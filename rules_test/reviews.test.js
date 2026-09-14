// nature_spots/{id}/reviews and tours/{id}/reviews, plus their votes —
// SECURITY.md 1c.
//
// The document id IS the author's uid. That is the whole design: it makes
// "one review per person per place" enforceable in a rule rather than merely
// intended.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
  serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { makeEnv, seed, ALICE, BOB, validReview, REVIEW_PARENTS } from './harness.js';

let env, alice, bob, guest, admin;

before(async () => {
  env = await makeEnv('reviews');
  alice = env.authenticatedContext(ALICE).firestore();
  bob = env.authenticatedContext(BOB).firestore();
  guest = env.unauthenticatedContext().firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());

// One hook per describe that clears and seeds together — see users.test.js.
const reset = async (seedFn) => {
  await env.clearFirestore();
  if (seedFn) await seed(env, seedFn);
};

const stamped = (uid = ALICE, over = {}) => ({
  ...validReview(uid),
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...over,
});

for (const parent of REVIEW_PARENTS) {
  const path = `${parent}/reviews`;
  const label = parent.split('/')[0];

  describe(`${label} reviews — create`, () => {
    beforeEach(async () => reset());

    test('author may write a review at their own uid', async () => {
      await assertSucceeds(setDoc(doc(alice, path, ALICE), stamped()));
    });

    test("author may NOT write a review at another user's uid", async () => {
      await assertFails(setDoc(doc(alice, path, BOB), stamped(BOB)));
    });

    test('userId must match the caller', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { userId: BOB })));
    });

    test('a guest may not write a review', async () => {
      await assertFails(setDoc(doc(guest, path, ALICE), stamped()));
    });

    // Half-step validation: the step check matters as much as the range,
    // because 3.7 is in range but no UI in this app can produce it.
    for (const rating of [0.5, 1, 2.5, 4.5, 5]) {
      test(`accepts valid half-step rating ${rating}`, async () => {
        await assertSucceeds(setDoc(doc(alice, path, ALICE), stamped(ALICE, { rating })));
      });
    }
    for (const rating of [0, 0.3, 3.7, 5.5, 6, -1]) {
      test(`rejects invalid rating ${rating}`, async () => {
        await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { rating })));
      });
    }
    test('rejects a non-numeric rating', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { rating: '5' })));
    });

    test('rejects a comment shorter than 3 characters', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { comment: 'ok' })));
    });

    test('rejects a comment longer than 1000 characters', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { comment: 'x'.repeat(1001) })));
    });

    test('rejects a userName longer than 80 characters', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { userName: 'x'.repeat(81) })));
    });

    test('rejects a status other than published', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { status: 'pending' })));
    });

    test('author may NOT set the server-owned helpfulCount', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, { helpfulCount: 9999 })));
    });

    test('rejects a back-dated createdAt', async () => {
      await assertFails(setDoc(doc(alice, path, ALICE), stamped(ALICE, {
        createdAt: Timestamp.fromDate(new Date('2020-01-01')),
      })));
    });
  });

  describe(`${label} reviews — read, update, delete`, () => {
    beforeEach(async () => reset(async (db) => {
      await setDoc(doc(db, path, ALICE), {
        ...validReview(ALICE),
        createdAt: Timestamp.fromDate(new Date('2026-01-01')),
        updatedAt: Timestamp.fromDate(new Date('2026-01-01')),
        helpfulCount: 7,
      });
    }));

    test('a published review is publicly readable', async () => {
      await assertSucceeds(getDoc(doc(guest, path, ALICE)));
    });

    test('a published review list is public', async () => {
      await assertSucceeds(getDocs(
        query(collection(guest, path), where('status', '==', 'published')),
      ));
    });

    test('author may update their own review', async () => {
      await assertSucceeds(updateDoc(doc(alice, path, ALICE), {
        comment: 'An edited but still reasonable review.',
        rating: 4,
        updatedAt: serverTimestamp(),
      }));
    });

    test('the existing helpfulCount does not block a valid edit', async () => {
      // Updates compare only changed keys, so the server-owned counter can
      // sit on the document without the author resending it.
      await assertSucceeds(updateDoc(doc(alice, path, ALICE), {
        comment: 'Another perfectly reasonable edit.',
        updatedAt: serverTimestamp(),
      }));
    });

    test('author may NOT raise helpfulCount', async () => {
      await assertFails(updateDoc(doc(alice, path, ALICE), {
        helpfulCount: 9999, updatedAt: serverTimestamp(),
      }));
    });

    test('author may NOT re-date createdAt to jump the sort order', async () => {
      await assertFails(updateDoc(doc(alice, path, ALICE), {
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      }));
    });

    test("another user may NOT update the review", async () => {
      await assertFails(updateDoc(doc(bob, path, ALICE), {
        comment: 'Vandalised by someone else.', updatedAt: serverTimestamp(),
      }));
    });

    test('author may delete their own review', async () => {
      await assertSucceeds(deleteDoc(doc(alice, path, ALICE)));
    });

    test('an admin may delete any review (moderation)', async () => {
      await assertSucceeds(deleteDoc(doc(admin, path, ALICE)));
    });

    test('another ordinary user may NOT delete it', async () => {
      await assertFails(deleteDoc(doc(bob, path, ALICE)));
    });
  });

  describe(`${label} review votes`, () => {
    const votes = `${path}/${ALICE}/votes`;

    beforeEach(async () => reset(async (db) => {
      await setDoc(doc(db, path, ALICE), {
        ...validReview(ALICE),
        createdAt: Timestamp.fromDate(new Date('2026-01-01')),
        updatedAt: Timestamp.fromDate(new Date('2026-01-01')),
      });
    }));

    test('a voter may record their own vote', async () => {
      await assertSucceeds(setDoc(doc(bob, votes, BOB), {
        userId: BOB, createdAt: serverTimestamp(),
      }));
    });

    test('a voter may NOT vote in someone else\'s name', async () => {
      await assertFails(setDoc(doc(alice, votes, BOB), {
        userId: BOB, createdAt: serverTimestamp(),
      }));
    });

    test('userId must match the voter', async () => {
      await assertFails(setDoc(doc(bob, votes, BOB), {
        userId: ALICE, createdAt: serverTimestamp(),
      }));
    });

    test('a guest may not vote', async () => {
      await assertFails(setDoc(doc(guest, votes, BOB), {
        userId: BOB, createdAt: serverTimestamp(),
      }));
    });

    test('rejects an extra field on a vote', async () => {
      await assertFails(setDoc(doc(bob, votes, BOB), {
        userId: BOB, createdAt: serverTimestamp(), weight: 100,
      }));
    });

    test('nobody may enumerate who voted', async () => {
      // Allowing this would turn "helpful" into a public record of who read what.
      await assertFails(getDocs(collection(bob, votes)));
      await assertFails(getDocs(collection(admin, votes)));
    });

    describe('with an existing vote', () => {
      // Seeds the parent review too: reset() clears everything, so this hook
      // must stand on its own rather than layering onto the outer seed.
      beforeEach(async () => reset(async (db) => {
        await setDoc(doc(db, path, ALICE), {
          ...validReview(ALICE),
          createdAt: Timestamp.fromDate(new Date('2026-01-01')),
          updatedAt: Timestamp.fromDate(new Date('2026-01-01')),
        });
        await setDoc(doc(db, votes, BOB), {
          userId: BOB, createdAt: Timestamp.fromDate(new Date('2026-01-02')),
        });
      }));

      test('the voter may read their own vote by id', async () => {
        await assertSucceeds(getDoc(doc(bob, votes, BOB)));
      });

      test("another user may NOT read someone else's vote", async () => {
        await assertFails(getDoc(doc(alice, votes, BOB)));
      });

      test('a vote may not be edited', async () => {
        await assertFails(updateDoc(doc(bob, votes, BOB), { userId: BOB }));
      });

      test('the voter may withdraw their vote', async () => {
        await assertSucceeds(deleteDoc(doc(bob, votes, BOB)));
      });

      test('another user may NOT withdraw it', async () => {
        await assertFails(deleteDoc(doc(alice, votes, BOB)));
      });
    });
  });
}
