// //  notify.js

// "use strict";

// const cron = require("node-cron");
// const admin = require("firebase-admin");
// const db = require("./config/db"); // mysql2 pool (promise-compatible)
// const path = require("path");
// // ─── Firebase Admin Init ──────────────────────────────────────────────────────
// const serviceAccount = require(
//   path.join(__dirname, "firebase-service-account.json"),
// );
// let firebaseInitialized = false;

// function initFirebase() {
//   if (firebaseInitialized) return;

//   admin.initializeApp({
//     credential: admin.credential.cert(serviceAccount),
//   });

//   firebaseInitialized = true;

//   console.log("[notify] Firebase Admin initialized.");
// }
// // ─── DB Helper ────────────────────────────────────────────────────────────────

// /**
//  * Thin promise wrapper — supports both mysql2 pool (.promise()) and
//  * the callback-style pool used elsewhere in this project.
//  */
// async function query(sql, params = []) {
//   // mysql2 pool with .promise()
//   if (typeof db.query === "function") {
//     const result = await db.query(sql, params);
//     // mysql2 returns [rows, fields]
//     return Array.isArray(result[0]) ? result[0] : result;
//   }
//   throw new Error("[notify] Unsupported DB driver.");
// }

// // ─── Time Helpers ─────────────────────────────────────────────────────────────

// /**
//  * Parse "HH:MM:SS" or "HH:MM" into { h, m } object.
//  */
// function parseTime(timeStr) {
//   const [h, m] = (timeStr || "00:00").split(":").map(Number);
//   return { h, m };
// }

// /**
//  * Subtract `minutes` from an { h, m } time; returns new { h, m }.
//  */
// function subtractMinutes({ h, m }, minutes) {
//   const total = h * 60 + m - minutes;
//   return { h: Math.floor(total / 60), m: total % 60 };
// }

// /**
//  * Format { h, m } → "HH:MM" zero-padded.
//  */
// function fmt({ h, m }) {
//   return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
// }

// /**
//  * Return current local time as "HH:MM".
//  */
// function nowHHMM() {
//   const d = new Date();
//   return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
// }

// /**
//  * Today's date as "YYYY-MM-DD".
//  */
// function todayDate() {
//   return new Date().toISOString().split("T")[0];
// }

// // ─── Core Logic ───────────────────────────────────────────────────────────────

// /**
//  * calculateReminderTimes(officeInTime)
//  *
//  * Given shift start time (e.g. "09:00:00"), return:
//  *   { before30: "08:30", before10: "08:50" }
//  */
// function calculateReminderTimes(officeInTime) {
//   const parsed = parseTime(officeInTime);
//   const before30 = fmt(subtractMinutes(parsed, 30));
//   const before10 = fmt(subtractMinutes(parsed, 10));
//   return { before30, before10 };
// }

// /**
//  * Fetch all tenants that have an active attendance policy.
//  * Returns [{ tenant_id, office_in_time }]
//  */
// async function getActiveTenants() {
//   const rows = await query(`
//     SELECT DISTINCT ap.tenant_id, ap.office_in_time
//     FROM   attendance_policy ap
//     INNER JOIN tenants t ON t.tenant_id = ap.tenant_id
//     WHERE  t.status IN ('active','trial')
//   `);
//   return rows;
// }

// /**
//  * getEmployeesForReminder(tenantId)
//  *
//  * Returns employees who:
//  *   • Are Active in employee_master
//  *   • Have an Active login session
//  *   • device_active = 1
//  *   • notification_enabled = 1
//  *   • Have a non-null fcm_token
//  *
//  * Returns [{ emp_id, login_id, fcm_token }]
//  */
// async function getEmployeesForReminder(tenantId) {
//   const rows = await query(
//     `
//     SELECT
//       em.emp_id,
//       lm.login_id,
//       lm.fcm_token
//     FROM   employee_master em
//     INNER  JOIN login_master lm
//            ON  lm.emp_id    = em.emp_id
//            AND lm.tenant_id = em.tenant_id
//     WHERE  em.tenant_id          = ?
//       AND  em.status             = 'Active'
//       AND  lm.status             = 'Active'
//       AND  lm.device_logged_in   = 1
//       AND  lm.device_active      = 1
//       AND  lm.notification_enabled = 1
//       AND  lm.fcm_token         IS NOT NULL
//       AND  lm.force_logout       = 0
//     `,
//     [tenantId],
//   );
//   return rows;
// }

