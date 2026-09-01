import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/featured_item.dart';
import 'firebase_bootstrap.dart';

/// Loads the public featured carousel and the nature-place count.
///
/// Guests can read featured content, while writes remain admin-only through
/// the Firestore rules. When Firebase is unavailable in a debug build, the
/// app uses polished bundled content so the main page remains reviewable.
class FeaturedService {
  FeaturedService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const String collection = 'featured';
  static const String natureSpotsCollection = 'nature_spots';
  static const int maxSlides = 8;

  static bool get isPreviewMode => kDebugMode && !FirebaseBootstrap.isReady;

  Future<List<FeaturedItem>> fetchFeatured() async {
    if (isPreviewMode) {
      debugPrint(
        'PREVIEW MODE: serving bundled featured slides. '
        'Seed the "$collection" collection for live content.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return bundledFeatured();
    }
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    final snapshot = await _firestore
        .collection(collection)
        .where('active', isEqualTo: true)
        .orderBy('order')
        .limit(maxSlides)
        .get();

    return snapshot.docs
        .map((doc) => FeaturedItem.fromMap(doc.id, doc.data()))
        .whereType<FeaturedItem>()
        .toList(growable: false);
  }

  Future<int?> fetchNatureSpotCount() async {
    if (isPreviewMode) return bundledNatureSpotCount;
    if (!FirebaseBootstrap.isReady) return null;

    try {
      final result = await _firestore
          .collection(natureSpotsCollection)
          .count()
          .get();
      return result.count;
    } catch (error) {
      debugPrint('Nature-spot count unavailable: $error');
      return null;
    }
  }

  static const int bundledNatureSpotCount = 120;

  static List<FeaturedItem> bundledFeatured() => const [
    FeaturedItem(
      id: 'preview-nature',
      type: FeaturedType.natureSpot,
      referenceId: 'rawanduz-canyon',
      titles: {
        'en': 'Rawanduz Canyon',
        'ku': 'دەربەندی ڕەواندز',
        'ar': 'وادي رواندوز',
      },
      subtitles: {
        'en': 'Erbil  •  Nature escape',
        'ku': 'هەولێر  •  گەشتی سروشتی',
        'ar': 'أربيل  •  رحلة طبيعية',
      },
      imageAsset: 'assets/images/featured-rawanduz.png',
      rating: 4.8,
      order: 1,
    ),
    FeaturedItem(
      id: 'preview-car',
      type: FeaturedType.car,
      referenceId: 'greenwheels-rentals',
      titles: {
        'en': 'GreenWheels Rentals',
        'ku': 'گرینویلز بۆ بەکرێدان',
        'ar': 'غرين ويلز للتأجير',
      },
      subtitles: {
        'en': 'Erbil  •  Car rental',
        'ku': 'هەولێر  •  بەکرێدانی ئۆتۆمبێل',
        'ar': 'أربيل  •  تأجير سيارات',
      },
      imageAsset: 'assets/images/journey-car.png',
      rating: 4.6,
      order: 2,
    ),
    FeaturedItem(
      id: 'preview-flight',
      type: FeaturedType.flight,
      referenceId: 'astra-ebl-ist',
      titles: {
        'en': 'Astra Airlines',
        'ku': 'ئاسترا ئێرلاینز',
        'ar': 'أسترا للطيران',
      },
      subtitles: {
        'en': 'Erbil → Istanbul  •  Flight',
        'ku': 'هەولێر ← ئەستەنبوڵ  •  فڕین',
        'ar': 'أربيل ← إسطنبول  •  رحلة جوية',
      },
      imageAsset: 'assets/images/journey-flight.png',
      rating: 4.5,
      order: 3,
    ),
    FeaturedItem(
      id: 'preview-tour',
      type: FeaturedType.tour,
      referenceId: 'zagros-camp',
      titles: {
        'en': 'Zagros Highland Camp',
        'ku': 'کەمپی بەرزایی زاگرۆس',
        'ar': 'مخيم مرتفعات زاغروس',
      },
      subtitles: {
        'en': '3 days  •  Guided tour',
        'ku': '٣ ڕۆژان  •  گەشتی ڕێبەرایەتیکراو',
        'ar': '٣ أيام  •  جولة بمرشد',
      },
      imageAsset: 'assets/images/journey-tours.png',
      rating: 4.7,
      order: 4,
    ),
  ];
}
