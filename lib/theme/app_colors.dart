import 'package:flutter/material.dart';

/// Brand color tokens for the app.
///
/// These are the single source of truth for brand colors so no widget
/// hardcodes a raw hex value (see CLAUDE.md rule on semantic tokens).
/// The splash gradient is a fixed brand asset — intentionally identical
/// in light and dark mode.
class AppColors {
  AppColors._();

  /// Splash background gradient — light mint at the top…
  static const Color splashGradientTop = Color(0xFFE1F4E5);

  /// …fading to deep Kurdistan green at the bottom.
  static const Color splashGradientBottom = Color(0xFF187C64);

  /// Splash title text (over the gradient).
  static const Color splashText = Colors.white;

  /// Base page gradient (light mint → deep green), used as an overlay on
  /// top of the background photo on the Language screen. Same stops as the
  /// splash, from `DESIGN light.md` ("Base Background").
  static const Color pageGradientTop = Color(0xFFE1F4E5);
  static const Color pageGradientBottom = Color(0xFF187C64);

  /// Action / icon navy. `DESIGN light.md` prose reserves this dark navy
  /// for primary interactive elements and icons (e.g. the globe icon).
  /// Note: this differs from the `tertiary` token (#3F5774) in the same
  /// file — using the prose value here because it matches the mockup.
  static const Color actionNavy = Color(0xFF0E2A44);

  // --- Dark mode ("Lush Horizon: Moonlit", from `DESIGN dark.md`) ---------
  //
  // Dark mode is a different design language, not a recolour of light mode:
  // mint-filled buttons instead of navy, heavier blur, deeper radii. These
  // tokens are currently used by the Login screen only.

  /// "Forest floor" base — the solid canvas everything else sits on.
  static const Color darkForestFloor = Color(0xFF062C32);

  /// Liquid-glass gradient: top…
  static const Color darkGlassTop = Color(0xFF0C1F1F);

  /// …to bottom.
  static const Color darkGlassBottom = Color(0xFF062C32);

  /// Luminous mint — dark mode's primary action colour, the counterpart to
  /// [actionNavy]. Buttons filled with this take *dark* text.
  static const Color luminousMint = Color(0xFF2AF598);

  /// Text/icons drawn **on** [luminousMint] — the `on-primary` token.
  ///
  /// `DESIGN dark.md` → Text & Legibility: *"Text on Luminous Mint buttons:
  /// dark (`on-primary` #00391E) — this is the one place dark text is
  /// correct, because the background is bright."*
  ///
  /// Distinct from [darkForestFloor] (#062C32), which is the *background*
  /// canvas, not a text colour.
  static const Color darkOnPrimary = Color(0xFF00391E);

  /// Dark mode's `on-surface-secondary` / `on-surface-muted` / `heading` /
  /// `on-glass` tokens. **All four are pure white** — the design file sets
  /// every text-capable token to `#ffffff` deliberately, so that whichever
  /// one a widget reaches for, the text comes out readable.
  static const Color darkOnSurfaceSecondary = Color(0xFFFFFFFF);

  /// Opacity for secondary / helper text in dark mode ("Or", "Don't have an
  /// account?", captions, field hints). `DESIGN dark.md` specifies a
  /// **70-80%** band — softer than a heading, but plainly readable.
  ///
  /// Headings and body text are *not* covered by this: they are white at
  /// 100%. "A heading that looks dim is a bug, not a style."
  static const double darkSecondaryTextOpacity = 0.75;

  /// Placeholder text inside dark inputs — `DESIGN dark.md` specifies
  /// exactly **60%**.
  static const double darkHintOpacity = 0.60;

  /// Opacity for white borders and strokes in dark mode. `DESIGN dark.md`:
  /// *"When `outline` is used for its actual purpose — a border or stroke —
  /// it must be applied at 10-15% opacity. A solid, fully opaque white
  /// border is wrong."*
  static const double darkBorderOpacity = 0.14;

  /// Primary interactive accent for the active appearance.
  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? luminousMint
      : actionNavy;

  /// Heading / title colour for a screen's own copy.
  ///
  /// Light mode uses `on-surface` (`#1B1B1B`) — `DESIGN_LIGHT F.md` sets
  /// `text-heading` to that near-black, not to [actionNavy].
  /// Dark mode is pure white at 100% — `DESIGN dark.md`: *"if a heading looks
  /// dim, it is a bug."*
  ///
  /// The Home screen keeps its own private copy of this logic (it predates
  /// this accessor); new screens should use this one.
  static Color heading(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1B1B1B);

  /// Returns the correct helper/secondary text colour for the current
  /// theme, so the dark-mode 70-80% rule is applied in one place instead of
  /// being re-derived (and mis-derived) per widget.
  static Color secondaryText(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? darkOnSurfaceSecondary.withValues(alpha: darkSecondaryTextOpacity)
        : scheme.onSurfaceVariant;
  }

