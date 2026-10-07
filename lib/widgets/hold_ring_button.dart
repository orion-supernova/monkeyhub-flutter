import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/interaction.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'haptic_ramp.dart';

/// How long a press has to last before the hold ring is allowed to appear.
///
/// A tap is over in well under this; a hold is only a third of the way through
/// it. So the ring never shows on a tap, and a user who genuinely means to
/// hold sees it come up almost at once. Below roughly 100ms it starts catching
/// deliberate taps again, and much above 150ms the hold feels unresponsive
/// before anything happens — this is the window between those.
const Duration _kHoldRingLead = Duration(milliseconds: 130);

/// A round button that does one thing on a tap and another on a hold, with a
/// ring that sweeps around it while the hold charges.
///
/// THE send-with-options gesture. The chat composer's send button and the photo
/// composer's both wear it, so "hold send to schedule" feels — and buzzes —
/// the same whether the thing being sent is words or pictures. Everything about
/// the gesture lives here; the caller only draws the disc.
///
///  * **Tap** — [onTap], with one light tick.
///  * **Hold** — the ring sweeps for [kActionMenuLongPress] with a vibration
///    that builds alongside it ([HapticRamp]), then [onHold] with one heavy
///    impact, so "it went" lands as its own beat.
///  * **Cmd/Ctrl+Enter** — [onHold], the keyboard route every mail client
///    already uses for "send with options".
///  * **Screen readers** — [onHold] as a rotor action named [holdLabel]: a hold
///    is a gesture a VoiceOver user cannot perform on a target they cannot see.
///
/// Null [onHold] drops all of that — no recognizer, no ring, no rotor action —
/// because a hold that visibly charges and then does nothing is worse than one
/// that never starts. Null [onTap] is a disabled button.
class HoldRingButton extends StatefulWidget {
  const HoldRingButton({
    super.key,
    this.child,
    this.builder,
    required this.onTap,
    required this.semanticLabel,
    this.onHold,
    this.holdLabel,
    this.ringColor,
  }) : assert(child != null || builder != null);

  /// The disc. The ring is painted around its bounds and adds nothing to
  /// layout.
  final Widget? child;

  /// The disc, drawn from how far the hold has charged (0..1) — for a button
  /// that wants to say what letting go will do before it happens. Used in
  /// place of [child].
  final Widget Function(BuildContext context, double hold)? builder;

  final VoidCallback? onTap;
  final VoidCallback? onHold;
  final String semanticLabel;

  /// The rotor action's name. Required in practice whenever [onHold] is set.
  final String? holdLabel;

  /// Defaults to the theme's ink-on-accent, which reads on an accent disc.
  final Color? ringColor;

  @override
  State<HoldRingButton> createState() => _HoldRingButtonState();
}

