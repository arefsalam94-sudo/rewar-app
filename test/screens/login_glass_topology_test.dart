import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/login_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/register_screen.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_liquid_glass.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/auth_glass_field.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/liquid_glass_surface.dart';

/// Locks Login's glass topology to the one Register has always had:
///
///     NON-SHADER outer grouping
///         → independent real-glass Email field
///         → independent real-glass Password field
///
/// Wrapping those fields in a fifth real shader is the nested-glass condition
/// `01_DESIGN_SYSTEM_CANONICAL.md` §5 forbids, and it is what corrupted the
/// fields when the keyboard opened and moved the card.
void main() {
  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  );

  /// Every `AppLiquidGlass` that renders a *real* shader surface.
  Iterable<AppLiquidGlass> realGlass(WidgetTester tester) => tester
      .widgetList<AppLiquidGlass>(find.byType(AppLiquidGlass))
      .where((g) => g.useCanonicalGlass && g.layer == GlassLayer.surface);

  group('Login card', () {
    testWidgets('the outer card is a non-shader grouping', (tester) async {
      await tester.pumpWidget(host(const LoginScreen()));
      await tester.pumpAndSettle();

      // The card is the only AppLiquidGlass at radius 28 on this screen.
      final card = tester
          .widgetList<AppLiquidGlass>(find.byType(AppLiquidGlass))
          .singleWhere((g) => g.borderRadius == 28);

      expect(
        card.layer,
        GlassLayer.embedded,
        reason:
            'the outer Login card must not push a second real shader '
            'around the fields — see 01_DESIGN_SYSTEM_CANONICAL.md §5',
      );
      // Still the canonical renderer, still translucent — only the shader
      // went away. Radius, padding and content positioning are unchanged.
      expect(card.useCanonicalGlass, isTrue);
      expect(card.padding, const EdgeInsets.fromLTRB(20, 22, 20, 22));
    });

    testWidgets('the Email and Password fields keep their real glass', (
      tester,
    ) async {
      await tester.pumpWidget(host(const LoginScreen()));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<AuthGlassField>(
        find.byType(AuthGlassField),
      );
      expect(fields.length, 2, reason: 'Email and Password');

      // AuthGlassField is itself a real canonical surface per field. Demoting
      // the parent must never demote these.
      for (final field in fields) {
        expect(find.byWidget(field), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byType(AuthGlassField).first,
          matching: find.byType(CanonicalGlassShell),
        ),
        findsWidgets,
        reason: 'each field is still its own real canonical glass surface',
      );
    });

    testWidgets('no real-glass surface wraps another one', (tester) async {
      await tester.pumpWidget(host(const LoginScreen()));
      await tester.pumpAndSettle();

      for (final outer in realGlass(tester)) {
        final nested = find.descendant(
          of: find.byWidget(outer),
          matching: find.byType(AppLiquidGlass),
        );
        for (final inner in tester.widgetList<AppLiquidGlass>(nested)) {
          expect(
            inner.useCanonicalGlass && inner.layer == GlassLayer.surface,
            isFalse,
            reason: 'a real glass surface must not contain another one',
          );
        }
      }
    });
  });

  group('Register — the reference', () {
    testWidgets('has no real-glass grouping around its fields', (tester) async {
      await tester.pumpWidget(host(const RegisterScreen()));
      await tester.pumpAndSettle();

      // Register's outer grouping has always been a plain transparent
      // Container, so no AppLiquidGlass on the screen wraps another.
      for (final outer in realGlass(tester)) {
        final nested = find.descendant(
          of: find.byWidget(outer),
          matching: find.byType(AppLiquidGlass),
        );
        for (final inner in tester.widgetList<AppLiquidGlass>(nested)) {
          expect(
            inner.useCanonicalGlass && inner.layer == GlassLayer.surface,
            isFalse,
          );
        }
      }
    });
  });

  group('keyboard behaviour is preserved', () {
    testWidgets('Login still resizes for the keyboard', (tester) async {
      await tester.pumpWidget(host(const LoginScreen()));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(
        scaffold.resizeToAvoidBottomInset,
        isTrue,
        reason: 'the form must keep moving when the keyboard appears',
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('focusing a field keeps the same glass shell', (tester) async {
      await tester.pumpWidget(host(const LoginScreen()));
      await tester.pumpAndSettle();

      final shellsBefore = tester
          .widgetList<CanonicalGlassShell>(find.byType(CanonicalGlassShell))
          .length;

      await tester.tap(find.byType(AuthGlassField).first);
      await tester.pumpAndSettle();

      // Focus must not add, remove or swap a glass shell — focused and
      // unfocused are the same surface, only the cursor/text differ.
      expect(
        tester
            .widgetList<CanonicalGlassShell>(find.byType(CanonicalGlassShell))
            .length,
        shellsBefore,
      );
    });
  });
}
