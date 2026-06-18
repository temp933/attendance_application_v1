require("dotenv").config();
const express = require("express");
const router = express.Router();
const db = require("./config/db");
const authMiddleware = require("./middleware/auth");

// ─────────────────────────────────────────────────────────────────────────────
// All available modules (single source of truth)
// ─────────────────────────────────────────────────────────────────────────────
const ALL_MODULES = [
  // ── Employee-facing ──────────────────────────────────────────────
  { key: "emp_dashboard", label: "Employee Dashboard" },
  { key: "emp_attendance_normal", label: "Normal Attendance" },
  { key: "emp_attendance_gps", label: "GPS Attendance" },
  { key: "emp_attendance_face", label: "Face Attendance" },
  { key: "emp_site_attendance_face", label: "Site Entry Face Attendance" },
  { key: "emp_leave", label: "My Leave" },

  // ── Admin/HR-facing ──────────────────────────────────────────────
  { key: "admin_dashboard", label: "Admin Dashboard" },
  { key: "admin_attendance_normal", label: "Attendance Mgmt (Normal)" },
  { key: "admin_attendance_gps", label: "Attendance Mgmt (GPS)" },
  { key: "admin_attendance_face", label: "Attendance Mgmt (Face)" },
  { key: "admin_attendance_site", label: "Attendance Mgmt (Site)" },
  { key: "leave_approval", label: "Leave Approval" },
  { key: "manage_user", label: "Manage Users" },
  { key: "employee_profile", label: "Employee Profile" },
  { key: "dept_management", label: "Departments & Roles" },
  { key: "approval", label: "Approvals" },
  { key: "face_approval", label: "Face Approval" },
  { key: "session_management", label: "Session Management" },
  { key: "policy_management", label: "Policy Management" },
  { key: "site_management", label: "Site Management" },
  { key: "emp_profile", label: "My Profile" },
];

// ─────────────────────────────────────────────────────────────────────────────
// Auth
// ─────────────────────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  authMiddleware(req, res, () => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized." });
    }
    req.user.tenantId = req.user.tenant_id ?? req.headers["x-tenant-id"];
    next();
  });
}

function requireRole(...roles) {
  return (req, res, next) => {
    const role = (req.user.role_name || "").toLowerCase().trim();
    if (!roles.includes(role)) {
      return res.status(403).json({ success: false, message: "Forbidden." });
    }
    next();
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/role-permissions/modules
// Returns the full list of available modules
// ─────────────────────────────────────────────────────────────────────────────
router.get("/modules", requireAuth, requireRole("admin"), (req, res) => {
  res.json({ success: true, data: ALL_MODULES });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/role-permissions/roles
// Returns all active roles for the tenant
// ─────────────────────────────────────────────────────────────────────────────
router.get("/roles", requireAuth, requireRole("admin"), async (req, res) => {
  const { tenantId } = req.user;
  try {
    const [rows] = await db.query(
      `SELECT role_id, role_name
         FROM role_master
         WHERE tenant_id = ? AND status = 'Active' AND is_deleted = 0
         ORDER BY role_name`,
      [tenantId],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /role-permissions/roles]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/role-permissions?role_id=X
// Returns permissions for a specific role, merged with ALL_MODULES
// (modules not yet role_permissions default to can_view=0, can_edit=0)
// ─────────────────────────────────────────────────────────────────────────────
router.get("/", requireAuth, requireRole("admin"), async (req, res) => {
  const { tenantId } = req.user;
  const roleId = parseInt(req.query.role_id, 10);

  if (!roleId) {
    return res
      .status(400)
      .json({ success: false, message: "role_id is required." });
  }

  try {
    const [rows] = await db.query(
      `SELECT module_key, can_view, can_edit
       FROM role_permissions
       WHERE tenant_id = ? AND role_id = ?`,
      [tenantId, roleId],
    );

    // Build a map of saved permissions
    const saved = new Map(rows.map((r) => [r.module_key, r]));

    // Merge with ALL_MODULES so every module appears
    const data = ALL_MODULES.map((m) => ({
      module_key: m.key,
      label: m.label,
      can_view: saved.get(m.key)?.can_view ?? 0,
      can_edit: saved.get(m.key)?.can_edit ?? 0,
    }));

    res.json({ success: true, role_id: roleId, data });
  } catch (err) {
    console.error("[GET /role-permissions]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/role-permissions
// Save (upsert) all module permissions for a role
// Body: { role_id: 3, permissions: [ { module_key, can_view, can_edit }, ... ] }
// ─────────────────────────────────────────────────────────────────────────────
router.post("/", requireAuth, requireRole("admin"), async (req, res) => {
  const { tenantId } = req.user;
  const { role_id, permissions } = req.body;

  if (!role_id || !Array.isArray(permissions)) {
    return res.status(400).json({
      success: false,
      message: "role_id and permissions[] are required.",
    });
  }

  // Validate module keys
  const validKeys = new Set(ALL_MODULES.map((m) => m.key));
  const invalid = permissions.filter((p) => !validKeys.has(p.module_key));
  if (invalid.length > 0) {
    return res.status(400).json({
      success: false,
      message: `Invalid module keys: ${invalid.map((p) => p.module_key).join(", ")}`,
    });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Delete existing permissions for this role
    await conn.query(
      `DELETE FROM role_permissions WHERE tenant_id = ? AND role_id = ?`,
      [tenantId, role_id],
    );

    // Insert new permissions
    if (permissions.length > 0) {
      const values = permissions.map((p) => [
        tenantId,
        role_id,
        p.module_key,
        p.can_view ? 1 : 0,
        p.can_edit ? 1 : 0,
      ]);

      await conn.query(
        `INSERT INTO role_permissions (tenant_id, role_id, module_key, can_view, can_edit)
         VALUES ?`,
        [values],
      );
    }

    await conn.commit();

    res.json({
      success: true,
      message: "Permissions saved successfully.",
      role_id,
      saved: permissions.length,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[POST /role-permissions]", err);
    res.status(500).json({ success: false, message: "Server error." });
  } finally {
    conn.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/role-permissions/my-permissions
// Called after login — returns the current user's module permissions
// ─────────────────────────────────────────────────────────────────────────────
router.get("/my-permissions", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const roleId = parseInt(req.user.roleId ?? req.user.role_id, 10);

  try {
    const [rows] = await db.query(
      `SELECT module_key, can_view, can_edit
       FROM role_permissions
       WHERE tenant_id = ? AND role_id = ?`,
      [tenantId, roleId],
    );

    res.json({ success: true, role_id: roleId, permissions: rows });
  } catch (err) {
    console.error("[GET /role-permissions/my-permissions]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