  /// Same, for helper text drawn directly on the background photo rather
  /// than on a glass surface (see [onPhotoBackground]).
  static Color onPhotoSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkOnSurfaceSecondary.withValues(alpha: darkSecondaryTextOpacity)
        : onPhotoBackground;
  }

  /// `step-connector-dot` — the dots between step circles in a multi-step
  /// flow (`DESIGN_SYSTEM.md` 14).
  ///
  /// Both theme files define it as the secondary text colour at 45%: white in
  /// dark, `on-surface-variant` (`#3E4945`) in light. Read from the scheme
  /// rather than typed as a hex, so the two cannot drift.
  static Color stepConnectorDot(BuildContext context) =>
      (_isDark(context)
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant)
          .withValues(alpha: 0.45);

  /// `step-active-ring` / `step-complete-fill` — the accent a multi-step
  /// indicator draws its state in (`DESIGN_SYSTEM.md` 14).
  ///
  /// **`primary-container`, not [actionNavy].** Both theme files are explicit:
  /// the approved checkout references draw the ring and the completed fill in
  /// the palette green (`#187C64` light / `#2AF598` dark), while `action` is
  /// the navy reserved for primary buttons. Using the button colour here was a
  /// bug — the two are different tokens and only coincide in dark mode.
  static Color stepAccent(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer;

  /// Content drawn on top of [stepAccent] when a step is filled — the check
  /// glyph on a completed step.
  static Color onStepAccent(BuildContext context) =>
      _isDark(context) ? darkOnPrimary : Colors.white;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Status pills reuse the approved semantic-state tokens.
  static Color statusSuccessFill(BuildContext context) =>
      _isDark(context) ? luminousMint : pageGradientBottom;

  static Color statusSuccessContent(BuildContext context) =>
      _isDark(context) ? darkOnPrimary : Colors.white;

  static Color statusInfoFill(BuildContext context) =>
      _isDark(context) ? const Color(0xFFAACCD4) : const Color(0xFF3F5774);

  static Color statusInfoContent(BuildContext context) =>
      _isDark(context) ? const Color(0xFF12353B) : Colors.white;

  /// Fill for a negative status pill (Cancelled).
  ///
  /// Deliberately reuses the existing `error` scheme tokens rather than adding
  /// a fifth colour — a cancelled booking *is* the error state of a booking,
  /// and the palette already answers this correctly in both modes.
  static Color statusErrorFill(BuildContext context) =>
      Theme.of(context).colorScheme.errorContainer;

  /// Text/icon drawn on [statusErrorFill].
  static Color statusErrorContent(BuildContext context) =>
      Theme.of(context).colorScheme.onErrorContainer;

  /// Text drawn **directly on the photo background**, outside any glass
  /// surface — e.g. the Register screen's "Or" divider and its
  /// "Already have an Account?" line.
  ///
  /// A semantic token rather than a bare `Colors.white` so the intent is
  /// explicit: the normal `onSurfaceVariant` (`#3E4945` in light mode) is a
  /// dark grey chosen for legibility *on a surface*, and it loses contrast
  /// badly against the deep green at the bottom of the page gradient.
  ///
  /// Correct in both modes — dark mode's `on-surface-variant` is already
  /// pure white per `DESIGN dark.md`.
  static const Color onPhotoBackground = Colors.white;

  // --- Glass design tokens (from DESIGN_SYSTEM.md section 5) ----------------
  //
  // Base liquid-glass properties (identical structure in light and dark).
  // Only theme-specific tints and colors differ.

  /// Background photo blur sigma value (same in light and dark).
  /// Per DESIGN_SYSTEM.md 4.3: minimal global background blur.
  static const double backgroundPhotoBlurSigma = 2.0;

  /// Background gradient overlay opacity (same in light and dark).
  /// Per DESIGN_SYSTEM.md 4.4: 0.45, acceptable range 0.42–0.46.
  static const double backgroundGradientOpacity = 0.45;

  /// Base glass backdrop blur (L1 — outer card / main glass surface).
  /// Per DESIGN_SYSTEM.md 5.1 and 6.1.
  static const double glassBlurBaseL1 = 18.0;

  /// Middle-layer glass blur (L2 — group card / sheet on L1).
  /// Per DESIGN_SYSTEM.md 6.1.
  static const double glassBlurMiddleL2 = 22.0;

  /// Top-layer glass blur (L3 — glass control / chip on L2).
  /// Per DESIGN_SYSTEM.md 6.1.
  static const double glassBlurTopL3 = 26.0;

  /// Base glass neutral edge thickness (pixels).
  /// Per DESIGN_SYSTEM.md 5.1: 1px soft light-catching edge.
  static const double glassEdgeThickness = 1.0;

  /// Glass sheen: vertical gradient approximately 24% → 8%.
  /// Per DESIGN_SYSTEM.md 5.1. These are opacity values for the top and
  /// bottom of the sheen, used when painting a vertical gradient overlay.
  static const double glassSheenTopOpacity = 0.24;
  static const double glassSheenBottomOpacity = 0.08;

  /// Soft floating shadow geometry.
  /// Per DESIGN_SYSTEM.md 5.3.
  static const double glassFloatingShadowOffsetY = 6.0;
  static const double glassFloatingShadowBlurRadius = 22.0;
  static const double glassFloatingShadowSpreadRadius = 0.0;
  static const double glassFloatingShadowOpacity = 0.14;

  /// Inter-layer shadow opacity (L2 → L1, L3 → L2).
  /// Per DESIGN_SYSTEM.md 6.2.
  static const double glassInterLayerShadowOpacity = 0.14;

  /// Selection state tint strength.
  /// Per DESIGN_SYSTEM.md 7.2: approximately 14–18%.
  static const double selectionTintOpacity = 0.16;

  /// Selection stroke width and opacity.
  /// Per DESIGN_SYSTEM.md 7.2 and 12.1.
  static const double selectionStrokeWidth = 1.5;
  static const double selectionStrokeOpacity = 0.90;

  // --- Light mode glass tint tokens (from DESIGN_LIGHT.md section 3) --------

  /// Light mode base glass tint color.
  static const Color lightGlassTintBase = Color(0xFFE1F4E5);

  /// Light mode base glass tint opacity.
  /// Per DESIGN_LIGHT.md: subtle theme glass tint at approximately 6%.
  static const double lightGlassTintOpacity = 0.06;

  /// Light mode glass shadow color.
  static const Color lightGlassShadowColor = Color(0xFF0E2A44);

  /// Light mode glass shadow opacity.
  static const double lightGlassShadowOpacity = 0.14;

  /// Light mode glass inner shadow color.
  static const Color lightGlassInnerShadowColor = Color(0xFF0E2A44);

  /// Light mode glass inner shadow opacity.
  static const double lightGlassInnerShadowOpacity = 0.14;

  /// Light mode glass inner highlight color (opposite edge of inset shadow).
  /// Per DESIGN_SYSTEM.md 8.3: inner highlight to show depth.
  static const Color lightGlassInnerHighlightColor = Color(0xFFFFFFFF);

  /// Light mode glass inner highlight opacity.
  /// Per DESIGN_SYSTEM.md 8.3: approximately 6–10%.
  static const double lightGlassInnerHighlightOpacity = 0.08;

  /// Light mode selection accent color.
  static const Color lightSelectionAccent = Color(0xFF00624D);

  /// Light mode selection tint color.
  static const Color lightSelectionTint = Color(0xFFE1F4E5);

  // --- Dark mode glass tint tokens (from DESIGN_DARK.md section 3) ---------

  /// Dark mode base glass tint color.
  static const Color darkGlassTintBase = Color(0xFF0C1F1F);

  /// Dark mode base glass tint opacity.
  /// Per DESIGN_DARK.md: subtle theme glass tint at approximately 6%.
  static const double darkGlassTintOpacity = 0.06;

  /// Dark mode glass shadow color.
  static const Color darkGlassShadowColor = Color(0xFF000000);

  /// Dark mode glass shadow opacity.
  static const double darkGlassShadowOpacity = 0.14;

  /// Dark mode glass inner shadow color.
  static const Color darkGlassInnerShadowColor = Color(0xFF000000);

  /// Dark mode glass inner shadow opacity.
  static const double darkGlassInnerShadowOpacity = 0.14;

  /// Dark mode glass inner highlight color (opposite edge of inset shadow).
  /// Per DESIGN_SYSTEM.md 8.3: inner highlight to show depth.
  static const Color darkGlassInnerHighlightColor = Color(0xFFFFFFFF);

  /// Dark mode glass inner highlight opacity.
  /// Per DESIGN_SYSTEM.md 8.3: approximately 6–10%.
  static const double darkGlassInnerHighlightOpacity = 0.08;

  /// Dark mode selection accent color (Luminous Mint).
  static const Color darkSelectionAccent = Color(0xFF2AF598);

  /// Dark mode selection tint color.
  static const Color darkSelectionTint = Color(0xFF2AF598);

  // --- Convenience accessors for theme-aware tokens -------------------------

  /// Returns the theme-appropriate glass base tint color.
  static Color glassBaseTint(BuildContext context) =>
      _isDark(context) ? darkGlassTintBase : lightGlassTintBase;

  /// Returns the theme-appropriate glass base tint opacity.
  static double glassBaseTintOpacity(BuildContext context) =>
      _isDark(context) ? darkGlassTintOpacity : lightGlassTintOpacity;

  /// Returns the theme-appropriate glass shadow color.
  static Color glassShadowColor(BuildContext context) =>
      _isDark(context) ? darkGlassShadowColor : lightGlassShadowColor;

  /// Returns the theme-appropriate glass shadow opacity.
  static double glassShadowOpacity(BuildContext context) =>
      _isDark(context) ? darkGlassShadowOpacity : lightGlassShadowOpacity;

  /// Returns the theme-appropriate selection accent color.
  static Color selectionAccent(BuildContext context) =>
      _isDark(context) ? darkSelectionAccent : lightSelectionAccent;

  /// Returns the theme-appropriate selection tint color.
  static Color selectionTint(BuildContext context) =>
      _isDark(context) ? darkSelectionTint : lightSelectionTint;
}
