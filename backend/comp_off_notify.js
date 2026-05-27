"use strict";

const admin = require("firebase-admin");
const db = require("./config/db");
const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT || "587"),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  tls: { rejectUnauthorized: false },
});

function formatDate(dateStr) {
  if (!dateStr) return "N/A";
  return new Date(dateStr).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

async function getEmployeeDetails(tenantId, employeeId) {
  const [rows] = await db.query(
    `SELECT
      em.emp_id,
      CONCAT_WS(' ',
        NULLIF(em.first_name, ''),
        NULLIF(em.mid_name, ''),
        NULLIF(em.last_name, '')
      ) AS emp_name,
      em.email_id,
      lm.fcm_token,
      lm.device_active,
      lm.notification_enabled
    FROM employee_master em
    LEFT JOIN login_master lm
      ON lm.emp_id    = CAST(em.emp_id AS CHAR)
     AND lm.tenant_id = em.tenant_id
     AND lm.status    = 'Active'
    WHERE em.emp_id    = ?
      AND em.tenant_id = ?
    LIMIT 1`,
    [employeeId, tenantId],
  );
  return rows[0] || null;
}

async function saveLog({ tenantId, empId, title, body, channel, sentStatus, failureReason = null }) {
  await db.query(
    `INSERT IGNORE INTO notification_logs
      (tenant_id, emp_id, title, body, reminder_type, channel, is_read, sent_status, failure_reason)
    VALUES (?, ?, ?, ?, 'comp_off', ?, 0, ?, ?)`,
    [tenantId, empId, title, body, channel, sentStatus, failureReason],
  );
}

async function notifyCompOffCredited({ tenantId, employeeId, compOff }) {
  const emp = await getEmployeeDetails(tenantId, employeeId);
  if (!emp) {
    console.warn(`[comp_off_notify] Employee ${employeeId} not found.`);
    return;
  }

  const title = "Compensatory Off Credited";
  const body = `A comp-off has been credited for ${formatDate(compOff.earned_date)}. Expires: ${formatDate(compOff.expiry_date)}.`;

  // FCM Push
  if (emp.fcm_token && emp.device_active && emp.notification_enabled) {
    try {
      await admin.messaging().send({
        token: emp.fcm_token,
        notification: { title, body },
        data: {
          type: "comp_off",
          comp_off_id: String(compOff.id),
          earned_date: compOff.earned_date || "",
          expiry_date: compOff.expiry_date || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: { channelId: "attendance_reminders", sound: "default", priority: "high" },
        },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      });
      await saveLog({ tenantId, empId: employeeId, title, body, channel: "PUSH", sentStatus: "SENT" });
      console.log(`[comp_off_notify] ✓ Push sent to emp ${employeeId}`);
    } catch (err) {
      await saveLog({ tenantId, empId: employeeId, title, body, channel: "PUSH", sentStatus: "FAILED", failureReason: err.message });
      console.error(`[comp_off_notify] ✗ Push failed: ${err.message}`);
    }
  }

  // Email
  if (emp.email_id) {
    const html = `
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;
                  border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;">
        <div style="background:#3B6FE8;padding:24px 32px;">
          <h2 style="color:#fff;margin:0;font-size:20px;">Compensatory Off Credited</h2>
        </div>
        <div style="padding:28px 32px;background:#fff;">
          <p style="margin:0 0 16px;color:#1A1D2E;font-size:15px;">Hi <strong>${emp.emp_name}</strong>,</p>
          <p style="margin:0 0 20px;color:#4B5563;font-size:14px;">A compensatory off has been credited to your account.</p>
          <table style="width:100%;border-collapse:collapse;border:1px solid #E5E7EB;border-radius:8px;overflow:hidden;">
            <tr style="background:#F9FAFB;">
              <td style="padding:12px 16px;color:#6B7280;font-size:13px;font-weight:600;width:40%;">Earned Date</td>
              <td style="padding:12px 16px;color:#1A1D2E;font-size:13px;">${formatDate(compOff.earned_date)}</td>
            </tr>
            <tr>
              <td style="padding:12px 16px;color:#6B7280;font-size:13px;font-weight:600;border-top:1px solid #E5E7EB;">Expiry Date</td>
              <td style="padding:12px 16px;color:#1A1D2E;font-size:13px;border-top:1px solid #E5E7EB;">${formatDate(compOff.expiry_date)}</td>
            </tr>
            <tr style="background:#F9FAFB;">
              <td style="padding:12px 16px;color:#6B7280;font-size:13px;font-weight:600;border-top:1px solid #E5E7EB;">Status</td>
              <td style="padding:12px 16px;border-top:1px solid #E5E7EB;">
                <span style="background:#D1FAE5;color:#065F46;padding:3px 10px;border-radius:20px;font-size:12px;font-weight:600;">EARNED</span>
              </td>
            </tr>
            ${compOff.remarks ? `
            <tr>
              <td style="padding:12px 16px;color:#6B7280;font-size:13px;font-weight:600;border-top:1px solid #E5E7EB;">Remarks</td>
              <td style="padding:12px 16px;color:#1A1D2E;font-size:13px;border-top:1px solid #E5E7EB;">${compOff.remarks}</td>
            </tr>` : ""}
          </table>
          <p style="margin:24px 0 0;color:#6B7280;font-size:13px;">Please apply for comp-off leave before the expiry date.</p>
        </div>
        <div style="padding:16px 32px;background:#F9FAFB;border-top:1px solid #E5E7EB;text-align:center;">
          <p style="margin:0;color:#9CA3AF;font-size:12px;">This is an automated notification. Please do not reply.</p>
        </div>
      </div>`;

    try {
      await transporter.sendMail({
        from: `"Attendance System" <${process.env.SMTP_USER}>`,
        to: emp.email_id,
        subject: "🎉 Compensatory Off Credited to Your Account",
        html,
      });
      await saveLog({ tenantId, empId: employeeId, title, body, channel: "EMAIL", sentStatus: "SENT" });
      console.log(`[comp_off_notify] ✓ Email sent to ${emp.email_id}`);
    } catch (err) {
      await saveLog({ tenantId, empId: employeeId, title, body, channel: "EMAIL", sentStatus: "FAILED", failureReason: err.message });
      console.error(`[comp_off_notify] ✗ Email failed: ${err.message}`);
    }
  }
}

module.exports = { notifyCompOffCredited };