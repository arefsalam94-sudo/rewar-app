import 'dart:math' as math;

import 'nature_detail.dart';
import 'nature_spot.dart';

/// How late a booking can be cancelled, as a **tier** rather than free text.
///
/// The wording of each tier lives in `legal_documents/cancellation_refunds`
/// (the Policy hub's "Cancellation & Refunds" document) — the card shows only
/// which tier applies. Typing the sentence onto each tour would let a hundred
/// operator-entered paragraphs drift away from the policy the app actually
/// enforces, which is exactly the failure `DATA_MODEL.md` warns about for
/// `help_topics`.
enum TourCancellationPolicy {
  free24h('free_24h'),
  free48h('free_48h'),
  free7d('free_7d'),
  nonRefundable('non_refundable');

  const TourCancellationPolicy(this.id);

  /// The value stored in `tours.cancellationPolicy`.
  final String id;

  /// Whether this tier can be cancelled at all — drives the icon and colour.
  bool get isFree => this != TourCancellationPolicy.nonRefundable;

  static TourCancellationPolicy? fromId(Object? id) {
    for (final policy in TourCancellationPolicy.values) {
      if (policy.id == id) return policy;
    }
    return null;
  }
}

/// A language the guide speaks, stored as its ISO 639-1 code.
///
/// A closed set rather than free text so the filter chips and the card label
/// can be localized. The first three are the app's own languages; the rest are
/// the ones a Kurdistan operator realistically offers.
enum TourGuideLanguage {
  english('en'),
  kurdish('ku'),
  arabic('ar'),
  turkish('tr'),
  persian('fa');

  const TourGuideLanguage(this.code);

  /// The value stored inside `tours.guideLanguages`.
  final String code;

