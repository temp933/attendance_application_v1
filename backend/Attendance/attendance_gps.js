// const express = require("express");
// const router = express.Router();
// const db = require("../config/db");
// const authMiddleware = require("../middleware/auth");
// const { generateCompOff } = require("./comp-off");

// // ─────────────────────────────────────────────────────────────────────────────
// // Auth
// // ─────────────────────────────────────────────────────────────────────────────
// function requireAuth(req, res, next) {
//   authMiddleware(req, res, () => {
//     if (!req.user) {
//       return res.status(401).json({ success: false, message: "Unauthorized." });
//     }
//     req.user.tenantId = req.user.tenant_id ?? req.headers["x-tenant-id"];
//     req.user.empId = req.user.emp_id ?? req.headers["x-employee-id"];
//     next();
//   });
// }

// // Admin-only middleware (role_id check — adjust role IDs to match your system)
// function requireAdmin(req, res, next) {
//   if (!req.user || ![1, 2, 3].includes(req.user.role_id)) {
//     return res.status(403).json({ success: false, message: "Forbidden." });
//   }
//   next();
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Helpers — IST (UTC+5:30)
// // ─────────────────────────────────────────────────────────────────────────────
// // ─────────────────────────────────────────────────────────────────────────────
// // Helpers — IST
// // ─────────────────────────────────────────────────────────────────────────────

// function getISTDate() {
//   return new Date(
//     new Date().toLocaleString("en-US", {
//       timeZone: "Asia/Kolkata",
//     }),
//   );
// }

// function nowDatetime() {
//   const d = getISTDate();

//   const yyyy = d.getFullYear();
//   const mm = String(d.getMonth() + 1).padStart(2, "0");
//   const dd = String(d.getDate()).padStart(2, "0");

//   const hh = String(d.getHours()).padStart(2, "0");
//   const mi = String(d.getMinutes()).padStart(2, "0");
//   const ss = String(d.getSeconds()).padStart(2, "0");

//   return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
// }

// function todayDate() {
//   return nowDatetime().split(" ")[0];
// }

// function toISTStr(date) {
//   if (!date) return null;

//   const d = new Date(date);

//   const yyyy = d.getFullYear();
//   const mm = String(d.getMonth() + 1).padStart(2, "0");
//   const dd = String(d.getDate()).padStart(2, "0");

//   const hh = String(d.getHours()).padStart(2, "0");
//   const mi = String(d.getMinutes()).padStart(2, "0");
//   const ss = String(d.getSeconds()).padStart(2, "0");

//   return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
// }
// function normalizeRecord(r) {
//   if (!r) return r;
//   r.checkin_time = toISTStr(r.checkin_time);
//   r.checkout_time = toISTStr(r.checkout_time);
//   if (r.work_date instanceof Date) {
//     r.work_date = toISTStr(r.work_date).slice(0, 10);
//   }
//   return r;
// }

// function timeToMinutes(timeStr) {
//   if (!timeStr) return 0;
//   const parts = timeStr.split(":").map(Number);
//   return parts[0] * 60 + parts[1];
// }

// function calcLateMinutes(checkinDatetime, officeInTime) {
//   const [, timePart] = checkinDatetime.split(" ");
//   return timeToMinutes(timePart) - timeToMinutes(officeInTime);
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Fetch policy
// // ─────────────────────────────────────────────────────────────────────────────
// async function getPolicy(tenantId) {
//   const [[policy]] = await db.query(
//     `SELECT
//         office_in_time,
//         office_out_time,
//         late_after_minutes,
//         halfday_after_minutes,
//         overtime_after_minutes,
//         multiple_in_out_allowed,
//         auto_checkout_enabled
//      FROM attendance_policy
//      WHERE tenant_id = ?
//      LIMIT 1`,
//     [tenantId],
//   );
//   return policy ?? null;
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/gps/today  — fetch today's record + policy
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/today", requireAuth, async (req, res) => {
//   const { tenantId, empId } = req.user;
//   try {
//     const [[record]] = await db.query(
//       `SELECT
//           attendance_id,
//           attendance_mode,
//           checkin_time,
//           checkout_time,
//           work_date,
//           status,
//           checkin_latitude,
//           checkin_longitude,
//           checkout_latitude,
//           checkout_longitude,
//           is_late,
//           late_minutes,
//           total_work_time
//        FROM employee_attendance
//        WHERE tenant_id  = ?
//          AND employee_id = ?
//          AND work_date   = ?
//          AND attendance_mode = 'gps'
//        ORDER BY attendance_id DESC
//        LIMIT 1`,
//       [tenantId, empId, todayDate()],
//     );

