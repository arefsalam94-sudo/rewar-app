import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/featured_item.dart' show FeaturedType;
import '../models/tour.dart';
import '../models/tour_filters.dart';
import '../services/currency_rates_service.dart';
import '../services/device_location_service.dart';
import '../services/favorites_service.dart';
import '../services/tours_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';
import 'tour_detail_screen.dart';
import 'tour_assets.dart' as tour_assets;

const String exploreToursBackgroundAsset =
    tour_assets.exploreToursBackgroundAsset;

/// The background photograph for the Explore Tours screen, supplied with the
/// reference (`DESIGN_SYSTEM.md` 4.1: every screen uses a developer-supplied
/// bundled photo, blurred at σ2 under the theme gradient at 45%).

/// Phase 6 — the Explore Tours list screen, opened from the Home screen's
/// "Explore Tours" card.
///
/// Layout comes from the supplied reference: the back button and title on one
/// row, a carousel of highlighted tours, the search block, then the "Trending
/// Tours" list. Every colour, radius and text size comes from tokens already
/// approved in `DESIGN_SYSTEM.md` / `DESIGN_LIGHT.md` / `DESIGN_DARK.md`.
///
/// The rating placement is as requested and as the reference draws it: on the
/// **trailing** edge in both places — above the tour name on a carousel slide,
/// and beside the tour name on a list card, with the score and the five stars
/// sharing one row.
///
/// Catalog data is public read, so a guest sees exactly what a signed-in user
/// sees (`SECURITY.md` section 1, `firestore.rules` → `tours`). Only the
/// favourite heart needs an account.
class ExploreToursScreen extends StatefulWidget {
  const ExploreToursScreen({
    super.key,
    this.toursService,
    this.locationService,
    this.favoritesService,
    this.currencyRatesService,
    this.userProfileService,
  });

  /// Injectable for tests; defaults to the real Firestore-backed service.
  final ToursService? toursService;

  /// Injectable for tests. A test that passes nothing gets the real service,
  /// which returns null off-device — so the distance line simply stays hidden
  /// rather than failing.
  final DeviceLocationService? locationService;

  final FavoritesService? favoritesService;
  final CurrencyRatesService? currencyRatesService;
  final UserProfileService? userProfileService;

  @override
  State<ExploreToursScreen> createState() => _ExploreToursScreenState();
}

class _ExploreToursScreenState extends State<ExploreToursScreen> {
  late final ToursService _service = widget.toursService ?? ToursService();
  late final DeviceLocationService _locationService =
      widget.locationService ?? const DeviceLocationService();
  late final FavoritesService _favoritesService =
      widget.favoritesService ?? FavoritesService();
  late final CurrencyRatesService _ratesService =
      widget.currencyRatesService ?? CurrencyRatesService();
  late final UserProfileService _profileService =
      widget.userProfileService ?? UserProfileService();

  late Future<List<Tour>> _highlightedFuture;

  /// The whole active catalog, fetched once and filtered in Dart.
  ///
  /// Firestore cannot do substring search at all, and the tour name is a
  /// locale map, so a server-side search would have to pick one of three
  /// languages. See [ToursService.fetchCatalog].
  List<Tour>? _catalog;
  Object? _catalogError;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  /// What the user has typed and picked, which is not yet what the list is
  /// showing — the reference has an explicit Apply button, so the *search*
  /// inputs do not narrow anything until it is pressed.
  DateTimeRange? _pendingRange;
  int _pendingTravellers = TourFilters.minTravellers;

  /// What is actually narrowing and ordering the list.
  ///
  /// Search text, dates and party size land here on Apply. The refinement
  /// chips and the sort control write straight through, because they refine a
  /// result set rather than describing a search — which is how both reference
  /// products behave, and what keeps Apply from looking decorative.
  TourFilters _filters = const TourFilters();

  /// Null until a GPS fix arrives, and stays null when location is off or
  /// denied — the cards then hide their distance line instead of inventing
  /// one, and "Nearest to me" quietly falls back to "Soonest".
  DeviceLocation? _deviceLocation;

  /// Indicative FX rates and the user's chosen display currency. Both are
  /// best-effort: without them prices stay in the operator's own currency,
  /// which is always correct.
  CurrencyRates _rates = CurrencyRates.empty;
  AppCurrency _displayCurrency = AppCurrency.usd;

  /// Tour ids the signed-in user has saved, and the ones mid-write so a
  /// double-tap cannot fire twice.
  Set<String> _favoriteIds = <String>{};
  final Set<String> _pendingFavorites = <String>{};

  final PageController _carouselController = PageController();
  int _currentSlide = 0;

