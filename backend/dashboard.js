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
         SUM(is_late = 1)       AS lateEntry
       FROM employee_attendance
       WHERE tenant_id = ? AND work_date = ?`,
      [tenantId, today],
    );

    const totalEmployees = parseInt(empRow.totalEmployees ?? 0, 10);
    const present = parseInt(attRow.present ?? 0, 10);
    const lateEntry = parseInt(attRow.lateEntry ?? 0, 10);
    const absent = Math.max(0, totalEmployees - present);

    // 3. Site module check — only query sites if this tenant's role
    //    actually has the site_management module enabled
    let activeSites = 0;
    let hasSiteModule = false;
    try {
      const [[permRow]] = await db.query(
        `SELECT can_view
         FROM role_permissions
         WHERE tenant_id = ? AND role_id = ?
           AND module_key = 'site_management' AND can_view = 1
         LIMIT 1`,
        [tenantId, req.user?.role_id],
      );
      hasSiteModule = !!permRow;
    } catch (_) {}

    if (hasSiteModule) {
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
    }

    // 4. Pending leave requests
    let pendingLeave = 0;
    try {
      const [[leaveRow]] = await db.query(
        `SELECT COUNT(*) AS pendingRequests
         FROM leave_master
         WHERE tenant_id = ? AND final_status = 'Pending'`,
        [tenantId],
      );
      pendingLeave = parseInt(leaveRow?.pendingRequests ?? 0, 10);
    } catch (_) {}

    // 5. Pending profile/update requests
    let pendingProfile = 0;
    try {
      const [[reqRow]] = await db.query(
        `SELECT COUNT(*) AS pendingProfile
         FROM employee_pending_request
         WHERE tenant_id = ? AND admin_approve = 'PENDING'`,
        [tenantId],
      );
      pendingProfile = parseInt(reqRow?.pendingProfile ?? 0, 10);
    } catch (_) {}

    const pendingRequests = pendingLeave + pendingProfile;

    res.json({
      success: true,
      totalEmployees,
      present,
      absent,
      lateEntry,
      activeSites,
      hasSiteModule,
      pendingRequests,
      pendingLeave,
      pendingProfile,
    });
  } catch (err) {
    console.error("[GET /api/dashboard]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// GET /api/dashboard/trend?days=7
// Daily present count for the last N days (default 7), oldest first
router.get("/trend", async (req, res) => {
  const tenantId = req.user?.tenant_id;
  if (!tenantId) {
    return res.status(401).json({ success: false, message: "Unauthorized." });
  }

  const days = Math.min(parseInt(req.query.days ?? "7", 10) || 7, 30);

  try {
    const [rows] = await db.query(
      `SELECT
         work_date,
         COUNT(DISTINCT employee_id) AS present
       FROM employee_attendance
       WHERE tenant_id = ?
         AND work_date >= DATE_SUB(
               DATE(CONVERT_TZ(NOW(), '+00:00', '+05:30')),
               INTERVAL ? DAY
             )
       GROUP BY work_date
       ORDER BY work_date ASC`,
      [tenantId, days - 1],
    );

    // Backfill missing dates with 0 so the chart always has `days` points
    const result = [];
    const byDate = {};
    rows.forEach((r) => {
      const key = new Date(r.work_date).toISOString().slice(0, 10);
      byDate[key] = parseInt(r.present, 10);
    });

    const now = new Date(Date.now() + 5.5 * 60 * 60 * 1000);
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      result.push({ date: key, present: byDate[key] ?? 0 });
    }

    res.json({ success: true, data: result });
  } catch (err) {
    console.error("[GET /api/dashboard/trend]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// GET /api/dashboard/department-breakdown
// Today's attendance % per department
router.get("/department-breakdown", async (req, res) => {
  const tenantId = req.user?.tenant_id;
  if (!tenantId) {
    return res.status(401).json({ success: false, message: "Unauthorized." });
  }

  try {
    const today = new Date(Date.now() + 5.5 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);

    const [rows] = await db.query(
      `SELECT
         dm.department_id,
         dm.department_name,
         COUNT(DISTINCT e.emp_id) AS total,
         COUNT(DISTINCT a.employee_id) AS present
       FROM department_master dm
       JOIN designation_master ds
         ON ds.department_id = dm.department_id
        AND ds.tenant_id = dm.tenant_id
       JOIN employee_master e
         ON e.designation_id = ds.designation_id
        AND e.tenant_id = dm.tenant_id
        AND e.status = 'Active'
       LEFT JOIN employee_attendance a
         ON a.employee_id = e.emp_id
        AND a.tenant_id = dm.tenant_id
        AND a.work_date = ?
       WHERE dm.tenant_id = ?
       GROUP BY dm.department_id, dm.department_name
       ORDER BY dm.department_name ASC`,
      [today, tenantId],
    );

    const data = rows.map((r) => {
      const total = parseInt(r.total, 10) || 0;
      const present = parseInt(r.present, 10) || 0;
      const pct = total > 0 ? Math.round((present / total) * 100) : 0;
      return {
        departmentId: r.department_id,
        departmentName: r.department_name,
        total,
        present,
        percentage: pct,
      };
    });

    res.json({ success: true, data });
  } catch (err) {
    console.error("[GET /api/dashboard/department-breakdown]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
