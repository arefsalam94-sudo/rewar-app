import '../models/nature_detail.dart';
import '../models/nature_spot.dart';
import 'nature_spots_service.dart';

/// Serves hotel reviews to the shared Reviews & Ratings experience.
///
/// Hotels are not on Firestore yet (`PreviewHotelService`), so there is no
/// `hotels/{id}/reviews` subcollection to read. This holds the preview
/// reviews in memory instead, and implements the same
/// [NatureSpotsService] surface the screen already talks to — which means the
/// day hotels become live, only this class is replaced, not the screen.
///
/// State is **static** on purpose: a review written on the detail sheet has to
/// still be there when the full reviews page is opened a moment later. It is
/// process-lifetime only and reaches no database.
class PreviewHotelReviewService extends NatureSpotsService {
  PreviewHotelReviewService({this.subject});

  /// The hotel the Reviews & Ratings screen is showing, as the neutral
  /// subject that screen understands. Supplied only by that screen, so it can
  /// be handed back with recomputed aggregates after a review is posted; the
  /// detail card fetches two reviews and needs no subject at all.
  final NatureSpot? subject;

  /// The stand-in author id, mirroring the one preview nature reviews use, so
  /// the composer's "you already reviewed this" branch can be walked.
  static const String previewUid = 'preview-viewer';

  static final Map<String, List<NatureReview>> _reviews =
      <String, List<NatureReview>>{
        'preview-divan-erbil': <NatureReview>[
          NatureReview(
            id: 'preview-hotel-review-1',
            userName: 'Aland Karim',
            comment:
                'Excellent stay. The view over the city at night is the '
                'reason to book here, and the staff could not have been '
                'more helpful.',
            rating: 5,
            createdAt: DateTime(2026, 8, 9),
            helpfulCount: 14,
          ),
          NatureReview(
            id: 'preview-hotel-review-2',
            userName: 'Sara Ahmed',
            comment:
                'Beautiful rooms and a very good breakfast. The pool was '
                'busy in the afternoon, but everything else was perfect.',
            rating: 4,
            createdAt: DateTime(2026, 8, 4),
            helpfulCount: 6,
          ),
          NatureReview(
            id: 'preview-hotel-review-3',
            userName: 'Dilan Mustafa',
            comment: 'Clean, quiet and close to everything we wanted to see.',
            rating: 4.5,
            createdAt: DateTime(2026, 7, 28),
            helpfulCount: 2,
          ),
        ],
        'preview-ramada-sulaimani': <NatureReview>[
          NatureReview(
            id: 'preview-hotel-review-4',
            userName: 'Hemin Rashid',
            comment:
                'Good value for the location. Parking was easy, which is '
                'rare downtown.',
            rating: 4,
            createdAt: DateTime(2026, 8, 1),
            helpfulCount: 3,
          ),
        ],
      };

  /// Per-hotel set of review ids the preview viewer has marked helpful.
  static final Map<String, Set<String>> _votes = <String, Set<String>>{};

  static List<NatureReview> _forHotel(String hotelId) =>
      _reviews.putIfAbsent(hotelId, () => <NatureReview>[]);

  /// The aggregate the Reviews screen shows at the top.
  ///
  /// Derived here because there is no Cloud Function in preview mode. Once
  /// hotels are live this must come from a server-owned field on the hotel
  /// document, exactly as `nature_spots.reviewScore` does — see
  /// `DATA_MODEL.md`.
  static ({double? score, int count, RatingBreakdown breakdown}) aggregateFor(
    String hotelId,
  ) {
    final reviews = _forHotel(hotelId);
    if (reviews.isEmpty) {
      return (score: null, count: 0, breakdown: RatingBreakdown.empty);
    }
    final total = reviews.fold<double>(
      0,
      (running, review) => running + review.scoreOutOfTen,
    );
    final counts = <int, int>{};
    for (final review in reviews) {
      final star = review.rating.ceil().clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
    }
    return (
      score: total / reviews.length,
      count: reviews.length,
      breakdown: RatingBreakdown(counts),
    );
  }

