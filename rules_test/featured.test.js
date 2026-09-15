// featured — the home screen carousel (DATA_MODEL.md, SECURITY.md 1).
//
// Public read including unauthenticated (the dashboard is browsable by a
// guest), admin-only write. A client that could write here could put anything
// on the app's front page.
//
// `type` and `referenceId` are validated in the rules as of 2026-09-15, after
// the launch-readiness audit found three of the four live slides pointing at
// documents that do not exist (`greenwheels-rentals`, `astra-ebl-ist`,
// `moraine-lake`). The rules cannot prove the target document is real — that
// needs a read, which `tool/seed_home_screen.js` does — but they can reject a
// slide whose `type` names no collection at all, which is a card the app can
// never open.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField, collection, getDocs,
  query, where, orderBy,
} from 'firebase/firestore';
import { makeEnv, seed, ALICE } from './harness.js';

let env, alice, guest, admin;

const SLIDE = 'rawanduz-canyon';

const slideDoc = (over = {}) => ({
  type: 'nature_spot',
  referenceId: 'rawanduz-canyon',
  title: { en: 'Rawanduz Canyon', ku: 'دەربەندی ڕەواندز', ar: 'وادي راوندوز' },
  subtitle: { en: 'Erbil  •  Nature escape' },
  imageUrl: '',
  order: 1,
  active: true,
  ...over,
});

before(async () => {
  env = await makeEnv('featured');
  alice = env.authenticatedContext(ALICE).firestore();
  guest = env.unauthenticatedContext().firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());

const seedCarousel = async (db) => {
  await setDoc(doc(db, 'featured', SLIDE), slideDoc());
  await setDoc(doc(db, 'featured', 'gali-alibag-waterfall'), slideDoc({
    type: 'tour', referenceId: 'gali-alibag-waterfall',
    title: { en: 'Gali Alibag Waterfall' }, order: 2,
  }));
  await setDoc(doc(db, 'featured', 'retired'), slideDoc({
    referenceId: 'erbil-citadel', order: 9, active: false,
  }));
};

beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, seedCarousel);
});

describe('featured — public reads', () => {
  test('a guest may read a slide by id', async () => {
    await assertSucceeds(getDoc(doc(guest, 'featured', SLIDE)));
  });

  test('a guest may list the carousel', async () => {
    await assertSucceeds(getDocs(collection(guest, 'featured')));
  });

  test('a guest may run the real carousel query', async () => {
    // active == true, ordered by `order`, limited — the composite index in
    // firestore.indexes.json exists for exactly this.
    const snap = await assertSucceeds(getDocs(query(
      collection(guest, 'featured'),
      where('active', '==', true),
      orderBy('order'),
    )));
    const ids = snap.docs.map((d) => d.id);
    if (ids.includes('retired')) {
      throw new Error(`inactive slide reached the carousel: ${ids.join(', ')}`);
    }
  });

  test('a signed-in user may read it too', async () => {
    await assertSucceeds(getDoc(doc(alice, 'featured', SLIDE)));
  });
});

describe('featured — writes stay admin-only', () => {
  test('a guest may NOT write a slide', async () => {
    await assertFails(setDoc(doc(guest, 'featured', 'forged'), slideDoc()));
  });

  test('a signed-in non-admin may NOT write a slide', async () => {
    await assertFails(setDoc(doc(alice, 'featured', 'forged'), slideDoc()));
  });

  test('a non-admin may NOT edit an existing slide', async () => {
    await assertFails(updateDoc(doc(alice, 'featured', SLIDE), {
      title: { en: 'Hacked' },
    }));
  });

  test('a non-admin may NOT repoint a slide at their own content', async () => {
    await assertFails(updateDoc(doc(alice, 'featured', SLIDE), {
      referenceId: 'attacker-owned',
    }));
  });

  test('a non-admin may NOT activate a retired slide', async () => {
    await assertFails(updateDoc(doc(alice, 'featured', 'retired'), {
      active: true,
    }));
  });

  test('a non-admin may NOT delete a slide', async () => {
    await assertFails(deleteDoc(doc(alice, 'featured', SLIDE)));
  });

  test('an admin may create, edit and delete', async () => {
    await assertSucceeds(setDoc(doc(admin, 'featured', 'new'), slideDoc({ order: 5 })));
    await assertSucceeds(updateDoc(doc(admin, 'featured', SLIDE), { order: 4 }));
    await assertSucceeds(deleteDoc(doc(admin, 'featured', SLIDE)));
  });
});

describe('featured — type and referenceId are validated', () => {
  for (const type of ['nature_spot', 'hotel', 'car', 'tour', 'flight']) {
    test(`an admin may publish a "${type}" slide`, async () => {
      // `flight` stays legal in the SCHEMA — flights are a real type that will
      // have inventory later. It is the seeder that refuses to write one while
      // the collection is empty, because only the seeder can check that.
      await assertSucceeds(setDoc(doc(admin, 'featured', `t-${type}`), slideDoc({ type })));
    });
  }

  for (const type of ['restaurant', 'natureSpot', 'nature-spot', 'Tour', '', 'event']) {
    test(`even an admin may NOT publish type "${type}"`, async () => {
      await assertFails(setDoc(doc(admin, 'featured', 'bad'), slideDoc({ type })));
    });
  }

  test('a slide with NO type is rejected', async () => {
    const { type, ...withoutType } = slideDoc();
    await assertFails(setDoc(doc(admin, 'featured', 'bad'), withoutType));
  });

  test('a non-string type is rejected', async () => {
    await assertFails(setDoc(doc(admin, 'featured', 'bad'), slideDoc({ type: 1 })));
  });

  test('a slide with NO referenceId is rejected', async () => {
    const { referenceId, ...withoutRef } = slideDoc();
    await assertFails(setDoc(doc(admin, 'featured', 'bad'), withoutRef));
  });

  test('an empty or non-string referenceId is rejected', async () => {
    await assertFails(setDoc(doc(admin, 'featured', 'bad'), slideDoc({ referenceId: '' })));
    await assertFails(setDoc(doc(admin, 'featured', 'bad'), slideDoc({ referenceId: 7 })));
  });

  test('an admin may NOT strip the type off an existing slide', async () => {
    await assertFails(updateDoc(doc(admin, 'featured', SLIDE), {
      type: deleteField(),
    }));
  });

  test('an admin may NOT strip the referenceId off an existing slide', async () => {
    await assertFails(updateDoc(doc(admin, 'featured', SLIDE), {
      referenceId: deleteField(),
    }));
  });

  test('a partial update to a bad type is still rejected', async () => {
    await assertFails(updateDoc(doc(admin, 'featured', SLIDE), { type: 'restaurant' }));
  });

  test('an admin may retype a slide between supported types', async () => {
    await assertSucceeds(updateDoc(doc(admin, 'featured', SLIDE), {
      type: 'tour', referenceId: 'korek-mountain-day',
    }));
  });

  test('reads are unaffected by the write validation', async () => {
    await assertSucceeds(getDoc(doc(guest, 'featured', SLIDE)));
  });
});
