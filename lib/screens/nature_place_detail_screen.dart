import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/map_availability.dart';

import '../l10n/app_localizations.dart';
import '../models/nature_detail.dart';
import '../models/nature_spot.dart';
import '../services/device_location_service.dart';
import '../services/nature_spots_service.dart';
import '../services/place_weather_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import 'customize_filters_screen.dart' show exploreNatureBackgroundAsset;
import 'map_screen.dart';
import 'nature_reviews_screen.dart';

/// Detail page opened from any Explore Nature place.
class NaturePlaceDetailScreen extends StatefulWidget {
  const NaturePlaceDetailScreen({
    super.key,
    required this.spot,
    this.natureSpotsService,
    this.locationService,
    this.weatherService,
    this.onReviewsTap,
    this.onStayTap,
  });

  final NatureSpot spot;
  final NatureSpotsService? natureSpotsService;
  final DeviceLocationService? locationService;
  final PlaceWeatherService? weatherService;
  final VoidCallback? onReviewsTap;
  final ValueChanged<NearbyStay>? onStayTap;

  @override
  State<NaturePlaceDetailScreen> createState() =>
      _NaturePlaceDetailScreenState();
}

class _NaturePlaceDetailScreenState extends State<NaturePlaceDetailScreen> {
  late final NatureSpotsService _service =
      widget.natureSpotsService ?? NatureSpotsService();
  late final DeviceLocationService _locationService =
      widget.locationService ?? const DeviceLocationService();
  late final PlaceWeatherService _weatherService =
      widget.weatherService ?? const PlaceWeatherService();

  /// Not `final`: it is re-issued when the user returns from the Reviews &
  /// Ratings page, which may have added or edited their review.
  late Future<List<NatureReview>> _reviewsFuture;
  Future<PlaceWeather>? _weatherFuture;
  DeviceLocation? _deviceLocation;
  final PageController _galleryController = PageController();
  int _photoIndex = 0;

  /// Taller than the old 330 because the last stretch is a fade rather than
  /// visible photo — this keeps the amount of *readable* image the same while
  /// giving the blend somewhere to happen.
  static const double _heroHeight = 400;

  /// Where the gallery starts fading out, as a fraction of [_heroHeight]. The
  /// bottom ~28% dissolves into the page background.
  static const double _heroFadeStart = 0.72;

  /// How far the About card rides up over the hero. Roughly half the card's
  /// height, so it straddles the photo and the page below it.
  static const double _cardOverlap = 120;

