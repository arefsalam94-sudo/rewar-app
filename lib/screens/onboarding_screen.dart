import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/onboarding_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Three-slide onboarding intro, shown once after the language is chosen.
///
/// Layout comes from the handed-over reference image rather than from the
/// dark-mode design file: this is a full-bleed photo screen whose artwork
/// already carries its own darkening, so it looks identical in light and
/// dark mode and every piece of text is plain white.
///
/// All three slides share one landscape photo three screens wide, panned as
/// the pages scroll — see [_PanoramaBackground].
///
/// All three slides carry their localized copy and scroll-linked motion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.languageCode});

  final String languageCode;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageCount = 3;
  static const Duration _nextTransitionDuration = Duration(milliseconds: 1000);
  static const Duration _finalSlideTransitionDuration = Duration(
    milliseconds: 1200,
  );

  /// The plane/line strip sits above the body copy. Anchoring it in the outer
  /// stack (rather than inside a page) keeps it perfectly still while the
  /// pages slide underneath — it is a shared progress indicator, not part of
  /// any one slide. Its offset comes from [_SlideMetrics], which measures the
  /// copy first so the two can never overlap.
  static const double _trackHeight = _SlideMetrics.trackHeight;

  final PageController _pageController = PageController();

  /// Drives the entry motion of the current slide's text. The individual
  /// timings are carved out of this with intervals — see [_FadeScaleIn] and
  /// [_OvershootIn].
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Slide one is on screen immediately, so its text animates in at once.
    _introController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the panorama during the push transition rather than on the first
    // painted frame, so the photo is ready before the screen settles.
    // Failures are ignored: the errorBuilder already covers a missing asset.
    precacheImage(
      _PanoramaBackground.provider(),
      context,
      onError: (error, stackTrace) =>
          debugPrint('Onboarding panorama failed to load: $error'),
    );
    precacheImage(
      _PanoramaBackground.nightProvider(),
      context,
      onError: (error, stackTrace) =>
          debugPrint('Onboarding night panorama failed to load: $error'),
    );
    precacheImage(
      _RoadCarMotion.provider,
      context,
      onError: (error, stackTrace) =>
          debugPrint('Onboarding road car failed to load: $error'),
    );
    // Decode the large decorative plane before the user begins swiping so
    // its first visible frame cannot hitch during the page transition.
    precacheImage(
      _MainPlaneMotion.provider,
      context,
      onError: (error, stackTrace) =>
          debugPrint('Onboarding main plane failed to load: $error'),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _pageController.dispose();
    // A 3-screen-wide photo is a large decode to leave sitting in the cache
    // for a screen that only runs once.
    _PanoramaBackground.provider().evict().ignore();
    _PanoramaBackground.nightProvider().evict().ignore();
    _RoadCarMotion.provider.evict().ignore();
    _MainPlaneMotion.provider.evict().ignore();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // Replay the entry motion each time a slide settles, so the text always
    // arrives rather than being already in place when swiping back.
    _introController
      ..reset()
      ..forward();
  }

  Future<void> _next() async {
    if (_currentPage < _pageCount - 1) {
      await _pageController.nextPage(
        duration: _currentPage == 1
            ? _finalSlideTransitionDuration
            : _nextTransitionDuration,
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  /// Ends onboarding for good and continues to Login.
  Future<void> _finish() async {
    await OnboardingPreferences.markOnboardingSeen();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      _OnboardingExitRoute<void>(
        builder: (_) => LoginScreen(languageCode: widget.languageCode),
        duration: _nextTransitionDuration,
      ),
    );
  }

  /// Continuous scroll position in pages (0.0 → 2.0), used to fly the plane
  /// between the three dots as the user drags rather than only on release.
  double get _scrollProgress {
    if (!_pageController.hasClients ||
        !_pageController.position.hasContentDimensions) {
      return _currentPage.toDouble();
    }
    return _pageController.page ?? _currentPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // Measured against every slide's copy, so the flight path sits clear of
    // the tallest of them and never shifts between slides.
    final metrics = _SlideMetrics.resolve(
      context,
      bodyTexts: [
        l10n.onboardingBody1,
        l10n.onboardingBody2,
        l10n.onboardingBody3,
      ],
      languageCode: widget.languageCode,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White text over a photo throughout, so the system icons stay light.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Shows through for the one frame before the photo is decoded,
            // and if the asset is ever missing.
            const ColoredBox(color: AppColors.darkForestFloor),
            // LAYER 1: the connected three-page landscape. It sits at the
            // very back and pans with the live page position.
            RepaintBoundary(
              key: const ValueKey('onboarding-layer-1-background'),
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) => _PanoramaBackground(
                  progress: _scrollProgress,
                  slideCount: _pageCount,
                ),
              ),
            ),
            // The car is attached to the third panorama slice using the same
            // scale and crop calculation as the road beneath it. Its motion,
            // perspective, shadow and headlights follow the final swipe.
            RepaintBoundary(
              key: const ValueKey('onboarding-layer-road-car'),
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) =>
                    _RoadCarMotion(progress: _scrollProgress),
              ),
            ),
            // LAYER 2: clouds 1, 2, 3 and 5, above the landscape and below
            // the animated main plane.
            AnimatedBuilder(
              key: const ValueKey('onboarding-layer-2-back-clouds'),
              animation: _pageController,
              builder: (context, _) => _CloudOverlay(
                progress: _scrollProgress,
                cloudFiles: const [
                  'cloud 1.png',
                  'cloud 2.png',
                  'cloud 3.png',
                  'cloud 5.png',
                ],
              ),
            ),
            // LAYER 3: the main plane, above the four back clouds.
            RepaintBoundary(
              key: const ValueKey('onboarding-layer-3-main-plane'),
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) =>
                    _MainPlaneMotion(progress: _scrollProgress),
              ),
            ),
            // LAYER 4: cloud 4 alone, above the animated main plane.
            AnimatedBuilder(
              key: const ValueKey('onboarding-layer-4-front-cloud'),
              animation: _pageController,
              builder: (context, _) => _CloudOverlay(
                progress: _scrollProgress,
                cloudFiles: const ['cloud 4.png'],
              ),
            ),
            // LAYER 5: all localized title and body text. The flight-path and
            // Next controls follow this content layer so they remain usable.
            // The slides always advance left-to-right, in every language.
            // A PageView follows the ambient direction, which would reverse
            // the swipe in Arabic and Kurdish — and the panorama and the
            // flight path behind it do not reverse, so the photo would pan
            // one way while the pages slid the other. Each slide's own
            // content is put back into the reading direction below, so only
            // the paging is forced, never the text.
            Directionality(
              key: const ValueKey('onboarding-layer-5-text'),
              textDirection: TextDirection.ltr,
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  Directionality(
                    textDirection: Directionality.of(context),
                    child: _Slide(
                      index: 0,
                      languageCode: widget.languageCode,
                      animation: _introController,
                      metrics: metrics,
                      pageController: _pageController,
                      currentPage: _currentPage,
                      titleLine1: l10n.onboardingTitleLine1,
                      titleLine2: l10n.onboardingTitleLine2,
                      body: l10n.onboardingBody1,
                      titleMotion: _TitleMotion.fadeScale,
                    ),
                  ),
                  Directionality(
                    textDirection: Directionality.of(context),
                    child: _Slide(
                      index: 1,
                      languageCode: widget.languageCode,
                      animation: _introController,
                      metrics: metrics,
                      pageController: _pageController,
                      currentPage: _currentPage,
                      titleLine1: l10n.onboardingTitle2Line1,
                      titleLine2: l10n.onboardingTitle2Line2,
                      body: l10n.onboardingBody2,
                      titleMotion: _TitleMotion.scaleBlur,
                    ),
                  ),
                  Directionality(
                    textDirection: Directionality.of(context),
                    child: _Slide(
                      index: 2,
                      languageCode: widget.languageCode,
                      animation: _introController,
                      metrics: metrics,
                      pageController: _pageController,
                      currentPage: _currentPage,
                      titleLine1: l10n.onboardingTitle3Line1,
                      titleLine2: l10n.onboardingTitle3Line2,
                      body: l10n.onboardingBody3,
                      titleMotion: _TitleMotion.scaleBlur,
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: metrics.trackBottom,
                    height: _trackHeight,
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) =>
                          _PlaneTrack(progress: _scrollProgress),
                    ),
                  ),
                  PositionedDirectional(
                    end: _SlideMetrics.buttonEndInset,
                    bottom: _SlideMetrics.bottomInset,
                    width: _SlideMetrics.buttonWidth,
                    height: _SlideMetrics.buttonHeight,
                    child: _NextButton(
                      label: l10n.onboardingNext,
                      mirrorArrow: isRtl,
                      onTap: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the final Next-button action as deliberate as the two page changes
/// while preserving Flutter's normal Material route transition.
class _OnboardingExitRoute<T> extends MaterialPageRoute<T> {
  _OnboardingExitRoute({required super.builder, required this.duration});

  final Duration duration;

  @override
  Duration get transitionDuration => duration;
}

/// Geometry and type sizes for the slides, resolved once per build.
///
/// The body copy is **measured** rather than assumed, and the flight path is
/// then placed above whatever height it actually came out at. Pinning the
/// track at a fixed offset instead is what let the copy grow up into the line
/// and the plane on small screens: the narrower the phone, the more lines the
/// paragraph wraps to, and the further up it reached.
///
/// The measurement covers *every* slide's copy, not just the current one, so
/// the track holds still while swiping instead of hopping between slides.
@immutable
class _SlideMetrics {
  const _SlideMetrics({
    required this.titleTop,
    required this.bodyStyle,
    required this.bodyBottom,
    required this.bodyEnd,
    required this.trackBottom,
  });

  /// Distance from the bottom safe-area edge to the button.
  static const double bottomInset = 24;

  /// The strip the flight path is drawn in. Taller than the artwork needs,
  /// because the plane swings up out of the line as it rotates into take-off
  /// and would otherwise be clipped at the top. [_trackGap] is reduced by the
  /// same amount, so the dotted line itself stays exactly where it was.
  static const double trackHeight = 60;

  /// Clear space between the top of the copy and the bottom of the track.
  static const double _trackGap = 4;

  static const double buttonWidth = 68;

  /// 48 is the minimum comfortable touch target, so the button is not made
  /// any shorter than this.
  static const double buttonHeight = 48;
  static const double buttonEndInset = 24;

  /// Side margins for the title and the copy.
  static const double textStart = 30;
  static const double textEnd = 24;

  static const double titleSize1 = 58;
  static const double titleSize2 = 45;
  static const double titleSize2LastSlide = 55;

  /// Slide 2 inverts the emphasis of the other slides: the region's name is
  /// the headline and the verb above it is the smaller line.
  static const double titleSize1Slide2 = titleSize2;
  static const double titleSize2Slide2 = titleSize1;

  /// The header block reserves one height for every slide, so it has to
  /// budget for the tallest line 2 in use.
  static const double titleSize2Max = titleSize2Slide2;
  static const double titleDownOffset = 40;
  static const double bodySize = 19;
  static const double bodyLineHeight = 1.32;

  /// Adobe-style Drop Shadow used by every visible onboarding text layer.
  ///
  /// A 138° light angle places the shadow down-right at this offset when
  /// converted to Flutter's screen coordinates. Black at 66% alpha produces
  /// the same result as a black Multiply shadow. Flutter's [Shadow] has no
  /// independent spread/choke parameter, so the requested 2% spread is
  /// represented within the 16px blur falloff.
  static const List<Shadow> textDropShadow = [
    Shadow(
      color: Color(0xA8000000),
      offset: Offset(8.1746, 7.3604),
      blurRadius: 16,
    ),
  ];

  /// Breathing room required between the title and the block below it.
  static const double _minTitleGap = 20;

  /// How far the copy may be scaled down before it is allowed to stay big and
  /// simply take the space it needs.
  static const double _minFontScale = 0.78;

  final double titleTop;
  final TextStyle bodyStyle;

  /// Offset of the copy's baseline block from the bottom safe-area edge.
  ///
  /// Set so the copy's **last** line sits level with the Next button and every
  /// line above it clears the button's top edge — the arrangement the
  /// reference shows, and the same on every screen size and in every
  /// language, because it is derived from the line height rather than fixed.
  final double bodyBottom;

  /// Inset at the far end of the copy. Normally [textEnd], but widened to
  /// clear the Next button entirely when no font size can keep the lines out
  /// of its way.
  final double bodyEnd;

  /// Offset of the flight path from the bottom safe-area edge.
  final double trackBottom;

  static TextStyle bodyStyleFor(String languageCode, double fontSize) {
    return TextStyle(
      fontFamily: AppTheme.fontFamilyForCode(languageCode),
      fontSize: fontSize,
      height: bodyLineHeight,
      fontWeight: FontWeight.w400,
      color: AppColors.onPhotoBackground,
      shadows: textDropShadow,
    );
  }

  static _SlideMetrics resolve(
    BuildContext context, {
    required List<String> bodyTexts,
    required String languageCode,
  }) {
    final media = MediaQuery.of(context);
    final direction = Directionality.of(context);
    final scaler = media.textScaler;

    final safeHeight =
        media.size.height -
        media.padding.top -
        math.max(media.padding.bottom, 8.0);
    final safeWidth =
        media.size.width - media.padding.left - media.padding.right;

    // Space the copy must leave free at its far end for the Next button. The
    // measurements below are all widths from the start edge, so this works
    // unchanged in right-to-left languages, where the button sits on the left
    // and the lines run towards it.
    final buttonReserve = buttonEndInset + buttonWidth + 12;
    final widthClearOfButton = safeWidth - textStart - buttonReserve;

    final compact = safeHeight < 700;
    // The complete two-line header is intentionally lowered by the same
    // amount on every slide and in every language.
    final titleTop = (compact ? 24.0 : 48.0) + titleDownOffset;
    final titleHeight = scaler.scale(titleSize1) * 0.92 + 8 + titleSize2Max;

    var fontScale = 1.0;
    // Normally the copy runs nearly the full width, as in the reference, and
    // only the lines level with the button have to stay clear of it. If no
    // font size can achieve that — which happens when a translation is much
    // wider than the English — the whole block is narrowed instead, so an
    // overlap becomes structurally impossible rather than merely unlikely.
    var reserveButtonColumn = false;
    var bodyStyle = bodyStyleFor(languageCode, bodySize);
    var bodyHeight = 0.0;
    var bodyEnd = textEnd;
    var bodyBottom = bottomInset;

    while (true) {
      bodyEnd = reserveButtonColumn ? buttonReserve : textEnd;
      final bodyWidth = safeWidth - textStart - bodyEnd;
      bodyStyle = bodyStyleFor(languageCode, bodySize * fontScale);

      // Drop the copy so its last line lands level with the button and every
      // line above it clears the button's top. Derived from the line height,
      // so the arrangement holds at any font size, screen or language.
      final lineHeight = scaler.scale(bodySize * fontScale) * bodyLineHeight;
      bodyBottom = math.max(
        bottomInset,
        bottomInset + buttonHeight - lineHeight,
      );
      final buttonTopAboveCopy = bottomInset + buttonHeight - bodyBottom;

      bodyHeight = 0;
      var hitsButton = false;

      for (final text in bodyTexts) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: bodyStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: bodyWidth);

        final lines = painter.computeLineMetrics();
        final height = painter.height;
        final measuredLine = lines.isEmpty ? height : height / lines.length;

        for (var i = 0; i < lines.length; i++) {
          // A line sits beside the button whenever any part of it falls in the
          // button's band — that is, its *bottom* edge is above the button's
          // top edge. Testing the line's top edge instead lets a line that is
          // 90% inside the band through unchecked.
          final bottomFromBlockBottom = height - (i + 1) * measuredLine;
          if (bottomFromBlockBottom < buttonTopAboveCopy &&
              lines[i].width > widthClearOfButton) {
            hitsButton = true;
          }
        }

        bodyHeight = math.max(bodyHeight, height);
        painter.dispose();
      }

      // Narrowing the block already guarantees no line reaches the button.
      if (reserveButtonColumn) hitsButton = false;

      final blockHeight = bodyBottom + bodyHeight + _trackGap + trackHeight;
      final fitsUnderTitle =
          titleTop + titleHeight + _minTitleGap + blockHeight <= safeHeight;

      if (!hitsButton && fitsUnderTitle) break;
      if (fontScale > _minFontScale) {
        fontScale = math.max(_minFontScale, fontScale - 0.04);
        continue;
      }
      // Out of room to shrink: fall back to reserving the button's column and
      // start the size search again.
      if (hitsButton && !reserveButtonColumn) {
        reserveButtonColumn = true;
        fontScale = 1;
        continue;
      }
      break;
    }

    return _SlideMetrics(
      titleTop: titleTop,
      bodyStyle: bodyStyle,
      bodyBottom: bodyBottom,
      bodyEnd: bodyEnd,
      trackBottom: bodyBottom + bodyHeight + _trackGap,
    );
  }
}

