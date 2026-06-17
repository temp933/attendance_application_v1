// middleware/app_admin_auth.js

"use strict";
const jwt = require("jsonwebtoken");
const db = require("../config/db");
const JWT_SECRET = process.env.JWT_SECRET;

module.exports = async (req, res, next) => {
  const authHeader = req.headers["authorization"];

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ success: false, message: "Unauthorized" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    if (decoded.userType !== "app_admin") {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    // SINGLE-DEVICE CHECK
    const [rows] = await db.query(
      `SELECT active_jti FROM app_admin_master
        WHERE admin_id = ? AND is_active = 1 LIMIT 1`,
      [decoded.adminId],
    );

    if (!rows.length || rows[0].active_jti !== decoded.jti) {
      return res.status(401).json({
        success: false,
        message: "Session superseded. Please log in again.",
      });
    }

    req.admin = { admin_id: decoded.adminId, username: decoded.username };
    return next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: "Invalid or expired session",
    });
  }
};
