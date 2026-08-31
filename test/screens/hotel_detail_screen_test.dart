import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel_detail.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_detail_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/map_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';

/// Divan Erbil — five gallery photos, fifteen facilities, six nearby places,
/// a full review breakdown and published policies.
final _rich = PreviewHotelService.hotels.first;

/// Duhok Palace — no gallery, no coordinates, no facilities, no nearby
/// places and no review aggregate.
final _sparse = PreviewHotelService.hotels.last;

HotelSearchCriteria _criteria({int adults = 2, int rooms = 1, int beds = 1}) =>
    HotelSearchCriteria(
      checkIn: DateTime(2026, 8, 29),
      checkOut: DateTime(2026, 8, 31),
      adults: adults,
      rooms: rooms,
      beds: beds,
    );

/// A service whose detail read always throws, for the error state.
class _FailingHotelService extends PreviewHotelService {
  const _FailingHotelService();

  @override
  Future<HotelDetail?> fetchDetail(String hotelId) async =>
      throw StateError('offline');
}

Widget _app({
  Hotel? hotel,
  HotelSearchCriteria? criteria,
  HotelService service = const PreviewHotelService(),
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  themeMode: themeMode,
  home: HotelDetailScreen(
    hotel: hotel ?? _rich,
    criteria: criteria ?? _criteria(),
    service: service,
  ),
);

void _sizePhone(WidgetTester tester, {Size size = const Size(420, 2600)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws the hotel, its stay and every populated section', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app());

    expect(find.text('Divan Erbil'), findsOneWidget);
    expect(
      find.text('Gulan Street, Erbil, Kurdistan Region, Iraq'),
      findsOneWidget,
    );
    // Guest score and star classification are separate values.
    expect(find.text('9.1'), findsWidgets);
    final detailRating = find.byKey(const ValueKey('hotel-detail-rating'));
    expect(detailRating, findsOneWidget);
    final compactBadges = tester
        .widgetList<Container>(
          find.descendant(of: detailRating, matching: find.byType(Container)),
        )
        .where((container) => container.constraints?.minHeight == 32);
    expect(compactBadges, hasLength(2));
    expect(find.text('2 adults, 1 bed'), findsOneWidget);
    expect(find.text('Facilities'), findsWidgets);
    expect(find.text('Outdoor Pool'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('128 reviews'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);
    expect(find.text('Erbil Citadel'), findsOneWidget);
    expect(find.text('Ratings & Comments'), findsOneWidget);
    expect(find.text('Property policies'), findsOneWidget);
  });

  testWidgets('the Select Room CTA stays on screen while the page scrolls', (
    tester,
  ) async {
    _sizePhone(tester, size: const Size(420, 800));
    await _pump(tester, _app());

    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
    await tester.drag(
      find.byKey(const ValueKey('hotel-detail-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    // Still there, and still tappable, after the content has moved.
    expect(find.text('Select Room'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hotel-select-room')));
    await tester.pumpAndSettle();
    expect(find.text('Choose Your Room'), findsOneWidget);
  });

  testWidgets('the gallery pages through the hotel photos', (tester) async {
    _sizePhone(tester);
    await _pump(tester, _app());

    expect(find.text('1 / 5'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('hotel-gallery')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
  });

  testWidgets('a hotel with one photo shows no counter and no dots', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app(hotel: _sparse));

    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('sections with no data are hidden rather than drawn empty', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app(hotel: _sparse));

    expect(find.text('Duhok Palace'), findsOneWidget);
    expect(find.text('Facilities'), findsNothing);
    expect(find.text('Nearby'), findsNothing);
    expect(find.text('Property policies'), findsNothing);
    // Location always draws; without coordinates it says so.
    expect(find.text('Map is unavailable'), findsOneWidget);
  });

  testWidgets('the map preview opens the shared map on this hotel', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app());

    await tester.tap(
      find.byKey(const ValueKey('hotel-map-open')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    final map = tester.widget<MapScreen>(find.byType(MapScreen));
    expect(map.target?.latitude, 36.2027);
    expect(map.title, 'Divan Erbil');
  });

  testWidgets('See all opens every facility, grouped by category', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app());

    await tester.tap(find.byKey(const ValueKey('hotel-facilities-see-all')));
    await tester.pumpAndSettle();

    expect(find.text('All facilities'), findsOneWidget);
    expect(find.text('Food & Drink'), findsOneWidget);
    // A facility that was not in the four-item preview.
    expect(find.text('Spa and wellness'), findsOneWidget);
  });

  testWidgets('Change edits the stay and updates the summary in place', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app());

    await tester.tap(find.byKey(const ValueKey('hotel-change-stay')));
    await tester.pumpAndSettle();

    expect(find.text('Update your stay'), findsNothing);
    expect(find.byKey(const ValueKey('hotel-change-stay')), findsNothing);
    final summary = find.byKey(const ValueKey('hotel-stay-summary'));
    final guests = find.byKey(const ValueKey('hotel-change-guests-panel'));
    final apply = find.byKey(const ValueKey('hotel-change-apply'));
    expect(summary, findsOneWidget);
    expect(find.descendant(of: summary, matching: guests), findsOneWidget);
    expect(find.descendant(of: summary, matching: apply), findsOneWidget);
    expect(
      tester.getTopLeft(guests).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const ValueKey('sheet-check-out'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(apply).dy,
      greaterThan(tester.getBottomLeft(guests).dy),
    );
    final panel = tester.widget<GlassPanel>(guests);
    expect(panel.borderRadius, 26);
    expect(panel.padding, const EdgeInsets.all(14));
    await tester.tap(find.byKey(const ValueKey('sheet-adult-increase')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-room-increase')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hotel-change-apply')));
    await tester.pumpAndSettle();

    expect(find.text('3 adults, 0 children, 2 rooms, 1 bed'), findsOneWidget);
    expect(find.text('Your stay has been updated'), findsOneWidget);
  });

  testWidgets('the adult counter cannot pass the published occupancy limit', (
    tester,
  ) async {
    _sizePhone(tester);
    // Divan's largest preview room sleeps four, and the stay is for one room.
    await _pump(tester, _app());

    await tester.tap(find.byKey(const ValueKey('hotel-change-stay')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sheet-adult-increase')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-adult-increase')));
    await tester.pump();
    // At the ceiling: a further tap must not move it to five.
    await tester.tap(find.byKey(const ValueKey('sheet-adult-increase')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hotel-change-apply')));
    await tester.pumpAndSettle();

    expect(find.text('4 adults, 1 bed'), findsOneWidget);
  });

  testWidgets('back returns the edited criteria to the caller', (tester) async {
    _sizePhone(tester);
    HotelSearchCriteria? returned;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightForLocale(const Locale('en')),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  returned = await Navigator.of(context)
                      .push<HotelSearchCriteria>(
                        MaterialPageRoute<HotelSearchCriteria>(
                          builder: (_) => HotelDetailScreen(
                            hotel: _rich,
                            criteria: _criteria(),
                          ),
                        ),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    // Localizations resolve asynchronously, so the first frame is empty.
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hotel-change-stay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-bed-increase')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hotel-change-apply')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GlassBackButton));
    await tester.pumpAndSettle();

    expect(returned?.beds, 2);
  });

  testWidgets('a failed detail read offers a retry and keeps the page usable', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app(service: const _FailingHotelService()));

    expect(find.text('We could not load this hotel.'), findsOneWidget);
    // The hotel itself, the gallery and the CTA all survive the failure.
    expect(find.text('Divan Erbil'), findsOneWidget);
    expect(find.text('Select Room'), findsOneWidget);
    expect(find.byKey(const ValueKey('hotel-detail-retry')), findsOneWidget);
  });

  testWidgets('renders in Kurdish and Arabic, RTL, on a narrow dark screen', (
    tester,
  ) async {
    _sizePhone(tester, size: const Size(320, 2600));

    await _pump(
      tester,
      _app(locale: const Locale('ku'), themeMode: ThemeMode.dark),
    );
    expect(find.text('دیڤان هەولێر'), findsOneWidget);
    expect(find.text('ئاسانکاریەکان'), findsWidgets);
    expect(find.text('هەڵبژاردنی ژوور'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      _app(locale: const Locale('ar'), themeMode: ThemeMode.dark),
    );
    expect(
      Directionality.of(tester.element(find.text('ديفان أربيل'))),
      TextDirection.rtl,
    );
    expect(find.text('اختيار الغرفة'), findsOneWidget);
    expect(find.text('سياسات الفندق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('policies stay collapsed until they are asked for', (
    tester,
  ) async {
    _sizePhone(tester);
    await _pump(tester, _app());

    expect(find.text('Check-in from'), findsNothing);
    final toggle = find.byKey(const ValueKey('hotel-policies-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Check-in from'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
  });

  testWidgets('survives a 1.6x font scale on a 320dp screen', (tester) async {
    _sizePhone(tester, size: const Size(320, 3600));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
