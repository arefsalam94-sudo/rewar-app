import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/login_screen.dart';
import '../theme/app_colors.dart';
import 'glass_panel.dart';
import 'primary_button.dart';

/// The shared "you need an account for this" state.
///
/// Extracted from My Bookings, which is where the pattern was first designed
/// (`my bookings.jpg`) — lock glyph, title, one explanatory line, and a single
/// Log In button. It now lives here so every feature that needs an auth uid
/// shows the *same* screen instead of each one inventing its own wording and
/// spacing.
///
/// The rule this encodes, from `SECURITY.md` 6.1f: there is no anonymous mirror
/// of signed-in data. A guest is told why the data is missing and given a route
/// to sign in — the feature is never faked locally and then "merged later".
///
/// Use [SignInRequired] when the guest reaches a whole screen, and
/// [SignInRequiredSheet] when they tap a control that never opens one (the
/// drawer avatar, for example).
class SignInRequired extends StatelessWidget {
  const SignInRequired({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.lock_outline_rounded,
  });

  /// Why sign-in is needed, in this feature's own words — e.g. "Sign in to see
  /// your bookings". Kept per-caller rather than one generic string, because a
  /// gate that names the thing you were reaching for is far less confusing.
  final String title;
  final String body;
  final IconData icon;

  /// The Login route, shared by both variants so the destination cannot drift.
  static Route<void> loginRoute() =>
      MaterialPageRoute<void>(builder: (_) => const LoginScreen());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Centred when there is room, scrollable when there isn't. Without this
    // the gate overflows by ~240dp on a 320dp phone at a 2x system font size —
    // the flaw the original in-screen version shipped with.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 52, color: AppColors.accent(context)),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      height: 28 / 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: AppColors.onPhotoSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 220,
                    child: PrimaryButton(
                      label: l10n.logIn,
                      onTap: () => Navigator.of(
                        context,
                      ).push(SignInRequired.loginRoute()),
                    ),
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

/// The same gate as a bottom sheet, for controls that have no screen of their
/// own to host it — the drawer's avatar tap is the case this was built for.
///
/// Show it with `showModalBottomSheet(backgroundColor: Colors.transparent)`,
/// matching the drawer's other sheets.
class SignInRequiredSheet extends StatelessWidget {
  const SignInRequiredSheet({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.lock_outline_rounded,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.accent(context)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: AppColors.secondaryText(context),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: l10n.logIn,
                // Closes the sheet first, so Login isn't pushed underneath it.
                // The navigator is captured before the pop, because this
                // context is deactivated the moment the sheet route leaves.
                onTap: () {
                  final navigator = Navigator.of(context, rootNavigator: true);
                  navigator.pop();
                  navigator.push(SignInRequired.loginRoute());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
