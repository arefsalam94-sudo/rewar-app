import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/registration.dart';
import '../models/reset_target.dart';
import '../services/auth_service.dart';
import '../services/email_verification_service.dart';
import '../services/password_reset_service.dart';
import '../services/preview_identity.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/page_background.dart';
import '../widgets/preview_mode_banner.dart';
import '../widgets/primary_button.dart';
import 'terms_of_service_screen.dart';
import 'verification_code_screen.dart';

/// Phase 1 — Register screen (all 3 languages, light + dark).
///
/// Reached from "Register Now" on Login. Collects the full profile, creates
/// the Firebase Auth account, writes `users/{uid}`, then sends the user to
/// the Verification Code screen to confirm the phone number they entered.
///
/// Gender is the only optional field, by explicit decision.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final AuthService _authService = AuthService();

  DateTime? _dateOfBirth;
  Gender? _gender;
  CountryCode _country = CountryCode.defaultCountry;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  // Terms consent is captured on the Terms of Service screen, not here.
  String? _errorText;

  bool get _darkMode => appDarkMode.value;

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // --- Pickers -------------------------------------------------------------

  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    // Opens on the 18th birthday boundary, the most likely starting point,
    // rather than today (which would be an impossible date of birth).
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? eighteenYearsAgo,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: AppLocalizations.of(context).age,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      // The field shows the resulting age, as the mockup labels it "Age";
      // Firestore stores the date itself so it never goes stale.
      _dobController.text = '${_ageFrom(picked)}';
    });
  }

  static int _ageFrom(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  Future<void> _pickGender() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<Gender>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _GenderSheet(selected: _gender, dark: _darkMode),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _gender = picked;
      _genderController.text = picked.label(l10n);
    });
  }

  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _CountrySheet(selected: _country, dark: _darkMode),
    );
    if (picked == null || !mounted) return;
    setState(() => _country = picked);
  }

  // --- Validation ----------------------------------------------------------

  String? _validateName(String? value, AppLocalizations l10n) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return l10n.fullNameRequired;
    if (name.length < 2) return l10n.fullNameTooShort;
    return null;
  }

  String? _validateDob(AppLocalizations l10n) {
    final dob = _dateOfBirth;
    if (dob == null) return l10n.dateOfBirthRequired;
    // Booking and Agoda both require 18+ to hold an account.
    if (_ageFrom(dob) < 18) return l10n.mustBe18;
    return null;
  }

  String? _validatePhone(String? value, AppLocalizations l10n) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return l10n.phoneRequired;
    if (!_country.isPlausible(phone)) return l10n.phoneInvalid;
    return null;
  }

  String? _validateEmail(String? value, AppLocalizations l10n) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return l10n.emailRequired;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return l10n.emailInvalid;
    }
    return null;
  }

  /// Same policy as the Reset Password screen, and the same one enforced
  /// server-side in `functions/index.js`.
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

  String _messageFor(AuthErrorKind kind, AppLocalizations l10n) {
    switch (kind) {
      case AuthErrorKind.emailAlreadyInUse:
        return l10n.emailInUse;
      case AuthErrorKind.invalidEmail:
        return l10n.emailInvalid;
      case AuthErrorKind.weakPassword:
        return l10n.passwordTooWeak;
      case AuthErrorKind.network:
        return l10n.networkError;
      case AuthErrorKind.tooManyRequests:
        return l10n.tooManyAttempts;
      case AuthErrorKind.backendUnavailable:
        return 'Firebase is not configured yet — see FIREBASE_SETUP.md';
      case AuthErrorKind.unknown:
        return l10n.registerFailed;
    }
  }

  // --- Submit --------------------------------------------------------------

  Future<void> _onRegister() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

    // Date of birth lives outside the Form, so it is validated explicitly
    // rather than by a field validator.
    final dobError = _validateDob(l10n);
    final formOk = _formKey.currentState?.validate() ?? false;

    if (dobError != null || !formOk) {
      setState(() => _errorText = dobError);
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final phoneE164 = _country.toE164(_phoneController.text);
    final details = RegistrationDetails(
      fullName: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      phoneE164: phoneE164,
      email: _emailController.text.trim(),
      gender: _gender,
    );

    try {
      await _authService.register(
        details: details,
        password: _passwordController.text,
      );
      // Records what was entered so the side drawer and Settings can show this
      // user rather than the built-in stand-in profile. Preview-mode only —
      // once Firebase exists, `users/{uid}` is the source of truth. Never
      // includes the password.
      await PreviewIdentity.save(
        name: details.fullName,
        email: details.email,
        phone: details.phoneE164,
      );
      if (!mounted) return;
      setState(() => _submitting = false);

      // The account now exists but consent hasn't been recorded, so Terms is
      // a required gate before the number is verified.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TermsOfServiceScreen(
            onAccepted: (version) =>
                _onTermsAccepted(version, phoneE164: phoneE164),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _messageFor(e.kind, l10n);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = l10n.registerFailed;
      });
    }
  }

  /// Runs when the user accepts on the Terms screen: records consent against
  /// the version they actually read, emails a six-digit code, then swaps Terms
  /// for the email verification step so Back can't return to a consent step
  /// that has already been recorded.
  ///
  /// **Email is verified before phone.** Registration collects an address but
  /// had no way of knowing it was real — a typo produced an account that could
  /// never receive a password reset. Email comes first because it is the
  /// account's recovery channel; the number is confirmed straight afterwards.
  Future<void> _onTermsAccepted(
    int version, {
    required String phoneE164,
  }) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();

    try {
      await _authService.recordTermsAcceptance(version);

      final emailService = EmailVerificationService();
      await emailService.sendCode();

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerificationCodeScreen(
            target: ResetTarget(
              method: ResetMethod.email,
              value: email,
              maskedValue: _maskEmail(email),
            ),
            // Unused by the email branch, but the screen's constructor is
            // shared with the password-reset flow.
            service: PasswordResetService(),
            emailVerificationService: emailService,
            purpose: VerificationPurpose.registrationEmail,
            registeredName: _nameController.text.trim(),
            onEmailVerified: () => _onEmailVerified(phoneE164: phoneE164),
          ),
        ),
      );
    } catch (e) {
      // The Terms screen stays put so the user can retry Continue.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.registerFailed)));
    }
  }

  /// Email confirmed — send the SMS and replace the email step with the phone
  /// step, so Back cannot return to a code that has already been consumed.
  Future<void> _onEmailVerified({required String phoneE164}) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final resetService = PasswordResetService();
    final target = ResetTarget(
      method: ResetMethod.phone,
      value: phoneE164,
      maskedValue: _maskPhone(phoneE164),
    );

    try {
      await resetService.sendCode(target);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerificationCodeScreen(
            target: target,
            service: resetService,
            purpose: VerificationPurpose.registration,
            registeredName: _nameController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      // The email step stays put so the user can retry rather than losing a
      // verification they have already passed.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sendCodeFailed)));
    }
  }

  /// `sara.ahmad@gmail.com` → `s*********d@gmail.com`, matching the Forget
  /// Password mask: enough to recognise your own address, not enough to read
  /// someone else's off the screen.
  static String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final local = email.substring(at);
    final name = email.substring(0, at);
    if (name.length <= 2) return '${name[0]}*$local';
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}$local';
  }

  /// `+9647500009042` → `*** *** 9042`, matching the Forget Password mask.
  static String _maskPhone(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    return '*** *** $last4';
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appDarkMode,
      builder: (context, _, _) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = _darkMode
        ? AppTheme.darkForLocale(Localizations.localeOf(context))
        : AppTheme.lightForLocale(Localizations.localeOf(context));
    final colorScheme = theme.colorScheme;
    final accent = AppColors.selectionAccent(context);

    return Theme(
      data: theme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: PageBackground(
          dark: _darkMode,
          child: SafeArea(
            child: SingleChildScrollView(
              // Same insets as Login so the back button doesn't move.
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                          dark: _darkMode,
                          useAppLiquidGlass: true,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    Text(
                      l10n.register,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 38,
                        height: 1.05,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const PreviewModeBanner(
                      message:
                          'Preview mode: no account will really be '
                          'created.',
                    ),
                    const SizedBox(height: 24),
                    // Every input lives in one card; the title above and the
                    // Register button below sit outside it.
                    //
                    // Fill/border come straight from `DESIGN light.md`
                    // ("Card Fill: a 20% opacity version of the brand
                    // gradient", "1px white inner border (20% opacity)") via
                    // old brand-gradient card fill, and from the former
                    // emerald glass in dark mode. Radius is the light file's
                    // "Standard Cards: 16px".
                    AppLiquidGlass(
                      borderRadius: 28,
                      dark: _darkMode,
                      quality: AppLiquidGlassQuality.standard,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppRecessedGlassField(
                            controller: _nameController,
                            hint: l10n.fullName,
                            prefixIcon: Icons.person_outline,
                            dark: _darkMode,
                            textInputAction: TextInputAction.next,
                            validator: (value) => _validateName(value, l10n),
                          ),
                          const SizedBox(height: 14),
                          AppRecessedGlassField(
                            controller: _dobController,
                            hint: l10n.age,
                            prefixIcon: Icons.calendar_today_outlined,
                            dark: _darkMode,
                            readOnly: true,
                            onTap: _pickDateOfBirth,
                            suffix: Icon(
                              Icons.keyboard_arrow_down,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 14),
                          AppRecessedGlassField(
                            controller: _genderController,
                            hint: l10n.genderOptional,
                            prefixIcon: Icons.person_add_alt,
                            dark: _darkMode,
                            readOnly: true,
                            onTap: _pickGender,
                            suffix: Icon(
                              Icons.keyboard_arrow_down,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 14),
                          AppRecessedGlassField(
                            controller: _phoneController,
                            hint: l10n.phoneNumber,
                            prefixIcon: Icons.phone_outlined,
                            dark: _darkMode,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            prefix: _CountryCodeButton(
                              country: _country,
                              onTap: _pickCountry,
                              color: colorScheme.onSurface,
                            ),
                            validator: (value) => _validatePhone(value, l10n),
                          ),
                          const SizedBox(height: 14),
                          AppRecessedGlassField(
                            controller: _emailController,
                            hint: l10n.emailAddress,
                            prefixIcon: Icons.mail_outline,
                            dark: _darkMode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) => _validateEmail(value, l10n),
                          ),
                          const SizedBox(height: 14),
                          AppRecessedGlassField(
                            controller: _passwordController,
                            hint: l10n.password,
                            prefixIcon: Icons.lock_outline,
                            dark: _darkMode,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            suffix: _EyeToggle(
                              obscured: _obscurePassword,
                              color: accent,
                              onTap: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: (value) =>
                                _validatePassword(value, l10n),
                          ),
                          const SizedBox(height: 14),
                          AppRecessedGlassField(
                            controller: _confirmController,
                            hint: l10n.confirmPassword,
                            prefixIcon: Icons.lock_outline,
                            dark: _darkMode,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            suffix: _EyeToggle(
                              obscured: _obscureConfirm,
                              color: accent,
                              onTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            validator: (value) => _validateConfirm(value, l10n),
                          ),
                          const SizedBox(height: 10),
                          // Booking and Agoda both state the password rule up
                          // front rather than only on failure.
                          Text(
                            l10n.passwordHint,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: AppColors.onPhotoSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Terms consent is NOT collected here — it is a required
                    // step on the Terms of Service screen, which opens
                    // immediately after this form submits.
                    if (_errorText != null) ...[
                      const SizedBox(height: 14),
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
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: l10n.register,
                      dark: _darkMode,
                      onTap: _submitting ? null : _onRegister,
                    ),
                    const SizedBox(height: 20),
                    _OrDivider(color: AppColors.onPhotoSecondary(context)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            icon: Icon(Icons.apple, size: 24, color: accent),
                            label: 'Apple',
                            dark: _darkMode,
                            onTap: () => _notWired('Apple'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SocialButton(
                            icon: Icon(
                              Icons.g_mobiledata,
                              size: 30,
                              color: accent,
                            ),
                            label: 'Gmail',
                            dark: _darkMode,
                            onTap: () => _notWired('Google'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: GestureDetector(
                        // Back to Login rather than a new route, so the two
                        // screens can't stack up on each other indefinitely.
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.onPhotoSecondary(context),
                            ),
                            children: [
                              TextSpan(text: l10n.alreadyHaveAccount),
                              TextSpan(
                                text: l10n.logInHere,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: accent,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _notWired(String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Would sign up with $provider '
            '(backend not connected yet)',
          ),
        ),
      );
  }
}

/// Tappable `🇮🇶 +964` prefix that opens the country sheet.
class _CountryCodeButton extends StatelessWidget {
  const _CountryCodeButton({
    required this.country,
    required this.onTap,
    required this.color,
  });

  final CountryCode country;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(country.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          // The dial code stays left-to-right even under RTL.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              country.dialCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 20, color: color),
        ],
      ),
    );
  }
}

/// Bottom sheet listing the three gender options.
class _GenderSheet extends StatelessWidget {
  const _GenderSheet({required this.selected, required this.dark});

  final Gender? selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AppLiquidGlass(
          borderRadius: 20,
          dark: dark,
          quality: AppLiquidGlassQuality.standard,
          // Scrollable for the same reason the country sheet is: a modal
          // sheet is capped at 9/16 of the screen, which three options can
          // exceed on a short phone once the system font is enlarged.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, gender) in Gender.values.indexed) ...[
                  // A white hairline between options, so they read as
                  // separate rows rather than one block of text.
                  if (index > 0) const _SheetDivider(),
                  _SheetOptionTile(
                    label: gender.label(l10n),
                    selected: selected == gender,
                    accent: accent,
                    textColor: colorScheme.onSurface,
                    onTap: () => Navigator.of(context).pop(gender),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single option inside the gender sheet.
///
/// Each row is its own rounded tile with a soft white glow, so the options
/// read as separate cards rather than one continuous list.
class _SheetOptionTile extends StatelessWidget {
  const _SheetOptionTile({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: GlassPanel(
        borderRadius: 14,
        depth: GlassDepth.top,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (selected) Icon(Icons.check, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The white hairline drawn between two [_SheetOptionTile]s.
class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.55)),
    );
  }
}

/// Bottom sheet listing the supported dialling codes.
class _CountrySheet extends StatelessWidget {
  const _CountrySheet({required this.selected, required this.dark});

  final CountryCode selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AppLiquidGlass(
          borderRadius: 20,
          dark: dark,
          quality: AppLiquidGlassQuality.standard,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final country in CountryCode.all)
                ListTile(
                  leading: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${country.dialCode}  (${country.isoCode})',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                  trailing: selected.isoCode == country.isoCode
                      ? Icon(Icons.check, color: accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(country),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "———— Or ————".
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(
      child: Container(height: 1.2, color: color.withValues(alpha: 0.45)),
    );
    return Row(
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AppLocalizations.of(context).orLabel,
            style: TextStyle(color: color, fontSize: 15),
          ),
        ),
        line(),
      ],
    );
  }
}

/// Frosted social sign-up button, matching Login's.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dark,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppLiquidGlass(
      borderRadius: 14,
      dark: dark,
      quality: AppLiquidGlassQuality.standard,
      interactive: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8),
                // Same guard as Login's social buttons: two share the row, so
                // the label must be allowed to shrink rather than overflow on
                // a narrow screen or at an enlarged system font size.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: colorScheme.onSurface,
                      ),
                    ),
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

/// Show/hide password eye with a 48dp tap target.
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({
    required this.obscured,
    required this.onTap,
    required this.color,
  });

  final bool obscured;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: color,
        size: 22,
      ),
    );
  }
}
