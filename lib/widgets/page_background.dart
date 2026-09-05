import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Shared auth-screen background: the mountain photo under the green gradient
/// wash. Per `DESIGN_SYSTEM.md` section 4:
/// - Layer order: photo (blurred) → gradient overlay (45% opacity) → content
/// - Gradient opacity: 55% (0.55) in both light and dark
/// - Photo blur: σ = 2 in both light and dark (minimal, uniform treatment)
class PageBackground extends StatelessWidget {
  const PageBackground({
    super.key,
    required this.child,
    this.dark,
    this.imageAsset = 'assets/images/Login.webp',
    this.blurSigma,
    this.gradientOpacity,
  });

  final Widget child;

  /// Which photo sits under the gradient wash. Defaults to the shared auth
  /// background; Account Setup passes its own.
  final String imageAsset;

  /// Background photo blur sigma (σ). Defaults to the design standard 2.
  /// Per DESIGN_SYSTEM.md 4.3: same value in both light and dark modes.
  /// This value overrides the default; use with caution to maintain design
  /// consistency. Most screens should not override this.
  final double? blurSigma;

  /// Background gradient overlay opacity. Defaults to the design standard 0.45.
  /// Per DESIGN_SYSTEM.md 4.4: same value in both light and dark modes,
  /// acceptable range 0.42–0.46. This value overrides the default; use with
  /// caution to maintain design consistency. Most screens should not override
  /// this.
  final double? gradientOpacity;

  /// Switches between light and dark themes. Defaults to ambient brightness.
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final photoBlurSigma = blurSigma ?? AppColors.backgroundPhotoBlurSigma;
    final overlayOpacity =
        (gradientOpacity ?? AppColors.backgroundGradientOpacity).clamp(
          0.0,
          1.0,
        );

    final photoWidget = Image.asset(
      imageAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: isDark
            ? AppColors.darkForestFloor
            : AppColors.pageGradientBottom,
      ),
    );
    // Global saturation normalization — one fixed value for every screen
    // (`AppColors.backgroundImageSaturation`), applied before the blur and
    // before the existing canonical gradient. Source photos vary widely in
    // hue/saturation (muted mountain photography vs. a saturated blue sky
    // photo); this is a controlled test of whether one shared value can
    // bring them into a comparable range without a per-screen correction.
    final normalizedPhoto = ColorFiltered(
      colorFilter: ColorFilter.matrix(
        _saturationMatrix(AppColors.backgroundImageSaturation),
      ),
      child: photoWidget,
    );
    final photo = _MaybeBlurred(sigma: photoBlurSigma, child: normalizedPhoto);

    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.darkGlassTop.withValues(alpha: overlayOpacity),
                  AppColors.darkGlassBottom.withValues(alpha: overlayOpacity),
                ]
              : [
                  AppColors.pageGradientTop.withValues(alpha: overlayOpacity),
                  AppColors.pageGradientBottom.withValues(
                    alpha: overlayOpacity,
                  ),
                ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 (bottom): Background photo, blurred per DESIGN_SYSTEM.md
          photo,
          // Layer 2 (middle): Theme gradient overlay at design-standard opacity
          gradient,
          // Layer 3 (top): Page content
          child,
        ],
      ),
    );
  }
}

/// Standard luminance-preserving saturation color matrix (the same formula
/// as Android's `ColorMatrix.setSaturation` / the classic W3C/graphics
/// "saturate" matrix), for [ColorFilter.matrix].
///
/// `saturation == 1.0` returns the identity matrix (image unchanged);
/// `saturation == 0.0` desaturates to grayscale via the Rec. 601 luminance
/// weights (R 0.213, G 0.715, B 0.072). Only the RGB rows are scaled toward
/// that luminance — brightness, contrast, hue, and the alpha row/column are
/// left untouched, so this changes saturation only.
List<double> _saturationMatrix(double saturation) {
  final inv = 1 - saturation;
  const lumR = 0.213;
  const lumG = 0.715;
  const lumB = 0.072;
  final r = lumR * inv;
  final g = lumG * inv;
  final b = lumB * inv;
  return <double>[
    r + saturation, g, b, 0, 0,
    r, g + saturation, b, 0, 0,
    r, g, b + saturation, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Applies gaussian blur to the background photo uniformly in both light
/// and dark modes. Per DESIGN_SYSTEM.md 4.3, the blur keeps the image
/// softly integrated while maintaining clarity.
class _MaybeBlurred extends StatelessWidget {
  const _MaybeBlurred({required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma <= 0) return child;
    return ImageFiltered(
      // Clamp, so the blur doesn't sample transparency at the screen edges
      // and leave a lighter border — the design file requires a uniform
      // treatment with no vignette.
      imageFilter: ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.clamp,
      ),
      child: child,
    );
  }
}
