// cars and rental_locations — DATA_MODEL.md, SECURITY.md 1.
//
// Public catalogue reads, admin-only writes. The write side is payment- and
// inventory-adjacent: price, currency, extras pricing and every contractual
// term in `conditions` are figures a user acts on.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
  Timestamp,
} from 'firebase/firestore';
import { makeEnv, seed, ALICE } from './harness.js';

let env, alice, guest, admin;

const CAR = 'preview-car-tesla-model-3';
const BRANCH = 'preview-erbil-airport';

const carDoc = (over = {}) => ({
  name: { en: 'Tesla Model 3', ku: 'تێسلا', ar: 'تسلا' },
  year: 2024,
  company: { id: 'abc-cars', name: { en: 'ABC Cars' } },
  imageUrls: [],
  capacity: 5,
  fuelType: 'electric',
  bags: 2,
  hasAC: true,
  paymentInfo: 'payAtPickup',
  locationId: BRANCH,
  pricePerDay: 56,
  currencyCode: 'USD',
  featured: true,
  active: true,
  transmission: 'automatic',
  extras: [],
  ...over,
});

const branchDoc = (over = {}) => ({
  name: { en: 'Erbil International Airport' },
  city: { en: 'Erbil' },
  country: { en: 'Iraq' },
  airportCode: 'EBL',
  active: true,
  ...over,
});

before(async () => {
  env = await makeEnv('cars');
  alice = env.authenticatedContext(ALICE).firestore();
  guest = env.unauthenticatedContext().firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());

const reset = async (seedFn) => {
  await env.clearFirestore();
  if (seedFn) await seed(env, seedFn);
};

const seedCatalog = async (db) => {
  await setDoc(doc(db, 'cars', CAR), carDoc());
  await setDoc(doc(db, 'cars', 'retired'), carDoc({ active: false, featured: false }));
  await setDoc(doc(db, 'rental_locations', BRANCH), branchDoc());
};

describe('cars — public reads', () => {
  beforeEach(async () => reset(seedCatalog));

  test('a guest may read a car by id', async () => {
    await assertSucceeds(getDoc(doc(guest, 'cars', CAR)));
  });

  test('a guest may list cars — the screens query the collection', async () => {
    await assertSucceeds(getDocs(collection(guest, 'cars')));
  });

  test('a guest may query only the active cars', async () => {
    const snap = await assertSucceeds(getDocs(
      query(collection(guest, 'cars'), where('active', '==', true)),
    ));
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes(CAR) || ids.includes('retired')) {
      throw new Error(`active filter returned ${ids.join(', ')}`);
    }
  });

  test('a signed-in user may read cars too', async () => {
    await assertSucceeds(getDoc(doc(alice, 'cars', CAR)));
    await assertSucceeds(getDocs(collection(alice, 'cars')));
  });

  test('a guest may read and list rental_locations', async () => {
    await assertSucceeds(getDoc(doc(guest, 'rental_locations', BRANCH)));
    await assertSucceeds(getDocs(collection(guest, 'rental_locations')));
  });
});

describe('cars — client writes denied', () => {
  beforeEach(async () => reset(seedCatalog));

  test('a guest may not create, update or delete a car', async () => {
    await assertFails(setDoc(doc(guest, 'cars', 'fake'), carDoc()));
    await assertFails(updateDoc(doc(guest, 'cars', CAR), { pricePerDay: 1 }));
    await assertFails(deleteDoc(doc(guest, 'cars', CAR)));
  });

  test('a signed-in non-admin may not create, update or delete a car', async () => {
    await assertFails(setDoc(doc(alice, 'cars', 'fake'), carDoc()));
    await assertFails(updateDoc(doc(alice, 'cars', CAR), { pricePerDay: 1 }));
    await assertFails(deleteDoc(doc(alice, 'cars', CAR)));
  });

  test('a user may not quote itself a cheaper daily rate', async () => {
    await assertFails(updateDoc(doc(alice, 'cars', CAR), {
      pricePerDay: 1, currencyCode: 'USD',
    }));
  });

  test('a user may not switch the currency a price is stated in', async () => {
    // Reading 56 as IQD instead of USD would misprice the vehicle by ~1300x.
    await assertFails(updateDoc(doc(alice, 'cars', CAR), { currencyCode: 'IQD' }));
  });

  test('a user may not rewrite the optional-extras pricing', async () => {
    await assertFails(updateDoc(doc(alice, 'cars', CAR), {
      extras: [{ id: 'gps', name: { en: 'GPS' }, pricePerDay: 0, selection: 'checkbox' }],
    }));
  });

  test('a user may not erase or invent supplier conditions', async () => {
    // Deposit, excess, cancellation deadline and minimum age are contractual
    // terms a renter acts on.
    await assertFails(updateDoc(doc(alice, 'cars', CAR), {
      conditions: {
        depositAmount: 0,
        damageExcess: 0,
        minimumDriverAge: 18,
        freeCancellationUntil: Timestamp.fromDate(new Date('2030-01-01')),
      },
    }));
  });

  test('a user may not promote a car into the featured carousel', async () => {
    await assertFails(updateDoc(doc(alice, 'cars', 'retired'), { featured: true }));
  });

  test('a user may not publish a retired car', async () => {
    await assertFails(updateDoc(doc(alice, 'cars', 'retired'), { active: true }));
  });

  test('a user may not repoint a car at another branch', async () => {
    await assertFails(updateDoc(doc(alice, 'cars', CAR), { locationId: 'elsewhere' }));
  });

  test('a user may not create or edit a rental branch', async () => {
    await assertFails(setDoc(doc(alice, 'rental_locations', 'fake'), branchDoc()));
    await assertFails(updateDoc(doc(alice, 'rental_locations', BRANCH), {
      airportCode: 'XXX',
    }));
    await assertFails(deleteDoc(doc(alice, 'rental_locations', BRANCH)));
  });
});

