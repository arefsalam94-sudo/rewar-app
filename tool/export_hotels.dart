// Exports the preview hotel catalogue to JSON for the seed script.
//
// `PreviewHotelService` is the single source of truth for this content, and
// Node cannot read Dart — so rather than transcribing three hotels, their
// facilities, nearby places, rooms and offers into the seeder by hand, this
// regenerates the JSON the seeder reads.
//
//   flutter test tool/export_hotels.dart
//
// Run through the Flutter test harness rather than `dart run`, because the
// hotel models import `package:flutter/foundation.dart` for @immutable and the
// bare Dart VM cannot load the Flutter SDK. It lives under tool/ and not test/,
// so the default `flutter test` run never picks it up — it is a generator, not
// a test. `test()` (unlike `testWidgets`) runs on the real clock, so the
// preview service's simulated latency resolves normally.
//
// Output shape is exactly the `hotels` schema in DATA_MODEL.md.
//
// ## What is deliberately NOT exported
//
// * **The rating aggregates** — `reviewScore`, `ratingCount`,
//   `ratingBreakdown`, `categoryScores` are server-owned and derived from the
//   reviews subcollection by a Cloud Function. Seeding a hand-typed average
//   would be overwritten by the first real review, and until the function is
//   deployed the honest state is "no score yet" — the same rule
//   `tool/seed_explore_nature.js` already follows.
// * **`imageUrls` is written empty**, matching nature_spots and tours. The
//   preview images are bundled ASSET paths, and the schema documents this
//   field as Storage URLs; writing asset paths into it would be a type-lie
//   that the admin panel and any future CDN logic would both trip over.
// * **Fields the Dart model has but the schema does not** —
//   `distanceFromCenterKm` and `imageAsset`.
//   `distanceFromCenterKm` was explicitly declined (DATA_MODEL.md): there is no
//   verified source for it, so the card hides that line instead.
//   DATA_MODEL.md is the contract; inventing Firestore fields to match a Dart
//   class would be the drift this exporter exists to prevent. They stay
//   client-side concerns.
// * **`region` / `country`** — the schema has them, the preview data does not.
//   Deriving them from the address string would be fabricating catalogue data
//   about named real properties. Left absent.
//
// ## Currency
//
// `currencyCode` IS exported, and is required (approved 2026-09-15). It was
// previously withheld, which left `pricePerNightFrom` denominated in nothing
// and the reader defaulting it to USD — a silent 1300x mispricing waiting for
// the first IQD property. The value written is whatever `PreviewHotelService`
// states; no price is converted or invented here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel_detail.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_reviews_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
// `NatureReview` — the hotel reviews page reuses the nature-spot review model
// through a service adapter (DATA_MODEL.md), so the exporter reads that type.
import 'package:kurdistan_paradise_travel_guide/models/nature_detail.dart';

Map<String, Object?> text(HotelText t) => {'en': t.en, 'ku': t.ku, 'ar': t.ar};

Map<String, Object?>? textOrNull(HotelText? t) => t == null ? null : text(t);

/// DATA_MODEL.md documents bed types as `double`, but the Dart enum has to
/// call it `doubleBed` because `double` is a reserved word.
String bedType(BedType type) => type == BedType.doubleBed ? 'double' : type.name;

Map<String, Object?> facility(HotelFacility f) => {
  'id': f.id,
  'iconKey': f.iconKey,
  'name': text(f.name),
  'category': f.category.name,
};

Map<String, Object?> nearby(HotelNearbyPlace p) => {
  'id': p.id,
  'name': text(p.name),
  'placeType': p.type.name,
  'distanceMeters': p.distanceMeters,
  if (p.minutes != null) 'minutes': p.minutes,
  if (p.latitude != null) 'lat': p.latitude,
  if (p.longitude != null) 'lng': p.longitude,
};

Map<String, Object?>? policies(HotelPolicies? p) {
  if (p == null) return null;
  // Every field is optional and each row hides without data, so only emit what
  // the property has actually published.
  return {
    if (p.checkInFrom != null) 'checkInFrom': p.checkInFrom,
    if (p.checkOutUntil != null) 'checkOutUntil': p.checkOutUntil,
    if (p.childPolicy != null) 'childPolicy': text(p.childPolicy!),
    if (p.cribPolicy != null) 'cribPolicy': text(p.cribPolicy!),
    if (p.extraBedPolicy != null) 'extraBedPolicy': text(p.extraBedPolicy!),
    if (p.minimumAge != null) 'minimumAge': p.minimumAge,
    if (p.petPolicy != null) 'petPolicy': text(p.petPolicy!),
    if (p.smokingPolicy != null) 'smokingPolicy': text(p.smokingPolicy!),
    if (p.accessibility != null) 'accessibility': text(p.accessibility!),
    if (p.acceptedPaymentMethods.isNotEmpty)
      'acceptedPaymentMethods': p.acceptedPaymentMethods,
    if (p.specialRequestsSupported != null)
      'specialRequestsSupported': p.specialRequestsSupported,
  };
}

Map<String, Object?> room(HotelRoomType r) => {
  'name': text(r.name),
  if (r.description != null) 'description': text(r.description!),
  // Empty for the same reason as the hotel's — see the header.
  'imageUrls': <String>[],
  if (r.sizeSqm != null) 'sizeSqm': r.sizeSqm,
  'adultCapacity': r.adultCapacity,
  'childCapacity': r.childCapacity,
  'maxOccupancy': r.maxOccupancy,
  'bedConfiguration': [
    for (final b in r.beds) {'type': bedType(b.type), 'count': b.count},
  ],
  'facilities': [for (final f in r.facilities) facility(f)],
};

