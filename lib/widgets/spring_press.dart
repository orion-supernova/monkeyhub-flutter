import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/motion.dart';
import 'teardown_safe.dart';

/// The press feel every tappable in the app shares: a quick move to the
/// pressed scale and a spring back with a small overshoot. One set of numbers,
/// so a glass button, a grouped row and a call control all answer a finger
/// alike.
///
/// A scale below 1 is a dip (rows, big capsules); above 1 is the Liquid Glass
/// "bloom" (glass circles, pills, groups): the control swells under the finger.
/// Both release on the same spring.
abstract final class PressSpec {
  static const down = Duration(milliseconds: 90);
  static const downCurve = Curves.easeOut;

  /// The older timed release, for the few controls that still animate their
  /// own scale with `AnimatedScale`. [SpringPress] itself no longer uses them.
  static const release = Duration(milliseconds: 420);
  static const releaseCurve = Curves.elasticOut;

  /// The release spring: stiffness 400, damping 18 (mass 1), damping ratio
  /// 0.45 — a quick return with a small overshoot (about 1.2% of the 6% bloom).
  static const releaseSpring =
      SpringDescription(mass: 1, stiffness: 400, damping: 18);

  /// Pressed scale of a glass control: it grows.
  static const bloom = 1.06;

  /// How far a control dips. Small controls dip further so the motion reads.
  static const scale = 0.96;
  static const scaleSmall = 0.92;

  /// How much of the dip a mouse click (or Enter) gets. A finger hides the
  /// control it presses, so the dip has to be big to be seen around it; a
  /// pointer covers nothing, and at full depth every click in a toolbar
  /// lurched. A quarter turns a small button's 0.92 into 0.98 and a row's
  /// 0.96 into 0.99: felt, not watched.
  static const pointerDepth = 0.25;

  /// [scale] as a mouse or keyboard press plays it.
  static double forPointer(double scale) => 1 - (1 - scale) * pointerDepth;
}

/// THE press feedback: scale on a spring, optional selection haptic, keyboard
/// activation that pulses the same press, and teardown-safe state.
///
/// Three shapes of use:
/// * `SpringPress(onTap:, child:)` — owns the tap.
/// * `SpringPress(onTap:, builder:)` — owns the tap and hands the pressed
///   state to its content (a glass surface that brightens while held).
/// * `SpringPress.passive(child:)` — only watches the pointer and springs,
///   leaving the tap to whatever is inside (a control with its own
///   GestureDetector, which must keep winning the arena exactly as before).
///
/// Hover is owned here too (through [FocusableTap]): a mouse over the control
/// fades in a quiet fill, never a scale. A circle or capsule — glass, almost
/// always — gets [HoverEffect.glow]; anything rounded gets [HoverEffect.tint].
/// Pass [hover] to choose, or use [stateBuilder] to draw your own from the
/// `hovered` flag (which turns the default fill off unless [hover] is given).
class SpringPress extends StatefulWidget {
  const SpringPress({
    super.key,
    required this.onTap,
    this.child,
    this.builder,
    this.scale = PressSpec.scale,
    this.haptic = true,
    this.semanticLabel,
    this.focusShape = FocusRingShape.rounded,
    this.focusRadius,
    this.autofocus = false,
    this.onLongPress,
    this.hover,
    this.hoverRadius,
    this.stateBuilder,
  })  : passive = false,
        assert(child != null || builder != null || stateBuilder != null);

  const SpringPress.passive({
    super.key,
    required Widget this.child,
    this.scale = PressSpec.scaleSmall,
  })  : passive = true,
        onTap = null,
        builder = null,
        haptic = false,
        semanticLabel = null,
        focusShape = FocusRingShape.rounded,
        focusRadius = null,
        autofocus = false,
        onLongPress = null,
        hover = HoverEffect.none,
        hoverRadius = null,
        stateBuilder = null;

  final VoidCallback? onTap;
  final Widget? child;
  final Widget Function(BuildContext context, bool pressed)? builder;
  final double scale;

  /// A light selection tick on tap — what UIKit controls do.
  final bool haptic;
  final String? semanticLabel;
  final FocusRingShape focusShape;
  final double? focusRadius;
  final bool passive;

