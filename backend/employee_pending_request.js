// // require("dotenv").config();
// // const express = require("express");
// // const router = express.Router();
// // const bcrypt = require("bcryptjs");
// // const multer = require("multer");
// // const db = require("./config/db");
// // const authMiddleware = require("./middleware/auth");

// // // ── Multer ────────────────────────────────────────────────────────────────────
// // const upload = multer({
// //   storage: multer.memoryStorage(),
// //   limits: { fileSize: 2 * 1024 * 1024 },
// //   fileFilter: (_, file, cb) => {
// //     if (file.mimetype.startsWith("image/")) cb(null, true);
// //     else cb(new Error("Only image files are allowed."));
// //   },
// // });

// // function requireAuth(req, res, next) {
// //   authMiddleware(req, res, () => {
// //     if (!req.user) {
// //       return res.status(401).json({ success: false, message: "Unauthorized." });
// //     }
// //     req.user.loginId = req.user.login_id;
// //     req.user.tenantId = req.user.tenant_id;
// //     req.user.roleId = req.user.role_id;
// //     req.user.empId = req.user.emp_id;
// //     req.user.companyId = req.user.tenant_id;
// //     next();
// //   });
// // }

// // function requireRole(...roles) {
// //   return (req, res, next) => {
// //     if (!roles.includes(req.user.roleId)) {
// //       return res.status(403).json({ success: false, message: "Forbidden." });
// //     }
// //     next();
// //   };
// // }

// // function nullIfEmpty(v) {
// //   return v === undefined || v === null || v === "" ? null : v;
// // }

// // // ─────────────────────────────────────────────────────────────────────────────
// // // POST /api/pending-request
// // // ─────────────────────────────────────────────────────────────────────────────
// // router.post("/", requireAuth, async (req, res) => {
// //   const { tenantId, empId: submittedBy } = req.user;
// //   const {
// //     request_type = "NEW",
// //     emp_id,
// //     first_name,
// //     mid_name,
// //     last_name,
// //     email_id,
// //     phone_number,
// //     date_of_birth,
// //     gender,
// //     department_id,
// //     role_id,
// //     date_of_joining,
// //     date_of_relieving,
// //     employment_type,
// //     work_type,
// //     permanent_address,
// //     communication_address,
// //     aadhar_number,
// //     pan_number,
// //     passport_number,
// //     father_name,
// //     emergency_contact_relation,
// //     emergency_contact,
// //     pf_number,
// //     esic_number,
// //     years_experience,
// //     username,
// //     password: rawPassword,
// //     edit_reason,
// //     education,
// //   } = req.body;

// //   if (!first_name || !last_name || !email_id || !phone_number) {
// //     return res.status(400).json({
// //       success: false,
// //       message: "first_name, last_name, email_id, phone_number are required.",
// //     });
// //   }
// //   if (request_type === "UPDATE" && !emp_id) {
// //     return res.status(400).json({
// //       success: false,
// //       message: "emp_id is required for UPDATE requests.",
// //     });
// //   }
// //   if (request_type === "NEW" && (!username || !rawPassword)) {
// //     return res.status(400).json({
// //       success: false,
// //       message: "username and password are required for NEW requests.",
// //     });
// //   }

// //   const conn = await db.getConnection();
// //   try {
// //     await conn.beginTransaction();

// //     const hashedPassword = rawPassword
// //       ? await bcrypt.hash(rawPassword, 12)
// //       : null;

// //     const [result] = await conn.query(
// //       `INSERT INTO employee_pending_request
// //         (tenant_id, emp_id, request_type, admin_approve,
// //          first_name, mid_name, last_name,
// //          email_id, phone_number, date_of_birth, gender,
// //          department_id, role_id,
// //          date_of_joining, date_of_relieving,
// //          employment_type, work_type,
// //          permanent_address, communication_address,
// //          aadhar_number, pan_number, passport_number,
// //          father_name, emergency_contact_relation, emergency_contact,
// //          pf_number, esic_number, years_experience,
// //          username, password, edit_reason,
// //          status, created_at)
// //        VALUES (?, ?, ?, 'PENDING',
// //                ?, ?, ?,
// //                ?, ?, ?, ?,
// //                ?, ?,
// //                ?, ?,
// //                ?, ?,
// //                ?, ?,
// //                ?, ?, ?,
// //                ?, ?, ?,
// //                ?, ?, ?,
// //                ?, ?, ?,
// //                'Active', NOW())`,
// //       [
// //         tenantId,
// //         nullIfEmpty(emp_id),
// //         request_type,
// //         nullIfEmpty(first_name),
// //         nullIfEmpty(mid_name),
// //         nullIfEmpty(last_name),
// //         nullIfEmpty(email_id),
// //         nullIfEmpty(phone_number),
// //         nullIfEmpty(date_of_birth),
// //         nullIfEmpty(gender),
// //         nullIfEmpty(department_id),
// //         nullIfEmpty(role_id),
// //         nullIfEmpty(date_of_joining),
// //         nullIfEmpty(date_of_relieving),
// //         nullIfEmpty(employment_type),
// //         nullIfEmpty(work_type),
// //         nullIfEmpty(permanent_address),
// //         nullIfEmpty(communication_address),
// //         nullIfEmpty(aadhar_number),
// //         nullIfEmpty(pan_number),
// //         nullIfEmpty(passport_number),
// //         nullIfEmpty(father_name),
// //         nullIfEmpty(emergency_contact_relation),
// //         nullIfEmpty(emergency_contact),
// //         nullIfEmpty(pf_number),
// //         nullIfEmpty(esic_number),
// //         years_experience !== undefined ? parseInt(years_experience, 10) : null,
// //         nullIfEmpty(username),
// //         hashedPassword,
// //         nullIfEmpty(edit_reason),
// //       ],
// //     );

