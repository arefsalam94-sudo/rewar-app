import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/legal_document.dart';
import '../theme/app_colors.dart';

/// Renders a [LegalDocument] — the "long-form document page" pattern in
/// `DESIGN_SYSTEM.md`: an optional unreviewed-wording banner, then each
/// section's heading, paragraphs and bullets.
///
/// Shared by the Policy hub's document pages and the Terms of Service consent
/// screen. They read documents out of the **same** `legal_documents`
/// collection — `PolicyTopic.terms.docId` *is* `LegalDocumentService
/// .termsDocId` — so a bullet has to look the same on both. Rendering it twice
/// is how they would quietly stop matching.
class LegalDocumentBody extends StatelessWidget {
  const LegalDocumentBody({
    super.key,
    required this.document,
    this.showReviewWarning = true,
  });

  final LegalDocument document;

  /// Whether to draw the "pending legal review" banner when the document's
  /// `legalReviewed` is false. On by default — an unreviewed document must
  /// not reach a real user unannounced.
  final bool showReviewWarning;

  /// Between the end of one section and the next section's heading.
  static const double sectionGap = 24;

  /// Between a heading and the content under it.
  static const double headingGap = 12;

  /// Between two bullets, and between two paragraphs.
  static const double blockGap = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = <Widget>[];

    if (showReviewWarning && !document.legalReviewed) {
      children
        ..add(_ReviewWarning(message: l10n.termsNotReviewed))
        ..add(const SizedBox(height: 20));
    }

    for (var s = 0; s < document.sections.length; s++) {
      final section = document.sections[s];
      if (s > 0) children.add(const SizedBox(height: sectionGap));

      // A document may open with an untitled lead-in paragraph, so an absent
      // heading is skipped rather than drawn as an empty line that adds
      // stray space above the first paragraph.
      if (section.heading.isNotEmpty) {
        children
          ..add(_SectionHeading(text: section.heading))
          ..add(const SizedBox(height: headingGap));
      }

      for (var b = 0; b < section.blocks.length; b++) {
        if (b > 0) children.add(const SizedBox(height: blockGap));
        children.add(LegalBlockText(block: section.blocks[b]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      // headline-md
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 28 / 20,
      color: AppColors.heading(context),
    ),
  );
}

/// One paragraph or bullet.
///
/// Bullets use a fixed-width leading column holding the "•", so a wrapped line
/// lines up with the text rather than sitting under the bullet — the hanging
/// indent drawn in the reference. The marker is a text glyph rather than a
/// drawn dot so it stays on the first line's baseline at any system font size.
class LegalBlockText extends StatelessWidget {
  const LegalBlockText({super.key, required this.block});

  final LegalBlock block;

  /// body-lg, at the line height both legal screens use — they have to read
  /// as the same document family.
  static const double fontSize = 16;
  static const double lineHeight = 1.45;

  /// Bullet glyph column: wide enough for "• " plus the gap in the reference.
  static const double markerWidth = 18;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: colorScheme.onSurface,
    );

    final text = block.lead == null
        ? Text(block.text, style: base)
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: block.lead,
                  style: base.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' ${block.text}', style: base),
              ],
            ),
            style: base,
          );

    if (block.type == LegalBlockType.paragraph) return text;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: markerWidth,
          // Directionality places this on the right in Kurdish and Arabic,
          // which is where a bullet belongs in an RTL list.
          child: Text('•', style: base),
        ),
        Expanded(child: text),
      ],
    );
  }
}

/// Shown while `legalReviewed` is false, so unreviewed wording — in
/// particular the Kurdish and Arabic renderings, which were translated rather
/// than drafted by a legal translator — can't quietly reach a real user.
class _ReviewWarning extends StatelessWidget {
  const _ReviewWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningBannerFill.withValues(
          alpha: AppColors.warningBannerFillOpacity,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warningBannerBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.gavel_outlined,
            size: 18,
            color: AppColors.warningBannerIcon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: AppColors.warningBannerText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
