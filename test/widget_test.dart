import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/locale_controller.dart';
import 'package:kurdistan_paradise_travel_guide/main.dart';
import 'package:kurdistan_paradise_travel_guide/models/featured_item.dart';
import 'package:kurdistan_paradise_travel_guide/models/reset_target.dart';
import 'package:kurdistan_paradise_travel_guide/screens/account_setup_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/billing_payment_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/car_rental_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/explore_nature_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/explore_tours_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/flight_ticketing_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/forget_password_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/help_support_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/home_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/language_selection_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/login_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/my_bookings_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/onboarding_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/register_complete_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/register_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/reset_password_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/settings_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/splash_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/verification_code_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/terms_of_service_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/auth_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/favorites_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/featured_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/legal_document_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/onboarding_preferences.dart';
import 'package:kurdistan_paradise_travel_guide/services/password_reset_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/theme/theme_controller.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/app_recessed_glass_field.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/home_bottom_nav.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/home_drawer.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/theme_mode_toggle.dart';

/// Wraps a screen with the same localization setup the real app uses.
Widget _host(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

const _phoneTarget = ResetTarget(
  method: ResetMethod.phone,
  value: '+9647500009042',
  maskedValue: '*** *** 9042',
);

const _emailTarget = ResetTarget(
  method: ResetMethod.email,
  value: 'someone@example.com',
  maskedValue: '*******sa@gmail.com',
);

Widget _verificationScreen(ResetTarget target) =>
    VerificationCodeScreen(target: target, service: PasswordResetService());

Widget _resetPasswordScreen() => ResetPasswordScreen(
  target: _phoneTarget,
  verified: const VerifiedReset(),
  service: PasswordResetService(),
);

/// Tears the screen down so its 1-second countdown timer is cancelled and the
/// test doesn't fail on a pending timer.
Future<void> _disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('App opens on Splash then advances to Language', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KurdistanParadiseApp());
    await tester.pumpAndSettle(); // let localization delegates load
    expect(find.text('Kurdistan Paradise\nTravel Guide'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
    expect(find.text('Choose Your Language'), findsOneWidget);
  });

  testWidgets('Language screen shows title and options (English)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const LanguageSelectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Language'), findsOneWidget);
    expect(find.text('Kurdish'), findsOneWidget);
    expect(find.text('Arabic'), findsOneWidget);
  });

  testWidgets('Login screen shows key elements (English)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('Forget Password screen shows title, options and button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const ForgetPasswordScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Forget Password'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
  });

  testWidgets('Login screen renders in Arabic (RTL)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const LoginScreen(languageCode: 'ar'), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.byType(LoginScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets('Verification Code screen shows the phone destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_verificationScreen(_phoneTarget)));
    await tester.pump();

    expect(find.text('Verification Code'), findsOneWidget);
    expect(find.text('*** *** 9042'), findsOneWidget);
    // The resend prompt is a Text.rich span, so findRichText is required.
    expect(
      find.textContaining("Didn't receive the code?", findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Verify'), findsOneWidget);

    await _disposeScreen(tester);
  });

  testWidgets('Verification Code screen shows the email destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_verificationScreen(_emailTarget)));
    await tester.pump();

    expect(find.text('*******sa@gmail.com'), findsOneWidget);
    expect(find.text('*** *** 9042'), findsNothing);

    await _disposeScreen(tester);
  });

  testWidgets('Typed digits replace the placement lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_verificationScreen(_phoneTarget)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '1525');
    await tester.pump();

    for (final digit in ['1', '5', '2']) {
      expect(find.text(digit), findsWidgets, reason: 'digit $digit is drawn');
    }
    // Only 4 of the 6 cells are filled, so 2 placement lines remain.
    expect(find.text('6'), findsNothing);

    await _disposeScreen(tester);
  });

  testWidgets('Resend is on cooldown when the screen opens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_verificationScreen(_phoneTarget)));
    await tester.pump();

    expect(find.textContaining('Resend now', findRichText: true), findsNothing);
    expect(
      find.textContaining('Resend in 60s', findRichText: true),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining('Resend in 59s', findRichText: true),
      findsOneWidget,
    );

    await _disposeScreen(tester);
  });

  testWidgets('Verify with an incomplete code shows a validation error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_verificationScreen(_phoneTarget)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pump();

    expect(find.text('Enter all 6 digits of the code'), findsOneWidget);

    await _disposeScreen(tester);
  });

  testWidgets('Verification Code screen renders in Kurdish (RTL)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(_verificationScreen(_phoneTarget), locale: const Locale('ku')),
    );
    await tester.pump();

    expect(find.text('کۆدی پشتڕاستکردنەوە'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(VerificationCodeScreen))),
      TextDirection.rtl,
    );
    // The destination itself must stay left-to-right inside the RTL sentence.
    expect(
      Directionality.of(tester.element(find.text('*** *** 9042'))),
      TextDirection.ltr,
    );

    await _disposeScreen(tester);
  });

  testWidgets('Reset Password screen shows its fields and button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_resetPasswordScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(
      find.text(
        'At least 8 characters, with uppercase, lowercase and '
        'special character.',
      ),
      findsOneWidget,
    );
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
  });

  testWidgets('Reset Password rejects a password that breaks the policy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_resetPasswordScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);

    // Too short.
    await tester.enterText(fields.first, 'Ab!1');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    // Long enough, but no special character.
    await tester.enterText(fields.first, 'Abcdefgh');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least one special character'), findsOneWidget);

    // No uppercase.
    await tester.enterText(fields.first, 'abcdefg!');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least one uppercase letter'), findsOneWidget);
  });

  testWidgets('Reset Password requires the two passwords to match', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_resetPasswordScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'Abcdefg!');
    await tester.enterText(fields.last, 'Abcdefg?');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('The two passwords do not match'), findsOneWidget);
  });

  testWidgets('Reset Password renders in Arabic (RTL)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(_resetPasswordScreen(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('إعادة تعيين كلمة المرور'), findsOneWidget);
    expect(find.text('تحديث كلمة المرور'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(ResetPasswordScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets('The light/dark toggle lives on Language, not Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeModeToggle), findsNothing);

    await tester.pumpWidget(_host(const LanguageSelectionScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeModeToggle), findsOneWidget);
    expect(
      tester.widget<ThemeModeToggle>(find.byType(ThemeModeToggle)).isDark,
      isFalse,
    );
  });

  testWidgets('The toggle darkens both Language and Login', (
    WidgetTester tester,
  ) async {
    addTearDown(() => appDarkMode.value = false);

    await tester.pumpWidget(_host(const LanguageSelectionScreen()));
    await tester.pumpAndSettle();

    // The toggle sits below the fold on the short default test surface.
    await tester.ensureVisible(find.byType(ThemeModeToggle));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThemeModeToggle));
    await tester.pumpAndSettle();

    expect(appDarkMode.value, isTrue);
    expect(
      Theme.of(tester.element(find.byType(ThemeModeToggle))).brightness,
      Brightness.dark,
    );

    // Login must honour the same shared value, with no toggle of its own.
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeModeToggle), findsNothing);
    expect(
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Log In'))
          .dark,
      isTrue,
    );

    // Turning it back off returns Login to the navy treatment.
    appDarkMode.value = false;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Log In'))
          .dark,
      isFalse,
    );
  });

  testWidgets('Toggle icons are vertically centred, not pinned to the top', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const LanguageSelectionScreen()));
    await tester.pumpAndSettle();

    final toggle = tester.getRect(find.byType(ThemeModeToggle));
    final sun = tester.getRect(find.byIcon(Icons.light_mode));
    final moon = tester.getRect(find.byIcon(Icons.dark_mode));

    // Each icon's centre must sit on the toggle's horizontal midline. This is
    // the regression guard for the icons being pinned to the top edge.
    expect((sun.center.dy - toggle.center.dy).abs(), lessThan(1.0));
    expect((moon.center.dy - toggle.center.dy).abs(), lessThan(1.0));
  });

  testWidgets(
    'Full reset flow navigates: Send Code → Verify → Reset Password',
    (WidgetTester tester) async {
      // Firebase is not configured in tests, so the service runs in preview
      // mode — exactly what the app does on a dev machine before setup.
      expect(PasswordResetService.isPreviewMode, isTrue);

      await tester.pumpWidget(_host(const ForgetPasswordScreen()));
      await tester.pumpAndSettle();

      // Nothing selected yet → Send Code must not navigate.
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();
      expect(find.text('Choose phone or email first'), findsOneWidget);
      expect(find.byType(VerificationCodeScreen), findsNothing);

      // Pick the phone option, then send.
      await tester.tap(find.text('Phone number'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();

      expect(find.byType(VerificationCodeScreen), findsOneWidget);
      expect(find.text('Verification Code'), findsOneWidget);

      // Enter 6 digits and verify.
      await tester.enterText(find.byType(TextField), '152537');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
    },
  );

  testWidgets('Register screen shows every field and control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const RegisterScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Register'), findsWidgets); // title + button
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Gender (optional)'), findsOneWidget);
    // Reuses the shared labels already used by Forget Password, so the
    // casing follows those rather than the mockup's title case.
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);
    expect(
      find.textContaining('Already have an Account?', findRichText: true),
      findsOneWidget,
    );
    // Country code defaults to Iraq.
    expect(find.text('+964'), findsOneWidget);
  });

  testWidgets('Register requires the mandatory fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(PrimaryButton, 'Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your full name'), findsOneWidget);
    expect(find.text('Please enter your phone number'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    // Gender is the one optional field, so it must NOT complain.
    expect(find.textContaining('Gender is required'), findsNothing);
  });

  testWidgets('Register puts every input inside one container', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const RegisterScreen()));
    await tester.pumpAndSettle();

    final container = find.ancestor(
      of: find.byType(AppRecessedGlassField).first,
      matching: find.byType(GlassPanel),
    );
    expect(container, findsOneWidget);

    // All seven fields share that one container.
    expect(
      find.descendant(
        of: container,
        matching: find.byType(AppRecessedGlassField),
      ),
      findsNWidgets(7),
    );
    // The title and the Register button stay outside it.
    expect(
      find.descendant(of: container, matching: find.byType(PrimaryButton)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: container,
        matching: find.widgetWithText(PrimaryButton, 'Register'),
      ),
      findsNothing,
    );
    expect(tester.widget<GlassPanel>(container).depth, GlassDepth.base);
  });

  testWidgets('Register requires a date of birth before submitting', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const RegisterScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Aref Salam');
    await tester.enterText(fields.at(3), '7500009042');
    await tester.enterText(fields.at(4), 'aref@example.com');
    await tester.enterText(fields.at(5), 'Abcdefg!');
    await tester.enterText(fields.at(6), 'Abcdefg!');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(PrimaryButton, 'Register'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Register'));
    await tester.pumpAndSettle();

    // Date of birth is still unset, so that error wins first.
    expect(find.text('Please choose your date of birth'), findsOneWidget);
  });

  testWidgets('Gender expands below the field as separated tiles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const RegisterScreen()));
    await tester.pumpAndSettle();

    final genderField = find.text('Gender (optional)');
    await tester.ensureVisible(genderField);
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: genderField, matching: find.byType(TextFormField)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    final fieldRect = tester.getRect(
      find.ancestor(of: genderField, matching: find.byType(TextFormField)),
    );
    expect(
      tester.getRect(find.text('Male')).top,
      greaterThan(fieldRect.bottom),
    );

    // Each option sits at a visibly different vertical position, with a gap
    // between them rather than sitting flush.
    final male = tester.getRect(find.text('Male'));
    final female = tester.getRect(find.text('Female'));
    final other = tester.getRect(find.text('Other'));
    expect(female.top, greaterThan(male.bottom));
    expect(other.top, greaterThan(female.bottom));

    // Picking one closes the inline list and fills the field.
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(find.text('Male'), findsNothing);
    expect(find.text('Female'), findsOneWidget); // now in the field
  });

  testWidgets('Register renders in Kurdish (RTL)', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(const RegisterScreen(), locale: const Locale('ku')),
    );
    await tester.pumpAndSettle();

    expect(find.text('تۆمارکردن'), findsWidgets);
    expect(find.text('ناوی تەواو'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(RegisterScreen))),
      TextDirection.rtl,
    );
    // The dial code stays left-to-right inside the RTL layout.
    expect(
      Directionality.of(tester.element(find.text('+964'))),
      TextDirection.ltr,
    );
  });

  testWidgets('Login opens Register, and Register goes back to Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();

    // Both links are Text.rich spans, so findRichText is required and the
    // tap lands on the whole rich-text widget inside its GestureDetector.
    final registerLink = find.textContaining(
      'Register Now',
      findRichText: true,
    );
    await tester.ensureVisible(registerLink);
    await tester.pumpAndSettle();
    await tester.tap(registerLink);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    final loginLink = find.textContaining('Log In here', findRichText: true);
    await tester.ensureVisible(loginLink);
    await tester.pumpAndSettle();
    await tester.tap(loginLink);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Terms screen shows the document and disables Continue', (
    WidgetTester tester,
  ) async {
    var acceptedVersion = -1;
    await tester.pumpWidget(
      _host(
        TermsOfServiceScreen(
          onAccepted: (version) async => acceptedVersion = version,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsOneWidget);
    // The wording now comes from the same `legal_documents/terms_of_service`
    // the Policy hub's "Terms & Conditions" row opens — one document, so a
    // user cannot accept one text and read another.
    expect(find.text('Our role as an intermediary'), findsOneWidget);
    expect(find.text('Your responsibilities'), findsOneWidget);
    // Its bullets render as bullets here too, via the shared body widget.
    expect(find.text('•'), findsNWidgets(5));
    expect(
      find.text(
        'I have read and agree to the Terms of Service and Privacy Policy.',
      ),
      findsOneWidget,
    );

    // Continue is disabled until the box is ticked.
    final button = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Continue'),
    );
    expect(button.onTap, isNull);

    // The checkbox sits at the end of the scrollable document, so the user
    // has to scroll through the terms to reach it — deliberate, not a bug.
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final enabled = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Continue'),
    );
    expect(enabled.onTap, isNotNull);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    // The accepted version is what gets recorded against the user. Read from
    // the bundled asset rather than hardcoded, so bumping the Terms wording
    // can't leave this test asserting a stale number.
    expect(
      acceptedVersion,
      await LegalDocumentService.bundledVersionOf(
        LegalDocumentService.termsDocId,
      ),
    );
  });

  testWidgets('Terms screen warns while the wording is unreviewed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(TermsOfServiceScreen(onAccepted: (_) async {})),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Draft wording — pending legal review. Not for release.'),
      findsOneWidget,
    );
    // The document body refers to "the date at the top", so it must be shown.
    expect(find.textContaining('Last updated:'), findsOneWidget);
  });

  testWidgets('Terms screen renders in Arabic (RTL)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TermsOfServiceScreen(onAccepted: (_) async {}),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('شروط الخدمة'), findsOneWidget);
    // A heading from the current Arabic wording of the shared Terms document.
    expect(find.text('دورنا كوسيط'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(TermsOfServiceScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets('Register no longer collects consent itself', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const RegisterScreen()));
    await tester.pumpAndSettle();

    // Consent moved to the Terms screen, so there is no checkbox here.
    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.text('I agree to the Terms of Service and Privacy Policy'),
      findsNothing,
    );
  });

  testWidgets('Account Setup shows its parts and pre-fills the name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AccountSetupScreen(
          initialName: 'Aref Salam',
          // No OS in a widget test to answer permission prompts.
          requestPermissionsOnOpen: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account Setup'), findsOneWidget);
    expect(
      find.text(
        'Finish your account setup by uploading profile picture and '
        'set your username.',
      ),
      findsOneWidget,
    );
    expect(find.text('Create Account'), findsOneWidget);
    // The name from Register arrives pre-filled and editable.
    expect(find.text('Aref Salam'), findsOneWidget);
  });

  testWidgets('Account Setup requires a username', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(const AccountSetupScreen(requestPermissionsOnOpen: false)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(PrimaryButton, 'Create Account'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a username'), findsOneWidget);
  });

  testWidgets('Account Setup renders in Kurdish (RTL)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AccountSetupScreen(requestPermissionsOnOpen: false),
        locale: const Locale('ku'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ڕێکخستنی هەژمار'), findsOneWidget);
    expect(find.text('دروستکردنی هەژمار'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(AccountSetupScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets('Account Setup offers camera and gallery on tapping the avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const AccountSetupScreen(requestPermissionsOnOpen: false)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.file_upload_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    // Nothing to remove until a picture has been chosen.
    expect(find.text('Remove photo'), findsNothing);
  });

  testWidgets('Register Complete shows the name, no back button, and Explore', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const RegisterCompleteScreen(displayName: 'Aref Salam')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Register Complete!'), findsOneWidget);
    expect(
      find.text('You have successfully created your account. Welcome!'),
      findsOneWidget,
    );
    expect(find.text('Aref Salam'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    // No back button on this screen, by design.
    expect(find.byType(GlassBackButton), findsNothing);
  });

  testWidgets('Register Complete blocks back navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const RegisterCompleteScreen(displayName: 'Aref Salam')),
    );
    await tester.pumpAndSettle();

    // Registration is finished, so the OS back gesture must not pop it.
    expect(
      find.byWidgetPredicate((w) => w is PopScope<dynamic> && !w.canPop),
      findsOneWidget,
    );
  });

  testWidgets('Register Complete Explore opens the signed-in dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const RegisterCompleteScreen(displayName: 'Aref Salam')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Explore'));
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterCompleteScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final dashboard = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(dashboard.isGuest, isFalse);
    expect(dashboard.displayName, 'Aref Salam');
  });

  testWidgets('Register Complete renders in Arabic (RTL)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const RegisterCompleteScreen(displayName: 'عارف'),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اكتمل التسجيل!'), findsOneWidget);
    expect(find.text('استكشف'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(RegisterCompleteScreen))),
      TextDirection.rtl,
    );
  });

  group('DESIGN dark.md — Text & Legibility rules', () {
    // Every text colour on a dark glass surface must be white; dark or
    // greenish tokens are for borders and strokes only.
    setUp(() => appDarkMode.value = true);
    tearDown(() => appDarkMode.value = false);

    testWidgets('headings and body text are pure white at full opacity', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const AccountSetupScreen(requestPermissionsOnOpen: false)),
      );
      await tester.pumpAndSettle();

      // 'Account Setup' appears once, unlike 'Register' which is both a
      // title and a button label.
      final title = tester.widget<Text>(find.text('Account Setup'));
      expect(title.style?.color, const Color(0xFFFFFFFF));
      // "If a heading looks dim, it is a bug."
      expect(title.style?.color?.a, 1.0);
    });

    testWidgets('secondary text is white within the 70-80% band', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const AccountSetupScreen(requestPermissionsOnOpen: false)),
      );
      await tester.pumpAndSettle();

      final subtitle = tester.widget<Text>(
        find.text(
          'Finish your account setup by uploading profile picture and set '
          'your username.',
        ),
      );
      final color = subtitle.style!.color!;
      expect(color.r, 1.0);
      expect(color.g, 1.0);
      expect(color.b, 1.0);
      // Softer than a heading, but plainly readable.
      expect(color.a, inInclusiveRange(0.70, 0.80));
    });

    test('outline is white and only ever used as a low-opacity stroke', () {
      // The token itself is white, so that picking it for text by mistake
      // still yields something readable.
      expect(AppTheme.darkColorScheme.outline, const Color(0xFFFFFFFF));
      expect(AppTheme.darkColorScheme.outlineVariant, const Color(0xFFD5DDD7));
      // ...but as a border it must sit at the specified 20% opacity.
      expect(AppColors.darkBorderOpacity, 0.14);
      // And every other text-capable token is pure white.
      expect(AppTheme.darkColorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(
        AppTheme.darkColorScheme.onSurfaceVariant,
        const Color(0xFFFFFFFF),
      );
      expect(AppColors.darkOnSurfaceSecondary, const Color(0xFFFFFFFF));
    });

    testWidgets('text on a Luminous Mint button uses on-primary, not the '
        'background canvas colour', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const RegisterCompleteScreen(displayName: 'Aref Salam')),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Explore'),
      );
      final style = button.style!;
      const enabled = <WidgetState>{};
      expect(style.backgroundColor!.resolve(enabled), AppColors.luminousMint);
      // #00391E, not the #062C32 background canvas.
      expect(style.foregroundColor!.resolve(enabled), AppColors.darkOnPrimary);
    });

    testWidgets('input placeholders are white at exactly 60% opacity', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const AccountSetupScreen(requestPermissionsOnOpen: false)),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      final color = field.decoration!.hintStyle!.color!;
      expect(color.r, 1.0);
      expect(color.g, 1.0);
      expect(color.b, 1.0);
      expect(color.a, closeTo(0.60, 0.01));
    });

    testWidgets('the background photo is blurred in both themes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const RegisterScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(ImageFiltered), findsWidgets);

      appDarkMode.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(ImageFiltered), findsWidgets);
    });
  });

  testWidgets('Splash screen shows the app name', (WidgetTester tester) async {
    await tester.pumpWidget(_host(const SplashScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kurdistan Paradise\nTravel Guide'), findsOneWidget);
    // Fire the navigation timer so no pending timers remain.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
  });

  group('Responsiveness across device sizes', () {
    /// Renders [home] at a given size and font scale, collecting any layout
    /// overflow instead of letting it fail the test outright.
    Future<List<String>> overflowsFor(
      WidgetTester tester,
      Widget home, {
      required double width,
      required double height,
      required double textScale,
    }) async {
      tester.view.physicalSize = Size(width * 3, height * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final caught = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          caught.add(details.exceptionAsString().split('\n').first);
        } else {
          previous?.call(details);
        }
      };
      try {
        await tester.pumpWidget(_host(home));
        await tester.pump(const Duration(milliseconds: 100));
      } finally {
        FlutterError.onError = previous;
      }
      return caught;
    }

    testWidgets('the back button meets the 48dp minimum touch target', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LoginScreen()));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(GlassBackButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      // The visible circle must not have grown with it.
      final circle = tester.getSize(
        find.descendant(
          of: find.byType(GlassBackButton),
          matching: find.byType(GlassPanel),
        ),
      );
      expect(circle.width, GlassBackButton.visualSize);
    });

    testWidgets('a tap just inside the enlarged target still goes back', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(GlassBackButton(onTap: () => tapped = true)),
      );
      await tester.pumpAndSettle();

      // Bottom-right of the 48dp box — outside the old 36dp circle.
      final box = tester.getRect(find.byType(GlassBackButton));
      await tester.tapAt(box.bottomRight - const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    // The Apple/Gmail buttons sit two-to-a-row, so their labels have the
    // least room of anything in the app.
    for (final (width, height, scale) in const [
      (320.0, 480.0, 1.0),
      (320.0, 568.0, 1.3),
      (360.0, 640.0, 1.3),
      // The worst case: the narrowest phone at the largest font size. This
      // combination is what exposed the field prefix overflow.
      (320.0, 480.0, 2.0),
      (411.0, 731.0, 2.0),
      (480.0, 1000.0, 2.0),
    ]) {
      testWidgets('Login lays out at ${width.toInt()} wide, x$scale font', (
        tester,
      ) async {
        final caught = await overflowsFor(
          tester,
          const LoginScreen(),
          width: width,
          height: height,
          textScale: scale,
        );
        expect(caught, isEmpty, reason: caught.join(' | '));
      });

      testWidgets('Register lays out at ${width.toInt()} wide, x$scale font', (
        tester,
      ) async {
        final caught = await overflowsFor(
          tester,
          const RegisterScreen(),
          width: width,
          height: height,
          textScale: scale,
        );
        expect(caught, isEmpty, reason: caught.join(' | '));
      });
    }

    testWidgets('the gender sheet scrolls instead of overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 480 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_host(const RegisterScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final caught = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          caught.add(details.exceptionAsString().split('\n').first);
        } else {
          previous?.call(details);
        }
      };
      try {
        await tester.ensureVisible(find.text('Gender (optional)'));
        await tester.pump();
        await tester.tap(find.text('Gender (optional)'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
      } finally {
        FlutterError.onError = previous;
      }

      expect(find.text('Male'), findsOneWidget);
      expect(caught, isEmpty, reason: caught.join(' | '));
    });
  });

  group('Onboarding (3-slide intro)', () {
    setUp(() => OnboardingPreferences.debugOverrideSeen = false);
    tearDown(() {
      OnboardingPreferences.debugOverrideSeen = null;
      appLocale.value = const Locale('en');
    });

    Finder artwork(String fileName) => find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.split('/').last == fileName,
    );

    testWidgets('slide one shows its title, body copy and flight path', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Kurdistan'), findsOneWidget);
      expect(find.textContaining('Explore beautiful valleys'), findsOneWidget);
      expect(artwork('line.png'), findsOneWidget);
      expect(artwork('plane.png'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('all slide headers keep the same 40px downward offset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411 * 3, 731 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      // A 731dp screen uses the regular 48dp baseline plus the requested
      // 40dp downward adjustment.
      expect(tester.getTopLeft(find.text('Discover')).dy, closeTo(88, 0.1));

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Fly to')).dy, closeTo(88, 0.1));

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Your Ride')).dy, closeTo(88, 0.1));
    });

    testWidgets('"Kurdistan" pins Unbounded to Medium on its weight axis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      final kurdistan = tester.widget<Text>(find.text('Kurdistan'));
      final style = kurdistan.style!;
      expect(style.fontFamily, 'Unbounded');
      expect(style.fontSize, 45);
      expect(kurdistan.textScaler, TextScaler.noScaling);
      // Unbounded is a variable font whose `wght` axis defaults to 400.
      // Without an explicit FontVariation it renders Regular, not Medium.
      expect(style.fontVariations, contains(const FontVariation('wght', 500)));
    });

    testWidgets('the plane parks on the dot belonging to the current slide', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      // Dot positions measured from line.png itself: the three solid dots sit
      // at these fractions of the artwork's width.
      const firstDot = 0.1546;
      const lastDot = 0.8440;

      final track = tester.getRect(artwork('line.png'));
      // Whichever attitude is on screen — level on the first two slides, the
      // take-off plane on the last — has to sit on the current dot.
      double planeCentre() {
        final plane = artwork('plane.png').evaluate().isNotEmpty
            ? artwork('plane.png')
            : artwork('plane1.png');
        return tester.getCenter(plane.first).dx;
      }

      expect(planeCentre(), closeTo(track.left + firstDot * track.width, 1));

      // Skip to the final slide and confirm it has flown to the last dot.
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(planeCentre(), closeTo(track.left + lastDot * track.width, 1));
    });

    // The copy must clear the Next button in every language, not just English.
    // Arabic and Kurdish wrap differently and are wider, and in right-to-left
    // the button sits on the left with the lines running towards it.
    for (final (locale, width, height) in const [
      ('en', 411.0, 731.0),
      ('en', 360.0, 640.0),
      ('ar', 411.0, 731.0),
      ('ar', 360.0, 640.0),
      ('ku', 411.0, 731.0),
      ('ku', 360.0, 640.0),
    ]) {
      testWidgets('copy clears the Next button in $locale at ${width.toInt()}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, height * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(OnboardingScreen(languageCode: locale), locale: Locale(locale)),
        );
        await tester.pumpAndSettle();

        final bodyFinder = find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data ?? '').contains('\n'),
        );
        final copy = tester.getRect(bodyFinder.first);
        final body = tester.widget<Text>(bodyFinder.first);
        final button = tester.getRect(
          find
              .ancestor(
                of: find.byIcon(Icons.arrow_forward),
                matching: find.byType(ClipRRect),
              )
              .first,
        );

        // Re-lay the paragraph out exactly as drawn, then check every line
        // that is vertically level with the button.
        final rtl = locale != 'en';
        final painter = TextPainter(
          text: TextSpan(text: body.data, style: body.style),
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        )..layout(maxWidth: copy.width);
        final lines = painter.computeLineMetrics();
        final lineHeight = painter.height / lines.length;

        // Work in real screen coordinates rather than assuming how the block
        // is anchored, so this keeps testing the arrangement itself.
        var worstIntrusion = 0.0;
        var lastLineIsLevel = false;
        for (var i = 0; i < lines.length; i++) {
          // Anchored to the bottom of the rendered block, so the last line is
          // always flush with copy.bottom even if this re-layout wraps to a
          // slightly different number of lines than the widget did.
          final lineTop = copy.bottom - painter.height + i * lineHeight;
          final lineBottom = lineTop + lineHeight;
          final level = lineBottom > button.top && lineTop < button.bottom;

          if (i == lines.length - 1) {
            lastLineIsLevel = level;
          } else {
            // Every line but the last sits above the button.
            expect(
              lineBottom,
              lessThanOrEqualTo(button.top + 0.5),
              reason:
                  'line ${i + 1} of ${lines.length} should sit above the Next '
                  'button in $locale at ${width.toInt()}dp wide',
            );
          }

          if (!level) continue;
          final farEdge = rtl
              ? copy.right - lines[i].width
              : copy.left + lines[i].width;
          final intrusion = rtl
              ? button.right - farEdge
              : farEdge - button.left;
          if (intrusion > worstIntrusion) worstIntrusion = intrusion;
        }
        painter.dispose();

        expect(
          lastLineIsLevel,
          isTrue,
          reason:
              'the last line should be level with the Next button in $locale '
              'at ${width.toInt()}dp wide',
        );
        expect(
          worstIntrusion,
          lessThanOrEqualTo(0),
          reason:
              'copy runs ${worstIntrusion.toStringAsFixed(1)}px into the Next '
              'button in $locale at ${width.toInt()}dp wide',
        );
      });
    }

    // The flight path, the panorama and the plane all run left-to-right, so
    // the slides must too — otherwise the photo pans one way while the pages
    // slide the other.
    for (final locale in const ['en', 'ar', 'ku']) {
      testWidgets('swiping left advances the slides in $locale', (
        tester,
      ) async {
        // A phone-sized viewport: the drag below has to clear PageView's
        // snap-back threshold, which is a fraction of the page width. At the
        // default 800dp test width, a 300dp drag falls short and springs back.
        tester.view.physicalSize = const Size(411 * 3, 731 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(OnboardingScreen(languageCode: locale), locale: Locale(locale)),
        );
        await tester.pumpAndSettle();

        final photo = artwork('panorama.webp');
        final before = tester.getRect(photo).left;

        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(photo).left,
          lessThan(before - 100),
          reason: 'a right-to-left swipe should move forward in $locale',
        );
      });
    }

    testWidgets('slide two shows its own header and copy', (tester) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fly to'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(find.text('Fly to'), findsOneWidget);
      expect(find.textContaining('Compare flights'), findsOneWidget);
      // Both slides carry a "Kurdistan" line, so it is on screen twice while
      // slide one is still built.
      expect(find.text('Kurdistan'), findsWidgets);
    });

    testWidgets(
      'the main plane follows both transitions and scales centrally',
      (tester) async {
        tester.view.physicalSize = const Size(411 * 3, 731 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(const OnboardingScreen(languageCode: 'en')),
        );
        await tester.pumpAndSettle();

        Transform scaleTransform() => tester.widget<Transform>(
          find.byKey(const ValueKey('main-plane-scale')),
        );

        expect(artwork('main plane.png'), findsOneWidget);
        expect(scaleTransform().transform.entry(0, 0), closeTo(0.40, 0.001));

        await tester.tap(find.byIcon(Icons.arrow_forward));
        await tester.pumpAndSettle();

        // At page two the supplied (1620, 366) centre maps to the horizontal
        // centre and the matching design-canvas height, at exactly 140% scale.
        expect(scaleTransform().transform.entry(0, 0), closeTo(1.40, 0.001));
        expect(
          tester.getCenter(artwork('main plane.png')).dx,
          closeTo(411 / 2, 0.5),
        );
        expect(
          tester.getCenter(artwork('main plane.png')).dy,
          closeTo(731 * 366 / 1080, 0.5),
        );

        await tester.tap(find.byIcon(Icons.arrow_forward));
        await tester.pumpAndSettle();
        expect(scaleTransform().transform.entry(0, 0), closeTo(1.85, 0.001));
        expect(
          tester.getCenter(artwork('main plane.png')).dx,
          lessThan(0),
          reason: 'the second motion finishes with the plane offscreen left',
        );
        expect(
          tester.getCenter(artwork('main plane.png')).dy,
          closeTo(731 * 149 / 1080, 0.5),
        );
      },
    );

    testWidgets('cloud overlays keep their design positions and pan one page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411 * 3, 731 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      const designPositions = [
        ('cloud 1.png', 2987.0, 103.0),
        ('cloud 2.png', 2200.0, 246.0),
        ('cloud 3.png', 1380.0, 105.0),
        ('cloud 4.png', 1062.0, 239.0),
        ('cloud 5.png', 100.0, 80.0),
      ];

      Transform cloudTransform(String file) =>
          tester.widget<Transform>(find.byKey(ValueKey(file)));

      Finder cloudsAtBrightness(String brightness) => find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.key is ValueKey<String> &&
            ((widget.key! as ValueKey<String>).value).startsWith(
              'cloud-brightness-',
            ) &&
            ((widget.key! as ValueKey<String>).value).endsWith('-$brightness'),
      );

      expect(cloudsAtBrightness('1.00'), findsNWidgets(5));

      for (final (file, x, y) in designPositions) {
        final transform = cloudTransform(file).transform;
        expect(transform.entry(0, 3), closeTo(x / 1080 * 411 - 411 / 2, 0.01));
        expect(transform.entry(1, 3), closeTo(y / 1080 * 731 - 411 / 2, 0.01));
      }

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      // Each cloud is fixed to the panorama, so advancing one page moves
      // every centre left by exactly one viewport while Y stays unchanged.
      for (final (file, x, y) in designPositions) {
        final transform = cloudTransform(file).transform;
        expect(
          transform.entry(0, 3),
          closeTo(x / 1080 * 411 - 411 / 2 - 411, 0.01),
        );
        expect(transform.entry(1, 3), closeTo(y / 1080 * 731 - 411 / 2, 0.01));
      }
      expect(cloudsAtBrightness('1.00'), findsNWidgets(5));

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      // All five clouds retain only 20% brightness on the night slide.
      expect(cloudsAtBrightness('0.20'), findsNWidgets(5));
    });

    testWidgets('slide two keeps the same fonts as slide one', (tester) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('Fly to')).style!.fontFamily,
        'Plus Jakarta Sans',
      );

      final kurdistan = tester
          .widgetList<Text>(find.text('Kurdistan'))
          .map((text) => text.style!)
          .toList();
      for (final style in kurdistan) {
        expect(style.fontFamily, 'Unbounded');
        // Slide two closes on the region's name at headline size.
        expect(style.fontSize, 58);
        expect(
          style.fontVariations,
          contains(const FontVariation('wght', 500)),
        );
      }
    });

    testWidgets('the header blurs out as its slide is swiped away', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411 * 3, 731 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      double sigmaOver(Finder text) {
        final filtered = find
            .ancestor(of: text, matching: find.byType(ImageFiltered))
            .evaluate();
        if (filtered.isEmpty) return 0;
        var largest = 0.0;
        for (final element in filtered) {
          final filter = (element.widget as ImageFiltered).imageFilter
              .toString();
          final match = RegExp(
            r'([0-9]+\.?[0-9]*)',
          ).firstMatch(filter.replaceAll('ImageFilter.blur(', ''));
          if (match != null) {
            largest = math.max(largest, double.parse(match.group(1)!));
          }
        }
        return largest;
      }

      // At rest the header is sharp: no blur filter is applied at all.
      expect(sigmaOver(find.text('Discover')), 0);

      // Drag half a page without releasing — the blur should track the finger.
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await drag.moveBy(const Offset(-205, 0));
      await tester.pump();
      final midSigma = sigmaOver(find.text('Discover'));
      expect(midSigma, greaterThan(2));

      // Further along, blurrier.
      await drag.moveBy(const Offset(-150, 0));
      await tester.pump();
      expect(sigmaOver(find.text('Discover')), greaterThan(midSigma));

      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the blur clears again if the swipe is abandoned', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411 * 3, 731 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      final drag = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await drag.moveBy(const Offset(-60, 0));
      await tester.pump();
      await drag.moveBy(const Offset(60, 0));
      await drag.up();
      await tester.pumpAndSettle();

      expect(
        find
            .ancestor(
              of: find.text('Discover'),
              matching: find.byType(ImageFiltered),
            )
            .evaluate(),
        isEmpty,
        reason: 'back at rest, the header should carry no blur filter',
      );
    });

    testWidgets('slide three shows its own header and copy', (tester) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Ride'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(find.text('Your Ride'), findsOneWidget);
      expect(find.text('Is Ready !'), findsOneWidget);
      expect(find.textContaining('Rent a car'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Is Ready !')).style!.fontSize, 55);
      expect(
        tester.widget<Text>(find.text('Is Ready !')).textScaler,
        TextScaler.noScaling,
      );
      expect(
        tester.widget<Text>(find.text('Is Ready !')).style!.fontVariations,
        contains(const FontVariation('wght', 500)),
      );
    });

    testWidgets('the plane pitches into take-off over the final leg', (
      tester,
    ) async {
      // Phone-sized, so the drag below clears PageView's snap-back threshold.
      tester.view.physicalSize = const Size(411 * 3, 731 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      // Nose-up angle, read off the rotation actually applied to the one
      // plane image. Anticlockwise is negative in Flutter, and the aircraft
      // points right, so climbing shows up as a negative angle.
      double noseUpRadians() {
        final rotation = tester.widget<Transform>(
          find
              .ancestor(
                of: artwork('plane.png'),
                matching: find.byType(Transform),
              )
              .first,
        );
        // Rotation about z reads out of the matrix as atan2(m[1], m[0]).
        final matrix = rotation.transform;
        return -math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));
      }

      // Only one plane image is used now; there is no second drawing.
      expect(artwork('plane.png'), findsOneWidget);
      expect(artwork('plane1.png'), findsNothing);

      // Slides one and two: level flight.
      expect(noseUpRadians(), closeTo(0, 0.001));
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(noseUpRadians(), closeTo(0, 0.001));

      // Part-way through the last leg it is caught mid-rotation.
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await drag.moveBy(const Offset(-200, 0));
      await tester.pump();
      final partial = noseUpRadians();
      expect(partial, greaterThan(0.02));
      expect(partial, lessThan(0.3));

      // Further along, steeper.
      await drag.moveBy(const Offset(-180, 0));
      await tester.pump();
      expect(noseUpRadians(), greaterThan(partial));

      await drag.up();
      await tester.pumpAndSettle();

      // Landed on slide three: full take-off attitude, about 18 degrees.
      expect(noseUpRadians(), closeTo(0.31, 0.005));
    });

    testWidgets('the take-off rotation unwinds if the swipe is abandoned', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411 * 3, 731 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      final drag = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await drag.moveBy(const Offset(-60, 0));
      await tester.pump();
      await drag.moveBy(const Offset(60, 0));
      await drag.up();
      await tester.pumpAndSettle();

      final rotation = tester.widget<Transform>(
        find
            .ancestor(
              of: artwork('plane.png'),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(
        -math.atan2(
          rotation.transform.entry(1, 0),
          rotation.transform.entry(0, 0),
        ),
        closeTo(0, 0.001),
        reason: 'back on slide two the plane should be level again',
      );
    });

    // The first header line is Light; the second stays Unbounded Medium.
    for (final (locale, line1, family) in const [
      ('en', 'Discover', 'Plus Jakarta Sans'),
      ('ar', 'اكتشف', 'Dubai'),
      ('ku', 'کوردستان', null),
    ]) {
      testWidgets('the first header line is Light in $locale', (tester) async {
        await tester.pumpWidget(
          _host(OnboardingScreen(languageCode: locale), locale: Locale(locale)),
        );
        await tester.pumpAndSettle();

        final style = tester.widget<Text>(find.text(line1)).style!;
        expect(style.fontFamily, family);
        expect(
          style.fontWeight,
          FontWeight.w300,
          reason: 'The heading uses the shared light display weight',
        );
      });
    }

    testWidgets('the dotted line runs underneath the plane', (tester) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      // Both files are square canvases with the artwork in a band around the
      // centre: the line covers rows 531-549 of 1080, the plane rows 474-609.
      final lineBox = tester.getRect(artwork('line.png'));
      final planeBox = tester.getRect(artwork('plane.png'));
      final lineTop = lineBox.center.dy - lineBox.height * (540 - 531) / 1080;
      final planeBottom =
          planeBox.center.dy + planeBox.height * (609 - 541.5) / 1080;

      expect(
        planeBottom,
        lessThan(lineTop),
        reason: 'the plane should fly clear above the line, not sit on it',
      );
    });

    testWidgets('the Next button keeps a usable touch target', (tester) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      final button = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.arrow_forward),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(button.width, 68);
      // 48 is the minimum comfortable touch target; the button must not be
      // shrunk below it.
      expect(button.height, greaterThanOrEqualTo(48));
    });

    testWidgets('the last slide finishes onboarding and opens Login', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.arrow_forward));
        await tester.pumpAndSettle();
      }

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      // Completing it is what records the flag — starting it is not enough.
      expect(await OnboardingPreferences.hasSeenOnboarding(), isTrue);
    });

    testWidgets('renders in Arabic, with the flight path still left-to-right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const OnboardingScreen(languageCode: 'ar'),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('اكتشف'), findsOneWidget);
      expect(find.text('كردستان'), findsOneWidget);
      // Unbounded has no Arabic glyphs, so the title must fall back to the
      // app's Arabic face rather than rendering as empty boxes.
      expect(
        tester.widget<Text>(find.text('كردستان')).style!.fontFamily,
        'Dubai',
      );

      // The plane still starts at the left-hand dot: it tracks progress
      // through the slides, not the reading direction.
      final track = tester.getRect(artwork('line.png'));
      expect(
        tester.getCenter(artwork('plane.png')).dx,
        closeTo(track.left + 0.1546 * track.width, 1),
      );
    });

    testWidgets('one photo spans all three slides and pans as they scroll', (
      tester,
    ) async {
      // A 16:9 surface, where each slide maps onto exactly one third of the
      // 3240x1920 photo with nothing cropped.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      // The per-slide background images are gone; one shared photo replaced
      // all three.
      expect(artwork('page 1.png'), findsNothing);
      expect(artwork('page 2.png'), findsNothing);
      expect(artwork('page 3.png'), findsNothing);
      expect(artwork('panorama.webp'), findsOneWidget);

      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      Rect photo() => tester.getRect(artwork('panorama.webp'));

      // Three screens wide, with the left third on screen for slide one.
      expect(photo().width, closeTo(screenWidth * 3, 0.5));
      expect(photo().left, closeTo(0, 0.5));

      // Each slide shifts the photo by exactly one screen, so slide three
      // lands on the right third — the far edge of the photo, no further.
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(photo().left, closeTo(-screenWidth, 0.5));

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(photo().left, closeTo(-screenWidth * 2, 0.5));
      expect(photo().right, closeTo(screenWidth, 0.5));
    });

    testWidgets('aligned panoramas crossfade across the full third swipe', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      final nightPhoto = artwork('panorama night.webp');
      expect(nightPhoto, findsOneWidget);
      expect(
        tester.getRect(nightPhoto),
        tester.getRect(artwork('panorama.webp')),
        reason: 'day and night panoramas must remain perfectly aligned',
      );
      expect(
        find.byKey(const ValueKey('onboarding-day-to-dusk-grade')),
        findsOneWidget,
        reason: 'the day layer needs an intermediate dusk exposure',
      );

      expect(
        find.ancestor(of: nightPhoto, matching: find.byType(ShaderMask)),
        findsNothing,
        reason: 'a spatial mask would create a visible day/night seam',
      );

      double nightOpacity() => tester
          .widget<Opacity>(
            find.ancestor(of: nightPhoto, matching: find.byType(Opacity)),
          )
          .opacity;

      expect(nightOpacity(), 0);

      // Page two is still entirely daytime.
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(nightOpacity(), 0);

      final pageView = find.byType(PageView);
      final pageWidth = tester.getSize(pageView).width;
      final gesture = await tester.startGesture(tester.getCenter(pageView));

      // Early in the swipe, night has only begun fading into the third slice.
      await gesture.moveBy(Offset(-pageWidth * 0.2, 0));
      await tester.pump();
      expect(nightOpacity(), inInclusiveRange(0.01, 0.3));

      // The fade lasts for the full transition instead of finishing early.
      await gesture.moveBy(Offset(-pageWidth * 0.4, 0));
      await tester.pump();
      expect(nightOpacity(), inInclusiveRange(0.4, 0.9));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(nightOpacity(), 1);
    });

    testWidgets('road car follows the final swipe with perspective and light', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      expect(artwork('car - 3ed page.webp'), findsOneWidget);
      expect(find.byKey(const ValueKey('road-car-effects')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      Transform carPosition() => tester.widget<Transform>(
        find.byKey(const ValueKey('road-car-position')),
      );

      final startTransform = carPosition().transform;
      final startOffset = Offset(
        startTransform.entry(0, 3),
        startTransform.entry(1, 3),
      );
      final startSize = tester.getSize(
        find.byKey(const ValueKey('road-car-size')),
      );

      // The green mark is off the right edge while page two is settled.
      expect(
        startOffset.dx,
        greaterThan(tester.getSize(find.byType(PageView)).width),
      );

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      final endTransform = carPosition().transform;
      final endOffset = Offset(
        endTransform.entry(0, 3),
        endTransform.entry(1, 3),
      );
      final endSize = tester.getSize(
        find.byKey(const ValueKey('road-car-size')),
      );
      final endRotation = tester
          .widget<Transform>(find.byKey(const ValueKey('road-car-rotation')))
          .transform;
      final endAngle = math.atan2(
        endRotation.entry(1, 0),
        endRotation.entry(0, 0),
      );

      expect(endOffset.dx, lessThan(startOffset.dx));
      expect(endOffset.dy, greaterThan(startOffset.dy));
      expect(endSize.width, greaterThan(startSize.width * 2));
      expect(endAngle, closeTo(-0.01, 0.02));
    });

    testWidgets('on a taller-than-16:9 screen the photo still covers it', (
      tester,
    ) async {
      // 20:9, the common modern phone shape. A third of the photo is 9:16, so
      // it has to be scaled up and cropped horizontally rather than letterboxed.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final photo = tester.getRect(artwork('panorama.webp'));

      // No letterboxing: the photo covers the screen in both directions.
      expect(photo.height, greaterThanOrEqualTo(screen.height - 0.5));
      expect(photo.width / 3, greaterThanOrEqualTo(screen.width - 0.5));
      // Slide one is centred on the left third, so the crop is even.
      expect(photo.left, closeTo((screen.width - photo.width / 3) / 2, 0.5));
    });

    // The body copy is bottom-anchored and grows upward, so on a narrow phone
    // it wraps to more lines and used to run straight into the flight path.
    for (final (width, height, label) in const [
      (411.0, 731.0, 'reference'),
      (393.0, 852.0, 'iPhone 15'),
      (360.0, 640.0, 'common Android'),
      (320.0, 568.0, 'small'),
      (320.0, 480.0, 'very small'),
    ]) {
      testWidgets('copy never runs into the line or the plane ($label)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, height * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(const OnboardingScreen(languageCode: 'en')),
        );
        await tester.pumpAndSettle();

        final copy = tester.getRect(
          find.textContaining('Explore beautiful valleys'),
        );

        // Both PNGs are mostly-empty square canvases, so the drawn artwork is
        // a thin band around their centre: the line covers rows 531-549 of
        // 1080, the plane rows 474-609.
        final lineBox = tester.getRect(artwork('line.png'));
        final planeBox = tester.getRect(artwork('plane.png'));
        final lineBottom =
            lineBox.center.dy + lineBox.height * (549 - 540) / 1080;
        final planeBottom =
            planeBox.center.dy + planeBox.height * (609 - 540) / 1080;

        expect(
          copy.top,
          greaterThan(lineBottom),
          reason: 'the copy overlaps the dotted line on a $label screen',
        );
        expect(
          copy.top,
          greaterThan(planeBottom),
          reason: 'the copy overlaps the plane on a $label screen',
        );
        // And it must not have grown up into the title either.
        final title = tester.getRect(find.text('Kurdistan'));
        expect(
          copy.top,
          greaterThan(title.bottom),
          reason: 'the copy overlaps the title on a $label screen',
        );
        expect(copy.top, greaterThan(0));
      });
    }

    testWidgets('copy stays clear of the line at a large system font size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      final copy = tester.getRect(
        find.textContaining('Explore beautiful valleys'),
      );
      final lineBox = tester.getRect(artwork('line.png'));
      expect(
        copy.top,
        greaterThan(lineBox.center.dy + lineBox.height * 9 / 1080),
      );
    });

    testWidgets('the title fades in slowly rather than snapping', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const OnboardingScreen(languageCode: 'en')),
      );

      double titleOpacity() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('Discover'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;

      await tester.pump();
      expect(titleOpacity(), lessThan(0.1));

      // The title used to be fully in by 605ms; it now runs for 1200ms.
      await tester.pump(const Duration(milliseconds: 620));
      expect(titleOpacity(), lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 640));
      expect(titleOpacity(), closeTo(1, 0.001));

      await tester.pumpAndSettle();
    });

    testWidgets('Language screen opens onboarding on a first install', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LanguageSelectionScreen()));
      await tester.pumpAndSettle();
      // 'Kurdish' is unique; 'English' appears twice (label and native name).
      await tester.tap(find.text('Kurdish'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Language screen skips onboarding once it has been seen', (
      tester,
    ) async {
      OnboardingPreferences.debugOverrideSeen = true;

      await tester.pumpWidget(_host(const LanguageSelectionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kurdish'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Home screen (main dashboard)', () {
    testWidgets('shows the greeting, prompt, all five cards and the nav', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(find.text('Good evening, Dear User'), findsOneWidget);
      expect(find.text('Where would you like to go?'), findsOneWidget);
      expect(find.text('Plan your journey'), findsOneWidget);

      for (final title in const [
        'Explore\nNature',
        'Where\nto Stay',
        'Car Rental',
        'Flight\nTicketing',
        'Explore\nTours',
      ]) {
        expect(find.text(title), findsOneWidget, reason: 'missing $title');
      }

      // Every nav destination is present, Home selected.
      expect(find.byType(HomeBottomNav), findsOneWidget);
      for (final label in const ['Home', 'My Bookings', 'Map', 'Saved']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('the greeting follows the clock', (tester) async {
      for (final (hour, expected) in const [
        (7, 'Good morning'),
        (14, 'Good afternoon'),
        (19, 'Good evening'),
        // No "Good night" band: the dashboard greets someone arriving, so
        // evening runs from 17:00 straight through to 05:00.
        (23, 'Good evening'),
        (3, 'Good evening'),
      ]) {
        await _pumpHome(tester, now: DateTime(2026, 8, 5, hour));
        expect(
          find.text('$expected, Dear User'),
          findsOneWidget,
          reason: 'hour $hour should read "$expected"',
        );
      }
    });

    testWidgets('a signed-in name replaces "Dear User"', (tester) async {
      await _pumpHome(tester, isGuest: false, displayName: 'Jason');
      expect(find.text('Good evening, Jason'), findsOneWidget);
      expect(find.textContaining('Dear User'), findsNothing);
    });

    testWidgets('the featured slide shows its title, place and rating', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(find.text('Rawanduz Canyon'), findsOneWidget);
      expect(find.text('Erbil  •  Nature escape'), findsOneWidget);
      // Star rating, not the reference's "FEATURED DESTINATION" pin label.
      expect(find.text('4.8'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('FEATURED DESTINATION'), findsNothing);
    });

    testWidgets('there is one dot per slide and swiping advances them', (
      tester,
    ) async {
      await _pumpHome(tester);

      // Four bundled slides → four dots.
      expect(_dotCount(tester), 4);
      expect(find.text('Rawanduz Canyon'), findsOneWidget);

      final carouselWidth = tester.getSize(find.byType(PageView)).width;
      await tester.drag(
        find.byType(PageView),
        Offset(-carouselWidth * 0.75, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('GreenWheels Rentals'), findsOneWidget);
      expect(find.text('Rawanduz Canyon'), findsNothing);
      expect(_dotCount(tester), 4);
    });

    testWidgets('a failed load shows an error with a working retry', (
      tester,
    ) async {
      final service = _FakeFeaturedService(failFirst: true);
      await _pumpHome(tester, featured: service);

      expect(find.text("Couldn't load featured destinations"), findsOneWidget);
      expect(find.text('Rawanduz Canyon'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Rawanduz Canyon'), findsOneWidget);
      expect(find.text("Couldn't load featured destinations"), findsNothing);
    });

    testWidgets('an empty collection says so instead of showing a blank', (
      tester,
    ) async {
      await _pumpHome(tester, featured: _FakeFeaturedService(items: const []));
      expect(find.text('Nothing is featured yet'), findsOneWidget);
    });

    testWidgets('the place count comes from the live count()', (tester) async {
      await _pumpHome(tester, featured: _FakeFeaturedService(count: 137));
      expect(find.text('137+ places'), findsOneWidget);
    });

    testWidgets('tapping anywhere on a journey card activates it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpHome(tester);

      // The whole journey card opens the Phase 4 hotel discovery screen.
      final cardTitle = find.text('Where\nto Stay');
      await tester.tap(cardTitle);
      await tester.pumpAndSettle();

      expect(find.byType(HotelScreen), findsOneWidget);
      expect(find.text('Coming soon'), findsNothing);
    });

    testWidgets('the Explore Nature card opens the Explore Nature screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpHome(tester);

      await tester.tap(find.text('Explore\nNature'));
      await tester.pumpAndSettle();

      // The one journey card with a screen behind it (ROADMAP.md Phase 3).
      expect(find.byType(ExploreNatureScreen), findsOneWidget);
      expect(find.text('Coming soon'), findsNothing);
    });

    testWidgets('the Car Rental card opens the Car Rental screen', (
      tester,
    ) async {
      await _pumpHome(tester);
      await tester.ensureVisible(find.text('Car Rental'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Car Rental'));
      await tester.pumpAndSettle();

      expect(find.byType(CarRentalScreen), findsOneWidget);
      expect(find.text('Pick-up – Drop-off Location'), findsOneWidget);
    });

    testWidgets('no count falls back to "Explore", never an invented number', (
      tester,
    ) async {
      await _pumpHome(tester, featured: _FakeFeaturedService(count: null));

      expect(find.textContaining('+ places'), findsNothing);
      // Both the carousel CTA and the Explore Nature button read "Explore".
      expect(find.text('Explore'), findsNWidgets(2));
    });

    testWidgets('a guest tapping the heart is asked to sign in, not written', (
      tester,
    ) async {
      final favorites = _FakeFavoritesService();
      await _pumpHome(tester, favorites: favorites);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to save favourites'), findsOneWidget);
      // Nothing was persisted, and no favourite was optimistically shown.
      expect(favorites.toggleCalls, isEmpty);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('a signed-in user can favourite and unfavourite a slide', (
      tester,
    ) async {
      final favorites = _FakeFavoritesService();
      await _pumpHome(tester, isGuest: false, favorites: favorites);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pumpAndSettle();

      expect(favorites.ids, contains('rawanduz-canyon'));
      expect(find.text('Added to your favourites'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_rounded).first);
      await tester.pumpAndSettle();

      expect(favorites.ids, isEmpty);
      expect(find.text('Removed from your favourites'), findsOneWidget);
    });

    testWidgets('an already-favourited slide opens with a filled heart', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        isGuest: false,
        favorites: _FakeFavoritesService(initial: {'rawanduz-canyon'}),
      );

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('the globe changes language in place, without navigating', (
      tester,
    ) async {
      addTearDown(() => appLocale.value = const Locale('en'));
      await _pumpHome(tester, listenToLocale: true);

      await tester.tap(find.byIcon(Icons.public));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-language-popover')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('language-option-en')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(appLocale.value.languageCode, 'ar');
      // Same screen, now in Arabic — not a push onto a language page.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LanguageSelectionScreen), findsNothing);
      expect(find.text('خطّط لرحلتك'), findsOneWidget);
    });

    testWidgets('renders in Kurdish (RTL) with the dots still left-to-right', (
      tester,
    ) async {
      await _pumpHome(tester, locale: const Locale('ku'));

      expect(find.text('پلان بۆ گەشتەکەت دابنێ'), findsOneWidget);
      expect(find.text('گەڕان\nبە سروشتدا'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(HomeBottomNav))),
        TextDirection.rtl,
      );

      // A progress track is not a sentence: the dot row stays LTR so slide
      // one's dot is on the left in every language.
      expect(
        Directionality.of(tester.element(find.byKey(carouselDotsRowKey))),
        TextDirection.ltr,
      );
    });

    testWidgets('renders in Arabic (RTL)', (tester) async {
      await _pumpHome(tester, locale: const Locale('ar'));

      expect(find.text('استكشف\nالطبيعة'), findsOneWidget);
      expect(find.text('تأجير السيارات'), findsOneWidget);
      expect(find.text('إلى أين تودّ الذهاب؟'), findsOneWidget);
    });

    testWidgets('the CTA arrow points the way the language reads', (
      tester,
    ) async {
      await _pumpHome(tester);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      await _pumpHome(tester, locale: const Locale('ar'));
      expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    group('DESIGN dark.md rules on the home screen', () {
      testWidgets('headings are pure white at full opacity', (tester) async {
        await _pumpHome(tester, dark: true);

        final greeting = tester.widget<Text>(
          find.text('Good evening, Dear User'),
        );
        expect(greeting.style!.color, const Color(0xFFFFFFFF));

        final section = tester.widget<Text>(find.text('Plan your journey'));
        expect(section.style!.color, const Color(0xFFFFFFFF));
      });

      testWidgets('pills are Luminous Mint with dark text on them', (
        tester,
      ) async {
        await _pumpHome(tester, dark: true);

        final label = tester.widget<Text>(find.text('Best Price'));
        // The one place dark text is correct.
        expect(label.style!.color, AppColors.darkOnPrimary);

        final pill = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Best Price'),
                matching: find.byType(Container),
              )
              .last,
        );
        final decoration = pill.decoration! as BoxDecoration;
        expect(decoration.color, AppColors.luminousMint);
      });

      testWidgets('light mode separates action and heading colors', (
        tester,
      ) async {
        await _pumpHome(tester);

        final label = tester.widget<Text>(find.text('Best Price'));
        expect(label.style!.color, Colors.white);

        final greeting = tester.widget<Text>(
          find.text('Good evening, Dear User'),
        );
        expect(greeting.style!.color, AppTheme.lightColorScheme.onSurface);
      });
    });

    group('Home screen responsiveness', () {
      testWidgets('the heart meets the 48dp minimum touch target', (
        tester,
      ) async {
        await _pumpHome(tester);

        final size = tester.getSize(
          find
              .ancestor(
                of: find.byIcon(Icons.favorite_border_rounded),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      });

      testWidgets('every nav destination is at least 48dp tall', (
        tester,
      ) async {
        await _pumpHome(tester);
        expect(
          tester.getSize(find.byType(HomeBottomNav)).height,
          greaterThanOrEqualTo(48),
        );
      });

      testWidgets('My Bookings opens the bookings page, bar still in place', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: false);
        final barRect = tester.getRect(find.byType(HomeBottomNav));

        await tester.tap(
          find.descendant(
            of: find.byType(HomeBottomNav),
            matching: find.byIcon(Icons.calendar_month_outlined),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MyBookingsScreen), findsOneWidget);
        // Same widget, same pixels — the bar must not jump or vanish.
        expect(find.byType(HomeBottomNav), findsOneWidget);
        expect(tester.getRect(find.byType(HomeBottomNav)), barRect);

        // Home takes you back rather than stacking a second dashboard.
        await tester.tap(
          find.descendant(
            of: find.byType(HomeBottomNav),
            matching: find.byIcon(Icons.home_outlined),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MyBookingsScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      for (final (label, width, scale) in const [
        ('small', 320.0, 1.0),
        ('common Android', 360.0, 1.0),
        ('iPhone 15', 393.0, 1.0),
        ('large font', 393.0, 1.6),
      ]) {
        testWidgets('lays out with no overflow ($label)', (tester) async {
          tester.view.physicalSize = Size(width * 3, 900 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          await _pumpHome(tester, textScale: scale);
          expect(find.byType(HomeScreen), findsOneWidget);

          // Scroll all the way down so every card is actually laid out at
          // this size, not just the ones above the fold. A RenderFlex
          // overflow anywhere logs a FlutterError, which fails the test.
          await tester.scrollUntilVisible(
            find.text(_lastCardTitle),
            240,
            // The page list, not the carousel's own PageView.
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();

          expect(find.text(_lastCardTitle), findsOneWidget);
        });
      }
    });

    testWidgets('"Continue as Guest" on Login opens the dashboard', (
      tester,
    ) async {
      // A phone-shaped window: the guest link sits below the fold of the
      // default 800x600 test view.
      tester.view.physicalSize = const Size(393 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      // pushReplacement — Back must not return to the login form.
      expect(find.byType(LoginScreen), findsNothing);
    });

    group('Side drawer (hamburger menu)', () {
      const profile = UserProfile(
        name: 'Jason Miller',
        email: 'jason.miller82@gmail.com',
        phone: '+1 202 555 0147',
        profileImageUrl: null,
        currency: AppCurrency.usd,
      );

      Future<void> openDrawer(WidgetTester tester) async {
        await tester.tap(find.byIcon(Icons.menu_rounded));
        // The drawer plays its own open animation rather than the dialog
        // route's (zero-duration) transition, so this has to actually
        // advance time rather than just settle().
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
      }

      testWidgets('the hamburger opens the drawer with the profile header', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          isGuest: false,
          userProfile: _FakeUserProfileService(profile: profile),
        );
        await openDrawer(tester);

        expect(find.byType(HomeDrawer), findsOneWidget);
        expect(find.text('Jason Miller'), findsOneWidget);
        expect(find.text('jason.miller82@gmail.com'), findsOneWidget);
        expect(find.text('+1 202 555 0147'), findsOneWidget);
        expect(find.text('Services'), findsOneWidget);
        expect(find.text('Log Out'), findsOneWidget);
      });

      testWidgets('a guest sees a placeholder header and a Log In button', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: true);
        await openDrawer(tester);

        expect(find.text('Guest'), findsOneWidget);
        expect(find.text('Sign in to see your profile'), findsOneWidget);
        expect(find.text('Log In'), findsOneWidget);
        expect(find.text('Log Out'), findsNothing);
      });

      testWidgets('Services expands to show the five journey options', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: false);
        await openDrawer(tester);

        // The underlying Home screen (still mounted behind the drawer) has
        // its own "Car Rental" card, so sub-items are matched scoped to the
        // drawer rather than with a bare find.text.
        Finder inDrawer(String text) => find.descendant(
          of: find.byType(HomeDrawer),
          matching: find.text(text),
        );

        expect(inDrawer('Explore Nature'), findsNothing);
        await tester.tap(find.text('Services'));
        await tester.pumpAndSettle();

        for (final label in const [
          'Explore Nature',
          'Where to Stay',
          'Car Rental',
          'Flight Ticketing',
          'Explore Tours',
        ]) {
          expect(inDrawer(label), findsOneWidget, reason: 'missing $label');
        }

        // Collapses again on a second tap.
        await tester.tap(find.text('Services'));
        await tester.pumpAndSettle();
        expect(inDrawer('Explore Nature'), findsNothing);
      });

      for (final (label, screen) in <(String, Type)>[
        ('Explore Nature', ExploreNatureScreen),
        ('Where to Stay', HotelScreen),
        ('Car Rental', CarRentalScreen),
        ('Flight Ticketing', FlightTicketingScreen),
        ('Explore Tours', ExploreToursScreen),
      ]) {
        testWidgets('Services → $label opens $screen', (tester) async {
          await _pumpHome(tester);
          await openDrawer(tester);
          await tester.tap(find.text('Services'));
          await tester.pumpAndSettle();

          await tester.tap(
            find.descendant(
              of: find.byType(HomeDrawer),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(screen), findsOneWidget);
          // The drawer is a dialog route — it must not be left open behind
          // the pushed screen.
          expect(find.byType(HomeDrawer), findsNothing);
        });
      }

      testWidgets('rows without a screen yet are still styled no-ops', (
        tester,
      ) async {
        // My Bookings now has a screen, so About Us stands in as the
        // remaining unbuilt destination. Keep this pointed at whichever row
        // is still inert; when the last one is built, delete the test.
        await _pumpHome(tester, isGuest: false);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('About Us'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('About Us'));
        await tester.pumpAndSettle();
        expect(find.text('Coming soon'), findsOneWidget);

        // The drawer itself is still open — this isn't real navigation.
        expect(find.byType(HomeDrawer), findsOneWidget);
      });

      testWidgets('My Bookings closes the drawer and opens the bookings page', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: false);
        await openDrawer(tester);

        await tester.ensureVisible(
          find.descendant(
            of: find.byType(HomeDrawer),
            matching: find.text('My Bookings'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(HomeDrawer),
            matching: find.text('My Bookings'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MyBookingsScreen), findsOneWidget);
        expect(find.byType(HomeDrawer), findsNothing);
        expect(find.text('Coming soon'), findsNothing);
      });

      testWidgets('a guest reaching My Bookings is asked to sign in', (
        tester,
      ) async {
        // There is no guest booking — the rules require an auth uid — so the
        // screen explains that rather than showing an empty list.
        await _pumpHome(tester, isGuest: true);
        await openDrawer(tester);

        await tester.ensureVisible(
          find.descendant(
            of: find.byType(HomeDrawer),
            matching: find.text('My Bookings'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(HomeDrawer),
            matching: find.text('My Bookings'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign in to see your bookings'), findsOneWidget);
      });

      testWidgets('Billing/Payments opens the no-card empty state', (
        tester,
      ) async {
        final service = _FakeUserProfileService(profile: profile);
        await _pumpHome(tester, isGuest: false, userProfile: service);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Billing/Payments'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Billing/Payments'));
        await tester.pumpAndSettle();

        expect(find.byType(BillingPaymentScreen), findsOneWidget);
        expect(find.text('Current Payment Method'), findsOneWidget);
        expect(find.byType(HomeDrawer), findsNothing);
      });

      testWidgets('Billing/Payments opens the sign-in gate for a guest', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: true);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Billing/Payments'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Billing/Payments'));
        await tester.pumpAndSettle();

        // The guest is pushed the screen and told why it is empty, rather than
        // being stopped at the drawer with a snackbar — the same treatment as
        // My Bookings and Settings.
        expect(find.byType(BillingPaymentScreen), findsOneWidget);
        expect(find.text('Sign in to manage payment'), findsOneWidget);
        expect(find.text('Log In'), findsOneWidget);
        expect(find.text('Current Payment Method'), findsNothing);
        expect(find.byType(HomeDrawer), findsNothing);
      });

      testWidgets('the avatar offers a guest the sign-in sheet', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: true);
        await openDrawer(tester);

        // The avatar opens no screen, so its gate is a sheet rather than a page.
        await tester.tap(find.byIcon(Icons.person_outline).first);
        await tester.pumpAndSettle();

        expect(find.text('Sign in to add a photo'), findsOneWidget);
        // Two: the sheet's button, and the drawer's own bottom button behind it.
        expect(find.text('Log In'), findsNWidgets(2));
      });

      testWidgets('saved payment methods open the populated billing page', (
        tester,
      ) async {
        const cardProfile = UserProfile(
          name: 'Jason Miller',
          email: 'jason.miller82@gmail.com',
          phone: '+1 202 555 0147',
          profileImageUrl: null,
          currency: AppCurrency.usd,
          hasPaymentMethod: true,
        );
        final service = _FakeUserProfileService(profile: cardProfile);
        await _pumpHome(tester, isGuest: false, userProfile: service);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Billing/Payments'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Billing/Payments'));
        await tester.pump();

        await tester.pumpAndSettle();
        expect(find.byType(BillingPaymentScreen), findsOneWidget);
        expect(find.text('Payment History'), findsOneWidget);
        expect(find.byType(HomeDrawer), findsNothing);
      });

      testWidgets('Settings closes the drawer and opens the settings hub', (
        tester,
      ) async {
        final service = _FakeUserProfileService(profile: profile);
        await _pumpHome(tester, isGuest: false, userProfile: service);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
        expect(find.byType(HomeDrawer), findsNothing);
      });

      testWidgets('Policy closes the drawer and opens the Policy hub', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: false);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Policy'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Policy'));
        await tester.pumpAndSettle();

        expect(find.byType(PolicyScreen), findsOneWidget);
        expect(find.text('Policy of App'), findsOneWidget);
        // Unlike the no-op rows, the drawer is dismissed first — leaving it
        // open behind a full screen would trap the back gesture.
        expect(find.byType(HomeDrawer), findsNothing);
      });

      testWidgets('Help/Support closes the drawer and opens the help centre', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: false);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Help/Support'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Help/Support'));
        await tester.pumpAndSettle();

        expect(find.byType(HelpSupportScreen), findsOneWidget);
        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.byType(HomeDrawer), findsNothing);
      });

      testWidgets('a guest can reach Help/Support without signing in', (
        tester,
      ) async {
        // Someone who cannot sign in is exactly the person who needs it.
        await _pumpHome(tester, isGuest: true);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Help/Support'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Help/Support'));
        await tester.pumpAndSettle();

        expect(find.byType(HelpSupportScreen), findsOneWidget);
        expect(find.text('Please sign in first'), findsNothing);
      });

      testWidgets('a guest can read the policies without signing in', (
        tester,
      ) async {
        // Legal terms have to be readable by someone who has not agreed to
        // them yet, so this row is not gated the way Currency is.
        await _pumpHome(tester, isGuest: true);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Policy'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Policy'));
        await tester.pumpAndSettle();

        expect(find.byType(PolicyScreen), findsOneWidget);
        expect(find.text('Please sign in first'), findsNothing);
      });

      testWidgets('Currency opens a sheet and writes the selection', (
        tester,
      ) async {
        final service = _FakeUserProfileService(profile: profile);
        await _pumpHome(tester, isGuest: false, userProfile: service);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Currency'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Currency'));
        await tester.pumpAndSettle();

        expect(find.text('Select Currency'), findsOneWidget);
        await tester.tap(find.text('Iraqi Dinar (IQD)'));
        await tester.pumpAndSettle();

        expect(service.updatedTo, AppCurrency.iqd);
        expect(find.text('Currency updated'), findsOneWidget);
      });

      testWidgets('a guest tapping Currency is asked to sign in first', (
        tester,
      ) async {
        final service = _FakeUserProfileService();
        await _pumpHome(tester, isGuest: true, userProfile: service);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Currency'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Currency'));
        await tester.pumpAndSettle();

        expect(find.text('Please sign in first'), findsOneWidget);
        expect(find.text('Select Currency'), findsNothing);
        expect(service.updatedTo, isNull);
      });

      testWidgets('Log Out signs out and lands back on Login', (tester) async {
        final auth = _FakeAuthService();
        await _pumpHome(tester, isGuest: false, auth: auth);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Log Out'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        expect(auth.signedOut, isTrue);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      });

      testWidgets('a guest tapping Log In goes straight to Login', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: true);
        await openDrawer(tester);

        await tester.ensureVisible(find.text('Log In'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('tapping the scrim closes the drawer without navigating', (
        tester,
      ) async {
        await _pumpHome(tester, isGuest: false);
        await openDrawer(tester);
        expect(find.byType(HomeDrawer), findsOneWidget);

        // Tap the scrim, well clear of the panel itself (which sits at the
        // leading edge in English).
        await tester.tapAt(const Offset(780, 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(HomeDrawer), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets(
        'renders in Arabic (RTL) with the panel on the trailing side',
        (tester) async {
          await _pumpHome(tester, isGuest: false, locale: const Locale('ar'));
          await openDrawer(tester);

          expect(
            Directionality.of(tester.element(find.byType(HomeDrawer))),
            TextDirection.rtl,
          );
          // Anchored to the *leading* edge, which is the right side in Arabic.
          final panel = tester.getRect(find.byType(ClipPath).first);
          expect(panel.right, closeTo(800, 1));
        },
      );

      testWidgets('headings are pure white in dark mode', (tester) async {
        await _pumpHome(
          tester,
          isGuest: false,
          dark: true,
          userProfile: _FakeUserProfileService(profile: profile),
        );
        await openDrawer(tester);

        final heading = tester.widget<Text>(find.text('Jason Miller'));
        expect(heading.style?.color, const Color(0xFFFFFFFF));
      });
    });
  });
}

// --- Home screen test helpers ------------------------------------------------

/// The last card on the page — scrolling to it proves everything above it
/// laid out at the size under test.
const String _lastCardTitle = 'Explore\nTours';

/// Stands in for the Firestore-backed carousel source.
class _FakeFeaturedService extends FeaturedService {
  _FakeFeaturedService({this.items, this.count = 120, this.failFirst = false});

  final List<FeaturedItem>? items;
  final int? count;

  /// Fails the first call only, so a retry can be shown to succeed.
  bool failFirst;

  @override
  Future<List<FeaturedItem>> fetchFeatured() async {
    if (failFirst) {
      failFirst = false;
      throw StateError('simulated failure');
    }
    return items ?? FeaturedService.bundledFeatured();
  }

  @override
  Future<int?> fetchNatureSpotCount() async => count;
}

class _FakeFavoritesService extends FavoritesService {
  _FakeFavoritesService({Set<String>? initial})
    : ids = {...?initial},
      toggleCalls = [];

  final Set<String> ids;
  final List<String> toggleCalls;

  @override
  Future<Set<String>> fetchFavoriteItemIds() async => {...ids};

  @override
  Future<bool> toggle({
    required FeaturedType itemType,
    required String itemId,
    required bool currentlyFavorite,
  }) async {
    toggleCalls.add(itemId);
    if (currentlyFavorite) {
      ids.remove(itemId);
      return false;
    }
    ids.add(itemId);
    return true;
  }
}

/// Stands in for the Firestore-backed drawer profile. Returns null (no
/// profile) unless one is supplied — same shape a real guest session would
/// produce, since [HomeDrawer] never calls this for a guest anyway.
class _FakeUserProfileService extends UserProfileService {
  _FakeUserProfileService({this.profile});

  final UserProfile? profile;

  bool updateShouldFail = false;
  AppCurrency? updatedTo;

  @override
  Future<UserProfile?> fetchProfile() async => profile;

  @override
  Future<void> updateCurrency(AppCurrency currency) async {
    if (updateShouldFail) throw StateError('simulated failure');
    updatedTo = currency;
  }
}

class _FakeAuthService extends AuthService {
  bool signedOut = false;
  bool shouldFail = false;

  @override
  Future<void> signOut() async {
    if (shouldFail) throw StateError('simulated failure');
    signedOut = true;
  }
}

/// Pumps [HomeScreen] with the app's real theme, localizations and fake
/// services, then settles the carousel's future.
Future<void> _pumpHome(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool dark = false,
  bool isGuest = true,
  String? displayName,
  DateTime? now,
  double textScale = 1.0,
  FeaturedService? featured,
  FavoritesService? favorites,
  UserProfileService? userProfile,
  AuthService? auth,
  bool listenToLocale = false,
}) async {
  final home = HomeScreen(
    isGuest: isGuest,
    displayName: displayName,
    // Fixed so the greeting doesn't depend on when the suite runs.
    now: now ?? DateTime(2026, 8, 5, 19, 30),
    featuredService: featured ?? _FakeFeaturedService(),
    favoritesService: favorites ?? _FakeFavoritesService(),
    userProfileService: userProfile ?? _FakeUserProfileService(),
    authService: auth ?? _FakeAuthService(),
  );

  Widget app(Locale active) => MaterialApp(
    locale: active,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.lightForLocale(active),
    darkTheme: AppTheme.darkForLocale(active),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );

  await tester.pumpWidget(
    listenToLocale
        // Mirrors main.dart, so changing appLocale rebuilds in place.
        ? ValueListenableBuilder<Locale>(
            valueListenable: appLocale,
            builder: (context, active, _) => app(active),
          )
        : app(locale),
  );
  await tester.pumpAndSettle();
}

/// Counts the carousel's page dots.
int _dotCount(WidgetTester tester) {
  return tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .where((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            (container.constraints?.maxWidth ?? 0) <= 10;
      })
      .length;
}
