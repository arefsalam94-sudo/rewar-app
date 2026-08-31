/**
 * Cloud Functions for the password-reset-by-code flow.
 *
 * Why these exist at all: Firebase Auth has no built-in *code*-based password
 * reset for email — `sendPasswordResetEmail()` sends a clickable link. The
 * Verification Code screen's design requires a 6-digit code, so the email
 * branch is implemented here. (The phone/SMS branch needs none of this —
 * Firebase Auth's own phone verification generates and sends that code.)
 *
 * Security properties, per SECURITY.md:
 *  - The plaintext code is NEVER stored and NEVER returned to the client.
 *    Firestore holds only a salted SHA-256 hash of it.
 *  - The client has zero access to `password_reset_codes` (see
 *    firestore.rules); only the Admin SDK, which bypasses rules, touches it.
 *  - Account enumeration is prevented: sending always reports success,
 *    whether or not the email belongs to a real account.
 *  - Rate limited on send (60s between sends) and on verify (5 attempts),
 *    satisfying SECURITY.md 6.4.
 *  - Codes expire after 10 minutes.
 *  - No secrets live in this file. Email delivery goes through the "Trigger
 *    Email from Firestore" extension, which holds the SMTP credentials in
 *    extension config (SECURITY.md section 4).
 */

const crypto = require("crypto");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue, Timestamp } =
  require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { searchAirports } = require("./airport-search");

initializeApp();
const db = getFirestore();

// Public, read-only worldwide airport autocomplete for the flight form.
exports.searchAirports = searchAirports;

const CODE_LENGTH = 6;
const CODE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const RESEND_COOLDOWN_MS = 60 * 1000; // must match _resendCooldown in Dart
const MAX_ATTEMPTS = 5;
const RESET_TOKEN_TTL_MS = 10 * 60 * 1000;

const COLLECTION = "password_reset_codes";
const EMAIL_CHANGE_COLLECTION = "email_change_codes";
const EMAIL_VERIFY_COLLECTION = "email_verify_codes";

function requireRecentSignIn(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Sign-in is required.");
  }
  const authTimeSeconds = Number(request.auth.token.auth_time || 0);
  if (!authTimeSeconds ||
      Date.now() - authTimeSeconds * 1000 > CODE_TTL_MS) {
    throw new HttpsError(
      "failed-precondition",
      "Confirm your password again before changing your email.",
      "recent-login-required"
    );
  }
  return request.auth.uid;
}

// `claimUsername` was removed with the username feature. A user is identified
// by their display name and email alone, so there is no globally unique handle
// left to reserve and the `usernames/{name}` collection is gone with it.
//
// If a deployment already ran the old function, drop the `usernames`
// collection and the `username` / `usernameNormalized` fields on `users` —
// see `DATA_MODEL.md`.

/** Mirrors Firebase Auth's verified phone into the profile document. */
exports.syncPhoneNumber = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }
    const user = await getAuth().getUser(request.auth.uid);
    if (!user.phoneNumber) {
      throw new HttpsError("failed-precondition", "No verified phone number.");
    }
    await db.collection("users").doc(request.auth.uid).set({
      phone: user.phoneNumber,
      phoneVerified: true,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
  }
);

/** Mirrors verified Firebase Auth identity fields after email-link changes. */
exports.syncAuthIdentity = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }
    const user = await getAuth().getUser(request.auth.uid);
    const updates = { updatedAt: FieldValue.serverTimestamp() };
    if (user.email && user.emailVerified) {
      updates.email = user.email;
      updates.emailVerified = true;
    }
    if (user.phoneNumber) {
      updates.phone = user.phoneNumber;
      updates.phoneVerified = true;
    }
    await db.collection("users").doc(request.auth.uid).set(
      updates,
      { merge: true }
    );
    return { ok: true };
  }
);

/**
 * Sends a six-digit code to the address the account was just registered with.
 *
 * Deliberately different from `sendEmailChangeCode` in one important way: the
 * destination is **not** taken from the request. It is read from Firebase Auth
 * for the calling uid, so a client cannot point registration codes at an
 * address it does not own. The only thing the caller controls is *when* a code
 * is sent to their own address.
 *
 * Same properties as every other code in this file: only a salted hash is
 * stored, sends are rate limited, and codes expire after 10 minutes.
 */
