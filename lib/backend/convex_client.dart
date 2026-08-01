import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart' as cv;
import 'package:flutter/foundation.dart';

import '../env.dart';
import 'connection_health.dart' show ConnectionProbe;
import 'subscription_registry.dart';

/// Thin wrapper around [cv.ConvexClient] that decodes JSON results and
/// surfaces typed errors. v02's auth model does not use JWTs — every
/// call passes `userId` as a parameter, so we don't touch setAuth here.
///
/// Initialization is lazy and idempotent: every API call awaits
/// [_ensureInitialized], so a sign-in tap will retry init if the boot-time
/// attempt failed (e.g. transient network or FFI race).
class ConvexBackend implements ConnectionProbe {
  ConvexBackend._();
  static final ConvexBackend instance = ConvexBackend._();

  Future<void>? _initFuture;
  Object? _initError;

  /// Returns null on success, or the underlying init error.
  Future<Object?> initialize() async {
    try {
      await _ensureInitialized();
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<void> _ensureInitialized() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      await cv.ConvexClient.initialize(
        cv.ConvexConfig(
          deploymentUrl: Env.convexUrl,
          clientId: Env.clientId,
          // A cheap, public, unauthenticated query used as the connectivity probe
          // (see [probeConnection]) and by the client's own reconnect().
          healthCheckQuery: 'releases:latest',
          // Pinned rather than left at the package's 30s default. Dart's
          // `.timeout()` does not cancel the future underneath it, so every
          // probe [ConnectionHealth] abandons leaves a query running to
          // completion here. At 30s an outage spent stacking orphaned queries
          // against the very server it was waiting on.
          operationTimeout: const Duration(seconds: 15),
        ),
      );
      _initError = null;
    } catch (e) {
      _initError = e;
      // Reset so the next call retries fresh instead of returning the failed
      // future indefinitely.
      _initFuture = null;
      rethrow;
    }
  }

  Object? get initError => _initError;

  cv.ConvexClient get _c => cv.ConvexClient.instance;

  Future<dynamic> query(String name, Map<String, dynamic> args) async {
    await _ensureInitialized();
    final raw = await _c.query(name, args);
    return _decode(raw);
  }

  Future<dynamic> mutation(String name, Map<String, dynamic> args) async {
    await _ensureInitialized();
    try {
      return _decode(await _c.mutation(name: name, args: args));
    } catch (e) {
      if (_isVoidResultThrow(e)) return null;
      rethrow;
    }
  }

  Future<dynamic> action(String name, Map<String, dynamic> args) async {
    await _ensureInitialized();
    try {
      return _decode(await _c.action(name: name, args: args));
    } catch (e) {
      if (_isVoidResultThrow(e)) return null;
      rethrow;
    }
  }

  /// The web ConvexClient throws `Exception('No result in mutation/action
  /// response')` for a void (null-returning) mutation/action even when the
  /// server reported `success: true`; the native client returns the string
  /// `"null"` without error. Convex void mutations are legitimate (e.g.
  /// `calls:accept`, `calls:sendSignal`, `calls:consumeSignal`, `calls:end`),
  /// so normalise the web throw to a null result to match native behaviour.
  /// Without this, `CallService.acceptIncoming` sees a spurious failure and
  /// immediately ends the call — accept-then-instant-hangup on web.
  static bool _isVoidResultThrow(Object e) {
    if (!kIsWeb) return false;
    final s = e.toString();
    return s.contains('No result in mutation response') ||
        s.contains('No result in action response');
  }

