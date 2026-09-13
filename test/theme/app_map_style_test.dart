import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_map_style.dart';

/// Guards the two canonical basemaps: `AppMapStyle` is the only place a map
/// style is chosen, and the App Light Map and App Dark Map are one structure
/// with two palettes.
void main() {
  Map<String, dynamic> loadStyle(String assetPath) {
    final file = File(assetPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$assetPath is missing — run `node tool/build_map_styles.js`',
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  late Map<String, dynamic> light;
  late Map<String, dynamic> dark;
  late Map<String, dynamic> upstream;

  setUpAll(() {
    light = loadStyle(AppMapStyle.lightStyleAsset);
    dark = loadStyle(AppMapStyle.darkStyleAsset);
    upstream =
        jsonDecode(
              File('tool/map_styles/liberty.upstream.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  List<Map<String, dynamic>> layersOf(Map<String, dynamic> style) =>
      (style['layers'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> layer(Map<String, dynamic> style, String id) =>
      layersOf(style).firstWhere((l) => l['id'] == id);

  group('AppMapStyle resolver', () {
    test('resolves a bundled app style per brightness', () {
      expect(
        AppMapStyle.forBrightness(Brightness.light),
        AppMapStyle.lightStyleAsset,
      );
      expect(
        AppMapStyle.forBrightness(Brightness.dark),
        AppMapStyle.darkStyleAsset,
      );
      // Asset paths, not provider URLs: the styles are the app's own.
      for (final style in [
        AppMapStyle.lightStyleAsset,
        AppMapStyle.darkStyleAsset,
      ]) {
        expect(style, startsWith('assets/map_styles/'));
        expect(style, isNot(startsWith('http')));
      }
    });

    testWidgets('follows the ambient theme brightness', (tester) async {
      late String resolved;
      Future<void> pumpWith(ThemeData theme) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                resolved = AppMapStyle.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // MaterialApp lerps between themes; settle so the switch has landed.
        await tester.pumpAndSettle();
      }

      await pumpWith(ThemeData(brightness: Brightness.light));
      expect(resolved, AppMapStyle.lightStyleAsset);

      await pumpWith(ThemeData(brightness: Brightness.dark));
      expect(resolved, AppMapStyle.darkStyleAsset);
    });

    test('both styles are registered as Flutter assets', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/map_styles/'));
    });
  });

  group('style documents', () {
    test('are valid MapLibre style v8 documents', () {
      for (final style in [light, dark]) {
        expect(style['version'], 8);
        expect(style['glyphs'], upstream['glyphs']);
        expect(style['sprite'], upstream['sprite']);
      }
    });

    test('keep the upstream data sources untouched', () {
      for (final style in [light, dark]) {
        final sources = style['sources'] as Map<String, dynamic>;
        final vector = sources['openmaptiles'] as Map<String, dynamic>;
        final raster = sources['ne2_shaded'] as Map<String, dynamic>;
        expect(vector['type'], 'vector');
        expect(vector['url'], 'https://tiles.openfreemap.org/planet');
        expect(
          (raster['tiles'] as List).first,
          'https://tiles.openfreemap.org/natural_earth/ne2sr/{z}/{x}/{y}.png',
        );
      }
    });

    test('carry the required attribution', () {
      for (final style in [light, dark]) {
        final sources = style['sources'] as Map<String, dynamic>;
        final vector = sources['openmaptiles'] as Map<String, dynamic>;
        final attribution = vector['attribution'] as String;
        expect(attribution, contains('OpenFreeMap'));
        expect(attribution, contains('OpenMapTiles'));
        expect(attribution, contains('OpenStreetMap'));
        expect(
          (sources['ne2_shaded'] as Map<String, dynamic>)['attribution'],
          contains('Natural Earth'),
        );
      }
    });

    test('Light and Dark are one structure with two palettes', () {
      final lightLayers = layersOf(light);
      final darkLayers = layersOf(dark);
      final upstreamLayers = layersOf(upstream);

      expect(lightLayers.length, upstreamLayers.length);
      expect(darkLayers.length, upstreamLayers.length);

      for (var i = 0; i < upstreamLayers.length; i++) {
        final up = upstreamLayers[i];
        for (final themed in [lightLayers[i], darkLayers[i]]) {
          // Same layer, same data, same geometry rules — only paint differs.
          expect(themed['id'], up['id']);
          expect(themed['type'], up['type']);
          expect(themed['source'], up['source']);
          expect(themed['source-layer'], up['source-layer']);
          expect(jsonEncode(themed['filter']), jsonEncode(up['filter']));
          expect(jsonEncode(themed['layout']), jsonEncode(up['layout']));
          expect(themed['minzoom'], up['minzoom']);
          expect(themed['maxzoom'], up['maxzoom']);
        }
      }
    });

    test('road hierarchy is four distinct tiers in both themes', () {
      const tiers = [
        'road_minor',
        'road_secondary_tertiary',
        'road_trunk_primary',
        'road_motorway',
      ];
      for (final style in [light, dark]) {
        final colors = <String>{
          for (final id in tiers)
            (layer(style, id)['paint'] as Map)['line-color'] as String,
        };
        // Minor is its own tier; major roads share one value; the motorway
        // tier is distinct from both. Three distinct values across four layers.
        expect(colors.length, 3);
        for (final id in tiers) {
          final casingId = id == 'road_minor'
              ? 'road_minor_casing'
              : '${id}_casing';
          final fill = (layer(style, id)['paint'] as Map)['line-color'];
          final casing = (layer(style, casingId)['paint'] as Map)['line-color'];
          expect(
            fill,
            isNot(casing),
            reason: '$id must stay readable against its casing',
          );
        }
      }
    });

    test('label hierarchy separates primary from secondary places', () {
      for (final style in [light, dark]) {
        final city = (layer(style, 'label_city')['paint'] as Map)['text-color'];
        final state =
            (layer(style, 'label_state')['paint'] as Map)['text-color'];
        expect(city, isNot(state));
        // Every place label carries a halo, so names stay legible over roads.
        for (final id in [
          'label_city',
          'label_town',
          'label_village',
          'label_state',
          'highway-name-major',
          'highway-name-minor',
        ]) {
          expect(
            (layer(style, id)['paint'] as Map)['text-halo-color'],
            isNotNull,
            reason: '$id needs a halo',
          );
        }
      }
    });

    test('Light uses the canonical warm-ivory land and navy labels', () {
      expect(
        (layer(light, 'background')['paint'] as Map)['background-color'],
        '#F1F3E9',
      );
      expect((layer(light, 'water')['paint'] as Map)['fill-color'], '#C9E5DF');
      expect((layer(light, 'park')['paint'] as Map)['fill-color'], '#D7E8D2');
      expect(
        (layer(light, 'label_city')['paint'] as Map)['text-color'],
        '#0E2A44',
      );
      expect(
        (layer(light, 'label_state')['paint'] as Map)['text-color'],
        '#3E4945',
      );
    });

    test('Dark uses the canonical deep charcoal-teal land, not black', () {
      expect(
        (layer(dark, 'background')['paint'] as Map)['background-color'],
        '#0C1F1F',
      );
      expect((layer(dark, 'water')['paint'] as Map)['fill-color'], '#08353A');
      expect((layer(dark, 'park')['paint'] as Map)['fill-color'], '#123328');
      expect(
        (layer(dark, 'label_city')['paint'] as Map)['text-color'],
        '#F1F5F3',
      );
      expect(
        (layer(dark, 'label_state')['paint'] as Map)['text-color'],
        '#9AADA7',
      );
    });

    test('mint is reserved for app UI — it never paints the basemap', () {
      for (final style in [light, dark]) {
        expect(jsonEncode(style).toUpperCase(), isNot(contains('2AF598')));
      }
    });

    test('no layer is left on an upstream colour in one theme only', () {
      final lightLayers = layersOf(light);
      final darkLayers = layersOf(dark);
      // The sprite-driven layers carry no colour of their own; every other
      // layer must be painted differently in Light and Dark.
      const spriteDriven = {
        'landcover_wetland',
        'road_area_pattern',
        'road_one_way_arrow',
        'road_one_way_arrow_opposite',
        'highway-shield-non-us',
        'highway-shield-us-interstate',
        'road_shield_us',
      };
      for (var i = 0; i < lightLayers.length; i++) {
        final id = lightLayers[i]['id'] as String;
        if (spriteDriven.contains(id)) continue;
        expect(
          jsonEncode(lightLayers[i]['paint']),
          isNot(jsonEncode(darkLayers[i]['paint'])),
          reason: '$id is painted identically in both themes',
        );
      }
    });
  });
}
