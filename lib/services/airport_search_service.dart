import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/airport.dart';
import 'firebase_bootstrap.dart';

abstract interface class AirportSearchService {
  Future<List<Airport>> search(String query);
}

class AirportSearchException implements Exception {
  const AirportSearchException();
}

class FirebaseAirportSearchService implements AirportSearchService {
  FirebaseAirportSearchService({FirebaseFunctions? functions})
    : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  /// Callable failures that mean "could not be reached", and are therefore
  /// safe to answer from the bundled catalogue.
  ///
  /// `not-found` is the one that matters today: `searchAirports` is not
  /// deployed, because Cloud Functions need the Blaze plan. Without this the
  /// airport picker is dead on any configured device — the user cannot choose
  /// an origin or destination at all.
  static const Set<String> unreachableCodes = {
    'not-found',
    'unavailable',
    'deadline-exceeded',
    'internal',
  };

  /// Failures that mean the request was **refused**, not unreachable.
  ///
  /// These must stay visible. Quietly serving five bundled airports instead
  /// would hide a misconfigured App Check, a revoked key, a rejected token or
  /// a malformed request — and would hide it behind a screen that looks like
  /// it is working, which is the worst possible place to hide it.
  static const Set<String> refusedCodes = {
    'permission-denied',
    'unauthenticated',
    'invalid-argument',
    'resource-exhausted',
    'failed-precondition',
  };

  @override
  Future<List<Airport>> search(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const [];
    if (!FirebaseBootstrap.isReady && _functionsOverride == null) {
      return const PreviewAirportSearchService().search(normalized);
    }
    try {
      final response = await _functions.httpsCallable('searchAirports').call({
        'query': normalized,
        'limit': 12,
      });
      final data = response.data;
      if (data is! Map) throw const AirportSearchException();
      final rawAirports = data['airports'];
      if (rawAirports is! List) throw const AirportSearchException();
      return rawAirports
          .whereType<Map>()
          .map((item) => Airport.fromMap(item.cast<Object?, Object?>()))
          .where(
            (airport) => airport.id.isNotEmpty && airport.iataCode.isNotEmpty,
          )
          .toList(growable: false);
    } on FirebaseFunctionsException catch (error) {
      if (refusedCodes.contains(error.code)) {
        // Deliberately NOT falling back — see refusedCodes.
        throw const AirportSearchException();
      }
      if (unreachableCodes.contains(error.code)) {
        debugPrint(
          'searchAirports unreachable (${error.code}) — serving the bundled '
          'airport catalogue.',
        );
        return const PreviewAirportSearchService().search(normalized);
      }
      // An unrecognised code surfaces rather than silently degrading: a new
      // failure mode should be seen, not absorbed.
      throw const AirportSearchException();
    } on AirportSearchException {
      rethrow;
    } catch (_) {
      throw const AirportSearchException();
    }
  }
}

/// Small bundled airport catalogue used only while Firebase is unavailable.
/// It keeps the flight flow reviewable without pretending to be live data.
class PreviewAirportSearchService implements AirportSearchService {
  const PreviewAirportSearchService();

  static const airports = <Airport>[
    Airport(
      id: '3391',
      iataCode: 'EBL',
      icaoCode: 'ORER',
      name: 'Erbil International Airport',
      city: 'Erbil',
      country: 'Iraq',
      countryCode: 'IQ',
      latitude: 36.2376,
      longitude: 43.9632,
    ),
    Airport(
      id: '30011',
      iataCode: 'IST',
      icaoCode: 'LTFM',
      name: 'Istanbul Airport',
      city: 'Istanbul',
      country: 'Türkiye',
      countryCode: 'TR',
      latitude: 41.2613,
      longitude: 28.7419,
    ),
    Airport(
      id: 'BGW',
      iataCode: 'BGW',
      icaoCode: 'ORBI',
      name: 'Baghdad International Airport',
      city: 'Baghdad',
      country: 'Iraq',
      countryCode: 'IQ',
      latitude: 33.2625,
      longitude: 44.2346,
    ),
    Airport(
      id: 'DXB',
      iataCode: 'DXB',
      icaoCode: 'OMDB',
      name: 'Dubai International Airport',
      city: 'Dubai',
      country: 'United Arab Emirates',
      countryCode: 'AE',
      latitude: 25.2532,
      longitude: 55.3657,
    ),
    Airport(
      id: 'ISU',
      iataCode: 'ISU',
      icaoCode: 'ORSU',
      name: 'Sulaimaniyah International Airport',
      city: 'Sulaimaniyah',
      country: 'Iraq',
      countryCode: 'IQ',
      latitude: 35.5617,
      longitude: 45.3167,
    ),
  ];

  @override
  Future<List<Airport>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    return airports
        .where((airport) {
          final searchable = [
            airport.iataCode,
            airport.icaoCode,
            airport.name,
            airport.city,
            airport.country,
          ].join(' ').toLowerCase();
          return searchable.contains(normalized);
        })
        .toList(growable: false);
  }
}
