import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'liquid_glass_surface.dart';

/// Shared recessed liquid-glass input for Login and Register.
class RecessedLiquidGlassField extends StatelessWidget {
  const RecessedLiquidGlassField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.prefix,
    this.dark,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.compact = false,
    this.useV2FieldColors = false,
    this.useCanonicalGlass = false,
    this.layer = GlassLayer.surface,
    this.insetDepth = false,
    this.dropShadow = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? prefix;
  final bool? dark;

  /// Multi-line support, added for the Reviews & Ratings composer.
  ///
  /// Deliberately extended here rather than built as a second input style:
  /// `DESIGN_SYSTEM.md` 8 requires every form/search/text input in the app to
  /// use this one recessed-glass family, and 22 lists "different input
  /// families on different screens" as a prohibited pattern. Both default to
  /// the previous single-line behaviour, so no existing screen changes.
  final int? minLines;
  final int? maxLines;

  /// Caps what can be typed. The rules cap it again server-side — client
  /// validation is UX, not the boundary (`SECURITY.md` 7).
  final int? maxLength;

  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  /// Shrinks only the *type size and inner padding* so this same field can be
  /// used at half width — the Explore Tours search row puts two of them side
  /// by side, and a 16px hint cannot fit there.
  ///
  /// The material, the 56dp control height, the 14px radius, the recessed
  /// depth and every state stroke are unchanged: this is the responsive
  /// concession `DESIGN_SYSTEM.md` 19/20 asks for ("labels beside icons must
  /// have room to shrink safely"), not a second input family — which 23 still
  /// prohibits.
  final bool compact;

  /// Routes icon/value/hint colors through the `Design system final v2.md`
  /// §4A field tokens (`AppColors.fieldIcon`/`fieldValue`/`fieldHint`)
  /// instead of the pre-v2 accent/`colorScheme.*` values.
  ///
  /// Opt-in and defaulting to `false` so every screen that already uses this
  /// field — Explore Tours, Car Rental, Flight Ticketing, Hotel Checkout,
  /// Nature Reviews, Booking — keeps its current, already-approved look.
  /// Only Login and Register set this to `true` today, per the v2 rollout
  /// order (`Design system final v2.md` §44).
  final bool useV2FieldColors;

  /// Renders through the real `oc_liquid_glass` shader instead of the legacy
  /// `BackdropFilter` recessed shell (`Design_system_CANONICAL.md` §9/§12:
  /// input fields must be real Liquid Glass, with no stacked BackdropFilter
  /// and no painted border/edge). Opt-in and defaulting to `false` so every
  /// existing screen that uses this field keeps its current, already-approved
  /// look; only Login and Register set this to `true`, alongside
  /// [useV2FieldColors], per the canonical visual migration.
  final bool useCanonicalGlass;

  /// Nesting role when [useCanonicalGlass] is `true`. Defaults to
  /// [GlassLayer.surface] (a standalone real shader) for a field used
  /// without a glass parent. Login/Register pass [GlassLayer.embedded]
  /// because their fields already sit inside a visible canonical glass
  /// card — a second shader there would be glass-on-glass. Ignored when
  /// [useCanonicalGlass] is `false`.
  final GlassLayer layer;

  /// Individual carved-in depth for a field that sits [GlassLayer.embedded]
  /// inside a canonical glass card alongside other fields — the Login/
  /// Register visual test: each field gets its own subtle inner-shadow/
  /// highlight so it reads as its own recessed control rather than all
  /// fields sharing one flat inner wash. Reuses the same shadow/highlight
  /// painter the pre-canonical recessed shell already draws
  /// ([lightGlassInnerShadowColor] etc.) — no new colors, no second
  /// shader/BackdropFilter. Opt-in and defaulting to `false` so every other
  /// embedded field/screen (Explore Tours, Car Rental, Hotel, Flight, …)
  /// keeps its current, already-approved look unchanged. Ignored unless
  /// [useCanonicalGlass] is `true` and [layer] is [GlassLayer.embedded].
  final bool insetDepth;

