import '../auth/session_guard.dart';
import '../auth/session_store.dart';
import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart' as cv;
import 'package:flutter/foundation.dart';

import '../diagnostics/diag_event.dart' show DiagSev;
import '../diagnostics/diag_log.dart';
import '../env.dart';
import 'connection_health.dart' show ConnectionProbe;
import 'server_store.dart';
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

  /// The deployment the live client was built against. Read back rather than
  /// re-derived, so [rebind] can tell "already pointed there" from "needs a new
  /// socket" even after [ServerStore] has moved on.
  String? _boundUrl;

  /// Which deployment the socket in hand actually talks to, or null before the
  /// first successful init.
  String? get boundUrl => _boundUrl;

  /// Whether the live client is out of step with [ServerStore] — i.e. a switch
  /// was saved but never applied. Should only ever be true mid-[rebind].
  bool get isStale =>
      _boundUrl != null && _boundUrl != ServerStore.instance.deploymentUrl;

  /// Throw the client away and build a new one against whatever [ServerStore]
  /// now says. Returns null on success, or the init error.
  ///
  /// This is the only supported way to change which server a running app talks
  /// to. The alternative — asking the user to force-quit — is not a settings
  /// change, it is an apology.
  ///
  /// Callers MUST have torn the session down first: signing out cancels every
  /// subscription and gets the final mutations onto the OLD server while it is
  /// still reachable. [ServerSwitch] owns that ordering; this method only
  /// handles the transport, and deliberately knows nothing about accounts.
  ///
  /// [keepSubscriptions] decides what happens to the query set, and the two
  /// answers are not interchangeable:
  ///
  ///  * **false** (a self-hosting switch) — abandon it. Every entry carries
  ///    args minted against the old backend, a userId or a roomId, and asking a
  ///    stranger's server for documents by another server's ids is worse than
  ///    asking nothing. The caller has signed out anyway.
  ///  * **true** (following a directive between the primary and the home
  ///    server) — re-register it. Those two hold replicated data, so every id
  ///    is still valid and the session is still live; dropping the query set
  ///    would blank the room list of a user who was told nothing happened.
  Future<Object?> rebind({bool keepSubscriptions = false}) async {
    final target = ServerStore.instance.deploymentUrl;
    DiagLog.connection('rebind-server', 'switching to ${_hostOf(target)}');
    if (!keepSubscriptions) _registry.abandonAll();
    // Both are statements about a socket that is about to stop existing.
    _lastProbeOkAt = null;
    _lastForcedReconnectAt = null;
    await cv.ConvexClient.shutdown();
    _initFuture = null;
    _initError = null;
    _boundUrl = null;
    final err = await initialize();
    if (err == null && keepSubscriptions) {
      // Fire-and-forget, for the reason [reconnect] spells out at length: these
      // subscribes are unbounded on a socket that has not handshaken yet, and
      // the caller's contract is "a fresh transport exists". Stale binds are
      // discarded by the registry's generation check.
      unawaited(
        _registry.rebindAll(++_generation).catchError((Object e) {
          DiagLog.connection('rebind', 'failed: $e', sev: DiagSev.warn);
        }),
      );
    }
    DiagLog.connection(
      'rebind-server',
      err == null ? 'ok (${_hostOf(target)})' : 'failed: $err',
      sev: err == null ? DiagSev.info : DiagSev.warn,
    );
    return err;
  }

  /// Host only — the same rule [DeviceReport] follows. A diagnostics line about
  /// a server switch must not be a place a full URL can leak into.
  static String _hostOf(String url) => Uri.tryParse(url)?.host ?? '?';

  Future<void> _doInit() async {
    final url = ServerStore.instance.deploymentUrl;
    if (url.isEmpty) {
      // Reachable only on a build whose `env.local` carries no CONVEX_URL and
      // whose user has not chosen a server yet. `_bootstrap` routes that state
      // to the server screen before it gets here, so this is the backstop for a
      // stray API call rather than the path anyone travels.
      _initFuture = null;
      throw const NoServerConfiguredError();
    }
    try {
      await cv.ConvexClient.initialize(
        cv.ConvexConfig(
          // NOT Env.convexUrl. The bundled deployment is only the default;
          // [ServerStore] answers which one is in force, so an install pointed
          // at a self-hosted backend builds its socket against that one
          // instead. The store is loaded before `runApp`, so it is always
          // populated by the time anything reaches here.
          deploymentUrl: url,
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
      _boundUrl = url;
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

  // These four methods are the app's entire backend surface — ChatApi, CallApi,
  // GroupCallApi and ChatRepository all hold this same singleton, so wrapping
  // them captures 100% of traffic without touching ~300 call sites. DiagLog is
  // a static no-op until a device is allowlisted, so the cost here is one bool
  // read per call.

  /// Attach the bearer token, unless this function is one the backend serves
  /// without a session.
  ///
  /// Every request in the app funnels through [query], [mutation] and
  /// [action], which is the only reason a 162-function auth migration did not
  /// also become a 101-call-site client migration: identity is added here, once,
  /// rather than threaded through every method on `ChatApi`.
  Map<String, dynamic> _withToken(String name, Map<String, dynamic> args) {
    if (!SessionGuard.instance.requiresToken(name)) return args;
    final token = SessionStore.instance.token;
    // No token but the function wants one: send it anyway and let the server
    // answer SESSION_UNKNOWN. Failing here instead would produce a different
    // error shape for the same condition, and `SessionGuard` would never see
    // the signal that drives the sign-out.
    return {...args, SessionGuard.identityArg: token ?? ''};
  }

  Future<dynamic> query(String name, Map<String, dynamic> rawArgs) async {
    await _ensureInitialized();
    final args = _withToken(name, rawArgs);
    final corr = DiagLog.apiStart('query', name, args);
    final sw = Stopwatch()..start();
    try {
      final decoded = _decode(await _c.query(name, args));
      DiagLog.apiEnd(corr, name, sw.elapsedMilliseconds, decoded);
      return decoded;
    } catch (e) {
      DiagLog.apiError(corr, name, sw.elapsedMilliseconds, e);
      SessionGuard.instance.noteError(e);
      rethrow;
    }
  }

  Future<dynamic> mutation(String name, Map<String, dynamic> rawArgs) async {
    await _ensureInitialized();
    final args = _withToken(name, rawArgs);
    final corr = DiagLog.apiStart('mutation', name, args);
    final sw = Stopwatch()..start();
    try {
      final decoded = _decode(await _c.mutation(name: name, args: args));
      DiagLog.apiEnd(corr, name, sw.elapsedMilliseconds, decoded);
      return decoded;
    } catch (e) {
      if (_isVoidResultThrow(e)) {
        // A normalised void result is a SUCCESS. Logging it as an error would
        // put a spurious red line in the timeline on every `calls:accept`.
        DiagLog.apiEnd(corr, name, sw.elapsedMilliseconds, null);
        return null;
      }
      DiagLog.apiError(corr, name, sw.elapsedMilliseconds, e);
      SessionGuard.instance.noteError(e);
      rethrow;
    }
  }

  Future<dynamic> action(String name, Map<String, dynamic> rawArgs) async {
    await _ensureInitialized();
    final args = _withToken(name, rawArgs);
    final corr = DiagLog.apiStart('action', name, args);
    final sw = Stopwatch()..start();
    try {
      final decoded = _decode(await _c.action(name: name, args: args));
      DiagLog.apiEnd(corr, name, sw.elapsedMilliseconds, decoded);
      return decoded;
    } catch (e) {
      if (_isVoidResultThrow(e)) {
        DiagLog.apiEnd(corr, name, sw.elapsedMilliseconds, null);
        return null;
      }
      DiagLog.apiError(corr, name, sw.elapsedMilliseconds, e);
      SessionGuard.instance.noteError(e);
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
    // The room transcript goes to the front of the queue after a forced socket
    // rebuild. Named here, at construction, rather than exposed as a setter:
    // every test fake of this class would otherwise have to implement one, and
    // this is a fixed property of the app rather than something a caller tunes.
    // See [SubscriptionRegistry.bindFirst] for why order matters at all.
    bindFirst: const {'messages:list'},
  );

  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> rawArgs, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    await _ensureInitialized();
    final args = _withToken(name, rawArgs);
    final entry = await _registry.add(
      name,
      args,
      onData: onData,
      // A subscription is where a revoked session shows up FIRST in a live
      // app: the user is sitting on the chat list, touching nothing, when
      // another device signs them out. Without this the socket would just go
      // quiet and the screen would look merely stale.
      onError: (Object error) {
        SessionGuard.instance.noteError(error);
        onError?.call(error);
      },
    );
    return Subscription._(entry);
  }

  /// Re-register any subscription whose original `subscribe()` threw.
  ///
  /// Call on every verified reconnect. A subscribe issued while the socket was
  /// down can fail outright rather than queueing — see
  /// [SubscriptionRegistry.rebindFailed], which is also where the reason it
  /// cannot heal itself is written down. A no-op in the normal case.
  Future<void> repairSubscriptions() => _registry.rebindFailed();

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
    // The onUpdate/onError wrappers already exist, so subscription logging is
    // free here. Deliveries are recorded by SHAPE and TIMING only (see
    // DiagLog.subUpdate) — fifteen live subscriptions handing over full
    // documents would bury every other category in the timeline.
    final corr = DiagLog.subOpen(name, args);
    // How long the screen behind this subscription had nothing to show. Only
    // the first delivery is timed: every one after it is the server telling us
    // something changed, which is not a wait anybody sat through.
    final sinceOpen = Stopwatch()..start();
    var awaitingFirst = true;
    return await _c.subscribe(
      name: name,
      args: args,
      onUpdate: (raw) {
        try {
          final decoded = _decode(raw);
          if (awaitingFirst) {
            awaitingFirst = false;
            DiagLog.subFirstData(corr, name, sinceOpen.elapsedMilliseconds);
            sinceOpen.stop();
          }
          DiagLog.subUpdate(corr, name, decoded);
          onData(decoded);
        } catch (e) {
          DiagLog.subError(corr, name, e);
          onError?.call(e);
        }
      },
      onError: (msg, value) {
        final err = ConvexError(msg, value);
        DiagLog.subError(corr, name, err);
        onError?.call(err);
      },
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
      await query('releases:latest', const {
        'channel': 'stable',
      }).timeout(timeout);
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
      // Logged, not silent. Whether a rebuild ran is the single most useful
      // fact in a stuck-connection capture, and it used to be the one thing
      // the diagnostics file could not tell you — a whole investigation had to
      // infer it from which events were *absent*.
      DiagLog.connection('rebuild', 'suppressed (rate-limited)');
      return false;
    }
    _lastForcedReconnectAt = DateTime.now();
    // A brand-new socket has proved nothing, so the subscribe path must not
    // skip its connectivity wait on the strength of a probe that round-tripped
    // over the socket we just destroyed.
    _lastProbeOkAt = null;
    DiagLog.connection('rebuild', 'started');
    try {
      await _ensureInitialized();
      final ok = await _c.forceReconnect();
      if (!ok) {
        DiagLog.connection('rebuild', 'failed', sev: DiagSev.warn);
        return false;
      }
      if (_rebuildOrphansSubscriptions) {
        // Deliberately NOT awaited. The caller's contract is "a fresh
        // transport exists" — [ConnectionHealth] caps this call at
        // `rebuildTimeout` (6s) and reads a timeout as `false`, while
        // `rebindAll` fans out over ~15 subscribes that are unbounded on a
        // socket which has not handshaken yet. So awaiting it reported a
        // rebuild that had genuinely succeeded as a failure, and the loop
        // backed off as though nothing had happened.
        //
        // Safe to let run: every entry is stamped with [_generation], and a
        // bind that lands after a later rebuild superseded it is discarded by
        // the stale-generation check in [SubscriptionRegistry].
        unawaited(
          _registry.rebindAll(++_generation).catchError((Object e) {
            DiagLog.connection('rebind', 'failed: $e', sev: DiagSev.warn);
          }),
        );
      }
      DiagLog.connection('rebuild', 'ok (transport only, not yet verified)');
      return true;
    } catch (e) {
      DiagLog.connection('rebuild', 'failed: $e', sev: DiagSev.warn);
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

/// No deployment to connect to at all: `env.local` carries no `CONVEX_URL` and
/// the user has not entered a server.
///
/// Its own type rather than a bare Exception because the boot screen treats it
/// completely differently from a connection failure — nothing is wrong, the app
/// simply has not been told where to go yet, so it opens the server screen
/// instead of an error.
class NoServerConfiguredError implements Exception {
  const NoServerConfiguredError();
  @override
  String toString() => 'No Convex deployment configured.';
}

class ConvexError implements Exception {
  ConvexError(this.message, [this.value]);
  final String message;
  final String? value;
  @override
  String toString() =>
      'ConvexError($message${value == null ? '' : ': $value'})';
}