  /// Shared by the location and weather cards so the row reads as one band
  /// rather than two boxes with mismatched bottoms.
  static const double _sideCardHeight = 210;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _service.fetchTopReviews(widget.spot.id);
    final latitude = widget.spot.latitude;
    final longitude = widget.spot.longitude;
    if (latitude != null && longitude != null) {
      _weatherFuture = _weatherService.fetch(latitude, longitude);
    }
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final location = await _locationService.currentLocation();
    if (mounted && location != null) setState(() => _deviceLocation = location);
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final background =
        widget.spot.photosAreAssets && widget.spot.photos.isNotEmpty
        ? widget.spot.photos.first
        : exploreNatureBackgroundAsset;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: background,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // Hero and About card share one sliver on purpose. Slivers paint
              // in reverse order — an earlier sliver draws over a later one —
              // so a card pulled up from the next sliver would slide *under*
              // the photo. Inside a single Column, normal paint order applies
              // and the card sits on top of the hero it overlaps.
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Paints its full height but only claims
                    // `_heroHeight - _cardOverlap` of layout, so the card that
                    // follows starts partway up the photo.
                    SizedBox(
                      height: _heroHeight - _cardOverlap,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: _heroHeight,
                        maxHeight: _heroHeight,
                        child: _hero(language),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _AboutCard(
                        spot: widget.spot,
                        language: language,
                        distance: _distanceText(),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 28),
                sliver: SliverList.list(
                  children: [
                    if (widget.spot.nearbyStays.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHeading(
                        icon: Icons.home_outlined,
                        label: AppLocalizations.of(
                          context,
                        ).suggestedStaysNearby,
                      ),
                      const SizedBox(height: 10),
                      _NearbyStaysCard(
                        stays: widget.spot.nearbyStays,
                        language: language,
                        onTap: _openStay,
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Location and weather always share one row, side by side.
                    // They used to stack below 360dp, which is most phones —
                    // so in practice the pair was never seen as a pair.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // What each card actually gets after the 12dp gutter.
                        final cardWidth = (constraints.maxWidth - 12) / 2;
                        // Below this, the weather card's full-size type and
                        // four hour columns no longer fit the half width.
                        final compact = cardWidth < 200;
                        return Row(
                          children: [
                            Expanded(
                              child: _LocationCard(
                                spot: widget.spot,
                                onOpenMap: widget.spot.latitude == null
                                    ? null
                                    : _openMap,
                                height: _sideCardHeight,
                                compact: compact,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _WeatherCard(
                                title: widget.spot.name(language),
                                future: _weatherFuture,
                                height: _sideCardHeight,
                                compact: compact,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _ReviewsCard(
                      score: widget.spot.reviewScore,
                      count: widget.spot.ratingCount,
                      reviewsFuture: _reviewsFuture,
                      onTap: _openReviews,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(String language) {
    final photos = widget.spot.photos;
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The gallery fades out along its bottom edge instead of stopping on
          // a hard line, so the photo melts into the page background and the
          // two read as one surface — as in the reference. `dstIn` multiplies
          // the gallery's alpha by the gradient, letting `PageBackground`
          // (photo + theme gradient) show through underneath.
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, _heroFadeStart, 1],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: photos.isEmpty
                ? const _PhotoFallback()
                : PageView.builder(
                    key: const ValueKey('nature-detail-gallery'),
                    controller: _galleryController,
                    itemCount: photos.length,
                    onPageChanged: (index) =>
                        setState(() => _photoIndex = index),
                    itemBuilder: (_, index) => _GalleryPhoto(
                      index: index,
                      source: photos[index],
                      asset: widget.spot.photosAreAssets,
                      featherLeft: index > 0,
                      featherRight: index < photos.length - 1,
                    ),
                  ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x4D000000), Color(0x00000000)],
                  stops: [0, 0.42],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 20,
            child: GlassBackButton(
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (widget.spot.reviewScore != null)
            PositionedDirectional(
              top: 14,
              end: 16,
              child: _RatingPair(score: widget.spot.reviewScore!),
            ),
          if (photos.length > 1)
            Positioned(
              // Keep the dots above the overlapping About card, in the clear
              // photo area marked in the design reference.
              bottom: _cardOverlap + 48,
              left: 0,
              right: 0,
              child: Center(
                child: _GalleryDots(count: photos.length, current: _photoIndex),
              ),
            ),
        ],
      ),
    );
  }

  String? _distanceText() {
    final location = _deviceLocation;
    if (location == null) return null;
    final meters = widget.spot.distanceMetersFrom(
      location.latitude,
      location.longitude,
    );
    if (meters == null) return null;
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
    return AppLocalizations.of(context).distanceFromCurrentLocation(distance);
  }

  /// Opens the shared in-app map centred on this place, rather than handing the
  /// user off to a maps app and out of the flow.
  void _openMap() {
    final latitude = widget.spot.latitude;
    final longitude = widget.spot.longitude;
    if (latitude == null || longitude == null) return;
    final language = Localizations.localeOf(context).languageCode;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          target: LatLng(latitude, longitude),
          title: widget.spot.name(language),
        ),
      ),
    );
  }

  void _openStay(NearbyStay stay) {
    final callback = widget.onStayTap;
    if (callback != null) {
      callback(stay);
      return;
    }
    _snack(AppLocalizations.of(context).comingSoon);
  }

  /// Opens the full Reviews & Ratings page, handing it the service this screen
  /// already holds so the two share one preview/live source (and one injected
  /// fake in tests).
  ///
  /// Awaited, because posting a review moves this screen's own score and count
  /// — the aggregates are rewritten by a Cloud Function, so coming back
  /// without re-reading would show the old average beside the new review.
  Future<void> _openReviews() async {
    final callback = widget.onReviewsTap;
    if (callback != null) {
      callback();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NatureReviewsScreen(
          spot: widget.spot,
          natureSpotsService: _service,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _reviewsFuture = _service.fetchTopReviews(widget.spot.id));
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.spot,
    required this.language,
    required this.distance,
  });

  final NatureSpot spot;
  final String language;
  final String? distance;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(18),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // The reference puts the photo beside the description on every phone.
        // The old 340 threshold was measured *inside* the card — after 32dp of
        // sliver padding and 36dp of glass padding — so it needed a 408dp
        // screen and the photo never appeared on an ordinary phone. 260 is the
        // width below which the text column would genuinely be too narrow.
        final showImage = constraints.maxWidth >= 260 && spot.hasPhoto;
        // Proportional rather than a fixed 120, so the text keeps a usable
        // column on a 320dp phone and the photo still reads on a large one.
        final photoWidth = (constraints.maxWidth * 0.34).clamp(96.0, 140.0);
        final l10n = AppLocalizations.of(context);
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spot.name(language),
              style: TextStyle(
                fontSize: 24,
                height: 30 / 24,
                fontWeight: FontWeight.w700,
                color: AppColors.heading(context),
              ),
            ),
            if (distance != null) ...[
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${l10n.placeDistanceLabel} ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent(context),
                      ),
                    ),
                    TextSpan(text: distance!),
                  ],
                ),
                style: _bodyStyle(context),
              ),
            ],
            const SizedBox(height: 10),
            Text(spot.description(language), style: _bodyStyle(context)),
          ],
        );
        if (!showImage) return details;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: photoWidth,
                // Portrait crop, matching the reference's tall thumbnail.
                height: photoWidth * 1.42,
                child: _SpotPhoto(
                  source: spot.photos.first,
                  asset: spot.photosAreAssets,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: details),
          ],
        );
      },
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // Stroke-only circled icon — the app's approved section/row icon
      // treatment, and what the reference draws beside this heading.
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent(context), width: 2),
        ),
        child: Icon(icon, size: 20, color: AppColors.accent(context)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
      ),
    ],
  );
}

