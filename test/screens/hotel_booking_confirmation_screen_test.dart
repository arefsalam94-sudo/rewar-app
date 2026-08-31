import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/booking.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_booking_confirmation_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_checkout_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';

void main() {
  testWidgets('uses a mock reference and never claims provider confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final booking = Booking(
      id: 'mock',
      userId: 'preview-user',
      type: BookingType.hotel,
      status: BookingStatus.pending,
      bookingReference: 'MOCK-HTL-1234567',
      startAt: DateTime(2026, 9, 1),
      referenceId: 'preview-hotel',
      display: const BookingDisplay(
        titles: {'en': 'Preview Hotel'},
        locationLabels: {'en': 'Erbil'},
        roomName: 'Garden View Room',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightForLocale(const Locale('en')),
        home: HotelBookingConfirmationScreen(
          booking: booking,
          paymentMethod: HotelPaymentMethod.stripe,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Booking Complete'), findsOneWidget);
    expect(find.text('MOCK-HTL-1234567'), findsOneWidget);
    expect(find.textContaining('no payment was charged'), findsOneWidget);
  });
}
