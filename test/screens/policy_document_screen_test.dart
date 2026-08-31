import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/legal_document.dart';
import 'package:kurdistan_paradise_travel_guide/models/policy_topic.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_document_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/legal_document_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';

void main() {
  group('LegalDocument parsing', () {
    test('the legacy {heading, body} shape still parses unchanged', () {
      // `terms_of_service` is already written this way; it must not break.
      final document = LegalDocument.fromMap({
        'version': 2,
        'legalReviewed': true,
        'content': {
          'en': {
            'sections': [
              {'heading': 'YOUR AGREEMENT', 'body': 'By using this App…'},
            ],
          },
        },
      }, 'en');

      expect(document, isNotNull);
      final section = document!.sections.single;
      expect(section.heading, 'YOUR AGREEMENT');
      expect(section.body, 'By using this App…');
      expect(section.blocks.single.type, LegalBlockType.paragraph);
    });

    test('the block shape carries bullets, bold lead-ins and no heading', () {
      final document = LegalDocument.fromMap({
        'content': {
          'en': {
            'sections': [
              {
                'blocks': [
                  {'type': 'paragraph', 'text': 'Intro with no heading.'},
                ],
              },
              {
                'heading': 'Information we collect',
                'blocks': [
                  {
                    'type': 'bullet',
                    'lead': 'Account & contact details:',
                    'text': 'name, email.',
                  },
                  {'type': 'bullet', 'text': 'No lead on this one.'},
                ],
              },
            ],
          },
        },
      }, 'en');

      expect(document, isNotNull);
      // An untitled lead-in section is legal, and keeps its empty heading.
      expect(document!.sections.first.heading, '');
      final collect = document.sections[1];
      expect(collect.blocks, hasLength(2));
      expect(collect.blocks.first.type, LegalBlockType.bullet);
      expect(collect.blocks.first.lead, 'Account & contact details:');
      expect(collect.blocks[1].lead, isNull);
    });

    test('a malformed block is dropped, not rendered as a blank line', () {
      final document = LegalDocument.fromMap({
        'content': {
          'en': {
            'sections': [
              {
                'heading': 'X',
                'blocks': [
                  {'type': 'bullet'}, // no text
                  {'type': 'bullet', 'text': ''}, // empty text
                  {'type': 'bullet', 'text': 'Kept.'},
                ],
              },
            ],
          },
        },
      }, 'en');

      expect(document!.sections.single.blocks, hasLength(1));
      expect(document.sections.single.blocks.single.text, 'Kept.');
    });

    test('falls back to English when a locale is missing', () {
      final document = LegalDocument.fromMap({
        'content': {
          'en': {
            'sections': [
              {
                'blocks': [
                  {'type': 'paragraph', 'text': 'English only.'},
                ],
              },
            ],
          },
        },
      }, 'ku');

      expect(document!.sections.single.blocks.single.text, 'English only.');
    });
  });

  group('PolicyDocumentScreen — layout', () {
    testWidgets('the header is the hub row title, at the hub title size', (
      tester,
    ) async {
      await _pump(tester);

      final title = tester.widget<Text>(find.text('Privacy Policy').first);
      expect(title.style!.fontSize, 28);
      expect(title.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('the "Last updated" line sits under the header', (
      tester,
    ) async {
      await _pump(tester);

      final updated = find.textContaining('Last updated:');
      expect(updated, findsOneWidget);
      // Date *and* time, as asked.
      expect(
        tester.widget<Text>(updated).data,
        matches(RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}')),
      );
      // Below the title, above the card.
      expect(
        tester.getTopLeft(updated).dy,
        greaterThan(tester.getTopLeft(find.text('Privacy Policy').first).dy),
      );
      expect(
        tester.getTopLeft(updated).dy,
        lessThan(tester.getTopLeft(find.byType(GlassPanel).last).dy),
      );
    });

    testWidgets('the document sits in one liquid-glass card with the '
        'low-opacity brand-gradient fill', (tester) async {
      await _pump(tester);

      final cards = tester
          .widgetList<GlassPanel>(find.byType(GlassPanel))
          .where((p) => p.borderRadius == 28)
          .toList();
      expect(cards, hasLength(1));
      expect(cards.single.depth, GlassDepth.base);
    });

    testWidgets('renders every heading, paragraph and bullet from the text', (
      tester,
    ) async {
      await _pump(tester);

      for (final heading in [
        'Information we collect',
        'How we use your information',
        'Sharing your information',
        'Data retention & your rights',
        'Children',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }

      // The untitled lead-in paragraph.
      expect(
        find.textContaining('This Privacy Policy explains how KurdistanGO'),
        findsOneWidget,
      );
      // 10 bullets across the two bulleted sections.
      expect(find.text('•'), findsNWidgets(10));
    });

    testWidgets('a bullet lead-in is bold and the rest of it is not', (
      tester,
    ) async {
      await _pump(tester);

      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere(
            (r) =>
                r.text.toPlainText().startsWith('Account & contact details:'),
          );
      // `Text.rich` nests the supplied span inside one carrying the default
      // style, so the runs that matter are the leaves.
      final runs = _leafSpans(rich.text as TextSpan);
      expect(runs, hasLength(2));
      expect(runs.first.text, 'Account & contact details:');
      expect(runs.first.style!.fontWeight, FontWeight.w700);
      expect(
        runs[1].text,
        ' name, email, phone number, and preferred language.',
      );
      expect(runs[1].style!.fontWeight, isNot(FontWeight.w700));
    });

    testWidgets('the back button pops back to the hub', (tester) async {
      // Opened the way the app opens it — from the hub — so the pop has
      // somewhere to land.
      await _pumpFromHub(tester);

      expect(find.byType(PolicyDocumentScreen), findsOneWidget);
      expect(find.byType(GlassBackButton), findsOneWidget);

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(PolicyDocumentScreen), findsNothing);
      expect(find.byType(PolicyScreen), findsOneWidget);
    });
  });

  group('PolicyDocumentScreen — states', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await _pump(tester, settle: false);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed load shows an error with a working retry', (
      tester,
    ) async {
      final service = _FakeLegalService(failFirst: true);
      await _pump(tester, service: service);

      expect(
        find.text("We couldn't load this policy. Please try again."),
        findsOneWidget,
      );
      // The title and the "Last updated" line are not invented on failure.
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('Last updated:'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Information we collect'), findsOneWidget);
      expect(service.reads, 2);
    });

    testWidgets('an unreviewed document carries the warning banner', (
      tester,
    ) async {
      await _pump(tester);
      // The bundled wording is not legally reviewed, and the Kurdish/Arabic
      // renderings were translated rather than drafted by a legal translator.
      expect(
        find.text('Draft wording — pending legal review. Not for release.'),
        findsOneWidget,
      );
    });

    testWidgets('a reviewed document carries no banner', (tester) async {
      await _pump(tester, service: _FakeLegalService(reviewed: true));
      expect(
        find.text('Draft wording — pending legal review. Not for release.'),
        findsNothing,
      );
    });

    testWidgets('it reads the topic it was given, not a hardcoded id', (
      tester,
    ) async {
      final service = _FakeLegalService();
      await _pump(tester, service: service);
      expect(service.requestedDocIds, ['privacy_policy']);
    });
  });

  group('PolicyDocumentScreen — languages', () {
    testWidgets('Kurdish renders its own copy, right-to-left', (tester) async {
      await _pump(tester, locale: const Locale('ku'));

      expect(find.text('سیاسەتی تایبەتمەندێتی'), findsOneWidget);
      expect(find.text('ئەو زانیارییانەی کۆیان دەکەینەوە'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(PolicyDocumentScreen))),
        TextDirection.rtl,
      );
    });

    testWidgets('Arabic renders its own copy', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('المعلومات التي نجمعها'), findsOneWidget);
      expect(find.text('الأطفال'), findsOneWidget);
    });

    testWidgets('every document has all three languages, with the same '
        'structure in each', (tester) async {
      // This is what replaces the old "keep the two copies in sync" warning:
      // one asset, checked by one test, across all seven documents.
      for (final topic in PolicyTopic.values) {
        final english = await LegalDocumentService.bundled(topic.docId, 'en');

        for (final locale in AppLocalizations.supportedLocales) {
          final code = locale.languageCode;
          final document = await LegalDocumentService.bundled(
            topic.docId,
            code,
          );

          expect(
            document.sections.length,
            english.sections.length,
            reason: '${topic.docId}/$code is missing a section',
          );

          for (var i = 0; i < document.sections.length; i++) {
            final section = document.sections[i];
            final reference = english.sections[i];

            // A heading present in one language and absent in another means
            // the reader of that language sees a differently-shaped document.
            expect(
              section.heading.isEmpty,
              reference.heading.isEmpty,
              reason:
                  '${topic.docId}/$code section $i disagrees with '
                  'English about having a heading',
            );
            expect(
              section.blocks.length,
              reference.blocks.length,
              reason:
                  '${topic.docId}/$code section $i has a different '
                  'number of blocks than English',
            );

            for (var b = 0; b < section.blocks.length; b++) {
              final block = section.blocks[b];
              expect(
                block.text.trim(),
                isNotEmpty,
                reason: '${topic.docId}/$code section $i block $b is empty',
              );
              expect(
                block.type,
                reference.blocks[b].type,
                reason:
                    '${topic.docId}/$code section $i block $b is a '
                    'different type than English',
              );
              // A bullet bolded in English must be bolded everywhere, or the
              // three languages read as different documents.
              expect(
                block.lead == null,
                reference.blocks[b].lead == null,
                reason:
                    '${topic.docId}/$code section $i block $b disagrees '
                    'with English about its bold lead-in',
              );
            }
          }
        }
      }
    });

    testWidgets('the bundled asset covers every policy topic, and the '
        'Terms document is the one consent is recorded against', (
      tester,
    ) async {
      final documents = await LegalDocumentService.bundledDocuments();

      for (final topic in PolicyTopic.values) {
        expect(
          documents.keys,
          contains(topic.docId),
          reason: '${topic.docId} has no entry in the bundled asset',
        );
      }
      // Nothing extra, either — an orphan id would be seeded and never read.
      expect(
        documents.keys.toSet(),
        PolicyTopic.values.map((t) => t.docId).toSet(),
      );
      expect(documents.keys, contains(LegalDocumentService.termsDocId));
    });
  });

  group('PolicyDocumentScreen — theming', () {
    testWidgets('body text and headings take the mode-correct tokens', (
      tester,
    ) async {
      await _pump(tester, dark: true);
      // `DESIGN dark.md`: every piece of text on dark glass is white, and a
      // heading is never dimmed.
      expect(
        tester.widget<Text>(find.text('Information we collect')).style!.color,
        Colors.white,
      );

      await _pump(tester);
      expect(
        tester.widget<Text>(find.text('Information we collect')).style!.color,
        const Color(0xFF1B1B1B), // DESIGN_LIGHT F.md -> text-heading
      );
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

/// Opens the document the way a user does — by tapping its row on the hub —
/// so back has somewhere to return to.
Future<void> _pumpFromHub(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(const Locale('en')),
      home: const PolicyScreen(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(policyTopicIcon(PolicyTopic.privacy)));
  await tester.pumpAndSettle();
}

/// The text-carrying runs of a span tree, in order.
List<TextSpan> _leafSpans(TextSpan root) {
  final leaves = <TextSpan>[];
  void walk(TextSpan span) {
    if (span.text != null) leaves.add(span);
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) walk(child);
    }
  }

  walk(root);
  return leaves;
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool dark = false,
  double textScale = 1.0,
  bool settle = true,
  LegalDocumentService? service,
}) async {
  tester.view.physicalSize = const Size(900, 4000);
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
      home: PolicyDocumentScreen(
        topic: PolicyTopic.privacy,
        service: service ?? _FakeLegalService(),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Serves the bundled wording without touching Firebase, and records what was
/// asked for so a test can prove the screen reads the topic it was handed.
class _FakeLegalService extends LegalDocumentService {
  _FakeLegalService({this.failFirst = false, this.reviewed = false});

  final bool failFirst;
  final bool reviewed;

  final List<String> requestedDocIds = [];
  int reads = 0;

  @override
  Future<LegalDocument> fetchDocument(String docId, String languageCode) async {
    requestedDocIds.add(docId);
    reads++;
    if (failFirst && reads == 1) {
      throw StateError('$docId has not been seeded');
    }
    final bundled = await LegalDocumentService.bundled(docId, languageCode);
    if (!reviewed) return bundled;
    return LegalDocument(
      version: bundled.version,
      updatedAt: bundled.updatedAt,
      sections: bundled.sections,
      legalReviewed: true,
    );
  }
}
