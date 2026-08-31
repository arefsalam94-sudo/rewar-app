import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/hotel.dart';
import '../models/hotel_detail.dart';
import '../services/currency_rates_service.dart';
import '../theme/app_colors.dart';
import 'glass_panel.dart';

class HotelCircleIcon extends StatelessWidget {
  const HotelCircleIcon({super.key, required this.icon, this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.statusInfoFill(context),
      border: Border.all(
        color: AppColors.accent(context).withValues(alpha: .7),
      ),
    ),
    child: Icon(
      icon,
      size: size * .54,
      color: AppColors.statusInfoContent(context),
    ),
  );
}

class HotelImage extends StatelessWidget {
  const HotelImage({super.key, required this.asset, this.cacheWidth});

  final String asset;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: BoxFit.cover,
    cacheWidth: cacheWidth,
    frameBuilder: (context, child, frame, synchronous) =>
        frame != null || synchronous ? child : _placeholder(context),
    errorBuilder: (_, _, _) => _placeholder(context),
  );

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: AppColors.glassBaseTint(context).withValues(alpha: .22),
    child: Icon(
      Icons.hotel_outlined,
      size: 48,
      color: AppColors.accent(context),
    ),
  );
}

class HotelStars extends StatelessWidget {
  const HotelStars({super.key, required this.rating, this.compact = false});

  final int rating;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).hotelStarClassification(rating),
    child: ExcludeSemantics(
      child: GlassPanel(
        depth: GlassDepth.top,
        borderRadius: 18,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 11,
          vertical: compact ? 5 : 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: AppColors.accent(context),
              size: compact ? 14 : 18,
            ),
          ),
        ),
      ),
    ),
  );
}

