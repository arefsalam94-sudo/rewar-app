import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/help_topic.dart';
import 'package:kurdistan_paradise_travel_guide/screens/help_support_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_list_row.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';

void main() {
  group('HelpSupportScreen — layout', () {
    testWidgets('draws the title and all ten rows', (tester) async {
      await _pump(tester);

      expect(find.text('Help & Support'), findsOneWidget);

      for (final title in const [
        'Account & Sign-in',
        'Bookings & Confirmation',
        'Payments & Refunds',
        'Cancellation & Changes',
        'Flights',
        'Where to Stay (Hotels)',
        'Car Rental',
        'Tours & Nature (Explore)',
        'Safety & Travel Info',
        'Still need help? Contact us',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }

      for (final preview in const [
        'How do I change my email or ...',
        'What is my booking reference ...',
        'My payment failed but I ...',
        'Can I change my booking instead ...',
        'What is the baggage allowance ...',
        'What are the check-in and ...',
        'What documents do I need to ...',
        'What happens if the weather ...',
        'What are the emergency numbers in ...',
        'Get in touch with our support team ...',
      ]) {
        expect(find.text(preview), findsOneWidget, reason: preview);
      }
    });

    testWidgets('the title sits beside the back button, at the hub size', (
      tester,
    ) async {
      await _pump(tester);

      final title = tester.widget<Text>(find.text('Help & Support'));
      expect(title.style!.fontSize, 28);
      expect(title.style!.fontWeight, FontWeight.w700);

      // Same line, not stacked: their vertical centres line up.
      expect(
        tester.getCenter(find.text('Help & Support')).dy,
        closeTo(tester.getCenter(find.byType(GlassBackButton)).dy, 2),
      );
    });

    testWidgets('every row uses the documented white-sheen glass fill and '
        'there is no outer background card', (tester) async {
      await _pump(tester);

      final rows = tester.widgetList<GlassListRow>(find.byType(GlassListRow));
      expect(rows.length, HelpTopic.values.length);

      final cards = tester
          .widgetList<GlassPanel>(find.byType(GlassPanel))
          .where((p) => p.borderRadius == GlassListRow.radius)
          .toList();
      expect(cards.length, HelpTopic.values.length);
      for (final card in cards) {
        expect(card.depth, GlassDepth.base);
      }

      // Aside from the back button's circular glass surface, every panel on
      // this page is one of the topic rows. There is no large backing card
      // around the list.
      expect(
        find.byType(GlassPanel),
        findsNWidgets(HelpTopic.values.length + 1),
      );
    });

    testWidgets('rows carry a downward chevron, not a forward one', (
      tester,
    ) async {
      await _pump(tester);

      // These expand in place once they have content, so the affordance
      // points down — and stays down in RTL, unlike a forward chevron.
      expect(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
        findsNWidgets(HelpTopic.values.length),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      for (final row in tester.widgetList<GlassListRow>(
        find.byType(GlassListRow),
      )) {
        expect(row.trailing, GlassListRowTrailing.expand);
      }
    });

    testWidgets('the background photo uses the shared blur in both modes', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, dark: dark);

        final image = tester.widget<Image>(find.byType(Image).first);
        expect(
          (image.image as AssetImage).assetName,
          PolicyScreen.backgroundAsset,
        );
        expect(find.byType(ImageFiltered), findsOneWidget);
      }
    });

    testWidgets('every row clears the 48dp minimum touch target', (
      tester,
    ) async {
      await _pump(tester);

      for (final topic in HelpTopic.values) {
        final card = find.ancestor(
          of: find.byIcon(helpTopicIcon(topic)),
          matching: find.byType(GlassPanel),
        );
        expect(
          tester.getSize(card).height,
          greaterThanOrEqualTo(48),
          reason: '$topic',
        );
      }
    });

    testWidgets('the back button pops the route', (tester) async {
      await _pump(tester, withHost: true);

      expect(find.byType(HelpSupportScreen), findsOneWidget);
      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HelpSupportScreen), findsNothing);
    });
  });

  group('HelpSupportScreen — behaviour', () {
    testWidgets('the first row expands downward and pushes later rows down', (
      tester,
    ) async {
      await _pump(tester);

      final firstCard = find.ancestor(
        of: find.byIcon(helpTopicIcon(HelpTopic.account)),
        matching: find.byType(GlassPanel),
      );
      final secondCard = find.ancestor(
        of: find.byIcon(helpTopicIcon(HelpTopic.bookings)),
        matching: find.byType(GlassPanel),
      );
      final firstTopBefore = tester.getTopLeft(firstCard).dy;
      final secondTopBefore = tester.getTopLeft(secondCard).dy;

      await tester.tap(find.byIcon(helpTopicIcon(HelpTopic.account)));
      await tester.pumpAndSettle();

      expect(find.text('Q: How do I create an account?'), findsOneWidget);
      expect(tester.getTopLeft(firstCard).dy, closeTo(firstTopBefore, 0.1));
      expect(tester.getTopLeft(secondCard).dy, greaterThan(secondTopBefore));
      expect(find.byType(HelpSupportScreen), findsOneWidget);
    });

    testWidgets('a middle row keeps all rows above fixed', (tester) async {
      await _pump(tester);

      final firstCard = find.ancestor(
        of: find.byIcon(helpTopicIcon(HelpTopic.account)),
        matching: find.byType(GlassPanel),
      );
      final secondCard = find.ancestor(
        of: find.byIcon(helpTopicIcon(HelpTopic.bookings)),
        matching: find.byType(GlassPanel),
      );
      final thirdCard = find.ancestor(
        of: find.byIcon(helpTopicIcon(HelpTopic.payments)),
        matching: find.byType(GlassPanel),
      );
      final fourthCard = find.ancestor(
        of: find.byIcon(helpTopicIcon(HelpTopic.cancellation)),
        matching: find.byType(GlassPanel),
      );
      final firstTop = tester.getTopLeft(firstCard).dy;
      final secondTop = tester.getTopLeft(secondCard).dy;
      final thirdTop = tester.getTopLeft(thirdCard).dy;
      final fourthTop = tester.getTopLeft(fourthCard).dy;

      await tester.tap(find.byIcon(helpTopicIcon(HelpTopic.payments)));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(firstCard).dy, closeTo(firstTop, 0.1));
      expect(tester.getTopLeft(secondCard).dy, closeTo(secondTop, 0.1));
      expect(tester.getTopLeft(thirdCard).dy, closeTo(thirdTop, 0.1));
      expect(tester.getTopLeft(fourthCard).dy, greaterThan(fourthTop));
      expect(find.text('Q: What payment methods can I use?'), findsOneWidget);
    });

    testWidgets('tapping an open row collapses it again', (tester) async {
      await _pump(tester);

      final target = find.byIcon(helpTopicIcon(HelpTopic.flights));
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(
        find.text('Q: How do I change or cancel a flight ticket?'),
        findsOneWidget,
      );

      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(
        find.text('Q: How do I change or cancel a flight ticket?'),
        findsNothing,
      );
    });

    testWidgets('the tenth row expands to its inline Coming soon state', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byIcon(helpTopicIcon(HelpTopic.contact)));
      await tester.pumpAndSettle();

      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('every topic maps to a distinct icon and help_topics id', (
      tester,
    ) async {
      final icons = HelpTopic.values.map(helpTopicIcon).toSet();
      expect(icons.length, HelpTopic.values.length);

      final ids = HelpTopic.values.map((t) => t.docId).toSet();
      expect(ids.length, HelpTopic.values.length);
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: id);
      }
    });
  });

  group('HelpSupportScreen — languages', () {
    testWidgets('Kurdish renders its own copy, right-to-left', (tester) async {
      await _pump(tester, locale: const Locale('ku'));

      expect(find.text('یارمەتی و پشتگیری'), findsOneWidget);
      expect(find.text('هەژمار و چوونەژوورەوە'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(HelpSupportScreen))),
        TextDirection.rtl,
      );
      // The expand chevron is not mirrored — down is down in every language.
      expect(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
        findsNWidgets(HelpTopic.values.length),
      );
      expect(find.byIcon(Icons.chevron_left), findsOneWidget); // back button
    });

    testWidgets('Arabic renders its own copy', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      expect(find.text('المساعدة والدعم'), findsOneWidget);
      expect(find.text('الحساب وتسجيل الدخول'), findsOneWidget);
      expect(find.text('تأجير السيارات'), findsOneWidget);
    });

    testWidgets('no locale is missing a title or a preview line', (
      tester,
    ) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        expect(l10n.helpAndSupport, isNotEmpty);
        for (final topic in HelpTopic.values) {
          expect(
            l10n.helpTopicTitle(topic),
            isNotEmpty,
            reason: '${locale.languageCode} $topic title',
          );
          expect(
            l10n.helpTopicPreview(topic),
            isNotEmpty,
            reason: '${locale.languageCode} $topic preview',
          );
        }
      }
    });
  });

  group('HelpSupportScreen — theming', () {
    testWidgets('headings and icons take the mode-correct accent token', (
      tester,
    ) async {
      await _pump(tester, dark: true);
      // `DESIGN dark.md`: a heading is pure white at 100%, never dimmed.
      expect(
        tester.widget<Text>(find.text('Car Rental')).style!.color,
        Colors.white,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.directions_car_outlined)).color,
        AppColors.luminousMint,
      );

      await _pump(tester);
      expect(
        tester.widget<Text>(find.text('Car Rental')).style!.color,
        AppTheme.lightColorScheme.onSurface,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.directions_car_outlined)).color,
        AppColors.actionNavy,
      );
    });

    testWidgets('survives a 2.0x system font size without overflowing', (
      tester,
    ) async {
      await _pump(tester, textScale: 2.0);
      await tester.tap(find.byIcon(helpTopicIcon(HelpTopic.account)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

// --- Helpers -----------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool dark = false,
  double textScale = 1.0,
  bool withHost = false,
}) async {
  // Tall enough that all ten rows lay out; several assertions read sizes,
  // which requires the widget to be on screen.
  tester.view.physicalSize = const Size(900, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: withHost ? const _PushHost() : const HelpSupportScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A throwaway route that immediately pushes Help & Support, so a test can
/// prove the back button pops rather than sitting on the root.
class _PushHost extends StatefulWidget {
  const _PushHost();

  @override
  State<_PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<_PushHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HelpSupportScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
