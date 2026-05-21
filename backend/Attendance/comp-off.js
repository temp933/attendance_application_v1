  /**
   * comp-off.js
   * Compensatory Off management module.
   *
   * Depends on:
   *   - attendance.js  (getPolicy helper re-exported below for internal use)
   *   - holiday.js     (holiday look-ups)
   *   - ../config/db   (shared MySQL pool)
   *
   * Public API
   * ──────────
   *   generateCompOff(tenantId, attendanceId)   ← call after checkout
   *   validateCompOffEligibility(tenantId, attendanceId)
   *   getEmployeeCompOffs(tenantId, empId, filters)
   *   markCompOffUsed(tenantId, compOffId, leaveId)
   *   expireCompOffs()                          ← call from cron
   */

  "use strict";

  const express = require("express");
  const router = express.Router();
  const db = require("../config/db");
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
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /**
   * Fetch attendance_policy for a tenant.
   * Mirrors the same helper in attendance.js — kept here so this module is
   * self-contained; the two helpers are identical and hit the same table.
   */
  async function getPolicy(tenantId) {
    const [[policy]] = await db.query(
      `SELECT
          office_in_time,
          office_out_time,
          comp_off_enabled,
          comp_off_min_hours,
          comp_off_expiry_days,
          is_saturday_weekoff,
          is_sunday_weekoff
      FROM attendance_policy
      WHERE tenant_id = ?
      LIMIT 1`,
      [tenantId],
    );
    return policy ?? null;
  }

  /**
   * Look up a single completed attendance record.
   */
  async function getAttendanceRecord(tenantId, attendanceId) {
    const [[record]] = await db.query(
      `SELECT
          attendance_id,
          employee_id,
          DATE_FORMAT(work_date, '%Y-%m-%d') AS work_date,   -- ← plain string
          status,
          checkin_time,
          checkout_time,
          SEC_TO_TIME(
              TIMESTAMPDIFF(SECOND, checkin_time, checkout_time)
          ) AS worked_time_str,
          TIMESTAMPDIFF(SECOND, checkin_time, checkout_time) AS worked_seconds
      FROM employee_attendance
      WHERE tenant_id    = ?
        AND attendance_id = ?
        AND status        = 'completed'
        AND checkin_time  IS NOT NULL
        AND checkout_time IS NOT NULL`,
      [tenantId, attendanceId],
    );
    return record ?? null;
  }

  /**
   * Check whether a given date is a holiday for the tenant.
   * Returns the holiday row or null.
   */
  async function getHolidayOnDate(tenantId, workDate) {
    const [[holiday]] = await db.query(
      `SELECT holiday_id, holiday_name, holiday_type
      FROM holiday_master
      WHERE (tenant_id = ? OR tenant_id = 'global')
        AND holiday_date = ?
      LIMIT 1`,
      [tenantId, workDate],
    );
    return holiday ?? null;
  }

  /**
   * Returns 0 = Sunday … 6 = Saturday for a "YYYY-MM-DD" string.
   */
  function dayOfWeek(dateStr) {
    return new Date(dateStr).getDay();
  }

  /**
   * Seconds → decimal hours, rounded to 2 dp.
   */
  function secondsToHours(seconds) {
    return Math.round((seconds / 3600) * 100) / 100;
  }

  /**
   * Add `days` to a "YYYY-MM-DD" string and return a new "YYYY-MM-DD" string.
   */
  function addDays(dateStr, days) {
    const d = new Date(dateStr);
    d.setDate(d.getDate() + days);
    return d.toISOString().slice(0, 10);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Core service functions
  // ─────────────────────────────────────────────────────────────────────────────

  /**
   * validateCompOffEligibility
   *
   * Checks all rules and returns a detailed eligibility object.
   * Does NOT write to the DB.
   *
   * @returns {Object} { eligible, reason, hoursWorked, policy, holiday, isWeekoff }
   */
  async function validateCompOffEligibility(tenantId, attendanceId) {
    // 1. Policy check
    const policy = await getPolicy(tenantId);
    if (!policy) {
      return { eligible: false, reason: "No attendance policy configured." };
    }
    if (!policy.comp_off_enabled) {
      return { eligible: false, reason: "Comp-off is disabled by policy." };
    }

    // 2. Attendance record check
    const record = await getAttendanceRecord(tenantId, attendanceId);
    if (!record) {
      return {
        eligible: false,
        reason: "Attendance record not found or not yet completed.",
      };
    }

    const hoursWorked = secondsToHours(record.worked_seconds ?? 0);
    const minHours = policy.comp_off_min_hours ?? 4;

    console.log(
      `[CompOff] attendance_id=${attendanceId} date=${record.work_date} ` +
        `hours_worked=${hoursWorked} min_required=${minHours}`,
    );

    if (hoursWorked < minHours) {
      return {
        eligible: false,
        reason: `Worked ${hoursWorked}h — minimum ${minHours}h required.`,
        hoursWorked,
        policy,
      };
    }

    // 3. Holiday check
    const holiday = await getHolidayOnDate(tenantId, record.work_date);
    if (holiday) {
      console.log(
        `[CompOff] Holiday detected: "${holiday.holiday_name}" on ${record.work_date}`,
      );
      return {
        eligible: true,
        reason: `Worked on holiday "${holiday.holiday_name}".`,
        hoursWorked,
        policy,
        holiday,
        isWeekoff: false,
      };
    }

    // 4. Weekoff check
    const dow = dayOfWeek(record.work_date); // 0=Sun, 6=Sat
    const isSundayWeekoff = policy.is_sunday_weekoff === 1;
    const isSaturdayWeekoff = policy.is_saturday_weekoff === 1;

    if (dow === 0 && isSundayWeekoff) {
      console.log(`[CompOff] Sunday weekoff detected on ${record.work_date}`);
      return {
        eligible: true,
        reason: "Worked on Sunday (weekly off).",
        hoursWorked,
        policy,
        holiday: null,
        isWeekoff: true,
      };
    }
    if (dow === 6 && isSaturdayWeekoff) {
      console.log(`[CompOff] Saturday weekoff detected on ${record.work_date}`);
      return {
        eligible: true,
        reason: "Worked on Saturday (weekly off).",
        hoursWorked,
        policy,
        holiday: null,
        isWeekoff: true,
      };
    }

    return {
      eligible: false,
      reason: "Attendance date is not a holiday or a weekly off.",
      hoursWorked,
      policy,
    };
  }

  /**
   * generateCompOff
   *
   * Validates eligibility then inserts a comp_off record if eligible.
   * Silently skips if a record already exists for this attendance_id (idempotent).
   *
   * @returns {Object} { created, skipped, reason, compOff? }
   */
  async function generateCompOff(tenantId, attendanceId) {
    // Duplicate guard — one comp_off per attendance_id
    const [[existing]] = await db.query(
      `SELECT id FROM comp_off WHERE attendance_id = ? LIMIT 1`,
      [attendanceId],
    );
    if (existing) {
      console.log(
        `[CompOff] Duplicate skipped — comp_off already exists for attendance_id=${attendanceId}`,
      );
      return {
        created: false,
        skipped: true,
        reason: "Comp-off already exists for this attendance record.",
      };
    }

    const eligibility = await validateCompOffEligibility(tenantId, attendanceId);
    if (!eligibility.eligible) {
      console.log(
        `[CompOff] Not eligible — attendance_id=${attendanceId}: ${eligibility.reason}`,
      );
      return { created: false, skipped: false, reason: eligibility.reason };
    }

    // Fetch the record again to get employee_id and work_date
    const record = await getAttendanceRecord(tenantId, attendanceId);
    const expiryDate = addDays(
      record.work_date,
      eligibility.policy.comp_off_expiry_days ?? 30,
    );

    const remarks = eligibility.holiday
      ? `Worked on holiday: ${eligibility.holiday.holiday_name}`
      : eligibility.isWeekoff
        ? `Worked on weekly off (${dayOfWeek(record.work_date) === 0 ? "Sunday" : "Saturday"})`
        : eligibility.reason;

    const [result] = await db.query(
      `INSERT INTO comp_off
        (tenant_id, employee_id, attendance_id, earned_date, expiry_date, status, remarks)
      VALUES (?, ?, ?, ?, ?, 'earned', ?)`,
      [
        tenantId,
        record.employee_id,
        attendanceId,
        record.work_date,
        expiryDate,
        remarks,
      ],
    );

    console.log(
      `[CompOff] Generated — id=${result.insertId} employee_id=${record.employee_id} ` +
        `earned_date=${record.work_date} expiry=${expiryDate} reason="${remarks}"`,
    );

    return {
      created: true,
      skipped: false,
      reason: remarks,
      compOff: {
        id: result.insertId,
        earned_date: record.work_date,
        expiry_date: expiryDate,
        status: "earned",
        remarks,
      },
    };
  }

  /**
   * getEmployeeCompOffs
   *
   * Retrieves comp_off entries for an employee with optional status filter.
   *
   * @param {Object} filters  { status?: 'earned'|'used'|'expired', limit?, offset? }
   */
  async function getEmployeeCompOffs(tenantId, empId, filters = {}) {
    const { status, limit = 50, offset = 0 } = filters;
    const safeLimit = Math.min(Number(limit), 200);
    const safeOffset = Number(offset);

    const whereClauses = ["co.tenant_id = ?", "co.employee_id = ?"];
    const params = [tenantId, empId];

    if (status) {
      whereClauses.push("co.status = ?");
      params.push(status);
    }

    const [rows] = await db.query(
      `SELECT
          co.id,
          co.attendance_id,
          co.leave_id,
          DATE_FORMAT(co.earned_date,  '%Y-%m-%d') AS earned_date,   -- ← fix
          DATE_FORMAT(co.expiry_date,  '%Y-%m-%d') AS expiry_date,   -- ← fix
          co.status,
          co.remarks,
          co.created_at,
          DATE_FORMAT(ea.work_date,    '%Y-%m-%d') AS work_date,     -- ← fix
          ea.checkin_time,
          ea.checkout_time,
          SEC_TO_TIME(
              TIMESTAMPDIFF(SECOND, ea.checkin_time, ea.checkout_time)
          ) AS worked_time
      FROM comp_off co
      LEFT JOIN employee_attendance ea
              ON ea.attendance_id = co.attendance_id
      WHERE ${whereClauses.join(" AND ")}
      ORDER BY co.earned_date DESC
      LIMIT ? OFFSET ?`,
      [...params, safeLimit, safeOffset],
    );

    // Summary counts
    const [[summary]] = await db.query(
      `SELECT
          COUNT(*)               AS total,
          SUM(status = 'earned') AS earned,
          SUM(status = 'used')   AS used,
          SUM(status = 'expired') AS expired
      FROM comp_off
      WHERE tenant_id   = ?
        AND employee_id = ?`,
      [tenantId, empId],
    );

    return { records: rows, summary };
  }

  /**
   * markCompOffUsed
   *
   * Marks a specific comp_off record as 'used' and links it to a leave request.
   * Validates ownership and current status before updating.
   */
  async function markCompOffUsed(tenantId, empId, compOffId, leaveId = null) {
    const [[record]] = await db.query(
      `SELECT id, status, expiry_date
      FROM comp_off
      WHERE id          = ?
        AND tenant_id   = ?
        AND employee_id = ?
      LIMIT 1`,
      [compOffId, tenantId, empId],
    );

    if (!record) {
      throw Object.assign(new Error("Comp-off record not found."), {
        status: 404,
      });
    }
    if (record.status !== "earned") {
      throw Object.assign(
        new Error(`Cannot use a comp-off with status '${record.status}'.`),
        { status: 409 },
      );
    }
    if (new Date(record.expiry_date) < new Date()) {
      throw Object.assign(new Error("This comp-off has expired."), {
        status: 409,
      });
    }

    await db.query(
      `UPDATE comp_off SET status = 'used', leave_id = ? WHERE id = ?`,
      [leaveId, compOffId],
    );

    console.log(
      `[CompOff] Marked used — id=${compOffId} leave_id=${leaveId} employee_id=${empId}`,
    );

    return { success: true, message: "Comp-off marked as used." };
  }

  /**
   * expireCompOffs
   *
   * Batch-expires all 'earned' comp_offs whose expiry_date < TODAY.
   * Intended to be called from a daily cron job.
   *
   * @returns {number} Number of records expired.
   */
  async function expireCompOffs() {
    const today = new Date().toISOString().slice(0, 10);

    const [result] = await db.query(
      `UPDATE comp_off
      SET status = 'expired'
      WHERE status     = 'earned'
        AND expiry_date < ?`,
      [today],
    );

    console.log(`[CompOff] Expired ${result.affectedRows} comp-off record(s).`);
    return result.affectedRows;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Routes
  // ─────────────────────────────────────────────────────────────────────────────

  /**
   * GET /api/comp-off
   * Returns comp-offs for the authenticated employee.
   * Query: ?status=earned|used|expired&limit=50&offset=0
   */
  router.get("/", requireAuth, async (req, res) => {
    const { tenantId, empId } = req.user;
    try {
      const { status, limit, offset } = req.query;
      const data = await getEmployeeCompOffs(tenantId, empId, {
        status: status || undefined,
        limit,
        offset,
      });
      res.json({ success: true, ...data });
    } catch (err) {
      console.error("[GET /comp-off]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  });

  /**
   * GET /api/comp-off/eligibility/:attendanceId
   * Dry-run eligibility check — does NOT create anything.
   */
  router.get("/eligibility/:attendanceId", requireAuth, async (req, res) => {
    const { tenantId } = req.user;
    const attendanceId = parseInt(req.params.attendanceId, 10);
    if (isNaN(attendanceId)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid attendance ID." });
    }
    try {
      const result = await validateCompOffEligibility(tenantId, attendanceId);
      res.json({ success: true, ...result });
    } catch (err) {
      console.error("[GET /comp-off/eligibility]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  });

  /**
   * POST /api/comp-off/generate
   * Body: { attendance_id }
   * Manually trigger comp-off generation (useful for backfill / admin).
   */
  router.post("/generate", requireAuth, async (req, res) => {
    const { tenantId } = req.user;
    const attendanceId = parseInt(req.body.attendance_id, 10);
    if (isNaN(attendanceId)) {
      return res
        .status(400)
        .json({ success: false, message: "attendance_id required." });
    }
    try {
      const result = await generateCompOff(tenantId, attendanceId);
      const status = result.created ? 201 : 200;
      res.status(status).json({ success: true, ...result });
    } catch (err) {
      console.error("[POST /comp-off/generate]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  });

  /**
   * PATCH /api/comp-off/:id/use
   * Body: { leave_id? }
   * Mark a specific comp-off as used (called when a leave is approved).
   */
  router.patch("/:id/use", requireAuth, async (req, res) => {
    const { tenantId, empId } = req.user;
    const compOffId = parseInt(req.params.id, 10);
    const leaveId = req.body.leave_id ? parseInt(req.body.leave_id, 10) : null;

    if (isNaN(compOffId)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid comp-off ID." });
    }
    try {
      const result = await markCompOffUsed(tenantId, empId, compOffId, leaveId);
      res.json(result);
    } catch (err) {
      const httpStatus = err.status ?? 500;
      console.error("[PATCH /comp-off/:id/use]", err);
      res.status(httpStatus).json({ success: false, message: err.message });
    }
  });

  /**
   * POST /api/comp-off/expire
   * Cron-triggered endpoint — requires x-cron-secret header.
   * Expires all overdue comp-offs.
   */
  router.post("/expire", async (req, res) => {
    if (req.headers["x-cron-secret"] !== process.env.AUTO_CHECKOUT_SECRET) {
      return res.status(401).json({ success: false, message: "Unauthorized." });
    }
    try {
      const expired = await expireCompOffs();
      res.json({
        success: true,
        message: `${expired} comp-off(s) expired.`,
        expired,
      });
    } catch (err) {
      console.error("[POST /comp-off/expire]", err);
      res.status(500).json({ success: false, message: "Server error." });
    }
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Module exports — export service functions for use in attendance.js
  // ─────────────────────────────────────────────────────────────────────────────
  module.exports = router;
  module.exports.generateCompOff = generateCompOff;
  module.exports.validateCompOffEligibility = validateCompOffEligibility;
  module.exports.getEmployeeCompOffs = getEmployeeCompOffs;
  module.exports.markCompOffUsed = markCompOffUsed;
  module.exports.expireCompOffs = expireCompOffs;