// /**
//  * validateAttendanceStatus(tenantId, empId)
//  *
//  * Returns true  → attendance NOT yet marked today (safe to notify)
//  * Returns false → attendance already marked (skip notification)
//  */
// async function validateAttendanceStatus(tenantId, empId) {
//   const rows = await query(
//     `
//     SELECT attendance_id
//     FROM   employee_attendance
//     WHERE  tenant_id   = ?
//       AND  employee_id = ?
//       AND  work_date   = ?
//     LIMIT  1
//     `,
//     [tenantId, empId, todayDate()],
//   );
//   return rows.length === 0; // true = safe to send
// }

// /**
//  * validateDuplicateNotification(tenantId, empId, reminderType)
//  *
//  * Returns true  → notification NOT yet sent today (safe to send)
//  * Returns false → already sent (skip)
//  */
// async function validateDuplicateNotification(tenantId, empId, reminderType) {
//   const rows = await query(
//     `
//     SELECT id
//     FROM   notification_logs
//     WHERE  tenant_id     = ?
//       AND  emp_id        = ?
//       AND  reminder_type = ?
//       AND  DATE(created_at) = ?
//       AND  sent_status   = 'SENT'
//     LIMIT  1
//     `,
//     [tenantId, empId, reminderType, todayDate()],
//   );
//   return rows.length === 0; // true = safe to send
// }

// /**
//  * saveNotificationLog(params) → insertId (BIGINT)
//  *
//  * Always called BEFORE the FCM push so history is preserved
//  * even if the push delivery fails.
//  */
// async function saveNotificationLog({
//   tenantId,
//   empId,
//   title,
//   body,
//   reminderType,
//   sentStatus = "SENT",
//   failureReason = null,
// }) {
//   const [result] = await db.query(
//     `
//     INSERT INTO notification_logs
//       (tenant_id, emp_id, title, body, reminder_type, channel, is_read, sent_status, failure_reason)
//     VALUES (?, ?, ?, ?, ?, 'PUSH', 0, ?, ?)
//     `,
//     [tenantId, empId, title, body, reminderType, sentStatus, failureReason],
//   );
//   return result.insertId;
// }

// /**
//  * updateNotificationLog(id, sentStatus, failureReason)
//  *
//  * After FCM attempt, update the log with final delivery status.
//  */
// async function updateNotificationLog(id, sentStatus, failureReason = null) {
//   await db.query(
//     `UPDATE notification_logs SET sent_status = ?, failure_reason = ? WHERE id = ?`,
//     [sentStatus, failureReason, id],
//   );
// }

// /**
//  * sendPushNotification({ fcmToken, title, body, data })
//  *
//  * Returns { success: true } or { success: false, error: string }
//  */
// async function sendPushNotification({ fcmToken, title, body, data = {} }) {
//   try {
//     const message = {
//       token: fcmToken,
//       notification: { title, body },
//       data: {
//         ...data,
//         click_action: "FLUTTER_NOTIFICATION_CLICK",
//       },
//       android: {
//         priority: "high",
//         notification: {
//           channelId: "attendance_reminders",
//           sound: "default",
//           priority: "high",
//         },
//       },
//       apns: {
//         payload: {
//           aps: {
//             sound: "default",
//             badge: 1,
//           },
//         },
//       },
//     };

//     await admin.messaging().send(message);
//     return { success: true };
//   } catch (err) {
//     console.error("[notify] FCM send error:", err.message);
//     return { success: false, error: err.message };
//   }
// }

