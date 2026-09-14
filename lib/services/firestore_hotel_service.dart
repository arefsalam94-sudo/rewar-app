import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/hotel.dart';
import '../models/hotel_detail.dart';
import 'firebase_bootstrap.dart';
import 'hotel_service.dart';

/// Reads the hotel catalogue from Firestore (`DATA_MODEL.md` → hotels),
/// falling back to [PreviewHotelService] when Firebase is unavailable or the
/// live data cannot be loaded.
///
/// Public read, admin-only write (`firestore.rules`) — Where to Stay is
/// browsable by a guest.
///
/// ## Why it falls back rather than throwing
///
/// A stale catalogue entry is a much smaller harm than an error page in front
/// of someone trying to find a room. Every failure path — Firebase absent,
/// offline, permission denied, malformed document — lands on the bundled
/// preview data, which is the same content the seed script wrote.
///
/// ## Fields the schema does not carry
///
/// `distanceFromCenterKm` is deliberately absent from `hotels` and stays null
/// here, so the card hides that line rather than inventing a number.
/// `currencyCode` defaults to USD for the list card's "from" price; the real
/// currency of a bookable rate lives on the offer, which is what checkout
/// reads.
class FirestoreHotelService implements HotelService {
  FirestoreHotelService({
    FirebaseFirestore? firestore,
    this.fallback = const PreviewHotelService(),
  }) : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  /// Serves the bundled preview catalogue on every failure path.
  final HotelService fallback;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const String collection = 'hotels';

  /// Card image used until `imageUrls` carries real Storage URLs. The seeded
  /// documents leave that array empty on purpose (SEED_DATA.md).
  static const String fallbackImageAsset = 'assets/images/journey-stay.png';

  bool get _live => FirebaseBootstrap.isReady || _firestoreOverride != null;

  // --- HotelService ------------------------------------------------------

  @override
  Future<List<Hotel>> trendingHotels() async {
    if (!_live) return fallback.trendingHotels();
    try {
      final all = await _activeHotels();
      if (all.isEmpty) return await fallback.trendingHotels();
      return all;
    } catch (error) {
      debugPrint('Could not load hotels: $error');
      return fallback.trendingHotels();
    }
  }

  @override
  Future<List<Hotel>> searchHotels(HotelSearchCriteria criteria) async {
    if (!_live) return fallback.searchHotels(criteria);
    try {
      final all = await _activeHotels();
      if (all.isEmpty) return await fallback.searchHotels(criteria);

      // Filtered in Dart rather than in the query, for the same reason
      // Explore Nature does it: the chips are a small set over a small
      // catalogue, and a composite index per combination would cost more than
      // it saves.
      return all
          .where((hotel) {
            final destination = criteria.destination;
            final destinationMatches =
                destination == null ||
                hotel.city.en.toLowerCase() ==
                    destination.name.en.toLowerCase();
            final amenitiesMatch = criteria.amenities.every(
              hotel.amenities.contains,
            );
            return destinationMatches && amenitiesMatch;
          })
          .toList(growable: false);
    } catch (error) {
      debugPrint('Could not search hotels: $error');
      return fallback.searchHotels(criteria);
    }
  }

  @override
  Future<List<HotelDestination>> searchDestinations(String query) async {
    if (!_live) return fallback.searchDestinations(query);
    final normalized = query.trim().toLowerCase();
    try {
      final all = await _activeHotels();
      if (all.isEmpty) return await fallback.searchDestinations(query);

      // Destinations are the distinct cities of the live catalogue, so a city
      // cannot be offered that has no hotels behind it.
      final seen = <String>{};
      final out = <HotelDestination>[];
      for (final hotel in all) {
        final key = hotel.city.en.toLowerCase();
        if (seen.contains(key)) continue;
        // Matching mirrors PreviewHotelService exactly, including "an empty
        // query lists every destination". Imposing a minimum length here
        // would silently change the picker's behaviour, which is not part of
        // this migration.
        final haystack = [
          hotel.city.en,
          hotel.city.ku,
          hotel.city.ar,
        ].join(' ').toLowerCase();
        if (normalized.isNotEmpty && !haystack.contains(normalized)) continue;
        seen.add(key);
        out.add(HotelDestination(id: key, name: hotel.city));
      }
      return out;
    } catch (error) {
      debugPrint('Could not search destinations: $error');
      return fallback.searchDestinations(query);
    }
  }

