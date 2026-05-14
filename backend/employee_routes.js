const express = require("express");
const router = express.Router();
const db = require("./config/db"); // adjust path if needed

const dbOne = async (sql, params = []) => {
  const [rows] = await db.query(sql, params);
  return rows[0] || null;
};

const dbAll = async (sql, params = []) => {
  const [rows] = await db.query(sql, params);
  return rows;
};

router.get("/:empId", async (req, res) => {
  try {
    const tenantId = req.headers["x-tenant-id"];
    const row = await dbOne(
      `SELECT e.*, d.department_name, r.role_name,
        TRIM(CONCAT(tl.first_name, ' ', IFNULL(tl.mid_name, ''), ' ', tl.last_name)) AS tl_name,
        DATE_FORMAT(e.date_of_birth,     '%Y-%m-%d') AS date_of_birth,
        DATE_FORMAT(e.date_of_joining,   '%Y-%m-%d') AS date_of_joining,
        DATE_FORMAT(e.date_of_relieving, '%Y-%m-%d') AS date_of_relieving
       FROM employee_master e
       LEFT JOIN department_master d ON e.department_id = d.department_id
       LEFT JOIN role_master r       ON e.role_id       = r.role_id
       LEFT JOIN employee_master tl  ON e.tl_id         = tl.emp_id
       WHERE e.emp_id = ? AND e.tenant_id = ?`,
      [req.params.empId, tenantId],
    );
    if (!row) return res.status(404).json({ error: "Employee not found" });
    res.json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/:empId/education", async (req, res) => {
  try {
    const tenantId = req.headers["x-tenant-id"];
    const rows = await dbAll(
      `SELECT edu.edu_id, edu.emp_id, edu.education_level, edu.stream, edu.score,
              edu.year_of_passout, edu.university, edu.college_name, edu.created_at
       FROM education_details edu
       INNER JOIN employee_master e ON e.emp_id = edu.emp_id
       WHERE edu.emp_id = ? AND e.tenant_id = ?
       ORDER BY FIELD(edu.education_level,'10','12','Diploma','UG','PG') ASC`,
      [req.params.empId, tenantId],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.get("/:empId/photo", async (req, res) => {
  try {
    const tenantId = req.headers["x-tenant-id"];
    const row = await dbOne(
      `SELECT profile_photo, profile_photo_mime 
       FROM employee_master 
       WHERE emp_id = ? AND tenant_id = ?`,
      [req.params.empId, tenantId],
    );
    if (!row || !row.profile_photo)
      return res
        .status(404)
        .json({ success: false, message: "No photo found" });
    res.set("Content-Type", row.profile_photo_mime || "image/jpeg");
    res.send(row.profile_photo);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
