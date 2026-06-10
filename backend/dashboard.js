const express = require("express");
const router = express.Router();
const db = require("./config/db");

// GET /api/dashboard
router.get("/", async (req, res) => {
  const tenantId = req.user?.tenant_id;
  if (!tenantId) {
    return res.status(401).json({ success: false, message: "Unauthorized." });
  }

  try {
    const today = new Date(Date.now() + 5.5 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);

    // 1. Total active employees
    const [[empRow]] = await db.query(
      `SELECT COUNT(*) AS totalEmployees
       FROM employee_master
       WHERE tenant_id = ? AND status = 'Active'`,
      [tenantId],
    );

    // 2. Present + late today (across all attendance modes)
    const [[attRow]] = await db.query(
      `SELECT
         COUNT(DISTINCT employee_id) AS present,
         SUM(is_late = 1)            AS lateEntry
       FROM employee_attendance
       WHERE tenant_id = ? AND work_date = ?`,
      [tenantId, today],
    );

    const totalEmployees = parseInt(empRow.totalEmployees ?? 0, 10);
    const present = parseInt(attRow.present ?? 0, 10);
    const lateEntry = parseInt(attRow.lateEntry ?? 0, 10);
    const absent = Math.max(0, totalEmployees - present);

    // 3. Active sites today
    let activeSites = 0;
    try {
      const [[siteRow]] = await db.query(
        `SELECT COUNT(*) AS activeSites
         FROM sites
         WHERE tenant_id = ?
           AND start_date <= ? AND end_date >= ?`,
        [tenantId, today, today],
      );
      activeSites = parseInt(siteRow?.activeSites ?? 0, 10);
    } catch (_) {}

    // 4. Pending leave requests
    let pendingRequests = 0;
    try {
      const [[leaveRow]] = await db.query(
        `SELECT COUNT(*) AS pendingRequests
         FROM leave_master
         WHERE tenant_id = ? AND final_status = 'Pending'`,
        [tenantId],
      );
      pendingRequests = parseInt(leaveRow?.pendingRequests ?? 0, 10);
    } catch (_) {}

    res.json({
      success: true,
      totalEmployees,
      present,
      absent,
      lateEntry,
      activeSites,
      pendingRequests,
    });
  } catch (err) {
    console.error("[GET /api/dashboard]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
