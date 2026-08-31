import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/tour.dart';
import '../models/traveler_details.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_recessed_glass_field.dart';
import '../widgets/booking_step_indicator.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'booking_payment_screen.dart';
import 'tour_assets.dart';

@visibleForTesting
const Key travelerContactNameKey = ValueKey('traveler-contact-name');
@visibleForTesting
const Key travelerContactEmailKey = ValueKey('traveler-contact-email');
@visibleForTesting
const Key travelerContactPhoneKey = ValueKey('traveler-contact-phone');
@visibleForTesting
const Key travelerCountPlusKey = ValueKey('traveler-count+');
@visibleForTesting
const Key travelerCountMinusKey = ValueKey('traveler-count-');
@visibleForTesting
const Key travelerContinueKey = ValueKey('traveler-continue');

/// The dial codes offered by the phone field.
///
/// A short regional list rather than every country on earth: the operators are
/// in Kurdistan and the realistic callers are local or from the neighbouring
/// countries plus the main diaspora destinations. Add to it when a real user
/// needs one — an exhaustive picker is a scrolling chore for everyone else.
@visibleForTesting
const List<({String flag, String code})> travelerDialCodes = [
  (flag: '🇮🇶', code: '+964'),
  (flag: '🇹🇷', code: '+90'),
  (flag: '🇮🇷', code: '+98'),
  (flag: '🇸🇾', code: '+963'),
  (flag: '🇯🇴', code: '+962'),
  (flag: '🇱🇧', code: '+961'),
  (flag: '🇦🇪', code: '+971'),
  (flag: '🇸🇦', code: '+966'),
  (flag: '🇬🇧', code: '+44'),
  (flag: '🇺🇸', code: '+1'),
  (flag: '🇩🇪', code: '+49'),
];

/// Checkout **step 1** — who is going, and who to contact about it.
///
/// Reached from the Tour Detail screen's "Reserve Insight" CTA, which gates on
/// sign-in first: `DATA_MODEL.md` is explicit that there is no such thing as a
/// guest booking, so letting a signed-out person fill three steps only to be
/// rejected by the rules at the end would be a worse experience, not a freer
/// one.
///
/// **This screen writes nothing.** It collects a [BookingContact] and a
/// [TravelerParty] in memory and hands them to the Payment step. `bookings` is
/// created by the checkout Cloud Function after the provider confirms the
/// charge (`SECURITY.md` section 5), so there is no client write path here to
/// secure — and deliberately no draft document holding named travellers' birth
/// dates before a purchase exists.
class BookingTravelerInfoScreen extends StatefulWidget {
  const BookingTravelerInfoScreen({
    super.key,
    required this.tour,
    this.initialTravelers = 1,
    this.transport = false,
    this.userProfileService,
    this.onContinue,
  });

  final Tour tour;

  /// How many travellers the form opens with. Clamped to what the departure
  /// can still take.
  final int initialTravelers;

  /// Whether the optional bus add-on was selected on the Tour Detail screen.
  /// Carried through untouched — this page does not offer it, it only passes
  /// it on so step 2 can price and describe the booking correctly.
  final bool transport;

  final UserProfileService? userProfileService;

  /// Handed the completed step-1 payload. Null routes to the Payment screen;
  /// tests pass a callback to inspect what step 1 produced without navigating.
  final void Function(BookingContact contact, TravelerParty party)? onContinue;

  @override
  State<BookingTravelerInfoScreen> createState() =>
      _BookingTravelerInfoScreenState();
}

class _BookingTravelerInfoScreenState extends State<BookingTravelerInfoScreen> {
  late final UserProfileService _profileService =
      widget.userProfileService ?? UserProfileService();

  final _contactName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();

  /// One controller per traveller name, kept alive across resizes so shrinking
  /// and re-growing the party does not silently wipe what was typed.
  final List<TextEditingController> _travelerNames = [];

  String _dialCode = travelerDialCodes.first.code;
  late TravelerParty _party;
  bool _submitted = false;

  /// Null means "no cap published", which the model already treats as bookable.
  int? get _maxTravelers => widget.tour.spotsLeft;

