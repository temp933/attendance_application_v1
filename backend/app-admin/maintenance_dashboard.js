"use strict";

const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const mysqldump = require("mysqldump");

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — centralised DB query (same pattern as your server.js)
// ─────────────────────────────────────────────────────────────────────────────
const db = require("../config/db");

const dbQuery = (sql, params = []) =>
  db.query(sql, params).then(([rows]) => rows);

const dbOne = async (sql, params = []) => {
  const rows = await dbQuery(sql, params);
  return rows[0] || null;
};

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — mysql2 returns SUM()/AVG()/DECIMAL aggregates as strings by default;
// normalise numeric-looking strings back to JS numbers before sending JSON.
// ─────────────────────────────────────────────────────────────────────────────
const toNumbers = (row) => {
  if (!row) return row;
  const out = {};
  for (const [k, v] of Object.entries(row)) {
    out[k] =
      v === null || v === undefined
        ? v
        : typeof v === "string" && v !== "" && !isNaN(v)
          ? Number(v)
          : v;
  }
  return out;
};

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — log admin activity
// ─────────────────────────────────────────────────────────────────────────────
async function logActivity(
  req,
  {
    tenant_id = null,
    action_type,
    action_details,
    status_before = null,
    status_after = null,
  },
) {
  try {
    await dbQuery(
      `INSERT INTO activity_logs
        (tenant_id, admin_id, action_type, action_details, status_before, status_after, ip_address)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        tenant_id,
        req.admin?.admin_id ?? null,
        action_type,
        action_details,
        status_before,
        status_after,
        req.ip ?? null,
      ],
    );
  } catch (e) {
    console.error("[logActivity] failed:", e.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — create alert
// ─────────────────────────────────────────────────────────────────────────────
async function createAlert({
  tenant_id = null,
  alert_type,
  severity = "info",
  title,
  message,
}) {
  try {
    await dbQuery(
      `INSERT INTO admin_alerts (tenant_id, alert_type, severity, title, message)
       VALUES (?, ?, ?, ?, ?)`,
      [tenant_id, alert_type, severity, title, message],
    );
  } catch (e) {
    console.error("[createAlert] failed:", e.message);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1.  DASHBOARD OVERVIEW STATS
//     GET /api/app-admin/maintenance/overview
// ═════════════════════════════════════════════════════════════════════════════
router.get("/maintenance/overview", async (req, res) => {
  try {
    // Organisation counts by status
    const orgStats = await dbQuery(`
      SELECT
        COUNT(*)                                              AS total_orgs,
        SUM(status = 'active')                               AS active_orgs,
        SUM(status = 'trial')                                AS trial_orgs,
        SUM(status = 'suspended')                            AS suspended_orgs,
        SUM(status = 'expired')                              AS expired_orgs,
        SUM(DATE(created_at) = CURDATE())                    AS new_today,
        ROUND(AVG(DATEDIFF(COALESCE(plan_ends_at, trial_ends_at), CURDATE())), 1)
                                                             AS avg_days_remaining
      FROM tenants
      WHERE is_active = 1
    `);

    // Employee counts
    const empStats = await dbQuery(`
      SELECT
        COUNT(*)              AS total_employees,
        SUM(status = 'Active')  AS active_employees,
        SUM(status != 'Active') AS inactive_employees
      FROM employee_master
    `);

    // Last health check
    const lastHealth = await dbOne(`
      SELECT status FROM system_health_logs
      ORDER BY created_at DESC LIMIT 1
    `);

    // Active alert count
    const alertCount = await dbOne(`
      SELECT COUNT(*) AS cnt FROM admin_alerts WHERE is_resolved = 0
    `);

    res.json({
      success: true,
      data: {
        ...toNumbers(orgStats[0]),
        ...toNumbers(empStats[0]),
        system_health: lastHealth?.status ?? "unknown",
        active_alerts: alertCount?.cnt ?? 0,
      },
    });
  } catch (err) {
    console.error("[maintenance/overview]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch overview." });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// 2.  ORGANISATION MONITORING
// ═════════════════════════════════════════════════════════════════════════════

// GET /api/app-admin/maintenance/organizations
//   query: page, limit, search, status
router.get("/maintenance/organizations", async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page ?? 1, 10));
    const limit = Math.min(100, parseInt(req.query.limit ?? 20, 10));
    const offset = (page - 1) * limit;
    const search = req.query.search ? `%${req.query.search}%` : null;
    const status = req.query.status ?? null;

    let where = "WHERE t.is_active = 1";
    const params = [];

    if (status && status !== "all") {
      where += " AND t.status = ?";
      params.push(status);
    }
    if (search) {
      where +=
        " AND (t.company_name LIKE ? OR t.admin_email LIKE ? OR t.tenant_id LIKE ?)";
      params.push(search, search, search);
    }

    const total = await dbOne(
      `SELECT COUNT(*) AS cnt FROM tenants t ${where}`,
      params,
    );

    const rows = await dbQuery(
      `SELECT
          t.tenant_id, t.company_name, t.company_code, t.status,
          t.admin_email, t.hr_email, t.contact_person, t.contact_number,
          t.max_users, t.plan_id,
          t.trial_ends_at, t.plan_starts_at, t.plan_ends_at,
          t.created_at,
          DATEDIFF(COALESCE(t.plan_ends_at, t.trial_ends_at), CURDATE()) AS days_remaining,
          COUNT(DISTINCT e.emp_id) AS employee_count
       FROM tenants t
       LEFT JOIN employee_master e ON e.tenant_id = t.tenant_id AND e.status = 'Active'
       ${where}
       GROUP BY t.tenant_id
       ORDER BY t.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    res.json({
      success: true,
      data: rows,
      pagination: {
        page,
        limit,
        total: total?.cnt ?? 0,
        total_pages: Math.ceil((total?.cnt ?? 0) / limit),
      },
    });
  } catch (err) {
    console.error("[maintenance/organizations]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch organizations." });
  }
});

