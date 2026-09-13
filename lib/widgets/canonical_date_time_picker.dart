import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'app_liquid_glass.dart';
import 'liquid_glass_surface.dart';
import 'primary_button.dart';

// ===========================================================================
// THE CANONICAL PICKER SYSTEM
//
// One visual system, four selection modes. Every date, date-of-birth and time
// surface in the app opens through the functions at the bottom of this file:
//
//   showCanonicalDatePicker        → DateTime?
//   showCanonicalDateRangePicker   → DateTimeRange?
//   showCanonicalDateOfBirthPicker → DateTime?
//   showCanonicalTimePicker        → TimeOfDay?
//
// They all share one shell — `_CanonicalPickerRoute` + `_PickerSheet` — so the
// bottom-up motion, the blurred backdrop, the real Liquid Glass sheet, the
// typography, the spacing, the Done button and the Light/Dark rules are
// defined exactly once. Only the content between the title and the button
// differs.
//
// A future screen must never build its own date or time UI. Call one of the
// four functions. See `UI_TRANSFER_PACKAGE/docs/01_DESIGN_SYSTEM_CANONICAL.md`
// §22.
// ===========================================================================

/// The sheet's corner radius — the canonical large-surface radius, applied to
/// the top corners so the sheet stays visually attached to the bottom edge.
const double _kSheetRadius = 28;

/// Backdrop blur behind an open picker. One value, shared by every mode: the
/// page stays visible and recognisable, just pushed out of focus.
const double _kBackdropBlurSigma = 12;

/// Backdrop dim behind an open picker. Deliberately lighter than Material's
/// default `black54` scrim — the point is focus, not obscuring the page.
const double _kBackdropDimOpacity = 0.28;

const Duration _kPickerMotion = Duration(milliseconds: 320);

/// The connecting band between a range's two endpoints, in Light.
///
/// Split from Dark because the two accent families do not carry equally over
/// the translucent Liquid Glass sheet: navy is a dark tint that has to work
/// harder in Light than mint does against Dark.
///
/// This was 0.16 in both themes, and on a real Android device that was
/// effectively invisible — the band sits on the same glass over a blurred
/// photo that already forced this calendar's content to white (see the palette
/// note below). Both values are device-verified; they are the canonical range
/// appearance for every range caller in the app.
const double kCanonicalRangeBandLightOpacity = 0.38;

/// The connecting band between a range's two endpoints, in Dark. See
/// [kCanonicalRangeBandLightOpacity].
const double kCanonicalRangeBandDarkOpacity = 0.27;

/// The one connecting-band colour: the canonical accent — navy in Light, mint
/// in Dark — at the device-verified alpha for that theme.
///
/// One function, every range caller. A screen cannot tune this; a range that
/// reads clearly on Hotel and faintly on Car Rental is the exact outcome this
/// exists to prevent.
Color canonicalRangeBandColor(BuildContext context) =>
    AppColors.accent(context).withValues(
      alpha: Theme.of(context).brightness == Brightness.dark
          ? kCanonicalRangeBandDarkOpacity
          : kCanonicalRangeBandLightOpacity,
    );

// ---------------------------------------------------------------------------
// Picker content palette
//
// Picker content is drawn **white in both themes**. Dark already was; Light was
// navy, and on a real Android device navy digits read as low-contrast against
// the translucent Liquid Glass sheet and the blurred photo behind it. White is
// the approved Light treatment.
//
// The same surface carries the calendar grid and the time wheel, so the same
// rule governs both: day numbers, the month/year heading, the wheel's hours,
// minutes and AM/PM.
//
// This is *content* only — the selected fill stays navy in Light and mint in
// Dark, the wheel's selection band keeps the canonical accent, and the sheet's
// own glass is untouched.
// ---------------------------------------------------------------------------

/// Normal, selectable day numbers, the month/year heading and the previous/next
/// month arrows.
Color _calendarPrimary(BuildContext context) => Colors.white;

/// Weekday labels and other supporting calendar text — one clear step below
/// primary, without becoming faint.
Color _calendarSecondary(BuildContext context) =>
    Colors.white.withValues(alpha: 0.80);

/// Dates outside the caller's bounds or refused by its predicate. Still
/// legible as a date, unmistakably not choosable.
Color _calendarDisabled(BuildContext context) => Colors.white.withValues(
  alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.40,
);

