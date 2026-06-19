"use strict";

const router = require("express").Router();
const db = require("./config/db");
const { getAdmin } = require("./firebase_admin");

const FCM_BATCH = 500;

// ─── DB helper ────────────────────────────────────────────────────────────────
async function q(sql, params = []) {
  const [rows] = await db.query(sql, params);
  return rows;
}

// ─── Role guard — Admin or HR only ────────────────────────────────────────────
function requireAdminOrHR(req, res, next) {
  const role = (req.user?.role_name || "").toLowerCase();
  if (!["admin", "hr"].includes(role)) {
    return res.status(403).json({ success: false, message: "Forbidden." });
  }
  next();
}

// ─── Target resolver ──────────────────────────────────────────────────────────
// Returns flat array of { emp_id, fcm_token } within the tenant.
// scope: 'all' | 'by_department' | 'by_role' | 'specific'
// scopeMeta: { department_ids[], role_ids[], emp_ids[] }
async function resolveOrgTargets(
  tenantId,
  scope,
  scopeMeta = {},
  requireToken = true,
) {
  const tokenCond = requireToken ? "AND lm.fcm_token IS NOT NULL" : "";

  switch (scope) {
    // ── All active employees ────────────────────────────────────────────────
    case "all": {
      return q(
        `SELECT em.emp_id, lm.fcm_token
         FROM   employee_master em
         INNER  JOIN login_master lm
                ON  lm.emp_id    = em.emp_id
                AND lm.tenant_id COLLATE utf8mb4_unicode_ci
                  = em.tenant_id COLLATE utf8mb4_unicode_ci
                AND lm.status = 'Active'
                ${tokenCond}
         WHERE  em.tenant_id = ? AND em.status = 'Active'`,
        [tenantId],
      );
    }

    // ── By department(s) ───────────────────────────────────────────────────
    case "by_department": {
      const ids = scopeMeta.department_ids;
      if (!Array.isArray(ids) || !ids.length) return [];
      const placeholders = ids.map(() => "?").join(",");
      return q(
        `SELECT em.emp_id, lm.fcm_token
         FROM   employee_master em
         INNER  JOIN designation_master ds
                ON ds.designation_id = em.designation_id
         INNER  JOIN login_master lm
                ON  lm.emp_id    = em.emp_id
                AND lm.tenant_id COLLATE utf8mb4_unicode_ci
                  = em.tenant_id COLLATE utf8mb4_unicode_ci
                AND lm.status = 'Active'
                ${tokenCond}
         WHERE  em.tenant_id = ?
           AND  em.status    = 'Active'
           AND  ds.department_id IN (${placeholders})`,
        [tenantId, ...ids],
      );
    }

    // ── By role(s) ─────────────────────────────────────────────────────────
    case "by_role": {
      const ids = scopeMeta.role_ids;
      if (!Array.isArray(ids) || !ids.length) return [];
      const placeholders = ids.map(() => "?").join(",");
      return q(
        `SELECT em.emp_id, lm.fcm_token
         FROM   employee_master em
         INNER  JOIN login_master lm
                ON  lm.emp_id    = em.emp_id
                AND lm.tenant_id COLLATE utf8mb4_unicode_ci
                  = em.tenant_id COLLATE utf8mb4_unicode_ci
                AND lm.status = 'Active'
                ${tokenCond}
         WHERE  em.tenant_id = ?
           AND  em.status    = 'Active'
           AND  em.role_id   IN (${placeholders})`,
        [tenantId, ...ids],
      );
    }

    // ── Specific employees ─────────────────────────────────────────────────
    case "specific": {
      const ids = scopeMeta.emp_ids;
      if (!Array.isArray(ids) || !ids.length) return [];
      const placeholders = ids.map(() => "?").join(",");
      return q(
        `SELECT em.emp_id, lm.fcm_token
         FROM   employee_master em
         INNER  JOIN login_master lm
                ON  lm.emp_id    = em.emp_id
                AND lm.tenant_id COLLATE utf8mb4_unicode_ci
                  = em.tenant_id COLLATE utf8mb4_unicode_ci
                AND lm.status = 'Active'
                ${tokenCond}
         WHERE  em.tenant_id = ?
           AND  em.status    = 'Active'
           AND  em.emp_id    IN (${placeholders})`,
        [tenantId, ...ids],
      );
    }

    default:
      return [];
  }
}

