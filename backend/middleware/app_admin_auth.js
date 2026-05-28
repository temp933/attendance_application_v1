"use strict";
const jwt = require("jsonwebtoken");
const JWT_SECRET = process.env.JWT_SECRET;

module.exports = (req, res, next) => {
  console.log("=== APP ADMIN AUTH ===");
  console.log("Headers:", JSON.stringify(req.headers));

  const authHeader = req.headers["authorization"];

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    console.log("❌ No Bearer header");
    return res.status(401).json({ success: false, message: "Unauthorized" });
  }

  const token = authHeader.split(" ")[1];
  console.log("Token preview:", token?.substring(0, 30));
  console.log("JWT_SECRET exists:", !!JWT_SECRET);

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    console.log("✅ JWT decoded:", decoded);

    if (decoded.userType !== "app_admin") {
      console.log("❌ userType is:", decoded.userType);
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    req.admin = { admin_id: decoded.adminId, username: decoded.username };
    return next();
  } catch (err) {
    console.log("❌ JWT error:", err.message);
    return res.status(401).json({
      success: false,
      message: "Invalid or expired session",
    });
  }
};
