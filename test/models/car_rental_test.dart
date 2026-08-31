import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';

void main() {
  test('localized rental text selects all configured languages', () {
    final name = PreviewCarRentalService.vehicles.first.name;

    expect(name.forLanguage('en'), 'Tesla Model 3');
    expect(name.forLanguage('ku'), isNot(name.en));
    expect(name.forLanguage('ar'), isNot(name.en));
    expect(name.forLanguage('fr'), name.en);
  });

  test('rental location calculates a real distance', () {
    final location = PreviewCarRentalService.erbilAirport;

    expect(
      location.distanceMetersFrom(location.latitude, location.longitude),
      closeTo(0, 0.01),
    );
    expect(location.distanceMetersFrom(35.56, 45.31), greaterThan(100000));
  });
}
