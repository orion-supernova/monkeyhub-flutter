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
class SubscriptionRegistry {
  SubscriptionRegistry({required SubBinder bind, required SubCanceller cancel})
      : _bind = bind,
        _cancel = cancel;

  final SubBinder _bind;
  final SubCanceller _cancel;

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

  /// Re-register every live entry that is not already on [generation].
  ///
  /// Called after a transport rebuild. Binds run concurrently: they are
  /// independent, and serialising ~15 of them is precisely the dead time this
  /// whole change set exists to remove.
  Future<void> rebindAll(int generation) async {
    _generation = generation;
    final stale =
        _live.where((e) => !e._cancelled && e._gen != generation).toList();
    await Future.wait(stale.map((e) => e._bindOnce(generation)));
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

  /// Which registry generation [_handle] belongs to. -1 until the first bind
  /// completes, so a generation bump during that first bind still re-binds.
  int _gen = -1;

  bool _cancelled = false;

  Future<void> _bindOnce(int generation) async {
    if (_cancelled) return;
    Object handle;
    try {
      handle = await _registry._bind(_name, _args, _onData, _onError);
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

  /// Deregister and cancel. Idempotent, and safe to call on a subscription
  /// whose transport was rebuilt out from under it.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _registry._forget(this);
    final h = _handle;
    _handle = null;
    if (h != null) _registry._cancel(h);
  }
}
