import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/booking.dart';
import '../services/bookings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/sign_in_required.dart';
import '../widgets/ticket_card.dart';
import 'map_screen.dart';
import 'policy_screen.dart';

/// Phase 8 — My Bookings, opened from the side drawer's **My Bookings** row.
///
/// Built from the `my bookings.jpg` reference. Two independent filter axes sit
/// above the list: a **time segment** (Upcoming / Past / Cancelled) and the
/// reference's **type chips** (All / Hotels / Cars / Flights / Tours). The time
/// axis is not in the reference — it was added deliberately, because both
/// Booking.com and Agoda make time the primary split and without it a trip from
/// two years ago sits next to next week's.
///
/// Everything is filtered in Dart from one Firestore read — see `DATA_MODEL.md`
/// for why that is cheaper here than a composite index per combination.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({
    super.key,
    this.isGuest = false,
    this.service,
    this.showBottomNav = false,
  });

  /// True when the screen was reached from the home bar's **My Bookings**
  /// item. The bar is then kept on screen, in the same place and with the same
  /// geometry as on Home, so tapping it doesn't make the bar disappear out from
  /// under the finger. False from the drawer, which has no bar to preserve.
  final bool showBottomNav;

  /// A guest has no bookings by definition — the rules require an auth uid —
  /// so the screen shows a sign-in prompt rather than an empty list. Same
  /// precedent as favorites and the drawer's Currency row.
  final bool isGuest;

  final BookingsService? service;

  /// My Bookings is a drawer destination, so it keeps the shared drawer
  /// photograph — one photo per screen *category*, per the design files.
  static const String backgroundAsset = PolicyScreen.backgroundAsset;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late final BookingsService _service = widget.service ?? BookingsService();

  late Future<List<Booking>> _future = _load();

  BookingTimeFilter _segment = BookingTimeFilter.upcoming;
  BookingTypeFilter _typeFilter = BookingTypeFilter.all;

  Future<List<Booking>> _load() =>
      widget.isGuest ? Future.value(const []) : _service.fetchMyBookings();

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  /// Mirrors Home's own handling, so the bar behaves identically from here.
  ///
  /// Home is a pop rather than a push: the Home screen is still underneath, and
  /// pushing a second copy would leave two dashboards on the stack.
  Future<void> _onNavSelected(HomeNavTab tab) async {
    switch (tab) {
      case HomeNavTab.trips:
        return; // Already here.
      case HomeNavTab.home:
        Navigator.of(context).maybePop();
      case HomeNavTab.map:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen()));
      case HomeNavTab.saved:
        // Phase 8 of ROADMAP.md — not built yet, and not built ahead here.
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.comingSoon)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // With the bar visible the list has to clear it, exactly as Home's does.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom +
        (widget.showBottomNav ? HomeBottomNav.barHeight + 12 : 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The glass bar floats over the photograph rather than sitting in a
      // solid-coloured slot.
      extendBody: true,
      body: PageBackground(
        imageAsset: MyBookingsScreen.backgroundAsset,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          // The shared navigation convention keeps back controls on
                          // the physical left in every language.
                          alignment: Alignment.centerLeft,
                          child: GlassBackButton(
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.myBookingsTitle,
                          style: TextStyle(
                            fontSize: 32,
                            height: 40 / 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 32,
                            color: AppColors.heading(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SegmentControl(
                          value: _segment,
                          onChanged: (value) =>
                              setState(() => _segment = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TypeChipRow(
                    value: _typeFilter,
                    onChanged: (value) => setState(() => _typeFilter = value),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: widget.isGuest
                        // Shared with Billing & Payments and any future screen
                        // that needs an auth uid — one gate, one wording.
                        ? SignInRequired(
                            title: l10n.bookingsSignInTitle,
                            body: l10n.bookingsSignInBody,
                          )
                        : _BookingsList(
                            future: _future,
                            segment: _segment,
                            typeFilter: _typeFilter,
                            bottomInset: bottomInset,
                            onRetry: _refresh,
                          ),
                  ),
                ],
              ),
            ),
            if (widget.showBottomNav)
              HomeBottomNav.floating(
                context: context,
                current: HomeNavTab.trips,
                onSelect: _onNavSelected,
              ),
          ],
        ),
      ),
    );
  }
}

// --- List, with its loading / error / empty states ---------------------------

class _BookingsList extends StatelessWidget {
  const _BookingsList({
    required this.future,
    required this.segment,
    required this.typeFilter,
    required this.bottomInset,
    required this.onRetry,
  });

