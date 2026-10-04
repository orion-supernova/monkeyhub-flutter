import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;
import 'teardown_safe.dart';

/// A whole number between [min] and [max], moved with a down and an up arrow.
///
/// For the choices a row of preset chips cannot cover — "3 days", "12 uses" —
/// without the ceremony of a picker wheel or the fiddliness of a keyboard for
/// a two-digit number.
///
/// **Hold to run.** A tap moves one step. Holding an arrow repeats, and the
/// step grows the longer it is held (1, then 5, then 25), so reaching the far
/// end of a large range takes a couple of seconds rather than a minute of
/// tapping, while a short hold still lands exactly. The run stops at either
/// bound with a heavier buzz, so the thumb feels the wall it cannot see.
///
/// **Accessible as one control.** The whole stepper is a single semantics node
/// with `increasedValue`/`decreasedValue` and increase/decrease actions — how
/// a screen reader expects an adjustable value to behave — rather than two
/// buttons it has to discover and pair up. Each arrow is still keyboard
/// focusable through [FocusableTap].
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.increaseLabel,
    required this.decreaseLabel,
    this.display,
    this.semanticsLabel,
  }) : assert(min <= max);

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// Localized names of the two arrows, for their focus nodes.
  final String increaseLabel;
  final String decreaseLabel;

  /// How the value reads, including its unit — "3", "12 uses". Defaults to the
  /// bare number.
  final String Function(int value)? display;

  /// What the value is, for a screen reader — "Number of uses".
  final String? semanticsLabel;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

/// How long an arrow has to be held before it starts repeating, and how often
/// it repeats once it has.
const Duration _kRepeatDelay = Duration(milliseconds: 380);
const Duration _kRepeatEvery = Duration(milliseconds: 85);

class _NumberStepperState extends State<NumberStepper> {
  Timer? _repeat;
  int _ticks = 0;

  /// The value as this widget last set it. A held arrow fires faster than the
  /// parent can rebuild, so stepping from `widget.value` would repeat the same
  /// step from a stale base.
  late int _value = widget.value;

  @override
  void didUpdateWidget(NumberStepper old) {
    super.didUpdateWidget(old);
    if (_repeat == null) _value = widget.value;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  bool get _canIncrease => _value < widget.max;
  bool get _canDecrease => _value > widget.min;

  /// The step for the [_ticks]th repeat of a hold: exact at first, then in
  /// fives, then in twenty-fives — but never more than a tenth of the range,
  /// so a small range stays precise however long it is held.
  int get _holdStep {
    final range = widget.max - widget.min;
    final step = _ticks < 10 ? 1 : (_ticks < 28 ? 5 : 25);
    final ceiling = (range / 10).floor().clamp(1, 1 << 30);
    return step.clamp(1, ceiling);
  }

  /// Moves by [delta] and reports it. Returns false at a bound.
  bool _nudge(int delta) {
    final next = (_value + delta).clamp(widget.min, widget.max);
    if (next == _value) return false;
    setState(() => _value = next);
    widget.onChanged(next);
    return true;
  }

  void _tap(int direction) {
    if (_nudge(direction)) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _startHold(int direction) {
    _stopHold();
    _ticks = 0;
    _tap(direction);
    _repeat = Timer(_kRepeatDelay, () {
      _repeat = Timer.periodic(_kRepeatEvery, (t) {
        _ticks++;
        if (!_nudge(direction * _holdStep)) {
          HapticFeedback.mediumImpact();
          _stopHold();
          return;
        }
        // A tick every few steps rather than every one: a continuous buzz at
        // twelve per second reads as a fault, not as feedback.
        if (_ticks % 4 == 0) HapticFeedback.selectionClick();
      });
    });
  }

  void _stopHold() {
    _repeat?.cancel();
    _repeat = null;
  }

  String _text(int v) => widget.display?.call(v) ?? '$v';

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      value: _text(_value),
      increasedValue: _canIncrease ? _text(_value + 1) : null,
      decreasedValue: _canDecrease ? _text(_value - 1) : null,
      onIncrease: _canIncrease ? () => _tap(1) : null,
      onDecrease: _canDecrease ? () => _tap(-1) : null,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: theme.surfaceSunken,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Arrow(
              icon: CupertinoIcons.minus,
              label: widget.decreaseLabel,
              enabled: _canDecrease,
              onTap: () => _tap(-1),
              onHoldStart: () => _startHold(-1),
              onHoldEnd: _stopHold,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: ExcludeSemantics(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Text(
                    _text(_value),
                    key: ValueKey(_value),
                    textAlign: TextAlign.center,
                    // Body face at 17, tabular so the width holds as the
                    // digits change — not the theme's mono, which is a
                    // typewriter on character themes.
                    style: theme.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: theme.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            _Arrow(
              icon: CupertinoIcons.plus,
              label: widget.increaseLabel,
              enabled: _canIncrease,
              onTap: () => _tap(1),
              onHoldStart: () => _startHold(1),
              onHoldEnd: _stopHold,
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatefulWidget {
  const _Arrow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  State<_Arrow> createState() => _ArrowState();
}

class _ArrowState extends State<_Arrow>
    with TeardownSafe<_Arrow> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = widget.enabled;
    return FocusableTap(
      onTap: widget.onTap,
      enabled: enabled,
      shape: FocusRingShape.circle,
      radius: 20,
      // The stepper as a whole carries the semantics; the arrows would only
      // be announced as two more unlabelled buttons beside it.
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _press(true) : null,
          onTapCancel: () => _press(false),
          onTapUp: (_) => _press(false),
          onTap: enabled ? widget.onTap : null,
          onLongPressStart: enabled
              ? (_) {
                  _press(true);
                  widget.onHoldStart();
                }
              : null,
          onLongPressEnd: (_) {
            _press(false);
            widget.onHoldEnd();
          },
          onLongPressCancel: () {
            _press(false);
            widget.onHoldEnd();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: theme.motionFast,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pressed
                      ? quietFill(theme)
                      : (enabled ? theme.surfaceRaised : Colors.transparent),
                ),
                child: Icon(
                  widget.icon,
                  size: 17,
                  color: enabled
                      ? theme.accent
                      : theme.inkMuted.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