/// Time-wheel digits and AM/PM labels — hours, minutes and the meridiem
/// column alike.
///
/// The same value and the same reasoning as [_calendarPrimary]: one sheet, one
/// content colour. Delegating rather than repeating `Colors.white` is what
/// keeps the wheel from drifting away from the calendar the next time either
/// is touched. The wheel's own off-centre fade is Cupertino's and is left
/// alone, so rows away from the selection stay white and simply fade.
Color _wheelPrimary(BuildContext context) => _calendarPrimary(context);

/// The today ring, and any other accent stroke inside the calendar. Dark keeps
/// its approved mint; Light follows the white content rather than leaving a
/// lone navy ring on an otherwise white calendar.
Color _calendarAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.accent(context)
    : Colors.white;

/// Validates a completed range without moving booking rules into the picker.
/// Feature screens can retain dependent constraints such as a minimum stay or
/// a return date capped relative to the selected start.
typedef CanonicalDateRangePredicate =
    bool Function(DateTime start, DateTime end);

// ---------------------------------------------------------------------------
// Content widgets — the canonical colour treatment, unchanged
// ---------------------------------------------------------------------------

/// The app's one calendar color treatment (`Design_system_CANONICAL.md`
/// §26): navy/mint selected fill, white/deep-emerald selected content,
/// canonical secondary weekday labels, navy/mint today ring. Stock
/// `CalendarDatePicker` otherwise fills the selected day with
/// `colorScheme.primary`, the legacy brand green, not this system's navy/mint
/// selected-control fill.
///
/// It supplies §7's required content — month + year header, previous/next
/// month controls, weekday labels, the grid, the selected state and disabled
/// dates — so the canonical single-date sheet wraps this rather than
/// re-deriving a grid of its own. No day cell is a glass surface: selection is
/// a solid semantic fill (§6).
class CanonicalCalendarDatePicker extends StatelessWidget {
  const CanonicalCalendarDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
    this.selectableDayPredicate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  /// A caller's own "which days are bookable" rule, passed straight through.
  final SelectableDayPredicate? selectableDayPredicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final normalDate = _calendarPrimary(context);
    final selectedFill = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final selectedContent = isDark ? AppColors.darkOnPrimary : Colors.white;
    final disabledDate = _calendarDisabled(context);
    final accent = _calendarAccent(context);
    final weekdayColor = _calendarSecondary(context);
    return Theme(
      data: theme.copyWith(
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: Colors.transparent,
          // The month/year title, its dropdown chevron and both previous/next
          // month arrows all render from `subHeaderForegroundColor`, whose
          // framework default is `onSurface` at **0.60**. They take the
          // calendar primary instead — white, at full strength.
          subHeaderForegroundColor: normalDate,
          toggleButtonTextStyle: theme.textTheme.titleSmall?.copyWith(
            color: normalDate,
            fontWeight: FontWeight.w700,
          ),
          // Flutter applies the state-resolved foreground *to* dayStyle. A
          // strong colour alone therefore still inherited Material 3's
          // regular-weight body glyph, which looked faint on Android once it
          // was rasterised over moving Liquid Glass. Own the complete rendered
          // style here: full-strength white plus a semibold glyph in Light.
          dayStyle: theme.textTheme.bodyLarge?.copyWith(
            color: normalDate,
            fontWeight: isDark ? null : FontWeight.w600,
          ),
          weekdayStyle: theme.textTheme.bodyMedium?.copyWith(
            color: weekdayColor,
            fontWeight: FontWeight.w500,
          ),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return disabledDate;
            if (states.contains(WidgetState.selected)) return selectedContent;
            return normalDate;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return selectedFill;
            return Colors.transparent;
          }),
          dayOverlayColor: WidgetStateProperty.resolveWith((states) {
            return accent.withValues(alpha: 0.08);
          }),
          todayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return disabledDate;
            if (states.contains(WidgetState.selected)) return selectedContent;
            return normalDate;
          }),
          todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return selectedFill;
            return Colors.transparent;
          }),
          todayBorder: BorderSide(color: accent),
          yearStyle: theme.textTheme.bodyLarge?.copyWith(
            color: normalDate,
            fontWeight: isDark ? null : FontWeight.w600,
          ),
          yearForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return selectedContent;
            return normalDate;
          }),
          yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return selectedFill;
            return Colors.transparent;
          }),
        ),
      ),
      child: CalendarDatePicker(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        onDateChanged: onDateChanged,
        selectableDayPredicate: selectableDayPredicate,
      ),
    );
  }
}

