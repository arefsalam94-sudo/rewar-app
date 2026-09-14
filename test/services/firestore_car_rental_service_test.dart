import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/car_rental.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/firestore_car_rental_service.dart';

const _branchId = 'preview-erbil-airport';

final _branch = RentalLocation(
  id: _branchId,
  name: const RentalText(
    en: 'Erbil International Airport',
    ku: 'فڕۆکەخانە',
    ar: 'مطار',
  ),
  city: const RentalText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
  country: const RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
  airportCode: 'EBL',
  latitude: 36.23,
  longitude: 43.96,
);

final _branches = {_branchId: _branch};

Map<String, dynamic> carDoc({
  Object? currencyCode = 'USD',
  Object? pricePerDay = 56,
  Object? locationId = _branchId,
  Map<String, dynamic> extra = const {},
}) => {
  'name': const {'en': 'Tesla Model 3', 'ku': 'تێسلا', 'ar': 'تسلا'},
  'year': 2024,
  'company': const {
    'id': 'abc-cars',
    'name': {'en': 'ABC Cars'},
  },
  'imageUrls': <String>[],
  'capacity': 5,
  'fuelType': 'electric',
  'bags': 2,
  'hasAC': true,
  'paymentInfo': 'payAtPickup',
  'locationId': locationId,
  'pricePerDay': pricePerDay,
  'currencyCode': currencyCode,
  'featured': true,
  'active': true,
  'transmission': 'automatic',
  'extras': const <Object?>[],
  ...extra,
};

