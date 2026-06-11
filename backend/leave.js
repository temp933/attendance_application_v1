"use strict";

const express = require("express");
const db = require("./config/db");
const router = express.Router();

// ─── Shared Helpers ────────────────────────────────────────────────────────────

const getTenantId = (req) =>
  req.user?.tenant_id || req.user?.tenantId || req.headers["x-tenant-id"] || "";

const send = (res, status, ok, message, data = {}) =>
  res.status(status).json({ ok, message, ...data });

async function calcDays(conn, tenantId, startDate, endDate, isHalfDay) {
  if (isHalfDay) return 0.5;

  // 1. Fetch attendance policy for weekoff config
  const [[policy]] = await conn.execute(
    `SELECT is_saturday_weekoff, is_sunday_weekoff
     FROM attendance_policy WHERE tenant_id = ? LIMIT 1`,
    [tenantId],
  );
  const skipSat = policy?.is_saturday_weekoff === 1;
  const skipSun = policy?.is_sunday_weekoff === 1;

  // 2. Fetch all holidays in the date range from holiday_master

  const toLocalDate = (d) => {
    const dt = new Date(d);
    return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}`;
  };
  const startStr = toLocalDate(startDate);
  const endStr = toLocalDate(endDate);

  const [holidayRows] = await conn.execute(
    `SELECT holiday_date FROM holiday_master
     WHERE tenant_id = ?
       AND holiday_date BETWEEN ? AND ?`,
    [tenantId, startStr, endStr],
  );

  // Build a Set of holiday date strings "YYYY-MM-DD" for O(1) lookup
  const holidaySet = new Set(
    holidayRows.map((h) => {
      const d = new Date(h.holiday_date);
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }),
  );

  // 3. Count only working days
  let count = 0;
  const cur = new Date(startDate);
  const end = new Date(endDate);

  while (cur <= end) {
    const day = cur.getDay();
    const dateStr = `${cur.getFullYear()}-${String(cur.getMonth() + 1).padStart(2, "0")}-${String(cur.getDate()).padStart(2, "0")}`;

    const isWeekend = (skipSun && day === 0) || (skipSat && day === 6);
    const isHoliday = holidaySet.has(dateStr);

    if (!isWeekend && !isHoliday) count++;

    cur.setDate(cur.getDate() + 1);
  }

  return count;
}

/**
 * Walk up the reporting chain N levels from empId.
 * Returns an ordered array of resolved emp_ids (level 1 first).
 * Stops early if the chain breaks (no reporting_to_employee_id found).
 */
async function resolveReportingChain(conn, tenantId, empId, levels) {
  const chain = [];
  let currentId = empId;

  for (let i = 0; i < levels; i++) {
    const [[row]] = await conn.execute(
      `SELECT reporting_to_employee_id FROM employee_master
          WHERE emp_id = ? AND tenant_id = ? LIMIT 1`,
      [currentId, tenantId],
    );
    const nextId = row?.reporting_to_employee_id ?? null;
    if (!nextId) break; // chain ends here
    chain.push(nextId);
    currentId = nextId;
  }

  return chain; // e.g. [rmId, rmOfRmId, rmOfRmOfRmId]
}

/**
 * Adjust leave_balance for paid leave types.
 * action: 'pending'    → +pending_days
 *         'approve'    → -pending_days, +used_days
 *         'reject'     → -pending_days
 *         'cancel_pending'  → -pending_days
 *         'cancel_approved' → -used_days
 */
async function updateLeaveBalance(
  conn,
  tenantId,
  empId,
  leaveTypeId,
  days,
  action,
) {
  // Only touch balance for paid leave
  const [[lt]] = await conn.execute(
    `SELECT leave_name, is_paid FROM leave_type_master
     WHERE leave_type_id = ? AND tenant_id = ? LIMIT 1`,
    [leaveTypeId, tenantId],
  );
  if (!lt || !lt.is_paid) return; // unpaid / comp-off → skip

  const leaveType = lt.leave_name;
  const year = new Date().getFullYear();

  // Upsert row if missing
  await conn.execute(
    `INSERT INTO leave_balance (emp_id, leave_type, year, allocated_days, used_days, pending_days, carry_forward, tenant_id)
     VALUES (?, ?, ?, 0, 0, 0, 0, ?)
     ON DUPLICATE KEY UPDATE balance_id = balance_id`,
    [empId, leaveType, year, tenantId],
  );

  let sql = "";
  switch (action) {
    case "pending":
      sql = `UPDATE leave_balance
             SET pending_days = GREATEST(0, pending_days + ?), updated_at = NOW()
             WHERE emp_id = ? AND leave_type = ? AND year = ? AND tenant_id = ?`;
      break;
    case "approve":
      sql = `UPDATE leave_balance
             SET pending_days = GREATEST(0, pending_days - ?),
                 used_days    = used_days + ?, updated_at = NOW()
             WHERE emp_id = ? AND leave_type = ? AND year = ? AND tenant_id = ?`;
      // approve needs days twice in params
      await conn.execute(sql, [days, days, empId, leaveType, year, tenantId]);
      return;
    case "reject":
    case "cancel_pending":
      sql = `UPDATE leave_balance
             SET pending_days = GREATEST(0, pending_days - ?), updated_at = NOW()
             WHERE emp_id = ? AND leave_type = ? AND year = ? AND tenant_id = ?`;
      break;
    case "cancel_approved":
      sql = `UPDATE leave_balance
             SET used_days = GREATEST(0, used_days - ?), updated_at = NOW()
             WHERE emp_id = ? AND leave_type = ? AND year = ? AND tenant_id = ?`;
      break;
    default:
      return;
  }
  await conn.execute(sql, [days, empId, leaveType, year, tenantId]);
}

/**
 * Validate approval_rules array sent from admin UI.
 * Each rule: { min_days, max_days (null = unlimited), approval_levels }
 */
function validateApprovalRules(approval_rules) {
  if (!Array.isArray(approval_rules) || approval_rules.length === 0)
    return "approval_rules array is mandatory and must not be empty";

  for (let i = 0; i < approval_rules.length; i++) {
    const r = approval_rules[i];
    const min = Number(r.min_days);
    const max =
      r.max_days === null || r.max_days === undefined
        ? null
        : Number(r.max_days);
    const levels = Number(r.approval_levels);

    if (isNaN(min) || min < 0.5)
      return `Rule ${i + 1}: min_days must be >= 0.5`;
    if (max !== null && (isNaN(max) || max < min))
      return `Rule ${i + 1}: max_days must be >= min_days or null`;
    if (isNaN(levels) || levels < 1 || !Number.isInteger(levels))
      return `Rule ${i + 1}: approval_levels must be a positive integer`;
  }

  // Check for overlapping ranges
  const sorted = [...approval_rules].sort(
    (a, b) => Number(a.min_days) - Number(b.min_days),
  );
  for (let i = 0; i < sorted.length - 1; i++) {
    const curMax =
      sorted[i].max_days === null ? Infinity : Number(sorted[i].max_days);
    const nextMin = Number(sorted[i + 1].min_days);
    if (nextMin <= curMax)
      return `Rules overlap: range ending at ${curMax} conflicts with range starting at ${nextMin}`;
  }

  return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEAVE POLICY ROUTES
// ═══════════════════════════════════════════════════════════════════════════════

// ─── 1. Create Leave Policy   POST /api/leave/policy/create ───────────────────

router.post("/policy/create", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const {
    leave_name,
    max_days,
    is_paid,
    requires_approval,
    approval_rules = [],
    carry_forward_enabled = false,
    carry_forward_type = null,
    max_carry_forward_days = null,
    time_accrual_enabled = false,
    time_accrual_type = null,
    time_accrual_days = null,
    attendance_accrual_enabled = false,
    attendance_accrual_streak = null,
    attendance_accrual_reward = null,
  } = req.body;
  if (!leave_name || typeof leave_name !== "string" || !leave_name.trim())
    return send(res, 400, false, "leave_name is required");
  if (!max_days || isNaN(Number(max_days)) || Number(max_days) <= 0)
    return send(res, 400, false, "max_days must be a positive number");
  if (time_accrual_enabled) {
    if (
      !time_accrual_type ||
      !["yearly", "monthly"].includes(time_accrual_type)
    )
      return send(
        res,
        400,
        false,
        "time_accrual_type must be yearly or monthly",
      );
    if (
      !time_accrual_days ||
      isNaN(Number(time_accrual_days)) ||
      Number(time_accrual_days) <= 0
    )
      return send(res, 400, false, "time_accrual_days must be > 0");
  }
  if (attendance_accrual_enabled) {
    if (
      !attendance_accrual_streak ||
      isNaN(Number(attendance_accrual_streak)) ||
      Number(attendance_accrual_streak) < 1
    )
      return send(res, 400, false, "attendance_accrual_streak must be >= 1");
    if (
      !attendance_accrual_reward ||
      isNaN(Number(attendance_accrual_reward)) ||
      Number(attendance_accrual_reward) <= 0
    )
      return send(res, 400, false, "attendance_accrual_reward must be > 0");
  }

  // Only validate rules when approval is required
  if (requires_approval) {
    const rulesError = validateApprovalRules(approval_rules);
    if (rulesError) return send(res, 400, false, rulesError);
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const cfType = carry_forward_enabled
      ? (carry_forward_type ?? "yearly")
      : null;
    const cfMax =
      carry_forward_enabled && max_carry_forward_days != null
        ? Number(max_carry_forward_days)
        : null;
    const taType = time_accrual_enabled
      ? (time_accrual_type ?? "yearly")
      : null;
    const taDays =
      time_accrual_enabled && time_accrual_days != null
        ? Number(time_accrual_days)
        : null;
    const aaStreak =
      attendance_accrual_enabled && attendance_accrual_streak != null
        ? Number(attendance_accrual_streak)
        : null;
    const aaReward =
      attendance_accrual_enabled && attendance_accrual_reward != null
        ? Number(attendance_accrual_reward)
        : null;

    const [ltResult] = await conn.execute(
      `INSERT INTO leave_type_master
            (tenant_id, leave_name, max_days, is_paid, requires_approval,
             carry_forward_enabled, carry_forward_type, max_carry_forward_days,
             time_accrual_enabled, time_accrual_type, time_accrual_days,
             attendance_accrual_enabled, attendance_accrual_streak, attendance_accrual_reward,
             created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        tenant_id,
        leave_name.trim(),
        Number(max_days),
        is_paid ? 1 : 0,
        requires_approval ? 1 : 0,
        carry_forward_enabled ? 1 : 0,
        cfType,
        cfMax,
        time_accrual_enabled ? 1 : 0,
        taType,
        taDays,
        attendance_accrual_enabled ? 1 : 0,
        aaStreak,
        aaReward,
      ],
    );
    const leave_type_id = ltResult.insertId;

    if (requires_approval && approval_rules.length > 0) {
      for (const rule of approval_rules) {
        await conn.execute(
          `INSERT INTO leave_approval_rules
                (tenant_id, leave_type_id, min_days, max_days, approval_levels, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, NOW(), NOW())`,
          [
            tenant_id,
            leave_type_id,
            Number(rule.min_days),
            rule.max_days === null || rule.max_days === undefined
              ? null
              : Number(rule.max_days),
            Number(rule.approval_levels),
          ],
        );
      }
    }

    await conn.commit();
    return send(res, 201, true, "Leave policy created successfully", {
      leave_type_id,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[leave/policy/create]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 2. List Leave Policies   GET /api/leave/policy/list ─────────────────────

router.get("/policy/list", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  try {
    const [rows] = await db.execute(
      `SELECT
            lt.leave_type_id, lt.leave_code, lt.leave_name, lt.max_days, lt.is_paid,
            lt.requires_approval, lt.is_system, lt.is_active, lt.created_at, lt.updated_at,
            lt.carry_forward_enabled, lt.carry_forward_type, lt.max_carry_forward_days,
            lt.time_accrual_enabled, lt.time_accrual_type, lt.time_accrual_days,
            lt.attendance_accrual_enabled, lt.attendance_accrual_streak, lt.attendance_accrual_reward,
            COUNT(lar.id) AS total_approval_rules
          FROM leave_type_master lt
          LEFT JOIN leave_approval_rules lar
            ON lt.leave_type_id = lar.leave_type_id AND lar.tenant_id = lt.tenant_id
          WHERE lt.tenant_id = ?
          GROUP BY lt.leave_type_id, lt.leave_code, lt.leave_name, lt.max_days,
                    lt.is_paid, lt.requires_approval, lt.is_system, lt.is_active,
                    lt.created_at, lt.updated_at,
                    lt.carry_forward_enabled, lt.carry_forward_type, lt.max_carry_forward_days,
                    lt.time_accrual_enabled, lt.time_accrual_type, lt.time_accrual_days,
                    lt.attendance_accrual_enabled, lt.attendance_accrual_streak, lt.attendance_accrual_reward
          ORDER BY lt.is_system ASC, lt.created_at DESC`,
      [tenant_id],
    );
    return send(res, 200, true, "Leave policies fetched", { data: rows });
  } catch (err) {
    console.error("[leave/policy/list]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 3. Get Single Leave Policy   GET /api/leave/policy/:leave_type_id ────────

router.get("/policy/:leave_type_id", async (req, res) => {
  const tenant_id = getTenantId(req);
  const { leave_type_id } = req.params;

  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");
  if (!leave_type_id || isNaN(Number(leave_type_id)))
    return send(res, 400, false, "Invalid leave_type_id");

  try {
    const [[leaveType]] = await db.execute(
      `SELECT * FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );
    if (!leaveType) return send(res, 404, false, "Leave policy not found");

    const [approvalRules] = await db.execute(
      `SELECT id, min_days, max_days, approval_levels, created_at
          FROM leave_approval_rules
          WHERE leave_type_id = ? AND tenant_id = ?
          ORDER BY min_days ASC`,
      [leave_type_id, tenant_id],
    );

    return send(res, 200, true, "Leave policy fetched", {
      data: { ...leaveType, approval_rules: approvalRules },
    });
  } catch (err) {
    console.error("[leave/policy/:id]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 4. Update Leave Policy   PUT /api/leave/policy/update/:leave_type_id ─────

router.put("/policy/update/:leave_type_id", async (req, res) => {
  const tenant_id = getTenantId(req);
  const { leave_type_id } = req.params;
  const {
    leave_name,
    max_days,
    is_paid,
    requires_approval,
    approval_rules = [],
    carry_forward_enabled = false,
    carry_forward_type = null,
    max_carry_forward_days = null,
    time_accrual_enabled = false,
    time_accrual_type = null,
    time_accrual_days = null,
    attendance_accrual_enabled = false,
    attendance_accrual_streak = null,
    attendance_accrual_reward = null,
  } = req.body;

  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");
  if (!leave_type_id || isNaN(Number(leave_type_id)))
    return send(res, 400, false, "Invalid leave_type_id");
  if (!leave_name || typeof leave_name !== "string" || !leave_name.trim())
    return send(res, 400, false, "leave_name is required");
  if (!max_days || isNaN(Number(max_days)) || Number(max_days) <= 0)
    return send(res, 400, false, "max_days must be a positive number");
  if (time_accrual_enabled) {
    if (
      !time_accrual_type ||
      !["yearly", "monthly"].includes(time_accrual_type)
    )
      return send(
        res,
        400,
        false,
        "time_accrual_type must be yearly or monthly",
      );
    if (
      !time_accrual_days ||
      isNaN(Number(time_accrual_days)) ||
      Number(time_accrual_days) <= 0
    )
      return send(res, 400, false, "time_accrual_days must be > 0");
  }
  if (attendance_accrual_enabled) {
    if (
      !attendance_accrual_streak ||
      isNaN(Number(attendance_accrual_streak)) ||
      Number(attendance_accrual_streak) < 1
    )
      return send(res, 400, false, "attendance_accrual_streak must be >= 1");
    if (
      !attendance_accrual_reward ||
      isNaN(Number(attendance_accrual_reward)) ||
      Number(attendance_accrual_reward) <= 0
    )
      return send(res, 400, false, "attendance_accrual_reward must be > 0");
  }

  if (requires_approval) {
    const rulesError = validateApprovalRules(approval_rules);
    if (rulesError) return send(res, 400, false, rulesError);
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[existing]] = await conn.execute(
      `SELECT leave_type_id, is_system FROM leave_type_master
          WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );
    if (!existing) {
      await conn.rollback();
      return send(res, 404, false, "Leave policy not found");
    }

    const cfType = carry_forward_enabled
      ? (carry_forward_type ?? "yearly")
      : null;
    const cfMax =
      carry_forward_enabled && max_carry_forward_days != null
        ? Number(max_carry_forward_days)
        : null;
    const taType = time_accrual_enabled
      ? (time_accrual_type ?? "yearly")
      : null;
    const taDays =
      time_accrual_enabled && time_accrual_days != null
        ? Number(time_accrual_days)
        : null;
    const aaStreak =
      attendance_accrual_enabled && attendance_accrual_streak != null
        ? Number(attendance_accrual_streak)
        : null;
    const aaReward =
      attendance_accrual_enabled && attendance_accrual_reward != null
        ? Number(attendance_accrual_reward)
        : null;

    await conn.execute(
      `UPDATE leave_type_master
          SET leave_name = ?, max_days = ?, is_paid = ?, requires_approval = ?,
              carry_forward_enabled = ?, carry_forward_type = ?, max_carry_forward_days = ?,
              time_accrual_enabled = ?, time_accrual_type = ?, time_accrual_days = ?,
              attendance_accrual_enabled = ?, attendance_accrual_streak = ?, attendance_accrual_reward = ?,
              updated_at = NOW()
          WHERE leave_type_id = ? AND tenant_id = ?`,
      [
        leave_name.trim(),
        Number(max_days),
        is_paid ? 1 : 0,
        requires_approval ? 1 : 0,
        carry_forward_enabled ? 1 : 0,
        cfType,
        cfMax,
        time_accrual_enabled ? 1 : 0,
        taType,
        taDays,
        attendance_accrual_enabled ? 1 : 0,
        aaStreak,
        aaReward,
        leave_type_id,
        tenant_id,
      ],
    );

    // Replace all existing rules for this policy
    await conn.execute(
      `DELETE FROM leave_approval_rules WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );

    if (requires_approval && approval_rules.length > 0) {
      for (const rule of approval_rules) {
        await conn.execute(
          `INSERT INTO leave_approval_rules
                (tenant_id, leave_type_id, min_days, max_days, approval_levels, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, NOW(), NOW())`,
          [
            tenant_id,
            leave_type_id,
            Number(rule.min_days),
            rule.max_days === null || rule.max_days === undefined
              ? null
              : Number(rule.max_days),
            Number(rule.approval_levels),
          ],
        );
      }
    }

    await conn.commit();
    return send(res, 200, true, "Leave policy updated successfully");
  } catch (err) {
    await conn.rollback();
    console.error("[leave/policy/update]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 5. Delete Leave Policy   DELETE /api/leave/policy/delete/:leave_type_id ──

router.delete("/policy/delete/:leave_type_id", async (req, res) => {
  const tenant_id = getTenantId(req);
  const { leave_type_id } = req.params;

  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");
  if (!leave_type_id || isNaN(Number(leave_type_id)))
    return send(res, 400, false, "Invalid leave_type_id");

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[existing]] = await conn.execute(
      `SELECT leave_type_id FROM leave_type_master
          WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );
    if (!existing) {
      await conn.rollback();
      return send(res, 404, false, "Leave policy not found");
    }

    if (existing.is_system === 1) {
      await conn.rollback();
      return send(res, 403, false, "System leave types cannot be deleted");
    }

    await conn.execute(
      `DELETE FROM leave_approval_rules WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );
    await conn.execute(
      `DELETE FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );

    await conn.commit();
    return send(res, 200, true, "Leave policy deleted successfully");
  } catch (err) {
    await conn.rollback();
    console.error("[leave/policy/delete]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// EMPLOYEE LEAVE ROUTES
// ═══════════════════════════════════════════════════════════════════════════════

// ─── 6. Apply Leave   POST /api/leave/apply ───────────────────────────────────

router.post("/apply", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  const {
    leave_type_id,
    leave_start_date,
    leave_end_date,
    is_half_day = false,
    half_day_period = null,
    reason,
  } = req.body;

  if (!leave_type_id) return send(res, 400, false, "leave_type_id is required");
  if (!leave_start_date)
    return send(res, 400, false, "leave_start_date is required");
  if (!leave_end_date)
    return send(res, 400, false, "leave_end_date is required");
  if (!reason || !reason.trim())
    return send(res, 400, false, "reason is required");

  const startDt = new Date(leave_start_date);
  const endDt = new Date(leave_end_date);
  if (isNaN(startDt) || isNaN(endDt))
    return send(res, 400, false, "Invalid date format. Use YYYY-MM-DD");
  if (startDt > endDt)
    return send(res, 400, false, "leave_start_date must be <= leave_end_date");

  if (is_half_day) {
    const sameDay =
      leave_start_date === leave_end_date ||
      startDt.toDateString() === endDt.toDateString();
    if (!sameDay)
      return send(
        res,
        400,
        false,
        "Half day is allowed only for a single date",
      );
    if (!["AM", "PM"].includes(half_day_period))
      return send(
        res,
        400,
        false,
        "half_day_period must be AM or PM for half day",
      );
  }

  const conn = await db.getConnection();
  try {
    const number_of_days = await calcDays(
      conn,
      tenant_id,
      startDt,
      endDt,
      is_half_day,
    );
    if (number_of_days === 0) {
      return send(
        res,
        400,
        false,
        "Selected date range contains no working days",
      );
    }
    await conn.beginTransaction();

    // ── Verify employee belongs to tenant ──
    const [[empRow]] = await conn.execute(
      `SELECT emp_id FROM employee_master
          WHERE emp_id = ? AND tenant_id = ? LIMIT 1`,
      [emp_id, tenant_id],
    );
    if (!empRow) {
      await conn.rollback();
      return send(res, 403, false, "Employee does not belong to this tenant");
    }

    // ── Fetch leave type / policy ──
    const [[policy]] = await conn.execute(
      `SELECT leave_type_id, leave_code, requires_approval
          FROM leave_type_master
          WHERE leave_type_id = ? AND tenant_id = ? AND is_active = 1 LIMIT 1`,
      [leave_type_id, tenant_id],
    );
    if (!policy) {
      await conn.rollback();
      return send(res, 404, false, "Leave policy not found for this tenant");
    }

    const isCompOff = (policy.leave_code ?? "").toUpperCase() === "COMP_OFF";

    // ── Comp-off balance check ──
    if (isCompOff) {
      const empIdInt = parseInt(emp_id, 10);
      const [[bal]] = await conn.execute(
        `SELECT COUNT(*) AS available FROM comp_off
            WHERE tenant_id = ? AND employee_id = ?
              AND status = 'earned' AND expiry_date >= CURDATE()`,
        [tenant_id, empIdInt],
      );
      if (number_of_days > (bal?.available ?? 0)) {
        await conn.rollback();
        return send(
          res,
          422,
          false,
          `Insufficient comp-off balance. Available: ${bal?.available ?? 0}`,
        );
      }
    }

    // ── Overlap check ──
    const [[overlap]] = await conn.execute(
      `SELECT leave_id FROM leave_master
          WHERE tenant_id = ? AND emp_id = ?
            AND final_status NOT IN ('Rejected','Cancelled')
            AND leave_start_date <= ? AND leave_end_date >= ?
          LIMIT 1`,
      [tenant_id, emp_id, leave_end_date, leave_start_date],
    );
    if (overlap) {
      await conn.rollback();
      return send(
        res,
        409,
        false,
        "Overlapping leave already exists for the selected dates",
      );
    }

    // ── Resolve approval chain via leave_approval_rules ──
    // Find the rule whose range covers number_of_days
    const [[matchedRule]] = await conn.execute(
      `SELECT approval_levels FROM leave_approval_rules
          WHERE leave_type_id = ? AND tenant_id = ?
            AND min_days <= ?
            AND (max_days IS NULL OR max_days >= ?)
          ORDER BY min_days ASC
          LIMIT 1`,
      [leave_type_id, tenant_id, number_of_days, number_of_days],
    );

    // levels = 0 means auto-approve (no rule matched or approval not required)
    if (policy.requires_approval && !matchedRule) {
      await conn.rollback();
      return send(
        res,
        422,
        false,
        `No approval rule configured for ${number_of_days} day(s) of leave. Please contact your HR admin.`,
      );
    }
    const approvalLevels = !policy.requires_approval
      ? 0
      : matchedRule.approval_levels;

    // ── Leave balance check (paid leaves only) ──
    if (!isCompOff) {
      const [[ltCheck]] = await conn.execute(
        `SELECT leave_name, is_paid FROM leave_type_master
         WHERE leave_type_id = ? AND tenant_id = ? LIMIT 1`,
        [leave_type_id, tenant_id],
      );
      if (ltCheck?.is_paid) {
        const year = new Date().getFullYear();
        const [[bal]] = await conn.execute(
          `SELECT
             COALESCE(allocated_days, 0) AS allocated,
             COALESCE(used_days, 0) AS used,
             COALESCE(pending_days, 0) AS pending
           FROM leave_balance
           WHERE emp_id = ? AND leave_type = ? AND year = ? AND tenant_id = ?`,
          [emp_id, ltCheck.leave_name, year, tenant_id],
        );
        const available =
          (bal?.allocated ?? 0) - (bal?.used ?? 0) - (bal?.pending ?? 0);
        if (number_of_days > available) {
          await conn.rollback();
          return send(
            res,
            422,
            false,
            `Insufficient leave balance. Available: ${available} day(s), Requested: ${number_of_days} day(s)`,
          );
        }
      }
    }

    // ── Insert leave_master record ──
    const [insertResult] = await conn.execute(
      `INSERT INTO leave_master
            (tenant_id, emp_id, leave_type_id, leave_start_date, leave_end_date,
              is_half_day, half_day_period, status, reason, number_of_days,
              current_approval_level, final_status, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending', ?, ?, ?, 'Pending', NOW(), NOW())`,
      [
        tenant_id,
        emp_id,
        leave_type_id,
        leave_start_date,
        leave_end_date,
        is_half_day ? 1 : 0,
        is_half_day ? half_day_period : null,
        reason.trim(),
        number_of_days,
        approvalLevels > 0 ? 1 : 0,
      ],
    );
    const leave_id = insertResult.insertId;

    // ── Auto-approve path ──
    if (approvalLevels === 0) {
      await conn.execute(
        `UPDATE leave_master
            SET status = 'Approved', final_status = 'Approved',
                current_approver_employee_id = NULL, updated_at = NOW()
            WHERE leave_id = ? AND tenant_id = ?`,
        [leave_id, tenant_id],
      );
      // Update leave balance (paid leaves)
      await updateLeaveBalance(
        conn,
        tenant_id,
        emp_id,
        leave_type_id,
        number_of_days,
        "approve",
      );

      // Consume comp-off credits on auto-approve (only when no approval needed)
      if (isCompOff) {
        const daysToUse = parseInt(Math.ceil(number_of_days), 10);
        const empIdInt = parseInt(emp_id, 10);
        const [earnedRows] = await conn.query(
          `SELECT id FROM comp_off
              WHERE tenant_id = ? AND employee_id = ?
                AND status = 'earned' AND expiry_date >= CURDATE()
              ORDER BY expiry_date ASC
              LIMIT ${daysToUse}`,
          [tenant_id, empIdInt],
        );
        for (const row of earnedRows) {
          await conn.execute(
            `UPDATE comp_off SET status = 'used', leave_id = ? WHERE id = ?`,
            [leave_id, row.id],
          );
        }
      }

      await conn.commit();
      return send(res, 201, true, "Leave applied and auto-approved", {
        leave_id,
      });
    }

    // ── Build approval chain by walking reporting hierarchy ──
    const chain = await resolveReportingChain(
      conn,
      tenant_id,
      emp_id,
      approvalLevels,
    );

    // Check if this employee has a reporting manager at all
    if (chain.length === 0) {
      await conn.execute(
        `UPDATE leave_master
        SET status = 'Approved', final_status = 'Approved',
            current_approver_employee_id = NULL, updated_at = NOW()
        WHERE leave_id = ? AND tenant_id = ?`,
        [leave_id, tenant_id],
      );
      await updateLeaveBalance(
        conn,
        tenant_id,
        emp_id,
        leave_type_id,
        number_of_days,
        "approve",
      );
      await conn.commit();
      return send(
        res,
        201,
        true,
        "Leave applied and auto-approved (no reporting manager)",
        {
          leave_id,
          approval_levels: 0,
        },
      );
    }
    // Insert one row per resolved level into leave_approval_flow
    for (let i = 0; i < chain.length; i++) {
      await conn.execute(
        `INSERT INTO leave_approval_flow
              (tenant_id, leave_id, approval_level, approver_employee_id, action, created_at)
            VALUES (?, ?, ?, ?, 'Pending', NOW())`,
        [tenant_id, leave_id, i + 1, chain[i]],
      );
    }

    // Point leave_master at level-1 approver
    await conn.execute(
      `UPDATE leave_master
          SET current_approver_employee_id = ?,
              current_approval_level = 1,
              updated_at = NOW()
          WHERE leave_id = ? AND tenant_id = ?`,
      [chain[0], leave_id, tenant_id],
    );

    // Update leave balance — mark as pending (paid leaves)
    await updateLeaveBalance(
      conn,
      tenant_id,
      emp_id,
      leave_type_id,
      number_of_days,
      "pending",
    );

    await conn.commit();
    return send(res, 201, true, "Leave applied successfully", {
      leave_id,
      number_of_days,
      approval_levels: chain.length,
      first_approver_employee_id: chain[0],
    });
  } catch (err) {
    await conn.rollback();
    console.error("[leave/apply]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 7. My Leave List   GET /api/leave/my-leaves ─────────────────────────────

router.get("/my-leaves", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  const { status, leave_type_id, year } = req.query;
  const params = [tenant_id, emp_id];
  let extraWhere = "";

  if (status) {
    extraWhere += " AND lm.final_status = ?";
    params.push(status);
  }
  if (leave_type_id) {
    extraWhere += " AND lm.leave_type_id = ?";
    params.push(leave_type_id);
  }
  if (year) {
    extraWhere += " AND YEAR(lm.leave_start_date) = ?";
    params.push(year);
  }

  try {
    const [rows] = await db.execute(
      `SELECT
            lm.leave_id, lm.leave_type_id, lt.leave_name,
            lm.leave_start_date, lm.leave_end_date,
            lm.is_half_day, lm.half_day_period, lm.number_of_days,
            lm.reason, lm.status, lm.final_status,
            lm.current_approval_level, lm.current_approver_employee_id,
            CONCAT(ce.first_name, ' ', ce.last_name) AS current_approver_name,
            lm.created_at, lm.updated_at,
            lm.cancel_reason, lm.last_action_at, lm.last_action_remarks
          FROM leave_master lm
          LEFT JOIN leave_type_master lt
            ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
          LEFT JOIN employee_master ce
            ON lm.current_approver_employee_id = ce.emp_id AND ce.tenant_id = lm.tenant_id
          WHERE lm.tenant_id = ? AND lm.emp_id = ?
          ${extraWhere}
          ORDER BY lm.created_at DESC`,
      params,
    );
    return send(res, 200, true, "Leave list fetched", { data: rows });
  } catch (err) {
    console.error("[leave/my-leaves]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 8. Leave Details   GET /api/leave/details/:leave_id ─────────────────────

router.get("/details/:leave_id", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const { leave_id } = req.params;
  if (!leave_id || isNaN(Number(leave_id)))
    return send(res, 400, false, "Invalid leave_id");

  try {
    const [[leave]] = await db.execute(
      `SELECT
            lm.*,
            lt.leave_name,
            CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
            e.designation_id,
            CONCAT(ca.first_name, ' ', ca.last_name) AS current_approver_name
          FROM leave_master lm
          LEFT JOIN leave_type_master lt
            ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
          LEFT JOIN employee_master e
            ON lm.emp_id = e.emp_id AND e.tenant_id = lm.tenant_id
          LEFT JOIN employee_master ca
            ON lm.current_approver_employee_id = ca.emp_id AND ca.tenant_id = lm.tenant_id
          WHERE lm.leave_id = ? AND lm.tenant_id = ?
          LIMIT 1`,
      [leave_id, tenant_id],
    );
    if (!leave) return send(res, 404, false, "Leave not found");

    const [timeline] = await db.execute(
      `SELECT
            af.flow_id, af.approval_level, af.approver_employee_id,
            CONCAT(e.first_name, ' ', e.last_name) AS approver_name,
            af.action, af.action_at, af.remarks, af.created_at
          FROM leave_approval_flow af
          LEFT JOIN employee_master e
            ON af.approver_employee_id = e.emp_id AND e.tenant_id = af.tenant_id
          WHERE af.leave_id = ? AND af.tenant_id = ?
          ORDER BY af.approval_level ASC`,
      [leave_id, tenant_id],
    );
    return send(res, 200, true, "Leave details fetched", {
      data: { ...leave, approval_timeline: timeline },
    });
  } catch (err) {
    console.error("[leave/details]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 9. Pending Approvals   GET /api/leave/pending-approvals ─────────────────

router.get("/pending-approvals", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const approver_emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!approver_emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  try {
    const [rows] = await db.execute(
      `SELECT
            lm.leave_id, lm.emp_id,
            CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
            e.designation_id, lm.leave_type_id, lt.leave_name,
            lm.leave_start_date, lm.leave_end_date,
            lm.is_half_day, lm.half_day_period, lm.number_of_days,
            lm.reason, lm.status, lm.final_status,
            lm.current_approval_level, lm.created_at
          FROM leave_master lm
          LEFT JOIN employee_master e
            ON lm.emp_id = e.emp_id AND e.tenant_id = lm.tenant_id
          LEFT JOIN leave_type_master lt
            ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
          WHERE lm.tenant_id = ?
            AND lm.current_approver_employee_id = ?
            AND lm.final_status = 'Pending'
          ORDER BY lm.created_at ASC`,
      [tenant_id, approver_emp_id],
    );
    return send(res, 200, true, "Pending approvals fetched", { data: rows });
  } catch (err) {
    console.error("[leave/pending-approvals]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 10. Approve Leave   POST /api/leave/approve/:leave_id ───────────────────

router.post("/approve/:leave_id", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const approver_emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!approver_emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  const { leave_id } = req.params;
  if (!leave_id || isNaN(Number(leave_id)))
    return send(res, 400, false, "Invalid leave_id");

  const { remarks = "" } = req.body;

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[leave]] = await conn.execute(
      `SELECT * FROM leave_master
          WHERE leave_id = ? AND tenant_id = ? AND final_status = 'Pending'
            AND current_approver_employee_id = ?
          LIMIT 1`,
      [leave_id, tenant_id, approver_emp_id],
    );
    if (!leave) {
      await conn.rollback();
      return send(
        res,
        404,
        false,
        "Leave not found or not pending your approval",
      );
    }

    const currentLevel = leave.current_approval_level;

    // Mark current level as approved
    await conn.execute(
      `UPDATE leave_approval_flow
          SET action = 'Approved', action_at = NOW(), remarks = ?
          WHERE leave_id = ? AND tenant_id = ? AND approval_level = ?`,
      [remarks, leave_id, tenant_id, currentLevel],
    );

    // Check if there is a next level
    const [[nextFlow]] = await conn.execute(
      `SELECT * FROM leave_approval_flow
          WHERE leave_id = ? AND tenant_id = ? AND approval_level = ? LIMIT 1`,
      [leave_id, tenant_id, currentLevel + 1],
    );

    if (nextFlow) {
      // Forward to next approver
      await conn.execute(
        `UPDATE leave_master
            SET current_approval_level = ?,
                current_approver_employee_id = ?,
                last_action_by = ?, last_action_at = NOW(),
                last_action_remarks = ?, updated_at = NOW()
            WHERE leave_id = ? AND tenant_id = ?`,
        [
          currentLevel + 1,
          nextFlow.approver_employee_id,
          approver_emp_id,
          remarks,
          leave_id,
          tenant_id,
        ],
      );
    } else {
      // Final approval
      await conn.execute(
        `UPDATE leave_master
            SET status = 'Approved', final_status = 'Approved',
                current_approver_employee_id = NULL,
                last_action_by = ?, last_action_at = NOW(),
                last_action_remarks = ?, updated_at = NOW()
            WHERE leave_id = ? AND tenant_id = ?`,
        [approver_emp_id, remarks, leave_id, tenant_id],
      );

      // Update leave balance: pending → used (paid leaves)
      await updateLeaveBalance(
        conn,
        tenant_id,
        leave.emp_id,
        leave.leave_type_id,
        leave.number_of_days,
        "approve",
      );

      // Consume comp-off credits on final approval
      const [[leaveForCompOff]] = await conn.execute(
        `SELECT lt.leave_code, lm.number_of_days, lm.emp_id
         FROM leave_master lm
         JOIN leave_type_master lt
           ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
         WHERE lm.leave_id = ? AND lm.tenant_id = ? LIMIT 1`,
        [leave_id, tenant_id],
      );
      if ((leaveForCompOff?.leave_code ?? "").toUpperCase() === "COMP_OFF") {
        const daysToUse = parseInt(
          Math.ceil(leaveForCompOff.number_of_days),
          10,
        );
        const empIdInt = parseInt(leaveForCompOff.emp_id, 10);
        const [earnedRows] = await conn.query(
          `SELECT id FROM comp_off
           WHERE tenant_id = ? AND employee_id = ?
             AND status = 'earned' AND expiry_date >= CURDATE()
           ORDER BY expiry_date ASC
           LIMIT ${daysToUse}`,
          [tenant_id, empIdInt],
        );
        for (const row of earnedRows) {
          await conn.execute(
            `UPDATE comp_off SET status = 'used', leave_id = ? WHERE id = ?`,
            [leave_id, row.id],
          );
        }
      }
    }

    await conn.commit();
    return send(
      res,
      200,
      true,
      nextFlow ? "Forwarded to next approver" : "Leave approved successfully",
    );
  } catch (err) {
    await conn.rollback();
    console.error("[leave/approve]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 11. Reject Leave   POST /api/leave/reject/:leave_id ─────────────────────

router.post("/reject/:leave_id", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const approver_emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!approver_emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  const { leave_id } = req.params;
  if (!leave_id || isNaN(Number(leave_id)))
    return send(res, 400, false, "Invalid leave_id");

  const { remarks } = req.body;
  if (!remarks || !remarks.trim())
    return send(res, 400, false, "Rejection remarks are mandatory");

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[leave]] = await conn.execute(
      `SELECT * FROM leave_master
          WHERE leave_id = ? AND tenant_id = ? AND final_status = 'Pending'
            AND current_approver_employee_id = ?
          LIMIT 1`,
      [leave_id, tenant_id, approver_emp_id],
    );
    if (!leave) {
      await conn.rollback();
      return send(
        res,
        404,
        false,
        "Leave not found or not pending your approval",
      );
    }

    const currentLevel = leave.current_approval_level;

    await conn.execute(
      `UPDATE leave_approval_flow
          SET action = 'Rejected', action_at = NOW(), remarks = ?
          WHERE leave_id = ? AND tenant_id = ? AND approval_level = ?`,
      [remarks.trim(), leave_id, tenant_id, currentLevel],
    );
    await conn.execute(
      `UPDATE leave_master
          SET status = 'Rejected', final_status = 'Rejected',
              current_approver_employee_id = NULL,
              last_action_by = ?, last_action_at = NOW(),
              last_action_remarks = ?, updated_at = NOW()
          WHERE leave_id = ? AND tenant_id = ?`,
      [approver_emp_id, remarks.trim(), leave_id, tenant_id],
    );

    // Restore leave balance (paid leaves)
    await updateLeaveBalance(
      conn,
      tenant_id,
      leave.emp_id,
      leave.leave_type_id,
      leave.number_of_days,
      "reject",
    );

    await conn.commit();
    return send(res, 200, true, "Leave rejected");
  } catch (err) {
    await conn.rollback();
    console.error("[leave/reject]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 12. Cancel Leave   POST /api/leave/cancel/:leave_id ─────────────────────

router.post("/cancel/:leave_id", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  const { leave_id } = req.params;
  if (!leave_id || isNaN(Number(leave_id)))
    return send(res, 400, false, "Invalid leave_id");

  const { cancel_reason } = req.body;
  if (!cancel_reason || !cancel_reason.trim())
    return send(res, 400, false, "cancel_reason is required");

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[leave]] = await conn.execute(
      `SELECT * FROM leave_master
          WHERE leave_id = ? AND tenant_id = ? AND emp_id = ? LIMIT 1`,
      [leave_id, tenant_id, emp_id],
    );
    if (!leave) {
      await conn.rollback();
      return send(res, 404, false, "Leave not found");
    }

    if (leave.final_status === "Cancelled")
      return send(res, 409, false, "Leave is already cancelled");
    if (leave.final_status === "Rejected")
      return send(res, 409, false, "Rejected leave cannot be cancelled");
    if (leave.final_status === "Approved") {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      if (new Date(leave.leave_start_date) < today) {
        await conn.rollback();
        return send(
          res,
          409,
          false,
          "Cannot cancel an approved leave that has already started or passed",
        );
      }
    }

    await conn.execute(
      `UPDATE leave_master
          SET final_status = 'Cancelled', status = 'Cancelled',
              cancel_reason = ?, updated_at = NOW()
          WHERE leave_id = ? AND tenant_id = ?`,
      [cancel_reason.trim(), leave_id, tenant_id],
    );

    // Restore leave balance (paid leaves)
    const wasApproved = leave.final_status === "Approved";
    await updateLeaveBalance(
      conn,
      tenant_id,
      leave.emp_id,
      leave.leave_type_id,
      leave.number_of_days,
      wasApproved ? "cancel_approved" : "cancel_pending",
    );

    // ── Restore comp-off credits if applicable ────────────────────────────
    const [[leaveType]] = await conn.execute(
      `SELECT lt.leave_code FROM leave_type_master lt
       WHERE lt.leave_type_id = ? AND lt.tenant_id = ? LIMIT 1`,
      [leave.leave_type_id, tenant_id],
    );
    if ((leaveType?.leave_code ?? "").toUpperCase() === "COMP_OFF") {
      await conn.execute(
        `UPDATE comp_off SET status = 'earned', leave_id = NULL
         WHERE leave_id = ? AND tenant_id = ?`,
        [leave_id, tenant_id],
      );
    }

    await conn.commit();
    return send(res, 200, true, "Leave cancelled successfully");
  } catch (err) {
    await conn.rollback();
    console.error("[leave/cancel]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 13. Available Comp-offs   GET /api/leave/available-compoffs ──────────────

router.get("/available-compoffs", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  try {
    const [rows] = await db.execute(
      `SELECT
            id,
            DATE_FORMAT(earned_date, '%Y-%m-%d') AS earned_date,
            DATE_FORMAT(expiry_date, '%Y-%m-%d') AS expiry_date,
            status,
            remarks
          FROM comp_off
          WHERE tenant_id   = ?
            AND employee_id = ?
            AND status      = 'earned'
            AND expiry_date >= CURDATE()
          ORDER BY expiry_date ASC`,
      [tenant_id, emp_id],
    );
    return send(res, 200, true, "Available comp-offs fetched", { data: rows });
  } catch (err) {
    console.error("[leave/available-compoffs]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 14. All Leave History   GET /api/leave/all-history ──────────────────────

router.get("/all-history", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const {
    status,
    leave_type_id,
    emp_id,
    year,
    search,
    sort = "desc",
  } = req.query;

  const params = [tenant_id];
  let extraWhere = "";

  if (status) {
    extraWhere += " AND lm.final_status = ?";
    params.push(status);
  }
  if (leave_type_id) {
    extraWhere += " AND lm.leave_type_id = ?";
    params.push(leave_type_id);
  }
  if (emp_id) {
    extraWhere += " AND lm.emp_id = ?";
    params.push(emp_id);
  }
  if (year) {
    extraWhere += " AND YEAR(lm.leave_start_date) = ?";
    params.push(year);
  }
  if (search) {
    extraWhere +=
      " AND (CONCAT(e.first_name, ' ', e.last_name) LIKE ? OR lm.emp_id LIKE ?)";
    params.push(`%${search}%`, `%${search}%`);
  }

  const sortDir = sort === "asc" ? "ASC" : "DESC";

  try {
    const [rows] = await db.execute(
      `SELECT
            lm.leave_id,
            lm.emp_id,
            CONCAT(e.first_name, ' ', e.last_name)         AS employee_name,
            e.designation_id,
            d.designation_name,
            lm.leave_type_id,
            lt.leave_name,
            lm.leave_start_date,
            lm.leave_end_date,
            lm.is_half_day,
            lm.half_day_period,
            lm.number_of_days,
            lm.reason,
            lm.status,
            lm.final_status,
            lm.current_approval_level,
            CONCAT(ca.first_name, ' ', ca.last_name)       AS current_approver_name,
            lm.last_action_by,
            CONCAT(la.first_name, ' ', la.last_name)       AS last_action_by_name,
            lm.last_action_at,
            lm.last_action_remarks,
            lm.cancel_reason,
            lm.created_at,
            lm.updated_at
          FROM leave_master lm
          LEFT JOIN employee_master e
            ON lm.emp_id = e.emp_id AND e.tenant_id = lm.tenant_id
          LEFT JOIN designation_master d
            ON e.designation_id = d.designation_id AND d.tenant_id = lm.tenant_id
          LEFT JOIN leave_type_master lt
            ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
          LEFT JOIN employee_master ca
            ON lm.current_approver_employee_id = ca.emp_id AND ca.tenant_id = lm.tenant_id
          LEFT JOIN employee_master la
            ON lm.last_action_by = la.emp_id AND la.tenant_id = lm.tenant_id
          WHERE lm.tenant_id = ?
          ${extraWhere}
          ORDER BY lm.created_at ${sortDir}`,
      params,
    );

    return send(res, 200, true, "All leaves fetched", {
      total: rows.length,
      data: rows,
    });
  } catch (err) {
    console.error("[leave/all-leaves]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 15. Download Balance Template   GET /api/leave/balance/template ──────────

router.get("/balance/template", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  try {
    const XLSX = require("xlsx");

    const [leaveTypes] = await db.execute(
      `SELECT leave_type_id, leave_name FROM leave_type_master
       WHERE tenant_id = ? AND is_active = 1 AND is_system = 0
       ORDER BY leave_type_id ASC`,
      [tenant_id],
    );

    const [employees] = await db.execute(
      `SELECT em.emp_id, em.employee_code,
              CONCAT(em.first_name, ' ', em.last_name) AS emp_name,
              COALESCE(dept.department_name, '') AS department_name,
              COALESCE(dg.designation_name, '') AS designation_name
       FROM employee_master em
       LEFT JOIN designation_master dg
         ON em.designation_id = dg.designation_id AND dg.tenant_id = em.tenant_id
       LEFT JOIN department_master dept
         ON dg.department_id = dept.department_id AND dept.tenant_id = em.tenant_id
       WHERE em.tenant_id = ? AND em.status = 'Active'
       ORDER BY em.emp_id ASC`,
      [tenant_id],
    );

    // Fetch existing balances for current year (so template pre-fills current values)
    const year = new Date().getFullYear();
    const [existingBalances] = await db.execute(
      `SELECT emp_id, leave_type, allocated_days
       FROM leave_balance
       WHERE tenant_id = ? AND year = ?`,
      [tenant_id, year],
    );

    // Map: empId → leaveType → allocated_days
    const balMap = {};
    for (const b of existingBalances) {
      if (!balMap[b.emp_id]) balMap[b.emp_id] = {};
      balMap[b.emp_id][b.leave_type] = b.allocated_days;
    }

    const leaveNames = leaveTypes.map((lt) => lt.leave_name);

    // Build rows
    const headerRow = [
      "emp_id",
      "employee_code",
      "emp_name",
      "department",
      "designation",
      ...leaveNames,
    ];

    const dataRows = employees.map((emp) => {
      const leaveCols = leaveNames.map(
        (name) => balMap[emp.emp_id]?.[name] ?? "",
      );
      return [
        emp.emp_id,
        emp.employee_code ?? "",
        emp.emp_name,
        emp.department_name ?? "",
        emp.designation_name ?? "",
        ...leaveCols,
      ];
    });

    const wsData = [headerRow, ...dataRows];
    const ws = XLSX.utils.aoa_to_sheet(wsData);

    // ── Column widths ──
    ws["!cols"] = [
      { wch: 10 }, // emp_id
      { wch: 14 }, // employee_code
      { wch: 24 }, // emp_name
      { wch: 20 }, // department
      { wch: 20 }, // designation
      ...leaveNames.map(() => ({ wch: 16 })),
    ];

    // ── Freeze header row ──
    ws["!freeze"] = { xSplit: 0, ySplit: 1 };

    // ── Lock emp_id, employee_code, emp_name, department, designation columns (cols A-E) ──
    // Mark leave columns as editable by adding a note to header cells
    leaveNames.forEach((name, i) => {
      const col = XLSX.utils.encode_col(5 + i); // F onwards
      const cellAddr = `${col}1`;
      if (ws[cellAddr]) {
        ws[cellAddr].s = {
          font: { bold: true, color: { rgb: "1A56DB" } },
          fill: { fgColor: { rgb: "EEF2FF" } },
          alignment: { horizontal: "center" },
        };
      }
    });

    // Style header row (A1:E1 — read-only info cols)
    ["A1", "B1", "C1", "D1", "E1"].forEach((addr) => {
      if (ws[addr]) {
        ws[addr].s = {
          font: { bold: true, color: { rgb: "FFFFFF" } },
          fill: { fgColor: { rgb: "1A56DB" } },
          alignment: { horizontal: "center" },
        };
      }
    });

    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Leave Balances");

    // Add instructions sheet
    const instructionData = [
      ["Leave Balance Upload Template — Instructions"],
      [""],
      [
        "1. Do NOT modify columns A to E (emp_id, employee_code, emp_name, department, designation)",
      ],
      ["2. Fill in the leave balance days in the blue columns (F onwards)"],
      ["3. Leave a cell empty to skip updating that employee's balance"],
      ["4. Use numbers only (e.g. 12 or 7.5). Decimals allowed."],
      ["5. Save as .xlsx and upload using the Upload button in the app"],
      [""],
      [`Generated for year: ${year}`],
    ];
    const wsInstructions = XLSX.utils.aoa_to_sheet(instructionData);
    wsInstructions["!cols"] = [{ wch: 70 }];
    XLSX.utils.book_append_sheet(wb, wsInstructions, "Instructions");

    const buffer = XLSX.write(wb, { type: "buffer", bookType: "xlsx" });

    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="leave_balance_template_${year}.xlsx"`,
    );
    return res.send(buffer);
  } catch (err) {
    console.error("[leave/balance/template]", err);
    return send(res, 500, false, "Internal server error");
  }
});
// ─── 16. Bulk Upload Balance   POST /api/leave/balance/bulk-upload ────────────

router.post("/balance/bulk-upload", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const { rows } = req.body;
  // rows: [{ emp_id, balances: { "Casual Leave": 7, "Earned Leave": 3 } }]
  if (!Array.isArray(rows) || rows.length === 0)
    return send(res, 400, false, "rows array is required");

  const year = new Date().getFullYear();

  // Fetch all leave types for this tenant
  const [leaveTypes] = await db.execute(
    `SELECT leave_type_id, leave_name FROM leave_type_master
     WHERE tenant_id = ? AND is_active = 1 AND is_system = 0`,
    [tenant_id],
  );

  // Build case-insensitive map: lowercase name → leave_name
  const leaveTypeMap = {};
  for (const lt of leaveTypes) {
    leaveTypeMap[lt.leave_name.toLowerCase()] = lt.leave_name;
  }

  // Fetch valid emp_ids for this tenant
  const [empRows] = await db.execute(
    `SELECT emp_id FROM employee_master
     WHERE tenant_id = ? AND status = 'Active'`,
    [tenant_id],
  );
  const validEmpIds = new Set(empRows.map((e) => String(e.emp_id)));

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    let updated = 0;
    let skippedEmp = 0;
    let skippedLeave = 0;
    let errors = 0;
    const errorDetails = [];

    for (const row of rows) {
      const empId = String(row.emp_id);

      if (!validEmpIds.has(empId)) {
        skippedEmp++;
        continue;
      }

      const balances = row.balances ?? {};
      for (const [colName, val] of Object.entries(balances)) {
        const matchedName = leaveTypeMap[colName.toLowerCase().trim()];
        if (!matchedName) {
          skippedLeave++;
          continue;
        }

        const days = parseFloat(val);
        if (isNaN(days) || days < 0) {
          errors++;
          errorDetails.push(
            `emp_id ${empId}: invalid value "${val}" for "${colName}"`,
          );
          continue;
        }

        try {
          await conn.execute(
            `INSERT INTO leave_balance
               (emp_id, leave_type, year, allocated_days, used_days, pending_days, carry_forward, tenant_id)
             VALUES (?, ?, ?, ?, 0, 0, 0, ?)
             ON DUPLICATE KEY UPDATE
               allocated_days = VALUES(allocated_days),
               updated_at = NOW()`,
            [empId, matchedName, year, days, tenant_id],
          );
          updated++;
        } catch (e) {
          errors++;
          errorDetails.push(`emp_id ${empId}: DB error for "${colName}"`);
        }
      }
    }

    await conn.commit();
    return send(res, 200, true, "Bulk upload complete", {
      updated,
      skipped_employees: skippedEmp,
      skipped_leave_types: skippedLeave,
      errors,
      error_details: errorDetails,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[leave/balance/bulk-upload]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 17. List Employee Balances   GET /api/leave/balance/list ─────────────────

router.get("/balance/list", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const year = req.query.year ?? new Date().getFullYear();
  const search = req.query.search ?? "";

  try {
    // All active employees
    let empQuery = `
      SELECT emp_id, employee_code,
             CONCAT(first_name, ' ', last_name) AS emp_name
      FROM employee_master
      WHERE tenant_id = ? AND status = 'Active'`;
    const empParams = [tenant_id];

    if (search.trim()) {
      empQuery += ` AND (CONCAT(first_name,' ',last_name) LIKE ?
                      OR employee_code LIKE ?)`;
      empParams.push(`%${search}%`, `%${search}%`);
    }
    empQuery += " ORDER BY first_name ASC";

    const [employees] = await db.execute(empQuery, empParams);

    // All leave types for tenant
    const [leaveTypes] = await db.execute(
      `SELECT leave_type_id, leave_name FROM leave_type_master
       WHERE tenant_id = ? AND is_active = 1 AND is_system = 0
       ORDER BY leave_type_id ASC`,
      [tenant_id],
    );

    // All balances for this tenant + year
    const [balances] = await db.execute(
      `SELECT emp_id, leave_type, allocated_days, used_days, pending_days, carry_forward
       FROM leave_balance
       WHERE tenant_id = ? AND year = ?`,
      [tenant_id, year],
    );

    // Map balances: empId → leaveType → balance row
    const balanceMap = {};
    for (const b of balances) {
      if (!balanceMap[b.emp_id]) balanceMap[b.emp_id] = {};
      balanceMap[b.emp_id][b.leave_type] = b;
    }

    // Combine
    const data = employees.map((emp) => ({
      emp_id: emp.emp_id,
      employee_code: emp.employee_code,
      emp_name: emp.emp_name,
      balances: leaveTypes.map((lt) => ({
        leave_type: lt.leave_name,
        leave_type_id: lt.leave_type_id,
        allocated_days:
          balanceMap[emp.emp_id]?.[lt.leave_name]?.allocated_days ?? null,
        used_days: balanceMap[emp.emp_id]?.[lt.leave_name]?.used_days ?? 0,
        pending_days:
          balanceMap[emp.emp_id]?.[lt.leave_name]?.pending_days ?? 0,
        carry_forward:
          balanceMap[emp.emp_id]?.[lt.leave_name]?.carry_forward ?? 0,
      })),
    }));

    return send(res, 200, true, "Balance list fetched", {
      year,
      leave_types: leaveTypes,
      data,
    });
  } catch (err) {
    console.error("[leave/balance/list]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 18. Set Balance (manual add/edit)   POST /api/leave/balance/set ──────────

router.post("/balance/set", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const { emp_id, year, balances } = req.body;
  // balances: [{ leave_type, allocated_days }]
  if (!emp_id) return send(res, 400, false, "emp_id is required");
  if (!Array.isArray(balances) || balances.length === 0)
    return send(res, 400, false, "balances array is required");

  const targetYear = year ?? new Date().getFullYear();

  // Verify employee belongs to tenant
  const [[emp]] = await db.execute(
    `SELECT emp_id FROM employee_master
     WHERE emp_id = ? AND tenant_id = ? LIMIT 1`,
    [emp_id, tenant_id],
  );
  if (!emp) return send(res, 404, false, "Employee not found");

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    for (const b of balances) {
      const days = parseFloat(b.allocated_days);
      if (isNaN(days) || days < 0) continue;

      await conn.execute(
        `INSERT INTO leave_balance
           (emp_id, leave_type, year, allocated_days, used_days, pending_days, carry_forward, tenant_id)
         VALUES (?, ?, ?, ?, 0, 0, 0, ?)
         ON DUPLICATE KEY UPDATE
           allocated_days = VALUES(allocated_days),
           updated_at = NOW()`,
        [emp_id, b.leave_type, targetYear, days, tenant_id],
      );
    }

    await conn.commit();
    return send(res, 200, true, "Balance updated successfully");
  } catch (err) {
    await conn.rollback();
    console.error("[leave/balance/set]", err);
    return send(res, 500, false, "Internal server error");
  } finally {
    conn.release();
  }
});

// ─── 19. My Leave Balance   GET /api/leave/balance/my ────────────────────────

router.get("/balance/my", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");

  const emp_id = req.user?.employee_id || req.user?.emp_id;
  if (!emp_id)
    return send(res, 401, false, "Unauthorized: employee not identified");

  const year = req.query.year ?? new Date().getFullYear();

  try {
    const [leaveTypes] = await db.execute(
      `SELECT leave_type_id, leave_name FROM leave_type_master
       WHERE tenant_id = ? AND is_active = 1 AND is_system = 0
       ORDER BY leave_type_id ASC`,
      [tenant_id],
    );

    const [balances] = await db.execute(
      `SELECT leave_type, allocated_days, used_days, pending_days, carry_forward
       FROM leave_balance
       WHERE tenant_id = ? AND emp_id = ? AND year = ?`,
      [tenant_id, emp_id, year],
    );

    const balMap = {};
    for (const b of balances) {
      balMap[b.leave_type] = b;
    }

    const data = leaveTypes.map((lt) => {
      const b = balMap[lt.leave_name] ?? {};
      const allocated = parseFloat(b.allocated_days ?? 0);
      const used = parseFloat(b.used_days ?? 0);
      const pending = parseFloat(b.pending_days ?? 0);
      return {
        leave_type_id: lt.leave_type_id,
        leave_name: lt.leave_name,
        allocated_days: allocated,
        used_days: used,
        pending_days: pending,
        available_days: Math.max(0, allocated - used - pending),
        carry_forward: parseFloat(b.carry_forward ?? 0),
      };
    });

    return send(res, 200, true, "My leave balance fetched", { data, year });
  } catch (err) {
    console.error("[leave/balance/my]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── 20. Attendance Accrual   POST /api/leave/balance/attendance-accrual ──────
// Called by cron daily (after auto-checkout) to credit leave balance
// based on attendance_accrual_streak / attendance_accrual_reward.
// Body (optional): { date: "YYYY-MM-DD" }  ← defaults to yesterday
// Header: x-cron-secret

router.post("/balance/attendance-accrual", async (req, res) => {
  const secret = req.headers["x-cron-secret"];
  if (secret !== process.env.AUTO_CHECKOUT_SECRET) {
    return send(res, 401, false, "Unauthorized");
  }

  const targetDate =
    req.body?.date ??
    (() => {
      const d = new Date();
      d.setDate(d.getDate() - 1);
      return d.toISOString().slice(0, 10);
    })();

  const year = new Date(targetDate).getFullYear();

  try {
    // 1. All accrual-enabled leave types across all tenants
    const [accrualTypes] = await db.execute(
      `SELECT tenant_id, leave_type_id, leave_name,
              attendance_accrual_streak, attendance_accrual_reward
       FROM leave_type_master
       WHERE attendance_accrual_enabled = 1
         AND is_active = 1
         AND attendance_accrual_streak > 0
         AND attendance_accrual_reward > 0`,
    );

    if (accrualTypes.length === 0) {
      return send(res, 200, true, "No accrual-enabled leave types found", {
        credited: 0,
      });
    }

    // Group by tenant
    const byTenant = {};
    for (const lt of accrualTypes) {
      if (!byTenant[lt.tenant_id]) byTenant[lt.tenant_id] = [];
      byTenant[lt.tenant_id].push(lt);
    }

    let totalCredited = 0;
    const errorDetails = [];

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      for (const [tenantId, leaveTypes] of Object.entries(byTenant)) {
        // 2. Employees present on targetDate (any attendance mode, completed)
        const [presentRows] = await conn.execute(
          `SELECT DISTINCT employee_id AS emp_id
           FROM employee_attendance
           WHERE tenant_id    = ?
             AND work_date    = ?
             AND status       = 'completed'
             AND checkin_time  IS NOT NULL
             AND checkout_time IS NOT NULL`,
          [tenantId, targetDate],
        );

        if (presentRows.length === 0) continue;

        for (const { emp_id } of presentRows) {
          for (const lt of leaveTypes) {
            const streak = Number(lt.attendance_accrual_streak); // e.g. 1
            const reward = Number(lt.attendance_accrual_reward); // e.g. 1.0

            // 3. Count YTD present days up to and including targetDate
            const [[countRow]] = await conn.execute(
              `SELECT COUNT(DISTINCT work_date) AS present_count
               FROM employee_attendance
               WHERE tenant_id    = ?
                 AND employee_id  = ?
                 AND status       = 'completed'
                 AND checkin_time  IS NOT NULL
                 AND checkout_time IS NOT NULL
                 AND work_date BETWEEN ? AND ?`,
              [tenantId, emp_id, `${year}-01-01`, targetDate],
            );

            const presentCount = Number(countRow?.present_count ?? 0);

            // Credit only on exact streak boundary (day 1,2,3... if streak=1; day 3,6,9... if streak=3)
            if (presentCount === 0 || presentCount % streak !== 0) continue;

            // 4. Add reward to allocated_days
            try {
              await conn.execute(
                `INSERT INTO leave_balance
                   (emp_id, leave_type, year, allocated_days, used_days, pending_days, carry_forward, tenant_id)
                 VALUES (?, ?, ?, ?, 0, 0, 0, ?)
                 ON DUPLICATE KEY UPDATE
                   allocated_days = allocated_days + VALUES(allocated_days),
                   updated_at     = NOW()`,
                [emp_id, lt.leave_name, year, reward, tenantId],
              );
              totalCredited++;
            } catch (e) {
              errorDetails.push(
                `tenant ${tenantId} emp ${emp_id} leave "${lt.leave_name}": ${e.message}`,
              );
            }
          }
        }
      }

      await conn.commit();
    } catch (innerErr) {
      await conn.rollback();
      throw innerErr;
    } finally {
      conn.release();
    }

    return send(
      res,
      200,
      true,
      `Attendance accrual complete for ${targetDate}`,
      {
        date: targetDate,
        credited: totalCredited,
        errors: errorDetails.length,
        error_details: errorDetails,
      },
    );
  } catch (err) {
    console.error("[leave/balance/attendance-accrual]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── Matrix Leave Report   GET /api/leave/report/matrix ──────────────────────

router.get("/report/matrix", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id) return send(res, 401, false, "Unauthorized");

  const { from, to, department_id } = req.query;
  if (!from || !to) return send(res, 400, false, "from and to are required");

  const fromDt = new Date(from);
  const toDt = new Date(to);
  if (isNaN(fromDt) || isNaN(toDt) || fromDt > toDt)
    return send(res, 400, false, "Invalid date range");

  try {
    // ── 1. Attendance policy (weekoffs) ──
    const [[policy]] = await db.execute(
      `SELECT is_saturday_weekoff, is_sunday_weekoff
       FROM attendance_policy WHERE tenant_id = ? LIMIT 1`,
      [tenant_id],
    );
    const skipSat = policy?.is_saturday_weekoff === 1;
    const skipSun = policy?.is_sunday_weekoff === 1;

    // ── 2. Holidays in range ──
    const [holidays] = await db.execute(
      `SELECT DATE_FORMAT(holiday_date,'%Y-%m-%d') AS hdate, holiday_name
       FROM holiday_master
       WHERE tenant_id = ? AND holiday_date BETWEEN ? AND ?`,
      [tenant_id, from, to],
    );
    const holidayMap = {};
    for (const h of holidays) holidayMap[h.hdate] = h.holiday_name;

    // ── 3. Build date list ──
    const dates = [];
    const cur = new Date(fromDt);
    while (cur <= toDt) {
      const ds = cur.toISOString().slice(0, 10);
      const dow = cur.getDay();
      dates.push({
        date: ds,
        day: cur.getDate(),
        dayLabel: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][dow],
        isWeekend: (skipSun && dow === 0) || (skipSat && dow === 6),
        isHoliday: !!holidayMap[ds],
        holidayName: holidayMap[ds] ?? null,
      });
      cur.setDate(cur.getDate() + 1);
    }

    // ── 4. Employees (with dept filter) ──
    const empParams = [tenant_id];
    let deptWhere = "";
    if (department_id) {
      deptWhere = "AND dg.department_id = ?";
      empParams.push(department_id);
    }
    const [employees] = await db.execute(
      `SELECT e.emp_id,
              CONCAT(e.first_name,' ',e.last_name) AS emp_name,
              e.employee_code,
              dept.department_name,
              dg.designation_name
       FROM employee_master e
       JOIN designation_master dg
         ON e.designation_id = dg.designation_id AND dg.tenant_id = e.tenant_id
       JOIN department_master dept
         ON dg.department_id = dept.department_id AND dept.tenant_id = e.tenant_id
       WHERE e.tenant_id = ? AND e.status = 'Active'
       ${deptWhere}
       ORDER BY dept.department_name, e.first_name`,
      empParams,
    );

    // ── 5. Leave records in range ──
    const leaveParams = [tenant_id, to, from];
    if (department_id) leaveParams.push(department_id);

    const [leaveRows] = await db.execute(
      `SELECT lm.emp_id,
              lm.leave_start_date,
              lm.leave_end_date,
              lm.final_status,
              lm.number_of_days,
              lt.leave_name,
              lt.leave_code,
              lt.is_paid
       FROM leave_master lm
       JOIN leave_type_master lt
         ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
       JOIN employee_master e
         ON lm.emp_id = e.emp_id AND e.tenant_id = lm.tenant_id
       JOIN designation_master dg
         ON e.designation_id = dg.designation_id AND dg.tenant_id = e.tenant_id
       ${department_id ? "JOIN department_master dept ON dg.department_id = dept.department_id AND dept.tenant_id = e.tenant_id" : ""}
       WHERE lm.tenant_id = ?
         AND lm.leave_start_date <= ?
         AND lm.leave_end_date   >= ?
         AND lm.final_status IN ('Approved','Pending')
         ${department_id ? "AND dg.department_id = ?" : ""}`,
      leaveParams,
    );

    // ── 6. Build per-employee summary from leaveRows in the date range ──
    // sumMap: empId → { paidTaken, unpaidTaken, pendingDays }
    const sumMap = {};
    for (const lv of leaveRows) {
      if (!sumMap[lv.emp_id]) {
        sumMap[lv.emp_id] = { paidTaken: 0, unpaidTaken: 0, pendingDays: 0 };
      }
      const days = Number(lv.number_of_days ?? 0);
      if (lv.final_status === "Pending") {
        sumMap[lv.emp_id].pendingDays += days;
      } else if (lv.final_status === "Approved") {
        if (lv.is_paid === 1 || lv.is_paid === true) {
          sumMap[lv.emp_id].paidTaken += days;
        } else {
          sumMap[lv.emp_id].unpaidTaken += days;
        }
      }
    }

    // ── 7. Build per-employee day map ──
    // leaveMap: empId → dateStr → { status: 'Approved'|'Pending', is_paid, leave_code }
    const leaveMap = {};
    for (const lv of leaveRows) {
      if (!leaveMap[lv.emp_id]) leaveMap[lv.emp_id] = {};
      const s = new Date(lv.leave_start_date);
      const e = new Date(lv.leave_end_date);
      const c = new Date(s);
      while (c <= e) {
        const ds = c.toISOString().slice(0, 10);
        leaveMap[lv.emp_id][ds] = {
          status: lv.final_status,
          is_paid: lv.is_paid === 1 || lv.is_paid === true,
          leave_code: lv.leave_code ?? lv.leave_name?.slice(0, 2).toUpperCase(),
          leave_name: lv.leave_name,
        };
        c.setDate(c.getDate() + 1);
      }
    }

    // ── 8. Assemble response ──
    const data = employees.map((emp) => {
      const empLeave = leaveMap[emp.emp_id] ?? {};

      const days = dates.map((d) => {
        if (d.isHoliday) return { date: d.date, type: "H", label: "H" };
        if (d.isWeekend) return { date: d.date, type: "W", label: "W" };
        const lv = empLeave[d.date];
        if (!lv) return { date: d.date, type: null, label: "" };
        if (lv.status === "Pending")
          return { date: d.date, type: "LP", label: lv.leave_code ?? "L" };
        return {
          date: d.date,
          type: lv.is_paid ? "PL" : "UL",
          label: lv.leave_code ?? "L",
        };
      });

      const empSum = sumMap[emp.emp_id] ?? {
        paidTaken: 0,
        unpaidTaken: 0,
        pendingDays: 0,
      };

      return {
        emp_id: emp.emp_id,
        emp_name: emp.emp_name,
        employee_code: emp.employee_code,
        department_name: emp.department_name,
        designation_name: emp.designation_name,
        days,
        summary: {
          paid_taken: empSum.paidTaken,
          unpaid_taken: empSum.unpaidTaken,
          pending_days: empSum.pendingDays,
          closing_balance:
            empSum.paidTaken + empSum.unpaidTaken + empSum.pendingDays,
        },
      };
    });

    return send(res, 200, true, "Matrix fetched", {
      dates,
      data,
      total_employees: data.length,
    });
  } catch (err) {
    console.error("[leave/report/matrix]", err);
    return send(res, 500, false, "Internal server error");
  }
});

// ─── Day-Wise Leave Report   GET /api/leave/report/day-wise ──────────────────

router.get("/report/day-wise", async (req, res) => {
  const tenant_id = getTenantId(req);
  if (!tenant_id) return send(res, 401, false, "Unauthorized");

  const { date, department_id } = req.query;
  if (!date) return send(res, 400, false, "date is required");

  const dt = new Date(date);
  if (isNaN(dt))
    return send(res, 400, false, "Invalid date format. Use YYYY-MM-DD");

  try {
    const deptJoin = department_id
      ? `JOIN designation_master dg2 ON e.designation_id = dg2.designation_id AND dg2.tenant_id = e.tenant_id
         JOIN department_master dept2 ON dg2.department_id = dept2.department_id AND dept2.tenant_id = e.tenant_id`
      : `LEFT JOIN designation_master dg2 ON e.designation_id = dg2.designation_id AND dg2.tenant_id = e.tenant_id
         LEFT JOIN department_master dept2 ON dg2.department_id = dept2.department_id AND dept2.tenant_id = e.tenant_id`;

    const params = [tenant_id, date, date];
    if (department_id) params.push(department_id);

    const [rows] = await db.execute(
      `SELECT
          lm.leave_id,
          lm.emp_id,
          CONCAT(e.first_name, ' ', e.last_name)   AS employee_name,
          e.employee_code,
          COALESCE(dept2.department_name, '')        AS department_name,
          COALESCE(dg2.designation_name, '')         AS designation_name,
          lm.leave_type_id,
          lt.leave_name,
          lt.leave_code,
          lt.is_paid,
          DATE_FORMAT(lm.leave_start_date, '%Y-%m-%d') AS leave_start_date,
          DATE_FORMAT(lm.leave_end_date,   '%Y-%m-%d') AS leave_end_date,
          lm.is_half_day,
          lm.half_day_period,
          lm.number_of_days,
          lm.reason,
          lm.final_status,
          DATE_FORMAT(lm.created_at, '%Y-%m-%d')    AS applied_on,
          CONCAT(ca.first_name, ' ', ca.last_name)  AS approver_name,
          lm.last_action_remarks                     AS remarks,
          lm.cancel_reason
       FROM leave_master lm
       JOIN employee_master e
         ON lm.emp_id = e.emp_id AND e.tenant_id = lm.tenant_id
       ${deptJoin}
       LEFT JOIN leave_type_master lt
         ON lm.leave_type_id = lt.leave_type_id AND lt.tenant_id = lm.tenant_id
       LEFT JOIN employee_master ca
         ON lm.last_action_by = ca.emp_id AND ca.tenant_id = lm.tenant_id
       WHERE lm.tenant_id = ?
         AND lm.leave_start_date <= ?
         AND lm.leave_end_date   >= ?
         AND lm.final_status IN ('Approved', 'Pending')
         ${department_id ? "AND dept2.department_id = ?" : ""}
       ORDER BY dept2.department_name ASC, e.first_name ASC`,
      params,
    );

    return send(res, 200, true, "Day-wise leave report fetched", {
      data: rows,
    });
  } catch (err) {
    console.error("[leave/report/day-wise]", err);
    return send(res, 500, false, "Internal server error");
  }
});
module.exports = router;