// GET /api/app-admin/maintenance/organizations/:tenantId
router.get("/maintenance/organizations/:tenantId", async (req, res) => {
  try {
    const { tenantId } = req.params;

    const org = await dbOne(
      `SELECT t.*,
          DATEDIFF(COALESCE(t.plan_ends_at, t.trial_ends_at), CURDATE()) AS days_remaining,
          COUNT(DISTINCT e.emp_id) AS employee_count
       FROM tenants t
       LEFT JOIN employee_master e ON e.tenant_id = t.tenant_id AND e.status = 'Active'
       WHERE t.tenant_id = ?
       GROUP BY t.tenant_id`,
      [tenantId],
    );

    if (!org)
      return res
        .status(404)
        .json({ success: false, message: "Organization not found." });

    // Health score: simple formula
    let score = 100;
    if (org.days_remaining !== null && org.days_remaining < 7) score -= 30;
    if (org.days_remaining !== null && org.days_remaining < 0) score -= 40;
    if (org.status === "suspended") score -= 50;
    if (org.status === "expired") score = 0;
    org.health_score = Math.max(0, score);

    res.json({ success: true, data: org });
  } catch (err) {
    console.error("[maintenance/organizations/:id]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch organization." });
  }
});

// PATCH /api/app-admin/maintenance/organizations/:tenantId/status
//   body: { status: 'active'|'suspended'|'expired' }
router.patch(
  "/maintenance/organizations/:tenantId/status",
  async (req, res) => {
    try {
      const { tenantId } = req.params;
      const { status } = req.body;
      const allowed = ["active", "suspended", "expired", "trial"];

      if (!allowed.includes(status)) {
        return res
          .status(400)
          .json({ success: false, message: "Invalid status value." });
      }

      const org = await dbOne(
        "SELECT status FROM tenants WHERE tenant_id = ?",
        [tenantId],
      );
      if (!org)
        return res
          .status(404)
          .json({ success: false, message: "Organization not found." });

      await dbQuery(
        "UPDATE tenants SET status = ?, updated_at = NOW() WHERE tenant_id = ?",
        [status, tenantId],
      );

      await logActivity(req, {
        tenant_id: tenantId,
        action_type: "UPDATE_ORG_STATUS",
        action_details: `Status changed to ${status}`,
        status_before: org.status,
        status_after: status,
      });

      res.json({
        success: true,
        message: `Organization status updated to ${status}.`,
      });
    } catch (err) {
      console.error("[maintenance/organizations/status]", err);
      res
        .status(500)
        .json({ success: false, message: "Failed to update status." });
    }
  },
);

