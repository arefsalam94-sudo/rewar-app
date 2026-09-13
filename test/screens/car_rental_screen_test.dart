import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/car_rental.dart';
import 'package:kurdistan_paradise_travel_guide/screens/car_rental_details_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/car_rental_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/device_location_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/canonical_date_time_picker.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';

class _NoLocationService extends DeviceLocationService {
  const _NoLocationService();

  @override
  Future<DeviceLocation?> currentLocation() async => null;
}

class _CapturingCarRentalService implements CarRentalService {
  CarRentalSearchCriteria? criteria;

  @override
  Future<List<RentalVehicle>> trendingCars() async =>
      PreviewCarRentalService.vehicles;

  @override
  Future<List<RentalVehicle>> searchCars(
    CarRentalSearchCriteria criteria,
  ) async {
    this.criteria = criteria;
    return PreviewCarRentalService.vehicles;
  }

  @override
  Future<List<RentalLocation>> searchLocations(String query) =>
      const PreviewCarRentalService().searchLocations(query);
}

Widget _app({
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  ValueChanged<RentalVehicle>? onSelected,
  CarRentalService service = const PreviewCarRentalService(),
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  themeMode: themeMode,
  home: CarRentalScreen(
    service: service,
    locationService: const _NoLocationService(),
    onVehicleSelected: onSelected,
  ),
);

void main() {
  testWidgets('renders the reference sections and preview cars', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Car Rental'), findsOneWidget);
    expect(find.text('Pick-up – Drop-off Location'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Trending Cars'),
      300,
      scrollable: _pageScrollable(),
    );
    expect(find.text('Trending Cars'), findsOneWidget);
    expect(find.text('Tesla Model 3'), findsOneWidget);
    expect(find.text(r'$56/day'), findsOneWidget);
  });

  testWidgets('different drop-off animates in a second location field', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('car-dropoff-location')), findsNothing);
    await tester.ensureVisible(find.text('Drop off in a different location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drop off in a different location'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('car-dropoff-location')), findsOneWidget);
  });

  testWidgets('pickup opens searchable preview locations', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('car-pickup-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Erbil');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump(const Duration(milliseconds: 221));
    await tester.pumpAndSettle();

    expect(find.text('Erbil International Airport'), findsOneWidget);
    await tester.tap(find.text('Erbil International Airport').last);
    await tester.pumpAndSettle();
    expect(find.text('Erbil International Airport'), findsOneWidget);
  });

  testWidgets('carousel updates its company badge when swiped', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('ABC Cars'), findsWidgets);
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Paradise Rent A Car'), findsWidgets);
  });

  testWidgets('empty search shows localized validation', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Search'));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Please choose a pick-up location'), findsOneWidget);
    expect(find.text('Please choose a pick-up date'), findsOneWidget);
    expect(find.text('Please choose a drop-off date'), findsOneWidget);
  });

  testWidgets('pick-up and return are two steps and both remain visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final range = await _selectRentalRange(tester);
    final formatter = MaterialLocalizations.of(
      tester.element(find.byType(CarRentalScreen)),
    );
    final pickupLabel = formatter.formatMediumDate(range.start);
    final returnLabel = formatter.formatMediumDate(range.end);
    expect(find.text(pickupLabel), findsOneWidget);
    expect(find.text(returnLabel), findsOneWidget);
    expect(find.text('Pick-up'), findsWidgets);
    expect(find.text('Drop-off'), findsWidgets);

    // Return reopens anchored to the pick-up, so the rental period it already
    // describes is drawn before anything is tapped.
    await tester.tap(find.text(returnLabel));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(_lightRangeBandCount(tester), greaterThan(0));
    await tester.tapAt(const Offset(30, 30));
    await tester.pumpAndSettle();
    expect(find.text(pickupLabel), findsOneWidget);
    expect(find.text(returnLabel), findsOneWidget);
  });

  testWidgets('car tap returns the typed vehicle selection', (tester) async {
    RentalVehicle? selected;
    await tester.pumpWidget(_app(onSelected: (vehicle) => selected = vehicle));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Toyota Corolla'),
      300,
      scrollable: _pageScrollable(),
    );
    // scrollUntilVisible stops as soon as the widget is attached, which can
    // still leave it a few pixels below the viewport; settle it fully into
    // view before tapping, as the search test above already does.
    await tester.ensureVisible(find.text('Toyota Corolla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toyota Corolla'));
    await tester.pump();

    expect(selected?.id, 'preview-car-toyota-corolla');
  });

  testWidgets('valid search opens the results page with the typed criteria', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _CapturingCarRentalService();
    await tester.pumpWidget(_app(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('car-pickup-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Erbil');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump(const Duration(milliseconds: 221));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erbil International Airport').last);
    await tester.pumpAndSettle();

    await _selectRentalRange(tester);

    await tester.tap(find.text('Select time').first);
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2020, 1, 1, 10));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select time'));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2020, 1, 1, 12));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Search'));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(service.criteria, isNotNull);
    expect(service.criteria!.sameLocation, isTrue);
    expect(service.criteria!.pickupLocation.id, 'preview-erbil-airport');
    // The results page is now on top, showing the count derived from the list.
    expect(find.text('5 Results'), findsOneWidget);

    // Back returns to the form with the entered values still selected.
    await tester.tap(find.byType(GlassBackButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Erbil International Airport'), findsWidgets);
    expect(find.text('Select date'), findsNothing);
  });

  testWidgets('supports Arabic RTL and dark mode', (tester) async {
    await tester.pumpWidget(
      _app(locale: const Locale('ar'), themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('تأجير السيارات'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('تأجير السيارات'))),
      TextDirection.rtl,
    );
  });

  testWidgets('small phone and large text scroll without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('BMW X5'),
      300,
      scrollable: _pageScrollable(),
    );
    expect(find.text('BMW X5'), findsOneWidget);
  });

  testWidgets(
    'a car tap with an incomplete form validates instead of pushing',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tesla Model 3').first);
      await tester.pumpAndSettle();

      expect(find.byType(CarRentalDetailsScreen), findsNothing);
      expect(find.text('Please choose a pick-up location'), findsOneWidget);
    },
  );

  testWidgets('a car tap on a completed form opens that car\'s details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _fillSearchForm(tester);

    await tester.tap(find.text('Tesla Model 3').first);
    await tester.pumpAndSettle();

    expect(find.byType(CarRentalDetailsScreen), findsOneWidget);
    expect(find.text('Tesla Model 3'), findsWidgets);
  });
}

