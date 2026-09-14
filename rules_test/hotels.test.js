// hotels, hotels/{id}/rooms, hotels/{id}/offers, hotels/{id}/reviews — the
// schema in DATA_MODEL.md and the catalog posture in SECURITY.md 1.
//
// Catalog data is publicly readable and admin-only writable. The write side
// here is payment-adjacent, not merely editorial: `pricePerNightFrom` on the
// hotel, and `nightlyPrice` / `availableQuantity` on an offer, are what a
// checkout quotes against.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
  serverTimestamp, Timestamp,
} from 'firebase/firestore';
import { makeEnv, seed, ALICE, BOB } from './harness.js';

let env, alice, bob, guest, admin;

const HOTEL = 'divan-erbil';
const ROOM = 'deluxe-king';
const OFFER = 'deluxe-king-flex';

const hotelDoc = () => ({
  name: { en: 'Divan Erbil', ku: 'دیڤان', ar: 'ديفان' },
  city: { en: 'Erbil', ku: 'هەولێر', ar: 'أربيل' },
  region: 'Erbil',
  country: 'Iraq',
  starRating: 5,
  pricePerNightFrom: 120,
  amenities: ['wifi', 'parking'],
  checkInTime: '14:00',
  checkOutTime: '12:00',
});

const roomDoc = () => ({
  name: { en: 'Deluxe King Room' },
  adultCapacity: 2,
  childCapacity: 1,
  maxOccupancy: 3,
  bedConfiguration: [{ type: 'king', count: 1 }],
});

const offerDoc = () => ({
  roomTypeId: ROOM,
  currency: 'USD',
  nightlyPrice: 120,
  totalPrice: 240,
  taxes: 24,
  fees: 5,
  taxesIncluded: false,
  breakfast: 'included',
  cancellationType: 'free',
  prepayment: 'none',
  paymentTiming: 'payLater',
  availableQuantity: 3,
});

const reviewDoc = (uid = ALICE, over = {}) => ({
  userId: uid,
  userName: 'Alice',
  avatarUrl: '',
  rating: 4.5,
  comment: 'A comfortable stay, close to everything.',
  status: 'published',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...over,
});