// POST /api/app-admin/maintenance/organizations/:tenantId/reset-password
//   body: { new_password }
router.post(
  "/maintenance/organizations/:tenantId/reset-password",
  async (req, res) => {
    try {
      const { tenantId } = req.params;
      const { new_password } = req.body;

      if (!new_password || new_password.length < 6) {
        return res.status(400).json({
          success: false,
          message: "Password must be at least 6 characters.",
        });
      }

      const bcrypt = require("bcryptjs");

      // Find the Admin login for this tenant
      const adminLogin = await dbOne(
        `SELECT lm.login_id
       FROM login_master lm
       JOIN role_master rm ON rm.role_id = lm.role_id
       WHERE lm.tenant_id = ? AND rm.role_name = 'Admin'
       LIMIT 1`,
        [tenantId],
      );

      if (!adminLogin) {
        return res.status(404).json({
          success: false,
          message: "Admin login not found for this organization.",
        });
      }

      const hash = await bcrypt.hash(new_password, 12);
      await dbQuery(
        "UPDATE login_master SET password = ?, is_first_login = 1 WHERE login_id = ?",
        [hash, adminLogin.login_id],
      );

      await logActivity(req, {
        tenant_id: tenantId,
        action_type: "RESET_ADMIN_PASSWORD",
        action_details: "Admin password reset by app admin",
      });

      res.json({
        success: true,
        message: "Admin password reset successfully.",
      });
    } catch (err) {
      console.error("[maintenance/reset-password]", err);
      res
        .status(500)
        .json({ success: false, message: "Failed to reset password." });
    }
  },
);

