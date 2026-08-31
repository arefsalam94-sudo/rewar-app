import 'package:flutter/material.dart';

import '../models/hotel.dart';
import '../models/nature_spot.dart';
import '../services/hotel_reviews_service.dart';
import '../services/nature_spots_service.dart';
import '../services/user_profile_service.dart';
import 'nature_reviews_screen.dart';

/// Hotel entry point for the shared Reviews & Ratings experience.
///
/// The same deliberate arrangement Explore Tours uses: the interaction is
/// identical to Explore Nature — sorting, paging, helpful votes, half-star
/// composer — while the injected service points every read and write at hotel
/// reviews instead. One review UI, no second comment system.
class HotelReviewsScreen extends StatelessWidget {
  const HotelReviewsScreen({
    super.key,
    required this.hotel,
    this.reviewService,
    this.userProfileService,
  });

  final Hotel hotel;
  final NatureSpotsService? reviewService;
  final UserProfileService? userProfileService;

  /// The photograph behind the hotel flow, kept for its reviews page too.
  static const String backgroundAsset = 'assets/images/hotel background.webp';

  @override
  Widget build(BuildContext context) {
    final subject = hotelAsNatureSpot(hotel);
    return NatureReviewsScreen(
      spot: subject,
      natureSpotsService:
          reviewService ?? PreviewHotelReviewService(subject: subject),
      userProfileService: userProfileService,
      backgroundFallbackAsset: backgroundAsset,
      // The hotel's own photograph belongs to the detail page's gallery; this
      // page keeps the flow background, exactly as the tours reviews page does.
      useSubjectPhotoForBackground: false,
    );
  }
}

/// Presents a [Hotel] as the neutral subject the shared reviews screen reads.
///
/// The score and count come from the preview review store rather than from
/// [Hotel.reviewScore], so the header cannot disagree with the list beneath
/// it. Once hotels are live, both come from server-owned fields on the hotel
/// document instead.
NatureSpot hotelAsNatureSpot(Hotel hotel) {
  final aggregate = PreviewHotelReviewService.aggregateFor(hotel.id);
  return NatureSpot(
    id: hotel.id,
    names: <String, String>{
      'en': hotel.name.en,
      'ku': hotel.name.ku,
      'ar': hotel.name.ar,
    },
    locationLabels: <String, String>{
      'en': hotel.address?.en ?? hotel.city.en,
      'ku': hotel.address?.ku ?? hotel.city.ku,
      'ar': hotel.address?.ar ?? hotel.city.ar,
    },
    imageAssets: hotel.galleryImages,
    latitude: hotel.latitude,
    longitude: hotel.longitude,
    reviewScore: aggregate.score,
    ratingCount: aggregate.count,
    ratingBreakdown: aggregate.breakdown,
  );
}
