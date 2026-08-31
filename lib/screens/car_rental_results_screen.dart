import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/car_rental.dart';
import '../services/car_rental_service.dart';
import '../services/device_location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/rental_car_parts.dart';
import 'car_rental_details_screen.dart';
import 'car_rental_screen.dart' show carRentalBackgroundAsset;

/// The car the user picked, together with the search it came from.
///
/// Handed to the Car Rental Details screen (and to
/// [CarRentalResultsScreen.onVehicleSelected]) so it
/// receives both without re-querying.
@immutable
class CarRentalSelection {
  const CarRentalSelection({required this.criteria, required this.vehicle});

  final CarRentalSearchCriteria criteria;
  final RentalVehicle vehicle;
}

/// Results for a completed Car Rental search.
///
/// Pushed by the Car Rental screen's Search button with the typed criteria the
/// form produced; the form itself stays alive underneath, so Back returns to it
/// with every entered value intact.
class CarRentalResultsScreen extends StatefulWidget {
  const CarRentalResultsScreen({
    super.key,
    required this.criteria,
    this.service = const PreviewCarRentalService(),
    this.locationService = const DeviceLocationService(),
    this.onVehicleSelected,
  });

  final CarRentalSearchCriteria criteria;
  final CarRentalService service;
  final DeviceLocationService locationService;
  final ValueChanged<CarRentalSelection>? onVehicleSelected;

  @override
  State<CarRentalResultsScreen> createState() => _CarRentalResultsScreenState();
}

class _CarRentalResultsScreenState extends State<CarRentalResultsScreen> {
  List<RentalVehicle>? _cars;
  Object? _error;
  DeviceLocation? _deviceLocation;

