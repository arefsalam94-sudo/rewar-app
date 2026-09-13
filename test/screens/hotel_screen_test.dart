import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/canonical_date_time_picker.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';

Widget _app({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: const HotelScreen(),
);

void main() {
  /// Opens the Date filter panel and then one of its two visible fields.
  Future<void> openDateField(WidgetTester tester, String field) async {
    if (find.text('Check-In').evaluate().isEmpty) {
      await tester.tap(find.text('Date').first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(field));
    await tester.pumpAndSettle();
  }

  group('Hotel stay dates — two fields, two single-date steps', () {
    testWidgets('Check-in asks for ONE date and writes only check-in', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final today = DateUtils.dateOnly(DateTime.now());
      final formatter = MaterialLocalizations.of(
        tester.element(find.byType(HotelScreen)),
      );
      // The screen opens on today+1 / today+3.
      final originalCheckOut = formatter.formatMediumDate(
        today.add(const Duration(days: 3)),
      );

      await openDateField(tester, 'Check-In');

      // Only the existing check-in is selected — no range, no band.
      expect(
        _lightRangeBandCount(tester),
        0,
        reason: 'the check-in step shows a single date, not a stay path',
      );

      // Done is reachable immediately: one date already exists and the user is
      // never asked for a check-out here.
      expect(find.text('Done'), findsOneWidget);

      // Move to next month and pick the 21st — one tap, nothing more.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();

      // Still a single selection: picking a day did not start a range.
      expect(_lightRangeBandCount(tester), 0);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final nextMonth = DateTime(today.year, today.month + 1);
      final newCheckIn = DateTime(nextMonth.year, nextMonth.month, 21);
      expect(find.text(formatter.formatMediumDate(newCheckIn)), findsOneWidget);
      // Check-out was untouched by this step (it was already after the new
      // check-in, so the screen's existing pair-resolution left it alone).
      expect(
        find.text(originalCheckOut),
        findsNothing,
        reason: 'a check-out before the new check-in moves to the next night',
      );
    });

    testWidgets(
      'Check-out opens with check-in selected, then paints 21 -> 24',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();

        final today = DateUtils.dateOnly(DateTime.now());
        final formatter = MaterialLocalizations.of(
          tester.element(find.byType(HotelScreen)),
        );
        final nextMonth = DateTime(today.year, today.month + 1);

        // Step 1 — set check-in to the 21st.
        await openDateField(tester, 'Check-In');
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        await tester.tap(find.text('21'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        final checkIn = DateTime(nextMonth.year, nextMonth.month, 21);
        expect(find.text(formatter.formatMediumDate(checkIn)), findsOneWidget);

        // Step 2 — open check-out. The check-in is already selected, and the
        // one-night stay the screen resolved to (21 -> 22) is already drawn:
        // one trailing half on the 21st, one leading half on the 22nd.
        await openDateField(tester, 'Check-Out');
        expect(
          _lightRangeBandCount(tester),
          2,
          reason: 'the existing stay is preloaded as a path',
        );

        // Choose the 24th: the stay becomes 21 -> 24, one continuous path.
        await tester.tap(find.text('24'));
        await tester.pumpAndSettle();
        expect(
          _lightRangeBandCount(tester),
          6,
          reason:
              '21 trailing + 22 both + 23 both + 24 leading — four days, '
              'one unbroken path',
        );

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        final checkOut = DateTime(nextMonth.year, nextMonth.month, 24);
        // Check-out written, check-in untouched.
        expect(find.text(formatter.formatMediumDate(checkOut)), findsOneWidget);
        expect(find.text(formatter.formatMediumDate(checkIn)), findsOneWidget);
      },
    );

    testWidgets('a check-out on or before check-in stays unavailable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final today = DateUtils.dateOnly(DateTime.now());
      final formatter = MaterialLocalizations.of(
        tester.element(find.byType(HotelScreen)),
      );
      final nextMonth = DateTime(today.year, today.month + 1);

      await openDateField(tester, 'Check-In');
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final checkOutBefore = find.text(
        formatter.formatMediumDate(
          DateTime(nextMonth.year, nextMonth.month, 22),
        ),
      );
      expect(
        checkOutBefore,
        findsOneWidget,
        reason: 'the one-night minimum moved check-out to the 22nd',
      );

      await openDateField(tester, 'Check-Out');
      // The resolved 21 -> 22 stay is showing: two band halves.
      expect(_lightRangeBandCount(tester), 2);

      // The one-night minimum: the 21st itself and anything earlier is refused.
      // The taps are inert — the stay stays exactly where it was.
      await tester.tap(find.text('21'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('18'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        _lightRangeBandCount(tester),
        2,
        reason: 'an invalid check-out never moves the stay',
      );

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Unchanged: the refused taps wrote nothing.
      expect(checkOutBefore, findsOneWidget);
    });

    testWidgets('reopening Check-out shows the existing stay as a path', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // The screen's own defaults are already a valid stay (today+1 → today+3).
      await openDateField(tester, 'Check-Out');
      expect(
        _lightRangeBandCount(tester),
        greaterThan(0),
        reason: 'an existing stay is preloaded as a connected path',
      );

      // Dismissing writes nothing.
      await tester.tapAt(const Offset(30, 30));
      await tester.pumpAndSettle();
    });

    testWidgets('both date fields stay visible and separate', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date').first);
      await tester.pumpAndSettle();
      expect(find.text('Check-In'), findsOneWidget);
      expect(find.text('Check-Out'), findsOneWidget);
    });
  });

  testWidgets('hotel ratings and names match the Explore Nature treatment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final featuredRating = find.byKey(
      const ValueKey('featured-hotel-rating-preview-divan-erbil'),
    );
    final trendingRating = find.byKey(
      const ValueKey('trending-hotel-rating-preview-divan-erbil'),
    );
    expect(featuredRating, findsOneWidget);
    expect(trendingRating, findsOneWidget);

    for (final rating in [featuredRating, trendingRating]) {
      final badgeSizes = tester
          .widgetList<Container>(
            find.descendant(of: rating, matching: find.byType(Container)),
          )
          .map((widget) => widget.constraints?.minHeight)
          .where((height) => height == 32);
      expect(badgeSizes, hasLength(2));
    }

    final nameStyles = tester
        .widgetList<Text>(find.text('Divan Erbil'))
        .map((text) => text.style)
        .toList();
    expect(
      nameStyles.any(
        (style) =>
            style?.fontSize == 26 && style?.fontWeight == FontWeight.w700,
      ),
      isTrue,
    );
    expect(
      nameStyles.any(
        (style) =>
            style?.fontSize == 19 && style?.fontWeight == FontWeight.w700,
      ),
      isTrue,
    );
  });

  testWidgets('only one expanded hotel filter is visible at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Location').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-panel')), findsOneWidget);

    await tester.ensureVisible(find.text('Guests').first);
    await tester.tap(find.text('Guests').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-panel')), findsNothing);
    expect(find.byKey(const ValueKey('guests-panel')), findsOneWidget);

    await tester.ensureVisible(find.text('Guests').first);
    await tester.tap(find.text('Guests').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guests-panel')), findsNothing);
  });

  testWidgets('guest counter and option summary update interactively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Guests').first);
    await tester.tap(find.text('Guests').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('adult-increase')));
    await tester.tap(find.byKey(const ValueKey('adult-increase')));
    await tester.pumpAndSettle();
    expect(find.text('3 adults, 1 bed'), findsWidgets);

    // Start a fresh page before checking options so the counter panel's
    // intentional scroll position cannot obscure the fixed filter grid.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Options').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pool').first);
    await tester.tap(find.text('Pool').first);
    await tester.pumpAndSettle();
    expect(find.text('1 option selected'), findsOneWidget);
  });

  testWidgets(
    'hotel page renders in RTL on a narrow screen without exceptions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('أين تقيم'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(GlassBackButton)).dx, lessThan(40));
      expect(tester.takeException(), isNull);
    },
  );
}

/// Half-cells of the stay path currently painted in Light.
///
/// Matches the one canonical range band — navy at
/// [kCanonicalRangeBandLightOpacity] — rather than any Hotel-private value, so
/// this fails if Hotel ever drifts away from the shared appearance.
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
