import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/favorite_item.dart';
import '../models/hotel.dart';
import '../services/favorites_service.dart';
import '../services/hotel_service.dart';
import '../services/nature_spots_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/sign_in_required.dart';
import 'favorites_category_screen.dart';
import 'hotel_detail_screen.dart';
import 'map_screen.dart';
import 'my_bookings_screen.dart';
import 'nature_place_detail_screen.dart';
import 'policy_screen.dart';

/// Phase 8 — Favorites, the bottom bar's fourth destination.
///
/// Built from the `favorits.png` reference: the back button and title, a count
/// line, then one section card per savable category — Where to Stay and
/// Explore Nature — each previewing its first four saved places above a
/// "View all" row. Those are the only two categories by design: the heart was
/// removed from the Home carousel and from tour cards so that "saved" means
/// one thing, in one place (`FavoritesService`).
///
/// Every row is drawn from the **denormalized snapshot** stored on the
/// favorite document itself (`DATA_MODEL.md` → `favorites`), so opening this
/// tab costs one query rather than one read per saved place. The live
/// document is re-read only when the user actually opens something.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    this.isGuest = false,
    this.service,
    this.natureSpotsService,
    this.hotelService = const PreviewHotelService(),
    this.showBottomNav = false,
  });

  /// True when the screen was reached from the home bar's **Saved** item. The
  /// bar is then kept on screen, in the same place and with the same geometry
  /// as on Home, so tapping it doesn't make the bar disappear out from under
  /// the finger.
  final bool showBottomNav;

  /// A guest has no favorites by definition — the rules require an auth uid —
  /// so the screen shows the shared sign-in gate rather than an empty list.
  /// Same precedent as My Bookings and the drawer's Currency row.
  final bool isGuest;

  final FavoritesService? service;

  /// Resolves a saved nature spot to its live document when the row is
  /// opened. Injectable for tests.
  final NatureSpotsService? natureSpotsService;

  /// Resolves a saved stay. Still the preview catalogue: `hotels` is not
  /// seeded and Where to Stay reads `PreviewHotelService` (`SEED_DATA.md`),
  /// so a stay saved today resolves against typed data, not Firestore.
  final HotelService hotelService;

  /// Favorites is a bar destination rather than a Nature/Hotel/Car/Tour/Flight
  /// screen, so it takes the shared non-category photograph — the same one
  /// Home, Policy and My Bookings use. One photo per screen *category*, per
  /// the design files.
  static const String backgroundAsset = PolicyScreen.backgroundAsset;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final FavoritesService _service = widget.service ?? FavoritesService();
  late final NatureSpotsService _natureService =
      widget.natureSpotsService ?? NatureSpotsService();

  /// The saved list, as a notifier rather than plain state.
  ///
  /// Two things read it: this screen's section cards and, when open, the
  /// "View all" screen. A notifier means an optimistic removal — or the Undo
  /// that reverses it — lands on both at once, instead of the full list
  /// holding a copy that quietly goes stale behind the snackbar.
  ///
  /// `null` is the loading state; a future cannot express the optimistic
  /// removal this screen needs, which is why this is not a `FutureBuilder`.
  final ValueNotifier<List<FavoriteItem>?> _items = ValueNotifier(null);

  Object? _error;

  /// Guards against a second tap while a detail screen is being resolved,
  /// so a double-tap cannot push two copies of the same page.
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _items.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.isGuest) {
      _items.value = const <FavoriteItem>[];
      setState(() => _error = null);
      return;
    }
    _items.value = null;
    setState(() => _error = null);
    try {
      final items = await _service.fetchFavorites();
      if (mounted) _items.value = items;
    } catch (error) {
      debugPrint('Could not load favorites: $error');
      if (mounted) setState(() => _error = error);
    }
  }

  void _snack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// Removes a saved place, with an Undo the user has the length of the
  /// snackbar to take. The row leaves the list immediately rather than after
  /// the write returns — an un-favorite that visibly lags reads as broken,
  /// and the restore path already covers the failure case.
  Future<void> _remove(FavoriteItem item) async {
    final l10n = AppLocalizations.of(context);
    final previous = _items.value;
    if (previous == null) return;

    _items.value = previous.where((other) => other.id != item.id).toList();

    try {
      await _service.remove(item);
      if (!mounted) return;
      _snack(
        l10n.removedFromFavorites,
        action: SnackBarAction(
          label: l10n.favoritesUndo,
          onPressed: () => _restore(item),
        ),
      );
    } catch (error) {
      debugPrint('Favorite removal failed: $error');
      if (!mounted) return;
      // Put it back — the list must not claim something was removed when the
      // write was denied.
      _items.value = previous;
      _snack(l10n.favoriteFailed);
    }
  }

  Future<void> _restore(FavoriteItem item) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _service.restore(item);
      await _load();
    } catch (error) {
      debugPrint('Favorite restore failed: $error');
      if (mounted) _snack(l10n.favoriteFailed);
    }
  }

  /// Opens the saved place's real detail screen.
  ///
  /// The row itself is drawn from the stored snapshot, but the detail screen
  /// is handed the **live** document — so a place renamed since it was saved
  /// opens correctly even though the row still shows the old name. A place
  /// that no longer exists says so rather than opening an empty page.
  Future<void> _open(FavoriteItem item) async {
    if (_opening) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _opening = true);
    try {
      switch (item.category) {
        case FavoriteCategory.nature:
          final spot = await _natureService.fetchSpot(item.itemId);
          if (!mounted) return;
          if (spot == null) {
            _snack(l10n.favoritesPlaceUnavailable);
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NaturePlaceDetailScreen(
                spot: spot,
                natureSpotsService: _natureService,
              ),
            ),
          );
        case FavoriteCategory.stay:
          final hotel = await _findHotel(item.itemId);
          if (!mounted) return;
          if (hotel == null) {
            _snack(l10n.favoritesPlaceUnavailable);
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/hotel/detail'),
              builder: (_) => HotelDetailScreen(
                hotel: hotel,
                criteria: _defaultStayCriteria(),
                service: widget.hotelService,
              ),
            ),
          );
      }
    } catch (error) {
      debugPrint('Could not open favorite: $error');
      if (mounted) _snack(l10n.favoritesPlaceUnavailable);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<Hotel?> _findHotel(String id) async {
    final hotels = await widget.hotelService.trendingHotels();
    for (final hotel in hotels) {
      if (hotel.id == id) return hotel;
    }
    return null;
  }

  /// Hotel Details cannot be opened without a stay to price, and Favorites is
  /// not a search — so it supplies the same starting dates and party Where to
  /// Stay itself opens with (`hotel_screen.dart`), which the user can then
  /// change on the detail screen as usual.
  HotelSearchCriteria _defaultStayCriteria() {
    final today = DateUtils.dateOnly(DateTime.now());
    return HotelSearchCriteria(
      checkIn: today.add(const Duration(days: 1)),
      checkOut: today.add(const Duration(days: 3)),
    );
  }

  /// Opens the full list for one category.
  ///
  /// It is handed the same notifier the sections read, not a copy — so a row
  /// removed on either screen (or restored by Undo) is reflected on both, and
  /// there is nothing to re-read on the way back.
  Future<void> _openViewAll(FavoriteCategory category) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FavoritesCategoryScreen(
          category: category,
          items: _items,
          onOpen: _open,
          onRemove: _remove,
        ),
      ),
    );
  }

  /// Mirrors Home's and My Bookings' handling, so the bar behaves identically
  /// from here. Home is a pop rather than a push: the Home screen is still
  /// underneath, and pushing a second copy would leave two dashboards on the
  /// stack.
  Future<void> _onNavSelected(HomeNavTab tab) async {
    switch (tab) {
      case HomeNavTab.saved:
        return; // Already here.
      case HomeNavTab.home:
        Navigator.of(context).maybePop();
      case HomeNavTab.map:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen()));
      case HomeNavTab.trips:
        // Pushed rather than popped: Favorites may have been reached from
        // Home, where popping would land on the dashboard instead of Trips.
        // Same destination and the same bar-preserving flag Home uses.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                MyBookingsScreen(isGuest: widget.isGuest, showBottomNav: true),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset =
        MediaQuery.paddingOf(context).bottom +
        (widget.showBottomNav ? HomeBottomNav.barHeight + 12 : 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The glass bar floats over the photograph rather than sitting in a
      // solid-coloured slot.
      extendBody: true,
      body: PageBackground(
        imageAsset: FavoritesScreen.backgroundAsset,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: widget.isGuest
                  ? Column(
                      children: [
                        const _HeaderBlock(count: 0, showCount: false),
                        Expanded(
                          child: SignInRequired(
                            title: l10n.favoritesSignInTitle,
                            body: l10n.favoritesSignInBody,
                            icon: Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    )
                  : _body(bottomInset),
            ),
            if (widget.showBottomNav)
              HomeBottomNav.floating(
                context: context,
                current: HomeNavTab.saved,
                onSelect: _onNavSelected,
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(double bottomInset) {
    final l10n = AppLocalizations.of(context);

    if (_error != null) {
      return Column(
        children: [
          const _HeaderBlock(count: 0, showCount: false),
          Expanded(
            child: _MessageState(
              icon: Icons.cloud_off_rounded,
              title: l10n.favoritesLoadFailed,
              body: '$_error',
              actionLabel: l10n.tryAgain,
              onAction: _load,
            ),
          ),
        ],
      );
    }

    return ValueListenableBuilder<List<FavoriteItem>?>(
      valueListenable: _items,
      builder: (context, items, _) {
        if (items == null) {
          return const Column(
            children: [
              _HeaderBlock(count: 0, showCount: false),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          );
        }

        final stays = items
            .where((item) => item.category == FavoriteCategory.stay)
            .toList();
        final nature = items
            .where((item) => item.category == FavoriteCategory.nature)
            .toList();

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 28),
            children: [
              _Header(count: items.length),
              const SizedBox(height: 22),
              if (items.isEmpty)
                _MessageState(
                  icon: Icons.favorite_border_rounded,
                  title: l10n.favoritesEmptyTitle,
                  body: l10n.favoritesEmptyBody,
                )
              else ...[
                if (stays.isNotEmpty) ...[
                  _FavoritesSection(
                    icon: Icons.king_bed_outlined,
                    title: l10n.whereToStay,
                    items: stays,
                    onOpen: _open,
                    onRemove: _remove,
                    onViewAll: () => _openViewAll(FavoriteCategory.stay),
                  ),
                  const SizedBox(height: 20),
                ],
                if (nature.isNotEmpty) ...[
                  _FavoritesSection(
                    icon: Icons.park_outlined,
                    title: l10n.exploreNature,
                    items: nature,
                    onOpen: _open,
                    onRemove: _remove,
                    onViewAll: () => _openViewAll(FavoriteCategory.nature),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
              const SizedBox(height: 2),
              // Always drawn, as in the reference — and tappable back to
              // browsing rather than left inert.
              _KeepExploringCard(onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
        );
      },
    );
  }
}

/// [_Header] with the horizontal inset the list normally supplies, for the
/// loading, error and guest states — which sit outside the padded `ListView`
/// and would otherwise put the back button flush against the screen edge.
class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.count, this.showCount = true});

  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: _Header(count: count, showCount: showCount),
  );
}

// --- Header ------------------------------------------------------------------

/// The back button, the page title, and the "24 Favorites" count line.
class _Header extends StatelessWidget {
  const _Header({required this.count, this.showCount = true});

  final int count;

  /// Hidden while loading, on the error state and for a guest — a count of
  /// zero shown next to a spinner reads as "you have none".
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            // The shared navigation convention keeps back controls on the
            // physical left in every language.
            alignment: Alignment.centerLeft,
            child: GlassBackButton(
              useAppLiquidGlass: true,
              useCanonicalGlass: true,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.favoritesTitle,
            // display-lg — identical to My Bookings' title, so the two bar
            // destinations share one heading treatment.
            style: TextStyle(
              fontSize: 32,
              height: 40 / 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02 * 32,
              color: AppColors.heading(context),
            ),
          ),
          if (showCount) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _StrokeIconCircle(
                  icon: Icons.favorite_border_rounded,
                  size: 34,
                  iconSize: 18,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.favoritesCount(count),
                  style: TextStyle(
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Stroke-only circle around an icon — the same treatment `GlassListRow` and
/// the Customize Filters group headers use. No fill, per the design files.
class _StrokeIconCircle extends StatelessWidget {
  const _StrokeIconCircle({
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Icon(icon, size: iconSize, color: accent),
    );
  }
}

// --- Section -----------------------------------------------------------------

/// One category card: header, up to four saved places, then "View all".
///
/// The card is the real canonical surface and the rows inside it are
/// [GlassLayer.embedded] — one shader for the whole section rather than one
/// per row. That is the nesting rule `07_DESIGN_EXCEPTIONS.md` §9 draws the
/// line at: a repeated, unbounded list of real glass surfaces stacked close
/// together is the condition that corrupted Register and Choose Room.
class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.onOpen,
    required this.onRemove,
    required this.onViewAll,
  });

  final IconData icon;
  final String title;
  final List<FavoriteItem> items;
  final ValueChanged<FavoriteItem> onOpen;
  final ValueChanged<FavoriteItem> onRemove;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final preview = items.take(FavoritesService.sectionPreviewCount).toList();

    return AppLiquidGlass(
      useCanonicalGlass: true,
      borderRadius: 28,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 0),
            child: Row(
              children: [
                _StrokeIconCircle(icon: icon, size: 42, iconSize: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      // headline-md
                      fontSize: 20,
                      height: 26 / 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.favoritesOptionCount(items.length),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryTextV3(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final item in preview) ...[
            FavoriteRow(
              item: item,
              language: language,
              onOpen: () => onOpen(item),
              onRemove: () => onRemove(item),
            ),
            const SizedBox(height: 10),
          ],
          // Only offered when there is more than the preview shows — a "View
          // all" that opens the same four rows is a dead end.
          if (items.length > preview.length)
            _ViewAllRow(onTap: onViewAll)
          else
            const SizedBox(height: 2),
        ],
      ),
    );
  }
}

/// The full-width "View all" row that closes a section card.
class _ViewAllRow extends StatelessWidget {
  const _ViewAllRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppLiquidGlass(
      useCanonicalGlass: true,
      // Inside the section's own glass — tint and geometry only, no second
      // shader. See [_FavoritesSection].
      layer: GlassLayer.embedded,
      borderRadius: 20,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            l10n.favoritesViewAll,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.accent(context),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Row ---------------------------------------------------------------------

/// One saved place: photo, name, place line, the heart, and the arrow that
/// opens it.
///
/// Public because the "View all" screen draws the identical row — the two
/// lists must not drift into two different-looking rows for the same thing.
class FavoriteRow extends StatelessWidget {
  const FavoriteRow({
    super.key,
    required this.item,
    required this.language,
    required this.onOpen,
    required this.onRemove,
    this.layer = GlassLayer.embedded,
  });

  final FavoriteItem item;
  final String language;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  /// [GlassLayer.embedded] inside a section card (the default), and
  /// [GlassLayer.surface] on the "View all" screen, where each row is a
  /// standalone card exactly like an Explore Nature or trending-hotel card.
  final GlassLayer layer;

  static const double photoWidth = 96;
  static const double photoHeight = 74;

  @override
  Widget build(BuildContext context) {
    final location = item.locationLabel(language);

    return Semantics(
      button: true,
      label: item.title(language),
      child: AppLiquidGlass(
        useCanonicalGlass: true,
        layer: layer,
        borderRadius: 20,
        onTap: onOpen,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: photoWidth,
                height: photoHeight,
                child: _FavoritePhoto(item: item),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      // headline-sm
                      fontSize: 17,
                      height: 22 / 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.accent(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              // body-sm
                              fontSize: 13,
                              height: 18 / 13,
                              color: AppColors.secondaryTextV3(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Always filled: everything on this screen is, by definition,
            // already a favorite. Tapping it un-saves the place.
            FavoriteHeartButton(
              isFavorite: true,
              onTap: onRemove,
              showCircle: false,
              targetSize: 44,
              iconSize: 23,
            ),
            _OpenArrowButton(onTap: onOpen),
          ],
        ),
      ),
    );
  }
}

/// The row thumbnail.
///
/// [FavoriteItem.imageRef] is either a Storage download URL or a bundled
/// asset path, so the widget picks the loader rather than the caller — and
/// both paths fall back to the same placeholder, so a missing photo never
/// leaves a hole in the row.
class _FavoritePhoto extends StatelessWidget {
  const _FavoritePhoto({required this.item});

  final FavoriteItem item;

  @override
  Widget build(BuildContext context) {
    final ref = item.imageRef;
    final fallback = _placeholder(context);
    if (ref == null || ref.isEmpty) return fallback;

    if (item.imageIsAsset) {
      return Image.asset(
        ref,
        fit: BoxFit.cover,
        cacheWidth: 320,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      ref,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: AppColors.glassBaseTint(context).withValues(alpha: .22),
    child: Icon(
      item.category == FavoriteCategory.stay
          ? Icons.hotel_outlined
          : Icons.park_outlined,
      size: 28,
      color: AppColors.accent(context),
    ),
  );
}

/// The circular arrow at the end of a row — "take me to this place".
///
/// `Icons.arrow_forward` is declared `matchTextDirection: true`, so Flutter
/// mirrors it in Kurdish and Arabic on its own — unlike `chevron_right`,
/// which `GlassListRow` has to swap by hand. Swapping this one manually as
/// well would flip it twice and point it the wrong way.
///
/// Uses the same circle fill as [FavoriteHeartButton] so the two controls
/// beside each other read as one pair rather than two unrelated buttons.
class _OpenArrowButton extends StatelessWidget {
  const _OpenArrowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;

    return Semantics(
      button: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.darkGlassTop.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.9),
                ),
                child: Icon(Icons.arrow_forward, size: 19, color: accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Footer ------------------------------------------------------------------

/// "Keep exploring — your next adventure is waiting."
///
/// Always drawn, as in the reference, and tappable back to browsing so it has
/// a job rather than sitting inert. The reference's tent-and-mountains
/// illustration is deliberately not drawn: no such asset exists in the
/// project, and inventing one is not a design decision this screen gets to
/// make.
class _KeepExploringCard extends StatelessWidget {
  const _KeepExploringCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      child: AppLiquidGlass(
        useCanonicalGlass: true,
        borderRadius: 28,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 34,
              color: AppColors.accent(context),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.favoritesKeepExploring,
                    style: TextStyle(
                      fontSize: 19,
                      height: 24 / 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.favoritesKeepExploringBody,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 19 / 13.5,
                      color: AppColors.secondaryTextV3(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Shared empty / error presentation ---------------------------------------

/// The same shape My Bookings uses for its empty and error states, so the two
/// bar destinations do not drift into two different-looking failures.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 52, color: AppColors.accent(context)),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            height: 28 / 20,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.onPhotoSecondary(context),
            ),
          ),
        ],
        if (actionLabel case final label?) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: PrimaryButton(label: label, onTap: () => onAction?.call()),
          ),
        ],
      ],
    ),
  );
}
