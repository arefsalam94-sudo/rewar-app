import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_liquid_glass.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_recessed_glass_field.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/recessed_liquid_glass_field.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
        ),
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('uses the shared authoritative glass surface for every shape', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLiquidGlass(child: SizedBox(width: 160, height: 64)),
            AppLiquidGlass(
              shape: AppLiquidGlassShape.pill,
              quality: AppLiquidGlassQuality.premium,
              child: SizedBox(width: 120, height: 48),
            ),
            AppLiquidGlass(
              shape: AppLiquidGlassShape.circle,
              selected: true,
              child: SizedBox.square(dimension: 48),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(AppLiquidGlass), findsNWidgets(3));
    expect(find.byType(GlassPanel), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('recessed field keeps a functional TextFormField', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 320,
          child: AppRecessedGlassField(
            controller: controller,
            hint: 'Email',
            prefixIcon: Icons.mail_outline,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'hello@example.com');
    expect(controller.text, 'hello@example.com');
    expect(find.byType(RecessedLiquidGlassField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
