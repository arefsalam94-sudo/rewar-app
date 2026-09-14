import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/car_rental.dart';
import 'car_rental_service.dart';
import 'firebase_bootstrap.dart';

/// Reads the rental catalogue from Firestore (`DATA_MODEL.md` → cars and
/// rental_locations), falling back to [PreviewCarRentalService] when Firebase
/// is unavailable or the live data cannot be loaded.
///
/// Public read, admin-only write (`firestore.rules`).
///
/// ## Price and currency
///
/// A vehicle carries **one authoritative price** in the currency its supplier
/// quotes — `pricePerDay` + `currencyCode`, USD or IQD. Nothing here assumes a
/// currency: a document with no usable `currencyCode` is **rejected** rather
/// than defaulted, because a price shown in the wrong currency is off by a
/// factor of roughly 1300 and is worse than no card at all.
///
/// Conversion to the user's display currency belongs at render time, through
/// `CurrencyRatesService`, and stays indicative — a charge is settled by the
/// payment processor, never at a rate this app stored (SECURITY.md 5).
class FirestoreCarRentalService implements CarRentalService {
  FirestoreCarRentalService({
    FirebaseFirestore? firestore,
    this.fallback = const PreviewCarRentalService(),
  }) : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  /// Serves the bundled preview catalogue on every failure path.
  final CarRentalService fallback;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const String carsCollection = 'cars';
  static const String locationsCollection = 'rental_locations';

  /// The currencies the app can display. Mirrors `firestore.rules`; a vehicle
  /// quoted in anything else is dropped rather than shown wrongly.
  static const List<String> supportedCurrencies = ['USD', 'IQD'];

  /// Card image used until `imageUrls` carries real Storage URLs. The seeded
  /// documents leave that array empty on purpose (SEED_DATA.md).
  static const String fallbackImageAsset = 'assets/images/journey-car.png';

  bool get _live => FirebaseBootstrap.isReady || _firestoreOverride != null;

  // --- CarRentalService --------------------------------------------------

  @override
  Future<List<RentalVehicle>> trendingCars() async {
    if (!_live) return fallback.trendingCars();
    try {
      final cars = await _activeCars();
      if (cars.isEmpty) return await fallback.trendingCars();
      return cars;
    } catch (error) {
      debugPrint('Could not load cars: $error');
      return fallback.trendingCars();
    }
  }

  @override
  Future<List<RentalVehicle>> searchCars(
    CarRentalSearchCriteria criteria,
  ) async {
    if (!_live) return fallback.searchCars(criteria);
    try {
      final cars = await _activeCars();
      if (cars.isEmpty) return await fallback.searchCars(criteria);
      // PreviewCarRentalService returns the whole catalogue for any criteria —
      // pickup branch and dates do not filter inventory until a supplier feed
      // exists. Matched here so the swap changes no visible behaviour.
      return cars;
    } catch (error) {
      debugPrint('Could not search cars: $error');
      return fallback.searchCars(criteria);
    }
  }

  @override
  Future<List<RentalLocation>> searchLocations(String query) async {
    if (!_live) return fallback.searchLocations(query);
    final normalized = query.trim().toLowerCase();
    // Matches PreviewCarRentalService exactly, including the two-character
    // minimum, so the picker behaves identically.
    if (normalized.length < 2) return const [];
    try {
      final branches = await _activeLocations();
      if (branches.isEmpty) return await fallback.searchLocations(query);
      return branches
          .where((location) {
            final haystack = [
              location.name.en,
              location.name.ku,
              location.name.ar,
              location.city.en,
              location.city.ku,
              location.city.ar,
              location.country.en,
              location.airportCode ?? '',
            ].join(' ').toLowerCase();
            return haystack.contains(normalized);
          })
          .toList(growable: false);
    } catch (error) {
      debugPrint('Could not search rental locations: $error');
      return fallback.searchLocations(query);
    }
  }

  // --- reading -----------------------------------------------------------

  /// Every vehicle a customer may see, with its branch resolved.
  ///
  /// `active: false` is filtered here, in one place, so no screen can forget.
  Future<List<RentalVehicle>> _activeCars() async {
    // Branches first: a vehicle whose pickup point cannot be resolved has no
    // location to draw, so it is dropped rather than shown with a blank row.
    final branches = {
      for (final location in await _activeLocations()) location.id: location,
    };
    if (branches.isEmpty) return const [];

    final snapshot = await _firestore
        .collection(carsCollection)
        .where('active', isEqualTo: true)
        .get();

    final out = <RentalVehicle>[];
    for (final doc in snapshot.docs) {
      final vehicle = vehicleFrom(doc.id, doc.data(), branches);
      if (vehicle != null) out.add(vehicle);
    }
    return out;
  }

  Future<List<RentalLocation>> _activeLocations() async {
    final snapshot = await _firestore
        .collection(locationsCollection)
        .where('active', isEqualTo: true)
        .get();
    final out = <RentalLocation>[];
    for (final doc in snapshot.docs) {
      final location = locationFrom(doc.id, doc.data());
      if (location != null) out.add(location);
    }
    return out;
  }

