const express = require("express");
const router = express.Router();
const db = require("../config/db");
const authMiddleware = require("../middleware/auth");

// ─────────────────────────────────────────────────────────────────────────────
// Auth helpers
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
// IST helpers  (UTC + 5:30)
// ─────────────────────────────────────────────────────────────────────────────
function getISTDate() {
  return new Date(
    new Date().toLocaleString("en-US", {
      timeZone: "Asia/Kolkata",
    }),
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

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
function toISTStr(date) {
  if (!date || !(date instanceof Date)) return date;
  return new Date(date.getTime() + IST_OFFSET_MS)
    .toISOString()
    .slice(0, 19)
    .replace("T", " ");
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
  const [h, m] = timeStr.split(":").map(Number);
  return h * 60 + m;
}

function calcLateMinutes(checkinDatetime, officeInTime) {
  const timePart = checkinDatetime.split(" ")[1].slice(0, 5);

  return timeToMinutes(timePart) - timeToMinutes(officeInTime.slice(0, 5));
}
// ─────────────────────────────────────────────────────────────────────────────
// Fetch attendance policy for a tenant
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
// GET /api/today  — today's record + policy
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
          last_known_latitude,
          last_known_longitude,
          last_location_updated_at,
          is_late,
          late_minutes,
          total_work_time
       FROM employee_attendance
       WHERE tenant_id   = ?
         AND employee_id = ?
         AND work_date   = ?
       ORDER BY attendance_id DESC
       LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    const policy = await getPolicy(tenantId);
    res.json({
      success: true,
      record: record ? normalizeRecord(record) : null,
      policy,
    });
  } catch (err) {
    console.error("[GET //api/today]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/checkin
// Requires face verification to have already succeeded on the Flutter side.
// ─────────────────────────────────────────────────────────────────────────────
router.post("/checkin", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    // Check for an existing record today
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

    // Only compute lateness for a fresh first check-in today
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
           last_known_latitude, last_known_longitude,
           last_location_updated_at,
           is_late, late_minutes)
       VALUES (?, ?, 'gps_face', ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?)`,
      [
        tenantId,
        empId,
        checkinDatetime,
        todayDate(),
        latitude,
        longitude,
        latitude,
        longitude, // initialise last_known = checkin position
        checkinDatetime,
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
          last_known_latitude, last_known_longitude,
          last_location_updated_at,
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
    console.error("[POST /checkin]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/checkout
// Requires face verification to have already succeeded on the Flutter side.
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
       SET checkout_time             = ?,
           status                    = 'completed',
           checkout_latitude         = ?,
           checkout_longitude        = ?,
           last_known_latitude       = ?,
           last_known_longitude      = ?,
           last_location_updated_at  = ?
       WHERE attendance_id = ?`,
      [
        checkoutDatetime,
        latitude,
        longitude,
        latitude,
        longitude, // also update last_known on checkout
        checkoutDatetime,
        active.attendance_id,
      ],
    );

    const [[record]] = await db.query(
      `SELECT
          attendance_id, attendance_mode,
          checkin_time, checkout_time,
          work_date, status,
          checkin_latitude, checkin_longitude,
          checkout_latitude, checkout_longitude,
          last_known_latitude, last_known_longitude,
          last_location_updated_at,
          is_late, late_minutes, total_work_time
       FROM employee_attendance
       WHERE attendance_id = ?`,
      [active.attendance_id],
    );

    res.json({
      success: true,
      message: "Checked out successfully.",
      record: normalizeRecord(record),
    });
  } catch (err) {
    console.error("[POST /checkout]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/update-location
// Called by background service every 10 min while session is active.
// Writes to last_known_latitude / last_known_longitude — NOT the original
// checkin_latitude / checkin_longitude which must remain the check-in snapshot.
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

    // No active session — tell background service to stop
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

    // ✅ Update ONLY last_known columns — checkin_latitude stays untouched
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
    console.error("[PATCH /update-location]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/history?limit=7&offset=0
// FIX: was filtering by todayDate() — now returns real history across all dates.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/history", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const limit = Math.min(Number(req.query.limit ?? 7), 100);
    const offset = Math.min(Number(req.query.offset ?? 0), 10000);

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
          last_known_latitude,
          last_known_longitude,
          last_location_updated_at,
          attendance_mode
       FROM employee_attendance
       WHERE tenant_id      = ?
         AND employee_id    = ?
         AND attendance_mode = 'gps_face'
       ORDER BY work_date DESC, attendance_id DESC
       LIMIT ? OFFSET ?`,
      [tenantId, empId, limit, offset],
    );

    res.json({
      success: true,
      records: records.map(normalizeRecord),
    });
  } catch (err) {
    console.error("[GET /history]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/all?date=&status=&search=&limit=&offset=
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
      "ea.attendance_mode = 'gps_face'",
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
          )                         AS employee_name,
          d.department_name         AS department,
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
          ea.last_known_latitude,
          ea.last_known_longitude,
          ea.last_location_updated_at,
          ea.attendance_mode
       FROM employee_attendance ea
       LEFT JOIN employee_master   e ON e.emp_id        = ea.employee_id
                                    AND CONVERT(e.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
                                      = CONVERT(ea.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
       LEFT JOIN department_master d ON d.department_id = e.department_id
                                    AND CONVERT(d.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
                                      = CONVERT(ea.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
       WHERE ${whereStr}
       ORDER BY ea.employee_id ASC, ea.attendance_id ASC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    const [[statsRow]] = await db.query(
      `SELECT
          COUNT(DISTINCT ea.employee_id)                                       AS present_today,
          COUNT(DISTINCT CASE WHEN ea.is_late = 1 THEN ea.employee_id END)    AS late_today,
          COUNT(DISTINCT CASE WHEN ea.status  = 'active' THEN ea.employee_id END) AS active_now
       FROM employee_attendance ea
       WHERE ea.tenant_id       = ?
         AND ea.attendance_mode = 'gps_face'
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
    console.error("[GET //api/admin/all]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
