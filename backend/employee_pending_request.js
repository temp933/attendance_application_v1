require("dotenv").config();

const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const multer = require("multer");

const db = require("./config/db");
const authMiddleware = require("./middleware/auth");

// ─────────────────────────────────────────────────────────────────────────────
// MULTER
// ─────────────────────────────────────────────────────────────────────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (_, file, cb) => {
    if (file.mimetype.startsWith("image/")) cb(null, true);
    else cb(new Error("Only image files are allowed."));
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  authMiddleware(req, res, () => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized." });
    }
    req.user.loginId = req.user.login_id;
    req.user.tenantId = req.user.tenant_id;
    req.user.roleId = req.user.role_id;
    req.user.empId = req.user.emp_id;
    req.user.companyId = req.user.company_id;
    next();
  });
}

function requireRole(...allowedRoleNames) {
  return (req, res, next) => {
    const roleName = (req.user.role_name || "").toLowerCase().trim();
    if (!allowedRoleNames.includes(roleName)) {
      return res.status(403).json({ success: false, message: "Forbidden." });
    }
    next();
  };
}

function nullIfEmpty(v) {
  return v === undefined || v === null || v === "" ? null : v;
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/pending-request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  const {
    request_type = "NEW",
    emp_id,
    first_name,
    mid_name,
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    designation_id,
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
    username,
    password: rawPassword,
    edit_reason,
    education,
  } = req.body;

  // ── Validation ─────────────────────────────────────────────────────────────
  if (!first_name || !last_name || !email_id || !phone_number) {
    return res.status(400).json({
      success: false,
      message: "first_name, last_name, email_id, phone_number are required.",
    });
  }
  if (request_type === "UPDATE" && !emp_id) {
    return res.status(400).json({
      success: false,
      message: "emp_id is required for UPDATE request.",
    });
  }
  if (request_type === "NEW" && (!username || !rawPassword)) {
    return res.status(400).json({
      success: false,
      message: "username and password are required for NEW request.",
    });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // ── Validate designation ─────────────────────────────────────────────────
    console.log(
      "[pending-request] designation_id:",
      designation_id,
      "role_id:",
      role_id,
      "tenantId:",
      tenantId,
    );
    const [[designation]] = await conn.query(
      `SELECT dm.designation_id, dm.department_id, dm.designation_name,
              dep.department_name
         FROM designation_master dm
         INNER JOIN department_master dep ON dep.department_id = dm.department_id
           AND dep.tenant_id = dm.tenant_id
        WHERE dm.designation_id = ? AND dm.tenant_id = ?
          AND dm.status = 'Active' AND dm.is_deleted = 0
        LIMIT 1`,
      [designation_id, tenantId],
    );
    if (!designation) {
      await conn.rollback();
      return res
        .status(400)
        .json({ success: false, message: "Invalid designation selected." });
    }

    // ── Validate role ────────────────────────────────────────────────────────
    const [[role]] = await conn.query(
      `SELECT role_id FROM role_master
        WHERE role_id = ? AND tenant_id = ?
          AND status = 'Active' AND is_deleted = 0
        LIMIT 1`,
      [role_id, tenantId],
    );
    if (!role) {
      await conn.rollback();
      return res
        .status(400)
        .json({ success: false, message: "Invalid role selected." });
    }

    // ── Hash password (only for NEW) ─────────────────────────────────────────
    const hashedPassword = rawPassword
      ? await bcrypt.hash(rawPassword, 12)
      : null;

    // ── Insert pending request ───────────────────────────────────────────────
    //
    // COLUMN LIST (29 bound params — status and created_at are literals):
    //  1  tenant_id
    //  2  emp_id
    //  3  request_type
    //     admin_approve  ← hardcoded literal 'PENDING'
    //  4  first_name
    //  5  mid_name
    //  6  last_name
    //  7  email_id
    //  8  phone_number
    //  9  date_of_birth
    //  10 gender
    //  11 designation_id
    //  12 role_id
    //  13 date_of_joining
    //  14 date_of_relieving
    //  15 employment_type
    //  16 work_type
    //  17 permanent_address
    //  18 communication_address
    //  19 aadhar_number
    //  20 pan_number
    //  21 passport_number
    //  22 father_name
    //  23 emergency_contact_relation
    //  24 emergency_contact
    //  25 pf_number
    //  26 esic_number
    //  27 years_experience
    //  28 username
    //  29 password
    //  30 edit_reason
    //     status         ← hardcoded literal 'Active'
    //     created_at     ← hardcoded literal NOW()
    //
    const [result] = await conn.query(
      `INSERT INTO employee_pending_request (
         tenant_id, emp_id,
         request_type, admin_approve,
         first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         designation_id, role_id,
         date_of_joining, date_of_relieving,
         employment_type, work_type,
         permanent_address, communication_address,
         aadhar_number, pan_number, passport_number,
         father_name,
         emergency_contact_relation, emergency_contact,
         pf_number, esic_number,
         years_experience,
         username, password,
         edit_reason,
         status, created_at
       ) VALUES (
         ?, ?,
         ?, 'PENDING',
         ?, ?, ?,
         ?, ?, ?, ?,
         ?, ?,
         ?, ?,
         ?, ?,
         ?, ?,
         ?, ?, ?,
         ?,
         ?, ?,
         ?, ?,
         ?,
         ?, ?,
         ?,
         'Active', NOW()
       )`,
      [
        // 1-2
        tenantId,
        nullIfEmpty(emp_id),
        // 3  (admin_approve is a literal)
        request_type,
        // 4-6
        nullIfEmpty(first_name),
        nullIfEmpty(mid_name),
        nullIfEmpty(last_name),
        // 7-10
        nullIfEmpty(email_id),
        nullIfEmpty(phone_number),
        nullIfEmpty(date_of_birth),
        nullIfEmpty(gender),
        // 11-12
        nullIfEmpty(designation_id),
        nullIfEmpty(role_id),
        // 13-14
        nullIfEmpty(date_of_joining),
        nullIfEmpty(date_of_relieving),
        // 15-16
        nullIfEmpty(employment_type),
        nullIfEmpty(work_type),
        // 17-18
        nullIfEmpty(permanent_address),
        nullIfEmpty(communication_address),
        // 19-21
        nullIfEmpty(aadhar_number),
        nullIfEmpty(pan_number),
        nullIfEmpty(passport_number),
        // 22
        nullIfEmpty(father_name),
        // 23-24
        nullIfEmpty(emergency_contact_relation),
        nullIfEmpty(emergency_contact),
        // 25-26
        nullIfEmpty(pf_number),
        nullIfEmpty(esic_number),
        // 27
        years_experience !== undefined ? parseInt(years_experience, 10) : null,
        // 28-29
        nullIfEmpty(username),
        hashedPassword,
        // 30  (status and created_at are literals)
        nullIfEmpty(edit_reason),
      ],
    );

    const requestId = result.insertId;

    // ── Education rows ───────────────────────────────────────────────────────
    if (Array.isArray(education) && education.length > 0) {
      for (const edu of education) {
        await conn.query(
          `INSERT INTO education_pending_request (
             request_id, tenant_id, emp_id,
             education_level, stream, score,
             year_of_passout,
             university, college_name,
             action_type
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'ADD')`,
          [
            requestId,
            tenantId,
            nullIfEmpty(emp_id),
            nullIfEmpty(edu.education_level),
            nullIfEmpty(edu.stream),
            nullIfEmpty(edu.score),
            nullIfEmpty(edu.year_of_passout),
            nullIfEmpty(edu.university),
            nullIfEmpty(edu.college_name),
          ],
        );
      }
    }

    await conn.commit();

    return res.status(201).json({
      success: true,
      message:
        request_type === "NEW"
          ? "Employee request submitted."
          : "Employee update request submitted.",
      request_id: requestId,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[POST /pending-request]", err);
    if (err.code === "ER_DUP_ENTRY") {
      return res
        .status(409)
        .json({ success: false, message: "Duplicate entry." });
    }
    return res.status(500).json({ success: false, message: "Server error." });
  } finally {
    conn.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/pending-request/:id/photo
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/:id/photo",
  requireAuth,
  upload.single("photo"),
  async (req, res) => {
    const { tenantId } = req.user;
    const { id } = req.params;

    if (!req.file) {
      return res
        .status(400)
        .json({ success: false, message: "No image provided." });
    }

    try {
      const [result] = await db.query(
        `UPDATE employee_pending_request
          SET profile_photo = ?, profile_photo_mime = ?
        WHERE request_id = ? AND tenant_id = ?`,
        [req.file.buffer, req.file.mimetype, id, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "Request not found." });
      }

      return res.json({ success: true, message: "Photo uploaded." });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/pending-request/:id/photo
// ─────────────────────────────────────────────────────────────────────────────
router.get("/:id/photo", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { id } = req.params;

  try {
    const [[row]] = await db.query(
      `SELECT profile_photo, profile_photo_mime
         FROM employee_pending_request
        WHERE request_id = ? AND tenant_id = ?
        LIMIT 1`,
      [id, tenantId],
    );

    if (!row || !row.profile_photo) {
      return res
        .status(404)
        .json({ success: false, message: "Photo not found." });
    }

    res.set("Content-Type", row.profile_photo_mime || "image/jpeg");
    res.send(row.profile_photo);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/pending-request
// ─────────────────────────────────────────────────────────────────────────────
router.get("/", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  const roleName = (req.user.role_name || "").toLowerCase().trim();
  const isAdminOrHR = ["admin", "hr"].includes(roleName);
  const { status, request_type } = req.query;

  try {
    const conditions = ["epr.tenant_id = ?"];
    const params = [tenantId];

    if (!isAdminOrHR) {
      conditions.push("epr.emp_id = ?");
      params.push(empId);
    }
    if (status) {
      conditions.push("epr.admin_approve = ?");
      params.push(status);
    }
    if (request_type) {
      conditions.push("epr.request_type = ?");
      params.push(request_type);
    }

    const where = conditions.join(" AND ");

    const [rows] = await db.query(
      `SELECT epr.*,
              dm.designation_name,
              dep.department_name,
              r.role_name
         FROM employee_pending_request epr
         LEFT JOIN designation_master dm  ON dm.designation_id = epr.designation_id
         LEFT JOIN department_master  dep ON dep.department_id = dm.department_id
         LEFT JOIN role_master        r   ON r.role_id         = epr.role_id
        WHERE ${where}
        ORDER BY epr.created_at DESC`,
      params,
    );

    return res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/pending-request/:id
// ─────────────────────────────────────────────────────────────────────────────
router.get("/:id", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const { id } = req.params;

  try {
    const [[row]] = await db.query(
      `SELECT epr.*,
              dm.designation_name,
              dep.department_name,
              r.role_name
         FROM employee_pending_request epr
         LEFT JOIN designation_master dm  ON dm.designation_id = epr.designation_id
         LEFT JOIN department_master  dep ON dep.department_id = dm.department_id
         LEFT JOIN role_master        r   ON r.role_id         = epr.role_id
        WHERE epr.request_id = ? AND epr.tenant_id = ?
        LIMIT 1`,
      [id, tenantId],
    );

    if (!row) {
      return res
        .status(404)
        .json({ success: false, message: "Request not found." });
    }

    const [eduRows] = await db.query(
      `SELECT * FROM education_pending_request WHERE request_id = ?`,
      [id],
    );

    row.education = eduRows;

    return res.json({ success: true, data: row });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
