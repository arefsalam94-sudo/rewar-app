import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_booking_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';

void main() {
  final hotel = PreviewHotelService.hotels.first;
  final criteria = HotelSearchCriteria(
    checkIn: DateTime(2026, 9, 1),
    checkOut: DateTime(2026, 9, 4),
    adults: 2,
  );
  const service = PreviewHotelBookingService(delay: Duration.zero);

  test(
    'returns Garden View and King mock rooms with stay-specific totals',
    () async {
      final result = await service.fetchAvailability(hotel, criteria);

      expect(result.availableRooms.map((room) => room.id), [
        'garden-view',
        'king-room',
      ]);
      final offer = result.offersByRoom['garden-view']!.first;
      expect(offer.availableQuantity, 5);
      expect(
        offer.totalPrice,
        offer.nightlyPrice * 3 + offer.taxes + offer.fees,
      );
      expect(offer.providerId, 'preview-only');
    },
  );

  test('does not pretend to support a multiple-room request', () async {
    final result = await service.fetchAvailability(
      hotel,
      criteria.copyWith(rooms: 2),
    );

    expect(result.availableRooms, isEmpty);
  });
}
