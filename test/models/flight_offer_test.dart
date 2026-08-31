import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/flight_offer.dart';

FlightOffer _offer(String id, double price, int duration, int stops) {
  final departure = DateTime(2026, 8, 22, 8);
  return FlightOffer(
    id: id,
    airlineName: id,
    outbound: FlightSegment(
      originName: 'Erbil',
      originCode: 'EBL',
      destinationName: 'Istanbul',
      destinationCode: 'IST',
      departure: departure,
      arrival: departure.add(Duration(minutes: duration)),
      stops: stops,
    ),
    totalPrice: price,
    currency: 'USD',
    priceIsTotal: true,
  );
}

void main() {
  final offers = [
    _offer('balanced', 400, 150, 0),
    _offer('cheap', 300, 240, 1),
    _offer('fast', 500, 90, 0),
  ];

  test('cheapest keeps original offers and sorts by total price', () {
    final sorted = offers.sortedBy(FlightOfferSort.cheapest);
    expect(sorted.first.id, 'cheap');
    expect(offers.first.id, 'balanced');
  });

  test('fastest sorts by total itinerary duration', () {
    expect(offers.sortedBy(FlightOfferSort.fastest).first.id, 'fast');
  });

  test('best scoring balances price duration and stops', () {
    expect(offers.sortedBy(FlightOfferSort.best).first.id, 'balanced');
  });
}
