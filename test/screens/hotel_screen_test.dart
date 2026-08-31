import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_screen.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';

Widget _app({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: const HotelScreen(),
);

void main() {
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
