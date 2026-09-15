/**
 * Seeds `hotels`, and its `rooms`, `offers` and `reviews` subcollections
 * (DATA_MODEL.md → hotels).
 *
 * Reads `tool/hotels_seed.json`, which is **generated** from
 * `PreviewHotelService` / `PreviewHotelReviewService` by
 * `tool/export_hotels.dart`. Nothing is retyped here, so the preview content
 * the app falls back to and the catalogue in Firestore cannot drift.
 *
 *   flutter test tool/export_hotels.dart
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node tool/seed_hotels.js
 *
 * ## What this deliberately does NOT write
 *
 * * **Rating aggregates** — `reviewScore`, `ratingCount`, `ratingBreakdown`
 *   and `categoryScores` are server-owned, derived from the reviews
 *   subcollection by a Cloud Function. Same rule as nature_spots and tours:
 *   until that function is deployed every hotel shows **no score at all**,
 *   which is the honest state for a catalogue whose reviews have not been
 *   counted — not a bug in the screen.
 * * **`helpfulCount`** on a review — server-owned, from the votes
 *   subcollection.
 * * **`imageUrls`** is written as an empty array, matching nature_spots and
 *   tours. The preview images are bundled asset paths; the schema documents
 *   this field as Storage URLs.
 *
 * ## Review document ids
 *
 * The id of a review **is its author's uid** — that is what makes "one review
 * per person per hotel" enforceable in `firestore.rules`. The preview content
 * has display names and no accounts, so these are seeded under `seed-*`
 * placeholder ids exactly as the nature-spot reviews are. **Replace or delete
 * them once real accounts exist.**
 *
 * Uses `{ merge: true }`, so re-running never deletes a field an admin added
 * through the panel.
 */

const fs = require("fs");
const path = require("path");
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  GeoPoint,
  Timestamp,
} = require("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const SOURCE = path.join(__dirname, "hotels_seed.json");
const COLLECTION = "hotels";

/**
 * The only currencies the app can display, mirroring `firestore.rules` and
 * `FirestoreHotelService.supportedCurrencies`. A hotel or an offer quoted in
 * anything else — or in nothing at all — is REJECTED here rather than written
 * and silently read as USD later, which would misprice an IQD rate by roughly
 * 1300x.
 */
const SUPPORTED_CURRENCIES = ["USD", "IQD"];

/** Fields a client must never be able to seed — all server-owned. */
const FORBIDDEN_HOTEL_FIELDS = [
  "reviewScore",
  "ratingCount",
  "ratingBreakdown",
  "categoryScores",
];

function validateHotel(id, hotel) {
  const at = `${COLLECTION}/${id}`;
  if (!hotel || typeof hotel !== "object") throw new Error(`${at} is not an object`);
  if (!hotel.name || typeof hotel.name.en !== "string" || !hotel.name.en.trim()) {
    throw new Error(`${at} has no English name`);
  }
  if (!Number.isFinite(hotel.starRating) || hotel.starRating < 0 || hotel.starRating > 5) {
    throw new Error(`${at} has a bad starRating: ${hotel.starRating}`);
  }
  for (const field of FORBIDDEN_HOTEL_FIELDS) {
    if (field in hotel) {
      throw new Error(
        `${at} carries the server-owned field "${field}". Aggregates are ` +
          `derived by a Cloud Function, never seeded — a hand-typed average ` +
          `is overwritten by the first real review.`
      );
    }
  }
  // Approved 2026-09-13. Both must be real booleans: the customer list filters
  // on `active`, and a string "false" would read as truthy and publish a hotel
  // an admin had retired.
  for (const flag of ["highlighted", "active"]) {
    if (typeof hotel[flag] !== "boolean") {
      throw new Error(`${at} has a non-boolean ${flag}: ${hotel[flag]}`);
    }
  }
  // Required, never defaulted (approved 2026-09-15). `pricePerNightFrom` means
  // nothing without it.
  if (!SUPPORTED_CURRENCIES.includes(hotel.currencyCode)) {
    throw new Error(
      `${at} has currencyCode "${hotel.currencyCode}". A hotel must state one ` +
        `of ${SUPPORTED_CURRENCIES.join(" | ")}; a missing code would be read ` +
        `as USD and misprice an IQD property by roughly 1300x.`
    );
  }
  if (!Number.isFinite(hotel.pricePerNightFrom) || hotel.pricePerNightFrom < 0) {
    throw new Error(
      `${at} has a bad pricePerNightFrom: ${hotel.pricePerNightFrom}`
    );
  }
  if ("distanceFromCenterKm" in hotel) {
    throw new Error(
      `${at} carries distanceFromCenterKm, which was explicitly declined ` +
        `(DATA_MODEL.md). There is no verified source for it; the card hides ` +
        `the line instead of showing a fabricated number.`
    );
  }
  if (hotel.location) {
    const { lat, lng } = hotel.location;
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new Error(`${at} has a malformed location`);
    }
  }
}

