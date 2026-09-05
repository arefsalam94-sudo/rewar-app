import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

import '../theme/app_colors.dart';

/// Centralized, approved `oc_liquid_glass` shader configuration
/// (`Design-system-final.md` section 5). Every real liquid-glass surface in
/// the app must share this exact configuration — do not tune per call site.
const OCLiquidGlassSettings kLiquidGlassSettings = OCLiquidGlassSettings(
  blendPx: 4.0,
  refractStrength: -0.24,
  distortFalloffPx: 30.0,
  distortExponent: 4.0,
  blurRadiusPx: 2.0,
  specAngle: 4.0,
  specStrength: 0.5,
  specPower: 120.0,
  specWidth: 8.0,
  lightbandOffsetPx: 8.0,
  lightbandWidthPx: 20.0,
  lightbandStrength: 0.55,
  lightbandColor: Colors.white,
);

/// V3 calibration (`Design_system_final_v3.md` "V3 CALIBRATION").
/// Supersedes [kLiquidGlassSettings] where it conflicts — lower blur,
/// stronger specular/lightband. Opt-in via [LiquidGlassGroup.settings] so
/// screens still on the V2 calibration (Verification, Home) are unaffected;
/// only Language Selection uses this today.
const OCLiquidGlassSettings kLiquidGlassSettingsV3 = OCLiquidGlassSettings(
  blendPx: 4.0,
  refractStrength: -0.24,
  distortFalloffPx: 30.0,
  distortExponent: 4.0,
  blurRadiusPx: 1.0,
  specAngle: 4.0,
  specStrength: 0.60,
  specPower: 120.0,
  specWidth: 8.0,
  lightbandOffsetPx: 8.0,
  lightbandWidthPx: 20.0,
  lightbandStrength: 0.65,
  lightbandColor: Colors.white,
);

/// The one canonical Liquid Glass surface profile
/// (`Design_system_CANONICAL.md` §9). Every standalone visible glass
/// surface in the app — Language cards, the Login/Register form cards,
/// the bottom nav/toolbar, the theme toggle, the back button, any other
/// standalone glass control — renders with this exact configuration.
/// There is deliberately only one: blur/tint carry readability, refraction
/// is only a subtle Liquid Glass hint, and the edge/highlight stay soft
/// (no lens effect, no bright corners, no raised 3D rim, no wave/zig-zag).
const OCLiquidGlassSettings kLiquidGlassSettingsCanonical =
    OCLiquidGlassSettings(
      blendPx: 3.0,
      refractStrength: -0.010,
      distortFalloffPx: 14.0,
      distortExponent: 6.0,
      blurRadiusPx: 2.8,
      specAngle: 4.0,
      // specPower is the shader's Phong exponent (pow(dot(normal,light),
      // specPower)) — package doc: "higher = sharper". At 52 it only lit
      // the exact pixel where the rounded-corner normal matched the light
      // direction (dot≈1), reading as an isolated corner flare/blob: for
      // this app's shapes (specAngle=4.0 rad aims the two lights at
      // top-left/bottom-right), the adjoining straight edges sit at a
      // *constant* dot of ≈0.73–0.81, and pow(0.73,52)≈8e-8 — effectively
      // zero, so nothing reached the edges at all. Lowering the exponent
      // is what makes those edges glow instead of only the corner peak.
      specStrength: 0.65,
      specPower: 6.0,
      specWidth: 8.0,
      lightbandOffsetPx: 10.0,
      lightbandWidthPx: 18.0,
      lightbandStrength: 0.030,
      lightbandColor: Colors.white,
    );

/// Formerly selected between a "standard" and a "compact" surface
/// calibration. The app now has exactly one canonical surface profile
/// ([kLiquidGlassSettingsCanonical]) — [standard] and [compact] are kept
/// only so existing call sites don't need touching; both resolve to the
/// identical settings via [glassSettingsForOptics], so there is no longer
/// any visual difference between them.
enum GlassOptics { standard, compact }

