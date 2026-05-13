// holiday_routes.js
require("dotenv").config();

const express = require("express");
const router = express.Router();
const db = require("./config/db");

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/holidays?year=2026
// ─────────────────────────────────────────────────────────────────────────────
router.get("/", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const { year } = req.query;

  if (!tenant_id) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  }

  try {
    let query = `
  SELECT
    holiday_id, tenant_id, holiday_name,
    DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date,
    holiday_type, description, is_recurring,
    created_by, created_at, updated_at
  FROM holiday_master
  WHERE (tenant_id = ? OR tenant_id = 'global')
`;
    const params = [tenant_id];

    if (year) {
      query += ` AND YEAR(holiday_date) = ?`;
      params.push(year);
    }

    query += ` ORDER BY holiday_date ASC`;

    const [rows] = await db.query(query, params);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /holidays]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

router.post("/defaults", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const year = parseInt(req.query.year, 10) || new Date().getFullYear();
  const login_id = req.body?.login_id ?? null;

  if (!tenant_id) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  }

  try {
    // ✅ Use DATE_FORMAT to always get 'MM-DD' as a plain string
    const [defaults] = await db.query(`
      SELECT 
        holiday_name,
        DATE_FORMAT(holiday_date, '%m-%d') AS holiday_date,
        holiday_type, 
        description, 
        is_recurring
      FROM default_holiday_master
      ORDER BY holiday_date ASC
    `);

    let inserted = 0;
    let skipped = 0;

    for (const h of defaults) {
      const fullDate = `${year}-${h.holiday_date}`; // e.g. "2026-01-26" ✅

      const [exists] = await db.query(
        `SELECT holiday_id FROM holiday_master
         WHERE tenant_id = ? AND holiday_name = ? AND holiday_date = ?
         LIMIT 1`,
        [tenant_id, h.holiday_name, fullDate],
      );

      if (exists.length > 0) {
        skipped++;
        continue;
      }

      await db.query(
        `INSERT INTO holiday_master
           (tenant_id, holiday_name, holiday_date, holiday_type, description, is_recurring, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          tenant_id,
          h.holiday_name,
          fullDate,
          h.holiday_type,
          h.description || null,
          h.is_recurring ? 1 : 0,
          login_id,
        ],
      );
      inserted++;
    }

    return res.json({
      success: true,
      message: `${inserted} holiday${inserted !== 1 ? "s" : ""} added, ${skipped} skipped.`,
      inserted,
      skipped,
    });
  } catch (err) {
    console.error("[POST /holidays/defaults]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/holidays
// Add a single holiday
// ─────────────────────────────────────────────────────────────────────────────
router.post("/", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const {
    holiday_name,
    holiday_date,
    holiday_type,
    description,
    is_recurring,
    login_id,
  } = req.body;

  if (!tenant_id) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  }
  if (!holiday_name?.trim()) {
    return res
      .status(400)
      .json({ success: false, message: "holiday_name is required." });
  }
  if (!holiday_date) {
    return res
      .status(400)
      .json({ success: false, message: "holiday_date is required." });
  }

  try {
    const [existing] = await db.query(
      `SELECT holiday_id FROM holiday_master
       WHERE tenant_id = ? AND holiday_name = ? AND holiday_date = ?
       LIMIT 1`,
      [tenant_id, holiday_name.trim(), holiday_date],
    );
    if (existing.length > 0) {
      return res
        .status(409)
        .json({ success: false, message: "Holiday already exists." });
    }

    const [result] = await db.query(
      `INSERT INTO holiday_master
         (tenant_id, holiday_name, holiday_date, holiday_type, description, is_recurring, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        tenant_id,
        holiday_name.trim(),
        holiday_date,
        holiday_type || "National",
        description || null,
        is_recurring ? 1 : 0,
        login_id || null,
      ],
    );

    return res.status(201).json({
      success: true,
      message: "Holiday created.",
      data: { holiday_id: result.insertId },
    });
  } catch (err) {
    console.error("[POST /holidays]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/holidays/:id
// Update a holiday
// ─────────────────────────────────────────────────────────────────────────────
router.put("/:id", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const holidayId = parseInt(req.params.id, 10);
  const {
    holiday_name,
    holiday_date,
    holiday_type,
    description,
    is_recurring,
  } = req.body;

  if (!tenant_id)
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  if (isNaN(holidayId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid holiday id." });

  try {
    const [[holiday]] = await db.query(
      `SELECT holiday_id FROM holiday_master WHERE holiday_id = ? AND tenant_id = ? LIMIT 1`,
      [holidayId, tenant_id],
    );
    if (!holiday)
      return res
        .status(404)
        .json({ success: false, message: "Holiday not found." });

    const [duplicate] = await db.query(
      `SELECT holiday_id FROM holiday_master
       WHERE tenant_id = ? AND holiday_name = ? AND holiday_date = ? AND holiday_id != ?
       LIMIT 1`,
      [tenant_id, holiday_name.trim(), holiday_date, holidayId],
    );
    if (duplicate.length > 0) {
      return res.status(409).json({
        success: false,
        message: "Another holiday already exists on that date.",
      });
    }

    await db.query(
      `UPDATE holiday_master
       SET holiday_name = ?, holiday_date = ?, holiday_type = ?,
           description  = ?, is_recurring = ?
       WHERE holiday_id = ? AND tenant_id = ?`,
      [
        holiday_name.trim(),
        holiday_date,
        holiday_type,
        description || null,
        is_recurring ? 1 : 0,
        holidayId,
        tenant_id,
      ],
    );

    return res.json({ success: true, message: "Holiday updated." });
  } catch (err) {
    console.error("[PUT /holidays/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/holidays/:id
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/:id", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const holidayId = parseInt(req.params.id, 10);

  if (!tenant_id)
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  if (isNaN(holidayId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid holiday id." });

  try {
    const [[holiday]] = await db.query(
      `SELECT holiday_id FROM holiday_master WHERE holiday_id = ? AND tenant_id = ? LIMIT 1`,
      [holidayId, tenant_id],
    );
    if (!holiday)
      return res
        .status(404)
        .json({ success: false, message: "Holiday not found." });

    await db.query(
      `DELETE FROM holiday_master WHERE holiday_id = ? AND tenant_id = ?`,
      [holidayId, tenant_id],
    );

    return res.json({ success: true, message: "Holiday deleted." });
  } catch (err) {
    console.error("[DELETE /holidays/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
