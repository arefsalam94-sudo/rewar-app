/**
 * Creates (or resets) ONE real Firebase Auth account to sign in with during
 * development, so you don't register a new one every time you test.
 *
 * ## Why this is a script and not a constant in the app
 *
 * The credentials live in Firebase Auth, exactly like a real user's. Nothing
 * is hard-coded into the Dart source, so there is no path by which a test
 * password ships inside a release binary — which is what `SECURITY.md` 6.1
 * forbids. The only hard-coded credential in this project stays
 * `AuthService.previewUsername`, which is double-gated on
 * `kDebugMode && !FirebaseBootstrap.isReady` and unlocks nothing but the UI.
 *
 * The password is passed on the command line and is never written to this
 * file, to Firestore, or to the log. Don't commit it anywhere.
 *
 * ## What it writes
 *
 *   Firebase Auth   the user (created, or its password reset if it exists)
 *                   with `emailVerified: true`, so verification gates pass.
 *   users/{uid}     the profile document, per the `users` table in
 *                   DATA_MODEL.md. No password, no token — never.
 *
 * Re-running it is safe: it resets the same account rather than making a
 * second one.
 *
 * ## Usage
 *
 *   cd functions && npm install && cd ..          (once)
 *   node tool/seed_test_account.js <email> <password> [options]
 *
 * Options:
 *   --name "Test User"        display name (default: "Test User")
 *   --phone +9647500000000    E.164 phone for users.phone
 *   --dob 1995-01-01          date of birth (drives the 18+ tour age gate)
 *   --accept-terms            also record Terms consent, so the account does
 *                             not stop at the Terms screen. Off by default:
 *                             `termsAcceptedAt` is consent evidence for App
 *                             Store review, and writing it for someone who
 *                             never tapped Accept makes that evidence a lie.
 *                             Use it only on accounts you own.
 *   --delete                  remove the account and its profile document.
 *
 * Credentials: set GOOGLE_APPLICATION_CREDENTIALS to a service-account key,
 * or drop the key in `secrets/` (gitignored) and it is picked up
 * automatically.
 */

const fs = require("fs");
const path = require("path");
const { createRequire } = require("module");

// The seed scripts live in tool/ but the dependency tree is in functions/, so
// a plain `require("firebase-admin/app")` from here fails. Resolve as though
// we were inside functions/ instead — via createRequire rather than an
// absolute path into node_modules, because firebase-admin's subpath entries
// ("/app", "/auth", "/firestore") come from its package exports map, which
// only applies to a real package-name resolution.
const repoRoot = path.join(__dirname, "..");
const fromFunctions = createRequire(
  path.join(repoRoot, "functions", "package.json"),
);
function admin(mod) {
  try {
    return require(mod);
  } catch (e) {
    return fromFunctions(mod);
  }
}

const { initializeApp, cert, applicationDefault } = admin("firebase-admin/app");
const { getAuth } = admin("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = admin("firebase-admin/firestore");

// ---------------------------------------------------------------- arguments

const argv = process.argv.slice(2);
const BOOLEAN_FLAGS = ["accept-terms", "delete"];

function flag(name) {
  const i = argv.indexOf("--" + name);
  if (i === -1) return undefined;
  return argv[i + 1];
}
const has = (name) => argv.includes("--" + name);

const positional = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i].startsWith("--")) {
    // Skip the flag's value too, unless it is a bare boolean flag.
    if (!BOOLEAN_FLAGS.includes(argv[i].slice(2))) i++;
    continue;
  }
  positional.push(argv[i]);
}

const email = positional[0];
const password = positional[1];
const displayName = flag("name") || "Test User";
const phone = flag("phone") || null;
const dobRaw = flag("dob") || "1995-01-01";
const acceptTerms = has("accept-terms");
const deleteMode = has("delete");

function die(message) {
  console.error("\n✗ " + message + "\n");
  process.exit(1);
}

