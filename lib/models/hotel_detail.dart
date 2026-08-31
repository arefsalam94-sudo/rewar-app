import 'package:flutter/foundation.dart';

import 'hotel.dart';

/// Everything the Hotel Details page draws that is not already on [Hotel].
///
/// Split from [Hotel] on purpose: the list and carousel cards need a hotel to
/// be cheap, and none of this is readable on a card. When hotels reach
/// Firestore this maps to `hotels/{id}` plus its `facilities`, `nearby`,
/// `rooms` and `offers` data — see `DATA_MODEL.md`.
///
/// Every collection defaults to empty rather than being required. A section
/// with no data hides itself; it never draws an invented row.
@immutable
class HotelDetail {
  const HotelDetail({
    required this.hotel,
    this.facilities = const <HotelFacility>[],
    this.reviewSummary,
    this.nearbyPlaces = const <HotelNearbyPlace>[],
    this.roomTypes = const <HotelRoomType>[],
    this.roomOffers = const <HotelRoomOffer>[],
    this.policies,
  });

  final Hotel hotel;
  final List<HotelFacility> facilities;
  final HotelReviewSummary? reviewSummary;
  final List<HotelNearbyPlace> nearbyPlaces;
  final List<HotelRoomType> roomTypes;
  final List<HotelRoomOffer> roomOffers;
  final HotelPolicies? policies;

  /// Facilities grouped for the "See all" sheet, in the declared enum order so
  /// the groups never reshuffle between openings.
  Map<HotelFacilityCategory, List<HotelFacility>> get facilitiesByCategory {
    final grouped = <HotelFacilityCategory, List<HotelFacility>>{};
    for (final category in HotelFacilityCategory.values) {
      final matches = facilities
          .where((facility) => facility.category == category)
          .toList(growable: false);
      if (matches.isNotEmpty) grouped[category] = matches;
    }
    return grouped;
  }

  /// The cheapest offer, for a "from" price once offers are real.
  HotelRoomOffer? get leadOffer {
    if (roomOffers.isEmpty) return null;
    final sorted = <HotelRoomOffer>[...roomOffers]
      ..sort((a, b) => a.nightlyPrice.compareTo(b.nightlyPrice));
    return sorted.first;
  }
}

/// The groups the facilities sheet renders. Named after categories the major
/// booking platforms already publish, so provider data maps onto them without
/// a translation table per provider.
enum HotelFacilityCategory {
  general,
  internet,
  parking,
  foodAndDrink,
  wellness,
  pool,
  transportation,
  roomFacilities,
  family,
  accessibility,
  business,
  safety,
}

/// One facility a hotel offers.
///
/// [iconKey] is a stable string rather than an `IconData`, because this data
/// will eventually come out of Firestore and a database cannot hold a Flutter
/// icon. The key is resolved to a glyph in `hotel_parts.dart`; an unknown key
/// falls back to a neutral check, never to an invented icon.
@immutable
class HotelFacility {
  const HotelFacility({
    required this.id,
    required this.name,
    required this.category,
    required this.iconKey,
  });

  final String id;
  final HotelText name;
  final HotelFacilityCategory category;
  final String iconKey;
}

/// The scored categories on the review-breakdown card.
enum HotelReviewCategory {
  location,
  cleanliness,
  comfort,
  service,
  value,
  facilities,
  wifi,
}

/// The aggregate drawn by the Reviews card.
///
/// **Server-owned** once hotels are on Firestore, exactly like
/// `nature_spots.reviewScore` — never averaged in the client from whichever
/// page of reviews happened to be downloaded.
@immutable
class HotelReviewSummary {
  const HotelReviewSummary({
    required this.score,
    required this.reviewCount,
    this.categoryScores = const <HotelReviewCategory, double>{},
  }) : assert(score >= 0 && score <= 10),
       assert(reviewCount >= 0);

  /// 0–10, the app-wide review scale.
  final double score;
  final int reviewCount;

  /// 0–10 per category. A category with no data is absent, not zero — a bar
  /// drawn at zero reads as "rated terribly", which is not the same thing.
  final Map<HotelReviewCategory, double> categoryScores;

  static const double maxScore = 10;

  bool get hasBreakdown => categoryScores.isNotEmpty;
}

enum NearbyPlaceType {
  landmark,
  park,
  mall,
  transport,
  airport,
  restaurant,
  atm,
  hospital,
  other,
}

/// One point of interest near the hotel.
@immutable
class HotelNearbyPlace {
  const HotelNearbyPlace({
    required this.id,
    required this.name,
    required this.type,
    required this.distanceMeters,
    this.minutes,
    this.latitude,
    this.longitude,
  }) : assert(distanceMeters >= 0);

  final String id;
  final HotelText name;
  final NearbyPlaceType type;
  final int distanceMeters;

  /// Estimated travel time. Null when the source gives a distance only — the
  /// row then shows the distance alone rather than a guessed duration.
  final int? minutes;
  final double? latitude;
  final double? longitude;
}

enum BedType { single, twin, doubleBed, queen, king, sofa, bunk }

@immutable
class BedConfiguration {
  const BedConfiguration({required this.type, this.count = 1})
    : assert(count >= 1);

