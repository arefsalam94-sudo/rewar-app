import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';

void main() {
  test('hotel search criteria keeps all search state in one value', () {
    final checkIn = DateTime(2026, 9, 10);
    final criteria = HotelSearchCriteria(
      checkIn: checkIn,
      checkOut: checkIn.add(const Duration(days: 2)),
    );

    final changed = criteria.copyWith(
      adults: 3,
      children: 1,
      rooms: 2,
      beds: 2,
      amenities: {HotelAmenity.pool, HotelAmenity.wifi},
    );

    expect(changed.adults, 3);
    expect(changed.children, 1);
    expect(changed.rooms, 2);
    expect(changed.beds, 2);
    expect(changed.amenities, {HotelAmenity.pool, HotelAmenity.wifi});
    expect(criteria.adults, 2);
  });
}
