require("dotenv").config();
const axios = require("axios");
const db = require("./config/db");

async function importHolidays() {
  try {
    const response = await axios.get(
      "https://calendarific.com/api/v2/holidays",
      {
        params: {
          api_key: process.env.CALENDARIFIC_API_KEY, // Add this to your .env
          country: "IN",
          year: 2025,
          type: "national",
        },
      },
    );

    const holidays = response.data.response.holidays;
    console.log(`Found ${holidays.length} holidays`);

    for (const h of holidays) {
      await db.query(
        `INSERT INTO default_holiday_master
         (holiday_name, holiday_date, holiday_type, description, is_recurring)
         VALUES (?, ?, ?, ?, ?)`,
        [
          h.name,
          h.date.iso, // "2026-01-26"
          "National",
          h.description || h.name,
          1,
        ],
      );
      console.log(`Inserted: ${h.name}`);
    }

    console.log("Holiday import completed.");
  } catch (err) {
    console.error("Import Error:", err.message);
  } finally {
    process.exit();
  }
}

importHolidays();
