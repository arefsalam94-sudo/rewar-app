# SEED_DATA.md — One Example Per Collection

Tracks the one real example document seeded into each Firestore collection,
so it's always clear what "real" data currently exists to test screens
against (per the "One example, seeded to Firestore, per page" rule in
`CLAUDE.md`).

Update the **Status** column as each one actually gets added to Firestore —
don't mark it seeded until it's really there and confirmed rendering.

> **Live project: `rewar-app-1c10e`** (Firestore `eur3`, production mode).
> Rules and indexes are deployed; five collections are seeded and read back.
> ✅ below means *the documents exist and were read back from Firestore*, not
> that the screen has been seen rendering them on a device — no screen has, as
> `PROGRESS.md` records.

| Collection | Example | Status |
|---|---|---|
| legal_documents | **all 7 policy documents** (en/ku/ar) — seed with `node tool/seed_legal_documents.js` | ✅ **SEEDED** 2026-08-17 — 7 docs. Still `legalReviewed:false` with [placeholders] |
| featured | 4 carousel slides (nature spot, car, flight, tour) — seed with `node tool/seed_home_screen.js` | ✅ **SEEDED** 2026-08-17 — 4 docs. `imageUrl` still empty on all four |
| nature_spots | Rawanduz Canyon (highlighted), Sami Abdulrahman Park, Erbil Citadel — seed with `node tool/seed_explore_nature.js` | ✅ **SEEDED** 2026-08-17 — 3 docs. `imageUrls` still empty |
| nature_spots/{id}/reviews | 7 visitor reviews — 3 for Rawanduz (Elena P., Hassan S., Priya N.), 2 each for the other places. Same script | ✅ **SEEDED** 2026-08-17 — 7 docs. **Scores still absent — `syncNatureReviewAggregates` is not deployed (needs Blaze)** |
| nature_spots/{id}/reviews/{id}/votes | n/a — written only by a signed-in user tapping the heart | N/A (not seeded by hand) |
| hotels | Divan Hotel (Iraq, Erbil, 40m Street) | NOT SEEDED — Where to Stay and the **Hotel Details** screen both read `PreviewHotelService`, not Firestore. Its three review hotels (Divan Erbil, Ramada Sulaimani, Duhok Palace) are typed mock data only. Divan carries the full detail set — a five-entry gallery built from **existing bundled photographs** (no per-hotel photos exist yet), fifteen facilities across nine categories, six Erbil nearby places, a five-category review breakdown, two room types, three rates and full policies. Ramada carries a partial set, and Duhok Palace is deliberately bare (no gallery, no coordinates, no facilities, no nearby, no aggregate) so the hidden sections and empty states stay reviewable. **None of it is a claim about these properties** |
| hotels/{id}/rooms | Ocean View Suite | NOT SEEDED — two preview room types exist in Dart (Deluxe King, Twin City View) purely to give the guest counters a published `maxOccupancy` to enforce |
| hotels/{id}/offers | n/a | NOT SEEDED — three preview rates exist in Dart with invented prices, taxes, fees, breakfast, cancellation and prepayment values. Nothing on the Hotel Details page displays a price; they exist so the Room Selection screen has a shape to build against |
| hotels/{id}/reviews | Sarah — "The views are incredible! Highly recommend." | NOT SEEDED — the Hotel Details page's Ratings & Comments card and its full reviews page read `PreviewHotelReviewService`, an **in-memory** store (three sample reviews for Divan, one for Ramada). Reviews written in preview mode survive until the app is closed and reach no database |
| cars | Tesla Model 3 (GreenWheels Rentals) | NOT SEEDED — the Car Rental and Car Rental Results screens read `PreviewCarRentalService`, not Firestore. Its five review vehicles (Tesla Model 3, Ford Mustang, Toyota Corolla, Range Rover, BMW X5 — ABC Cars / Paradise Rent A Car) are typed mock data only; seed real docs when a rental provider or the `cars` collection is wired up. The Car Rental **Details** screen reads the same mock data: five gallery entries per car (the single `journey-car.png` asset repeated, so the carousel can be exercised) and six add-ons per car with invented prices. `conditions` is left **entirely empty** on all five — fuel policy, mileage, deposit, excess, cancellation deadline, minimum age and required documents are contractual terms and are never invented for review data, so the Rental Conditions card stays hidden until a supplier feed fills them |
| tours | Gali Alibag Waterfall (highlighted + trending), Gali Sherana (trending), Korek Mountain Day Trip (highlighted) — seed with `node tool/seed_explore_tours.js` | ✅ **SEEDED** 2026-08-17 — 3 docs, both queries verified live. `imageUrls` still empty |
| tours — `minAge` | **Gali Sherana only**, `minAge: 18`; the other two omit the field so "absent = no restriction" is exercised too | ⚠️ **NOT RE-SEEDED** — added to `tool/seed_explore_tours.js` on 2026-08-18 for the Traveler Info age gate. Re-run the script to push it |
| tours — `features` | Re-tagged on 2026-08-20 to the Explore Tours reference: Gali Alibag `guide, activity, wifi, food, electricity`; Gali Sherana `campfire, tent, wifi, swimming`; Korek `guide, food, transport, photography, activity` | ⚠️ **NOT RE-SEEDED** — the four new ids (`activity`, `wifi`, `electricity`, `tent`) are additive, so the seeded docs still load; they just draw the old four icons until `node tool/seed_explore_tours.js` is re-run |
| tours/{id}/reviews | 5 traveller reviews — 3 for Gali Alibag, 2 for Gali Sherana, **none for Korek on purpose**. Same script | ✅ **SEEDED** 2026-08-17 — 5 docs. **Scores still absent — `syncTourReviewAggregates` is not deployed (needs Blaze)** |
| currency_rates | `latest` — USD base, IQD and EUR — seed with `node tool/seed_currency_rates.js` | ✅ **SEEDED** 2026-08-17 — 1 doc (`USD:1, IQD:1310, EUR:0.92`). Nothing refreshes it |
| flights | Astra Airlines, Erbil (EBL) → Istanbul | NOT SEEDED |
| users | (your own test account, created via the Auth screen) | NOT SEEDED |
| bookings | one per type — hotel, flight, car, tour (upcoming + completed) — seed with `node tool/seed_bookings.js <uid>` | NOT SEEDED (needs a Firebase project) |
| favorites | (one test favorite once favoriting is wired up) | NOT SEEDED |
| password_reset_codes | n/a — written only by Cloud Functions | N/A (not seeded by hand) |
| mail | n/a — written only by Cloud Functions | N/A (not seeded by hand) |

