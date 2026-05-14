// const express = require("express");
// const bcrypt = require("bcryptjs"); // match server.js which uses bcryptjs
// const router = express.Router();
// const db = require("./config/db");

// // ─────────────────────────────────────────────────────────────────────────────
// // db helper that works with BOTH callback-style AND promise pools
// // server.js uses db.query(sql, params, callback) — callback style
// // So we wrap it the same way server.js does with dbQuery/dbAll
// // ─────────────────────────────────────────────────────────────────────────────
// const dbQuery = (sql, params = []) => {
//   return new Promise((resolve, reject) => {
//     db.query(sql, params, (err, result) => {
//       if (err) reject(err);
//       else resolve(result);
//     });
//   });
// };

// // For transactional queries we need a connection — get one from the pool
// // db.getConnection works on both mysql2 callback pools
// const getConn = () =>
//   new Promise((resolve, reject) => {
//     db.getConnection((err, conn) => {
//       if (err) reject(err);
//       else resolve(conn);
//     });
//   });

// const qConn = (conn, sql, params = []) =>
//   new Promise((resolve, reject) => {
//     conn.query(sql, params, (err, result) => {
//       if (err) reject(err);
//       else resolve(result);
//     });
//   });

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /employee-pending-request
// // Admin  (role_id == 2) → direct insert to employee_master
// // Others               → insert to employee_pending_request
// // ─────────────────────────────────────────────────────────────────────────────
// router.post("/employee-pending-request", async (req, res) => {
//   const user = req.user;
//   const isAdmin = String(user.role_id) === "2";
//   const tenantId = user.tenant_id;

//   const {
//     first_name, mid_name, last_name,
//     email_id, phone_number,
//     date_of_birth, gender,
//     department_id, role_id,
//     date_of_joining, employment_type, work_type,
//     permanent_address, communication_address,
//     aadhar_number, pan_number, passport_number,
//     father_name, emergency_contact_relation, emergency_contact,
//     pf_number, esic_number, years_experience,
//     username, password, tl_id,
//     education = [],
//   } = req.body;

//   if (
//     !first_name || !last_name || !email_id || !phone_number ||
//     !date_of_birth || !gender || !department_id || !role_id ||
//     !date_of_joining || !employment_type || !work_type ||
//     !permanent_address || !username || !password
//   ) {
//     return res.status(400).json({ success: false, message: "Missing required fields" });
//   }

//   const conn = await getConn();

//   const beginTx  = () => new Promise((res, rej) => conn.beginTransaction(e => e ? rej(e) : res()));
//   const commitTx = () => new Promise((res, rej) => conn.commit(e => e ? rej(e) : res()));
//   const rollback = () => new Promise((res) => conn.rollback(() => res()));

//   try {
//     await beginTx();
//     const hashedPassword = await bcrypt.hash(String(password), 10);

//     // ── ADMIN → employee_master ───────────────────────────────────────────
//     if (isAdmin) {
//       const empResult = await qConn(conn, `
//         INSERT INTO employee_master (
//           tenant_id, first_name, mid_name, last_name,
//           email_id, phone_number, date_of_birth, gender,
//           department_id, role_id, date_of_joining,
//           employment_type, work_type,
//           permanent_address, communication_address,
//           aadhar_number, pan_number, passport_number,
//           father_name, emergency_contact_relation, emergency_contact,
//           pf_number, esic_number, years_experience,
//           status, tl_id
//         ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'Active',?)
//       `, [
//         tenantId, first_name, mid_name || null, last_name,
//         email_id, phone_number, date_of_birth, gender,
//         department_id, role_id, date_of_joining,
//         employment_type, work_type,
//         permanent_address, communication_address || null,
//         aadhar_number || null, pan_number || null, passport_number || null,
//         father_name || null, emergency_contact_relation || null, emergency_contact || null,
//         pf_number || null, esic_number || null,
//         years_experience != null ? Number(years_experience) : null,
//         tl_id || null,
//       ]);

//       const empId = empResult.insertId;

//       // Insert login — use login_master to match server.js pattern
//       // First get company_code for this tenant
//       const tenantRows = await qConn(conn,
//         `SELECT company_code FROM tenants WHERE tenant_id = ? LIMIT 1`,
//         [tenantId]
//       );
//       const companyCode = tenantRows[0]?.company_code || null;

