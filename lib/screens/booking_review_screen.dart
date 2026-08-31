import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/policy_topic.dart';
import '../models/tour.dart';
import '../models/traveler_details.dart';
import '../theme/app_colors.dart';
import '../widgets/booking_step_indicator.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'explore_tours_screen.dart' show formatMoney;
import 'policy_document_screen.dart';
import 'policy_screen.dart';
import 'tour_assets.dart';

@visibleForTesting
const Key reviewAgreeCheckboxKey = ValueKey('review-agree-checkbox');
@visibleForTesting
const Key reviewConfirmKey = ValueKey('review-confirm');
@visibleForTesting
const Key reviewTermsLinkKey = ValueKey('review-terms-link');
@visibleForTesting
const Key reviewPolicyLinkKey = ValueKey('review-policy-link');

/// Checkout **step 3** — Review & Confirm, opened from step 2's
/// "Continue to Payment".
///
/// Layout comes from the approved reference: the step indicator with steps 1
/// and 2 completed, then one base-glass card holding the title and its hint,
/// the booking summary, the travellers the user entered, the price breakdown,
/// the consent checkbox and the CTA — separated by hairlines, exactly as drawn.
///
/// ## Why nothing is written here
///
/// This screen shows the user what they typed and what it costs. It creates
/// no Firestore document: `DATA_MODEL.md` gives the app **owner-read only** on
/// `bookings`, and the document is written by the checkout Cloud Function once
/// a processor confirms a charge. Step 1's payload is still carried in memory
/// and still dies with the flow — there is no draft collection holding named
/// travellers' details before a purchase exists.
///
/// The CTA is therefore inert by contract. With no [onPaid] wired it says
/// plainly that nothing was charged and no booking was created, which is the
/// honest message for a button that deliberately goes nowhere.
class BookingReviewScreen extends StatefulWidget {
  const BookingReviewScreen({
    super.key,
    required this.tour,
    required this.contact,
    required this.party,
    this.transport = false,
    this.onPaid,
  });

  final Tour tour;

  /// Step 1's payload, carried forward in memory through step 2.
  final BookingContact contact;
  final TravelerParty party;

  /// Whether the optional bus add-on was selected on the Tour Detail screen.
  final bool transport;

  /// Fires when a charge would be taken. Null until a processor is wired.
  final VoidCallback? onPaid;

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  /// The CTA stays disabled until this is ticked, as specified. Consent is a
  /// precondition for the charge, not a box to un-tick afterwards.
  bool _agreed = false;

  int get _travelers => widget.party.size;

  num? get _total =>
      widget.tour.totalFor(travelers: _travelers, transport: widget.transport);

  /// The bus add-on for the whole party, or null when it was not selected or
  /// the operator published no price — in which case the line is not drawn at
  /// all rather than shown as free.
  num? get _busTotal {
    if (!widget.transport) return null;
    final each = widget.tour.transportPricePerPerson;
    if (each == null) return null;
    return each * _travelers;
  }

  num? get _travelerFeeTotal {
    final each = widget.tour.pricePerPerson;
    return each == null ? null : each * _travelers;
  }

  String _money(num amount) => formatMoney(amount, widget.tour.currency);

