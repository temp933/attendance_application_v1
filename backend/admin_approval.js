require("dotenv").config();
const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const db = require("./config/db");
const authMiddleware = require("./middleware/auth");

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
    req.user.roleId = parseInt(req.user.role_id, 10); // ← parse to int
    req.user.empId = req.user.emp_id;
    req.user.companyId = req.user.tenant_id ?? req.headers["x-tenant-id"];
    next();
  });
}

function requireRole(...roles) {
  return (req, res, next) => {
    // Parse to int — JWT often returns role_id as a string
    const userRole = parseInt(req.user.roleId, 10);
    if (!roles.includes(userRole)) {
      return res.status(403).json({ success: false, message: "Forbidden." });
    }
    next();
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/pending-requests
// ─────────────────────────────────────────────────────────────────────────────
router.get(
  "/pending-requests",
  requireAuth,
  requireRole(1, 2),
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
            COALESCE(p.department_id,              e.department_id)              AS department_id,
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
            d.department_name,
            r.role_name
         FROM employee_pending_request p
         LEFT JOIN employee_master   e ON e.emp_id      = p.emp_id
                                      AND e.tenant_id   = p.tenant_id
         LEFT JOIN department_master d ON d.department_id = COALESCE(p.department_id, e.department_id)
                                      AND d.tenant_id   = p.tenant_id
         LEFT JOIN role_master       r ON r.role_id      = COALESCE(p.role_id, e.role_id)
                                      AND r.tenant_id   = p.tenant_id
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
             FROM education_details
             WHERE emp_id = ?
             ORDER BY education_level`,
            [row.emp_id],
          );
          row.education_list = liveEdu;
        } else {
          row.education_list = eduRows;
        }
      }

      res.json({ success: true, count: rows.length, data: rows });
    } catch (err) {
      console.error("[GET /admin/pending-requests]", err);
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

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/approve-request
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/approve-request",
  requireAuth,
  requireRole(1, 2),
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

      // ── NEW EMPLOYEE ────────────────────────────────────────────────────────
      if (pending.request_type === "NEW") {
        // ── 1. Email uniqueness ──
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

        // ── 2. Phone uniqueness ──
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

        // ── 3. Username uniqueness ──
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

        // ── 4. Aadhar uniqueness ──
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

        // ── 5. PAN uniqueness ──
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

        // ── 6. No other PENDING request for same email ──
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

        // ── Insert employee_master ──
        const [empResult] = await conn.query(
          `INSERT INTO employee_master
              (tenant_id, first_name, mid_name, last_name,
               email_id, phone_number, date_of_birth, gender,
               department_id, role_id,
               date_of_joining, employment_type, work_type,
               permanent_address, communication_address,
               aadhar_number, pan_number, passport_number,
               father_name, emergency_contact_relation, emergency_contact,
               pf_number, esic_number, years_experience,
               profile_photo, profile_photo_mime,
               status, created_at)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'Active',NOW())`,
          [
            tenantId,
            pending.first_name,
            pending.mid_name,
            pending.last_name,
            pending.email_id,
            pending.phone_number,
            pending.date_of_birth,
            pending.gender,
            pending.department_id,
            pending.role_id,
            pending.date_of_joining,
            pending.employment_type,
            pending.work_type,
            pending.permanent_address,
            pending.communication_address,
            pending.aadhar_number,
            pending.pan_number,
            pending.passport_number,
            pending.father_name,
            pending.emergency_contact_relation,
            pending.emergency_contact,
            pending.pf_number,
            pending.esic_number,
            pending.years_experience,
            pending.profile_photo || null,
            pending.profile_photo_mime || null,
          ],
        );

        const newEmpId = empResult.insertId;

        // ── Insert login_master ──
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

        // ── Copy education staging → live ──
        const [eduRows] = await conn.query(
          "SELECT * FROM education_pending_request WHERE request_id = ?",
          [request_id],
        );
        for (const edu of eduRows) {
          await conn.query(
            `INSERT INTO education_details
                (emp_id, education_level, stream, score,
                 year_of_passout, university, college_name)
               VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
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

        await conn.query(
          "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
          [request_id],
        );

        await conn.commit();
        return res.json({
          success: true,
          message: "Employee created and approved successfully.",
          emp_id: newEmpId,
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

      // ── Duplicate guards for UPDATE (exclude self with emp_id != empId) ──
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

      // ── Build UPDATE SET clause ──
      const updatable = [
        ["first_name", pending.first_name],
        ["mid_name", pending.mid_name],
        ["last_name", pending.last_name],
        ["email_id", pending.email_id],
        ["phone_number", pending.phone_number],
        ["date_of_birth", pending.date_of_birth],
        ["gender", pending.gender],
        ["department_id", pending.department_id],
        ["role_id", pending.role_id],
        ["date_of_joining", pending.date_of_joining],
        ["date_of_relieving", pending.date_of_relieving],
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
        ["status", pending.status],
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

      // ── Replace education ──
      const [eduRows] = await conn.query(
        "SELECT * FROM education_pending_request WHERE request_id = ?",
        [request_id],
      );
      if (eduRows.length > 0) {
        await conn.query("DELETE FROM education_details WHERE emp_id = ?", [
          empId,
        ]);
        for (const edu of eduRows) {
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
        }
      }

      await conn.query(
        "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
        [request_id],
      );

      await conn.commit();
      return res.json({
        success: true,
        message: "Employee updated and approved successfully.",
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
// POST /api/admin/reject-request
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/reject-request",
  requireAuth,
  requireRole(1, 2),
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
      console.error("[POST /admin/reject-request]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

module.exports = router;
