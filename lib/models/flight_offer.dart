import 'flight_search_criteria.dart';

class FlightSegment {
  const FlightSegment({
    required this.originName,
    required this.originCode,
    required this.destinationName,
    required this.destinationCode,
    required this.departure,
    required this.arrival,
    required this.stops,
    this.flightNumber,
  });

  final String originName;
  final String originCode;
  final String destinationName;
  final String destinationCode;
  final DateTime departure;
  final DateTime arrival;
  final int stops;
  final String? flightNumber;

  int get durationMinutes => arrival.difference(departure).inMinutes;
}

class FlightOffer {
  const FlightOffer({
    required this.id,
    required this.airlineName,
    required this.outbound,
    required this.totalPrice,
    required this.currency,
    required this.priceIsTotal,
    this.returnSegment,
    this.airlineLogoUrl,
    this.baggageAllowance,
    this.refundable,
    this.expiresAt,
  });

  final String id;
  final String airlineName;
  final String? airlineLogoUrl;
  final FlightSegment outbound;
  final FlightSegment? returnSegment;
  final double totalPrice;
  final String currency;
  final bool priceIsTotal;
  final String? baggageAllowance;
  final bool? refundable;
  final DateTime? expiresAt;

  int get totalDurationMinutes =>
      outbound.durationMinutes + (returnSegment?.durationMinutes ?? 0);

  int get totalStops => outbound.stops + (returnSegment?.stops ?? 0);
}

enum FlightOfferSort { best, cheapest, fastest }

extension FlightOfferSorting on Iterable<FlightOffer> {
  List<FlightOffer> sortedBy(FlightOfferSort sort) {
    final result = toList(growable: false);
    if (result.length < 2) return result;
    switch (sort) {
      case FlightOfferSort.cheapest:
        return result.toList()
          ..sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
      case FlightOfferSort.fastest:
        return result.toList()..sort(
          (a, b) => a.totalDurationMinutes.compareTo(b.totalDurationMinutes),
        );
      case FlightOfferSort.best:
        final prices = result.map((item) => item.totalPrice);
        final durations = result.map((item) => item.totalDurationMinutes);
        final minPrice = prices.reduce((a, b) => a < b ? a : b);
        final maxPrice = prices.reduce((a, b) => a > b ? a : b);
        final minDuration = durations.reduce((a, b) => a < b ? a : b);
        final maxDuration = durations.reduce((a, b) => a > b ? a : b);
        double normalized(num value, num min, num max) => max == min
            ? 0
            : (value.toDouble() - min.toDouble()) /
                  (max.toDouble() - min.toDouble());
        double score(FlightOffer offer) =>
            normalized(offer.totalPrice, minPrice, maxPrice) * 0.55 +
            normalized(offer.totalDurationMinutes, minDuration, maxDuration) *
                0.35 +
            offer.totalStops * 0.10;
        return result.toList()..sort((a, b) => score(a).compareTo(score(b)));
    }
  }
}

class FlightResultsSelection {
  const FlightResultsSelection({required this.criteria, required this.offer});

  final FlightSearchCriteria criteria;
  final FlightOffer offer;
}
