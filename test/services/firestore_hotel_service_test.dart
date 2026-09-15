import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel_detail.dart';
import 'package:kurdistan_paradise_travel_guide/services/firestore_hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';

Map<String, dynamic> hotelDoc({
  bool highlighted = false,
  bool active = true,
  Object? name = const {'en': 'Divan Erbil', 'ku': 'دیڤان', 'ar': 'ديفان'},
  Object? city = const {'en': 'Erbil'},
  Object? currencyCode = 'USD',
  Object? pricePerNightFrom = 120,
  Map<String, dynamic> extra = const {},
}) => {
  'name': ?name,
  'city': ?city,
  'highlighted': highlighted,
  'active': active,
  'starRating': 5,
  'pricePerNightFrom': ?pricePerNightFrom,
  'currencyCode': ?currencyCode,
  'amenities': ['wifi', 'pool'],
  'imageUrls': <String>[],
  ...extra,
};

Map<String, dynamic> offerDoc({
  Object? currency = 'USD',
  Object? nightlyPrice = 120,
  Object? totalPrice = 240,
  Object? roomTypeId = 'deluxe-king',
  Map<String, dynamic> extra = const {},
}) => {
  'roomTypeId': ?roomTypeId,
  'currency': ?currency,
  'nightlyPrice': ?nightlyPrice,
  'totalPrice': ?totalPrice,
  'taxes': 24,
  'fees': 5,
  'taxesIncluded': false,
  'breakfast': 'included',
  'cancellationType': 'free',
  'prepayment': 'none',
  'paymentTiming': 'payLater',
  'availableQuantity': 3,
  ...extra,
};

