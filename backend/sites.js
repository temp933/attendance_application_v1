const express = require("express");
const router = express.Router();

const db = require("./config/db");
const authMiddleware = require("./middleware/auth");

router.use(authMiddleware);

// GET /api/sites
router.get("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  try {
    const [rows] = await db.query(
      `SELECT id, site_name, polygon_json,
          DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
          DATE_FORMAT(end_date,   '%Y-%m-%d') AS end_date,
          created_at
       FROM sites
       WHERE tenant_id = ?
       ORDER BY created_at DESC`,
      [tenant_id],
    );
    res.json(rows);
  } catch (err) {
    console.error("[GET /sites]", err);
    res.status(500).json({ message: "Database error" });
  }
});

// GET /api/sites/on-site-today
router.get("/on-site-today", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  try {
    const today = new Date().toISOString().split("T")[0];
    const [rows] = await db.query(
      `SELECT COUNT(*) AS count FROM sites
       WHERE tenant_id = ? AND start_date <= ? AND end_date >= ?`,
      [tenant_id, today, today],
    );
    res.json({ onSiteToday: rows[0].count });
  } catch (err) {
    console.error("[GET /sites/on-site-today]", err);
    res.status(500).json({ message: "Database error" });
  }
});

// GET /api/sites/:id/location
router.get("/:id/location", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  try {
    const [[site]] = await db.query(
      `SELECT id, site_name, polygon_json FROM sites WHERE id = ? AND tenant_id = ?`,
      [req.params.id, tenant_id],
    );
    if (!site)
      return res
        .status(404)
        .json({ success: false, message: "Site not found" });

    let lat = null,
      lng = null;
    if (site.polygon_json) {
      try {
        const polygon = JSON.parse(site.polygon_json);
        if (Array.isArray(polygon) && polygon.length > 0) {
          let sumLat = 0,
            sumLng = 0;
          polygon.forEach((p) => {
            sumLat += p.lat;
            sumLng += p.lng;
          });
          lat = sumLat / polygon.length;
          lng = sumLng / polygon.length;
        }
      } catch (parseErr) {
        console.error("[site-location] polygon parse error:", parseErr);
      }
    }

    res.json({
      success: true,
      site_id: site.id,
      site_name: site.site_name,
      lat,
      lng,
    });
  } catch (err) {
    console.error("[GET /sites/:id/location]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/sites
// POST /api/sites
router.post("/", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const { site_name, polygon_json, start_date, end_date } = req.body;
  if (!site_name || !polygon_json || !start_date || !end_date)
    return res.status(400).json({ message: "Missing required fields" });
  try {
    const [result] = await db.query(
      `INSERT INTO sites (tenant_id, site_name, polygon_json, start_date, end_date)
       VALUES (?, ?, ?, ?, ?)`,
      [
        tenant_id,
        site_name,
        JSON.stringify(polygon_json),
        start_date,
        end_date,
      ],
    );
    res.json({ message: "Site saved", id: result.insertId });
  } catch (err) {
    console.error("[POST /sites]", err);
    if (err.code === "ER_DUP_ENTRY")
      return res.status(409).json({ message: "Site name already exists" });
    res.status(500).json({ message: "Database error" });
  }
});

// PUT /api/sites/:id
router.put("/:id", async (req, res) => {
  const tenant_id = req.user.tenant_id;
  const { site_name, polygon_json, start_date, end_date } = req.body;
  if (!site_name || !polygon_json || !start_date || !end_date)
    return res.status(400).json({ message: "Missing required fields" });
  try {
    const [result] = await db.query(
      `UPDATE sites SET site_name=?, polygon_json=?, start_date=?, end_date=?
       WHERE id=? AND tenant_id=?`,
      [
        site_name,
        JSON.stringify(polygon_json),
        start_date,
        end_date,
        req.params.id,
        tenant_id,
      ],
    );
    if (result.affectedRows === 0)
      return res.status(404).json({ message: "Site not found" });
    res.json({ message: "Site updated" });
  } catch (err) {
    console.error("[PUT /sites/:id]", err);
    if (err.code === "ER_DUP_ENTRY")
      return res.status(409).json({ message: "Site name already exists" });
    res.status(500).json({ message: "Database error" });
  }
});

module.exports = router;
