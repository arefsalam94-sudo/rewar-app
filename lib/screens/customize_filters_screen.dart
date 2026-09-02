import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/nature_filters.dart';
import '../models/nature_spot.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';

/// Phase 3 — the Customize Filters sheet, opened from the Explore Nature
/// screen's "Customize" chip.
///
/// Layout comes from the `explore nature-filters.jpeg` reference: one modal
/// glass card holding the title row, a live selection counter, a card per
/// filter group, and an apply button carrying the live result count.
///
/// **No Firestore read.** The caller hands over the catalog it already
/// fetched, so every chip tap re-counts instantly and for free — see
/// [NatureSpotsService.fetchCatalog] for why filtering lives in Dart.
///
/// Returns the edited [NatureFilters] via `Navigator.pop`, or null if the user
/// backed out — backing out is a cancel, the apply button is the commit.
class CustomizeFiltersScreen extends StatefulWidget {
  const CustomizeFiltersScreen({
    super.key,
    required this.initialFilters,
    required this.catalog,
  });

  /// The filters currently applied on the list screen. The quick chips
  /// (Hiking / Beach / Sunset View) travel along inside this and are not
  /// editable here — they stay selected behind this screen and still count
  /// toward the result total.
  final NatureFilters initialFilters;

  /// The already-fetched catalog, used only to count matches.
  final List<NatureSpot> catalog;

  @override
  State<CustomizeFiltersScreen> createState() => _CustomizeFiltersScreenState();
}

class _CustomizeFiltersScreenState extends State<CustomizeFiltersScreen> {
  late NatureFilters _draft = widget.initialFilters;

  /// Places matching the draft across **all three** dimensions, including the
  /// quick chips the user set before opening this screen — the number on the
  /// button has to be what they will actually see.
  int get _matchCount => widget.catalog.where(_draft.matches).length;

  void _togglePlaceType(String id) =>
      setState(() => _draft = _draft.togglePlaceType(id));

  void _toggleAmenity(String id) =>
      setState(() => _draft = _draft.toggleAmenity(id));

  void _resetAll() => setState(() => _draft = _draft.clearCustomize());

