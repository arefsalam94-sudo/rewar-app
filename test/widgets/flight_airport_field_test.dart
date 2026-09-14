import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/services/airport_search_service.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/flight_airport_field.dart';

/// Fails every search, so the error branch can be exercised.
class _FailingSearchService implements AirportSearchService {
  @override
  Future<List<Airport>> search(String query) async {
    throw const AirportSearchException();
  }
}

/// Records the queries it is asked for, to verify debouncing.
class _CountingSearchService implements AirportSearchService {
  final queries = <String>[];

  @override
  Future<List<Airport>> search(String query) async {
    queries.add(query);
    return const PreviewAirportSearchService().search(query);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required AirportSearchService service,
  required ValueChanged<Airport?> onChanged,
  Airport? airport,
  bool open = true,
}) async {
  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Form(
            child: FlightAirportField(
              controller: TextEditingController(),
              airport: airport,
              label: 'From',
              prefixIcon: Icons.flight_takeoff,
              service: service,
              open: open,
              onToggle: () {},
              onChanged: onChanged,
              validator: (_) => null,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a query under two characters searches nothing', (tester) async {
    final service = _CountingSearchService();
    await _pump(tester, service: service, onChanged: (_) {});

    await tester.enterText(find.byType(TextField).last, 'E');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      service.queries,
      isEmpty,
      reason: 'one keystroke must not reach the callable',
    );
  });

  testWidgets('typing a code shows the matching airport', (tester) async {
    await _pump(
      tester,
      service: const PreviewAirportSearchService(),
      onChanged: (_) {},
    );

    await tester.enterText(find.byType(TextField).last, 'EBL');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('EBL'), findsWidgets);
    expect(find.textContaining('Erbil'), findsWidgets);
  });

  testWidgets('choosing a result reports it to the caller', (tester) async {
    Airport? chosen;
    await _pump(
      tester,
      service: const PreviewAirportSearchService(),
      onChanged: (airport) => chosen = airport,
    );

    await tester.enterText(find.byType(TextField).last, 'EBL');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Erbil').last);
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.iataCode, 'EBL');
  });

  testWidgets('rapid typing is debounced into a single search', (tester) async {
    final service = _CountingSearchService();
    await _pump(tester, service: service, onChanged: (_) {});

    final field = find.byType(TextField).last;
    await tester.enterText(field, 'Er');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(field, 'Erb');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(field, 'Erbi');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Each keystroke cancels the pending timer, so only the last query runs.
    // Without this the airport callable would be invoked once per character.
    expect(service.queries, ['Erbi']);
  });

  testWidgets('a failed search shows the error state, not an empty list', (
    tester,
  ) async {
    await _pump(tester, service: _FailingSearchService(), onChanged: (_) {});

    await tester.enterText(find.byType(TextField).last, 'EBL');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // A thrown search must be visibly different from "no airports matched" —
    // otherwise a broken backend looks like a bad query to the user.
    expect(find.byType(TextButton), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
