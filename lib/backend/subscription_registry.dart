import 'dart:async';

import 'package:flutter/foundation.dart';

/// Registers one subscription with the transport and returns its opaque handle.
typedef SubBinder = Future<Object> Function(
  String name,
  Map<String, dynamic> args,
  void Function(dynamic) onData,
  void Function(Object error)? onError,
);

/// Cancels one transport handle previously returned by a [SubBinder].
typedef SubCanceller = void Function(Object handle);

/// Every live subscription in the app, and how to put it back.
///
/// ───────── why this exists ─────────
///
/// Tearing the socket down and building a new one (see
/// `ConvexBackend.reconnect`) kills every subscription the old transport was
/// carrying. Before this class, recovery from that was a hand-maintained list
/// in `_resubscribeAll` — and it was wrong: family context, the two room-member
/// subscriptions, the group-call room banner and the group-call roster were all
/// missing from it, so they would have gone permanently silent behind a UI that
/// looked healthy. That is this codebase's oldest bug shape, and enumerating
/// call sites is what keeps reintroducing it.
///
/// So the list is not maintained by hand. Every subscription in the app is
/// created through `ConvexBackend.subscribe`, which registers here, so coverage
/// is total by construction and a new `subscribe()` call site anywhere gets
/// healing for free.
///
/// ───────── the three rules ─────────
///
///  * **A rebind never cancels the old handle.** After a transport rebuild the
///    handle's peer is already gone; cancelling it is a no-op at best and, on
///    the native path, used to panic across FFI. Cancellation is reachable only
///    from a caller's own [RegisteredSub.cancel].
///  * **Idempotence is by generation stamp, not a flag.** A `subscribe()` that
///    was in flight when the rebuild happened stamps the generation it *started*
///    with, so the trailing [rebindAll] still sees it as stale and re-binds it —
///    exactly once. A flag would have to guess whether that subscribe landed on
///    the old transport or the new one.
///  * **A cancel that lands mid-rebind wins.** The fresh handle is cancelled and
///    the entry dropped, rather than leaving a live subscription nobody holds.
///
/// ───────── the third way a subscription dies ─────────
///
/// [rebindAll] covers a rebuilt transport and [rebindFailed] covers a bind that
/// threw. Both are about the BIND. A third case slipped between them for a long
/// time: the bind succeeds, and then the query itself fails on the server —
///
///     GroupCallService invite error: ConvexError([Request ID: 4a3a41061ea800b9]
///     Server Error / Function execution timed out (maximum duration: 1s))
///
/// ...which on a small self-hosted box a cold module load can do all by itself.
/// The give-away in that report was that all THIRTY-SIX logged copies carried
/// the same request id. That is not thirty-six failures; it is one failed
/// result, cached against the query's read set and re-delivered on every later
/// transition. Nothing re-executes it, so the subscription is finished: the
/// handle is live, the registry considers the entry healthy, and the callback
/// never fires with data again. For the group-call ring that means the device
/// stops ringing for the rest of the session, which is exactly the
/// silent-behind-a-healthy-UI shape the class doc opens by describing.
///
/// So a delivered error re-binds the entry, [_maxHeals] times, backing off.
/// Central rather than per-call-site for the same reason as everything else
/// here: fifteen subscriptions get it without anyone remembering to ask.
class SubscriptionRegistry {
  SubscriptionRegistry({
    required SubBinder bind,
    required SubCanceller cancel,
    Duration healDelay = const Duration(seconds: 1),
    this.bindFirst = const {},
  })  : _bind = bind,
        _cancel = cancel,
        _healDelay = healDelay;

  final SubBinder _bind;
  final SubCanceller _cancel;

  /// Base backoff before re-binding a subscription whose QUERY errored. Each
  /// further attempt doubles it. Injectable so tests do not sleep.
  final Duration _healDelay;

  final Set<RegisteredSub> _live = {};

  /// Bumped by [rebindAll]. Entries carry the generation they were bound under.
  int _generation = 0;

  /// Live subscription count. Exposed for tests and leak assertions — a screen
  /// that forgets to cancel now retains its callbacks here, not just in the
  /// transport.
  @visibleForTesting
  int get liveCount => _live.length;

