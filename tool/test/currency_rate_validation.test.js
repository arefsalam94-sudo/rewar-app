// Validation rules for the manual currency-rate tool.
//
// Pure — no Firebase, no network, no project. Run from the repo root:
//
//   node --test tool/test/*.test.js
//
// The cases that matter are not the happy ones. `currency_rates/latest` is the
// single document behind every converted price in Hotels, Cars, Tours and
// Flights, and the realistic way it gets corrupted is a typo at a keyboard,
// not an attacker: `1` instead of `1310` renders a $120 hotel as "≈ IQD 120",
// with a perfectly correct IQD label on a number that is wrong by 1300x.
//
// CommonJS, like every other script under tool/.
'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const {
  BASE,
  SENSIBLE_BANDS,
  STALE_AFTER_DAYS,
  validateRate,
  buildRatesUpdate,
  ageInDays,
  describeAge,
} = require('../currency_rate_validation');

describe('validateRate — valid rates', () => {
  test('accepts the current pegged IQD rate', () => {
    assert.equal(validateRate('IQD', 1310).ok, true);
  });

  test('accepts plausible IQD rates across the band', () => {
    for (const rate of [500, 1200, 1310, 1320, 1470, 5000]) {
      assert.equal(validateRate('IQD', rate).ok, true, `${rate} should pass`);
    }
  });

  test('accepts a plausible EUR rate', () => {
    assert.equal(validateRate('EUR', 0.92).ok, true);
    assert.equal(validateRate('EUR', 1.15).ok, true);
  });

  test('accepts a non-integer rate', () => {
    assert.equal(validateRate('IQD', 1309.75).ok, true);
  });

  test('accepts the base at exactly 1', () => {
    assert.equal(validateRate(BASE, 1).ok, true);
  });
});

describe('validateRate — zero', () => {
  test('rejects zero', () => {
    const result = validateRate('IQD', 0);
    assert.equal(result.ok, false);
    assert.match(result.reason, /zero/);
  });

  test('a zero is NOT forceable', () => {
    // CurrencyRates.convert treats a non-positive `from` rate as unusable and
    // returns null, so a zero would silently stop every conversion out of it.
    assert.equal(validateRate('IQD', 0, { force: true }).ok, false);
  });

  test('rejects negative zero', () => {
    assert.equal(validateRate('IQD', -0).ok, false);
  });
});

describe('validateRate — negative', () => {
  for (const rate of [-1, -0.5, -1310, -Number.MIN_VALUE]) {
    test(`rejects ${rate}`, () => {
      const result = validateRate('IQD', rate);
      assert.equal(result.ok, false);
      assert.match(result.reason, /negative|zero/);
    });
  }

  test('a negative is NOT forceable', () => {
    assert.equal(validateRate('IQD', -1310, { force: true }).ok, false);
  });
});

describe('validateRate — invalid, non-numeric and hostile', () => {
  for (const [label, value] of [
    ['a string', '1310'],
    ['an empty string', ''],
    ['null', null],
    ['undefined', undefined],
    ['a boolean', true],
    ['an object', { rate: 1310 }],
    ['an array', [1310]],
  ]) {
    test(`rejects ${label}`, () => {
      const result = validateRate('IQD', value);
      assert.equal(result.ok, false);
      assert.match(result.reason, /must be a number/);
    });
  }

  test('rejects NaN', () => {
    const result = validateRate('IQD', Number.NaN);
    assert.equal(result.ok, false);
    assert.match(result.reason, /NaN/);
  });

  test('rejects Infinity and -Infinity', () => {
    assert.equal(validateRate('IQD', Number.POSITIVE_INFINITY).ok, false);
    assert.equal(validateRate('IQD', Number.NEGATIVE_INFINITY).ok, false);
  });

  test('rejects a malformed currency code', () => {
    for (const code of ['iqd', 'IQ', 'IQDX', '', '123', null]) {
      assert.equal(validateRate(code, 1310).ok, false, `${code} should fail`);
    }
  });

  test('rejects a base that is not exactly 1', () => {
    const result = validateRate(BASE, 1.01);
    assert.equal(result.ok, false);
    assert.match(result.reason, /must be exactly 1/);
  });
});

describe('validateRate — the plausibility band catches typos', () => {
  test('rejects 1 — the "dropped the thousands" typo', () => {
    // This is the dangerous one: positive, finite, and it would render a $120
    // hotel as "≈ IQD 120" with a correct label on a 1300x-wrong number.
    const result = validateRate('IQD', 1);
    assert.equal(result.ok, false);
    assert.equal(result.outOfBand, true);
  });

  test('rejects 131000 — the extra-zeros typo', () => {
    const result = validateRate('IQD', 131000);
    assert.equal(result.ok, false);
    assert.equal(result.outOfBand, true);
  });

  test('rejects an EUR rate entered as if it were IQD', () => {
    assert.equal(validateRate('EUR', 1310).ok, false);
  });

  test('band edges are inclusive', () => {
    assert.equal(validateRate('IQD', SENSIBLE_BANDS.IQD.min).ok, true);
    assert.equal(validateRate('IQD', SENSIBLE_BANDS.IQD.max).ok, true);
    assert.equal(validateRate('IQD', SENSIBLE_BANDS.IQD.min - 0.01).ok, false);
    assert.equal(validateRate('IQD', SENSIBLE_BANDS.IQD.max + 0.01).ok, false);
  });

  test('the reason names --force, so the operator knows the way out', () => {
    assert.match(validateRate('IQD', 1).reason, /--force/);
  });

  test('an unbanded currency is accepted when positive', () => {
    // Only IQD and EUR have bands; a new currency is not blocked outright.
    assert.equal(validateRate('GBP', 0.79).ok, true);
  });
});

