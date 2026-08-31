import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The opaque "ticket" surface introduced by the My Bookings screen.
///
/// This is the app's **second** card surface, alongside [GlassPanel]. That is a
/// deliberate, approved exception rather than drift: a booking is a physical
/// artefact in the user's mind — a boarding pass, a voucher — and the reference
/// draws it as a solid ticket with torn edges. A translucent glass panel cannot
/// carry a notch or a perforation convincingly, because the cut-out would show
/// the background photo at a different blur than its surroundings.
///
/// **No new colours.** The fill is the already-approved brand mint
/// (`AppColors.pageGradientTop`, `#E1F4E5`) in light mode and the approved
/// `darkGlassTop` (`#0C1F1F`) in dark, both at full opacity. The only new
/// tokens this screen introduces are the status-pill colours, which are
/// documented in `DESIGN_light.md` / `DESIGN_dark.md`.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.child,
    this.notchFraction,
    this.borderRadius,
  });

  final Widget child;

  /// Where the semicircular edge notches sit, as a fraction of the card's
  /// height. Null draws no notches — used by cards that have no seam to line
  /// up with.
  final double? notchFraction;

  /// Defaults to the per-mode card radius the app already uses: 16 in light,
  /// 24 in dark (`DESIGN_SYSTEM.md` — "Card radius is per-mode").
  final double? borderRadius;

  static const double notchRadius = 11;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkGlassTop
      : AppColors.pageGradientTop;

  static double defaultRadius(BuildContext context) => 28;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? defaultRadius(context);

    return DecoratedBox(
      // The shadow is drawn by a widget *behind* the clip, because a
      // `ClipPath` clips its child's shadow away along with everything else.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _TicketOutlineClipper(
          radius: radius,
          notchFraction: notchFraction,
          notchRadius: notchRadius,
        ),
        child: ColoredBox(color: surface(context), child: child),
      ),
    );
  }
}

/// Rounded rectangle with a semicircular bite taken out of each long edge, so
/// the card reads as a torn ticket stub.
class _TicketOutlineClipper extends CustomClipper<Path> {
  const _TicketOutlineClipper({
    required this.radius,
    required this.notchFraction,
    required this.notchRadius,
  });

  final double radius;
  final double? notchFraction;
  final double notchRadius;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    final fraction = notchFraction;
    if (fraction == null) return body;

    final centerY = size.height * fraction.clamp(0.0, 1.0);
    final notches = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(0, centerY), radius: notchRadius),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, centerY),
          radius: notchRadius,
        ),
      );

    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  bool shouldReclip(_TicketOutlineClipper oldClipper) =>
      oldClipper.radius != radius ||
      oldClipper.notchFraction != notchFraction ||
      oldClipper.notchRadius != notchRadius;
}

/// Clips a panel so its **leading** edge is a vertical sine wave.
///
/// Used for the information panel that overlaps the photograph on the hotel,
/// car and tour cards. The wave is sampled as discrete points down the height,
/// exactly like the drawer's wavy trailing edge — the only other place in the
/// app that uses this shape language.
///
/// [textDirection] flips the wave to the trailing side under RTL, so the whole
/// card mirrors in Kurdish and Arabic rather than reading backwards. Same rule
/// as Explore Nature's leading-edge thumbnail.
class WavySeamClipper extends CustomClipper<Path> {
  const WavySeamClipper({
    required this.textDirection,
    this.amplitude = 7,
    this.periods = 2.5,
  });

  final TextDirection textDirection;
  final double amplitude;
  final double periods;

  /// How many points the curve is sampled at. 48 is smooth at phone sizes and
  /// cheap enough to rebuild every frame if the card ever animates.
  static const int _samples = 48;

  @override
  Path getClip(Size size) {
    final path = Path();
    final isRtl = textDirection == TextDirection.rtl;

    double waveX(double t) {
      // t runs 0→1 down the height; the sine rides around `amplitude`.
      final offset = amplitude * (1 + math.sin(t * periods * 2 * math.pi));
      return isRtl ? size.width - offset : offset;
    }

    path.moveTo(waveX(0), 0);
    for (var i = 1; i <= _samples; i++) {
      final t = i / _samples;
      path.lineTo(waveX(t), size.height * t);
    }

    if (isRtl) {
      path
        ..lineTo(0, size.height)
        ..lineTo(0, 0);
    } else {
      path
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0);
    }

    return path..close();
  }

  @override
  bool shouldReclip(WavySeamClipper oldClipper) =>
      oldClipper.textDirection != textDirection ||
      oldClipper.amplitude != amplitude ||
      oldClipper.periods != periods;
}

/// A dashed rule, used as the ticket's tear line.
///
/// Horizontal by default; [axis] switches it to the vertical perforation that
/// separates a boarding pass from its barcode stub.
class TicketPerforation extends StatelessWidget {
  const TicketPerforation({super.key, this.axis = Axis.horizontal});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accent(context).withValues(alpha: 0.28);
    return SizedBox(
      width: axis == Axis.vertical ? 1 : double.infinity,
      height: axis == Axis.horizontal ? 1 : double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color, axis: axis),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color, required this.axis});

  final Color color;
  final Axis axis;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final extent = axis == Axis.horizontal ? size.width : size.height;
    for (var pos = 0.0; pos < extent; pos += _dash + _gap) {
      final end = math.min(pos + _dash, extent);
      canvas.drawLine(
        axis == Axis.horizontal ? Offset(pos, 0.5) : Offset(0.5, pos),
        axis == Axis.horizontal ? Offset(end, 0.5) : Offset(0.5, end),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.axis != axis;
}

/// Which of the three approved status colours a pill uses.
enum StatusTone { positive, informational, negative }

/// A small badge stating a fact about a record — Confirmed, Economy, Cancelled.
///
/// **Not a chip.** It is never tappable and the user cannot change it, so the
/// 48dp minimum touch target deliberately does not apply. See "Status Pills" in
/// `DESIGN_light.md` / `DESIGN_dark.md`.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fill, content) = switch (tone) {
      StatusTone.positive => (
        AppColors.statusSuccessFill(context),
        AppColors.statusSuccessContent(context),
      ),
      StatusTone.informational => (
        AppColors.statusInfoFill(context),
        AppColors.statusInfoContent(context),
      ),
      StatusTone.negative => (
        AppColors.statusErrorFill(context),
        AppColors.statusErrorContent(context),
      ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: content,
                ),
              ),
            ),
          ),
          if (icon case final glyph?) ...[
            const SizedBox(width: 5),
            Icon(glyph, size: 14, color: content),
          ],
        ],
      ),
    );
  }
}
