require("dotenv").config();

const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const multer = require("multer");
const db = require("./config/db");

// ── Multer (profile photo — memory storage, 2 MB cap) ────────────────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (_, file, cb) => {
    if (file.mimetype.startsWith("image/")) cb(null, true);
    else cb(new Error("Only image files are allowed."));
  },
});

// ── Auth middleware ───────────────────────────────────────────────────────────
// Expects header:  Authorization: Bearer <session_token>
//                  X-Login-Id: <login_id>
// Attaches req.user = { loginId, tenantId, companyId, roleId }
async function requireAuth(req, res, next) {
  const token = (req.headers["authorization"] || "")
    .replace("Bearer ", "")
    .trim();
  const loginId = req.headers["x-login-id"];

  if (!token || !loginId) {
    return res.status(401).json({ success: false, message: "Unauthorised." });
  }

  try {
    const [rows] = await db.query(
      `SELECT login_id, tenant_id, company_id, role_id, status, session_token
         FROM login_master
        WHERE login_id = ? AND status = 'Active'
        LIMIT 1`,
      [loginId],
    );

    if (!rows.length || rows[0].session_token !== token) {
      return res
        .status(401)
        .json({ success: false, message: "Session invalid or expired." });
    }

    req.user = {
      loginId: rows[0].login_id,
      tenantId: rows[0].tenant_id,
      companyId: rows[0].company_id,
      roleId: rows[0].role_id,
    };
    next();
  } catch (err) {
    console.error("[requireAuth]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
}

// ── Role guard factory ────────────────────────────────────────────────────────
// Roles: Admin=1, HR=2, TL=3, Employee=5, AppAdmin=6, Manager=8
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!allowedRoles.includes(req.user.roleId)) {
      return res.status(403).json({ success: false, message: "Forbidden." });
    }
    next();
  };
}