// ═════════════════════════════════════════════════════════════════════════════
// 3.  SYSTEM HEALTH CHECKS
//     GET /api/app-admin/maintenance/health
// ═════════════════════════════════════════════════════════════════════════════
router.get("/maintenance/health", async (req, res) => {
  const checks = [];
  const start = Date.now();

  // — Database
  try {
    const t0 = Date.now();
    await dbQuery("SELECT 1");
    const ms = Date.now() - t0;
    const status = ms < 200 ? "healthy" : ms < 1000 ? "warning" : "critical";
    checks.push({
      name: "database",
      status,
      response_ms: ms,
      message: `Response ${ms}ms`,
    });
    await dbQuery(
      `INSERT INTO system_health_logs (check_type, status, metric_value, metric_unit, message)
       VALUES ('database', ?, ?, 'ms', ?)`,
      [status, ms, `DB ping ${ms}ms`],
    );
  } catch (e) {
    checks.push({
      name: "database",
      status: "critical",
      response_ms: null,
      message: e.message,
    });
    await createAlert({
      alert_type: "db_error",
      severity: "critical",
      title: "Database Error",
      message: e.message,
    });
  }

  // — API server (self)
  const apiMs = Date.now() - start;
  checks.push({
    name: "api_server",
    status: "healthy",
    response_ms: apiMs,
    message: `API up, ${apiMs}ms`,
  });

  // — Recent error count (activity_logs with action_type containing ERROR, last 24h)
  try {
    const errRow = await dbOne(
      `SELECT COUNT(*) AS cnt FROM activity_logs
       WHERE action_type LIKE '%ERROR%' AND created_at >= NOW() - INTERVAL 24 HOUR`,
    );
    const errCnt = errRow?.cnt ?? 0;
    const errStatus =
      errCnt === 0 ? "healthy" : errCnt < 10 ? "warning" : "critical";
    checks.push({
      name: "error_rate",
      status: errStatus,
      response_ms: null,
      message: `${errCnt} errors in last 24h`,
      value: errCnt,
    });
  } catch (e) {
    checks.push({ name: "error_rate", status: "unknown", message: e.message });
  }

  // — Backup status (last backup)
  try {
    const lastBackup = await dbOne(
      `SELECT status, completed_at FROM backup_records ORDER BY created_at DESC LIMIT 1`,
    );
    if (!lastBackup) {
      checks.push({
        name: "backup",
        status: "warning",
        message: "No backups found",
      });
    } else {
      const hoursAgo = lastBackup.completed_at
        ? Math.floor(
            (Date.now() - new Date(lastBackup.completed_at).getTime()) /
              3600000,
          )
        : null;
      const backupStatus =
        lastBackup.status === "completed" && hoursAgo !== null && hoursAgo < 25
          ? "healthy"
          : "warning";
      checks.push({
        name: "backup",
        status: backupStatus,
        message: lastBackup.completed_at
          ? `Last backup ${hoursAgo}h ago — ${lastBackup.status}`
          : `Last backup status: ${lastBackup.status}`,
      });
    }
  } catch (e) {
    checks.push({ name: "backup", status: "unknown", message: e.message });
  }

  // — Active alerts
  try {
    const alertRow = await dbOne(
      "SELECT COUNT(*) AS cnt FROM admin_alerts WHERE is_resolved = 0",
    );
    const cnt = alertRow?.cnt ?? 0;
    checks.push({
      name: "alerts",
      status: cnt === 0 ? "healthy" : cnt < 5 ? "warning" : "critical",
      message: `${cnt} unresolved alert(s)`,
      value: cnt,
    });
  } catch (e) {
    checks.push({ name: "alerts", status: "unknown", message: e.message });
  }

  const overallStatus = checks.some((c) => c.status === "critical")
    ? "critical"
    : checks.some((c) => c.status === "warning")
      ? "warning"
      : "healthy";

  res.json({
    success: true,
    data: {
      overall: overallStatus,
      checks,
      checked_at: new Date().toISOString(),
    },
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// 4.  ACTIVITY LOGS
// ═════════════════════════════════════════════════════════════════════════════

// GET /api/app-admin/maintenance/activity-logs
//   query: page, limit, action_type, tenant_id, date_from, date_to, search
router.get("/maintenance/activity-logs", async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page ?? 1, 10));
    const limit = Math.min(200, parseInt(req.query.limit ?? 50, 10));
    const offset = (page - 1) * limit;

    let where = "WHERE 1=1";
    const params = [];

    if (req.query.action_type) {
      where += " AND al.action_type = ?";
      params.push(req.query.action_type);
    }
    if (req.query.tenant_id) {
      where += " AND al.tenant_id = ?";
      params.push(req.query.tenant_id);
    }
    if (req.query.date_from) {
      where += " AND DATE(al.created_at) >= ?";
      params.push(req.query.date_from);
    }
    if (req.query.date_to) {
      where += " AND DATE(al.created_at) <= ?";
      params.push(req.query.date_to);
    }
    if (req.query.search) {
      where += " AND (al.action_details LIKE ? OR t.company_name LIKE ?)";
      params.push(`%${req.query.search}%`, `%${req.query.search}%`);
    }

    const total = await dbOne(
      `SELECT COUNT(*) AS cnt
       FROM activity_logs al
       LEFT JOIN tenants t ON t.tenant_id = al.tenant_id
       ${where}`,
      params,
    );

    const rows = await dbQuery(
      `SELECT al.*, t.company_name
       FROM activity_logs al
       LEFT JOIN tenants t ON t.tenant_id = al.tenant_id
       ${where}
       ORDER BY al.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    res.json({
      success: true,
      data: rows,
      pagination: {
        page,
        limit,
        total: total?.cnt ?? 0,
        total_pages: Math.ceil((total?.cnt ?? 0) / limit),
      },
    });
  } catch (err) {
    console.error("[maintenance/activity-logs]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch activity logs." });
  }
});

// GET /api/app-admin/maintenance/activity-logs/export
//   Returns CSV text
router.get("/maintenance/activity-logs/export", async (req, res) => {
  try {
    let where = "WHERE 1=1";
    const params = [];

    if (req.query.action_type) {
      where += " AND al.action_type = ?";
      params.push(req.query.action_type);
    }
    if (req.query.tenant_id) {
      where += " AND al.tenant_id = ?";
      params.push(req.query.tenant_id);
    }
    if (req.query.date_from) {
      where += " AND DATE(al.created_at) >= ?";
      params.push(req.query.date_from);
    }
    if (req.query.date_to) {
      where += " AND DATE(al.created_at) <= ?";
      params.push(req.query.date_to);
    }

    const rows = await dbQuery(
      `SELECT al.log_id, al.tenant_id, t.company_name, al.admin_id,
              al.action_type, al.action_details,
              al.status_before, al.status_after, al.ip_address, al.created_at
       FROM activity_logs al
       LEFT JOIN tenants t ON t.tenant_id = al.tenant_id
       ${where}
       ORDER BY al.created_at DESC
       LIMIT 10000`,
      params,
    );

    const header = [
      "log_id",
      "tenant_id",
      "company_name",
      "admin_id",
      "action_type",
      "action_details",
      "status_before",
      "status_after",
      "ip_address",
      "created_at",
    ];
    const escape = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
    const csv = [
      header.join(","),
      ...rows.map((r) => header.map((k) => escape(r[k])).join(",")),
    ].join("\n");

    res.setHeader("Content-Type", "text/csv");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="activity_logs_${Date.now()}.csv"`,
    );
    res.send(csv);
  } catch (err) {
    console.error("[activity-logs/export]", err);
    res.status(500).json({ success: false, message: "Export failed." });
  }
});

