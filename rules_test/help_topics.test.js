// help_topics — DATA_MODEL.md, and SECURITY.md 1 / 3.
//
// Public read (including unauthenticated), admin-only write, no `list`. The
// read side is deliberately the most open in the database: someone who cannot
// sign in is exactly the person who needs the help centre. The write side is
// the opposite — support answers are the app's own voice, so a client that
// could write here could publish a phishing instruction to every user.
import { test, describe, before, after, beforeEach } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
} from 'firebase/firestore';
import { makeEnv, seed, ALICE, validHelpTopic } from './harness.js';

let env, alice, guest, admin;

// The ten ids fixed in lib/models/help_topic.dart. Pinned here as well as in
// the Dart test so a rename cannot quietly land on one side only.
const TOPIC_IDS = [
  'account_signin',
  'bookings_confirmation',
  'payments_refunds',
  'cancellation_changes',
  'flights',
  'stays_hotels',
  'car_rental',
  'tours_nature',
  'safety_travel_info',
  'contact_support',
];

before(async () => {
  env = await makeEnv('helptopics');
  alice = env.authenticatedContext(ALICE).firestore();
  guest = env.unauthenticatedContext().firestore();
  admin = env.authenticatedContext('root_uid', { admin: true }).firestore();
});
after(async () => env?.cleanup());

const reset = async (seedFn) => {
  await env.clearFirestore();
  if (seedFn) await seed(env, seedFn);
};

describe('help_topics — public read', () => {
  beforeEach(async () => reset(async (db) => {
    for (const [i, id] of TOPIC_IDS.entries()) {
      await setDoc(doc(db, 'help_topics', id), validHelpTopic(i + 1));
    }
  }));

  test('an unauthenticated visitor may read a topic by id', async () => {
    // The whole point of the collection: no account required.
    await assertSucceeds(getDoc(doc(guest, 'help_topics', 'account_signin')));
  });

  test('a signed-in user may read a topic by id', async () => {
    await assertSucceeds(getDoc(doc(alice, 'help_topics', 'payments_refunds')));
  });

  test('every one of the ten fixed ids is readable by a guest', async () => {
    for (const id of TOPIC_IDS) {
      await assertSucceeds(getDoc(doc(guest, 'help_topics', id)));
    }
  });

  test('reading a topic that has not been seeded is still allowed', async () => {
    // A missing document is "not found", not "denied" — the rule must not make
    // an unseeded topic look like a permissions problem to the app.
    await assertSucceeds(getDoc(doc(guest, 'help_topics', 'not_seeded_yet')));
  });
});

describe('help_topics — list is denied', () => {
  beforeEach(async () => reset(async (db) => {
    await setDoc(doc(db, 'help_topics', 'flights'), validHelpTopic());
  }));

  test('a guest may not enumerate the collection', async () => {
    // Ids are fixed in HelpTopic.docId, so the app never needs `list`.
    await assertFails(getDocs(collection(guest, 'help_topics')));
  });

  test('a signed-in user may not enumerate the collection', async () => {
    await assertFails(getDocs(collection(alice, 'help_topics')));
  });

  test('an admin may not enumerate it either', async () => {
    await assertFails(getDocs(collection(admin, 'help_topics')));
  });

  test('a filtered query is denied too', async () => {
    await assertFails(getDocs(
      query(collection(guest, 'help_topics'), where('active', '==', true)),
    ));
  });
});

describe('help_topics — client writes denied', () => {
  beforeEach(async () => reset(async (db) => {
    await setDoc(doc(db, 'help_topics', 'account_signin'), validHelpTopic());
  }));

  test('a guest may not create a topic', async () => {
    await assertFails(
      setDoc(doc(guest, 'help_topics', 'fake_topic'), validHelpTopic()),
    );
  });

  test('a signed-in non-admin may not create a topic', async () => {
    await assertFails(
      setDoc(doc(alice, 'help_topics', 'fake_topic'), validHelpTopic()),
    );
  });

  test('a signed-in non-admin may not rewrite an answer', async () => {
    // The phishing case: replacing a support answer with a fake instruction.
    await assertFails(updateDoc(doc(alice, 'help_topics', 'account_signin'), {
      content: {
        en: {
          questions: [
            {
              question: 'How do I verify my card?',
              answer: 'Call +000 000 0000 and read out your card number.',
            },
          ],
        },
      },
    }));
  });

  test('a signed-in non-admin may not hide a topic via active', async () => {
    await assertFails(
      updateDoc(doc(alice, 'help_topics', 'account_signin'), { active: false }),
    );
  });

  test('a signed-in non-admin may not reorder topics', async () => {
    await assertFails(
      updateDoc(doc(alice, 'help_topics', 'account_signin'), { order: 99 }),
    );
  });

  test('a signed-in non-admin may not delete a topic', async () => {
    await assertFails(deleteDoc(doc(alice, 'help_topics', 'account_signin')));
  });

  test('a guest may not delete a topic', async () => {
    await assertFails(deleteDoc(doc(guest, 'help_topics', 'account_signin')));
  });
});

describe('help_topics — admin writes allowed', () => {
  beforeEach(async () => reset(async (db) => {
    await setDoc(doc(db, 'help_topics', 'account_signin'), validHelpTopic());
  }));

  test('a simulated admin may create a topic', async () => {
    await assertSucceeds(
      setDoc(doc(admin, 'help_topics', 'safety_travel_info'), validHelpTopic(9)),
    );
  });

  test('a simulated admin may update an answer', async () => {
    await assertSucceeds(updateDoc(doc(admin, 'help_topics', 'account_signin'), {
      content: {
        en: {
          questions: [
            { question: 'Updated?', answer: 'Yes, by an admin.' },
          ],
        },
      },
    }));
  });

  test('a simulated admin may toggle active and reorder', async () => {
    await assertSucceeds(
      updateDoc(doc(admin, 'help_topics', 'account_signin'), { active: false }),
    );
    await assertSucceeds(
      updateDoc(doc(admin, 'help_topics', 'account_signin'), { order: 3 }),
    );
  });

  test('a simulated admin may delete a topic', async () => {
    await assertSucceeds(deleteDoc(doc(admin, 'help_topics', 'account_signin')));
  });

  test('the admin claim is what grants it, not merely being signed in', async () => {
    // Same operation, same shape, only the claim differs.
    const patch = { order: 42 };
    await assertFails(updateDoc(doc(alice, 'help_topics', 'account_signin'), patch));
    await assertSucceeds(updateDoc(doc(admin, 'help_topics', 'account_signin'), patch));
  });
});

describe('help_topics — nothing hides under it', () => {
  beforeEach(async () => reset());

  test('a subcollection under a topic is denied by the catch-all', async () => {
    // The rule matches help_topics/{topicId} only; anything deeper falls
    // through to the catch-all rather than inheriting the public read.
    await assertFails(getDoc(doc(guest, 'help_topics/account_signin/drafts', 'x')));
    await assertFails(
      setDoc(doc(admin, 'help_topics/account_signin/drafts', 'x'), { a: 1 }),
    );
  });
});