  /// Whether the standalone real-glass surface (a non-embedded
  /// [useCanonicalGlass] field, i.e. [GlassLayer.surface]) paints its
  /// [AppColors.glassFloatingShadowBlurRadius] drop shadow.
  ///
  /// Every other standalone canonical surface (cards, the back button,
  /// social buttons, a lone search field on a page background) has enough
  /// clearance around it for that shadow to read as a soft lift. The
  /// Login/Register nested-glass test stacks several of these surfaces only
  /// [SizedBox](height: 14) apart — closer than the shadow's own 22px blur
  /// radius — so the shadow bled from one field's edge into its neighbor's
  /// space and read as one oversized/overlapping shape, even though each
  /// field's own laid-out bounds were already exact (verified: every field
  /// is precisely 56dp tall with the intended 14dp gap; the shader's own
  /// mask cuts off within ~1px of the shape edge — see the field-geometry
  /// diagnosis in the PR notes). Turning the shadow off — not the shader
  /// material — is what actually fixes that bleed. Defaults to `true` so
  /// every existing standalone-surface call site keeps its current,
  /// already-approved look; only Login/Register set this to `false`.
  /// Ignored unless [useCanonicalGlass] is `true` and [layer] is
  /// [GlassLayer.surface].
  final bool dropShadow;

