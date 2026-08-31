const assert = require("node:assert/strict");
const test = require("node:test");
const { _test } = require("../airport-search");

test("finds an airport by IATA code", () => {
  const results = _test.searchAirportData("EBL");
  assert.equal(results[0].iataCode, "EBL");
  assert.match(results[0].name, /Erbil/i);
});

test("finds airports by city and country", () => {
  assert.ok(_test.searchAirportData("Istanbul").some((item) => item.iataCode === "IST"));
  assert.ok(_test.searchAirportData("Iraq").some((item) => item.countryCode === "IQ"));
});

test("normalizes accented search text and enforces result limits", () => {
  assert.equal(_test.normalize("  Montr\u00e9al "), "montreal");
  assert.equal(_test.searchAirportData("United", 3).length, 3);
});

test("does not return duplicate IATA codes", () => {
  const results = _test.searchAirportData("London", 20);
  assert.equal(new Set(results.map((item) => item.iataCode)).size, results.length);
});