/// Resolves a [GlassOptics] role to the canonical settings object. Both
/// values return the same [kLiquidGlassSettingsCanonical] — there is only
/// one surface renderer profile.
OCLiquidGlassSettings glassSettingsForOptics(GlassOptics optics) =>
    kLiquidGlassSettingsCanonical;

/// Nesting role for a canonical glass component
/// (`Design_system_CANONICAL.md` §9/§10): [surface] renders the real
/// `oc_liquid_glass` shader — blur, refraction, highlight, tint — and is
/// for glass that stands on its own (a card, a floating button, the
/// toolbar). [embedded] renders no shader at all — no second refraction,
/// no second specular rim, no second blur — only the same shared tint as a
/// subtle material separation, because the content already sits inside a
/// visible [surface] glass. A visible canonical glass surface must never be
/// rendered directly over another one; [embedded] is how content inside an
/// existing surface avoids doing that. This is a nesting role, not a
/// second glass style — embedded content still shares every tint/blur/edge
/// value with [surface].
enum GlassLayer { surface, embedded }

/// Wraps a region of the tree so every [LiquidGlassSurface] inside it shares
/// one shader pass. The renderer supports at most 4 registered surfaces per
/// group — group only the glass surfaces that belong together on screen.
class LiquidGlassGroup extends StatelessWidget {
  const LiquidGlassGroup({
    super.key,
    required this.child,
    this.settings = kLiquidGlassSettings,
  });

  final Widget child;

  /// Defaults to the standing V2 calibration so every existing call site
  /// (Verification, Home) keeps its current look unchanged. Pass
  /// [kLiquidGlassSettingsV3] to opt a screen into the V3 calibration.
  final OCLiquidGlassSettings settings;

  @override
  Widget build(BuildContext context) {
    return OCLiquidGlassGroup(settings: settings, child: child);
  }
}

/// A single real liquid-glass surface, rendered by the approved
/// `oc_liquid_glass` shader. Must be used inside an ancestor
/// [LiquidGlassGroup].
///
/// The shape passed to the shader always stays transparent — this widget
/// never tints it. Any selection/emphasis state belongs in a decoration
/// around [child] instead, so the shader configuration never varies by state.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.shadow,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double borderRadius;
  final BoxShadow? shadow;

  /// Interior padding, applied inside the glass shape (the shader itself
  /// only ever wraps [child] tightly).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return OCLiquidGlass(
      color: Colors.transparent,
      borderRadius: borderRadius,
      shadow: shadow,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The large-card radius the canonical calibration
/// ([kLiquidGlassSettingsCanonical]) was tuned and approved against —
/// Settings/Help & Support/Login/Register cards, and every other full-size
/// canonical panel, all use this radius today. [canonicalGlassSettingsFor]
/// treats it as the "1.0 scale" reference: a surface built at this radius
/// (or larger — a pill/circle control's clamped sentinel radius included)
/// renders with the approved values completely unscaled.
const double kCanonicalGlassReferenceRadius = 28.0;

/// Floor for [canonicalGlassSettingsFor]'s size scale, so an unusually
/// tight radius still reads as glass rather than losing its highlight
/// entirely. Comfortably below every real radius in use today (the
/// smallest is 12, which already scales to ~0.43).
const double _kCanonicalGlassMinScale = 0.4;

