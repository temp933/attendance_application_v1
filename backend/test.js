const bcrypt = require("bcryptjs");

const PLAIN_PASSWORD = "App_Admin@123"; // change this if you update the password

(async () => {
  const hash = await bcrypt.hash(PLAIN_PASSWORD, 12);
  console.log("\n✅  Paste this into your .env file:\n");
  console.log(`APP_ADMIN_PASSWORD_HASH=${hash}\n`);
})();
