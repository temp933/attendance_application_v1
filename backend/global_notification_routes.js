// global_notification_routes.js

"use strict";

const router = require("express").Router();
const db = require("./config/db");
const {
  sendGlobalNotification,
  retryFailed,
  resolveTargets,
} = require("./global_notify");

// ─── Helper ───────────────────────────────────────────────────────────────────
async function q(sql, params = []) {
  const [rows] = await db.query(sql, params);
  return rows;
}

// ─── GET /dashboard ───────────────────────────────────────────────────────────
// Summary stats + recent notifications
router.get("/dashboard", async (req, res) => {
  try {
    const [totals] = await q(
      `SELECT
         COUNT(*)                                    AS total_notifications,
         SUM(status = 'scheduled')                   AS scheduled_count,
         SUM(status = 'sending')                     AS sending_count
       FROM global_notifications`,
    );
    const [liveTotals] = await q(
      `SELECT
         SUM(delivery_status = 'sent')                               AS total_sent,
         SUM(delivery_status = 'failed')                             AS total_failed,
         SUM(delivery_status = 'sent' AND opened_at IS NOT NULL)     AS total_opened
       FROM global_notification_logs`,
    );
    totals.total_sent = liveTotals.total_sent || 0;
    totals.total_delivered = liveTotals.total_sent || 0;
    totals.total_failed = liveTotals.total_failed || 0;
    totals.total_opened = liveTotals.total_opened || 0;

    const recent = await q(
      `SELECT id, title, type, scope, status,
              total_targets, sent_count, failed_count, opened_count,
              created_at, sent_at, scheduled_at
       FROM   global_notifications
       ORDER  BY created_at DESC
       LIMIT  10`,
    );

    // Open rate (aggregate)
    const openRate =
      totals.total_sent && totals.total_opened <= totals.total_sent
        ? ((totals.total_opened / totals.total_sent) * 100).toFixed(1)
        : totals.total_sent
          ? "100.0"
          : "0.0";

    res.json({
      success: true,
      summary: {
        total_notifications: totals.total_notifications || 0,
        total_sent: totals.total_sent || 0,
        total_delivered: totals.total_delivered || 0,
        total_failed: totals.total_failed || 0,
        total_opened: totals.total_opened || 0,
        scheduled_count: totals.scheduled_count || 0,
        sending_count: totals.sending_count || 0,
        open_rate: parseFloat(openRate),
      },
      recent,
    });
  } catch (err) {
    console.error("[global-notif-routes] GET /dashboard:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch dashboard." });
  }
});

// ─── POST /send ───────────────────────────────────────────────────────────────
// Create + optionally dispatch immediately, or schedule.
router.post("/send", async (req, res) => {
  try {
    const createdBy = req.admin?.admin_id ?? req.user?.login_id ?? "superadmin";

    const {
      title,
      message,
      type = "general",
      scope = "all",
      scope_meta = null,
      image_url = null,
      scheduled_at = null,
      recipients = "all", // "all" | "admin_only" | "hr_only" | "admin_hr"
    } = req.body;

    if (!title?.trim() || !message?.trim()) {
      return res
        .status(400)
        .json({ success: false, message: "title and message are required." });
    }

    const validTypes = [
      "general",
      "maintenance",
      "app_update",
      "billing_reminder",
      "emergency_alert",
    ];
    const validScopes = [
      "all",
      "selected",
      "by_plan",
      "trial",
      "expired",
      "by_version",
    ];

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

    const isSendNow = !scheduled_at;
    const status = isSendNow ? "draft" : "scheduled";
    const scheduleTs = scheduled_at ? new Date(scheduled_at) : null;

    const [result] = await db.query(
      `INSERT INTO global_notifications
         (title, message, type, scope, scope_meta, image_url, created_by, scheduled_at, status, recipients)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        title.trim(),
        message.trim(),
        type,
        scope,
        scope_meta ? JSON.stringify(scope_meta) : null,
        image_url || null,
        createdBy,
        scheduleTs,
        status,
        recipients,
      ],
    );

    const notificationId = result.insertId;

    if (isSendNow) {
      // Fire-and-forget (don't block HTTP response)
      setImmediate(async () => {
        try {
          await sendGlobalNotification(notificationId);
        } catch (err) {
          console.error(
            `[global-notif-routes] sendGlobalNotification #${notificationId}:`,
            err.message,
          );
          await db.query(
            `UPDATE global_notifications SET status = 'failed' WHERE id = ?`,
            [notificationId],
          );
        }
      });
    }

    res.status(201).json({
      success: true,
      notification_id: notificationId,
      scheduled: !isSendNow,
      message: isSendNow
        ? "Notification queued for sending."
        : "Notification scheduled.",
    });
  } catch (err) {
    console.error("[global-notif-routes] POST /send:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to send notification." });
  }
});

