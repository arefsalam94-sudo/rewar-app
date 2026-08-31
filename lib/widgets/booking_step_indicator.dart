import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_panel.dart';

/// The multi-step flow indicator, per `DESIGN_SYSTEM.md` section 14.
///
/// One circle per step with its number inside, connector dots between, and the
/// step label beneath. Three visually distinct states:
///
/// * **completed** — solid accent fill with a check glyph in place of the
///   number; its connector to the next step is drawn in the accent colour
/// * **active** — accent ring, accent number and label
/// * **upcoming** — neutral on-glass, no ring and no fill
///
/// The check glyph is what separates completed from active without relying on
/// colour alone (section 20's rule that state must not be colour-only).
///
/// The row mirrors in RTL like any other content order (section 21) — step 1
/// sits on the reading-start side. It is presentational only: there are no tap
/// handlers, because a step indicator reports position rather than navigating
/// past input that has not been validated.
class BookingStepIndicator extends StatelessWidget {
  const BookingStepIndicator({
    super.key,
    required this.labels,
    required this.activeIndex,
    this.dark,
  });

  /// One label per step, already localized.
  final List<String> labels;

  /// Zero-based. Every step before it reads as completed; values outside the
  /// range simply leave no step emphasized rather than throwing on a screen the
  /// user is looking at.
  final int activeIndex;

  final bool? dark;

  /// `DESIGN_SYSTEM.md` 14: circle diameter 56px.
  static const double circleSize = 56;

  /// 5 dots per gap, 4px each.
  static const int dotsPerGap = 5;
  static const double dotSize = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;

    return GlassPanel(
      dark: dark,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            // Both the steps and the gaps flex, so three labels of any length
            // share the width instead of a fixed column overflowing a 320dp
            // phone.
            if (i > 0)
              Expanded(
                flex: 2,
                // The run leading into a reached step is itself complete.
                child: _Connector(dark: isDark, done: i <= activeIndex),
              ),
            Expanded(
              flex: 3,
              child: _Step(
                number: i + 1,
                label: labels[i],
                state: i < activeIndex
                    ? _StepState.complete
                    : i == activeIndex
                    ? _StepState.active
                    : _StepState.upcoming,
                dark: isDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { complete, active, upcoming }

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.label,
    required this.state,
    required this.dark,
  });

  final int number;
  final String label;
  final _StepState state;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // `step-active-ring` / `step-complete-fill` — primary-container, not the
    // navy `action` token. See AppColors.stepAccent for why the two differ.
    final accent = AppColors.stepAccent(context);
    final neutral = AppColors.heading(context);
    final complete = state == _StepState.complete;
    final active = state == _StepState.active;
    final upcoming = state == _StepState.upcoming;

    return Semantics(
      // Reads as "1. Traveler Info", with completed/current conveyed by the
      // checked and selected flags rather than by colour.
      label: '$number. $label',
      selected: active,
      checked: complete,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: BookingStepIndicator.circleSize,
            height: BookingStepIndicator.circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: complete
                  ? accent
                  : (dark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.55)),
              border: Border.all(
                color: upcoming
                    ? (dark
                          ? Colors.white.withValues(
                              alpha: AppColors.darkBorderOpacity,
                            )
                          : Colors.white.withValues(alpha: 0.65))
                    : accent,
                width: active ? 2 : 1,
              ),
            ),
            child: complete
                ? Icon(
                    Icons.check_rounded,
                    size: 28,
                    color: AppColors.onStepAccent(context),
                  )
                : Text(
                    '$number',
                    // A step number is a position, not a measurement sequence,
                    // so it takes the ambient direction like the rest of the
                    // row.
                    style: TextStyle(
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: active ? accent : neutral,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // Wraps rather than truncating, per section 14 — the column width
          // comes from the flex above, so a long label never widens the row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 18 / 13,
                fontWeight: upcoming ? FontWeight.w500 : FontWeight.w600,
                color: upcoming ? neutral : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dotted run between two circles, vertically centred on the circles
/// rather than on the whole column — the labels below must not drag it down.
class _Connector extends StatelessWidget {
  const _Connector({required this.dark, required this.done});

  final bool dark;

  /// True once the flow has passed this gap, which draws it in the accent
  /// colour (`step-connector-done`) instead of the neutral dot colour.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.stepAccent(context)
        : AppColors.stepConnectorDot(context);

    return SizedBox(
      height: BookingStepIndicator.circleSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < BookingStepIndicator.dotsPerGap; i++)
            Container(
              width: BookingStepIndicator.dotSize,
              height: BookingStepIndicator.dotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
