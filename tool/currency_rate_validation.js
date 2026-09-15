/**
 * Pure validation and shaping for `currency_rates/latest`.
 *
 * Deliberately has **no Firebase import and no I/O** — every rule below is
 * arithmetic on plain values, so `tool/test/currency_rate_validation.test.js`
 * can exercise the zero/negative/absurd cases without a project, a network, or
 * a chance of touching production.
 *
 * `tool/update_currency_rate.js` is the only caller.
 *
 * ## Why a band and not just "> 0"
 *
 * A positive number is not the same as a sensible one, and the realistic
 * failure here is a typo, not an attack: `1` instead of `1310` would make a
 * $120 hotel read as "≈ IQD 120", and `131000` would make it "≈ IQD 15.7m".
 * Both are positive, both are finite, and both would be drawn on a card with a
 * perfectly correct "IQD" label — the UI has no way to know the number is
 * wrong. The band is the only place that can catch it.
 *
 * The bands are wide on purpose. They are a typo guard, not a market opinion:
 * anything a real quote could plausibly be must pass.
 */

'use strict';

/** The currency every rate is quoted against. Always present in `rates` at 1. */
const BASE = 'USD';

/**
 * Plausible ranges for "units of this currency per one USD".
 *
 * * **IQD** — the dinar is pegged to the dollar and has traded around
 *   1,300–1,320 for years. 500–5,000 leaves room for a real repeg (the 2023
 *   revaluation moved it by ~10%) while still catching 1, 13 and 131000.
 * * **EUR** — 0.5–2.0 spans every level EUR/USD has held in the euro's
 *   lifetime, with margin.
 */
const SENSIBLE_BANDS = {
  IQD: { min: 500, max: 5000 },
  EUR: { min: 0.5, max: 2 },
};

/** How old `updatedAt` may get before the tool calls the rate stale. */
const STALE_AFTER_DAYS = 7;

/**
 * Checks one currency's rate.
 *
 * Returns `{ ok: true }` or `{ ok: false, reason, outOfBand }`. `outOfBand` is
 * true only for the "positive and finite but implausible" case, which is the
 * one an explicit `--force` may override — a zero, a negative or a non-number
 * can never be right and is never forceable.
 */
function validateRate(code, value, { force = false } = {}) {
  if (typeof code !== 'string' || !/^[A-Z]{3}$/.test(code)) {
    return { ok: false, reason: `"${code}" is not a 3-letter ISO currency code` };
  }

  if (typeof value !== 'number') {
    return {
      ok: false,
      reason: `${code} rate must be a number, got ${typeof value} (${JSON.stringify(value)})`,
    };
  }
  if (Number.isNaN(value)) return { ok: false, reason: `${code} rate is NaN` };
  if (!Number.isFinite(value)) {
    return { ok: false, reason: `${code} rate is not finite (${value})` };
  }
  if (value === 0) {
    // Not merely implausible: CurrencyRates.convert treats a non-positive
    // `from` rate as unusable and returns null, so a zero would silently stop
    // every conversion out of that currency.
    return { ok: false, reason: `${code} rate is zero — a zero rate converts nothing` };
  }
  if (value < 0) {
    return { ok: false, reason: `${code} rate is negative (${value})` };
  }

  if (code === BASE && value !== 1) {
    return {
      ok: false,
      reason: `${BASE} is the base currency and must be exactly 1, got ${value}`,
    };
  }

  const band = SENSIBLE_BANDS[code];
  if (band && (value < band.min || value > band.max)) {
    return {
      ok: false,
      outOfBand: true,
      reason:
        `${code} rate ${value} is outside the plausible range ` +
        `${band.min}–${band.max} per 1 ${BASE}. If this is genuinely correct, ` +
        `re-run with --force.`,
      forced: force,
    };
  }

  return { ok: true };
}

/**
 * Merges explicit updates into the existing `rates` map.
 *
 * **Only the currencies named are touched.** Everything already in the
 * document is carried through untouched, so updating IQD can never silently
 * drop EUR — and no second copy of a rate is ever introduced, because this
 * writes back the same single `rates` map the schema defines.
 *
 * Throws on any invalid entry rather than writing a partial update.
 */
function buildRatesUpdate(existingRates, updates, { force = false } = {}) {
  const current = { ...(existingRates || {}) };
  const applied = [];

  for (const [rawCode, value] of Object.entries(updates || {})) {
    const code = String(rawCode).toUpperCase();
    const result = validateRate(code, value, { force });

    if (!result.ok) {
      // An out-of-band value is the only kind --force may wave through.
      if (!(result.outOfBand && force)) throw new Error(result.reason);
    }

    applied.push({
      code,
      from: current[code] === undefined ? null : current[code],
      to: value,
      forced: Boolean(result.outOfBand && force),
    });
    current[code] = value;
  }

  if (applied.length === 0) {
    throw new Error('No rate was supplied. This tool never invents or fetches one.');
  }

  // The base must always be present at 1 so the cross-rate arithmetic in
  // CurrencyRates.convert needs no special case (DATA_MODEL.md).
  if (current[BASE] !== 1) current[BASE] = 1;

  return { rates: current, applied };
}

/** Whole days between two dates, or null when the date is unknown. */
function ageInDays(updatedAt, now = new Date()) {
  if (!(updatedAt instanceof Date) || Number.isNaN(updatedAt.getTime())) return null;
  return Math.floor((now.getTime() - updatedAt.getTime()) / 86400000);
}

/** "29 days old (STALE)" / "today" / "never updated". */
function describeAge(updatedAt, now = new Date()) {
  const days = ageInDays(updatedAt, now);
  if (days === null) return 'never updated — an undated rate is worse than no rate';
  const label = days === 0 ? 'today' : days === 1 ? '1 day old' : `${days} days old`;
  return days >= STALE_AFTER_DAYS ? `${label} (STALE)` : label;
}

module.exports = {
  BASE,
  SENSIBLE_BANDS,
  STALE_AFTER_DAYS,
  validateRate,
  buildRatesUpdate,
  ageInDays,
  describeAge,
};