function validateOffer(at, offer) {
  for (const field of ["nightlyPrice", "totalPrice", "taxes", "fees"]) {
    if (!Number.isFinite(offer[field]) || offer[field] < 0) {
      throw new Error(`${at} has a bad ${field}: ${offer[field]}`);
    }
  }
  if (typeof offer.taxesIncluded !== "boolean") {
    // Stored, never inferred — the UI must always be able to state which
    // figure it is showing (DATA_MODEL.md).
    throw new Error(`${at} must state taxesIncluded explicitly`);
  }
  if (!Number.isInteger(offer.availableQuantity) || offer.availableQuantity < 0) {
    throw new Error(`${at} has a bad availableQuantity`);
  }
  // Same rule as the hotel, and it matters more here: this is the figure a
  // checkout quotes against.
  if (!SUPPORTED_CURRENCIES.includes(offer.currency)) {
    throw new Error(
      `${at} has currency "${offer.currency}". An offer must state one of ` +
        `${SUPPORTED_CURRENCIES.join(" | ")}.`
    );
  }
}

function validateReview(at, id, review) {
  if (review.userId !== id) {
    throw new Error(
      `${at} has userId "${review.userId}" but the document id is "${id}". ` +
        `The id IS the author's uid — firestore.rules enforces it.`
    );
  }
  const r = review.rating;
  if (!Number.isFinite(r) || r < 0.5 || r > 5 || r * 2 !== Math.round(r * 2)) {
    throw new Error(`${at} has a rating outside 0.5–5 in half steps: ${r}`);
  }
  if (typeof review.comment !== "string" || review.comment.length < 3 || review.comment.length > 1000) {
    throw new Error(`${at} has a comment outside 3–1000 characters`);
  }
  if (review.status !== "published") {
    throw new Error(`${at} must be published`);
  }
  if ("helpfulCount" in review) {
    throw new Error(`${at} carries the server-owned helpfulCount`);
  }
}

/** Converts the JSON envelope into Firestore-native types. */
function hotelPayload(hotel) {
  const out = { ...hotel };
  if (hotel.location) {
    out.location = new GeoPoint(hotel.location.lat, hotel.location.lng);
  }
  return out;
}

function offerPayload(offer) {
  const out = { ...offer };
  if (offer.cancellationDeadline) {
    out.cancellationDeadline = Timestamp.fromDate(
      new Date(offer.cancellationDeadline)
    );
  }
  return out;
}

async function main() {
  if (!fs.existsSync(SOURCE)) {
    throw new Error(
      `${SOURCE} is missing. Generate it first:\n` +
        `  flutter test tool/export_hotels.dart`
    );
  }

  const raw = JSON.parse(fs.readFileSync(SOURCE, "utf8"));
  const entries = Object.entries(raw).filter(([k]) => !k.startsWith("_"));
  if (entries.length === 0) throw new Error("no hotels in the source file");

  // Validate everything BEFORE writing anything. A seed script that writes
  // half a catalogue and then fails is worse than one that refuses to start.
  for (const [id, bundle] of entries) {
    validateHotel(id, bundle.hotel);
    for (const [offerId, offer] of Object.entries(bundle.offers || {})) {
      validateOffer(`${COLLECTION}/${id}/offers/${offerId}`, offer);
    }
    for (const [reviewId, review] of Object.entries(bundle.reviews || {})) {
      validateReview(`${COLLECTION}/${id}/reviews/${reviewId}`, reviewId, review);
    }
  }

  let rooms = 0;
  let offers = 0;
  let reviews = 0;

  for (const [id, bundle] of entries) {
    const hotelRef = db.collection(COLLECTION).doc(id);
    await hotelRef.set(
      { ...hotelPayload(bundle.hotel), updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    console.log(`seeded ${COLLECTION}/${id}`);

    for (const [roomId, room] of Object.entries(bundle.rooms || {})) {
      await hotelRef.collection("rooms").doc(roomId).set(room, { merge: true });
      rooms++;
      console.log(`  rooms/${roomId}`);
    }
    for (const [offerId, offer] of Object.entries(bundle.offers || {})) {
      await hotelRef
        .collection("offers")
        .doc(offerId)
        .set(offerPayload(offer), { merge: true });
      offers++;
      console.log(`  offers/${offerId}`);
    }
    for (const [reviewId, review] of Object.entries(bundle.reviews || {})) {
      await hotelRef
        .collection("reviews")
        .doc(reviewId)
        .set(
          {
            ...review,
            createdAt: Timestamp.fromDate(new Date(review.createdAt)),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      reviews++;
      console.log(`  reviews/${reviewId}`);
    }
  }

  console.log(
    `\nDone — ${entries.length} hotels, ${rooms} rooms, ${offers} offers, ` +
      `${reviews} reviews.`
  );
  console.log(
    "No rating aggregates were written; they are derived by a Cloud Function.\n" +
      "Until it is deployed every hotel shows no score, which is expected."
  );
}

main().catch((error) => {
  console.error(`\nSeed aborted: ${error.message}`);
  process.exit(1);
});
