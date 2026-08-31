import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../models/featured_item.dart';
import '../services/auth_service.dart';
import '../services/featured_service.dart';
import '../services/favorites_service.dart';
import '../services/profile_setup_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/home_background.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/home_drawer.dart';
import 'explore_nature_screen.dart';
import 'explore_tours_screen.dart';
import 'flight_ticketing_screen.dart';
import 'hotel_screen.dart';
import 'car_rental_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'my_bookings_screen.dart';

/// Phase 2 — the main dashboard, shown once the user has logged in or chosen
/// "Continue as Guest".
///
/// Layout comes from the `main screen.jpeg` reference; every colour, radius
/// and text size comes from `DESIGN light.md` / `DESIGN dark.md` via the
/// theme's [ColorScheme] and [AppColors]. Both modes are built together — the
/// screen reads the ambient [Brightness] and never branches on a hardcoded
/// colour.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.isGuest = true,
    this.displayName,
    this.featuredService,
    this.favoritesService,
    this.userProfileService,
    this.authService,
    this.profileSetupService,
    this.picker,
    this.now,
  });

  /// Guests see the whole screen, but cannot favorite anything — they get a
  /// sign-in prompt instead. See `SECURITY.md` 6.1f.
  final bool isGuest;

  /// Shown after the greeting. Falls back to a localized "Dear User".
  final String? displayName;

  /// Injectable for tests; defaults to the real Firestore-backed services.
  final FeaturedService? featuredService;
  final FavoritesService? favoritesService;

  /// Passed straight through to the side drawer ([HomeDrawer]); injectable
  /// for tests the same way as [featuredService]/[favoritesService].
  final UserProfileService? userProfileService;
  final AuthService? authService;
  final ProfileSetupService? profileSetupService;
  final ImagePicker? picker;

  /// Fixes "now" in tests so the time-of-day greeting is deterministic.
  final DateTime? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FeaturedService _featuredService =
      widget.featuredService ?? FeaturedService();
  late final FavoritesService _favoritesService =
      widget.favoritesService ?? FavoritesService();

  late Future<List<FeaturedItem>> _featuredFuture;

  final PageController _carouselController = PageController();
  int _currentSlide = 0;

  /// Nature-spot total for the Explore Nature button. Null until it loads,
  /// and stays null if the count is unavailable — the button then falls back
  /// to a plain "Explore" rather than showing an invented number.
  int? _natureSpotCount;

  /// `itemId`s the signed-in user has already favorited.
  Set<String> _favoriteIds = <String>{};

  /// Favorites currently being written, so a double-tap can't fire twice.
  final Set<String> _pendingFavorites = <String>{};

  HomeNavTab _currentTab = HomeNavTab.home;

  @override
  void initState() {
    super.initState();
    _featuredFuture = _featuredService.fetchFeatured();
    _loadSecondaryData();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  /// The count and the favorite list are both non-essential: if either fails
  /// the screen still works, so neither is allowed to surface an error.
  Future<void> _loadSecondaryData() async {
    final count = await _featuredService.fetchNatureSpotCount();
    if (mounted && count != null) setState(() => _natureSpotCount = count);

    if (widget.isGuest) return;
    try {
      final ids = await _favoritesService.fetchFavoriteItemIds();
      if (mounted) setState(() => _favoriteIds = ids);
    } catch (e) {
      debugPrint('Could not load favorites: $e');
    }
  }

  void _retryFeatured() {
    setState(() {
      _currentSlide = 0;
      _featuredFuture = _featuredService.fetchFeatured();
    });
  }

  String _greeting(AppLocalizations l10n) {
    final now = widget.now ?? DateTime.now();
    final name = widget.displayName?.trim();
    final who = (name == null || name.isEmpty) ? l10n.dearUser : name;
    // Arabic and Kurdish use their own comma character.
    final comma = Localizations.localeOf(context).languageCode == 'en'
        ? ','
        : '،';
    return '${l10n.greetingForHour(now.hour)}$comma $who';
  }

  // --- Actions --------------------------------------------------------------

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onFavoriteTapped(FeaturedItem item) async {
    final l10n = AppLocalizations.of(context);

    if (widget.isGuest) {
      await _showSignInPrompt();
      return;
    }
    if (_pendingFavorites.contains(item.referenceId)) return;

    final wasFavorite = _favoriteIds.contains(item.referenceId);
    setState(() => _pendingFavorites.add(item.referenceId));
    try {
      final nowFavorite = await _favoritesService.toggle(
        itemType: item.type,
        itemId: item.referenceId,
        currentlyFavorite: wasFavorite,
      );
      if (!mounted) return;
      setState(() {
        if (nowFavorite) {
          _favoriteIds.add(item.referenceId);
        } else {
          _favoriteIds.remove(item.referenceId);
        }
      });
      _snack(nowFavorite ? l10n.addedToFavorites : l10n.removedFromFavorites);
    } catch (e) {
      debugPrint('Favorite toggle failed: $e');
      if (mounted) _snack(l10n.favoriteFailed);
    } finally {
      if (mounted) setState(() => _pendingFavorites.remove(item.referenceId));
    }
  }

  Future<void> _showSignInPrompt() async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GlassSheet(
        dark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.signInToSave,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _headingColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.signInToSaveBody,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.secondaryText(context),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ArrowPill(
                    label: l10n.logIn,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(
                    l10n.notNow,
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Changes the app's language **in place** — no navigation. [appLocale] is
  /// what `MaterialApp` listens to, so the whole tree (including this screen)
  /// rebuilds in the new language and text direction.
  Future<void> _showLanguageSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = Localizations.localeOf(context).languageCode;
    final topInset = MediaQuery.paddingOf(context).top;
    final textDirection = Directionality.of(context);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context).changeLanguage,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) => Dialog(
        alignment: AlignmentDirectional.topEnd,
        constraints: const BoxConstraints.tightFor(
          width: _LanguagePopover.menuWidth,
        ),
        insetPadding: EdgeInsetsDirectional.only(
          top: topInset + 58,
          end: 8,
        ).resolve(textDirection),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: _LanguagePopover(
          dark: isDark,
          current: current,
          onSelected: (languageCode) {
            appLocale.value = Locale(languageCode);
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  /// Opens the side drawer. `transitionDuration: Duration.zero` and
  /// `barrierColor: Colors.transparent` hand all animation and scrim drawing
  /// to [HomeDrawer] itself, so it has full control over its own open/close
  /// motion (needed for the wavy-edge ripple to play on both directions).
  Future<void> _openDrawer() async {
    final l10n = AppLocalizations.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: l10n.menu,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) => HomeDrawer(
        isGuest: widget.isGuest,
        displayName: widget.displayName,
        userProfileService: widget.userProfileService,
        authService: widget.authService,
        profileSetupService: widget.profileSetupService,
        picker: widget.picker,
      ),
    );
  }

  /// The one journey card with a screen behind it (`ROADMAP.md` Phase 3).
  /// The other four stay on "Coming soon" until their phase is built.
  Future<void> _openExploreNature() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ExploreNatureScreen()),
    );
  }

  Future<void> _openExploreTours() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ExploreToursScreen()));
  }

  Future<void> _openFlightTicketing() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FlightTicketingScreen()),
    );
  }

  Future<void> _openCarRental() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CarRentalScreen()));
  }

  Future<void> _openHotel() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HotelScreen()));
  }

  Future<void> _onNavSelected(HomeNavTab tab) async {
    final l10n = AppLocalizations.of(context);
    switch (tab) {
      case HomeNavTab.home:
        setState(() => _currentTab = HomeNavTab.home);
      case HomeNavTab.map:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen()));
      case HomeNavTab.trips:
        // Same destination as the drawer's My Bookings row. A guest is pushed
        // the same screen rather than blocked here — the screen itself explains
        // that bookings need an account and offers a route to Login.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyBookingsScreen(
              isGuest: widget.isGuest,
              // Reached from the bar, so the bar stays put.
              showBottomNav: true,
            ),
          ),
        );
      case HomeNavTab.saved:
        // Phase 8 of ROADMAP.md — not built yet, and not built ahead here.
        _snack(l10n.comingSoon);
    }
  }

  // --- Build ----------------------------------------------------------------

  static Color _headingColor(BuildContext context) =>
      AppColors.heading(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      // The glass bar floats over the content rather than sitting in a
      // solid-coloured slot.
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: HomeBackground(
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  8,
                  8,
                  8,
                  // Clear the floating bar plus its own bottom margin.
                  HomeBottomNav.barHeight + bottomInset + 40,
                ),
                children: [
                  _TopBar(onMenu: _openDrawer, onLanguage: _showLanguageSheet),
                  const SizedBox(height: 16),
                  Text(
                    _greeting(l10n),
                    style: TextStyle(
                      // headline-lg-mobile, DESIGN light.md
                      fontSize: 26,
                      height: 32 / 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02 * 26,
                      color: _headingColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Transform.translate(
                    offset: const Offset(0, -5),
                    child: Text(
                      l10n.whereWouldYouLikeToGo,
                      style: TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildCarousel(),
                  const SizedBox(height: 8),
                  Transform.translate(
                    offset: const Offset(0, 10),
                    child: _SectionHeader(label: l10n.planYourJourney),
                  ),
                  const SizedBox(height: 14),
                  _buildJourneyGrid(l10n),
                ],
              ),
            ),
            HomeBottomNav.floating(
              context: context,
              current: _currentTab,
              onSelect: _onNavSelected,
              dark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: _FeaturedCard.heightFor(context),
      child: FutureBuilder<List<FeaturedItem>>(
        future: _featuredFuture,
        builder: (context, snapshot) {
          final l10n = AppLocalizations.of(context);

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _CarouselShell(child: _CarouselLoading());
          }
          if (snapshot.hasError) {
            return _CarouselShell(
              child: _CarouselMessage(
                message: l10n.featuredLoadFailed,
                actionLabel: l10n.tryAgain,
                onAction: _retryFeatured,
              ),
            );
          }

          final items = snapshot.data ?? const <FeaturedItem>[];
          if (items.isEmpty) {
            return _CarouselShell(
              child: _CarouselMessage(message: l10n.featuredEmpty),
            );
          }

          final languageCode = Localizations.localeOf(context).languageCode;
          return Stack(
            children: [
              PageView.builder(
                controller: _carouselController,
                itemCount: items.length,
                onPageChanged: (index) => setState(() => _currentSlide = index),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _FeaturedCard(
                    item: item,
                    languageCode: languageCode,
                    isFavorite: _favoriteIds.contains(item.referenceId),
                    onFavorite: () => _onFavoriteTapped(item),
                    // The detail screens are Phase 3+; nothing is built ahead.
                    onExplore: () =>
                        _snack(AppLocalizations.of(context).comingSoon),
                  );
                },
              ),
              // The dots belong to the carousel, not to any one slide, so
              // they sit outside the PageView and stay still as it scrolls.
              PositionedDirectional(
                end: 18,
                bottom: 18,
                child: _Dots(count: items.length, current: _currentSlide),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJourneyGrid(AppLocalizations l10n) {
    final count = _natureSpotCount;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _JourneyCard(
                  icon: Icons.park_outlined,
                  title: _breakAfterFirstWord(l10n.exploreNature),
                  hint: l10n.exploreNatureHint,
                  // Falls back to "Explore" rather than inventing a number.
                  buttonLabel: count == null
                      ? l10n.explore
                      : l10n.placesCount(count),
                  imageAsset: 'assets/images/journey-nature.png',
                  contentOffsetY: 22,
                  buttonOffsetY: 10,
                  onTap: _openExploreNature,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _JourneyCard(
                  icon: Icons.king_bed_outlined,
                  title: _breakAfterFirstWord(l10n.whereToStay),
                  hint: l10n.whereToStayHint,
                  buttonLabel: l10n.bestPrice,
                  imageAsset: 'assets/images/journey-stay.png',
                  contentOffsetY: 22,
                  buttonOffsetY: 10,
                  onTap: _openHotel,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _JourneyCard(
          icon: Icons.directions_car_outlined,
          title: l10n.carRental,
          hint: l10n.carRentalHint,
          buttonLabel: l10n.findACar,
          imageAsset: 'assets/images/journey-car.png',
          wide: true,
          contentOffsetY: 16,
          buttonOffsetX: -60,
          onTap: _openCarRental,
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _JourneyCard(
                  icon: Icons.flight_takeoff_outlined,
                  title: _breakAfterFirstWord(l10n.flightTicketing),
                  hint: l10n.flightTicketingHint,
                  buttonLabel: l10n.findFlight,
                  imageAsset: 'assets/images/journey-flight.png',
                  contentOffsetY: 18,
                  buttonOffsetY: 10,
                  onTap: _openFlightTicketing,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _JourneyCard(
                  icon: Icons.festival_outlined,
                  title: _breakAfterFirstWord(l10n.exploreToursTitle),
                  hint: l10n.exploreToursHint,
                  buttonLabel: l10n.findTours,
                  imageAsset: 'assets/images/journey-tours.png',
                  contentOffsetY: 18,
                  buttonOffsetY: 10,
                  onTap: _openExploreTours,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _breakAfterFirstWord(String value) {
    final separator = value.indexOf(' ');
    if (separator < 0) return value;
    return '${value.substring(0, separator)}\n${value.substring(separator + 1)}';
  }
}

// --- Top bar ----------------------------------------------------------------

/// Hamburger (leading) · logo (centred) · language globe (trailing).
///
/// The logo is drawn bare, with no pill or frame around it, per the spec.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onMenu, required this.onLanguage});

  final VoidCallback onMenu;
  final VoidCallback onLanguage;

  static const double height = 56;
  static const double logoHeight = 42;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Align(
            // Directional, so the menu button follows the reading direction
            // in Kurdish and Arabic the way a drawer affordance should.
            alignment: AlignmentDirectional.centerStart,
            child: _IconAction(
              icon: Icons.menu_rounded,
              tooltip: l10n.menu,
              onTap: onMenu,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/logo.png',
              height: logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(height: logoHeight),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _IconAction(
              icon: Icons.public,
              tooltip: l10n.changeLanguage,
              onTap: onLanguage,
            ),
          ),
        ],
      ),
    );
  }
}

/// A bare icon button that still honours the 48dp minimum touch target.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : AppColors.actionNavy;
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 28, color: color),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// --- Featured carousel ------------------------------------------------------

/// One slide: photo, star rating, favourite heart, title, location, Explore.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.item,
    required this.languageCode,
    required this.isFavorite,
    required this.onFavorite,
    required this.onExplore,
  });

  final FeaturedItem item;
  final String languageCode;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onExplore;

  /// Base height, grown for large system font sizes so the overlaid copy
  /// never runs out of room.
  static double heightFor(BuildContext context) {
    final factor = (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(
      1.0,
      1.6,
    );
    return 270 * factor;
  }

  /// `DESIGN light.md`: "Standard Cards: 16px". `DESIGN dark.md`: cards use
  /// `rounded-xl` (24px).
  static double radiusFor(BuildContext context) => 28;

  @override
  Widget build(BuildContext context) {
    final radius = radiusFor(context);

    return Padding(
      // Keeps a gap between slides as the PageView scrolls.
      padding: const EdgeInsets.only(right: 2, left: 2),
      child: Semantics(
        button: true,
        label: item.title(languageCode),
        child: InkWell(
          onTap: onExplore,
          borderRadius: BorderRadius.circular(radius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _FeaturedPhoto(item: item),
                // Scrim, so white copy stays legible over any photograph.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x00000000),
                        Color(0xA6000000),
                      ],
                      stops: [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
                Padding(
                  // A zero bottom inset lowers the destination copy and CTA by
                  // roughly 14px while keeping the top controls unchanged.
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (item.rating != null)
                            _RatingPill(rating: item.rating!),
                          const Spacer(),
                          _FavoriteButton(
                            isFavorite: isFavorite,
                            onTap: onFavorite,
                          ),
                        ],
                      ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          item.title(languageCode),
                          maxLines: 1,
                          style: const TextStyle(
                            // headline-lg
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle(languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Flexible, not fixed: on a 320dp screen the pill has
                          // to be allowed to shrink (its label is already inside
                          // a scale-down FittedBox) rather than overflow.
                          Flexible(
                            child: _ArrowPill(
                              label: AppLocalizations.of(context).explore,
                              onTap: onExplore,
                              compact: true,
                              visualHeight: 40,
                            ),
                          ),
                          // Keeps the pill clear of the dot row in the opposite
                          // corner, which is drawn outside this slide.
                          const SizedBox(width: 64),
                        ],
                      ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkBorderOpacity
                              : 0.62,
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
    );
  }
}

/// The slide photo: a Storage URL in production, a bundled asset in preview
/// mode. Both fall back to the brand colour rather than a broken-image box.
class _FeaturedPhoto extends StatelessWidget {
  const _FeaturedPhoto({required this.item});

  final FeaturedItem item;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkForestFloor
          : AppColors.pageGradientBottom,
    );

    final asset = item.imageAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        cacheHeight:
            (_FeaturedCard.heightFor(context) *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    final url = item.imageUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

/// Star + score, replacing the reference's "FEATURED DESTINATION" pin label.
class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkGlassTop : AppColors.actionNavy)
            .withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 16,
            color: isDark ? AppColors.luminousMint : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            // Always left-to-right: a decimal score reads the same way in
            // every language.
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05 * 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;

    return Semantics(
      button: true,
      selected: isFavorite,
      label: AppLocalizations.of(context).navSaved,
      child: SizedBox(
        // 40dp circle inside a 48dp target — the GlassBackButton pattern.
        width: 48,
        height: 48,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
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
                size: 21,
                color: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Key on the carousel's dot row, so a test can assert it really is laid out
/// left-to-right even when the app is in Kurdish or Arabic.
@visibleForTesting
const Key carouselDotsRowKey = ValueKey('carousel-dots');

/// Page dots. Always laid out left-to-right, like the onboarding flight path
/// — a progress track is not a sentence.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        key: carouselDotsRowKey,
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
}

/// Shared frame for the carousel's loading / error / empty states, so the
/// layout doesn't jump between them.
class _CarouselShell extends StatelessWidget {
  const _CarouselShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: _FeaturedCard.radiusFor(context),
    padding: const EdgeInsets.all(20),
    child: Center(child: child),
  );
}

class _CarouselLoading extends StatelessWidget {
  const _CarouselLoading();

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

class _CarouselMessage extends StatelessWidget {
  const _CarouselMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
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
        if (label != null && onAction != null) ...[
          const SizedBox(height: 14),
          _ArrowPill(label: label, onTap: onAction!, showArrow: false),
        ],
      ],
    );
  }
}

// --- "Plan your journey" ----------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _HomeScreenState._headingColor(context);
    return Row(
      children: [
        Icon(Icons.explore_outlined, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              style: TextStyle(
                // headline-md
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One "plan your journey" tile: circled icon, title, hint, arrow pill.
///
/// [imageAsset] is the per-card photograph from the reference design. Until
/// those five photos are supplied the card falls back to the design system's
/// glass fill, and switches its copy to on-surface colours so the text stays
/// readable in light mode — white-on-glass would not be.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.buttonLabel,
    required this.onTap,
    required this.imageAsset,
    this.wide = false,
    this.contentOffsetY = 0,
    this.buttonOffsetX = 0,
    this.buttonOffsetY = 0,
  });

  final IconData icon;
  final String title;
  final String hint;
  final String buttonLabel;
  final VoidCallback onTap;
  final String? imageAsset;
  final bool wide;
  final double contentOffsetY;
  final double buttonOffsetX;
  final double buttonOffsetY;

  @override
  Widget build(BuildContext context) {
    final radius = _FeaturedCard.radiusFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final onPhoto = imageAsset != null;
    // Horizontal tweaks are authored for the English (LTR) layout. Mirror
    // them in Arabic and Kurdish so the CTA keeps the same relative position
    // on the opposite side of the card.
    final directionalButtonOffsetX = isRtl ? -buttonOffsetX : buttonOffsetX;

    final titleColor = onPhoto || isDark
        ? Colors.white
        : _HomeScreenState._headingColor(context);
    final hintColor = onPhoto
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.secondaryText(context);

    final content = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircledIcon(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, contentOffsetY),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CardTitle(title: title, color: titleColor),
                          const SizedBox(height: 6),
                          _CardHint(hint: hint, color: hintColor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Transform.translate(
                        offset: Offset(directionalButtonOffsetX, buttonOffsetY),
                        child: _ArrowPill(
                          label: buttonLabel,
                          onTap: onTap,
                          compact: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircledIcon(icon: icon),
              const SizedBox(height: 14),
              // Pushes the copy to the bottom when this card is shorter than
              // the one beside it, so both button rows line up.
              const Spacer(),
              Transform.translate(
                offset: Offset(0, contentOffsetY),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardTitle(title: title, color: titleColor),
                    const SizedBox(height: 6),
                    _CardHint(hint: hint, color: hintColor),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Transform.translate(
                offset: Offset(directionalButtonOffsetX, buttonOffsetY),
                child: _ArrowPill(
                  label: buttonLabel,
                  onTap: onTap,
                  compact: true,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: wide ? 140 : 196),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                if (onPhoto)
                  Positioned.fill(
                    child: Image.asset(
                      imageAsset!,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                if (onPhoto)
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x26000000),
                            Color(0x52000000),
                            Color(0xC2000000),
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                if (!onPhoto)
                  Positioned.fill(
                    child: GlassPanel(
                      borderRadius: radius,
                      child: const SizedBox.expand(),
                    ),
                  ),
                Padding(padding: const EdgeInsets.all(16), child: content),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isDark ? AppColors.darkBorderOpacity : 0.62,
                          ),
                          width: 1.2,
                        ),
                      ),
                    ),
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

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    title,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      // headline-md
      fontSize: 20,
      height: 26 / 20,
      fontWeight: FontWeight.w700,
      color: color,
    ),
  );
}

class _CardHint extends StatelessWidget {
  const _CardHint({required this.hint, required this.color});

  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    hint,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      // body-sm
      fontSize: 14,
      height: 20 / 14,
      color: color,
    ),
  );
}

/// The outlined circle every card's icon sits inside.
class _CircledIcon extends StatelessWidget {
  const _CircledIcon({required this.icon});

  final IconData icon;

  static const double size = 46;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Icon(icon, size: 24, color: accent),
    );
  }
}

/// The pill CTA used on the featured card and every journey card: filled
/// accent, label, and a circular arrow.
///
/// `DESIGN light.md` shapes: "Selection Chips: Fully rounded (pill-shaped)".
/// These are chip-sized in-card actions, not the full-width [PrimaryButton]
/// (which stays at 12px per the same file's "Action Buttons" rule).
class _ArrowPill extends StatelessWidget {
  const _ArrowPill({
    required this.label,
    required this.onTap,
    this.showArrow = true,
    this.compact = false,
    this.visualHeight,
  }) : assert(visualHeight == null || visualHeight > 0 && visualHeight <= 48);

  final String label;
  final VoidCallback onTap;
  final bool showArrow;
  final bool compact;
  final double? visualHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    // On a Luminous Mint fill the text must be dark — the one place dark
    // text is correct in dark mode.
    final onFill = isDark ? AppColors.darkOnPrimary : Colors.white;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final pillHeight = visualHeight ?? (compact ? 34.0 : 44.0);

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          // The visible pills stay compact while their transparent vertical
          // margin preserves a full 48dp touch target.
          height: pillHeight,
          margin: EdgeInsets.symmetric(vertical: (48 - pillHeight) / 2),
          padding: EdgeInsetsDirectional.fromSTEB(
            compact ? 10 : 14,
            0,
            showArrow ? (compact ? 3 : 4) : (compact ? 10 : 14),
            0,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: onFill,
                    ),
                  ),
                ),
              ),
              if (showArrow) ...[
                SizedBox(width: compact ? 6 : 8),
                Container(
                  width: compact ? 22 : 26,
                  height: compact ? 22 : 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onFill,
                  ),
                  child: Icon(
                    // Points the way the language reads.
                    isRtl
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: compact ? 14 : 16,
                    color: fill,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --- Bottom sheets ----------------------------------------------------------

/// Glass container for this screen's modal sheets, matching the auth flow's
/// sheets. Scrollable, per the "bottom sheets scroll" rule.
class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child, required this.dark});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassPanel(
          dark: dark,
          borderRadius: 28,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}

/// Compact glass language menu anchored below the top-bar globe.
class _LanguagePopover extends StatelessWidget {
  const _LanguagePopover({
    required this.dark,
    required this.current,
    required this.onSelected,
  });

  final bool dark;
  final String current;
  final ValueChanged<String> onSelected;

  static const double menuWidth = 140;

  @override
  Widget build(BuildContext context) {
    final pointerColor = dark
        ? AppColors.darkGlassTop.withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.52);

    return SizedBox(
      width: menuWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassPanel(
              key: const ValueKey('home-language-popover'),
              dark: dark,
              borderRadius: 28,
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in const [
                    ('ku', 'کوردی'),
                    ('en', 'English'),
                    ('ar', 'العربية'),
                  ])
                    _LanguageOption(
                      key: ValueKey('language-option-${option.$1}'),
                      label: option.$2,
                      selected: option.$1 == current,
                      onTap: () => onSelected(option.$1),
                    ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 21,
            child: CustomPaint(
              size: const Size(18, 11),
              painter: _LanguagePointerPainter(pointerColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePointerPainter extends CustomPainter {
  const _LanguagePointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_LanguagePointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? (isDark ? AppColors.luminousMint : AppColors.actionNavy)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? (isDark ? AppColors.darkOnPrimary : Colors.white)
                : _HomeScreenState._headingColor(context),
          ),
        ),
      ),
    );
  }
}
