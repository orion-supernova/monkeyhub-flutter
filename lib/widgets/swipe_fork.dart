import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import 'haptic_ramp.dart';
import 'haptic_tick.dart';
import 'swipe_fork/fork_machine.dart';
import 'swipe_fork/fork_options.dart';

export 'swipe_fork/fork_gesture.dart';
export 'swipe_fork/fork_machine.dart';
export 'swipe_fork/fork_options.dart';
export 'swipe_fork/fork_overlay.dart';
export 'swipe_fork/fork_peek.dart';

/// A value an [Animation] can wrap without a ticker: [HapticRamp] listens to an
/// [Animation], and the fork's pull and slide are just numbers the pointer sets.
class ForkValue extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  double _v = 0;

  @override
  double get value => _v;
  set value(double v) {
    if (v == _v) return;
    _v = v;
    notifyListeners();
  }

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void didRegisterListener() {}
  @override
  void didUnregisterListener() {}
}

class _Poke extends ChangeNotifier {
  void poke() => notifyListeners();
}

const _openSpring = SpringDescription(mass: 1, stiffness: 420, damping: 26);
const _armSpring = SpringDescription(mass: 1, stiffness: 420, damping: 30);
// Critically damped on the way home, as the chat row's is.
const _closeSpring = SpringDescription(mass: 1, stiffness: 520, damping: 46);

/// The swipe-up: gesture state, haptics and the animations the overlay paints.
/// The decisions live in [ForkMachine]; this owns time.
///
/// Mount a [SwipeForkGesture] over the transcript and a [SwipeForkOverlay]
/// above the screen, both given this controller. Nothing here rebuilds the
/// transcript per frame: the overlay's small capsule tree listens to
/// [repaint].
class SwipeForkController {
  SwipeForkController({
    required TickerProvider vsync,
    required this.canArm,
    required this.roomState,
    required this.onStartHuddle,
    required this.onJoinHuddle,
    required this.onToggleVanish,
    this.failureText,
    this.onCommitted,
    this.rtl = false,
    this.hapticTier,
    ForkMachine? machine,
  }) : machine = machine ?? ForkMachine() {
    AnimationController unb() => AnimationController.unbounded(vsync: vsync);
    reveal = unb();
    armLeft = unb();
    armRight = unb();
    hintT = unb();
    fade = unb();
    shake = unb();
  }

  /// How tall the capsules rest when settled open: a chat row's capsule height.
  static const double restReveal = 64;

  /// Everything the gesture needs to be allowed: at the newest message, no
  /// keyboard, no card, and so on. Asked once, at touch-down.
  final bool Function() canArm;

  /// The room state the options derive from. Asked once, at touch-down, so a
  /// room that changes mid-gesture cannot change the choices under the thumb.
  final ForkRoomState Function() roomState;

  final Future<void> Function() onStartHuddle;
  final Future<void> Function() onJoinHuddle;
  final Future<void> Function(bool on) onToggleVanish;

  /// Turns a failed commit into the line shown under the capsules.
  final String Function(Object error)? failureText;

  /// The reader fired an option (the gesture was completed once).
  final VoidCallback? onCommitted;

  /// Mirrors the sides: vanish on the right, talk on the left.
  bool rtl;

  /// Reduce Motion / low power: crossfades, no overshoot, 150ms.
  bool calm = false;

  /// The x that splits the screen into the capsules' halves. The overlay sets
  /// it from the screen width.
  double midX = 0;

  /// Pins the haptic tier (tests); null decides per gesture.
  final HapticTier? hapticTier;

  final ForkMachine machine;

  /// The capsules' height: follows the finger, then springs to rest or home.
  late final AnimationController reveal;

  /// 0..1 per side: that capsule is armed (stretched over the other).
  late final AnimationController armLeft, armRight;

  /// 0..1: room under the capsules for the hint while a finger is down.
  late final AnimationController hintT;

  /// 0..1: the capsules fading away after a fired action.
  late final AnimationController fade;

  /// 0..1: one shake of the armed capsule when the action failed.
  late final AnimationController shake;

  /// Pull progress 0..1 (the pull haptics read this).
  final ForkValue pullValue = ForkValue();

  final _Poke _frame = _Poke();

  /// Whether anything is on screen. False when idle.
  final ValueNotifier<bool> visible = ValueNotifier(false);

