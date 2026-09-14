import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/car_rental.dart';
import '../screens/explore_tours_screen.dart' show formatMoney;
import '../services/currency_rates_service.dart';
import '../services/device_location_service.dart';
import '../theme/app_colors.dart';
import 'app_liquid_glass.dart';
import 'liquid_glass_surface.dart';

/// Building blocks shared by the Car Rental page's card and the Car Rental
/// Results page's card, so the two layouts stay visually identical while
/// arranging the same pieces differently.

/// Standalone-icon family (`Design_system_CANONICAL.md` §13): stroke-only
/// ring, transparent center, `icon-accent` glyph — no filled circle. Used
/// for facilities, payment, and location. Replaces the legacy filled
/// `statusInfoFill`/`statusSuccessFill` treatment, which rendered every Car
/// Rental icon as a solid blue- or green-tinted disc.
class RentalCircleIcon extends StatelessWidget {
  const RentalCircleIcon({super.key, required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Icon(icon, color: accent, size: size * 0.56),
    );
  }
}

/// One "icon + label" facility item (persons, powertrain, bags, AC).
class RentalFacility extends StatelessWidget {
  const RentalFacility({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize = 30,
    this.fontSize = 11,
    this.gap = 4,
  });

  final IconData icon;
  final String label;
  final double iconSize;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      RentalCircleIcon(icon: icon, size: iconSize),
      SizedBox(width: gap),
      Flexible(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: fontSize,
          ),
        ),
      ),
    ],
  );
}

/// Rounded glass badge carrying the rental company icon and name.
///
/// The circular icon container is kept even when a company has no logo yet —
/// the generic car glyph is the fallback.
class RentalCompanyBadge extends StatelessWidget {
  const RentalCompanyBadge({
    super.key,
    required this.company,
    this.maxWidth = 180,
    this.iconSize = 36,
    this.fontSize,
    this.borderRadius = 24,
    this.padding = const EdgeInsetsDirectional.fromSTEB(6, 5, 12, 5),
    this.gap = 8,
    this.layer = GlassLayer.surface,
  });

  final RentalCompany company;
  final double maxWidth;
  final double iconSize;
  final double? fontSize;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double gap;

  /// [GlassLayer.surface] (default) for standalone use, such as floating
  /// over the featured carousel photo. [GlassLayer.embedded] when nested
  /// inside another visible canonical glass surface (a car card), so the
  /// two don't stack into a second shader.
  final GlassLayer layer;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final name = company.name.forLanguage(language);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AppLiquidGlass(
        useCanonicalGlass: true,
        layer: layer,
        borderRadius: borderRadius,
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RentalCircleIcon(icon: Icons.directions_car, size: iconSize),
            SizedBox(width: gap),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vehicle photo with a loading placeholder and an error fallback, so a
/// missing or slow image never leaves a blank hole in the card.
class RentalVehicleImage extends StatelessWidget {
  const RentalVehicleImage({super.key, required this.asset, this.cacheWidth});

  final String asset;

  /// Decode budget — result cards only need a thumbnail, never the full frame.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: BoxFit.cover,
    cacheWidth: cacheWidth,
    frameBuilder: (context, child, frame, synchronous) =>
        frame != null || synchronous ? child : _placeholder(context, 48),
    errorBuilder: (_, _, _) => _placeholder(context, 52),
  );

  Widget _placeholder(BuildContext context, double size) => ColoredBox(
    color: AppColors.glassBaseTint(context).withValues(alpha: 0.25),
    child: Icon(
      Icons.directions_car_outlined,
      size: size,
      color: AppColors.accent(context),
    ),
  );
}

/// Glass price pill. The amount carries the emphasis; the rental period unit
/// is rendered smaller and secondary, as in the approved design.
class RentalPriceBadge extends StatelessWidget {
  const RentalPriceBadge({
    super.key,
    required this.vehicle,
    this.amountFontSize = 22,
    this.unitFontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.layer = GlassLayer.embedded,
  });

  final RentalVehicle vehicle;
  final double amountFontSize;
  final double unitFontSize;
  final EdgeInsetsGeometry padding;

  /// [GlassLayer.embedded] (default) — every current call site sits nested
  /// inside a car card's own visible canonical glass surface. Pass
  /// [GlassLayer.surface] if a future call site needs to float standalone.
  final GlassLayer layer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final amount = rentalPriceAmount(vehicle);
    // `carPricePerDay` owns the separator and the localized period word, so
    // splitting on the amount keeps the two type sizes without hard-coding
    // "/day" anywhere in the widget layer.
    final full = l10n.carPricePerDay(amount);
    final unit = full.replaceFirst(amount, '');
    return AppLiquidGlass(
      useCanonicalGlass: true,
      layer: layer,
      borderRadius: 16,
      padding: padding,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: amount,
              style: TextStyle(
                color: AppColors.heading(context),
                fontSize: amountFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: unit,
              style: TextStyle(
                color: AppColors.secondaryTextV3(context),
                fontSize: unitFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        // Currency amounts read left-to-right even inside an RTL layout.
        textDirection: TextDirection.ltr,
        maxLines: 1,
      ),
    );
  }
}

/// Converts a vehicle's stored price into the currency the user chose in
/// Settings, using the live `currency_rates` table.
///
/// A vehicle stores **one authoritative price** in its supplier's currency
/// (`pricePerDay` + `currencyCode`, DATA_MODEL.md). Nothing is duplicated in
/// Firestore; the conversion happens here, at render time.
///
/// Mirrors `TourPricing` in `explore_tours_screen.dart` deliberately, and
/// reuses its `formatMoney`, so a price on a car card and the same figure at
/// checkout cannot be formatted two different ways.
///
/// Conversions are **indicative**, never a quote: a charge is settled by the
/// payment processor in the operator's own currency, never at a rate this app
/// stored (SECURITY.md 5). That is what the `≈` prefix discloses.
class RentalPricing {
  const RentalPricing({required this.rates, required this.displayCurrency});

