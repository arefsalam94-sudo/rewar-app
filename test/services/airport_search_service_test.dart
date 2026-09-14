import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/services/airport_search_service.dart';

void main() {
  const service = PreviewAirportSearchService();

  test('a query shorter than two characters returns nothing', () async {
    // Guards the callable's cost surface as much as the UI: one keystroke
    // should not fan out to every airport in the catalogue.
    expect(await service.search(''), isEmpty);
    expect(await service.search('E'), isEmpty);
    expect(await service.search(' '), isEmpty);
  });

  test('matches an IATA code case-insensitively', () async {
    final lower = await service.search('ebl');
    final upper = await service.search('EBL');

    expect(lower.single.iataCode, 'EBL');
    expect(upper.single.iataCode, 'EBL');
  });

  test('matches an ICAO code', () async {
    final results = await service.search('ORER');

    expect(results.single.iataCode, 'EBL');
  });

  test('matches a city name', () async {
    final results = await service.search('Istanbul');

    expect(results, isNotEmpty);
    expect(results.map((a) => a.iataCode), contains('IST'));
  });

  test('matches a country name', () async {
    final results = await service.search('Iraq');

    expect(results, isNotEmpty);
    expect(
      results.every((airport) => airport.country == 'Iraq'),
      isTrue,
      reason: 'a country search must not return airports elsewhere',
    );
  });

  test('surrounding whitespace is ignored', () async {
    final padded = await service.search('  EBL  ');

    expect(padded.single.iataCode, 'EBL');
  });

  test('an unknown query returns an empty list rather than throwing', () async {
    expect(await service.search('zzzzzz'), isEmpty);
  });

  test('every bundled airport carries the fields the picker draws', () async {
    for (final airport in PreviewAirportSearchService.airports) {
      expect(airport.id, isNotEmpty, reason: 'id missing');
      expect(airport.iataCode, hasLength(3), reason: '${airport.name} IATA');
      expect(airport.name, isNotEmpty, reason: 'name missing');
      expect(airport.displayName, isNotEmpty, reason: 'nothing to draw');
      expect(airport.latitude, inInclusiveRange(-90, 90));
      expect(airport.longitude, inInclusiveRange(-180, 180));
    }
  });
}