  void _openTerms() {
    // The same document the Policy hub's "Terms & Conditions" row opens
    // (`legal_documents/terms_of_service`), not a second copy of it.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PolicyDocumentScreen(topic: PolicyTopic.terms),
      ),
    );
  }

  void _openPolicy() {
    // The hub itself, which is what the hamburger menu's "Policy" entry opens.
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PolicyScreen()));
  }

  void _confirm() {
    final l10n = AppLocalizations.of(context);
    if (widget.onPaid == null) {
      _snack(l10n.confirmPayNotLive);
      return;
    }
    widget.onPaid!.call();
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
      // Same photo, same σ2 blur and same 45% theme gradient as the rest of
      // the tour flow — `DESIGN_SYSTEM.md` 4, no per-screen override.
      body: PageBackground(
        imageAsset: exploreToursBackgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 24),
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
                // Steps 1 and 2 are behind us, so both draw as completed.
                activeIndex: 2,
                labels: [
                  l10n.bookingStepTravelerInfo,
                  l10n.bookingStepPayment,
                  l10n.bookingStepConfirmation,
                ],
              ),
              const SizedBox(height: 20),
              _reviewCard(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(AppLocalizations l10n) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reviewConfirmTitle,
          style: TextStyle(
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.reviewConfirmHint,
          style: TextStyle(
            fontSize: 15,
            height: 22 / 15,
            color: AppColors.secondaryText(context),
          ),
        ),
        const SizedBox(height: 16),
        const _Hairline(),
        const SizedBox(height: 20),
        _summarySection(l10n),
        const SizedBox(height: 24),
        const _Hairline(),
        const SizedBox(height: 20),
        _sectionTitle(l10n.travelersInformation),
        const SizedBox(height: 12),
        _travelersCard(l10n),
        const SizedBox(height: 24),
        const _Hairline(),
        const SizedBox(height: 20),
        _sectionTitle(l10n.priceBreakdown),
        const SizedBox(height: 12),
        _breakdownCard(l10n),
        const SizedBox(height: 20),
        _consentRow(l10n),
        const SizedBox(height: 18),
        _confirmButton(l10n),
      ],
    ),
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 17,
      height: 24 / 17,
      fontWeight: FontWeight.w700,
      color: AppColors.heading(context),
    ),
  );

  // --- Booking summary -------------------------------------------------

  /// Photo on the leading edge, facts in the middle, total on the trailing
  /// edge behind a vertical rule — identical to step 2's summary on purpose,
  /// so the same booking does not appear to change shape between screens.
  Widget _summarySection(AppLocalizations l10n) {
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
                        _Thumbnail(tour: widget.tour),
                        const SizedBox(width: 14),
                        Expanded(child: facts),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _Hairline(),
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
                  _Thumbnail(tour: widget.tour),
                  const SizedBox(width: 14),
                  Expanded(child: facts),
                  const SizedBox(width: 14),
                  const _VerticalRule(height: 84),
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
          total == null ? '—' : _money(total),
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

  // --- Travellers ------------------------------------------------------

  /// The people on the booking on the leading side, the contact details on the
  /// trailing side behind a vertical rule — read-only, so the user can spot a
  /// typo before paying. Correcting one means going back a step, which is
  /// where those fields live and where they are validated.
  Widget _travelersCard(AppLocalizations l10n) {
    final names = <Widget>[
      for (var i = 0; i < widget.party.travelers.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: _AvatarLine(
            // A position in a list, not a sentence: "1 - Ali Ahmad".
            text: '${i + 1} - ${_nameOf(i, l10n)}',
          ),
        ),
    ];

    final contact = <Widget>[
      _IconLine(
        icon: Icons.mail_outline_rounded,
        text: widget.contact.email,
        // An address and a phone number are data sequences, not prose.
        forceLtr: true,
      ),
      const SizedBox(height: 10),
      _IconLine(
        icon: Icons.phone_outlined,
        text: '${widget.contact.dialCode}${widget.contact.phone}',
        forceLtr: true,
      ),
    ];

    return GlassPanel(
      depth: GlassDepth.middle,
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two columns need real width; below that they stack rather than
          // squeezing an email address into 80dp.
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...names,
                const SizedBox(height: 12),
                const _Hairline(),
                const SizedBox(height: 12),
                ...contact,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: names,
                ),
              ),
              const SizedBox(width: 14),
              _VerticalRule(height: (names.length * 34).toDouble().clamp(48, 96)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: contact,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// A traveller who was left unnamed still occupies a seat, so the row is
  /// drawn with its ordinal rather than silently dropped — a missing name is
  /// exactly the kind of mistake this screen exists to surface.
  String _nameOf(int index, AppLocalizations l10n) {
    final name = widget.party.travelers[index].fullName.trim();
    return name.isEmpty ? l10n.travelerNumbered(index + 1) : name;
  }

  // --- Price breakdown -------------------------------------------------

  Widget _breakdownCard(AppLocalizations l10n) {
    final fee = _travelerFeeTotal;
    final bus = _busTotal;
    final busEach = widget.tour.transportPricePerPerson;
    final total = _total;

    return GlassPanel(
      depth: GlassDepth.middle,
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _BreakdownRow(
            label: l10n.travelerFee,
            // "2 adults" — the party the fee covers, as the reference draws it.
            note: l10n.adultsCount(_travelers),
            amount: fee == null ? '—' : _money(fee),
          ),
          if (bus != null && busEach != null) ...[
            const SizedBox(height: 14),
            _BreakdownRow(
              label: l10n.tourTransportationBus,
              // "(2 × $5)" — the arithmetic, so the add-on is checkable.
              note: '(${l10n.priceEachTimes(_travelers, _money(busEach))})',
              amount: _money(bus),
            ),
          ],
          const SizedBox(height: 14),
          const _Hairline(),
          const SizedBox(height: 14),
          _BreakdownRow(
            label: l10n.tourTotalPrice,
            amount: total == null ? '—' : _money(total),
            emphasized: true,
          ),
        ],
      ),
    );
  }

  // --- Consent and CTA -------------------------------------------------

  /// "I agree to the **Terms of Service** and **Policy of App**."
  ///
  /// The two labels are tappable spans into the same documents the hamburger
  /// menu reaches: Terms opens `legal_documents/terms_of_service`, and Policy
  /// opens the hub. They are drawn in the `text-link` token with an underline
  /// and a heavier weight, the same treatment the Register screen already
  /// uses — a link that is only a slightly different colour is not a link.
  Widget _consentRow(AppLocalizations l10n) {
    final parts = l10n.reviewAgreeTermsParts();
    final accent = AppColors.accent(context);
    final body = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: AppColors.heading(context),
    );
    final link = body.copyWith(
      fontWeight: FontWeight.w700,
      color: accent,
      decoration: TextDecoration.underline,
      decorationColor: accent,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            key: reviewAgreeCheckboxKey,
            value: _agreed,
            onChanged: (value) => setState(() => _agreed = value ?? false),
            activeColor: accent,
            side: BorderSide(
              color: AppColors.secondaryText(context),
              width: 1.8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                style: body,
                children: [
                  TextSpan(text: parts[0]),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: _LinkText(
                      key: reviewTermsLinkKey,
                      label: l10n.reviewTermsLink,
                      style: link,
                      onTap: _openTerms,
                    ),
                  ),
                  TextSpan(text: parts[1]),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: _LinkText(
                      key: reviewPolicyLinkKey,
                      label: l10n.reviewPolicyLink,
                      style: link,
                      onTap: _openPolicy,
                    ),
                  ),
                  TextSpan(text: parts[2]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _confirmButton(AppLocalizations l10n) {
    final total = _total;
    // Enabled only once consent is given, as specified — and never for a tour
    // whose price could not be computed, because "Confirm & Pay —" is not
    // something anyone should be able to press.
    final enabled = _agreed && total != null;

    return Semantics(
      // Says *why* it is disabled, which the greyed fill alone does not.
      hint: enabled ? null : l10n.reviewMustAgree,
      child: PrimaryButton(
        key: reviewConfirmKey,
        label: l10n.confirmAndPay(total == null ? '' : _money(total)).trim(),
        onTap: enabled ? _confirm : null,
        trailingIcon: Icons.arrow_forward_rounded,
      ),
    );
  }
}

// --- Shared pieces -----------------------------------------------------

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: AppColors.heading(context).withValues(alpha: 0.12),
  );
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: height,
    color: AppColors.heading(context).withValues(alpha: 0.12),
  );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.tour});

  final Tour tour;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.accent(context).withValues(alpha: 0.18),
      child: Center(
        child: Icon(
          Icons.tour_outlined,
          size: 32,
          color: AppColors.accent(context),
        ),
      ),
    );
    final photos = tour.photos;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 92,
        height: 92,
        child: photos.isEmpty
            ? fallback
            : tour.photosAreAssets
            ? Image.asset(
                photos.first,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            // A dead photo URL must not blank the summary of a booking the
            // user is about to pay for.
            : Image.network(
                photos.first,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    this.forceLtr = false,
  });

  final IconData icon;
  final String text;

  /// True for addresses, phone numbers and other data sequences, which stay
  /// left-to-right in every language (`DESIGN_SYSTEM.md` 21).
  final bool forceLtr;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      textDirection: forceLtr ? TextDirection.ltr : null,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        color: AppColors.heading(context),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.secondaryText(context)),
        const SizedBox(width: 7),
        Expanded(child: label),
      ],
    );
  }
}

