import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/car_rental.dart';
import '../services/car_rental_service.dart';
import '../services/device_location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/rental_car_parts.dart';
import 'car_rental_details_screen.dart';
import 'car_rental_results_screen.dart';

const carRentalBackgroundAsset = 'assets/images/car rental background.webp';

class CarRentalScreen extends StatefulWidget {
  const CarRentalScreen({
    super.key,
    this.service = const PreviewCarRentalService(),
    this.locationService = const DeviceLocationService(),
    this.onVehicleSelected,
  });

  final CarRentalService service;
  final DeviceLocationService locationService;
  final ValueChanged<RentalVehicle>? onVehicleSelected;

  @override
  State<CarRentalScreen> createState() => _CarRentalScreenState();
}

class _CarRentalScreenState extends State<CarRentalScreen> {
  final _carouselController = PageController();
  final _searchCardKey = GlobalKey();

  List<RentalVehicle>? _cars;
  Object? _loadError;
  DeviceLocation? _deviceLocation;
  int _featuredIndex = 0;
  bool _differentDropOff = false;
  RentalLocation? _pickupLocation;
  RentalLocation? _dropOffLocation;
  DateTime? _pickupDate;
  DateTime? _dropOffDate;
  TimeOfDay? _pickupTime;
  TimeOfDay? _dropOffTime;
  bool _searching = false;

