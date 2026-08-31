import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/car_rental.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/device_location_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/rental_car_parts.dart';

RentalVehicle _vehicle({double price = 56, String currency = 'USD'}) =>
    RentalVehicle(
      id: 'test-car',
      name: const RentalText(en: 'Test Car', ku: 'ئۆتۆمبێل', ar: 'سيارة'),
      modelYear: 2026,
      company: PreviewCarRentalService.vehicles.first.company,
      images: const ['assets/images/journey-car.png'],
      passengers: 4,
      bags: 2,
      powertrain: RentalPowertrain.hybrid,
      transmission: RentalTransmission.automatic,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payAtPickup,
      location: PreviewCarRentalService.wavyAvenue,
      dailyPrice: price,
      currencyCode: currency,
      featured: false,
    );

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('rentalPriceAmount', () {
    test('drops the decimals on a whole amount', () {
      expect(rentalPriceAmount(_vehicle()), r'$56');
    });

    test('keeps two decimals on a fractional amount', () {
      expect(rentalPriceAmount(_vehicle(price: 56.5)), r'$56.50');
    });

    test('spaces a multi-character currency symbol off the number', () {
      final amount = rentalPriceAmount(_vehicle(currency: 'IQD'));
      expect(amount, contains('56'));
      expect(amount.startsWith(r'$'), isFalse);
    });
  });

  group('rentalDistanceText', () {
    test('is null without a device position', () {
      expect(
        rentalDistanceText(PreviewCarRentalService.wavyAvenue, null),
        null,
      );
    });

    test('uses metres under a kilometre', () {
      final branch = PreviewCarRentalService.wavyAvenue;
      final text = rentalDistanceText(
        branch,
        DeviceLocation(branch.latitude, branch.longitude),
      );
      expect(text, '0 m');
    });

    test('uses one decimal of kilometres further out', () {
      final text = rentalDistanceText(
        PreviewCarRentalService.erbilAirport,
        const DeviceLocation(36.2088, 43.9891),
      );
      expect(text, endsWith(' km'));
    });
  });

  testWidgets('the price badge splits the amount from the period unit', (
    tester,
  ) async {
    await tester.pumpWidget(_host(RentalPriceBadge(vehicle: _vehicle())));
    await tester.pumpAndSettle();

    expect(find.text(r'$56/day', findRichText: true), findsOneWidget);
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(RentalPriceBadge),
        matching: find.byType(RichText),
      ),
    );
    final sizes = <String, double?>{};
    richText.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) {
        sizes[span.text!] = span.style?.fontSize;
      }
      return true;
    });
    // The amount is emphasised; the period unit is deliberately smaller.
    expect(sizes[r'$56'], 22);
    expect(sizes['/day'], 13);
  });

  testWidgets('the price badge localizes the period unit', (tester) async {
    await tester.pumpWidget(
      _host(RentalPriceBadge(vehicle: _vehicle()), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$56/يوم', findRichText: true), findsOneWidget);
  });

  testWidgets('the company badge falls back to the car glyph', (tester) async {
    await tester.pumpWidget(
      _host(
        RentalCompanyBadge(
          company: PreviewCarRentalService.vehicles.first.company,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC Cars'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car), findsOneWidget);
  });

  testWidgets('a broken image path shows the fallback glyph', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 100,
          height: 120,
          child: RentalVehicleImage(asset: 'assets/images/missing.webp'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
  });
}
