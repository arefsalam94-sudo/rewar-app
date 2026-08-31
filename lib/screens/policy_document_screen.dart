import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/legal_document.dart';
import '../models/policy_topic.dart';
import '../services/legal_document_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/legal_document_body.dart';
import '../widgets/page_background.dart';
import 'policy_screen.dart';

/// Phase 8 — one policy document, opened from a row on the Policy hub.
///
/// Layout comes from the `policy of app+` reference: the shared glass back
/// button, the row's own title as the page header at the hub's title size, the
/// "Last updated" line beneath it, then a single liquid-glass card holding the
/// document.
///
/// Parameterised by [topic] because every row on the hub uses this same
/// layout — only the title and the document behind it differ. **Only
/// `PolicyTopic.privacy` is wired up**; the other six still say "Coming soon"
/// on the hub, because their wording has not been supplied yet.
///
/// The wording is read from Firestore (`legal_documents/{topic.docId}`) so it
/// can be corrected without an app-store release — a privacy policy that can
/// only be fixed by shipping a new build is a liability.
class PolicyDocumentScreen extends StatefulWidget {
  const PolicyDocumentScreen({super.key, required this.topic, this.service});

  final PolicyTopic topic;

  /// Injectable for tests; defaults to the real Firestore-backed service.
  final LegalDocumentService? service;

  @override
  State<PolicyDocumentScreen> createState() => _PolicyDocumentScreenState();
}

class _PolicyDocumentScreenState extends State<PolicyDocumentScreen> {
  late final LegalDocumentService _service =
      widget.service ?? LegalDocumentService();

  Future<LegalDocument>? _future;
  String? _loadedForLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch if the app language changed while this screen was alive, so
    // the user always reads the policy in the language they've chosen.
    final language = Localizations.localeOf(context).languageCode;
    if (_loadedForLanguage != language) {
      _loadedForLanguage = language;
      _future = _service.fetchDocument(widget.topic.docId, language);
    }
  }

  void _reload() {
    setState(() {
      _future = _service.fetchDocument(
        widget.topic.docId,
        Localizations.localeOf(context).languageCode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        // Deliberately the same photo and wash as the Policy hub — the
        // design files require the treatment to be identical across a flow.
        imageAsset: PolicyScreen.backgroundAsset,
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<LegalDocument>(
            future: _future,
            builder: (context, snapshot) {
              final document = snapshot.data;
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 28),
                children: [
                  Align(
                    // The app's shared navigation convention keeps back
                    // controls on the physical left in every language.
                    alignment: Alignment.centerLeft,
                    child: GlassBackButton(
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    // The header is the hub row's own label, at the hub's
                    // title size — one string, so the two can never disagree.
                    l10n.policyTopicTitle(widget.topic),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02 * 28,
                      color: AppColors.heading(context),
                    ),
                  ),
                  if (document?.updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.lastUpdated(_formatDateTime(document!.updatedAt!)),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _CardShell(
                    child: switch (snapshot) {
                      AsyncSnapshot(connectionState: ConnectionState.waiting) =>
                        const _Loading(),
                      AsyncSnapshot(hasError: true) ||
                      AsyncSnapshot(
                        data: null,
                      ) => _ErrorState(onRetry: _reload),
                      _ => LegalDocumentBody(document: snapshot.data!),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Date **and** time, in a plain unambiguous order — a numeric day/month
  /// order reads differently depending on where the reader is from.
  static String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

/// The glass card the document sits in — shared by the loading, error and
/// loaded states so the layout doesn't jump between them.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GlassPanel(
    // `rounded-card`, and the low-opacity brand-gradient fill from the design
    // files' "Liquid Glass Cards" — so the background photo reads through.
    borderRadius: 28,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    child: child,
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 160,
    child: Center(
      child: CircularProgressIndicator(color: AppColors.accent(context)),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              l10n.policyLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                l10n.tryAgain,
                style: TextStyle(
                  color: AppColors.accent(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
