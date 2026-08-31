import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel_detail.dart';

const _name = HotelText(en: 'Name', ku: 'ناو', ar: 'اسم');

HotelFacility _facility(String id, HotelFacilityCategory category) =>
    HotelFacility(id: id, name: _name, category: category, iconKey: id);

HotelRoomOffer _offer(String id, double nightly) => HotelRoomOffer(
  id: id,
  roomTypeId: 'room',
  currencyCode: 'USD',
  nightlyPrice: nightly,
  totalPrice: nightly * 2,
);

const _hotel = Hotel(
  id: 'h1',
  name: _name,
  city: _name,
  imageAsset: 'assets/images/hotel background.webp',
  starRating: 4,
  reviewScore: 8.5,
  distanceFromCenterKm: 1,
  pricePerNight: 100,
  currencyCode: 'USD',
  amenities: <HotelAmenity>{},
);

void main() {
  test('facilities group by category, in the declared order', () {
    final detail = HotelDetail(
      hotel: _hotel,
      facilities: <HotelFacility>[
        _facility('safety', HotelFacilityCategory.safety),
        _facility('wifi', HotelFacilityCategory.internet),
        _facility('lobby', HotelFacilityCategory.general),
        _facility('router', HotelFacilityCategory.internet),
      ],
    );

    final grouped = detail.facilitiesByCategory;
    expect(grouped.keys.toList(), <HotelFacilityCategory>[
      HotelFacilityCategory.general,
      HotelFacilityCategory.internet,
      HotelFacilityCategory.safety,
    ]);
    expect(grouped[HotelFacilityCategory.internet]!.length, 2);
    // A category nobody offers is absent, not an empty group.
    expect(grouped.containsKey(HotelFacilityCategory.pool), isFalse);
  });

  test('the lead offer is the cheapest per night', () {
    final detail = HotelDetail(
      hotel: _hotel,
      roomOffers: <HotelRoomOffer>[
        _offer('flex', 200),
        _offer('saver', 140),
        _offer('mid', 175),
      ],
    );
    expect(detail.leadOffer?.id, 'saver');
    expect(const HotelDetail(hotel: _hotel).leadOffer, isNull);
  });

  test('an offer with no inventory is not available', () {
    expect(_offer('a', 100).isAvailable, isFalse);
    expect(
      HotelRoomOffer(
        id: 'a',
        roomTypeId: 'room',
        currencyCode: 'USD',
        nightlyPrice: 100,
        totalPrice: 200,
        availableQuantity: 2,
      ).isAvailable,
      isTrue,
    );
  });

  test('policies with nothing published report themselves empty', () {
    expect(const HotelPolicies().isEmpty, isTrue);
    expect(const HotelPolicies(checkInFrom: '14:00').isEmpty, isFalse);
    expect(
      const HotelPolicies(acceptedPaymentMethods: <String>['Visa']).isEmpty,
      isFalse,
    );
  });

  test('a summary without categories draws no breakdown', () {
    const summary = HotelReviewSummary(score: 8.5, reviewCount: 10);
    expect(summary.hasBreakdown, isFalse);
    expect(
      const HotelReviewSummary(
        score: 8.5,
        reviewCount: 10,
        categoryScores: <HotelReviewCategory, double>{
          HotelReviewCategory.value: 8,
        },
      ).hasBreakdown,
      isTrue,
    );
  });

  test('the gallery falls back to the card photo', () {
    expect(_hotel.galleryImages, <String>[_hotel.imageAsset]);
    expect(_hotel.hasCoordinates, isFalse);
  });

  test('nights come from the stay, not from a guess', () {
    final criteria = HotelSearchCriteria(
      checkIn: DateTime(2026, 8, 29),
      checkOut: DateTime(2026, 9, 1),
    );
    expect(criteria.nights, 3);
  });
}
