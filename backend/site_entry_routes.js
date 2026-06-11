"use strict";

const express = require("express");
const router = express.Router();
const db = require("./config/db");
const authMiddleware = require("./middleware/auth");

function requireAuth(req, res, next) {
  authMiddleware(req, res, () => {
    if (!req.user)
      return res.status(401).json({ success: false, message: "Unauthorized." });
    req.user.tenantId = req.user.tenant_id ?? req.headers["x-tenant-id"];
    req.user.empId = req.user.emp_id ?? req.headers["x-employee-id"];
    next();
  });
}

function requireAdmin(req, res, next) {
  const role = (req.user?.role_name || "").toLowerCase().trim();
  if (!["admin", "hr", "team lead", "tl"].includes(role))
    return res.status(403).json({ success: false, message: "Forbidden." });
  next();
}

function getISTDate() {
  return new Date(
    new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }),
  );
}
function nowDatetime() {
  const d = getISTDate();
  return (
    [
      d.getFullYear(),
      String(d.getMonth() + 1).padStart(2, "0"),
      String(d.getDate()).padStart(2, "0"),
    ].join("-") +
    " " +
    [
      String(d.getHours()).padStart(2, "0"),
      String(d.getMinutes()).padStart(2, "0"),
      String(d.getSeconds()).padStart(2, "0"),
    ].join(":")
  );
}
function todayDate() {
  return nowDatetime().split(" ")[0];
}

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
function toISTStr(date) {
  if (!date || !(date instanceof Date)) return date;
  return new Date(date.getTime() + IST_OFFSET_MS)
    .toISOString()
    .slice(0, 19)
    .replace("T", " ");
}
function normalizeRecord(r) {
  if (!r) return r;
  r.checkin_time = toISTStr(r.checkin_time);
  r.checkout_time = toISTStr(r.checkout_time);
  r.paused_at = toISTStr(r.paused_at);
  if (r.work_date instanceof Date)
    r.work_date = toISTStr(r.work_date).slice(0, 10);
  return r;
}

function haversineMetres(lat1, lng1, lat2, lng2) {
  const R = 6_371_000;
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(Δφ / 2) ** 2 + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function centroid(polygonJson) {
  try {
    const pts = JSON.parse(polygonJson);
    if (!Array.isArray(pts) || pts.length === 0) return null;
    const sumLat = pts.reduce((s, p) => s + p.lat, 0);
    const sumLng = pts.reduce((s, p) => s + p.lng, 0);
    return { lat: sumLat / pts.length, lng: sumLng / pts.length };
  } catch {
    return null;
  }
}

function pointInPolygon(lat, lng, polygonJson) {
  try {
    const pts = JSON.parse(polygonJson);
    if (!Array.isArray(pts) || pts.length < 3) return false;
    let inside = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const xi = pts[i].lng,
        yi = pts[i].lat;
      const xj = pts[j].lng,
        yj = pts[j].lat;
      const intersect =
        yi > lat !== yj > lat &&
        lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi;
      if (intersect) inside = !inside;
    }
    return inside;
  } catch {
    return false;
  }
}

