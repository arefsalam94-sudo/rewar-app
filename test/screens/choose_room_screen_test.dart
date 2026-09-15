import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/screens/choose_room_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_booking_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_liquid_glass.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/liquid_glass_surface.dart';

final _hotel = PreviewHotelService.hotels.first;

HotelSearchCriteria _criteria({int rooms = 1}) => HotelSearchCriteria(
  checkIn: DateTime(2026, 9, 1),
  checkOut: DateTime(2026, 9, 3),
  adults: 2,
  rooms: rooms,
);

Widget _app({
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  int rooms = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  themeMode: themeMode,
  home: ChooseRoomScreen(
    hotel: _hotel,
    criteria: _criteria(rooms: rooms),
    bookingService: const PreviewHotelBookingService(delay: Duration.zero),
  ),
);

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Every room type the preview hotel offers, in render order.
const _roomIds = ['garden-view', 'king-room'];

Finder _roomCard(String roomId) => find.byKey(chooseRoomCardKey(roomId));

void main() {
  group('one main Liquid Glass panel per room type', () {
    testWidgets('each room type is its own real canonical glass surface', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final roomId in _roomIds) {
        expect(_roomCard(roomId), findsOneWidget, reason: roomId);
        final glass = tester.widget<AppLiquidGlass>(
          find.byKey(chooseRoomCardGlassKey(roomId)),
        );
        expect(glass.useCanonicalGlass, isTrue, reason: roomId);
        // The real shader, not the tint-only embedded treatment.
        expect(glass.layer, GlassLayer.surface, reason: roomId);
        // The panel's glass fills the panel exactly — the content sizes the
        // card, the glass follows it.
        expect(
          tester.getRect(find.byKey(chooseRoomCardGlassKey(roomId))),
          tester.getRect(_roomCard(roomId)),
          reason: roomId,
        );
      }

      // Separate panels, never one container around every room.
      final garden = tester.getRect(_roomCard('garden-view'));
      final king = tester.getRect(_roomCard('king-room'));
      expect(king.top, greaterThanOrEqualTo(garden.bottom));
      expect(
        find.descendant(
          of: _roomCard('garden-view'),
          matching: _roomCard('king-room'),
        ),
        findsNothing,
      );
    });

    testWidgets('photo, name, facilities, details, rates and availability '
        'all sit inside the room panel', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final card = _roomCard('garden-view');

      // Room photo.
      expect(
        find.descendant(of: card, matching: find.byType(Image)),
        findsWidgets,
      );
      // Room name.
      expect(
        find.descendant(of: card, matching: find.text('Garden View Room')),
        findsOneWidget,
      );
      // Facilities / feature chips.
      expect(
        find.descendant(of: card, matching: find.textContaining('King bed')),
        findsWidgets,
      );
      // "See room details".
      expect(
        find.descendant(of: card, matching: find.text('See room details')),
        findsOneWidget,
      );
      // Both rate options.
      for (final rateId in const ['garden-dinner', 'garden-room-only']) {
        expect(
          find.descendant(
            of: card,
            matching: find.byKey(chooseRoomRateKey(rateId)),
          ),
          findsOneWidget,
          reason: rateId,
        );
      }
      // Availability line.
      expect(
        find.descendant(of: card, matching: find.textContaining('rooms left')),
        findsOneWidget,
      );
    });

    testWidgets('every glass surface under a room uses the shared canonical '
        'shader settings, never a tuned one', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final roomId in _roomIds) {
        final groups = tester.widgetList<LiquidGlassGroup>(
          find.descendant(
            of: _roomCard(roomId),
            matching: find.byType(LiquidGlassGroup),
          ),
        );
        expect(groups, isNotEmpty, reason: roomId);
        for (final group in groups) {
          // `canonicalGlassSettingsFor` scales only spatial values by radius;
          // every intensity/angle/colour value stays the shared canonical one.
          // A bespoke per-screen recipe would show up right here.
          final canonical = canonicalGlassSettingsFor(
            kCanonicalGlassReferenceRadius,
          );
          expect(group.settings.specStrength, canonical.specStrength);
          expect(group.settings.specPower, canonical.specPower);
          expect(group.settings.refractStrength, canonical.refractStrength);
          expect(group.settings.lightbandStrength, canonical.lightbandStrength);
          expect(group.settings.lightbandColor, canonical.lightbandColor);
        }
      }
    });

    testWidgets('the private _NestedGlass sheen workaround is gone', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final roomId in _roomIds) {
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: _roomCard(roomId),
            matching: find.byType(DecoratedBox),
          ),
        )) {
          final decoration = box.decoration;
          if (decoration is! BoxDecoration) continue;
          // No imitation glass: no gradient of any kind is painted inside a
          // room panel any more, so the white sheen cannot come back.
          expect(
            decoration.gradient,
            isNull,
            reason: '$roomId still paints a gradient behind nested content',
          );
        }
      }
    });

    testWidgets('each rate option is a real canonical Liquid Glass card', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final rateId in const ['garden-dinner', 'garden-room-only']) {
        final rate = find.byKey(chooseRoomRateKey(rateId));
        final glass = tester.widget<AppLiquidGlass>(
          find.descendant(of: rate, matching: find.byType(AppLiquidGlass)),
        );
        // The app's one shared canonical surface — the same component every
        // other approved glass card renders through.
        expect(glass.useCanonicalGlass, isTrue, reason: rateId);
        expect(glass.layer, GlassLayer.surface, reason: rateId);
        // Unchanged geometry.
        expect(glass.borderRadius, 22, reason: rateId);
        expect(glass.padding, const EdgeInsets.all(16), reason: rateId);

        // It really renders the shader, and carries the canonical floating
        // shadow a standalone card gets.
        final shell = tester.widget<CanonicalGlassShell>(
          find.descendant(of: rate, matching: find.byType(CanonicalGlassShell)),
        );
        expect(shell.borderRadius, 22, reason: rateId);
        expect(shell.shadow, isNotNull, reason: rateId);
      }
    });

    testWidgets('each facility chip reuses the Explore Nature filter-chip '
        'glass recipe', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Every facility/feature the Garden View room lists.
      const facilities = [
        '70 m²',
        'Smart Tech',
        'Spa & Massage',
        'Safety Lock',
        'Gym Access',
      ];
      final expectedTint = AppColors.canonicalGlassBodyTint.withValues(
        alpha: AppColors.lightCanonicalGlassBodyTintOpacity,
      );

      for (final label in facilities) {
        final chipText = find.descendant(
          of: _roomCard('garden-view'),
          matching: find.text(label),
        );
        expect(chipText, findsOneWidget, reason: label);

        // `_FilterChoiceChip`'s exact recipe: a real CanonicalGlassShell with
        // NO shadow (chips in a Wrap must not each cast one), over the shared
        // canonicalGlassBodyTint at canonicalGlassBodyTintOpacity.
        final shell = tester.widget<CanonicalGlassShell>(
          find
              .ancestor(
                of: chipText,
                matching: find.byType(CanonicalGlassShell),
              )
              .first,
        );
        expect(shell.borderRadius, 18, reason: label);
        expect(shell.shadow, isNull, reason: label);

        final tinted = tester
            .widgetList<DecoratedBox>(
              find.ancestor(of: chipText, matching: find.byType(DecoratedBox)),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.color)
            .toList();
        expect(tinted, contains(expectedTint), reason: label);
      }
    });

    testWidgets('no real glass surface is nested inside another one', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // The rule `canonical_date_time_picker.dart` documents and this screen
      // broke: a real `OCLiquidGlass` pushes its own `BackdropFilterLayer`
      // and positions its shapes with scene-space uniforms, so a second real
      // surface *inside* that layer paints stretched and offset. The room
      // panel's glass is a sibling of its content, never an ancestor.
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

    testWidgets('each facility chip hugs its own icon and label', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // 11dp leading padding + 17dp icon + 6dp gap before the label, and
      // 11dp trailing padding after it. Anything wider means the glass shell
      // stretched past its content instead of wrapping it.
      const leading = 11.0 + 17.0 + 6.0;
      const trailing = 11.0;

      final rects = <Rect>[];
      for (final label in const [
        '70 m²',
        'Smart Tech',
        'Spa & Massage',
        'Safety Lock',
        'Gym Access',
      ]) {
        final chipText = find.descendant(
          of: _roomCard('garden-view'),
          matching: find.text(label),
        );
        final text = tester.getRect(chipText);
        final shell = tester.getRect(
          find
              .ancestor(
                of: chipText,
                matching: find.byType(CanonicalGlassShell),
              )
              .first,
        );

        expect(shell.left, closeTo(text.left - leading, 0.5), reason: label);
        expect(shell.right, closeTo(text.right + trailing, 0.5), reason: label);
        // And never the full width of the panel it sits in.
        expect(
          shell.width,
          lessThan(tester.getRect(_roomCard('garden-view')).width),
          reason: label,
        );
        rects.add(shell);
      }

      // Chips never overlap each other.
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: 'chip $i overlaps chip $j',
          );
        }
      }
    });

    testWidgets('no glass is painted around "See room details"', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final details = tester.getRect(
        find.descendant(
          of: _roomCard('garden-view'),
          matching: find.text('See room details'),
        ),
      );

      // No stray/empty canonical surface sits behind or under the link.
      expect(
        find.ancestor(
          of: find.text('See room details'),
          matching: find.byType(CanonicalGlassShell),
        ),
        findsNothing,
      );
      final shells = find.byType(CanonicalGlassShell);
      for (var i = 0; i < shells.evaluate().length; i++) {
        final rect = tester.getRect(shells.at(i));
        // The room panel's own glass legitimately spans the whole card;
        // nothing else may touch the link's band.
        if (rect.height > 500) continue;
        expect(
          rect.overlaps(details),
          isFalse,
          reason: 'a glass surface overlaps "See room details"',
        );
      }
    });

    testWidgets('the two rate cards keep their original geometry', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final dinner = tester.getRect(
        find.byKey(chooseRoomRateKey('garden-dinner')),
      );
      final only = tester.getRect(
        find.byKey(chooseRoomRateKey('garden-room-only')),
      );

      // Side by side, equal widths and heights, the original 12dp gap, and
      // the glass adds no width, height or offset of its own.
      expect(dinner.top, only.top);
      expect(dinner.height, only.height);
      expect(dinner.width, only.width);
      expect(only.left - dinner.right, closeTo(12, 0.5));

      for (final rate in [dinner, only]) {
        final shell = tester.getRect(
          find
              .descendant(
                of: find.byKey(
                  rate == dinner
                      ? chooseRoomRateKey('garden-dinner')
                      : chooseRoomRateKey('garden-room-only'),
                ),
                matching: find.byType(CanonicalGlassShell),
              )
              .first,
        );
        expect(shell, rate, reason: 'the glass must match the card exactly');
      }
    });
  });

  group('the Reserve button is untouched by the room panels', () {
    testWidgets('it lives outside every room panel, sticky at the bottom', (
      tester,
    ) async {
      // A real phone viewport, so the rooms genuinely overflow and scroll.
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final roomId in _roomIds) {
        expect(
          find.descendant(
            of: _roomCard(roomId),
            matching: find.byKey(chooseRoomReserveKey),
          ),
          findsNothing,
          reason: roomId,
        );
      }

      // Overlaid at the bottom of the screen, not a row in the scroll view.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);
      expect(scaffold.extendBody, isTrue);

      // Pinned to the bottom of the screen, inside the bar's own 12dp
      // SafeArea minimum — not somewhere up in the scrolled content.
      final before = tester.getRect(find.byKey(chooseRoomReserveKey));
      expect(before.bottom, closeTo(900 - 12, 1));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Still there, still in the same place, after scrolling.
      final after = tester.getRect(find.byKey(chooseRoomReserveKey));
      expect(after, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it stays disabled until a rate is chosen', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      ElevatedButton reserve() => tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(chooseRoomReserveKey),
          matching: find.byType(ElevatedButton),
        ),
      );

      expect(reserve().onPressed, isNull);
      await tester.tap(find.byKey(chooseRoomRateKey('king-flex')));
      await tester.pump();
      expect(reserve().onPressed, isNotNull);
    });
  });

  testWidgets('selects, deselects and reserves exactly one rate', (
    tester,
  ) async {
    _size(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Garden View Room'), findsOneWidget);
    expect(find.text('King Room'), findsOneWidget);
    final reserve = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(chooseRoomReserveKey),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(reserve.onPressed, isNull);

    await tester.tap(find.byKey(chooseRoomRateKey('garden-dinner')));
    await tester.pump();
    final enabled = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(chooseRoomReserveKey),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(enabled.onPressed, isNotNull);

    await tester.tap(find.byKey(chooseRoomRateKey('garden-dinner')));
    await tester.pump();
    final disabledAgain = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(chooseRoomReserveKey),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(disabledAgain.onPressed, isNull);

    await tester.tap(find.byKey(chooseRoomRateKey('king-flex')));
    await tester.pump();
    await tester.tap(find.byKey(chooseRoomReserveKey));
    await tester.pumpAndSettle();
    expect(find.text('Complete Your Booking'), findsOneWidget);
  });

  testWidgets('shows a designed empty state for unsupported multiple rooms', (
    tester,
  ) async {
    _size(tester);
    await tester.pumpWidget(_app(rooms: 2));
    await tester.pumpAndSettle();

    expect(
      find.text('No rooms are available for these dates.'),
      findsOneWidget,
    );
    expect(find.text('Change dates'), findsOneWidget);
  });

  testWidgets('renders dark Arabic RTL without an exception', (tester) async {
    _size(tester);
    await tester.pumpWidget(
      _app(locale: const Locale('ar'), themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر غرفتك'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('اختر غرفتك'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the two rates share a row on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final dinner = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-dinner')),
    );
    final only = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-room-only')),
    );

    expect(dinner.top, only.top);
    expect(dinner.right, lessThanOrEqualTo(only.left));
    // The longer wording on one rate must not leave the other card short.
    expect(dinner.height, only.height);
    expect(dinner.width, only.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a raised text scale drops the rates back to one column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 3600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final dinner = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-dinner')),
    );
    final only = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-room-only')),
    );

    expect(only.top, greaterThan(dinner.top));
    expect(tester.takeException(), isNull);
  });
}
