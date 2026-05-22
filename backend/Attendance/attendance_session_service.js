const db = require("../config/db"); // adjust to your db import

/** Today's date in 'YYYY-MM-DD' (server local, adjust if you use UTC). */
function todayDate() {
  return new Date().toISOString().slice(0, 10);
}

function toMysqlDatetime(isoString) {
  return new Date(isoString).toISOString().slice(0, 19).replace("T", " ");
}

/** Returns true for location-based modes. */
function isLocationMode(mode) {
  return mode === "gps" || mode === "gps_face";
}

async function forceCloseSession(params) {
  const {
    tenantId,
    employeeId,
    sessionId,
    closeTime,
    reason,
    closedByLoginId = null,
    workDate,
    mode: modeHint,
    checkoutLocation,
  } = params;

  if (!tenantId || !employeeId || !closeTime || !reason) {
    const err = new Error(
      "tenantId, employeeId, closeTime, and reason are required.",
    );
    err.statusCode = 400;
    throw err;
  }

  const closeStr = toMysqlDatetime(closeTime);
  const date = workDate ?? todayDate();

  // ── 1. Resolve the active session row ──────────────────────────────────────
  let row;

  if (sessionId) {
    [[row]] = await db.query(
      `SELECT attendance_id, attendance_mode,
              last_known_latitude, last_known_longitude
       FROM   employee_attendance
       WHERE  attendance_id   = ?
         AND  tenant_id       = ?
         AND  status          = 'active'
       LIMIT  1`,
      [sessionId, tenantId],
    );
  } else {
    [[row]] = await db.query(
      `SELECT attendance_id, attendance_mode,
              last_known_latitude, last_known_longitude
       FROM   employee_attendance
       WHERE  tenant_id   = ?
         AND  employee_id = ?
         AND  work_date   = ?
         AND  status      = 'active'
       ORDER  BY attendance_id DESC
       LIMIT  1`,
      [tenantId, employeeId, date],
    );
  }

  if (!row) {
    const err = new Error("Active session not found.");
    err.statusCode = 404;
    throw err;
  }

  const { attendance_id, attendance_mode } = row;
  const resolvedMode = modeHint ?? attendance_mode; // trust DB if not supplied

  // ── 2. Resolve checkout coordinates ────────────────────────────────────────
  let checkoutLat = null;
  let checkoutLng = null;

  if (isLocationMode(resolvedMode)) {
    if (
      checkoutLocation?.latitude != null &&
      checkoutLocation?.longitude != null
    ) {
      // Caller supplied a fresh location (e.g. device sent coords on close)
      checkoutLat = checkoutLocation.latitude;
      checkoutLng = checkoutLocation.longitude;
    } else {
      // Fall back to the last synced location already in the DB
      checkoutLat = row.last_known_latitude ?? null;
      checkoutLng = row.last_known_longitude ?? null;
    }
  }

  const baseFields = `
    checkout_time      = ?,
    status             = 'completed',
    force_closed       = 1,
    force_close_reason = ?,
    force_closed_by    = ?
  `;

  const baseValues = [closeStr, reason, closedByLoginId];

  let sql, values;

  if (isLocationMode(resolvedMode)) {
    sql = `
      UPDATE employee_attendance
      SET    ${baseFields},
             checkout_latitude  = ?,
             checkout_longitude = ?
      WHERE  attendance_id = ?
    `;
    values = [...baseValues, checkoutLat, checkoutLng, attendance_id];
  } else {
    sql = `
      UPDATE employee_attendance
      SET    ${baseFields}
      WHERE  attendance_id = ?
    `;
    values = [...baseValues, attendance_id];
  }

  await db.query(sql, values);

  return {
    attendance_id,
    mode: resolvedMode,
    checkout_latitude: checkoutLat,
    checkout_longitude: checkoutLng,
  };
}

async function forceCloseAllSessions(params) {
  const {
    tenantId,
    closeTime,
    reason,
    closedByLoginId = null,
    workDate,
  } = params;

  if (!tenantId || !closeTime || !reason) {
    const err = new Error("tenantId, closeTime, and reason are required.");
    err.statusCode = 400;
    throw err;
  }

  const date = workDate ?? todayDate();

  // Fetch all active sessions with their mode + last location
  const [sessions] = await db.query(
    `SELECT ea.attendance_id,
            ea.employee_id,
            ea.attendance_mode,
            ea.last_known_latitude,
            ea.last_known_longitude
     FROM   employee_attendance ea
     WHERE  ea.tenant_id  = ?
       AND  ea.work_date  = ?
       AND  ea.status     = 'active'
     ORDER  BY ea.attendance_id`,
    [tenantId, date],
  );

  if (sessions.length === 0) {
    return { sessions_closed: 0, details: [] };
  }

  const details = [];

  for (const s of sessions) {
    try {
      const result = await forceCloseSession({
        tenantId,
        employeeId: s.employee_id,
        sessionId: s.attendance_id,
        closeTime,
        reason,
        closedByLoginId,
        workDate: date,
        // Pass mode explicitly – row already loaded above, no extra query
        mode: s.attendance_mode,
      });
      details.push({ ...result, success: true });
    } catch (err) {
      // Don't let one failure abort the rest; collect errors
      details.push({
        attendance_id: s.attendance_id,
        employee_id: s.employee_id,
        success: false,
        error: err.message,
      });
    }
  }

  const sessions_closed = details.filter((d) => d.success).length;
  return { sessions_closed, details };
}

async function syncGpsLocation(params) {
  const { tenantId, employeeId, sessionId, latitude, longitude, workDate } =
    params;

  if (!tenantId || !employeeId || latitude == null || longitude == null) {
    const err = new Error(
      "tenantId, employeeId, latitude, and longitude are required.",
    );
    err.statusCode = 400;
    throw err;
  }

  const date = workDate ?? todayDate();

  let attendance_id;

  if (sessionId) {
    const [[row]] = await db.query(
      `SELECT attendance_id FROM employee_attendance
       WHERE  attendance_id = ?
         AND  tenant_id     = ?
         AND  status        = 'active'
         AND  attendance_mode IN ('gps','gps_face')
       LIMIT  1`,
      [sessionId, tenantId],
    );
    if (!row) {
      const err = new Error("Active GPS session not found.");
      err.statusCode = 404;
      throw err;
    }
    attendance_id = row.attendance_id;
  } else {
    const [[row]] = await db.query(
      `SELECT attendance_id FROM employee_attendance
       WHERE  tenant_id        = ?
         AND  employee_id      = ?
         AND  work_date        = ?
         AND  status           = 'active'
         AND  attendance_mode  IN ('gps','gps_face')
       ORDER  BY attendance_id DESC
       LIMIT  1`,
      [tenantId, employeeId, date],
    );
    if (!row) {
      const err = new Error("Active GPS session not found.");
      err.statusCode = 404;
      throw err;
    }
    attendance_id = row.attendance_id;
  }

  await db.query(
    `UPDATE employee_attendance
     SET    last_known_latitude    = ?,
            last_known_longitude   = ?,
            last_location_updated_at = NOW()
     WHERE  attendance_id = ?`,
    [latitude, longitude, attendance_id],
  );

  return { attendance_id };
}

// ─────────────────────────────────────────────────────────────────────────────
module.exports = { forceCloseSession, forceCloseAllSessions, syncGpsLocation };
