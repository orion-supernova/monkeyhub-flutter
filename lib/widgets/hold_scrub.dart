/// The long-press grammar shared by every hold that opens a menu.
///
/// One skeleton, one gesture (see the plan on the user's Desktop,
/// `long-press-plan.html`, 2026-11-06):
///
///  * **Layout never flips.** Reactions above, the lifted item in the middle,
///    actions below. When there is no room, the ITEM moves or shrinks; the
///    chrome keeps its order. See [holdMenuPlacement].
///  * **The hold continues into a reaction scrub.** The finger that opened the
///    menu stays live: sliding across the quick reactions magnifies the one
///    under it, releasing on it reacts. See [HoldScrub].
///  * **Actions always need a tap.** Rows never commit on release and never
///    highlight under a sliding finger. A wrong reaction is undone in one tap;
///    a wrong Forward, Pin or Delete is not.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../theme/interaction.dart';

/// Something that wants the finger a long-press left down: the open menu.
abstract interface class HoldScrubTarget {
  /// The held finger moved. [fromOrigin] is its travel since the press began.
  void holdMove(Offset globalPosition, Offset fromOrigin);

  /// The held finger lifted.
  void holdEnd(Offset globalPosition);
}

/// Hands the finger of a long-press from the widget that was pressed to the
/// menu that press opened.
///
/// The menu lives in the root overlay, which did not exist when the pointer
/// went down, so it never gets that pointer's events: hit-testing happened at
/// pointer-down. The pressed widget's [LongPressGestureRecognizer] has already
/// won the arena by the time the menu is up, and it keeps receiving moves and
/// the release. It forwards them here ([start] / [move] / [end]) and whichever
/// menu is [attach]ed takes them.
///
/// The menu can attach a frame or two after the hold fires (the caller awaits
/// state before showing it), so the moves in between are dropped and [isHeld]
/// tells a late menu whether the finger is still down at all.
abstract final class HoldScrub {
  static HoldScrubTarget? _target;
  static bool _held = false;

  /// Whether the finger that fired the last long-press is still down.
  static bool get isHeld => _held;

  static void attach(HoldScrubTarget target) => _target = target;

  static void detach(HoldScrubTarget target) {
    if (identical(_target, target)) _target = null;
  }

  /// Called by the pressed widget when its hold fires.
  static void start() => _held = true;

  static void move(Offset globalPosition, Offset fromOrigin) {
    if (!_held) return;
    _target?.holdMove(globalPosition, fromOrigin);
  }

  static void end(Offset globalPosition) {
    if (!_held) return;
    _held = false;
    _target?.holdEnd(globalPosition);
  }

  /// Travel past which a held finger counts as sliding rather than resting.
  /// Below it, a release leaves the menu open for tapping (today's behavior).
  static const double slop = 10;

  @visibleForTesting
  static void reset() {
    _target = null;
    _held = false;
  }
}

/// Where the pieces of a hold menu land. See [holdMenuPlacement].
@immutable
class HoldMenuPlacement {
  const HoldMenuPlacement({
    required this.previewScale,
    required this.previewTop,
    required this.liftDy,
    required this.pillTop,
    required this.menuTop,
    required this.menuHeight,
  });

  /// The scale the preview settles at, relative to the pressed item.
  final double previewScale;

  /// Top of the settled preview.
  final double previewTop;

  /// How far the preview travels from where it was pressed.
  final double liftDy;

  /// Top of the reaction pill (or of the space it would take).
  final double pillTop;

  /// Top of the action list.
  final double menuTop;

  /// The list's height: what it wanted, or less when the band forced it to
  /// scroll.
  final double menuHeight;
}

/// Lays a hold menu out: reactions above, preview in the middle, actions
/// below, ALWAYS in that order.
///
/// The old layout chose between three shapes (split, stacked under, stacked
/// over) depending on where the bubble sat, so the pill jumped around and a
/// hand could never learn where it was. Here only the preview moves: it stays
/// where it was pressed unless that collides, then glides the least distance
/// that clears both pieces of chrome. A preview too tall for what is left
/// shrinks toward its own edge, never below [minPreview]; past that the list
/// scrolls instead.
///
/// [pressed] is the item's rect at the press; [maxScale] caps the preview
/// (media sets one so a photo does not crowd the menu even when it would fit).
/// The preview scales about its own vertical center, matching the lifted
/// widget's transform.
HoldMenuPlacement holdMenuPlacement({
  required Rect pressed,
  required double bandTop,
  required double bandBottom,
  required double pillHeight,
  required double wantedMenuHeight,
  double gap = 8,
  double maxScale = 1,
  double minPreview = 64,
}) {
  final band = math.max(0.0, bandBottom - bandTop);
  final chrome = pillHeight + gap * 2;
  final floor = math.min(minPreview, pressed.height);
  final menuH = math.max(
    0.0,
    math.min(wantedMenuHeight, band - chrome - floor),
  );
  final previewRoom = math.max(1.0, band - chrome - menuH);
  final scale = pressed.height <= 0
      ? 1.0
      : math.max(0.05, math.min(maxScale, previewRoom / pressed.height));
  final previewH = pressed.height * scale;
  final settledTop = pressed.center.dy - previewH / 2;

  final lo = bandTop + pillHeight + gap;
  final hi = math.max(lo, bandBottom - gap - menuH - previewH);
  final top = settledTop.clamp(lo, hi).toDouble();

  return HoldMenuPlacement(
    previewScale: scale,
    previewTop: top,
    liftDy: top - settledTop,
    pillTop: top - gap - pillHeight,
    menuTop: top + previewH + gap,
    menuHeight: menuH,
  );
}

