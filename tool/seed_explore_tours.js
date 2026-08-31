/**
 * Seeds the `tours` documents the Explore Tours screen reads.
 *
 * Writes three tours, matching the reference screenshot:
 *   gali-alibag-waterfall — highlighted (top carousel) and trending (card 1)
 *   gali-sherana          — trending (card 2)
 *   korek-mountain-day    — highlighted only, so the carousel has two slides
 *
 * See the "one example, seeded to Firestore, per page" rule in CLAUDE.md and
 * the tracking table in SEED_DATA.md.
 *
 * These same three are duplicated as `ToursService.bundledTours()` in
 * `lib/services/tours_service.dart`, which is what preview mode serves before
 * Firebase exists. Keep the two in sync.
 *
 * ⚠️ `startAt` / `endAt` are written **relative to the day this script runs**,
 * not as fixed calendar dates. A seeded catalog full of tours that departed
 * last year would make the date filter untestable and the list dishonest.
 * Re-run the script whenever the seeded dates fall into the past.
 *
 * It also seeds the traveller reviews behind each tour's score — three for
 * Gali Alibag and two for Gali Sherana. Korek is left with none on purpose, so
 * the "no reviews yet" state on a real card is testable.
 *
 * ⚠️ `reviewScore`, `ratingCount` and `ratingBreakdown` are deliberately NOT
 * written here. They are **server-owned**: the `syncTourReviewAggregates`
 * Cloud Function derives them from the review documents below. Writing them by
 * hand would produce a tour claiming 300 reviews with two review documents
 * behind it — and the next review posted would silently correct it anyway.
 * Deploy the functions before (or with) running this script; until they exist
 * the tours show no score, which is the honest state for a catalog with no
 * counted reviews.
 *
 * ⚠️ `bookedCount` is **server-owned** too. The seeded values below exist only
 * so the availability line is reviewable; once the tour checkout exists, that
 * Cloud Function owns the field (see the note in `functions/index.js`).
 *
 * ⚠️ `imageUrls` is left empty on every document. Upload the photos to
 * Firebase Storage first, then paste their download URLs in below (or set them
 * from the admin panel). With no URL the card falls back to a brand-coloured
 * panel with a tour icon rather than showing a broken image.
 *
 * Usage:
 *   1. Download a service-account key from
 *      Firebase Console → Project Settings → Service accounts.
 *      Do NOT commit it — .gitignore already covers *-service-account.json.
 *   2. cd functions && npm install && cd ..
 *   3. GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *        node tool/seed_explore_tours.js
 */

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  GeoPoint,
} = require("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

/** Midnight, `days` from today, in the server's timezone. */
function inDays(days) {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() + days);
}

/**
 * `name`, `description` and `locationLabel` are locale maps so switching
 * language costs no extra read. A missing locale falls back to `en` in the app.
 *
 * `companyTag` is deliberately NOT a locale map — it is a company's own name,
 * and translating a brand is wrong in the same way translating "Booking.com"
 * would be.
 *
 * `durationDays` is a NUMBER, not the rendered string "2 Days travel": the app
 * builds that line in three languages from the number. Storing the sentence
 * would make the Kurdish and Arabic cards read English.
 *
 * `features` are the ids in `lib/models/tour.dart` (`TourFeature`):
 *   camping | hiking | guide | food | swimming | campfire | transport |
 *   photography | activity | wifi | electricity | tent
 * The app draws the first five on a list card and drops any id it has no icon
 * for, so adding a new tag here needs a matching enum value in the app.
 */
