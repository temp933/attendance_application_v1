// user notification_routes.js

"use strict";

const router = require("express").Router();
const db = require("./config/db");

// ─── GET /api/notifications/history ──────────────────────────────────────────
// Returns attendance reminder history for the authenticated employee.
// Query params: ?page=1&limit=20
router.get("/history", async (req, res) => {
  try {
    const empId = req.user.emp_id;
    const tenantId = req.user.tenant_id;
    const page = Math.max(1, parseInt(req.query.page || "1", 10));
    const limit = Math.min(50, parseInt(req.query.limit || "20", 10));
    const offset = (page - 1) * limit;

    const [rows] = await db.query(
      `
      SELECT
        id,
        title,
        body,
        reminder_type,
        is_read,
        read_at,
        sent_status,
        created_at
      FROM   notification_logs
      WHERE  tenant_id = ?
        AND  emp_id    = ?
        AND  sent_status != 'SKIPPED'
      ORDER  BY created_at DESC
      LIMIT  ? OFFSET ?
      `,
      [tenantId, empId, limit, offset],
    );

    // Unread count
    const [[{ unread_count }]] = await db.query(
      `SELECT COUNT(*) AS unread_count
       FROM   notification_logs
       WHERE  tenant_id = ? AND emp_id = ? AND is_read = 0`,
      [tenantId, empId],
    );

    res.json({
      success: true,
      page,
      limit,
      unread_count,
      data: rows,
    });
  } catch (err) {
    console.error("[notif-routes] GET /history:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch notifications." });
  }
});

// ─── GET /api/notifications/global-history ───────────────────────────────────
// Returns broadcast (global) notification history for the authenticated employee.
// Query params: ?page=1&limit=20
router.get("/global-history", async (req, res) => {
  try {
    const empId = req.user.emp_id;
    const tenantId = req.user.tenant_id;
    const page = Math.max(1, parseInt(req.query.page || "1", 10));
    const limit = Math.min(50, parseInt(req.query.limit || "20", 10));
    const offset = (page - 1) * limit;

    const [rows] = await db.query(
      `
      SELECT
        gn.id                           AS notification_id,
        gn.title,
        gn.message,
        gn.type,
        l.opened_at,
        COALESCE(gn.sent_at, l.sent_at) AS created_at
      FROM   global_notification_logs l
      INNER  JOIN global_notifications gn ON gn.id = l.notification_id
      WHERE  l.tenant_id = ?
        AND  l.emp_id    = ?
      ORDER  BY created_at DESC
      LIMIT  ? OFFSET ?
      `,
      [tenantId, empId, limit, offset],
    );

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
    console.error("[notif-routes] GET /global-history:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch broadcast history." });
  }
});

// ─── PATCH /api/notifications/:id/read ───────────────────────────────────────
// Mark a single notification as read.
router.patch("/:id/read", async (req, res) => {
  try {
    const empId = req.user.emp_id;
    const tenantId = req.user.tenant_id;
    const { id } = req.params;

    const [result] = await db.query(
      `
      UPDATE notification_logs
      SET    is_read = 1, read_at = NOW()
      WHERE  id        = ?
        AND  emp_id    = ?
        AND  tenant_id = ?
        AND  is_read   = 0
      `,
      [id, empId, tenantId],
    );

    if (result.affectedRows === 0) {
      return res.json({ success: true, message: "Already read or not found." });
    }

    res.json({ success: true, message: "Marked as read." });
  } catch (err) {
    console.error("[notif-routes] PATCH /:id/read:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to mark as read." });
  }
});

// ─── PATCH /api/notifications/read-all ───────────────────────────────────────
// Mark ALL unread notifications as read for the authenticated employee.
router.patch("/read-all", async (req, res) => {
  try {
    const empId = req.user.emp_id;
    const tenantId = req.user.tenant_id;

    await db.query(
      `
      UPDATE notification_logs
      SET    is_read = 1, read_at = NOW()
      WHERE  emp_id    = ?
        AND  tenant_id = ?
        AND  is_read   = 0
      `,
      [empId, tenantId],
    );

    res.json({ success: true, message: "All notifications marked as read." });
  } catch (err) {
    console.error("[notif-routes] PATCH /read-all:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to mark all as read." });
  }
});

// ─── POST /api/notifications/fcm-token ───────────────────────────────────────
// Called by Flutter on login / token refresh to save / update FCM token.
router.post("/fcm-token", async (req, res) => {
  try {
    const loginId = req.user.login_id;
    const { fcm_token, platform } = req.body;

    if (!fcm_token) {
      return res
        .status(400)
        .json({ success: false, message: "fcm_token is required." });
    }

    await db.query(
      `
       UPDATE login_master
      SET    fcm_token            = ?,
             device_platform      = ?,
             device_active        = 1,
             device_logged_in     = 1,
             notification_enabled = 1,
             fcm_updated_at       = NOW()
      WHERE  login_id = ?
      `,
      [fcm_token, platform || null, loginId],
    );

    res.json({ success: true, message: "FCM token saved." });
  } catch (err) {
    console.error("[notif-routes] POST /fcm-token:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to save FCM token." });
  }
});

