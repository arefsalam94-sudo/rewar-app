import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/models/booking.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_search_criteria.dart';

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
  DateTime? departureDate,
  DateTime? returnDate,
  int adults = 1,
  int children = 0,
  int infants = 0,
}) => FlightSearchCriteria(
  tripType: tripType,
  origin: _erbil,
  destination: _istanbul,
  departureDate: departureDate ?? DateTime(2027, 5, 1),
  returnDate: returnDate,
  adults: adults,
  children: children,
  infants: infants,
  cabinClass: CabinClass.economy,
  directFlightsOnly: false,
);

void main() {
  group('passengerCount', () {
    test('sums all three passenger types', () {
      expect(_criteria(adults: 2, children: 3, infants: 1).passengerCount, 6);
    });

    test('is the adult count when nobody else is travelling', () {
      expect(_criteria(adults: 1).passengerCount, 1);
    });

    test('counts infants, who occupy no seat but are still travellers', () {
      // Worth pinning: an infant is easy to leave out of a headcount, and the
      // Traveler Info screen collects details for every person counted here.
      expect(_criteria(adults: 1, infants: 1).passengerCount, 2);
    });
  });

  group('copyWith', () {
    test('replaces the departure date and leaves everything else alone', () {
      final original = _criteria(adults: 2, children: 1);
      final moved = original.copyWith(departureDate: DateTime(2027, 6, 9));

      expect(moved.departureDate, DateTime(2027, 6, 9));
      expect(moved.origin.iataCode, 'EBL');
      expect(moved.destination.iataCode, 'IST');
      expect(moved.adults, 2);
      expect(moved.children, 1);
      expect(moved.cabinClass, CabinClass.economy);
      expect(moved.directFlightsOnly, isFalse);
      expect(moved.tripType, FlightTripType.oneWay);
    });

    test('replaces the return date', () {
      final original = _criteria(
        tripType: FlightTripType.roundTrip,
        returnDate: DateTime(2027, 5, 8),
      );
      final moved = original.copyWith(returnDate: DateTime(2027, 5, 12));

      expect(moved.returnDate, DateTime(2027, 5, 12));
      expect(moved.departureDate, DateTime(2027, 5, 1));
    });

    test('omitted arguments keep the existing values', () {
      final original = _criteria(
        tripType: FlightTripType.roundTrip,
        returnDate: DateTime(2027, 5, 8),
      );
      final same = original.copyWith();

      expect(same.departureDate, original.departureDate);
      expect(same.returnDate, original.returnDate);
    });

    test(
      'a null returnDate cannot be cleared through copyWith — known limitation',
      () {
        // `returnDate ?? this.returnDate` means passing null keeps the old
        // value rather than clearing it. Switching a round trip back to one-way
        // therefore has to build a new criteria object, not copyWith. Pinned so
        // the behaviour is a documented choice rather than a surprise.
        final round = _criteria(
          tripType: FlightTripType.roundTrip,
          returnDate: DateTime(2027, 5, 8),
        );

        expect(round.copyWith(returnDate: null).returnDate, DateTime(2027, 5, 8));
      },
    );
  });
}
