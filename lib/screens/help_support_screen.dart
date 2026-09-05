import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/help_faq.dart';
import '../models/help_topic.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_list_row.dart';
import '../widgets/page_background.dart';
import 'policy_screen.dart';

/// Phase 8 — Help & Support, opened from the side drawer's **Help/Support**
/// row.
///
/// Layout comes from the `Help & Support` reference: the shared glass back
/// button and the page title on one line, then one liquid-glass row per topic
/// — a stroke-only circled icon, a title, a truncated question preview, and a
/// downward chevron.
///
/// The supplied English Q&A is bundled as an offline fallback. A future live
/// `help_topics/{docId}` source can replace it using the shape documented in
/// `DATA_MODEL.md` without changing this accordion interaction.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  HelpTopic? _expandedTopic;

  void _toggle(HelpTopic topic) {
    setState(() {
      _expandedTopic = _expandedTopic == topic ? null : topic;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        // Keep the shared drawer-destination photo and gradient wash.
        imageAsset: PolicyScreen.backgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 28),
            children: [
              Row(
                // The app's shared navigation convention keeps back controls
                // on the physical left in every language, so this row is
                // laid out left-to-right regardless of locale.
                textDirection: TextDirection.ltr,
                children: [
                  GlassBackButton(
                    onTap: () => Navigator.of(context).maybePop(),
                    useAppLiquidGlass: true,
                    useCanonicalGlass: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.helpAndSupport,
                        maxLines: 1,
                        textDirection: Directionality.of(context),
                        style: TextStyle(
                          // headline-lg, the size every hub title uses.
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02 * 28,
                          color: AppColors.heading(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final topic in HelpTopic.values) ...[
                GlassListRow(
                  icon: helpTopicIcon(topic),
                  title: l10n.helpTopicTitle(topic),
                  subtitle: l10n.helpTopicPreview(topic),
                  trailing: GlassListRowTrailing.expand,
                  expanded: _expandedTopic == topic,
                  expandedChild: _HelpTopicDetails(topic: topic),
                  onTap: () => _toggle(topic),
                  useCanonicalGlass: true,
                ),
                const SizedBox(height: GlassListRow.gap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The icon drawn in each row's circle, matching the reference screenshot.
IconData helpTopicIcon(HelpTopic topic) => switch (topic) {
  HelpTopic.account => Icons.lock_person_outlined,
  HelpTopic.bookings => Icons.confirmation_number_outlined,
  HelpTopic.payments => Icons.credit_card_outlined,
  HelpTopic.cancellation => Icons.event_repeat_outlined,
  HelpTopic.flights => Icons.flight_outlined,
  HelpTopic.stays => Icons.king_bed_outlined,
  HelpTopic.carRental => Icons.directions_car_outlined,
  HelpTopic.tours => Icons.landscape_outlined,
  HelpTopic.safety => Icons.error_outline,
  HelpTopic.contact => Icons.support_agent_outlined,
};

class _HelpTopicDetails extends StatelessWidget {
  const _HelpTopicDetails({required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final entries = bundledHelpFaqsFor(topic);
    final dividerColor = AppColors.accent(context).withValues(alpha: 0.22);

    return Container(
      key: ValueKey('help-details-${topic.docId}'),
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Text(
              AppLocalizations.of(context).comingSoon,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryTextV3(context),
              ),
            )
          else
            // Only English Q&A copy was supplied. Keep its punctuation and
            // reading order correct while Kurdish/Arabic row chrome remains
            // localized and RTL. Firestore's locale map will replace this
            // fallback once translated content is available.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < entries.length; index++) ...[
                    _QuestionAnswer(entry: entries[index]),
                    if (index != entries.length - 1) const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionAnswer extends StatelessWidget {
  const _QuestionAnswer({required this.entry});

  final HelpFaqEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Q: ${entry.question}',
          style: TextStyle(
            fontSize: 16,
            height: 23 / 16,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A: ${entry.answer}',
          style: TextStyle(
            fontSize: 15,
            height: 22 / 15,
            color: AppColors.secondaryTextV3(context),
          ),
        ),
      ],
    );
  }
}
