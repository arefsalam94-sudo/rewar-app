/**
 * Grants, revokes and inspects the `admin: true` Firebase Auth custom claim —
 * the claim every `isAdmin()` gate in `firestore.rules` checks.
 *
 * ## Why this is a local operator script and not a Cloud Function
 *
 * `SECURITY.md` section 3 says the claim is "set through a Cloud Function
 * (never set directly from a client)". The binding requirement there is the
 * parenthetical: **a client must never be able to elevate itself.** This
 * script satisfies that more strictly than a callable would, because there is
 * no deployed endpoint to attack, guess, or forget to protect — the only way
 * to run it is to already hold a service-account key.
 *
 * It is also the only option available today: Cloud Functions require the
 * Blaze plan, which this project is deliberately not on yet. When a callable
 * is eventually added, it must itself be gated on `request.auth.token.admin`
 * so only an existing admin can mint another — and the first admin will still
 * have to be created with this script, because that bootstrap cannot be done
 * by an endpoint that requires an admin to call it.
 *
 * ## The Flutter app has no counterpart to this file, on purpose
 *
 * Nothing in `lib/` can set a custom claim. The client SDK has no such API —
 * only the Admin SDK does, and the Admin SDK never ships in an app bundle.
 *
 * ## Usage
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     node tool/admin_claim.js inspect <uid>
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     node tool/admin_claim.js grant <uid> --yes
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     node tool/admin_claim.js revoke <uid> --yes
 *
 * `inspect` never writes. `grant` and `revoke` refuse to run without `--yes`,
 * and always print the before/after claims.
 *
 * A UID is required. Email and display name are deliberately NOT accepted as
 * selectors: both are mutable and non-unique in ways a UID is not, and
 * "grant admin to the account called X" is exactly the instruction that
 * elevates the wrong person. Use `inspect` to confirm you have the right UID
 * — it prints the email and display name so you can check before writing.
 *
 * ## The claim does not reach the client until its ID token refreshes
 *
 * A custom claim is baked into the ID token at issue time. An already
 * signed-in user keeps their old token — and therefore their old
 * permissions — until it is refreshed. Firebase refreshes automatically about
 * every hour, or immediately on `user.getIdToken(true)` / a fresh sign-in.
 *
 * That cuts both ways and the revoke case is the one that matters:
 *
 * - **Granting** admin: the new admin must sign out and back in (or the app
 *   must call `getIdToken(true)`) before the rules will let them write.
 * - **Revoking** admin: the ex-admin KEEPS admin access until their current
 *   ID token expires — up to an hour. `revoke` therefore also calls
 *   `revokeRefreshTokens`, which stops them obtaining a *new* token, but the
 *   one already in their hand stays valid until it expires. If you are
 *   revoking because an account is compromised, disable the account too.
 */

// firebase-admin is required lazily inside main(), not at module load. The
// exported helpers below all take an `auth` instance as a parameter, so a test
// can exercise them with its own emulator-backed instance without this file
// needing to resolve the SDK from its own directory.
const CLAIM = "admin";

/**
 * Returns the claims to write for a given change, preserving everything else.
 *
 * Pure and exported so the merge behaviour can be tested without a project.
 * Revoking DELETES the key rather than setting `admin: false`: the rules check
 * `== true`, so both deny, and an absent claim keeps the token smaller and
 * leaves no misleading "admin: false" to misread later.
 *
 * @param {object|undefined|null} existing the user's current customClaims
 * @param {boolean} makeAdmin true to grant, false to revoke
 * @returns {object|null} claims to pass to setCustomUserClaims (null = clear)
 */
function mergeAdminClaim(existing, makeAdmin) {
  const next = { ...(existing || {}) };
  if (makeAdmin) {
    next[CLAIM] = true;
  } else {
    delete next[CLAIM];
  }
  // Firebase treats null as "remove every custom claim". Only send it when
  // nothing is left, so we never clobber claims we did not put there.
  return Object.keys(next).length === 0 ? null : next;
}

/** True when the record currently carries the admin claim. */
function isAdmin(claims) {
  return (claims || {})[CLAIM] === true;
}

/** Reads a user and returns the details needed to confirm identity. */
async function inspect(auth, uid) {
  const user = await auth.getUser(uid);
  return {
    uid: user.uid,
    email: user.email || null,
    displayName: user.displayName || null,
    disabled: user.disabled,
    claims: user.customClaims || {},
    isAdmin: isAdmin(user.customClaims),
  };
}

/**
 * Grants or revokes the admin claim.
 *
 * @returns {{before: object, after: object, changed: boolean}}
 */
