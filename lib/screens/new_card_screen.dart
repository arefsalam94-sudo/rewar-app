import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'policy_screen.dart';

/// Collects card details for a future PCI-compliant payment-provider flow.
///
/// Values intentionally live only in this widget. In particular, the PAN and
/// CVV must never be written to Firestore, analytics, logs, or preferences.
class NewCardScreen extends StatefulWidget {
  const NewCardScreen({super.key, this.onSubmit});

  static const String backgroundAsset = PolicyScreen.backgroundAsset;

  /// Hook for the hosted/tokenized payment flow. Only display-safe last-four,
  /// expiry, and brand metadata is exposed.
  final ValueChanged<NewCardSummary>? onSubmit;

  @override
  State<NewCardScreen> createState() => _NewCardScreenState();
}

class _NewCardScreenState extends State<NewCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _zipController = TextEditingController();
  bool _saveCard = true;
  bool _attemptedSubmit = false;
  String? _country;

  static const _countries = <String>[
    'Iraq',
    'Türkiye',
    'Iran',
    'Syria',
    'Jordan',
    'Lebanon',
    'Saudi Arabia',
    'United Arab Emirates',
    'Qatar',
    'Kuwait',
    'Bahrain',
    'Oman',
    'Egypt',
    'United Kingdom',
    'United States',
    'Canada',
    'Germany',
    'France',
    'Italy',
    'Spain',
    'Netherlands',
    'Sweden',
    'Australia',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _refreshPreview(String _) => setState(() {});

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _attemptedSubmit = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_country == null) return;
    if (widget.onSubmit case final callback?) {
      final digits = _numberController.text.replaceAll(' ', '');
      callback(
        NewCardSummary(
          last4: digits.substring(digits.length - 4),
          expiry: _expiryController.text,
          brand: _cardBrand(digits),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).secureCardSetupUnavailable,
          ),
        ),
      );
  }

  String _cardBrand(String digits) {
    if (digits.startsWith('4')) return 'VISA';
    final prefix = int.tryParse(digits.substring(0, 2));
    if (prefix != null && prefix >= 51 && prefix <= 55) return 'MC';
    return 'CARD';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: NewCardScreen.backgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 28),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: GlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.newCard,
                style: TextStyle(
                  fontSize: 32,
                  height: 40 / 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.32,
                  color: AppColors.heading(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.newCardDescription,
                style: TextStyle(
                  fontSize: 16,
                  height: 24 / 16,
                  color: AppColors.secondaryText(context),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _CardPreview(
                    name: _nameController.text,
                    number: _numberController.text,
                    expiry: _expiryController.text,
                    cardholderPlaceholder: l10n.cardholderName,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: GlassPanel(
                    borderRadius: 28,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.cardDetails,
                            style: TextStyle(
                              fontSize: 20,
                              height: 28 / 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading(context),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _CardField(
                            label: l10n.cardholderName,
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onChanged: _refreshPreview,
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? l10n.requiredField
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _CardField(
                            label: l10n.cardNumber,
                            controller: _numberController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [_CardNumberFormatter()],
                            onChanged: _refreshPreview,
                            validator: (value) {
                              final digits = (value ?? '').replaceAll(' ', '');
                              return digits.length < 12
                                  ? l10n.invalidCardNumber
                                  : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CardField(
                                  label: l10n.expiryDate,
                                  hint: l10n.expiryHint,
                                  controller: _expiryController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: const [_ExpiryFormatter()],
                                  onChanged: _refreshPreview,
                                  validator: (value) =>
                                      _validExpiry(value ?? '')
                                      ? null
                                      : l10n.invalidExpiryDate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CardField(
                                  label: l10n.cvv,
                                  hint: '•••',
                                  controller: _cvvController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  obscureText: true,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  validator: (value) {
                                    final length = (value ?? '').length;
                                    return length < 3 ? l10n.invalidCvv : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CountryField(
                                  label: l10n.country,
                                  hint: l10n.yourCountry,
                                  value: _country,
                                  countries: _countries,
                                  onChanged: (value) =>
                                      setState(() => _country = value),
                                  errorText:
                                      _attemptedSubmit && _country == null
                                      ? l10n.requiredField
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CardField(
                                  label: l10n.zipCode,
                                  hint: l10n.optional,
                                  controller: _zipController,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Icon(
                                Icons.bookmark_border_rounded,
                                color: AppColors.accent(context),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.saveCardForFutureBookings,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 20 / 15,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: _saveCard,
                                activeTrackColor: AppColors.accent(context),
                                onChanged: (value) =>
                                    setState(() => _saveCard = value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.heading(context),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l10n.editPaymentMethodLater,
                          style: TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            color: AppColors.heading(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: PrimaryButton(label: l10n.addCard, onTap: _submit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validExpiry(String value) {
    final parts = value.split('/');
    if (parts.length != 2 || parts[0].length != 2 || parts[1].length != 2) {
      return false;
    }
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null || month < 1 || month > 12) return false;
    final now = DateTime.now();
    final fullYear = 2000 + year;
    return fullYear > now.year || (fullYear == now.year && month >= now.month);
  }
}

/// Presentation-safe result from the design form. It deliberately contains
/// no PAN, CVV, cardholder name, or provider token.
class NewCardSummary {
  const NewCardSummary({
    required this.last4,
    required this.expiry,
    required this.brand,
  });

  final String last4;
  final String expiry;
  final String brand;
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.name,
    required this.number,
    required this.expiry,
    required this.cardholderPlaceholder,
  });

  final String name;
  final String number;
  final String expiry;
  final String cardholderPlaceholder;

  @override
  Widget build(BuildContext context) {
    final shownNumber = number.isEmpty ? '••••  ••••  ••••  ••••' : number;
    return AspectRatio(
      aspectRatio: 1.68,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF102D53), Color(0xFF0B6570), Color(0xFF87D6CF)],
            stops: [0, 0.62, 1],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardChip(),
            const Spacer(),
            Directionality(
              textDirection: TextDirection.ltr,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  shownNumber,
                  key: const Key('card-preview-number'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? cardholderPlaceholder : name.toUpperCase(),
                    key: const Key('card-preview-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text(
                  expiry.isEmpty ? 'MM/YY' : expiry,
                  key: const Key('card-preview-expiry'),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 32,
    decoration: BoxDecoration(
      color: const Color(0xFFD8D7D0),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xFF7B807F)),
    ),
    child: const Icon(
      Icons.grid_view_rounded,
      size: 22,
      color: Color(0xFF68706F),
    ),
  );
}

class _CardField extends StatefulWidget {
  const _CardField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.onChanged,
    this.validator,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  State<_CardField> createState() => _CardFieldState();
}

class _CardFieldState extends State<_CardField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);
  }

  void _focusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final accent = AppColors.accent(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: focused ? 0.28 : 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? accent : Colors.white.withValues(alpha: 0.55),
              width: focused ? 1.8 : 1.2,
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            validator: widget.validator,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: AppColors.secondaryText(context)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: InputBorder.none,
              errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryField extends StatelessWidget {
  const _CountryField({
    required this.label,
    required this.hint,
    required this.value,
    required this.countries,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> countries;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: AppColors.heading(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.accent(context),
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.16),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.accent(context),
              width: 1.8,
            ),
          ),
          errorText: errorText,
        ),
        items: countries
            .map(
              (country) =>
                  DropdownMenuItem(value: country, child: Text(country)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _CardNumberFormatter extends TextInputFormatter {
  const _CardNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(
      0,
      digits.length > 19 ? 19 : digits.length,
    );
    final groups = <String>[];
    for (var i = 0; i < limited.length; i += 4) {
      final end = i + 4 > limited.length ? limited.length : i + 4;
      groups.add(limited.substring(i, end));
    }
    final text = groups.join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  const _ExpiryFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length > 4 ? 4 : digits.length);
    final text = limited.length <= 2
        ? limited
        : '${limited.substring(0, 2)}/${limited.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
