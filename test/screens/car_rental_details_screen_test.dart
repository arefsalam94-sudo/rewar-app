import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/car_rental.dart';
import 'package:kurdistan_paradise_travel_guide/screens/car_rental_details_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/car_rental_results_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/rental_details_parts.dart';

/// Tesla Model 3 — five gallery photos, six extras, $56/day.
final _vehicle = PreviewCarRentalService.vehicles.first;

CarRentalSearchCriteria _criteria({
  bool sameLocation = true,
  DateTime? pickup,
  DateTime? dropOff,
}) => CarRentalSearchCriteria(
  pickupLocation: PreviewCarRentalService.erbilAirport,
  dropOffLocation: sameLocation
      ? PreviewCarRentalService.erbilAirport
      : PreviewCarRentalService.duhokCenter,
  sameLocation: sameLocation,
  pickupDateTime: pickup ?? DateTime(2026, 9, 1, 10),
  dropOffDateTime: dropOff ?? DateTime(2026, 9, 3, 10),
);

Widget _app({
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  RentalVehicle? vehicle,
  CarRentalSearchCriteria? criteria,
  ValueChanged<CarRentalSelection>? onApply,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  // The app's own delegate list, so the Kurdish fallbacks are present.
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  themeMode: themeMode,
  home: CarRentalDetailsScreen(
    selection: CarRentalSelection(
      criteria: criteria ?? _criteria(),
      vehicle: vehicle ?? _vehicle,
    ),
    onApply: onApply,
  ),
);

void _sizeForPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders the selected car, its supplier and its facilities', (
    tester,
  ) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Tesla Model 3'), findsOneWidget);
    expect(find.text('(Model 2026)'), findsOneWidget);
    expect(find.text('ABC Cars'), findsOneWidget);
    expect(find.text('4 persons'), findsOneWidget);
    expect(find.text('2 bags'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    // The facility added for this screen, from the model rather than the
    // reference screenshot's wording.
    expect(find.text('Automatic'), findsOneWidget);
  });

  testWidgets('restates the search without asking for it again', (
    tester,
  ) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Pick-up'), findsOneWidget);
    expect(find.text('Drop-off'), findsOneWidget);
    // Same pick-up and drop-off branch collapses to one address row.
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Pick-up location'), findsNothing);
    expect(find.text('Erbil International Airport'), findsOneWidget);
    // Rendered with MaterialLocalizations.formatMediumDate — the identical
    // string the search form showed when the user picked the date.
    expect(find.text('Tue, Sep 1'), findsOneWidget);
    expect(find.text('Thu, Sep 3'), findsOneWidget);
  });

  testWidgets('different branches show both locations', (tester) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app(criteria: _criteria(sameLocation: false)));
    await tester.pumpAndSettle();

    expect(find.text('Location'), findsNothing);
    expect(find.text('Pick-up location'), findsOneWidget);
    expect(find.text('Drop-off location'), findsOneWidget);
    expect(find.text('Duhok City Centre'), findsOneWidget);
  });

  testWidgets('the gallery swipes and the dots follow', (tester) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_vehicle.images.length, 5);
    expect(find.byType(RentalCarouselDots), findsOneWidget);
    expect(
      tester
          .widget<RentalCarouselDots>(find.byType(RentalCarouselDots))
          .current,
      0,
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<RentalCarouselDots>(find.byType(RentalCarouselDots))
          .current,
      1,
    );
  });

  testWidgets('a single photo shows no dots at all', (tester) async {
    _sizeForPhone(tester);
    final single = RentalVehicle(
      id: 'single-photo',
      name: const RentalText(en: 'One Photo', ku: 'یەک وێنە', ar: 'صورة واحدة'),
      modelYear: 2026,
      company: _vehicle.company,
      images: const ['assets/images/journey-car.png'],
      passengers: 4,
      bags: 2,
      powertrain: RentalPowertrain.petrol,
      transmission: RentalTransmission.manual,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payNow,
      location: PreviewCarRentalService.wavyAvenue,
      dailyPrice: 40,
      currencyCode: 'USD',
      featured: false,
    );
    await tester.pumpWidget(_app(vehicle: single));
    await tester.pumpAndSettle();

    expect(find.byType(RentalCarouselDots), findsNothing);
    expect(find.text('Manual'), findsOneWidget);
  });

  testWidgets('ticking an extra adds it to the estimated total', (
    tester,
  ) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // 2 rental days × $56. With no extras the base row and the total row
    // legitimately carry the same number.
    expect(find.text('\$112'), findsNWidgets(2));
    expect(find.text('Extras'), findsNothing);

    await tester.tap(find.text('Mini Damage Protection'));
    await tester.pumpAndSettle();

    // $10/day × 2 days, and the total moves with it.
    expect(find.text('Extras'), findsOneWidget);
    expect(find.text('\$20'), findsOneWidget);
    expect(find.text('\$132'), findsOneWidget);
  });

  testWidgets('the baby seat stepper stops at 0 and at its maximum', (
    tester,
  ) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final babySeatRow = find.ancestor(
      of: find.text('Baby Seat'),
      matching: find.byType(RentalOptionRow),
    );
    final plus = find.descendant(
      of: babySeatRow,
      matching: find.widgetWithIcon(IconButton, Icons.add),
    );
    final minus = find.descendant(
      of: babySeatRow,
      matching: find.widgetWithIcon(IconButton, Icons.remove),
    );

    // At zero the minus button is disabled, not merely dimmed.
    expect(tester.widget<IconButton>(minus).onPressed, isNull);

    for (var tap = 0; tap < 3; tap++) {
      await tester.tap(plus);
      await tester.pumpAndSettle();
    }
    expect(
      find.descendant(of: babySeatRow, matching: find.text('3')),
      findsOneWidget,
    );
    // Supplier ceiling of 3 — the plus button disables rather than running on.
    expect(tester.widget<IconButton>(plus).onPressed, isNull);
    expect(tester.widget<IconButton>(minus).onPressed, isNotNull);

    // $5/day × 3 seats × 2 days restated on the row itself.
    expect(find.text('\$5/day × 3'), findsOneWidget);
  });

  testWidgets('no supplier terms means no Rental Conditions card', (
    tester,
  ) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Preview data carries no conditions, and nothing is invented to fill it.
    expect(_vehicle.conditions.isEmpty, isTrue);
    expect(find.text('Rental Conditions'), findsNothing);
  });

  testWidgets('conditions appear row by row as real data arrives', (
    tester,
  ) async {
    _sizeForPhone(tester);
    final withTerms = RentalVehicle(
      id: 'with-terms',
      name: const RentalText(en: 'Termed Car', ku: 'مەرجدار', ar: 'بشروط'),
      modelYear: 2026,
      company: _vehicle.company,
      images: _vehicle.images,
      passengers: 4,
      bags: 2,
      powertrain: RentalPowertrain.petrol,
      transmission: RentalTransmission.automatic,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payNow,
      location: PreviewCarRentalService.wavyAvenue,
      dailyPrice: 40,
      currencyCode: 'USD',
      featured: false,
      conditions: const RentalConditions(
        fuelPolicy: RentalFuelPolicy.fullToFull,
        mileagePolicy: RentalMileagePolicy(unlimited: true),
        depositAmount: 250,
        guaranteedModel: false,
      ),
    );
    await tester.pumpWidget(_app(vehicle: withTerms));
    await tester.pumpAndSettle();

    expect(find.text('Rental Conditions'), findsOneWidget);
    expect(find.text('Full to full'), findsOneWidget);
    expect(find.text('Unlimited'), findsOneWidget);
    expect(find.text('\$250'), findsOneWidget);
    expect(find.text('This model or a similar vehicle'), findsOneWidget);
    // Fields the supplier did not send stay off the screen entirely.
    expect(find.text('Minimum driver age'), findsNothing);
    expect(find.text('Damage excess'), findsNothing);
  });

  testWidgets('Apply reports Coming Soon rather than opening a booking', (
    tester,
  ) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('Apply hands the whole selection to a host screen', (
    tester,
  ) async {
    _sizeForPhone(tester);
    CarRentalSelection? applied;
    await tester.pumpWidget(_app(onApply: (selection) => applied = selection));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(applied?.vehicle, same(_vehicle));
    expect(applied?.criteria.rentalDays, 2);
  });

  testWidgets('renders in Kurdish, in dark mode, right-to-left', (
    tester,
  ) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(
      _app(locale: const Locale('ku'), themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('زانیاری ئۆتۆمبێل'), findsOneWidget);
    expect(find.text('هەڵبژاردنی زیادە'), findsOneWidget);
    expect(find.text('جێبەجێکردن'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('جێبەجێکردن'))),
      TextDirection.rtl,
    );
  });

  testWidgets('renders in Arabic', (tester) async {
    _sizeForPhone(tester);
    await tester.pumpWidget(_app(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل السيارة'), findsOneWidget);
    expect(find.text('خيارات إضافية'), findsOneWidget);
    expect(find.text('ملخص السعر'), findsOneWidget);
  });

  testWidgets('a large text scale does not overflow the facilities row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightForLocale(const Locale('en')),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: CarRentalDetailsScreen(
            selection: CarRentalSelection(
              criteria: _criteria(),
              vehicle: _vehicle,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test('rental days count every started 24-hour period, minimum one', () {
    expect(_criteria().rentalDays, 2);
    expect(
      _criteria(
        pickup: DateTime(2026, 9, 1, 10),
        dropOff: DateTime(2026, 9, 1, 14),
      ).rentalDays,
      1,
    );
    expect(
      _criteria(
        pickup: DateTime(2026, 9, 1, 10),
        dropOff: DateTime(2026, 9, 3, 12),
      ).rentalDays,
      3,
    );
  });

  test('the quote multiplies extras by quantity and by rental days', () {
    final quote = RentalQuote.forSelection(
      vehicle: _vehicle,
      criteria: _criteria(),
      // One baby seat pair at $5/day and GPS at $4/day, over two days.
      extraQuantities: const {
        'preview-extra-baby-seat': 2,
        'preview-extra-gps': 1,
      },
    );

    expect(quote.days, 2);
    expect(quote.baseTotal, 112);
    expect(quote.extrasTotal, 28);
    expect(quote.total, 140);
  });
}
