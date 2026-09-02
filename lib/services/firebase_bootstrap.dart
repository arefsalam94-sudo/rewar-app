import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Initializes Firebase once at startup, without letting a missing/incomplete
/// Firebase configuration crash the whole app.
///
/// Configured against the `rewar-app-1c10e` project, whose options are
/// generated into `lib/firebase_options.dart` by `flutterfire configure`.
///
/// **Options are passed explicitly** rather than relying on the bare
/// `initializeApp()`, which reads the platform config files
/// (`google-services.json` / `GoogleService-Info.plist`) through native
/// plugins. Explicit options behave identically on every platform including
/// web and desktop, and they fail loudly at compile time if the generated file
/// is missing — rather than at runtime, on one platform, in a way that looks
/// like a network error.
///
/// If initialization still fails, we catch it, record it in [isReady], and let
/// the app keep running so the UI is viewable — every screen that needs the
/// backend checks [isReady] and shows a real error instead of pretending.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _ready = false;
  static Object? _error;

  /// True once Firebase initialized successfully.
  static bool get isReady => _ready;

  /// Why initialization failed, if it did (for logging, not for the user).
  static Object? get error => _error;

  static Future<void> ensureInitialized() async {
    if (_ready) return;

    // firebase_options.dart currently contains Android and iOS apps only.
    // Avoid touching currentPlatform elsewhere: its generated getter throws,
    // which can pause an IDE debugger even when the exception is caught.
    final isConfiguredPlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isConfiguredPlatform) {
      _ready = false;
      _error = UnsupportedError(
        'Firebase is not configured for the current platform.',
      );
      debugPrint(
        'Firebase is not configured for this platform; using preview mode.',
      );
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
      _error = null;
    } catch (e, s) {
      _ready = false;
      _error = e;
      debugPrint(
        'Firebase not initialized — backend features are unavailable.\n'
        'Finish the steps in FIREBASE_SETUP.md.\n$e\n$s',
      );
    }
  }
}
