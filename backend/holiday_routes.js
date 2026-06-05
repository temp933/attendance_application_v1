// holiday_routes.js
require("dotenv").config();

const express = require("express");
const router = express.Router();
const db = require("./config/db");

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/holidays?year=2026
// ─────────────────────────────────────────────────────────────────────────────
router.get("/", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const { year } = req.query;

  if (!tenant_id) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  }

  try {
    let query = `
  SELECT
    holiday_id, tenant_id, holiday_name,
    DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date,
    holiday_type, description, is_recurring,
    created_by, created_at, updated_at
  FROM holiday_master
  WHERE (tenant_id = ? OR tenant_id = 'global')
`;
    const params = [tenant_id];

    if (year) {
      query += ` AND YEAR(holiday_date) = ?`;
      params.push(year);
    }

    query += ` ORDER BY holiday_date ASC`;

    const [rows] = await db.query(query, params);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error("[GET /holidays]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

router.post("/defaults", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const year = parseInt(req.query.year, 10) || new Date().getFullYear();
  const login_id = req.body?.login_id ?? null;

  if (!tenant_id) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  }

  try {
    // ✅ Use DATE_FORMAT to always get 'MM-DD' as a plain string
    const [defaults] = await db.query(`
      SELECT 
        holiday_name,
        DATE_FORMAT(holiday_date, '%m-%d') AS holiday_date,
        holiday_type, 
        description, 
        is_recurring
      FROM default_holiday_master
      ORDER BY holiday_date ASC
    `);

    let inserted = 0;
    let skipped = 0;

    for (const h of defaults) {
      const fullDate = `${year}-${h.holiday_date}`; // e.g. "2026-01-26" ✅

      const [exists] = await db.query(
        `SELECT holiday_id FROM holiday_master
         WHERE tenant_id = ? AND holiday_name = ? AND holiday_date = ?
         LIMIT 1`,
        [tenant_id, h.holiday_name, fullDate],
      );

      if (exists.length > 0) {
        skipped++;
        continue;
      }

      await db.query(
        `INSERT INTO holiday_master
           (tenant_id, holiday_name, holiday_date, holiday_type, description, is_recurring, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          tenant_id,
          h.holiday_name,
          fullDate,
          h.holiday_type,
          h.description || null,
          h.is_recurring ? 1 : 0,
          login_id,
        ],
      );
      inserted++;
    }

    return res.json({
      success: true,
      message: `${inserted} holiday${inserted !== 1 ? "s" : ""} added, ${skipped} skipped.`,
      inserted,
      skipped,
    });
  } catch (err) {
    console.error("[POST /holidays/defaults]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/holidays
// Add a single holiday
// ─────────────────────────────────────────────────────────────────────────────
router.post("/", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const {
    holiday_name,
    holiday_date,
    holiday_type,
    description,
    is_recurring,
    login_id,
  } = req.body;

  if (!tenant_id) {
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  }
  if (!holiday_name?.trim()) {
    return res
      .status(400)
      .json({ success: false, message: "holiday_name is required." });
  }
  if (!holiday_date) {
    return res
      .status(400)
      .json({ success: false, message: "holiday_date is required." });
  }

  try {
    const [existing] = await db.query(
      `SELECT holiday_id FROM holiday_master
       WHERE tenant_id = ? AND holiday_name = ? AND holiday_date = ?
       LIMIT 1`,
      [tenant_id, holiday_name.trim(), holiday_date],
    );
    if (existing.length > 0) {
      return res
        .status(409)
        .json({ success: false, message: "Holiday already exists." });
    }

    const [result] = await db.query(
      `INSERT INTO holiday_master
         (tenant_id, holiday_name, holiday_date, holiday_type, description, is_recurring, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        tenant_id,
        holiday_name.trim(),
        holiday_date,
        holiday_type || "National",
        description || null,
        is_recurring ? 1 : 0,
        login_id || null,
      ],
    );

    return res.status(201).json({
      success: true,
      message: "Holiday created.",
      data: { holiday_id: result.insertId },
    });
  } catch (err) {
    console.error("[POST /holidays]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/holidays/:id
// Update a holiday
// ─────────────────────────────────────────────────────────────────────────────
router.put("/:id", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const holidayId = parseInt(req.params.id, 10);
  const {
    holiday_name,
    holiday_date,
    holiday_type,
    description,
    is_recurring,
  } = req.body;

  if (!tenant_id)
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  if (isNaN(holidayId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid holiday id." });

  try {
    const [[holiday]] = await db.query(
      `SELECT holiday_id FROM holiday_master WHERE holiday_id = ? AND tenant_id = ? LIMIT 1`,
      [holidayId, tenant_id],
    );
    if (!holiday)
      return res
        .status(404)
        .json({ success: false, message: "Holiday not found." });

    const [duplicate] = await db.query(
      `SELECT holiday_id FROM holiday_master
       WHERE tenant_id = ? AND holiday_name = ? AND holiday_date = ? AND holiday_id != ?
       LIMIT 1`,
      [tenant_id, holiday_name.trim(), holiday_date, holidayId],
    );
    if (duplicate.length > 0) {
      return res.status(409).json({
        success: false,
        message: "Another holiday already exists on that date.",
      });
    }

    await db.query(
      `UPDATE holiday_master
       SET holiday_name = ?, holiday_date = ?, holiday_type = ?,
           description  = ?, is_recurring = ?
       WHERE holiday_id = ? AND tenant_id = ?`,
      [
        holiday_name.trim(),
        holiday_date,
        holiday_type,
        description || null,
        is_recurring ? 1 : 0,
        holidayId,
        tenant_id,
      ],
    );

    return res.json({ success: true, message: "Holiday updated." });
  } catch (err) {
    console.error("[PUT /holidays/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/holidays/:id
// ─────────────────────────────────────────────────────────────────────────────
router.delete("/:id", async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const holidayId = parseInt(req.params.id, 10);

  if (!tenant_id)
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  if (isNaN(holidayId))
    return res
      .status(400)
      .json({ success: false, message: "Invalid holiday id." });

  try {
    const [[holiday]] = await db.query(
      `SELECT holiday_id FROM holiday_master WHERE holiday_id = ? AND tenant_id = ? LIMIT 1`,
      [holidayId, tenant_id],
    );
    if (!holiday)
      return res
        .status(404)
        .json({ success: false, message: "Holiday not found." });

    await db.query(
      `DELETE FROM holiday_master WHERE holiday_id = ? AND tenant_id = ?`,
      [holidayId, tenant_id],
    );

    return res.json({ success: true, message: "Holiday deleted." });
  } catch (err) {
    console.error("[DELETE /holidays/:id]", err);
    return res.status(500).json({ success: false, message: "Server error." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/holidays/import-excel
// Accepts multipart/form-data with field "file" (xlsx/xls/csv)
// ─────────────────────────────────────────────────────────────────────────────
const multer = require("multer");
const XLSX = require("xlsx");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});

const MONTH_MAP = {
  jan: "01",
  feb: "02",
  mar: "03",
  apr: "04",
  may: "05",
  jun: "06",
  jul: "07",
  aug: "08",
  sep: "09",
  oct: "10",
  nov: "11",
  dec: "12",
};

function parseExcelDate(raw) {
  // Case 1: XLSX already parsed it as a JS Date object
  if (raw instanceof Date) {
    const y = raw.getFullYear();
    const m = String(raw.getMonth() + 1).padStart(2, "0");
    const d = String(raw.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }

  const s = String(raw).trim();

  // Case 2: YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;

  // Case 3: YYYY/MM/DD or YYYY.MM.DD
  if (/^\d{4}[\/\.]\d{2}[\/\.]\d{2}$/.test(s)) {
    const [y, m, d] = s.split(/[\/\.]/);
    return `${y}-${m.padStart(2, "0")}-${d.padStart(2, "0")}`;
  }

  // Case 4: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
  if (/^\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{4}$/.test(s)) {
    const parts = s.split(/[\/\-\.]/);
    return `${parts[2]}-${parts[1].padStart(2, "0")}-${parts[0].padStart(2, "0")}`;
  }

  // Case 5: YYYY/Mon/DD or YYYY-Mon-DD (e.g. 2026/May/05)
  const monthWord = /^(\d{4})[\/\-\.]([a-zA-Z]{3,9})[\/\-\.](\d{1,2})$/.exec(s);
  if (monthWord) {
    const mo = MONTH_MAP[monthWord[2].toLowerCase().slice(0, 3)];
    if (mo) return `${monthWord[1]}-${mo}-${monthWord[3].padStart(2, "0")}`;
  }

  // Case 6: Excel serial number (number stored as string, e.g. "46000")
  if (/^\d{5}$/.test(s)) {
    const serial = parseInt(s, 10);
    const date = new Date((serial - 25569) * 86400 * 1000);
    const y = date.getUTCFullYear();
    const m = String(date.getUTCMonth() + 1).padStart(2, "0");
    const d = String(date.getUTCDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }

  return null; // unrecognised
}

router.post("/import-excel", upload.single("file"), async (req, res) => {
  const tenant_id = req.headers["x-tenant-id"];
  const login_id = req.body?.login_id ?? null;

  if (!tenant_id)
    return res
      .status(400)
      .json({ success: false, message: "tenant_id required." });
  if (!req.file)
    return res
      .status(400)
      .json({ success: false, message: "No file uploaded." });

  const t0 = Date.now();
  console.log(
    `[import-excel] START tenant=${tenant_id} file=${req.file.originalname} size=${req.file.size}b`,
  );

  try {
    const workbook = XLSX.read(req.file.buffer, {
      type: "buffer",
      cellDates: true,
    });
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const raw = XLSX.utils.sheet_to_json(sheet, { defval: "" });

    if (!raw.length)
      return res
        .status(400)
        .json({ success: false, message: "File is empty." });

    console.log(
      `[import-excel] Parsed ${raw.length} rows in ${Date.now() - t0}ms`,
    );

    const validTypes = ["Public", "National", "Optional", "Office"];
    const results = { inserted: 0, skipped: 0, errors: [] };

    // ── Normalise column name lookup ────────────────────────────────────────
    const get = (row, keys) => {
      const rowKeys = Object.keys(row);
      // 1. Exact match (case-insensitive, trimmed)
      for (const k of keys) {
        const found = rowKeys.find(
          (rk) => rk.trim().toLowerCase() === k.toLowerCase(),
        );
        if (found !== undefined) return String(row[found]).trim();
      }
      // 2. Partial match — header contains or is contained by any key
      for (const k of keys) {
        const found = rowKeys.find((rk) => {
          const rk2 = rk.trim().toLowerCase();
          const k2 = k.toLowerCase();
          return rk2.includes(k2) || k2.includes(rk2);
        });
        if (found !== undefined) return String(row[found]).trim();
      }
      return "";
    };

    // ── Step 1: Parse all rows, collect valid ones ──────────────────────────
    const toInsert = []; // { name, dateStr, type, desc }

    for (let i = 0; i < raw.length; i++) {
      const row = raw[i];
      const rowNum = i + 2;

      const name = get(row, ["holiday name", "holiday_name", "name"]);
      const dateRaw = get(row, ["date", "holiday_date", "holiday date"]);
      const typeRaw = get(row, ["holiday type", "holiday_type", "type"]);
      const desc = get(row, [
        "about the holiday (optional)",
        "about the holiday",
        "description",
        "about",
        "desc",
      ]);

      if (!name) {
        results.errors.push({
          row: rowNum,
          error: "Holiday name is required.",
        });
        continue;
      }

      // Use raw Date object from XLSX if available (cellDates: true)
      const rawCell =
        raw[i][
          Object.keys(raw[i]).find((k) => k.trim().toLowerCase() === "date")
        ] ?? dateRaw;
      const dateStr = parseExcelDate(
        rawCell instanceof Date ? rawCell : dateRaw,
      );

      if (!dateStr || isNaN(new Date(dateStr).getTime())) {
        results.errors.push({
          row: rowNum,
          error: `Unrecognised date format: "${dateRaw}". Supported: DD/MM/YYYY, YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD, YYYY/Mon/DD`,
        });
        continue;
      }

      const typeNorm =
        validTypes.find((t) => t.toLowerCase() === typeRaw.toLowerCase()) ||
        "Public";

      toInsert.push({
        rowNum,
        name,
        dateStr,
        type: typeNorm,
        desc: desc || null,
      });
    }

    console.log(
      `[import-excel] Valid rows: ${toInsert.length}, errors so far: ${results.errors.length}`,
    );

    // ── Step 2: Bulk-fetch existing to detect duplicates in one query ───────
    const safeToInsert = toInsert.filter((r) => r.name && r.dateStr);
    const skippedEmpty = toInsert.length - safeToInsert.length;
    results.skipped += skippedEmpty;
    if (skippedEmpty > 0) {
      console.log(
        `[import-excel] Dropped ${skippedEmpty} rows with empty name/date after parsing`,
      );
    }

    if (safeToInsert.length > 0) {
      const placeholders = safeToInsert.map(() => "(?, ?)").join(", ");
      const flatParams = safeToInsert.flatMap((r) => [r.name, r.dateStr]);

      const [existing] = await db.query(
        `SELECT holiday_name, DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date
         FROM holiday_master
         WHERE tenant_id = ?
           AND (holiday_name, holiday_date) IN (${placeholders})`,
        [tenant_id, ...flatParams],
      );
      const existingSet = new Set(
        existing.map((e) => `${e.holiday_name}||${e.holiday_date}`),
      );
      console.log(
        `[import-excel] Duplicate check done: ${existing.length} already exist`,
      );

      const newRows = [];
      for (const r of safeToInsert) {
        if (existingSet.has(`${r.name}||${r.dateStr}`)) {
          results.skipped++;
        } else {
          newRows.push(r);
        }
      }

      // ── Step 3: Single batch INSERT ───────────────────────────────────────
      if (newRows.length > 0) {
        const insertPlaceholders = newRows
          .map(() => "(?, ?, ?, ?, ?, 0, ?)")
          .join(", ");
        const insertParams = newRows.flatMap((r) => [
          tenant_id,
          r.name,
          r.dateStr,
          r.type,
          r.desc,
          login_id,
        ]);

        await db.query(
          `INSERT INTO holiday_master
             (tenant_id, holiday_name, holiday_date, holiday_type, description, is_recurring, created_by)
           VALUES ${insertPlaceholders}`,
          insertParams,
        );

        results.inserted = newRows.length;
        console.log(`[import-excel] Inserted ${results.inserted} rows`);
      }
    }

    const elapsed = Date.now() - t0;
    console.log(
      `[import-excel] DONE in ${elapsed}ms — inserted=${results.inserted} skipped=${results.skipped} errors=${results.errors.length}`,
    );

    return res.json({
      success: true,
      message: `${results.inserted} added, ${results.skipped} skipped${results.errors.length ? `, ${results.errors.length} error(s)` : ""}.`,
      inserted: results.inserted,
      skipped: results.skipped,
      errors: results.errors,
    });
  } catch (err) {
    console.error(`[import-excel] ERROR after ${Date.now() - t0}ms:`, err);
    return res
      .status(500)
      .json({ success: false, message: "Server error: " + err.message });
  }
});

module.exports = router;