//       await qConn(conn, `
//         INSERT INTO login_master (tenant_id, company_id, emp_id, username, password, role_id, is_first_login, status, created_at)
//         VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())
//       `, [tenantId, companyCode, empId, username, hashedPassword, role_id]);

//       // Insert education_details
//       for (const edu of education) {
//         await qConn(conn, `
//           INSERT INTO education_details (
//             tenant_id, emp_id, education_level, stream, score,
//             year_of_passout, university, college_name
//           ) VALUES (?,?,?,?,?,?,?,?)
//         `, [
//           tenantId, empId,
//           edu.education_level,
//           edu.stream || null,
//           edu.score || null,
//           edu.year_of_passout || null,
//           edu.university || null,
//           edu.college_name || null,
//         ]);
//       }

//       await commitTx();
//       conn.release();
//       return res.json({
//         success: true,
//         message: "Employee added successfully.",
//         emp_id: empId,
//         request_id: null,
//       });
//     }

//     // ── NON-ADMIN → employee_pending_request ──────────────────────────────
//     const reqResult = await qConn(conn, `
//       INSERT INTO employee_pending_request (
//         tenant_id, first_name, mid_name, last_name,
//         email_id, phone_number, date_of_birth, gender,
//         department_id, role_id, date_of_joining,
//         employment_type, work_type,
//         permanent_address, communication_address,
//         aadhar_number, pan_number, passport_number,
//         father_name, emergency_contact_relation, emergency_contact,
//         pf_number, esic_number, years_experience,
//         username, password, request_type, admin_approve, tl_id
//       ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'NEW','PENDING',?)
//     `, [
//       tenantId, first_name, mid_name || null, last_name,
//       email_id, phone_number, date_of_birth, gender,
//       department_id, role_id, date_of_joining,
//       employment_type, work_type,
//       permanent_address, communication_address || null,
//       aadhar_number || null, pan_number || null, passport_number || null,
//       father_name || null, emergency_contact_relation || null, emergency_contact || null,
//       pf_number || null, esic_number || null,
//       years_experience != null ? Number(years_experience) : null,
//       username, hashedPassword,
//       tl_id || null,
//     ]);

//     const requestId = reqResult.insertId;

//     for (const edu of education) {
//       await qConn(conn, `
//         INSERT INTO education_pending_request (
//           tenant_id, request_id, emp_id,
//           education_level, stream, score,
//           year_of_passout, university, college_name, action_type
//         ) VALUES (?,?,0,?,?,?,?,?,?,'ADD')
//       `, [
//         tenantId, requestId,
//         edu.education_level,
//         edu.stream || null,
//         edu.score || null,
//         edu.year_of_passout || null,
//         edu.university || null,
//         edu.college_name || null,
//       ]);
//     }

//     await commitTx();
//     conn.release();
//     return res.json({
//       success: true,
//       message: "Employee request submitted for approval.",
//       request_id: requestId,
//     });

//   } catch (err) {
//     await rollback();
//     conn.release();
//     console.error("POST /employee-pending-request error:", err);

//     if (err.code === "ER_DUP_ENTRY") {
//       const field = err.message.includes("email")     ? "Email"
//                   : err.message.includes("phone")     ? "Phone number"
//                   : err.message.includes("aadhar")    ? "Aadhar number"
//                   : err.message.includes("pan")        ? "PAN number"
//                   : err.message.includes("passport")   ? "Passport number"
//                   : err.message.includes("username")   ? "Username"
//                   : "A field";
//       return res.status(409).json({ success: false, message: `${field} already exists.` });
//     }
//     return res.status(500).json({ success: false, message: "Server error.", error: err.message });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // Photo upload routes
// // ─────────────────────────────────────────────────────────────────────────────
// const multer = require("multer");
// const upload = multer({
//   storage: multer.memoryStorage(),
//   limits: { fileSize: 5 * 1024 * 1024 },
// });

// router.post("/pending-request/:requestId/photo", upload.single("photo"), async (req, res) => {
//   const { requestId } = req.params;
//   if (!req.file) return res.status(400).json({ success: false, message: "No photo uploaded" });
//   try {
//     await dbQuery(
//       `UPDATE employee_pending_request SET profile_photo=?, profile_photo_mime=? WHERE request_id=?`,
//       [req.file.buffer, req.file.mimetype, requestId]
//     );
//     res.json({ success: true });
//   } catch (err) {
//     console.error("Photo upload error:", err);
//     res.status(500).json({ success: false, message: "Failed to save photo" });
//   }
// });