  @visibleForTesting
  static RentalVehicle? vehicleFrom(
    String id,
    Map<String, dynamic> data,
    Map<String, RentalLocation> branches,
  ) {
    final name = _textFrom(data['name']);
    if (name == null) return null;

    // A price with no supported currency is not shown at all. Defaulting to
    // USD would misprice an IQD vehicle by roughly 1300x.
    final currency = data['currencyCode'];
    if (currency is! String || !supportedCurrencies.contains(currency)) {
      debugPrint('cars/$id has unsupported currency "$currency" — skipped.');
      return null;
    }
    final price = data['pricePerDay'];
    if (price is! num || price < 0) {
      debugPrint('cars/$id has a bad pricePerDay — skipped.');
      return null;
    }

    final location = branches[data['locationId']];
    if (location == null) {
      debugPrint('cars/$id points at an unknown branch — skipped.');
      return null;
    }

    final company = data['company'];
    final companyName = company is Map ? _textFrom(company['name']) : null;
    if (company is! Map || companyName == null) return null;

    final images = _stringList(data['imageUrls']);

    return RentalVehicle(
      id: id,
      name: name,
      modelYear: _int(data['year']),
      company: RentalCompany(
        id: company['id'] is String ? company['id'] as String : id,
        name: companyName,
      ),
      images: images.isEmpty ? const [fallbackImageAsset] : images,
      passengers: _int(data['capacity']),
      bags: _int(data['bags']),
      powertrain: _enum(
        RentalPowertrain.values,
        data['fuelType'],
        RentalPowertrain.petrol,
      ),
      transmission: _enum(
        RentalTransmission.values,
        data['transmission'],
        RentalTransmission.automatic,
      ),
      airConditioning: data['hasAC'] == true,
      paymentOption: _enum(
        RentalPaymentOption.values,
        data['paymentInfo'],
        RentalPaymentOption.payAtPickup,
      ),
      location: location,
      dailyPrice: price.toDouble(),
      currencyCode: currency,
      featured: data['featured'] == true,
      extras: _extrasFrom(data['extras']),
      // `conditions` is absent from every seeded vehicle on purpose: supplier
      // terms are contractual and are never invented for review data. An empty
      // RentalConditions hides the Rental Conditions card.
      conditions: _conditionsFrom(data['conditions']),
    );
  }

  @visibleForTesting
  static RentalLocation? locationFrom(String id, Map<String, dynamic> data) {
    final name = _textFrom(data['name']);
    final city = _textFrom(data['city']);
    final country = _textFrom(data['country']);
    if (name == null || city == null || country == null) return null;
    final point = data['location'];
    if (point is! GeoPoint) return null;
    return RentalLocation(
      id: id,
      name: name,
      city: city,
      country: country,
      airportCode: data['airportCode'] is String
          ? data['airportCode'] as String
          : null,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  static List<RentalExtra> _extrasFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <RentalExtra>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = _textFrom(item['name']);
      final id = item['id'];
      final price = item['pricePerDay'];
      if (name == null || id is! String || price is! num) continue;
      out.add(
        RentalExtra(
          id: id,
          name: name,
          pricePerDay: price.toDouble(),
          selection: _enum(
            RentalExtraSelection.values,
            item['selection'],
            RentalExtraSelection.checkbox,
          ),
          minQuantity: _int(item['minQuantity']),
          maxQuantity: item['maxQuantity'] is num
              ? (item['maxQuantity'] as num).toInt()
              : 1,
        ),
      );
    }
    return out;
  }

  static RentalConditions _conditionsFrom(Object? raw) {
    if (raw is! Map) return const RentalConditions();
    // Every key is optional and each absent one hides its row, so a supplier
    // that published nothing shows nothing rather than a default to act on.
    final mileage = raw['mileagePolicy'];
    final deadline = raw['freeCancellationUntil'];
    return RentalConditions(
      fuelPolicy: _enumOrNull(RentalFuelPolicy.values, raw['fuelPolicy']),
      mileagePolicy: mileage is Map
          ? RentalMileagePolicy(
              unlimited: mileage['unlimited'] == true,
              kilometresPerDay: mileage['kilometresPerDay'] is num
                  ? (mileage['kilometresPerDay'] as num).toInt()
                  : null,
              extraKilometrePrice: mileage['extraKilometrePrice'] is num
                  ? (mileage['extraKilometrePrice'] as num).toDouble()
                  : null,
            )
          : null,
      depositAmount: raw['depositAmount'] is num
          ? (raw['depositAmount'] as num).toDouble()
          : null,
      damageExcess: raw['damageExcess'] is num
          ? (raw['damageExcess'] as num).toDouble()
          : null,
      freeCancellationUntil: deadline is Timestamp ? deadline.toDate() : null,
      minimumDriverAge: raw['minimumDriverAge'] is num
          ? (raw['minimumDriverAge'] as num).toInt()
          : null,
      requiredDocuments: [
        for (final item
            in (raw['requiredDocuments'] is List
                ? raw['requiredDocuments'] as List
                : const []))
          ?_textFrom(item),
      ],
      guaranteedModel: raw['guaranteedModel'] is bool
          ? raw['guaranteedModel'] as bool
          : null,
    );
  }

  // --- primitives --------------------------------------------------------

  static RentalText? _textFrom(Object? raw) {
    if (raw is! Map) return null;
    final en = raw['en'];
    if (en is! String || en.trim().isEmpty) return null;
    // A missing locale falls back to English, the same rule as every other
    // catalog collection.
    return RentalText(
      en: en,
      ku: raw['ku'] is String ? raw['ku'] as String : en,
      ar: raw['ar'] is String ? raw['ar'] as String : en,
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String) item,
    ];
  }

  static int _int(Object? raw) => raw is num ? raw.toInt() : 0;

  static T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) =>
      _enumOrNull(values, raw) ?? fallback;

  static T? _enumOrNull<T extends Enum>(List<T> values, Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
