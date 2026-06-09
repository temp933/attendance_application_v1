// server.js
require("dotenv").config();

const express = require("express");
const bcrypt = require("bcryptjs");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const app = express();
const authMiddleware = require("./middleware/auth");

app.use(cors());
app.use(express.json());
app.set("trust proxy", 1);

// ── DB ───────────────────────────────────────────────────────────────────────
const db = require("./config/db");

// ─────────────────────────────────────────────
// DB Helpers
// ─────────────────────────────────────────────

const dbQuery = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.query(sql, params, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
};

const dbOne = async (sql, params = []) => {
  const rows = await dbQuery(sql, params);
  return rows[0] || null;
};

const dbAll = async (sql, params = []) => {
  return await dbQuery(sql, params);
};

// ── Nodemailer transporter ───────────────────────────────────────────────────
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  tls: {
    rejectUnauthorized: false,
  },
});

// ── OTP Store ────────────────────────────────────────────────────────────────
const otpStore = new Map();

// ── Helpers ──────────────────────────────────────────────────────────────────
function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

function generateSessionId() {
  return crypto.randomBytes(16).toString("hex");
}

async function sendOtpEmail(to, otp, orgName) {
  await transporter.sendMail({
    from: `"No Reply | ${process.env.APP_NAME || "EMS"}" <no-reply@${process.env.SMTP_USER.split("@")[1]}>`,
    to,
    subject: `Your OTP for ${orgName} Registration`,
    html: `
        <div style="font-family:sans-serif;padding:20px;">
          <h2>Your OTP</h2>
          <h1>${otp}</h1>
          <p>This OTP expires in 10 minutes.</p>
        </div>
      `,
  });
}

// ── Rate Limiters ────────────────────────────────────────────────────────────
const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: "Too many requests. Please try again after 15 minutes." },
});

const completeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: "Too many registration attempts. Please try again later.",
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// SEND OTP
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/send-otp", otpLimiter, async (req, res) => {
  try {
    let { org_name, admin_email, hr_email, attendance_mode } = req.body;

    // attendance_mode must be 1, 2, 3 or 4
    const parsedMode = parseInt(attendance_mode, 10);
    if (![1, 2, 3, 4].includes(parsedMode)) {
      return res.status(400).json({
        message: "attendance_mode is required and must be 1, 2, 3 or 4.",
      });
    }

    admin_email = admin_email?.toLowerCase().trim();
    hr_email = hr_email?.toLowerCase().trim();

    if (!org_name || !admin_email || !hr_email) {
      return res.status(400).json({
        message: "org_name, admin_email and hr_email are required.",
      });
    }

    /// ── Same-email guard ─────────────────────────────────────────────────────
    if (admin_email === hr_email) {
      return res.status(400).json({
        message: "Admin and HR email addresses must be different.",
      });
    }

    // ── Check duplicate org ──────────────────────────────────────────────────
    const [existingRows] = await db.query(
      `SELECT tenant_id FROM tenants
       WHERE admin_email IN (?, ?) OR hr_email IN (?, ?)
       LIMIT 1`,
      [admin_email, hr_email, admin_email, hr_email],
    );

    if (existingRows.length > 0) {
      return res.status(409).json({
        message:
          "One or both email addresses are already registered with another organisation.",
      });
    }
    const sessionId = generateSessionId();
    const adminOtp = generateOtp();
    const hrOtp = generateOtp();
    const expiresAt = Date.now() + 10 * 60 * 1000;

    otpStore.set(`${sessionId}:admin`, {
      otp: adminOtp,
      email: admin_email,
      expiresAt,
      attendance_mode: parsedMode,
    });
    otpStore.set(`${sessionId}:hr`, {
      otp: hrOtp,
      email: hr_email,
      expiresAt,
      attendance_mode: parsedMode,
    });

    await Promise.all([
      sendOtpEmail(admin_email, adminOtp, org_name),
      sendOtpEmail(hr_email, hrOtp, org_name),
    ]);

    res.json({
      message: "OTP sent successfully.",
      session_id: sessionId,
      attendance_mode: parsedMode,
    });
  } catch (err) {
    console.error("[send-otp] Error:", err);
    res.status(500).json({ message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// VERIFY OTP
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/verify-otp", otpLimiter, (req, res) => {
  const { session_id, admin_otp, hr_otp } = req.body;

  if (!session_id || !admin_otp || !hr_otp) {
    return res.status(400).json({ message: "Missing required fields." });
  }

  const adminEntry = otpStore.get(`${session_id}:admin`);
  const hrEntry = otpStore.get(`${session_id}:hr`);

  if (!adminEntry || !hrEntry) {
    return res.status(400).json({ message: "Session expired or invalid." });
  }

  if (Date.now() > adminEntry.expiresAt || Date.now() > hrEntry.expiresAt) {
    otpStore.delete(`${session_id}:admin`);
    otpStore.delete(`${session_id}:hr`);
    return res.status(400).json({ message: "OTP expired. Please resend." });
  }

  if (adminEntry.otp !== admin_otp || hrEntry.otp !== hr_otp) {
    return res.status(400).json({ message: "Invalid OTP." });
  }

  adminEntry.verified = true;
  hrEntry.verified = true;

  res.json({ message: "OTP verified successfully." });
});

// ── Tenant ID Generator ───────────────────────────────────────────────────────
function generateTenantId() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < 5; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETE REGISTRATION
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/complete", completeLimiter, async (req, res) => {
  const {
    session_id,
    org_name,
    contact_person,
    contact_number,
    admin_email,
    hr_email,
    expected_employees,
    company_address,
    domain_name,
    gst_number,
    plan_id,
    admin_login,
    hr_login,
    admin_profile,
    hr_profile,
  } = req.body;

  // ── Basic field validation ────────────────────────────────────────────────
  const adminUsername = admin_login?.username?.trim();
  const adminPassword = admin_login?.password;
  const hrUsername = hr_login?.username?.trim();
  const hrPassword = hr_login?.password;

  if (!adminUsername || !adminPassword) {
    return res.status(400).json({ message: "Admin login details missing." });
  }
  if (!hrUsername || !hrPassword) {
    return res.status(400).json({ message: "HR login details missing." });
  }

  const normalizedAdminEmail = admin_email?.toLowerCase().trim();
  const normalizedHrEmail = hr_email?.toLowerCase().trim();

  if (!normalizedAdminEmail || !normalizedHrEmail) {
    return res.status(400).json({ message: "Email fields are required." });
  }

  // ── Validate OTP session ──────────────────────────────────────────────────
  const adminEntry = otpStore.get(`${session_id}:admin`);
  const hrEntry = otpStore.get(`${session_id}:hr`);

  if (!adminEntry?.verified || !hrEntry?.verified) {
    return res.status(400).json({ message: "OTP verification required." });
  }
  if (adminEntry.email !== normalizedAdminEmail) {
    return res.status(400).json({ message: "Admin email mismatch." });
  }
  if (hrEntry.email !== normalizedHrEmail) {
    return res.status(400).json({ message: "HR email mismatch." });
  }

  const attendanceMode = adminEntry.attendance_mode;
  if (![1, 2, 3, 4].includes(attendanceMode)) {
    return res
      .status(400)
      .json({ message: "Invalid attendance mode in session." });
  }
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // ── 1. Duplicate org check ────────────────────────────────────────────
    const [[existingOrg]] = await conn.query(
      `SELECT tenant_id FROM tenants
       WHERE admin_email = ? OR hr_email = ? LIMIT 1`,
      [normalizedAdminEmail, normalizedHrEmail],
    );
    if (existingOrg) {
      await conn.rollback();
      return res.status(409).json({ message: "Organisation already exists." });
    }

    // ── 2. Duplicate username check ───────────────────────────────────────
    const [[existingAdminUsername]] = await conn.query(
      `SELECT login_id FROM login_master WHERE username = ? LIMIT 1`,
      [adminUsername],
    );
    if (existingAdminUsername) {
      await conn.rollback();
      return res.status(409).json({
        message: "Admin username already taken. Please choose another.",
      });
    }

    const [[existingHrUsername]] = await conn.query(
      `SELECT login_id FROM login_master WHERE username = ? LIMIT 1`,
      [hrUsername],
    );
    if (existingHrUsername) {
      await conn.rollback();
      return res
        .status(409)
        .json({ message: "HR username already taken. Please choose another." });
    }

     

    // ── 4. Date calculations ──────────────────────────────────────────────
    const today = new Date();
    const trialEndsAt = new Date(today);
    trialEndsAt.setDate(trialEndsAt.getDate() + 30);

    const toMysqlDate = (d) => d.toISOString().split("T")[0];

    // ── 5. Generate unique tenant ID (with attempt limit) ─────────────────
    let tenantId;
    let attempts = 0;
    let tenantExists = true;

    while (tenantExists && attempts < 10) {
      tenantId = generateTenantId();
      const [rows] = await conn.query(
        "SELECT tenant_id FROM tenants WHERE tenant_id = ? LIMIT 1",
        [tenantId],
      );
      tenantExists = rows.length > 0;
      attempts++;
    }

    if (attempts >= 10) {
      throw new Error(
        "Failed to generate a unique tenant ID after 10 attempts.",
      );
    }

    // ── 6. Insert 3 default roles for this tenant ─────────────────────────
    const [adminRoleResult] = await conn.query(
      `INSERT INTO role_master (tenant_id, role_name, status, is_deleted, created_at)
       VALUES (?, 'Admin', 'Active', 0, NOW())`,
      [tenantId],
    );
    const adminRoleId = adminRoleResult.insertId;

    const [hrRoleResult] = await conn.query(
      `INSERT INTO role_master (tenant_id, role_name, status, is_deleted, created_at)
       VALUES (?, 'HR', 'Active', 0, NOW())`,
      [tenantId],
    );
    const hrRoleId = hrRoleResult.insertId;

    // Employee role — exists for future employee creation, not used in this flow
    await conn.query(
      `INSERT INTO role_master (tenant_id, role_name, status, is_deleted, created_at)
       VALUES (?, 'Employee', 'Active', 0, NOW())`,
      [tenantId],
    );

    // ── 7. Insert tenant ──────────────────────────────────────────────────
    await conn.query(
      `INSERT INTO tenants
        (tenant_id, company_name, contact_person, contact_number,
         admin_email, hr_email, max_users, company_address,
         domain_name, gst_number, status,
         trial_ends_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'trial', ?, NOW())`,
      [
        tenantId,
        org_name,
        contact_person,
        contact_number,
        normalizedAdminEmail,
        normalizedHrEmail,
        expected_employees || 50,
        company_address,
        domain_name,
        gst_number || null,
        toMysqlDate(trialEndsAt),
      ],
    );

    // ── 8. Fetch company_code (auto-generated by DB trigger) ──────────────
    const [[tenant]] = await conn.query(
      `SELECT company_code FROM tenants WHERE tenant_id = ?`,
      [tenantId],
    );
    const companyCode = tenant.company_code;

    // ── 8.5. Create default Department & Designation ──────────────────────
    const [deptResult] = await conn.query(
      `INSERT INTO department_master 
        (tenant_id, department_name, status, is_deleted, created_at)
       VALUES (?, 'General', 'Active', 0, NOW())`,
      [tenantId],
    );
    const defaultDeptId = deptResult.insertId;

    const [desigResult] = await conn.query(
      `INSERT INTO designation_master 
        (tenant_id, department_id, designation_name, status, is_deleted, created_at)
       VALUES (?, ?, 'General', 'Active', 0, NOW())`,
      [tenantId, defaultDeptId],
    );
    const defaultDesigId = desigResult.insertId;

    // ── 8.6. Generate employee codes ──────────────────────────────────────
    const adminEmpCode = `EMP0001`;
    const hrEmpCode = `EMP0002`;

    // ── 9. Insert Admin employee ──────────────────────────────────────────
    const [adminEmpResult] = await conn.query(
      `INSERT INTO employee_master
      (tenant_id, employee_code, first_name, mid_name, last_name,
       email_id, phone_number, date_of_birth, gender,
       designation_id, role_id, date_of_joining,
       employment_type, work_type,
       permanent_address, communication_address,
       father_name, emergency_contact, emergency_contact_relation,
       aadhar_number, pan_number, pf_number, esic_number,
       years_experience, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
      [
        tenantId,
        adminEmpCode,
        admin_profile?.first_name?.trim() ||
          contact_person?.split(" ")[0] ||
          "Admin",
        admin_profile?.mid_name?.trim() || null,
        admin_profile?.last_name?.trim() ||
          contact_person?.split(" ").slice(1).join(" ") ||
          "User",
        normalizedAdminEmail,
        admin_profile?.phone_number?.trim() || contact_number || null,
        admin_profile?.date_of_birth || null,
        admin_profile?.gender || null,
        defaultDesigId,
        adminRoleId,
        admin_profile?.date_of_joining || toMysqlDate(today),
        admin_profile?.employment_type || "Permanent",
        admin_profile?.work_type || "Full Time",
        admin_profile?.permanent_address?.trim() || company_address || null,
        admin_profile?.communication_address?.trim() || null,
        admin_profile?.father_name?.trim() || null,
        admin_profile?.emergency_contact?.trim() || null,
        admin_profile?.emergency_contact_relation?.trim() || null,
        admin_profile?.aadhar_number?.trim() || null,
        admin_profile?.pan_number?.trim()?.toUpperCase() || null,
        admin_profile?.pf_number?.trim() || null,
        admin_profile?.esic_number?.trim() || null,
        admin_profile?.years_experience !== undefined
          ? parseInt(admin_profile.years_experience, 10)
          : null,
      ],
    );
    const adminEmpId = adminEmpResult.insertId;

    // ── 10. Insert HR employee ────────────────────────────────────────────
    const [hrEmpResult] = await conn.query(
      `INSERT INTO employee_master
      (tenant_id, employee_code, first_name, mid_name, last_name,
       email_id, phone_number, date_of_birth, gender,
       designation_id, role_id, date_of_joining,
       employment_type, work_type,
       permanent_address, communication_address,
       father_name, emergency_contact, emergency_contact_relation,
       aadhar_number, pan_number, pf_number, esic_number,
       years_experience, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
      [
        tenantId,
        hrEmpCode,
        hr_profile?.first_name?.trim() || "HR",
        hr_profile?.mid_name?.trim() || null,
        hr_profile?.last_name?.trim() || "Manager",
        normalizedHrEmail,
        hr_profile?.phone_number?.trim() || null,
        hr_profile?.date_of_birth || null,
        hr_profile?.gender || null,
        defaultDesigId,
        hrRoleId,
        hr_profile?.date_of_joining || toMysqlDate(today),
        hr_profile?.employment_type || "Permanent",
        hr_profile?.work_type || "Full Time",
        hr_profile?.permanent_address?.trim() || company_address || null,
        hr_profile?.communication_address?.trim() || null,
        hr_profile?.father_name?.trim() || null,
        hr_profile?.emergency_contact?.trim() || null,
        hr_profile?.emergency_contact_relation?.trim() || null,
        hr_profile?.aadhar_number?.trim() || null,
        hr_profile?.pan_number?.trim()?.toUpperCase() || null,
        hr_profile?.pf_number?.trim() || null,
        hr_profile?.esic_number?.trim() || null,
        hr_profile?.years_experience !== undefined
          ? parseInt(hr_profile.years_experience, 10)
          : null,
      ],
    );
    const hrEmpId = hrEmpResult.insertId;
    // ── 11. Hash passwords ────────────────────────────────────────────────
    const [adminPasswordHash, hrPasswordHash] = await Promise.all([
      bcrypt.hash(adminPassword, 12),
      bcrypt.hash(hrPassword, 12),
    ]);

    // ── 12. Insert Admin login ────────────────────────────────────────────
    await conn.query(
      `INSERT INTO login_master
          (tenant_id, emp_id, username, contact_number,
           password, role_id, is_first_login, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
      [
        tenantId,
        adminEmpId,
        adminUsername,
        admin_profile?.phone_number?.trim() || contact_number || null,
        adminPasswordHash,
        adminRoleId,
      ],
    );

    // ── 13. Insert HR login ───────────────────────────────────────────────
    await conn.query(
      `INSERT INTO login_master
          (tenant_id, emp_id, username, contact_number,
           password, role_id, is_first_login, status, created_at)
        VALUES (?,   ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
      [
        tenantId,
        hrEmpId,
        hrUsername,
        hr_profile?.phone_number?.trim() || null,
        hrPasswordHash,
        hrRoleId,
      ],
    );

    // ── 14. Save attendance mode ──────────────────────────────────────────
    await conn.query(
      `INSERT INTO tenant_attendance_mode (tenant_id, mode) VALUES (?, ?)`,
      [tenantId, attendanceMode],
    );

    // ── 15. Seed role_permissions for Admin + HR ──────────────────────────
    //   Define module sets per attendance mode
    const DEFAULT_MODULES = [
      "emp_dashboard",
      "session_management",
      "policy_management",
      "emp_leave",
      "leave_approval",
      "leave_management",
      "comp_off",
      "emp_profile",
      "manage_user",
      "dept_management",
    ];

    const MODE_MODULES = {
      1: ["emp_attendance_normal", "admin_attendance_normal", "approval"],
      2: ["emp_attendance_gps", "admin_attendance_gps", "approval"],
      3: ["emp_attendance_face", "admin_attendance_face", "face_approval"],
      4: [
        "emp_site_attendance_face",
        "admin_attendance_site",
        "face_approval",
        "emp_site",
        "site_management",
      ],
    };

    const assignedModules = [
      ...DEFAULT_MODULES,
      ...MODE_MODULES[attendanceMode],
    ];

    if (assignedModules.length > 0) {
      // Admin role → full can_view + can_edit on every module
      const adminPermValues = assignedModules.map((key) => [
        tenantId,
        adminRoleId,
        key,
        1,
        1,
      ]);
      await conn.query(
        `INSERT INTO role_permissions (tenant_id, role_id, module_key, can_view, can_edit)
         VALUES ?
         ON DUPLICATE KEY UPDATE can_view = VALUES(can_view), can_edit = VALUES(can_edit)`,
        [adminPermValues],
      );

      // HR role → full can_view + can_edit on every module
      const hrPermValues = assignedModules.map((key) => [
        tenantId,
        hrRoleId,
        key,
        1,
        1,
      ]);
      await conn.query(
        `INSERT INTO role_permissions (tenant_id, role_id, module_key, can_view, can_edit)
         VALUES ?
         ON DUPLICATE KEY UPDATE can_view = VALUES(can_view), can_edit = VALUES(can_edit)`,
        [hrPermValues],
      );
    }

    await conn.commit();

    // ── 16. Cleanup OTP session ───────────────────────────────────────────
    otpStore.delete(`${session_id}:admin`);
    otpStore.delete(`${session_id}:hr`);

    res.status(201).json({
      message: "Organisation registered successfully.",
      tenant_id: tenantId,
      company_code: companyCode,
      admin_emp_id: adminEmpId,
      hr_emp_id: hrEmpId,
      attendance_mode: attendanceMode,
      trial_ends_at: toMysqlDate(trialEndsAt),
    });
  } catch (err) {
    await conn.rollback();
    console.error("[complete] Registration failed:", err);
    res.status(500).json({ message: "Registration failed. Please try again." });
  } finally {
    conn.release();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PASSWORD — SEND OTP
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/forgot-password/send-otp", otpLimiter, async (req, res) => {
  try {
    const { username, email, contact_number } = req.body;

    if (!username || !email || !contact_number) {
      return res
        .status(400)
        .json({ message: "username, email and contact_number are required." });
    }

    const [users] = await db.query(
      `SELECT lm.login_id, lm.username, lm.contact_number, lm.tenant_id,
              rm.role_name,
              t.admin_email, t.hr_email, e.email_id
       FROM login_master lm
       LEFT JOIN tenants t ON t.tenant_id = lm.tenant_id
       LEFT JOIN employee_master e ON e.emp_id = lm.emp_id
       LEFT JOIN role_master rm ON rm.role_id = lm.role_id
       WHERE lm.username = ? AND lm.contact_number = ? LIMIT 1`,
      [username, contact_number],
    );

    if (users.length === 0) {
      return res.status(400).json({ message: "Invalid credentials." });
    }

    const user = users[0];
    let validEmail = false;

    if (user.role_name === "Admin") {
      validEmail = user.admin_email?.toLowerCase() === email?.toLowerCase();
    } else if (user.role_name === "HR") {
      validEmail = user.hr_email?.toLowerCase() === email?.toLowerCase();
    } else {
      validEmail = user.email_id?.toLowerCase() === email?.toLowerCase();
    }

    if (!validEmail) {
      return res.status(400).json({ message: "Invalid credentials." });
    }

    const otp = crypto.randomInt(100000, 999999).toString();

    await db.query(
      `UPDATE login_master SET reset_otp = ?,
       reset_otp_expiry = DATE_ADD(NOW(), INTERVAL 10 MINUTE)
       WHERE login_id = ?`,
      [otp, user.login_id],
    );

    await transporter.sendMail({
      from: `"${process.env.APP_NAME || "EMS"}" <${process.env.SMTP_USER}>`,
      to: email,
      subject: "Password Reset OTP",
      html: `
        <div style="font-family:sans-serif;padding:20px;">
          <h2>Password Reset OTP</h2>
          <h1>${otp}</h1>
          <p>This OTP expires in 10 minutes.</p>
        </div>`,
    });

    res.json({ message: "OTP sent successfully." });
  } catch (err) {
    console.error("[forgot-password] Error:", err);
    res.status(500).json({ message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// RESEND OTP
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/resend-otp", otpLimiter, async (req, res) => {
  try {
    const { session_id, org_name, admin_email, hr_email } = req.body;

    if (!session_id || !admin_email || !hr_email) {
      return res.status(400).json({ message: "Missing required fields." });
    }

    // ── Validate session exists before overwriting ────────────────────────
    const existingAdmin = otpStore.get(`${session_id}:admin`);
    const existingHr = otpStore.get(`${session_id}:hr`);

    if (!existingAdmin || !existingHr) {
      return res.status(400).json({
        message: "Invalid or expired session. Please restart registration.",
      });
    }

    const adminOtp = generateOtp();
    const hrOtp = generateOtp();
    const expiresAt = Date.now() + 10 * 60 * 1000;

    const savedMode = existingAdmin.attendance_mode ?? 1;

    otpStore.set(`${session_id}:admin`, {
      otp: adminOtp,
      email: admin_email.toLowerCase().trim(),
      expiresAt,
      verified: false,
      attendance_mode: savedMode,
    });
    otpStore.set(`${session_id}:hr`, {
      otp: hrOtp,
      email: hr_email.toLowerCase().trim(),
      expiresAt,
      verified: false,
      attendance_mode: savedMode,
    });

    await Promise.all([
      sendOtpEmail(admin_email, adminOtp, org_name),
      sendOtpEmail(hr_email, hrOtp, org_name),
    ]);

    res.json({ message: "OTP resent successfully." });
  } catch (err) {
    console.error("[resend-otp] Error:", err);
    res.status(500).json({ message: "Failed to resend OTP." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// AUTO CLEANUP EXPIRED OTPs
// ─────────────────────────────────────────────────────────────────────────────
setInterval(
  () => {
    const now = Date.now();
    for (const [key, value] of otpStore.entries()) {
      if (value.expiresAt < now) otpStore.delete(key);
    }
  },
  5 * 60 * 1000,
);

// ─────────────────────────────────────────────────────────────────────────────
// ROUTES — ORDER MATTERS: specific before general
// ─────────────────────────────────────────────────────────────────────────────

// ── Auth
const authRoutes = require("./auth_routes");
app.use("/api/auth", authRoutes);

// ── App Admin login (JWT-based, app_admin_master table)
const appAdminLogin = require("./app_admin_login");
app.use("/api/auth/app-admin", appAdminLogin);

// ── Departments
const departmentrouter = require("./department");
app.use("/api/departments", authMiddleware, departmentrouter);

const rolerouter = require("./role");
app.use("/api/roles", authMiddleware, rolerouter);

const rolePermissions = require("./role_permissions");
app.use("/api/role-permissions", rolePermissions);

const tenantModeRoutes = require("./tenant_attendance_mode");
app.use("/api/tenant", authMiddleware, tenantModeRoutes);

const designationrouter = require("./designation");
app.use("/api/designations", authMiddleware, designationrouter);

// ── SPECIFIC /api/app-admin/* routes MUST come before the catch-all below ──

// Global Notifications (Super Admin)
const globalNotifRoutes = require("./global_notification_routes");
const requireAppAdmin = require("./middleware/app_admin_auth");
app.use("/api/app-admin/notifications", requireAppAdmin, globalNotifRoutes);

// Plans (app-admin)
const planRoutes = require("./plans_routes");
app.use("/api/app-admin/plans", planRoutes);

// System Modules (app-admin)
const systemModulesRoutes = require("./system_modules_routes");
app.use("/api/app-admin/system-modules", systemModulesRoutes);

// ── CATCH-ALL for /api/app-admin — must be LAST among app-admin routes
const ManageOrganizationRouter = require("./app_admin_org_router");
app.use("/api/app-admin", ManageOrganizationRouter);

// ── Plans (public/tenant)
const plansRoutes = require("./plans");
app.use("/api/plans", plansRoutes);

// ── Employees
const employeeRoutes = require("./employees");
app.use("/api/employees", authMiddleware, employeeRoutes);

// ── Pending Requests
const pendingRequestRoutes = require("./employee_pending_request");
app.use("/api/pending-request", authMiddleware, pendingRequestRoutes);

// ── Admin Approval
const approvalRouter = require("./admin_approval");
app.use("/api/admin", approvalRouter);

// ── Holidays
const holidayRoutes = require("./holiday_routes");
app.use("/api/holidays", holidayRoutes);

// ── Attendance History — must be BEFORE /api/attendance to avoid interception
app.use("/api/attendance/history", require("./Attendance/history"));

// ── Attendance
const normalInOutRouter = require("./Attendance/normal_in_out");
app.use("/api/attendance", normalInOutRouter);

const attendanceGpsRoutes = require("./Attendance/attendance_gps");
app.use("/api/gps", attendanceGpsRoutes);

const attendanceGpsFaceRoutes = require("./Attendance/attendance_gps_face");
app.use("/api/face", attendanceGpsFaceRoutes);

// ── Face Embedding
const faceEmbRouter = require("./admin_face_approval");
app.use("/api/admin", faceEmbRouter);

// ── Proxy /api/face-service/* → Python FastAPI on :8000
const { createProxyMiddleware } = require("http-proxy-middleware");
app.use(
  "/api/face-service",
  createProxyMiddleware({
    target: "http://127.0.0.1:8000",
    changeOrigin: true,
    pathRewrite: { "^/api/face-service": "" }, // strips the prefix
    on: {
      error: (err, req, res) => {
        console.error("[face-proxy] Error:", err.message);
        res.status(502).json({ message: "Face service unavailable." });
      },
    },
  }),
);

// ── Leave
const leaveRouter = require("./leave");
app.use("/api/leave", authMiddleware, leaveRouter);

// ── Comp Off
const compOffRoutes = require("./Attendance/comp-off");
app.use("/api/comp-off", compOffRoutes);

// ── Attendance Reports
const reportRouter = require("./Attendance/attendance_report_routes");
app.use("/api", authMiddleware, reportRouter);

// leave reports
const leavereportRouter = require("./leave_report");
app.use("/api/report", leavereportRouter);

// ── Attendance Sessions
const attendanceSessionRouter = require("./Attendance/attendance_session_router");
app.use("/api/attendance_sessions", authMiddleware, attendanceSessionRouter);

// ── Sites
const siteRoutes = require("./sites");
app.use("/api/sites", siteRoutes);

// site entry routes
const siteEntryRoutes = require("./site_entry_routes");
app.use("/api/site-entry", siteEntryRoutes);

// ── Sessions
const sessionsRouter = require("./sessions");
app.use("/api/admin", sessionsRouter);

// ── Notifications (tenant employees)
const { initializeNotificationService } = require("./notify");
initializeNotificationService();

const notifRoutes = require("./notification_routes");
app.use("/api/notifications", authMiddleware, notifRoutes);

// ── Global Notification Cron (scheduled notifications)
const { initGlobalCron } = require("./global_notify");
initGlobalCron();

// ── Mark global notification opened (called from Flutter app by normal users)
app.post(
  "/api/notifications/mark-global-opened",
  authMiddleware,
  async (req, res) => {
    const { markOpened } = require("./global_notify");
    const { notification_id } = req.body;
    const empId = req.user?.emp_id;
    const tenantId = req.user?.tenant_id;
    if (!notification_id || !empId || !tenantId) {
      return res
        .status(400)
        .json({ success: false, message: "Missing fields." });
    }
    try {
      await markOpened(parseInt(notification_id, 10), empId, tenantId);
      res.json({ success: true });
    } catch (e) {
      console.error("[mark-global-opened] Error:", e);
      res.status(500).json({ success: false, message: "Failed." });
    }
  },
);

// ── Stubs
app.get("/api/leave-status-summary", (req, res) =>
  res.json({ ok: true, data: [] }),
);
app.get("/api/dashboard", (req, res) => res.json({ ok: true, data: {} }));

// ─────────────────────────────────────────────────────────────────────────────
// START SERVER
// ─────────────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(`Server running on port ${PORT}`),
);