  @override
  void initState() {
    super.initState();
    _highlightedFuture = _service.fetchHighlighted();
    _searchController.addListener(_onSearchChanged);
    _loadCatalog();
    _loadDeviceLocation();
    _loadSecondaryData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _dateController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  /// Only rebuilds when the box crosses between empty and non-empty — every
  /// keystroke in between changes nothing on screen.
  bool _searchWasEmpty = true;
  void _onSearchChanged() {
    final isEmpty = _searchController.text.isEmpty;
    if (isEmpty != _searchWasEmpty) {
      setState(() => _searchWasEmpty = isEmpty);
    }
  }

  /// The distance line is a nice-to-have, so a failure here must never surface
  /// as an error on a screen that is otherwise working.
  Future<void> _loadDeviceLocation() async {
    final location = await _locationService.currentLocation();
    if (mounted && location != null) {
      setState(() => _deviceLocation = location);
    }
  }

  /// Favourites, FX rates and the currency preference — three optional extras.
  ///
  /// Every one of them is allowed to fail silently: none is the reason the
  /// user opened this screen, and a tour list that refuses to draw because a
  /// rate table is missing would be a much worse bug than an unconverted price.
  Future<void> _loadSecondaryData() async {
    try {
      final rates = await _ratesService.fetchLatest();
      if (mounted) setState(() => _rates = rates);
    } catch (error) {
      debugPrint('Could not load currency rates: $error');
    }
    try {
      final profile = await _profileService.fetchProfile();
      if (mounted && profile != null) {
        setState(() => _displayCurrency = profile.currency);
      }
    } catch (error) {
      debugPrint('Could not load the currency preference: $error');
    }
    try {
      final ids = await _favoritesService.fetchFavoriteItemIds();
      if (mounted) setState(() => _favoriteIds = ids);
    } catch (error) {
      debugPrint('Could not load favorites: $error');
    }
  }

  void _retryHighlighted() {
    setState(() {
      _currentSlide = 0;
      _highlightedFuture = _service.fetchHighlighted();
    });
  }

  /// Loads the catalog, and is also the retry path — it resets to the loading
  /// state first, so a retry visibly restarts rather than sitting on the error.
  Future<void> _loadCatalog() async {
    setState(() {
      _catalog = null;
      _catalogError = null;
    });
    try {
      final tours = await _service.fetchCatalog();
      if (mounted) setState(() => _catalog = tours);
    } catch (error) {
      debugPrint('Could not load tours: $error');
      if (mounted) setState(() => _catalogError = error);
    }
  }

  /// Commits the search box, the date range and the party size to the list.
  /// Costs no read — the catalog is already in memory.
  void _apply() {
    FocusScope.of(context).unfocus();
    final range = _pendingRange;
    setState(() {
      _filters = _filters.copyWith(
        query: _searchController.text,
        clearRange: range == null,
        rangeStart: range?.start,
        rangeEnd: range?.end,
        travellers: _pendingTravellers,
      );
    });
  }

  void _clearEverything() {
    _searchController.clear();
    setState(() {
      _pendingRange = null;
      _pendingTravellers = TourFilters.minTravellers;
      // The sort survives a clear: it is the user's chosen view of the list,
      // not one of the things narrowing it.
      _filters = TourFilters(sort: _filters.sort);
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _pendingRange,
      // A tour that has already departed cannot be booked, so there is nothing
      // useful behind today.
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
    );
    if (picked != null && mounted) setState(() => _pendingRange = picked);
  }

  Future<void> _onFavoriteTapped(Tour tour) async {
    final l10n = AppLocalizations.of(context);

    if (!_service.isSignedIn) {
      await _showSignInPrompt();
      return;
    }
    if (_pendingFavorites.contains(tour.id)) return;

    final wasFavorite = _favoriteIds.contains(tour.id);
    setState(() => _pendingFavorites.add(tour.id));
    try {
      final nowFavorite = await _favoritesService.toggle(
        itemType: FeaturedType.tour,
        itemId: tour.id,
        currentlyFavorite: wasFavorite,
      );
      if (!mounted) return;
      setState(() {
        if (nowFavorite) {
          _favoriteIds.add(tour.id);
        } else {
          _favoriteIds.remove(tour.id);
        }
      });
      _snack(nowFavorite ? l10n.addedToFavorites : l10n.removedFromFavorites);
    } catch (error) {
      debugPrint('Favorite toggle failed: $error');
      if (mounted) _snack(l10n.favoriteFailed);
    } finally {
      if (mounted) setState(() => _pendingFavorites.remove(tour.id));
    }
  }

  /// The same prompt the Home screen shows: a favourite is tied to an account,
  /// so there is no such thing as an anonymous one.
  Future<void> _showSignInPrompt() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassPanel(
            borderRadius: 28,
            depth: GlassDepth.middle,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.signInToSave,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.signInToSaveBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: l10n.logIn,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(l10n.notNow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The list actually drawn: filtered and ordered by [_filters].
  List<Tour> _visibleTours(List<Tour> catalog) => _filters.sortedFrom(
    catalog,
    fromLatitude: _deviceLocation?.latitude,
    fromLongitude: _deviceLocation?.longitude,
  );

  /// How prices should be drawn, given the rate table and the user's currency.
  TourPricing get _pricing => TourPricing(
    rates: _rates,
    displayCurrency: _displayCurrency.code,
    travellers: _filters.travellers,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: exploreToursBackgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset + 28),
            children: [
              const _BackBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCarousel(l10n, languageCode),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSearchControls(l10n),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.trendingTours,
                  // `section-title` from the DESIGN_SYSTEM.md type scale.
                  style: TextStyle(
                    fontSize: 20,
                    height: 28 / 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTourList(l10n, languageCode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel(AppLocalizations l10n, String languageCode) {
    return SizedBox(
      height: _HighlightCard.heightFor(context),
      child: FutureBuilder<List<Tour>>(
        future: _highlightedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PanelShell(child: _PanelLoading());
          }
          if (snapshot.hasError) {
            return _PanelShell(
              child: _PanelMessage(
                message: l10n.toursLoadFailed,
                actionLabel: l10n.tryAgain,
                onAction: _retryHighlighted,
              ),
            );
          }

          final tours = snapshot.data ?? const <Tour>[];
          if (tours.isEmpty) {
            return _PanelShell(
              child: _PanelMessage(message: l10n.toursHighlightedEmpty),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _carouselController,
                itemCount: tours.length,
                onPageChanged: (index) => setState(() => _currentSlide = index),
                itemBuilder: (context, index) => _HighlightCard(
                  tour: tours[index],
                  languageCode: languageCode,
                  onTap: () => _openTour(tours[index]),
                ),
              ),
              // Outside the PageView, so the dots stay still while the slides
              // move — the same rule the Home and Explore Nature carousels
              // follow.
              PositionedDirectional(
                end: 20,
                bottom: 16,
                child: _Dots(count: tours.length, current: _currentSlide),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The recessed-glass inputs, the traveller stepper and the Apply button.
  ///
  /// Every field is the shared [AppRecessedGlassField] — `DESIGN_SYSTEM.md`
  /// section 8 requires one input family across the whole app, and section 23
  /// lists "different input families on different screens" as prohibited.
  Widget _buildSearchControls(AppLocalizations l10n) {
    final range = _pendingRange;
    // Written here rather than in `_pickDateRange`, so the field re-renders in
    // the new language when the app locale changes under it.
    _dateController.text = range == null
        ? ''
        : l10n.tourDateRange(range.start, range.end);

    final search = AppRecessedGlassField(
      key: exploreToursSearchFieldKey,
      controller: _searchController,
      hint: l10n.toursSearchHint,
      prefixIcon: Icons.search_rounded,
      compact: true,
      textInputAction: TextInputAction.search,
      onFieldSubmitted: (_) => _apply(),
      suffix: _searchController.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: l10n.clearSearch,
              onPressed: () {
                _searchController.clear();
                _apply();
              },
            ),
    );

    final date = AppRecessedGlassField(
      key: exploreToursDateFieldKey,
      controller: _dateController,
      hint: l10n.toursDateRangeHint,
      prefixIcon: Icons.calendar_month_outlined,
      compact: true,
      // Read-only rather than a free-text date: a typed date has to be
      // parsed, and a parser that has to cover three languages is a source
      // of wrong dates, not convenience.
      readOnly: true,
      onTap: _pickDateRange,
      suffix: range == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: l10n.clearDate,
              onPressed: () => setState(() => _pendingRange = null),
            ),
    );

    // Side by side, as the reference draws them. Below the Compact breakpoint
    // the two halves are too narrow for a legible hint even at the compact
    // type size, so they stack instead of clipping — `DESIGN_SYSTEM.md` 19:
    // "components stack vertically when necessary".
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final sideBySide = width >= 340 && textScale <= 1.3;

    return Column(
      children: [
        if (sideBySide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              Expanded(child: date),
            ],
          )
        else ...[
          search,
          const SizedBox(height: 12),
          date,
        ],
        const SizedBox(height: 16),
        // Not full width: the reference draws a compact action centred under
        // the gap between the two fields. The token geometry (56dp, radius 14,
        // solid action fill) is unchanged — only the width is constrained.
        Center(
          child: SizedBox(
            width: 190,
            child: PrimaryButton(label: l10n.toursApply, onTap: _apply),
          ),
        ),
      ],
    );
  }

  Widget _buildTourList(AppLocalizations l10n, String languageCode) {
    if (_catalogError != null) {
      return SizedBox(
        height: 160,
        child: _PanelShell(
          child: _PanelMessage(
            message: l10n.toursLoadFailed,
            actionLabel: l10n.tryAgain,
            onAction: _loadCatalog,
          ),
        ),
      );
    }

    final catalog = _catalog;
    if (catalog == null) {
      return const SizedBox(
        height: 160,
        child: _PanelShell(child: _PanelLoading()),
      );
    }

    final tours = _visibleTours(catalog);
    if (tours.isEmpty) {
      return SizedBox(
        height: 160,
        child: _PanelShell(
          child: _PanelMessage(
            message: l10n.toursEmpty,
            // Only offered when a filter is what emptied the list — otherwise
            // there is nothing to clear.
            actionLabel: _filters.isEmpty ? null : l10n.toursClearAll,
            onAction: _filters.isEmpty ? null : _clearEverything,
          ),
        ),
      );
    }

    final pricing = _pricing;
    // The disclosure is drawn once, above the list, and only when a price on
    // screen actually was converted — a standing legal notice nobody needs is
    // noise, and noise is what makes real disclosures invisible.
    final showsConverted = tours.any(
      (tour) => pricing.isConverted(tour.currency),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showsConverted) ...[
          _PriceDisclosure(updatedAt: _rates.updatedAt),
          const SizedBox(height: 12),
        ],
        for (final tour in tours) ...[
          _TourCard(
            tour: tour,
            languageCode: languageCode,
            deviceLocation: _deviceLocation,
            pricing: pricing,
            isFavorite: _favoriteIds.contains(tour.id),
            favoritePending: _pendingFavorites.contains(tour.id),
            onFavorite: () => _onFavoriteTapped(tour),
            onTap: () => _openTour(tour),
          ),
          if (tour != tours.last) const SizedBox(height: 14),
        ],
      ],
    );
  }

  void _openTour(Tour tour) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TourDetailScreen(
          tour: tour,
          toursService: _service,
          locationService: _locationService,
        ),
      ),
    );
  }
}

@visibleForTesting
const Key exploreToursSearchFieldKey = ValueKey('explore-tours-search');

@visibleForTesting
const Key exploreToursDateFieldKey = ValueKey('explore-tours-date');

// --- Chrome -----------------------------------------------------------------

/// The back button and the page title, on one row, as the reference draws it.
///
/// Sized by its content rather than a fixed height, so the title can wrap at a
/// large system font size instead of being clipped (`DESIGN_SYSTEM.md` § 19,
/// "avoid fixed-height containers that clip text").
class _BackBar extends StatelessWidget {
  const _BackBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left, not start: GlassBackButton stays physically top-left in every
          // language, RTL included (`DESIGN_SYSTEM.md` 11.3 and 20).
          GlassBackButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              l10n.exploreToursTitle,
              // `page-title` from the DESIGN_SYSTEM.md type scale: 28/700/36.
              style: TextStyle(
                fontSize: 28,
                height: 36 / 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02 * 28,
                color: AppColors.heading(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Both design files specify the organic 28px `rounded-card` silhouette.
const double _cardRadius = 22;

// --- Pricing ----------------------------------------------------------------

/// How one screen draws money: the rate table, the currency to show, and how
/// many people are travelling.
///
/// A value object rather than three loose fields, so the card cannot render a
/// per-person price in one currency and a total in another.
@immutable
class TourPricing {
  const TourPricing({
    required this.rates,
    required this.displayCurrency,
    this.travellers = 1,
  });

  final CurrencyRates rates;

  /// The ISO code the user chose in Settings (`users.preferredCurrency`).
  final String displayCurrency;

  final int travellers;

  /// Whether a price quoted in [currency] would actually be converted for
  /// display — false when it already matches, and false when the rate table
  /// cannot do it.
  bool isConverted(String currency) {
    if (currency.toUpperCase() == displayCurrency.toUpperCase()) return false;
    return rates.convert(1, from: currency, to: displayCurrency) != null;
  }

  /// One person's price as drawn, e.g. `$55` or `≈ IQD 72,050`.
  ///
  /// Falls back to the operator's own currency whenever the conversion is not
  /// possible — an unconverted true price beats a converted invented one.
  String perPerson(num amount, String currency) =>
      _format(amount, currency, multiplier: 1);

  /// The whole party's price, or null when [travellers] is 1 and the line
  /// would only repeat the per-person figure.
  String? total(num amount, String currency) {
    if (travellers <= 1) return null;
    return _format(amount, currency, multiplier: travellers);
  }

  String _format(num amount, String currency, {required int multiplier}) {
    final base = amount * multiplier;
    final converted = rates.convert(base, from: currency, to: displayCurrency);
    if (converted == null || !isConverted(currency)) {
      return formatMoney(base, currency);
    }
    // "≈" is the whole disclosure at a glance; the sentence above the list
    // carries the rest.
    return '≈ ${formatMoney(converted, displayCurrency)}';
  }
}

/// `$55`, `€1,240`, `IQD 72,050`.
///
/// Grouped in threes with Western digits in every language, matching how every
/// other number in the app is drawn (see `AppLocalizations.bookingDate`).
/// A currency with no well-known glyph keeps its ISO code, because an invented
/// symbol is worse than three unambiguous letters.
///
/// Public rather than `@visibleForTesting`: checkout step 2 prints the booking
/// total and must format it identically to the tour cards it came from.
String formatMoney(num amount, String currency) {
  final symbol = CurrencyRatesService.symbolFor(currency);
  // Sub-unit precision only where it exists and matters: 55 is "$55", 55.5 is
  // "$55.50", and 72049.6 dinars is "IQD 72,050" — nobody quotes fils.
  final rounded = amount.abs() >= 1000 || amount % 1 == 0
      ? amount.round().toString()
      : amount.toStringAsFixed(2);
  final parts = rounded.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
  final body = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  return symbol.length > 1 ? '$symbol $body' : '$symbol$body';
}

/// The one-line notice above a list containing converted prices.
class _PriceDisclosure extends StatelessWidget {
  const _PriceDisclosure({this.updatedAt});

  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final when = updatedAt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 15,
          color: AppColors.secondaryText(context),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            when == null
                ? l10n.toursPriceApprox
                : '${l10n.toursPriceApprox} '
                      '${l10n.lastUpdated(l10n.bookingDate(when))}',
            style: TextStyle(
              // `caption`
              fontSize: 12,
              height: 16 / 12,
              color: AppColors.secondaryText(context),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Highlighted carousel ---------------------------------------------------

/// One carousel slide: the photo of a highlighted tour, its rating on the
/// **leading** edge and its operator tag on the trailing edge, then the name,
/// location line and a clipped description.
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.tour,
    required this.languageCode,
    required this.onTap,
  });

  final Tour tour;
  final String languageCode;
  final VoidCallback onTap;

  /// Base height, grown for large system font sizes so the overlaid copy never
  /// runs out of room — the same rule the Explore Nature carousel uses.
  static double heightFor(BuildContext context) {
    final factor = (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(
      1.0,
      1.6,
    );
    return 308 * factor;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = tour.reviewScore;

    return Padding(
      // Keeps a gap between slides as the PageView scrolls.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        label: tour.name(languageCode),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_cardRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _TourPhoto(tour: tour, index: 0),
                  // Scrim, so white copy stays legible over any photograph.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x40000000),
                          Color(0x00000000),
                          Color(0xB3000000),
                        ],
                        stops: [0.0, 0.32, 1.0],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rating on the **trailing** edge, above the tour
                        // name, as the reference draws it: the score and the
                        // stars share one row, with the operator tag beneath
                        // them. Score and stars stay two separate badges
                        // (`DESIGN_SYSTEM.md` 13).
                        // `Align` rather than a bare `Column`: the parent
                        // column is start-aligned, so a shrink-wrapped child
                        // would sit on the leading edge instead.
                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (score != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ScoreBox(score: score),
                                    const SizedBox(width: 8),
                                    _StarBox(score: score),
                                  ],
                                ),
                              if (tour.companyTag.isNotEmpty) ...[
                                if (score != null) const SizedBox(height: 8),
                                _CompanyTag(
                                  label: tour.companyTag,
                                  onPhoto: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            tour.name(languageCode),
                            maxLines: 1,
                            style: const TextStyle(
                              // headline-lg
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.02 * 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 17,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                // "Rawanduz, Erbil | 2 days travel" — one line,
                                // as the reference draws it. The separator is
                                // punctuation, not copy, so it is not
                                // translated.
                                '${tour.locationLabel(languageCode)} | '
                                '${l10n.tourDuration(tour.durationDays)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          // Keeps the copy clear of the dot row in the opposite
                          // corner, which is drawn outside this slide.
                          padding: const EdgeInsetsDirectional.only(end: 70),
                          child: Text(
                            tour.description(languageCode),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_cardRadius),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isDark ? AppColors.darkBorderOpacity : 0.35,
                          ),
                          width: 1.2,
                        ),
                      ),
                    ),
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

/// A tour photograph: a bundled asset in preview mode, a Storage URL in
/// production. Both fall back to a brand-coloured panel with a tour icon
/// rather than a broken-image box.
class _TourPhoto extends StatelessWidget {
  const _TourPhoto({required this.tour, required this.index});

  final Tour tour;

  /// Which of the tour's photos to draw. Out-of-range falls back gracefully.
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = ColoredBox(
      color: isDark
          ? AppColors.darkForestFloor
          : AppColors.pageGradientBottom.withValues(alpha: 0.55),
      child: Center(
        child: Icon(
          Icons.festival_outlined,
          size: 34,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );

    final photos = tour.photos;
    if (photos.isEmpty || index >= photos.length) return fallback;
    final photo = photos[index];

    if (tour.photosAreAssets) {
      return Image.asset(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    return Image.network(
      photo,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

/// Page dots. Always laid out left-to-right, like the Home carousel and the
/// Explore Nature carousel — a progress track is not a sentence.
@visibleForTesting
const Key exploreToursDotsKey = ValueKey('explore-tours-dots');

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      key: exploreToursDotsKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 9 : 7,
            height: i == current ? 9 : 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: i == current ? 1 : 0.5),
            ),
          ),
      ],
    ),
  );
}

// --- Rating badges ----------------------------------------------------------

/// The 0–10 review score, in the shared rating-badge shell.
///
/// The carousel slide only: the list card was asked to drop the number and
/// keep the stars alone, laid over the photo.
class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) => _BadgeShell(
    child: Text(
      score.toStringAsFixed(1),
      // Always left-to-right: a decimal score reads the same way in every
      // language.
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: _BadgeShell.contentColor(context),
      ),
    ),
  );
}

/// Five stars, filled from the same 0–10 score. Derived, never stored — see
/// [Tour.starsForScore].
///
/// The carousel slide only, like [_ScoreBox]: the list card shows no rating.
class _StarBox extends StatelessWidget {
  const _StarBox({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final filled = Tour.starsForScore(score);
    final color = _BadgeShell.contentColor(context);

    return _BadgeShell(
      child: Directionality(
        // A rating track fills left-to-right in every language, the same rule
        // the carousel dots follow.
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: EdgeInsets.only(right: i == 4 ? 0 : 5),
                child: Icon(
                  i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 17,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared shell behind [_ScoreBox] and [_StarBox], per the unified
/// rating-badge rule in both theme documents. Identical to the Explore Nature
/// treatment on purpose — `DESIGN_SYSTEM.md` 13 forbids a per-screen rating.
class _BadgeShell extends StatelessWidget {
  const _BadgeShell({required this.child});

  final Widget child;

  /// `DESIGN_SYSTEM.md` 13: compact rounded box, radius 12.
  static const double radius = 12;

  static Color contentColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkOnPrimary
      : AppColors.actionNavy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.luminousMint
            : AppColors.pageGradientTop.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark ? AppColors.darkOnPrimary : AppColors.actionNavy,
        ),
      ),
      child: child,
    );
  }
}

// --- Tour card --------------------------------------------------------------

/// The photo panel on one list card, keyed so a test can measure it against the
/// card it bleeds into.
@visibleForTesting
Key tourCardThumbnailKey(String tourId) => ValueKey('tour-thumb-$tourId');

/// One tour in the list.
///
/// The photo sits on the **leading** edge and the rating on the **trailing**
/// edge, so the whole card mirrors in Kurdish and Arabic instead of reading
/// backwards.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.languageCode,
    required this.deviceLocation,
    required this.pricing,
    required this.isFavorite,
    required this.favoritePending,
    required this.onFavorite,
    required this.onTap,
  });

  final Tour tour;
  final String languageCode;
  final DeviceLocation? deviceLocation;
  final TourPricing pricing;
  final bool isFavorite;
  final bool favoritePending;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  // --- Base geometry --------------------------------------------------------
  //
  // The whole card is laid out once at this fixed size and then scaled to the
  // width it is given, so every phone shows the *same* card, only larger or
  // smaller — the approved reference is a proportion, not a pixel size. Nothing
  // inside reflows between devices, which is what the reference asks for.

  /// The width the layout below is written against.
  static const double baseWidth = 360;

  /// Height of that layout. `baseWidth / baseHeight` is the card's aspect
  /// ratio, held on every screen.
  static const double baseHeight = 184;

  /// Beyond this the card would stop looking like a card on a tablet, so the
  /// scaling stops and the card centres instead.
  static const double maxWidth = 520;

  static const double _pad = 9;
  static const double _photoWidth = 102;
  static const double _photoGap = 10;

  /// The trailing column: the operator tag, the facility grid and the price
  /// badge all share this width.
  static const double _badgeColumnWidth = 84;

  /// How wide the place block (6 and 7) is allowed to run before it would
  /// reach under the trailing column.
  static const double _placeColumnWidth = 130;

  /// How far the price and the facility grid ride above where they would
  /// otherwise sit, as requested.
  static const double _lift = 5;

  /// How far the date is nudged off the trailing edge, as requested — 2, then
  /// 3 more.
  static const double _dateNudge = 5;

  /// How many facility icons fit the 2x3 grid. A tour tagged with more keeps
  /// them all in Firestore — opening the card shows the full set on the Tour
  /// Detail screen.
  static const int maxFeaturesOnCard = 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : baseWidth,
          maxWidth,
        );
        return Center(
          child: SizedBox(
            width: width,
            height: width * baseHeight / baseWidth,
            child: FittedBox(
              fit: BoxFit.fill,
              child: MediaQuery.withNoTextScaling(
                // The card is a scaled drawing: letting the system font size
                // grow the text inside a fixed box would overflow it. The text
                // still grows with the card itself on a larger phone.
                child: SizedBox(
                  width: baseWidth,
                  height: baseHeight,
                  child: _buildCard(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = _distanceText(l10n);
    final features = tour.knownFeatures.take(maxFeaturesOnCard).toList();
    final price = tour.pricePerPerson;
    final start = tour.startAt;

    return Semantics(
      button: true,
      label: tour.name(languageCode),
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: onTap,
        child: GlassPanel(
          borderRadius: _cardRadius,
          padding: const EdgeInsets.all(_pad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1 — the photo, inset from the rim on all four sides, with the
              // favourite heart laid over the top of it. No rating is drawn on
              // a list card at all now: neither the number nor the stars.
              SizedBox(
                key: tourCardThumbnailKey(tour.id),
                width: _photoWidth,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _TourPhoto(tour: tour, index: 0),
                      ),
                    ),
                    PositionedDirectional(
                      top: 2,
                      start: 2,
                      child: _FavoriteButton(
                        isFavorite: isFavorite,
                        pending: favoritePending,
                        onTap: onFavorite,
                        targetSize: 30,
                        circleSize: 24,
                        iconSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _photoGap),
              // Everything else is placed against the card's own height rather
              // than stacked in one flow: the place block sits on the card's
              // vertical centre, the description on its floor, and the trailing
              // column rides 5dp above both. A Column could not hold all three
              // at once.
              Expanded(
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      child: _buildHeader(context, l10n),
                    ),
                    // 6 and 7 — centred on the card's own vertical middle.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: _placeColumnWidth,
                        child: _buildPlaceBlock(context, l10n, distance),
                      ),
                    ),
                    // 8–13, on the card's vertical middle beside the place
                    // block, lifted just clear of the date above the price.
                    PositionedDirectional(
                      top: 0,
                      bottom: _lift * 2,
                      end: 0,
                      width: _badgeColumnWidth,
                      child: _buildBadgeColumn(context, features),
                    ),
                    // The description sits on the card's floor; the date and
                    // the price (5) ride 5dp above it on the trailing side.
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              tour.description(languageCode),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                height: 12.4 / 9.5,
                                color: AppColors.secondaryText(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Transform.translate(
                            offset: const Offset(0, -_lift),
                            child: _buildPriceStack(
                              context,
                              l10n,
                              start,
                              price,
                            ),
                          ),
                        ],
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

  /// The tour name and its duration on the leading side; the operator tag (4)
  /// on the card's top trailing corner.
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tour.name(languageCode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 19 / 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading(context),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                l10n.tourDuration(tour.durationDays),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (tour.companyTag.isNotEmpty)
          _CompanyTag(label: tour.companyTag, compact: true),
      ],
    );
  }

  /// 6 (the place) with the distance beneath it, then 7 (availability).
  Widget _buildPlaceBlock(
    BuildContext context,
    AppLocalizations l10n,
    String? distance,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardIconLine(
          icon: Icons.location_on_outlined,
          text: tour.locationLabel(languageCode),
          fontSize: 11.5,
          bold: true,
          color: AppColors.heading(context),
        ),
        if (distance != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _CardIconLine.circleSize + _CardIconLine.gap,
              top: 1,
            ),
            child: Text(
              distance,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                color: AppColors.secondaryText(context),
              ),
            ),
          ),
        if (tour.isLowAvailability) ...[
          const SizedBox(height: 3),
          _CardIconLine(
            icon: Icons.event_seat_outlined,
            text: l10n.tourSpotsLeft(tour.spotsLeft!),
            fontSize: 11,
            bold: true,
            // The one line on the card that is a warning rather than
            // information, so it keeps the semantic warning token.
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ],
    );
  }

  /// 8–13 — the facility icons, icon-only. The operator tag that used to sit
  /// above them now rides in the header, on the card's top trailing corner.
  ///
  /// Centred on the card's own height, level with the place block across the
  /// card. The band it centres in stops short of the card's floor so the grid
  /// cannot land on the date above the price.
  Widget _buildBadgeColumn(BuildContext context, List<TourFeature> features) {
    if (features.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: _FeatureGrid(features: features),
    );
  }

  /// The departure dates directly over 5 (the price), sharing its width.
  Widget _buildPriceStack(
    BuildContext context,
    AppLocalizations l10n,
    DateTime? start,
    num? price,
  ) {
    return SizedBox(
      width: _badgeColumnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (start != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: 2,
                // Off the trailing edge by 2, as asked — mirrored in Kurdish
                // and Arabic so it stays on the same side as the price.
                end: _dateNudge,
              ),
              child: Text(
                l10n.tourDateRange(start, tour.endAt),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  height: 11 / 8.5,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ),
          if (price != null)
            _PriceBox(
              price: price,
              currency: tour.currency,
              pricing: pricing,
              compact: true,
            ),
        ],
      ),
    );
  }

  /// "2.3 km from current location", or null when either the device position
  /// or the tour's coordinates are missing — in which case the line is not
  /// drawn at all, rather than showing a distance from somewhere the user
  /// is not.
  String? _distanceText(AppLocalizations l10n) {
    final from = deviceLocation;
    if (from == null) return null;
    final meters = tour.distanceMetersFrom(from.latitude, from.longitude);
    if (meters == null) return null;
    return l10n.distanceFromCurrentLocation(formatTourDistance(meters));
  }
}

/// One icon-and-text line on the card — 6 (the place) and 7 (availability).
///
/// The icon sits in the stroke-only circle every feature icon in the app uses
/// (`DESIGN_SYSTEM.md` 11.1), which is what the reference draws around both.
class _CardIconLine extends StatelessWidget {
  const _CardIconLine({
    required this.icon,
    required this.text,
    required this.fontSize,
    required this.color,
    this.bold = false,
  });

