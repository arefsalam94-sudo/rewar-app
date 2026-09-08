import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/favorite_item.dart';
import '../models/hotel.dart';
import '../services/favorites_service.dart';
import '../services/hotel_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_liquid_glass.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/favorite_toggle_mixin.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/hotel_parts.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/page_background.dart';
import 'hotel_detail_screen.dart';

enum _HotelFilter { location, date, guests, options }

class HotelScreen extends StatefulWidget {
  const HotelScreen({
    super.key,
    this.service = const PreviewHotelService(),
    this.favoritesService,
  });

  final HotelService service;

  /// Backs the heart on the featured and trending cards. Where to Stay is one
  /// of the only two screens that can save anything — see [FavoritesService].
  final FavoritesService? favoritesService;

  @override
  State<HotelScreen> createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen>
    with SingleTickerProviderStateMixin, FavoriteToggleMixin<HotelScreen> {
  @override
  late final FavoritesService favoritesService =
      widget.favoritesService ?? FavoritesService();

  @override
  FavoriteCategory get favoriteCategory => FavoriteCategory.stay;

  late HotelSearchCriteria _criteria;
  late Future<List<Hotel>> _hotels;
  _HotelFilter? _openFilter;
  int _featuredPage = 0;
  List<HotelDestination> _destinationResults = PreviewHotelService.destinations;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _criteria = HotelSearchCriteria(
      checkIn: today.add(const Duration(days: 1)),
      checkOut: today.add(const Duration(days: 3)),
    );
    _hotels = widget.service.trendingHotels();
    loadFavoriteIds();
  }

  /// One callback shared by both card types, so the featured slide and the
  /// trending row cannot disagree about what a saved stay looks like.
  void _onFavorite(Hotel hotel) =>
      toggleFavorite(itemId: hotel.id, snapshot: () => hotel.favoriteSnapshot);

  void _toggle(_HotelFilter filter) =>
      setState(() => _openFilter = _openFilter == filter ? null : filter);

  void _update(HotelSearchCriteria value) => setState(() => _criteria = value);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseDate({required bool checkIn}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = checkIn ? _criteria.checkIn : _criteria.checkOut;
    final first = checkIn
        ? today
        : _criteria.checkIn.add(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
      helpText: checkIn
          ? AppLocalizations.of(context).hotelCheckIn
          : AppLocalizations.of(context).hotelCheckOut,
    );
    if (selected == null || !mounted) return;
    if (checkIn) {
      final checkOut = !_criteria.checkOut.isAfter(selected)
          ? selected.add(const Duration(days: 1))
          : _criteria.checkOut;
      _update(_criteria.copyWith(checkIn: selected, checkOut: checkOut));
    } else {
      _update(_criteria.copyWith(checkOut: selected));
    }
  }

  Future<void> _searchDestinations(String query) async {
    final results = await widget.service.searchDestinations(query);
    if (mounted) setState(() => _destinationResults = results);
  }