/// The app's one wheel time-picker color treatment: canonical **white** digits
/// in both themes instead of the ambient Cupertino default, which reads too
/// low-contrast against the page showing through the wheel's own transparent
/// background, plus a canonical selection band.
///
/// The caller is expected to place this inside a [GlassLayer.embedded]
/// backing (`Design_system_CANONICAL.md` §9/§10) rather than directly on a
/// bare glass surface, since the wheel paints no background of its own. No
/// hour or minute row is its own glass surface (§6).
class CanonicalCupertinoDatePicker extends StatelessWidget {
  const CanonicalCupertinoDatePicker({
    super.key,
    required this.mode,
    required this.initialDateTime,
    required this.onDateTimeChanged,
    this.use24hFormat = false,
  });

  final CupertinoDatePickerMode mode;
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;
  final bool use24hFormat;

  @override
  Widget build(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // One style covers every wheel column — hours, minutes and AM/PM — so the
    // meridiem labels cannot end up a different colour from the digits beside
    // them.
    final textColor = _wheelPrimary(context);
    return CupertinoTheme(
      data: cupertinoTheme.copyWith(
        textTheme: cupertinoTheme.textTheme.copyWith(
          dateTimePickerTextStyle: cupertinoTheme
              .textTheme
              .dateTimePickerTextStyle
              .copyWith(
                color: textColor,
                // Light only: the approved extra weight, unchanged. The wheel
                // fades off-centre rows on its own, so the centred value is
                // the one that gains, which is the intent. Dark is already
                // approved and keeps its existing weight.
                fontWeight: isDark ? null : FontWeight.w600,
              ),
        ),
      ),
      child: CupertinoDatePicker(
        mode: mode,
        backgroundColor: Colors.transparent,
        initialDateTime: initialDateTime,
        use24hFormat: use24hFormat,
        onDateTimeChanged: onDateTimeChanged,
        // The selected band, in the canonical accent rather than Cupertino's
        // ambient grey. A translucent wash, not the solid navy/mint used for a
        // calendar day: the digits scroll *through* this band, so a solid fill
        // would leave unselected digits sitting on it at the moment of
        // transition with no way to restyle them.
        //
        // One band across the whole wheel: the columns are capped at the outer
        // edges only, so hours and minutes read as a single selected row.
        selectionOverlayBuilder:
            (context, {required columnCount, required selectedIndex}) =>
                _WheelSelectionBand(
                  color: AppColors.accent(context),
                  capStart: selectedIndex == 0,
                  capEnd: selectedIndex == columnCount - 1,
                ),
      ),
    );
  }
}

class _WheelSelectionBand extends StatelessWidget {
  const _WheelSelectionBand({
    required this.color,
    this.capStart = true,
    this.capEnd = true,
  });

  final Color color;

  /// Whether this column is the wheel's leading/trailing edge. Only the outer
  /// edges are rounded, so the separate columns read as one continuous band.
  final bool capStart;
  final bool capEnd;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(12);
    return Container(
      margin: EdgeInsetsDirectional.only(
        start: capStart ? 8 : 0,
        end: capEnd ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadiusDirectional.horizontal(
          start: capStart ? radius : Radius.zero,
          end: capEnd ? radius : Radius.zero,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The shared shell
// ---------------------------------------------------------------------------

/// The one modal backdrop for the canonical picker family (§4/§24): a blur and
/// a light dim over the page, animated in with the sheet.
///
/// **Layering matters here.** This is a *sibling* of the glass sheet inside the
/// route's `Stack`, never an ancestor of it. A real `OCLiquidGlass` surface
/// pushes its own `BackdropFilterLayer`, and putting it inside another filter's
/// offscreen layer is what produced the black-band corruption documented in
/// `07_DESIGN_EXCEPTIONS.md` §19. As siblings, the sheet's glass simply samples
/// the already-blurred page behind it, which is exactly the intended look.
///
/// Scoped to this picker family — it is deliberately not applied to every
/// dialog in the app.
class _PickerBackdrop extends StatelessWidget {
  const _PickerBackdrop({required this.animation, required this.onTap});

  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _kBackdropBlurSigma,
            sigmaY: _kBackdropBlurSigma,
          ),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: _kBackdropDimOpacity),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// The canonical picker sheet: one real Liquid Glass surface, rounded top
/// corners, attached to the bottom edge, holding an optional title, the mode's
/// content, and the Done button.
///
/// The sheet is the *only* real glass in the picker. Its content is drawn with
/// solid semantic fills and embedded backings — never a second shader per day,
/// hour or minute cell (§6).
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.animation,
    required this.title,
    required this.content,
    required this.onDone,
    this.doneEnabled = true,
  });

