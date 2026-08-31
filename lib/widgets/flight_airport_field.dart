import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/airport.dart';
import '../services/airport_search_service.dart';
import '../theme/app_colors.dart';
import 'app_recessed_glass_field.dart';
import 'glass_panel.dart';

/// A read-only airport field whose picker expands in place beneath it.
///
/// Behaves like the Car Rental location fields: the visible field shows the
/// chosen airport and is not typed into, and tapping it opens a search panel
/// directly under the field rather than a modal sheet over the page. The
/// criteria stay backed by a real IATA airport, because the only way to fill
/// the field is to pick one from the results.
class FlightAirportField extends StatefulWidget {
  const FlightAirportField({
    super.key,
    required this.controller,
    required this.airport,
    required this.label,
    required this.prefixIcon,
    required this.service,
    required this.open,
    required this.onToggle,
    required this.onChanged,
    required this.validator,
  });

  /// Holds the display text of the chosen airport, so the surrounding [Form]
  /// still validates and resets through the usual controller.
  final TextEditingController controller;
  final Airport? airport;
  final String label;
  final IconData prefixIcon;
  final AirportSearchService service;

  /// Whether this field's search panel is the open one. The screen owns the
  /// flag so From and To can never be expanded at the same time.
  final bool open;
  final VoidCallback onToggle;

  final ValueChanged<Airport?> onChanged;
  final String? Function(String?) validator;

  @override
  State<FlightAirportField> createState() => _FlightAirportFieldState();
}

class _FlightAirportFieldState extends State<FlightAirportField> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  List<Airport> _results = const [];
  bool _queryReady = false;
  bool _loading = false;
  bool _failed = false;
  int _revision = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  static String display(Airport airport) =>
      '${airport.iataCode} · ${airport.displayName}';

  void _changed(String value) {
    _debounce?.cancel();
    final revision = ++_revision;
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _queryReady = false;
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _queryReady = true;
      _loading = true;
      _failed = false;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.service.search(query);
        if (!mounted || revision != _revision) return;
        setState(() {
          _results = results;
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

  void _select(Airport airport) {
    widget.controller.text = display(airport);
    widget.onChanged(airport);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppRecessedGlassField(
          controller: widget.controller,
          hint: widget.label,
          prefixIcon: widget.prefixIcon,
          validator: widget.validator,
          readOnly: true,
          onTap: widget.onToggle,
          suffix: widget.airport == null
              ? const Icon(Icons.search)
              : IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged(null);
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
        AnimatedSize(
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
                          controller: _queryController,
                          hint: l10n.flightAirportSearchHint,
                          prefixIcon: Icons.search,
                          autofocus: true,
                          onChanged: _changed,
                        ),
                        const SizedBox(height: 10),
                        // The panel lives inside the page scroll view, so the
                        // list is capped and scrolls on its own rather than
                        // pushing the rest of the form off-screen.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: _AirportResults(
                            loading: _loading,
                            failed: _failed,
                            queryReady: _queryReady,
                            results: _results,
                            onRetry: () => _changed(_queryController.text),
                            onSelected: _select,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AirportResults extends StatelessWidget {
  const _AirportResults({
    required this.loading,
    required this.failed,
    required this.queryReady,
    required this.results,
    required this.onRetry,
    required this.onSelected,
    required this.l10n,
  });

  final bool loading;
  final bool failed;
  final bool queryReady;
  final List<Airport> results;
  final VoidCallback onRetry;
  final ValueChanged<Airport> onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (failed) {
      return _AirportMessage(
        message: l10n.flightAirportLoadFailed,
        action: TextButton(onPressed: onRetry, child: Text(l10n.flightRetry)),
      );
    }
    if (!queryReady) {
      return _AirportMessage(message: l10n.flightAirportStartTyping);
    }
    if (results.isEmpty) {
      return _AirportMessage(message: l10n.flightNoAirportsFound);
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final airport = results[index];
        return GlassPanel(
          depth: GlassDepth.top,
          borderRadius: 14,
          child: ListTile(
            onTap: () => onSelected(airport),
            leading: CircleAvatar(
              backgroundColor: AppColors.accent(
                context,
              ).withValues(alpha: 0.15),
              foregroundColor: AppColors.accent(context),
              child: Text(
                airport.iataCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              airport.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                airport.city,
                airport.country,
              ].where((item) => item.isNotEmpty).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

class _AirportMessage extends StatelessWidget {
  const _AirportMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.travel_explore, color: AppColors.accent(context)),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
