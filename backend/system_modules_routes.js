require("dotenv").config();

const express = require("express");
const router = express.Router();
const db = require("./config/db");

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/system-modules
// ─────────────────────────────────────────────────────────────
router.get("/", async (req, res) => {
  try {
    const [modules] = await db.query(`
      SELECT
        module_id,
        module_key,
        module_name,
        module_code,
        category,
        description,
        is_active,
        sort_order,
        created_at
      FROM system_modules
      ORDER BY sort_order ASC
    `);

    res.json({
      success: true,
      data: modules,
      total: modules.length,
    });
  } catch (err) {
    console.error("[GET /system-modules]", err);

    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/app-admin/system-modules/:moduleId
// ─────────────────────────────────────────────────────────────
router.get("/:moduleId", async (req, res) => {
  const { moduleId } = req.params;

  try {
    const [[module]] = await db.query(
      `
      SELECT
        module_id,
        module_key,
        module_name,
        module_code,
        category,
        description,
        is_active,
        sort_order,
        created_at
      FROM system_modules
      WHERE module_id = ?
      LIMIT 1
      `,
      [moduleId],
    );

    if (!module) {
      return res.status(404).json({
        success: false,
        message: "Module not found",
      });
    }

    res.json({
      success: true,
      data: module,
    });
  } catch (err) {
    console.error("[GET /system-modules/:moduleId]", err);

    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

module.exports = router;
