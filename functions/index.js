const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.checkUserExists = functions.https.onCall(async (data, context) => {
  const email = data.email;

  if (!email || typeof email !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A valid email must be provided."
    );
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    return {
      exists: true,
      uid: userRecord.uid,
      name: userRecord.displayName || null,
      photoUrl: userRecord.photoURL || null,
    };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return { exists: false };
    }
    throw new functions.https.HttpsError("internal", error.message);
  }
});