// router.post("/employees/:empId/photo", upload.single("photo"), async (req, res) => {
//   const { empId } = req.params;
//   if (!req.file) return res.status(400).json({ success: false, message: "No photo uploaded" });
//   try {
//     await dbQuery(
//       `UPDATE employee_master SET profile_photo=?, profile_photo_mime=? WHERE emp_id=?`,
//       [req.file.buffer, req.file.mimetype, empId]
//     );
//     res.json({ success: true });
//   } catch (err) {
//     console.error("Photo upload error:", err);
//     res.status(500).json({ success: false, message: "Failed to save photo" });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /all-employees
// // Uses dbQuery (callback-style) to match how server.js uses db
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/all-employees", async (req, res) => {
//   const tenantId = req.user?.tenant_id;
//   try {
//     const rows = await dbQuery(
//       `SELECT * FROM (
//          SELECT
//            e.emp_id, e.first_name, e.mid_name, e.last_name,
//            e.email_id AS email, e.phone_number AS phone,
//            e.date_of_birth, e.gender,
//            e.department_id, d.department_name,
//            e.role_id, r.role_name,
//            e.date_of_joining, e.employment_type, e.work_type,
//            e.status AS emp_status,
//            e.tl_id,
//            NULL         AS admin_approve,
//            NULL         AS request_id,
//            'MASTER'     AS source,
//            e.created_at, e.updated_at
//          FROM employee_master e
//          LEFT JOIN department_master d ON e.department_id = d.department_id
//          LEFT JOIN role_master r       ON e.role_id       = r.role_id
//          WHERE e.tenant_id = ?

//          UNION ALL

//          SELECT
//            p.emp_id, p.first_name, p.mid_name, p.last_name,
//            p.email_id AS email, p.phone_number AS phone,
//            p.date_of_birth, p.gender,
//            p.department_id, d2.department_name,
//            p.role_id, r2.role_name,
//            p.date_of_joining, p.employment_type, p.work_type,
//            NULL         AS emp_status,
//            p.tl_id,
//            p.admin_approve,
//            p.request_id,
//            'PENDING'    AS source,
//            p.created_at, p.updated_at
//          FROM employee_pending_request p
//          LEFT JOIN department_master d2 ON p.department_id = d2.department_id
//          LEFT JOIN role_master r2       ON p.role_id       = r2.role_id
//          WHERE p.tenant_id = ?
//            AND p.admin_approve IN ('PENDING', 'REJECTED')
//        ) combined
//        ORDER BY created_at DESC`,
//       [tenantId, tenantId]
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     console.error("GET /all-employees error:", err);
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /team-leads
// // Returns all active employees whose role_name contains 'team lead'
// // If your role is named differently (e.g. 'TL'), change the LIKE below.
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/team-leads", async (req, res) => {
//   const tenantId = req.user?.tenant_id;
//   try {
//     const rows = await dbQuery(
//       `SELECT
//          em.emp_id AS id,
//          CONCAT(
//            em.first_name,
//            CASE WHEN em.mid_name IS NOT NULL AND em.mid_name != ''
//                 THEN CONCAT(' ', em.mid_name) ELSE '' END,
//            ' ', em.last_name
//          ) AS name
//        FROM employee_master em
//        JOIN role_master r ON em.role_id = r.role_id
//        WHERE em.tenant_id = ?
//          AND em.status    = 'Active'
//          AND LOWER(r.role_name) LIKE '%team lead%'
//        ORDER BY em.first_name, em.last_name`,
//       [tenantId]
//     );
//     return res.json({ success: true, data: rows });
//   } catch (err) {
//     console.error("GET /team-leads error:", err);
//     return res.status(500).json({
//       success: false,
//       message: "Failed to load team leads",
//       error: err.message,
//     });
//   }
// });

// module.exports = router;

const express = require("express");
const bcrypt = require("bcryptjs"); // match server.js which uses bcryptjs
const router = express.Router();
const db = require("./config/db");

// ─────────────────────────────────────────────────────────────────────────────
// db helper that works with BOTH callback-style AND promise pools
// server.js uses db.query(sql, params, callback) — callback style
// So we wrap it the same way server.js does with dbQuery/dbAll
// ─────────────────────────────────────────────────────────────────────────────
const dbQuery = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.query(sql, params, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
};