  final IconData icon;
  final String text;
  final double fontSize;
  final Color color;
  final bool bold;

  static const double circleSize = 15;
  static const double gap = 4;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
          child: Icon(icon, size: circleSize - 6, color: color),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// 8–13: the facilities, as a 2x3 grid of icon-only circles.
///
/// No label under them, on request — the name of each is still announced to a
/// screen reader, and the full labelled list is on the Tour Detail screen.
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features});

  final List<TourFeature> features;

  static const int columns = 3;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < features.length; i += columns) {
      final slice = features.skip(i).take(columns).toList();
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final feature in slice) _FeatureIcon(feature: feature),
            // Keeps a short last row aligned under the first one instead of
            // spreading three icons' worth of gap between two.
            for (var pad = slice.length; pad < columns; pad++)
              const SizedBox(width: _FeatureIcon.circleSize),
          ],
        ),
      );
      if (i + columns < features.length) {
        rows.add(const SizedBox(height: 6));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// Metres under a kilometre, then one decimal up to 10 km, then whole
/// kilometres — "0.3 km" and "127.4 km" are both worse than "300 m" and
/// "127 km".
///
/// Mirrors `formatSpotDistance` on the Explore Nature screen. Kept as its own
/// copy rather than imported because that one is `@visibleForTesting`; if a
/// third screen needs it, move both into a shared helper then.
@visibleForTesting
String formatTourDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

/// The heart drawn on a tour photo.
///
/// Mirrors the Home screen's featured-card control exactly — a favourite is
/// one concept, so it must not look like two.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.pending,
    required this.onTap,
    this.targetSize = 48,
    this.circleSize = 34,
    this.iconSize = 19,
  });

  final bool isFavorite;

  /// True while the write is in flight, so a double-tap cannot fire twice.
  final bool pending;

  final VoidCallback onTap;

  /// The three sizes shrink together on the list card, whose photo is drawn at
  /// the card's own scale rather than at device pixels — see
  /// [_TourCard.baseWidth]. The carousel keeps the full-size defaults.
  final double targetSize;
  final double circleSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;

    return Semantics(
      button: true,
      selected: isFavorite,
      enabled: !pending,
      label: AppLocalizations.of(context).navSaved,
      child: SizedBox(
        // 34dp circle inside a 48dp target — the GlassBackButton pattern,
        // trimmed to sit on a 140dp thumbnail.
        width: targetSize,
        height: targetSize,
        child: InkWell(
          onTap: pending ? null : onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.darkGlassTop.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.9),
              ),
              child: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: iconSize,
                color: accent.withValues(alpha: pending ? 0.4 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The operator badge — "AB group".
///
/// Glass rather than a solid pill, per `DESIGN_SYSTEM.md` 5: badges sitting on
/// another glass surface use the shared material at the next layer up (6.1),
/// which is what `elevated` selects.
class _CompanyTag extends StatelessWidget {
  const _CompanyTag({
    required this.label,
    this.onPhoto = false,
    this.compact = false,
  });

  final String label;

  /// True when the tag sits directly on a photograph rather than on a glass
  /// card, which is the one case its label is white in both themes.
  final bool onPhoto;

  /// The list card draws this pill inside a 90dp trailing column
  /// ([_TourCard.baseWidth]), which the full-size padding cannot share.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 90 : 110),
      child: GlassPanel(
        borderRadius: 999,
        depth: GlassDepth.top,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            // `label` from the type scale: 12 / 600.
            fontSize: compact ? 9 : 12,
            fontWeight: FontWeight.w600,
            color: onPhoto ? Colors.white : AppColors.heading(context),
          ),
        ),
      ),
    );
  }
}

