import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/legal_document.dart';
import '../services/legal_document_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/legal_document_body.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';

/// Phase 1 — Terms of Service (all 3 languages, light + dark).
///
/// A required gate between Register and phone verification: the account
/// already exists, but consent has not been recorded yet. Continue is
/// disabled until the checkbox is ticked, and records `termsAcceptedAt` +
/// `termsVersion` against the user before letting them through.
///
/// The wording is read from Firestore (`legal_documents/terms_of_service`)
/// so it can be updated without an app release — which is what the Terms
/// themselves promise.
class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({
    super.key,
    required this.onAccepted,
    this.service,
  });

  /// Called with the accepted document version once the user continues.
  /// Responsible for recording consent and moving the flow along.
  final Future<void> Function(int acceptedVersion) onAccepted;

  final LegalDocumentService? service;

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  late final LegalDocumentService _service =
      widget.service ?? LegalDocumentService();

  Future<LegalDocument>? _future;
  String? _loadedForLanguage;
  bool _accepted = false;
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch if the app language changed while this screen was alive, so
    // the user always reads the terms in the language they've chosen.
    final language = Localizations.localeOf(context).languageCode;
    if (_loadedForLanguage != language) {
      _loadedForLanguage = language;
      _future = _service.fetchTerms(language);
    }
  }

  void _reload() {
    setState(() {
      _future = _service.fetchTerms(
        Localizations.localeOf(context).languageCode,
      );
    });
  }

  Future<void> _onContinue(LegalDocument document) async {
    if (!_accepted || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onAccepted(document.version);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appDarkMode,
      builder: (context, isDark, _) => _buildScreen(context, isDark),
    );
  }

  Widget _buildScreen(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final theme = isDark
        ? AppTheme.darkForLocale(Localizations.localeOf(context))
        : AppTheme.lightForLocale(Localizations.localeOf(context));
    final colorScheme = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        body: PageBackground(
          dark: isDark,
          child: SafeArea(
            child: Padding(
              // Same insets as Login so the back button doesn't move.
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 82,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GlassBackButton(
                        dark: isDark,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                  Text(
                    l10n.termsOfService,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 38,
                      height: 1.05,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<LegalDocument>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _CardShell(
                            dark: isDark,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: isDark
                                    ? AppColors.luminousMint
                                    : AppColors.actionNavy,
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return _CardShell(
                            dark: isDark,
                            child: _ErrorState(onRetry: _reload, dark: isDark),
                          );
                        }
                        return _DocumentCard(
                          document: snapshot.data!,
                          dark: isDark,
                          accepted: _accepted,
                          onAcceptedChanged: (value) =>
                              setState(() => _accepted = value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<LegalDocument>(
                    future: _future,
                    builder: (context, snapshot) {
                      final document = snapshot.data;
                      final enabled =
                          _accepted && document != null && !_submitting;
                      return PrimaryButton(
                        label: l10n.continueLabel,
                        dark: isDark,
                        onTap: enabled ? () => _onContinue(document) : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The glass card the document sits in — shared by the loading, error and
/// loaded states so the layout doesn't jump between them.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.dark});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 28,
      dark: dark,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: child,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.dark});

  final VoidCallback onRetry;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(
            l10n.termsLoadFailed,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              l10n.tryAgain,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrollable document with the consent checkbox pinned at its end.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.dark,
    required this.accepted,
    required this.onAcceptedChanged,
  });

  final LegalDocument document;
  final bool dark;
  final bool accepted;
  final ValueChanged<bool> onAcceptedChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;
    final updatedAt = document.updatedAt;

    return _CardShell(
      dark: dark,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The document body refers to "the date at the top", so it has
            // to actually be there.
            if (updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.lastUpdated(_formatDate(updatedAt)),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText(context),
                  ),
                ),
              ),
            // Shared with the Policy hub's document pages. This screen and
            // the hub's "Terms & Conditions" row read the *same* Firestore
            // document, so a bullet has to render identically on both —
            // drawing it twice is how they would quietly stop matching.
            LegalDocumentBody(document: document),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => onAcceptedChanged(!accepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: accepted,
                      onChanged: (value) => onAcceptedChanged(value ?? false),
                      activeColor: accent,
                      side: BorderSide(
                        color: AppColors.secondaryText(context),
                        width: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.termsAgreeCheckbox,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plain ISO-style date — unambiguous in every locale, unlike a numeric
  /// day/month order.
  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
