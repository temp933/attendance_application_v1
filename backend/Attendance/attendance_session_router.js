const express = require("express");
const router = express.Router();
const {
  forceCloseSession,
  forceCloseAllSessions,
  syncGpsLocation,
} = require("./attendance_session_service");

function handleError(res, err, context) {
  console.error(`[${context}]`, err);
  const status = err.statusCode ?? 500;
  res
    .status(status)
    .json({ success: false, message: err.message ?? "Server error." });
}

// ── helper: pull tenantId regardless of how auth middleware names it ──────────
function getTenantId(user) {
  return user?.tenantId ?? user?.tenant_id ?? null;
}

// ─────────────────────────────────────────────────────────────────────────────
router.get("/open-sessions", async (req, res) => {
  const tenantId = getTenantId(req.user);
  if (!tenantId) {
    return res
      .status(401)
      .json({ success: false, message: "Missing tenantId in token." });
  }

  const db = require("../config/db");

  try {
    const date =
      (req.query.date ?? "").trim() || new Date().toISOString().slice(0, 10);
    const mode = (req.query.mode ?? "").trim() || null;

    const [rows] = await db.query(
      `SELECT
          ea.attendance_id                                                AS session_id,
          ea.employee_id,
          ea.attendance_mode,
          CONCAT(e.first_name, ' ', e.last_name)                         AS emp_name,
          COALESCE(d.department_name, '')                                AS department_name,
          DATE_FORMAT(
              CONVERT_TZ(ea.checkin_time, '+00:00', '+05:30'),
              '%Y-%m-%d %H:%i:%s'
          )                                                               AS started_at,
          TIMESTAMPDIFF(MINUTE, ea.checkin_time, NOW())                  AS open_minutes,
          ea.is_late,
          ea.late_minutes,
          ea.checkin_latitude,
          ea.checkin_longitude,
          ea.last_known_latitude,
          ea.last_known_longitude,
          CASE
            WHEN ea.last_location_updated_at IS NOT NULL
            THEN DATE_FORMAT(
                    CONVERT_TZ(ea.last_location_updated_at, '+00:00', '+05:30'),
                    '%Y-%m-%d %H:%i:%s'
                 )
            ELSE NULL
          END                                                             AS last_location_updated_at
      FROM  employee_attendance ea
      JOIN  employee_master e
            ON  e.emp_id = ea.employee_id
            AND CONVERT(e.tenant_id   USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
              = CONVERT(ea.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
      LEFT JOIN department_master d
            ON  d.department_id = e.designation_id
            AND CONVERT(d.tenant_id  USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
              = CONVERT(ea.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
       WHERE CONVERT(ea.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
        AND ea.work_date = ?
        AND ea.status    = 'active'
        ${mode ? `AND ea.attendance_mode = ?` : ""}
      ORDER BY open_minutes DESC`,
      mode ? [tenantId, date, mode] : [tenantId, date],
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    handleError(res, err, "GET /open-sessions");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
router.post("/admin-force-close", async (req, res) => {
  const tenantId = getTenantId(req.user);
  if (!tenantId) {
    return res
      .status(401)
      .json({ success: false, message: "Missing tenantId in token." });
  }

  const {
    employee_id,
    session_id,
    close_time,
    reason,
    closed_by_login_id,
    work_date,
    checkout_latitude,
    checkout_longitude,
  } = req.body;

  try {
    const result = await forceCloseSession({
      tenantId,
      employeeId: employee_id,
      sessionId: session_id,
      closeTime: close_time,
      reason,
      closedByLoginId: closed_by_login_id,
      workDate: work_date,
      checkoutLocation:
        checkout_latitude != null && checkout_longitude != null
          ? { latitude: checkout_latitude, longitude: checkout_longitude }
          : undefined,
    });

    res.json({ success: true, sessions_closed: 1, ...result });
  } catch (err) {
    handleError(res, err, "POST /admin-force-close");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
router.post("/admin-force-close-all", async (req, res) => {
  const tenantId = getTenantId(req.user);
  if (!tenantId) {
    return res
      .status(401)
      .json({ success: false, message: "Missing tenantId in token." });
  }

  const { work_date, close_time, reason, closed_by_login_id } = req.body;

  try {
    const result = await forceCloseAllSessions({
      tenantId,
      closeTime: close_time,
      reason,
      closedByLoginId: closed_by_login_id,
      workDate: work_date,
    });

    res.json({ success: true, ...result });
  } catch (err) {
    handleError(res, err, "POST /admin-force-close-all");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
router.post("/sync-location", async (req, res) => {
  const tenantId = getTenantId(req.user);
  if (!tenantId) {
    return res
      .status(401)
      .json({ success: false, message: "Missing tenantId in token." });
  }

  const { employee_id, session_id, latitude, longitude, work_date } = req.body;

  try {
    const result = await syncGpsLocation({
      tenantId,
      employeeId: employee_id,
      sessionId: session_id,
      latitude,
      longitude,
      workDate: work_date,
    });

    res.json({ success: true, ...result });
  } catch (err) {
    handleError(res, err, "POST /sync-location");
  }
});

module.exports = router;
