require("dotenv").config();

const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

// ─────────────────────────────────────────────────────────────────────────────
// Config — pulled from .env
// ─────────────────────────────────────────────────────────────────────────────
const APP_ADMIN_USERNAME = process.env.APP_ADMIN_USERNAME; // "App_Admin"
const APP_ADMIN_PASSWORD_HASH = process.env.APP_ADMIN_PASSWORD_HASH; // bcrypt hash of "App_Admin@123"
const APP_ADMIN_EMAIL = process.env.APP_ADMIN_EMAIL; // "temps3220@gmail.com"
const JWT_SECRET = process.env.JWT_SECRET;

// Fail fast at startup if required env vars are missing
if (
  !APP_ADMIN_USERNAME ||
  !APP_ADMIN_PASSWORD_HASH ||
  !APP_ADMIN_EMAIL ||
  !JWT_SECRET
) {
  console.error(
    "[app_admin_routes] FATAL: APP_ADMIN_USERNAME, APP_ADMIN_PASSWORD_HASH, " +
      "APP_ADMIN_EMAIL, and JWT_SECRET must be set in .env",
  );
  process.exit(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Nodemailer transporter (reuses your existing SMTP config)
// ─────────────────────────────────────────────────────────────────────────────
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: parseInt(process.env.SMTP_PORT || "587", 10),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  tls: { rejectUnauthorized: false },
});

const otpStore = new Map();

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const MAX_OTP_ATTEMPTS = 5; // lock out after 5 wrong guesses

// Auto-purge expired entries every 2 minutes
setInterval(
  () => {
    const now = Date.now();
    for (const [key, val] of otpStore.entries()) {
      if (val.expiresAt < now) otpStore.delete(key);
    }
  },
  2 * 60 * 1000,
);

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Generate a cryptographically-random 6-digit OTP */
function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

/** Send OTP email to the App Admin */
async function sendOtpEmail(otp) {
  await transporter.sendMail({
    from: `"${process.env.APP_NAME || "EMS"} Admin" <${process.env.SMTP_USER}>`,
    to: APP_ADMIN_EMAIL,
    subject: "App Admin Login OTP",
    html: `
      <div style="font-family:sans-serif;max-width:420px;margin:auto;
                  padding:32px;border-radius:12px;border:1px solid #e5e7eb">
        <h2 style="color:#4F46E5;margin-bottom:8px">App Admin Login OTP</h2>
        <p style="color:#6B7280;margin-bottom:24px">
          Use the code below to complete your login. It expires in
          <strong>5 minutes</strong>.
        </p>
        <div style="font-size:36px;font-weight:800;letter-spacing:12px;
                    color:#1E1B4B;text-align:center;padding:16px;
                    background:#EEF2FF;border-radius:8px">
          ${otp}
        </div>
        <p style="color:#9CA3AF;font-size:12px;margin-top:24px">
          If you didn't request this, someone may be trying to access the admin
          panel. Please change your credentials immediately.
        </p>
      </div>`,
  });
}

router.post("/login", async (req, res) => {
  const { username, password } = req.body;

  // ── Basic input check ──────────────────────────────────────────────────────
  if (!username || !password) {
    return res.status(400).json({
      success: false,
      message: "Username and password are required.",
    });
  }

  // ── Username check (case-sensitive to match .env exactly) ─────────────────
  if (username.trim() !== APP_ADMIN_USERNAME) {
    // Return generic message to avoid username enumeration
    return res.status(401).json({
      success: false,
      message: "Invalid credentials.",
    });
  }

  // ── Password check via bcrypt ──────────────────────────────────────────────
  try {
    const passwordMatch = await bcrypt.compare(
      password,
      APP_ADMIN_PASSWORD_HASH,
    );
    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials.",
      });
    }
  } catch (err) {
    console.error("[/app-admin/login] bcrypt error:", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }

  // ── Generate & store OTP ───────────────────────────────────────────────────
  const otp = generateOtp();
  const expiresAt = Date.now() + OTP_TTL_MS;

  otpStore.set(APP_ADMIN_USERNAME, { otp, expiresAt, attempts: 0 });

  // ── Send OTP email ─────────────────────────────────────────────────────────
  try {
    await sendOtpEmail(otp);
  } catch (err) {
    console.error("[/app-admin/login] email error:", err);
    otpStore.delete(APP_ADMIN_USERNAME);
    return res.status(500).json({
      success: false,
      message: "Failed to send OTP. Please try again.",
    });
  }

  console.log(`[app-admin/login] OTP sent to ${APP_ADMIN_EMAIL}`);

  return res.json({
    success: true,
    message: "OTP sent to the registered admin email. Valid for 5 minutes.",
  });
});

router.post("/verify-otp", async (req, res) => {
  const { username, otp } = req.body;

  // ── Basic input check ──────────────────────────────────────────────────────
  if (!username || !otp) {
    return res.status(400).json({
      success: false,
      message: "Username and OTP are required.",
    });
  }

  // ── Username check ─────────────────────────────────────────────────────────
  if (username.trim() !== APP_ADMIN_USERNAME) {
    return res.status(401).json({
      success: false,
      message: "Invalid credentials.",
    });
  }

  // ── Retrieve OTP entry ─────────────────────────────────────────────────────
  const entry = otpStore.get(APP_ADMIN_USERNAME);

  if (!entry) {
    return res.status(400).json({
      success: false,
      message: "No active OTP found. Please log in again to request a new OTP.",
    });
  }

  // ── Expiry check ───────────────────────────────────────────────────────────
  if (Date.now() > entry.expiresAt) {
    otpStore.delete(APP_ADMIN_USERNAME);
    return res.status(400).json({
      success: false,
      message: "OTP has expired. Please log in again to request a new one.",
    });
  }

  // ── Rate-limit: too many wrong attempts ───────────────────────────────────
  if (entry.attempts >= MAX_OTP_ATTEMPTS) {
    otpStore.delete(APP_ADMIN_USERNAME);
    return res.status(429).json({
      success: false,
      message:
        "Too many incorrect OTP attempts. Please log in again to request a new OTP.",
    });
  }

  // ── OTP comparison ─────────────────────────────────────────────────────────
  if (entry.otp !== otp.trim()) {
    entry.attempts += 1;
    const remaining = MAX_OTP_ATTEMPTS - entry.attempts;
    return res.status(400).json({
      success: false,
      message: `Invalid OTP. ${remaining} attempt${remaining !== 1 ? "s" : ""} remaining.`,
    });
  }

  // ── OTP verified — delete immediately to prevent reuse ────────────────────
  otpStore.delete(APP_ADMIN_USERNAME);

  // ── Issue JWT ──────────────────────────────────────────────────────────────
  const payload = {
    type: "APP_ADMIN",
    username: APP_ADMIN_USERNAME,
    access: "FULL",
  };

  let token;
  try {
    token = jwt.sign(payload, JWT_SECRET, { expiresIn: "8h" });
  } catch (err) {
    console.error("[/app-admin/verify-otp] JWT sign error:", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }

  console.log(`[app-admin/verify-otp] App Admin authenticated successfully.`);

  return res.json({
    success: true,
    message: "App Admin authenticated successfully.",
    token,
    admin: {
      username: APP_ADMIN_USERNAME,
      email: APP_ADMIN_EMAIL,
      access: "FULL",
    },
  });
});

module.exports = router;
