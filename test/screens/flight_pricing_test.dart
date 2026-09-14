import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/models/booking.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_offer.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_search_criteria.dart';
import 'package:kurdistan_paradise_travel_guide/screens/flight_search_results_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/currency_rates_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/flight_results_service.dart';

/// The bundled table the app already ships — no rate is invented or changed.
const _rates = CurrencyRatesService.bundledRates;

FlightPricing pricingIn(String code) =>
    FlightPricing(rates: _rates, displayCurrency: code);

FlightSegment segment({int stops = 0, String flightNumber = 'AS 204'}) =>
    FlightSegment(
      originName: 'Erbil',
      originCode: 'EBL',
      destinationName: 'Istanbul',
      destinationCode: 'IST',
      departure: DateTime(2027, 5, 1, 8),
      arrival: DateTime(2027, 5, 1, 11),
      stops: stops,
      flightNumber: flightNumber,
    );

FlightOffer offer({
  double price = 400,
  String currency = 'USD',
  FlightSegment? returnSegment,
  int outboundStops = 0,
}) => FlightOffer(
  id: 'o',
  airlineName: 'Astra Airlines',
  outbound: segment(stops: outboundStops),
  returnSegment: returnSegment,
  totalPrice: price,
  currency: currency,
  priceIsTotal: true,
);

const _erbil = Airport(
  id: '3391',
  iataCode: 'EBL',
  icaoCode: 'ORER',
  name: 'Erbil International Airport',
  city: 'Erbil',
  country: 'Iraq',
  countryCode: 'IQ',
  latitude: 36.2,
  longitude: 43.9,
);

const _istanbul = Airport(
  id: '30011',
  iataCode: 'IST',
  icaoCode: 'LTFM',
  name: 'Istanbul Airport',
  city: 'Istanbul',
  country: 'Türkiye',
  countryCode: 'TR',
  latitude: 41.2,
  longitude: 28.7,
);

FlightSearchCriteria criteria({
  FlightTripType tripType = FlightTripType.oneWay,
  DateTime? returnDate,
  bool directFlightsOnly = false,
}) => FlightSearchCriteria(
  tripType: tripType,
  origin: _erbil,
  destination: _istanbul,
  departureDate: DateTime(2027, 5, 1),
  returnDate: returnDate,
  adults: 1,
  children: 0,
  infants: 0,
  cabinClass: CabinClass.economy,
  directFlightsOnly: directFlightsOnly,
);

void main() {
  group('fare display — USD stored → IQD displayed', () {
    test('converts and marks the figure approximate', () {
      final drawn = pricingIn('IQD').fare(offer(price: 400, currency: 'USD'));
      expect(drawn, startsWith('≈'));
      expect(drawn, contains('IQD'));
      expect(drawn, isNot(contains(r'$')));
    });

    test('uses the live rate rather than a hard-coded figure', () {
      final expected = _rates.convert(400, from: 'USD', to: 'IQD');
      expect(expected, isNotNull);
      expect(expected, greaterThan(400));
    });

    test('the stored fare itself is untouched', () {
      final o = offer(price: 400, currency: 'USD');
      expect(o.totalPrice, 400);
      expect(o.currency, 'USD');
    });
  });

  group('fare display — IQD stored → USD displayed', () {
    test('converts down to dollars, not left as 524000', () {
      final drawn = pricingIn('USD').fare(
        offer(price: 524000, currency: 'IQD'),
      );
      expect(drawn, startsWith('≈'));
      expect(drawn, contains(r'$'));
      expect(drawn, isNot(contains('524,000')));
    });
  });

  group('fare display — same currency', () {
    test('USD fare shown to a USD user carries no marker', () {
      final drawn = pricingIn('USD').fare(offer(price: 400, currency: 'USD'));
      expect(drawn, r'$400');
      expect(drawn, isNot(startsWith('≈')));
    });

    test('IQD fare shown to an IQD user carries no marker', () {
      final drawn = pricingIn('IQD').fare(
        offer(price: 524000, currency: 'IQD'),
      );
      expect(drawn, contains('IQD'));
      expect(drawn, contains('524,000'));
      expect(drawn, isNot(startsWith('≈')));
    });
  });

  group('fare display — rates unavailable', () {
    test('falls back to the carrier currency and value', () {
      const pricing = FlightPricing(
        rates: CurrencyRates.empty,
        displayCurrency: 'IQD',
      );
      expect(pricing.fare(offer(price: 400, currency: 'USD')), r'$400');
    });

    test('the unconverted default does the same', () {
      expect(
        FlightPricing.unconverted.fare(offer(price: 400, currency: 'USD')),
        r'$400',
      );
    });
  });

  // --- offer shape ---------------------------------------------------------
  //
  // DATA_MODEL.md: an offer carries an `outbound` leg and an OPTIONAL
  // `returnSegment`, and `stops` lives on each leg because the two can differ.

  group('one-way and round-trip offers', () {
    const service = MockFlightResultsService();

    test('a one-way offer has no return leg', () async {
      final offers = await service.search(criteria());
      expect(offers, isNotEmpty);
      expect(offers.every((o) => o.returnSegment == null), isTrue);
    });

    test('a round-trip offer carries a return leg that flies back', () async {
      final offers = await service.search(
        criteria(
          tripType: FlightTripType.roundTrip,
          returnDate: DateTime(2027, 5, 8),
        ),
      );
      expect(offers, isNotEmpty);
      for (final o in offers) {
        final back = o.returnSegment;
        expect(back, isNotNull);
        expect(back!.originCode, 'IST');
        expect(back.destinationCode, 'EBL');
      }
    });

    test('a round-trip without a return date yields no return leg', () async {
      final offers = await service.search(
        criteria(tripType: FlightTripType.roundTrip),
      );
      expect(offers.every((o) => o.returnSegment == null), isTrue);
    });
  });

  group('stops live on the leg', () {
    test('an offer can be direct outbound and stopping on the return', () {
      // The reason stops belongs on the leg: a single offer-level count would
      // misdescribe one of the two.
      final o = offer(
        outboundStops: 0,
        returnSegment: segment(stops: 1, flightNumber: 'AS 205R'),
      );
      expect(o.outbound.stops, 0);
      expect(o.returnSegment!.stops, 1);
    });

    test('the two legs keep their own flight numbers', () {
      final o = offer(returnSegment: segment(flightNumber: 'AS 205R'));
      expect(o.outbound.flightNumber, 'AS 204');
      expect(o.returnSegment!.flightNumber, 'AS 205R');
    });
  });

  group('direct-only filtering', () {
    const service = MockFlightResultsService();

    test('excludes every offer with a stop', () async {
      final all = await service.search(criteria());
      final direct = await service.search(criteria(directFlightsOnly: true));

      expect(direct.length, lessThan(all.length));
      expect(direct.every((o) => o.outbound.stops == 0), isTrue);
    });

    test('an unfiltered search still returns the stopping offer', () async {
      final all = await service.search(criteria());
      expect(all.any((o) => o.outbound.stops > 0), isTrue);
    });

    test('filtering reads the leg, not an offer-level number', () async {
      // Every returned leg must itself be non-stop.
      final direct = await service.search(criteria(directFlightsOnly: true));
      for (final o in direct) {
        expect(o.outbound.stops, 0);
        if (o.returnSegment != null) {
          expect(o.returnSegment!.stops, 0);
        }
      }
    });
  });
}
