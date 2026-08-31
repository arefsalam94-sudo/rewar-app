import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/nature_filters.dart';
import '../models/nature_spot.dart';
import '../services/device_location_service.dart';
import '../services/nature_spots_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import 'customize_filters_screen.dart';
import 'nature_place_detail_screen.dart';

/// Phase 3 — the Explore Nature list screen, opened from the Home screen's
/// "Explore Nature" card.
///
/// Layout comes from the `explore nature.jpg` reference: a carousel of the
/// highlighted places, a filter bar, then a card per place. Every colour,
/// radius and text size comes from tokens already approved in
/// `DESIGN_SYSTEM.md` — nothing new was invented to match the screenshot.
///
/// Catalog data is public read, so a guest sees exactly what a signed-in user
/// sees (`SECURITY.md` section 1, `firestore.rules` → `nature_spots`).
class ExploreNatureScreen extends StatefulWidget {
  const ExploreNatureScreen({
    super.key,
    this.natureSpotsService,
    this.locationService,
  });

  /// Injectable for tests; defaults to the real Firestore-backed service.
  final NatureSpotsService? natureSpotsService;

  /// Injectable for tests. A test that passes nothing gets the real service,
  /// which returns null off-device — so the Distance row simply stays hidden
  /// rather than failing.
  final DeviceLocationService? locationService;

  @override
  State<ExploreNatureScreen> createState() => _ExploreNatureScreenState();
}

class _ExploreNatureScreenState extends State<ExploreNatureScreen> {
  late final NatureSpotsService _service =
      widget.natureSpotsService ?? NatureSpotsService();
  late final DeviceLocationService _locationService =
      widget.locationService ?? const DeviceLocationService();

  late Future<List<NatureSpot>> _highlightedFuture;

  /// The whole active catalog, fetched once and filtered in Dart.
  ///
  /// Firestore permits one array clause per query and this screen now has
  /// three multi-select dimensions (quick chips, place types, facilities), so
  /// filtering server-side is not possible in a single query — and the
  /// Customize screen's "Show N places" button has to be exact on every tap.
  /// See [NatureSpotsService.fetchCatalog].
  ///
  /// Held as plain state rather than behind a `FutureBuilder` because the
  /// filter bar needs the same list the list section is drawn from, to hand to
  /// the Customize screen — reading it out of a builder would mean either a
  /// second read or a side effect during build.
  List<NatureSpot>? _catalog;
  Object? _catalogError;

  /// Everything currently narrowing the list, across all three dimensions.
  NatureFilters _filters = const NatureFilters();

  /// Null until a GPS fix arrives, and stays null when location is off or
  /// denied — the cards then hide their Distance row instead of inventing one.
  DeviceLocation? _deviceLocation;

  final PageController _carouselController = PageController();
  int _currentSlide = 0;

