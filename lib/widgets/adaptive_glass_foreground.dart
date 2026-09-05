import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';

/// Wraps the scrollable/background content that can appear behind a glass
/// toolbar/navigation surface, so [AdaptiveGlassForeground] can sample its
/// rendered pixels. [boundaryKey] must be the same [GlobalKey] passed to
/// that widget's `backdropKey`.
///
/// This must wrap everything that can visually sit behind the glass surface
/// (background photo, gradient, scrolling content) — not just the
/// scrollable list — or the sampled luminance will be wrong wherever the
/// list itself is transparent.
class AdaptiveGlassBackdrop extends StatelessWidget {
  const AdaptiveGlassBackdrop({
    super.key,
    required this.boundaryKey,
    required this.child,
  });

  final GlobalKey boundaryKey;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: boundaryKey, child: child);
}

/// Marks the exact on-screen bounds of a glass toolbar/navigation surface,
/// so [AdaptiveGlassForeground] knows which part of the
/// [AdaptiveGlassBackdrop] to sample. [anchorKey] must be the same
/// [GlobalKey] passed to that widget's `anchorKey`.
class AdaptiveGlassForegroundAnchor extends StatelessWidget {
  const AdaptiveGlassForegroundAnchor({
    super.key,
    required this.anchorKey,
    required this.child,
  });

  final GlobalKey anchorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: anchorKey, child: child);
}

/// Reusable adaptive foreground color for glass toolbar/navigation
/// surfaces. Samples the average luminance of the content actually
/// rendered behind the glass surface (via [AdaptiveGlassBackdrop] +
/// [AdaptiveGlassForegroundAnchor]) and exposes ONE shared, smoothly
/// interpolated, smoothly-animated color between [onDark] (white) and
/// [onLight] (navy) for that surface's neutral/inactive icons and labels.
///
/// There is no binary switch and no hysteresis band: the color is a
/// continuous function of (smoothed) luminance, so nothing can get stuck
/// in one state — it always tracks whatever is currently behind the
/// surface.
///
/// This only ever supplies the neutral color; selected/active styling and
/// every other color in the app are untouched. Not tied to any one screen
/// or glass surface — any glass toolbar/navigation control can reuse it by
/// wrapping its background content in [AdaptiveGlassBackdrop] and its own
/// bounds in [AdaptiveGlassForegroundAnchor].
class AdaptiveGlassForeground extends StatefulWidget {
  const AdaptiveGlassForeground({
    super.key,
    required this.backdropKey,
    required this.anchorKey,
    required this.initialColor,
    required this.builder,
    this.activity,
    this.sampleInterval = const Duration(milliseconds: 110),
    this.trailingSampleDelay = const Duration(milliseconds: 100),
    this.animationDuration = const Duration(milliseconds: 180),
    this.fullWhiteLuminance = 0.25,
    this.fullNavyLuminance = 0.65,
    this.luminanceSmoothing = 0.30,
  });

  /// The [GlobalKey] of the [AdaptiveGlassBackdrop] to sample.
  final GlobalKey backdropKey;

  /// The [GlobalKey] of this glass surface's own
  /// [AdaptiveGlassForegroundAnchor].
  final GlobalKey anchorKey;

  /// Shown before the first sample resolves and seeds the luminance
  /// smoothing, so there is no flash of the wrong color on first frame.
  /// Callers typically pass their previous static neutral color.
  final Color initialColor;

  final ValueWidgetBuilder<Color> builder;

  /// Optional signal (e.g. a scroll position) that content behind the
  /// surface may have moved. When provided, sampling is throttled to
  /// [sampleInterval] while this fires, plus one trailing sample
  /// [trailingSampleDelay] after it goes quiet, and stops entirely once
  /// settled — no continuous capture while idle. When omitted, a single
  /// sample is still taken after first layout.
  final Listenable? activity;

  /// Minimum gap between samples while [activity] is actively firing.
  final Duration sampleInterval;

  /// Delay after the last [activity] tick before one final settling
  /// sample — important because the throttle window during scrolling can
  /// otherwise miss exactly where the content stopped.
  final Duration trailingSampleDelay;

  /// Duration of the white↔navy color transition. Restarted from
  /// whatever color is currently displayed on every new sample, so
  /// continuous samples during a scroll read as one smooth chase rather
  /// than a series of separate animations.
  final Duration animationDuration;

  /// At or below this (smoothed) luminance, the foreground is full
  /// [onDark] (white).
  final double fullWhiteLuminance;

  /// At or above this (smoothed) luminance, the foreground is full
  /// [onLight] (navy). Between [fullWhiteLuminance] and this, the color is
  /// linearly interpolated — there is no snap point.
  final double fullNavyLuminance;

  /// Exponential-moving-average weight given to each new raw luminance
  /// sample (the rest — `1 - luminanceSmoothing` — comes from the
  /// previous smoothed value), so noisy photo pixels don't make the color
  /// shake.
  final double luminanceSmoothing;

  /// Foreground used over a light background.
  static const Color onLight = AppColors.actionNavy;

  /// Foreground used over a dark background.
  static const Color onDark = Colors.white;

