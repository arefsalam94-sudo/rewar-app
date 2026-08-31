import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Shared auth-screen background: the mountain photo under the green gradient
/// wash. Per `DESIGN_SYSTEM.md` section 4:
/// - Layer order: photo (blurred) → gradient overlay (45% opacity) → content
/// - Gradient opacity: 45% (0.45) in both light and dark
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
    final photo = _MaybeBlurred(sigma: photoBlurSigma, child: photoWidget);

    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Color(0xFF0C1F1F).withValues(alpha: overlayOpacity),
                  Color(0xFF062C32).withValues(alpha: overlayOpacity),
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
