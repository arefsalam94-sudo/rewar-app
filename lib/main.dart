import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_bootstrap.dart';
import 'services/preview_identity.dart';
import 'services/settings_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Non-fatal: until the Firebase project config files are added, this
  // records the failure and the app still runs (backend features report a
  // real error instead of pretending to work). See FIREBASE_SETUP.md.
  await FirebaseBootstrap.ensureInitialized();
  await ThemePreference.restore();
  // Only consulted while Firebase is missing, so account surfaces can show the
  // name the user registered with instead of a hard-coded stand-in.
  await PreviewIdentity.load();
  final savedLanguage = await const SettingsPreferences().languageCode();
  appLocale.value = Locale(savedLanguage);
  runApp(const KurdistanParadiseApp());
}

class KurdistanParadiseApp extends StatelessWidget {
  const KurdistanParadiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the chosen language changes, switching the whole app's
    // language and text direction (LTR/RTL) live.
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: appDarkMode,
          builder: (context, isDark, _) => MaterialApp(
            title: 'Kurdistan Paradise Travel Guide',
            debugShowCheckedModeBanner: false,
            // Font follows the authoritative locale mapping, while the
            // saved preference selects the matching light/dark theme.
            theme: AppTheme.lightForLocale(locale),
            darkTheme: AppTheme.darkForLocale(locale),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // Real entry point: Splash → Language → Login (Login opens in the
            // language chosen on the Language screen).
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