const TOURS = [
  {
    id: "gali-alibag-waterfall",
    name: {
      en: "Gali Alibag Waterfall",
      ku: "ئاوشاری گەلی عەلی بەگ",
      ar: "شلال كلي علي بك",
    },
    locationLabel: {
      en: "Rawanduz, Erbil",
      ku: "ڕەواندز، هەولێر",
      ar: "راوندوز، أربيل",
    },
    description: {
      en:
        "A popular scenic waterfall destination with cool water, picnic " +
        "spots, and beautiful mountain views.",
      ku:
        "شوێنێکی ناودار و دڵڕفێنی ئاوشار بە ئاوی سارد و شوێنی پیکنیک و " +
        "دیمەنی جوانی چیاکان.",
      ar:
        "وجهة شلالات خلابة ومشهورة بمياهها الباردة وأماكن النزهات " +
        "وإطلالات جبلية جميلة.",
    },
    companyTag: "AB group",
    durationDays: 2,
    features: ["guide", "activity", "wifi", "food", "electricity"],
    imageUrls: [],
    location: new GeoPoint(36.6289, 44.5311),
    pricePerPerson: 55,
    currency: "USD",
    startAt: inDays(4),
    endAt: inDays(6),
    capacity: 24,
    bookedCount: 21,
    cancellationPolicy: "free_48h",
    guideLanguages: ["en", "ku", "ar"],
    transportAvailable: true,
    transportPricePerPerson: 5,
    trending: true,
    trendingOrder: 1,
    highlighted: true,
    highlightOrder: 1,
    active: true,
  },
  {
    id: "gali-sherana",
    name: {
      en: "Gali Sherana",
      ku: "گەلی شێرانە",
      ar: "كلي شيرانة",
    },
    locationLabel: {
      en: "Duhok Province",
      ku: "پارێزگای دهۆک",
      ar: "محافظة دهوك",
    },
    description: {
      en:
        "A relaxing nature escape known for peaceful scenery, fresh air, " +
        "and a great riverside camp experience.",
      ku:
        "پاشەکشەیەکی ئارامی سروشت کە بە دیمەنی هێمن و هەوای پاک و " +
        "ئەزموونی خۆشی خێوەتگە لەسەر ڕووبار ناسراوە.",
      ar:
        "ملاذ طبيعي مريح يشتهر بمناظره الهادئة وهوائه النقي وتجربة " +
        "تخييم رائعة على ضفة النهر.",
    },
    companyTag: "Ava group",
    durationDays: 1,
    features: ["campfire", "tent", "wifi", "swimming"],
    imageUrls: [],
    location: new GeoPoint(37.0469, 43.0892),
    pricePerPerson: 32,
    currency: "USD",
    startAt: inDays(11),
    endAt: inDays(12),
    capacity: 16,
    bookedCount: 4,
    // The only seeded tour with an age restriction, so the Traveler Info
    // screen's age gate can be seen firing against real data. The other two
    // omit the field on purpose — absent must read as "no restriction".
    minAge: 18,
    cancellationPolicy: "free_24h",
    guideLanguages: ["ku", "ar"],
    transportAvailable: true,
    transportPricePerPerson: 4,
    trending: true,
    trendingOrder: 2,
    highlighted: false,
    highlightOrder: 0,
    active: true,
  },
  {
    id: "korek-mountain-day",
    name: {
      en: "Korek Mountain Day Trip",
      ku: "گەشتی ڕۆژانەی چیای کۆڕەک",
      ar: "رحلة يوم إلى جبل كورك",
    },
    locationLabel: {
      en: "Rawanduz, Erbil",
      ku: "ڕەواندز، هەولێر",
      ar: "راوندوز، أربيل",
    },
    description: {
      en:
        "Cable car to the summit, alpine air and a long lunch above the " +
        "clouds, with a guide for the ridge walk.",
      ku:
        "تەلەفریک بۆ لوتکە، هەوای چیایی و نانی نیوەڕۆی درێژ لەسەرووی " +
        "هەورەکانەوە، لەگەڵ ڕێبەرێک بۆ پیاسەی شاخ.",
      ar:
        "تلفريك إلى القمة وهواء جبلي وغداء طويل فوق الغيوم، مع مرشد " +
        "لجولة المشي على الحافة.",
    },
    companyTag: "Zagros Trips",
    durationDays: 1,
    features: ["guide", "food", "transport", "photography", "activity"],
    imageUrls: [],
    location: new GeoPoint(36.652, 44.44),
    pricePerPerson: 40,
    currency: "USD",
    startAt: inDays(18),
    endAt: inDays(18),
    capacity: 30,
    bookedCount: 28,
    cancellationPolicy: "non_refundable",
    guideLanguages: ["en", "tr"],
    transportAvailable: false,
    trending: false,
    trendingOrder: 0,
    highlighted: true,
    highlightOrder: 2,
    active: true,
  },
];

