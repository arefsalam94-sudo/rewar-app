// Everything else: public catalog reads, admin-only writes, bookings,
// the server-only collections, and the catch-all.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
} from 'firebase/firestore';
import { makeEnv, seed, ALICE, BOB, SERVER_ONLY, NO_RULE } from './harness.js';

let env, alice, bob, guest, admin;

before(async () => {
  env = await makeEnv('catalog');
  alice = env.authenticatedContext(ALICE).firestore();
  bob = env.authenticatedContext(BOB).firestore();
  guest = env.unauthenticatedContext().firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, async (db) => {
    await setDoc(doc(db, 'nature_spots', 'rawanduz-canyon'), { name: { en: 'Rawanduz' }, active: true, highlighted: true });
    await setDoc(doc(db, 'tours', 'gali-sherana'), { name: { en: 'Gali Sherana' }, active: true, pricePerPerson: 50 });
    await setDoc(doc(db, 'featured', 'slide-1'), { title: { en: 'Slide' }, order: 1 });
    await setDoc(doc(db, 'legal_documents', 'terms_of_service'), { version: 1, legalReviewed: false });
    await setDoc(doc(db, 'currency_rates', 'latest'), { base: 'USD', rates: { IQD: 1310 } });
    await setDoc(doc(db, 'bookings', 'bk1'), { userId: ALICE, status: 'confirmed', totalPrice: 100 });
  });
});

describe('public catalog — reads intentionally allowed', () => {
  test('a guest may read and list nature_spots', async () => {
    await assertSucceeds(getDoc(doc(guest, 'nature_spots', 'rawanduz-canyon')));
    await assertSucceeds(getDocs(collection(guest, 'nature_spots')));
  });

  test('a guest may read and list tours', async () => {
    await assertSucceeds(getDoc(doc(guest, 'tours', 'gali-sherana')));
    await assertSucceeds(getDocs(collection(guest, 'tours')));
  });

  test('a guest may read and list featured', async () => {
    await assertSucceeds(getDoc(doc(guest, 'featured', 'slide-1')));
    await assertSucceeds(getDocs(collection(guest, 'featured')));
  });

  test('a guest may fetch legal documents by id but NOT enumerate them', async () => {
    await assertSucceeds(getDoc(doc(guest, 'legal_documents', 'terms_of_service')));
    await assertFails(getDocs(collection(guest, 'legal_documents')));
  });

  test('a guest may fetch currency rates by id but NOT enumerate them', async () => {
    await assertSucceeds(getDoc(doc(guest, 'currency_rates', 'latest')));
    await assertFails(getDocs(collection(guest, 'currency_rates')));
  });
});

describe('catalog — writes are admin-only', () => {
  const targets = [
    ['nature_spots', 'rawanduz-canyon', { reviewScore: 10 }],
    ['tours', 'gali-sherana', { pricePerPerson: 0 }],
    ['featured', 'slide-1', { title: { en: 'Hacked' } }],
    ['currency_rates', 'latest', { rates: { IQD: 1 } }],
    ['legal_documents', 'terms_of_service', { version: 99 }],
  ];

  for (const [col, id, patch] of targets) {
    test(`a signed-in non-admin may NOT write ${col}`, async () => {
      await assertFails(updateDoc(doc(alice, col, id), patch));
    });
    test(`a guest may NOT write ${col}`, async () => {
      await assertFails(updateDoc(doc(guest, col, id), patch));
    });
    test(`a simulated admin MAY write ${col}`, async () => {
      await assertSucceeds(updateDoc(doc(admin, col, id), patch));
    });
    test(`a simulated admin may delete from ${col}`, async () => {
      await assertSucceeds(deleteDoc(doc(admin, col, id)));
    });
  }

  test('the aggregates a client must never write are covered by the same rule', async () => {
    // reviewScore / ratingCount / ratingBreakdown are derived by a Cloud
    // Function; a client that could write an average could give a competitor
    // a 2.0 without leaving a review.
    await assertFails(updateDoc(doc(alice, 'nature_spots', 'rawanduz-canyon'), {
      reviewScore: 2.0, ratingCount: 500, ratingBreakdown: { 1: 500 },
    }));
  });
});

