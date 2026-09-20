import 'dart:async';

import 'package:flutter/widgets.dart';

import 'drop_channel.dart';
import 'drop_channel_events.dart';
import 'drop_classifier.dart';
import 'drop_item.dart';
import 'drop_zone_registry.dart';

/// A drop that has just happened, kept alive only long enough to be animated.
@immutable
class DropLanding {
  const DropLanding({
    required this.at,
    required this.plan,
    required this.serial,
    required this.accepted,
  });

  /// Where the pointer was when the user let go, in global coordinates.
  final Offset at;

  /// What landed, re-planned against everything the drop finally revealed —
  /// which in a browser is the first moment names and sizes exist at all.
  final DropPlan plan;

  /// Distinguishes two drops in the same place. The overlay keys its burst on
  /// this so a second drop restarts the animation rather than being swallowed
  /// as "no change".
  final int serial;

  /// False when the drop landed on empty space or on a zone that refused it —
  /// the burst is then a dissolve rather than a splash.
  final bool accepted;
}

/// The one place a desktop drag is turned into something this app understands.
///
/// ### Why the position does not live in [notifyListeners]
///
/// A drag reports a position at the display's refresh rate. Routing that
/// through `ChangeNotifier` would rebuild every listener sixty times a second
/// for the whole length of a drag, which on the chat list means rebuilding
/// however many rows are registered — while the compositor is already busy
/// with the overlay's blur. So there are two channels out of here:
///
///  * [pointer] — a `ValueNotifier<Offset>` that ticks constantly and is
///    listened to by exactly two things: the ghost stack and the verdict chip.
///  * [notifyListeners] — fires only when the ANSWER changes: a session
///    starting or ending, the target zone changing, the plan changing.
///
/// The zones themselves are not listeners at all. Each holds its own
/// `ValueNotifier` and is driven directly through its handle, so crossing from
/// one chat row to the next repaints two rows rather than the list.
class DropController extends ChangeNotifier {
  DropController._({DropZoneRegistry? registry})
      : _registry = registry ?? DropZoneRegistry.instance;

  static final DropController instance = DropController._();

  /// Test seam — an isolated controller over an isolated registry, so a widget
  /// test can drive a synthetic drag without touching the singleton.
  @visibleForTesting
  factory DropController.forTest(DropZoneRegistry registry) =>
      DropController._(registry: registry);

  final DropZoneRegistry _registry;

  /// Whether this platform has a drag to receive at all. False on iOS and
  /// Android, where nothing is ever installed and every drop affordance is
  /// absent rather than inert.
  static bool get isSupported => DropChannel.isSupported;

  bool _started = false;

  /// Ticks with the pointer. Never null so listeners need no branch; read it
  /// only while [active].
  final ValueNotifier<Offset> pointer = ValueNotifier(Offset.zero);

  /// The most recent completed drop, for the landing animation. Cleared by the
  /// overlay once it has finished playing.
  final ValueNotifier<DropLanding?> landing = ValueNotifier(null);

  DropSnapshot? _snapshot;
  DropSnapshot? get snapshot => _snapshot;

  /// Whether a drag is over the window right now.
  bool get active => _snapshot != null;

  DropZoneHandle? _target;
  DropZoneHandle? get target => _target;

  DropPlan _plan = DropPlan.empty;

  /// What would happen if the user let go this instant.
  ///
  /// Planned against the TARGET's policy, so the same three files read
  /// "Send 3 photos" over a room the user may post in and "Not allowed here"
  /// over one a guardian has restricted — before anything is let go.
  DropPlan get plan => _plan;

  int _serial = 0;

  /// Installs the platform listener. Safe to call repeatedly; only the first
  /// call does anything.
  Future<void> start() async {
    if (_started || !isSupported) return;
    _started = true;
    await DropChannel.instance.start(DropChannelHandlers(
      onEnter: _onEnter,
      onMove: _onMove,
      onLeave: _onLeave,
      onPerform: _onPerform,
    ));
  }

  // ──────────────────────────────── events ────────────────────────────────

  void _onEnter(DropSnapshot snapshot, Offset at) {
    _snapshot = snapshot.isEmpty ? null : snapshot;
    pointer.value = at;
    if (_snapshot == null) {
      _clearTarget();
      notifyListeners();
      return;
    }
    _retarget(at, entering: true);
    notifyListeners();
  }

