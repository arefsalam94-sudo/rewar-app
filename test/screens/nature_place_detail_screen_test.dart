import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_detail.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_spot.dart';
import 'package:kurdistan_paradise_travel_guide/screens/map_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/nature_place_detail_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/device_location_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/nature_spots_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/page_background.dart';

void main() {
  const spot = NatureSpot(
    id: 'detail-place',
    names: {'en': 'Bekhal Waterfall', 'ku': 'تاڤگەی بێخاڵ', 'ar': 'شلال بيخال'},
    descriptions: {
      'en': 'A refreshing waterfall surrounded by mountain scenery.',
      'ku': 'تاڤگەیەکی جوانە لە ناو دیمەنی چیاکاندا.',
      'ar': 'شلال منعش تحيط به مناظر جبلية.',
    },
    locationLabels: {
      'en': 'Rawanduz, Kurdistan',
      'ku': 'ڕەواندز، کوردستان',
      'ar': 'رواندوز، كردستان',
    },
    imageAssets: [
      'assets/images/featured-rawanduz.png',
      'assets/images/featured-rawanduz.png',
      'assets/images/featured-rawanduz.png',
      'assets/images/featured-rawanduz.png',
      'assets/images/featured-rawanduz.png',
    ],
    reviewScore: 8.2,
    ratingCount: 214,
    nearbyStays: [
      NearbyStay(
        id: 'stay-1',
        names: {
          'en': 'Rawanduz Resort',
          'ku': 'ڕیزۆرتی ڕەواندز',
          'ar': 'منتجع رواندوز',
        },
        imageAsset: 'assets/images/journey-nature.png',
        distanceKm: 3.2,
      ),
    ],
  );

  /// Same place, but with coordinates — the map card and the distance line
  /// only exist when the catalog document carries a geopoint.
  const located = NatureSpot(
    id: 'detail-place',
    names: {'en': 'Bekhal Waterfall'},
    descriptions: {'en': 'A refreshing waterfall.'},
    locationLabels: {'en': 'Rawanduz, Kurdistan'},
    latitude: 36.6089,
    longitude: 44.5286,
  );

  testWidgets('draws the complete detail structure and two reviews', (
    tester,
  ) async {
    var reviewTapped = false;
    await _pump(tester, spot: spot, onReviewsTap: () => reviewTapped = true);

    expect(find.byType(GlassBackButton), findsOneWidget);
    expect(find.text('8.2'), findsWidgets);
    expect(find.textContaining('Name:'), findsNothing);
    expect(find.text('Bekhal Waterfall'), findsNWidgets(2));
    expect(find.text('Suggested stays nearby'), findsOneWidget);
    expect(find.text('Rawanduz Resort'), findsOneWidget);
    expect(find.text('Weather is unavailable right now'), findsOneWidget);
    expect(find.text('Ratings & Reviews'), findsOneWidget);
    expect(find.text('Aland K.'), findsOneWidget);
    expect(find.text('Sara A.'), findsOneWidget);
    expect(find.text('Visited this place?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nature-detail-reviews-card')));
    expect(reviewTapped, isTrue);
  });

  testWidgets('draws five gallery dots for the five preview slides', (
    tester,
  ) async {
    await _pump(tester, spot: spot);

    for (var index = 0; index < 5; index++) {
      expect(
        find.byKey(ValueKey('nature-detail-gallery-dot-$index')),
        findsOneWidget,
      );
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('nature-detail-gallery-dot-0'))),
      const Size.square(9),
    );

    await tester.drag(
      find.byKey(const ValueKey('nature-detail-gallery')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('nature-detail-gallery-dot-1'))),
      const Size.square(9),
    );
  });

  testWidgets('uses the selected place cover as the blurred page background', (
    tester,
  ) async {
    await _pump(tester, spot: spot);
    final background = tester.widget<PageBackground>(
      find.byType(PageBackground),
    );
    expect(background.imageAsset, 'assets/images/featured-rawanduz.png');
  });

  testWidgets('hides the distance line when there is no GPS fix', (
    tester,
  ) async {
    await _pump(tester, spot: located);
    expect(find.textContaining('Distance:'), findsNothing);
  });

  testWidgets('labels the distance line once a fix arrives', (tester) async {
    await _pump(
      tester,
      spot: located,
      locationService: const _FixedLocationService(),
    );
    expect(find.textContaining('Distance:'), findsOneWidget);
  });

  testWidgets('the map preview opens the full map on this place', (
    tester,
  ) async {
    await _pump(tester, spot: located);

    await tester.tap(find.byKey(const ValueKey('nature-detail-map-locate')));
    await tester.pumpAndSettle();
    final map = tester.widget<MapScreen>(find.byType(MapScreen));
    expect(map.target?.latitude, 36.6089);
    expect(map.title, 'Bekhal Waterfall');
  });

  testWidgets('renders localized Kurdish and Arabic detail labels', (
    tester,
  ) async {
    await _pump(tester, spot: spot, locale: const Locale('ku'));
    expect(find.text('تاڤگەی بێخاڵ'), findsNWidgets(2));
    expect(find.text('شوێنی مانەوەی پێشنیارکراو لە نزیکەوە'), findsOneWidget);

    await _pump(tester, spot: spot, locale: const Locale('ar'));
    expect(find.text('شلال بيخال'), findsNWidgets(2));
    expect(find.text('أماكن إقامة مقترحة قريبة'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required NatureSpot spot,
  Locale locale = const Locale('en'),
  VoidCallback? onReviewsTap,
  DeviceLocationService locationService = const _NoLocationService(),
}) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      home: NaturePlaceDetailScreen(
        spot: spot,
        natureSpotsService: _ReviewService(),
        locationService: locationService,
        onReviewsTap: onReviewsTap,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ReviewService extends NatureSpotsService {
  @override
  Future<List<NatureReview>> fetchTopReviews(String spotId) async => const [
    NatureReview(
      id: 'r1',
      userName: 'Aland K.',
      comment: 'A beautiful and refreshing place.',
      rating: 5,
    ),
    NatureReview(
      id: 'r2',
      userName: 'Sara A.',
      comment: 'The mountain view was excellent.',
      rating: 4,
    ),
  ];
}

class _NoLocationService extends DeviceLocationService {
  const _NoLocationService();

  @override
  Future<DeviceLocation?> currentLocation() async => null;
}

class _FixedLocationService extends DeviceLocationService {
  const _FixedLocationService();

  @override
  Future<DeviceLocation?> currentLocation() async =>
      const DeviceLocation(36.5, 44.4);
}