// For transactional queries we need a connection — get one from the pool
// db.getConnection works on both mysql2 callback pools
const getConn = () =>
  new Promise((resolve, reject) => {
    db.getConnection((err, conn) => {
      if (err) reject(err);
      else resolve(conn);
    });
  });

const qConn = (conn, sql, params = []) =>
  new Promise((resolve, reject) => {
    conn.query(sql, params, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// POST /employee-pending-request
// Admin  (role_id == 2) → direct insert to employee_master
// Others               → insert to employee_pending_request
// ─────────────────────────────────────────────────────────────────────────────
router.post("/employee-pending-request", async (req, res) => {
  const user = req.user;
  const isAdmin = String(user.role_id) === "2";
  const tenantId = user.tenant_id;

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
    username,
    password,
    tl_id,
    education = [],
  } = req.body;

  if (
    !first_name ||
    !last_name ||
    !email_id ||
    !phone_number ||
    !date_of_birth ||
    !gender ||
    !department_id ||
    !role_id ||
    !date_of_joining ||
    !employment_type ||
    !work_type ||
    !permanent_address ||
    !username ||
    !password
  ) {
    return res
      .status(400)
      .json({ success: false, message: "Missing required fields" });
  }

  const conn = await getConn();

  const beginTx = () =>
    new Promise((res, rej) =>
      conn.beginTransaction((e) => (e ? rej(e) : res())),
    );
  const commitTx = () =>
    new Promise((res, rej) => conn.commit((e) => (e ? rej(e) : res())));
  const rollback = () => new Promise((res) => conn.rollback(() => res()));

  try {
    await beginTx();
    const hashedPassword = await bcrypt.hash(String(password), 10);

    // ── ADMIN → employee_master ───────────────────────────────────────────
    if (isAdmin) {
      const empResult = await qConn(
        conn,
        `
            INSERT INTO employee_master (
            tenant_id, first_name, mid_name, last_name,
            email_id, phone_number, date_of_birth, gender,
            department_id, role_id, date_of_joining,
            employment_type, work_type,
            permanent_address, communication_address,
            aadhar_number, pan_number, passport_number,
            father_name, emergency_contact_relation, emergency_contact,
            pf_number, esic_number, years_experience,
            status, tl_id
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'Active',?)
        `,
        [
          tenantId,
          first_name,
          mid_name || null,
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
          communication_address || null,
          aadhar_number || null,
          pan_number || null,
          passport_number || null,
          father_name || null,
          emergency_contact_relation || null,
          emergency_contact || null,
          pf_number || null,
          esic_number || null,
          years_experience != null ? Number(years_experience) : null,
          tl_id || null,
        ],
      );

      const empId = empResult.insertId;

      // Insert login — use login_master to match server.js pattern
      // First get company_code for this tenant
      const tenantRows = await qConn(
        conn,
        `SELECT company_code FROM tenants WHERE tenant_id = ? LIMIT 1`,
        [tenantId],
      );
      const companyCode = tenantRows[0]?.company_code || null;

      await qConn(
        conn,
        `
            INSERT INTO login_master (tenant_id, company_id, emp_id, username, password, role_id, is_first_login, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())
        `,
        [tenantId, companyCode, empId, username, hashedPassword, role_id],
      );

      // Insert education_details
      for (const edu of education) {
        await qConn(
          conn,
          `
            INSERT INTO education_details (
                tenant_id, emp_id, education_level, stream, score,
                year_of_passout, university, college_name
            ) VALUES (?,?,?,?,?,?,?,?)
            `,
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

      await commitTx();
      conn.release();
      return res.json({
        success: true,
        message: "Employee added successfully.",
        emp_id: empId,
        request_id: null,
      });
    }

    // ── NON-ADMIN → employee_pending_request ──────────────────────────────
    const reqResult = await qConn(
      conn,
      `
        INSERT INTO employee_pending_request (
            tenant_id, first_name, mid_name, last_name,
            email_id, phone_number, date_of_birth, gender,
            department_id, role_id, date_of_joining,
            employment_type, work_type,
            permanent_address, communication_address,
            aadhar_number, pan_number, passport_number,
            father_name, emergency_contact_relation, emergency_contact,
            pf_number, esic_number, years_experience,
            username, password, request_type, admin_approve, tl_id
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'NEW','PENDING',?)
        `,
      [
        tenantId,
        first_name,
        mid_name || null,
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
        communication_address || null,
        aadhar_number || null,
        pan_number || null,
        passport_number || null,
        father_name || null,
        emergency_contact_relation || null,
        emergency_contact || null,
        pf_number || null,
        esic_number || null,
        years_experience != null ? Number(years_experience) : null,
        username,
        hashedPassword,
        tl_id || null,
      ],
    );

    const requestId = reqResult.insertId;

    for (const edu of education) {
      await qConn(
        conn,
        `
            INSERT INTO education_pending_request (
            tenant_id, request_id, emp_id,
            education_level, stream, score,
            year_of_passout, university, college_name, action_type
            ) VALUES (?,?,0,?,?,?,?,?,?,'ADD')
        `,
        [
          tenantId,
          requestId,
          edu.education_level,
          edu.stream || null,
          edu.score || null,
          edu.year_of_passout || null,
          edu.university || null,
          edu.college_name || null,
        ],
      );
    }

    await commitTx();
    conn.release();
    return res.json({
      success: true,
      message: "Employee request submitted for approval.",
      request_id: requestId,
    });
  } catch (err) {
    await rollback();
    conn.release();
    console.error("POST /employee-pending-request error:", err);

    if (err.code === "ER_DUP_ENTRY") {
      const field = err.message.includes("email")
        ? "Email"
        : err.message.includes("phone")
          ? "Phone number"
          : err.message.includes("aadhar")
            ? "Aadhar number"
            : err.message.includes("pan")
              ? "PAN number"
              : err.message.includes("passport")
                ? "Passport number"
                : err.message.includes("username")
                  ? "Username"
                  : "A field";
      return res
        .status(409)
        .json({ success: false, message: `${field} already exists.` });
    }
    return res
      .status(500)
      .json({ success: false, message: "Server error.", error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Photo upload routes
// ─────────────────────────────────────────────────────────────────────────────
const multer = require("multer");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});

router.post(
  "/pending-request/:requestId/photo",
  upload.single("photo"),
  async (req, res) => {
    const { requestId } = req.params;
    if (!req.file)
      return res
        .status(400)
        .json({ success: false, message: "No photo uploaded" });
    try {
      await dbQuery(
        `UPDATE employee_pending_request SET profile_photo=?, profile_photo_mime=? WHERE request_id=?`,
        [req.file.buffer, req.file.mimetype, requestId],
      );
      res.json({ success: true });
    } catch (err) {
      console.error("Photo upload error:", err);
      res.status(500).json({ success: false, message: "Failed to save photo" });
    }
  },
);

router.post(
  "/employees/:empId/photo",
  upload.single("photo"),
  async (req, res) => {
    const { empId } = req.params;
    if (!req.file)
      return res
        .status(400)
        .json({ success: false, message: "No photo uploaded" });
    try {
      await dbQuery(
        `UPDATE employee_master SET profile_photo=?, profile_photo_mime=? WHERE emp_id=?`,
        [req.file.buffer, req.file.mimetype, empId],
      );
      res.json({ success: true });
    } catch (err) {
      console.error("Photo upload error:", err);
      res.status(500).json({ success: false, message: "Failed to save photo" });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GET /all-employees
// Uses dbQuery (callback-style) to match how server.js uses db
// ─────────────────────────────────────────────────────────────────────────────
router.get("/all-employees", async (req, res) => {
  // ── Guard: auth middleware must have set req.user ─────────────────────────
  if (!req.user?.tenant_id) {
    return res
      .status(401)
      .json({ success: false, message: "Unauthorized — no tenant context" });
  }

  const tenantId = req.user.tenant_id;

  try {
    const rows = await dbQuery(
      `SELECT * FROM (
            SELECT
            e.emp_id,
            CONVERT(e.first_name   USING utf8mb4) COLLATE utf8mb4_general_ci AS first_name,
            CONVERT(e.mid_name     USING utf8mb4) COLLATE utf8mb4_general_ci AS mid_name,
            CONVERT(e.last_name    USING utf8mb4) COLLATE utf8mb4_general_ci AS last_name,
            CONVERT(e.email_id     USING utf8mb4) COLLATE utf8mb4_general_ci AS email,
            CONVERT(e.phone_number USING utf8mb4) COLLATE utf8mb4_general_ci AS phone,
            e.date_of_birth, CONVERT(e.gender USING utf8mb4) COLLATE utf8mb4_general_ci AS gender,
            e.department_id,
            CONVERT(d.department_name USING utf8mb4) COLLATE utf8mb4_general_ci AS department_name,
            e.role_id,
            CONVERT(r.role_name USING utf8mb4) COLLATE utf8mb4_general_ci AS role_name,
            e.date_of_joining, CONVERT(e.employment_type USING utf8mb4) COLLATE utf8mb4_general_ci AS employment_type,
CONVERT(e.work_type USING utf8mb4) COLLATE utf8mb4_general_ci AS work_type,
            CONVERT(e.status USING utf8mb4) COLLATE utf8mb4_general_ci AS emp_status,
            e.tl_id,
            CAST(NULL AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci AS admin_approve,
            NULL  AS request_id,
            CONVERT('MASTER' USING utf8mb4) COLLATE utf8mb4_general_ci AS source,
            e.created_at, e.updated_at
            FROM employee_master e
            LEFT JOIN department_master d ON e.department_id = d.department_id
            LEFT JOIN role_master r       ON e.role_id       = r.role_id
            WHERE e.tenant_id = ?
    
            UNION ALL
    
            SELECT
            p.emp_id,
            CONVERT(p.first_name   USING utf8mb4) COLLATE utf8mb4_general_ci AS first_name,
            CONVERT(p.mid_name     USING utf8mb4) COLLATE utf8mb4_general_ci AS mid_name,
            CONVERT(p.last_name    USING utf8mb4) COLLATE utf8mb4_general_ci AS last_name,
            CONVERT(p.email_id     USING utf8mb4) COLLATE utf8mb4_general_ci AS email,
            CONVERT(p.phone_number USING utf8mb4) COLLATE utf8mb4_general_ci AS phone,
            p.date_of_birth, CONVERT(p.gender USING utf8mb4) COLLATE utf8mb4_general_ci AS gender,
            p.department_id,
            CONVERT(d2.department_name USING utf8mb4) COLLATE utf8mb4_general_ci AS department_name,
            p.role_id,
            CONVERT(r2.role_name USING utf8mb4) COLLATE utf8mb4_general_ci AS role_name,
            p.date_of_joining, CONVERT(p.employment_type USING utf8mb4) COLLATE utf8mb4_general_ci AS employment_type,
CONVERT(p.work_type USING utf8mb4) COLLATE utf8mb4_general_ci AS work_type,
            CAST(NULL AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci AS emp_status,
            p.tl_id,
            CONVERT(p.admin_approve USING utf8mb4) COLLATE utf8mb4_general_ci AS admin_approve,
            p.request_id,
            CONVERT('PENDING' USING utf8mb4) COLLATE utf8mb4_general_ci AS source,
            p.created_at, p.updated_at
            FROM employee_pending_request p
            LEFT JOIN department_master d2 ON p.department_id = d2.department_id
            LEFT JOIN role_master r2       ON p.role_id       = r2.role_id
            WHERE p.tenant_id = ?
            AND p.admin_approve IN ('PENDING', 'REJECTED')
        ) combined
        ORDER BY created_at DESC`,
      [tenantId, tenantId],
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("GET /all-employees error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /team-leads
// Returns all active employees whose role_name contains 'team lead'
// If your role is named differently (e.g. 'TL'), change the LIKE below.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/team-leads", async (req, res) => {
  const tenantId = req.user?.tenant_id;
  try {
    const rows = await dbQuery(
      `SELECT
            em.emp_id AS id,
            CONCAT(
            em.first_name,
            CASE WHEN em.mid_name IS NOT NULL AND em.mid_name != ''
                    THEN CONCAT(' ', em.mid_name) ELSE '' END,
            ' ', em.last_name
            ) AS name
        FROM employee_master em
        JOIN role_master r ON em.role_id = r.role_id
        WHERE em.tenant_id = ?
            AND em.status    = 'Active'
            AND LOWER(r.role_name) LIKE '%team lead%'
        ORDER BY em.first_name, em.last_name`,
      [tenantId],
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error("GET /team-leads error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to load team leads",
      error: err.message,
    });
  }
});

module.exports = router;
