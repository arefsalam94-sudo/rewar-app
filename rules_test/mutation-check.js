// One-off sanity check: does this suite actually DETECT a loosened rule?
//
// A test that asserts "denied" passes for any reason a request is denied,
// including reasons unrelated to the rule under test. This script proves two
// of the most important assertions are really pinned to the rule text, by
// loading a MUTATED copy of firestore.rules in memory and confirming the
// behaviour flips. The real firestore.rules file is never modified.
import { initializeTestEnvironment, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { RULES_PATH, ALICE, validFavorite, validProfile } from './harness.js';

const original = readFileSync(RULES_PATH, 'utf8');

async function withMutation(name, find, replace, body) {
  if (!original.includes(find)) throw new Error(`mutation "${name}": anchor not found in rules`);
  const env = await initializeTestEnvironment({
    projectId: `demo-mutation-${name}`,
    firestore: { rules: original.replace(find, replace) },
  });
  try {
    await body(env.authenticatedContext(ALICE).firestore());
    console.log(`  DETECTED  ${name} — loosening the rule changed the outcome, so the suite's assertion is real`);
  } finally {
    await env.cleanup();
  }
}

console.log('mutation checks (firestore.rules on disk is untouched):');

await withMutation(
  'favorites-itemtype',
  "request.resource.data.itemType in ['nature_spot', 'hotel']",
  "request.resource.data.itemType in ['nature_spot', 'hotel', 'car']",
  async (db) => {
    // The real suite asserts this is DENIED. Under the loosened rule it must succeed.
    await assertSucceeds(setDoc(doc(db, 'favorites', `${ALICE}_m`), {
      ...validFavorite(), itemType: 'car',
    }));
  },
);

await withMutation(
  'users-role-allowlist',
  "'termsAcceptedAt', 'termsVersion',",
  "'termsAcceptedAt', 'termsVersion', 'role',",
  async (db) => {
    // The real suite asserts role:'admin' is DENIED. Add `role` to the
    // allow-list and it must go through — which is exactly the escalation the
    // allow-list exists to stop.
    await assertSucceeds(setDoc(doc(db, 'users', ALICE), {
      ...validProfile(), role: 'admin',
    }));
  },
);

console.log('both mutations detected — the assertions are pinned to the rule text.');
