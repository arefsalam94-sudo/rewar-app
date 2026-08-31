import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class RentalText {
  const RentalText({required this.en, required this.ku, required this.ar});

  final String en;
  final String ku;
  final String ar;

  String forLanguage(String languageCode) => switch (languageCode) {
    'ku' => ku,
    'ar' => ar,
    _ => en,
  };
}

@immutable
class RentalCompany {
  const RentalCompany({required this.id, required this.name, this.logoAsset});

  final String id;
  final RentalText name;

  /// Supplier logo. Null until a rental provider supplies artwork — the
  /// company badge falls back to the generic car glyph, exactly as it does
  /// today, so a missing logo is never a blank box.
  final String? logoAsset;
}

@immutable
class RentalLocation {
  const RentalLocation({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.airportCode,
  });

  final String id;
  final RentalText name;
  final RentalText city;
  final RentalText country;
  final String? airportCode;
  final double latitude;
  final double longitude;

  double distanceMetersFrom(double latitude, double longitude) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _radians(latitude);
    final lat2 = _radians(this.latitude);
    final deltaLat = _radians(this.latitude - latitude);
    final deltaLon = _radians(this.longitude - longitude);
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

enum RentalPowertrain { hybrid, electric, petrol, diesel }

enum RentalTransmission { automatic, manual }

enum RentalPaymentOption { payAtPickup, payNow }

/// How an add-on is chosen on the Car Rental Details screen: a plain on/off
/// tick, or a stepper with a supplier-imposed ceiling (child seats, extra
/// drivers).
enum RentalExtraSelection { checkbox, quantity }

/// One optional rental add-on offered with a vehicle.
///
/// Deliberately immutable and free of selection state: what the user picked is
/// screen state, not a property of the offer. That keeps the same [RentalExtra]
/// instance shareable across screens and safe to hand straight to a booking
/// request later.
@immutable
class RentalExtra {
  const RentalExtra({
    required this.id,
    required this.name,
    required this.pricePerDay,
    this.selection = RentalExtraSelection.checkbox,
    this.minQuantity = 0,
    this.maxQuantity = 1,
  }) : assert(minQuantity >= 0, 'minQuantity cannot be negative'),
       assert(maxQuantity >= minQuantity, 'maxQuantity is below minQuantity');

  final String id;
  final RentalText name;

  /// Charged per rental day, matching how the approved design labels every
  /// add-on price.
  final double pricePerDay;

  final RentalExtraSelection selection;
  final int minQuantity;

  /// Supplier ceiling — the stepper's `+` disables here, and a checkbox extra
  /// simply leaves this at 1.
  final int maxQuantity;
}

/// How the supplier expects the tank to come back.
enum RentalFuelPolicy { fullToFull, fullToEmpty, sameToSame }

@immutable
class RentalMileagePolicy {
  const RentalMileagePolicy({
    required this.unlimited,
    this.kilometresPerDay,
    this.extraKilometrePrice,
  });

  final bool unlimited;
  final int? kilometresPerDay;
  final double? extraKilometrePrice;
}

/// Supplier terms shown on the Car Rental Details screen.
///
/// **Every field is nullable on purpose.** These are contractual and financial
/// terms — a deposit figure or a cancellation deadline is something a user
/// would act on — so none of them may be invented for review data. Until a
/// rental provider is connected they all stay null, each row hides itself, and
/// the card as a whole disappears via [isEmpty]. This mirrors how
/// `rentalDistanceText` hides the distance line rather than guessing a number
/// when the device has no fix.
@immutable
class RentalConditions {
  const RentalConditions({
    this.fuelPolicy,
    this.mileagePolicy,
    this.depositAmount,
    this.damageExcess,
    this.freeCancellationUntil,
    this.minimumDriverAge,
    this.requiredDocuments = const <RentalText>[],
    this.guaranteedModel,
  });

  final RentalFuelPolicy? fuelPolicy;
  final RentalMileagePolicy? mileagePolicy;
  final double? depositAmount;
  final double? damageExcess;
  final DateTime? freeCancellationUntil;
  final int? minimumDriverAge;
  final List<RentalText> requiredDocuments;

