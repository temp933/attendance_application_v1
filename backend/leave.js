"use strict";

const express = require("express");
const router = express.Router();

// ─── Constants ────────────────────────────────────────────────────────────────

const MODULE_NAME = "LEAVE";
const VALID_TYPES = ["Paid", "Casual", "Sick", "Comp-Off"];
const VALID_PERIODS = ["AM", "PM"];
const STATUS_PENDING = "Pending";
const STATUS_APPROVED = "Approved";
const STATUS_REJECTED = "Rejected";

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Uniform success response
 */
const ok = (res, data = {}, message = "Success", statusCode = 200) =>
  res.status(statusCode).json({ success: true, message, data });

/**
 * Uniform error response
 */
const fail = (
  res,
  message = "An error occurred",
  statusCode = 400,
  error = null,
) => {
  const payload = { success: false, message };
  if (process.env.NODE_ENV !== "production" && error) {
    payload.debug = error.message ?? String(error);
  }
  return res.status(statusCode).json(payload);
};

/**
 * Wrap async route handlers — surfaces unhandled promise rejections as 500s
 */
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch((err) => {
    console.error("[LeaveManagement]", err);
    return fail(res, "Internal server error", 500, err);
  });

/**
 * Run a callback inside a mysql2 transaction on the given connection.
 * Commits on success, rolls back on error, always releases connection.
 */