// ─── FCM send ─────────────────────────────────────────────────────────────────
async function sendFcmBatch(tokens, title, body, data = {}) {
  const message = {
    notification: { title, body },
    data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
    android: {
      priority: "high",
      notification: {
        channelId: "org_notifications",
        sound: "default",
        priority: "high",
      },
    },
    apns: { payload: { aps: { sound: "default", badge: 1 } } },
    tokens,
  };
  try {
    return await getAdmin().messaging().sendEachForMulticast(message);
  } catch (err) {
    console.error("[org-notify] FCM error:", err.message);
    return { successCount: 0, failureCount: tokens.length, responses: [] };
  }
}

// ─── Core send function ───────────────────────────────────────────────────────
async function sendOrgNotification(notifId) {
  const [notif] = await q(
    `SELECT * FROM org_notifications WHERE id = ? LIMIT 1`,
    [notifId],
  );
  if (!notif) throw new Error(`Org notification ${notifId} not found`);
  if (notif.status === "sent" || notif.status === "cancelled") return;

  await db.query(
    `UPDATE org_notifications SET status = 'sending', sent_at = NOW() WHERE id = ?`,
    [notifId],
  );

  const scopeMeta = notif.scope_meta
    ? typeof notif.scope_meta === "string"
      ? JSON.parse(notif.scope_meta)
      : notif.scope_meta
    : {};

  // Resolve everyone (including offline — for pending queue)
  const allRecipients = await resolveOrgTargets(
    notif.tenant_id,
    notif.scope,
    scopeMeta,
    false,
  );

  if (!allRecipients.length) {
    await db.query(
      `UPDATE org_notifications SET status = 'sent', total_targets = 0 WHERE id = ?`,
      [notifId],
    );
    return;
  }

  // Bulk-insert log rows
  const logValues = allRecipients.map(({ emp_id }) => [
    notifId,
    notif.tenant_id,
    emp_id,
    null,
    "pending",
  ]);
  await db.query(
    `INSERT IGNORE INTO org_notification_logs
       (notification_id, tenant_id, emp_id, fcm_token, delivery_status)
     VALUES ?`,
    [logValues],
  );

  // Subset that can receive a push right now
  const targets = allRecipients.filter((r) => r.fcm_token);

  if (!targets.length) {
    await db.query(
      `UPDATE org_notifications SET status = 'sent', total_targets = ?, sent_count = 0, failed_count = 0 WHERE id = ?`,
      [allRecipients.length, notifId],
    );
    console.log(
      `[org-notify] #${notifId} — nobody online, ${allRecipients.length} queued pending.`,
    );
    return;
  }

  const data = {
    type: "org_notification",
    notification_id: String(notifId),
    notif_type: notif.type,
    ...(notif.image_url ? { image_url: notif.image_url } : {}),
  };

  let totalSent = 0,
    totalFailed = 0;

  for (let i = 0; i < targets.length; i += FCM_BATCH) {
    const batch = targets.slice(i, i + FCM_BATCH);
    const tokens = batch.map((t) => t.fcm_token);
    const result = await sendFcmBatch(tokens, notif.title, notif.message, data);

    for (let j = 0; j < batch.length; j++) {
      const { emp_id } = batch[j];
      const success = result.responses?.[j]?.success ?? false;
      await db.query(
        `UPDATE org_notification_logs
         SET delivery_status = ?, failure_reason = ?, fcm_token = ?, sent_at = NOW()
         WHERE notification_id = ? AND emp_id = ? AND tenant_id = ?`,
        [
          success ? "sent" : "failed",
          success
            ? null
            : (result.responses?.[j]?.error?.message ?? "FCM error"),
          batch[j].fcm_token,
          notifId,
          emp_id,
          notif.tenant_id,
        ],
      );
    }

    totalSent += result.successCount ?? 0;
    totalFailed += result.failureCount ?? 0;
  }

  await db.query(
    `UPDATE org_notifications
     SET status = 'sent', total_targets = ?, sent_count = ?, failed_count = ?
     WHERE id = ?`,
    [allRecipients.length, totalSent, totalFailed, notifId],
  );

  console.log(
    `[org-notify] #${notifId} done — sent=${totalSent} failed=${totalFailed}`,
  );
}

