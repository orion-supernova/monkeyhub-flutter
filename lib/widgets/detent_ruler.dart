import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'haptic_tick.dart';

/// A horizontal ruler with a few labelled stops: drag the knob, it follows the
/// finger, ticks as it passes each stop and settles on the nearest one when let
/// go. The message-timer control (see `MessageLifePicker`), kept generic so any
/// short list of choices can use it.
///
///  * **Drag or tap** anywhere on the ruler. The knob follows the finger
///    continuously and shows the value it would land on; [onChanged] fires as
///    the nearest stop changes, so whatever it feeds (a caption, a preview)
///    updates live, exactly as the design prototype does.
///  * **Haptics** - one [HapticTick] per stop crossed, in either direction,
///    firmer toward the high end ("soft to firm", `0.25 + 0.5 * i/(n-1)`).
///    The [HapticTier] is decided once, when the finger lands, so a call or
///    low power never re-checks per tick: below a full ramp a stop is a single
///    clean notch instead of a graded tick.
///  * **Release** - the knob springs onto the stop. Reduce Motion (or a calm
///    app) has no spring: it just lands.
///  * **Accessibility** - an adjustable slider for screen readers (swipe up and
///    down to step, announcing [semanticValues] or [labels]), and arrow keys,
///    Home and End for a keyboard, with a focus ring while focused.
///
/// Controlled: [index] is the truth. A change from the outside (the picker
/// swapping its list) glides or jumps to the new stop; during a drag the
/// finger wins.
class DetentRuler extends StatefulWidget {
  const DetentRuler({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    required this.semanticLabel,
    this.semanticValues,
    this.hapticsEnabled = true,
  })  : assert(labels.length >= 2),
        assert(index >= 0 && index < labels.length);

  /// What each stop reads. Shown under the track and on the knob.
  final List<String> labels;

  /// The selected stop.
  final int index;

  final ValueChanged<int> onChanged;

  /// What the control is, for a screen reader ("Message timer").
  final String semanticLabel;

  /// Spoken forms of [labels] ("30 seconds" for "30s"), when they differ.
  final List<String>? semanticValues;

  /// Off for a host that supplies its own feedback.
  final bool hapticsEnabled;

  /// The ruler's height; the knob and labels are laid out inside it.
  static const double height = 62;

  @override
  State<DetentRuler> createState() => _DetentRulerState();
}