describe('buildRatesUpdate — merging', () => {
  const existing = { USD: 1, IQD: 1310, EUR: 0.92 };

  test('updates only the currency named', () => {
    const { rates } = buildRatesUpdate(existing, { IQD: 1320 });
    assert.deepEqual(rates, { USD: 1, IQD: 1320, EUR: 0.92 });
  });

  test('never drops a currency it was not asked about', () => {
    const { rates } = buildRatesUpdate(existing, { IQD: 1320 });
    assert.equal(rates.EUR, 0.92);
  });

  test('reports the before and after of each change', () => {
    const { applied } = buildRatesUpdate(existing, { IQD: 1320 });
    assert.deepEqual(applied, [
      { code: 'IQD', from: 1310, to: 1320, forced: false },
    ]);
  });

  test('keeps the base pinned at 1 even if it is missing', () => {
    const { rates } = buildRatesUpdate({ IQD: 1310 }, { IQD: 1320 });
    assert.equal(rates[BASE], 1);
  });

  test('adds no duplicate or parallel rate field', () => {
    const { rates } = buildRatesUpdate(existing, { IQD: 1320 });
    assert.deepEqual(Object.keys(rates).sort(), ['EUR', 'IQD', 'USD']);
  });

  test('lower-cases a code into canonical form', () => {
    const { rates } = buildRatesUpdate(existing, { iqd: 1320 });
    assert.equal(rates.IQD, 1320);
  });

  test('refuses an empty update rather than writing a no-op', () => {
    assert.throws(
      () => buildRatesUpdate(existing, {}),
      /never invents or fetches/
    );
  });

  test('throws on a zero without writing anything', () => {
    assert.throws(() => buildRatesUpdate(existing, { IQD: 0 }), /zero/);
  });

  test('throws on a negative', () => {
    assert.throws(() => buildRatesUpdate(existing, { IQD: -1310 }), /negative/);
  });

  test('throws on a non-number', () => {
    assert.throws(() => buildRatesUpdate(existing, { IQD: '1310' }), /must be a number/);
  });

  test('a multi-currency update is all-or-nothing', () => {
    // The bad EUR must stop the good IQD from being applied too.
    assert.throws(() => buildRatesUpdate(existing, { IQD: 1320, EUR: 0 }), /zero/);
  });

  test('--force waves through an out-of-band value and marks it', () => {
    const { rates, applied } = buildRatesUpdate(existing, { IQD: 1 }, { force: true });
    assert.equal(rates.IQD, 1);
    assert.equal(applied[0].forced, true);
  });

  test('--force does NOT wave through a zero or a negative', () => {
    assert.throws(() => buildRatesUpdate(existing, { IQD: 0 }, { force: true }), /zero/);
    assert.throws(() => buildRatesUpdate(existing, { IQD: -5 }, { force: true }), /negative/);
  });
});

describe('staleness reporting', () => {
  const now = new Date('2026-09-16T00:00:00Z');

  test('counts whole days', () => {
    assert.equal(ageInDays(new Date('2026-09-16T00:00:00Z'), now), 0);
    assert.equal(ageInDays(new Date('2026-09-15T00:00:00Z'), now), 1);
    assert.equal(ageInDays(new Date('2026-08-17T20:41:56Z'), now), 29);
  });

  test('flags the live document as stale', () => {
    // The real updatedAt on rewar-app-1c10e at the time of writing.
    const described = describeAge(new Date('2026-08-17T20:41:56Z'), now);
    assert.match(described, /29 days old/);
    assert.match(described, /STALE/);
  });

  test('a fresh rate is not flagged', () => {
    assert.equal(describeAge(now, now), 'today');
    assert.doesNotMatch(describeAge(new Date('2026-09-15T00:00:00Z'), now), /STALE/);
  });

  test(`the threshold is ${STALE_AFTER_DAYS} days`, () => {
    const justUnder = new Date(now.getTime() - (STALE_AFTER_DAYS - 1) * 86400000);
    const atLimit = new Date(now.getTime() - STALE_AFTER_DAYS * 86400000);
    assert.doesNotMatch(describeAge(justUnder, now), /STALE/);
    assert.match(describeAge(atLimit, now), /STALE/);
  });

  test('a missing date says so rather than implying freshness', () => {
    assert.match(describeAge(null, now), /never updated/);
    assert.match(describeAge(undefined, now), /never updated/);
    assert.match(describeAge(new Date('nonsense'), now), /never updated/);
  });
});
