import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// The app's single "save this place" heart.
///
/// Lifted verbatim from the two private copies that existed on the Home
/// carousel and the Explore Tours cards, because the heart now appears on
/// four screens — Where to Stay (trending + featured cards), Hotel Details,
/// Explore Nature (cards) and Nature Place Details — and a favourite is one
/// concept, so it must not look like four.
///
/// Nothing here is new: the circle geometry is the [GlassBackButton] pattern
/// (a small filled circle centred in a 48dp target), and the fill and accent
/// are the same tokens the previous copies used. It deliberately draws a
/// solid translucent circle rather than canonical glass — it sits *on a
/// photograph*, which is the case `07_DESIGN_EXCEPTIONS.md` §8 covers, and a
/// second shader per card is the repeated-surface condition §9 warns against.
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.pending = false,
    this.showCircle = true,
    this.targetSize = 48,
    this.circleSize = 40,
    this.iconSize = 21,
  });

  final bool isFavorite;

  /// True while the write is in flight, so a double-tap cannot fire twice.
  final bool pending;

  final VoidCallback onTap;

  /// Whether the filled circle is drawn behind the heart.
  ///
  /// True everywhere the heart sits **on a photograph**, where it needs its
  /// own ground to stay legible. False on the Favorites rows, where it sits
  /// on a glass card beside the open arrow and a second circle would read as
  /// a button the row does not have.
  final bool showCircle;

  /// The three sizes shrink together on a list card, whose photo is drawn at
  /// the card's own scale rather than at device pixels. The defaults are the
  /// full-size values the Home carousel used.
  final double targetSize;
  final double circleSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;

    return Semantics(
      button: true,
      selected: isFavorite,
      enabled: !pending,
      label: AppLocalizations.of(context).navSaved,
      child: SizedBox(
        width: targetSize,
        height: targetSize,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: pending ? null : onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: showCircle ? circleSize : null,
                height: showCircle ? circleSize : null,
                decoration: showCircle
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppColors.darkGlassTop.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.9),
                      )
                    : null,
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: iconSize,
                  color: accent.withValues(alpha: pending ? 0.4 : 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