const withTransaction = async (db, callback) => {
  const conn = await db.promise().getConnection();
  await conn.beginTransaction();
  try {
    const result = await callback(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
};

/**
 * Fetch a single employee row (only what we need).
 * Returns null when not found.
 */
const getEmployee = async (db, emp_id, tenant_id) => {
  const [rows] = await db.promise().query(
    `SELECT emp_id, tenant_id, first_name, last_name, reporting_to_employee_id
       FROM employee_master
      WHERE emp_id = ? AND tenant_id = ?
      LIMIT 1`,
    [emp_id, tenant_id],
  );
  return rows[0] ?? null;
};

/**
 * Insert a row into approval_trail.
 * Accepts an open connection (inside a transaction) OR the pool itself.
 */
const insertTrail = async (
  executor,
  {
    tenant_id,
    record_id,
    approval_level,
    approver_employee_id,
    action,
    comments,
  },
) => {
  const sql = `
    INSERT INTO approval_trail
      (tenant_id, module_name, record_id, approval_level, approver_employee_id, action, comments, action_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
  `;
  await executor.query(sql, [
    tenant_id,
    MODULE_NAME,
    record_id,
    approval_level,
    approver_employee_id,
    action,
    comments ?? null,
  ]);
};

// ─────────────────────────────────────────────────────────────────────────────
// 1. APPLY LEAVE
//    POST /apply-leave
// ─────────────────────────────────────────────────────────────────────────────
/**
 * @route   POST /apply-leave
 * @desc    Authenticated employee submits a new leave request.
 *          The system auto-resolves the first approver from reporting_to_employee_id.
 * @access  Authenticated employee
 * @body    {
 *            leave_type, leave_start_date, leave_end_date,
 *            number_of_days, reason,
 *            is_half_day (bool, optional),
 *            half_day_period ('AM'|'PM', required when is_half_day = true)
 *          }
 */
router.post(
  "/apply-leave",
  asyncHandler(async (req, res) => {
    const { emp_id, tenant_id } = req.user;

    // ── Validate body ──────────────────────────────────────────────────────
    const {
      leave_type,
      leave_start_date,
      leave_end_date,
      number_of_days,
      reason,
      is_half_day = false,
      half_day_period,
    } = req.body;

    if (!leave_type || !VALID_TYPES.includes(leave_type)) {
      return fail(
        res,
        `Invalid leave_type. Must be one of: ${VALID_TYPES.join(", ")}`,
      );
    }
    if (!leave_start_date || !leave_end_date) {
      return fail(res, "leave_start_date and leave_end_date are required");
    }
    if (
      !number_of_days ||
      isNaN(Number(number_of_days)) ||
      Number(number_of_days) <= 0
    ) {
      return fail(res, "number_of_days must be a positive number");
    }
    if (!reason || String(reason).trim().length === 0) {
      return fail(res, "reason is required");
    }
    if (
      is_half_day &&
      (!half_day_period || !VALID_PERIODS.includes(half_day_period))
    ) {
      return fail(
        res,
        `half_day_period must be 'AM' or 'PM' when is_half_day is true`,
      );
    }

    const db = req.app.locals.db;

    // ── Fetch employee + reporting manager ──────────────────────────────────
    const employee = await getEmployee(db, emp_id, tenant_id);
    if (!employee) {
      return fail(res, "Employee not found", 404);
    }
    if (!employee.reporting_to_employee_id) {
      return fail(
        res,
        "No reporting manager configured for this employee. Please contact HR.",
        422,
      );
    }

    // ── Confirm the reporting manager actually exists in this tenant ─────────
    const manager = await getEmployee(
      db,
      employee.reporting_to_employee_id,
      tenant_id,
    );
    if (!manager) {
      return fail(res, "Reporting manager not found. Please contact HR.", 422);
    }

    // ── Insert inside a transaction ─────────────────────────────────────────
    const leaveId = await withTransaction(db, async (conn) => {
      // Insert leave_master
      const insertLeaveSql = `
        INSERT INTO leave_master (
          tenant_id, emp_id, leave_type,
          leave_start_date, leave_end_date,
          is_half_day, half_day_period, number_of_days,
          reason, current_approval_level,
          current_approver_employee_id, final_status,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, NOW(), NOW())
      `;
      const [result] = await conn.query(insertLeaveSql, [
        tenant_id,
        emp_id,
        leave_type,
        leave_start_date,
        leave_end_date,
        is_half_day ? 1 : 0,
        is_half_day ? half_day_period : null,
        Number(number_of_days),
        reason.trim(),
        employee.reporting_to_employee_id,
        STATUS_PENDING,
      ]);

      const newLeaveId = result.insertId;

      // Insert first approval_trail entry
      await insertTrail(conn, {
        tenant_id,
        record_id: newLeaveId,
        approval_level: 0, // 0 = submitted by employee
        approver_employee_id: emp_id,
        action: "Submitted",
        comments: reason.trim(),
      });

      return newLeaveId;
    });

    return ok(
      res,
      { leave_id: leaveId },
      "Leave request submitted successfully",
      201,
    );
  }),
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. APPROVER INBOX
//    GET /approver-inbox
// ─────────────────────────────────────────────────────────────────────────────
/**
 * @route   GET /approver-inbox
 * @desc    Returns all pending leave requests assigned to the logged-in approver.
 * @access  Any employee who is a reporting manager
 */
router.get(
  "/approver-inbox",
  asyncHandler(async (req, res) => {
    const { emp_id, tenant_id } = req.user;
    const db = req.app.locals.db;

    const sql = `
      SELECT
        lm.leave_id,
        lm.emp_id,
        CONCAT(e.first_name, ' ', e.last_name)  AS employee_name,
        lm.leave_type,
        lm.leave_start_date,
        lm.leave_end_date,
        lm.is_half_day,
        lm.half_day_period,
        lm.number_of_days,
        lm.reason,
        lm.final_status,
        lm.current_approval_level,
        lm.created_at
      FROM leave_master lm
      JOIN employee_master e
        ON e.emp_id = lm.emp_id AND e.tenant_id = lm.tenant_id
      WHERE lm.tenant_id                  = ?
        AND lm.current_approver_employee_id = ?
        AND lm.final_status               = ?
      ORDER BY lm.created_at ASC
    `;

    const [rows] = await db
      .promise()
      .query(sql, [tenant_id, emp_id, STATUS_PENDING]);

    return ok(res, rows, `${rows.length} pending leave(s) found`);
  }),
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. APPROVE LEAVE
//    POST /approve-leave/:leaveId
// ─────────────────────────────────────────────────────────────────────────────
/**
 * @route   POST /approve-leave/:leaveId
 * @desc    Current approver approves a leave.
 *          If the approver has their own reporting manager, the request is
 *          forwarded (multi-level). Otherwise the leave is finally approved.
 * @access  Assigned approver only
 * @body    { comments (optional) }
 */
router.post(
  "/approve-leave/:leaveId",
  asyncHandler(async (req, res) => {
    const { emp_id, tenant_id } = req.user;
    const leaveId = Number(req.params.leaveId);
    const comments = req.body.comments ?? null;
    const db = req.app.locals.db;

    if (!leaveId || isNaN(leaveId)) {
      return fail(res, "Invalid leaveId");
    }

    // ── Load leave record ──────────────────────────────────────────────────
    const [leaveRows] = await db
      .promise()
      .query(
        `SELECT * FROM leave_master WHERE leave_id = ? AND tenant_id = ? LIMIT 1`,
        [leaveId, tenant_id],
      );
    const leave = leaveRows[0];

    if (!leave) {
      return fail(res, "Leave request not found", 404);
    }
    if (leave.final_status !== STATUS_PENDING) {
      return fail(res, `Leave is already ${leave.final_status}`, 422);
    }
    if (leave.current_approver_employee_id !== emp_id) {
      return fail(res, "You are not the current approver for this leave", 403);
    }

    // ── Determine next approver ────────────────────────────────────────────
    //    The current approver's own reporting_to_employee_id becomes the next approver.
    const currentApprover = await getEmployee(db, emp_id, tenant_id);
    const nextApproverId = currentApprover?.reporting_to_employee_id ?? null;

    // Verify the next approver exists within the same tenant (guard against
    // cross-tenant IDs or orphaned references)
    let nextApprover = null;
    if (nextApproverId) {
      nextApprover = await getEmployee(db, nextApproverId, tenant_id);
    }

    await withTransaction(db, async (conn) => {
      if (nextApprover) {
        // ── Forward to next level ──────────────────────────────────────────
        await conn.query(
          `UPDATE leave_master
              SET current_approval_level        = current_approval_level + 1,
                  current_approver_employee_id  = ?,
                  updated_at                    = NOW()
            WHERE leave_id = ? AND tenant_id = ?`,
          [nextApproverId, leaveId, tenant_id],
        );

        await insertTrail(conn, {
          tenant_id,
          record_id: leaveId,
          approval_level: leave.current_approval_level,
          approver_employee_id: emp_id,
          action: "Approved — Forwarded",
          comments,
        });
      } else {
        // ── Final approval ─────────────────────────────────────────────────
        await conn.query(
          `UPDATE leave_master
              SET final_status                  = ?,
                  current_approver_employee_id  = NULL,
                  updated_at                    = NOW()
            WHERE leave_id = ? AND tenant_id = ?`,
          [STATUS_APPROVED, leaveId, tenant_id],
        );

        await insertTrail(conn, {
          tenant_id,
          record_id: leaveId,
          approval_level: leave.current_approval_level,
          approver_employee_id: emp_id,
          action: STATUS_APPROVED,
          comments,
        });
      }
    });

    const message = nextApprover
      ? "Leave approved and forwarded to next approver"
      : "Leave finally approved";

    return ok(res, { leave_id: leaveId, forwarded: !!nextApprover }, message);
  }),
);

// ─────────────────────────────────────────────────────────────────────────────
// 4. REJECT LEAVE
//    POST /reject-leave/:leaveId
// ─────────────────────────────────────────────────────────────────────────────
/**
 * @route   POST /reject-leave/:leaveId
 * @desc    Current approver rejects a leave request. Rejection is terminal —
 *          no further forwarding occurs.
 * @access  Assigned approver only
 * @body    { comments (required) }
 */

// router.get(
//   "/employees/:empId/leaves",
//   asyncHandler(async (req, res) => {
//     const db = req.app.locals.db;

//     const sql = `
//       SELECT
//         leave_id,
//         emp_id,
//         leave_type,
//         DATE_FORMAT(leave_start_date, '%Y-%m-%d') AS leave_start_date,
//         DATE_FORMAT(leave_end_date, '%Y-%m-%d')   AS leave_end_date,
//         number_of_days,
//         recommended_by,
//         DATE_FORMAT(recommended_at, '%Y-%m-%d %H:%i:%s') AS recommended_at,
//         approved_by,
//         final_status,
//         reason,
//         cancel_reason,
//         rejection_reason,
//         DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
//         DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
//       FROM leave_master
//       WHERE emp_id = ?
//       ORDER BY leave_start_date DESC
//     `;

//     const [rows] = await db.promise().query(sql, [req.params.empId]);

//     return ok(res, rows, "Leave history fetched successfully");
//   }),
// );
router.post(
  "/reject-leave/:leaveId",
  asyncHandler(async (req, res) => {
    const { emp_id, tenant_id } = req.user;
    const leaveId = Number(req.params.leaveId);
    const comments = req.body.comments;
    const db = req.app.locals.db;

    if (!leaveId || isNaN(leaveId)) {
      return fail(res, "Invalid leaveId");
    }
    if (!comments || String(comments).trim().length === 0) {
      return fail(res, "A rejection reason (comments) is required");
    }

    // ── Load leave ─────────────────────────────────────────────────────────
    const [leaveRows] = await db
      .promise()
      .query(
        `SELECT * FROM leave_master WHERE leave_id = ? AND tenant_id = ? LIMIT 1`,
        [leaveId, tenant_id],
      );
    const leave = leaveRows[0];

    if (!leave) {
      return fail(res, "Leave request not found", 404);
    }
    if (leave.final_status !== STATUS_PENDING) {
      return fail(res, `Leave is already ${leave.final_status}`, 422);
    }
    if (leave.current_approver_employee_id !== emp_id) {
      return fail(res, "You are not the current approver for this leave", 403);
    }

    await withTransaction(db, async (conn) => {
      // Reject — clear approver, mark final
      await conn.query(
        `UPDATE leave_master
            SET final_status                  = ?,
                current_approver_employee_id  = NULL,
                updated_at                    = NOW()
          WHERE leave_id = ? AND tenant_id = ?`,
        [STATUS_REJECTED, leaveId, tenant_id],
      );

      await insertTrail(conn, {
        tenant_id,
        record_id: leaveId,
        approval_level: leave.current_approval_level,
        approver_employee_id: emp_id,
        action: STATUS_REJECTED,
        comments: String(comments).trim(),
      });
    });

    return ok(res, { leave_id: leaveId }, "Leave request rejected");
  }),
);

// ─────────────────────────────────────────────────────────────────────────────
// 5. MY LEAVES (Employee Leave History)
//    GET /my-leaves
// ─────────────────────────────────────────────────────────────────────────────
/**
 * @route   GET /my-leaves
 * @desc    Returns the full leave history for the authenticated employee.
 *          Accepts optional query params: status, year
 * @access  Authenticated employee
 * @query   status (optional) — filter by final_status
 *          year   (optional) — filter by calendar year (default: current year)
 */
router.get(
  "/my-leaves",
  asyncHandler(async (req, res) => {
    const { emp_id, tenant_id } = req.user;
    const db = req.app.locals.db;
    const year = req.query.year ? Number(req.query.year) : null;
    const status = req.query.status ? String(req.query.status) : null;

    const conditions = ["lm.emp_id = ?", "lm.tenant_id = ?"];
    const params = [emp_id, tenant_id];

    if (year) {
      conditions.push("YEAR(lm.leave_start_date) = ?");
      params.push(year);
    }
    if (status) {
      conditions.push("lm.final_status = ?");
      params.push(status);
    }

    const sql = `
      SELECT
        lm.leave_id,
        lm.leave_type,
        lm.leave_start_date,
        lm.leave_end_date,
        lm.is_half_day,
        lm.half_day_period,
        lm.number_of_days,
        lm.reason,
        lm.final_status,
        lm.current_approval_level,
        lm.current_approver_employee_id,
        CONCAT(mgr.first_name, ' ', mgr.last_name) AS current_approver_name,
        lm.created_at,
        lm.updated_at
      FROM leave_master lm
      LEFT JOIN employee_master mgr
        ON mgr.emp_id    = lm.current_approver_employee_id
       AND mgr.tenant_id = lm.tenant_id
      WHERE ${conditions.join(" AND ")}
      ORDER BY lm.created_at DESC
    `;

    const [rows] = await db.promise().query(sql, params);

    return ok(res, rows, `${rows.length} leave record(s) found`);
  }),
);

// ─────────────────────────────────────────────────────────────────────────────
// 6. APPROVAL TRAIL
//    GET /leave-trail/:leaveId
// ─────────────────────────────────────────────────────────────────────────────
/**
 * @route   GET /leave-trail/:leaveId
 * @desc    Returns the complete approval trail for a specific leave.
 *          Both the requesting employee and any involved approver may view it.
 * @access  Authenticated (owner or any approver in the chain)
 */
router.get(
  "/leave-trail/:leaveId",
  asyncHandler(async (req, res) => {
    const { emp_id, tenant_id } = req.user;
    const leaveId = Number(req.params.leaveId);
    const db = req.app.locals.db;

    if (!leaveId || isNaN(leaveId)) {
      return fail(res, "Invalid leaveId");
    }

    // ── Verify leave exists and belongs to this tenant ─────────────────────
    const [leaveRows] = await db.promise().query(
      `SELECT leave_id, emp_id, final_status, leave_type
         FROM leave_master
        WHERE leave_id = ? AND tenant_id = ? LIMIT 1`,
      [leaveId, tenant_id],
    );
    const leave = leaveRows[0];

    if (!leave) {
      return fail(res, "Leave request not found", 404);
    }

    // ── Access guard — only the owner or trail participants may view ────────
    const [trailParticipants] = await db.promise().query(
      `SELECT DISTINCT approver_employee_id
         FROM approval_trail
        WHERE record_id = ? AND module_name = ? AND tenant_id = ?`,
      [leaveId, MODULE_NAME, tenant_id],
    );

    const participantIds = trailParticipants.map((r) => r.approver_employee_id);
    const isOwner = leave.emp_id === emp_id;
    const isParticipant = participantIds.includes(emp_id);

    if (!isOwner && !isParticipant) {
      return fail(
        res,
        "Access denied. You are not associated with this leave request",
        403,
      );
    }

    // ── Fetch trail with actor names ───────────────────────────────────────
    const sql = `
      SELECT
        at.trail_id,
        at.approval_level,
        at.approver_employee_id,
        CONCAT(e.first_name, ' ', e.last_name) AS approver_name,
        at.action,
        at.comments,
        at.action_at
      FROM approval_trail at
      JOIN employee_master e
        ON e.emp_id    = at.approver_employee_id
       AND e.tenant_id = at.tenant_id
      WHERE at.record_id    = ?
        AND at.module_name  = ?
        AND at.tenant_id    = ?
      ORDER BY at.action_at ASC, at.approval_level ASC
    `;

    const [trail] = await db
      .promise()
      .query(sql, [leaveId, MODULE_NAME, tenant_id]);

    return ok(
      res,
      {
        leave_id: leave.leave_id,
        leave_type: leave.leave_type,
        final_status: leave.final_status,
        trail,
      },
      "Approval trail fetched successfully",
    );
  }),
);

// ─── Export ───────────────────────────────────────────────────────────────────
module.exports = router;