//     const policy = await getPolicy(tenantId);
//     res.json({
//       success: true,
//       record: normalizeRecord(record) ?? null,
//       policy,
//     });
//   } catch (err) {
//     console.error("[GET /gps/today]", err);
//     res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/gps/checkin
// // ─────────────────────────────────────────────────────────────────────────────
// router.post("/checkin", requireAuth, async (req, res) => {
//   const { tenantId, empId } = req.user;
//   try {
//     const [[existing]] = await db.query(
//       `SELECT attendance_id, status
//        FROM employee_attendance
//        WHERE tenant_id  = ?
//          AND employee_id = ?
//          AND work_date   = ?
//        ORDER BY attendance_id DESC
//        LIMIT 1`,
//       [tenantId, empId, todayDate()],
//     );

//     if (existing?.status === "active") {
//       return res.status(409).json({
//         success: false,
//         message: "Already checked in. Please check out first.",
//       });
//     }

//     const policy = await getPolicy(tenantId);

//     if (
//       existing?.status === "completed" &&
//       policy &&
//       !policy.multiple_in_out_allowed
//     ) {
//       return res.status(409).json({
//         success: false,
//         message:
//           "Multiple check-ins per day are not allowed by your company policy.",
//       });
//     }

//     const { latitude = null, longitude = null } = req.body;

//     if (latitude === null || longitude === null) {
//       return res.status(400).json({
//         success: false,
//         message: "Location is required for GPS check-in.",
//       });
//     }

//     const checkinDatetime = nowDatetime();
//     let isLate = 0;
//     let lateMinutes = 0;

//     if (!existing && policy?.office_in_time) {
//       const diffMinutes = calcLateMinutes(
//         checkinDatetime,
//         policy.office_in_time,
//       );
//       const threshold = policy.late_after_minutes ?? 0;
//       if (diffMinutes > threshold) {
//         isLate = 1;
//         lateMinutes = diffMinutes;
//       }
//     }

//     const [result] = await db.query(
//       `INSERT INTO employee_attendance
//           (tenant_id, employee_id, attendance_mode,
//            checkin_time, work_date, status,
//            checkin_latitude, checkin_longitude,
//            is_late, late_minutes)
//        VALUES (?, ?, 'gps', ?, ?, 'active', ?, ?, ?, ?)`,
//       [
//         tenantId,
//         empId,
//         checkinDatetime,
//         todayDate(),
//         latitude,
//         longitude,
//         isLate,
//         lateMinutes,
//       ],
//     );

//     const [[record]] = await db.query(
//       `SELECT
//           attendance_id, attendance_mode,
//           checkin_time, checkout_time,
//           work_date, status,
//           checkin_latitude, checkin_longitude,
//           is_late, late_minutes, total_work_time
//        FROM employee_attendance
//        WHERE attendance_id = ?`,
//       [result.insertId],
//     );

//     res.status(201).json({
//       success: true,
//       message: "Checked in successfully.",
//       record: normalizeRecord(record),
//       policy,
//       is_late: isLate === 1,
//       late_minutes: lateMinutes,
//     });
//   } catch (err) {
//     console.error("[POST /gps/checkin]", err);
//     res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/gps/checkout
// // ─────────────────────────────────────────────────────────────────────────────
// router.post("/checkout", requireAuth, async (req, res) => {
//   const { tenantId, empId } = req.user;
//   try {
//     const [[active]] = await db.query(
//       `SELECT attendance_id
//        FROM employee_attendance
//        WHERE tenant_id  = ?
//          AND employee_id = ?
//          AND work_date   = ?
//          AND status      = 'active'
//        ORDER BY attendance_id DESC
//        LIMIT 1`,
//       [tenantId, empId, todayDate()],
//     );

//     if (!active) {
//       return res.status(404).json({
//         success: false,
//         message: "No active check-in found for today.",
//       });
//     }

//     const { latitude = null, longitude = null } = req.body;

//     if (latitude === null || longitude === null) {
//       return res.status(400).json({
//         success: false,
//         message: "Location is required for GPS check-out.",
//       });
//     }

