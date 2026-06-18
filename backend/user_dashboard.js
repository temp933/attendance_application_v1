// const express = require("express");
// const router = express.Router();
// const db = require("./config/db");

// // ── helpers ───────────────────────────────────────────────────────────────────
// const istNow = () => new Date(Date.now() + 5.5 * 60 * 60 * 1000);

// const toIST_HHMM = (val) => {
//   if (!val) return null;
//   // val may be a JS Date, MySQL DATETIME string, or HH:MM:SS time string
//   if (val instanceof Date) {
//     return val.toTimeString().slice(0, 5);
//   }
//   const s = String(val);
//   // MySQL time column comes as "HH:MM:SS"
//   if (/^\d{2}:\d{2}/.test(s)) return s.slice(0, 5);
//   // MySQL datetime string "YYYY-MM-DD HH:MM:SS"
//   if (s.includes(" ")) return s.split(" ")[1].slice(0, 5);
//   return s.slice(0, 5);
// };

// const minutesToHM = (mins) => {
//   if (!mins || mins <= 0) return null;
//   const h = Math.floor(mins / 60);
//   const m = mins % 60;
//   return h > 0 ? `${h}h ${m}m` : `${m}m`;
// };

// const isoDate = (d) => d.toISOString().slice(0, 10);

// // GET /api/user-dashboard
// router.get("/", async (req, res) => {
//   const tenantId = req.user?.tenant_id;
//   const employeeId = req.user?.emp_id;
//   if (!tenantId || !employeeId) {
//     return res.status(401).json({ success: false, message: "Unauthorized." });
//   }

//   try {
//     const now = istNow();
//     const today = isoDate(now);

//     // ── 1. Today's attendance rows (multi in/out) ────────────────────────────
//     // Fetch ALL rows for today, ordered by checkin ascending
//     const [todayRows] = await db.query(
//       `SELECT
//          checkin_time,
//          checkout_time,
//          is_late,
//          late_minutes,
//          total_work_time,
//          status,
//          force_closed
//        FROM employee_attendance
//        WHERE tenant_id = ? AND employee_id = ? AND work_date = ?
//        ORDER BY checkin_time ASC`,
//       [tenantId, employeeId, today],
//     );

//     let todayStatus = "Absent";
//     let checkIn = null;
//     let checkOut = null;
//     let hoursWorked = null;

//     if (todayRows.length > 0) {
//       // First check-in of the day
//       const firstRow = todayRows[0];
//       // Last completed checkout (latest checkout_time that is not null)
//       const lastCheckedOut = [...todayRows]
//         .reverse()
//         .find((r) => r.checkout_time != null);
//       // Active session = any row with status='active' and no checkout
//       const activeRow = todayRows.find(
//         (r) => r.status === "active" && !r.checkout_time,
//       );

//       checkIn = toIST_HHMM(firstRow.checkin_time);
//       checkOut = lastCheckedOut
//         ? toIST_HHMM(lastCheckedOut.checkout_time)
//         : null;

//       // Sum total_work_time across all rows (mysql2 may return TIME as Date or "HH:MM:SS")
//       const totalMins = todayRows.reduce((acc, r) => {
//         if (!r.total_work_time) return acc;
//         let h = 0,
//           m = 0;
//         if (r.total_work_time instanceof Date) {
//           h = r.total_work_time.getUTCHours();
//           m = r.total_work_time.getUTCMinutes();
//         } else {
//           const parts = String(r.total_work_time).split(":");
//           h = parseInt(parts[0], 10) || 0;
//           m = parseInt(parts[1], 10) || 0;
//         }
//         return acc + h * 60 + m;
//       }, 0);
//       hoursWorked = totalMins > 0 ? minutesToHM(totalMins) : null;

//       // Derive display status
//       const anyLate = todayRows.some((r) => r.is_late);
//       if (activeRow) {
//         // Currently checked in
//         todayStatus = anyLate ? "Late Entry" : "Present";
//       } else if (lastCheckedOut) {
//         // All sessions closed
//         todayStatus = anyLate ? "Late Entry" : "Present";
//       }
//     } else {
//       // No attendance rows — check approved leave
//       const [[leaveRow]] = await db.query(
//         `SELECT leave_id FROM leave_master
//          WHERE tenant_id = ? AND emp_id = ?
//            AND final_status = 'Approved'
//            AND leave_start_date <= ? AND leave_end_date >= ?
//          LIMIT 1`,
//         [tenantId, employeeId, today, today],
//       );
//       if (leaveRow) todayStatus = "On Leave";
//     }

//     // ── 2. Recent 7 days ─────────────────────────────────────────────────────
//     const recentRows = [];
//     for (let i = 6; i >= 0; i--) {
//       const d = new Date(now);
//       d.setDate(d.getDate() - i);
//       recentRows.push(isoDate(d));
//     }

