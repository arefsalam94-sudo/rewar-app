# rules_test — Firestore security-rules regression suite

Runs `../firestore.rules` against the Firebase Emulator Suite and asserts what
each rule is supposed to allow and deny. Nothing here touches the live
`rewar-app-1c10e` project.

## Run it

```bash
cd rules_test
npm install      # first time only
npm test
```

### Windows: the emulator needs a JDK on PATH

The Firestore emulator is a Java program. This machine has no standalone JDK,
but Android Studio ships one, which is new enough:

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"
npm test
```

`flutter doctor -v` prints the path under "Java binary at" if it ever moves.

## Why it cannot reach production

`initializeTestEnvironment` uses a project id beginning with `demo-`. The
Firebase tooling treats `demo-*` as a fake project: the emulator runs fully
offline, no credentials are read, and any attempt to reach a real backend
fails rather than silently succeeding. The service-account key in `secrets/`
is never loaded by this suite.

## Layout

| file | covers |
|---|---|
| `harness.js` | shared setup, fixtures, the `demo-` project id |
| `users.test.js` | the `users` field allow-list, server-owned fields, cross-user access |
| `favorites.test.js` | ownership, item types, locale-map and string-size bounds |
| `reviews.test.js` | review uid rules, rating validation, votes — for **both** `nature_spots` and `tours` |
| `catalog_and_closed.test.js` | public reads, admin-only writes, bookings, server-only collections, catch-all |

## Two things that will bite you

**One project id per test file.** `node --test` runs files in parallel against
a single emulator. If two files share a project id, one file's
`clearFirestore()` deletes the other's seeded documents mid-test. The failures
look exactly like rules bugs — `Null value error`, `NOT_FOUND` — and move
between runs. `makeEnv(namespace)` requires a namespace for this reason.

**Clear and seed in the same hook.** Splitting `clearFirestore()` into an outer
`beforeEach` and the seed into an inner one leaves the order between them
ambiguous. Each describe owns one `reset()` call that does both.

## Simulated admin

`env.authenticatedContext('root_uid', { admin: true })` mints a token carrying
the `admin: true` custom claim, which is what `isAdmin()` in the rules checks.
This is how admin-only writes are tested **without granting a real production
account the claim**.

## mutation-check.js

Not part of `npm test`. It answers "would these tests actually notice if a rule
were loosened?" — it loads a deliberately weakened copy of the rules *in
memory* and confirms the outcome flips. Run it after changing the rules if you
want to confirm an assertion is still pinned to the rule text:

```bash
npx firebase emulators:exec --only firestore --project demo-kurdistan \
  --config ../firebase.json "node mutation-check.js"
```

It never writes to `../firestore.rules`.
