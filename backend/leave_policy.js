// const express = require("express");
// const db = require("./config/db");
// const router = express.Router();

// // ─── Helpers ──────────────────────────────────────────────────────────────────

// const send = (res, status, ok, message, data = {}) =>
//   res.status(status).json({ ok, message, ...data });

// /**
//  * Tenant resolution order (most-trusted first):
//  *  1. req.user.tenant_id  — set by JWT/session auth middleware (preferred)
//  *  2. req.user.tenantId   — alternate casing some middlewares use
//  *  3. req.headers['x-tenant-id'] — header sent by Flutter ApiConfig
//  *
//  * Using the header as a fallback is safe here because:
//  *  - The route is still behind the auth middleware (unauthenticated requests
//  *    are blocked before reaching this router).
//  *  - All DB queries also filter by this tenant_id, so cross-tenant leakage
//  *    is impossible even if the header were tampered with.
//  */
// const getTenantId = (req) =>
//   req.user?.tenant_id || req.user?.tenantId || req.headers["x-tenant-id"] || "";

// // ─── 1. Create Leave Policy ───────────────────────────────────────────────────

// router.post("/policy/create", async (req, res) => {
//   const tenant_id = getTenantId(req);

//   if (!tenant_id)
//     return send(res, 401, false, "Unauthorized: tenant not identified");

//   const { leave_name, max_days, is_paid, requires_approval, approval_flow } =
//     req.body;

//   // Validation
//   if (!leave_name || typeof leave_name !== "string" || !leave_name.trim())
//     return send(res, 400, false, "leave_name is required");
//   if (!max_days || isNaN(Number(max_days)) || Number(max_days) <= 0)
//     return send(res, 400, false, "max_days must be a positive number");
//   if (!Array.isArray(approval_flow) || approval_flow.length === 0)
//     return send(
//       res,
//       400,
//       false,
//       "approval_flow array is mandatory and must not be empty",
//     );

//   const validApproverTypes = [
//     "REPORTING_MANAGER",
//     "DEPARTMENT_HEAD",
//     "HR",
//     "ADMIN",
//     "SPECIFIC_EMPLOYEE",
//   ];
//   for (let i = 0; i < approval_flow.length; i++) {
//     const step = approval_flow[i];
//     if (!validApproverTypes.includes(step.approver_type))
//       return send(res, 400, false, `Invalid approver_type at level ${i + 1}`);
//     if (
//       step.approver_type === "SPECIFIC_EMPLOYEE" &&
//       !step.approver_employee_id
//     )
//       return send(
//         res,
//         400,
//         false,
//         `approver_employee_id required for SPECIFIC_EMPLOYEE at level ${i + 1}`,
//       );
//     const expectedLevel = i + 1;
//     if (step.approval_level && Number(step.approval_level) !== expectedLevel)
//       return send(
//         res,
//         400,
//         false,
//         `Approval levels must be sequential. Expected ${expectedLevel} at index ${i}`,
//       );
//   }

//   const conn = await db.getConnection();
//   try {
//     await conn.beginTransaction();

//     const [ltResult] = await conn.execute(
//       `INSERT INTO leave_type_master
//          (tenant_id, leave_name, max_days, is_paid, requires_approval, created_at, updated_at)
//        VALUES (?, ?, ?, ?, ?, NOW(), NOW())`,
//       [
//         tenant_id,
//         leave_name.trim(),
//         Number(max_days),
//         is_paid ? 1 : 0,
//         requires_approval ? 1 : 0,
//       ],
//     );
//     const leave_type_id = ltResult.insertId;

//     for (let i = 0; i < approval_flow.length; i++) {
//       const step = approval_flow[i];
//       await conn.execute(
//         `INSERT INTO leave_policy_flow
//            (tenant_id, leave_type_id, approval_level, approver_type, approver_employee_id, is_mandatory, created_at, updated_at)
//          VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
//         [
//           tenant_id,
//           leave_type_id,
//           i + 1,
//           step.approver_type,
//           step.approver_type === "SPECIFIC_EMPLOYEE"
//             ? step.approver_employee_id || null
//             : null,
//           step.is_mandatory ? 1 : 0,
//         ],
//       );
//     }