// POST /api/app-admin/maintenance/activity-logs/cleanup
//   body: { older_than_days: 90 }
router.post("/maintenance/activity-logs/cleanup", async (req, res) => {
  try {
    const days = parseInt(req.body.older_than_days ?? 90, 10);
    if (days < 7)
      return res
        .status(400)
        .json({ success: false, message: "Minimum retention is 7 days." });

    const result = await dbQuery(
      "DELETE FROM activity_logs WHERE created_at < NOW() - INTERVAL ? DAY",
      [days],
    );

    await logActivity(req, {
      action_type: "CLEANUP_LOGS",
      action_details: `Deleted activity logs older than ${days} days. Affected: ${result.affectedRows}`,
    });

    res.json({
      success: true,
      message: `Deleted ${result.affectedRows} log entries older than ${days} days.`,
    });
  } catch (err) {
    console.error("[activity-logs/cleanup]", err);
    res.status(500).json({ success: false, message: "Cleanup failed." });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// 5.  BACKUP & MAINTENANCE
// ═════════════════════════════════════════════════════════════════════════════

// Local disk for now — point BACKUP_DIR at a mounted/remote path later without
// touching anything below it.
const BACKUP_DIR =
  process.env.BACKUP_DIR || path.join(__dirname, "..", "backups");
if (!fs.existsSync(BACKUP_DIR)) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
}

// Runs the actual dump in the background; backup/start returns immediately.
async function runBackup(backupId) {
  const startedAt = Date.now();
  const filePath = path.join(BACKUP_DIR, `backup_${backupId}.sql.gz`);

  try {
    const dump = await mysqldump({
      connection: {
        host: process.env.DB_HOST || "localhost",
        user: process.env.DB_USER || "root",
        password: process.env.DB_PASSWORD || "2026",
        database: process.env.DB_NAME || "global_app",
      },
    });

    const sql = [dump.dump.schema, dump.dump.data, dump.dump.trigger]
      .filter(Boolean)
      .join("\n\n");

    fs.writeFileSync(filePath, zlib.gzipSync(sql));

    const sizeMb = fs.statSync(filePath).size / (1024 * 1024);
    const durationSeconds = Math.round((Date.now() - startedAt) / 1000);

    await dbQuery(
      `UPDATE backup_records
       SET status = 'completed',
           completed_at = NOW(),
           backup_duration_seconds = ?,
           backup_size_mb = ?,
           file_path = ?,
           notes = 'Backup completed successfully'
       WHERE backup_id = ?`,
      [durationSeconds, sizeMb, filePath, backupId],
    );
  } catch (e) {
    console.error("[runBackup]", e.message);
    await dbQuery(
      "UPDATE backup_records SET status = 'failed', notes = ? WHERE backup_id = ?",
      [e.message, backupId],
    );
    await createAlert({
      alert_type: "backup_failure",
      severity: "critical",
      title: "Backup Failed",
      message: `Backup ${backupId} failed: ${e.message}`,
    });
  }
}

// POST /api/app-admin/maintenance/backup/start
router.post("/maintenance/backup/start", async (req, res) => {
  try {
    const backupId = uuidv4();
    const backupType = req.body.backup_type ?? "full";

    await dbQuery(
      `INSERT INTO backup_records (backup_id, backup_type, status, triggered_by, started_at)
       VALUES (?, ?, 'running', 'manual', NOW())`,
      [backupId, backupType],
    );

    await logActivity(req, {
      action_type: "BACKUP_STARTED",
      action_details: `Manual ${backupType} backup initiated. ID: ${backupId}`,
    });

    // Don't await — let it run in the background, client polls history/status.
    runBackup(backupId).catch((e) =>
      console.error("[backup/start] unhandled:", e.message),
    );

    res.status(202).json({
      success: true,
      message: "Backup started.",
      backup_id: backupId,
    });
  } catch (err) {
    console.error("[backup/start]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to start backup." });
  }
});

// GET /api/app-admin/maintenance/backup/history
//   query: page, limit
router.get("/maintenance/backup/history", async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page ?? 1, 10));
    const limit = Math.min(100, parseInt(req.query.limit ?? 20, 10));
    const offset = (page - 1) * limit;

    const total = await dbOne("SELECT COUNT(*) AS cnt FROM backup_records");
    const rows = await dbQuery(
      `SELECT * FROM backup_records ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [limit, offset],
    );

    res.json({
      success: true,
      data: rows.map(toNumbers),
      pagination: {
        page,
        limit,
        total: total?.cnt ?? 0,
        total_pages: Math.ceil((total?.cnt ?? 0) / limit),
      },
    });
  } catch (err) {
    console.error("[backup/history]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch backup history." });
  }
});

// GET /api/app-admin/maintenance/backup/:backupId/status
router.get("/maintenance/backup/:backupId/status", async (req, res) => {
  try {
    const record = await dbOne(
      "SELECT * FROM backup_records WHERE backup_id = ?",
      [req.params.backupId],
    );
    if (!record)
      return res
        .status(404)
        .json({ success: false, message: "Backup record not found." });
    res.json({ success: true, data: record });
  } catch (err) {
    console.error("[backup/status]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch backup status." });
  }
});

// ─── Maintenance tasks ────────────────────────────────────────────────────────

// POST /api/app-admin/maintenance/tasks/optimize-db
router.post("/maintenance/tasks/optimize-db", async (req, res) => {
  try {
    // Get tables to optimize
    const tables = await dbQuery("SHOW TABLES");
    const tableNames = tables.map((r) => Object.values(r)[0]);

    // Run ANALYZE on each (safe, non-blocking equivalent of OPTIMIZE)
    for (const tbl of tableNames) {
      await dbQuery(`ANALYZE TABLE \`${tbl}\``).catch(() => {});
    }

    await logActivity(req, {
      action_type: "DB_OPTIMIZE",
      action_details: `Analyzed ${tableNames.length} tables`,
    });

    res.json({
      success: true,
      message: `Database optimization complete. ${tableNames.length} tables analyzed.`,
    });
  } catch (err) {
    console.error("[tasks/optimize-db]", err);
    res
      .status(500)
      .json({ success: false, message: "DB optimization failed." });
  }
});

