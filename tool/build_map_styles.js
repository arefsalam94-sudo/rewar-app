#!/usr/bin/env node
/**
 * Builds the app's two canonical basemap styles:
 *
 *   assets/map_styles/app_light.json  — App Light Map
 *   assets/map_styles/app_dark.json   — App Dark Map
 *
 * Both are derived from ONE upstream structure, the vendored OpenFreeMap
 * "liberty" style (`tool/map_styles/liberty.upstream.json`), so Light and Dark
 * always have an identical layer list, road hierarchy, label hierarchy, filters
 * and zoom stops. Only the *paint* differs between them — which is exactly the
 * guarantee the design system asks for: one map, two palettes.
 *
 * What is kept untouched from upstream, on purpose:
 *   - `sources` (the same `tiles.openfreemap.org/planet` vector tiles and the
 *     `ne2sr` Natural Earth raster), `glyphs`, `sprite`
 *   - every `source-layer`, `filter`, `layout`, `minzoom`/`maxzoom`
 *   - layer order, i.e. the whole road and label hierarchy
 *   - the sprite-driven layers (`fill-pattern`, one-way arrows, road shields)
 *
 * What this script rewrites: colours only.
 *
 * Attribution is *added*, not removed: upstream leaves it to the TileJSON, and
 * because we now ship the style ourselves we declare it explicitly on both
 * sources so the OpenFreeMap / OpenMapTiles / OpenStreetMap credits travel with
 * our own files.
 *
 * Run:  node tool/build_map_styles.js
 * Then: flutter analyze && flutter test test/theme/app_map_style_test.dart
 */

'use strict';

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const upstreamPath = path.join(root, 'tool', 'map_styles', 'liberty.upstream.json');
const outDir = path.join(root, 'assets', 'map_styles');

// ---------------------------------------------------------------------------
// Attribution — legally required, declared on our own style files.
// ---------------------------------------------------------------------------

const VECTOR_ATTRIBUTION =
  '<a href="https://openfreemap.org" target="_blank">OpenFreeMap</a> ' +
  '<a href="https://www.openmaptiles.org/" target="_blank">&copy; OpenMapTiles</a> ' +
  'Data from <a href="https://www.openstreetmap.org/copyright" target="_blank">&copy; OpenStreetMap contributors</a>';

const RASTER_ATTRIBUTION =
  '<a href="https://www.naturalearthdata.com/" target="_blank">Natural Earth</a>';

// ---------------------------------------------------------------------------
// The two palettes.
//
// Every key exists in both, so a layer is never coloured in one theme and left
// upstream-coloured in the other. Values marked "canonical" are verbatim design
// tokens from `DESIGN_LIGHT F.md` / `DESIGN_DARK F.md`; the rest are the map
// palette agreed for this design-system change.
// ---------------------------------------------------------------------------

const LIGHT = {
  name: 'Kurdistan Paradise — App Light Map',

  // Land
  background: '#F1F3E9',
  residentialLow: 'rgba(228,233,217,0.85)', // z9
  residentialHigh: 'rgba(236,240,226,0.55)', // z12

  // Green
  park: '#D7E8D2',
  parkOutline: '#CFE2CC',
  wood: '#CBE0C5',
  woodOpacity: 0.6,
  grass: '#D7E8D2',
  grassOpacity: 0.5,
  pitch: '#DCE7D4',
  cemetery: '#D9E4CE',
  school: '#E9EBD5',
  hospital: '#EDE2E2',
  ice: '#E2EEEB',
  sand: '#EFE6CC',

  // Water
  water: '#C9E5DF',
  waterway: '#BFDCD7',

  // Aeroway
  aerowayFill: '#E5E7DA',
  aerowayLine: '#ECEEE2',

  // Roads — fill over casing, four visible tiers
  highwayFill: '#E0B462',
  highwayCasing: '#CFA24C',
  majorFill: '#EBCB83',
  majorCasing: '#E3C077',
  minorFill: '#E6D7B7',
  minorCasing: '#DDD6C7',
  serviceFill: '#EAE0C8',
  serviceCasing: '#DDD6C7',
  pathFill: '#E9E2CE',
  pathCasing: '#DDD6C7',
  rail: '#C6C9BB',

  // Built form
  building: '#E5E6D9',
  buildingOutlineLow: 'rgba(214,217,201,0.32)', // z13
  buildingOutlineHigh: '#D6D9C9', // z14

  // Boundaries
  boundarySoft: '#B3BDB2',
  boundaryStrong: '#8D998F',

  // Labels — canonical text tokens
  labelPrimary: '#0E2A44', // canonical `action` / `text-link`
  labelSecondary: '#3E4945', // canonical `on-surface-variant` / `text-secondary`
  labelMuted: '#6E7A74', // canonical `outline` / `text-hint`
  labelHalo: 'rgba(241,243,233,0.85)', // the land colour
  waterLabel: '#0E2A44',
  waterLabelSecondary: '#3E4945',
  waterHalo: 'rgba(201,229,223,0.80)', // the water colour
  poi: '#3E4945',
  poiTransit: '#0E2A44',

  // Natural Earth shaded relief: upstream treatment, unchanged.
  reliefOpacity: ['interpolate', ['exponential', 1.5], ['zoom'], 0, 0.6, 6, 0.1],
  reliefExtra: {},
};