// // ─── Reminder Processing ──────────────────────────────────────────────────────

// /**
//  * processReminderForTenant(tenantId, reminderType, officeInTime)
//  *
//  * Orchestrates the full flow for one tenant + one reminder slot.
//  */
// async function processReminderForTenant(tenantId, reminderType, officeInTime) {
//   const minutes = reminderType === "before_30_min" ? 30 : 10;
//   const title = "Attendance Reminder";
//   const body = `Your shift starts in ${minutes} minutes. Please mark your attendance.`;

//   const employees = await getEmployeesForReminder(tenantId);

//   if (!employees.length) return;

//   for (const { emp_id, fcm_token } of employees) {
//     try {
//       // 1. Check attendance not already marked
//       const attendanceOk = await validateAttendanceStatus(tenantId, emp_id);
//       if (!attendanceOk) {
//         console.log(
//           `[notify] Skipping emp ${emp_id} — attendance already marked.`,
//         );
//         continue;
//       }

//       // 2. Check not a duplicate notification
//       const dupOk = await validateDuplicateNotification(
//         tenantId,
//         emp_id,
//         reminderType,
//       );
//       if (!dupOk) {
//         console.log(
//           `[notify] Skipping emp ${emp_id} — ${reminderType} already sent today.`,
//         );
//         continue;
//       }

//       // 3. Save log record BEFORE sending push
//       const logId = await saveNotificationLog({
//         tenantId,
//         empId: emp_id,
//         title,
//         body,
//         reminderType,
//         sentStatus: "SENT",
//       });

//       // 4. Send FCM push
//       const result = await sendPushNotification({
//         fcmToken: fcm_token,
//         title,
//         body,
//         data: {
//           type: "attendance_reminder",
//           reminder_type: reminderType,
//           log_id: String(logId),
//           shift_time: officeInTime,
//         },
//       });

//       // 5. Update log with actual delivery result
//       if (!result.success) {
//         await updateNotificationLog(logId, "FAILED", result.error);
//         console.warn(`[notify] FCM FAILED for emp ${emp_id}: ${result.error}`);
//       } else {
//         console.log(
//           `[notify] ✓ Sent ${reminderType} to emp ${emp_id} (log #${logId})`,
//         );
//       }
//     } catch (err) {
//       console.error(`[notify] Error processing emp ${emp_id}:`, err.message);
//     }
//   }
// }

// // ─── Cron Job ─────────────────────────────────────────────────────────────────

// /**
//  * Runs every minute.
//  * For each active tenant, checks if the current HH:MM matches either
//  * reminder slot and triggers notifications accordingly.
//  */
// async function runNotificationCron() {
//   const currentTime = nowHHMM(); // e.g. "08:30"
//   console.log(`[notify] Cron tick — ${currentTime}`);

//   let tenants;
//   try {
//     tenants = await getActiveTenants();
//   } catch (err) {
//     console.error("[notify] Failed to fetch tenants:", err.message);
//     return;
//   }

//   for (const { tenant_id, office_in_time } of tenants) {
//     try {
//       const { before30, before10 } = calculateReminderTimes(office_in_time);

//       if (currentTime === before30) {
//         console.log(
//           `[notify] Tenant ${tenant_id}: firing before_30_min reminder`,
//         );
//         await processReminderForTenant(
//           tenant_id,
//           "before_30_min",
//           office_in_time,
//         );
//       }

//       if (currentTime === before10) {
//         console.log(
//           `[notify] Tenant ${tenant_id}: firing before_10_min reminder`,
//         );
//         await processReminderForTenant(
//           tenant_id,
//           "before_10_min",
//           office_in_time,
//         );
//       }
//     } catch (err) {
//       console.error(`[notify] Error for tenant ${tenant_id}:`, err.message);
//     }
//   }
// }

// // ─── Public API ───────────────────────────────────────────────────────────────

// /**
//  * initializeNotificationService()
//  *
//  * Call this once from server.js at startup.
//  */
// function initializeNotificationService() {
//   initFirebase();

