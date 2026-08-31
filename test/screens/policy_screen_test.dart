import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/policy_topic.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_document_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';

void main() {
  group('PolicyScreen — layout', () {
    testWidgets('draws the title, the hint line and one card per topic', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Policy of App'), findsOneWidget);
      expect(
        find.text(
          'Read our guidelines and policies to learn how we protect you.',
        ),
        findsOneWidget,
      );

      // The six from the reference screenshot, in the order drawn…
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Cancellation & Refunds'), findsOneWidget);
      expect(find.text('Payment Policy'), findsOneWidget);
      expect(find.text('Liability & Disclaimer'), findsOneWidget);
      expect(find.text('Contact & Complaints'), findsOneWidget);
      // …plus the store-required seventh.
      expect(find.text('Account & Data Deletion'), findsOneWidget);

      expect(find.text('How we handle your data'), findsOneWidget);
      expect(find.text('Rules for using the app'), findsOneWidget);
      expect(find.text('Changing or cancelling bookings'), findsOneWidget);
      expect(find.text('Methods, currency & charges'), findsOneWidget);
      expect(find.text('Limits of our responsibility'), findsOneWidget);
      expect(find.text('Reach support'), findsOneWidget);
      expect(find.text('Delete your account and your data'), findsOneWidget);
    });

    testWidgets('every card uses the documented white-sheen glass fill', (
      tester,
    ) async {
      await _pump(tester);

      final panels = tester
          .widgetList<GlassPanel>(find.byType(GlassPanel))
          .toList();
      // One per topic, plus the shared back button's own circle.
      final cards = panels.where((p) => p.borderRadius == 28).toList();
      expect(cards.length, PolicyTopic.values.length);
      for (final card in cards) {
        expect(card.depth, GlassDepth.base);
      }
    });

    testWidgets('the background photo is the shared drawer photograph', (
      tester,
    ) async {
      // The σ=24 light-mode blur was removed by approved decision — the photo
      // is now sharp in light mode and keeps `DESIGN dark.md`'s mandatory σ=8
      // in dark, which is `PageBackground`'s default. There is therefore no
      // sigma constant on this screen to assert; what must stay true is that
      // the hub and its document pages share one photograph.
      for (final dark in [false, true]) {
        await _pump(tester, dark: dark);
        final image = tester.widget<Image>(find.byType(Image).first);
        expect(
          (image.image as AssetImage).assetName,
          PolicyScreen.backgroundAsset,
        );
      }
    });

    testWidgets('the back button is present and pops the route', (
      tester,
    ) async {
      await _pump(tester, withScaffoldBelow: true);

      expect(find.byType(GlassBackButton), findsOneWidget);
      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(PolicyScreen), findsNothing);
    });

    testWidgets('each card clears the 48dp minimum touch target', (
      tester,
    ) async {
      await _pump(tester);

      for (final topic in PolicyTopic.values) {
        final card = find.ancestor(
          of: find.byIcon(policyTopicIcon(topic)),
          matching: find.byType(GlassPanel),
        );
        expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('PolicyScreen — behaviour', () {
    testWidgets('every card opens its own document, titled with the row it '
        'was tapped from', (tester) async {
      // The expected header of each page — the row's own label, which is the
      // whole point of `PolicyDocumentScreen` taking a topic.
      const titles = {
        PolicyTopic.privacy: 'Privacy Policy',
        PolicyTopic.terms: 'Terms & Conditions',
        PolicyTopic.cancellation: 'Cancellation & Refunds',
        PolicyTopic.payment: 'Payment Policy',
        PolicyTopic.liability: 'Liability & Disclaimer',
        PolicyTopic.contact: 'Contact & Complaints',
        PolicyTopic.accountDeletion: 'Account & Data Deletion',
      };
      expect(titles.keys, containsAll(PolicyTopic.values));

      // Pumped once, then navigated back between topics: re-pumping the same
      // MaterialApp reuses the Navigator's state, so the pushed route would
      // survive and the next tap would miss the hub entirely.
      await _pump(tester);

      for (final topic in PolicyTopic.values) {
        await tester.tap(find.byIcon(policyTopicIcon(topic)));
        await tester.pumpAndSettle();

        expect(
          find.byType(PolicyDocumentScreen),
          findsOneWidget,
          reason: '$topic did not open',
        );
        // The hub row and the page header carry the same label.
        expect(find.text(titles[topic]!), findsOneWidget, reason: '$topic');
        // Nothing is inert any more.
        expect(find.text('Coming soon'), findsNothing, reason: '$topic');

        await tester.tap(find.byType(GlassBackButton));
        await tester.pumpAndSettle();
        expect(find.byType(PolicyScreen), findsOneWidget, reason: '$topic');
      }
    });

    testWidgets('every topic maps to a distinct icon and legal_documents id', (
      tester,
    ) async {
      final icons = PolicyTopic.values.map(policyTopicIcon).toSet();
      expect(icons.length, PolicyTopic.values.length);

      final ids = PolicyTopic.values.map((t) => t.docId).toSet();
      expect(ids.length, PolicyTopic.values.length);
      // The Terms row must point at the document the Register flow already
      // reads, not a second copy of the same agreement.
      expect(PolicyTopic.terms.docId, 'terms_of_service');
    });
  });

  group('PolicyScreen — languages', () {
    testWidgets('Kurdish renders its own copy, right-to-left', (tester) async {
      await _pump(tester, locale: const Locale('ku'));

      expect(find.text('سیاسەتی ئەپ'), findsOneWidget);
      expect(find.text('سیاسەتی تایبەتمەندێتی'), findsOneWidget);
      expect(find.text('سڕینەوەی هەژمار و زانیاری'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(PolicyScreen))),
        TextDirection.rtl,
      );
      // The card chevrons point the other way in RTL. Counted by their own
      // size, because the shared back button draws a chevron_left too — in
      // every language, by the app's navigation convention.
      expect(
        _cardChevrons(tester, Icons.chevron_left),
        PolicyTopic.values.length,
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('Arabic renders its own copy', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      expect(find.text('سياسة التطبيق'), findsOneWidget);
      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('حذف الحساب والبيانات'), findsOneWidget);
      expect(find.text('تواصل مع الدعم'), findsOneWidget);
    });

    testWidgets('no locale is missing a title or a hint line', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        expect(l10n.policyOfApp, isNotEmpty);
        expect(l10n.policyOfAppSubtitle, isNotEmpty);
        for (final topic in PolicyTopic.values) {
          expect(l10n.policyTopicTitle(topic), isNotEmpty, reason: '$locale');
          expect(
            l10n.policyTopicSubtitle(topic),
            isNotEmpty,
            reason: '$locale',
          );
        }
      }
    });
  });

  group('PolicyScreen — theming', () {
    testWidgets('headings and icons take the mode-correct accent token', (
      tester,
    ) async {
      await _pump(tester, dark: true);

      final title = tester.widget<Text>(find.text('Privacy Policy'));
      // `DESIGN dark.md`: a heading is pure white at 100%, never dimmed.
      expect(title.style!.color, Colors.white);

      final icon = tester.widget<Icon>(find.byIcon(Icons.security_outlined));
      expect(icon.color, AppColors.luminousMint);

      await _pump(tester);
      expect(
        tester.widget<Text>(find.text('Privacy Policy')).style!.color,
        AppTheme.lightColorScheme.onSurface,
      );
      final lightIcon = tester.widget<Icon>(
        find.byIcon(Icons.security_outlined),
      );
      expect(lightIcon.color, AppColors.actionNavy);
    });

    testWidgets('survives a 2.0x system font size without overflowing', (
      tester,
    ) async {
      await _pump(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });
}

// --- Helpers -----------------------------------------------------------------

/// Counts only the chevrons drawn *on cards*, ignoring the shared back
/// button's — which is a `chevron_left` in every language.
int _cardChevrons(WidgetTester tester, IconData icon) => tester
    .widgetList<Icon>(find.byIcon(icon))
    .where((i) => i.size == 28)
    .length;

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool dark = false,
  double textScale = 1.0,
  bool withScaffoldBelow = false,
}) async {
  // Tall enough that all seven cards lay out; several assertions read sizes,
  // which requires the widget to be on screen.
  tester.view.physicalSize = const Size(900, 3000);
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
      home: withScaffoldBelow ? const _PushHost() : const PolicyScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A throwaway route that immediately pushes the Policy screen, so a test can
/// prove the back button actually pops rather than sitting on the root.
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const PolicyScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
