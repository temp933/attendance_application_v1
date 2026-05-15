require("dotenv").config();

const express = require("express");
const bcrypt = require("bcryptjs");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const cors = require("cors");
const app = express();
const authMiddleware = require("./middleware/auth");

app.use(cors());
app.use(express.json());

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
    return res.status(400).json({ message: "Admin login details missing." });
  }
  if (!hrUsername || !hrPassword) {
    return res.status(400).json({ message: "HR login details missing." });
  }

  // ── Validate OTP session ──────────────────────────────────────────────────
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

    // ─────────────────────────────────────────────────────────────
    // FETCH PLAN DETAILS
    // ─────────────────────────────────────────────────────────────
    const [[planRow]] = await conn.query(
      `SELECT 
      trial_days,
      billing_cycle,
      price_monthly,
      price_yearly
   FROM plans
   WHERE plan_id = ?
   LIMIT 1`,
      [plan_id || "plan-free-trial"],
    );

    const trialDays = planRow?.trial_days ?? 30;
    const billingCycle = planRow?.billing_cycle ?? "monthly";

    // ─────────────────────────────────────────────────────────────
    // CALCULATE PLAN DATES
    // ─────────────────────────────────────────────────────────────
    const today = new Date();

    const trialEndsAt = new Date(today);
    trialEndsAt.setDate(trialEndsAt.getDate() + trialDays);

    // Plan starts after trial
    const planStartsAt = new Date(trialEndsAt);
    planStartsAt.setDate(planStartsAt.getDate() + 1);

    // Plan end based on billing cycle
    const planEndsAt = new Date(planStartsAt);

    if (billingCycle === "yearly") {
      planEndsAt.setFullYear(planEndsAt.getFullYear() + 1);
    } else {
      planEndsAt.setMonth(planEndsAt.getMonth() + 1);
    }

    // ─────────────────────────────────────────────────────────────
    // MYSQL DATE FORMATTER
    // ─────────────────────────────────────────────────────────────
    const toMysqlDate = (d) => d.toISOString().split("T")[0];

    // ── Generate unique tenant ID ─────────────────────────────────────────
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

    // ── Get role IDs ──────────────────────────────────────────────────────
    const [[adminRoleRow]] = await conn.query(
      `SELECT role_id FROM role_master WHERE role_name = 'Admin' LIMIT 1`,
    );
    const [[hrRoleRow]] = await conn.query(
      `SELECT role_id FROM role_master WHERE role_name = 'HR' LIMIT 1`,
    );
    const adminRoleId = adminRoleRow?.role_id || 1;
    const hrRoleId = hrRoleRow?.role_id || 2;

    // ── Step 1: Insert tenant ─────────────────────────────────────────────
    await conn.query(
      `INSERT INTO tenants
    (tenant_id, company_name, contact_person, contact_number,
     admin_email, hr_email, max_users, company_address,
     domain_name, gst_number, plan_id, status,
     trial_ends_at, plan_starts_at, plan_ends_at,   -- ← NEW
     created_at)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'trial',
     ?, ?, ?,                                        -- ← NEW
     NOW())`,
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
        toMysqlDate(trialEndsAt), // ← NEW
        toMysqlDate(planStartsAt), // ← NEW
        toMysqlDate(planEndsAt), // ← NEW
      ],
    );

    // ── Step 2: Fetch auto-generated company_code ─────────────────────────
    const [[tenant]] = await conn.query(
      `SELECT company_code FROM tenants WHERE tenant_id = ?`,
      [tenantId],
    );
    const companyCode = tenant.company_code;

    // ── Step 3: Insert Admin into employee_master ─────────────────────────
    const [adminEmpResult] = await conn.query(
      `INSERT INTO employee_master
        (tenant_id, first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         department_id, role_id, date_of_joining,
         employment_type, work_type,
         permanent_address, communication_address,
         father_name, emergency_contact, emergency_contact_relation,
         aadhar_number, pan_number, pf_number, esic_number,
         years_experience, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
      [
        tenantId,
        admin_profile?.first_name?.trim() ||
          contact_person?.split(" ")[0] ||
          "Admin",
        admin_profile?.mid_name?.trim() || null,
        admin_profile?.last_name?.trim() ||
          contact_person?.split(" ").slice(1).join(" ") ||
          "User",
        admin_email.toLowerCase().trim(),
        admin_profile?.phone_number?.trim() || contact_number || null,
        admin_profile?.date_of_birth || null,
        admin_profile?.gender || null,
        adminRoleId,
        admin_profile?.date_of_joining ||
          new Date().toISOString().split("T")[0],
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

    // ── Step 4: Insert HR into employee_master ────────────────────────────
    const [hrEmpResult] = await conn.query(
      `INSERT INTO employee_master
        (tenant_id, first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         department_id, role_id, date_of_joining,
         employment_type, work_type,
         permanent_address, communication_address,
         father_name, emergency_contact, emergency_contact_relation,
         aadhar_number, pan_number, pf_number, esic_number,
         years_experience, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
      [
        tenantId,
        hr_profile?.first_name?.trim() || "HR",
        hr_profile?.mid_name?.trim() || null,
        hr_profile?.last_name?.trim() || "Manager",
        hr_email.toLowerCase().trim(),
        hr_profile?.phone_number?.trim() || null,
        hr_profile?.date_of_birth || null,
        hr_profile?.gender || null,
        hrRoleId,
        hr_profile?.date_of_joining || new Date().toISOString().split("T")[0],
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

    // ── Step 5: Hash passwords ────────────────────────────────────────────
    const adminPasswordHash = await bcrypt.hash(adminPassword, 12);
    const hrPasswordHash = await bcrypt.hash(hrPassword, 12);

    // ── Step 6: Create login records linked to emp_id ─────────────────────
    await conn.query(
      `INSERT INTO login_master
        (tenant_id, company_id, emp_id, username, contact_number,
         password, role_id, is_first_login, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
      [
        tenantId,
        companyCode,
        adminEmpId,
        adminUsername,
        admin_profile?.phone_number || null,
        adminPasswordHash,
        adminRoleId,
      ],
    );

    await conn.query(
      `INSERT INTO login_master
        (tenant_id, company_id, emp_id, username, contact_number,
         password, role_id, is_first_login, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'Active', NOW())`,
      [
        tenantId,
        companyCode,
        hrEmpId,
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
      admin_emp_id: adminEmpId,
      hr_emp_id: hrEmpId,
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

const departmentRoutes = require("./department_routes");
app.use("/api/departments", departmentRoutes);

const planRoutes = require("./plans_routes");
app.use("/api/app-admin/plans", planRoutes);

const employeeRoutes = require("./employees");
app.use("/api/employees", authMiddleware, employeeRoutes);

const pendingRequestRoutes = require("./employee_pending_request");
app.use("/api/pending-request", authMiddleware, pendingRequestRoutes);

const approvalRouter = require('./admin_approval');
app.use('/api/admin', approvalRouter);

const holidayRoutes = require("./holiday_routes");
app.use("/api/holidays", holidayRoutes);

const systemModulesRoutes = require("./system_modules_routes");
app.use("/api/app-admin/system-modules", systemModulesRoutes);

const appAdminLogin = require("./app_admin_login");
app.use("/api/auth/app-admin", appAdminLogin);

// const userManagementRouter = require("./user_management_router");
// app.use("/api", userManagementRouter);

const ManageOrganizationRouter = require("./app_admin_org_router");
app.use("/api/app-admin", ManageOrganizationRouter);
const plansRoutes = require("./plans");
app.use("/api/plans", plansRoutes);

// ─────────────────────────────────────────────────────────────────────────────
// START SERVER
// ─────────────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(`Server running on port ${PORT}`),
);