  // What the overlay reads. Kept after release so the exit animates from here.
  bool viewSingle = false;
  ForkOption? viewLeft;
  ForkOption? viewRight;
  ForkOption? committed;

  /// The reason a commit failed, while the capsules show it.
  String? failReason;

  Offset _down = Offset.zero;
  List<ForkOption> _opts = const [];
  HapticRamp? _pullRamp;
  bool _disposed = false;
  int _gen = 0;

  /// Repaint source for the overlay.
  Listenable get repaint =>
      Listenable.merge([_frame, reveal, armLeft, armRight, hintT, fade, shake]);

  /// The options captured at touch-down.
  List<ForkOption> get options => _opts;

  bool get busy => visible.value;

  /// The state a tick of the gesture is in.
  bool get active => machine.active;

  /// Settled open: capsules wait for a tap.
  bool get isOpen => machine.phase == ForkPhase.open;

  /// A finger is down.
  bool get holding => machine.holding;

  ForkSide? get armedSide => machine.armedSide;

  // ───────── touch-down ─────────

  /// Called at pointer-down. Returns whether the gesture may arm, and captures
  /// the options. False for a gate that is closed or a room with nothing to
  /// offer (the list then just bounces).
  bool prepare(Offset down) {
    if (_disposed || busy) return false;
    if (!canArm()) return false;
    final opts = forkOptionsFor(roomState());
    if (opts.isEmpty) return false;
    _opts = opts;
    _down = down;
    return true;
  }

  /// Called when the drag is accepted: the capsules start to grow.
  void start() {
    if (_opts.isEmpty) return;
    ForkOption? left, right;
    for (final o in _opts) {
      // Vanish takes the start side, talk the end side; RTL mirrors both.
      final onLeft = o.isVanish != rtl;
      if (onLeft) {
        left = o;
      } else {
        right = o;
      }
    }
    ++_gen;
    machine.begin(left: left, right: right, midX: midX);
    viewLeft = left;
    viewRight = right;
    viewSingle = machine.single;
    committed = null;
    failReason = null;
    for (final c in [reveal, armLeft, armRight, hintT, fade, shake]) {
      c.stop();
      c.value = 0;
    }
    pullValue.value = 0;
    _pullRamp?.dispose();
    _pullRamp = HapticRamp.twoWay(pullValue, taps: 12, tier: hapticTier)
      ..beginGesture(tier: hapticTier);
    visible.value = true;
    _animate(hintT, 1, 150);
    _frame.poke();
  }

  // ───────── drag ─────────

  void move(Offset pos) {
    if (!machine.holding) return;
    final events = machine.update(_down.dy - pos.dy, pos.dx);
    for (final e in events) {
      switch (e) {
        case ForkEvent.opened:
          _tick(0.9, HapticKind.notch);
        case ForkEvent.unopened:
          break;
        case ForkEvent.armed:
        case ForkEvent.swapped:
          _tick(0.85, HapticKind.arm);
          _armTo(machine.armedSide);
        case ForkEvent.disarmed:
          _tick(0.3, HapticKind.soft);
          _armTo(null);
      }
    }
    reveal.value = machine.reveal;
    // The arm tick owns the last detent, so the ramp stops short of it.
    pullValue.value = machine.progress.clamp(0.0, 0.92).toDouble();
    _frame.poke();
  }

  void _armTo(ForkSide? side) {
    _spring(armLeft, side == ForkSide.left ? 1 : 0, _armSpring);
    _spring(armRight, side == ForkSide.right ? 1 : 0, _armSpring);
  }

  void _spring(AnimationController c, double to, SpringDescription d) {
    if (_disposed) return;
    if (calm) {
      c.animateTo(to, duration: const Duration(milliseconds: 150));
      return;
    }
    c.animateWith(SpringSimulation(d, c.value, to, c.velocity));
  }

  TickerFuture _animate(AnimationController c, double to, int ms) =>
      c.animateTo(to, duration: Duration(milliseconds: ms));

  void _tick(double intensity, HapticKind kind) =>
      HapticTick.play(intensity, kind: kind, tier: hapticTier);

  // ───────── release ─────────

  void release(double vx) {
    if (!machine.holding) return;
    final out = machine.end();
    _endRamps();
    switch (out.result) {
      case ForkResult.commit:
        _commit(out.option!, tapped: false);
      case ForkResult.settleOpen:
        _settleOpen();
      case ForkResult.cancel:
        _close(tick: true);
    }
  }

