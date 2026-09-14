// Can a Firestore document ever grant admin? — SECURITY.md 3.
//
// `isAdmin()` reads `request.auth.token.admin`, and the rules contain no
// `get()` or `exists()` lookup at all, so no document can influence an access
// decision. That is a property worth testing rather than asserting: a future
// rule that "helpfully" reads users/{uid}.role to decide admin would compile,
// pass every other test in this suite, and quietly turn a client-writable
// field into a privilege escalation.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';
import { makeEnv, seed, ALICE, RULES_PATH, validHelpTopic } from './harness.js';

let env, alice, admin;

// Every shape someone might hope grants admin from inside Firestore.
const IMPOSTOR_PROFILES = [
  ['role: "admin"', { role: 'admin' }],
  ['admin: true', { admin: true }],
  ['isAdmin: true', { isAdmin: true }],
  ['claims.admin: true', { claims: { admin: true } }],
  ['token.admin: true', { token: { admin: true } }],
  ['customClaims.admin: true', { customClaims: { admin: true } }],
  ['permissions: ["admin"]', { permissions: ['admin'] }],
];

// Collections whose writes are admin-only.
const ADMIN_ONLY = [
  ['nature_spots', 'rawanduz-canyon', { reviewScore: 10 }],
  ['tours', 'gali-sherana', { pricePerPerson: 0 }],
  ['featured', 'slide-1', { title: { en: 'Hacked' } }],
  ['currency_rates', 'latest', { rates: { IQD: 1 } }],
  ['legal_documents', 'terms_of_service', { version: 99 }],
  ['help_topics', 'account_signin', { order: 99 }],
];

before(async () => {
  env = await makeEnv('adminbypass');
  alice = env.authenticatedContext(ALICE).firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, async (db) => {
    await setDoc(doc(db, 'nature_spots', 'rawanduz-canyon'), { active: true });
    await setDoc(doc(db, 'tours', 'gali-sherana'), { active: true });
    await setDoc(doc(db, 'featured', 'slide-1'), { order: 1 });
    await setDoc(doc(db, 'legal_documents', 'terms_of_service'), { version: 1 });
    await setDoc(doc(db, 'currency_rates', 'latest'), { base: 'USD' });
    await setDoc(doc(db, 'help_topics', 'account_signin'), validHelpTopic());
  });
});

describe('the rules never consult a document to decide admin', () => {
  test('firestore.rules contains no get() or exists() lookup', () => {
    // A static guard, deliberately. The behavioural tests below can only
    // disprove the lookups someone has already thought of; this catches the
    // introduction of ANY document read into an access decision.
    const rules = readFileSync(RULES_PATH, 'utf8');
    const lookups = rules.match(/\b(get|exists|getAfter)\s*\(\s*\//g) || [];
    if (lookups.length) {
      throw new Error(
        `firestore.rules now performs ${lookups.length} document lookup(s) ` +
          `in access decisions: ${lookups.join(', ')}. If that is deliberate, ` +
          'confirm it cannot read a client-writable field before relaxing ' +
          'this test.',
      );
    }
  });

  test('isAdmin() is defined against the auth token', () => {
    const rules = readFileSync(RULES_PATH, 'utf8');
    const match = rules.match(/function isAdmin\(\)\s*\{([\s\S]*?)\}/);
    if (!match) throw new Error('isAdmin() not found in firestore.rules');
    const body = match[1];
    if (!body.includes('request.auth.token.admin')) {
      throw new Error('isAdmin() no longer reads request.auth.token.admin');
    }
  });
});

describe('a self-written Firestore field grants nothing', () => {
  for (const [label, extra] of IMPOSTOR_PROFILES) {
    test(`a user cannot even WRITE ${label} onto their own profile`, async () => {
      // First line of defence: the users allow-list (SECURITY.md 6.1c).
      await assertFails(setDoc(doc(alice, 'users', ALICE), {
        name: 'Alice Example',
        email: 'alice@example.com',
        phone: '+9647500000000',
        dateOfBirth: new Date('1990-01-01T00:00:00Z'),
        ...extra,
      }));
    });

    test(`${label} planted server-side still grants no admin write`, async () => {
      // Second, independent line of defence. Seeded with rules DISABLED, so
      // this simulates the field existing by any means at all — a compromised
      // admin panel, a bad migration, a Cloud Function bug. The rules must
      // still refuse, because they never look at it.
      await seed(env, async (db) => {
        await setDoc(doc(db, 'users', ALICE), {
          name: 'Alice Example',
          email: 'alice@example.com',
          ...extra,
        });
      });

      for (const [col, id, patch] of ADMIN_ONLY) {
        await assertFails(updateDoc(doc(alice, col, id), patch));
      }
    });
  }

  test('the planted document is really there — the denials are not vacuous', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users', ALICE), {
        name: 'Alice Example',
        email: 'alice@example.com',
        role: 'admin',
        admin: true,
      });
    });

    const snapshot = await assertSucceeds(getDoc(doc(alice, 'users', ALICE)));
    if (snapshot.data().role !== 'admin' || snapshot.data().admin !== true) {
      throw new Error('the impostor fields were not seeded; test is vacuous');
    }
  });

  test('a real token claim DOES grant the same writes', async () => {
    // The control. Without this the suite could pass because the writes are
    // broken for everyone, rather than because the claim is what matters.
    for (const [col, id, patch] of ADMIN_ONLY) {
      await assertSucceeds(updateDoc(doc(admin, col, id), patch));
    }
  });

  test('a planted field cannot delete admin-only content either', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users', ALICE), {
        name: 'Alice Example',
        email: 'alice@example.com',
        role: 'admin',
      });
    });

    await assertFails(deleteDoc(doc(alice, 'legal_documents', 'terms_of_service')));
    await assertFails(deleteDoc(doc(alice, 'help_topics', 'account_signin')));
  });
});