  @override
  State<AdaptiveGlassForeground> createState() =>
      _AdaptiveGlassForegroundState();
}

class _AdaptiveGlassForegroundState extends State<AdaptiveGlassForeground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  double? _smoothedLuminance;
  Timer? _throttle;
  Timer? _trailingTimer;
  bool _sampling = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.animationDuration)
          ..value = 1;
    _colorAnimation = AlwaysStoppedAnimation<Color?>(widget.initialColor);
    widget.activity?.addListener(_onActivity);
    // One sample after first layout so a static (non-scrolling) background
    // still gets the right color, without polling forever.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sample());
  }

  @override
  void didUpdateWidget(covariant AdaptiveGlassForeground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity) {
      oldWidget.activity?.removeListener(_onActivity);
      widget.activity?.addListener(_onActivity);
    }
  }

  void _onActivity() {
    // Throttle: at most one sample per sampleInterval while activity keeps
    // firing; nothing is scheduled once it goes quiet.
    _throttle ??= Timer(widget.sampleInterval, () {
      _throttle = null;
      _sample();
    });
    // Debounced trailing sample: reset on every tick, so it only actually
    // fires once activity has settled — this is what catches wherever
    // scrolling ends up stopping, even if the last throttle window missed
    // it.
    _trailingTimer?.cancel();
    _trailingTimer = Timer(widget.trailingSampleDelay, _sample);
  }

  Future<void> _sample() async {
    if (_sampling || !mounted) return;
    _sampling = true;
    try {
      final measured = await _measureLuminance();
      if (measured == null || !mounted) return;
      // Exponential moving average — smooths out noisy individual pixels
      // so the color doesn't shake from frame to frame.
      _smoothedLuminance = _smoothedLuminance == null
          ? measured
          : _smoothedLuminance! * (1 - widget.luminanceSmoothing) +
                measured * widget.luminanceSmoothing;

      // Continuous interpolation — no binary switch, no hysteresis band,
      // so the color can never get stuck.
      final t =
          ((_smoothedLuminance! - widget.fullWhiteLuminance) /
                  (widget.fullNavyLuminance - widget.fullWhiteLuminance))
              .clamp(0.0, 1.0);
      final target = Color.lerp(
        AdaptiveGlassForeground.onDark,
        AdaptiveGlassForeground.onLight,
        t,
      )!;
      _animateTo(target);
    } finally {
      _sampling = false;
    }
  }

  void _animateTo(Color target) {
    setState(() {
      _colorAnimation = ColorTween(
        begin: _colorAnimation.value,
        end: target,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    });
    _controller
      ..value = 0
      ..forward();
  }

  Future<double?> _measureLuminance() async {
    final backdropObj = widget.backdropKey.currentContext?.findRenderObject();
    final anchorObj = widget.anchorKey.currentContext?.findRenderObject();
    if (backdropObj is! RenderRepaintBoundary || anchorObj is! RenderBox) {
      return null;
    }
    if (!backdropObj.attached || !anchorObj.attached) return null;

    final backdropSize = backdropObj.size;
    if (backdropSize.width <= 0 || backdropSize.height <= 0) return null;

    final topLeft = backdropObj.globalToLocal(
      anchorObj.localToGlobal(Offset.zero),
    );
    final bottomRight = backdropObj.globalToLocal(
      anchorObj.localToGlobal(anchorObj.size.bottomRight(Offset.zero)),
    );

    // Render the backdrop at a tiny fixed resolution — cheap regardless of
    // screen size or how visually complex the background content is.
    const double targetWidth = 32.0;
    final pixelRatio = targetWidth / backdropSize.width;

    ui.Image image;
    try {
      image = await backdropObj.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      return null;
    }
    final ByteData? bytes;
    try {
      bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
    if (bytes == null) return null;

    final imgWidth = image.width;
    final imgHeight = image.height;
    final x0 = (topLeft.dx * pixelRatio).floor().clamp(0, imgWidth - 1);
    final y0 = (topLeft.dy * pixelRatio).floor().clamp(0, imgHeight - 1);
    final x1 = (bottomRight.dx * pixelRatio).ceil().clamp(x0 + 1, imgWidth);
    final y1 = (bottomRight.dy * pixelRatio).ceil().clamp(y0 + 1, imgHeight);

    final pixels = bytes.buffer.asUint8List();
    double total = 0;
    int count = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final index = (y * imgWidth + x) * 4;
        if (index + 3 >= pixels.length) continue;
        final r = pixels[index] / 255.0;
        final g = pixels[index + 1] / 255.0;
        final b = pixels[index + 2] / 255.0;
        // Relative (perceptual) luminance.
        total += 0.2126 * r + 0.7152 * g + 0.0722 * b;
        count++;
      }
    }
    if (count == 0) return null;
    return total / count;
  }

  @override
  void dispose() {
    widget.activity?.removeListener(_onActivity);
    _throttle?.cancel();
    _trailingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return widget.builder(
          context,
          _colorAnimation.value ?? widget.initialColor,
          child,
        );
      },
    );
  }
}
