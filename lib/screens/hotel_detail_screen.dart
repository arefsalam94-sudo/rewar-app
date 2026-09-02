import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/map_availability.dart';

import '../l10n/app_localizations.dart';
import '../models/hotel.dart';
import '../models/hotel_detail.dart';
import '../models/nature_detail.dart';
import '../services/hotel_reviews_service.dart';
import '../services/hotel_service.dart';
import '../services/nature_spots_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/hotel_parts.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'choose_room_screen.dart';
import 'hotel_assets.dart';
import 'hotel_reviews_screen.dart';
import 'map_screen.dart';

/// The one detail page behind every hotel card in the app.
///
/// Highlighted hotels, trending hotels and future search results all push this
/// route with the hotel they were drawing plus the criteria the search was run
/// with, so nothing about the stay is ever re-entered. Anything the user
/// changes here is handed back on pop, which is what keeps the Where to Stay
/// screen's destination, dates, guests and options from resetting.
class HotelDetailScreen extends StatefulWidget {
  const HotelDetailScreen({
    super.key,
    required this.hotel,
    required this.criteria,
    this.service = const PreviewHotelService(),
    this.reviewService,
    this.userProfileService,
    this.onSelectRoom,
  });

  final Hotel hotel;
  final HotelSearchCriteria criteria;
  final HotelService service;
  final NatureSpotsService? reviewService;
  final UserProfileService? userProfileService;

  /// Where the sticky CTA goes. Null until the Room Selection screen exists
  /// (`ROADMAP.md` Phase 4) — the button then reports that plainly instead of
  /// pretending to book something.
  final VoidCallback? onSelectRoom;

  /// The Where to Stay photograph, reused so the whole flow reads as one
  /// screen. `DESIGN_SYSTEM.md` 4: photo, then gradient, then content.
  static const String backgroundAsset = hotelBackgroundAsset;

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  late HotelSearchCriteria _criteria = widget.criteria;
  late final NatureSpotsService _reviewService =
      widget.reviewService ??
      PreviewHotelReviewService(subject: hotelAsNatureSpot(widget.hotel));

  late Future<HotelDetail?> _detail;
  late Future<List<NatureReview>> _reviews;

  final PageController _gallery = PageController();
  int _photoIndex = 0;
  bool _policiesOpen = false;
  bool _changeEditorOpen = false;
  int? _changeMaxOccupancyPerRoom;
  late HotelSearchCriteria _changeDraft = widget.criteria;

