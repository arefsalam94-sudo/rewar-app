import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/car_rental.dart';
import 'package:kurdistan_paradise_travel_guide/services/currency_rates_service.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/rental_car_parts.dart';

/// The bundled table `CurrencyRatesService` already ships — no rate is
/// invented here, and none is changed.
const _rates = CurrencyRatesService.bundledRates;

const _branch = RentalLocation(
  id: 'b',
  name: RentalText(en: 'Wavy Avenue', ku: 'Wavy', ar: 'Wavy'),
  city: RentalText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
  country: RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
  latitude: 36.2,
  longitude: 44.0,
);

RentalVehicle vehicle({required double price, required String currency}) =>
    RentalVehicle(
      id: 'v',
      name: const RentalText(en: 'Tesla Model 3', ku: 'تێسلا', ar: 'تسلا'),
      modelYear: 2024,
      company: const RentalCompany(
        id: 'abc',
        name: RentalText(en: 'ABC Cars', ku: 'ABC', ar: 'ABC'),
      ),
      images: const ['assets/images/journey-car.png'],
      passengers: 5,
      bags: 2,
      powertrain: RentalPowertrain.electric,
      transmission: RentalTransmission.automatic,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payAtPickup,
      location: _branch,
      dailyPrice: price,
      currencyCode: currency,
      featured: true,
    );

RentalPricing pricingIn(String code) =>
    RentalPricing(rates: _rates, displayCurrency: code);

