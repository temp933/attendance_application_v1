// routes/plans.js

const express = require("express");
const router = express.Router();
const db = require("./config/db");

// GET /plans/list
router.get("/list", async (req, res) => {
  try {
    const sql = `
  SELECT
    p.plan_id,
    p.plan_name,
    p.plan_code,
    p.max_users,
    p.price_monthly,
    p.price_yearly,
    p.is_active,
    p.trial_days,          -- ← NEW
    p.billing_cycle,       -- ← NEW

    COUNT(
      CASE WHEN pm.is_included = 1 THEN pm.module_id END
    ) AS total_modules,

    JSON_ARRAYAGG(
      CASE WHEN pm.is_included = 1 THEN m.module_name END
    ) AS modules

  FROM plans p
  LEFT JOIN plan_modules pm ON pm.plan_id = p.plan_id
  LEFT JOIN modules m ON m.module_code = pm.module_id

  GROUP BY
    p.plan_id, p.plan_name, p.plan_code,
    p.max_users, p.price_monthly, p.price_yearly,
    p.is_active, p.trial_days, p.billing_cycle   -- ← NEW

  ORDER BY p.price_monthly ASC
`;

    const [rows] = await db.query(sql);

    const plans = rows.map((plan) => {
      // mysql2 already parses JSON columns into JS values.
      // If it's already an array, use it directly; only JSON.parse if it's a string.
      let rawModules = plan.modules;

      if (typeof rawModules === "string") {
        try {
          rawModules = JSON.parse(rawModules);
        } catch {
          rawModules = [];
        }
      }

      const modules = Array.isArray(rawModules)
        ? rawModules.filter(Boolean)
        : [];

      return { ...plan, modules };
    });

    res.status(200).json({ success: true, plans });
  } catch (error) {
    console.error("Plans Fetch Error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch plans",
      error: error.message,
    });
  }
});

module.exports = router;
