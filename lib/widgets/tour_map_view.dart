import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../config/tour_map_config.dart';
import '../l10n/app_localizations.dart';
import '../models/map_place.dart';
import '../theme/app_colors.dart';

bool get tourMapSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// A small public camera handle that keeps MapLibre types out of callers.
class TourMapViewController {
  MapLibreMapController? _controller;

  Future<void> animateTo({
    required double latitude,
    required double longitude,
    required double zoom,
  }) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), zoom),
      duration: const Duration(milliseconds: 700),
    );
  }
}

/// Shared MapLibre renderer for the Explore Tours preview card and full map.
class TourMapView extends StatefulWidget {
  const TourMapView({
    super.key,
    required this.places,
    this.controller,
    this.initialLatitude = TourMapConfig.erbilLatitude,
    this.initialLongitude = TourMapConfig.erbilLongitude,
    this.initialZoom = TourMapConfig.cityZoom,
    this.interactive = true,
    this.showUserLocation = false,
    this.onPlaceSelected,
  });

  final List<MapPlace> places;
  final TourMapViewController? controller;
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final bool interactive;
  final bool showUserLocation;
  final ValueChanged<MapPlace>? onPlaceSelected;

  @override
  State<TourMapView> createState() => _TourMapViewState();
}

class _TourMapViewState extends State<TourMapView> {
  MapLibreMapController? _mapController;
  Timer? _loadTimer;
  bool _styleLoaded = false;
  bool _failed = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _startLoadTimer();
  }

  @override
  void didUpdateWidget(TourMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded && !listEquals(oldWidget.places, widget.places)) {
      unawaited(_syncMarkers());
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._controller = null;
      widget.controller?._controller = _styleLoaded ? _mapController : null;
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    widget.controller?._controller = null;
    final controller = _mapController;
    if (controller != null) {
      controller.onSymbolTapped.remove(_onSymbolTapped);
    }
    super.dispose();
  }

  void _startLoadTimer() {
    _loadTimer?.cancel();
    if (!tourMapSupported) return;
    _loadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_styleLoaded) setState(() => _failed = true);
    });
  }

  void _retry() {
    setState(() {
      _failed = false;
      _styleLoaded = false;
      _mapController = null;
      _revision++;
    });
    _startLoadTimer();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;
    _loadTimer?.cancel();
    controller.onSymbolTapped.add(_onSymbolTapped);
    widget.controller?._controller = controller;
    try {
      await _syncMarkers();
      if (mounted) {
        setState(() {
          _styleLoaded = true;
          _failed = false;
        });
      }
    } catch (error) {
      debugPrint('Could not prepare tour map markers: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _syncMarkers() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.clearSymbols();
    if (widget.places.isEmpty) return;

    final categories = widget.places.map((place) => place.category).toSet();
    for (final category in categories) {
      await controller.addImage(
        _iconName(category),
        await _markerBytes(category),
      );
    }
    await controller.setSymbolIconAllowOverlap(true);
    await controller.addSymbols(
      widget.places
          .map(
            (place) => SymbolOptions(
              geometry: LatLng(place.latitude, place.longitude),
              iconImage: _iconName(place.category),
              iconSize: 0.58,
              iconAnchor: 'bottom',
            ),
          )
          .toList(growable: false),
      widget.places
          .map((place) => <String, dynamic>{'placeId': place.id})
          .toList(growable: false),
    );
  }

  void _onSymbolTapped(Symbol symbol) {
    final id = symbol.data?['placeId'];
    if (id is! String) return;
    for (final place in widget.places) {
      if (place.id == id) {
        widget.onPlaceSelected?.call(place);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!tourMapSupported || _failed) {
      return ColoredBox(
        key: const ValueKey('tour-map-unavailable'),
        color: AppColors.glassBaseTint(context).withValues(alpha: .22),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.tourMapUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
                if (tourMapSupported) ...[
                  const SizedBox(height: 6),
                  TextButton(onPressed: _retry, child: Text(l10n.tryAgain)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          key: ValueKey('tour-maplibre-map-$_revision'),
          styleString: TourMapConfig.styleUrl,
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.initialLatitude, widget.initialLongitude),
            zoom: widget.initialZoom,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          myLocationEnabled: widget.showUserLocation,
          myLocationRenderMode: MyLocationRenderMode.normal,
          compassEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          foregroundLoadColor: AppColors.glassBaseTint(context),
        ),
        if (!_styleLoaded)
          ColoredBox(
            color: AppColors.glassBaseTint(context).withValues(alpha: .38),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

String _iconName(MapPlaceCategory category) => 'map-place-${category.name}';

IconData _categoryIcon(MapPlaceCategory category) => switch (category) {
  MapPlaceCategory.tour => Icons.hiking_rounded,
  MapPlaceCategory.nature => Icons.landscape_rounded,
  MapPlaceCategory.hotel => Icons.hotel_rounded,
  MapPlaceCategory.restaurant => Icons.restaurant_rounded,
  MapPlaceCategory.attraction => Icons.account_balance_rounded,
  MapPlaceCategory.airport => Icons.flight_rounded,
  MapPlaceCategory.carRental => Icons.directions_car_rounded,
  MapPlaceCategory.camping => Icons.cabin_rounded,
  MapPlaceCategory.activity => Icons.local_activity_rounded,
};

Color _categoryColor(MapPlaceCategory category) => switch (category) {
  MapPlaceCategory.tour => const Color(0xFF007F73),
  MapPlaceCategory.nature => const Color(0xFF2E7D32),
  MapPlaceCategory.hotel => const Color(0xFF3949AB),
  MapPlaceCategory.restaurant => const Color(0xFFE65100),
  MapPlaceCategory.attraction => const Color(0xFF6A1B9A),
  MapPlaceCategory.airport => const Color(0xFF1565C0),
  MapPlaceCategory.carRental => const Color(0xFF455A64),
  MapPlaceCategory.camping => const Color(0xFF558B2F),
  MapPlaceCategory.activity => const Color(0xFFC62828),
};

Future<Uint8List> _markerBytes(MapPlaceCategory category) async {
  const width = 96.0;
  const height = 112.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final color = _categoryColor(category);

  canvas.drawCircle(
    const Offset(48, 48),
    38,
    Paint()
      ..color = Colors.black.withValues(alpha: .25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  final pin = Path()
    ..moveTo(48, 108)
    ..cubicTo(39, 89, 12, 69, 12, 45)
    ..arcToPoint(
      const Offset(84, 45),
      radius: const Radius.circular(36),
      clockwise: true,
    )
    ..cubicTo(84, 69, 57, 89, 48, 108)
    ..close();
  canvas.drawPath(pin, Paint()..color = color);
  canvas.drawCircle(const Offset(48, 45), 25, Paint()..color = Colors.white);

  final icon = _categoryIcon(category);
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 31,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(48 - painter.width / 2, 45 - painter.height / 2),
  );

  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('Could not render map marker');
  return data.buffer.asUint8List();
}
