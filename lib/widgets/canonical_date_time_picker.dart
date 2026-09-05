import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's one calendar color treatment (`Design_system_CANONICAL.md`
/// §26): navy/mint selected fill, white/deep-emerald selected content,
/// canonical secondary weekday labels, navy/mint today ring. First proven on
/// Flight Ticketing; every other screen that needs a calendar reuses this
/// instead of re-deriving its own copy — stock `CalendarDatePicker`
/// otherwise fills the selected day with `colorScheme.primary`, the legacy
/// brand green, not this system's navy/mint selected-control fill.
class CanonicalCalendarDatePicker extends StatelessWidget {
  const CanonicalCalendarDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final normalDate = AppColors.heading(context);
    final selectedFill = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final selectedContent = isDark ? AppColors.darkOnPrimary : Colors.white;
    final disabledDate = normalDate.withValues(alpha: 0.35);
    final accent = AppColors.accent(context);
    return Theme(
      data: theme.copyWith(
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: Colors.transparent,
          weekdayStyle: TextStyle(color: AppColors.secondaryTextV3(context)),
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
            if (states.contains(WidgetState.selected)) return selectedContent;
            return normalDate;
          }),
          todayBorder: BorderSide(color: accent),
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
      ),
    );
  }
}

/// The app's one wheel time-picker color treatment: canonical navy/white
/// digits instead of the ambient Cupertino default, which reads too
/// low-contrast against the page showing through the wheel's own
/// transparent background. Only the digit color is overridden — every other
/// `dateTimePickerTextStyle` property (size, weight) is left at whatever the
/// framework already resolves, and the wheel's own geometry is untouched.
///
/// The caller is expected to place this inside a [GlassLayer.embedded]
/// backing (`Design_system_CANONICAL.md` §9/§10) rather than directly on a
/// bare glass surface, since the wheel paints no background of its own.
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
    final textColor = AppColors.heading(context);
    return CupertinoTheme(
      data: cupertinoTheme.copyWith(
        textTheme: cupertinoTheme.textTheme.copyWith(
          dateTimePickerTextStyle: cupertinoTheme.textTheme.dateTimePickerTextStyle
              .copyWith(color: textColor),
        ),
      ),
      child: CupertinoDatePicker(
        mode: mode,
        backgroundColor: Colors.transparent,
        initialDateTime: initialDateTime,
        use24hFormat: use24hFormat,
        onDateTimeChanged: onDateTimeChanged,
      ),
    );
  }
}
