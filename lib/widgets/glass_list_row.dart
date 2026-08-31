import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_panel.dart';

/// Which control sits at the trailing edge of a [GlassListRow].
enum GlassListRowTrailing {
  /// A forward chevron — the row opens another screen. Mirrored in RTL,
  /// because `chevron_right` is not auto-mirrored.
  chevron,

  /// A downward chevron — the row expands in place. Not mirrored: down is
  /// down in every reading direction.
  expand,

  /// Nothing at the trailing edge.
  none,
}

/// The app's shared "hub row": a liquid-glass card holding a stroke-only
/// circled icon, a title, a hint line, and a trailing control.
///
/// `DESIGN_SYSTEM.md` declares this the approved list-row pattern for any hub
/// screen that lists destinations, and says to reuse it rather than inventing
/// a second row style — so it lives here rather than being copied per screen.
/// Used by the Policy hub and Help & Support.
class GlassListRow extends StatelessWidget {
  const GlassListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = GlassListRowTrailing.chevron,
    this.expanded = false,
    this.expandedChild,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final GlassListRowTrailing trailing;

  /// Whether [expandedChild] is currently revealed below the fixed header.
  final bool expanded;

  /// Optional body that grows from the header's bottom edge. The card's top
  /// stays fixed while following list rows are pushed down.
  final Widget? expandedChild;

  /// `rounded-card` — 28px in both design files.
  static const double radius = 28;

  /// The whole card is the tap target, so this is what satisfies the 48dp
  /// minimum rather than padding around a small icon.
  static const double minHeight = 88;

  /// Vertical gap between two rows. Kept here so every hub screen spaces them
  /// identically.
  static const double gap = 16;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: GlassPanel(
        borderRadius: radius,
        // The design files define one card treatment app-wide: the translucent
        // white sheen. The brand gradient belongs to the full-page background
        // only; using it here makes the rows look like dark backing cards.
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: minHeight),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      18,
                      16,
                      14,
                      16,
                    ),
                    child: Row(
                      children: [
                        _IconCircle(icon: icon, color: accent),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                // Allowed to wrap rather than shrink: this
                                // Column owns the full remaining width.
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  // headline-md
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heading(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  // body-sm
                                  fontSize: 14,
                                  height: 20 / 14,
                                  color: AppColors.secondaryText(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != GlassListRowTrailing.none) ...[
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns:
                                trailing == GlassListRowTrailing.expand &&
                                    expanded
                                ? 0.5
                                : 0,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              _trailingIcon(context),
                              size: 28,
                              color: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: const Duration(milliseconds: 280),
                  reverseDuration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: expanded && expandedChild != null
                      ? expandedChild!
                      : const SizedBox(width: double.infinity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _trailingIcon(BuildContext context) {
    if (trailing == GlassListRowTrailing.expand) {
      return Icons.keyboard_arrow_down_rounded;
    }
    return Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;
  }
}

/// Stroke-only circle around the row's icon — no fill, per the references and
/// the same treatment the Customize Filters group headers use.
class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) => Container(
    width: _size,
    height: _size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.5),
    ),
    child: Icon(icon, size: 22, color: color),
  );
}
