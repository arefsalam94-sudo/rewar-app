/**
 * Downloads the public-domain OurAirports CSV files and builds the compact
 * dataset bundled with the Firebase airport-search function.
 *
 * Run from the repository root:
 *   node tool/sync_airports.js
 */

const fs = require("fs/promises");
const path = require("path");

const AIRPORTS_URL =
  "https://davidmegginson.github.io/ourairports-data/airports.csv";
const COUNTRIES_URL =
  "https://davidmegginson.github.io/ourairports-data/countries.csv";
const OUTPUT = path.join(__dirname, "..", "functions", "data", "airports.json");

function parseCsv(text) {
  const rows = [];
  let row = [];
  let value = "";
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (quoted) {
      if (character === '"' && text[index + 1] === '"') {
        value += '"';
        index += 1;
      } else if (character === '"') {
        quoted = false;
      } else {
        value += character;
      }
    } else if (character === '"') {
      quoted = true;
    } else if (character === ",") {
      row.push(value);
      value = "";
    } else if (character === "\n") {
      row.push(value.replace(/\r$/, ""));
      rows.push(row);
      row = [];
      value = "";
    } else {
      value += character;
    }
  }
  if (value || row.length) {
    row.push(value.replace(/\r$/, ""));
    rows.push(row);
  }
  return rows;
}

function records(text) {
  const rows = parseCsv(text);
  const headers = rows.shift();
  return rows
    .filter((row) => row.length === headers.length)
    .map((row) => Object.fromEntries(headers.map((key, index) => [key, row[index]])));
}

async function download(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Download failed (${response.status}): ${url}`);
  return response.text();
}

async function main() {
  const [airportText, countryText] = await Promise.all([
    download(AIRPORTS_URL),
    download(COUNTRIES_URL),
  ]);
  const countries = new Map(
    records(countryText).map((country) => [country.code, country.name]),
  );
  const allowedTypes = new Set([
    "large_airport",
    "medium_airport",
    "small_airport",
    "seaplane_base",
  ]);
  const airports = records(airportText)
    .filter((airport) => airport.iata_code && allowedTypes.has(airport.type))
    .map((airport) => ({
      id: airport.id,
      iataCode: airport.iata_code,
      icaoCode: airport.icao_code || airport.ident || "",
      name: airport.name,
      city: airport.municipality || "",
      country: countries.get(airport.iso_country) || airport.iso_country,
      countryCode: airport.iso_country,
      latitude: Number(airport.latitude_deg),
      longitude: Number(airport.longitude_deg),
      scheduled: airport.scheduled_service === "yes",
      type: airport.type,
      keywords: airport.keywords || "",
    }))
    .sort((left, right) => left.iataCode.localeCompare(right.iataCode));

  await fs.mkdir(path.dirname(OUTPUT), { recursive: true });
  await fs.writeFile(
    OUTPUT,
    `${JSON.stringify({ source: "OurAirports", airports })}\n`,
    "utf8",
  );
  process.stdout.write(`Wrote ${airports.length} airports to ${OUTPUT}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