/// Fills every required field on the search card, so a test can exercise what
/// happens once the form validates.
Future<void> _fillSearchForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('car-pickup-location')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).last, 'Erbil');
  await tester.pump(const Duration(milliseconds: 301));
  await tester.pump(const Duration(milliseconds: 221));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Erbil International Airport').last);
  await tester.pumpAndSettle();

  await _selectRentalRange(tester);
  for (var index = 0; index < 2; index++) {
    await tester.tap(find.text('Select time').first);
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2020, 1, 1, 10 + index * 2));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }
}

/// Fills Pick-up then Drop-off the way the screen now asks for them: two
/// separate fields, two separate single-date steps.
///
/// Pick-up is chosen on its own with no path on screen; Drop-off then opens
/// with the pick-up already selected and paints the whole rental period.
Future<DateTimeRange> _selectRentalRange(WidgetTester tester) async {
  final today = DateUtils.dateOnly(DateTime.now());
  final targetMonth = DateTime(today.year, today.month + 1);
  final range = DateTimeRange(
    start: DateTime(targetMonth.year, targetMonth.month, 12),
    end: DateTime(targetMonth.year, targetMonth.month, 16),
  );

  // --- Pick-up: one date, no range ------------------------------------------
  await tester.tap(find.text('Select date').first);
  await tester.pumpAndSettle();
  expect(
    find.byType(CalendarDatePicker),
    findsNothing,
    reason: 'paired rental dates must use the canonical range calendar',
  );
  await tester.tap(find.byIcon(Icons.chevron_right));
  await tester.pumpAndSettle();
  await tester.tap(find.text('12'));
  await tester.pumpAndSettle();
  expect(
    _lightRangeBandCount(tester),
    0,
    reason: 'the pick-up step is a single date, not a rental period',
  );
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();

  // --- Drop-off: anchored to the pick-up, path appears ----------------------
  // No month step here: the drop-off picker opens on the pick-up's own month,
  // which is the point of anchoring it.
  await tester.tap(find.text('Select date').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('16'));
  await tester.pumpAndSettle();
  expect(
    _lightRangeBandCount(tester),
    greaterThan(0),
    reason: 'choosing the return must draw the whole rental period',
  );
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
  return range;
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

Finder _pageScrollable() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;
