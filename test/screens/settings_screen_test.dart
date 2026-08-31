import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/login_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/account_edit_screens.dart';
import 'package:kurdistan_paradise_travel_guide/screens/settings_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/auth_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/settings_preferences.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/theme/theme_controller.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/theme_mode_toggle.dart';

void main() {
  const profile = UserProfile(
    name: 'Sara Ahmad',
    email: 'Saraahmad@gmail.com',
    phone: '+964 750 777 7777',
    profileImageUrl: null,
    currency: AppCurrency.usd,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appDarkMode.value = false;
  });
  tearDown(() => appDarkMode.value = false);

  group('SettingsScreen — layout', () {
    testWidgets('draws the profile and all requested settings rows', (
      tester,
    ) async {
      await _pump(tester, profile: profile);

      for (final text in const [
        'Settings',
        'Sara Ahmad',
        '+964 750 777 7777',
        'Account',
        'Email',
        'Saraahmad@gmail.com',
        'Phone number',
        'Change password',
        'Preferences',
        'Notifications',
        'Theme',
        'Language',
        'English',
        'Currency',
        'USD',
        'Units',
        'Km',
        'Security & legal',
        'Security & privacy',
        'Delete account',
        'Log Out',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }

      // Shared back button + profile card + three grouped cards.
      expect(find.byType(GlassPanel), findsNWidgets(6));
      expect(find.byType(ThemeModeToggle), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('uses the shared blurred local photo and '
        'sheen cards', (tester) async {
      await _pump(tester, profile: profile);

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(
        (image.image as AssetImage).assetName,
        SettingsScreen.backgroundAsset,
      );
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.byType(GlassPanel), findsWidgets);
    });

    testWidgets('dark mode still blurs the photo, as the design file '
        'requires', (tester) async {
      // `DESIGN dark.md` → Background Imagery Treatment is not optional: the
      // photo reads as defocused light, not a legible scene. Removing the
      // light-mode blur must not have removed this one too.
      await _pump(tester, profile: profile, dark: true);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('account rows open their dedicated editor pages', (
      tester,
    ) async {
      await _pump(tester, profile: profile);

      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangeEmailScreen), findsOneWidget);
    });

    testWidgets('survives a narrow phone with 2x text', (tester) async {
      await _pump(
        tester,
        profile: profile,
        size: const Size(320, 1800),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsScreen — preferences', () {
    testWidgets('language, currency and units expand choices inline', (
      tester,
    ) async {
      await _pump(tester, profile: profile);

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.text('Kurdish'), findsOneWidget);
      expect(find.text('EUR'), findsNothing);

      await tester.tap(find.text('Currency'));
      await tester.pumpAndSettle();
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('Kurdish'), findsNothing);

      await tester.tap(find.text('Units'));
      await tester.pumpAndSettle();
      expect(find.text('Miles (mi)'), findsOneWidget);
      expect(find.text('EUR'), findsNothing);

      // The choices are part of the Settings route, not a modal overlay.
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(ModalBarrier), findsNothing);
    });
    testWidgets('notification switch requests permission and persists', (
      tester,
    ) async {
      final preferences = _FakeSettingsPreferences(enabled: false);
      var permissionCalls = 0;
      await _pump(
        tester,
        profile: profile,
        preferences: preferences,
        requestPermission: () async {
          permissionCalls++;
          return true;
        },
      );

      final switchFinder = find.byKey(
        const ValueKey('settings-notifications-switch'),
      );
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(permissionCalls, 1);
      expect(preferences.enabled, isTrue);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(permissionCalls, 1); // Permission is needed only when enabling.
      expect(preferences.enabled, isFalse);
    });

    testWidgets('notification switch stays off when permission is denied', (
      tester,
    ) async {
      final preferences = _FakeSettingsPreferences(enabled: false);
      await _pump(
        tester,
        profile: profile,
        preferences: preferences,
        requestPermission: () async => false,
      );

      final switchFinder = find.byKey(
        const ValueKey('settings-notifications-switch'),
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(preferences.enabled, isFalse);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(
        find.text('Notification permission was not granted.'),
        findsOneWidget,
      );
    });

    testWidgets('theme toggle changes the app-wide mode', (tester) async {
      await _pump(tester, profile: profile);

      await tester.tap(find.byType(ThemeModeToggle));
      await tester.pumpAndSettle();
      expect(appDarkMode.value, isTrue);
    });
  });

  group('SettingsScreen — navigation and languages', () {
    testWidgets('logout signs out and clears the stack to Login', (
      tester,
    ) async {
      final auth = _FakeAuthService();
      await _pump(tester, profile: profile, authService: auth);

      await tester.ensureVisible(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(auth.signedOut, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('the back button pops the route', (tester) async {
      await _pump(tester, profile: profile, withHost: true);

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('Kurdish and Arabic render localized RTL settings', (
      tester,
    ) async {
      for (final locale in const [Locale('ku'), Locale('ar')]) {
        await _pump(tester, profile: profile, locale: locale);
        final l10n = AppLocalizations(locale);
        expect(find.text(l10n.settingsAccount), findsOneWidget);
        expect(find.text(l10n.settingsPreferences), findsOneWidget);
        expect(find.text(l10n.settingsDeleteAccount), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(SettingsScreen))),
          TextDirection.rtl,
        );
      }
    });
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required UserProfile profile,
  Locale locale = const Locale('en'),
  Size size = const Size(430, 1900),
  double textScale = 1,
  SettingsPreferences? preferences,
  Future<bool> Function()? requestPermission,
  AuthService? authService,
  bool withHost = false,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final screen = SettingsScreen(
    userProfileService: _FakeUserProfileService(profile),
    authService: authService ?? _FakeAuthService(),
    preferences: preferences ?? _FakeSettingsPreferences(enabled: true),
    requestNotificationPermission: requestPermission ?? () async => true,
  );

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: withHost ? _PushHost(screen: screen) : screen,
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeUserProfileService extends UserProfileService {
  _FakeUserProfileService(this.profile);

  final UserProfile profile;

  @override
  Future<UserProfile?> fetchProfile() async => profile;
}

class _FakeSettingsPreferences extends SettingsPreferences {
  _FakeSettingsPreferences({required this.enabled});

  bool enabled;

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<void> setNotificationsEnabled(bool value) async => enabled = value;
}

class _FakeAuthService extends AuthService {
  bool signedOut = false;

  @override
  Future<void> signOut() async => signedOut = true;
}

class _PushHost extends StatefulWidget {
  const _PushHost({required this.screen});

  final Widget screen;

  @override
  State<_PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<_PushHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => widget.screen));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
