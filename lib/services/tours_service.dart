import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/nature_detail.dart';
import '../models/tour.dart';
import '../models/tour_filters.dart';
import 'firebase_bootstrap.dart';

/// Reads the `tours` catalog for the Explore Tours screen.
///
/// Catalog data is public read / admin-only write (`firestore.rules`), so a
/// guest who has never signed in sees exactly the same list as a signed-in
/// user. When Firebase is unavailable in a debug build the service serves
/// bundled content instead, so the page stays reviewable — the same preview
/// contract `NatureSpotsService` and `FeaturedService` use.
class ToursService {
  ToursService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const String collection = 'tours';
  static const String reviewsSubcollection = 'reviews';
  static const String votesSubcollection = 'votes';
  static const int reviewPageSize = 10;
  static const int minCommentLength = 3;
  static const int maxCommentLength = 1000;
  static const String _previewUid = 'preview-viewer';

  String? get currentUid {
    if (isPreviewMode) return _previewUid;
    return _auth.currentUser?.uid;
  }

  /// Whether anyone is signed in, so the screen knows to show the sign-in
  /// prompt instead of attempting a favourite write that the rules will
  /// reject. Guests browse the catalog freely; only saving needs an account.
  bool get isSignedIn {
    if (!FirebaseBootstrap.isReady) return false;
    return _auth.currentUser != null;
  }

  /// Slides in the top carousel.
  static const int maxHighlighted = 8;

  /// How much of the catalog one read pulls down.
  ///
  /// Search and date filtering happen in Dart (see [fetchCatalog]), so this is
  /// the ceiling on what the filters can search. Sized for a regional guide;
  /// revisit the whole approach before the catalog approaches it.
  static const int catalogFetchLimit = 200;

  static bool get isPreviewMode => kDebugMode && !FirebaseBootstrap.isReady;

  /// The carousel: every tour the admin has flagged as highlighted.
  ///
  /// Needs the `active + highlighted + highlightOrder` composite index
  /// declared in `firestore.indexes.json`.
  Future<List<Tour>> fetchHighlighted() async {
    if (isPreviewMode) {
      debugPrint(
        'PREVIEW MODE: serving bundled tours. '
        'Seed the "$collection" collection for live content.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return bundledTours().where((tour) => tour.highlighted).toList()
        ..sort((a, b) => a.highlightOrder.compareTo(b.highlightOrder));
    }
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    final snapshot = await _firestore
        .collection(collection)
        .where('active', isEqualTo: true)
        .where('highlighted', isEqualTo: true)
        .orderBy('highlightOrder')
        .limit(maxHighlighted)
        .get();

    return _mapDocs(snapshot);
  }

  /// The active catalog, soonest departure first — **unsearched, unfiltered**.
  ///
  /// The search box and the date picker are both applied in Dart, not in this
  /// query, and that is a deliberate decision rather than an oversight:
  ///
  /// * **Firestore has no substring search.** "waterfall" cannot be matched
  ///   against a name field by any query this database supports; that needs a
  ///   search service (Algolia/Typesense) or a tokenized keyword array. Until
  ///   the catalog is big enough to justify one, matching in memory is both
  ///   correct and free.
  /// * The name is a **locale map**, so a server-side search would have to
  ///   pick one language and would fail the other two.
  /// * One read then serves the carousel, the list, the search and the date
  ///   filter, and changing a filter costs nothing.
  ///
  /// The trade is that the catalog is downloaded up to [catalogFetchLimit].
  /// See `DATA_MODEL.md` for when that stops being the right call.
  Future<List<Tour>> fetchCatalog() async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return bundledTours();
    }
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    final snapshot = await _firestore
        .collection(collection)
        .where('active', isEqualTo: true)
        .orderBy('startAt')
        .limit(catalogFetchLimit)
        .get();

