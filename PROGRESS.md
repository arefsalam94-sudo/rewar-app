# PROGRESS.md — Build Log

Append a new entry every time a page/task is approved. Never delete old
entries — this is the project's memory across sessions.

Template for each entry:

```
## [Date] — [Page/Task name]
Status: APPROVED
What was built: [1-3 sentences]
Known placeholders/limitations: [anything not fully wired up]
Firestore collections touched: [list]
Example data seeded: [what, and whether via admin panel or manually]
```

---

> **Note on this log's history.** Entries below start at the Home screen.
> The screens built before it (Splash, Language, Onboarding, Login, Register,
> Terms, Account Setup, Register Complete, and the three password-reset
> screens) were never recorded here — their decisions live in the notes
> section of `DESIGN_SYSTEM.md` instead. Worth backfilling.

## 2026-08-05 — Phase 2: Main dashboard (Home screen)
Status: **AWAITING APPROVAL** — not yet approved.

What was built: The post-login / post-guest dashboard from the `main screen`
reference. Top bar (hamburger · bare logo · language globe), a time-of-day
greeting with the user's name, a swipeable featured carousel reading the new
`featured` collection, a "Plan your journey" grid of five cards (Explore
Nature, Where to Stay, Car Rental, Flight Ticketing, Explore Tours), and a
floating liquid-glass bottom nav. Light **and** dark, in English, Kurdish and
Arabic with full RTL. 26 new widget tests; 125 pass, analyzer clean.

Decisions taken (all four confirmed by the user before building):
- Featured slides come from a **curated `featured` collection**, not a
  fan-out across four catalog collections — one read, admin-ordered, and a
  slide can point at any entity type.
- Guests get a **sign-in prompt** on the heart; there is no anonymous
  favorite, so `favorites` keeps a single owner-only source of truth.
- The "N+ places" number is a **live `count()` aggregation**, and falls back
  to a plain "Explore" label rather than an invented number.
- The Map tab opens the **platform maps app** at Erbil via `url_launcher`
  (new dependency, approved).

Known placeholders / not wired up:
- **The five per-card photographs are missing.** Only the page background was
  supplied, so every journey card renders the design system's glass fill
  instead of its photo. The card already accepts an `imageAsset`; dropping
  the files in and setting five paths is the whole change.
- **Nothing is seeded, because there is still no Firebase project.** The
  screen runs in preview mode behind the yellow banner: bundled slides, a
  bundled count of 120, favorites not persisted.
- **Not yet run on a device or emulator.** `flutter run` fails on this
  machine with "Building with plugins requires symlink support" until
  Developer Mode is enabled in Windows settings. Verification so far is the
  test suite only.
- Hamburger menu, Explore/detail navigation, Trips and Saved are all
  deliberately inert ("coming soon") — those screens are later phases.
- Login **success** still doesn't reach this screen; only "Continue as Guest"
  does. Real auth is still unwired, as it was before.
- The Welcome/tagline transition screen (Phase 1, item 5) was skipped — the
  guest path goes straight from Login to here.

Firestore collections touched: `featured` (read), `nature_spots`
(count), `favorites` (read/write). Rules for all three added to
`firestore.rules`; composite index for the carousel query added to
`firestore.indexes.json`. **Rules are written but not yet deployed or
emulator-tested** — that needs the Firebase project.

Example data seeded: none yet. `tool/seed_home_screen.js` is ready and seeds
four `featured` slides plus one `nature_spots` document.

## 2026-08-09 — Phase 3: Explore Nature list screen
Status: **AWAITING APPROVAL** — not yet approved.

What was built: The Explore Nature list screen from the `explore nature.jpg`
reference, opened by tapping the Home screen's "Explore Nature" card (the only
journey card that now navigates; the other four still say "Coming soon"). The
shared glass back button, a swipeable carousel of the places flagged
`highlighted`, a multi-select filter bar (Hiking · Beach · Sunset View ·
Customize), and a card per place carrying its 0–10 score, a derived 5-star row,
name, location, live distance and a clipped description. Light **and** dark, in
English, Kurdish and Arabic with full RTL. 19 new tests; 160 pass, analyzer
clean.

Decisions taken (all four confirmed before building):
- The carousel reads **`nature_spots` where `highlighted == true`**, not a
  filtered view of `featured` — the slide needs the place's own description,
  and it keeps one source of truth for the whole screen.
- The star row is **derived from `reviewScore`** (`round(score / 2)`), not
  stored. One number to enter in the admin panel, and the score and the stars
  can never disagree. Matches the reference: 8.2 → 4 stars, 8.7 → 4 stars.
- Distance is **computed live** from the device GPS fix; when location is off
  or denied the row is **hidden** rather than showing a distance from
  somewhere the user is not.
- Filter chips are **multi-select** via `array-contains-any`, which is OR
  logic — selecting more chips widens the results.

Schema changes (all in `DATA_MODEL.md`, **copy to the admin panel repo**):
`nature_spots.name` / `.description` became locale maps; `locationLabel`,
`categories`, `highlighted`, `highlightOrder` and `active` were added;
`reviewScore` (0–10) replaced `rating` (0–5); `distanceLabel` was removed.
Nothing had been seeded yet, so there is no migration — but the admin panel's
nature-spot form has to match.

Known placeholders / not wired up:
- **The Customize filter has no options yet** — they are the next hand-over, so
  the chip is present and shows "Coming soon" rather than guessing a sheet.
- **The place photographs are missing.** Only Rawanduz Canyon has a bundled
  image (reused from the Home carousel); the other two render a brand-coloured
  panel with a park icon. Dropping the files in and setting `imageUrls` is the
  whole change.
- **Tapping a place says "Coming soon"** — the spot detail screen is the next
  ROADMAP item and has not been specified.
- **Nothing is seeded, because there is still no Firebase project.** The screen
  runs in preview mode on bundled content.
- **The list is a single page of 20**, newest-scoring first. No infinite scroll
  or "load more" yet.
- **Not yet run on a device or emulator** — same blocker as the Home screen
  (`flutter run` needs Windows Developer Mode for plugin symlinks).
  Verification so far is the test suite only.
- The side drawer's own "Explore Nature" service row is still inert; only the
  Home card navigates, as specified.

Firestore collections touched: `nature_spots` (read only). The existing public
read / admin-only write rule already covers it; its comment block was updated
and **three composite indexes** were added to `firestore.indexes.json`
(highlighted carousel, unfiltered list, filtered list). **Rules and indexes are
written but not yet deployed or emulator-tested** — that needs the Firebase
project.

Example data seeded: none yet. `tool/seed_explore_nature.js` is ready and seeds
the three places from the reference.

## 2026-08-09 — Phase 3: Customize Filters screen
Status: **AWAITING APPROVAL** — not yet approved.

What was built: The Customize Filters modal from the
`explore nature-filters.jpeg` reference, opened by the Explore Nature screen's
Customize chip. One elevated glass card holding the back button + title on one
line, the "Find places that match your trip" hint, a live "N Filters selected"
counter with Reset All, a **Place Type** group (Forest, Mountain, Canyon, Park,
Lake, Waterfall, River, Museum) and a **Facilities & Amenities** group
(Parking, Restrooms, Restaurants, Cafes, Mobile signal, Lodging nearby, ATM
nearby), and a "Show N Places" apply button whose number updates on every tap.
Light **and** dark, in English, Kurdish and Arabic with full RTL. 33 tests on
this feature; 174 pass overall, analyzer clean.

Decisions taken (all four confirmed before building):
- **All filtering moved into Dart.** Firestore permits one array clause per
  query and the screen now has three multi-select dimensions, so a single
  server-side query cannot express it — and the apply button's count has to be
  exact on every tap. The catalog is read once and filtered in memory. This
  **supersedes** the earlier "multi-select Firestore query" decision from the
  list screen; the `array-contains-any` composite index has been removed.
- **OR within a group, AND across groups.** More place types widens; adding a
  facility narrows.
- The reference's duplicated "Lake" chip was treated as a design slip —
  **8 place types**, not 9.
- Customize **combines** with the quick chips rather than replacing them. The
  counter and Reset All cover only the two Customize groups, as drawn, but the
  quick chips still count toward the result total on the button.

Also changed, per the same request:
- The Explore Nature background now blurs at **σ=40** (was 16), over the same
  brand gradient wash from `DESIGN light.md` / `DESIGN dark.md`. Both screens
  share one asset + sigma constant, because the design files require the
  treatment to be identical across a flow.
- New `GlassPanel.elevated`, implementing the design file's modal rule (40px
  blur, +8% fill opacity). Opt-in; no approved screen changed.

Schema changes (in `DATA_MODEL.md`, **copy to the admin panel repo**):
`nature_spots.placeTypes` and `nature_spots.amenities` added as string arrays.
The admin panel's nature-spot form needs both, as multi-selects.

Known placeholders / not wired up:
- **Nothing is seeded, because there is still no Firebase project.** The screen
  runs on the three bundled places, so "Show N Places" counts up to 3.
- **The catalog read is capped at 200 documents** — the ceiling on what the
  filters search and what the counter counts. Fine now; `DATA_MODEL.md` records
  what to do when it isn't.
- **Not yet run on a device or emulator** — same Windows Developer Mode
  blocker. Verification is the test suite only.
- Tapping a place still says "Coming soon"; the spot detail screen is next.

## 2026-08-13 — Phase 3: Nature place detail screen
Status: **AWAITING APPROVAL** — not yet approved.

Built the selected-place detail route from the supplied `Explore nature +.png`
reference: blurred/gradient-washed selected cover, scrollable gallery, shared
back button, app-standard score/star badges, localized overview with cover,
three curated nearby stays, place map, live Open-Meteo weather, and the two
newest published visitor reviews. The whole review card is visibly actionable
and exposes a callback for the next review-writing screen.

Database/application changes: `nature_spots.nearbyStays` was added for curated
accommodation previews; `nature_spots/{spotId}/reviews` was added with owner
write validation, public published reads, and a composite index. Weather is
coordinate-driven and deliberately not stored. The seed script now includes
three nearby stays and two example reviews for Rawanduz. Real accommodation
images and all place galleries still need Storage URLs from the admin workflow.

Competitive information audit: current Booking.com and Agoda property pages
both prioritize gallery, location/nearby context, facilities, aggregate score,
review count and review excerpts. This implementation includes the relevant
nature-destination equivalents without copying either product's UI.

Firestore collections touched: `nature_spots` (read only, unchanged rules).
`firestore.indexes.json` lost the now-unused `categories` array index.

## 2026-08-10 — Phase 8: Policy screen (Policy of App)
Status: **AWAITING APPROVAL** — not yet approved.

What was built: The Policy hub from the `Policy of App` reference, opened by
the side drawer's **Policy** row (previously inert). The shared glass back
button, the "Policy of App" title with its hint line, and seven liquid-glass
cards — each a stroke-only circled icon, a title, a hint line and a chevron.
Light **and** dark, in English, Kurdish and Arabic with full RTL. 17 new tests;
193 pass overall, analyzer clean.

Decisions taken (both confirmed before building):
- **Background:** reuses `main screen back image.webp` rather than a new asset
  or the Nature photo. Policy is opened from the Home drawer, so it stays in
  the Home/account category — the design files call for one photo per screen
  *category*, and Policy is not a Nature/Hotel/Car/Tour/Flight screen.
- **A seventh card, `Account & Data Deletion`, was added** beyond the six in
  the reference screenshot. Both the App Store and Play Store require an
  in-app route to account and data deletion for any app with sign-up, so a
  Policy hub without it is a store-review risk, not a stylistic choice.

Also changed:
- `PageBackground` gained an optional `darkBlurSigma`. Dark mode's blur was
  previously a fixed 8 with light mode at 0; a screen that blurs in *both*
  modes needs the same sigma in each or the treatment stops matching itself.
  Opt-in, defaulting to the old value — no approved screen changed. Policy
  uses **σ=24** in both modes.
- `PolicyTopic` (`lib/models/policy_topic.dart`) fixes the seven
  `legal_documents` ids in code, so the app, a seed script and the admin panel
  cannot drift on naming. `PolicyTopic.terms` is asserted equal to
  `LegalDocumentService.termsDocId` by a test — if those ever diverge, a user
  could accept one wording and read another.

Known placeholders / not wired up:
- **All seven cards are inert and answer "Coming soon."** As specified. The
  policy documents themselves have not been written, and showing a blank legal
  page would be worse than saying so.
- **No Firestore read, so nothing was seeded** and no new security rules were
  needed. `SEED_DATA.md` is unchanged, deliberately.
- **Not yet run on a device or emulator** — the same Windows Developer Mode
  blocker as every screen since the Home screen. Verification is the test
  suite only.
- The drawer's other rows (My Bookings, Billing, Settings, Help/Support, About
  Us, Contact Way) are still inert.