/**
 * Traveller reviews, which are what the tour scores are actually derived from.
 *
 * ⚠️ **The document id is the author's uid**, which `firestore.rules` requires
 * (one review per person per tour). The `seed-*` ids below stand in for real
 * Auth uids; replace them, or delete these documents, once real accounts exist.
 *
 * `rating` is a half-step number, 0.5–5, not an integer — the same grid the
 * nature reviews use. The card shows `rating × 2` out of 10, so 4.5 reads 9.0.
 */
const REVIEWS = {
  "gali-alibag-waterfall": [
    {
      uid: "seed-hemin",
      userName: "Hemin R.",
      rating: 4.5,
      hoursAgo: 40,
      comment:
        "The guide knew every path and the swimming stop was the best part. " +
        "Bring proper shoes — the rocks are slippery.",
    },
    {
      uid: "seed-lana",
      userName: "Lana T.",
      rating: 4.5,
      hoursAgo: 190,
      comment:
        "Two days was exactly right. Food was included and genuinely good, " +
        "and the camp site was quiet at night.",
    },
    {
      uid: "seed-omar",
      userName: "Omar F.",
      rating: 4.0,
      hoursAgo: 400,
      comment:
        "Beautiful trip. The group was a little large for the narrow paths, " +
        "but the organisation was solid.",
    },
  ],
  "gali-sherana": [
    {
      uid: "seed-shilan",
      userName: "Shilan A.",
      rating: 4.5,
      hoursAgo: 70,
      comment:
        "A proper escape. The riverside campfire in the evening made the " +
        "whole day worth it.",
    },
    {
      uid: "seed-karwan",
      userName: "Karwan B.",
      rating: 4.0,
      hoursAgo: 260,
      comment:
        "Relaxed pace and a friendly guide. One day is enough to see it, " +
        "but I would happily stay two.",
    },
  ],
  // Korek deliberately has none, so the "No reviews yet" state on a real card
  // can be checked against live data rather than only in a unit test.
};

function hoursAgo(hours) {
  return new Date(Date.now() - hours * 60 * 60 * 1000);
}

async function main() {
  for (const { id, ...data } of TOURS) {
    await db
      .collection("tours")
      .doc(id)
      .set(
        {
          ...data,
          id,
          source: "manual",
          createdBy: "seed-script",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    console.log(`seeded tours/${id}`);
  }

  let reviewCount = 0;
  for (const [tourId, reviews] of Object.entries(REVIEWS)) {
    for (const { uid, userName, rating, comment, hoursAgo: age } of reviews) {
      const createdAt = hoursAgo(age);
      await db
        .collection("tours")
        .doc(tourId)
        .collection("reviews")
        .doc(uid)
        .set({
          id: uid,
          userId: uid,
          userName,
          rating,
          comment,
          status: "published",
          source: "manual",
          createdBy: "seed-script",
          createdAt,
          updatedAt: createdAt,
        });
      reviewCount += 1;
      console.log(`seeded tours/${tourId}/reviews/${uid}`);
    }
  }

  console.log(
    `\nDone — ${TOURS.length} tours and ${reviewCount} reviews written.` +
      "\nThe scores appear once syncTourReviewAggregates has run; deploy the" +
      "\nfunctions if the cards still show no rating.",
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
