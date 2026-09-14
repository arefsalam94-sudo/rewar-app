import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/help_faq.dart';
import '../models/help_topic.dart';
import '../services/help_topics_service.dart';
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
/// Q&A comes from the `help_topics` collection (`DATA_MODEL.md`), read by
/// [HelpTopicsService]. The bundled English copy in [bundledHelpFaqs] remains
/// the fallback for every failure path — Firebase absent, document unseeded,
/// offline, malformed — because a slightly stale answer beats an error page in
/// front of someone who is already stuck.
///
/// The row list itself still comes from the [HelpTopic] enum, not Firestore:
/// titles and preview lines are app strings, and the approved schema has no
/// field for them.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, this.service});

  /// Injectable for tests. Defaults to the real Firestore-backed service.
  final HelpTopicsService? service;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  HelpTopic? _expandedTopic;
  late final HelpTopicsService _service = widget.service ?? HelpTopicsService();

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
                  expandedChild: _HelpTopicDetails(
                    topic: topic,
                    service: _service,
                  ),
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

class _HelpTopicDetails extends StatefulWidget {
  const _HelpTopicDetails({required this.topic, required this.service});

  final HelpTopic topic;
  final HelpTopicsService service;

  @override
  State<_HelpTopicDetails> createState() => _HelpTopicDetailsState();
}

class _HelpTopicDetailsState extends State<_HelpTopicDetails> {
  Future<HelpTopicContent>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Started here rather than in initState because it needs the locale.
    _future ??= widget.service.fetchTopic(
      widget.topic,
      Localizations.localeOf(context).languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HelpTopicContent>(
      future: _future,
      builder: (context, snapshot) {
        // No spinner: the bundled copy is always available as a floor, so the
        // row would flash a loader for one frame and then fill in. Drawing the
        // fallback immediately and swapping in the live answers when they
        // arrive keeps the accordion's height stable, which is what the
        // layout tests pin.
        final entries = snapshot.data?.questions ??
            bundledHelpFaqsFor(widget.topic);
        return _HelpTopicBody(topic: widget.topic, entries: entries);
      },
    );
  }
}

class _HelpTopicBody extends StatelessWidget {
  const _HelpTopicBody({required this.topic, required this.entries});

  final HelpTopic topic;
  final List<HelpFaqEntry> entries;

  @override
  Widget build(BuildContext context) {
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
