// ============================================================
// backend/routes/app-admin/maintenance_dashboard.js
// Mount in server.js:
//   const maintenanceDashboard = require('./routes/app-admin/maintenance_dashboard');
//   app.use('/api/app-admin', verifyAppAdminToken, maintenanceDashboard);
// ============================================================

const express = require("express");
const router = express.Router();
const db = require("../config/db"); // adjust path to your db config

// ─────────────────────────────────────────────────────────────
// HELPER: promisified query
// ─────────────────────────────────────────────────────────────
function query(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.query(sql, params, (err, results) => {
      if (err) reject(err);
      else resolve(results);
    });
  });
}

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/dashboard/overview
// Returns all stats needed for the System Dashboard tab
// ─────────────────────────────────────────────────────────────
router.get("/dashboard/overview", async (req, res) => {
  try {
    // Org counts by status
    const orgStats = await query(`
      SELECT
        COUNT(*)                                          AS total_orgs,
        SUM(status = 'active')                           AS active_orgs,
        SUM(status = 'trial')                            AS trial_orgs,
        SUM(status = 'suspended')                        AS suspended_orgs,
        SUM(status = 'expired')                          AS expired_orgs,
        SUM(DATE(created_at) = CURDATE())                AS new_today,
        ROUND(AVG(DATEDIFF(COALESCE(plan_ends_at, trial_ends_at), CURDATE())), 0) AS avg_days_left
      FROM tenants
    `);

    // Employee counts
    const empStats = await query(`
      SELECT
        COUNT(*)                  AS total_employees,
        SUM(status = 'active')    AS active_employees,
        SUM(status = 'inactive')  AS inactive_employees
      FROM employee_master
    `);

    // Unresolved alert count
    const alertCount = await query(`
      SELECT COUNT(*) AS error_count
      FROM admin_alerts
      WHERE is_resolved = 0
    `);

    // Orgs expiring in next 7 days
    const expiringSoon = await query(`
      SELECT COUNT(*) AS expiring_soon
      FROM tenants
      WHERE (
        (status = 'active' AND plan_ends_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY))
        OR
        (status = 'trial'  AND trial_ends_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY))
      )
    `);

    res.json({
      success: true,
      data: {
        orgs: {
          total: orgStats[0].total_orgs || 0,
          active: orgStats[0].active_orgs || 0,
          trial: orgStats[0].trial_orgs || 0,
          suspended: orgStats[0].suspended_orgs || 0,
          expired: orgStats[0].expired_orgs || 0,
          new_today: orgStats[0].new_today || 0,
          avg_days_left: orgStats[0].avg_days_left || 0,
          expiring_soon: expiringSoon[0].expiring_soon || 0,
        },
        employees: {
          total: empStats[0].total_employees || 0,
          active: empStats[0].active_employees || 0,
          inactive: empStats[0].inactive_employees || 0,
        },
        alerts: {
          unresolved: alertCount[0].error_count || 0,
        },
      },
    });
  } catch (err) {
    console.error("Dashboard overview error:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch overview" });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/dashboard/growth-chart
// Returns last 30 days of org + employee registrations
// ─────────────────────────────────────────────────────────────
router.get("/dashboard/growth-chart", async (req, res) => {
  try {
    const orgGrowth = await query(`
      SELECT
        DATE(created_at) AS date,
        COUNT(*)         AS count
      FROM tenants
      WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `);

    const empGrowth = await query(`
      SELECT
        DATE(created_at) AS date,
        COUNT(*)         AS count
      FROM employee_master
      WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `);

    // Build full 30-day range with zeros for missing dates
    const days = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      days.push(d.toISOString().split("T")[0]);
    }

    const orgMap = Object.fromEntries(
      orgGrowth.map((r) => [r.date.toISOString().split("T")[0], r.count]),
    );
    const empMap = Object.fromEntries(
      empGrowth.map((r) => [r.date.toISOString().split("T")[0], r.count]),
    );

    const chartData = days.map((d) => ({
      date: d,
      new_orgs: orgMap[d] || 0,
      new_employees: empMap[d] || 0,
    }));

    res.json({ success: true, data: chartData });
  } catch (err) {
    console.error("Growth chart error:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch growth data" });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/dashboard/alerts
// Returns unresolved alerts
// ─────────────────────────────────────────────────────────────
router.get("/dashboard/alerts", async (req, res) => {
  try {
    // Auto-generate expiry alerts if not already present
    const expiringOrgs = await query(`
      SELECT tenant_id, company_name,
             COALESCE(plan_ends_at, trial_ends_at) AS expiry_date,
             DATEDIFF(COALESCE(plan_ends_at, trial_ends_at), CURDATE()) AS days_left
      FROM tenants
      WHERE (
        (status = 'active' AND plan_ends_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY))
        OR
        (status = 'trial'  AND trial_ends_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY))
      )
        AND tenant_id NOT IN (
          SELECT tenant_id FROM admin_alerts
          WHERE alert_type = 'ORG_EXPIRY_SOON'
            AND is_resolved = 0
            AND DATE(created_at) = CURDATE()
        )
    `);

    for (const org of expiringOrgs) {
      await query(
        `
        INSERT INTO admin_alerts (tenant_id, alert_type, severity, title, message)
        VALUES (?, 'ORG_EXPIRY_SOON', 'warning', ?, ?)
      `,
        [
          org.tenant_id,
          `${org.company_name} expires soon`,
          `Organization "${org.company_name}" expires in ${org.days_left} day(s) on ${org.expiry_date}.`,
        ],
      );
    }

    const alerts = await query(`
      SELECT alert_id, tenant_id, alert_type, severity, title, message, created_at
      FROM admin_alerts
      WHERE is_resolved = 0
      ORDER BY
        FIELD(severity, 'critical','warning','info'),
        created_at DESC
      LIMIT 50
    `);

    res.json({ success: true, data: alerts });
  } catch (err) {
    console.error("Alerts error:", err);
    res.status(500).json({ success: false, message: "Failed to fetch alerts" });
  }
});

// ─────────────────────────────────────────────────────────────
// PATCH /api/app-admin/dashboard/alerts/:alert_id/resolve
// ─────────────────────────────────────────────────────────────
router.patch("/dashboard/alerts/:alert_id/resolve", async (req, res) => {
  try {
    const { alert_id } = req.params;const admin_id = req.admin?.admin_id || null;

    await query(
      `
      UPDATE admin_alerts
      SET is_resolved = 1, resolved_at = NOW(), resolved_by = ?
      WHERE alert_id = ?
    `,
      [admin_id, alert_id],
    );

    res.json({ success: true, message: "Alert resolved" });
  } catch (err) {
    console.error("Resolve alert error:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to resolve alert" });
  }
});

// ─────────────────────────────────────────────────────────────
// POST /api/app-admin/activity-logs
// Log any admin action (call this internally from other routes)
// ─────────────────────────────────────────────────────────────
router.post("/activity-logs", async (req, res) => {
  try {
    const {
      tenant_id,
      action_type,
      action_details,
      status_before,
      status_after,
    } = req.body;const admin_id = req.admin?.admin_id || null;
    const ip_address = req.ip || req.headers["x-forwarded-for"] || null;

    await query(
      `
      INSERT INTO activity_logs
        (tenant_id, admin_id, action_type, action_details, status_before, status_after, ip_address)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
      [
        tenant_id,
        admin_id,
        action_type,
        action_details,
        status_before,
        status_after,
        ip_address,
      ],
    );

    res.json({ success: true });
  } catch (err) {
    console.error("Log activity error:", err);
    res.status(500).json({ success: false, message: "Failed to log activity" });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/activity-logs
// Paginated activity log list
// ─────────────────────────────────────────────────────────────
router.get("/activity-logs", async (req, res) => {
  try {
    const {
      tenant_id,
      action_type,
      from_date,
      to_date,
      page = 1,
      limit = 20,
    } = req.query;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const conditions = [];
    const params = [];

    if (tenant_id) {
      conditions.push("al.tenant_id = ?");
      params.push(tenant_id);
    }
    if (action_type) {
      conditions.push("al.action_type = ?");
      params.push(action_type);
    }
    if (from_date) {
      conditions.push("DATE(al.created_at) >= ?");
      params.push(from_date);
    }
    if (to_date) {
      conditions.push("DATE(al.created_at) <= ?");
      params.push(to_date);
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

    const logs = await query(
      `
      SELECT
        al.log_id, al.tenant_id, al.admin_id,
        al.action_type, al.action_details,
        al.status_before, al.status_after,
        al.ip_address, al.created_at,
        o.company_name
      FROM activity_logs al
      LEFT JOIN tenants o ON o.tenant_id = al.tenant_id
      ${where}
      ORDER BY al.created_at DESC
      LIMIT ? OFFSET ?
    `,
      [...params, parseInt(limit), offset],
    );

    const countResult = await query(
      `SELECT COUNT(*) AS total FROM activity_logs al ${where}`,
      params,
    );

    res.json({
      success: true,
      data: logs,
      pagination: {
        total: countResult[0].total,
        page: parseInt(page),
        limit: parseInt(limit),
        pages: Math.ceil(countResult[0].total / parseInt(limit)),
      },
    });
  } catch (err) {
    console.error("Activity logs error:", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch activity logs" });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/health-check
// Quick system health status
// ─────────────────────────────────────────────────────────────
router.get("/health-check", async (req, res) => {
  const checks = [];

  // 1. Database
  const dbStart = Date.now();
  try {
    await query("SELECT 1");
    checks.push({
      name: "Database",
      status: "healthy",
      response_ms: Date.now() - dbStart,
      message: "Connected",
    });
  } catch {
    checks.push({
      name: "Database",
      status: "critical",
      message: "Connection failed",
    });
  }

  // 2. Org count sanity
  try {
    const [{ cnt }] = await query("SELECT COUNT(*) AS cnt FROM tenants");
    checks.push({
      name: "Organizations",
      status: "healthy",
      message: `${cnt} tenants registered`,
      value: cnt,
    });
  } catch {
    checks.push({
      name: "Organizations",
      status: "warning",
      message: "Could not query",
    });
  }

  // 3. Unresolved alerts
  try {
    const [{ cnt }] = await query(
      "SELECT COUNT(*) AS cnt FROM admin_alerts WHERE is_resolved = 0 AND severity = 'critical'",
    );
    checks.push({
      name: "Critical Alerts",
      status: cnt > 0 ? "critical" : "healthy",
      message:
        cnt > 0 ? `${cnt} critical alerts unresolved` : "No critical alerts",
      value: cnt,
    });
  } catch {
    checks.push({
      name: "Critical Alerts",
      status: "warning",
      message: "Could not query",
    });
  }

  // 4. Expiring orgs
  try {
    const [{ cnt }] = await query(`
      SELECT COUNT(*) AS cnt FROM tenants
      WHERE status = 'active'
        AND plan_ends_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)
    `);
    checks.push({
      name: "Expiring Soon",
      status: cnt > 0 ? "warning" : "healthy",
      message:
        cnt > 0 ? `${cnt} orgs expiring in 7 days` : "No orgs expiring soon",
      value: cnt,
    });
  } catch {
    checks.push({
      name: "Expiring Soon",
      status: "warning",
      message: "Could not query",
    });
  }

  const overallStatus = checks.some((c) => c.status === "critical")
    ? "critical"
    : checks.some((c) => c.status === "warning")
      ? "warning"
      : "healthy";

  res.json({ success: true, overall: overallStatus, checks });
});

module.exports = router;
