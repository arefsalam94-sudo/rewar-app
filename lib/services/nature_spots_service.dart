import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/nature_spot.dart';
import '../models/nature_detail.dart';
import 'firebase_bootstrap.dart';

/// Reads the `nature_spots` catalog for the Explore Nature screen.
///
/// Catalog data is public read / admin-only write (`firestore.rules`), so a
/// guest who has never signed in sees exactly the same list as a signed-in
/// user. When Firebase is unavailable in a debug build the service serves
/// bundled content instead, so the page stays reviewable — the same preview
/// contract [FeaturedService] uses.
class NatureSpotsService {
  NatureSpotsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const String collection = 'nature_spots';
  static const String reviewsSubcollection = 'reviews';
  static const String votesSubcollection = 'votes';

  /// How many reviews one page of the Reviews & Ratings list holds.
  static const int reviewPageSize = 10;

  /// Comment length accepted by the review composer. Mirrors the same bounds
  /// in `firestore.rules` — the rules are the boundary, this is the fast
  /// feedback (`SECURITY.md` section 7).
  static const int minCommentLength = 3;
  static const int maxCommentLength = 1000;

  /// Slides in the top carousel.
  static const int maxHighlighted = 8;

  /// How much of the catalog one read pulls down.
  ///
  /// Filtering happens in Dart (see [fetchCatalog]), so this is the ceiling on
  /// what the filters can search and what "Show N places" can count. Sized for
  /// a regional guide; revisit the whole approach before the catalog
  /// approaches it.
  static const int catalogFetchLimit = 200;

  static bool get isPreviewMode => kDebugMode && !FirebaseBootstrap.isReady;

  /// The carousel: every spot the admin has flagged as highlighted.
  ///
  /// Needs the `active + highlighted + highlightOrder` composite index
  /// declared in `firestore.indexes.json`.
  Future<List<NatureSpot>> fetchHighlighted() async {
    if (isPreviewMode) {
      debugPrint(
        'PREVIEW MODE: serving bundled nature spots. '
        'Seed the "$collection" collection for live content.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return bundledSpots().where((spot) => spot.highlighted).toList()
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

  /// The active catalog, best-scoring first — **unfiltered**.
  ///
  /// Every filter (quick chips, place types, facilities) is applied in Dart by
  /// [NatureFilters.matches], not in this query. That is a deliberate decision,
  /// not an oversight: Firestore permits **one** array clause per query and the
  /// screen has three independent multi-select groups, and the Customize
  /// screen's "Show N places" button has to be exact and update on every tap.
  /// One read serves the list, the filters and the counter.
  ///
  /// The trade is that the catalog is downloaded up to [catalogFetchLimit].
  /// See `DATA_MODEL.md` for when that stops being the right call.
  Future<List<NatureSpot>> fetchCatalog() async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return bundledSpots();
    }
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    final snapshot = await _firestore
        .collection(collection)
        .where('active', isEqualTo: true)
        .orderBy('reviewScore', descending: true)
        .limit(catalogFetchLimit)
        .get();

    return _mapDocs(snapshot);
  }

  /// The uid of the signed-in author, or null for a guest.
  ///
  /// **This is also the review's document id** (`firestore.rules`), which is
  /// what makes one review per person per place enforceable rather than merely
  /// intended — a client cannot post the same opinion a hundred times and drag
  /// the average with it.
  String? get currentUid {
    if (isPreviewMode) return _previewUid;
    return _auth.currentUser?.uid;
  }

  bool get isSignedIn => currentUid != null;

  /// The stand-in author id used before Firebase exists, so the composer can
  /// be walked in preview mode. Never reaches Firestore.
  static const String _previewUid = 'preview-viewer';

  /// The two newest public comments shown on a detail screen.
  Future<List<NatureReview>> fetchTopReviews(String spotId) async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      return _sortedPreviewReviews(
        spotId,
        ReviewSort.mostRecent,
      ).take(2).toList(growable: false);
    }
    final snapshot = await _firestore
        .collection(collection)
        .doc(spotId)
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

