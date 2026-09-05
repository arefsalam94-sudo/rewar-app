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
  /// Light mode uses the semantic `on-surface` navy token.
  /// Dark mode is pure white at 100% — `DESIGN dark.md`: *"if a heading looks
  /// dim, it is a bug."*
  ///
  /// The Home screen keeps its own private copy of this logic (it predates
  /// this accessor); new screens should use this one.
  static Color heading(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : actionNavy;

  /// Returns the correct helper/secondary text colour for the current
  /// theme, so the dark-mode 70-80% rule is applied in one place instead of
  /// being re-derived (and mis-derived) per widget.
  static Color secondaryText(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? darkOnSurfaceSecondary.withValues(alpha: darkSecondaryTextOpacity)
        : scheme.onSurfaceVariant;
  }

  // --- V3 calibration — Design_system_final_v3.md ---------------------------
  //
  // Additive V3 tokens/opacities. Existing V2 constants above (used by Login,
  // Register, Verification, Home, and every other screen) are left exactly
  // as they are; only Language Selection reads these today.

  /// `text-secondary` under V3's exact-opacity rule: Light `#3E4945` at
  /// `1.00` (unchanged from V2's `onSurfaceVariant`), Dark `#FFFFFF` at
  /// `0.80` (V2 was `0.75` via [darkSecondaryTextOpacity] — a shared constant
  /// left untouched so other screens don't shift).
  static Color secondaryTextV3(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.80)
      : const Color(0xFF3E4945);

  /// `glass-tint-opacity` (V3): the subtle ambient wash on ordinary,
  /// unselected Liquid Glass. Color comes from [glassBaseTint].
  static const double glassTintOpacityV3 = 0.02;

  /// Canonical glass body tint: the one neutral readability wash shared by
  /// every standalone real-shader canonical surface
  /// (`Design_system_CANONICAL.md` §9) — Language, Login/Register cards,
  /// the bottom nav/toolbar, the theme toggle, the back button. Always
  /// plain white; only the opacity differs by theme, so the material
  /// itself never reads as tinted toward a brand hue and every standalone
  /// surface reads as the same glass. Never a page-specific value.
  static const Color canonicalGlassBodyTint = Colors.white;

  /// [canonicalGlassBodyTint] opacity in light mode.
  static const double lightCanonicalGlassBodyTintOpacity = 0.10;

  /// [canonicalGlassBodyTint] opacity in dark mode.
  static const double darkCanonicalGlassBodyTintOpacity = 0.06;

  /// Embedded-content tint opacity in light mode
  /// (`Design_system_CANONICAL.md` §9/§10) — the very subtle fill used by
  /// [GlassLayer.embedded] content (fields, social buttons, option rows)
  /// that already sits inside a visible canonical [GlassLayer.surface], so
  /// it never stacks a second shader/blur/highlight and never reads as a
  /// second box. Deliberately lighter than [lightCanonicalGlassBodyTintOpacity].
  static const double lightCanonicalGlassEmbeddedTintOpacity = 0.04;

  /// Embedded-content tint opacity in dark mode. See
  /// [lightCanonicalGlassEmbeddedTintOpacity].
  static const double darkCanonicalGlassEmbeddedTintOpacity = 0.025;

  /// `glass-shadow-opacity` (V3), both themes. Color comes from
  /// [lightGlassShadowColor]/[darkGlassShadowColor].
  static const double glassShadowOpacityV3 = 0.10;

  /// "Large selected glass cards — maximum local tint opacity" (V3): the
  /// selected-state emphasis cap, using [selectionAccent] for color.
  static const double largeSelectionTintOpacityV3 = 0.05;

  // --- Field (input) semantic tokens — Design system final v2.md §4A -------
  //
  // Dedicated component-color-ownership tokens for text/search/form fields.
  // Opt-in via `RecessedLiquidGlassField.useV2FieldColors` so existing
  // screens that haven't been migrated yet keep their current look; only
  // Login and Register set it to true today.

  /// `field-icon`: normal input icons. Light is navy (never the brand green
  /// `primary`/`lightSelectionAccent`); dark is mint.
  static Color fieldIcon(BuildContext context) =>
      _isDark(context) ? luminousMint : actionNavy;

  /// `field-value`: the text the user has typed.
  static Color fieldValue(BuildContext context) =>
      _isDark(context) ? Colors.white : actionNavy;

  /// `field-label`: a field's own label, when a screen draws one separately
  /// from the placeholder.
  static Color fieldLabel(BuildContext context) => fieldValue(context);

  /// `field-hint`: placeholder text. `Light_mode_CANONICAL.md` §5: full-opacity
  /// navy `#0E2A44` at `1.00` — normal Light field hints must not be reduced
  /// to `0.70`. `Dark_mode_CANONICAL.md` §5 is unchanged: white at `0.70`.
  static Color fieldHint(BuildContext context) =>
      _isDark(context) ? Colors.white.withValues(alpha: 0.70) : actionNavy;

  /// `field-helper`: supporting text under a field (not the placeholder).
  /// `Light_mode_CANONICAL.md` §5: full-opacity `#3E4945` at `1.00` — normal
  /// Light field helper text must not be reduced to `0.90`.
  /// `Dark_mode_CANONICAL.md` §5 is unchanged: `#FFFFFF` at `0.80`.
  static Color fieldHelper(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.80)
      : const Color(0xFF3E4945);

  /// `field-cursor`: the text-input caret. `Light_mode_CANONICAL.md` §5:
  /// `#00624D`. `Dark_mode_CANONICAL.md` §5: `#2AF598`.
  static Color fieldCursor(BuildContext context) =>
      _isDark(context) ? luminousMint : const Color(0xFF00624D);

  /// `icon-accent` (`Design_system_CANONICAL.md` §13): a standalone/embedded
  /// icon that isn't literally inside a text field but shares the same
  /// navy/mint role — e.g. a back-button chevron or a theme-toggle glyph.
  /// Identical values to [fieldIcon]; named separately so call sites read
  /// with the canonical vocabulary.
  static Color iconAccent(BuildContext context) => fieldIcon(context);

  /// `text-on-photo-secondary` (`Design_system_CANONICAL.md` §11 /
  /// `Light_mode_CANONICAL.md` §4, updated; `Dark_mode_CANONICAL.md` §4
  /// unchanged): white at `0.90` in both themes, for text drawn directly on
  /// the background photo (outside any glass surface). Scoped to the
  /// Language/Login/Register canonical migration — every other screen keeps
  /// [onPhotoSecondary], which uses different, already-shared opacities.
  static Color textOnPhotoSecondaryCanonical(BuildContext context) =>
      Colors.white.withValues(alpha: 0.90);

  /// `authActionLink`: the single semantic color for authentication/account
  /// links — Forgot Password, Register Now, Log In Here, and equivalents.
  /// Light `#0E2A44` at `1.00`; Dark `#2AF598` at `1.00`. Deliberately the
  /// same value whether the link sits directly on the background photo or
  /// inside a glass surface — the placement must not change the color.
  /// The single active color source for this role: do not reintroduce a
  /// separate on-photo/on-glass variant, `#00624D`, `colorScheme.primary`,
  /// or a screen-local link color.
  static Color authActionLink(BuildContext context) =>
      _isDark(context) ? luminousMint : actionNavy;

  /// `socialAuthContent`: the single semantic color for social sign-in
  /// controls (icon and label alike) — Apple, Gmail, and equivalents.
  /// Light `#0E2A44` at `1.00`; Dark `#2AF598` at `1.00`. The single active
  /// color source for this role: do not reintroduce `#00624D`,
  /// `colorScheme.primary`, or a screen-local social-button color.
  static Color socialAuthContent(BuildContext context) =>
      _isDark(context) ? luminousMint : actionNavy;

  /// `large-selection-accent`, selected state (`Design_system_CANONICAL.md`
  /// §16): `Light_mode_CANONICAL.md` §8 navy `#0E2A44`;
  /// `Dark_mode_CANONICAL.md` §8 mint `#2AF598`. Deliberately distinct from
  /// [selectionAccent] (`#00624D` in light) — that token is the brand
  /// `text-link` color, not the large-card selection accent, and using it
  /// for a selected Language card would paint the selection green instead
  /// of navy.
  static Color largeSelectionAccent(BuildContext context) =>
      _isDark(context) ? luminousMint : actionNavy;

  /// `compact-selected-fill` (`Light_mode_CANONICAL.md` /
  /// `Dark_mode_CANONICAL.md` §7): the solid fill for a *selected* small
  /// selectable chip/pill/option — navy in Light, mint in Dark. Same value
  /// as [largeSelectionAccent]; named separately because it is a solid
  /// background fill (a compact chip's selected state is intentionally
  /// opaque), not a translucent tint over a real-glass surface the way
  /// [largeSelectionAccent] is used for a large card. The one shared
  /// selection-fill helper for this component family — do not re-derive it
  /// inline per call site.
  static Color compactSelectedFill(BuildContext context) =>
      _isDark(context) ? luminousMint : actionNavy;

  /// `compact-selected-content` (`Light_mode_CANONICAL.md` /
  /// `Dark_mode_CANONICAL.md` §7): the text/icon color drawn on top of
  /// [compactSelectedFill] — white in Light, [darkOnPrimary] (deep emerald)
  /// in Dark, for contrast against the solid fill.
  static Color compactSelectedContent(BuildContext context) =>
      _isDark(context) ? darkOnPrimary : Colors.white;

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
  /// Per Design-system-final.md: 0.55 in both themes.
  static const double backgroundGradientOpacity = 0.55;

  /// Global background-photo saturation normalization (same in light and
  /// dark) — a controlled design-system test to check whether one fixed
  /// value can neutralize source photos of very different hue/saturation
  /// (e.g. Flight Ticketing's saturated blue sky photo) without a
  /// per-screen correction. `1.0` is the original image; `0.0` is
  /// grayscale. Applied in [PageBackground] *before* the existing blur and
  /// the existing canonical Light/Dark gradient — it changes saturation
  /// only, never hue, brightness, contrast, or alpha.
  static const double backgroundImageSaturation = 0.70;

  /// Shared liquid-glass backdrop blur from the final design system.
  static const double glassBlurBaseL1 = 2.0;

  /// Middle-layer glass blur (L2 — group card / sheet on L1).
  /// Per DESIGN_SYSTEM.md 6.1.
  static const double glassBlurMiddleL2 = 2.0;

  /// Top-layer glass blur (L3 — glass control / chip on L2).
  /// Per DESIGN_SYSTEM.md 6.1.
  static const double glassBlurTopL3 = 2.0;

  /// Base glass neutral edge thickness (pixels).
  /// Per DESIGN_SYSTEM.md 5.1: 1px soft light-catching edge.
  static const double glassEdgeThickness = 0.0;

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
  static const double selectionStrokeWidth = 0.0;
  static const double selectionStrokeOpacity = 0.0;

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

  /// Returns the theme-appropriate [canonicalGlassBodyTint] opacity.
  static double canonicalGlassBodyTintOpacity(BuildContext context) =>
      _isDark(context)
      ? darkCanonicalGlassBodyTintOpacity
      : lightCanonicalGlassBodyTintOpacity;

  /// Returns the theme-appropriate [GlassLayer.embedded] tint opacity. See
  /// [lightCanonicalGlassEmbeddedTintOpacity].
  static double canonicalGlassEmbeddedTintOpacity(BuildContext context) =>
      _isDark(context)
      ? darkCanonicalGlassEmbeddedTintOpacity
      : lightCanonicalGlassEmbeddedTintOpacity;

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

  // --- Warning banner (PreviewModeBanner, legal-document "unreviewed"
  // notice) --------------------------------------------------------------
  //
  // Named here to stop the same four hex values being duplicated verbatim
  // in both call sites. Intentionally one value in both themes — an amber
  // caution banner, not a themed surface — so no dark variant is defined;
  // introducing one would be a new design decision, not a cleanup.
  static const Color warningBannerFill = Color(0xFFFFE08A);
  static const double warningBannerFillOpacity = 0.92;
  static const Color warningBannerBorder = Color(0xFF8A6D00);
  static const Color warningBannerIcon = Color(0xFF6B5400);
  static const Color warningBannerText = Color(0xFF4A3A00);
}
