import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/airport.dart';
import 'package:kurdistan_paradise_travel_guide/services/airport_search_service.dart';

/// Fails every callable with a chosen Firebase error code.
class _FailingFunctions extends Fake implements FirebaseFunctions {
  _FailingFunctions(this.code);

  final String code;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FailingCallable(code);
}

class _FailingCallable extends Fake implements HttpsCallable {
  _FailingCallable(this.code);

  final String code;

  @override
  Future<HttpsCallableResult<T>> call<T>([Object? parameters]) async =>
      throw FirebaseFunctionsException(message: 'boom', code: code);
}

void main() {
  // The regression this guards: `searchAirports` is not deployed (Cloud
  // Functions need Blaze), and the bundled fallback used to fire only when
  // Firebase was ABSENT. Once Firebase was configured the picker started
  // calling a function that returns 404, so a user could not choose an origin
  // or destination at all.

  group('unreachable callable → bundled fallback', () {
    for (final code in FirebaseAirportSearchService.unreachableCodes) {
      test('"$code" serves the bundled catalogue', () async {
        final service = FirebaseAirportSearchService(
          functions: _FailingFunctions(code),
        );
        final results = await service.search('EBL');

        expect(results, isNotEmpty);
        expect(results.single.iataCode, 'EBL');
      });
    }

    test('not-found is the deployed-nowhere case specifically', () async {
      // What the SDK reports for a callable that does not exist.
      final service = FirebaseAirportSearchService(
        functions: _FailingFunctions('not-found'),
      );
      expect(await service.search('Istanbul'), isNotEmpty);
    });

    test('the fallback still honours the two-character minimum', () async {
      final service = FirebaseAirportSearchService(
        functions: _FailingFunctions('not-found'),
      );
      expect(await service.search('E'), isEmpty);
    });
  });

  group('refused callable → visible failure, never a silent fallback', () {
    for (final code in FirebaseAirportSearchService.refusedCodes) {
      test('"$code" throws instead of serving bundled data', () async {
        // Quietly answering with five bundled airports would hide a
        // misconfigured App Check, a revoked key or a rejected token behind a
        // screen that looks like it is working.
        final service = FirebaseAirportSearchService(
          functions: _FailingFunctions(code),
        );
        await expectLater(
          service.search('EBL'),
          throwsA(isA<AirportSearchException>()),
        );
      });
    }

    test('an unrecognised code also surfaces rather than degrading', () async {
      final service = FirebaseAirportSearchService(
        functions: _FailingFunctions('some-new-code'),
      );
      await expectLater(
        service.search('EBL'),
        throwsA(isA<AirportSearchException>()),
      );
    });
  });

  test('the two code sets do not overlap', () {
    // An overlap would make the outcome depend on check order.
    expect(
      FirebaseAirportSearchService.unreachableCodes
          .intersection(FirebaseAirportSearchService.refusedCodes),
      isEmpty,
    );
  });

  test('the bundled catalogue can actually answer a search', () async {
    // If this were empty the fallback would be worthless.
    expect(PreviewAirportSearchService.airports, isNotEmpty);
    final results = await const PreviewAirportSearchService().search('Erbil');
    expect(results.map((Airport a) => a.iataCode), contains('EBL'));
  });
}
