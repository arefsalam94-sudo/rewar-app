import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/nature_detail.dart';
import '../models/nature_spot.dart';
import 'firebase_bootstrap.dart';
import 'hotel_reviews_service.dart';
import 'nature_spots_service.dart';

/// Guest reviews for a hotel, read from `hotels/{hotelId}/reviews`.
///
/// The Hotel Details page and the full reviews page are the **shared**
/// Reviews & Ratings screens, which are typed against [NatureSpotsService].
/// This subclass keeps that contract and redirects every review query at the
/// hotel collection root instead — `ToursService` solves the same problem by
/// duplicating the class, which is why the rules for all three review
/// subcollections are identical (DATA_MODEL.md).
///
/// Falls back to [PreviewHotelReviewService] whenever Firebase is unavailable
/// or a live read fails, for the same reason the catalogue does: a stale
/// review list is better than an error page.
class FirestoreHotelReviewsService extends NatureSpotsService {
  FirestoreHotelReviewsService({
    required this.subject,
    super.firestore,
    super.auth,
    PreviewHotelReviewService? fallback,
  }) : _firestoreOverride = firestore,
       _fallback = fallback ?? PreviewHotelReviewService(subject: subject);

  /// The hotel rendered as a [NatureSpot], so the shared screen can draw its
  /// header without knowing it is looking at a hotel.
  final NatureSpot subject;

  final FirebaseFirestore? _firestoreOverride;
  final PreviewHotelReviewService _fallback;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static const String hotelsCollection = 'hotels';

  bool get _live => FirebaseBootstrap.isReady || _firestoreOverride != null;

  CollectionReference<Map<String, dynamic>> _reviews(String hotelId) => _db
      .collection(hotelsCollection)
      .doc(hotelId)
      .collection(NatureSpotsService.reviewsSubcollection);

  @override
  Future<NatureSpot?> fetchSpot(String spotId) async => subject;

  @override
  Future<List<NatureReview>> fetchTopReviews(String spotId) async {
    if (!_live) return _fallback.fetchTopReviews(spotId);
    try {
      final snapshot = await _reviews(spotId)
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(2)
          .get();
      return snapshot.docs
          .map((doc) => NatureReview.fromMap(doc.id, doc.data()))
          .whereType<NatureReview>()
          .toList(growable: false);
    } catch (error) {
      debugPrint('Could not load reviews for \$spotId: \$error');
      return _fallback.fetchTopReviews(spotId);
    }
  }

  @override
  Future<NatureReviewPage> fetchReviewPage({
    required String spotId,
    ReviewSort sort = ReviewSort.mostRecent,
    Object? startAfter,
  }) async {
    if (!_live) {
      return _fallback.fetchReviewPage(
        spotId: spotId,
        sort: sort,
        startAfter: startAfter,
      );
    }
    try {
      Query<Map<String, dynamic>> query = _reviews(spotId)
          .where('status', isEqualTo: 'published')
          .orderBy(sort.field, descending: sort.descending);
      if (sort.needsCreatedAtTieBreak) {
        // Without a stable tie-break two reviews with the same rating can swap
        // places between pages, showing one twice and hiding another.
        query = query.orderBy('createdAt', descending: true);
      }
      if (startAfter is DocumentSnapshot) {
        query = query.startAfterDocument(startAfter);
      }

      // One more than the page, so "is there another page?" costs no extra
      // query and no count.
      final snapshot = await query
          .limit(NatureSpotsService.reviewPageSize + 1)
          .get();
      final docs = snapshot.docs;
      final hasMore = docs.length > NatureSpotsService.reviewPageSize;
      final page = hasMore
          ? docs.take(NatureSpotsService.reviewPageSize).toList()
          : docs;

      return NatureReviewPage(
        reviews: page
            .map((doc) => NatureReview.fromMap(doc.id, doc.data()))
            .whereType<NatureReview>()
            .toList(growable: false),
        hasMore: hasMore,
        cursor: page.isEmpty ? null : page.last,
      );
    } catch (error) {
      debugPrint('Could not page reviews for $spotId: $error');
      return _fallback.fetchReviewPage(
        spotId: spotId,
        sort: sort,
        startAfter: startAfter,
      );
    }
  }

  @override
  Future<NatureReview?> fetchViewerReview(String spotId) async {
    final uid = currentUid;
    if (uid == null) return null;
    if (!_live) return _fallback.fetchViewerReview(spotId);
    try {
      // The document id IS the author's uid, so the viewer's own review is a
      // single get by known id rather than a query.
      final doc = await _reviews(spotId).doc(uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return NatureReview.fromMap(doc.id, data);
    } catch (error) {
      debugPrint('Could not load the viewer review for $spotId: $error');
      return _fallback.fetchViewerReview(spotId);
    }
  }

  @override
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
    if (!_live) {
      return _fallback.submitReview(
        spotId: spotId,
        rating: rating,
        comment: comment,
        userName: userName,
        avatarUrl: avatarUrl,
      );
    }

    final normalized = NatureReview.normalizeRating(rating);
    final text = comment.trim();
    if (text.length < NatureSpotsService.minCommentLength ||
        text.length > NatureSpotsService.maxCommentLength) {
      throw ArgumentError.value(text.length, 'comment', 'length out of range');
    }

    final ref = _reviews(spotId).doc(uid);
    final existing = await ref.get();
    // `createdAt` is pinned by the rules on update, so an edit must not resend
    // it — an author cannot re-date an old review to the top of Most recent.
    // `helpfulCount` is server-owned and is on no client allow-list.
    final payload = <String, Object?>{
      'userId': uid,
      'userName': userName,
      'avatarUrl': avatarUrl ?? '',
      'rating': normalized,
      'comment': text,
      'status': 'published',
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(payload, SetOptions(merge: true));
  }

  @override
  Future<Set<String>> fetchViewerVotes(
    String spotId,
    Iterable<String> reviewIds,
  ) async {
    final uid = currentUid;
    if (uid == null || reviewIds.isEmpty) return <String>{};
    if (!_live) return _fallback.fetchViewerVotes(spotId, reviewIds);
    try {
      // `list` on votes is denied by the rules — nobody may enumerate who
      // liked a review — so the viewer's own vote is fetched by known id.
      final votes = <String>{};
      for (final reviewId in reviewIds) {
        final doc = await _reviews(spotId)
            .doc(reviewId)
            .collection(NatureSpotsService.votesSubcollection)
            .doc(uid)
            .get();
        if (doc.exists) votes.add(reviewId);
      }
      return votes;
    } catch (error) {
      debugPrint('Could not load votes for $spotId: $error');
      return _fallback.fetchViewerVotes(spotId, reviewIds);
    }
  }

  @override
  Future<void> setHelpful({
    required String spotId,
    required String reviewId,
    required bool helpful,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw StateError('A helpful vote needs a signed-in voter.');
    }
    if (!_live) {
      return _fallback.setHelpful(
        spotId: spotId,
        reviewId: reviewId,
        helpful: helpful,
      );
    }

    // A vote is a DOCUMENT keyed by the voter, not an incrementable counter:
    // a document cannot be created twice by the same person, whereas an
    // increment can be sent in a loop. `helpfulCount` on the review is derived
    // from these by a trigger.
    final ref = _reviews(
      spotId,
    ).doc(reviewId).collection(NatureSpotsService.votesSubcollection).doc(uid);
    if (helpful) {
      await ref.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }
}
