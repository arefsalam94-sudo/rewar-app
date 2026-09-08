import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/favorite_item.dart';
import '../models/featured_item.dart';
import 'firebase_bootstrap.dart';

/// Reads and toggles the signed-in user's `favorites`.
///
/// Guests are not handled here at all — the caller prompts them to sign in
/// instead. That is deliberate: `favorites` documents are keyed by `userId`
/// and the security rule requires `request.auth.uid` to match, so there is no
/// such thing as an anonymous favorite.
///
/// Only two things can be favorited — a stay and a nature spot
/// ([FavoriteCategory]). The heart used to appear on the Home carousel and on
/// tour cards as well; it was consolidated onto Where to Stay and Explore
/// Nature so "saved" means one thing in one place, and the rules were
/// narrowed to the same two types.
class FavoritesService {
  FavoritesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const String collection = 'favorites';

  /// Cap on how many of the user's favorites are pulled in one read.
  ///
  /// One query serves the whole Favorites screen — both sections and both
  /// "View all" screens are filtered from this single list in Dart, exactly
  /// as My Bookings filters its segments and chips. That is cheaper than a
  /// composite index per (`userId`, `itemType`) combination, and it is what
  /// makes the denormalized snapshot on each row worth carrying.
  static const int fetchLimit = 200;

  /// How many rows each section previews before "View all".
  static const int sectionPreviewCount = 4;

  static bool get isPreviewMode => kDebugMode && !FirebaseBootstrap.isReady;

  String? get _uid {
    if (!FirebaseBootstrap.isReady) return null;
    return _auth.currentUser?.uid;
  }

  /// Whether there is a signed-in user who can own favorites at all.
  ///
  /// The screens use this to choose between the list and the shared
  /// `SignInRequired` gate, rather than showing a guest an empty list that
  /// looks like "you have saved nothing".
  bool get hasViewer => _uid != null;

  /// A deterministic id, so favoriting is a plain set/delete on a known
  /// document rather than a query-then-write. That also makes a double-tap
  /// idempotent instead of creating two rows for the same place.
  static String documentId({
    required String uid,
    required FeaturedType itemType,
    required String itemId,
  }) => '${uid}_${itemType.id}_$itemId';

  /// The ids (`itemId`) the current user has already favorited.
  ///
  /// Pass [category] to get just that section's ids — a hotel and a nature
  /// spot could in principle carry the same document id, so a screen drawing
  /// hearts must never match on a bare `itemId` across both types. Filtered
  /// in Dart from the one read above rather than server-side, which would
  /// need a composite index for no benefit at this size.
  ///
  /// Returns an empty set for guests and in preview mode — nothing is stored
  /// in either case, so nothing can be already-favorited.
  Future<Set<String>> fetchFavoriteItemIds({FavoriteCategory? category}) async {
    if (isPreviewMode) return <String>{};
    final uid = _uid;
    if (uid == null) return <String>{};

    final snapshot = await _firestore
        .collection(collection)
        .where('userId', isEqualTo: uid)
        .limit(fetchLimit)
        .get();

    return snapshot.docs
        .where(
          (doc) => category == null || doc.data()['itemType'] == category.id,
        )
        .map((doc) => doc.data()['itemId'])
        .whereType<String>()
        .toSet();
  }

  /// Every favorite the user has saved, newest first.
  ///
  /// Ordering is done in Dart for the same reason the type filter is: adding
  /// `orderBy('createdAt')` to the `where('userId')` query would require a
  /// composite index, and the list is already capped at [fetchLimit]. Rows
  /// that fail to parse — a legacy `car`/`tour`/`flight` favorite, or a
  /// document written before the snapshot fields existed — are skipped
  /// rather than allowed to empty the screen.
  Future<List<FavoriteItem>> fetchFavorites() async {
    if (isPreviewMode) return const <FavoriteItem>[];
    final uid = _uid;
    if (uid == null) return const <FavoriteItem>[];

    final snapshot = await _firestore
        .collection(collection)
        .where('userId', isEqualTo: uid)
        .limit(fetchLimit)
        .get();

    final items = snapshot.docs
        .map((doc) => FavoriteItem.fromMap(doc.id, doc.data()))
        .whereType<FavoriteItem>()
        .toList();

    // Newest first. A row whose server timestamp has not resolved yet reads
    // back with a null `createdAt`; it was just written, so it sorts first
    // rather than last.
    items.sort((a, b) {
      final left = a.createdAt;
      final right = b.createdAt;
      if (left == null && right == null) return 0;
      if (left == null) return -1;
      if (right == null) return 1;
      return right.compareTo(left);
    });
    return items;
  }

  /// Adds or removes a favorite. Returns the new state (true = favorited).
  ///
  /// [snapshot] is the denormalized copy the Favorites screen draws its row
  /// from — see [FavoriteSnapshot] for why it is stored rather than resolved.
  /// It is required on the way in even when the call turns out to be a
  /// removal, because the caller always has it and making it optional would
  /// invite a row that saves with no name.
  ///
  /// Throws [StateError] if called with no signed-in user — the caller is
  /// expected to have shown the sign-in prompt already.
  Future<bool> toggle({
    required FavoriteCategory category,
    required String itemId,
    required bool currentlyFavorite,
    required FavoriteSnapshot snapshot,
  }) async {
    if (isPreviewMode) {
      debugPrint(
        'PREVIEW MODE: favorite not persisted. '
        'Finish FIREBASE_SETUP.md for the real write.',
      );
      return !currentlyFavorite;
    }

    final uid = _uid;
    if (uid == null) {
      throw StateError('Cannot change favorites without a signed-in user');
    }

    final document = _firestore
        .collection(collection)
        .doc(documentId(uid: uid, itemType: category.type, itemId: itemId));

    if (currentlyFavorite) {
      await document.delete();
      return false;
    }

    await document.set({
      'userId': uid,
      'itemType': category.id,
      'itemId': itemId,
      ...snapshot.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'manual',
    });
    return true;
  }

  /// Removes a favorite the Favorites screen is already holding.
  ///
  /// Separate from [toggle] because the screen has the whole [FavoriteItem]
  /// and no snapshot to write — requiring it to reconstruct one just to
  /// delete a row would be busywork.
  Future<void> remove(FavoriteItem item) async {
    if (isPreviewMode) {
      debugPrint('PREVIEW MODE: favorite not removed.');
      return;
    }
    final uid = _uid;
    if (uid == null) {
      throw StateError('Cannot change favorites without a signed-in user');
    }
    await _firestore.collection(collection).doc(item.id).delete();
  }

  /// Re-adds a row the user has just removed, for the undo action on the
  /// Favorites screen's snackbar.
  ///
  /// `createdAt` is rewritten rather than restored, so an undone removal
  /// reappears at the top of the list instead of silently changing position.
  Future<void> restore(FavoriteItem item) async {
    if (isPreviewMode) return;
    final uid = _uid;
    if (uid == null) {
      throw StateError('Cannot change favorites without a signed-in user');
    }
    await _firestore.collection(collection).doc(item.id).set({
      'userId': uid,
      'itemType': item.category.id,
      'itemId': item.itemId,
      // Same omit-when-empty rule as [FavoriteSnapshot.toMap] — an empty
      // locale map is rejected by `validShape`.
      'title': item.titles,
      if (item.locationLabels.isNotEmpty) 'locationLabel': item.locationLabels,
      if (item.imageRef != null) 'imageRef': item.imageRef,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'manual',
    });
  }
}