  static const double radius = 14;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = dark ?? colorScheme.brightness == Brightness.dark;
    // `field-icon` (Design system final v2.md §4A / canonical §12) for
    // migrated screens; everyone else keeps the pre-v2 accent color
    // unchanged.
    final accent = useV2FieldColors
        ? AppColors.fieldIcon(context)
        : (isDark
              ? AppColors.darkSelectionAccent
              : AppColors.lightSelectionAccent);
    final tint = useCanonicalGlass
        ? AppColors.canonicalGlassBodyTint
        : (isDark ? AppColors.darkGlassTintBase : AppColors.lightGlassTintBase);
    final tintOpacity = useCanonicalGlass
        ? (layer == GlassLayer.embedded
              ? AppColors.canonicalGlassEmbeddedTintOpacity(context)
              : AppColors.canonicalGlassBodyTintOpacity(context))
        : (isDark
              ? AppColors.darkGlassTintOpacity
              : AppColors.lightGlassTintOpacity);
    OutlineInputBorder borderWith(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      autofocus: autofocus,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      showCursor: !readOnly,
      cursorColor: useV2FieldColors ? AppColors.fieldCursor(context) : null,
      style: TextStyle(
        // `field-value` (Design system final v2.md §4A) for migrated
        // screens; everyone else keeps `colorScheme.onSurface`.
        color: useV2FieldColors
            ? AppColors.fieldValue(context)
            : colorScheme.onSurface,
        fontSize: compact ? 14 : 16,
      ),
      decoration: InputDecoration(
        // The character counter would sit outside the glass and break
        // the recessed shape; `maxLength` is kept for the input limit
        // only. The composer shows its own count where it belongs.
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          // `field-hint` for migrated screens; everyone else keeps
          // the pre-v2 hint treatment.
          color: useV2FieldColors
              ? AppColors.fieldHint(context)
              : (isDark
                    ? AppColors.darkOnSurfaceSecondary.withValues(
                        alpha: AppColors.darkHintOpacity,
                      )
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.85)),
          fontSize: compact ? 14 : 16,
        ),
        prefixIcon: (prefixIcon == null && prefix == null)
            ? null
            : Padding(
                padding: EdgeInsetsDirectional.only(
                  start: compact ? 14 : 18,
                  end: compact ? 8 : 12,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (prefixIcon != null)
                        Icon(
                          prefixIcon,
                          color: accent,
                          size: compact ? 20 : 22,
                        ),
                      if (prefix != null) ...[
                        const SizedBox(width: 10),
                        prefix!,
                      ],
                    ],
                  ),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.transparent,
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: 16,
        ),
        enabledBorder: borderWith(Colors.transparent, 0),
        border: borderWith(Colors.transparent, 0),
        focusedBorder: borderWith(Colors.transparent, 0),
        errorBorder: borderWith(Colors.transparent, 0),
        focusedErrorBorder: borderWith(Colors.transparent, 0),
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final tintedField = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: tint.withValues(alpha: tintOpacity),
        // The legacy sheen gradient simulates a painted highlight — the
        // canonical renderer supplies its own edge/specular, so the
        // real-glass path skips it (`Design_system_CANONICAL.md` §10).
        gradient: useCanonicalGlass
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(
                    alpha: AppColors.glassSheenBottomOpacity,
                  ),
                  Colors.white.withValues(alpha: 0.02),
                ],
                stops: const [0.0, 1.0],
              ),
        border: null,
      ),
      child: field,
    );

    if (useCanonicalGlass && layer == GlassLayer.embedded) {
      // Already inside a visible canonical glass surface — no second
      // shader, no second refraction/specular/blur, just the same shared
      // tint as material separation (`Design_system_CANONICAL.md` §9/§10).
      if (!insetDepth) return tintedField;

      // Visual test only (Login/Register): the flat shared tint alone left
      // every field reading as one continuous wash across the card, with no
      // edge to tell one field from the next. This adds a per-field carved
      // -in cue — a soft blurred inner shadow at the top edge and a hairline
      // highlight below it — painted straight onto this field's own canvas,
      // not a second BackdropFilter/shader, so it can't stack with the
      // card's real glass blur behind it.
      return CustomPaint(
        foregroundPainter: _RecessedFieldPainter(
          borderRadius: radius,
          shadowColor: isDark
              ? AppColors.darkGlassInnerShadowColor
              : AppColors.lightGlassInnerShadowColor,
          shadowOpacity: isDark
              ? AppColors.darkGlassInnerShadowOpacity
              : AppColors.lightGlassInnerShadowOpacity,
          highlightColor: isDark
              ? AppColors.darkGlassInnerHighlightColor
              : AppColors.lightGlassInnerHighlightColor,
        ),
        child: tintedField,
      );
    }

    if (useCanonicalGlass) {
      // The same shared shell [AppLiquidGlass]'s canonical branch renders
      // through — not a separate hand-built `LiquidGlassGroup` +
      // `LiquidGlassSurface` pair (Design_system_CANONICAL.md §9): there is
      // exactly one canonical surface renderer in the app.
      //
      // `oc_liquid_glass`'s `BackdropFilterLayer` is pushed with no clip of
      // its own (the package's own source even has this exact fix written
      // out and commented as a possible future addition) — left unbounded,
      // its blur/refraction paints over whatever the compositor gives it,
      // not just this field's rect. A lone standalone surface (a card, the
      // back button) has enough clearance that this never shows. Login/
      // Register fields sit only 14dp apart, so it read as one field's
      // glass bleeding into its neighbor. `ClipRRect` at this field's own
      // radius is the standard Flutter pairing for an unbounded
      // `BackdropFilter`, applied only when [dropShadow] is off — the same
      // "stacked too close" condition this is fixing. A field that keeps
      // its floating drop shadow (every non-Login/Register canonical field,
      // today none) is far enough from its neighbors not to need it, and
      // that shadow is deliberately painted *outside* this radius, so
      // clipping there would cut it off.
      final glass = CanonicalGlassShell(
        borderRadius: radius,
        // See [dropShadow] — off only for fields stacked closer together
        // than the shadow's own blur radius (Login/Register); every other
        // standalone surface keeps this shadow unchanged.
        shadow: dropShadow ? canonicalGlassShadow(context) : null,
        child: tintedField,
      );
      if (dropShadow) return glass;
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: glass,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppColors.glassBlurMiddleL2,
          sigmaY: AppColors.glassBlurMiddleL2,
        ),
        child: CustomPaint(
          foregroundPainter: _RecessedFieldPainter(
            borderRadius: radius,
            shadowColor: isDark
                ? AppColors.darkGlassInnerShadowColor
                : AppColors.lightGlassInnerShadowColor,
            shadowOpacity: isDark
                ? AppColors.darkGlassInnerShadowOpacity
                : AppColors.lightGlassInnerShadowOpacity,
            highlightColor: isDark
                ? AppColors.darkGlassInnerHighlightColor
                : AppColors.lightGlassInnerHighlightColor,
          ),
          child: tintedField,
        ),
      ),
    );
  }
}

class _RecessedFieldPainter extends CustomPainter {
  const _RecessedFieldPainter({
    required this.borderRadius,
    required this.shadowColor,
    required this.shadowOpacity,
    required this.highlightColor,
  });

  final double borderRadius;
  final Color shadowColor;
  final double shadowOpacity;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      Radius.circular(borderRadius - 3),
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    final shadowPaint = Paint()
      ..color = shadowColor.withValues(alpha: shadowOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(rrect)
        ..addRRect(inner.shift(const Offset(0, -2))),
      shadowPaint,
    );
    canvas.restore();

    final topHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));
    canvas.drawRRect(rrect.deflate(1.4), topHighlight);

    final lowerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = highlightColor.withValues(alpha: 0.06);
    canvas.drawRRect(rrect.deflate(2.4), lowerGlow);
  }

  @override
  bool shouldRepaint(_RecessedFieldPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.shadowOpacity != shadowOpacity ||
        oldDelegate.highlightColor != highlightColor;
  }
}
