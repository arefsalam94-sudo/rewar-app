import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_liquid_glass.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/canonical_date_time_picker.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/liquid_glass_surface.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';

/// The canonical picker system: one sheet, four modes.
void main() {
  const locale = Locale('en');

  Widget host({
    required bool dark,
    required void Function(BuildContext) onTap,
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onTap(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    // Localization delegates load asynchronously, so the host has to settle
    // before its button exists.
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The one real-glass sheet, found by its canonical radius.
  AppLiquidGlass sheetOf(WidgetTester tester) => tester
      .widgetList<AppLiquidGlass>(find.byType(AppLiquidGlass))
      .firstWhere((g) => g.borderRadius == 28);

  // =========================================================================
  group('shared shell', () {
    testWidgets('opens a real Liquid Glass sheet over a blurred backdrop', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDatePicker(
            context: context,
            initialDate: DateTime(2026, 6, 10),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 6, 30),
          ),
        ),
      );
      await open(tester);

      // Backdrop: a real blur, not a flat scrim.
      expect(find.byType(BackdropFilter), findsWidgets);

      // Sheet: the canonical real-glass surface.
      final sheet = sheetOf(tester);
      expect(sheet.useCanonicalGlass, isTrue);
      expect(sheet.layer, GlassLayer.surface);

      // Done uses the shared primary-action button, not a bespoke one.
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    testWidgets(
      'the backdrop is a sibling of the glass sheet, never its parent',
      (tester) async {
        // The nested-filter topology that produced the documented black-band
        // corruption. The sheet must not sit inside the backdrop's filter layer.
        await tester.pumpWidget(
          host(
            dark: true,
            onTap: (context) => showCanonicalDatePicker(
              context: context,
              initialDate: DateTime(2026, 6, 10),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 6, 30),
            ),
          ),
        );
        await open(tester);

        expect(
          find.descendant(
            of: find.byType(BackdropFilter).first,
            matching: find.byType(AppLiquidGlass),
          ),
          findsNothing,
          reason:
              'the glass sheet must not be inside the backdrop filter layer',
        );
      },
    );

    testWidgets('sits at the bottom of the screen, not centred', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDatePicker(
            context: context,
            initialDate: DateTime(2026, 6, 10),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 6, 30),
          ),
        ),
      );
      await open(tester);

      final screen = tester.getSize(find.byType(MaterialApp));
      final box = tester.getRect(find.byWidget(sheetOf(tester)));
      expect(
        box.bottom,
        greaterThan(screen.height * 0.7),
        reason: 'the sheet stays attached to the bottom edge',
      );
    });

    testWidgets('no day cell is its own real-glass surface', (tester) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDatePicker(
            context: context,
            initialDate: DateTime(2026, 6, 10),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 6, 30),
          ),
        ),
      );
      await open(tester);

      final realGlass = tester
          .widgetList<AppLiquidGlass>(find.byType(AppLiquidGlass))
          .where((g) => g.useCanonicalGlass && g.layer == GlassLayer.surface);
      expect(
        realGlass.length,
        1,
        reason: 'exactly one real glass surface: the sheet itself',
      );
    });
  });

  // =========================================================================
  group('single date', () {
    testWidgets('confirms only on Done', (tester) async {
      DateTime? result;
      var returned = false;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDatePicker(
              context: context,
              initialDate: DateTime(2026, 6, 10),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 6, 30),
            );
            returned = true;
          },
        ),
      );
      await open(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(returned, isFalse, reason: 'tapping a day must not close it');

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, DateTime(2026, 6, 15));
    });

    testWidgets('dismissing without confirming returns null', (tester) async {
      DateTime? result;
      var returned = false;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDatePicker(
              context: context,
              initialDate: DateTime(2026, 6, 10),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 6, 30),
            );
            returned = true;
          },
        ),
      );
      await open(tester);

      // A pick the user then abandons must not be committed (§15).
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 60)); // outside the sheet
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, isNull);
    });

    testWidgets('Android back dismisses without committing', (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDatePicker(
              context: context,
              initialDate: DateTime(2026, 6, 10),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 6, 30),
            );
          },
        ),
      );
      await open(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('min/max constraints are honoured', (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDatePicker(
              context: context,
              initialDate: DateTime(2026, 6, 10),
              firstDate: DateTime(2026, 6, 8),
              lastDate: DateTime(2026, 6, 20),
            );
          },
        ),
      );
      await open(tester);

      // Out of range: the tap is ignored, so Done still returns the initial.
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 6, 10));
    });

    testWidgets('an out-of-range initial date is clamped into range', (
      tester,
    ) async {
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDatePicker(
              context: context,
              initialDate: DateTime(2026, 1, 1),
              firstDate: DateTime(2026, 6, 8),
              lastDate: DateTime(2026, 6, 20),
            );
          },
        ),
      );
      await open(tester);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 6, 8));
    });
  });

  // =========================================================================
  group('selected vs unselected, per theme', () {
    Future<Color?> selectedFillFor(
      WidgetTester tester, {
      required bool dark,
    }) async {
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) => showCanonicalDatePicker(
            context: context,
            initialDate: DateTime(2026, 6, 10),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 6, 30),
          ),
        ),
      );
      await open(tester);
      // Read below the Theme the canonical picker installs, not above it.
      final context = tester.element(find.byType(CalendarDatePicker));
      final data = Theme.of(context).datePickerTheme;
      return data.dayBackgroundColor?.resolve({WidgetState.selected});
    }

    testWidgets('Light selects with canonical navy', (tester) async {
      expect(await selectedFillFor(tester, dark: false), AppColors.actionNavy);
    });

    testWidgets('Dark selects with canonical mint', (tester) async {
      expect(await selectedFillFor(tester, dark: true), AppColors.luminousMint);
    });

    testWidgets('unselected days stay transparent in both themes', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          host(
            dark: dark,
            onTap: (context) => showCanonicalDatePicker(
              context: context,
              initialDate: DateTime(2026, 6, 10),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 6, 30),
            ),
          ),
        );
        await open(tester);
        final context = tester.element(find.byType(CalendarDatePicker));
        final data = Theme.of(context).datePickerTheme;
        expect(data.dayBackgroundColor?.resolve({}), Colors.transparent);
        // Today keeps a distinguishable ring, not a fill. The ring follows the
        // calendar's content colour: white in Light alongside the white day
        // numbers, the approved mint in Dark.
        expect(
          data.todayBorder?.color,
          dark ? AppColors.luminousMint : Colors.white,
        );
        await tester.tapAt(const Offset(200, 60));
        await tester.pumpAndSettle();
      }
    });
  });

  // =========================================================================
  group('date of birth and age', () {
    testWidgets('uses the same sheet and calendar as a plain date', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDateOfBirthPicker(
            context: context,
            initialDate: DateTime(2000, 5, 20),
            firstDate: DateTime(1926),
            lastDate: DateTime(2026, 9, 12),
          ),
        ),
      );
      await open(tester);

      expect(find.byType(CanonicalCalendarDatePicker), findsOneWidget);
      expect(sheetOf(tester).useCanonicalGlass, isTrue);
      expect(
        find.byType(CupertinoDatePicker),
        findsNothing,
        reason: 'no separate numeric age wheel',
      );
    });

    testWidgets('with no value it opens at the caller\'s upper bound', (
      tester,
    ) async {
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDateOfBirthPicker(
              context: context,
              firstDate: DateTime(1926),
              lastDate: DateTime(2008, 9, 12),
            );
          },
        ),
      );
      await open(tester);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      // Never today, which would be an impossible birth date.
      expect(result, DateTime(2008, 9, 12));
    });

    group('ageOn', () {
      test('counts whole years', () {
        expect(ageOn(DateTime(2000, 5, 20), asOf: DateTime(2026, 5, 20)), 26);
      });

      test('a birthday that has not happened yet is still the younger age', () {
        expect(
          ageOn(DateTime(2000, 5, 20), asOf: DateTime(2026, 5, 19)),
          25,
          reason: 'year subtraction alone would wrongly say 26',
        );
      });

      test('the day before and the day after a birthday differ by one', () {
        final before = ageOn(
          DateTime(2000, 12, 31),
          asOf: DateTime(2026, 12, 30),
        );
        final after = ageOn(
          DateTime(2000, 12, 31),
          asOf: DateTime(2026, 12, 31),
        );
        expect(after - before, 1);
      });

      test('a leap-day birth is handled on a non-leap year', () {
        expect(ageOn(DateTime(2000, 2, 29), asOf: DateTime(2026, 2, 28)), 25);
        expect(ageOn(DateTime(2000, 2, 29), asOf: DateTime(2026, 3, 1)), 26);
      });
    });
  });

  // =========================================================================
  group('date range', () {
    Future<DateTimeRange?> pickRange(
      WidgetTester tester, {
      required List<String> taps,
      bool confirm = true,
      bool dark = false,
    }) async {
      DateTimeRange? result;
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) async {
            result = await showCanonicalDateRangePicker(
              context: context,
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
            );
          },
        ),
      );
      await open(tester);
      for (final day in taps) {
        await tester.tap(find.text(day));
        await tester.pumpAndSettle();
      }
      if (confirm) {
        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('selects a start and an end', (tester) async {
      final range = await pickRange(tester, taps: ['5', '12']);
      expect(range?.start, DateTime(2026, 6, 5));
      expect(range?.end, DateTime(2026, 6, 12));
    });

    testWidgets('a preloaded start waits for and connects to its end', (
      tester,
    ) async {
      DateTimeRange? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDateRangePicker(
              context: context,
              initialStart: DateTime(2026, 6, 12),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
            );
          },
        ),
      );
      await open(tester);

      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNull,
      );
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(result?.start, DateTime(2026, 6, 12));
      expect(result?.end, DateTime(2026, 6, 16));
    });

    testWidgets('a caller predicate preserves minimum-range rules', (
      tester,
    ) async {
      DateTimeRange? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDateRangePicker(
              context: context,
              initialStart: DateTime(2026, 6, 12),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
              selectableRangePredicate: (start, end) => end.isAfter(start),
            );
          },
        ),
      );
      await open(tester);

      await tester.tap(find.text('12'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNull,
        reason: 'same-day check-in/check-out stays invalid',
      );

      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(
        result,
        DateTimeRange(start: DateTime(2026, 6, 12), end: DateTime(2026, 6, 16)),
      );
    });

    testWidgets('Done stays disabled until both ends are chosen', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDateRangePicker(
            context: context,
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 8, 31),
          ),
        ),
      );
      await open(tester);

      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNull,
      );

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNull,
        reason: 'a half-made range cannot be committed',
      );

      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNotNull,
      );
    });

    testWidgets('tapping before the start begins a new range', (tester) async {
      final range = await pickRange(tester, taps: ['12', '5', '20']);
      expect(range?.start, DateTime(2026, 6, 5));
      expect(range?.end, DateTime(2026, 6, 20));
    });

    testWidgets('moves between months', (tester) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDateRangePicker(
            context: context,
            firstDate: DateTime(2026, 6, 10),
            lastDate: DateTime(2026, 8, 31),
          ),
        ),
      );
      await open(tester);

      expect(find.text('June 2026'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('July 2026'), findsOneWidget);
    });

    testWidgets('dismissing returns null even with both ends picked', (
      tester,
    ) async {
      final range = await pickRange(tester, taps: ['5', '12'], confirm: false);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(range, isNull);
    });
  });

  // =========================================================================
  group('time', () {
    testWidgets('uses the same sheet, with an embedded wheel backing', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 9, minute: 30),
          ),
        ),
      );
      await open(tester);

      expect(find.byType(CanonicalCupertinoDatePicker), findsOneWidget);
      expect(sheetOf(tester).layer, GlassLayer.surface);

      // The wheel backing is embedded — not a second real shader (§6).
      final embedded = tester
          .widgetList<AppLiquidGlass>(find.byType(AppLiquidGlass))
          .where((g) => g.layer == GlassLayer.embedded);
      expect(embedded.length, 1);
    });

    testWidgets('confirms the initial time when Done is tapped', (
      tester,
    ) async {
      TimeOfDay? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 9, minute: 30),
            );
          },
        ),
      );
      await open(tester);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(result, const TimeOfDay(hour: 9, minute: 30));
    });

    testWidgets('dismissing returns null', (tester) async {
      TimeOfDay? result;
      var returned = false;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 9, minute: 30),
            );
            returned = true;
          },
        ),
      );
      await open(tester);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
    });

    testWidgets('renders in Dark without a separate implementation', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          dark: true,
          onTap: (context) => showCanonicalTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 9, minute: 30),
          ),
        ),
      );
      await open(tester);
      expect(find.byType(CanonicalCupertinoDatePicker), findsOneWidget);
      expect(sheetOf(tester).useCanonicalGlass, isTrue);
    });
  });

  // =========================================================================
  // Light-mode readability refinement
  // =========================================================================
  // The Light-mode calendar's content colour is asserted by the
  // "Light calendar content is white" group below. What stays here is the
  // typography and state behaviour that is independent of that colour.
  group('Light typography and states', () {
    Future<DatePickerThemeData> calendarTheme(
      WidgetTester tester, {
      required bool dark,
    }) async {
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) => showCanonicalDatePicker(
            context: context,
            initialDate: DateTime(2026, 6, 10),
            firstDate: DateTime(2026, 6, 8),
            lastDate: DateTime(2026, 6, 20),
          ),
        ),
      );
      await open(tester);
      final context = tester.element(find.byType(CalendarDatePicker));
      return Theme.of(context).datePickerTheme;
    }

    testWidgets('day numbers own their rendered style, not just a colour', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      // The trap this guards: Flutter applies the state-resolved foreground to
      // `dayStyle`, so a colour token alone leaves Material's regular-weight
      // glyph in place — which is what looked faint on Android.
      expect(data.dayStyle, isNotNull);
      expect(data.dayStyle?.fontWeight, FontWeight.w600);

      final day = tester.widget<Text>(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('12'),
        ),
      );
      expect(day.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('the header is not left on the 0.60 framework default', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      expect(data.subHeaderForegroundColor!.a, 1.0);
      expect(data.toggleButtonTextStyle?.fontWeight, FontWeight.w700);
    });

    testWidgets('a hierarchy exists: primary > secondary > disabled', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      final primary = data.dayForegroundColor!.resolve({})!.a;
      final secondary = data.weekdayStyle!.color!.a;
      final disabled = data.dayForegroundColor!.resolve({
        WidgetState.disabled,
      })!.a;
      expect(primary, greaterThan(secondary));
      expect(secondary, greaterThan(disabled));
    });

    testWidgets('selected today is a solid selected cell, not a ring', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      // Flutter resolves the `today*` properties instead of the ordinary day
      // ones for today's cell, so selected today needs its own solid fill.
      expect(
        data.todayBackgroundColor?.resolve({WidgetState.selected}),
        AppColors.actionNavy,
      );
      expect(
        data.todayForegroundColor?.resolve({WidgetState.selected}),
        Colors.white,
      );
      expect(
        data.todayBackgroundColor?.resolve({}),
        Colors.transparent,
        reason: 'unselected today keeps a ring, not a fill',
      );
    });

    testWidgets('the time wheel gains weight in Light only', (tester) async {
      Future<TextStyle> wheelStyle({required bool dark}) async {
        await tester.pumpWidget(
          host(
            dark: dark,
            onTap: (context) => showCanonicalTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 9, minute: 30),
            ),
          ),
        );
        await open(tester);
        final context = tester.element(find.byType(CupertinoDatePicker));
        return CupertinoTheme.of(context).textTheme.dateTimePickerTextStyle;
      }

      final light = await wheelStyle(dark: false);
      expect(light.fontWeight, FontWeight.w600);
      expect(
        light.color,
        Colors.white,
        reason: 'the extra weight is on top of white, not navy',
      );

      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      final dark = await wheelStyle(dark: true);
      expect(dark.color, Colors.white);
      expect(dark.fontWeight, isNot(FontWeight.w600));
    });
  });

  // =========================================================================
  // Light time wheel content is white
  // =========================================================================
  // The theme style alone is not proof: `CupertinoDatePicker` builds the hour,
  // minute and AM/PM columns separately and can restyle a column on its own.
  // These read the `Text` widgets the wheel actually renders.
  group('Light time wheel content is white', () {
    /// Every wheel label the picker renders, with its fully resolved style.
    Future<List<({String label, TextStyle style})>> wheelLabels(
      WidgetTester tester, {
      required bool dark,
      bool use24h = false,
    }) async {
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) => showCanonicalTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 9, minute: 30),
          ),
        ),
      );
      // `showCanonicalTimePicker` reads the ambient 12h/24h setting, so the
      // override has to sit above the picker's own context.
      if (use24h) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(alwaysUse24HourFormat: true),
            child: host(
              dark: dark,
              onTap: (context) => showCanonicalTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 9, minute: 30),
              ),
            ),
          ),
        );
      }
      await open(tester);
      return find
          .descendant(
            of: find.byType(CupertinoDatePicker),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((e) {
            final text = e.widget as Text;
            return (
              label: text.data ?? '',
              style: DefaultTextStyle.of(e).style.merge(text.style),
            );
          })
          .toList();
    }

    testWidgets('hours, minutes and AM/PM all render white', (tester) async {
      final labels = await wheelLabels(tester, dark: false);
      expect(labels, isNotEmpty);

      // Every column, not just the centred row.
      for (final entry in labels) {
        expect(
          entry.style.color,
          Colors.white,
          reason: '"${entry.label}" must be white in Light',
        );
      }

      // The three column kinds are all present and all covered above.
      // Cupertino zero-pads both numeric columns.
      expect(
        labels.any((e) => e.label == '09'),
        isTrue,
        reason: 'the hour column renders the selected hour',
      );
      expect(
        labels.any((e) => e.label == '30'),
        isTrue,
        reason: 'the minute column renders the selected minute',
      );
      expect(
        labels.any((e) => e.label == 'AM' || e.label == 'PM'),
        isTrue,
        reason: 'the meridiem column renders',
      );
    });

    testWidgets('no navy wheel text survives in Light', (tester) async {
      final labels = await wheelLabels(tester, dark: false);
      expect(
        labels.map((e) => e.style.color).toSet(),
        {Colors.white},
        reason: 'one content colour across the whole wheel',
      );
      expect(
        labels.any((e) => e.style.color == AppColors.actionNavy),
        isFalse,
      );
    });

    testWidgets('the centred value is full-opacity white, not a tint', (
      tester,
    ) async {
      final labels = await wheelLabels(tester, dark: false);
      for (final entry in labels) {
        expect(
          entry.style.color?.a,
          1.0,
          reason: '"${entry.label}" must be full opacity — the wheel\'s own '
              'off-centre fade is what softens the rows around it',
        );
        expect(entry.style.fontWeight, FontWeight.w600);
      }
    });

    testWidgets('24-hour mode keeps white digits and drops AM/PM', (
      tester,
    ) async {
      final labels = await wheelLabels(tester, dark: false, use24h: true);
      expect(labels, isNotEmpty);
      for (final entry in labels) {
        expect(entry.style.color, Colors.white);
      }
      expect(
        labels.any((e) => e.label == 'AM' || e.label == 'PM'),
        isFalse,
        reason: '24h has no meridiem column',
      );
    });

    testWidgets('Dark is unchanged: white digits at the ambient weight', (
      tester,
    ) async {
      final labels = await wheelLabels(tester, dark: true);
      expect(labels, isNotEmpty);
      for (final entry in labels) {
        expect(entry.style.color, Colors.white);
        expect(
          entry.style.fontWeight,
          isNot(FontWeight.w600),
          reason: 'the Light-only weight bump must not leak into Dark',
        );
      }
    });

    testWidgets('the selection band is unchanged', (tester) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 9, minute: 30),
          ),
        ),
      );
      await open(tester);

      // Still the canonical accent wash, not a solid fill that would swallow
      // the white digits scrolling through it.
      final bands = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CupertinoDatePicker),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color != null)
          .toList();
      expect(bands, isNotEmpty);
      for (final d in bands) {
        expect(d.color, AppColors.actionNavy.withValues(alpha: 0.12));
      }
    });
  });

  // =========================================================================
  // Continuous range path
  // =========================================================================
  group('range path', () {
    /// The band segments painted inside one day cell. Two half-cells per day:
    /// leading and trailing.
    List<Color> bandsOn(WidgetTester tester, String day) {
      final cell = find.ancestor(
        of: find.text(day),
        matching: find.byType(LayoutBuilder),
      );
      return tester
          .widgetList<ColoredBox>(
            find.descendant(of: cell.first, matching: find.byType(ColoredBox)),
          )
          .map((b) => b.color)
          .toList();
    }

    /// The solid endpoint disc, if this day has one.
    bool hasEndpoint(WidgetTester tester, String day) {
      final cell = find.ancestor(
        of: find.text(day),
        matching: find.byType(LayoutBuilder),
      );
      return tester
          .widgetList<Container>(
            find.descendant(of: cell.first, matching: find.byType(Container)),
          )
          .any((c) {
            final d = c.decoration;
            return d is BoxDecoration &&
                d.shape == BoxShape.circle &&
                d.color != null;
          });
    }

    Future<void> openRange(
      WidgetTester tester, {
      required bool dark,
      required List<String> taps,
      DateTime? first,
      DateTime? last,
    }) async {
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) => showCanonicalDateRangePicker(
            context: context,
            firstDate: first ?? DateTime(2026, 6, 1),
            lastDate: last ?? DateTime(2026, 12, 31),
          ),
        ),
      );
      await open(tester);
      for (final t in taps) {
        await tester.tap(find.text(t));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('start, middle and end form one continuous path', (
      tester,
    ) async {
      await openRange(tester, dark: false, taps: ['12', '16']);
      final band = AppColors.actionNavy.withValues(
        alpha: kCanonicalRangeBandLightOpacity,
      );

      // Start: solid endpoint, band on the trailing half only.
      expect(hasEndpoint(tester, '12'), isTrue);
      expect(bandsOn(tester, '12'), [band]);

      // Middle days: both halves banded, no endpoint — so adjacent cells meet
      // with no seam and no day becomes its own solid circle.
      for (final middle in ['13', '14', '15']) {
        expect(
          hasEndpoint(tester, middle),
          isFalse,
          reason: '$middle must not be a separate selected circle',
        );
        expect(bandsOn(tester, middle), [band, band]);
      }

      // End: solid endpoint, band on the leading half only.
      expect(hasEndpoint(tester, '16'), isTrue);
      expect(bandsOn(tester, '16'), [band]);
    });

    testWidgets('days outside the range carry no band', (tester) async {
      await openRange(tester, dark: false, taps: ['12', '16']);
      expect(bandsOn(tester, '11'), isEmpty);
      expect(bandsOn(tester, '17'), isEmpty);
      expect(hasEndpoint(tester, '11'), isFalse);
    });

    testWidgets('a lone start point draws no band yet', (tester) async {
      await openRange(tester, dark: false, taps: ['12']);
      expect(hasEndpoint(tester, '12'), isTrue);
      expect(
        bandsOn(tester, '12'),
        isEmpty,
        reason: 'nothing to connect to until an end exists',
      );
    });

    testWidgets('a single-day range is an endpoint with no band', (
      tester,
    ) async {
      // Tapping the same day twice: start then end on one date.
      await openRange(tester, dark: false, taps: ['12', '12']);
      expect(bandsOn(tester, '12'), isEmpty);
    });

    testWidgets('Light uses the navy family', (tester) async {
      await openRange(tester, dark: false, taps: ['12', '16']);
      expect(
        bandsOn(tester, '14').first,
        AppColors.actionNavy.withValues(alpha: kCanonicalRangeBandLightOpacity),
      );
    });

    testWidgets('Dark uses the mint family at the canonical alpha', (
      tester,
    ) async {
      await openRange(tester, dark: true, taps: ['12', '16']);
      expect(
        bandsOn(tester, '14').first,
        AppColors.luminousMint.withValues(
          alpha: kCanonicalRangeBandDarkOpacity,
        ),
      );
    });

    testWidgets('the path continues across a week-row boundary', (
      tester,
    ) async {
      // June 2026: the 1st is a Monday, so 7 and 8 straddle a row edge.
      await openRange(tester, dark: false, taps: ['5', '10']);
      final band = AppColors.actionNavy.withValues(
        alpha: kCanonicalRangeBandLightOpacity,
      );
      // Every middle day is fully banded regardless of which row it lands in,
      // so the band finishes cleanly at one row edge and restarts on the next.
      for (final middle in ['6', '7', '8', '9']) {
        expect(bandsOn(tester, middle), [
          band,
          band,
        ], reason: 'day $middle keeps the path across the row break');
      }
    });

    testWidgets('range state survives navigating between months', (
      tester,
    ) async {
      await openRange(tester, dark: false, taps: ['20']);

      // Forward a month, pick the end there: a cross-month range.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('July 2026'), findsOneWidget);
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // July's leading days are in-span and banded.
      final band = AppColors.actionNavy.withValues(
        alpha: kCanonicalRangeBandLightOpacity,
      );
      expect(bandsOn(tester, '2'), [band, band]);
      expect(hasEndpoint(tester, '4'), isTrue);

      // Back to June: the start endpoint and its trailing band are still there.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('June 2026'), findsOneWidget);
      expect(hasEndpoint(tester, '20'), isTrue);
      expect(bandsOn(tester, '20'), [band]);
      expect(bandsOn(tester, '25'), [band, band]);
    });

    testWidgets('a cross-month range still returns the right dates', (
      tester,
    ) async {
      DateTimeRange? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalDateRangePicker(
              context: context,
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 12, 31),
            );
          },
        ),
      );
      await open(tester);
      // The last row sits below the fold on a 600px test viewport; the sheet
      // scrolls, so bring it into view first.
      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapVisible(find.text('29'));
      await tapVisible(find.byIcon(Icons.chevron_right));
      await tapVisible(find.text('4'));
      await tapVisible(find.byType(PrimaryButton));

      expect(result?.start, DateTime(2026, 6, 29));
      expect(result?.end, DateTime(2026, 7, 4));
    });
  });

  // =========================================================================
  group('the range path is scoped to range selection only', () {
    testWidgets('the single-date picker draws no band', (tester) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDatePicker(
            context: context,
            initialDate: DateTime(2026, 6, 10),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 6, 30),
          ),
        ),
      );
      await open(tester);
      // Still the stock calendar under canonical theming — unchanged.
      expect(find.byType(CanonicalCalendarDatePicker), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
    });

    testWidgets('the DOB picker draws no band', (tester) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDateOfBirthPicker(
            context: context,
            initialDate: DateTime(2000, 5, 20),
            firstDate: DateTime(1926),
            lastDate: DateTime(2026, 9, 12),
          ),
        ),
      );
      await open(tester);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
    });

    testWidgets('the time picker is untouched', (tester) async {
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 9, minute: 30),
          ),
        ),
      );
      await open(tester);
      expect(find.byType(CanonicalCupertinoDatePicker), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsNothing);
    });
  });

  // =========================================================================
  // Light-mode white calendar content
  // =========================================================================
  group('Light calendar content is white', () {
    Future<DatePickerThemeData> calendarTheme(
      WidgetTester tester, {
      required bool dark,
    }) async {
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) => showCanonicalDatePicker(
            context: context,
            initialDate: DateTime(2026, 6, 10),
            firstDate: DateTime(2026, 6, 8),
            lastDate: DateTime(2026, 6, 20),
          ),
        ),
      );
      await open(tester);
      final context = tester.element(find.byType(CalendarDatePicker));
      return Theme.of(context).datePickerTheme;
    }

    testWidgets('normal day numbers render white, not navy', (tester) async {
      final data = await calendarTheme(tester, dark: false);
      expect(data.dayForegroundColor?.resolve({}), Colors.white);
      expect(data.dayStyle?.color, Colors.white);
      expect(data.dayForegroundColor?.resolve({}), isNot(AppColors.actionNavy));

      // And it is the *rendered* style, not only a token.
      final day = tester.widget<Text>(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('12'),
        ),
      );
      expect(day.style?.color, Colors.white);
    });

    testWidgets('the month/year heading and arrows render white', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      expect(data.subHeaderForegroundColor, Colors.white);
      expect(data.toggleButtonTextStyle?.color, Colors.white);
    });

    testWidgets('weekday labels are white at a reduced opacity', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      final weekday = data.weekdayStyle!.color!;
      expect(weekday.r, 1.0);
      expect(weekday.g, 1.0);
      expect(weekday.b, 1.0);
      expect(weekday.a, closeTo(0.80, 0.01));
      expect(weekday.a, lessThan(1.0), reason: 'a step below primary');
    });

    testWidgets('disabled dates are white at a lower opacity still', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      final disabled = data.dayForegroundColor!.resolve({
        WidgetState.disabled,
      })!;
      expect(disabled.r, 1.0);
      expect(
        disabled.a,
        lessThan(data.weekdayStyle!.color!.a),
        reason: 'disabled sits below secondary',
      );
      expect(disabled.a, closeTo(0.40, 0.01));
    });

    testWidgets('selected keeps solid navy fill with white content', (
      tester,
    ) async {
      final data = await calendarTheme(tester, dark: false);
      expect(
        data.dayBackgroundColor?.resolve({WidgetState.selected}),
        AppColors.actionNavy,
      );
      expect(
        data.dayForegroundColor?.resolve({WidgetState.selected}),
        Colors.white,
      );
    });

    testWidgets('Dark is unchanged', (tester) async {
      final data = await calendarTheme(tester, dark: true);
      expect(data.dayForegroundColor?.resolve({}), Colors.white);
      expect(
        data.dayBackgroundColor?.resolve({WidgetState.selected}),
        AppColors.luminousMint,
      );
      expect(
        data.dayForegroundColor?.resolve({WidgetState.selected}),
        AppColors.darkOnPrimary,
      );
      expect(
        data.todayBorder?.color,
        AppColors.luminousMint,
        reason: 'Dark keeps its approved mint today ring',
      );
    });
  });

  // =========================================================================
  // Paired stay fields — one date per step
  // =========================================================================
  group('stay picker', () {
    /// The default 800x600 test viewport clips the bottom of a month grid, so
    /// later days cannot be tapped. Give the sheet room, as the Hotel screen
    /// tests do.
    void tallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    int bandCount(WidgetTester tester, {required bool dark}) {
      final band = (dark ? AppColors.luminousMint : AppColors.actionNavy)
          .withValues(
            alpha: dark
                ? kCanonicalRangeBandDarkOpacity
                : kCanonicalRangeBandLightOpacity,
          );
      return tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((b) => b.color == band)
          .length;
    }

    testWidgets('the first field is a single-date step', (tester) async {
      tallViewport(tester);
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalStayDatePicker(
              context: context,
              initialDate: DateTime(2026, 6, 21),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
            );
          },
        ),
      );
      await open(tester);

      // Done is reachable straight away — no second date is demanded.
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNotNull,
      );
      expect(bandCount(tester, dark: false), 0, reason: 'no path in this step');

      // A second tap moves the single date rather than opening a range.
      await tester.tap(find.text('24'));
      await tester.pumpAndSettle();
      expect(bandCount(tester, dark: false), 0);
      await tester.tap(find.text('26'));
      await tester.pumpAndSettle();
      expect(bandCount(tester, dark: false), 0);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 6, 26));
    });

    testWidgets('the first field can start from nothing', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalStayDatePicker(
            context: context,
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 8, 31),
          ),
        ),
      );
      await open(tester);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNull,
        reason: 'nothing chosen yet',
      );
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNotNull,
      );
    });

    testWidgets('the second field opens with the first already selected', (
      tester,
    ) async {
      tallViewport(tester);
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalStayDatePicker(
              context: context,
              stayStart: DateTime(2026, 6, 21),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
              selectableRangePredicate: (start, end) => end.isAfter(start),
            );
          },
        ),
      );
      await open(tester);

      // The anchor shows, but no end yet: nothing to connect, nothing to commit.
      expect(bandCount(tester, dark: false), 0);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNull,
      );

      // 21 -> 24 paints four days as one path: 1 + 2 + 2 + 1 half-cells.
      await tester.tap(find.text('24'));
      await tester.pumpAndSettle();
      expect(bandCount(tester, dark: false), 6);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(
        result,
        DateTime(2026, 6, 24),
        reason: 'the second field returns its own date, not a range',
      );
    });

    testWidgets('the anchor cannot be moved by tapping it', (tester) async {
      tallViewport(tester);
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalStayDatePicker(
              context: context,
              stayStart: DateTime(2026, 6, 21),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
              selectableRangePredicate: (start, end) => end.isAfter(start),
            );
          },
        ),
      );
      await open(tester);

      // The anchor itself and every earlier day are refused by the caller's
      // minimum-stay rule, so they cannot become the end.
      await tester.tap(find.text('21'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onTap,
        isNull,
      );

      await tester.tap(find.text('23'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 6, 23));
    });

    testWidgets('an existing pair reopens as a path and can be changed', (
      tester,
    ) async {
      tallViewport(tester);
      DateTime? result;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalStayDatePicker(
              context: context,
              stayStart: DateTime(2026, 6, 21),
              initialDate: DateTime(2026, 6, 24),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
              selectableRangePredicate: (start, end) => end.isAfter(start),
            );
          },
        ),
      );
      await open(tester);

      expect(
        bandCount(tester, dark: false),
        6,
        reason: 'the existing 21 -> 24 stay is drawn on open',
      );

      await tester.tap(find.text('26'));
      await tester.pumpAndSettle();
      // 21 -> 26: 1 + (2 x 4 middles) + 1.
      expect(bandCount(tester, dark: false), 10);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 6, 26));
    });

    testWidgets('dismissing the second field commits nothing', (tester) async {
      tallViewport(tester);
      DateTime? result;
      var returned = false;
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) async {
            result = await showCanonicalStayDatePicker(
              context: context,
              stayStart: DateTime(2026, 6, 21),
              initialDate: DateTime(2026, 6, 24),
              firstDate: DateTime(2026, 6, 1),
              lastDate: DateTime(2026, 8, 31),
            );
            returned = true;
          },
        ),
      );
      await open(tester);
      await tester.tap(find.text('27'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
    });

    testWidgets('the stay path uses the shared Dark mint family too', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        host(
          dark: true,
          onTap: (context) => showCanonicalStayDatePicker(
            context: context,
            stayStart: DateTime(2026, 6, 21),
            initialDate: DateTime(2026, 6, 24),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 8, 31),
          ),
        ),
      );
      await open(tester);
      expect(
        bandCount(tester, dark: true),
        6,
        reason: 'one shared renderer, no Hotel-specific paint',
      );
    });

    // -----------------------------------------------------------------------
    // One canonical band, no per-caller tuning.
    // -----------------------------------------------------------------------

    Future<void> openStay21To24(
      WidgetTester tester, {
      required bool dark,
    }) async {
      tallViewport(tester);
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) => showCanonicalStayDatePicker(
            context: context,
            stayStart: DateTime(2026, 6, 21),
            initialDate: DateTime(2026, 6, 24),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 8, 31),
          ),
        ),
      );
      await open(tester);
    }

    testWidgets('the stay band is the canonical navy in Light', (tester) async {
      await openStay21To24(tester, dark: false);
      expect(bandCount(tester, dark: false), 6);
    });

    testWidgets('the stay band is the canonical mint in Dark', (tester) async {
      await openStay21To24(tester, dark: true);
      expect(bandCount(tester, dark: true), 6);
    });

    testWidgets('a paired stay and a true range paint the identical band', (
      tester,
    ) async {
      // The paired-field picker — Hotel, Hotel Detail, Car Rental, Round Trip.
      await openStay21To24(tester, dark: false);
      final stayColors = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toSet();

      // The one-sheet range picker — Explore Tours.
      tallViewport(tester);
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalDateRangePicker(
            context: context,
            initialRange: DateTimeRange(
              start: DateTime(2026, 6, 21),
              end: DateTime(2026, 6, 24),
            ),
            firstDate: DateTime(2026, 6, 1),
            lastDate: DateTime(2026, 8, 31),
          ),
        ),
      );
      await open(tester);
      final rangeColors = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toSet();

      expect(
        stayColors.contains(
          AppColors.actionNavy.withValues(
            alpha: kCanonicalRangeBandLightOpacity,
          ),
        ),
        isTrue,
      );
      expect(
        rangeColors,
        stayColors,
        reason: 'one canonical range appearance, not one per caller',
      );
    });

    // -----------------------------------------------------------------------
    // Painted geometry.
    //
    // Everything above counts `ColoredBox` widgets. That is what let a real
    // bug ship: the band strips were built, correctly assigned, and laid out
    // at **zero height**, so every count passed while the device showed two
    // lone endpoints and nothing between them. These tests assert the rect
    // each cell actually paints.
    // -----------------------------------------------------------------------

    /// The cell that renders [day] — the `LayoutBuilder` each `_DayCell`
    /// builds, which is also the box the grid sized.
    Finder cellFor(String day) => find
        .ancestor(of: find.text(day), matching: find.byType(LayoutBuilder))
        .first;

    /// The band rectangles actually painted inside [day]'s cell, in the cell's
    /// own coordinates, left to right.
    List<Rect> bandRectsIn(WidgetTester tester, String day) {
      final cell = cellFor(day);
      final origin = tester.getTopLeft(cell);
      final rects =
          find
              .descendant(of: cell, matching: find.byType(ColoredBox))
              .evaluate()
              .map((e) {
                final box = e.renderObject! as RenderBox;
                return (box.localToGlobal(Offset.zero) - origin) & box.size;
              })
              .toList()
            ..sort((a, b) => a.left.compareTo(b.left));
      return rects;
    }

    /// Whether [day] paints a solid selected endpoint disc.
    bool hasEndpointDisc(
      WidgetTester tester,
      String day, {
      required bool dark,
    }) {
      final fill = dark ? AppColors.luminousMint : AppColors.actionNavy;
      return find
          .descendant(of: cellFor(day), matching: find.byType(Container))
          .evaluate()
          .any((e) {
            final d = (e.widget as Container).decoration;
            return d is BoxDecoration &&
                d.shape == BoxShape.circle &&
                d.color == fill;
          });
    }

    Future<void> openStay15To18(
      WidgetTester tester, {
      bool dark = false,
    }) async {
      tallViewport(tester);
      await tester.pumpWidget(
        host(
          dark: dark,
          onTap: (context) => showCanonicalStayDatePicker(
            context: context,
            stayStart: DateTime(2026, 9, 15),
            initialDate: DateTime(2026, 9, 18),
            firstDate: DateTime(2026, 9, 1),
            lastDate: DateTime(2026, 11, 30),
            selectableRangePredicate: (start, end) => end.isAfter(start),
          ),
        ),
      );
      await open(tester);
    }

    testWidgets(
      '15 -> 18: the middle days paint a full-width, full-height band',
      (tester) async {
        await openStay15To18(tester);

        final cellWidth = tester.getSize(cellFor('16')).width;
        final band = AppColors.actionNavy.withValues(
          alpha: kCanonicalRangeBandLightOpacity,
        );

        for (final middle in ['16', '17']) {
          final rects = bandRectsIn(tester, middle);
          expect(rects.length, 2, reason: '$middle: both halves banded');

          // The regression itself: these were 24.6 x 0.0 on the device.
          for (final r in rects) {
            expect(
              r.height,
              greaterThan(0),
              reason: '$middle: a zero-height band paints nothing',
            );
          }
          expect(rects.first.height, rects.last.height);

          // Edge to edge, the two halves meeting exactly — no seam.
          expect(
            rects.first.left,
            moreOrLessEquals(0, epsilon: 0.5),
            reason: '$middle: band starts at the left cell edge',
          );
          expect(
            rects.last.right,
            moreOrLessEquals(cellWidth, epsilon: 0.5),
            reason: '$middle: band reaches the right cell edge',
          );
          expect(
            rects.first.right,
            moreOrLessEquals(rects.last.left, epsilon: 0.5),
            reason: '$middle: the two halves meet with no gap',
          );

          // Same family, and classified as a middle day, not an endpoint.
          for (final e
              in find
                  .descendant(
                    of: cellFor(middle),
                    matching: find.byType(ColoredBox),
                  )
                  .evaluate()) {
            expect((e.widget as ColoredBox).color, band);
          }
          expect(
            hasEndpointDisc(tester, middle, dark: false),
            isFalse,
            reason: '$middle is a middle day, not an endpoint',
          );
        }
      },
    );

    testWidgets('15 -> 18: endpoints band inward only and keep their disc', (
      tester,
    ) async {
      await openStay15To18(tester);

      final cellWidth = tester.getSize(cellFor('15')).width;

      // 15 = start: centre -> right edge, plus the solid disc.
      final startRects = bandRectsIn(tester, '15');
      expect(startRects.length, 1);
      expect(startRects.single.height, greaterThan(0));
      expect(
        startRects.single.left,
        moreOrLessEquals(cellWidth / 2, epsilon: 0.5),
        reason: '15: the band leaves from the centre, not the left edge',
      );
      expect(
        startRects.single.right,
        moreOrLessEquals(cellWidth, epsilon: 0.5),
      );
      expect(hasEndpointDisc(tester, '15', dark: false), isTrue);

      // 18 = end: left edge -> centre, plus the solid disc.
      final endRects = bandRectsIn(tester, '18');
      expect(endRects.length, 1);
      expect(endRects.single.height, greaterThan(0));
      expect(endRects.single.left, moreOrLessEquals(0, epsilon: 0.5));
      expect(
        endRects.single.right,
        moreOrLessEquals(cellWidth / 2, epsilon: 0.5),
        reason: '18: the band arrives at the centre, not the right edge',
      );
      expect(hasEndpointDisc(tester, '18', dark: false), isTrue);

      // The days either side of the stay are untouched.
      expect(bandRectsIn(tester, '14'), isEmpty);
      expect(bandRectsIn(tester, '19'), isEmpty);
    });

    testWidgets('15 -> 18 is one continuous path across the row', (
      tester,
    ) async {
      await openStay15To18(tester);

      final rects = ['15', '16', '17', '18'].expand((d) {
        final origin = tester.getTopLeft(cellFor(d));
        return bandRectsIn(tester, d).map((r) => r.shift(origin));
      }).toList()..sort((a, b) => a.left.compareTo(b.left));

      expect(rects.length, 6);
      // Height first: six contiguous zero-height rects are still "contiguous",
      // which is how the original bug slipped past a continuity check.
      for (final r in rects) {
        expect(r.height, greaterThan(0));
      }
      for (var i = 1; i < rects.length; i++) {
        expect(
          rects[i].left,
          moreOrLessEquals(rects[i - 1].right, epsilon: 0.5),
          reason: 'a gap between segment ${i - 1} and $i breaks the path',
        );
        expect(rects[i].top, moreOrLessEquals(rects[i - 1].top, epsilon: 0.5));
        expect(
          rects[i].height,
          moreOrLessEquals(rects[i - 1].height, epsilon: 0.5),
        );
      }

      // The path spans from the centre of 15 to the centre of 18.
      final startCell = tester.getRect(cellFor('15'));
      final endCell = tester.getRect(cellFor('18'));
      expect(
        rects.first.left,
        moreOrLessEquals(startCell.center.dx, epsilon: 0.5),
      );
      expect(
        rects.last.right,
        moreOrLessEquals(endCell.center.dx, epsilon: 0.5),
      );
    });

    testWidgets('the band paints under the endpoint disc, never over it', (
      tester,
    ) async {
      await openStay15To18(tester);
      final children = tester
          .widget<Stack>(
            find
                .descendant(of: cellFor('15'), matching: find.byType(Stack))
                .first,
          )
          .children;
      final bandIndex = children.indexWhere(
        (w) => w is SizedBox && w.height != null,
      );
      final discIndex = children.indexWhere(
        (w) =>
            w is Container &&
            (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
      expect(bandIndex, isNonNegative);
      expect(
        discIndex,
        greaterThan(bandIndex),
        reason: 'the solid endpoint must be painted above the band',
      );
    });

    testWidgets('a row boundary breaks the band, not the selection', (
      tester,
    ) async {
      // Sep 2026: the 26th is a Saturday, so a 25 -> 29 stay wraps a row.
      tallViewport(tester);
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalStayDatePicker(
            context: context,
            stayStart: DateTime(2026, 9, 25),
            initialDate: DateTime(2026, 9, 29),
            firstDate: DateTime(2026, 9, 1),
            lastDate: DateTime(2026, 11, 30),
            selectableRangePredicate: (start, end) => end.isAfter(start),
          ),
        ),
      );
      await open(tester);

      // Every banded day still paints, with real height, on both rows.
      for (final day in ['25', '26', '27', '28', '29']) {
        final rects = bandRectsIn(tester, day);
        expect(rects, isNotEmpty, reason: '$day: banded on its own row');
        for (final r in rects) {
          expect(r.height, greaterThan(0), reason: day);
        }
      }

      // The rows are genuinely different rows, and the band stops at the edge
      // of the first rather than running off it.
      final firstRowTop = tester.getRect(cellFor('26')).top;
      final secondRowTop = tester.getRect(cellFor('27')).top;
      expect(
        secondRowTop,
        greaterThan(firstRowTop),
        reason: 'Sep 27 2026 starts a new week row',
      );

      final lastOfRow = tester.getRect(cellFor('26'));
      final lastBand = bandRectsIn(tester, '26').last.shift(lastOfRow.topLeft);
      expect(
        lastBand.right,
        moreOrLessEquals(lastOfRow.right, epsilon: 0.5),
        reason: 'the band ends flush with the row edge',
      );

      final firstOfNextRow = tester.getRect(cellFor('27'));
      final nextBand = bandRectsIn(
        tester,
        '27',
      ).first.shift(firstOfNextRow.topLeft);
      expect(
        nextBand.left,
        moreOrLessEquals(firstOfNextRow.left, epsilon: 0.5),
        reason: 'and resumes flush with the next row edge',
      );
    });

    testWidgets('a cross-month stay survives month navigation', (
      tester,
    ) async {
      // Sep 29 -> Oct 4.
      tallViewport(tester);
      await tester.pumpWidget(
        host(
          dark: false,
          onTap: (context) => showCanonicalStayDatePicker(
            context: context,
            stayStart: DateTime(2026, 9, 29),
            initialDate: DateTime(2026, 10, 4),
            firstDate: DateTime(2026, 9, 1),
            lastDate: DateTime(2026, 12, 31),
            selectableRangePredicate: (start, end) => end.isAfter(start),
          ),
        ),
      );
      await open(tester);

      // Opens on the end's month: the in-span days and the end endpoint.
      expect(find.text('October 2026'), findsOneWidget);
      for (final day in ['1', '2', '3', '4']) {
        final rects = bandRectsIn(tester, day);
        expect(rects, isNotEmpty, reason: 'Oct $day is part of the stay');
        for (final r in rects) {
          expect(r.height, greaterThan(0));
        }
      }
      expect(hasEndpointDisc(tester, '4', dark: false), isTrue);
      expect(bandRectsIn(tester, '5'), isEmpty);

      // Back to September: the start endpoint and its trailing band.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(hasEndpointDisc(tester, '29', dark: false), isTrue);
      for (final day in ['29', '30']) {
        final rects = bandRectsIn(tester, day);
        expect(rects, isNotEmpty, reason: 'Sep $day is part of the stay');
        for (final r in rects) {
          expect(r.height, greaterThan(0));
        }
      }
      expect(bandRectsIn(tester, '28'), isEmpty);

      // Forward again: the state is intact, not rebuilt from scratch.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(hasEndpointDisc(tester, '4', dark: false), isTrue);
      expect(bandRectsIn(tester, '2'), hasLength(2));

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
    });

    testWidgets('Dark paints the same geometry in mint', (tester) async {
      await openStay15To18(tester, dark: true);
      final rects = bandRectsIn(tester, '16');
      expect(rects.length, 2);
      expect(rects.first.height, greaterThan(0));
      for (final e
          in find
              .descendant(of: cellFor('16'), matching: find.byType(ColoredBox))
              .evaluate()) {
        expect(
          (e.widget as ColoredBox).color,
          AppColors.luminousMint.withValues(
            alpha: kCanonicalRangeBandDarkOpacity,
          ),
        );
      }
      expect(hasEndpointDisc(tester, '15', dark: true), isTrue);
    });
  });
}
