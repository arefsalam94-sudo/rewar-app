import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/map_availability.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';

/// A native, interactive Google Map shown entirely inside the app.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.target, this.title});

  /// An optional place to open on and pin. When given, the map does **not**
  /// recentre on the device — the user asked to see this place, not where they
  /// are standing. The Map tab passes nothing and keeps the old behaviour.
  final LatLng? target;

  /// Header label. Defaults to the Map tab's own title.
  final String? title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Erbil is a useful regional fallback while location is unavailable.
  static const LatLng _fallbackLocation = LatLng(36.1911, 44.0092);
  static const double _fallbackZoom = 11;
  static const double _userZoom = 15;
  static const double _targetZoom = 13.5;

  GoogleMapController? _controller;
  LatLng? _userLocation;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    if (googleMapsAvailable) {
      _centerOnCurrentLocation();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
      setState(() => _userLocation = location);
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(location, _userZoom),
      );
    } catch (error) {
      // The fallback map remains fully usable when GPS is unavailable.
      debugPrint('Could not determine the current map location: $error');
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    final location = _userLocation;
    if (location != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(location, _userZoom),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: googleMapsAvailable
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: widget.target ?? _fallbackLocation,
                      zoom: widget.target == null ? _fallbackZoom : _targetZoom,
                    ),
                    markers: {
                      if (widget.target != null)
                        Marker(
                          markerId: const MarkerId('map-target'),
                          position: widget.target!,
                        ),
                    },
                    onMapCreated: _onMapCreated,
                    myLocationEnabled: _locationPermissionGranted,
                    myLocationButtonEnabled: _locationPermissionGranted,
                    compassEnabled: true,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                  )
                : ColoredBox(
                    color: AppColors.glassBaseTint(
                      context,
                    ).withValues(alpha: .22),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).hotelMapUnavailable,
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                        ),
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
                  child: GlassPanel(
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
