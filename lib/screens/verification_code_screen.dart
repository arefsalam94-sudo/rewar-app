import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/reset_target.dart';
import '../services/email_verification_service.dart';
import '../services/password_reset_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'account_setup_screen.dart';
import 'reset_password_screen.dart';

/// How many digits the code has. Firebase's phone-auth SMS codes are 6
/// digits, and the email Cloud Function generates 6 to match.
const int _codeLength = 6;

/// How long the user must wait before "Resend now" becomes tappable again.
/// Required by `SECURITY.md` 6.4 (rate-limit password resets) — the server
/// enforces its own limit too; this is the UX half of it.
const Duration _resendCooldown = Duration(seconds: 60);

/// What the code is being checked for. Only changes the subtitle wording and
/// where a successful verification goes — the code entry itself is identical,
/// so the two flows share one screen.
enum VerificationPurpose {
  /// Step 2 of the password reset, arriving from Forget Password.
  passwordReset,

  /// Confirming the phone number entered on the Register screen.
  registration,

  /// Confirming the **email** entered on the Register screen, before the
  /// phone step. Registration collects an address but previously had no way
  /// of knowing it was real; a typo produced an account that could never
  /// receive a password reset.
  registrationEmail,
}

/// Phase 1 — Verification Code screen (light mode only, all 3 languages).
///
/// Step 2 of the password reset: the user has already picked phone or email
/// on the Forget Password screen and a code has been sent there. Here they
/// type the 6-digit code, can resend it, and verify.
///
/// On success this hands a [VerifiedReset] to [onVerified] — the actual
/// password change belongs to the Set New Password screen, which has not been
/// designed yet.
class VerificationCodeScreen extends StatefulWidget {
  const VerificationCodeScreen({
    super.key,
    required this.target,
    required this.service,
    this.onVerified,
    this.purpose = VerificationPurpose.passwordReset,
    this.registeredName = '',
    this.emailVerificationService,
    this.onEmailVerified,
  });

  /// Which flow this screen is serving.
  final VerificationPurpose purpose;

  /// Required when [purpose] is [VerificationPurpose.registrationEmail]; the
  /// registration email code is issued by its own Cloud Function rather than
  /// the password-reset one.
  final EmailVerificationService? emailVerificationService;

  /// Registration-email flow only: what to do once the address is confirmed.
  /// Production passes the step that continues to phone verification; tests
  /// pass their own.
  final VoidCallback? onEmailVerified;

  /// Registration flow only: the name from Register, carried through so
  /// Account Setup can pre-fill it.
  final String registeredName;

  /// Which channel the code went to, and the masked value to display.
  final ResetTarget target;

  /// Shared with the Forget Password screen so the phone flow's
  /// `verificationId` survives the navigation.
  final PasswordResetService service;

  /// Overrides the default "push Reset Password" behaviour. Only used by
  /// tests; production leaves it null.
  final void Function(VerifiedReset)? onVerified;

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _cooldownTimer;
  int _secondsLeft = _resendCooldown.inSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _errorText;

  /// Positive confirmation (e.g. "a new code has been sent"), shown in the
  /// same slot as [_errorText]. Inline rather than a SnackBar, which would
  /// sit on top of the Verify button.
  String? _noticeText;

  String get _code => _controller.text;
  bool get _isComplete => _code.length == _codeLength;
  bool get _canResend => _secondsLeft == 0 && !_resending;