  final Future<List<Booking>> future;
  final BookingTimeFilter segment;
  final BookingTypeFilter typeFilter;
  final double bottomInset;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<List<Booking>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.cloud_off_rounded,
            title: l10n.bookingsLoadFailed,
            body: '${snapshot.error}',
            actionLabel: l10n.tryAgain,
            onAction: onRetry,
          );
        }

        final all = snapshot.data ?? const <Booking>[];
        final now = DateTime.now();

        // Time first, then type — so "no upcoming bookings" is reported even
        // when a type chip is active, which is the more useful message.
        final inSegment = all
            .where((booking) => booking.segment(now) == segment)
            .toList();
        final visible = inSegment.where(typeFilter.matches).toList();

        if (visible.isEmpty) {
          final (title, body) = switch ((all.isEmpty, inSegment.isEmpty)) {
            (true, _) => (l10n.bookingsEmptyTitle, l10n.bookingsEmptyBody),
            (false, true) => (l10n.bookingsEmptySegment(segment), ''),
            _ => (
              l10n.bookingsEmptySegment(segment),
              l10n.bookingsEmptyFiltered,
            ),
          };
          return RefreshIndicator(
            onRefresh: onRetry,
            child: _MessageState(
              icon: Icons.luggage_outlined,
              title: title,
              body: body,
              scrollable: true,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRetry,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 28),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 18),
            itemBuilder: (context, index) =>
                BookingCard(booking: visible[index]),
          ),
        );
      },
    );
  }
}

/// Shared empty / error presentation, so the three states cannot drift apart.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.scrollable = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  /// A `RefreshIndicator` needs a scrollable child, so the empty states are
  /// wrapped in one — otherwise pull-to-refresh silently stops working exactly
  /// when the user most wants it.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppColors.accent(context)),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.w700,
              color: AppColors.heading(context),
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.onPhotoSecondary(context),
              ),
            ),
          ],
          if (actionLabel case final label?) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: PrimaryButton(label: label, onTap: () => onAction?.call()),
            ),
          ],
        ],
      ),
    );

    if (!scrollable) return Center(child: content);

    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        ],
      ),
    );
  }
}

// --- Filters -----------------------------------------------------------------

/// Upcoming / Past / Cancelled.
///
/// Drawn as a glass segmented control rather than a second row of pills, so it
/// is visually distinct from the type chips underneath — two identical chip
/// rows stacked would read as one wrapped row of eight.
class _SegmentControl extends StatelessWidget {
  const _SegmentControl({required this.value, required this.onChanged});