//     const checkoutDatetime = nowDatetime();
//     await db.query(
//       `UPDATE employee_attendance
//        SET checkout_time      = ?,
//            status             = 'completed',
//            checkout_latitude  = ?,
//            checkout_longitude = ?
//        WHERE attendance_id = ?`,
//       [checkoutDatetime, latitude, longitude, active.attendance_id],
//     );

//     const [[record]] = await db.query(
//       `SELECT
//           attendance_id, attendance_mode,
//           checkin_time, checkout_time,
//           work_date, status,
//           checkin_latitude, checkin_longitude,
//           checkout_latitude, checkout_longitude,
//           is_late, late_minutes, total_work_time
//        FROM employee_attendance
//        WHERE attendance_id = ?`,
//       [active.attendance_id],
//     );

//     generateCompOff(tenantId, active.attendance_id).catch((err) =>
//       console.error("[CompOff] generateCompOff failed after checkout:", err),
//     );

//     const compOffResult = await generateCompOff(
//       tenantId,
//       active.attendance_id,
//     ).catch((err) => {
//       console.error("[CompOff] generateCompOff failed:", err);
//       return null;
//     });
//     res.json({
//       success: true,
//       message: "Checked out successfully.",
//       record: normalizeRecord(record),
//       comp_off: compOffResult ?? undefined,
//     });
//   } catch (err) {
//     console.error("[POST /gps/checkout]", err);
//     res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // PATCH /api/gps/update-location
// // ─────────────────────────────────────────────────────────────────────────────
// router.patch("/update-location", requireAuth, async (req, res) => {
//   const { tenantId, empId } = req.user;
//   try {
//     const [[active]] = await db.query(
//       `SELECT attendance_id
//        FROM employee_attendance
//        WHERE tenant_id  = ?
//          AND employee_id = ?
//          AND work_date   = ?
//          AND status      = 'active'
//        ORDER BY attendance_id DESC
//        LIMIT 1`,
//       [tenantId, empId, todayDate()],
//     );

//     if (!active) {
//       return res.json({ success: true, active: false });
//     }

//     const { latitude, longitude } = req.body;

//     if (
//       latitude === null ||
//       latitude === undefined ||
//       longitude === null ||
//       longitude === undefined
//     ) {
//       return res.status(400).json({
//         success: false,
//         message: "latitude and longitude are required.",
//       });
//     }

//     await db.query(
//       `UPDATE employee_attendance
//        SET checkin_latitude  = ?,
//            checkin_longitude = ?
//        WHERE attendance_id = ?`,
//       [latitude, longitude, active.attendance_id],
//     );

//     res.json({
//       success: true,
//       active: true,
//       message: "Location updated.",
//       attendance_id: active.attendance_id,
//     });
//   } catch (err) {
//     console.error("[PATCH /gps/update-location]", err);
//     res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/gps/history?limit=7&offset=0
// // ─────────────────────────────────────────────────────────────────────────────
// router.get("/history", requireAuth, async (req, res) => {
//   const { tenantId, empId } = req.user;
//   try {
//     const limit = Math.min(Number(req.query.limit ?? 7), 100);
//     const offset = Number(req.query.offset ?? 0);

//     const [records] = await db.query(
//       `SELECT
//           attendance_id,
//           work_date,
//           checkin_time,
//           checkout_time,
//           status,
//           total_work_time,
//           is_late,
//           late_minutes,
//           checkin_latitude,
//           checkin_longitude,
//           checkout_latitude,
//           checkout_longitude,
//           attendance_mode
//        FROM employee_attendance
//        WHERE tenant_id   = ?
//          AND employee_id = ?
//          AND attendance_mode = 'gps'
//          AND work_date = ?
//        ORDER BY attendance_id DESC
//        LIMIT ? OFFSET ?`,
//       [tenantId, empId, todayDate(), limit, offset],
//     );

//     res.json({ success: true, records: records.map(normalizeRecord) });
//   } catch (err) {
//     console.error("[GET /gps/history]", err);
//     res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// router.get("/admin/all", requireAuth, requireAdmin, async (req, res) => {
//   const { tenantId } = req.user;
//   try {
//     const date = req.query.date || todayDate();
//     const status = req.query.status || "";
//     const search = (req.query.search || "").trim();
//     const limit = Math.min(Number(req.query.limit ?? 50), 200);
//     const offset = Number(req.query.offset ?? 0);