  /// Register a subscription and bind it to the current transport.
  Future<RegisteredSub> add(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    // Copied: the entry outlives the call, and a rebind re-sends these args
    // however long later. A caller reusing or mutating its map would otherwise
    // silently re-subscribe to something else.
    final entry = RegisteredSub._(
      this,
      name,
      Map<String, dynamic>.unmodifiable(args),
      onData,
      onError,
    );
    _live.add(entry);
    await entry._bindOnce(_generation);
    return entry;
  }

  /// Query names to re-bind ahead of everything else after a transport
  /// rebuild.
  ///
  /// Concurrent is not the same as simultaneous. The binds below all start in
  /// list order and queue into the transport in that order, and the backend
  /// answers them roughly in the order it receives them — so on a resumed app
  /// the one query the user is actually staring at can land behind a dozen
  /// they will never look at. Naming it here moves it to the front of that
  /// queue and costs nothing when the list is empty.
  ///
  /// Supplied at construction by the owner that knows which query that is (see
  /// `ConvexBackend`); this class deliberately knows no query names of its own.
  final Set<String> bindFirst;

  /// Re-register every live entry that is not already on [generation].
  ///
  /// Called after a transport rebuild. Binds run concurrently: they are
  /// independent, and serialising ~15 of them is precisely the dead time this
  /// whole change set exists to remove. [bindFirst] reorders them without
  /// serialising anything.
  Future<void> rebindAll(int generation) async {
    _generation = generation;
    final due = _live.where((e) => !e._cancelled && e._gen != generation);
    // Partitioned rather than sorted, which keeps it stable for free: `_live`
    // iterates in registration order, so entries of equal priority hold the
    // order they were registered in — which for a room is the order they
    // matter in.
    final stale = bindFirst.isEmpty
        ? due.toList()
        : [
            ...due.where((e) => bindFirst.contains(e._name)),
            ...due.where((e) => !bindFirst.contains(e._name)),
          ];
    await Future.wait(stale.map((e) => e._bindOnce(generation)));
  }

  /// Re-bind only the entries that have no live handle, because their bind
  /// threw.
  ///
  /// A `subscribe()` issued while the socket is down does not always queue: the
  /// web client throws `StateError('WebSocket not connected')` outright and
  /// erases the record it would otherwise have replayed, so that subscription
  /// is registered nowhere — not with the server, not in the client's own
  /// replay map. The caller cannot tell, because it was handed a perfectly
  /// ordinary [Subscription].
  ///
  /// Nothing else can heal that. A transport can only replay what it has, and
  /// [rebindAll] runs solely after a forced rebuild — which on web never
  /// happens, since its client replays for itself. So the app's own verified
  /// reconnect calls this, and it is the only thing standing between a slow
  /// handshake at sign-in and a room list that never updates again.
  ///
  /// Cheap when there is nothing to do, which is almost always.
  Future<void> rebindFailed() async {
    final broken =
        _live.where((e) => !e._cancelled && e._handle == null).toList();
    if (broken.isEmpty) return;
    await Future.wait(broken.map((e) => e._bindOnce(_generation)));
  }

  /// Drop every entry WITHOUT touching the transport.
  ///
  /// For the one case a rebind must not cover: the client is being thrown away
  /// and replaced by one pointed at a DIFFERENT deployment (see
  /// `ConvexBackend.rebind`). Every entry here carries args minted against the
  /// old server — a userId, a roomId — so re-binding them would ask a stranger's
  /// backend for documents by another backend's ids.
  ///
  /// Handles are abandoned rather than cancelled, for the reason in the class
  /// doc's first rule: their peer is already gone, and on the native path
  /// cancelling one across FFI used to panic.
  ///
  /// Entries are marked cancelled, so a caller still holding a [Subscription]
  /// and calling `cancel()` afterwards is a safe no-op rather than a reach into
  /// a disposed client.
  void abandonAll() {
    for (final e in _live) {
      e._cancelled = true;
      e._stopHealing();
      e._handle = null;
    }
    _live.clear();
  }

