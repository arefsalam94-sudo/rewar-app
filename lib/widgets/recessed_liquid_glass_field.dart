import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

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

  static const double radius = 14;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = dark ?? colorScheme.brightness == Brightness.dark;
    final accent = isDark
        ? AppColors.darkSelectionAccent
        : AppColors.lightSelectionAccent;
    final tint = isDark
        ? AppColors.darkGlassTintBase
        : AppColors.lightGlassTintBase;
    final tintOpacity = isDark
        ? AppColors.darkGlassTintOpacity
        : AppColors.lightGlassTintOpacity;
    final edge = Colors.white.withValues(alpha: 0.55);

    OutlineInputBorder borderWith(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: tint.withValues(alpha: tintOpacity),
              gradient: LinearGradient(
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
              border: Border.all(color: edge, width: 1.1),
            ),
            child: TextFormField(
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
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: compact ? 14 : 16,
              ),
              decoration: InputDecoration(
                // The character counter would sit outside the glass and break
                // the recessed shape; `maxLength` is kept for the input limit
                // only. The composer shows its own count where it belongs.
                counterText: '',
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkOnSurfaceSecondary.withValues(
                          alpha: AppColors.darkHintOpacity,
                        )
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
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
                focusedBorder: borderWith(
                  accent,
                  AppColors.selectionStrokeWidth,
                ),
                errorBorder: borderWith(
                  colorScheme.error,
                  AppColors.selectionStrokeWidth,
                ),
                focusedErrorBorder: borderWith(
                  colorScheme.error,
                  AppColors.selectionStrokeWidth,
                ),
                errorStyle: TextStyle(
                  color: colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