// ─── markOrgDelivered — promote pending→sent on employee fetch ───────────────
async function markOrgDelivered(notificationIds, empId, tenantId) {
  if (!notificationIds.length) return;
  const placeholders = notificationIds.map(() => "?").join(",");

  await db.query(
    `UPDATE org_notification_logs
     SET delivery_status = 'sent', sent_at = COALESCE(sent_at, NOW())
     WHERE notification_id IN (${placeholders})
       AND emp_id = ? AND tenant_id = ? AND delivery_status = 'pending'`,
    [...notificationIds, empId, tenantId],
  );

  for (const id of notificationIds) {
    await db.query(
      `UPDATE org_notifications gn
       SET sent_count = (
             SELECT COUNT(*) FROM org_notification_logs
             WHERE notification_id = ? AND delivery_status = 'sent'
           ),
           failed_count = (
             SELECT COUNT(*) FROM org_notification_logs
             WHERE notification_id = ? AND delivery_status = 'failed'
           )
       WHERE gn.id = ?`,
      [id, id, id],
    );
  }
}

// ─── markOrgOpened ─────────────────────────────────────────────────────────
async function markOrgOpened(notificationId, empId, tenantId) {
  const [result] = await db.query(
    `UPDATE org_notification_logs
     SET opened_at = NOW()
     WHERE notification_id = ? AND emp_id = ? AND tenant_id = ?
       AND delivery_status = 'sent' AND opened_at IS NULL`,
    [notificationId, empId, tenantId],
  );

  if (result.affectedRows > 0) {
    await db.query(
      `UPDATE org_notifications
       SET opened_count = (
         SELECT COUNT(*) FROM org_notification_logs
         WHERE notification_id = ? AND delivery_status = 'sent' AND opened_at IS NOT NULL
       )
       WHERE id = ?`,
      [notificationId, notificationId],
    );
  }
}

// ─── GET /my-history — employee-facing history ───────────────────────────────
router.get("/my-history", async (req, res) => {
  const empId = req.user?.emp_id;
  const tenantId = req.user?.tenant_id;
  const page = Math.max(1, parseInt(req.query.page || "1", 10));
  const limit = Math.min(50, parseInt(req.query.limit || "20", 10));
  const offset = (page - 1) * limit;

  try {
    const rows = await q(
      `SELECT
         gn.id                            AS notification_id,
         gn.title,
         gn.message,
         gn.type,
         l.delivery_status,
         l.opened_at,
         COALESCE(gn.sent_at, l.sent_at)  AS created_at
       FROM   org_notification_logs l
       INNER  JOIN org_notifications gn ON gn.id = l.notification_id
       WHERE  l.tenant_id = ? AND l.emp_id = ?
       ORDER  BY created_at DESC
       LIMIT  ? OFFSET ?`,
      [tenantId, empId, limit, offset],
    );

    const pendingIds = rows
      .filter((r) => r.delivery_status === "pending")
      .map((r) => r.notification_id);
    if (pendingIds.length) await markOrgDelivered(pendingIds, empId, tenantId);

    const data = rows.map((r) => ({
      notification_id: r.notification_id,
      title: r.title,
      message: r.message,
      type: r.type,
      is_opened: r.opened_at !== null ? 1 : 0,
      created_at: r.created_at,
    }));

    res.json({ success: true, page, limit, data });
  } catch (err) {
    console.error("[org-notif] GET /my-history:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch history." });
  }
});