exports.sendRegistrationEmailCode = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }
    const uid = request.auth.uid;
    const user = await getAuth().getUser(uid);
    const email = user.email && user.email.toLowerCase();
    if (!email) {
      throw new HttpsError("failed-precondition", "No email on the account.");
    }
    // Already verified — nothing to send, and re-verifying is a no-op.
    if (user.emailVerified) return { ok: true, alreadyVerified: true };

    const ref = db.collection(EMAIL_VERIFY_COLLECTION).doc(uid);
    const existing = await ref.get();
    const now = Date.now();
    if (existing.exists) {
      const lastSentAt = existing.get("lastSentAt");
      const lastSentMs = lastSentAt ? lastSentAt.toMillis() : 0;
      if (now - lastSentMs < RESEND_COOLDOWN_MS) {
        throw new HttpsError(
          "resource-exhausted",
          "Please wait before requesting another code.",
          "too-many-attempts"
        );
      }
    }

    const code = generateCode();
    const salt = crypto.randomBytes(16).toString("hex");
    await ref.set({
      email,
      codeHash: hashCode(code, salt),
      salt,
      attempts: 0,
      verifying: false,
      expiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
      lastSentAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });

    await db.collection("mail").add({
      to: [email],
      message: {
        subject: "Verify your Kurdistan Paradise email",
        text:
          `Your verification code is ${code}.\n\n` +
          "It expires in 10 minutes. If you didn't create an account, " +
          "you can safely ignore this email.",
        html:
          `<p>Your verification code is <strong>${code}</strong>.</p>` +
          "<p>It expires in 10 minutes. If you didn't create an account, " +
          "you can safely ignore this email.</p>",
      },
    });
    return { ok: true };
  }
);

/**
 * Verifies the registration code and marks the address verified.
 *
 * `emailVerified` is written here, by the Admin SDK, and is on neither
 * client-writable allow-list (SECURITY.md 6.1c) — a client that could set it
 * would be claiming a verification it never passed.
 */
exports.confirmRegistrationEmailCode = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }
    const uid = request.auth.uid;
    const code = request.data && request.data.code;
    if (typeof code !== "string" ||
        !new RegExp(`^\\d{${CODE_LENGTH}}$`).test(code)) {
      throw new HttpsError("invalid-argument", "A six-digit code is required.");
    }

    const ref = db.collection(EMAIL_VERIFY_COLLECTION).doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError(
          "not-found", "No verification was requested.", "expired-code"
        );
      }
      if (snap.get("verifying") === true) {
        throw new HttpsError("aborted", "Verification is already in progress.");
      }
      const attempts = snap.get("attempts") || 0;
      if (attempts >= MAX_ATTEMPTS) {
        throw new HttpsError(
          "resource-exhausted", "Too many attempts.", "too-many-attempts"
        );
      }
      const expiresAt = snap.get("expiresAt");
      if (!expiresAt || expiresAt.toMillis() < Date.now()) {
        throw new HttpsError(
          "deadline-exceeded", "The code expired.", "expired-code"
        );
      }
      const expectedHash = snap.get("codeHash");
      const salt = snap.get("salt");
      // Constant-time compare, so a timing side channel cannot leak the code.
      if (!expectedHash || !salt ||
          !safeEqual(hashCode(code, salt), expectedHash)) {
        tx.update(ref, { attempts: FieldValue.increment(1) });
        throw new HttpsError(
          "permission-denied", "Incorrect code.", "incorrect-code"
        );
      }
      tx.update(ref, { verifying: true });
    });

    try {
      await getAuth().updateUser(uid, { emailVerified: true });
      await db.collection("users").doc(uid).set({
        emailVerified: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      // Burned on first successful use, so the code cannot be replayed.
      await ref.delete();
    } catch (e) {
      await ref.set({ verifying: false }, { merge: true });
      logger.error("Could not complete email verification", e);
      throw new HttpsError("internal", "Could not verify the email.");
    }
    return { ok: true };
  }
);

