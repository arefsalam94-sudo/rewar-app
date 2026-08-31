import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/car_rental.dart';
import 'package:kurdistan_paradise_travel_guide/screens/car_rental_results_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/device_location_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';

class _NoLocationService extends DeviceLocationService {
  const _NoLocationService();

  @override
  Future<DeviceLocation?> currentLocation() async => null;
}

class _FixedLocationService extends DeviceLocationService {
  const _FixedLocationService();

  @override
  Future<DeviceLocation?> currentLocation() async =>
      const DeviceLocation(36.2088, 43.9891);
}

/// Returns whatever the test hands it, and records the criteria it received.
class _StubCarRentalService implements CarRentalService {
  _StubCarRentalService(this.result);

  final List<RentalVehicle> result;
  CarRentalSearchCriteria? criteria;
  int searchCalls = 0;

  @override
  Future<List<RentalVehicle>> trendingCars() async => result;

  @override
  Future<List<RentalVehicle>> searchCars(
    CarRentalSearchCriteria criteria,
  ) async {
    this.criteria = criteria;
    searchCalls++;
    return result;
  }

  @override
  Future<List<RentalLocation>> searchLocations(String query) async => const [];
}

class _FailingCarRentalService implements CarRentalService {
  int searchCalls = 0;

  @override
  Future<List<RentalVehicle>> trendingCars() async => const [];

  @override
  Future<List<RentalVehicle>> searchCars(
    CarRentalSearchCriteria criteria,
  ) async {
    searchCalls++;
    throw StateError('supplier unavailable');
  }

  @override
  Future<List<RentalLocation>> searchLocations(String query) async => const [];
}

final _criteria = CarRentalSearchCriteria(
  pickupLocation: PreviewCarRentalService.erbilAirport,
  dropOffLocation: PreviewCarRentalService.erbilAirport,
  sameLocation: true,
  pickupDateTime: DateTime(2026, 9, 1, 10),
  dropOffDateTime: DateTime(2026, 9, 4, 12),
);