  /// Takes keyboard focus when it first builds — the Cancel of a destructive
  /// prompt, so Enter on a freshly opened one never destroys anything.
  final bool autofocus;

  /// A secondary gesture on the same control (a row's context menu). The
  /// spring answers it like a tap; keyboard activation stays [onTap].
  final VoidCallback? onLongPress;

  /// The hover fill. Null picks by [focusShape]; see the class doc.
  final HoverEffect? hover;

  /// The hover fill's corner radius, when not [focusRadius].
  final double? hoverRadius;

  /// Like [builder], plus whether a mouse is over the control — for content
  /// that answers hover itself. Rebuilds on hover in and out, so keep what it
  /// builds small.
  final Widget Function(BuildContext context, bool pressed, bool hovered)?
      stateBuilder;

  HoverEffect get _hoverEffect =>
      hover ??
      (stateBuilder != null
          ? HoverEffect.none
          : focusShape == FocusRingShape.rounded
              ? HoverEffect.tint
              : HoverEffect.glow);

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with TeardownSafe<SpringPress>, SingleTickerProviderStateMixin {
  late final AnimationController _scale =
      AnimationController.unbounded(vsync: this, value: 1);
  bool _calm = false;
  bool _down = false;
  bool _hovered = false;

  /// The press in flight came from a mouse or the keyboard: dip gently.
  bool _gentle = false;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
    _animate();
  }

  /// Moves the scale to where the press state says it should be: a short
  /// ease to the pressed scale, then a spring (carrying its velocity) home.
  /// Calm motion never scales.
  void _animate() {
    if (_calm) {
      _scale.stop();
      _scale.value = 1;
      return;
    }
    if (_down) {
      final target =
          _gentle ? PressSpec.forPointer(widget.scale) : widget.scale;
      _scale.animateTo(
        target,
        duration: PressSpec.down,
        curve: PressSpec.downCurve,
      );
    } else {
      _scale.animateWith(
        SpringSimulation(
          PressSpec.releaseSpring,
          _scale.value,
          1,
          _scale.velocity,
        ),
      ).whenComplete(() {
        // The simulation stops within a tolerance of 1; land exactly on it.
        if (mounted && !_down) _scale.value = 1;
      });
    }
  }

  void _press(PointerDeviceKind? kind) {
    _gentle = kind == PointerDeviceKind.mouse;
    _set(true);
  }

  void _tap() {
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap!();
  }

  /// Enter/Space: pulse the same press a finger would, so keyboard use gets
  /// the identical feedback instead of firing invisibly.
  void _activateFromKeyboard() {
    _gentle = true;
    _set(true);
    Future<void>.delayed(PressSpec.down * 2, () {
      if (mounted) _set(false);
    });
    _tap();
  }

  Widget _spring(BuildContext context, Widget child) {
    _calm = MotionScope.of(context).calm;
    if (_calm && _scale.value != 1) _scale.value = 1;
    return AnimatedBuilder(
      animation: _scale,
      child: child,
      // Always wrapped: adding and dropping the Transform as the scale leaves
      // and returns to 1 would remount the child.
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.stateBuilder?.call(context, _down, _hovered) ??
        widget.builder?.call(context, _down) ??
        widget.child!;
    if (widget.passive) {
      return Listener(
        onPointerDown: (e) => _press(e.kind),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: _spring(context, content),
      );
    }
    final enabled = widget.onTap != null;
    return FocusableTap(
      onTap: enabled ? _activateFromKeyboard : null,
      autofocus: widget.autofocus,
      semanticLabel: widget.semanticLabel,
      shape: widget.focusShape,
      radius: widget.focusRadius ?? 14,
      hover: widget._hoverEffect,
      hoverRadius: widget.hoverRadius,
      onHover: widget.stateBuilder == null
          ? null
          : (v) {
              if (_hovered != v && mounted) setState(() => _hovered = v);
            },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (d) => _press(d.kind) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled ? _tap : null,
        onLongPress: enabled ? widget.onLongPress : null,
        // A right-click is a mouse's long-press. Touch never produces one.
        onSecondaryTap: enabled ? widget.onLongPress : null,
        child: _spring(context, content),
      ),
    );
  }
}
