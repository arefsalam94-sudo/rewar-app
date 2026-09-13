import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_search_criteria.dart';
import 'package:kurdistan_paradise_travel_guide/screens/flight_ticketing_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/airport_search_service.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/canonical_date_time_picker.dart';

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

class _AirportService implements AirportSearchService {
  int calls = 0;

  @override
  Future<List<Airport>> search(String query) async {
    calls += 1;
    if (query.toLowerCase().contains('erb')) return const [_erbil];
    if (query.toLowerCase().contains('ist')) return const [_istanbul];
    return const [];
  }
}

Widget _app({
  Locale locale = const Locale('en'),
  ValueChanged<FlightSearchCriteria>? onSearch,
  AirportSearchService? airportSearchService,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: FlightTicketingScreen(
    onSearch: onSearch,
    airportSearchService: airportSearchService ?? _AirportService(),
  ),
);

Future<void> _selectAirport(
  WidgetTester tester, {
  required int fieldIndex,
  required String query,
  required String resultName,
}) async {
  // The field is read-only: tapping it expands the search panel underneath,
  // whose own input lands immediately after it in the field order.
  await tester.tap(find.byType(TextFormField).at(fieldIndex));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(fieldIndex + 1), query);
  await tester.pump(const Duration(milliseconds: 301));
  await tester.pump(const Duration(milliseconds: 221));
  await tester.pumpAndSettle();
  await tester.tap(find.text(resultName));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the requested flight search controls', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Flight Ticketing'), findsOneWidget);
    expect(find.text('One-way'), findsOneWidget);
    expect(find.text('Round trip'), findsOneWidget);
    expect(find.text('Direct flights only'), findsOneWidget);
    expect(find.text('Search flights'), findsOneWidget);
  });

  testWidgets('round trip adds a return calendar field', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.text('Round trip'));
    await tester.pump();

    expect(find.text('Departure'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
  });

  testWidgets('departure opens the glass calendar sheet', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.ensureVisible(find.text('Departure'));
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  // =========================================================================
  // Round Trip is a paired start/end flow; One-Way is a genuine single date.
  // =========================================================================

  /// Opens Round Trip and returns the departure/return field finders.
  Future<void> openRoundTrip(WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.text('Round trip'));
    await tester.pumpAndSettle();
  }

  testWidgets('One-Way departure stays a plain single-date picker', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.ensureVisible(find.text('Departure'));
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();

    // The stock canonical calendar, not the range grid — and no path.
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(_rangeBandCount(tester), 0);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(_rangeBandCount(tester), 0);
  });

  testWidgets('Round Trip departure asks for one date and draws no path', (
    tester,
  ) async {
    await openRoundTrip(tester);
    await tester.ensureVisible(find.text('Departure'));
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();

    // Done is reachable without a return being demanded here.
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(
      _rangeBandCount(tester),
      0,
      reason: 'the departure step is a single date, not a trip',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('Round Trip return opens anchored and paints the whole trip', (
    tester,
  ) async {
    await openRoundTrip(tester);

    // --- Departure ---------------------------------------------------------
    await tester.ensureVisible(find.text('Departure'));
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // --- Return ------------------------------------------------------------
    // Opens on the departure's own month, with it already selected.
    await tester.ensureVisible(find.text('Return'));
    await tester.tap(find.byType(TextFormField).at(3));
    await tester.pumpAndSettle();
    expect(
      _rangeBandCount(tester),
      0,
      reason: 'the anchor alone has nothing to connect to yet',
    );

    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();
    // 12 trailing + 13/14/15 both + 16 leading = 8 half-cells.
    expect(
      _rangeBandCount(tester),
      8,
      reason: 'choosing the return must draw the whole trip as one path',
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final today = DateUtils.dateOnly(DateTime.now());
    final month = DateTime(today.year, today.month + 1);
    final formatter = MaterialLocalizations.of(
      tester.element(find.text('Return')),
    );
    // Departure untouched, return written.
    expect(
      find.text(formatter.formatMediumDate(DateTime(month.year, month.month, 12))),
      findsOneWidget,
    );
    expect(
      find.text(formatter.formatMediumDate(DateTime(month.year, month.month, 16))),
      findsOneWidget,
    );
  });

  testWidgets('a same-day return stays allowed, as it was before', (
    tester,
  ) async {
    await openRoundTrip(tester);

    await tester.ensureVisible(find.text('Departure'));
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Return'));
    await tester.tap(find.byType(TextFormField).at(3));
    await tester.pumpAndSettle();
    // Tapping the departure day itself is a valid return here — unlike Hotel,
    // where check-out must fall after check-in.
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    // The sheet's own Done — the page behind it has a PrimaryButton too.
    final done = find.ancestor(
      of: find.text('Done'),
      matching: find.byType(PrimaryButton),
    );
    expect(
      tester.widget<PrimaryButton>(done).onTap,
      isNotNull,
      reason: 'a same-day round trip must remain committable',
    );
  });

  testWidgets('passenger picker exposes age groups and cabin classes', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.ensureVisible(find.byIcon(Icons.people_outline));
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('Adults (12+)'), findsOneWidget);
    expect(find.text('Children (2–11)'), findsOneWidget);
    expect(find.text('Infants (under 2)'), findsOneWidget);
    expect(find.text('Premium Economy'), findsOneWidget);
    expect(find.text('First Class'), findsOneWidget);
  });

  testWidgets('empty search shows localized validation', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.ensureVisible(find.text('Search flights'));
    await tester.tap(find.text('Search flights'));
    await tester.pump();

    expect(find.text('Please enter where you are flying from'), findsOneWidget);
  });

  testWidgets('valid search opens the flight results page', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await _selectAirport(
      tester,
      fieldIndex: 0,
      query: 'erb',
      resultName: 'Erbil International Airport',
    );
    await _selectAirport(
      tester,
      fieldIndex: 1,
      query: 'ist',
      resultName: 'Istanbul Airport',
    );
    await tester.ensureVisible(find.text('Departure'));
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Search flights'));
    await tester.tap(find.text('Search flights'));
    await tester.pumpAndSettle();

    expect(find.text('5 flights found'), findsOneWidget);
    expect(find.text('Erbil – Istanbul'), findsOneWidget);
  });

  testWidgets('the From field opens an inline search panel', (tester) async {
    final service = _AirportService();
    await tester.pumpWidget(_app(airportSearchService: service));
    await tester.pump();

    // Nothing is searched until the panel is opened and typed into.
    expect(find.text('Enter at least 2 characters'), findsNothing);
    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 2 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'erb');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump(const Duration(milliseconds: 221));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.text('Erbil International Airport'), findsOneWidget);

    // Picking a result fills the field and collapses the panel.
    await tester.tap(find.text('Erbil International Airport'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 2 characters'), findsNothing);
  });
}

/// Half-cells of the trip path painted in Light — the one canonical range
/// band, shared with Hotel, Hotel Detail, Car Rental and Explore Tours.
int _rangeBandCount(WidgetTester tester) => tester
    .widgetList<ColoredBox>(find.byType(ColoredBox))
    .where(
      (box) =>
          box.color ==
          AppColors.actionNavy.withValues(
            alpha: kCanonicalRangeBandLightOpacity,
          ),
    )
    .length;
