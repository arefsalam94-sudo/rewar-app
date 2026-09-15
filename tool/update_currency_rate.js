/**
 * Inspects and updates `currency_rates/latest` — the one document behind every
 * converted price in the app.
 *
 * A **manual stand-in** for the scheduled Cloud Function described in
 * `ROADMAP.md` / `tool/seed_currency_rates.js`, which needs Blaze. It changes
 * nothing about how prices are computed: the app still reads the same single
 * document, through the same `CurrencyRatesService`, and every converted figure
 * stays marked `≈`.
 *
 * ## What this tool will not do
 *
 * * **It never invents or fetches a rate.** There is no provider call and no
 *   default value anywhere in this file. You pass the number, or nothing is
 *   written. A tool that quietly fetched a rate would be a scheduled job with
 *   no schedule, no logging and no review.
 * * **It never writes without `--confirm`.** Without it you get a dry run
 *   printing the exact before/after, and the document is untouched.
 * * **It adds no fields and removes none.** The schema in `DATA_MODEL.md`
 *   (`base`, `rates`, `updatedAt`) is preserved exactly, along with the
 *   envelope the seeder wrote (`id`, `source`, `createdBy`, `createdAt`).
 *   There is no second copy of any rate — the single `rates` map is merged and
 *   written back.
 *
 * ## Why this is an Admin SDK script and not a screen
 *
 * `firestore.rules` allows `create, update, delete` on `currency_rates` only
 * when `isAdmin()`, and **this tool does not change that**. It runs on a
 * service-account key, which bypasses rules server-side — no capability is
 * added to any Flutter client, and no signed-in user gains one. Write access
 * here is a financial control, not an editorial one: a client that could write
 * this document could make a $500 tour read as $5 (`SECURITY.md` 5,
 * `DATA_MODEL.md` → currency_rates).
 *
 * ## Usage
 *
 *   # look, change nothing
 *   GOOGLE_APPLICATION_CREDENTIALS=secrets/<key>.json \
 *     node tool/update_currency_rate.js --inspect
 *
 *   # dry run — prints the diff, writes nothing
 *   GOOGLE_APPLICATION_CREDENTIALS=secrets/<key>.json \
 *     node tool/update_currency_rate.js --iqd 1310
 *
 *   # actually write
 *   GOOGLE_APPLICATION_CREDENTIALS=secrets/<key>.json \
 *     node tool/update_currency_rate.js --iqd 1310 --confirm
 *
 * Flags: `--inspect`, `--iqd <n>`, `--eur <n>`, `--confirm`, `--force`
 * (`--force` only ever overrides the plausibility band — never a zero, a
 * negative or a non-number).
 *
 * Keep `CurrencyRatesService.bundledRates` in sync when the real rate moves
 * far from the bundled illustrative one; that constant is what preview mode
 * serves before Firebase exists.
 */

'use strict';

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const {
  BASE,
  buildRatesUpdate,
  describeAge,
  STALE_AFTER_DAYS,
} = require('./currency_rate_validation');

const COLLECTION = 'currency_rates';
const DOC_ID = 'latest';

function parseArgs(argv) {
  const args = { updates: {}, inspect: false, confirm: false, force: false };
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    switch (token) {
      case '--inspect':
        args.inspect = true;
        break;
      case '--confirm':
        args.confirm = true;
        break;
      case '--force':
        args.force = true;
        break;
      case '--iqd':
      case '--eur': {
        const code = token.slice(2).toUpperCase();
        const raw = argv[++i];
        if (raw === undefined) throw new Error(`${token} needs a value`);
        // Number() rather than parseFloat: parseFloat('13abc') is 13, which is
        // exactly the kind of quiet coercion a money tool must not do.
        const value = Number(raw);
        if (raw.trim() === '' || Number.isNaN(value)) {
          throw new Error(`${token} value "${raw}" is not a number`);
        }
        args.updates[code] = value;
        break;
      }
      default:
        throw new Error(`Unknown argument "${token}"`);
    }
  }
  return args;
}

