    // routes/history.js
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
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────────
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
    if (r.work_date instanceof Date) {
        r.work_date = toISTStr(r.work_date).slice(0, 10);
    }
    return r;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // GET /api/attendance/history
    // Query params:
    //   limit  – max records (default 30, cap 100)
    //   offset – pagination offset (default 0)
    //   mode   – filter by attendance_mode: 'normal' | 'gps' | 'gps_face' | ''(all)
    // ─────────────────────────────────────────────────────────────────────────────
    router.get("/", requireAuth, async (req, res) => {
    const { tenantId, empId } = req.user;
    try {
        const limit = Math.min(Number(req.query.limit ?? 30), 100);
        const offset = Number(req.query.offset ?? 0);
        const mode = (req.query.mode ?? "").trim();

        const whereClauses = ["tenant_id = ?", "employee_id = ?"];
        const params = [tenantId, empId];

        if (mode) {
        whereClauses.push("attendance_mode = ?");
        params.push(mode);
        }

        // ── 1. Fetch paginated records ─────────────────────────────────────────
        const [records] = await db.query(
        `SELECT
            attendance_id,
            work_date,
            checkin_time,
            checkout_time,
            status,
            is_late,
            late_minutes,
            attendance_mode,
            -- Per-session duration (NULL when active / no checkout)
            CASE
                WHEN checkin_time IS NOT NULL AND checkout_time IS NOT NULL
                THEN SEC_TO_TIME(TIMESTAMPDIFF(SECOND, checkin_time, checkout_time))
                ELSE NULL
            END AS total_work_time
        FROM employee_attendance
        WHERE ${whereClauses.join(" AND ")}
        ORDER BY work_date DESC, attendance_id DESC
        LIMIT ? OFFSET ?`,
        [...params, limit, offset],
        );

        // ── 2. Fetch daily totals (all completed sessions per date+mode) ───────
        //    One extra query but avoids N+1 — groups all dates at once.
        const modeParams = mode ? [mode] : [];
        const modeClause = mode ? "AND attendance_mode = ?" : "";

        const [totals] = await db.query(
        `SELECT
            DATE_FORMAT(work_date, '%Y-%m-%d') AS work_date,
            attendance_mode,
            SEC_TO_TIME(
                SUM(TIMESTAMPDIFF(SECOND, checkin_time, checkout_time))
            ) AS daily_total
        FROM employee_attendance
        WHERE tenant_id   = ?
            AND employee_id = ?
            ${modeClause}
            AND status        = 'completed'
            AND checkin_time  IS NOT NULL
            AND checkout_time IS NOT NULL
        GROUP BY work_date, attendance_mode`,
        [tenantId, empId, ...modeParams],
        );

        // Build a lookup: "YYYY-MM-DD_mode" → daily_total string
        const dailyMap = {};
        for (const t of totals) {
        const dateStr =
            t.work_date instanceof Date
            ? t.work_date.toISOString().slice(0, 10)
            : String(t.work_date).slice(0, 10);
        dailyMap[`${dateStr}_${t.attendance_mode}`] = t.daily_total;
        }

        // ── 3. Stamp daily total onto every record ─────────────────────────────
        for (const r of records) {
        const workDateStr =
            r.work_date instanceof Date
            ? r.work_date.toISOString().slice(0, 10)
            : String(r.work_date).slice(0, 10);
        const key = `${workDateStr}_${r.attendance_mode}`;
        if (dailyMap[key]) {
            r.total_work_time = dailyMap[key];
        }
        }

        res.json({ success: true, records: records.map(normalizeRecord) });
    } catch (err) {
        console.error("[GET /attendance/history]", err);
        res.status(500).json({ success: false, message: "Server error." });
    }
    });

    module.exports = router;
