import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';

void main() {
  group('Airport.fromMap', () {
    test('reads a complete payload', () {
      final airport = Airport.fromMap(const {
        'id': '3391',
        'iataCode': 'EBL',
        'icaoCode': 'ORER',
        'name': 'Erbil International Airport',
        'city': 'Erbil',
        'country': 'Iraq',
        'countryCode': 'IQ',
        'latitude': 36.2376,
        'longitude': 43.9632,
      });

      expect(airport.id, '3391');
      expect(airport.iataCode, 'EBL');
      expect(airport.icaoCode, 'ORER');
      expect(airport.name, 'Erbil International Airport');
      expect(airport.city, 'Erbil');
      expect(airport.country, 'Iraq');
      expect(airport.countryCode, 'IQ');
      expect(airport.latitude, closeTo(36.2376, 1e-9));
      expect(airport.longitude, closeTo(43.9632, 1e-9));
    });

    test('missing fields become empty strings and zero coordinates', () {
      // The payload crosses a Cloud Function boundary, so a field can be
      // absent. Defaulting rather than throwing keeps one bad row from
      // emptying the whole airport picker.
      final airport = Airport.fromMap(const <Object?, Object?>{});

      expect(airport.id, isEmpty);
      expect(airport.iataCode, isEmpty);
      expect(airport.latitude, 0);
      expect(airport.longitude, 0);
    });

    test('coordinates sent as int are widened to double', () {
      // JSON over the callable boundary drops a trailing .0, so a whole-number
      // latitude arrives as an int and a plain cast would throw.
      final airport = Airport.fromMap(const {'latitude': 36, 'longitude': -44});

      expect(airport.latitude, 36.0);
      expect(airport.longitude, -44.0);
    });

    test('non-string scalars are stringified rather than rejected', () {
      final airport = Airport.fromMap(const {'id': 3391, 'iataCode': 'EBL'});

      expect(airport.id, '3391');
    });
  });

  group('displayName', () {
    test('prefers the city', () {
      const airport = Airport(
        id: '1',
        iataCode: 'EBL',
        icaoCode: 'ORER',
        name: 'Erbil International Airport',
        city: 'Erbil',
        country: 'Iraq',
        countryCode: 'IQ',
        latitude: 0,
        longitude: 0,
      );

      expect(airport.displayName, 'Erbil');
    });

    test('falls back to the airport name when the city is empty', () {
      const airport = Airport(
        id: '1',
        iataCode: 'EBL',
        icaoCode: 'ORER',
        name: 'Erbil International Airport',
        city: '',
        country: 'Iraq',
        countryCode: 'IQ',
        latitude: 0,
        longitude: 0,
      );

      expect(airport.displayName, 'Erbil International Airport');
    });
  });
}