//     // ── Build dynamic WHERE clauses ──────────────────────────────────────────
//     const whereClauses = [
//       "ea.tenant_id = ?",
//       "ea.attendance_mode = 'gps'",
//       "ea.work_date = ?",
//     ];
//     const params = [tenantId, date];

//     if (status) {
//       whereClauses.push("ea.status = ?");
//       params.push(status);
//     }

//     if (search) {
//       whereClauses.push(
//         "(CONCAT_WS(' ', e.first_name, e.last_name) LIKE ? OR CAST(ea.employee_id AS CHAR) LIKE ?)",
//       );
//       params.push(`%${search}%`, `%${search}%`);
//     }

//     const whereStr = whereClauses.join(" AND ");

//     // ── Fetch records (joined with employees for name + department) ──────────
//     // In GET /api/gps/admin/all, replace the records query with:

//     const [records] = await db.query(
//       `SELECT
//       ea.attendance_id,
//       ea.employee_id,
//       COALESCE(
//         CONCAT_WS(' ', e.first_name, NULLIF(e.mid_name,''), e.last_name),
//         CONCAT('Employee #', ea.employee_id)
//       )                    AS employee_name,
//       d.department_name    AS department,
//       ea.work_date,
//       ea.checkin_time,
//       ea.checkout_time,
//       ea.status,
//       ea.total_work_time,
//       ea.is_late,
//       ea.late_minutes,
//       ea.checkin_latitude,
//       ea.checkin_longitude,
//       ea.checkout_latitude,
//       ea.checkout_longitude,
//       ea.attendance_mode
//    FROM employee_attendance ea
//    LEFT JOIN employee_master   e ON e.emp_id     = ea.employee_id
//                                 AND CONVERT(e.tenant_id   USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
//                                   = CONVERT(ea.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
//    LEFT JOIN department_master d ON d.department_id = e.department_id
//                                 AND CONVERT(d.tenant_id   USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
//                                   = CONVERT(ea.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
//    WHERE ${whereStr}
//    ORDER BY ea.employee_id ASC, ea.attendance_id ASC
//    LIMIT ? OFFSET ?`,
//       [...params, limit, offset],
//     );

//     // ── Stats query (always for the full date, no status/search filter) ──────
//     const [[statsRow]] = await db.query(
//       `SELECT
//           /* distinct employees on GPS attendance today */
//           COUNT(DISTINCT ea.employee_id)                                      AS present_today,
//           COUNT(DISTINCT CASE WHEN ea.is_late  = 1
//                               THEN ea.employee_id END)                        AS late_today,
//           COUNT(DISTINCT CASE WHEN ea.status   = 'active'
//                               THEN ea.employee_id END)                        AS active_now
//        FROM employee_attendance ea
//        WHERE ea.tenant_id      = ?
//          AND ea.attendance_mode = 'gps'
//          AND ea.work_date       = ?`,
//       [tenantId, date],
//     );

//     // Total GPS-enabled employees for this tenant
//     // Replace the total_employees query with:
//     const [[{ total_employees }]] = await db.query(
//       `SELECT COUNT(*) AS total_employees
//    FROM employee_master
//    WHERE CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
//      AND status = 'Active'`,
//       [tenantId],
//     );

//     res.json({
//       success: true,
//       records: records.map(normalizeRecord),
//       stats: {
//         total_employees: Number(total_employees ?? 0),
//         present_today: Number(statsRow.present_today ?? 0),
//         late_today: Number(statsRow.late_today ?? 0),
//         active_now: Number(statsRow.active_now ?? 0),
//       },
//     });
//   } catch (err) {
//     console.error("[GET /gps/admin/all]", err);
//     res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// module.exports = router;

const express = require("express");
const router = express.Router();
const db = require("../config/db");
const authMiddleware = require("../middleware/auth");
const { generateCompOff } = require("./comp-off");

// ─────────────────────────────────────────────────────────────────────────────
// Auth
// ─────────────────────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  authMiddleware(req, res, () => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized." });
    }
    req.user.tenantId = req.user.tenant_id ?? req.headers["x-tenant-id"];
    req.user.empId = req.user.emp_id ?? req.headers["x-employee-id"];
    next();
  });
}

