// firebase_admin.js
"use strict";

const admin = require("firebase-admin");
const path = require("path");

let initialized = false;

function getAdmin() {
  if (!initialized) {
    const serviceAccount = require(
      path.join(__dirname, "firebase-service-account.json"),
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    initialized = true;
    console.log("[firebase] Admin SDK initialized.");
  }
  return admin;
}

module.exports = { getAdmin };