  final Animation<double> animation;
  final String? title;
  final Widget content;
  final VoidCallback onDone;
  final bool doneEnabled;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;
    setState(() {
      _dragOffset = (_dragOffset + details.primaryDelta!).clamp(0.0, 600.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    // Swipe down to dismiss — a flick, or dragged far enough to read as
    // intent. Dismissing never commits a value (§15).
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 700 || _dragOffset > 120) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    // The sheet never grows past most of the screen; its content scrolls
    // instead. Scrolling inherits `AppScrollBehavior` from the app, so no
    // Android stretch overscroll is introduced around this real glass (§21).
    final maxHeight = media.size.height * 0.86;

    final sheet = Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: media.viewInsets.bottom + media.padding.bottom + 12,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AppLiquidGlass(
          useCanonicalGlass: true,
          borderRadius: _kSheetRadius,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DragHandle(),
              if (widget.title != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.heading(context),
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Flexible(child: SingleChildScrollView(child: widget.content)),
              const SizedBox(height: 12),
              PrimaryButton(
                label: l10n.done,
                onTap: widget.doneEnabled ? widget.onDone : null,
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: widget.animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: sheet,
        ),
      ),
    );
  }
}

/// The grab handle: an affordance for the swipe-down dismissal, in the
/// canonical secondary tone.
class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.secondaryTextV3(context).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The route every canonical picker opens on.
///
/// A `PopupRoute` rather than `showModalBottomSheet`, for one reason: the
/// backdrop. `ModalBottomSheetRoute` only exposes a flat `barrierColor`, and
/// §4 asks for a blurred, dimmed, still-visible page. Owning the route gives
/// the blur, the bottom-up motion and the barrier as one animated unit — and
/// keeps the barrier a sibling of the glass sheet rather than its parent.
///
/// Android back and a tap outside both dismiss without committing (§15).
class _CanonicalPickerRoute<T> extends PopupRoute<T> {
  _CanonicalPickerRoute({required this.builder, required this.barrierLabel});

  final Widget Function(BuildContext context, Animation<double> animation)
  builder;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null; // `_PickerBackdrop` draws it, blurred.

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => _kPickerMotion;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Stack(
      children: [
        // Sibling, not ancestor — see `_PickerBackdrop`.
        _PickerBackdrop(
          animation: animation,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: builder(context, animation),
        ),
      ],
    );
  }
}

Future<T?> _showPicker<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, Animation<double> animation)
  builder,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    _CanonicalPickerRoute<T>(
      builder: builder,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// The canonical single-date picker.
///
/// Returns the confirmed date, or `null` if the sheet was dismissed — a
/// dismissal never commits a selection.
Future<DateTime?> showCanonicalDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
  SelectableDayPredicate? selectableDayPredicate,
}) {
  final clamped = initialDate.isBefore(firstDate)
      ? firstDate
      : (initialDate.isAfter(lastDate) ? lastDate : initialDate);
  return _showPicker<DateTime>(
    context,
    builder: (context, animation) {
      var selected = clamped;
      return StatefulBuilder(
        builder: (context, setSheetState) => _PickerSheet(
          animation: animation,
          title: title,
          content: CanonicalCalendarDatePicker(
            initialDate: selected,
            firstDate: firstDate,
            lastDate: lastDate,
            selectableDayPredicate: selectableDayPredicate,
            onDateChanged: (value) => setSheetState(() => selected = value),
          ),
          onDone: () => Navigator.of(context).pop(selected),
        ),
      );
    },
  );
}

/// The canonical date-of-birth picker.
///
/// The same sheet and the same calendar as [showCanonicalDatePicker] — there is
/// no separate numeric age wheel (§10). The caller keeps storing whatever it
/// already stores; this only selects a birth date. Use [ageOn] to derive an
/// age from the result.
Future<DateTime?> showCanonicalDateOfBirthPicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
}) {
  return showCanonicalDatePicker(
    context: context,
    // Opening on today would be an impossible birth date, so a caller that has
    // no value yet lands on the upper bound it chose instead.
    initialDate: initialDate ?? lastDate,
    firstDate: firstDate,
    lastDate: lastDate,
    title: title,
  );
}

