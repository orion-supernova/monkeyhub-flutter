import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import 'haptic_ramp.dart';
import 'haptic_tick.dart';
import 'swipe_fork/fork_machine.dart';
import 'swipe_fork/fork_options.dart';
import 'swipe_fork/fork_peek.dart';
import 'swipe_fork/fork_scroll.dart';

export 'swipe_fork/fork_gesture.dart';
export 'swipe_fork/fork_machine.dart';
export 'swipe_fork/fork_options.dart';
export 'swipe_fork/fork_overlay.dart';
export 'swipe_fork/fork_peek.dart';
export 'swipe_fork/fork_scroll.dart';

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

/// How the gesture ended: the list springs back either way; the commit kinds
/// say which action ran (so the host can aim a wave at the circle).
enum ForkExit { none, cancel, commitTalk, commitVanish }

/// Extra lift the list gets when two chips bloom, so they fit in the gap.
const double kForkBloomLift = 24;

const _bloomSpring = SpringDescription(mass: 1, stiffness: 420, damping: 26);
/// Critically damped and quick: the chips trail the finger without jitter.
const _followSpring = SpringDescription(mass: 1, stiffness: 520, damping: 45.6);
const _commitSpring = SpringDescription(mass: 1, stiffness: 300, damping: 30);
const _cancelSpring = SpringDescription(mass: 1, stiffness: 520, damping: 40);

