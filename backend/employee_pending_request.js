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
// POST /api/employee-pending-request
// ANY authenticated user within the tenant can submit a new employee request.
// The request goes to employee_pending_request with admin_approve = 'PENDING'.
// Admin/HR approves it before it lands in employee_master.
//
// Body (JSON):
//   Required: first_name, last_name, email_id, phone_number, date_of_birth,
//             gender, department_id, role_id, date_of_joining,
//             employment_type, work_type, permanent_address,
//             username, password
//   Optional: mid_name, communication_address, aadhar_number, pan_number,
//             passport_number, father_name, emergency_contact_relation,
//             emergency_contact, pf_number, esic_number, years_experience,
//             tl_id, education (array)
// ─────────────────────────────────────────────────────────────────────────────
router.post("/employee-pending-request", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

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
    username,
    password,
    education = [],
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
    username,
    password,
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

  // ── Format validations ───────────────────────────────────────────────────
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email_id.trim())) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid email address." });
  }
  if (!/^[6-9]\d{9}$/.test(phone_number.trim())) {
    return res
      .status(400)
      .json({
        success: false,
        message: "Invalid phone number (must be 10 digits starting with 6-9).",
      });
  }

  // ── Validate department belongs to this tenant ────────────────────────────
  const [[dept]] = await db.query(
    "SELECT department_id FROM department_master WHERE department_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
    [department_id, tenantId],
  );
  if (!dept) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid department for this tenant." });
  }

  // ── Validate role belongs to this tenant ─────────────────────────────────
  const [[role]] = await db.query(
    "SELECT role_id FROM role_master WHERE role_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
    [role_id, tenantId],
  );
  if (!role) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid role for this tenant." });
  }

  // ── Validate TL belongs to this tenant (if provided) ─────────────────────
  if (nullIfEmpty(tl_id)) {
    const [[tl]] = await db.query(
      "SELECT emp_id FROM employee_master WHERE emp_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
      [tl_id, tenantId],
    );
    if (!tl) {
      return res
        .status(400)
        .json({
          success: false,
          message: "Invalid Team Lead for this tenant.",
        });
    }
  }

  // ── Duplicate username check in login_master ──────────────────────────────
  const [[dupUser]] = await db.query(
    "SELECT login_id FROM login_master WHERE username = ? LIMIT 1",
    [username.trim()],
  );
  if (dupUser) {
    return res.status(409).json({
      success: false,
      message: `Username '${username}' is already taken.`,
    });
  }

  // ── Duplicate email check in pending requests (same tenant, still PENDING) ──
  const [[dupPendingEmail]] = await db.query(
    "SELECT request_id FROM employee_pending_request WHERE email_id = ? AND tenant_id = ? AND admin_approve = 'PENDING' LIMIT 1",
    [email_id.trim().toLowerCase(), tenantId],
  );
  if (dupPendingEmail) {
    return res.status(409).json({
      success: false,
      message: "A pending request with this email already exists.",
    });
  }

  // ── Duplicate email check in employee_master ──────────────────────────────
  const [[dupEmpEmail]] = await db.query(
    "SELECT emp_id FROM employee_master WHERE email_id = ? LIMIT 1",
    [email_id.trim().toLowerCase()],
  );
  if (dupEmpEmail) {
    return res.status(409).json({
      success: false,
      message: "Email is already registered to an existing employee.",
    });
  }

  // ── Hash the password ─────────────────────────────────────────────────────
  const hashedPassword = await bcrypt.hash(password, 12);

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // ── Insert into employee_pending_request ──────────────────────────────
    const [result] = await conn.query(
      `INSERT INTO employee_pending_request
        (tenant_id, first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         department_id, role_id,
         date_of_joining,
         employment_type, work_type,
         permanent_address, communication_address,
         aadhar_number, pan_number, passport_number,
         father_name, emergency_contact_relation, emergency_contact,
         pf_number, esic_number, years_experience,
         tl_id, username, password,
         request_type, admin_approve, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'NEW', 'PENDING', 'Active', NOW())`,
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
        username.trim(),
        hashedPassword,
      ],
    );

    const requestId = result.insertId;

    // ── Insert education records if any ───────────────────────────────────
    if (Array.isArray(education) && education.length > 0) {
      const eduValues = education.map((e) => [
        requestId,
        nullIfEmpty(e.education_level),
        nullIfEmpty(e.stream),
        nullIfEmpty(e.score),
        nullIfEmpty(e.year_of_passout),
        nullIfEmpty(e.university),
        nullIfEmpty(e.college_name),
      ]);

      await conn.query(
        `INSERT INTO education_pending_request
          (request_id, education_level, stream, score, year_of_passout, university, college_name)
         VALUES ?`,
        [eduValues],
      );
    }

    await conn.commit();

    res.status(201).json({
      success: true,
      message:
        "Employee request submitted successfully. Awaiting admin approval.",
      request_id: requestId,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[POST /employee-pending-request]", err);
    res.status(500).json({ success: false, message: "Server error." });
  } finally {
    conn.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/pending-request/:request_id/photo
// Upload photo for a pending request. Anyone authenticated in the same tenant.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/pending-request/:request_id/photo",
  requireAuth,
  upload.single("photo"),
  async (req, res) => {
    const { tenantId } = req.user;
    const { request_id } = req.params;

    if (!req.file) {
      return res
        .status(400)
        .json({ success: false, message: "No image file provided." });
    }

    try {
      const [result] = await db.query(
        `UPDATE employee_pending_request
            SET profile_photo = ?, profile_photo_mime = ?
          WHERE request_id = ? AND tenant_id = ?`,
        [req.file.buffer, req.file.mimetype, request_id, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "Pending request not found." });
      }

      res.json({ success: true, message: "Photo uploaded successfully." });
    } catch (err) {
      console.error("[POST /pending-request/:id/photo]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/requests
// Lists all pending requests for the tenant.
// Admin / HR only.
// Query params:
//   status   — PENDING | APPROVED | REJECTED  (default: PENDING)
//   page     — 1-based (default 1)
//   limit    — rows per page (default 50, max 200)
// ─────────────────────────────────────────────────────────────────────────────
router.get(
  "/admin/requests",
  requireAuth,
  requireRole(1, 2),
  async (req, res) => {
    const { tenantId } = req.user;
    const { status = "PENDING", page = 1, limit = 50 } = req.query;

    const safePage = Math.max(1, parseInt(page, 10) || 1);
    const safeLimit = Math.min(200, Math.max(1, parseInt(limit, 10) || 50));
    const offset = (safePage - 1) * safeLimit;

    const conditions = ["r.tenant_id = ?"];
    const params = [tenantId];

    if (status) {
      conditions.push("r.admin_approve = ?");
      params.push(status.toUpperCase());
    }

    const where = conditions.join(" AND ");

    try {
      const [[{ total }]] = await db.query(
        `SELECT COUNT(*) AS total FROM employee_pending_request r WHERE ${where}`,
        params,
      );

      const [rows] = await db.query(
        `SELECT
            r.request_id, r.emp_id, r.tenant_id,
            r.first_name, r.mid_name, r.last_name,
            r.email_id, r.phone_number, r.date_of_birth, r.gender,
            r.department_id, d.department_name,
            r.role_id, rl.role_name,
            r.date_of_joining, r.employment_type, r.work_type,
            r.permanent_address, r.communication_address,
            r.aadhar_number, r.pan_number, r.passport_number,
            r.father_name, r.emergency_contact_relation, r.emergency_contact,
            r.pf_number, r.esic_number, r.years_experience,
            r.tl_id,
            CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS tl_name,
            r.username, r.request_type, r.admin_approve, r.status,
            r.edit_reason, r.reject_reason,
            r.created_at, r.updated_at
         FROM employee_pending_request r
         LEFT JOIN department_master d  ON d.department_id = r.department_id
         LEFT JOIN role_master        rl ON rl.role_id       = r.role_id
         LEFT JOIN employee_master    t  ON t.emp_id          = r.tl_id
         WHERE ${where}
         ORDER BY r.created_at DESC
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
      console.error("[GET /admin/requests]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/request/:request_id
// Returns a single pending request by ID.
// Admin / HR only.
// ─────────────────────────────────────────────────────────────────────────────
router.get(
  "/admin/request/:request_id",
  requireAuth,
  requireRole(1, 2),
  async (req, res) => {
    const { tenantId } = req.user;
    const { request_id } = req.params;

    try {
      const [rows] = await db.query(
        `SELECT
            r.request_id, r.emp_id, r.tenant_id,
            r.first_name, r.mid_name, r.last_name,
            r.email_id, r.phone_number, r.date_of_birth, r.gender,
            r.department_id, d.department_name,
            r.role_id, rl.role_name,
            r.date_of_joining, r.employment_type, r.work_type,
            r.permanent_address, r.communication_address,
            r.aadhar_number, r.pan_number, r.passport_number,
            r.father_name, r.emergency_contact_relation, r.emergency_contact,
            r.pf_number, r.esic_number, r.years_experience,
            r.tl_id,
            CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS tl_name,
            r.username, r.request_type, r.admin_approve, r.status,
            r.edit_reason, r.reject_reason,
            r.created_at, r.updated_at
         FROM employee_pending_request r
         LEFT JOIN department_master d  ON d.department_id = r.department_id
         LEFT JOIN role_master        rl ON rl.role_id       = r.role_id
         LEFT JOIN employee_master    t  ON t.emp_id          = r.tl_id
         WHERE r.request_id = ? AND r.tenant_id = ?
         LIMIT 1`,
        [request_id, tenantId],
      );

      if (!rows.length) {
        return res
          .status(404)
          .json({ success: false, message: "Request not found." });
      }

      res.json({ success: true, data: rows[0] });
    } catch (err) {
      console.error("[GET /admin/request/:id]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/approve-request/:request_id
// Approves a NEW employee pending request.
// On approval: creates employee_master + login_master records in a transaction.
// Admin / HR only.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/admin/approve-request/:request_id",
  requireAuth,
  requireRole(1, 2),
  async (req, res) => {
    const { tenantId, companyId } = req.user;
    const { request_id } = req.params;

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // ── Fetch the pending request ─────────────────────────────────────
      const [[req_row]] = await conn.query(
        `SELECT * FROM employee_pending_request
          WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'PENDING'
          LIMIT 1`,
        [request_id, tenantId],
      );

      if (!req_row) {
        await conn.rollback();
        return res.status(404).json({
          success: false,
          message: "Pending request not found or already processed.",
        });
      }

      if (req_row.request_type !== "NEW") {
        await conn.rollback();
        return res.status(400).json({
          success: false,
          message:
            "This endpoint is for NEW requests only. Use /approve-edit-request for UPDATE requests.",
        });
      }

      // ── Check for email / phone duplicates in employee_master ─────────
      const [[dupEmail]] = await conn.query(
        "SELECT emp_id FROM employee_master WHERE email_id = ? LIMIT 1",
        [req_row.email_id],
      );
      if (dupEmail) {
        await conn.rollback();
        return res.status(409).json({
          success: false,
          message: "An employee with this email already exists.",
        });
      }

      const [[dupPhone]] = await conn.query(
        "SELECT emp_id FROM employee_master WHERE phone_number = ? LIMIT 1",
        [req_row.phone_number],
      );
      if (dupPhone) {
        await conn.rollback();
        return res.status(409).json({
          success: false,
          message: "An employee with this phone number already exists.",
        });
      }

      // ── Insert into employee_master ───────────────────────────────────
      const [empResult] = await conn.query(
        `INSERT INTO employee_master
          (tenant_id, first_name, mid_name, last_name,
           email_id, phone_number, date_of_birth, gender,
           department_id, role_id,
           date_of_joining,
           employment_type, work_type,
           permanent_address, communication_address,
           aadhar_number, pan_number, passport_number,
           father_name, emergency_contact_relation, emergency_contact,
           pf_number, esic_number, years_experience,
           tl_id, status,
           profile_photo, profile_photo_mime,
           created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', ?, ?, NOW())`,
        [
          req_row.tenant_id,
          req_row.first_name,
          req_row.mid_name,
          req_row.last_name,
          req_row.email_id,
          req_row.phone_number,
          req_row.date_of_birth,
          req_row.gender,
          req_row.department_id,
          req_row.role_id,
          req_row.date_of_joining,
          req_row.employment_type,
          req_row.work_type,
          req_row.permanent_address,
          req_row.communication_address,
          req_row.aadhar_number,
          req_row.pan_number,
          req_row.passport_number,
          req_row.father_name,
          req_row.emergency_contact_relation,
          req_row.emergency_contact,
          req_row.pf_number,
          req_row.esic_number,
          req_row.years_experience,
          req_row.tl_id,
          req_row.profile_photo || null,
          req_row.profile_photo_mime || null,
        ],
      );

      const empId = empResult.insertId;

      // ── Create login_master record (password already hashed) ──────────
      await conn.query(
        `INSERT INTO login_master
          (tenant_id, company_id, emp_id, username, password,
           role_id, is_first_login, status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
        [
          tenantId,
          companyId,
          empId,
          req_row.username,
          req_row.password,
          req_row.role_id,
        ],
      );

      // ── Copy education records from pending to employee ───────────────
      const [eduRows] = await conn.query(
        `SELECT * FROM education_pending_request WHERE request_id = ?`,
        [request_id],
      );

      if (eduRows.length > 0) {
        const eduValues = eduRows.map((e) => [
          empId,
          e.education_level,
          e.stream,
          e.score,
          e.year_of_passout,
          e.university,
          e.college_name,
        ]);

        await conn.query(
          `INSERT INTO education_master
            (emp_id, education_level, stream, score, year_of_passout, university, college_name)
           VALUES ?`,
          [eduValues],
        );
      }

      // ── Mark the request as APPROVED and link the new emp_id ─────────
      await conn.query(
        `UPDATE employee_pending_request
            SET admin_approve = 'APPROVED', emp_id = ?
          WHERE request_id = ?`,
        [empId, request_id],
      );

      await conn.commit();

      res.json({
        success: true,
        message: "Employee request approved. Employee and login created.",
        emp_id: empId,
      });
    } catch (err) {
      await conn.rollback();
      console.error("[POST /admin/approve-request]", err);
      res.status(500).json({ success: false, message: "Server error." });
    } finally {
      conn.release();
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/reject-request/:request_id
// Rejects a pending request with a reason.
// Admin / HR only.
// Body: { reject_reason: string }
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/admin/reject-request/:request_id",
  requireAuth,
  requireRole(1, 2),
  async (req, res) => {
    const { tenantId } = req.user;
    const { request_id } = req.params;
    const { reject_reason } = req.body;

    if (!reject_reason || !reject_reason.trim()) {
      return res.status(400).json({
        success: false,
        message: "reject_reason is required.",
      });
    }

    try {
      const [result] = await db.query(
        `UPDATE employee_pending_request
            SET admin_approve = 'REJECTED', reject_reason = ?
          WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'PENDING'`,
        [reject_reason.trim(), request_id, tenantId],
      );

      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          message: "Pending request not found or already processed.",
        });
      }

      res.json({ success: true, message: "Request rejected." });
    } catch (err) {
      console.error("[POST /admin/reject-request]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/admin/resubmit-request/:request_id
// The original submitter resubmits a REJECTED request with corrections.
// ANY authenticated user in the same tenant can resubmit (their own rejected request).
// ─────────────────────────────────────────────────────────────────────────────
router.put(
  "/admin/resubmit-request/:request_id",
  requireAuth,
  async (req, res) => {
    const { tenantId } = req.user;
    const { request_id } = req.params;

    // ── Fetch the existing request ────────────────────────────────────────
    const [[existing]] = await db.query(
      `SELECT * FROM employee_pending_request
        WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'REJECTED'
        LIMIT 1`,
      [request_id, tenantId],
    );

    if (!existing) {
      return res.status(404).json({
        success: false,
        message: "Rejected request not found.",
      });
    }

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
      username,
      education = [],
    } = req.body;

    // ── Validate department belongs to tenant ─────────────────────────────
    if (department_id) {
      const [[dept]] = await db.query(
        "SELECT department_id FROM department_master WHERE department_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
        [department_id, tenantId],
      );
      if (!dept) {
        return res.status(400).json({
          success: false,
          message: "Invalid department for this tenant.",
        });
      }
    }

    // ── Validate role belongs to tenant ──────────────────────────────────
    if (role_id) {
      const [[role]] = await db.query(
        "SELECT role_id FROM role_master WHERE role_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
        [role_id, tenantId],
      );
      if (!role) {
        return res.status(400).json({
          success: false,
          message: "Invalid role for this tenant.",
        });
      }
    }

    // ── Username conflict check (skip if same username) ───────────────────
    if (username && username.trim() !== existing.username) {
      const [[dupUser]] = await db.query(
        "SELECT login_id FROM login_master WHERE username = ? LIMIT 1",
        [username.trim()],
      );
      if (dupUser) {
        return res.status(409).json({
          success: false,
          message: `Username '${username}' is already taken.`,
        });
      }
    }

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      await conn.query(
        `UPDATE employee_pending_request SET
            first_name = ?,
            mid_name = ?,
            last_name = ?,
            email_id = ?,
            phone_number = ?,
            date_of_birth = ?,
            gender = ?,
            department_id = ?,
            role_id = ?,
            date_of_joining = ?,
            employment_type = ?,
            work_type = ?,
            permanent_address = ?,
            communication_address = ?,
            aadhar_number = ?,
            pan_number = ?,
            passport_number = ?,
            father_name = ?,
            emergency_contact_relation = ?,
            emergency_contact = ?,
            pf_number = ?,
            esic_number = ?,
            years_experience = ?,
            tl_id = ?,
            username = ?,
            admin_approve = 'PENDING',
            reject_reason = NULL,
            updated_at = NOW()
          WHERE request_id = ? AND tenant_id = ?`,
        [
          nullIfEmpty(first_name) || existing.first_name,
          nullIfEmpty(mid_name),
          nullIfEmpty(last_name) || existing.last_name,
          nullIfEmpty(email_id) || existing.email_id,
          nullIfEmpty(phone_number) || existing.phone_number,
          nullIfEmpty(date_of_birth) || existing.date_of_birth,
          nullIfEmpty(gender) || existing.gender,
          nullIfEmpty(department_id) || existing.department_id,
          nullIfEmpty(role_id) || existing.role_id,
          nullIfEmpty(date_of_joining) || existing.date_of_joining,
          nullIfEmpty(employment_type) || existing.employment_type,
          nullIfEmpty(work_type) || existing.work_type,
          nullIfEmpty(permanent_address) || existing.permanent_address,
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
            : existing.years_experience,
          nullIfEmpty(tl_id),
          nullIfEmpty(username) || existing.username,
          request_id,
          tenantId,
        ],
      );

      // ── Replace education records ─────────────────────────────────────
      if (Array.isArray(education) && education.length > 0) {
        await conn.query(
          "DELETE FROM education_pending_request WHERE request_id = ?",
          [request_id],
        );

        const eduValues = education.map((e) => [
          request_id,
          nullIfEmpty(e.education_level),
          nullIfEmpty(e.stream),
          nullIfEmpty(e.score),
          nullIfEmpty(e.year_of_passout),
          nullIfEmpty(e.university),
          nullIfEmpty(e.college_name),
        ]);

        await conn.query(
          `INSERT INTO education_pending_request
            (request_id, education_level, stream, score, year_of_passout, university, college_name)
           VALUES ?`,
          [eduValues],
        );
      }

      await conn.commit();

      res.json({
        success: true,
        message: "Request resubmitted for approval.",
        request_id: parseInt(request_id),
      });
    } catch (err) {
      await conn.rollback();
      console.error("[PUT /admin/resubmit-request]", err);
      res.status(500).json({ success: false, message: "Server error." });
    } finally {
      conn.release();
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/employee-edit-request
// ANY authenticated user can submit an edit request for an existing employee.
// Creates a pending request with request_type = 'UPDATE'.
// Admin / HR approves it before applying changes to employee_master.
// Body: { emp_id, ...fields, edit_reason, education }
// ─────────────────────────────────────────────────────────────────────────────
router.post("/employee-edit-request", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  const {
    emp_id,
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
    status,
    edit_reason,
    education = [],
  } = req.body;

  if (!emp_id) {
    return res
      .status(400)
      .json({ success: false, message: "emp_id is required." });
  }

  if (!edit_reason || !edit_reason.trim()) {
    return res
      .status(400)
      .json({ success: false, message: "edit_reason is required." });
  }

  // ── Verify employee belongs to this tenant ────────────────────────────────
  const [[emp]] = await db.query(
    `SELECT * FROM employee_master WHERE emp_id = ? AND tenant_id = ? LIMIT 1`,
    [emp_id, tenantId],
  );

  if (!emp) {
    return res
      .status(404)
      .json({ success: false, message: "Employee not found." });
  }

  // ── Validate department / role / tl if provided ───────────────────────────
  if (department_id) {
    const [[dept]] = await db.query(
      "SELECT department_id FROM department_master WHERE department_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
      [department_id, tenantId],
    );
    if (!dept) {
      return res.status(400).json({
        success: false,
        message: "Invalid department for this tenant.",
      });
    }
  }

  if (role_id) {
    const [[role]] = await db.query(
      "SELECT role_id FROM role_master WHERE role_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
      [role_id, tenantId],
    );
    if (!role) {
      return res.status(400).json({
        success: false,
        message: "Invalid role for this tenant.",
      });
    }
  }

  if (nullIfEmpty(tl_id)) {
    const [[tl]] = await db.query(
      "SELECT emp_id FROM employee_master WHERE emp_id = ? AND tenant_id = ? AND status = 'Active' LIMIT 1",
      [tl_id, tenantId],
    );
    if (!tl) {
      return res.status(400).json({
        success: false,
        message: "Invalid Team Lead for this tenant.",
      });
    }
  }

  // ── Resolve values: use submitted value or fall back to existing ──────────
  const resolve = (val, fallback) =>
    val !== undefined && val !== null && val !== "" ? val : fallback;

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [result] = await conn.query(
      `INSERT INTO employee_pending_request
        (tenant_id, emp_id,
         first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         department_id, role_id,
         date_of_joining, date_of_relieving,
         employment_type, work_type,
         permanent_address, communication_address,
         aadhar_number, pan_number, passport_number,
         father_name, emergency_contact_relation, emergency_contact,
         pf_number, esic_number, years_experience,
         tl_id, status,
         username, password,
         request_type, admin_approve,
         edit_reason, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'UPDATE', 'PENDING', ?, NOW())`,
      [
        tenantId,
        emp_id,
        resolve(first_name, emp.first_name),
        nullIfEmpty(mid_name) !== null ? mid_name : emp.mid_name,
        resolve(last_name, emp.last_name),
        resolve(email_id, emp.email_id),
        resolve(phone_number, emp.phone_number),
        resolve(date_of_birth, emp.date_of_birth),
        resolve(gender, emp.gender),
        resolve(department_id, emp.department_id),
        resolve(role_id, emp.role_id),
        resolve(date_of_joining, emp.date_of_joining),
        nullIfEmpty(date_of_relieving),
        resolve(employment_type, emp.employment_type),
        resolve(work_type, emp.work_type),
        resolve(permanent_address, emp.permanent_address),
        nullIfEmpty(communication_address),
        nullIfEmpty(aadhar_number),
        nullIfEmpty(pan_number),
        nullIfEmpty(passport_number),
        nullIfEmpty(father_name),
        nullIfEmpty(emergency_contact_relation),
        nullIfEmpty(emergency_contact),
        nullIfEmpty(pf_number),
        nullIfEmpty(esic_number),
        years_experience !== undefined && years_experience !== ""
          ? parseInt(years_experience, 10)
          : emp.years_experience,
        nullIfEmpty(tl_id),
        resolve(status, emp.status),
        // username and password are carried over from the existing login
        emp.username || "",
        emp.password || "",
        edit_reason.trim(),
      ],
    );

    const requestId = result.insertId;

    // ── Insert education records if provided ──────────────────────────────
    if (Array.isArray(education) && education.length > 0) {
      const eduValues = education.map((e) => [
        requestId,
        nullIfEmpty(e.education_level),
        nullIfEmpty(e.stream),
        nullIfEmpty(e.score),
        nullIfEmpty(e.year_of_passout),
        nullIfEmpty(e.university),
        nullIfEmpty(e.college_name),
      ]);

      await conn.query(
        `INSERT INTO education_pending_request
          (request_id, education_level, stream, score, year_of_passout, university, college_name)
         VALUES ?`,
        [eduValues],
      );
    }

    await conn.commit();

    res.status(201).json({
      success: true,
      message: "Edit request submitted. Awaiting admin approval.",
      request_id: requestId,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[POST /employee-edit-request]", err);
    res.status(500).json({ success: false, message: "Server error." });
  } finally {
    conn.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/approve-edit-request/:request_id
// Approves an UPDATE pending request.
// Applies the changes from employee_pending_request into employee_master.
// Admin / HR only.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/admin/approve-edit-request/:request_id",
  requireAuth,
  requireRole(1, 2),
  async (req, res) => {
    const { tenantId } = req.user;
    const { request_id } = req.params;

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      const [[req_row]] = await conn.query(
        `SELECT * FROM employee_pending_request
          WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'PENDING' AND request_type = 'UPDATE'
          LIMIT 1`,
        [request_id, tenantId],
      );

      if (!req_row) {
        await conn.rollback();
        return res.status(404).json({
          success: false,
          message: "Edit request not found or already processed.",
        });
      }

      if (!req_row.emp_id) {
        await conn.rollback();
        return res.status(400).json({
          success: false,
          message: "Edit request has no linked employee ID.",
        });
      }

      // ── Apply changes to employee_master ──────────────────────────────
      await conn.query(
        `UPDATE employee_master SET
            first_name = ?,
            mid_name = ?,
            last_name = ?,
            email_id = ?,
            phone_number = ?,
            date_of_birth = ?,
            gender = ?,
            department_id = ?,
            role_id = ?,
            date_of_joining = ?,
            date_of_relieving = ?,
            employment_type = ?,
            work_type = ?,
            permanent_address = ?,
            communication_address = ?,
            aadhar_number = ?,
            pan_number = ?,
            passport_number = ?,
            father_name = ?,
            emergency_contact_relation = ?,
            emergency_contact = ?,
            pf_number = ?,
            esic_number = ?,
            years_experience = ?,
            tl_id = ?,
            status = ?,
            updated_at = NOW()
          WHERE emp_id = ? AND tenant_id = ?`,
        [
          req_row.first_name,
          req_row.mid_name,
          req_row.last_name,
          req_row.email_id,
          req_row.phone_number,
          req_row.date_of_birth,
          req_row.gender,
          req_row.department_id,
          req_row.role_id,
          req_row.date_of_joining,
          req_row.date_of_relieving,
          req_row.employment_type,
          req_row.work_type,
          req_row.permanent_address,
          req_row.communication_address,
          req_row.aadhar_number,
          req_row.pan_number,
          req_row.passport_number,
          req_row.father_name,
          req_row.emergency_contact_relation,
          req_row.emergency_contact,
          req_row.pf_number,
          req_row.esic_number,
          req_row.years_experience,
          req_row.tl_id,
          req_row.status,
          req_row.emp_id,
          tenantId,
        ],
      );

      // ── Sync role in login_master if changed ──────────────────────────
      await conn.query("UPDATE login_master SET role_id = ? WHERE emp_id = ?", [
        req_row.role_id,
        req_row.emp_id,
      ]);

      // ── Update education: replace all records for this employee ───────
      const [eduRows] = await conn.query(
        "SELECT * FROM education_pending_request WHERE request_id = ?",
        [request_id],
      );

      if (eduRows.length > 0) {
        await conn.query("DELETE FROM education_master WHERE emp_id = ?", [
          req_row.emp_id,
        ]);

        const eduValues = eduRows.map((e) => [
          req_row.emp_id,
          e.education_level,
          e.stream,
          e.score,
          e.year_of_passout,
          e.university,
          e.college_name,
        ]);

        await conn.query(
          `INSERT INTO education_master
            (emp_id, education_level, stream, score, year_of_passout, university, college_name)
           VALUES ?`,
          [eduValues],
        );
      }

      // ── If status changed to Relieved / Inactive, update login ────────
      if (req_row.status !== "Active") {
        await conn.query(
          `UPDATE login_master
              SET status = 'Inactive', session_token = NULL, device_logged_in = 0
            WHERE emp_id = ?`,
          [req_row.emp_id],
        );
      }

      // ── Apply profile photo if pending request has one ────────────────
      if (req_row.profile_photo) {
        await conn.query(
          `UPDATE employee_master
              SET profile_photo = ?, profile_photo_mime = ?
            WHERE emp_id = ?`,
          [req_row.profile_photo, req_row.profile_photo_mime, req_row.emp_id],
        );
      }

      // ── Mark request as APPROVED ──────────────────────────────────────
      await conn.query(
        "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
        [request_id],
      );

      await conn.commit();

      res.json({
        success: true,
        message: "Edit request approved. Employee record updated.",
        emp_id: req_row.emp_id,
      });
    } catch (err) {
      await conn.rollback();
      console.error("[POST /admin/approve-edit-request]", err);
      res.status(500).json({ success: false, message: "Server error." });
    } finally {
      conn.release();
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/requests/:request_id/education
// Returns education records attached to a pending request.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/requests/:request_id/education", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { request_id } = req.params;

  try {
    // Verify request belongs to tenant
    const [[reqRow]] = await db.query(
      "SELECT request_id FROM employee_pending_request WHERE request_id = ? AND tenant_id = ? LIMIT 1",
      [request_id, tenantId],
    );
    if (!reqRow) {
      return res
        .status(404)
        .json({ success: false, message: "Request not found." });
    }

    const [rows] = await db.query(
      "SELECT * FROM education_pending_request WHERE request_id = ?",
      [request_id],
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /requests/:id/education]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/employees/:emp_id/education
// Returns education records for an approved employee.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/employees/:emp_id/education", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { emp_id } = req.params;

  try {
    const [[emp]] = await db.query(
      "SELECT emp_id FROM employee_master WHERE emp_id = ? AND tenant_id = ? LIMIT 1",
      [emp_id, tenantId],
    );
    if (!emp) {
      return res
        .status(404)
        .json({ success: false, message: "Employee not found." });
    }

    const [rows] = await db.query(
      "SELECT * FROM education_master WHERE emp_id = ? ORDER BY edu_id",
      [emp_id],
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /employees/:id/education]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/departments
// Returns active departments for the caller's tenant.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/departments", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  try {
    const [rows] = await db.query(
      `SELECT department_id AS id, department_name AS name, status
         FROM department_master
        WHERE tenant_id = ? AND status = 'Active'
        ORDER BY department_name`,
      [tenantId],
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /departments]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/roles
// Returns active roles for the caller's tenant.
// Optional query param: dept_id — filter roles by department.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/roles", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { dept_id } = req.query;

  const conditions = ["r.tenant_id = ?", "r.status = 'Active'"];
  const params = [tenantId];

  if (dept_id) {
    conditions.push("r.department_id = ?");
    params.push(dept_id);
  }

  const where = conditions.join(" AND ");

  try {
    const [rows] = await db.query(
      `SELECT r.role_id AS id, r.role_name AS name, r.department_id,
              d.department_name, r.status
         FROM role_master r
         LEFT JOIN department_master d ON d.department_id = r.department_id
        WHERE ${where}
        ORDER BY r.role_name`,
      params,
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /roles]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/team-leads
// Returns active employees who can act as Team Leads (role_id = 3)
// within the caller's tenant.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/team-leads", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  try {
    const [rows] = await db.query(
      `SELECT e.emp_id AS id,
              CONCAT(e.first_name, ' ', COALESCE(e.mid_name, ''), ' ', COALESCE(e.last_name, '')) AS name,
              e.department_id, d.department_name
         FROM employee_master e
         LEFT JOIN department_master d ON d.department_id = e.department_id
        WHERE e.tenant_id = ? AND e.status = 'Active'
          AND e.role_id IN (
            SELECT role_id FROM role_master
            WHERE tenant_id = ? AND status = 'Active'
          )
        ORDER BY e.first_name`,
      [tenantId, tenantId],
    );

    // Trim extra spaces from concatenation
    const cleaned = rows.map((r) => ({
      ...r,
      name: r.name.replace(/\s+/g, " ").trim(),
    }));

    res.json({ success: true, data: cleaned });
  } catch (err) {
    console.error("[GET /team-leads]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/all-employees
// Returns all employees for the tenant (for HR / TL / Admin lists).
// Includes both PENDING and APPROVED employees in one list
// (pending from employee_pending_request, approved from employee_master).
// ─────────────────────────────────────────────────────────────────────────────
router.get("/all-employees", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  try {
    // Approved employees from employee_master
    const [approved] = await db.query(
      `SELECT
          e.emp_id, NULL AS request_id,
          e.first_name, e.mid_name, e.last_name,
          e.email_id, e.phone_number,
          e.department_id, d.department_name,
          e.role_id, r.role_name,
          e.tl_id,
          CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS tl_name,
          e.employment_type, e.work_type, e.status,
          'APPROVED' AS admin_approve,
          e.created_at
       FROM employee_master e
       LEFT JOIN department_master d ON d.department_id = e.department_id
       LEFT JOIN role_master        r ON r.role_id        = e.role_id
       LEFT JOIN employee_master    t ON t.emp_id          = e.tl_id
       WHERE e.tenant_id = ?`,
      [tenantId],
    );

    // Pending / rejected NEW requests from employee_pending_request
    const [pendingRows] = await db.query(
      `SELECT
          NULL AS emp_id, r.request_id,
          r.first_name, r.mid_name, r.last_name,
          r.email_id, r.phone_number,
          r.department_id, d.department_name,
          r.role_id, rl.role_name,
          r.tl_id,
          CONCAT(t.first_name, ' ', COALESCE(t.last_name,'')) AS tl_name,
          r.employment_type, r.work_type, r.status,
          r.admin_approve,
          r.created_at
       FROM employee_pending_request r
       LEFT JOIN department_master d  ON d.department_id = r.department_id
       LEFT JOIN role_master        rl ON rl.role_id       = r.role_id
       LEFT JOIN employee_master    t  ON t.emp_id          = r.tl_id
       WHERE r.tenant_id = ?
         AND r.request_type = 'NEW'
         AND r.admin_approve IN ('PENDING', 'REJECTED')`,
      [tenantId],
    );

    // Merge, sort by created_at descending
    const all = [...approved, ...pendingRows].sort(
      (a, b) => new Date(b.created_at) - new Date(a.created_at),
    );

    res.json({ success: true, count: all.length, data: all });
  } catch (err) {
    console.error("[GET /all-employees]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
