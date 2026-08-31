import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/hotel.dart';
import '../models/hotel_detail.dart';
import '../services/hotel_booking_service.dart';
import '../services/hotel_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/hotel_parts.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'hotel_checkout_screen.dart';
import 'hotel_assets.dart';

const Key chooseRoomReserveKey = ValueKey('choose-room-reserve');
Key chooseRoomRateKey(String id) => ValueKey('choose-room-rate-$id');

enum ChooseRoomStatus {
  loading,
  loaded,
  empty,
  failed,
  rechecking,
  creatingHold,
}

class ChooseRoomScreen extends StatefulWidget {
  const ChooseRoomScreen({
    super.key,
    required this.hotel,
    required this.criteria,
    this.hotelService = const PreviewHotelService(),
    this.bookingService,
  });

  final Hotel hotel;
  final HotelSearchCriteria criteria;
  final HotelService hotelService;
  final HotelBookingService? bookingService;

  @override
  State<ChooseRoomScreen> createState() => _ChooseRoomScreenState();
}

class _ChooseRoomScreenState extends State<ChooseRoomScreen> {
  late final HotelBookingService _service =
      widget.bookingService ??
      PreviewHotelBookingService(hotelService: widget.hotelService);

  ChooseRoomStatus _status = ChooseRoomStatus.loading;
  HotelAvailability? _availability;
  HotelRoomSelection? _selection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = ChooseRoomStatus.loading);
    try {
      final result = await _service.fetchAvailability(
        widget.hotel,
        widget.criteria,
      );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _selection = null;
        _status = result.availableRooms.isEmpty
            ? ChooseRoomStatus.empty
            : ChooseRoomStatus.loaded;
      });
    } catch (_) {
      if (mounted) setState(() => _status = ChooseRoomStatus.failed);
    }
  }

  void _select(HotelRoomType room, HotelRoomOffer offer) {
    setState(() {
      _selection = _selection?.offer.id == offer.id
          ? null
          : HotelRoomSelection(
              hotel: widget.hotel,
              criteria: widget.criteria,
              room: room,
              offer: offer,
            );
    });
  }

  Future<void> _reserve() async {
    final selected = _selection;
    if (selected == null || _status != ChooseRoomStatus.loaded) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _status = ChooseRoomStatus.rechecking);
    final refreshed = await _service.revalidate(selected);
    if (!mounted) return;
    if (refreshed == null) {
      setState(() {
        _selection = null;
        _status = ChooseRoomStatus.loaded;
      });
      _snack(l10n.hotelRateUnavailable);
      return;
    }

    final current = HotelRoomSelection(
      hotel: selected.hotel,
      criteria: selected.criteria,
      room: selected.room,
      offer: refreshed,
    );
    setState(() => _status = ChooseRoomStatus.creatingHold);
    try {
      final hold = await _service.createHold(current);
      if (!mounted) return;
      setState(() => _status = ChooseRoomStatus.loaded);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/hotel/checkout'),
          builder: (_) => HotelCheckoutScreen(
            selection: current,
            hold: hold,
            bookingService: _service,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = ChooseRoomStatus.loaded);
      _snack(l10n.hotelRateUnavailable);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  bool get _busy =>
      _status == ChooseRoomStatus.rechecking ||
      _status == ChooseRoomStatus.creatingHold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Without this the reserve bar sits below the body and exposes the
      // app canvas as a pale band; extending the body keeps the page
      // background running behind the button.
      extendBody: true,
      body: PageBackground(
        imageAsset: hotelBackgroundAsset,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 112),
                sliver: SliverList.list(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: GlassBackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Header(title: l10n.hotelChooseRoom),
                    const SizedBox(height: 10),
                    _PreviewNotice(text: l10n.hotelMockNotice),
                    const SizedBox(height: 14),
                    _content(l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _status == ChooseRoomStatus.loaded || _busy
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: PrimaryButton(
                key: chooseRoomReserveKey,
                label: _busy ? l10n.hotelRechecking : l10n.hotelReserve,
                onTap: _selection == null || _busy ? null : _reserve,
              ),
            )
          : null,
    );
  }

  Widget _content(AppLocalizations l10n) => switch (_status) {
    ChooseRoomStatus.loading => const _LoadingRooms(),
    ChooseRoomStatus.failed => _StateCard(
      icon: Icons.cloud_off_outlined,
      message: l10n.hotelDetailLoadFailed,
      primaryLabel: l10n.tryAgain,
      onPrimary: _load,
    ),
    ChooseRoomStatus.empty => _StateCard(
      icon: Icons.event_busy_outlined,
      message: l10n.hotelNoRooms,
      primaryLabel: l10n.hotelChangeDates,
      onPrimary: () => Navigator.of(context).maybePop(),
      secondaryLabel: l10n.hotelBackToHotel,
      onSecondary: () => Navigator.of(context).maybePop(),
    ),
    _ => Column(
      children: [
        for (final room in _availability!.availableRooms) ...[
          _RoomCard(
            room: room,
            offers: _availability!.offersByRoom[room.id]!,
            selectedOfferId: _selection?.offer.id,
            nights: widget.criteria.nights,
            onSelect: (offer) => _select(room, offer),
            onDetails: () => _openRoomDetails(room),
          ),
          const SizedBox(height: 14),
        ],
      ],
    ),
  };

  void _openRoomDetails(HotelRoomType room) {
    final language = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassPanel(
            depth: GlassDepth.middle,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name.forLanguage(language),
                  style: TextStyle(
                    color: AppColors.heading(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (room.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    room.description!.forLanguage(language),
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                ],
                const SizedBox(height: 14),
                Text(l10n.hotelMaximumGuests(room.maxOccupancy)),
                if (room.sizeSqm != null)
                  Text('${room.sizeSqm!.toStringAsFixed(0)} m²'),
                const SizedBox(height: 10),
                for (final bed in room.beds)
                  Text(hotelBedConfigurationLabel(l10n, bed)),
                const SizedBox(height: 10),
                for (final facility in room.facilities)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(hotelFacilityIcon(facility.iconKey), size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(facility.name.forLanguage(language)),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        HotelCircleIcon(icon: Icons.king_bed_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.heading(context),
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => GlassPanel(
    depth: GlassDepth.top,
    borderRadius: 16,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Icon(Icons.science_outlined, color: AppColors.accent(context)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.offers,
    required this.selectedOfferId,
    required this.nights,
    required this.onSelect,
    required this.onDetails,
  });

  final HotelRoomType room;
  final List<HotelRoomOffer> offers;
  final String? selectedOfferId;
  final int nights;
  final ValueChanged<HotelRoomOffer> onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.asset(
                room.images.isEmpty ? hotelBackgroundAsset : room.images.first,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            room.name.forLanguage(language),
            style: TextStyle(
              color: AppColors.heading(context),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final bed in room.beds)
                _InfoChip(
                  icon: Icons.bed_outlined,
                  label: hotelBedConfigurationLabel(l10n, bed),
                ),
              if (room.sizeSqm != null)
                _InfoChip(
                  icon: Icons.square_foot_outlined,
                  label: '${room.sizeSqm!.toStringAsFixed(0)} m²',
                ),
              for (final facility in room.facilities.take(4))
                _InfoChip(
                  icon: hotelFacilityIcon(facility.iconKey),
                  label: facility.name.forLanguage(language),
                ),
            ],
          ),
          TextButton(
            onPressed: onDetails,
            child: Text(l10n.hotelSeeRoomDetails),
          ),
          Builder(
            builder: (context) {
              // The two rates sit side by side, as the reference shows. A
              // raised system font size — or an unexpected third rate — falls
              // back to a single column, where half a phone width can no
              // longer hold a rate's wording.
              final stack =
                  offers.length != 2 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final cards = [
                for (final offer in offers)
                  _RateCard(
                    offer: offer,
                    nights: nights,
                    selected: offer.id == selectedOfferId,
                    onTap: () => onSelect(offer),
                  ),
              ];
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      if (index > 0) const SizedBox(height: 12),
                      cards[index],
                    ],
                  ],
                );
              }
              // IntrinsicHeight with a stretched cross axis: the rate whose
              // wording wraps to an extra line sets the height, and the other
              // card matches it instead of ending short.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(l10n.hotelRoomsLeft(offers.first.availableQuantity)),
          ),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.offer,
    required this.nights,
    required this.selected,
    required this.onTap,
  });

  final HotelRoomOffer offer;
  final int nights;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        key: chooseRoomRateKey(offer.id),
        onTap: onTap,
        child: GlassPanel(
          depth: GlassDepth.middle,
          selected: selected,
          borderRadius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      offer.name?.forLanguage(language) ?? l10n.hotelReserve,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColors.selectionAccent(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                offer.mealPlan?.forLanguage(language) ??
                    hotelBreakfastLabel(l10n, offer.breakfast),
              ),
              const SizedBox(height: 5),
              Text(hotelCancellationLabel(l10n, offer.cancellationType)),
              const SizedBox(height: 5),
              Text(hotelPaymentTimingLabel(l10n, offer.paymentTiming)),
              const SizedBox(height: 12),
              Text(l10n.hotelPriceForNights(nights)),
              const SizedBox(height: 3),
              Text(
                _money(offer.totalPrice, offer.currencyCode),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.hotelTaxesExcluded,
                style: TextStyle(color: AppColors.secondaryText(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => GlassPanel(
    depth: GlassDepth.top,
    borderRadius: 18,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    // Flexible, not fixed: at a raised system font size a feature label is
    // wider than the chip row it sits in, and would otherwise overflow.
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

class _LoadingRooms extends StatelessWidget {
  const _LoadingRooms();
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      2,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: GlassPanel(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });
  final IconData icon;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Icon(icon, size: 52, color: AppColors.accent(context)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        PrimaryButton(label: primaryLabel, onTap: onPrimary),
        if (secondaryLabel != null)
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
      ],
    ),
  );
}

String _money(num amount, String currency) {
  final value = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return currency == 'USD' ? '\$$value' : '$value $currency';
}