/// The canonical date-range picker — check-in/check-out, departure/return,
/// pick-up/drop-off.
///
/// Returns the confirmed range, or `null` on dismissal. Done stays disabled
/// until both ends are chosen, so a half-made range can never be committed.
Future<DateTimeRange?> showCanonicalDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialRange,
  DateTime? initialStart,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
  SelectableDayPredicate? selectableDayPredicate,
  SelectableDayPredicate? selectableStartDayPredicate,
  CanonicalDateRangePredicate? selectableRangePredicate,
}) {
  assert(
    initialRange == null || initialStart == null,
    'Pass either initialRange or initialStart, not both.',
  );
  return _showPicker<DateTimeRange>(
    context,
    builder: (context, animation) {
      DateTime? start = initialRange?.start ?? initialStart;
      DateTime? end = initialRange?.end;
      return StatefulBuilder(
        builder: (context, setSheetState) => _PickerSheet(
          animation: animation,
          title: title,
          doneEnabled: start != null && end != null,
          content: _CanonicalRangeCalendar(
            start: start,
            end: end,
            firstDate: firstDate,
            lastDate: lastDate,
            selectableDayPredicate: selectableDayPredicate,
            selectableStartDayPredicate: selectableStartDayPredicate,
            selectableRangePredicate: selectableRangePredicate,
            onChanged: (nextStart, nextEnd) => setSheetState(() {
              start = nextStart;
              end = nextEnd;
            }),
          ),
          onDone: () {
            final s = start;
            final e = end;
            if (s == null || e == null) return;
            Navigator.of(context).pop(DateTimeRange(start: s, end: e));
          },
        ),
      );
    },
  );
}

/// One end of a two-field stay, chosen on its own.
///
/// This is the picker a **paired** flow uses when each date has its own visible
/// field and its own step — Hotel's Check-in and Check-out. It is a
/// *single-date* picker: it returns one `DateTime`, and Done is reachable as
/// soon as that one date exists.
///
/// The difference from [showCanonicalDatePicker] is what it can *show*. Pass
/// the other end of the stay as [stayStart] and the calendar opens with that
/// date already selected; once the user picks this field's date, the continuous
/// path between the two appears immediately — the same shared range rendering
/// every other range caller uses, with no Hotel-specific paint.
///
/// - **First field** (Check-in): leave [stayStart] null. Every tap moves the
///   single selected date. The user is never asked for the second date.
/// - **Second field** (Check-out): pass the first field's value as [stayStart].
///   It renders selected and immovable; taps set this field's date, validated
///   by [selectableRangePredicate] so an invalid pairing is untappable.
///
/// Returns the confirmed date, or `null` on dismissal — dismissing writes
/// nothing, exactly as elsewhere in the picker family.
Future<DateTime?> showCanonicalStayDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? stayStart,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
  SelectableDayPredicate? selectableDayPredicate,
  CanonicalDateRangePredicate? selectableRangePredicate,
}) {
  final pickingEnd = stayStart != null;
  return _showPicker<DateTime>(
    context,
    builder: (context, animation) {
      DateTime? start = stayStart ?? initialDate;
      DateTime? end = pickingEnd ? initialDate : null;
      return StatefulBuilder(
        builder: (context, setSheetState) => _PickerSheet(
          animation: animation,
          title: title,
          doneEnabled: pickingEnd ? end != null : start != null,
          content: _CanonicalRangeCalendar(
            start: start,
            end: end,
            firstDate: firstDate,
            lastDate: lastDate,
            mode: pickingEnd
                ? _RangeSelectionMode.endOnly
                : _RangeSelectionMode.startOnly,
            selectableDayPredicate: selectableDayPredicate,
            selectableRangePredicate: selectableRangePredicate,
            onChanged: (nextStart, nextEnd) => setSheetState(() {
              start = nextStart;
              end = nextEnd;
            }),
          ),
          onDone: () {
            final value = pickingEnd ? end : start;
            if (value == null) return;
            Navigator.of(context).pop(value);
          },
        ),
      );
    },
  );
}

