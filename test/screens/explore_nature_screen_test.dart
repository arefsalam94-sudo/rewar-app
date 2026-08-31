import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_filters.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_spot.dart';
import 'package:kurdistan_paradise_travel_guide/screens/customize_filters_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/explore_nature_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/device_location_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/nature_spots_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';

void main() {
  group('NatureSpot', () {
    test('stars are derived from the 0-10 score, matching the reference', () {
      // The two scores drawn in `explore nature.jpg` both show four stars.
      expect(NatureSpot.starsForScore(8.2), 4);
      expect(NatureSpot.starsForScore(8.7), 4);
      expect(NatureSpot.starsForScore(9.8), 5);
      expect(NatureSpot.starsForScore(0), 0);
      // Clamped, so a bad admin entry cannot draw six stars.
      expect(NatureSpot.starsForScore(20), 5);
    });

    test('falls back to English when a locale is missing', () {
      const spot = NatureSpot(
        id: 'x',
        names: {'en': 'Erbil Citadel'},
        descriptions: {'en': 'Old.'},
      );
      expect(spot.name('ku'), 'Erbil Citadel');
      expect(spot.description('ar'), 'Old.');
      // No location label at all is an empty string, never a crash.
      expect(spot.locationLabel('en'), '');
    });

    test('fromMap skips a document with no name', () {
      expect(
        NatureSpot.fromMap('x', <String, dynamic>{'reviewScore': 9}),
        null,
      );
      expect(NatureSpot.fromMap('x', null), null);
    });

    test('fromMap reads locale maps, all three tag arrays and the score', () {
      final spot = NatureSpot.fromMap('erbil-citadel', <String, dynamic>{
        'name': {'en': 'Erbil Citadel', 'ku': 'قەڵای هەولێر'},
        'description': {'en': 'A historic citadel.'},
        'locationLabel': {'en': 'Erbil, Iraq'},
        'imageUrls': ['https://example.test/a.jpg', ''],
        'reviewScore': 8.7,
        'ratingCount': 876,
        'categories': ['sunset_view', 42],
        'placeTypes': ['museum'],
        'amenities': ['parking', 'cafes'],
        'nearbyStays': [
          {
            'id': 'hotel-1',
            'name': {'en': 'Nearby Hotel', 'ar': 'فندق قريب'},
            'distanceKm': 2.4,
            'reviewScore': 8.6,
          },
        ],
        'highlighted': true,
        'highlightOrder': 3,
      });

      expect(spot, isNotNull);
      expect(spot!.name('ku'), 'قەڵای هەولێر');
      expect(spot.reviewScore, 8.7);
      expect(spot.ratingCount, 876);
      // Empty strings and non-strings are dropped rather than drawn.
      expect(spot.imageUrls, ['https://example.test/a.jpg']);
      expect(spot.categories, {'sunset_view'});
      expect(spot.placeTypes, {'museum'});
      expect(spot.amenities, {'parking', 'cafes'});
      expect(spot.nearbyStays, hasLength(1));
      expect(spot.nearbyStays.single.name('ar'), 'فندق قريب');
      expect(spot.nearbyStays.single.distanceKm, 2.4);
      expect(spot.highlighted, isTrue);
      expect(spot.highlightOrder, 3);
      // No geopoint means no coordinates, which means no distance row.
      expect(spot.distanceMetersFrom(36.19, 44.0), null);
    });

    test('distance is a real great-circle measurement', () {
      const spot = NatureSpot(
        id: 'citadel',
        names: {'en': 'Erbil Citadel'},
        latitude: 36.1912,
        longitude: 44.0093,
      );
      // Sami Abdulrahman Park to the Citadel is ~1.4 km.
      final meters = spot.distanceMetersFrom(36.1901, 43.9930)!;
      expect(meters, greaterThan(1200));
      expect(meters, lessThan(1700));
    });
  });

  group('NatureFilters', () {
    const forest = NatureSpot(
      id: 'forest',
      names: {'en': 'Forest'},
      categories: {'hiking'},
      placeTypes: {'forest'},
      amenities: {'parking'},
    );

    test('an empty group is "no filter", not "match nothing"', () {
      expect(const NatureFilters().matches(forest), isTrue);
    });

    test('OR within a group', () {
      const filters = NatureFilters(placeTypes: {'forest', 'museum'});
      expect(filters.matches(forest), isTrue);
      expect(
        const NatureFilters(placeTypes: {'museum'}).matches(forest),
        false,
      );
    });

    test('AND across groups', () {
      // Matches the place type but not the amenity → excluded.
      const filters = NatureFilters(
        placeTypes: {'forest'},
        amenities: {'cafes'},
      );
      expect(filters.matches(forest), isFalse);

      const both = NatureFilters(
        placeTypes: {'forest'},
        amenities: {'parking'},
      );
      expect(both.matches(forest), isTrue);
    });

    test('the counter and Reset All cover only the Customize groups', () {
      const filters = NatureFilters(
        activities: {'hiking'},
        placeTypes: {'forest', 'lake'},
        amenities: {'parking'},
      );
      expect(filters.customizeCount, 3);

      final reset = filters.clearCustomize();
      expect(reset.customizeCount, 0);
      // The quick chips are left exactly as they were.
      expect(reset.activities, {'hiking'});
      expect(reset.isEmpty, isFalse);
    });

    test('toggling is immutable — the original is never mutated', () {
      const original = NatureFilters(placeTypes: {'forest'});
      final next = original.togglePlaceType('lake');
      expect(original.placeTypes, {'forest'});
      expect(next.placeTypes, {'forest', 'lake'});
      expect(next.togglePlaceType('lake').placeTypes, {'forest'});
    });
  });

  group('formatSpotDistance', () {
    test('switches unit and precision by magnitude', () {
      expect(formatSpotDistance(420), '420 m');
      expect(formatSpotDistance(999), '999 m');
      expect(formatSpotDistance(2500), '2.5 km');
      expect(formatSpotDistance(9949), '9.9 km');
      expect(formatSpotDistance(127400), '127 km');
    });
  });

  group('Explore Nature screen', () {
    test('both pages keep the shared background photo unblurred', () {
      expect(exploreNatureBackgroundBlurEnabled, isFalse);
    });

    testWidgets('content cards use the documented base sheen glass', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());

      final contentPanels = tester
          .widgetList<GlassPanel>(find.byType(GlassPanel))
          .toList();
      expect(contentPanels, isNotEmpty);
      expect(
        contentPanels.where((panel) => panel.borderRadius == 28),
        everyElement(
          isA<GlassPanel>().having(
            (panel) => panel.depth,
            'depth',
            GlassDepth.base,
          ),
        ),
      );
    });

    testWidgets('draws the carousel, the filters and a card per place', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());

      // Carousel slide (the highlighted spot) plus its own list card.
      expect(find.text('Rawanduz Canyon'), findsNWidgets(2));
      // 8.0, not the old hand-typed 8.2: the score is now derived by the
      // `syncNatureReviewAggregates` trigger from the three seeded reviews
      // (4.5 + 4.0 + 3.5 → mean 4.0 → 8.0), and the bundled preview data
      // matches what that function would write.
      expect(find.text('8.0'), findsNWidgets(2));

      // Filter chips.
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('Beach'), findsOneWidget);
      expect(find.text('Sunset View'), findsOneWidget);
      expect(find.text('Customize'), findsOneWidget);

      // List cards — the whole active catalog.
      expect(find.text('Sami Abdulrahman Park'), findsOneWidget);
      expect(find.text('Erbil Citadel'), findsOneWidget);
      expect(find.text('Location:'), findsNWidgets(3));
    });

    testWidgets('shows the back button in the shared position', (tester) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());
      expect(find.byType(GlassBackButton), findsOneWidget);
    });

    testWidgets('hides the Distance row when location is unavailable', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeNatureSpotsService(),
        location: const _FakeLocationService(null),
      );

      expect(find.text('Distance:'), findsNothing);
      // The rest of the card is unaffected.
      expect(find.text('Location:'), findsNWidgets(3));
    });

    testWidgets('shows the Distance row once a fix arrives', (tester) async {
      await _pumpScreen(
        tester,
        service: _FakeNatureSpotsService(),
        // Sitting in Sami Abdulrahman Park.
        location: const _FakeLocationService(DeviceLocation(36.1901, 43.9930)),
      );

      expect(find.text('Distance:'), findsNWidgets(3));
      expect(find.textContaining('from current location'), findsNWidgets(3));
    });

    testWidgets('filter chips filter in Dart, with no extra read', (
      tester,
    ) async {
      final service = _FakeNatureSpotsService();
      await _pumpScreen(tester, service: service);
      expect(service.catalogReads, 1);

      // Only the Citadel is not tagged "hiking".
      await tester.tap(find.text('Hiking'));
      await tester.pumpAndSettle();
      expect(find.text('Sami Abdulrahman Park'), findsOneWidget);
      expect(find.text('Erbil Citadel'), findsNothing);

      // Multi-select is OR: adding Sunset View widens it back out.
      await tester.tap(find.text('Sunset View'));
      await tester.pumpAndSettle();
      expect(find.text('Erbil Citadel'), findsOneWidget);

      // Tapping an active chip clears just that one.
      await tester.tap(find.text('Hiking'));
      await tester.pumpAndSettle();
      expect(find.text('Erbil Citadel'), findsOneWidget);

      // Not one extra Firestore read for any of that.
      expect(service.catalogReads, 1);
    });

    testWidgets('a filter that matches nothing offers Clear filters', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());

      // No bundled place is tagged "beach".
      await tester.tap(find.text('Beach'));
      await tester.pumpAndSettle();

      expect(find.text('No places match these filters yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Erbil Citadel'), findsOneWidget);
    });

    testWidgets('surfaces a load failure and recovers on retry', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeNatureSpotsService(failFirstList: true),
      );

      expect(
        find.text("Couldn't load places. Please try again."),
        findsOneWidget,
      );

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Sami Abdulrahman Park'), findsOneWidget);
    });

    testWidgets('an empty catalog is an empty state, not an error', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeNatureSpotsService(emptyList: true),
      );

      expect(find.text('No places match these filters yet'), findsOneWidget);
      // Nothing is filtered, so there is nothing to clear.
      expect(find.text('Clear filters'), findsNothing);
    });

    testWidgets('shows the empty carousel state without an error', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeNatureSpotsService(noHighlights: true),
      );

      expect(find.text('Nothing is highlighted yet'), findsOneWidget);
      // The list underneath still works.
      expect(find.text('Erbil Citadel'), findsOneWidget);
    });

    testWidgets('renders Kurdish copy and keeps the dots left-to-right', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeNatureSpotsService(),
        locale: const Locale('ku'),
      );

      expect(find.text('دەربەندی ڕەواندز'), findsNWidgets(2));
      expect(find.text('شوێن:'), findsNWidgets(3));

      // The page is right-to-left…
      expect(
        Directionality.of(tester.element(find.text('شوێن:').first)),
        TextDirection.rtl,
      );
      // …but a progress track is not a sentence.
      final dots = tester.widget<Row>(find.byKey(exploreNatureDotsKey));
      expect(
        Directionality.of(tester.element(find.byKey(exploreNatureDotsKey))),
        TextDirection.ltr,
      );
      expect(dots.children, isNotEmpty);
    });

    testWidgets('dark mode draws headings pure white, never a dim token', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService(), dark: true);

      final name = tester.widget<Text>(find.text('Sami Abdulrahman Park'));
      expect(name.style?.color, const Color(0xFFFFFFFF));
    });

    testWidgets('light mode draws headings in on-surface', (tester) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());

      final name = tester.widget<Text>(find.text('Sami Abdulrahman Park'));
      expect(name.style?.color, AppTheme.lightColorScheme.onSurface);
    });

    testWidgets('every filter chip meets the 48dp touch target', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());

      for (final label in ['Hiking', 'Beach', 'Sunset View', 'Customize']) {
        final inkWell = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(inkWell.first).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('Customize Filters screen', () {
    testWidgets('Customize opens it, and applying filters the list', (
      tester,
    ) async {
      final service = _FakeNatureSpotsService();
      await _pumpScreen(tester, service: service);

      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomizeFiltersScreen), findsOneWidget);
      expect(find.text('Customize Filters'), findsOneWidget);
      expect(find.text('Find places that match your trip'), findsOneWidget);
      expect(find.text('No filters selected'), findsOneWidget);
      expect(find.text('Show 3 Places'), findsOneWidget);

      // Only the Citadel is a museum.
      await tester.tap(find.text('Museum'));
      await tester.pumpAndSettle();
      expect(find.text('1 Filter selected'), findsOneWidget);
      expect(find.text('Show 1 Place'), findsOneWidget);

      await tester.tap(find.text('Show 1 Place'));
      await tester.pumpAndSettle();

      // Back on the list, filtered — and with no second Firestore read.
      expect(find.byType(CustomizeFiltersScreen), findsNothing);
      expect(find.text('Erbil Citadel'), findsOneWidget);
      expect(find.text('Sami Abdulrahman Park'), findsNothing);
      expect(service.catalogReads, 1);
    });

    testWidgets('backing out is a cancel — the list keeps its filters', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());

      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Museum'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      // Every place is still listed: the draft was discarded.
      expect(find.text('Erbil Citadel'), findsOneWidget);
      expect(find.text('Sami Abdulrahman Park'), findsOneWidget);
    });

    testWidgets('both groups are drawn with all their chips', (tester) async {
      await _pumpCustomize(tester);

      expect(find.text('Place Type'), findsOneWidget);
      for (final label in [
        'Forest',
        'Mountain',
        'Canyon',
        'Park',
        'Lake',
        'Waterfall',
        'River',
        'Museum',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      expect(find.text('Facilities & Amenities'), findsOneWidget);
      for (final label in [
        'Parking',
        'Restrooms',
        'Restaurants',
        'Cafes',
        'Mobile signal',
        'Lodging nearby',
        'ATM nearby',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('uses the documented three-level glass color stack', (
      tester,
    ) async {
      await _pumpCustomize(tester);

      final panels = tester
          .widgetList<GlassPanel>(find.byType(GlassPanel))
          .toList();
      expect(panels.any((panel) => panel.depth == GlassDepth.base), isTrue);
      expect(panels.any((panel) => panel.depth == GlassDepth.middle), isTrue);
      expect(panels.any((panel) => panel.depth == GlassDepth.top), isTrue);
    });

    testWidgets('the counter spans both groups and Reset All clears them', (
      tester,
    ) async {
      await _pumpCustomize(tester);

      await tester.tap(find.text('Forest'));
      await tester.tap(find.text('Parking'));
      await tester.pumpAndSettle();
      expect(find.text('2 Filters selected'), findsOneWidget);

      await tester.tap(find.text('Reset All'));
      await tester.pumpAndSettle();
      expect(find.text('No filters selected'), findsOneWidget);
    });

    testWidgets('the quick chips still count toward the result total', (
      tester,
    ) async {
      // Beach matches nothing in the catalog, so whatever else is picked the
      // total must be zero — the button has to reflect what the user will see.
      await _pumpCustomize(
        tester,
        initial: const NatureFilters(activities: {'beach'}),
      );

      expect(find.text('No places match'), findsOneWidget);

      await tester.tap(find.text('Museum'));
      await tester.pumpAndSettle();
      expect(find.text('No places match'), findsOneWidget);
    });

    testWidgets('applies with zero matches rather than trapping the user', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeNatureSpotsService());
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forest'));
      await tester.pumpAndSettle();
      expect(find.text('No places match'), findsOneWidget);

      await tester.tap(find.text('No places match'));
      await tester.pumpAndSettle();

      // Lands on the list's empty state, which has its own way out.
      expect(find.text('No places match these filters yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('renders in Arabic (RTL)', (tester) async {
      await _pumpCustomize(tester, locale: const Locale('ar'));

      expect(find.text('تخصيص الفلاتر'), findsOneWidget);
      expect(find.text('نوع المكان'), findsOneWidget);
      expect(find.text('المرافق والخدمات'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('نوع المكان'))),
        TextDirection.rtl,
      );
    });

    testWidgets('dark mode draws the title pure white', (tester) async {
      await _pumpCustomize(tester, dark: true);

      final title = tester.widget<Text>(find.text('Customize Filters'));
      expect(title.style?.color, const Color(0xFFFFFFFF));
    });

    testWidgets('light mode draws the title in on-surface', (tester) async {
      await _pumpCustomize(tester);

      final title = tester.widget<Text>(find.text('Customize Filters'));
      expect(title.style?.color, AppTheme.lightColorScheme.onSurface);
    });

    testWidgets('every filter chip meets the 48dp touch target', (
      tester,
    ) async {
      await _pumpCustomize(tester);

      for (final label in ['Forest', 'Museum', 'Parking', 'ATM nearby']) {
        final inkWell = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(
          tester.getSize(inkWell.first).height,
          greaterThanOrEqualTo(48),
          reason: label,
        );
      }
    });
  });
}

// --- Helpers -----------------------------------------------------------------

Future<void> _pumpScreen(
  WidgetTester tester, {
  required NatureSpotsService service,
  DeviceLocationService location = const _FakeLocationService(null),
  Locale locale = const Locale('en'),
  bool dark = false,
}) async {
  await _pump(
    tester,
    locale: locale,
    dark: dark,
    home: ExploreNatureScreen(
      natureSpotsService: service,
      locationService: location,
    ),
  );
}

Future<void> _pumpCustomize(
  WidgetTester tester, {
  NatureFilters initial = const NatureFilters(),
  Locale locale = const Locale('en'),
  bool dark = false,
}) async {
  await _pump(
    tester,
    locale: locale,
    dark: dark,
    home: CustomizeFiltersScreen(
      initialFilters: initial,
      catalog: NatureSpotsService.bundledSpots(),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  required Locale locale,
  required bool dark,
}) async {
  // Tall enough that the whole filter card is laid out; several assertions
  // read sizes, which requires the widget to be on screen.
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// Stands in for the Firestore-backed catalog source, and counts reads so a
/// test can prove that filtering costs none.
class _FakeNatureSpotsService extends NatureSpotsService {
  _FakeNatureSpotsService({
    this.failFirstList = false,
    this.emptyList = false,
    this.noHighlights = false,
  });

  /// Fails the first catalog read only, so a retry can be shown to succeed.
  bool failFirstList;
  final bool emptyList;
  final bool noHighlights;

  int catalogReads = 0;

  @override
  Future<List<NatureSpot>> fetchHighlighted() async {
    if (noHighlights) return const <NatureSpot>[];
    return NatureSpotsService.bundledSpots()
        .where((spot) => spot.highlighted)
        .toList();
  }

  @override
  Future<List<NatureSpot>> fetchCatalog() async {
    catalogReads++;
    if (failFirstList) {
      failFirstList = false;
      throw StateError('simulated failure');
    }
    if (emptyList) return const <NatureSpot>[];
    return NatureSpotsService.bundledSpots();
  }
}

class _FakeLocationService extends DeviceLocationService {
  const _FakeLocationService(this.location);

  final DeviceLocation? location;

  @override
  Future<DeviceLocation?> currentLocation() async => location;
}
