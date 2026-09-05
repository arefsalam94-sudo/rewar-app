import 'package:flutter/foundation.dart';

import 'tour.dart';

/// Categories supported by the reusable map model. Explore Tours currently
/// supplies [tour]; the remaining values let future catalogs use the same map
/// contract without changing its marker architecture.
enum MapPlaceCategory {
  tour,
  nature,
  hotel,
  restaurant,
  attraction,
  airport,
  carRental,
  camping,
  activity,
}

@immutable
class MapPlace {
  const MapPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.description = '',
    this.image,
    this.address = '',
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final MapPlaceCategory category;
  final String description;
  final String? image;
  final String address;

  static MapPlace? fromTour(Tour tour, String languageCode) {
    final latitude = tour.latitude;
    final longitude = tour.longitude;
    if (latitude == null || longitude == null) return null;

    return MapPlace(
      id: tour.id,
      name: tour.name(languageCode),
      latitude: latitude,
      longitude: longitude,
      category: MapPlaceCategory.tour,
      description: tour.description(languageCode),
      image: tour.photos.isEmpty ? null : tour.photos.first,
      address: tour.locationLabel(languageCode),
    );
  }
}