  @override
  void initState() {
    super.initState();
    final cap = _maxTravelers;
    // A departure with no published capacity is bookable, per Tour.hasRoomFor;
    // one with none left still builds a form, but the CTA is disabled.
    final start = cap == null
        ? (widget.initialTravelers < 1 ? 1 : widget.initialTravelers)
        : widget.initialTravelers.clamp(1, cap < 1 ? 1 : cap);
    _party = TravelerParty.ofSize(start);
    _syncControllers();
    _prefillContact();
  }

  @override
  void dispose() {
    _contactName.dispose();
    _contactEmail.dispose();
    _contactPhone.dispose();
    for (final controller in _travelerNames) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Prefills the contact block from the signed-in profile, the way both
  /// reference products do — the person booking is usually the contact, and
  /// retyping their own name is friction with no purpose.
  ///
  /// A failure here is silent on purpose: an empty form is a working form, and
  /// an error banner about a convenience the user never asked for is noise.
  Future<void> _prefillContact() async {
    try {
      final profile = await _profileService.fetchProfile();
      if (!mounted || profile == null) return;
      setState(() {
        if (_contactName.text.isEmpty) _contactName.text = profile.name;
        final email = profile.email;
        if (_contactEmail.text.isEmpty && email != null) {
          _contactEmail.text = email;
        }
        final phone = profile.phone;
        if (_contactPhone.text.isEmpty && phone != null) {
          _applyStoredPhone(phone);
        }
      });
    } catch (_) {
      // Deliberately ignored — see above.
    }
  }

  /// Splits a stored `+964 750…` into the picker value and the local digits, so
  /// the dial code is not shown twice.
  void _applyStoredPhone(String stored) {
    final trimmed = stored.trim();
    for (final entry in travelerDialCodes) {
      if (trimmed.startsWith(entry.code)) {
        _dialCode = entry.code;
        _contactPhone.text = trimmed.substring(entry.code.length).trim();
        return;
      }
    }
    _contactPhone.text = trimmed;
  }

  void _syncControllers() {
    while (_travelerNames.length < _party.size) {
      final index = _travelerNames.length;
      final controller = TextEditingController(
        text: index < _party.size ? _party.travelers[index].fullName : '',
      );
      controller.addListener(() => _onTravelerName(index, controller.text));
      _travelerNames.add(controller);
    }
    // Controllers past the current size are kept, not disposed: the user may
    // step the count back up, and their typing should still be there.
  }

  void _onTravelerName(int index, String value) {
    if (index >= _party.size) return;
    setState(
      () => _party = _party.updated(
        index,
        _party.travelers[index].copyWith(fullName: value),
      ),
    );
  }

  void _setCount(int next) {
    final cap = _maxTravelers;
    final upper = cap ?? 20;
    if (next < 1 || next > upper) return;
    setState(() {
      _party = _party.resized(next);
      _syncControllers();
    });
  }

  Future<void> _pickBirthDate(int index) async {
    final now = DateTime.now();
    final current = _party.travelers[index].dateOfBirth;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 30, now.month, now.day),
      // 120 years is past any real traveller; the upper bound is today, so a
      // future birth date is impossible to pick rather than merely rejected.
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: AppLocalizations.of(context).dateOfBirthHint,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _party = _party.updated(
        index,
        _party.travelers[index].copyWith(dateOfBirth: picked),
      ),
    );
  }

  BookingContact get _contact => BookingContact(
    fullName: _contactName.text,
    email: _contactEmail.text,
    phone: _contactPhone.text,
    dialCode: _dialCode,
  );

  void _continue() {
    setState(() => _submitted = true);
    final l10n = AppLocalizations.of(context);

    if (!_contact.isComplete) {
      _snack(l10n.contactIncomplete);
      return;
    }
    if (!_party.isComplete) {
      _snack(l10n.travelerInfoIncomplete);
      return;
    }
    final minAge = widget.tour.minAge;
    final underage = _party.underageIndexes(minAge, DateTime.now());
    if (underage.isNotEmpty && minAge != null) {
      _snack(l10n.travelerTooYoung(minAge));
      return;
    }
    if (widget.onContinue case final handler?) {
      handler(_contact, _party);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingPaymentScreen(
          tour: widget.tour,
          contact: _contact,
          party: _party,
          transport: widget.transport,
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
                    // The back button stays physically top-left in every
                    // language — `DESIGN_SYSTEM.md` 21's approved exception.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GlassBackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BookingStepIndicator(
                      activeIndex: 0,
                      labels: [
                        l10n.bookingStepTravelerInfo,
                        l10n.bookingStepPayment,
                        l10n.bookingStepConfirmation,
                      ],
                    ),
                    const SizedBox(height: 20),
                    _formCard(l10n),
                  ],
                ),
              ),
              // Outside the scroll view, so the CTA holds its position while
              // the form scrolls behind it.
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: PrimaryButton(
                      key: travelerContinueKey,
                      label: l10n.continueToPayment,
                      onTap: widget.tour.isSoldOut ? null : _continue,
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

  Widget _formCard(AppLocalizations l10n) {
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.travelerInformation,
            style: TextStyle(
              fontSize: 24,
              height: 32 / 24,
              fontWeight: FontWeight.w700,
              color: AppColors.heading(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.travelerInformationHint,
            style: TextStyle(
              fontSize: 15,
              height: 22 / 15,
              color: AppColors.secondaryText(context),
            ),
          ),
          const SizedBox(height: 16),
          _Divider(),
          const SizedBox(height: 20),
          Text(
            l10n.contactPerson,
            style: TextStyle(
              fontSize: 17,
              height: 24 / 17,
              fontWeight: FontWeight.w700,
              color: AppColors.heading(context),
            ),
          ),
          const SizedBox(height: 12),
          AppRecessedGlassField(
            key: travelerContactNameKey,
            controller: _contactName,
            hint: l10n.fullName,
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppRecessedGlassField(
            key: travelerContactEmailKey,
            controller: _contactEmail,
            hint: l10n.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _phoneRow(l10n),
          const SizedBox(height: 24),
          _Divider(),
          const SizedBox(height: 20),
          _travelerCountRow(l10n),
          const SizedBox(height: 16),
          for (var i = 0; i < _party.size; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _travelerCard(l10n, i),
          ],
          const SizedBox(height: 20),
          _secureNote(l10n),
        ],
      ),
    );
  }

  /// The dial-code picker and the number, on one row.
  ///
  /// The whole row is forced LTR: `DESIGN_SYSTEM.md` 21 keeps phone and dial
  /// codes left-to-right in every language, and a `+964` that mirrors reads as
  /// a different number.
  Widget _phoneRow(AppLocalizations l10n) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          _DialCodePicker(
            value: _dialCode,
            onChanged: (code) => setState(() => _dialCode = code),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppRecessedGlassField(
              key: travelerContactPhoneKey,
              controller: _contactPhone,
              hint: l10n.phoneNumber,
              prefixIcon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\s-]')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _travelerCountRow(AppLocalizations l10n) {
    final cap = _maxTravelers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Flexible so the label wraps on a narrow phone instead of
            // pushing the stepper off the edge.
            Flexible(
              child: Text(
                l10n.travelersLabel,
                style: TextStyle(
                  fontSize: 17,
                  height: 24 / 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _DottedRule()),
            const SizedBox(width: 8),
            _CountButton(
              key: travelerCountMinusKey,
              icon: Icons.remove_rounded,
              onTap: _party.size > 1 ? () => _setCount(_party.size - 1) : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading(context),
                ),
              ),
            ),
            _CountButton(
              key: travelerCountPlusKey,
              icon: Icons.add_rounded,
              onTap: (cap == null || _party.size < cap)
                  ? () => _setCount(_party.size + 1)
                  : null,
            ),
          ],
        ),
        // Only speaks up when the number is genuinely small, the same rule the
        // tour card's availability line follows.
        if (widget.tour.isSoldOut || widget.tour.isLowAvailability) ...[
          const SizedBox(height: 8),
          Text(
            widget.tour.isSoldOut
                ? l10n.noPlacesLeft
                : l10n.onlyPlacesLeft(cap ?? 0),
            style: TextStyle(
              fontSize: 13,
              height: 18 / 13,
              color: AppColors.secondaryText(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _travelerCard(AppLocalizations l10n, int index) {
    final traveler = _party.travelers[index];
    final birth = traveler.dateOfBirth;
    final missing = _submitted && !traveler.isComplete;

    return GlassPanel(
      depth: GlassDepth.middle,
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      borderColor: missing ? Theme.of(context).colorScheme.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The chip sits beside the title when there is room and drops
          // beneath it when there is not — "Lead traveler" is too important to
          // ellipsize, and too wide to keep on one line at 320dp.
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: AppColors.heading(context),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.travelerNumbered(index + 1),
                      style: TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading(context),
                      ),
                    ),
                  ),
                ],
              );
              final chip = _LeadChip(
                selected: traveler.isLead,
                label: l10n.leadTraveler,
                onTap: () => setState(() => _party = _party.withLead(index)),
              );
              if (constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 8), chip],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  chip,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Side by side when there is room, stacked when there is not — the
          // two fields together need more than a narrow phone can give them.
          LayoutBuilder(
            builder: (context, constraints) {
              final name = AppRecessedGlassField(
                controller: _travelerNames[index],
                hint: l10n.fullName,
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
              );
              final dob = AppRecessedGlassField(
                controller: TextEditingController(
                  text: birth == null ? '' : _formatDate(birth),
                ),
                hint: l10n.dateOfBirthHint,
                prefixIcon: Icons.calendar_today_outlined,
                readOnly: true,
                onTap: () => _pickBirthDate(index),
              );
              if (constraints.maxWidth < 340) {
                return Column(
                  children: [name, const SizedBox(height: 10), dob],
                );
              }
              return Row(
                children: [
                  Expanded(child: name),
                  const SizedBox(width: 10),
                  Expanded(child: dob),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// `dd/MM/yyyy`, forced LTR like every other numeric sequence.
  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Widget _secureNote(AppLocalizations l10n) => Row(
    children: [
      Icon(
        Icons.verified_user_outlined,
        size: 20,
        color: AppColors.accent(context),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          l10n.informationSecure,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: AppColors.secondaryText(context),
          ),
        ),
      ),
    ],
  );
}

/// The hairline that separates the card header from the form, and the contact
/// block from the travellers.
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: AppColors.heading(context).withValues(alpha: 0.12),
  );
}

