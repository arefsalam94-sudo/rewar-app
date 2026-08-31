import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/saved_payment_method.dart';
import '../models/tour.dart';
import '../models/traveler_details.dart';
import '../theme/app_colors.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/booking_step_indicator.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'booking_review_screen.dart';
import 'explore_tours_screen.dart' show formatMoney;
import 'tour_assets.dart';

@visibleForTesting
const Key paymentCardNumberKey = ValueKey('payment-card-number');
@visibleForTesting
const Key paymentExpiryKey = ValueKey('payment-expiry');
@visibleForTesting
const Key paymentCvvKey = ValueKey('payment-cvv');
@visibleForTesting
const Key paymentContinueKey = ValueKey('payment-continue');
@visibleForTesting
const Key paymentSavedCardArtKey = ValueKey('payment-saved-card-art');
@visibleForTesting
Key paymentRailKey(PaymentRail rail) => ValueKey('payment-rail-${rail.id}');

/// Checkout **step 2** — the booking summary and how it will be paid for.
///
/// ## Why the card fields here are inert
///
/// `SECURITY.md` 5.1 and 5.2 are unambiguous: card entry must happen through
/// the processor's own SDK/Payment Sheet, **never** through custom-built input
/// fields, and no code may read, log, store, or cache a raw PAN, CVV, or
/// expiry — "not even temporarily for debugging".
///
/// The approved reference draws the fields, so they are drawn. They are also
/// completely inert: the values live in this widget's [State] and nothing reads
/// them except the "is this filled in?" check that enables the button. Nothing
/// is written to Firestore, analytics, logs, or preferences, and there is no
/// callback that hands them anywhere. Pressing Continue only checks that the
/// form looks filled in and then opens step 3.
///
/// This mirrors the contract [NewCardScreen] already established.
///
/// **These fields must be replaced by the processor's Payment Sheet before a
/// single real charge is taken.** Wiring them to anything that transmits a card
/// number would move this app from the simplest PCI DSS self-assessment into
/// the full one — see `SECURITY.md` 5.1.
class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen({
    super.key,
    required this.tour,
    required this.contact,
    required this.party,
    this.transport = false,
    this.savedMethods,
    this.onPaid,
  });

  final Tour tour;

  /// Step 1's payload, carried forward in memory. Still never persisted.
  final BookingContact contact;
  final TravelerParty party;

  /// Whether the optional bus add-on was selected on the Tour Detail screen.
  final bool transport;

  /// The user's reusable methods. Null falls back to the shared design
  /// fixtures; an **empty list** means "no saved card", which hides the
  /// current-method block entirely rather than drawing an empty frame.
  final List<SavedPaymentMethod>? savedMethods;

  /// Fires when a payment would be taken. **Forwarded to step 3**, which is
  /// where the charge belongs — this screen only collects the instrument.
  /// Null until a processor is wired; step 3's CTA then reports that nothing
  /// was charged rather than pretending to.
  final VoidCallback? onPaid;

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  /// See the class doc: inert by contract. Never read except to decide whether
  /// the form looks complete, never transmitted, never persisted.
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  PaymentRail _rail = PaymentRail.card;
  late final List<SavedPaymentMethod> _saved =
      widget.savedMethods ?? demoSavedPaymentMethods();

  /// True while the saved card is the chosen instrument. Selecting a rail below
  /// switches away from it, exactly as the reference's "OR" divider implies.
  bool _useSaved = true;

  SavedPaymentMethod? get _defaultCard => _saved.isEmpty ? null : _saved.first;

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  int get _travelers => widget.party.size;

  num? get _total =>
      widget.tour.totalFor(travelers: _travelers, transport: widget.transport);

  void _continue() {
    final l10n = AppLocalizations.of(context);

    // A saved card needs no entry; a fresh card does.
    if (!(_useSaved && _defaultCard != null) && _rail == PaymentRail.card) {
      final filled =
          _cardNumber.text.trim().isNotEmpty &&
          _expiry.text.trim().isNotEmpty &&
          _cvv.text.trim().isNotEmpty;
      if (!filled) {
        _snack(l10n.paymentIncompleteCard);
        return;
      }
    }

    // Step 3 reviews what was entered and is where a charge would be taken;
    // [onPaid] is forwarded there rather than fired here.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingReviewScreen(
          tour: widget.tour,
          contact: widget.contact,
          party: widget.party,
          transport: widget.transport,
          onPaid: widget.onPaid,
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
        imageAsset: exploreToursBackgroundAsset,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GlassBackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BookingStepIndicator(
                      // Step 1 is behind us, so it draws as completed.
                      activeIndex: 1,
                      labels: [
                        l10n.bookingStepTravelerInfo,
                        l10n.bookingStepPayment,
                        l10n.bookingStepConfirmation,
                      ],
                    ),
                    const SizedBox(height: 20),
                    _detailsCard(l10n),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: PrimaryButton(
                      key: paymentContinueKey,
                      label: l10n.continueToPayment,
                      onTap: _continue,
                      trailingIcon: Icons.arrow_forward_rounded,
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

  Widget _detailsCard(AppLocalizations l10n) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.paymentDetails,
          style: TextStyle(
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.paymentDetailsHint,
          style: TextStyle(
            fontSize: 15,
            height: 22 / 15,
            color: AppColors.secondaryText(context),
          ),
        ),
        const SizedBox(height: 16),
        _Hairline(),
        const SizedBox(height: 20),
        _summaryCard(l10n),
        const SizedBox(height: 24),
        _Hairline(),
        const SizedBox(height: 20),
        Text(
          l10n.paymentMethodLabel,
          style: TextStyle(
            fontSize: 17,
            height: 24 / 17,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 12),
        _methodCard(l10n),
      ],
    ),
  );

  /// Photo on the leading edge, facts in the middle, total on the trailing
  /// edge behind a vertical rule — so the whole block mirrors in Kurdish and
  /// Arabic instead of reading backwards.
  Widget _summaryCard(AppLocalizations l10n) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final total = _total;

    return GlassPanel(
      depth: GlassDepth.middle,
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bookingSummary,
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w700,
              color: AppColors.heading(context),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final facts = _summaryFacts(l10n, languageCode);
              final price = _summaryTotal(l10n, total);
              // Under ~380dp the three columns cannot share a row without the
              // date line wrapping to one word per line.
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _thumbnail(),
                        const SizedBox(width: 14),
                        Expanded(child: facts),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Hairline(),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: price,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _thumbnail(),
                  const SizedBox(width: 14),
                  Expanded(child: facts),
                  const SizedBox(width: 14),
                  Container(
                    width: 1,
                    height: 84,
                    color: AppColors.heading(context).withValues(alpha: 0.12),
                  ),
                  const SizedBox(width: 14),
                  price,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _thumbnail() {
    final urls = widget.tour.imageUrls;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 92,
        height: 92,
        child: urls.isEmpty
            ? _ThumbnailFallback()
            : Image.network(
                urls.first,
                fit: BoxFit.cover,
                // A dead photo URL must not blank the summary of a booking the
                // user is about to pay for.
                errorBuilder: (_, _, _) => _ThumbnailFallback(),
              ),
      ),
    );
  }

  Widget _summaryFacts(AppLocalizations l10n, String languageCode) {
    final start = widget.tour.startAt;
    final guests = l10n.adultsCount(_travelers);
    final line = widget.transport
        ? '$guests + ${l10n.tourTransportationBus}'
        : guests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.tour.name(languageCode),
          style: TextStyle(
            fontSize: 17,
            height: 24 / 17,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.tourDuration(widget.tour.durationDays),
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: AppColors.secondaryText(context),
          ),
        ),
        if (start != null) ...[
          const SizedBox(height: 6),
          _IconLine(
            icon: Icons.calendar_month_outlined,
            text: l10n.tourDateRange(start, widget.tour.endAt),
          ),
        ],
        const SizedBox(height: 6),
        _IconLine(icon: Icons.person_outline_rounded, text: line),
      ],
    );
  }

  Widget _summaryTotal(AppLocalizations l10n, num? total) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // A price is a measurement sequence: LTR in every language, per
      // `DESIGN_SYSTEM.md` 21.
      Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          total == null ? '—' : formatMoney(total, widget.tour.currency),
          style: TextStyle(
            fontSize: 28,
            height: 34 / 28,
            fontWeight: FontWeight.w800,
            color: AppColors.heading(context),
          ),
        ),
      ),
      Text(
        l10n.totalLabel,
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          color: AppColors.secondaryText(context),
        ),
      ),
    ],
  );

  Widget _methodCard(AppLocalizations l10n) {
    final card = _defaultCard;

    return GlassPanel(
      depth: GlassDepth.middle,
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hidden entirely when there is no saved card, as specified — not
          // drawn as an empty frame.
          if (card != null) ...[
            Text(
              l10n.currentPaymentMethod,
              style: TextStyle(
                fontSize: 15,
                height: 21 / 15,
                fontWeight: FontWeight.w600,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 12),
            _SavedCardRow(
              card: card,
              selected: _useSaved,
              onTap: () => setState(() => _useSaved = true),
            ),
            const SizedBox(height: 14),
            _OrDivider(label: l10n.orLabel),
            const SizedBox(height: 14),
          ] else ...[
            Text(
              l10n.selectPaymentMethod,
              style: TextStyle(
                fontSize: 15,
                height: 21 / 15,
                fontWeight: FontWeight.w600,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final rail in PaymentRail.values) ...[
            _RailRow(
              key: paymentRailKey(rail),
              rail: rail,
              selected: !_useSaved && _rail == rail,
              onTap: () => setState(() {
                _rail = rail;
                _useSaved = false;
              }),
            ),
            if (rail != PaymentRail.values.last) const SizedBox(height: 4),
          ],
          // Card entry only applies to the card rail, and only when a saved
          // card is not already doing the job.
          if (!_useSaved && _rail == PaymentRail.card) ...[
            const SizedBox(height: 14),
            _cardEntry(l10n),
          ],
        ],
      ),
    );
  }

  /// The inert card form. See the class doc — nothing here leaves the widget.
  Widget _cardEntry(AppLocalizations l10n) => Column(
    children: [
      AppRecessedGlassField(
        key: paymentCardNumberKey,
        controller: _cardNumber,
        hint: l10n.cardNumber,
        prefixIcon: Icons.credit_card_outlined,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(19),
          _CardNumberSpacer(),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: AppRecessedGlassField(
              key: paymentExpiryKey,
              controller: _expiry,
              hint: l10n.expiryDate,
              prefixIcon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
                _ExpirySlasher(),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppRecessedGlassField(
              key: paymentCvvKey,
              controller: _cvv,
              hint: l10n.cvv,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

/// Groups a card number into fours as it is typed. Formatting only — the value
/// never leaves the field.
class _CardNumberSpacer extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Turns `1228` into `12/28` while typing.
class _ExpirySlasher extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _Hairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: AppColors.heading(context).withValues(alpha: 0.12),
  );
}

class _ThumbnailFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.accent(context).withValues(alpha: 0.18),
    child: Center(
      child: Icon(
        Icons.tour_outlined,
        size: 32,
        color: AppColors.accent(context),
      ),
    ),
  );
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: AppColors.secondaryText(context)),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: AppColors.heading(context),
          ),
        ),
      ),
    ],
  );
}

