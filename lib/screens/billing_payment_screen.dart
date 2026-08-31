import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/saved_payment_method.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/sign_in_required.dart';
import 'new_card_screen.dart';
import 'policy_screen.dart';

/// Billing hub opened from the Home drawer.
///
/// It shows either the add-method empty state or the saved-method/history
/// design. Card details remain in memory and are never persisted; production
/// submission must be completed by a PCI-compliant payment provider.
///
/// **The card list is session state, deliberately.** `DATA_MODEL.md` ("Saved
/// payment methods") holds that the carousel is fixture data until a callable
/// Cloud Function can list the provider customer's reusable methods, and
/// `SECURITY.md` 5.1 forbids the client storing anything card-shaped. So Add /
/// Change / Delete edit an in-memory list and reset when the screen closes —
/// they are wired to real UI behaviour, not to real persistence. Replacing
/// `_seedMethods` and the three mutators with provider calls is the whole of
/// what is left to do once that endpoint exists.
class BillingPaymentScreen extends StatefulWidget {
  const BillingPaymentScreen({
    super.key,
    this.onAddCard,
    this.hasSavedMethods = false,
    this.isGuest = false,
  });

  final VoidCallback? onAddCard;
  final bool hasSavedMethods;

  /// Saved cards belong to an account, so a guest gets the shared sign-in gate
  /// instead of the billing UI — the same treatment as My Bookings, and the
  /// rule in `SECURITY.md` 6.1f (no anonymous mirror of signed-in data).
  final bool isGuest;

  static const String backgroundAsset = PolicyScreen.backgroundAsset;
  static const double backgroundBlurSigma = 24;

  @override
  State<BillingPaymentScreen> createState() => _BillingPaymentScreenState();
}

class _BillingPaymentScreenState extends State<BillingPaymentScreen> {
  /// Every saved card, newest first. Empty means the add-method empty state.
  final List<SavedPaymentMethod> _methods = [];

  /// Which card carries the "Default" badge, by [SavedPaymentMethod.id]. Null
  /// only while the list is empty.
  String? _defaultId;

  /// Assigns ids to cards added this session, so Change/Delete can target one
  /// unambiguously even when two cards share a brand and last four.
  int _nextId = 0;

  final _carousel = PageController();

