/// Configuration for the key-free map used by the Explore Tours flow.
///
/// The basemap style itself is not here: it depends on the app theme, so it
/// lives in `AppMapStyle` (`lib/theme/app_map_style.dart`) with the rest of the
/// theme-driven visual decisions. Coordinates and zoom levels are the same in
/// both themes and stay here.
abstract final class TourMapConfig {
  static const double erbilLatitude = 36.1901;
  static const double erbilLongitude = 44.0091;
  static const double cityZoom = 10.5;
  static const double placeZoom = 13.5;
  static const double userZoom = 15;
}