/// The canonical time picker — the same sheet, a wheel instead of a calendar.
///
/// 12h/24h follows the platform/locale setting the app already honours
/// (`MediaQuery.alwaysUse24HourFormatOf`), exactly as before.
Future<TimeOfDay?> showCanonicalTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? title,
}) {
  return _showPicker<TimeOfDay>(
    context,
    builder: (context, animation) {
      // The date part is a fixed carrier for the wheel; only h:m is read back.
      var selected = DateTime(2020, 1, 1, initialTime.hour, initialTime.minute);
      return _PickerSheet(
        animation: animation,
        title: title,
        content: AppLiquidGlass(
          useCanonicalGlass: true,
          // Embedded, never a second real shader inside the sheet (§6).
          layer: GlassLayer.embedded,
          borderRadius: 20,
          child: SizedBox(
            height: 220,
            child: CanonicalCupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: selected,
              use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              onDateTimeChanged: (value) => selected = value,
            ),
          ),
        ),
        onDone: () => Navigator.of(
          context,
        ).pop(TimeOfDay(hour: selected.hour, minute: selected.minute)),
      );
    },
  );
}

/// Age in whole years on [asOf] (defaults to today) for someone born on
/// [birthDate].
///
/// Month- and day-aware: someone whose birthday has not happened yet this year
/// is still the younger age. Subtracting birth year from current year is wrong
/// for roughly half the calendar and is what this exists to prevent.
int ageOn(DateTime birthDate, {DateTime? asOf}) {
  final now = asOf ?? DateTime.now();
  var age = now.year - birthDate.year;
  final hadBirthday =
      now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hadBirthday) age--;
  return age;
}

// ---------------------------------------------------------------------------
// Range calendar
// ---------------------------------------------------------------------------

/// How taps are interpreted by [_CanonicalRangeCalendar].
///
/// One grid, one set of range visuals, three interaction shapes — so a paired
/// flow that picks its two dates in two separate steps still renders the same
/// continuous path as a flow that picks both in one sheet.
enum _RangeSelectionMode {
  /// Two taps in one sheet: the first sets the start, the second the end.
  /// Explore Tours and Car Rental use this.
  range,

  /// Every tap moves the **start**; the end is never set here. Used by a
  /// first-of-pair field (Hotel Check-in), which is a single-date step and must
  /// never demand a second date before Done.
  startOnly,

  /// The start is fixed and already drawn as selected; every tap sets the
  /// **end**, and the path from the fixed start appears immediately. Used by a
  /// second-of-pair field (Hotel Check-out).
  endOnly,
}

/// A month grid with range semantics, styled to match
/// [CanonicalCalendarDatePicker] exactly: same month/year header, same
/// previous/next controls, same weekday labels, same solid selected fill.
///
/// Flutter's own range picker is a full-screen dialog with no embeddable
/// widget, and it has no theme hook for the in-between span, so the grid is
/// drawn here. Every cell is a plain `Material`/`InkWell` over a solid or
/// translucent fill — no cell is a glass surface (§6/§19).
class _CanonicalRangeCalendar extends StatefulWidget {
  const _CanonicalRangeCalendar({
    required this.start,
    required this.end,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.mode = _RangeSelectionMode.range,
    this.selectableDayPredicate,
    this.selectableStartDayPredicate,
    this.selectableRangePredicate,
  });

  final DateTime? start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(DateTime? start, DateTime? end) onChanged;
  final _RangeSelectionMode mode;
  final SelectableDayPredicate? selectableDayPredicate;
  final SelectableDayPredicate? selectableStartDayPredicate;
  final CanonicalDateRangePredicate? selectableRangePredicate;

  @override
  State<_CanonicalRangeCalendar> createState() =>
      _CanonicalRangeCalendarState();
}

