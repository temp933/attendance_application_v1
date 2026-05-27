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
          ) AS days_remaining,

          COALESCE(
            (SELECT JSON_ARRAYAGG(sm.module_name)
             FROM plan_modules pm
             JOIN system_modules sm ON sm.module_id = pm.module_id
             WHERE pm.plan_id = t.plan_id AND pm.is_included = 1),
            JSON_ARRAY()
          ) AS modules

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

router.patch(
  "/organizations/:tenant_id/details",
  requireAppAdmin,
  async (req, res) => {
    try {
      const { tenant_id } = req.params;

      // Allowed fields that can be updated
      const ALLOWED = [
        "company_name",
        "company_code",
        "admin_email",
        "hr_email",
        "contact_person",
        "contact_number",
        "company_address",
        "domain_name",
        "gst_number",
        "timezone",
      ];

      const fields = [];
      const vals = [];

      for (const key of ALLOWED) {
        if (key in req.body) {
          // Allow empty string to clear optional fields,
          // but reject null/undefined for required fields
          if (
            (key === "company_name" || key === "admin_email") &&
            !req.body[key]?.trim()
          ) {
            return res.status(400).json({
              success: false,
              message: `${key} is required and cannot be empty`,
            });
          }
          fields.push(`${key} = ?`);
          // Trim strings; store empty string as NULL for optional fields
          const value = req.body[key]?.toString().trim() ?? "";
          const isRequired = key === "company_name" || key === "admin_email";
          vals.push(isRequired || value.length > 0 ? value : null);
        }
      }

      if (!fields.length) {
        return res.status(400).json({
          success: false,
          message: "No valid fields provided to update",
        });
      }

      // Check org exists
      const [check] = await db.query(
        "SELECT tenant_id FROM tenants WHERE tenant_id = ?",
        [tenant_id],
      );
      if (!check.length) {
        return res.status(404).json({
          success: false,
          message: "Organization not found",
        });
      }

      fields.push("updated_at = NOW()");
      vals.push(tenant_id);

      await db.query(
        `UPDATE tenants SET ${fields.join(", ")} WHERE tenant_id = ?`,
        vals,
      );

      // Return fresh org data
      const [rows] = await db.query(
        `SELECT t.*,
          p.plan_name, p.plan_code, p.price_monthly, p.price_yearly,
          COALESCE(emp.employee_count, 0) AS employee_count,
          COALESCE(emp.active_count, 0) AS active_employee_count,
          DATEDIFF(COALESCE(t.plan_ends_at, t.trial_ends_at), CURDATE()) AS days_remaining,
          COALESCE(
            (SELECT JSON_ARRAYAGG(sm.module_name)
             FROM plan_modules pm
             JOIN system_modules sm ON sm.module_id = pm.module_id
             WHERE pm.plan_id = t.plan_id AND pm.is_included = 1),
            JSON_ARRAY()
          ) AS modules
         FROM tenants t
         LEFT JOIN plans p ON p.plan_id = t.plan_id
         LEFT JOIN (
           SELECT tenant_id, COUNT(*) AS employee_count,
                  SUM(status = 'active') AS active_count
           FROM employee_master GROUP BY tenant_id
         ) emp ON emp.tenant_id = t.tenant_id
         WHERE t.tenant_id = ?`,
        [tenant_id],
      );
      return res.json({
        success: true,
        message: "Details updated successfully",
        organization: normalizeDates(rows[0]),
      });
    } catch (err) {
      console.error("PATCH details error:", err);
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  },
);

// ─────────────────────────────────────────────────────────────
// POST /api/app-admin/organizations/:tenant_id/reset-password
// ─────────────────────────────────────────────────────────────
router.post(
  "/organizations/:tenant_id/reset-password",
  requireAppAdmin,
  async (req, res) => {
    try {
      const { tenant_id } = req.params;

      // Check org exists and get admin email
      const [rows] = await db.query(
        "SELECT tenant_id, admin_email, company_name FROM tenants WHERE tenant_id = ?",
        [tenant_id],
      );

      if (!rows.length) {
        return res.status(404).json({
          success: false,
          message: "Organization not found",
        });
      }

      const { admin_email, company_name } = rows[0];

      // ── TODO: plug in your real email/reset logic here ──
      // e.g. generate a token, store it, send via nodemailer / SendGrid
      // For now we just acknowledge the request
      console.log(
        `[reset-password] Reset requested for ${admin_email} (${company_name})`,
      );

      return res.json({
        success: true,
        message: `Password reset link sent to ${admin_email}`,
        admin_email,
      });
    } catch (err) {
      console.error("POST reset-password error:", err);
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
      const {
        plan_id,
        plan_starts_at,
        plan_ends_at,
        trial_ends_at,
        max_users,
      } = req.body;

      const fields = [];
      const vals = [];

      if (plan_id !== undefined) {
        fields.push("plan_id = ?");
        vals.push(plan_id || null); // allow clearing plan
      }
      if (plan_starts_at !== undefined) {
        fields.push("plan_starts_at = ?");
        vals.push(plan_starts_at || null);
      }
      if (plan_ends_at !== undefined) {
        fields.push("plan_ends_at = ?");
        vals.push(plan_ends_at || null);
      }
      if (trial_ends_at !== undefined) {
        fields.push("trial_ends_at = ?");
        vals.push(trial_ends_at || null);
      }
      if (max_users !== undefined) {
        const mu = parseInt(max_users);
        if (isNaN(mu) || mu < 1) {
          return res.status(400).json({
            success: false,
            message: "max_users must be a positive integer",
          });
        }
        fields.push("max_users = ?");
        vals.push(mu);
      }

      if (!fields.length) {
        return res.status(400).json({
          success: false,
          message: "Nothing to update",
        });
      }

      // Check org exists
      const [check] = await db.query(
        "SELECT tenant_id FROM tenants WHERE tenant_id = ?",
        [tenant_id],
      );
      if (!check.length) {
        return res.status(404).json({
          success: false,
          message: "Organization not found",
        });
      }

      fields.push("updated_at = NOW()");
      vals.push(tenant_id);

      await db.query(
        `UPDATE tenants SET ${fields.join(", ")} WHERE tenant_id = ?`,
        vals,
      );

      // Return fresh org data
      const [rows] = await db.query(
        `SELECT t.*,
          p.plan_name, p.plan_code, p.price_monthly, p.price_yearly,
          COALESCE(emp.employee_count, 0) AS employee_count,
          COALESCE(emp.active_count, 0) AS active_employee_count,
          DATEDIFF(COALESCE(t.plan_ends_at, t.trial_ends_at), CURDATE()) AS days_remaining,
          COALESCE(
            (SELECT JSON_ARRAYAGG(sm.module_name)
             FROM plan_modules pm
             JOIN system_modules sm ON sm.module_id = pm.module_id
             WHERE pm.plan_id = t.plan_id AND pm.is_included = 1),
            JSON_ARRAY()
          ) AS modules
         FROM tenants t
         LEFT JOIN plans p ON p.plan_id = t.plan_id
         LEFT JOIN (
           SELECT tenant_id, COUNT(*) AS employee_count,
                  SUM(status = 'active') AS active_count
           FROM employee_master GROUP BY tenant_id
         ) emp ON emp.tenant_id = t.tenant_id
         WHERE t.tenant_id = ?`,
        [tenant_id],
      );

      return res.json({
        success: true,
        message: "Plan updated",
        organization: normalizeDates(rows[0]),
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
