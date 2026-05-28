const fs = require("fs");
const mysql = require("mysql2/promise");

async function generateDbDocumentation() {
  // ===== DB CONFIG =====
  const connection = await mysql.createConnection({
    host: "localhost",
    user: "root",
    password: "2026",
    database: "global_app",
  });

  let output = "";

  // ===== GET ALL TABLES =====
  const [tables] = await connection.query(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
    ORDER BY table_name
  `);

  for (const table of tables) {
    const tableName = table.TABLE_NAME || table.table_name;

    output += `\n==================================================\n`;
    output += `TABLE: ${tableName}\n`;
    output += `==================================================\n`;

    // ===== GET COLUMNS =====
    const [columns] = await connection.query(
      `
      SELECT
        column_name,
        column_type,
        is_nullable,
        column_key,
        extra
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
      AND table_name = ?
      ORDER BY ordinal_position
    `,
      [tableName],
    );

    for (const col of columns) {
      output += `
COLUMN: ${col.COLUMN_NAME || col.column_name}
TYPE: ${col.COLUMN_TYPE || col.column_type}
NULL: ${col.IS_NULLABLE || col.is_nullable}
KEY: ${col.COLUMN_KEY || col.column_key}
EXTRA: ${col.EXTRA || col.extra}
----------------------------------------
`;
    }

    // ===== OPTIONAL TABLE DESCRIPTION =====
    output += `\nPOSSIBLE PURPOSE:\n`;

    if (tableName.includes("attendance")) {
      output += `Attendance management related table\n`;
    } else if (tableName.includes("leave")) {
      output += `Leave management related table\n`;
    } else if (tableName.includes("notification")) {
      output += `Notification system related table\n`;
    } else if (tableName.includes("role")) {
      output += `Role and permission management\n`;
    } else if (tableName.includes("policy")) {
      output += `Policy configuration table\n`;
    } else if (tableName.includes("employee")) {
      output += `Employee management related table\n`;
    } else {
      output += `General application table\n`;
    }

    output += `\n\n`;
  }

  // ===== SAVE FILE =====
  fs.writeFileSync("db.txt", output);

  console.log("✅ Database documentation generated: db.txt");

  await connection.end();
}

generateDbDocumentation().catch((err) => {
  console.error("❌ Error:", err);
});