if (!email) {
  die(
    "Usage: node tool/seed_test_account.js <email> <password> [--name ...] " +
      "[--phone +964...] [--dob YYYY-MM-DD] [--accept-terms]",
  );
}
// Mirrors `isStrongEnough()` in functions/index.js — the app's own policy
// (SECURITY.md 6.1b), which is stricter than Firebase Auth's 6-character
// floor. A test account that could not have been created through the real
// Register screen is a test account that proves less than it looks like.
function isStrongEnough(p) {
  return (
    p.length >= 8 &&
    /[A-Z]/.test(p) &&
    /[a-z]/.test(p) &&
    /[^A-Za-z0-9]/.test(p)
  );
}

if (!deleteMode && !password) {
  die("A password is required.");
}
if (!deleteMode && !isStrongEnough(password)) {
  die(
    "Password does not meet this app's policy (SECURITY.md 6.1b): at least " +
      "8 characters, with an upper-case letter, a lower-case letter and a " +
      "symbol.",
  );
}
const dob = new Date(dobRaw + "T00:00:00Z");
if (Number.isNaN(dob.getTime())) die("--dob is not a date: " + dobRaw);
if (phone && !/^\+[1-9]\d{6,14}$/.test(phone)) {
  die("--phone must be E.164, e.g. +9647500000000 (got: " + phone + ")");
}

// -------------------------------------------------------------- credentials

function credential() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) return applicationDefault();
  const dir = path.join(repoRoot, "secrets");
  const key = fs.existsSync(dir)
    ? fs.readdirSync(dir).find((f) => f.endsWith(".json"))
    : undefined;
  if (!key) {
    die(
      "No service-account key found. Set GOOGLE_APPLICATION_CREDENTIALS, or " +
        "put the key JSON in secrets/ (gitignored).",
    );
  }
  console.log("Using service-account key secrets/" + key);
  return cert(require(path.join(dir, key)));
}

initializeApp({ credential: credential() });
const auth = getAuth();
const db = getFirestore();

// --------------------------------------------------------------------- main

async function main() {
  let user = null;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }

  if (deleteMode) {
    if (!user) {
      console.log("Nothing to delete — no account for " + email + ".");
      return;
    }
    await db.collection("users").doc(user.uid).delete();
    await auth.deleteUser(user.uid);
    console.log(
      "Deleted " + email + " (uid " + user.uid + ") and its users/ document.",
    );
    return;
  }

  if (user) {
    user = await auth.updateUser(user.uid, {
      password,
      displayName,
      emailVerified: true,
      ...(phone ? { phoneNumber: phone } : {}),
    });
    console.log(
      "Reset the existing account " + email + " (uid " + user.uid + ").",
    );
  } else {
    user = await auth.createUser({
      email,
      password,
      displayName,
      emailVerified: true,
      ...(phone ? { phoneNumber: phone } : {}),
    });
    console.log("Created " + email + " (uid " + user.uid + ").");
  }

  // `role` is deliberately "user", never "admin". An admin test account is a
  // separate decision with its own blast radius — see SECURITY.md.
  const profile = {
    name: displayName,
    email,
    emailVerified: true,
    ...(phone ? { phone, phoneVerified: true } : {}),
    dateOfBirth: Timestamp.fromDate(dob),
    mfaEnrolled: false,
    mfaMethods: [],
    preferredLanguage: "en",
    preferredCurrency: "USD",
    role: "user",
    updatedAt: FieldValue.serverTimestamp(),
    source: "manual",
  };

  if (acceptTerms) {
    let version = 1;
    const terms = await db
      .collection("legal_documents")
      .doc("terms_of_service")
      .get();
    if (terms.exists && typeof terms.data().version === "number") {
      version = terms.data().version;
    }
    profile.termsAcceptedAt = FieldValue.serverTimestamp();
    profile.termsVersion = version;
    console.log("Recorded Terms consent at version " + version + ".");
  }

  const ref = db.collection("users").doc(user.uid);
  const existing = await ref.get();
  if (!existing.exists) profile.createdAt = FieldValue.serverTimestamp();
  await ref.set(profile, { merge: true });

  console.log("Wrote users/" + user.uid + ".");
  console.log(
    "\n✓ Sign in with " + email + " and the password you passed in.",
  );
  if (!acceptTerms) {
    console.log(
      "  (No Terms consent recorded — pass --accept-terms if the app stops " +
        "you at the Terms screen.)",
    );
  }
}

main().catch((e) => {
  console.error("\n✗ Failed:", e.message || e);
  process.exit(1);
});