  /// One page of published reviews for the Reviews & Ratings screen.
  ///
  /// Ordering happens **in the query**, not in Dart, because the list is
  /// paginated: sorting a downloaded page would rank the newest ten reviews
  /// and label them the highest rated of all of them. Each [ReviewSort] has
  /// its own composite index in `firestore.indexes.json`.
  ///
  /// Pass the previous page's [NatureReviewPage.cursor] as [startAfter] to
  /// continue; omit it for the first page.
  Future<NatureReviewPage> fetchReviewPage({
    required String spotId,
    ReviewSort sort = ReviewSort.mostRecent,
    Object? startAfter,
  }) async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      final all = _sortedPreviewReviews(spotId, sort);
      final offset = startAfter is int ? startAfter : 0;
      final page = all.skip(offset).take(reviewPageSize).toList();
      final consumed = offset + page.length;
      return NatureReviewPage(
        reviews: page,
        hasMore: consumed < all.length,
        cursor: consumed,
      );
    }
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection(collection)
        .doc(spotId)
        .collection(reviewsSubcollection)
        .where('status', isEqualTo: 'published')
        .orderBy(sort.field, descending: sort.descending);
    if (sort.needsCreatedAtTieBreak) {
      // Without a stable tie-break, two reviews with the same rating can swap
      // places between pages — which shows one twice and hides another.
      query = query.orderBy('createdAt', descending: true);
    }
    if (startAfter is DocumentSnapshot) {
      query = query.startAfterDocument(startAfter);
    }

    // One more than the page, so "is there another page?" is answered without
    // a second query or a count.
    final snapshot = await query.limit(reviewPageSize + 1).get();
    final docs = snapshot.docs;
    final hasMore = docs.length > reviewPageSize;
    final pageDocs = hasMore ? docs.sublist(0, reviewPageSize) : docs;

    final reviews = pageDocs
        .map((doc) => NatureReview.fromMap(doc.id, doc.data()))
        .whereType<NatureReview>()
        .toList(growable: false);

    return NatureReviewPage(
      reviews: reviews,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  /// Re-reads one spot, for the aggregates at the top of the reviews page.
  ///
  /// Called after a review is posted because `reviewScore`, `ratingCount` and
  /// `ratingBreakdown` are written by a Cloud Function, not by the client —
  /// so the new numbers only exist once the trigger has run. Returns null if
  /// the document has gone, rather than throwing at the caller.
  Future<NatureSpot?> fetchSpot(String spotId) async {
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _previewSpot(spotId);
    }
    final doc = await _firestore.collection(collection).doc(spotId).get();
    return NatureSpot.fromMap(doc.id, doc.data());
  }

  /// The signed-in viewer's own review of this place, if they have left one.
  ///
  /// Fetched by known id (the uid), never by query — so it costs one read and
  /// needs no index.
  Future<NatureReview?> fetchViewerReview(String spotId) async {
    final uid = currentUid;
    if (uid == null) return null;
    if (isPreviewMode) {
      return _firstOrNull(
        _sortedPreviewReviews(
          spotId,
          ReviewSort.mostRecent,
        ).where((review) => review.id == uid),
      );
    }
    final doc = await _firestore
        .collection(collection)
        .doc(spotId)
        .collection(reviewsSubcollection)
        .doc(uid)
        .get();
    return NatureReview.fromMap(doc.id, doc.data());
  }

  /// Creates or replaces the viewer's review of [spotId].
  ///
  /// The document id is the uid, so posting twice edits rather than
  /// duplicates. `helpfulCount` is deliberately not sent: it is server-owned
  /// and the rules reject it (a client that could write it would be declaring
  /// its own review the most helpful on the page).
  Future<void> submitReview({
    required String spotId,
    required double rating,
    required String comment,
    required String userName,
    String? avatarUrl,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw StateError('A review needs a signed-in author.');
    }
    final normalized = NatureReview.normalizeRating(rating);
    final text = comment.trim();
    if (text.length < minCommentLength || text.length > maxCommentLength) {
      throw ArgumentError.value(text.length, 'comment', 'length out of range');
    }

    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final existing = _previewReviewsFor(spotId);
      final previous = _firstOrNull(existing.where((r) => r.id == uid));
      existing
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
        .doc(spotId)
        .collection(reviewsSubcollection)
        .doc(uid);

    // `createdAt` is only set on the first write. The rules pin it to the
    // existing value on update, so an author cannot re-date an old review to
    // push it back to the top of "Most recent".
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

  /// Which of [reviewIds] the viewer has already marked helpful.
  ///
  /// Read one document per review, by known id. `list` on `votes` is denied in
  /// the rules on purpose — nobody should be able to enumerate who liked which
  /// review — so this cannot be one query. A page is [reviewPageSize] reviews,
  /// so it is that many small reads, issued together.
  Future<Set<String>> fetchViewerVotes(
    String spotId,
    Iterable<String> reviewIds,
  ) async {
    final uid = currentUid;
    if (uid == null || reviewIds.isEmpty) return <String>{};
    if (isPreviewMode) {
      return _previewVotes
          .where((key) => key.startsWith('$spotId/'))
          .map((key) => key.split('/').last)
          .where(reviewIds.contains)
          .toSet();
    }

    final spot = _firestore.collection(collection).doc(spotId);
    final results = await Future.wait(
      reviewIds.map(
        (reviewId) => spot
            .collection(reviewsSubcollection)
            .doc(reviewId)
            .collection(votesSubcollection)
            .doc(uid)
            .get()
            .then((doc) => doc.exists ? reviewId : null)
            // One unreadable vote must not blank the whole page's hearts.
            .catchError((Object _) => null),
      ),
    );
    return results.whereType<String>().toSet();
  }

  /// Casts or withdraws the viewer's "helpful" vote on a review.
  ///
  /// Writes only `votes/{uid}` — a document that cannot be created twice by
  /// the same person. The visible number comes from `helpfulCount` on the
  /// review, which the `syncReviewHelpfulCount` trigger recomputes.
  Future<void> setHelpful({
    required String spotId,
    required String reviewId,
    required bool helpful,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw StateError('A helpful vote needs a signed-in voter.');
    }
    if (isPreviewMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final key = '$spotId/$reviewId';
      if (helpful) {
        _previewVotes.add(key);
      } else {
        _previewVotes.remove(key);
      }
      _adjustPreviewHelpfulCount(spotId, reviewId, helpful ? 1 : -1);
      return;
    }

    final vote = _firestore
        .collection(collection)
        .doc(spotId)
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

  // --- Preview-mode state -------------------------------------------------
  //
  // Mutable so the composer and the hearts actually do something before a
  // Firebase project exists. Static, so navigating away and back does not
  // discard what was just posted. Never touched in a live build — every
  // caller is behind `isPreviewMode`.

  static final Map<String, List<NatureReview>> _previewReviewStore =
      <String, List<NatureReview>>{};
  static final Set<String> _previewVotes = <String>{};

  /// `Iterable.firstOrNull` without taking a direct dependency on
  /// `package:collection` for three call sites.
  static T? _firstOrNull<T>(Iterable<T> items) {
    for (final item in items) {
      return item;
    }
    return null;
  }

  static List<NatureReview> _previewReviewsFor(String spotId) =>
      _previewReviewStore.putIfAbsent(
        spotId,
        () => List<NatureReview>.of(bundledReviews(spotId)),
      );

  static void _adjustPreviewHelpfulCount(
    String spotId,
    String reviewId,
    int delta,
  ) {
    final reviews = _previewReviewsFor(spotId);
    final index = reviews.indexWhere((review) => review.id == reviewId);
    if (index < 0) return;
    reviews[index] = reviews[index].copyWith(
      helpfulCount: (reviews[index].helpfulCount + delta).clamp(0, 1 << 30),
    );
  }

  /// Preview reviews in the order the requested sort would return them, with
  /// the viewer's own vote state attached.
  static List<NatureReview> _sortedPreviewReviews(
    String spotId,
    ReviewSort sort,
  ) {
    final reviews = _previewReviewsFor(spotId)
        .map(
          (review) => review.copyWith(
            viewerFoundHelpful: _previewVotes.contains('$spotId/${review.id}'),
          ),
        )
        .toList();
    int byNewest(NatureReview a, NatureReview b) {
      final left = a.createdAt;
      final right = b.createdAt;
      if (left == null || right == null) return 0;
      return right.compareTo(left);
    }

    switch (sort) {
      case ReviewSort.mostRecent:
        reviews.sort(byNewest);
      case ReviewSort.highestRated:
        reviews.sort((a, b) {
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : byNewest(a, b);
        });
      case ReviewSort.lowestRated:
        reviews.sort((a, b) {
          final byRating = a.rating.compareTo(b.rating);
          return byRating != 0 ? byRating : byNewest(a, b);
        });
      case ReviewSort.mostHelpful:
        reviews.sort((a, b) {
          final byHelpful = b.helpfulCount.compareTo(a.helpfulCount);
          return byHelpful != 0 ? byHelpful : byNewest(a, b);
        });
    }
    return reviews;
  }

  /// The bundled spot, with its aggregates recomputed from whatever preview
  /// reviews currently exist — so posting a review in preview mode moves the
  /// average and the bars exactly as the Cloud Function would.
  static NatureSpot? _previewSpot(String spotId) {
    final base = _firstOrNull(
      bundledSpots().where((spot) => spot.id == spotId),
    );
    if (base == null) return null;
    final reviews = _previewReviewsFor(spotId);
    if (reviews.isEmpty) return base;

    final counts = <int, int>{};
    var sum = 0.0;
    for (final review in reviews) {
      sum += review.rating;
      final bucket = review.rating.round().clamp(1, 5);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    final mean = sum / reviews.length;
    return NatureSpot(
      id: base.id,
      names: base.names,
      descriptions: base.descriptions,
      locationLabels: base.locationLabels,
      imageUrls: base.imageUrls,
      imageAssets: base.imageAssets,
      latitude: base.latitude,
      longitude: base.longitude,
      reviewScore: (mean * 2 * 10).round() / 10,
      ratingCount: reviews.length,
      ratingBreakdown: RatingBreakdown(counts),
      categories: base.categories,
      placeTypes: base.placeTypes,
      amenities: base.amenities,
      nearbyStays: base.nearbyStays,
      highlighted: base.highlighted,
      highlightOrder: base.highlightOrder,
    );
  }

  /// Discards everything posted in preview mode. Test-only.
  @visibleForTesting
  static void resetPreviewState() {
    _previewReviewStore.clear();
    _previewVotes.clear();
  }

  /// The three example reviews `tool/seed_explore_nature.js` writes for
  /// Rawanduz Canyon, mirrored here so the page is reviewable before Firebase
  /// exists. **Keep the two in sync** — same rule as the bundled spots.
  ///
  /// Ratings are half-star values: 4.5 / 4.0 / 3.5, which the page shows as
  /// 9.0, 8.0 and 7.0 out of 10.
  static List<NatureReview> bundledReviews(String spotId) {
    // Ages are relative to *now*, so "3 hours ago" stays true however long
    // this build sits on a device — the same thing the seed script does with
    // its `hoursAgo` offsets.
    final now = DateTime.now();
    NatureReview review({
      required String uid,
      required String userName,
      required String comment,
      required double rating,
      required int hoursAgo,
      int helpfulCount = 0,
    }) => NatureReview(
      id: uid,
      userId: uid,
      userName: userName,
      comment: comment,
      rating: rating,
      helpfulCount: helpfulCount,
      createdAt: now.subtract(Duration(hours: hoursAgo)),
    );

    switch (spotId) {
      case 'rawanduz-canyon':
        return [
          review(
            uid: 'seed-elena',
            userName: 'Elena P.',
            rating: 4.5,
            hoursAgo: 3,
            helpfulCount: 4,
            comment:
                'The view is absolutely stunning! The sound of the waterfall '
                'is so relaxing. Perfect place to unwind.',
          ),
          review(
            uid: 'seed-hassan',
            userName: 'Hassan S.',
            rating: 4.0,
            hoursAgo: 24,
            helpfulCount: 7,
            comment:
                'Great place for hiking and photography. I visited in the '
                'morning and the lighting was perfect.',
          ),
          review(
            uid: 'seed-priya',
            userName: 'Priya N.',
            rating: 3.5,
            hoursAgo: 96,
            helpfulCount: 3,
            comment:
                'Beautiful waterfall and clean area. There are small stalls '
                'with tea and snacks.',
          ),
        ];
      case 'sami-abdulrahman-park':
        return [
          review(
            uid: 'seed-aland',
            userName: 'Aland K.',
            rating: 4.5,
            hoursAgo: 30,
            helpfulCount: 2,
            comment:
                'Wide open lawns and a proper lake path. Best just before '
                'sunset.',
          ),
          review(
            uid: 'seed-sara',
            userName: 'Sara A.',
            rating: 4.0,
            hoursAgo: 200,
            helpfulCount: 1,
            comment:
                'Clean, safe and easy to park at. Gets busy on Friday '
                'afternoons.',
          ),
        ];
      case 'erbil-citadel':
        return [
          review(
            uid: 'seed-dara',
            userName: 'Dara M.',
            rating: 5.0,
            hoursAgo: 60,
            helpfulCount: 5,
            comment:
                'Standing somewhere people have lived for thousands of years '
                'is worth the trip on its own. Take a guide.',
          ),
          review(
            uid: 'seed-noor',
            userName: 'Noor H.',
            rating: 4.0,
            hoursAgo: 500,
            helpfulCount: 2,
            comment:
                'The museums are small but well kept, and the view over the '
                'bazaar is the best in the city.',
          ),
        ];
      default:
        return const <NatureReview>[];
    }
  }

  static List<NatureSpot> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs
          .map((doc) => NatureSpot.fromMap(doc.id, doc.data()))
          .whereType<NatureSpot>()
          .toList(growable: false);

  /// Bundled stand-ins for preview mode, mirroring the three documents that
  /// `tool/seed_explore_nature.js` writes. **Keep the two in sync** — the same
  /// rule as the bundled Terms text and the bundled featured slides.
  ///
  /// Only Rawanduz Canyon has a bundled photo; the other two fall back to the
  /// brand-coloured placeholder until real images are uploaded to Storage.
  static List<NatureSpot> bundledSpots() => const [
    NatureSpot(
      id: 'rawanduz-canyon',
      names: {
        'en': 'Rawanduz Canyon',
        'ku': 'دەربەندی ڕەواندز',
        'ar': 'وادي راوندوز',
      },
      locationLabels: {
        'en': 'Erbil, Iraq',
        'ku': 'هەولێر، عێراق',
        'ar': 'أربيل، العراق',
      },
      descriptions: {
        'en':
            'Bekhal Waterfall is one of the most famous natural attractions '
            'in the Rawanduz area of Iraqi Kurdistan. Cool spring water '
            'cascades down the rock face all summer long.',
        'ku':
            'ئاوشاری بێخاڵ یەکێکە لە ناودارترین شوێنە سروشتییەکانی ناوچەی '
            'ڕەواندز لە کوردستانی عێراق. ئاوی سارد بە درێژایی هاوین بەسەر '
            'بەردەکاندا دەڕژێت.',
        'ar':
            'شلال بيخال هو أحد أشهر المعالم الطبيعية في منطقة راوندوز بكردستان '
            'العراق. تتدفق مياه الينابيع الباردة على الصخور طوال الصيف.',
      },
      // Repeated temporarily so the detail gallery and its five-position
      // indicator can be reviewed before distinct photos are available.
      imageAssets: [
        'assets/images/featured-rawanduz.png',
        'assets/images/featured-rawanduz.png',
        'assets/images/featured-rawanduz.png',
        'assets/images/featured-rawanduz.png',
        'assets/images/featured-rawanduz.png',
      ],
      latitude: 36.6089,
      longitude: 44.5286,
      // Server-owned since the Reviews & Ratings screen: these are what the
      // `syncNatureReviewAggregates` trigger derives from the three seeded
      // reviews (4.5 + 4.0 + 3.5 → mean 4.0 → 8.0 out of 10). Hand-typing a
      // prettier number here would make preview mode disagree with the
      // reviews printed directly underneath it.
      reviewScore: 8.0,
      ratingCount: 3,
      ratingBreakdown: RatingBreakdown({5: 1, 4: 2}),
      categories: {'hiking', 'sunset_view'},
      placeTypes: {'canyon', 'waterfall', 'river', 'mountain'},
      amenities: {'parking', 'restrooms', 'restaurants', 'lodging_nearby'},
      nearbyStays: [
        NearbyStay(
          id: 'rawanduz-resort',
          names: {
            'en': 'Rawanduz Resort',
            'ku': 'ڕیزۆرتی ڕەواندز',
            'ar': 'منتجع رواندوز',
          },
          imageAsset: 'assets/images/featured-rawanduz.png',
          distanceKm: 3.2,
          reviewScore: 8.8,
        ),
        NearbyStay(
          id: 'bekhal-cabin',
          names: {
            'en': 'Bekhal Cabin',
            'ku': 'کابینی بێخاڵ',
            'ar': 'كوخ بيخال',
          },
          imageAsset: 'assets/images/journey-nature.png',
          distanceKm: 1.4,
          reviewScore: 8.5,
        ),
        NearbyStay(
          id: 'korek-lodge',
          names: {
            'en': 'Korek Mountain Lodge',
            'ku': 'لۆجی چیای کۆڕەک',
            'ar': 'نُزل جبل كورك',
          },
          imageAsset: 'assets/images/Explore nature .jpeg',
          distanceKm: 18.0,
          reviewScore: 9.0,
        ),
      ],
      highlighted: true,
      highlightOrder: 1,
    ),
    NatureSpot(
      id: 'sami-abdulrahman-park',
      names: {
        'en': 'Sami Abdulrahman Park',
        'ku': 'پارکی سامی عەبدولڕەحمان',
        'ar': 'حديقة سامي عبد الرحمن',
      },
      locationLabels: {
        'en': 'Erbil, Iraq',
        'ku': 'هەولێر، عێراق',
        'ar': 'أربيل، العراق',
      },
      descriptions: {
        'en':
            'A beautiful urban park with scenic lakes, walking trails, and '
            'picnic areas perfect for a slow afternoon in the city.',
        'ku':
            'پارکێکی جوانی ناوشار بە دەریاچەی دڵڕفێن و ڕێڕەوی پیاسە و شوێنی '
            'پیکنیک، گونجاو بۆ نیوەڕۆیەکی ئارام لە شاردا.',
        'ar':
            'حديقة حضرية جميلة ببحيرات خلابة ومسارات للمشي وأماكن للنزهات، '
            'مثالية لقضاء عصر هادئ في المدينة.',
      },
      latitude: 36.1901,
      longitude: 43.9930,
      // Derived from the two seeded reviews (4.5 + 4.0 → mean 4.25 → 8.5).
      reviewScore: 8.5,
      ratingCount: 2,
      ratingBreakdown: RatingBreakdown({5: 1, 4: 1}),
      categories: {'hiking', 'sunset_view'},
      placeTypes: {'park', 'lake'},
      amenities: {
        'parking',
        'restrooms',
        'restaurants',
        'cafes',
        'mobile_signal',
        'atm_nearby',
      },
    ),
    NatureSpot(
      id: 'erbil-citadel',
      names: {'en': 'Erbil Citadel', 'ku': 'قەڵای هەولێر', 'ar': 'قلعة أربيل'},
      locationLabels: {
        'en': 'Erbil, Iraq',
        'ku': 'هەولێر، عێراق',
        'ar': 'أربيل، العراق',
      },
      descriptions: {
        'en':
            "A historic citadel and one of the world's oldest continuously "
            'inhabited places, with museums and stunning views over the city.',
        'ku':
            'قەڵایەکی مێژوویی و یەکێک لە کۆنترین شوێنەکانی جیهان کە بەردەوام '
            'نیشتەجێی تێدا بووە، بە مۆزەخانە و دیمەنی سەرنجڕاکێشی شار.',
        'ar':
            'قلعة تاريخية وأحد أقدم الأماكن المأهولة باستمرار في العالم، '
            'تضم متاحف وإطلالات رائعة على المدينة.',
      },
      latitude: 36.1912,
      longitude: 44.0093,
      // Derived from the two seeded reviews (5.0 + 4.0 → mean 4.5 → 9.0).
      reviewScore: 9.0,
      ratingCount: 2,
      ratingBreakdown: RatingBreakdown({5: 1, 4: 1}),
      categories: {'sunset_view'},
      placeTypes: {'museum'},
      amenities: {
        'parking',
        'restrooms',
        'cafes',
        'mobile_signal',
        'lodging_nearby',
        'atm_nearby',
      },
    ),
  ];
}
