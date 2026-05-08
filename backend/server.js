require("dotenv").config();

const express = require("express");
const bcrypt = require("bcryptjs");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const cors = require("cors");
const app = express();

app.use(cors());
app.use(express.json());

// ── DB ───────────────────────────────────────────────────────────────────────
const db = require("./config/db");

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

// ─────────────────────────────────────────────────────────────────────────────
// SEND OTP
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/send-otp", async (req, res) => {
  try {
    let { org_name, admin_email, hr_email } = req.body;

    admin_email = admin_email?.toLowerCase().trim();
    hr_email = hr_email?.toLowerCase().trim();

    if (!org_name || !admin_email || !hr_email) {
      return res.status(400).json({
        message: "org_name, admin_email and hr_email are required.",
      });
    }

    // Check duplicate
    const [existing] = await db.query(
      "SELECT tenant_id FROM tenants WHERE admin_email = ? OR hr_email = ? LIMIT 1",
      [admin_email, hr_email],
    );

    if (existing.length > 0) {
      return res.status(409).json({ message: "Organization already exists." });
    }

    const sessionId = generateSessionId();
    const adminOtp = generateOtp();
    const hrOtp = generateOtp();
    const expiresAt = Date.now() + 10 * 60 * 1000;

    otpStore.set(`${sessionId}:admin`, {
      otp: adminOtp,
      email: admin_email,
      expiresAt,
    });
    otpStore.set(`${sessionId}:hr`, { otp: hrOtp, email: hr_email, expiresAt });

    await Promise.all([
      sendOtpEmail(admin_email, adminOtp, org_name),
      sendOtpEmail(hr_email, hrOtp, org_name),
    ]);

    res.json({ message: "OTP sent successfully.", session_id: sessionId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// VERIFY OTP
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/verify-otp", (req, res) => {
  const { session_id, admin_otp, hr_otp } = req.body;

  const adminEntry = otpStore.get(`${session_id}:admin`);
  const hrEntry = otpStore.get(`${session_id}:hr`);

  if (!adminEntry || !hrEntry) {
    return res.status(400).json({ message: "Session expired." });
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
app.post("/api/auth/complete", async (req, res) => {
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

  const adminUsername = admin_login?.username?.trim();
  const adminPassword = admin_login?.password;

  const hrUsername = hr_login?.username?.trim();
  const hrPassword = hr_login?.password;

  if (!adminUsername || !adminPassword) {
    return res.status(400).json({
      message: "Admin login details missing",
    });
  }

  if (!hrUsername || !hrPassword) {
    return res.status(400).json({
      message: "HR login details missing",
    });
  }
  // ── Validate OTP session ─────────────────────────────────────────────────
  const adminEntry = otpStore.get(`${session_id}:admin`);
  const hrEntry = otpStore.get(`${session_id}:hr`);

  if (!adminEntry?.verified || !hrEntry?.verified) {
    return res.status(400).json({ message: "OTP verification required." });
  }

  if (adminEntry.email !== admin_email.toLowerCase().trim()) {
    return res.status(400).json({ message: "Admin email mismatch." });
  }

  if (hrEntry.email !== hr_email.toLowerCase().trim()) {
    return res.status(400).json({ message: "HR email mismatch." });
  }

  const conn = await db.getConnection();

  try {
    await conn.beginTransaction();

    let tenantId;
    let exists = true;

    while (exists) {
      tenantId = generateTenantId();

      const [rows] = await conn.query(
        "SELECT tenant_id FROM tenants WHERE tenant_id = ? LIMIT 1",
        [tenantId],
      );

      exists = rows.length > 0;
    }

    const adminPasswordHash = await bcrypt.hash(adminPassword, 12);
    const hrPasswordHash = await bcrypt.hash(hrPassword, 12);

    const [[adminRole]] = await conn.query(
      `SELECT role_id FROM role_master WHERE role_name = 'Admin' LIMIT 1`,
    );

    const [[hrRole]] = await conn.query(
      `SELECT role_id FROM role_master WHERE role_name = 'HR' LIMIT 1`,
    );

    const adminRoleId = adminRole?.role_id || 1;
    const hrRoleId = hrRole?.role_id || 2;

    // ── Step 1: Insert tenant (company_code auto-generated by trigger) ────
    await conn.query(
      `INSERT INTO tenants
        (tenant_id, company_name, contact_person, contact_number,
         admin_email, hr_email, max_users, company_address,
         domain_name, gst_number, plan_id, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'trial', NOW())`,
      [
        tenantId,
        org_name,
        contact_person,
        contact_number,
        admin_email.toLowerCase().trim(),
        hr_email.toLowerCase().trim(),
        expected_employees || 50,
        company_address,
        domain_name,
        gst_number || null,
        plan_id || "plan-free-trial",
      ],
    );

    // ── Step 2: Fetch the auto-generated company_code from trigger ────────
    const [[tenant]] = await conn.query(
      `SELECT company_code FROM tenants WHERE tenant_id = ?`,
      [tenantId],
    );

    const companyCode = tenant.company_code;

    await conn.query(
      `INSERT INTO login_master
  (
    tenant_id,
    company_id,
    username,
    contact_number,
    password,
    role_id,
    is_first_login,
    status,
    created_at
  )
  VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
      [
        tenantId,
        companyCode,
        adminUsername,
        admin_profile?.phone_number || null,
        adminPasswordHash,
        adminRoleId,
      ],
    );

    await conn.query(
      `INSERT INTO login_master
  (
    tenant_id,
    company_id,
    username,
    contact_number,
    password,
    role_id,
    is_first_login,
    status,
    created_at
  )
    VALUES (?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
      [
        tenantId,
        companyCode,
        hrUsername,
        hr_profile?.phone_number || null,
        hrPasswordHash,
        hrRoleId,
      ],
    );

    await conn.commit();

    // ── Cleanup OTP session ───────────────────────────────────────────────
    otpStore.delete(`${session_id}:admin`);
    otpStore.delete(`${session_id}:hr`);

    res.status(201).json({
      message: "Organisation registered successfully.",
      tenant_id: tenantId,
      company_code: companyCode,
    });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ message: "Registration failed." });
  } finally {
    conn.release();
  }
});

app.post("/api/auth/forgot-password/send-otp", async (req, res) => {
  try {
    const { username, email, contact_number } = req.body;

    const [users] = await db.query(
      `SELECT
          lm.login_id,
          lm.username,
          lm.contact_number,
          lm.role_id,
          lm.tenant_id,
          t.admin_email,
          t.hr_email,
          e.email_id
       FROM login_master lm

       LEFT JOIN tenants t
         ON t.tenant_id = lm.tenant_id

       LEFT JOIN employee_master e
         ON e.emp_id = lm.emp_id

       WHERE lm.username = ?
         AND lm.contact_number = ?
       LIMIT 1`,
      [username, contact_number],
    );

    if (users.length === 0) {
      return res.status(400).json({
        message: "Invalid credentials",
      });
    }

    const user = users[0];

    let validEmail = false;

    // Admin
    if (user.role_id === 1) {
      validEmail = user.admin_email?.toLowerCase() === email?.toLowerCase();
    }

    // HR
    else if (user.role_id === 2) {
      validEmail = user.hr_email?.toLowerCase() === email?.toLowerCase();
    }

    // Employee
    else {
      validEmail = user.email_id?.toLowerCase() === email?.toLowerCase();
    }

    if (!validEmail) {
      return res.status(400).json({
        message: "Invalid credentials",
      });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    await db.query(
      `UPDATE login_master
       SET reset_otp = ?,
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
        </div>
      `,
    });

    res.json({
      message: "OTP sent successfully",
    });
  } catch (err) {
    console.error(err);

    res.status(500).json({
      message: "Server error",
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// RESEND OTP
// ─────────────────────────────────────────────────────────────────────────────
app.post("/api/auth/resend-otp", async (req, res) => {
  try {
    const { session_id, org_name, admin_email, hr_email } = req.body;

    if (!session_id || !admin_email || !hr_email) {
      return res.status(400).json({ message: "Missing required fields." });
    }

    const adminOtp = generateOtp();
    const hrOtp = generateOtp();
    const expiresAt = Date.now() + 10 * 60 * 1000;

    otpStore.set(`${session_id}:admin`, {
      otp: adminOtp,
      email: admin_email.toLowerCase().trim(),
      expiresAt,
    });
    otpStore.set(`${session_id}:hr`, {
      otp: hrOtp,
      email: hr_email.toLowerCase().trim(),
      expiresAt,
    });

    await Promise.all([
      sendOtpEmail(admin_email, adminOtp, org_name),
      sendOtpEmail(hr_email, hrOtp, org_name),
    ]);

    res.json({ message: "OTP resent successfully." });
  } catch (err) {
    console.error(err);
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

const authRoutes = require("./auth_routes");
app.use("/api/auth", authRoutes);

const employeeRoutes = require("./employee_routes");
app.use("/api/employees", employeeRoutes);
// ─────────────────────────────────────────────────────────────────────────────
// START SERVER
// ─────────────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(`Server running on port ${PORT}`),
);