/// Scales [kLiquidGlassSettingsCanonical]'s *spatial* (pixel-distance)
/// parameters to the surface's own [borderRadius], leaving every
/// intensity/angle/color parameter untouched.
///
/// The raw shader settings are absolute pixel distances (`Design-system-
/// final.md` §5's `specWidth`, `lightbandWidthPx`, …). Applied unscaled to
/// every surface regardless of size, an 18px lightband reads as a soft
/// sliver on a ~340px-wide card but as a hard, disproportionate strip on a
/// 56px-tall field — the same raw numbers, wildly different visual weight.
/// This is the one place that correction happens: a pure function of the
/// radius every canonical call site already declares to match its own
/// visual scale (`Design_system_CANONICAL.md` §9), not a per-component
/// profile — there is still exactly one [kLiquidGlassSettingsCanonical],
/// just applied at a size-appropriate scale. At
/// [kCanonicalGlassReferenceRadius] or above (every approved reference
/// surface — Settings/Help/Login/Register cards, the pill-shaped toolbar,
/// a circular control's clamped sentinel radius) this returns the exact
/// unmodified constant, so none of them change.
///
/// Left unscaled, because they represent strength/character rather than a
/// physical distance: [OCLiquidGlassSettings.refractStrength],
/// `distortExponent`, `blurRadiusPx`, `specAngle`, `specStrength`,
/// `specPower`, `lightbandStrength`, `lightbandColor`.
OCLiquidGlassSettings canonicalGlassSettingsFor(double borderRadius) {
  final scale = (borderRadius / kCanonicalGlassReferenceRadius).clamp(
    _kCanonicalGlassMinScale,
    1.0,
  );
  if (scale == 1.0) return kLiquidGlassSettingsCanonical;
  return kLiquidGlassSettingsCanonical.copyWith(
    blendPx: kLiquidGlassSettingsCanonical.blendPx * scale,
    distortFalloffPx: kLiquidGlassSettingsCanonical.distortFalloffPx * scale,
    specWidth: kLiquidGlassSettingsCanonical.specWidth * scale,
    lightbandOffsetPx: kLiquidGlassSettingsCanonical.lightbandOffsetPx * scale,
    lightbandWidthPx: kLiquidGlassSettingsCanonical.lightbandWidthPx * scale,
  );
}

/// The one shared shell every canonical Liquid Glass surface renders
/// through: a dedicated [LiquidGlassGroup] running the size-normalized
/// canonical settings ([canonicalGlassSettingsFor]) around a single
/// [LiquidGlassSurface] (`Design_system_CANONICAL.md` §9).
///
/// [AppLiquidGlass]'s canonical branch and [RecessedLiquidGlassField]'s
/// `GlassLayer.surface` branch both build their content on top of this one
/// widget instead of each hand-rolling their own `LiquidGlassGroup` +
/// `LiquidGlassSurface` pair — there is exactly one place that constructs
/// the real shader group for a canonical surface.
class CanonicalGlassShell extends StatelessWidget {
  const CanonicalGlassShell({
    super.key,
    required this.borderRadius,
    required this.child,
    this.shadow,
  });

  final double borderRadius;
  final Widget child;

  /// The surface's drop shadow, or `null` for a surface that doesn't float
  /// (e.g. fields stacked closer together than the shadow's own blur
  /// radius — see [RecessedLiquidGlassField.dropShadow]).
  final BoxShadow? shadow;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassGroup(
      settings: canonicalGlassSettingsFor(borderRadius),
      child: LiquidGlassSurface(
        borderRadius: borderRadius,
        shadow: shadow,
        child: child,
      ),
    );
  }
}

/// The canonical floating-surface shadow recipe (`Design_system_CANONICAL.md`
/// §9) — a shared function so every [CanonicalGlassShell] caller that wants
/// the standard drop shadow gets the exact same values, rather than each
/// call site reconstructing this `BoxShadow` itself.
BoxShadow canonicalGlassShadow(BuildContext context) {
  final shadowColor = AppColors.glassShadowColor(context);
  return BoxShadow(
    color: shadowColor.withValues(alpha: AppColors.glassShadowOpacityV3),
    offset: const Offset(0, AppColors.glassFloatingShadowOffsetY),
    blurRadius: AppColors.glassFloatingShadowBlurRadius,
    spreadRadius: AppColors.glassFloatingShadowSpreadRadius,
  );
}