Firestore collections touched: **none.** `DATA_MODEL.md` gained a clearly
marked *proposed, not approved* section under `legal_documents` describing the
six extra document ids these rows will read, plus two rows that are more than
text and need their own decisions first — Contact & Complaints (may need a
`complaints` collection with owner-only read/create if it becomes a form) and
Account & Data Deletion (must be a **Cloud Function**; a client can never be
allowed to cascade a delete across `users`, `bookings`, `favorites` and
Storage).

Example data seeded: none — this screen reads nothing.

### Gap review against Agoda / Booking.com
Their apps surface, beyond our seven: **Cookie & Tracking Preferences** (a
consent screen, not just a document — needed for EU/UK users and for
App Tracking Transparency on iOS), **Open-Source Licenses** (an attribution
obligation from the packages already in `pubspec.yaml`; Flutter gives this
almost free via `showLicensePage`), **Content/Review Guidelines** (only
relevant once users can post reviews — Phase 4's `hotels/{id}/reviews`),
**Accessibility Statement**, and **Modern Slavery / Human Rights statements**
(large-company obligations, not applicable yet). Deliberately left out to
match the reference screenshot; recorded here so the decision is on record.

## 2026-08-10 — Phase 8: Privacy Policy document screen
Status: **AWAITING APPROVAL** — not yet approved.

What was built: The policy document page from the `policy of app+` reference,
opened by tapping **Privacy Policy** on the Policy hub. The shared glass back
button, the row's own title as the page header at the hub's 28px title size, a
"Last updated" line beneath it, and one liquid-glass card holding the document
— untitled lead-in paragraph, section headings, bulleted lists with bold
lead-ins, and plain paragraphs. Light **and** dark, in English, Kurdish and
Arabic with full RTL. 20 new tests; 214 pass overall, analyzer clean.

Decisions taken (all four confirmed before building):
- **The wording lives in Firestore** (`legal_documents/privacy_policy`), same
  as the Terms, with the supplied text bundled as the preview-mode fallback.
  A privacy policy that can only be corrected by shipping a new build is a
  liability, and both stores also require a live URL to it.
- **Rich text is stored as structured blocks**, not markers inside a string.
  You asked for it to look exactly like the image; blocks are the option that
  guarantees that, because nothing is parsed at render time — a typo in the
  admin panel can't silently break the formatting, and RTL bullets don't
  depend on a parser knowing which end of the string the bold run is on.
- **"Last updated" was added under the header**, as requested, showing date
  **and** time (`2026-08-10 14:30`) in a plain unambiguous order.
- **The "…address in the Contact section" wording was kept exactly as
  supplied**, even though this document has no Contact section. Flagged below.

Schema change (in `DATA_MODEL.md`, **copy to the admin panel repo**):
`legal_documents` sections now accept a **second shape** alongside the
original. `{heading, body}` still parses untouched — `terms_of_service` needed
no migration — and `{heading?, blocks: [{type, lead?, text}]}` was added for
headings-optional sections, bullets and bold lead-ins. A test pins the legacy
shape so it can't regress. **The admin panel needs a block editor for this**,
not a plain textarea.

Also changed:
- `LegalDocumentService.fetchTerms` now delegates to a general
  `fetchDocument(docId, language)`; the Terms screen is untouched and its
  behaviour is unchanged.
- The Policy hub gained a `_wiredTopics` set. Only `PolicyTopic.privacy` is in
  it; the other six rows still say "Coming soon". Add a topic there the moment
  its document exists — everything else about the row already works.
- The document screen is **parameterised by `PolicyTopic`**, because you
  confirmed all the rows share this layout. It is not wired to the other six.

Known placeholders / not wired up:
- **Nothing is seeded, because there is still no Firebase project.** The
  screen runs in preview mode on the bundled copy.
  `tool/seed_privacy_policy.js` is written and ready.
- **`node` is not installed on this machine**, so the seed script has not been
  syntax-checked or run — same as the three seed scripts written before it.
- **The Kurdish and Arabic wording is a translation, not legal drafting.**
  `legalReviewed` is false and the yellow warning banner is shown on the page
  because of it. Removing the banner is a one-line change if you'd rather the
  page match the screenshot exactly.
- **"…the address in the Contact section" points at a section that does not
  exist** in this document, and the hub's own Contact & Complaints page is not
  built. Kept verbatim at your instruction.
- **The other six policy rows are still inert.**
- **Not yet run on a device or emulator** — same Windows Developer Mode
  blocker. Verification is the test suite only.

Firestore collections touched: `legal_documents` (read only). The existing
public-read / admin-only-write rule already covers the new document id — it
matches on `{docId}`, so no rule change was needed and none was made. No index
is needed either: the document is fetched by known id, and `list` stays denied.

Example data seeded: none yet. `tool/seed_privacy_policy.js` seeds
`legal_documents/privacy_policy` v1 in all three languages.

### Gap review against Agoda / Booking.com — Privacy Policy specifically
The supplied text is a reasonable short-form policy, but it is materially
thinner than either of theirs, and three of the gaps are things **our own code
already does**, which makes them accuracy problems rather than omissions:

1. **Precise location is collected, but the policy says "approximate."** The
   Explore Nature screen reads a GPS fix via `DeviceLocationService` to show
   the distance to a place. That is precise location under both stores' data
   labels.
2. **Camera and photo-library access is not mentioned at all.** The drawer's
   avatar picker uses `image_picker` for both.
3. **Firebase/Google is not named as a processor**, and neither is the SMS
   provider that `SECURITY.md` section 6 requires for phone verification. Both
   stores' privacy forms (Play Data Safety, Apple Privacy Nutrition Label) ask
   for third-party SDKs by name, and the answers there must match this text.
4. **No international-transfer section.** Firebase stores data outside Iraq;
   Agoda and Booking both have an explicit section on this.
5. **No security-measures section**, and retention is "as long as needed"
   with no criteria — both have concrete sections.
6. **No cookies/tracking section**, which is also what an iOS App Tracking
   Transparency prompt has to point at.
7. **No legal basis for processing, and no right to complain to a supervisory
   authority** — GDPR Article 13 items that both of theirs carry.
8. **"Personalise the content you see" is profiling** and is normally called
   out as such.
9. **Deletion is described as an email request only.** Both stores now expect
   an in-app route — which is exactly the hub's 7th row, so these two should
   cross-reference each other once that page exists.
10. **Children is set at 18.** Unusual: GDPR uses 16 (13 in some places) and
    COPPA 13. Worth confirming with whoever reviews the wording, since it also
    determines the target-age answer on the Play listing.

None of this was added to the page — you supplied exact text and asked for an
exact match. Recorded here so it reaches legal review.

## 2026-08-10 — Phase 8: the remaining six policy documents
Status: **AWAITING APPROVAL** — not yet approved.

What was built: The six documents behind the rest of the Policy hub — Terms &
Conditions, Cancellation & Refunds, Payment Policy, Liability & Disclaimer,
Contact & Complaints, and Account & Data Deletion — in English, Kurdish and
Arabic. **All seven rows now open**; nothing on the hub is inert any more. No
new screen was needed: `PolicyDocumentScreen` was already parameterised by
`PolicyTopic`, so each row opens the same page with its own title and its own
`legal_documents` document. 224 tests pass, analyzer clean.

Decision taken without asking, because the alternative was clearly worse —
**flagging it here for your confirmation**:
- **The Terms & Conditions row and the registration consent gate share one
  document.** `PolicyTopic.terms.docId` already *was*
  `LegalDocumentService.termsDocId`, and a test pinned it there deliberately:
  two Terms documents would let a user accept one wording and read another. So
  the new Terms text **replaced** the old placeholder wording ("YOUR
  AGREEMENT" / "PRIVACY") rather than living beside it, and the document was
  bumped to **version 2**. Consequence: the Register flow's Terms screen now
  shows your new text, and anyone who accepted v1 would need re-prompting.
  Nothing is live, so there is nothing to migrate — but say the word if you
  wanted these kept as two separate documents instead.

Also changed — one source of truth for legal wording:
- Every document now lives in **`assets/legal/legal_documents.json`**, read by
  both the app (bundled, preview mode) and `tool/seed_legal_documents.js`
  (writes Firestore). Previously each document was written twice — once in
  Dart, once in JS — and `SEED_DATA.md` carried three separate "keep the two
  in sync" warnings. Seven documents in three languages would have made that
  drift a certainty. There is now nothing to keep in sync.
- `tool/seed_privacy_policy.js` was **deleted**, superseded by the single
  script. The script validates every document before writing any of them.
- Preview mode now parses the bundled asset with the **same**
  `LegalDocument.fromMap()` used on live Firestore data, so a malformed
  document fails in development instead of production.
- **`LegalDocumentBody`** (`lib/widgets/legal_document_body.dart`) was
  extracted from the Privacy Policy screen and is now used by the Terms of
  Service consent screen too. Those two render the same Firestore document, so
  a bullet has to look identical on both — the Terms screen previously drew
  `section.body`, which would have flattened the new Terms bullets into
  unmarked lines.
- `rootBundle.loadString` hands UTF-8 decoding to a background isolate past
  50KB, and that isolate's result never arrives under a widget test's fake
  clock — every test hung on the loading spinner. The service now loads bytes
  and decodes inline.

Text handling — exactly as supplied, with one correction:
- **"Menu fi Support / Help"** in the Contact text was rendered as **"Menu →
  Support / Help"**. The `fi` is an encoding artifact of the arrow; the
  Account & Data Deletion text you sent uses "Menu → Delete Account" in the
  same construction. Say if you meant something else.
- The 3rd document's title is **"Cancellation & Refunds"**, matching the hub
  row, not "Cancellation & Refund Policy" from your heading — you asked for
  the page header to be the button's name, and both come from one string so
  they cannot disagree.
- Everything else is verbatim, placeholders included.

Known placeholders / not wired up:
- **[Square-bracket placeholders] are live on four pages** — support email,
  phone/WhatsApp, business name and address, response times, and the accepted
  payment-methods list. `contact_complaints` says so in its own text. These
  are visible to users as-is.
- **Account & Data Deletion describes a route that does not exist.** The
  document promises "Menu → Delete Account"; there is no such menu item and no
  deletion backend. Both app stores require a working in-app deletion route,
  so this is a release blocker — and a page promising it while it doesn't work
  is worse than no page. It needs a **Cloud Function**, not a client-side
  delete (cascades through `users`, `bookings`, `favorites`, Storage avatars).
- **Contact & Complaints promises "Menu → Support / Help"**, which is also not
  built — the drawer's Help/Support row is still inert.
- **Cancellation & Refunds references "My Trips"** and a "Cancel booking"
  action; the Trips tab is Phase 8 and says "coming soon".
- **All seven have `legalReviewed: false`**, so every page shows the yellow
  warning banner. The Kurdish and Arabic wording is translation, not legal
  drafting.
- **Nothing is seeded** — still no Firebase project. Preview mode serves the
  bundled asset.
- **`node` is not installed on this machine**, so the seed script has not been
  run or syntax-checked.
- **Not run on a device** — same Windows Developer Mode blocker.

Firestore collections touched: `legal_documents` (read only). The existing
public-read / admin-only-write rule matches on `{docId}` and already covers
all seven ids, so no rule change was needed and none was made. No index
either — documents are fetched by known id and `list` stays denied.

Example data seeded: none yet. `tool/seed_legal_documents.js` seeds all seven.

### Gap review against Agoda / Booking.com — the six new documents
Each is a reasonable short-form policy; these are the gaps that matter most,
beyond the Privacy Policy ones already logged in the previous entry:

1. **No governing-law or dispute-resolution clause** in the Terms. Both of
   theirs name a jurisdiction and a dispute process; ours mentions Iraqi and
   Kurdistan Region consumer law only inside the liability disclaimer.
2. **No account-suspension or termination clause** — what happens if a user
   breaches the Terms. Standard in both.
3. **Cancellation & Refunds gives no worked example.** Both show concrete
   free-cancellation windows and fee tables; "the provider decides" is thinner
   than a user expects at the point of paying.
4. **Payment Policy doesn't name the payment processor**, which the Privacy
   Policy needs to match for the store privacy forms.
5. **No currency-conversion disclosure** — who sets the rate and who bears the
   spread when the display currency differs from the charge currency. Both of
   theirs are explicit, and this app has a live USD/IQD currency switch.
6. **Liability has no force-majeure clause** (weather, closures, unrest),
   which matters for a mountain-travel product.
7. **Contact & Complaints has no escalation path or deadline** beyond "[X]
   business days" — no ombudsman, regulator, or second-tier contact.
8. **Terms say "at least 18 years old, or acting with a guardian"** while the
   Privacy Policy says the app is "not intended for users under 18 without the
   involvement of a parent or guardian". Close, but not identical wording for
   the same rule — worth aligning before legal review.

Nothing was added to the pages; you supplied exact text.

## 2026-08-10 — Phase 8: Help & Support screen
Status: **AWAITING APPROVAL** — not yet approved.

What was built: The Help & Support hub from the `Help & Support` reference,
opened by the side drawer's **Help/Support** row (previously inert). The
shared glass back button and the page title on one line, then ten liquid-glass
rows — a stroke-only circled icon, a title, a truncated question preview, and a
downward chevron. Light **and** dark, in English, Kurdish and Arabic with full
RTL. 14 new tests on this screen, 2 on the drawer; 246 pass overall, analyzer
clean.

Decisions taken (all three confirmed before building):
- **Every row answers "Coming soon."** The Q&A content comes later.
- **The content will live in Firestore**, in a `help_topics` collection —
  support answers change far more often than legal text, and a wrong answer
  should not wait for an App Store release. Shape recorded in `DATA_MODEL.md`;
  nothing is built against it yet, because there is nothing to read.
- **The tenth row, "Still need help? Contact us", is also "Coming soon"**
  rather than opening the Contact & Complaints policy.

Also changed:
- **`GlassListRow`** (`lib/widgets/glass_list_row.dart`) was extracted from
  the Policy hub and is now used by both screens. `DESIGN_SYSTEM.md` already
  declared this the approved list-row pattern and said to reuse it rather than
  invent a second row style — extracting it is how that actually happens.
  Its only variable is the trailing control (`chevron` / `expand` / `none`).
  The Policy hub renders identically to before; its tests still pass unchanged.
- `HelpTopic` (`lib/models/help_topic.dart`) fixes the ten `help_topics`
  document ids in code, the same arrangement `PolicyTopic` uses.

Judgment calls worth flagging:
- **The rows do not visually expand yet.** The chevron points down, as drawn,
  but tapping shows "Coming soon" rather than animating open — there is
  nothing to reveal. The expansion arrives with the content.
- **The reference's rows are slightly more compact than the Policy hub's**
  (~80% the height). I kept the approved shared row metrics instead, so the
  two drawer destinations match each other. Easy to tighten if you prefer the
  screenshot exactly — it is one constant in `GlassListRow`.
- **The drawer still says "Help/Support" while the page says "Help &
  Support"**, because the drawer label is existing approved copy in all three
  languages. Say the word and I will align them.
- The down chevron is **not** mirrored in RTL, unlike the Policy hub's forward
  chevron. Down is down in every reading direction.

Known placeholders / not wired up:
- **All ten rows are inert**, as specified.
- **Nothing is seeded and no service exists** — `help_topics` has no content,
  so no read, no rules, no seed script were written. Building a reader for an
  empty collection would be building ahead.
- **The row titles and preview lines are app strings**, not Firestore. If the
  admin panel should rename a topic without a release they have to move — a
  decision to take when the content arrives, recorded in `DATA_MODEL.md`.
- **Not run on a device** — same Windows Developer Mode blocker. Verification
  is the test suite only.

Firestore collections touched: **none.** `help_topics` is documented and
approved but unbuilt; no rules or indexes were added, because nothing reads it.

Example data seeded: none — this screen reads nothing.

### Gap review against Agoda / Booking.com — help centres
Their help centres do several things ours will need once it has content:

1. **A search box at the top.** Both lead with search rather than categories —
   it is how most users actually find an answer, and with ten categories of
   Q&A the list alone gets slow to scan. The single biggest gap.
2. **Booking-aware help.** Both show *your* bookings first and attach the help
   flow to one ("cancel this booking", "message this property"). Ours is a
   static category list; the connection to `bookings` is what makes a help
   centre useful rather than a FAQ page.
3. **A real contact channel with hours and expected response time**, plus live
   chat. Ours is a tenth row saying "coming soon", and the underlying contact
   details are still [placeholders] in `legal_documents/contact_complaints`.
4. **"Was this helpful?" feedback** on each answer, which is how you find out
   which answers are wrong.
5. **Deep links from the failure itself** — a failed payment offers help at
   the point it fails, rather than expecting the user to find Help & Support
   in a drawer.
6. **Safety & emergency info surfaced by location.** Ours is a category; for a
   mountain-travel product the emergency numbers arguably belong somewhere
   reachable offline and without navigating a menu.

None of this was built — the ask was the screen from the reference. Recorded
so it is on the table when the content arrives.

## 2026-08-11 — Help & Support accordion content

The first nine Help & Support rows now expand downward in place with the
supplied 43 English question/answer pairs. The selected card keeps its header
anchored, grows only from the bottom, and pushes only later rows down. Tapping
it again collapses it; opening another topic switches the expanded selection.
The tenth Contact row expands to the localized “Coming soon” message.

The body copy is bundled as the English offline fallback in
`lib/models/help_faq.dart`. Kurdish and Arabic row titles/previews remain fully
localized and RTL; their accordion bodies intentionally use the documented
English fallback until translated Q&A content is provided. No Firestore read,
rule, index, or seed change is required for this bundled phase. The approved
`help_topics` schema remains the future live/admin-managed source.

## 2026-08-11 — Phase 8: Settings hub

Status: **AWAITING APPROVAL** — not yet approved.

What was built: the drawer's Settings row now opens the supplied Settings
layout. It includes the back/header area, a live profile card, Account,
Preferences, and Security & legal glass groups, and the centered Log Out/Log In
button. The photo background uses the approved light/dark gradient. (It
originally carried a sigma-24 blur in both modes; that was removed by approved
decision when My Bookings was built — light mode is now sharp and dark mode
keeps its mandatory sigma-8.) All visible chrome is localized in English,
Kurdish, and Arabic with RTL.

Functional now:
- Notification opt-in requests the platform permission when enabled, handles a
  denial without leaving the switch on, and persists locally.
- The shared light/dark theme toggle now persists and restores before the app
  starts.
- Log Out signs out and clears the navigation stack; a guest is sent to Login.

Explicit placeholders: profile/account editing, language, currency, units,
Security & privacy, and Delete account show "Coming soon." The already-working
drawer Currency editor remains unchanged. Delete account still requires the
documented server-side cascade Cloud Function and remains a release blocker.

Data impact: none in Firestore. Device-only preferences use
`SharedPreferences`; no collection, security-rule, index, or migration change
is needed. The screen reads the existing user profile fields.

Verification: analyzer reports no issues and the full suite passes 274 tests,
including drawer navigation, three languages, notification permission/
persistence, theme, logout, back navigation, narrow screens, and 2x system
text.

---

## My Bookings — built, awaiting approval (2026-08-13)

Built from the `my bookings.jpg` reference plus the supplied functional
description. Light and dark, English/Kurdish/Arabic with RTL. Opened from the
Home drawer's **My Bookings** row, which is no longer inert.

Layout: the shared physical-left back button, a 32px title, then two pinned
filter rows and a scrolling list of ticket cards.

Four decisions were taken to the user before any code was written, and all four
are reflected here:

1. **Background** — sharp in light mode (the reference shows no blur), keeping
   dark mode's mandatory sigma-8.
2. **The sigma-24 blur was removed from Settings, Policy, the seven policy
   documents, Billing/Payment and New Card** as well. Those five screens now
   match: sharp light, sigma-8 dark. `DESIGN_SYSTEM.md` records the change; a
   new test pins dark mode's blur so it cannot be dropped by accident.
3. **Booking data is denormalized** onto each document rather than joined from
   the catalog, so a renamed or delisted hotel cannot rewrite a user's history.
4. **An Upcoming/Past/Cancelled axis was added** above the reference's type
   chips, matching Booking.com and Agoda.

Four further design-token approvals were taken before building: the design file
wins over the screenshot on chip colour; new `success`/`info` status-pill tokens
were added to both design files; the ticket card is a new opaque surface; and
the flight barcode is real, via `barcode_widget`.

Functional now:
- Reads `bookings` through one owner-scoped query; both filter axes apply in
  Dart, so switching a chip costs nothing.
- Loading, error (with Try again), first-run empty, per-segment empty, and
  filtered-empty states are all distinct and handled.
- Pull-to-refresh, including from the empty states.
- A guest is asked to sign in and never triggers a read — asserted by test.
- Four preview fixtures render every card layout before Firebase exists.

Explicit placeholders: every card's primary action (Check In / Open Ticket /
Pickup Info / Tour Details) shows "Coming soon", because the detail screens
behind them are Phases 4-7. Price is stored but not yet drawn on the card.
Cancel/Modify, voucher download, share and add-to-calendar are identified as
gaps against Booking.com and Agoda but are not built.

Data impact: `bookings` was substantially expanded in `DATA_MODEL.md` -
`bookingReference`, `startAt`/`endAt`, `cancellable`, a `completed` status and a
denormalized `display` map with per-type blocks. `firestore.rules` gained the
collection with **owner-read and every client write denied**; a composite
`userId + startAt` index was declared. `tool/seed_bookings.js` writes one
document per type and refuses to run without a real Auth uid.

Not yet done, and blocking approval: there is no live Firebase project, so the
seeded documents have not been confirmed rendering on the real screen and the
rules have not been denial-tested. Card photographs have not been supplied.
Nothing in the app can create a booking until Phases 4-7 exist.

Verification: analyzer reports no issues; 338 of 341 tests pass. The three
failures are in the in-flight saved-cards billing work (`First Iraqi Bank`
fixture, duplicate `Cardholder Name` in the card preview) and are unrelated to
this screen.

---

## Preview sign-in account added (2026-08-13)

A real Firebase Auth user could not be created: there is no Firebase project,
and the Login button had never been wired to sign-in at all — `_onLogin` only
showed a "backend not connected" snackbar.

So the requested account exists as a **debug-only preview credential**:
`kurdistan` / `Asd!@3`, in `AuthService.previewUsername` / `previewPassword`.

Safety, since this is a hard-coded credential:
- Gated on `kDebugMode && !FirebaseBootstrap.isReady` — two independent
  conditions, so it vanishes on a release build *or* once Firebase is wired up.
- Creates no session and calls no Firebase API; it only flips the UI into its
  signed-in state.
- `checkPreviewCredentials` throws if called outside preview mode.
- A yellow `PreviewModeBanner` on the Login card says it is not real sign-in.
- Ten tests in `test/screens/login_preview_signin_test.dart` pin all of it,
  including the end-to-end path into My Bookings as a signed-in user.

The Login email field accepts the bare username in preview mode only; the email
format check is otherwise unchanged. Note `Asd!@3` is 6 characters and would be
rejected by the app's own 8-character registration policy — acceptable only
because it never reaches Firebase Auth. Documented in `SECURITY.md` 1b, which
also says to delete the account when real sign-in is built.

Also fixed, to get the project compiling again (these were blocking every test
and were not from the My Bookings work):
- `app_localizations.dart` — `verificationCode` and `sendCode` were declared
  twice as getters and duplicated as keys in all three language maps.
- `user_profile_service.dart` — `fetchProfile` lost its null promotion on
  `user` when reassigning after `reload()`, so every field access failed to
  compile. Split into a separate non-nullable local.

Verification: analyzer reports no errors; 348 tests pass. Six failures remain,
all in the concurrently-developing account-editing and saved-cards billing work
(`account_edit_screens_test.dart` and `account_settings_service_test.dart` are
empty placeholder files with no `main()`; the rest are its fixtures).

---

## Nature place detail — reference-match pass (2026-08-15)

Status: **AWAITING APPROVAL** — still not approved.

The screen already existed (entry of 2026-08-13). This pass audited it against
the `Explore nature +.png` reference and the supplied functional description
and closed the gaps found. **No schema change, no new collection, no rule or
index change, and nothing new seeded** — everything below is presentation and
navigation on data the catalog already carries.

What changed:
- **`Name:` and `Distance:` labels.** The reference writes both as labelled
  sentences; the card drew a bare name and an "About this place" accent line
  that is not in the reference. Both are now one wrapping `Text.rich`
  paragraph, so the label cannot orphan onto its own line. New localized keys
  `placeNameLabel` / `placeDistanceLabel` in English, Kurdish and Arabic.
- **The weather card is headed with the place's name**, as the reference draws
  it, instead of the generic word "Weather". The `weather` string is retained
  for reuse elsewhere.
- **The map preview actually opens a map.** It carried `Semantics(button:
  true)` with no tap handler — announced to a screen reader as actionable and
  inert to everyone. The whole preview and a new round "take me there" control
  (the one the reference draws on the map, bottom-start) now push the shared
  `MapScreen`.
- **`MapScreen` gained two optional parameters**, `target` and `title`, rather
  than a second map screen being written. With a target it opens on that place,
  pins it, and skips the recentre-on-device step that would otherwise pull the
  camera off the place a second after opening. The Map tab passes neither and
  is unchanged.
- **The map pill now names the place above its location line**, matching the
  reference's two-line pill; it previously showed only "Rawanduz, Kurdistan".
- **The "Suggested Accommodations Nearby" icon is a stroke-only circled icon**,
  the app's approved section/row icon treatment and what the reference draws.
- The stale comment in `explore_nature_screen.dart` claiming the detail screen
  was unbuilt and tapping a card says "coming soon" was corrected — it has
  navigated to the detail screen since 2026-08-13.

Deliberately **not** changed, and why:
- **The cover photo stays on the leading edge of the About card.** The written
  spec says "at the right"; the reference screenshot clearly puts it on the
  left. `DESIGN_SYSTEM.md`'s rule is that the page matches the screenshot, and
  the layout is directional — it already mirrors to the right in Kurdish and
  Arabic. Say the word if the written spec was the intent in English too.

Verification: analyzer clean; the detail screen's suite is 6 tests, all
passing, and the Explore Nature/Customize suites still pass unchanged. Two new
tests cover the distance label (hidden without a fix, labelled with one) and
the map preview handing `MapScreen` the right coordinates and title. Nine
failures remain across the whole suite — four are empty placeholder test files
with no `main()` and five are the pre-existing background-blur, My Bookings and
New Card failures; none touch this screen.

Still not done, unchanged from the previous entry: no live Firebase project, so
nothing is seeded or confirmed rendering on a device; the review-writing screen
this card is wired to does not exist yet, so tapping it still says "Coming
soon"; place galleries and accommodation photos still need real Storage URLs.

### Gap review against Agoda / Booking.com — nature-place detail page
Checked against both products' current property/attraction detail pages. None
of this was built (the ask was the reference screen); recorded so it is on the
table:

1. **No facilities section.** `nature_spots.amenities` and `.placeTypes` are
   already in the schema and already seeded — and are used *only* for
   filtering. Both products show a facilities grid on the detail page itself.
   This is the biggest gap, and it needs **no database change at all**.
2. **No Save/favorite and no Share control on the hero.** Both have both, and
   the `favorites` collection already exists from the Home screen.
3. **No "see all photos" grid.** Both open a full gallery with a photo count;
   ours is a swipe-only carousel with dots.
4. **No review breakdown or review sorting**, and no "N reviews" beside the
   hero score — the count is only inside the reviews card.
5. **No practical-visit block**: opening hours, best season, entry fee,
   accessibility. Ours has weather and distance only.
6. **No "get directions" hand-off** to the platform maps app. The new control
   opens the in-app map, which is the right default, but neither product stops
   there.
7. **No safety/emergency information**, which matters more for a mountain
   destination than for a hotel.

---

## 2026-08-15 — Phase 3: Reviews & Ratings screen

Status: **AWAITING APPROVAL** — not yet approved.

Built from the `explore nature - comment.png` reference, opened by the nature
detail screen's review card — which previously said "Coming soon" and now
navigates. Light **and** dark, in English, Kurdish and Arabic with full RTL.
16 new tests; analyzer clean.

Layout, with the four changes you asked for against the screenshot: the hero
carries the shared glass back button and the **"Reviews & Ratings" title on the
same row**, the **top-right rating badge is gone**, and the place name sits at
the foot of the image as a header with its location as a hint line under it.
Then the Average Rating card (score, stars, real review count, and the 5★→1★
percentage bars), an "All Reviews" heading with the Most Recent sort control,
the review list, and the composer.

### Four decisions taken to you before any code was written

1. **Ratings became half-star, 0.5–5.0.** The reference's own numbers (9.2,
   7.5, 9.5) cannot be produced by any star picker, and the old schema stored
   an integer 1–5. Half stars are the closest reachable design, and they are
   what the reference *draws* (Omar J. is 3.5 stars). Individual reviews
   therefore read 9.0 / 8.0 / 7.0, never 9.2. The **average** is still a
   decimal — 8.6 is perfectly reachable, it is just a mean.
