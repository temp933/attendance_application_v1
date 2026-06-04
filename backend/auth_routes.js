require("dotenv").config();

const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const rateLimit = require("express-rate-limit"); // FIX #12
const db = require("./config/db");

const APP_ADMIN_USERNAME = process.env.APP_ADMIN_USERNAME;
// FIX #2: Use hashed password from env instead of plaintext
// Generate hash once: node -e "console.log(require('bcryptjs').hashSync('yourpassword', 12))"
// Then set APP_ADMIN_PASSWORD_HASH=<hash> in your .env

// ── Nodemailer ────────────────────────────────────────────────────────────────
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: 587,
  secure: false,
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  tls: { rejectUnauthorized: false },
});

function generateToken() {
  return crypto.randomBytes(32).toString("hex");
}

function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

function nullIfEmpty(v) {
  return v === undefined || v === null || v === "" ? null : v;
}

// FIX #10: Hash session token before storing in DB
function hashToken(rawToken) {
  return crypto.createHash("sha256").update(rawToken).digest("hex");
}

const loginOtpStore = new Map();
const appAdminSessions = new Map();

// FIX #12: Rate limiters for brute-force protection
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { success: false, message: "Too many attempts. Try again later." },
});

const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { success: false, message: "Too many attempts. Try again later." },
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/login
// ─────────────────────────────────────────────────────────────────────────────
router.post("/login", loginLimiter, async (req, res) => {
  const { username, password, device_id, device_info } = req.body;

  if (!username || !password) {
    return res.status(400).json({
      success: false,
      message: "Username and password are required.",
    });
  }

  const normalizedUsername = username.trim().toLowerCase();

  // ── APP ADMIN LOGIN ─────────────────────────────
  // FIX #2: Compare against bcrypt hash instead of plaintext
  const isAppAdmin =
    normalizedUsername === APP_ADMIN_USERNAME.toLowerCase() &&
    (await bcrypt.compare(password, process.env.APP_ADMIN_PASSWORD_HASH));

  if (isAppAdmin) {
    const sessionToken = generateToken();

    // FIX #3: Add expiresAt to app admin session
    appAdminSessions.set(sessionToken, {
      username: APP_ADMIN_USERNAME,
      roleId: 999,
      createdAt: Date.now(),
      expiresAt: Date.now() + 24 * 60 * 60 * 1000,
    });

    console.log("[APP ADMIN SESSION TOKEN]:", sessionToken);

    return res.json({
      success: true,
      loginId: 0,
      roleId: 999,
      userType: "app_admin",
      username: APP_ADMIN_USERNAME,
      sessionToken,
      tenantId: "0",
    });
  }
  // FIX #1: Removed duplicate `if (!username || !password)` block that was here

  try {
    const [rows] = await db.query(
      `SELECT
lm.*,
rm.role_name,
t.admin_email,
t.hr_email,
t.is_active,
t.block_reason,
t.status AS tenant_status
 FROM login_master lm
INNER JOIN tenants t ON t.tenant_id = lm.tenant_id
LEFT JOIN role_master rm ON rm.role_id = lm.role_id AND rm.tenant_id = lm.tenant_id
WHERE lm.status = 'Active'
  AND lm.tenant_id IS NOT NULL
  AND t.is_active = 1
  AND t.status IN ('trial', 'active')
  AND (lm.username = ? OR lm.username = ?)
LIMIT 1`,
      [username.trim(), username.trim().toLowerCase()],
    );

    if (rows.length === 0) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid credentials." });
    }

    const user = rows[0];

    // ─────────────────────────────────────────────
    // TENANT VALIDATION
    // ─────────────────────────────────────────────

    if (user.is_active === 0) {
      return res.status(403).json({
        success: false,
        message:
          user.block_reason || "Company access blocked. Contact support.",
      });
    }

    if (user.tenant_status === "suspended") {
      return res.status(403).json({
        success: false,
        message: "Company account suspended.",
      });
    }

    if (user.tenant_status === "expired") {
      return res.status(403).json({
        success: false,
        message: "Subscription expired. Please renew your plan.",
      });
    }

    if (user.tenant_status !== "trial" && user.tenant_status !== "active") {
      return res.status(403).json({
        success: false,
        message: "Company account inactive.",
      });
    }

    if (user.locked_until && new Date(user.locked_until) > new Date()) {
      const remaining = Math.ceil(
        (new Date(user.locked_until) - Date.now()) / 60000,
      );
      return res.status(423).json({
        success: false,
        message: `Account locked. Try again in ${remaining} minute${remaining !== 1 ? "s" : ""}.`,
      });
    }

    const passwordMatch = await bcrypt.compare(password, user.password);

    if (!passwordMatch) {
      const attempts = (user.failed_attempts || 0) + 1;
      const MAX_ATTEMPTS = 5;

      if (attempts >= MAX_ATTEMPTS) {
        const lockUntil = new Date(Date.now() + 15 * 60 * 1000);
        await db.query(
          `UPDATE login_master SET failed_attempts = ?, locked_until = ? WHERE login_id = ?`,
          [attempts, lockUntil, user.login_id],
        );
        return res.status(423).json({
          success: false,
          message: "Too many failed attempts. Account locked for 15 minutes.",
        });
      } else {
        await db.query(
          `UPDATE login_master SET failed_attempts = ? WHERE login_id = ?`,
          [attempts, user.login_id],
        );
        return res.status(401).json({
          success: false,
          message: `Invalid credentials. ${MAX_ATTEMPTS - attempts} attempt${MAX_ATTEMPTS - attempts !== 1 ? "s" : ""} remaining.`,
        });
      }
    }

    await db.query(
      `UPDATE login_master SET failed_attempts = 0, locked_until = NULL WHERE login_id = ?`,
      [user.login_id],
    );

    if (user.is_first_login === 1) {
      return res.json({
        success: true,
        firstLogin: true,
        loginId: user.login_id,
        empId: user.emp_id ?? 0,
        roleId: user.role_id,
        username: user.username,
      });
    }

    let userType = "employee";
    const roleName = (user.role_name || "").toLowerCase().trim();

    if (roleName === "admin") userType = "org_admin";
    else if (roleName === "hr") userType = "org_hr";
    else if (roleName === "team lead" || roleName === "tl")
      userType = "team_lead";
    else if (roleName === "manager") userType = "manager";

    if (user.device_logged_in === 1 && user.session_device) {
      const existingDevice = JSON.parse(user.session_device || "{}");
      if (existingDevice.deviceId && existingDevice.deviceId !== device_id) {
        return res.status(409).json({
          success: false,
          message:
            "Account is active on another device. Please log out from that device first.",
        });
      }
    }

    // FIX #10: Generate raw token, store hashed token in DB, return raw to client
    const rawToken = generateToken();
    const hashedToken = hashToken(rawToken);

    console.log("====================================");
    console.log("[LOGIN] Session Token Generated");
    console.log("User:", user.username);
    console.log("Login ID:", user.login_id);
    console.log("====================================");

    const deviceInfoStr = JSON.stringify(device_info || {});

    await db.query(
      `UPDATE login_master SET session_token = ?, device_logged_in = 1, session_device = ?, last_login_at = NOW() WHERE login_id = ?`,
      [hashedToken, deviceInfoStr, user.login_id],
    );

    return res.json({
      success: true,
      firstLogin: false,
      loginId: user.login_id,
      empId: user.emp_id ?? 0,
      roleId: user.role_id,
      roleName: user.role_name ?? "",
      userType,
      username: user.username,
      sessionToken: rawToken, // client holds raw token
      tenantId: user.tenant_id,
    });
  } catch (err) {
    console.error("[/auth/login]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/validate-session
// ─────────────────────────────────────────────────────────────────────────────
router.post("/validate-session", async (req, res) => {
  try {
    const { login_id, session_token: sessionToken } = req.body;

    // ─────────────────────────────────────────────
    // APP ADMIN SESSION VALIDATION (NO DB)
    // ─────────────────────────────────────────────
    if (login_id === 0 || login_id === "0" || Number(login_id) === 0) {
      if (!sessionToken) {
        return res.json({
          valid: false,
          expired: true,
          force_logout: false,
        });
      }

      const session = appAdminSessions.get(sessionToken);

      if (!session) {
        return res.json({
          valid: false,
          expired: true,
          force_logout: false,
        });
      }

      // Check app admin session expiry
      if (Date.now() > session.expiresAt) {
        appAdminSessions.delete(sessionToken);
        return res.json({
          valid: false,
          expired: true,
          force_logout: false,
        });
      }

      return res.json({
        valid: true,
        expired: false,
        force_logout: false,
      });
    }

    // ─────────────────────────────────────────────
    // NORMAL USERS (DB VALIDATION)
    // ─────────────────────────────────────────────

    // Guard: token must exist before hashing
    if (!sessionToken) {
      return res.json({
        valid: false,
        expired: true,
        force_logout: false,
        userType: (() => {
          const rn = (user.role_name || "").toLowerCase().trim();
          if (rn === "admin") return "org_admin";
          if (rn === "hr") return "org_hr";
          if (rn === "team lead" || rn === "tl") return "team_lead";
          if (rn === "manager") return "manager";
          return "employee";
        })(),
        roleName: user.role_name ?? "",
      });
    }

    const hashedToken = hashToken(sessionToken);

    const [rows] = await db.query(
      `SELECT
     lm.session_token,
     lm.device_logged_in AS is_logged_in,
     lm.force_logout,
     rm.role_name          -- ✅ ADD THIS
   FROM login_master lm
   LEFT JOIN role_master rm 
     ON rm.role_id = lm.role_id AND rm.tenant_id = lm.tenant_id
   WHERE lm.login_id = ?`,
      [login_id],
    );

    if (!rows.length) {
      return res.json({
        valid: false,
        expired: true,
        force_logout: true,
      });
    }

    const user = rows[0];

    // Compare hashed tokens
    if (user.session_token !== hashedToken) {
      return res.json({
        valid: false,
        expired: true,
        force_logout: false,
      });
    }

    if (user.force_logout == 1) {
      await db.query(
        `UPDATE login_master SET force_logout = 0 WHERE login_id = ?`,
        [login_id],
      );

      return res.json({
        valid: false,
        expired: false,
        force_logout: true,
      });
    }

    if (!user.is_logged_in) {
      return res.json({
        valid: false,
        expired: true,
        force_logout: false,
      });
    }

    return res.json({
      valid: true,
      expired: false,
      force_logout: false,
      userType: (() => {
        const rn = (user.role_name || "").toLowerCase().trim();
        if (rn === "admin") return "org_admin";
        if (rn === "hr") return "org_hr";
        if (rn === "team lead" || rn === "tl") return "team_lead";
        if (rn === "manager") return "manager";
        return "employee";
      })(),
      roleName: user.role_name ?? "",
    });
  } catch (err) {
    console.error("[/auth/validate-session]", err);

    return res.status(500).json({
      valid: false,
      message: "Server error",
    });
  }
});

/// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/logout
// ─────────────────────────────────────────────────────────────────────────────
router.post("/logout", async (req, res) => {
  const { login_id, sessionToken } = req.body;

  if (login_id == 0 || login_id == "0") {
    if (sessionToken) appAdminSessions.delete(sessionToken);
    return res.json({ success: true });
  }

  if (!login_id) return res.json({ success: true });

  try {
    // ── Resolve emp_id from login_id ────────────────────────────────────────
    const [[loginRow]] = await db.query(
      `SELECT emp_id FROM login_master WHERE login_id = ? LIMIT 1`,
      [login_id],
    );

    if (loginRow?.emp_id) {
      // ── Auto-close any open GPS/GPS_FACE attendance on logout ─────────────
      await db.query(
        `UPDATE employee_attendance
         SET
           checkout_time      = NOW(),
           status             = 'completed',
           force_closed       = 1,
           force_close_reason = 'Auto-closed on logout',
           force_closed_by    = ?
         WHERE
           employee_id        = ?
           AND status         = 'active'
           AND attendance_mode IN ('gps', 'gps_face')`,
        [loginRow.emp_id, loginRow.emp_id],
      );
    }

    // ── Invalidate session ──────────────────────────────────────────────────
    await db.query(
      `UPDATE login_master
       SET session_token = NULL, device_logged_in = 0, session_device = NULL
       WHERE login_id = ?`,
      [login_id],
    );

    return res.json({ success: true });
  } catch (err) {
    console.error("[/auth/logout]", err);
    return res.status(500).json({ success: false, message: "Logout failed." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/change-password
// ─────────────────────────────────────────────────────────────────────────────
router.post("/change-password", async (req, res) => {
  const { login_id, new_password, confirm_password } = req.body;

  if (!login_id || !new_password || !confirm_password) {
    return res
      .status(400)
      .json({ success: false, message: "All fields are required." });
  }
  if (new_password !== confirm_password) {
    return res
      .status(400)
      .json({ success: false, message: "Passwords do not match." });
  }
  if (new_password.length < 8) {
    return res.status(400).json({
      success: false,
      message: "Password must be at least 8 characters.",
    });
  }
  if (!/[a-zA-Z]/.test(new_password)) {
    return res.status(400).json({
      success: false,
      message: "Password must contain at least one letter.",
    });
  }
  if (!/[0-9]/.test(new_password)) {
    return res.status(400).json({
      success: false,
      message: "Password must contain at least one number.",
    });
  }

  try {
    const [rows] = await db.query(
      `SELECT login_id, password FROM login_master WHERE login_id = ? LIMIT 1`,
      [login_id],
    );
    if (rows.length === 0)
      return res
        .status(404)
        .json({ success: false, message: "User not found." });

    const sameAsOld = await bcrypt.compare(new_password, rows[0].password);
    if (sameAsOld) {
      return res.status(400).json({
        success: false,
        message: "New password cannot be the same as current password.",
      });
    }

    const hashed = await bcrypt.hash(new_password, 12);
    await db.query(
      `UPDATE login_master SET password = ?, is_first_login = 0, password_updated_at = NOW(), session_token = NULL, device_logged_in = 0, session_device = NULL WHERE login_id = ?`,
      [hashed, login_id],
    );

    return res.json({
      success: true,
      message: "Password updated. Please log in again.",
    });
  } catch (err) {
    console.error("[/auth/change-password]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/reset-password
// ─────────────────────────────────────────────────────────────────────────────
router.post("/reset-password", async (req, res) => {
  const { emp_id, new_password, confirm_password } = req.body;

  if (!emp_id || !new_password || !confirm_password) {
    return res
      .status(400)
      .json({ success: false, message: "All fields are required." });
  }
  if (new_password !== confirm_password) {
    return res
      .status(400)
      .json({ success: false, message: "Passwords do not match." });
  }
  if (new_password.length < 8) {
    return res
      .status(400)
      .json({ success: false, message: "Password too short." });
  }

  try {
    const hashed = await bcrypt.hash(new_password, 12);
    const [result] = await db.query(
      `UPDATE login_master SET password = ?, is_first_login = 1, password_updated_at = NOW(), session_token = NULL, device_logged_in = 0, session_device = NULL, failed_attempts = 0, locked_until = NULL WHERE emp_id = ?`,
      [hashed, emp_id],
    );

    if (result.affectedRows === 0)
      return res
        .status(404)
        .json({ success: false, message: "Employee not found." });
    return res.json({
      success: true,
      message: "Password reset. Employee must change on next login.",
    });
  } catch (err) {
    console.error("[/auth/reset-password]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/send-login-otp
// ─────────────────────────────────────────────────────────────────────────────
router.post("/send-login-otp", otpLimiter, async (req, res) => {
  const { username } = req.body;
  if (!username)
    return res
      .status(400)
      .json({ success: false, message: "Username is required." });

  try {
    // FIX #8: Changed LEFT JOIN to INNER JOIN for tenants (tenant is mandatory)
    const [rows] = await db.query(
      `SELECT lm.login_id, lm.username, lm.status,
              COALESCE(e.email_id, t.admin_email) AS contact_email
         FROM login_master lm
         LEFT JOIN employee_master e ON e.emp_id = lm.emp_id
         INNER JOIN tenants t ON t.tenant_id = lm.tenant_id
        WHERE lm.status = 'Active'
  AND lm.tenant_id IS NOT NULL
  AND t.is_active = 1
  AND t.status IN ('trial', 'active')
          AND (lm.username = ? OR lm.username = ?)
        LIMIT 1`,
      [username.trim(), username.trim().toLowerCase()],
    );

    if (rows.length === 0) {
      return res.json({
        success: true,
        message: "If the account exists, an OTP has been sent.",
      });
    }

    const user = rows[0];
    if (!user.contact_email) {
      return res.status(400).json({
        success: false,
        message: "No email registered for this account.",
      });
    }

    const otp = generateOtp();
    const expiresAt = Date.now() + 5 * 60 * 1000;
    loginOtpStore.set(`login:${user.login_id}`, { otp, expiresAt });

    await transporter.sendMail({
      from: `"${process.env.APP_NAME || "EMS"}" <${process.env.SMTP_USER}>`,
      to: user.contact_email,
      subject: "Your Login OTP",
      html: `
        <div style="font-family:sans-serif;max-width:400px;margin:auto;padding:32px;border-radius:12px;border:1px solid #e5e7eb">
          <h2 style="color:#4F46E5;margin-bottom:8px">Login OTP</h2>
          <p style="color:#6B7280;margin-bottom:24px">Use this code to sign in. It expires in 5 minutes.</p>
          <div style="font-size:36px;font-weight:800;letter-spacing:12px;color:#1E1B4B;text-align:center;padding:16px;background:#EEF2FF;border-radius:8px">${otp}</div>
          <p style="color:#9CA3AF;font-size:12px;margin-top:24px">If you didn't request this, ignore this email.</p>
        </div>`,
    });

    return res.json({
      success: true,
      message: "OTP sent to registered email.",
    });
  } catch (err) {
    console.error("[/auth/send-login-otp]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/verify-login-otp
// ─────────────────────────────────────────────────────────────────────────────
router.post("/verify-login-otp", otpLimiter, async (req, res) => {
  const { username, otp, device_id, device_info } = req.body;

  if (!username || !otp) {
    return res
      .status(400)
      .json({ success: false, message: "Username and OTP are required." });
  }

  try {
    const [rows] = await db.query(
      `SELECT
lm.*,
rm.role_name,
t.admin_email,
t.hr_email,
t.is_active,
t.block_reason,
t.status AS tenant_status
 FROM login_master lm
INNER JOIN tenants t ON t.tenant_id = lm.tenant_id
LEFT JOIN role_master rm ON rm.role_id = lm.role_id AND rm.tenant_id = lm.tenant_id
WHERE lm.status = 'Active'
  AND lm.tenant_id IS NOT NULL
  AND t.is_active = 1
  AND t.status IN ('trial', 'active')
  AND (lm.username = ? OR lm.username = ?)
LIMIT 1`,
      [username.trim(), username.trim().toLowerCase()],
    );

    if (rows.length === 0)
      return res
        .status(401)
        .json({ success: false, message: "Invalid credentials." });

    const user = rows[0];

    if (user.is_active === 0) {
      return res.status(403).json({
        success: false,
        message:
          user.block_reason || "Company access blocked. Contact support.",
      });
    }

    if (user.tenant_status === "suspended") {
      return res.status(403).json({
        success: false,
        message: "Company account suspended.",
      });
    }

    if (user.tenant_status === "expired") {
      return res.status(403).json({
        success: false,
        message: "Subscription expired. Please renew your plan.",
      });
    }

    const entry = loginOtpStore.get(`login:${user.login_id}`);

    if (!entry)
      return res.status(400).json({
        success: false,
        message: "No OTP found. Please request a new one.",
      });
    if (Date.now() > entry.expiresAt) {
      loginOtpStore.delete(`login:${user.login_id}`);
      return res.status(400).json({
        success: false,
        message: "OTP expired. Please request a new one.",
      });
    }
    if (entry.otp !== otp.trim())
      return res.status(400).json({ success: false, message: "Invalid OTP." });

    loginOtpStore.delete(`login:${user.login_id}`);

    // FIX #6: Single-device check for OTP login (same as password login)
    if (user.device_logged_in === 1 && user.session_device) {
      const existingDevice = JSON.parse(user.session_device || "{}");
      if (existingDevice.deviceId && existingDevice.deviceId !== device_id) {
        return res.status(409).json({
          success: false,
          message:
            "Account is active on another device. Please log out from that device first.",
        });
      }
    }

    let userType = "employee";
    const roleName = (user.role_name || "").toLowerCase().trim();

    if (roleName === "admin") userType = "org_admin";
    else if (roleName === "hr") userType = "org_hr";
    else if (roleName === "team lead" || roleName === "tl")
      userType = "team_lead";
    else if (roleName === "manager") userType = "manager";

    // FIX #10: Hash token before storing in DB
    const rawToken = generateToken();
    const hashedToken = hashToken(rawToken);
    const deviceInfoStr = JSON.stringify(device_info || {});

    await db.query(
      `UPDATE login_master SET session_token = ?, device_logged_in = 1, session_device = ?, last_login_at = NOW(), failed_attempts = 0, locked_until = NULL WHERE login_id = ?`,
      [hashedToken, deviceInfoStr, user.login_id],
    );

    return res.json({
      success: true,
      firstLogin: user.is_first_login === 1,
      loginId: user.login_id,
      empId: user.emp_id ?? 0,
      roleId: user.role_id,
      roleName: user.role_name ?? "",
      userType,
      username: user.username,
      sessionToken: rawToken, // client holds raw token
      tenantId: user.tenant_id,
    });
  } catch (err) {
    console.error("[/auth/verify-login-otp]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/complete  — Organisation registration (Step 3)
// ─────────────────────────────────────────────────────────────────────────────
router.post("/complete", async (req, res) => {
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
    admin_login,
    hr_login,
    admin_profile,
    hr_profile,
  } = req.body;

  if (!session_id || !admin_email || !hr_email) {
    return res
      .status(400)
      .json({ success: false, message: "Missing required fields." });
  }
  if (!admin_login?.username || !admin_login?.password) {
    return res.status(400).json({
      success: false,
      message: "admin_login.username and password are required.",
    });
  }
  if (!hr_login?.username || !hr_login?.password) {
    return res.status(400).json({
      success: false,
      message: "hr_login.username and password are required.",
    });
  }
  if (!admin_profile || !hr_profile) {
    return res.status(400).json({
      success: false,
      message: "admin_profile and hr_profile are required.",
    });
  }

  const profileRequired = [
    "first_name",
    "last_name",
    "phone_number",
    "date_of_birth",
    "gender",
    "date_of_joining",
    "employment_type",
    "work_type",
    "permanent_address",
  ];
  for (const field of profileRequired) {
    if (!admin_profile[field]) {
      return res.status(400).json({
        success: false,
        message: `admin_profile.${field} is required.`,
      });
    }
    if (!hr_profile[field]) {
      return res
        .status(400)
        .json({ success: false, message: `hr_profile.${field} is required.` });
    }
  }

  const validWorkTypes = ["Full Time", "Part Time"];
  if (!validWorkTypes.includes(admin_profile.work_type)) {
    return res.status(400).json({
      success: false,
      message: `admin_profile.work_type must be 'Full Time' or 'Part Time'.`,
    });
  }
  if (!validWorkTypes.includes(hr_profile.work_type)) {
    return res.status(400).json({
      success: false,
      message: `hr_profile.work_type must be 'Full Time' or 'Part Time'.`,
    });
  }

  let sessionData;
  try {
    const [[row]] = await db.query(
      `SELECT * FROM registration_sessions WHERE session_id = ? AND status = 'verified' LIMIT 1`,
      [session_id],
    );
    if (!row) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired session. Please restart registration.",
      });
    }
    sessionData = row;
  } catch (err) {
    console.error("[/complete] session lookup", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }

  if (
    sessionData.admin_email.toLowerCase() !==
      admin_email.trim().toLowerCase() ||
    sessionData.hr_email.toLowerCase() !== hr_email.trim().toLowerCase()
  ) {
    return res.status(400).json({
      success: false,
      message: "Email mismatch with verified session.",
    });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[dupAdmin]] = await conn.query(
      "SELECT login_id FROM login_master WHERE username = ? LIMIT 1",
      [admin_login.username.trim()],
    );
    if (dupAdmin) {
      await conn.rollback();
      return res.status(409).json({
        success: false,
        message: `Username '${admin_login.username}' is already taken.`,
      });
    }

    const [[dupHr]] = await conn.query(
      "SELECT login_id FROM login_master WHERE username = ? LIMIT 1",
      [hr_login.username.trim()],
    );
    if (dupHr) {
      await conn.rollback();
      return res.status(409).json({
        success: false,
        message: `Username '${hr_login.username}' is already taken.`,
      });
    }

    // FIX #9: Safer company code generation — strip all non-alphanumeric chars
    const safeOrgName = (org_name || "ORG")
      .replace(/[^A-Z0-9]/gi, "")
      .toUpperCase();
    const companyCode = safeOrgName.substring(0, 10) + "_" + Date.now();

    const tenantId = crypto.randomUUID();

    await conn.query(
      `INSERT INTO tenants
        (tenant_id, company_name, company_code, plan_id,
         contact_person, contact_number,
         admin_email, hr_email, max_users,
         company_address, domain_name, gst_number,
         status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW())`,
      [
        tenantId,
        (org_name || "").trim(),
        companyCode,
        process.env.DEFAULT_PLAN_ID || "1",
        nullIfEmpty(contact_person),
        nullIfEmpty(contact_number),
        admin_email.trim().toLowerCase(),
        hr_email.trim().toLowerCase(),
        expected_employees || 50,
        nullIfEmpty(company_address),
        nullIfEmpty(domain_name),
        nullIfEmpty(gst_number),
      ],
    );

    const ap = admin_profile;
    const [adminEmpResult] = await conn.query(
      `INSERT INTO employee_master
        (tenant_id, first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         department_id, role_id, date_of_joining,
         employment_type, work_type,
         permanent_address, communication_address,
         father_name,
         emergency_contact, emergency_contact_relation,
         aadhar_number, pan_number,
         pf_number, esic_number, years_experience,
         status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
      [
        tenantId,
        ap.first_name.trim(),
        nullIfEmpty(ap.mid_name),
        ap.last_name.trim(),
        admin_email.trim().toLowerCase(),
        ap.phone_number.trim(),
        ap.date_of_birth,
        ap.gender,
        ap.date_of_joining,
        ap.employment_type,
        ap.work_type,
        ap.permanent_address.trim(),
        nullIfEmpty(ap.communication_address),
        nullIfEmpty(ap.father_name),
        nullIfEmpty(ap.emergency_contact),
        nullIfEmpty(ap.emergency_contact_relation),
        nullIfEmpty(ap.aadhar_number),
        nullIfEmpty(ap.pan_number),
        nullIfEmpty(ap.pf_number),
        nullIfEmpty(ap.esic_number),
        ap.years_experience !== undefined
          ? parseInt(ap.years_experience, 10)
          : null,
      ],
    );
    const adminEmpId = adminEmpResult.insertId;

    const hashedAdminPass = await bcrypt.hash(admin_login.password, 12);
    await conn.query(
      `INSERT INTO login_master
        (tenant_id, company_id, emp_id, username, password,
         role_id, is_first_login, status, created_at)
       VALUES (?, ?, ?, ?, ?, 1, 0, 'Active', NOW())`,
      [
        tenantId,
        tenantId,
        adminEmpId,
        admin_login.username.trim(),
        hashedAdminPass,
      ],
    );

    const hp = hr_profile;
    const [hrEmpResult] = await conn.query(
      `INSERT INTO employee_master
        (tenant_id, first_name, mid_name, last_name,
         email_id, phone_number, date_of_birth, gender,
         department_id, role_id, date_of_joining,
         employment_type, work_type,
         permanent_address, communication_address,
         father_name,
         emergency_contact, emergency_contact_relation,
         aadhar_number, pan_number,
         pf_number, esic_number, years_experience,
         status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 2, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', NOW())`,
      [
        tenantId,
        hp.first_name.trim(),
        nullIfEmpty(hp.mid_name),
        hp.last_name.trim(),
        hr_email.trim().toLowerCase(),
        hp.phone_number.trim(),
        hp.date_of_birth,
        hp.gender,
        hp.date_of_joining,
        hp.employment_type,
        hp.work_type,
        hp.permanent_address.trim(),
        nullIfEmpty(hp.communication_address),
        nullIfEmpty(hp.father_name),
        nullIfEmpty(hp.emergency_contact),
        nullIfEmpty(hp.emergency_contact_relation),
        nullIfEmpty(hp.aadhar_number),
        nullIfEmpty(hp.pan_number),
        nullIfEmpty(hp.pf_number),
        nullIfEmpty(hp.esic_number),
        hp.years_experience !== undefined
          ? parseInt(hp.years_experience, 10)
          : null,
      ],
    );
    const hrEmpId = hrEmpResult.insertId;

    const hashedHrPass = await bcrypt.hash(hr_login.password, 12);
    await conn.query(
      `INSERT INTO login_master
        (tenant_id, company_id, emp_id, username, password,
         role_id, is_first_login, status, created_at)
       VALUES (?, ?, ?, ?, ?, 2, 1, 'Active', NOW())`,
      [tenantId, tenantId, hrEmpId, hr_login.username.trim(), hashedHrPass],
    );

    await conn.query(
      "UPDATE registration_sessions SET status = 'completed' WHERE session_id = ?",
      [session_id],
    );

    await conn.commit();

    return res.status(201).json({
      success: true,
      message: "Organisation registered successfully.",
      admin_username: admin_login.username.trim(),
      hr_username: hr_login.username.trim(),
      tenant_id: tenantId,
      admin_emp_id: adminEmpId,
      hr_emp_id: hrEmpId,
    });
  } catch (err) {
    await conn.rollback();
    console.error("[POST /auth/complete]", err);

    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({
        success: false,
        message:
          "Duplicate entry detected (email, phone, Aadhar or PAN already exists).",
      });
    }

    return res
      .status(500)
      .json({ success: false, message: `Server error: ${err.message}` });
  } finally {
    conn.release();
  }
});

router.post("/forgot-password/verify-otp", async (req, res) => {
  try {
    const { username, otp } = req.body;

    const [rows] = await db.query(
      `SELECT login_id
       FROM login_master
       WHERE username = ?
       AND reset_otp = ?
       AND reset_otp_expiry > NOW()
       LIMIT 1`,
      [username, otp],
    );

    if (rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    res.json({
      success: true,
      message: "OTP verified",
    });
  } catch (err) {
    console.error(err);

    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

// FIX #7: Added password strength validation to forgot-password/reset
router.post("/forgot-password/reset", otpLimiter, async (req, res) => {
  try {
    const { username, otp, new_password } = req.body;

    if (!username || !otp || !new_password) {
      return res.status(400).json({
        success: false,
        message: "Missing fields",
      });
    }

    if (new_password.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 8 characters.",
      });
    }

    if (!/[a-zA-Z]/.test(new_password)) {
      return res.status(400).json({
        success: false,
        message: "Password must contain at least one letter.",
      });
    }

    if (!/[0-9]/.test(new_password)) {
      return res.status(400).json({
        success: false,
        message: "Password must contain at least one number.",
      });
    }

    const [rows] = await db.query(
      `SELECT login_id
       FROM login_master
       WHERE username = ?
       AND reset_otp = ?
       AND reset_otp_expiry > NOW()
       LIMIT 1`,
      [username, otp],
    );

    if (rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    const hashedPassword = await bcrypt.hash(new_password, 12);

    await db.query(
      `UPDATE login_master
       SET password = ?,
           reset_otp = NULL,
           reset_otp_expiry = NULL
       WHERE login_id = ?`,
      [hashedPassword, rows[0].login_id],
    );

    res.json({
      success: true,
      message: "Password reset successful",
    });
  } catch (err) {
    console.error(err);

    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

// Auto-cleanup expired login OTPs every 2 minutes
setInterval(
  () => {
    const now = Date.now();
    for (const [key, val] of loginOtpStore.entries()) {
      if (val.expiresAt < now) loginOtpStore.delete(key);
    }
  },
  2 * 60 * 1000,
);

// Auto-cleanup expired app admin sessions every 30 minutes
setInterval(
  () => {
    const now = Date.now();
    for (const [token, session] of appAdminSessions.entries()) {
      if (session.expiresAt < now) appAdminSessions.delete(token);
    }
  },
  30 * 60 * 1000,
);

router.appAdminSessions = appAdminSessions;
module.exports = router;
