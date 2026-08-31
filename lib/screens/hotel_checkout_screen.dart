import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/booking.dart';
import '../models/traveler_details.dart';
import '../services/bookings_service.dart';
import '../services/hotel_booking_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/hotel_parts.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'hotel_booking_confirmation_screen.dart';
import 'hotel_assets.dart';

const Key hotelCheckoutConfirmKey = ValueKey('hotel-checkout-confirm');
const Key hotelCheckoutConsentKey = ValueKey('hotel-checkout-consent');
Key hotelPaymentMethodKey(HotelPaymentMethod method) =>
    ValueKey('hotel-payment-${method.name}');

enum HotelPaymentMethod { stripe, fib }

class HotelCheckoutScreen extends StatefulWidget {
  const HotelCheckoutScreen({
    super.key,
    required this.selection,
    required this.hold,
    required this.bookingService,
    this.userProfileService,
  });

  final HotelRoomSelection selection;
  final MockHotelHold hold;
  final HotelBookingService bookingService;
  final UserProfileService? userProfileService;

  @override
  State<HotelCheckoutScreen> createState() => _HotelCheckoutScreenState();
}

class _HotelCheckoutScreenState extends State<HotelCheckoutScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _requests = TextEditingController();
  HotelPaymentMethod _method = HotelPaymentMethod.stripe;
  bool _agreed = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final profile = await (widget.userProfileService ?? UserProfileService())
        .fetchProfile();
    if (!mounted || profile == null) return;
    _name.text = profile.name;
    _email.text = profile.email ?? '';
    _phone.text = profile.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _requests.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_processing) return;
    final l10n = AppLocalizations.of(context);
    final contact = BookingContact(
      fullName: _name.text,
      email: _email.text,
      phone: _phone.text,
    );
    if (!contact.isComplete) {
      _snack(l10n.hotelGuestRequired);
      return;
    }
    if (!_agreed) {
      _snack(l10n.hotelConsentRequired);
      return;
    }

    setState(() => _processing = true);
    final refreshed = await widget.bookingService.revalidate(widget.selection);
    if (!mounted) return;
    if (refreshed == null || DateTime.now().isAfter(widget.hold.expiresAt)) {
      setState(() => _processing = false);
      _snack(l10n.hotelRateUnavailable);
      return;
    }

    final now = DateTime.now();
    final language = Localizations.localeOf(context).languageCode;
    final booking = Booking(
      id: 'mock-hotel-${now.microsecondsSinceEpoch}',
      userId: 'preview-user',
      type: BookingType.hotel,
      status: BookingStatus.pending,
      bookingReference: 'MOCK-HTL-${now.millisecondsSinceEpoch % 10000000}',
      startAt: widget.selection.criteria.checkIn,
      endAt: widget.selection.criteria.checkOut,
      referenceId: widget.selection.hotel.id,
      totalPrice: refreshed.totalPrice,
      currency: refreshed.currencyCode,
      cancellable: false,
      display: BookingDisplay(
        titles: {
          'en': widget.selection.hotel.name.en,
          'ku': widget.selection.hotel.name.ku,
          'ar': widget.selection.hotel.name.ar,
        },
        locationLabels: {
          'en': widget.selection.hotel.city.en,
          'ku': widget.selection.hotel.city.ku,
          'ar': widget.selection.hotel.city.ar,
        },
        imageAsset: widget.selection.hotel.imageAsset,
        guestCount:
            widget.selection.criteria.adults + widget.selection.criteria.children,
        roomName: widget.selection.room.name.forLanguage(language),
      ),
    );
    BookingsService.addSessionPreviewBooking(booking);
    if (!mounted) return;
    setState(() => _processing = false);
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/hotel/confirmation'),
        builder: (_) => HotelBookingConfirmationScreen(
          booking: booking,
          paymentMethod: _method,
        ),
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: hotelBackgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 112),
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 12),
              _TitleCard(title: l10n.hotelCompleteBooking),
              const SizedBox(height: 12),
              _Notice(text: l10n.hotelMockPaymentNotice),
              const SizedBox(height: 12),
              _summary(l10n),
              const SizedBox(height: 12),
              _guestCard(l10n),
              const SizedBox(height: 12),
              _paymentCard(l10n),
              const SizedBox(height: 12),
              _priceCard(l10n),
              const SizedBox(height: 12),
              _policyCard(l10n),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: PrimaryButton(
          key: hotelCheckoutConfirmKey,
          label: _processing ? l10n.hotelRechecking : l10n.hotelConfirmMockBooking,
          onTap: _processing ? null : _confirm,
        ),
      ),
    );
  }

  Widget _summary(AppLocalizations l10n) {
    final selection = widget.selection;
    final language = Localizations.localeOf(context).languageCode;
    final dates = MaterialLocalizations.of(context);
    return _Section(
      title: l10n.bookingSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selection.hotel.name.forLanguage(language),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(selection.room.name.forLanguage(language)),
          Text(
            '${dates.formatMediumDate(selection.criteria.checkIn)} — '
            '${dates.formatMediumDate(selection.criteria.checkOut)}',
          ),
          Text(l10n.hotelPriceForNights(selection.criteria.nights)),
        ],
      ),
    );
  }

  Widget _guestCard(AppLocalizations l10n) => _Section(
    title: l10n.hotelGuestDetails,
    child: Column(
      children: [
        AppRecessedGlassField(
          controller: _name,
          hint: l10n.fullName,
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 10),
        AppRecessedGlassField(
          controller: _email,
          hint: l10n.emailAddress,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        AppRecessedGlassField(
          controller: _phone,
          hint: l10n.phoneNumber,
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
        AppRecessedGlassField(
          controller: _requests,
          hint: l10n.hotelSpecialRequestsHint,
          prefixIcon: Icons.chat_bubble_outline,
        ),
      ],
    ),
  );

  Widget _paymentCard(AppLocalizations l10n) => _Section(
    title: l10n.paymentMethodLabel,
    child: Column(
      children: [
        _PaymentOption(
          key: hotelPaymentMethodKey(HotelPaymentMethod.stripe),
          icon: Icons.credit_card_outlined,
          label: l10n.hotelStripePreview,
          selected: _method == HotelPaymentMethod.stripe,
          onTap: () => setState(() => _method = HotelPaymentMethod.stripe),
        ),
        const SizedBox(height: 10),
        _PaymentOption(
          key: hotelPaymentMethodKey(HotelPaymentMethod.fib),
          icon: Icons.account_balance_outlined,
          label: l10n.hotelFibPreview,
          selected: _method == HotelPaymentMethod.fib,
          onTap: () => setState(() => _method = HotelPaymentMethod.fib),
        ),
      ],
    ),
  );

  Widget _priceCard(AppLocalizations l10n) {
    final offer = widget.selection.offer;
    return _Section(
      title: l10n.priceBreakdown,
      child: Column(
        children: [
          _PriceRow(
            label: l10n.hotelRoomSubtotal,
            value: _money(widget.selection.subtotal, offer.currencyCode),
          ),
          _PriceRow(
            label: l10n.hotelTaxesAndFees,
            value: _money(offer.taxes + offer.fees, offer.currencyCode),
          ),
          const Divider(),
          _PriceRow(
            label: l10n.totalLabel,
            value: _money(offer.totalPrice, offer.currencyCode),
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _policyCard(AppLocalizations l10n) => _Section(
    title: l10n.hotelPropertyPolicies,
    child: Column(
      children: [
        _PolicyLine(
          icon: Icons.event_available_outlined,
          text: hotelCancellationLabel(
            l10n,
            widget.selection.offer.cancellationType,
          ),
        ),
        _PolicyLine(
          icon: Icons.payments_outlined,
          text: hotelPaymentTimingLabel(
            l10n,
            widget.selection.offer.paymentTiming,
          ),
        ),
        CheckboxListTile(
          key: hotelCheckoutConsentKey,
          contentPadding: EdgeInsets.zero,
          value: _agreed,
          onChanged: (value) => setState(() => _agreed = value ?? false),
          title: Text(l10n.hotelBookingConsent),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    ),
  );
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Icon(Icons.fact_check_outlined, color: AppColors.accent(context), size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.heading(context),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => GlassPanel(
    depth: GlassDepth.top,
    borderRadius: 16,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(Icons.science_outlined, color: AppColors.accent(context)),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: GlassPanel(
      depth: GlassDepth.middle,
      selected: selected,
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
        ],
      ),
    ),
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500),
        ),
      ],
    ),
  );
}

class _PolicyLine extends StatelessWidget {
  const _PolicyLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
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
