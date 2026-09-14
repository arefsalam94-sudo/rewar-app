/**
 * Seeds the ten `help_topics` documents (DATA_MODEL.md → help_topics).
 *
 * Reads `tool/help_topics_seed.json`, which is **generated** from
 * `lib/models/help_faq.dart` by `tool/export_help_topics.dart`. Nothing is
 * retyped here, so the Q&A the app falls back to and the Q&A in Firestore
 * cannot drift. If the bundled content changes:
 *
 *   dart run tool/export_help_topics.dart
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node tool/seed_help_topics.js
 *
 * Schema written per document:
 *   order    number   ascending display order (1..10)
 *   active   boolean  false hides a topic without deleting it
 *   content  map      { en: { questions: [{question, answer}] } }
 *
 * Only `en` is written — that is all the bundled content has. A missing locale
 * falls back to `en` in the app, the same rule as legal_documents.
 *
 * `contact_support` is seeded with an EMPTY questions array on purpose: it is
 * a route to a human, not a Q&A topic, and the screen draws its "Coming soon"
 * state from exactly that emptiness. Seeding filler there would change the
 * screen's behaviour, which this script has no business doing.
 *
 * Uses `{ merge: true }`, so re-running never deletes a field an admin added
 * through the panel; it only rewrites what this script owns.
 *
 * Usage:
 *   1. Download a service-account key (Firebase Console → Project Settings →
 *      Service accounts). Do NOT commit it — .gitignore covers it.
 *   2. cd functions && npm install && cd ..
 *   3. dart run tool/export_help_topics.dart
 *   4. GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *        node tool/seed_help_topics.js
 */

const fs = require("fs");
const path = require("path");
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const SOURCE = path.join(__dirname, "help_topics_seed.json");
const COLLECTION = "help_topics";

/** The ten ids fixed in lib/models/help_topic.dart (HelpTopic.docId). */
const EXPECTED_IDS = [
  "account_signin",
  "bookings_confirmation",
  "payments_refunds",
  "cancellation_changes",
  "flights",
  "stays_hotels",
  "car_rental",
  "tours_nature",
  "safety_travel_info",
  "contact_support",
];

/**
 * Validates one document before it is written.
 *
 * A seed script that writes malformed data is worse than one that refuses to
 * run: the screen would render a blank topic in production and nobody would
 * know why.
 */
function validate(id, topic) {
  const at = `${COLLECTION}/${id}`;
  if (!topic || typeof topic !== "object") {
    throw new Error(`${at} is not an object`);
  }
  if (!Number.isInteger(topic.order) || topic.order < 1) {
    throw new Error(`${at} has a bad order: ${topic.order}`);
  }
  if (typeof topic.active !== "boolean") {
    throw new Error(`${at} has a non-boolean active`);
  }
  if (!topic.content || typeof topic.content !== "object") {
    throw new Error(`${at} has no content map`);
  }
  const en = topic.content.en;
  if (!en || !Array.isArray(en.questions)) {
    throw new Error(`${at} has no content.en.questions array`);
  }
  for (const [locale, body] of Object.entries(topic.content)) {
    if (!["en", "ku", "ar"].includes(locale)) {
      throw new Error(`${at} has an unsupported locale "${locale}"`);
    }
    if (!Array.isArray(body.questions)) {
      throw new Error(`${at}/${locale} has no questions array`);
    }
    body.questions.forEach((qa, i) => {
      const where = `${at}/${locale} question ${i}`;
      if (typeof qa.question !== "string" || qa.question.trim() === "") {
        throw new Error(`${where} has no question text`);
      }
      if (typeof qa.answer !== "string" || qa.answer.trim() === "") {
        throw new Error(`${where} has no answer text`);
      }
    });
  }
}

async function main() {
  if (!fs.existsSync(SOURCE)) {
    throw new Error(
      `${SOURCE} is missing. Generate it first:\n` +
        `  dart run tool/export_help_topics.dart`
    );
  }

  const raw = JSON.parse(fs.readFileSync(SOURCE, "utf8"));
  const topics = Object.fromEntries(
    Object.entries(raw).filter(([key]) => !key.startsWith("_"))
  );
  const ids = Object.keys(topics);

  // Refuse to seed a set that does not match the app's enum. A missing id
  // means a blank row; an extra id means a document no screen will ever read.
  const missing = EXPECTED_IDS.filter((id) => !ids.includes(id));
  const extra = ids.filter((id) => !EXPECTED_IDS.includes(id));
  if (missing.length || extra.length) {
    throw new Error(
      `help topic ids do not match HelpTopic.docId.\n` +
        (missing.length ? `  missing: ${missing.join(", ")}\n` : "") +
        (extra.length ? `  unexpected: ${extra.join(", ")}\n` : "") +
        `Re-run: dart run tool/export_help_topics.dart`
    );
  }

  for (const [id, topic] of Object.entries(topics)) validate(id, topic);

  const orders = ids.map((id) => topics[id].order);
  if (new Set(orders).size !== orders.length) {
    throw new Error(`duplicate order values: ${orders.join(", ")}`);
  }

  let questionCount = 0;
  for (const id of EXPECTED_IDS) {
    const topic = topics[id];
    const n = topic.content.en.questions.length;
    questionCount += n;
    await db
      .collection(COLLECTION)
      .doc(id)
      .set(
        {
          order: topic.order,
          active: topic.active,
          content: topic.content,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    console.log(`seeded ${COLLECTION}/${id} (order ${topic.order}, ${n} Q&A)`);
  }

  console.log(
    `\nDone — ${EXPECTED_IDS.length} topics, ${questionCount} questions.`
  );
  console.log(
    "contact_support is intentionally empty; the screen draws 'Coming soon'."
  );
}

main().catch((error) => {
  console.error(`\nSeed aborted: ${error.message}`);
  process.exit(1);
});
