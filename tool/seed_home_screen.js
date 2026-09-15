/**
 * Seeds `featured/*` — the home screen's carousel.
 *
 * The same slides are duplicated as `bundledFeatured()` in
 * `lib/services/featured_service.dart`, which is what preview mode serves
 * before Firebase exists. Keep the two in sync.
 *
 * ## Every slide must point at a document that actually exists
 *
 * `referenceId` is not decoration: it is what Explore opens. A slide naming a
 * document that is not in the live collection is a dead front-page card, and
 * `validate()` below refuses to write one. That is the whole reason this
 * script now reads the target collections back before committing.
 *
 * **Rewritten 2026-09-15** after the launch-readiness audit found three of the
 * four original slides were placeholder content:
 *
 * * `greenwheels-rentals` (car) — no such car, and no such rental company.
 *   The live companies are ABC Cars and Paradise Rent A Car.
 * * `astra-ebl-ist` (flight) — the `flights` collection is empty, and flights
 *   are release-gated as Coming Soon. **Do not add a flight slide back until
 *   there is real inventory**; a front-page card for a product the app does
 *   not sell is worse than one fewer slide.
 * * `moraine-lake` (tour) — no such tour, and Moraine Lake is in Banff,
 *   Canada. It must never ship as a Kurdistan destination.
 *
 * The three that remain are copied from live documents: one nature spot and
 * the two tours whose own `highlighted` flag already marks them feature-worthy.
 * Titles, subtitles and locations are the documents' own localized values —
 * nothing here is authored.
 *
 * ## No ratings
 *
 * Slides are seeded WITHOUT `rating`. The referenced documents carry no rating
 * aggregate: those are server-owned, derived from the reviews subcollections by
 * a Cloud Function that is not deployed. A hand-typed 4.8 on the front page is
 * the same fabrication `seed_explore_nature.js`, `seed_explore_tours.js` and
 * `seed_hotels.js` all already refuse to write. `FeaturedItem.rating` is
 * nullable and the card hides the star pill when it is absent, so this renders
 * correctly rather than drawing a zero.
 *
 * ## What this no longer writes
 *
 * It used to also seed `nature_spots/rawanduz-canyon`, using the OLD flat
 * schema — `name` as a plain string, a hand-typed `rating`, `distanceLabel`.
 * The live document has since moved to locale maps with server-owned
 * aggregates, so re-running that would have corrupted it. That document is
 * owned by `tool/seed_explore_nature.js`; this script only references it.
 *
 * ⚠️ `imageUrl` is left empty on every slide. Upload the photos to Firebase
 * Storage first, then paste their download URLs in below (or set them from the
 * admin panel). With no URL the card falls back to the brand colour rather
 * than showing a broken image.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     node tool/seed_home_screen.js
 *
 * Pass --prune to also DELETE featured documents that are not listed here.
 * That is how the three placeholder slides were removed; without it the script
 * only adds and updates.
 */

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

/** Which collection each `type` points into. Mirrors `FeaturedType`. */
const COLLECTION_FOR_TYPE = {
  nature_spot: "nature_spots",
  hotel: "hotels",
  car: "cars",
  tour: "tours",
  flight: "flights",
};

/**
 * Titles and subtitles are locale maps so switching language costs no extra
 * read. A missing locale falls back to `en` in the app.
 *
 * Every string below is copied from the referenced live document
 * (`name`, `locationLabel`); the trailing category word is the app's own
 * existing carousel copy.
 */
