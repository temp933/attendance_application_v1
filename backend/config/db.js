// const mysql = require("mysql2/promise");

// const pool = mysql.createPool({
//   host: "localhost",
//   user: "root",
//   password: "2026", // your password
//   database: "global_app",
//   waitForConnections: true,
//   connectionLimit: 10,
//   queueLimit: 0,

//   timezone: "+05:30",
// });
// pool.on("connection", (conn) => {
//   conn.query("SET time_zone = '+05:30'");
// });
// module.exports = pool;

const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "2026",
  database: process.env.DB_NAME || "global_app",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,

  // ✅ Keep DATE/DATETIME values as plain strings — never convert to JS Date
  dateStrings: true,

  // ✅ UTC for the driver's internal conversions (TIMESTAMP / DATETIME)
  timezone: "Z",

  // ❌ REMOVED: timezone: '+05:30'          ← was shifting every date write
  // ❌ REMOVED: SET time_zone = '+05:30'    ← was shifting every date read
});

module.exports = pool;