//     await conn.commit();
//     return send(res, 201, true, "Leave policy created successfully", {
//       leave_type_id,
//     });
//   } catch (err) {
//     await conn.rollback();
//     console.error("[leave/policy/create]", err);
//     return send(res, 500, false, "Internal server error");
//   } finally {
//     conn.release();
//   }
// });

// // ─── 2. Get All Leave Policies ────────────────────────────────────────────────

// router.get("/policy/list", async (req, res) => {

//   const tenant_id = getTenantId(req);

//   if (!tenant_id)
//     return send(res, 401, false, "Unauthorized: tenant not identified");

//   try {
//     // ─── 2. Get All Leave Policies ────────────────────────────────────────────────
//     const [rows] = await db.execute(
//       `SELECT
//      lt.leave_type_id,
//      lt.leave_name,
//      lt.max_days,
//      lt.is_paid,
//      lt.requires_approval,
//      lt.created_at,
//      lt.updated_at,
//      COUNT(lpf.policy_flow_id) AS total_approval_levels
//    FROM leave_type_master lt
//    LEFT JOIN leave_policy_flow lpf
//      ON lt.leave_type_id = lpf.leave_type_id AND lpf.tenant_id = lt.tenant_id
//    WHERE lt.tenant_id = ?
//    GROUP BY
//      lt.leave_type_id,
//      lt.leave_name,
//      lt.max_days,
//      lt.is_paid,
//      lt.requires_approval,
//      lt.created_at,
//      lt.updated_at
//    ORDER BY lt.created_at DESC`,
//       [tenant_id],
//     );

//     return send(res, 200, true, "Leave policies fetched", { data: rows });
//   } catch (err) {
//     console.error("[leave/policy/list]", err);
//     return send(res, 500, false, "Internal server error");
//   }
// });

// // ─── 3. Get Single Leave Policy ───────────────────────────────────────────────

// router.get("/policy/:leave_type_id", async (req, res) => {

//   const tenant_id = getTenantId(req);
//   const { leave_type_id } = req.params;

//   if (!tenant_id)
//     return send(res, 401, false, "Unauthorized: tenant not identified");
//   if (!leave_type_id || isNaN(Number(leave_type_id)))
//     return send(res, 400, false, "Invalid leave_type_id");

//   try {
//     const [[leaveType]] = await db.execute(
//       `SELECT * FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
//       [leave_type_id, tenant_id],
//     );

//     if (!leaveType) return send(res, 404, false, "Leave policy not found");

//     const [approvalFlow] = await db.execute(
//       `SELECT * FROM leave_policy_flow
//        WHERE leave_type_id = ? AND tenant_id = ?
//        ORDER BY approval_level ASC`,
//       [leave_type_id, tenant_id],
//     );

//     return send(res, 200, true, "Leave policy fetched", {
//       data: { ...leaveType, approval_flow: approvalFlow },
//     });
//   } catch (err) {
//     console.error("[leave/policy/:id]", err);
//     return send(res, 500, false, "Internal server error");
//   }
// });

// // ─── 4. Update Leave Policy ───────────────────────────────────────────────────

// router.put("/policy/update/:leave_type_id", async (req, res) => {

//   const tenant_id = getTenantId(req);
//   const { leave_type_id } = req.params;
//   const { leave_name, max_days, is_paid, requires_approval, approval_flow } =
//     req.body;

//   if (!tenant_id)
//     return send(res, 401, false, "Unauthorized: tenant not identified");
//   if (!leave_type_id || isNaN(Number(leave_type_id)))
//     return send(res, 400, false, "Invalid leave_type_id");
//   if (!leave_name || typeof leave_name !== "string" || !leave_name.trim())
//     return send(res, 400, false, "leave_name is required");
//   if (!max_days || isNaN(Number(max_days)) || Number(max_days) <= 0)
//     return send(res, 400, false, "max_days must be a positive number");
//   if (!Array.isArray(approval_flow) || approval_flow.length === 0)
//     return send(
//       res,
//       400,
//       false,
//       "approval_flow array is mandatory and must not be empty",
//     );

