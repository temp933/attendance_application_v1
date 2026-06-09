const express = require("express");
const router = express.Router();
const db = require("../config/db");

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const getTenantId = (req) =>
  req.user?.tenant_id ?? req.user?.tenantId ?? req.headers["x-tenant-id"] ?? "";

const send = (res, status, ok, message, data = {}) =>
  res.status(status).json({ ok, message, ...data });

function isValidDate(str) {
  return /^\d{4}-\d{2}-\d{2}$/.test(str);
}

function dateRange(from, to) {
  const dates = [];
  const cur = new Date(from);
  const end = new Date(to);
  while (cur <= end) {
    dates.push(cur.toISOString().slice(0, 10));
    cur.setDate(cur.getDate() + 1);
  }
  return dates;
}

// ─────────────────────────────────────────────────────────────────────────────
// DB fetchers
// ─────────────────────────────────────────────────────────────────────────────

async function fetchPolicy(tenantId) {
  const [[row]] = await db.query(
    `SELECT is_saturday_weekoff, is_sunday_weekoff, comp_off_enabled
     FROM attendance_policy
     WHERE tenant_id = ? LIMIT 1`,
    [tenantId],
  );
  return {
    isSatWeekoff: row?.is_saturday_weekoff == 1,
    isSunWeekoff: row?.is_sunday_weekoff == 1,
    compOffEnabled: row?.comp_off_enabled == 1, // ← NEW
  };
}

async function fetchEmployees(tenantId, departmentId = null) {
  let sql = `
    SELECT
      em.emp_id,
      CONCAT(em.first_name, ' ', em.last_name) AS employee_name,
      COALESCE(dept.department_name, '') AS department
    FROM employee_master em
    LEFT JOIN designation_master desig
      ON desig.designation_id = em.designation_id AND desig.tenant_id = em.tenant_id
    LEFT JOIN department_master dept
      ON dept.department_id = desig.department_id AND dept.tenant_id = em.tenant_id
    WHERE em.tenant_id = ? AND em.status = 'Active'
  `;
  const params = [tenantId];
  if (departmentId) {
    sql += ` AND desig.department_id = ?`;
    params.push(departmentId);
  }
  sql += ` ORDER BY em.emp_id`;
  const [rows] = await db.query(sql, params);
  return rows;
}

async function fetchHolidayMapByDate(tenantId, from, to) {
  const [rows] = await db.query(
    `SELECT DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date, holiday_name
     FROM holiday_master
     WHERE (tenant_id = ? OR tenant_id = 'global') AND holiday_date BETWEEN ? AND ?`,
    [tenantId, from, to],
  );
  const map = new Map();
  for (const r of rows) map.set(r.holiday_date, r.holiday_name);
  return map;
}

async function fetchLeaveMap(tenantId, from, to) {
  const [rows] = await db.query(
    `SELECT emp_id,
            DATE_FORMAT(leave_start_date, '%Y-%m-%d') AS start_date,
            DATE_FORMAT(leave_end_date,   '%Y-%m-%d') AS end_date
     FROM leave_master
     WHERE tenant_id = ? AND final_status = 'Approved'
       AND leave_start_date <= ? AND leave_end_date >= ?`,
    [tenantId, to, from],
  );
  const map = new Map();
  for (const row of rows) {
    if (!map.has(row.emp_id)) map.set(row.emp_id, new Set());
    const set = map.get(row.emp_id);
    const cur = new Date(row.start_date);
    const end = new Date(row.end_date);
    while (cur <= end) {
      set.add(cur.toISOString().slice(0, 10));
      cur.setDate(cur.getDate() + 1);
    }
  }
  return map;
}

async function fetchAttendanceMap(tenantId, from, to, mode = "normal") {
  const [rows] = await db.query(
    `SELECT DISTINCT employee_id,
            DATE_FORMAT(work_date, '%Y-%m-%d') AS work_date,
            MAX(is_late) AS is_late
     FROM employee_attendance
     WHERE tenant_id = ? AND work_date BETWEEN ? AND ?
       AND checkin_time IS NOT NULL AND attendance_mode = ?
     GROUP BY employee_id, work_date`,
    [tenantId, from, to, mode],
  );
  const map = new Map(); // emp_id → Set of present dates
  const lateMap = new Map(); // emp_id → Set of late dates
  for (const row of rows) {
    if (!map.has(row.employee_id)) map.set(row.employee_id, new Set());
    map.get(row.employee_id).add(row.work_date);
    if (row.is_late == 1) {
      if (!lateMap.has(row.employee_id))
        lateMap.set(row.employee_id, new Set());
      lateMap.get(row.employee_id).add(row.work_date);
    }
  }
  return { map, lateMap };
}

