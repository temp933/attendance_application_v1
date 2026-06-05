  require("dotenv").config();

  const express = require("express");
  const router = express.Router();
  const bcrypt = require("bcryptjs");

  const db = require("./config/db");
  const authMiddleware = require("./middleware/auth");

  // ─────────────────────────────────────────────────────────────────────────────
  // AUTH MIDDLEWARE
  // ─────────────────────────────────────────────────────────────────────────────
  function requireAuth(req, res, next) {
    authMiddleware(req, res, () => {
      if (!req.user) {
        return res.status(401).json({
          success: false,
          message: "Unauthorized.",
        });
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
        return res.status(403).json({
          success: false,
          message: "Forbidden.",
        });
      }

      next();
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DATE VALIDATION
  // ─────────────────────────────────────────────────────────────────────────────
  function assertDateString(value, fieldName) {
    if (value === null || value === undefined || value === "") {
      return;
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new Error(`Field '${fieldName}' must be yyyy-MM-dd string`);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // AUTO REJECT HELPER
  // ─────────────────────────────────────────────────────────────────────────────
  async function autoReject(conn, request_id, reason, errorMsg) {
    await conn.query(
      `
          UPDATE employee_pending_request
          SET
            admin_approve = 'REJECTED',
            reject_reason = ?
          WHERE request_id = ?
        `,
      [reason, request_id],
    );

    await conn.commit();

    return {
      status: 409,
      body: {
        success: false,
        message: errorMsg,
      },
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // APPLY EDUCATION CHANGES
  // ─────────────────────────────────────────────────────────────────────────────
  async function applyEducationChanges(conn, request_id, empId, tenantId) {
    const [eduRows] = await conn.query(
      `
          SELECT *
          FROM education_pending_request
          WHERE request_id = ?
          ORDER BY edu_req_id
        `,
      [request_id],
    );

    if (eduRows.length === 0) {
      return false;
    }

    for (const edu of eduRows) {
      if (edu.is_changed === 0 && edu.action_type === "UPDATE") {
        continue;
      }

      switch (edu.action_type) {
        case "ADD":
          await conn.query(
            `
                INSERT INTO education_details
                (
                  tenant_id,
                  emp_id,
                  education_level,
                  stream,
                  score,
                  year_of_passout,
                  university,
                  college_name
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              `,
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
          await conn.query(
            `
                UPDATE education_details
                SET
                  tenant_id = ?,
                  education_level = ?,
                  stream = ?,
                  score = ?,
                  year_of_passout = ?,
                  university = ?,
                  college_name = ?
                WHERE edu_id = ?
                  AND emp_id = ?
              `,
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
          await conn.query(
            `
                DELETE FROM education_details
                WHERE edu_id = ?
                  AND emp_id = ?
              `,
            [edu.original_edu_id, empId],
          );
          break;
      }
    }

    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GET PENDING REQUESTS
  // ─────────────────────────────────────────────────────────────────────────────
  router.get(
    "/pending-requests",
    requireAuth,
    requireRole("admin", "hr"),
    async (req, res) => {
      const { tenantId } = req.user;

      try {
        const [rows] = await db.query(
          `
            SELECT
                p.request_id,
                p.emp_id,
                p.request_type,
                p.admin_approve,
                p.edit_reason,
                p.reject_reason,
                p.created_at,
                p.updated_at,

                COALESCE(p.first_name, e.first_name) AS first_name,
                COALESCE(p.mid_name, e.mid_name) AS mid_name,
                COALESCE(p.last_name, e.last_name) AS last_name,
                COALESCE(p.email_id, e.email_id) AS email_id,
                COALESCE(p.phone_number, e.phone_number) AS phone_number,
                COALESCE(p.date_of_birth, e.date_of_birth) AS date_of_birth,
                COALESCE(p.gender, e.gender) AS gender,

                COALESCE(p.father_name, e.father_name) AS father_name,

                COALESCE(
                  p.emergency_contact,
                  e.emergency_contact
                ) AS emergency_contact,

                COALESCE(
                  p.emergency_contact_relation,
                  e.emergency_contact_relation
                ) AS emergency_contact_relation,

                COALESCE(
                  p.designation_id,
                  e.designation_id
                ) AS designation_id,

                COALESCE(p.role_id, e.role_id) AS role_id,

                COALESCE(
                  p.date_of_joining,
                  e.date_of_joining
                ) AS date_of_joining,

                COALESCE(
                  p.date_of_relieving,
                  e.date_of_relieving
                ) AS date_of_relieving,

                COALESCE(
                  p.employment_type,
                  e.employment_type
                ) AS employment_type,

                COALESCE(
                  p.work_type,
                  e.work_type
                ) AS work_type,

                COALESCE(
                  p.years_experience,
                  e.years_experience
                ) AS years_experience,

                COALESCE(
                  p.permanent_address,
                  e.permanent_address
                ) AS permanent_address,

                COALESCE(
                  p.communication_address,
                  e.communication_address
                ) AS communication_address,

                COALESCE(
                  p.aadhar_number,
                  e.aadhar_number
                ) AS aadhar_number,

                COALESCE(
                  p.pan_number,
                  e.pan_number
                ) AS pan_number,

                COALESCE(
                  p.passport_number,
                  e.passport_number
                ) AS passport_number,

                COALESCE(
                  p.pf_number,
                  e.pf_number
                ) AS pf_number,

                COALESCE(
                  p.esic_number,
                  e.esic_number
                ) AS esic_number,

                p.username,

              d.designation_name,
              dep2.department_id,
              dep2.department_name,
              r.role_name,
              CONCAT(tl.first_name, ' ', COALESCE(tl.last_name, '')) AS reporting_to_name

          FROM employee_pending_request p

            LEFT JOIN employee_master e
              ON e.emp_id = p.emp_id
            AND e.tenant_id = p.tenant_id

            LEFT JOIN employee_master tl
              ON tl.emp_id = COALESCE(p.reporting_to_employee_id, e.reporting_to_employee_id)

            LEFT JOIN designation_master d
              ON d.designation_id =
                COALESCE(
                  p.designation_id,
                  e.designation_id
                )
            AND d.tenant_id = p.tenant_id

          LEFT JOIN role_master r
            ON r.role_id =
              COALESCE(
                p.role_id,
                e.role_id
              )
          AND r.tenant_id = p.tenant_id

          LEFT JOIN department_master dep2
            ON dep2.department_id = d.department_id
          AND dep2.tenant_id = p.tenant_id

          WHERE p.admin_approve = 'PENDING'
              AND p.tenant_id = ?

            ORDER BY p.created_at DESC
            `,
          [tenantId],
        );

        for (const row of rows) {
          // EDUCATION
          if (row.request_type === "NEW") {
            const [newEduRows] = await db.query(
              `SELECT education_level, stream, score, year_of_passout, university, college_name,
                      action_type, is_changed, original_edu_id
              FROM education_pending_request
              WHERE request_id = ?
              ORDER BY education_level`,
              [row.request_id],
            );
            row.education_list = newEduRows;
          }

          

          // CURRENT EMPLOYEE DATA
          if (row.request_type === "UPDATE" && row.emp_id) {
            const [[current]] = await db.query(
              `
                SELECT
                  e.first_name,
                  e.mid_name,
                  e.last_name,
                  e.email_id,
                  e.phone_number,
                  e.date_of_birth,
                  e.gender,
                  e.father_name,
                  e.emergency_contact,
                  e.emergency_contact_relation,

                  e.designation_id,
                  e.role_id,
                  e.reporting_to_employee_id,

                  e.date_of_joining,
                  e.date_of_relieving,
                  e.employment_type,
                  e.work_type,
                  e.years_experience,
                  e.status,

                  e.permanent_address,
                  e.communication_address,

                  e.aadhar_number,
                  e.pan_number,
                  e.passport_number,

                  e.pf_number,
                  e.esic_number,

                  d.designation_name,
                  dep.department_id,
                  dep.department_name,
                  r.role_name,
                  CONCAT(tl.first_name, ' ', COALESCE(tl.last_name, '')) AS reporting_to_name

                FROM employee_master e

                LEFT JOIN designation_master d
                  ON d.designation_id = e.designation_id
                AND d.tenant_id = e.tenant_id

                LEFT JOIN department_master dep
                  ON dep.department_id = d.department_id
                AND dep.tenant_id = e.tenant_id

                LEFT JOIN role_master r
                  ON r.role_id = e.role_id
                AND r.tenant_id = e.tenant_id

                LEFT JOIN employee_master tl
                  ON tl.emp_id = e.reporting_to_employee_id

                WHERE e.emp_id = ?
                  AND e.tenant_id = ?
              `,
              [row.emp_id, tenantId],
            );

            if (current) {
              const [masterEdu] = await db.query(
                `SELECT education_level, stream, score, year_of_passout, university, college_name
                FROM education_details
                WHERE emp_id = ? AND tenant_id = ?
                ORDER BY education_level`,
                [row.emp_id, tenantId],
              );
              current.education_list = masterEdu;
            }
            row.current_data = current || null;

            // ── Always send full pending edu list for diff; fall back to master if none ──
            const [pendingEduRows] = await db.query(
              `SELECT education_level, stream, score, year_of_passout, university, college_name,
                      action_type, is_changed, original_edu_id
              FROM education_pending_request
              WHERE request_id = ?
              ORDER BY education_level`,
              [row.request_id],
            );

            const hasAnyPendingEdu = pendingEduRows.length > 0;
            if (hasAnyPendingEdu) {
              row.education_list = pendingEduRows;
            } else {
              // No edu rows submitted at all — show master data as-is (no diff)
              const [masterEduFallback] = await db.query(
                `SELECT education_level, stream, score, year_of_passout, university, college_name
                FROM education_details
                WHERE emp_id = ? AND tenant_id = ?
                ORDER BY education_level`,
                [row.emp_id, tenantId],
              );
              row.education_list = masterEduFallback;
            }
          } else {
            row.current_data = null;
          }
        }

        res.json({
          success: true,
          count: rows.length,
          data: rows,
        });
      } catch (err) {
        console.error(err);

        res.status(500).json({
          success: false,
          message: "Server error.",
        });
      }
    },
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // APPROVE REQUEST
  // ─────────────────────────────────────────────────────────────────────────────
  router.post(
    "/approve-request",
    requireAuth,
    requireRole("admin", "hr"),
    async (req, res) => {
      const { tenantId } = req.user;
      const { request_id } = req.body;

      if (!request_id) {
        return res.status(400).json({
          success: false,
          message: "request_id is required",
        });
      }

      const conn = await db.getConnection();

      try {
        await conn.beginTransaction();

        const [[pending]] = await conn.query(
          `
              SELECT *
              FROM employee_pending_request
              WHERE request_id = ?
                AND tenant_id = ?
                AND admin_approve = 'PENDING'
            `,
          [request_id, tenantId],
        );

        if (!pending) {
          await conn.rollback();

          return res.status(404).json({
            success: false,
            message: "Pending request not found",
          });
        }

        assertDateString(pending.date_of_birth, "date_of_birth");

        assertDateString(pending.date_of_joining, "date_of_joining");

        assertDateString(pending.date_of_relieving, "date_of_relieving");

        // ───────────────────────────────────────────────────────────────────────
        // NEW EMPLOYEE
        // ───────────────────────────────────────────────────────────────────────
        if (pending.request_type === "NEW") {
          const [[dupEmail]] = await conn.query(
            `
                SELECT emp_id
                FROM employee_master
                WHERE email_id = ?
                  AND tenant_id = ?
                LIMIT 1
              `,
            [pending.email_id, tenantId],
          );

          if (dupEmail) {
            const r = await autoReject(
              conn,
              request_id,
              "Duplicate email",
              "Email already exists",
            );

            return res.status(r.status).json(r.body);
          }

          // Generate employee_code: EMP0001, EMP0002, … (tenant-scoped)
          const [[{ empCount }]] = await conn.query(
            `SELECT COUNT(*) AS empCount FROM employee_master WHERE tenant_id = ?`,
            [tenantId],
          );
          const employeeCode = `EMP${String(empCount + 1).padStart(4, "0")}`;

          const [empResult] = await conn.query(
            `
        INSERT INTO employee_master
        (
          tenant_id,
          employee_code,
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
          reporting_to_employee_id,
          profile_photo,
          profile_photo_mime,
          status,
          created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
      `,
            [
              tenantId, // 1  tenant_id
              employeeCode, // 2  employee_code
              pending.first_name, // 3  first_name
              pending.mid_name, // 4  mid_name
              pending.last_name, // 5  last_name
              pending.email_id, // 6  email_id
              pending.phone_number, // 7  phone_number
              pending.date_of_birth, // 8  date_of_birth
              pending.gender, // 9  gender
              pending.designation_id, // 10 designation_id
              pending.role_id, // 11 role_id
              pending.date_of_joining, // 12 date_of_joining
              pending.date_of_relieving ?? null, // 13 date_of_relieving
              pending.employment_type, // 14 employment_type
              pending.work_type, // 15 work_type
              pending.permanent_address, // 16 permanent_address
              pending.communication_address, // 17 communication_address
              pending.aadhar_number, // 18 aadhar_number
              pending.pan_number, // 19 pan_number
              pending.passport_number ?? null, // 20 passport_number
              pending.father_name, // 21 father_name
              pending.emergency_contact_relation, // 22 emergency_contact_relation
              pending.emergency_contact, // 23 emergency_contact
              pending.pf_number ?? null, // 24 pf_number
              pending.esic_number ?? null, // 25 esic_number
              pending.years_experience, // 26 years_experience
              pending.reporting_to_employee_id ?? null, // 27 reporting_to_employee_id
              pending.profile_photo ?? null, // 28 profile_photo
              pending.profile_photo_mime ?? null, // 29 profile_photo_mime
              pending.status ?? "Active", // 30 status
            ],
          );

          const newEmpId = empResult.insertId;

          await conn.query(
            `
                INSERT INTO login_master
                (
                  tenant_id,
                  emp_id,
                  username,
                  password,
                  role_id,
                  is_first_login,
                  status,
                  created_at
                )
                VALUES
                (
                  ?, ?, ?, ?, ?, 1,
                  'Active',
                  NOW()
                )
              `,
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
            `
                UPDATE employee_pending_request
                SET admin_approve = 'APPROVED'
                WHERE request_id = ?
              `,
            [request_id],
          );

          await conn.commit();

          return res.json({
            success: true,
            message: "Employee approved successfully",
            emp_id: newEmpId,
          });
        }

        // ───────────────────────────────────────────────────────────────────────
        // UPDATE EMPLOYEE
        // ───────────────────────────────────────────────────────────────────────
        const empId = pending.emp_id;

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
          ["reporting_to_employee_id", pending.reporting_to_employee_id],
        ].filter(([, value]) => value !== null && value !== undefined);

        if (pending.profile_photo) {
          updatable.push(["profile_photo", pending.profile_photo]);

          updatable.push(["profile_photo_mime", pending.profile_photo_mime]);
        }

        if (updatable.length > 0) {
          const setClause = updatable.map(([field]) => `${field} = ?`).join(", ");

          const values = updatable.map(([, value]) => value);

          await conn.query(
            `
                UPDATE employee_master
                SET ${setClause}
                WHERE emp_id = ?
                  AND tenant_id = ?
              `,
            [...values, empId, tenantId],
          );
        }

        if (pending.role_id) {
          await conn.query(
            `
                UPDATE login_master
                SET role_id = ?
                WHERE emp_id = ?
                  AND tenant_id = ?
              `,
            [pending.role_id, empId, tenantId],
          );
        }

        await applyEducationChanges(conn, request_id, empId, tenantId);

        await conn.query(
          `
              UPDATE employee_pending_request
              SET admin_approve = 'APPROVED'
              WHERE request_id = ?
            `,
          [request_id],
        );

        await conn.commit();

        return res.json({
          success: true,
          message: "Employee updated successfully",
          emp_id: empId,
        });
      } catch (err) {
        await conn.rollback();

        console.error(err);

        return res.status(500).json({
          success: false,
          message: "Server error",
        });
      } finally {
        conn.release();
      }
    },
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // REJECT REQUEST
  // ─────────────────────────────────────────────────────────────────────────────
  router.post(
    "/reject-request",
    requireAuth,
    requireRole("admin", "hr"),
    async (req, res) => {
      const { tenantId } = req.user;

      const { request_id, reject_reason } = req.body;

      if (!request_id || !reject_reason) {
        return res.status(400).json({
          success: false,
          message: "request_id and reject_reason required",
        });
      }

      try {
        const [result] = await db.query(
          `
              UPDATE employee_pending_request
              SET
                admin_approve = 'REJECTED',
                reject_reason = ?
              WHERE request_id = ?
                AND tenant_id = ?
                AND admin_approve = 'PENDING'
            `,
          [reject_reason, request_id, tenantId],
        );

        if (result.affectedRows === 0) {
          return res.status(404).json({
            success: false,
            message: "Pending request not found",
          });
        }

        res.json({
          success: true,
          message: "Request rejected",
        });
      } catch (err) {
        console.error(err);

        res.status(500).json({
          success: false,
          message: "Server error",
        });
      }
    },
  );

  module.exports = router;