class _DetentRulerState extends State<DetentRuler>
    with SingleTickerProviderStateMixin {
  static const double _pad = 24;
  static const double _knobWidth = 56;
  static const _spring = SpringDescription(mass: 1, stiffness: 420, damping: 26);

  /// Where the knob is, in stops (fractional while dragging or springing).
  late final AnimationController _pos;

  final FocusNode _focus = FocusNode(debugLabel: 'DetentRuler');
  bool _focused = false;
  bool _dragging = false;

  /// The stop last reported, which a release settles on.
  late int _current;

  HapticTier? _tier;

  int get _last => widget.labels.length - 1;

  @override
  void initState() {
    super.initState();
    _current = widget.index;
    _pos = AnimationController.unbounded(
      vsync: this,
      value: widget.index.toDouble(),
    );
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void didUpdateWidget(DetentRuler old) {
    super.didUpdateWidget(old);
    if (_dragging) return;
    final clamped = widget.index.clamp(0, _last);
    if (clamped != _current || widget.labels.length != old.labels.length) {
      _current = clamped;
      _settle();
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Carries the knob to [_current]: a spring, or a jump when calm.
  void _settle() {
    final target = _current.toDouble();
    if (MotionScope.of(context).calm) {
      _pos.stop();
      _pos.value = target;
    } else {
      _pos.animateWith(SpringSimulation(_spring, _pos.value, target, 0));
    }
  }

  double _trackWidth(double full) => (full - _pad * 2).clamp(1.0, double.infinity);

  /// The fractional stop under a finger at [dx] of a [full]-wide ruler.
  double _stopAt(double dx, double full) =>
      (((dx - _pad) / _trackWidth(full)).clamp(0.0, 1.0)) * _last;

  void _begin() {
    _dragging = true;
    _pos.stop();
    _tier = widget.hapticsEnabled ? HapticTick.current() : HapticTier.silent;
    if (widget.hapticsEnabled) HapticTick.prepare();
    setState(() {});
  }

  void _move(double dx, double full) {
    final stop = _stopAt(dx, full);
    _pos.value = stop;
    final next = stop.round();
    if (next != _current) {
      _current = next;
      _tickFor(next);
      widget.onChanged(next);
    }
  }

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    _settle();
    setState(() {});
  }

  /// Soft to firm along the ruler. Below the full ramp a stop is one clean
  /// notch, not a graded tick.
  void _tickFor(int stop) {
    final tier = _tier ?? HapticTier.silent;
    if (tier == HapticTier.silent) return;
    final through = _last == 0 ? 1.0 : stop / _last;
    if (tier == HapticTier.landmarks) {
      HapticTick.play(0.6, kind: HapticKind.notch, tier: tier);
    } else {
      HapticTick.play(0.25 + 0.5 * through, tier: tier);
    }
  }

  /// A step from a keyboard or a screen reader: no finger, so no haptic.
  void _step(int by) {
    final next = (_current + by).clamp(0, _last);
    if (next == _current) return;
    _current = next;
    _settle();
    widget.onChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _step(1);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _step(-1);
    } else if (key == LogicalKeyboardKey.home) {
      _step(-_last);
    } else if (key == LogicalKeyboardKey.end) {
      _step(_last);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String _spoken(int i) => (widget.semanticValues ?? widget.labels)[i];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final labels = widget.labels;
    final shown = _current.clamp(0, _last);

    final ruler = LayoutBuilder(
      builder: (context, box) {
        final full = box.maxWidth;
        final track = _trackWidth(full);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // A tap is a drag that lands and lifts: the knob jumps there.
          onTapDown: (d) {
            _begin();
            _move(d.localPosition.dx, full);
          },
          onTapUp: (_) => _end(),
          onTapCancel: _end,
          onHorizontalDragStart: (d) {
            if (!_dragging) _begin();
            _move(d.localPosition.dx, full);
          },
          onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, full),
          onHorizontalDragEnd: (_) => _end(),
          onHorizontalDragCancel: _end,
          child: SizedBox(
            height: DetentRuler.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _focused ? theme.accent : const Color(0x00000000),
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The stops: a tick and a label each. The selected label
                  // brightens, the way the design's `.on` tick does.
                  for (var i = 0; i <= _last; i++)
                    Positioned(
                      left: _pad + track * (_last == 0 ? 0 : i / _last) - 30,
                      width: 60,
                      top: 36,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 2,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == shown
                                  ? theme.accent
                                  : theme.ink.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[i],
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: theme.caption.copyWith(
                              fontSize: 11,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: i == shown ? theme.ink : theme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // The knob, on the controller so a spring or a drag moves it
                  // without rebuilding the labels.
                  AnimatedBuilder(
                    animation: _pos,
                    builder: (context, _) {
                      final x = _pad +
                          track * (_last == 0 ? 0 : _pos.value / _last);
                      return Positioned(
                        left: x - _knobWidth / 2,
                        top: 8,
                        width: _knobWidth,
                        height: 24,
                        child: Transform.scale(
                          scale: _dragging ? 1.08 : 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                labels[shown],
                                maxLines: 1,
                                softWrap: false,
                                style: theme.caption.copyWith(
                                  fontSize: 12,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: theme.accentInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Semantics(
      container: true,
      slider: true,
      label: widget.semanticLabel,
      value: _spoken(shown),
      increasedValue: shown < _last ? _spoken(shown + 1) : null,
      decreasedValue: shown > 0 ? _spoken(shown - 1) : null,
      onIncrease: shown < _last ? () => _step(1) : null,
      onDecrease: shown > 0 ? () => _step(-1) : null,
      child: ExcludeSemantics(
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: ruler,
          ),
        ),
      ),
    );
  }
}