  final BedType type;
  final int count;
}

/// A room a hotel sells. Permanent property data — never price or
/// availability, which belong to [HotelRoomOffer] and change per search.
@immutable
class HotelRoomType {
  const HotelRoomType({
    required this.id,
    required this.hotelId,
    required this.name,
    this.description,
    this.images = const <String>[],
    this.sizeSqm,
    this.adultCapacity = 2,
    this.childCapacity = 0,
    this.maxOccupancy = 2,
    this.beds = const <BedConfiguration>[],
    this.facilities = const <HotelFacility>[],
  }) : assert(adultCapacity >= 1),
       assert(childCapacity >= 0),
       assert(maxOccupancy >= 1);

  final String id;
  final String hotelId;
  final HotelText name;
  final HotelText? description;
  final List<String> images;
  final double? sizeSqm;
  final int adultCapacity;
  final int childCapacity;
  final int maxOccupancy;
  final List<BedConfiguration> beds;
  final List<HotelFacility> facilities;
}

enum BreakfastPolicy { included, extra, unavailable }

enum CancellationType { free, partial, nonRefundable }

enum PrepaymentType { none, partial, full }

enum PaymentTiming { payNow, payLater, payAtProperty }

/// A bookable rate for one [HotelRoomType], for one search.
///
/// Provider identifiers are held separately from our own ids so a room can be
/// re-priced or booked through whichever provider supplied it without any
/// provider-specific branch reaching a widget.
///
/// [taxes] and [fees] are never optional to display: whether they are included
/// is a stored flag, so the UI can always state which of the two it is showing.
@immutable
class HotelRoomOffer {
  const HotelRoomOffer({
    required this.id,
    required this.roomTypeId,
    required this.currencyCode,
    required this.nightlyPrice,
    required this.totalPrice,
    this.name,
    this.mealPlan,
    this.taxes = 0,
    this.fees = 0,
    this.taxesIncluded = false,
    this.breakfast = BreakfastPolicy.unavailable,
    this.cancellationType = CancellationType.nonRefundable,
    this.cancellationDeadline,
    this.cancellationPenalty,
    this.prepayment = PrepaymentType.none,
    this.paymentTiming = PaymentTiming.payAtProperty,
    this.availableQuantity = 0,
    this.providerId,
    this.providerHotelId,
    this.providerRoomId,
    this.ratePlanId,
    this.searchSessionId,
    this.expiresAt,
  }) : assert(nightlyPrice >= 0),
       assert(totalPrice >= 0),
       assert(taxes >= 0),
       assert(fees >= 0),
       assert(availableQuantity >= 0);

  final String id;
  final String roomTypeId;
  final HotelText? name;
  final HotelText? mealPlan;
  final String currencyCode;
  final double nightlyPrice;
  final double totalPrice;
  final double taxes;
  final double fees;
  final bool taxesIncluded;
  final BreakfastPolicy breakfast;
  final CancellationType cancellationType;
  final DateTime? cancellationDeadline;
  final double? cancellationPenalty;
  final PrepaymentType prepayment;
  final PaymentTiming paymentTiming;

  /// How many of this room remain at this rate. Scarcity copy is only ever
  /// drawn from this number — never manufactured to create urgency.
  final int availableQuantity;

  final String? providerId;
  final String? providerHotelId;
  final String? providerRoomId;
  final String? ratePlanId;
  final String? searchSessionId;
  final DateTime? expiresAt;

  bool get isAvailable => availableQuantity > 0;

  bool get isExpired => expiresAt?.isBefore(DateTime.now()) ?? false;
}

/// House rules, shown in the collapsible Property policies section.
///
/// Every field is nullable and every row hides without data, so a property
/// that has published nothing shows nothing rather than a default someone
/// could act on.
@immutable
class HotelPolicies {
  const HotelPolicies({
    this.checkInFrom,
    this.checkOutUntil,
    this.childPolicy,
    this.cribPolicy,
    this.extraBedPolicy,
    this.minimumAge,
    this.petPolicy,
    this.smokingPolicy,
    this.acceptedPaymentMethods = const <String>[],
    this.specialRequestsSupported,
    this.accessibility,
  });

  /// Local times as `HH:mm` strings — a wall-clock time at the property, not
  /// an instant, so a `DateTime` would be the wrong type.
  final String? checkInFrom;
  final String? checkOutUntil;

  final HotelText? childPolicy;
  final HotelText? cribPolicy;
  final HotelText? extraBedPolicy;
  final int? minimumAge;
  final HotelText? petPolicy;
  final HotelText? smokingPolicy;
  final List<String> acceptedPaymentMethods;
  final bool? specialRequestsSupported;
  final HotelText? accessibility;

  bool get isEmpty =>
      checkInFrom == null &&
      checkOutUntil == null &&
      childPolicy == null &&
      cribPolicy == null &&
      extraBedPolicy == null &&
      minimumAge == null &&
      petPolicy == null &&
      smokingPolicy == null &&
      acceptedPaymentMethods.isEmpty &&
      specialRequestsSupported == null &&
      accessibility == null;
}
