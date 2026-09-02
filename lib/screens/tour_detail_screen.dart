import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/map_availability.dart';

import '../l10n/app_localizations.dart';
import '../models/nature_detail.dart';
import '../models/tour.dart';
import '../services/device_location_service.dart';
import '../services/place_weather_service.dart';
import '../services/tours_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/sign_in_required.dart';
import 'booking_traveler_info_screen.dart';
import 'map_screen.dart';
import 'tour_assets.dart';
import 'tour_reviews_screen.dart';

/// Detail and price-estimate page for one Explore Tours departure.
///
/// [onReserve] intentionally defaults to null. Until the payment/booking
/// workflow is supplied, the fixed CTA is visible but disabled and this page
/// performs no booking write.
class TourDetailScreen extends StatefulWidget {
  const TourDetailScreen({
    super.key,
    required this.tour,
    this.toursService,
    this.locationService,
    this.weatherService,
    this.onReserve,
    this.userProfileService,
    this.onReviewsTap,
  });

  final Tour tour;
  final ToursService? toursService;
  final DeviceLocationService? locationService;
  final PlaceWeatherService? weatherService;
  final VoidCallback? onReserve;
  final UserProfileService? userProfileService;
  final VoidCallback? onReviewsTap;

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  late final ToursService _service = widget.toursService ?? ToursService();
  late final DeviceLocationService _locationService =
      widget.locationService ?? const DeviceLocationService();
  late final PlaceWeatherService _weatherService =
      widget.weatherService ?? const PlaceWeatherService();
  late final UserProfileService _profileService =
      widget.userProfileService ?? UserProfileService();
  late Future<List<NatureReview>> _reviewsFuture;
  Future<PlaceWeather>? _weatherFuture;
  DeviceLocation? _deviceLocation;
  final PageController _galleryController = PageController();
  int _photoIndex = 0;
  int _people = 1;
  bool _transport = false;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _service.fetchTopReviews(widget.tour.id);
    final lat = widget.tour.latitude;
    final lng = widget.tour.longitude;
    if (lat != null && lng != null) {
      _weatherFuture = _weatherService.fetch(lat, lng);
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // The frozen CTA sits over the page photograph, not on an opaque bar, so
      // the body background has to reach under the bottom bar.
      extendBody: true,
      body: PageBackground(
        // This flow keeps the exact Explore Tours background photograph, as
        // requested; selected-tour photos belong to the gallery and cards.
        imageAsset: exploreToursBackgroundAsset,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const ValueKey('tour-detail-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 116),
                sliver: SliverList.list(
                  children: [
                    // Physical top-left, outside the image, as requested.
                    Align(
                      alignment: Alignment.topLeft,
                      child: GlassBackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HeroGallery(
                      tour: widget.tour,
                      controller: _galleryController,
                      current: _photoIndex,
                      onChanged: (index) => setState(() => _photoIndex = index),
                    ),
                    const SizedBox(height: 12),
                    _TourInformationCard(
                      tour: widget.tour,
                      distance: _distanceText(),
                    ),
                    const SizedBox(height: 12),
                    _FacilitiesCard(features: widget.tour.knownFeatures),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 184,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _WeatherCard(future: _weatherFuture)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MapCard(tour: widget.tour, onTap: _openMap),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TourReviewsCard(
                      score: widget.tour.reviewScore,
                      count: widget.tour.ratingCount,
                      reviews: _reviewsFuture,
                      onTap: _openReviews,
                    ),
                    const SizedBox(height: 12),
                    _CheckoutCard(
                      tour: widget.tour,
                      people: _people,
                      transportation: _transport,
                      onPeopleChanged: (value) =>
                          setState(() => _people = value),
                      onTransportationChanged:
                          widget.tour.transportAvailable &&
                              widget.tour.transportPricePerPerson != null
                          ? (value) => setState(() => _transport = value)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Only the CTA is frozen. The checkout details remain part of the page
      // so they can be reviewed before committing in the future payment flow.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(22, 8, 22, 12),
        child: PrimaryButton(
          label: AppLocalizations.of(context).tourReserveInsight,
          onTap: widget.tour.isSoldOut ? null : (widget.onReserve ?? _reserve),
        ),
      ),
    );
  }

  /// Opens checkout step 1, after confirming there is an account to attach the
  /// booking to.
  ///
  /// The gate is here rather than at the end of the flow because `bookings`
  /// requires an auth uid (`DATA_MODEL.md`: "There is no such thing as a guest
  /// booking"). Letting someone fill three steps and be refused by the rules at
  /// the charge would not be a freer experience — it would be a wasted one.
  Future<void> _reserve() async {
    final l10n = AppLocalizations.of(context);
    final profile = await _profileService.fetchProfile();
    if (!mounted) return;

    if (profile == null) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SignInRequiredSheet(
          title: l10n.reserveSignInTitle,
          body: l10n.reserveSignInBody,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingTravelerInfoScreen(
          tour: widget.tour,
          // The count and the bus add-on the user already chose on this page
          // carry into checkout, so the summary on step 2 shows the same
          // total they were just looking at.
          initialTravelers: _people,
          transport: _transport,
          userProfileService: widget.userProfileService,
        ),
      ),
    );
  }

  String? _distanceText() {
    final location = _deviceLocation;
    if (location == null) return null;
    final meters = widget.tour.distanceMetersFrom(
      location.latitude,
      location.longitude,
    );
    if (meters == null) return null;
    final label = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
    return AppLocalizations.of(context).distanceFromCurrentLocation(label);
  }

  void _openMap() {
    final lat = widget.tour.latitude;
    final lng = widget.tour.longitude;
    if (lat == null || lng == null) return;
    final language = Localizations.localeOf(context).languageCode;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          target: LatLng(lat, lng),
          title: widget.tour.name(language),
        ),
      ),
    );
  }

