import '../models/airport.dart';
import '../models/flight_offer.dart';
import '../models/flight_search_criteria.dart';

abstract interface class FlightResultsService {
  Future<List<FlightOffer>> search(FlightSearchCriteria criteria);
}

/// Review data used until a live flight provider is connected.
///
/// The UI depends only on [FlightResultsService], so replacing this class with
/// an API repository requires no widget or database rewrite.
class MockFlightResultsService implements FlightResultsService {
  const MockFlightResultsService();

  static const _airportCodes = <String, String>{
    'erbil': 'EBL',
    'hawler': 'EBL',
    'هەولێر': 'EBL',
    'أربيل': 'EBL',
    'istanbul': 'IST',
    'ئەستەنبووڵ': 'IST',
    'اسطنبول': 'IST',
    'baghdad': 'BGW',
    'بغداد': 'BGW',
    'dubai': 'DXB',
    'دبي': 'DXB',
    'sulaymaniyah': 'ISU',
    'سلێمانی': 'ISU',
    'السليمانية': 'ISU',
  };

  @override
  Future<List<FlightOffer>> search(FlightSearchCriteria criteria) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final originCode = _codeFor(criteria.origin);
    final destinationCode = _codeFor(criteria.destination);
    final specs = <_MockOfferSpec>[
      const _MockOfferSpec('Astra Airlines', 100, 165, 400, 0, 'AS 204'),
      const _MockOfferSpec('Blue Horizon Airlines', 555, 165, 350, 0, 'BH 118'),
      const _MockOfferSpec('SkyJet Airlines', 920, 135, 435, 0, 'SJ 415'),
      const _MockOfferSpec('Mesopotamia Air', 680, 190, 365, 1, 'MA 307'),
      const _MockOfferSpec('Zagros Wings', 1220, 155, 390, 0, 'ZW 612'),
    ];
    final visibleSpecs = criteria.directFlightsOnly
        ? specs.where((item) => item.stops == 0)
        : specs;
    return visibleSpecs
        .map((spec) {
          final departure = _atMinute(
            criteria.departureDate,
            spec.departureMinute,
          );
          final returnDate = criteria.returnDate;
          return FlightOffer(
            id: '${originCode}_${destinationCode}_${spec.flightNumber}',
            airlineName: spec.airline,
            outbound: FlightSegment(
              originName: criteria.origin.displayName,
              originCode: originCode,
              destinationName: criteria.destination.displayName,
              destinationCode: destinationCode,
              departure: departure,
              arrival: departure.add(Duration(minutes: spec.durationMinutes)),
              stops: spec.stops,
              flightNumber: spec.flightNumber,
            ),
            returnSegment:
                criteria.tripType == FlightTripType.roundTrip &&
                    returnDate != null
                ? _returnSegment(
                    criteria: criteria,
                    spec: spec,
                    originCode: originCode,
                    destinationCode: destinationCode,
                    returnDate: returnDate,
                  )
                : null,
            totalPrice: criteria.tripType == FlightTripType.roundTrip
                ? spec.price * 1.82
                : spec.price,
            currency: 'USD',
            priceIsTotal: true,
            baggageAllowance: '20 kg',
            refundable: spec.price >= 390,
            expiresAt: DateTime.now().add(const Duration(minutes: 20)),
          );
        })
        .toList(growable: false);
  }

  static FlightSegment _returnSegment({
    required FlightSearchCriteria criteria,
    required _MockOfferSpec spec,
    required String originCode,
    required String destinationCode,
    required DateTime returnDate,
  }) {
    final departure = _atMinute(returnDate, spec.departureMinute + 45);
    return FlightSegment(
      originName: criteria.destination.displayName,
      originCode: destinationCode,
      destinationName: criteria.origin.displayName,
      destinationCode: originCode,
      departure: departure,
      arrival: departure.add(Duration(minutes: spec.durationMinutes + 10)),
      stops: spec.stops,
      flightNumber: '${spec.flightNumber}R',
    );
  }

  static DateTime _atMinute(DateTime date, int minute) =>
      DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);

  static String _codeFor(Object input) {
    if (input is Airport) return input.iataCode;
    if (input is! String) return '---';
    final normalized = input.trim().toLowerCase();
    final exact = _airportCodes[normalized];
    if (exact != null) return exact;
    for (final entry in _airportCodes.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return '---';
  }
}

class _MockOfferSpec {
  const _MockOfferSpec(
    this.airline,
    this.departureMinute,
    this.durationMinutes,
    this.price,
    this.stops,
    this.flightNumber,
  );

  final String airline;
  final int departureMinute;
  final int durationMinutes;
  final double price;
  final int stops;
  final String flightNumber;
}
