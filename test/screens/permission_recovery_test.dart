import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/services/app_permissions.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/permission_blocked_prompt.dart';

/// The channel `permission_handler` talks to. Mocking it is what lets a test
/// tell "the app asked the OS to open Settings" apart from "the app did not",
/// which is the whole point of the permanently-denied work.
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

/// Drives the prompt directly, so the five journeys can be exercised without
/// standing up a whole screen and its services.
class _Host extends StatelessWidget {
  const _Host({required this.outcome, required this.reason});

  final PermissionOutcome outcome;
  final String reason;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              // Mirrors what the real screens do: only a permanent denial
              // gets the recovery prompt.
              if (outcome.needsSettings) {
                await showPermissionBlockedPrompt(context, reason: reason);
              }
            },
            child: const Text('request'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const reason = 'Camera access is off.';

  /// Every `openAppSettings` call the app made during a test.
  late List<String> openedSettings;

  setUp(() {
    openedSettings = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
          openedSettings.add(call.method);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });

  /// MaterialApp resolves its localizations asynchronously, so the very first
  /// frame is empty — settle before looking for anything.
  Future<void> pumpHost(
    WidgetTester tester,
    PermissionOutcome outcome,
  ) async {
    // A phone-shaped surface, like the other screen tests: on the default
    // 800x600 the SnackBar lands below the viewport and cannot be touched.
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Host(outcome: outcome, reason: reason));
    await tester.pumpAndSettle();
    await tester.tap(find.text('request'));
    // Settle the SnackBar's entrance: until it has finished sliding in, its
    // action sits below the viewport and cannot be tapped, and its auto-dismiss
    // timer has not started.
    await tester.pumpAndSettle();
  }

  group('PermissionOutcome keeps the states distinct', () {
    test('granted is granted and needs no settings trip', () {
      expect(PermissionOutcome.granted.isGranted, isTrue);
      expect(PermissionOutcome.granted.needsSettings, isFalse);
    });

    test('a normal denial is recoverable by asking again', () {
      // The OS will still prompt next time, so sending the user to Settings
      // would be wrong advice.
      expect(PermissionOutcome.denied.isGranted, isFalse);
      expect(PermissionOutcome.denied.needsSettings, isFalse);
    });

    test('a permanent denial is the only one that needs Settings', () {
      expect(PermissionOutcome.permanentlyDenied.isGranted, isFalse);
      expect(PermissionOutcome.permanentlyDenied.needsSettings, isTrue);
    });

    test('unavailable is not reported to the user as a refusal', () {
      // Desktop, web, or an OS version without this permission.
      expect(PermissionOutcome.unavailable.isGranted, isFalse);
      expect(PermissionOutcome.unavailable.needsSettings, isFalse);
    });
  });

  group('what the user sees', () {
    testWidgets('granted shows no prompt at all', (tester) async {
      await pumpHost(tester, PermissionOutcome.granted);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(openedSettings, isEmpty);
    });

    testWidgets('a normal denial shows no Open Settings offer', (tester) async {
      // The distinction that matters: telling someone to open Settings when
      // the OS will simply ask again next time is wrong advice.
      await pumpHost(tester, PermissionOutcome.denied);
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsNothing);
      expect(find.byType(SnackBarAction), findsNothing);
      expect(openedSettings, isEmpty);
    });

    testWidgets('a permanent denial explains why and offers a way out', (
      tester,
    ) async {
      await pumpHost(tester, PermissionOutcome.permanentlyDenied);

      expect(find.byType(SnackBar), findsOneWidget);
      // The permission-specific line survives…
      expect(find.textContaining('Camera access is off.'), findsOneWidget);
      // …and the generic explanation of WHY asking again will not help.
      expect(
        find.textContaining('only be turned back on in your device settings'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
    });
  });

  group('the user decides, not the app', () {
    testWidgets('settings are never opened without a tap', (tester) async {
      // Showing the prompt must not itself navigate the user out of the app.
      await pumpHost(tester, PermissionOutcome.permanentlyDenied);

      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(openedSettings, isEmpty, reason: 'the app opened Settings itself');
      expect(find.text('request'), findsOneWidget);
    });

    testWidgets('choosing Open Settings asks the OS exactly once', (
      tester,
    ) async {
      await pumpHost(tester, PermissionOutcome.permanentlyDenied);

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(openedSettings, ['openAppSettings']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling leaves the user exactly where they were', (
      tester,
    ) async {
      await pumpHost(tester, PermissionOutcome.permanentlyDenied);
      expect(find.byType(SnackBar), findsOneWidget);

      // Declining is a valid choice: swipe the offer away. Nothing else may
      // happen — no navigation, no Settings, no permission asked again.
      await tester.fling(find.byType(SnackBar), const Offset(0, 200), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(openedSettings, isEmpty);
      expect(find.text('request'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppPermissions.openSettings', () {
    testWidgets('reports what the platform returned', (tester) async {
      expect(await AppPermissions.openSettings(), isTrue);
      expect(openedSettings, ['openAppSettings']);
    });

    testWidgets('returns false instead of throwing when the platform cannot', (
      tester,
    ) async {
      // A recovery path that crashes is worse than no recovery path.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissionChannel, (call) async {
            throw PlatformException(code: 'unavailable');
          });

      expect(await AppPermissions.openSettings(), isFalse);
    });
  });
}
