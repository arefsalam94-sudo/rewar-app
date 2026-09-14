// favorites/{id} — SECURITY.md 6.1f.
//
// A user can create unlimited rows under their own uid, so every string on
// the denormalized snapshot is size-bounded: without that the collection is
// writable free storage.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
} from 'firebase/firestore';
import { makeEnv, seed, ALICE, BOB, validFavorite } from './harness.js';

let env, alice, bob, guest;
const FAV = `${ALICE}_rawanduz`;

before(async () => {
  env = await makeEnv('favorites');
  alice = env.authenticatedContext(ALICE).firestore();
  bob = env.authenticatedContext(BOB).firestore();
  guest = env.unauthenticatedContext().firestore();
});
after(async () => env?.cleanup());

// One hook per describe that clears and seeds together — see users.test.js.
const reset = async (seedFn) => {
  await env.clearFirestore();
  if (seedFn) await seed(env, seedFn);
};

describe('favorites — create shape', () => {
  beforeEach(async () => reset());

  test('owner may save a valid favorite', async () => {
    await assertSucceeds(setDoc(doc(alice, 'favorites', FAV), validFavorite()));
  });

  test('the optional snapshot fields may be omitted', async () => {
    const { locationLabel, imageRef, ...minimal } = validFavorite();
    await assertSucceeds(setDoc(doc(alice, 'favorites', FAV), minimal));
  });

  test('hotel is an accepted item type', async () => {
    await assertSucceeds(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), itemType: 'hotel', itemId: 'divan-erbil',
    }));
  });

  // Narrowed from five values to two when the heart was consolidated.
  for (const itemType of ['car', 'tour', 'flight', 'anything']) {
    test(`rejects retired/unknown item type: ${itemType}`, async () => {
      await assertFails(setDoc(doc(alice, 'favorites', FAV), { ...validFavorite(), itemType }));
    });
  }

  test('title is required', async () => {
    const { title, ...noTitle } = validFavorite();
    await assertFails(setDoc(doc(alice, 'favorites', FAV), noTitle));
  });

  test('title must carry an English entry', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), title: { ku: 'Rawanduz' },
    }));
  });

  test('title must not be empty', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), title: { en: '' },
    }));
  });

  test('title accepts exactly 200 characters', async () => {
    await assertSucceeds(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), title: { en: 'x'.repeat(200) },
    }));
  });

  test('title rejects 201 characters', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), title: { en: 'x'.repeat(201) },
    }));
  });

  test('title rejects a locale key outside en/ku/ar', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), title: { en: 'ok', fr: 'non' },
    }));
  });

  test('locationLabel is size-bounded too', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), locationLabel: { en: 'x'.repeat(201) },
    }));
  });

  test('imageRef accepts 1000 characters and rejects 1001', async () => {
    await assertSucceeds(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), imageRef: 'x'.repeat(1000),
    }));
    await assertFails(setDoc(doc(alice, 'favorites', `${FAV}2`), {
      ...validFavorite(), imageRef: 'x'.repeat(1001),
    }));
  });

  test('itemId rejects over 200 characters', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), itemId: 'x'.repeat(201),
    }));
  });

  test('rejects a field outside the allow-list', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), {
      ...validFavorite(), payload: 'x'.repeat(50),
    }));
  });
});

describe('favorites — ownership', () => {
  beforeEach(async () => reset());

  test('a user may NOT create a row owned by someone else', async () => {
    await assertFails(setDoc(doc(alice, 'favorites', FAV), validFavorite(BOB)));
  });

  test('a guest may not create a favorite at all', async () => {
    // There is no anonymous favorite — guests get a sign-in prompt instead.
    await assertFails(setDoc(doc(guest, 'favorites', FAV), validFavorite()));
  });

  describe('with an existing row owned by alice', () => {
    beforeEach(async () => reset(async (db) => {
      await setDoc(doc(db, 'favorites', FAV), validFavorite());
    }));

    test('owner may read it', async () => {
      await assertSucceeds(getDoc(doc(alice, 'favorites', FAV)));
    });

    test('another user may NOT read it', async () => {
      await assertFails(getDoc(doc(bob, 'favorites', FAV)));
    });

    test('owner may list their own rows', async () => {
      await assertSucceeds(getDocs(
        query(collection(alice, 'favorites'), where('userId', '==', ALICE)),
      ));
    });

    test('a query not pinned to the caller is rejected', async () => {
      await assertFails(getDocs(
        query(collection(alice, 'favorites'), where('userId', '==', BOB)),
      ));
    });

    test('an unconstrained list is rejected', async () => {
      await assertFails(getDocs(collection(alice, 'favorites')));
    });

    test('update is denied outright', async () => {
      // A favourite is added or removed; update would only add a way to
      // repoint an existing row at another user.
      await assertFails(updateDoc(doc(alice, 'favorites', FAV), { itemId: 'other' }));
    });

    test('owner may delete it', async () => {
      await assertSucceeds(deleteDoc(doc(alice, 'favorites', FAV)));
    });

    test('another user may NOT delete it', async () => {
      await assertFails(deleteDoc(doc(bob, 'favorites', FAV)));
    });
  });

  test('a legacy car/tour/flight row stays deletable', async () => {
    // delete checks ownership only, not shape — a tightening that trapped
    // rows in a user's account would be worse than the loose type it replaced.
    await reset(async (db) => {
      await setDoc(doc(db, 'favorites', 'legacy'), { ...validFavorite(), itemType: 'car' });
    });
    await assertSucceeds(deleteDoc(doc(alice, 'favorites', 'legacy')));
  });
});