/// One "what's included" icon.
///
/// A stroke-only circle, per `DESIGN_SYSTEM.md` 11.1 — the same feature-icon
/// family the Home screen and Explore Nature already use. The list card draws
/// these **without** their label, on request, so the name reaches a screen
/// reader through [Semantics] and a sighted user through the Tour Detail
/// screen, where the full labelled list lives.
class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.feature});

  final TourFeature feature;

  /// Sized for the card's 2x3 trailing grid, drawn at the card's own scale
  /// rather than at device pixels — see [_TourCard.baseWidth].
  static const double circleSize = 22;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accent(context);
    final label = l10n.tourFeatureLabel(feature);

    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Stroke only — no fill, per 11.1.
            border: Border.all(color: accent, width: 1.2),
          ),
          child: Icon(_iconFor(feature), size: 12, color: accent),
        ),
      ),
    );
  }

  static IconData _iconFor(TourFeature feature) => switch (feature) {
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
}

/// "$55 / per person", with the party total beneath it when more than one
/// person is travelling. In the small rounded-box badge family
/// (`DESIGN_SYSTEM.md` 13.4: radius 12, compact, high contrast).
class _PriceBox extends StatelessWidget {
  const _PriceBox({
    required this.price,
    required this.currency,
    required this.pricing,
    this.compact = false,
  });