  @override
  void initState() {
    super.initState();
    // The code was already sent by the Forget Password screen, so the
    // cooldown starts counting the moment this screen opens.
    _startCooldown();
    _controller.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.removeListener(_onCodeChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    // Clearing the error as soon as they start correcting it avoids a stale
    // "wrong code" sitting under a code they've already fixed. The cells
    // themselves redraw from the controller directly, so no other rebuild is
    // needed per keystroke.
    if (_errorText != null || _noticeText != null) {
      setState(() {
        _errorText = null;
        _noticeText = null;
      });
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _resendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  /// Maps a backend failure onto a localized message. Raw Firebase strings
  /// are never shown to the user.
  String _messageFor(ResetErrorKind kind, AppLocalizations l10n) {
    switch (kind) {
      case ResetErrorKind.incorrectCode:
        return l10n.codeIncorrect;
      case ResetErrorKind.expiredCode:
        return l10n.codeExpired;
      case ResetErrorKind.tooManyAttempts:
        return l10n.tooManyAttempts;
      case ResetErrorKind.network:
        return l10n.networkError;
      case ResetErrorKind.sessionExpired:
        return l10n.sessionExpired;
      case ResetErrorKind.backendUnavailable:
        return 'Firebase is not configured yet — see FIREBASE_SETUP.md';
      // Not reachable from this screen (no password is set here), but the
      // switch must stay exhaustive.
      case ResetErrorKind.weakPassword:
      case ResetErrorKind.unknown:
        return l10n.sendCodeFailed;
    }
  }

  Future<void> _onVerify() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

    if (!_isComplete) {
      setState(() => _errorText = l10n.codeIncomplete);
      return;
    }

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      // The registration-email step is issued by its own Cloud Function and
      // returns no reset proof — it only confirms the address is reachable.
      if (widget.purpose == VerificationPurpose.registrationEmail) {
        await widget.emailVerificationService!.verifyCode(_code);
        if (!mounted) return;
        setState(() => _verifying = false);
        widget.onEmailVerified?.call();
        return;
      }

      final result = await widget.service.verifyCode(widget.target, _code);
      if (!mounted) return;
      setState(() => _verifying = false);
      final onVerified = widget.onVerified;
      if (onVerified != null) {
        onVerified(result);
        return;
      }

      if (widget.purpose == VerificationPurpose.registration) {
        // Number confirmed. Replace this route with Account Setup so Back
        // can't return to a verification step that has already been consumed.
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                AccountSetupScreen(initialName: widget.registeredName),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            target: widget.target,
            verified: result,
            service: widget.service,
          ),
        ),
      );
    } on ResetException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorText = _messageFor(e.kind, l10n);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorText = l10n.sendCodeFailed;
      });
    }
  }

  Future<void> _onResend() async {
    if (!_canResend) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _resending = true;
      _errorText = null;
      _noticeText = null;
    });

    try {
      if (widget.purpose == VerificationPurpose.registrationEmail) {
        await widget.emailVerificationService!.sendCode();
      } else {
        await widget.service.sendCode(widget.target);
      }
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _resending = false;
        // Shown inline rather than as a SnackBar: a SnackBar covers the
        // Verify button at the bottom of this screen and eats taps on it.
        _noticeText = widget.target.isPhone
            ? l10n.codeResentPhone
            : l10n.codeResentEmail;
      });
      _startCooldown();
      _focusNode.requestFocus();
    } on ResetException catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _errorText = _messageFor(e.kind, l10n);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _errorText = l10n.sendCodeFailed;
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
                // Same horizontal padding and top inset as the Login screen so
                // the back button lands in exactly the same place.
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 24,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back button: same 82px bar / left alignment as Login.
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
                          // The email step names what is being verified, so
                          // two consecutive code screens during registration
                          // are not mistaken for one another.
                          widget.purpose ==
                                  VerificationPurpose.registrationEmail
                              ? l10n.verifyEmailTitle
                              : l10n.verificationCode,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 38,
                            height: 1.05,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Subtitle(
                          maskedValue: widget.target.maskedValue,
                          purpose: widget.purpose,
                        ),
                        const SizedBox(height: 40),
                        _CodeBox(
                          controller: _controller,
                          focusNode: _focusNode,
                        ),
                        const SizedBox(height: 18),
                        _ResendRow(
                          secondsLeft: _secondsLeft,
                          busy: _resending,
                          onResend: _onResend,
                        ),
                        if (_errorText != null || _noticeText != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorText ?? _noticeText!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _errorText != null
                                  ? colorScheme.error
                                  : AppColors.accent(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),
                        _verifying
                            ? SizedBox(
                                height: 56,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent(context),
                                  ),
                                ),
                              )
                            : PrimaryButton(
                                label: l10n.verify,
                                onTap: _onVerify,
                              ),
                        const SizedBox(height: 8),
                      ],
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

