import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/policy_topic.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_list_row.dart';
import '../widgets/page_background.dart';
import 'policy_document_screen.dart';

/// Phase 8 — the Policy hub, opened from the side drawer's **Policy** row.
///
/// Layout comes from the `Policy of App` reference: the shared glass back
/// button, the page title with a hint line under it, then one liquid-glass
/// card per policy category. Each card carries a stroke-only circled icon, a
/// title, a hint line and a chevron.
///
/// **Reads nothing itself.** Each card opens a [PolicyDocumentScreen], which
/// fetches `legal_documents/{topic.docId}` — one document per [PolicyTopic],
/// in the collection the Terms of Service already lives in rather than a new
/// one. See `DATA_MODEL.md`.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  /// Policy is reachable from the drawer, so it stays on the Home screen's
  /// photograph — `DESIGN light.md` / `DESIGN dark.md` call for one photo per
  /// screen *category*, and this is not a Nature/Hotel/Car/Tour/Flight screen.
  static const String backgroundAsset =
      'assets/images/main screen back image.webp';

  void _open(BuildContext context, PolicyTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyDocumentScreen(topic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: backgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 28),
            children: [
              Align(
                // The app's shared navigation convention keeps back controls
                // on the physical left in every language.
                alignment: Alignment.centerLeft,
                child: GlassBackButton(
                  useAppLiquidGlass: true,
                  useCanonicalGlass: true,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 20),
              const _Header(),
              const SizedBox(height: 24),
              for (final topic in PolicyTopic.values) ...[
                GlassListRow(
                  icon: policyTopicIcon(topic),
                  title: l10n.policyTopicTitle(topic),
                  subtitle: l10n.policyTopicSubtitle(topic),
                  // Every topic now has wording in `legal_documents`, so
                  // every row opens its document. A missing entry throws in
                  // preview mode rather than showing a blank legal page, and
                  // a test asserts the asset covers all seven ids.
                  onTap: () => _open(context, topic),
                  useCanonicalGlass: true,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The icon drawn in each card's circle, matching the reference screenshot.
IconData policyTopicIcon(PolicyTopic topic) => switch (topic) {
  // Material's `security` glyph is the shield-with-lock drawn in the
  // reference; `shield_outlined` is empty and `privacy_tip` carries a "!".
  PolicyTopic.privacy => Icons.security_outlined,
  PolicyTopic.terms => Icons.article_outlined,
  PolicyTopic.cancellation => Icons.event_busy_outlined,
  PolicyTopic.payment => Icons.credit_card_outlined,
  PolicyTopic.liability => Icons.warning_amber_rounded,
  PolicyTopic.contact => Icons.headset_mic_outlined,
  PolicyTopic.accountDeletion => Icons.person_remove_outlined,
};

// --- Header ------------------------------------------------------------------

/// Page title and the hint line beneath it, drawn straight on the background
/// rather than inside a card — as in the reference.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.policyOfApp,
          style: TextStyle(
            // headline-lg, at the size the sibling Customize Filters screen
            // already uses for a page title.
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02 * 28,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.policyOfAppSubtitle,
          style: TextStyle(
            // body-sm
            fontSize: 14,
            height: 20 / 14,
            // The header sits on the pale top of the brand gradient, so the
            // dark on-surface-variant reads cleanly here; dark mode gets its
            // 75%-white helper tone from the same accessor.
            color: AppColors.secondaryText(context),
          ),
        ),
      ],
    );
  }
}