  @override
  void initState() {
    super.initState();
    _highlightedFuture = _service.fetchHighlighted();
    _loadCatalog();
    _loadDeviceLocation();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  /// The distance line is a nice-to-have, so a failure here must never surface
  /// as an error on a screen that is otherwise working.
  Future<void> _loadDeviceLocation() async {
    final location = await _locationService.currentLocation();
    if (mounted && location != null) {
      setState(() => _deviceLocation = location);
    }
  }

  void _retryHighlighted() {
    setState(() {
      _currentSlide = 0;
      _highlightedFuture = _service.fetchHighlighted();
    });
  }

  /// Loads the catalog, and is also the retry path — it resets to the loading
  /// state first, so a retry visibly restarts rather than sitting on the error.
  Future<void> _loadCatalog() async {
    setState(() {
      _catalog = null;
      _catalogError = null;
    });
    try {
      final spots = await _service.fetchCatalog();
      if (mounted) setState(() => _catalog = spots);
    } catch (error) {
      debugPrint('Could not load nature spots: $error');
      if (mounted) setState(() => _catalogError = error);
    }
  }

  /// Toggling a chip costs no read — the catalog is already in memory, so the
  /// list and the Customize counter both re-derive from it.
  void _toggleActivity(String categoryId) =>
      setState(() => _filters = _filters.toggleActivity(categoryId));

  void _clearFilters() => setState(() => _filters = const NatureFilters());

  /// Opens the Customize Filters screen, handing it the catalog it needs to
  /// count matches so it never issues a read of its own. A null result means
  /// the user backed out, and the current filters are kept.
  Future<void> _openCustomize(List<NatureSpot> catalog) async {
    final result = await Navigator.of(context).push<NatureFilters>(
      MaterialPageRoute<NatureFilters>(
        builder: (_) =>
            CustomizeFiltersScreen(initialFilters: _filters, catalog: catalog),
      ),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  /// Opens the selected place's detail screen, handing it the services this
  /// screen already holds so the detail page doesn't build its own (and so a
  /// test can inject fakes once, here).
  void _openSpot(NatureSpot spot) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NaturePlaceDetailScreen(
        spot: spot,
        natureSpotsService: _service,
        locationService: _locationService,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: exploreNatureBackgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset + 28),
            children: [
              const _BackBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCarousel(l10n, languageCode),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FilterBar(
                  selected: _filters.activities,
                  // A dot on the Customize chip while place-type or facility
                  // filters are active, so a selection made on the other screen
                  // is still visible from here.
                  customizeCount: _filters.customizeCount,
                  onToggle: _toggleActivity,
                  // Needs the catalog to count matches; until it has loaded
                  // there is nothing to count, so the chip waits.
                  onCustomize: _catalog == null
                      ? null
                      : () => _openCustomize(_catalog!),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSpotList(l10n, languageCode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel(AppLocalizations l10n, String languageCode) {
    return SizedBox(
      height: _HighlightCard.heightFor(context),
      child: FutureBuilder<List<NatureSpot>>(
        future: _highlightedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PanelShell(child: _PanelLoading());
          }
          if (snapshot.hasError) {
            return _PanelShell(
              child: _PanelMessage(
                message: l10n.natureSpotsLoadFailed,
                actionLabel: l10n.tryAgain,
                onAction: _retryHighlighted,
              ),
            );
          }

          final spots = snapshot.data ?? const <NatureSpot>[];
          if (spots.isEmpty) {
            return _PanelShell(
              child: _PanelMessage(message: l10n.highlightedEmpty),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _carouselController,
                itemCount: spots.length,
                onPageChanged: (index) => setState(() => _currentSlide = index),
                itemBuilder: (context, index) => _HighlightCard(
                  spot: spots[index],
                  languageCode: languageCode,
                  onTap: () => _openSpot(spots[index]),
                ),
              ),
              // Outside the PageView, so the dots stay still while the slides
              // move — the same rule the Home carousel follows.
              PositionedDirectional(
                end: 20,
                bottom: 16,
                child: _Dots(count: spots.length, current: _currentSlide),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpotList(AppLocalizations l10n, String languageCode) {
    if (_catalogError != null) {
      return SizedBox(
        height: 160,
        child: _PanelShell(
          child: _PanelMessage(
            message: l10n.natureSpotsLoadFailed,
            actionLabel: l10n.tryAgain,
            onAction: _loadCatalog,
          ),
        ),
      );
    }

    final catalog = _catalog;
    if (catalog == null) {
      return const SizedBox(
        height: 160,
        child: _PanelShell(child: _PanelLoading()),
      );
    }

    // The whole filter set, applied in one pass over the in-memory catalog.
    final spots = catalog.where(_filters.matches).toList(growable: false);
    if (spots.isEmpty) {
      return SizedBox(
        height: 160,
        child: _PanelShell(
          child: _PanelMessage(
            message: l10n.natureSpotsEmpty,
            // Only offered when a filter is what emptied the list — otherwise
            // there is nothing to clear.
            actionLabel: _filters.isEmpty ? null : l10n.clearFilters,
            onAction: _filters.isEmpty ? null : _clearFilters,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final spot in spots) ...[
          _SpotCard(
            spot: spot,
            languageCode: languageCode,
            deviceLocation: _deviceLocation,
            onTap: () => _openSpot(spot),
          ),
          if (spot != spots.last) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

// --- Chrome -----------------------------------------------------------------

/// The back button and page title share the top row. It remains sized by its
/// content so large system text can grow instead of being clipped.
class _BackBar extends StatelessWidget {
  const _BackBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textDirection = Directionality.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        // Keep the back button on the physical left in every language.
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GlassBackButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 14),
          Expanded(
            child: Directionality(
              textDirection: textDirection,
              child: Text(
                l10n.exploreNature,
                style: TextStyle(
                  fontSize: 28,
                  height: 36 / 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02 * 28,
                  color: AppColors.heading(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Both design files specify the organic 28px `rounded-card` silhouette.
double _cardRadius(BuildContext context) => 28;

Color _natureHeading(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return scheme.brightness == Brightness.dark ? Colors.white : scheme.onSurface;
}

Color _natureSecondary(BuildContext context) =>
    AppColors.secondaryText(context);

// --- Highlighted carousel ---------------------------------------------------

/// One carousel slide: the photo of a highlighted place, its score and stars,
/// name, location line and a clipped description.
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.spot,
    required this.languageCode,
    required this.onTap,
  });

  final NatureSpot spot;
  final String languageCode;
  final VoidCallback onTap;

  /// Base height, grown for large system font sizes so the overlaid copy never
  /// runs out of room — the same rule the Home screen's featured card uses.
  static double heightFor(BuildContext context) {
    final factor = (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(
      1.0,
      1.6,
    );
    return 288 * factor;
  }

  @override
  Widget build(BuildContext context) {
    final radius = _cardRadius(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = spot.reviewScore;

    return Padding(
      // Keeps a gap between slides as the PageView scrolls.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        label: spot.name(languageCode),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SpotPhoto(spot: spot, index: 0),
                // Scrim, so white copy stays legible over any photograph.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x40000000),
                        Color(0x00000000),
                        Color(0xB3000000),
                      ],
                      stops: [0.0, 0.32, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (score != null)
                        Row(
                          children: [
                            const Spacer(),
                            _ScoreBox(score: score),
                            const SizedBox(width: 10),
                            _StarBox(score: score),
                          ],
                        ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          spot.name(languageCode),
                          maxLines: 1,
                          style: const TextStyle(
                            // headline-lg
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        spot.locationLabel(languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        // Keeps the copy clear of the dot row in the opposite
                        // corner, which is drawn outside this slide.
                        padding: const EdgeInsetsDirectional.only(end: 70),
                        child: Text(
                          spot.description(languageCode),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 17 / 13,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? AppColors.darkBorderOpacity : 0.35,
                        ),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A spot photograph: a bundled asset in preview mode, a Storage URL in
/// production. Both fall back to a brand-coloured panel with a park icon
/// rather than a broken-image box.
class _SpotPhoto extends StatelessWidget {
  const _SpotPhoto({required this.spot, required this.index});

  final NatureSpot spot;

  /// Which of the spot's photos to draw. Out-of-range falls back gracefully.
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = ColoredBox(
      color: isDark
          ? AppColors.darkForestFloor
          : AppColors.pageGradientBottom.withValues(alpha: 0.55),
      child: Center(
        child: Icon(
          Icons.park_outlined,
          size: 34,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );

    final photos = spot.photos;
    if (photos.isEmpty || index >= photos.length) return fallback;
    final photo = photos[index];

    if (spot.photosAreAssets) {
      return Image.asset(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    return Image.network(
      photo,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

/// Page dots. Always laid out left-to-right, like the Home carousel and the
/// onboarding flight path — a progress track is not a sentence.
@visibleForTesting
const Key exploreNatureDotsKey = ValueKey('explore-nature-dots');

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      key: exploreNatureDotsKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 9 : 7,
            height: i == current ? 9 : 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: i == current ? 1 : 0.5),
            ),
          ),
      ],
    ),
  );
}

// --- Score + stars ----------------------------------------------------------

/// The 0–10 review score, in a rounded box.
///
/// Uses the same unified rating treatment over photos and glass cards.
class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) => _BadgeShell(
    child: Text(
      score.toStringAsFixed(1),
      // Always left-to-right: a decimal score reads the same way in every
      // language.
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: _BadgeShell.contentColor(context),
      ),
    ),
  );
}

/// Five stars, filled from the same 0–10 score. Derived, never stored — see
/// [NatureSpot.starsForScore].
class _StarBox extends StatelessWidget {
  const _StarBox({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final filled = NatureSpot.starsForScore(score);
    final color = _BadgeShell.contentColor(context);

    return _BadgeShell(
      child: Directionality(
        // A rating track fills left-to-right in every language, the same rule
        // the carousel dots follow.
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: EdgeInsets.only(right: i == 4 ? 0 : 4),
                child: Icon(
                  i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 15,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared shell behind [_ScoreBox] and [_StarBox], per the mandatory unified
/// rating-badge rule in both theme documents.
class _BadgeShell extends StatelessWidget {
  const _BadgeShell({required this.child});

  final Widget child;

  // Text and icons report different intrinsic heights. A shared minimum keeps
  // the numeric score and star badges level without clipping scaled text.
  static const double minHeight = 32;

  /// `DESIGN light.md` → "Search Inputs: 12px corner radius"; these are the
  /// same small rounded-rect family.
  static const double radius = 12;

  static Color contentColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkOnPrimary
      : AppColors.actionNavy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      // The reference draws a green outline on these badges. Brand green at
      // partial opacity — an approved token, not a new colour.
      constraints: const BoxConstraints(minHeight: minHeight),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.luminousMint
            : AppColors.pageGradientTop.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark ? AppColors.darkOnPrimary : AppColors.actionNavy,
        ),
      ),
      child: child,
    );
  }
}

// --- Filter bar -------------------------------------------------------------

/// The chip row: Hiking · Beach · Sunset View · Customize.
///
/// Horizontally scrollable, because four chips plus their labels do not fit on
/// a 320dp phone — and certainly not at a raised system font size.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.customizeCount,
    required this.onToggle,
    required this.onCustomize,
  });

  final Set<String> selected;

  /// How many place-type / facility filters are active. Drawn as a badge on
  /// the Customize chip so a selection made on the other screen stays visible
  /// from here.
  final int customizeCount;

  final ValueChanged<String> onToggle;

  /// Null until the catalog has loaded — the Customize screen counts matches
  /// against it, so there is nothing to open before then.
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final chips = <Widget>[
      _FilterChip(
        icon: Icons.hiking_rounded,
        label: l10n.filterHiking,
        selected: selected.contains(NatureCategory.hiking.id),
        onTap: () => onToggle(NatureCategory.hiking.id),
      ),
      _FilterChip(
        icon: Icons.beach_access_rounded,
        label: l10n.filterBeach,
        selected: selected.contains(NatureCategory.beach.id),
        onTap: () => onToggle(NatureCategory.beach.id),
      ),
      _FilterChip(
        icon: Icons.wb_sunny_outlined,
        label: l10n.filterSunsetView,
        selected: selected.contains(NatureCategory.sunsetView.id),
        onTap: () => onToggle(NatureCategory.sunsetView.id),
      ),
      _FilterChip(
        icon: Icons.tune_rounded,
        label: l10n.filterCustomize,
        // Not "selected" — it opens a screen rather than toggling a value —
        // but it carries a count badge when filters are active behind it.
        selected: false,
        badgeCount: customizeCount,
        onTap: onCustomize,
      ),
    ];

    return GlassPanel(
      borderRadius: _cardRadius(context),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final chip in chips) ...[
              chip,
              if (chip != chips.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;

  /// Null renders the chip disabled (greyed, not tappable).
  final VoidCallback? onTap;

  /// Drawn as a small filled counter after the label when greater than zero.
  final int badgeCount;

  /// Drawn at 38dp inside a 48dp tap target, per the "48dp minimum touch
  /// target" rule — the same technique `_ArrowPill` uses on the Home screen.
  static const double visualHeight = 38;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final content = AppColors.selectionAccent(
      context,
    ).withValues(alpha: enabled ? 1 : 0.4);

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: (48 - visualHeight) / 2,
          ),
          child: GlassPanel(
            borderRadius: 999,
            depth: GlassDepth.top,
            selected: selected,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: visualHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: content),
                  const SizedBox(width: 6),
                  // Allowed to shrink rather than overflow — the "text next to
                  // text must be allowed to shrink" rule.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: content,
                        ),
                      ),
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$badgeCount',
                        // A count reads the same way in every language.
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Place card -------------------------------------------------------------

/// One place in the list: thumbnail on the leading edge, score and stars at the
/// top of the trailing column, then name, location, distance and description.
///
/// The thumbnail sits on the **leading** edge rather than a fixed left, so the
/// whole card mirrors in Kurdish and Arabic instead of reading backwards.
class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.spot,
    required this.languageCode,
    required this.deviceLocation,
    required this.onTap,
  });

  final NatureSpot spot;
  final String languageCode;
  final DeviceLocation? deviceLocation;
  final VoidCallback onTap;

  static const double thumbnailWidth = 126;
  static const double minHeight = 158;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final radius = _cardRadius(context);
    final score = spot.reviewScore;
    final distance = _distanceText(l10n);

    return Semantics(
      button: true,
      label: spot.name(languageCode),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: GlassPanel(
          borderRadius: radius,
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: thumbnailWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius - 4),
                      child: _SpotPhoto(spot: spot, index: 0),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (score != null) ...[
                          Row(
                            children: [
                              const Spacer(),
                              _ScoreBox(score: score),
                              const SizedBox(width: 10),
                              _StarBox(score: score),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          spot.name(languageCode),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            // headline-md
                            fontSize: 19,
                            height: 24 / 19,
                            fontWeight: FontWeight.w700,
                            color: _natureHeading(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LabelledLine(
                          label: l10n.locationLabel,
                          value: spot.locationLabel(languageCode),
                        ),
                        if (distance != null) ...[
                          const SizedBox(height: 4),
                          _LabelledLine(
                            label: l10n.distanceLabel,
                            value: distance,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          spot.description(languageCode),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            // body-sm
                            fontSize: 13,
                            height: 19 / 13,
                            color: _natureSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "2.5 km from current location", or null when either the device position
  /// or the spot's coordinates are missing — in which case the row is not
  /// drawn at all, rather than showing a distance from somewhere the user
  /// is not.
  String? _distanceText(AppLocalizations l10n) {
    final from = deviceLocation;
    if (from == null) return null;
    final meters = spot.distanceMetersFrom(from.latitude, from.longitude);
    if (meters == null) return null;
    return l10n.distanceFromCurrentLocation(formatSpotDistance(meters));
  }
}

/// Metres under a kilometre, then one decimal up to 10 km, then whole
/// kilometres — "0.3 km" and "127.4 km" are both worse than "300 m" and
/// "127 km".
@visibleForTesting
String formatSpotDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

/// A bold label with its value beside it ("Location:  Erbil, Iraq").
class _LabelledLine extends StatelessWidget {
  const _LabelledLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final headingColor = _natureHeading(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Both halves are allowed to shrink rather than overflow on a narrow
        // phone or at a raised system font size.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: _natureSecondary(context)),
          ),
        ),
      ],
    );
  }
}

// --- Loading / error / empty ------------------------------------------------

/// Shared frame for this screen's loading, error and empty states, so the
/// layout does not jump between them.
class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: _cardRadius(context),
    padding: const EdgeInsets.all(20),
    child: Center(child: child),
  );
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: CircularProgressIndicator(
      strokeWidth: 2.5,
      color: AppColors.accent(context),
    ),
  );
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: _natureSecondary(context)),
        ),
        if (label != null && action != null) ...[
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: label,
            child: InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkOnPrimary : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