// ─── GET /history ─────────────────────────────────────────────────────────────
// Paginated list with filters: type, status, tenant_id, date range.
router.get("/history", async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page || "1", 10));
    const limit = Math.min(50, parseInt(req.query.limit || "20", 10));
    const offset = (page - 1) * limit;

    const { type, status, tenant_id, date_from, date_to, search } = req.query;

    const conditions = [];
    const params = [];

    if (type) {
      conditions.push("gn.type = ?");
      params.push(type);
    }
    if (status) {
      conditions.push("gn.status = ?");
      params.push(status);
    }
    if (date_from) {
      conditions.push("DATE(gn.created_at) >= ?");
      params.push(date_from);
    }
    if (date_to) {
      conditions.push("DATE(gn.created_at) <= ?");
      params.push(date_to);
    }
    if (search) {
      conditions.push("gn.title LIKE ?");
      params.push(`%${search}%`);
    }

    if (tenant_id) {
      conditions.push(
        `EXISTS (SELECT 1 FROM global_notification_targets t
                 WHERE t.notification_id = gn.id AND t.tenant_id = ?)`,
      );
      params.push(tenant_id);
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

    const [countRow] = await q(
      `SELECT COUNT(*) AS total FROM global_notifications gn ${where}`,
      params,
    );

    const rows = await q(
      `SELECT gn.id, gn.title, gn.type, gn.scope, gn.status,
              gn.total_targets, gn.sent_count, gn.delivered_count,
              gn.failed_count, gn.opened_count,
              gn.created_by, gn.created_at, gn.sent_at, gn.scheduled_at,
              gn.image_url
       FROM   global_notifications gn
       ${where}
       ORDER  BY gn.created_at DESC
       LIMIT  ? OFFSET ?`,
      [...params, limit, offset],
    );

    res.json({
      success: true,
      page,
      limit,
      total: countRow.total,
      data: rows,
    });
  } catch (err) {
    console.error("[global-notif-routes] GET /history:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch history." });
  }
});

