import 'airport.dart';
import 'booking.dart';

enum FlightTripType { oneWay, roundTrip }

/// The validated values produced by the Flight Ticketing search form.
///
/// Search criteria are transient UI state. They deliberately do not belong in
/// Firestore; a future results screen/provider can receive this object directly.
class FlightSearchCriteria {
  const FlightSearchCriteria({
    required this.tripType,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.adults,
    required this.children,
    required this.infants,
    required this.cabinClass,
    required this.directFlightsOnly,
    this.returnDate,
  });

  final FlightTripType tripType;
  final Airport origin;
  final Airport destination;
  final DateTime departureDate;
  final DateTime? returnDate;
  final int adults;
  final int children;
  final int infants;
  final CabinClass cabinClass;
  final bool directFlightsOnly;

  int get passengerCount => adults + children + infants;

  FlightSearchCriteria copyWith({
    DateTime? departureDate,
    DateTime? returnDate,
  }) => FlightSearchCriteria(
    tripType: tripType,
    origin: origin,
    destination: destination,
    departureDate: departureDate ?? this.departureDate,
    returnDate: returnDate ?? this.returnDate,
    adults: adults,
    children: children,
    infants: infants,
    cabinClass: cabinClass,
    directFlightsOnly: directFlightsOnly,
  );
}