  /// Opens the shared Hotel Details page for [hotel].
  ///
  /// One route serves every hotel card — highlighted, trending or a future
  /// search result — so there is never a second detail page to keep in step.
  /// The live search criteria travel with it, and any change the user makes
  /// there comes back here, so returning does not reset the destination,
  /// dates, guests or options they had already chosen.
  Future<void> _openDetail(Hotel hotel) async {
    final updated = await Navigator.of(context).push<HotelSearchCriteria>(
      MaterialPageRoute<HotelSearchCriteria>(
        settings: const RouteSettings(name: '/hotel/detail'),
        builder: (_) => HotelDetailScreen(
          hotel: hotel,
          criteria: _criteria,
          service: widget.service,
        ),
      ),
    );
    if (updated != null && mounted) _update(updated);
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    if (_criteria.destination == null) {
      _snack(l10n.hotelDestinationRequired);
      setState(() => _openFilter = _HotelFilter.location);
      return;
    }
    if (!_criteria.checkOut.isAfter(_criteria.checkIn)) {
      _snack(l10n.hotelInvalidDates);
      return;
    }
    await widget.service.searchHotels(_criteria);
    if (mounted) _snack(l10n.comingSoon);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: 'assets/images/hotel background.webp',
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(l10n: l10n),
                          const SizedBox(height: 14),
                          FutureBuilder<List<Hotel>>(
                            future: _hotels,
                            builder: (context, snapshot) {
                              final hotels = snapshot.data ?? const <Hotel>[];
                              if (snapshot.connectionState !=
                                      ConnectionState.done &&
                                  hotels.isEmpty) {
                                return SizedBox(
                                  height: 220,
                                  child: AppLiquidGlass(
                                    useCanonicalGlass: true,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                              }
                              if (hotels.isEmpty) {
                                return AppLiquidGlass(
                                  useCanonicalGlass: true,
                                  padding: const EdgeInsets.all(24),
                                  child: Text(l10n.hotelPreviewData),
                                );
                              }
                              return _FeaturedCarousel(
                                hotels: hotels
                                    .where((hotel) => hotel.highlighted)
                                    .toList(growable: false),
                                language: language,
                                page: _featuredPage,
                                onPageChanged: (value) =>
                                    setState(() => _featuredPage = value),
                                onTap: _openDetail,
                                isFavorite: isFavorite,
                                favoritePending: favoritePending,
                                onFavorite: _onFavorite,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _FilterGrid(
                            criteria: _criteria,
                            openFilter: _openFilter,
                            onTap: _toggle,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _openFilter == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: _expandedPanel(l10n),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            child: SizedBox(
                              width: 310,
                              child: _HotelSearchButton(onTap: _search),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              l10n.hotelPreviewData,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.secondaryTextV3(context),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _TrendingHeader(label: l10n.hotelTrending),
                          const SizedBox(height: 12),
                          FutureBuilder<List<Hotel>>(
                            future: _hotels,
                            builder: (context, snapshot) => Column(
                              children: [
                                for (final hotel
                                    in snapshot.data ?? const <Hotel>[])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _TrendingHotelCard(
                                      hotel: hotel,
                                      criteria: _criteria,
                                      language: language,
                                      onTap: () => _openDetail(hotel),
                                      isFavorite: isFavorite(hotel.id),
                                      favoritePending: favoritePending(
                                        hotel.id,
                                      ),
                                      onFavorite: () => _onFavorite(hotel),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expandedPanel(AppLocalizations l10n) => switch (_openFilter!) {
    _HotelFilter.location => _LocationPanel(
      key: const ValueKey('location-panel'),
      results: _destinationResults,
      onQueryChanged: _searchDestinations,
      onSelected: (destination) {
        _update(_criteria.copyWith(destination: destination));
        setState(() => _openFilter = null);
      },
    ),
    _HotelFilter.date => _DatePanel(
      key: const ValueKey('date-panel'),
      criteria: _criteria,
      onCheckIn: () => _chooseDate(checkIn: true),
      onCheckOut: () => _chooseDate(checkIn: false),
    ),
    _HotelFilter.guests => _GuestsPanel(
      key: const ValueKey('guests-panel'),
      criteria: _criteria,
      onChanged: _update,
    ),
    _HotelFilter.options => _OptionsPanel(
      key: const ValueKey('options-panel'),
      selected: _criteria.amenities,
      onChanged: (selected) => _update(_criteria.copyWith(amenities: selected)),
      onMore: () => _snack(l10n.comingSoon),
    ),
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pageDirection = Directionality.of(context);
    return Directionality(
      // The shared back control intentionally remains on the physical left in
      // every locale; only the title's text direction follows the language.
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          GlassBackButton(
            onTap: () => Navigator.of(context).maybePop(),
            useAppLiquidGlass: true,
            useCanonicalGlass: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Directionality(
              textDirection: pageDirection,
              child: Text(
                l10n.whereToStay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({
    required this.hotels,
    required this.language,
    required this.page,
    required this.onPageChanged,
    required this.onTap,
    required this.isFavorite,
    required this.favoritePending,
    required this.onFavorite,
  });

  final List<Hotel> hotels;
  final String language;
  final int page;
  final ValueChanged<int> onPageChanged;

  /// Carries the tapped hotel, so the carousel opens the slide the user is
  /// actually looking at rather than whichever one the page index implies.
  final ValueChanged<Hotel> onTap;

  /// Queried per slide rather than passed as a set, so the carousel does not
  /// have to know how favourites are stored.
  final bool Function(String hotelId) isFavorite;
  final bool Function(String hotelId) favoritePending;
  final ValueChanged<Hotel> onFavorite;

  @override
  Widget build(BuildContext context) {
    if (hotels.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: 1.62,
      child: Semantics(
        label: AppLocalizations.of(
          context,
        ).hotelCarouselPosition(page + 1, hotels.length),
        child: PageView.builder(
          itemCount: hotels.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == hotels.length - 1 ? 0 : 7,
            ),
            child: _FeaturedHotelCard(
              hotel: hotels[index],
              language: language,
              dots: hotels.length,
              activeDot: page,
              onTap: () => onTap(hotels[index]),
              isFavorite: isFavorite(hotels[index].id),
              favoritePending: favoritePending(hotels[index].id),
              onFavorite: () => onFavorite(hotels[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedHotelCard extends StatelessWidget {
  const _FeaturedHotelCard({
    required this.hotel,
    required this.language,
    required this.dots,
    required this.activeDot,
    required this.onTap,
    required this.isFavorite,
    required this.favoritePending,
    required this.onFavorite,
  });

  final Hotel hotel;
  final String language;
  final int dots;
  final int activeDot;
  final VoidCallback onTap;
  final bool isFavorite;
  final bool favoritePending;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: hotel.name.forLanguage(language),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              HotelImage(asset: hotel.imageAsset, cacheWidth: 1100),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .05),
                      Colors.black.withValues(alpha: .72),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: .8)),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              // The heart sits on the leading corner and the rating on the
              // trailing one, so the two top controls never compete for the
              // same space as the slide's title grows.
              PositionedDirectional(
                top: 10,
                start: 10,
                child: FavoriteHeartButton(
                  isFavorite: isFavorite,
                  pending: favoritePending,
                  onTap: onFavorite,
                ),
              ),
              PositionedDirectional(
                top: 16,
                end: 16,
                child: HotelCompactRatingPair(
                  key: ValueKey('featured-hotel-rating-${hotel.id}'),
                  score: hotel.reviewScore,
                  starRating: hotel.starRating,
                ),
              ),
              PositionedDirectional(
                start: 20,
                end: 20,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hotel.name.forLanguage(language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.02 * 26,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${hotel.city.forLanguage(language)}  •  '
                            '${l10n.hotelDistanceFromCenter(hotel.distanceFromCenterKm)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(
                        dots,
                        (index) => Container(
                          margin: const EdgeInsetsDirectional.only(start: 6),
                          width: index == activeDot ? 10 : 8,
                          height: index == activeDot ? 10 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == activeDot
                                ? Colors.white
                                : Colors.transparent,
                            border: Border.all(color: Colors.white),
                          ),
                        ),
                      ),
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
}

class _FilterGrid extends StatelessWidget {
  const _FilterGrid({
    required this.criteria,
    required this.openFilter,
    required this.onTap,
  });

  final HotelSearchCriteria criteria;
  final _HotelFilter? openFilter;
  final ValueChanged<_HotelFilter> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final date = MaterialLocalizations.of(context);
    final filters =
        <({String title, String value, IconData icon, _HotelFilter id})>[
          (
            title: l10n.hotelLocation,
            value:
                criteria.destination?.name.forLanguage(locale) ??
                l10n.hotelLocationHint,
            icon: Icons.location_on_outlined,
            id: _HotelFilter.location,
          ),
          (
            title: l10n.hotelDate,
            value:
                '${date.formatShortDate(criteria.checkIn)} – ${date.formatShortDate(criteria.checkOut)}',
            icon: Icons.calendar_month_outlined,
            id: _HotelFilter.date,
          ),
          (
            title: l10n.hotelGuests,
            value: l10n.hotelGuestSummary(
              criteria.adults,
              criteria.children,
              criteria.rooms,
              criteria.beds,
            ),
            icon: Icons.people_outline,
            id: _HotelFilter.guests,
          ),
          (
            title: l10n.hotelOptions,
            value: l10n.hotelOptionsSelected(criteria.amenities.length),
            icon: Icons.tune,
            id: _HotelFilter.options,
          ),
        ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final filter in filters)
            SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: _FilterCard(
                title: filter.title,
                value: filter.value,
                icon: filter.icon,
                expanded: openFilter == filter.id,
                onTap: () => onTap(filter.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: expanded,
    // Standalone filter card — the final canonical surface
    // (Design_system_CANONICAL.md §9). The legacy `selected` glass tint had
    // no canonical embedded/surface equivalent; the rotating chevron below
    // already communicates the expanded state.
    child: AppLiquidGlass(
      useCanonicalGlass: true,
      borderRadius: 24,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              HotelCircleIcon(icon: icon, size: 42),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.heading(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.secondaryTextV3(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.accent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    super.key,
    required this.results,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final List<HotelDestination> results;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<HotelDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return AppLiquidGlass(
      // Standalone filter panel — the final canonical surface.
      useCanonicalGlass: true,
      borderRadius: 26,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onQueryChanged,
            // This field keeps its own established 20px radius (the
            // canonical `AppRecessedGlassField`/`RecessedLiquidGlassField`
            // family hard-codes a 14px radius with no override), so only
            // its colors were migrated to the canonical field tokens — see
            // the migration report for the architectural gap this leaves.
            style: TextStyle(color: AppColors.fieldValue(context)),
            cursorColor: AppColors.fieldCursor(context),
            decoration: InputDecoration(
              hintText: l10n.hotelLocationHint,
              hintStyle: TextStyle(color: AppColors.fieldHint(context)),
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: AppColors.fieldIcon(context),
              ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.hotelRecentSearches,
            style: TextStyle(
              color: AppColors.heading(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final destination in results)
                AppLiquidGlass(
                  // Nested inside this panel's own visible glass surface.
                  useCanonicalGlass: true,
                  layer: GlassLayer.embedded,
                  borderRadius: 22,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onSelected(destination),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HotelCircleIcon(
                            icon: Icons.location_on_outlined,
                            size: 30,
                          ),
                          const SizedBox(width: 7),
                          Text(destination.name.forLanguage(language)),
                        ],
                      ),
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

class _DatePanel extends StatelessWidget {
  const _DatePanel({
    super.key,
    required this.criteria,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final HotelSearchCriteria criteria;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = MaterialLocalizations.of(context);
    return AppLiquidGlass(
      // Standalone filter panel — the final canonical surface. The
      // check-in/check-out taps below open the platform's native
      // `showDatePicker`, not a custom calendar — see the migration report
      // for why that internal styling was left untouched.
      useCanonicalGlass: true,
      borderRadius: 26,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DateChoice(
              width: constraints.maxWidth > 470
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              label: l10n.hotelCheckIn,
              value: formatter.formatMediumDate(criteria.checkIn),
              onTap: onCheckIn,
            ),
            _DateChoice(
              width: constraints.maxWidth > 470
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              label: l10n.hotelCheckOut,
              value: formatter.formatMediumDate(criteria.checkOut),
              onTap: onCheckOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.width,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AppLiquidGlass(
      // Nested inside the Date panel's own visible glass surface.
      useCanonicalGlass: true,
      layer: GlassLayer.embedded,
      borderRadius: 22,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const HotelCircleIcon(icon: Icons.calendar_month_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: AppColors.secondaryTextV3(context)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.heading(context),
                      fontWeight: FontWeight.w700,
                    ),
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

class _GuestsPanel extends StatelessWidget {
  const _GuestsPanel({
    super.key,
    required this.criteria,
    required this.onChanged,
  });

  final HotelSearchCriteria criteria;
  final ValueChanged<HotelSearchCriteria> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppLiquidGlass(
      // Standalone filter panel — the final canonical surface.
      useCanonicalGlass: true,
      borderRadius: 26,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          HotelCounterRow(
            icon: Icons.person_outline,
            label: l10n.hotelAdult,
            value: criteria.adults,
            minimum: 1,
            controlKey: 'adult',
            onChanged: (value) => onChanged(criteria.copyWith(adults: value)),
          ),
          HotelCounterRow(
            icon: Icons.child_care,
            label: l10n.hotelChild,
            value: criteria.children,
            minimum: 0,
            controlKey: 'child',
            onChanged: (value) => onChanged(criteria.copyWith(children: value)),
          ),
          HotelCounterRow(
            icon: Icons.meeting_room_outlined,
            label: l10n.hotelRoom,
            value: criteria.rooms,
            minimum: 1,
            controlKey: 'room',
            onChanged: (value) => onChanged(criteria.copyWith(rooms: value)),
          ),
          HotelCounterRow(
            icon: Icons.bed_outlined,
            label: l10n.hotelBed,
            value: criteria.beds,
            minimum: 1,
            controlKey: 'bed',
            last: true,
            onChanged: (value) => onChanged(criteria.copyWith(beds: value)),
          ),
        ],
      ),
    );
  }
}

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onMore,
  });

  final Set<HotelAmenity> selected;
  final ValueChanged<Set<HotelAmenity>> onChanged;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const options = <HotelAmenity>[
      HotelAmenity.pool,
      HotelAmenity.bar,
      HotelAmenity.restaurant,
      HotelAmenity.gym,
      HotelAmenity.parking,
      HotelAmenity.wifi,
    ];
    return AppLiquidGlass(
      // Standalone filter panel — the final canonical surface.
      useCanonicalGlass: true,
      borderRadius: 26,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (final amenity in options)
            _AmenityCheckbox(
              amenity: amenity,
              selected: selected.contains(amenity),
              onChanged: (checked) {
                final next = Set<HotelAmenity>.of(selected);
                checked ? next.add(amenity) : next.remove(amenity);
                onChanged(next);
              },
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppLiquidGlass(
              // Nested inside the Options panel's own visible glass surface.
              useCanonicalGlass: true,
              layer: GlassLayer.embedded,
              borderRadius: 22,
              onTap: onMore,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HotelCircleIcon(icon: Icons.tune, size: 30),
                  const SizedBox(width: 7),
                  Text(l10n.hotelMoreOptions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityCheckbox extends StatelessWidget {
  const _AmenityCheckbox({
    required this.amenity,
    required this.selected,
    required this.onChanged,
  });

  final HotelAmenity amenity;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = hotelAmenityLabel(l10n, amenity);
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            HotelCircleIcon(icon: hotelAmenityIcon(amenity), size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
              // `Design_system_CANONICAL.md` §19: "selected uses theme
              // active color + contrast check" — navy/mint, not the
              // unthemed default (`colorScheme.primary`, brand green in
              // Light mode).
              activeColor: AppColors.accent(context),
              checkColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkOnPrimary
                  : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _HotelSearchButton extends StatelessWidget {
  const _HotelSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // `action-fill` / `action-content` (Design_system_CANONICAL.md §14) —
    // the primary search action. The legacy implementation rendered this as
    // a translucent glass pill; the canonical primary-action style is a
    // solid navy/mint fill with contrasting content.
    final fill = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final content = isDark ? AppColors.darkOnPrimary : Colors.white;
    return Semantics(
      button: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, color: content, size: 28),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context).hotelSearch,
                  style: TextStyle(
                    color: content,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingHeader extends StatelessWidget {
  const _TrendingHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Divider(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: .55),
      ),
      Row(
        children: [
          const HotelCircleIcon(icon: Icons.king_bed_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.heading(context),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _TrendingHotelCard extends StatelessWidget {
  const _TrendingHotelCard({
    required this.hotel,
    required this.criteria,
    required this.language,
    required this.onTap,
    required this.isFavorite,
    required this.favoritePending,
    required this.onFavorite,
  });

  final Hotel hotel;
  final HotelSearchCriteria criteria;
  final String language;
  final VoidCallback onTap;
  final bool isFavorite;
  final bool favoritePending;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: hotel.name.forLanguage(language),
      child: AppLiquidGlass(
        // Standalone information card — the final canonical surface.
        useCanonicalGlass: true,
        borderRadius: 28,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageWidth = constraints.maxWidth < 310
                  ? 90.0
                  : constraints.maxWidth < 390
                  ? 112.0
                  : 142.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: imageWidth,
                        height: 145,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: HotelImage(
                                  asset: hotel.imageAsset,
                                  cacheWidth: 420,
                                ),
                              ),
                            ),
                            // On the photo, on the leading corner — the same
                            // placement Explore Nature's card uses, so the two
                            // list screens carry one heart in one spot.
                            PositionedDirectional(
                              top: 2,
                              start: 2,
                              child: FavoriteHeartButton(
                                isFavorite: isFavorite,
                                pending: favoritePending,
                                onTap: onFavorite,
                                targetSize: 38,
                                circleSize: 28,
                                iconSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: HotelCompactRatingPair(
                                key: ValueKey(
                                  'trending-hotel-rating-${hotel.id}',
                                ),
                                score: hotel.reviewScore,
                                starRating: hotel.starRating,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hotel.name.forLanguage(language),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.heading(context),
                                fontSize: 19,
                                height: 24 / 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.01 * 19,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              hotel.city.forLanguage(language),
                              style: TextStyle(
                                color: AppColors.heading(context),
                              ),
                            ),
                            Text(
                              l10n.hotelDistanceFromCenter(
                                hotel.distanceFromCenterKm,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.secondaryTextV3(context),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 7,
                              children: [
                                for (final amenity in hotel.amenities.take(5))
                                  Tooltip(
                                    message: hotelAmenityLabel(l10n, amenity),
                                    child: HotelCircleIcon(
                                      icon: hotelAmenityIcon(amenity),
                                      size: 29,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: .5),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.hotelGuestSummary(
                            criteria.adults,
                            criteria.children,
                            criteria.rooms,
                            criteria.beds,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.secondaryTextV3(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.hotelPerNight,
                        style: TextStyle(
                          color: AppColors.secondaryTextV3(context),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        formatHotelPrice(hotel),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: AppColors.heading(context),
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
