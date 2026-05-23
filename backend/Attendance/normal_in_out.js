const express = require("express");
const router = express.Router();
const db = require("../config/db");
const { generateCompOff } = require("./comp-off");
const authMiddleware = require("../middleware/auth");

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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — all timestamps in IST (UTC+5:30)
// ─────────────────────────────────────────────────────────────────────────────
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

function nowIST() {
  return new Date(Date.now() + IST_OFFSET_MS);
}

function nowDatetime() {
  return nowIST().toISOString().slice(0, 19).replace("T", " ");
}

function todayDate() {
  return nowIST().toISOString().slice(0, 10);
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
// Helper — sum ALL completed sessions for an employee on a given date.
// ─────────────────────────────────────────────────────────────────────────────
// FIX — add mode parameter
async function getDailyTotal(tenantId, empId, workDate, mode = "normal") {
  const [[row]] = await db.query(
    `SELECT SEC_TO_TIME(SUM(TIMESTAMPDIFF(SECOND, checkin_time, checkout_time))) AS daily_total
     FROM employee_attendance
     WHERE tenant_id = ? AND employee_id = ? AND work_date = ?
     AND attendance_mode = ?
     AND status = 'completed'
     AND checkin_time IS NOT NULL AND checkout_time IS NOT NULL`,
    [tenantId, empId, workDate, mode],
  );
  return row?.daily_total ?? null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fetch attendance_policy for a tenant (returns null if not configured)
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
        auto_checkout_enabled,
        is_saturday_weekoff,
        is_sunday_weekoff,
        comp_off_enabled,
        comp_off_min_hours,
        comp_off_expiry_days
     FROM attendance_policy
     WHERE tenant_id = ?
     LIMIT 1`,
    [tenantId],
  );
  return policy ?? null;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/today
// ─────────────────────────────────────────────────────────────────────────────
router.get("/today", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [[record]] = await db.query(
      `SELECT
            attendance_id, attendance_mode,
            checkin_time, checkout_time,
            work_date, status,
            checkin_latitude, checkin_longitude,
            checkout_latitude, checkout_longitude,
            is_late, late_minutes, total_work_time
        FROM employee_attendance
        WHERE tenant_id   = ?
            AND employee_id = ?
            AND work_date   = ?
            AND attendance_mode = 'normal'
        ORDER BY attendance_id DESC
        LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    if (record && record.status === "completed") {
      const dailyTotal = await getDailyTotal(tenantId, empId, todayDate());
      if (dailyTotal) record.total_work_time = dailyTotal;
    }

    const policy = await getPolicy(tenantId);
    res.json({
      success: true,
      record: normalizeRecord(record) ?? null,
      policy,
    });
  } catch (err) {
    console.error("[GET /attendance/today]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/attendance/checkin
// ─────────────────────────────────────────────────────────────────────────────
router.post("/checkin", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const policy = await getPolicy(tenantId);

    const [[existing]] = await db.query(
      `SELECT attendance_id, status
        FROM employee_attendance
        WHERE tenant_id   = ?
            AND employee_id = ?
            AND work_date   = ?
             AND attendance_mode = 'normal'
        ORDER BY attendance_id DESC
        LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    if (existing) {
      if (existing.status === "active") {
        return res.status(409).json({
          success: false,
          message: "Already checked in. Please check out first.",
        });
      }
      if (policy && !policy.multiple_in_out_allowed) {
        return res.status(409).json({
          success: false,
          message:
            "Multiple check-ins per day are not allowed by your company policy.",
        });
      }
    }

    const {
      latitude = null,
      longitude = null,
      face_verified = false,
      photo = null,
      notes = null,
      mode = "normal",
    } = req.body;

    const checkinDatetime = nowDatetime();
    let isLate = 0;
    let lateMinutes = 0;

    if (!existing && policy && policy.office_in_time) {
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
    (
      tenant_id,
      employee_id,
      attendance_mode,
      checkin_time,
      work_date,
      status,
      checkin_latitude,
      checkin_longitude,
      is_late,
      late_minutes
    )
    VALUES (?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)`,
      [
        tenantId,
        empId,
        mode,
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
    console.error("[POST /attendance/checkin]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/attendance/checkout
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
            AND attendance_mode = 'normal'
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

    const {
      latitude = null,
      longitude = null,
      face_verified = false,
      photo = null,
      notes = null,
    } = req.body;

    await db.query(
      `UPDATE employee_attendance
    SET checkout_time      = ?,
        status             = 'completed',
        checkout_latitude  = ?,
        checkout_longitude = ?
    WHERE attendance_id = ?`,
      [nowDatetime(), latitude, longitude, active.attendance_id],
    );

    // ── Auto-generate comp-off if applicable ──────────────────────────────
    try {
      const compOffResult = await generateCompOff(
        tenantId,
        active.attendance_id,
      );
      if (compOffResult.created) {
        console.log(`[Checkout] Comp-off generated: ${compOffResult.reason}`);
      } else if (compOffResult.skipped) {
        console.log("[Checkout] Comp-off already exists — skipped.");
      }
    } catch (compErr) {
      // Non-fatal: checkout must not fail because of comp-off errors
      console.error(
        "[Checkout] Comp-off generation error (non-fatal):",
        compErr.message,
      );
    }

    const dailyTotal = await getDailyTotal(tenantId, empId, todayDate());

    const [[record]] = await db.query(
      `SELECT
            attendance_id, attendance_mode,
            checkin_time, checkout_time,
            work_date, status,
            checkout_latitude, checkout_longitude,
            is_late, late_minutes, total_work_time
        FROM employee_attendance
        WHERE attendance_id = ?`,
      [active.attendance_id],
    );

    record.total_work_time = dailyTotal ?? record.total_work_time;

    res.json({
      success: true,
      message: "Checked out successfully.",
      record: normalizeRecord(record),
    });
  } catch (err) {
    console.error("[POST /attendance/checkout]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/attendance/auto-checkout
// ─────────────────────────────────────────────────────────────────────────────
router.post("/auto-checkout", async (req, res) => {
  const secret = req.headers["x-cron-secret"];
  if (secret !== process.env.AUTO_CHECKOUT_SECRET) {
    return res.status(401).json({ success: false, message: "Unauthorized." });
  }

  try {
    const [policies] = await db.query(
      `SELECT tenant_id, office_out_time
        FROM attendance_policy
        WHERE auto_checkout_enabled = 1`,
    );

    let totalClosed = 0;

    for (const policy of policies) {
      const checkoutTime = `${todayDate()} ${policy.office_out_time}`;
      const [result] = await db.query(
        `UPDATE employee_attendance
            SET checkout_time      = ?,
                status             = 'completed'
            WHERE tenant_id    = ?
            AND work_date    = ?
            AND status       = 'active'
            AND attendance_mode = 'normal'
            AND checkin_time < ?`,
        [checkoutTime, policy.tenant_id, todayDate(), checkoutTime],
      );
      totalClosed += result.affectedRows;
    }

    res.json({
      success: true,
      message: `Auto-checkout complete. ${totalClosed} session(s) closed.`,
      closed: totalClosed,
    });
  } catch (err) {
    console.error("[POST /attendance/auto-checkout]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});
router.get("/history", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const limit = Math.min(Number(req.query.limit ?? 30), 100);
    const offset = Number(req.query.offset ?? 0);

    const [records] = await db.query(
      `SELECT
            attendance_id, work_date,
            checkin_time, checkout_time,
            status, total_work_time,
            is_late, late_minutes,
            attendance_mode
        FROM employee_attendance
        WHERE tenant_id   = ?
            AND employee_id = ?
            AND attendance_mode = 'normal'
        ORDER BY work_date DESC, attendance_id DESC
        LIMIT ? OFFSET ?`,
      [tenantId, empId, limit, offset],
    );

    res.json({ success: true, records: records.map(normalizeRecord) });
  } catch (err) {
    console.error("[GET /attendance/history]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});
// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/summary
// ─────────────────────────────────────────────────────────────────────────────
router.get("/summary", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [[summary]] = await db.query(
      `SELECT
            COUNT(DISTINCT work_date)                          AS total_days,
            ROUND(
            SUM(TIMESTAMPDIFF(SECOND, checkin_time, checkout_time)) / 3600, 1
            )                                                  AS total_hours,
            COUNT(DISTINCT CASE WHEN status = 'completed'
                THEN work_date END)                         AS completed_days,
            COUNT(DISTINCT CASE WHEN status = 'active'
                THEN work_date END)                         AS active_days,
            SUM(is_late = 1)                                   AS late_days,
            ROUND(AVG(NULLIF(late_minutes, 0)), 0)             AS avg_late_minutes
        FROM employee_attendance
        WHERE tenant_id   = ?
            AND employee_id = ?
            AND attendance_mode = 'normal'
            AND work_date BETWEEN DATE_FORMAT(CONVERT_TZ(NOW(), '+00:00', '+05:30'), '%Y-%m-01')
                            AND DATE(CONVERT_TZ(NOW(), '+00:00', '+05:30'))`,
      [tenantId, empId],
    );

    const policy = await getPolicy(tenantId);
    res.json({ success: true, summary, policy });
  } catch (err) {
    console.error("[GET /attendance/summary]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/all?date=YYYY-MM-DD&limit=50&offset=0&status=&search=
// ─────────────────────────────────────────────────────────────────────────────
router.get("/all", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  try {
    const date = req.query.date ?? todayDate();
    const limit = Math.min(Number(req.query.limit ?? 50), 200);
    const offset = Number(req.query.offset ?? 0);
    const status = (req.query.status ?? "").trim();
    const search = (req.query.search ?? "").trim();

    const whereClauses = [
      "ea.tenant_id = ?",
      "ea.work_date = ?",
      "ea.attendance_mode = 'normal'",
    ];
    const params = [tenantId, date];

    if (status) {
      whereClauses.push("ea.status = ?");
      params.push(status);
    }

    if (search) {
      whereClauses.push(
        "(e.first_name LIKE ? OR e.last_name LIKE ? OR CAST(ea.employee_id AS CHAR) LIKE ?)",
      );
      const like = `%${search}%`;
      params.push(like, like, like);
    }

    const whereSQL = whereClauses.join(" AND ");

    const [records] = await db.query(
      `SELECT
            ea.attendance_id,
            ea.employee_id,
            CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
            e.department_id,
            ea.work_date,
            ea.checkin_time,
            ea.checkout_time,
            ea.status,
            ea.total_work_time,
            ea.is_late,
            ea.late_minutes,
            ea.attendance_mode
        FROM employee_attendance ea
        JOIN employee_master e
            ON  e.emp_id = ea.employee_id
            AND e.tenant_id COLLATE utf8mb4_0900_ai_ci = ea.tenant_id
        WHERE ${whereSQL}
        ORDER BY ea.checkin_time DESC
        LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    records.forEach(normalizeRecord);

    const [[stats]] = await db.query(
      `SELECT
            (SELECT COUNT(*)
            FROM employee_master
            WHERE tenant_id COLLATE utf8mb4_0900_ai_ci = ?
                AND status = 'Active') AS total_employees,
            COUNT(DISTINCT ea.employee_id)           AS present_today,
            COALESCE(SUM(ea.is_late = 1), 0)        AS late_today,
            COALESCE(SUM(ea.status = 'active'), 0)  AS active_now
        FROM employee_attendance ea
        WHERE ea.tenant_id = ?
            AND ea.work_date = ?
            AND ea.attendance_mode = 'normal'`,
      [tenantId, tenantId, date],
    );

    stats.absent_today =
      (stats.total_employees ?? 0) - (stats.present_today ?? 0);

    res.json({ success: true, records, stats });
  } catch (err) {
    console.error("[GET /attendance/all]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/policy
// ─────────────────────────────────────────────────────────────────────────────
router.get("/policy", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  try {
    const policy = await getPolicy(tenantId);
    res.json({ success: true, policy: policy ?? null });
  } catch (err) {
    console.error("[GET /attendance/policy]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/attendance/policy  — upsert policy (admin only)
// ─────────────────────────────────────────────────────────────────────────────
router.post("/policy", requireAuth, async (req, res) => {
  const { tenantId } = req.user;

  const {
    office_in_time,
    office_out_time,
    late_after_minutes = 0,
    halfday_after_minutes = 0,
    overtime_after_minutes = 0,
    multiple_in_out_allowed = 1,
    auto_checkout_enabled = 0,
    is_saturday_weekoff = 0,
    is_sunday_weekoff = 1,
    comp_off_enabled = 1,
    comp_off_min_hours = 4,
    comp_off_expiry_days = 30,
  } = req.body;

  if (!office_in_time || !office_out_time) {
    return res.status(400).json({
      success: false,
      message: "office_in_time and office_out_time are required.",
    });
  }

  const toInt = (v, def = 0) => {
    const n = parseInt(v, 10);
    return isNaN(n) || n < 0 ? def : n;
  };
  const toBool = (v, def = 0) =>
    v === true || v === 1 || v === "1"
      ? 1
      : v === false || v === 0 || v === "0"
        ? 0
        : def;

  const params = {
    office_in_time,
    office_out_time,
    late_after_minutes: toInt(late_after_minutes, 0),
    halfday_after_minutes: toInt(halfday_after_minutes, 0),
    overtime_after_minutes: toInt(overtime_after_minutes, 0),
    multiple_in_out_allowed: toBool(multiple_in_out_allowed, 1),
    auto_checkout_enabled: toBool(auto_checkout_enabled, 0),
    is_saturday_weekoff: toBool(is_saturday_weekoff, 0),
    is_sunday_weekoff: toBool(is_sunday_weekoff, 1),
    comp_off_enabled: toBool(comp_off_enabled, 1),
    comp_off_min_hours: toInt(comp_off_min_hours, 4),
    comp_off_expiry_days: toInt(comp_off_expiry_days, 30),
  };

  try {
    const [[existing]] = await db.query(
      `SELECT id FROM attendance_policy WHERE tenant_id = ? LIMIT 1`,
      [tenantId],
    );

    if (existing) {
      await db.query(
        `UPDATE attendance_policy SET
           office_in_time          = ?,
           office_out_time         = ?,
           late_after_minutes      = ?,
           halfday_after_minutes   = ?,
           overtime_after_minutes  = ?,
           multiple_in_out_allowed = ?,
           auto_checkout_enabled   = ?,
           is_saturday_weekoff     = ?,
           is_sunday_weekoff       = ?,
           comp_off_enabled        = ?,
           comp_off_min_hours      = ?,
           comp_off_expiry_days    = ?
         WHERE tenant_id = ?`,
        [
          params.office_in_time,
          params.office_out_time,
          params.late_after_minutes,
          params.halfday_after_minutes,
          params.overtime_after_minutes,
          params.multiple_in_out_allowed,
          params.auto_checkout_enabled,
          params.is_saturday_weekoff,
          params.is_sunday_weekoff,
          params.comp_off_enabled,
          params.comp_off_min_hours,
          params.comp_off_expiry_days,
          tenantId,
        ],
      );
    } else {
      await db.query(
        `INSERT INTO attendance_policy
           (tenant_id,
            office_in_time, office_out_time,
            late_after_minutes, halfday_after_minutes, overtime_after_minutes,
            multiple_in_out_allowed, auto_checkout_enabled,
            is_saturday_weekoff, is_sunday_weekoff,
            comp_off_enabled, comp_off_min_hours, comp_off_expiry_days)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          tenantId,
          params.office_in_time,
          params.office_out_time,
          params.late_after_minutes,
          params.halfday_after_minutes,
          params.overtime_after_minutes,
          params.multiple_in_out_allowed,
          params.auto_checkout_enabled,
          params.is_saturday_weekoff,
          params.is_sunday_weekoff,
          params.comp_off_enabled,
          params.comp_off_min_hours,
          params.comp_off_expiry_days,
        ],
      );
    }

    const policy = await getPolicy(tenantId);
    res.json({ success: true, message: "Policy saved.", policy });
  } catch (err) {
    console.error("[POST /attendance/policy]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
