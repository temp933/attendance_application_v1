require("dotenv").config();
const express = require("express");
const router = express.Router();
const pool = require("./config/db");

// GET /api/designations
router.get("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const { department_id } = req.query;
  try {
    const [rows] = await pool.query(
      `SELECT d.designation_id AS id, d.designation_name, d.department_id,
              dm.department_name, d.status, d.created_at, d.updated_at
       FROM designation_master d
       LEFT JOIN department_master dm ON dm.department_id = d.department_id AND dm.is_deleted = 0
       WHERE d.tenant_id = ? AND d.is_deleted = 0
       ${department_id ? "AND d.department_id = ?" : ""}
       ORDER BY d.designation_name ASC`,
      department_id ? [tenant_id, department_id] : [tenant_id],
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /designations]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// GET /api/designations/:id
router.get("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const desgId = parseInt(req.params.id, 10);
  if (isNaN(desgId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid designation id." });
  try {
    const [[desg]] = await pool.query(
      `SELECT d.designation_id AS id, d.designation_name, d.department_id,
              dm.department_name, d.status, d.created_at, d.updated_at
       FROM designation_master d
       LEFT JOIN department_master dm ON dm.department_id = d.department_id AND dm.is_deleted = 0
       WHERE d.designation_id = ? AND d.tenant_id = ? AND d.is_deleted = 0 LIMIT 1`,
      [desgId, tenant_id],
    );
    if (!desg)
      return res
        .status(404)
        .json({ success: false, message: "Designation not found." });
    return res.json({ success: true, data: desg });
  } catch (err) {
    console.error("[GET /designations/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// POST /api/designations
router.post("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const { designation_name, department_id, status = "Active" } = req.body;

  if (!designation_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "designation_name is required." });
  if (!department_id)
    return res
      .status(400)
      .json({ success: false, message: "department_id is required." });

  try {
    const [existing] = await pool.query(
      `SELECT designation_id FROM designation_master
       WHERE tenant_id = ? AND designation_name = ? AND department_id = ? AND is_deleted = 0 LIMIT 1`,
      [tenant_id, designation_name.trim(), department_id],
    );
    if (existing.length > 0)
      return res.status(409).json({
        success: false,
        message: `Designation '${designation_name.trim()}' already exists in this department.`,
      });

    const [result] = await pool.query(
      `INSERT INTO designation_master (tenant_id, designation_name, department_id, status, is_deleted, created_by, updated_by)
       VALUES (?, ?, ?, ?, 0, ?, ?)`,
      [
        tenant_id,
        designation_name.trim(),
        department_id,
        status,
        user_id,
        user_id,
      ],
    );

    const [[created]] = await pool.query(
      `SELECT d.designation_id AS id, d.designation_name, d.department_id,
              dm.department_name, d.status
       FROM designation_master d
       LEFT JOIN department_master dm ON dm.department_id = d.department_id
       WHERE d.designation_id = ?`,
      [result.insertId],
    );

    return res.status(201).json({
      success: true,
      message: "Designation created successfully.",
      data: created,
    });
  } catch (err) {
    console.error("[POST /designations]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// PUT /api/designations/:id
router.put("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const desgId = parseInt(req.params.id, 10);
  const { designation_name, department_id, status } = req.body;

  if (isNaN(desgId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid designation id." });
  if (!designation_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "designation_name is required." });
  if (!department_id)
    return res
      .status(400)
      .json({ success: false, message: "department_id is required." });

  try {
    const [[desg]] = await pool.query(
      `SELECT designation_id FROM designation_master
       WHERE designation_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [desgId, tenant_id],
    );
    if (!desg)
      return res
        .status(404)
        .json({ success: false, message: "Designation not found." });

    const [existing] = await pool.query(
      `SELECT designation_id FROM designation_master
       WHERE tenant_id = ? AND designation_name = ? AND department_id = ? AND is_deleted = 0 AND designation_id != ? LIMIT 1`,
      [tenant_id, designation_name.trim(), department_id, desgId],
    );
    if (existing.length > 0)
      return res.status(409).json({
        success: false,
        message: `Designation '${designation_name.trim()}' already exists in this department.`,
      });

    await pool.query(
      `UPDATE designation_master
       SET designation_name = ?, department_id = ?, status = ?, updated_by = ?, updated_at = NOW()
       WHERE designation_id = ? AND tenant_id = ?`,
      [
        designation_name.trim(),
        department_id,
        status,
        user_id,
        desgId,
        tenant_id,
      ],
    );

    const [[updated]] = await pool.query(
      `SELECT d.designation_id AS id, d.designation_name, d.department_id,
              dm.department_name, d.status
       FROM designation_master d
       LEFT JOIN department_master dm ON dm.department_id = d.department_id
       WHERE d.designation_id = ?`,
      [desgId],
    );

    return res.json({
      success: true,
      message: "Designation updated successfully.",
      data: updated,
    });
  } catch (err) {
    console.error("[PUT /designations/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// DELETE /api/designations/:id
router.delete("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const desgId = parseInt(req.params.id, 10);

  if (isNaN(desgId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid designation id." });

  try {
    const [[desg]] = await pool.query(
      `SELECT designation_id FROM designation_master
       WHERE designation_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [desgId, tenant_id],
    );
    if (!desg)
      return res
        .status(404)
        .json({ success: false, message: "Designation not found." });

    await pool.query(
      `UPDATE designation_master
       SET is_deleted = 1, updated_by = ?, updated_at = NOW()
       WHERE designation_id = ? AND tenant_id = ?`,
      [user_id, desgId, tenant_id],
    );
    return res.json({
      success: true,
      message: "Designation deleted successfully.",
    });
  } catch (err) {
    console.error("[DELETE /designations/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
