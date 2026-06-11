// department.js
require("dotenv").config();
const express = require("express");
const router = express.Router();
const pool = require("./config/db");

// GET /api/departments
router.get("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  try {
    const [rows] = await pool.query(
      `SELECT department_id AS id, department_name, status, created_at, updated_at
       FROM department_master
       WHERE tenant_id = ? AND is_deleted = 0
       ORDER BY department_name ASC`,
      [tenant_id],
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /departments]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});
// Reject obviously bad id values before /:id route runs
router.param('id', (req, res, next, id) => {
  if (id === 'undefined' || id === 'null' || id === '') {
    return res.status(400).json({ success: false, message: 'Invalid department id.' });
  }
  next();
});
// GET /api/departments/:id
router.get("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const deptId = parseInt(req.params.id, 10);
  if (isNaN(deptId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid department id." });
  try {
    const [[dept]] = await pool.query(
      `SELECT department_id AS id, department_name, status, created_at, updated_at
       FROM department_master
       WHERE department_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [deptId, tenant_id],
    );
    if (!dept)
      return res
        .status(404)
        .json({ success: false, message: "Department not found." });
    return res.json({ success: true, data: dept });
  } catch (err) {
    console.error("[GET /departments/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// POST /api/departments
router.post("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const { department_name, status = "Active" } = req.body;

  if (!department_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "department_name is required." });

  try {
    const [existing] = await pool.query(
      `SELECT department_id FROM department_master
       WHERE tenant_id = ? AND department_name = ? AND is_deleted = 0 LIMIT 1`,
      [tenant_id, department_name.trim()],
    );
    if (existing.length > 0)
      return res
        .status(409)
        .json({
          success: false,
          message: `Department '${department_name.trim()}' already exists.`,
        });

    const [result] = await pool.query(
      `INSERT INTO department_master (tenant_id, department_name, status, is_deleted, created_by, updated_by)
       VALUES (?, ?, ?, 0, ?, ?)`,
      [tenant_id, department_name.trim(), status, user_id, user_id],
    );
    return res.status(201).json({
      success: true,
      message: "Department created successfully.",
      data: {
        id: result.insertId,
        department_name: department_name.trim(),
        status,
      },
    });
  } catch (err) {
    console.error("[POST /departments]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// PUT /api/departments/:id
router.put("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const deptId = parseInt(req.params.id, 10);
  const { department_name, status } = req.body;

  if (isNaN(deptId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid department id." });
  if (!department_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "department_name is required." });

  try {
    const [[dept]] = await pool.query(
      `SELECT department_id FROM department_master
       WHERE department_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [deptId, tenant_id],
    );
    if (!dept)
      return res
        .status(404)
        .json({ success: false, message: "Department not found." });

    const [existing] = await pool.query(
      `SELECT department_id FROM department_master
       WHERE tenant_id = ? AND department_name = ? AND is_deleted = 0 AND department_id != ? LIMIT 1`,
      [tenant_id, department_name.trim(), deptId],
    );
    if (existing.length > 0)
      return res
        .status(409)
        .json({
          success: false,
          message: `Department '${department_name.trim()}' already exists.`,
        });

    await pool.query(
      `UPDATE department_master
       SET department_name = ?, status = ?, updated_by = ?, updated_at = NOW()
       WHERE department_id = ? AND tenant_id = ?`,
      [department_name.trim(), status, user_id, deptId, tenant_id],
    );
    return res.json({
      success: true,
      message: "Department updated successfully.",
      data: { id: deptId, department_name: department_name.trim(), status },
    });
  } catch (err) {
    console.error("[PUT /departments/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// DELETE /api/departments/:id
router.delete("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const deptId = parseInt(req.params.id, 10);

  if (isNaN(deptId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid department id." });

  try {
    const [[dept]] = await pool.query(
      `SELECT department_id FROM department_master
       WHERE department_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [deptId, tenant_id],
    );
    if (!dept)
      return res
        .status(404)
        .json({ success: false, message: "Department not found." });

    await pool.query(
      `UPDATE department_master
       SET is_deleted = 1, updated_by = ?, updated_at = NOW()
       WHERE department_id = ? AND tenant_id = ?`,
      [user_id, deptId, tenant_id],
    );
    return res.json({
      success: true,
      message: "Department deleted successfully.",
    });
  } catch (err) {
    console.error("[DELETE /departments/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