  /// No rate table — every price renders in its own stored currency. This is
  /// the honest state before `currency_rates/latest` has loaded.
  static const RentalPricing unconverted = RentalPricing(
    rates: CurrencyRates.empty,
    displayCurrency: '',
  );

  final CurrencyRates rates;

  /// The ISO code the user chose in Settings (`users.preferredCurrency`).
  final String displayCurrency;

  /// Whether a price quoted in [currency] would actually be converted — false
  /// when it already matches the display currency, and false when the rate
  /// table cannot do it.
  bool isConverted(String currency) {
    if (displayCurrency.isEmpty) return false;
    if (currency.toUpperCase() == displayCurrency.toUpperCase()) return false;
    return rates.convert(1, from: currency, to: displayCurrency) != null;
  }

  /// A vehicle's daily rate as drawn, e.g. `$56` or `≈ IQD 73,360`.
  String perDay(RentalVehicle vehicle) =>
      format(vehicle.dailyPrice, vehicle.currencyCode);

  /// Any amount in [currency], converted for display when possible.
  ///
  /// Falls back to the stored currency whenever the conversion cannot be made
  /// — an unconverted true price beats a converted invented one.
  String format(num amount, String currency) {
    if (!isConverted(currency)) return formatMoney(amount, currency);
    final converted = rates.convert(
      amount,
      from: currency,
      to: displayCurrency,
    );
    if (converted == null) return formatMoney(amount, currency);
    return '≈ ${formatMoney(converted, displayCurrency)}';
  }
}

/// Formats the structured `dailyPrice` + `currencyCode` pair into a symbol and
/// amount. Symbols longer than one character are spaced off the number, which
/// covers the codes rendered as words in the rates table.
String rentalPriceAmount(RentalVehicle vehicle, [RentalPricing? pricing]) {
  // With a rate table and a chosen display currency, render in that currency.
  if (pricing != null) return pricing.perDay(vehicle);
  final symbol = CurrencyRatesService.symbolFor(vehicle.currencyCode);
  final amount = vehicle.dailyPrice == vehicle.dailyPrice.roundToDouble()
      ? vehicle.dailyPrice.toStringAsFixed(0)
      : vehicle.dailyPrice.toStringAsFixed(2);
  return symbol.length == 1 ? '$symbol$amount' : '$symbol $amount';
}

String rentalPowertrainLabel(
  AppLocalizations l10n,
  RentalPowertrain powertrain,
) => switch (powertrain) {
  RentalPowertrain.hybrid => l10n.carHybrid,
  RentalPowertrain.electric => l10n.carElectric,
  RentalPowertrain.petrol => l10n.carPetrol,
  RentalPowertrain.diesel => l10n.carDiesel,
};

IconData rentalPowertrainIcon(RentalPowertrain powertrain) =>
    switch (powertrain) {
      RentalPowertrain.hybrid || RentalPowertrain.electric => Icons.bolt,
      RentalPowertrain.petrol || RentalPowertrain.diesel => Icons.water_drop,
    };

String rentalPaymentLabel(AppLocalizations l10n, RentalPaymentOption option) =>
    switch (option) {
      RentalPaymentOption.payAtPickup => l10n.carPayAtPickup,
      RentalPaymentOption.payNow => l10n.carPayNow,
    };

/// The distance between the device and a rental branch, or `null` when the
/// device position is unknown (services off, permission denied, no fix). The
/// caller then hides the row rather than inventing a number.
String? rentalDistanceText(RentalLocation location, DeviceLocation? device) {
  if (device == null) return null;
  final meters = location.distanceMetersFrom(device.latitude, device.longitude);
  return meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Formats a bare amount with its currency symbol, using the same rules as
/// [rentalPriceAmount] — whole numbers lose the decimals, and a multi-character
/// symbol is spaced off the number.
String rentalFormatAmount(double amount, String currencyCode) {
  final symbol = CurrencyRatesService.symbolFor(currencyCode);
  final text = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return symbol.length == 1 ? '$symbol$text' : '$symbol $text';
}

String rentalTransmissionLabel(
  AppLocalizations l10n,
  RentalTransmission transmission,
) => switch (transmission) {
  RentalTransmission.automatic => l10n.carAutomatic,
  RentalTransmission.manual => l10n.carManual,
};

IconData rentalTransmissionIcon(RentalTransmission transmission) =>
    switch (transmission) {
      RentalTransmission.automatic => Icons.auto_mode,
      RentalTransmission.manual => Icons.settings,
    };

String rentalFuelPolicyLabel(AppLocalizations l10n, RentalFuelPolicy policy) =>
    switch (policy) {
      RentalFuelPolicy.fullToFull => l10n.carFuelFullToFull,
      RentalFuelPolicy.fullToEmpty => l10n.carFuelFullToEmpty,
      RentalFuelPolicy.sameToSame => l10n.carFuelSameToSame,
    };