  final BookingTimeFilter value;
  final ValueChanged<BookingTimeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassPanel(
      borderRadius: 999,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final segment in BookingTimeFilter.values)
            Expanded(
              child: Semantics(
                selected: segment == value,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(segment),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    // 40dp visual inside the 48dp row height below.
                    constraints: const BoxConstraints(minHeight: 40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: segment == value ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.bookingTimeFilterLabel(segment),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: segment == value
                                ? (isDark
                                      ? AppColors.darkOnPrimary
                                      : Colors.white)
                                : AppColors.heading(context),
                          ),
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

/// All / Hotels / Cars / Flights / Tours.
///
/// Colours follow the **Selection & Multi-Select States** rule in both design
/// files, not the reference screenshot: unselected is mint (light) / deep
/// emerald (dark), never white. The screenshot draws white unselected chips,
/// which `DESIGN_light.md` explicitly calls a bug — flagged and resolved in
/// favour of the design file.
///
/// The row scrolls horizontally because five labelled chips do not fit on a
/// 320dp phone, let alone at a raised system font size.
class _TypeChipRow extends StatelessWidget {
  const _TypeChipRow({required this.value, required this.onChanged});

  final BookingTypeFilter value;
  final ValueChanged<BookingTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: BookingTypeFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = BookingTypeFilter.values[index];
          return _TypeChip(
            filter: filter,
            selected: filter == value,
            onTap: () => onChanged(filter),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final BookingTypeFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = AppColors.selectionAccent(context);

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        // 38dp visual inside a 48dp tap target, per the shape rules.
        child: Center(
          child: GlassPanel(
            borderRadius: 999,
            depth: GlassDepth.top,
            selected: selected,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 38,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(filter), size: 18, color: content),
                  const SizedBox(width: 7),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.bookingTypeFilterLabel(filter),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: content,
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

  /// Reuses the Home screen's own journey-card icons, as requested, so a
  /// product means the same glyph everywhere in the app.
  static IconData _icon(BookingTypeFilter filter) => switch (filter) {
    BookingTypeFilter.all => Icons.grid_view_rounded,
    BookingTypeFilter.hotels => Icons.king_bed_outlined,
    BookingTypeFilter.cars => Icons.directions_car_outlined,
    BookingTypeFilter.flights => Icons.flight_takeoff_outlined,
    BookingTypeFilter.tours => Icons.festival_outlined,
  };
}

// --- Cards -------------------------------------------------------------------

/// Dispatches to the right ticket layout for the booking's type.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});

  final Booking booking;

  static IconData iconFor(BookingType type) => switch (type) {
    BookingType.hotel => Icons.king_bed_outlined,
    BookingType.car => Icons.directions_car_outlined,
    BookingType.flight => Icons.flight_takeoff_outlined,
    BookingType.tour => Icons.festival_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return booking.type == BookingType.flight
        ? _FlightTicket(booking: booking)
        : _PhotoTicket(booking: booking);
  }
}

/// Hotel, car and tour: a photograph on the **leading** edge with the
/// information panel overlapping it along a wavy seam.
///
/// Leading rather than "left", so the whole card mirrors in Kurdish and Arabic
/// instead of reading backwards — the same rule as Explore Nature's thumbnail.
class _PhotoTicket extends StatelessWidget {
  const _PhotoTicket({required this.booking});

  final Booking booking;

  static const double _photoWidth = 116;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = l10n.locale.languageCode;
    final direction = Directionality.of(context);

    return TicketCard(
      notchFraction: 0.62,
      child: IntrinsicHeight(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _photoWidth,
                  child: _BookingPhoto(display: booking.display),
                ),
                Expanded(
                  child: ClipPath(
                    clipper: WavySeamClipper(textDirection: direction),
                    child: ColoredBox(
                      color: TicketCard.surface(context),
                      child: Padding(
                        // Extra leading padding clears the wave's crest.
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          22,
                          14,
                          14,
                          14,
                        ),
                        child: _TicketBody(
                          booking: booking,
                          language: language,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: _TypeBadge(type: booking.type),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title / location / details / footer stack shared by the photo tickets.
class _TicketBody extends StatelessWidget {
  const _TicketBody({required this.booking, required this.language});

  final Booking booking;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = booking.display;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _StatusPillFor(booking: booking),
        ),
        const SizedBox(height: 6),
        Text(
          display.title(language),
          style: TextStyle(
            fontSize: 19,
            height: 26 / 19,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 4),
        _IconLine(
          icon: Icons.location_on_outlined,
          text: display.locationLabel(language),
        ),
        const SizedBox(height: 12),
        const TicketPerforation(),
        const SizedBox(height: 12),
        _DetailWrap(details: _details(context, l10n)),
        const SizedBox(height: 12),
        const TicketPerforation(),
        const SizedBox(height: 12),
        _TicketFooter(booking: booking),
      ],
    );
  }

  List<_Detail> _details(BuildContext context, AppLocalizations l10n) {
    final display = booking.display;
    final guests = display.guestCount;

    return switch (booking.type) {
      BookingType.hotel => [
        _Detail(
          icon: Icons.calendar_today_outlined,
          label: l10n.bookingCheckIn,
          value: l10n.bookingDate(booking.startAt),
        ),
        if (booking.endAt case final end?)
          _Detail(
            icon: Icons.calendar_today_outlined,
            label: l10n.bookingCheckOut,
            value: l10n.bookingDate(end),
          ),
        if (guests != null)
          _Detail(
            icon: Icons.person_outline_rounded,
            label: l10n.bookingGuestLabel(booking.type),
            value: l10n.adultsCount(guests),
          ),
      ],
      BookingType.car => [
        _Detail(
          icon: Icons.calendar_today_outlined,
          label: l10n.bookingPickup,
          value: l10n.bookingDate(booking.startAt),
          secondary: l10n.bookingTime(booking.startAt),
        ),
        if (booking.endAt case final end?)
          _Detail(
            icon: Icons.calendar_today_outlined,
            label: l10n.bookingDropoff,
            value: l10n.bookingDate(end),
            secondary: l10n.bookingTime(end),
          ),
        if (guests != null)
          _Detail(
            icon: Icons.person_outline_rounded,
            label: l10n.bookingGuestLabel(booking.type),
            value: l10n.adultsCount(guests),
          ),
      ],
      BookingType.tour => [
        _Detail(
          icon: Icons.calendar_today_outlined,
          label: l10n.bookingDate(booking.startAt),
          value: l10n.bookingTime(booking.startAt),
        ),
        if (display.durationHours case final hours?)
          _Detail(
            icon: Icons.schedule_outlined,
            label: l10n.bookingDuration,
            value: l10n.bookingHours(hours),
          ),
        if (guests != null)
          _Detail(
            icon: Icons.person_outline_rounded,
            label: l10n.bookingGuestLabel(booking.type),
            value: l10n.adultsCount(guests),
          ),
      ],
      // Flights use their own layout entirely.
      BookingType.flight => const [],
    };
  }
}

/// The boarding-pass layout: route across the top, details beneath, and a
/// perforated stub carrying the barcode.
class _FlightTicket extends StatelessWidget {
  const _FlightTicket({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = l10n.locale.languageCode;
    final display = booking.display;

    return TicketCard(
      notchFraction: 0.58,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: booking.type),
                const Spacer(),
                _StatusPillFor(booking: booking),
              ],
            ),
            const SizedBox(height: 10),
            // The airline. The reference draws only the route, but a boarding
            // pass without a carrier is missing the first thing a traveller
            // looks for — and both Booking.com and Agoda show it.
            Text(
              display.title(language),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FlightRoute(display: display, language: language),
                        const SizedBox(height: 12),
                        const TicketPerforation(),
                        const SizedBox(height: 12),
                        _DetailWrap(details: _details(l10n)),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: TicketPerforation(axis: Axis.vertical),
                  ),
                  _BarcodeStub(reference: booking.bookingReference),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TicketPerforation(),
            const SizedBox(height: 12),
            _TicketFooter(booking: booking),
          ],
        ),
      ),
    );
  }

  List<_Detail> _details(AppLocalizations l10n) {
    final display = booking.display;
    return [
      _Detail(
        icon: Icons.calendar_today_outlined,
        label: l10n.bookingDate(booking.startAt),
        value: l10n.bookingTime(booking.startAt),
      ),
      // Absent before check-in — hidden rather than faked, the same rule as
      // Explore Nature's Distance row.
      if (display.seat case final seat?)
        _Detail(
          icon: Icons.airline_seat_recline_normal_outlined,
          label: l10n.bookingSeat,
          value: seat,
          alwaysLtr: true,
        ),
      if (display.guestCount case final count?)
        _Detail(
          icon: Icons.person_outline_rounded,
          label: l10n.bookingGuestLabel(BookingType.flight),
          value: l10n.adultsCount(count),
        ),
    ];
  }
}

/// `EBL ---✈--- IST`, with the city names beneath.
///
/// The whole route is forced **left-to-right in every language**: a route is a
/// journey with a direction, not a sentence. Same rule as the OTP box, the
/// carousel dots and the rating digits.
class _FlightRoute extends StatelessWidget {
  const _FlightRoute({required this.display, required this.language});

  final BookingDisplay display;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accent(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible, not fixed: two airport codes plus two city names do not
          // fit beside the tear line on a 320dp phone at a raised font size.
          Flexible(
            child: _RouteEnd(
              code: display.fromCode ?? '',
              city: display.fromCity(language),
              alignment: CrossAxisAlignment.start,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(child: TicketPerforation()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.flight_takeoff_outlined,
                          size: 18,
                          color: accent,
                        ),
                      ),
                      const Expanded(child: TicketPerforation()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (display.durationMinutes case final minutes?)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.flightDuration(minutes),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Flexible(
            child: _RouteEnd(
              code: display.toCode ?? '',
              city: display.toCity(language),
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteEnd extends StatelessWidget {
  const _RouteEnd({
    required this.code,
    required this.city,
    required this.alignment,
  });

  final String code;
  final String city;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            code,
            maxLines: 1,
            style: TextStyle(
              fontSize: 26,
              height: 32 / 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: AppColors.heading(context),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText(context),
          ),
        ),
      ],
    );
  }
}

/// The scannable stub. A real Code128 of the booking reference, because that is
/// the entire point of putting a barcode on a boarding pass — a decorative one
/// would be misleading.
class _BarcodeStub extends StatelessWidget {
  const _BarcodeStub({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      child: RotatedBox(
        quarterTurns: 3,
        child: BarcodeWidget(
          barcode: Barcode.code128(),
          data: reference,
          drawText: false,
          color: AppColors.heading(context),
          // The stub is part of the ticket surface, so it must not paint its
          // own white plate over the card fill.
          backgroundColor: Colors.transparent,
          errorBuilder: (context, error) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// --- Shared card parts -------------------------------------------------------

/// Circle icon + product label, e.g. a bed glyph and "HOTEL".
///
/// Drawn on an opaque pill because on the photo tickets it overlaps the
/// photograph, and a photograph's brightness cannot be predicted. The reference
/// puts dark text straight on the image; a pill guarantees the 4.5:1 minimum on
/// every photo instead of only on pale ones.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final BookingType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accent(context);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 12, 5),
      decoration: BoxDecoration(
        color: TicketCard.surface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1.5),
            ),
            child: Icon(BookingCard.iconFor(type), size: 15, color: accent),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l10n.bookingTypeLabel(type),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.heading(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the right pill for a booking: its cabin class if it has one (the
/// reference shows "ECONOMY" on the flight), otherwise its status.
class _StatusPillFor extends StatelessWidget {
  const _StatusPillFor({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final cabin = booking.display.cabinClass;
    if (cabin != null && booking.status == BookingStatus.confirmed) {
      return StatusPill(
        label: l10n.cabinClassLabel(cabin),
        tone: StatusTone.informational,
      );
    }

    final (tone, icon) = switch (booking.status) {
      BookingStatus.confirmed => (
        StatusTone.positive,
        Icons.check_circle_outline_rounded,
      ),
      BookingStatus.completed => (StatusTone.positive, Icons.done_all_rounded),
      BookingStatus.pending => (
        StatusTone.informational,
        Icons.schedule_rounded,
      ),
      BookingStatus.cancelled => (StatusTone.negative, Icons.cancel_outlined),
    };

    return StatusPill(
      label: l10n.bookingStatusLabel(booking.status),
      tone: tone,
      icon: icon,
    );
  }
}

/// "Booking ID / HTL-7845123" on the leading side, the action on the trailing.
class _TicketFooter extends StatelessWidget {
  const _TicketFooter({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.bookingId,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText(context),
                ),
              ),
              const SizedBox(height: 2),
              // A reference code is an identifier, not a sentence — it reads
              // left-to-right in every language.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  booking.bookingReference,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Flexible so the pill gives way before the row overflows on a narrow
        // phone; its own FittedBox then scales the label down.
        Flexible(child: _ActionPill(booking: booking)),
      ],
    );
  }
}

/// The card's primary action. Styled as a **chip**, matching the Home screen's
/// `_ArrowPill` precedent: an in-card pill action, not a `PrimaryButton`.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final content = isDark ? AppColors.darkOnPrimary : Colors.white;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.comingSoon))),
        // 40dp visual inside a 48dp tap target, matching the journey cards.
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              height: 40,
              constraints: const BoxConstraints(maxWidth: 168),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 6, 0),
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
                        l10n.bookingActionLabel(booking.type),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: content,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: content.withValues(alpha: 0.18),
                    ),
                    child: Icon(
                      // The arrow points the way the language reads, unlike
                      // the always-left back button.
                      isRtl
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_forward_rounded,
                      size: 15,
                      color: content,
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

/// One label/value pair in a card's detail strip.
class _Detail {
  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
    this.secondary,
    this.alwaysLtr = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// An optional third line, e.g. the time under a pick-up date.
  final String? secondary;

  /// Forces the value left-to-right — for codes like a seat number.
  final bool alwaysLtr;
}

/// Lays the detail pairs out in a `Wrap` rather than a fixed `Row` of
/// `Expanded`s: the number of pairs varies by product (and by whether optional
/// fields like Seat are present), and the labels change length in all three
/// languages. A fixed row overflows on a 320dp phone at a raised font size.
class _DetailWrap extends StatelessWidget {
  const _DetailWrap({required this.details});

  final List<_Detail> details;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 18,
      runSpacing: 12,
      children: [
        for (final detail in details)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconLine(icon: detail.icon, text: detail.label, small: true),
              const SizedBox(height: 3),
              Directionality(
                textDirection: detail.alwaysLtr
                    ? TextDirection.ltr
                    : Directionality.of(context),
                child: Text(
                  detail.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
              if (detail.secondary case final secondary?)
                Text(
                  secondary,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText(context),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Small icon followed by text, used for the location line and detail labels.
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.small = false});

  final IconData icon;
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = small
        ? AppColors.secondaryText(context)
        : AppColors.heading(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: small ? 13 : 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                fontSize: small ? 12 : 13,
                fontWeight: small ? FontWeight.w500 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The card thumbnail: a bundled asset in preview mode, a Storage URL live, and
/// a brand-coloured placeholder when neither loads.
class _BookingPhoto extends StatelessWidget {
  const _BookingPhoto({required this.display});

  final BookingDisplay display;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.accent(context).withValues(alpha: 0.18),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.accent(context).withValues(alpha: 0.6),
        ),
      ),
    );

    if (display.imageAsset case final asset?) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    if (display.imageUrl case final url?) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      );
    }

    return fallback;
  }
}