async function findNearbySites(tenantId, lat, lng, radiusMetres = 50) {
  const today = todayDate();
  const [sites] = await db.query(
    `SELECT id, site_name, polygon_json
     FROM sites
     WHERE tenant_id  = ?
       AND start_date <= ?
       AND end_date   >= ?`,
    [tenantId, today, today],
  );

  return sites.filter((s) => {
    if (!s.polygon_json) return false;
    if (pointInPolygon(lat, lng, s.polygon_json)) return true;
    const c = centroid(s.polygon_json);
    if (!c) return false;
    return haversineMetres(lat, lng, c.lat, c.lng) <= radiusMetres;
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — credit attendance-accrual leave balance on checkout
// ─────────────────────────────────────────────────────────────────────────────
async function runAttendanceAccrual(tenantId, empId, workDate) {
  const year = new Date(workDate).getFullYear();

  const [accrualTypes] = await db.query(
    `SELECT leave_name, attendance_accrual_streak, attendance_accrual_reward
     FROM leave_type_master
     WHERE tenant_id = ? AND attendance_accrual_enabled = 1
       AND is_active = 1
       AND attendance_accrual_streak > 0
       AND attendance_accrual_reward > 0`,
    [tenantId],
  );
  if (!accrualTypes.length) return;

  const [[countRow]] = await db.query(
    `SELECT COUNT(DISTINCT work_date) AS present_count
     FROM employee_attendance
     WHERE tenant_id    = ?
       AND employee_id  = ?
       AND status       = 'completed'
       AND checkin_time  IS NOT NULL
       AND checkout_time IS NOT NULL
       AND work_date BETWEEN ? AND ?`,
    [tenantId, empId, `${year}-01-01`, workDate],
  );
  const presentCount = Number(countRow?.present_count ?? 0);
  if (presentCount === 0) return;

  for (const lt of accrualTypes) {
    const streak = Number(lt.attendance_accrual_streak);
    const reward = Number(lt.attendance_accrual_reward);
    if (presentCount % streak !== 0) continue;

    await db.query(
      `INSERT INTO leave_balance
         (emp_id, leave_type, year, allocated_days, used_days, pending_days, carry_forward, tenant_id)
       VALUES (?, ?, ?, ?, 0, 0, 0, ?)
       ON DUPLICATE KEY UPDATE
         allocated_days = allocated_days + VALUES(allocated_days),
         updated_at     = NOW()`,
      [empId, lt.leave_name, year, reward, tenantId],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: fetch attendance policy for a tenant
// ─────────────────────────────────────────────────────────────────────────────
async function getPolicy(tenantId) {
  const [[policy]] = await db.query(
    `SELECT office_in_time,
            office_out_time,
            late_after_minutes,
            multiple_in_out_allowed,
            auto_checkout_enabled
     FROM attendance_policy
     WHERE tenant_id = ?
     LIMIT 1`,
    [tenantId],
  );
  return policy ?? null;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/site-entry/nearby-sites
// ─────────────────────────────────────────────────────────────────────────────
router.get("/nearby-sites", requireAuth, async (req, res) => {
  const { tenantId } = req.user;
  const lat = parseFloat(req.query.lat);
  const lng = parseFloat(req.query.lng);
  const radius = parseFloat(req.query.radius ?? 50);
  if (isNaN(lat) || isNaN(lng))
    return res
      .status(400)
      .json({ success: false, message: "lat and lng are required." });
  try {
    const nearby = await findNearbySites(tenantId, lat, lng, radius);
    res.json({
      success: true,
      sites: nearby.map((s) => ({ id: s.id, site_name: s.site_name })),
    });
  } catch (err) {
    console.error("[GET /nearby-sites]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/site-entry/face-verified-today
// ─────────────────────────────────────────────────────────────────────────────
router.get("/face-verified-today", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [[row]] = await db.query(
      `SELECT COUNT(*) AS cnt
       FROM employee_attendance
       WHERE tenant_id       = ?
         AND employee_id     = ?
         AND attendance_mode = 'site_entry'
         AND work_date       = ?`,
      [tenantId, empId, todayDate()],
    );
    res.json({ success: true, verified: (row.cnt ?? 0) > 0 });
  } catch (err) {
    console.error("[GET /face-verified-today]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/site-entry/today
// ─────────────────────────────────────────────────────────────────────────────
router.get("/today", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const [records] = await db.query(
      `SELECT
          ea.attendance_id, ea.site_id, s.site_name,
          ea.checkin_time, ea.checkout_time, ea.work_date, ea.status,
          ea.checkin_latitude, ea.checkin_longitude,
          ea.checkout_latitude, ea.checkout_longitude,
          ea.last_known_latitude, ea.last_known_longitude,
          ea.last_location_updated_at,
          ea.is_late, ea.late_minutes, ea.total_work_time,
          ea.paused_at, ea.total_pause_secs
       FROM employee_attendance ea
       LEFT JOIN sites s ON s.id = ea.site_id
       WHERE ea.tenant_id       = ?
         AND ea.employee_id     = ?
         AND ea.work_date       = ?
         AND ea.attendance_mode = 'site_entry'
       ORDER BY ea.attendance_id ASC`,
      [tenantId, empId, todayDate()],
    );

    const [sites] = await db.query(
      `SELECT id, site_name FROM sites
       WHERE tenant_id  = ?
         AND start_date <= ?
         AND end_date   >= ?
       ORDER BY site_name ASC`,
      [tenantId, todayDate(), todayDate()],
    );

    const policy = await getPolicy(tenantId);

    // Sum all completed sessions' work time for today
    const [[totalRow]] = await db.query(
      `SELECT SEC_TO_TIME(
         SUM(TIMESTAMPDIFF(SECOND, checkin_time, checkout_time))
       ) AS daily_total
       FROM employee_attendance
       WHERE tenant_id       = ?
         AND employee_id     = ?
         AND work_date       = ?
         AND attendance_mode = 'site_entry'
         AND status          = 'completed'
         AND checkin_time IS NOT NULL
         AND checkout_time IS NOT NULL`,
      [tenantId, empId, todayDate()],
    );

    res.json({
      success: true,
      records: records.map(normalizeRecord),
      sites,
      policy: policy ?? null,
      daily_total: totalRow?.daily_total ?? null,
    });
  } catch (err) {
    console.error("[GET /site-entry/today]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

router.post("/checkin", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  const { site_id, latitude, longitude } = req.body;

  if (!site_id || latitude == null || longitude == null)
    return res.status(400).json({
      success: false,
      message: "site_id, latitude and longitude are required.",
    });

  try {
    // Fetch policy first — needed for multiple_in_out_allowed + late check
    const policy = await getPolicy(tenantId);

    // ── Policy: multiple_in_out_allowed ────────────────────────────────────
    if (!(policy.multiple_in_out_allowed ?? 1)) {
      const [[anyToday]] = await db.query(
        `SELECT COUNT(*) AS cnt
         FROM employee_attendance
         WHERE tenant_id       = ?
           AND employee_id     = ?
           AND work_date       = ?
           AND attendance_mode = 'site_entry'`,
        [tenantId, empId, todayDate()],
      );
      if ((anyToday.cnt ?? 0) > 0)
        return res.status(409).json({
          success: false,
          message:
            "Multiple check-ins are not allowed. You have already checked in today.",
        });
    }

    // Verify site belongs to tenant and is active today
    const [[site]] = await db.query(
      `SELECT id, site_name FROM sites
       WHERE id = ? AND tenant_id = ? AND start_date <= ? AND end_date >= ?`,
      [site_id, tenantId, todayDate(), todayDate()],
    );
    if (!site)
      return res
        .status(404)
        .json({ success: false, message: "Site not found or inactive." });

    // Check if already active on THIS site
    const [[sameActive]] = await db.query(
      `SELECT attendance_id, status, paused_at
       FROM employee_attendance
       WHERE tenant_id       = ?
         AND employee_id     = ?
         AND site_id         = ?
         AND work_date       = ?
         AND attendance_mode = 'site_entry'
         AND status          = 'active'
       ORDER BY attendance_id DESC LIMIT 1`,
      [tenantId, empId, site_id, todayDate()],
    );

    if (sameActive) {
      if (sameActive.paused_at) {
        const pausedSeconds = Math.floor(
          (new Date() - new Date(sameActive.paused_at)) / 1000,
        );
        await db.query(
          `UPDATE employee_attendance
           SET paused_at          = NULL,
               total_pause_secs   = total_pause_secs + ?,
               last_known_latitude       = ?,
               last_known_longitude      = ?,
               last_location_updated_at  = ?
           WHERE attendance_id = ?`,
          [
            pausedSeconds,
            latitude,
            longitude,
            nowDatetime(),
            sameActive.attendance_id,
          ],
        );
      }
      return res.status(409).json({
        success: false,
        message: "Already checked in to this site.",
        attendance_id: sameActive.attendance_id,
      });
    }

    const now = nowDatetime();

    // Auto-checkout any active session on a DIFFERENT site
    const [[otherActive]] = await db.query(
      `SELECT attendance_id, site_id
       FROM employee_attendance
       WHERE tenant_id       = ?
         AND employee_id     = ?
         AND work_date       = ?
         AND attendance_mode = 'site_entry'
         AND status          = 'active'
       ORDER BY attendance_id DESC LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    if (otherActive) {
      await db.query(
        `UPDATE employee_attendance
         SET checkout_time            = ?,
             checkout_latitude        = ?,
             checkout_longitude       = ?,
             last_known_latitude      = ?,
             last_known_longitude     = ?,
             last_location_updated_at = ?,
             status                   = 'completed',
             force_closed             = 1,
             force_close_reason       = 'Auto-closed: employee moved to another site'
         WHERE attendance_id = ?`,
        [
          now,
          latitude,
          longitude,
          latitude,
          longitude,
          now,
          otherActive.attendance_id,
        ],
      );
    }

    // ── Late check ─────────────────────────────────────────────────────────
    let isLate = 0,
      lateMinutes = 0;
    const [[firstToday]] = await db.query(
      `SELECT COUNT(*) AS cnt FROM employee_attendance
       WHERE tenant_id = ? AND employee_id = ? AND work_date = ? AND attendance_mode = 'site_entry'`,
      [tenantId, empId, todayDate()],
    );
    if (firstToday.cnt === 0 && policy?.office_in_time) {
      const timePart = now.split(" ")[1].slice(0, 5);
      const diff =
        timePart
          .split(":")
          .reduce((a, v, i) => a + (i === 0 ? +v * 60 : +v), 0) -
        policy.office_in_time
          .slice(0, 5)
          .split(":")
          .reduce((a, v, i) => a + (i === 0 ? +v * 60 : +v), 0);
      if (diff > (policy.late_after_minutes ?? 0)) {
        isLate = 1;
        lateMinutes = diff;
      }
    }

    const [result] = await db.query(
      `INSERT INTO employee_attendance
         (tenant_id, employee_id, attendance_mode, site_id,
          checkin_time, work_date, status,
          checkin_latitude, checkin_longitude,
          last_known_latitude, last_known_longitude, last_location_updated_at,
          is_late, late_minutes, total_pause_secs)
       VALUES (?, ?, 'site_entry', ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, 0)`,
      [
        tenantId,
        empId,
        site_id,
        now,
        todayDate(),
        latitude,
        longitude,
        latitude,
        longitude,
        now,
        isLate,
        lateMinutes,
      ],
    );

    const [[record]] = await db.query(
      `SELECT ea.*, s.site_name
       FROM employee_attendance ea
       LEFT JOIN sites s ON s.id = ea.site_id
       WHERE ea.attendance_id = ?`,
      [result.insertId],
    );

    res.status(201).json({
      success: true,
      message: `Checked in to ${site.site_name}.`,
      record: normalizeRecord(record),
      auto_closed_site_id: otherActive?.site_id ?? null,
    });
  } catch (err) {
    console.error("[POST /site-entry/checkin]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/site-entry/checkout
// Body: { attendance_id, latitude, longitude }
// ─────────────────────────────────────────────────────────────────────────────
router.post("/checkout", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  const { attendance_id, latitude, longitude } = req.body;

  if (!attendance_id || latitude == null || longitude == null)
    return res.status(400).json({
      success: false,
      message: "attendance_id, latitude and longitude are required.",
    });

  try {
    const [[active]] = await db.query(
      `SELECT attendance_id, site_id, paused_at, total_pause_secs
       FROM employee_attendance
       WHERE attendance_id   = ?
         AND tenant_id       = ?
         AND employee_id     = ?
         AND attendance_mode = 'site_entry'
         AND status          = 'active'`,
      [attendance_id, tenantId, empId],
    );
    if (!active)
      return res
        .status(404)
        .json({ success: false, message: "No active session found." });

    const now = nowDatetime();

    let extraPauseSecs = 0;
    if (active.paused_at) {
      extraPauseSecs = Math.floor(
        (new Date() - new Date(active.paused_at)) / 1000,
      );
    }

    await db.query(
      `UPDATE employee_attendance
       SET checkout_time            = ?,
           status                   = 'completed',
           checkout_latitude        = ?,
           checkout_longitude       = ?,
           last_known_latitude      = ?,
           last_known_longitude     = ?,
           last_location_updated_at = ?,
           paused_at                = NULL,
           total_pause_secs         = total_pause_secs + ?
       WHERE attendance_id = ?`,
      [
        now,
        latitude,
        longitude,
        latitude,
        longitude,
        now,
        extraPauseSecs,
        active.attendance_id,
      ],
    );

    const [[record]] = await db.query(
      `SELECT ea.*, s.site_name
       FROM employee_attendance ea
       LEFT JOIN sites s ON s.id = ea.site_id
       WHERE ea.attendance_id = ?`,
      [active.attendance_id],
    );

    // ── Attendance accrual ────────────────────────────────────────────────
    try {
      await runAttendanceAccrual(tenantId, empId, todayDate());
    } catch (accrualErr) {
      console.error(
        "[Site Entry Checkout] Accrual error (non-fatal):",
        accrualErr.message,
      );
    }

  

    res.json({
      success: true,
      message: "Checked out successfully.",
      record: normalizeRecord(record),
    });
  } catch (err) {
    console.error("[POST /site-entry/checkout]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

router.patch("/update-location", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  const { latitude, longitude } = req.body;

  if (latitude == null || longitude == null)
    return res.status(400).json({
      success: false,
      message: "latitude and longitude are required.",
    });

  try {
    const now = nowDatetime();
    const nowMs = Date.now();

    // Fetch policy — needed for auto_checkout_enabled
    const policy = await getPolicy(tenantId);
    const autoCheckoutEnabled = !!(policy.auto_checkout_enabled ?? 0);

    // 1. Find current active session (if any)
    const [[active]] = await db.query(
      `SELECT ea.attendance_id, ea.site_id, ea.paused_at, ea.total_pause_secs,
              s.polygon_json, s.site_name
       FROM employee_attendance ea
       LEFT JOIN sites s ON s.id = ea.site_id
       WHERE ea.tenant_id       = ?
         AND ea.employee_id     = ?
         AND ea.work_date       = ?
         AND ea.attendance_mode = 'site_entry'
         AND ea.status          = 'active'
       ORDER BY ea.attendance_id DESC LIMIT 1`,
      [tenantId, empId, todayDate()],
    );

    // 2. Find which sites the employee is currently inside
    const nearbySites = await findNearbySites(
      tenantId,
      latitude,
      longitude,
      50,
    );
    const nearbyIds = new Set(nearbySites.map((s) => s.id));

    // ── CASE: No active session ────────────────────────────────────────────
    if (!active) {
      return res.json({
        success: true,
        action: "no_active_session",
        nearby: nearbySites.map((s) => ({ id: s.id, site_name: s.site_name })),
      });
    }

    const isOnActiveSite = nearbyIds.has(active.site_id);

    // ── CASE: Still on the same site ──────────────────────────────────────
    if (isOnActiveSite) {
      let pausedSecsToAdd = 0;
      if (active.paused_at) {
        pausedSecsToAdd = Math.floor(
          (nowMs - new Date(active.paused_at).getTime()) / 1000,
        );
      }
      await db.query(
        `UPDATE employee_attendance
         SET last_known_latitude       = ?,
             last_known_longitude      = ?,
             last_location_updated_at  = ?,
             paused_at                 = NULL,
             total_pause_secs          = total_pause_secs + ?
         WHERE attendance_id = ?`,
        [latitude, longitude, now, pausedSecsToAdd, active.attendance_id],
      );
      return res.json({
        success: true,
        action: "location_updated",
        site_id: active.site_id,
      });
    }

    // ── CASE: Not on active site ───────────────────────────────────────────
    const pausedAt = active.paused_at ? new Date(active.paused_at) : null;
    const pausedMs = pausedAt ? nowMs - pausedAt.getTime() : 0;
    const TEN_MIN_MS = 10 * 60 * 1000;

    // Check if employee is at a DIFFERENT site
    const otherSite = nearbySites.find((s) => s.id !== active.site_id);

    if (otherSite) {
      // Auto-checkout current, auto check-in to new site
      let extraPauseSecs = pausedAt ? Math.floor(pausedMs / 1000) : 0;
      await db.query(
        `UPDATE employee_attendance
         SET checkout_time            = ?,
             checkout_latitude        = ?,
             checkout_longitude       = ?,
             last_known_latitude      = ?,
             last_known_longitude     = ?,
             last_location_updated_at = ?,
             status                   = 'completed',
             paused_at                = NULL,
             total_pause_secs         = total_pause_secs + ?,
             force_closed             = 1,
             force_close_reason       = 'Auto-closed: moved to another site'
         WHERE attendance_id = ?`,
        [
          now,
          latitude,
          longitude,
          latitude,
          longitude,
          now,
          extraPauseSecs,
          active.attendance_id,
        ],
      );

      const [ins] = await db.query(
        `INSERT INTO employee_attendance
           (tenant_id, employee_id, attendance_mode, site_id,
            checkin_time, work_date, status,
            checkin_latitude, checkin_longitude,
            last_known_latitude, last_known_longitude, last_location_updated_at,
            is_late, late_minutes, total_pause_secs)
         VALUES (?, ?, 'site_entry', ?, ?, ?, 'active', ?, ?, ?, ?, ?, 0, 0, 0)`,
        [
          tenantId,
          empId,
          otherSite.id,
          now,
          todayDate(),
          latitude,
          longitude,
          latitude,
          longitude,
          now,
        ],
      );

      return res.json({
        success: true,
        action: "site_switched",
        closed_site: { id: active.site_id, name: active.site_name },
        new_session: {
          attendance_id: ins.insertId,
          site_id: otherSite.id,
          site_name: otherSite.site_name,
        },
      });
    }

    // ── Employee has left all sites ────────────────────────────────────────

    if (!pausedAt) {
      // First ping outside the site — set paused_at
      await db.query(
        `UPDATE employee_attendance
         SET paused_at                = ?,
             last_known_latitude      = ?,
             last_known_longitude     = ?,
             last_location_updated_at = ?
         WHERE attendance_id = ?`,
        [now, latitude, longitude, now, active.attendance_id],
      );
      return res.json({
        success: true,
        action: "paused",
        attendance_id: active.attendance_id,
      });
    }

    if (pausedMs < TEN_MIN_MS) {
      // Still within grace window — update coords, keep paused
      await db.query(
        `UPDATE employee_attendance
         SET last_known_latitude      = ?,
             last_known_longitude     = ?,
             last_location_updated_at = ?
         WHERE attendance_id = ?`,
        [latitude, longitude, now, active.attendance_id],
      );
      return res.json({
        success: true,
        action: "still_paused",
        paused_since: active.paused_at,
        remaining_grace: Math.ceil((TEN_MIN_MS - pausedMs) / 60000),
      });
    }

    // ── Beyond 10 min grace ───────────────────────────────────────────────
    if (!autoCheckoutEnabled) {
      await db.query(
        `UPDATE employee_attendance
         SET last_known_latitude      = ?,
             last_known_longitude     = ?,
             last_location_updated_at = ?
         WHERE attendance_id = ?`,
        [latitude, longitude, now, active.attendance_id],
      );
      return res.json({
        success: true,
        action: "extend_pause",
        attendance_id: active.attendance_id,
        paused_since: active.paused_at,
        paused_minutes: Math.floor(pausedMs / 60000),
      });
    }

    // ── auto_checkout_enabled = 1 → auto-checkout ─────────────────────────
    const extraPauseSecs = Math.floor(pausedMs / 1000);
    await db.query(
      `UPDATE employee_attendance
       SET checkout_time            = ?,
           checkout_latitude        = ?,
           checkout_longitude       = ?,
           last_known_latitude      = ?,
           last_known_longitude     = ?,
           last_location_updated_at = ?,
           status                   = 'completed',
           paused_at                = NULL,
           total_pause_secs         = total_pause_secs + ?,
           force_closed             = 1,
           force_close_reason       = 'Auto-closed: employee absent from site for >10 minutes'
       WHERE attendance_id = ?`,
      [
        now,
        latitude,
        longitude,
        latitude,
        longitude,
        now,
        extraPauseSecs,
        active.attendance_id,
      ],
    );

    return res.json({
      success: true,
      action: "auto_checked_out",
      attendance_id: active.attendance_id,
      reason: "absent_over_10_min",
    });
  } catch (err) {
    console.error("[PATCH /site-entry/update-location]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/site-entry/history
// ─────────────────────────────────────────────────────────────────────────────
router.get("/history", requireAuth, async (req, res) => {
  const { tenantId, empId } = req.user;
  try {
    const limit = Math.min(Number(req.query.limit ?? 20), 100);
    const offset = Math.min(Number(req.query.offset ?? 0), 10000);

    const [records] = await db.query(
      `SELECT
          ea.attendance_id, ea.site_id, s.site_name,
          ea.work_date, ea.checkin_time, ea.checkout_time,
          ea.status, ea.total_work_time,
          ea.is_late, ea.late_minutes,
          ea.checkin_latitude, ea.checkin_longitude,
          ea.checkout_latitude, ea.checkout_longitude,
          ea.paused_at, ea.total_pause_secs,
          ea.force_closed, ea.force_close_reason
       FROM employee_attendance ea
       LEFT JOIN sites s ON s.id = ea.site_id
       WHERE ea.tenant_id       = ?
         AND ea.employee_id     = ?
         AND ea.attendance_mode = 'site_entry'
       ORDER BY ea.work_date DESC, ea.attendance_id DESC
       LIMIT ? OFFSET ?`,
      [tenantId, empId, limit, offset],
    );

    res.json({ success: true, records: records.map(normalizeRecord) });
  } catch (err) {
    console.error("[GET /site-entry/history]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/site-entry/admin/all
// ─────────────────────────────────────────────────────────────────────────────
router.get("/admin/all", requireAuth, requireAdmin, async (req, res) => {
  const { tenantId } = req.user;
  try {
    const date = req.query.date || todayDate();
    const siteId = req.query.site_id || "";
    const status = req.query.status || "";
    const search = (req.query.search || "").trim();
    const limit = Math.min(Number(req.query.limit ?? 50), 200);
    const offset = Number(req.query.offset ?? 0);

    const wheres = [
      "ea.tenant_id       = ?",
      "ea.attendance_mode = 'site_entry'",
      "ea.work_date       = ?",
    ];
    const params = [tenantId, date];

    if (siteId) {
      wheres.push("ea.site_id = ?");
      params.push(siteId);
    }
    if (status) {
      wheres.push("ea.status  = ?");
      params.push(status);
    }
    if (search) {
      wheres.push(
        "(CONCAT_WS(' ', e.first_name, e.last_name) LIKE ? OR CAST(ea.employee_id AS CHAR) LIKE ?)",
      );
      params.push(`%${search}%`, `%${search}%`);
    }

    const [records] = await db.query(
      `SELECT
          ea.attendance_id, ea.employee_id,
          COALESCE(
            CONCAT_WS(' ', e.first_name, NULLIF(e.mid_name,''), e.last_name),
            CONCAT('Employee #', ea.employee_id)
          )                           AS employee_name,
          d.department_name           AS department,
          ea.site_id, s.site_name,
          ea.work_date, ea.checkin_time, ea.checkout_time,
          ea.status, ea.total_work_time,
          ea.is_late, ea.late_minutes,
          ea.checkin_latitude, ea.checkin_longitude,
          ea.checkout_latitude, ea.checkout_longitude,
          ea.last_known_latitude, ea.last_known_longitude,
          ea.last_location_updated_at,
          ea.force_closed, ea.force_close_reason,
          ea.paused_at, ea.total_pause_secs
       FROM employee_attendance ea
       LEFT JOIN employee_master   e  ON e.emp_id          = ea.employee_id
                                     AND CONVERT(e.tenant_id  USING utf8mb4) = CONVERT(ea.tenant_id USING utf8mb4)
       LEFT JOIN designation_master dg ON dg.designation_id = e.designation_id
                                     AND CONVERT(dg.tenant_id USING utf8mb4) = CONVERT(ea.tenant_id USING utf8mb4)
       LEFT JOIN department_master  d  ON d.department_id   = dg.department_id
                                     AND CONVERT(d.tenant_id  USING utf8mb4) = CONVERT(ea.tenant_id USING utf8mb4)
       LEFT JOIN sites              s  ON s.id              = ea.site_id
       WHERE ${wheres.join(" AND ")}
       ORDER BY ea.employee_id ASC, ea.attendance_id ASC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    const [[stats]] = await db.query(
      `SELECT
          COUNT(DISTINCT ea.employee_id)                                             AS present_today,
          COUNT(DISTINCT CASE WHEN ea.is_late = 1 THEN ea.employee_id END)          AS late_today,
          COUNT(DISTINCT CASE WHEN ea.status  = 'active' THEN ea.employee_id END)   AS active_now,
          COUNT(*)                                                                   AS total_sessions
       FROM employee_attendance ea
       WHERE ea.tenant_id       = ?
         AND ea.attendance_mode = 'site_entry'
         AND ea.work_date       = ?`,
      [tenantId, date],
    );

    res.json({
      success: true,
      records: records.map(normalizeRecord),
      stats: {
        present_today: Number(stats.present_today ?? 0),
        late_today: Number(stats.late_today ?? 0),
        active_now: Number(stats.active_now ?? 0),
        total_sessions: Number(stats.total_sessions ?? 0),
      },
    });
  } catch (err) {
    console.error("[GET /site-entry/admin/all]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
