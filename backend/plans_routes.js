// plans_routes.js
require("dotenv").config();
const express = require("express");
const router = express.Router();
const db = require("./config/db");
const { v4: uuidv4 } = require("uuid");

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/app-admin/plans
// ─────────────────────────────────────────────────────────────────────────────
router.get("/", async (req, res) => {
  try {
    const [plans] = await db.query(
      `SELECT
          p.plan_id, p.plan_name, p.plan_code, p.max_users,
          p.price_monthly, p.price_yearly, p.is_active,
          p.created_at, p.updated_at,
          COUNT(DISTINCT CASE WHEN pm.is_included = 1 THEN pm.module_id END) AS module_count,
          COUNT(DISTINCT t.tenant_id) AS tenant_count
       FROM plans p
       LEFT JOIN plan_modules pm ON p.plan_id = pm.plan_id
       LEFT JOIN tenants t ON p.plan_id = t.plan_id AND t.status != 'suspended'
       GROUP BY p.plan_id
       ORDER BY p.price_monthly ASC`,
    );

    const [planModules] = await db.query(
      `SELECT pm.plan_id, pm.module_id, pm.is_included,
              sm.module_name, sm.module_code, sm.category, sm.description
       FROM plan_modules pm
       JOIN system_modules sm ON pm.module_id = sm.module_id
       ORDER BY sm.category ASC, sm.module_name ASC`,
    );

    const modulesByPlan = {};
    for (const m of planModules) {
      if (!modulesByPlan[m.plan_id]) modulesByPlan[m.plan_id] = [];
      modulesByPlan[m.plan_id].push(m);
    }

    const result = plans.map((p) => ({
      ...p,
      modules: modulesByPlan[p.plan_id] || [],
    }));

    res.json({ success: true, data: result, total: result.length });
  } catch (err) {
    console.error("[GET /plans]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/app-admin/plans/:planId
// ─────────────────────────────────────────────────────────────────────────────
router.get("/:planId", async (req, res) => {
  const { planId } = req.params;
  try {
    const [[plan]] = await db.query(
      `SELECT plan_id, plan_name, plan_code, max_users,
              price_monthly, price_yearly, is_active, created_at, updated_at
       FROM plans WHERE plan_id = ? LIMIT 1`,
      [planId],
    );

    if (!plan) {
      return res
        .status(404)
        .json({ success: false, message: "Plan not found" });
    }

    const [modules] = await db.query(
      `SELECT sm.module_id, sm.module_name, sm.module_code,
              sm.category, sm.description,
              COALESCE(pm.is_included, 0) AS is_included
       FROM system_modules sm
       LEFT JOIN plan_modules pm
         ON sm.module_id = pm.module_id AND pm.plan_id = ?
       WHERE sm.is_active = 1
       ORDER BY sm.category ASC, sm.module_name ASC`,
      [planId],
    );

    const [[tcRow]] = await db.query(
      `SELECT COUNT(*) AS tenant_count FROM tenants
       WHERE plan_id = ? AND status != 'suspended'`,
      [planId],
    );

    res.json({
      success: true,
      data: { ...plan, modules, tenant_count: tcRow?.tenant_count ?? 0 },
    });
  } catch (err) {
    console.error("[GET /plans/:planId]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/app-admin/plans
// ─────────────────────────────────────────────────────────────────────────────
router.post("/", async (req, res) => {
  const {
    plan_name,
    plan_code,
    max_users = 50,
    price_monthly = 0,
    price_yearly = 0,
    module_ids = [],
  } = req.body;

  if (!plan_name || !plan_code) {
    return res.status(400).json({
      success: false,
      message: "plan_name and plan_code are required",
    });
  }

  try {
    const [[existing]] = await db.query(
      `SELECT plan_id FROM plans WHERE plan_code = ? LIMIT 1`,
      [plan_code.toUpperCase()],
    );
    if (existing) {
      return res.status(409).json({
        success: false,
        message: `Plan code '${plan_code}' already exists`,
      });
    }

    const planId = uuidv4();

    await db.query(
      `INSERT INTO plans (plan_id, plan_name, plan_code, max_users, price_monthly, price_yearly, is_active)
       VALUES (?, ?, ?, ?, ?, ?, 1)`,
      [
        planId,
        plan_name.trim(),
        plan_code.toUpperCase().trim(),
        max_users,
        price_monthly,
        price_yearly,
      ],
    );

    const [allModules] = await db.query(
      `SELECT module_id FROM system_modules WHERE is_active = 1`,
    );

    if (allModules.length > 0) {
      const includedSet = new Set(module_ids);
      const placeholders = allModules.map(() => "(?, ?, ?)").join(", ");
      const values = allModules.flatMap((m) => [
        planId,
        m.module_id,
        includedSet.has(m.module_id) ? 1 : 0,
      ]);
      await db.query(
        `INSERT INTO plan_modules (plan_id, module_id, is_included) VALUES ${placeholders}`,
        values,
      );
    }

    res.status(201).json({
      success: true,
      message: "Plan created successfully",
      plan_id: planId,
    });
  } catch (err) {
    console.error("[POST /plans]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/app-admin/plans/:planId
// ─────────────────────────────────────────────────────────────────────────────
router.put("/:planId", async (req, res) => {
  const { planId } = req.params;
  const {
    plan_name,
    max_users,
    price_monthly,
    price_yearly,
    is_active,
    module_ids,
  } = req.body;

  try {
    const [[plan]] = await db.query(
      `SELECT plan_id FROM plans WHERE plan_id = ? LIMIT 1`,
      [planId],
    );
    if (!plan) {
      return res
        .status(404)
        .json({ success: false, message: "Plan not found" });
    }

    const updates = [];
    const vals = [];

    if (plan_name !== undefined) {
      updates.push("plan_name = ?");
      vals.push(plan_name.trim());
    }
    if (max_users !== undefined) {
      updates.push("max_users = ?");
      vals.push(max_users);
    }
    if (price_monthly !== undefined) {
      updates.push("price_monthly = ?");
      vals.push(price_monthly);
    }
    if (price_yearly !== undefined) {
      updates.push("price_yearly = ?");
      vals.push(price_yearly);
    }
    if (is_active !== undefined) {
      updates.push("is_active = ?");
      vals.push(is_active ? 1 : 0);
    }

    if (updates.length > 0) {
      vals.push(planId);
      await db.query(
        `UPDATE plans SET ${updates.join(", ")}, updated_at = NOW() WHERE plan_id = ?`,
        vals,
      );
    }

    if (Array.isArray(module_ids)) {
      const [allModules] = await db.query(
        `SELECT module_id FROM system_modules WHERE is_active = 1`,
      );
      const includedSet = new Set(module_ids);
      for (const m of allModules) {
        const isIncluded = includedSet.has(m.module_id) ? 1 : 0;
        await db.query(
          `INSERT INTO plan_modules (plan_id, module_id, is_included)
           VALUES (?, ?, ?)
           ON DUPLICATE KEY UPDATE is_included = ?`,
          [planId, m.module_id, isIncluded, isIncluded],
        );
      }
    }

    res.json({ success: true, message: "Plan updated successfully" });
  } catch (err) {
    console.error("[PUT /plans/:planId]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/app-admin/plans/:planId/toggle  (Flutter uses PUT, not PATCH)
// ─────────────────────────────────────────────────────────────────────────────
router.put("/:planId/toggle", async (req, res) => {
  const { planId } = req.params;
  try {
    const [[plan]] = await db.query(
      `SELECT plan_id, plan_name, is_active FROM plans WHERE plan_id = ? LIMIT 1`,
      [planId],
    );
    if (!plan) {
      return res
        .status(404)
        .json({ success: false, message: "Plan not found" });
    }

    if (plan.is_active === 1) {
      const [[countRow]] = await db.query(
        `SELECT COUNT(*) AS cnt FROM tenants WHERE plan_id = ? AND status = 'active'`,
        [planId],
      );
      if (countRow.cnt > 0) {
        return res.status(409).json({
          success: false,
          message: `Cannot deactivate — ${countRow.cnt} active company(s) are on this plan`,
        });
      }
    }

    const newStatus = plan.is_active === 1 ? 0 : 1;
    await db.query(
      `UPDATE plans SET is_active = ?, updated_at = NOW() WHERE plan_id = ?`,
      [newStatus, planId],
    );

    res.json({
      success: true,
      message: `Plan ${newStatus ? "activated" : "deactivated"} successfully`,
      is_active: newStatus,
    });
  } catch (err) {
    console.error("[PUT /plans/:planId/toggle]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/app-admin/plans/:planId
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/:planId", async (req, res) => {
  const { planId } = req.params;
  try {
    const [[plan]] = await db.query(
      `SELECT plan_id, plan_name FROM plans WHERE plan_id = ? LIMIT 1`,
      [planId],
    );
    if (!plan) {
      return res
        .status(404)
        .json({ success: false, message: "Plan not found" });
    }

    const [[countRow]] = await db.query(
      `SELECT COUNT(*) AS cnt FROM tenants WHERE plan_id = ?`,
      [planId],
    );
    if (countRow.cnt > 0) {
      return res.status(409).json({
        success: false,
        message: `Cannot delete — ${countRow.cnt} company(s) assigned to this plan. Deactivate it instead.`,
      });
    }

    await db.query(`DELETE FROM plan_modules WHERE plan_id = ?`, [planId]);
    await db.query(`DELETE FROM plans WHERE plan_id = ?`, [planId]);

    res.json({ success: true, message: "Plan deleted successfully" });
  } catch (err) {
    console.error("[DELETE /plans/:planId]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/app-admin/plans/:planId/companies
// ─────────────────────────────────────────────────────────────────────────────
router.get("/:planId/companies", async (req, res) => {
  const { planId } = req.params;
  try {
    const [companies] = await db.query(
      `SELECT t.tenant_id, t.company_name, t.company_code, t.status,
              t.max_users, t.created_at, t.plan_expires_at,
              COUNT(DISTINCT lm.login_id) AS user_count
       FROM tenants t
       LEFT JOIN login_master lm ON t.tenant_id = lm.tenant_id AND lm.status = 'Active'
       WHERE t.plan_id = ?
       GROUP BY t.tenant_id
       ORDER BY t.created_at DESC`,
      [planId],
    );
    res.json({ success: true, data: companies, total: companies.length });
  } catch (err) {
    console.error("[GET /plans/:planId/companies]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