class _NearbyStaysCard extends StatelessWidget {
  const _NearbyStaysCard({
    required this.stays,
    required this.language,
    required this.onTap,
  });
  final List<NearbyStay> stays;
  final String language;
  final ValueChanged<NearbyStay> onTap;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(12),
    child: SizedBox(
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stays.length.clamp(0, 3),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final stay = stays[index];
          return SizedBox(
            width: 150,
            child: InkWell(
              key: ValueKey('nearby-stay-${stay.id}'),
              onTap: () => onTap(stay),
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 108,
                    width: 150,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: _SpotPhoto(
                              source: stay.imageAsset ?? stay.imageUrl ?? '',
                              asset: stay.imageAsset != null,
                            ),
                          ),
                        ),
                        if (stay.reviewScore != null)
                          PositionedDirectional(
                            top: 6,
                            end: 6,
                            child: _MiniScore(score: stay.reviewScore!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stay.name(language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                  if (stay.distanceKm != null)
                    Text(
                      AppLocalizations.of(
                        context,
                      ).stayDistanceAway(stay.distanceKm!.toStringAsFixed(1)),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.spot,
    required this.onOpenMap,
    required this.height,
    this.compact = false,
  });
  final NatureSpot spot;
  final VoidCallback? onOpenMap;
  final double height;

  /// Half-width layout: the locate button and the name plate would otherwise
  /// leave the name no room at all.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final latitude = spot.latitude;
    final longitude = spot.longitude;
    final openMapLabel = AppLocalizations.of(context).openPlaceMap;
    return GlassPanel(
      borderRadius: 28,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            if (googleMapsAvailable && latitude != null && longitude != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AbsorbPointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(latitude, longitude),
                      zoom: 13.5,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId(spot.id),
                        position: LatLng(latitude, longitude),
                      ),
                    },
                    liteModeEnabled: true,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ),
              )
            else
              const Positioned.fill(child: _PhotoFallback()),
            // The whole preview opens the full map. It was previously marked
            // as a button for screen readers while having no tap handler at
            // all — announced as actionable, and inert.
            if (onOpenMap != null)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: openMapLabel,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('nature-detail-map-card'),
                      onTap: onOpenMap,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              start: compact ? 10 : 14,
              end: compact ? 10 : 14,
              bottom: compact ? 10 : 14,
              child: _LocationOverlay(
                compact: compact,
                locateButton: onOpenMap == null
                    ? null
                    : _MapLocateButton(label: openMapLabel, onTap: onOpenMap!),
                plate: GlassPanel(
                  depth: GlassDepth.middle,
                  borderRadius: 16,
                  padding: EdgeInsets.all(compact ? 9 : 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: compact ? 18 : 24,
                        color: AppColors.accent(context),
                      ),
                      SizedBox(width: compact ? 6 : 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              spot.name(language),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 12 : 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.heading(context),
                              ),
                            ),
                            Text(
                              spot.locationLabel(language),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 10 : 12,
                                color: AppColors.secondaryText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Locate button + name plate over the map preview. Side by side at full
/// width; stacked when the card is half the row, where the button and the
/// plate together would squeeze the place name down to an ellipsis.
class _LocationOverlay extends StatelessWidget {
  const _LocationOverlay({
    required this.compact,
    required this.locateButton,
    required this.plate,
  });
  final bool compact;
  final Widget? locateButton;
  final Widget plate;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Row(
        children: [
          if (locateButton != null) ...[
            locateButton!,
            const SizedBox(width: 10),
          ],
          Expanded(child: plate),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (locateButton != null) ...[locateButton!, const SizedBox(height: 8)],
        plate,
      ],
    );
  }
}

/// The round "take me there" control the reference draws on the map preview.
class _MapLocateButton extends StatelessWidget {
  const _MapLocateButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GlassPanel(
      depth: GlassDepth.middle,
      borderRadius: 999,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('nature-detail-map-locate'),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.near_me_rounded,
              size: 22,
              color: AppColors.accent(context),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({
    required this.title,
    required this.future,
    required this.height,
    this.compact = false,
  });

  /// The reference heads this card with the place's own name, not the word
  /// "Weather" — it is the weather *at Bekhal Waterfall*, and the card sits
  /// beside the map card that names the same place.
  final String title;
  final Future<PlaceWeather>? future;
  final double height;

  /// Half-width layout: smaller type and three hour columns instead of four,
  /// which is what the width will actually carry.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 12.0 : 18.0;
    return GlassPanel(
      borderRadius: 28,
      padding: EdgeInsets.all(pad),
      // The location card's panel has no padding, so its outer height *is*
      // `height`. Subtracting the padding here makes both cards end on the
      // same line instead of the weather card standing taller.
      child: SizedBox(
        height: height - pad * 2,
        child: future == null
            ? _WeatherUnavailable()
            : FutureBuilder<PlaceWeather>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent(context),
                      ),
                    );
                  }
                  final weather = snapshot.data;
                  if (weather == null) return _WeatherUnavailable();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 13 : 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading(context),
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 8),
                      Row(
                        children: [
                          Icon(
                            _weatherIcon(weather.weatherCode),
                            size: compact ? 26 : 40,
                            color: AppColors.accent(context),
                          ),
                          SizedBox(width: compact ? 6 : 10),
                          Expanded(
                            // The condition word plus the temperature is the
                            // widest run of text in the card; at half width it
                            // scales down rather than wrapping or clipping.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                '${_weatherLabel(context, weather.weatherCode)}, ${weather.temperature}°',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: compact ? 18 : 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heading(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: compact ? 16 : 22),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Three columns at half width — four would collide.
                            for (final hour in weather.hourly.take(
                              compact ? 3 : 4,
                            ))
                              _HourWeather(hour: hour, compact: compact),
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

class _WeatherUnavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      AppLocalizations.of(context).weatherUnavailable,
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.secondaryText(context)),
    ),
  );
}

class _HourWeather extends StatelessWidget {
  const _HourWeather({required this.hour, this.compact = false});
  final HourlyWeather hour;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        '${hour.time.hour.toString().padLeft(2, '0')}:00',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          color: AppColors.secondaryText(context),
        ),
      ),
      Icon(
        _weatherIcon(hour.weatherCode),
        size: compact ? 20 : 24,
        color: AppColors.accent(context),
      ),
      Text(
        '${hour.temperature}°',
        style: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w700,
          color: AppColors.heading(context),
        ),
      ),
    ],
  );
}

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({
    required this.score,
    required this.count,
    required this.reviewsFuture,
    required this.onTap,
  });

  final double? score;
  final int count;
  final Future<List<NatureReview>> reviewsFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('nature-detail-reviews-card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).ratingsAndReviews,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading(context),
                      ),
                    ),
                  ),
                  if (score != null) _RatingPair(score: score!),
                ],
              ),
              if (count > 0) ...[
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).basedOnReviews(count),
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
              ],
              const SizedBox(height: 14),
              FutureBuilder<List<NatureReview>>(
                future: reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(AppLocalizations.of(context).reviewsLoadFailed);
                  }
                  final reviews = snapshot.data ?? const <NatureReview>[];
                  if (reviews.isEmpty) {
                    return Text(AppLocalizations.of(context).noReviewsYet);
                  }
                  return Column(
                    children: [
                      for (var index = 0; index < reviews.length; index++) ...[
                        _ReviewRow(review: reviews[index]),
                        if (index != reviews.length - 1)
                          const Divider(height: 24),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: AppColors.accent(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).writeReviewPrompt,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading(context),
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context).writeReviewHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.accent(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});
  final NatureReview review;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.accent(context).withValues(alpha: 0.16),
        foregroundImage: review.avatarUrl == null
            ? null
            : NetworkImage(review.avatarUrl!),
        child: review.avatarUrl == null
            ? Icon(Icons.person_outline, color: AppColors.accent(context))
            : null,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.userName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                ),
                _Stars(filled: review.rating, size: 15),
              ],
            ),
            const SizedBox(height: 4),
            Text(review.comment, style: _bodyStyle(context)),
          ],
        ),
      ),
    ],
  );
}

