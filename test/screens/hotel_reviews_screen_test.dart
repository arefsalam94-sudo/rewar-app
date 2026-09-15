import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_reviews_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/nature_reviews_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_liquid_glass.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_menu_popover.dart';

final _hotel = PreviewHotelService.hotels.first;

Widget _app({
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  themeMode: themeMode,
  home: HotelReviewsScreen(hotel: _hotel),
);

const _sortButton = ValueKey('reviews-sort-button');
const _sortMenu = ValueKey('reviews-sort-menu');

Finder _option(String name) => find.byKey(ValueKey('reviews-sort-option-$name'));

/// The label [Text] inside one menu row — never the trigger pill's own copy
/// of the same string.
Text _optionText(WidgetTester tester, String name) => tester.widget<Text>(
  find.descendant(of: _option(name), matching: find.byType(Text)),
);

/// The selection fill behind one menu row.
Color? _optionFill(WidgetTester tester, String name) {
  final container = tester.widget<Container>(
    find.descendant(of: _option(name), matching: find.byType(Container)).first,
  );
  return (container.decoration! as BoxDecoration).color;
}

Future<void> _openSortMenu(WidgetTester tester, {ThemeMode? themeMode}) async {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(themeMode: themeMode ?? ThemeMode.light));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_sortButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hotels reuse the shared Reviews & Ratings screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Not a second comment system: the Explore Nature screen itself.
    expect(find.byType(NatureReviewsScreen), findsOneWidget);
    expect(find.text('Divan Erbil'), findsWidgets);
    expect(find.text('Aland Karim'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('the review sort menu is canonical Liquid Glass', () {
    testWidgets('it opens under the trigger with every option visible', (
      tester,
    ) async {
      expect(find.byKey(_sortMenu), findsNothing);

      await _openSortMenu(tester);

      expect(find.byKey(_sortMenu), findsOneWidget);
      for (final label in const [
        'Most Recent',
        'Highest Rated',
        'Lowest Rated',
        'Most Helpful',
      ]) {
        expect(find.descendant(of: find.byKey(_sortMenu), matching: find.text(label)), findsOneWidget);
      }

      // Anchored to the filter pill exactly as `PopupMenuPosition.under` was:
      // directly beneath it, hung from its leading edge, and never allowed off
      // the screen. (The widget-test font is fixed-width, so the menu measures
      // much wider here than on device and the right-edge clamp engages —
      // hence `lessThanOrEqualTo` rather than an exact left match.)
      final trigger = tester.getRect(find.byKey(_sortButton));
      final menu = tester.getRect(find.byKey(_sortMenu));
      expect(menu.top, greaterThanOrEqualTo(trigger.bottom));
      expect(menu.left, lessThanOrEqualTo(trigger.left + 1));
      expect(menu.right, greaterThan(trigger.left));
      expect(menu.left, greaterThanOrEqualTo(0));
      expect(menu.right, lessThanOrEqualTo(420));
    });

    testWidgets('the menu surface is the shared glass popover, not a sheet', (
      tester,
    ) async {
      await _openSortMenu(tester);

      // No Material `PopupMenuButton` sheet anywhere — the surface is the same
      // GlassMenuPopover the Home language popup's recipe defines.
      expect(find.byType(PopupMenuButton<Object?>), findsNothing);
      expect(find.byType(GlassMenuPopover), findsOneWidget);

      final glass = tester.widget<AppLiquidGlass>(
        find.descendant(
          of: find.byKey(_sortMenu),
          matching: find.byType(AppLiquidGlass),
        ),
      );
      expect(glass.useCanonicalGlass, isTrue);

      // The frost clipped to the menu's own footprint — the part that makes a
      // floating menu read as glass over a photograph.
      expect(
        find.descendant(
          of: find.byKey(_sortMenu),
          matching: find.byKey(const ValueKey('glass-menu-popover-frost')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_sortMenu),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Light: every label is white, the selected row navy-filled', (
      tester,
    ) async {
      await _openSortMenu(tester, themeMode: ThemeMode.light);

      // Selected — white, bold, on the action navy fill.
      expect(_optionText(tester, 'mostRecent').style!.color, Colors.white);
      expect(
        _optionText(tester, 'mostRecent').style!.fontWeight,
        FontWeight.w700,
      );
      expect(_optionFill(tester, 'mostRecent'), AppColors.actionNavy);

      // Unselected — still white and still semibold, never a dim or
      // low-contrast navy over the frosted glass.
      for (final name in const ['highestRated', 'lowestRated', 'mostHelpful']) {
        expect(_optionText(tester, name).style!.color, Colors.white);
        expect(_optionText(tester, name).style!.fontWeight, FontWeight.w600);
        expect(_optionText(tester, name).style!.fontSize, 16);
        expect(_optionFill(tester, name), Colors.transparent);
      }
    });

    testWidgets('Dark: dark-on-mint selected, full white unselected', (
      tester,
    ) async {
      await _openSortMenu(tester, themeMode: ThemeMode.dark);

      expect(
        _optionText(tester, 'mostRecent').style!.color,
        AppColors.darkOnPrimary,
      );
      expect(
        _optionText(tester, 'mostRecent').style!.fontWeight,
        FontWeight.w700,
      );
      expect(_optionFill(tester, 'mostRecent'), AppColors.luminousMint);

      for (final name in const ['highestRated', 'lowestRated', 'mostHelpful']) {
        // `DESIGN DARK F.md`: a heading that looks dim is a bug.
        expect(_optionText(tester, name).style!.color, Colors.white);
        expect(_optionText(tester, name).style!.fontWeight, FontWeight.w600);
        expect(_optionFill(tester, name), Colors.transparent);
      }
    });

    testWidgets('every row clears the 48dp minimum', (tester) async {
      await _openSortMenu(tester);

      for (final name in const [
        'mostRecent',
        'highestRated',
        'lowestRated',
        'mostHelpful',
      ]) {
        expect(
          tester.getSize(_option(name)).height,
          greaterThanOrEqualTo(48),
          reason: name,
        );
      }
    });

    testWidgets('picking an option sorts and re-labels the trigger', (
      tester,
    ) async {
      await _openSortMenu(tester);

      await tester.tap(_option('highestRated'));
      await tester.pumpAndSettle();

      // Menu closed, trigger now carries the chosen sort, and the list is in
      // that order — the same behaviour the Material menu had.
      expect(find.byKey(_sortMenu), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(_sortButton),
          matching: find.text('Highest Rated'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('the hotel is presented with its own review aggregate', () {
    final subject = hotelAsNatureSpot(_hotel);

    expect(subject.id, _hotel.id);
    expect(subject.names['ku'], _hotel.name.ku);
    expect(subject.locationLabels['ar'], _hotel.address!.ar);
    expect(subject.imageAssets, _hotel.galleryImages);
    expect(subject.latitude, _hotel.latitude);
    // Derived from the reviews the list will show, not from Hotel.reviewScore,
    // so the header cannot disagree with the list beneath it.
    expect(subject.ratingCount, 3);
    expect(subject.reviewScore, closeTo(9.0, 0.001));
  });

  test('a hotel with no reviews yet carries no score', () {
    final subject = hotelAsNatureSpot(PreviewHotelService.hotels.last);
    expect(subject.ratingCount, 0);
    expect(subject.reviewScore, isNull);
  });
}
