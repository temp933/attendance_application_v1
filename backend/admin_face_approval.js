require("dotenv").config();
const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const db = require("./config/db");
const authMiddleware = require("./middleware/auth");
const FormData = require("form-data");
const fetch = require("node-fetch");

const FACE_SERVICE_URL =
  process.env.FACE_SERVICE_URL || "http://localhost:8000";

// ─────────────────────────────────────────────────────────────────────────────
// Helper: call Python face service to get embedding from image bytes
// ─────────────────────────────────────────────────────────────────────────────
async function generateFaceEmbedding(imageBuffer, mimeType = "image/jpeg") {
  try {
    const ext = mimeType.split("/")[1] || "jpg";
    const form = new FormData();
    form.append("file", imageBuffer, {
      filename: `photo.${ext}`,
      contentType: mimeType,
    });

    const res = await fetch(`${FACE_SERVICE_URL}/embedding`, {
      method: "POST",
      body: form,
      headers: form.getHeaders(),
    });

    if (!res.ok) return null;

    const data = await res.json();
    if (data.success && Array.isArray(data.embedding)) {
      return data.embedding;
    }
    return null;
  } catch (err) {
    console.error("[generateFaceEmbedding] Face service error:", err.message);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth middleware
// ─────────────────────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  authMiddleware(req, res, () => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized." });
    }
    req.user.loginId = req.user.login_id;
    req.user.tenantId = req.user.tenant_id ?? req.headers["x-tenant-id"];
    req.user.roleId = parseInt(req.user.role_id, 10);
    req.user.empId = req.user.emp_id;
    req.user.companyId = req.user.tenant_id ?? req.headers["x-tenant-id"];
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

// ─────────────────────────────────────────────────────────────────────────────
// Helper: validate that a value looks like yyyy-MM-dd (or is null/undefined/"")
// ─────────────────────────────────────────────────────────────────────────────
function assertDateString(value, fieldName) {
  if (value === null || value === undefined || value === "") return;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(
      `Field '${fieldName}' must be a plain 'yyyy-MM-dd' string, got: ${JSON.stringify(value)}`,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: coerce an empty string date to null so MySQL doesn't reject it
// ─────────────────────────────────────────────────────────────────────────────
function nullableDate(value) {
  return value === "" || value === undefined ? null : value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: apply education staging rows → education_details
// ─────────────────────────────────────────────────────────────────────────────
async function applyEducationChanges(conn, request_id, empId) {
  const [eduRows] = await conn.query(
    `SELECT * FROM education_pending_request
      WHERE request_id = ?
      ORDER BY edu_req_id`,
    [request_id],
  );

  if (eduRows.length === 0) {
    console.log(
      `[applyEducationChanges] No edu rows for request_id=${request_id}`,
    );
    return false;
  }

  console.log(
    `[applyEducationChanges] Processing ${eduRows.length} edu rows for request_id=${request_id}`,
  );
  for (const edu of eduRows) {
    console.log(
      `[applyEducationChanges] edu_req_id=${edu.edu_req_id} action=${edu.action_type} is_changed=${edu.is_changed}`,
    );
    if (edu.is_changed === 0 && edu.action_type === "UPDATE") continue;

    switch (edu.action_type) {
      case "ADD":
        await conn.query(
          `INSERT INTO education_details
              (emp_id, education_level, stream, score,
               year_of_passout, university, college_name)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            empId,
            edu.education_level,
            edu.stream,
            edu.score,
            edu.year_of_passout,
            edu.university,
            edu.college_name,
          ],
        );
        break;

      case "UPDATE":
        if (!edu.original_edu_id)
          throw new Error(
            `edu_req_id ${edu.edu_req_id} has action_type=UPDATE but no original_edu_id`,
          );
        await conn.query(
          `UPDATE education_details
              SET education_level = ?, stream = ?, score = ?,
                  year_of_passout = ?, university = ?, college_name = ?
            WHERE edu_id = ? AND emp_id = ?`,
          [
            edu.education_level,
            edu.stream,
            edu.score,
            edu.year_of_passout,
            edu.university,
            edu.college_name,
            edu.original_edu_id,
            empId,
          ],
        );
        break;

      case "DELETE":
        if (!edu.original_edu_id)
          throw new Error(
            `edu_req_id ${edu.edu_req_id} has action_type=DELETE but no original_edu_id`,
          );
        await conn.query(
          `DELETE FROM education_details WHERE edu_id = ? AND emp_id = ?`,
          [edu.original_edu_id, empId],
        );
        break;

      default:
        console.warn(
          `Unknown action_type '${edu.action_type}' on edu_req_id ${edu.edu_req_id} — skipped`,
        );
    }
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/face/pending-requests
// ─────────────────────────────────────────────────────────────────────────────
router.get(
  "/face/pending-requests",
  requireAuth,
  requireRole("admin", "hr"),
  async (req, res) => {
    const { tenantId } = req.user;
    try {
      // NOTE: employee_pending_request has NO department_id column per schema.
      // Designation is carried via designation_id on both tables.
      // department_id lives only on employee_master and designation_master.
      const [rows] = await db.query(
        `SELECT
            p.request_id,
            p.emp_id,
            p.request_type,
            p.admin_approve,
            p.edit_reason,
            p.reject_reason,
            p.created_at,
            p.updated_at,
            COALESCE(p.first_name,                 e.first_name)                 AS first_name,
            COALESCE(p.mid_name,                   e.mid_name)                   AS mid_name,
            COALESCE(p.last_name,                  e.last_name)                  AS last_name,
            COALESCE(p.email_id,                   e.email_id)                   AS email_id,
            COALESCE(p.phone_number,               e.phone_number)               AS phone_number,
            COALESCE(p.date_of_birth,              e.date_of_birth)              AS date_of_birth,
            COALESCE(p.gender,                     e.gender)                     AS gender,
            COALESCE(p.father_name,                e.father_name)                AS father_name,
            COALESCE(p.emergency_contact,          e.emergency_contact)          AS emergency_contact,
            COALESCE(p.emergency_contact_relation, e.emergency_contact_relation) AS emergency_contact_relation,
            COALESCE(p.designation_id,             e.designation_id)             AS designation_id,
            COALESCE(p.role_id,                    e.role_id)                    AS role_id,
            COALESCE(p.date_of_joining,            e.date_of_joining)            AS date_of_joining,
            COALESCE(p.date_of_relieving,          e.date_of_relieving)          AS date_of_relieving,
            COALESCE(p.employment_type,            e.employment_type)            AS employment_type,
            COALESCE(p.work_type,                  e.work_type)                  AS work_type,
            COALESCE(p.years_experience,           e.years_experience)           AS years_experience,
            COALESCE(p.permanent_address,          e.permanent_address)          AS permanent_address,
            COALESCE(p.communication_address,      e.communication_address)      AS communication_address,
            COALESCE(p.aadhar_number,              e.aadhar_number)              AS aadhar_number,
            COALESCE(p.pan_number,                 e.pan_number)                 AS pan_number,
            COALESCE(p.passport_number,            e.passport_number)            AS passport_number,
            COALESCE(p.pf_number,                  e.pf_number)                  AS pf_number,
            COALESCE(p.esic_number,                e.esic_number)                AS esic_number,
            p.username,
            -- Resolve department via designation (pending designation takes priority)
            dept.department_id,
            dept.department_name,
            r.role_name,
            desig.designation_name
         FROM employee_pending_request p
         LEFT JOIN employee_master      e     ON e.emp_id        = p.emp_id
                                             AND e.tenant_id     = p.tenant_id
         -- Join designation using the resolved designation_id
         LEFT JOIN designation_master   desig ON desig.designation_id
                                                   = COALESCE(p.designation_id, e.designation_id)
                                             AND desig.tenant_id = p.tenant_id
         -- department comes from designation
         LEFT JOIN department_master    dept  ON dept.department_id = desig.department_id
                                             AND dept.tenant_id    = p.tenant_id
         LEFT JOIN role_master          r     ON r.role_id
                                                   = COALESCE(p.role_id, e.role_id)
                                             AND r.tenant_id     = p.tenant_id
         WHERE p.admin_approve = 'PENDING'
           AND p.tenant_id    = ?
         ORDER BY p.created_at DESC`,
        [tenantId],
      );

      for (const row of rows) {
        // ── 1. Pending education rows ──────────────────────────────────────
        const [eduRows] = await db.query(
          `SELECT education_level, stream, score, year_of_passout, university, college_name
           FROM education_pending_request
           WHERE request_id = ?
           ORDER BY education_level`,
          [row.request_id],
        );

        if (
          eduRows.length === 0 &&
          row.emp_id &&
          row.request_type === "UPDATE"
        ) {
          const [liveEdu] = await db.query(
            `SELECT education_level, stream, score, year_of_passout, university, college_name
             FROM education_details
             WHERE emp_id = ?
             ORDER BY education_level`,
            [row.emp_id],
          );
          row.education_list = liveEdu;
        } else {
          row.education_list = eduRows;
        }

        // ── 2. Current master data for old-vs-new diff (UPDATE only) ──────
        if (row.request_type === "UPDATE" && row.emp_id) {
          const [[current]] = await db.query(
            `SELECT
               e.first_name, e.mid_name, e.last_name,
               e.email_id, e.phone_number,
               e.date_of_birth, e.gender, e.father_name,
               e.emergency_contact, e.emergency_contact_relation,
               e.designation_id, e.role_id,
               e.date_of_joining, e.date_of_relieving,
               e.employment_type, e.work_type, e.years_experience,
               e.permanent_address, e.communication_address,
               e.aadhar_number, e.pan_number, e.passport_number,
               e.pf_number, e.esic_number,
               dept.department_id,
               dept.department_name,
               desig.designation_name,
               r.role_name
             FROM employee_master e
             LEFT JOIN designation_master desig
               ON desig.designation_id = e.designation_id AND desig.tenant_id = e.tenant_id
             LEFT JOIN department_master dept
               ON dept.department_id = desig.department_id AND dept.tenant_id = e.tenant_id
             LEFT JOIN role_master r
               ON r.role_id = e.role_id AND r.tenant_id = e.tenant_id
             WHERE e.emp_id = ? AND e.tenant_id = ?`,
            [row.emp_id, tenantId],
          );

          if (current) {
            const [currentEdu] = await db.query(
              `SELECT education_level, stream, score, year_of_passout, university, college_name
               FROM education_details
               WHERE emp_id = ?
               ORDER BY education_level`,
              [row.emp_id],
            );
            current.education_list = currentEdu;
          }

          row.current_data = current || null;
        } else {
          row.current_data = null;
        }
      } // ── end for loop ───────────────────────────────────────────────────

      res.json({ success: true, count: rows.length, data: rows });
    } catch (err) {
      console.error("[GET /admin/face/pending-requests]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Helper: auto-reject and return 409
// ─────────────────────────────────────────────────────────────────────────────
async function autoReject(conn, request_id, reason, errorMsg) {
  await conn.query(
    `UPDATE employee_pending_request
        SET admin_approve = 'REJECTED', reject_reason = ?
      WHERE request_id = ?`,
    [reason, request_id],
  );
  await conn.commit();
  return { status: 409, body: { success: false, error: errorMsg } };
}

router.get("/face/test-embedding", async (req, res) => {
  try {
    const testRes = await fetch(`${FACE_SERVICE_URL}/docs`);
    res.json({
      reachable: testRes.ok,
      status: testRes.status,
      url: FACE_SERVICE_URL,
    });
  } catch (err) {
    res.json({ reachable: false, error: err.message, url: FACE_SERVICE_URL });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/face/approve-request
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/face/approve-request",
  requireAuth,
  requireRole("admin", "hr"),
  async (req, res) => {
    const { tenantId } = req.user;
    const { request_id } = req.body;

    if (!request_id) {
      return res
        .status(400)
        .json({ success: false, message: "request_id is required." });
    }

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      const [[pending]] = await conn.query(
        `SELECT * FROM employee_pending_request
          WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'PENDING'`,
        [request_id, tenantId],
      );

      if (!pending) {
        await conn.rollback();
        return res
          .status(404)
          .json({ success: false, message: "Pending request not found." });
      }

      // Validate date fields; also coerce empty strings to null
      assertDateString(pending.date_of_birth, "date_of_birth");
      assertDateString(pending.date_of_joining, "date_of_joining");
      assertDateString(pending.date_of_relieving, "date_of_relieving");

      const safeRelieving = nullableDate(pending.date_of_relieving);

      // ── NEW EMPLOYEE ────────────────────────────────────────────────────────
      if (pending.request_type === "NEW") {
        const [[dupEmail]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE email_id = ? AND tenant_id = ? LIMIT 1",
          [pending.email_id, tenantId],
        );
        if (dupEmail) {
          const r = await autoReject(
            conn,
            request_id,
            "Duplicate email address.",
            `Email '${pending.email_id}' is already registered.`,
          );
          return res.status(r.status).json(r.body);
        }

        const [[dupPhone]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE phone_number = ? AND tenant_id = ? LIMIT 1",
          [pending.phone_number, tenantId],
        );
        if (dupPhone) {
          const r = await autoReject(
            conn,
            request_id,
            "Duplicate phone number.",
            `Phone '${pending.phone_number}' is already registered.`,
          );
          return res.status(r.status).json(r.body);
        }

        const [[dupUser]] = await conn.query(
          "SELECT login_id FROM login_master WHERE username = ? AND tenant_id = ? LIMIT 1",
          [pending.username, tenantId],
        );
        if (dupUser) {
          const r = await autoReject(
            conn,
            request_id,
            "Duplicate username.",
            `Username '${pending.username}' is already taken.`,
          );
          return res.status(r.status).json(r.body);
        }

        if (pending.aadhar_number) {
          const [[dupAadhar]] = await conn.query(
            "SELECT emp_id FROM employee_master WHERE aadhar_number = ? AND tenant_id = ? LIMIT 1",
            [pending.aadhar_number, tenantId],
          );
          if (dupAadhar) {
            const r = await autoReject(
              conn,
              request_id,
              "Duplicate Aadhar number.",
              `Aadhar '${pending.aadhar_number}' is already registered.`,
            );
            return res.status(r.status).json(r.body);
          }
        }

        if (pending.pan_number) {
          const [[dupPan]] = await conn.query(
            "SELECT emp_id FROM employee_master WHERE pan_number = ? AND tenant_id = ? LIMIT 1",
            [pending.pan_number, tenantId],
          );
          if (dupPan) {
            const r = await autoReject(
              conn,
              request_id,
              "Duplicate PAN number.",
              `PAN '${pending.pan_number}' is already registered.`,
            );
            return res.status(r.status).json(r.body);
          }
        }

        const [[dupPending]] = await conn.query(
          `SELECT request_id FROM employee_pending_request
            WHERE email_id = ? AND tenant_id = ? AND admin_approve = 'PENDING'
              AND request_id != ? LIMIT 1`,
          [pending.email_id, tenantId, request_id],
        );
        if (dupPending) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            error: `Another pending request already exists for email '${pending.email_id}'.`,
          });
        }

        // employee_master has no department_id column directly;
        // department is inferred via designation_id → designation_master.
        const [[{ empCount }]] = await conn.query(
          `SELECT COUNT(*) AS empCount FROM employee_master WHERE tenant_id = ?`,
          [tenantId],
        );
        const employeeCode = `EMP${String(empCount + 1).padStart(4, "0")}`;

        const [empResult] = await conn.query(
          `INSERT INTO employee_master
              (tenant_id, employee_code, first_name, mid_name, last_name,
               email_id, phone_number, date_of_birth, gender,
               designation_id, role_id,
               date_of_joining, date_of_relieving,
               employment_type, work_type,
               permanent_address, communication_address,
               aadhar_number, pan_number, passport_number,
               father_name, emergency_contact_relation, emergency_contact,
               pf_number, esic_number, years_experience,reporting_to_employee_id,
               profile_photo, profile_photo_mime,
               status, created_at)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'Active',NOW())`,
          [
            tenantId,
            employeeCode,
            pending.first_name,
            pending.mid_name,
            pending.last_name,
            pending.email_id,
            pending.phone_number,
            pending.date_of_birth,
            pending.gender,
            pending.designation_id || null,
            pending.role_id,
            pending.date_of_joining,
            safeRelieving,
            pending.employment_type,
            pending.work_type,
            pending.permanent_address,
            pending.communication_address,
            pending.aadhar_number || null,
            pending.pan_number || null,
            pending.passport_number || null,
            pending.father_name || null,
            pending.emergency_contact_relation || null,
            pending.emergency_contact || null,
            pending.pf_number || null,
            pending.esic_number || null,
            pending.years_experience ?? null,
            pending.reporting_to_employee_id || null,
            pending.profile_photo || null,
            pending.profile_photo_mime || null,
          ],
        );

        const newEmpId = empResult.insertId;

        await conn.query(
          `INSERT INTO login_master
              (tenant_id, emp_id, username, password,
               role_id, is_first_login, status, created_at)
             VALUES (?, ?, ?, ?, ?, 1, 'Active', NOW())`,
          [
            tenantId,
            newEmpId,
            pending.username,
            pending.password,
            pending.role_id,
          ],
        );

        await applyEducationChanges(conn, request_id, newEmpId);

        await conn.query(
          "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
          [request_id],
        );

        await conn.commit();

        // ── Generate & store face embedding (after commit — non-fatal) ──
        let faceEnrolled = false;
        if (pending.profile_photo) {
          const mimeType = pending.profile_photo_mime || "image/jpeg";
          const imageBuffer = Buffer.isBuffer(pending.profile_photo)
            ? pending.profile_photo
            : Buffer.from(pending.profile_photo);

          const embedding = await generateFaceEmbedding(imageBuffer, mimeType);

          if (embedding) {
            try {
              await db.query(
                `UPDATE employee_master
                    SET face_embedding     = ?,
                        has_face_embedding = 1,
                        face_enrolled_at   = NOW()
                  WHERE emp_id = ?`,
                [JSON.stringify(embedding), newEmpId],
              );
              faceEnrolled = true;
              console.log(
                `[approve-request] Face embedding stored for emp_id=${newEmpId}`,
              );
            } catch (dbErr) {
              console.error(
                "[approve-request] Failed to save face embedding:",
                dbErr.message,
              );
            }
          } else {
            console.warn(
              `[approve-request] No face detected in profile photo for emp_id=${newEmpId}. Skipping embedding.`,
            );
          }
        }

        return res.json({
          success: true,
          message: "Employee created and approved successfully.",
          emp_id: newEmpId,
          face_enrolled: faceEnrolled,
        });
      }

      // ── UPDATE EXISTING EMPLOYEE ────────────────────────────────────────────
      const empId = pending.emp_id;
      if (!empId) {
        await conn.rollback();
        return res.status(400).json({
          success: false,
          message: "emp_id missing for UPDATE request.",
        });
      }

      if (pending.email_id) {
        const [[dupEmail]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE email_id = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.email_id, tenantId, empId],
        );
        if (dupEmail) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `Email '${pending.email_id}' is already in use by another employee.`,
          });
        }
      }

      if (pending.phone_number) {
        const [[dupPhone]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE phone_number = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.phone_number, tenantId, empId],
        );
        if (dupPhone) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `Phone '${pending.phone_number}' is already in use by another employee.`,
          });
        }
      }

      if (pending.aadhar_number) {
        const [[dupAadhar]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE aadhar_number = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.aadhar_number, tenantId, empId],
        );
        if (dupAadhar) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `Aadhar '${pending.aadhar_number}' is already in use by another employee.`,
          });
        }
      }

      if (pending.pan_number) {
        const [[dupPan]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE pan_number = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.pan_number, tenantId, empId],
        );
        if (dupPan) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `PAN '${pending.pan_number}' is already in use by another employee.`,
          });
        }
      }

      // Build dynamic SET clause — only fields that are actually present in the
      // pending row AND exist as columns on employee_master.
      // NOTE: status is intentionally excluded here; use a dedicated
      //       status-change flow if you need that.
      const updatable = [
        ["first_name", pending.first_name],
        ["mid_name", pending.mid_name],
        ["last_name", pending.last_name],
        ["email_id", pending.email_id],
        ["phone_number", pending.phone_number],
        ["date_of_birth", pending.date_of_birth],
        ["gender", pending.gender],
        ["designation_id", pending.designation_id],
        ["role_id", pending.role_id],
        ["date_of_joining", pending.date_of_joining],
        ["date_of_relieving", safeRelieving],
        ["employment_type", pending.employment_type],
        ["work_type", pending.work_type],
        ["permanent_address", pending.permanent_address],
        ["communication_address", pending.communication_address],
        ["aadhar_number", pending.aadhar_number],
        ["pan_number", pending.pan_number],
        ["passport_number", pending.passport_number],
        ["father_name", pending.father_name],
        ["emergency_contact_relation", pending.emergency_contact_relation],
        ["emergency_contact", pending.emergency_contact],
        ["pf_number", pending.pf_number],
        ["esic_number", pending.esic_number],
        ["years_experience", pending.years_experience],
        ["reporting_to_employee_id", pending.reporting_to_employee_id],
        // status changes require a dedicated, audited flow — excluded here
      ].filter(([, v]) => v !== null && v !== undefined);

      if (pending.profile_photo) {
        updatable.push(["profile_photo", pending.profile_photo]);
        updatable.push(["profile_photo_mime", pending.profile_photo_mime]);
      }

      if (updatable.length > 0) {
        const setClauses = updatable.map(([f]) => `${f} = ?`).join(", ");
        const values = updatable.map(([, v]) => v);
        await conn.query(
          `UPDATE employee_master SET ${setClauses} WHERE emp_id = ? AND tenant_id = ?`,
          [...values, empId, tenantId],
        );

        if (pending.role_id) {
          await conn.query(
            "UPDATE login_master SET role_id = ? WHERE emp_id = ? AND tenant_id = ?",
            [pending.role_id, empId, tenantId],
          );
        }
      }

      await applyEducationChanges(conn, request_id, empId);

      await conn.query(
        "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
        [request_id],
      );

      await conn.commit();

      // ── Re-generate face embedding if profile photo was updated (after commit) ──
      let faceEnrolled = false;
      if (pending.profile_photo) {
        const mimeType = pending.profile_photo_mime || "image/jpeg";
        const imageBuffer = Buffer.isBuffer(pending.profile_photo)
          ? pending.profile_photo
          : Buffer.from(pending.profile_photo);

        const embedding = await generateFaceEmbedding(imageBuffer, mimeType);

        if (embedding) {
          try {
            await db.query(
              `UPDATE employee_master
                  SET face_embedding     = ?,
                      has_face_embedding = 1,
                      face_enrolled_at   = NOW()
                WHERE emp_id = ?`,
              [JSON.stringify(embedding), empId],
            );
            faceEnrolled = true;
            console.log(
              `[approve-request] Face embedding updated for emp_id=${empId}`,
            );
          } catch (dbErr) {
            console.error(
              "[approve-request] Failed to save face embedding:",
              dbErr.message,
            );
          }
        } else {
          console.warn(
            `[approve-request] No face detected in updated profile photo for emp_id=${empId}. Embedding not updated.`,
          );
        }
      }

      return res.json({
        success: true,
        message: "Employee updated and approved successfully.",
        emp_id: empId,
        face_enrolled: faceEnrolled,
      });
    } catch (err) {
      await conn.rollback();
      console.error("[POST /admin/face/approve-request]", err);
      res.status(500).json({ success: false, message: "Server error." });
    } finally {
      conn.release();
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/face/reject-request
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/face/reject-request",
  requireAuth,
  requireRole("admin", "hr"),
  async (req, res) => {
    const { tenantId } = req.user;
    const { request_id, reject_reason } = req.body;

    if (!request_id || !reject_reason) {
      return res.status(400).json({
        success: false,
        message: "request_id and reject_reason are required.",
      });
    }

    try {
      const [result] = await db.query(
        `UPDATE employee_pending_request
            SET admin_approve = 'REJECTED', reject_reason = ?
          WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'PENDING'`,
        [reject_reason, request_id, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "Pending request not found." });
      }

      res.json({ success: true, message: "Request rejected." });
    } catch (err) {
      console.error("[POST /admin/face/reject-request]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/face/pending-request/:id/photo
// ─────────────────────────────────────────────────────────────────────────────
router.get("/face/pending-request/:id/photo", requireAuth, async (req, res) => {
  const { id } = req.params;
  try {
    const [[row]] = await db.query(
      "SELECT profile_photo, profile_photo_mime FROM employee_pending_request WHERE request_id = ?",
      [id],
    );
    if (!row || !row.profile_photo) return res.status(404).end();
    res.set("Content-Type", row.profile_photo_mime || "image/jpeg");
    res.send(row.profile_photo);
  } catch (err) {
    res.status(500).end();
  }
});

module.exports = router;
