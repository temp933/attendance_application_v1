"use strict";

const express = require("express");
const router = express.Router();
const db = require("./config/db");
const authMiddleware = require("./middleware/auth");

// ─── Auth ─────────────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  authMiddleware(req, res, () => {
    if (!req.user)
      return res.status(401).json({ ok: false, message: "Unauthorized." });
    req.user.tenantId = req.user.tenant_id ?? req.headers["x-tenant-id"];
    req.user.empId = req.user.emp_id;
    next();
  });
}

const send = (res, status, ok, message, data = {}) =>
  res.status(status).json({ ok, message, ...data });

// ─── Shared: fetch policy + holidays for a date range ────────────────────────
async function fetchPolicyAndHolidays(tenantId, startDate, endDate) {
  const [[policy]] = await db.execute(
    `SELECT office_in_time, office_out_time, late_after_minutes,
            halfday_after_minutes, overtime_after_minutes,
            is_saturday_weekoff, is_sunday_weekoff
     FROM attendance_policy WHERE tenant_id = ? LIMIT 1`,
    [tenantId],
  );

  const [holidays] = await db.execute(
    `SELECT holiday_date, holiday_name, holiday_type
     FROM holiday_master
     WHERE tenant_id = ? AND holiday_date BETWEEN ? AND ?`,
    [tenantId, startDate, endDate],
  );

  const holidayMap = {};
  for (const h of holidays) {
    const key = new Date(h.holiday_date).toISOString().split("T")[0];
    holidayMap[key] = { name: h.holiday_name, type: h.holiday_type };
  }

  return { policy: policy ?? null, holidayMap };
}

// ─── Shared: classify a date ──────────────────────────────────────────────────
function classifyDate(dateStr, policy, holidayMap) {
  const d = new Date(dateStr);
  const day = d.getDay(); // 0=Sun, 6=Sat

  if (holidayMap[dateStr]) {
    return { type: "holiday", meta: holidayMap[dateStr] };
  }
  if (policy?.is_sunday_weekoff && day === 0) {
    return { type: "weekoff", meta: { name: "Sunday" } };
  }
  if (policy?.is_saturday_weekoff && day === 6) {
    return { type: "weekoff", meta: { name: "Saturday" } };
  }
  return { type: "working", meta: null };
}