async function setAdmin(auth, uid, makeAdmin, { revokeTokens = true } = {}) {
  const user = await auth.getUser(uid);
  const before = user.customClaims || {};

  if (isAdmin(before) === makeAdmin) {
    return { before, after: before, changed: false };
  }

  const next = mergeAdminClaim(before, makeAdmin);
  await auth.setCustomUserClaims(uid, next);

  // Forces the client to obtain a fresh ID token, which is the only way the
  // new claim reaches the rules. On revoke this also stops the ex-admin
  // minting further tokens — see the note at the top about the window where
  // their existing token is still valid.
  if (revokeTokens) await auth.revokeRefreshTokens(uid);

  const after = (await auth.getUser(uid)).customClaims || {};
  return { before, after, changed: true };
}

// --- CLI -----------------------------------------------------------------

const UID_PATTERN = /^[A-Za-z0-9_-]{6,128}$/;

function usage() {
  console.log(
    [
      "Usage:",
      "  node tool/admin_claim.js inspect <uid>",
      "  node tool/admin_claim.js grant   <uid> --yes",
      "  node tool/admin_claim.js revoke  <uid> --yes",
      "",
      "A UID is required; email and display name are not accepted.",
      "Run inspect first to confirm you have the right account.",
    ].join("\n")
  );
}

async function main(argv) {
  const [command, uid, ...rest] = argv;
  const confirmed = rest.includes("--yes");

  if (!command || ["-h", "--help", "help"].includes(command)) {
    usage();
    return 0;
  }
  if (!["inspect", "grant", "revoke"].includes(command)) {
    console.error(`Unknown command: ${command}\n`);
    usage();
    return 2;
  }
  if (!uid) {
    console.error("A Firebase Auth UID is required.\n");
    usage();
    return 2;
  }
  if (uid.includes("@")) {
    console.error(
      `"${uid}" looks like an email address. This tool takes a UID only —\n` +
        "an email is mutable and is the wrong thing to key admin rights on.\n" +
        "Find the UID in Firebase Console -> Authentication -> Users."
    );
    return 2;
  }
  if (!UID_PATTERN.test(uid)) {
    console.error(`"${uid}" is not a plausible Firebase Auth UID.`);
    return 2;
  }

  const { initializeApp, applicationDefault } = require("firebase-admin/app");
  const { getAuth } = require("firebase-admin/auth");

  initializeApp({ credential: applicationDefault() });
  const auth = getAuth();
  const projectId =
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    "(from credentials)";
  const emulator = process.env.FIREBASE_AUTH_EMULATOR_HOST;

  console.log(`project : ${projectId}${emulator ? ` (EMULATOR ${emulator})` : ""}`);

  let current;
  try {
    current = await inspect(auth, uid);
  } catch (error) {
    console.error(`\nNo such user: ${uid}\n  ${error.message}`);
    return 1;
  }

  console.log(`uid     : ${current.uid}`);
  console.log(`email   : ${current.email ?? "(none)"}`);
  console.log(`name    : ${current.displayName ?? "(none)"}`);
  console.log(`disabled: ${current.disabled}`);
  console.log(`claims  : ${JSON.stringify(current.claims)}`);
  console.log(`admin   : ${current.isAdmin}`);

  if (command === "inspect") return 0;

  const makeAdmin = command === "grant";
  if (current.isAdmin === makeAdmin) {
    console.log(`\nNothing to do — admin is already ${makeAdmin}.`);
    return 0;
  }

  if (!confirmed) {
    console.error(
      `\nRefusing to ${command} without --yes.\n` +
        `Re-run: node tool/admin_claim.js ${command} ${uid} --yes`
    );
    return 3;
  }

  const { before, after } = await setAdmin(auth, uid, makeAdmin);
  console.log(`\n${command.toUpperCase()} applied to ${uid}`);
  console.log(`  before: ${JSON.stringify(before)}`);
  console.log(`  after : ${JSON.stringify(after)}`);
  console.log(
    "\nRefresh tokens revoked. The account must sign in again (or call\n" +
      "getIdToken(true)) before the rules see this change."
  );
  if (!makeAdmin) {
    console.log(
      "NOTE: an ID token already issued to this account stays valid until it\n" +
        "expires (up to ~1 hour). If this revoke is a security response,\n" +
        "disable the account as well."
    );
  }
  return 0;
}

module.exports = { mergeAdminClaim, isAdmin, inspect, setAdmin, CLAIM, main };

if (require.main === module) {
  main(process.argv.slice(2))
    .then((code) => process.exit(code))
    .catch((error) => {
      console.error(`\nFailed: ${error.message}`);
      process.exit(1);
    });
}
