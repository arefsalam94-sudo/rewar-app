import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/reset_target.dart';
import '../services/password_reset_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'verification_code_screen.dart';

/// Phase 1 — Forget Password screen (light mode only, all 3 languages).
///
/// Same photo/gradient background as Login. The user picks one contact
/// method (phone or email) and taps "Send Code", which sends the code and
/// opens the Verification Code screen.
///
/// IMPORTANT: the masked phone/email are still placeholders — the real
/// values have to come from the account being recovered, which needs the
/// identifier-lookup step this screen doesn't have yet (see PROGRESS.md).
class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  ResetMethod? _selected;
  bool _sending = false;

  /// Created here rather than in the next screen so the phone flow's
  /// `verificationId` survives the navigation to Verification Code.
  final PasswordResetService _service = PasswordResetService();

  // Placeholder contact details (from the mockup) — will be replaced with the
  // real account's data once the identifier-lookup step exists.
  static const String _phone = '+9647500009042';
  static const String _maskedPhone = '*** *** 9042';
  static const String _email = 'aref.salam94@gmail.com';
  static const String _maskedEmail = '*******sa@gmail.com';

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  ResetTarget _targetFor(ResetMethod method) => method == ResetMethod.phone
      ? const ResetTarget(
          method: ResetMethod.phone,
          value: _phone,
          maskedValue: _maskedPhone,
        )
      : const ResetTarget(
          method: ResetMethod.email,
          value: _email,
          maskedValue: _maskedEmail,
        );

  Future<void> _onSendCode() async {
    final l10n = AppLocalizations.of(context);
    final method = _selected;
    if (method == null) {
      _snack(l10n.selectContactMethod);
      return;
    }

    final target = _targetFor(method);
    setState(() => _sending = true);

    try {
      await _service.sendCode(target);
      if (!mounted) return;
      setState(() => _sending = false);
      // No SnackBar here on purpose: it renders at the bottom of the *next*
      // screen, directly over its Verify button, and swallows taps for four
      // seconds. The Verification screen shows a PreviewModeBanner instead.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              VerificationCodeScreen(target: target, service: _service),
        ),
      );
    } on ResetException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(
        e.kind == ResetErrorKind.backendUnavailable
            ? 'Firebase is not configured yet — see FIREBASE_SETUP.md'
            : e.kind == ResetErrorKind.network
            ? l10n.networkError
            : l10n.sendCodeFailed,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(l10n.sendCodeFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: PageBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button — kept top-left for every language.
                Align(
                  alignment: Alignment.centerLeft,
                  child: GlassBackButton(
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.forgetPassword,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 38,
                    height: 1.05,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.forgetPasswordSubtitle,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    color: AppColors.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 36),
                _ContactOption(
                  icon: Icons.phone,
                  label: l10n.phoneNumber,
                  value: _maskedPhone,
                  selected: _selected == ResetMethod.phone,
                  onTap: () => setState(() => _selected = ResetMethod.phone),
                ),
                const SizedBox(height: 16),
                _ContactOption(
                  icon: Icons.email,
                  label: l10n.emailAddress,
                  value: _maskedEmail,
                  selected: _selected == ResetMethod.email,
                  onTap: () => setState(() => _selected = ResetMethod.email),
                ),
                const SizedBox(height: 40),
                if (_sending)
                  SizedBox(
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent(context),
                      ),
                    ),
                  )
                else
                  PrimaryButton(label: l10n.sendCode, onTap: _onSendCode),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable contact-method row: circular icon + label + masked value,
/// in a glass panel that highlights when chosen.
class _ContactOption extends StatelessWidget {
  const _ContactOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return GlassPanel(
      borderRadius: 28,
      borderColor: selected ? AppColors.accent(context) : null,
      borderWidth: selected ? 2 : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppColors.luminousMint.withValues(alpha: 0.20)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                  child: Icon(icon, color: AppColors.accent(context), size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Phone/email stay LTR even in RTL layouts.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