/** Sends a six-digit ownership code to an authenticated user's new email. */
exports.sendEmailChangeCode = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const uid = requireRecentSignIn(request);
    const newEmail = normalizeEmail(request.data && request.data.newEmail);
    if (!newEmail) {
      throw new HttpsError("invalid-argument", "A valid email is required.");
    }

    const user = await getAuth().getUser(uid);
    if (user.email && user.email.toLowerCase() === newEmail) {
      throw new HttpsError(
        "invalid-argument", "The new email must be different."
      );
    }
    try {
      await getAuth().getUserByEmail(newEmail);
      throw new HttpsError(
        "already-exists", "That email is already in use."
      );
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      if (e.code !== "auth/user-not-found") {
        logger.error("Email availability lookup failed", e);
        throw new HttpsError("internal", "Could not send the code.");
      }
    }

    const ref = db.collection(EMAIL_CHANGE_COLLECTION).doc(uid);
    const existing = await ref.get();
    const now = Date.now();
    if (existing.exists) {
      const lastSentAt = existing.get("lastSentAt");
      const lastSentMs = lastSentAt ? lastSentAt.toMillis() : 0;
      if (now - lastSentMs < RESEND_COOLDOWN_MS) {
        throw new HttpsError(
          "resource-exhausted",
          "Please wait before requesting another code.",
          "too-many-attempts"
        );
      }
    }

    const code = generateCode();
    const salt = crypto.randomBytes(16).toString("hex");
    await ref.set({
      newEmail,
      codeHash: hashCode(code, salt),
      salt,
      attempts: 0,
      verifying: false,
      expiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
      lastSentAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });

    await db.collection("mail").add({
      to: [newEmail],
      message: {
        subject: "Confirm your new Kurdistan Paradise email",
        text:
          `Your email verification code is ${code}.\n\n` +
          "It expires in 10 minutes. If you didn't request this change, " +
          "you can safely ignore this email.",
        html:
          `<p>Your email verification code is <strong>${code}</strong>.</p>` +
          "<p>It expires in 10 minutes. If you didn't request this change, " +
          "you can safely ignore this email.</p>",
      },
    });
    return { ok: true };
  }
);

/** Verifies the code, then updates both Firebase Auth and the user profile. */
exports.confirmEmailChangeCode = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const uid = requireRecentSignIn(request);
    const newEmail = normalizeEmail(request.data && request.data.newEmail);
    const code = request.data && request.data.code;
    if (!newEmail || typeof code !== "string" ||
        !new RegExp(`^\\d{${CODE_LENGTH}}$`).test(code)) {
      throw new HttpsError(
        "invalid-argument", "Email and a six-digit code are required."
      );
    }

    const ref = db.collection(EMAIL_CHANGE_COLLECTION).doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.get("newEmail") !== newEmail) {
        throw new HttpsError(
          "not-found", "No email change was requested.", "expired-code"
        );
      }
      if (snap.get("verifying") === true) {
        throw new HttpsError("aborted", "Verification is already in progress.");
      }
      const attempts = snap.get("attempts") || 0;
      if (attempts >= MAX_ATTEMPTS) {
        throw new HttpsError(
          "resource-exhausted", "Too many attempts.", "too-many-attempts"
        );
      }
      const expiresAt = snap.get("expiresAt");
      if (!expiresAt || expiresAt.toMillis() < Date.now()) {
        throw new HttpsError(
          "deadline-exceeded", "The code expired.", "expired-code"
        );
      }
      const expectedHash = snap.get("codeHash");
      const salt = snap.get("salt");
      if (!expectedHash || !salt ||
          !safeEqual(hashCode(code, salt), expectedHash)) {
        tx.update(ref, { attempts: FieldValue.increment(1) });
        throw new HttpsError(
          "permission-denied", "Incorrect code.", "incorrect-code"
        );
      }
      tx.update(ref, { verifying: true });
    });

    try {
      await getAuth().updateUser(uid, { email: newEmail, emailVerified: true });
      await db.collection("users").doc(uid).set({
        email: newEmail,
        emailVerified: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      await ref.delete();
    } catch (e) {
      await ref.set({ verifying: false }, { merge: true });
      logger.error("Could not complete email change", e);
      if (e.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "That email is already in use.");
      }
      throw new HttpsError("internal", "Could not update the email.");
    }
    return { ok: true };
  }
);