//     const [attRows] = await db.query(
//       `SELECT
//          work_date,
//          checkin_time,
//          is_late
//        FROM employee_attendance
//        WHERE tenant_id = ? AND employee_id = ?
//          AND work_date >= ? AND work_date <= ?`,
//       [tenantId, employeeId, recentRows[0], today],
//     );

//     const [leaveRows] = await db.query(
//       `SELECT leave_start_date, leave_end_date
//        FROM leave_master
//        WHERE tenant_id = ? AND emp_id = ?
//          AND final_status = 'Approved'
//          AND leave_start_date <= ? AND leave_end_date >= ?`,
//       [tenantId, employeeId, today, recentRows[0]],
//     );

//     // Group by date — aggregate across multiple rows per day
//     const attByDate = {};
//     attRows.forEach((r) => {
//       const key = isoDate(new Date(r.work_date));
//       if (!attByDate[key]) {
//         attByDate[key] = { hasCheckIn: false, anyLate: false };
//       }
//       if (r.checkin_time) attByDate[key].hasCheckIn = true;
//       if (r.is_late) attByDate[key].anyLate = true;
//     });
//     // Flatten to status string
//     Object.keys(attByDate).forEach((key) => {
//       const { hasCheckIn, anyLate } = attByDate[key];
//       attByDate[key] = hasCheckIn
//         ? anyLate
//           ? "Late Entry"
//           : "Present"
//         : "Absent";
//     });

//     // mark leave days
//     leaveRows.forEach((r) => {
//       const from = new Date(r.leave_start_date);
//       const to = new Date(r.leave_end_date);
//       for (let d = new Date(from); d <= to; d.setDate(d.getDate() + 1)) {
//         const key = isoDate(d);
//         if (!attByDate[key]) attByDate[key] = "On Leave";
//       }
//     });

//     const recentDays = recentRows.map((date) => ({
//       date,
//       status: attByDate[date] ?? "Absent",
//     }));

//     // ── 3. Leave balances ────────────────────────────────────────────────────
//     // leave_balance has leave_type (varchar) — join leave_type_master on leave_name
//     // available = allocated + carry_forward - used - pending
//     const [balances] = await db.query(
//       `SELECT
//          lb.leave_type                                        AS leaveType,
//          (lb.allocated_days + lb.carry_forward)              AS total,
//          (lb.allocated_days + lb.carry_forward
//             - lb.used_days - lb.pending_days)                AS remaining
//        FROM leave_balance lb
//        WHERE lb.tenant_id = ?
//          AND lb.emp_id    = ?
//          AND lb.year      = ?
//        ORDER BY lb.leave_type ASC`,
//       [tenantId, employeeId, now.getFullYear()],
//     );

//     // ── 4. Pending leave count ───────────────────────────────────────────────
//     const [[pendingRow]] = await db.query(
//       `SELECT COUNT(*) AS cnt
//        FROM leave_master
//        WHERE tenant_id  = ?
//          AND emp_id = ?
//          AND final_status = 'Pending'`,
//       [tenantId, employeeId],
//     );
//     const pendingLeaveCount = parseInt(pendingRow.cnt ?? 0, 10);

//     // ── Response ─────────────────────────────────────────────────────────────
//     res.json({
//       success: true,
//       todayStatus,
//       checkIn,
//       checkOut,
//       hoursWorked,
//       recentDays,
//       leaveBalances: balances.map((b) => ({
//         leaveType: b.leaveType,
//         total: parseInt(b.total ?? 0, 10),
//         remaining: parseInt(b.remaining ?? 0, 10),
//       })),
//       pendingLeaveCount,
//     });
//   } catch (err) {
//     console.error("[GET /api/user-dashboard]", err);
//     res.status(500).json({ success: false, message: "Server error." });
//   }
// });

// module.exports = router;
const express = require("express");
const router = express.Router();
const db = require("./config/db");

const istNow = () => new Date(Date.now() + 5.5 * 60 * 60 * 1000);

const toIST_HHMM = (val) => {
  if (!val) return null;
  if (val instanceof Date) return val.toTimeString().slice(0, 5);
  const s = String(val);
  if (/^\d{2}:\d{2}/.test(s)) return s.slice(0, 5);
  if (s.includes(" ")) return s.split(" ")[1].slice(0, 5);
  return s.slice(0, 5);
};

const isoDate = (d) => d.toISOString().slice(0, 10);

const daysBetween = (a, b) => {
  const ms = new Date(b) - new Date(a);
  return Math.round(ms / 86400000);
};