  void _onMove(Offset at) {
    if (_snapshot == null) return;
    pointer.value = at;
    _retarget(at);
  }

  void _onLeave() {
    if (_snapshot == null && _target == null) return;
    _snapshot = null;
    _plan = DropPlan.empty;
    _clearTarget();
    DropChannel.instance.setAccepting(false);
    notifyListeners();
  }

  Future<void> _onPerform(DropBundle bundle, Offset at) async {
    // The zone is resolved one last time from the drop's own coordinates
    // rather than trusted from the last move. A drop can arrive without a
    // preceding move — a quick flick into the window, or a platform that
    // coalesced the last update away — and delivering to a stale target would
    // put somebody's photo in the wrong chat.
    pointer.value = at;
    final zone = _registry.hitTest(at);

    // Re-planned against the real facts. This is the moment a browser drag
    // stops guessing: names, sizes and types all exist for the first time, so
    // a `.mkv` that hovered as an anonymous "file" is finally known to be one
    // that will go as a document — which is what the post-drop notice says.
    final resolved = planFor(
      bundle.toSnapshot(),
      policy: zone?.policy ?? DropPolicy.permissive,
    );

    _snapshot = null;
    _plan = DropPlan.empty;
    _clearTarget();
    DropChannel.instance.setAccepting(false);
    landing.value = DropLanding(
      at: at,
      plan: resolved,
      serial: ++_serial,
      accepted: zone != null && resolved.sendsAnything,
    );
    notifyListeners();

    if (zone == null || !resolved.sendsAnything) {
      // Nothing to hand over. The staged copies are still ours to clean up —
      // a drop onto empty space has already cost a disk copy on macOS.
      DropChannel.instance.release(bundle);
      return;
    }

    try {
      await zone.onDrop(bundle);
    } catch (e, s) {
      debugPrint('drop: delivery failed: $e\n$s');
    } finally {
      DropChannel.instance.release(bundle);
    }
  }

  // ─────────────────────────────── targeting ───────────────────────────────

  void _retarget(Offset at, {bool entering = false}) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final zone = _registry.hitTest(at);

    if (identical(zone, _target) && !entering) {
      if (zone != null) {
        final rect = zone.rect;
        if (rect != null) zone.onMove(at - rect.topLeft);
      }
      return;
    }

    _releaseTarget();
    _target = zone;
    final next = planFor(snapshot, policy: zone?.policy ?? DropPolicy.permissive);
    final changed = entering || next != _plan;
    _plan = next;

    if (zone != null) {
      final rect = zone.rect;
      zone.onEnter(rect == null ? Offset.zero : at - rect.topLeft);
    }
    DropChannel.instance.setAccepting(zone != null && next.sendsAnything);
    if (changed || entering) notifyListeners();
  }

  void _clearTarget() => _releaseTarget();

  /// Tells the current target the pointer has gone, and forgets it.
  ///
  /// Guarded on [DropZoneHandle.detached], which is the only protection
  /// against a zone whose widget left the tree mid-drag: this controller holds
  /// the last reference to it, and its notifier was disposed with its state.
  /// A route popped or a chat row rebuilt under a live drag is ordinary, not
  /// exotic.
  void _releaseTarget() {
    final target = _target;
    _target = null;
    if (target != null && !target.detached) target.onLeave();
  }

  // ───────────────────────────── test seams ─────────────────────────────
  //
  // The platform half is a method channel on macOS and four DOM listeners in a
  // browser, and neither exists under `flutter test`. These are the same four
  // events those two produce, spelled so a test can drive a whole drag — which
  // is the only way to exercise the targeting, which is where the bugs are.

  @visibleForTesting
  void debugEnter(DropSnapshot snapshot, Offset at) => _onEnter(snapshot, at);

  @visibleForTesting
  void debugMove(Offset at) => _onMove(at);

  @visibleForTesting
  void debugLeave() => _onLeave();

  @visibleForTesting
  Future<void> debugPerform(DropBundle bundle, Offset at) =>
      _onPerform(bundle, at);

  /// Clears a finished landing. Called by the overlay when its burst is done,
  /// rather than on a timer here, so the animation owns its own length.
  void clearLanding(int serial) {
    if (landing.value?.serial == serial) landing.value = null;
  }

  @override
  void dispose() {
    pointer.dispose();
    landing.dispose();
    super.dispose();
  }
}
