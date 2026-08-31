import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel.dart';
import 'package:kurdistan_paradise_travel_guide/screens/choose_room_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_booking_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';

final _hotel = PreviewHotelService.hotels.first;

HotelSearchCriteria _criteria({int rooms = 1}) => HotelSearchCriteria(
  checkIn: DateTime(2026, 9, 1),
  checkOut: DateTime(2026, 9, 3),
  adults: 2,
  rooms: rooms,
);

Widget _app({
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  int rooms = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  themeMode: themeMode,
  home: ChooseRoomScreen(
    hotel: _hotel,
    criteria: _criteria(rooms: rooms),
    bookingService: const PreviewHotelBookingService(delay: Duration.zero),
  ),
);

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('selects, deselects and reserves exactly one rate', (
    tester,
  ) async {
    _size(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Garden View Room'), findsOneWidget);
    expect(find.text('King Room'), findsOneWidget);
    final reserve = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(chooseRoomReserveKey),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(reserve.onPressed, isNull);

    await tester.tap(find.byKey(chooseRoomRateKey('garden-dinner')));
    await tester.pump();
    final enabled = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(chooseRoomReserveKey),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(enabled.onPressed, isNotNull);

    await tester.tap(find.byKey(chooseRoomRateKey('garden-dinner')));
    await tester.pump();
    final disabledAgain = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(chooseRoomReserveKey),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(disabledAgain.onPressed, isNull);

    await tester.tap(find.byKey(chooseRoomRateKey('king-flex')));
    await tester.pump();
    await tester.tap(find.byKey(chooseRoomReserveKey));
    await tester.pumpAndSettle();
    expect(find.text('Complete Your Booking'), findsOneWidget);
  });

  testWidgets('shows a designed empty state for unsupported multiple rooms', (
    tester,
  ) async {
    _size(tester);
    await tester.pumpWidget(_app(rooms: 2));
    await tester.pumpAndSettle();

    expect(
      find.text('No rooms are available for these dates.'),
      findsOneWidget,
    );
    expect(find.text('Change dates'), findsOneWidget);
  });

  testWidgets('renders dark Arabic RTL without an exception', (tester) async {
    _size(tester);
    await tester.pumpWidget(
      _app(locale: const Locale('ar'), themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر غرفتك'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('اختر غرفتك'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the two rates share a row on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final dinner = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-dinner')),
    );
    final only = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-room-only')),
    );

    expect(dinner.top, only.top);
    expect(dinner.right, lessThanOrEqualTo(only.left));
    // The longer wording on one rate must not leave the other card short.
    expect(dinner.height, only.height);
    expect(dinner.width, only.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a raised text scale drops the rates back to one column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 3600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final dinner = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-dinner')),
    );
    final only = tester.getRect(
      find.byKey(chooseRoomRateKey('garden-room-only')),
    );

    expect(only.top, greaterThan(dinner.top));
    expect(tester.takeException(), isNull);
  });
}
