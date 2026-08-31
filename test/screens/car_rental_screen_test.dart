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

  testWidgets('car tap returns the typed vehicle selection', (tester) async {
    RentalVehicle? selected;
    await tester.pumpWidget(_app(onSelected: (vehicle) => selected = vehicle));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Toyota Corolla'),
      300,
      scrollable: _pageScrollable(),
    );
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

    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    await tester.tap(find.text('Select date').first);
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(tomorrow);
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select time').first);
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2020, 1, 1, 10));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(tomorrow);
    await tester.pump();
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
  final tomorrow = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  await tester.tap(find.byKey(const Key('car-pickup-location')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).last, 'Erbil');
  await tester.pump(const Duration(milliseconds: 301));
  await tester.pump(const Duration(milliseconds: 221));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Erbil International Airport').last);
  await tester.pumpAndSettle();

  for (var index = 0; index < 2; index++) {
    await tester.tap(find.text('Select date').first);
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(tomorrow.add(Duration(days: index)));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select time').first);
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2020, 1, 1, 10 + index * 2));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }
}

Finder _pageScrollable() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;
