import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'system_status_bar.dart';

/// The home screen's full-bleed background.
///
/// Per `DESIGN_SYSTEM.md` section 4, the layer order is:
/// 1. background photo (blurred)
/// 2. theme gradient overlay (55% opacity)
/// 3. page content and liquid-glass surfaces
///
/// This order is identical in Light and Dark modes.
class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, required this.child, this.dark});

  final Widget child;

  /// Overrides the ambient theme brightness (used by tests).
  final bool? dark;

  static const String imageAsset = 'assets/images/main screen back image.webp';

  /// The source photo is a very large JPEG. Decoded cost is
  /// `width × height × 4` bytes regardless of file size, so it is decoded
  /// down to the height actually drawn — the same rule the onboarding
  /// panorama follows.
  static int decodeHeightFor(BuildContext context) {
    final media = MediaQuery.of(context);
    return (media.size.height * media.devicePixelRatio).round();
  }

  /// Minimal global background blur per DESIGN_SYSTEM.md 4.3.
  /// Same value in Light and Dark modes.
  static const double blurSigma = AppColors.backgroundPhotoBlurSigma;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final gradientOpacity = AppColors.backgroundGradientOpacity;

    final photo = ImageFiltered(
      // Clamp so the blur doesn't sample transparency at the screen edges and
      // leave a lighter border — the treatment must be uniform, no vignette.
      imageFilter: ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
        tileMode: TileMode.clamp,
      ),
      child: Image.asset(
        imageAsset,
        fit: BoxFit.cover,
        cacheHeight: decodeHeightFor(context),
        // A missing asset must not leave a blank screen; the gradient below
        // already carries the brand colour on its own.
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );

    return SystemStatusBar(
      // Light mode draws navy text on a pale background, so the status-bar
      // icons must be dark; dark mode is the reverse.
      backdrop: StatusBarBackdrop.ofBrightness(
        isDark ? Brightness.dark : Brightness.light,
      ),
      // Home draws its own floating bar over the gesture area.
      navigationBar: SystemNavBarTreatment.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 (bottom): Background photo, blurred
          photo,

          // Layer 2 (middle): Theme gradient overlay at 55% opacity
          // Per DESIGN_SYSTEM.md 4.2: same layer order in Light and Dark
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        AppColors.darkGlassTop.withValues(
                          alpha: gradientOpacity,
                        ),
                        AppColors.darkGlassBottom.withValues(
                          alpha: gradientOpacity,
                        ),
                      ]
                    : [
                        AppColors.pageGradientTop.withValues(
                          alpha: gradientOpacity,
                        ),
                        AppColors.pageGradientBottom.withValues(
                          alpha: gradientOpacity,
                        ),
                      ],
              ),
            ),
          ),

          // Layer 3 (top): Page content
          child,
        ],
      ),
    );
  }
}