async function fetchAttendanceDetail(tenantId, date, mode = "normal") {
  const [rows] = await db.query(
    `SELECT
       ea.employee_id,
       DATE_FORMAT(ea.checkin_time,  '%Y-%m-%d %H:%i:%s') AS check_in,
       DATE_FORMAT(ea.checkout_time, '%Y-%m-%d %H:%i:%s') AS check_out,
       ea.is_late,
       ea.late_minutes,
       TIMESTAMPDIFF(SECOND, ea.checkin_time, ea.checkout_time) AS worked_seconds
     FROM employee_attendance ea
     WHERE ea.tenant_id = ? AND ea.work_date = ?
       AND ea.attendance_mode = ? AND ea.checkin_time IS NOT NULL`,
    [tenantId, date, mode],
  );
  const map = new Map();
  for (const r of rows) map.set(r.employee_id, r);
  return map;
}

async function fetchCompOffSet(tenantId, date) {
  const [rows] = await db.query(
    `SELECT employee_id FROM comp_off
     WHERE tenant_id = ? AND earned_date = ? AND status = 'earned'`,
    [tenantId, date],
  );
  return new Set(rows.map((r) => r.employee_id));
}

async function fetchCompOffUsedMap(tenantId, from, to) {
  const [rows] = await db.query(
    `SELECT
       co.employee_id,
       DATE_FORMAT(lm.leave_start_date, '%Y-%m-%d') AS leave_start,
       DATE_FORMAT(lm.leave_end_date,   '%Y-%m-%d') AS leave_end
     FROM comp_off co
     LEFT JOIN leave_master lm ON lm.leave_id = co.leave_id
     WHERE co.tenant_id = ? AND co.status = 'used'
       AND lm.final_status = 'Approved'
       AND lm.leave_start_date <= ? AND lm.leave_end_date >= ?`,
    [tenantId, to, from],
  );
  const map = new Map();
  for (const row of rows) {
    if (!map.has(row.employee_id)) map.set(row.employee_id, new Set());
    const set = map.get(row.employee_id);
    const cur = new Date(Math.max(new Date(row.leave_start), new Date(from)));
    const end = new Date(Math.min(new Date(row.leave_end), new Date(to)));
    while (cur <= end) {
      set.add(cur.toISOString().slice(0, 10));
      cur.setDate(cur.getDate() + 1);
    }
  }
  return map;
}

// ── NEW: comp-off totals per employee (all-time, not date-filtered) ──────────

async function fetchCompOffSummaryMap(tenantId, empIds) {
  if (!empIds.length) return new Map();
  const [rows] = await db.query(
    `SELECT
       employee_id,
       SUM(status = 'earned')  AS earned,
       SUM(status = 'used')    AS used,
       SUM(status = 'expired') AS expired
     FROM comp_off
     WHERE tenant_id = ? AND employee_id IN (?)
     GROUP BY employee_id`,
    [tenantId, empIds],
  );
  const map = new Map();
  for (const r of rows)
    map.set(r.employee_id, {
      earned: Number(r.earned),
      used: Number(r.used),
      expired: Number(r.expired),
    });
  return map;
}

// ── NEW: leave approved/rejected totals per employee (all-time) ──────────────

async function fetchLateSummaryMap(
  tenantId,
  empIds,
  from,
  to,
  mode = "normal",
) {
  if (!empIds.length) return new Map();
  const [rows] = await db.query(
    `SELECT
       employee_id,
       COUNT(DISTINCT work_date) AS late_days,
       SUM(late_minutes)         AS total_late_minutes
     FROM employee_attendance
     WHERE tenant_id        = ?
       AND employee_id      IN (?)
       AND work_date        BETWEEN ? AND ?
       AND attendance_mode  = ?
       AND is_late          = 1
       AND checkin_time     IS NOT NULL
     GROUP BY employee_id`,
    [tenantId, empIds, from, to, mode],
  );
  const map = new Map();
  for (const r of rows)
    map.set(r.employee_id, {
      lateDays: Number(r.late_days),
      lateMinutes: Number(r.total_late_minutes ?? 0),
    });
  return map;
}

