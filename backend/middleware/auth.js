const crypto = require("crypto");
const db = require("../config/db");

function hashToken(rawToken) {
  return crypto.createHash("sha256").update(rawToken).digest("hex");
}

module.exports = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "No token provided",
      });
    }

    const rawToken = authHeader.split(" ")[1];

    const hashedToken = hashToken(rawToken);

    const [rows] = await db.query(
      `
      SELECT
        login_id,
        emp_id,
        role_id,
        tenant_id,
        username,
        device_logged_in
      FROM login_master
      WHERE session_token = ?
      LIMIT 1
      `,
      [hashedToken],
    );

    if (!rows.length) {
      return res.status(401).json({
        success: false,
        message: "Invalid session",
      });
    }

    const user = rows[0];

    if (user.device_logged_in !== 1) {
      return res.status(401).json({
        success: false,
        message: "Session expired",
      });
    }

    req.user = {
      login_id: user.login_id,
      emp_id: user.emp_id,
      role_id: user.role_id,
      tenant_id: user.tenant_id,
      username: user.username,
    };

    console.log("AUTH USER:", req.user);

    next();
  } catch (err) {
    console.error("AUTH ERROR:", err);

    return res.status(500).json({
      success: false,
      message: "Authentication failed",
    });
  }
};