/// "Enter the 6-digit code we just sent to **\*\*\* \*\*\* 9042** to reset
/// your password." — the destination is bold and always rendered
/// left-to-right, even inside the Kurdish/Arabic right-to-left sentence.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.maskedValue, required this.purpose});

  final String maskedValue;
  final VerificationPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final (before, after) = switch (purpose) {
      VerificationPurpose.registration => l10n.verifyNumberSubtitleParts(),
      VerificationPurpose.registrationEmail => l10n.verifyEmailSubtitleParts(),
      VerificationPurpose.passwordReset => l10n.verificationSubtitleParts(),
    };

    final baseStyle = TextStyle(
      fontSize: 18,
      height: 1.35,
      color: AppColors.secondaryText(context),
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                maskedValue,
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

/// The 6-slot code field.
///
/// A single real (but invisible) [TextField] sits behind the panel so the
/// platform gives us paste, OS-level SMS autofill (`oneTimeCode`) and correct
/// backspace behaviour for free; the visible cells are drawn from its value.
///
/// The code panel follows the shared glass treatment while keeping its
/// six-cell structure and left-to-right data direction.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  static const double _height = 96;
  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark
        ? AppColors.darkGlassShadowColor
        : AppColors.lightGlassShadowColor;
    final shadowOpacity = isDark
        ? AppColors.darkGlassShadowOpacity
        : AppColors.lightGlassShadowOpacity;

    return SizedBox(
      height: _height,
      child: Stack(
        children: [
          // The real input — invisible, but focusable and fully functional.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                // Lets iOS/Android offer the code straight from the SMS.
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_codeLength),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: focusNode.requestFocus,
              // Same canonical renderer every other real-glass surface in
              // the app uses (`Design_system_CANONICAL.md` §9) — retires
              // the old V2 default this call site used to fall back to.
              // Shadow/radius unchanged.
              child: CanonicalGlassShell(
                borderRadius: _radius,
                shadow: BoxShadow(
                  color: shadowColor.withValues(alpha: shadowOpacity),
                  offset: const Offset(0, AppColors.glassFloatingShadowOffsetY),
                  blurRadius: AppColors.glassFloatingShadowBlurRadius,
                  spreadRadius: AppColors.glassFloatingShadowSpreadRadius,
                ),
                // The code itself always reads left-to-right, including in
                // Kurdish and Arabic.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => _cells(context, value.text),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cells(BuildContext context, String code) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    for (var i = 0; i < _codeLength; i++) {
      if (i > 0) {
        children.add(
          Container(
            width: 1,
            height: 46,
            color: colorScheme.onSurface.withValues(alpha: 0.22),
          ),
        );
      }
      final hasDigit = i < code.length;
      children.add(
        Expanded(
          child: Center(
            child: hasDigit
                ? Text(
                    code[i],
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  )
                : Padding(
                    // Sits the placement line low in the cell, where the
                    // baseline of a typed digit would be.
                    padding: const EdgeInsets.only(top: 32),
                    child: Container(
                      width: 26,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

/// "Didn't receive the code? Resend now", or the countdown while the resend
/// is on cooldown.
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.busy,
    required this.onResend,
  });

  final int secondsLeft;
  final bool busy;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final onCooldown = secondsLeft > 0;

    if (busy) {
      return Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.accent(context),
          ),
        ),
      );
    }

    return Center(
      child: GestureDetector(
        onTap: onCooldown ? null : onResend,
        behavior: HitTestBehavior.opaque,
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondaryText(context),
            ),
            children: [
              TextSpan(text: l10n.didntReceiveCode),
              TextSpan(
                text: onCooldown ? l10n.resendIn(secondsLeft) : l10n.resendNow,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: onCooldown
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.75)
                      : AppColors.accent(context),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
