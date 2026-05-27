"use strict";

 
const express = require("express");
const db = require("./config/db");
const router = express.Router();

// ─── Shared Helpers ────────────────────────────────────────────────────────────

const getTenantId = (req) =>
  req.user?.tenant_id || req.user?.tenantId || req.headers["x-tenant-id"] || "";

const send = (res, status, ok, message, data = {}) =>
  res.status(status).json({ ok, message, ...data });

function calcDays(startDate, endDate, isHalfDay) {
  if (isHalfDay) return 0.5;
  let count = 0;
  const cur = new Date(startDate);
  const end = new Date(endDate);
  while (cur <= end) {
    if (cur.getDay() !== 0) count++;
    cur.setDate(cur.getDate() + 1);
  }
  return count;
}

/**
 * Resolve the actual emp_id for an approver_type.
 * NOTE: All queries use emp_id (not employee_id) to match the DB schema.
 */
async function resolveApprover(
  conn,
  tenantId,
  empId,
  approverType,
  specificId,
) {
  switch (approverType) {
    case "REPORTING_MANAGER": {
      const [[emp]] = await conn.execute(
        `SELECT reporting_to_employee_id FROM employee_master
          WHERE emp_id = ? AND tenant_id = ? LIMIT 1`,
        [empId, tenantId],
      );
      return emp?.reporting_to_employee_id ?? null;
    }
    case "DEPARTMENT_HEAD": {
      return null; // Future: resolve via department_id
    }
    case "HR": {
      const [[hr]] = await conn.execute(
        `SELECT em.emp_id FROM employee_master em
          JOIN role_master rm ON em.role_id = rm.role_id
          WHERE em.tenant_id = ? AND UPPER(rm.role_name) LIKE '%HR%'
          ORDER BY em.emp_id ASC LIMIT 1`,
        [tenantId],
      );
      return hr?.emp_id ?? null; // ← was hr?.employee_id (bug)
    }
    case "ADMIN": {
      const [[admin]] = await conn.execute(
        `SELECT em.emp_id FROM employee_master em
          JOIN role_master rm ON em.role_id = rm.role_id
          WHERE em.tenant_id = ? AND UPPER(rm.role_name) LIKE '%ADMIN%'
          ORDER BY em.emp_id ASC LIMIT 1`,
        [tenantId],
      );
      return admin?.emp_id ?? null; // ← was admin?.employee_id (bug)
    }
    case "SPECIFIC_EMPLOYEE":
      return specificId ?? null;
    default:
      return null;
  }
}

const VALID_APPROVER_TYPES = [
  "REPORTING_MANAGER",
  "DEPARTMENT_HEAD",
  "HR",
  "ADMIN",
  "SPECIFIC_EMPLOYEE",
];