const DARK = {
  name: 'Kurdistan Paradise — App Dark Map',

  // Land
  background: '#0C1F1F', // canonical `background-gradient-top` / `glass-tint`
  residentialLow: 'rgba(16,28,29,0.85)', // z9
  residentialHigh: 'rgba(18,34,34,0.60)', // z12

  // Green
  park: '#123328',
  parkOutline: '#163B2F',
  wood: '#123328',
  woodOpacity: 0.6,
  grass: '#163B2F',
  grassOpacity: 0.5,
  pitch: '#16302A',
  cemetery: '#142C26',
  school: '#1C2C22',
  hospital: '#2A2224',
  ice: '#1E3335',
  sand: '#232A23',

  // Water. #062C32 (canonical `background-gradient-bottom`) is the family this
  // is built from; the fill takes the lighter member so a lake actually reads
  // against the land, and rivers take one step lighter again so they read as
  // lines rather than disappearing into the lake colour.
  water: '#08353A',
  waterway: '#0B4048',

  // Aeroway
  aerowayFill: '#16282A',
  aerowayLine: '#1E3234',

  // Roads
  highwayFill: '#687F77',
  highwayCasing: '#617871',
  majorFill: '#49645F',
  majorCasing: '#405B57',
  minorFill: '#2D4340',
  minorCasing: '#263C3A',
  serviceFill: '#263C3A',
  serviceCasing: '#223634',
  pathFill: '#2A3E3B',
  pathCasing: '#223634',
  rail: '#35504C',

  // Built form
  building: '#16292B',
  buildingOutlineLow: 'rgba(31,54,53,0.32)', // z13
  buildingOutlineHigh: '#1F3635', // z14

  // Boundaries
  boundarySoft: '#304542',
  boundaryStrong: '#3D5551',

  // Labels
  labelPrimary: '#F1F5F3',
  labelSecondary: '#9AADA7',
  labelMuted: '#8FA39D',
  labelHalo: 'rgba(12,31,31,0.80)', // the land colour
  waterLabel: '#9AADA7',
  waterLabelSecondary: '#8FA39D',
  waterHalo: 'rgba(6,44,50,0.85)', // the water colour
  poi: '#8FA39D',
  poiTransit: '#9AADA7',

  // Natural Earth shaded relief is a warm, bright image. Left at upstream
  // strength it would read as brown haze over a deep-teal map, so in Dark it is
  // desaturated and dimmed rather than dropped — the source stays, the terrain
  // shape stays, the colour cast goes.
  reliefOpacity: ['interpolate', ['exponential', 1.5], ['zoom'], 0, 0.25, 6, 0.05],
  reliefExtra: {
    'raster-saturation': -1,
    'raster-brightness-max': 0.45,
  },
};

// ---------------------------------------------------------------------------
// Layer id → paint patch.
//
// One table, both themes: `patch(p)` receives the palette and returns the paint
// properties to merge over upstream's. A layer absent from this table keeps its
// upstream paint verbatim (that is the sprite-driven set: wetland pattern,
// pedestrian-area pattern, one-way arrows, road shields).
// ---------------------------------------------------------------------------

const fill = (color, extra) => (p) => ({ 'fill-color': color(p), ...(extra || {}) });
const line = (color, extra) => (p) => ({ 'line-color': color(p), ...(extra || {}) });

/** The three road variants MapLibre draws separately: in tunnels, at grade, on bridges. */
const roadVariants = (suffix, color, extra) => {
  const table = {};
  for (const prefix of ['tunnel', 'road', 'bridge']) {
    table[`${prefix}_${suffix}`] = line(color, extra);
  }
  return table;
};

