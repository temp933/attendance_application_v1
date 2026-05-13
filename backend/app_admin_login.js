// backend/app_admin_login.js

const express = require("express");
const router = express.Router();
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
require("dotenv").config();

// ── In-memory OTP store ───────────────────────────────────────────────────────
const otpStore = new Map();

const APP_ADMIN_USERNAME = process.env.APP_ADMIN_USERNAME;
const APP_ADMIN_PASSWORD_HASH = process.env.APP_ADMIN_PASSWORD_HASH;
const APP_ADMIN_EMAIL = process.env.APP_ADMIN_EMAIL;
const JWT_SECRET = process.env.JWT_SECRET;

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const MAX_OTP_ATTEMPTS = 5;

// ── Mailer — uses same SMTP vars as server.js ─────────────────────────────────
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

// ── Helpers ───────────────────────────────────────────────────────────────────
function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

function generateSessionId() {
  return crypto.randomBytes(24).toString("hex");
}

async function sendOtpEmail(email, otp) {
  await transporter.sendMail({
    from: `" App Admin" <${process.env.SMTP_USER}>`,
    to: email,
    subject: "Your App Admin Login OTP",
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px;
                  border:1px solid #e0e7ff;border-radius:12px;">
        <h2 style="color:#4F46E5;margin-bottom:8px;">App Admin Login</h2>
        <p style="color:#6B7280;margin-bottom:24px;">
          Use the OTP below to complete your login. It expires in <strong>5 minutes</strong>.
        </p>
        <div style="background:#EEF2FF;border-radius:10px;padding:20px;
                    text-align:center;font-size:36px;font-weight:800;
                    letter-spacing:14px;color:#1E1B4B;">
          ${otp}
        </div>
        <p style="color:#9CA3AF;font-size:12px;margin-top:20px;">
          If you did not request this, please ignore this email.
        </p>
      </div>
    `,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/app-admin/login
// Body: { username, password }
// ─────────────────────────────────────────────────────────────────────────────
router.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res
        .status(400)
        .json({ message: "Username and password are required." });
    }

    // Guard: catch missing env vars early with a clear server log
    if (!APP_ADMIN_USERNAME || !APP_ADMIN_PASSWORD_HASH || !APP_ADMIN_EMAIL) {
      console.error(
        "[app_admin/login] Missing env vars: APP_ADMIN_USERNAME / APP_ADMIN_PASSWORD_HASH / APP_ADMIN_EMAIL",
      );
      return res
        .status(500)
        .json({ message: "Server misconfiguration. Contact administrator." });
    }

    if (username !== APP_ADMIN_USERNAME) {
      return res
        .status(401)
        .json({ message: "Invalid credentials. Please try again." });
    }

    const passwordMatch = await bcrypt.compare(
      password,
      APP_ADMIN_PASSWORD_HASH,
    );
    if (!passwordMatch) {
      return res
        .status(401)
        .json({ message: "Invalid credentials. Please try again." });
    }

    const otp = generateOtp();
    const sessionId = generateSessionId();

    otpStore.set(sessionId, {
      otp,
      expiresAt: Date.now() + OTP_TTL_MS,
      attempts: 0,
    });

    setTimeout(() => otpStore.delete(sessionId), OTP_TTL_MS + 5000);

    await sendOtpEmail(APP_ADMIN_EMAIL, otp);

    const [localPart, domain] = APP_ADMIN_EMAIL.split("@");
    const emailHint = localPart.slice(0, 2) + "***@" + domain;

    return res.status(200).json({
      session_id: sessionId,
      message: "OTP sent successfully.",
      email_hint: emailHint,
    });
  } catch (err) {
    console.error("[app_admin/login] Error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error. Please try again." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/app-admin/verify
// Body: { session_id, otp }
// ─────────────────────────────────────────────────────────────────────────────
router.post("/verify", async (req, res) => {
  try {
    const { session_id, otp } = req.body;

    if (!session_id || !otp) {
      return res
        .status(400)
        .json({ message: "Session ID and OTP are required." });
    }

    const record = otpStore.get(session_id);

    if (!record) {
      return res.status(400).json({
        message:
          "Session expired or invalid. Please start the login process again.",
      });
    }

    if (Date.now() > record.expiresAt) {
      otpStore.delete(session_id);
      return res
        .status(400)
        .json({ message: "OTP has expired. Please request a new one." });
    }

    record.attempts += 1;
    if (record.attempts > MAX_OTP_ATTEMPTS) {
      otpStore.delete(session_id);
      return res.status(429).json({
        message:
          "Too many failed attempts. Please start the login process again.",
      });
    }

    // Constant-time comparison
    const otpBuffer = Buffer.from(otp.padEnd(6));
    const storedBuffer = Buffer.from(record.otp.padEnd(6));
    const match =
      otpBuffer.length === storedBuffer.length &&
      crypto.timingSafeEqual(otpBuffer, storedBuffer);

    if (!match) {
      const remaining = MAX_OTP_ATTEMPTS - record.attempts;
      return res.status(401).json({
        message: `Invalid OTP. ${remaining} attempt${remaining !== 1 ? "s" : ""} remaining.`,
      });
    }

    otpStore.delete(session_id);

    if (!JWT_SECRET) {
      console.error("[app_admin/verify] JWT_SECRET is not set in .env");
      return res
        .status(500)
        .json({ message: "Server misconfiguration. Contact administrator." });
    }

    const payload = {
      loginId: 0,
      empId: 0,
      roleId: 6,
      userType: "app_admin",
      tenantId: "global",
    };

    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: "8h" });

    return res.status(200).json({
      token,
      loginId: payload.loginId,
      empId: payload.empId,
      roleId: payload.roleId,
      userType: payload.userType,
      tenantId: payload.tenantId,
      message: "Login successful.",
    });
  } catch (err) {
    console.error("[app_admin/verify] Error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error. Please try again." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/app-admin/resend
// Body: { session_id }
// ─────────────────────────────────────────────────────────────────────────────
router.post("/resend", async (req, res) => {
  try {
    const { session_id } = req.body;

    if (session_id) otpStore.delete(session_id);

    const otp = generateOtp();
    const newSessionId = generateSessionId();

    otpStore.set(newSessionId, {
      otp,
      expiresAt: Date.now() + OTP_TTL_MS,
      attempts: 0,
    });

    setTimeout(() => otpStore.delete(newSessionId), OTP_TTL_MS + 5000);

    await sendOtpEmail(APP_ADMIN_EMAIL, otp);

    const [localPart, domain] = APP_ADMIN_EMAIL.split("@");
    const emailHint = localPart.slice(0, 2) + "***@" + domain;

    return res.status(200).json({
      session_id: newSessionId,
      message: "New OTP sent.",
      email_hint: emailHint,
    });
  } catch (err) {
    console.error("[app_admin/resend] Error:", err);
    return res.status(500).json({ message: "Failed to resend OTP." });
  }
});

module.exports = router;