// POST /api/app-admin/maintenance/tasks/health-check
//   Triggers a fresh health check and stores results
router.post("/maintenance/tasks/health-check", async (req, res) => {
  try {
    const t0 = Date.now();
    await dbQuery("SELECT 1");
    const ms = Date.now() - t0;
    const status = ms < 200 ? "healthy" : ms < 1000 ? "warning" : "critical";

    await dbQuery(
      `INSERT INTO system_health_logs (check_type, status, metric_value, metric_unit, message)
       VALUES ('manual_check', ?, ?, 'ms', ?)`,
      [status, ms, `Manual health check — DB ping ${ms}ms`],
    );

    await logActivity(req, {
      action_type: "HEALTH_CHECK",
      action_details: `Manual health check. DB: ${ms}ms, Status: ${status}`,
    });

    res.json({
      success: true,
      message: "Health check complete.",
      status,
      db_response_ms: ms,
    });
  } catch (err) {
    console.error("[tasks/health-check]", err);
    res.status(500).json({ success: false, message: "Health check failed." });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// 6.  ALERTS
// ═════════════════════════════════════════════════════════════════════════════

// GET /api/app-admin/maintenance/alerts
//   query: page, limit, severity, is_resolved
router.get("/maintenance/alerts", async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page ?? 1, 10));
    const limit = Math.min(200, parseInt(req.query.limit ?? 50, 10));
    const offset = (page - 1) * limit;

    let where = "WHERE 1=1";
    const params = [];

    if (req.query.severity) {
      where += " AND severity = ?";
      params.push(req.query.severity);
    }
    if (req.query.is_resolved !== undefined) {
      where += " AND is_resolved = ?";
      params.push(req.query.is_resolved === "true" ? 1 : 0);
    } else {
      // Default: show unresolved only
      where += " AND is_resolved = 0";
    }

    const total = await dbOne(
      `SELECT COUNT(*) AS cnt FROM admin_alerts ${where}`,
      params,
    );
    const rows = await dbQuery(
      `SELECT aa.*, t.company_name
       FROM admin_alerts aa
       LEFT JOIN tenants t ON t.tenant_id = aa.tenant_id
       ${where}
       ORDER BY aa.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    res.json({
      success: true,
      data: rows,
      pagination: {
        page,
        limit,
        total: total?.cnt ?? 0,
        total_pages: Math.ceil((total?.cnt ?? 0) / limit),
      },
    });
  } catch (err) {
    console.error("[maintenance/alerts]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch alerts." });
  }
});

// PATCH /api/app-admin/maintenance/alerts/:alertId/resolve
router.patch("/maintenance/alerts/:alertId/resolve", async (req, res) => {
  try {
    const { alertId } = req.params;

    const alert = await dbOne("SELECT * FROM admin_alerts WHERE alert_id = ?", [
      alertId,
    ]);
    if (!alert)
      return res
        .status(404)
        .json({ success: false, message: "Alert not found." });
    if (alert.is_resolved)
      return res
        .status(400)
        .json({ success: false, message: "Alert already resolved." });

    await dbQuery(
      `UPDATE admin_alerts
       SET is_resolved = 1, resolved_at = NOW(), resolved_by = ?
       WHERE alert_id = ?`,
      [String(req.admin?.admin_id ?? "system"), alertId],
    );

    await logActivity(req, {
      tenant_id: alert.tenant_id,
      action_type: "RESOLVE_ALERT",
      action_details: `Resolved alert #${alertId}: ${alert.title}`,
      status_before: "unresolved",
      status_after: "resolved",
    });

    res.json({ success: true, message: "Alert resolved." });
  } catch (err) {
    console.error("[alerts/resolve]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to resolve alert." });
  }
});