> The Verification Code screen reads no catalog data, so the "one seeded
> example document" rule doesn't apply to it in the usual way. Its equivalent
> proof is an **end-to-end run**: request a code, receive the real SMS/email,
> and verify it against the deployed Cloud Function. That can't happen until
> `FIREBASE_SETUP.md` is finished.

### featured + nature_spots (Home screen)

Seeded together by one script, because the carousel is meaningless without at
least one catalog document behind it:

```
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
  node tool/seed_home_screen.js
```

The same four slides are duplicated as `bundledFeatured()` in
`lib/services/featured_service.dart`, which is what preview mode serves before
Firebase exists — **keep the two in sync**, the same rule as the bundled
Terms text.

> ⚠️ Every seeded slide has an **empty `imageUrl`**. Upload the four photos to
> Firebase Storage and paste the download URLs in (or set them from the admin
> panel) — with no URL the card falls back to a flat brand colour instead of
> a photo. The page is not "done" until at least one slide renders with its
> real image on a running device.

### nature_spots (Explore Nature screen)

The three places drawn in the `explore nature.jpg` reference — Rawanduz Canyon
(flagged `highlighted`, so it fills the top carousel), Sami Abdulrahman Park
and Erbil Citadel:

```
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
  node tool/seed_explore_nature.js
```

The same three are duplicated as `NatureSpotsService.bundledSpots()` in
`lib/services/nature_spots_service.dart`, which is what preview mode serves
before Firebase exists — **keep the two in sync**, the same rule as the
bundled Terms text and the bundled featured slides.

Each document carries all **three** tag arrays the Explore Nature and Customize
Filters screens filter on — `categories`, `placeTypes`, `amenities`. A place
with an empty array simply never matches that group's chips, so leaving one out
silently hides the place from anyone who filters. The seeded three are tagged
across every group deliberately, so each filter has something to find.

Rawanduz also carries three `nearbyStays` preview maps.