  void _apply() => Navigator.of(context).pop(_draft);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: exploreNatureBackgroundAsset,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: GlassPanel(
                        // L1 of the canonical three-deep glass stack.
                        borderRadius: _panelRadius(context),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(),
                            const SizedBox(height: 14),
                            _CounterRow(
                              count: _draft.customizeCount,
                              onReset: _draft.customizeCount == 0
                                  ? null
                                  : _resetAll,
                            ),
                            const SizedBox(height: 14),
                            _FilterGroupCard(
                              icon: Icons.explore_outlined,
                              title: l10n.placeType,
                              children: [
                                for (final type in NaturePlaceType.values)
                                  _FilterChoiceChip(
                                    icon: placeTypeIcon(type),
                                    label: l10n.placeTypeLabel(type),
                                    selected: _draft.placeTypes.contains(
                                      type.id,
                                    ),
                                    onTap: () => _togglePlaceType(type.id),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _FilterGroupCard(
                              icon: Icons.apartment_rounded,
                              title: l10n.facilitiesAmenities,
                              children: [
                                for (final amenity in NatureAmenity.values)
                                  _FilterChoiceChip(
                                    icon: amenityIcon(amenity),
                                    label: l10n.amenityLabel(amenity),
                                    selected: _draft.amenities.contains(
                                      amenity.id,
                                    ),
                                    onTap: () => _toggleAmenity(amenity.id),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: _hairline(context),
                            ),
                            const SizedBox(height: 14),
                            _ShowPlacesButton(
                              count: _matchCount,
                              onTap: _apply,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Keep page navigation outside the content card, in the same
              // physical top-left position for LTR and RTL languages.
              Positioned(
                left: 8,
                top: 8,
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared with the Explore Nature screen so the two pages sit on an identical
/// background — the design files require the treatment to be uniform.
const String exploreNatureBackgroundAsset =
    'assets/images/Explore nature .jpeg';

/// Both Nature pages keep their shared photograph sharp in light and dark
/// mode. Keeping this shared prevents the two screens from drifting apart.
const bool exploreNatureBackgroundBlurEnabled = false;

/// The outer modal card. Follows the same per-mode card rule as everywhere
/// else — `DESIGN light.md` "Standard Cards: 16px", `DESIGN dark.md`
/// `rounded-xl` (24px) — one step up, because this is a full-page surface.
double _panelRadius(BuildContext context) => 28;

double _groupRadius(BuildContext context) => 28;

Color _hairline(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.white.withValues(alpha: AppColors.darkBorderOpacity)
    : Colors.white.withValues(alpha: 0.20);

Color _natureHeading(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return scheme.brightness == Brightness.dark ? Colors.white : scheme.onSurface;
}

Color _natureIcon(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.luminousMint
    : AppColors.actionNavy;

/// The icon drawn on each Place Type chip, matching the reference.
IconData placeTypeIcon(NaturePlaceType type) => switch (type) {
  NaturePlaceType.forest => Icons.forest_outlined,
  NaturePlaceType.mountain => Icons.terrain_rounded,
  NaturePlaceType.canyon => Icons.landscape_outlined,
  NaturePlaceType.park => Icons.park_outlined,
  NaturePlaceType.lake => Icons.water_outlined,
  NaturePlaceType.waterfall => Icons.water_drop_outlined,
  NaturePlaceType.river => Icons.waves_rounded,
  NaturePlaceType.museum => Icons.museum_outlined,
};

/// The icon drawn on each Facilities & Amenities chip.
IconData amenityIcon(NatureAmenity amenity) => switch (amenity) {
  NatureAmenity.parking => Icons.local_parking_rounded,
  NatureAmenity.restrooms => Icons.wc_rounded,
  NatureAmenity.restaurants => Icons.restaurant_rounded,
  NatureAmenity.cafes => Icons.local_cafe_outlined,
  NatureAmenity.mobileSignal => Icons.signal_cellular_alt_rounded,
  NatureAmenity.lodgingNearby => Icons.hotel_outlined,
  NatureAmenity.atmNearby => Icons.credit_card_rounded,
};

// --- Header ------------------------------------------------------------------

/// Card title and subtitle; page navigation sits outside this surface.
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.customizeFilters,
                  maxLines: 1,
                  style: TextStyle(
                    // headline-lg
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.02 * 28,
                    color: _natureHeading(context),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                l10n.customizeFiltersSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  height: 18 / 14,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Counter row -------------------------------------------------------------

/// "6 Filters selected" pill on the leading side, "Reset All" on the trailing.
class _CounterRow extends StatelessWidget {
  const _CounterRow({required this.count, required this.onReset});

  final int count;

  /// Null disables Reset All — there is nothing to reset at zero.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accent(context);
    final onAccent = isDark ? AppColors.darkOnPrimary : Colors.white;
    final heading = _natureHeading(context);

    return Row(
      children: [
        Flexible(
          child: GlassPanel(
            borderRadius: 999,
            depth: GlassDepth.top,
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Greyed out at zero, so the badge reads as "nothing
                    // selected" rather than a lit-up tick next to a zero.
                    color: count == 0
                        ? heading.withValues(alpha: 0.28)
                        : accent,
                  ),
                  child: Icon(Icons.check_rounded, size: 15, color: onAccent),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.filtersSelected(count),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: heading,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          enabled: onReset != null,
          label: l10n.resetAll,
          child: InkWell(
            onTap: onReset,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: onReset == null
                        ? heading.withValues(alpha: 0.38)
                        : heading,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.resetAll,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: onReset == null
                              ? heading.withValues(alpha: 0.38)
                              : heading,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Filter group ------------------------------------------------------------

/// One titled card of chips ("Place Type", "Facilities & Amenities").
class _FilterGroupCard extends StatelessWidget {
  const _FilterGroupCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final heading = _natureHeading(context);
    final iconColor = _natureIcon(context);

    return GlassPanel(
      borderRadius: _groupRadius(context),
      // L2: the fill stays identical to L1; only blur/depth steps up.
      depth: GlassDepth.middle,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor, width: 1.5),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      // headline-md
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: heading,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Wrap rather than a fixed grid: chip widths vary with their label,
          // and the labels change length in every language.
          Wrap(spacing: 6, runSpacing: 4, children: children),
        ],
      ),
    );
  }
}

/// One selectable filter chip: icon, label, and a check once selected.
class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 38dp drawn inside a 48dp tap target — compact without sacrificing the
  /// shared minimum-touch rule.
  static const double visualHeight = 34;

  @override
  Widget build(BuildContext context) {
    final content = AppColors.selectionAccent(context);

    return Semantics(
      button: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: visualHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: content),
                  const SizedBox(width: 5),
                  // Allowed to shrink rather than overflow: "Lodging nearby" and
                  // its Kurdish/Arabic translations are long.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: content,
                        ),
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.check_circle_rounded, size: 14, color: content),
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

// --- Apply button ------------------------------------------------------------

/// "Show 32 Places" — commits the draft and returns to the list.
///
/// Stays tappable at zero matches: applying a filter set that matches nothing
/// is a legitimate action, and the list screen already has an empty state with
/// a "Clear filters" escape. Disabling it here would strand the user on a
/// screen whose only other exit discards their work.
class _ShowPlacesButton extends StatelessWidget {
  const _ShowPlacesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final fill = AppColors.accent(context);
    final content = isDark ? AppColors.darkOnPrimary : Colors.white;

    return Semantics(
      button: true,
      label: l10n.showPlaces(count),
      child: Padding(
        // Reduce the full-width action by exactly 60 logical pixels.
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_rounded, size: 22, color: content),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l10n.showPlaces(count),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: content,
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