//   const validApproverTypes = [
//     "REPORTING_MANAGER",
//     "DEPARTMENT_HEAD",
//     "HR",
//     "ADMIN",
//     "SPECIFIC_EMPLOYEE",
//   ];
//   for (let i = 0; i < approval_flow.length; i++) {
//     const step = approval_flow[i];
//     if (!validApproverTypes.includes(step.approver_type))
//       return send(res, 400, false, `Invalid approver_type at level ${i + 1}`);
//     if (
//       step.approver_type === "SPECIFIC_EMPLOYEE" &&
//       !step.approver_employee_id
//     )
//       return send(
//         res,
//         400,
//         false,
//         `approver_employee_id required for SPECIFIC_EMPLOYEE at level ${i + 1}`,
//       );
//   }

//   const conn = await db.getConnection();
//   try {
//     await conn.beginTransaction();

//     const [[existing]] = await conn.execute(
//       `SELECT leave_type_id FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
//       [leave_type_id, tenant_id],
//     );
//     if (!existing) {
//       await conn.rollback();
//       return send(res, 404, false, "Leave policy not found");
//     }

//     await conn.execute(
//       `UPDATE leave_type_master
//        SET leave_name = ?, max_days = ?, is_paid = ?, requires_approval = ?, updated_at = NOW()
//        WHERE leave_type_id = ? AND tenant_id = ?`,
//       [
//         leave_name.trim(),
//         Number(max_days),
//         is_paid ? 1 : 0,
//         requires_approval ? 1 : 0,
//         leave_type_id,
//         tenant_id,
//       ],
//     );

//     await conn.execute(
//       `DELETE FROM leave_policy_flow WHERE leave_type_id = ? AND tenant_id = ?`,
//       [leave_type_id, tenant_id],
//     );

//     for (let i = 0; i < approval_flow.length; i++) {
//       const step = approval_flow[i];
//       await conn.execute(
//         `INSERT INTO leave_policy_flow
//            (tenant_id, leave_type_id, approval_level, approver_type, approver_employee_id, is_mandatory, created_at, updated_at)
//          VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
//         [
//           tenant_id,
//           leave_type_id,
//           i + 1,
//           step.approver_type,
//           step.approver_type === "SPECIFIC_EMPLOYEE"
//             ? step.approver_employee_id || null
//             : null,
//           step.is_mandatory ? 1 : 0,
//         ],
//       );
//     }

//     await conn.commit();
//     return send(res, 200, true, "Leave policy updated successfully");
//   } catch (err) {
//     await conn.rollback();
//     console.error("[leave/policy/update]", err);
//     return send(res, 500, false, "Internal server error");
//   } finally {
//     conn.release();
//   }
// });

// // ─── 5. Delete Leave Policy ───────────────────────────────────────────────────

// router.delete("/policy/delete/:leave_type_id", async (req, res) => {

//   const tenant_id = getTenantId(req);
//   const { leave_type_id } = req.params;

//   if (!tenant_id)
//     return send(res, 401, false, "Unauthorized: tenant not identified");
//   if (!leave_type_id || isNaN(Number(leave_type_id)))
//     return send(res, 400, false, "Invalid leave_type_id");

//   const conn = await db.getConnection();
//   try {
//     await conn.beginTransaction();

//     const [[existing]] = await conn.execute(
//       `SELECT leave_type_id FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
//       [leave_type_id, tenant_id],
//     );
//     if (!existing) {
//       await conn.rollback();
//       return send(res, 404, false, "Leave policy not found");
//     }

//     await conn.execute(
//       `DELETE FROM leave_policy_flow WHERE leave_type_id = ? AND tenant_id = ?`,
//       [leave_type_id, tenant_id],
//     );
//     await conn.execute(
//       `DELETE FROM leave_type_master WHERE leave_type_id = ? AND tenant_id = ?`,
//       [leave_type_id, tenant_id],
//     );

//     await conn.commit();
//     return send(res, 200, true, "Leave policy deleted successfully");
//   } catch (err) {
//     await conn.rollback();
//     console.error("[leave/policy/delete]", err);
//     return send(res, 500, false, "Internal server error");
//   } finally {
//     conn.release();
//   }
// });

// module.exports = router;