class _HoldRingButtonState extends State<HoldRingButton>
    with SingleTickerProviderStateMixin {
  /// Drives the ring that sweeps around the button while it is held.
  ///
  /// The whole point is that a hold has to LOOK like it is going somewhere.
  /// Without it the button sits there for 400ms and the user either lets go
  /// (thinking it is broken) or is surprised by a sheet. The ring is the
  /// mechanism iOS uses for the same gesture, rather than a fade or a wobble
  /// tuned until it feels long enough.
  late final AnimationController _hold;

  /// The vibration that builds with the ring, and stops the instant it does.
  late final HapticRamp _holdHaptics;

  /// Waits out [_kHoldRingLead] before the ring is allowed to start.
  ///
  /// This is the whole fix for the ring flashing on an ordinary tap.
  /// `onLongPressDown` fires on POINTER-DOWN — the recognizer has no idea yet
  /// whether this will become a tap or a hold — so starting the sweep there
  /// meant every tap flashed a stub of arc and then spent up to 400ms
  /// reversing it. No opacity threshold fixes that: the animation is running,
  /// and the only question is how much of it you can see.
  Timer? _leadIn;

  /// Kept across rebuilds that re-create the button's parent.
  ///
  /// Load-bearing: the chat composer rebuilds this on every keystroke, and a
  /// recognizer holding a live pointer whose element is re-created loses the
  /// gesture mid-hold. The same reparenting problem `ComposerCaptureHost`
  /// documents on its own mode button.
  final GlobalKey _key = GlobalKey();

  /// True from [deactivate]: the hold recognizer can fire its cancel from
  /// inside the unmount, and notifying [_hold]'s listeners then would mark a
  /// builder dirty while the tree is locked (see TeardownSafe).
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(
      vsync: this,
      // What is LEFT of the gesture once the lead-in has passed, so the ring
      // still closes at the exact instant the recognizer fires. Using the full
      // threshold here would leave it a lead-in short of complete at the moment
      // the sheet opens — a progress indicator that never reaches its end.
      duration: kActionMenuLongPress - _kHoldRingLead,
    );
    _holdHaptics = HapticRamp(_hold);
  }

  @override
  void dispose() {
    _leadIn?.cancel();
    _holdHaptics.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    _leaving = true;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _leaving = false;
  }

  void _startHold() {
    if (widget.onHold == null || widget.onTap == null) return;
    if (MotionScope.of(context).calm) return;
    _leadIn?.cancel();
    _leadIn = Timer(_kHoldRingLead, () {
      if (mounted) _hold.forward(from: 0);
    });
  }

  /// Withdraws the ring, instantly.
  ///
  /// Snapped rather than reversed. A reverse reads as the button finishing
  /// something; the user has just let go, and the honest rendering of an
  /// abandoned gesture is that it is gone.
  void _endHold() {
    _leadIn?.cancel();
    _leadIn = null;
    if (_leaving) return;
    if (_hold.value != 0) _hold.value = 0;
  }

  /// A tap is one light tick. The hold's heavy impact stays the loud one.
  void _tap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    HapticFeedback.lightImpact();
    onTap();
  }

  void _fire() {
    final onHold = widget.onHold;
    if (onHold == null || widget.onTap == null) return;
    // Heavier than anything the ramp played, so the sheet opening lands as
    // its own beat rather than one more tap in the buzz.
    HapticFeedback.heavyImpact();
    _endHold();
    onHold();
  }

  @override
  Widget build(BuildContext context) {
    final holds = widget.onHold != null && widget.onTap != null;
    final builder = widget.builder;
    Widget core = builder == null
        ? widget.child!
        : AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => builder(context, _hold.value),
          );

    if (holds) {
      final color = widget.ringColor ?? ThemeScope.of(context).accentInk;
      // The ring, painted outside the button's own bounds so it adds nothing
      // to layout — the FocusableTap focus-ring trick, for the same reason.
      core = Stack(
        clipBehavior: Clip.none,
        children: [
          core,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _hold,
                // The lead-in timer keeps the controller at rest through every
                // tap: while it is moving at all, the user is holding.
                builder: (context, _) => _hold.value == 0
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        painter: _HoldRingPainter(
                          progress: _hold.value,
                          color: color,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
      // The button shrinks slightly as the ring fills, so the hold reads as
      // one gesture gathering rather than a decoration spinning on a static
      // button. Driven by the same controller, which only leaves zero during
      // a real hold — so a tap never twitches.
      core = AnimatedBuilder(
        animation: _hold,
        builder: (context, child) => Transform.scale(
          scale: 1 - (_hold.value * 0.06),
          child: child,
        ),
        child: core,
      );
    }

    // RawGestureDetector, not GestureDetector: a plain one's long press is
    // fixed at Flutter's half-second with no way to shorten it, and this app
    // has already settled on `kActionMenuLongPress` for "hold reveals options"
    // everywhere else. Two recognizers in one arena so a tap still taps.
    Widget body = !holds
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap == null ? null : _tap,
            child: core,
          )
        : RawGestureDetector(
            key: _key,
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (instance) {
                  instance.onTap = _tap;
                  instance.onTapCancel = _endHold;
                },
              ),
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: kActionMenuLongPress,
                ),
                (instance) {
                  instance.onLongPressDown = (_) => _startHold();
                  instance.onLongPress = _fire;
                  instance.onLongPressCancel = _endHold;
                  instance.onLongPressUp = _endHold;
                },
              ),
            },
            child: core,
          );

    body = FocusableTap(
      onTap: widget.onTap == null ? null : _tap,
      semanticLabel: widget.semanticLabel,
      shape: FocusRingShape.circle,
      child: body,
    );

    if (holds) {
      // Bound outside FocusableTap so it fires while the button's own node
      // holds focus.
      body = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _fire,
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _fire,
        },
        child: body,
      );
      final holdLabel = widget.holdLabel;
      if (holdLabel != null) {
        body = Semantics(
          customSemanticsActions: {
            CustomSemanticsAction(label: holdLabel): _fire,
          },
          child: body,
        );
      }
    }
    return body;
  }
}

/// The arc that sweeps around the button while it is held.
class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      // Fades in over the first fifth of the sweep, so a tap that happens to
      // register a few milliseconds of hold does not flash a stub of arc.
      ..color = color.withValues(alpha: (progress * 5).clamp(0.0, 1.0) * 0.9);
    canvas.drawArc(
      rect.deflate(2),
      -1.5707963267948966, // 12 o'clock
      progress * 6.283185307179586,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_HoldRingPainter old) =>
      old.progress != progress || old.color != color;
}
