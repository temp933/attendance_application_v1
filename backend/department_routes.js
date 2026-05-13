// department_routes.js
require("dotenv").config();
const express = require("express");
const router = express.Router();
const db = require("./config/db");

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/departments — fetch all departments for the tenant
// ─────────────────────────────────────────────────────────────────────────────
router.get("/", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  if (!tenant_id)
    return res.status(400).json({
      success: false,
      message: "tenant_id required (x-tenant-id header).",
    });

  try {
    const [rows] = await db.query(
      `SELECT department_id AS id, department_name AS name, status
       FROM department_master
       WHERE tenant_id = ?
       ORDER BY department_name ASC`,
      [tenant_id],
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /departments]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/departments — add a department
// ─────────────────────────────────────────────────────────────────────────────
router.post("/", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const { department_name } = req.body;

  if (!tenant_id)
    return res.status(400).json({
      success: false,
      message: "tenant_id required (x-tenant-id header).",
    });
  if (!department_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "department_name is required." });

  try {
    // Duplicate check within same tenant
    const [existing] = await db.query(
      `SELECT department_id FROM department_master
       WHERE tenant_id = ? AND department_name = ? LIMIT 1`,
      [tenant_id, department_name.trim()],
    );
    if (existing.length > 0)
      return res.status(409).json({
        success: false,
        message: `Department '${department_name.trim()}' already exists.`,
      });

    const [result] = await db.query(
      `INSERT INTO department_master (tenant_id, department_name, status)
       VALUES (?, ?, 'Active')`,
      [tenant_id, department_name.trim()],
    );

    return res.status(201).json({
      success: true,
      message: "Department created.",
      data: {
        id: result.insertId,
        name: department_name.trim(),
        status: "Active",
      },
    });
  } catch (err) {
    console.error("[POST /departments]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/departments/:id — delete a department (only if no employees)
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/:id", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const deptId = parseInt(req.params.id, 10);

  if (!tenant_id)
    return res.status(400).json({
      success: false,
      message: "tenant_id required (x-tenant-id header).",
    });
  if (isNaN(deptId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid department id." });

  try {
    // Ownership check — ensure this dept belongs to the tenant
    const [[dept]] = await db.query(
      `SELECT department_id FROM department_master
       WHERE department_id = ? AND tenant_id = ? LIMIT 1`,
      [deptId, tenant_id],
    );
    if (!dept)
      return res
        .status(404)
        .json({ success: false, message: "Department not found." });

    // Safety check — block delete if employees are assigned
    const [[{ empCount }]] = await db.query(
      `SELECT COUNT(*) AS empCount FROM employee_master
       WHERE department_id = ? AND tenant_id = ? AND status = 'Active'`,
      [deptId, tenant_id],
    );
    if (empCount > 0)
      return res.status(409).json({
        success: false,
        message: `Cannot delete: ${empCount} active employee(s) are in this department. Transfer them first.`,
      });

    await db.query(
      `DELETE FROM department_master WHERE department_id = ? AND tenant_id = ?`,
      [deptId, tenant_id],
    );

    return res.json({ success: true, message: "Department deleted." });
  } catch (err) {
    console.error("[DELETE /departments/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/departments/:id/status — activate or deactivate
// ─────────────────────────────────────────────────────────────────────────────
router.put("/:id/status", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const deptId = parseInt(req.params.id, 10);
  const { status } = req.body;

  if (!tenant_id)
    return res.status(400).json({
      success: false,
      message: "tenant_id required (x-tenant-id header).",
    });
  if (isNaN(deptId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid department id." });
  if (!["Active", "Inactive"].includes(status))
    return res.status(400).json({
      success: false,
      message: "status must be 'Active' or 'Inactive'.",
    });

  try {
    const [result] = await db.query(
      `UPDATE department_master SET status = ?
       WHERE department_id = ? AND tenant_id = ?`,
      [status, deptId, tenant_id],
    );
    if (result.affectedRows === 0)
      return res
        .status(404)
        .json({ success: false, message: "Department not found." });

    return res.json({
      success: true,
      message: `Department ${status === "Active" ? "activated" : "deactivated"}.`,
    });
  } catch (err) {
    console.error("[PUT /departments/:id/status]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/departments/:id/employees — employees in a department
// ─────────────────────────────────────────────────────────────────────────────
router.get("/:id/employees", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const deptId = parseInt(req.params.id, 10);

  if (!tenant_id)
    return res.status(400).json({
      success: false,
      message: "tenant_id required (x-tenant-id header).",
    });
  if (isNaN(deptId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid department id." });

  try {
    const [rows] = await db.query(
      `SELECT emp_id, first_name, last_name, email_id, status
       FROM employee_master
       WHERE department_id = ? AND tenant_id = ? AND status = 'Active'
       ORDER BY first_name ASC`,
      [deptId, tenant_id],
    );
    return res.json(rows);
  } catch (err) {
    console.error("[GET /departments/:id/employees]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/departments/:id/transfer-employee — move employee to this dept
// ─────────────────────────────────────────────────────────────────────────────
router.put("/:id/transfer-employee", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const toDeptId = parseInt(req.params.id, 10);
  const { emp_id, reason } = req.body;

  if (!tenant_id)
    return res.status(400).json({
      success: false,
      message: "tenant_id required (x-tenant-id header).",
    });
  if (isNaN(toDeptId) || !emp_id)
    return res
      .status(400)
      .json({ success: false, message: "Valid dept id and emp_id required." });

  try {
    // Verify target dept belongs to tenant
    const [[dept]] = await db.query(
      `SELECT department_id FROM department_master
       WHERE department_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1`,
      [toDeptId, tenant_id],
    );
    if (!dept)
      return res
        .status(404)
        .json({ success: false, message: "Target department not found." });

    const [result] = await db.query(
      `UPDATE employee_master
       SET department_id = ?
       WHERE emp_id = ? AND tenant_id = ?`,
      [toDeptId, emp_id, tenant_id],
    );
    if (result.affectedRows === 0)
      return res
        .status(404)
        .json({ success: false, message: "Employee not found." });

    return res.json({
      success: true,
      message: "Employee transferred successfully.",
    });
  } catch (err) {
    console.error("[PUT /departments/:id/transfer-employee]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});


// GET /api/departments/:id/roles — roles for a specific department
router.get("/:id/roles", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const deptId = parseInt(req.params.id, 10);
  try {
    const [rows] = await db.query(
      `SELECT role_id, role_name, status 
       FROM role_master 
       WHERE department_id = ? AND tenant_id = ?
       ORDER BY role_name ASC`,
      [deptId, tenant_id]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// POST /api/departments/:id/roles — add role TO a specific department
router.post("/:id/roles", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const deptId = parseInt(req.params.id, 10);  // ← use actual dept id
  const { role_name } = req.body;
  try {
    const [existing] = await db.query(
      `SELECT role_id FROM role_master 
       WHERE tenant_id = ? AND department_id = ? AND role_name = ? LIMIT 1`,
      [tenant_id, deptId, role_name.trim()]
    );
    if (existing.length > 0)
      return res.status(409).json({ success: false, message: `Role already exists in this department.` });

    const [result] = await db.query(
      `INSERT INTO role_master (tenant_id, department_id, role_name) VALUES (?, ?, ?)`,
      [tenant_id, deptId, role_name.trim()]
    );
    return res.status(201).json({ success: true, data: { role_id: result.insertId, role_name: role_name.trim(), status: 'Active' } });
  } catch (err) {
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// PUT /api/departments/:id/roles/:roleId/status — activate/deactivate role
router.put("/:id/roles/:roleId/status", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const { status } = req.body;
  const roleId = parseInt(req.params.roleId, 10);
  try {
    await db.query(
      `UPDATE role_master SET status = ? WHERE role_id = ? AND tenant_id = ?`,
      [status, roleId, tenant_id]
    );
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// DELETE /api/departments/:id/roles/:roleId
router.delete("/:id/roles/:roleId", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const roleId = parseInt(req.params.roleId, 10);
  try {
    // Block if employees assigned
    const [[{ count }]] = await db.query(
      `SELECT COUNT(*) as count FROM employee_master WHERE role_id = ? AND tenant_id = ? AND status = 'Active'`,
      [roleId, tenant_id]
    );
    if (count > 0)
      return res.status(409).json({ success: false, message: `${count} active employee(s) have this role.` });

    await db.query(`DELETE FROM role_master WHERE role_id = ? AND tenant_id = ?`, [roleId, tenant_id]);
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ← module.exports MUST be here, at the bottom
module.exports = router;