import 'featured_item.dart';

/// The two things this app lets a user save.
///
/// `favorites.itemType` can technically still hold `car`, `tour` or `flight`
/// from before the heart was consolidated, so this enum is deliberately
/// *narrower* than [FeaturedType]: a row whose type is not one of these two
/// is skipped by the Favorites screen rather than drawn in a section that
/// does not exist. The rules were narrowed to match, so no new row of another
/// type can be created — see `firestore.rules` → `favorites`.
enum FavoriteCategory {
  /// "Where to stay" — a hotel.
  stay(FeaturedType.hotel),

  /// "Explore Nature" — a nature spot.
  nature(FeaturedType.natureSpot);

  const FavoriteCategory(this.type);

  /// The [FeaturedType] this category is stored as, so the document id and
  /// the `itemType` field keep the exact shape `DATA_MODEL.md` documents.
  final FeaturedType type;

  /// The string written to `favorites.itemType`.
  String get id => type.id;

  static FavoriteCategory? fromId(Object? id) {
    for (final category in FavoriteCategory.values) {
      if (category.id == id) return category;
    }
    return null;
  }
}

/// The denormalized copy of a place, written onto the favorite row at the
/// moment the heart is tapped.
///
/// Without this the Favorites screen would have to read one document per
/// saved item just to draw a name and a thumbnail — 24 reads to open a tab.
/// Booking.com and Agoda both denormalize their saved lists for the same
/// reason. The trade is that a place renamed after it was saved keeps its old
/// name in the list until it is re-favorited; the detail screen the arrow
/// opens always re-reads the live document, so the stale copy never travels
/// past the row itself.
class FavoriteSnapshot {
  const FavoriteSnapshot({
    required this.titles,
    required this.locationLabels,
    this.imageRef,
  });

  /// Locale map (`{en, ku, ar}`), the same shape `featured.title` uses — the
  /// app runs in three languages and switching one must not require a write.
  final Map<String, String> titles;

  /// Locale map of the human-readable place line, e.g. "Rawanduz, Kurdistan".
  final Map<String, String> locationLabels;

  /// The row thumbnail: either a Firebase Storage `https://` download URL or
  /// a bundled `assets/...` path.
  ///
  /// One field rather than two because the caller knows which it has and the
  /// row only ever draws one of them. Hotels supply an asset path today —
  /// `hotels` is not seeded and Where to Stay reads `PreviewHotelService`
  /// (`SEED_DATA.md`) — while nature spots supply whichever they carry.
  final String? imageRef;

  /// Only non-empty entries are written. The rules require `title` to be a
  /// valid locale map and reject an empty one, so a place with no location
  /// line omits the field entirely rather than sending `{}` and having the
  /// whole save denied — the row then draws without that line.
  Map<String, Object?> toMap() => {
    'title': titles,
    if (locationLabels.isNotEmpty) 'locationLabel': locationLabels,
    if (imageRef != null && imageRef!.isNotEmpty) 'imageRef': imageRef,
  };
}

/// One row of the Favorites screen, from `favorites/{id}`.
class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.category,
    required this.itemId,
    required this.titles,
    required this.locationLabels,
    this.imageRef,
    this.createdAt,
  });

  /// The favorite document's own id (`{uid}_{itemType}_{itemId}`).
  final String id;

  final FavoriteCategory category;

  /// Id of the document in the category's own collection — what the arrow
  /// re-reads to open the detail screen.
  final String itemId;

  final Map<String, String> titles;
  final Map<String, String> locationLabels;

  /// See [FavoriteSnapshot.imageRef].
  final String? imageRef;

  /// Newest first is the order the screen lists in. Null while the server
  /// timestamp is still resolving on a just-written row.
  final DateTime? createdAt;

  String title(String languageCode) => _localized(titles, languageCode);

  String locationLabel(String languageCode) =>
      _localized(locationLabels, languageCode);

  /// Whether [imageRef] is a bundled asset rather than a network URL.
  /// Anything that isn't an `http(s)` URL is treated as an asset path.
  bool get imageIsAsset {
    final ref = imageRef;
    return ref != null && ref.isNotEmpty && !ref.startsWith('http');
  }

  static String _localized(Map<String, String> values, String languageCode) =>
      values[languageCode] ?? values['en'] ?? '';

  /// Builds a row from a Firestore document, or null when the document is
  /// missing what the row cannot be drawn without, or carries a type this
  /// screen no longer has a section for.
  ///
  /// Returning null rather than throwing keeps one malformed or legacy
  /// document from emptying the whole screen — the service skips it and
  /// shows the rest, the same rule [FeaturedItem.fromMap] follows.
  static FavoriteItem? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;

    final category = FavoriteCategory.fromId(data['itemType']);
    if (category == null) return null;

    final itemId = data['itemId'];
    if (itemId is! String || itemId.isEmpty) return null;

    final titles = _localeMap(data['title']);
    if (titles.isEmpty) return null;

    return FavoriteItem(
      id: id,
      category: category,
      itemId: itemId,
      titles: titles,
      locationLabels: _localeMap(data['locationLabel']),
      imageRef:
          data['imageRef'] is String && (data['imageRef'] as String).isNotEmpty
          ? data['imageRef'] as String
          : null,
      createdAt: _dateTime(data['createdAt']),
    );
  }

  /// A Firestore `Timestamp` without importing `cloud_firestore` — this
  /// model stays plain Dart so it can be unit-tested without Firebase.
  /// Anything that is neither a `DateTime` nor a `toDate()`-bearing object
  /// (including the null a server timestamp reads back as before it
  /// resolves) yields null rather than throwing.
  static DateTime? _dateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    try {
      final value = (raw as dynamic).toDate();
      return value is DateTime ? value : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _localeMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (key is String && value is String && value.isNotEmpty) {
        result[key] = value;
      }
    });
    return result;
  }
}
