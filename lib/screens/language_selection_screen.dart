import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../services/onboarding_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/page_background.dart';
import '../widgets/theme_mode_toggle.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// A selectable language option.
class _LanguageOption {
  const _LanguageOption({
    required this.label,
    required this.hint,
    required this.code,
  });

  /// English name shown as the main label (e.g. "Kurdish").
  final String label;

  /// The language's own name, shown as the hint (e.g. "کوردی").
  final String hint;

  /// Locale code carried into the app ('en' | 'ku' | 'ar').
  final String code;
}

/// Phase 1, screen 2 — Language selection.
///
/// Light-mode only (per the handed-over `DESIGN light.md`). A blurred forest
/// photo sits behind a light-mint→green gradient, with the app's globe icon,
/// a title/subtitle, and three "liquid glass" language buttons.
///
/// Selecting a language switches the whole app to it, then continues to the
/// onboarding intro on a first install, or straight to Login once onboarding
/// has already been completed.
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  static const List<_LanguageOption> _options = [
    _LanguageOption(label: 'English', hint: 'English', code: 'en'),
    _LanguageOption(label: 'Kurdish', hint: 'کوردی', code: 'ku'),
    _LanguageOption(label: 'Arabic', hint: 'العربية', code: 'ar'),
  ];

  int? _selectedIndex;

  Future<void> _selectLanguage(int index) async {
    final code = _options[index].code;
    setState(() => _selectedIndex = index);
    // Switch the whole app to the chosen language (and direction).
    appLocale.value = Locale(code);

    // The onboarding intro runs on first install only; after it has been
    // completed once, this goes straight to Login.
    final seenOnboarding = await OnboardingPreferences.hasSeenOnboarding();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => seenOnboarding
            ? LoginScreen(languageCode: code)
            : OnboardingScreen(languageCode: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds the screen whenever the shared light/dark value changes.
    return ValueListenableBuilder<bool>(
      valueListenable: appDarkMode,
      builder: (context, isDark, _) => _buildScreen(context, isDark),
    );
  }

  Widget _buildScreen(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    // Swapping the subtree's ThemeData flips every `colorScheme.*` lookup at
    // once instead of branching on colour in each widget.
    final theme = isDark
        ? AppTheme.darkForLocale(Localizations.localeOf(context))
        : AppTheme.lightForLocale(Localizations.localeOf(context));
    final colorScheme = theme.colorScheme;

    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Light mode's top edge is pale (dark status-bar icons); dark mode's
        // is deep emerald (light icons).
        value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: PageBackground(
            dark: isDark,
            imageAsset: 'assets/images/Language.webp',
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background photo — same asset and same blur in both modes.
                // Gradient wash at a flat 45% in both modes; only the two
                // gradient colours differ. Light: mint→green.
                // Dark: the "Moonlit" pair `#0C1F1F → #062C32`.
                // Content. Scrollable so it can't overflow on short screens —
                // it stays vertically centred whenever there is room, and
                // scrolls instead of overflowing when there isn't.
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 32,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Image.asset(
                                isDark
                                    ? 'assets/images/language_logo dark.png'
                                    : 'assets/images/language_logo light.png',
                                height: 84,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.public,
                                      size: 76,
                                      color: isDark
                                          ? AppColors.luminousMint
                                          : AppColors.actionNavy,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                l10n.chooseYourLanguage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 30,
                                  height: 1.1,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.selectLanguageToContinue,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  color: AppColors.secondaryText(context),
                                ),
                              ),
                              const SizedBox(height: 40),
                              for (var i = 0; i < _options.length; i++) ...[
                                _LanguageButton(
                                  option: _options[i],
                                  selected: _selectedIndex == i,
                                  dark: isDark,
                                  onTap: () => _selectLanguage(i),
                                ),
                                if (i != _options.length - 1)
                                  const SizedBox(height: 18),
                              ],
                              const SizedBox(height: 32),
                              // The app's single light/dark switch. Lives here
                              // rather than on Login so the choice is made
                              // before the rest of the flow starts; Login reads
                              // the same notifier.
                              Align(
                                child: ThemeModeToggle(
                                  isDark: isDark,
                                  onChanged: ThemePreference.setDarkMode,
                                ),
                              ),
                            ],
                          ),
                        ),
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

/// A single "liquid glass" language button: frosted blur, subtle top shine,
/// bold label with a hint underneath.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.option,
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  final _LanguageOption option;
  final bool selected;
  final VoidCallback onTap;

  /// "Moonlit" glass from `DESIGN dark.md`: `#0C1F1F → #062C32` at 45% with
  /// the 85/15 split (brighter top edge "catches moonlight"), 40px blur, and
  /// a 12%-white edge stroke.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppLiquidGlass(
      borderRadius: 28,
      dark: dark,
      selected: selected,
      quality: AppLiquidGlassQuality.standard,
      interactive: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamilyForCode(option.code),
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: AppColors.secondaryText(context),
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