  @override
  void initState() {
    super.initState();
    _detail = widget.service.fetchDetail(widget.hotel.id);
    _reviews = _reviewService.fetchTopReviews(widget.hotel.id);
  }

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _detail = widget.service.fetchDetail(widget.hotel.id));

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope<HotelSearchCriteria>(
      // Every exit — the button, the Android back gesture, a swipe — returns
      // the criteria, so the search behind this page can never fall out of
      // step with the stay the user just edited here.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_criteria);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Keep the photographed background visible behind the sticky CTA.
        extendBody: true,
        body: PageBackground(
          imageAsset: HotelDetailScreen.backgroundAsset,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              key: const ValueKey('hotel-detail-scroll'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 116),
                  sliver: SliverList.list(
                    children: [
                      // Physically top-left in every language
                      // (`DESIGN_SYSTEM.md` 11.3).
                      Align(
                        alignment: Alignment.topLeft,
                        child: GlassBackButton(
                          onTap: () => Navigator.of(context).pop(_criteria),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Gallery(
                        images: widget.hotel.galleryImages,
                        controller: _gallery,
                        current: _photoIndex,
                        onChanged: (index) =>
                            setState(() => _photoIndex = index),
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(
                        hotel: widget.hotel,
                        criteria: _changeEditorOpen ? _changeDraft : _criteria,
                        language: language,
                        editing: _changeEditorOpen,
                        onChange: _toggleChangeEditor,
                        onApply: () => _applyChangedStay(_changeDraft),
                        onCheckIn: () => _pickChangedDate(checkIn: true),
                        onCheckOut: () => _pickChangedDate(checkIn: false),
                        adultMaximum: _changeAdultCeiling(),
                        childMaximum: _changeChildCeiling(),
                        onAdultsChanged: (value) => setState(
                          () => _changeDraft = _changeDraft.copyWith(
                            adults: value,
                          ),
                        ),
                        onChildrenChanged: (value) => setState(
                          () => _changeDraft = _changeDraft.copyWith(
                            children: value,
                          ),
                        ),
                        onRoomsChanged: (value) => setState(
                          () => _changeDraft = _changeDraft.copyWith(
                            rooms: value,
                          ),
                        ),
                        onBedsChanged: (value) => setState(
                          () =>
                              _changeDraft = _changeDraft.copyWith(beds: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<HotelDetail?>(
                        future: _detail,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _LoadingCard();
                          }
                          if (snapshot.hasError) {
                            return _MessageCard(
                              icon: Icons.cloud_off_rounded,
                              message: l10n.hotelDetailLoadFailed,
                              actionLabel: l10n.tryAgain,
                              onAction: _reload,
                            );
                          }
                          final detail = snapshot.data;
                          if (detail == null) {
                            return _MessageCard(
                              icon: Icons.search_off_rounded,
                              message: l10n.hotelDetailNotFound,
                              actionLabel: l10n.tryAgain,
                              onAction: _reload,
                            );
                          }
                          return _Sections(
                            detail: detail,
                            language: language,
                            reviews: _reviews,
                            policiesOpen: _policiesOpen,
                            onPoliciesToggle: () =>
                                setState(() => _policiesOpen = !_policiesOpen),
                            onFacilitiesSeeAll: () => _openFacilities(detail),
                            onNearbySeeAll: () => _openNearby(detail),
                            onMapTap: _openMap,
                            onReviewsTap: _openReviews,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Frozen: the content scrolls beneath it and the last card keeps its
        // clearance through the scroll padding above.
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: PrimaryButton(
            key: const ValueKey('hotel-select-room'),
            label: l10n.hotelSelectRoom,
            onTap: widget.onSelectRoom ?? _openChooseRoom,
          ),
        ),
      ),
    );
  }

  Future<void> _openChooseRoom() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/hotel/rooms'),
        builder: (_) => ChooseRoomScreen(
          hotel: widget.hotel,
          criteria: _criteria,
          hotelService: widget.service,
        ),
      ),
    );
  }

  /// Opens the filter directly below the current-stay summary. A second tap
  /// closes it without applying its draft values.
  Future<void> _toggleChangeEditor() async {
    if (_changeEditorOpen) {
      setState(() => _changeEditorOpen = false);
      return;
    }
    final detail = await _detail.catchError((_) => null);
    if (!mounted) return;
    setState(() {
      _changeMaxOccupancyPerRoom = _maxOccupancyPerRoom(detail);
      _changeDraft = _criteria;
      _changeEditorOpen = true;
    });
  }

  int? get _changeGuestCeiling {
    final perRoom = _changeMaxOccupancyPerRoom;
    return perRoom == null ? null : perRoom * _changeDraft.rooms;
  }

  int? _changeAdultCeiling() {
    final ceiling = _changeGuestCeiling;
    if (ceiling == null) return null;
    final room = ceiling - _changeDraft.children;
    return room < 1 ? 1 : room;
  }

  int? _changeChildCeiling() {
    final ceiling = _changeGuestCeiling;
    if (ceiling == null) return null;
    final room = ceiling - _changeDraft.adults;
    return room < 0 ? 0 : room;
  }

  Future<void> _pickChangedDate({required bool checkIn}) async {
    final l10n = AppLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final first = checkIn
        ? today
        : _changeDraft.checkIn.add(const Duration(days: 1));
    final initial = checkIn ? _changeDraft.checkIn : _changeDraft.checkOut;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
      helpText: checkIn ? l10n.hotelCheckIn : l10n.hotelCheckOut,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (checkIn) {
        final checkOut = !_changeDraft.checkOut.isAfter(selected)
            ? selected.add(const Duration(days: 1))
            : _changeDraft.checkOut;
        _changeDraft = _changeDraft.copyWith(
          checkIn: selected,
          checkOut: checkOut,
        );
      } else {
        _changeDraft = _changeDraft.copyWith(checkOut: selected);
      }
    });
  }

  void _applyChangedStay(HotelSearchCriteria updated) {
    setState(() {
      _criteria = updated;
      _detail = widget.service.fetchDetail(widget.hotel.id);
      _changeEditorOpen = false;
    });
    _snack(AppLocalizations.of(context).hotelStayUpdated);
  }

  /// The occupancy ceiling the counters enforce, when the property publishes
  /// one. Null means unknown — and an unknown limit is left unenforced rather
  /// than replaced with a guess.
  int? _maxOccupancyPerRoom(HotelDetail? detail) {
    if (detail == null || detail.roomTypes.isEmpty) return null;
    return detail.roomTypes
        .map((room) => room.maxOccupancy)
        .reduce((a, b) => a > b ? a : b);
  }

  void _openMap() {
    final lat = widget.hotel.latitude;
    final lng = widget.hotel.longitude;
    if (lat == null || lng == null) return;
    final language = Localizations.localeOf(context).languageCode;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          target: LatLng(lat, lng),
          title: widget.hotel.name.forLanguage(language),
        ),
      ),
    );
  }

  void _openFacilities(HotelDetail detail) {
    final language = Localizations.localeOf(context).languageCode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FacilitiesSheet(detail: detail, language: language),
    );
  }

  void _openNearby(HotelDetail detail) {
    final language = Localizations.localeOf(context).languageCode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NearbySheet(detail: detail, language: language),
    );
  }

  Future<void> _openReviews() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HotelReviewsScreen(
          hotel: widget.hotel,
          reviewService: _reviewService,
          userProfileService: widget.userProfileService,
        ),
      ),
    );
    if (!mounted) return;
    // The viewer may have posted or edited a review while they were there.
    setState(() => _reviews = _reviewService.fetchTopReviews(widget.hotel.id));
  }
}