    return _mapDocs(snapshot);
  }

  /// Orders the "Trending Tours" section: flagged tours first, in their
  /// `trendingOrder`, then everything else in the query's departure order.
  ///
  /// Grouped in Dart rather than in the query because a second `orderBy` on
  /// `trending` would need another composite index for a list that is already
  /// fully in memory.
  ///
  /// The implementation lives on [TourFilters] because that is where the rest
  /// of the ordering now lives — this stays as the name the rest of the app
  /// already calls.
  static List<Tour> sortForTrending(List<Tour> tours) =>
      TourFilters.trendingFirst(tours);

  static List<Tour> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap
      .docs
      .map((doc) => Tour.fromMap(doc.id, doc.data()))
      .whereType<Tour>()
      .toList(growable: false);

  Future<List<NatureReview>> fetchTopReviews(String tourId) async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return _sortedPreviewReviews(
        tourId,
        ReviewSort.mostRecent,
      ).take(2).toList(growable: false);
    }
    final snapshot = await _firestore
        .collection(collection)
        .doc(tourId)
        .collection(reviewsSubcollection)
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(2)
        .get();
    return snapshot.docs
        .map((doc) => NatureReview.fromMap(doc.id, doc.data()))
        .whereType<NatureReview>()
        .toList(growable: false);
  }

  Future<NatureReviewPage> fetchReviewPage({
    required String tourId,
    ReviewSort sort = ReviewSort.mostRecent,
    Object? startAfter,
  }) async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final all = _sortedPreviewReviews(tourId, sort);
      final offset = startAfter is int ? startAfter : 0;
      final page = all.skip(offset).take(reviewPageSize).toList();
      final consumed = offset + page.length;
      return NatureReviewPage(
        reviews: page,
        hasMore: consumed < all.length,
        cursor: consumed,
      );
    }
    Query<Map<String, dynamic>> query = _firestore
        .collection(collection)
        .doc(tourId)
        .collection(reviewsSubcollection)
        .where('status', isEqualTo: 'published')
        .orderBy(sort.field, descending: sort.descending);
    if (sort.needsCreatedAtTieBreak) {
      query = query.orderBy('createdAt', descending: true);
    }
    if (startAfter is DocumentSnapshot) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(reviewPageSize + 1).get();
    final docs = snapshot.docs;
    final hasMore = docs.length > reviewPageSize;
    final pageDocs = hasMore ? docs.sublist(0, reviewPageSize) : docs;
    return NatureReviewPage(
      reviews: pageDocs
          .map((doc) => NatureReview.fromMap(doc.id, doc.data()))
          .whereType<NatureReview>()
          .toList(growable: false),
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  Future<Tour?> fetchTour(String tourId) async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final base = _firstOrNull(bundledTours().where((t) => t.id == tourId));
      if (base == null) return null;
      return _tourWithPreviewAggregates(base);
    }
    final doc = await _firestore.collection(collection).doc(tourId).get();
    return Tour.fromMap(doc.id, doc.data());
  }

  Future<NatureReview?> fetchViewerReview(String tourId) async {
    final uid = currentUid;
    if (uid == null) return null;
    if (isPreviewMode) {
      return _firstOrNull(
        _sortedPreviewReviews(
          tourId,
          ReviewSort.mostRecent,
        ).where((review) => review.id == uid),
      );
    }
    final doc = await _firestore
        .collection(collection)
        .doc(tourId)
        .collection(reviewsSubcollection)
        .doc(uid)
        .get();
    return NatureReview.fromMap(doc.id, doc.data());
  }

  Future<void> submitReview({
    required String tourId,
    required double rating,
    required String comment,
    required String userName,
    String? avatarUrl,
  }) async {
    final uid = currentUid;
    if (uid == null) throw StateError('A review needs a signed-in author.');
    final normalized = NatureReview.normalizeRating(rating);
    final text = comment.trim();
    if (text.length < minCommentLength || text.length > maxCommentLength) {
      throw ArgumentError.value(text.length, 'comment', 'length out of range');
    }
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
      final reviews = _previewReviewsFor(tourId);
      final previous = _firstOrNull(reviews.where((r) => r.id == uid));
      reviews
        ..removeWhere((review) => review.id == uid)
        ..add(
          NatureReview(
            id: uid,
            userId: uid,
            userName: userName,
            comment: text,
            rating: normalized,
            avatarUrl: avatarUrl,
            createdAt: previous?.createdAt ?? DateTime.now(),
            helpfulCount: previous?.helpfulCount ?? 0,
          ),
        );
      return;
    }
    final doc = _firestore
        .collection(collection)
        .doc(tourId)
        .collection(reviewsSubcollection)
        .doc(uid);
    final existing = await doc.get();
    final Object createdAt = existing.exists
        ? (existing.data()?['createdAt'] as Object? ??
              FieldValue.serverTimestamp())
        : FieldValue.serverTimestamp();
    await doc.set({
      'userId': uid,
      'userName': userName,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      'rating': normalized,
      'comment': text,
      'status': 'published',
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Set<String>> fetchViewerVotes(
    String tourId,
    Iterable<String> reviewIds,
  ) async {
    final uid = currentUid;
    if (uid == null || reviewIds.isEmpty) return <String>{};
    if (isPreviewMode) {
      return _previewVotes
          .where((key) => key.startsWith('$tourId/'))
          .map((key) => key.split('/').last)
          .where(reviewIds.contains)
          .toSet();
    }
    final tour = _firestore.collection(collection).doc(tourId);
    final results = await Future.wait(
      reviewIds.map(
        (reviewId) => tour
            .collection(reviewsSubcollection)
            .doc(reviewId)
            .collection(votesSubcollection)
            .doc(uid)
            .get()
            .then((doc) => doc.exists ? reviewId : null)
            .catchError((Object _) => null),
      ),
    );
    return results.whereType<String>().toSet();
  }

  Future<void> setHelpful({
    required String tourId,
    required String reviewId,
    required bool helpful,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw StateError('A helpful vote needs a signed-in voter.');
    }
    if (isPreviewMode) {
      final key = '$tourId/$reviewId';
      helpful ? _previewVotes.add(key) : _previewVotes.remove(key);
      final reviews = _previewReviewsFor(tourId);
      final index = reviews.indexWhere((review) => review.id == reviewId);
      if (index >= 0) {
        reviews[index] = reviews[index].copyWith(
          helpfulCount: (reviews[index].helpfulCount + (helpful ? 1 : -1))
              .clamp(0, 1 << 30),
        );
      }
      return;
    }
    final vote = _firestore
        .collection(collection)
        .doc(tourId)
        .collection(reviewsSubcollection)
        .doc(reviewId)
        .collection(votesSubcollection)
        .doc(uid);
    if (helpful) {
      await vote.set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await vote.delete();
    }
  }

  static final Map<String, List<NatureReview>> _previewReviewStore = {};
  static final Set<String> _previewVotes = <String>{};

  @visibleForTesting
  static void resetPreviewReviewState() {
    _previewReviewStore.clear();
    _previewVotes.clear();
  }

  static List<NatureReview> _previewReviewsFor(String tourId) =>
      _previewReviewStore.putIfAbsent(tourId, () => _seedReviews(tourId));

  static List<NatureReview> _sortedPreviewReviews(
    String tourId,
    ReviewSort sort,
  ) {
    final reviews = _previewReviewsFor(tourId)
        .map(
          (review) => review.copyWith(
            viewerFoundHelpful: _previewVotes.contains('$tourId/${review.id}'),
          ),
        )
        .toList();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    int newest(NatureReview a, NatureReview b) =>
        (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch);
    switch (sort) {
      case ReviewSort.mostRecent:
        reviews.sort(newest);
      case ReviewSort.highestRated:
        reviews.sort((a, b) {
          final rating = b.rating.compareTo(a.rating);
          return rating == 0 ? newest(a, b) : rating;
        });
      case ReviewSort.lowestRated:
        reviews.sort((a, b) {
          final rating = a.rating.compareTo(b.rating);
          return rating == 0 ? newest(a, b) : rating;
        });
      case ReviewSort.mostHelpful:
        reviews.sort((a, b) {
          final helpful = b.helpfulCount.compareTo(a.helpfulCount);
          return helpful == 0 ? newest(a, b) : helpful;
        });
    }
    return reviews;
  }

  static List<NatureReview> _seedReviews(String tourId) {
    final now = DateTime.now();
    NatureReview review(
      String id,
      String name,
      double rating,
      String comment,
      int hoursAgo,
    ) => NatureReview(
      id: id,
      userId: id,
      userName: name,
      rating: rating,
      comment: comment,
      createdAt: now.subtract(Duration(hours: hoursAgo)),
    );
    if (tourId == 'gali-alibag-waterfall') {
      return [
        review(
          'seed-hemin',
          'Hemin R.',
          4.5,
          'The guide knew every path and the swimming stop was the best part.',
          40,
        ),
        review(
          'seed-lana',
          'Lana T.',
          4.5,
          'Two days was exactly right. The food and campsite were excellent.',
          190,
        ),
        review(
          'seed-omar',
          'Omar F.',
          4.0,
          'Beautiful trip and very well organised.',
          400,
        ),
      ];
    }
    if (tourId == 'gali-sherana') {
      return [
        review(
          'seed-shilan',
          'Shilan A.',
          4.5,
          'The riverside campfire made the whole day worth it.',
          70,
        ),
        review(
          'seed-karwan',
          'Karwan B.',
          4.0,
          'Relaxed pace and a friendly guide.',
          260,
        ),
      ];
    }
    return [];
  }

  static Tour _tourWithPreviewAggregates(Tour tour) {
    final reviews = _previewReviewsFor(tour.id);
    if (reviews.isEmpty) return tour;
    var sum = 0.0;
    final breakdown = <int, int>{};
    for (final review in reviews) {
      sum += review.rating;
      final bucket = review.rating.round().clamp(1, 5);
      breakdown[bucket] = (breakdown[bucket] ?? 0) + 1;
    }
    return Tour(
      id: tour.id,
      names: tour.names,
      descriptions: tour.descriptions,
      locationLabels: tour.locationLabels,
      companyTag: tour.companyTag,
      durationDays: tour.durationDays,
      features: tour.features,
      imageUrls: tour.imageUrls,
      imageAssets: tour.imageAssets,
      latitude: tour.latitude,
      longitude: tour.longitude,
      pricePerPerson: tour.pricePerPerson,
      currency: tour.currency,
      startAt: tour.startAt,
      endAt: tour.endAt,
      reviewScore: ((sum / reviews.length) * 20).round() / 10,
      ratingCount: reviews.length,
      ratingBreakdown: RatingBreakdown(breakdown),
      capacity: tour.capacity,
      bookedCount: tour.bookedCount,
      cancellationPolicy: tour.cancellationPolicy,
      guideLanguages: tour.guideLanguages,
      transportAvailable: tour.transportAvailable,
      transportPricePerPerson: tour.transportPricePerPerson,
      trending: tour.trending,
      trendingOrder: tour.trendingOrder,
      highlighted: tour.highlighted,
      highlightOrder: tour.highlightOrder,
    );
  }

  static T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  /// Bundled stand-ins for preview mode, mirroring the documents that
  /// `tool/seed_explore_tours.js` writes. **Keep the two in sync** — the same
  /// rule as the bundled nature spots, the bundled Terms text and the bundled
  /// featured slides.
  ///
  /// Only Gali Alibag has a bundled photo; the others fall back to the
  /// brand-coloured placeholder until real images are uploaded to Storage.
  ///
  /// The dates are **relative to now**, not fixed calendar dates, so preview
  /// mode never shows a screen full of tours that departed last year.
  static List<Tour> bundledTours() {
    final today = DateTime.now();
    DateTime inDays(int days) =>
        DateTime(today.year, today.month, today.day + days);

    return [
      Tour(
        id: 'gali-alibag-waterfall',
        names: {
          'en': 'Gali Alibag Waterfall',
          'ku': 'ئاوشاری گەلی عەلی بەگ',
          'ar': 'شلال كلي علي بك',
        },
        locationLabels: {
          'en': 'Rawanduz, Erbil',
          'ku': 'ڕەواندز، هەولێر',
          'ar': 'راوندوز، أربيل',
        },
        descriptions: {
          'en':
              'A popular scenic waterfall destination with cool water, picnic '
              'spots, and beautiful mountain views.',
          'ku':
              'شوێنێکی ناودار و دڵڕفێنی ئاوشار بە ئاوی سارد و شوێنی پیکنیک و '
              'دیمەنی جوانی چیاکان.',
          'ar':
              'وجهة شلالات خلابة ومشهورة بمياهها الباردة وأماكن النزهات '
              'وإطلالات جبلية جميلة.',
        },
        companyTag: 'AB group',
        durationDays: 2,
        features: {'guide', 'activity', 'wifi', 'food', 'electricity'},
        imageAssets: ['assets/images/featured-rawanduz.png'],
        latitude: 36.6289,
        longitude: 44.5311,
        pricePerPerson: 55,
        startAt: inDays(4),
        endAt: inDays(6),
        // Server-owned: what `syncTourReviewAggregates` would derive from the
        // reviews `tool/seed_explore_tours.js` writes (4.5 + 4.5 + 4.0 → mean
        // 4.33 → 8.7 of 10). Hand-typing a prettier number here would make
        // preview mode disagree with the trigger.
        reviewScore: 8.7,
        ratingCount: 3,
        ratingBreakdown: RatingBreakdown({5: 2, 4: 1}),
        capacity: 24,
        bookedCount: 21,
        cancellationPolicy: TourCancellationPolicy.free48h,
        guideLanguages: {'en', 'ku', 'ar'},
        transportAvailable: true,
        transportPricePerPerson: 5,
        trending: true,
        trendingOrder: 1,
        highlighted: true,
        highlightOrder: 1,
      ),
      Tour(
        id: 'gali-sherana',
        names: {'en': 'Gali Sherana', 'ku': 'گەلی شێرانە', 'ar': 'كلي شيرانة'},
        locationLabels: {
          'en': 'Duhok Province',
          'ku': 'پارێزگای دهۆک',
          'ar': 'محافظة دهوك',
        },
        descriptions: {
          'en':
              'A relaxing nature escape known for peaceful scenery, fresh air, '
              'and a great riverside camp experience.',
          'ku':
              'پاشەکشەیەکی ئارامی سروشت کە بە دیمەنی هێمن و هەوای پاک و '
              'ئەزموونی خۆشی خێوەتگە لەسەر ڕووبار ناسراوە.',
          'ar':
              'ملاذ طبيعي مريح يشتهر بمناظره الهادئة وهوائه النقي وتجربة '
              'تخييم رائعة على ضفة النهر.',
        },
        companyTag: 'Ava group',
        durationDays: 1,
        features: {'campfire', 'tent', 'wifi', 'swimming'},
        latitude: 37.0469,
        longitude: 43.0892,
        pricePerPerson: 32,
        startAt: inDays(11),
        endAt: inDays(12),
        // Derived from the two seeded reviews (4.0 + 4.5 → mean 4.25 → 8.5).
        reviewScore: 8.5,
        ratingCount: 2,
        ratingBreakdown: RatingBreakdown({5: 1, 4: 1}),
        capacity: 16,
        bookedCount: 4,
        cancellationPolicy: TourCancellationPolicy.free24h,
        guideLanguages: {'ku', 'ar'},
        transportAvailable: true,
        transportPricePerPerson: 4,
        trending: true,
        trendingOrder: 2,
      ),
      Tour(
        id: 'korek-mountain-day',
        names: {
          'en': 'Korek Mountain Day Trip',
          'ku': 'گەشتی ڕۆژانەی چیای کۆڕەک',
          'ar': 'رحلة يوم إلى جبل كورك',
        },
        locationLabels: {
          'en': 'Rawanduz, Erbil',
          'ku': 'ڕەواندز، هەولێر',
          'ar': 'راوندوز، أربيل',
        },
        descriptions: {
          'en':
              'Cable car to the summit, alpine air and a long lunch above the '
              'clouds, with a guide for the ridge walk.',
          'ku':
              'تەلەفریک بۆ لوتکە، هەوای چیایی و نانی نیوەڕۆی درێژ لەسەرووی '
              'هەورەکانەوە، لەگەڵ ڕێبەرێک بۆ پیاسەی شاخ.',
          'ar':
              'تلفريك إلى القمة وهواء جبلي وغداء طويل فوق الغيوم، مع مرشد '
              'لجولة المشي على الحافة.',
        },
        companyTag: 'Zagros Trips',
        durationDays: 1,
        features: {'guide', 'food', 'transport', 'photography', 'activity'},
        latitude: 36.6520,
        longitude: 44.4400,
        pricePerPerson: 40,
        startAt: inDays(18),
        endAt: inDays(18),
        // No reviews seeded, so no score — an unrated tour hides the badge
        // rather than drawing a zero, and this is the case that proves it.
        capacity: 30,
        bookedCount: 28,
        cancellationPolicy: TourCancellationPolicy.nonRefundable,
        guideLanguages: {'en', 'tr'},
        transportAvailable: false,
        highlighted: true,
        highlightOrder: 2,
      ),
    ];
  }
}
