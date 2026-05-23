require("dotenv").config();

const express = require("express");
const router = express.Router();
const db = require("./config/db");

// ─────────────────────────────────────────────────────────────
// ✅ FIXED APP ADMIN AUTH MIDDLEWARE
// ─────────────────────────────────────────────────────────────
function requireAppAdmin(req, res, next) {
  // safer header reading (fixes Postman / frontend mismatch issues)
  const usertype =
    req.headers["usertype"] ||
    req.headers["user-type"] ||
    req.headers["x-usertype"];

  const sessiontoken =
    req.headers["sessiontoken"] ||
    req.headers["session-token"] ||
    req.headers["x-sessiontoken"];

  // debug (remove in production)
  // console.log("HEADERS:", req.headers);

  if (!usertype || !sessiontoken) {
    return res.status(403).json({
      success: false,
      message: "Forbidden: Missing credentials",
    });
  }

  if (usertype !== "app_admin") {
    return res.status(403).json({
      success: false,
      message: "Forbidden: Invalid role",
    });
  }

  // NOTE: later you should verify sessiontoken from DB or JWT
  next();
}

// ── Add this helper near the top of the file ──────────────────────────────
function fmtDate(val) {
  if (!val) return null;
  // If MySQL already gave us a Date object, pull YYYY-MM-DD directly
  if (val instanceof Date) {
    const y = val.getFullYear();
    const m = String(val.getMonth() + 1).padStart(2, "0");
    const d = String(val.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }
  // If it's a string, slice the date part only
  return String(val).slice(0, 10);
}

function normalizeDates(org) {
  const dateFields = [
    "trial_ends_at",
    "plan_starts_at",
    "plan_ends_at",
    "created_at",
    "updated_at",
  ];
  for (const f of dateFields) {
    if (f in org) org[f] = fmtDate(org[f]);
  }
  return org;
}
// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/organizations
// ─────────────────────────────────────────────────────────────
router.get("/organizations", requireAppAdmin, async (req, res) => {
  try {
    const { status, search, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let conditions = [];
    let params = [];

    if (status && status !== "all") {
      conditions.push("t.status = ?");
      params.push(status);
    }

    if (search) {
      conditions.push(
        `(t.company_name LIKE ? OR t.company_code LIKE ? OR t.admin_email LIKE ? OR t.contact_person LIKE ?)`,
      );
      const like = `%${search}%`;
      params.push(like, like, like, like);
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

    // ── COUNT ──
    const [countRows] = await db.query(
      `SELECT COUNT(*) AS total FROM tenants t ${where}`,
      params,
    );

    const total = countRows[0].total;

    // ── MAIN DATA ──
    const [rows] = await db.query(
      `
      SELECT
        t.tenant_id,
        t.company_name,
        t.company_code,
        t.status,
        t.max_users,
        t.admin_email,
        t.hr_email,
        t.contact_number,
        t.contact_person,
        t.company_address,
        t.domain_name,
        t.gst_number,
        t.timezone,
        t.trial_ends_at,
        t.plan_starts_at,
        t.plan_ends_at,
        t.created_at,
        t.updated_at,
        p.plan_name,
        p.plan_code,
        p.price_monthly,
        p.price_yearly,

        COALESCE(emp.employee_count, 0) AS employee_count,
        COALESCE(emp.active_count, 0) AS active_employee_count,

        DATEDIFF(
          COALESCE(t.plan_ends_at, t.trial_ends_at),
          CURDATE()
        ) AS days_remaining

      FROM tenants t
      LEFT JOIN plans p ON p.plan_id = t.plan_id
      LEFT JOIN (
        SELECT
          tenant_id,
          COUNT(*) AS employee_count,
          SUM(status = 'active') AS active_count
        FROM employee_master
        GROUP BY tenant_id
      ) emp ON emp.tenant_id = t.tenant_id

      ${where}
      ORDER BY t.created_at DESC
      LIMIT ? OFFSET ?
      `,
      [...params, parseInt(limit), offset],
    );

    // ── DASHBOARD STATS ──
    const [statsRows] = await db.query(`
      SELECT
        COUNT(*) AS total_orgs,
        SUM(status = 'active') AS active_orgs,
        SUM(status = 'trial') AS trial_orgs,
        SUM(status = 'suspended') AS suspended_orgs,
        SUM(status = 'expired') AS expired_orgs,
        SUM(COALESCE(emp.employee_count, 0)) AS total_employees
      FROM tenants t
      LEFT JOIN (
        SELECT tenant_id, COUNT(*) AS employee_count
        FROM employee_master
        GROUP BY tenant_id
      ) emp ON emp.tenant_id = t.tenant_id
    `);

    return res.json({
      success: true,
      stats: statsRows[0],
      organizations: rows.map(normalizeDates),
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        total_pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (err) {
    console.error("GET /organizations error:", err);
    return res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/organizations/:tenant_id
// ─────────────────────────────────────────────────────────────
router.get("/organizations/:tenant_id", requireAppAdmin, async (req, res) => {
  try {
    const { tenant_id } = req.params;

    const [rows] = await db.query(
      `
        SELECT
          t.*,
          p.plan_name,
          p.plan_code,
          p.price_monthly,
          p.price_yearly,

          COALESCE(emp.employee_count, 0) AS employee_count,
          COALESCE(emp.active_count, 0) AS active_employee_count,
          COALESCE(emp.inactive_count, 0) AS inactive_employee_count,

          DATEDIFF(
            COALESCE(t.plan_ends_at, t.trial_ends_at),
            CURDATE()
          ) AS days_remaining

        FROM tenants t
        LEFT JOIN plans p ON p.plan_id = t.plan_id
        LEFT JOIN (
          SELECT
            tenant_id,
            COUNT(*) AS employee_count,
            SUM(status = 'active') AS active_count,
            SUM(status != 'active') AS inactive_count
          FROM employee_master
          GROUP BY tenant_id
        ) emp ON emp.tenant_id = t.tenant_id

        WHERE t.tenant_id = ?
        `,
      [tenant_id],
    );

    if (!rows.length) {
      return res.status(404).json({
        success: false,
        message: "Organization not found",
      });
    }

    return res.json({
      success: true,
      organization: normalizeDates(rows[0]),
    });
  } catch (err) {
    console.error("GET /organizations/:id error:", err);
    return res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

// ─────────────────────────────────────────────────────────────
// PATCH status
// ─────────────────────────────────────────────────────────────
router.patch(
  "/organizations/:tenant_id/status",
  requireAppAdmin,
  async (req, res) => {
    try {
      const { tenant_id } = req.params;
      const { status } = req.body;

      const allowed = ["active", "trial", "suspended", "expired"];

      if (!allowed.includes(status)) {
        return res.status(400).json({
          success: false,
          message: "Invalid status",
        });
      }

      await db.query(
        "UPDATE tenants SET status = ?, updated_at = NOW() WHERE tenant_id = ?",
        [status, tenant_id],
      );

      return res.json({
        success: true,
        message: `Status updated to ${status}`,
      });
    } catch (err) {
      console.error("PATCH status error:", err);
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  },
);

// ─────────────────────────────────────────────────────────────
// PATCH plan
// ─────────────────────────────────────────────────────────────
router.patch(
  "/organizations/:tenant_id/plan",
  requireAppAdmin,
  async (req, res) => {
    try {
      const { tenant_id } = req.params;
      const { plan_id, plan_starts_at, plan_ends_at, max_users } = req.body;

      const fields = [];
      const vals = [];

      if (plan_id) {
        fields.push("plan_id = ?");
        vals.push(plan_id);
      }
      if (plan_starts_at) {
        fields.push("plan_starts_at = ?");
        vals.push(plan_starts_at);
      }
      if (plan_ends_at) {
        fields.push("plan_ends_at = ?");
        vals.push(plan_ends_at);
      }
      if (max_users) {
        fields.push("max_users = ?");
        vals.push(parseInt(max_users));
      }

      if (!fields.length) {
        return res.status(400).json({
          success: false,
          message: "Nothing to update",
        });
      }

      fields.push("updated_at = NOW()");
      vals.push(tenant_id);

      await db.query(
        `UPDATE tenants SET ${fields.join(", ")} WHERE tenant_id = ?`,
        vals,
      );

      return res.json({
        success: true,
        message: "Plan updated",
      });
    } catch (err) {
      console.error("PATCH plan error:", err);
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  },
);

module.exports = router;