  Future<void> _openReviews() async {
    if (widget.onReviewsTap != null) {
      widget.onReviewsTap!();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TourReviewsScreen(tour: widget.tour, toursService: _service),
      ),
    );
    if (!mounted) return;
    setState(() => _reviewsFuture = _service.fetchTopReviews(widget.tour.id));
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.tour,
    required this.controller,
    required this.current,
    required this.onChanged,
  });

  final Tour tour;
  final PageController controller;
  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final photos = tour.photos;
    return AspectRatio(
      aspectRatio: 1.7,
      child: GlassPanel(
        borderRadius: 22,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: photos.isEmpty
                  ? const _PhotoFallback()
                  : PageView.builder(
                      key: const ValueKey('tour-detail-gallery'),
                      controller: controller,
                      itemCount: photos.length,
                      onPageChanged: onChanged,
                      itemBuilder: (_, index) => _TourPhoto(
                        source: photos[index],
                        asset: tour.photosAreAssets,
                      ),
                    ),
            ),
            if (tour.companyTag.isNotEmpty)
              PositionedDirectional(
                top: 14,
                end: 14,
                child: GlassPanel(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Text(
                    tour.companyTag,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                ),
              ),
            if (photos.length > 1)
              PositionedDirectional(
                end: 18,
                bottom: 16,
                child: _Dots(count: photos.length, current: current),
              ),
          ],
        ),
      ),
    );
  }
}

class _TourInformationCard extends StatelessWidget {
  const _TourInformationCard({required this.tour, required this.distance});