  /// A second finger, the app going to the background: no commit, a calm
  /// collapse.
  void cancelGesture() {
    if (!machine.active || machine.phase == ForkPhase.committing) return;
    machine.reset();
    _endRamps();
    _close(tick: true);
  }

  /// A tap anywhere that is not a capsule, a scroll, the keyboard: closes the
  /// settled-open capsules.
  void dismiss() {
    if (!isOpen) return;
    machine.reset();
    _close(tick: false);
  }

  /// A tap on the capsule at [side] while settled open.
  void tapSide(ForkSide side) {
    final out = machine.tap(side);
    if (out.committed) _commit(out.option!, tapped: true);
  }

  /// A tap on whichever capsule shows [o].
  void tapOption(ForkOption o) {
    if (viewLeft == o) {
      tapSide(ForkSide.left);
    } else if (viewRight == o) {
      tapSide(ForkSide.right);
    }
  }

  void _endRamps() {
    pullValue.value = 0;
    _pullRamp?.dispose();
    _pullRamp = null;
  }

  void _settleOpen() {
    _tick(0.5, HapticKind.soft);
    _armTo(null);
    _animate(hintT, 0, 150);
    if (calm) {
      _animate(reveal, restReveal, 150);
    } else {
      reveal.animateWith(
        SpringSimulation(_openSpring, reveal.value, restReveal, reveal.velocity),
      );
    }
    _frame.poke();
  }

  /// Springs the capsules back into the dock and clears the screen.
  void _close({required bool tick}) {
    if (tick) _tick(0.25, HapticKind.soft);
    final gen = ++_gen;
    _armTo(null);
    _animate(hintT, 0, 150);
    final Future<void> done;
    if (calm) {
      done = _animate(fade, 1, 150);
    } else {
      done = reveal.animateWith(
        SpringSimulation(_closeSpring, reveal.value, 0, reveal.velocity),
      );
    }
    done.then((_) {
      if (gen == _gen) _finish();
    }, onError: (_) {});
    _frame.poke();
  }

  Future<void> _commit(ForkOption option, {required bool tapped}) async {
    final gen = ++_gen;
    committed = option;
    onCommitted?.call();
    _tick(1, HapticKind.commit);
    if (tapped) {
      _armTo(machine.armedSide);
    }
    _animate(hintT, 0, 150);
    final result = _run(option);
    _frame.poke();
    final err = await result;
    if (gen != _gen || _disposed) return;
    if (err == null) {
      try {
        await _animate(fade, 1, 240);
      } catch (_) {}
      if (gen == _gen) _finish();
      return;
    }
    // Failed: one shake, the reason, then a calm collapse.
    failReason = failureText?.call(err) ?? '';
    _tick(0.3, HapticKind.soft);
    _animate(hintT, 1, 150);
    _frame.poke();
    try {
      await shake.animateTo(1, duration: const Duration(milliseconds: 420));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (gen != _gen || _disposed) return;
    } catch (_) {
      return;
    }
    machine.reset();
    _close(tick: false);
  }

  /// Runs the option's action. Returns the error, or null on success.
  Future<Object?> _run(ForkOption o) async {
    try {
      await runOption(o.kind);
      return null;
    } catch (e) {
      return e;
    }
  }

  /// Does what [kind] says, with no animation: the commit's action, and what
  /// the composer's accessibility actions call.
  Future<void> runOption(ForkKind kind) => switch (kind) {
        ForkKind.startHuddle => onStartHuddle(),
        ForkKind.joinHuddle => onJoinHuddle(),
        ForkKind.vanishOn => onToggleVanish(true),
        ForkKind.vanishOff => onToggleVanish(false),
      };

  void _finish() {
    if (_disposed) return;
    machine.reset();
    failReason = null;
    committed = null;
    visible.value = false;
    for (final c in [reveal, armLeft, armRight, hintT, fade, shake]) {
      c.stop();
      c.value = 0;
    }
    _frame.poke();
  }

  void dispose() {
    _disposed = true;
    _pullRamp?.dispose();
    for (final c in [reveal, armLeft, armRight, hintT, fade, shake]) {
      c.dispose();
    }
    visible.dispose();
    _frame.dispose();
  }
}