  @override
  Future<HotelDetail?> fetchDetail(String hotelId) async {
    if (!_live) return fallback.fetchDetail(hotelId);
    try {
      final snapshot = await _firestore
          .collection(collection)
          .doc(hotelId)
          .get();
      if (!snapshot.exists) {
        // Not in the live catalogue. Try the preview set before giving up, so
        // a hotel opened from a favourite saved before the migration still
        // resolves; the detail screen shows "not found" if neither has it.
        return await fallback.fetchDetail(hotelId);
      }

      final data = snapshot.data();
      if (data == null) return await fallback.fetchDetail(hotelId);
      final hotel = _hotelFrom(snapshot.id, data);
      if (hotel == null) return await fallback.fetchDetail(hotelId);

      final ref = _firestore.collection(collection).doc(hotelId);
      final rooms = await ref.collection('rooms').get();
      final offers = await ref.collection('offers').get();

      final roomTypes = <HotelRoomType>[];
      for (final doc in rooms.docs) {
        final room = _roomFrom(hotelId, doc.id, doc.data());
        if (room != null) roomTypes.add(room);
      }
      final roomOffers = <HotelRoomOffer>[];
      for (final doc in offers.docs) {
        final offer = _offerFrom(doc.id, doc.data());
        if (offer != null) roomOffers.add(offer);
      }

      return HotelDetail(
        hotel: hotel,
        facilities: _facilitiesFrom(data['facilities']),
        nearbyPlaces: _nearbyFrom(data['nearby']),
        roomTypes: roomTypes,
        roomOffers: roomOffers,
        policies: _policiesFrom(data['policies']),
        // reviewSummary stays null: the aggregates are server-owned and no
        // Cloud Function derives them yet, so there is nothing honest to show.
        reviewSummary: null,
      );
    } catch (error) {
      debugPrint('Could not load hotel $hotelId: $error');
      return fallback.fetchDetail(hotelId);
    }
  }

  // --- reading -----------------------------------------------------------

  /// Every hotel a customer may see. `active: false` is filtered OUT here, in
  /// one place, so no screen can forget to.
  Future<List<Hotel>> _activeHotels() async {
    final snapshot = await _firestore
        .collection(collection)
        .where('active', isEqualTo: true)
        .get();
    final out = <Hotel>[];
    for (final doc in snapshot.docs) {
      final hotel = _hotelFrom(doc.id, doc.data());
      if (hotel != null) out.add(hotel);
    }
    return out;
  }

  @visibleForTesting
  static Hotel? hotelFrom(String id, Map<String, dynamic> data) =>
      _hotelFrom(id, data);

  static Hotel? _hotelFrom(String id, Map<String, dynamic> data) {
    final name = _textFrom(data['name']);
    final city = _textFrom(data['city']);
    // A document with no name or city cannot be drawn as a card at all.
    if (name == null || city == null) return null;

    final location = data['location'];
    final images = _stringList(data['imageUrls']);

    return Hotel(
      id: id,
      name: name,
      city: city,
      address: _textFrom(data['address']),
      imageAsset: images.isNotEmpty ? images.first : fallbackImageAsset,
      images: images,
      starRating: _int(data['starRating']).clamp(0, 5),
      // Server-owned aggregates. Absent until a Cloud Function derives them,
      // and 0 is how the card renders "no score yet".
      reviewScore: _double(data['reviewScore']).clamp(0, 10),
      reviewCount: _int(data['ratingCount']),
      // Deliberately null — see the class doc.
      distanceFromCenterKm: null,
      pricePerNight: _double(data['pricePerNightFrom']),
      currencyCode: 'USD',
      amenities: _amenitiesFrom(data['amenities']),
      highlighted: data['highlighted'] == true,
      latitude: location is GeoPoint ? location.latitude : null,
      longitude: location is GeoPoint ? location.longitude : null,
    );
  }

  static HotelRoomType? _roomFrom(
    String hotelId,
    String id,
    Map<String, dynamic> data,
  ) {
    final name = _textFrom(data['name']);
    if (name == null) return null;
    return HotelRoomType(
      id: id,
      hotelId: hotelId,
      name: name,
      description: _textFrom(data['description']),
      images: _stringList(data['imageUrls']),
      sizeSqm: data['sizeSqm'] == null ? null : _double(data['sizeSqm']),
      adultCapacity: _int(data['adultCapacity']),
      childCapacity: _int(data['childCapacity']),
      maxOccupancy: _int(data['maxOccupancy']),
      beds: _bedsFrom(data['bedConfiguration']),
      facilities: _facilitiesFrom(data['facilities']),
    );
  }