const PAINT = {
  // ---- Land ------------------------------------------------------------
  background: (p) => ({ 'background-color': p.background }),
  natural_earth: (p) => ({ 'raster-opacity': p.reliefOpacity, ...p.reliefExtra }),
  landuse_residential: (p) => ({
    'fill-color': [
      'interpolate',
      ['linear'],
      ['zoom'],
      9,
      p.residentialLow,
      12,
      p.residentialHigh,
    ],
  }),

  // ---- Green and landcover --------------------------------------------
  // Park drops upstream's 0.7 fill-opacity so the palette value is the value
  // that actually lands on screen.
  park: fill((p) => p.park, { 'fill-opacity': 1, 'fill-outline-color': null }),
  park_outline: line((p) => p.parkOutline),
  landcover_wood: (p) => ({ 'fill-color': p.wood, 'fill-opacity': p.woodOpacity }),
  landcover_grass: (p) => ({ 'fill-color': p.grass, 'fill-opacity': p.grassOpacity }),
  landcover_ice: fill((p) => p.ice),
  landcover_sand: fill((p) => p.sand),
  landuse_pitch: fill((p) => p.pitch),
  landuse_track: fill((p) => p.pitch),
  landuse_cemetery: fill((p) => p.cemetery),
  landuse_hospital: fill((p) => p.hospital),
  landuse_school: fill((p) => p.school),

  // ---- Water -----------------------------------------------------------
  water: fill((p) => p.water),
  waterway_tunnel: line((p) => p.waterway),
  waterway_river: line((p) => p.waterway),
  waterway_other: line((p) => p.waterway),

  // ---- Aeroway ---------------------------------------------------------
  aeroway_fill: fill((p) => p.aerowayFill),
  aeroway_runway: line((p) => p.aerowayLine),
  aeroway_taxiway: line((p) => p.aerowayLine),

  // ---- Roads: casings (drawn under the fills) --------------------------
  ...roadVariants('motorway_casing', (p) => p.highwayCasing),
  ...roadVariants('motorway_link_casing', (p) => p.highwayCasing),
  ...roadVariants('trunk_primary_casing', (p) => p.majorCasing),
  ...roadVariants('secondary_tertiary_casing', (p) => p.majorCasing),
  ...roadVariants('link_casing', (p) => p.majorCasing),
  ...roadVariants('service_track_casing', (p) => p.serviceCasing),
  tunnel_street_casing: line((p) => p.minorCasing),
  road_minor_casing: line((p) => p.minorCasing),
  bridge_street_casing: line((p) => p.minorCasing),
  bridge_path_pedestrian_casing: line((p) => p.pathCasing),

  // ---- Roads: fills (the four tiers the user must tell apart) ----------
  // Upstream gives `road_motorway` a zoom-interpolated colour; a flat value
  // keeps the highway tier reading the same at every zoom.
  ...roadVariants('motorway', (p) => p.highwayFill),
  ...roadVariants('motorway_link', (p) => p.highwayFill),
  ...roadVariants('trunk_primary', (p) => p.majorFill),
  ...roadVariants('secondary_tertiary', (p) => p.majorFill),
  ...roadVariants('link', (p) => p.majorFill),
  ...roadVariants('service_track', (p) => p.serviceFill),
  ...roadVariants('path_pedestrian', (p) => p.pathFill),
  tunnel_minor: line((p) => p.minorFill),
  road_minor: line((p) => p.minorFill),
  bridge_street: line((p) => p.minorFill),

  // ---- Rail ------------------------------------------------------------
  ...roadVariants('major_rail', (p) => p.rail),
  ...roadVariants('major_rail_hatching', (p) => p.rail),
  ...roadVariants('transit_rail', (p) => p.rail),
  ...roadVariants('transit_rail_hatching', (p) => p.rail),

  // ---- Built form ------------------------------------------------------
  building: (p) => ({
    'fill-color': p.building,
    'fill-outline-color': [
      'interpolate',
      ['linear'],
      ['zoom'],
      13,
      p.buildingOutlineLow,
      14,
      p.buildingOutlineHigh,
    ],
  }),
  'building-3d': (p) => ({ 'fill-extrusion-color': p.building }),

  // ---- Boundaries ------------------------------------------------------
  boundary_3: line((p) => p.boundarySoft),
  boundary_2: line((p) => p.boundaryStrong),
  boundary_disputed: line((p) => p.boundaryStrong),

  // ---- Labels ----------------------------------------------------------
  // Water names carry the water colour as their halo, which is what makes them
  // read as water without spending a palette entry on a third label colour.
  waterway_line_label: (p) => ({
    'text-color': p.waterLabelSecondary,
    'text-halo-color': p.waterHalo,
  }),
  water_name_point_label: (p) => ({
    'text-color': p.waterLabel,
    'text-halo-color': p.waterHalo,
  }),
  water_name_line_label: (p) => ({
    'text-color': p.waterLabel,
    'text-halo-color': p.waterHalo,
  }),

  poi_r20: (p) => ({ 'text-color': p.poi, 'text-halo-color': p.labelHalo }),
  poi_r7: (p) => ({ 'text-color': p.poi, 'text-halo-color': p.labelHalo }),
  poi_r1: (p) => ({ 'text-color': p.poi, 'text-halo-color': p.labelHalo }),
  poi_transit: (p) => ({ 'text-color': p.poiTransit, 'text-halo-color': p.labelHalo }),
  airport: (p) => ({ 'text-color': p.labelSecondary, 'text-halo-color': p.labelHalo }),

  // Upstream leaves the two road-name layers with a halo width but no halo
  // colour, i.e. no halo at all. On a dark basemap that is the difference
  // between a legible street name and a smear, so both get the land halo.
  'highway-name-path': (p) => ({
    'text-color': p.labelMuted,
    'text-halo-color': p.labelHalo,
  }),
  'highway-name-minor': (p) => ({
    'text-color': p.labelMuted,
    'text-halo-color': p.labelHalo,
  }),
  'highway-name-major': (p) => ({
    'text-color': p.labelSecondary,
    'text-halo-color': p.labelHalo,
  }),

  // Places: settlements and countries are primary, the supporting ranks muted.
  label_other: (p) => ({ 'text-color': p.labelSecondary, 'text-halo-color': p.labelHalo }),
  label_state: (p) => ({ 'text-color': p.labelSecondary, 'text-halo-color': p.labelHalo }),
  label_village: (p) => ({ 'text-color': p.labelPrimary, 'text-halo-color': p.labelHalo }),
  label_town: (p) => ({ 'text-color': p.labelPrimary, 'text-halo-color': p.labelHalo }),
  label_city: (p) => ({ 'text-color': p.labelPrimary, 'text-halo-color': p.labelHalo }),
  label_city_capital: (p) => ({
    'text-color': p.labelPrimary,
    'text-halo-color': p.labelHalo,
  }),
  label_country_3: (p) => ({ 'text-color': p.labelPrimary, 'text-halo-color': p.labelHalo }),
  label_country_2: (p) => ({ 'text-color': p.labelPrimary, 'text-halo-color': p.labelHalo }),
  label_country_1: (p) => ({ 'text-color': p.labelPrimary, 'text-halo-color': p.labelHalo }),
};

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------

