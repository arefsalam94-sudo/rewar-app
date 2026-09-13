import 'package:flutter/material.dart';

/// The app-wide scroll behaviour, installed once on `MaterialApp`.
///
/// Its only job is to keep Android's **stretch overscroll** away from real
/// Liquid Glass surfaces. Scrolling itself is untouched: physics, gestures,
/// fling, nested scrollables, scrollbars and overscroll *notifications* all
/// stay exactly as Flutter ships them.
///
/// ## Why this exists — the black-band bug
///
/// Every real glass surface is an `OCLiquidGlass`, and `oc_liquid_glass`
/// renders it by pushing a `BackdropFilterLayer` with `ImageFilter.shader(…)`.
/// A backdrop filter blurs and refracts **whatever has already been painted
/// behind it** — on these screens, the `PageBackground` photograph and gradient
/// that sit *outside* the scroll view.
///
/// On Android with Material 3, `MaterialScrollBehavior` wraps every scrollable
/// in a `StretchingOverscrollIndicator`. While the user is pulling against an
/// edge, that indicator wraps the scrolling content in
/// `ImageFiltered(imageFilter: ImageFilter.shader(stretch_effect.frag))`
/// (`flutter/src/widgets/stretch_effect.dart`), which pushes an
/// **`ImageFilterLayer` — an offscreen save-layer**.
///
/// The glass surfaces are painted *into* that offscreen layer. Their backdrop
/// filter can therefore only sample the offscreen texture, and the background
/// photograph is not in it: it was painted earlier, outside the layer. The
/// shader samples transparent black, blurs and refracts it, and the surface
/// renders as a solid or near-solid **black bar**. It compounds because
/// `oc_liquid_glass` computes its sampling boundary from `getTransformTo(null)`
/// — scene coordinates — which no longer describe where the surface landed once
/// the stretch shader has remapped it.
///
/// That is also why the corruption is strictly tied to overscroll:
/// `StretchEffect` passes `enabled: stretchStrength.abs() > tolerance`, so the
/// offscreen layer exists *only* while the edge is being pulled. At rest there
/// is no extra layer and the glass is correct.
///
/// Removing the indicator removes the offscreen layer, so the backdrop filter
/// keeps sampling the real scene in every scroll state.
///
/// ## What this does and does not change
///
/// - **Android / Fuchsia:** no stretch transform and no glow at the edges.
///   Scrolling, flinging and bouncing off the end all still work — Android's
///   `ClampingScrollPhysics` is what stops the list at its edge, and that is
///   inherited untouched.
/// - **iOS / macOS / desktop / web:** unchanged. `MaterialScrollBehavior`
///   already returns the child unmodified on those platforms, so `super` is
///   called and iOS keeps its native bounce.
/// - **`RefreshIndicator`:** unaffected. It drives itself from
///   `ScrollUpdateNotification` / `OverscrollNotification`, which come from the
///   scroll *physics*, not from the indicator. Its one link to the indicator is
///   `OverscrollIndicatorNotification.disallowIndicator()`, which merely hides
///   a glow it is standing in front of; with no indicator that notification
///   simply never arrives.
/// - **Scroll physics are not overridden.** `getScrollPhysics` is inherited, so
///   overscroll is still *reported* — only the visual transform is gone.
///
/// See `UI_TRANSFER_PACKAGE/docs/01_DESIGN_SYSTEM_CANONICAL.md` §3.8 for the
/// design-system rule this implements.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior({this.allowAndroidOverscrollIndicator = false});

  /// Escape hatch for a screen that genuinely needs Android's overscroll
  /// indicator back — a surface with **no real glass inside the scrollable**
  /// whose design depends on the stretch.
  ///
  /// Do not reach for this to "fix" a glass screen: restoring the stretch
  /// restores the black bands. Wrap only that subtree, and document it in
  /// `07_DESIGN_EXCEPTIONS.md`:
  ///
  /// ```dart
  /// ScrollConfiguration(
  ///   behavior: const AppScrollBehavior(allowAndroidOverscrollIndicator: true),
  ///   child: theScrollable,
  /// )
  /// ```
  ///
  /// No screen uses it today.
  final bool allowAndroidOverscrollIndicator;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (allowAndroidOverscrollIndicator) {
      return super.buildOverscrollIndicator(context, child, details);
    }
    switch (getPlatform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        // The whole point: no StretchingOverscrollIndicator, therefore no
        // ImageFilterLayer between a glass surface and the scene it samples.
        return child;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        // Already a no-op on these platforms — deferring keeps it that way if
        // Flutter ever changes its mind.
        return super.buildOverscrollIndicator(context, child, details);
    }
  }
}