  final Tour tour;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final photoWidth = (constraints.maxWidth * 0.34).clamp(108.0, 160.0);
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: photoWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: tour.photos.isEmpty
                        ? const _PhotoFallback()
                        : _TourPhoto(
                            source: tour.photos.first,
                            asset: tour.photosAreAssets,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tour.name(language),
                        style: TextStyle(
                          fontSize: 22,
                          height: 27 / 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.tourDuration(tour.durationDays),
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 19,
                            color: AppColors.accent(context),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tour.locationLabel(language),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.heading(context),
                                  ),
                                ),
                                if (distance != null)
                                  Text(
                                    distance!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tour.description(language),
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FacilitiesCard extends StatelessWidget {
  const _FacilitiesCard({required this.features});
  final List<TourFeature> features;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardTitle(AppLocalizations.of(context).tourFacilities),
        const SizedBox(height: 14),
        if (features.isEmpty)
          Text('—', style: TextStyle(color: AppColors.secondaryText(context)))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final feature in features)
                SizedBox(width: 66, child: _Facility(feature: feature)),
            ],
          ),
      ],
    ),
  );
}

class _Facility extends StatelessWidget {
  const _Facility({required this.feature});
  final TourFeature feature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accent(context);
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 1.5),
          ),
          child: Icon(_featureIcon(feature), size: 23, color: accent),
        ),
        const SizedBox(height: 5),
        Text(
          l10n.tourFeatureLabel(feature),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppColors.heading(context)),
        ),
      ],
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.future});
  final Future<PlaceWeather>? future;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(14),
    child: SizedBox(
      height: 176,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(AppLocalizations.of(context).weather),
          const SizedBox(height: 8),
          Expanded(
            child: future == null
                ? _Unavailable(
                    AppLocalizations.of(context).tourWeatherUnavailable,
                  )
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
                      if (weather == null) {
                        return _Unavailable(
                          AppLocalizations.of(context).tourWeatherUnavailable,
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                '${weather.temperature}°',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heading(context),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _weatherIcon(weather.weatherCode),
                                size: 42,
                                color: AppColors.accent(context),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final hour in weather.hourly.take(3))
                                Column(
                                  children: [
                                    Text(
                                      '${hour.time.hour}:00',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.secondaryText(context),
                                      ),
                                    ),
                                    Icon(
                                      _weatherIcon(hour.weatherCode),
                                      size: 18,
                                      color: AppColors.accent(context),
                                    ),
                                    Text(
                                      '${hour.temperature}°',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.heading(context),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.tour, required this.onTap});
  final Tour tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lat = tour.latitude;
    final lng = tour.longitude;
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 176,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(AppLocalizations.of(context).tourMap),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: lat == null || lng == null || !googleMapsAvailable
                    ? _Unavailable(
                        AppLocalizations.of(context).tourMapUnavailable,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          IgnorePointer(
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(lat, lng),
                                zoom: 11,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('tour'),
                                  position: LatLng(lat, lng),
                                ),
                              },
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              myLocationButtonEnabled: false,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(onTap: onTap),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourReviewsCard extends StatelessWidget {
  const _TourReviewsCard({
    required this.score,
    required this.count,
    required this.reviews,
    required this.onTap,
  });
  final double? score;
  final int count;
  final Future<List<NatureReview>> reviews;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      child: GlassPanel(
        borderRadius: 28,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _CardTitle(l10n.ratingsAndReviews)),
                      if (score != null)
                        Text(
                          score!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heading(context),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    l10n.tourReviewCount(count),
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<NatureReview>>(
                    future: reviews,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return LinearProgressIndicator(
                          color: AppColors.accent(context),
                          backgroundColor: Colors.transparent,
                        );
                      }
                      final items = snapshot.data ?? const <NatureReview>[];
                      if (items.isEmpty) {
                        return Text(
                          l10n.noReviewsYet,
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            _ReviewPreview(review: items[i]),
                            if (i != items.length - 1)
                              const Divider(height: 16),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 18,
                        color: AppColors.accent(context),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          l10n.tourWriteReviewPrompt,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.accent(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewPreview extends StatelessWidget {
  const _ReviewPreview({required this.review});
  final NatureReview review;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.accent(context).withValues(alpha: 0.16),
        child: Text(
          review.userName.isEmpty ? '?' : review.userName.characters.first,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review.userName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.heading(context),
              ),
            ),
            Text(
              review.comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.secondaryText(context)),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.tour,
    required this.people,
    required this.transportation,
    required this.onPeopleChanged,
    required this.onTransportationChanged,
  });
  final Tour tour;
  final int people;
  final bool transportation;
  final ValueChanged<int> onPeopleChanged;
  final ValueChanged<bool>? onTransportationChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // One formula, on the model — the checkout summary shows the same number.
    final total = tour.totalFor(travelers: people, transport: transportation);
    final maxPeople = tour.spotsLeft ?? 99;
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(l10n.tourCheckout),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tourPerson,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.remove,
                onTap: people > 1 ? () => onPeopleChanged(people - 1) : null,
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  '$people',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: people < maxPeople
                    ? () => onPeopleChanged(people + 1)
                    : null,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tourTransportationBus,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading(context),
                      ),
                    ),
                    if (tour.transportAvailable &&
                        tour.transportPricePerPerson != null)
                      Text(
                        '${_money(tour.transportPricePerPerson!, tour.currency)} ${l10n.tourPerPerson} · ${l10n.tourOptional}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText(context),
                        ),
                      )
                    else
                      Text(
                        l10n.tourTransportUnavailable,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                  ],
                ),
              ),
              Checkbox(
                value: transportation,
                onChanged: onTransportationChanged == null
                    ? null
                    : (value) => onTransportationChanged!(value ?? false),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tourTotalPrice,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
              Text(
                total == null ? '—' : _money(total, tour.currency),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accent(
              context,
            ).withValues(alpha: onTap == null ? 0.35 : 1),
          ),
        ),
        child: Icon(
          icon,
          color: AppColors.accent(
            context,
          ).withValues(alpha: onTap == null ? 0.35 : 1),
        ),
      ),
    ),
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.heading(context),
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.secondaryText(context)),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++)
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsetsDirectional.only(start: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
    ],
  );
}

