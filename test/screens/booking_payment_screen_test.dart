import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/saved_payment_method.dart';
import 'package:kurdistan_paradise_travel_guide/models/tour.dart';
import 'package:kurdistan_paradise_travel_guide/models/traveler_details.dart';
import 'package:kurdistan_paradise_travel_guide/screens/booking_payment_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/booking_review_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/booking_step_indicator.dart';

void main() {
  group('The total is the model\'s, so the two screens cannot disagree', () {
    test('travelers multiply, and the bus is priced per person', () {
      final tour = _tour();
      expect(tour.totalFor(travelers: 1, transport: false), 55);
      expect(tour.totalFor(travelers: 2, transport: false), 110);
      // 55 + 5 bus, twice over.
      expect(tour.totalFor(travelers: 2, transport: true), 120);
    });

    test('an unpriced tour totals null, never zero', () {
      const tour = Tour(
        id: 't',
        names: {'en': 'Unpriced'},
        descriptions: {},
        locationLabels: {},
        companyTag: 'AB',
        durationDays: 1,
      );
      expect(tour.totalFor(travelers: 3, transport: true), isNull);
    });
  });

  group('BookingPaymentScreen', () {
    testWidgets('step 1 reads as completed and step 2 as active', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(BookingStepIndicator), findsOneWidget);
      // Step 1's numeral is replaced by the check glyph.
      expect(find.text('1'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('draws the header and the booking summary', (tester) async {
      await _pump(tester, travelers: 2, transport: true);

      expect(find.text('Payment Details'), findsOneWidget);
      expect(
        find.text('Complete your payment to confirm the booking'),
        findsOneWidget,
      );
      expect(find.text('Booking Summary'), findsOneWidget);
      expect(find.text('Gali Alibag Waterfall'), findsOneWidget);
      expect(find.text('2 Days travel'), findsOneWidget);
      expect(find.text('2 Adults + Transportation Bus'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      // (55 + 5) x 2.
      expect(find.text(r'$120'), findsOneWidget);
    });

    testWidgets('the summary drops the bus line when it was not chosen', (
      tester,
    ) async {
      await _pump(tester, travelers: 2, transport: false);

      expect(find.text('2 Adults'), findsOneWidget);
      expect(find.text(r'$110'), findsOneWidget);
    });

    testWidgets('one traveler reads "1 Adult", not "1 Adults"', (tester) async {
      await _pump(tester, travelers: 1);
      expect(find.text('1 Adult'), findsOneWidget);
    });

    testWidgets('a saved card is shown and selected by default', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Current Payment Method'), findsOneWidget);
      expect(find.text('Kurdistan International Bank'), findsOneWidget);
      expect(find.text('Debit Card'), findsWidgets);
      expect(find.text('•••• 4832'), findsNWidgets(2));
      expect(find.text('06/28'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('the card art and its details stay on one row, even narrow', (
      tester,
    ) async {
      for (final width in const [320.0, 360.0, 393.0]) {
        await _pump(tester, viewport: Size(width, 1400));

        final art = tester.getRect(find.byKey(paymentSavedCardArtKey));
        final details = tester.getRect(
          find.text('Kurdistan International Bank'),
        );

        // Details start after the artwork ends, not beneath it.
        expect(
          details.left,
          greaterThanOrEqualTo(art.right),
          reason: 'details should be beside the card at dp',
        );
        // And the two share the row rather than stacking.
        expect(
          details.top < art.bottom && art.top < details.bottom,
          isTrue,
          reason: 'details should share the row at dp',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('no saved card hides the block entirely', (tester) async {
      await _pump(tester, saved: const []);

      expect(find.text('Current Payment Method'), findsNothing);
      expect(find.text('Kurdistan International Bank'), findsNothing);
      // The rails are still offered, with the prompt in place of the card.
      expect(find.text('Choose how you want to pay'), findsOneWidget);
      expect(find.text('Mastercard / Visa'), findsOneWidget);
      expect(find.text('First Iraqi Bank'), findsOneWidget);
    });

    testWidgets('exactly two rails are offered — no Zain Cash row', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(paymentRailKey(PaymentRail.card)), findsOneWidget);
      expect(find.byKey(paymentRailKey(PaymentRail.fib)), findsOneWidget);
      expect(find.text('Zain Cash'), findsNothing);
      expect(find.text('NassWallet'), findsNothing);
    });

    testWidgets('card fields appear only after choosing the card rail', (
      tester,
    ) async {
      await _pump(tester);

      // The saved card is doing the job, so no entry form is drawn.
      expect(find.byKey(paymentCardNumberKey), findsNothing);

      await tester.tap(find.byKey(paymentRailKey(PaymentRail.card)));
      await tester.pumpAndSettle();

      expect(find.byKey(paymentCardNumberKey), findsOneWidget);
      expect(find.byKey(paymentExpiryKey), findsOneWidget);
      expect(find.byKey(paymentCvvKey), findsOneWidget);
    });

    testWidgets('choosing FIB offers no card fields', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(paymentRailKey(PaymentRail.fib)));
      await tester.pumpAndSettle();

      expect(find.byKey(paymentCardNumberKey), findsNothing);
      expect(find.byKey(paymentCvvKey), findsNothing);
    });

    testWidgets('an empty card form is refused before anything is sent', (
      tester,
    ) async {
      var paid = false;
      await _pump(tester, onPaid: () => paid = true);

      await tester.tap(find.byKey(paymentRailKey(PaymentRail.card)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(paymentContinueKey));
      await tester.pumpAndSettle();

      expect(paid, isFalse);
      expect(
        find.text('Please enter the card number, expiry date and CVV.'),
        findsOneWidget,
      );
    });

    testWidgets('Continue opens step 3 rather than charging here', (
      tester,
    ) async {
      var paid = false;
      await _pump(tester, onPaid: () => paid = true);

      await tester.tap(find.byKey(paymentContinueKey));
      await tester.pumpAndSettle();

      // Step 3 is where the charge belongs; this screen only collects the
      // instrument, so onPaid must not have fired on the way there.
      expect(find.byType(BookingReviewScreen), findsOneWidget);
      expect(paid, isFalse);
    });

    testWidgets('a saved card needs no card entry to continue', (tester) async {
      // onPaid omitted: the deliberate "not connected" state, which step 3
      // reports rather than this screen.
      await _pump(tester);

      await tester.tap(find.byKey(paymentContinueKey));
      await tester.pumpAndSettle();

      expect(find.byType(BookingReviewScreen), findsOneWidget);
    });

    testWidgets('the card number groups into fours as it is typed', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byKey(paymentRailKey(PaymentRail.card)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(paymentCardNumberKey),
        '4111111111111111',
      );
      await tester.pumpAndSettle();
      expect(find.text('4111 1111 1111 1111'), findsOneWidget);
    });

    testWidgets('the expiry gains its slash as it is typed', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(paymentRailKey(PaymentRail.card)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(paymentExpiryKey), '1228');
      await tester.pumpAndSettle();
      expect(find.text('12/28'), findsOneWidget);
    });

    testWidgets('the CVV is obscured', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(paymentRailKey(PaymentRail.card)));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(paymentCvvKey),
          matching: find.byType(TextFormField),
        ),
      );
      expect(field.controller, isNotNull);
      // The obscured flag lives on the inner EditableText.
      await tester.enterText(find.byKey(paymentCvvKey), '123');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(paymentCvvKey),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });

    testWidgets('renders in Kurdish and Arabic, right to left', (tester) async {
      for (final locale in const [Locale('ku'), Locale('ar')]) {
        await _pump(tester, locale: locale);
        final l10n = AppLocalizations(locale);

        expect(find.text(l10n.paymentDetails), findsWidgets);
        expect(find.text(l10n.bookingSummary), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(BookingStepIndicator))),
          TextDirection.rtl,
        );
        // The total is a measurement sequence: LTR in every language.
        expect(
          Directionality.of(tester.element(find.text(r'$110'))),
          TextDirection.ltr,
        );
      }
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(tester, dark: true);
      expect(find.text('Payment Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the CTA stays put while the page scrolls', (tester) async {
      await _pump(tester, viewport: const Size(393, 760));

      final before = tester.getRect(find.byKey(paymentContinueKey));
      await tester.drag(find.byType(ListView), const Offset(0, -260));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(paymentContinueKey)), before);
    });

    testWidgets('lays out without overflow on a small phone', (tester) async {
      await _pump(tester, viewport: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });
  });
}

// --- Helpers -----------------------------------------------------------------

Tour _tour() => Tour(
  id: 'gali-alibag',
  names: const {'en': 'Gali Alibag Waterfall', 'ku': 'گەلی', 'ar': 'شلال'},
  descriptions: const {'en': 'A scenic waterfall.'},
  locationLabels: const {'en': 'Rawanduz, Erbil'},
  companyTag: 'AB group',
  durationDays: 2,
  pricePerPerson: 55,
  currency: 'USD',
  startAt: DateTime(2026, 8, 14),
  endAt: DateTime(2026, 8, 16),
  transportAvailable: true,
  transportPricePerPerson: 5,
);

Future<void> _pump(
  WidgetTester tester, {
  int travelers = 2,
  bool transport = false,
  List<SavedPaymentMethod>? saved,
  Locale locale = const Locale('en'),
  bool dark = false,
  Size viewport = const Size(900, 2600),
  VoidCallback? onPaid,
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
      home: BookingPaymentScreen(
        tour: _tour(),
        contact: const BookingContact(
          fullName: 'Sara Ahmad',
          email: 'sara@example.com',
          phone: '7501234567',
        ),
        party: TravelerParty.ofSize(travelers),
        transport: transport,
        savedMethods: saved,
        onPaid: onPaid,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