  /// `false` means the supplier guarantees only the category, which is what
  /// renders the "or a similar vehicle" disclaimer. `null` means unknown, and
  /// shows nothing at all.
  final bool? guaranteedModel;

  bool get isEmpty =>
      fuelPolicy == null &&
      mileagePolicy == null &&
      depositAmount == null &&
      damageExcess == null &&
      freeCancellationUntil == null &&
      minimumDriverAge == null &&
      requiredDocuments.isEmpty &&
      guaranteedModel == null;
}

@immutable
class RentalVehicle {
  const RentalVehicle({
    required this.id,
    required this.name,
    required this.modelYear,
    required this.company,
    required this.images,
    required this.passengers,
    required this.bags,
    required this.powertrain,
    required this.transmission,
    required this.airConditioning,
    required this.paymentOption,
    required this.location,
    required this.dailyPrice,
    required this.currencyCode,
    required this.featured,
    this.extras = const <RentalExtra>[],
    this.conditions = const RentalConditions(),
  });

  final String id;
  final RentalText name;
  final int modelYear;
  final RentalCompany company;

  /// Every photo of this vehicle, in display order. The details carousel
  /// renders however many there are — one, five, or a dozen.
  final List<String> images;

  final int passengers;
  final int bags;
  final RentalPowertrain powertrain;
  final RentalTransmission transmission;
  final bool airConditioning;
  final RentalPaymentOption paymentOption;
  final RentalLocation location;
  final double dailyPrice;
  final String currencyCode;
  final bool featured;

  /// Add-ons offered with this vehicle. Per-vehicle rather than a global
  /// catalogue, so two suppliers can offer different extras at different
  /// prices without a schema change.
  final List<RentalExtra> extras;

  final RentalConditions conditions;
}

@immutable
class CarRentalSearchCriteria {
  const CarRentalSearchCriteria({
    required this.pickupLocation,
    required this.dropOffLocation,
    required this.sameLocation,
    required this.pickupDateTime,
    required this.dropOffDateTime,
  });

  final RentalLocation pickupLocation;
  final RentalLocation dropOffLocation;
  final bool sameLocation;
  final DateTime pickupDateTime;
  final DateTime dropOffDateTime;

  /// Chargeable rental days: any started 24-hour period counts as a full day,
  /// and a rental is never shorter than one day. That is the unit the daily
  /// price and every add-on price are quoted in, and the search form already
  /// guarantees drop-off is after pick-up.
  int get rentalDays {
    final minutes = dropOffDateTime.difference(pickupDateTime).inMinutes;
    if (minutes <= 0) return 1;
    return math.max(1, (minutes / (24 * 60)).ceil());
  }
}

/// The money side of a details-screen selection.
///
/// Derived entirely from data already in hand — the vehicle's daily rate, the
/// dates the user searched, and the extras they ticked. Taxes and supplier
/// fees are deliberately absent: we have no source for them, so the screen
/// labels the result an estimate rather than showing an invented breakdown.
@immutable
class RentalQuote {
  const RentalQuote({
    required this.days,
    required this.baseTotal,
    required this.extrasTotal,
    required this.currencyCode,
  });

  factory RentalQuote.forSelection({
    required RentalVehicle vehicle,
    required CarRentalSearchCriteria criteria,
    required Map<String, int> extraQuantities,
  }) {
    final days = criteria.rentalDays;
    var extras = 0.0;
    for (final extra in vehicle.extras) {
      final quantity = extraQuantities[extra.id] ?? 0;
      if (quantity <= 0) continue;
      extras += extra.pricePerDay * quantity * days;
    }
    return RentalQuote(
      days: days,
      baseTotal: vehicle.dailyPrice * days,
      extrasTotal: extras,
      currencyCode: vehicle.currencyCode,
    );
  }

  final int days;
  final double baseTotal;
  final double extrasTotal;
  final String currencyCode;

  double get total => baseTotal + extrasTotal;
}