  final num price;
  final String currency;
  final TourPricing pricing;

  /// The list card's badge column is 90dp wide ([_TourCard.baseWidth]), too
  /// narrow for the amount and the "per person" label side by side — compact
  /// stacks the label under the figure instead. Radius, material and colour
  /// tokens are unchanged.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final perPerson = pricing.perPerson(price, currency);
    final total = pricing.total(price, currency);

    return Semantics(
      // The screen reader gets the operator's own price too, which is the one
      // that will actually be charged.
      label: pricing.isConverted(currency)
          ? '$perPerson (${formatMoney(price, currency)})'
          : perPerson,
      child: GlassPanel(
        borderRadius: 12,
        depth: GlassDepth.top,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 5 : 8,
        ),
        child: compact
            ? _buildCompact(context, perPerson, total, l10n)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amount and "per person" side by side on one row, as the
                  // reference draws it — the label wraps onto two short lines
                  // beside the figure rather than sitting under it.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          // A price is a measurement sequence: it stays
                          // left-to-right in every language (`DESIGN_SYSTEM.md` 21).
                          perPerson,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            height: 24 / 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heading(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        // Wide enough for "Per Person" on two lines and for the
                        // Kurdish and Arabic labels, narrow enough that the badge
                        // stays a badge.
                        constraints: const BoxConstraints(maxWidth: 46),
                        child: Text(
                          l10n.tourPerPersonBadge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 12 / 10,
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (total != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.tourTotalFor(total),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent(context),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  /// The card's version: the amount on the leading side with "per person"
  /// beside it on the same row, as the full-size badge draws it, squeezed to
  /// fit the card's trailing column.
  Widget _buildCompact(
    BuildContext context,
    String perPerson,
    String? total,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  // A price is a measurement sequence: it stays left-to-right
                  // in every language (`DESIGN_SYSTEM.md` 21).
                  perPerson,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    height: 17 / 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            ConstrainedBox(
              // Two short lines of "Per Person" beside the figure — the same
              // shape the full-size badge uses, at the card's scale. Wide
              // enough for the Kurdish and Arabic labels too.
              constraints: const BoxConstraints(maxWidth: 30),
              child: Text(
                l10n.tourPerPersonBadge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  height: 10 / 8,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ),
          ],
        ),
        if (total != null)
          Text(
            l10n.tourTotalFor(total),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              height: 11 / 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accent(context),
            ),
          ),
      ],
    );
  }
}

// --- Loading / error / empty ------------------------------------------------

/// Shared frame for this screen's loading, error and empty states, so the
/// layout does not jump between them.
class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: _cardRadius,
    padding: const EdgeInsets.all(20),
    child: Center(child: child),
  );
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: CircularProgressIndicator(
      strokeWidth: 2.5,
      color: AppColors.accent(context),
    ),
  );
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.secondaryText(context),
          ),
        ),
        if (label != null && action != null) ...[
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: label,
            child: InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkOnPrimary : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
