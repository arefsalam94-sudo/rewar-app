const { onCall, HttpsError } = require("firebase-functions/v2/https");
const dataset = require("./data/airports.json");

const MAX_QUERY_LENGTH = 64;
const DEFAULT_LIMIT = 12;
const MAX_LIMIT = 20;
const WINDOW_MS = 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 60;
const callers = new Map();

function normalize(value) {
  return String(value || "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("en")
    .trim();
}

const airports = dataset.airports.map((airport) => ({
  ...airport,
  search: normalize([
    airport.iataCode,
    airport.icaoCode,
    airport.name,
    airport.city,
    airport.country,
    airport.countryCode,
    airport.keywords,
  ].join(" ")),
  normalizedIata: normalize(airport.iataCode),
  normalizedIcao: normalize(airport.icaoCode),
  normalizedName: normalize(airport.name),
  normalizedCity: normalize(airport.city),
  normalizedCountry: normalize(airport.country),
}));

function score(airport, query) {
  if (airport.normalizedIata === query) return 0;
  if (airport.normalizedIcao === query) return 2;
  if (airport.normalizedIata.startsWith(query)) return 5;
  if (airport.normalizedCity === query) return 10;
  if (airport.normalizedCity.startsWith(query)) return 15;
  if (airport.normalizedName.startsWith(query)) return 20;
  if (airport.normalizedCountry === query) return 25;
  if (airport.normalizedCountry.startsWith(query)) return 30;
  const position = airport.search.indexOf(query);
  return position < 0 ? Number.POSITIVE_INFINITY : 40 + Math.min(position, 20);
}

function searchAirportData(rawQuery, rawLimit = DEFAULT_LIMIT) {
  const query = normalize(rawQuery);
  if (query.length < 2) return [];
  const limit = Math.max(1, Math.min(MAX_LIMIT, Number(rawLimit) || DEFAULT_LIMIT));
  const ranked = [];
  for (const airport of airports) {
    const relevance = score(airport, query);
    if (!Number.isFinite(relevance)) continue;
    ranked.push({
      airport,
      relevance: relevance + (airport.scheduled ? 0 : 8) +
        (airport.type === "large_airport" ? 0 :
          airport.type === "medium_airport" ? 2 : 5),
    });
  }
  ranked.sort((left, right) =>
    left.relevance - right.relevance ||
    left.airport.name.localeCompare(right.airport.name));

  const seen = new Set();
  const results = [];
  for (const { airport } of ranked) {
    if (seen.has(airport.iataCode)) continue;
    seen.add(airport.iataCode);
    results.push({
      id: airport.id,
      iataCode: airport.iataCode,
      icaoCode: airport.icaoCode,
      name: airport.name,
      city: airport.city,
      country: airport.country,
      countryCode: airport.countryCode,
      latitude: airport.latitude,
      longitude: airport.longitude,
    });
    if (results.length >= limit) break;
  }
  return results;
}

function enforceRateLimit(request) {
  const key = request.rawRequest.ip || "unknown";
  const now = Date.now();
  const state = callers.get(key);
  if (!state || now - state.startedAt >= WINDOW_MS) {
    callers.set(key, { startedAt: now, count: 1 });
    return;
  }
  state.count += 1;
  if (state.count > MAX_REQUESTS_PER_WINDOW) {
    throw new HttpsError("resource-exhausted", "Too many airport searches.");
  }
}

exports.searchAirports = onCall(
  {
    region: "us-central1",
    enforceAppCheck: false,
    memory: "512MiB",
    timeoutSeconds: 15,
    maxInstances: 10,
  },
  (request) => {
    enforceRateLimit(request);
    const query = request.data && request.data.query;
    if (typeof query !== "string" || query.trim().length < 2 ||
        query.length > MAX_QUERY_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        "Airport query must contain between 2 and 64 characters.",
      );
    }
    return { airports: searchAirportData(query, request.data.limit) };
  },
);

exports._test = { normalize, searchAirportData };