/// The dashed run between "Travelers" and the stepper, as the reference draws
/// it. Painted rather than a row of Containers so it fills whatever width is
/// left over without arithmetic.
class _DottedRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: CustomPaint(
      painter: _DottedRulePainter(
        color: AppColors.heading(context).withValues(alpha: 0.35),
      ),
    ),
  );
}

class _DottedRulePainter extends CustomPainter {
  const _DottedRulePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedRulePainter old) => old.color != color;
}

/// A circular +/- button. 48dp target with a 40dp visible circle, matching the
/// touch-target rule the rest of the app follows.
class _CountButton extends StatelessWidget {
  const _CountButton({super.key, required this.icon, required this.onTap});

  final IconData icon;

  /// Null disables the button — at the floor of one traveller, or at the
  /// departure's remaining capacity.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final content = AppColors.heading(
      context,
    ).withValues(alpha: enabled ? 1 : 0.35);

    return Semantics(
      button: true,
      enabled: enabled,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: content.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 20, color: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "lead traveler" toggle on each traveller card.
///
/// Single-select across the party: tapping one moves the designation rather
/// than adding a second, which is why it is a chip on every card and not a
/// checkbox that could end up with none ticked.
class _LeadChip extends StatelessWidget {
  const _LeadChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    final content = selected ? accent : AppColors.secondaryText(context);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : content.withValues(alpha: 0.35),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 15,
                color: content,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flag + dial code, opening a sheet of the supported countries.
class _DialCodePicker extends StatelessWidget {
  const _DialCodePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entry = travelerDialCodes.firstWhere(
      (e) => e.code == value,
      orElse: () => travelerDialCodes.first,
    );

    return Semantics(
      button: true,
      label: l10n.selectDialCode,
      value: value,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.heading(context).withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                entry.code,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heading(context),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.heading(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: GlassPanel(
          borderRadius: 28,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in travelerDialCodes)
                ListTile(
                  leading: Text(
                    entry.flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    entry.code,
                    style: TextStyle(color: AppColors.heading(sheetContext)),
                  ),
                  trailing: entry.code == value
                      ? Icon(
                          Icons.check_rounded,
                          color: AppColors.accent(sheetContext),
                        )
                      : null,
                  onTap: () {
                    onChanged(entry.code);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
