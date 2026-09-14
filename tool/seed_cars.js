/**
 * Seeds `cars` and `rental_locations` (DATA_MODEL.md).
 *
 * Reads `tool/cars_seed.json`, generated from `PreviewCarRentalService` by
 * `tool/export_cars.dart`, so the preview fallback and Firestore cannot drift.
 *
 *   flutter test tool/export_cars.dart
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node tool/seed_cars.js
 *
 * ## Price and currency
 *
 * Each vehicle stores ONE authoritative price with the currency its supplier
 * quotes: `pricePerDay` + `currencyCode`. There are deliberately no
 * `priceUSD` / `priceIQD` fields — two stored prices are two things to keep in
 * step, and the moment a rate moves they disagree. Conversion to the user's
 * display currency happens at render time through `CurrencyRatesService`.
 *
 * Only USD and IQD are accepted, matching `firestore.rules`. Every current
 * preview vehicle is quoted in USD, and **no IQD price is fabricated**.
 *
 * ## What this does NOT write
 *
 * * **`conditions`** — deposit, damage excess, fuel policy, cancellation
 *   deadline, minimum driver age and required documents are contractual terms
 *   a renter acts on. The preview data leaves them empty on purpose and
 *   nothing here invents them; the Rental Conditions card stays hidden.
 * * **`imageUrls`** is empty, matching hotels/nature_spots/tours.
 *
 * Uses `{ merge: true }`, so re-running never deletes a field an admin added.
 */

const fs = require("fs");
const path = require("path");
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  GeoPoint,
} = require("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const SOURCE = path.join(__dirname, "cars_seed.json");

/** The only currencies the app can display. Mirrors firestore.rules. */
const SUPPORTED_CURRENCIES = ["USD", "IQD"];

/** Fields the old schema had that must never be written again. */
const RETIRED_FIELDS = ["rentalCompany", "companyTag", "location"];

function validateCar(id, car) {
  const at = `cars/${id}`;
  if (!car || typeof car !== "object") throw new Error(`${at} is not an object`);

  if (!car.name || typeof car.name.en !== "string" || !car.name.en.trim()) {
    throw new Error(`${at} has no English name`);
  }
  if (!car.company || typeof car.company.id !== "string") {
    throw new Error(`${at} has no company.id`);
  }
  if (!car.company.name || typeof car.company.name.en !== "string") {
    throw new Error(`${at} has no English company name`);
  }

  // The currency contract, enforced here as well as in the rules so a bad
  // value is named against its vehicle rather than surfacing as a generic
  // permission error.
  if (!SUPPORTED_CURRENCIES.includes(car.currencyCode)) {
    throw new Error(
      `${at} has unsupported currencyCode "${car.currencyCode}". ` +
        `Only ${SUPPORTED_CURRENCIES.join(" and ")} are supported.`
    );
  }
  if (typeof car.pricePerDay !== "number" || car.pricePerDay < 0) {
    throw new Error(`${at} has a bad pricePerDay: ${car.pricePerDay}`);
  }
  for (const dup of ["priceUSD", "priceIQD"]) {
    if (dup in car) {
      throw new Error(
        `${at} carries "${dup}". A vehicle stores ONE authoritative price ` +
          `with its own currency; duplicates drift the moment a rate moves.`
      );
    }
  }

  for (const flag of ["featured", "active"]) {
    if (typeof car[flag] !== "boolean") {
      throw new Error(`${at} has a non-boolean ${flag}: ${car[flag]}`);
    }
  }
  if (typeof car.locationId !== "string" || !car.locationId) {
    throw new Error(`${at} has no locationId`);
  }
  for (const retired of RETIRED_FIELDS) {
    if (retired in car) {
      throw new Error(
        `${at} carries the retired field "${retired}" — the schema was ` +
          `revised 2026-09-13. Re-run: flutter test tool/export_cars.dart`
      );
    }
  }
  if ("conditions" in car) {
    throw new Error(
      `${at} carries conditions. Supplier terms are contractual and are never ` +
        `invented for review data (SEED_DATA.md).`
    );
  }

  for (const [i, e] of (car.extras || []).entries()) {
    const where = `${at} extras[${i}]`;
    if (typeof e.id !== "string" || !e.id) throw new Error(`${where} has no id`);
    if (typeof e.pricePerDay !== "number" || e.pricePerDay < 0) {
      throw new Error(`${where} has a bad pricePerDay`);
    }
    if (!["checkbox", "quantity"].includes(e.selection)) {
      throw new Error(`${where} has a bad selection: ${e.selection}`);
    }
  }
}

function validateBranch(id, branch) {
  const at = `rental_locations/${id}`;
  if (!branch.name || typeof branch.name.en !== "string") {
    throw new Error(`${at} has no English name`);
  }
  if (typeof branch.active !== "boolean") {
    throw new Error(`${at} has a non-boolean active`);
  }
  const loc = branch.location;
  if (!loc || !Number.isFinite(loc.lat) || !Number.isFinite(loc.lng)) {
    throw new Error(`${at} has a malformed location`);
  }
}

async function main() {
  if (!fs.existsSync(SOURCE)) {
    throw new Error(
      `${SOURCE} is missing. Generate it first:\n` +
        `  flutter test tool/export_cars.dart`
    );
  }

  const raw = JSON.parse(fs.readFileSync(SOURCE, "utf8"));
  const cars = raw.cars || {};
  const branches = raw.rental_locations || {};
  if (Object.keys(cars).length === 0) throw new Error("no cars in the source");

  // Validate everything before writing anything.
  for (const [id, car] of Object.entries(cars)) validateCar(id, car);
  for (const [id, branch] of Object.entries(branches)) validateBranch(id, branch);

  // Every car must point at a branch that exists, or its pickup row is blank.
  for (const [id, car] of Object.entries(cars)) {
    if (!(car.locationId in branches)) {
      throw new Error(
        `cars/${id} points at unknown branch "${car.locationId}"`
      );
    }
  }

  for (const [id, branch] of Object.entries(branches)) {
    await db
      .collection("rental_locations")
      .doc(id)
      .set(
        {
          ...branch,
          location: new GeoPoint(branch.location.lat, branch.location.lng),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    console.log(`seeded rental_locations/${id}`);
  }

  const byCurrency = {};
  for (const [id, car] of Object.entries(cars)) {
    await db
      .collection("cars")
      .doc(id)
      .set({ ...car, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    byCurrency[car.currencyCode] = (byCurrency[car.currencyCode] || 0) + 1;
    console.log(
      `seeded cars/${id} (${car.pricePerDay} ${car.currencyCode}` +
        `${car.featured ? ", featured" : ""})`
    );
  }

  const summary = Object.entries(byCurrency)
    .map(([code, n]) => `${n} ${code}`)
    .join(", ");
  console.log(
    `\nDone — ${Object.keys(cars).length} cars (${summary}), ` +
      `${Object.keys(branches).length} branches.`
  );
  console.log(
    "No conditions and no imageUrls were written; both are intentional."
  );
}

main().catch((error) => {
  console.error(`\nSeed aborted: ${error.message}`);
  process.exit(1);
});