/** Stable, non-reversible document id for an email address. */
function docIdFor(email) {
  return crypto
    .createHash("sha256")
    .update(email.trim().toLowerCase())
    .digest("hex");
}

/** Salted hash of a code — what we actually persist. */
function hashCode(code, salt) {
  return crypto
    .createHash("sha256")
    .update(`${salt}:${code}`)
    .digest("hex");
}

/**
 * A cryptographically random 6-digit code.
 *
 * `randomInt` is used rather than `Math.random()` so the code is not
 * predictable from previously issued ones.
 */
function generateCode() {
  const max = 10 ** CODE_LENGTH;
  return String(crypto.randomInt(0, max)).padStart(CODE_LENGTH, "0");
}

/** Constant-time comparison, so a timing side channel can't leak the code. */
function safeEqual(a, b) {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

function normalizeEmail(raw) {
  if (typeof raw !== "string") return null;
  const email = raw.trim().toLowerCase();
  // Deliberately permissive — real validation is "does an account exist".
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return null;
  return email;
}

/**
 * Step 1 — generate a code, store its hash, and queue the email.
 *
 * Always resolves with `{ ok: true }`, even for an unknown address, so an
 * attacker can't use this endpoint to discover which emails are registered.
 */
exports.sendPasswordResetCode = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const email = normalizeEmail(request.data && request.data.email);
    if (!email) {
      throw new HttpsError("invalid-argument", "A valid email is required.");
    }

    const ref = db.collection(COLLECTION).doc(docIdFor(email));
    const now = Date.now();

    // Rate limit before doing any work, and before revealing any latency
    // difference between known and unknown addresses.
    const existing = await ref.get();
    if (existing.exists) {
      const lastSentAt = existing.get("lastSentAt");
      const lastSentMs = lastSentAt ? lastSentAt.toMillis() : 0;
      if (now - lastSentMs < RESEND_COOLDOWN_MS) {
        throw new HttpsError(
          "resource-exhausted",
          "Please wait before requesting another code.",
          "too-many-attempts"
        );
      }
    }

    // Does this address actually have an account? We branch only on whether
    // we queue an email — the response is identical either way.
    let userExists = true;
    try {
      await getAuth().getUserByEmail(email);
    } catch (e) {
      if (e.code === "auth/user-not-found") {
        userExists = false;
      } else {
        logger.error("Auth lookup failed", e);
        throw new HttpsError("internal", "Could not send the code.");
      }
    }

    const code = generateCode();
    const salt = crypto.randomBytes(16).toString("hex");

    await ref.set(
      {
        codeHash: hashCode(code, salt),
        salt,
        expiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
        attempts: 0,
        lastSentAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        // Cleared on a fresh send so an old token can't be reused.
        resetTokenHash: FieldValue.delete(),
        resetTokenExpiresAt: FieldValue.delete(),
      },
      { merge: true }
    );

    if (userExists) {
      // Consumed by the "Trigger Email from Firestore" extension, which owns
      // the SMTP credentials — no keys in this codebase.
      await db.collection("mail").add({
        to: [email],
        message: {
          subject: "Your Kurdistan Paradise verification code",
          text:
            `Your password reset code is ${code}.\n\n` +
            "It expires in 10 minutes. If you didn't request this, you can " +
            "safely ignore this email.",
          html:
            `<p>Your password reset code is <strong>${code}</strong>.</p>` +
            "<p>It expires in 10 minutes. If you didn't request this, you " +
            "can safely ignore this email.</p>",
        },
      });
    } else {
      logger.info("Reset requested for an address with no account.");
    }

    return { ok: true };
  }
);