/// Everything below the summary card, once the detail read has resolved.
///
/// A section with no data hides itself. The alternative — an empty Facilities
/// card — tells the user the hotel has no facilities, which is a different
/// claim from "we do not have that data".
class _Sections extends StatelessWidget {
  const _Sections({
    required this.detail,
    required this.language,
    required this.reviews,
    required this.policiesOpen,
    required this.onPoliciesToggle,
    required this.onFacilitiesSeeAll,
    required this.onNearbySeeAll,
    required this.onMapTap,
    required this.onReviewsTap,
  });

  final HotelDetail detail;
  final String language;
  final Future<List<NatureReview>> reviews;
  final bool policiesOpen;
  final VoidCallback onPoliciesToggle;
  final VoidCallback onFacilitiesSeeAll;
  final VoidCallback onNearbySeeAll;
  final VoidCallback onMapTap;
  final VoidCallback onReviewsTap;

  @override
  Widget build(BuildContext context) {
    final policies = detail.policies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.facilities.isNotEmpty) ...[
          _FacilitiesCard(
            facilities: detail.facilities,
            language: language,
            onSeeAll: onFacilitiesSeeAll,
          ),
          const SizedBox(height: 12),
        ],
        if (detail.reviewSummary != null) ...[
          _ReviewScoreCard(summary: detail.reviewSummary!),
          const SizedBox(height: 12),
        ],
        _LocationCard(hotel: detail.hotel, onTap: onMapTap),
        const SizedBox(height: 12),
        if (detail.nearbyPlaces.isNotEmpty) ...[
          _NearbyCard(
            places: detail.nearbyPlaces,
            language: language,
            onSeeAll: onNearbySeeAll,
          ),
          const SizedBox(height: 12),
        ],
        _CommentsCard(reviews: reviews, onTap: onReviewsTap),
        if (policies != null && !policies.isEmpty) ...[
          const SizedBox(height: 12),
          _PoliciesCard(
            policies: policies,
            language: language,
            expanded: policiesOpen,
            onToggle: onPoliciesToggle,
          ),
        ],
      ],
    );
  }
}

/// The swipeable hotel gallery.
///
/// Renders however many photographs the hotel carries: one shows no dots, and
/// the dot row is capped so a large gallery cannot overflow the card — the
/// counter badge still states the true position.
class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.images,
    required this.controller,
    required this.current,
    required this.onChanged,
  });

  final List<String> images;
  final PageController controller;
  final int current;
  final ValueChanged<int> onChanged;

  /// Above this many photos the dots stop being readable, so only the counter
  /// is shown.
  static const int maxDots = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      image: true,
      label: l10n.hotelGalleryImage(current + 1, images.length),
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  key: const ValueKey('hotel-gallery'),
                  controller: controller,
                  itemCount: images.length,
                  onPageChanged: onChanged,
                  itemBuilder: (context, index) =>
                      HotelImage(asset: images[index], cacheWidth: 1080),
                ),
                if (images.length > 1)
                  PositionedDirectional(
                    end: 12,
                    top: 12,
                    child: GlassPanel(
                      depth: GlassDepth.top,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        l10n.hotelGalleryPosition(current + 1, images.length),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: AppColors.heading(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                if (images.length > 1 && images.length <= maxDots)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: _Dots(count: images.length, current: current),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var index = 0; index < count; index++)
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == current
                ? AppColors.onPhotoBackground
                : AppColors.onPhotoBackground.withValues(alpha: 0.5),
          ),
        ),
    ],
  );
}

