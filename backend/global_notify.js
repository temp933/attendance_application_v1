// global_notify.js

"use strict";

const cron = require("node-cron");
const { getAdmin } = require("./firebase_admin"); // ← shared singleton
const db = require("./config/db");

// FCM multicast batch size — FCM /v1 max is 500 per sendEachForMulticast call
const FCM_BATCH_SIZE = 500;

// ─── DB helper ────────────────────────────────────────────────────────────────
async function q(sql, params = []) {
  const [rows] = await db.query(sql, params);
  return rows;
}

// ─── Target Resolution ────────────────────────────────────────────────────────

/**
 * Resolve scope → flat array of { tenant_id, emp_id, fcm_token }
 * Only includes employees with a valid FCM token + active device.
 *
 * @param {string} scope         - 'all'|'selected'|'by_plan'|'trial'|'expired'|'by_version'
 * @param {object} scopeMeta     - extra parameters (tenant_ids[], plan_id, version_string)
 * @returns {Promise<Array>}
 */
async function resolveTargets(scope, scopeMeta = {}) {
  let tenantFilter = "";
  let params = [];

  switch (scope) {
    case "all":
      tenantFilter = `t.status IN ('active', 'trial')`;
      break;

    case "selected":
      if (!scopeMeta.tenant_ids?.length) return [];
      tenantFilter = `t.tenant_id IN (${scopeMeta.tenant_ids.map(() => "?").join(",")})`;
      params = [...scopeMeta.tenant_ids];
      break;

    case "by_plan":
      tenantFilter = `t.plan_id = ? AND t.status IN ('active','trial')`;
      params = [scopeMeta.plan_id];
      break;

    case "trial":
      tenantFilter = `t.status = 'trial'`;
      break;

    case "expired":
      // plan_ends_at < today and status not yet active
      tenantFilter = `t.plan_ends_at < CURDATE() AND t.status NOT IN ('active','trial')`;
      break;

    case "by_version":
      // Filter via login_master.app_version column (add if not present)
      tenantFilter = `t.status IN ('active','trial')`;
      break;

    default:
      tenantFilter = `t.status IN ('active','trial')`;
  }

  let versionJoin = "";
  let versionWhere = "";
  if (scope === "by_version" && scopeMeta.version_string) {
    versionWhere = `AND lm.app_version = ?`;
    params.push(scopeMeta.version_string);
  }

  const rows = await q(
    `SELECT
        em.tenant_id,
        em.emp_id,
        lm.fcm_token
     FROM   tenants t
     INNER  JOIN employee_master em
            ON em.tenant_id COLLATE utf8mb4_unicode_ci
             = t.tenant_id  COLLATE utf8mb4_unicode_ci
            AND em.status = 'Active'
     INNER  JOIN login_master lm
            ON  lm.emp_id    = em.emp_id
            AND lm.tenant_id COLLATE utf8mb4_unicode_ci
              = em.tenant_id COLLATE utf8mb4_unicode_ci
            AND lm.status             = 'Active'
            AND lm.device_active      = 1
            AND lm.notification_enabled = 1
            AND lm.fcm_token         IS NOT NULL
            AND lm.force_logout       = 0
            ${versionWhere}
     WHERE  ${tenantFilter}`,
    params,
  );

  return rows;
}

// ─── FCM Batch Send ───────────────────────────────────────────────────────────

/**
 * sendFcmBatch — send to up to FCM_BATCH_SIZE tokens in one multicast.
 *
 * @param {string[]} tokens
 * @param {string}   title
 * @param {string}   body
 * @param {object}   data
 * @returns {Promise<{ successCount, failureCount, responses }>}
 */