// GET /api/user-dashboard
router.get("/", async (req, res) => {
  const tenantId = req.user?.tenant_id;
  const employeeId = req.user?.emp_id;
  if (!tenantId || !employeeId)
    return res.status(401).json({ success: false, message: "Unauthorized." });

  try {
    const now = istNow();
    const today = isoDate(now);

    // ── 1. Today's attendance (multi in/out) ─────────────────────────────────
    const [todayRows] = await db.query(
      `SELECT checkin_time, checkout_time, is_late, total_work_time, status
       FROM employee_attendance
       WHERE tenant_id = ? AND employee_id = ? AND work_date = ?
       ORDER BY checkin_time ASC`,
      [tenantId, employeeId, today],
    );

    let attendanceStatus = "Absent"; // Present / Late Entry / Absent
    let checkIn = null;
    let checkOut = null;

    if (todayRows.length > 0) {
      const firstRow = todayRows[0];
      const lastCheckedOut = [...todayRows]
        .reverse()
        .find((r) => r.checkout_time != null);
      const activeRow = todayRows.find(
        (r) => r.status === "active" && !r.checkout_time,
      );

      checkIn = toIST_HHMM(firstRow.checkin_time);
      checkOut = lastCheckedOut
        ? toIST_HHMM(lastCheckedOut.checkout_time)
        : null;

      const anyLate = todayRows.some((r) => r.is_late);
      if (activeRow || lastCheckedOut) {
        attendanceStatus = anyLate ? "Late Entry" : "Present";
      }
    }

    // ── 2. Today's context flags ─────────────────────────────────────────────
    // Holiday
    const [[holidayRow]] = await db.query(
      `SELECT holiday_name FROM holiday_master
       WHERE tenant_id = ? AND holiday_date = ?
       LIMIT 1`,
      [tenantId, today],
    );

    // Today's approved leave (for On Leave / Half Day / Comp Off flags)
    const [[todayLeave]] = await db.query(
      `SELECT lt.leave_name, lm.is_half_day, lm.half_day_period
       FROM leave_master lm
       JOIN leave_type_master lt
         ON lt.leave_type_id = lm.leave_type_id
        AND lt.tenant_id     = lm.tenant_id
       WHERE lm.tenant_id  = ? AND lm.emp_id = ?
         AND lm.final_status = 'Approved'
         AND lm.leave_start_date <= ? AND lm.leave_end_date >= ?
       ORDER BY lm.leave_id DESC
       LIMIT 1`,
      [tenantId, employeeId, today, today],
    );

    // Build status flags array — only what's true today
    const todayFlags = [];

    if (holidayRow) {
      todayFlags.push({ type: "holiday", label: holidayRow.holiday_name });
    }

    if (todayLeave) {
      if (todayLeave.is_half_day) {
        const period =
          todayLeave.half_day_period === "AM" ? "Morning" : "Afternoon";
        todayFlags.push({ type: "halfday", label: `Half day · ${period}` });
      } else {
        // Detect comp off by leave name
        const lname = (todayLeave.leave_name ?? "").toLowerCase();
        const isCompOff =
          lname.includes("comp") || lname.includes("compensatory");
        todayFlags.push({
          type: isCompOff ? "compoff" : "onleave",
          label: todayLeave.leave_name,
        });
      }
      // Override attendance status if no check-in
      if (attendanceStatus === "Absent") attendanceStatus = "On Leave";
    }

    // ── 3. Pending leave count ────────────────────────────────────────────────
    const [[pendingRow]] = await db.query(
      `SELECT COUNT(*) AS cnt FROM leave_master
       WHERE tenant_id = ? AND emp_id = ? AND final_status = 'Pending'`,
      [tenantId, employeeId],
    );
    const pendingLeaveCount = parseInt(pendingRow.cnt ?? 0, 10);

    // ── 4. Upcoming approved leave (next 30 days, soonest first) ─────────────
    const [[upcomingLeave]] = await db.query(
      `SELECT lt.leave_name, lm.leave_start_date, lm.leave_end_date, lm.number_of_days
       FROM leave_master lm
       JOIN leave_type_master lt
         ON lt.leave_type_id = lm.leave_type_id
        AND lt.tenant_id     = lm.tenant_id
       WHERE lm.tenant_id    = ? AND lm.emp_id = ?
         AND lm.final_status = 'Approved'
         AND lm.leave_start_date > ?
         AND lm.leave_start_date <= DATE_ADD(?, INTERVAL 30 DAY)
       ORDER BY lm.leave_start_date ASC
       LIMIT 1`,
      [tenantId, employeeId, today, today],
    );

    let upcomingLeaveData = null;
    if (upcomingLeave) {
      const startDate = isoDate(new Date(upcomingLeave.leave_start_date));
      const endDate = isoDate(new Date(upcomingLeave.leave_end_date));
      const daysUntil = daysBetween(today, startDate);
      upcomingLeaveData = {
        leaveName: upcomingLeave.leave_name,
        startDate,
        endDate,
        numberOfDays: parseFloat(upcomingLeave.number_of_days ?? 0),
        daysUntil,
      };
    }

    // ── Response ──────────────────────────────────────────────────────────────
    res.json({
      success: true,
      attendanceStatus,
      checkIn,
      checkOut,
      todayFlags,
      pendingLeaveCount,
      upcomingLeave: upcomingLeaveData,
    });
  } catch (err) {
    console.error("[GET /api/user-dashboard]", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