async function fetchLeaveSummaryMap(tenantId, empIds) {
  if (!empIds.length) return new Map();
  const [rows] = await db.query(
    `SELECT
       emp_id,
       SUM(final_status = 'Approved') AS approved,
       SUM(final_status = 'Rejected') AS rejected
     FROM leave_master
     WHERE tenant_id = ? AND emp_id IN (?)
     GROUP BY emp_id`,
    [tenantId, empIds],
  );
  const map = new Map();
  for (const r of rows)
    map.set(r.emp_id, {
      approved: Number(r.approved),
      rejected: Number(r.rejected),
    });
  return map;
}

// ─────────────────────────────────────────────────────────────────────────────
// Status resolver
// Priority: P > C > H > W > L > A
// ─────────────────────────────────────────────────────────────────────────────

function resolveStatus({
  isPresent,
  isCompOff,
  isHoliday,
  isWeekend,
  isLeave,
}) {
  if (isPresent) return "P";
  if (isCompOff) return "C";
  if (isHoliday) return "H";
  if (isWeekend) return "W";
  if (isLeave) return "L";
  return "A";
}

function isWeekendDay(dateStr, policy) {
  const day = new Date(dateStr).getDay();
  return (
    (day === 6 && policy.isSatWeekoff) || (day === 0 && policy.isSunWeekoff)
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/report/daily
// ─────────────────────────────────────────────────────────────────────────────
router.get("/attendance/report/daily", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id) return send(res, 401, false, "Unauthorized");

  const { date, department_id, mode } = req.query;
  const attendanceMode = (mode ?? "").trim() || "normal";

  if (!date || !isValidDate(date))
    return send(res, 400, false, "Invalid or missing date (YYYY-MM-DD)");

  const deptId = department_id ? parseInt(department_id, 10) : null;

  try {
    const isSiteEntry = attendanceMode === "site_entry";

    // Phase 1 — common fetches
    const [
      policy,
      employees,
      holidayMap,
      leaveMap,
      compOffEarnedSet,
      compOffUsedMap,
    ] = await Promise.all([
      fetchPolicy(tenant_id),
      fetchEmployees(tenant_id, deptId),
      fetchHolidayMapByDate(tenant_id, date, date),
      fetchLeaveMap(tenant_id, date, date),
      fetchCompOffSet(tenant_id, date),
      fetchCompOffUsedMap(tenant_id, date, date),
    ]);

    // Phase 1b — mode-specific attendance fetch
    const [attendanceDetail, siteSessionsMap] = await Promise.all([
      isSiteEntry
        ? Promise.resolve(new Map()) // not used for site_entry status calc
        : fetchAttendanceDetail(tenant_id, date, attendanceMode),
      isSiteEntry
        ? fetchSiteSessionsForDay(tenant_id, date)
        : Promise.resolve(new Map()),
    ]);

    // For site_entry: an employee is "present" if they have ≥1 session
    const sitePresenceSet = isSiteEntry
      ? new Set(siteSessionsMap.keys())
      : null;

    // Phase 2 — summary maps
    const empIds = employees.map((e) => e.emp_id);
    const [compOffSummaryMap, leaveSummaryMap] = await Promise.all([
      fetchCompOffSummaryMap(tenant_id, empIds),
      fetchLeaveSummaryMap(tenant_id, empIds),
    ]);

    const holidayName = holidayMap.get(date) ?? null;
    const isHolidayDay = holidayMap.has(date);
    const isWeekendDay_ = isWeekendDay(date, policy);

    const data = employees.map((emp) => {
      const isPresent = isSiteEntry
        ? sitePresenceSet.has(emp.emp_id)
        : !!attendanceDetail.get(emp.emp_id);

      const detail = isSiteEntry ? null : attendanceDetail.get(emp.emp_id);
      const isLeave = leaveMap.get(emp.emp_id)?.has(date) ?? false;
      const isCompOff = compOffUsedMap.get(emp.emp_id)?.has(date) ?? false;

      const statusCode = resolveStatus({
        isPresent,
        isCompOff,
        isHoliday: isHolidayDay,
        isWeekend: isWeekendDay_,
        isLeave,
      });

      const statusLabel =
        {
          P: "Present",
          A: "Absent",
          L: "Leave",
          H: "Holiday",
          W: "Weekend",
          C: "Comp-Off",
        }[statusCode] ?? "Absent";

      const coSummary = compOffSummaryMap.get(emp.emp_id) ?? {
        earned: 0,
        used: 0,
        expired: 0,
      };
      const lvSummary = leaveSummaryMap.get(emp.emp_id) ?? {
        approved: 0,
        rejected: 0,
      };

      // Aggregate worked_minutes from sessions for site_entry
      let workedMinutes = 0;
      if (isSiteEntry) {
        const sessions = siteSessionsMap.get(emp.emp_id) ?? [];
        for (const s of sessions) {
          if (s.total_work_time) {
            const [h, m, sec] = s.total_work_time.split(":").map(Number);
            workedMinutes +=
              (h || 0) * 60 + (m || 0) + Math.floor((sec || 0) / 60);
          }
        }
      } else {
        workedMinutes = detail
          ? Math.floor((detail.worked_seconds ?? 0) / 60)
          : 0;
      }

      // For site_entry, take late from the first session (earliest check-in)
      const firstSession = isSiteEntry
        ? ((siteSessionsMap.get(emp.emp_id) ?? [])[0] ?? null)
        : null;

      return {
        emp_id: emp.emp_id,
        name: emp.employee_name,
        department: emp.department,
        check_in: detail?.check_in ?? null,
        check_out: detail?.check_out ?? null,
        worked_minutes: workedMinutes,
        worked_seconds: isSiteEntry ? null : (detail?.worked_seconds ?? null),
        is_late: isSiteEntry
          ? (firstSession?.is_late ?? false)
          : detail?.is_late === 1 || false,
        late_minutes: isSiteEntry
          ? (firstSession?.late_minutes ?? 0)
          : (detail?.late_minutes ?? 0),
        comp_off_earned: compOffEarnedSet.has(emp.emp_id),
        holiday_name: isHolidayDay ? holidayName : null,
        total_comp_off_earned: coSummary.earned,
        total_comp_off_used: coSummary.used,
        total_comp_off_expired: coSummary.expired,
        total_leave_approved: lvSummary.approved,
        total_leave_rejected: lvSummary.rejected,
        // sessions only populated for site_entry mode
        sessions: isSiteEntry ? (siteSessionsMap.get(emp.emp_id) ?? []) : [],
      };
    });

    return send(res, 200, true, "Daily report", {
      date,
      is_holiday: isHolidayDay,
      is_weekend: isWeekendDay_,
      holiday_name: holidayName,
      department_id: deptId,
      comp_off_enabled: policy.compOffEnabled,
      data,
    });
  } catch (err) {
    console.error("[/attendance/report/daily]", err);
    return send(res, 500, false, "Server error");
  }
});
// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/report/matrix
// ─────────────────────────────────────────────────────────────────────────────