  /// The card the action row acts on: whichever one the carousel is showing.
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.hasSavedMethods) _seedMethods();
  }

  @override
  void dispose() {
    _carousel.dispose();
    super.dispose();
  }

  /// The two design fixtures, taken from the shared list so this screen and
  /// checkout step 2 cannot show different cards. They are ordinary entries —
  /// deletable and re-assignable like any added card — so the screen behaves
  /// consistently rather than having two magic rows that ignore the buttons.
  void _seedMethods() {
    _methods.addAll([
      for (final card in demoSavedPaymentMethods())
        SavedPaymentMethod(
          id: 'seed-${_nextId++}',
          issuer: card.issuer,
          kind: card.kind,
          last4: card.last4,
          expiry: card.expiry,
          brand: card.brand,
          colors: card.colors,
        ),
    ]);
    _defaultId = _methods.first.id;
  }

  // --- Add / Change / Delete ------------------------------------------------

  void _addCard(BuildContext context) {
    if (widget.onAddCard case final callback?) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (cardContext) => NewCardScreen(
          onSubmit: (card) {
            Navigator.of(cardContext).pop();
            if (mounted) _appendCard(card);
          },
        ),
      ),
    );
  }

  /// Appends rather than replaces — the previous behaviour overwrote a single
  /// `NewCardSummary?` slot, so a second card silently erased the first.
  void _appendCard(NewCardSummary card) {
    final entry = SavedPaymentMethod(
      id: 'card-${_nextId++}',
      issuer: CardIssuer.saved,
      kind: CardKind.debitOrCredit,
      last4: card.last4,
      expiry: card.expiry,
      brand: card.brand,
      colors: const [Color(0xFF348D96), Color(0xFF124A65), Color(0xFF092E50)],
    );
    setState(() {
      _methods.insert(0, entry);
      // The first card to exist is necessarily the default one.
      _defaultId ??= entry.id;
    });
    // Bring the new card into view, since it lands at the front of the list.
    if (_carousel.hasClients) _carousel.jumpToPage(0);
    _snack(AppLocalizations.of(context).cardAdded);
  }

  /// Change → pick which card is the default, the operation Booking.com and
  /// Agoda both offer here. Editing a card's number is deliberately not an
  /// option: a changed PAN is a new method at the processor, and `SECURITY.md`
  /// 5.1 means we could not pre-fill the old one to edit in any case.
  Future<void> _changeDefault() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DefaultCardSheet(
        methods: List.unmodifiable(_methods),
        defaultId: _defaultId,
      ),
    );
    if (picked == null || !mounted || picked == _defaultId) return;
    setState(() => _defaultId = picked);
    _snack(l10n.defaultCardUpdated);
  }

  /// Delete → confirm first. Removing a payment method is not undoable here
  /// (there is no trash to restore from), so it gets a dialog naming the card.
  Future<void> _deleteCurrent() async {
    if (_methods.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final target = _methods[_page.clamp(0, _methods.length - 1)];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteCardTitle),
        content: Text(l10n.deleteCardBody(target.last4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _methods.removeWhere((method) => method.id == target.id);
      // Deleting the default promotes the next card, so the badge is never
      // left pointing at a card that no longer exists.
      if (_defaultId == target.id) {
        _defaultId = _methods.isEmpty ? null : _methods.first.id;
      }
      _page = _page.clamp(0, _methods.isEmpty ? 0 : _methods.length - 1);
    });
    if (_carousel.hasClients && _methods.isNotEmpty) {
      _carousel.jumpToPage(_page);
    }
    _snack(l10n.cardDeleted);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // A guest has no saved methods by definition — the rules require an auth
    // uid — so the screen shows the shared gate instead of the billing UI.
    if (widget.isGuest) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: PageBackground(
          imageAsset: BillingPaymentScreen.backgroundAsset,
          child: SafeArea(
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
                        alignment: Alignment.centerLeft,
                        child: GlassBackButton(
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.billingPaymentTitle,
                        style: TextStyle(
                          fontSize: 32,
                          height: 40 / 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02 * 32,
                          color: AppColors.heading(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SignInRequired(
                    title: l10n.billingSignInTitle,
                    body: l10n.billingSignInBody,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: BillingPaymentScreen.backgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 28),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.billingPaymentTitle,
                style: TextStyle(
                  fontSize: 32,
                  height: 40 / 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02 * 32,
                  color: AppColors.heading(context),
                ),
              ),
              const SizedBox(height: 28),
              // Driven by the list itself, not a separate flag — deleting the
              // last card must fall back to the empty state, and adding the
              // first must leave it.
              if (_methods.isNotEmpty)
                _SavedBillingContent(
                  methods: _methods,
                  defaultId: _defaultId,
                  controller: _carousel,
                  page: _page,
                  onPageChanged: (index) => setState(() => _page = index),
                  onAddCard: () => _addCard(context),
                  onChangeDefault: _changeDefault,
                  onDelete: _deleteCurrent,
                )
              else
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: GlassPanel(
                      borderRadius: 28,
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.currentPaymentMethod,
                            style: TextStyle(
                              fontSize: 20,
                              height: 28 / 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading(context),
                            ),
                          ),
                          const SizedBox(height: 34),
                          const Align(child: _AddPaymentIcon()),
                          const SizedBox(height: 28),
                          Text(
                            l10n.addPaymentMethod,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              height: 36 / 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading(context),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.addPaymentMethodDescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 24 / 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: AppColors.secondaryText(context),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l10n.paymentInformationEncrypted,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    color: AppColors.secondaryText(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          PrimaryButton(
                            label: l10n.addCard,
                            onTap: () => _addCard(context),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              _PlainHint(
                                icon: Icons.verified_user_outlined,
                                label: l10n.debitOrCreditCard,
                              ),
                              _PlainHint(
                                icon: Icons.lock_outline_rounded,
                                label: l10n.secureCheckout,
                              ),
                            ],
                          ),
                        ],
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
}

class _SavedBillingContent extends StatelessWidget {
  const _SavedBillingContent({
    required this.methods,
    required this.defaultId,
    required this.controller,
    required this.page,
    required this.onPageChanged,
    required this.onAddCard,
    required this.onChangeDefault,
    required this.onDelete,
  });

  final List<SavedPaymentMethod> methods;
  final String? defaultId;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onAddCard;
  final VoidCallback onChangeDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = [
      _PaymentHistoryData(
        icon: Icons.bed_rounded,
        title: l10n.mountainViewResort,
        category: l10n.hotel,
        date: l10n.paymentDateMay24,
        amount: r'$480',
        paid: true,
      ),
      _PaymentHistoryData(
        icon: Icons.flight_rounded,
        title: l10n.erbilToIstanbul,
        category: l10n.flight,
        date: l10n.paymentDateMay23,
        amount: r'$320',
        paid: true,
      ),
      _PaymentHistoryData(
        icon: Icons.directions_car_filled_rounded,
        title: l10n.suvRental,
        category: l10n.car,
        date: l10n.paymentDateMay25,
        amount: r'$210',
        paid: true,
      ),
      _PaymentHistoryData(
        icon: Icons.landscape_rounded,
        title: l10n.rawanduzCanyonAdventure,
        category: l10n.tour,
        date: l10n.paymentDateMay26,
        amount: r'$160',
        paid: false,
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassPanel(
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.currentPaymentMethod,
                    style: TextStyle(
                      fontSize: 20,
                      height: 28 / 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading(context),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // A PageView rather than a free-scrolling ListView: the
                  // action row below acts on "the card you are looking at",
                  // which is only well-defined if the carousel snaps.
                  SizedBox(
                    height: 174,
                    child: PageView.builder(
                      key: const Key('saved-payment-methods'),
                      controller: controller,
                      onPageChanged: onPageChanged,
                      itemCount: methods.length,
                      itemBuilder: (context, index) => _SavedMethodTile(
                        data: methods[index],
                        isDefault: methods[index].id == defaultId,
                      ),
                    ),
                  ),
                  if (methods.length > 1) ...[
                    const SizedBox(height: 12),
                    _CarouselDots(count: methods.length, active: page),
                  ],
                  const SizedBox(height: 18),
                  Divider(
                    height: 1,
                    color: AppColors.secondaryText(
                      context,
                    ).withValues(alpha: 0.25),
                  ),
                  _PaymentActions(
                    onAddCard: onAddCard,
                    // Change needs a second card to switch to; with one card
                    // saved there is nothing to pick, so it greys out rather
                    // than opening a one-row sheet.
                    onChangeDefault: methods.length > 1
                        ? onChangeDefault
                        : null,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              l10n.paymentHistory,
              style: TextStyle(
                fontSize: 22,
                height: 30 / 22,
                fontWeight: FontWeight.w600,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 14),
            GlassPanel(
              borderRadius: 28,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < history.length; index++) ...[
                    _PaymentHistoryRow(data: history[index]),
                    if (index != history.length - 1)
                      Divider(
                        height: 1,
                        indent: 18,
                        endIndent: 18,
                        color: AppColors.secondaryText(
                          context,
                        ).withValues(alpha: 0.22),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who issued the card, as a key rather than a resolved string — the label has
/// to be localized at build time, and the list itself is built in `initState`
/// where there is no `AppLocalizations` yet.

class _SavedMethodTile extends StatelessWidget {
  const _SavedMethodTile({required this.data, required this.isDefault});

  final SavedPaymentMethod data;

  /// Owned by the screen, not the card — exactly one card carries the badge,
  /// and it moves when Change is used.
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SizedBox(width: 160, height: 122, child: _MiniBankCard(data: data)),
        const SizedBox(width: 14),
        // The carousel is a fixed 174dp tall, but the text block's height
        // varies: a two-line bank name plus the Default badge already
        // overflowed it by 22dp on a 393dp phone — a bug that predates the
        // badge being movable, and one every card can now hit. Scaling down
        // keeps the design's fixed row height instead of clipping the
        // expiry, and matches how the booking chips and flight route already
        // absorb long strings.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.issuerLabel(l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 19 / 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading(context),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.kindLabel(l10n),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '•••• ${data.last4}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        data.expiry,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.heading(context),
                        ),
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _StatusBadge(
                          label: l10n.defaultPayment,
                          paid: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBankCard extends StatelessWidget {
  const _MiniBankCard({required this.data});

  final SavedPaymentMethod data;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: data.colors,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_rounded,
              size: 18,
              color: Colors.white,
            ),
            const Spacer(),
            Icon(
              Icons.contactless_rounded,
              size: 19,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Container(
          width: 30,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFDAD8C9),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            size: 15,
            color: Color(0xFF6F7471),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '•••• ${data.last4}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Text(
              data.brand,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Which card in the carousel the action row is pointed at.
class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);

    // Left-to-right in every language: the dots track a scroll position, not
    // a sentence — the same rule the flight route and OTP box follow.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < count; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: index == active ? 1 : 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentActions extends StatelessWidget {
  const _PaymentActions({
    required this.onAddCard,
    required this.onChangeDefault,
    required this.onDelete,
  });

  final VoidCallback onAddCard;

  /// Null disables the button — see the call site for when that applies.
  final VoidCallback? onChangeDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 66,
      child: Row(
        children: [
          Expanded(
            child: _PaymentAction(
              icon: Icons.add_circle_outline_rounded,
              label: l10n.add,
              onTap: onAddCard,
            ),
          ),
          const _ActionDivider(),
          Expanded(
            child: _PaymentAction(
              icon: Icons.sync_rounded,
              label: l10n.change,
              onTap: onChangeDefault,
            ),
          ),
          const _ActionDivider(),
          Expanded(
            child: _PaymentAction(
              icon: Icons.delete_outline_rounded,
              label: l10n.delete,
              onTap: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

/// Change → choose which saved card is the default.
///
/// This is the operation Booking.com and Agoda actually offer on a saved
/// method; neither lets you edit a card in place, because a changed number is
/// a new method at the processor (and `SECURITY.md` 5.1 means the old number
/// could never be pre-filled for editing anyway).
class _DefaultCardSheet extends StatelessWidget {
  const _DefaultCardSheet({required this.methods, required this.defaultId});

  final List<SavedPaymentMethod> methods;
  final String? defaultId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = AppColors.accent(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          borderRadius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.setDefaultCard,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.heading(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.setDefaultCardBody,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Scrollable, because the list grows every time Add is used and
              // a tall sheet must not overflow on a short phone.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final method in methods)
                      ListTile(
                        leading: Icon(Icons.credit_card_rounded, color: accent),
                        title: Text(
                          method.issuerLabel(l10n),
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        subtitle: Directionality(
                          // A card number reads left-to-right in every
                          // language, like the booking reference.
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${method.brand}  ••••  ${method.last4}',
                            style: TextStyle(
                              color: AppColors.secondaryText(context),
                            ),
                          ),
                        ),
                        trailing: method.id == defaultId
                            ? Icon(Icons.check_rounded, color: accent)
                            : null,
                        onTap: () => Navigator.of(context).pop(method.id),
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

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: AppColors.secondaryText(context).withValues(alpha: 0.25),
  );
}

class _PaymentAction extends StatelessWidget {
  const _PaymentAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A null callback now genuinely disables the button. It used to fall back
    // to `() {}`, which left Change and Delete rippling on tap while doing
    // nothing — indistinguishable from a broken button.
    final enabled = onTap != null;
    final iconColor = AppColors.accent(context);
    final labelColor = AppColors.heading(context);

    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: iconColor),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentHistoryData {
  const _PaymentHistoryData({
    required this.icon,
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
    required this.paid,
  });

  final IconData icon;
  final String title;
  final String category;
  final String date;
  final String amount;
  final bool paid;
}

class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow({required this.data});

  final _PaymentHistoryData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              data.icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkOnPrimary
                  : Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.category,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.secondaryText(context),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        data.date,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.amount,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading(context),
                ),
              ),
              const SizedBox(height: 7),
              _StatusBadge(
                label: data.paid ? l10n.paid : l10n.pending,
                paid: data.paid,
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 15,
                    color: AppColors.heading(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.viewReceipt,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.heading(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.paid});

  final String label;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final background = paid
        ? (isDark ? AppColors.luminousMint : AppColors.pageGradientTop)
        : scheme.tertiaryContainer;
    final foreground = paid
        ? (isDark ? AppColors.darkOnPrimary : AppColors.actionNavy)
        : scheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular add-card illustration from the supplied reference.
class _AddPaymentIcon extends StatelessWidget {
  const _AddPaymentIcon();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);

    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.58),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.credit_card_outlined, size: 64, color: accent),
          Positioned(
            right: 22,
            bottom: 27,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.luminousMint
                    : Colors.white,
                border: Border.all(color: accent, width: 2.5),
              ),
              child: Icon(Icons.add_rounded, size: 24, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Security metadata intentionally has no pill, border, or strike/stroke.
class _PlainHint extends StatelessWidget {
  const _PlainHint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.secondaryText(context);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
