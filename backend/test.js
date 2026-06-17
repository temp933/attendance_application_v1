// const bcrypt = require("bcryptjs");

// const PLAIN_PASSWORD = "Super_Admin@123"; // change this if you update the password

// (async () => {
//   const hash = await bcrypt.hash(PLAIN_PASSWORD, 12);
//   console.log("\n✅  Paste this into your .env file:\n");
//   console.log(`APP_ADMIN_PASSWORD_HASH=${hash}\n`);
// })();

// random 32 char tokens
const crypto = require("crypto");

console.log(crypto.randomBytes(32).toString("hex"));