// ─── GET /orgs ────────────────────────────────────────────────────────────────
// Returns tenant list for the org picker dropdown.
router.get("/orgs", async (req, res) => {
  try {
    const rows = await q(
      `SELECT tenant_id, company_name, status, plan_id
       FROM   tenants
       WHERE  status IN ('active', 'trial', 'expired')
       ORDER  BY company_name ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[global-notif-routes] GET /orgs:", err);
    res.status(500).json({ success: false, message: "Failed to fetch orgs." });
  }
});

// ─── GET /:id ─────────────────────────────────────────────────────────────────
// Notification detail + delivery breakdown.
router.get("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const [notif] = await q(
      `SELECT * FROM global_notifications WHERE id = ? LIMIT 1`,
      [id],
    );
    if (!notif)
      return res.status(404).json({ success: false, message: "Not found." });

    // Recalculate live counts from logs (more accurate than stored counters)
    const [liveCounts] = await q(
      `SELECT
         COUNT(*)                                        AS total_targets,
         SUM(delivery_status = 'sent')                  AS sent_count,
         SUM(delivery_status = 'failed')                AS failed_count,
         SUM(delivery_status = 'pending')               AS pending_count,
         SUM(delivery_status = 'sent' AND opened_at IS NOT NULL) AS opened_count
       FROM global_notification_logs
       WHERE notification_id = ?`,
      [id],
    );
    notif.total_targets = liveCounts.total_targets || notif.total_targets;
    notif.sent_count = liveCounts.sent_count || 0;
    notif.failed_count = liveCounts.failed_count || 0;
    notif.opened_count = liveCounts.opened_count || 0;

    // Delivery status breakdown
    const breakdown = await q(
      `SELECT delivery_status, COUNT(*) AS count
       FROM   global_notification_logs
       WHERE  notification_id = ?
       GROUP  BY delivery_status`,
      [id],
    );

    // Targeted orgs
    const orgs = await q(
      `SELECT t.tenant_id, t.company_name, t.plan_id, t.status
       FROM   global_notification_targets gnt
       INNER  JOIN tenants t ON t.tenant_id COLLATE utf8mb4_unicode_ci
                              = gnt.tenant_id COLLATE utf8mb4_unicode_ci
       WHERE  gnt.notification_id = ?
       ORDER  BY t.company_name`,
      [id],
    );

    // Per-org delivery stats
    const orgStats = await q(
      `SELECT 
              gnl.tenant_id,
              t.company_name,
              SUM(gnl.delivery_status = 'sent')      AS sent,
              SUM(gnl.delivery_status = 'failed')    AS failed,
              SUM(gnl.delivery_status = 'pending')   AS pending,
               SUM(gnl.delivery_status = 'sent' AND gnl.opened_at IS NOT NULL) AS opened,
              COUNT(*)                               AS total
       FROM   global_notification_logs gnl
       LEFT JOIN tenants t 
             ON t.tenant_id COLLATE utf8mb4_unicode_ci 
              = gnl.tenant_id COLLATE utf8mb4_unicode_ci
       WHERE  gnl.notification_id = ?
       GROUP  BY gnl.tenant_id, t.company_name`,
      [id],
    );

    res.json({
      success: true,
      notification: notif,
      breakdown,
      orgs,
      org_stats: orgStats,
    });
  } catch (err) {
    console.error("[global-notif-routes] GET /:id:", err);
    res.status(500).json({
      success: false,
      message: "Failed to fetch notification detail.",
    });
  }
});

// ─── PATCH /:id/cancel ────────────────────────────────────────────────────────
// Cancel a scheduled notification.
router.patch("/:id/cancel", async (req, res) => {
  try {
    const { id } = req.params;
    const [result] = await db.query(
      `UPDATE global_notifications
       SET status = 'cancelled'
       WHERE id = ? AND status = 'scheduled'`,
      [id],
    );

    if (!result.affectedRows) {
      return res.status(400).json({
        success: false,
        message: "Notification not found or not in scheduled state.",
      });
    }

    res.json({ success: true, message: "Notification cancelled." });
  } catch (err) {
    console.error("[global-notif-routes] PATCH /:id/cancel:", err);
    res.status(500).json({ success: false, message: "Failed to cancel." });
  }
});

// ─── PATCH /:id/reschedule ────────────────────────────────────────────────────
// Update schedule time for a scheduled notification.
router.patch("/:id/reschedule", async (req, res) => {
  try {
    const { id } = req.params;
    const { scheduled_at } = req.body;

    if (!scheduled_at) {
      return res
        .status(400)
        .json({ success: false, message: "scheduled_at is required." });
    }

    const [result] = await db.query(
      `UPDATE global_notifications
       SET scheduled_at = ?
       WHERE id = ? AND status = 'scheduled'`,
      [new Date(scheduled_at), id],
    );

    if (!result.affectedRows) {
      return res.status(400).json({
        success: false,
        message: "Notification not found or not in scheduled state.",
      });
    }

    res.json({ success: true, message: "Schedule updated." });
  } catch (err) {
    console.error("[global-notif-routes] PATCH /:id/reschedule:", err);
    res.status(500).json({ success: false, message: "Failed to reschedule." });
  }
});

// ─── POST /:id/retry ──────────────────────────────────────────────────────────
// Retry all failed deliveries for a sent notification.
router.post("/:id/retry", async (req, res) => {
  try {
    const { id } = req.params;
    const result = await retryFailed(parseInt(id, 10));
    res.json({ success: true, ...result });
  } catch (err) {
    console.error("[global-notif-routes] POST /:id/retry:", err);
    res
      .status(500)
      .json({ success: false, message: err.message || "Retry failed." });
  }
});

// ─── GET /scheduled/upcoming ──────────────────────────────────────────────────
// All scheduled notifications ordered by fire time.
router.get("/scheduled/upcoming", async (req, res) => {
  try {
    const rows = await q(
      `SELECT id, title, type, scope, scheduled_at, created_by, created_at
       FROM   global_notifications
       WHERE  status = 'scheduled'
       ORDER  BY scheduled_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[global-notif-routes] GET /scheduled/upcoming:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch scheduled." });
  }
});

// ─── GET /analytics/summary ───────────────────────────────────────────────────
// 30-day trend + per-type breakdown.
router.get("/analytics/summary", async (req, res) => {
  try {
    const trend = await q(
      `SELECT DATE(created_at) AS date,
              COUNT(*)         AS total,
              SUM(sent_count)  AS sent,
              SUM(failed_count) AS failed,
              SUM(opened_count) AS opened
       FROM   global_notifications
       WHERE  created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
       GROUP  BY DATE(created_at)
       ORDER  BY date ASC`,
    );

    const byType = await q(
      `SELECT type,
              COUNT(*)                            AS total,
              SUM(sent_count)                     AS total_sent,
              SUM(failed_count)                   AS total_failed,
              ROUND(
                100.0 * SUM(opened_count) /
                NULLIF(SUM(sent_count), 0), 1
              )                                   AS open_rate
       FROM   global_notifications
       WHERE  status = 'sent'
       GROUP  BY type`,
    );

    res.json({ success: true, trend, by_type: byType });
  } catch (err) {
    console.error("[global-notif-routes] GET /analytics/summary:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch analytics." });
  }
});