Map<String, Object?> offer(HotelRoomOffer o) => {
  'roomTypeId': o.roomTypeId,
  'currency': o.currencyCode,
  'nightlyPrice': o.nightlyPrice,
  'totalPrice': o.totalPrice,
  'taxes': o.taxes,
  'fees': o.fees,
  'taxesIncluded': o.taxesIncluded,
  'breakfast': o.breakfast.name,
  'cancellationType': o.cancellationType.name,
  if (o.cancellationDeadline != null)
    'cancellationDeadline': o.cancellationDeadline!.toUtc().toIso8601String(),
  if (o.cancellationPenalty != null)
    'cancellationPenalty': o.cancellationPenalty,
  'prepayment': o.prepayment.name,
  'paymentTiming': o.paymentTiming.name,
  'availableQuantity': o.availableQuantity,
};

void main() {
  test('export the preview hotel catalogue to tool/hotels_seed.json', export);
}

Future<void> export() async {
  const service = PreviewHotelService();
  final out = <String, Object?>{
    '_comment':
        'GENERATED by tool/export_hotels.dart from PreviewHotelService. '
        'Do not edit by hand — edit the Dart preview data and re-run the '
        'exporter, or the app fallback and Firestore will disagree. '
        'Rating aggregates and imageUrls are deliberately omitted/empty; '
        'see the exporter header.',
  };

  var roomCount = 0;
  var offerCount = 0;
  var reviewCount = 0;
  final reviewService = PreviewHotelReviewService();

  for (final hotel in PreviewHotelService.hotels) {
    final detail = await service.fetchDetail(hotel.id);

    final doc = <String, Object?>{
      'name': text(hotel.name),
      'city': text(hotel.city),
      if (hotel.address != null) 'address': text(hotel.address!),
      if (hotel.latitude != null && hotel.longitude != null)
        'location': {'lat': hotel.latitude, 'lng': hotel.longitude},
      'imageUrls': <String>[],
      // Approved 2026-09-13. `highlighted` carries the preview data's own
      // trending flag through unchanged, so the carousel shows exactly what it
      // showed before the swap. Every seeded hotel is active.
      'highlighted': hotel.highlighted,
      'active': true,
      'starRating': hotel.starRating,
      'pricePerNightFrom': hotel.pricePerNight,
      // The currency `pricePerNightFrom` is stated in. Required, never
      // defaulted — see the header.
      'currencyCode': hotel.currencyCode,
      'amenities': [for (final a in hotel.amenities) a.name],
    };

    final p = detail?.policies;
    if (p?.checkInFrom != null) doc['checkInTime'] = p!.checkInFrom;
    if (p?.checkOutUntil != null) doc['checkOutTime'] = p!.checkOutUntil;

    final facilities = detail?.facilities ?? const <HotelFacility>[];
    if (facilities.isNotEmpty) {
      doc['facilities'] = [for (final f in facilities) facility(f)];
    }
    final nearbyPlaces = detail?.nearbyPlaces ?? const <HotelNearbyPlace>[];
    if (nearbyPlaces.isNotEmpty) {
      doc['nearby'] = [for (final n in nearbyPlaces) nearby(n)];
    }
    final policyMap = policies(detail?.policies);
    if (policyMap != null && policyMap.isNotEmpty) doc['policies'] = policyMap;

    final rooms = <String, Object?>{};
    for (final r in detail?.roomTypes ?? const <HotelRoomType>[]) {
      rooms[r.id] = room(r);
      roomCount++;
    }
    final offers = <String, Object?>{};
    for (final o in detail?.roomOffers ?? const <HotelRoomOffer>[]) {
      offers[o.id] = offer(o);
      offerCount++;
    }

    // Reviews. The document id must be the AUTHOR'S UID — that is what makes
    // "one review per person per hotel" enforceable in firestore.rules. The
    // preview data has display names and no accounts, so these are seeded
    // under `seed-*` placeholder ids, exactly as the nature-spot reviews are.
    // Replace or delete them once real accounts exist.
    //
    // `helpfulCount` is NOT exported: it is server-owned, derived from the
    // votes subcollection by a Cloud Function, and on no client allow-list.
    final reviews = <String, Object?>{};
    final list = <NatureReview>[];
    Object? cursor;
    while (true) {
      final page = await reviewService.fetchReviewPage(
        spotId: hotel.id,
        startAfter: cursor,
      );
      list.addAll(page.reviews);
      if (!page.hasMore) break;
      cursor = page.cursor;
    }
    for (final r in list) {
      final uid = 'seed-${r.id}';
      reviews[uid] = {
        'userId': uid,
        'userName': r.userName,
        'avatarUrl': '',
        'rating': r.rating,
        'comment': r.comment,
        'status': 'published',
        if (r.createdAt != null)
          'createdAt': r.createdAt!.toUtc().toIso8601String(),
      };
      reviewCount++;
    }

    out[hotel.id] = {
      'hotel': doc,
      'rooms': rooms,
      'offers': offers,
      'reviews': reviews,
    };
  }

  final file = File('tool/hotels_seed.json');
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(out)}\n',
  );
  stdout.writeln(
    'Wrote ${file.path}: ${PreviewHotelService.hotels.length} hotels, '
    '$roomCount rooms, $offerCount offers, $reviewCount reviews.',
  );
}
