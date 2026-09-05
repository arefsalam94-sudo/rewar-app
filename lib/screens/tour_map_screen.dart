import 'package:flutter/material.dart';

import '../config/tour_map_config.dart';
import '../l10n/app_localizations.dart';
import '../models/map_place.dart';
import '../models/tour.dart';
import '../services/tour_map_location_service.dart';
import '../services/tours_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/tour_map_view.dart';

/// The key-free full-screen map reached only from Explore Tours map cards.
class TourMapScreen extends StatefulWidget {
  const TourMapScreen({
    super.key,
    required this.selectedTour,
    this.toursService,
    this.locationService,
  });

  final Tour selectedTour;
  final ToursService? toursService;
  final TourMapLocationService? locationService;

  @override
  State<TourMapScreen> createState() => _TourMapScreenState();
}

class _TourMapScreenState extends State<TourMapScreen> {
  late final ToursService _toursService = widget.toursService ?? ToursService();
  late final TourMapLocationService _locationService =
      widget.locationService ?? const TourMapLocationService();
  final TourMapViewController _mapController = TourMapViewController();

  List<MapPlace> _places = const [];
  MapPlace? _selectedPlace;
  bool _loadedCatalog = false;
  bool _locating = false;
  bool _showUserLocation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedCatalog) return;
    _loadedCatalog = true;
    final language = Localizations.localeOf(context).languageCode;
    final selected = MapPlace.fromTour(widget.selectedTour, language);
    if (selected != null) {
      _places = [selected];
      _selectedPlace = selected;
    }
    _loadCatalog(language);
  }

  Future<void> _loadCatalog(String language) async {
    try {
      final tours = await _toursService.fetchCatalog();
      if (!mounted) return;
      final places = tours
          .map((tour) => MapPlace.fromTour(tour, language))
          .whereType<MapPlace>()
          .toList(growable: false);
      final selected = MapPlace.fromTour(widget.selectedTour, language);
      if (selected != null && !places.any((place) => place.id == selected.id)) {
        places.insert(0, selected);
      }
      setState(() {
        _places = places;
        _selectedPlace = places
            .where((place) => place.id == widget.selectedTour.id)
            .firstOrNull;
      });
    } catch (error) {
      // The selected tour remains usable even when the wider catalog fails.
      debugPrint('Could not load other tours for the map: $error');
    }
  }

  Future<void> _locateUser() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await _locationService.currentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.isAvailable) _showUserLocation = true;
    });

    final latitude = result.latitude;
    final longitude = result.longitude;
    if (latitude != null && longitude != null) {
      await _mapController.animateTo(
        latitude: latitude,
        longitude: longitude,
        zoom: TourMapConfig.userZoom,
      );
      return;
    }

    final l10n = AppLocalizations.of(context);
    final message = switch (result.status) {
      TourMapLocationStatus.servicesDisabled =>
        l10n.tourMapLocationServicesDisabled,
      TourMapLocationStatus.permissionDenied => l10n.tourMapPermissionDenied,
      TourMapLocationStatus.permissionDeniedForever =>
        l10n.tourMapPermissionDeniedForever,
      TourMapLocationStatus.failed => l10n.tourMapLocationFailed,
      TourMapLocationStatus.available => l10n.tourMapLocationFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selectedPlace;
    final initialLat =
        widget.selectedTour.latitude ?? TourMapConfig.erbilLatitude;
    final initialLng =
        widget.selectedTour.longitude ?? TourMapConfig.erbilLongitude;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TourMapView(
              places: _places,
              controller: _mapController,
              initialLatitude: initialLat,
              initialLongitude: initialLng,
              initialZoom: widget.selectedTour.latitude == null
                  ? TourMapConfig.cityZoom
                  : TourMapConfig.placeZoom,
              showUserLocation: _showUserLocation,
              onPlaceSelected: (place) =>
                  setState(() => _selectedPlace = place),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).pop(),
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: GlassPanel(
                    borderRadius: 28,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      l10n.tourMap,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.bottomEnd,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: 16,
                  bottom: selected == null ? 20 : 222,
                ),
                child: Semantics(
                  button: true,
                  label: l10n.tourMapMyLocation,
                  child: Material(
                    color: AppColors.glassBaseTint(context),
                    elevation: 5,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _locating ? null : _locateUser,
                      child: SizedBox.square(
                        dimension: 52,
                        child: _locating
                            ? const Padding(
                                padding: EdgeInsets.all(15),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Icon(
                                Icons.my_location_rounded,
                                color: AppColors.heading(context),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selected != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _TourMapPlaceCard(
                  place: selected,
                  onViewDetails: () => Navigator.of(context).pop(selected.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TourMapPlaceCard extends StatelessWidget {
  const _TourMapPlaceCard({required this.place, required this.onViewDetails});

  final MapPlace place;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: GlassPanel(
        borderRadius: 26,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent(context).withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hiking_rounded,
                    color: AppColors.accent(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading(context),
                        ),
                      ),
                      Text(
                        l10n.tourMapTourCategory,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.heading(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (place.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.secondaryText(context),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (place.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                place.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.heading(context),
                ),
              ),
            ],
            const SizedBox(height: 10),
            PrimaryButton(label: l10n.tourMapViewDetails, onTap: onViewDetails),
          ],
        ),
      ),
    );
  }
}
