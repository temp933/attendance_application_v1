// notification_routes.js


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
      SET    fcm_token          = ?,
             device_platform    = ?,
             device_active      = 1,
             notification_enabled = 1,
             fcm_updated_at     = NOW()
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
      SET    fcm_token     = NULL,
             device_active = 0,
             fcm_updated_at = NOW()
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

module.exports = router;
