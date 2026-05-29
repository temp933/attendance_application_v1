require("dotenv").config();
const express = require("express");
const router = express.Router();
const pool = require("./config/db");

// GET /api/roles
router.get("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  try {
    const [rows] = await pool.query(
      `SELECT role_id AS id, role_name, status, created_at, updated_at
       FROM role_master
       WHERE tenant_id = ? AND is_deleted = 0
       ORDER BY role_name ASC`,
      [tenant_id],
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /roles]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// GET /api/roles/:id
router.get("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const roleId = parseInt(req.params.id, 10);
  if (isNaN(roleId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid role id." });
  try {
    const [[role]] = await pool.query(
      `SELECT role_id AS id, role_name, status, created_at, updated_at
       FROM role_master
       WHERE role_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [roleId, tenant_id],
    );
    if (!role)
      return res
        .status(404)
        .json({ success: false, message: "Role not found." });
    return res.json({ success: true, data: role });
  } catch (err) {
    console.error("[GET /roles/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// POST /api/roles
router.post("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const { role_name, status = "Active" } = req.body;

  if (!role_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "role_name is required." });

  try {
    const [existing] = await pool.query(
      `SELECT role_id FROM role_master
       WHERE tenant_id = ? AND role_name = ? AND is_deleted = 0 LIMIT 1`,
      [tenant_id, role_name.trim()],
    );
    if (existing.length > 0)
      return res.status(409).json({
        success: false,
        message: `Role '${role_name.trim()}' already exists.`,
      });

    const [result] = await pool.query(
      `INSERT INTO role_master (tenant_id, role_name, status, is_deleted, created_by, updated_by)
       VALUES (?, ?, ?, 0, ?, ?)`,
      [tenant_id, role_name.trim(), status, user_id, user_id],
    );
    return res.status(201).json({
      success: true,
      message: "Role created successfully.",
      data: { id: result.insertId, role_name: role_name.trim(), status },
    });
  } catch (err) {
    console.error("[POST /roles]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// PUT /api/roles/:id
router.put("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const roleId = parseInt(req.params.id, 10);
  const { role_name, status } = req.body;

  if (isNaN(roleId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid role id." });
  if (!role_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "role_name is required." });

  try {
    const [[role]] = await pool.query(
      `SELECT role_id FROM role_master
       WHERE role_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [roleId, tenant_id],
    );
    if (!role)
      return res
        .status(404)
        .json({ success: false, message: "Role not found." });

    const [existing] = await pool.query(
      `SELECT role_id FROM role_master
       WHERE tenant_id = ? AND role_name = ? AND is_deleted = 0 AND role_id != ? LIMIT 1`,
      [tenant_id, role_name.trim(), roleId],
    );
    if (existing.length > 0)
      return res.status(409).json({
        success: false,
        message: `Role '${role_name.trim()}' already exists.`,
      });

    await pool.query(
      `UPDATE role_master
       SET role_name = ?, status = ?, updated_by = ?, updated_at = NOW()
       WHERE role_id = ? AND tenant_id = ?`,
      [role_name.trim(), status, user_id, roleId, tenant_id],
    );
    return res.json({
      success: true,
      message: "Role updated successfully.",
      data: { id: roleId, role_name: role_name.trim(), status },
    });
  } catch (err) {
    console.error("[PUT /roles/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// DELETE /api/roles/:id
router.delete("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const user_id = req.user.emp_id;
  const roleId = parseInt(req.params.id, 10);

  if (isNaN(roleId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid role id." });

  try {
    const [[role]] = await pool.query(
      `SELECT role_id FROM role_master
       WHERE role_id = ? AND tenant_id = ? AND is_deleted = 0 LIMIT 1`,
      [roleId, tenant_id],
    );
    if (!role)
      return res
        .status(404)
        .json({ success: false, message: "Role not found." });

    await pool.query(
      `UPDATE role_master
       SET is_deleted = 1, updated_by = ?, updated_at = NOW()
       WHERE role_id = ? AND tenant_id = ?`,
      [user_id, roleId, tenant_id],
    );
    return res.json({ success: true, message: "Role deleted successfully." });
  } catch (err) {
    console.error("[DELETE /roles/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