//   // Run every 1 minute — "* * * * *"
//   cron.schedule("* * * * *", runNotificationCron, {
//     timezone: process.env.TZ || "Asia/Kolkata",
//   });

//   console.log("[notify] Attendance reminder cron started (every 1 min).");
// }

// module.exports = {
//   initializeNotificationService,
//   calculateReminderTimes,
//   getEmployeesForReminder,
//   validateAttendanceStatus,
//   validateDuplicateNotification,
//   sendPushNotification,
//   saveNotificationLog,
// };
/**
 * notify.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Centralized Attendance Reminder Notification Service
 *
 * Responsibilities
 *  • initializeNotificationService()  — boot FCM + start cron
 *  • calculateReminderTimes()         — derive 30-min & 10-min slots from policy
 *  • getEmployeesForReminder()        — fetch eligible employees per tenant
 *  • validateAttendanceStatus()       — ensure attendance not already marked
 *  • validateDuplicateNotification()  — prevent double-send per reminder type
 *  • sendPushNotification()           — FCM via Firebase Admin SDK
 *  • saveNotificationLog()            — persist to notification_logs BEFORE send
 *
 * Cron: runs every 1 minute
 * ─────────────────────────────────────────────────────────────────────────────
 */

"use strict";

const cron   = require("node-cron");
const admin  = require("firebase-admin");
const path   = require("path");
const db     = require("./config/db");   // mysql2 pool (promise-compatible)

// ─── Firebase Admin Init ──────────────────────────────────────────────────────

let firebaseInitialized = false;

function initFirebase() {
  if (firebaseInitialized) return;

  // Loads backend/firebase-service-account.json
  // notify.js is at backend/notifications/notify.js → go up one level
  const serviceAccount = require(
    path.join(__dirname, ".", "firebase-service-account.json")
  );

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  firebaseInitialized = true;
  console.log("[notify] Firebase Admin initialized.");
}

// ─── DB Helper ────────────────────────────────────────────────────────────────

/**
 * Thin promise wrapper — supports both mysql2 pool (.promise()) and
 * the callback-style pool used elsewhere in this project.
 */
async function query(sql, params = []) {
  // mysql2 pool with .promise()
  if (typeof db.query === "function") {
    const result = await db.query(sql, params);
    // mysql2 returns [rows, fields]
    return Array.isArray(result[0]) ? result[0] : result;
  }
  throw new Error("[notify] Unsupported DB driver.");
}

// ─── Time Helpers ─────────────────────────────────────────────────────────────

/**
 * Parse "HH:MM:SS" or "HH:MM" into { h, m } object.
 */
function parseTime(timeStr) {
  const [h, m] = (timeStr || "00:00").split(":").map(Number);
  return { h, m };
}

/**
 * Subtract `minutes` from an { h, m } time; returns new { h, m }.
 */
function subtractMinutes({ h, m }, minutes) {
  const total = h * 60 + m - minutes;
  return { h: Math.floor(total / 60), m: total % 60 };
}

/**
 * Format { h, m } → "HH:MM" zero-padded.
 */
