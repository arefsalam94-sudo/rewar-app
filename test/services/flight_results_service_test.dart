import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/models/booking.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_search_criteria.dart';
import 'package:kurdistan_paradise_travel_guide/services/flight_results_service.dart';

const _erbil = Airport(
  id: '3391',
  iataCode: 'EBL',
  icaoCode: 'ORER',
  name: 'Erbil International Airport',
  city: 'Erbil',
  country: 'Iraq',
  countryCode: 'IQ',
  latitude: 36.2376,
  longitude: 43.9632,
);

const _istanbul = Airport(
  id: '30011',
  iataCode: 'IST',
  icaoCode: 'LTFM',
  name: 'Istanbul Airport',
  city: 'Istanbul',
  country: 'Türkiye',
  countryCode: 'TR',
  latitude: 41.2753,
  longitude: 28.7519,
);

FlightSearchCriteria _criteria({
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
  const service = MockFlightResultsService();

  test('a one-way search returns offers with no return segment', () async {
    final offers = await service.search(_criteria());

    expect(offers, isNotEmpty);
    expect(offers.every((offer) => offer.returnSegment == null), isTrue);
  });

  test('offers carry the searched airport codes', () async {
    final offers = await service.search(_criteria());

    for (final offer in offers) {
      expect(offer.outbound.originCode, 'EBL');
      expect(offer.outbound.destinationCode, 'IST');
    }
  });

  test('every offer id is unique', () async {
    final offers = await service.search(_criteria());
    final ids = offers.map((offer) => offer.id).toSet();

    expect(ids, hasLength(offers.length));
  });

  test('directFlightsOnly filters out every offer with a stop', () async {
    final all = await service.search(_criteria());
    final direct = await service.search(_criteria(directFlightsOnly: true));

    expect(direct.length, lessThan(all.length));
    expect(direct.every((offer) => offer.outbound.stops == 0), isTrue);
  });

  test('a round trip adds a return segment that flies back', () async {
    final offers = await service.search(
      _criteria(
        tripType: FlightTripType.roundTrip,
        returnDate: DateTime(2027, 5, 8),
      ),
    );

    expect(offers, isNotEmpty);
    for (final offer in offers) {
      final back = offer.returnSegment;
      expect(back, isNotNull);
      // The return leg must mirror the outbound, not repeat it.
      expect(back!.originCode, 'IST');
      expect(back.destinationCode, 'EBL');
      expect(back.departure.day, 8);
    }
  });

  test('a round trip costs more than the same one-way', () async {
    final oneWay = await service.search(_criteria());
    final round = await service.search(
      _criteria(
        tripType: FlightTripType.roundTrip,
        returnDate: DateTime(2027, 5, 8),
      ),
    );

    expect(round.first.totalPrice, greaterThan(oneWay.first.totalPrice));
  });

  test('a round trip without a return date yields no return segment', () async {
    // The screen should not be able to produce this, but the service must not
    // fabricate a return leg out of a missing date.
    final offers = await service.search(
      _criteria(tripType: FlightTripType.roundTrip),
    );

    expect(offers.every((offer) => offer.returnSegment == null), isTrue);
  });

  test('arrival is always after departure', () async {
    final offers = await service.search(_criteria());

    for (final offer in offers) {
      expect(offer.outbound.arrival.isAfter(offer.outbound.departure), isTrue);
    }
  });

  test('offers depart on the requested date', () async {
    final offers = await service.search(_criteria());

    for (final offer in offers) {
      expect(offer.outbound.departure.year, 2027);
      expect(offer.outbound.departure.month, 5);
      expect(offer.outbound.departure.day, 1);
    }
  });

  test('prices are quoted as a total in USD', () async {
    final offers = await service.search(_criteria());

    for (final offer in offers) {
      expect(offer.currency, 'USD');
      expect(offer.priceIsTotal, isTrue);
      expect(offer.totalPrice, greaterThan(0));
    }
  });
}
