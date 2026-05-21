"use strict";

const express = require("express");
const router = express.Router();
const db = require("../config/db");

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// Fetch Policy
// ─────────────────────────────────────────────────────────────

async function fetchPolicy(tenantId) {
  const [[row]] = await db.query(
    `SELECT is_saturday_weekoff, is_sunday_weekoff
     FROM attendance_policy
     WHERE tenant_id = ?
     LIMIT 1`,
    [tenantId],
  );

  return {
    isSatWeekoff: row?.is_saturday_weekoff == 1,
    isSunWeekoff: row?.is_sunday_weekoff == 1,
  };
}

// ─────────────────────────────────────────────────────────────
// Fetch Employees
// ─────────────────────────────────────────────────────────────

async function fetchEmployees(tenantId) {
  const [rows] = await db.query(
    `SELECT emp_id,
            CONCAT(first_name,' ',last_name) AS employee_name
     FROM employee_master
     WHERE tenant_id = ?
     ORDER BY emp_id`,
    [tenantId],
  );

  return rows;
}

// ─────────────────────────────────────────────────────────────
// Fetch Holidays
// ─────────────────────────────────────────────────────────────

async function fetchHolidaySet(tenantId, from, to) {
  const [rows] = await db.query(
    `SELECT DATE_FORMAT(holiday_date,'%Y-%m-%d') AS holiday_date
     FROM holiday_master
     WHERE (tenant_id = ? OR tenant_id = 'global')
       AND holiday_date BETWEEN ? AND ?`,
    [tenantId, from, to],
  );

  return new Set(rows.map((r) => r.holiday_date));
}

// ─────────────────────────────────────────────────────────────
// Fetch Leave Dates
// ─────────────────────────────────────────────────────────────

async function fetchLeaveMap(tenantId, from, to) {
  const [rows] = await db.query(
    `SELECT emp_id,
            DATE_FORMAT(leave_start_date,'%Y-%m-%d') AS start_date,
            DATE_FORMAT(leave_end_date,'%Y-%m-%d') AS end_date
     FROM leave_master
     WHERE tenant_id = ?
       AND final_status = 'Approved'
       AND leave_start_date <= ?
       AND leave_end_date >= ?`,
    [tenantId, to, from],
  );

  const map = new Map();

  for (const row of rows) {
    if (!map.has(row.emp_id)) {
      map.set(row.emp_id, new Set());
    }

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

// ─────────────────────────────────────────────────────────────
// Fetch Attendance
// ─────────────────────────────────────────────────────────────

async function fetchAttendanceMap(tenantId, from, to) {
  const [rows] = await db.query(
    `SELECT DISTINCT employee_id,
            DATE_FORMAT(work_date,'%Y-%m-%d') AS work_date
     FROM employee_attendance
     WHERE tenant_id = ?
       AND work_date BETWEEN ? AND ?
       AND checkin_time IS NOT NULL
       AND attendance_mode = 'normal'`,
    [tenantId, from, to],
  );

  const map = new Map();

  for (const row of rows) {
    if (!map.has(row.employee_id)) {
      map.set(row.employee_id, new Set());
    }

    map.get(row.employee_id).add(row.work_date);
  }

  return map;
}

// ─────────────────────────────────────────────────────────────
// 1. DAY WISE REPORT
// GET /attendance/report/day-wise?date=2026-05-21
// ─────────────────────────────────────────────────────────────

router.get("/attendance/report/day-wise", async (req, res) => {
  const tenant_id = getTenantId(req);

  if (!tenant_id) {
    return send(res, 401, false, "Unauthorized");
  }

  const { date } = req.query;

  if (!date || !isValidDate(date)) {
    return send(res, 400, false, "Invalid date");
  }

  try {
    const [policy, employees, holidaySet, leaveMap, attendanceMap] =
      await Promise.all([
        fetchPolicy(tenant_id),
        fetchEmployees(tenant_id),
        fetchHolidaySet(tenant_id, date, date),
        fetchLeaveMap(tenant_id, date, date),
        fetchAttendanceMap(tenant_id, date, date),
      ]);

    const day = new Date(date).getDay();

    const isWeekend =
      (day === 6 && policy.isSatWeekoff) || (day === 0 && policy.isSunWeekoff);

    const isHoliday = holidaySet.has(date);

    const data = employees.map((emp) => {
      const isPresent = attendanceMap.get(emp.emp_id)?.has(date) || false;

      const isLeave = leaveMap.get(emp.emp_id)?.has(date) || false;

      let status = "A";

      if (isPresent) status = "P";
      else if (isHoliday) status = "H";
      else if (isWeekend) status = "W";
      else if (isLeave) status = "L";

      return {
        emp_id: emp.emp_id,
        employee_name: emp.employee_name,
        status,
      };
    });

    return send(res, 200, true, "Day wise report", {
      date,
      data,
    });
  } catch (err) {
    console.error(err);
    return send(res, 500, false, "Server error");
  }
});

// ─────────────────────────────────────────────────────────────
// 2. MONTHLY / RANGE WISE REPORT
// GET /attendance/report/monthly?from=2026-05-01&to=2026-05-31
// ─────────────────────────────────────────────────────────────

router.get("/attendance/report/monthly", async (req, res) => {
  const tenant_id = getTenantId(req);

  if (!tenant_id) {
    return send(res, 401, false, "Unauthorized");
  }

  const { from, to } = req.query;

  if (!from || !to) {
    return send(res, 400, false, "from and to required");
  }

  try {
    const [policy, employees, holidaySet, leaveMap, attendanceMap] =
      await Promise.all([
        fetchPolicy(tenant_id),
        fetchEmployees(tenant_id),
        fetchHolidaySet(tenant_id, from, to),
        fetchLeaveMap(tenant_id, from, to),
        fetchAttendanceMap(tenant_id, from, to),
      ]);

    const dates = dateRange(from, to);

    const data = employees.map((emp) => {
      const days = [];

      let present = 0;
      let absent = 0;
      let leave = 0;

      for (const date of dates) {
        const day = new Date(date).getDay();

        const isWeekend =
          (day === 6 && policy.isSatWeekoff) ||
          (day === 0 && policy.isSunWeekoff);

        const isHoliday = holidaySet.has(date);

        const isPresent = attendanceMap.get(emp.emp_id)?.has(date) || false;

        const isLeave = leaveMap.get(emp.emp_id)?.has(date) || false;

        let status = "A";

        if (isPresent) {
          status = "P";
          present++;
        } else if (isHoliday) {
          status = "H";
        } else if (isWeekend) {
          status = "W";
        } else if (isLeave) {
          status = "L";
          leave++;
        } else {
          absent++;
        }

        days.push({
          date,
          status,
        });
      }

      return {
        emp_id: emp.emp_id,
        employee_name: emp.employee_name,
        present,
        absent,
        leave,
        days,
      };
    });

    return send(res, 200, true, "Monthly report", {
      from,
      to,
      dates,
      data,
    });
  } catch (err) {
    console.error(err);
    return send(res, 500, false, "Server error");
  }
});

module.exports = router;