// ─── POST /mark-opened — employee marks an org notification opened ──────────
router.post("/mark-opened", async (req, res) => {
  const empId = req.user?.emp_id;
  const tenantId = req.user?.tenant_id;
  const { notification_id } = req.body;
  if (!notification_id || !empId || !tenantId) {
    return res.status(400).json({ success: false, message: "Missing fields." });
  }
  try {
    await markOrgOpened(parseInt(notification_id, 10), empId, tenantId);
    res.json({ success: true });
  } catch (err) {
    console.error("[org-notif] POST /mark-opened:", err);
    res.status(500).json({ success: false, message: "Failed." });
  }
});

// ─── GET /dashboard ───────────────────────────────────────────────────────────
router.get("/dashboard", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  try {
    const [totals] = await q(
      `SELECT
         COUNT(*)                         AS total_notifications,
         SUM(status = 'scheduled')        AS scheduled_count,
         SUM(status = 'sending')          AS sending_count
       FROM org_notifications
       WHERE tenant_id = ?`,
      [tenant_id],
    );

    const [liveTotals] = await q(
      `SELECT
         SUM(delivery_status = 'sent')                             AS total_sent,
         SUM(delivery_status = 'failed')                           AS total_failed,
         SUM(delivery_status = 'sent' AND opened_at IS NOT NULL)   AS total_opened
       FROM org_notification_logs
       WHERE tenant_id = ?`,
      [tenant_id],
    );

    const totalSent = liveTotals.total_sent || 0;
    const totalFailed = liveTotals.total_failed || 0;
    const totalOpened = liveTotals.total_opened || 0;
    const openRate =
      totalSent > 0
        ? parseFloat(((totalOpened / totalSent) * 100).toFixed(1))
        : 0;

    const recent = await q(
      `SELECT id, title, type, scope, status,
              total_targets, sent_count, failed_count, opened_count,
              created_by, created_at, sent_at, scheduled_at
       FROM   org_notifications
       WHERE  tenant_id = ?
       ORDER  BY created_at DESC
       LIMIT  10`,
      [tenant_id],
    );

    res.json({
      success: true,
      summary: {
        total_notifications: totals.total_notifications || 0,
        total_sent: totalSent,
        total_failed: totalFailed,
        total_opened: totalOpened,
        scheduled_count: totals.scheduled_count || 0,
        open_rate: openRate,
      },
      recent,
    });
  } catch (err) {
    console.error("[org-notif] GET /dashboard:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch dashboard." });
  }
});

