import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/firebase_options.dart';

/// Guards the generated Firebase config against the mistakes that are silent
/// at build time and only surface as "permission denied" or an empty app on a
/// device: a regenerated file pointing at the wrong project, a mismatched
/// sender id between platforms, or a platform block quietly dropped.
///
/// These values are **not secrets** — `SECURITY.md` section 4 is explicit that
/// the client config is a public project identifier. Security comes from the
/// rules, so asserting them here leaks nothing.
void main() {
  const projectId = 'rewar-app-1c10e';
  const messagingSenderId = '5280763166';
  const storageBucket = 'rewar-app-1c10e.firebasestorage.app';

  final android = DefaultFirebaseOptions.android;
  final ios = DefaultFirebaseOptions.ios;

  group('every configured platform points at the same project', () {
    test('android', () {
      expect(android.projectId, projectId);
      expect(android.messagingSenderId, messagingSenderId);
      expect(android.storageBucket, storageBucket);
    });

    test('ios', () {
      expect(ios.projectId, projectId);
      expect(ios.messagingSenderId, messagingSenderId);
      expect(ios.storageBucket, storageBucket);
    });

    test('the two platforms agree on project and sender', () {
      // A mismatch here means one platform talks to a different Firebase
      // project — the data simply would not be there, with no build error.
      expect(android.projectId, ios.projectId);
      expect(android.messagingSenderId, ios.messagingSenderId);
      expect(android.storageBucket, ios.storageBucket);
    });
  });

  group('per-platform identity is distinct', () {
    test('app ids differ and name their platform', () {
      expect(android.appId, isNot(ios.appId));
      expect(android.appId, contains(':android:'));
      expect(ios.appId, contains(':ios:'));
    });

    test('api keys differ', () {
      // Android and iOS are separate Firebase apps with separate keys; sharing
      // one is a sign the file was hand-edited.
      expect(android.apiKey, isNot(ios.apiKey));
    });

    test('both api keys are populated', () {
      expect(android.apiKey, isNotEmpty);
      expect(ios.apiKey, isNotEmpty);
    });

    test('ios carries the bundle id the Xcode project uses', () {
      expect(
        ios.iosBundleId,
        'com.kurdistanparadise.kurdistanParadiseTravelGuide',
      );
    });
  });

  group('currentPlatform', () {
    test('resolves for android and ios', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(DefaultFirebaseOptions.currentPlatform.appId, android.appId);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(DefaultFirebaseOptions.currentPlatform.appId, ios.appId);

      debugDefaultTargetPlatformOverride = null;
    });

    test('throws on a platform that was never configured', () {
      // FirebaseBootstrap checks the platform *before* touching this getter
      // precisely because it throws; this pins that it still does, so the
      // guard there cannot be removed as redundant.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(() => DefaultFirebaseOptions.currentPlatform, throwsUnsupportedError);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