  /// Every live subscription, and how to put it back after [reconnect] throws
  /// the transport away. See [SubscriptionRegistry] for why the list is derived
  /// rather than hand-maintained.
  late final SubscriptionRegistry _registry = SubscriptionRegistry(
    bind: _bindSubscription,
    cancel: (h) => (h as cv.SubscriptionHandle).cancel(),
  );

  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    await _ensureInitialized();
    final entry = await _registry.add(
      name,
      args,
      onData: onData,
      onError: onError,
    );
    return Subscription._(entry);
  }

  Future<Object> _bindSubscription(
    String name,
    Map<String, dynamic> args,
    void Function(dynamic) onData,
    void Function(Object error)? onError,
  ) async {
    // Web only. There the client silently drops subscriptions registered
    // before the socket finishes connecting, so a restored session subscribed
    // into the void and the room list stayed empty until a fresh login. The
    // native client has no such window: `ConvexClient::subscribe` pushes into
    // an unbounded queue its worker drains once the socket is up. Waiting there
    // was pure cost — up to 3s per subscription, and a rebind re-registers
    // fifteen of them.
    if (kIsWeb) await _awaitConnected();
    return await _c.subscribe(
      name: name,
      args: args,
      onUpdate: (raw) {
        try {
          onData(_decode(raw));
        } catch (e) {
          onError?.call(e);
        }
      },
      onError: (msg, value) => onError?.call(ConvexError(msg, value)),
    );
  }

  /// When [probeConnection] last round-tripped successfully. Better evidence
  /// than [isConnected], which reads the client's cached socket state and can
  /// sit wedged on `connecting` after an OS suspension while queries work fine.
  DateTime? _lastProbeOkAt;

  /// How long a successful probe stands in for [isConnected] in
  /// [_awaitConnected]. Short enough that it can't mask a socket that died
  /// right after we checked.
  static const _probeFreshness = Duration(seconds: 10);

  /// Resolve once the socket is connected, or after [timeout] regardless — so
  /// a still-down socket never blocks a subscription forever (the caller's
  /// onError path and the client's own reconnect handle that case). No-op when
  /// already connected, which is the steady state after the first connect.
  ///
  /// Polls [isConnected] rather than listening to [connectionState] so that the
  /// concurrent attach() calls on boot (each subscribing several queries) can't
  /// collide on a single-subscription stream.
  ///
  /// Web only — see [_bindSubscription]. The timeout is short and the
  /// recent-probe short-circuit matters even there, because this runs once per
  /// subscription and a rebind re-registers fifteen of them. With a 10s wait
  /// and a socket whose cached state is wedged, resubscribing serialised into
  /// over a minute of dead time — during which the app looked reconnected but
  /// received nothing.
  Future<void> _awaitConnected({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (isConnected) return;
    final ok = _lastProbeOkAt;
    if (ok != null && DateTime.now().difference(ok) < _probeFreshness) return;
    const step = Duration(milliseconds: 100);
    var waited = Duration.zero;
    while (!isConnected && waited < timeout) {
      await Future.delayed(step);
      waited += step;
    }
  }

  @override
  Stream<bool> get connectionState =>
      _c.connectionState.map((s) => s == cv.WebSocketConnectionState.connected);

  @override
  bool get isConnected {
    try {
      return _c.isConnected;
    } catch (_) {
      return false;
    }
  }

  /// Ground-truth connectivity check: round-trips the cheap no-arg health
  /// query and returns true if the server responds within [timeout].
  ///
  /// Why this exists: after a long OS suspension the WebSocket can silently
  /// die while the native client's `connectionState` stays wedged on
  /// `connecting`/`reconnecting` and never re-emits `connected`. That leaves
  /// the "reconnecting…" banner stuck even though a query would actually
  /// succeed. Issuing a real query both reveals the true state AND prods the
  /// native client to rebuild a dead socket. This is the ground truth that
  /// [ConnectionHealth] drives its whole state machine from.
  @override
  Future<bool> probeConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await query('releases:latest', const {'channel': 'stable'}).timeout(timeout);
      _lastProbeOkAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// When [reconnect] last actually tore the socket down.
  DateTime? _lastForcedReconnectAt;

  /// Minimum spacing between forced teardowns. Enough to outlast a handshake
  /// and let the fresh socket answer a probe, and no more.
  ///
  /// Was 12s, sized around the web client's self-inflicted double-socket churn
  /// (one `reconnect()` producing two connections a second apart). That churn
  /// is fixed at the source now — on web by `_abandonSocket`, and on native it
  /// never existed: `force_reconnect` holds a build lock across the whole
  /// teardown-and-rebuild, so there is no window for a second socket.
  static const _minForcedReconnectInterval = Duration(seconds: 5);

  /// Bumped by each successful rebuild; stamps registry entries so a
  /// subscribe that was in flight across the rebuild still gets re-bound.
  int _generation = 0;

  /// Whether a forced rebuild orphans the subscriptions we are holding.
  ///
  /// Native: yes. A fresh Rust `ConvexClient` starts with an empty query set
  /// and the old handles' peer tasks have already exited, so every subscription
  /// must be re-registered from here.
  ///
  /// Web: no. The vendored client replays its own `_subscriptions` map into
  /// each new socket (`_replaySubscriptions`), so re-registering would create a
  /// second live copy of every query and orphan the first.
  static const _rebuildOrphansSubscriptions = !kIsWeb;

  /// Tear the socket down and build a new one, then put every subscription back.
  ///
  /// This is the only way to recover a socket that has gone silent without
  /// closing — the ordinary outcome of a phone resuming after a long sleep,
  /// where the NAT binding expired or the interface changed and nothing was
  /// sent to find out. Left alone, convex-rs notices only via a 30s
  /// `SERVER_INACTIVITY_THRESHOLD` measured on a monotonic clock, which does
  /// not advance while the device is asleep and so effectively restarts at
  /// resume; every probe in that window parks on the dead socket for its full
  /// timeout and tells us nothing. That is the whole "stuck on reconnecting for
  /// half a minute" report.
  ///
  /// Returns true when a fresh transport exists. **That is not a verdict about
  /// connectivity** — `force_reconnect` returns as soon as the socket worker is
  /// spawned, not once it has handshaken. [ConnectionHealth] must still probe.
  ///
  /// Rate-limited: without a floor, a server that is merely down would get a
  /// teardown per backoff rung, and each rebuild throws away a query set that
  /// then has to be re-registered. Returning false when suppressed is not a
  /// verdict either; the caller falls through to its normal failure path.
  @override
  Future<bool> reconnect() async {
    final last = _lastForcedReconnectAt;
    if (last != null &&
        DateTime.now().difference(last) < _minForcedReconnectInterval) {
      return false;
    }
    _lastForcedReconnectAt = DateTime.now();
    // A brand-new socket has proved nothing, so the subscribe path must not
    // skip its connectivity wait on the strength of a probe that round-tripped
    // over the socket we just destroyed.
    _lastProbeOkAt = null;
    try {
      await _ensureInitialized();
      final ok = await _c.forceReconnect();
      if (!ok) return false;
      if (_rebuildOrphansSubscriptions) {
        await _registry.rebindAll(++_generation);
      }
      return true;
    } catch (e) {
      debugPrint('ConvexBackend.reconnect: $e');
      return false;
    }
  }

  dynamic _decode(String raw) {
    if (raw.isEmpty || raw == 'null') return null;
    return jsonDecode(raw);
  }
}

class Subscription {
  Subscription._(this._entry);
  final RegisteredSub _entry;

  /// Deregisters and cancels. Idempotent, and safe on a subscription whose
  /// transport was rebuilt out from under it.
  void cancel() => _entry.cancel();
}

class ConvexError implements Exception {
  ConvexError(this.message, [this.value]);
  final String message;
  final String? value;
  @override
  String toString() =>
      'ConvexError($message${value == null ? '' : ': $value'})';
}