class _RatingPair extends StatelessWidget {
  const _RatingPair({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _RatingBadge(
        child: Text(
          score.toStringAsFixed(1),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 6),
      _RatingBadge(
        // Whole stars here on purpose: this badge was approved with whole
        // stars on the list card and the hero, and switching it to halves
        // would restyle two already-built screens as a side effect.
        child: _Stars(
          filled: NatureSpot.starsForScore(score).toDouble(),
          size: 15,
          spacing: 4,
        ),
      ),
    ],
  );
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = dark ? AppColors.darkOnPrimary : AppColors.actionNavy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.luminousMint
            : AppColors.pageGradientTop.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: content),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: content,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = dark ? AppColors.darkOnPrimary : AppColors.actionNavy;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.luminousMint
            : AppColors.pageGradientTop.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: content),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: content),
        child: IconTheme(
          data: IconThemeData(color: content),
          child: child,
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.filled, required this.size, this.spacing = 0});

  /// 0.0–5.0. A **double** since reviews became half-star: a 3.5-star review
  /// has no honest whole-star drawing.
  final double filled;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    textDirection: TextDirection.ltr,
    children: [
      for (var index = 0; index < 5; index++) ...[
        Icon(_iconFor(index), size: size),
        if (index != 4) SizedBox(width: spacing),
      ],
    ],
  );

  IconData _iconFor(int index) {
    final remaining = filled - index;
    if (remaining >= 1) return Icons.star_rounded;
    if (remaining >= 0.5) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }
}

