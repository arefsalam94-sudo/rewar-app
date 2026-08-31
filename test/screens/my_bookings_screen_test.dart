import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/booking.dart';
import 'package:kurdistan_paradise_travel_guide/screens/my_bookings_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/bookings_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/ticket_card.dart';

void main() {
  group('MyBookingsScreen — layout', () {
    testWidgets('draws the back button, the title and both filter rows', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(GlassBackButton), findsOneWidget);
      expect(find.text('My Bookings'), findsOneWidget);

      // The reference's type chips…
      for (final label in ['All', 'Hotels', 'Cars', 'Flights', 'Tours']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // …plus the time axis added from Booking.com / Agoda.
      for (final label in ['Upcoming', 'Past', 'Cancelled']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('shows the upcoming bookings by default, newest axis first', (
      tester,
    ) async {
      await _pump(tester);

      // Four fixtures are ahead; the second tour is completed.
      expect(find.byType(TicketCard), findsNWidgets(4));
      expect(find.text('Divan Erbil Hotel'), findsOneWidget);
      expect(find.text('Iraqi Airways'), findsOneWidget);
      expect(find.text('Lalish & Amedi Heritage Tour'), findsOneWidget);
      expect(find.text('SUV – Premium'), findsOneWidget);
      expect(find.text('Rawanduz & Bekhal Day Tour'), findsNothing);
    });

    testWidgets('the hotel card draws its reference, dates and guests', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('HTL-7845123'), findsOneWidget);
      expect(find.text('Erbil, Iraq'), findsOneWidget);
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);
      expect(find.text('2 Adults'), findsWidgets);
      expect(find.text('Check In'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsWidgets);
    });

    testWidgets('the flight card draws the route, cabin pill and barcode', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('EBL'), findsOneWidget);
      expect(find.text('IST'), findsOneWidget);
      expect(find.text('Erbil'), findsOneWidget);
      expect(find.text('Istanbul'), findsOneWidget);
      expect(find.text('2h 45m'), findsOneWidget);
      expect(find.text('ECONOMY'), findsOneWidget);
      expect(find.text('16A'), findsOneWidget);
      expect(find.text('Open Ticket'), findsOneWidget);
    });

    testWidgets('each card carries its product action, not a shared one', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Check In'), findsOneWidget);
      expect(find.text('Open Ticket'), findsOneWidget);
      expect(find.text('Pickup Info'), findsOneWidget);

      await _selectSegment(tester, 'Past');
      expect(find.text('Tour Details'), findsOneWidget);
    });

    testWidgets('a booking reference always reads left-to-right', (
      tester,
    ) async {
      // An identifier is not a sentence — same rule as the OTP box and the
      // rating digits.
      await _pump(tester, locale: const Locale('ar'));

      final reference = find.text('HTL-7845123');
      expect(reference, findsOneWidget);
      expect(Directionality.of(tester.element(reference)), TextDirection.ltr);
    });
  });

  group('MyBookingsScreen — filtering', () {
    testWidgets('the time segment moves bookings between Upcoming and Past', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Rawanduz & Bekhal Day Tour'), findsNothing);

      await _selectSegment(tester, 'Past');
      expect(find.text('Rawanduz & Bekhal Day Tour'), findsOneWidget);
      expect(find.text('Divan Erbil Hotel'), findsNothing);
      expect(find.byType(TicketCard), findsNWidgets(1));
    });

    testWidgets('a type chip narrows the list within the segment', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Hotels'));
      await tester.pumpAndSettle();

      expect(find.byType(TicketCard), findsNWidgets(1));
      expect(find.text('Divan Erbil Hotel'), findsOneWidget);
      expect(find.text('Iraqi Airways'), findsNothing);
    });

    testWidgets('both axes apply together', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Tours'));
      await tester.pumpAndSettle();
      // The only tour is in the past, so Upcoming + Tours is legitimately
      // empty — and says so rather than showing the tour anyway.
      expect(find.byType(TicketCard), findsOneWidget);
      expect(find.text('Lalish & Amedi Heritage Tour'), findsOneWidget);

      await _selectSegment(tester, 'Past');
      expect(find.byType(TicketCard), findsNWidgets(1));
    });

    testWidgets('an empty segment reports the segment, not a generic empty', (
      tester,
    ) async {
      await _pump(tester);

      await _selectSegment(tester, 'Cancelled');
      expect(find.text('No cancelled bookings'), findsOneWidget);
      // Not the "you have never booked anything" copy, which would be wrong.
      expect(find.text('No bookings yet'), findsNothing);
    });
  });

  group('MyBookingsScreen — states', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await _pump(tester, service: _SlowService(), settle: false);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a Firebase failure is shown, not thrown', (tester) async {
      await _pump(tester, service: _FailingService());

      expect(find.text("Couldn't load your bookings"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(TicketCard), findsNothing);
    });

    testWidgets('a user with no bookings gets the first-run empty state', (
      tester,
    ) async {
      await _pump(tester, service: _EmptyService());

      expect(find.text('No bookings yet'), findsOneWidget);
      expect(
        find.text(
          'When you book a hotel, flight, car or tour, it will appear here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a guest is asked to sign in, never shown an empty list', (
      tester,
    ) async {
      // There is no such thing as a guest booking — the rules require an auth
      // uid. Same precedent as favorites and the drawer's Currency row.
      await _pump(tester, isGuest: true);

      expect(find.text('Sign in to see your bookings'), findsOneWidget);
      expect(find.byType(TicketCard), findsNothing);
      expect(find.text('No bookings yet'), findsNothing);
    });

    testWidgets('a guest never triggers a Firestore read', (tester) async {
      final service = _CountingService();
      await _pump(tester, isGuest: true, service: service);

      expect(service.calls, 0);
    });
  });

  group('MyBookingsScreen — languages', () {
    testWidgets('Kurdish renders its own copy, right-to-left', (tester) async {
      await _pump(tester, locale: const Locale('ku'));

      expect(find.text('داواکاریەکانم'), findsOneWidget);
      expect(find.text('داهاتوو'), findsWidgets);
      expect(find.text('هوتێلەکان'), findsOneWidget);
      expect(find.text('هوتێلی دیڤان هەولێر'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(MyBookingsScreen))),
        TextDirection.rtl,
      );
    });

    testWidgets('Arabic renders its own copy', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      expect(find.text('حجوزاتي'), findsOneWidget);
      expect(find.text('الفنادق'), findsOneWidget);
      expect(find.text('فندق ديوان أربيل'), findsOneWidget);
      expect(find.text('رقم الحجز'), findsWidgets);
    });

    testWidgets('a flight route reads left-to-right in every language', (
      tester,
    ) async {
      // A route is a journey with a direction, not a sentence.
      for (final code in ['en', 'ku', 'ar']) {
        await _pump(tester, locale: Locale(code));
        expect(
          Directionality.of(tester.element(find.text('EBL'))),
          TextDirection.ltr,
          reason: code,
        );
      }
    });

    testWidgets('no locale is missing a booking string', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        expect(l10n.myBookingsTitle, isNotEmpty, reason: '$locale');
        expect(l10n.bookingsEmptyTitle, isNotEmpty, reason: '$locale');
        expect(l10n.bookingsSignInTitle, isNotEmpty, reason: '$locale');
        expect(l10n.bookingsLoadFailed, isNotEmpty, reason: '$locale');

        for (final filter in BookingTypeFilter.values) {
          expect(
            l10n.bookingTypeFilterLabel(filter),
            isNotEmpty,
            reason: '$locale/$filter',
          );
        }
        for (final filter in BookingTimeFilter.values) {
          expect(
            l10n.bookingTimeFilterLabel(filter),
            isNotEmpty,
            reason: '$locale/$filter',
          );
          expect(
            l10n.bookingsEmptySegment(filter),
            isNotEmpty,
            reason: '$locale/$filter',
          );
        }
        for (final type in BookingType.values) {
          expect(
            l10n.bookingTypeLabel(type),
            isNotEmpty,
            reason: '$locale/$type',
          );
          expect(
            l10n.bookingGuestLabel(type),
            isNotEmpty,
            reason: '$locale/$type',
          );
          expect(
            l10n.bookingActionLabel(type),
            isNotEmpty,
            reason: '$locale/$type',
          );
        }
        for (final status in BookingStatus.values) {
          expect(
            l10n.bookingStatusLabel(status),
            isNotEmpty,
            reason: '$locale/$status',
          );
        }
        for (final cabin in CabinClass.values) {
          expect(
            l10n.cabinClassLabel(cabin),
            isNotEmpty,
            reason: '$locale/$cabin',
          );
        }
        for (var month = 1; month <= 12; month++) {
          expect(l10n.monthName(month), isNotEmpty, reason: '$locale/$month');
        }
      }
    });

    test('date and duration formatting', () {
      const en = AppLocalizations(Locale('en'));
      const ar = AppLocalizations(Locale('ar'));
      final date = DateTime(2030, 5, 24, 9, 35);

      expect(en.bookingDate(date), 'May 24, 2030');
      // Day before month in Kurdish and Arabic.
      expect(ar.bookingDate(date), '24 مايو 2030');
      expect(en.bookingTime(date), '9:35 AM');
      expect(en.bookingTime(DateTime(2030, 5, 24, 0, 5)), '12:05 AM');
      expect(en.bookingTime(DateTime(2030, 5, 24, 12, 0)), '12:00 PM');
      expect(en.flightDuration(165), '2h 45m');
      expect(en.flightDuration(120), '2h');
      expect(en.flightDuration(45), '45m');
    });
  });

  group('MyBookingsScreen — theming and responsiveness', () {
    testWidgets('the selected type chip uses the shared selected glass state', (
      tester,
    ) async {
      // `DESIGN_light.md`: "A plain white fill is not the unselected state —
      // unselected is mint. A white chip is a bug." The reference screenshot
      // draws white chips; the design file wins.
      await _pump(tester);

      expect(_chipPanel(tester, 'All').selected, isTrue);
      expect(_chipPanel(tester, 'Hotels').selected, isFalse);

      await _pump(tester, dark: true);
      expect(_chipPanel(tester, 'All').selected, isTrue);
      expect(_chipPanel(tester, 'Hotels').selected, isFalse);
    });

    testWidgets('headings are pure white in dark mode', (tester) async {
      await _pump(tester, dark: true);

      final title = tester.widget<Text>(find.text('My Bookings'));
      expect(title.style!.color, Colors.white);
    });

    testWidgets('the card surface follows the mode', (tester) async {
      await _pump(tester);
      var context = tester.element(find.byType(MyBookingsScreen));
      expect(TicketCard.surface(context), AppColors.pageGradientTop);

      await _pump(tester, dark: true);
      context = tester.element(find.byType(MyBookingsScreen));
      expect(TicketCard.surface(context), AppColors.darkGlassTop);
    });

    testWidgets('every type chip clears the 48dp minimum touch target', (
      tester,
    ) async {
      await _pump(tester);

      for (final label in ['All', 'Hotels', 'Cars', 'Flights', 'Tours']) {
        final target = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(
          tester.getSize(target.first).height,
          greaterThanOrEqualTo(48),
          reason: label,
        );
      }
    });

    testWidgets('survives a 2.0x system font size without overflowing', (
      tester,
    ) async {
      await _pump(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a narrow 320dp phone', (tester) async {
      await _pump(tester, size: const Size(320, 2400));
      expect(tester.takeException(), isNull);
    });
  });
}

