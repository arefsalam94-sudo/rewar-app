# DATA_MODEL.md — Firestore Schema (draft, refine with your agent in Phase 0)

Every document includes: `id`, `createdAt`, `updatedAt`, `source`
(`"manual"` | `"api"`), `createdBy`. Omitted below for brevity — assume
they're on every collection.

## `users`
| field | type | notes |
|---|---|---|
| name | string | The user's display name, and — with `email` — the whole of their identity in this app |
| email | string | matches Firebase Auth |
| emailVerified | boolean | mirrors Firebase Auth's own verification state. Written only by `confirmRegistrationEmailCode` / `confirmEmailChangeCode` under the Admin SDK; never client-writable (a client that could set it would be claiming a verification it never passed) |
| phone | string | |
| phoneVerified | boolean | |
| mfaEnrolled | boolean | true once at least one second factor is set up |
| mfaMethods | array<string> | which second factors are enrolled, e.g. `["sms"]`, `["totp"]`, or both |
| profileImageUrl | string | Firebase Storage download URL. The file lives at `profile_images/{uid}/avatar.jpg` — a fixed name per user, so re-uploading replaces the old picture rather than orphaning files. Set by the Account Setup screen |
| dateOfBirth | timestamp | set at registration. Stored as a **date**, not an age, so it never goes stale and an 18+ check stays correct over time |
| gender | string | `"male"` \| `"female"` \| `"other"`. **Optional** — absent when the user skips it (`SECURITY.md` 9: don't collect more than needed) |
| termsAcceptedAt | timestamp | when the user accepted on the Terms of Service screen. Required evidence for App Store / Play review |
| termsVersion | number | **which version** of the terms they accepted, from `legal_documents/terms_of_service.version`. A timestamp alone can't tell you whether someone agreed to the current wording or last year's — this is what lets you re-prompt only the users who haven't seen the latest text |
| preferredLanguage | string | `en` / `ku` / `ar` |
| preferredCurrency | string | `"USD"` \| `"IQD"` \| `"EUR"`. Defaults to `USD` client-side when absent — no migration needed for existing accounts |
| hasPaymentMethod | boolean | **Server-owned**, optional, defaults to `false`. Set only after the payment processor confirms that at least one reusable method exists; controls whether the Billing/Payment empty state applies. This is a summary flag only—never store a card number, CVC, or raw payment token in `users` |
| role | string | `"user"` \| `"admin"` |
| passwordChangedAt | timestamp | *when* the password last changed — never the password itself. Written only by Cloud Functions (`confirmPasswordResetWithCode` / `recordPasswordChange`); lets Settings show "last changed" and lets tokens issued before a reset be rejected |

Note: `emailVerified`/`phoneVerified`/MFA enrollment state ultimately
lives in Firebase Auth itself (the source of truth) — these Firestore
fields are a convenience mirror for querying/display, not a replacement
for checking the real Firebase Auth state before granting access to
anything sensitive.

Settings that affect only this installation — notification opt-in, theme, and
units until cross-device sync is explicitly required — belong in device-local
`SharedPreferences`, not in `users`. The current Settings implementation adds
no Firestore fields, rules, indexes, or migration. Language already uses the
existing app locale preference; currency remains the existing
`users.preferredCurrency` account preference.

### Saved payment methods

The Billing & Payments saved-card carousel does **not** introduce card fields
on `users` and needs no Firestore migration. When a payment provider is wired
in, a callable Cloud Function must list that provider customer's reusable
methods and return only presentation-safe metadata (`providerMethodId`, brand,
bank label when available, last four digits, expiry month/year, and default
status). PAN and CVC never enter Firestore. Add/change/delete operations must go
through the provider and then update the server-owned `hasPaymentMethod`
summary. The current carousel is design-only fixture data until that endpoint
exists.

**Which fields the client may write.** The Register screen creates this
document from the app, so `firestore.rules` restricts both create and update
to an explicit allow-list: `name`, `email`, `phone`, `dateOfBirth`, `gender`,
`profileImageUrl`, `preferredLanguage`, `termsAcceptedAt`, `createdAt`,
`updatedAt`, `source`. Everything else — **`role`, `emailVerified`,
`phoneVerified`, `mfaEnrolled`, `mfaMethods`, `passwordChangedAt`** — is
writable only by Cloud Functions via the Admin SDK. Without that restriction
a modified client could simply write `role: "admin"` to its own document and
grant itself the admin panel.

## `password_reset_codes` *(server-only — added for the Verification Code screen)*

Backs the **email** branch of the password-reset code flow. Firebase Auth's
built-in `sendPasswordResetEmail()` sends a *link*, not a code, so a 6-digit
email code has to be issued and checked by our own Cloud Functions.
The **phone/SMS** branch needs no collection at all — Firebase Auth generates
and verifies that code itself.

Document id = SHA-256 of the lowercased email (non-reversible, non-enumerable).
**No client access in either direction** — only the Admin SDK inside Cloud
Functions touches it (see `firestore.rules`).

| field | type | notes |
|---|---|---|
| codeHash | string | salted SHA-256 of the 6-digit code. The plaintext code is never stored |
| salt | string | random per-code salt |
| expiresAt | timestamp | 10 minutes after issue |
| attempts | number | failed verify attempts; 5 max, then locked out |
| lastSentAt | timestamp | enforces the 60s resend cooldown server-side |
| resetTokenHash | string | set only after a correct code; hash of the short-lived token the Set New Password screen will exchange |
| resetTokenExpiresAt | timestamp | 10 minutes after issue |

Note: this collection deliberately does **not** carry the standard
`id`/`createdBy`/`source` envelope — it holds no user-authored content, is
never listed or queried, and is deleted/overwritten per reset attempt.

## `email_change_codes` *(server-only)*

Backs the authenticated change-email flow. Document id = the signed-in user's
UID. The user must reauthenticate before requesting a code, and the callable
functions reject sessions whose `auth_time` is more than 10 minutes old.
Clients have **no direct read or write access**.

| field | type | notes |
|---|---|---|
| newEmail | string | normalized proposed address; never copied to the profile before verification |
| codeHash | string | salted SHA-256 of the six-digit code; plaintext is never stored |
| salt | string | random per-code salt |
| expiresAt | timestamp | 10 minutes after issue |
| attempts | number | failed verify attempts; 5 max |
| lastSentAt | timestamp | enforces the 60-second resend cooldown |
| verifying | boolean | transaction lock preventing concurrent code consumption |
| createdAt | timestamp | issue time |

## `email_verify_codes` *(server-only — added for the registration email step)*

Backs the six-digit email verification that now gates registration. Document
id = the signed-in user's UID. Clients have **no direct read or write access** —
note that because the id *is* the uid, allowing read would let a signed-in user
simply fetch their own pending code instead of receiving it by email, which
defeats the entire verification.

Same shape and the same guarantees as `email_change_codes`, with one important
difference: **the destination address is read server-side from Firebase Auth**,
never taken from the request, so a client cannot aim a registration code at an
address it does not own.

| field | type | notes |
|---|---|---|
| email | string | the account's own address, read from Firebase Auth — not client-supplied |
| codeHash | string | salted SHA-256 of the six-digit code; plaintext is never stored |
| salt | string | random per-code salt |
| expiresAt | timestamp | 10 minutes after issue |
| attempts | number | failed verify attempts; 5 max |
| lastSentAt | timestamp | enforces the 60-second resend cooldown |
| verifying | boolean | transaction lock preventing concurrent code consumption |
| createdAt | timestamp | issue time |

Written by `sendRegistrationEmailCode`; consumed and deleted by
`confirmRegistrationEmailCode`, which then sets `emailVerified` on both
Firebase Auth and `users/{uid}`.

## ~~`usernames`~~ — removed

The app no longer has usernames. A user is identified by their **display name
and email** alone, so there is no globally unique handle left to reserve.

Removed together:

- the `usernames/{normalizedUsername}` collection
- `users.username` and `users.usernameNormalized`
- the `claimUsername` Cloud Function
- the Change User Name row in Settings and its screen

The collection has no rule in `firestore.rules` any more; deny-by-default
(`SECURITY.md` 1) covers it. **If a deployment already ran the old function**,
drop the `usernames` collection and delete both fields from existing `users`
documents — nothing reads them.

## `mail` *(server-only — added for the Verification Code screen)*

Outbound email queue consumed by the **"Trigger Email from Firestore"**
Firebase Extension, which holds the SMTP credentials in extension config so
no secret lands in this repo (`SECURITY.md` section 4). Written only by
Cloud Functions; **no client access** — client write access would let anyone
send mail from the project's verified sender address.

| field | type | notes |
|---|---|---|
| to | array<string> | recipient address |
| message | map | `{subject, text, html}` — the extension's own schema |

## `legal_documents` *(added for the Terms of Service screen)*

Versioned legal text — **seven documents**, one per row on the Policy hub
(see the table further down). Held in Firestore rather than bundled in the app
so the wording can be updated from the admin panel without an App Store / Play
release, which is exactly what the Terms text itself promises ("we reserve the
right… to change… at any time"). A store release can take days; a legal
correction shouldn't wait.

**Single source of truth for the wording:**
`assets/legal/legal_documents.json`. The app bundles it (preview mode serves
it before Firebase exists) and `tool/seed_legal_documents.js` reads the same
file off disk to write Firestore. Nothing is retyped, so the two cannot drift;
a test asserts every document has all three languages with identical structure.
**Edit that file, never a Dart or JS copy.**

**Public read (including unauthenticated), admin-only write.** A user must be
able to read the terms before they have an account. If the client could write
here, it could rewrite the agreement it is about to accept.

| field | type | notes |
|---|---|---|
| version | number | bump on every wording change; consent is recorded against it in `users.termsVersion` |
| updatedAt | timestamp | shown as "Last updated" at the top — the body text refers to this date, so it has to exist |
| legalReviewed | boolean | false until a qualified translator/lawyer signs off. While false the app shows a visible warning banner |
| content | map | keyed by locale: `{ en: {sections: [...]}, ku: {...}, ar: {...} }` |
| content.{locale}.sections | array | ordered sections — **two accepted shapes**, see below |

### Section shapes — `{heading, body}` and `{heading?, blocks}`

`terms_of_service` was written as `{heading, body}`, two plain strings. The
Privacy Policy needs an untitled lead-in paragraph, bullet lists, and bold
lead-ins inside a bullet, none of which two strings can express — so a second
shape was added. **Both parse**; the old documents did not have to be
migrated, and `LegalSection.body` still returns the same string for them.

| field | type | notes |
|---|---|---|
| heading | string | **Optional** in the block shape — omit it for a lead-in paragraph that precedes the first titled section. Required in the legacy shape |
| body | string | Legacy shape only. Becomes a single paragraph block |
| blocks | array | Block shape. An empty/unparseable block is dropped, never drawn as a blank line |
| blocks[].type | string | `"paragraph"` \| `"bullet"`. Anything else is treated as a paragraph |
| blocks[].lead | string | **Optional.** The bold run at the start of a bullet, e.g. `"Account & contact details:"`. A separate field rather than a `**marker**` inside `text`, so nothing is parsed at render time — a typo can't silently break the formatting, and RTL bullets don't depend on a parser knowing which end of the string the bold run is on |
| blocks[].text | string | Required and non-empty. Drawn after `lead`, with a space between |

**The admin panel needs a block editor for this**, not a plain textarea: a
repeatable list of sections, each with an optional heading and a repeatable
list of paragraph/bullet rows (bullets having an optional lead field).

One read serves all three languages. A missing locale falls back to `en` so
the legal page is never blank.

### One document per Policy screen row

The Policy hub lists seven categories. Every one is the same shape —
versioned, localized, ordered sections — so they all live in **this
collection**, not a new one and not as fields on anything else. All seven are
written and all seven rows open.

| doc id | Policy screen row | version |
|---|---|---|
| `terms_of_service` | Terms & Conditions | **2** |
| `privacy_policy` | Privacy Policy | 1 |
| `cancellation_refunds` | Cancellation & Refunds | 1 |
| `payment_policy` | Payment Policy | 1 |
| `liability_disclaimer` | Liability & Disclaimer | 1 |
| `contact_complaints` | Contact & Complaints | 1 |
| `account_data_deletion` | Account & Data Deletion | 1 |

The ids are fixed in code, in `lib/models/policy_topic.dart`
(`PolicyTopic.docId`), so the app, the seed script and the admin panel cannot
drift on the naming. A test asserts the bundled asset covers exactly these
seven — no missing id, no orphan.

> **`terms_of_service` is at version 2, and that matters.** The Policy hub's
> "Terms & Conditions" row and the registration consent gate read the **same
> document** — deliberately, so a user can never accept one wording and read
> another. Its text was replaced wholesale at v2, so **anyone who accepted v1
> has not accepted the current wording** and must be re-prompted. Nothing is
> live yet, so there is no migration to run; the rule matters from first
> release onward.

**The admin panel needs a document picker rather than a hardcoded "Terms"
form**, plus a block editor (see the section shapes above) rather than a plain
textarea.

Two rows are more than text and still need their own decisions:

- **Contact & Complaints** is currently contact details only, so it stays a
  plain document. If it becomes a complaint *form*, it needs a `complaints`
  collection with owner-only read and create — see `SECURITY.md` section 1.
- **Account & Data Deletion** currently *describes* deletion; it does not
  perform it. The document promises an "in-app: Menu → Delete Account" route
  that **does not exist yet**. Building it cannot be a client-side delete:
  erasing a user has to cascade through `users`, `bookings`, `favorites` and
  Storage avatars, which a client must never be allowed to do. It belongs in a
  **Cloud Function**, with the screen only requesting it.

Both app stores require a working in-app deletion route for any app with
sign-up, so the second one is a release blocker, not a nice-to-have — the page
describing it is not the same as the page doing it.

## `help_topics` *(approved live source; bundled fallback is implemented)*

The ten categories on the Help & Support screen. **Confirmed to live in
Firestore**, for the same reason as `legal_documents` and more urgently:
support answers change far more often than legal text, and fixing a wrong
answer should not wait for an App Store release.

The screen currently expands bundled English fallback Q&A in place. The tenth
contact row intentionally says “Coming soon.” This collection remains the live
source planned for admin-managed updates and translated content; when seeded,
missing locales fall back to the same bundled English copy.

**Public read (including unauthenticated), admin-only write.** A user who
cannot sign in is exactly the person who needs the help centre, so it cannot
require auth. Rules will match the `legal_documents` pattern.

| field | type | notes |
|---|---|---|
| order | number | ascending display order, so the admin panel can reorder rows without a release |
| active | boolean | false hides a topic without deleting it |
| content | map | keyed by locale: `{ en: {...}, ku: {...}, ar: {...} }`. Missing locale falls back to `en`, same rule as `legal_documents` |
| content.{locale}.questions | array<{question, answer}> | the Q&A pairs shown when the row expands |

Document ids are fixed in `lib/models/help_topic.dart` (`HelpTopic.docId`):
`account_signin`, `bookings_confirmation`, `payments_refunds`,
`cancellation_changes`, `flights`, `stays_hotels`, `car_rental`,
`tours_nature`, `safety_travel_info`, `contact_support`.

Open questions, to settle when the content arrives:

- **The row titles and preview lines are currently app strings**, not
  Firestore — they are in `app_localizations.dart` like every other piece of
  UI copy. If the admin panel should rename a topic without a release, they
  have to move into this collection too. Decide before seeding.
- **`contact_support` is not a Q&A topic** — it is a route to a human (email,
  phone/WhatsApp, hours). It may need a different shape from the other nine,
  or may be better served by reading the contact details already in
  `legal_documents/contact_complaints` so the two cannot disagree.
- **Answers that restate policy** (refund timing, baggage, cancellation) risk
  drifting from `legal_documents`. Prefer linking to the policy page over
  duplicating its wording.

## `featured` *(added for the Home screen)*

The home screen's carousel — the four slides at the top of the dashboard.
A **curated collection** rather than a query across `nature_spots` / `cars` /
`tours` / `flights`, for three reasons: one read instead of four, the admin
panel controls exactly what appears and in what order, and a single slide can
point at any entity type without the client knowing which collections exist.

**Public read (including unauthenticated), admin-only write.** The dashboard
is fully browsable by a guest, so the carousel cannot require auth; a client
that could write here could put anything on the app's front page.

| field | type | notes |
|---|---|---|
| type | string | `"nature_spot"` \| `"hotel"` \| `"car"` \| `"tour"` \| `"flight"` — which collection `referenceId` points into |
| referenceId | string | id of the document in that collection, so Explore can open the right detail screen |
| title | map | keyed by locale: `{ en, ku, ar }`. A **map, not a string** — the app is trilingual and switching language must not cost a second read. Missing locale falls back to `en` |
| subtitle | map | same shape; the location/context line, e.g. "Erbil • Nature escape" |
| imageUrl | string | Firebase Storage download URL for the slide photo |
| rating | number | 0–5, shown as a star pill. **Optional** — absent hides the pill rather than drawing a zero, since an unrated item is not a badly rated one |
| order | number | ascending display order |
| active | boolean | false pulls a slide off the front page without deleting it |

Query: `.where('active', == true).orderBy('order').limit(8)`. That
combination needs a **composite index** — already declared in
`firestore.indexes.json`.

## `nature_spots`

**Revised for the Explore Nature list screen (Phase 3).** Three fields changed
shape and five were added; nothing had been seeded yet, so there is no
migration to run — but the admin panel's nature-spot form must match this.

| field | type | notes |
|---|---|---|
| name | map | keyed by locale: `{ en, ku, ar }`. **Changed from a plain string** — the app is trilingual and switching language must not cost a second read, the same rule `featured` and `legal_documents` already follow. Missing locale falls back to `en` |
| description | map | same shape. Shown clipped on the card, in full on the detail screen |
| locationLabel | map | same shape. The readable place line, e.g. "Erbil, Iraq". **New** — a geopoint cannot be shown to a user, and a label cannot be measured against, so the collection needs both |
| imageUrls | array<string> | Storage download URLs. The first is the list-card thumbnail |
| location | geopoint | used to compute the live distance; never displayed directly |
| reviewScore | number | 0–10, Booking.com-style. **Replaces `rating` (0–5)** for this collection. The 5-star row on the card is **derived** (`round(score / 2)`), never stored — one number to enter, and the two can never disagree. Optional: absent hides the score/star badges rather than drawing a zero. **Server-owned since the Reviews & Ratings screen** — see below |
| ratingCount | number | how many reviews `reviewScore` averages — an 8.7 from one review is not an 8.7 from two hundred. **Server-owned**; it is the "N reviews" figure printed on the Reviews & Ratings screen |
| ratingBreakdown | map | **Added for the Reviews & Ratings screen.** `{ "1": n, "2": n, "3": n, "4": n, "5": n }` — the 5★→1★ bars beside the average. **Server-owned.** A rating falls in `round(rating)`, so a 3.5 counts in the 4-star bar |
| categories | array<string> | **New.** The quick chips on the list screen — *what you do there*: `"hiking"`, `"beach"`, `"sunset_view"` |
| placeTypes | array<string> | **Added for the Customize Filters screen.** *What the place is*: `"forest"`, `"mountain"`, `"canyon"`, `"park"`, `"lake"`, `"waterfall"`, `"river"`, `"museum"`. A separate array from `categories` because it answers a different question — a waterfall you can hike to is tagged in both |
| amenities | array<string> | **Added for the Customize Filters screen.** `"parking"`, `"restrooms"`, `"restaurants"`, `"cafes"`, `"mobile_signal"`, `"lodging_nearby"`, `"atm_nearby"` |
| nearbyStays | array<map> | Up to three curated accommodation previews: `{ id, name: {en,ku,ar}, imageUrl, distanceKm, reviewScore }`. Price and availability belong to the live hotel flow |
| highlighted | boolean | **New.** True puts the spot in the screen's top carousel |
| highlightOrder | number | **New.** Ascending order within that carousel |
| active | boolean | **New.** False pulls a spot off the list without deleting it — same flag, same purpose as `featured.active` |

> `distanceLabel` is **removed**. The card says "from current location", so the
> distance is computed client-side from `location` and the device's GPS fix
> (`DeviceLocationService`). When location is off, denied, or unavailable, the
> Distance row is **hidden** — a stored label would have made that line a lie.

Only two queries are ever run, both with a composite index declared in
`firestore.indexes.json`:

```
carousel:  .where('active', == true).where('highlighted', == true)
             .orderBy('highlightOrder').limit(8)
catalog:   .where('active', == true)
             .orderBy('reviewScore', desc).limit(200)
```

### Why every filter is applied in Dart, not in the query

**Revised when the Customize Filters screen was added.** The list screen now
has *three* independent multi-select dimensions — `categories`, `placeTypes`,
`amenities` — and **Firestore permits only one array clause per query**
(`array-contains`, `array-contains-any` and `in` all share that limit). A
single query cannot express "any of these place types AND any of these
facilities" at all.

On top of that, the Customize screen's apply button reads "Show 32 Places" and
has to be exact and update on every chip tap. A server-side count would mean a
`count()` aggregation per tap.

So the catalog is read **once**, and `NatureFilters.matches` applies all three
dimensions in memory. One read serves the list, the filters and the counter,
and toggling a chip costs nothing.

**Semantics: OR within a group, AND across groups.** Selecting Forest and
Waterfall widens the results to places that are either; adding Restrooms then
narrows to those that also have restrooms. An empty group means "no filter",
not "match nothing".

> **When this stops being right.** The catalog is capped at
> `NatureSpotsService.catalogFetchLimit` (200 documents), which is both the read
> cost and the ceiling on what the filters can search. That is comfortable for a
> regional guide. If `nature_spots` heads toward four figures, move `placeTypes`
> to a server-side `array-contains-any` and keep only `amenities` client-side,
> and accept an approximate count on the button — or move filtering to a search
> service. This is a deliberate trade recorded here, not an accident.

> The Home screen runs a `count()` **aggregation** against this collection for
> the "N+ places" button. That needs `list` permission in the rules (granted:
> catalog data is public read), and is billed at one read per 1000 documents
> rather than one per document. The count is **unfiltered**, so it still works
> unchanged against the revised schema.

### The three aggregates are server-owned — the admin panel must not edit them

**Revised for the Reviews & Ratings screen.** `reviewScore`, `ratingCount` and
`ratingBreakdown` are no longer values anyone types. The
`syncNatureReviewAggregates` Cloud Function (`functions/index.js`) recomputes
all three from the `reviews` subcollection whenever a review is written.

Why it has to be the server: `nature_spots` is **admin-only write**
(`SECURITY.md` 1), and it must stay that way — a client that could write the
average score of a place could give a competitor a 2.0 without leaving a
review. So the client writes only its own review document, and the aggregates
are derived from it.

Why it **recomputes** rather than incrementing: Cloud Functions triggers are
*at-least-once*, so a duplicate delivery is a documented guarantee rather than
a rare fault. An `increment(1)` applied twice corrupts the count permanently
with nothing in the data to show it happened; a recompute applied twice gives
the same answer and repairs any earlier drift. It also makes seeding work —
`tool/seed_explore_nature.js` writes reviews and no aggregates at all, and
whatever order the writes land in, the last trigger leaves the right totals.

> **When this stops being right.** Each review write costs one read per
> existing review on that place. Comfortable into the low thousands. Past
> that, move to a sharded counter keyed by the event id for idempotency, and
> keep the recompute as a scheduled repair job.

**Consequences for the admin panel:** show these three **read-only**. A
hand-typed average is overwritten by the next review posted, so an editable
field there is a bug that looks like a feature.

### `nature_spots/{spotId}/reviews/{reviewId}`

Public visitor feedback. The detail page reads the two newest published
reviews; the Reviews & Ratings page reads them a page of 10 at a time, in one
of four orders.

**The document id is the author's uid.** That is what makes "one review per
person per place" a rule rather than a hope: without it a client could post the
same review a hundred times and drag the average wherever it liked, and no rule
could tell that apart from a hundred honest visitors. It also means a returning
author *edits* their review instead of stacking a second one on the same place.

| field | type | notes |
|---|---|---|
| userId | string | immutable owner UID; equals the document id |
| userName | string | denormalized display name, max 80 characters. Copied, not joined — a review must keep showing who wrote it after that account is renamed or deleted, the same rule `bookings.display` follows |
| avatarUrl | string | optional presentation-only URL |
| rating | number | **0.5–5.0 in half-star steps.** Changed from an integer 1–5: the design draws half stars, and an integer cannot hold a 3.5. Shown as `rating × 2` out of 10, so 4.5 reads as 9.0 / 10. Rules reject anything off the half-step grid, because it is a value no UI in this app can produce |
| comment | string | 3–1000 characters |
| helpfulCount | number | **Added for the Reviews & Ratings screen. Server-owned** — the heart count, recomputed by `syncReviewHelpfulCount` from the `votes` subcollection. On no client allow-list: a client that could write it would be declaring its own review the most helpful on the page |
| status | string | `published`; retained for moderation visibility |
| createdAt / updatedAt | timestamp | `createdAt` is pinned by the rules on update, so an author cannot re-date an old review to push it back to the top of "Most recent" |

Four query orders, each with its own composite index in
`firestore.indexes.json` — `createdAt`, `rating` (both directions) and
`helpfulCount`, all after `status == 'published'`, all with `createdAt` as the
tie-break. **Ordering is done in the query, not in Dart**, because the list is
paginated: sorting a downloaded page would rank the newest ten reviews and
present them as the highest rated of all 128.

#### `nature_spots/{spotId}/reviews/{reviewId}/votes/{voterId}`

"I found this review helpful", one document per person, keyed by their uid.

| field | type | notes |
|---|---|---|
| userId | string | equals the document id and `request.auth.uid` |
| createdAt | timestamp | |

A **document** rather than a counter the client increments, for the same reason
the review id is the uid: a document keyed by the voter physically cannot be
cast twice, whereas an increment can be sent in a loop. `list` is denied — the
screen reads only the viewer's own vote, by known id, and enumerating votes
would turn "helpful" into a public record of who read what.

> The viewer's votes for a page cost one small read per review shown (10).
> That is the price of not granting `list`; it is the right trade.

Weather is not stored in Firestore. It is fetched from Open-Meteo using the
place geopoint so the detail card cannot show stale catalog temperatures.

## `hotels`

> **Nothing reads this collection yet.** Where to Stay and the Hotel Details
> page both read `PreviewHotelService` (see `SEED_DATA.md`), so the shape below
> is the agreed target, not a live schema. It is written down now because the
> Dart model layer added for the Hotel Details page (2026-08-25) already has
> these fields, and the two must not drift.
>
> Nothing here is a destructive change: the collection has no documents.

| field | type | notes |
|---|---|---|
| name | map<lang,string> | `{en, ku, ar}`, like every other catalog collection |
| address | map<lang,string> | street line under the hotel name; falls back to `city` |
| city | map<lang,string> | |
| region | string | |
| country | string | |
| location | geopoint | drives the map card; absent hides the map, never fakes it |
| imageUrls | array<string> | Storage URLs, in gallery order. The first is the card photo |
| starRating | number | 0–5, the **official classification** |
| reviewScore | number | 0–10, the **guest score**. Server-owned (see below) |
| ratingCount | number | server-owned |
| ratingBreakdown | map<1–5, number> | server-owned |
| categoryScores | map<category, number> | 0–10 per category, server-owned or provider-supplied |
| checkInTime | string | `HH:mm` wall-clock at the property, not a timestamp |
| checkOutTime | string | `HH:mm` |
| pricePerNightFrom | number | list-card display only — never the charged price |
| amenities | array<string> | the seven filter chips on the search screen |
| facilities | array<{id, iconKey, name{en,ku,ar}, category}> | the detail page's Facilities card |
| nearby | array<{id, name{}, placeType, distanceMeters, minutes, lat, lng}> | the Nearby card |
| policies | map | see **Property policies** below |

`starRating` and `reviewScore` are **two different measurements** and are drawn
as two separate badges. Never merge them.

`categoryScores` keys: `location`, `cleanliness`, `comfort`, `service`,
`value`, `facilities`, `wifi`. A category with no data is **absent**, not zero —
a bar drawn at zero reads as "rated badly", which is a different claim.

### The rating aggregates are server-owned

`reviewScore`, `ratingCount`, `ratingBreakdown` and `categoryScores` follow the
same rule as `nature_spots` and `tours`: they are derived by a Cloud Function
from the reviews subcollection, and the admin panel must show them read-only. A
hand-typed average is overwritten by the next review.

Until then, `PreviewHotelReviewService` derives them in memory — in the service,
never in a widget.

### `hotels/{hotelId}/rooms` (subcollection) — permanent room data

| field | type | notes |
|---|---|---|
| name | map<lang,string> | e.g. "Deluxe King Room" |
| description | map<lang,string> | optional |
| imageUrls | array<string> | |
| sizeSqm | number | optional |
| adultCapacity | number | |
| childCapacity | number | |
| maxOccupancy | number | the ceiling the guest counters enforce |
| bedConfiguration | array<{type, count}> | `single/twin/double/queen/king/sofa/bunk` |
| facilities | array<facility> | same shape as the hotel's |

Price and availability are **not** here — they change per search, and a stale
number on a permanent document is worse than no number.

### `hotels/{hotelId}/offers` (subcollection) — a priced, bookable rate

| field | type | notes |
|---|---|---|
| roomTypeId | string | our id, from `rooms` |
| currency | string | |
| nightlyPrice | number | |
| totalPrice | number | for the searched stay |
| taxes | number | |
| fees | number | |
| taxesIncluded | bool | **stored, not inferred** — the UI must always be able to state which figure it is showing |
| breakfast | string | `included` / `extra` / `unavailable` |
| cancellationType | string | `free` / `partial` / `nonRefundable` |
| cancellationDeadline | timestamp | optional |
| cancellationPenalty | number | optional |
| prepayment | string | `none` / `partial` / `full` |
| paymentTiming | string | `payNow` / `payLater` / `payAtProperty` |
| availableQuantity | number | the **only** source for "Only N rooms left". Scarcity copy is never manufactured |
| providerId, providerHotelId, providerRoomId, ratePlanId, searchSessionId | string | optional, provider-side ids |

Provider ids are kept separate from our own so a room can be re-priced or booked
through whichever provider supplied it **without any provider-specific branch
reaching a widget** — normalization belongs in the repository layer.

Taxes and fees are never silently omitted. The checkout rule that already
applies to tours applies here too: the charge must be re-priced and
re-checked server-side, in one transaction, at booking time. A client-side
availability or price check is a suggestion, not a check.

### Property policies (`hotels/{hotelId}.policies`)

| field | type |
|---|---|
| checkInFrom, checkOutUntil | string `HH:mm` |
| childPolicy, cribPolicy, extraBedPolicy | map<lang,string> |
| minimumAge | number |
| petPolicy, smokingPolicy, accessibility | map<lang,string> |
| acceptedPaymentMethods | array<string> |
| specialRequestsSupported | bool |

Every field is optional and **each row hides without data**. A property that
has published nothing shows nothing, rather than a default a guest could act on.

### `hotels/{hotelId}/reviews` (subcollection)

Same shape and same rules as `nature_spots/{spotId}/reviews`, deliberately: the
Hotel Details page reuses that screen through a service adapter, exactly as
Explore Tours does. **The document id is the author's uid**, which is what makes
one review per person per hotel enforceable in the rules rather than merely
intended.

| field | type | notes |
|---|---|---|
| userId | string | equals the document id |
| userName | string | denormalized, so a deleted account keeps its attribution |
| avatarUrl | string | optional |
| comment | string | 3–1000 characters, mirrored in `firestore.rules` |
| rating | number | 0.5–5.0 in half-star steps |
| createdAt | timestamp | |
| status | string | `published` |
| helpfulCount | number | server-owned, from the `votes` subcollection |

## `cars`
| field | type | notes |
|---|---|---|
| name | string | |
| year | number | |
| rentalCompany | string | |
| companyTag | string | |
| imageUrls | array<string> | |
| capacity | number | |
| fuelType | string | |
| bags | number | |
| hasAC | boolean | |
| paymentInfo | string | |
| location | geopoint | |
| pricePerDay | number | |
| transmission | string | `"automatic"` \| `"manual"` — added for the Car Rental Details screen's facilities row |
| extras | array<map> | optional add-ons, see below |
| conditions | map | supplier terms, see below — **every key optional** |

**Not yet read by the app.** The Car Rental, Car Rental Results and Car Rental
Details screens all read `PreviewCarRentalService` (typed mock data), not this
collection — see `SEED_DATA.md`. The three rows added above document what the
Details screen expects once a rental provider is connected, so the admin panel
and a future importer agree on shape before anything is written.

### `cars.extras[]` — optional add-ons
| field | type | notes |
|---|---|---|
| id | string | stable per supplier; the app keys the user's selection on it |
| name | map | keyed by locale `{ en, ku, ar }` |
| pricePerDay | number | charged per rental day, matching how the screen labels it |
| selection | string | `"checkbox"` (0 or 1) \| `"quantity"` (stepper) |
| minQuantity | number | default 0 |
| maxQuantity | number | supplier ceiling — the stepper's `+` disables here. Default 1 |

Per-vehicle rather than a global catalogue, so two suppliers can offer the same
add-on at different prices without a schema change.

### `cars.conditions` — supplier terms
| field | type | notes |
|---|---|---|
| fuelPolicy | string | `"fullToFull"` \| `"fullToEmpty"` \| `"sameToSame"` |
| mileagePolicy | map | `{ unlimited: bool, kilometresPerDay?, extraKilometrePrice? }` |
| depositAmount | number | in the vehicle's `currencyCode` |
| damageExcess | number | |
| freeCancellationUntil | timestamp | |
| minimumDriverAge | number | |
| requiredDocuments | array<map> | each keyed by locale `{ en, ku, ar }` |
| guaranteedModel | boolean | `false` renders the "or a similar vehicle" disclaimer |

> **Every field here is optional on purpose.** These are contractual and
> financial terms a user would act on, so none may be invented for review data.
> Absent fields hide their row, and a fully empty `conditions` hides the Rental
> Conditions card altogether — the same rule the distance line already follows
> when the device has no position fix. Nothing here is populated in the preview
> service today.

## `tours`

**Substantially revised for the Explore Tours screen (Phase 6).** The original
eight-field draft could not render a single card: the text fields were plain
strings in a trilingual app, `duration` was a pre-rendered English sentence,
and there were no dates, no active flag and no way for the admin panel to
choose what appears in the carousel or the Trending section. Nothing had been
seeded, so there is no migration — but the admin panel's tour form must match
this shape.

| field | type | notes |
|---|---|---|
| name | map | keyed by locale `{ en, ku, ar }`. **Changed from a plain string** — the app is trilingual and switching language must not cost a second read, the same rule `nature_spots`, `featured` and `legal_documents` already follow. Missing locale falls back to `en` |
| description | map | same shape. Shown clipped on the card, in full on the detail screen |
| locationLabel | map | same shape. The readable place line, e.g. "Rawanduz, Erbil". **New** — a geopoint cannot be shown to a user and a label cannot be measured against, so the collection needs both |
| companyTag | string | the operator badge in the card's corner, e.g. `"AB group"`. Deliberately **not** a locale map: it is a company's own name, and translating a brand is wrong in the same way translating "Booking.com" would be |
| durationDays | number | **Replaces `duration: "3 days travel"`.** A stored sentence would make the Kurdish and Arabic cards read English; the app builds the line in all three languages from this number |
| features | array<string> | what the tour includes, as the ids in `lib/models/tour.dart` (`TourFeature`): `camping`, `hiking`, `guide`, `food`, `swimming`, `campfire`, `transport`, `photography`, and — **added with the Explore Tours reference rebuild** — `activity`, `wifi`, `electricity`, `tent`. The list card draws the **first five** (the reference card shows five) and drops any id the app has no icon for, so a new tag here still needs a matching enum value in the app. The four new ids are additive: no seeded document needs migrating |
| imageUrls | array<string> | Storage download URLs. The first is the list-card thumbnail; the carousel shows them all for a highlighted tour |
| location | geopoint | the meeting point, used to compute the live distance; never displayed directly |
| pricePerPerson | number | **Optional.** Absent hides the price box rather than drawing a zero — a tour whose price is not set yet is not free |
| currency | string | `"USD"` \| `"IQD"` \| `"EUR"`, matching `AppCurrency` and `bookings.currency`. **New.** The price the operator quoted, and **the currency a charge must be settled in** — see `currency_rates` below for why display conversion is a separate, explicitly approximate thing |
| reviewScore | number | 0–10, Booking.com-style. **Added in the gap-closing pass.** The 5-star row is derived (`round(score / 2)`), never stored. Optional: absent hides the badge rather than drawing a zero. **Server-owned** — see below |
| ratingCount | number | how many reviews `reviewScore` averages — an 8.7 from one review is not an 8.7 from two hundred, which is why the card prints both. **Server-owned** |
| ratingBreakdown | map | `{ "1": n … "5": n }`, the 5★→1★ distribution. **Server-owned.** Not drawn on the list card; it is what a Tour Reviews screen would use |
| capacity | number | **Optional.** How many travellers the departure takes. Absent means the operator published none, and the availability line is simply not drawn rather than guessed at |
| minAge | number | **Optional. Added for the Traveler Info (checkout step 1) screen.** The operator's minimum traveller age in years. Absent means the departure has no age restriction, so no existing document needs migrating. Enforced against every traveller's entered date of birth before the form may advance — a group tour that says 18+ must not be able to accept a 12-year-old, and the check belongs where the birth dates are collected |
| bookedCount | number | how many places are taken. **Server-owned** — see the availability note below |
| cancellationPolicy | string | one of `free_24h`, `free_48h`, `free_7d`, `non_refundable` — a **tier**, not free text. The wording lives in `legal_documents/cancellation_refunds`; a per-tour paragraph would drift from the policy the app actually enforces |
| guideLanguages | array&lt;string&gt; | ISO 639-1 codes the guide speaks: `en`, `ku`, `ar`, `tr`, `fa`. A closed set, so the filter chips and the card label can be localized |
| transportAvailable | boolean | whether this departure offers the optional bus add-on. Operator/admin controlled; false hides/disables the checkout option |
| transportPricePerPerson | number | optional bus add-on price for one traveller, quoted in the tour's `currency`. Required by the UI when `transportAvailable == true`; absent never means free |
| startAt | timestamp | **New.** Departure. Drives the list ordering *and* the date filter |
| endAt | timestamp | **New.** Return. Optional — a one-day tour may omit it, and the card then prints a single date instead of "Aug 14 - Aug 14" |
| trending | boolean | **New.** True puts the tour in the screen's "Trending Tours" section, which is otherwise just the catalog |
| trendingOrder | number | **New.** Ascending order within that section |
| highlighted | boolean | **New.** True puts the tour in the screen's top carousel |
| highlightOrder | number | **New.** Ascending order within that carousel |
| active | boolean | **New.** False pulls a tour off the list without deleting it — same flag, same purpose as `featured.active` and `nature_spots.active` |

### The three rating aggregates are server-owned — the admin panel must not edit them

`reviewScore`, `ratingCount` and `ratingBreakdown` are not values anyone types.
The `syncTourReviewAggregates` Cloud Function (`functions/index.js`) recomputes
all three from the `reviews` subcollection whenever a review is written — the
same arrangement `nature_spots` uses, copied deliberately rather than
reinvented so the two catalogs cannot end up with different guarantees.

Why the server has to own it: `tours` is **admin-only write**
(`SECURITY.md` 1), and must stay that way — a client that could write the
average score of a tour could give a competing operator a 2.0 without leaving
a review. Why it **recomputes** rather than increments: triggers are
at-least-once, so a duplicate delivery is a documented guarantee; an
`increment(1)` applied twice corrupts the count permanently, while a recompute
applied twice gives the same answer and repairs earlier drift.

**Consequences for the admin panel:** show all three **read-only**.

### `tours/{tourId}/reviews/{reviewId}`

Traveller feedback, and the only thing the aggregates above are derived from.
Same shape and the same rules as `nature_spots/{spotId}/reviews` — **the
document id is the author's uid**, which is what makes "one review per person
per tour" enforceable rather than merely intended.

| field | type | notes |
|---|---|---|
| userId | string | immutable owner UID; equals the document id |
| userName | string | denormalized display name, max 80 characters. Copied, not joined — a review must keep showing who wrote it after that account is renamed |
| avatarUrl | string | optional, presentation-only |
| rating | number | **0.5–5.0 in half-star steps.** Shown as `rating × 2` out of 10. Rules reject anything off the half-step grid |
| comment | string | 3–1000 characters |
| status | string | `published`; retained for moderation visibility |
| createdAt / updatedAt | timestamp | `createdAt` is pinned by the rules on update, so an author cannot re-date an old review |
| helpfulCount | number | **Server-owned.** Counted from the tour review's `votes` subcollection by `syncTourReviewHelpfulCount`; never accepted from the client |

**No new index was needed.** The `reviews` composite indexes in
`firestore.indexes.json` are `COLLECTION_GROUP`-scoped and keyed on the
collection **id**, so they already serve `tours/*/reviews`.

### `tours/{tourId}/reviews/{reviewId}/votes/{voterId}`

Same shape and guarantees as nature-review votes. The document id is the
voter's uid, contains only `userId` and `createdAt`, and can be read only by
that voter by known id; listing voters is denied. The
`syncTourReviewHelpfulCount` trigger counts these documents into the
server-owned `helpfulCount` on the parent review.

### Availability is a server-owned number, and a transaction, not a field

`bookedCount` must be maintained by the tour checkout Cloud Function, never by
a client — a client that could write it could mark a rival's departure full,
or clear it and oversell one.

**Nothing in this app can create a tour booking yet** (the detail/checkout
screen is Phase 6b), so the seeded values are the only writer today. When that
screen is built, its Cloud Function must, **inside one transaction**:

1. re-read `capacity` and `bookedCount`, and refuse the booking if
   `capacity - bookedCount < party size` — checking availability on the client
   is not a check, it is a suggestion;
2. write the booking and bump `bookedCount` together, so two people paying at
   once cannot both take the last seat.

A trigger on `bookings` is not sufficient on its own: by the time it fires the
payment has been taken, and an oversold departure has to be refunded and
apologised for. This is also recorded in `functions/index.js`, in the file that
would own it.

Only two queries are ever run, both with a composite index declared in
`firestore.indexes.json`:

```
carousel:  .where('active', == true).where('highlighted', == true)
             .orderBy('highlightOrder').limit(8)
catalog:   .where('active', == true)
             .orderBy('startAt').limit(200)
```

### Why the search box is not a query

The screen's search field matches a tour **name, location line or operator**,
and Firestore cannot do that at all: it has no substring match, and
`name` is a locale map, so a server-side search would have to pick one of three
languages and fail the other two. The date picker and the trending ordering are
then applied over the same in-memory catalog, so neither costs an extra read or
an extra index.

**One read serves the carousel, the list, the search, the date filter and the
Trending ordering**, and changing a filter costs nothing.

> **When this stops being right.** The catalog is capped at
> `ToursService.catalogFetchLimit` (200 documents), which is both the read cost
> and the ceiling on what search can find. Comfortable for a regional operator
> catalog. Past that, the search belongs in a real search service (Algolia,
> Typesense) or a tokenized `keywords` array — not in a bigger download.

**Prices are a security boundary, not just content.** `pricePerPerson` and
`currency` are what a future checkout charges against, so `tours` stays
admin-only write (`firestore.rules`); a client that could write here could set
its own price to zero before booking. See `SECURITY.md` section 5.

### Sorting and refining still cost no extra read or index

The gap-closing pass added a sort control (soonest / price ↑ / price ↓ / top
rated / nearest), feature chips, guide-language chips, a date **range** and a
party-size filter. All of them run over the one catalog read already in memory
(`TourFilters.sortedFrom`), so the collection still needs exactly the two
indexes listed above.

Two behaviours worth recording because they are decisions, not accidents:

- **Items missing a sort key sort last, never first.** A tour with no price is
  not the cheapest and not the most expensive; an unrated tour is not the worst
  rated.
- **"Nearest to me" falls back to "Soonest" when there is no GPS fix**, and the
  option is not offered at all — presenting an arbitrary order as "nearest" is
  worse than offering one option fewer.

## `currency_rates` *(added for the Explore Tours screen)*

One document, `currency_rates/latest`. **Public read, admin/server write.**

| field | type | notes |
|---|---|---|
| base | string | the currency every rate is quoted against, e.g. `"USD"`. Present in `rates` at `1`, so the cross-rate arithmetic needs no special case |
| rates | map | `{ "USD": 1, "IQD": 1310, "EUR": 0.92 }` — units of each currency per one `base` unit |
| updatedAt | timestamp | shown to the user as part of the disclosure. **An undated rate is worse than no rate** |

A fixed document id rather than a query: one read, no index, and no way for a
stale document to win a race with a fresh one.

**These rates are indicative, not transactional.** They exist so a traveller
can compare a tour priced in USD against one priced in IQD. A charge must be
priced in the operator's own currency and converted by the payment processor,
or the app takes on FX risk it cannot hedge (`SECURITY.md` 5). Every converted
figure in the UI is prefixed `≈` and carries a one-line disclosure above the
list — drawn **only when something on screen was actually converted**, because
a standing notice nobody needs is what makes real disclosures invisible.

Write access is a **financial** control, not an editorial one: a client that
could write this document could make a $500 tour read as $5.

`CurrencyRates.convert` returns **null** for any currency missing from the
table, and the UI then falls back to the operator's own price. Deleting a
currency here is therefore safe; adding a wrong one is not.

> ⚠️ **Nothing refreshes this document yet**, and rates drift. Before release
> it needs either a scheduled Cloud Function pulling from a rate provider (key
> in Secret Manager, never in the repo) or an admin-panel form. Recorded in
> `tool/seed_currency_rates.js` as well.

## `flights`
| field | type | notes |
|---|---|---|
| airline | string | |
| fromAirportCode | string | |
| toAirportCode | string | |
| departTime | timestamp | |
| arriveTime | timestamp | |
| durationMinutes | number | |
| price | number | |
| cabinClass | string | Economy / Premium Economy / Business / First |

## `bookings`

**Substantially expanded for the My Bookings screen (Phase 8).** The original
eight-field draft could not render a single card: it had no title, no image, no
dates, no guest count and no human-readable reference. Nothing has been seeded
yet, so there is no migration — but the admin panel and the future checkout
Cloud Function must both write this shape.

### Rule: a booking is a historical record, so it is denormalized

The card's title, photo, location and dates are **copied onto the booking
document** at purchase time rather than read from `hotels` / `cars` / `tours` /
`flights` at display time. Three reasons, in order of importance:

1. **Correctness.** A booking must always show *what was actually booked*. If a
   hotel is renamed, re-photographed, re-priced or delisted, a joined card would
   silently rewrite the user's own history — and a delisted document would blank
   the card entirely. Booking.com and Agoda both denormalize for exactly this.
2. **Cost.** One `where('userId')` query renders the whole list. Joining means
   1 + N reads fanned out across four different collections, and the client
   cannot batch across collections.
3. **Rules.** A user can read their own bookings without also needing read
   access to every catalog document a booking might point at.

`referenceId` is retained so a card can still deep-link into the live hotel/car/
tour/flight detail screen when one exists — the link is a *navigation* target,
never the source of what the card displays.

### Top-level fields

| field | type | notes |
|---|---|---|
| userId | string | must equal `request.auth.uid`; enforced in rules |
| type | string | `"hotel"` \| `"car"` \| `"tour"` \| `"flight"` — selects the card layout and the type filter chip |
| referenceId | string | id of the hotel/car/tour/flight document. **Navigation only** — never the source of displayed text |
| bookingReference | string | **New.** The human-readable code shown on the card and quoted to support, e.g. `HTL-7845123`. Prefix is `HTL` / `CR` / `FL` / `TO` by type. **Generated server-side** in the checkout Cloud Function, never client-side — a client could otherwise forge or collide one. Indexed, because support looks bookings up by it |
| status | string | `"pending"` \| `"confirmed"` \| `"cancelled"` \| `"completed"`. **`completed` is new** — see the note on the time axis below |
| startAt | timestamp | **New.** Check-in / departure / pickup / tour start. Drives sorting **and** the Upcoming-vs-Past split |
| endAt | timestamp | **New.** Check-out / arrival / drop-off / tour end. Optional for a one-way flight, where it equals arrival |
| totalPrice | number | |
| currency | string | `"USD"` \| `"IQD"`. Rendered per `users.preferredCurrency` only when the two agree; otherwise the **booked** currency wins — a price is a fact about the transaction, not a display preference |
| paymentProvider | string | `"stripe"` \| `"fib"` \| `"nasswallet"` — see `SECURITY.md` section 5.3 |
| paymentStatus | string | **New. Server-owned.** `"pending"` \| `"paid"` \| `"refunded"` \| `"failed"`; written from the provider's verified callback/webhook, not inferred by the client from booking status |
| receiptUrl | string | **New, optional and server-owned.** Short-lived/provider-hosted receipt URL or a backend receipt endpoint. Never a client-uploaded URL. Absent hides “View Receipt” |
| cancellable | boolean | whether the Cancel action is offered. Server-owned; derived from the provider's fare/cancellation rules at purchase time |
| display | map | the denormalized card content — see below |
| bookingDetails | map | anything not shown on the card: add-ons, special requests, provider payload. Deliberately unstructured |

### `display` — what the card actually draws

Keyed by nothing; a flat map, because it is written once and read whole.

| field | type | notes |
|---|---|---|
| title | map | keyed by locale `{ en, ku, ar }` — the hotel/car/tour name, or the airline for a flight. A **map, not a string**, for the same reason as `featured.title`: switching language must not cost a second read. Missing locale falls back to `en` |
| locationLabel | map | same shape. "Erbil, Iraq" / "Erbil International Airport" |
| imageUrl | string | Storage download URL for the card thumbnail. **Copied, not referenced** — same reasoning as above. Flights have no thumbnail and omit it |
| guestCount | number | guests (hotel) / travelers (tour) / drivers (car) / passengers (flight). One field, four labels — the label comes from `type`, so the schema does not need four near-identical fields |
| guestLabel | string | `"adults"` \| `"children"` \| `"mixed"` — which noun the count is rendered with |

### `bookingDetails.travelers[]` — who is actually going

**Added for the Traveler Info screen (checkout step 1).** `display.guestCount`
is only a number; it cannot tell the operator who to expect. The named
travellers live under `bookingDetails`, which the schema already reserves for
"anything not shown on the card".

| field | type | notes |
|---|---|---|
| fullName | string | 2–80 characters, as entered by the person booking |
| dateOfBirth | timestamp | stored as a **date, not an age**, for the same reason as `users.dateOfBirth` — an age goes stale, a birth date does not, so a `tours.minAge` check stays correct however long after booking it is re-run |
| isLead | boolean | exactly one traveller is the lead — the person the booking is issued to. Defaults to the first traveller, and the form does not allow zero or two |

Alongside it, `bookingDetails.contact` holds the contact person — `{ fullName,
email, phone, dialCode }` — who is **not necessarily travelling**. That is why
the contact block and the traveller list are separate on the screen rather than
the first traveller doubling as the contact.

> **Step 1 writes nothing to Firestore.** The traveller list is held in memory
> and handed to the Payment step as an argument. `bookings` is created only by
> the checkout Cloud Function after the provider confirms the charge (see "Who
> may write" below) — so there is no client path that could persist this, and
> deliberately no draft collection holding named minors' birth dates before any
> purchase exists.

### PROPOSED for checkout step 3 — **not approved, nothing writes these yet**

Raised while building the Review & Confirm screen (2026-08-20). The screen
itself needs none of them — it writes nothing — but a checkout Cloud Function
that turns it into a real booking would, and both Agoda and Booking.com store
them. **Do not implement until signed off.**

| field | type | why |
|---|---|---|
| `bookingDetails.transport` | boolean | whether the optional bus add-on was bought. It currently has nowhere structured to live, so the operator cannot tell who is on the bus |
| `bookingDetails.priceBreakdown` | map | `{ pricePerPerson, travelers, transportPricePerPerson, transportTotal, subtotal, currency }`. `totalPrice` alone cannot reproduce the line items the user agreed to, and a receipt that only shows a grand total is what refund disputes are made of |
| `bookingDetails.termsVersion` + `termsAcceptedAt` | number + timestamp | which Terms version was in force **for this purchase**. `users.termsAcceptedAt` records signup consent, which is a different event and can be years earlier |
| `bookingDetails.cancellationPolicy` | string | a snapshot of the `tours.cancellationPolicy` tier the departure was **sold under**. The live tier can change; `bookings.cancellable` is a boolean and cannot say "free until 48h before" |

All four are server-written from the checkout function's own request, never
client-supplied — `bookings` stays admin/function-write per `SECURITY.md` 1.


### Type-specific fields, all under `display`

Only the block matching `type` is present. A card never reads a field belonging
to another type.

| type | field | notes |
|---|---|---|
| hotel | `roomName` | optional, e.g. "Deluxe Twin" |
| flight | `fromCode` / `toCode` | IATA codes, e.g. `EBL` / `IST`. Always rendered left-to-right, even in Kurdish/Arabic — a route is not a sentence |
| flight | `fromCity` / `toCity` | maps keyed by locale, drawn under the codes |
| flight | `durationMinutes` | number; formatted as "2h 45m" in the active language |
| flight | `seat` | optional string, e.g. `16A`. Absent before check-in, and the row is **hidden rather than faked** — same rule as Explore Nature's Distance row |
| flight | `cabinClass` | `"economy"` \| `"premium_economy"` \| `"business"` \| `"first"`. Drawn as the info-coloured pill. Stored as a **key, not a display string**, so it can be translated |
| car | `pickupLocation` | map keyed by locale |
| car | `carClass` | optional, e.g. "SUV – Premium" |
| tour | `durationHours` | number; the tour's own length, distinct from `startAt`/`endAt` |

### Queries and indexes

```
list:   .where('userId', == uid).orderBy('startAt', desc).limit(50)
```

One query serves the whole screen. **Type and time filtering are applied in
Dart**, not in the query — the same decision, for the same reasons, as
`nature_spots` above: two independent filter dimensions (type chip × time
segment) would need a separate composite index per combination, and a user's own
booking list is small enough that one read is cheaper than five indexes. A
`userId` + `startAt` composite index is declared in `firestore.indexes.json`.

> **When this stops being right.** At 50+ bookings per user the list should
> paginate on `startAt` rather than raising the limit. Recorded as a deliberate
> trade, not an oversight.

### Who may write

**No client writes, in either direction.** A booking is created only by the
checkout Cloud Function, after the payment provider confirms the charge
(`SECURITY.md` section 5). Cancellation is likewise a Cloud Function — it must
call the provider's cancel API and compute the refund, neither of which a client
can be trusted to do. The rules therefore grant the client **owner-read only**;
`create`, `update` and `delete` are all denied.

If the client could write here, a modified app could mint itself a confirmed
booking it never paid for. That is the entire reason this collection is
read-only from the app.

> **There is no such thing as a guest booking.** The rules require an auth uid,
> so a signed-out user sees a sign-in prompt rather than an empty list — the
> same precedent as favorites and the drawer's Currency row (`SECURITY.md` 6.1f:
> no anonymous mirror of signed-in data).

## `favorites`

Document id is **deterministic**: `{uid}_{itemType}_{itemId}`. That makes
favoriting a plain set/delete on a known document instead of a
query-then-write, and makes a double-tap idempotent rather than creating two
rows for the same place. The id is *not* what the rules trust — they check
the `userId` field, so a forged id gains nothing.

| field | type | notes |
|---|---|---|
| userId | string | must equal `request.auth.uid`; enforced in rules |
| itemType | string | `"nature_spot"` \| `"hotel"` \| `"car"` \| `"tour"` \| `"flight"` — `flight` added for the Home screen, whose carousel can feature one |
| itemId | string | |

There is no such thing as a guest favorite: the rules require an auth uid, so
the Home screen prompts an unsigned-in user to log in rather than writing
anything locally.

---

**Notes for the agent:**
- Keep subcollections (like `hotels/{id}/rooms`) instead of separate
  top-level collections with a foreign key, when the child data is always
  fetched alongside the parent (cheaper reads, simpler security rules).
- Use top-level collections with a reference field when the child data
  needs to be queried independently of its parent (e.g. `bookings` needs
  to be queried by `userId` across all hotels/cars/tours, so it can't live
  nested under `hotels/{id}`).
- Revisit this file after Phase 0 planning — this is a starting draft, not
  final.
