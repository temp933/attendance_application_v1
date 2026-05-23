const express = require("express");
const router = express.Router();
const db = require("./config/db"); // adjust path if needed
const authMiddleware = require("./middleware/auth");

// ─────────────────────────────────────────────────────────────────────────────
// Auth + admin guard
// ─────────────────────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  authMiddleware(req, res, () => {
    if (!req.user)
      return res.status(401).json({ success: false, message: "Unauthorized." });
    req.user.tenantId = req.user.tenant_id ?? req.headers["x-tenant-id"];
    req.user.empId = req.user.emp_id ?? req.headers["x-employee-id"];
    next();
  });
}

function requireAdmin(req, res, next) {
  // role_id 1 = admin, 2 = HR, 3 = TL — adjust to match your system
  if (!req.user || ![1, 2, 3].includes(Number(req.user.role_id))) {
    return res.status(403).json({ success: false, message: "Forbidden." });
  }
  next();
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Parse session_device JSON safely */
function parseDevice(raw) {
  if (!raw) return null;
  try {
    const d = typeof raw === "string" ? JSON.parse(raw) : raw;
    // Prefer a human-readable label built from the device info object
    // Common fields sent by Flutter: deviceName, model, brand, deviceId
    return (
      d.deviceName || d.model || d.brand || d.deviceId || JSON.stringify(d)
    );
  } catch {
    return String(raw);
  }
}

/** Map role_id → friendly role name */
function roleName(roleId) {
  const map = {
    1: "Admin",
    2: "HR",
    3: "Team Lead",
    4: "Employee",
  };
  return map[roleId] || `Role ${roleId}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /admin/sessions
// Returns every login_master row for the tenant, joined with employee name.
// ─────────────────────────────────────────────────────────────────────────────
router.get("/sessions", requireAuth, requireAdmin, async (req, res) => {
  const { tenantId } = req.user;

  try {
    const [rows] = await db.query(
      `SELECT
      lm.login_id,
      lm.emp_id,
      lm.username,
      lm.role_id,
      lm.status,
      lm.device_logged_in,
      lm.session_device,
      lm.last_login_at,
      lm.session_expires_at,
      lm.failed_attempts,
      lm.locked_until,
      lm.force_logout,
      COALESCE(rm.role_name, CONCAT('Role ', lm.role_id)) AS role_name,
      COALESCE(dm.department_name, 'No Department')       AS department_name,
      COALESCE(
        CONCAT_WS(' ',
          NULLIF(em.first_name, ''),
          NULLIF(em.mid_name, ''),
          NULLIF(em.last_name, '')
        ),
        lm.username
      ) AS full_name
   FROM login_master lm
   LEFT JOIN employee_master em
          ON em.emp_id    = lm.emp_id
         AND CONVERT(em.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
           = CONVERT(lm.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
   LEFT JOIN role_master rm
          ON rm.role_id   = lm.role_id
         AND CONVERT(rm.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
           = CONVERT(lm.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
   LEFT JOIN department_master dm
          ON dm.department_id = em.department_id
         AND CONVERT(dm.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
           = CONVERT(lm.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
   WHERE CONVERT(lm.tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
   ORDER BY lm.device_logged_in DESC, lm.last_login_at DESC`,
      [tenantId],
    );

    const data = rows.map((r) => ({
      loginId: r.login_id,
      empId: r.emp_id ?? null,
      username: r.username,
      fullName: (r.full_name || r.username).trim(),
      roleName: r.role_name, // ← from JOIN, not the helper function
      departmentName: r.department_name,
      roleId: r.role_id,
      accountStatus: r.status, // 'Active' | 'Inactive'
      isAccountLocked: r.status === "Inactive", // admin-locked account
      isLoggedIn: r.device_logged_in === 1,
      sessionDevice: parseDevice(r.session_device),
      lastLoginAt: r.last_login_at ? r.last_login_at.toISOString() : null,
      sessionExpiresAt: r.session_expires_at
        ? r.session_expires_at.toISOString()
        : null,
      failedAttempts: r.failed_attempts ?? 0,
      isLocked: r.locked_until ? new Date(r.locked_until) > new Date() : false,
      lockedUntil: r.locked_until ? r.locked_until.toISOString() : null,
      forceLogout: r.force_logout === 1,
    }));

    return res.json({ success: true, data });
  } catch (err) {
    console.error("[GET /admin/sessions]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/sessions/:loginId/force-logout
// Clears the session token + marks force_logout = 1 so the device detects it.
// Also closes any active attendance session for the employee.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/sessions/:loginId/force-logout",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    const { tenantId } = req.user;
    const loginId = parseInt(req.params.loginId, 10);

    if (!loginId || isNaN(loginId)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid loginId." });
    }

    try {
      // Verify the target login belongs to this tenant
      const [[target]] = await db.query(
        `SELECT login_id, emp_id, device_logged_in
         FROM login_master
         WHERE login_id  = ?
           AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
         LIMIT 1`,
        [loginId, tenantId],
      );

      if (!target) {
        return res
          .status(404)
          .json({ success: false, message: "Session not found." });
      }

      // ── 1. Clear session ────────────────────────────────────────────────────
      await db.query(
        `UPDATE login_master
         SET session_token    = NULL,
             device_logged_in = 0,
             session_device   = NULL,
             force_logout     = 1
         WHERE login_id = ?`,
        [loginId],
      );

      // ── 2. Close any active attendance sessions (non-fatal) ─────────────────
      if (target.emp_id) {
        try {
          await db.query(
            `UPDATE employee_attendance
             SET checkout_time = NOW(),
                 status        = 'completed'
             WHERE employee_id = ?
               AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
               AND status      = 'active'`,
            [target.emp_id, tenantId],
          );
        } catch (attErr) {
          console.warn(
            "[force-logout] attendance close warning:",
            attErr.message,
          );
        }
      }

      return res.json({
        success: true,
        message: "Session terminated and attendance closed.",
      });
    } catch (err) {
      console.error("[POST /admin/sessions/:loginId/force-logout]", err);
      return res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/sessions/force-logout-all/:empId
// Revoke every session tied to an employee (multi-device scenario).
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/sessions/force-logout-all/:empId",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    const { tenantId } = req.user;
    const empId = req.params.empId;

    if (!empId) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid empId." });
    }

    try {
      const [result] = await db.query(
        `UPDATE login_master
         SET session_token    = NULL,
             device_logged_in = 0,
             session_device   = NULL,
             force_logout     = 1
         WHERE emp_id = ?
           AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?`,
        [empId, tenantId],
      );

      // Close attendance
      try {
        await db.query(
          `UPDATE employee_attendance
           SET checkout_time = NOW(),
               status        = 'completed'
           WHERE employee_id = ?
             AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
             AND status      = 'active'`,
          [empId, tenantId],
        );
      } catch (attErr) {
        console.warn(
          "[force-logout-all] attendance close warning:",
          attErr.message,
        );
      }

      return res.json({
        success: true,
        message: `${result.affectedRows} session(s) terminated.`,
        affected: result.affectedRows,
      });
    } catch (err) {
      console.error("[POST /admin/sessions/force-logout-all/:empId]", err);
      return res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/sessions/:loginId/unlock
// Clears brute-force lock (failed_attempts + locked_until).
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/sessions/:loginId/unlock",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    const { tenantId } = req.user;
    const loginId = parseInt(req.params.loginId, 10);

    try {
      const [result] = await db.query(
        `UPDATE login_master
         SET failed_attempts = 0,
             locked_until    = NULL
         WHERE login_id = ?
           AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?`,
        [loginId, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "User not found." });
      }

      return res.json({ success: true, message: "Account unlocked." });
    } catch (err) {
      console.error("[POST /admin/sessions/:loginId/unlock]", err);
      return res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/sessions/:loginId/lock-account
// Permanently disables account: status = 'Inactive', force-logouts session,
// closes active attendance. No ALTER needed — status enum already has 'Inactive'.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/sessions/:loginId/lock-account",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    const { tenantId } = req.user;
    const loginId = parseInt(req.params.loginId, 10);

    if (!loginId || isNaN(loginId)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid loginId." });
    }

    try {
      const [[target]] = await db.query(
        `SELECT login_id, emp_id, status
         FROM login_master
         WHERE login_id = ?
           AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
         LIMIT 1`,
        [loginId, tenantId],
      );

      if (!target) {
        return res
          .status(404)
          .json({ success: false, message: "User not found." });
      }

      if (target.status === "Inactive") {
        return res
          .status(409)
          .json({ success: false, message: "Account is already locked." });
      }

      // Lock account + clear session
      await db.query(
        `UPDATE login_master
         SET status           = 'Inactive',
             session_token    = NULL,
             device_logged_in = 0,
             session_device   = NULL,
             force_logout     = 1
         WHERE login_id = ?`,
        [loginId],
      );

      // Close active attendance (non-fatal)
      if (target.emp_id) {
        try {
          await db.query(
            `UPDATE employee_attendance
             SET checkout_time = NOW(),
                 status        = 'completed'
             WHERE employee_id = ?
               AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?
               AND status      = 'active'`,
            [target.emp_id, tenantId],
          );
        } catch (attErr) {
          console.warn(
            "[lock-account] attendance close warning:",
            attErr.message,
          );
        }
      }

      return res.json({
        success: true,
        message: "Account locked and session terminated.",
      });
    } catch (err) {
      console.error("[POST /admin/sessions/:loginId/lock-account]", err);
      return res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /admin/sessions/:loginId/unlock-account
// Re-enables an admin-locked account: status = 'Active', clears brute-force too.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  "/sessions/:loginId/unlock-account",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    const { tenantId } = req.user;
    const loginId = parseInt(req.params.loginId, 10);

    if (!loginId || isNaN(loginId)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid loginId." });
    }

    try {
      const [result] = await db.query(
        `UPDATE login_master
         SET status          = 'Active',
             failed_attempts = 0,
             locked_until    = NULL,
             force_logout    = 0
         WHERE login_id = ?
           AND CONVERT(tenant_id USING utf8mb4) COLLATE utf8mb4_0900_ai_ci = ?`,
        [loginId, tenantId],
      );

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "User not found." });
      }

      return res.json({
        success: true,
        message: "Account re-enabled successfully.",
      });
    } catch (err) {
      console.error("[POST /admin/sessions/:loginId/unlock-account]", err);
      return res.status(500).json({ success: false, message: "Server error." });
    }
  },
);

module.exports = router;
