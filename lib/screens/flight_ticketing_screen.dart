import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/airport.dart';
import '../models/booking.dart';
import '../models/flight_search_criteria.dart';
import '../services/airport_search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/flight_airport_field.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'flight_search_results_screen.dart';

const String flightTicketingBackgroundAsset =
    'assets/images/flight ticketing - background.webp';

class FlightTicketingScreen extends StatefulWidget {
  const FlightTicketingScreen({
    super.key,
    this.onSearch,
    this.airportSearchService,
  });

  /// Hook for the results page that will be added later.
  final ValueChanged<FlightSearchCriteria>? onSearch;
  final AirportSearchService? airportSearchService;

  @override
  State<FlightTicketingScreen> createState() => _FlightTicketingScreenState();
}

class _FlightTicketingScreenState extends State<FlightTicketingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  late final AirportSearchService _airportSearchService;

  FlightTripType _tripType = FlightTripType.oneWay;
  Airport? _origin;
  Airport? _destination;
  DateTime? _departureDate;
  DateTime? _returnDate;
  int _adults = 1;
  int _children = 0;
  int _infants = 0;
  CabinClass _cabinClass = CabinClass.economy;
  bool _directOnly = false;
  bool _searching = false;

  /// Which airport field has its inline search panel open — `from`, `to`, or
  /// null when both are collapsed. Only one expands at a time.
  String? _openAirportField;

  @override
  void initState() {
    super.initState();
    _airportSearchService =
        widget.airportSearchService ?? FirebaseAirportSearchService();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickDepartureDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await _showGlassCalendar(
      title: AppLocalizations.of(context).flightDepartureDate,
      initialDate: _departureDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _departureDate = picked;
      if (_returnDate != null && _returnDate!.isBefore(picked)) {
        _returnDate = null;
      }
    });
    _formKey.currentState?.validate();
  }

  Future<void> _pickReturnDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = _departureDate ?? today;
    final picked = await _showGlassCalendar(
      title: AppLocalizations.of(context).flightReturnDate,
      initialDate: _returnDate ?? first,
      firstDate: first,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) {
      setState(() => _returnDate = picked);
      _formKey.currentState?.validate();
    }
  }

  Future<DateTime?> _showGlassCalendar({
    required String title,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) => showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      var selectedDate = initialDate;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final l10n = AppLocalizations.of(context);
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassPanel(
              depth: GlassDepth.middle,
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.heading(context),
                        fontSize: 20,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Theme(
                      data: theme.copyWith(
                        datePickerTheme: const DatePickerThemeData(
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          headerBackgroundColor: Colors.transparent,
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: selectedDate,
                        firstDate: firstDate,
                        lastDate: lastDate,
                        onDateChanged: (value) =>
                            setSheetState(() => selectedDate = value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: l10n.done,
                      onTap: () => Navigator.of(sheetContext).pop(selectedDate),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  Future<void> _showPassengerAndCabinPicker() async {
    var adults = _adults;
    var children = _children;
    var infants = _infants;
    var cabin = _cabinClass;

    final selection = await showModalBottomSheet<_PassengerCabinSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final l10n = AppLocalizations.of(context);
          final total = adults + children + infants;
          void changeAdults(int delta) {
            final next = adults + delta;
            if (next < 1 || next > 9 || total + delta > 9) return;
            setSheetState(() {
              adults = next;
              if (infants > adults) infants = adults;
            });
          }

          void changeChildren(int delta) {
            final next = children + delta;
            if (next < 0 || total + delta > 9) return;
            setSheetState(() => children = next);
          }

          void changeInfants(int delta) {
            final next = infants + delta;
            if (next < 0 || next > adults || total + delta > 9) return;
            setSheetState(() => infants = next);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: GlassPanel(
              depth: GlassDepth.middle,
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 680),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.flightPassengers,
                        style: TextStyle(
                          color: AppColors.heading(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PassengerStepper(
                        icon: Icons.person_outline,
                        label: l10n.flightAdults,
                        value: adults,
                        onMinus: adults > 1 ? () => changeAdults(-1) : null,
                        onPlus: total < 9 ? () => changeAdults(1) : null,
                      ),
                      const SizedBox(height: 10),
                      _PassengerStepper(
                        icon: Icons.child_care_outlined,
                        label: l10n.flightChildren,
                        value: children,
                        onMinus: children > 0 ? () => changeChildren(-1) : null,
                        onPlus: total < 9 ? () => changeChildren(1) : null,
                      ),
                      const SizedBox(height: 10),
                      _PassengerStepper(
                        icon: Icons.baby_changing_station_outlined,
                        label: l10n.flightInfants,
                        value: infants,
                        onMinus: infants > 0 ? () => changeInfants(-1) : null,
                        onPlus: total < 9 && infants < adults
                            ? () => changeInfants(1)
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.white.withValues(alpha: 0.65)),
                      const SizedBox(height: 12),
                      Text(
                        l10n.flightCabinClass,
                        style: TextStyle(
                          color: AppColors.heading(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final value in CabinClass.values) ...[
                        _CabinOption(
                          label: l10n.flightSearchCabinClassLabel(value),
                          selected: cabin == value,
                          onTap: () => setSheetState(() => cabin = value),
                        ),
                        if (value != CabinClass.values.last)
                          const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: l10n.done,
                        onTap: () => Navigator.of(sheetContext).pop(
                          _PassengerCabinSelection(
                            adults: adults,
                            children: children,
                            infants: infants,
                            cabinClass: cabin,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (selection == null || !mounted) return;
    setState(() {
      _adults = selection.adults;
      _children = selection.children;
      _infants = selection.infants;
      _cabinClass = selection.cabinClass;
    });
  }

  Future<void> _search() async {
    if (_searching) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final criteria = FlightSearchCriteria(
      tripType: _tripType,
      origin: _origin!,
      destination: _destination!,
      departureDate: _departureDate!,
      returnDate: _tripType == FlightTripType.roundTrip ? _returnDate : null,
      adults: _adults,
      children: _children,
      infants: _infants,
      cabinClass: _cabinClass,
      directFlightsOnly: _directOnly,
    );
    final onSearch = widget.onSearch;
    if (onSearch != null) {
      onSearch(criteria);
    } else {
      setState(() => _searching = true);
      try {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FlightSearchResultsScreen(criteria: criteria),
          ),
        );
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    }
  }

  String _formatDate(BuildContext context, DateTime? date) => date == null
      ? ''
      : MaterialLocalizations.of(context).formatMediumDate(date);

  void _toggleAirportField(String field) {
    FocusScope.of(context).unfocus();
    setState(
      () => _openAirportField = _openAirportField == field ? null : field,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = AppColors.heading(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: flightTicketingBackgroundAsset,
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 72, 16, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Transform.translate(
                          offset: const Offset(-40, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox.square(
                                dimension: 46,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.accent(context),
                                      width: AppColors.selectionStrokeWidth,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.flight,
                                    color: AppColors.accent(context),
                                    size: 23,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  l10n.flightTicketing,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: heading,
                                    fontSize: 28,
                                    height: 1.28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        GlassPanel(
                          borderRadius: 28,
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _TripTypeSelector(
                                  value: _tripType,
                                  oneWayLabel: l10n.flightOneWay,
                                  roundTripLabel: l10n.flightRoundTrip,
                                  onChanged: (value) => setState(() {
                                    _tripType = value;
                                    if (value == FlightTripType.oneWay) {
                                      _returnDate = null;
                                    }
                                  }),
                                ),
                                const SizedBox(height: 18),
                                FlightAirportField(
                                  controller: _originController,
                                  airport: _origin,
                                  label: l10n.flightFrom,
                                  prefixIcon: Icons.flight_takeoff_outlined,
                                  service: _airportSearchService,
                                  open: _openAirportField == 'from',
                                  onToggle: () => _toggleAirportField('from'),
                                  onChanged: (airport) => setState(() {
                                    _origin = airport;
                                    if (airport != null) {
                                      _openAirportField = null;
                                    }
                                  }),
                                  validator: (_) => _origin == null
                                      ? l10n.flightOriginRequired
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                FlightAirportField(
                                  controller: _destinationController,
                                  airport: _destination,
                                  label: l10n.flightTo,
                                  prefixIcon: Icons.flight_land_outlined,
                                  service: _airportSearchService,
                                  open: _openAirportField == 'to',
                                  onToggle: () => _toggleAirportField('to'),
                                  onChanged: (airport) => setState(() {
                                    _destination = airport;
                                    if (airport != null) {
                                      _openAirportField = null;
                                    }
                                  }),
                                  validator: (_) {
                                    if (_destination == null) {
                                      return l10n.flightDestinationRequired;
                                    }
                                    if (_origin?.id == _destination?.id ||
                                        _origin?.iataCode ==
                                            _destination?.iataCode) {
                                      return l10n.flightDifferentAirports;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (_tripType == FlightTripType.oneWay)
                                  _DateField(
                                    label: l10n.flightDepartureDate,
                                    value: _formatDate(context, _departureDate),
                                    onTap: _pickDepartureDate,
                                    validator: (_) => _departureDate == null
                                        ? l10n.flightDepartureRequired
                                        : null,
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DateField(
                                          label: l10n.flightDepartureDate,
                                          value: _formatDate(
                                            context,
                                            _departureDate,
                                          ),
                                          onTap: _pickDepartureDate,
                                          compact: true,
                                          validator: (_) =>
                                              _departureDate == null
                                              ? l10n.flightDepartureRequired
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _DateField(
                                          label: l10n.flightReturnDate,
                                          value: _formatDate(
                                            context,
                                            _returnDate,
                                          ),
                                          onTap: _pickReturnDate,
                                          compact: true,
                                          validator: (_) => _returnDate == null
                                              ? l10n.flightReturnRequired
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 12),
                                _FlightGlass(
                                  depth: GlassDepth.middle,
                                  borderRadius: 14,
                                  onTap: _showPassengerAndCabinPicker,
                                  child: SizedBox(
                                    height: 64,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.people_outline,
                                            color: AppColors.accent(context),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              l10n.flightPassengerSummary(
                                                _adults,
                                                _children,
                                                _infants,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: heading,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 34,
                                            color: Colors.white.withValues(
                                              alpha: 0.65,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              l10n.flightSearchCabinClassLabel(
                                                _cabinClass,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: heading,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            color: heading,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _FlightGlass(
                                  depth: GlassDepth.middle,
                                  borderRadius: 14,
                                  selected: _directOnly,
                                  child: SwitchListTile.adaptive(
                                    value: _directOnly,
                                    onChanged: (value) =>
                                        setState(() => _directOnly = value),
                                    activeThumbColor: AppColors.accent(context),
                                    title: Text(
                                      l10n.flightDirectOnly,
                                      style: TextStyle(
                                        color: heading,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    secondary: Icon(
                                      Icons.route_outlined,
                                      color: AppColors.accent(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                PrimaryButton(
                                  label: _searching
                                      ? l10n.flightSearching
                                      : l10n.flightSearch,
                                  onTap: _searching ? null : _search,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 8,
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-way / Round trip, drawn as the same sliding pill the Language screen's
/// [ThemeModeToggle] uses: one glass pill with a thumb that animates under the
/// selected half, rather than two separate glass buttons.
class _TripTypeSelector extends StatelessWidget {
  const _TripTypeSelector({
    required this.value,
    required this.oneWayLabel,
    required this.roundTripLabel,
    required this.onChanged,
  });

  final FlightTripType value;
  final String oneWayLabel;
  final String roundTripLabel;
  final ValueChanged<FlightTripType> onChanged;

  /// Same gap the theme toggle leaves between thumb and pill edge.
  static const double _thumbInset = 4;
  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The toggle's own tokens, so the two controls read as one component
    // family in both themes.
    final thumbColor = isDark
        ? AppColors.luminousMint
        : Colors.white.withValues(alpha: 0.95);
    final activeLabel = isDark ? AppColors.darkOnPrimary : AppColors.actionNavy;
    final inactiveLabel = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.actionNavy.withValues(alpha: 0.45);

    return AppLiquidGlass(
      shape: AppLiquidGlassShape.pill,
      dark: isDark,
      quality: AppLiquidGlassQuality.standard,
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final thumbWidth = (constraints.maxWidth - _thumbInset * 2) / 2;
            return Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  // Directional, so the thumb still tracks the selected label
                  // when the app is laid out right-to-left.
                  alignment: value == FlightTripType.oneWay
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.all(_thumbInset),
                    child: Container(
                      width: thumbWidth,
                      height: _height - (_thumbInset * 2),
                      decoration: BoxDecoration(
                        color: thumbColor,
                        borderRadius: BorderRadius.circular(1000),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final type in FlightTripType.values)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: value == type,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(type),
                              child: Center(
                                child: Text(
                                  type == FlightTripType.oneWay
                                      ? oneWayLabel
                                      : roundTripLabel,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: value == type
                                        ? activeLabel
                                        : inactiveLabel,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.validator,
    this.compact = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? Function(String?) validator;
  final bool compact;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final nextValue = widget.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.text != nextValue) {
        _controller.text = nextValue;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppRecessedGlassField(
      controller: _controller,
      hint: widget.label,
      prefixIcon: Icons.calendar_month_outlined,
      readOnly: true,
      compact: widget.compact,
      onTap: widget.onTap,
      validator: widget.validator,
    );
  }
}

class _PassengerStepper extends StatelessWidget {
  const _PassengerStepper({
    required this.icon,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => _FlightGlass(
    depth: GlassDepth.top,
    borderRadius: 14,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.heading(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _RoundIconButton(icon: Icons.remove, onTap: onMinus),
          SizedBox(
            width: 42,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.heading(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _RoundIconButton(icon: Icons.add, onTap: onPlus),
        ],
      ),
    ),
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return IconButton.outlined(
      onPressed: onTap,
      icon: Icon(icon),
      color: accent,
      disabledColor: accent.withValues(alpha: 0.40),
      style: IconButton.styleFrom(
        side: BorderSide(
          color: (onTap == null ? accent.withValues(alpha: 0.28) : accent),
        ),
      ),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}

class _CabinOption extends StatelessWidget {
  const _CabinOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _FlightGlass(
    depth: GlassDepth.top,
    borderRadius: 14,
    selected: selected,
    onTap: onTap,
    child: SizedBox(
      height: 58,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected
                ? AppColors.selectionAccent(context)
                : AppColors.heading(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.heading(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PassengerCabinSelection {
  const _PassengerCabinSelection({
    required this.adults,
    required this.children,
    required this.infants,
    required this.cabinClass,
  });

  final int adults;
  final int children;
  final int infants;
  final CabinClass cabinClass;
}

/// Flight-local interactive glass wrapper. The page deliberately specifies
/// depth at every nested surface so L1 → L2 → L3 never collapses into one
/// flat blur recipe.
class _FlightGlass extends StatelessWidget {
  const _FlightGlass({
    required this.child,
    required this.depth,
    this.borderRadius = 28,
    this.selected = false,
    this.onTap,
  });

  final Widget child;
  final GlassDepth depth;
  final double borderRadius;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );
    final glass = GlassPanel(
      depth: depth,
      borderRadius: borderRadius,
      selected: selected,
      child: child,
    );
    if (onTap == null) return glass;
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, customBorder: shape, child: glass),
    );
  }
}