const FEATURED = [
  {
    id: "rawanduz-canyon",
    type: "nature_spot",
    referenceId: "rawanduz-canyon",
    title: {
      en: "Rawanduz Canyon",
      ku: "دەربەندی ڕەواندز",
      ar: "وادي راوندوز",
    },
    subtitle: {
      en: "Erbil  •  Nature escape",
      ku: "هەولێر  •  گەشتی سروشتی",
      ar: "أربيل  •  رحلة طبيعية",
    },
    imageUrl: "",
    order: 1,
  },
  {
    // tours/gali-alibag-waterfall — highlighted: true in its own document.
    id: "gali-alibag-waterfall",
    type: "tour",
    referenceId: "gali-alibag-waterfall",
    title: {
      en: "Gali Alibag Waterfall",
      ku: "ئاوشاری گەلی عەلی بەگ",
      ar: "شلال كلي علي بك",
    },
    subtitle: {
      en: "Rawanduz, Erbil  •  Guided tour",
      ku: "ڕەواندز، هەولێر  •  گەشتی ڕێبەرایەتیکراو",
      ar: "راوندوز، أربيل  •  جولة بمرشد",
    },
    imageUrl: "",
    order: 2,
  },
  {
    // tours/korek-mountain-day — highlighted: true in its own document.
    id: "korek-mountain-day",
    type: "tour",
    referenceId: "korek-mountain-day",
    title: {
      en: "Korek Mountain Day Trip",
      ku: "گەشتی ڕۆژانەی چیای کۆڕەک",
      ar: "رحلة يوم إلى جبل كورك",
    },
    subtitle: {
      en: "Rawanduz, Erbil  •  Guided tour",
      ku: "ڕەواندز، هەولێر  •  گەشتی ڕێبەرایەتیکراو",
      ar: "راوندوز، أربيل  •  جولة بمرشد",
    },
    imageUrl: "",
    order: 3,
  },
];

/**
 * Refuses to write a slide the app could not honour.
 *
 * Shape first, then the reference itself — one `get()` per slide against the
 * collection its `type` names. A dead reference is the exact defect this
 * rewrite exists to remove, so it fails the whole run rather than warning.
 */
async function validate() {
  const seen = new Set();
  for (const item of FEATURED) {
    const at = `featured/${item.id}`;
    const collection = COLLECTION_FOR_TYPE[item.type];
    if (!collection) {
      throw new Error(
        `${at} has unsupported type "${item.type}". One of ` +
          `${Object.keys(COLLECTION_FOR_TYPE).join(" | ")}.`
      );
    }
    if (typeof item.referenceId !== "string" || !item.referenceId) {
      throw new Error(`${at} has no referenceId`);
    }
    if (seen.has(item.order)) throw new Error(`${at} reuses order ${item.order}`);
    seen.add(item.order);
    for (const field of ["title", "subtitle"]) {
      const value = item[field];
      if (!value || typeof value.en !== "string" || !value.en.trim()) {
        throw new Error(`${at} has no English ${field}`);
      }
    }
    if ("rating" in item) {
      // See the header: no aggregate exists to back one.
      throw new Error(`${at} carries a rating; none of the referenced documents has one`);
    }

    const target = await db.collection(collection).doc(item.referenceId).get();
    if (!target.exists) {
      throw new Error(
        `${at} references ${collection}/${item.referenceId}, which does not ` +
          `exist. A featured slide must point at a real document — see the ` +
          `header for the three placeholder slides this check was added for.`
      );
    }
    if (target.data().active === false) {
      throw new Error(
        `${at} references ${collection}/${item.referenceId}, which is inactive. ` +
          `A retired document must not be on the front page.`
      );
    }
    console.log(`  ✓ ${at} → ${collection}/${item.referenceId}`);
  }
}

async function main() {
  const prune = process.argv.includes("--prune");

  console.log("Verifying every featured reference resolves…");
  await validate();

  const envelope = {
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    source: "manual",
    createdBy: "seed-script",
  };

  const batch = db.batch();
  const keep = new Set(FEATURED.map((item) => item.id));

  for (const item of FEATURED) {
    const { id, ...data } = item;
    batch.set(db.collection("featured").doc(id), {
      ...data,
      ...envelope,
      id,
      // Only active slides appear in the carousel; this is the flag the
      // admin panel toggles to pull something off the front page.
      active: true,
    });
  }

  let pruned = 0;
  if (prune) {
    const existing = await db.collection("featured").get();
    for (const doc of existing.docs) {
      if (keep.has(doc.id)) continue;
      console.log(`  – deleting featured/${doc.id}`);
      batch.delete(doc.ref);
      pruned++;
    }
  }

  await batch.commit();

  console.log(
    `Seeded ${FEATURED.length} featured slides` +
      (prune ? `, deleted ${pruned}.` : ". Re-run with --prune to delete others.")
  );
  console.log(
    "Reminder: every featured slide still has an empty imageUrl — upload the " +
      "photos to Storage and set the URLs before calling this page done."
  );
}

main().catch((error) => {
  console.error(error.message ?? error);
  process.exit(1);
});