// ─── Shared: build attendance summary for a set of records ───────────────────
function buildSummary(records) {
  let present = 0,
    absent = 0,
    late = 0,
    halfday = 0,
    overtime = 0;
  for (const r of records) {
    if (r.day_status === "Present" || r.day_status === "present") present++;
    else if (r.day_status === "Absent" || r.day_status === "absent") absent++;
    if (r.is_late) late++;
    if (r.is_halfday) halfday++;
    if (r.overtime_minutes > 0) overtime++;
  }
  return { present, absent, late, halfday, overtime, total: records.length };
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE 1 — Day-wise Report
// GET /api/report/day?date=YYYY-MM-DD&emp_id=&department_id=
// date defaults to today; emp_id and department_id are optional filters
// ─────────────────────────────────────────────────────────────────────────────
router.get("/day", requireAuth, async (req, res) => {
  const tenantId = req.user.tenantId;
  const { emp_id, department_id } = req.query;
  const date = req.query.date ?? new Date().toISOString().split("T")[0];

  // Validate date format
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date))
    return send(res, 400, false, "date must be YYYY-MM-DD");

  try {
    const { policy, holidayMap } = await fetchPolicyAndHolidays(
      tenantId,
      date,
      date,
    );

    const dayInfo = classifyDate(date, policy, holidayMap);

    // ── Build employee + attendance query ──
    let empWhere = "e.tenant_id = ? AND e.status = 'Active'";
    const empParams = [tenantId];

    if (emp_id) {
      empWhere += " AND e.emp_id = ?";
      empParams.push(emp_id);
    }
    if (department_id) {
      empWhere += " AND e.department_id = ?";
      empParams.push(department_id);
    }

    const [employees] = await db.execute(
      `SELECT e.emp_id, e.first_name, e.last_name, e.employee_code,
              d.department_name, dg.designation_name,
              r.role_name
       FROM employee_master e
       LEFT JOIN department_master d ON e.department_id = d.department_id AND d.tenant_id = e.tenant_id
       LEFT JOIN designation_master dg ON e.designation_id = dg.designation_id AND dg.tenant_id = e.tenant_id
       LEFT JOIN role_master r ON e.role_id = r.role_id AND r.tenant_id = e.tenant_id
       WHERE ${empWhere}
       ORDER BY e.first_name ASC`,
      empParams,
    );

    if (employees.length === 0)
      return send(res, 200, true, "No employees found", {
        date,
        day_info: dayInfo,
        data: [],
        summary: buildSummary([]),
      });

    const empIds = employees.map((e) => e.emp_id);
    const placeholders = empIds.map(() => "?").join(",");

    // ── Attendance for all employees on that date ──
    const [attRows] = await db.execute(
      `SELECT
         a.emp_id,
         a.attendance_date,
         a.day_status,
         a.check_in_time,
         a.check_out_time,
         a.total_hours,
         a.is_late,
         a.is_halfday,
         a.late_minutes,
         a.overtime_minutes,
         a.work_location
       FROM attendance_master a
       WHERE a.tenant_id = ?
         AND a.attendance_date = ?
         AND a.emp_id IN (${placeholders})`,
      [tenantId, date, ...empIds],
    );

    const attMap = {};
    for (const row of attRows) attMap[row.emp_id] = row;

    // ── Leaves on that date ──
    const [leaveRows] = await db.execute(
      `SELECT lm.emp_id, lt.leave_name, lm.is_half_day, lm.half_day_period
       FROM leave_master lm
       LEFT JOIN leave_type_master lt ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
       WHERE lm.tenant_id = ?
         AND lm.final_status = 'Approved'
         AND lm.leave_start_date <= ?
         AND lm.leave_end_date >= ?
         AND lm.emp_id IN (${placeholders})`,
      [tenantId, date, date, ...empIds],
    );

    const leaveMap = {};
    for (const row of leaveRows) leaveMap[row.emp_id] = row;

    // ── Merge ──
    const data = employees.map((emp) => {
      const att = attMap[emp.emp_id] ?? null;
      const leave = leaveMap[emp.emp_id] ?? null;

      let status = "Absent";
      if (dayInfo.type === "holiday") status = "Holiday";
      else if (dayInfo.type === "weekoff") status = "Week Off";
      else if (leave)
        status = leave.is_half_day ? "Half Day Leave" : "On Leave";
      else if (att) status = att.day_status ?? "Present";

      return {
        emp_id: emp.emp_id,
        employee_code: emp.employee_code,
        employee_name: `${emp.first_name} ${emp.last_name}`.trim(),
        department: emp.department_name ?? "-",
        designation: emp.designation_name ?? "-",
        role: emp.role_name ?? "-",
        date,
        status,
        check_in_time: att?.check_in_time ?? null,
        check_out_time: att?.check_out_time ?? null,
        total_hours: att?.total_hours ?? null,
        is_late: att?.is_late ?? false,
        late_minutes: att?.late_minutes ?? 0,
        is_halfday: att?.is_halfday ?? false,
        overtime_minutes: att?.overtime_minutes ?? 0,
        work_location: att?.work_location ?? null,
        leave_name: leave?.leave_name ?? null,
        half_day_period: leave?.half_day_period ?? null,
        day_info: dayInfo,
      };
    });

    const summary = {
      total_employees: data.length,
      present: data.filter((d) => d.status === "Present").length,
      absent: data.filter((d) => d.status === "Absent").length,
      on_leave: data.filter((d) => d.status.includes("Leave")).length,
      late: data.filter((d) => d.is_late).length,
      halfday: data.filter((d) => d.is_halfday).length,
      overtime: data.filter((d) => d.overtime_minutes > 0).length,
      holiday: dayInfo.type === "holiday" ? dayInfo.meta : null,
      weekoff: dayInfo.type === "weekoff" ? dayInfo.meta : null,
    };

    return send(res, 200, true, "Day report fetched", {
      date,
      day_info: dayInfo,
      policy: policy
        ? {
            office_in_time: policy.office_in_time,
            office_out_time: policy.office_out_time,
            late_after_minutes: policy.late_after_minutes,
          }
        : null,
      summary,
      data,
    });
  } catch (err) {
    console.error("[report/day]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE 2 — Range-wise Report
// GET /api/report/range?start=YYYY-MM-DD&end=YYYY-MM-DD&emp_id=&department_id=
// Accepts past and future dates. Includes holidays + weekoffs per day.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/range", requireAuth, async (req, res) => {
  const tenantId = req.user.tenantId;
  const { start, end, emp_id, department_id } = req.query;

  if (!start || !end)
    return send(res, 400, false, "start and end dates are required");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(start) || !/^\d{4}-\d{2}-\d{2}$/.test(end))
    return send(res, 400, false, "Dates must be YYYY-MM-DD");
  if (new Date(start) > new Date(end))
    return send(res, 400, false, "start must be <= end");

  // Cap range to 365 days to prevent runaway queries
  const daysDiff = (new Date(end) - new Date(start)) / (1000 * 60 * 60 * 24);
  if (daysDiff > 365)
    return send(res, 400, false, "Date range cannot exceed 365 days");

  try {
    const { policy, holidayMap } = await fetchPolicyAndHolidays(
      tenantId,
      start,
      end,
    );

    // ── Build all dates in range ──
    const allDates = [];
    const cur = new Date(start);
    const endDt = new Date(end);
    while (cur <= endDt) {
      allDates.push(cur.toISOString().split("T")[0]);
      cur.setDate(cur.getDate() + 1);
    }

    // ── Classify each date ──
    const dateInfoMap = {};
    for (const d of allDates) {
      dateInfoMap[d] = classifyDate(d, policy, holidayMap);
    }

    // ── Employees ──
    let empWhere = "e.tenant_id = ? AND e.status = 'Active'";
    const empParams = [tenantId];

    if (emp_id) {
      empWhere += " AND e.emp_id = ?";
      empParams.push(emp_id);
    }
    if (department_id) {
      empWhere += " AND e.department_id = ?";
      empParams.push(department_id);
    }

    const [employees] = await db.execute(
      `SELECT e.emp_id, e.first_name, e.last_name, e.employee_code,
              d.department_name, dg.designation_name, r.role_name
       FROM employee_master e
       LEFT JOIN department_master d ON e.department_id = d.department_id AND d.tenant_id = e.tenant_id
       LEFT JOIN designation_master dg ON e.designation_id = dg.designation_id AND dg.tenant_id = e.tenant_id
       LEFT JOIN role_master r ON e.role_id = r.role_id AND r.tenant_id = e.tenant_id
       WHERE ${empWhere}
       ORDER BY e.first_name ASC`,
      empParams,
    );

    if (employees.length === 0)
      return send(res, 200, true, "No employees found", {
        start,
        end,
        dates: dateInfoMap,
        data: [],
      });

    const empIds = employees.map((e) => e.emp_id);
    const placeholders = empIds.map(() => "?").join(",");

    // ── Attendance for entire range ──
    const [attRows] = await db.execute(
      `SELECT emp_id, attendance_date, day_status,
              check_in_time, check_out_time, total_hours,
              is_late, is_halfday, late_minutes, overtime_minutes, work_location
       FROM attendance_master
       WHERE tenant_id = ?
         AND attendance_date BETWEEN ? AND ?
         AND emp_id IN (${placeholders})`,
      [tenantId, start, end, ...empIds],
    );

    // att[emp_id][date] = record
    const att = {};
    for (const row of attRows) {
      const dateKey = new Date(row.attendance_date).toISOString().split("T")[0];
      if (!att[row.emp_id]) att[row.emp_id] = {};
      att[row.emp_id][dateKey] = row;
    }

    // ── Approved leaves for entire range ──
    const [leaveRows] = await db.execute(
      `SELECT lm.emp_id, lm.leave_start_date, lm.leave_end_date,
              lt.leave_name, lm.is_half_day, lm.half_day_period
       FROM leave_master lm
       LEFT JOIN leave_type_master lt ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
       WHERE lm.tenant_id = ?
         AND lm.final_status = 'Approved'
         AND lm.leave_start_date <= ?
         AND lm.leave_end_date >= ?
         AND lm.emp_id IN (${placeholders})`,
      [tenantId, end, start, ...empIds],
    );

    // leave[emp_id][date] = leave record
    const leaveByEmpDate = {};
    for (const lv of leaveRows) {
      const lvStart = new Date(lv.leave_start_date);
      const lvEnd = new Date(lv.leave_end_date);
      const c = new Date(lvStart);
      while (c <= lvEnd) {
        const dk = c.toISOString().split("T")[0];
        if (dk >= start && dk <= end) {
          if (!leaveByEmpDate[lv.emp_id]) leaveByEmpDate[lv.emp_id] = {};
          leaveByEmpDate[lv.emp_id][dk] = lv;
        }
        c.setDate(c.getDate() + 1);
      }
    }

    // ── Merge per employee ──
    const data = employees.map((emp) => {
      const daily = allDates.map((date) => {
        const dayInfo = dateInfoMap[date];
        const record = att[emp.emp_id]?.[date] ?? null;
        const leave = leaveByEmpDate[emp.emp_id]?.[date] ?? null;

        let status = "Absent";
        if (dayInfo.type === "holiday") status = "Holiday";
        else if (dayInfo.type === "weekoff") status = "Week Off";
        else if (leave)
          status = leave.is_half_day ? "Half Day Leave" : "On Leave";
        else if (record) status = record.day_status ?? "Present";

        return {
          date,
          day_info: dayInfo,
          status,
          check_in_time: record?.check_in_time ?? null,
          check_out_time: record?.check_out_time ?? null,
          total_hours: record?.total_hours ?? null,
          is_late: record?.is_late ?? false,
          late_minutes: record?.late_minutes ?? 0,
          is_halfday: record?.is_halfday ?? false,
          overtime_minutes: record?.overtime_minutes ?? 0,
          work_location: record?.work_location ?? null,
          leave_name: leave?.leave_name ?? null,
          half_day_period: leave?.half_day_period ?? null,
        };
      });

      // Per-employee summary
      const workingDays = daily.filter((d) => d.day_info.type === "working");
      const summary = {
        total_days: allDates.length,
        working_days: workingDays.length,
        holidays: daily.filter((d) => d.day_info.type === "holiday").length,
        weekoffs: daily.filter((d) => d.day_info.type === "weekoff").length,
        present: workingDays.filter((d) => d.status === "Present").length,
        absent: workingDays.filter((d) => d.status === "Absent").length,
        on_leave: daily.filter((d) => d.status.includes("Leave")).length,
        late: workingDays.filter((d) => d.is_late).length,
        halfday: workingDays.filter((d) => d.is_halfday).length,
        overtime_days: workingDays.filter((d) => d.overtime_minutes > 0).length,
        total_overtime_minutes: workingDays.reduce(
          (sum, d) => sum + (d.overtime_minutes ?? 0),
          0,
        ),
      };

      return {
        emp_id: emp.emp_id,
        employee_code: emp.employee_code,
        employee_name: `${emp.first_name} ${emp.last_name}`.trim(),
        department: emp.department_name ?? "-",
        designation: emp.designation_name ?? "-",
        role: emp.role_name ?? "-",
        summary,
        daily,
      };
    });

    // ── Overall summary across all employees ──
    const overall = {
      total_employees: data.length,
      total_days: allDates.length,
      working_days: allDates.filter((d) => dateInfoMap[d].type === "working")
        .length,
      holidays: Object.values(holidayMap).length,
      weekoffs: allDates.filter((d) => dateInfoMap[d].type === "weekoff")
        .length,
      holiday_list: allDates
        .filter((d) => dateInfoMap[d].type === "holiday")
        .map((d) => ({ date: d, ...dateInfoMap[d].meta })),
      weekoff_dates: allDates.filter((d) => dateInfoMap[d].type === "weekoff"),
    };

    return send(res, 200, true, "Range report fetched", {
      start,
      end,
      policy: policy
        ? {
            office_in_time: policy.office_in_time,
            office_out_time: policy.office_out_time,
            late_after_minutes: policy.late_after_minutes,
            halfday_after_minutes: policy.halfday_after_minutes,
            overtime_after_minutes: policy.overtime_after_minutes,
          }
        : null,
      overall,
      data,
    });
  } catch (err) {
    console.error("[report/range]", err);
    return send(res, 500, false, "Internal server error");
  }
});

module.exports = router;
