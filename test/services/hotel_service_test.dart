import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';

void main() {
  const service = PreviewHotelService();

  test(
    'preview destination search is localized and case insensitive',
    () async {
      expect(await service.searchDestinations('ERB'), hasLength(1));
      expect((await service.searchDestinations('هەولێر')).single.id, 'erbil');
    },
  );

  test(
    'preview hotel search applies destination and amenity filters',
    () async {
      final checkIn = DateTime(2026, 9, 10);
      final results = await service.searchHotels(
        HotelSearchCriteria(
          destination: PreviewHotelService.destinations.first,
          checkIn: checkIn,
          checkOut: checkIn.add(const Duration(days: 2)),
          amenities: const {HotelAmenity.pool, HotelAmenity.gym},
        ),
      );

      expect(results.map((hotel) => hotel.id), ['preview-divan-erbil']);
    },
  );
}
