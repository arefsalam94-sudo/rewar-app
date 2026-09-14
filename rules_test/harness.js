// Shared setup for the firestore.rules regression suite.
//
// Everything here runs against the Firebase Emulator Suite under the project
// id `demo-kurdistan`. The `demo-` prefix is not cosmetic: it tells the
// Firebase tooling the project is fake, so the emulator refuses to reach any
// real backend and no credentials are ever used. The live `rewar-app-1c10e`
// project cannot be touched by these tests even by accident.
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

/** The rules under test — read from the real file, never a copy. */
export const RULES_PATH = join(here, '..', 'firestore.rules');

/**
 * @param {string} namespace unique per test FILE.
 *
 * `node --test` runs files in parallel, and every file talks to the same
 * emulator process. Sharing one project id means one file's `clearFirestore()`
 * wipes another file's seeded documents mid-test, which surfaces as rules
 * "Null value error" / NOT_FOUND failures that move around between runs and
 * look exactly like real rules bugs. A project id per file gives each one its
 * own isolated namespace inside the emulator, so they can still run in
 * parallel.
 */
export async function makeEnv(namespace) {
  if (!namespace) throw new Error('makeEnv(namespace) requires a unique namespace per test file');
  return initializeTestEnvironment({
    projectId: `demo-kurdistan-${namespace}`,
    firestore: { rules: readFileSync(RULES_PATH, 'utf8') },
  });
}

/**
 * Seeds documents with rules bypassed.
 *
 * Needed because several rules can only be exercised against an existing
 * document — `allow update`/`delete` read `resource.data`, and a read test
 * that returns "not found" would pass for the wrong reason.
 */
export async function seed(env, fn) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

// --- fixtures ------------------------------------------------------------

export const ALICE = 'alice_uid';
export const BOB = 'bob_uid';

/** A users/{uid} document that satisfies validShape(). */
export const validProfile = (email = 'alice@example.com') => ({
  name: 'Alice Example',
  email,
  phone: '+9647500000000',
  dateOfBirth: new Date('1990-01-01T00:00:00Z'),
});

/** A favorites/{id} document that satisfies validShape(). */
export const validFavorite = (uid = ALICE) => ({
  userId: uid,
  itemType: 'nature_spot',
  itemId: 'rawanduz-canyon',
  title: { en: 'Rawanduz Canyon' },
  locationLabel: { en: 'Erbil' },
  imageRef: 'assets/images/featured-rawanduz.png',
});

/**
 * A review document that satisfies validReviewBody()/validShape().
 * `createdAt`/`updatedAt` must be added by the caller as serverTimestamp(),
 * because the rules pin both to `request.time`.
 */
export const validReview = (uid = ALICE) => ({
  userId: uid,
  userName: 'Alice',
  avatarUrl: '',
  rating: 4.5,
  comment: 'A perfectly reasonable review of this place.',
  status: 'published',
});

/** Both review collections are governed by equivalent rules. */
export const REVIEW_PARENTS = [
  'nature_spots/rawanduz-canyon',
  'tours/gali-sherana',
];

/** Collections that must be closed to every client, in both directions. */
export const SERVER_ONLY = [
  'password_reset_codes',
  'email_verify_codes',
  'email_change_codes',
  'mail',
];

/** Collections with no rule of their own — the catch-all must deny them. */
export const NO_RULE = [
  // hotels moved OUT of this list when it was given real rules — see
  // hotels.test.js. Its rooms/offers/reviews subcollections are covered there.
  // cars and rental_locations likewise moved out — see cars.test.js.
  'flights',
  // help_topics moved OUT of this list when it was given real rules — see
  // help_topics.test.js.
  'admin_activity_log',
  'anything_random',
];

/** A help_topics document in the DATA_MODEL.md shape. */
export const validHelpTopic = (order = 1) => ({
  order,
  active: true,
  content: {
    en: {
      questions: [
        {
          question: 'How do I create an account?',
          answer: 'Tap Sign Up and register with your email.',
        },
      ],
    },
  },
});