// POST /api/app-admin/maintenance/alerts/auto-generate
//   Scans tenants and creates alerts for expiring orgs, high error rate, etc.
router.post("/maintenance/alerts/auto-generate", async (req, res) => {
  try {
    let created = 0;

    // — Orgs expiring in ≤ 7 days
    const expiring = await dbQuery(
      `SELECT tenant_id, company_name,
              DATEDIFF(COALESCE(plan_ends_at, trial_ends_at), CURDATE()) AS days_left
       FROM tenants
       WHERE is_active = 1
         AND DATEDIFF(COALESCE(plan_ends_at, trial_ends_at), CURDATE()) BETWEEN 0 AND 7`,
    );

    for (const org of expiring) {
      // Avoid duplicate alerts
      const dup = await dbOne(
        `SELECT alert_id FROM admin_alerts
         WHERE tenant_id = ? AND alert_type = 'expiring_soon' AND is_resolved = 0`,
        [org.tenant_id],
      );
      if (!dup) {
        await createAlert({
          tenant_id: org.tenant_id,
          alert_type: "expiring_soon",
          severity: org.days_left <= 2 ? "critical" : "warning",
          title: "Subscription Expiring Soon",
          message: `${org.company_name} expires in ${org.days_left} day(s).`,
        });
        created++;
      }
    }

    // — High error rate (last 24h)
    const errRow = await dbOne(
      `SELECT COUNT(*) AS cnt FROM activity_logs
       WHERE action_type LIKE '%ERROR%' AND created_at >= NOW() - INTERVAL 24 HOUR`,
    );
    if ((errRow?.cnt ?? 0) >= 10) {
      const dup = await dbOne(
        `SELECT alert_id FROM admin_alerts
         WHERE alert_type = 'high_error_rate' AND is_resolved = 0
           AND created_at >= NOW() - INTERVAL 24 HOUR`,
      );
      if (!dup) {
        await createAlert({
          alert_type: "high_error_rate",
          severity: "critical",
          title: "High Error Rate",
          message: `${errRow.cnt} errors logged in the last 24 hours.`,
        });
        created++;
      }
    }

    await logActivity(req, {
      action_type: "AUTO_GENERATE_ALERTS",
      action_details: `Auto-generated ${created} alert(s)`,
    });

    res.json({
      success: true,
      message: `Auto-generated ${created} alert(s).`,
      created,
    });
  } catch (err) {
    console.error("[alerts/auto-generate]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to auto-generate alerts." });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// 7.  GROWTH STATS  (for dashboard charts)
//     GET /api/app-admin/maintenance/growth?days=30
// ═════════════════════════════════════════════════════════════════════════════
router.get("/maintenance/growth", async (req, res) => {
  try {
    const days = Math.min(365, parseInt(req.query.days ?? 30, 10));

    const orgGrowth = await dbQuery(
      `SELECT DATE(created_at) AS date, COUNT(*) AS count
       FROM tenants
       WHERE created_at >= CURDATE() - INTERVAL ? DAY
       GROUP BY DATE(created_at)
       ORDER BY date ASC`,
      [days],
    );

    const empGrowth = await dbQuery(
      `SELECT DATE(created_at) AS date, COUNT(*) AS count
       FROM employee_master
       WHERE created_at >= CURDATE() - INTERVAL ? DAY
       GROUP BY DATE(created_at)
       ORDER BY date ASC`,
      [days],
    );

    res.json({
      success: true,
      data: { org_growth: orgGrowth, emp_growth: empGrowth },
    });
  } catch (err) {
    console.error("[maintenance/growth]", err);
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch growth data." });
  }
});

// PATCH /api/app-admin/maintenance/organizations/:tenantId/logo
router.patch("/maintenance/organizations/:tenantId/logo", async (req, res) => {
  try {
    const { tenantId } = req.params;
    const { company_logo, company_logo_type } = req.body;

    if (!company_logo || !company_logo_type) {
      return res.status(400).json({
        success: false,
        message: "company_logo (base64) and company_logo_type are required.",
      });
    }

    const logoBuffer = Buffer.from(company_logo, "base64");

    await dbQuery(
      `UPDATE tenants
       SET company_logo = ?, company_logo_type = ?, updated_at = NOW()
       WHERE tenant_id = ?`,
      [logoBuffer, company_logo_type, tenantId],
    );

    res.json({ success: true, message: "Logo updated successfully." });
  } catch (err) {
    console.error("[organizations/logo]", err);
    res.status(500).json({ success: false, message: "Failed to update logo." });
  }
});
router.patch(
  "/maintenance/organizations/:tenantId/details",
  async (req, res) => {
    try {
      const { tenantId } = req.params;
      const {
        company_name,
        contact_person,
        contact_number,
        admin_email,
        hr_email,
        domain_name,
        gst_number,
        timezone,
        company_address,
        max_users,
      } = req.body;

      const org = await dbOne(
        "SELECT tenant_id FROM tenants WHERE tenant_id = ?",
        [tenantId],
      );
      if (!org) {
        return res
          .status(404)
          .json({ success: false, message: "Organization not found." });
      }

      await dbQuery(
        `UPDATE tenants
       SET company_name = ?, contact_person = ?, contact_number = ?, admin_email = ?, hr_email = ?,
           domain_name = ?, gst_number = ?, timezone = ?, company_address = ?,
           max_users = ?, updated_at = NOW()
       WHERE tenant_id = ?`,
        [
          company_name.trim(),
          contact_person ?? null,
          contact_number ?? null,
          admin_email ?? null,
          hr_email ?? null,
          domain_name ?? null,
          gst_number ?? null,
          timezone ?? null,
          company_address ?? null,
          max_users != null ? parseInt(max_users, 10) : null,
          tenantId,
        ],
      );

      await logActivity(req, {
        tenant_id: tenantId,
        action_type: "UPDATE_ORG_DETAILS",
        action_details: "Organization details updated by app admin",
      });

      res.json({
        success: true,
        message: "Organization details updated successfully.",
      });
    } catch (err) {
      console.error("[organizations/details]", err);
      res
        .status(500)
        .json({
          success: false,
          message: "Failed to update organization details.",
        });
    }
  },
);

module.exports = router;
