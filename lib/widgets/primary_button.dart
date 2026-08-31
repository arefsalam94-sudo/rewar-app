import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Solid navy primary button (white text), per `DESIGN light.md`:
///
/// > *Buttons: Primary buttons are solid Navy (#0E2A44) with White (#FFFFFF)
/// > text. There is no drop shadow.*
/// > *Shapes → Action Buttons: 12px corner radius.*
///
/// Shared across the auth screens.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.dark,
    this.trailingIcon,
  });

  final String label;

  /// Null disables the button (used while a request is in flight).
  final VoidCallback? onTap;

  /// Dark mode inverts the button entirely, per `DESIGN dark.md`:
  ///
  /// > *Primary buttons are filled with the Luminous Mint (#2AF598) with
  /// > dark text.*
  ///
  /// Only the Login screen passes true today.
  final bool? dark;

  /// Optional forward arrow after the label, for a button that advances a
  /// multi-step flow. It mirrors in RTL — `DESIGN_SYSTEM.md` 21: "forward
  /// chevrons mirror with direction".
  final IconData? trailingIcon;

  /// `DESIGN light.md` → Shapes → "Action Buttons: 12px corner radius".
  /// `DESIGN dark.md` → "Buttons/Inputs: rounded-lg (1rem / 16px)".
  static const double radius = 14;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    // On the bright mint fill the label must be the `on-primary` token, per
    // DESIGN dark.md's Text & Legibility rules — not the darker background
    // canvas colour.
    final foreground = isDark ? AppColors.darkOnPrimary : Colors.white;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.55),
          disabledForegroundColor: foreground.withValues(alpha: 0.85),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Builder(
          builder: (context) {
            const textStyle = TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            );
            final icon = trailingIcon;
            if (icon == null) return Text(label, style: textStyle);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, style: textStyle)),
                const SizedBox(width: 10),
                // Mirrors automatically with the ambient direction.
                Icon(icon, size: 22, textDirection: Directionality.of(context)),
              ],
            );
          },
        ),
      ),
    );
  }
}
