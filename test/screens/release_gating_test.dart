import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/models/booking.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_search_criteria.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_checkout_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_booking_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/screens/flight_search_results_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/bookings_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/flight_results_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/release_gate.dart';

/// Tests run in debug, so `kDebugMode` is true and the preview flows are live
/// by default. `ReleaseGate.debugSetPreviewFeaturesAllowed(false)` is the only
/// way to exercise the shipped path — and it is itself unavailable in release,
/// because its body sits inside an `assert`.
void main() {
  tearDown(() => ReleaseGate.debugSetPreviewFeaturesAllowed(null));

  const erbil = Airport(
    id: '3391',
    iataCode: 'EBL',
    icaoCode: 'ORER',
    name: 'Erbil International Airport',
    city: 'Erbil',
    country: 'Iraq',
    countryCode: 'IQ',
    latitude: 36.2,
    longitude: 43.9,
  );
  const istanbul = Airport(
    id: '30011',
    iataCode: 'IST',
    icaoCode: 'LTFM',
    name: 'Istanbul Airport',
    city: 'Istanbul',
    country: 'Türkiye',
    countryCode: 'TR',
    latitude: 41.2,
    longitude: 28.7,
  );

  final criteria = FlightSearchCriteria(
    tripType: FlightTripType.oneWay,
    origin: erbil,
    destination: istanbul,
    departureDate: DateTime(2027, 5, 1),
    returnDate: null,
    adults: 1,
    children: 0,
    infants: 0,
    cabinClass: CabinClass.economy,
    directFlightsOnly: false,
  );

  group('ReleaseGate', () {
    test('preview flows are live in debug, which is where tests run', () {
      expect(ReleaseGate.previewFeaturesAllowed, isTrue);
    });

    test('the override closes and reopens the gate', () {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      expect(ReleaseGate.previewFeaturesAllowed, isFalse);
      ReleaseGate.debugSetPreviewFeaturesAllowed(null);
      expect(ReleaseGate.previewFeaturesAllowed, isTrue);
    });
  });

  // --- 1. Flights ---------------------------------------------------------

  group('release Flights cannot show fake offers', () {
    const service = MockFlightResultsService();

    test('the mock source reports itself unavailable', () {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      expect(service.isAvailable, isFalse);
    });

    test('searching it refuses rather than returning invented offers', () {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      // Not an empty list: "we found nothing" and "we do not sell flights
      // yet" are different statements and must stay distinguishable.
      expect(
        () => service.search(criteria),
        throwsA(isA<FlightResultsUnavailable>()),
      );
    });

    testWidgets('the results screen shows Coming soon, not offers', (
      tester,
    ) async {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      await _pumpResults(tester, criteria);

      expect(find.text('Flight booking is coming soon'), findsOneWidget);
      // None of the invented airlines may appear anywhere on screen.
      for (final airline in const [
        'Astra Airlines',
        'Blue Horizon Airlines',
        'SkyJet Airlines',
        'Mesopotamia Air',
        'Zagros Wings',
      ]) {
        expect(find.textContaining(airline), findsNothing, reason: airline);
      }
      // Nor the "no flights found" wording, which would imply we searched.
      expect(find.text('No flights found'), findsNothing);
    });

    testWidgets('the coming-soon state offers nothing to retry', (
      tester,
    ) async {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      await _pumpResults(tester, criteria);

      expect(find.text('Retry'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('debug/test mock Flights still work', () {
    const service = MockFlightResultsService();

    test('the mock source reports itself available', () {
      expect(service.isAvailable, isTrue);
    });

    test('searching returns the development offers', () async {
      final offers = await service.search(criteria);
      expect(offers, isNotEmpty);
      expect(offers.map((o) => o.airlineName), contains('Astra Airlines'));
    });

    testWidgets('the results screen renders them', (tester) async {
      await _pumpResults(tester, criteria);
      // The mock sleeps 650ms before answering.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('Astra Airlines'), findsWidgets);
      expect(find.text('Flight booking is coming soon'), findsNothing);
    });
  });

  // --- 2. Hotel checkout --------------------------------------------------

  group('release Hotel Checkout cannot create a fake booking', () {
    Booking sample({String id = 'mock-hotel-release-probe'}) => Booking(
      id: id,
      userId: 'preview-user',
      type: BookingType.hotel,
      status: BookingStatus.pending,
      bookingReference: 'MOCK-HTL-1',
      startAt: DateTime(2027, 5, 1),
      endAt: DateTime(2027, 5, 3),
      referenceId: 'preview-divan-erbil',
      totalPrice: 400,
      currency: 'USD',
      cancellable: false,
      display: const BookingDisplay(
        titles: {'en': 'Divan Erbil'},
        locationLabels: {'en': 'Erbil'},
        imageAsset: null,
        guestCount: 2,
        roomName: 'Garden View',
      ),
    );

    test('a preview booking is not recorded in release', () async {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      // The old `assert(kDebugMode)` here was stripped in release, so this is
      // the regression that matters: the call is a silent no-op, not a crash
      // and not an insert.
      expect(
        () => BookingsService.addSessionPreviewBooking(sample()),
        returnsNormally,
      );

      // Read it back the way the My Bookings screen does.
      ReleaseGate.debugSetPreviewFeaturesAllowed(null);
      final listed = await BookingsService().fetchMyBookings();
      expect(
        listed.any((b) => b.id == 'mock-hotel-release-probe'),
        isFalse,
        reason: 'a release build recorded a preview booking',
      );
    });

    test('and is recorded in debug, where the preview flow still runs', () async {
      BookingsService.addSessionPreviewBooking(sample(id: 'mock-hotel-debug'));
      final listed = await BookingsService().fetchMyBookings();
      expect(listed.any((b) => b.id == 'mock-hotel-debug'), isTrue);
    });

    testWidgets('the confirm button is disabled and says Coming soon', (
      tester,
    ) async {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      await _pumpCheckout(tester);

      expect(find.text('Booking is coming soon'), findsOneWidget);
      expect(find.text('Confirm preview booking'), findsNothing);
      expect(
        find.textContaining('Rooms cannot be reserved in the app yet'),
        findsOneWidget,
      );
    });

    testWidgets('tapping through cannot reach a confirmation', (tester) async {
      ReleaseGate.debugSetPreviewFeaturesAllowed(false);
      await _pumpCheckout(tester);

      await tester.tap(find.byKey(hotelCheckoutConsentKey));
      await tester.pump();
      await tester.tap(
        find.byKey(hotelCheckoutConfirmKey),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Still on checkout; no reference number was minted.
      expect(find.text('Preview Booking Complete'), findsNothing);
      expect(find.textContaining('MOCK-HTL-'), findsNothing);
      expect(find.text('Booking is coming soon'), findsOneWidget);
    });

    testWidgets('debug still completes the preview booking', (tester) async {
      await _pumpCheckout(tester);

      expect(find.text('Confirm preview booking'), findsOneWidget);
      await tester.tap(find.byKey(hotelCheckoutConsentKey));
      await tester.pump();
      await tester.tap(find.byKey(hotelCheckoutConfirmKey));
      await tester.pumpAndSettle();

      expect(find.text('Preview Booking Complete'), findsOneWidget);
    });
  });

  group('no client Firestore booking write was introduced', () {
    test('bookings_service.dart performs no Firestore write', () {
      final source = File('lib/services/bookings_service.dart')
          .readAsStringSync();
      for (final write in const [
        '.set(',
        '.add(',
        '.update(',
        '.delete(',
        'SetOptions',
      ]) {
        expect(
          source.contains(write),
          isFalse,
          reason: 'bookings_service.dart now contains $write',
        );
      }
    });

    test('hotel_checkout_screen.dart performs no Firestore write', () {
      final source = File('lib/screens/hotel_checkout_screen.dart')
          .readAsStringSync();
      expect(source.contains('FirebaseFirestore'), isFalse);
      expect(source.contains('collection('), isFalse);
    });

    test('firestore.rules still denies every client booking write', () {
      final rules = File('firestore.rules').readAsStringSync();
      expect(
        rules.contains('allow create, update, delete: if false;'),
        isTrue,
        reason: 'the bookings deny rule is gone',
      );
    });
  });
}

Future<void> _pumpResults(
  WidgetTester tester,
  FlightSearchCriteria criteria,
) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: FlightSearchResultsScreen(criteria: criteria),
    ),
  );
  await tester.pump();
}

class _ProfileService extends UserProfileService {
  @override
  Future<UserProfile?> fetchProfile() async => const UserProfile(
    name: 'Test Guest',
    email: 'guest@example.com',
    phone: '+964 750 123 4567',
    profileImageUrl: null,
    currency: AppCurrency.usd,
  );
}

/// Mirrors the harness in `hotel_checkout_screen_test.dart`, including the
/// runAsync build: `_app()` reaches `PreviewHotelService.fetchDetail`, which
/// sleeps 220ms on the real clock, and awaiting that before the first pump
/// deadlocks the fake clock.
Future<Widget> _checkoutApp() async {
  final hotel = PreviewHotelService.hotels.first;
  final criteria = HotelSearchCriteria(
    checkIn: DateTime(2026, 9, 1),
    checkOut: DateTime(2026, 9, 3),
  );
  const service = PreviewHotelBookingService(delay: Duration.zero);
  final availability = await service.fetchAvailability(hotel, criteria);
  final room = availability.availableRooms.first;
  final offer = availability.offersByRoom[room.id]!.first;
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.lightForLocale(const Locale('en')),
    home: HotelCheckoutScreen(
      selection: HotelRoomSelection(
        hotel: hotel,
        criteria: criteria,
        room: room,
        offer: offer,
      ),
      hold: MockHotelHold(
        id: 'mock-test',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
      bookingService: service,
      userProfileService: _ProfileService(),
    ),
  );
}

Future<void> _pumpCheckout(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final app = await tester.runAsync(_checkoutApp);
  await tester.pumpWidget(app!);
  await tester.pumpAndSettle();
}