function toDate(value) {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function printCurrent(data, projectId) {
  console.log(`project        : ${projectId}`);
  console.log(`document       : ${COLLECTION}/${DOC_ID}`);
  if (!data) {
    console.log('state          : DOES NOT EXIST');
    return null;
  }
  const updatedAt = toDate(data.updatedAt);
  console.log(`base           : ${data.base}`);
  console.log(`rates          : ${JSON.stringify(data.rates)}`);
  console.log(
    `updatedAt      : ${updatedAt ? updatedAt.toISOString() : 'missing'}` +
      `  — ${describeAge(updatedAt)}`
  );
  const created = toDate(data.createdAt);
  console.log(`createdAt      : ${created ? created.toISOString() : 'missing'}`);
  console.log(`source         : ${data.source ?? '—'}`);
  return updatedAt;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  initializeApp({ credential: applicationDefault() });
  const db = getFirestore();
  const projectId =
    process.env.GOOGLE_CLOUD_PROJECT ||
    require(process.env.GOOGLE_APPLICATION_CREDENTIALS).project_id;

  const ref = db.collection(COLLECTION).doc(DOC_ID);
  const snapshot = await ref.get();
  const current = snapshot.exists ? snapshot.data() : null;

  console.log('--- current ---');
  const updatedAt = printCurrent(current, projectId);

  const hasUpdates = Object.keys(args.updates).length > 0;

  if (args.inspect || !hasUpdates) {
    if (!hasUpdates && !args.inspect) {
      console.log(
        '\nNo rate supplied, so nothing to do. This tool never invents one.\n' +
          'Pass --iqd <rate> (add --confirm to write), or --inspect to look.'
      );
    }
    if (updatedAt && describeAge(updatedAt).includes('STALE')) {
      console.log(
        `\n⚠️  Older than ${STALE_AFTER_DAYS} days. Converted prices are still ` +
          `LABELLED correctly —\n    the app never relabels a currency it could ` +
          `not convert — but the magnitude\n    is drifting. Every "≈" figure in ` +
          `Hotels, Cars, Tours and Flights uses this.`
      );
    }
    return;
  }

  if (!current) {
    throw new Error(
      `${COLLECTION}/${DOC_ID} does not exist. Seed it first with ` +
        `tool/seed_currency_rates.js; this tool updates, it does not create.`
    );
  }

  // Throws on zero, negative, non-numeric or (unless --force) implausible.
  const { rates, applied } = buildRatesUpdate(current.rates, args.updates, {
    force: args.force,
  });

  console.log('\n--- proposed ---');
  for (const change of applied) {
    const from = change.from === null ? '(absent)' : change.from;
    console.log(
      `  ${change.code}: ${from} → ${change.to}` +
        (change.forced ? '   ⚠️ OUT OF BAND, forced' : '')
    );
  }
  console.log(`  rates after : ${JSON.stringify(rates)}`);
  console.log(`  updatedAt   : will be set to the server timestamp`);
  console.log(`  base        : ${BASE} (unchanged)`);

  if (!args.confirm) {
    console.log(
      '\nDRY RUN — nothing was written.\n' +
        'Re-run the same command with --confirm to apply it to ' +
        `${projectId}.`
    );
    return;
  }

  // `update` rather than `set`: it fails if the document vanished between the
  // read above and now, and it cannot drop a field this tool does not mention
  // (createdAt, source, createdBy, id all survive untouched).
  await ref.update({
    base: current.base || BASE,
    rates,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const after = await ref.get();
  console.log('\n--- written ---');
  printCurrent(after.data(), projectId);
  console.log(
    '\n✅ Updated. These rates remain INDICATIVE: a charge is settled by the ' +
      'payment\n   processor in the operator’s own currency, never at a rate ' +
      'this app stored.'
  );
}

main().catch((error) => {
  console.error(`\n✗ ${error.message ?? error}`);
  process.exit(1);
});
