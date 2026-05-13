/**
 * ============================================================
 * user_management_router.js
 * Multi-Tenant HRMS — Employee & Education Management Router
 * ============================================================
 *
 * ADMIN FLOW  : Direct CRUD on master tables (no approval needed)
 * NON-ADMIN   : All writes go to pending tables → Admin approval required
 *
 * ALL queries MUST include tenant_id — enforced at every operation.
 * Roles are validated inside the same tenant only.
 *
 * Tables used:
 *   - employee_master
 *   - education_details
 *   - employee_pending_request
 *   - education_pending_request   (assumed schema shown below)
 *
 * Expected education_pending_request schema:
 *   edu_req_id  INT PK AUTO_INCREMENT
 *   tenant_id   VARCHAR(36)
 *   request_id  INT  (FK → employee_pending_request.request_id, nullable for standalone edu requests)
 *   emp_id      INT  (FK → employee_master.emp_id, nullable for new-employee requests)
 *   education_level  ENUM('10','12','Diploma','UG','PG','PhD')
 *   stream      VARCHAR(100)
 *   score       DECIMAL(5,2)
 *   year_of_passout YEAR
 *   university  VARCHAR(150)
 *   college_name VARCHAR(150)
 *   request_type ENUM('ADD','UPDATE','DELETE')
 *   admin_approve ENUM('PENDING','APPROVED','REJECTED')  DEFAULT 'PENDING'
 *   reject_reason TEXT
 *   created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
 */

"use strict";

const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const multer = require("multer");

// ─── Multer: store photo in memory (saved to DB as BLOB) ─────────────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith("image/")) {
      return cb(new Error("Only image files are allowed"), false);
    }
    cb(null, true);
  },
});

// ─── DB pool injected via app.locals (set in server.js) ──────────────────────
// Usage: req.app.locals.db  →  mysql2/promise pool

// =============================================================================
// HELPER UTILITIES
// =============================================================================

/**
 * Resolve tenant_id and role_id for the logged-in user from the session / JWT.
 * Adjust to match your actual auth middleware (req.user, req.session, etc.).
 */
function getAuthContext(req) {
  // ── Adapt this block to your auth middleware ──────────────────────────────
  // Common patterns:
  //   req.user = { emp_id, tenant_id, role_id }   (JWT decoded)
  //   req.session.user = { ... }
  const user = req.user || req.session?.user;
  if (!user) throw new Error("Unauthorized: no session");
  return {
    empId: user.emp_id || user.empId,
    tenantId: user.tenant_id || user.tenantId,
    roleId: Number(user.role_id || user.roleId),
  };
}

/**
 * Returns true only when the logged-in user is ADMIN (role_id === 2).
 * Role 2 = Admin — align with your roles table.
 */
function isAdmin(roleId) {
  return roleId === 2;
}

/**
 * Validate that a role_id actually belongs to the given tenant.
 * Prevents cross-tenant role injection.
 */
async function validateRoleInTenant(db, roleId, tenantId) {
  const [rows] = await db.query(
    "SELECT role_id FROM roles WHERE role_id = ? AND tenant_id = ? LIMIT 1",
    [roleId, tenantId],
  );
  return rows.length > 0;
}

/**
 * Validate that a department_id belongs to the given tenant.
 */
async function validateDeptInTenant(db, deptId, tenantId) {
  const [rows] = await db.query(
    "SELECT dept_id FROM departments WHERE dept_id = ? AND tenant_id = ? LIMIT 1",
    [deptId, tenantId],
  );
  return rows.length > 0;
}

/**
 * Validate that an emp_id (TL candidate) belongs to the given tenant.
 */
async function validateEmpInTenant(db, empId, tenantId) {
  if (!empId) return true; // tl_id is optional
  const [rows] = await db.query(
    "SELECT emp_id FROM employee_master WHERE emp_id = ? AND tenant_id = ? LIMIT 1",
    [empId, tenantId],
  );
  return rows.length > 0;
}

/**
 * Centralised success response.
 */
function ok(res, data = {}, status = 200) {
  return res.status(status).json({ success: true, ...data });
}

/**
 * Centralised error response.
 */
function fail(res, message, status = 400, extra = {}) {
  return res.status(status).json({ success: false, message, ...extra });
}