class _CanonicalRangeCalendarState extends State<_CanonicalRangeCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    // Open on whichever end this step is actually editing, so the user does
    // not land a month away from the date they came to change.
    final anchor = switch (widget.mode) {
      _RangeSelectionMode.endOnly =>
        widget.end ?? widget.start ?? widget.firstDate,
      _ => widget.start ?? widget.firstDate,
    };
    _month = DateTime(anchor.year, anchor.month);
  }

  bool get _canGoBack =>
      _month.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));

  bool get _canGoForward =>
      _month.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  void _step(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  void _tap(DateTime day) {
    if (!_canTap(day)) return;
    switch (widget.mode) {
      case _RangeSelectionMode.startOnly:
        // A single-date step. Re-tapping simply moves the date; the end is
        // never introduced here, so Done is reachable after one tap.
        widget.onChanged(day, null);
        return;
      case _RangeSelectionMode.endOnly:
        // The start is fixed by the field that already holds it. Every tap
        // sets the end, and the path appears the moment it lands.
        widget.onChanged(widget.start, day);
        return;
      case _RangeSelectionMode.range:
        break;
    }
    final start = widget.start;
    final end = widget.end;
    // First tap sets the start; second sets the end. A tap before the current
    // start, or a tap once a full range exists, starts a new range — the same
    // convention Flutter's own range picker uses.
    if (start == null || end != null || day.isBefore(start)) {
      widget.onChanged(day, null);
      return;
    }
    widget.onChanged(start, day);
  }

  bool _globallySelectable(DateTime day) {
    final date = DateUtils.dateOnly(day);
    return !date.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
        !date.isAfter(DateUtils.dateOnly(widget.lastDate)) &&
        (widget.selectableDayPredicate?.call(date) ?? true);
  }

  bool _selectableAsStart(DateTime day) =>
      _globallySelectable(day) &&
      (widget.selectableStartDayPredicate?.call(DateUtils.dateOnly(day)) ??
          true);

  bool _canTap(DateTime day) {
    final date = DateUtils.dateOnly(day);
    final start = widget.start == null
        ? null
        : DateUtils.dateOnly(widget.start!);
    switch (widget.mode) {
      case _RangeSelectionMode.startOnly:
        return _selectableAsStart(date);
      case _RangeSelectionMode.endOnly:
        // The caller's range rule is what keeps an invalid end — a Hotel
        // check-out on or before check-in, say — untappable rather than merely
        // rejected afterwards.
        if (start == null) return _selectableAsStart(date);
        return _globallySelectable(date) &&
            (widget.selectableRangePredicate?.call(start, date) ?? true);
      case _RangeSelectionMode.range:
        break;
    }
    if (start == null || widget.end != null || date.isBefore(start)) {
      return _selectableAsStart(date);
    }
    return _globallySelectable(date) &&
        (widget.selectableRangePredicate?.call(start, date) ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    final heading = _calendarPrimary(context);
    final accent = _calendarAccent(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _canGoBack ? () => _step(-1) : null,
              icon: const Icon(Icons.chevron_left),
              color: accent,
              disabledColor: accent.withValues(alpha: 0.3),
              tooltip: materialL10n.previousMonthTooltip,
            ),
            Expanded(
              child: Text(
                materialL10n.formatMonthYear(_month),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: _canGoForward ? () => _step(1) : null,
              icon: const Icon(Icons.chevron_right),
              color: accent,
              disabledColor: accent.withValues(alpha: 0.3),
              tooltip: materialL10n.nextMonthTooltip,
            ),
          ],
        ),
        _WeekdayLabels(),
        const SizedBox(height: 4),
        _MonthGrid(
          month: _month,
          start: widget.start,
          end: widget.end,
          isEnabled: _canTap,
          onTap: _tap,
        ),
      ],
    );
  }
}

class _WeekdayLabels extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    final firstDayOfWeek = materialL10n.firstDayOfWeekIndex;
    final labels = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final index = (firstDayOfWeek + i) % 7;
      labels.add(
        Expanded(
          child: Center(
            child: Text(
              materialL10n.narrowWeekdays[index],
              style: TextStyle(
                color: _calendarSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: labels);
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.start,
    required this.end,
    required this.isEnabled,
    required this.onTap,
  });

  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final bool Function(DateTime day) isEnabled;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateUtils.firstDayOffset(
      month.year,
      month.month,
      materialL10n,
    );

    final cells = <Widget>[
      for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          start: start,
          end: end,
          enabled: isEnabled(DateTime(month.year, month.month, day)),
          onTap: onTap,
        ),
    ];

    // No padding and no cross/main axis spacing: the range band is painted
    // edge to edge inside each cell, so any gap here would break the path into
    // dashes. Day cells keep their breathing room from the endpoint diameter
    // being smaller than the cell (see `_DayCell`), not from grid spacing.
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      children: cells,
    );
  }
}