void main() {
  group('vehicleFrom — the revised schema', () {
    test('maps the documented field names onto the Dart model', () {
      final car = FirestoreCarRentalService.vehicleFrom(
        'tesla',
        carDoc(),
        _branches,
      );

      expect(car, isNotNull);
      expect(car!.id, 'tesla');
      expect(car.name.en, 'Tesla Model 3');
      expect(car.modelYear, 2024);
      // year -> modelYear, capacity -> passengers, hasAC -> airConditioning
      expect(car.passengers, 5);
      expect(car.airConditioning, isTrue);
      expect(car.powertrain, RentalPowertrain.electric);
      expect(car.transmission, RentalTransmission.automatic);
      expect(car.paymentOption, RentalPaymentOption.payAtPickup);
      expect(car.featured, isTrue);
    });

    test('the company map becomes a localized RentalCompany', () {
      // The old flat rentalCompany/companyTag pair could not carry this.
      final car = FirestoreCarRentalService.vehicleFrom('t', carDoc(), _branches);
      expect(car!.company.id, 'abc-cars');
      expect(car.company.name.en, 'ABC Cars');
      expect(car.company.name.ku, 'ABC Cars', reason: 'missing locale -> en');
    });

    test('locationId resolves to the full branch', () {
      final car = FirestoreCarRentalService.vehicleFrom('t', carDoc(), _branches);
      expect(car!.location.id, _branchId);
      expect(car.location.airportCode, 'EBL');
      expect(car.location.city.en, 'Erbil');
    });

    test('a car pointing at an unknown branch is dropped, not half-drawn', () {
      expect(
        FirestoreCarRentalService.vehicleFrom(
          't',
          carDoc(locationId: 'nowhere'),
          _branches,
        ),
        isNull,
      );
    });

    test('an empty imageUrls falls back to the bundled asset', () {
      final car = FirestoreCarRentalService.vehicleFrom('t', carDoc(), _branches);
      expect(car!.images, [FirestoreCarRentalService.fallbackImageAsset]);
    });

    test('conditions are empty when the document has none', () {
      // Supplier terms are never invented; the Rental Conditions card hides.
      final car = FirestoreCarRentalService.vehicleFrom('t', carDoc(), _branches);
      expect(car!.conditions.fuelPolicy, isNull);
      expect(car.conditions.depositAmount, isNull);
      expect(car.conditions.requiredDocuments, isEmpty);
    });
  });

  group('currency — never assumed, never defaulted', () {
    test('a USD vehicle keeps its own price and code', () {
      final car = FirestoreCarRentalService.vehicleFrom(
        't',
        carDoc(currencyCode: 'USD', pricePerDay: 56),
        _branches,
      );
      expect(car!.currencyCode, 'USD');
      expect(car.dailyPrice, 56);
    });

    test('an IQD vehicle keeps ITS own price and code', () {
      // The whole point: 85000 IQD must not be read as 85000 USD, nor
      // converted at store time.
      final car = FirestoreCarRentalService.vehicleFrom(
        't',
        carDoc(currencyCode: 'IQD', pricePerDay: 85000),
        _branches,
      );
      expect(car!.currencyCode, 'IQD');
      expect(car.dailyPrice, 85000);
    });

    for (final bad in ['EUR', 'GBP', 'usd', '', 'BTC']) {
      test('a vehicle priced in "$bad" is dropped rather than shown', () {
        // Defaulting to USD would misprice by roughly 1300x against IQD.
        expect(
          FirestoreCarRentalService.vehicleFrom(
            't',
            carDoc(currencyCode: bad),
            _branches,
          ),
          isNull,
        );
      });
    }

    test('a missing or non-string currency is dropped', () {
      expect(
        FirestoreCarRentalService.vehicleFrom('t', carDoc(currencyCode: null), _branches),
        isNull,
      );
      expect(
        FirestoreCarRentalService.vehicleFrom('t', carDoc(currencyCode: 1), _branches),
        isNull,
      );
    });

    test('a non-numeric or negative price is dropped', () {
      expect(
        FirestoreCarRentalService.vehicleFrom('t', carDoc(pricePerDay: '56'), _branches),
        isNull,
      );
      expect(
        FirestoreCarRentalService.vehicleFrom('t', carDoc(pricePerDay: -1), _branches),
        isNull,
      );
    });

    test('there are no duplicate converted price fields to drift', () {
      // A vehicle stores ONE authoritative price; priceUSD/priceIQD are not
      // part of the schema and are ignored if somehow present.
      final car = FirestoreCarRentalService.vehicleFrom(
        't',
        carDoc(currencyCode: 'IQD', pricePerDay: 85000, extra: {
          'priceUSD': 65,
        }),
        _branches,
      );
      expect(car!.dailyPrice, 85000);
      expect(car.currencyCode, 'IQD');
    });
  });

  group('extras', () {
    test('are mapped with their selection mode and ceiling', () {
      final car = FirestoreCarRentalService.vehicleFrom(
        't',
        carDoc(extra: {
          'extras': [
            {
              'id': 'gps',
              'name': {'en': 'GPS'},
              'pricePerDay': 5,
              'selection': 'quantity',
              'minQuantity': 0,
              'maxQuantity': 3,
            },
          ],
        }),
        _branches,
      );
      final gps = car!.extras.single;
      expect(gps.id, 'gps');
      expect(gps.pricePerDay, 5);
      expect(gps.selection, RentalExtraSelection.quantity);
      expect(gps.maxQuantity, 3);
    });

    test('a malformed extra is skipped rather than blanking the list', () {
      final car = FirestoreCarRentalService.vehicleFrom(
        't',
        carDoc(extra: {
          'extras': [
            {'id': 'good', 'name': {'en': 'Good'}, 'pricePerDay': 5},
            {'id': 'no-price', 'name': {'en': 'Bad'}},
            'not a map',
          ],
        }),
        _branches,
      );
      expect(car!.extras.map((e) => e.id), ['good']);
    });
  });

  group('locationFrom', () {
    test('maps a branch document', () {
      final branch = FirestoreCarRentalService.locationFrom('b', {
        'name': const {'en': 'Erbil International Airport'},
        'city': const {'en': 'Erbil'},
        'country': const {'en': 'Iraq'},
        'airportCode': 'EBL',
        'location': const GeoPoint(36.23, 43.96),
        'active': true,
      });
      expect(branch!.id, 'b');
      expect(branch.airportCode, 'EBL');
      expect(branch.latitude, closeTo(36.23, 1e-9));
    });

    test('a branch with no geopoint is rejected', () {
      expect(
        FirestoreCarRentalService.locationFrom('b', {
          'name': const {'en': 'X'},
          'city': const {'en': 'X'},
          'country': const {'en': 'X'},
        }),
        isNull,
      );
    });

    test('airportCode is optional — city branches have none', () {
      final branch = FirestoreCarRentalService.locationFrom('b', {
        'name': const {'en': 'Dream City'},
        'city': const {'en': 'Erbil'},
        'country': const {'en': 'Iraq'},
        'location': const GeoPoint(36.2, 44.0),
      });
      expect(branch!.airportCode, isNull);
    });
  });

  group('fallback when Firebase is unavailable', () {
    final service = FirestoreCarRentalService();

    test('trending falls back to the preview catalogue', () async {
      final live = await service.trendingCars();
      final preview = await const PreviewCarRentalService().trendingCars();
      expect(live.map((c) => c.id), preview.map((c) => c.id));
    });

    test('search falls back', () async {
      final pickup = DateTime(2027, 8, 22, 10);
      final criteria = CarRentalSearchCriteria(
        pickupLocation: PreviewCarRentalService.erbilAirport,
        dropOffLocation: PreviewCarRentalService.erbilAirport,
        sameLocation: true,
        pickupDateTime: pickup,
        dropOffDateTime: pickup.add(const Duration(days: 2)),
      );
      expect(await service.searchCars(criteria), isNotEmpty);
    });

    test('location search falls back and keeps the 2-character minimum', () async {
      expect(await service.searchLocations('Erbil'), isNotEmpty);
      expect(await service.searchLocations('E'), isEmpty);
    });
  });
}