// //     const requestId = result.insertId;

// //     // emp_id is null for NEW requests, provided for UPDATE requests
// //     const eduEmpId = nullIfEmpty(emp_id);

// //     if (Array.isArray(education) && education.length > 0) {
// //       for (const edu of education) {
// //         await conn.query(
// //           `INSERT INTO education_pending_request
// //             (request_id, tenant_id, emp_id, education_level, stream, score,
// //              year_of_passout, university, college_name, action_type)
// //            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'ADD')`,
// //           [
// //             requestId,
// //             tenantId,
// //             eduEmpId,
// //             nullIfEmpty(edu.education_level),
// //             nullIfEmpty(edu.stream),
// //             nullIfEmpty(edu.score),
// //             nullIfEmpty(edu.year_of_passout),
// //             nullIfEmpty(edu.university),
// //             nullIfEmpty(edu.college_name),
// //           ],
// //         );
// //       }
// //     }

// //     await conn.commit();
// //     res.status(201).json({
// //       success: true,
// //       message:
// //         request_type === "NEW"
// //           ? "Employee request submitted for approval."
// //           : "Edit request submitted for approval.",
// //       request_id: requestId,
// //     });
// //   } catch (err) {
// //     await conn.rollback();
// //     console.error("[POST /pending-request]", err);
// //     if (err.code === "ER_DUP_ENTRY") {
// //       return res
// //         .status(409)
// //         .json({ success: false, message: "Duplicate entry." });
// //     }
// //     res.status(500).json({ success: false, message: "Server error." });
// //   } finally {
// //     conn.release();
// //   }
// // });

// // // ─────────────────────────────────────────────────────────────────────────────
// // // POST /api/pending-request/:id/photo
// // // ─────────────────────────────────────────────────────────────────────────────
// // // ─── POST /:id/photo  (UPLOAD) ─────────────────────────────────────────────
// // router.post(
// //   "/:id/photo",
// //   requireAuth,
// //   upload.single("photo"),
// //   async (req, res) => {
// //     const { tenantId } = req.user;
// //     const { id } = req.params;

// //     if (!req.file) {
// //       return res
// //         .status(400)
// //         .json({ success: false, message: "No image file provided." });
// //     }

// //     try {
// //       const [result] = await db.query(
// //         `UPDATE employee_pending_request
// //            SET profile_photo = ?, profile_photo_mime = ?
// //          WHERE request_id = ? AND tenant_id = ?`,
// //         [
// //           req.file.buffer,
// //           req.file.mimetype === "application/octet-stream"
// //             ? "image/jpeg"
// //             : req.file.mimetype,
// //           id,
// //           tenantId,
// //         ],
// //       );

// //       if (result.affectedRows === 0) {
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Request not found." });
// //       }

// //       res.json({ success: true, message: "Photo uploaded." });
// //     } catch (err) {
// //       console.error("[POST /pending-request/:id/photo]", err);
// //       res.status(500).json({ success: false, message: err.message });
// //     }
// //   },
// // );

// // // ─── GET /:id/photo  (SERVE) ──────────────────────────────────────────────── ← THIS WAS MISSING
// // router.get("/:id/photo", requireAuth, async (req, res) => {
// //   const { tenantId } = req.user;
// //   const { id } = req.params;

// //   try {
// //     const [[row]] = await db.query(
// //       `SELECT profile_photo, profile_photo_mime
// //          FROM employee_pending_request
// //         WHERE request_id = ? AND tenant_id = ?
// //         LIMIT 1`,
// //       [id, tenantId],
// //     );

// //     if (!row || !row.profile_photo) {
// //       return res
// //         .status(404)
// //         .json({ success: false, message: "No photo found." });
// //     }

// //     res.set("Content-Type", row.profile_photo_mime || "image/jpeg");
// //     res.set("Cache-Control", "private, max-age=3600");
// //     res.send(row.profile_photo);
// //   } catch (err) {
// //     console.error("[GET /pending-request/:id/photo]", err);
// //     res.status(500).json({ success: false, message: "Server error." });
// //   }
// // });

// // // ─────────────────────────────────────────────────────────────────────────────
// // // GET /api/pending-request
// // // ─────────────────────────────────────────────────────────────────────────────
// // router.get("/", requireAuth, async (req, res) => {
// //   const { tenantId, roleId, empId } = req.user;
// //   const isAdminOrHR = [1, 2].includes(roleId);
// //   const { status, request_type } = req.query;