  static HotelRoomOffer? _offerFrom(String id, Map<String, dynamic> data) {
    final roomTypeId = data['roomTypeId'];
    if (roomTypeId is! String || roomTypeId.isEmpty) return null;
    final deadline = data['cancellationDeadline'];
    return HotelRoomOffer(
      id: id,
      roomTypeId: roomTypeId,
      currencyCode: data['currency'] is String
          ? data['currency'] as String
          : 'USD',
      nightlyPrice: _double(data['nightlyPrice']),
      totalPrice: _double(data['totalPrice']),
      taxes: _double(data['taxes']),
      fees: _double(data['fees']),
      // Stored, never inferred (DATA_MODEL.md) — the UI must always be able to
      // state which figure it is showing.
      taxesIncluded: data['taxesIncluded'] == true,
      breakfast: _enum(
        BreakfastPolicy.values,
        data['breakfast'],
        BreakfastPolicy.unavailable,
      ),
      cancellationType: _enum(
        CancellationType.values,
        data['cancellationType'],
        CancellationType.nonRefundable,
      ),
      cancellationDeadline: deadline is Timestamp ? deadline.toDate() : null,
      cancellationPenalty: data['cancellationPenalty'] == null
          ? null
          : _double(data['cancellationPenalty']),
      prepayment: _enum(
        PrepaymentType.values,
        data['prepayment'],
        PrepaymentType.none,
      ),
      paymentTiming: _enum(
        PaymentTiming.values,
        data['paymentTiming'],
        PaymentTiming.payAtProperty,
      ),
      availableQuantity: _int(data['availableQuantity']),
    );
  }

  static List<HotelFacility> _facilitiesFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <HotelFacility>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = _textFrom(item['name']);
      final id = item['id'];
      if (name == null || id is! String) continue;
      out.add(
        HotelFacility(
          id: id,
          name: name,
          iconKey: item['iconKey'] is String ? item['iconKey'] as String : '',
          category: _enum(
            HotelFacilityCategory.values,
            item['category'],
            HotelFacilityCategory.general,
          ),
        ),
      );
    }
    return out;
  }

  static List<HotelNearbyPlace> _nearbyFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <HotelNearbyPlace>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = _textFrom(item['name']);
      final id = item['id'];
      if (name == null || id is! String) continue;
      out.add(
        HotelNearbyPlace(
          id: id,
          name: name,
          type: _enum(
            NearbyPlaceType.values,
            item['placeType'],
            NearbyPlaceType.landmark,
          ),
          distanceMeters: _int(item['distanceMeters']),
          minutes: item['minutes'] == null ? null : _int(item['minutes']),
          latitude: item['lat'] == null ? null : _double(item['lat']),
          longitude: item['lng'] == null ? null : _double(item['lng']),
        ),
      );
    }
    return out;
  }

  static List<BedConfiguration> _bedsFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <BedConfiguration>[];
    for (final item in raw) {
      if (item is! Map) continue;
      // DATA_MODEL.md writes `double`; the Dart enum has to call it
      // `doubleBed` because `double` is a reserved word.
      final wire = item['type'] == 'double' ? 'doubleBed' : item['type'];
      out.add(
        BedConfiguration(
          type: _enum(BedType.values, wire, BedType.single),
          count: _int(item['count']),
        ),
      );
    }
    return out;
  }

  static HotelPolicies? _policiesFrom(Object? raw) {
    if (raw is! Map) return null;
    // Every field is optional and each row hides without data, so a property
    // that published nothing shows nothing.
    return HotelPolicies(
      checkInFrom: raw['checkInFrom'] as String?,
      checkOutUntil: raw['checkOutUntil'] as String?,
      childPolicy: _textFrom(raw['childPolicy']),
      cribPolicy: _textFrom(raw['cribPolicy']),
      extraBedPolicy: _textFrom(raw['extraBedPolicy']),
      minimumAge: raw['minimumAge'] == null ? null : _int(raw['minimumAge']),
      petPolicy: _textFrom(raw['petPolicy']),
      smokingPolicy: _textFrom(raw['smokingPolicy']),
      accessibility: _textFrom(raw['accessibility']),
      acceptedPaymentMethods: _stringList(raw['acceptedPaymentMethods']),
      specialRequestsSupported: raw['specialRequestsSupported'] as bool?,
    );
  }

  static Set<HotelAmenity> _amenitiesFrom(Object? raw) {
    if (raw is! List) return const {};
    final out = <HotelAmenity>{};
    for (final item in raw) {
      for (final amenity in HotelAmenity.values) {
        if (amenity.name == item) out.add(amenity);
      }
    }
    return out;
  }

  // --- primitives --------------------------------------------------------

  static HotelText? _textFrom(Object? raw) {
    if (raw is! Map) return null;
    final en = raw['en'];
    if (en is! String || en.trim().isEmpty) return null;
    // A missing locale falls back to English, the same rule as every other
    // catalog collection.
    return HotelText(
      en: en,
      ku: raw['ku'] is String ? raw['ku'] as String : en,
      ar: raw['ar'] is String ? raw['ar'] as String : en,
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String) item,
    ];
  }

  static int _int(Object? raw) => raw is num ? raw.toInt() : 0;

  static double _double(Object? raw) => raw is num ? raw.toDouble() : 0;

  static T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}
