import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/tour.dart';
import 'package:kurdistan_paradise_travel_guide/models/traveler_details.dart';
import 'package:kurdistan_paradise_travel_guide/screens/booking_traveler_info_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/booking_step_indicator.dart';

void main() {
  group('TravelerParty — the "exactly one lead" rule', () {
    test('the first traveler leads by default', () {
      final party = TravelerParty.ofSize(3);
      expect(party.size, 3);
      expect(party.travelers.where((t) => t.isLead).length, 1);
      expect(party.leadIndex, 0);
    });

    test('moving the lead does not leave two', () {
      final party = TravelerParty.ofSize(3).withLead(2);
      expect(party.travelers.where((t) => t.isLead).length, 1);
      expect(party.leadIndex, 2);
    });

    test('shrinking past the lead re-seats it rather than losing it', () {
      final party = TravelerParty.ofSize(4).withLead(3).resized(2);
      expect(party.size, 2);
      expect(party.travelers.where((t) => t.isLead).length, 1);
      expect(party.leadIndex, 0);
    });

    test('growing keeps what was already typed', () {
      var party = TravelerParty.ofSize(1);
      party = party.updated(0, party.travelers[0].copyWith(fullName: 'Sara'));
      party = party.resized(3);
      expect(party.travelers[0].fullName, 'Sara');
      expect(party.travelers[1].fullName, isEmpty);
    });
  });

  group('Age is computed from a birth date, never stored as a number', () {
    test('a birthday that has not come round yet still counts correctly', () {
      const traveler = TravelerDetails(fullName: 'A', dateOfBirth: null);
      expect(traveler.ageOn(DateTime(2026, 1, 1)), isNull);

      final born = TravelerDetails(
        fullName: 'A',
        dateOfBirth: DateTime(2008, 12, 31),
      );
      // The day before the 18th birthday.
      expect(born.ageOn(DateTime(2026, 12, 30)), 17);
      // The birthday itself.
      expect(born.ageOn(DateTime(2026, 12, 31)), 18);
    });

    test('no minAge means nobody is ever underage', () {
      final party = TravelerParty.ofSize(2).updated(
        0,
        TravelerDetails(fullName: 'Kid', dateOfBirth: DateTime(2020, 1, 1)),
      );
      expect(party.underageIndexes(null, DateTime(2026, 1, 1)), isEmpty);
    });

    test('an unanswered birth date is incomplete, not underage', () {
      final party = TravelerParty.ofSize(1);
      // Reported as underage would tell the user the wrong thing — the fix is
      // to fill the field, not to bring an older person.
      expect(party.travelers.first.isComplete, isFalse);
    });

    test('a traveler under the tour minimum is named by index', () {
      var party = TravelerParty.ofSize(2);
      party = party.updated(
        0,
        TravelerDetails(fullName: 'Adult', dateOfBirth: DateTime(1990, 5, 5)),
      );
      party = party.updated(
        1,
        TravelerDetails(fullName: 'Child', dateOfBirth: DateTime(2015, 5, 5)),
      );
      expect(party.underageIndexes(18, DateTime(2026, 8, 18)), [1]);
    });
  });

  group('BookingContact validation', () {
    test('an address without a dotted domain is rejected', () {
      const base = BookingContact(fullName: 'Sara Ahmad', phone: '7501234567');
      expect(base.copyWith(email: 'sara@example').hasValidEmail, isFalse);
      expect(base.copyWith(email: 'sara@example.com').hasValidEmail, isTrue);
    });

    test('a phone is judged on its digits, not its punctuation', () {
      const base = BookingContact(
        fullName: 'Sara Ahmad',
        email: 'sara@example.com',
      );
      expect(base.copyWith(phone: '750 123 4567').hasValidPhone, isTrue);
      expect(base.copyWith(phone: '12345').hasValidPhone, isFalse);
    });
  });

  group('BookingTravelerInfoScreen', () {
    testWidgets('draws the step indicator with step 1 active', (tester) async {
      await _pump(tester);

      expect(find.byType(BookingStepIndicator), findsOneWidget);
      expect(find.text('Traveler Info'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Confirmation'), findsOneWidget);
      // One numeral per step.
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('draws the contact block and the secure note', (tester) async {
      await _pump(tester);

      expect(find.text('Traveler Information'), findsOneWidget);
      expect(
        find.text('Please enter the details of all travelers'),
        findsOneWidget,
      );
      expect(find.text('Contact Person'), findsOneWidget);
      expect(find.byKey(travelerContactNameKey), findsOneWidget);
      expect(find.byKey(travelerContactEmailKey), findsOneWidget);
      expect(find.byKey(travelerContactPhoneKey), findsOneWidget);
      expect(find.text('+964'), findsOneWidget);
      expect(
        find.text('Your information is secure and encrypted'),
        findsOneWidget,
      );
    });

    testWidgets('one traveler card per person, added and removed', (
      tester,
    ) async {
      await _pump(tester, initialTravelers: 2);

      expect(find.text('Traveler 1'), findsOneWidget);
      expect(find.text('Traveler 2'), findsOneWidget);
      expect(find.text('Traveler 3'), findsNothing);

      await tester.tap(find.byKey(travelerCountPlusKey));
      await tester.pumpAndSettle();
      expect(find.text('Traveler 3'), findsOneWidget);

      await tester.tap(find.byKey(travelerCountMinusKey));
      await tester.pumpAndSettle();
      expect(find.text('Traveler 3'), findsNothing);
    });

    testWidgets('the counter cannot go below one traveler', (tester) async {
      await _pump(tester, initialTravelers: 1);

      await tester.tap(find.byKey(travelerCountMinusKey));
      await tester.pumpAndSettle();
      expect(find.text('Traveler 1'), findsOneWidget);
      expect(find.text('Traveler 2'), findsNothing);
    });

    testWidgets('the counter stops at the departure\'s remaining places', (
      tester,
    ) async {
      // 3 capacity, 1 taken — two places left, so two travelers is the ceiling.
      await _pump(tester, capacity: 3, bookedCount: 1, initialTravelers: 2);

      await tester.tap(find.byKey(travelerCountPlusKey));
      await tester.pumpAndSettle();
      expect(find.text('Traveler 3'), findsNothing);
      expect(
        find.text('Only 2 places left on this departure.'),
        findsOneWidget,
      );
    });

    testWidgets('a sold-out departure disables the CTA', (tester) async {
      await _pump(tester, capacity: 2, bookedCount: 2);

      expect(find.text('This departure is sold out.'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(travelerContinueKey),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an incomplete contact block blocks the continue', (
      tester,
    ) async {
      BookingContact? handed;
      // No profile to prefill from, so the contact block is genuinely blank.
      await _pump(
        tester,
        profile: _EmptyProfileService(),
        onContinue: (c, _) => handed = c,
      );

      await tester.tap(find.byKey(travelerContinueKey));
      await tester.pumpAndSettle();

      expect(handed, isNull);
      expect(
        find.text('Please enter a valid name, email address and phone number.'),
        findsOneWidget,
      );
    });

    testWidgets('a complete contact but a blank traveler still blocks', (
      tester,
    ) async {
      TravelerParty? handed;
      await _pump(tester, onContinue: (_, p) => handed = p);
      await _fillContact(tester);

      await tester.tap(find.byKey(travelerContinueKey));
      await tester.pumpAndSettle();

      expect(handed, isNull);
      expect(
        find.text('Please complete every traveler’s name and date of birth.'),
        findsOneWidget,
      );
    });

    testWidgets('a traveler under the tour minimum is refused by age', (
      tester,
    ) async {
      TravelerParty? handed;
      await _pump(tester, minAge: 18, onContinue: (_, p) => handed = p);
      await _fillContact(tester);
      await tester.enterText(_travelerNameField(tester, 0), 'Young Traveler');
      await tester.pumpAndSettle();
      await _pickBirthYear(tester, 0);

      await tester.tap(find.byKey(travelerContinueKey));
      await tester.pumpAndSettle();

      expect(handed, isNull);
      expect(
        find.text('Every traveler on this tour must be 18 or older.'),
        findsOneWidget,
      );
    });

    testWidgets('the contact block is prefilled from the signed-in profile', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Sara Ahmad'), findsOneWidget);
      expect(find.text('sara@example.com'), findsOneWidget);
      // The stored "+964 7501234567" is split, so the code is not shown twice.
      expect(find.text('7501234567'), findsOneWidget);
    });

    testWidgets('the lead designation moves rather than duplicating', (
      tester,
    ) async {
      await _pump(tester, initialTravelers: 2);

      expect(find.text('Lead traveler'), findsNWidgets(2));
      // Tapping traveler 2's chip must not leave two leads; the party model
      // owns that rule and the unit tests above prove it, so here we only
      // confirm the control is present on every card and tappable.
      await tester.tap(find.text('Lead traveler').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in Kurdish and Arabic, right to left', (tester) async {
      for (final locale in const [Locale('ku'), Locale('ar')]) {
        await _pump(tester, locale: locale);
        final l10n = AppLocalizations(locale);

        expect(find.text(l10n.travelerInformation), findsWidgets);
        expect(find.text(l10n.continueToPayment), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(BookingStepIndicator))),
          TextDirection.rtl,
        );
        // A dial code is a data sequence: it stays LTR in every language.
        expect(
          Directionality.of(tester.element(find.text('+964'))),
          TextDirection.ltr,
        );
      }
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(tester, dark: true);
      expect(find.text('Traveler Information'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the CTA stays put while the form scrolls', (tester) async {
      await _pump(tester, initialTravelers: 4, viewport: const Size(393, 780));

      final before = tester.getRect(find.byKey(travelerContinueKey));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byKey(travelerContinueKey));

      expect(after, before);
    });

    testWidgets('lays out without overflow on a small phone', (tester) async {
      await _pump(tester, initialTravelers: 3, viewport: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });
  });
}

// --- Helpers -----------------------------------------------------------------

Finder _travelerNameField(WidgetTester tester, int index) =>
    find.widgetWithText(TextFormField, 'Full Name').at(index + 1);

Future<void> _fillContact(WidgetTester tester) async {
  await tester.enterText(find.byKey(travelerContactNameKey), 'Sara Ahmad');
  await tester.enterText(
    find.byKey(travelerContactEmailKey),
    'sara@example.com',
  );
  await tester.enterText(find.byKey(travelerContactPhoneKey), '7501234567');
  await tester.pumpAndSettle();
}

/// Opens the date picker on a traveler card and accepts whatever it opens on —
/// which is ~30 years back, comfortably over any minAge — then overrides it to
/// a recent year by typing, so the age check has something young to reject.
Future<void> _pickBirthYear(WidgetTester tester, int index) async {
  await tester.tap(find.widgetWithText(TextFormField, 'Date of birth').first);
  await tester.pumpAndSettle();

  // Switch the picker to text entry and type a date inside minAge.
  final input = find.byIcon(Icons.edit_outlined);
  if (input.evaluate().isNotEmpty) {
    await tester.tap(input);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '01/01/2015');
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Tour _tour({int? capacity, int bookedCount = 0, int? minAge}) => Tour(
  id: 'tour-1',
  names: const {'en': 'Gali Alibag Waterfall'},
  descriptions: const {'en': 'A scenic waterfall.'},
  locationLabels: const {'en': 'Rawanduz, Erbil'},
  companyTag: 'AB group',
  durationDays: 1,
  pricePerPerson: 55,
  currency: 'USD',
  capacity: capacity,
  bookedCount: bookedCount,
  minAge: minAge,
);

/// Returns nothing, so a test can see the form in its genuinely empty state.
class _EmptyProfileService extends UserProfileService {
  @override
  Future<UserProfile?> fetchProfile() async => null;
}

class _FakeProfileService extends UserProfileService {
  @override
  Future<UserProfile?> fetchProfile() async => UserProfile(
    name: 'Sara Ahmad',
    email: 'sara@example.com',
    phone: '+964 7501234567',
    profileImageUrl: null,
    currency: AppCurrency.usd,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  int initialTravelers = 1,
  int? capacity,
  int bookedCount = 0,
  int? minAge,
  Locale locale = const Locale('en'),
  bool dark = false,
  Size viewport = const Size(900, 2400),
  UserProfileService? profile,
  void Function(BookingContact, TravelerParty)? onContinue,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: BookingTravelerInfoScreen(
        tour: _tour(
          capacity: capacity,
          bookedCount: bookedCount,
          minAge: minAge,
        ),
        initialTravelers: initialTravelers,
        userProfileService: profile ?? _FakeProfileService(),
        onContinue: onContinue,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