function fmt({ h, m }) {
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

/**
 * Return current local time as "HH:MM".
 */
function nowHHMM() {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

/**
 * Today's date as "YYYY-MM-DD".
 */
function todayDate() {
  return new Date().toISOString().split("T")[0];
}

// ─── Core Logic ───────────────────────────────────────────────────────────────

/**
 * calculateReminderTimes(officeInTime)
 *
 * Given shift start time (e.g. "09:00:00"), return:
 *   { before30: "08:30", before10: "08:50" }
 */
function calculateReminderTimes(officeInTime) {
  const parsed   = parseTime(officeInTime);
  const before30 = fmt(subtractMinutes(parsed, 30));
  const before10 = fmt(subtractMinutes(parsed, 10));
  return { before30, before10 };
}

/**
 * Fetch all tenants that have an active attendance policy.
 * Returns [{ tenant_id, office_in_time }]
 */
async function getActiveTenants() {
  const rows = await query(`
    SELECT DISTINCT ap.tenant_id, ap.office_in_time
    FROM   attendance_policy ap
    INNER JOIN tenants t
      ON t.tenant_id COLLATE utf8mb4_unicode_ci = ap.tenant_id COLLATE utf8mb4_unicode_ci
    WHERE  t.status IN ('active','trial')
  `);
  return rows;
}

/**
 * getEmployeesForReminder(tenantId)
 *
 * Returns employees who:
 *   • Are Active in employee_master
 *   • Have an Active login session
 *   • device_active = 1
 *   • notification_enabled = 1
 *   • Have a non-null fcm_token
 *
 * Returns [{ emp_id, login_id, fcm_token }]
 */
async function getEmployeesForReminder(tenantId) {
  const rows = await query(
    `
    SELECT
      em.emp_id,
      lm.login_id,
      lm.fcm_token
    FROM   employee_master em
    INNER  JOIN login_master lm
           ON  lm.emp_id    = em.emp_id
           AND lm.tenant_id COLLATE utf8mb4_unicode_ci = em.tenant_id COLLATE utf8mb4_unicode_ci
    WHERE  em.tenant_id          = ?
      AND  em.status             = 'Active'
      AND  lm.status             = 'Active'
      AND  lm.device_logged_in   = 1
      AND  lm.device_active      = 1
      AND  lm.notification_enabled = 1
      AND  lm.fcm_token         IS NOT NULL
      AND  lm.force_logout       = 0
    `,
    [tenantId]
  );
  return rows;
}

/**
 * validateAttendanceStatus(tenantId, empId)
 *
 * Returns true  → attendance NOT yet marked today (safe to notify)
 * Returns false → attendance already marked (skip notification)
 */
async function validateAttendanceStatus(tenantId, empId) {
  const rows = await query(
    `
    SELECT attendance_id
    FROM   employee_attendance
    WHERE  tenant_id   = ?
      AND  employee_id = ?
      AND  work_date   = ?
    LIMIT  1
    `,
    [tenantId, empId, todayDate()]
  );
  return rows.length === 0; // true = safe to send
}

/**
 * validateDuplicateNotification(tenantId, empId, reminderType)
 *
 * Returns true  → notification NOT yet sent today (safe to send)
 * Returns false → already sent (skip)
 */
async function validateDuplicateNotification(tenantId, empId, reminderType) {
  const rows = await query(
    `
    SELECT id
    FROM   notification_logs
    WHERE  tenant_id     = ?
      AND  emp_id        = ?
      AND  reminder_type = ?
      AND  DATE(created_at) = ?
      AND  sent_status   = 'SENT'
    LIMIT  1
    `,
    [tenantId, empId, reminderType, todayDate()]
  );
  return rows.length === 0; // true = safe to send
}

/**
 * saveNotificationLog(params) → insertId (BIGINT)
 *
 * Always called BEFORE the FCM push so history is preserved
 * even if the push delivery fails.
 */
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
    `
    INSERT INTO notification_logs
      (tenant_id, emp_id, title, body, reminder_type, channel, is_read, sent_status, failure_reason)
    VALUES (?, ?, ?, ?, ?, 'PUSH', 0, ?, ?)
    `,
    [tenantId, empId, title, body, reminderType, sentStatus, failureReason]
  );
  return result.insertId;
}

/**
 * updateNotificationLog(id, sentStatus, failureReason)
 *
 * After FCM attempt, update the log with final delivery status.
 */
async function updateNotificationLog(id, sentStatus, failureReason = null) {
  await db.query(
    `UPDATE notification_logs SET sent_status = ?, failure_reason = ? WHERE id = ?`,
    [sentStatus, failureReason, id]
  );
}

/**
 * sendPushNotification({ fcmToken, title, body, data })
 *
 * Returns { success: true } or { success: false, error: string }
 */