// ─── GET /departments ─────────────────────────────────────────────────────────
// For the department picker in the Send form
router.get("/departments", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  try {
    const rows = await q(
      `SELECT department_id AS id, department_name
       FROM   department_master
       WHERE  tenant_id = ? AND status = 'Active' AND is_deleted = 0
       ORDER  BY department_name ASC`,
      [tenant_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[org-notif] GET /departments:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch departments." });
  }
});

// ─── GET /roles ───────────────────────────────────────────────────────────────
router.get("/roles", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  try {
    const rows = await q(
      `SELECT role_id AS id, role_name
       FROM   role_master
       WHERE  tenant_id = ? AND status = 'Active' AND is_deleted = 0
       ORDER  BY role_name ASC`,
      [tenant_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[org-notif] GET /roles:", err);
    res.status(500).json({ success: false, message: "Failed to fetch roles." });
  }
});

// ─── GET /employees ───────────────────────────────────────────────────────────
// Light list for the employee picker — name + emp_id only
router.get("/employees", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  try {
    const rows = await q(
      `SELECT em.emp_id, em.first_name, em.last_name,
              r.role_name, dm.department_name
       FROM   employee_master em
       LEFT   JOIN role_master r ON r.role_id = em.role_id
       LEFT   JOIN designation_master ds ON ds.designation_id = em.designation_id
       LEFT   JOIN department_master  dm ON dm.department_id  = ds.department_id
       WHERE  em.tenant_id = ? AND em.status = 'Active'
       ORDER  BY em.first_name ASC`,
      [tenant_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[org-notif] GET /employees:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch employees." });
  }
});

// ─── POST /send ───────────────────────────────────────────────────────────────
router.post("/send", requireAdminOrHR, async (req, res) => {
  const { tenant_id, emp_id: createdBy } = req.user;

  const {
    title,
    message,
    type = "general",
    scope = "all",
    scope_meta = null,
    image_url = null,
    scheduled_at = null,
  } = req.body;

  if (!title?.trim() || !message?.trim()) {
    return res
      .status(400)
      .json({ success: false, message: "title and message are required." });
  }

  const validTypes = [
    "general",
    "announcement",
    "policy_update",
    "urgent",
    "reminder",
  ];
  const validScopes = ["all", "by_department", "by_role", "specific"];

  if (!validTypes.includes(type)) {
    return res
      .status(400)
      .json({ success: false, message: `Invalid type: ${type}` });
  }
  if (!validScopes.includes(scope)) {
    return res
      .status(400)
      .json({ success: false, message: `Invalid scope: ${scope}` });
  }

  // Validate scope_meta is populated when required
  if (scope === "by_department" && !scope_meta?.department_ids?.length) {
    return res.status(400).json({
      success: false,
      message: "department_ids required for by_department scope.",
    });
  }
  if (scope === "by_role" && !scope_meta?.role_ids?.length) {
    return res.status(400).json({
      success: false,
      message: "role_ids required for by_role scope.",
    });
  }
  if (scope === "specific" && !scope_meta?.emp_ids?.length) {
    return res.status(400).json({
      success: false,
      message: "emp_ids required for specific scope.",
    });
  }

  const isSendNow = !scheduled_at;
  const status = isSendNow ? "draft" : "scheduled";
  const scheduleTs = scheduled_at ? new Date(scheduled_at) : null;

  try {
    const [result] = await db.query(
      `INSERT INTO org_notifications
         (tenant_id, title, message, type, scope, scope_meta, image_url, created_by, scheduled_at, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        tenant_id,
        title.trim(),
        message.trim(),
        type,
        scope,
        scope_meta ? JSON.stringify(scope_meta) : null,
        image_url || null,
        createdBy,
        scheduleTs,
        status,
      ],
    );

    const notifId = result.insertId;

    if (isSendNow) {
      setImmediate(async () => {
        try {
          await sendOrgNotification(notifId);
        } catch (err) {
          console.error(
            `[org-notif] sendOrgNotification #${notifId}:`,
            err.message,
          );
          await db.query(
            `UPDATE org_notifications SET status = 'failed' WHERE id = ?`,
            [notifId],
          );
        }
      });
    }

    res.status(201).json({
      success: true,
      notification_id: notifId,
      scheduled: !isSendNow,
      message: isSendNow
        ? "Notification queued for sending."
        : "Notification scheduled.",
    });
  } catch (err) {
    console.error("[org-notif] POST /send:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to send notification." });
  }
});