2. **The percentage bars come from a server-maintained histogram**
   (`nature_spots.ratingBreakdown`), not from the page of reviews downloaded.
3. **Helpful votes are built fully** — a `votes/{uid}` subcollection plus a
   server-owned `helpfulCount`, with a Cloud Function between them.
4. **Reviews publish immediately.** A guest gets a sign-in prompt instead of a
   composer.

### The aggregates moved to the server, and that is the important change

`reviewScore`, `ratingCount` and the new `ratingBreakdown` are no longer typed
by anyone. Two new triggers in `functions/index.js` derive them:

- **`syncNatureReviewAggregates`** recomputes all three whenever a review is
  written.
- **`syncReviewHelpfulCount`** recomputes a review's heart count from its
  `votes` subcollection.

Both **recompute rather than increment**, which was a deliberate reversal
mid-build. Cloud Functions triggers are *at-least-once* — a duplicate delivery
is a documented guarantee, not a rare fault — so `increment(1)` would corrupt a
count permanently with nothing in the data to show it happened. A recompute
gives the same answer however many times it runs, and repairs earlier drift. It
also made seeding work: the seed script writes reviews and no aggregates, and
whatever order the writes land in, the last trigger leaves the right totals.
The cost (one read per existing review, per review write) and the point at
which it stops being right are recorded in `DATA_MODEL.md`.

