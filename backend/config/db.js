const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: "localhost",
  user: "root",
  password: "2026", // your password
  database: "global_app",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,

  timezone: "+05:30",
});
pool.on("connection", (conn) => {
  conn.query("SET time_zone = '+05:30'");
});
module.exports = pool;