router.get("/attendance/report/matrix", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id) return send(res, 401, false, "Unauthorized");

  const { from, to, department_id, mode } = req.query;
  const attendanceMode = (mode ?? "").trim() || null;
  if (!from || !to) return send(res, 400, false, "from and to are required");
  if (!isValidDate(from)) return send(res, 400, false, "Invalid from date");
  if (!isValidDate(to)) return send(res, 400, false, "Invalid to date");
  if (from > to) return send(res, 400, false, "from must be <= to");

  const deptId = department_id ? parseInt(department_id, 10) : null;

  try {
    // Phase 1
    const [
      policy,
      employees,
      holidayMap,
      leaveMap,
      attendanceResult,
      compOffUsedMap,
    ] = await Promise.all([
      fetchPolicy(tenant_id),
      fetchEmployees(tenant_id, deptId),
      fetchHolidayMapByDate(tenant_id, from, to),
      fetchLeaveMap(tenant_id, from, to),
      fetchAttendanceMap(tenant_id, from, to, attendanceMode ?? "normal"),
      fetchCompOffUsedMap(tenant_id, from, to),
    ]);
    const attendanceMap = attendanceResult.map;
    const lateAttendanceMap = attendanceResult.lateMap;

    // Phase 2
    const empIds = employees.map((e) => e.emp_id);
    const [compOffSummaryMap, leaveSummaryMap, lateSummaryMap] =
      await Promise.all([
        fetchCompOffSummaryMap(tenant_id, empIds),
        fetchLeaveSummaryMap(tenant_id, empIds),
        fetchLateSummaryMap(
          tenant_id,
          empIds,
          from,
          to,
          attendanceMode ?? "normal",
        ),
      ]);

    const allDates = dateRange(from, to);

    const dates = allDates.map((date) => {
      const jsDay = new Date(date).getDay();
      const isHoliday = holidayMap.has(date);
      const isWeekend = isWeekendDay(date, policy);
      return {
        date,
        day: jsDay,
        is_holiday: isHoliday,
        is_weekend: isWeekend,
        holiday_name: isHoliday ? holidayMap.get(date) : null,
      };
    });

    const data = employees.map((emp) => {
      let presentDays = 0,
        absentDays = 0,
        leaveDays = 0,
        compOffDays = 0,
        workingDays = 0;

      const dayStatuses = allDates.map((date) => {
        const isHoliday = holidayMap.has(date);
        const isWeekend = isWeekendDay(date, policy);
        const isPresent = attendanceMap.get(emp.emp_id)?.has(date) ?? false;
        const isLate = lateAttendanceMap.get(emp.emp_id)?.has(date) ?? false;
        const isLeave = leaveMap.get(emp.emp_id)?.has(date) ?? false;
        const isCompOff = compOffUsedMap.get(emp.emp_id)?.has(date) ?? false;

        const code = resolveStatus({
          isPresent,
          isCompOff,
          isHoliday,
          isWeekend,
          isLeave,
        });

        if (!isHoliday && !isWeekend) workingDays++;
        if (code === "P") presentDays++;
        if (code === "A") absentDays++;
        if (code === "L") leaveDays++;
        if (code === "C") compOffDays++;

        // "PL" = present but late — Flutter renders it differently
        return code === "P" && isLate ? "PL" : code;
      });

      const percentage =
        workingDays > 0
          ? parseFloat(
              (((presentDays + compOffDays) / workingDays) * 100).toFixed(1),
            )
          : 0;

      const coSummary = compOffSummaryMap.get(emp.emp_id) ?? {
        earned: 0,
        used: 0,
        expired: 0,
      };
      const lvSummary = leaveSummaryMap.get(emp.emp_id) ?? {
        approved: 0,
        rejected: 0,
      };
      const lateSummary = lateSummaryMap.get(emp.emp_id) ?? {
        lateDays: 0,
        lateMinutes: 0,
      };

      return {
        emp_id: emp.emp_id,
        name: emp.employee_name,
        department: emp.department,
        days: dayStatuses,
        present_days: presentDays,
        absent_days: absentDays,
        leave_days: leaveDays,
        comp_off_days: compOffDays,
        total_working_days: workingDays,
        percentage,
        comp_off_earned: coSummary.earned,
        comp_off_used: coSummary.used,
        comp_off_expired: coSummary.expired,
        leave_approved: lvSummary.approved,
        leave_rejected: lvSummary.rejected,
        late_days: lateSummary.lateDays,
        late_minutes: lateSummary.lateMinutes,
      };
    });

    return send(res, 200, true, "Matrix report", {
      from,
      to,
      department_id: deptId,
      comp_off_enabled: policy.compOffEnabled,
      dates,
      data,
    });
  } catch (err) {
    console.error("[/attendance/report/matrix]", err);
    return send(res, 500, false, "Server error");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/report/daily  (site_entry mode — sessions per employee)
// Already handled by the existing /daily route for status/stats, but the
// Flutter side also needs sessions[]. We extend the existing daily handler:
// ─────────────────────────────────────────────────────────────────────────────

async function fetchSiteSessionsForDay(tenantId, date) {
  const [rows] = await db.query(
    `SELECT
       ea.employee_id,
       sm.site_name,
       DATE_FORMAT(ea.checkin_time,  '%Y-%m-%d %H:%i:%s') AS checkin_time,
       DATE_FORMAT(ea.checkout_time, '%Y-%m-%d %H:%i:%s') AS checkout_time,
       ea.status,
       ea.total_work_time,
       ea.total_pause_secs,
       ea.is_late,
       ea.late_minutes
     FROM employee_attendance ea
     LEFT JOIN sites sm ON sm.id = ea.site_id AND sm.tenant_id = ea.tenant_id
     WHERE ea.tenant_id = ?
       AND ea.work_date = ?
       AND ea.attendance_mode = 'site_entry'
       AND ea.checkin_time IS NOT NULL
     ORDER BY ea.employee_id, ea.checkin_time ASC`,
    [tenantId, date],
  );
  // Group sessions by employee_id
  const map = new Map();
  for (const r of rows) {
    if (!map.has(r.employee_id)) map.set(r.employee_id, []);
    map.get(r.employee_id).push({
      site_name: r.site_name ?? null,
      checkin_time: r.checkin_time ?? null,
      checkout_time: r.checkout_time ?? null,
      total_work_time: r.total_work_time ?? null,
      status: r.status ?? "completed",
      total_pause_secs: Number(r.total_pause_secs ?? 0),
      is_late: r.is_late === 1,
      late_minutes: Number(r.late_minutes ?? 0),
    });
  }
  return map;
}
module.exports = router;
