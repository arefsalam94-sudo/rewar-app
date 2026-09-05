import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_liquid_glass.dart';
import 'glass_panel.dart';
import 'liquid_glass_surface.dart';

/// Circular frosted back button, shared across screens.
///
/// Always shows a left-pointing chevron and is meant to be placed at the
/// top-left by the caller — the back button stays on the left for every
/// language (LTR and RTL) by request.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({
    super.key,
    required this.onTap,
    this.dark,
    this.useAppLiquidGlass = false,
    this.useCanonicalGlass = false,
  });

  final VoidCallback onTap;

  /// Uses the Moonlit glass + a light chevron. Only Login passes true today.
  final bool? dark;
  final bool useAppLiquidGlass;

  /// Forwarded to [AppLiquidGlass.useCanonicalGlass] when
  /// [useAppLiquidGlass] is also `true`. See that flag's doc for scope.
  final bool useCanonicalGlass;

  /// The visible circle, unchanged from the approved designs.
  static const double visualSize = 36;

  /// The area that responds to a tap. 48dp is the minimum touch target on
  /// both iOS and Android; the circle itself stays [visualSize], so nothing
  /// moves on screen — only the region that accepts the tap grows.
  static const double tapTargetSize = 48;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: SizedBox.square(
        dimension: tapTargetSize,
        child: Stack(
          children: [
            // Pinned to the left edge (not centred) so the circle lands on
            // exactly the pixel it did before; the extra tappable margin
            // grows inwards, away from the screen edge. Left rather than
            // start because this button stays on the left in RTL too.
            Align(
              alignment: Alignment.centerLeft,
              child: IgnorePointer(
                child: SizedBox.square(
                  dimension: visualSize,
                  child: useAppLiquidGlass
                      ? AppLiquidGlass(
                          shape: AppLiquidGlassShape.circle,
                          borderRadius: 100,
                          dark: isDark,
                          quality: AppLiquidGlassQuality.standard,
                          interactive: true,
                          useCanonicalGlass: useCanonicalGlass,
                          // The back button is a compact control
                          // (Design_system_CANONICAL.md §9) — always the
                          // calmer profile, never per-screen.
                          optics: GlassOptics.compact,
                          child: Center(
                            child: Icon(
                              Icons.chevron_left,
                              color: isDark
                                  ? AppColors.luminousMint
                                  : AppColors.actionNavy,
                              size: 20,
                            ),
                          ),
                        )
                      : GlassPanel(
                          borderRadius: 100,
                          dark: isDark,
                          child: Center(
                            child: Icon(
                              Icons.chevron_left,
                              color: isDark
                                  ? AppColors.luminousMint
                                  : AppColors.actionNavy,
                              size: 20,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