// //   try {
// //     const conditions = ["epr.tenant_id = ?"];
// //     const params = [tenantId];

// //     if (!isAdminOrHR) {
// //       conditions.push("epr.emp_id = ?");
// //       params.push(empId);
// //     }
// //     if (status) {
// //       conditions.push("epr.admin_approve = ?");
// //       params.push(status);
// //     }
// //     if (request_type) {
// //       conditions.push("epr.request_type = ?");
// //       params.push(request_type);
// //     }

// //     const where = conditions.join(" AND ");

// //     const [rows] = await db.query(
// //       `SELECT
// //           epr.*,
// //           d.department_name,
// //           r.role_name
// //          FROM employee_pending_request epr
// //          LEFT JOIN department_master d ON d.department_id = epr.department_id
// //          LEFT JOIN role_master        r ON r.role_id       = epr.role_id
// //         WHERE ${where}
// //         ORDER BY epr.created_at DESC`,
// //       params,
// //     );

// //     res.json({ success: true, count: rows.length, data: rows });
// //   } catch (err) {
// //     console.error("[GET /pending-request]", err);
// //     res.status(500).json({ success: false, message: "Server error." });
// //   }
// // });

// // // ─────────────────────────────────────────────────────────────────────────────
// // // GET /api/pending-request/:id
// // // ─────────────────────────────────────────────────────────────────────────────
// // router.get("/:id", requireAuth, async (req, res) => {
// //   const { tenantId } = req.user;
// //   const { id } = req.params;

// //   try {
// //     const [[row]] = await db.query(
// //       `SELECT
// //           epr.*,
// //           d.department_name,
// //           r.role_name
// //          FROM employee_pending_request epr
// //          LEFT JOIN department_master d ON d.department_id = epr.department_id
// //          LEFT JOIN role_master        r ON r.role_id       = epr.role_id
// //         WHERE epr.request_id = ? AND epr.tenant_id = ?
// //         LIMIT 1`,
// //       [id, tenantId],
// //     );

// //     if (!row) {
// //       return res
// //         .status(404)
// //         .json({ success: false, message: "Request not found." });
// //     }

// //     const [eduRows] = await db.query(
// //       "SELECT * FROM education_pending_request WHERE request_id = ?",
// //       [id],
// //     );
// //     row.education = eduRows;

// //     res.json({ success: true, data: row });
// //   } catch (err) {
// //     console.error("[GET /pending-request/:id]", err);
// //     res.status(500).json({ success: false, message: "Server error." });
// //   }
// // });

// // // ─────────────────────────────────────────────────────────────────────────────
// // // PUT /api/pending-request/:id/review
// // // Admin/HR only — APPROVE or REJECT.
// // // ─────────────────────────────────────────────────────────────────────────────
// // router.put("/:id/review", requireAuth, requireRole(1, 2), async (req, res) => {
// //   const { tenantId, empId: reviewerId, companyId } = req.user;
// //   const { id } = req.params;
// //   const { action, reject_reason } = req.body;

// //   if (!["APPROVE", "REJECT"].includes(action)) {
// //     return res.status(400).json({
// //       success: false,
// //       message: "action must be APPROVE or REJECT.",
// //     });
// //   }

// //   const conn = await db.getConnection();
// //   try {
// //     await conn.beginTransaction();

// //     const [[pending]] = await conn.query(
// //       `SELECT * FROM employee_pending_request
// //           WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'PENDING'`,
// //       [id, tenantId],
// //     );

// //     if (!pending) {
// //       await conn.rollback();
// //       return res
// //         .status(404)
// //         .json({ success: false, message: "Pending request not found." });
// //     }

// //     // ── REJECT ────────────────────────────────────────────────────────────
// //     if (action === "REJECT") {
// //       await conn.query(
// //         `UPDATE employee_pending_request
// //               SET admin_approve = 'REJECTED', reject_reason = ?
// //             WHERE request_id = ?`,
// //         [reject_reason || null, id],
// //       );
// //       await conn.commit();
// //       return res.json({ success: true, message: "Request rejected." });
// //     }

// //     // ── APPROVE NEW ───────────────────────────────────────────────────────
// //     if (pending.request_type === "NEW") {
// //       const [empResult] = await conn.query(
// //         `INSERT INTO employee_master
// //             (tenant_id, first_name, mid_name, last_name,
// //              email_id, phone_number, date_of_birth, gender,
// //              department_id, role_id,
// //              date_of_joining, employment_type, work_type,
// //              permanent_address, communication_address,
// //              aadhar_number, pan_number, passport_number,
// //              father_name, emergency_contact_relation, emergency_contact,
// //              pf_number, esic_number, years_experience,
// //              profile_photo, profile_photo_mime,
// //              status, created_at)
// //            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'Active',NOW())`,
// //         [
// //           tenantId,
// //           pending.first_name,
// //           pending.mid_name,
// //           pending.last_name,
// //           pending.email_id,
// //           pending.phone_number,
// //           pending.date_of_birth,
// //           pending.gender,
// //           pending.department_id,
// //           pending.role_id,
// //           pending.date_of_joining,
// //           pending.employment_type,
// //           pending.work_type,
// //           pending.permanent_address,
// //           pending.communication_address,
// //           pending.aadhar_number,
// //           pending.pan_number,
// //           pending.passport_number,
// //           pending.father_name,
// //           pending.emergency_contact_relation,
// //           pending.emergency_contact,
// //           pending.pf_number,
// //           pending.esic_number,
// //           pending.years_experience,
// //           pending.profile_photo,
// //           pending.profile_photo_mime,
// //         ],
// //       );