// =============================================================================
// ██████████████████████████████████████████████████████████████████
//  EMPLOYEE APIs
// ██████████████████████████████████████████████████████████████████
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// GET /employees  — list all employees for this tenant
// ─────────────────────────────────────────────────────────────────────────────
router.get("/employees", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;

    const [rows] = await db.query(
      `SELECT
         em.emp_id, em.tenant_id,
         em.first_name, em.mid_name, em.last_name,
         em.email_id, em.phone_number,
         em.date_of_birth, em.gender,
         em.department_id, d.name AS department_name,
         em.role_id, r.name AS role_name,
         em.date_of_joining, em.date_of_relieving,
         em.employment_type, em.work_type,
         em.permanent_address, em.communication_address,
         em.father_name, em.emergency_contact_relation, em.emergency_contact,
         em.aadhar_number, em.pan_number, em.passport_number,
         em.pf_number, em.esic_number, em.years_experience,
         em.status, em.tl_id,
         CONCAT(tl.first_name,' ',tl.last_name) AS tl_name,
         em.created_at, em.updated_at
       FROM employee_master em
       LEFT JOIN departments d ON d.dept_id = em.department_id AND d.tenant_id = em.tenant_id
       LEFT JOIN roles       r ON r.role_id  = em.role_id       AND r.tenant_id = em.tenant_id
       LEFT JOIN employee_master tl ON tl.emp_id = em.tl_id    AND tl.tenant_id = em.tenant_id
       WHERE em.tenant_id = ?
       ORDER BY em.created_at DESC`,
      [tenantId],
    );

    return ok(res, { data: rows });
  } catch (err) {
    console.error("[GET /employees]", err);
    return fail(res, err.message || "Failed to fetch employees", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /employees/:id  — single employee detail
// ─────────────────────────────────────────────────────────────────────────────
router.get("/employees/:id", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const empId = Number(req.params.id);

    if (!empId) return fail(res, "Invalid employee ID");

    const [rows] = await db.query(
      `SELECT
         em.emp_id, em.tenant_id,
         em.first_name, em.mid_name, em.last_name,
         em.email_id, em.phone_number,
         em.date_of_birth, em.gender,
         em.department_id, d.name AS department_name,
         em.role_id, r.name AS role_name,
         em.date_of_joining, em.date_of_relieving,
         em.employment_type, em.work_type,
         em.permanent_address, em.communication_address,
         em.father_name, em.emergency_contact_relation, em.emergency_contact,
         em.aadhar_number, em.pan_number, em.passport_number,
         em.pf_number, em.esic_number, em.years_experience,
         em.status, em.tl_id,
         CONCAT(tl.first_name,' ',tl.last_name) AS tl_name,
         em.created_at, em.updated_at
       FROM employee_master em
       LEFT JOIN departments d  ON d.dept_id  = em.department_id AND d.tenant_id = em.tenant_id
       LEFT JOIN roles       r  ON r.role_id   = em.role_id       AND r.tenant_id = em.tenant_id
       LEFT JOIN employee_master tl ON tl.emp_id = em.tl_id       AND tl.tenant_id = em.tenant_id
       WHERE em.emp_id = ? AND em.tenant_id = ?
       LIMIT 1`,
      [empId, tenantId],
    );

    if (!rows.length) return fail(res, "Employee not found", 404);
    return ok(res, { data: rows[0] });
  } catch (err) {
    console.error("[GET /employees/:id]", err);
    return fail(res, err.message || "Failed to fetch employee", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /employees/:id/photo
// ─────────────────────────────────────────────────────────────────────────────
router.get("/employees/:id/photo", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const empId = Number(req.params.id);

    const [rows] = await db.query(
      "SELECT profile_photo, profile_photo_mime FROM employee_master WHERE emp_id = ? AND tenant_id = ?",
      [empId, tenantId],
    );

    if (!rows.length || !rows[0].profile_photo) {
      return res.status(404).json({ success: false, message: "No photo" });
    }

    res.set("Content-Type", rows[0].profile_photo_mime || "image/jpeg");
    return res.send(rows[0].profile_photo);
  } catch (err) {
    console.error("[GET /employees/:id/photo]", err);
    return fail(res, "Failed to fetch photo", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /employees  — ADMIN: add employee directly to master
// ─────────────────────────────────────────────────────────────────────────────
router.post("/employees", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(
        res,
        "Forbidden: Only admins can directly add employees",
        403,
      );
    }

    const db = req.app.locals.db;
    const b = req.body;

    // ── Required field validation ─────────────────────────────────────────
    const required = [
      "first_name",
      "last_name",
      "email_id",
      "phone_number",
      "date_of_birth",
      "gender",
      "department_id",
      "role_id",
      "date_of_joining",
      "employment_type",
      "work_type",
      "permanent_address",
      "aadhar_number",
      "pan_number",
      "username",
      "password",
    ];
    for (const f of required) {
      if (!b[f] && b[f] !== 0) return fail(res, `${f} is required`);
    }

    // ── Tenant-scoped validations ─────────────────────────────────────────
    if (!(await validateRoleInTenant(db, b.role_id, tenantId))) {
      return fail(res, "Invalid role for this tenant", 403);
    }
    if (!(await validateDeptInTenant(db, b.department_id, tenantId))) {
      return fail(res, "Invalid department for this tenant", 403);
    }
    if (b.tl_id && !(await validateEmpInTenant(db, b.tl_id, tenantId))) {
      return fail(res, "Invalid TL for this tenant", 403);
    }

    // ── Uniqueness checks within tenant ──────────────────────────────────
    const [dup] = await db.query(
      `SELECT emp_id FROM employee_master
       WHERE tenant_id = ? AND (email_id = ? OR phone_number = ? OR aadhar_number = ?)
       LIMIT 1`,
      [tenantId, b.email_id, b.phone_number, b.aadhar_number],
    );
    if (dup.length)
      return fail(res, "Email, phone or Aadhar already exists in this tenant");

    const hashedPwd = await bcrypt.hash(String(b.password), 10);
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      const [result] = await conn.query(
        `INSERT INTO employee_master
           (tenant_id, first_name, mid_name, last_name, email_id, phone_number,
            date_of_birth, gender, department_id, role_id, date_of_joining,
            date_of_relieving, employment_type, work_type,
            permanent_address, communication_address,
            father_name, emergency_contact_relation, emergency_contact,
            aadhar_number, pan_number, passport_number,
            pf_number, esic_number, years_experience, tl_id, status)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          b.first_name,
          b.mid_name || null,
          b.last_name,
          b.email_id,
          b.phone_number,
          b.date_of_birth,
          b.gender,
          b.department_id,
          b.role_id,
          b.date_of_joining,
          b.date_of_relieving || null,
          b.employment_type,
          b.work_type,
          b.permanent_address,
          b.communication_address || null,
          b.father_name || null,
          b.emergency_contact_relation || null,
          b.emergency_contact || null,
          b.aadhar_number,
          b.pan_number,
          b.passport_number || null,
          b.pf_number || null,
          b.esic_number || null,
          b.years_experience || null,
          b.tl_id || null,
          b.status || "Active",
        ],
      );

      const empId = result.insertId;

      // ── Insert login credentials ──────────────────────────────────────
      await conn.query(
        `INSERT INTO login_master (tenant_id, emp_id, username, password, role_id)
         VALUES (?,?,?,?,?)`,
        [tenantId, empId, b.username, hashedPwd, b.role_id],
      );

      // ── Insert education records if provided ──────────────────────────
      if (Array.isArray(b.education) && b.education.length > 0) {
        for (const edu of b.education) {
          await conn.query(
            `INSERT INTO education_details
               (tenant_id, emp_id, education_level, stream, score,
                year_of_passout, university, college_name)
             VALUES (?,?,?,?,?,?,?,?)`,
            [
              tenantId,
              empId,
              edu.education_level,
              edu.stream || null,
              edu.score || null,
              edu.year_of_passout || null,
              edu.university || null,
              edu.college_name || null,
            ],
          );
        }
      }

      await conn.commit();
      return ok(
        res,
        { emp_id: empId, message: "Employee added successfully" },
        201,
      );
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[POST /employees]", err);
    if (err.code === "ER_DUP_ENTRY") {
      return fail(
        res,
        "Duplicate entry: email, phone, Aadhar or PAN already exists",
      );
    }
    return fail(res, err.message || "Failed to add employee", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /employees/:id  — ADMIN: update employee directly in master
// ─────────────────────────────────────────────────────────────────────────────
router.put("/employees/:id", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(
        res,
        "Forbidden: Only admins can directly update employees",
        403,
      );
    }

    const db = req.app.locals.db;
    const empId = Number(req.params.id);
    const b = req.body;

    if (!empId) return fail(res, "Invalid employee ID");

    // ── Confirm employee belongs to this tenant ───────────────────────────
    const [existing] = await db.query(
      "SELECT emp_id FROM employee_master WHERE emp_id = ? AND tenant_id = ? LIMIT 1",
      [empId, tenantId],
    );
    if (!existing.length) return fail(res, "Employee not found", 404);

    // ── Tenant-scoped role/dept validations ───────────────────────────────
    if (b.role_id && !(await validateRoleInTenant(db, b.role_id, tenantId))) {
      return fail(res, "Invalid role for this tenant", 403);
    }
    if (
      b.department_id &&
      !(await validateDeptInTenant(db, b.department_id, tenantId))
    ) {
      return fail(res, "Invalid department for this tenant", 403);
    }
    if (b.tl_id && !(await validateEmpInTenant(db, b.tl_id, tenantId))) {
      return fail(res, "Invalid TL for this tenant", 403);
    }

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      await conn.query(
        `UPDATE employee_master SET
           first_name=?, mid_name=?, last_name=?,
           email_id=?, phone_number=?,
           date_of_birth=?, gender=?,
           department_id=?, role_id=?,
           date_of_joining=?, date_of_relieving=?,
           employment_type=?, work_type=?,
           permanent_address=?, communication_address=?,
           father_name=?, emergency_contact_relation=?, emergency_contact=?,
           aadhar_number=?, pan_number=?, passport_number=?,
           pf_number=?, esic_number=?, years_experience=?,
           tl_id=?, status=?
         WHERE emp_id=? AND tenant_id=?`,
        [
          b.first_name,
          b.mid_name || null,
          b.last_name,
          b.email_id,
          b.phone_number,
          b.date_of_birth,
          b.gender,
          b.department_id,
          b.role_id,
          b.date_of_joining,
          b.date_of_relieving || null,
          b.employment_type,
          b.work_type,
          b.permanent_address,
          b.communication_address || null,
          b.father_name || null,
          b.emergency_contact_relation || null,
          b.emergency_contact || null,
          b.aadhar_number,
          b.pan_number,
          b.passport_number || null,
          b.pf_number || null,
          b.esic_number || null,
          b.years_experience || null,
          b.tl_id || null,
          b.status || "Active",
          empId,
          tenantId,
        ],
      );

      // ── Handle education updates if provided ──────────────────────────
      if (Array.isArray(b.education)) {
        // Delete existing education for this employee (admin replaces all)
        await conn.query(
          "DELETE FROM education_details WHERE emp_id = ? AND tenant_id = ?",
          [empId, tenantId],
        );
        for (const edu of b.education) {
          await conn.query(
            `INSERT INTO education_details
               (tenant_id, emp_id, education_level, stream, score,
                year_of_passout, university, college_name)
             VALUES (?,?,?,?,?,?,?,?)`,
            [
              tenantId,
              empId,
              edu.education_level,
              edu.stream || null,
              edu.score || null,
              edu.year_of_passout || null,
              edu.university || null,
              edu.college_name || null,
            ],
          );
        }
      }

      await conn.commit();
      return ok(res, { message: "Employee updated successfully" });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[PUT /employees/:id]", err);
    if (err.code === "ER_DUP_ENTRY") {
      return fail(
        res,
        "Duplicate entry: email, phone, Aadhar or PAN already exists",
      );
    }
    return fail(res, err.message || "Failed to update employee", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /employees/:id  — ADMIN only
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/employees/:id", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(res, "Forbidden: Only admins can delete employees", 403);
    }

    const db = req.app.locals.db;
    const empId = Number(req.params.id);

    if (!empId) return fail(res, "Invalid employee ID");

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // Delete education records first (FK safety)
      await conn.query(
        "DELETE FROM education_details WHERE emp_id = ? AND tenant_id = ?",
        [empId, tenantId],
      );

      const [result] = await conn.query(
        "DELETE FROM employee_master WHERE emp_id = ? AND tenant_id = ?",
        [empId, tenantId],
      );

      if (!result.affectedRows) {
        await conn.rollback();
        return fail(res, "Employee not found", 404);
      }

      await conn.commit();
      return ok(res, { message: "Employee deleted successfully" });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[DELETE /employees/:id]", err);
    return fail(res, err.message || "Failed to delete employee", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /employees/:id/photo  — ADMIN: upload photo to master
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/employees/:id/photo",
  upload.single("photo"),
  async (req, res) => {
    try {
      const { tenantId, roleId } = getAuthContext(req);
      if (!isAdmin(roleId)) return fail(res, "Forbidden", 403);

      const db = req.app.locals.db;
      const empId = Number(req.params.id);

      if (!req.file) return fail(res, "No photo uploaded");

      const [result] = await db.query(
        `UPDATE employee_master
       SET profile_photo = ?, profile_photo_mime = ?
       WHERE emp_id = ? AND tenant_id = ?`,
        [req.file.buffer, req.file.mimetype, empId, tenantId],
      );

      if (!result.affectedRows) return fail(res, "Employee not found", 404);
      return ok(res, { message: "Photo updated" });
    } catch (err) {
      console.error("[POST /employees/:id/photo]", err);
      return fail(res, "Failed to upload photo", 500);
    }
  },
);

// =============================================================================
// ██████████████████████████████████████████████████████████████████
//  EMPLOYEE PENDING REQUEST APIs  (Non-Admin flow)
// ██████████████████████████████████████████████████████████████████
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// POST /employee-pending-request  — Non-Admin: submit NEW employee request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/employee-pending-request", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);

    // Admins should use the direct endpoint; redirect if somehow called here
    if (isAdmin(roleId)) {
      return fail(res, "Admins should use POST /employees directly", 400);
    }

    const db = req.app.locals.db;
    const b = req.body;

    // ── Required field validation ─────────────────────────────────────────
    const required = [
      "first_name",
      "last_name",
      "email_id",
      "phone_number",
      "date_of_birth",
      "gender",
      "department_id",
      "role_id",
      "date_of_joining",
      "employment_type",
      "work_type",
      "permanent_address",
      "aadhar_number",
      "pan_number",
      "username",
      "password",
    ];
    for (const f of required) {
      if (!b[f] && b[f] !== 0) return fail(res, `${f} is required`);
    }

    // ── Tenant-scoped validations ─────────────────────────────────────────
    if (!(await validateRoleInTenant(db, b.role_id, tenantId))) {
      return fail(res, "Invalid role for this tenant", 403);
    }
    if (!(await validateDeptInTenant(db, b.department_id, tenantId))) {
      return fail(res, "Invalid department for this tenant", 403);
    }

    const hashedPwd = await bcrypt.hash(String(b.password), 10);
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // RULE: Always create a NEW row — never update pending rows
      const [result] = await conn.query(
        `INSERT INTO employee_pending_request
           (tenant_id, emp_id,
            first_name, mid_name, last_name, email_id, phone_number,
            date_of_birth, gender, department_id, role_id,
            date_of_joining, employment_type, work_type,
            permanent_address, communication_address,
            father_name, emergency_contact_relation, emergency_contact,
            aadhar_number, pan_number, passport_number,
            pf_number, esic_number, years_experience,
            username, password, request_type, tl_id, status)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          null, // emp_id is null for NEW requests
          b.first_name,
          b.mid_name || null,
          b.last_name,
          b.email_id,
          b.phone_number,
          b.date_of_birth,
          b.gender,
          b.department_id,
          b.role_id,
          b.date_of_joining,
          b.employment_type,
          b.work_type,
          b.permanent_address,
          b.communication_address || null,
          b.father_name || null,
          b.emergency_contact_relation || null,
          b.emergency_contact || null,
          b.aadhar_number,
          b.pan_number,
          b.passport_number || null,
          b.pf_number || null,
          b.esic_number || null,
          b.years_experience || null,
          b.username,
          hashedPwd,
          "NEW",
          b.tl_id || null,
          "Active",
        ],
      );

      const requestId = result.insertId;

      // ── Insert education into pending education table ──────────────────
      if (Array.isArray(b.education) && b.education.length > 0) {
        for (const edu of b.education) {
          await conn.query(
            `INSERT INTO education_pending_request
               (tenant_id, request_id, emp_id,
                education_level, stream, score,
                year_of_passout, university, college_name,
                request_type)
             VALUES (?,?,?,?,?,?,?,?,?,?)`,
            [
              tenantId,
              requestId,
              null,
              edu.education_level,
              edu.stream || null,
              edu.score || null,
              edu.year_of_passout || null,
              edu.university || null,
              edu.college_name || null,
              "ADD",
            ],
          );
        }
      }

      await conn.commit();
      return ok(
        res,
        {
          request_id: requestId,
          message: "Employee request submitted. Awaiting admin approval.",
        },
        201,
      );
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[POST /employee-pending-request]", err);
    return fail(res, err.message || "Failed to submit employee request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /employee-edit-request  — Non-Admin: submit UPDATE employee request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/employee-edit-request", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (isAdmin(roleId)) {
      return fail(res, "Admins should use PUT /employees/:id directly", 400);
    }

    const db = req.app.locals.db;
    const b = req.body;

    if (!b.emp_id) return fail(res, "emp_id is required for edit request");
    if (!b.edit_reason) return fail(res, "edit_reason is required");

    // ── Confirm employee belongs to this tenant ───────────────────────────
    const [empRows] = await db.query(
      "SELECT emp_id, username FROM employee_master WHERE emp_id = ? AND tenant_id = ? LIMIT 1",
      [b.emp_id, tenantId],
    );
    if (!empRows.length) return fail(res, "Employee not found", 404);

    // Tenant-scoped validations
    if (b.role_id && !(await validateRoleInTenant(db, b.role_id, tenantId))) {
      return fail(res, "Invalid role for this tenant", 403);
    }
    if (
      b.department_id &&
      !(await validateDeptInTenant(db, b.department_id, tenantId))
    ) {
      return fail(res, "Invalid department for this tenant", 403);
    }
    if (b.tl_id && !(await validateEmpInTenant(db, b.tl_id, tenantId))) {
      return fail(res, "Invalid TL for this tenant", 403);
    }

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // RULE: Always create a NEW row — never update existing pending rows
      const [result] = await conn.query(
        `INSERT INTO employee_pending_request
           (tenant_id, emp_id,
            first_name, mid_name, last_name, email_id, phone_number,
            date_of_birth, gender, department_id, role_id,
            date_of_joining, date_of_relieving, employment_type, work_type,
            permanent_address, communication_address,
            father_name, emergency_contact_relation, emergency_contact,
            aadhar_number, pan_number, passport_number,
            pf_number, esic_number, years_experience,
            username, password, request_type, edit_reason,
            tl_id, status)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          b.emp_id,
          b.first_name,
          b.mid_name || null,
          b.last_name,
          b.email_id,
          b.phone_number,
          b.date_of_birth,
          b.gender,
          b.department_id,
          b.role_id,
          b.date_of_joining,
          b.date_of_relieving || null,
          b.employment_type,
          b.work_type,
          b.permanent_address,
          b.communication_address || null,
          b.father_name || null,
          b.emergency_contact_relation || null,
          b.emergency_contact || null,
          b.aadhar_number,
          b.pan_number,
          b.passport_number || null,
          b.pf_number || null,
          b.esic_number || null,
          b.years_experience || null,
          // Keep existing username for UPDATE; password unchanged unless provided
          b.username || empRows[0].username,
          b.password
            ? await bcrypt.hash(String(b.password), 10)
            : empRows[0].password,
          "UPDATE",
          b.edit_reason,
          b.tl_id || null,
          b.status || "Active",
        ],
      );

      const requestId = result.insertId;

      // ── Snapshot education into pending table ─────────────────────────
      if (Array.isArray(b.education) && b.education.length > 0) {
        for (const edu of b.education) {
          await conn.query(
            `INSERT INTO education_pending_request
               (tenant_id, request_id, emp_id,
                education_level, stream, score,
                year_of_passout, university, college_name,
                request_type)
             VALUES (?,?,?,?,?,?,?,?,?,?)`,
            [
              tenantId,
              requestId,
              b.emp_id,
              edu.education_level,
              edu.stream || null,
              edu.score || null,
              edu.year_of_passout || null,
              edu.university || null,
              edu.college_name || null,
              "ADD",
            ],
          );
        }
      }

      await conn.commit();
      return ok(
        res,
        {
          request_id: requestId,
          message: "Edit request submitted. Awaiting admin approval.",
        },
        201,
      );
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[POST /employee-edit-request]", err);
    return fail(res, err.message || "Failed to submit edit request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /employee-pending-requests  — Admin: list all pending employee requests
// ─────────────────────────────────────────────────────────────────────────────
router.get("/employee-pending-requests", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(res, "Forbidden: Only admins can view pending requests", 403);
    }

    const db = req.app.locals.db;
    const status = req.query.status || "PENDING"; // PENDING | APPROVED | REJECTED

    const [rows] = await db.query(
      `SELECT
         epr.*,
         d.name AS department_name,
         r.name AS role_name,
         CONCAT(tl.first_name,' ',tl.last_name) AS tl_name
       FROM employee_pending_request epr
       LEFT JOIN departments d  ON d.dept_id  = epr.department_id AND d.tenant_id = epr.tenant_id
       LEFT JOIN roles       r  ON r.role_id   = epr.role_id       AND r.tenant_id = epr.tenant_id
       LEFT JOIN employee_master tl ON tl.emp_id = epr.tl_id       AND tl.tenant_id = epr.tenant_id
       WHERE epr.tenant_id = ? AND epr.admin_approve = ?
       ORDER BY epr.created_at DESC`,
      [tenantId, status.toUpperCase()],
    );

    return ok(res, { data: rows });
  } catch (err) {
    console.error("[GET /employee-pending-requests]", err);
    return fail(res, err.message || "Failed to fetch pending requests", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /admin/request/:requestId  — fetch single pending request detail
// ─────────────────────────────────────────────────────────────────────────────
router.get("/admin/request/:requestId", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const requestId = Number(req.params.requestId);

    if (!requestId) return fail(res, "Invalid request ID");

    const [rows] = await db.query(
      `SELECT
         epr.*,
         d.name AS department_name,
         r.name AS role_name,
         CONCAT(tl.first_name,' ',tl.last_name) AS tl_name
       FROM employee_pending_request epr
       LEFT JOIN departments d  ON d.dept_id  = epr.department_id AND d.tenant_id = epr.tenant_id
       LEFT JOIN roles       r  ON r.role_id   = epr.role_id       AND r.tenant_id = epr.tenant_id
       LEFT JOIN employee_master tl ON tl.emp_id = epr.tl_id       AND tl.tenant_id = epr.tenant_id
       WHERE epr.request_id = ? AND epr.tenant_id = ?
       LIMIT 1`,
      [requestId, tenantId],
    );

    if (!rows.length) return fail(res, "Request not found", 404);
    return ok(res, { data: rows[0] });
  } catch (err) {
    console.error("[GET /admin/request/:requestId]", err);
    return fail(res, "Failed to fetch request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/approve-employee/:requestId  — Admin: approve employee request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/admin/approve-employee/:requestId", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(res, "Forbidden: Only admins can approve requests", 403);
    }

    const db = req.app.locals.db;
    const requestId = Number(req.params.requestId);
    if (!requestId) return fail(res, "Invalid request ID");

    // ── Fetch the pending request (tenant-scoped) ─────────────────────────
    const [pending] = await db.query(
      "SELECT * FROM employee_pending_request WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'PENDING' LIMIT 1",
      [requestId, tenantId],
    );
    if (!pending.length)
      return fail(res, "Pending request not found or already processed", 404);

    const req_data = pending[0];
    const conn = await db.getConnection();

    try {
      await conn.beginTransaction();

      if (req_data.request_type === "NEW") {
        // ── NEW employee: insert into master ──────────────────────────────
        const [insertResult] = await conn.query(
          `INSERT INTO employee_master
             (tenant_id, first_name, mid_name, last_name, email_id, phone_number,
              date_of_birth, gender, department_id, role_id,
              date_of_joining, date_of_relieving, employment_type, work_type,
              permanent_address, communication_address,
              father_name, emergency_contact_relation, emergency_contact,
              aadhar_number, pan_number, passport_number,
              pf_number, esic_number, years_experience,
              tl_id, status,
              profile_photo, profile_photo_mime)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [
            tenantId,
            req_data.first_name,
            req_data.mid_name,
            req_data.last_name,
            req_data.email_id,
            req_data.phone_number,
            req_data.date_of_birth,
            req_data.gender,
            req_data.department_id,
            req_data.role_id,
            req_data.date_of_joining,
            req_data.date_of_relieving,
            req_data.employment_type,
            req_data.work_type,
            req_data.permanent_address,
            req_data.communication_address,
            req_data.father_name,
            req_data.emergency_contact_relation,
            req_data.emergency_contact,
            req_data.aadhar_number,
            req_data.pan_number,
            req_data.passport_number,
            req_data.pf_number,
            req_data.esic_number,
            req_data.years_experience,
            req_data.tl_id,
            req_data.status,
            req_data.profile_photo || null,
            req_data.profile_photo_mime || null,
          ],
        );

        const newEmpId = insertResult.insertId;

        // ── Create login credentials ──────────────────────────────────────
        await conn.query(
          `INSERT INTO login_master (tenant_id, emp_id, username, password, role_id)
           VALUES (?,?,?,?,?)`,
          [
            tenantId,
            newEmpId,
            req_data.username,
            req_data.password,
            req_data.role_id,
          ],
        );

        // ── Copy education records from pending to master ─────────────────
        const [eduRows] = await conn.query(
          "SELECT * FROM education_pending_request WHERE request_id = ? AND tenant_id = ?",
          [requestId, tenantId],
        );
        for (const edu of eduRows) {
          await conn.query(
            `INSERT INTO education_details
               (tenant_id, emp_id, education_level, stream, score,
                year_of_passout, university, college_name)
             VALUES (?,?,?,?,?,?,?,?)`,
            [
              tenantId,
              newEmpId,
              edu.education_level,
              edu.stream,
              edu.score,
              edu.year_of_passout,
              edu.university,
              edu.college_name,
            ],
          );
        }
      } else if (req_data.request_type === "UPDATE") {
        // ── UPDATE existing employee in master ────────────────────────────
        if (!req_data.emp_id)
          throw new Error("emp_id missing in update request");

        await conn.query(
          `UPDATE employee_master SET
             first_name=?, mid_name=?, last_name=?,
             email_id=?, phone_number=?,
             date_of_birth=?, gender=?,
             department_id=?, role_id=?,
             date_of_joining=?, date_of_relieving=?,
             employment_type=?, work_type=?,
             permanent_address=?, communication_address=?,
             father_name=?, emergency_contact_relation=?, emergency_contact=?,
             aadhar_number=?, pan_number=?, passport_number=?,
             pf_number=?, esic_number=?, years_experience=?,
             tl_id=?, status=?
           WHERE emp_id=? AND tenant_id=?`,
          [
            req_data.first_name,
            req_data.mid_name,
            req_data.last_name,
            req_data.email_id,
            req_data.phone_number,
            req_data.date_of_birth,
            req_data.gender,
            req_data.department_id,
            req_data.role_id,
            req_data.date_of_joining,
            req_data.date_of_relieving,
            req_data.employment_type,
            req_data.work_type,
            req_data.permanent_address,
            req_data.communication_address,
            req_data.father_name,
            req_data.emergency_contact_relation,
            req_data.emergency_contact,
            req_data.aadhar_number,
            req_data.pan_number,
            req_data.passport_number,
            req_data.pf_number,
            req_data.esic_number,
            req_data.years_experience,
            req_data.tl_id,
            req_data.status,
            req_data.emp_id,
            tenantId,
          ],
        );

        // ── Replace education in master ───────────────────────────────────
        await conn.query(
          "DELETE FROM education_details WHERE emp_id = ? AND tenant_id = ?",
          [req_data.emp_id, tenantId],
        );
        const [eduRows] = await conn.query(
          "SELECT * FROM education_pending_request WHERE request_id = ? AND tenant_id = ?",
          [requestId, tenantId],
        );
        for (const edu of eduRows) {
          await conn.query(
            `INSERT INTO education_details
               (tenant_id, emp_id, education_level, stream, score,
                year_of_passout, university, college_name)
             VALUES (?,?,?,?,?,?,?,?)`,
            [
              tenantId,
              req_data.emp_id,
              edu.education_level,
              edu.stream,
              edu.score,
              edu.year_of_passout,
              edu.university,
              edu.college_name,
            ],
          );
        }

        // ── Apply photo if a new one was submitted ────────────────────────
        if (req_data.profile_photo) {
          await conn.query(
            `UPDATE employee_master
             SET profile_photo=?, profile_photo_mime=?
             WHERE emp_id=? AND tenant_id=?`,
            [
              req_data.profile_photo,
              req_data.profile_photo_mime,
              req_data.emp_id,
              tenantId,
            ],
          );
        }
      }

      // ── Mark request as APPROVED ──────────────────────────────────────
      await conn.query(
        "UPDATE employee_pending_request SET admin_approve='APPROVED' WHERE request_id=? AND tenant_id=?",
        [requestId, tenantId],
      );

      await conn.commit();
      return ok(res, { message: "Employee request approved successfully" });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[POST /admin/approve-employee/:requestId]", err);
    if (err.code === "ER_DUP_ENTRY") {
      return fail(
        res,
        "Duplicate entry: employee with this email/phone/Aadhar already exists",
      );
    }
    return fail(res, err.message || "Failed to approve employee request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/reject-employee/:requestId  — Admin: reject employee request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/admin/reject-employee/:requestId", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(res, "Forbidden: Only admins can reject requests", 403);
    }

    const db = req.app.locals.db;
    const requestId = Number(req.params.requestId);
    const rejectReason = req.body.reject_reason || "Rejected by admin";

    if (!requestId) return fail(res, "Invalid request ID");
    if (!rejectReason.trim()) return fail(res, "reject_reason is required");

    const [result] = await db.query(
      `UPDATE employee_pending_request
       SET admin_approve='REJECTED', reject_reason=?
       WHERE request_id=? AND tenant_id=? AND admin_approve='PENDING'`,
      [rejectReason, requestId, tenantId],
    );

    if (!result.affectedRows) {
      return fail(res, "Pending request not found or already processed", 404);
    }

    return ok(res, { message: "Employee request rejected" });
  } catch (err) {
    console.error("[POST /admin/reject-employee/:requestId]", err);
    return fail(res, err.message || "Failed to reject request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /admin/resubmit-request/:requestId  — Non-Admin: resubmit a REJECTED request
// RULE: Create a NEW row — never update the old rejected row
// ─────────────────────────────────────────────────────────────────────────────
router.put("/admin/resubmit-request/:requestId", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (isAdmin(roleId)) {
      return fail(res, "Admins do not need to resubmit requests", 400);
    }

    const db = req.app.locals.db;
    const requestId = Number(req.params.requestId);
    const b = req.body;

    if (!requestId) return fail(res, "Invalid request ID");

    // ── Confirm the original request belongs to this tenant ───────────────
    const [original] = await db.query(
      "SELECT * FROM employee_pending_request WHERE request_id=? AND tenant_id=? AND admin_approve='REJECTED' LIMIT 1",
      [requestId, tenantId],
    );
    if (!original.length) return fail(res, "Rejected request not found", 404);

    const orig = original[0];
    const hashedPwd = b.password
      ? await bcrypt.hash(String(b.password), 10)
      : orig.password;

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // RULE: Insert NEW row for the resubmission
      const [result] = await conn.query(
        `INSERT INTO employee_pending_request
           (tenant_id, emp_id,
            first_name, mid_name, last_name, email_id, phone_number,
            date_of_birth, gender, department_id, role_id,
            date_of_joining, date_of_relieving, employment_type, work_type,
            permanent_address, communication_address,
            father_name, emergency_contact_relation, emergency_contact,
            aadhar_number, pan_number, passport_number,
            pf_number, esic_number, years_experience,
            username, password, request_type, edit_reason,
            tl_id, status)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          orig.emp_id, // carry over emp_id from original
          b.first_name || orig.first_name,
          b.mid_name || orig.mid_name,
          b.last_name || orig.last_name,
          b.email_id || orig.email_id,
          b.phone_number || orig.phone_number,
          b.date_of_birth || orig.date_of_birth,
          b.gender || orig.gender,
          b.department_id || orig.department_id,
          b.role_id || orig.role_id,
          b.date_of_joining || orig.date_of_joining,
          b.date_of_relieving || orig.date_of_relieving || null,
          b.employment_type || orig.employment_type,
          b.work_type || orig.work_type,
          b.permanent_address || orig.permanent_address,
          b.communication_address || orig.communication_address || null,
          b.father_name || orig.father_name || null,
          b.emergency_contact_relation ||
            orig.emergency_contact_relation ||
            null,
          b.emergency_contact || orig.emergency_contact || null,
          b.aadhar_number || orig.aadhar_number,
          b.pan_number || orig.pan_number,
          b.passport_number || orig.passport_number || null,
          b.pf_number || orig.pf_number || null,
          b.esic_number || orig.esic_number || null,
          b.years_experience || orig.years_experience || null,
          b.username || orig.username,
          hashedPwd,
          orig.request_type,
          b.edit_reason || orig.edit_reason || null,
          b.tl_id || orig.tl_id || null,
          b.status || orig.status || "Active",
        ],
      );

      const newRequestId = result.insertId;

      // ── Insert updated education into pending table ────────────────────
      if (Array.isArray(b.education) && b.education.length > 0) {
        for (const edu of b.education) {
          await conn.query(
            `INSERT INTO education_pending_request
               (tenant_id, request_id, emp_id,
                education_level, stream, score,
                year_of_passout, university, college_name,
                request_type)
             VALUES (?,?,?,?,?,?,?,?,?,?)`,
            [
              tenantId,
              newRequestId,
              orig.emp_id || null,
              edu.education_level,
              edu.stream || null,
              edu.score || null,
              edu.year_of_passout || null,
              edu.university || null,
              edu.college_name || null,
              "ADD",
            ],
          );
        }
      }

      await conn.commit();
      return ok(res, {
        request_id: newRequestId,
        message: "Request resubmitted successfully. Awaiting admin approval.",
      });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[PUT /admin/resubmit-request/:requestId]", err);
    return fail(res, err.message || "Failed to resubmit request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /pending-request/:requestId/photo  — upload photo for a pending request
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/pending-request/:requestId/photo",
  upload.single("photo"),
  async (req, res) => {
    try {
      const { tenantId } = getAuthContext(req);
      const db = req.app.locals.db;
      const requestId = Number(req.params.requestId);

      if (!req.file) return fail(res, "No photo uploaded");
      if (!requestId) return fail(res, "Invalid request ID");

      const [result] = await db.query(
        `UPDATE employee_pending_request
       SET profile_photo=?, profile_photo_mime=?
       WHERE request_id=? AND tenant_id=?`,
        [req.file.buffer, req.file.mimetype, requestId, tenantId],
      );

      if (!result.affectedRows)
        return fail(res, "Pending request not found", 404);
      return ok(res, { message: "Photo saved to pending request" });
    } catch (err) {
      console.error("[POST /pending-request/:requestId/photo]", err);
      return fail(res, "Failed to upload photo", 500);
    }
  },
);

// =============================================================================
// ██████████████████████████████████████████████████████████████████
//  EDUCATION APIs  (Master Table Operations)
// ██████████████████████████████████████████████████████████████████
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// GET /employees/:empId/education
// ─────────────────────────────────────────────────────────────────────────────
router.get("/employees/:empId/education", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const empId = Number(req.params.empId);

    if (!empId) return fail(res, "Invalid employee ID");

    // Security: confirm employee belongs to tenant before returning education
    const [emp] = await db.query(
      "SELECT emp_id FROM employee_master WHERE emp_id=? AND tenant_id=? LIMIT 1",
      [empId, tenantId],
    );
    if (!emp.length) return fail(res, "Employee not found", 404);

    const [rows] = await db.query(
      `SELECT * FROM education_details
       WHERE emp_id=? AND tenant_id=?
       ORDER BY
         FIELD(education_level,'10','12','Diploma','UG','PG','PhD')`,
      [empId, tenantId],
    );

    return ok(res, { data: rows });
  } catch (err) {
    console.error("[GET /employees/:empId/education]", err);
    return fail(res, err.message || "Failed to fetch education", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /employees/:empId/education
// Admin  → insert directly into education_details
// Non-admin → insert into education_pending_request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/employees/:empId/education", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    const db = req.app.locals.db;
    const empId = Number(req.params.empId);
    const b = req.body;

    if (!empId) return fail(res, "Invalid employee ID");
    if (!b.education_level) return fail(res, "education_level is required");

    // Confirm employee belongs to tenant
    const [emp] = await db.query(
      "SELECT emp_id FROM employee_master WHERE emp_id=? AND tenant_id=? LIMIT 1",
      [empId, tenantId],
    );
    if (!emp.length) return fail(res, "Employee not found", 404);

    if (isAdmin(roleId)) {
      // ── ADMIN: direct insert ────────────────────────────────────────────
      const [result] = await db.query(
        `INSERT INTO education_details
           (tenant_id, emp_id, education_level, stream, score,
            year_of_passout, university, college_name)
         VALUES (?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          empId,
          b.education_level,
          b.stream || null,
          b.score || null,
          b.year_of_passout || null,
          b.university || null,
          b.college_name || null,
        ],
      );
      return ok(
        res,
        { edu_id: result.insertId, message: "Education record added" },
        201,
      );
    } else {
      // ── NON-ADMIN: check for existing pending request for this employee ──
      const [pendingEmp] = await db.query(
        "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND tenant_id=? AND admin_approve='PENDING' ORDER BY created_at DESC LIMIT 1",
        [empId, tenantId],
      );
      const requestId = pendingEmp.length ? pendingEmp[0].request_id : null;

      const [result] = await db.query(
        `INSERT INTO education_pending_request
           (tenant_id, request_id, emp_id,
            education_level, stream, score,
            year_of_passout, university, college_name, request_type)
         VALUES (?,?,?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          requestId,
          empId,
          b.education_level,
          b.stream || null,
          b.score || null,
          b.year_of_passout || null,
          b.university || null,
          b.college_name || null,
          "ADD",
        ],
      );
      return ok(
        res,
        {
          edu_req_id: result.insertId,
          pending: true,
          request_id: requestId,
          message: "Education add request submitted for approval",
        },
        201,
      );
    }
  } catch (err) {
    console.error("[POST /employees/:empId/education]", err);
    return fail(res, err.message || "Failed to add education", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /education/:eduId
// Admin → update directly
// Non-admin → create UPDATE pending request
// ─────────────────────────────────────────────────────────────────────────────
router.put("/education/:eduId", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    const db = req.app.locals.db;
    const eduId = Number(req.params.eduId);
    const b = req.body;

    if (!eduId) return fail(res, "Invalid education ID");

    // ── Confirm record belongs to tenant ──────────────────────────────────
    const [eduRows] = await db.query(
      "SELECT * FROM education_details WHERE edu_id=? AND tenant_id=? LIMIT 1",
      [eduId, tenantId],
    );
    if (!eduRows.length) return fail(res, "Education record not found", 404);

    const edu = eduRows[0];

    if (isAdmin(roleId)) {
      await db.query(
        `UPDATE education_details SET
           education_level=?, stream=?, score=?,
           year_of_passout=?, university=?, college_name=?
         WHERE edu_id=? AND tenant_id=?`,
        [
          b.education_level || edu.education_level,
          b.stream || null,
          b.score || null,
          b.year_of_passout || null,
          b.university || null,
          b.college_name || null,
          eduId,
          tenantId,
        ],
      );
      return ok(res, { message: "Education record updated" });
    } else {
      // ── NON-ADMIN: find associated employee pending request ───────────
      const [pendingEmp] = await db.query(
        "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND tenant_id=? AND admin_approve='PENDING' ORDER BY created_at DESC LIMIT 1",
        [edu.emp_id, tenantId],
      );
      const requestId = pendingEmp.length ? pendingEmp[0].request_id : null;

      // Always create a NEW row — never update existing pending rows
      const [result] = await db.query(
        `INSERT INTO education_pending_request
           (tenant_id, request_id, emp_id,
            education_level, stream, score,
            year_of_passout, university, college_name, request_type)
         VALUES (?,?,?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          requestId,
          edu.emp_id,
          b.education_level || edu.education_level,
          b.stream || null,
          b.score || null,
          b.year_of_passout || null,
          b.university || null,
          b.college_name || null,
          "UPDATE",
        ],
      );
      return ok(res, {
        edu_req_id: result.insertId,
        pending: true,
        request_id: requestId,
        message: "Education update request submitted for approval",
      });
    }
  } catch (err) {
    console.error("[PUT /education/:eduId]", err);
    return fail(res, err.message || "Failed to update education", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /education/:eduId
// Admin → delete directly
// Non-admin → create DELETE pending request
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/education/:eduId", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    const db = req.app.locals.db;
    const eduId = Number(req.params.eduId);

    if (!eduId) return fail(res, "Invalid education ID");

    const [eduRows] = await db.query(
      "SELECT * FROM education_details WHERE edu_id=? AND tenant_id=? LIMIT 1",
      [eduId, tenantId],
    );
    if (!eduRows.length) return fail(res, "Education record not found", 404);

    const edu = eduRows[0];

    if (isAdmin(roleId)) {
      await db.query(
        "DELETE FROM education_details WHERE edu_id=? AND tenant_id=?",
        [eduId, tenantId],
      );
      return ok(res, { message: "Education record deleted" });
    } else {
      // NON-ADMIN: submit DELETE request for approval
      const [pendingEmp] = await db.query(
        "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND tenant_id=? AND admin_approve='PENDING' ORDER BY created_at DESC LIMIT 1",
        [edu.emp_id, tenantId],
      );
      const requestId = pendingEmp.length ? pendingEmp[0].request_id : null;

      const [result] = await db.query(
        `INSERT INTO education_pending_request
           (tenant_id, request_id, emp_id,
            education_level, stream, score,
            year_of_passout, university, college_name, request_type)
         VALUES (?,?,?,?,?,?,?,?,?,?)`,
        [
          tenantId,
          requestId,
          edu.emp_id,
          edu.education_level,
          edu.stream,
          edu.score,
          edu.year_of_passout,
          edu.university,
          edu.college_name,
          "DELETE",
        ],
      );
      return ok(res, {
        edu_req_id: result.insertId,
        pending: true,
        request_id: requestId,
        message: "Education delete request submitted for approval",
      });
    }
  } catch (err) {
    console.error("[DELETE /education/:eduId]", err);
    return fail(res, err.message || "Failed to delete education", 500);
  }
});

// =============================================================================
// ██████████████████████████████████████████████████████████████████
//  EDUCATION PENDING REQUEST APIs
// ██████████████████████████████████████████████████████████████████
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// GET /requests/:requestId/education  — fetch education for a pending request
// ─────────────────────────────────────────────────────────────────────────────
router.get("/requests/:requestId/education", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const requestId = Number(req.params.requestId);

    if (!requestId) return fail(res, "Invalid request ID");

    // Confirm the parent pending request belongs to this tenant
    const [parent] = await db.query(
      "SELECT request_id FROM employee_pending_request WHERE request_id=? AND tenant_id=? LIMIT 1",
      [requestId, tenantId],
    );
    if (!parent.length) return fail(res, "Request not found", 404);

    const [rows] = await db.query(
      "SELECT * FROM education_pending_request WHERE request_id=? AND tenant_id=? ORDER BY edu_req_id",
      [requestId, tenantId],
    );

    return ok(res, { data: rows });
  } catch (err) {
    console.error("[GET /requests/:requestId/education]", err);
    return fail(res, err.message || "Failed to fetch education", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /education-pending-requests  — Admin: list all education pending requests
// ─────────────────────────────────────────────────────────────────────────────
router.get("/education-pending-requests", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(
        res,
        "Forbidden: Only admins can view pending education requests",
        403,
      );
    }

    const db = req.app.locals.db;
    const status = req.query.status || "PENDING";

    const [rows] = await db.query(
      `SELECT
         epr.*,
         CONCAT(em.first_name,' ',em.last_name) AS employee_name,
         em.emp_id
       FROM education_pending_request epr
       LEFT JOIN employee_master em ON em.emp_id=epr.emp_id AND em.tenant_id=epr.tenant_id
       WHERE epr.tenant_id=? AND epr.admin_approve=?
       ORDER BY epr.created_at DESC`,
      [tenantId, status.toUpperCase()],
    );

    return ok(res, { data: rows });
  } catch (err) {
    console.error("[GET /education-pending-requests]", err);
    return fail(
      res,
      err.message || "Failed to fetch education pending requests",
      500,
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/approve-education/:eduReqId  — Admin: approve an education request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/admin/approve-education/:eduReqId", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(
        res,
        "Forbidden: Only admins can approve education requests",
        403,
      );
    }

    const db = req.app.locals.db;
    const eduReqId = Number(req.params.eduReqId);

    if (!eduReqId) return fail(res, "Invalid education request ID");

    const [pending] = await db.query(
      "SELECT * FROM education_pending_request WHERE edu_req_id=? AND tenant_id=? AND admin_approve='PENDING' LIMIT 1",
      [eduReqId, tenantId],
    );
    if (!pending.length)
      return fail(res, "Pending education request not found", 404);

    const eduReq = pending[0];
    const conn = await db.getConnection();

    try {
      await conn.beginTransaction();

      if (eduReq.request_type === "ADD") {
        await conn.query(
          `INSERT INTO education_details
             (tenant_id, emp_id, education_level, stream, score,
              year_of_passout, university, college_name)
           VALUES (?,?,?,?,?,?,?,?)`,
          [
            tenantId,
            eduReq.emp_id,
            eduReq.education_level,
            eduReq.stream,
            eduReq.score,
            eduReq.year_of_passout,
            eduReq.university,
            eduReq.college_name,
          ],
        );
      } else if (eduReq.request_type === "UPDATE") {
        // Find the existing record by emp_id + level (best match)
        await conn.query(
          `UPDATE education_details SET
             education_level=?, stream=?, score=?,
             year_of_passout=?, university=?, college_name=?
           WHERE emp_id=? AND education_level=? AND tenant_id=?`,
          [
            eduReq.education_level,
            eduReq.stream,
            eduReq.score,
            eduReq.year_of_passout,
            eduReq.university,
            eduReq.college_name,
            eduReq.emp_id,
            eduReq.education_level,
            tenantId,
          ],
        );
      } else if (eduReq.request_type === "DELETE") {
        await conn.query(
          `DELETE FROM education_details
           WHERE emp_id=? AND education_level=? AND tenant_id=?`,
          [eduReq.emp_id, eduReq.education_level, tenantId],
        );
      }

      // Mark request approved
      await conn.query(
        "UPDATE education_pending_request SET admin_approve='APPROVED' WHERE edu_req_id=? AND tenant_id=?",
        [eduReqId, tenantId],
      );

      await conn.commit();
      return ok(res, { message: "Education request approved" });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("[POST /admin/approve-education/:eduReqId]", err);
    return fail(res, err.message || "Failed to approve education request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/reject-education/:eduReqId  — Admin: reject an education request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/admin/reject-education/:eduReqId", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(
        res,
        "Forbidden: Only admins can reject education requests",
        403,
      );
    }

    const db = req.app.locals.db;
    const eduReqId = Number(req.params.eduReqId);
    const rejectReason = req.body.reject_reason || "Rejected by admin";

    if (!eduReqId) return fail(res, "Invalid education request ID");

    const [result] = await db.query(
      `UPDATE education_pending_request
       SET admin_approve='REJECTED', reject_reason=?
       WHERE edu_req_id=? AND tenant_id=? AND admin_approve='PENDING'`,
      [rejectReason, eduReqId, tenantId],
    );

    if (!result.affectedRows) {
      return fail(
        res,
        "Pending education request not found or already processed",
        404,
      );
    }

    return ok(res, { message: "Education request rejected" });
  } catch (err) {
    console.error("[POST /admin/reject-education/:eduReqId]", err);
    return fail(res, err.message || "Failed to reject education request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /requests/:requestId/education  — Non-Admin: add edu to existing request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/requests/:requestId/education", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const requestId = Number(req.params.requestId);
    const b = req.body;

    if (!requestId) return fail(res, "Invalid request ID");
    if (!b.education_level) return fail(res, "education_level is required");

    // Confirm parent request belongs to tenant
    const [parent] = await db.query(
      "SELECT * FROM employee_pending_request WHERE request_id=? AND tenant_id=? LIMIT 1",
      [requestId, tenantId],
    );
    if (!parent.length) return fail(res, "Parent request not found", 404);

    const [result] = await db.query(
      `INSERT INTO education_pending_request
         (tenant_id, request_id, emp_id,
          education_level, stream, score,
          year_of_passout, university, college_name, request_type)
       VALUES (?,?,?,?,?,?,?,?,?,?)`,
      [
        tenantId,
        requestId,
        parent[0].emp_id || null,
        b.education_level,
        b.stream || null,
        b.score || null,
        b.year_of_passout || null,
        b.university || null,
        b.college_name || null,
        "ADD",
      ],
    );

    return ok(
      res,
      { edu_req_id: result.insertId, message: "Education added to request" },
      201,
    );
  } catch (err) {
    console.error("[POST /requests/:requestId/education]", err);
    return fail(res, err.message || "Failed to add education to request", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /requests/education/:eduReqId  — Non-Admin: update a pending education row
// ─────────────────────────────────────────────────────────────────────────────
router.put("/requests/education/:eduReqId", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const eduReqId = Number(req.params.eduReqId);
    const b = req.body;

    if (!eduReqId) return fail(res, "Invalid education request ID");

    // Confirm record belongs to tenant and is still PENDING
    const [rows] = await db.query(
      "SELECT * FROM education_pending_request WHERE edu_req_id=? AND tenant_id=? AND admin_approve='PENDING' LIMIT 1",
      [eduReqId, tenantId],
    );
    if (!rows.length)
      return fail(res, "Pending education record not found", 404);

    await db.query(
      `UPDATE education_pending_request SET
         education_level=?, stream=?, score=?,
         year_of_passout=?, university=?, college_name=?
       WHERE edu_req_id=? AND tenant_id=?`,
      [
        b.education_level || rows[0].education_level,
        b.stream || null,
        b.score || null,
        b.year_of_passout || null,
        b.university || null,
        b.college_name || null,
        eduReqId,
        tenantId,
      ],
    );

    return ok(res, { message: "Pending education record updated" });
  } catch (err) {
    console.error("[PUT /requests/education/:eduReqId]", err);
    return fail(res, err.message || "Failed to update pending education", 500);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /requests/education/:eduReqId  — Non-Admin: remove a pending education row
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/requests/education/:eduReqId", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const eduReqId = Number(req.params.eduReqId);

    if (!eduReqId) return fail(res, "Invalid education request ID");

    const [result] = await db.query(
      "DELETE FROM education_pending_request WHERE edu_req_id=? AND tenant_id=? AND admin_approve='PENDING'",
      [eduReqId, tenantId],
    );

    if (!result.affectedRows) {
      return fail(
        res,
        "Pending education record not found or already approved",
        404,
      );
    }

    return ok(res, { message: "Pending education record deleted" });
  } catch (err) {
    console.error("[DELETE /requests/education/:eduReqId]", err);
    return fail(res, err.message || "Failed to delete pending education", 500);
  }
});

// =============================================================================
// ██████████████████████████████████████████████████████████████████
//  HELPER / LOOKUP APIs
// ██████████████████████████████████████████████████████████████████
// =============================================================================

// ─── GET /employees/:empId/pending-request ──────────────────────────────────
router.get("/employees/:empId/pending-request", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;
    const empId = Number(req.params.empId);

    const [rows] = await db.query(
      `SELECT request_id FROM employee_pending_request
       WHERE emp_id=? AND tenant_id=? AND admin_approve='PENDING'
       ORDER BY created_at DESC LIMIT 1`,
      [empId, tenantId],
    );

    if (rows.length) {
      return ok(res, { pending: true, request_id: rows[0].request_id });
    }
    return ok(res, { pending: false });
  } catch (err) {
    console.error("[GET /employees/:empId/pending-request]", err);
    return fail(res, err.message || "Failed to check pending request", 500);
  }
});

// ─── GET /all-employees  (alias used by Flutter EmployeeService) ─────────────
router.get("/all-employees", async (req, res) => {
  try {
    const { tenantId } = getAuthContext(req);
    const db = req.app.locals.db;

    const [rows] = await db.query(
      `SELECT
         em.emp_id, em.tenant_id,
         em.first_name, em.mid_name, em.last_name,
         em.email_id, em.phone_number,
         em.department_id, d.name AS department_name,
         em.role_id, r.name AS role_name,
         em.status, em.tl_id,
         CONCAT(tl.first_name,' ',tl.last_name) AS tl_name,
         NULL AS admin_approve, NULL AS request_id
       FROM employee_master em
       LEFT JOIN departments d  ON d.dept_id  = em.department_id AND d.tenant_id = em.tenant_id
       LEFT JOIN roles       r  ON r.role_id   = em.role_id       AND r.tenant_id = em.tenant_id
       LEFT JOIN employee_master tl ON tl.emp_id = em.tl_id       AND tl.tenant_id = em.tenant_id
       WHERE em.tenant_id = ?

       UNION ALL

       SELECT
         0 AS emp_id, epr.tenant_id,
         epr.first_name, epr.mid_name, epr.last_name,
         epr.email_id, epr.phone_number,
         epr.department_id, d.name AS department_name,
         epr.role_id, r.name AS role_name,
         epr.status, epr.tl_id,
         CONCAT(tl.first_name,' ',tl.last_name) AS tl_name,
         epr.admin_approve, epr.request_id
       FROM employee_pending_request epr
       LEFT JOIN departments d  ON d.dept_id  = epr.department_id AND d.tenant_id = epr.tenant_id
       LEFT JOIN roles       r  ON r.role_id   = epr.role_id       AND r.tenant_id = epr.tenant_id
       LEFT JOIN employee_master tl ON tl.emp_id = epr.tl_id       AND tl.tenant_id = epr.tenant_id
       WHERE epr.tenant_id = ? AND epr.admin_approve IN ('PENDING','REJECTED')
         AND epr.request_type = 'NEW'

       ORDER BY first_name`,
      [tenantId, tenantId],
    );

    return ok(res, { data: rows });
  } catch (err) {
    console.error("[GET /all-employees]", err);
    return fail(res, err.message || "Failed to fetch employees", 500);
  }
});

// ─── GET /admin/requests  (existing endpoint alias) ──────────────────────────
router.get("/admin/requests", async (req, res) => {
  try {
    const { tenantId, roleId } = getAuthContext(req);
    if (!isAdmin(roleId)) {
      return fail(res, "Forbidden", 403);
    }
    const db = req.app.locals.db;

    const [rows] = await db.query(
      `SELECT
         epr.*,
         d.name AS department_name,
         r.name AS role_name
       FROM employee_pending_request epr
       LEFT JOIN departments d ON d.dept_id = epr.department_id AND d.tenant_id = epr.tenant_id
       LEFT JOIN roles       r ON r.role_id  = epr.role_id       AND r.tenant_id = epr.tenant_id
       WHERE epr.tenant_id=? AND epr.admin_approve='PENDING'
       ORDER BY epr.created_at DESC`,
      [tenantId],
    );

    return ok(res, { data: rows });
  } catch (err) {
    console.error("[GET /admin/requests]", err);
    return fail(res, err.message || "Failed to fetch requests", 500);
  }
});

module.exports = router;