/// The swipe-up fork: gesture state, haptics and the animations the list lift
/// and the overlay paint. The decisions live in [ForkMachine]; this owns time.
///
/// The transcript itself is pulled up with the finger: wrap it in a
/// [ForkLift], mount a [SwipeForkGesture] over it and a [SwipeForkOverlay]
/// above the screen (the circle and chips live in the gap the lift opens), all
/// given this controller. Nothing here rebuilds a message row per frame: the
/// lift is one transform and the overlay's painter listens to [repaint].
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
    bloom = unb();
    armLeft = unb();
    armRight = unb();
    glyph = unb();
    pulse = unb();
    flight = unb();
    chrome = unb();
    orbFade = unb();
    shake = unb();
    fingerY = unb();
    kick = unb();
    pull = ForkPull(this);
  }

  /// Everything the gesture needs to be allowed: at the newest message, no
  /// keyboard, no card, and so on. Asked once, at touch-down.
  final bool Function() canArm;

  /// The room state the options derive from. Asked once, at touch-down, so a
  /// room that changes mid-gesture cannot change the choices under the thumb.
  final ForkRoomState Function() roomState;

  final Future<void> Function() onStartHuddle;
  final Future<void> Function() onJoinHuddle;
  final Future<void> Function(bool on) onToggleVanish;

  /// Turns a failed commit into the line the circle shows.
  final String Function(Object error)? failureText;

  /// The reader let go on an option (the gesture was completed once).
  final VoidCallback? onCommitted;

  /// Mirrors the sides: vanish on the right, talk on the left.
  bool rtl;

  /// Reduce Motion / low power: crossfades, 150ms commit.
  bool calm = false;

  /// Pins the haptic tier (tests); null decides per gesture.
  final HapticTier? hapticTier;

  final ForkMachine machine;

  late final AnimationController bloom, armLeft, armRight, glyph, pulse;
  late final AnimationController flight, chrome, orbFade, shake;

  /// The finger's height (global), low-passed, which the chips ride while the
  /// fork is open; and the one-shot outward nudge of their chevrons (0..1).
  late final AnimationController fingerY, kick;

  /// Turns the transcript's own drag into the pull (see [ForkPull]); mount it
  /// with [SwipeForkGesture].
  late final ForkPull pull;

  /// Pull progress 0..1 (the arc and the pull haptics read this).
  final ForkValue pullValue = ForkValue();

  /// Slide progress 0..1 on the side being moved toward (the slide haptics).
  final ForkValue slideValue = ForkValue();

  final _Poke _frame = _Poke();

  /// The discoverability nudge, 0..1 (see [ForkPeek]); and whether it shows.
  final ForkValue peekValue = ForkValue();
  final ValueNotifier<bool> peekOn = ValueNotifier(false);

  /// Whether anything is on screen. False when idle.
  final ValueNotifier<bool> visible = ValueNotifier(false);

  // What the painters read. Kept after release so the exit animates from here.
  double viewTravel = 0;
  double viewP = 0;
  double thumbX = 0;
  double thumbY = 0;
  bool viewForked = false;
  bool viewSingle = false;
  ForkSide? viewArmed;
  ForkOption? viewLeft;
  ForkOption? viewRight;
  ForkExit exit = ForkExit.none;
  ForkOption? committed;

  /// The reason a commit failed, while the circle shows it.
  String? failReason;

  Offset _at = Offset.zero;
  List<ForkOption> _opts = const [];
  HapticRamp? _pullRamp;
  HapticRamp? _slideRamp;
  int _slideSign = 0;
  double _liftAtRelease = 0;
  bool _disposed = false;
  int _gen = 0;

  /// Repaint source for the overlay's painters.
  Listenable get repaint => Listenable.merge([
        _frame,
        bloom,
        armLeft,
        armRight,
        glyph,
        pulse,
        flight,
        chrome,
        orbFade,
        shake,
        fingerY,
        kick,
        peekValue,
      ]);

  /// How far the list is lifted right now, in points (positive = up). One
  /// number, read by [ForkLift] and by the overlay to find the gap.
  double get lift {
    if (!visible.value) {
      if (!peekOn.value) return 0;
      final t = peekValue.value;
      return ForkPeek.rise * math.sin(math.pi * Curves.easeOut.transform(t.clamp(0.0, 1.0)));
    }
    if (exit == ForkExit.none) return _gestureLift;
    return _liftAtRelease * (1 - flight.value.clamp(0.0, 1.0));
  }

  double get _gestureLift =>
      viewTravel +
      (viewSingle ? 0 : kForkBloomLift * bloom.value.clamp(0.0, 1.0));

  /// Ends the peek nudge (it finished, or its widget went away).
  void endPeek() {
    if (_disposed) return;
    peekOn.value = false;
    peekValue.value = 0;
  }

  /// The options captured at touch-down.
  List<ForkOption> get options => _opts;

  bool get busy => visible.value;

  /// The state a tick of the gesture is in.
  bool get active => machine.active;

  // ───────── touch-down ─────────

  /// Called when the list's own drag runs out of list at the newest message
  /// ([at] is the finger). Returns whether the fork may arm, and captures the
  /// options. False for a gate that is closed or a room with nothing to offer
  /// (the list then just bounces).
  bool prepare(Offset at) {
    if (_disposed || busy) return false;
    if (!canArm()) return false;
    final opts = forkOptionsFor(roomState());
    if (opts.isEmpty) return false;
    _opts = opts;
    _at = at;
    peekOn.value = false;
    return true;
  }

  /// Called when the drag is accepted: the list starts to lift.
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
    machine.begin(left: left, right: right);
    viewLeft = left;
    viewRight = right;
    viewSingle = machine.single;
    viewTravel = 0;
    viewP = 0;
    viewForked = false;
    viewArmed = null;
    thumbX = _at.dx;
    thumbY = _at.dy;
    exit = ForkExit.none;
    committed = null;
    failReason = null;
    _slideSign = 0;
    for (final c in [bloom, armLeft, armRight, glyph, pulse, flight, chrome, orbFade, shake, fingerY, kick]) {
      c.stop();
      c.value = 0;
    }
    peekOn.value = false;
    peekValue.value = 0;
    pullValue.value = 0;
    slideValue.value = 0;
    _pullRamp?.dispose();
    _slideRamp?.dispose();
    _pullRamp = HapticRamp.twoWay(pullValue, taps: 12, tier: hapticTier)
      ..beginGesture(tier: hapticTier);
    _slideRamp = HapticRamp.twoWay(
      slideValue,
      taps: 6,
      minIntensity: 0.2,
      maxIntensity: 0.7,
      tier: hapticTier,
    )..beginGesture(tier: hapticTier);
    visible.value = true;
    _frame.poke();
  }

  // ───────── drag ─────────

  /// The finger is [pos]; the list has been pulled [dy] points past its end.
  void move(double dy, Offset pos) {
    if (!machine.active) return;
    final events = machine.update(dy, pos.dx);
    thumbX = pos.dx;
    thumbY = pos.dy;
    for (final e in events) {
      switch (e) {
        case ForkEvent.forked:
          _tick(0.9, HapticKind.notch);
          viewForked = true;
          _spring(glyph, 1, _bloomSpring);
          if (!viewSingle) {
            _bloomChips(1);
            // The chips open where the finger is, and nudge outward once.
            fingerY.stop();
            fingerY.value = pos.dy;
            if (!calm) {
              kick.value = 0;
              kick.animateTo(1, duration: const Duration(milliseconds: 400));
            }
          }
          _pulse();
        case ForkEvent.unforked:
          viewForked = false;
          viewArmed = null;
          _spring(glyph, 0, _bloomSpring);
          if (!viewSingle) {
            _bloomChips(0);
            _spring(armLeft, 0, _bloomSpring);
            _spring(armRight, 0, _bloomSpring);
          }
        case ForkEvent.armed:
        case ForkEvent.swapped:
          _tick(0.85, HapticKind.arm);
          _armTo(machine.armed);
          _pulse();
        case ForkEvent.disarmed:
          _tick(0.3, HapticKind.soft);
          _armTo(null);
      }
    }
    if (viewForked && !viewSingle && fingerY.value != pos.dy) {
      _spring(fingerY, pos.dy, _followSpring);
    }
    viewTravel = machine.travel;
    viewP = machine.progress;
    viewArmed = machine.armed;
    final pulling = viewForked && !viewSingle;
    pullValue.value = viewP;
    if (pulling) {
      final sign = machine.dx < 0 ? -1 : 1;
      if (sign != _slideSign) {
        slideValue.value = 0;
        _slideSign = sign;
      }
      // The arm tick owns the last detent, so the ramp stops short of it.
      slideValue.value = machine.slide.clamp(0.0, 0.9).toDouble();
    } else {
      slideValue.value = 0;
      _slideSign = 0;
    }
    _frame.poke();
  }

  void _armTo(ForkSide? side) {
    _spring(armLeft, side == ForkSide.left ? 1 : 0, _bloomSpring);
    _spring(armRight, side == ForkSide.right ? 1 : 0, _bloomSpring);
  }

  void _bloomChips(double to) {
    if (calm) {
      bloom.animateTo(to, duration: const Duration(milliseconds: 150));
    } else {
      _spring(bloom, to, _bloomSpring);
    }
  }

  void _pulse() {
    if (calm) return;
    pulse.value = 0;
    pulse.animateTo(1, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  void _spring(AnimationController c, double to, SpringDescription d) {
    if (_disposed) return;
    if (calm) {
      c.animateTo(to, duration: const Duration(milliseconds: 150));
      return;
    }
    c.animateWith(SpringSimulation(d, c.value, to, c.velocity));
  }

  void _tick(double intensity, HapticKind kind) =>
      HapticTick.play(intensity, kind: kind, tier: hapticTier);

  // ───────── release ─────────

  void release(double vx) {
    if (!machine.active) return;
    final out = machine.end(vx);
    _endRamps();
    if (out.committed) {
      _commit(out.option!);
    } else {
      _cancel();
    }
  }

  /// A second finger, the app going to the background: no commit, a calm
  /// collapse.
  void cancelGesture() {
    if (!machine.active) return;
    machine.reset();
    _endRamps();
    _cancel();
  }

  void _endRamps() {
    pullValue.value = 0;
    slideValue.value = 0;
    _pullRamp?.dispose();
    _slideRamp?.dispose();
    _pullRamp = null;
    _slideRamp = null;
  }

  void _cancel() {
    exit = ForkExit.cancel;
    _liftAtRelease = _gestureLift;
    _tick(0.25, HapticKind.soft);
    _armTo(null);
    _bloomChips(0);
    _spring(glyph, 0, _bloomSpring);
    final back = _springBack(_cancelSpring);
    final fade = chrome.animateTo(1, duration: const Duration(milliseconds: 250));
    final gen = ++_gen;
    Future.wait([back, fade]).then((_) {
      if (gen == _gen) _finish();
    }, onError: (_) {});
    _frame.poke();
  }

  /// The list settles back down: a spring, or a short ease when calm.
  TickerFuture _springBack(SpringDescription d) => calm
      ? flight.animateTo(1, duration: const Duration(milliseconds: 150))
      : flight.animateWith(SpringSimulation(d, 0, 1, 0));

  Future<void> _commit(ForkOption option) async {
    final gen = ++_gen;
    committed = option;
    onCommitted?.call();
    exit = option.isVanish ? ForkExit.commitVanish : ForkExit.commitTalk;
    _liftAtRelease = _gestureLift;
    _tick(1, HapticKind.commit);
    _bloomChips(0);
    final flightDone = _springBack(_commitSpring);
    final faded = chrome.animateTo(1, duration: const Duration(milliseconds: 250));
    final result = _run(option);
    try {
      await Future.wait([flightDone, faded]);
    } catch (_) {}
    final err = await result;
    if (gen != _gen || _disposed) return;
    if (err == null) {
      if (gen == _gen) _finish();
      return;
    }
    // Failed: one shake, the reason, then a calm collapse.
    failReason = failureText?.call(err) ?? '';
    _tick(0.3, HapticKind.soft);
    _frame.poke();
    try {
      await shake.animateTo(1, duration: const Duration(milliseconds: 420));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (gen != _gen || _disposed) return;
      await orbFade.animateTo(1, duration: const Duration(milliseconds: 250));
    } catch (_) {}
    if (gen == _gen) _finish();
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
    exit = ForkExit.none;
    failReason = null;
    committed = null;
    visible.value = false;
    for (final c in [bloom, armLeft, armRight, glyph, pulse, flight, chrome, orbFade, shake, fingerY, kick]) {
      c.stop();
      c.value = 0;
    }
    _frame.poke();
  }

  void dispose() {
    _disposed = true;
    _pullRamp?.dispose();
    _slideRamp?.dispose();
    for (final c in [bloom, armLeft, armRight, glyph, pulse, flight, chrome, orbFade, shake, fingerY, kick]) {
      c.dispose();
    }
    visible.dispose();
    peekOn.dispose();
    _frame.dispose();
  }
}
