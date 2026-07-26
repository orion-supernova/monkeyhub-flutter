import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart' as cv;
import 'package:flutter/foundation.dart';

import '../env.dart';
import 'connection_health.dart' show ConnectionProbe;

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

  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    await _ensureInitialized();
    // The web client silently drops subscriptions registered before the
    // WebSocket finishes connecting (native queues them and replays on
    // connect). On a restored session, attach() subscribes before the socket
    // is up, which left the room list empty until a fresh login. Wait
    // (bounded) for the connection before registering.
    await _awaitConnected();
    final handle = await _c.subscribe(
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
    return Subscription._(handle);
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
  /// The timeout is short and the recent-probe short-circuit matters, because
  /// this runs once per subscription and a reconnect re-registers eight of them
  /// (see [ChatRepository.resubscribe]). With a 10s wait and a socket whose
  /// cached state is wedged, resubscribing serialised into over a minute of
  /// dead time — during which the app looked reconnected but received nothing.
  /// [ConnectionHealth] only resubscribes after a probe has round-tripped, so
  /// that path now skips the wait outright.
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

  /// Force the client to tear down and rebuild the socket. Needed on WEB: a
  /// backgrounded tab's socket can freeze WITHOUT the browser firing `onclose`,
  /// so the client's cached state stays stuck on `connected` and it never
  /// auto-reconnects. `probeConnection` reveals the deadness; this heals it.
  /// After a rebuild the caller must re-register subscriptions — the web client
  /// resets its query set on reconnect but never replays them.
  ///
  /// WEB ONLY in practice, and [ConnectionHealth] calls it only there. On
  /// native, convex_flutter implements `reconnect()` as `checkConnection()` —
  /// it re-runs `healthCheckQuery` and reports whether that succeeded, without
  /// touching the socket. It cannot do otherwise: the Rust client keeps its
  /// connection in a `OnceCell` and exposes no close/reconnect/dispose, and the
  /// Dart singleton throws if re-initialized. So on iOS/Android there is no way
  /// to rebuild a dead socket from here; recovery relies on the Rust client's
  /// own internal reconnect loop, with `probeConnection` as the observer.
  /// If a future convex_flutter release adds a real native reconnect, drop the
  /// `kIsWeb` guard in `ConnectionHealth._loop`.
  @override
  Future<bool> reconnect() async {
    try {
      return await _c.reconnect();
    } catch (_) {
      return false;
    }
  }

  dynamic _decode(String raw) {
    if (raw.isEmpty || raw == 'null') return null;
    return jsonDecode(raw);
  }
}

class Subscription {
  Subscription._(this._handle);
  final cv.SubscriptionHandle _handle;
  void cancel() => _handle.cancel();
}

class ConvexError implements Exception {
  ConvexError(this.message, [this.value]);
  final String message;
  final String? value;
  @override
  String toString() =>
      'ConvexError($message${value == null ? '' : ': $value'})';
}
