import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/reset_target.dart';
import '../services/password_reset_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/page_background.dart';
import '../widgets/preview_mode_banner.dart';
import '../widgets/primary_button.dart';

/// Phase 1 — Reset Password screen (light mode only, all 3 languages).
///
/// Final step of the password reset: the user has proved control of their
/// phone or email on the Verification Code screen, and now sets a new
/// password. On success they are sent back to Login to sign in with it.
///
/// The password is handed straight to Firebase Auth (phone flow) or to the
/// Admin SDK in a Cloud Function (email flow) — it is never stored in
/// Firestore, logged, or cached.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.target,
    required this.verified,
    required this.service,
  });

  /// Which channel was verified, and the address/number behind it.
  final ResetTarget target;

  /// Proof from the Verification Code screen that the code was correct.
  final VerifiedReset verified;

  final PasswordResetService service;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// The rule stated on the screen itself: 8+ characters, with an uppercase
  /// letter, a lowercase letter and a special character.
  ///
  /// This is UX only — `SECURITY.md` 6.4 requires the same policy be
  /// configured in Firebase Auth, which is the real boundary. A client can
  /// always be bypassed.
  String? _validatePassword(String? value, AppLocalizations l10n) {
    final password = value ?? '';
    if (password.length < 8) return l10n.passwordTooShort;
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return l10n.passwordNeedsUppercase;
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return l10n.passwordNeedsLowercase;
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return l10n.passwordNeedsSpecial;
    }
    return null;
  }

  String? _validateConfirm(String? value, AppLocalizations l10n) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return l10n.confirmPasswordRequired;
    if (confirm != _passwordController.text) return l10n.passwordsDontMatch;
    return null;
  }

  String _messageFor(ResetErrorKind kind, AppLocalizations l10n) {
    switch (kind) {
      case ResetErrorKind.weakPassword:
        return l10n.passwordTooWeak;
      case ResetErrorKind.sessionExpired:
      case ResetErrorKind.expiredCode:
        return l10n.sessionExpired;
      case ResetErrorKind.tooManyAttempts:
        return l10n.tooManyAttempts;
      case ResetErrorKind.network:
        return l10n.networkError;
      case ResetErrorKind.backendUnavailable:
        return 'Firebase is not configured yet — see FIREBASE_SETUP.md';
      case ResetErrorKind.incorrectCode:
      case ResetErrorKind.unknown:
        return l10n.passwordUpdateFailed;
    }
  }

  Future<void> _onUpdatePassword() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.service.completePasswordReset(
        target: widget.target,
        verified: widget.verified,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.passwordUpdated)));

      // Back to Login, clearing the whole reset flow so Back can't walk
      // into a now-consumed verification step.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ResetException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _messageFor(e.kind, l10n);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = l10n.passwordUpdateFailed;
      });
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // Same insets as Login so the back button doesn't move.
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 24,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 82,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: GlassBackButton(
                                useAppLiquidGlass: true,
                                useCanonicalGlass: true,
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ),
                          ),
                          Text(
                            l10n.resetPassword,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 38,
                              height: 1.05,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.resetPasswordSubtitle,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.35,
                              color: AppColors.secondaryText(context),
                            ),
                          ),
                          const PreviewModeBanner(
                            message:
                                'Preview mode: the password will not '
                                'really be changed.',
                          ),
                          const SizedBox(height: 40),
                          AppRecessedGlassField(
                            controller: _passwordController,
                            hint: l10n.newPassword,
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            suffix: _EyeToggle(
                              obscured: _obscurePassword,
                              onTap: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: (value) =>
                                _validatePassword(value, l10n),
                            useV2FieldColors: true,
                            useCanonicalGlass: true,
                            layer: GlassLayer.surface,
                            dropShadow: false,
                          ),
                          const SizedBox(height: 18),
                          AppRecessedGlassField(
                            controller: _confirmController,
                            hint: l10n.confirmPassword,
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _onUpdatePassword(),
                            suffix: _EyeToggle(
                              obscured: _obscureConfirm,
                              onTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            validator: (value) => _validateConfirm(value, l10n),
                            useV2FieldColors: true,
                            useCanonicalGlass: true,
                            layer: GlassLayer.surface,
                            dropShadow: false,
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 18),
                            Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 36),
                          PrimaryButton(
                            label: l10n.updatePassword,
                            onTap: _submitting ? null : _onUpdatePassword,
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Show/hide password eye, matching the mockup's crossed-out eye default.
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      // Keeps the tap target at the 48dp minimum even though the glyph is 22.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.accent(context),
        size: 22,
      ),
    );
  }
}
