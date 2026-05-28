// // role_routes.js  — Roles are tenant-scoped master data, NOT department-scoped
// require("dotenv").config();
// const express = require("express");
// const router = express.Router();
// const db = require("./config/db");

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/roles — fetch all roles for the tenant
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/", async (req, res) => {
//   const tenant_id = req.headers["x-tenant-id"];
//   if (!tenant_id)
//     return res
//       .status(400)
//       .json({
//         success: false,
//         message: "tenant_id required (x-tenant-id header).",
//       });

//   try {
//     const [rows] = await db.query(
//       `SELECT role_id AS id, role_name AS name, status
//        FROM role_master
//        WHERE tenant_id = ?
//        ORDER BY role_name ASC`,
//       [tenant_id],
//     );
//     return res.json({ success: true, data: rows });
//   } catch (err) {
//     console.error("[GET /roles]", err);
//     return res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/roles — add a role
// // ─────────────────────────────────────────────────────────────────────────────
// router.post("/", async (req, res) => {
//   const tenant_id = req.headers["x-tenant-id"];
//   const { role_name } = req.body;

//   if (!tenant_id)
//     return res
//       .status(400)
//       .json({
//         success: false,
//         message: "tenant_id required (x-tenant-id header).",
//       });
//   if (!role_name?.trim())
//     return res
//       .status(400)
//       .json({ success: false, message: "role_name is required." });

//   try {
//     const [existing] = await db.query(
//       `SELECT role_id FROM role_master
//        WHERE tenant_id = ? AND role_name = ? LIMIT 1`,
//       [tenant_id, role_name.trim()],
//     );
//     if (existing.length > 0)
//       return res.status(409).json({
//         success: false,
//         message: `Role '${role_name.trim()}' already exists.`,
//       });

//     const [result] = await db.query(
//       `INSERT INTO role_master (tenant_id, role_name, status) VALUES (?, ?, 'Active')`,
//       [tenant_id, role_name.trim()],
//     );

//     return res.status(201).json({
//       success: true,
//       message: "Role created.",
//       data: { id: result.insertId, name: role_name.trim(), status: "Active" },
//     });
//   } catch (err) {
//     console.error("[POST /roles]", err);
//     return res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // PUT /api/roles/:id — edit role name
// // ─────────────────────────────────────────────────────────────────────────────
// router.put("/:id", async (req, res) => {
//   const tenant_id = req.headers["x-tenant-id"];
//   const roleId = parseInt(req.params.id, 10);
//   const { role_name } = req.body;

//   if (!tenant_id)
//     return res
//       .status(400)
//       .json({
//         success: false,
//         message: "tenant_id required (x-tenant-id header).",
//       });
//   if (isNaN(roleId))
//     return res
//       .status(400)
//       .json({ success: false, message: "Invalid role id." });
//   if (!role_name?.trim())
//     return res
//       .status(400)
//       .json({ success: false, message: "role_name is required." });

//   try {
//     // Duplicate name check (excluding self)
//     const [dup] = await db.query(
//       `SELECT role_id FROM role_master
//        WHERE tenant_id = ? AND role_name = ? AND role_id != ? LIMIT 1`,
//       [tenant_id, role_name.trim(), roleId],
//     );
//     if (dup.length > 0)
//       return res.status(409).json({
//         success: false,
//         message: `Role '${role_name.trim()}' already exists.`,
//       });

//     const [result] = await db.query(
//       `UPDATE role_master SET role_name = ?
//        WHERE role_id = ? AND tenant_id = ?`,
//       [role_name.trim(), roleId, tenant_id],
//     );
//     if (result.affectedRows === 0)
//       return res
//         .status(404)
//         .json({ success: false, message: "Role not found." });

//     return res.json({ success: true, message: "Role updated." });
//   } catch (err) {
//     console.error("[PUT /roles/:id]", err);
//     return res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // PUT /api/roles/:id/status — activate / deactivate
// // ─────────────────────────────────────────────────────────────────────────────
// router.put("/:id/status", async (req, res) => {
//   const tenant_id = req.headers["x-tenant-id"];
//   const roleId = parseInt(req.params.id, 10);
//   const { status } = req.body;

//   if (!tenant_id)
//     return res
//       .status(400)
//       .json({
//         success: false,
//         message: "tenant_id required (x-tenant-id header).",
//       });
//   if (isNaN(roleId))
//     return res
//       .status(400)
//       .json({ success: false, message: "Invalid role id." });
//   if (!["Active", "Inactive"].includes(status))
//     return res
//       .status(400)
//       .json({
//         success: false,
//         message: "status must be 'Active' or 'Inactive'.",
//       });

//   try {
//     const [result] = await db.query(
//       `UPDATE role_master SET status = ?
//        WHERE role_id = ? AND tenant_id = ?`,
//       [status, roleId, tenant_id],
//     );
//     if (result.affectedRows === 0)
//       return res
//         .status(404)
//         .json({ success: false, message: "Role not found." });

//     return res.json({
//       success: true,
//       message: `Role ${status === "Active" ? "activated" : "deactivated"}.`,
//     });
//   } catch (err) {
//     console.error("[PUT /roles/:id/status]", err);
//     return res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // DELETE /api/roles/:id — delete role (blocked if employees hold it)
// // ─────────────────────────────────────────────────────────────────────────────
// router.delete("/:id", async (req, res) => {
//   const tenant_id = req.headers["x-tenant-id"];
//   const roleId = parseInt(req.params.id, 10);

//   if (!tenant_id)
//     return res
//       .status(400)
//       .json({
//         success: false,
//         message: "tenant_id required (x-tenant-id header).",
//       });
//   if (isNaN(roleId))
//     return res
//       .status(400)
//       .json({ success: false, message: "Invalid role id." });

//   try {
//     const [[role]] = await db.query(
//       `SELECT role_id FROM role_master WHERE role_id = ? AND tenant_id = ? LIMIT 1`,
//       [roleId, tenant_id],
//     );
//     if (!role)
//       return res
//         .status(404)
//         .json({ success: false, message: "Role not found." });

//     const [[{ empCount }]] = await db.query(
//       `SELECT COUNT(*) AS empCount FROM employee_master
//        WHERE role_id = ? AND tenant_id = ? AND status = 'Active'`,
//       [roleId, tenant_id],
//     );
//     if (empCount > 0)
//       return res.status(409).json({
//         success: false,
//         message: `Cannot delete: ${empCount} active employee(s) have this role. Reassign them first.`,
//       });

//     await db.query(
//       `DELETE FROM role_master WHERE role_id = ? AND tenant_id = ?`,
//       [roleId, tenant_id],
//     );

//     return res.json({ success: true, message: "Role deleted." });
//   } catch (err) {
//     console.error("[DELETE /roles/:id]", err);
//     return res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// module.exports = router;