// --- Fakes -------------------------------------------------------------------

/// Serves the bundled fixtures without touching Firebase.
class _FakeService extends BookingsService {
  @override
  Future<List<Booking>> fetchMyBookings() async =>
      BookingsService.bundledBookings();
}

class _EmptyService extends BookingsService {
  @override
  Future<List<Booking>> fetchMyBookings() async => const [];
}

class _FailingService extends BookingsService {
  @override
  Future<List<Booking>> fetchMyBookings() async =>
      throw StateError('network unreachable');
}

class _SlowService extends BookingsService {
  @override
  Future<List<Booking>> fetchMyBookings() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return BookingsService.bundledBookings();
  }
}

/// Proves a guest never causes a read.
class _CountingService extends BookingsService {
  int calls = 0;

  @override
  Future<List<Booking>> fetchMyBookings() async {
    calls++;
    return const [];
  }
}

// --- Helpers -----------------------------------------------------------------

GlassPanel _chipPanel(WidgetTester tester, String label) {
  return tester.widget<GlassPanel>(
    find
        .ancestor(of: find.text(label), matching: find.byType(GlassPanel))
        .first,
  );
}

Future<void> _selectSegment(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool dark = false,
  double textScale = 1.0,
  bool isGuest = false,
  BookingsService? service,
  bool settle = true,
  Size size = const Size(900, 2400),
}) async {
  // Tall enough that every card lays out; several assertions read sizes,
  // which requires the widget to be on screen.
  tester.view.physicalSize = size;
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
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: MyBookingsScreen(
        isGuest: isGuest,
        service: service ?? _FakeService(),
      ),
    ),
  );

  if (settle) await tester.pumpAndSettle();
}
