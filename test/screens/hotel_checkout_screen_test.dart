import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_checkout_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_booking_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';

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

Future<Widget> _app() async {
  final hotel = PreviewHotelService.hotels.first;
  final criteria = HotelSearchCriteria(
    checkIn: DateTime(2026, 9, 1),
    checkOut: DateTime(2026, 9, 3),
  );
  const service = PreviewHotelBookingService(delay: Duration.zero);
  final availability = await service.fetchAvailability(hotel, criteria);
  final room = availability.availableRooms.first;
  final offer = availability.offersByRoom[room.id]!.first;
  final selection = HotelRoomSelection(
    hotel: hotel,
    criteria: criteria,
    room: room,
    offer: offer,
  );
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.lightForLocale(const Locale('en')),
    home: HotelCheckoutScreen(
      selection: selection,
      hold: MockHotelHold(
        id: 'mock-test',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
      bookingService: service,
      userProfileService: _ProfileService(),
    ),
  );
}

void main() {
  testWidgets('prefills guest details and labels both rails as previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.text('Complete Your Booking'), findsOneWidget);
    expect(find.text('Stripe — preview only'), findsOneWidget);
    expect(find.text('FIB — preview only'), findsOneWidget);
    expect(find.text('Test Guest'), findsOneWidget);
    expect(find.textContaining('No payment will be sent'), findsOneWidget);
  });

  testWidgets('confirmation remains explicitly local and unpaid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(hotelCheckoutConsentKey));
    await tester.pump();
    await tester.tap(find.byKey(hotelCheckoutConfirmKey));
    await tester.pumpAndSettle();

    expect(find.text('Preview Booking Complete'), findsOneWidget);
    expect(find.textContaining('no payment was charged'), findsOneWidget);
    expect(find.textContaining('MOCK-HTL-'), findsOneWidget);
  });
}
