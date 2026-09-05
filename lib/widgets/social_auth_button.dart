import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_liquid_glass.dart';
import 'liquid_glass_surface.dart';

/// Frosted social-auth button (icon + label) shared by Login and Register,
/// so both render through the exact same canonical Liquid Glass call site
/// rather than two hand-maintained copies that could drift apart.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dark,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return AppLiquidGlass(
      borderRadius: 14,
      dark: dark,
      quality: AppLiquidGlassQuality.standard,
      interactive: true,
      useCanonicalGlass: true,
      // Social buttons are a compact control (Design_system_CANONICAL.md
      // §9) — the calmer profile, not the large-surface baseline.
      optics: GlassOptics.compact,
      // Its own real canonical glass surface (the default `GlassLayer.
      // surface`), matching Register's approved buttons — not `embedded`,
      // which would flatten it into the outer card's shader.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8),
                // Two of these sit side by side, so each gets under half the
                // screen. Without this the label pushes the row past its
                // width on a narrow phone, or once the system font is
                // enlarged. Scaling down keeps the whole word readable,
                // where clipping would leave "Gm…".
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        // `socialAuthContent`.
                        color: AppColors.socialAuthContent(context),
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