// //       const newEmpId = empResult.insertId;

// //       await conn.query(
// //         `INSERT INTO login_master
// //             (tenant_id, company_id, emp_id, username, password,
// //              role_id, is_first_login, status, created_at)
// //            VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
// //         [
// //           tenantId,
// //           companyId ?? tenantId,
// //           newEmpId,
// //           pending.username,
// //           pending.password,
// //           pending.role_id,
// //         ],
// //       );

// //       // Copy education from staging → live table
// //       const [eduRows] = await conn.query(
// //         "SELECT * FROM education_pending_request WHERE request_id = ?",
// //         [id],
// //       );
// //       for (const edu of eduRows) {
// //         await conn.query(
// //           `INSERT INTO employee_education
// //               (emp_id, education_level, stream, score,
// //                year_of_passout, university, college_name)
// //              VALUES (?, ?, ?, ?, ?, ?, ?)`,
// //           [
// //             newEmpId,
// //             edu.education_level,
// //             edu.stream,
// //             edu.score,
// //             edu.year_of_passout,
// //             edu.university,
// //             edu.college_name,
// //           ],
// //         );
// //       }

// //       await conn.query(
// //         "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
// //         [id],
// //       );

// //       await conn.commit();
// //       return res.json({
// //         success: true,
// //         message: "Employee created successfully.",
// //         emp_id: newEmpId,
// //       });
// //     }

// //     // ── APPROVE UPDATE ────────────────────────────────────────────────────
// //     const empId = pending.emp_id;
// //     if (!empId) {
// //       await conn.rollback();
// //       return res.status(400).json({
// //         success: false,
// //         message: "emp_id missing for UPDATE request.",
// //       });
// //     }

// //     const updatable = [
// //       ["first_name", pending.first_name],
// //       ["mid_name", pending.mid_name],
// //       ["last_name", pending.last_name],
// //       ["email_id", pending.email_id],
// //       ["phone_number", pending.phone_number],
// //       ["date_of_birth", pending.date_of_birth],
// //       ["gender", pending.gender],
// //       ["department_id", pending.department_id],
// //       ["role_id", pending.role_id],
// //       ["date_of_joining", pending.date_of_joining],
// //       ["date_of_relieving", pending.date_of_relieving],
// //       ["employment_type", pending.employment_type],
// //       ["work_type", pending.work_type],
// //       ["permanent_address", pending.permanent_address],
// //       ["communication_address", pending.communication_address],
// //       ["aadhar_number", pending.aadhar_number],
// //       ["pan_number", pending.pan_number],
// //       ["passport_number", pending.passport_number],
// //       ["father_name", pending.father_name],
// //       ["emergency_contact_relation", pending.emergency_contact_relation],
// //       ["emergency_contact", pending.emergency_contact],
// //       ["pf_number", pending.pf_number],
// //       ["esic_number", pending.esic_number],
// //       ["years_experience", pending.years_experience],
// //       ["status", pending.status],
// //     ].filter(([, v]) => v !== null && v !== undefined);

// //     if (pending.profile_photo) {
// //       updatable.push(["profile_photo", pending.profile_photo]);
// //       updatable.push(["profile_photo_mime", pending.profile_photo_mime]);
// //     }

// //     if (updatable.length > 0) {
// //       const setClauses = updatable.map(([f]) => `${f} = ?`).join(", ");
// //       const values = updatable.map(([, v]) => v);
// //       await conn.query(
// //         `UPDATE employee_master SET ${setClauses}
// //             WHERE emp_id = ? AND tenant_id = ?`,
// //         [...values, empId, tenantId],
// //       );

// //       if (pending.role_id) {
// //         await conn.query(
// //           "UPDATE login_master SET role_id = ? WHERE emp_id = ?",
// //           [pending.role_id, empId],
// //         );
// //       }
// //     }

// //     // Replace education in live table from staging
// //     const [eduRows] = await conn.query(
// //       "SELECT * FROM education_pending_request WHERE request_id = ?",
// //       [id],
// //     );
// //     if (eduRows.length > 0) {
// //       await conn.query("DELETE FROM employee_education WHERE emp_id = ?", [
// //         empId,
// //       ]);
// //       for (const edu of eduRows) {
// //         await conn.query(
// //           `INSERT INTO employee_education
// //               (emp_id, education_level, stream, score,
// //                year_of_passout, university, college_name)
// //              VALUES (?, ?, ?, ?, ?, ?, ?)`,
// //           [
// //             empId,
// //             edu.education_level,
// //             edu.stream,
// //             edu.score,
// //             edu.year_of_passout,
// //             edu.university,
// //             edu.college_name,
// //           ],
// //         );
// //       }
// //     }