  void _forget(RegisteredSub e) => _live.remove(e);
}

/// One registered subscription. Returned by [SubscriptionRegistry.add].
class RegisteredSub {
  RegisteredSub._(
    this._registry,
    this._name,
    this._args,
    this._onData,
    this._onError,
  );

  final SubscriptionRegistry _registry;
  final String _name;
  final Map<String, dynamic> _args;
  final void Function(dynamic) _onData;
  final void Function(Object error)? _onError;

  /// The current transport handle, or null if the last bind failed.
  Object? _handle;

  /// Error deliveries since the last good one. Any successful delivery resets
  /// it, so a subscription that recovers gets its full budget back rather than
  /// carrying a grudge from an outage an hour ago.
  int _errorStreak = 0;

  /// The pending heal, if one is scheduled. Also the re-entry guard: a burst of
  /// error deliveries schedules ONE rebind, not one per delivery.
  Timer? _healTimer;

  /// How many delivered errors will be healed before the entry gives up.
  ///
  /// Bounded, because the error may be DETERMINISTIC — a function that throws
  /// for these args will throw again however many times it is re-run. Three
  /// attempts costs three extra executions and stops; unbounded retry would
  /// hammer the backend forever over a bad argument, which is a worse failure
  /// than the silent one it is trying to fix.
  static const _maxHeals = 3;

  /// Which registry generation [_handle] belongs to. -1 until the first bind
  /// completes, so a generation bump during that first bind still re-binds.
  int _gen = -1;

  bool _cancelled = false;

  Future<void> _bindOnce(int generation) async {
    if (_cancelled) return;
    Object handle;
    try {
      handle = await _registry._bind(
        _name,
        _args,
        _onDelivered,
        _onDeliveredError,
      );
    } catch (e) {
      // Leave [_gen] behind so the next rebind retries this entry. Reported
      // through the caller's own error path rather than thrown: one failed
      // subscription must not abort the rebind of the other fourteen.
      _onError?.call(e);
      return;
    }
    // The world may have moved while we were awaiting the bind.
    if (_cancelled || generation != _registry._generation) {
      _registry._cancel(handle);
      return;
    }
    // Deliberately does NOT cancel the previous handle — see the class doc.
    _handle = handle;
    _gen = generation;
  }

  /// A good delivery. Clears the error budget, then hands over untouched.
  void _onDelivered(dynamic data) {
    _errorStreak = 0;
    _onData(data);
  }

  /// An error delivery. The caller still hears about it exactly as before —
  /// healing is added ALONGSIDE their handler, never in place of it, because
  /// several call sites use the error to drive their own UI.
  void _onDeliveredError(Object error) {
    _onError?.call(error);
    _scheduleHeal();
  }

  void _scheduleHeal() {
    if (_cancelled || _healTimer != null || _errorStreak >= _maxHeals) return;
    _errorStreak++;
    _healTimer = Timer(_registry._healDelay * (1 << (_errorStreak - 1)), () {
      _healTimer = null;
      if (_cancelled) return;
      // Cancel first: unlike a rebind after a transport rebuild, this handle's
      // peer is very much alive, and binding a second one would leave two
      // subscriptions feeding the same callbacks forever. This is the one place
      // in this class the "a rebind never cancels" rule does not apply, and the
      // reason it does not is that the rule is about handles whose transport is
      // already gone.
      final old = _handle;
      _handle = null;
      if (old != null) _registry._cancel(old);
      // Failure here leaves [_handle] null, which is precisely what
      // [rebindFailed] looks for — the two healers hand off cleanly.
      unawaited(_bindOnce(_registry._generation));
    });
  }

  /// Stop any pending heal. Called from both teardown paths, so a timer can
  /// never fire into a disposed registry.
  void _stopHealing() {
    _healTimer?.cancel();
    _healTimer = null;
  }

  /// Deregister and cancel. Idempotent, and safe to call on a subscription
  /// whose transport was rebuilt out from under it.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _stopHealing();
    _registry._forget(this);
    final h = _handle;
    _handle = null;
    if (h != null) _registry._cancel(h);
  }
}
