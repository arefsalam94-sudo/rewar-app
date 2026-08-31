import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/flight_offer.dart';
import '../models/flight_search_criteria.dart';
import '../services/currency_rates_service.dart';
import '../services/flight_results_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';

const String flightResultsBackgroundAsset =
    'assets/images/flight ticketing - background.webp';

class FlightSearchResultsScreen extends StatefulWidget {
  const FlightSearchResultsScreen({
    super.key,
    required this.criteria,
    this.service = const MockFlightResultsService(),
    this.onSelected,
  });

  final FlightSearchCriteria criteria;
  final FlightResultsService service;
  final ValueChanged<FlightResultsSelection>? onSelected;

  @override
  State<FlightSearchResultsScreen> createState() =>
      _FlightSearchResultsScreenState();
}

class _FlightSearchResultsScreenState extends State<FlightSearchResultsScreen> {
  late FlightSearchCriteria _criteria = widget.criteria;
  FlightOfferSort _sort = FlightOfferSort.best;
  List<FlightOffer>? _offers;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _offers = null;
      _error = null;
    });
    try {
      final offers = await widget.service.search(_criteria);
      if (mounted) setState(() => _offers = offers);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _changeDate(int days) async {
    final current = DateUtils.dateOnly(_criteria.departureDate);
    final candidate = current.add(Duration(days: days));
    final today = DateUtils.dateOnly(DateTime.now());
    if (candidate.isBefore(today)) return;
    final returnDate = _criteria.returnDate;
    if (_criteria.tripType == FlightTripType.roundTrip &&
        returnDate != null &&
        !candidate.isBefore(DateUtils.dateOnly(returnDate))) {
      return;
    }
    setState(() => _criteria = _criteria.copyWith(departureDate: candidate));
    await _load();
  }

  Future<void> _select(FlightOffer offer) async {
    final selection = FlightResultsSelection(criteria: _criteria, offer: offer);
    final callback = widget.onSelected;
    if (callback != null) {
      callback(selection);
      return;
    }
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassPanel(
          depth: GlassDepth.middle,
          borderRadius: 28,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.accent(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.flightOfferSelected,
                  style: TextStyle(
                    color: AppColors.heading(context),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canMoveBack {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(_criteria.departureDate).isAfter(today);
  }

  bool get _canMoveForward {
    final returnDate = _criteria.returnDate;
    if (_criteria.tripType != FlightTripType.roundTrip || returnDate == null) {
      return true;
    }
    return DateUtils.dateOnly(
      _criteria.departureDate,
    ).add(const Duration(days: 1)).isBefore(DateUtils.dateOnly(returnDate));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: flightResultsBackgroundAsset,
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 68, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SearchSummary(
                          criteria: _criteria,
                          canMoveBack: _canMoveBack,
                          canMoveForward: _canMoveForward,
                          onPrevious: () => _changeDate(-1),
                          onNext: () => _changeDate(1),
                        ),
                        const SizedBox(height: 24),
                        _ResultsBody(
                          offers: _offers,
                          error: _error,
                          sort: _sort,
                          onSort: (value) => setState(() => _sort = value),
                          onRetry: _load,
                          onSelect: _select,
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

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({
    required this.criteria,
    required this.canMoveBack,
    required this.canMoveForward,
    required this.onPrevious,
    required this.onNext,
  });

  final FlightSearchCriteria criteria;
  final bool canMoveBack;
  final bool canMoveForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = AppColors.heading(context);
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(criteria.departureDate);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      child: Column(
        children: [
          Text(
            '${criteria.origin.displayName} – ${criteria.destination.displayName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: heading,
              fontSize: 24,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.flightPassengerSummary(criteria.adults, criteria.children, criteria.infants)} · ${l10n.flightSearchCabinClassLabel(criteria.cabinClass)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            children: [
              _DateArrow(
                tooltip: l10n.flightPreviousDate,
                icon: Icons.chevron_left,
                onTap: canMoveBack ? onPrevious : null,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _OutlinedFeatureIcon(icon: Icons.calendar_month_outlined),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        date,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: heading,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _DateArrow(
                tooltip: l10n.flightNextDate,
                icon: Icons.chevron_right,
                onTap: canMoveForward ? onNext : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.offers,
    required this.error,
    required this.sort,
    required this.onSort,
    required this.onRetry,
    required this.onSelect,
  });

  final List<FlightOffer>? offers;
  final Object? error;
  final FlightOfferSort sort;
  final ValueChanged<FlightOfferSort> onSort;
  final VoidCallback onRetry;
  final ValueChanged<FlightOffer> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: l10n.flightResultsLoadFailed,
        body: l10n.flightResultsEmptyBody,
        actionLabel: l10n.flightRetry,
        onAction: onRetry,
      );
    }
    final source = offers;
    if (source == null) return const _LoadingResults();
    if (source.isEmpty) {
      return _MessageState(
        icon: Icons.airplanemode_inactive,
        title: l10n.flightResultsEmptyTitle,
        body: l10n.flightResultsEmptyBody,
        actionLabel: l10n.flightRetry,
        onAction: onRetry,
      );
    }
    final sorted = source.sortedBy(sort);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _OutlinedFeatureIcon(icon: Icons.search),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n.flightResultsFound(source.length),
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SortRow(offers: source, selected: sort, onChanged: onSort),
        const SizedBox(height: 24),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 16),
        for (var index = 0; index < sorted.length; index++) ...[
          _FlightOfferCard(offer: sorted[index], onSelect: onSelect),
          if (index != sorted.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.offers,
    required this.selected,
    required this.onChanged,
  });

  final List<FlightOffer> offers;
  final FlightOfferSort selected;
  final ValueChanged<FlightOfferSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = FlightOfferSort.values
            .map((sort) {
              final offer = offers.sortedBy(sort).first;
              final label = switch (sort) {
                FlightOfferSort.best => l10n.flightSortBest,
                FlightOfferSort.cheapest => l10n.flightSortCheapest,
                FlightOfferSort.fastest => l10n.flightSortFastest,
              };
              return SizedBox(
                width: constraints.maxWidth < 380
                    ? 116
                    : (constraints.maxWidth - 24) / 3,
                child: _SortCard(
                  label: label,
                  offer: offer,
                  selected: selected == sort,
                  onTap: () => onChanged(sort),
                ),
              );
            })
            .toList(growable: false);
        if (constraints.maxWidth < 380) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SortCard extends StatelessWidget {
  const _SortCard({
    required this.label,
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final FlightOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _InteractiveGlass(
    selected: selected,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.heading(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              _price(offer),
              style: TextStyle(
                color: AppColors.heading(context),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _duration(offer.totalDurationMinutes),
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
        ],
      ),
    ),
  );
}

class _FlightOfferCard extends StatelessWidget {
  const _FlightOfferCard({required this.offer, required this.onSelect});

  final FlightOffer offer;
  final ValueChanged<FlightOffer> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _OutlinedFeatureIcon(icon: Icons.flight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  offer.airlineName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.heading(context),
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (offer.outbound.flightNumber != null)
                Text(
                  offer.outbound.flightNumber!,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SegmentRow(segment: offer.outbound, label: l10n.flightOutbound),
          if (offer.returnSegment != null) ...[
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            _SegmentRow(
              segment: offer.returnSegment!,
              label: l10n.flightReturn,
              reverseDirection: true,
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _price(offer),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: AppColors.heading(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      offer.priceIsTotal
                          ? l10n.flightTotalPrice
                          : l10n.flightPerTraveler,
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => onSelect(offer),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent(context),
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkOnPrimary
                        : Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(
                    l10n.flightSelect,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.segment,
    required this.label,
    this.reverseDirection = false,
  });

  final FlightSegment segment;
  final String label;
  final bool reverseDirection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localizations = MaterialLocalizations.of(context);
    final heading = AppColors.heading(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.secondaryText(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              _TimeAndCode(
                time: localizations.formatTimeOfDay(
                  TimeOfDay.fromDateTime(segment.departure),
                  alwaysUse24HourFormat: true,
                ),
                code: segment.originCode,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        _duration(segment.durationMinutes),
                        style: TextStyle(color: heading, fontSize: 13),
                      ),
                      Row(
                        children: [
                          if (reverseDirection)
                            Icon(Icons.arrow_back, color: heading, size: 18),
                          Expanded(child: Divider(color: heading)),
                          if (!reverseDirection)
                            Icon(Icons.arrow_forward, color: heading, size: 18),
                        ],
                      ),
                      Text(
                        l10n.flightStops(segment.stops),
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _TimeAndCode(
                time: localizations.formatTimeOfDay(
                  TimeOfDay.fromDateTime(segment.arrival),
                  alwaysUse24HourFormat: true,
                ),
                code: segment.destinationCode,
                trailing: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeAndCode extends StatelessWidget {
  const _TimeAndCode({
    required this.time,
    required this.code,
    this.trailing = false,
  });

  final String time;
  final String code;
  final bool trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: trailing
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        time,
        style: TextStyle(
          color: AppColors.heading(context),
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        code,
        style: TextStyle(
          color: AppColors.secondaryText(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _DateArrow extends StatelessWidget {
  const _DateArrow({required this.tooltip, required this.icon, this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon),
    color: AppColors.heading(context),
    disabledColor: AppColors.heading(context).withValues(alpha: 0.40),
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
  );
}

class _OutlinedFeatureIcon extends StatelessWidget {
  const _OutlinedFeatureIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 46,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent(context),
          width: AppColors.selectionStrokeWidth,
        ),
      ),
      child: Icon(icon, color: AppColors.accent(context), size: 23),
    ),
  );
}

class _InteractiveGlass extends StatelessWidget {
  const _InteractiveGlass({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = 22.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: GlassPanel(
          depth: GlassDepth.middle,
          borderRadius: radius,
          selected: selected,
          child: child,
        ),
      ),
    );
  }
}

class _LoadingResults extends StatelessWidget {
  const _LoadingResults();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: CircularProgressIndicator(color: AppColors.accent(context)),
      ),
      for (var index = 0; index < 3; index++) ...[
        GlassPanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 112,
            child: Center(
              child: Icon(
                Icons.flight_outlined,
                color: AppColors.secondaryText(context),
              ),
            ),
          ),
        ),
        if (index != 2) const SizedBox(height: 14),
      ],
    ],
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        _OutlinedFeatureIcon(icon: icon),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText(context)),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ),
  );
}

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}m';
}

String _price(FlightOffer offer) {
  final symbol = CurrencyRatesService.symbolFor(offer.currency);
  final amount = offer.totalPrice == offer.totalPrice.roundToDouble()
      ? offer.totalPrice.toStringAsFixed(0)
      : offer.totalPrice.toStringAsFixed(2);
  return symbol.length == 1 ? '$symbol$amount' : '$symbol $amount';
}