/// One day in the range calendar.
///
/// The range reads as a single continuous path, not a row of separate circles:
///
/// ```
///   ●━━━━━━━━━━━━━━●
///  12  13  14  15  16
/// ```
///
/// Each cell paints its own half-cells of the connecting band, so two adjacent
/// days' bands meet exactly at the shared edge with no seam:
///
/// - **start** — trailing half banded, solid endpoint on top
/// - **middle** — both halves banded, no endpoint
/// - **end** — leading half banded, solid endpoint on top
/// - **start == end** — endpoint only, no band
///
/// Leading/trailing are *directional*, so the path mirrors correctly in Arabic
/// and Kurdish. At a week boundary the band simply stops at the row edge and
/// resumes at the start of the next row, which is what makes a multi-week range
/// still read as one selection.
///
/// Nothing here is a glass surface — the sheet is the only real glass. These
/// are painted semantic fills (§16).
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.start,
    required this.end,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final DateTime? start;
  final DateTime? end;
  final bool enabled;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    // Normalised, so a caller's `DateTimeRange` carrying a time component
    // cannot shift which days count as inside the span.
    final day = DateUtils.dateOnly(date);
    final rangeStart = start == null ? null : DateUtils.dateOnly(start!);
    final rangeEnd = end == null ? null : DateUtils.dateOnly(end!);

    final isStart = rangeStart != null && day == rangeStart;
    final isEnd = rangeEnd != null && day == rangeEnd;
    final inSpan =
        rangeStart != null &&
        rangeEnd != null &&
        day.isAfter(rangeStart) &&
        day.isBefore(rangeEnd);
    final isToday = DateUtils.isSameDay(day, DateTime.now());

    // A complete range is the only thing that draws a band. A lone start point
    // has nothing to connect to yet.
    final hasSpan = rangeStart != null && rangeEnd != null;
    final isEndpoint = isStart || isEnd;
    final bandLeading = hasSpan && (inSpan || (isEnd && !isStart));
    final bandTrailing = hasSpan && (inSpan || (isStart && !isEnd));

    final selectedFill = AppColors.compactSelectedFill(context);
    final selectedContent = AppColors.compactSelectedContent(context);
    final accent = _calendarAccent(context);
    final normal = _calendarPrimary(context);
    // The connecting band keeps the canonical accent — navy in Light, mint in
    // Dark — not the white content colour, so the path still reads as a tinted
    // span under white day numbers. One value for every range caller.
    final bandColor = canonicalRangeBandColor(context);

    final Color foreground;
    if (isEndpoint) {
      foreground = selectedContent;
    } else if (inSpan) {
      foreground = normal;
    } else {
      foreground = enabled ? normal : _calendarDisabled(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The endpoint disc, sized from the cell so it stays circular and
        // leaves a little air on every screen width.
        final diameter =
            (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight) -
            4;

        return Stack(
          alignment: Alignment.center,
          children: [
            // The band strip, exactly as tall as the endpoint so the path is
            // one unbroken bar. Row is directional: child 0 is the leading
            // half in LTR and the trailing half in RTL, which is what mirrors
            // the path correctly.
            //
            // `stretch` is load-bearing, not cosmetic. A `ColoredBox` has no
            // child, so under the default `CrossAxisAlignment.center` it is
            // handed *loose* vertical constraints and collapses to
            // `constraints.smallest` — a strip the full half-cell wide and
            // zero pixels tall. It still exists in the widget tree, so a test
            // that counts `ColoredBox`es sees a complete path while the device
            // paints nothing at all between the endpoints. Stretch gives each
            // half a tight height, which is what actually puts the band on
            // screen. Keep it, and keep the geometry test that pins the
            // painted size rather than the widget count.
            if (bandLeading || bandTrailing)
              SizedBox(
                height: diameter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: bandLeading
                          ? ColoredBox(color: bandColor)
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: bandTrailing
                          ? ColoredBox(color: bandColor)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            // The solid endpoint, drawn over the band so the path terminates
            // in a strong disc at each end.
            if (isEndpoint)
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  color: selectedFill,
                  shape: BoxShape.circle,
                ),
              ),
            // Today keeps its accent ring, but only while it is not itself an
            // endpoint or inside the span — otherwise the ring competes with
            // the path.
            if (isToday && !isEndpoint && !inSpan)
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent),
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? () => onTap(day) : null,
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: isEndpoint
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
