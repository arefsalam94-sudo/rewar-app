import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/ticket_card.dart';

void main() {
  group('TicketCard — the opaque ticket surface', () {
    testWidgets('uses already-approved brand tokens, not a new colour', (
      tester,
    ) async {
      // The screen introduces exactly one set of new colours — the status
      // pills. The card surface itself must reuse existing brand values, or
      // the "design system is locked" rule has been broken quietly.
      await _pump(tester, const TicketCard(child: SizedBox(height: 80)));
      expect(
        _surfaceColor(tester),
        AppColors.pageGradientTop,
        reason: 'light mode must reuse the brand mint',
      );

      await _pump(
        tester,
        const TicketCard(child: SizedBox(height: 80)),
        dark: true,
      );
      expect(
        _surfaceColor(tester),
        AppColors.darkGlassTop,
        reason: 'dark mode must reuse the approved wash colour',
      );
    });

    testWidgets('uses the shared 28px card radius in both themes', (
      tester,
    ) async {
      // Same precedent as the Home screen — dark mode is a different design
      // language, not a recolour.
      await _pump(tester, const SizedBox.shrink());
      final lightContext = tester.element(find.byType(SizedBox).first);
      expect(TicketCard.defaultRadius(lightContext), 28);

      await _pump(tester, const SizedBox.shrink(), dark: true);
      final darkContext = tester.element(find.byType(SizedBox).first);
      expect(TicketCard.defaultRadius(darkContext), 28);
    });

    testWidgets('clips its child, so the notch is a real cut-out', (
      tester,
    ) async {
      await _pump(
        tester,
        const TicketCard(notchFraction: 0.5, child: SizedBox(height: 120)),
      );

      expect(find.byType(ClipPath), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with and without notches', (tester) async {
      for (final fraction in <double?>[null, 0.0, 0.5, 1.0]) {
        await _pump(
          tester,
          TicketCard(
            notchFraction: fraction,
            child: const SizedBox(height: 90),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'fraction=$fraction');
      }
    });
  });

  group('WavySeamClipper — mirrors with the reading direction', () {
    test('the wave sits on the leading edge in each direction', () {
      const size = Size(200, 100);

      final ltr = const WavySeamClipper(
        textDirection: TextDirection.ltr,
      ).getClip(size);
      final rtl = const WavySeamClipper(
        textDirection: TextDirection.rtl,
      ).getClip(size);

      // LTR keeps the trailing (right) edge straight and waves on the left;
      // RTL is the mirror image. Comparing bounds is enough to catch a clipper
      // that forgot to mirror — the failure mode is a card that reads
      // backwards in Kurdish and Arabic.
      expect(ltr.getBounds().right, size.width);
      expect(rtl.getBounds().left, 0);
      expect(ltr.getBounds(), isNot(rtl.getBounds()));
    });

    test('reclips only when its inputs change', () {
      const clipper = WavySeamClipper(textDirection: TextDirection.ltr);
      expect(
        clipper.shouldReclip(
          const WavySeamClipper(textDirection: TextDirection.ltr),
        ),
        isFalse,
      );
      expect(
        clipper.shouldReclip(
          const WavySeamClipper(textDirection: TextDirection.rtl),
        ),
        isTrue,
      );
    });
  });

  group('StatusPill — the new tokens', () {
    testWidgets('each tone uses its documented fill and content colour', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          const Column(
            children: [
              StatusPill(label: 'CONFIRMED', tone: StatusTone.positive),
              StatusPill(label: 'ECONOMY', tone: StatusTone.informational),
              StatusPill(label: 'CANCELLED', tone: StatusTone.negative),
            ],
          ),
          dark: dark,
        );

        final context = tester.element(find.text('CONFIRMED'));

        expect(
          _pillFill(tester, 'CONFIRMED'),
          AppColors.statusSuccessFill(context),
          reason: 'dark=$dark',
        );
        expect(
          _pillFill(tester, 'ECONOMY'),
          AppColors.statusInfoFill(context),
          reason: 'dark=$dark',
        );
        // Cancelled deliberately reuses `error` rather than adding a fifth
        // colour — a cancelled booking is the error state of a booking.
        expect(
          _pillFill(tester, 'CANCELLED'),
          Theme.of(context).colorScheme.errorContainer,
          reason: 'dark=$dark',
        );
      }
    });

    testWidgets('dark mode fills are fully opaque', (tester) async {
      // `DESIGN dark.md`: a translucent tint over a dark background muddies
      // into the backdrop and drops the dark contents below 4.5:1.
      await _pump(
        tester,
        const StatusPill(label: 'CONFIRMED', tone: StatusTone.positive),
        dark: true,
      );
      expect(_pillFill(tester, 'CONFIRMED')!.a, 1.0);

      await _pump(
        tester,
        const StatusPill(label: 'ECONOMY', tone: StatusTone.informational),
        dark: true,
      );
      expect(_pillFill(tester, 'ECONOMY')!.a, 1.0);
    });

    testWidgets('is a pill, and is not a 48dp touch target', (tester) async {
      // A status pill states a fact; it is never tappable, so the minimum
      // touch target deliberately does not apply. If this ever grows to 48 it
      // probably means someone wrapped it in a button by mistake.
      await _pump(
        tester,
        const StatusPill(label: 'CONFIRMED', tone: StatusTone.positive),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('CONFIRMED'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(999));
      expect(tester.getSize(find.byType(StatusPill)).height, lessThan(48));
      expect(
        tester.getSize(find.byType(StatusPill)).height,
        greaterThanOrEqualTo(26),
      );
    });

    testWidgets('survives a 2.0x system font size', (tester) async {
      await _pump(
        tester,
        const StatusPill(
          label: 'PREMIUM ECONOMY',
          tone: StatusTone.informational,
          icon: Icons.check_circle_outline_rounded,
        ),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

// --- Helpers -----------------------------------------------------------------

Color? _surfaceColor(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find.descendant(
        of: find.byType(TicketCard),
        matching: find.byType(ColoredBox),
      ),
    )
    .color;

Color? _pillFill(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  return (container.decoration! as BoxDecoration).color;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: Center(child: SizedBox(width: 340, child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
