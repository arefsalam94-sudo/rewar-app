import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'adaptive_glass_foreground.dart';
import 'liquid_glass_surface.dart';

/// The four destinations in the floating bottom bar.
///
/// [map] opens the app's native Google Map screen. The remaining destinations
/// are wired to their real behaviour as they are built.
enum HomeNavTab { home, trips, map, saved }

/// Floating "liquid glass" bottom navigation bar.
///
/// `DESIGN light.md` → Components → Navigation: *"A floating bottom
/// navigation bar using the Liquid Glass style, with Navy icons for the
/// active state."* The selected item is lifted out of the row into a filled
/// circle with a slightly larger icon, as drawn in the reference screenshot.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    this.dark,
    this.adaptiveBackdropKey,
    this.adaptiveAnchorKey,
    this.adaptiveActivity,
  });

  final HomeNavTab current;
  final ValueChanged<HomeNavTab> onSelect;
  final bool? dark;

  /// Together with [adaptiveAnchorKey], enables
  /// [AdaptiveGlassForeground] for this bar's neutral/inactive icons and
  /// labels — see that widget's doc. Both must be provided by the same
  /// caller (typically the hosting screen) or the bar falls back to its
  /// previous static theme-based neutral color. Selected/active styling is
  /// never affected by this.
  final GlobalKey? adaptiveBackdropKey;

  /// See [adaptiveBackdropKey].
  final GlobalKey? adaptiveAnchorKey;

  /// Optional scroll/movement signal forwarded to
  /// [AdaptiveGlassForeground.activity] so sampling is throttled while the
  /// background is moving and idle otherwise.
  final Listenable? adaptiveActivity;

  /// Overall bar height. Fixed so it looks identical on every device, per
  /// the "Sizes that must stay identical" table in `DESIGN_SYSTEM.md`.
  static const double barHeight = 74;

  /// Overall width of the floating bar on screens wide enough to show it.
  static const double barWidth = 311;

  /// Diameter of the filled circle behind the selected icon.
  static const double selectedCircleSize = 48;

  static const double _iconSize = 22;

  /// "A little bit bigger than the others" — the selected icon only.
  static const double _selectedIconSize = 24;

  /// The bar in its floating position, ready to drop into a [Stack].
  ///
  /// Shared rather than repeated per screen so the pill lands on exactly the
  /// same pixels wherever the bar is kept visible — moving between Home and a
  /// bar destination must not shift it.
  ///
  /// Returns a [PositionedDirectional] directly (not wrapped in a widget of
  /// its own) because [Stack] only honours positioning on its immediate
  /// children.
  ///
  /// The adaptive arguments are optional: a screen that wires up a backdrop
  /// and an anchor gets the sampled neutral foreground color, and one that
  /// does not falls back to the static theme color.
  static Widget floating({
    required BuildContext context,
    required HomeNavTab current,
    required ValueChanged<HomeNavTab> onSelect,
    bool? dark,
    GlobalKey? adaptiveBackdropKey,
    GlobalKey? adaptiveAnchorKey,
    Listenable? adaptiveActivity,
  }) {
    return PositionedDirectional(
      start: 0,
      end: 0,
      bottom: MediaQuery.paddingOf(context).bottom + 12,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: barWidth),
          child: SizedBox(
            width: double.infinity,
            child: HomeBottomNav(
              current: current,
              onSelect: onSelect,
              dark: dark,
              adaptiveBackdropKey: adaptiveBackdropKey,
              adaptiveAnchorKey: adaptiveAnchorKey,
              adaptiveActivity: adaptiveActivity,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final shadowColor = isDark
        ? AppColors.darkGlassShadowColor
        : AppColors.lightGlassShadowColor;
    final shadowOpacity = isDark
        ? AppColors.darkGlassShadowOpacity
        : AppColors.lightGlassShadowOpacity;
    // Previous static neutral color — used as-is when adaptive sampling
    // isn't wired up, and as the seed/fallback so there is no flash of the
    // wrong color before the first real sample resolves.
    final staticNeutralColor = isDark
        ? AppColors.darkOnSurfaceSecondary
        : AppColors.actionNavy;

    Widget buildRow(Color neutralColor) {
      return Row(
        children: [
          _NavItem(
            tab: HomeNavTab.home,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: l10n.navHome,
            current: current,
            onSelect: onSelect,
            dark: isDark,
            neutralColor: neutralColor,
          ),
          _NavItem(
            tab: HomeNavTab.trips,
            // Deliberately identical to the drawer's My Bookings row — same
            // icon, same label, same destination, so the two entry points
            // don't read as two different places.
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            label: l10n.myBookings,
            current: current,
            onSelect: onSelect,
            dark: isDark,
            neutralColor: neutralColor,
          ),
          _NavItem(
            tab: HomeNavTab.map,
            icon: Icons.map_outlined,
            selectedIcon: Icons.map_rounded,
            label: l10n.navMap,
            current: current,
            onSelect: onSelect,
            dark: isDark,
            neutralColor: neutralColor,
          ),
          _NavItem(
            tab: HomeNavTab.saved,
            icon: Icons.favorite_border_rounded,
            selectedIcon: Icons.favorite_rounded,
            label: l10n.navSaved,
            current: current,
            onSelect: onSelect,
            dark: isDark,
            neutralColor: neutralColor,
          ),
        ],
      );
    }

    final backdropKey = adaptiveBackdropKey;
    final anchorKey = adaptiveAnchorKey;
    // Same shared canonical renderer every other standalone surface uses
    // (`Design_system_CANONICAL.md` §9) — identical to Language/Login/
    // Register/back button/theme toggle. No separate toolbar-specific
    // settings object, and no separate hand-built `LiquidGlassGroup` +
    // `LiquidGlassSurface` pair.
    final content = CanonicalGlassShell(
      // Pill-shaped, as drawn. Half the height gives a true pill regardless
      // of how the bar is sized.
      borderRadius: barHeight / 2,
      shadow: BoxShadow(
        color: shadowColor.withValues(alpha: shadowOpacity),
        offset: const Offset(0, AppColors.glassFloatingShadowOffsetY),
        blurRadius: AppColors.glassFloatingShadowBlurRadius,
        spreadRadius: AppColors.glassFloatingShadowSpreadRadius,
      ),
      // Same shared canonical body tint every other standalone surface
      // uses (`Design_system_CANONICAL.md` §9) — without it the bar was
      // the one canonical surface with no readability wash, which is
      // what read as "too transparent/busy" against complex photography.
      // Fills the pill edge-to-edge (Design_system_CANONICAL.md §9): the
      // horizontal content padding is applied *inside* this tint, not
      // passed to the shader shape itself, so there's no untinted gap
      // between the tint and the shader's own edge exposing a raw,
      // unmuted specular strip along the pill's flat sides.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(barHeight / 2),
          color: AppColors.canonicalGlassBodyTint.withValues(
            alpha: AppColors.canonicalGlassBodyTintOpacity(context),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            height: barHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 288),
                // Neutral icon/label color: adaptive (one shared color for
                // the whole bar) when both keys are wired up by the host
                // screen, otherwise the previous static theme color.
                // Selected/active styling never goes through this.
                child: (backdropKey != null && anchorKey != null)
                    ? AdaptiveGlassForeground(
                        backdropKey: backdropKey,
                        anchorKey: anchorKey,
                        initialColor: staticNeutralColor,
                        activity: adaptiveActivity,
                        builder: (context, neutralColor, _) =>
                            buildRow(neutralColor),
                      )
                    : buildRow(staticNeutralColor),
              ),
            ),
          ),
        ),
      ),
    );

    return anchorKey != null
        ? AdaptiveGlassForegroundAnchor(anchorKey: anchorKey, child: content)
        : content;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.current,
    required this.onSelect,
    required this.dark,
    required this.neutralColor,
  });

  final HomeNavTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final HomeNavTab current;
  final ValueChanged<HomeNavTab> onSelect;
  final bool dark;

  /// Shared adaptive (or static fallback) neutral color for the unselected
  /// icon and the label — the same value for every item in the bar, so
  /// the whole toolbar always reads as one color, not per-item colors.
  final Color neutralColor;

  @override
  Widget build(BuildContext context) {
    final selected = tab == current;
    // Selected/active styling is untouched: still theme-based, never
    // adaptive.
    // Dark mode fills the circle with Luminous Mint and puts *dark* text on
    // it — the one place dark-on-light is correct (`DESIGN dark.md`).
    final circleColor = dark ? AppColors.luminousMint : AppColors.actionNavy;
    final onCircle = dark ? AppColors.darkOnPrimary : Colors.white;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: () => onSelect(tab),
          borderRadius: BorderRadius.circular(HomeBottomNav.barHeight / 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: selected ? HomeBottomNav.selectedCircleSize : 25,
                height: selected ? HomeBottomNav.selectedCircleSize : 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? circleColor : Colors.transparent,
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: selected
                      ? HomeBottomNav._selectedIconSize
                      : HomeBottomNav._iconSize,
                  color: selected ? onCircle : neutralColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: 0.05 * 10,
                      color: neutralColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