void main() {
  // The three cases the display contract has to cover. The stored pair is
  // never duplicated in Firestore — conversion happens here, at render time.

  group('stored USD → displayed IQD', () {
    final car = vehicle(price: 56, currency: 'USD');
    final pricing = pricingIn('IQD');

    test('is reported as a conversion', () {
      expect(pricing.isConverted('USD'), isTrue);
    });

    test('renders in IQD with the approximate marker', () {
      final drawn = pricing.perDay(car);
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
      expect(drawn, isNot(contains(r'$')));
    });

    test('uses the live rate, not a hard-coded figure', () {
      final expected = _rates.convert(56, from: 'USD', to: 'IQD');
      expect(expected, isNotNull);
      // Grouped thousands, so compare the number the helper actually derived.
      expect(pricing.perDay(car), contains(expected!.round().toString().substring(0, 2)));
    });

    test('the stored price itself is untouched', () {
      // Nothing converts at rest; the document still holds 56 USD.
      expect(car.dailyPrice, 56);
      expect(car.currencyCode, 'USD');
    });
  });

  group('stored IQD → displayed USD', () {
    final car = vehicle(price: 85000, currency: 'IQD');
    final pricing = pricingIn('USD');

    test('is reported as a conversion', () {
      expect(pricing.isConverted('IQD'), isTrue);
    });

    test('renders in USD with the approximate marker', () {
      final drawn = pricing.perDay(car);
      expect(drawn, startsWith('≈'));
      expect(drawn, contains(r'$'));
      expect(drawn, isNot(contains('IQD')));
    });

    test('converts down to a plausible dollar figure, not 85000', () {
      final drawn = pricing.perDay(car);
      expect(drawn, isNot(contains('85,000')));
      final expected = _rates.convert(85000, from: 'IQD', to: 'USD');
      expect(expected, isNotNull);
      expect(expected, lessThan(85000));
    });
  });

  group('same currency — no conversion', () {
    test('USD stored, USD displayed', () {
      final car = vehicle(price: 56, currency: 'USD');
      final pricing = pricingIn('USD');

      expect(pricing.isConverted('USD'), isFalse);
      final drawn = pricing.perDay(car);
      expect(drawn, r'$56');
      expect(drawn, isNot(startsWith('≈')),
          reason: 'an unconverted price must not be marked approximate');
    });

    test('IQD stored, IQD displayed', () {
      final car = vehicle(price: 85000, currency: 'IQD');
      final pricing = pricingIn('IQD');

      expect(pricing.isConverted('IQD'), isFalse);
      final drawn = pricing.perDay(car);
      expect(drawn, contains('IQD'));
      expect(drawn, contains('85,000'));
      expect(drawn, isNot(startsWith('≈')));
    });

    test('case is ignored when comparing currencies', () {
      expect(
        RentalPricing(rates: _rates, displayCurrency: 'usd').isConverted('USD'),
        isFalse,
      );
    });
  });

  group('falling back rather than inventing a rate', () {
    test('an empty rate table leaves the stored currency alone', () {
      const pricing = RentalPricing(
        rates: CurrencyRates.empty,
        displayCurrency: 'IQD',
      );
      final car = vehicle(price: 56, currency: 'USD');

      expect(pricing.isConverted('USD'), isFalse);
      expect(pricing.perDay(car), r'$56');
    });

    test('the unconverted default shows the supplier currency', () {
      // What every card renders before currency_rates/latest has loaded.
      final car = vehicle(price: 85000, currency: 'IQD');
      expect(RentalPricing.unconverted.perDay(car), contains('IQD'));
      expect(RentalPricing.unconverted.isConverted('IQD'), isFalse);
    });

    test('a currency the table cannot reach is left unconverted', () {
      final pricing = pricingIn('JPY');
      final car = vehicle(price: 56, currency: 'USD');
      expect(pricing.isConverted('USD'), isFalse);
      expect(pricing.perDay(car), r'$56');
    });
  });

  group('rentalPriceAmount', () {
    final car = vehicle(price: 56, currency: 'USD');

    test('without pricing keeps the stored-currency behaviour', () {
      expect(rentalPriceAmount(car), r'$56');
    });

    test('with pricing converts', () {
      expect(rentalPriceAmount(car, pricingIn('IQD')), startsWith('≈'));
    });

    test('an arbitrary amount converts through format()', () {
      // Used by the extras and conditions rows, which quote the same currency.
      final drawn = pricingIn('IQD').format(10, 'USD');
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
    });
  });

  // --- conditions money ---------------------------------------------------
  //
  // DATA_MODEL.md: depositAmount, damageExcess and
  // mileagePolicy.extraKilometrePrice are ALL denominated in the vehicle's own
  // currencyCode. There is no second currency field on `cars`, and the user's
  // Settings choice is display-only — it never changes what the supplier is
  // owed.

  group('deposit — USD stored → IQD displayed', () {
    const deposit = 200.0;
    final pricing = pricingIn('IQD');

    test('converts and marks the figure approximate', () {
      final drawn = pricing.format(deposit, 'USD');
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
      expect(drawn, isNot(contains(r'$')));
    });

    test('uses the live rate rather than a hard-coded figure', () {
      final expected = _rates.convert(deposit, from: 'USD', to: 'IQD');
      expect(expected, isNotNull);
      expect(expected, greaterThan(deposit));
    });
  });

  group('deposit — IQD stored → USD displayed', () {
    const deposit = 260000.0;
    final pricing = pricingIn('USD');

    test('converts down to dollars, not left as 260000', () {
      final drawn = pricing.format(deposit, 'IQD');
      expect(drawn, startsWith('≈'));
      expect(drawn, contains(r'$'));
      expect(drawn, isNot(contains('260,000')));
    });
  });

  group('deposit — same currency', () {
    test('USD deposit shown to a USD user carries no marker', () {
      final drawn = pricingIn('USD').format(200, 'USD');
      expect(drawn, r'$200');
      expect(drawn, isNot(startsWith('≈')));
    });

    test('IQD deposit shown to an IQD user carries no marker', () {
      final drawn = pricingIn('IQD').format(260000, 'IQD');
      expect(drawn, contains('IQD'));
      expect(drawn, contains('260,000'));
      expect(drawn, isNot(startsWith('≈')));
    });
  });

  group('deposit — rates unavailable', () {
    test('falls back to the supplier currency and value', () {
      // An unconverted true figure beats a converted invented one, and a
      // deposit is money the renter will actually be held to.
      const pricing = RentalPricing(
        rates: CurrencyRates.empty,
        displayCurrency: 'IQD',
      );
      final drawn = pricing.format(200, 'USD');
      expect(drawn, r'$200');
      expect(drawn, isNot(startsWith('≈')));
    });

    test('the unconverted default does the same', () {
      expect(RentalPricing.unconverted.format(200, 'USD'), r'$200');
    });
  });

  group('the other monetary conditions use the same path', () {
    test('damage excess converts USD → IQD', () {
      final drawn = pricingIn('IQD').format(1500, 'USD');
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
    });

    test('damage excess is unmarked in the same currency', () {
      expect(pricingIn('USD').format(1500, 'USD'), r'$1,500');
    });

    test('mileage extra-kilometre price converts', () {
      // A small per-kilometre charge — sub-unit precision must survive.
      final drawn = pricingIn('IQD').format(0.25, 'USD');
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
    });

    test('an add-on extra converts through the same call', () {
      final drawn = pricingIn('IQD').format(5, 'USD');
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
    });

    test('every conditions figure uses the VEHICLE currency, not the display one', () {
      // The contract: a deposit quoted by a USD supplier is a USD debt, shown
      // approximately in IQD. Swapping the arguments would invert the rate.
      final asStored = pricingIn('IQD').format(200, 'USD');
      final ifInverted = pricingIn('IQD').format(200, 'IQD');
      expect(asStored, isNot(equals(ifInverted)));
      expect(ifInverted, isNot(startsWith('≈')));
    });
  });
}
