import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/car_rental.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';

void main() {
  const service = PreviewCarRentalService();

  test('preview cars are shared by trending and search results', () async {
    final trending = await service.trendingCars();
    final pickup = DateTime(2027, 8, 22, 10);
    final criteria = CarRentalSearchCriteria(
      pickupLocation: PreviewCarRentalService.erbilAirport,
      dropOffLocation: PreviewCarRentalService.erbilAirport,
      sameLocation: true,
      pickupDateTime: pickup,
      dropOffDateTime: pickup.add(const Duration(days: 2)),
    );

    final searched = await service.searchCars(criteria);

    // The point of this test: both entry points serve the same fixtures, so a
    // car opened from Trending and the same car opened from Results cannot
    // disagree.
    expect(searched.map((car) => car.id), trending.map((car) => car.id));

    // Tied to the fixture list rather than a hard-coded count. The catalogue
    // grew from three vehicles to five and silently broke this test; anchoring
    // it to the source list means growing it again cannot.
    expect(searched, hasLength(PreviewCarRentalService.vehicles.length));
    expect(searched, isNotEmpty);
  });

  test('location search matches city names', () async {
    final byCity = await service.searchLocations('Erbil');

    // Erbil has four branches — the airport plus three city pickup points — so
    // this asserts the whole matched set, not a single hit.
    expect(byCity, hasLength(greaterThan(1)));
    expect(byCity.map((location) => location.id), contains('preview-erbil-airport'));
    expect(
      byCity.every((location) => location.city.en == 'Erbil'),
      isTrue,
      reason: 'a city search must not return branches in another city',
    );
  });

  test('location search matches a unique airport code', () async {
    final byCode = await service.searchLocations('ISU');

    // An IATA code belongs to exactly one branch, so `single` is the right
    // assertion here even though it is wrong for a city name.
    expect(byCode.single.id, 'preview-sulaymaniyah-airport');
    expect(byCode.single.airportCode, 'ISU');
  });

  test('a query shorter than two characters returns nothing', () async {
    expect(await service.searchLocations('E'), isEmpty);
    expect(await service.searchLocations(' '), isEmpty);
  });
}
