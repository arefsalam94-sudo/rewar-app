import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/tour.dart';
import 'package:kurdistan_paradise_travel_guide/models/traveler_details.dart';
import 'package:kurdistan_paradise_travel_guide/screens/booking_review_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_document_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/policy_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/booking_step_indicator.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/page_background.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';

void main() {
  group('BookingReviewScreen', () {
    testWidgets('steps 1 and 2 read as completed, step 3 as active', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(BookingStepIndicator), findsOneWidget);
      // Both numerals are replaced by check glyphs; only step 3 keeps its
      // number.
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('uses the shared tour photo under the standard gradient', (
      tester,
    ) async {
      await _pump(tester);

      final background = tester.widget<PageBackground>(
        find.byType(PageBackground),
      );
      // The design-standard σ2 blur and 45% gradient, not a per-screen recipe.
      expect(background.blurSigma, isNull);
      expect(background.gradientOpacity, isNull);
    });

    testWidgets('draws the header, its hint and the booking summary', (
      tester,
    ) async {
      await _pump(tester, travelers: 2, transport: true);

      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(
        find.text('Please review your booking details before confirmation.'),
        findsOneWidget,
      );
      expect(find.text('Booking Summary'), findsOneWidget);
      expect(find.text('Gali Alibag Waterfall'), findsOneWidget);
      expect(find.text('2 Days travel'), findsOneWidget);
      expect(find.text('Aug 14 - 16'), findsOneWidget);
      expect(find.text('2 Adults + Transportation Bus'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('lists every traveler and the contact details', (tester) async {
      await _pump(
        tester,
        names: const ['Ali Ahmad', 'Sara Ahmad'],
      );

      expect(find.text('1 - Ali Ahmad'), findsOneWidget);
      expect(find.text('2 - Sara Ahmad'), findsOneWidget);
      expect(find.text('ali.ahmad@gmail.com'), findsOneWidget);
      expect(find.text('+9647501234567'), findsOneWidget);
    });

    testWidgets('an unnamed traveler still gets a row', (tester) async {
      // A blank name is exactly the mistake this screen exists to surface, so
      // the seat must not silently disappear.
      await _pump(tester, names: const ['Ali Ahmad', '']);

      expect(find.text('1 - Ali Ahmad'), findsOneWidget);
      expect(find.text('2 - Traveler 2'), findsOneWidget);
    });

    testWidgets('the breakdown shows the fee, the bus and the total', (
      tester,
    ) async {
      await _pump(tester, travelers: 2, transport: true);

      expect(find.text('Price Breakdown'), findsOneWidget);
      expect(find.text('Traveler Fee'), findsOneWidget);
      expect(find.text('2 Adults'), findsOneWidget);
      // 55 x 2.
      expect(find.text(r'$110'), findsOneWidget);
      expect(find.text('Transportation Bus'), findsOneWidget);
      expect(find.text(r'(2 × $5)'), findsOneWidget);
      // 5 x 2.
      expect(find.text(r'$10'), findsOneWidget);
      expect(find.text('Total Price'), findsOneWidget);
      // (55 + 5) x 2 — printed twice: the summary and the breakdown total.
      expect(find.text(r'$120'), findsNWidgets(2));
    });

    testWidgets('the bus line is dropped when it was not chosen', (
      tester,
    ) async {
      await _pump(tester, travelers: 2, transport: false);

      expect(find.text('Transportation Bus'), findsNothing);
      expect(find.text('Total Price'), findsOneWidget);
      // The summary total, the traveler fee and the breakdown total.
      expect(find.text(r'$110'), findsNWidgets(3));
    });

    testWidgets('the CTA is disabled until the box is ticked', (tester) async {
      await _pump(tester);

      final before = tester.widget<PrimaryButton>(find.byKey(reviewConfirmKey));
      expect(before.onTap, isNull);
      expect(find.text(r'Confirm & Pay $110'), findsOneWidget);

      await tester.tap(find.byKey(reviewAgreeCheckboxKey));
      await tester.pumpAndSettle();

      final after = tester.widget<PrimaryButton>(find.byKey(reviewConfirmKey));
      expect(after.onTap, isNotNull);
    });

    testWidgets('with no processor wired, the CTA says nothing was charged', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(reviewAgreeCheckboxKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(reviewConfirmKey));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Payments are not connected yet, so nothing was charged and no '
          'booking was created.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('once wired, the CTA hands off to the processor', (
      tester,
    ) async {
      var paid = false;
      await _pump(tester, onPaid: () => paid = true);

      await tester.tap(find.byKey(reviewAgreeCheckboxKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(reviewConfirmKey));
      await tester.pumpAndSettle();

      expect(paid, isTrue);
    });

    testWidgets('an unpriced tour cannot be confirmed even when agreed', (
      tester,
    ) async {
      await _pump(tester, priced: false);

      await tester.tap(find.byKey(reviewAgreeCheckboxKey));
      await tester.pumpAndSettle();

      final button = tester.widget<PrimaryButton>(find.byKey(reviewConfirmKey));
      expect(button.onTap, isNull);
    });

    testWidgets('the Terms link opens the Terms of Service document', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(reviewTermsLinkKey));
      await tester.pumpAndSettle();

      expect(find.byType(PolicyDocumentScreen), findsOneWidget);
    });

    testWidgets('the Policy link opens the Policy hub from the drawer', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(reviewPolicyLinkKey));
      await tester.pumpAndSettle();

      expect(find.byType(PolicyScreen), findsOneWidget);
    });

    testWidgets('renders in Kurdish and Arabic, right to left', (tester) async {
      for (final locale in const [Locale('ku'), Locale('ar')]) {
        await _pump(tester, locale: locale, transport: true);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(BookingReviewScreen)),
        );
        expect(find.text(l10n.reviewConfirmTitle), findsOneWidget);
        expect(find.text(l10n.priceBreakdown), findsOneWidget);
        expect(find.text(l10n.travelersInformation), findsOneWidget);
        // The consent sentence keeps both links in every language.
        expect(find.text(l10n.reviewTermsLink), findsOneWidget);
        expect(find.text(l10n.reviewPolicyLink), findsOneWidget);
        // Money stays left-to-right and Western-digited.
        expect(find.text(r'$120'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(tester, dark: true);
      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out on a phone width and at a large system font', (
      tester,
    ) async {
      await _pump(
        tester,
        viewport: const Size(360, 3000),
        transport: true,
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Total Price'), findsOneWidget);
    });
  });
}

Tour _tour({bool priced = true}) => Tour(
  id: 'gali-alibag',
  names: const {'en': 'Gali Alibag Waterfall', 'ku': 'گەلی', 'ar': 'شلال'},
  descriptions: const {'en': 'A scenic waterfall.'},
  locationLabels: const {'en': 'Rawanduz, Erbil'},
  companyTag: 'AB group',
  durationDays: 2,
  pricePerPerson: priced ? 55 : null,
  currency: 'USD',
  startAt: DateTime(2026, 8, 14),
  endAt: DateTime(2026, 8, 16),
  transportAvailable: true,
  transportPricePerPerson: 5,
);

TravelerParty _party(int count, List<String>? names) {
  var party = TravelerParty.ofSize(count);
  if (names == null) return party;
  for (var i = 0; i < names.length && i < party.size; i++) {
    party = party.updated(
      i,
      party.travelers[i].copyWith(fullName: names[i]),
    );
  }
  return party;
}

Future<void> _pump(
  WidgetTester tester, {
  int travelers = 2,
  List<String>? names,
  bool transport = false,
  bool priced = true,
  Locale locale = const Locale('en'),
  bool dark = false,
  Size viewport = const Size(900, 2600),
  double textScale = 1.0,
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: BookingReviewScreen(
        tour: _tour(priced: priced),
        contact: const BookingContact(
          fullName: 'Ali Ahmad',
          email: 'ali.ahmad@gmail.com',
          phone: '7501234567',
        ),
        party: _party(travelers, names),
        transport: transport,
        onPaid: onPaid,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