**Reviews are seeded by the same script**, seven of them: three for Rawanduz —
Elena P., Hassan S. and Priya N., the ones drawn in the Reviews & Ratings
reference — and two each for Sami Abdulrahman Park and Erbil Citadel, so no
place shows a score with nothing behind it.

Two things about them are easy to get wrong:

- **The document id is the author's uid**, which `firestore.rules` requires
  (one review per person per place). The `seed-*` ids stand in for real Auth
  uids; replace them, or delete these documents, once real accounts exist.
- **`rating` is a half-step number**, 0.5–5, not an integer. The page shows it
  as `rating × 2` out of 10 — 4.5 reads as 9.0 / 10.

> ⚠️ **The script writes no `reviewScore`, `ratingCount` or `ratingBreakdown`,
> deliberately.** All three are server-owned and derived by the
> `syncNatureReviewAggregates` Cloud Function from the reviews above. Deploy
> the functions (`firebase deploy --only functions`) before or with the seed;
> until that trigger runs, **every place will show no score at all** — which is
> the honest state for a catalog whose reviews have not been counted, and is
> the failure to expect rather than a bug in the screen.

The same seven are mirrored by `NatureSpotsService.bundledReviews()`, and the
aggregates they imply are mirrored on `bundledSpots()` (Rawanduz 8.0 from 3,
Sami 8.5 from 2, Erbil 9.0 from 2). **Keep all of it in sync** — the bundled
numbers exist to match what the Cloud Function would compute, so a preview that
disagrees with them is a bug in the fixture, not a display quirk.

> This script **overwrites** `nature_spots/rawanduz-canyon`, which
> `tool/seed_home_screen.js` also writes. Intentional: this one carries the
> revised schema (locale maps, `reviewScore`, `categories`, `highlighted`,
> `active`), and the Home screen only runs an unfiltered `count()` against the
> collection, so it is unaffected. Run this one **second**.

> ⚠️ Every seeded document has an **empty `imageUrls`** array. Upload the
> photos to Firebase Storage and paste the download URLs in (or set them from
> the admin panel) — with no URL the card falls back to a brand-coloured panel
> with a park icon instead of a photo. The page is not "done" until at least
> one place renders with its real image on a running device.

### tours (Explore Tours screen)

The three tours drawn in the Explore Tours reference — Gali Alibag Waterfall
(flagged both `highlighted`, so it fills the top carousel, and `trending`, so
it leads the list), Gali Sherana (`trending`) and Korek Mountain Day Trip
(`highlighted` only, so the carousel has a second slide):

```
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
  node tool/seed_explore_tours.js
```

The same three are duplicated as `ToursService.bundledTours()` in
`lib/services/tours_service.dart`, which is what preview mode serves before
Firebase exists — **keep the two in sync**, the same rule as the bundled nature
spots and the bundled featured slides.

Three things about these documents are easy to get wrong:

- **`durationDays` is a number, not "2 Days travel".** The app builds that line
  in all three languages; a stored English sentence would print English on a
  Kurdish card.
- **`features` uses the ids in `lib/models/tour.dart`** — `camping`, `hiking`,
  `guide`, `food`, `swimming`, `campfire`, `transport`, `photography`,
  `activity`, `wifi`, `electricity`, `tent`. An id the app has no icon for is
  silently dropped from the card, so a typo shows up as a missing icon rather
  than an error. The list card draws the **first five**.
- **`companyTag` is not translated.** It is the operator's own brand name.

> ⚠️ **`startAt` / `endAt` are written relative to the day the script runs**,
> not as fixed calendar dates — a seeded catalog full of tours that departed
> last year makes the date filter untestable and the list dishonest. Re-run the
> script whenever the seeded dates fall into the past.

> ⚠️ Every seeded document has an **empty `imageUrls`** array. Upload the
> photos to Firebase Storage and paste the download URLs in (or set them from
> the admin panel) — with no URL the card falls back to a brand-coloured panel
> with a tour icon instead of a photo. The page is not "done" until at least
> one tour renders with its real image on a running device.

**Reviews are seeded by the same script**, five of them: three for Gali Alibag
and two for Gali Sherana. **Korek is left with none deliberately**, so the "No
reviews yet" state on a real card can be checked against live data rather than
only in a unit test.

Two things about them are easy to get wrong, both identical to the nature
reviews:

- **The document id is the author's uid**, which `firestore.rules` requires
  (one review per person per tour). The `seed-*` ids stand in for real Auth
  uids; replace them, or delete these documents, once real accounts exist.
- **`rating` is a half-step number**, 0.5–5, not an integer.

> ⚠️ **The script writes no `reviewScore`, `ratingCount` or `ratingBreakdown`,
> deliberately.** All three are server-owned and derived by the
> `syncTourReviewAggregates` Cloud Function from the reviews above. Deploy the
> functions (`firebase deploy --only functions`) before or with the seed; until
> that trigger runs **every tour shows no score at all** — the honest state for
> a catalog whose reviews have not been counted, and the failure to expect
> rather than a bug in the screen.

> ⚠️ **`bookedCount` is server-owned too.** The seeded values exist only so the
> availability line is reviewable. Once the tour checkout is built, its Cloud
> Function owns the field — see the note in `functions/index.js`.

The aggregates the seeded reviews imply are mirrored on
`ToursService.bundledTours()` (Alibag 8.7 from 3, Sherana 8.5 from 2, Korek
none). **Keep them in sync** — the bundled numbers exist to match what the
Cloud Function would compute, so a preview that disagrees is a bug in the
fixture, not a display quirk.

### currency_rates (converted prices)

One document, `currency_rates/latest`:

```
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
  node tool/seed_currency_rates.js
```

Mirrored by `CurrencyRatesService.bundledRates`. **Keep the two in sync.**

> ⚠️ **These rates are indicative, not transactional**, and **nothing refreshes
> them yet.** They let a traveller compare a USD tour against an IQD one; a
> charge must be settled in the operator's own currency by the payment
> processor. Before release this needs a scheduled Cloud Function against a
> rate provider (key in Secret Manager, never in the repo) or an admin-panel
> form. See the header of the seed script.

### legal_documents — all seven, one script

One command seeds every document behind the Policy hub — Terms & Conditions,
Privacy Policy, Cancellation & Refunds, Payment Policy, Liability &
Disclaimer, Contact & Complaints, Account & Data Deletion:

```sh
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
  node tool/seed_legal_documents.js
```

**There is no second copy of the wording to keep in sync.** Both the script
and the app read `assets/legal/legal_documents.json`: the app bundles it and
serves it in preview mode, the script reads it off disk and writes it to
Firestore. To change a policy, edit that JSON — never a Dart or JS copy, and
never the Firestore console alone (the next seed would overwrite it).

Two guards, so a bad edit fails loudly instead of shipping half-translated:

- A **Dart test** asserts every document has all three languages with the same
  sections, the same block count, the same block types, and the same bullets
  bolded — plus that the asset covers exactly the seven `PolicyTopic` ids,
  with no missing id and no orphan.
- The **seed script validates before it writes anything**, so a malformed file
  cannot leave the collection half-updated.

Preview mode parses the asset with the same `LegalDocument.fromMap()` used on
live Firestore data, so a malformed document shows up in development.

> `legalReviewed` is **false** on all seven, and the app shows a visible
> warning banner while it is. Flip it to true only once the wording —
> especially the Kurdish and Arabic renderings, which were translated rather
> than drafted by a legal translator — has been signed off by someone
> qualified. The script prints a reminder.
>
> ⚠️ Several documents still contain **[square-bracket placeholders]** —
> support email, phone number, business name and address, response times,
> accepted payment methods. `contact_complaints` says so in its own text. The
> script prints how many documents still have them.
>
> ⚠️ **`terms_of_service` is at version 2.** The registration consent gate and
> the Policy hub's "Terms & Conditions" row read this same document, on
> purpose. Its wording was replaced wholesale, so anyone who accepted v1 has
> not accepted this text.

> ⚠️ Unlike the catalog collections, this one has **no missing images** and
> needs no follow-up upload. Seeding it is the whole job.

### bookings (My Bookings screen)

`node tool/seed_bookings.js <firebase-auth-uid>` writes five documents —
`preview-hotel`, `preview-flight`, `preview-car`, `preview-tour-upcoming`,
`preview-tour` — covering every product type, so every card layout on the
screen is reachable. Four are ahead of today and one is completed, so the
Upcoming and Past segments both have content whenever the script is run.

Tours are seeded **twice**, once upcoming and once completed. The screen opens
on Upcoming, so a tour that only exists in the past leaves the Tours chip empty
on the segment users land on — which reads as a broken filter rather than as an
empty Past.

