import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/car_rental.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/rental_car_parts.dart';
import '../widgets/rental_details_parts.dart';
import 'car_rental_results_screen.dart' show CarRentalSelection;
import 'car_rental_screen.dart' show carRentalBackgroundAsset;

/// Car Rental Details — the car the user picked, the search it came from, and
/// the add-ons they can put on the rental.
///
/// Receives everything it needs in a single [CarRentalSelection], so nothing on
/// this page is re-queried and the user never re-enters a location, date or
/// time. Add-on choices live in this screen's state (a quantity per extra id),
/// which is what a booking request will eventually carry.
class CarRentalDetailsScreen extends StatefulWidget {
  const CarRentalDetailsScreen({
    super.key,
    required this.selection,
    this.onApply,
  });

  final CarRentalSelection selection;

  /// Lets a host screen or a test observe the Apply action. When null, Apply
  /// shows the app's standard Coming Soon snackbar.
  final ValueChanged<CarRentalSelection>? onApply;

  @override
  State<CarRentalDetailsScreen> createState() => _CarRentalDetailsScreenState();
}

class _CarRentalDetailsScreenState extends State<CarRentalDetailsScreen> {
  /// Quantity per extra id. A checkbox extra is 0 or 1; a quantity extra runs
  /// between its own min and max. Absent means zero.
  final Map<String, int> _quantities = <String, int>{};

  RentalVehicle get _vehicle => widget.selection.vehicle;
  CarRentalSearchCriteria get _criteria => widget.selection.criteria;

  @override
  void initState() {
    super.initState();
    // Suppliers can require a minimum on an add-on; honour it as the starting
    // value rather than letting the row open below its own floor.
    for (final extra in _vehicle.extras) {
      if (extra.minQuantity > 0) _quantities[extra.id] = extra.minQuantity;
    }
  }

  void _setQuantity(RentalExtra extra, int value) {
    setState(() {
      _quantities[extra.id] = value.clamp(extra.minQuantity, extra.maxQuantity);
    });
  }