/**
 * Step 2 — check a submitted code.
 *
 * On success returns a short-lived `resetToken`. That token proves the user
 * controls the mailbox; the Set New Password screen will exchange it (plus
 * the new password) via a separate function. Holding the token grants no
 * other privilege.
 */
exports.verifyPasswordResetCode = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const email = normalizeEmail(request.data && request.data.email);
    const code = request.data && request.data.code;

    if (!email || typeof code !== "string" ||
        !new RegExp(`^\\d{${CODE_LENGTH}}$`).test(code)) {
      throw new HttpsError("invalid-argument", "Email and code are required.");
    }

    const ref = db.collection(COLLECTION).doc(docIdFor(email));

    // A transaction so concurrent guesses can't race past the attempt limit.
    const resetToken = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError(
          "not-found", "No code was requested.", "expired-code"
        );
      }

      const attempts = snap.get("attempts") || 0;
      if (attempts >= MAX_ATTEMPTS) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many attempts.",
          "too-many-attempts"
        );
      }

      const expiresAt = snap.get("expiresAt");
      if (!expiresAt || expiresAt.toMillis() < Date.now()) {
        throw new HttpsError(
          "deadline-exceeded", "The code expired.", "expired-code"
        );
      }

      const expectedHash = snap.get("codeHash");
      const salt = snap.get("salt");
      if (!expectedHash || !salt ||
          !safeEqual(hashCode(code, salt), expectedHash)) {
        tx.update(ref, { attempts: FieldValue.increment(1) });
        throw new HttpsError(
          "permission-denied", "Incorrect code.", "incorrect-code"
        );
      }

      // Correct. Burn the code immediately so it can't be replayed, and
      // issue the token the next screen will need.
      const token = crypto.randomBytes(32).toString("hex");
      tx.update(ref, {
        codeHash: FieldValue.delete(),
        salt: FieldValue.delete(),
        attempts: 0,
        resetTokenHash: crypto
          .createHash("sha256").update(token).digest("hex"),
        resetTokenExpiresAt:
          Timestamp.fromMillis(Date.now() + RESET_TOKEN_TTL_MS),
      });
      return token;
    });

    return { resetToken };
  }
);

/**
 * Step 3 (email branch) — set the new password.
 *
 * Called by the Reset Password screen with the `resetToken` issued by
 * `verifyPasswordResetCode`. The password is applied through the Admin SDK
 * and is never written to Firestore or logged.
 *
 * Revoking refresh tokens is the point of a password reset that people often
 * miss: without it, a session an attacker already holds keeps working after
 * the legitimate owner "recovers" the account.
 */
exports.confirmPasswordResetWithCode = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const email = normalizeEmail(request.data && request.data.email);
    const resetToken = request.data && request.data.resetToken;
    const newPassword = request.data && request.data.newPassword;

    if (!email || typeof resetToken !== "string" || !resetToken) {
      throw new HttpsError("invalid-argument", "Email and token are required.");
    }
    if (typeof newPassword !== "string" || !isStrongEnough(newPassword)) {
      throw new HttpsError(
        "invalid-argument",
        "Password does not meet the policy.",
        "weak-password"
      );
    }

    const ref = db.collection(COLLECTION).doc(docIdFor(email));
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError(
        "not-found", "No reset in progress.", "invalid-reset-token"
      );
    }

    const expectedHash = snap.get("resetTokenHash");
    const expiresAt = snap.get("resetTokenExpiresAt");
    const submittedHash = crypto
      .createHash("sha256").update(resetToken).digest("hex");

    if (!expectedHash || !safeEqual(submittedHash, expectedHash)) {
      throw new HttpsError(
        "permission-denied", "Invalid token.", "invalid-reset-token"
      );
    }
    if (!expiresAt || expiresAt.toMillis() < Date.now()) {
      throw new HttpsError(
        "deadline-exceeded", "Token expired.", "invalid-reset-token"
      );
    }

    let user;
    try {
      user = await getAuth().getUserByEmail(email);
    } catch (e) {
      logger.error("Auth lookup failed during reset confirm", e);
      throw new HttpsError("internal", "Could not update the password.");
    }

    await getAuth().updateUser(user.uid, { password: newPassword });
    // Kill every existing session for this account.
    await getAuth().revokeRefreshTokens(user.uid);

    // The token is single-use — delete the whole document.
    await ref.delete();

    await stampPasswordChange(user.uid);

    return { ok: true };
  }
);

