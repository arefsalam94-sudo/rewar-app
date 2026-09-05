import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_panel.dart';
import 'liquid_glass_surface.dart';

enum AppLiquidGlassShape { roundedRectangle, pill, circle }

/// Kept only for source compatibility while the dedicated package migration
/// is handled separately. Both values use the authoritative glass recipe.
enum AppLiquidGlassQuality { standard, premium }

/// Compatibility facade over the app's single authoritative glass material.
///
/// It intentionally contains no package-specific refraction, thickness, or
/// chromatic-aberration values: those are not part of DESIGN_SYSTEM F.md.
class AppLiquidGlass extends StatelessWidget {
  const AppLiquidGlass({
    super.key,
    required this.child,
    this.shape = AppLiquidGlassShape.roundedRectangle,
    this.borderRadius = 28,
    this.padding = EdgeInsets.zero,
    this.dark,
    this.selected = false,
    this.tint,
    this.quality = AppLiquidGlassQuality.standard,
    this.interactive = false,
    this.onTap,
    this.useCanonicalGlass = false,
    this.optics = GlassOptics.standard,
    this.layer = GlassLayer.surface,
  });

  final Widget child;
  final AppLiquidGlassShape shape;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool? dark;
  final bool selected;

  /// Retained for call-site compatibility; the theme tint is authoritative.
  final Color? tint;

  /// Retained for call-site compatibility; it does not alter glass geometry.
  final AppLiquidGlassQuality quality;
  final bool interactive;
  final VoidCallback? onTap;

  /// Renders through the real `oc_liquid_glass` shader (its own dedicated
  /// glass group, well under the package's 4-surfaces-per-group cap) instead
  /// of [GlassPanel]'s `BackdropFilter` shell (`Design_system_CANONICAL.md`
  /// §9/§10: no stacked BackdropFilter, no painted border on real glass).
  /// Opt-in and defaulting to `false` — every existing caller (bottom nav,
  /// Home, Hotel, Car Rental, and the rest of the app) keeps its current,
  /// already-approved look; only Language/Login/Register call sites set this
  /// to `true`, per the canonical visual migration.
  final bool useCanonicalGlass;

  /// Which canonical calibration this surface renders with when
  /// [useCanonicalGlass] is `true`. Defaults to [GlassOptics.standard] so
  /// every existing card/panel call site is unaffected; small controls
  /// (fields, buttons, back button, toolbar/nav) pass
  /// [GlassOptics.compact] instead. Ignored when [useCanonicalGlass] is
  /// `false`.
  final GlassOptics optics;

  /// Nesting role when [useCanonicalGlass] is `true`. Defaults to
  /// [GlassLayer.surface] (a standalone real shader) so every existing
  /// call site is unaffected; pass [GlassLayer.embedded] for content that
  /// already sits inside another visible canonical glass surface, so the
  /// two don't stack into a second shader/blur/specular rim. Ignored when
  /// [useCanonicalGlass] is `false`.
  final GlassLayer layer;

  double get _effectiveRadius => switch (shape) {
    AppLiquidGlassShape.roundedRectangle => borderRadius,
    AppLiquidGlassShape.pill || AppLiquidGlassShape.circle => 1000,
  };

  ShapeBorder get _materialShape => switch (shape) {
    AppLiquidGlassShape.circle => const CircleBorder(),
    AppLiquidGlassShape.pill => const StadiumBorder(),
    AppLiquidGlassShape.roundedRectangle => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  };

  @override
  Widget build(BuildContext context) {
    Widget content = useCanonicalGlass
        ? (layer == GlassLayer.embedded
              ? _EmbeddedGlass(
                  borderRadius: _effectiveRadius,
                  padding: padding,
                  child: child,
                )
              : _CanonicalGlass(
                  borderRadius: _effectiveRadius,
                  padding: padding,
                  optics: optics,
                  child: child,
                ))
        : GlassPanel(
            borderRadius: _effectiveRadius,
            padding: padding,
            dark: dark,
            selected: selected,
            child: child,
          );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        shape: _materialShape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: _materialShape,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// The canonical real-glass shell for [AppLiquidGlass.useCanonicalGlass]:
/// one real `OCLiquidGlass` surface in its own dedicated group, tinted with
/// the canonical ambient `glass-tint` wash, no painted border, no stacked
/// `BackdropFilter`.
class _CanonicalGlass extends StatelessWidget {
  const _CanonicalGlass({
    required this.borderRadius,
    required this.padding,
    required this.child,
    this.optics = GlassOptics.standard,
  });

  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final GlassOptics optics;

  @override
  Widget build(BuildContext context) {
    // [glassSettingsForOptics] always resolves to
    // [kLiquidGlassSettingsCanonical] — [CanonicalGlassShell] is the one
    // place that constructs the shader group, so [optics] no longer needs
    // threading through to it.
    return CanonicalGlassShell(
      borderRadius: borderRadius,
      shadow: canonicalGlassShadow(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: AppColors.canonicalGlassBodyTint.withValues(
            alpha: AppColors.canonicalGlassBodyTintOpacity(context),
          ),
        ),
        child: Padding(
          padding: padding,
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    );
  }
}

/// Content embedded inside an existing visible canonical glass [surface]
/// ([GlassLayer.embedded]): no second `OCLiquidGlass` shader, no second
/// refraction, no specular rim, no second blur — only the same
/// [AppColors.canonicalGlassBodyTint] white at the lighter
/// [AppColors.canonicalGlassEmbeddedTintOpacity] as a subtle material
/// separation. This is not a second glass style; it is how content avoids
/// stacking a visible glass surface directly on top of another one.
class _EmbeddedGlass extends StatelessWidget {
  const _EmbeddedGlass({
    required this.borderRadius,
    required this.padding,
    required this.child,
  });

  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppColors.canonicalGlassBodyTint.withValues(
          alpha: AppColors.canonicalGlassEmbeddedTintOpacity(context),
        ),
      ),
      child: Padding(
        padding: padding,
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}