/// The give a held item shows before its menu opens: it eases down to 0.96
/// while the finger stays, so the hold announces itself instead of arriving
/// out of nowhere at [kActionMenuLongPress].
///
/// Pointer-level ([Listener]) rather than a recognizer, so it never joins the
/// gesture arena and cannot change who wins it. It waits [_delay] before
/// moving at all, so a tap or the start of a scroll never twitches the item.
/// Touch and stylus only: a mouse hold is a text selection on desktop.
class HoldPressFeedback extends StatefulWidget {
  const HoldPressFeedback({
    super.key,
    required this.enabled,
    required this.child,
    this.alignment = Alignment.center,
  });

  final bool enabled;
  final Alignment alignment;
  final Widget child;

  @override
  State<HoldPressFeedback> createState() => _HoldPressFeedbackState();
}

class _HoldPressFeedbackState extends State<HoldPressFeedback>
    with SingleTickerProviderStateMixin {
  static const Duration _delay = Duration(milliseconds: 120);
  static const double _depth = 0.04;

  AnimationController? _c;
  Timer? _timer;
  int? _pointer;
  Offset _origin = Offset.zero;

  AnimationController get _ctrl => _c ??= AnimationController(
        vsync: this,
        duration: kActionMenuLongPress - _delay,
        reverseDuration: const Duration(milliseconds: 140),
      )..addListener(() => setState(() {}));

  void _down(PointerDownEvent e) {
    if (!widget.enabled || _pointer != null) return;
    if (e.kind == PointerDeviceKind.mouse) return;
    _pointer = e.pointer;
    _origin = e.position;
    _timer = Timer(_delay, () {
      if (mounted && _pointer != null) _ctrl.forward();
    });
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    // Before the hold fires, travel means a scroll or a swipe: let go. After
    // it, the menu is up and the item stays pressed under it.
    if (_ctrl.value < 1 && (e.position - _origin).distance > kTouchSlop) {
      _release();
    }
  }

  void _up(PointerEvent e) {
    if (e.pointer == _pointer) _release();
  }

  void _release() {
    _pointer = null;
    _timer?.cancel();
    _timer = null;
    final c = _c;
    if (c != null && c.value > 0) c.reverse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = Curves.easeOut.transform(_c?.value ?? 0);
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      // Always wrapped, even at rest: swapping the wrapper in and out would
      // change the child's place in the tree and rebuild the whole bubble.
      child: Transform.scale(
        scale: 1 - _depth * v,
        alignment: widget.alignment,
        child: widget.child,
      ),
    );
  }
}

/// An underdamped spring as a [Curve]: overshoots by about [overshoot] of the
/// distance, swings back under, and settles by t = 1. The "jelly" every
/// piece of a hold menu lands with, so a fixed-duration [AnimationController]
/// can still wobble into place.
///
/// Unlike [Curves.easeOutBack], which overshoots once and glides home, this
/// one rings: the second, smaller swing is what reads as soft and physical
/// rather than merely springy. Values leave 0..1, so anything driving an
/// opacity or a clip must clamp.
class JellyCurve extends Curve {
  const JellyCurve({this.overshoot = 0.12});

  /// Fraction of the distance the first swing passes the end by.
  final double overshoot;

  @override
  double transformInternal(double t) {
    // Damping ratio from the wanted overshoot: os = exp(-pi*z/sqrt(1-z^2)).
    final l = math.log(overshoot.clamp(0.001, 0.9));
    final z = -l / math.sqrt(math.pi * math.pi + l * l);
    // Fast enough that the envelope is under 0.2% by t = 1.
    final w = 6.2 / z;
    final wd = w * math.sqrt(1 - z * z);
    final decay = math.exp(-z * w * t);
    return 1 - decay * (math.cos(wd * t) + z * w / wd * math.sin(wd * t));
  }
}