/**
 * Bookkeeping for the phone branch, where the client already changed the
 * password itself using its signed-in credential.
 *
 * Exists so the app needs **no** client write access to `users` — the
 * collection stays fully closed in `firestore.rules`.
 */
exports.recordPasswordChange = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const uid = request.auth.uid;
    await getAuth().revokeRefreshTokens(uid);
    await stampPasswordChange(uid);
    return { ok: true };
  }
);

/**
 * Records *when* the password changed — never the password itself.
 *
 * Useful for showing "last changed" in settings and for rejecting tokens
 * issued before the reset.
 */
async function stampPasswordChange(uid) {
  try {
    await db.collection("users").doc(uid).set(
      {
        passwordChangedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } catch (e) {
    // Non-fatal: the password change itself already succeeded.
    logger.error("Could not stamp passwordChangedAt", e);
  }
}

/**
 * Server-side copy of the policy shown on the Reset Password screen:
 * 8+ characters, an uppercase letter, a lowercase letter, a special
 * character. The client validates the same rules for fast feedback, but this
 * is the one that actually counts (SECURITY.md section 7).
 */
function isStrongEnough(password) {
  return (
    password.length >= 8 &&
    /[A-Z]/.test(password) &&
    /[a-z]/.test(password) &&
    /[^A-Za-z0-9]/.test(password)
  );
}

// =====================================================================
// Nature-spot review aggregates — the numbers at the top of the
// Reviews & Ratings screen.
//
// Why these are triggers and not client writes: `reviewScore`,
// `ratingCount` and `ratingBreakdown` all live on the `nature_spots`
// document, which is **admin-only write** (SECURITY.md 1). That is
// deliberate — a client that could write the average score of a place
// could give a competitor a 2.0 without ever leaving a review. So the
// client writes only its own review, and the server derives every
// aggregate from it.
//
// ## Why these RECOMPUTE instead of incrementing
//
// An incremental `FieldValue.increment(1)` is cheaper and was the obvious
// first design. It is also wrong here, for a reason that is easy to miss:
// **Cloud Functions triggers are at-least-once**. A duplicate delivery is
// not a rare failure mode, it is a documented guarantee — and an
// increment applied twice corrupts the count permanently, with nothing in
// the data to show it happened. A recompute applied twice produces the
// same answer both times, and repairs any earlier drift on the next
// write. Correct numbers matter more than a few reads here: this is the
// figure the whole page is built around.
//
// It also makes seeding work. `tool/seed_explore_nature.js` writes
// reviews without hand-computing aggregates; whatever order the writes
// land in, the last trigger leaves the right totals.
//
// > **When this stops being right.** Each review write costs one read per
// > existing review on that spot. Comfortable into the low thousands; past
// > that, move to a sharded counter with an idempotency key per event id,
// > and keep the recompute as a scheduled repair job. Recorded as a
// > deliberate trade in DATA_MODEL.md, not an oversight.
// =====================================================================

const { onDocumentWritten } = require("firebase-functions/v2/firestore");

/** Which 1–5 bar a rating falls in. 3.5 rounds up into the 4-star bar. */
function ratingBucket(rating) {
  return Math.min(5, Math.max(1, Math.round(rating)));
}

/** Whether a review counts toward the aggregates. Only published ones do. */
function countableRating(data) {
  if (!data || data.status !== "published") return null;
  const rating = Number(data.rating);
  if (!Number.isFinite(rating) || rating <= 0 || rating > 5) return null;
  return rating;
}

exports.syncNatureReviewAggregates = onDocumentWritten(
  {
    region: "us-central1",
    document: "nature_spots/{spotId}/reviews/{reviewId}",
  },
  async (event) => {
    const before = event.data && event.data.before;
    const after = event.data && event.data.after;
    const ratingBefore = countableRating(
      before && before.exists ? before.data() : null
    );
    const ratingAfter = countableRating(
      after && after.exists ? after.data() : null
    );

    // A helpful-vote write touches the review document too (it bumps
    // `helpfulCount`). Nothing that feeds the score changed, so there is
    // nothing to recompute — this keeps a popular review from re-reading
    // every review on the place each time someone taps the heart.
    if (ratingBefore === ratingAfter) return;

    const spotId = event.params.spotId;
    const spotRef = db.collection("nature_spots").doc(spotId);

    const snapshot = await spotRef
      .collection("reviews")
      .where("status", "==", "published")
      .get();

    let count = 0;
    let sum = 0;
    const breakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    snapshot.forEach((doc) => {
      const rating = countableRating(doc.data());
      if (rating === null) return;
      count += 1;
      sum += rating;
      breakdown[ratingBucket(rating)] += 1;
    });

    await spotRef.set({
      ratingCount: count,
      ratingBreakdown: breakdown,
      // 0–10, one decimal — the Booking.com-style score the rest of the app
      // already shows. Derived here so the headline score and the reviews
      // behind it can never disagree. Null (not 0) with no reviews: an
      // unrated place is not a badly rated one, the rule the card already
      // follows by hiding the badge.
      reviewScore: count === 0 ? null : Math.round((sum / count) * 2 * 10) / 10,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    logger.info(
      `Recomputed review aggregates for ${spotId}: ` +
      `${count} reviews, score ${count === 0 ? "none" : sum / count * 2}.`
    );
  }
);

/**
 * Maintains `helpfulCount` on a review from its `votes` subcollection.
 *
 * The client creates or deletes one document keyed by its own uid; this
 * turns that into the number on the heart. Deliberately NOT a client-side
 * increment: a document keyed by the voter cannot be cast twice, an
 * increment can be sent in a loop.
 *
 * Uses a `count()` aggregation rather than `increment(±1)` for the same
 * at-least-once reason as above — one aggregation read, and the answer is
 * the same however many times the trigger runs.
 */
exports.syncReviewHelpfulCount = onDocumentWritten(
  {
    region: "us-central1",
    document: "nature_spots/{spotId}/reviews/{reviewId}/votes/{voterId}",
  },
  async (event) => {
    const before = event.data && event.data.before;
    const after = event.data && event.data.after;
    const existedBefore = Boolean(before && before.exists);
    const existsAfter = Boolean(after && after.exists);
    // Votes carry no editable content, so a write that neither creates nor
    // deletes one cannot have changed the total.
    if (existedBefore === existsAfter) return;

    const reviewRef = db.collection("nature_spots")
      .doc(event.params.spotId)
      .collection("reviews")
      .doc(event.params.reviewId);

    const total = await reviewRef.collection("votes").count().get();

    // `update` rather than `set(merge)`: if the review was deleted while the
    // votes were being cleaned up, there is nothing to count for, and
    // recreating a review document out of a stray counter would be worse
    // than failing.
    try {
      await reviewRef.update({ helpfulCount: total.data().count });
    } catch (e) {
      logger.info(
        "Skipped helpfulCount update; the review no longer exists.", e
      );
    }
  }
);

// =====================================================================
// Tour rating aggregates — added with the Explore Tours screen.
//
// Identical in shape and in reasoning to syncNatureReviewAggregates
// above, pointed at `tours/{tourId}/reviews`. Deliberately a second
// trigger rather than a shared collectionGroup one: a collectionGroup
// listener on `reviews` would fire for every catalog that ever gains a
// `reviews` subcollection, and would then have to guess which parent
// document to write back to from the event path. Two explicit triggers
// cost nothing and cannot write to the wrong collection.
//
// Recompute rather than increment, for the same reason: Firestore
// triggers are at-least-once, so a duplicate delivery is a documented
// guarantee. An increment applied twice corrupts the count permanently;
// a recompute applied twice gives the same answer and repairs drift.
// It is also what makes `tool/seed_explore_tours.js` work — it writes
// reviews and no aggregates at all.
//
// `tours` is admin-only write (firestore.rules), and it must stay that
// way: a client that could write the average score of a tour could give
// a competing operator a 2.0 without leaving a review. So the client
// writes only its own review document, and all three aggregates are
// derived from it here.
// =====================================================================
exports.syncTourReviewAggregates = onDocumentWritten(
  {
    region: "us-central1",
    document: "tours/{tourId}/reviews/{reviewId}",
  },
  async (event) => {
    const before = event.data && event.data.before;
    const after = event.data && event.data.after;
    const ratingBefore = countableRating(
      before && before.exists ? before.data() : null
    );
    const ratingAfter = countableRating(
      after && after.exists ? after.data() : null
    );

    // An edit that changed only the comment text cannot move the score,
    // so there is nothing to recompute.
    if (ratingBefore === ratingAfter) return;

    const tourId = event.params.tourId;
    const tourRef = db.collection("tours").doc(tourId);

    const snapshot = await tourRef
      .collection("reviews")
      .where("status", "==", "published")
      .get();

    let count = 0;
    let sum = 0;
    const breakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    snapshot.forEach((doc) => {
      const rating = countableRating(doc.data());
      if (rating === null) return;
      count += 1;
      sum += rating;
      breakdown[ratingBucket(rating)] += 1;
    });

    await tourRef.set({
      ratingCount: count,
      ratingBreakdown: breakdown,
      // 0–10, one decimal — the Booking.com-style score the rest of the
      // app already shows. Null (not 0) with no reviews: an unrated tour
      // is not a badly rated one, which is the rule the card follows by
      // hiding the badge.
      reviewScore: count === 0 ? null : Math.round((sum / count) * 2 * 10) / 10,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    logger.info(
      `Recomputed review aggregates for tour ${tourId}: ` +
      `${count} reviews, score ${count === 0 ? "none" : sum / count * 2}.`
    );
  }
);

/** Maintains helpfulCount for votes under tours/{tourId}/reviews. */
exports.syncTourReviewHelpfulCount = onDocumentWritten(
  {
    region: "us-central1",
    document: "tours/{tourId}/reviews/{reviewId}/votes/{voterId}",
  },
  async (event) => {
    const before = event.data && event.data.before;
    const after = event.data && event.data.after;
    const existedBefore = Boolean(before && before.exists);
    const existsAfter = Boolean(after && after.exists);
    if (existedBefore === existsAfter) return;

    const reviewRef = db.collection("tours")
      .doc(event.params.tourId)
      .collection("reviews")
      .doc(event.params.reviewId);
    const total = await reviewRef.collection("votes").count().get();
    try {
      await reviewRef.update({ helpfulCount: total.data().count });
    } catch (e) {
      logger.info(
        "Skipped tour helpfulCount update; the review no longer exists.", e
      );
    }
  }
);

// =====================================================================
// Tour availability — `tours.bookedCount` is SERVER-OWNED.
//
// The Explore Tours screen hides a departure that cannot seat the whole
// party, and prints "Only 3 spots left". Both numbers must come from
// somewhere a client cannot write: a client that could set `bookedCount`
// could mark a rival operator's departure full, or zero it out and
// oversell a trip that is already sold.
//
// There is nothing to maintain it from yet — **no code in this app can
// create a tour booking**, because the tour detail/checkout screen does
// not exist (ROADMAP Phase 6). When it does, the checkout Cloud Function
// must do BOTH of these inside one transaction:
//
//   1. re-read `tours/{id}.capacity` and `bookedCount`, and refuse the
//      booking if `capacity - bookedCount < party size`. Checking
//      availability on the client is not a check — it is a suggestion;
//   2. write the booking and bump `bookedCount` in the same transaction,
//      so two people paying at once cannot both take the last seat.
//
// A trigger on `bookings` is NOT sufficient on its own: by the time it
// fires the payment has already been taken, and an oversold departure
// then has to be refunded and apologised for. The transaction is the
// control; a recompute trigger is only a repair job on top of it.
//
// Recorded here, in the file that would own it, rather than only in
// DATA_MODEL.md — this is the kind of gap that gets discovered in
// production.
// =====================================================================
