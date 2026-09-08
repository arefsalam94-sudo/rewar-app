import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/favorite_item.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/page_background.dart';
import 'favorites_screen.dart';

/// Everything saved in one category — what "View all" opens.
///
/// It deliberately owns no service and issues no read: the Favorites screen
/// already holds the whole list from its single query, so this screen is
/// handed that list and the two callbacks that act on it. A second read here
/// would cost a query to show data the caller is already holding.
///
/// It is handed the caller's **notifier**, not a copy, so the two screens
/// cannot disagree about what is saved: a row removed here disappears from
/// the section card behind it, and an Undo tapped on either screen puts the
/// row back on both.
class FavoritesCategoryScreen extends StatelessWidget {
  const FavoritesCategoryScreen({
    super.key,
    required this.category,
    required this.items,
    required this.onOpen,
    required this.onRemove,
  });

  final FavoriteCategory category;

  /// The caller's full saved list — every category, newest first. This screen
  /// filters it rather than being handed a pre-filtered copy, so it keeps
  /// tracking the live list as rows come and go.
  final ValueListenable<List<FavoriteItem>?> items;

  /// Opens a place's detail screen. Owned by the Favorites screen so the
  /// resolve-then-push logic exists once.
  final Future<void> Function(FavoriteItem) onOpen;

  /// Un-saves a place, including its Undo. Also owned by the caller, so a
  /// removal here and a removal there behave identically — and so the row
  /// leaves this list and the section card behind it in one step.
  final Future<void> Function(FavoriteItem) onRemove;

  /// Same photograph as the screen it was opened from, so the pair reads as
  /// one place rather than two.
  static const String backgroundAsset = FavoritesScreen.backgroundAsset;

  String _title(AppLocalizations l10n) => switch (category) {
    FavoriteCategory.stay => l10n.whereToStay,
    FavoriteCategory.nature => l10n.exploreNature,
  };

  /// This category's rows, out of the caller's full saved list.
  List<FavoriteItem> _inCategory(List<FavoriteItem>? all) =>
      (all ?? const <FavoriteItem>[])
          .where((item) => item.category == category)
          .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: FavoritesCategoryScreen.backgroundAsset,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      // Back controls stay on the physical left in every
                      // language, per the shared navigation convention.
                      alignment: Alignment.centerLeft,
                      child: GlassBackButton(
                        useAppLiquidGlass: true,
                        useCanonicalGlass: true,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _title(l10n),
                      style: TextStyle(
                        fontSize: 32,
                        height: 40 / 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.02 * 32,
                        color: AppColors.heading(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CountLine(items: items, category: category),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ValueListenableBuilder<List<FavoriteItem>?>(
                  valueListenable: items,
                  builder: (context, all, _) {
                    final rows = _inCategory(all);
                    if (rows.isEmpty) {
                      return _EmptyState(category: category);
                    }
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 28),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        return FavoriteRow(
                          key: ValueKey('favorite-${item.id}'),
                          item: item,
                          language: language,
                          // Standalone cards here rather than rows inside a
                          // section, exactly like an Explore Nature or
                          // trending-hotel card — so this list is real
                          // canonical glass, not the embedded layer.
                          layer: GlassLayer.surface,
                          onOpen: () => onOpen(item),
                          onRemove: () => onRemove(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "12 options", kept in step with the list below it.
class _CountLine extends StatelessWidget {
  const _CountLine({required this.items, required this.category});

  final ValueListenable<List<FavoriteItem>?> items;
  final FavoriteCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<List<FavoriteItem>?>(
      valueListenable: items,
      builder: (context, all, _) => Text(
        l10n.favoritesOptionCount(
          (all ?? const <FavoriteItem>[])
              .where((item) => item.category == category)
              .length,
        ),
        style: TextStyle(
          fontSize: 15,
          height: 20 / 15,
          color: AppColors.secondaryTextV3(context),
        ),
      ),
    );
  }
}

/// Shown once the user has un-saved everything in this category without
/// leaving the screen — the list cannot refill itself from here, so it says
/// so rather than showing a blank page.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.category});

  final FavoriteCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category == FavoriteCategory.stay
                  ? Icons.king_bed_outlined
                  : Icons.park_outlined,
              size: 52,
              color: AppColors.accent(context),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.favoritesEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                height: 28 / 20,
                fontWeight: FontWeight.w700,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.favoritesEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.onPhotoSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