// //     await conn.query(
// //       "UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?",
// //       [id],
// //     );

// //     await conn.commit();
// //     return res.json({
// //       success: true,
// //       message: "Employee updated successfully.",
// //       emp_id: empId,
// //     });
// //   } catch (err) {
// //     await conn.rollback();
// //     console.error("[PUT /pending-request/:id/review]", err);
// //     res.status(500).json({ success: false, message: "Server error." });
// //   } finally {
// //     conn.release();
// //   }
// // });

// // // ─────────────────────────────────────────────────────────────────────────────
// // // PUT /api/pending-request/:id/resubmit
// // // ─────────────────────────────────────────────────────────────────────────────
// // router.put("/:id/resubmit", requireAuth, async (req, res) => {
// //   const { tenantId } = req.user;
// //   const { id } = req.params;
// //   const {
// //     first_name,
// //     mid_name,
// //     last_name,
// //     email_id,
// //     phone_number,
// //     date_of_birth,
// //     gender,
// //     department_id,
// //     role_id,
// //     date_of_joining,
// //     employment_type,
// //     work_type,
// //     permanent_address,
// //     communication_address,
// //     aadhar_number,
// //     pan_number,
// //     passport_number,
// //     father_name,
// //     emergency_contact_relation,
// //     emergency_contact,
// //     pf_number,
// //     esic_number,
// //     years_experience,
// //     username,
// //     education,
// //   } = req.body;

// //   const conn = await db.getConnection();
// //   try {
// //     await conn.beginTransaction();

// //     // Fetch existing record to get emp_id (needed for education_pending_request)
// //     const [[existing]] = await conn.query(
// //       `SELECT request_id, emp_id FROM employee_pending_request
// //         WHERE request_id = ? AND tenant_id = ? AND admin_approve = 'REJECTED'`,
// //       [id, tenantId],
// //     );

// //     if (!existing) {
// //       await conn.rollback();
// //       return res.status(404).json({
// //         success: false,
// //         message: "Rejected request not found.",
// //       });
// //     }

// //     await conn.query(
// //       `UPDATE employee_pending_request SET
// //           admin_approve = 'PENDING', reject_reason = NULL,
// //           first_name = ?, mid_name = ?, last_name = ?,
// //           email_id = ?, phone_number = ?, date_of_birth = ?, gender = ?,
// //           department_id = ?, role_id = ?,
// //           date_of_joining = ?, employment_type = ?, work_type = ?,
// //           permanent_address = ?, communication_address = ?,
// //           aadhar_number = ?, pan_number = ?, passport_number = ?,
// //           father_name = ?, emergency_contact_relation = ?, emergency_contact = ?,
// //           pf_number = ?, esic_number = ?, years_experience = ?,
// //           username = ?, updated_at = NOW()
// //         WHERE request_id = ?`,
// //       [
// //         nullIfEmpty(first_name),
// //         nullIfEmpty(mid_name),
// //         nullIfEmpty(last_name),
// //         nullIfEmpty(email_id),
// //         nullIfEmpty(phone_number),
// //         nullIfEmpty(date_of_birth),
// //         nullIfEmpty(gender),
// //         nullIfEmpty(department_id),
// //         nullIfEmpty(role_id),
// //         nullIfEmpty(date_of_joining),
// //         nullIfEmpty(employment_type),
// //         nullIfEmpty(work_type),
// //         nullIfEmpty(permanent_address),
// //         nullIfEmpty(communication_address),
// //         nullIfEmpty(aadhar_number),
// //         nullIfEmpty(pan_number),
// //         nullIfEmpty(passport_number),
// //         nullIfEmpty(father_name),
// //         nullIfEmpty(emergency_contact_relation),
// //         nullIfEmpty(emergency_contact),
// //         nullIfEmpty(pf_number),
// //         nullIfEmpty(esic_number),
// //         years_experience !== undefined ? parseInt(years_experience, 10) : null,
// //         nullIfEmpty(username),
// //         id,
// //       ],
// //     );

// //     if (Array.isArray(education) && education.length > 0) {
// //       await conn.query(
// //         "DELETE FROM education_pending_request WHERE request_id = ?",
// //         [id],
// //       );
// //       for (const edu of education) {
// //         await conn.query(
// //           `INSERT INTO education_pending_request
// //             (request_id, tenant_id, emp_id, education_level, stream, score,
// //              year_of_passout, university, college_name, action_type)
// //            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'ADD')`,
// //           [
// //             id,
// //             tenantId,
// //             nullIfEmpty(existing.emp_id), // null for NEW, real id for UPDATE
// //             nullIfEmpty(edu.education_level),
// //             nullIfEmpty(edu.stream),
// //             nullIfEmpty(edu.score),
// //             nullIfEmpty(edu.year_of_passout),
// //             nullIfEmpty(edu.university),
// //             nullIfEmpty(edu.college_name),
// //           ],
// //         );
// //       }
// //     }