// ─── DELETE /api/notifications/fcm-token ─────────────────────────────────────
// Called on logout — clears FCM token and marks device inactive.
router.delete("/fcm-token", async (req, res) => {
  try {
    const loginId = req.user.login_id;

    await db.query(
      `
       UPDATE login_master
      SET    fcm_token        = NULL,
             device_active    = 0,
             device_logged_in = 0,
             fcm_updated_at   = NOW()
      WHERE  login_id = ?
      `,
      [loginId],
    );

    res.json({ success: true, message: "FCM token removed." });
  } catch (err) {
    console.error("[notif-routes] DELETE /fcm-token:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to remove FCM token." });
  }
});

// ─── GET /api/notifications/missed-global ────────────────────────────────────
// Delivers every global notification this employee was ever a target for
// and has not yet successfully received. Never drops, never caps.
router.get("/missed-global", async (req, res) => {
  try {
    const empId = req.user.emp_id;
    const tenantId = req.user.tenant_id;
    const loginId = req.user.login_id;

    const [[loginRow]] = await db.query(
      `SELECT fcm_token FROM login_master
       WHERE login_id = ? AND fcm_token IS NOT NULL AND device_active = 1 LIMIT 1`,
      [loginId],
    );

    if (!loginRow?.fcm_token) {
      // No token yet — tell the client to retry shortly. Nothing is forgiven here.
      return res.json({
        success: true,
        pushed: 0,
        reason: "no_fcm_token",
        retry: true,
      });
    }

    const fcmToken = loginRow.fcm_token;

    // Every notification this tenant was targeted for, that this employee
    // does not yet have a 'sent' log row for. No date cutoff, no LIMIT.
    const owed = await db.query(
      `SELECT gn.id, gn.title, gn.message, gn.type
       FROM   global_notifications gn
       WHERE  gn.status = 'sent'
         AND  EXISTS (
                SELECT 1 FROM global_notification_targets t
                WHERE t.notification_id = gn.id
                  AND t.tenant_id COLLATE utf8mb4_unicode_ci
                    = ? COLLATE utf8mb4_unicode_ci
              )
         AND  NOT EXISTS (
                SELECT 1 FROM global_notification_logs l
                WHERE l.notification_id = gn.id
                  AND l.emp_id    = ?
                  AND l.tenant_id COLLATE utf8mb4_unicode_ci
                    = ? COLLATE utf8mb4_unicode_ci
                  AND l.delivery_status = 'sent'
              )
       ORDER  BY gn.sent_at ASC`,
      [tenantId, empId, tenantId],
    );

    if (!owed.length) {
      return res.json({ success: true, pushed: 0 });
    }

    const { getAdmin } = require("./firebase_admin");
    let pushed = 0;
    let failed = 0;

    for (const notif of owed) {
      try {
        await getAdmin()
          .messaging()
          .send({
            token: fcmToken,
            notification: { title: notif.title, body: notif.message },
            data: {
              type: "global_notification",
              notification_id: String(notif.id),
              notif_type: notif.type,
              missed: "true",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
              priority: "high",
              notification: { channelId: "global_alerts", sound: "default" },
            },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
          });

        await db.query(
          `INSERT INTO global_notification_logs
             (notification_id, tenant_id, emp_id, fcm_token, delivery_status, sent_at)
           VALUES (?, ?, ?, ?, 'sent', NOW())
           ON DUPLICATE KEY UPDATE
             delivery_status = 'sent',
             fcm_token       = VALUES(fcm_token),
             failure_reason  = NULL,
             sent_at         = COALESCE(sent_at, NOW())`,
          [notif.id, tenantId, empId, fcmToken],
        );
        // Also update the parent notification's counters
        await db.query(
          `UPDATE global_notifications
           SET sent_count     = (SELECT COUNT(*) FROM global_notification_logs
                                 WHERE notification_id = ? AND delivery_status = 'sent'),
               total_targets  = (SELECT COUNT(*) FROM global_notification_logs
                                 WHERE notification_id = ?),
               opened_count   = (SELECT COUNT(*) FROM global_notification_logs
                                 WHERE notification_id = ? AND delivery_status = 'sent'
                                   AND opened_at IS NOT NULL)
           WHERE id = ?`,
          [notif.id, notif.id, notif.id, notif.id],
        );
        pushed++;
      } catch (err) {
        failed++;
        // Stays 'failed', NOT excluded from future retries — this person
        // still owes nothing back to us, we owe them this notification.
        await db.query(
          `INSERT INTO global_notification_logs
             (notification_id, tenant_id, emp_id, fcm_token, delivery_status, failure_reason, sent_at)
           VALUES (?, ?, ?, ?, 'failed', ?, NOW())
           ON DUPLICATE KEY UPDATE
             delivery_status = 'failed', failure_reason = VALUES(failure_reason),
             fcm_token = VALUES(fcm_token), sent_at = NOW()`,
          [notif.id, tenantId, empId, fcmToken, err.message],
        );
        console.warn(
          `[owed-global] Failed notif #${notif.id} → emp ${empId}:`,
          err.message,
        );
      }
    }

    res.json({ success: true, pushed, failed, total_owed: owed.length });
  } catch (err) {
    console.error("[notif-routes] GET /missed-global:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to push owed notifications." });
  }
});

module.exports = router;