/// Hotel identity plus the stay the search was run with.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.hotel,
    required this.criteria,
    required this.language,
    required this.editing,
    required this.onChange,
    required this.onApply,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onAdultsChanged,
    required this.onChildrenChanged,
    required this.onRoomsChanged,
    required this.onBedsChanged,
    this.adultMaximum,
    this.childMaximum,
  });

  final Hotel hotel;
  final HotelSearchCriteria criteria;
  final String language;
  final bool editing;
  final VoidCallback onChange;
  final VoidCallback onApply;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final ValueChanged<int> onAdultsChanged;
  final ValueChanged<int> onChildrenChanged;
  final ValueChanged<int> onRoomsChanged;
  final ValueChanged<int> onBedsChanged;
  final int? adultMaximum;
  final int? childMaximum;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = MaterialLocalizations.of(context);
    final location =
        hotel.address?.forLanguage(language) ??
        hotel.city.forLanguage(language);

    return GlassPanel(
      key: const ValueKey('hotel-stay-summary'),
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name.forLanguage(language),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: AppColors.accent(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              color: AppColors.secondaryText(context),
                              fontSize: 13,
                              height: 18 / 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              HotelCompactRatingPair(
                key: const ValueKey('hotel-detail-rating'),
                score: hotel.reviewScore,
                starRating: hotel.starRating,
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              const HotelCircleIcon(icon: Icons.groups_outlined, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.hotelGuestSummary(
                    criteria.adults,
                    criteria.children,
                    criteria.rooms,
                    criteria.beds,
                  ),
                  style: TextStyle(
                    color: AppColors.heading(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final checkIn = _StayDate(
                label: l10n.hotelCheckIn,
                value: formatter.formatMediumDate(criteria.checkIn),
                controlKey: 'sheet-check-in',
                onTap: editing ? onCheckIn : null,
              );
              final checkOut = _StayDate(
                label: l10n.hotelCheckOut,
                value: formatter.formatMediumDate(criteria.checkOut),
                controlKey: 'sheet-check-out',
                onTap: editing ? onCheckOut : null,
              );
              // Below this width two date cards squeeze the localized labels
              // into two-line ellipses, so they stack instead of shrinking.
              if (constraints.maxWidth < 340) {
                return Column(
                  children: [checkIn, const SizedBox(height: 10), checkOut],
                );
              }
              // IntrinsicHeight, not a fixed height: the two cards match each
              // other even when a localized label wraps, and neither is
              // clipped when it does.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: checkIn),
                    const SizedBox(width: 10),
                    Expanded(child: checkOut),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (editing) ...[
            GlassPanel(
              key: const ValueKey('hotel-change-guests-panel'),
              borderRadius: 26,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  HotelCounterRow(
                    icon: Icons.person_outline,
                    label: l10n.hotelAdult,
                    value: criteria.adults,
                    minimum: 1,
                    maximum: adultMaximum,
                    controlKey: 'sheet-adult',
                    onChanged: onAdultsChanged,
                  ),
                  HotelCounterRow(
                    icon: Icons.child_care,
                    label: l10n.hotelChild,
                    value: criteria.children,
                    minimum: 0,
                    maximum: childMaximum,
                    controlKey: 'sheet-child',
                    onChanged: onChildrenChanged,
                  ),
                  HotelCounterRow(
                    icon: Icons.meeting_room_outlined,
                    label: l10n.hotelRoom,
                    value: criteria.rooms,
                    minimum: 1,
                    controlKey: 'sheet-room',
                    onChanged: onRoomsChanged,
                  ),
                  HotelCounterRow(
                    icon: Icons.bed_outlined,
                    label: l10n.hotelBed,
                    value: criteria.beds,
                    minimum: 1,
                    controlKey: 'sheet-bed',
                    last: true,
                    onChanged: onBedsChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: PrimaryButton(
                key: const ValueKey('hotel-change-apply'),
                label: l10n.hotelUpdateStayApply,
                onTap: onApply,
              ),
            ),
          ] else
            Center(
              child: _PillButton(
                key: const ValueKey('hotel-change-stay'),
                icon: Icons.edit_outlined,
                label: l10n.hotelChange,
                onTap: onChange,
              ),
            ),
        ],
      ),
    );
  }
}

class _StayDate extends StatelessWidget {
  const _StayDate({
    required this.label,
    required this.value,
    required this.controlKey,
    this.onTap,
  });

  final String label;
  final String value;
  final String controlKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        const HotelCircleIcon(icon: Icons.calendar_month_outlined, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return GlassPanel(
      depth: GlassDepth.middle,
      borderRadius: 20,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(controlKey),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A card header: circled feature icon, title, and an optional See all pill.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onSeeAll,
    this.seeAllKey,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onSeeAll;
  final Key? seeAllKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HotelCircleIcon(icon: icon, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading(context),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
        if (onSeeAll != null)
          // Flexible, not fixed: at a large font scale, or with a long
          // localized label, the pill gives way rather than pushing the
          // header past the card edge.
          Flexible(
            child: _PillButton(
              key: seeAllKey,
              label: l10n.hotelSeeAll,
              trailingChevron: true,
              onTap: onSeeAll!,
            ),
          ),
      ],
    );
  }
}

/// The compact card CTA from `DESIGN_SYSTEM.md` 9.3: pill, ~40dp visual
/// height, 48dp tap target, optional directional chevron.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingChevron = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool trailingChevron;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: GlassPanel(
              depth: GlassDepth.middle,
              borderRadius: 22,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 17,
                            color: AppColors.accent(context),
                          ),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.heading(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (trailingChevron) ...[
                          const SizedBox(width: 4),
                          // Mirrors, because it points at where the next
                          // screen comes from (`DESIGN_SYSTEM.md` 21).
                          Icon(
                            rtl
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.accent(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FacilitiesCard extends StatelessWidget {
  const _FacilitiesCard({
    required this.facilities,
    required this.language,
    required this.onSeeAll,
  });

  final List<HotelFacility> facilities;
  final String language;
  final VoidCallback onSeeAll;

  /// The reference shows four before "See all"; the rest live in the sheet.
  static const int previewCount = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = facilities.take(previewCount).toList(growable: false);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.apartment_outlined,
            title: l10n.hotelFacilities,
            onSeeAll: facilities.length > previewCount ? onSeeAll : null,
            seeAllKey: const ValueKey('hotel-facilities-see-all'),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns where they fit, one where a localized label would
              // otherwise be squeezed into an ellipsis.
              final columns = constraints.maxWidth < 320 ? 1 : 2;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final facility in shown)
                    SizedBox(
                      width: width,
                      child: _FacilityRow(
                        facility: facility,
                        language: language,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FacilityRow extends StatelessWidget {
  const _FacilityRow({required this.facility, required this.language});

  final HotelFacility facility;
  final String language;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      HotelCircleIcon(icon: hotelFacilityIcon(facility.iconKey), size: 40),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          facility.name.forLanguage(language),
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 15,
            height: 20 / 15,
          ),
        ),
      ),
    ],
  );
}

/// The overall guest score and its per-category breakdown.
class _ReviewScoreCard extends StatelessWidget {
  const _ReviewScoreCard({required this.summary});

  final HotelReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.reviews_outlined,
            title: l10n.hotelReviews,
            subtitle: l10n.hotelReviewCount(summary.reviewCount),
            trailing: HotelReviewBadge(score: summary.score),
          ),
          if (summary.hasBreakdown) ...[
            const SizedBox(height: 14),
            for (final entry in summary.categoryScores.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScoreBar(category: entry.key, score: entry.value),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.category, required this.score});

  final HotelReviewCategory category;
  final double score;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = hotelReviewCategoryLabel(l10n, category);
    final value = (score / HotelReviewSummary.maxScore).clamp(0.0, 1.0);
    return Semantics(
      label: '$label ${score.toStringAsFixed(1)}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(
              hotelReviewCategoryIcon(category),
              size: 20,
              color: AppColors.accent(context),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Text(
                label,
                maxLines: 2,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Fills from the leading edge, so it grows right-to-left in
            // Arabic and Kurdish without any branch here.
            Expanded(
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: AppColors.accent(
                  context,
                ).withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.accent(context),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              child: Text(
                score.toStringAsFixed(1),
                // Scores read the same way in every language
                // (`DESIGN_SYSTEM.md` 13).
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: AppColors.heading(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.hotel, required this.onTap});

  final Hotel hotel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lat = hotel.latitude;
    final lng = hotel.longitude;
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: Icons.map_outlined, title: l10n.hotelMap),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: lat == null || lng == null || !googleMapsAvailable
                  ? ColoredBox(
                      color: AppColors.glassBaseTint(
                        context,
                      ).withValues(alpha: .22),
                      child: Center(
                        child: Text(
                          l10n.hotelMapUnavailable,
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(lat, lng),
                              zoom: 13.5,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('hotel'),
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
                          child: InkWell(
                            key: const ValueKey('hotel-map-open'),
                            onTap: onTap,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.places,
    required this.language,
    required this.onSeeAll,
  });

  final List<HotelNearbyPlace> places;
  final String language;
  final VoidCallback onSeeAll;

  static const int previewCount = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = places.take(previewCount).toList(growable: false);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.near_me_outlined,
            title: l10n.hotelNearby,
            onSeeAll: places.length > previewCount ? onSeeAll : null,
            seeAllKey: const ValueKey('hotel-nearby-see-all'),
          ),
          const SizedBox(height: 12),
          for (final place in shown)
            _NearbyRow(place: place, language: language),
        ],
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.place, required this.language});

  final HotelNearbyPlace place;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = Text(
      place.name.forLanguage(language),
      maxLines: 2,
      style: TextStyle(color: AppColors.heading(context), fontSize: 15),
    );
    final distance = Text(
      l10n.hotelNearbyDistance(place.distanceMeters / 1000, place.minutes),
      style: TextStyle(color: AppColors.secondaryText(context), fontSize: 14),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            nearbyPlaceIcon(place.type),
            size: 18,
            color: AppColors.accent(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The leader dots are decoration. Once the name and the
                // distance need the width — a long localized name, or a large
                // font scale — the row gives the dots up, and then stacks,
                // rather than clipping either value.
                final needed =
                    _textWidth(context, name) + _textWidth(context, distance);
                if (needed > constraints.maxWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [name, distance],
                  );
                }
                return Row(
                  children: [
                    Flexible(child: name),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '················',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    distance,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Laid-out width of a single-line [Text], at the ambient scale.
  double _textWidth(BuildContext context, Text text) {
    final painter = TextPainter(
      text: TextSpan(text: text.data, style: text.style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}

/// The same card Explore Nature uses, reading hotel reviews.
class _CommentsCard extends StatelessWidget {
  const _CommentsCard({required this.reviews, required this.onTap});

  final Future<List<NatureReview>> reviews;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.forum_outlined,
            title: l10n.hotelRatingsAndComments,
            onSeeAll: onTap,
            seeAllKey: const ValueKey('hotel-comments-see-all'),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<NatureReview>>(
            future: reviews,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  l10n.reviewsLoadFailed,
                  style: TextStyle(color: AppColors.secondaryText(context)),
                );
              }
              final items = snapshot.data ?? const <NatureReview>[];
              if (items.isEmpty) {
                return Text(
                  l10n.noReviewsYet,
                  style: TextStyle(color: AppColors.secondaryText(context)),
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _CommentRow(review: items[index]),
                    if (index != items.length - 1) const Divider(height: 22),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // Same wording as Explore Nature, deliberately: one review action
          // across the app rather than a hotel-only synonym.
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('hotel-write-review'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
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
                            l10n.writeReviewPrompt,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading(context),
                            ),
                          ),
                          Text(
                            l10n.writeReviewHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.accent(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.review});

  final NatureReview review;

  @override
  Widget build(BuildContext context) {
    final createdAt = review.createdAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
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
                  _Stars(filled: review.rating),
                ],
              ),
              if (createdAt != null)
                Text(
                  MaterialLocalizations.of(context).formatMediumDate(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText(context),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                review.comment,
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  height: 20 / 14,
                  fontSize: 14,
                ),
              ),
              if (review.helpfulCount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: AppColors.accent(context),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${review.helpfulCount}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Half-star row, matching the review scale Explore Nature established.
class _Stars extends StatelessWidget {
  const _Stars({required this.filled});

  /// Matches the compact star size used on the Explore Nature review row.
  static const double size = 15;

  final double filled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).hotelReviewScore(filled * 2),
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // Stars read the same way in every language.
        textDirection: TextDirection.ltr,
        children: List.generate(5, (index) {
          final position = index + 1;
          final icon = filled >= position
              ? Icons.star_rounded
              : filled >= position - 0.5
              ? Icons.star_half_rounded
              : Icons.star_border_rounded;
          return Icon(icon, size: size, color: AppColors.accent(context));
        }),
      ),
    ),
  );
}

/// House rules, collapsed by default so they do not lengthen the page for
/// everyone who is not looking for them.
class _PoliciesCard extends StatelessWidget {
  const _PoliciesCard({
    required this.policies,
    required this.language,
    required this.expanded,
    required this.onToggle,
  });

  final HotelPolicies policies;
  final String language;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassPanel(
      borderRadius: 28,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              key: const ValueKey('hotel-policies-toggle'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _SectionHeader(
                  icon: Icons.gavel_outlined,
                  title: l10n.hotelPropertyPolicies,
                  trailing: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.accent(context),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _rows(context, l10n),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  /// One row per published rule. Nothing is defaulted: a rule the property has
  /// not stated simply does not appear.
  List<Widget> _rows(BuildContext context, AppLocalizations l10n) {
    final rows = <Widget>[];

    void add(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(_PolicyRow(label: label, value: value));
    }

    add(l10n.hotelPolicyCheckInFrom, policies.checkInFrom);
    add(l10n.hotelPolicyCheckOutUntil, policies.checkOutUntil);
    add(l10n.hotelPolicyChildren, policies.childPolicy?.forLanguage(language));
    add(l10n.hotelPolicyCribs, policies.cribPolicy?.forLanguage(language));
    add(
      l10n.hotelPolicyExtraBeds,
      policies.extraBedPolicy?.forLanguage(language),
    );
    if (policies.minimumAge != null) {
      add(
        l10n.hotelPolicyAgeRestriction,
        l10n.hotelPolicyMinimumAge(policies.minimumAge!),
      );
    }
    add(l10n.hotelPolicyPets, policies.petPolicy?.forLanguage(language));
    add(l10n.hotelPolicySmoking, policies.smokingPolicy?.forLanguage(language));
    if (policies.acceptedPaymentMethods.isNotEmpty) {
      add(l10n.hotelPolicyPayment, policies.acceptedPaymentMethods.join(' · '));
    }
    if (policies.specialRequestsSupported != null) {
      add(
        l10n.hotelPolicySpecialRequests,
        l10n.hotelPolicySpecialRequestsAllowed(
          policies.specialRequestsSupported!,
        ),
      );
    }
    add(
      l10n.hotelPolicyAccessibility,
      policies.accessibility?.forLanguage(language),
    );
    return rows;
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppColors.secondaryText(context),
            fontSize: 13,
            height: 19 / 13,
          ),
        ),
      ],
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 200,
    child: GlassPanel(
      borderRadius: 28,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.all(22),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.accent(context)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.heading(context), fontSize: 15),
        ),
        const SizedBox(height: 14),
        _PillButton(
          key: const ValueKey('hotel-detail-retry'),
          label: actionLabel,
          onTap: onAction,
        ),
      ],
    ),
  );
}

/// Shared chrome for this page's sheets: a glass panel that grows to its
/// content and scrolls once it would pass roughly five-sixths of the screen.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: GlassPanel(
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading(context),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: l10n.close,
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.heading(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FacilitiesSheet extends StatelessWidget {
  const _FacilitiesSheet({required this.detail, required this.language});

  final HotelDetail detail;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grouped = detail.facilitiesByCategory;
    return _SheetShell(
      title: l10n.hotelAllFacilities,
      child: grouped.isEmpty
          ? Text(
              l10n.hotelNoFacilities,
              style: TextStyle(color: AppColors.secondaryText(context)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text(
                      hotelFacilityCategoryLabel(l10n, entry.key),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent(context),
                      ),
                    ),
                  ),
                  for (final facility in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FacilityRow(
                        facility: facility,
                        language: language,
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _NearbySheet extends StatelessWidget {
  const _NearbySheet({required this.detail, required this.language});

  final HotelDetail detail;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SheetShell(
      title: l10n.hotelNearbyAll,
      child: detail.nearbyPlaces.isEmpty
          ? Text(
              l10n.hotelNearbyEmpty,
              style: TextStyle(color: AppColors.secondaryText(context)),
            )
          : Column(
              children: [
                for (final place in detail.nearbyPlaces)
                  _NearbyRow(place: place, language: language),
              ],
            ),
    );
  }
}

/// Edits the stay this page is showing: dates, rooms and occupancy.
///
/// Nothing here is applied until Apply is pressed, so a half-made change never
/// re-queries availability. The counters cannot be driven into an invalid
/// state — check-out is pushed past check-in, adults never falls below one,
/// and the guest total is capped only where the property publishes a limit.
class _ChangeStayEditor extends StatefulWidget {
  const _ChangeStayEditor({
    required this.criteria,
    required this.onClose,
    required this.onApply,
    required this.maxOccupancyPerRoom,
  });

  final HotelSearchCriteria criteria;
  final int? maxOccupancyPerRoom;
  final VoidCallback onClose;
  final ValueChanged<HotelSearchCriteria> onApply;

  @override
  State<_ChangeStayEditor> createState() => _ChangeStayEditorState();
}

class _ChangeStayEditorState extends State<_ChangeStayEditor> {
  late HotelSearchCriteria _draft = widget.criteria;

  int? get _guestCeiling {
    final perRoom = widget.maxOccupancyPerRoom;
    return perRoom == null ? null : perRoom * _draft.rooms;
  }

  int? _adultCeiling() {
    final ceiling = _guestCeiling;
    if (ceiling == null) return null;
    final room = ceiling - _draft.children;
    return room < 1 ? 1 : room;
  }

  int? _childCeiling() {
    final ceiling = _guestCeiling;
    if (ceiling == null) return null;
    final room = ceiling - _draft.adults;
    return room < 0 ? 0 : room;
  }

  Future<void> _pickDate({required bool checkIn}) async {
    final l10n = AppLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final first = checkIn ? today : _draft.checkIn.add(const Duration(days: 1));
    final initial = checkIn ? _draft.checkIn : _draft.checkOut;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
      helpText: checkIn ? l10n.hotelCheckIn : l10n.hotelCheckOut,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (checkIn) {
        // Check-out must stay after check-in — enforced by moving it, so the
        // user is never left holding an invalid range to fix themselves.
        final checkOut = !_draft.checkOut.isAfter(selected)
            ? selected.add(const Duration(days: 1))
            : _draft.checkOut;
        _draft = _draft.copyWith(checkIn: selected, checkOut: checkOut);
      } else {
        _draft = _draft.copyWith(checkOut: selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = MaterialLocalizations.of(context);
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.hotelUpdateStay,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('hotel-change-close'),
                onPressed: widget.onClose,
                tooltip: l10n.close,
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.heading(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassPanel(
            key: const ValueKey('hotel-change-date-panel'),
            borderRadius: 26,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _SheetDateRow(
                  label: l10n.hotelCheckIn,
                  value: formatter.formatMediumDate(_draft.checkIn),
                  controlKey: 'sheet-check-in',
                  onTap: () => _pickDate(checkIn: true),
                ),
                const SizedBox(height: 12),
                _SheetDateRow(
                  label: l10n.hotelCheckOut,
                  value: formatter.formatMediumDate(_draft.checkOut),
                  controlKey: 'sheet-check-out',
                  onTap: () => _pickDate(checkIn: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            key: const ValueKey('hotel-change-guests-panel'),
            borderRadius: 26,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                HotelCounterRow(
                  icon: Icons.person_outline,
                  label: l10n.hotelAdult,
                  value: _draft.adults,
                  minimum: 1,
                  maximum: _adultCeiling(),
                  controlKey: 'sheet-adult',
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(adults: value)),
                ),
                HotelCounterRow(
                  icon: Icons.child_care,
                  label: l10n.hotelChild,
                  value: _draft.children,
                  minimum: 0,
                  maximum: _childCeiling(),
                  controlKey: 'sheet-child',
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(children: value)),
                ),
                HotelCounterRow(
                  icon: Icons.meeting_room_outlined,
                  label: l10n.hotelRoom,
                  value: _draft.rooms,
                  minimum: 1,
                  controlKey: 'sheet-room',
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(rooms: value)),
                ),
                HotelCounterRow(
                  icon: Icons.bed_outlined,
                  label: l10n.hotelBed,
                  value: _draft.beds,
                  minimum: 1,
                  controlKey: 'sheet-bed',
                  last: true,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(beds: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            key: const ValueKey('hotel-change-apply'),
            label: l10n.hotelUpdateStayApply,
            onTap: () => widget.onApply(_draft),
          ),
        ],
      ),
    );
  }
}

class _SheetDateRow extends StatelessWidget {
  const _SheetDateRow({
    required this.label,
    required this.value,
    required this.controlKey,
    required this.onTap,
  });

  final String label;
  final String value;
  final String controlKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label $value',
    child: ExcludeSemantics(
      child: GlassPanel(
        depth: GlassDepth.top,
        borderRadius: 22,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey(controlKey),
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
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
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                          ),
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
        ),
      ),
    ),
  );
}