// ─── POST /preview-targets ────────────────────────────────────────────────────
// Dry-run: how many employees / orgs would be targeted?
router.post("/preview-targets", async (req, res) => {
  try {
    const { scope, scope_meta, recipients = "all" } = req.body;
    const targets = await resolveTargets(scope, scope_meta || {}, recipients, {
      requireToken: false,
    });

    const tenantSet = [...new Set(targets.map((t) => t.tenant_id))];

    res.json({
      success: true,
      total_employees: targets.length,
      total_orgs: tenantSet.length,
      org_ids: tenantSet,
    });
  } catch (err) {
    console.error("[global-notif-routes] POST /preview-targets:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to preview targets." });
  }
});

// ─── POST /mark-opened ───────────────────────────────────────────────────────
// Called from the Flutter app when a notification is tapped.
// Does NOT require super admin auth — uses normal employee auth middleware.
router.post("/mark-opened", async (req, res) => {
  try {
    const { notification_id } = req.body;
    const empId = req.user?.emp_id;
    const tenantId = req.user?.tenant_id;

    if (!notification_id || !empId || !tenantId) {
      return res
        .status(400)
        .json({ success: false, message: "Missing fields." });
    }

    const { markOpened } = require("./global_notify");
    await markOpened(parseInt(notification_id, 10), empId, tenantId);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to mark opened." });
  }
});

module.exports = router;
