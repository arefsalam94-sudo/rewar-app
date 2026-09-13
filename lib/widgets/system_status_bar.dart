import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How bright the thing actually drawn *behind the system status bar* is on a
/// screen — the semantic input the whole status-bar contrast rule turns on.
///
/// This is a statement about the top strip of that screen, **not** about the
/// app theme. A bright street map is [light] even while the app runs in Dark
/// mode; Home's photograph under its gradient wash is [dark] in both modes.
/// Screens whose top edge is simply the theme's own gradient can derive it
/// with [ofTheme] instead of choosing.
enum StatusBarBackdrop {
  /// A bright/light top area → dark (near-black) clock, Wi-Fi, battery and
  /// Bluetooth glyphs.
  light,

  /// A dark or photo-heavy top area → white glyphs.
  dark;

  /// The backdrop of a screen whose top strip is the theme's own surface or
  /// gradient: pale in Light mode, deep emerald in Dark. This is what
  /// [PageBackground] assumes when a screen does not say otherwise.
  static StatusBarBackdrop ofTheme(BuildContext context) =>
      ofBrightness(Theme.of(context).brightness);

  /// [ofTheme] for a brightness a caller already resolved (screens that flip
  /// their own subtree's `ThemeData`, or a widget test's `dark:` override).
  static StatusBarBackdrop ofBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// What a screen wants done with the Android navigation bar, kept separate
/// from the status-bar decision so a contrast fix can never move it by
/// accident.
enum SystemNavBarTreatment {
  /// Leave the navigation bar exactly as it already is. Null fields are
  /// skipped by the platform channel, so nothing about it is re-sent.
  unchanged,

  /// Opaque black bar with light icons — Flutter's own default for
  /// [SystemUiOverlayStyle.light]/[SystemUiOverlayStyle.dark], and what the
  /// photographic page shell has always sent.
  opaqueBlack,

  /// Transparent bar with light icons, for edge-to-edge screens that draw
  /// their own floating bar over the gesture area (Home, onboarding).
  transparent,
}

/// The system-UI style that keeps the status-bar glyphs readable on top of
/// [backdrop].
///
/// Android reads `statusBarIconBrightness`; iOS reads `statusBarBrightness`,
/// which describes the *background* and is therefore the inverse of it. Both
/// values are taken from Flutter's own paired constants rather than written
/// out per screen, so the two platforms cannot drift apart:
/// - [StatusBarBackdrop.light] → `statusBarIconBrightness: Brightness.dark`
///   (Android) + `statusBarBrightness: Brightness.light` (iOS)
/// - [StatusBarBackdrop.dark] → `statusBarIconBrightness: Brightness.light`
///   (Android) + `statusBarBrightness: Brightness.dark` (iOS)
SystemUiOverlayStyle systemOverlayStyleFor(
  StatusBarBackdrop backdrop, {
  SystemNavBarTreatment navigationBar = SystemNavBarTreatment.unchanged,
}) {
  final base = switch (backdrop) {
    // "Overlays drawn with a dark color. Intended for applications with a
    // light background" — i.e. dark glyphs.
    StatusBarBackdrop.light => SystemUiOverlayStyle.dark,
    // The reverse: white glyphs for a dark background.
    StatusBarBackdrop.dark => SystemUiOverlayStyle.light,
  };
  return switch (navigationBar) {
    // Only the status-bar fields are populated; the navigation-bar fields stay
    // null and the platform leaves that bar untouched.
    SystemNavBarTreatment.unchanged => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: base.statusBarIconBrightness,
      statusBarBrightness: base.statusBarBrightness,
    ),
    SystemNavBarTreatment.opaqueBlack => base.copyWith(
      statusBarColor: Colors.transparent,
    ),
    SystemNavBarTreatment.transparent => base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  };
}

/// Declares the status-bar contrast for the screen inside it.
///
/// Wrap a screen's root (usually its `Scaffold`) and name the backdrop the top
/// strip really has:
///
/// ```dart
/// // A bright map fills the screen, so the clock and battery must be dark.
/// SystemStatusBar(
///   backdrop: StatusBarBackdrop.light,
///   child: Scaffold(body: ...),
/// )
/// ```
///
/// Screens built on [PageBackground] get this for free and should pass
/// `statusBarBackdrop` to it instead of adding a second region — the innermost
/// annotation is the one the engine reads, so an outer wrapper would be
/// silently ignored.
class SystemStatusBar extends StatelessWidget {
  const SystemStatusBar({
    super.key,
    required this.backdrop,
    required this.child,
    this.navigationBar = SystemNavBarTreatment.unchanged,
  });

  /// The brightness of what is drawn behind the status bar here.
  final StatusBarBackdrop backdrop;

  /// Whether this screen also has something to say about the navigation bar.
  /// Defaults to leaving it alone.
  final SystemNavBarTreatment navigationBar;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(backdrop, navigationBar: navigationBar),
      child: child,
    );
  }
}
