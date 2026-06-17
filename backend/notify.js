
// notify.js
"use strict";

const cron = require("node-cron");
const path = require("path");
const db = require("./config/db");
const { getAdmin } = require("./firebase_admin"); // ← shared init

// ─── DB Helper ────────────────────────────────────────────────────────────────
async function query(sql, params = []) {
  const result = await db.query(sql, params);
  return Array.isArray(result[0]) ? result[0] : result;
}

// ─── Time Helpers ─────────────────────────────────────────────────────────────
function parseTime(timeStr) {
  const [h, m] = (timeStr || "00:00").split(":").map(Number);
  return { h, m };
}

function subtractMinutes({ h, m }, minutes) {
  const total = h * 60 + m - minutes;
  return { h: Math.floor(total / 60), m: total % 60 };
}

function fmt({ h, m }) {
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

function nowHHMM() {
  // Use IST explicitly so server TZ doesn't matter
  const d = new Date();
  const ist = new Date(d.toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
  return `${String(ist.getHours()).padStart(2, "0")}:${String(ist.getMinutes()).padStart(2, "0")}`;
}

function todayDateIST() {
  // Returns YYYY-MM-DD in IST — avoids UTC midnight bug
  const d = new Date();
  const ist = new Date(d.toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
  const yyyy = ist.getFullYear();
  const mm = String(ist.getMonth() + 1).padStart(2, "0");
  const dd = String(ist.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

// ─── Core Logic ───────────────────────────────────────────────────────────────
function calculateReminderTimes(officeInTime) {
  const parsed = parseTime(officeInTime);
  const before30 = fmt(subtractMinutes(parsed, 30));
  const before10 = fmt(subtractMinutes(parsed, 10));
  return { before30, before10 };
}

async function getActiveTenants() {
  return query(`
    SELECT DISTINCT ap.tenant_id, ap.office_in_time
    FROM   attendance_policy ap
    INNER  JOIN tenants t
           ON t.tenant_id COLLATE utf8mb4_unicode_ci
            = ap.tenant_id COLLATE utf8mb4_unicode_ci
    WHERE  t.status IN ('active','trial')
  `);
}

async function getEmployeesForReminder(tenantId) {
  return query(
    `
    SELECT em.emp_id, lm.login_id, lm.fcm_token
    FROM   employee_master em
    INNER  JOIN login_master lm
           ON  lm.emp_id    = em.emp_id
           AND lm.tenant_id COLLATE utf8mb4_unicode_ci
             = em.tenant_id COLLATE utf8mb4_unicode_ci
    WHERE  em.tenant_id          = ?
      AND  em.status             = 'Active'
      AND  lm.status             = 'Active'
      AND  lm.device_active      = 1
      AND  lm.notification_enabled = 1
      AND  lm.fcm_token         IS NOT NULL
      AND  lm.force_logout       = 0
    `,
    [tenantId],
  );
  // NOTE: removed device_logged_in filter — it's often not set correctly
}

async function validateAttendanceStatus(tenantId, empId) {
  const rows = await query(
    `SELECT attendance_id FROM employee_attendance
     WHERE tenant_id = ? AND employee_id = ? AND work_date = ? LIMIT 1`,
    [tenantId, empId, todayDateIST()],
  );
  return rows.length === 0;
}

async function validateDuplicateNotification(tenantId, empId, reminderType) {
  const rows = await query(
    `SELECT id FROM notification_logs
     WHERE  tenant_id = ? AND emp_id = ? AND reminder_type = ?
       AND  DATE(created_at) = ? AND sent_status = 'SENT' LIMIT 1`,
    [tenantId, empId, reminderType, todayDateIST()],
  );
  return rows.length === 0;
}

async function saveNotificationLog({
  tenantId,
  empId,
  title,
  body,
  reminderType,
  sentStatus = "SENT",
  failureReason = null,
}) {
  const [result] = await db.query(
    `INSERT INTO notification_logs
       (tenant_id, emp_id, title, body, reminder_type, channel, is_read, sent_status, failure_reason)
     VALUES (?, ?, ?, ?, ?, 'PUSH', 0, ?, ?)`,
    [tenantId, empId, title, body, reminderType, sentStatus, failureReason],
  );
  return result.insertId;
}

async function updateNotificationLog(id, sentStatus, failureReason = null) {
  await db.query(
    `UPDATE notification_logs SET sent_status = ?, failure_reason = ? WHERE id = ?`,
    [sentStatus, failureReason, id],
  );
}

async function sendPushNotification({ fcmToken, title, body, data = {} }) {
  try {
    const message = {
      token: fcmToken,
      notification: { title, body },
      data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
      android: {
        priority: "high",
        notification: {
          channelId: "attendance_reminders",
          sound: "default",
          priority: "high",
        },
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    };
    await getAdmin().messaging().send(message); // ← uses shared admin
    return { success: true };
  } catch (err) {
    console.error("[notify] FCM send error:", err.message);
    return { success: false, error: err.message };
  }
}

// ─── Reminder Processing ──────────────────────────────────────────────────────
async function processReminderForTenant(tenantId, reminderType, officeInTime) {
  const minutes = reminderType === "before_30_min" ? 30 : 10;
  const title = "Attendance Reminder";
  const body = `Your shift starts in ${minutes} minutes. Please mark your attendance.`;

  const employees = await getEmployeesForReminder(tenantId);
  if (!employees.length) {
    console.log(`[notify] Tenant ${tenantId}: no eligible employees`);
    return;
  }

  for (const { emp_id, fcm_token } of employees) {
    try {
      if (!(await validateAttendanceStatus(tenantId, emp_id))) {
        console.log(
          `[notify] Skipping emp ${emp_id} — attendance already marked`,
        );
        continue;
      }
      if (
        !(await validateDuplicateNotification(tenantId, emp_id, reminderType))
      ) {
        console.log(
          `[notify] Skipping emp ${emp_id} — ${reminderType} already sent today`,
        );
        continue;
      }

      const logId = await saveNotificationLog({
        tenantId,
        empId: emp_id,
        title,
        body,
        reminderType,
      });

      const result = await sendPushNotification({
        fcmToken: fcm_token,
        title,
        body,
        data: {
          type: "attendance_reminder",
          reminder_type: reminderType,
          log_id: String(logId),
          shift_time: officeInTime,
        },
      });

      if (!result.success) {
        await updateNotificationLog(logId, "FAILED", result.error);
        console.warn(`[notify] FCM FAILED emp ${emp_id}: ${result.error}`);
      } else {
        console.log(
          `[notify] ✓ ${reminderType} → emp ${emp_id} (log #${logId})`,
        );
      }
    } catch (err) {
      console.error(`[notify] Error emp ${emp_id}:`, err.message);
    }
  }
}

// ─── Cron ─────────────────────────────────────────────────────────────────────
async function runNotificationCron() {
  const currentTime = nowHHMM();
  console.log(`[notify] Cron tick — ${currentTime} IST`);

  let tenants;
  try {
    tenants = await getActiveTenants();
  } catch (err) {
    console.error("[notify] Failed to fetch tenants:", err.message);
    return;
  }

  if (!tenants.length) {
    console.log("[notify] No active tenants found");
    return;
  }

  for (const { tenant_id, office_in_time } of tenants) {
    try {
      const { before30, before10 } = calculateReminderTimes(office_in_time);
      console.log(
        `[notify] Tenant ${tenant_id}: shift=${office_in_time} before30=${before30} before10=${before10} now=${currentTime}`,
      );

      if (currentTime === before30) {
        await processReminderForTenant(
          tenant_id,
          "before_30_min",
          office_in_time,
        );
      }
      if (currentTime === before10) {
        await processReminderForTenant(
          tenant_id,
          "before_10_min",
          office_in_time,
        );
      }
    } catch (err) {
      console.error(`[notify] Error tenant ${tenant_id}:`, err.message);
    }
  }
}

function initializeNotificationService() {
  getAdmin(); // ensure Firebase is initialized at startup
  cron.schedule("* * * * *", runNotificationCron, { timezone: "Asia/Kolkata" });
  console.log("[notify] Attendance reminder cron started (every 1 min).");
}

module.exports = {
  initializeNotificationService,
  calculateReminderTimes,
  getEmployeesForReminder,
  validateAttendanceStatus,
  validateDuplicateNotification,
  sendPushNotification,
  saveNotificationLog,
};