describe('cars — admin writes allowed', () => {
  beforeEach(async () => reset(seedCatalog));

  test('an admin may create a car', async () => {
    await assertSucceeds(setDoc(doc(admin, 'cars', 'new-car'), carDoc()));
  });

  test('an admin may update price, flags and conditions', async () => {
    await assertSucceeds(updateDoc(doc(admin, 'cars', CAR), { pricePerDay: 60 }));
    await assertSucceeds(updateDoc(doc(admin, 'cars', CAR), { featured: false }));
    await assertSucceeds(updateDoc(doc(admin, 'cars', CAR), { active: false }));
    await assertSucceeds(updateDoc(doc(admin, 'cars', CAR), {
      conditions: { depositAmount: 200, minimumDriverAge: 23 },
    }));
  });

  test('an admin may delete a car', async () => {
    await assertSucceeds(deleteDoc(doc(admin, 'cars', CAR)));
  });

  test('an admin may manage rental branches', async () => {
    await assertSucceeds(setDoc(doc(admin, 'rental_locations', 'new'), branchDoc()));
    await assertSucceeds(deleteDoc(doc(admin, 'rental_locations', BRANCH)));
  });

  test('the admin claim is what grants it, not merely being signed in', async () => {
    const patch = { pricePerDay: 77 };
    await assertFails(updateDoc(doc(alice, 'cars', CAR), patch));
    await assertSucceeds(updateDoc(doc(admin, 'cars', CAR), patch));
  });
});

describe('cars — shape validation the rules actually enforce', () => {
  beforeEach(async () => reset(seedCatalog));

  for (const currency of ['USD', 'IQD']) {
    test(`an admin may publish a price in ${currency}`, async () => {
      await assertSucceeds(setDoc(doc(admin, 'cars', `c-${currency}`), carDoc({
        currencyCode: currency,
        pricePerDay: currency === 'IQD' ? 85000 : 65,
      })));
    });
  }

  for (const currency of ['EUR', 'GBP', 'usd', 'US', '', 'BTC']) {
    test(`even an admin may NOT publish currency "${currency}"`, async () => {
      // A code the app cannot display renders a price nobody can act on, so
      // this is validated in the rules and not only in the client.
      await assertFails(setDoc(doc(admin, 'cars', 'bad'), carDoc({
        currencyCode: currency,
      })));
    });
  }

  test('a non-string currency is rejected', async () => {
    await assertFails(setDoc(doc(admin, 'cars', 'bad'), carDoc({ currencyCode: 1 })));
  });

  test('a non-numeric price is rejected', async () => {
    // "65" would render as a price and sort as text.
    await assertFails(setDoc(doc(admin, 'cars', 'bad'), carDoc({ pricePerDay: '65' })));
  });

  test('a negative price is rejected', async () => {
    await assertFails(setDoc(doc(admin, 'cars', 'bad'), carDoc({ pricePerDay: -1 })));
  });

  test('non-boolean featured/active are rejected', async () => {
    // A string "false" is truthy in plenty of languages; it must not publish
    // a car an admin retired.
    await assertFails(setDoc(doc(admin, 'cars', 'bad'), carDoc({ active: 'false' })));
    await assertFails(setDoc(doc(admin, 'cars', 'bad2'), carDoc({ featured: 'true' })));
  });

  test('a partial admin update need not resend the whole document', async () => {
    // The validators are all "absent is fine", so editing one field works.
    await assertSucceeds(updateDoc(doc(admin, 'cars', CAR), { bags: 3 }));
  });

  test('a partial update carrying a bad currency is still rejected', async () => {
    await assertFails(updateDoc(doc(admin, 'cars', CAR), { currencyCode: 'EUR' }));
  });
});

describe('cars — catch-all still effective', () => {
  beforeEach(async () => reset(seedCatalog));

  test('an unruled subcollection under a car is denied', async () => {
    await assertFails(getDoc(doc(guest, `cars/${CAR}/secrets`, 'x')));
    await assertFails(setDoc(doc(admin, `cars/${CAR}/secrets`, 'x'), { a: 1 }));
  });

  test('an unruled subcollection under a branch is denied', async () => {
    await assertFails(getDoc(doc(guest, `rental_locations/${BRANCH}/notes`, 'x')));
  });

  test('car bookings are not a thing — bookings stay server-write-only', async () => {
    await assertFails(setDoc(doc(alice, 'bookings', 'forged-car'), {
      userId: ALICE, status: 'confirmed', totalPrice: 0,
    }));
  });
});
