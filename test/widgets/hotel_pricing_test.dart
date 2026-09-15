import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel_detail.dart';
import 'package:kurdistan_paradise_travel_guide/services/currency_rates_service.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/hotel_parts.dart';

/// The bundled table `CurrencyRatesService` already ships — no rate is
/// invented here, and none is changed.
const _rates = CurrencyRatesService.bundledRates;

Hotel hotel({required double price, required String currency}) => Hotel(
  id: 'h',
  name: const HotelText(en: 'Divan Erbil', ku: 'دیڤان', ar: 'ديفان'),
  city: const HotelText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
  imageAsset: 'assets/images/journey-stay.png',
  starRating: 5,
  reviewScore: 0,
  pricePerNight: price,
  currencyCode: currency,
  amenities: const {HotelAmenity.wifi},
);

HotelRoomOffer offer({required double total, required String currency}) =>
    HotelRoomOffer(
      id: 'o',
      roomTypeId: 'deluxe-king',
      currencyCode: currency,
      nightlyPrice: total / 2,
      totalPrice: total,
    );

HotelPricing pricingIn(String code) =>
    HotelPricing(rates: _rates, displayCurrency: code);

void main() {
  // The display contract, mirroring `rental_pricing_test.dart` case for case.
  // A hotel stores ONE authoritative price in the property's own currency and
  // an offer stores ONE in its own; neither is duplicated as a USD/IQD pair in
  // Firestore, so every one of these conversions happens at render time.

  group('hotel stored USD → user prefers IQD', () {
    final stay = hotel(price: 120, currency: 'USD');
    final pricing = pricingIn('IQD');

    test('is reported as a conversion', () {
      expect(pricing.isConverted('USD'), isTrue);
    });

    test('renders in IQD with the approximate marker', () {
      final drawn = pricing.perNight(stay);
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
      expect(drawn, isNot(contains(r'$')));
    });

    test('uses the live rate, not a hard-coded figure', () {
      final expected = _rates.convert(120, from: 'USD', to: 'IQD');
      expect(expected, isNotNull);
      expect(expected, greaterThan(120));
      // Grouped thousands, so compare on the leading digits the helper derived.
      expect(
        pricing.perNight(stay),
        contains(expected!.round().toString().substring(0, 3)),
      );
    });

    test('the stored price itself is untouched', () {
      // Nothing converts at rest; the document still holds 120 USD.
      expect(stay.pricePerNight, 120);
      expect(stay.currencyCode, 'USD');
    });
  });

  group('hotel stored IQD → user prefers USD', () {
    final stay = hotel(price: 157200, currency: 'IQD');
    final pricing = pricingIn('USD');

    test('is reported as a conversion', () {
      expect(pricing.isConverted('IQD'), isTrue);
    });

    test('renders in USD with the approximate marker', () {
      final drawn = pricing.perNight(stay);
      expect(drawn, startsWith('≈'));
      expect(drawn, contains(r'$'));
      expect(drawn, isNot(contains('IQD')));
    });

    test('converts down to a plausible dollar figure, not 157200', () {
      final drawn = pricing.perNight(stay);
      expect(drawn, isNot(contains('157,200')));
      final expected = _rates.convert(157200, from: 'IQD', to: 'USD');
      expect(expected, isNotNull);
      expect(expected, lessThan(157200));
      expect(expected, closeTo(120, 0.01));
    });
  });

  group('same currency — no conversion, no marker', () {
    test('USD stored, USD preferred', () {
      final pricing = pricingIn('USD');
      expect(pricing.isConverted('USD'), isFalse);

      final drawn = pricing.perNight(hotel(price: 120, currency: 'USD'));
      expect(drawn, r'$120');
      expect(
        drawn,
        isNot(startsWith('≈')),
        reason: 'an unconverted price must not be marked approximate',
      );
    });

    test('IQD stored, IQD preferred', () {
      final pricing = pricingIn('IQD');
      expect(pricing.isConverted('IQD'), isFalse);

      final drawn = pricing.perNight(hotel(price: 157200, currency: 'IQD'));
      expect(drawn, contains('IQD'));
      expect(drawn, contains('157,200'));
      expect(drawn, isNot(startsWith('≈')));
    });

    test('case is ignored when comparing currencies', () {
      expect(
        HotelPricing(rates: _rates, displayCurrency: 'usd').isConverted('USD'),
        isFalse,
      );
    });
  });

  group('missing rates fall back to the authoritative currency', () {
    test('an empty rate table leaves a USD hotel in USD', () {
      const pricing = HotelPricing(
        rates: CurrencyRates.empty,
        displayCurrency: 'IQD',
      );
      expect(pricing.isConverted('USD'), isFalse);
      expect(pricing.perNight(hotel(price: 120, currency: 'USD')), r'$120');
    });

    test('an empty rate table leaves an IQD hotel in IQD', () {
      // The direction that matters: falling back must never mean "assume USD".
      const pricing = HotelPricing(
        rates: CurrencyRates.empty,
        displayCurrency: 'USD',
      );
      final drawn = pricing.perNight(hotel(price: 157200, currency: 'IQD'));
      expect(drawn, contains('IQD'));
      expect(drawn, isNot(contains(r'$')));
    });

    test('the unconverted default shows the property currency', () {
      // What every card renders before currency_rates/latest has loaded.
      final stay = hotel(price: 157200, currency: 'IQD');
      expect(HotelPricing.unconverted.perNight(stay), contains('IQD'));
      expect(HotelPricing.unconverted.isConverted('IQD'), isFalse);
    });

    test('a display currency the table cannot reach is left unconverted', () {
      final pricing = pricingIn('JPY');
      expect(pricing.isConverted('USD'), isFalse);
      expect(pricing.perNight(hotel(price: 120, currency: 'USD')), r'$120');
    });

    test('an offer falls back to its own currency too', () {
      const pricing = HotelPricing(
        rates: CurrencyRates.empty,
        displayCurrency: 'USD',
      );
      final rate = offer(total: 314400, currency: 'IQD');
      final drawn = pricing.format(rate.totalPrice, rate.currencyCode);
      expect(drawn, contains('IQD'));
      expect(drawn, isNot(startsWith('≈')));
    });
  });

  group('offer totals — the figure the rate list draws', () {
    test('a USD offer shown to an IQD user converts and is marked', () {
      final rate = offer(total: 240, currency: 'USD');
      final drawn = pricingIn('IQD').format(rate.totalPrice, rate.currencyCode);
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
    });

    test('an IQD offer shown to a USD user converts and is marked', () {
      final rate = offer(total: 314400, currency: 'IQD');
      final drawn = pricingIn('USD').format(rate.totalPrice, rate.currencyCode);
      expect(drawn, startsWith('≈'));
      expect(drawn, contains(r'$'));
    });

    test('an offer in the preferred currency is drawn exactly', () {
      final rate = offer(total: 240, currency: 'USD');
      expect(pricingIn('USD').format(rate.totalPrice, rate.currencyCode), r'$240');
    });

    test('the offer keeps its own stored currency regardless of display', () {
      // Display never rewrites the rate the hold and the booking are made in.
      final rate = offer(total: 240, currency: 'USD');
      pricingIn('IQD').format(rate.totalPrice, rate.currencyCode);
      expect(rate.currencyCode, 'USD');
      expect(rate.totalPrice, 240);
    });
  });

  group('formatHotelPrice', () {
    test('without pricing keeps the stored-currency behaviour', () {
      expect(formatHotelPrice(hotel(price: 120, currency: 'USD')), r'$120');
    });

    test('without pricing an IQD hotel is NOT drawn as dollars', () {
      // The old helper had no USD default either, but the service above it
      // did — this pins the card end of the same contract.
      final drawn = formatHotelPrice(hotel(price: 157200, currency: 'IQD'));
      expect(drawn, contains('IQD'));
      expect(drawn, isNot(contains(r'$')));
    });

    test('with pricing it converts', () {
      final drawn = formatHotelPrice(
        hotel(price: 120, currency: 'USD'),
        pricingIn('IQD'),
      );
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
    });
  });
}