void main() {
  group('hotelFrom — mapping the approved schema', () {
    test('maps the documented field names onto the Dart model', () {
      final hotel = FirestoreHotelService.hotelFrom('divan', hotelDoc());

      expect(hotel, isNotNull);
      expect(hotel!.id, 'divan');
      expect(hotel.name.en, 'Divan Erbil');
      expect(hotel.city.en, 'Erbil');
      expect(hotel.starRating, 5);
      // pricePerNightFrom -> pricePerNight
      expect(hotel.pricePerNight, 120);
      expect(hotel.amenities, {HotelAmenity.wifi, HotelAmenity.pool});
    });

    test('highlighted carries through', () {
      expect(
        FirestoreHotelService.hotelFrom('a', hotelDoc(highlighted: true))!.highlighted,
        isTrue,
      );
      expect(
        FirestoreHotelService.hotelFrom('a', hotelDoc(highlighted: false))!.highlighted,
        isFalse,
      );
    });

    test('a missing highlighted reads as false, never as true', () {
      final doc = hotelDoc()..remove('highlighted');
      expect(FirestoreHotelService.hotelFrom('a', doc)!.highlighted, isFalse);
    });

    test('a non-boolean highlighted does not read as true', () {
      // A string "true" is truthy in many languages; it must not be here.
      final doc = hotelDoc()..['highlighted'] = 'true';
      expect(FirestoreHotelService.hotelFrom('a', doc)!.highlighted, isFalse);
    });

    test('distanceFromCenterKm is always null', () {
      // The field was declined (DATA_MODEL.md). The card hides the line rather
      // than showing a fabricated 0.0 km.
      final hotel = FirestoreHotelService.hotelFrom('a', hotelDoc());
      expect(hotel!.distanceFromCenterKm, isNull);
    });

    test('a document carrying distanceFromCenterKm still maps to null', () {
      final doc = hotelDoc(extra: {'distanceFromCenterKm': 2.6});
      expect(
        FirestoreHotelService.hotelFrom('a', doc)!.distanceFromCenterKm,
        isNull,
        reason: 'the field is not part of the approved schema',
      );
    });

    test('server-owned aggregates default to zero when absent', () {
      // No Cloud Function derives them yet, so "no score" is the honest state.
      final hotel = FirestoreHotelService.hotelFrom('a', hotelDoc());
      expect(hotel!.reviewScore, 0);
      expect(hotel.reviewCount, 0);
    });

    test('a geopoint location becomes latitude/longitude', () {
      final doc = hotelDoc(extra: {'location': const GeoPoint(36.2, 43.9)});
      final hotel = FirestoreHotelService.hotelFrom('a', doc);
      expect(hotel!.latitude, closeTo(36.2, 1e-9));
      expect(hotel.longitude, closeTo(43.9, 1e-9));
    });

    test('a missing locale falls back to English', () {
      final doc = hotelDoc(name: const {'en': 'Only English'});
      final hotel = FirestoreHotelService.hotelFrom('a', doc);
      expect(hotel!.name.ku, 'Only English');
      expect(hotel.name.ar, 'Only English');
    });

    test('an empty imageUrls falls back to the bundled card asset', () {
      final hotel = FirestoreHotelService.hotelFrom('a', hotelDoc());
      expect(hotel!.imageAsset, FirestoreHotelService.fallbackImageAsset);
    });

    test('a document with no name or city is rejected, not half-drawn', () {
      expect(FirestoreHotelService.hotelFrom('a', hotelDoc(name: null)), isNull);
      expect(FirestoreHotelService.hotelFrom('a', hotelDoc(city: null)), isNull);
    });

    test('an unknown amenity is ignored rather than crashing the card', () {
      final doc = hotelDoc(extra: {
        'amenities': ['wifi', 'teleportation'],
      });
      expect(
        FirestoreHotelService.hotelFrom('a', doc)!.amenities,
        {HotelAmenity.wifi},
      );
    });
  });

  // --- currency (approved 2026-09-15) ------------------------------------
  //
  // `pricePerNightFrom` states no currency of its own. Before this, the reader
  // hard-coded `currencyCode: 'USD'` on every hotel and defaulted an offer's
  // missing `currency` to USD — so the first IQD property would have been
  // drawn at roughly 1/1300th of its real rate. Nothing is defaulted now.

  group('hotel currency — never assumed, never defaulted', () {
    test('a USD hotel keeps its own price and code', () {
      final hotel = FirestoreHotelService.hotelFrom(
        'divan',
        hotelDoc(currencyCode: 'USD', pricePerNightFrom: 120),
      );
      expect(hotel!.currencyCode, 'USD');
      expect(hotel.pricePerNight, 120);
    });

    test('an IQD hotel keeps ITS own price and code', () {
      // The whole point: 157200 IQD must not be read as 157200 USD, nor
      // converted at store time.
      final hotel = FirestoreHotelService.hotelFrom(
        'divan',
        hotelDoc(currencyCode: 'IQD', pricePerNightFrom: 157200),
      );
      expect(hotel!.currencyCode, 'IQD');
      expect(hotel.pricePerNight, 157200);
    });

    for (final bad in ['EUR', 'GBP', 'usd', '', 'BTC', 'US']) {
      test('a hotel priced in "$bad" is dropped rather than shown', () {
        expect(
          FirestoreHotelService.hotelFrom('a', hotelDoc(currencyCode: bad)),
          isNull,
        );
      });
    }

    test('a MISSING currency does not silently become USD', () {
      // The regression this whole change exists for: the old reader wrote
      // `currencyCode: 'USD'` unconditionally, so this document rendered a
      // price card. It must now render nothing at all.
      final hotel = FirestoreHotelService.hotelFrom(
        'a',
        hotelDoc(currencyCode: null),
      );
      expect(hotel, isNull);
    });

    test('a non-string currency is dropped', () {
      expect(
        FirestoreHotelService.hotelFrom('a', hotelDoc(currencyCode: 1)),
        isNull,
      );
      expect(
        FirestoreHotelService.hotelFrom(
          'a',
          hotelDoc(currencyCode: const ['USD']),
        ),
        isNull,
      );
    });

    test('a bad or missing pricePerNightFrom is dropped, not read as 0', () {
      // A free hotel is a claim about a named real property, not a default.
      expect(
        FirestoreHotelService.hotelFrom('a', hotelDoc(pricePerNightFrom: null)),
        isNull,
      );
      expect(
        FirestoreHotelService.hotelFrom(
          'a',
          hotelDoc(pricePerNightFrom: '120'),
        ),
        isNull,
      );
      expect(
        FirestoreHotelService.hotelFrom('a', hotelDoc(pricePerNightFrom: -1)),
        isNull,
      );
    });
  });

  group('offer currency — never assumed, never defaulted', () {
    test('a USD offer keeps its own prices and code', () {
      final offer = FirestoreHotelService.offerFrom('flex', offerDoc());
      expect(offer!.currencyCode, 'USD');
      expect(offer.nightlyPrice, 120);
      expect(offer.totalPrice, 240);
    });

    test('an IQD offer keeps ITS own prices and code', () {
      final offer = FirestoreHotelService.offerFrom(
        'flex',
        offerDoc(currency: 'IQD', nightlyPrice: 157200, totalPrice: 314400),
      );
      expect(offer!.currencyCode, 'IQD');
      expect(offer.totalPrice, 314400);
    });

    for (final bad in ['EUR', 'GBP', 'usd', '', 'BTC']) {
      test('an offer priced in "$bad" is dropped rather than shown', () {
        expect(
          FirestoreHotelService.offerFrom('flex', offerDoc(currency: bad)),
          isNull,
        );
      });
    }

    test('an offer with a MISSING currency does not become USD', () {
      // This is the figure checkout quotes against, so a defaulted code here
      // would be a wrong number on a charge, not just on a card.
      expect(
        FirestoreHotelService.offerFrom('flex', offerDoc(currency: null)),
        isNull,
      );
    });

    test('an offer with a non-string currency is dropped', () {
      expect(
        FirestoreHotelService.offerFrom('flex', offerDoc(currency: 1)),
        isNull,
      );
    });

    test('an offer with a bad or missing price is dropped', () {
      expect(
        FirestoreHotelService.offerFrom('f', offerDoc(nightlyPrice: null)),
        isNull,
      );
      expect(
        FirestoreHotelService.offerFrom('f', offerDoc(totalPrice: '240')),
        isNull,
      );
      expect(
        FirestoreHotelService.offerFrom('f', offerDoc(totalPrice: -5)),
        isNull,
      );
    });

    test('a valid offer still maps the rest of the schema', () {
      // Guards against the currency gate short-circuiting the whole mapper.
      final offer = FirestoreHotelService.offerFrom('flex', offerDoc());
      expect(offer!.roomTypeId, 'deluxe-king');
      expect(offer.taxesIncluded, isFalse);
      expect(offer.availableQuantity, 3);
      expect(offer.breakfast, BreakfastPolicy.included);
      expect(offer.cancellationType, CancellationType.free);
    });

    test('the supported set is exactly the two the rules allow', () {
      expect(FirestoreHotelService.supportedCurrencies, ['USD', 'IQD']);
    });
  });

  group('fallback when Firebase is unavailable', () {
    // FirebaseBootstrap is never initialised under flutter test, and no
    // firestore override is supplied, so these exercise the real fallback.
    final service = FirestoreHotelService();

    test('trending falls back to the preview catalogue', () async {
      final live = await service.trendingHotels();
      final preview = await const PreviewHotelService().trendingHotels();
      expect(live.map((h) => h.id), preview.map((h) => h.id));
    });

    test('search falls back', () async {
      final criteria = HotelSearchCriteria(
        checkIn: DateTime(2027, 5, 1),
        checkOut: DateTime(2027, 5, 3),
      );
      expect(await service.searchHotels(criteria), isNotEmpty);
    });

    test('detail falls back', () async {
      final detail = await service.fetchDetail('preview-divan-erbil');
      expect(detail, isNotNull);
      expect(detail!.roomTypes, isNotEmpty);
      expect(detail.roomOffers, isNotEmpty);
    });

    test('an unknown hotel resolves to null through the fallback', () async {
      expect(await service.fetchDetail('no-such-hotel'), isNull);
    });

    test('destinations fall back', () async {
      expect(await service.searchDestinations('Erb'), isNotEmpty);
    });

    test('a one-character query still matches, as the preview does', () async {
      // Pinned deliberately: the Firestore service must not introduce a
      // minimum query length the destination picker never had.
      expect(await service.searchDestinations('E'), isNotEmpty);
    });

    test('an empty query lists every destination, as the preview does', () async {
      final all = await service.searchDestinations('');
      final preview = await const PreviewHotelService().searchDestinations('');
      expect(all.length, preview.length);
    });
  });
}