  @override
  String? get currentUid => previewUid;

  @override
  bool get isSignedIn => true;

  @override
  Future<List<NatureReview>> fetchTopReviews(String spotId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _sorted(
      spotId,
      ReviewSort.mostRecent,
    ).take(2).toList(growable: false);
  }

  @override
  Future<NatureReviewPage> fetchReviewPage({
    required String spotId,
    ReviewSort sort = ReviewSort.mostRecent,
    Object? startAfter,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final all = _sorted(spotId, sort);
    final offset = startAfter is int ? startAfter : 0;
    final page = all
        .skip(offset)
        .take(NatureSpotsService.reviewPageSize)
        .toList(growable: false);
    final consumed = offset + page.length;
    return NatureReviewPage(
      reviews: page,
      hasMore: consumed < all.length,
      cursor: consumed,
    );
  }

  @override
  Future<NatureReview?> fetchViewerReview(String spotId) async {
    final own = _forHotel(spotId).where((review) => review.id == previewUid);
    return own.isEmpty ? null : own.first;
  }

  @override
  Future<void> submitReview({
    required String spotId,
    required double rating,
    required String comment,
    required String userName,
    String? avatarUrl,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final reviews = _forHotel(spotId)
      ..removeWhere((review) => review.id == previewUid);
    // Keyed by the author's uid, like the live rules require: writing again
    // replaces your review rather than stacking a second one.
    reviews.insert(
      0,
      NatureReview(
        id: previewUid,
        userId: previewUid,
        userName: userName,
        comment: comment,
        rating: NatureReview.normalizeRating(rating),
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Set<String>> fetchViewerVotes(
    String spotId,
    Iterable<String> reviewIds,
  ) async {
    final voted = _votes[spotId] ?? const <String>{};
    return reviewIds.where(voted.contains).toSet();
  }

  @override
  Future<void> setHelpful({
    required String spotId,
    required String reviewId,
    required bool helpful,
  }) async {
    final voted = _votes.putIfAbsent(spotId, () => <String>{});
    if (helpful) {
      voted.add(reviewId);
    } else {
      voted.remove(reviewId);
    }
    final reviews = _forHotel(spotId);
    final index = reviews.indexWhere((review) => review.id == reviewId);
    if (index == -1) return;
    final review = reviews[index];
    reviews[index] = review.copyWith(
      helpfulCount: (review.helpfulCount + (helpful ? 1 : -1)).clamp(
        0,
        1 << 30,
      ),
      viewerFoundHelpful: helpful,
    );
  }

  /// The screen re-reads the subject after a post to pick up the refreshed
  /// aggregates, which a Cloud Function would have written. In preview there
  /// is no trigger, so they are recomputed from the in-memory reviews here —
  /// and only here, never inside a widget.
  @override
  Future<NatureSpot?> fetchSpot(String spotId) async {
    final base = subject;
    if (base == null || base.id != spotId) return null;
    final aggregate = aggregateFor(spotId);
    return NatureSpot(
      id: base.id,
      names: base.names,
      descriptions: base.descriptions,
      locationLabels: base.locationLabels,
      imageUrls: base.imageUrls,
      imageAssets: base.imageAssets,
      latitude: base.latitude,
      longitude: base.longitude,
      reviewScore: aggregate.score,
      ratingCount: aggregate.count,
      ratingBreakdown: aggregate.breakdown,
    );
  }

  List<NatureReview> _sorted(String spotId, ReviewSort sort) {
    final reviews = <NatureReview>[..._forHotel(spotId)];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    reviews.sort((a, b) {
      final comparison = switch (sort) {
        ReviewSort.mostRecent => (b.createdAt ?? epoch).compareTo(
          a.createdAt ?? epoch,
        ),
        ReviewSort.highestRated => b.rating.compareTo(a.rating),
        ReviewSort.lowestRated => a.rating.compareTo(b.rating),
        ReviewSort.mostHelpful => b.helpfulCount.compareTo(a.helpfulCount),
      };
      if (comparison != 0) return comparison;
      return (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch);
    });
    return reviews;
  }
}
