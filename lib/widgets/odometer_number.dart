import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// A number that rolls when it changes, one digit at a time.
///
/// Used wherever the board shows a count that moves under the viewer —
/// standings totals, reaction counts, unseen tallies. A number that simply
/// swaps reads as a re-render; one that rolls reads as something happening.
///
/// Three details that are easy to get wrong:
///
///  * **Per-character, not per-value.** Animating the whole string slides "9"
///    and "10" past each other as one block, which looks like a glitch. Each
///    slot animates independently, so 9 → 10 rolls the units and reveals a new
///    tens slot.
///  * **`ClipRect` around the transition**, or the outgoing digit paints
///    outside the text's bounds on the way past.
///  * **Never an overshooting curve.** Inside that `ClipRect` an `easeOutBack`
///    overshoot is visibly clipped, so this uses `motionEntrance` — which is
///    always `easeOutCubic`/`easeOutQuart` — and `easeInCubic` on the way out.
class OdometerNumber extends StatelessWidget {
  const OdometerNumber({
    super.key,
    required this.value,
    this.style,
    this.semanticLabel,
  });

  final int value;

  /// Defaults to `theme.monoLarge` — numbers on this board are mono so their
  /// figures are tabular and a rolling digit does not shift its neighbours.
  final TextStyle? style;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final resolved = style ?? theme.monoLarge;
    final digits = value.toString().split('');

    return Semantics(
      label: semanticLabel,
      // The animated digits are decorative once the value is announced —
      // without this a screen reader reads each slot separately.
      excludeSemantics: semanticLabel != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < digits.length; i++)
            AnimatedSwitcher(
              // Slot index, so slot 0 keeps animating slot 0 as the number
              // grows. Keying on the digit alone would make 11 → 12 animate
              // both slots because the second "1" would re-match the first.
              key: ValueKey('slot_$i'),
              duration: motion.d(theme.motionFast),
              switchInCurve: motion.c(theme.motionEntrance),
              switchOutCurve: motion.c(Curves.easeInCubic),
              transitionBuilder: (child, anim) => ClipRect(
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: [
                  // The outgoing digit must stay laid out while it slides out,
                  // or it is unmounted the moment the switch begins and the
                  // slot appears to blink rather than roll.
                  ...previous,
                  ?current,
                ],
              ),
              child: Text(
                digits[i],
                key: ValueKey('${digits[i]}_$i'),
                style: resolved,
              ),
            ),
        ],
      ),
    );
  }
}
