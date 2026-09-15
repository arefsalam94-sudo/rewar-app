import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel_detail.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_detail_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_reviews_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/map_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/canonical_date_time_picker.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_liquid_glass.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/liquid_glass_surface.dart';
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
  GlobalKey<NavigatorState>? navigatorKey,
}) => MaterialApp(
  navigatorKey: navigatorKey,
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
  group('the stay row and Change pill are canonical Liquid Glass', () {
    const checkInKey = ValueKey('sheet-check-in');
    const checkOutKey = ValueKey('sheet-check-out');
    const changeKey = ValueKey('hotel-change-stay');

    /// The `AppLiquidGlass` that paints [inside]'s own surface.
    AppLiquidGlass glassOf(WidgetTester tester, Finder inside) =>
        tester.widget<AppLiquidGlass>(
          find
              .ancestor(of: inside, matching: find.byType(AppLiquidGlass))
              .first,
        );

    testWidgets('Check-In and Check-Out are real canonical glass fields', (
      tester,
    ) async {
      _sizePhone(tester);
      await _pump(tester, _app());

      for (final key in const [checkInKey, checkOutKey]) {
        final field = find.byKey(key);
        expect(field, findsOneWidget, reason: '$key');

        final glass = glassOf(tester, field);
        expect(glass.useCanonicalGlass, isTrue, reason: '$key');
        // The real shader, not the tint-only embedded treatment.
        expect(glass.layer, GlassLayer.surface, reason: '$key');
        expect(glass.borderRadius, 20, reason: '$key');

        // It really renders the shader.
        final shell = tester.widget<CanonicalGlassShell>(
          find
              .ancestor(of: field, matching: find.byType(CanonicalGlassShell))
              .first,
        );
        expect(shell.borderRadius, 20, reason: '$key');
      }

      // Content unchanged: the calendar icon, the label and the date.
      expect(find.text('Check-In'), findsOneWidget);
      expect(find.text('Check-Out'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsNWidgets(2));
    });

    testWidgets('Change is a real canonical glass pill', (tester) async {
      _sizePhone(tester);
      await _pump(tester, _app());

      final change = find.byKey(changeKey);
      expect(change, findsOneWidget);

      final glass = tester.widget<AppLiquidGlass>(
        find.descendant(of: change, matching: find.byType(AppLiquidGlass)),
      );
      expect(glass.useCanonicalGlass, isTrue);
      expect(glass.layer, GlassLayer.surface);
      expect(glass.borderRadius, 22);
      expect(
        find.descendant(of: change, matching: find.byType(CanonicalGlassShell)),
        findsOneWidget,
      );
      // Icon and label unchanged.
      expect(
        find.descendant(of: change, matching: find.byIcon(Icons.edit_outlined)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: change, matching: find.text('Change')),
        findsOneWidget,
      );
    });

    testWidgets('the other pills stay embedded — only Change changed', (
      tester,
    ) async {
      _sizePhone(tester);
      await _pump(tester, _app());

      // `_PillButton`'s default is still embedded, so the "See all" header
      // pill (nested inside its own card's real glass) is untouched.
      final seeAll = find.byKey(const ValueKey('hotel-facilities-see-all'));
      if (seeAll.evaluate().isNotEmpty) {
        final glass = tester.widget<AppLiquidGlass>(
          find.descendant(of: seeAll, matching: find.byType(AppLiquidGlass)),
        );
        expect(glass.layer, GlassLayer.embedded);
      }
    });

    testWidgets('no real glass surface is nested inside another one', (
      tester,
    ) async {
      _sizePhone(tester);
      await _pump(tester, _app());

      // The Summary card paints its glass as a sibling of its content, so the
      // fields and the pill have no real-glass ancestor. A nested shader
      // would paint stretched and offset on Android.
      final shells = find.byType(CanonicalGlassShell);
      expect(shells, findsWidgets);
      for (var i = 0; i < shells.evaluate().length; i++) {
        expect(
          find.descendant(
            of: shells.at(i),
            matching: find.byType(CanonicalGlassShell),
          ),
          findsNothing,
          reason: 'glass shell $i contains another real glass shell',
        );
      }
    });

    testWidgets('positions and sizes are unchanged', (tester) async {
      _sizePhone(tester);
      await _pump(tester, _app());

      final summary = tester.getRect(
        find.byKey(const ValueKey('hotel-stay-summary')),
      );
      // The card's glass fills the card exactly — content sizes it, glass
      // follows.
      expect(
        tester.getRect(find.byKey(const ValueKey('hotel-stay-summary-glass'))),
        summary,
      );

      final checkIn = tester.getRect(find.byKey(checkInKey));
      final checkOut = tester.getRect(find.byKey(checkOutKey));
      // Side by side, equal widths and heights, the original 10dp gap.
      expect(checkIn.top, checkOut.top);
      expect(checkIn.height, checkOut.height);
      expect(checkIn.width, checkOut.width);
      expect(checkOut.left - checkIn.right, closeTo(10, 0.5));
      // Both stay inside the card, and the glass adds no width of its own.
      expect(checkIn.left, greaterThanOrEqualTo(summary.left));
      expect(checkOut.right, lessThanOrEqualTo(summary.right));

      // The Change pill stays centred in the card and below the dates.
      final change = tester.getRect(find.byKey(changeKey));
      expect(change.top, greaterThan(checkIn.bottom));
      expect(change.center.dx, closeTo(summary.center.dx, 1));
      expect(change.height, greaterThanOrEqualTo(48));
    });

    testWidgets('tap behaviour is unchanged', (tester) async {
      _sizePhone(tester);
      await _pump(tester, _app());

      // Change still opens the editor in place, replacing itself with Apply.
      await tester.tap(find.byKey(changeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(changeKey), findsNothing);
      expect(find.byKey(const ValueKey('hotel-change-apply')), findsOneWidget);

      // And the date field still opens the canonical date picker.
      await tester.tap(find.byKey(checkInKey));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
    });
  });

  testWidgets('coming back from the reviews page re-reads without throwing', (
    tester,
  ) async {
    // Regression, found on a device: `_openReviews` refreshed the summary with
    // an arrow-bodied `setState(() => _reviews = ...fetchTopReviews(...))`. An
    // arrow closure returns the value of its expression, so that callback
    // handed `setState` a `Future` — which its debug assert rejects, taking
    // the screen down with "setState() callback argument returned a Future"
    // every time the user closed the reviews page.
    _sizePhone(tester);
    final navigator = GlobalKey<NavigatorState>();
    await _pump(tester, _app(navigatorKey: navigator));

    final seeAll = find.byKey(const ValueKey('hotel-comments-see-all'));
    await tester.ensureVisible(seeAll);
    await tester.pumpAndSettle();
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.byType(HotelReviewsScreen), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HotelDetailScreen), findsOneWidget);
  });

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
    // Canonical surface now, and embedded rather than its own shader: the
    // panel sits inside the editor's own visible glass.
    final panel = tester.widget<AppLiquidGlass>(guests);
    expect(panel.useCanonicalGlass, isTrue);
    expect(panel.layer, GlassLayer.embedded);
    expect(panel.borderRadius, 26);
    await tester.tap(find.byKey(const ValueKey('sheet-adult-increase')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-room-increase')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hotel-change-apply')));
    // Check the snackbar before waiting for the native map loading timeout.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('3 adults, 0 children, 2 rooms, 1 bed'), findsOneWidget);
    expect(find.text('Your stay has been updated'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('Change Stay is two fields and two single-date steps', (
    tester,
  ) async {
    _sizePhone(tester);
    final today = DateUtils.dateOnly(DateTime.now());
    final initialStart = today.add(const Duration(days: 2));
    final criteria = HotelSearchCriteria(
      checkIn: initialStart,
      checkOut: initialStart.add(const Duration(days: 3)),
    );
    await _pump(tester, _app(criteria: criteria));

    await tester.tap(find.byKey(const ValueKey('hotel-change-stay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-check-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-check-out')), findsOneWidget);

    // --- Check-in: one date, no stay path -------------------------------
    await tester.tap(find.byKey(const ValueKey('sheet-check-in')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(
      _lightRangeBandCount(tester),
      0,
      reason: 'the check-in step is a single date, not a stay',
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(_lightRangeBandCount(tester), 0);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // --- Check-out: anchored to the check-in, stay path appears ----------
    // The check-out picker opens on the check-in's own month, so no month
    // step is needed here.
    await tester.tap(find.byKey(const ValueKey('sheet-check-out')));
    await tester.pumpAndSettle();
    expect(
      _lightRangeBandCount(tester),
      greaterThan(0),
      reason: 'the stay the check-in step resolved to is drawn on open',
    );
    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();
    expect(
      _lightRangeBandCount(tester),
      greaterThan(0),
      reason: 'choosing the check-out must draw the whole stay',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final start = DateTime(initialStart.year, initialStart.month + 1, 12);
    final end = DateTime(initialStart.year, initialStart.month + 1, 16);
    final formatter = MaterialLocalizations.of(
      tester.element(find.byKey(const ValueKey('hotel-stay-summary'))),
    );
    expect(find.text(formatter.formatMediumDate(start)), findsOneWidget);
    expect(find.text(formatter.formatMediumDate(end)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hotel-change-apply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(formatter.formatMediumDate(start)), findsOneWidget);
    expect(find.text(formatter.formatMediumDate(end)), findsOneWidget);
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

int _lightRangeBandCount(WidgetTester tester) => tester
    .widgetList<ColoredBox>(find.byType(ColoredBox))
    .where(
      (box) =>
          box.color ==
          AppColors.actionNavy.withValues(
            alpha: kCanonicalRangeBandLightOpacity,
          ),
    )
    .length;
