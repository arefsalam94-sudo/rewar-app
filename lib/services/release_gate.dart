import 'package:flutter/foundation.dart';

/// Whether the app may run its **simulated** flows.
///
/// Two features are still stand-ins for a backend that does not exist yet:
/// the mock flight offers in `MockFlightResultsService`, and the preview hotel
/// reservation created at the end of checkout. Both exist so unfinished
/// screens stay reviewable during development.
///
/// Shipping them is a different thing entirely. A release user cannot tell a
/// simulated fare from a real one, or a preview reservation from a room that
/// was actually held — so in a release build they must not run at all. What is
/// honest in development becomes a false statement to a paying customer.
///
/// ## Release cannot be overridden
///
/// The test override is applied inside an `assert` body, and Dart strips
/// assert bodies from release builds. [debugSetPreviewFeaturesAllowed]
/// therefore compiles down to an empty method there, `_override` stays null
/// for the life of the process, and [previewFeaturesAllowed] can only ever
/// return `kDebugMode` — which is false. There is no flag, no environment
/// variable and no code path that turns these flows back on in a shipped
/// build.
class ReleaseGate {
  ReleaseGate._();

  /// Null in release, always. See the class doc.
  static bool? _override;

  /// True in debug (and under `flutter test`), false in release and profile.
  static bool get previewFeaturesAllowed => _override ?? kDebugMode;

  /// Test-only. Pass null to restore the real build-mode answer.
  ///
  /// Tests run in debug, so proving the *release* behaviour needs this seam —
  /// there is no other way to exercise the shipped path from a test.
  @visibleForTesting
  static void debugSetPreviewFeaturesAllowed(bool? value) {
    assert(() {
      _override = value;
      return true;
    }());
  }
}
