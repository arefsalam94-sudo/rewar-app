import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_liquid_glass.dart';
import 'liquid_glass_surface.dart';

/// The app's canonical anchored dropdown menu — one glass recipe, reused.
///
/// This is the Home language popover's surface, lifted out so dropdowns
/// elsewhere stop reaching for Material's opaque `PopupMenuButton` sheet
/// (`DESIGN_SYSTEM F.md` §16: *"All popup menus, sheets, dropdown surfaces,
/// and floating overlays use the same liquid-glass material … do not invent a
/// separate popup glass recipe"*).
///
/// Home still owns its own private copy of this widget: that screen is
/// approved pixel-for-pixel and is not touched here. When a change to Home is
/// on the table, that copy should be deleted in favour of this one.
class GlassMenuPopover extends StatelessWidget {
  const GlassMenuPopover({super.key, required this.children});

  final List<Widget> children;

  /// Corner radius of the glass surface — shared with the frost below it so
  /// the local blur is clipped to exactly the surface it sits behind.
  static const double radius = 28;

  /// ## Local frost, exactly as the Home language popover carries it
  ///
  /// The canonical glass shader carries very little blur of its own
  /// (`blurRadiusPx: 2.8` in `kLiquidGlassSettingsCanonical`). A floating menu
  /// over a photograph needs more than that or it reads as thin, near-clear
  /// glass. These values are the approved ones, and they are clipped to the
  /// menu's own footprint — nothing behind the rest of the screen is touched.
  static const double _frostSigma = 12;
  static const double _frostDimOpacity = 0.28;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The frost is a **sibling painted before** the glass, never an ancestor
    // of it. A real glass surface pushes its own `BackdropFilterLayer`, and
    // nesting that inside another filter's offscreen layer is the black-band
    // corruption documented in `07_DESIGN_EXCEPTIONS.md` §19. As an earlier
    // sibling the shader simply samples the already-frosted region.
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            key: const ValueKey('glass-menu-popover-frost'),
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _frostSigma,
                sigmaY: _frostSigma,
              ),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: _frostDimOpacity),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        AppLiquidGlass(
          useCanonicalGlass: true,
          layer: GlassLayer.surface,
          dark: isDark,
          borderRadius: radius,
          padding: const EdgeInsets.all(6),
          child: Material(
            type: MaterialType.transparency,
            // A vertical viewport stretches its child across the full cross
            // axis, which would blow the menu out to the whole screen width.
            // [IntrinsicWidth] measures the rows themselves — so the menu is
            // exactly as wide as its longest label in any language, and the
            // scroll view still takes over when the rows run out of height
            // (`DESIGN_SYSTEM F.md` §16: contents scroll when space is tight).
            child: IntrinsicWidth(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One row inside a [GlassMenuPopover].
///
/// The text rules are the approved language-popup ones, verbatim:
///
/// * **Light** — every label is white, selected or not. The menu's frosted
///   glass sits over a photograph rather than a page colour, so the `heading`
///   navy an unselected row would otherwise take was tuned for a surface this
///   popup does not have.
/// * **Dark** — dark-on-mint for the selected row (the one place dark mode
///   puts dark text on a light fill, `DESIGN DARK F.md`), and the full-white
///   `heading` colour for every other row.
class GlassMenuOption extends StatelessWidget {
  const GlassMenuOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? (isDark ? AppColors.luminousMint : AppColors.actionNavy)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: isDark
                ? (selected
                      ? AppColors.darkOnPrimary
                      : AppColors.heading(context))
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Opens a [GlassMenuPopover] anchored under [anchorKey]'s box.
///
/// Placement matches what `PopupMenuButton(position: PopupMenuPosition.under)`
/// produced: directly beneath the trigger, leading edges aligned (so it flips
/// with the text direction), clamped to the screen, and flipped above the
/// trigger only when there genuinely is no room below. Dismisses by tapping
/// outside or with Back, returning `null`.
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required String semanticLabel,
  required List<Widget> Function(BuildContext context) itemBuilder,
  Key? menuKey,
}) {
  final navigator = Navigator.of(context);
  final overlayBox =
      navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchorBox = anchorKey.currentContext!.findRenderObject()! as RenderBox;
  final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final anchorRect = topLeft & anchorBox.size;
  final textDirection = Directionality.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: semanticLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) => CustomSingleChildLayout(
      delegate: _AnchoredMenuLayout(
        anchorRect: anchorRect,
        textDirection: textDirection,
      ),
      child: GlassMenuPopover(
        key: menuKey,
        children: itemBuilder(dialogContext),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

/// Positions the menu against the trigger it was opened from.
class _AnchoredMenuLayout extends SingleChildLayoutDelegate {
  const _AnchoredMenuLayout({
    required this.anchorRect,
    required this.textDirection,
  });

  final Rect anchorRect;
  final TextDirection textDirection;

  /// Gap between the trigger and the menu, and the smallest breathing room
  /// kept against every screen edge.
  static const double _gap = 8;
  static const double _screenMargin = 12;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = (constraints.maxWidth - _screenMargin * 2).clamp(
      0.0,
      constraints.maxWidth,
    );
    final below = constraints.maxHeight - anchorRect.bottom - _gap;
    final above = anchorRect.top - _gap;
    final maxHeight = (below > above ? below : above) - _screenMargin;
    return BoxConstraints(
      // Content-sized, exactly as the Material menu it replaces was — never
      // stretched to the trigger's width, which on a wide pill would push the
      // menu off the screen edge and force it away from its anchor.
      maxWidth: maxWidth,
      maxHeight: maxHeight.clamp(0.0, constraints.maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = size.height - anchorRect.bottom - _gap;
    final y = childSize.height <= below
        ? anchorRect.bottom + _gap
        : anchorRect.top - _gap - childSize.height;

    final x = textDirection == TextDirection.rtl
        ? anchorRect.right - childSize.width
        : anchorRect.left;

    return Offset(
      _clamp(x, size.width, childSize.width),
      _clamp(y, size.height, childSize.height),
    );
  }

  /// Keeps [value] inside the screen without ever inverting the range on a
  /// menu that is larger than the space it was given.
  static double _clamp(double value, double extent, double childExtent) {
    final upper = extent - _screenMargin - childExtent;
    if (upper <= _screenMargin) return _screenMargin;
    return value.clamp(_screenMargin, upper);
  }

  @override
  bool shouldRelayout(_AnchoredMenuLayout oldDelegate) =>
      oldDelegate.anchorRect != anchorRect ||
      oldDelegate.textDirection != textDirection;
}