function requireAdmin(req, res, next) {
  if (!req.user || ![1, 2, 3].includes(req.user.role_id)) {
    return res.status(403).json({ success: false, message: "Forbidden." });
  }
  next();
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — IST (UTC+5:30)
// ─────────────────────────────────────────────────────────────────────────────
function getISTDate() {
  return new Date(
    new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }),
  );
}

function nowDatetime() {
  const d = getISTDate();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  const ss = String(d.getSeconds()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
}

function todayDate() {
  return nowDatetime().split(" ")[0];
}

function toISTStr(date) {
  if (!date) return null;
  const d = new Date(date);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  const ss = String(d.getSeconds()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
}

function normalizeRecord(r) {
  if (!r) return r;
  r.checkin_time = toISTStr(r.checkin_time);
  r.checkout_time = toISTStr(r.checkout_time);
  if (r.work_date instanceof Date) {
    r.work_date = toISTStr(r.work_date).slice(0, 10);
  }
  return r;
}

function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const parts = timeStr.split(":").map(Number);
  return parts[0] * 60 + parts[1];
}

function calcLateMinutes(checkinDatetime, officeInTime) {
  const [, timePart] = checkinDatetime.split(" ");
  return timeToMinutes(timePart) - timeToMinutes(officeInTime);
}

// ─────────────────────────────────────────────────────────────────────────────
// Fetch policy
// ─────────────────────────────────────────────────────────────────────────────
async function getPolicy(tenantId) {
  const [[policy]] = await db.query(
    `SELECT
        office_in_time,
        office_out_time,
        late_after_minutes,
        halfday_after_minutes,
        overtime_after_minutes,
        multiple_in_out_allowed,
        auto_checkout_enabled
     FROM attendance_policy
     WHERE tenant_id = ?
     LIMIT 1`,
    [tenantId],
  );
  return policy ?? null;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/gps/today
// ─────────────────────────────────────────────────────────────────────────────
router.get("/today", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [[record]] = await db.query(
      `SELECT
          attendance_id,
          attendance_mode,
          checkin_time,
          checkout_time,
          work_date,
          status,
          checkin_latitude,
          checkin_longitude,
          checkout_latitude,
          checkout_longitude,
          is_late,
          late_minutes,
          total_work_time
       FROM employee_attendance
       WHERE tenant_id     = ?
         AND employee_id   = ?
         AND work_date     = ?
         AND attendance_mode = 'gps'
       ORDER BY attendance_id DESC
       LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    const policy = await getPolicy(tenantId);
    res.json({
      success: true,
      record: normalizeRecord(record) ?? null,
      policy,
    });
  } catch (err) {
    console.error("[GET /gps/today]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/gps/checkin
// ─────────────────────────────────────────────────────────────────────────────
router.post("/checkin", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [[existing]] = await db.query(
      `SELECT attendance_id, status
       FROM employee_attendance
       WHERE tenant_id   = ?
         AND employee_id = ?
         AND work_date   = ?
       ORDER BY attendance_id DESC
       LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    if (existing?.status === "active") {
      return res.status(409).json({
        success: false,
        message: "Already checked in. Please check out first.",
      });
    }

    const policy = await getPolicy(tenantId);

    if (
      existing?.status === "completed" &&
      policy &&
      !policy.multiple_in_out_allowed
    ) {
      return res.status(409).json({
        success: false,
        message:
          "Multiple check-ins per day are not allowed by your company policy.",
      });
    }

    const { latitude = null, longitude = null } = req.body;

    if (latitude === null || longitude === null) {
      return res.status(400).json({
        success: false,
        message: "Location is required for GPS check-in.",
      });
    }

    const checkinDatetime = nowDatetime();
    let isLate = 0;
    let lateMinutes = 0;

    if (!existing && policy?.office_in_time) {
      const diffMinutes = calcLateMinutes(
        checkinDatetime,
        policy.office_in_time,
      );
      const threshold = policy.late_after_minutes ?? 0;
      if (diffMinutes > threshold) {
        isLate = 1;
        lateMinutes = diffMinutes;
      }
    }

    const [result] = await db.query(
      `INSERT INTO employee_attendance
          (tenant_id, employee_id, attendance_mode,
           checkin_time, work_date, status,
           checkin_latitude, checkin_longitude,
           is_late, late_minutes)
       VALUES (?, ?, 'gps', ?, ?, 'active', ?, ?, ?, ?)`,
      [
        tenantId,
        empId,
        checkinDatetime,
        todayDate(),
        latitude,
        longitude,
        isLate,
        lateMinutes,
      ],
    );

    const [[record]] = await db.query(
      `SELECT
          attendance_id, attendance_mode,
          checkin_time, checkout_time,
          work_date, status,
          checkin_latitude, checkin_longitude,
          is_late, late_minutes, total_work_time
       FROM employee_attendance
       WHERE attendance_id = ?`,
      [result.insertId],
    );

    res.status(201).json({
      success: true,
      message: "Checked in successfully.",
      record: normalizeRecord(record),
      policy,
      is_late: isLate === 1,
      late_minutes: lateMinutes,
    });
  } catch (err) {
    console.error("[POST /gps/checkin]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/gps/checkout
// ─────────────────────────────────────────────────────────────────────────────
router.post("/checkout", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [[active]] = await db.query(
      `SELECT attendance_id
       FROM employee_attendance
       WHERE tenant_id   = ?
         AND employee_id = ?
         AND work_date   = ?
         AND status      = 'active'
       ORDER BY attendance_id DESC
       LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    if (!active) {
      return res.status(404).json({
        success: false,
        message: "No active check-in found for today.",
      });
    }

    const { latitude = null, longitude = null } = req.body;

    if (latitude === null || longitude === null) {
      return res.status(400).json({
        success: false,
        message: "Location is required for GPS check-out.",
      });
    }

    const checkoutDatetime = nowDatetime();
    await db.query(
      `UPDATE employee_attendance
       SET checkout_time      = ?,
           status             = 'completed',
           checkout_latitude  = ?,
           checkout_longitude = ?
       WHERE attendance_id = ?`,
      [checkoutDatetime, latitude, longitude, active.attendance_id],
    );

    const [[record]] = await db.query(
      `SELECT
          attendance_id, attendance_mode,
          checkin_time, checkout_time,
          work_date, status,
          checkin_latitude, checkin_longitude,
          checkout_latitude, checkout_longitude,
          is_late, late_minutes, total_work_time
       FROM employee_attendance
       WHERE attendance_id = ?`,
      [active.attendance_id],
    );

    // FIX: was calling generateCompOff twice — now called once, result returned
    const compOffResult = await generateCompOff(
      tenantId,
      active.attendance_id,
    ).catch((err) => {
      console.error(
        "[CompOff] generateCompOff failed after gps checkout:",
        err,
      );
      return null;
    });

    res.json({
      success: true,
      message: "Checked out successfully.",
      record: normalizeRecord(record),
      comp_off: compOffResult ?? undefined,
    });
  } catch (err) {
    console.error("[POST /gps/checkout]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/gps/update-location
// FIX: was overwriting checkin_latitude/longitude — now uses last_known columns
// ─────────────────────────────────────────────────────────────────────────────
router.patch("/update-location", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [[active]] = await db.query(
      `SELECT attendance_id
       FROM employee_attendance
       WHERE tenant_id   = ?
         AND employee_id = ?
         AND work_date   = ?
         AND status      = 'active'
       ORDER BY attendance_id DESC
       LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    if (!active) {
      return res.json({ success: true, active: false });
    }

    const { latitude, longitude } = req.body;

    if (latitude == null || longitude == null) {
      return res.status(400).json({
        success: false,
        message: "latitude and longitude are required.",
      });
    }

    await db.query(
      `UPDATE employee_attendance
       SET last_known_latitude      = ?,
           last_known_longitude     = ?,
           last_location_updated_at = ?
       WHERE attendance_id = ?`,
      [latitude, longitude, nowDatetime(), active.attendance_id],
    );

    res.json({
      success: true,
      active: true,
      message: "Location updated.",
      attendance_id: active.attendance_id,
    });
  } catch (err) {
    console.error("[PATCH /gps/update-location]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/gps/history?limit=7&offset=0
// FIX: was filtering by todayDate() — now returns real history across all dates
// ─────────────────────────────────────────────────────────────────────────────
router.get("/history", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const limit = Math.min(Number(req.query.limit ?? 7), 100);
    const offset = Number(req.query.offset ?? 0);

    const [records] = await db.query(
      `SELECT
          attendance_id,
          work_date,
          checkin_time,
          checkout_time,
          status,
          total_work_time,
          is_late,
          late_minutes,
          checkin_latitude,
          checkin_longitude,
          checkout_latitude,
          checkout_longitude,
          attendance_mode
       FROM employee_attendance
       WHERE tenant_id       = ?
         AND employee_id     = ?
         AND attendance_mode = 'gps'
       ORDER BY work_date DESC, attendance_id DESC
       LIMIT ? OFFSET ?`,
      [tenantId, empId, limit, offset],
    );

    res.json({ success: true, records: records.map(normalizeRecord) });
  } catch (err) {
    console.error("[GET /gps/history]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/gps/admin/all?date=&status=&search=&limit=&offset=
// FIX: employee_master has no department_id — must join through designation_master
// ─────────────────────────────────────────────────────────────────────────────
router.get("/admin/all", requireAuth, requireAdmin, async (req, res) => {
  const { tenantId } = req.user;
  try {
    const date = req.query.date || todayDate();
    const status = req.query.status || "";
    const search = (req.query.search || "").trim();
    const limit = Math.min(Number(req.query.limit ?? 50), 200);
    const offset = Number(req.query.offset ?? 0);

    const whereClauses = [
      "ea.tenant_id       = ?",
      "ea.attendance_mode = 'gps'",
      "ea.work_date       = ?",
    ];
    const params = [tenantId, date];

    if (status) {
      whereClauses.push("ea.status = ?");
      params.push(status);
    }

    if (search) {
      whereClauses.push(
        "(CONCAT_WS(' ', e.first_name, e.last_name) LIKE ? OR CAST(ea.employee_id AS CHAR) LIKE ?)",
      );
      params.push(`%${search}%`, `%${search}%`);
    }

    const whereStr = whereClauses.join(" AND ");

    const [records] = await db.query(
      `SELECT
          ea.attendance_id,
          ea.employee_id,
          COALESCE(
            CONCAT_WS(' ', e.first_name, NULLIF(e.mid_name,''), e.last_name),
            CONCAT('Employee #', ea.employee_id)
          )                    AS employee_name,
          d.department_name    AS department,
          ea.work_date,
          ea.checkin_time,
          ea.checkout_time,
          ea.status,
          ea.total_work_time,
          ea.is_late,
          ea.late_minutes,
          ea.checkin_latitude,
          ea.checkin_longitude,
          ea.checkout_latitude,
          ea.checkout_longitude,
          ea.attendance_mode
       FROM employee_attendance ea
       LEFT JOIN employee_master    e  ON e.emp_id          = ea.employee_id
                                      AND CONVERT(e.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
                                        = CONVERT(ea.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
       LEFT JOIN designation_master dg ON dg.designation_id = e.designation_id
                                      AND CONVERT(dg.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
                                        = CONVERT(ea.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
       LEFT JOIN department_master  d  ON d.department_id   = dg.department_id
                                      AND CONVERT(d.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
                                        = CONVERT(ea.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
       WHERE ${whereStr}
       ORDER BY ea.employee_id ASC, ea.attendance_id ASC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    const [[statsRow]] = await db.query(
      `SELECT
          COUNT(DISTINCT ea.employee_id)                                           AS present_today,
          COUNT(DISTINCT CASE WHEN ea.is_late = 1 THEN ea.employee_id END)        AS late_today,
          COUNT(DISTINCT CASE WHEN ea.status  = 'active' THEN ea.employee_id END) AS active_now
       FROM employee_attendance ea
       WHERE ea.tenant_id       = ?
         AND ea.attendance_mode = 'gps'
         AND ea.work_date       = ?`,
      [tenantId, date],
    );

    const [[{ total_employees }]] = await db.query(
      `SELECT COUNT(*) AS total_employees
       FROM employee_master
       WHERE CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
         AND status = 'Active'`,
      [tenantId],
    );

    res.json({
      success: true,
      records: records.map(normalizeRecord),
      stats: {
        total_employees: Number(total_employees ?? 0),
        present_today: Number(statsRow.present_today ?? 0),
        late_today: Number(statsRow.late_today ?? 0),
        active_now: Number(statsRow.active_now ?? 0),
      },
    });
  } catch (err) {
    console.error("[GET /gps/admin/all]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
