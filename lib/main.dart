import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'screens/splash_screen.dart';
import 'services/crash_reporter.dart';
import 'services/firebase_bootstrap.dart';
import 'services/settings_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compile the Liquid Glass shader once, before the first frame, so it is
  // already cached by the time the Language Selection screen (or any later
  // screen using LiquidGlassSurface) first paints. Fire-and-forget:
  // nothing here should block or repeat on rebuilds.
  OCLiquidGlassGroup.precacheShader().ignore();
  // Non-fatal: until the Firebase project config files are added, this
  // records the failure and the app still runs (backend features report a
  // real error instead of pretending to work). See FIREBASE_SETUP.md.
  await FirebaseBootstrap.ensureInitialized();
  // Installed after Firebase, because Crashlytics needs it, and before the
  // first frame so a crash during startup is still caught. Collection is off
  // in debug; every report is scrubbed by CrashReporter.redact first
  // (SECURITY.md 10, and 5.1 on what must never reach Crashlytics).
  await CrashReporter().initialize();
  await ThemePreference.restore();
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
            // Installed app-wide so no screen has to remember: Android's
            // stretch overscroll wraps scrolling content in an offscreen
            // ImageFilterLayer, and a real Liquid Glass surface inside it can
            // no longer sample the page background behind the scroll view —
            // it samples transparent black and renders as black bars. See
            // `AppScrollBehavior` for the full mechanism.
            scrollBehavior: const AppScrollBehavior(),
            // Font follows the authoritative locale mapping, while the
            // saved preference selects the matching light/dark theme.
            theme: AppTheme.lightForLocale(locale),
            darkTheme: AppTheme.darkForLocale(locale),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // Browser refreshes can retain an argument-dependent page such as
            // /hotel/rooms. It cannot be rebuilt without its Hotel and search
            // objects, so restart the web app from the real entry point.
            initialRoute: '/',
            // Real entry point: Splash → Language → Login (Login opens in the
            // language chosen on the Language screen).
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
