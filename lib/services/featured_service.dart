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

  /// The slides preview mode serves before Firebase exists.
  ///
  /// **Must stay in sync with `tool/seed_home_screen.js`** — these are the
  /// same three slides, and a divergence means the app shows one front page in
  /// preview and another in production.
  ///
  /// Rewritten 2026-09-15. The previous bundled set carried three slides that
  /// referenced documents which do not exist in any live collection:
  /// `greenwheels-rentals` (no such car or company), `astra-ebl-ist` (the
  /// `flights` collection is empty and flights are release-gated as Coming
  /// Soon), and `zagros-camp` (no such tour — and the live collection had
  /// drifted further still, seeding `moraine-lake`, a lake in Banff, Canada,
  /// as a Kurdistan tour).
  ///
  /// **No slide carries a rating.** The referenced documents have no rating
  /// aggregate — those are server-owned and the Cloud Function that derives
  /// them is not deployed — so a number here would be invented. [FeaturedItem]
  /// treats a null rating as "hide the pill", which is the honest rendering.
  ///
  /// Three slides, not four: there are only three live documents whose content
  /// genuinely matches a carousel card. The carousel sizes itself to whatever
  /// it is given rather than assuming four.
  static List<FeaturedItem> bundledFeatured() => const [
    FeaturedItem(
      id: 'preview-nature',
      type: FeaturedType.natureSpot,
      referenceId: 'rawanduz-canyon',
      titles: {
        'en': 'Rawanduz Canyon',
        'ku': 'دەربەندی ڕەواندز',
        'ar': 'وادي راوندوز',
      },
      subtitles: {
        'en': 'Erbil  •  Nature escape',
        'ku': 'هەولێر  •  گەشتی سروشتی',
        'ar': 'أربيل  •  رحلة طبيعية',
      },
      imageAsset: 'assets/images/featured-rawanduz.png',
      order: 1,
    ),
    FeaturedItem(
      id: 'preview-tour-gali-alibag',
      type: FeaturedType.tour,
      referenceId: 'gali-alibag-waterfall',
      titles: {
        'en': 'Gali Alibag Waterfall',
        'ku': 'ئاوشاری گەلی عەلی بەگ',
        'ar': 'شلال كلي علي بك',
      },
      subtitles: {
        'en': 'Rawanduz, Erbil  •  Guided tour',
        'ku': 'ڕەواندز، هەولێر  •  گەشتی ڕێبەرایەتیکراو',
        'ar': 'راوندوز، أربيل  •  جولة بمرشد',
      },
      imageAsset: 'assets/images/journey-tours.png',
      order: 2,
    ),
    FeaturedItem(
      id: 'preview-tour-korek',
      type: FeaturedType.tour,
      referenceId: 'korek-mountain-day',
      titles: {
        'en': 'Korek Mountain Day Trip',
        'ku': 'گەشتی ڕۆژانەی چیای کۆڕەک',
        'ar': 'رحلة يوم إلى جبل كورك',
      },
      subtitles: {
        'en': 'Rawanduz, Erbil  •  Guided tour',
        'ku': 'ڕەواندز، هەولێر  •  گەشتی ڕێبەرایەتیکراو',
        'ar': 'راوندوز، أربيل  •  جولة بمرشد',
      },
      imageAsset: 'assets/images/journey-tours.png',
      order: 3,
    ),
  ];
}