describe('bookings — owner read, every client write denied', () => {
  test('the owner may read their own booking', async () => {
    await assertSucceeds(getDoc(doc(alice, 'bookings', 'bk1')));
  });

  test('the owner may list their own bookings', async () => {
    await assertSucceeds(getDocs(
      query(collection(alice, 'bookings'), where('userId', '==', ALICE)),
    ));
  });

  test("another user may NOT read someone else's booking", async () => {
    await assertFails(getDoc(doc(bob, 'bookings', 'bk1')));
  });

  test("a query filtered to another user's uid is rejected", async () => {
    await assertFails(getDocs(
      query(collection(bob, 'bookings'), where('userId', '==', ALICE)),
    ));
  });

  test('an unconstrained booking list is rejected', async () => {
    await assertFails(getDocs(collection(alice, 'bookings')));
  });

  test('a guest may not read bookings', async () => {
    await assertFails(getDoc(doc(guest, 'bookings', 'bk1')));
  });

  test('the owner may NOT create a booking', async () => {
    // A client that could create here could mint itself a confirmed booking
    // it never paid for.
    await assertFails(setDoc(doc(alice, 'bookings', 'forged'), {
      userId: ALICE, status: 'confirmed', totalPrice: 0,
    }));
  });

  test('the owner may NOT update a booking', async () => {
    await assertFails(updateDoc(doc(alice, 'bookings', 'bk1'), { status: 'cancelled' }));
  });

  test('the owner may NOT delete a booking', async () => {
    await assertFails(deleteDoc(doc(alice, 'bookings', 'bk1')));
  });

  test('even a simulated admin client may not write bookings', async () => {
    // Writes belong to the Admin SDK, which bypasses rules entirely — so the
    // rule denies every client, admin claim included.
    await assertFails(setDoc(doc(admin, 'bookings', 'forged2'), {
      userId: ALICE, status: 'confirmed', totalPrice: 0,
    }));
  });
});

describe('server-only collections are closed to every client', () => {
  for (const col of SERVER_ONLY) {
    test(`${col} — read denied for guest, user and admin`, async () => {
      await assertFails(getDoc(doc(guest, col, 'any')));
      await assertFails(getDoc(doc(alice, col, ALICE)));
      await assertFails(getDoc(doc(admin, col, ALICE)));
    });
    test(`${col} — write denied for guest, user and admin`, async () => {
      await assertFails(setDoc(doc(guest, col, 'any'), { x: 1 }));
      await assertFails(setDoc(doc(alice, col, ALICE), { x: 1 }));
      await assertFails(setDoc(doc(admin, col, ALICE), { x: 1 }));
    });
    test(`${col} — listing denied`, async () => {
      await assertFails(getDocs(collection(alice, col)));
    });
  }

  test('a signed-in user may not read their own pending verification code', async () => {
    // The document id IS the uid, so "deny read" is what stops a user
    // fetching their own code instead of receiving it by email.
    await seed(env, async (db) => {
      await setDoc(doc(db, 'email_verify_codes', ALICE), { hash: 'x', salt: 'y' });
    });
    await assertFails(getDoc(doc(alice, 'email_verify_codes', ALICE)));
  });
});

describe('catch-all — collections with no rule of their own', () => {
  for (const col of NO_RULE) {
    test(`${col} is denied to every caller`, async () => {
      await assertFails(getDoc(doc(guest, col, 'probe')));
      await assertFails(getDoc(doc(alice, col, 'probe')));
      await assertFails(getDoc(doc(admin, col, 'probe')));
      await assertFails(setDoc(doc(alice, col, 'probe'), { x: 1 }));
      await assertFails(setDoc(doc(admin, col, 'probe'), { x: 1 }));
    });
  }

  test('a deeply nested unknown path is denied', async () => {
    await assertFails(getDoc(doc(alice, 'nature_spots/rawanduz-canyon/secret_notes', 'x')));
    await assertFails(setDoc(doc(alice, 'nature_spots/rawanduz-canyon/secret_notes', 'x'), { a: 1 }));
  });

  test('the removed usernames collection stays closed', async () => {
    await assertFails(getDoc(doc(alice, 'usernames', 'kurdistan')));
    await assertFails(setDoc(doc(alice, 'usernames', 'kurdistan'), { uid: ALICE }));
  });
});

describe('unauthenticated access to user-owned data', () => {
  test('a guest may not touch users, favorites or bookings', async () => {
    await assertFails(getDoc(doc(guest, 'users', ALICE)));
    await assertFails(setDoc(doc(guest, 'users', ALICE), { name: 'Ghost' }));
    await assertFails(getDocs(collection(guest, 'favorites')));
    await assertFails(getDoc(doc(guest, 'bookings', 'bk1')));
  });
});
