import 'package:flutter/material.dart';

import 'glass_panel.dart';

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
    Widget content = GlassPanel(
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
