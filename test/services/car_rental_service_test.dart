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

    expect(searched.map((car) => car.id), trending.map((car) => car.id));
    expect(searched, hasLength(3));
  });

  test('location search supports city and airport code', () async {
    final byCity = await service.searchLocations('Erbil');
    final byCode = await service.searchLocations('ISU');

    expect(byCity.single.id, 'preview-erbil-airport');
    expect(byCode.single.id, 'preview-sulaymaniyah-airport');
  });
}
