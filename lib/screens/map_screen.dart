import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../l10n/app_localizations.dart';
import '../config/tour_map_config.dart';
import '../models/map_place.dart';
import '../widgets/tour_map_view.dart';
import '../theme/app_colors.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/liquid_glass_surface.dart';

/// The shared interactive map used by the main navigation and place details.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.target,
    this.title,
    this.category = MapPlaceCategory.attraction,
  });

  /// An optional place to open on and pin. When given, the map does **not**
  /// recentre on the device — the user asked to see this place, not where they
  /// are standing. The Map tab passes nothing and keeps the old behaviour.
  final LatLng? target;
  final MapPlaceCategory category;

  /// Header label. Defaults to the Map tab's own title.
  final String? title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Erbil is a useful regional fallback while location is unavailable.
  static const LatLng _fallbackLocation = LatLng(
    TourMapConfig.erbilLatitude,
    TourMapConfig.erbilLongitude,
  );
  static const double _fallbackZoom = TourMapConfig.cityZoom;
  static const double _userZoom = 15;
  static const double _targetZoom = 13.5;

  final TourMapViewController _controller = TourMapViewController();
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    if (tourMapSupported) {
      _centerOnCurrentLocation();
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    // A place was requested explicitly; recentring on the device would move the
    // camera off it a second after it opened.
    if (widget.target != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      if (mounted) {
        setState(() => _locationPermissionGranted = true);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);
      await _controller.animateTo(
        latitude: location.latitude,
        longitude: location.longitude,
        zoom: _userZoom,
      );
    } catch (error) {
      // The fallback map remains fully usable when GPS is unavailable.
      debugPrint('Could not determine the current map location: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TourMapView(
              controller: _controller,
              initialLatitude:
                  widget.target?.latitude ?? _fallbackLocation.latitude,
              initialLongitude:
                  widget.target?.longitude ?? _fallbackLocation.longitude,
              initialZoom: widget.target == null ? _fallbackZoom : _targetZoom,
              showUserLocation: _locationPermissionGranted,
              places: [
                if (widget.target != null)
                  MapPlace(
                    id: 'map-target',
                    name: widget.title ?? '',
                    latitude: widget.target!.latitude,
                    longitude: widget.target!.longitude,
                    category: widget.category,
                  ),
              ],
            ),
          ),
          if (_locationPermissionGranted)
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingActionButton.small(
                    tooltip: AppLocalizations.of(context).tourMapMyLocation,
                    onPressed: _centerOnCurrentLocation,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GlassBackButton(
                  useAppLiquidGlass: true,
                  useCanonicalGlass: true,
                  onTap: () => Navigator.of(context).pop(),
                  dark: isDark,
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
                  child: AppLiquidGlass(
                    useCanonicalGlass: true,
                    layer: GlassLayer.surface,
                    borderRadius: 28,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      widget.title ?? AppLocalizations.of(context).navMap,
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
        ],
      ),
    );
  }
}