  /// Which location field has its inline search panel open: `pickup`,
  /// `dropoff`, or null when both are collapsed. The panel expands in place
  /// under the tapped field rather than opening a modal sheet.
  String? _openLocation;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _loadLocation();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _cars = null;
      _loadError = null;
    });
    try {
      final cars = await widget.service.trendingCars();
      if (mounted) setState(() => _cars = cars);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _loadLocation() async {
    final location = await widget.locationService.currentLocation();
    if (mounted) setState(() => _deviceLocation = location);
  }

  void _toggleLocationSearch({required bool pickup}) {
    final target = pickup ? 'pickup' : 'dropoff';
    setState(() => _openLocation = _openLocation == target ? null : target);
  }

  void _selectLocation(RentalLocation selected, {required bool pickup}) {
    setState(() {
      if (pickup) {
        _pickupLocation = selected;
        _errors.remove('pickupLocation');
      } else {
        _dropOffLocation = selected;
        _errors.remove('dropOffLocation');
      }
      _openLocation = null;
    });
  }

  Future<void> _chooseDate({required bool pickup}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = pickup ? today : (_pickupDate ?? today);
    final initialDate = pickup
        ? (_pickupDate ?? today)
        : (_dropOffDate ?? firstDate);
    final selected = await _showCalendar(
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (pickup) {
        _pickupDate = selected;
        if (_dropOffDate != null && _dropOffDate!.isBefore(selected)) {
          _dropOffDate = null;
          _dropOffTime = null;
        }
        _errors.remove('pickupDate');
      } else {
        _dropOffDate = selected;
        _errors.remove('dropOffDate');
      }
      _clearDateTimeErrors();
    });
  }

  Future<DateTime?> _showCalendar({
    required DateTime initialDate,
    required DateTime firstDate,
  }) => showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      var selectedDate = initialDate;
      return StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            depth: GlassDepth.middle,
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: firstDate,
                    lastDate: DateTime(
                      firstDate.year + 1,
                      firstDate.month,
                      firstDate.day,
                    ),
                    onDateChanged: (value) =>
                        setSheetState(() => selectedDate = value),
                  ),
                  PrimaryButton(
                    label: AppLocalizations.of(context).done,
                    onTap: () => Navigator.of(sheetContext).pop(selectedDate),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Future<void> _chooseTime({required bool pickup}) async {
    final selected = await _showTime(
      pickup
          ? (_pickupTime ?? TimeOfDay.now())
          : (_dropOffTime ?? TimeOfDay.now()),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (pickup) {
        _pickupTime = selected;
        _errors.remove('pickupTime');
      } else {
        _dropOffTime = selected;
        _errors.remove('dropOffTime');
      }
      _clearDateTimeErrors();
    });
  }

  Future<TimeOfDay?> _showTime(TimeOfDay initialTime) =>
      showModalBottomSheet<TimeOfDay>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          var selected = DateTime(
            2020,
            1,
            1,
            initialTime.hour,
            initialTime.minute,
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassPanel(
              depth: GlassDepth.middle,
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 220,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: selected,
                      use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                      onDateTimeChanged: (value) => selected = value,
                    ),
                  ),
                  PrimaryButton(
                    label: AppLocalizations.of(context).done,
                    onTap: () => Navigator.of(sheetContext).pop(
                      TimeOfDay(hour: selected.hour, minute: selected.minute),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  void _clearDateTimeErrors() {
    _errors.remove('pickupFuture');
    _errors.remove('dropOffAfterPickup');
  }

  DateTime? _combine(DateTime? date, TimeOfDay? time) =>
      date == null || time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    final errors = <String, String>{};
    if (_pickupLocation == null) {
      errors['pickupLocation'] = l10n.carPickupLocationRequired;
    }
    if (_differentDropOff && _dropOffLocation == null) {
      errors['dropOffLocation'] = l10n.carDropOffLocationRequired;
    }
    if (_pickupDate == null) {
      errors['pickupDate'] = l10n.carPickupDateRequired;
    }
    if (_pickupTime == null) {
      errors['pickupTime'] = l10n.carPickupTimeRequired;
    }
    if (_dropOffDate == null) {
      errors['dropOffDate'] = l10n.carDropOffDateRequired;
    }
    if (_dropOffTime == null) {
      errors['dropOffTime'] = l10n.carDropOffTimeRequired;
    }

    final pickup = _combine(_pickupDate, _pickupTime);
    final dropOff = _combine(_dropOffDate, _dropOffTime);
    if (pickup != null && !pickup.isAfter(DateTime.now())) {
      errors['pickupFuture'] = l10n.carPickupFuture;
    }
    if (pickup != null && dropOff != null && !dropOff.isAfter(pickup)) {
      errors['dropOffAfterPickup'] = l10n.carDropOffAfterPickup;
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  /// The typed criteria the form currently describes, or null when it does
  /// not validate. Validating has a side effect (it publishes the inline field
  /// errors), which is why both Search and a car tap go through here rather
  /// than assembling criteria themselves.
  CarRentalSearchCriteria? _criteriaOrNull() {
    if (!_validate()) return null;
    final pickupLocation = _pickupLocation!;
    return CarRentalSearchCriteria(
      pickupLocation: pickupLocation,
      dropOffLocation: _differentDropOff ? _dropOffLocation! : pickupLocation,
      sameLocation: !_differentDropOff,
      pickupDateTime: _combine(_pickupDate, _pickupTime)!,
      dropOffDateTime: _combine(_dropOffDate, _dropOffTime)!,
    );
  }

  /// Brings the search form back on screen when a tap could not proceed —
  /// the reason is drawn as field errors inside that card, which is off
  /// screen when the tap came from a trending card further down.
  void _revealSearchCard() {
    final target = _searchCardKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  Future<void> _search() async {
    if (_searching) return;
    FocusScope.of(context).unfocus();
    final criteria = _criteriaOrNull();
    if (criteria == null) return;
    final onVehicleSelected = widget.onVehicleSelected;
    // Guards against a second push while the results route is opening.
    setState(() => _searching = true);
    try {
      // Pushed, not replaced: this form stays alive underneath, so Back
      // returns to it with every entered value still in place. The results
      // screen owns the query itself, including its loading/error states.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CarRentalResultsScreen(
            criteria: criteria,
            service: widget.service,
            locationService: widget.locationService,
            onVehicleSelected: onVehicleSelected == null
                ? null
                : (selection) => onVehicleSelected(selection.vehicle),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectVehicle(RentalVehicle vehicle) {
    final callback = widget.onVehicleSelected;
    if (callback != null) {
      callback(vehicle);
      return;
    }
    FocusScope.of(context).unfocus();
    // The details screen quotes a price against real dates, so it cannot open
    // on a half-filled form. Validation publishes the missing-field errors and
    // the form is scrolled back into view so the user can see why.
    final criteria = _criteriaOrNull();
    if (criteria == null) {
      _revealSearchCard();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CarRentalDetailsScreen(
          selection: CarRentalSelection(criteria: criteria, vehicle: vehicle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cars = _cars;
    final featured = cars?.where((car) => car.featured).toList() ?? const [];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: carRentalBackgroundAsset,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList.list(
                  children: [
                    _Header(onBack: () => Navigator.of(context).maybePop()),
                    const SizedBox(height: 16),
                    _FeaturedCarousel(
                      controller: _carouselController,
                      cars: featured,
                      loading: cars == null && _loadError == null,
                      current: _featuredIndex,
                      onChanged: (index) =>
                          setState(() => _featuredIndex = index),
                      onTap: _selectVehicle,
                    ),
                    const SizedBox(height: 16),
                    _SearchCard(
                      key: _searchCardKey,
                      pickupLocation: _pickupLocation,
                      dropOffLocation: _dropOffLocation,
                      differentDropOff: _differentDropOff,
                      pickupDate: _pickupDate,
                      pickupTime: _pickupTime,
                      dropOffDate: _dropOffDate,
                      dropOffTime: _dropOffTime,
                      errors: _errors,
                      searching: _searching,
                      service: widget.service,
                      openLocation: _openLocation,
                      onPickupLocation: () =>
                          _toggleLocationSearch(pickup: true),
                      onDropOffLocation: () =>
                          _toggleLocationSearch(pickup: false),
                      onLocationSelected: _selectLocation,
                      onDifferentDropOff: (value) => setState(() {
                        _differentDropOff = value;
                        if (!value) _errors.remove('dropOffLocation');
                      }),
                      onPickupDate: () => _chooseDate(pickup: true),
                      onPickupTime: () => _chooseTime(pickup: true),
                      onDropOffDate: () => _chooseDate(pickup: false),
                      onDropOffTime: () => _chooseTime(pickup: false),
                      onSearch: _search,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      // Search results now live on their own screen; this list
                      // stays the trending selection.
                      l10n.carTrending,
                      style: TextStyle(
                        color: AppColors.heading(context),
                        fontSize: 20,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadError != null)
                      _CarsMessage(
                        message: l10n.carSearchFailed,
                        actionLabel: l10n.flightRetry,
                        onAction: _loadTrending,
                      )
                    else if (cars == null)
                      const _CarsLoading()
                    else if (cars.isEmpty)
                      _CarsMessage(message: l10n.carNoAvailable)
                    else
                      for (final car in cars) ...[
                        _RentalCarCard(
                          vehicle: car,
                          deviceLocation: _deviceLocation,
                          onTap: () => _selectVehicle(car),
                        ),
                        if (car != cars.last) const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      GlassBackButton(onTap: onBack),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          AppLocalizations.of(context).carRental,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 28,
            height: 1.28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({
    required this.controller,
    required this.cars,
    required this.loading,
    required this.current,
    required this.onChanged,
    required this.onTap,
  });

  final PageController controller;
  final List<RentalVehicle> cars;
  final bool loading;
  final int current;
  final ValueChanged<int> onChanged;
  final ValueChanged<RentalVehicle> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AspectRatio(
        aspectRatio: 1.92,
        child: GlassPanel(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (cars.isEmpty) return const SizedBox.shrink();
    final languageCode = Localizations.localeOf(context).languageCode;
    return AspectRatio(
      aspectRatio: 1.92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              itemCount: cars.length,
              onPageChanged: onChanged,
              itemBuilder: (context, index) {
                final car = cars[index];
                return Semantics(
                  button: true,
                  image: true,
                  label:
                      '${car.name.forLanguage(languageCode)}, ${AppLocalizations.of(context).carCarouselPosition(index + 1, cars.length)}',
                  child: InkWell(
                    onTap: () => onTap(car),
                    child: RentalVehicleImage(asset: car.images.first),
                  ),
                );
              },
            ),
            PositionedDirectional(
              top: 14,
              end: 14,
              child: RentalCompanyBadge(
                company: cars[current.clamp(0, cars.length - 1)].company,
              ),
            ),
            PositionedDirectional(
              end: 18,
              bottom: 14,
              child: _CarouselDots(count: cars.length, current: current),
            ),
          ],
        ),
      ),
    );
  }
}

/// The compact variant of the shared company badge, as used inside this
/// screen's own car cards.
class _CompactCompanyBadge extends StatelessWidget {
  const _CompactCompanyBadge({required this.company});

  final RentalCompany company;

  @override
  Widget build(BuildContext context) => RentalCompanyBadge(
    company: company,
    maxWidth: 104,
    borderRadius: 14,
    padding: const EdgeInsetsDirectional.fromSTEB(3, 2, 7, 2),
    iconSize: 20,
    fontSize: 11,
    gap: 4,
  );
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count.clamp(0, 7); index++) ...[
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == current ? 10 : 8,
          height: index == current ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.48),
            border: index == current
                ? Border.all(color: AppColors.accent(context), width: 1)
                : null,
          ),
        ),
        if (index != count.clamp(0, 7) - 1) const SizedBox(width: 7),
      ],
    ],
  );
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    super.key,
    required this.pickupLocation,
    required this.dropOffLocation,
    required this.differentDropOff,
    required this.pickupDate,
    required this.pickupTime,
    required this.dropOffDate,
    required this.dropOffTime,
    required this.errors,
    required this.searching,
    required this.service,
    required this.openLocation,
    required this.onLocationSelected,
    required this.onPickupLocation,
    required this.onDropOffLocation,
    required this.onDifferentDropOff,
    required this.onPickupDate,
    required this.onPickupTime,
    required this.onDropOffDate,
    required this.onDropOffTime,
    required this.onSearch,
  });

  final RentalLocation? pickupLocation;
  final RentalLocation? dropOffLocation;
  final bool differentDropOff;
  final DateTime? pickupDate;
  final TimeOfDay? pickupTime;
  final DateTime? dropOffDate;
  final TimeOfDay? dropOffTime;
  final Map<String, String> errors;
  final bool searching;
  final CarRentalService service;

  /// `pickup`, `dropoff`, or null — which field shows its inline search list.
  final String? openLocation;
  final void Function(RentalLocation selected, {required bool pickup})
  onLocationSelected;
  final VoidCallback onPickupLocation;
  final VoidCallback onDropOffLocation;
  final ValueChanged<bool> onDifferentDropOff;
  final VoidCallback onPickupDate;
  final VoidCallback onPickupTime;
  final VoidCallback onDropOffDate;
  final VoidCallback onDropOffTime;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.carPickupDropOffLocation,
            style: TextStyle(
              color: AppColors.heading(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _RentalField(
            key: const Key('car-pickup-location'),
            icon: Icons.directions_car,
            label: pickupLocation?.name.forLanguage(language) ?? l10n.carPickup,
            onTap: onPickupLocation,
            error: errors['pickupLocation'],
          ),
          _InlineLocationSearch(
            key: const Key('car-pickup-location-search'),
            open: openLocation == 'pickup',
            service: service,
            onSelected: (location) =>
                onLocationSelected(location, pickup: true),
          ),
          const SizedBox(height: 8),
          Semantics(
            checked: differentDropOff,
            child: InkWell(
              onTap: () => onDifferentDropOff(!differentDropOff),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  Checkbox(
                    value: differentDropOff,
                    onChanged: (value) => onDifferentDropOff(value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      l10n.carDifferentDropOff,
                      style: TextStyle(color: AppColors.heading(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: differentDropOff
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RentalField(
                          key: const Key('car-dropoff-location'),
                          icon: Icons.location_on_outlined,
                          label:
                              dropOffLocation?.name.forLanguage(language) ??
                              l10n.carDropOffLocation,
                          onTap: onDropOffLocation,
                          error: errors['dropOffLocation'],
                        ),
                        _InlineLocationSearch(
                          key: const Key('car-dropoff-location-search'),
                          open: openLocation == 'dropoff',
                          service: service,
                          onSelected: (location) =>
                              onLocationSelected(location, pickup: false),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final stack = constraints.maxWidth < 330 || scale > 1.25;
              final pickup = _DateTimeColumn(
                title: l10n.carPickup,
                date: pickupDate,
                time: pickupTime,
                dateError: errors['pickupDate'],
                timeError: errors['pickupTime'],
                combinedError: errors['pickupFuture'],
                onDate: onPickupDate,
                onTime: onPickupTime,
              );
              final dropOff = _DateTimeColumn(
                title: l10n.carDropOff,
                date: dropOffDate,
                time: dropOffTime,
                dateError: errors['dropOffDate'],
                timeError: errors['dropOffTime'],
                combinedError: errors['dropOffAfterPickup'],
                onDate: onDropOffDate,
                onTime: onDropOffTime,
              );
              if (stack) {
                return Column(
                  children: [pickup, const SizedBox(height: 16), dropOff],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: pickup),
                  const SizedBox(width: 12),
                  Expanded(child: dropOff),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: _GlassSearchButton(
              loading: searching,
              onTap: searching ? null : onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeColumn extends StatelessWidget {
  const _DateTimeColumn({
    required this.title,
    required this.date,
    required this.time,
    required this.dateError,
    required this.timeError,
    required this.combinedError,
    required this.onDate,
    required this.onTime,
  });

  final String title;
  final DateTime? date;
  final TimeOfDay? time;
  final String? dateError;
  final String? timeError;
  final String? combinedError;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.heading(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _RentalField(
          icon: Icons.calendar_month_outlined,
          label: date == null
              ? l10n.carSelectDate
              : MaterialLocalizations.of(context).formatMediumDate(date!),
          onTap: onDate,
          error: dateError,
          compact: true,
        ),
        const SizedBox(height: 8),
        _RentalField(
          icon: Icons.access_time,
          label: time == null
              ? l10n.carSelectTime
              : MaterialLocalizations.of(context).formatTimeOfDay(time!),
          onTap: onTime,
          error: timeError ?? combinedError,
          compact: true,
        ),
      ],
    );
  }
}

class _RentalField extends StatelessWidget {
  const _RentalField({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.error,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? error;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        button: true,
        label: label,
        child: GlassPanel(
          depth: GlassDepth.middle,
          borderRadius: 14,
          borderColor: error == null
              ? null
              : Theme.of(context).colorScheme.error,
          borderWidth: error == null ? null : AppColors.selectionStrokeWidth,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 12, 0),
                child: Row(
                  children: [
                    RentalCircleIcon(icon: icon, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.heading(context),
                          fontSize: compact ? 13 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 3),
        Text(
          error!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ],
  );
}

class _GlassSearchButton extends StatelessWidget {
  const _GlassSearchButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassPanel(
    depth: GlassDepth.top,
    borderRadius: 24,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 16, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox.square(
                    dimension: 38,
                    child: Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const RentalCircleIcon(icon: Icons.search, size: 38),
            const SizedBox(width: 8),
            Text(
              loading
                  ? AppLocalizations.of(context).carSearching
                  : AppLocalizations.of(context).carSearch,
              style: TextStyle(
                color: AppColors.heading(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RentalCarCard extends StatelessWidget {
  const _RentalCarCard({
    required this.vehicle,
    required this.deviceLocation,
    required this.onTap,
  });

  final RentalVehicle vehicle;
  final DeviceLocation? deviceLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final distance = rentalDistanceText(vehicle.location, deviceLocation);
    return Semantics(
      button: true,
      label: vehicle.name.forLanguage(language),
      child: GlassPanel(
        borderRadius: 28,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 132,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: RentalVehicleImage(
                          asset: vehicle.images.first,
                          cacheWidth: 336,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 132,
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
                                        vehicle.name.forLanguage(language),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.heading(context),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        l10n.carModelYear(vehicle.modelYear),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.secondaryText(
                                            context,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _CompactCompanyBadge(company: vehicle.company),
                              ],
                            ),
                            Expanded(
                              child: Center(
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 7,
                                    children: [
                                      RentalFacility(
                                        icon: Icons.person_outline,
                                        label: l10n.carPersons(
                                          vehicle.passengers,
                                        ),
                                      ),
                                      RentalFacility(
                                        icon: Icons.bolt,
                                        label: rentalPowertrainLabel(
                                          l10n,
                                          vehicle.powertrain,
                                        ),
                                      ),
                                      RentalFacility(
                                        icon: Icons.work_outline,
                                        label: l10n.carBags(vehicle.bags),
                                      ),
                                      if (vehicle.airConditioning)
                                        RentalFacility(
                                          icon: Icons.ac_unit,
                                          label: l10n.carAirConditioning,
                                        ),
                                      RentalFacility(
                                        icon: Icons.payments_outlined,
                                        label: rentalPaymentLabel(
                                          l10n,
                                          vehicle.paymentOption,
                                        ),
                                        success:
                                            vehicle.paymentOption ==
                                            RentalPaymentOption.payAtPickup,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const RentalCircleIcon(icon: Icons.location_on, size: 42),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.location.name.forLanguage(language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.heading(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (distance != null)
                            Text(
                              l10n.distanceFromCurrentLocation(distance),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.secondaryText(context),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassPanel(
                      depth: GlassDepth.top,
                      borderRadius: 14,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        l10n.carPricePerDay(rentalPriceAmount(vehicle)),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: AppColors.heading(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarsLoading extends StatelessWidget {
  const _CarsLoading();

  @override
  Widget build(BuildContext context) => const GlassPanel(
    borderRadius: 28,
    padding: EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _CarsMessage extends StatelessWidget {
  const _CarsMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Icon(Icons.directions_car_outlined, color: AppColors.accent(context)),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

/// The location picker, expanded in place under the field that opened it —
/// the same inline-panel behaviour the other search screens use, rather than
/// a modal sheet over the page.
class _InlineLocationSearch extends StatefulWidget {
  const _InlineLocationSearch({
    super.key,
    required this.open,
    required this.service,
    required this.onSelected,
  });

  final bool open;
  final CarRentalService service;
  final ValueChanged<RentalLocation> onSelected;

  @override
  State<_InlineLocationSearch> createState() => _InlineLocationSearchState();
}

class _InlineLocationSearchState extends State<_InlineLocationSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<RentalLocation> _results = const [];
  bool _loading = false;
  bool _failed = false;
  int _revision = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final revision = ++_revision;
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.service.searchLocations(query);
        if (!mounted || revision != _revision) return;
        final deduplicated = <String, RentalLocation>{
          for (final result in results) result.id: result,
        }.values.toList(growable: false);
        setState(() {
          _results = deduplicated;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || revision != _revision) return;
        setState(() {
          _results = const [];
          _loading = false;
          _failed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final queryReady = _controller.text.trim().length >= 2;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !widget.open
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassPanel(
                depth: GlassDepth.middle,
                borderRadius: 20,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppRecessedGlassField(
                      controller: _controller,
                      hint: l10n.carLocationSearchHint,
                      prefixIcon: Icons.search,
                      autofocus: true,
                      onChanged: _changed,
                    ),
                    const SizedBox(height: 10),
                    // The panel sits inside the page scroll view, so the list
                    // is capped and scrolls on its own instead of pushing the
                    // rest of the card off-screen.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _failed
                          ? _LocationMessage(
                              message: l10n.carLocationsFailed,
                              action: TextButton(
                                onPressed: () => _changed(_controller.text),
                                child: Text(l10n.flightRetry),
                              ),
                            )
                          : !queryReady
                          ? _LocationMessage(
                              message: l10n.carLocationStartTyping,
                            )
                          : _results.isEmpty
                          ? _LocationMessage(message: l10n.carNoLocations)
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: _results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final location = _results[index];
                                return GlassPanel(
                                  depth: GlassDepth.top,
                                  borderRadius: 14,
                                  child: ListTile(
                                    onTap: () => widget.onSelected(location),
                                    leading: const RentalCircleIcon(
                                      icon: Icons.location_on,
                                      size: 40,
                                    ),
                                    title: Text(
                                      location.name.forLanguage(language),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      [
                                        if (location.airportCode != null)
                                          location.airportCode!,
                                        location.city.forLanguage(language),
                                        location.country.forLanguage(language),
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LocationMessage extends StatelessWidget {
  const _LocationMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_searching, color: AppColors.accent(context)),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