**The admin panel must show these three read-only.** A hand-typed average is
overwritten by the next review posted.

### Security

`firestore.rules` gained the votes subcollection and a substantially stricter
review rule. The design point is that **the review document id is the author's
uid**: without it a client could post the same opinion a hundred times and drag
a place's average wherever it liked, and no rule could tell that apart from a
hundred honest visitors. Rate limiting would not have fixed this — a patient
attacker just waits.

Also: `rating` is validated on the half-step grid (3.7 is inside the range but
is a value no UI here can produce); `helpfulCount` is on no client allow-list;
updates compare only changed keys, so the server-owned field can sit on the
document without becoming writable; `createdAt` is pinned on update, so an
author cannot re-date an old review to the top of "Most recent"; and `list` on
`votes` is denied outright, so "helpful" never becomes a public record of who
read what. `SECURITY.md` 1c has the seven denial tests to run.

### Also changed

- **`RecessedLiquidGlassField` gained `minLines` / `maxLines` / `maxLength` /
  `onChanged` / `textCapitalization`.** The composer needs a multi-line box,
  and `DESIGN_SYSTEM.md` 22 prohibits a second input family — so the shared
  field was extended rather than a new one written. Every parameter defaults to
  the previous behaviour, so no existing screen changed.
- **`DESIGN_SYSTEM.md` gained 8.5** (multi-line inputs), **13.1** (where half
  stars are allowed), **13.2** (the star input's accessibility exception) and
  **13.3** (distribution bars).
- **Four composite indexes**, one per sort order. Sorting is done in the
  **query**, not in Dart, because the list is paginated — sorting a downloaded
  page would rank the newest ten reviews and present them as the highest rated
  of 128.
- The detail screen's `_Stars` takes a double now. Its **badges keep whole
  stars** deliberately: they were approved that way on the list card and the
  hero, and switching them would restyle two built screens as a side effect.

### Judgment calls worth flagging

- **The star input breaks the 48dp rule, knowingly.** Half a star cannot be
  48dp wide without the row leaving the screen. The row is 56dp tall, accepts a
  horizontal drag, and exposes slider semantics with increase/decrease actions,
  so assistive technology can set it without touching a 20dp target. Documented
  as an explicit exception in `DESIGN_SYSTEM.md` 13.2, scoped to this control.
- **The fabricated review counts were removed from the seed and the bundled
  data.** Rawanduz claimed 214 reviews with two documents behind it, and the
  other two places claimed 1,032 and 876 with none — you asked for the review
  number to be real, and those were the numbers that were not. Seven reviews
  are now seeded (three for Rawanduz from the reference, two each elsewhere)
  and every score is derived from them: Rawanduz **8.0**, Sami **8.5**, Erbil
  **9.0**. One existing test that asserted 8.2 was updated.
- **Consequence of the above: the bars are sparse.** Three reviews produce two
  bars, not the five-bar spread the screenshot shows. That is what real data
  looks like at this volume. Say the word if you would rather I seed a wider
  spread of reviews for the demo.
- **Reviews paginate at 10 behind a "Show more reviews" button**, not infinite
  scroll. The reference shows no pagination because it shows five reviews.

### Known placeholders / not wired up

- **Nothing is seeded, because there is still no Firebase project**, and
  **`node` is still not installed on this machine**, so the seed script has not
  been run or syntax-checked.
- **The two Cloud Functions have never run.** Every number on the top card is
  bundled preview data computed in Dart to mirror what they would write. Until
  they are deployed, a seeded place shows **no score at all** — that is the
  expected failure, not a bug in the screen.
- **The rules have not been denial-tested** — `SECURITY.md` 1c lists the seven
  checks. Release blocker for this screen.
- **No moderation queue.** Reviews publish instantly, as agreed; `status` and
  the existing `delete` rule are there so one can be added without a migration.
- **Kurdish and Arabic strings are translation**, not copy reviewed by a native
  speaker — the same caveat as every other screen.
- **Not run on a device** — the same Windows Developer Mode blocker as every
  screen since the Home screen. Verification is the test suite only.
- Place photographs still need real Storage URLs.

### Verification

Analyzer reports no issues. The new suite is 16 tests, all passing: the
header/hero layout, the removed badge, the server-owned average card, the
review rows, sort re-querying (rather than reordering locally), optimistic
hearts, both composer validation failures, a successful post, half-star
landing, the guest gate, load failure and retry, the empty state, pagination,
Kurdish/Arabic RTL, the background treatment in both themes, and the 48dp
targets. The Explore Nature and detail suites still pass (43 tests).

Nineteen failures remain across the whole suite and **none are from this
work**: nine are empty placeholder test files with no `main()`, and ten are the
pre-existing background-blur, My Bookings, New Card, billing and
account-editing failures already recorded above.

### Gap review against Agoda / Booking.com — review pages

Checked against both products' current review surfaces. None of this was built
— the ask was the reference screen; recorded so it is on the table:

1. **No "verified stay" marker.** Both only accept a review from someone who
   actually booked, and say so on the review. Ours accepts anyone signed in,
   which is arguably right for a public nature spot (you do not book a
   waterfall) — but it is the single biggest quality difference between our
   reviews and theirs, and it deserves a deliberate decision rather than a
   default.
2. **No sub-scores.** Both break the average into categories (cleanliness,
   location, value). The nature equivalents would be access, facilities,
   crowding.
3. **No filtering by rating or by language.** Tapping a bar to read only the
   1-star reviews is the most common interaction on both.
4. **No photos in reviews.** Both let a reviewer attach images, and for a
   scenic destination that is arguably worth more than the text.
5. **No owner/admin response** under a review.
6. **No report/flag control**, which is the other half of publishing
   instantly — and which app-store review does ask about for user-generated
   content.
7. **No translation of reviews.** Ours are stored in whatever language they
   were typed in, with no locale field and no "translate" affordance; both of
   theirs translate on demand.
8. **Review text is not length-guided.** Both nudge toward a useful length; we
   accept three characters.


## 2026-08-17 — Phase 6: Explore Tours screen

Built from the supplied reference and its functional description, opened by the
Home screen's "Explore Tours" card (previously "coming soon").

**Built out of order, deliberately.** Phases 4 (Where to Stay) and 5 (Car
Rental) are still NOT STARTED. This screen was requested directly, with its
reference image and a full description of every element, so it was built;
`ROADMAP.md` now records the skip rather than leaving it to be noticed later.

### What was built

- **`lib/screens/explore_tours_screen.dart`** — the screen.
  - Back button and page title on **one row** (the reference draws them that
    way; Explore Nature stacks them, and neither was changed to match the
    other — each follows its own approved reference).
  - A carousel of `highlighted` tours: photo, operator tag in the top corner,
    name, location line, clipped description, and the page dots pinned to the
    opposite corner **outside** the `PageView` so they stay still as slides
    move.
  - The two search controls and the Apply button. Both fields are the shared
    `AppRecessedGlassField` — `DESIGN_SYSTEM.md` 8 requires one input family
    app-wide and 22 lists "different input families on different screens" as
    prohibited.
  - "Trending Tours", then a card per tour: photo on the **leading** edge (so
    the card mirrors in Kurdish and Arabic rather than reading backwards),
    name, operator tag, trip length, four stroke-only circled feature icons
    (`DESIGN_SYSTEM.md` 11.1: 44dp circle, 22dp icon, 1.5px stroke, no fill),
    location line, live distance, clipped description, date range and the
    price-per-person box.
- **`lib/models/tour.dart`** — `Tour` + `TourFeature`, plain Dart (no
  `cloud_firestore` import), so it is testable without Firebase.
- **`lib/services/tours_service.dart`** — two queries plus bundled preview
  data, mirroring `NatureSpotsService` exactly.
- **`tool/seed_explore_tours.js`**, `firestore.rules`, two new indexes, and
  the localization for all three languages.

### The `tours` schema had to be revised before anything could be drawn

The eight-field draft in `DATA_MODEL.md` could not render a single card. Six
changes, all recorded there:

1. `name` / `description` / `locationLabel` became **locale maps**. They were
   plain strings in a trilingual app.
2. `duration: "3 days travel"` became **`durationDays: 3`**. A stored English
   sentence prints English on a Kurdish card; the app builds the line from the
   number.
3. **`startAt` / `endAt` added.** The card draws a date range and the screen
   filters by date; neither was expressible before.
4. **`currency` added**, matching `AppCurrency` and `bookings.currency`.
5. **`active`, `highlighted` + `highlightOrder`, `trending` + `trendingOrder`
   added** — the same admin controls `nature_spots` and `featured` already have.
6. `features` was pinned to snake_case ids matching a Dart enum, so an unknown
   tag is dropped rather than drawn as a nameless circle.

**No `reviewScore` on `tours`.** The reference draws no rating on a tour card,
and the three aggregates on `nature_spots` are server-owned by a Cloud Function
trigger — adding hand-typed ones here would contradict that the moment tour
reviews exist.

### Security

- `tours` is **public read, admin-only write**, like `nature_spots` and
  `featured`. Here that is a **payment-adjacent** control, not only an
  editorial one: `pricePerPerson` and `currency` are what a future checkout
  charges against, so a client that could write this collection could set its
  own price to zero before booking (`SECURITY.md` 5).
- No new client write path exists on this screen at all — it only reads.
- The rules have **not been denial-tested**; that needs a live project.

### Judgment calls worth flagging

- **Apply actually applies.** Typing in the search box changes nothing until
  the button is pressed. The reference has an explicit Apply button, so making
  the list filter live would have made that button decorative.
- **The search is done in Dart, not in a query, and cannot be otherwise.**
  Firestore has no substring match, and `name` is a locale map — a server-side
  search would have to pick one of three languages and fail the other two.
  Documented in `DATA_MODEL.md` with the point at which it stops being right
  (200 documents).
- **The date field is read-only and opens a picker.** A typed date needs a
  parser, and a parser covering three languages is a source of wrong dates.
- **The Apply button is 200dp wide, not full width.** The token geometry
  (56dp, radius 14, solid action fill) is unchanged; `DESIGN_SYSTEM.md` 9.1
  says full width "where the page layout calls for" it, and this one does not.
- **A list card draws at most four feature icons.** The reference shows four,
  and a fifth does not fit beside a 140dp thumbnail at a readable label size.
  Extra tags stay in Firestore for the detail screen.
- **The cards are not tappable.** There is no tour detail screen yet, and a
  card that opens nothing is worse than a card that says nothing. Wiring it is
  one line when that screen exists.
- **Abbreviated months are English-only.** Kurdish and Arabic have no
  conventional three-letter month abbreviation, so those two spell the month
  out; the range collapses to "Aug 14 - 16" / "14 - 16 ئاب" when both ends
  share a month, which is what keeps the column narrow.
- **Nothing converts currency.** The price shows in the currency the operator
  quoted. Showing the user's preferred currency needs a live rate, and a stale
  rate on a price is worse than an honest foreign one.
- **`formatTourDistance` is a copy of Explore Nature's `formatSpotDistance`**,
  not an import — that one is `@visibleForTesting`. If a third screen needs it,
  move both into a shared helper then.

### Known placeholders / not wired up

- **Nothing is seeded** — still no Firebase project, and `node` is still not
  installed on this machine, so `tool/seed_explore_tours.js` has not been run
  or syntax-checked.
- **No tour photographs.** Every seeded document has an empty `imageUrls`, so
  cards fall back to a brand-coloured panel with a tour icon.
- **The rules have not been denial-tested.** Release blocker for this screen.
- **Tapping a card does nothing** — see above.
- **Kurdish and Arabic strings are translation**, not copy reviewed by a native
  speaker — the same caveat as every other screen.
- **Not run on a device** — the same Windows Developer Mode blocker as every
  screen since the Home screen. Verification is the test suite only.

### Verification

`flutter analyze` reports no issues across the whole project. The new suite is
**28 tests, all passing**: the model's locale fallback, `fromMap` parsing and
rejection, unknown-feature dropping, multilingual search matching, the
whole-run date match, trending ordering, the three date-range shapes in all
three languages, the plural duration line, a check that every new string exists
in all three languages *and differs from English*, distance formatting, the
background treatment, the back-button/title row geometry, the carousel and card
content, the four-icon cap, distance shown and hidden, Apply-gated search
costing no extra read, the empty result and its clear action, load failure and
retry, the empty catalog, the empty carousel, LTR dots under RTL, Kurdish and
Arabic rendering, dark mode, and the feature-circle rule.

The Explore Nature, nature detail and Reviews suites still pass (59 tests), so
nothing regressed. The pre-existing failures recorded above (empty placeholder
test files, background-blur, My Bookings, New Card, billing, account-editing)
are unchanged and unrelated.

### Gap review against Agoda / Booking.com — tour / "Things to do" listings

Checked against both products' current attraction and activity surfaces. **None
of this was built** — the ask was the reference screen; recorded so it is on
the table for the tour detail screen and for `DATA_MODEL.md`:

1. **No rating anywhere on a tour.** Both lead with a score and a review count
   on every activity card, and it is the single strongest signal a traveller
   uses to choose between two similar tours. Ours has neither — deliberately,
   because the reference draws neither and because the aggregates must be
   server-derived. This is the biggest single gap, and it needs the
   `nature_spots` review arrangement copied wholesale onto `tours`.
2. **No availability or "N spots left".** Both show whether a departure can
   still be booked. Ours lists a tour whether or not it is full, which will
   become a support problem the day booking exists. Needs a `capacity` /
   `bookedCount` pair, and both must be **server-owned**.
3. **No cancellation policy on the card.** "Free cancellation until 24h
   before" is on virtually every Booking.com and Agoda activity card, and it
   converts. It is also a `legal_documents` consistency risk if typed per tour
   rather than referenced.
4. **No sort control.** Ours orders by departure date with the admin's
   trending picks first. Both offer price / rating / popularity / distance.
5. **No filters beyond text and one date.** Both filter by price range,
   duration, language of the guide, and category. Our `features` array is
   already the right shape for a chip row like Explore Nature's Customize
   screen — the data is there, the UI is not.
6. **No date *range*, only a single day.** Both take check-in/check-out or a
   flexible range. Our picker answers "what runs on this day?", which is the
   narrower question.
7. **No "from" price or price-per-group.** Ours is strictly per person; both
   handle group pricing and show a "from" price where tiers exist.
8. **No group-size / traveller-count selector.** Both take it before showing
   prices, because the price depends on it.
9. **No currency conversion.** Both show the traveller's own currency with a
   disclosed rate. Ours shows the operator's currency, which is honest but not
   equivalent — and `users.preferredCurrency` already exists, so the gap is a
   rate source, not a schema change.
10. **No map view of results**, and no "distance from city centre" framing —
    ours measures from the device, which is better when location is granted and
    absent when it is not. Both fall back to a landmark.
11. **No saved/favourite control on a tour card.** `favorites` already supports
    `itemType: "tour"`; the heart simply is not drawn here.
12. **No language-of-tour field.** Both list which languages a guide speaks,
    which matters more here than in most categories.

## 2026-08-17 — Explore Tours: closing the Agoda / Booking.com gaps

Ten of the twelve items from the gap review above were built. The two left
alone are **#7 group/"from" pricing** and **#10 a map view of results** — both
were outside the request, and both are recorded below as still open.

The rating placement is as asked: **leading edge on the carousel slide,
trailing edge on a list card**.

### 1. Ratings and review counts — the biggest gap, and the one with a backend

Not a field anyone types. `tours` gained `reviewScore`, `ratingCount` and
`ratingBreakdown`, all three **server-owned**, plus a `tours/{id}/reviews`
subcollection and a `syncTourReviewAggregates` Cloud Function that recomputes
them on every review write.

The whole `nature_spots` arrangement was **copied deliberately rather than
reinvented** — same half-star grid, same uid-as-document-id rule (which is what
makes "one review per person per tour" enforceable), same recompute-not-
increment reasoning (triggers are at-least-once, so an increment applied twice
corrupts a count permanently while a recompute repairs drift). Two catalogs
with different guarantees about who may rate what would be the actual bug.

Deliberately **not** added: `helpfulCount` and the `votes` subcollection.
Nothing in the app can cast a helpful vote on a tour review, and a write path
with no UI behind it is surface area for nothing.

**No new index was needed** — the `reviews` composite indexes are
`COLLECTION_GROUP`-scoped and keyed on the collection *id*, so they already
serve `tours/*/reviews`.

Display: score badge + five stars on the carousel (leading edge), score badge +
"128 reviews" on a card (trailing edge). The card omits the star row because
its column is ~230dp wide and `DESIGN_SYSTEM.md` 13 approves either form. An
unrated tour says "No reviews yet" rather than drawing a 0.0.

### 2. Availability

`capacity` + `bookedCount`, with `bookedCount` **server-owned**. The card says
"Only 3 spots left" — but only when the number is genuinely small (≤ 5),
because a "48 spots left" badge is noise and printing it everywhere teaches
people to ignore it.

**A departure that cannot seat the whole party is filtered out**, which is what
both reference products do — so there is deliberately **no "Sold out" pill**: a
badge that can never render is dead UI.

The important half of this is in `functions/index.js` and `DATA_MODEL.md`, not
in the screen: when checkout exists it must re-check `capacity - bookedCount`
and bump it **inside one transaction**. A client-side availability check is a
suggestion, not a check, and a `bookings` trigger fires after the money is
taken.

### 3. Cancellation policy

A **tier** (`free_24h` / `free_48h` / `free_7d` / `non_refundable`), not free
text. The wording lives in `legal_documents/cancellation_refunds`; a hundred
operator-typed paragraphs would drift from the policy the app actually
enforces, which is the failure `DATA_MODEL.md` already warns about for
`help_topics`.

### 4–6. Sort, refinement chips, date ranges

- **Sort**: soonest (default) / price ↑ / price ↓ / top rated / nearest.
- **Refine**: eight feature chips and five guide-language chips, OR within a
  group and AND across groups — the semantics `NatureFilters` established.
- **Dates**: the single date field became a **range** picker, matching by
  **overlap rather than containment** — someone searching 14–20 August wants
  the three-day trip starting on the 19th.

All of it runs over the one catalog read already in memory, so the collection
still needs exactly two indexes.

### 7. Traveller count

A stepper (1–20) rather than a text field: the value is a small integer with
hard bounds, and a keyboard invites "0" and "300". It does two things — prices
the trip, and hides departures that cannot seat the party. Showing someone a
tour with two places left when they have said there are four of them is how a
booking failure gets discovered at the payment screen.

### 8. Currency conversion

New `currency_rates/latest` document, `CurrencyRatesService`, and a
`TourPricing` value object. Reads `users.preferredCurrency`, which already
existed.

The design point is what it refuses to do: `CurrencyRates.convert` returns
**null** for any currency missing from the table, and the UI then falls back to
the operator's own price. An unconverted true price beats a converted invented
one. Converted figures are prefixed `≈`, and a one-line disclosure sits above
the list — drawn **only when something on screen was actually converted**,
because a standing notice nobody needs is what makes real disclosures
invisible.

**These rates are indicative, not transactional**, and that is written into the
service, the seed script, the rules comment and `DATA_MODEL.md`: a charge must
be priced in the operator's own currency and converted by the payment
processor, or the app takes on FX risk it cannot hedge.

### 9. Favourite heart

Reuses `FavoritesService` with `FeaturedType.tour`, which `favorites` already
supported — no schema change, no new rule. Guests get the same sign-in sheet
the Home screen shows; a favourite is keyed by uid, so there is no such thing
as an anonymous one.

### 10. Guide languages

`guideLanguages`, ISO 639-1 codes from a closed set (`en`, `ku`, `ar`, `tr`,
`fa`) so the chips and the card line can be localized. Free text could not be
translated or filtered.

### Firebase changes

- **`firestore.rules`** — `tours/*/reviews` (public read of published,
  author-owned write, half-step rating validation, `createdAt` pinned on
  update) and `currency_rates` (public `get`, **`list` denied** because the app
  reads one known id, admin-only write).
- **`firestore.indexes.json`** — no new index; the existing `reviews`
  collection-group entries already cover tours. The comment now says so, so the
  next person does not add a redundant one.
- **`functions/index.js`** — `syncTourReviewAggregates`, plus the recorded
  contract for the availability transaction.
- **`tool/seed_explore_tours.js`** — the new fields and five reviews (three for
  Alibag, two for Sherana, **none for Korek on purpose**, so the "No reviews
  yet" state is testable against live data).
- **`tool/seed_currency_rates.js`** — new.

### Judgment calls worth flagging

- **Apply gates the search inputs; chips and sort write through.** Text, dates
  and party size describe a *search*, so they wait for the button — otherwise
  Apply is decorative. Chips and sort refine a result set already on screen,
  which is how both reference products behave.
- **Trending pins lead the default order only.** Once the user chooses
  "cheapest", honouring an editorial pin above their instruction just looks
  like a broken sort.
- **Items missing a sort key sort last, never first.** A tour with no price is
  not the cheapest *and* not the most expensive; an unrated tour is not the
  worst rated. Tested in both directions.
- **"Nearest to me" is hidden without a GPS fix**, and falls back to "soonest"
  if it is somehow selected — presenting an arbitrary order as "nearest" is
  worse than one option fewer.
- **No "Sold out" badge**, because sold-out departures are filtered out. See #2.
- **Abbreviated months stay English-only.** Kurdish and Arabic have no
  conventional three-letter abbreviation.
- **`bookedCount` is seeded but server-owned.** The seeded values exist only so
  the availability line is reviewable.

### Known placeholders / not wired up

- **Nothing is seeded** — still no Firebase project, and `node` is still not
  installed on this machine, so neither seed script has been run or
  syntax-checked.
- **The two Cloud Functions have never run.** Until `syncTourReviewAggregates`
  is deployed, a seeded tour shows **no score at all** — the expected failure,
  not a bug in the screen.
- **Nothing refreshes `currency_rates`.** Release blocker for converted prices;
  a stale rate is the failure mode to design against, which is why the document
  carries `updatedAt` and the app prints it.
- **No tour checkout**, so the availability transaction described above exists
  only as a recorded contract.
- **The rules have not been denial-tested.** Release blocker.
- **Cards are still not tappable** — no detail screen.
- **No tour photographs.**
- **Kurdish and Arabic strings are translation**, not copy reviewed by a native
  speaker.
- **Not run on a device** — the same Windows Developer Mode blocker as every
  screen since the Home screen.

### Verification

`flutter analyze` reports no issues across the whole project. The tours suite
grew from 28 to **59 tests, all passing**, including: availability derivation
(clamped, absent, low, roomy), OR-within/AND-across filter semantics, party
size hiding a departure, missing-sort-key ordering in both price directions and
for ratings, the "nearest" fallback, trending pins leading only the default
order, date-range **overlap** at both ends, cross-rate conversion through the
base, null-on-unknown-currency, the `≈` marking, the operator-currency
fallback, money formatting and grouping, the party total appearing only above
one traveller, real singulars in all three languages, rating on the leading
edge of the carousel and the trailing edge of a card, the unrated state, the
low-availability line, the cancellation tier, the guide-language line, chips
filtering with no extra read, the sort reordering with no extra read, the guest
sign-in gate and a signed-in save, and the 48dp targets.

The Explore Nature, nature detail and Reviews suites still pass (59 tests).
**Two My Bookings tests fail, and were verified pre-existing** by stashing this
work and re-running — identical failures either way.

Four zero-byte test stubs (`test/models/tour_test.dart`,
`tour_filters_test.dart`, `test/services/tours_service_test.dart`,
`currency_rates_service_test.dart`) appeared alongside the new source files and
were deleted; empty files with no `main()` are counted as suite failures, and
these are already covered by `explore_tours_screen_test.dart`.

### Still open from the original gap review

- **#7 — group / "from" pricing.** Prices are strictly per person. Both
  products handle tiered group pricing and show a "from" price where tiers
  exist.
- **#10 — map view of results.** Ours measures distance from the device, which
  is better when location is granted and absent when it is not; both products
  fall back to a landmark ("2 km from city centre") and offer a map.

## 2026-08-17 — Firebase toolchain installed on this machine

Not a code change; recorded because **every entry above says "`node` is still
not installed on this machine"**, and that is no longer true.

| Tool | Version |
|---|---|
| Node.js | v24.19.0 (LTS "Krypton") |
| npm | 11.17.0 |
| Firebase CLI | 15.27.0 |
| FlutterFire CLI | 1.4.1 |

Installed from the **official portable zip** rather than the MSI, because this
account is not a local administrator and the MSI needs elevation (a UAC dialog
nobody could approve from a terminal). Extracted to `%LOCALAPPDATA%\Programs`
and added to the **user** `Path` — nothing machine-wide was touched, and it is
reversible by deleting the folder and the two `Path` entries.

`functions/npm install` ran cleanly (189 packages); `firebase-admin` and
`firebase-functions` both load.

### What this immediately bought us

**All seven JavaScript files now pass `node --check`** — `functions/index.js`
and every script in `tool/`. Until today none of them had ever been parsed by
anything, so "the seed script has not been run or syntax-checked" was a real
risk on six files including the two written this week. They are clean.

That is only syntax. None of them has been *run*, because there is still no
Firebase project to run them against.

### What is still blocked, and why it cannot be unblocked from here

- **`firebase login`** opens a browser and authenticates a Google account.
- **Creating the project**, choosing **Blaze** (Cloud Functions will not deploy
  on Spark), and downloading a **service-account key** are all console actions
  under a personal account.

Those are the only remaining prerequisites. Once the project exists and the CLI
is logged in, the deploy and all five seeds can run from here unattended.

> `functions/package.json` pins the **deploy** runtime to Node 20. That is
> correct and should stay — it is the Cloud Functions runtime, not the local
> one. Node 24 locally only runs the CLI and the seed scripts.
## 2026-08-17 — Phase 6: Tour detail and estimate page

Built the page opened by both a highlighted-tour slide and a tour list card,
using the supplied `Explore Tour+` mockup and the approved light/dark design
system. This remains **awaiting review/approval**.

### What was built

- The Explore Tours background asset remains the full-page photo under the
  shared sigma-2 blur and 45% theme gradient. The physical top-left back button
  sits outside the gallery.
- A larger swipeable gallery carries the operator badge and fixed page dots;
  the detail card, all known circular facility icons, live coordinate weather,
  and the tappable in-app map follow it.
- The review card reads the two newest documents from
  `tours/{tourId}/reviews`, then opens the existing full review experience
  through a tour adapter. Reviews, helpful votes and preview-mode state stay
  separate from `nature_spots`; the copy is tour-specific in English, Kurdish
  and Arabic.
- Checkout estimates one or more travellers and an optional per-person bus
  add-on. `transportAvailable` and `transportPricePerPerson` were added to the
  tour model, Firestore schema and seed fixtures. The total recalculates without
  writing any booking.
- Reserve Insight is fixed above the system safe area and intentionally
  disabled. Its payment/booking action was explicitly deferred to the next
  update, so this pass does not create a client-write path around the protected
  `bookings` collection.

### Database and security changes

- Tour reviews now have the same one-user/one-document, half-star, timestamp,
  helpful-vote and server-owned aggregate guarantees as nature reviews.
- Added `tours/{tourId}/reviews/{reviewId}/votes/{uid}` rules and
  `syncTourReviewHelpfulCount`; vote listing is denied and only the server can
  write `helpfulCount`.
- The existing collection-group review indexes already cover tour reviews, so
  no new Firestore index was needed.
- `DATA_MODEL.md`, `SECURITY.md`, `SEED_DATA.md`, `ROADMAP.md`, the preview
  fixtures and `tool/seed_explore_tours.js` were updated together.

### Current Booking.com / Agoda audit

Checked current official attraction/activity pages on both products. The page
now covers their common gallery, duration, operator, location, traveller count,
transport add-on, cancellation tier, facilities, map and rating/review signals.
The remaining gaps are deliberately recorded rather than silently added:

1. Structured **what is included / not included** lists.
2. A stop-by-stop itinerary / “what to expect”, not only one description.
3. Meeting point, pickup area/time and departure/return instructions.
4. Package/time-slot/ticket options and adult/child pricing.
5. Mobile ticket/QR confirmation after payment.
6. Restrictions, accessibility/fitness guidance and what-to-bring notes.
7. Verified-booker reviews, review photos and operator responses.
8. Actual payment, confirmation, refund and support flow — deferred with the
   Reserve Insight behavior.

Those items need product decisions and additional schema before implementation;
none was invented in this page-only pass.

### Verification and remaining blockers

- `flutter analyze`: no issues.
- 88 affected tests pass (tour list/detail/review adapter/service plus nature
  detail/reviews).
- Node.js and Firebase CLI are not installed on this machine, so the changed
  Cloud Function/seed script could not be syntax-checked or deployed.
- No live Firebase project is configured here; seed execution, rule denial
  tests, function deployment and device visual approval remain release blockers.

## 2026-08-17 — Firebase is live: `rewar-app-1c10e`

The backend exists. Every "needs a Firebase project" caveat in the entries
above is now resolved except the two recorded at the bottom of this one.

### Done

- **`flutterfire configure`** against `rewar-app-1c10e`. Generated
  `lib/firebase_options.dart`, `android/app/google-services.json`, and both
  Android and iOS apps are registered
  (`1:5280763166:android:...` / `1:5280763166:ios:...`).
- **`ios/Runner/GoogleService-Info.plist`** was **not** written by
  `flutterfire configure` on Windows. Pulled down separately with
  `firebase apps:sdkconfig ios <appId>`. Worth knowing: the plist is silently
  skipped on a non-macOS host, and nothing warns you.
- **`FirebaseBootstrap` now passes explicit options**
  (`DefaultFirebaseOptions.currentPlatform`) instead of the bare
  `initializeApp()`. The bare form reads the native platform config files, so
  it behaves differently per platform and fails at *runtime* on whichever one
  is misconfigured. Explicit options fail at *compile* time if the generated
  file is missing, which is the failure you want.
- **Firestore rules + indexes deployed.** Rules compiled clean.
- **Five collections seeded and read back**: `legal_documents` (7),
  `featured` (4), `nature_spots` (3 + 7 reviews), `tours` (3 + 5 reviews),
  `currency_rates` (1).
- **Both Explore Tours queries verified against live Firestore** once the
  composite indexes finished building (~3 minutes): the catalog query returns
  the three tours in departure order, the carousel query returns the two
  highlighted ones.

### The rules denial test finally ran — and it passes

`SECURITY.md` 1c has been an open release blocker on every screen since the
Home screen. It ran today against the **deployed** rules, as an
**unauthenticated** client over the Firestore REST API (the Admin SDK bypasses
rules, so it was deliberately not used).

**11 of 11 denials pass**, including the ones that matter most for this phase:

- writing a tour (price tampering) — denied
- overwriting a real tour's `pricePerPerson` — denied
- writing `currency_rates` (rate tampering) — denied
- forging `reviewScore` on a tour — denied
- posting a tour review as a guest — denied
- reading `users`, `bookings`, `password_reset_codes`, `email_verify_codes` — all denied
- reading an undeclared collection (catch-all) — denied

**6 of 6 public reads pass**: `tours`, `nature_spots`, `featured`,
`currency_rates/latest` by id, `legal_documents` by id — all readable by a
signed-out guest, which is what the catalog is for.

#### One result needed a second look, and the rule was right

`list` on `tours/{id}/reviews` came back **denied**, which looked like a bug in
a public-read collection. It is not.

The deployed rule is `allow get, list: if resource.data.status == 'published'`
— **stricter than the `if true` originally written here**, and better. On a
list/query Firestore only permits queries it can *prove* cannot match a
forbidden document, so an unfiltered scrape is rejected while the app's own
query is allowed. Verified both ways:

- the query the app issues (`where status == 'published'`) → **allowed, 3 docs**
- an unfiltered scrape of the same subcollection → **denied (403)**

So the `status == 'published'` filter in `ToursService.fetchTopReviews` /
`fetchReviewPage` is not decoration — it is what makes the query legal. Anyone
adding a review query must include it.

The first version of the probe reported false failures because PowerShell's
`Invoke-WebRequest` collapses a missing response to status `0`, and because a
keyless REST call is rejected before rules are evaluated at all. Rewritten with
Node's `fetch` and the app's API key. **Worth remembering: a denial test that
cannot tell "denied by rules" from "never reached the server" proves nothing.**

### A real gitignore hole, found by having a key to place

`.gitignore` had `*-service-account.json`, but Firebase names its downloads
`<project>-firebase-adminsdk-<hash>.json`, which that pattern **does not
match**. The key would have been committed on the next `git add .`. Added
`*firebase-adminsdk*.json` and `secrets/`, and verified with `git check-ignore`
before moving the file into place.

### Still blocked

- **Cloud Functions are NOT deployed — the project is on the Spark plan.**
  `firebase deploy --only functions` fails: Artifact Registry cannot be
  enabled without Blaze. Consequence, and it is visible in the data right now:
  **every seeded tour and nature spot has no `reviewScore` at all**, because
  `syncTourReviewAggregates` / `syncNatureReviewAggregates` have never run.
  The reviews are there; nothing has counted them. This is the documented
  expected state, not a bug — but it means the rating work from earlier today
  cannot be seen end to end until Blaze is enabled.
- **Firebase Storage is not set up** (`Get Started` never clicked), so
  `firebase deploy --only storage` fails and `storage.rules` is undeployed.
  Nothing needs it yet — every `imageUrls` is empty — but the photos cannot be
  uploaded until it exists.
- **No screen has been seen rendering live data on a device.** The Windows
  Developer Mode blocker is unchanged. Everything above was verified through
  the Admin SDK and the REST API, which proves the *data and the rules*, not
  the *UI*.
- **The service-account key was pasted into chat twice.** The first
  (`rewar-app-7c8ff`) is deleted and its project abandoned. The current one
  (`746a6dbdee…`) is in `secrets/`, git-ignored, **and should still be rotated**
  — an Admin SDK key bypasses every rule proven above.

---

## 2026-08-18 — Checkout step 1: Traveler Info (AWAITING APPROVAL)

Built from the "payment 1" reference. Reached from the Tour Detail screen's
"Reserve Insight" CTA, which was previously always disabled (`onReserve`
defaulted to null) and is now live.

### What was built

- `lib/screens/booking_traveler_info_screen.dart` — the page: back button,
  3-step indicator, the Traveler Information card (contact block → divider →
  travellers stepper → one card per traveller → secure note), and a
  **Continue to Payment** CTA held outside the scroll view so it does not move
  while the form scrolls.
- `lib/widgets/booking_step_indicator.dart` — the new shared step component.
- `lib/models/traveler_details.dart` — `TravelerDetails`, `BookingContact`,
  `TravelerParty`. All in memory; **nothing is written to Firestore.**
- `PrimaryButton` gained an optional `trailingIcon` (the CTA's forward arrow,
  which mirrors in RTL). Existing callers are unchanged.

### Decisions taken, with the user's answers

- **Sign-in is gated at Reserve, not at Payment.** `DATA_MODEL.md` requires an
  auth uid on `bookings` ("there is no such thing as a guest booking"), so a
  guest filling three steps would be refused by the rules at the charge. A
  signed-out tap opens `SignInRequiredSheet` instead.
- **Step 1 persists nothing.** No draft collection, no new rules, no cleanup
  job — and no named minors' birth dates stored before a purchase exists.
- **The travellers cap is the departure's remaining places** (`capacity -
  bookedCount`). A sold-out departure disables the CTA.
- **Age is enforced from `tours.minAge`** against each entered birth date.
  Absent means no restriction.
- **Fields match the reference exactly, plus a lead-traveller chip.** Special
  requests, nationality/passport were offered and declined for now.

### Documentation changed

- `DESIGN_SYSTEM F.md` — **new section 14, "Step indicator"** (approved before
  building; the design system had no stepper). Sections 14–23 renumbered to
  15–24, and the two stale references in `explore_tours_screen.dart` updated.
- `DESIGN_LIGHT F.md` / `DESIGN_DARK F.md` — new section 10 with matching
  `step-*` tokens, one-for-one in both themes as section 3 requires.
- `DATA_MODEL.md` — `tours.minAge`, and `bookingDetails.travelers[]` /
  `bookingDetails.contact` for what the checkout function will eventually write.
- `SEED_DATA.md` + `tool/seed_explore_tours.js` — `minAge: 18` on Gali Sherana.

### Not done / still a placeholder

- **`onContinue` is null in the app.** The CTA validates the whole form and
  reports what is wrong, then stops — the Payment screen does not exist yet, so
  it navigates nowhere rather than pretending to have booked something.
- **`minAge: 18` is in the seed script but has not been pushed to Firestore.**
  Re-run `node tool/seed_explore_tours.js` to verify the age gate against live
  data.
- **Not seen running on a device.** The Windows Developer Mode blocker recorded
  earlier is unchanged; this page is verified by 25 widget/unit tests and the
  analyzer, not by eye on a phone.
- No security rules changed, because the screen reads and writes nothing new —
  it reads the signed-in profile through the existing `UserProfileService`.

---

## 2026-08-19 — Checkout step 2: Payment (AWAITING APPROVAL)

Built from the "payment 2" reference. Reached from step 1's Continue to
Payment. Analyzer clean, 510 tests passing (21 new).

### The security decision this screen turns on

`SECURITY.md` 5.1/5.2 forbid custom card input fields and any code that reads,
logs, stores or caches a raw PAN, CVV or expiry. The reference draws those
fields. Asked, and the answer was **draw them inert** — the same contract
`NewCardScreen` already established:

- the three controllers live in widget `State` and are read by exactly one
  thing: a "does this look filled in?" check that gates the button
- nothing is written to Firestore, analytics, logs or preferences
- there is no callback that hands the values anywhere
- with no processor wired, Continue reports *"Card payments are not connected
  yet. Your card details were not sent or saved."*

**These fields must be replaced by the processor's Payment Sheet before a
single real charge.** The class doc-comment on `BookingPaymentScreen` says so
in the place a future editor will actually read it.

### What was built

- `lib/screens/booking_payment_screen.dart` — back button, step indicator
  (step 1 completed), Payment Details card → Booking Summary → Payment Method,
  and a **Continue to Payment** CTA outside the scroll view.
- `lib/models/saved_payment_method.dart` — `SavedPaymentMethod`, `CardIssuer`,
  `CardKind`, `PaymentRail`, and the shared fixtures. Lifted out of
  `billing_payment_screen.dart`, which now uses them, so the two screens
  cannot show different cards.
- `Tour.totalFor(travelers:, transport:)` — one formula on the model. Tour
  Detail's estimate now calls it too, so the two totals cannot drift.
- `formatMoney` promoted from `@visibleForTesting` to public for the same
  reason.

### Decisions taken, with the user's answers

- **Tour Detail feeds step 1.** `Reserve` now passes `_people` and `_transport`
  through, so the count and the bus add-on the user picked survive into the
  summary. Previously step 1 always opened at 1 traveller regardless.
- **Two rails only: Mastercard/Visa and FIB.** Zain Cash was dropped from the
  reference on request. **No schema change** — `bookings.paymentProvider`
  already has `stripe` and `fib`. `nasswallet` stays in the schema, unoffered.
- **The saved-card block hides entirely when there is no saved card**, rather
  than drawing an empty frame.

### Design-system changes — NEED SIGN-OFF

Two corrections to what was approved for step 1:

1. **Section 14 gained a "completed" state.** The original wording said a
   completed step looks identical to an upcoming one. The step-2 reference
   shows step 1 as a solid fill with a check glyph and an accent connector, so
   the rule was wrong. Now three states, with the check glyph carrying the
   distinction so it is not colour-only.
2. **The step accent is `primary-container`, not `action`.** Step 1 was built
   with the navy button colour; the references draw the ring and fill in the
   palette green (`#187C64` light / `#2AF598` dark). Both theme files updated,
   `AppColors.stepAccent` / `onStepAccent` added, and **step 1 now renders
   green too** — a visible change to an already-built page.

### Not done / still a placeholder

- **`onPaid` is null in the app**, so the CTA validates and reports. Step 3
  (Confirmation) does not exist and was not built ahead.
- **The saved card is fixture data.** `DATA_MODEL.md` requires a callable Cloud
  Function to list a provider customer's real methods; it does not exist, and
  Functions are still undeployed (Spark plan).
- **Brand marks are drawn from icons and text, not logo files.** Shipping Visa/
  Mastercard/FIB artwork is a trademark question and none of those assets are
  in the repo.
- **Not seen on a device** — the Windows Developer Mode blocker is unchanged.
- The Billing/New Card screen was **not** given the two-rail picker. That is a
  separate approved page; flagged rather than changed under the one-page rule.

---

## Explore Tours — reference rebuild (2026-08-20)

A re-layout pass against the supplied reference screenshot. **No data-flow,
navigation, security or query changes** — the Firestore reads, the Apply
semantics, the favourites writes, the FX conversion and the disclosure are all
untouched. The background is unchanged (the bundled photo at σ2 under the
theme gradient at 45%, straight from `DESIGN_SYSTEM.md` 4).

### What changed on screen

- **Carousel slide.** The rating moved from the leading edge to the
  **trailing** edge and now sits **above the tour name**, with the score and
  the five stars on one row and the operator tag beneath them. The place line
  now reads `Rawanduz, Erbil | 2 days travel`, as the reference does. Slide
  height 224 → 208, description 3 lines → 2, name 20 → 22.
- **Search block.** The two inputs sit **side by side on one row**, with the
  Apply button centred beneath the gap between them. Below 340dp, or above a
  1.3× system font, they stack instead of clipping.
- **Trending card.** Re-proportioned to the reference: thumbnail 104 → 100,
  min height 184 → 168, page margin 16 → 20. Title and duration lead; the
  **score and the five stars share one row** on the trailing side with the
  operator tag under them. The distance line moved directly under the place
  line. The price badge now draws the amount and "Per Person" **on one row**.
  Feature icons: five instead of four, circle 36 → 32.

### Schema change (approved shape, already in `DATA_MODEL.md`)

`TourFeature` gained four ids — `activity`, `wifi`, `electricity`, `tent` —
because the reference card tags departures with them and an unknown id is
silently dropped. Purely additive; no seeded document needs migrating. Labels
added in **all three languages**, and the detail screen's icon map too.

### Design-system deviations — NEED SIGN-OFF

1. **A compact rating badge.** Section 13 asks for "consistent padding and
   height across screens". The reference draws the card's score+stars pair at
   roughly half the carousel's size — five full-size stars cannot share a
   ~190dp column with a tour name. Radius, fill, stroke and content colour are
   the same tokens; only the type size and padding shrink.
2. **A compact recessed input.** Section 8's 56dp height, 14px radius,
   material and every state stroke are unchanged; the type size drops 16 → 14
   so two fields fit on one row. Justified under 19/20 rather than treated as
   a second input family.
3. **The reference draws pill-shaped search fields** (radius ≈ 28) where
   section 8.2 specifies radius 14. **Kept at 14** and flagged rather than
   silently changed — say which is right.

### Not done / still a placeholder

- The refinement chips and the sort control still are not drawn, although
  `toursIncludes` / `toursSortLabel` exist and `TourFilters` supports both.
  Pre-existing, not introduced here.
- There is no traveller stepper on the screen, so `TourFilters.travellers` is
  always 1 and the price badge never shows a party total.
- **Not seen on a device** — the Windows Developer Mode blocker is unchanged.
  Verified by the widget-test suite (56 tests on this screen, including a
  360dp phone width and a 1.6× system font with no overflow).

---

## Checkout step 3 — Review & Confirm (2026-08-20)

New screen: `lib/screens/booking_review_screen.dart`, opened from step 2's
"Continue to Payment". Background, glass, radii, type scale and every colour
come from `DESIGN_SYSTEM F.md` / `DESIGN_LIGHT F.md` / `DESIGN_DARK F.md` —
the same tour photograph at σ2 under the theme gradient at 45%, no per-screen
override.

### What it draws, top to bottom

1. **Step indicator** with steps 1 and 2 completed (check glyphs) and step 3
   active — the shared `BookingStepIndicator` at `activeIndex: 2`.
2. One base-glass card holding: **"Review & Confirm"** and its hint, a
   hairline, **Booking Summary** (photo · facts · vertical rule · total), a
   hairline, **Travelers Information** (numbered travellers | contact email and
   phone), a hairline, **Price Breakdown** (Traveler Fee, Transportation Bus,
   dotted leaders, then the Total Price), the consent checkbox, and the CTA.
3. **"I agree to the Terms of Service and Policy of App."** Both labels are
   tappable: Terms opens `legal_documents/terms_of_service` through
   `PolicyDocumentScreen`, Policy opens the hub the hamburger menu opens.
4. **"Confirm & Pay $65"** — disabled until the box is ticked, and also
   disabled for a tour with no computable price.

### Behaviour changes to an already-approved screen

**Step 2's "Continue to Payment" now opens step 3** instead of firing `onPaid`.
`onPaid` is forwarded to step 3, which is where a charge belongs — step 2 only
collects the instrument. Its two CTA tests were updated to match. Card-form
validation on step 2 is unchanged and still blocks before anything advances.

### Still writes nothing

`bookings` remains function-written after a provider confirms a charge
(`SECURITY.md` 1, `DATA_MODEL.md`). Step 1's payload is still carried in
memory through steps 2 and 3 and still dies with the flow. With no processor
wired the CTA says plainly that nothing was charged and no booking was created.

### Schema — nothing needed for this screen; four fields proposed

Recorded in `DATA_MODEL.md` under "**PROPOSED for checkout step 3 — not
approved**": `bookingDetails.transport`, `bookingDetails.priceBreakdown`,
`bookingDetails.termsVersion` + `termsAcceptedAt`, and a
`bookingDetails.cancellationPolicy` snapshot. **Not implemented** — they are
for the checkout Cloud Function, and need sign-off first.

### Design-system deviation — NEEDS SIGN-OFF

The reference draws both consent links in the palette green
(`primary-container`), but `text-link` is the navy `#0E2A44` in
`DESIGN_LIGHT F.md` §6. Built with **`text-link` plus an underline and a
heavier weight** — the Register screen's existing link treatment — because
navy against `#1B1B1B` body text is not distinguishable on its own. Say
whether `text-link` should become the green instead; that is a change to both
theme files, not to this screen.

### Reference vs. our arithmetic

The reference prints "Traveler Fee · Two adults · $55" with a $55 per-person
tour, i.e. it charges one fee for two people. Our model is per-person
(`Tour.totalFor`), so the line reads **$110** for two adults at $55 each and
the total follows. The layout matches the reference exactly; the numbers are
the model's, so step 2 and step 3 cannot disagree about what is owed.

### Not done / still a placeholder

- **No availability re-check before paying.** Someone can sit on this screen
  while the last seat sells. Booking.com re-validates at confirm; we do not.
- **No cancellation-policy reassurance line** above the CTA, although
  `tours.cancellationPolicy` is already on the tour and needs no schema change.
- **No "taxes and fees included" statement** — still absent app-wide.
- **No confirmation-email promise**, because no email is sent yet.
- Step 4 (the post-payment confirmation/receipt screen) does **not** exist and
  was not built ahead.
- **Not seen on a device** — the Windows Developer Mode blocker is unchanged.
  Verified by 16 new widget tests, including a 360dp width at a 1.5× system
  font, Kurdish and Arabic RTL, and dark mode.

---

## Explore Tours — carousel height, card trim, price nudge (2026-08-20)

Three requested adjustments, plus one layout bug they exposed.

- **Carousel grown by 100dp**, 208 → 308 at the default font size. It still
  scales with the system font like every other measurement on the screen.
- **The cancellation tier and the guide-language list were removed from every
  Trending card.** Both are still stored on the tour and still drawn on the
  Tour Detail screen — the card now keeps only the red availability warning
  ("Only 3 spots left"), which the user asked to keep. A test now asserts the
  card stays clear of them, so a future edit cannot quietly put them back.
- **The price badge was nudged 6dp toward the trailing edge.** 6 rather than
  10: the card's inner padding is 8dp and the glass panel clips, so a badge
  crossing the rim would be cut by the rounded corner.

### Bug found and fixed while doing it

The price column had been wrapped in `Flexible` in the previous pass to stop a
large-font overflow. A `Flexible` child takes a *share* of the row and is laid
out at the **start** of that share — so the badge was sitting near the middle
of the card rather than against its trailing edge. It was hard to see on a
phone (the share is only ~96dp there) and obvious at tablet width. Replaced
with a content-sized column under a 150dp ceiling, which keeps it at the
trailing edge and still prevents the overflow.

### Not done / still a placeholder

- Unchanged from the earlier entry: no sort control, no refinement chips, no
  traveller stepper, no result count.
- **Not seen on a device** — the Windows Developer Mode blocker is unchanged.
  Verified by the widget suite (57 tests on this screen, including the 360dp
  width at a 1.6× system font).

---

## Explore Tours — full-bleed card photo (2026-08-20)

The Trending card's photo now fills the card's leading side edge-to-edge, as
the marked-up reference asks.

- The card's `GlassPanel` padding drops to zero; the 8dp inset it used to give
  everything is now carried by the **text column alone**, so the photo can meet
  the rim while the copy keeps its breathing room.
- The photo's **leading** corners take the card's own 22dp radius so it nests
  inside the curve with no sliver of glass showing; its **inner** edge keeps a
  gentler 14dp radius against the text.
- Width 100 → **116dp**. It already stretched to the card's full height.
- The favourite heart moved 4dp in from the corner, which the photo now shares
  with the card — at 0 it would have crowded the 22dp curve.

Applies to every Trending card automatically: they are all one widget.

### Not done / still a placeholder

- Unchanged from the earlier entries: no sort control, no refinement chips, no
  traveller stepper, no result count.
- **Not seen on a device** — the Windows Developer Mode blocker is unchanged.
  Verified by the widget suite (58 tests on this screen). A new test measures
  the photo against the card it bleeds into, so the inset cannot creep back.

---

## Car Rental Details (2026-08-24)

The third screen in the Car Rental flow. Opens when a card on the Car Rental
Results screen is tapped, receiving a single `CarRentalSelection` — the chosen
vehicle plus the criteria the search was run with — so nothing is re-queried and
no location, date or time is ever re-entered.

- **Photo carousel** — `PageView` (no new dependency) over
  `RentalVehicle.images`, with the Car Rental screen's dot style. Renders
  whatever number of photos a vehicle carries: one photo shows no dots, and the
  dot row is capped at 7 so a large gallery cannot overflow the card.
- **Car details card** — name, model year, supplier badge, and five facilities
  (persons, powertrain, AC, bags, transmission) in a `Wrap`, so they reflow
  rather than overflow on a 320dp phone or at a 1.6× font scale.
- **Pick-Up / Drop-Off card** — restates the search. Collapses to one Location
  row when the branches match and shows both when they differ; it never assumes
  they are the same. Dates and times use `MaterialLocalizations`, so they render
  as the identical strings the search form showed.
- **Additional Options card** — driven by `RentalVehicle.extras`. One row widget
  covers both selection types: a checkbox add-on, and a stepper add-on whose `+`
  and `−` disable at the supplier's own min/max (Baby Seat maxes at 3). A
  quantity above one restates the arithmetic on the row.
- **Price Summary** — base rate × rental days, plus extras. Labelled an
  estimate, with a line saying taxes and supplier fees are not included, because
  there is no source for them.
- **Rental Conditions** — every field nullable; each row hides without data and
  the card hides entirely when all are absent. Empty today by design.
- **Apply** — the design system's `PrimaryButton` (§9.1), not the screenshot's
  glass pill; per §1 the design files outrank the reference image on styling.
  Shows the standard Coming Soon snackbar.

### Schema

`RentalVehicle` gained `transmission`, `extras` and `conditions`;
`RentalCompany` gained an optional `logoAsset`. `DATA_MODEL.md`'s `cars` section
documents all of it for when the collection is actually wired up.

### Not done / still a placeholder

- **No Firestore.** Like the two screens before it, this reads
  `PreviewCarRentalService`. Nothing is seeded, and no security rules are needed
  yet — recorded in `SEED_DATA.md`.
- **One photograph exists.** The five gallery entries are the same asset
  repeated so the carousel can be reviewed; real per-angle photos replace it.
- **No supplier terms.** The Rental Conditions card renders nothing until a
  provider supplies data — deliberately, not as an oversight.
- **`logoAsset` is unused.** No logo files exist, so the company badge still
  draws the generic car glyph.
- **Not seen on a device** — the Windows Developer Mode blocker is unchanged.
  Verified by 16 widget/unit tests on this screen, covering both branch modes,
  the stepper limits, the hidden conditions card, all three languages, RTL,
  dark mode, and a 320dp screen at a 1.6× font scale.

---

## Hotel Details (2026-08-25)

The second screen in the Where to Stay flow, built from the supplied `hotel`
reference. **One route serves every hotel card in the app** — the highlighted
carousel and the trending list both opened a "coming soon" snackbar before
today; there is deliberately no separate detail page per entry point.

The reference is a layout reference only. None of its blue palette was taken:
every colour, blur, radius and spacing value comes from the three authoritative
design files, and the page reuses the Where to Stay photograph
(`assets/images/hotel background.webp`) through the shared `PageBackground`, so
the flow reads as one continuous screen.

### What it draws, top to bottom

- **Back button** — the shared `GlassBackButton`, physically top-left in every
  language (`DESIGN_SYSTEM.md` 11.3), outside the image.
- **Gallery** — a `PageView` over `Hotel.images` with a `1 / 5` counter badge
  and dot indicators. The count is **dynamic**: one photo shows neither, and
  above eight photos the dots drop out so they cannot overflow while the
  counter keeps stating the true position. Five entries is preview data, not a
  layout constant.
- **Summary card** — name, address with a pin, and, opposite them, the guest
  score and the star classification as **two separate badges** (they are two
  different measurements). Below a divider: the guest/room/bed summary, the two
  date cards, and the centred `Change` pill.
- **Facilities** — four in a two-column `Wrap`, with `See all` opening a sheet
  that groups every facility by category. Facility icons resolve from a stable
  `iconKey` string, because this data will come out of a database eventually and
  a database cannot hold a Flutter icon. An unknown key falls back to a neutral
  check rather than a wrong glyph.
- **Reviews** — the overall 0–10 score with a per-category breakdown. The bars
  fill from the leading edge, so they grow right-to-left in Arabic and Kurdish
  with no branch in the code.
- **Location** — a `GoogleMap` preview using the existing dependency and
  `MapScreen`; **no new map SDK was added**. Without coordinates it says the map
  is unavailable rather than showing a map of nowhere.
- **Nearby** — name, leader dots, time and distance. The dots are decoration:
  when a long localized name or a large font scale needs the width, the row
  gives them up and stacks instead of clipping either value.
- **Ratings & Comments** — two most recent reviews and the same
  `Visited this place?` composer strip Explore Nature uses. `See all` and the
  strip both open `HotelReviewsScreen`.
- **Property policies** — collapsed by default, so it does not lengthen the page
  for everyone who is not looking for it.
- **Select Room** — `Scaffold.bottomNavigationBar`, so it is genuinely frozen
  while content scrolls beneath it, with `bottomInset + 116` of scroll padding
  so the last card is never hidden under it.

### Decisions taken, with the user's answers

1. **Data source** — preview service for now, and add the fields we have no
   real data for so they exist when Firebase is wired up. Done: the whole
   booking-critical layer is modelled in Dart and documented in
   `DATA_MODEL.md`, with nothing seeded.
2. **Select Room** — the standard "coming soon" snackbar. The Room Selection
   screen is not built; building it would have been a second page.
3. **Booking data** — models plus the Property policies section on this page.
   Prices, taxes, breakfast, cancellation and prepayment are modelled but **not
   displayed here**; they belong to room selection.
4. **Reviews** — an adapter onto the shared Explore Nature reviews screen, the
   arrangement Explore Tours already uses. No second comment system was built.

Four smaller calls were made and stated rather than asked: the score scale
stays **0–10** (the reference's 4.2/5 is not this app's scale, and mixing them
un-normalized was explicitly out); the map is the existing provider; the gallery
is built from bundled photographs; and the Change sheet exposes only what the
app actually supports.

### The reviews reuse, precisely

`HotelReviewsScreen` wraps `NatureReviewsScreen` and injects
`PreviewHotelReviewService`, which implements the `NatureSpotsService` surface
against an in-memory hotel review store. Sorting, paging, helpful votes, the
half-star composer, the sign-in gate and the "you already reviewed this" edit
branch all come for free and cannot drift from Explore Nature. The aggregate
shown at the top is derived **in the service**, never in a widget — the same
rule the live screens follow, where a Cloud Function owns it.

### Shared component extracted

`_CounterRow` / `_CounterButton` were lifted out of `hotel_screen.dart` into
`HotelCounterRow` / `HotelCounterButton` in `hotel_parts.dart`, so the Change
sheet uses the identical stepper rather than a second one that would drift.
`HotelCounterRow` gained an optional `maximum`; the Where to Stay screen passes
none, so its behaviour is unchanged (its three tests still pass).

### Schema

**No Firestore change was required — nothing reads `hotels` yet.** The Dart
model layer grew: `Hotel` gained `address`, `latitude`, `longitude`, `images`
and `reviewCount`; `HotelSearchCriteria` gained `nights`; and a new
`lib/models/hotel_detail.dart` holds `HotelDetail`, `HotelFacility`,
`HotelReviewSummary`, `HotelNearbyPlace`, `HotelRoomType`, `HotelRoomOffer`
and `HotelPolicies`. Every addition is optional with a default, so no existing
call site changed. `DATA_MODEL.md`'s `hotels` section was rewritten to match,
including the rule that provider ids stay separate from ours and that
`taxesIncluded` is **stored, not inferred**.

### Not done / still a placeholder

- **No Firestore, no seeding, no rules.** Like the two Car Rental screens
  before it, this reads preview data. Recorded in `SEED_DATA.md`.
- **No hotel photographs exist.** The five gallery entries are existing bundled
  photos so the carousel can be reviewed; real per-hotel photos replace them.
- **Nothing is priced.** No price, tax or fee is displayed on this page. The
  models exist; the Room Selection screen displays them.
- **Reviews are in memory.** A review written in preview mode survives until the
  app is closed and reaches no database. Whether only verified guests may review
  a hotel is **an open question** — the app has no stay-verification concept, so
  no permission rule was invented.
- **No child ages and no bed-preference option** in the Change sheet. Neither is
  supported by the model or by any provider, and both would have been fiction.
- **Not seen on a device** — the Windows Developer Mode blocker is unchanged.
  Verified by 36 widget/unit tests across the screen, the models, the review
  service and the shared parts, covering all three languages, RTL, dark mode,
  a 320dp screen at a 1.6x font scale, the empty/hidden sections, the failed
  read, the occupancy ceiling and the criteria round-trip on back.