// ─── GET /history ─────────────────────────────────────────────────────────────
router.get("/history", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;

  const page = Math.max(1, parseInt(req.query.page || "1", 10));
  const limit = Math.min(50, parseInt(req.query.limit || "20", 10));
  const offset = (page - 1) * limit;

  const { type, status, search } = req.query;
  const conditions = ["tenant_id = ?"];
  const params = [tenant_id];

  if (type) {
    conditions.push("type = ?");
    params.push(type);
  }
  if (status) {
    conditions.push("status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("title LIKE ?");
    params.push(`%${search}%`);
  }

  const where = conditions.join(" AND ");

  try {
    const [countRow] = await q(
      `SELECT COUNT(*) AS total FROM org_notifications WHERE ${where}`,
      params,
    );
    const rows = await q(
      `SELECT id, title, type, scope, status,
              total_targets, sent_count, failed_count, opened_count,
              created_by, created_at, sent_at, scheduled_at, image_url
       FROM   org_notifications
       WHERE  ${where}
       ORDER  BY created_at DESC
       LIMIT  ? OFFSET ?`,
      [...params, limit, offset],
    );
    res.json({ success: true, page, limit, total: countRow.total, data: rows });
  } catch (err) {
    console.error("[org-notif] GET /history:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch history." });
  }
});

// ─── POST /preview-targets ────────────────────────────────────────────────────
router.post("/preview-targets", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  const { scope, scope_meta } = req.body;

  try {
    const targets = await resolveOrgTargets(
      tenant_id,
      scope,
      scope_meta || {},
      false,
    );
    res.json({ success: true, total_employees: targets.length });
  } catch (err) {
    console.error("[org-notif] POST /preview-targets:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to preview targets." });
  }
});

// ─── GET /analytics/summary ───────────────────────────────────────────────────
router.get("/analytics/summary", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  try {
    const trend = await q(
      `SELECT DATE(created_at) AS date,
              SUM(sent_count)   AS sent,
              SUM(failed_count) AS failed,
              SUM(opened_count) AS opened
       FROM   org_notifications
       WHERE  tenant_id = ?
         AND  created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
       GROUP  BY DATE(created_at)
       ORDER  BY date ASC`,
      [tenant_id],
    );

    const byType = await q(
      `SELECT type,
              COUNT(*)                             AS total,
              SUM(sent_count)                      AS total_sent,
              SUM(failed_count)                    AS total_failed,
              ROUND(100.0 * SUM(opened_count) / NULLIF(SUM(sent_count), 0), 1) AS open_rate
       FROM   org_notifications
       WHERE  tenant_id = ? AND status = 'sent'
       GROUP  BY type`,
      [tenant_id],
    );

    res.json({ success: true, trend, by_type: byType });
  } catch (err) {
    console.error("[org-notif] GET /analytics/summary:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch analytics." });
  }
});

// ─── GET /:id ─────────────────────────────────────────────────────────────────
router.get("/:id", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  const { id } = req.params;

  try {
    const [notif] = await q(
      `SELECT * FROM org_notifications WHERE id = ? AND tenant_id = ? LIMIT 1`,
      [id, tenant_id],
    );
    if (!notif)
      return res.status(404).json({ success: false, message: "Not found." });

    // Live counts from logs
    const [live] = await q(
      `SELECT
         COUNT(*)                                         AS total_targets,
         SUM(delivery_status = 'sent')                   AS sent_count,
         SUM(delivery_status = 'failed')                 AS failed_count,
         SUM(delivery_status = 'sent' AND opened_at IS NOT NULL) AS opened_count
       FROM org_notification_logs
       WHERE notification_id = ? AND tenant_id = ?`,
      [id, tenant_id],
    );
    notif.total_targets = live.total_targets || notif.total_targets;
    notif.sent_count = live.sent_count || 0;
    notif.failed_count = live.failed_count || 0;
    notif.opened_count = live.opened_count || 0;

    const breakdown = await q(
      `SELECT delivery_status, COUNT(*) AS count
       FROM   org_notification_logs
       WHERE  notification_id = ? AND tenant_id = ?
       GROUP  BY delivery_status`,
      [id, tenant_id],
    );

    res.json({ success: true, notification: notif, breakdown });
  } catch (err) {
    console.error("[org-notif] GET /:id:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch detail." });
  }
});