function build(upstream, palette) {
  const style = JSON.parse(JSON.stringify(upstream));

  style.name = palette.name;
  style.metadata = {
    'kpt:generated-by': 'tool/build_map_styles.js',
    'kpt:derived-from': 'OpenFreeMap liberty (tool/map_styles/liberty.upstream.json)',
    'kpt:note': 'Paint only. Sources, glyphs, sprite, source-layers, filters and layer order are upstream.',
  };

  style.sources.openmaptiles.attribution = VECTOR_ATTRIBUTION;
  style.sources.ne2_shaded.attribution = RASTER_ATTRIBUTION;

  const unused = new Set(Object.keys(PAINT));
  for (const layer of style.layers) {
    const patch = PAINT[layer.id];
    if (!patch) continue;
    unused.delete(layer.id);
    layer.paint = { ...(layer.paint || {}), ...patch(palette) };
    // A patch may null out an upstream property it is replacing wholesale.
    for (const [key, value] of Object.entries(layer.paint)) {
      if (value === null) delete layer.paint[key];
    }
  }

  if (unused.size > 0) {
    throw new Error(
      `Paint table names layers that do not exist upstream: ${[...unused].join(', ')}`,
    );
  }
  return style;
}

function main() {
  const upstream = JSON.parse(fs.readFileSync(upstreamPath, 'utf8'));
  fs.mkdirSync(outDir, { recursive: true });

  for (const [file, palette] of [
    ['app_light.json', LIGHT],
    ['app_dark.json', DARK],
  ]) {
    const style = build(upstream, palette);
    fs.writeFileSync(path.join(outDir, file), `${JSON.stringify(style, null, 2)}\n`, 'utf8');
    console.log(`wrote assets/map_styles/${file} — ${style.layers.length} layers`);
  }
}

main();