class HotelReviewBadge extends StatelessWidget {
  const HotelReviewBadge({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).hotelReviewScore(score),
    child: GlassPanel(
      depth: GlassDepth.top,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Text(
        score.toStringAsFixed(1),
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: AppColors.heading(context),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// Compact score-and-stars treatment shared visually with Explore Nature.
class HotelCompactRatingPair extends StatelessWidget {
  const HotelCompactRatingPair({
    super.key,
    required this.score,
    required this.starRating,
  });

  final double score;
  final int starRating;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: AppLocalizations.of(context).hotelReviewScore(score),
          child: _HotelCompactRatingShell(
            child: Text(
              score.toStringAsFixed(1),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: AppLocalizations.of(
            context,
          ).hotelStarClassification(starRating),
          child: ExcludeSemantics(
            child: _HotelCompactRatingShell(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < 5; index++)
                    Padding(
                      padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
                      child: Icon(
                        index < starRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 15,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HotelCompactRatingShell extends StatelessWidget {
  const _HotelCompactRatingShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = dark ? AppColors.darkOnPrimary : AppColors.actionNavy;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.luminousMint
            : AppColors.pageGradientTop.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: content),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: content),
        child: IconTheme(
          data: IconThemeData(color: content),
          child: child,
        ),
      ),
    );
  }
}

IconData hotelAmenityIcon(HotelAmenity amenity) => switch (amenity) {
  HotelAmenity.pool => Icons.pool,
  HotelAmenity.bar => Icons.local_bar_outlined,
  HotelAmenity.restaurant => Icons.restaurant_outlined,
  HotelAmenity.gym => Icons.fitness_center,
  HotelAmenity.parking => Icons.local_parking,
  HotelAmenity.wifi => Icons.wifi,
  HotelAmenity.beach => Icons.beach_access_outlined,
};

String hotelAmenityLabel(AppLocalizations l10n, HotelAmenity amenity) =>
    switch (amenity) {
      HotelAmenity.pool => l10n.hotelPool,
      HotelAmenity.bar => l10n.hotelBar,
      HotelAmenity.restaurant => l10n.hotelRestaurant,
      HotelAmenity.gym => l10n.hotelGym,
      HotelAmenity.parking => l10n.hotelParking,
      HotelAmenity.wifi => l10n.hotelFreeWifi,
      HotelAmenity.beach => l10n.hotelBeach,
    };

String formatHotelPrice(Hotel hotel) {
  final symbol = CurrencyRatesService.symbolFor(hotel.currencyCode);
  final value = hotel.pricePerNight == hotel.pricePerNight.roundToDouble()
      ? hotel.pricePerNight.toStringAsFixed(0)
      : hotel.pricePerNight.toStringAsFixed(2);
  return symbol.length == 1 ? '$symbol$value' : '$symbol $value';
}

/// Resolves a [HotelFacility.iconKey] to a glyph.
///
/// The keys are data, so an unrecognised one is expected rather than
/// exceptional: it falls back to a neutral check mark. Inventing a glyph for
/// an unknown facility would describe the facility wrongly.
IconData hotelFacilityIcon(String iconKey) => switch (iconKey) {
  'pool' => Icons.pool_outlined,
  'breakfast' => Icons.free_breakfast_outlined,
  'airportShuttle' => Icons.airplanemode_active_outlined,
  'wifi' => Icons.wifi_rounded,
  'frontDesk' => Icons.support_agent_outlined,
  'parking' => Icons.local_parking_outlined,
  'restaurant' => Icons.restaurant_outlined,
  'bar' => Icons.local_bar_outlined,
  'gym' => Icons.fitness_center_outlined,
  'spa' => Icons.spa_outlined,
  'airConditioning' => Icons.ac_unit_outlined,
  'familyRooms' => Icons.family_restroom_outlined,
  'accessible' => Icons.accessible_outlined,
  'meetingRooms' => Icons.groups_outlined,
  'security' => Icons.shield_outlined,
  'smartTech' => Icons.devices_outlined,
  'cityView' => Icons.location_city_outlined,
  'lounge' => Icons.local_bar_outlined,
  'laundry' => Icons.local_laundry_service_outlined,
  'roomService' => Icons.room_service_outlined,
  'elevator' => Icons.elevator_outlined,
  'petFriendly' => Icons.pets_outlined,
  'nonSmoking' => Icons.smoke_free_outlined,
  _ => Icons.check_rounded,
};

String hotelFacilityCategoryLabel(
  AppLocalizations l10n,
  HotelFacilityCategory category,
) => switch (category) {
  HotelFacilityCategory.general => l10n.hotelFacilityGeneral,
  HotelFacilityCategory.internet => l10n.hotelFacilityInternet,
  HotelFacilityCategory.parking => l10n.hotelFacilityParking,
  HotelFacilityCategory.foodAndDrink => l10n.hotelFacilityFoodAndDrink,
  HotelFacilityCategory.wellness => l10n.hotelFacilityWellness,
  HotelFacilityCategory.pool => l10n.hotelFacilityPool,
  HotelFacilityCategory.transportation => l10n.hotelFacilityTransportation,
  HotelFacilityCategory.roomFacilities => l10n.hotelFacilityRoom,
  HotelFacilityCategory.family => l10n.hotelFacilityFamily,
  HotelFacilityCategory.accessibility => l10n.hotelFacilityAccessibility,
  HotelFacilityCategory.business => l10n.hotelFacilityBusiness,
  HotelFacilityCategory.safety => l10n.hotelFacilitySafety,
};

IconData hotelReviewCategoryIcon(HotelReviewCategory category) =>
    switch (category) {
      HotelReviewCategory.location => Icons.place_outlined,
      HotelReviewCategory.cleanliness => Icons.cleaning_services_outlined,
      HotelReviewCategory.comfort => Icons.chair_outlined,
      HotelReviewCategory.service => Icons.room_service_outlined,
      HotelReviewCategory.value => Icons.savings_outlined,
      HotelReviewCategory.facilities => Icons.apartment_outlined,
      HotelReviewCategory.wifi => Icons.wifi_rounded,
    };

String hotelReviewCategoryLabel(
  AppLocalizations l10n,
  HotelReviewCategory category,
) => switch (category) {
  HotelReviewCategory.location => l10n.hotelLocation,
  HotelReviewCategory.cleanliness => l10n.hotelCleanliness,
  HotelReviewCategory.comfort => l10n.hotelComfort,
  HotelReviewCategory.service => l10n.hotelService,
  HotelReviewCategory.value => l10n.hotelValue,
  HotelReviewCategory.facilities => l10n.hotelFacilities,
  HotelReviewCategory.wifi => l10n.hotelFreeWifi,
};

IconData nearbyPlaceIcon(NearbyPlaceType type) => switch (type) {
  NearbyPlaceType.landmark => Icons.account_balance_outlined,
  NearbyPlaceType.park => Icons.park_outlined,
  NearbyPlaceType.mall => Icons.storefront_outlined,
  NearbyPlaceType.transport => Icons.directions_bus_outlined,
  NearbyPlaceType.airport => Icons.flight_outlined,
  NearbyPlaceType.restaurant => Icons.restaurant_outlined,
  NearbyPlaceType.atm => Icons.atm_outlined,
  NearbyPlaceType.hospital => Icons.local_hospital_outlined,
  NearbyPlaceType.other => Icons.place_outlined,
};

String hotelBedTypeLabel(AppLocalizations l10n, BedType type) => switch (type) {
  BedType.single => l10n.hotelBedSingle,
  BedType.twin => l10n.hotelBedTwin,
  BedType.doubleBed => l10n.hotelBedDouble,
  BedType.queen => l10n.hotelBedQueen,
  BedType.king => l10n.hotelBedKing,
  BedType.sofa => l10n.hotelBedSofa,
  BedType.bunk => l10n.hotelBedBunk,
};

String hotelBedConfigurationLabel(
  AppLocalizations l10n,
  BedConfiguration bed,
) => l10n.hotelBedCount(bed.count, hotelBedTypeLabel(l10n, bed.type));

String hotelBreakfastLabel(AppLocalizations l10n, BreakfastPolicy policy) =>
    switch (policy) {
      BreakfastPolicy.included => l10n.hotelBreakfastIncluded,
      BreakfastPolicy.extra => l10n.hotelBreakfastExtra,
      BreakfastPolicy.unavailable => l10n.hotelBreakfastUnavailable,
    };

String hotelCancellationLabel(AppLocalizations l10n, CancellationType type) =>
    switch (type) {
      CancellationType.free => l10n.hotelFreeCancellation,
      CancellationType.partial => l10n.hotelPartiallyRefundable,
      CancellationType.nonRefundable => l10n.hotelNonRefundable,
    };

String hotelPrepaymentLabel(AppLocalizations l10n, PrepaymentType type) =>
    switch (type) {
      PrepaymentType.none => l10n.hotelNoPrepayment,
      PrepaymentType.partial => l10n.hotelPartialPrepayment,
      PrepaymentType.full => l10n.hotelPrepaymentRequired,
    };

String hotelPaymentTimingLabel(AppLocalizations l10n, PaymentTiming timing) =>
    switch (timing) {
      PaymentTiming.payNow => l10n.hotelPayNow,
      PaymentTiming.payLater => l10n.hotelPayLater,
      PaymentTiming.payAtProperty => l10n.hotelPayAtProperty,
    };

/// One `−  value  +` row, used by the Where to Stay guests panel and by the
/// detail page's Change sheet.
///
/// Lifted out of `hotel_screen.dart` when the Change sheet needed the same
/// control, rather than drawing a second stepper that would drift from it.
class HotelCounterRow extends StatelessWidget {
  const HotelCounterRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.minimum,
    required this.controlKey,
    required this.onChanged,
    this.maximum,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final int minimum;

  /// Upper bound, when the occupancy rules impose one. Null means the
  /// control has no known ceiling — it does not invent one.
  final int? maximum;

  final String controlKey;
  final ValueChanged<int> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          HotelCircleIcon(icon: icon, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    style: TextStyle(
                      color: AppColors.heading(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '················',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                ),
              ],
            ),
          ),
          HotelCounterButton(
            key: ValueKey('$controlKey-decrease'),
            icon: Icons.remove,
            enabled: value > minimum,
            semanticLabel: l10n.hotelDecrease(label),
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: AppColors.heading(context), fontSize: 18),
            ),
          ),
          HotelCounterButton(
            key: ValueKey('$controlKey-increase'),
            icon: Icons.add,
            enabled: maximum == null || value < maximum!,
            semanticLabel: l10n.hotelIncrease(label),
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class HotelCounterButton extends StatelessWidget {
  const HotelCounterButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: semanticLabel,
    child: Opacity(
      opacity: enabled ? 1 : .4,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 24,
        child: HotelCircleIcon(icon: icon, size: 38),
      ),
    ),
  );
}