class _TourPhoto extends StatelessWidget {
  const _TourPhoto({required this.source, required this.asset});
  final String source;
  final bool asset;

  @override
  Widget build(BuildContext context) => asset
      ? Image.asset(source, fit: BoxFit.cover)
      : Image.network(
          source,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _PhotoFallback(),
        );
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.accent(context).withValues(alpha: 0.18),
    child: Center(
      child: Icon(
        Icons.tour_outlined,
        size: 56,
        color: AppColors.accent(context),
      ),
    ),
  );
}

IconData _featureIcon(TourFeature feature) => switch (feature) {
  TourFeature.camping => Icons.cabin_outlined,
  TourFeature.hiking => Icons.hiking_rounded,
  TourFeature.guide => Icons.person_outline_rounded,
  TourFeature.food => Icons.restaurant_rounded,
  TourFeature.swimming => Icons.pool_outlined,
  TourFeature.campfire => Icons.local_fire_department_outlined,
  TourFeature.transport => Icons.directions_bus_outlined,
  TourFeature.photography => Icons.photo_camera_outlined,
  TourFeature.activity => Icons.directions_run_rounded,
  TourFeature.wifi => Icons.wifi_rounded,
  TourFeature.electricity => Icons.bolt_outlined,
  TourFeature.tent => Icons.festival_outlined,
};

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code <= 3) return Icons.cloud_outlined;
  if (code <= 48) return Icons.foggy;
  if (code <= 67) return Icons.grain;
  if (code <= 77) return Icons.ac_unit;
  if (code <= 82) return Icons.water_drop_outlined;
  return Icons.thunderstorm_outlined;
}

String _money(num value, String currency) {
  final digits = value % 1 == 0 ? 0 : 2;
  final amount = value.toStringAsFixed(digits);
  return switch (currency.toUpperCase()) {
    'USD' => '\$$amount',
    'EUR' => '€$amount',
    'IQD' => '$amount IQD',
    _ => '$amount $currency',
  };
}