before(async () => {
  env = await makeEnv('hotels');
  alice = env.authenticatedContext(ALICE).firestore();
  bob = env.authenticatedContext(BOB).firestore();
  guest = env.unauthenticatedContext().firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());

const reset = async (seedFn) => {
  await env.clearFirestore();
  if (seedFn) await seed(env, seedFn);
};

const seedCatalog = async (db) => {
  await setDoc(doc(db, 'hotels', HOTEL), hotelDoc());
  await setDoc(doc(db, `hotels/${HOTEL}/rooms`, ROOM), roomDoc());
  await setDoc(doc(db, `hotels/${HOTEL}/offers`, OFFER), offerDoc());
};

describe('hotels — public catalog reads', () => {
  beforeEach(async () => reset(seedCatalog));

  test('a guest may read a hotel by id', async () => {
    await assertSucceeds(getDoc(doc(guest, 'hotels', HOTEL)));
  });

  test('a guest may list hotels — Where to Stay queries the collection', async () => {
    await assertSucceeds(getDocs(collection(guest, 'hotels')));
  });

  test('a guest may filter hotels by city', async () => {
    await assertSucceeds(getDocs(
      query(collection(guest, 'hotels'), where('starRating', '==', 5)),
    ));
  });

  test('a signed-in user may read hotels too', async () => {
    await assertSucceeds(getDoc(doc(alice, 'hotels', HOTEL)));
  });

  test('a guest may read and list rooms', async () => {
    await assertSucceeds(getDoc(doc(guest, `hotels/${HOTEL}/rooms`, ROOM)));
    await assertSucceeds(getDocs(collection(guest, `hotels/${HOTEL}/rooms`)));
  });

  test('a guest may read and list offers', async () => {
    await assertSucceeds(getDoc(doc(guest, `hotels/${HOTEL}/offers`, OFFER)));
    await assertSucceeds(getDocs(collection(guest, `hotels/${HOTEL}/offers`)));
  });

  test('a guest may filter offers by room type', async () => {
    // The Room Selection screen groups offers under their room.
    await assertSucceeds(getDocs(
      query(
        collection(guest, `hotels/${HOTEL}/offers`),
        where('roomTypeId', '==', ROOM),
      ),
    ));
  });
});

describe('hotels — catalog writes are admin-only', () => {
  beforeEach(async () => reset(seedCatalog));

  const paths = [
    ['hotel', 'hotels', HOTEL, { starRating: 1 }],
    ['room', `hotels/${HOTEL}/rooms`, ROOM, { maxOccupancy: 99 }],
    ['offer', `hotels/${HOTEL}/offers`, OFFER, { nightlyPrice: 0 }],
  ];

  for (const [label, col, id, patch] of paths) {
    test(`a guest may NOT write a ${label}`, async () => {
      await assertFails(updateDoc(doc(guest, col, id), patch));
    });
    test(`a signed-in non-admin may NOT write a ${label}`, async () => {
      await assertFails(updateDoc(doc(alice, col, id), patch));
    });
    test(`a signed-in non-admin may NOT delete a ${label}`, async () => {
      await assertFails(deleteDoc(doc(alice, col, id)));
    });
    test(`a simulated admin MAY write a ${label}`, async () => {
      await assertSucceeds(updateDoc(doc(admin, col, id), patch));
    });
    test(`a simulated admin MAY create a ${label}`, async () => {
      await assertSucceeds(setDoc(doc(admin, col, `${id}-2`), { a: 1 }));
    });
    test(`a simulated admin MAY delete a ${label}`, async () => {
      await assertSucceeds(deleteDoc(doc(admin, col, id)));
    });
  }

  test('a user may not quote itself a cheaper price', async () => {
    await assertFails(updateDoc(doc(alice, `hotels/${HOTEL}/offers`, OFFER), {
      nightlyPrice: 1, totalPrice: 1, taxes: 0, fees: 0,
    }));
  });

  test('a user may not manufacture scarcity', async () => {
    // availableQuantity is the only source for "Only N rooms left".
    await assertFails(updateDoc(doc(alice, `hotels/${HOTEL}/offers`, OFFER), {
      availableQuantity: 1,
    }));
  });

  test('a user may not write the server-owned rating aggregates', async () => {
    await assertFails(updateDoc(doc(alice, 'hotels', HOTEL), {
      reviewScore: 10, ratingCount: 999, ratingBreakdown: { 5: 999 },
      categoryScores: { cleanliness: 10 },
    }));
  });

  test('a user may not create a hotel of their own', async () => {
    await assertFails(setDoc(doc(alice, 'hotels', 'fake-hotel'), hotelDoc()));
  });
});

describe('hotel reviews — owner-written, same rules as nature_spots', () => {
  const reviews = `hotels/${HOTEL}/reviews`;

  beforeEach(async () => reset(seedCatalog));

  test('an author may write a review at their own uid', async () => {
    await assertSucceeds(setDoc(doc(alice, reviews, ALICE), reviewDoc()));
  });

  test("an author may NOT write at another user's uid", async () => {
    await assertFails(setDoc(doc(alice, reviews, BOB), reviewDoc(BOB)));
  });

  test('userId must match the caller', async () => {
    await assertFails(
      setDoc(doc(alice, reviews, ALICE), reviewDoc(ALICE, { userId: BOB })),
    );
  });

  test('a guest may not write a review', async () => {
    await assertFails(setDoc(doc(guest, reviews, ALICE), reviewDoc()));
  });

  for (const rating of [0.5, 3, 4.5, 5]) {
    test(`accepts a valid half-step rating of ${rating}`, async () => {
      await assertSucceeds(
        setDoc(doc(alice, reviews, ALICE), reviewDoc(ALICE, { rating })),
      );
    });
  }
  for (const rating of [0, 0.3, 3.7, 5.5, 6, -1]) {
    test(`rejects an invalid rating of ${rating}`, async () => {
      await assertFails(
        setDoc(doc(alice, reviews, ALICE), reviewDoc(ALICE, { rating })),
      );
    });
  }
  test('rejects a non-numeric rating', async () => {
    await assertFails(
      setDoc(doc(alice, reviews, ALICE), reviewDoc(ALICE, { rating: '5' })),
    );
  });

  test('rejects a comment shorter than 3 or longer than 1000', async () => {
    await assertFails(
      setDoc(doc(alice, reviews, ALICE), reviewDoc(ALICE, { comment: 'ok' })),
    );
    await assertFails(setDoc(doc(alice, reviews, ALICE),
      reviewDoc(ALICE, { comment: 'x'.repeat(1001) })));
  });

  test('rejects a status other than published', async () => {
    await assertFails(
      setDoc(doc(alice, reviews, ALICE), reviewDoc(ALICE, { status: 'draft' })),
    );
  });

  test('an author may NOT set the server-owned helpfulCount', async () => {
    await assertFails(
      setDoc(doc(alice, reviews, ALICE), reviewDoc(ALICE, { helpfulCount: 99 })),
    );
  });

  describe('with an existing review', () => {
    beforeEach(async () => reset(async (db) => {
      await seedCatalog(db);
      await setDoc(doc(db, reviews, ALICE), {
        userId: ALICE,
        userName: 'Alice',
        avatarUrl: '',
        rating: 4.5,
        comment: 'A comfortable stay, close to everything.',
        status: 'published',
        createdAt: Timestamp.fromDate(new Date('2026-01-01')),
        updatedAt: Timestamp.fromDate(new Date('2026-01-01')),
        helpfulCount: 7,
      });
    }));

    test('a published review is publicly readable', async () => {
      await assertSucceeds(getDoc(doc(guest, reviews, ALICE)));
      await assertSucceeds(getDocs(
        query(collection(guest, reviews), where('status', '==', 'published')),
      ));
    });

    test('the author may edit their own review', async () => {
      await assertSucceeds(updateDoc(doc(alice, reviews, ALICE), {
        comment: 'Edited, still a reasonable review.',
        rating: 4,
        updatedAt: serverTimestamp(),
      }));
    });

    test('the existing helpfulCount does not block a valid edit', async () => {
      await assertSucceeds(updateDoc(doc(alice, reviews, ALICE), {
        comment: 'Another reasonable edit.',
        updatedAt: serverTimestamp(),
      }));
    });

    test('the author may NOT raise helpfulCount', async () => {
      await assertFails(updateDoc(doc(alice, reviews, ALICE), {
        helpfulCount: 9999, updatedAt: serverTimestamp(),
      }));
    });

    test('the author may NOT re-date createdAt', async () => {
      await assertFails(updateDoc(doc(alice, reviews, ALICE), {
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      }));
    });

    test('another user may NOT edit it', async () => {
      await assertFails(updateDoc(doc(bob, reviews, ALICE), {
        comment: 'Vandalised by someone else.', updatedAt: serverTimestamp(),
      }));
    });

    test('the author may delete it; an admin may moderate it', async () => {
      await assertFails(deleteDoc(doc(bob, reviews, ALICE)));
      await assertSucceeds(deleteDoc(doc(admin, reviews, ALICE)));
    });
  });

  describe('review votes', () => {
    const votes = `${reviews}/${ALICE}/votes`;

    beforeEach(async () => reset(async (db) => {
      await seedCatalog(db);
      await setDoc(doc(db, reviews, ALICE), {
        userId: ALICE, userName: 'Alice', avatarUrl: '', rating: 4.5,
        comment: 'A comfortable stay, close to everything.',
        status: 'published',
        createdAt: Timestamp.fromDate(new Date('2026-01-01')),
        updatedAt: Timestamp.fromDate(new Date('2026-01-01')),
      });
    }));

    test('a voter may record their own vote', async () => {
      await assertSucceeds(setDoc(doc(bob, votes, BOB), {
        userId: BOB, createdAt: serverTimestamp(),
      }));
    });

    test("a voter may NOT vote in someone else's name", async () => {
      await assertFails(setDoc(doc(alice, votes, BOB), {
        userId: BOB, createdAt: serverTimestamp(),
      }));
    });

    test('nobody may enumerate who voted', async () => {
      await assertFails(getDocs(collection(bob, votes)));
      await assertFails(getDocs(collection(admin, votes)));
    });

    test('a vote may not be edited', async () => {
      await seed(env, async (db) => {
        await setDoc(doc(db, votes, BOB), {
          userId: BOB, createdAt: Timestamp.fromDate(new Date('2026-01-02')),
        });
      });
      await assertFails(updateDoc(doc(bob, votes, BOB), { userId: BOB }));
    });
  });
});

describe('hotels — highlighted and active (approved 2026-09-13)', () => {
  beforeEach(async () => reset(async (db) => {
    await setDoc(doc(db, 'hotels', HOTEL), { ...hotelDoc(), highlighted: true, active: true });
    await setDoc(doc(db, 'hotels', 'retired'), { ...hotelDoc(), highlighted: false, active: false });
  }));

  test('a guest may query only the active hotels', async () => {
    // This is the query the customer-facing list runs; `active: false` must
    // never reach it.
    const snap = await assertSucceeds(getDocs(
      query(collection(guest, 'hotels'), where('active', '==', true)),
    ));
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes(HOTEL) || ids.includes('retired')) {
      throw new Error(`active filter returned ${ids.join(', ')}`);
    }
  });

  test('an inactive hotel is still readable by direct id', async () => {
    // Hiding it from the list is a product decision, not a security boundary —
    // the rules stay simple and the service does the filtering.
    await assertSucceeds(getDoc(doc(guest, 'hotels', 'retired')));
  });

  test('a normal user may NOT flip active to publish a retired hotel', async () => {
    await assertFails(updateDoc(doc(alice, 'hotels', 'retired'), { active: true }));
  });

  test('a normal user may NOT promote a hotel into the carousel', async () => {
    await assertFails(updateDoc(doc(alice, 'hotels', 'retired'), { highlighted: true }));
  });

  test('an admin may set both flags', async () => {
    await assertSucceeds(updateDoc(doc(admin, 'hotels', 'retired'), {
      active: true, highlighted: true,
    }));
  });
});

describe('hotels — nothing else hides under the path', () => {
  beforeEach(async () => reset(seedCatalog));

  test('an unruled subcollection falls through to the catch-all', async () => {
    await assertFails(getDoc(doc(guest, `hotels/${HOTEL}/secrets`, 'x')));
    await assertFails(setDoc(doc(admin, `hotels/${HOTEL}/secrets`, 'x'), { a: 1 }));
  });

  test('bookings remain server-write-only even with hotels wired', async () => {
    // The checkout screen may READ hotel/room/offer data, but creating the
    // booking is still denied to every client (SECURITY.md 1a).
    await assertFails(setDoc(doc(alice, 'bookings', 'forged'), {
      userId: ALICE, status: 'confirmed', totalPrice: 0,
    }));
  });
});
