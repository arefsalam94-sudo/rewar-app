import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/car_rental.dart';
import '../theme/app_colors.dart';
import 'glass_panel.dart';
import 'rental_car_parts.dart';

/// Building blocks for the Car Rental Details screen.
///
/// Kept beside [rental_car_parts.dart] rather than inside the screen so the
/// screen file stays a layout, and so a future Hotel/Tour details page can
/// reuse the same section header and option rows.

/// The "circle icon + title" line that opens every card on the details screen.
class RentalSectionHeader extends StatelessWidget {
  const RentalSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;

  /// Optional end-aligned widget — the company badge on the Car details card.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      children: [
        RentalCircleIcon(icon: icon, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.heading(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}

/// Swipeable gallery of vehicle photos with page dots.
///
/// Renders however many photos the vehicle carries: a single photo shows no
/// dots at all, and a long gallery keeps the dot row bounded (see
/// [RentalCarouselDots]) rather than overflowing the card.
class RentalImageCarousel extends StatefulWidget {
  const RentalImageCarousel({
    super.key,
    required this.images,
    required this.vehicleName,
    this.aspectRatio = 16 / 10,
  });

  final List<String> images;
  final String vehicleName;
  final double aspectRatio;

  @override
  State<RentalImageCarousel> createState() => _RentalImageCarouselState();
}

class _RentalImageCarouselState extends State<RentalImageCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final images = widget.images;
    // A vehicle with no photography at all still gets a card of the right
    // shape, filled by the image widget's own fallback glyph.
    final count = images.isEmpty ? 1 : images.length;

    return Semantics(
      container: true,
      label: l10n.carGalleryLabel(widget.vehicleName),
      child: GlassPanel(
        borderRadius: 28,
        padding: EdgeInsets.zero,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => PageView.builder(
                    controller: _controller,
                    itemCount: count,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) => RentalVehicleImage(
                      asset: images.isEmpty ? '' : images[index],
                      // Decode to the card's own width rather than the full
                      // frame — the details hero is still only phone-wide.
                      cacheWidth:
                          (constraints.maxWidth *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                    ),
                  ),
                ),
              ),
              if (count > 1)
                PositionedDirectional(
                  end: 16,
                  bottom: 14,
                  child: Semantics(
                    liveRegion: true,
                    label: l10n.carPhotoPosition(_index + 1, count),
                    excludeSemantics: true,
                    child: RentalCarouselDots(count: count, current: _index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page dots for a rental carousel, matching the Car Rental screen's featured
/// carousel. The row is capped so a large gallery cannot push the dots past
/// the edge of the card.
class RentalCarouselDots extends StatelessWidget {
  const RentalCarouselDots({
    super.key,
    required this.count,
    required this.current,
    this.maxDots = 7,
  });

  final int count;
  final int current;
  final int maxDots;

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(0, maxDots);
    // With more photos than dots, the last dot stands in for "and the rest",
    // so the active dot never disappears off the end of the row.
    final active = current >= shown ? shown - 1 : current;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < shown; index++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == active ? 10 : 8,
            height: index == active ? 10 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.48),
              border: index == active
                  ? Border.all(color: AppColors.accent(context), width: 1)
                  : null,
            ),
          ),
          if (index != shown - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

/// One add-on row: title, per-day price, and the control on the end.
///
/// A single widget covers both selection types so the two rows keep identical
/// metrics, and so adding a third selection type later is a change in one
/// place.
class RentalOptionRow extends StatelessWidget {
  const RentalOptionRow({
    super.key,
    required this.extra,
    required this.currencyCode,
    required this.quantity,
    required this.onChanged,
  });

  final RentalExtra extra;
  final String currencyCode;

  /// 0 means "not taken" for both selection types.
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final name = extra.name.forLanguage(language);
    final unitPrice = l10n.carPricePerDay(
      rentalFormatAmount(extra.pricePerDay, currencyCode),
    );
    // A quantity above one restates the maths on the row itself, so the price
    // the user is agreeing to is never left implicit.
    final priceLabel =
        extra.selection == RentalExtraSelection.quantity && quantity > 1
        ? l10n.carExtraTimesQuantity(unitPrice, quantity)
        : unitPrice;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          priceLabel,
          style: TextStyle(
            color: AppColors.secondaryText(context),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: switch (extra.selection) {
        RentalExtraSelection.checkbox => _CheckboxOption(
          name: name,
          semanticsPrice: priceLabel,
          selected: quantity > 0,
          onChanged: (value) => onChanged(value ? 1 : 0),
          label: label,
        ),
        RentalExtraSelection.quantity => _QuantityOption(
          extra: extra,
          name: name,
          semanticsPrice: priceLabel,
          quantity: quantity,
          onChanged: onChanged,
          label: label,
        ),
      },
    );
  }
}

class _CheckboxOption extends StatelessWidget {
  const _CheckboxOption({
    required this.name,
    required this.semanticsPrice,
    required this.selected,
    required this.onChanged,
    required this.label,
  });

  final String name;
  final String semanticsPrice;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final Widget label;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    label: '$name, $semanticsPrice',
    excludeSemantics: true,
    child: InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 8),
          // The framework checkbox carries the theme's selected/unselected
          // tokens and its own 48dp target, and it is what the Car Rental
          // search card and Terms screen already use.
          Checkbox(
            value: selected,
            onChanged: (value) => onChanged(value ?? false),
          ),
        ],
      ),
    ),
  );
}

class _QuantityOption extends StatelessWidget {
  const _QuantityOption({
    required this.extra,
    required this.name,
    required this.semanticsPrice,
    required this.quantity,
    required this.onChanged,
    required this.label,
  });

  final RentalExtra extra;
  final String name;
  final String semanticsPrice;
  final int quantity;
  final ValueChanged<int> onChanged;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canDecrease = quantity > extra.minQuantity;
    final canIncrease = quantity < extra.maxQuantity;

    return Semantics(
      label: '$name, $semanticsPrice',
      value: '$quantity',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.remove,
            semanticsLabel: l10n.carDecreaseQuantity(name),
            onTap: canDecrease ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.heading(context),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            semanticsLabel: l10n.carIncreaseQuantity(name),
            onTap: canIncrease ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Round stepper button, matching the Flight Ticketing passenger stepper.
///
/// A null [onTap] is the disabled state: the ring and glyph both drop to the
/// disabled alpha, and the button stops reporting itself as enabled to
/// assistive tech — so the limit is never signalled by colour alone.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticsLabel,
    this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticsLabel,
      child: IconButton.outlined(
        onPressed: onTap,
        icon: Icon(icon),
        color: accent,
        disabledColor: accent.withValues(alpha: 0.40),
        style: IconButton.styleFrom(
          side: BorderSide(
            color: onTap == null ? accent.withValues(alpha: 0.28) : accent,
          ),
        ),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );
  }
}

/// A label/value line in the Pick-Up / Drop-Off and Rental Conditions cards.
///
/// Wraps to a second line rather than overflowing, which is what keeps a long
/// branch name inside the card on a small phone.
class RentalDetailRow extends StatelessWidget {
  const RentalDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final Widget value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.accent(context)),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "icon + text" pair used for the date, time and location values.
class RentalValueChip extends StatelessWidget {
  const RentalValueChip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: AppColors.accent(context)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 3,
          style: TextStyle(
            color: AppColors.heading(context),
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
