import 'package:geolocator/geolocator.dart';

enum TourMapLocationStatus {
  available,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

class TourMapLocationResult {
  const TourMapLocationResult._(this.status, {this.latitude, this.longitude});

  const TourMapLocationResult.available(double latitude, double longitude)
    : this._(
        TourMapLocationStatus.available,
        latitude: latitude,
        longitude: longitude,
      );

  const TourMapLocationResult.unavailable(TourMapLocationStatus status)
    : this._(status);

  final TourMapLocationStatus status;
  final double? latitude;
  final double? longitude;

  bool get isAvailable => status == TourMapLocationStatus.available;
}

/// Foreground-only location access for the Explore Tours map.
///
/// Unlike the silent distance helper used by catalog cards, this service
/// returns an explicit state so the map can explain disabled GPS or denied
/// permission without exposing platform exceptions.
class TourMapLocationService {
  const TourMapLocationService();

  Future<TourMapLocationResult> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const TourMapLocationResult.unavailable(
          TourMapLocationStatus.servicesDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const TourMapLocationResult.unavailable(
          TourMapLocationStatus.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        return const TourMapLocationResult.unavailable(
          TourMapLocationStatus.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return TourMapLocationResult.available(
        position.latitude,
        position.longitude,
      );
    } catch (_) {
      return const TourMapLocationResult.unavailable(
        TourMapLocationStatus.failed,
      );
    }
  }
}