// ── Sanitise helper ───────────────────────────────────────────────────────────
function nullIfEmpty(v) {
  return v === undefined || v === null || v === "" ? null : v;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees
// Lists all employees for the caller's tenant (across all statuses by default).
// Query params:
//   status   — Active | Inactive | Relieved  (optional, no default = all)
//   dept_id  — filter by department
//   role_id  — filter by role
//   tl_id    — filter by TL
//   search   — partial match on name / email / phone
//   page     — 1-based (default 1)
//   limit    — rows per page (default 50, max 200)
// ─────────────────────────────────────────────────────────────────────────────
router.get("/", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const {
    status,
    dept_id,
    role_id,
    tl_id,
    search,
    page = 1,
    limit = 50,
  } = req.query;

  const safePage = Math.max(1, parseInt(page, 10) || 1);
  const safeLimit = Math.min(200, Math.max(1, parseInt(limit, 10) || 50));
  const offset = (safePage - 1) * safeLimit;

  const conditions = ["e.tenant_id = ?"];
  const params = [tenantId];

  if (status) {
    conditions.push("e.status = ?");
    params.push(status);
  }
  if (dept_id) {
    conditions.push("e.department_id = ?");
    params.push(dept_id);
  }
  if (role_id) {
    conditions.push("e.role_id = ?");
    params.push(role_id);
  }
  if (tl_id) {
    conditions.push("e.tl_id = ?");
    params.push(tl_id);
  }
  if (search) {
    conditions.push(
      `(e.first_name LIKE ? OR e.last_name LIKE ? OR e.email_id LIKE ? OR e.phone_number LIKE ?)`,
    );
    const like = `%${search}%`;
    params.push(like, like, like, like);
  }

  const where = conditions.join(" AND ");

  try {
    const [[{ total }]] = await db.query(
      `SELECT COUNT(*) AS total FROM employee_master e WHERE ${where}`,
      params,
    );

    const [rows] = await db.query(
      `SELECT
          e.emp_id, e.first_name, e.mid_name, e.last_name,
          e.email_id, e.phone_number, e.date_of_birth, e.gender,
          e.department_id, d.department_name,
          e.role_id, r.role_name,
          e.date_of_joining, e.date_of_relieving,
          e.employment_type, e.work_type,
          e.permanent_address, e.communication_address,
          e.aadhar_number, e.pan_number, e.passport_number,
          e.father_name, e.emergency_contact_relation, e.emergency_contact,
          e.pf_number, e.esic_number, e.years_experience,
          e.status, e.tl_id, e.has_face_embedding,
          e.created_at, e.updated_at,
          CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS tl_name
       FROM employee_master e
       LEFT JOIN department_master d ON d.department_id = e.department_id
       LEFT JOIN role_master        r ON r.role_id        = e.role_id
       LEFT JOIN employee_master    t ON t.emp_id          = e.tl_id
       WHERE ${where}
       ORDER BY e.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, safeLimit, offset],
    );

    res.json({
      success: true,
      total,
      page: safePage,
      limit: safeLimit,
      pages: Math.ceil(total / safeLimit),
      data: rows,
    });
  } catch (err) {
    console.error("[GET /employees]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/me
// Returns the profile of the currently logged-in employee.
// NOTE: Must be defined BEFORE /:emp_id to avoid route collision.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/me", requireAuth, async (req, res) => {
  const { loginId, tenantId } = req.user;

  try {
    const [[lm]] = await db.query(
      "SELECT emp_id FROM login_master WHERE login_id = ? LIMIT 1",
      [loginId],
    );

    if (!lm?.emp_id) {
      return res.status(404).json({
        success: false,
        message: "No employee record linked to this login.",
      });
    }

    const [rows] = await db.query(
      `SELECT
          e.emp_id, e.first_name, e.mid_name, e.last_name,
          e.email_id, e.phone_number, e.date_of_birth, e.gender,
          e.department_id, d.department_name,
          e.role_id, r.role_name,
          e.date_of_joining, e.employment_type, e.work_type,
          e.permanent_address, e.communication_address,
          e.father_name, e.emergency_contact_relation, e.emergency_contact,
          e.pf_number, e.esic_number, e.years_experience,
          e.status, e.has_face_embedding,
          CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS tl_name
       FROM employee_master e
       LEFT JOIN department_master d ON d.department_id = e.department_id
       LEFT JOIN role_master        r ON r.role_id        = e.role_id
       LEFT JOIN employee_master    t ON t.emp_id          = e.tl_id
       WHERE e.emp_id = ? AND e.tenant_id = ?
       LIMIT 1`,
      [lm.emp_id, tenantId],
    );

    if (!rows.length) {
      return res
        .status(404)
        .json({ success: false, message: "Employee not found." });
    }

    res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error("[GET /employees/me]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/stats/summary
// Tenant-level headcount breakdown — for dashboards.
// NOTE: Must be defined BEFORE /:emp_id to avoid route collision.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/stats/summary", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  try {
    const [[counts]] = await db.query(
      `SELECT
          COUNT(*) AS total,
          SUM(status = 'Active')   AS active,
          SUM(status = 'Inactive') AS inactive,
          SUM(status = 'Relieved') AS relieved,
          SUM(employment_type = 'Permanent') AS permanent,
          SUM(employment_type = 'Contract')  AS contract,
          SUM(employment_type = 'Intern')    AS interns,
          SUM(gender = 'Male')   AS male,
          SUM(gender = 'Female') AS female,
          SUM(gender = 'Other')  AS other_gender
       FROM employee_master
       WHERE tenant_id = ?`,
      [tenantId],
    );

    const [byDept] = await db.query(
      `SELECT d.department_name, COUNT(*) AS count
         FROM employee_master e
         JOIN department_master d ON d.department_id = e.department_id
        WHERE e.tenant_id = ? AND e.status = 'Active'
        GROUP BY e.department_id
        ORDER BY count DESC`,
      [tenantId],
    );

    const [byRole] = await db.query(
      `SELECT r.role_name, COUNT(*) AS count
         FROM employee_master e
         JOIN role_master r ON r.role_id = e.role_id
        WHERE e.tenant_id = ? AND e.status = 'Active'
        GROUP BY e.role_id
        ORDER BY count DESC`,
      [tenantId],
    );

    res.json({
      success: true,
      data: { ...counts, by_department: byDept, by_role: byRole },
    });
  } catch (err) {
    console.error("[GET /employees/stats/summary]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/face-embeddings/all
// Returns all employees with face embeddings for client-side recognition.
// AppAdmin (6) or Admin (1) only.
// NOTE: Must be defined BEFORE /:emp_id to avoid route collision.
// ─────────────────────────────────────────────────────────────────────────────
router.get(
  "/face-embeddings/all",
  requireAuth,
  requireRole(1, 6),
  async (req, res) => {
    const { tenantId } = req.user;

    try {
      const [rows] = await db.query(
        `SELECT emp_id,
                CONCAT(first_name, ' ', COALESCE(last_name,'')) AS full_name,
                face_embedding
           FROM employee_master
          WHERE tenant_id = ? AND has_face_embedding = 1 AND status = 'Active'`,
        [tenantId],
      );

      res.json({ success: true, count: rows.length, data: rows });
    } catch (err) {
      console.error("[GET /employees/face-embeddings/all]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/by-department/:dept_id
// Convenience endpoint — employees in one department.
// NOTE: Must be defined BEFORE /:emp_id to avoid route collision.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/by-department/:dept_id", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { dept_id } = req.params;
  const { status = "Active" } = req.query;

  try {
    const [rows] = await db.query(
      `SELECT e.emp_id, e.first_name, e.mid_name, e.last_name,
              e.email_id, e.phone_number, e.role_id, r.role_name,
              e.employment_type, e.work_type, e.status
         FROM employee_master e
         LEFT JOIN role_master r ON r.role_id = e.role_id
        WHERE e.tenant_id = ? AND e.department_id = ? AND e.status = ?
        ORDER BY e.first_name`,
      [tenantId, dept_id, status],
    );

    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error("[GET /employees/by-department]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/by-tl/:tl_id
// Team lead's reportees.
// NOTE: Must be defined BEFORE /:emp_id to avoid route collision.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/by-tl/:tl_id", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { tl_id } = req.params;
  const { status = "Active" } = req.query;

  try {
    const [rows] = await db.query(
      `SELECT e.emp_id, e.first_name, e.mid_name, e.last_name,
              e.email_id, e.phone_number,
              e.department_id, d.department_name,
              e.role_id, r.role_name, e.status
         FROM employee_master e
         LEFT JOIN department_master d ON d.department_id = e.department_id
         LEFT JOIN role_master        r ON r.role_id        = e.role_id
        WHERE e.tenant_id = ? AND e.tl_id = ? AND e.status = ?
        ORDER BY e.first_name`,
      [tenantId, tl_id, status],
    );

    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error("[GET /employees/by-tl]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/:emp_id
// Returns full employee record (no photo blob — use /photo endpoint).
// ─────────────────────────────────────────────────────────────────────────────
router.get("/:emp_id", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { emp_id } = req.params;

  try {
    const [rows] = await db.query(
      `SELECT
          e.emp_id, e.tenant_id, e.first_name, e.mid_name, e.last_name,
          e.email_id, e.phone_number, e.date_of_birth, e.gender,
          e.department_id, d.department_name,
          e.role_id, r.role_name,
          e.date_of_joining, e.date_of_relieving,
          e.employment_type, e.work_type,
          e.permanent_address, e.communication_address,
          e.aadhar_number, e.pan_number, e.passport_number,
          e.father_name, e.emergency_contact_relation, e.emergency_contact,
          e.pf_number, e.esic_number, e.years_experience,
          e.status, e.tl_id, e.has_face_embedding,
          e.created_at, e.updated_at,
          CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS tl_name,
          lm.login_id, lm.username, lm.is_first_login, lm.last_login_at
       FROM employee_master e
       LEFT JOIN department_master d  ON d.department_id = e.department_id
       LEFT JOIN role_master        r  ON r.role_id        = e.role_id
       LEFT JOIN employee_master    t  ON t.emp_id          = e.tl_id
       LEFT JOIN login_master       lm ON lm.emp_id         = e.emp_id
       WHERE e.emp_id = ? AND e.tenant_id = ?
       LIMIT 1`,
      [emp_id, tenantId],
    );

    if (!rows.length) {
      return res
        .status(404)
        .json({ success: false, message: "Employee not found." });
    }

    res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error("[GET /employees/:id]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/employees
// ADMIN / HR ONLY — Direct insert into employee_master (bypasses approval).
// Used for bulk imports or admin overrides.
// For general use, employees should go through /employee-pending-request.
// ─────────────────────────────────────────────────────────────────────────────
router.post("/", requireAuth, requireRole(1, 2), async (req, res) => {
  const { tenantId, companyId } = req.user;

  const {
    first_name,
    mid_name,
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    department_id,
    role_id,
    date_of_joining,
    date_of_relieving,
    employment_type,
    work_type,
    permanent_address,
    communication_address,
    aadhar_number,
    pan_number,
    passport_number,
    father_name,
    emergency_contact_relation,
    emergency_contact,
    pf_number,
    esic_number,
    years_experience,
    tl_id,
    username: rawUsername,
    initial_password = "Pass@1234",
  } = req.body;

  // ── Required field validation ────────────────────────────────────────────
  const required = {
    first_name,
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    department_id,
    role_id,
    date_of_joining,
    employment_type,
    work_type,
    permanent_address,
  };

  const missing = Object.entries(required)
    .filter(([, v]) => v === undefined || v === null || v === "")
    .map(([k]) => k);

  if (missing.length) {
    return res.status(400).json({
      success: false,
      message: `Missing required fields: ${missing.join(", ")}`,
    });
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email_id.trim())) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid email address." });
  }
  if (!/^[6-9]\d{9}$/.test(phone_number.trim())) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid phone number." });
  }

  // Validate department belongs to tenant
  const [[dept]] = await db.query(
    "SELECT department_id FROM department_master WHERE department_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
    [department_id, tenantId],
  );
  if (!dept) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid department for this tenant." });
  }

  // Validate role belongs to tenant
  const [[role]] = await db.query(
    "SELECT role_id FROM role_master WHERE role_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
    [role_id, tenantId],
  );
  if (!role) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid role for this tenant." });
  }

  const username = rawUsername?.trim() || email_id.split("@")[0].toLowerCase();

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // ── Duplicate checks ───────────────────────────────────────────────────
    const [[dupEmail]] = await conn.query(
      "SELECT emp_id FROM employee_master WHERE email_id = ? LIMIT 1",
      [email_id.trim().toLowerCase()],
    );
    if (dupEmail) {
      await conn.rollback();
      return res
        .status(409)
        .json({ success: false, message: "Email already registered." });
    }

    const [[dupPhone]] = await conn.query(
      "SELECT emp_id FROM employee_master WHERE phone_number = ? LIMIT 1",
      [phone_number.trim()],
    );
    if (dupPhone) {
      await conn.rollback();
      return res
        .status(409)
        .json({ success: false, message: "Phone number already registered." });
    }

    const [[dupUser]] = await conn.query(
      "SELECT login_id FROM login_master WHERE username = ? LIMIT 1",
      [username],
    );
    if (dupUser) {
      await conn.rollback();
      return res.status(409).json({
        success: false,
        message: `Username '${username}' already taken.`,
      });
    }

    // ── Insert employee ────────────────────────────────────────────────────
    const [empResult] = await conn.query(
      `INSERT INTO employee_master
        (tenant_id, first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         department_id, role_id,
         date_of_joining, date_of_relieving,
         employment_type, work_type,
         permanent_address, communication_address,
         aadhar_number, pan_number, passport_number,
         father_name, emergency_contact_relation, emergency_contact,
         pf_number, esic_number, years_experience,
         tl_id, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
      [
        tenantId,
        first_name.trim(),
        nullIfEmpty(mid_name),
        last_name.trim(),
        email_id.trim().toLowerCase(),
        phone_number.trim(),
        date_of_birth,
        gender,
        department_id,
        role_id,
        date_of_joining,
        nullIfEmpty(date_of_relieving),
        employment_type,
        work_type,
        permanent_address,
        nullIfEmpty(communication_address),
        nullIfEmpty(aadhar_number),
        nullIfEmpty(pan_number),
        nullIfEmpty(passport_number),
        nullIfEmpty(father_name),
        nullIfEmpty(emergency_contact_relation),
        nullIfEmpty(emergency_contact),
        nullIfEmpty(pf_number),
        nullIfEmpty(esic_number),
        years_experience !== undefined ? parseInt(years_experience, 10) : null,
        nullIfEmpty(tl_id),
      ],
    );

    const empId = empResult.insertId;
    const hashedPass = await bcrypt.hash(initial_password, 12);

    await conn.query(
      `INSERT INTO login_master
        (tenant_id, company_id, emp_id, username, password,
         role_id, is_first_login, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
      [tenantId, companyId, empId, username, hashedPass, role_id],
    );

    await conn.commit();

    res.status(201).json({
      success: true,
      message: "Employee created successfully.",
      emp_id: empId,
      username,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[POST /employees]", err);
    res.status(500).json({ success: false, message: "Server error." });
  } finally {
    conn.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/employees/:emp_id
// Updates an existing employee's details.
// Admin / HR can update anyone; Employee can only update safe personal fields.
// ─────────────────────────────────────────────────────────────────────────────
router.put("/:emp_id", requireAuth, async (req, res) => {
  const { tenantId, roleId, loginId } = req.user;
  const { emp_id } = req.params;

  // Determine caller's emp_id
  let callerEmpId = null;
  try {
    const [[lm]] = await db.query(
      "SELECT emp_id FROM login_master WHERE login_id = ? LIMIT 1",
      [loginId],
    );
    callerEmpId = lm?.emp_id ?? null;
  } catch (_) {}

  const isSelf = callerEmpId !== null && String(callerEmpId) === String(emp_id);
  const isAdminOrHR = [1, 2].includes(roleId);

  if (!isSelf && !isAdminOrHR) {
    return res.status(403).json({ success: false, message: "Forbidden." });
  }

  // Employees can only update safe personal fields
  const selfAllowed = new Set([
    "communication_address",
    "phone_number",
    "emergency_contact",
    "emergency_contact_relation",
  ]);

  const body = req.body;
  const fields = [];
  const params = [];

  const allFields = [
    "first_name",
    "mid_name",
    "last_name",
    "email_id",
    "phone_number",
    "date_of_birth",
    "gender",
    "department_id",
    "role_id",
    "date_of_joining",
    "date_of_relieving",
    "employment_type",
    "work_type",
    "permanent_address",
    "communication_address",
    "aadhar_number",
    "pan_number",
    "passport_number",
    "father_name",
    "emergency_contact_relation",
    "emergency_contact",
    "pf_number",
    "esic_number",
    "years_experience",
    "tl_id",
    "status",
  ];

  for (const field of allFields) {
    if (!(field in body)) continue;
    if (!isAdminOrHR && !selfAllowed.has(field)) continue;
    fields.push(`${field} = ?`);
    params.push(body[field] === "" ? null : body[field]);
  }

  if (!fields.length) {
    return res
      .status(400)
      .json({ success: false, message: "No updatable fields provided." });
  }

  params.push(emp_id, tenantId);

  try {
    const [result] = await db.query(
      `UPDATE employee_master SET ${fields.join(", ")} WHERE emp_id = ? AND tenant_id = ?`,
      params,
    );

    if (result.affectedRows === 0) {
      return res
        .status(404)
        .json({ success: false, message: "Employee not found." });
    }

    if (isAdminOrHR && body.role_id !== undefined) {
      await db.query("UPDATE login_master SET role_id = ? WHERE emp_id = ?", [
        body.role_id,
        emp_id,
      ]);
    }

    res.json({ success: true, message: "Employee updated." });
  } catch (err) {
    console.error("[PUT /employees/:id]", err);
    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({
        success: false,
        message: "Duplicate value (email / phone / Aadhar / PAN).",
      });
    }
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/employees/:emp_id/status
// Change employee status. Admin / HR only.
// ─────────────────────────────────────────────────────────────────────────────
router.patch(
  "/:emp_id/status",
  requireAuth,
  requireRole(1, 2),
  async (req, res) => {
    const { tenantId } = req.user;
    const { emp_id } = req.params;
    const { status, date_of_relieving } = req.body;

    const validStatuses = ["Active", "Inactive", "Relieved"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `status must be one of: ${validStatuses.join(", ")}`,
      });
    }

    try {
      const extraFields =
        status === "Relieved" && date_of_relieving
          ? ", date_of_relieving = ?"
          : "";
      const extraParams =
        status === "Relieved" && date_of_relieving ? [date_of_relieving] : [];

      const [result] = await db.query(
        `UPDATE employee_master
            SET status = ? ${extraFields}
          WHERE emp_id = ? AND tenant_id = ?`,
        [status, ...extraParams, emp_id, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "Employee not found." });
      }

      if (status !== "Active") {
        await db.query(
          `UPDATE login_master
              SET status = 'Inactive', session_token = NULL, device_logged_in = 0
            WHERE emp_id = ?`,
          [emp_id],
        );
      } else {
        await db.query(
          "UPDATE login_master SET status = 'Active' WHERE emp_id = ?",
          [emp_id],
        );
      }

      res.json({
        success: true,
        message: `Employee status updated to ${status}.`,
      });
    } catch (err) {
      console.error("[PATCH /employees/:id/status]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/employees/:emp_id
// Soft delete (default) or hard delete (?hard=1). Admin only.
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/:emp_id", requireAuth, requireRole(1), async (req, res) => {
  const { tenantId } = req.user;
  const { emp_id } = req.params;
  const hard = req.query.hard === "1";

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    if (hard) {
      await conn.query("DELETE FROM login_master WHERE emp_id = ?", [emp_id]);
      const [result] = await conn.query(
        "DELETE FROM employee_master WHERE emp_id = ? AND tenant_id = ?",
        [emp_id, tenantId],
      );
      if (result.affectedRows === 0) {
        await conn.rollback();
        return res
          .status(404)
          .json({ success: false, message: "Employee not found." });
      }
    } else {
      const [result] = await conn.query(
        "UPDATE employee_master SET status = 'Inactive' WHERE emp_id = ? AND tenant_id = ?",
        [emp_id, tenantId],
      );
      if (result.affectedRows === 0) {
        await conn.rollback();
        return res
          .status(404)
          .json({ success: false, message: "Employee not found." });
      }
      await conn.query(
        `UPDATE login_master
            SET status = 'Inactive', session_token = NULL, device_logged_in = 0
          WHERE emp_id = ?`,
        [emp_id],
      );
    }

    await conn.commit();
    res.json({
      success: true,
      message: hard ? "Employee permanently deleted." : "Employee deactivated.",
    });
  } catch (err) {
    await conn.rollback();
    console.error("[DELETE /employees/:id]", err);
    res.status(500).json({ success: false, message: "Server error." });
  } finally {
    conn.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/:emp_id/photo
// Returns the profile photo as the correct MIME type.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/:emp_id/photo", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { emp_id } = req.params;

  try {
    const [[row]] = await db.query(
      "SELECT profile_photo, profile_photo_mime FROM employee_master WHERE emp_id = ? AND tenant_id = ?",
      [emp_id, tenantId],
    );

    if (!row || !row.profile_photo) {
      return res
        .status(404)
        .json({ success: false, message: "No photo found." });
    }

    res.set("Content-Type", row.profile_photo_mime || "image/jpeg");
    res.send(row.profile_photo);
  } catch (err) {
    console.error("[GET /employees/:id/photo]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/employees/:emp_id/photo
// Uploads / replaces the profile photo.
// Accessible by the employee themselves OR Admin/HR.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/:emp_id/photo",
  requireAuth,
  upload.single("photo"),
  async (req, res) => {
    const { tenantId, roleId, loginId } = req.user;
    const { emp_id } = req.params;

    if (!req.file) {
      return res
        .status(400)
        .json({ success: false, message: "No image file provided." });
    }

    let callerEmpId = null;
    try {
      const [[lm]] = await db.query(
        "SELECT emp_id FROM login_master WHERE login_id = ? LIMIT 1",
        [loginId],
      );
      callerEmpId = lm?.emp_id ?? null;
    } catch (_) {}

    const isSelf =
      callerEmpId !== null && String(callerEmpId) === String(emp_id);
    const isAdminOrHR = [1, 2].includes(roleId);

    if (!isSelf && !isAdminOrHR) {
      return res.status(403).json({ success: false, message: "Forbidden." });
    }

    try {
      const [result] = await db.query(
        `UPDATE employee_master
            SET profile_photo = ?, profile_photo_mime = ?
          WHERE emp_id = ? AND tenant_id = ?`,
        [req.file.buffer, req.file.mimetype, emp_id, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "Employee not found." });
      }

      res.json({ success: true, message: "Profile photo updated." });
    } catch (err) {
      console.error("[POST /employees/:id/photo]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/employees/:emp_id/face-embedding
// Stores a face embedding JSON. Admin / HR / AppAdmin only.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/:emp_id/face-embedding",
  requireAuth,
  requireRole(1, 2, 6),
  async (req, res) => {
    const { tenantId } = req.user;
    const { emp_id } = req.params;
    const { embedding } = req.body;

    if (!Array.isArray(embedding) || !embedding.length) {
      return res.status(400).json({
        success: false,
        message: "embedding must be a non-empty array.",
      });
    }

    try {
      const [result] = await db.query(
        `UPDATE employee_master
            SET face_embedding = ?, has_face_embedding = 1
          WHERE emp_id = ? AND tenant_id = ?`,
        [JSON.stringify(embedding), emp_id, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "Employee not found." });
      }

      res.json({ success: true, message: "Face embedding saved." });
    } catch (err) {
      console.error("[POST /employees/:id/face-embedding]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/employees/bulk
// Bulk-create employees from a JSON array. Admin / HR only.
// ─────────────────────────────────────────────────────────────────────────────
router.post("/bulk", requireAuth, requireRole(1, 2), async (req, res) => {
  const { tenantId, companyId } = req.user;
  const { employees } = req.body;

  if (!Array.isArray(employees) || !employees.length) {
    return res
      .status(400)
      .json({ success: false, message: "employees array is required." });
  }

  const results = [];

  for (const emp of employees) {
    const {
      first_name,
      mid_name,
      last_name,
      email_id,
      phone_number,
      date_of_birth,
      gender,
      department_id,
      role_id,
      date_of_joining,
      employment_type,
      work_type,
      permanent_address,
      communication_address,
      aadhar_number,
      pan_number,
      passport_number,
      father_name,
      emergency_contact_relation,
      emergency_contact,
      pf_number,
      esic_number,
      years_experience,
      tl_id,
      username: rawUsername,
      initial_password = "Pass@1234",
    } = emp;

    const username =
      rawUsername?.trim() || email_id?.split("@")[0].toLowerCase();

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      const [empResult] = await conn.query(
        `INSERT INTO employee_master
            (tenant_id, first_name, mid_name, last_name,
             email_id, phone_number, date_of_birth, gender,
             department_id, role_id,
             date_of_joining, employment_type, work_type,
             permanent_address, communication_address,
             aadhar_number, pan_number, passport_number,
             father_name, emergency_contact_relation, emergency_contact,
             pf_number, esic_number, years_experience, tl_id,
             status, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
        [
          tenantId,
          first_name?.trim(),
          nullIfEmpty(mid_name),
          last_name?.trim(),
          email_id?.trim().toLowerCase(),
          phone_number?.trim(),
          date_of_birth,
          gender,
          department_id,
          role_id,
          date_of_joining,
          employment_type,
          work_type,
          permanent_address,
          nullIfEmpty(communication_address),
          nullIfEmpty(aadhar_number),
          nullIfEmpty(pan_number),
          nullIfEmpty(passport_number),
          nullIfEmpty(father_name),
          nullIfEmpty(emergency_contact_relation),
          nullIfEmpty(emergency_contact),
          nullIfEmpty(pf_number),
          nullIfEmpty(esic_number),
          years_experience !== undefined
            ? parseInt(years_experience, 10)
            : null,
          nullIfEmpty(tl_id),
        ],
      );

      const empId = empResult.insertId;
      const hashed = await bcrypt.hash(initial_password, 12);

      await conn.query(
        `INSERT INTO login_master
            (tenant_id, company_id, emp_id, username, password, role_id, is_first_login, status, created_at)
           VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
        [tenantId, companyId, empId, username, hashed, role_id],
      );

      await conn.commit();
      results.push({ email_id, success: true, emp_id: empId, username });
    } catch (err) {
      await conn.rollback();
      results.push({ email_id, success: false, error: err.message });
    } finally {
      conn.release();
    }
  }

  const created = results.filter((r) => r.success).length;
  const failed = results.length - created;

  res.status(207).json({ success: true, created, failed, results });
});

module.exports = router;
