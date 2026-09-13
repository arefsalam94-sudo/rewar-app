import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';

/// Phase 1 — Register Complete (all 3 languages, light + dark).
///
/// The last step of registration, reached from Account Setup. Confirms the
/// account, shows the picture and name just chosen, and hands off to the app.
///
/// Deliberately has **no back button**, and the OS/gesture back is blocked
/// too: registration is finished, and returning to Account Setup or the
/// consumed verification step would leave the user somewhere meaningless.
class RegisterCompleteScreen extends StatelessWidget {
  const RegisterCompleteScreen({
    super.key,
    required this.displayName,
    this.imageFile,
    this.imageUrl,
    this.onExplore,
  });

  /// The name saved on Account Setup, shown under the avatar.
  final String displayName;

  /// The picture as picked on this device. Preferred over [imageUrl] because
  /// it is already local — no network round-trip on the final screen.
  final File? imageFile;

  /// The uploaded Storage URL, used when the local file isn't to hand.
  final String? imageUrl;

  /// Overrides the default dashboard navigation. Used by tests.
  final VoidCallback? onExplore;

  void _onExplore(BuildContext context) {
    final callback = onExplore;
    if (callback != null) {
      callback();
      return;
    }
    // Registration and profile persistence are complete before this screen
    // is shown. Clear the entire auth flow so Back cannot return to any
    // consumed registration, verification, or account-setup step.
    Navigator.of(context).pushAndRemoveUntil(
      HomeScreen.route(isGuest: false, displayName: displayName),
      (route) => false,
    );
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
      // Registration is done — swallow the hardware/gesture back so the user
      // can't walk back into a finished flow.
      child: PopScope(
        canPop: false,
        child: Scaffold(
          body: PageBackground(
            dark: isDark,
            imageAsset: 'assets/images/account Image.webp',
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // No back button by design, so the title sits
                          // higher than on the other auth screens.
                          const SizedBox(height: 40),
                          Text(
                            l10n.registerComplete,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 38,
                              height: 1.05,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.registerCompleteSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.35,
                              color: AppColors.secondaryText(context),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Center(
                            child: _Avatar(
                              imageFile: imageFile,
                              imageUrl: imageUrl,
                              dark: isDark,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w400,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 40),
                          PrimaryButton(
                            label: l10n.explore,
                            dark: isDark,
                            onTap: () => _onExplore(context),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular profile picture, or the person icon when none was chosen.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageFile,
    required this.imageUrl,
    required this.dark,
  });

  final File? imageFile;
  final String? imageUrl;
  final bool dark;

  static const double _size = 230;

  @override
  Widget build(BuildContext context) {
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A brighter ring than the default, matching the mockup's crisp
        // edge. DESIGN dark.md: white strokes sit at 10-15% opacity — "a
        // solid, fully opaque white border is wrong". Light mode keeps the
        // crisp ring the mockup shows.
        border: Border.all(
          color: Colors.white.withValues(
            alpha: dark ? AppColors.darkBorderOpacity : 0.90,
          ),
          width: 2,
        ),
      ),
      child: AppLiquidGlass(
        useCanonicalGlass: true,
        layer: GlassLayer.surface,
        borderRadius: _size,
        dark: dark,
        child: SizedBox(
          width: _size,
          height: _size,
          child: ClipOval(child: _picture(accent)),
        ),
      ),
    );
  }

  Widget _picture(Color accent) {
    final file = imageFile;
    if (file != null) {
      return Image.file(file, fit: BoxFit.cover);
    }
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        // A broken URL must not leave a grey box on the celebratory screen.
        errorBuilder: (context, error, stackTrace) => _placeholder(accent),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(accent),
      );
    }
    return _placeholder(accent);
  }

  Widget _placeholder(Color accent) =>
      Center(child: Icon(Icons.person_outline, size: 104, color: accent));
}