  void _apply() {
    final callback = widget.onApply;
    if (callback != null) {
      callback(widget.selection);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).comingSoon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final quote = RentalQuote.forSelection(
      vehicle: _vehicle,
      criteria: _criteria,
      extraQuantities: _quantities,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: carRentalBackgroundAsset,
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 32),
                children: [
                  RentalImageCarousel(
                    images: _vehicle.images,
                    vehicleName: _vehicle.name.forLanguage(language),
                  ),
                  const SizedBox(height: 14),
                  _CarDetailsCard(vehicle: _vehicle),
                  const SizedBox(height: 14),
                  _PickupDropOffCard(criteria: _criteria),
                  if (_vehicle.extras.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _AdditionalOptionsCard(
                      vehicle: _vehicle,
                      quantities: _quantities,
                      onChanged: _setQuantity,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _PriceSummaryCard(vehicle: _vehicle, quote: quote),
                  // Hides itself entirely until a supplier feed provides terms
                  // — the screen never invents a deposit or a deadline.
                  if (!_vehicle.conditions.isEmpty) ...[
                    const SizedBox(height: 14),
                    _RentalConditionsCard(vehicle: _vehicle),
                  ],
                  const SizedBox(height: 22),
                  PrimaryButton(label: l10n.carApply, onTap: _apply),
                ],
              ),
              // Left rather than start: DESIGN_SYSTEM.md 11.3 keeps the back
              // button physically top-left in RTL too, as on every other screen.
              Positioned(
                left: 16,
                top: 8,
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vehicle identity, supplier, and what the car actually offers.
class _CarDetailsCard extends StatelessWidget {
  const _CarDetailsCard({required this.vehicle});

  final RentalVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;

    final facilities = <Widget>[
      RentalFacility(
        icon: Icons.person_outline,
        label: l10n.carPersons(vehicle.passengers),
        iconSize: 34,
        fontSize: 12,
      ),
      RentalFacility(
        icon: rentalPowertrainIcon(vehicle.powertrain),
        label: rentalPowertrainLabel(l10n, vehicle.powertrain),
        iconSize: 34,
        fontSize: 12,
      ),
      // Absent AC is simply not listed, matching the results card — a facility
      // the car lacks is never shown as a negative.
      if (vehicle.airConditioning)
        RentalFacility(
          icon: Icons.ac_unit,
          label: l10n.carAirConditioning,
          iconSize: 34,
          fontSize: 12,
        ),
      RentalFacility(
        icon: Icons.work_outline,
        label: l10n.carBags(vehicle.bags),
        iconSize: 34,
        fontSize: 12,
      ),
      RentalFacility(
        icon: rentalTransmissionIcon(vehicle.transmission),
        label: rentalTransmissionLabel(l10n, vehicle.transmission),
        iconSize: 34,
        fontSize: 12,
      ),
    ];

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RentalSectionHeader(
            icon: Icons.directions_car,
            title: l10n.carDetails,
            trailing: RentalCompanyBadge(
              company: vehicle.company,
              maxWidth: 170,
              iconSize: 30,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            vehicle.name.forLanguage(language),
            style: TextStyle(
              color: AppColors.heading(context),
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '(${l10n.carModelYear(vehicle.modelYear)})',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          // Wrap rather than a Row: five facilities do not fit one line on a
          // small phone or at a large text scale, and this reflows instead of
          // overflowing.
          Wrap(spacing: 14, runSpacing: 12, children: facilities),
        ],
      ),
    );
  }
}

/// What the user already chose on the search form, restated so they never have
/// to go back to check it.
class _PickupDropOffCard extends StatelessWidget {
  const _PickupDropOffCard({required this.criteria});

  final CarRentalSearchCriteria criteria;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;

    Widget dateAndTime(DateTime value) {
      final date = materialL10n.formatMediumDate(value);
      final time = materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(value));
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 14,
        runSpacing: 4,
        children: [
          RentalValueChip(icon: Icons.calendar_month_outlined, text: date),
          RentalValueChip(icon: Icons.access_time, text: time),
        ],
      );
    }

    final pickupBranch = criteria.pickupLocation.name.forLanguage(language);
    final dropOffBranch = criteria.dropOffLocation.name.forLanguage(language);

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RentalSectionHeader(
            icon: Icons.calendar_month_outlined,
            title: l10n.carPickupDropOffDetails,
          ),
          const SizedBox(height: 6),
          RentalDetailRow(
            label: l10n.carPickup,
            value: dateAndTime(criteria.pickupDateTime),
          ),
          const _Separator(),
          RentalDetailRow(
            label: l10n.carDropOff,
            value: dateAndTime(criteria.dropOffDateTime),
          ),
          const _Separator(),
          // One row when the car comes back where it was collected, two when
          // the search asked for different branches — never an assumption that
          // the two are the same.
          if (criteria.sameLocation)
            RentalDetailRow(
              label: l10n.carLocation,
              value: RentalValueChip(
                icon: Icons.location_on_outlined,
                text: pickupBranch,
              ),
            )
          else ...[
            RentalDetailRow(
              label: l10n.carPickupLocation,
              value: RentalValueChip(
                icon: Icons.location_on_outlined,
                text: pickupBranch,
              ),
            ),
            const _Separator(),
            RentalDetailRow(
              label: l10n.carDropOffLocation,
              value: RentalValueChip(
                icon: Icons.location_on_outlined,
                text: dropOffBranch,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdditionalOptionsCard extends StatelessWidget {
  const _AdditionalOptionsCard({
    required this.vehicle,
    required this.quantities,
    required this.onChanged,
  });

  final RentalVehicle vehicle;
  final Map<String, int> quantities;
  final void Function(RentalExtra extra, int value) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final extras = vehicle.extras;

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RentalSectionHeader(
            icon: Icons.tune,
            title: l10n.carAdditionalOptions,
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < extras.length; index++) ...[
            RentalOptionRow(
              extra: extras[index],
              currencyCode: vehicle.currencyCode,
              quantity: quantities[extras[index].id] ?? 0,
              onChanged: (value) => onChanged(extras[index], value),
            ),
            if (index != extras.length - 1) const _Separator(),
          ],
        ],
      ),
    );
  }
}

/// Base rate × rental days, plus whatever extras are ticked.
///
/// Labelled an estimate on purpose: taxes and supplier fees have no source in
/// the data, so they are named as missing rather than silently folded in.
class _PriceSummaryCard extends StatelessWidget {
  const _PriceSummaryCard({required this.vehicle, required this.quote});