// //     await conn.commit();
// //     res.json({ success: true, message: "Request resubmitted for approval." });
// //   } catch (err) {
// //     await conn.rollback();
// //     console.error("[PUT /pending-request/:id/resubmit]", err);
// //     res.status(500).json({ success: false, message: "Server error." });
// //   } finally {
// //     conn.release();
// //   }
// // });

// // module.exports = router;
// require("dotenv").config();

// const express = require("express");
// const router = express.Router();
// const bcrypt = require("bcryptjs");
// const multer = require("multer");

// const db = require("./config/db");
// const authMiddleware = require("./middleware/auth");

// // ─────────────────────────────────────────────────────────────────────────────
// // MULTER
// // ─────────────────────────────────────────────────────────────────────────────
// const upload = multer({
//   storage: multer.memoryStorage(),
//   limits: { fileSize: 2 * 1024 * 1024 },
//   fileFilter: (_, file, cb) => {
//     if (file.mimetype.startsWith("image/")) {
//       cb(null, true);
//     } else {
//       cb(new Error("Only image files are allowed."));
//     }
//   },
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // AUTH
// // ─────────────────────────────────────────────────────────────────────────────
// function requireAuth(req, res, next) {
//   authMiddleware(req, res, () => {
//     if (!req.user) {
//       return res.status(401).json({
//         success: false,
//         message: "Unauthorized.",
//       });
//     }

//     req.user.loginId = req.user.login_id;
//     req.user.tenantId = req.user.tenant_id;
//     req.user.roleId = req.user.role_id;
//     req.user.empId = req.user.emp_id;
//     req.user.companyId = req.user.company_id;

//     next();
//   });
// }

// // TEMP ROLE CHECK
// // Later replace with permission-based RBAC
// function requireRole(...roles) {
//   return (req, res, next) => {
//     if (!roles.includes(req.user.roleId)) {
//       return res.status(403).json({
//         success: false,
//         message: "Forbidden.",
//       });
//     }

//     next();
//   };
// }

// function nullIfEmpty(v) {
//   return v === undefined || v === null || v === "" ? null : v;
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/pending-request
// // CREATE REQUEST
// // ─────────────────────────────────────────────────────────────────────────────
// router.post("/", requireAuth, async (req, res) => {
//   const { tenantId } = req.user;

//   const {
//     request_type = "NEW",

//     emp_id,

//     first_name,
//     mid_name,
//     last_name,

//     email_id,
//     phone_number,
//     date_of_birth,
//     gender,

//     designation_id,
//     role_id,

//     date_of_joining,
//     date_of_relieving,

//     employment_type,
//     work_type,

//     permanent_address,
//     communication_address,

//     aadhar_number,
//     pan_number,
//     passport_number,

//     father_name,

//     emergency_contact_relation,
//     emergency_contact,

//     pf_number,
//     esic_number,

//     years_experience,

//     username,
//     password: rawPassword,

//     edit_reason,

//     education,
//   } = req.body;

//   // ───────────────────────────────────────────────────────────────────────────
//   // VALIDATION
//   // ───────────────────────────────────────────────────────────────────────────
//   if (!first_name || !last_name || !email_id || !phone_number) {
//     return res.status(400).json({
//       success: false,
//       message: "first_name, last_name, email_id, phone_number are required.",
//     });
//   }

//   if (request_type === "UPDATE" && !emp_id) {
//     return res.status(400).json({
//       success: false,
//       message: "emp_id is required for UPDATE request.",
//     });
//   }

//   if (request_type === "NEW" && (!username || !rawPassword)) {
//     return res.status(400).json({
//       success: false,
//       message: "username and password are required for NEW request.",
//     });
//   }

//   const conn = await db.getConnection();

//   try {
//     await conn.beginTransaction();

//     // ─────────────────────────────────────────────────────────────────────────
//     // VALIDATE DESIGNATION
//     // ─────────────────────────────────────────────────────────────────────────
//     const [[designation]] = await conn.query(
//       `
//       SELECT
//         dm.designation_id,
//         dm.department_id,
//         dm.designation_name,
//         dep.department_name
//       FROM designation_master dm

//       INNER JOIN department_master dep
//         ON dep.department_id = dm.department_id

//       WHERE dm.designation_id = ?
//         AND dm.tenant_id = ?
//         AND dm.status = 'Active'
//         AND dm.is_deleted = 0

//       LIMIT 1
//       `,
//       [designation_id, tenantId],
//     );

//     if (!designation) {
//       await conn.rollback();

//       return res.status(400).json({
//         success: false,
//         message: "Invalid designation selected.",
//       });
//     }

//     // ─────────────────────────────────────────────────────────────────────────
//     // VALIDATE ROLE
//     // ─────────────────────────────────────────────────────────────────────────
//     const [[role]] = await conn.query(
//       `
//       SELECT role_id
//       FROM role_master
//       WHERE role_id = ?
//         AND tenant_id = ?
//         AND status = 'Active'
//         AND is_deleted = 0
//       LIMIT 1
//       `,
//       [role_id, tenantId],
//     );

