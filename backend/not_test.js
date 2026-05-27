/**
 * ─────────────────────────────────────────────────────────────
 *  FCM Notification Server
 *  Polls MySQL every 1 second for unsent notifications
 *  and sends them via Firebase Cloud Messaging (Admin SDK)
 * ─────────────────────────────────────────────────────────────
 */

const mysql = require("mysql2/promise");
const admin = require("firebase-admin");
const path = require("path");

// ─────────────────────────────────────────────
// 1. FIREBASE ADMIN INIT
// ─────────────────────────────────────────────

const serviceAccount = require(
  path.join(__dirname, "firebase-service-account.json"),
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

console.log("✅ Firebase Admin initialized");

// ─────────────────────────────────────────────
// 2. CONFIG — Edit these values
// ─────────────────────────────────────────────

/**
 * Paste the FCM token printed by your Flutter app here.
 * You can also store it in MySQL and look it up dynamically.
 */
const DEVICE_TOKEN =
  "fZG7xSOcQiGUnIO5rMXMkF:APA91bFPU3VMYPzzx8yfy4C7cfAeL0exVphaUF7lsUecCw_vF8SjT-JJArtRv_svE-nFi47ocDl8zW3YZIx6aTGEwAH5cLZv1kweyVwuT3zY30G7wN5tKXo"; // <-- Replace with token from Flutter debug console

/** MySQL connection settings */
const DB_CONFIG = {
  host: "localhost",
  port: 3306,
  user: "root",
  password: "2026",
  database: "test",
};

/** How often to poll (ms) */
const POLL_INTERVAL_MS = 1000;

// ─────────────────────────────────────────────
// 3. MYSQL — Create table if not exists
// ─────────────────────────────────────────────

async function ensureTable(connection) {
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS notification_queue (
      id         INT AUTO_INCREMENT PRIMARY KEY,
      title      VARCHAR(255)  NOT NULL,
      message    TEXT          NOT NULL,
      is_sent    TINYINT(1)    NOT NULL DEFAULT 0,
      created_at TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  `);
  console.log("✅ Table [notification_queue] ready");
}

// ─────────────────────────────────────────────
// 4. SEND ONE FCM NOTIFICATION
// ─────────────────────────────────────────────

async function sendFCM({ token, title, body, notificationId }) {
  const message = {
    token,
    notification: {
      title,
      body,
    },
    // Extra key-value data (accessible in Flutter via message.data)
    data: {
      notificationId: String(notificationId),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
        priority: "max",
        defaultSound: true,
        vibrateTimingsMillis: [0, 250, 250, 250],
      },
    },
  };

  const response = await admin.messaging().send(message);
  return response; // e.g. "projects/xxx/messages/0:xxx"
}

// ─────────────────────────────────────────────
// 5. MAIN POLLING LOOP
// ─────────────────────────────────────────────

async function processNotifications() {
  console.log("🔄 Notification service starting...");

  let connection;

  try {
    connection = await mysql.createConnection(DB_CONFIG);
    console.log("✅ MySQL connected");

    await ensureTable(connection);

    console.log(
      `\n🟢 Polling every ${POLL_INTERVAL_MS}ms for unsent notifications...\n`,
    );

    while (true) {
      try {
        // Fetch the oldest unsent notification
        const [rows] = await connection.execute(`
          SELECT id, title, message
          FROM   notification_queue
          WHERE  is_sent = 0
          ORDER  BY id ASC
          LIMIT  1
        `);

        if (rows.length > 0) {
          const { id, title, message } = rows[0];

          console.log(`\n📤 Sending notification #${id}`);
          console.log(`   Title  : ${title}`);
          console.log(`   Message: ${message}`);

          const fcmResponse = await sendFCM({
            token: DEVICE_TOKEN,
            title,
            body: message,
            notificationId: id,
          });

          console.log(`   ✅ Sent! FCM Message ID: ${fcmResponse}`);

          // Mark as sent
          await connection.execute(
            "UPDATE notification_queue SET is_sent = 1 WHERE id = ?",
            [id],
          );

          console.log(`   📝 Marked #${id} as sent`);
        }
      } catch (loopError) {
        console.error("⚠️  Loop error (will retry):", loopError.message);

        // Reconnect if MySQL connection dropped
        if (
          loopError.code === "ECONNRESET" ||
          loopError.code === "PROTOCOL_CONNECTION_LOST"
        ) {
          console.log("🔁 Reconnecting to MySQL...");
          try {
            connection = await mysql.createConnection(DB_CONFIG);
            console.log("✅ MySQL reconnected");
          } catch (connErr) {
            console.error("❌ Reconnect failed:", connErr.message);
          }
        }
      }

      // Wait before next poll
      await sleep(POLL_INTERVAL_MS);
    }
  } catch (fatalError) {
    console.error("❌ Fatal error:", fatalError);
    process.exit(1);
  }
}

// ─────────────────────────────────────────────
// UTILS
// ─────────────────────────────────────────────

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ─────────────────────────────────────────────
// START
// ─────────────────────────────────────────────

processNotifications();
