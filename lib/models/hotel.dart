import 'package:flutter/foundation.dart';

@immutable
class HotelText {
  const HotelText({required this.en, required this.ku, required this.ar});

  final String en;
  final String ku;
  final String ar;

  String forLanguage(String languageCode) => switch (languageCode) {
    'ku' => ku,
    'ar' => ar,
    _ => en,
  };
}

@immutable
class HotelDestination {
  const HotelDestination({required this.id, required this.name});

  final String id;
  final HotelText name;
}

enum HotelAmenity { pool, bar, restaurant, gym, parking, wifi, beach }

@immutable
class Hotel {
  const Hotel({
    required this.id,
    required this.name,
    required this.city,
    required this.imageAsset,
    required this.starRating,
    required this.reviewScore,
    required this.distanceFromCenterKm,
    required this.pricePerNight,
    required this.currencyCode,
    required this.amenities,
    this.highlighted = false,
    this.address,
    this.latitude,
    this.longitude,
    this.images = const <String>[],
    this.reviewCount = 0,
  }) : assert(starRating >= 0 && starRating <= 5),
       assert(reviewScore >= 0 && reviewScore <= 10),
       assert(distanceFromCenterKm >= 0),
       assert(pricePerNight >= 0),
       assert(reviewCount >= 0);

  final String id;
  final HotelText name;
  final HotelText city;

  /// The single photo the list and carousel cards draw. Kept separate from
  /// [images] so an existing card never depends on a gallery being present.
  final String imageAsset;
  final int starRating;

  /// **0–10**, matching `DESIGN_SYSTEM.md` 13's numeric score badge and the
  /// rest of the app. The reference screenshot's 4.2/5 is not this app's scale.
  final double reviewScore;
  final double distanceFromCenterKm;
  final double pricePerNight;
  final String currencyCode;
  final Set<HotelAmenity> amenities;
  final bool highlighted;

  /// Street-level address under the hotel name. Null until a provider or the
  /// admin panel supplies one; the detail card then falls back to [city].
  final HotelText? address;

  /// Coordinates for the detail page's map card. Both null means the card
  /// draws its unavailable state rather than a map of nowhere.
  final double? latitude;
  final double? longitude;

  /// The detail page's swipeable gallery, in display order. Deliberately a
  /// list of any length — the five entries in preview data are sample data,
  /// not a layout constant.
  final List<String> images;

  /// How many reviews [reviewScore] is an average of. Server-owned once
  /// hotels reach Firestore, exactly like `nature_spots.ratingCount`.
  final int reviewCount;

  /// What the gallery actually pages through: the gallery when there is one,
  /// otherwise the card photo, so a hotel is never a blank carousel.
  List<String> get galleryImages =>
      images.isEmpty ? <String>[imageAsset] : images;

  bool get hasCoordinates => latitude != null && longitude != null;
}

@immutable
class HotelSearchCriteria {
  HotelSearchCriteria({
    this.destination,
    required this.checkIn,
    required this.checkOut,
    this.adults = 2,
    this.children = 0,
    this.rooms = 1,
    this.beds = 1,
    this.amenities = const <HotelAmenity>{},
    this.currencyCode = 'USD',
    this.localeCode = 'en',
  }) : assert(adults >= 1),
       assert(children >= 0),
       assert(rooms >= 1),
       assert(beds >= 1),
       assert(checkOut.isAfter(checkIn));

  final HotelDestination? destination;
  final DateTime checkIn;
  final DateTime checkOut;
  final int adults;
  final int children;
  final int rooms;
  final int beds;
  final Set<HotelAmenity> amenities;
  final String currencyCode;
  final String localeCode;

  /// Nights in the stay — the multiplier every future price total needs.
  int get nights => checkOut.difference(checkIn).inDays;

  HotelSearchCriteria copyWith({
    HotelDestination? destination,
    DateTime? checkIn,
    DateTime? checkOut,
    int? adults,
    int? children,
    int? rooms,
    int? beds,
    Set<HotelAmenity>? amenities,
    String? currencyCode,
    String? localeCode,
  }) => HotelSearchCriteria(
    destination: destination ?? this.destination,
    checkIn: checkIn ?? this.checkIn,
    checkOut: checkOut ?? this.checkOut,
    adults: adults ?? this.adults,
    children: children ?? this.children,
    rooms: rooms ?? this.rooms,
    beds: beds ?? this.beds,
    amenities: Set<HotelAmenity>.unmodifiable(amenities ?? this.amenities),
    currencyCode: currencyCode ?? this.currencyCode,
    localeCode: localeCode ?? this.localeCode,
  );
}
