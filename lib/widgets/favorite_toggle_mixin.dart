import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/favorite_item.dart';
import '../services/favorites_service.dart';
import 'sign_in_required.dart';

/// The save/un-save behaviour behind every heart in the app.
///
/// Four screens draw a heart — Where to Stay and Explore Nature, plus each of
/// their detail pages — and before this existed the same forty lines were
/// copy-pasted per screen, which is how the Home and Tours copies drifted
/// apart. Mixing this in gives a screen [favoriteIds], [isFavorite],
/// [favoritePending] and [toggleFavorite], and nothing else to get wrong.
///
/// A guest gets the shared [SignInRequiredSheet] rather than a silent no-op:
/// `favorites` rows are keyed by `userId` and the rules require a matching
/// `request.auth.uid`, so there is no such thing as an anonymous favorite
/// (`SECURITY.md` 6.1f — no anonymous mirror of signed-in data).
mixin FavoriteToggleMixin<T extends StatefulWidget> on State<T> {
  /// The service the screen already holds, so a test injects one fake rather
  /// than one per mixin.
  FavoritesService get favoritesService;

  /// Which section of the Favorites screen this screen's hearts save into.
  FavoriteCategory get favoriteCategory;

  /// Whether the current viewer is browsing without an account.
  ///
  /// Defaults to asking the service, which reports whether Firebase has a
  /// signed-in user. A screen that already knows (because its caller told it)
  /// can override.
  bool get favoritesViewerIsGuest => !favoritesService.hasViewer;

  Set<String> _favoriteIds = <String>{};
  final Set<String> _pending = <String>{};

  /// The ids this viewer has already saved **in this category**.
  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String itemId) => _favoriteIds.contains(itemId);

  /// True while a write for [itemId] is in flight, so the heart can dim and
  /// a double-tap cannot fire twice.
  bool favoritePending(String itemId) => _pending.contains(itemId);

  /// Loads the saved ids for this category.
  ///
  /// Never surfaces an error: a screen whose hearts failed to load is still a
  /// working catalogue screen, so a failure leaves every heart empty rather
  /// than replacing the list with an error state.
  Future<void> loadFavoriteIds() async {
    if (favoritesViewerIsGuest) return;
    try {
      final ids = await favoritesService.fetchFavoriteItemIds(
        category: favoriteCategory,
      );
      if (mounted) setState(() => _favoriteIds = ids);
    } catch (error) {
      debugPrint('Could not load favorites: $error');
    }
  }

  /// Saves or un-saves [itemId], writing [snapshot] so the Favorites screen
  /// can draw the row without a second read.
  ///
  /// [snapshot] is a callback rather than a value so a screen listing dozens
  /// of places doesn't build one for every card on every rebuild — it is only
  /// needed on the tap that actually saves.
  Future<void> toggleFavorite({
    required String itemId,
    required FavoriteSnapshot Function() snapshot,
  }) async {
    final l10n = AppLocalizations.of(context);

    if (favoritesViewerIsGuest) {
      await showFavoriteSignInSheet();
      return;
    }
    if (_pending.contains(itemId)) return;

    final wasFavorite = _favoriteIds.contains(itemId);
    setState(() => _pending.add(itemId));
    try {
      final nowFavorite = await favoritesService.toggle(
        category: favoriteCategory,
        itemId: itemId,
        currentlyFavorite: wasFavorite,
        snapshot: snapshot(),
      );
      if (!mounted) return;
      setState(() {
        if (nowFavorite) {
          _favoriteIds.add(itemId);
        } else {
          _favoriteIds.remove(itemId);
        }
      });
      _snack(nowFavorite ? l10n.addedToFavorites : l10n.removedFromFavorites);
    } catch (error) {
      debugPrint('Favorite toggle failed: $error');
      if (mounted) _snack(l10n.favoriteFailed);
    } finally {
      if (mounted) setState(() => _pending.remove(itemId));
    }
  }

  /// The shared "you need an account for this" sheet, in this feature's own
  /// words. Exposed so a screen can show it from somewhere other than a heart.
  Future<void> showFavoriteSignInSheet() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SignInRequiredSheet(
        title: l10n.signInToSave,
        body: l10n.signInToSaveBody,
        icon: Icons.favorite_border_rounded,
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