  final RentalVehicle vehicle;
  final RentalQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget amount(double value, {bool emphasised = false}) => Text(
      rentalFormatAmount(value, quote.currencyCode),
      // Currency amounts read left-to-right even inside an RTL layout.
      textDirection: TextDirection.ltr,
      style: TextStyle(
        color: AppColors.heading(context),
        fontSize: emphasised ? 22 : 15,
        fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
      ),
    );

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RentalSectionHeader(
            icon: Icons.receipt_long_outlined,
            title: l10n.carPriceSummary,
          ),
          const SizedBox(height: 6),
          RentalDetailRow(
            label:
                '${l10n.carPricePerDay(rentalPriceAmount(vehicle))} · '
                '${l10n.carRentalDays(quote.days)}',
            value: amount(quote.baseTotal),
          ),
          if (quote.extrasTotal > 0) ...[
            const _Separator(),
            RentalDetailRow(
              label: l10n.carExtrasTotal,
              value: amount(quote.extrasTotal),
            ),
          ],
          const _Separator(),
          RentalDetailRow(
            label: l10n.carEstimatedTotal,
            value: amount(quote.total, emphasised: true),
          ),
          Text(
            l10n.carEstimateNote,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Supplier terms. Every row is conditional on real data being present — see
/// [RentalConditions], where all of these fields are nullable by design.
class _RentalConditionsCard extends StatelessWidget {
  const _RentalConditionsCard({required this.vehicle});

  final RentalVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final conditions = vehicle.conditions;
    final currency = vehicle.currencyCode;

    Widget value(String text) => Text(
      text,
      textAlign: TextAlign.end,
      style: TextStyle(
        color: AppColors.heading(context),
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
    );

    final rows = <Widget>[
      if (conditions.fuelPolicy != null)
        RentalDetailRow(
          label: l10n.carFuelPolicy,
          icon: Icons.local_gas_station_outlined,
          value: value(rentalFuelPolicyLabel(l10n, conditions.fuelPolicy!)),
        ),
      if (conditions.mileagePolicy != null)
        RentalDetailRow(
          label: l10n.carMileage,
          icon: Icons.speed_outlined,
          value: value(_mileageText(l10n, conditions.mileagePolicy!, currency)),
        ),
      if (conditions.depositAmount != null)
        RentalDetailRow(
          label: l10n.carDeposit,
          icon: Icons.account_balance_wallet_outlined,
          value: value(rentalFormatAmount(conditions.depositAmount!, currency)),
        ),
      if (conditions.damageExcess != null)
        RentalDetailRow(
          label: l10n.carDamageExcess,
          icon: Icons.shield_outlined,
          value: value(rentalFormatAmount(conditions.damageExcess!, currency)),
        ),
      if (conditions.freeCancellationUntil != null)
        RentalDetailRow(
          label: l10n.carFreeCancellation,
          icon: Icons.event_available_outlined,
          value: value(
            materialL10n.formatMediumDate(conditions.freeCancellationUntil!),
          ),
        ),
      if (conditions.minimumDriverAge != null)
        RentalDetailRow(
          label: l10n.carMinimumAge,
          icon: Icons.badge_outlined,
          value: value(l10n.carMinimumAgeValue(conditions.minimumDriverAge!)),
        ),
      if (conditions.requiredDocuments.isNotEmpty)
        RentalDetailRow(
          label: l10n.carRequiredDocuments,
          icon: Icons.description_outlined,
          value: value(
            conditions.requiredDocuments
                .map((document) => document.forLanguage(language))
                .join(' · '),
          ),
        ),
    ];

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RentalSectionHeader(
            icon: Icons.assignment_outlined,
            title: l10n.carRentalConditions,
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1) const _Separator(),
          ],
          if (conditions.guaranteedModel == false) ...[
            const SizedBox(height: 8),
            Text(
              l10n.carOrSimilar,
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _mileageText(
    AppLocalizations l10n,
    RentalMileagePolicy policy,
    String currency,
  ) {
    if (policy.unlimited) return l10n.carMileageUnlimited;
    final perDay = policy.kilometresPerDay;
    final extra = policy.extraKilometrePrice;
    return [
      if (perDay != null) l10n.carMileagePerDay(perDay),
      if (extra != null)
        l10n.carMileageExtra(rentalFormatAmount(extra, currency)),
    ].join(' · ');
  }
}

/// The hairline between rows, using the theme's outline token.
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}
