import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/models/booking.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_offer.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_search_criteria.dart';
import 'package:kurdistan_paradise_travel_guide/screens/flight_search_results_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/flight_results_service.dart';

final criteria = FlightSearchCriteria(
  tripType: FlightTripType.oneWay,
  origin: _erbil,
  destination: _istanbul,
  departureDate: _date,
  adults: 1,
  children: 0,
  infants: 0,
  cabinClass: CabinClass.economy,
  directFlightsOnly: false,
);

final _date = DateTime(2027, 8, 22);

const _erbil = Airport(
  id: '3391',
  iataCode: 'EBL',
  icaoCode: 'ORER',
  name: 'Erbil International Airport',
  city: 'Erbil',
  country: 'Iraq',
  countryCode: 'IQ',
  latitude: 36.2376,
  longitude: 43.9632,
);

const _istanbul = Airport(
  id: '30011',
  iataCode: 'IST',
  icaoCode: 'LTFM',
  name: 'Istanbul Airport',
  city: 'Istanbul',
  country: 'Türkiye',
  countryCode: 'TR',
  latitude: 41.2613,
  longitude: 28.7419,
);

Widget _app(
  FlightResultsService service, {
  FlightSearchCriteria? searchCriteria,
}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: FlightSearchResultsScreen(
    criteria: searchCriteria ?? criteria,
    service: service,
  ),
);

class _EmptyService implements FlightResultsService {
  @override
  Future<List<FlightOffer>> search(FlightSearchCriteria criteria) async => [];
}

class _ErrorService implements FlightResultsService {
  @override
  Future<List<FlightOffer>> search(FlightSearchCriteria criteria) async =>
      throw StateError('network details must not be shown');
}

class _PendingService implements FlightResultsService {
  final completer = Completer<List<FlightOffer>>();

  @override
  Future<List<FlightOffer>> search(FlightSearchCriteria criteria) =>
      completer.future;
}

void main() {
  testWidgets('renders typed mock results and sorting controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const MockFlightResultsService()));
    await tester.pumpAndSettle();

    expect(find.text('5 flights found'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Cheapest'), findsOneWidget);
    expect(find.text('Fastest'), findsOneWidget);
    expect(find.text('Astra Airlines'), findsOneWidget);
    expect(find.text('EBL'), findsWidgets);
    expect(find.text('IST'), findsWidgets);
  });

  testWidgets('return segment arrow points opposite to outbound', (
    tester,
  ) async {
    final roundTripCriteria = FlightSearchCriteria(
      tripType: FlightTripType.roundTrip,
      origin: _erbil,
      destination: _istanbul,
      departureDate: _date,
      returnDate: _date.add(const Duration(days: 7)),
      adults: 1,
      children: 0,
      infants: 0,
      cabinClass: CabinClass.economy,
      directFlightsOnly: false,
    );

    await tester.pumpWidget(
      _app(const MockFlightResultsService(), searchCriteria: roundTripCriteria),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_forward), findsWidgets);
    expect(find.byIcon(Icons.arrow_back), findsWidgets);
  });

  testWidgets('shows a non-blank loading state', (tester) async {
    await tester.pumpWidget(_app(_PendingService()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.flight_outlined), findsNWidgets(3));
  });

  testWidgets('renders localized empty state', (tester) async {
    await tester.pumpWidget(_app(_EmptyService()));
    await tester.pumpAndSettle();
    expect(find.text('No flights found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('hides technical errors behind friendly state', (tester) async {
    await tester.pumpWidget(_app(_ErrorService()));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load flights"), findsOneWidget);
    expect(find.textContaining('network details'), findsNothing);
  });
}
