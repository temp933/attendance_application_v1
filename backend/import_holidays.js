require("dotenv").config();
const axios = require("axios");
const db = require("./config/db");

// Only holidays every Indian org will have — fixed date every year
const CORE_HOLIDAYS = [
  "new year",
  "pongal",
  "republic day",
  "ambedkar jayanti",
  "labour day",
  "independence day",
  "gandhi jayanti",
  "christmas",
];

async function importHolidays() {
  try {
    const year = new Date().getFullYear();

    const response = await axios.get(
      "https://calendarific.com/api/v2/holidays",
      {
        params: {
          api_key: process.env.CALENDARIFIC_API_KEY,
          country: "IN",
          year,
          type: "national",
        },
      },
    );

    const holidays = response.data.response.holidays;
    console.log(`API returned ${holidays.length} holidays`);

    // Filter only core holidays
    const filtered = holidays.filter((h) =>
      CORE_HOLIDAYS.some((name) => h.name.toLowerCase().includes(name)),
    );
    console.log(`Filtered to ${filtered.length} core holidays`);

    // Clear old and re-insert
    await db.query(`DELETE FROM default_holiday_master`);

    let inserted = 0;
    for (const h of filtered) {
      const mmdd = h.date.iso.slice(5, 10); // "MM-DD"

      await db.query(
        `INSERT INTO default_holiday_master
           (holiday_name, holiday_date, holiday_type, description, is_recurring)
         VALUES (?, ?, ?, ?, ?)`,
        [h.name, mmdd, "National", h.description || h.name, 1],
      );
      console.log(`Inserted: ${h.name} — ${mmdd}`);
      inserted++;
    }

    console.log(`\nDone. ${inserted} core holidays inserted.`);
  } catch (err) {
    console.error("Import Error:", err.message);
  } finally {
    process.exit();
  }
}

importHolidays();
