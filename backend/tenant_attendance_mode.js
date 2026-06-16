// tenant_attendance_mode.js

"use strict";

const express = require("express");
const router = express.Router();
const db = require("./config/db");

router.get("/attendance-mode", async (req, res) => {
  const tenantId = req.user?.tenant_id ?? req.headers["x-tenant-id"];
  if (!tenantId) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id missing." });
  }

  try {
    const [[row]] = await db.query(
      `SELECT mode FROM tenant_attendance_mode WHERE tenant_id = ? LIMIT 1`,
      [tenantId],
    );

    if (!row) {
      return res
        .status(404)
        .json({ success: false, message: "Mode not configured." });
    }

    res.json({ success: true, mode: row.mode });
  } catch (err) {
    console.error("[GET /tenant/attendance-mode]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

router.get("/trial-status", async (req, res) => {
  const tenantId = req.user?.tenant_id ?? req.headers["x-tenant-id"];
  if (!tenantId) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id missing." });
  }

  try {
    const [[tenant]] = await db.query(
      `SELECT status, trial_ends_at, plan_id FROM tenants WHERE tenant_id = ? LIMIT 1`,
      [tenantId],
    );

    if (!tenant) {
      return res
        .status(404)
        .json({ success: false, message: "Tenant not found." });
    }

    const now = new Date();
    const trialEnd = tenant.trial_ends_at
      ? new Date(tenant.trial_ends_at)
      : null;
    const daysLeft = trialEnd
      ? Math.max(0, Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24)))
      : null;
    const isTrialActive =
      tenant.status === "trial" && daysLeft !== null && daysLeft > 0;
    const isTrialExpired =
      tenant.status === "trial" && daysLeft !== null && daysLeft <= 0;
    const requiresPayment = isTrialExpired || tenant.status === "expired";

    res.json({
      success: true,
      status: tenant.status,
      trial_ends_at: trialEnd ? trialEnd.toISOString().split("T")[0] : null,
      days_remaining: daysLeft,
      is_trial_active: isTrialActive,
      requires_payment: requiresPayment,
    });
  } catch (err) {
    console.error("[GET /tenant/trial-status]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// GET /api/tenant/my-org
router.get('/my-org', async (req, res) => {
  try {
    const tenantId = req.user.tenant_id ?? req.user.tenantId;

    const [rows] = await db.query(
      `SELECT t.*,
          DATEDIFF(COALESCE(t.plan_ends_at, t.trial_ends_at), CURDATE()) AS days_remaining,
          COUNT(DISTINCT e.emp_id) AS employee_count
       FROM tenants t
       LEFT JOIN employee_master e ON e.tenant_id = t.tenant_id AND e.status = 'Active'
       WHERE t.tenant_id = ?
       GROUP BY t.tenant_id`,
      [tenantId]
    );

    const org = rows[0];
    if (!org) return res.status(404).json({ success: false, message: 'Organization not found.' });

    let score = 100;
    if (org.days_remaining !== null && org.days_remaining < 7) score -= 30;
    if (org.days_remaining !== null && org.days_remaining < 0) score -= 40;
    if (org.status === 'suspended') score -= 50;
    if (org.status === 'expired') score = 0;
    org.health_score = Math.max(0, score);

    if (org.company_logo && Buffer.isBuffer(org.company_logo)) {
      org.company_logo = org.company_logo.toString('base64');
    }

    res.json({ success: true, data: org });
  } catch (err) {
    console.error('[tenant/my-org]', err);
    res.status(500).json({ success: false, message: 'Failed to fetch organization.' });
  }
});

module.exports = router;