class _GalleryDots extends StatelessWidget {
  const _GalleryDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    textDirection: TextDirection.ltr,
    children: [
      for (var index = 0; index < count; index++) ...[
        Container(
          key: ValueKey('nature-detail-gallery-dot-$index'),
          width: index == current ? 9 : 7,
          height: index == current ? 9 : 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: index == current ? 1 : 0.5),
          ),
        ),
        if (index != count - 1) const SizedBox(width: 7),
      ],
    ],
  );
}

class _SpotPhoto extends StatelessWidget {
  const _SpotPhoto({required this.source, required this.asset});
  final String source;
  final bool asset;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return const _PhotoFallback();
    return asset
        ? Image.asset(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          )
        : Image.network(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          );
  }
}

/// Softens only the edges shared with another gallery page. During a swipe,
/// both facing edges feather into the hero background instead of meeting at a
/// hard vertical seam.
class _GalleryPhoto extends StatelessWidget {
  const _GalleryPhoto({
    required this.index,
    required this.source,
    required this.asset,
    required this.featherLeft,
    required this.featherRight,
  });

  final int index;
  final String source;
  final bool asset;
  final bool featherLeft;
  final bool featherRight;

  @override
  Widget build(BuildContext context) => ShaderMask(
    key: ValueKey('nature-detail-gallery-photo-$index'),
    shaderCallback: (bounds) => LinearGradient(
      colors: [
        featherLeft ? Colors.transparent : Colors.white,
        Colors.white,
        Colors.white,
        featherRight ? Colors.transparent : Colors.white,
      ],
      stops: const [0, 0.12, 0.88, 1],
    ).createShader(bounds),
    blendMode: BlendMode.dstIn,
    child: _SpotPhoto(source: source, asset: asset),
  );
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.accent(context).withValues(alpha: 0.18),
    child: Center(
      child: Icon(
        Icons.landscape_outlined,
        size: 54,
        color: AppColors.accent(context),
      ),
    ),
  );
}

TextStyle _bodyStyle(BuildContext context) => TextStyle(
  fontSize: 14,
  height: 20 / 14,
  color: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Theme.of(context).colorScheme.onSurface,
);

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 3) return Icons.cloud_queue_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
    return Icons.water_drop_outlined;
  }
  return Icons.cloud_rounded;
}

String _weatherLabel(BuildContext context, int code) {
  final l10n = AppLocalizations.of(context);
  if (code == 0) return l10n.sunny;
  if (code <= 2) return l10n.partlyCloudy;
  if (code == 3 || code == 45 || code == 48) return l10n.cloudy;
  if (code >= 71 && code <= 77) return l10n.snowy;
  return l10n.rainy;
}
