import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/legal_document.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/legal_document_body.dart';

/// The renderer shared by the Terms of Service consent screen and the Policy
/// hub's document pages. Those two read the **same** Firestore document, so
/// anything that renders differently between them is a bug.
void main() {
  group('LegalDocumentBody', () {
    testWidgets('draws headings, paragraphs and bullets', (tester) async {
      await _pump(
        tester,
        _document(
          sections: [
            const LegalSection(
              heading: '',
              blocks: [LegalBlock.paragraph('Lead-in with no heading.')],
            ),
            const LegalSection(
              heading: 'A heading',
              blocks: [
                LegalBlock.paragraph('A paragraph.'),
                LegalBlock.bullet('A bullet.'),
                LegalBlock.bullet('Bold one.', lead: 'Lead:'),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Lead-in with no heading.'), findsOneWidget);
      expect(find.text('A heading'), findsOneWidget);
      expect(find.text('A paragraph.'), findsOneWidget);
      // One marker per bullet, and none for the paragraphs.
      expect(find.text('•'), findsNWidgets(2));
    });

    testWidgets('an empty heading draws nothing rather than a blank line', (
      tester,
    ) async {
      await _pump(
        tester,
        _document(
          sections: [
            const LegalSection(
              heading: '',
              blocks: [LegalBlock.paragraph('Only text.')],
            ),
          ],
        ),
      );

      // An empty Text('') would still occupy a line and push the paragraph
      // down; nothing but the paragraph should be present.
      expect(find.text(''), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('a bullet hangs its wrapped lines past the marker', (
      tester,
    ) async {
      await _pump(
        tester,
        _document(
          sections: [
            const LegalSection(
              heading: '',
              blocks: [
                LegalBlock.bullet(
                  'A deliberately long bullet that has to wrap onto a second '
                  'line so the hanging indent is actually exercised.',
                ),
              ],
            ),
          ],
        ),
        width: 300,
      );

      final marker = tester.getTopLeft(find.text('•'));
      final body = tester.getTopLeft(find.byType(RichText).last);
      // The text column starts to the right of the marker, and the marker
      // column is the documented width.
      expect(body.dx - marker.dx, LegalBlockText.markerWidth);
    });

    testWidgets('the review banner shows only while unreviewed', (
      tester,
    ) async {
      const warning = 'Draft wording — pending legal review. Not for release.';

      await _pump(tester, _document(reviewed: false));
      expect(find.text(warning), findsOneWidget);

      await _pump(tester, _document(reviewed: true));
      expect(find.text(warning), findsNothing);
    });

    testWidgets('the banner can be suppressed by the caller', (tester) async {
      await _pump(tester, _document(reviewed: false), showReviewWarning: false);
      expect(
        find.text('Draft wording — pending legal review. Not for release.'),
        findsNothing,
      );
    });

    testWidgets('body text follows the theme in both modes', (tester) async {
      await _pump(tester, _document());
      expect(
        tester.widget<Text>(find.text('Body.')).style!.color,
        AppTheme.light.colorScheme.onSurface,
      );

      await _pump(tester, _document(), dark: true);
      // `DESIGN dark.md`: every piece of text on dark glass is white.
      expect(
        tester.widget<Text>(find.text('Body.')).style!.color,
        Colors.white,
      );
      expect(
        tester.widget<Text>(find.text('Heading')).style!.color,
        Colors.white,
      );
    });

    testWidgets('headings use the heading token in light mode', (tester) async {
      await _pump(tester, _document());
      expect(
        tester.widget<Text>(find.text('Heading')).style!.color,
        const Color(0xFF1B1B1B), // DESIGN_LIGHT F.md -> text-heading
      );
    });

    testWidgets('the bullet marker sits on the trailing side in RTL', (
      tester,
    ) async {
      await _pump(
        tester,
        _document(
          sections: [
            const LegalSection(
              heading: '',
              blocks: [LegalBlock.bullet('نموونە')],
            ),
          ],
        ),
        locale: const Locale('ar'),
      );

      // In Arabic the list marker belongs on the right of the text.
      expect(
        tester.getCenter(find.text('•')).dx,
        greaterThan(tester.getCenter(find.text('نموونە')).dx),
      );
    });
  });
}

// --- Helpers -----------------------------------------------------------------

LegalDocument _document({List<LegalSection>? sections, bool reviewed = true}) =>
    LegalDocument(
      version: 1,
      updatedAt: DateTime(2026, 8, 10),
      legalReviewed: reviewed,
      sections:
          sections ??
          [
            const LegalSection(
              heading: 'Heading',
              blocks: [LegalBlock.paragraph('Body.')],
            ),
          ],
    );

Future<void> _pump(
  WidgetTester tester,
  LegalDocument document, {
  bool dark = false,
  Locale locale = const Locale('en'),
  double width = 600,
  bool showReviewWarning = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: LegalDocumentBody(
                document: document,
                showReviewWarning: showReviewWarning,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