Widget _app({
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  CarRentalService? service,
  DeviceLocationService locationService = const _NoLocationService(),
  ValueChanged<CarRentalSelection>? onSelected,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  // The app's own delegate list, so the Kurdish fallbacks are present.
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  themeMode: themeMode,
  home: CarRentalResultsScreen(
    criteria: _criteria,
    service: service ?? const PreviewCarRentalService(),
    locationService: locationService,
    onVehicleSelected: onSelected,
  ),
);

void main() {
  testWidgets('five mock cars render and the badge counts them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _StubCarRentalService(PreviewCarRentalService.vehicles);
    await tester.pumpWidget(_app(service: service));
    await tester.pumpAndSettle();

    expect(service.searchCalls, 1);
    expect(service.criteria, same(_criteria));
    expect(find.text('5 Results'), findsOneWidget);
    expect(find.byType(CarResultCard), findsWidgets);
    expect(find.text('Tesla Model 3'), findsOneWidget);
    expect(find.text('(Model 2026)'), findsWidgets);
    expect(find.text('ABC Cars'), findsWidgets);
    expect(find.text('4 persons'), findsWidgets);
    expect(find.text('2 bags'), findsWidgets);
    expect(find.text('AC'), findsWidgets);
    expect(find.text('Pay at pickup'), findsWidgets);
    expect(find.text('Wavy Avenue, near Empire Pearl'), findsWidgets);
    expect(find.text(r'$56/day', findRichText: true), findsOneWidget);
  });

  testWidgets('a single result uses the singular count', (tester) async {
    final service = _StubCarRentalService([
      PreviewCarRentalService.vehicles.first,
    ]);
    await tester.pumpWidget(_app(service: service));
    await tester.pumpAndSettle();

    expect(find.text('1 Result'), findsOneWidget);
    expect(find.text('5 Results'), findsNothing);
  });

  testWidgets('no results shows the empty state and a modify action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(service: _StubCarRentalService(const [])));
    await tester.pumpAndSettle();

    expect(find.text('0 Results'), findsOneWidget);
    expect(find.text('No cars found'), findsOneWidget);
    expect(
      find.text('No cars found for your selected dates and location.'),
      findsOneWidget,
    );
    expect(find.text('Modify Search'), findsOneWidget);
    expect(find.byType(CarResultCard), findsNothing);
  });

  testWidgets('a failed search shows a friendly error and retries', (
    tester,
  ) async {
    final service = _FailingCarRentalService();
    await tester.pumpWidget(_app(service: service));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load available cars"), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.textContaining('supplier unavailable'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.searchCalls, 2);
  });

  testWidgets('a skeleton is shown while the search runs', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(CarResultCard), findsNothing);
    expect(find.text('5 Results'), findsNothing);

    // The preview service answers after a simulated network delay.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('5 Results'), findsOneWidget);
    expect(find.byType(CarResultCard), findsWidgets);
  });

  testWidgets('tapping a card reports the car with its search criteria', (
    tester,
  ) async {
    CarRentalSelection? selection;
    await tester.pumpWidget(
      _app(
        service: _StubCarRentalService(PreviewCarRentalService.vehicles),
        onSelected: (value) => selection = value,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tesla Model 3'));
    await tester.pump();

    expect(selection, isNotNull);
    expect(selection!.vehicle.id, 'preview-car-tesla-model-3');
    expect(selection!.criteria, same(_criteria));
  });

  testWidgets('distance is hidden when the device position is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(service: _StubCarRentalService(PreviewCarRentalService.vehicles)),
    );
    await tester.pumpAndSettle();

    // The cars are still listed — a denied permission never blocks results.
    expect(find.byType(CarResultCard), findsWidgets);
    expect(find.textContaining('from current location'), findsNothing);
  });

  testWidgets('distance is shown once the device position arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        service: _StubCarRentalService(PreviewCarRentalService.vehicles),
        locationService: const _FixedLocationService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('from current location'), findsWidgets);
  });

  testWidgets('renders in Arabic RTL and in dark mode', (tester) async {
    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        themeMode: ThemeMode.dark,
        service: _StubCarRentalService(PreviewCarRentalService.vehicles),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.text('5 نتائج');
    expect(badge, findsOneWidget);
    expect(Directionality.of(tester.element(badge)), TextDirection.rtl);
  });

  testWidgets('renders in Kurdish', (tester) async {
    await tester.pumpWidget(
      _app(
        locale: const Locale('ku'),
        service: _StubCarRentalService(PreviewCarRentalService.vehicles),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5 ئەنجام'), findsOneWidget);
  });

  testWidgets('small phone with large text scrolls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _app(service: _StubCarRentalService(PreviewCarRentalService.vehicles)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('BMW X5'), 300);
    expect(find.text('BMW X5'), findsOneWidget);
  });

  testWidgets('a missing image falls back to the vehicle glyph', (
    tester,
  ) async {
    final broken = RentalVehicle(
      id: 'broken-image',
      name: const RentalText(en: 'No Photo Car', ku: 'بێ وێنە', ar: 'بلا صورة'),
      modelYear: 2025,
      company: PreviewCarRentalService.vehicles.first.company,
      images: const ['assets/images/does-not-exist.webp'],
      passengers: 4,
      bags: 1,
      powertrain: RentalPowertrain.diesel,
      transmission: RentalTransmission.manual,
      airConditioning: false,
      paymentOption: RentalPaymentOption.payNow,
      location: PreviewCarRentalService.wavyAvenue,
      dailyPrice: 25,
      currencyCode: 'USD',
      featured: false,
    );
    await tester.pumpWidget(_app(service: _StubCarRentalService([broken])));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.directions_car_outlined), findsWidgets);
    // An absent facility is left out rather than shown as a negative.
    expect(find.text('AC'), findsNothing);
    expect(find.text('Pay now'), findsOneWidget);
  });
}
