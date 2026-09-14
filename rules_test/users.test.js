// users/{uid} — SECURITY.md 6.1c.
//
// The question these tests answer is not "can the client write?" but "WHICH
// fields can it write?". A user who could set `role: "admin"` on their own
// document would grant themselves the admin panel.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs } from 'firebase/firestore';
import { makeEnv, seed, ALICE, BOB, validProfile } from './harness.js';

let env, alice, bob, guest, admin;

before(async () => {
  env = await makeEnv('users');
  alice = env.authenticatedContext(ALICE).firestore();
  bob = env.authenticatedContext(BOB).firestore();
  guest = env.unauthenticatedContext().firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());

// Each describe owns a single beforeEach that clears and then seeds in one
// hook. Splitting those across an outer and an inner hook makes the order
// between them ambiguous, and a test that reads a missing document fails with
// a rules "Null value error" that looks like a rules bug but is not.
const reset = async (seedFn) => {
  await env.clearFirestore();
  if (seedFn) await seed(env, seedFn);
};

describe('users — create', () => {
  beforeEach(async () => reset());

  test('owner may create a valid profile', async () => {
    await assertSucceeds(setDoc(doc(alice, 'users', ALICE), validProfile()));
  });

  test('owner may include the optional allow-listed fields', async () => {
    await assertSucceeds(setDoc(doc(alice, 'users', ALICE), {
      ...validProfile(),
      gender: 'female',
      preferredLanguage: 'ku',
      preferredCurrency: 'IQD',
      profileImageUrl: 'https://example.com/a.jpg',
      termsAcceptedAt: new Date(),
      termsVersion: 3,
      source: 'manual',
    }));
  });

  // The whole point of the allow-list.
  for (const [field, value] of [
    ['role', 'admin'],
    ['emailVerified', true],
    ['phoneVerified', true],
    ['mfaEnrolled', true],
    ['mfaMethods', ['sms']],
    ['hasPaymentMethod', true],
    ['passwordChangedAt', new Date()],
  ]) {
    test(`owner may NOT set server-owned field: ${field}`, async () => {
      await assertFails(setDoc(doc(alice, 'users', ALICE), {
        ...validProfile(), [field]: value,
      }));
    });
  }

  test('rejects an unknown field outside the allow-list', async () => {
    await assertFails(setDoc(doc(alice, 'users', ALICE), {
      ...validProfile(), isVip: true,
    }));
  });

  test('rejects a name shorter than 2 characters', async () => {
    await assertFails(setDoc(doc(alice, 'users', ALICE), { ...validProfile(), name: 'A' }));
  });

  test('rejects a name longer than 100 characters', async () => {
    await assertFails(setDoc(doc(alice, 'users', ALICE), { ...validProfile(), name: 'x'.repeat(101) }));
  });

  test('rejects a gender outside the three permitted values', async () => {
    await assertFails(setDoc(doc(alice, 'users', ALICE), { ...validProfile(), gender: 'other-thing' }));
  });

  test('rejects an unsupported currency', async () => {
    await assertFails(setDoc(doc(alice, 'users', ALICE), { ...validProfile(), preferredCurrency: 'GBP' }));
  });

  test('rejects an unsupported language', async () => {
    await assertFails(setDoc(doc(alice, 'users', ALICE), { ...validProfile(), preferredLanguage: 'fr' }));
  });

  test('rejects a dateOfBirth that is not a timestamp', async () => {
    await assertFails(setDoc(doc(alice, 'users', ALICE), { ...validProfile(), dateOfBirth: '1990-01-01' }));
  });
});

describe('users — cross-user access', () => {
  beforeEach(async () => reset(async (db) => {
    await setDoc(doc(db, 'users', BOB), validProfile('bob@example.com'));
  }));

  test("a user may NOT read another user's profile", async () => {
    await assertFails(getDoc(doc(alice, 'users', BOB)));
  });

  test("a user may NOT write another user's profile", async () => {
    await assertFails(setDoc(doc(alice, 'users', BOB), validProfile('bob@example.com')));
  });

  test('an admin may NOT read an arbitrary user profile', async () => {
    // users is owner-only in both directions; the admin claim grants no
    // special read here, and should not.
    await assertFails(getDoc(doc(admin, 'users', BOB)));
  });

  test('a guest may not read any profile', async () => {
    await assertFails(getDoc(doc(guest, 'users', BOB)));
  });

  test('nobody may enumerate the user base', async () => {
    await assertFails(getDocs(collection(alice, 'users')));
    await assertFails(getDocs(collection(admin, 'users')));
  });
});

describe('users — update and delete', () => {
  beforeEach(async () => reset(async (db) => {
    await setDoc(doc(db, 'users', ALICE), {
      ...validProfile(),
      hasPaymentMethod: false, // server-owned, already on the document
      role: 'user',
    });
  }));

  test('owner may update an allow-listed field', async () => {
    await assertSucceeds(updateDoc(doc(alice, 'users', ALICE), { name: 'Alice Renamed' }));
  });

  test('a partial update need not resend every field', async () => {
    await assertSucceeds(updateDoc(doc(alice, 'users', ALICE), { preferredCurrency: 'EUR' }));
  });

  test('owner may NOT escalate to admin on update', async () => {
    await assertFails(updateDoc(doc(alice, 'users', ALICE), { role: 'admin' }));
  });

  test('owner may NOT flip a server-owned flag on update', async () => {
    await assertFails(updateDoc(doc(alice, 'users', ALICE), { hasPaymentMethod: true }));
    await assertFails(updateDoc(doc(alice, 'users', ALICE), { emailVerified: true }));
  });

  test('owner may NOT change the sign-in email', async () => {
    await assertFails(updateDoc(doc(alice, 'users', ALICE), { email: 'attacker@example.com' }));
  });

  test('a server-owned field already on the document does not block a valid update', async () => {
    // The rule compares only CHANGED keys, so hasPaymentMethod sitting on the
    // document must not make every update fail.
    await assertSucceeds(updateDoc(doc(alice, 'users', ALICE), { name: 'Still Fine' }));
  });

  test('owner may NOT delete their own profile', async () => {
    // Deletion cascades through a Cloud Function (SECURITY.md 9).
    await assertFails(deleteDoc(doc(alice, 'users', ALICE)));
  });

  test('owner may read their own profile', async () => {
    await assertSucceeds(getDoc(doc(alice, 'users', ALICE)));
  });
});
