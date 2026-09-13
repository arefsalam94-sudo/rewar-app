import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/main.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_scroll_behavior.dart';

/// Guards the fix for the Android stretch-overscroll black-band bug.
///
/// The corruption comes from the `ImageFilterLayer` that
/// `StretchingOverscrollIndicator` pushes while an edge is being pulled: a real
/// Liquid Glass surface inside it can no longer sample the page background, so
/// its backdrop filter blurs transparent black into black bars. These tests
/// assert the indicator is gone on Android and that nothing else about
/// scrolling went with it.
void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  Widget listApp({
    ScrollBehavior? behavior,
    ScrollController? controller,
    Future<void> Function()? onRefresh,
  }) {
    Widget list = ListView.builder(
      controller: controller,
      itemCount: 60,
      itemBuilder: (context, i) => SizedBox(height: 40, child: Text('row $i')),
    );
    if (onRefresh != null) {
      list = RefreshIndicator(onRefresh: onRefresh, child: list);
    }
    return MaterialApp(
      scrollBehavior: behavior,
      home: Scaffold(body: list),
    );
  }

  group('AppScrollBehavior on Android', () {
    testWidgets("Flutter's default really does install the stretch indicator", (
      tester,
    ) async {
      // The "before" half of the fix. If this ever stops finding one, the
      // premise of this whole file has changed and the fix needs re-deriving.
      await tester.pumpWidget(listApp());
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
    }, variant: android);

    testWidgets('AppScrollBehavior removes it', (tester) async {
      await tester.pumpWidget(listApp(behavior: const AppScrollBehavior()));
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    }, variant: android);

    testWidgets('no stretch layer appears while pulling against the edge', (
      tester,
    ) async {
      await tester.pumpWidget(listApp(behavior: const AppScrollBehavior()));

      // Pull down past the top — the exact gesture that produced the black
      // bands. Held mid-drag, which is when the offscreen layer used to
      // exist.
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();

      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(StretchEffect), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(StretchEffect), findsNothing);
    }, variant: android);

    testWidgets('scrolling still works, in both directions', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        listApp(behavior: const AppScrollBehavior(), controller: controller),
      );

      expect(controller.offset, 0);
      await tester.fling(find.byType(ListView), const Offset(0, -400), 1200);
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));

      final scrolled = controller.offset;
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(scrolled));
    }, variant: android);

    testWidgets('the far end of a long list is still reachable', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        listApp(behavior: const AppScrollBehavior(), controller: controller),
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('row 59'), findsOneWidget);

      // And pulling past that edge neither crashes nor re-introduces a layer.
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.byType(StretchEffect), findsNothing);
      expect(controller.offset, controller.position.maxScrollExtent);
    }, variant: android);

    testWidgets('RefreshIndicator still fires', (tester) async {
      var refreshed = false;
      await tester.pumpWidget(
        listApp(
          behavior: const AppScrollBehavior(),
          onRefresh: () async => refreshed = true,
        ),
      );

      await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    }, variant: android);

    testWidgets('the escape hatch puts the indicator back', (tester) async {
      await tester.pumpWidget(
        listApp(
          behavior: const AppScrollBehavior(
            allowAndroidOverscrollIndicator: true,
          ),
        ),
      );
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
    }, variant: android);

    testWidgets(
      'Android keeps its clamping physics — they are not overridden',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          listApp(behavior: const AppScrollBehavior(), controller: controller),
        );

        // Clamping is what stops an Android list at its edge. Overscroll is
        // still *reported* by the physics — only the visual transform was
        // removed — which is why RefreshIndicator above still works.
        expect(controller.position.physics, isA<ClampingScrollPhysics>());
      },
      variant: android,
    );
  });

  group('the real app installs it', () {
    testWidgets('KurdistanParadiseApp puts AppScrollBehavior in the tree', (
      tester,
    ) async {
      // The fix is only worth anything if it is actually wired into the app
      // every screen runs under. Screen tests build their own MaterialApp, so
      // this is the one place that is checked.
      await tester.pumpWidget(const KurdistanParadiseApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Navigator).first);
      expect(ScrollConfiguration.of(context), isA<AppScrollBehavior>());

      // Splash runs a countdown timer; tear the tree down so it is cancelled.
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: android);
  });

  group('AppScrollBehavior on iOS', () {
    testWidgets('leaves iOS exactly as Material ships it', (tester) async {
      // iOS has no overscroll indicator to begin with — it bounces via
      // physics — so the assertion that matters is that the physics survive.
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        listApp(behavior: const AppScrollBehavior(), controller: controller),
      );

      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(
        controller.position.physics,
        isA<BouncingScrollPhysics>(),
        reason: 'iOS bounce must survive — only the Android indicator is gone',
      );

      await tester.fling(find.byType(ListView), const Offset(0, -400), 1200);
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
    }, variant: ios);
  });
}