async function sendPushNotification({ fcmToken, title, body, data = {} }) {
  try {
    const message = {
      token: fcmToken,
      notification: { title, body },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "attendance_reminders",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    return { success: true };
  } catch (err) {
    console.error("[notify] FCM send error:", err.message);
    return { success: false, error: err.message };
  }
}

// ─── Reminder Processing ──────────────────────────────────────────────────────

/**
 * processReminderForTenant(tenantId, reminderType, officeInTime)
 *
 * Orchestrates the full flow for one tenant + one reminder slot.
 */
async function processReminderForTenant(tenantId, reminderType, officeInTime) {
  const minutes    = reminderType === "before_30_min" ? 30 : 10;
  const title      = "Attendance Reminder";
  const body       = `Your shift starts in ${minutes} minutes. Please mark your attendance.`;

  const employees = await getEmployeesForReminder(tenantId);

  if (!employees.length) return;

  for (const { emp_id, fcm_token } of employees) {
    try {
      // 1. Check attendance not already marked
      const attendanceOk = await validateAttendanceStatus(tenantId, emp_id);
      if (!attendanceOk) {
        console.log(`[notify] Skipping emp ${emp_id} — attendance already marked.`);
        continue;
      }

      // 2. Check not a duplicate notification
      const dupOk = await validateDuplicateNotification(tenantId, emp_id, reminderType);
      if (!dupOk) {
        console.log(`[notify] Skipping emp ${emp_id} — ${reminderType} already sent today.`);
        continue;
      }

      // 3. Save log record BEFORE sending push
      const logId = await saveNotificationLog({
        tenantId,
        empId: emp_id,
        title,
        body,
        reminderType,
        sentStatus: "SENT",
      });

      // 4. Send FCM push
      const result = await sendPushNotification({
        fcmToken: fcm_token,
        title,
        body,
        data: {
          type:          "attendance_reminder",
          reminder_type: reminderType,
          log_id:        String(logId),
          shift_time:    officeInTime,
        },
      });

      // 5. Update log with actual delivery result
      if (!result.success) {
        await updateNotificationLog(logId, "FAILED", result.error);
        console.warn(`[notify] FCM FAILED for emp ${emp_id}: ${result.error}`);
      } else {
        console.log(`[notify] ✓ Sent ${reminderType} to emp ${emp_id} (log #${logId})`);
      }
    } catch (err) {
      console.error(`[notify] Error processing emp ${emp_id}:`, err.message);
    }
  }
}

// ─── Cron Job ─────────────────────────────────────────────────────────────────

/**
 * Runs every minute.
 * For each active tenant, checks if the current HH:MM matches either
 * reminder slot and triggers notifications accordingly.
 */
async function runNotificationCron() {
  const currentTime = nowHHMM(); // e.g. "08:30"
  console.log(`[notify] Cron tick — ${currentTime}`);

  let tenants;
  try {
    tenants = await getActiveTenants();
  } catch (err) {
    console.error("[notify] Failed to fetch tenants:", err.message);
    return;
  }

  for (const { tenant_id, office_in_time } of tenants) {
    try {
      const { before30, before10 } = calculateReminderTimes(office_in_time);

      if (currentTime === before30) {
        console.log(`[notify] Tenant ${tenant_id}: firing before_30_min reminder`);
        await processReminderForTenant(tenant_id, "before_30_min", office_in_time);
      }

      if (currentTime === before10) {
        console.log(`[notify] Tenant ${tenant_id}: firing before_10_min reminder`);
        await processReminderForTenant(tenant_id, "before_10_min", office_in_time);
      }
    } catch (err) {
      console.error(`[notify] Error for tenant ${tenant_id}:`, err.message);
    }
  }
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * initializeNotificationService()
 *
 * Call this once from server.js at startup.
 */
function initializeNotificationService() {
  initFirebase();

  // Run every 1 minute — "* * * * *"
  cron.schedule("* * * * *", runNotificationCron, {
    timezone: process.env.TZ || "Asia/Kolkata",
  });

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