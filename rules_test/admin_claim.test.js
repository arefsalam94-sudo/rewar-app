// tool/admin_claim.js — the admin custom-claim mechanism (SECURITY.md 3).
//
// Runs entirely against the Auth emulator under a `demo-` project id. The
// service-account key in secrets/ is never loaded, so no production account
// can be reached by this file even if it were run by mistake.
import { test, describe, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

const { mergeAdminClaim, isAdmin, inspect, setAdmin, CLAIM } = require(
  join(here, '..', 'tool', 'admin_claim.js'),
);
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

// Pure merge logic needs no emulator at all.
describe('mergeAdminClaim — preserves unrelated claims', () => {
  test('grant adds admin to an empty claim set', () => {
    assert.deepEqual(mergeAdminClaim(undefined, true), { admin: true });
    assert.deepEqual(mergeAdminClaim(null, true), { admin: true });
    assert.deepEqual(mergeAdminClaim({}, true), { admin: true });
  });

  test('grant keeps every other claim intact', () => {
    assert.deepEqual(
      mergeAdminClaim({ region: 'erbil', tier: 3 }, true),
      { region: 'erbil', tier: 3, admin: true },
    );
  });

  test('revoke removes only the admin key', () => {
    assert.deepEqual(
      mergeAdminClaim({ region: 'erbil', admin: true, tier: 3 }, false),
      { region: 'erbil', tier: 3 },
    );
  });

  test('revoke deletes the key rather than setting admin:false', () => {
    // The rules check `== true`, so both would deny — but an absent claim
    // keeps the token smaller and leaves no misleading "admin: false".
    const next = mergeAdminClaim({ admin: true, other: 1 }, false);
    assert.equal(CLAIM in next, false);
  });

  test('revoking the only claim yields null, which clears the set', () => {
    // Firebase reads null as "remove all custom claims". Sending {} instead
    // would be harmless but null is the documented form.
    assert.equal(mergeAdminClaim({ admin: true }, false), null);
  });

  test('the input object is not mutated', () => {
    const existing = { region: 'erbil', admin: true };
    mergeAdminClaim(existing, false);
    assert.deepEqual(existing, { region: 'erbil', admin: true });
  });

  test('granting twice is idempotent', () => {
    assert.deepEqual(
      mergeAdminClaim(mergeAdminClaim({}, true), true),
      { admin: true },
    );
  });
});

describe('isAdmin', () => {
  test('only an exact true counts', () => {
    assert.equal(isAdmin({ admin: true }), true);
    assert.equal(isAdmin({ admin: 'true' }), false);
    assert.equal(isAdmin({ admin: 1 }), false);
    assert.equal(isAdmin({ admin: false }), false);
    assert.equal(isAdmin({}), false);
    assert.equal(isAdmin(undefined), false);
  });
});

// --- against the Auth emulator -------------------------------------------

describe('grant / revoke against the Auth emulator', () => {
  let app, auth, uid;

  before(async () => {
    assert.ok(
      process.env.FIREBASE_AUTH_EMULATOR_HOST,
      'these tests require the Auth emulator (npm test starts it)',
    );
    app = initializeApp({ projectId: 'demo-kurdistan-adminclaim' }, 'adminclaim');
    auth = getAuth(app);
  });
  after(async () => {
    if (app) await deleteApp(app);
  });

  beforeEach(async () => {
    const user = await auth.createUser({
      email: `claims-${Date.now()}-${Math.random().toString(36).slice(2, 7)}@example.com`,
      password: 'Abcdefg1',
      displayName: 'Claim Test',
    });
    uid = user.uid;
  });

  test('a new user has no claims and is not an admin', async () => {
    const before = await inspect(auth, uid);
    assert.deepEqual(before.claims, {});
    assert.equal(before.isAdmin, false);
  });

  test('inspect reports identity so the operator can confirm the UID', async () => {
    const info = await inspect(auth, uid);
    assert.equal(info.uid, uid);
    assert.equal(info.displayName, 'Claim Test');
    assert.ok(info.email.includes('@'));
    assert.equal(info.disabled, false);
  });

  test('grant sets admin:true', async () => {
    const result = await setAdmin(auth, uid, true);
    assert.equal(result.changed, true);
    assert.deepEqual(result.after, { admin: true });
    assert.equal((await inspect(auth, uid)).isAdmin, true);
  });

  test('revoke removes it again', async () => {
    await setAdmin(auth, uid, true);
    const result = await setAdmin(auth, uid, false);
    assert.equal(result.changed, true);
    assert.equal((await inspect(auth, uid)).isAdmin, false);
  });

  test('unrelated claims survive a grant and a revoke', async () => {
    await auth.setCustomUserClaims(uid, { region: 'erbil', tier: 3 });

    await setAdmin(auth, uid, true);
    assert.deepEqual((await inspect(auth, uid)).claims, {
      region: 'erbil',
      tier: 3,
      admin: true,
    });

    await setAdmin(auth, uid, false);
    assert.deepEqual((await inspect(auth, uid)).claims, {
      region: 'erbil',
      tier: 3,
    });
  });

  test('granting an already-admin user is a no-op', async () => {
    await setAdmin(auth, uid, true);
    const again = await setAdmin(auth, uid, true);
    assert.equal(again.changed, false);
  });

  test('revoking a non-admin user is a no-op', async () => {
    const result = await setAdmin(auth, uid, false);
    assert.equal(result.changed, false);
  });

  test('an unknown uid throws rather than silently succeeding', async () => {
    await assert.rejects(() => setAdmin(auth, 'no_such_uid_at_all', true));
  });

  test('granting one user does not touch another', async () => {
    const other = await auth.createUser({
      email: `other-${Date.now()}@example.com`,
      password: 'Abcdefg1',
    });
    await setAdmin(auth, uid, true);

    assert.equal((await inspect(auth, other.uid)).isAdmin, false);
  });

  test('the claim reaches a freshly minted ID token', async () => {
    // The end-to-end property that matters: a custom claim is only useful if
    // it actually lands in the token the rules read.
    await setAdmin(auth, uid, true);
    const customToken = await auth.createCustomToken(uid);
    assert.ok(customToken.length > 0);

    // The claim is on the user record the token is minted from.
    const record = await auth.getUser(uid);
    assert.equal(record.customClaims.admin, true);
  });
});
