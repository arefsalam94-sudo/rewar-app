import 'dart:math' as math;

import 'favorite_item.dart';
import 'nature_detail.dart';

/// The filter categories drawn as chips on the Explore Nature screen.
///
/// The stored value is the snake_case [id]; the visible label is localized by
/// the screen, so adding a language never means re-writing Firestore data.
enum NatureCategory {
  hiking('hiking'),
  beach('beach'),
  sunsetView('sunset_view');

  const NatureCategory(this.id);

  /// The value stored inside `nature_spots.categories`.
  final String id;

  static NatureCategory? fromId(Object? id) {
    for (final category in NatureCategory.values) {
      if (category.id == id) return category;
    }
    return null;
  }
}

/// One document from `nature_spots/{id}`.
///
/// Text fields are **locale maps** (`{en, ku, ar}`) rather than plain strings,
/// the same rule `featured` and `legal_documents` already follow: the app runs
/// in three languages and switching language must not cost a second read. A
/// missing locale falls back to English so a card is never blank.
class NatureSpot {
  const NatureSpot({
    required this.id,
    required this.names,
    this.descriptions = const {},
    this.locationLabels = const {},
    this.imageUrls = const [],
    this.imageAssets = const [],
    this.latitude,
    this.longitude,
    this.reviewScore,
    this.ratingCount = 0,
    this.ratingBreakdown = RatingBreakdown.empty,
    this.categories = const {},
    this.placeTypes = const {},
    this.amenities = const {},
    this.nearbyStays = const [],
    this.highlighted = false,
    this.highlightOrder = 0,
  });

  final String id;
  final Map<String, String> names;
  final Map<String, String> descriptions;

  /// The human-readable place line, e.g. "Erbil, Iraq". Separate from
  /// [latitude]/[longitude] because a geopoint cannot be shown to a user and a
  /// label cannot be measured against — the card needs both.
  final Map<String, String> locationLabels;

  /// Firebase Storage download URLs. The first is the card thumbnail; the
  /// carousel shows them all for a highlighted spot.
  final List<String> imageUrls;

  /// Bundled assets used instead of [imageUrls] in preview mode, before any
  /// real photo has been uploaded. Never set on a document read from Firestore.
  final List<String> imageAssets;

  final double? latitude;
  final double? longitude;

  /// 0–10, the Booking.com-style review score drawn in the square pill.
  ///
  /// Null hides the pill rather than drawing a zero — an unrated place is not
  /// a badly rated one, the same rule `featured.rating` follows.
  final double? reviewScore;

  /// How many reviews [reviewScore] averages. A 9.6 from one review is not a
  /// 9.6 from two hundred.
  ///
  /// **Server-owned** since the Reviews & Ratings screen was built: this and
  /// [reviewScore] are recomputed by the `syncNatureReviewAggregates` trigger
  /// whenever a review is written. The admin panel should show them
  /// read-only — a hand-typed average would be overwritten by the next review.
  final int ratingCount;

  /// The 5★→1★ distribution behind [reviewScore], drawn as bars on the
  /// Reviews & Ratings screen. Server-owned, from the same trigger.
  final RatingBreakdown ratingBreakdown;

  /// The quick chips on the list screen — activity tags such as `hiking`.
  final Set<String> categories;

  /// The Customize screen's "Place Type" group: `forest`, `mountain`,
  /// `canyon`, `park`, `lake`, `waterfall`, `river`, `museum`.
  ///
  /// A separate array from [categories] because it answers a different
  /// question: *what the place is*, not *what you do there*. A waterfall you
  /// can hike to is tagged in both.
  final Set<String> placeTypes;

  /// The Customize screen's "Facilities & Amenities" group: `parking`,
  /// `restrooms`, `restaurants`, `cafes`, `mobile_signal`, `lodging_nearby`,
  /// `atm_nearby`.
  final Set<String> amenities;

  /// Curated nearby accommodation discovery cards (maximum three in the UI).
  final List<NearbyStay> nearbyStays;

  /// Whether this spot appears in the screen's top carousel.
  final bool highlighted;

  /// Ascending order within the carousel, chosen by the admin panel.
  final int highlightOrder;

  String name(String languageCode) => _localized(names, languageCode);

  String description(String languageCode) =>
      _localized(descriptions, languageCode);

  String locationLabel(String languageCode) =>
      _localized(locationLabels, languageCode);

  /// Whether the card has any photo to draw at all (live URL or bundled
  /// asset), so the caller can pick a graceful fallback instead of a
  /// broken-image box.
  bool get hasPhoto => imageUrls.isNotEmpty || imageAssets.isNotEmpty;

  /// Every photo for this spot, preferring bundled assets when they exist
  /// (preview mode) so the carousel is reviewable before Storage is populated.
  List<String> get photos => imageAssets.isNotEmpty ? imageAssets : imageUrls;