/// A rule with "OR" set into it, separating the saved card from the rails.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: AppColors.heading(context).withValues(alpha: 0.12),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText(context),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// The saved-card artwork and its details.
class _SavedCardRow extends StatelessWidget {
  const _SavedCardRow({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final SavedPaymentMethod card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: l10n.useSavedCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.stepAccent(context)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Artwork on the leading edge, details on the trailing edge, on
              // one row at every width. The card shrinks to take at most 45%
              // of the row rather than the layout stacking, which pushed the
              // details under the artwork on a narrow phone.
              final artWidth = (constraints.maxWidth * 0.42).clamp(
                _CardArt.minWidth,
                _CardArt.maxWidth,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CardArt(card: card, width: artWidth),
                  const SizedBox(width: 12),
                  Expanded(child: _CardDetails(card: card)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CardArt extends StatelessWidget {
  const _CardArt({required this.card, this.width = maxWidth});

  /// Never narrower than this — below it the digits stop being readable and
  /// the artwork reads as a coloured smudge rather than a card.
  static const double minWidth = 104;
  static const double maxWidth = 168;

  /// Standard payment-card proportions, so the artwork stays card-shaped at
  /// whatever width the row can spare.
  static const double aspectRatio = 168 / 106;

  final SavedPaymentMethod card;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Everything inside scales with the card, so a narrow phone gets a smaller
    // card rather than a clipped one.
    final scale = width / maxWidth;
    final pad = 12.0 * scale;

    return Container(
      key: paymentSavedCardArtKey,
      width: width,
      height: width / aspectRatio,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        gradient: LinearGradient(
          colors: card.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 18 * scale,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const Spacer(),
              Icon(
                Icons.wifi_rounded,
                size: 16 * scale,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
          const Spacer(),
          // Card artwork sits on a fixed dark gradient in both themes, so white
          // is the correct on-colour here rather than a theme token.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                // Scale down rather than overflow: a long brand name must not
                // push the digits off the card.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '•••• ${card.last4}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    card.brand,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({required this.card});

  final SavedPaymentMethod card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.stepAccent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.issuerLabel(l10n),
          style: TextStyle(
            fontSize: 15,
            height: 21 / 15,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          card.kindLabel(l10n),
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondaryText(context),
          ),
        ),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '•••• ${card.last4}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heading(context),
                ),
              ),
              Text(
                card.expiry,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.heading(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Scales down rather than overflowing: on a 320dp phone the details
        // column is only ~80dp wide once the card artwork has taken its share.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: accent.withValues(alpha: 0.15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.defaultPayment,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One selectable payment rail.
class _RailRow extends StatelessWidget {
  const _RailRow({
    super.key,
    required this.rail,
    required this.selected,
    required this.onTap,
  });

  final PaymentRail rail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.stepAccent(context);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? accent : AppColors.secondaryText(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rail.label(l10n),
                  style: TextStyle(
                    fontSize: 15,
                    height: 21 / 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
              _RailMark(rail: rail),
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand mark on the trailing edge of a rail row.
///
/// Drawn from text and shapes rather than bundled logo files: shipping a bank's
/// or card network's artwork is a trademark question, not a design one, and
/// none of those assets are in the repo.
class _RailMark extends StatelessWidget {
  const _RailMark({required this.rail});

  final PaymentRail rail;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.secondaryText(context);
    return switch (rail) {
      PaymentRail.card => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card_rounded, size: 20, color: muted),
          const SizedBox(width: 6),
          Text(
            'VISA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: muted,
            ),
          ),
        ],
      ),
      PaymentRail.fib => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_rounded, size: 18, color: muted),
          const SizedBox(width: 6),
          Text(
            'FIB',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: muted,
            ),
          ),
        ],
      ),
    };
  }
}
