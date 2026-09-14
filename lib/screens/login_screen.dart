import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/auth_glass_field.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_auth_button.dart';
import 'forget_password_screen.dart';
import 'home_screen.dart';
import 'language_selection_screen.dart';
import 'register_screen.dart';

/// Phase 1 — Login / Auth screen (light mode only).
///
/// Photo background under a green gradient, a back button, the logo, and a
/// "liquid glass" card containing the login form, social sign-in, and
/// register link, with "Continue as Guest" outside the card.
///
/// Email + password sign-in runs against **real Firebase Auth**
/// ([AuthService.signIn], `SECURITY.md` 6.1). The password is handed to the
/// SDK and nothing else — it is never logged, cached, or persisted.
///
/// The two social buttons are still honestly [_notWired]: Apple and Google
/// sign-in providers have not been configured. They say so rather than
/// failing silently.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.languageCode = 'en'});

  /// The language the user picked on the Language screen ('en' | 'ku' | 'ar').
  final String languageCode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// True while a sign-in request is in flight. Disables the button so a
  /// double-tap cannot fire two attempts, which would burn a second try
  /// against Firebase's own rate limiter (`SECURITY.md` 6.4).
  bool _submitting = false;

  /// Localized failure text shown under the form. Same idiom as Register.
  String? _errorText;

  /// Mirrors the app-wide [appDarkMode] notifier, which the toggle on the
  /// **Language** screen owns. This screen only reads it — there is no toggle
  /// here any more.
  bool get _darkMode => appDarkMode.value;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Temporary stand-in for any action that will need the (not-yet-configured)
  /// Firebase backend. Keeps the UI honest — it says what *will* happen.
  void _notWired(String whatItWillDo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$whatItWillDo (backend not connected yet)')),
      );
  }

  String _messageFor(AuthErrorKind kind, AppLocalizations l10n) {
    switch (kind) {
      case AuthErrorKind.invalidCredentials:
        return l10n.invalidCredentials;
      case AuthErrorKind.userDisabled:
        return l10n.accountDisabled;
      case AuthErrorKind.invalidEmail:
        return l10n.emailInvalid;
      case AuthErrorKind.network:
        return l10n.networkError;
      case AuthErrorKind.tooManyRequests:
        return l10n.tooManyAttempts;
      case AuthErrorKind.backendUnavailable:
        return 'Firebase is not configured yet — see FIREBASE_SETUP.md';
      // Registration outcomes. Unreachable from this screen, which only signs
      // existing users in, but the enum is shared so the switch stays
      // exhaustive.
      case AuthErrorKind.emailAlreadyInUse:
      case AuthErrorKind.weakPassword:
      case AuthErrorKind.unknown:
        return l10n.loginFailed;
    }
  }

  /// Sends the user to the dashboard. `pushReplacement`, so Back from there
  /// doesn't return to Login — the auth flow is finished. Same rule as
  /// Continue as Guest.
  void _enterApp(String? displayName) {
    Navigator.of(context).pushReplacement(
<<<<<<< HEAD
      HomeScreen.route(
        isGuest: false,
        displayName: AuthService.previewDisplayName,
=======
      MaterialPageRoute<void>(
        builder: (_) =>
            HomeScreen(isGuest: false, displayName: displayName),
>>>>>>> ab113c6 (Latest app update)
      ),
    );
  }

  Future<void> _onLogin() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final displayName = await AuthService().signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // The password controller is cleared before navigating so the entered
      // secret does not sit in a live TextEditingController behind the
      // dashboard for the rest of the session.
      _passwordController.clear();
      _enterApp(displayName);
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
        _errorText = l10n.loginFailed;
      });
    }
  }

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
      );
    }
  }

  /// Enters the app without an account. The home screen is fully browsable
  /// as a guest; only saving a favourite prompts for sign-in.
  ///
  /// `pushReplacement`, so Back from the dashboard doesn't return to Login —
  /// the auth flow is finished either way.
  void _onContinueAsGuest() {
    Navigator.of(context).pushReplacement(HomeScreen.route());
  }

  void _onForgetPassword() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ForgetPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds if the mode is changed elsewhere while this screen is alive.
    return ValueListenableBuilder<bool>(
      valueListenable: appDarkMode,
      builder: (context, _, _) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    // Swapping the whole subtree's ThemeData is what makes every `Text` and
    // `colorScheme.*` lookup on this screen flip at once, instead of
    // scattering if/else colour branches through the widget tree.
    final theme = _darkMode
        ? AppTheme.darkForLocale(Localizations.localeOf(context))
        : AppTheme.lightForLocale(Localizations.localeOf(context));

    return Theme(
      data: theme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: PageBackground(
          dark: _darkMode,
          // `background-gradient-opacity: 0.45` (Design_system_CANONICAL.md
          // §8). Local override — the shared default (0.55) stays untouched
          // for every other screen.
          gradientOpacity: 0.45,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          _TopBar(onBack: _onBack, dark: _darkMode),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildCard(),
                          ),
                          const SizedBox(height: 18),
                          _GuestButton(onTap: _onContinueAsGuest),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final l10n = AppLocalizations.of(context);

    // The outer card is a NON-SHADER grouping (`GlassLayer.embedded` →
    // `_EmbeddedGlass`): the canonical body tint at the embedded opacity, the
    // same radius, padding and content positioning, but no second
    // `OCLiquidGlass`, no second blur and no second specular rim.
    //
    // APPROVED, NOT TEMPORARY — do not convert this back to
    // `GlassLayer.surface`. This card contains four independent real-glass
    // children (the Email and Password fields, and the Apple and Gmail
    // buttons). Wrapping them in a fifth real shader is the nested-glass
    // condition `01_DESIGN_SYSTEM_CANONICAL.md` §5 forbids: when the keyboard
    // opens, `resizeToAvoidBottomInset` reflows the viewport and the scroll
    // view moves the card, and the nested backdrop-filter composition became
    // visually unstable — the fields flattened and grew horizontal
    // lower-edge bands. Register has never shown it because its outer
    // grouping has always been non-shader; this is the same fix, through the
    // renderer's own `embedded` layer rather than a second hand-built one.
    //
    // The rule is to demote the *parent*, never the children — the two fields
    // below stay exactly as they were, each its own real canonical surface.
    // See `07_DESIGN_EXCEPTIONS.md` §1 and §20.
    return AppLiquidGlass(
      useCanonicalGlass: true,
      layer: GlassLayer.embedded,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.logIn,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 28,
                // `text-heading` (Design_system_CANONICAL.md §11).
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 22),
            AuthGlassField(
              controller: _emailController,
              hint: l10n.email,
              keyboardType: TextInputType.emailAddress,
              dark: _darkMode,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return l10n.emailRequired;
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRegex.hasMatch(text)) {
                  return l10n.emailInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthGlassField(
              controller: _passwordController,
              hint: l10n.password,
              obscureText: _obscurePassword,
              dark: _darkMode,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  // `field-icon` (Design_system_CANONICAL.md §12) — this
                  // toggle lives inside the password field.
                  color: AppColors.fieldIcon(context),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return l10n.passwordRequired;
                return null;
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: GestureDetector(
                onTap: _onForgetPassword,
                child: Text(
                  l10n.forgetPassword,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    // `authActionLink` — same color on photo or glass.
                    color: AppColors.authActionLink(context),
                  ),
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: l10n.logIn,
              onTap: _submitting ? null : _onLogin,
              dark: _darkMode,
            ),
            const SizedBox(height: 20),
            const _OrDivider(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SocialAuthButton(
                    icon: Icon(
                      Icons.apple,
                      size: 24,
                      // `socialAuthContent`.
                      color: AppColors.socialAuthContent(context),
                    ),
                    label: 'Apple',
                    dark: _darkMode,
                    onTap: () => _notWired('Would sign in with Apple'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SocialAuthButton(
                    icon: Icon(
                      Icons.g_mobiledata,
                      size: 30,
                      // `socialAuthContent`.
                      color: AppColors.socialAuthContent(context),
                    ),
                    label: 'Gmail',
                    dark: _darkMode,
                    onTap: () => _notWired('Would sign in with Google'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      // `text-secondary` (Design_system_CANONICAL.md §11).
                      color: AppColors.secondaryTextV3(context),
                    ),
                    children: [
                      TextSpan(text: l10n.dontHaveAccount),
                      TextSpan(
                        text: l10n.registerNow,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          // `authActionLink` — same color on photo or
                          // glass.
                          color: AppColors.authActionLink(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top bar: circular glass back button (top-left, all languages) and the
/// centered logo.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, this.dark = false});

  final VoidCallback onBack;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GlassBackButton(
              onTap: onBack,
              dark: dark,
              useAppLiquidGlass: true,
              useCanonicalGlass: true,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/logo.png',
              height: 74,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                'Logo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: AppColors.heading(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "———— Or ————" divider.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final color = AppColors.secondaryTextV3(context);
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

/// "Continue as Guest" link shown outside the card.
class _GuestButton extends StatelessWidget {
  const _GuestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        AppLocalizations.of(context).continueAsGuest,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