/// How a slide's header arrives.
enum _TitleMotion {
  /// Slide one: fades in while scaling up.
  fadeScale,

  /// Slide two: scales up out of a Gaussian blur, over 0.45s.
  scaleBlur,
}

/// One onboarding slide: a two-line header at the top and body copy beneath
/// the flight path, each with its own entry motion.
///
/// Both slides share this, so a change to spacing or measurement applies to
/// every slide instead of being copied per screen.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.index,
    required this.languageCode,
    required this.animation,
    required this.metrics,
    required this.pageController,
    required this.currentPage,
    required this.titleLine1,
    required this.titleLine2,
    required this.body,
    required this.titleMotion,
  });

  /// Position in the deck, used to work out how far this slide has been
  /// swiped away when blurring its header out.
  final int index;

  final String languageCode;
  final Animation<double> animation;
  final _SlideMetrics metrics;
  final PageController pageController;
  final int currentPage;
  final String titleLine1;
  final String titleLine2;
  final String body;
  final _TitleMotion titleMotion;

  @override
  Widget build(BuildContext context) {
    final title = _Title(
      languageCode: languageCode,
      line1: titleLine1,
      line2: titleLine2,
      line1FontSize: index == 1
          ? _SlideMetrics.titleSize1Slide2
          : _SlideMetrics.titleSize1,
      line2FontSize: switch (index) {
        1 => _SlideMetrics.titleSize2Slide2,
        2 => _SlideMetrics.titleSize2LastSlide,
        _ => _SlideMetrics.titleSize2,
      },
    );

    // No background of its own: the shared panorama shows through from
    // behind the PageView.
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          PositionedDirectional(
            top: metrics.titleTop,
            start: _SlideMetrics.textStart,
            end: _SlideMetrics.textEnd,
            // Motion out wraps motion in: the header blurs away as the slide
            // is swiped off, on top of whatever brought it in.
            child: _BlurOut(
              pageController: pageController,
              index: index,
              currentPage: currentPage,
              child: switch (titleMotion) {
                _TitleMotion.fadeScale => _FadeScaleIn(
                  animation: animation,
                  child: title,
                ),
                _TitleMotion.scaleBlur => _ScaleBlurIn(
                  animation: animation,
                  child: title,
                ),
              },
            ),
          ),
          // Sizes itself to its content and grows upward. The flight path is
          // placed above the height this measures to, so the two stay clear
          // of each other whatever the screen size or system font scale.
          PositionedDirectional(
            start: _SlideMetrics.textStart,
            end: metrics.bodyEnd,
            bottom: metrics.bodyBottom,
            child: _OvershootIn(
              animation: animation,
              child: Text(
                body,
                textAlign: TextAlign.start,
                style: metrics.bodyStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A two-line header: line one in Corbel, line two in Unbounded.
class _Title extends StatelessWidget {
  const _Title({
    required this.languageCode,
    required this.line1,
    required this.line2,
    required this.line1FontSize,
    required this.line2FontSize,
  });

  final String languageCode;
  final String line1;
  final String line2;
  final double line1FontSize;
  final double line2FontSize;

  @override
  Widget build(BuildContext context) {
    final isEnglish = languageCode == 'en';
    // Unbounded and Corbel have no Arabic-script glyphs, so Kurdish and
    // Arabic fall back to the app's per-language font instead of rendering
    // as empty boxes.
    final fallbackFamily = AppTheme.fontFamilyForCode(languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScaleDownLine(
          child: Text(
            line1,
            style: TextStyle(
              fontFamily: isEnglish ? 'Plus Jakarta Sans' : fallbackFamily,
              fontSize: line1FontSize,
              height: 0.92,
              // Corbel Light / Dubai Light, both registered at weight 300.
              fontWeight: FontWeight.w300,
              color: AppColors.onPhotoBackground,
              shadows: _SlideMetrics.textDropShadow,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _FixedSizeLine(
          child: Text(
            line2,
            textScaler: TextScaler.noScaling,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: isEnglish ? 'Unbounded' : fallbackFamily,
              fontSize: line2FontSize,
              height: 1,
              fontWeight: FontWeight.w500,
              // Unbounded is a variable font whose weight axis defaults to
              // 400. `fontWeight` alone does not move a variable axis, so
              // without this the title renders Regular, not Medium.
              fontVariations: isEnglish
                  ? const [FontVariation('wght', 500)]
                  : null,
              color: AppColors.onPhotoBackground,
              shadows: _SlideMetrics.textDropShadow,
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps the emphasized second title line at its exact design size on every
/// device. It may extend beyond its layout box on an unusually narrow screen,
/// but it is never silently resized based on the phone width or text settings.
class _FixedSizeLine extends StatelessWidget {
  const _FixedSizeLine({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(alignment: AlignmentDirectional.centerStart, child: child);
  }
}

/// Keeps a title line on one line, shrinking it only if a translation is too
/// wide for the screen.
class _ScaleDownLine extends StatelessWidget {
  const _ScaleDownLine({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
  }
}

/// Title motion: fade in while scaling up.
class _FadeScaleIn extends StatelessWidget {
  const _FadeScaleIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  /// Runs over the first 75% of the 1600ms controller — 1200ms. Curves are
  /// applied with `transform` rather than a [CurvedAnimation], which would
  /// register a listener on the controller on every rebuild.
  static const Curve _curve = Interval(0, 0.75, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final t = _curve.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: lerpDouble(0.88, 1, t),
            alignment: AlignmentDirectional.centerStart,
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

/// Header motion in for slide two: scales up out of a Gaussian blur.
///
/// Runs over 450ms — the 0.45s in the spec — carved out of the front of the
/// shared 1600ms controller.
class _ScaleBlurIn extends StatelessWidget {
  const _ScaleBlurIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  /// 450ms of the 1600ms controller.
  static const Curve _curve = Interval(0, 0.28, curve: Curves.easeOutCubic);

  /// Blur the text starts behind, in logical pixels.
  static const double _fromSigma = 14;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final t = _curve.transform(animation.value);
        final scaled = Transform.scale(
          scale: lerpDouble(0.72, 1, t),
          alignment: AlignmentDirectional.centerStart.resolve(
            Directionality.of(context),
          ),
          child: inner,
        );
        if (t >= 1) return scaled;
        // A zero-sigma blur still costs a full filter pass, so it is skipped
        // entirely once the text has resolved.
        final sigma = _fromSigma * (1 - t);
        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
          child: scaled,
        );
      },
      child: child,
    );
  }
}

/// Header motion out: the text blurs away as its slide is swiped off.
///
/// Driven by the live scroll position rather than a timer, so it tracks the
/// finger — dragging half way and letting go blurs half way and clears again.
/// Full blur lands as the slide finishes leaving.
class _BlurOut extends StatelessWidget {
  const _BlurOut({
    required this.pageController,
    required this.index,
    required this.currentPage,
    required this.child,
  });

  final PageController pageController;
  final int index;
  final int currentPage;
  final Widget child;

  static const double _maxSigma = 14;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, inner) {
        final page =
            (pageController.hasClients &&
                pageController.position.hasContentDimensions)
            ? (pageController.page ?? currentPage.toDouble())
            : currentPage.toDouble();
        final away = (page - index).abs().clamp(0.0, 1.0);
        if (away == 0) return inner!;
        final sigma = _maxSigma * away;
        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
          child: inner,
        );
      },
      child: child,
    );
  }
}

/// Body motion: rises from below while scaling and un-rotating, overshooting
/// slightly past its resting position before settling.
class _OvershootIn extends StatelessWidget {
  const _OvershootIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  /// How far below its resting place the text starts, in logical pixels.
  static const double _riseFrom = 46;

  /// Starting tilt, in radians (about 3.4°).
  static const double _tiltFrom = 0.06;

  /// Starts 544ms in and runs to the end of the 1600ms controller, so the copy
  /// arrives while the title is still settling and finishes just after it.
  ///
  /// `easeOutBack` deliberately passes 1.0 and comes back — that overshoot is
  /// the point. Opacity gets its own non-overshooting curve, since an opacity
  /// above 1.0 is meaningless.
  static const Curve _motion = Interval(0.34, 1, curve: Curves.easeOutBack);
  static const Curve _fade = Interval(0.34, 0.62, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    // Mirror the tilt in right-to-left layouts so it reads the same way.
    final tiltSign = direction == TextDirection.rtl ? -1 : 1;
    final pivot = AlignmentDirectional.bottomStart.resolve(direction);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final motion = _motion.transform(animation.value);
        final remaining = 1 - motion;
        return Opacity(
          opacity: _fade.transform(animation.value).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _riseFrom * remaining),
            child: Transform.rotate(
              angle: _tiltFrom * remaining * tiltSign,
              alignment: pivot,
              child: Transform.scale(
                scale: lerpDouble(0.86, 1, motion),
                alignment: pivot,
                child: inner,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// The dotted flight path with the plane parked on the current slide's dot.
///
/// `line.png`, `plane.png` and `plane1.png` share one transparent 1080x1080
/// canvas. The three solid dots sit at the fractions below — measured from the
/// artwork itself, so the plane lands exactly on them.
///
/// `plane.png` is level flight and `plane1.png` is the take-off attitude. They
/// are the same aircraft rotated on the same canvas, so cross-fading between
/// them as the last slide scrolls in reads as the plane pitching into a climb.
class _PlaneTrack extends StatelessWidget {
  const _PlaneTrack({required this.progress});

  /// Continuous position in pages: 0.0 is the first dot, 2.0 the third.
  final double progress;

  static const String _assetRoot = 'assets/images/3 page';
  static const List<double> _dotFractions = [0.1546, 0.4991, 0.8440];

  /// Plane canvas width as a fraction of the line canvas width, chosen so the
  /// plane renders at the size shown in the reference image.
  ///
  /// Calibrated against the artwork rather than guessed: the aircraft fills
  /// 388 of `plane.png`'s 1080px canvas, and the reference draws it at about
  /// 21% of the track width, so the canvas is drawn at 0.212 / 0.359.
  static const double _planeScale = 0.590;

  /// How far the plane is raised above the dotted line, as a fraction of the
  /// track width. Both PNGs are drawn centred on the same canvas, which put
  /// the line straight through the middle of the aircraft; lifting the plane
  /// by this much leaves the line running clear underneath it.
  ///
  /// Derived from the artwork: the plane's silhouette reaches 65/1080 of its
  /// canvas below centre and the line is 19/1080 thick, so this clears both
  /// with a little air in between.
  static const double _planeLift = 0.058;

  /// Nose-up angle at the last dot, in radians (about 18°). The plane rotates
  /// smoothly into this over the final leg — one image, turned, rather than a
  /// swap between two drawings.
  static const double _takeOffAngle = 0.31;

  /// Half the aircraft's length as a fraction of the track width: 194 of
  /// `plane.png`'s 1080px canvas, scaled by [_planeScale]. Rotating about the
  /// centre swings the tail down by this much times sin(angle), so the lift is
  /// increased to match and the tail stays clear of the line.
  static const double _planeHalfLength = 0.106;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final trackWidth = (screenWidth * 0.37).clamp(130.0, 190.0);

    // Both PNGs are square canvases that are mostly empty; the surrounding
    // Stack clips them down to the thin strip that actually has artwork.
    final planeCanvas = trackWidth * _planeScale;

    final clamped = progress.clamp(0.0, (_dotFractions.length - 1).toDouble());
    final lower = clamped.floor();
    final upper = clamped.ceil();
    final dotFraction = lerpDouble(
      _dotFractions[lower],
      _dotFractions[upper],
      clamped - lower,
    )!;

    // The aircraft pitches into its climb over the final leg only: level for
    // the whole first hop, then rotating up as the last slide is scrolled in.
    final takeOff = (clamped - (_dotFractions.length - 2)).clamp(0.0, 1.0);

    // Climbing lifts the plane as well as tilting it, which is both what a
    // take-off looks like and exactly what keeps the dropping tail off the
    // line.
    final lift =
        _planeLift + _planeHalfLength * math.sin(_takeOffAngle * takeOff);

    return Center(
      child: SizedBox(
        width: trackWidth,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bandHeight = constraints.maxHeight;
            // The flight path always runs left-to-right, even in right-to-left
            // languages: it tracks progress through the slides, and the
            // artwork is drawn for that one direction.
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (bandHeight - trackWidth) / 2,
                    height: trackWidth,
                    child: Image.asset(
                      '$_assetRoot/line.png',
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.expand(),
                    ),
                  ),
                  // Drawn after the line, so it sits on top of it.
                  Positioned(
                    left: dotFraction * trackWidth - planeCanvas / 2,
                    top: (bandHeight - planeCanvas) / 2 - trackWidth * lift,
                    width: planeCanvas,
                    height: planeCanvas,
                    child: Transform.rotate(
                      // Negative is anticlockwise, which lifts the nose: the
                      // aircraft points right.
                      angle: -_takeOffAngle * takeOff,
                      child: Image.asset(
                        '$_assetRoot/plane.png',
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One wide landscape photo panned across all three slides, so swiping moves
/// through a single continuous scene instead of cutting between images.
///
/// The photo is 3 screens wide (3240x1920) and is split into equal thirds:
/// slide 1 shows the left third, slide 2 the middle, slide 3 the right. It is
/// laid out once at a fixed size and only *translated* as the pages scroll —
/// changing an offset repaints without re-running layout or re-decoding the
/// image, which is what keeps the pan smooth.
class _PanoramaBackground extends StatelessWidget {
  const _PanoramaBackground({required this.progress, required this.slideCount});

  /// Continuous scroll position in pages: 0.0 shows the left third, 2.0 the
  /// right third, and everything between pans smoothly.
  final double progress;

  final int slideCount;

  static const String _asset = 'assets/images/3 page/panorama.webp';
  static const String _nightAsset = 'assets/images/3 page/panorama night.webp';

  /// Natural pixel size of the panorama, and of one slide's third of it.
  static const double _imageWidth = 3240;
  static const double _imageHeight = 1920;
  static double get _sliceWidth => _imageWidth / 3;

  /// The image provider is `const` so all three slides share one decode: a
  /// new provider instance each frame would defeat the image cache.
  static ImageProvider provider({int? cacheHeight}) {
    const asset = AssetImage(_asset);
    if (cacheHeight == null) return asset;
    return ResizeImage(asset, height: cacheHeight, allowUpscaling: false);
  }

  static ImageProvider nightProvider({int? cacheHeight}) {
    const asset = AssetImage(_nightAsset);
    if (cacheHeight == null) return asset;
    return ResizeImage(asset, height: cacheHeight, allowUpscaling: false);
  }

  /// Gradually turns the daytime pixels into a darker, cooler dusk exposure
  /// before the night photo replaces them. Because this operates on the same
  /// day pixels, the transition reads as changing light rather than two
  /// differently exposed images sitting side by side.
  static ColorFilter _dayToDuskFilter(double progress) {
    final eased = Curves.easeInOutSine.transform(progress);
    final brightness = 1.0 - 0.42 * eased;
    final red = brightness * (1.0 - 0.18 * eased);
    final green = brightness * (1.0 - 0.05 * eased);
    final blue = brightness * (1.0 + 0.10 * eased);

    return ColorFilter.matrix([
      red,
      0,
      0,
      0,
      0,
      0,
      green,
      0,
      0,
      0,
      0,
      0,
      blue,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    // Scale so a single third always covers the screen in both directions.
    // Phones taller than 16:9 are covered by height, which crops a little off
    // each side rather than letterboxing.
    final scale = (size.height / _imageHeight) > (size.width / _sliceWidth)
        ? size.height / _imageHeight
        : size.width / _sliceWidth;

    final renderedWidth = _imageWidth * scale;
    final renderedHeight = _imageHeight * scale;
    final sliceWidth = _sliceWidth * scale;

    // Centre the current third on screen. Clamped so a rubber-band overscroll
    // at either end can't drag the photo's edge into view.
    final clamped = progress.clamp(0.0, (slideCount - 1).toDouble());
    final dx = size.width / 2 - (clamped + 0.5) * sliceWidth;
    final dy = (size.height - renderedHeight) / 2;

    // Crossfade the two identically aligned panoramas as one complete scene.
    // Page two settles at 100% day, page three at 100% night, and every point
    // between them is a uniform dusk blend without a moving vertical seam.
    final nightFadeProgress = (clamped - 1.0).clamp(0.0, 1.0);
    final nightOpacity = Curves.easeInOutSine.transform(nightFadeProgress);

    // Decoding above the size actually drawn wastes memory, so on smaller
    // screens the image is decoded down to the height it will be shown at.
    final targetHeightPx = (renderedHeight * media.devicePixelRatio).round();
    final cacheHeight = targetHeightPx < _imageHeight ? targetHeightPx : null;

    return ClipRect(
      child: Transform.translate(
        offset: Offset(dx, dy),
        transformHitTests: false,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: SizedBox(
            width: renderedWidth,
            height: renderedHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  key: const ValueKey('onboarding-day-to-dusk-grade'),
                  colorFilter: _dayToDuskFilter(nightFadeProgress),
                  child: Image(
                    image: provider(cacheHeight: cacheHeight),
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: AppColors.darkForestFloor),
                  ),
                ),
                Opacity(
                  opacity: nightOpacity,
                  child: Image(
                    image: nightProvider(cacheHeight: cacheHeight),
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A perspective-scaled car following the marked road on the night panorama.
///
/// Coordinates are measured directly on the 3240×1920 source image. The car
/// uses the panorama's exact cover scale, crop and scroll translation, so its
/// tyres stay registered to the road on every screen aspect ratio.
class _RoadCarMotion extends StatelessWidget {
  const _RoadCarMotion({required this.progress});

  final double progress;

  static const String _asset = 'assets/images/3 page/car - 3ed page.png';
  static const AssetImage provider = AssetImage(_asset);

  static const double _panoramaWidth = 3240;
  static const double _panoramaHeight = 1920;
  static const double _sliceWidth = _panoramaWidth / 3;

  // Centres of the supplied green and blue marks, with two controls following
  // the red road stroke between them.
  static const Offset _start = Offset(2900, 1293);
  static const Offset _control1 = Offset(2860, 1350);
  static const Offset _control2 = Offset(2750, 1460);
  static const Offset _end = Offset(2656, 1504);

  // The cutout faces mostly left before rotation is applied. Subtracting this
  // source heading from the path tangent keeps the car centred on the road as
  // it turns.
  static const double _assetForwardHeading = 2.92;

  static const double _startBoxWidth = 360;
  static const double _endBoxWidth = 360;
  static const double _assetAspectRatio = 1536 / 1024;
  static const Offset _roadAlignmentNudge = Offset.zero;

  static Offset _pointOnPath(double t) {
    final inverse = 1 - t;
    return _start * (inverse * inverse * inverse) +
        _control1 * (3 * inverse * inverse * t) +
        _control2 * (3 * inverse * t * t) +
        _end * (t * t * t);
  }

  static Offset _pathTangent(double t) {
    final inverse = 1 - t;
    return (_control1 - _start) * (3 * inverse * inverse) +
        (_control2 - _control1) * (6 * inverse * t) +
        (_end - _control2) * (3 * t * t);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final pageProgress = progress.clamp(0.0, 2.0);
    final rawMotion = (pageProgress - 1.0).clamp(0.0, 1.0);
    final motion = Curves.easeInOutSine.transform(rawMotion);

    final scale = (size.height / _panoramaHeight) > (size.width / _sliceWidth)
        ? size.height / _panoramaHeight
        : size.width / _sliceWidth;
    final renderedHeight = _panoramaHeight * scale;
    final renderedSliceWidth = _sliceWidth * scale;
    final dx = size.width / 2 - (pageProgress + 0.5) * renderedSliceWidth;
    final dy = (size.height - renderedHeight) / 2;

    final sourceBoxWidth = lerpDouble(_startBoxWidth, _endBoxWidth, motion)!;
    final boxWidth = sourceBoxWidth * scale;
    final boxHeight = boxWidth / _assetAspectRatio;

    final sourceAnchor = _pointOnPath(motion);
    final tangent = _pathTangent(motion);
    final endTangent = _pathTangent(1);
    final endLevelingAdjustment =
        _assetForwardHeading - math.atan2(endTangent.dy, endTangent.dx);
    final previousRotation =
        math.atan2(tangent.dy, tangent.dx) -
        _assetForwardHeading +
        endLevelingAdjustment;
    const rotation = 0.0;

    // Keep the requested fixed angle while retaining the rear's established
    // contact point. The car remains rigid: only its transform changes.
    final rearVector = Offset(sourceBoxWidth * 0.27, 0);
    Offset rotateVector(Offset vector, double angle) => Offset(
      vector.dx * math.cos(angle) - vector.dy * math.sin(angle),
      vector.dx * math.sin(angle) + vector.dy * math.cos(angle),
    );
    final frontAlignmentOffset =
        rotateVector(rearVector, previousRotation) -
        rotateVector(rearVector, rotation);
    final carAnchor = sourceAnchor + frontAlignmentOffset;

    final viewportAnchor = Offset(
      dx + carAnchor.dx * scale,
      dy + carAnchor.dy * scale,
    );

    return IgnorePointer(
      child: ClipRect(
        child: Transform.translate(
          key: const ValueKey('road-car-position'),
          offset: Offset(
            viewportAnchor.dx - boxWidth / 2 + _roadAlignmentNudge.dx,
            viewportAnchor.dy - boxHeight * 0.72 + _roadAlignmentNudge.dy,
          ),
          transformHitTests: false,
          child: Align(
            alignment: Alignment.topLeft,
            child: Transform.rotate(
              key: const ValueKey('road-car-rotation'),
              angle: rotation,
              alignment: const Alignment(0, 0.44),
              child: SizedBox(
                key: const ValueKey('road-car-size'),
                width: boxWidth,
                height: boxHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      key: const ValueKey('road-car-effects'),
                      painter: _RoadCarEffectsPainter(intensity: motion),
                    ),
                    Image(
                      key: const ValueKey('onboarding-road-car'),
                      image: provider,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.expand(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the car's contact shadow and warm headlight spill in the car's local
/// coordinate system, so both effects rotate and scale with the road tangent.
class _RoadCarEffectsPainter extends CustomPainter {
  const _RoadCarEffectsPainter({required this.intensity});

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.58)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.035);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.56, size.height * 0.70),
        width: size.width * 0.65,
        height: size.height * 0.17,
      ),
      shadow,
    );

    final lightStrength = 0.22 + 0.58 * intensity;
    _drawBeam(
      canvas,
      size,
      origin: const Offset(0.29, 0.57),
      upperTarget: const Offset(-0.42, 0.64),
      lowerTarget: const Offset(-0.25, 0.78),
      strength: lightStrength,
    );
    _drawBeam(
      canvas,
      size,
      origin: const Offset(0.44, 0.61),
      upperTarget: const Offset(-0.30, 0.70),
      lowerTarget: const Offset(-0.12, 0.84),
      strength: lightStrength * 0.82,
    );

    canvas.save();
    canvas.translate(-size.width * 0.03, size.height * 0.74);
    canvas.scale(1, 0.28);
    canvas.drawCircle(
      Offset.zero,
      size.width * 0.58,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(Offset.zero, size.width * 0.58, [
          const Color(0xFFFFE3A3).withValues(alpha: 0.16 * intensity),
          Colors.transparent,
        ]),
    );
    canvas.restore();
  }

  void _drawBeam(
    Canvas canvas,
    Size size, {
    required Offset origin,
    required Offset upperTarget,
    required Offset lowerTarget,
    required double strength,
  }) {
    final start = Offset(origin.dx * size.width, origin.dy * size.height);
    final upper = Offset(
      upperTarget.dx * size.width,
      upperTarget.dy * size.height,
    );
    final lower = Offset(
      lowerTarget.dx * size.width,
      lowerTarget.dy * size.height,
    );
    final target = Offset((upper.dx + lower.dx) / 2, (upper.dy + lower.dy) / 2);

    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(upper.dx, upper.dy)
        ..lineTo(lower.dx, lower.dy)
        ..close(),
      Paint()
        ..blendMode = BlendMode.screen
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.025)
        ..shader = ui.Gradient.linear(
          start,
          target,
          [
            Colors.white.withValues(alpha: 0.38 * strength),
            const Color(0xFFFFD784).withValues(alpha: 0.20 * strength),
            Colors.transparent,
          ],
          const [0, 0.34, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_RoadCarEffectsPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}

/// Five cloud canvases fixed to the shared 3240×1080 onboarding design.
///
/// Every source is a 1080×1080 image at 100% design scale. The supplied
/// coordinate identifies the exact centre of that image. X follows the
/// three-page horizontal scroll; Y stays fixed within the current screen.
class _CloudOverlay extends StatelessWidget {
  const _CloudOverlay({required this.progress, required this.cloudFiles});

  final double progress;
  final List<String> cloudFiles;

  static const double _designPageSize = 1080;
  static const String _assetRoot = 'assets/images/3 page';

  static const List<({String file, Offset centre})> _clouds = [
    (file: 'cloud 1.png', centre: Offset(2987, 103)),
    (file: 'cloud 2.png', centre: Offset(2200, 246)),
    (file: 'cloud 3.png', centre: Offset(1380, 105)),
    (file: 'cloud 4.png', centre: Offset(1062, 239)),
    (file: 'cloud 5.png', centre: Offset(100, 80)),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pageProgress = progress.clamp(0.0, 2.0);
    final nightTransition = Curves.easeInOutSine.transform(
      (pageProgress - 1.0).clamp(0.0, 1.0),
    );
    final cloudBrightness = 1.0 - 0.8 * nightTransition;

    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final cloud in _clouds)
              if (cloudFiles.contains(cloud.file))
                Transform.translate(
                  key: ValueKey(cloud.file),
                  offset: Offset(
                    cloud.centre.dx / _designPageSize * size.width -
                        pageProgress * size.width -
                        size.width / 2,
                    cloud.centre.dy / _designPageSize * size.height -
                        size.width / 2,
                  ),
                  transformHitTests: false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox.square(
                      // One 1080px source canvas equals one 1080px design page
                      // at 100% scale. Keeping this square preserves the image.
                      dimension: size.width,
                      child: _ScreenBlendAsset(
                        asset: '$_assetRoot/${cloud.file}',
                        brightness: cloudBrightness,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Loads one opaque cloud canvas and paints it with a true Screen blend.
///
/// Screen makes black contribute nothing while retaining the cloud's lighter
/// pixels over the already-painted panorama beneath this widget.
class _ScreenBlendAsset extends StatefulWidget {
  const _ScreenBlendAsset({required this.asset, required this.brightness});

  final String asset;
  final double brightness;

  @override
  State<_ScreenBlendAsset> createState() => _ScreenBlendAssetState();
}

class _ScreenBlendAssetState extends State<_ScreenBlendAsset> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;

    final stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, synchronousCall) {
        if (!mounted) return;
        setState(() => _image = info.image);
      },
      onError: (Object error, StackTrace? stackTrace) {
        debugPrint('Onboarding cloud failed to load (${widget.asset}): $error');
      },
    );

    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey(
        'cloud-brightness-${widget.asset}-${widget.brightness.toStringAsFixed(2)}',
      ),
      painter: _ScreenBlendPainter(_image, widget.brightness),
      size: Size.infinite,
    );
  }
}

class _ScreenBlendPainter extends CustomPainter {
  const _ScreenBlendPainter(this.image, this.brightness);

  final ui.Image? image;
  final double brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final source = image;
    if (source == null) return;

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.screen
        ..colorFilter = ColorFilter.matrix([
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])
        ..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_ScreenBlendPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.brightness != brightness;
}

/// The large plane that enters during page 1 → 2 and exits during page 2 → 3.
///
/// The supplied motion coordinates live on a separate 3240×1080 design
/// canvas made from three 1080×1080 pages. X is converted into the matching
/// location across the three runtime page widths; Y is converted into the
/// matching fraction of the runtime screen height. The PNG itself always
/// stays square, so adapting the path to a tall or short phone never distorts
/// the aircraft.
class _MainPlaneMotion extends StatelessWidget {
  const _MainPlaneMotion({required this.progress});

  final double progress;

  static const String _asset = 'assets/images/3 page/main plane.png';
  static const AssetImage provider = AssetImage(_asset);
  static const double _designPageSize = 1080;
  // Every position is the centre of the plane's transparent 1080×1080
  // canvas, measured on the complete 3240×1080 three-page design. Keeping
  // the centre as the transform origin makes the 40→140%→185% scale change
  // expand from the middle of the artwork without distorting it.
  static const Offset _firstStart = Offset(2300, 583);
  static const Offset _firstEnd = Offset(1620, 366);
  static const Offset _secondEnd = Offset(633, 149);

  static const double _firstScale = 0.40;
  static const double _secondScale = 1.40;
  static const double _thirdScale = 1.85;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pageProgress = progress.clamp(0.0, 2.0);

    final Offset designCentre;
    final double imageScale;
    if (pageProgress <= 1) {
      designCentre = Offset.lerp(_firstStart, _firstEnd, pageProgress)!;
      imageScale = lerpDouble(_firstScale, _secondScale, pageProgress)!;
    } else {
      final exitProgress = pageProgress - 1;
      designCentre = Offset.lerp(_firstEnd, _secondEnd, exitProgress)!;
      imageScale = lerpDouble(_secondScale, _thirdScale, exitProgress)!;
    }

    // Convert the global three-page X coordinate into the current viewport.
    // Subtracting pageProgress makes the image track the same continuous
    // scroll offset as the PageView and panorama.
    final viewportX =
        designCentre.dx / _designPageSize * size.width -
        pageProgress * size.width;
    final viewportY = designCentre.dy / _designPageSize * size.height;

    return IgnorePointer(
      child: ClipRect(
        child: Transform.translate(
          key: const ValueKey('main-plane-position'),
          offset: Offset(
            viewportX - size.width / 2,
            viewportY - size.height / 2,
          ),
          transformHitTests: false,
          child: Center(
            child: Transform.scale(
              key: const ValueKey('main-plane-scale'),
              scale: imageScale,
              alignment: Alignment.center,
              transformHitTests: false,
              child: SizedBox.square(
                dimension: size.width,
                child: Image(
                  image: provider,
                  key: const ValueKey('onboarding-main-plane'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass "next" pill in the bottom corner.
class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.label,
    required this.onTap,
    required this.mirrorArrow,
  });

  final String label;
  final VoidCallback onTap;

  /// Points the arrow towards the start edge in right-to-left languages.
  final bool mirrorArrow;

  /// Half the button's height, keeping it a pill.
  static const double _radius = _SlideMetrics.buttonHeight / 2;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(_radius),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.30),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.70),
                    width: 1.2,
                  ),
                ),
                child: Transform.scale(
                  scaleX: mirrorArrow ? -1 : 1,
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 30,
                    color: AppColors.onPhotoBackground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