// ─── PATCH /:id/cancel ───────────────────────────────────────────────────────
router.patch("/:id/cancel", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  const { id } = req.params;
  try {
    const [result] = await db.query(
      `UPDATE org_notifications SET status = 'cancelled'
       WHERE id = ? AND tenant_id = ? AND status = 'scheduled'`,
      [id, tenant_id],
    );
    if (!result.affectedRows) {
      return res.status(400).json({
        success: false,
        message: "Not found or not in scheduled state.",
      });
    }
    res.json({ success: true, message: "Notification cancelled." });
  } catch (err) {
    console.error("[org-notif] PATCH /:id/cancel:", err);
    res.status(500).json({ success: false, message: "Failed to cancel." });
  }
});

// ─── POST /:id/retry ──────────────────────────────────────────────────────────
router.post("/:id/retry", requireAdminOrHR, async (req, res) => {
  const { tenant_id } = req.user;
  const { id } = req.params;

  try {
    const [notif] = await q(
      `SELECT * FROM org_notifications WHERE id = ? AND tenant_id = ? AND status = 'sent' LIMIT 1`,
      [id, tenant_id],
    );
    if (!notif)
      return res
        .status(404)
        .json({ success: false, message: "Not found or not yet sent." });

    const failedRows = await q(
      `SELECT emp_id, fcm_token FROM org_notification_logs
       WHERE notification_id = ? AND tenant_id = ? AND delivery_status = 'failed' AND fcm_token IS NOT NULL`,
      [id, tenant_id],
    );

    if (!failedRows.length) return res.json({ success: true, retried: 0 });

    const data = {
      type: "org_notification",
      notification_id: String(notif.id),
      notif_type: notif.type,
      retry: "true",
    };

    let retried = 0;
    for (let i = 0; i < failedRows.length; i += FCM_BATCH) {
      const batch = failedRows.slice(i, i + FCM_BATCH);
      const tokens = batch.map((r) => r.fcm_token);
      const result = await sendFcmBatch(
        tokens,
        notif.title,
        notif.message,
        data,
      );

      for (let j = 0; j < batch.length; j++) {
        if (result.responses?.[j]?.success) {
          retried++;
          await db.query(
            `UPDATE org_notification_logs
             SET delivery_status = 'sent', failure_reason = NULL, sent_at = NOW()
             WHERE notification_id = ? AND emp_id = ? AND tenant_id = ?`,
            [notif.id, batch[j].emp_id, tenant_id],
          );
        }
      }
    }

    // Recalculate counters
    const [counts] = await q(
      `SELECT
         SUM(delivery_status = 'sent')   AS sent_count,
         SUM(delivery_status = 'failed') AS failed_count,
         SUM(opened_at IS NOT NULL)      AS opened_count
       FROM org_notification_logs
       WHERE notification_id = ? AND tenant_id = ?`,
      [notif.id, tenant_id],
    );

    await db.query(
      `UPDATE org_notifications SET sent_count = ?, failed_count = ?, opened_count = ? WHERE id = ?`,
      [
        counts.sent_count || 0,
        counts.failed_count || 0,
        counts.opened_count || 0,
        notif.id,
      ],
    );

    res.json({ success: true, retried });
  } catch (err) {
    console.error("[org-notif] POST /:id/retry:", err);
    res.status(500).json({ success: false, message: "Retry failed." });
  }
});

// ─── Scheduled cron — call this from server.js ────────────────────────────────
async function runOrgNotifCron() {
  const due = await q(
    `SELECT id FROM org_notifications
     WHERE status = 'scheduled' AND scheduled_at <= NOW()
     ORDER BY scheduled_at ASC`,
  );
  for (const { id } of due) {
    try {
      await sendOrgNotification(id);
    } catch (err) {
      console.error(`[org-notify-cron] Failed #${id}:`, err.message);
      await db.query(
        `UPDATE org_notifications SET status = 'failed' WHERE id = ?`,
        [id],
      );
    }
  }
}

module.exports = { router, runOrgNotifCron };