async function sendFcmBatch(tokens, title, body, data = {}) {
  const message = {
    notification: { title, body },
    data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
    android: {
      priority: "high",
      notification: {
        channelId: "global_alerts",
        sound: "default",
        priority: "high",
      },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
    tokens,
  };

  try {
    const result = await getAdmin().messaging().sendEachForMulticast(message);
    return result;
  } catch (err) {
    console.error("[global-notify] FCM multicast error:", err.message);
    return { successCount: 0, failureCount: tokens.length, responses: [] };
  }
}

// ─── Core Send Flow ───────────────────────────────────────────────────────────

/**
 * sendGlobalNotification(notificationId)
 *
 * 1. Load notification record.
 * 2. Resolve targets according to scope.
 * 3. Insert per-employee log rows (bulk).
 * 4. Insert per-tenant target rows.
 * 5. Send FCM in batches and update log rows + counters.
 *
 * @param {number} notificationId
 */
async function sendGlobalNotification(notificationId) {
  // 1. Load record
  const [notif] = await q(
    `SELECT * FROM global_notifications WHERE id = ? LIMIT 1`,
    [notificationId],
  );

  if (!notif) throw new Error(`Notification ${notificationId} not found`);
  if (notif.status === "sent" || notif.status === "cancelled") {
    console.log(
      `[global-notify] Skipping #${notificationId} — already ${notif.status}`,
    );
    return;
  }

  // Mark as sending
  await db.query(
    `UPDATE global_notifications SET status = 'sending', sent_at = NOW() WHERE id = ?`,
    [notificationId],
  );

  // 2. Resolve targets
  const scopeMeta = notif.scope_meta ? JSON.parse(notif.scope_meta) : {};
  const targets = await resolveTargets(notif.scope, scopeMeta);

  if (!targets.length) {
    await db.query(
      `UPDATE global_notifications SET status = 'sent', total_targets = 0 WHERE id = ?`,
      [notificationId],
    );
    console.log(`[global-notify] #${notificationId} — no targets found.`);
    return;
  }

  // 3. Bulk-insert log rows
  const logValues = targets.map(({ tenant_id, emp_id, fcm_token }) => [
    notificationId,
    tenant_id,
    emp_id,
    fcm_token,
    "pending",
  ]);
  await db.query(
    `INSERT IGNORE INTO global_notification_logs
       (notification_id, tenant_id, emp_id, fcm_token, delivery_status)
     VALUES ?`,
    [logValues],
  );

  // 4. Bulk-insert tenant target rows (distinct tenants)
  const tenantSet = [...new Set(targets.map((t) => t.tenant_id))];
  const targetValues = tenantSet.map((tid) => [notificationId, tid]);
  await db.query(
    `INSERT IGNORE INTO global_notification_targets (notification_id, tenant_id) VALUES ?`,
    [targetValues],
  );

  // 5. Send in batches
  const data = {
    type: "global_notification",
    notification_id: String(notificationId),
    notif_type: notif.type,
    ...(notif.image_url ? { image_url: notif.image_url } : {}),
  };

  let totalSent = 0;
  let totalFailed = 0;

  for (let i = 0; i < targets.length; i += FCM_BATCH_SIZE) {
    const batch = targets.slice(i, i + FCM_BATCH_SIZE);
    const tokens = batch.map((t) => t.fcm_token);
    const result = await sendFcmBatch(tokens, notif.title, notif.message, data);

    // Update per-token log rows
    for (let j = 0; j < batch.length; j++) {
      const { emp_id, tenant_id } = batch[j];
      const response = result.responses?.[j];
      const success = response?.success ?? false;

      await db.query(
        `UPDATE global_notification_logs
         SET delivery_status = ?, failure_reason = ?, sent_at = NOW()
         WHERE notification_id = ? AND emp_id = ? AND tenant_id = ?`,
        [
          success ? "sent" : "failed",
          success ? null : (response?.error?.message ?? "FCM error"),
          notificationId,
          emp_id,
          tenant_id,
        ],
      );
    }

    totalSent += result.successCount ?? 0;
    totalFailed += result.failureCount ?? 0;

    console.log(
      `[global-notify] #${notificationId} batch ${Math.floor(i / FCM_BATCH_SIZE) + 1}: ` +
        `sent=${result.successCount} failed=${result.failureCount}`,
    );
  }

  // 6. Update summary counters
  await db.query(
    `UPDATE global_notifications
     SET status       = 'sent',
         total_targets = ?,
         sent_count    = ?,
         failed_count  = ?
     WHERE id = ?`,
    [targets.length, totalSent, totalFailed, notificationId],
  );

  console.log(
    `[global-notify] #${notificationId} complete — ` +
      `targets=${targets.length} sent=${totalSent} failed=${totalFailed}`,
  );
}

// ─── Retry Failed ─────────────────────────────────────────────────────────────

/**
 * retryFailed(notificationId)
 *
 * Re-sends FCM to all employees whose delivery_status = 'failed'
 * for the given notification.
 */
async function retryFailed(notificationId) {
  const [notif] = await q(
    `SELECT * FROM global_notifications WHERE id = ? AND status = 'sent' LIMIT 1`,
    [notificationId],
  );
  if (!notif)
    throw new Error(`Notification ${notificationId} not found or not yet sent`);

  const failedRows = await q(
    `SELECT emp_id, tenant_id, fcm_token
     FROM   global_notification_logs
     WHERE  notification_id = ? AND delivery_status = 'failed' AND fcm_token IS NOT NULL`,
    [notificationId],
  );

  if (!failedRows.length) {
    console.log(`[global-notify] No failed logs for #${notificationId}`);
    return { retried: 0 };
  }

  const data = {
    type: "global_notification",
    notification_id: String(notificationId),
    notif_type: notif.type,
    retry: "true",
  };

  let retried = 0;
  for (let i = 0; i < failedRows.length; i += FCM_BATCH_SIZE) {
    const batch = failedRows.slice(i, i + FCM_BATCH_SIZE);
    const tokens = batch.map((r) => r.fcm_token);
    const result = await sendFcmBatch(tokens, notif.title, notif.message, data);

    for (let j = 0; j < batch.length; j++) {
      const { emp_id, tenant_id } = batch[j];
      const success = result.responses?.[j]?.success ?? false;
      if (success) {
        retried++;
        await db.query(
          `UPDATE global_notification_logs
           SET delivery_status = 'sent', failure_reason = NULL, sent_at = NOW()
           WHERE notification_id = ? AND emp_id = ? AND tenant_id = ?`,
          [notificationId, emp_id, tenant_id],
        );
      }
    }
  }

  // Recalculate counters
  const [counts] = await q(
    `SELECT
       SUM(delivery_status = 'sent')      AS sent_count,
       SUM(delivery_status = 'failed')    AS failed_count,
       SUM(delivery_status = 'delivered') AS delivered_count,
       SUM(opened_at IS NOT NULL)         AS opened_count,
       COUNT(*)                           AS total_targets
     FROM global_notification_logs
     WHERE notification_id = ?`,
    [notificationId],
  );

  await db.query(
    `UPDATE global_notifications
     SET sent_count      = ?,
         failed_count    = ?,
         delivered_count = ?,
         opened_count    = ?
     WHERE id = ?`,
    [
      counts.sent_count || 0,
      counts.failed_count || 0,
      counts.delivered_count || 0,
      counts.opened_count || 0,
      notificationId,
    ],
  );

  console.log(
    `[global-notify] Retry #${notificationId}: ${retried} recovered.`,
  );
  return { retried };
}

// ─── Mark Opened (called from Flutter app via API) ────────────────────────────

/**
 * markOpened(notificationId, empId, tenantId)
 *
 * Increment opened_count on the parent record.
 */
async function markOpened(notificationId, empId, tenantId) {
  const [result] = await db.query(
    `UPDATE global_notification_logs
     SET opened_at = NOW()
     WHERE notification_id = ? AND emp_id = ? AND tenant_id = ? AND opened_at IS NULL`,
    [notificationId, empId, tenantId],
  );

  if (result.affectedRows > 0) {
    await db.query(
      `UPDATE global_notifications
       SET opened_count = opened_count + 1
       WHERE id = ?`,
      [notificationId],
    );
  }
}

// ─── Scheduled Notification Cron ─────────────────────────────────────────────

/**
 * Runs every minute.
 * Picks up scheduled notifications whose scheduled_at <= NOW() and fires them.
 */
async function runScheduledCron() {
  const due = await q(
    `SELECT id FROM global_notifications
     WHERE status = 'scheduled' AND scheduled_at <= NOW()
     ORDER BY scheduled_at ASC`,
  );

  for (const { id } of due) {
    console.log(`[global-notify] Dispatching scheduled notification #${id}`);
    try {
      await sendGlobalNotification(id);
    } catch (err) {
      console.error(`[global-notify] Failed to send #${id}:`, err.message);
      await db.query(
        `UPDATE global_notifications SET status = 'failed' WHERE id = ?`,
        [id],
      );
    }
  }
}

function initGlobalCron() {
  getAdmin(); // ensure Firebase initialized
  cron.schedule("* * * * *", runScheduledCron, { timezone: "Asia/Kolkata" });
  console.log("[global-notify] Scheduled notification cron started.");
}

// ─── Exports ──────────────────────────────────────────────────────────────────
module.exports = {
  resolveTargets,
  sendGlobalNotification,
  retryFailed,
  markOpened,
  initGlobalCron,
};
