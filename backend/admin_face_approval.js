require("dotenv").config();
const express = require("express");
const router = express.Router();
const db = require("./config/db");
const authMiddleware = require("./middleware/auth");
const FormData = require("form-data");
const fetch = require("node-fetch");

const FACE_SERVICE_URL =
  process.env.FACE_SERVICE_URL || "http://192.168.29.103:8000";

// ─────────────────────────────────────────────────────────────────────────────
// Helper: call Python face service to get embedding from image bytes
// Returns { embedding: [...] } on success
// Returns { error: "reason" } on failure
// ─────────────────────────────────────────────────────────────────────────────
async function generateFaceEmbedding(imageBuffer, mimeType = "image/jpeg") {
  try {
    // ✅ Fix: don't double-wrap an existing Buffer
    const buf = Buffer.isBuffer(imageBuffer)
      ? imageBuffer
      : Buffer.from(imageBuffer);

    const ext = mimeType.split("/")[1] || "jpg";
    const form = new FormData();
    form.append("file", buf, {
      filename: `photo.${ext}`,
      contentType: mimeType,
    });

    const res = await fetch(`${FACE_SERVICE_URL}/embedding`, {
      method: "POST",
      body: form,
      headers: form.getHeaders(),
      // ✅ Add timeout — don't hang forever if Python service is slow
      timeout: 15000,
    });

    const data = await res.json();

    if (!res.ok) {
      // Python returned 400 — likely no face detected
      return { error: data.error || "Face service returned error" };
    }

    if (data.success && Array.isArray(data.embedding)) {
      return { embedding: data.embedding };
    }

    return { error: "Invalid response from face service" };
  } catch (err) {
    // Network error / timeout / service down
    console.error("[generateFaceEmbedding] Face service error:", err.message);
    return { error: `Face service unreachable: ${err.message}` };
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
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
function assertDateString(value, fieldName) {
  if (value === null || value === undefined || value === "") return;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(
      `Field '${fieldName}' must be a plain 'yyyy-MM-dd' string, got: ${JSON.stringify(value)}`,
    );
  }
}

function nullableDate(value) {
  return value === "" || value === undefined ? null : value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: apply education staging rows → education_details
// ─────────────────────────────────────────────────────────────────────────────
async function applyEducationChanges(conn, request_id, empId, tenantId) {
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

  for (const edu of eduRows) {
    if (edu.is_changed === 0 && edu.action_type === "UPDATE") continue;

    switch (edu.action_type) {
      case "ADD":
        await conn.query(
          `INSERT INTO education_details
             (tenant_id, emp_id, education_level, stream, score,
              year_of_passout, university, college_name)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            tenantId,
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
            `edu_req_id ${edu.edu_req_id} UPDATE has no original_edu_id`,
          );
        await conn.query(
          `UPDATE education_details
              SET tenant_id = ?, education_level = ?, stream = ?, score = ?,
                  year_of_passout = ?, university = ?, college_name = ?
            WHERE edu_id = ? AND emp_id = ?`,
          [
            tenantId,
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
            `edu_req_id ${edu.edu_req_id} DELETE has no original_edu_id`,
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
// Helper: enroll face embedding after commit (non-fatal)
// ✅ Unified helper — used by both NEW and UPDATE flows
// ─────────────────────────────────────────────────────────────────────────────
async function enrollFaceEmbedding(empId, profilePhoto, mimeType) {
  if (!profilePhoto) {
    return { enrolled: false, warning: "No profile photo provided." };
  }

  const result = await generateFaceEmbedding(profilePhoto, mimeType);

  if (result.error) {
    console.warn(`[enrollFace] emp_id=${empId} — ${result.error}`);
    return { enrolled: false, warning: result.error };
  }

  try {
    await db.query(
      `UPDATE employee_master
          SET face_embedding     = ?,
              has_face_embedding = 1,
              face_enrolled_at   = NOW()
        WHERE emp_id = ?`,
      [JSON.stringify(result.embedding), empId],
    );
    console.log(`[enrollFace] Embedding stored for emp_id=${empId}`);
    return { enrolled: true, warning: null };
  } catch (dbErr) {
    console.error(
      `[enrollFace] DB save failed for emp_id=${empId}:`,
      dbErr.message,
    );
    return { enrolled: false, warning: `DB error: ${dbErr.message}` };
  }
}

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
            dept.department_id,
            dept.department_name,
            r.role_name,
            desig.designation_name,
            e.has_face_embedding,
            COALESCE(p.reporting_to_employee_id, e.reporting_to_employee_id) AS reporting_to_employee_id,
            CONCAT_WS(' ', rep.first_name, rep.last_name)                    AS reporting_to_name
         FROM employee_pending_request p
         LEFT JOIN employee_master      e     ON e.emp_id    = p.emp_id AND e.tenant_id = p.tenant_id
         LEFT JOIN designation_master   desig ON desig.designation_id = COALESCE(p.designation_id, e.designation_id)
                                             AND desig.tenant_id = p.tenant_id
         LEFT JOIN department_master    dept  ON dept.department_id = desig.department_id
                                             AND dept.tenant_id = p.tenant_id
          LEFT JOIN role_master          r     ON r.role_id = COALESCE(p.role_id, e.role_id)
                                             AND r.tenant_id = p.tenant_id
         LEFT JOIN employee_master      rep   ON rep.emp_id = COALESCE(p.reporting_to_employee_id, e.reporting_to_employee_id)
                                             AND rep.tenant_id = p.tenant_id
         WHERE p.admin_approve = 'PENDING'
           AND p.tenant_id    = ?
         ORDER BY p.created_at DESC`,
        [tenantId],
      );

      for (const row of rows) {
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
             FROM education_details WHERE emp_id = ? ORDER BY education_level`,
            [row.emp_id],
          );
          row.education_list = liveEdu;
        } else {
          row.education_list = eduRows;
        }

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
               e.has_face_embedding,
               dept.department_id, dept.department_name,
                desig.designation_name, r.role_name,
               e.reporting_to_employee_id,
               CONCAT_WS(' ', rep.first_name, rep.last_name) AS reporting_to_name
             FROM employee_master e
             LEFT JOIN designation_master desig ON desig.designation_id = e.designation_id AND desig.tenant_id = e.tenant_id
             LEFT JOIN department_master dept   ON dept.department_id = desig.department_id AND dept.tenant_id = e.tenant_id
             LEFT JOIN role_master r            ON r.role_id = e.role_id AND r.tenant_id = e.tenant_id
             LEFT JOIN employee_master rep      ON rep.emp_id = e.reporting_to_employee_id AND rep.tenant_id = e.tenant_id
             WHERE e.emp_id = ? AND e.tenant_id = ?`,
            [row.emp_id, tenantId],
          );

          if (current) {
            const [currentEdu] = await db.query(
              `SELECT education_level, stream, score, year_of_passout, university, college_name
               FROM education_details WHERE emp_id = ? ORDER BY education_level`,
              [row.emp_id],
            );
            current.education_list = currentEdu;
          }
          row.current_data = current || null;
        } else {
          row.current_data = null;
        }
      }

      res.json({ success: true, count: rows.length, data: rows });
    } catch (err) {
      console.error("[GET /admin/face/pending-requests]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/face/test-embedding
// ─────────────────────────────────────────────────────────────────────────────
router.get("/face/test-embedding", async (req, res) => {
  try {
    const testRes = await fetch(`${FACE_SERVICE_URL}/health`);
    const data = await testRes.json();
    res.json({
      reachable: testRes.ok,
      status: testRes.status,
      url: FACE_SERVICE_URL,
      ...data,
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

      assertDateString(pending.date_of_birth, "date_of_birth");
      assertDateString(pending.date_of_joining, "date_of_joining");
      assertDateString(pending.date_of_relieving, "date_of_relieving");
      const safeRelieving = nullableDate(pending.date_of_relieving);

      // ══════════════════════════════════════════════════════════════════════
      // NEW EMPLOYEE
      // ══════════════════════════════════════════════════════════════════════
      if (pending.request_type === "NEW") {
        // ── Duplicate checks ───────────────────────────────────────────────
        const [[dupEmail]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE email_id = ? AND tenant_id = ? LIMIT 1",
          [pending.email_id, tenantId],
        );
        if (dupEmail)
          return res
            .status(409)
            .json(
              (
                await autoReject(
                  conn,
                  request_id,
                  "Duplicate email.",
                  `Email '${pending.email_id}' already registered.`,
                )
              ).body,
            );

        const [[dupPhone]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE phone_number = ? AND tenant_id = ? LIMIT 1",
          [pending.phone_number, tenantId],
        );
        if (dupPhone)
          return res
            .status(409)
            .json(
              (
                await autoReject(
                  conn,
                  request_id,
                  "Duplicate phone.",
                  `Phone '${pending.phone_number}' already registered.`,
                )
              ).body,
            );

        const [[dupUser]] = await conn.query(
          "SELECT login_id FROM login_master WHERE username = ? AND tenant_id = ? LIMIT 1",
          [pending.username, tenantId],
        );
        if (dupUser)
          return res
            .status(409)
            .json(
              (
                await autoReject(
                  conn,
                  request_id,
                  "Duplicate username.",
                  `Username '${pending.username}' already taken.`,
                )
              ).body,
            );

        if (pending.aadhar_number) {
          const [[dupAadhar]] = await conn.query(
            "SELECT emp_id FROM employee_master WHERE aadhar_number = ? AND tenant_id = ? LIMIT 1",
            [pending.aadhar_number, tenantId],
          );
          if (dupAadhar)
            return res
              .status(409)
              .json(
                (
                  await autoReject(
                    conn,
                    request_id,
                    "Duplicate Aadhar.",
                    `Aadhar '${pending.aadhar_number}' already registered.`,
                  )
                ).body,
              );
        }

        if (pending.pan_number) {
          const [[dupPan]] = await conn.query(
            "SELECT emp_id FROM employee_master WHERE pan_number = ? AND tenant_id = ? LIMIT 1",
            [pending.pan_number, tenantId],
          );
          if (dupPan)
            return res
              .status(409)
              .json(
                (
                  await autoReject(
                    conn,
                    request_id,
                    "Duplicate PAN.",
                    `PAN '${pending.pan_number}' already registered.`,
                  )
                ).body,
              );
        }

        const [[dupPending]] = await conn.query(
          `SELECT request_id FROM employee_pending_request
            WHERE email_id = ? AND tenant_id = ? AND admin_approve = 'PENDING' AND request_id != ? LIMIT 1`,
          [pending.email_id, tenantId, request_id],
        );
        if (dupPending) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            error: `Another pending request exists for email '${pending.email_id}'.`,
          });
        }

        // ── Insert employee ────────────────────────────────────────────────
        const [[{ empCount }]] = await conn.query(
          "SELECT COUNT(*) AS empCount FROM employee_master WHERE tenant_id = ?",
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
               pf_number, esic_number, years_experience, reporting_to_employee_id,
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
              (tenant_id, emp_id, username, password, role_id, is_first_login, status, created_at)
             VALUES (?, ?, ?, ?, ?, 1, 'Active', NOW())`,
          [
            tenantId,
            newEmpId,
            pending.username,
            pending.password,
            pending.role_id,
          ],
        );

        await applyEducationChanges(conn, request_id, newEmpId, tenantId);

        await conn.query(
          "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
          [request_id],
        );

        await conn.commit();

        // ── Face enrollment (after commit — non-fatal) ─────────────────────
        const { enrolled, warning } = await enrollFaceEmbedding(
          newEmpId,
          pending.profile_photo,
          pending.profile_photo_mime || "image/jpeg",
        );

        return res.json({
          success: true,
          message: "Employee created and approved successfully.",
          emp_id: newEmpId,
          face_enrolled: enrolled,
          // ✅ Admin UI can show this if face_enrolled is false
          face_warning: warning,
        });
      }

      // ══════════════════════════════════════════════════════════════════════
      // UPDATE EXISTING EMPLOYEE
      // ══════════════════════════════════════════════════════════════════════
      const empId = pending.emp_id;
      if (!empId) {
        await conn.rollback();
        return res.status(400).json({
          success: false,
          message: "emp_id missing for UPDATE request.",
        });
      }

      // ── Duplicate checks (exclude self) ────────────────────────────────
      if (pending.email_id) {
        const [[dup]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE email_id = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.email_id, tenantId, empId],
        );
        if (dup) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `Email '${pending.email_id}' in use.`,
          });
        }
      }

      if (pending.phone_number) {
        const [[dup]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE phone_number = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.phone_number, tenantId, empId],
        );
        if (dup) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `Phone '${pending.phone_number}' in use.`,
          });
        }
      }

      if (pending.aadhar_number) {
        const [[dup]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE aadhar_number = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.aadhar_number, tenantId, empId],
        );
        if (dup) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `Aadhar '${pending.aadhar_number}' in use.`,
          });
        }
      }

      if (pending.pan_number) {
        const [[dup]] = await conn.query(
          "SELECT emp_id FROM employee_master WHERE pan_number = ? AND tenant_id = ? AND emp_id != ? LIMIT 1",
          [pending.pan_number, tenantId, empId],
        );
        if (dup) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `PAN '${pending.pan_number}' in use.`,
          });
        }
      }

      // ── Build dynamic SET clause ────────────────────────────────────────
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

      await applyEducationChanges(conn, request_id, empId, tenantId);

      await conn.query(
        "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
        [request_id],
      );

      await conn.commit();

      // ── Re-enroll face if photo changed (after commit — non-fatal) ──────
      const { enrolled, warning } = await enrollFaceEmbedding(
        empId,
        pending.profile_photo, // null if photo wasn't changed — helper handles it
        pending.profile_photo_mime || "image/jpeg",
      );

      return res.json({
        success: true,
        message: "Employee updated and approved successfully.",
        emp_id: empId,
        face_enrolled: enrolled,
        face_warning: warning,
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