**The uid argument is required and must be a real Firebase Auth uid.** Every
read is pinned to `request.auth.uid` by `firestore.rules`, so a booking written
against a placeholder uid is invisible in the app and looks like a bug in the
screen rather than a bad seed. The script refuses to run without one.

**This script exists only because checkout does not.** In production a booking
is created exclusively by the checkout Cloud Function after the payment provider
confirms the charge — the rules deny every client write to this collection, and
`bookingReference` must be generated server-side. The script uses the Admin SDK,
which bypasses the rules; that is the only reason it can write. Delete it, or
restrict it to non-production projects, once Phases 4–7 exist.

The same five documents are duplicated as `BookingsService.bundledBookings()`
in `lib/services/bookings_service.dart`, which preview mode serves before
Firebase exists. **Keep the two in sync** — a test asserts the ids and booking
references match.

> `display.imageUrl` is empty on every document. Upload the photos to Storage
> and set the URLs before calling this page done; until then the card falls
> back to a brand-coloured panel with an image icon rather than a broken image.

## Suggested field values, ready to paste into the admin manual-entry
## forms (or Firestore console) once each collection exists

### hotels
```
name: Divan Hotel
address: Iraq, Erbil, 40m Street
city: Erbil
starRating: 5
reviewScore: 8.9
pricePerNightFrom: 200
amenities: [Pool, Bar, Restaurant, Parking]
```

### hotels/{id}/rooms
```
name: Ocean View Suite
bedConfiguration: [{type: Queen, count: 1}, {type: Sofa Bed, count: 1}]
sizeSqm: 90
facilities: [Beach Access, Balcony, Free Wi-Fi, Minibar, Room Service]
pricingOptions: [
  {title: "Property + Breakfast", infoLines: ["Non-refundable","Prepay online","Check-in: 3:00 PM"], pricePerNight: 260},
  {title: "Properties Only", infoLines: ["Free cancellation","Prepay online","Check-in: 2:00 PM"], pricePerNight: 240}
]
availableCount: 4
```

### cars
```
name: Tesla Model 3
year: 2026
rentalCompany: GreenWheels Rentals
companyTag: DriveXpress
capacity: 4
fuelType: Electric
bags: 2
hasAC: true
paymentInfo: Pay at the pick-up
pricePerDay: 58
```

### tours
Seeded by `tool/seed_explore_tours.js` — this is the shape the admin panel's
tour form must produce. Note the locale maps, the numeric `durationDays` and
the snake_case feature ids.
```
name:          { en: "Gali Alibag Waterfall", ku: "ئاوشاری گەلی عەلی بەگ", ar: "شلال كلي علي بك" }
locationLabel: { en: "Rawanduz, Erbil", ku: "ڕەواندز، هەولێر", ar: "راوندوز، أربيل" }
description:   { en: "A popular scenic waterfall destination with cool water, picnic spots, and beautiful mountain views.", ku: "...", ar: "..." }
companyTag: AB group        # a brand name — NOT translated
durationDays: 2             # a NUMBER, not "2 Days travel"
features: [guide, activity, wifi, food, electricity]
location: geopoint(36.6289, 44.5311)
pricePerPerson: 55
currency: USD               # what a charge is settled in; display conversion is separate
startAt: <timestamp>        # departure — drives ordering and the date filter
endAt:   <timestamp>        # return; omit for a one-day tour
capacity: 24                # optional; absent hides the availability line
bookedCount: 21             # SERVER-OWNED once checkout exists — read-only in admin
minAge: 18                  # optional; absent = no age restriction. Checked on the Traveler Info screen
cancellationPolicy: free_48h   # free_24h | free_48h | free_7d | non_refundable
guideLanguages: [en, ku, ar]   # ISO 639-1: en | ku | ar | tr | fa
transportAvailable: true       # operator-configured per departure
transportPricePerPerson: 5     # in the tour currency; never client supplied
# reviewScore / ratingCount / ratingBreakdown are SERVER-OWNED — never typed here
trending: true
trendingOrder: 1
highlighted: true
highlightOrder: 1
active: true
```

### flights
```
airline: Astra Airlines
fromAirportCode: EBL
toAirportCode: IST
durationMinutes: 165
price: 400
cabinClass: Economy
```