//     if (!role) {
//       await conn.rollback();

//       return res.status(400).json({
//         success: false,
//         message: "Invalid role selected.",
//       });
//     }

//     // ─────────────────────────────────────────────────────────────────────────
//     // HASH PASSWORD
//     // ─────────────────────────────────────────────────────────────────────────
//     const hashedPassword = rawPassword
//       ? await bcrypt.hash(rawPassword, 12)
//       : null;

//     // ─────────────────────────────────────────────────────────────────────────
//     // INSERT REQUEST
//     // ─────────────────────────────────────────────────────────────────────────
//     const [result] = await conn.query(
//       `
//       INSERT INTO employee_pending_request
//       (
//         tenant_id,
//         emp_id,

//         request_type,
//         admin_approve,

//         first_name,
//         mid_name,
//         last_name,

//         email_id,
//         phone_number,
//         date_of_birth,
//         gender,

//         designation_id,
//         role_id,

//         date_of_joining,
//         date_of_relieving,

//         employment_type,
//         work_type,

//         permanent_address,
//         communication_address,

//         aadhar_number,
//         pan_number,
//         passport_number,

//         father_name,

//         emergency_contact_relation,
//         emergency_contact,

//         pf_number,
//         esic_number,

//         years_experience,

//         username,
//         password,

//         edit_reason,

//         status,

//         created_at
//       )
//       VALUES
//       (
//         ?, ?,

//         ?, 'PENDING',

//         ?, ?, ?,

//         ?, ?, ?, ?,

//         ?, ?,

//         ?, ?,

//         ?, ?,

//         ?, ?,

//         ?, ?, ?,

//         ?,

//         ?, ?,

//         ?, ?,

//         ?, ?,

//         ?, ?,

//         ?,

//         'Active',

//         NOW()
//       )
//       `,
//       [
//         tenantId,
//         nullIfEmpty(emp_id),

//         request_type,

//         nullIfEmpty(first_name),
//         nullIfEmpty(mid_name),
//         nullIfEmpty(last_name),

//         nullIfEmpty(email_id),
//         nullIfEmpty(phone_number),
//         nullIfEmpty(date_of_birth),
//         nullIfEmpty(gender),

//         nullIfEmpty(designation_id),
//         nullIfEmpty(role_id),

//         nullIfEmpty(date_of_joining),
//         nullIfEmpty(date_of_relieving),

//         nullIfEmpty(employment_type),
//         nullIfEmpty(work_type),

//         nullIfEmpty(permanent_address),
//         nullIfEmpty(communication_address),

//         nullIfEmpty(aadhar_number),
//         nullIfEmpty(pan_number),
//         nullIfEmpty(passport_number),

//         nullIfEmpty(father_name),

//         nullIfEmpty(emergency_contact_relation),
//         nullIfEmpty(emergency_contact),

//         nullIfEmpty(pf_number),
//         nullIfEmpty(esic_number),

//         years_experience !== undefined ? parseInt(years_experience, 10) : null,

//         nullIfEmpty(username),
//         hashedPassword,

//         nullIfEmpty(edit_reason),
//       ],
//     );

//     const requestId = result.insertId;

//     // ─────────────────────────────────────────────────────────────────────────
//     // EDUCATION
//     // ─────────────────────────────────────────────────────────────────────────
//     if (Array.isArray(education) && education.length > 0) {
//       for (const edu of education) {
//         await conn.query(
//           `
//           INSERT INTO education_pending_request
//           (
//             request_id,
//             tenant_id,
//             emp_id,

//             education_level,
//             stream,
//             score,

//             year_of_passout,

//             university,
//             college_name,

//             action_type
//           )
//           VALUES
//           (
//             ?, ?, ?,

//             ?, ?, ?,

//             ?,

//             ?, ?,

//             'ADD'
//           )
//           `,
//           [
//             requestId,
//             tenantId,
//             nullIfEmpty(emp_id),

//             nullIfEmpty(edu.education_level),
//             nullIfEmpty(edu.stream),
//             nullIfEmpty(edu.score),

//             nullIfEmpty(edu.year_of_passout),

//             nullIfEmpty(edu.university),
//             nullIfEmpty(edu.college_name),
//           ],
//         );
//       }
//     }

//     await conn.commit();

//     return res.status(201).json({
//       success: true,
//       message:
//         request_type === "NEW"
//           ? "Employee request submitted."
//           : "Employee update request submitted.",
//       request_id: requestId,
//     });
//   } catch (err) {
//     await conn.rollback();

//     console.error("[POST /pending-request]", err);

//     if (err.code === "ER_DUP_ENTRY") {
//       return res.status(409).json({
//         success: false,
//         message: "Duplicate entry.",
//       });
//     }

//     return res.status(500).json({
//       success: false,
//       message: "Server error.",
//     });
//   } finally {
//     conn.release();
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // PHOTO UPLOAD
// // ─────────────────────────────────────────────────────────────────────────────
// router.post(
//   "/:id/photo",
//   requireAuth,
//   upload.single("photo"),
//   async (req, res) => {
//     const { tenantId } = req.user;
//     const { id } = req.params;