/// One traveller, behind the circled avatar the reference draws.
class _AvatarLine extends StatelessWidget {
  const _AvatarLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.14),
          ),
          child: Icon(Icons.person_outline_rounded, size: 17, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
}

/// One line of the price breakdown: label (with an optional note beneath),
/// a dotted leader, and the amount.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.amount,
    this.note,
    this.emphasized = false,
  });

  final String label;
  final String amount;
  final String? note;

  /// The total line: heavier, and without a leader — it is the answer, not
  /// another item.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final heading = AppColors.heading(context);
    final note = this.note;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: emphasized ? 17 : 16,
                  height: 22 / 16,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                  color: heading,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: AppColors.secondaryText(context),
                  ),
                ),
            ],
          ),
        ),
        if (!emphasized)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _DottedLeader(color: heading.withValues(alpha: 0.35)),
            ),
          )
        else
          const Expanded(child: SizedBox(width: 8)),
        // Money stays left-to-right in every language.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: emphasized ? 20 : 16,
              height: emphasized ? 26 / 20 : 22 / 16,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              color: heading,
            ),
          ),
        ),
      ],
    );
  }
}

/// The row of dots between a breakdown label and its amount.
///
/// Painted rather than built from a `Row` of dot widgets: the count depends on
/// the width left over after both ends have been laid out, which is only known
/// at paint time.
class _DottedLeader extends StatelessWidget {
  const _DottedLeader({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    width: double.infinity,
    child: CustomPaint(painter: _DottedLeaderPainter(color)),
  );
}

class _DottedLeaderPainter extends CustomPainter {
  const _DottedLeaderPainter(this.color);

  final Color color;

  static const double _radius = 1.1;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final paint = Paint()..color = color;
    final y = size.height - 8;
    for (var x = _radius; x <= size.width - _radius; x += _gap) {
      canvas.drawCircle(Offset(x, y), _radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLeaderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A tappable label inside a sentence, with a 48dp-tall hit area so it meets
/// the minimum touch target without changing how the line reads.
class _LinkText extends StatelessWidget {
  const _LinkText({
    super.key,
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Vertical slack for the touch target; horizontally the label has to
        // sit flush against the surrounding words.
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(label, style: style),
      ),
    ),
  );
}
