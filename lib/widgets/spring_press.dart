import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/motion.dart';
import 'teardown_safe.dart';

/// The press feel every tappable in the app shares: a quick dip and an
/// overshooting return — the Telegram feel. One set of numbers, so a glass
/// button, a grouped row and a call control all answer a finger alike.
abstract final class PressSpec {
  static const down = Duration(milliseconds: 90);
  static const release = Duration(milliseconds: 420);
  static const downCurve = Curves.easeOut;
  static const releaseCurve = Curves.elasticOut;

  /// How far a control dips. Small controls dip further so the motion reads.
  static const scale = 0.96;
  static const scaleSmall = 0.92;
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
  })  : passive = false,
        assert(child != null || builder != null);

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
        focusRadius = null;

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

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with TeardownSafe<SpringPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  void _tap() {
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap!();
  }

  /// Enter/Space: pulse the same press a finger would, so keyboard use gets
  /// the identical feedback instead of firing invisibly.
  void _activateFromKeyboard() {
    _set(true);
    Future<void>.delayed(PressSpec.down * 2, () {
      if (mounted) _set(false);
    });
    _tap();
  }

  Widget _spring(BuildContext context, Widget child) {
    final motion = MotionScope.of(context);
    return AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: motion.d(_down ? PressSpec.down : PressSpec.release),
      curve: _down ? PressSpec.downCurve : PressSpec.releaseCurve,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.builder?.call(context, _down) ?? widget.child!;
    if (widget.passive) {
      return Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: _spring(context, content),
      );
    }
    final enabled = widget.onTap != null;
    return FocusableTap(
      onTap: enabled ? _activateFromKeyboard : null,
      semanticLabel: widget.semanticLabel,
      shape: widget.focusShape,
      radius: widget.focusRadius ?? 14,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled ? _tap : null,
        child: _spring(context, content),
      ),
    );
  }
}