function validateApprovalFlow(approval_flow) {
  if (!Array.isArray(approval_flow) || approval_flow.length === 0)
    return "approval_flow array is mandatory and must not be empty";
  for (let i = 0; i < approval_flow.length; i++) {
    const step = approval_flow[i];
    if (!VALID_APPROVER_TYPES.includes(step.approver_type))
      return `Invalid approver_type at level ${i + 1}`;
    if (
      step.approver_type === "SPECIFIC_EMPLOYEE" &&
      !step.approver_employee_id
    )
      return `approver_employee_id required for SPECIFIC_EMPLOYEE at level ${i + 1}`;
    const expectedLevel = i + 1;
    if (step.approval_level && Number(step.approval_level) !== expectedLevel)
      return `Approval levels must be sequential. Expected ${expectedLevel} at index ${i}`;
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

  const { leave_name, max_days, is_paid, requires_approval, approval_flow } =
    req.body;

  if (!leave_name || typeof leave_name !== "string" || !leave_name.trim())
    return send(res, 400, false, "leave_name is required");
  if (!max_days || isNaN(Number(max_days)) || Number(max_days) <= 0)
    return send(res, 400, false, "max_days must be a positive number");

  const flowError = validateApprovalFlow(approval_flow);
  if (flowError) return send(res, 400, false, flowError);

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [ltResult] = await conn.execute(
      `INSERT INTO leave_type_master
          (tenant_id, leave_name, max_days, is_paid, requires_approval, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        tenant_id,
        leave_name.trim(),
        Number(max_days),
        is_paid ? 1 : 0,
        requires_approval ? 1 : 0,
      ],
    );
    const leave_type_id = ltResult.insertId;

    for (let i = 0; i < approval_flow.length; i++) {
      const step = approval_flow[i];
      await conn.execute(
        `INSERT INTO leave_policy_flow
            (tenant_id, leave_type_id, approval_level, approver_type, approver_employee_id, is_mandatory, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
        [
          tenant_id,
          leave_type_id,
          i + 1,
          step.approver_type,
          step.approver_type === "SPECIFIC_EMPLOYEE"
            ? step.approver_employee_id || null
            : null,
          step.is_mandatory ? 1 : 0,
        ],
      );
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
          lt.requires_approval, lt.created_at, lt.updated_at,
          COUNT(lpf.policy_flow_id) AS total_approval_levels
        FROM leave_type_master lt
        LEFT JOIN leave_policy_flow lpf
          ON lt.leave_type_id = lpf.leave_type_id AND lpf.tenant_id = lt.tenant_id
        WHERE lt.tenant_id = ?
        GROUP BY lt.leave_type_id, lt.leave_name, lt.max_days,
                  lt.is_paid, lt.requires_approval, lt.created_at, lt.updated_at
        ORDER BY lt.created_at DESC`,
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

    const [approvalFlow] = await db.execute(
      `SELECT * FROM leave_policy_flow
        WHERE leave_type_id = ? AND tenant_id = ? ORDER BY approval_level ASC`,
      [leave_type_id, tenant_id],
    );
    return send(res, 200, true, "Leave policy fetched", {
      data: { ...leaveType, approval_flow: approvalFlow },
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
  const { leave_name, max_days, is_paid, requires_approval, approval_flow } =
    req.body;

  if (!tenant_id)
    return send(res, 401, false, "Unauthorized: tenant not identified");
  if (!leave_type_id || isNaN(Number(leave_type_id)))
    return send(res, 400, false, "Invalid leave_type_id");
  if (!leave_name || typeof leave_name !== "string" || !leave_name.trim())
    return send(res, 400, false, "leave_name is required");
  if (!max_days || isNaN(Number(max_days)) || Number(max_days) <= 0)
    return send(res, 400, false, "max_days must be a positive number");

  const flowError = validateApprovalFlow(approval_flow);
  if (flowError) return send(res, 400, false, flowError);

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[existing]] = await conn.execute(
      `SELECT leave_type_id FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );
    if (!existing) {
      await conn.rollback();
      return send(res, 404, false, "Leave policy not found");
    }

    await conn.execute(
      `UPDATE leave_type_master
        SET leave_name = ?, max_days = ?, is_paid = ?, requires_approval = ?, updated_at = NOW()
        WHERE leave_type_id = ? AND tenant_id = ?`,
      [
        leave_name.trim(),
        Number(max_days),
        is_paid ? 1 : 0,
        requires_approval ? 1 : 0,
        leave_type_id,
        tenant_id,
      ],
    );
    await conn.execute(
      `DELETE FROM leave_policy_flow WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );
    for (let i = 0; i < approval_flow.length; i++) {
      const step = approval_flow[i];
      await conn.execute(
        `INSERT INTO leave_policy_flow
            (tenant_id, leave_type_id, approval_level, approver_type, approver_employee_id, is_mandatory, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
        [
          tenant_id,
          leave_type_id,
          i + 1,
          step.approver_type,
          step.approver_type === "SPECIFIC_EMPLOYEE"
            ? step.approver_employee_id || null
            : null,
          step.is_mandatory ? 1 : 0,
        ],
      );
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
      `SELECT leave_type_id FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
      [leave_type_id, tenant_id],
    );
    if (!existing) {
      await conn.rollback();
      return send(res, 404, false, "Leave policy not found");
    }

    await conn.execute(
      `DELETE FROM leave_policy_flow WHERE leave_type_id = ? AND tenant_id = ?`,
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

  const number_of_days = calcDays(startDt, endDt, is_half_day);
  if (number_of_days === 0)
    return send(
      res,
      400,
      false,
      "Selected date range contains no working days",
    );

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Verify employee belongs to tenant (uses emp_id)
    const [[empRow]] = await conn.execute(
      `SELECT emp_id FROM employee_master WHERE emp_id = ? AND tenant_id = ? LIMIT 1`,
      [emp_id, tenant_id],
    );
    if (!empRow) {
      await conn.rollback();
      return send(res, 403, false, "Employee does not belong to this tenant");
    }

    const [[policy]] = await conn.execute(
      `SELECT leave_type_id, leave_code, requires_approval FROM leave_type_master
    WHERE leave_type_id = ? AND tenant_id = ? AND is_active = 1 LIMIT 1`,
      [leave_type_id, tenant_id],
    );
    if (!policy) {
      await conn.rollback();
      return send(res, 404, false, "Leave policy not found for this tenant");
    }
    const isCompOff = (policy.leave_code ?? "").toUpperCase() === "COMP_OFF";

    // If comp-off, check balance
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

    const [flowRows] = await conn.execute(
      `SELECT * FROM leave_policy_flow
        WHERE leave_type_id = ? AND tenant_id = ? ORDER BY approval_level ASC`,
      [leave_type_id, tenant_id],
    );

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
        flowRows.length > 0 ? 1 : 0,
      ],
    );
    const leave_id = insertResult.insertId;

    // Auto-approve if no approval flow
    if (!policy.requires_approval || flowRows.length === 0 || isCompOff) {
      await conn.execute(
        `UPDATE leave_master
      SET status = 'Approved', final_status = 'Approved',
          current_approver_employee_id = NULL, updated_at = NOW()
      WHERE leave_id = ? AND tenant_id = ?`,
        [leave_id, tenant_id],
      );

      // If comp-off: mark earned records as used
      if (isCompOff) {
        const daysToUse = parseInt(Math.ceil(number_of_days), 10);
        const empIdInt = parseInt(emp_id, 10);

        // Use hardcoded LIMIT in query to avoid prepared statement type issue
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
      return send(
        res,
        201,
        true,
        isCompOff
          ? "Comp-off leave applied successfully"
          : "Leave applied and auto-approved",
        { leave_id },
      );
    }

    let firstApproverEmpId = null;

    for (const step of flowRows) {
      const approverEmpId = await resolveApprover(
        conn,
        tenant_id,
        emp_id,
        step.approver_type,
        step.approver_employee_id,
      );

      if (!approverEmpId && !step.is_mandatory) continue;
      if (!approverEmpId && step.is_mandatory) {
        await conn.rollback();
        return send(
          res,
          422,
          false,
          `Could not resolve mandatory approver for level ${step.approval_level} (${step.approver_type})`,
        );
      }

      await conn.execute(
        `INSERT INTO leave_approval_flow
            (tenant_id, leave_id, approval_level, approver_employee_id, action, created_at)
          VALUES (?, ?, ?, ?, 'Pending', NOW())`,
        [tenant_id, leave_id, step.approval_level, approverEmpId],
      );

      if (step.approval_level === 1) firstApproverEmpId = approverEmpId;
    }

    if (firstApproverEmpId) {
      await conn.execute(
        `UPDATE leave_master
          SET current_approver_employee_id = ?, current_approval_level = 1, updated_at = NOW()
          WHERE leave_id = ? AND tenant_id = ?`,
        [firstApproverEmpId, leave_id, tenant_id],
      );
    }

    await conn.commit();
    return send(res, 201, true, "Leave applied successfully", {
      leave_id,
      number_of_days,
      first_approver_employee_id: firstApproverEmpId,
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
          e.department_id,
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
          e.department_id, lm.leave_type_id, lt.leave_name,
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

    await conn.execute(
      `UPDATE leave_approval_flow
        SET action = 'Approved', action_at = NOW(), remarks = ?
        WHERE leave_id = ? AND tenant_id = ? AND approval_level = ?`,
      [remarks, leave_id, tenant_id, currentLevel],
    );

    const [[nextFlow]] = await conn.execute(
      `SELECT * FROM leave_approval_flow
        WHERE leave_id = ? AND tenant_id = ? AND approval_level = ? LIMIT 1`,
      [leave_id, tenant_id, currentLevel + 1],
    );

    if (nextFlow) {
      await conn.execute(
        `UPDATE leave_master
          SET current_approval_level = ?, current_approver_employee_id = ?,
              last_action_by = ?, last_action_at = NOW(), last_action_remarks = ?, updated_at = NOW()
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
      await conn.execute(
        `UPDATE leave_master
          SET status = 'Approved', final_status = 'Approved',
              current_approver_employee_id = NULL,
              last_action_by = ?, last_action_at = NOW(), last_action_remarks = ?, updated_at = NOW()
          WHERE leave_id = ? AND tenant_id = ?`,
        [approver_emp_id, remarks, leave_id, tenant_id],
      );
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
            last_action_by = ?, last_action_at = NOW(), last_action_remarks = ?, updated_at = NOW()
        WHERE leave_id = ? AND tenant_id = ?`,
      [approver_emp_id, remarks.trim(), leave_id, tenant_id],
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
        SET final_status = 'Cancelled', status = 'Cancelled', cancel_reason = ?, updated_at = NOW()
        WHERE leave_id = ? AND tenant_id = ?`,
      [cancel_reason.trim(), leave_id, tenant_id],
    );

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

// ─── 13. Available Comp-offs for Leave Apply   GET /api/leave/available-compoffs ──

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
          e.department_id,
          d.department_name,
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
        LEFT JOIN department_master d
          ON e.department_id = d.department_id AND d.tenant_id = lm.tenant_id
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
module.exports = router;