//     if (!req.file) {
//       return res.status(400).json({
//         success: false,
//         message: "No image provided.",
//       });
//     }

//     try {
//       const [result] = await db.query(
//         `
//         UPDATE employee_pending_request
//         SET
//           profile_photo = ?,
//           profile_photo_mime = ?
//         WHERE request_id = ?
//           AND tenant_id = ?
//         `,
//         [req.file.buffer, req.file.mimetype, id, tenantId],
//       );

//       if (result.affectedRows === 0) {
//         return res.status(404).json({
//           success: false,
//           message: "Request not found.",
//         });
//       }

//       return res.json({
//         success: true,
//         message: "Photo uploaded.",
//       });
//     } catch (err) {
//       console.error(err);

//       return res.status(500).json({
//         success: false,
//         message: "Server error.",
//       });
//     }
//   },
// );

// // ─────────────────────────────────────────────────────────────────────────────
// // GET PHOTO
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/:id/photo", requireAuth, async (req, res) => {
//   const { tenantId } = req.user;
//   const { id } = req.params;

//   try {
//     const [[row]] = await db.query(
//       `
//       SELECT
//         profile_photo,
//         profile_photo_mime
//       FROM employee_pending_request
//       WHERE request_id = ?
//         AND tenant_id = ?
//       LIMIT 1
//       `,
//       [id, tenantId],
//     );

//     if (!row || !row.profile_photo) {
//       return res.status(404).json({
//         success: false,
//         message: "Photo not found.",
//       });
//     }

//     res.set("Content-Type", row.profile_photo_mime || "image/jpeg");

//     res.send(row.profile_photo);
//   } catch (err) {
//     console.error(err);

//     return res.status(500).json({
//       success: false,
//       message: "Server error.",
//     });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // GET ALL REQUESTS
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/", requireAuth, async (req, res) => {
//   const { tenantId, roleId, empId } = req.user;

//   const isAdminOrHR = [1, 2].includes(roleId);

//   const { status, request_type } = req.query;

//   try {
//     const conditions = ["epr.tenant_id = ?"];
//     const params = [tenantId];

//     if (!isAdminOrHR) {
//       conditions.push("epr.emp_id = ?");
//       params.push(empId);
//     }

//     if (status) {
//       conditions.push("epr.admin_approve = ?");
//       params.push(status);
//     }

//     if (request_type) {
//       conditions.push("epr.request_type = ?");
//       params.push(request_type);
//     }

//     const where = conditions.join(" AND ");

//     const [rows] = await db.query(
//       `
//       SELECT
//         epr.*,

//         dm.designation_name,

//         dep.department_name,

//         r.role_name

//       FROM employee_pending_request epr

//       LEFT JOIN designation_master dm
//         ON dm.designation_id = epr.designation_id

//       LEFT JOIN department_master dep
//         ON dep.department_id = dm.department_id

//       LEFT JOIN role_master r
//         ON r.role_id = epr.role_id

//       WHERE ${where}

//       ORDER BY epr.created_at DESC
//       `,
//       params,
//     );

//     return res.json({
//       success: true,
//       count: rows.length,
//       data: rows,
//     });
//   } catch (err) {
//     console.error(err);

//     return res.status(500).json({
//       success: false,
//       message: "Server error.",
//     });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // GET SINGLE REQUEST
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/:id", requireAuth, async (req, res) => {
//   const { tenantId } = req.user;
//   const { id } = req.params;

//   try {
//     const [[row]] = await db.query(
//       `
//       SELECT
//         epr.*,

//         dm.designation_name,

//         dep.department_name,

//         r.role_name

//       FROM employee_pending_request epr

//       LEFT JOIN designation_master dm
//         ON dm.designation_id = epr.designation_id

//       LEFT JOIN department_master dep
//         ON dep.department_id = dm.department_id

//       LEFT JOIN role_master r
//         ON r.role_id = epr.role_id

//       WHERE epr.request_id = ?
//         AND epr.tenant_id = ?

//       LIMIT 1
//       `,
//       [id, tenantId],
//     );

//     if (!row) {
//       return res.status(404).json({
//         success: false,
//         message: "Request not found.",
//       });
//     }

//     const [eduRows] = await db.query(
//       `
//       SELECT *
//       FROM education_pending_request
//       WHERE request_id = ?
//       `,
//       [id],
//     );

//     row.education = eduRows;

//     return res.json({
//       success: true,
//       data: row,
//     });
//   } catch (err) {
//     console.error(err);

//     return res.status(500).json({
//       success: false,
//       message: "Server error.",
//     });
//   }
// });

// module.exports = router;
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

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.roleId)) {
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
    const [[designation]] = await conn.query(
      `SELECT dm.designation_id, dm.department_id, dm.designation_name,
              dep.department_name
         FROM designation_master dm
         INNER JOIN department_master dep ON dep.department_id = dm.department_id
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
  const { tenantId, roleId, empId } = req.user;
  const isAdminOrHR = [1, 2].includes(roleId);
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