  static TourGuideLanguage? fromCode(Object? code) {
    for (final language in TourGuideLanguage.values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// What a tour includes — the stroke-only circled icons drawn on every card.
///
/// The stored value is the snake_case [id]; the visible label is localized by
/// the screen, so adding a language never means rewriting Firestore data. Same
/// contract as `NatureCategory` on `nature_spots.categories`.
enum TourFeature {
  camping('camping'),
  hiking('hiking'),
  guide('guide'),
  food('food'),
  swimming('swimming'),
  campfire('campfire'),
  transport('transport'),
  photography('photography'),
  // Added with the Explore Tours reference rebuild: the approved card
  // screenshot tags departures with Activity, Wifi, Electricity and Tent.
  // An id with no enum value here is silently dropped by `knownFeatures`,
  // so the icons could not be drawn until the ids existed.
  activity('activity'),
  wifi('wifi'),
  electricity('electricity'),
  tent('tent');

  const TourFeature(this.id);

  /// The value stored inside `tours.features`.
  final String id;

  static TourFeature? fromId(Object? id) {
    for (final feature in TourFeature.values) {
      if (feature.id == id) return feature;
    }
    return null;
  }
}

/// One document from `tours/{id}`.
///
/// Text fields are **locale maps** (`{en, ku, ar}`) rather than plain strings,
/// the same rule `nature_spots`, `featured` and `legal_documents` already
/// follow: the app runs in three languages and switching language must not
/// cost a second read. A missing locale falls back to English so a card is
/// never blank.
class Tour {
  const Tour({
    required this.id,
    required this.names,
    this.descriptions = const {},
    this.locationLabels = const {},
    this.companyTag = '',
    this.durationDays = 1,
    this.features = const {},
    this.imageUrls = const [],
    this.imageAssets = const [],
    this.latitude,
    this.longitude,
    this.pricePerPerson,
    this.currency = 'USD',
    this.startAt,
    this.endAt,
    this.reviewScore,
    this.ratingCount = 0,
    this.ratingBreakdown = RatingBreakdown.empty,
    this.capacity,
    this.bookedCount = 0,
    this.minAge,
    this.cancellationPolicy,
    this.guideLanguages = const {},
    this.transportAvailable = false,
    this.transportPricePerPerson,
    this.trending = false,
    this.trendingOrder = 0,
    this.highlighted = false,
    this.highlightOrder = 0,
  });

  final String id;
  final Map<String, String> names;
  final Map<String, String> descriptions;

  /// The human-readable place line, e.g. "Rawanduz, Erbil". Separate from
  /// [latitude]/[longitude] because a geopoint cannot be shown to a user and a
  /// label cannot be measured against — the card needs both.
  final Map<String, String> locationLabels;

  /// The operator badge in the card's top corner, e.g. "AB group".
  ///
  /// **Not** a locale map: it is a company's own name, and translating a brand
  /// is wrong in the same way translating "Booking.com" would be.
  final String companyTag;

  /// Whole days, so the screen can say "2 Days travel" in three languages from
  /// one number. Storing the rendered string instead would mean the Kurdish
  /// and Arabic cards read English.
  final int durationDays;

  /// What the tour includes — [TourFeature] ids.
  final Set<String> features;

  /// Firebase Storage download URLs. The first is the card thumbnail; the
  /// carousel shows them all for a highlighted tour.
  final List<String> imageUrls;

  /// Bundled assets used instead of [imageUrls] in preview mode, before any
  /// real photo has been uploaded. Never set on a document read from Firestore.
  final List<String> imageAssets;

  final double? latitude;
  final double? longitude;

  /// Price for one traveller, in [currency]. Null hides the price box rather
  /// than drawing a zero — a tour whose price is not set yet is not free.
  final num? pricePerPerson;

  /// ISO code the price is quoted in (`USD` / `IQD` / `EUR`), matching
  /// `AppCurrency`. Shown as given; **nothing here converts currencies**, and
  /// inventing a rate would be worse than showing the operator's own price.
  final String currency;

  /// Departure and return. Both optional: a tour whose dates are not published
  /// yet hides the date line instead of showing a placeholder.
  final DateTime? startAt;
  final DateTime? endAt;

  /// 0–10, the Booking.com-style review score drawn in the square badge.
  ///
  /// Null hides the badge rather than drawing a zero — an unrated tour is not
  /// a badly rated one, the same rule `NatureSpot.reviewScore` follows.
  ///
  /// **Server-owned**: this, [ratingCount] and [ratingBreakdown] are
  /// recomputed by the `syncTourReviewAggregates` trigger whenever a review is
  /// written. The admin panel must show all three read-only — a hand-typed
  /// average is overwritten by the next review posted.
  final double? reviewScore;

  /// How many reviews [reviewScore] averages. An 8.7 from one review is not an
  /// 8.7 from two hundred, which is precisely why both are drawn. Server-owned.
  final int ratingCount;

  /// The 5★→1★ distribution behind [reviewScore]. Server-owned, same trigger.
  /// Not drawn on the list card; it is what a Tour Reviews screen would use.
  final RatingBreakdown ratingBreakdown;

  /// How many travellers the departure can take, and how many are already
  /// booked. Null [capacity] means the operator has not published one, and
  /// availability is simply not shown rather than guessed at.
  ///
  /// [bookedCount] is **server-owned** — it must be maintained by the checkout
  /// Cloud Function, never by a client. A client that could write it could
  /// mark a rival's departure full, or clear the count and oversell it.
  final int? capacity;
  final int bookedCount;

  /// The operator's minimum traveller age in years, or null when the departure
  /// carries no age restriction.
  ///
  /// Checked against every entered date of birth on the Traveler Info screen.
  /// Null is "no restriction", never "0" — an absent field must not read as a
  /// rule that happens to pass.
  final int? minAge;

  /// Which cancellation tier applies. Null hides the line rather than implying
  /// a policy the operator never agreed to.
  final TourCancellationPolicy? cancellationPolicy;

  /// ISO 639-1 codes of the languages the guide speaks
  /// ([TourGuideLanguage.code]).
  final Set<String> guideLanguages;

  /// Whether this departure offers an optional bus add-on.
  ///
  /// The price is kept on the tour document because it is operator-controlled
  /// payment-adjacent catalog data. It is never accepted from a checkout form.
  final bool transportAvailable;

  /// Optional bus price for one traveller, quoted in [currency].
  /// Null means the operator has not published a transport price yet.
  final num? transportPricePerPerson;

  /// Whether this tour belongs in the "Trending Tours" section, and in what
  /// order. Applied in Dart over the one catalog read — see `ToursService`.
  final bool trending;
  final int trendingOrder;

  /// Whether this tour appears in the screen's top carousel.
  final bool highlighted;
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

  /// Every photo for this tour, preferring bundled assets when they exist
  /// (preview mode) so the carousel is reviewable before Storage is populated.
  List<String> get photos => imageAssets.isNotEmpty ? imageAssets : imageUrls;

  /// Whether [photos] holds bundled asset paths rather than network URLs.
  bool get photosAreAssets => imageAssets.isNotEmpty;

  /// The tour's features in a stable, declaration order, ignoring any id the
  /// app does not know about.
  ///
  /// Unknown ids are dropped rather than drawn as a blank circle: the admin
  /// panel can add a tag before the app ships an icon for it, and a card with
  /// a nameless icon on it is worse than a card with one fewer.
  List<TourFeature> get knownFeatures => TourFeature.values
      .where((feature) => features.contains(feature.id))
      .toList(growable: false);

  /// The guide's languages in a stable order, ignoring any unknown code — the
  /// same contract as [knownFeatures].
  List<TourGuideLanguage> get knownGuideLanguages => TourGuideLanguage.values
      .where((language) => guideLanguages.contains(language.code))
      .toList(growable: false);

  /// Filled stars for [reviewScore], on the approved 5-star row.
  ///
  /// Delegates to `NatureSpot.starsForScore` rather than repeating the
  /// arithmetic, so the two catalogs can never round a score differently.
  static int starsForScore(double score) => NatureSpot.starsForScore(score);

  /// Places still bookable, or null when the operator published no [capacity]
  /// — in which case the card shows no availability line at all rather than
  /// inventing one.
  ///
  /// Clamped at zero: an over-booked departure is sold out, not negative.
  int? get spotsLeft {
    final total = capacity;
    if (total == null) return null;
    final left = total - bookedCount;
    return left < 0 ? 0 : left;
  }

  bool get isSoldOut => spotsLeft == 0;

  /// Whether the remaining places are worth calling out. Both reference
  /// products only nudge when the number is genuinely small; a "48 spots left"
  /// badge is noise, and printing it on every card teaches people to ignore it.
  bool get isLowAvailability {
    final left = spotsLeft;
    return left != null && left > 0 && left <= lowAvailabilityThreshold;
  }

  static const int lowAvailabilityThreshold = 5;

  /// What [travelers] people pay, with the optional bus add-on when [transport].
  ///
  /// Null when the operator published no [pricePerPerson] — the UI then prints
  /// a dash rather than a zero, because "free" and "not priced yet" are not the
  /// same claim.
  ///
  /// Lives on the model so the Tour Detail estimate and the checkout summary
  /// cannot drift into showing two different totals for one booking.
  num? totalFor({required int travelers, required bool transport}) {
    final base = pricePerPerson;
    if (base == null) return null;
    final bus = transport ? (transportPricePerPerson ?? 0) : 0;
    return (base + bus) * travelers;
  }

  /// Whether this tour can still take [travellers] people.
  ///
  /// A tour with no published capacity is assumed bookable — the alternative
  /// is hiding a perfectly good tour because its operator left a field blank.
  bool hasRoomFor(int travellers) {
    final left = spotsLeft;
    return left == null || left >= travellers;
  }

  /// Whether this tour matches the free-text search box.
  ///
  /// Matches the **name and the location line in every language**, not just
  /// the one on screen: someone browsing in Kurdish may well type a place name
  /// the way they have seen it written in English.
  bool matchesQuery(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    for (final value in [...names.values, ...locationLabels.values]) {
      if (value.toLowerCase().contains(needle)) return true;
    }
    return companyTag.toLowerCase().contains(needle);
  }

  /// Whether this tour's run overlaps the closed range [from]–[to], comparing
  /// calendar days only.
  ///
  /// **Overlap, not containment.** Someone searching 14–20 August wants the
  /// three-day trip that starts on the 19th, not only the trips that fit
  /// entirely inside their window. A null [to] means a single day.
  bool runsBetween(DateTime from, DateTime? to) {
    final start = startAt;
    if (start == null) return false;
    DateTime day(DateTime value) =>
        DateTime(value.year, value.month, value.day);

    final windowStart = day(from);
    final windowEnd = day(to ?? from);
    final tourStart = day(start);
    final tourEnd = day(endAt ?? start);
    return !tourStart.isAfter(windowEnd) && !tourEnd.isBefore(windowStart);
  }

  /// Whether [day] falls inside this tour's run, comparing calendar days only.
  ///
  /// A tour is "on" a date the whole way through, not only on its departure
  /// day — someone picking the middle of their holiday should still find the
  /// trip that is running then. A tour with no [startAt] never matches a date
  /// filter, because there is nothing to compare against.
  bool runsOn(DateTime day) {
    final start = startAt;
    if (start == null) return false;
    final target = DateTime(day.year, day.month, day.day);
    final first = DateTime(start.year, start.month, start.day);
    final rawEnd = endAt ?? start;
    final last = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
    return !target.isBefore(first) && !target.isAfter(last);
  }

  /// Great-circle distance in metres from ([fromLat], [fromLng]) to this
  /// tour's meeting point, or null when either end has no coordinates.
  ///
  /// Computed here rather than stored so "from current location" is actually
  /// true — the same rule `NatureSpot` follows.
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

  /// Builds a tour from a Firestore document, or null when the document is
  /// missing what the card cannot be drawn without (a name).
  ///
  /// Returning null rather than throwing keeps one malformed document from
  /// emptying the whole list — the service skips it and shows the rest, the
  /// same contract `NatureSpot.fromMap` has.
  static Tour? fromMap(String id, Map<String, dynamic>? data) {
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

    final companyTag = data['companyTag'];
    final durationDays = data['durationDays'];
    final price = data['pricePerPerson'];
    final currency = data['currency'];
    final trendingOrder = data['trendingOrder'];
    final highlightOrder = data['highlightOrder'];
    final score = data['reviewScore'];
    final ratingCount = data['ratingCount'];
    final capacity = data['capacity'];
    final minAge = data['minAge'];
    final bookedCount = data['bookedCount'];
    final transportPrice = data['transportPricePerPerson'];

    return Tour(
      id: id,
      names: names,
      descriptions: _localeMap(data['description']),
      locationLabels: _localeMap(data['locationLabel']),
      companyTag: companyTag is String ? companyTag : '',
      durationDays: durationDays is num
          ? durationDays.toInt().clamp(1, 365)
          : 1,
      features: _stringList(data['features']).toSet(),
      imageUrls: _stringList(data['imageUrls']),
      latitude: latitude,
      longitude: longitude,
      pricePerPerson: price is num && price >= 0 ? price : null,
      currency: currency is String && currency.isNotEmpty ? currency : 'USD',
      startAt: _dateTime(data['startAt']),
      endAt: _dateTime(data['endAt']),
      reviewScore: score is num ? score.toDouble().clamp(0.0, 10.0) : null,
      ratingCount: ratingCount is num ? ratingCount.toInt() : 0,
      ratingBreakdown: RatingBreakdown.fromMap(data['ratingBreakdown']),
      capacity: capacity is num && capacity >= 0 ? capacity.toInt() : null,
      bookedCount: bookedCount is num && bookedCount >= 0
          ? bookedCount.toInt()
          : 0,
      minAge: minAge is num && minAge > 0 ? minAge.toInt() : null,
      cancellationPolicy: TourCancellationPolicy.fromId(
        data['cancellationPolicy'],
      ),
      guideLanguages: _stringList(data['guideLanguages']).toSet(),
      transportAvailable: data['transportAvailable'] == true,
      transportPricePerPerson: transportPrice is num && transportPrice >= 0
          ? transportPrice
          : null,
      trending: data['trending'] == true,
      trendingOrder: trendingOrder is num ? trendingOrder.toInt() : 0,
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

  /// Accepts a Firestore `Timestamp` (via its `toDate()`), a `DateTime`, or an
  /// ISO-8601 string — the last so the bundled preview fixtures and the seed
  /// script can share one shape without importing `cloud_firestore`. Same
  /// helper `Booking` uses.
  static DateTime? _dateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    try {
      final converted = (raw as dynamic).toDate();
      return converted is DateTime ? converted : null;
    } catch (_) {
      return null;
    }
  }
}