  /// Whether [photos] holds bundled asset paths rather than network URLs.
  bool get photosAreAssets => imageAssets.isNotEmpty;

  /// Filled stars for a 0–10 [reviewScore], on the approved 5-star row.
  ///
  /// **Derived, never stored.** Storing a star count alongside the score lets
  /// the two disagree (9.5 shown next to two stars); deriving means there is
  /// one number to enter in the admin panel and one source of truth. Rounding
  /// matches the reference screenshots: 8.2 → 4 stars, 8.7 → 4 stars.
  static int starsForScore(double score) =>
      (score / 2).round().clamp(0, 5).toInt();

  /// The same derivation, kept to the **nearest half star** for the surfaces
  /// that draw halves (the Reviews & Ratings header, and every review row).
  ///
  /// [starsForScore] stays as it is: the list card and the detail hero were
  /// approved with whole stars, and quietly changing them here would restyle
  /// two already-built screens as a side effect of adding a third.
  static double halfStarsForScore(double score) =>
      ((score / 2) * 2).round() / 2;

  /// Great-circle distance in metres from ([fromLat], [fromLng]) to this spot,
  /// or null when either end has no coordinates.
  ///
  /// Computed here rather than stored so "from current location" is actually
  /// true. The haversine formula is plenty for a card label — the error against
  /// a proper geodesic is well under a percent at these distances.
  double? distanceMetersFrom(double fromLat, double fromLng) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return null;

    const earthRadiusMeters = 6371000.0;
    double toRadians(double degrees) => degrees * math.pi / 180.0;

    final dLat = toRadians(lat - fromLat);
    final dLng = toRadians(lng - fromLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRadians(fromLat)) *
            math.cos(toRadians(lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _localized(Map<String, String> values, String languageCode) =>
      values[languageCode] ?? values['en'] ?? '';

  /// Builds a spot from a Firestore document, or null when the document is
  /// missing what the card cannot be drawn without (a name).
  ///
  /// Returning null rather than throwing keeps one malformed document from
  /// emptying the whole list — the service skips it and shows the rest, the
  /// same contract [FeaturedItem.fromMap] has.
  static NatureSpot? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;

    final names = _localeMap(data['name']);
    if (names.isEmpty) return null;

    final location = data['location'];
    double? latitude;
    double? longitude;
    // Firestore hands back a GeoPoint; reading `latitude`/`longitude`
    // dynamically avoids importing cloud_firestore into the model layer, so
    // this class stays plain Dart and testable without Firebase.
    if (location != null) {
      try {
        final lat = (location as dynamic).latitude;
        final lng = (location as dynamic).longitude;
        if (lat is num && lng is num) {
          latitude = lat.toDouble();
          longitude = lng.toDouble();
        }
      } on NoSuchMethodError {
        // Not a GeoPoint — leave the coordinates null and hide the distance.
      }
    }

    final score = data['reviewScore'];
    final ratingCount = data['ratingCount'];
    final highlightOrder = data['highlightOrder'];

    return NatureSpot(
      id: id,
      names: names,
      descriptions: _localeMap(data['description']),
      locationLabels: _localeMap(data['locationLabel']),
      imageUrls: _stringList(data['imageUrls']),
      latitude: latitude,
      longitude: longitude,
      reviewScore: score is num ? score.toDouble().clamp(0.0, 10.0) : null,
      ratingCount: ratingCount is num ? ratingCount.toInt() : 0,
      ratingBreakdown: RatingBreakdown.fromMap(data['ratingBreakdown']),
      categories: _stringList(data['categories']).toSet(),
      placeTypes: _stringList(data['placeTypes']).toSet(),
      amenities: _stringList(data['amenities']).toSet(),
      nearbyStays: _nearbyStays(data['nearbyStays']),
      highlighted: data['highlighted'] == true,
      highlightOrder: highlightOrder is num ? highlightOrder.toInt() : 0,
    );
  }

  static Map<String, String> _localeMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (key is String && value is String && value.isNotEmpty) {
        result[key] = value;
      }
    });
    return result;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().where((v) => v.isNotEmpty).toList();
  }

  static List<NearbyStay> _nearbyStays(Object? raw) {
    if (raw is! List) return const [];
    return raw.map(NearbyStay.fromMap).whereType<NearbyStay>().toList();
  }
}

/// What a saved nature spot stores on its `favorites` row.
///
/// Lives here rather than in each screen so the Explore Nature card and the
/// detail page cannot write two different-shaped snapshots for the same
/// place — which is exactly how the old duplicated heart code drifted.
extension NatureSpotFavorite on NatureSpot {
  FavoriteSnapshot get favoriteSnapshot => FavoriteSnapshot(
    titles: names,
    locationLabels: locationLabels,
    // `photos` is the bundled-asset list in preview mode and the Storage URL
    // list otherwise; the Favorites row picks its loader by inspecting the
    // string, so either is valid here.
    imageRef: photos.isEmpty ? null : photos.first,
  );
}