  /// The last card the user opened, kept so returning from the Car Details
  /// screen restores the highlight.
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocation();
  }

  Future<void> _load() async {
    setState(() {
      _cars = null;
      _error = null;
    });
    try {
      final cars = await widget.service.searchCars(widget.criteria);
      if (mounted) setState(() => _cars = cars);
    } catch (error, stackTrace) {
      // The user sees a friendly message; the details go to the log only.
      debugPrint('Car rental search failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _loadLocation() async {
    // Never blocks the results: a null position simply hides the distance line.
    final location = await widget.locationService.currentLocation();
    if (mounted) setState(() => _deviceLocation = location);
  }

  void _select(RentalVehicle vehicle) {
    setState(() => _selectedVehicleId = vehicle.id);
    final selection = CarRentalSelection(
      criteria: widget.criteria,
      vehicle: vehicle,
    );
    final callback = widget.onVehicleSelected;
    if (callback != null) {
      callback(selection);
      return;
    }
    // Pushed, not replaced: this list stays alive underneath, so Back returns
    // to the same results with the search, the scroll position and the
    // highlighted card all intact.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CarRentalDetailsScreen(selection: selection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cars = _cars;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: carRentalBackgroundAsset,
        child: SafeArea(
          child: Stack(
            children: [
              _ResultsBody(
                cars: cars,
                error: _error,
                deviceLocation: _deviceLocation,
                selectedVehicleId: _selectedVehicleId,
                onRetry: _load,
                onModifySearch: () => Navigator.of(context).maybePop(),
                onSelect: _select,
              ),
              // Left rather than start: DESIGN_SYSTEM.md 11.3 keeps the back
              // button physically top-left in RTL too, as it is on every other
              // screen.
              Positioned(
                left: 16,
                top: 8,
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Padding(
                      // Clears the back button on both sides so the badge stays
                      // centred and never sits under it in LTR or RTL.
                      padding: const EdgeInsets.symmetric(horizontal: 76),
                      child: _ResultCountBadge(count: cars?.length),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded glass pill above the list. The number is always derived from the
/// list itself — there is no separately maintained counter.
class _ResultCountBadge extends StatelessWidget {
  const _ResultCountBadge({required this.count});

  /// `null` while the search is still running, which hides the pill.
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (count == null) return const SizedBox.shrink();
    final label = AppLocalizations.of(context).carResults(count!);
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: GlassPanel(
        depth: GlassDepth.top,
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.cars,
    required this.error,
    required this.deviceLocation,
    required this.selectedVehicleId,
    required this.onRetry,
    required this.onModifySearch,
    required this.onSelect,
  });

  final List<RentalVehicle>? cars;
  final Object? error;
  final DeviceLocation? deviceLocation;
  final String? selectedVehicleId;
  final VoidCallback onRetry;
  final VoidCallback onModifySearch;
  final ValueChanged<RentalVehicle> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const padding = EdgeInsets.fromLTRB(16, 64, 16, 32);

    if (error != null) {
      return _MessagePane(
        padding: padding,
        icon: Icons.error_outline,
        title: l10n.carSearchFailed,
        actionLabel: l10n.flightRetry,
        onAction: onRetry,
      );
    }
    final cars = this.cars;
    if (cars == null) return const _ResultsSkeleton(padding: padding);
    if (cars.isEmpty) {
      return _MessagePane(
        padding: padding,
        icon: Icons.directions_car_outlined,
        title: l10n.carResultsEmptyTitle,
        body: l10n.carResultsEmptyBody,
        actionLabel: l10n.carModifySearch,
        onAction: onModifySearch,
      );
    }

    return Semantics(
      container: true,
      label: l10n.carResultsListLabel,
      child: ListView.separated(
        padding: padding,
        itemCount: cars.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final car = cars[index];
          return CarResultCard(
            vehicle: car,
            deviceLocation: deviceLocation,
            selected: car.id == selectedVehicleId,
            onTap: () => onSelect(car),
          );
        },
      ),
    );
  }
}

/// One search result. The whole card is a single button.
class CarResultCard extends StatelessWidget {
  const CarResultCard({
    super.key,
    required this.vehicle,
    required this.deviceLocation,
    required this.onTap,
    this.selected = false,
  });

  final RentalVehicle vehicle;
  final DeviceLocation? deviceLocation;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final name = vehicle.name.forLanguage(language);
    final modelYear = l10n.carModelYear(vehicle.modelYear);
    final branch = vehicle.location.name.forLanguage(language);
    final distance = rentalDistanceText(vehicle.location, deviceLocation);
    final payAtPickup =
        vehicle.paymentOption == RentalPaymentOption.payAtPickup;

    final facilities = <Widget>[
      RentalFacility(
        icon: Icons.person_outline,
        label: l10n.carPersons(vehicle.passengers),
        iconSize: 30,
        fontSize: 12,
      ),
      RentalFacility(
        icon: rentalPowertrainIcon(vehicle.powertrain),
        label: rentalPowertrainLabel(l10n, vehicle.powertrain),
        iconSize: 30,
        fontSize: 12,
      ),
      RentalFacility(
        icon: Icons.work_outline,
        label: l10n.carBags(vehicle.bags),
        iconSize: 30,
        fontSize: 12,
      ),
      // Hidden rather than shown as a negative — an absent facility is simply
      // not listed, exactly as the design does for the other rows.
      if (vehicle.airConditioning)
        RentalFacility(
          icon: Icons.ac_unit,
          label: l10n.carAirConditioning,
          iconSize: 30,
          fontSize: 12,
        ),
    ];

    final semanticsLabel = [
      name,
      modelYear,
      vehicle.company.name.forLanguage(language),
      l10n.carPersons(vehicle.passengers),
      rentalPowertrainLabel(l10n, vehicle.powertrain),
      l10n.carBags(vehicle.bags),
      if (vehicle.airConditioning) l10n.carAirConditioning,
      rentalPaymentLabel(l10n, vehicle.paymentOption),
      branch,
      if (distance != null) l10n.distanceFromCurrentLocation(distance),
      l10n.carPricePerDay(rentalPriceAmount(vehicle)),
    ].join(', ');

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GlassPanel(
        borderRadius: 28,
        padding: EdgeInsets.zero,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The photo keeps roughly the reference's third-of-the-card
                  // proportion, but never squeezes the information column on a
                  // small phone or grows past it on a large one.
                  final imageWidth = (constraints.maxWidth * 0.34).clamp(
                    96.0,
                    134.0,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: imageWidth,
                        height: imageWidth * 1.65,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: RentalVehicleImage(
                            asset: vehicle.images.first,
                            // Thumbnail budget: the card never needs the full
                            // frame, and this keeps a long list cheap.
                            cacheWidth: (imageWidth * 3).round(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.heading(context),
                                          fontSize: 20,
                                          height: 1.25,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '($modelYear)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.secondaryText(
                                            context,
                                          ),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                RentalCompanyBadge(
                                  company: vehicle.company,
                                  maxWidth: 150,
                                  iconSize: 28,
                                  fontSize: 13,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: facilities,
                            ),
                            const SizedBox(height: 10),
                            RentalFacility(
                              icon: Icons.credit_card,
                              label: rentalPaymentLabel(
                                l10n,
                                vehicle.paymentOption,
                              ),
                              success: payAtPickup,
                              iconSize: 30,
                              fontSize: 12,
                            ),
                            const SizedBox(height: 10),
                            _LocationAndPrice(
                              vehicle: vehicle,
                              branch: branch,
                              distance: distance,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The branch line and the price pill, side by side as in the design — and
/// stacked instead once the text is scaled far enough up that the two can no
/// longer share a row on a narrow phone.
class _LocationAndPrice extends StatelessWidget {
  const _LocationAndPrice({
    required this.vehicle,
    required this.branch,
    required this.distance,
  });

  final RentalVehicle vehicle;
  final String branch;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 17.5;

    final location = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RentalCircleIcon(icon: Icons.location_on, size: 34),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branch,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (distance != null)
                Text(
                  l10n.distanceFromCurrentLocation(distance!),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          location,
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: RentalPriceBadge(vehicle: vehicle),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: location),
        const SizedBox(width: 8),
        RentalPriceBadge(vehicle: vehicle),
      ],
    );
  }
}

/// Glass placeholders shown while the search runs, so the page never flashes
/// empty. Static rather than animated — the project ships no shimmer package.
class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).carResultsLoading,
    child: ListView.separated(
      padding: padding,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => const _SkeletonCard(),
    ),
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonBox(width: 112, height: 185, radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SkeletonBox(width: 150, height: 22, radius: 8),
              const SizedBox(height: 10),
              const _SkeletonBox(width: 90, height: 14, radius: 8),
              const SizedBox(height: 16),
              const _SkeletonBox(
                width: double.infinity,
                height: 30,
                radius: 15,
              ),
              const SizedBox(height: 10),
              const _SkeletonBox(
                width: double.infinity,
                height: 30,
                radius: 15,
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(child: _SkeletonBox(height: 34, radius: 12)),
                  SizedBox(width: 8),
                  _SkeletonBox(width: 78, height: 42, radius: 16),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, required this.radius});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.glassBaseTint(context).withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Shared shell for the empty and error states.
class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.padding,
    required this.icon,
    required this.title,
    this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final EdgeInsets padding;
  final IconData icon;
  final String title;
  final String? body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    return ListView(
      padding: padding,
      children: [
        GlassPanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              RentalCircleIcon(icon: icon, size: 52),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: 18,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ],
    );
  }
}
