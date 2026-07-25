import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// What the UI should say about connectivity.
enum ConnectionPhase {
  /// Socket verified live. Nothing shown.
  online,

  /// Down, but not long enough to alarm anyone — a plain "reconnecting…".
  reconnecting,

  /// Down long enough that it may not fix itself. The banner offers a manual
  /// retry. Recovery attempts continue underneath regardless.
  stalled,
}

/// The slice of [ConvexBackend] that [ConnectionHealth] needs. Exists so tests
/// can drive the state machine with a fake instead of a live Convex client —
/// `ConvexBackend implements ConnectionProbe` and needed no other change.
abstract class ConnectionProbe {
  bool get isConnected;
  Stream<bool> get connectionState;
  Future<bool> probeConnection({Duration timeout});
  Future<bool> reconnect();
}

/// Runs an async job, collapsing overlapping requests into exactly one re-run.
///
/// Written for [ConnectionHealth.onReconnected]. Re-subscribing recreates ~6
/// subscriptions, so requests genuinely do overlap — and the previous
/// "bail if already running" guard *dropped* them. When the dropped request was
/// the real reconnect, its subscriptions were never re-registered and the app
/// went quiet until a restart. Collapsing (rather than queueing every request)
/// is the right shape here because the job is idempotent: one more run after the
/// current one is always enough to reflect the latest state.
class CoalescingJob {
  CoalescingJob(this._run);
  final Future<void> Function() _run;

  bool _running = false;
  bool _queued = false;

  /// True while the job is executing. Exposed for tests.
  bool get isRunning => _running;

  Future<void> call() async {
    if (_running) {
      _queued = true;
      return;
    }
    _running = true;
    try {
      await _run();
    } finally {
      _running = false;
      if (_queued) {
        _queued = false;
        await call();
      }
    }
  }
}

/// Single owner of "are we actually connected, and if not, what is being done
/// about it".
///
/// ───────── why this class exists ─────────
///
/// A socket can stop working in two ways, and the client's own
/// `connectionState` is unreliable for both:
///
///   1. **It dies and reconnects.** The convex_flutter web client resets its
///      query set on reconnect and NEVER replays subscriptions, so
///      rooms/messages/typing/friends all go silent while the client believes
///      it is subscribed.
///   2. **It freezes with no `onclose`.** Nothing is emitted at all, so the
///      client reports `connected` forever and never reconnects. Conversely,
///      after a long OS suspension the native stream can wedge on
///      `connecting`/`reconnecting` and never re-emit `connected` even though
///      queries work fine.
///
/// So the stream is a hint, not truth. Ground truth is a real round-trip
/// ([ConnectionProbe.probeConnection], which also prods the native client into
/// rebuilding a dead socket). This class treats the stream as one input among
/// several, and a successful probe as authoritative.
///
/// ───────── the guarantees ─────────
///
///  * **Recovery never gives up** while foregrounded and signed in. Attempts
///    back off to one per 15s and continue indefinitely. Previously the resume
///    handler probed once and gave up, so a probe issued while the Wi-Fi radio
///    was still reassociating after a screen unlock left the app wedged on
///    "reconnecting…" until the next foreground — which never came, because the
///    app was already foreground.
///  * **A successful probe is a reconnect edge**, always firing
///    [onReconnected]. Previously the banner's own watchdog hid itself on a
///    successful probe without telling anyone, so subscriptions stayed dead
///    behind a healthy-looking UI.
///  * **[onReconnected] only runs after a probe returned true.** That matters
///    because every `subscribe()` first waits (up to 10s) for the socket to
///    come up; re-subscribing while down would burn that timeout once per
///    subscription. Confirming first keeps resubscribe fast.
class ConnectionHealth extends ChangeNotifier {
  ConnectionHealth({
    required ConnectionProbe backend,
    required Future<void> Function() onReconnected,
    required bool Function() isActive,
    this.graceDelay = const Duration(milliseconds: 800),
    this.stalledAfter = const Duration(milliseconds: 3500),
    this.firstProbeTimeout = const Duration(seconds: 2),
    this.probeTimeout = const Duration(seconds: 5),
    this.backoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
    ],
    this.heartbeatFailureThreshold = 2,
    bool watchConnectivity = true,
  }) : _backend = backend,
       _onReconnected = onReconnected,
       _isActive = isActive,
       _watchConnectivity = watchConnectivity;

  final ConnectionProbe _backend;

  /// Re-register every subscription and flush stuck sends. Called on every
  /// verified transition back to online.
  final Future<void> Function() _onReconnected;

  /// Whether there is a signed-in session worth healing for. Recovery parks
  /// while this is false rather than hammering a server we have no identity on.
  final bool Function() _isActive;

  /// How long the socket must be down before the banner appears at all — short
  /// blips shouldn't flash UI.
  final Duration graceDelay;

  /// How long before "reconnecting…" escalates to the manual-retry state.
  final Duration stalledAfter;

  /// The first probe of an outage is short: it is usually diagnosing an already
  /// dead socket, and a fast answer gets us to the reconnect+retry cycle sooner.
  final Duration firstProbeTimeout;
  final Duration probeTimeout;

  /// Waits between attempts. The final entry repeats forever.
  final List<Duration> backoff;

  /// Consecutive failed app round-trips (see [noteRoundTrip]) that mean the
  /// socket is frozen despite reporting `connected`.
  final int heartbeatFailureThreshold;

  final bool _watchConnectivity;

  ConnectionPhase _phase = ConnectionPhase.online;
  ConnectionPhase get phase => _phase;

  /// A probe or reconnect is in flight. Drives the banner's spinner so a manual
  /// retry visibly does something.
  bool _retrying = false;
  bool get isRetrying => _retrying;

  StreamSubscription<bool>? _socketSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Timer? _graceTimer;
  Timer? _stalledTimer;

  /// Last value seen from the socket stream, so we can spot rising edges.
  bool _socketUp = true;

  /// A recovery loop is running. Not the same as "offline": the loop keeps
  /// running while parked in the background.
  bool _healing = false;
  bool _disposed = false;

  /// True while the app is foreground. Recovery parks when false — probing a
  /// suspended app's dead socket accomplishes nothing and costs battery.
  bool _foreground = true;

  int _consecutiveRoundTripFailures = 0;

  /// Completes to break the current backoff sleep early (manual retry,
  /// connectivity change, or returning to the foreground).
  Completer<void>? _sleeper;

  // ───────── lifecycle ─────────

  /// Begin watching. Call once, after the backend has initialized successfully.
  void start() {
    _socketUp = _backend.isConnected;
    _socketSub?.cancel();
    _socketSub = _backend.connectionState.listen(_onSocketState);
    if (_watchConnectivity) _startConnectivityWatch();
    if (!_socketUp) _beginHealing();
  }

  /// OS interface changes are only ever a nudge to retry *now* instead of
  /// waiting out the backoff. Never a verdict — see the class doc.
  void _startConnectivityWatch() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final usable =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);
        if (usable) retryNow();
      });
    } catch (_) {
      // Unsupported platform — the backoff loop is the backstop.
    }
  }

  @override
  void dispose() {
    if (_disposed) return; // idempotent: the loop may race a widget teardown
    _disposed = true;
    _healing = false;
    _socketSub?.cancel();
    _connectivitySub?.cancel();
    _graceTimer?.cancel();
    _stalledTimer?.cancel();
    _wake();
    super.dispose();
  }

  // ───────── inputs ─────────

  void _onSocketState(bool connected) {
    final wasUp = _socketUp;
    _socketUp = connected;
    if (connected && !wasUp) {
      // A genuine reconnect. The web client dropped every subscription.
      _markOnline();
    } else if (!connected) {
      _beginHealing();
    }
  }

  /// Report the outcome of an ordinary app round-trip (the presence heartbeat).
  /// This is the only continuous detector for a socket that has frozen while
  /// still reporting `connected` — the stream says nothing and, being
  /// foreground, no resume event is coming either.
  void noteRoundTrip({required bool ok}) {
    if (_disposed) return;
    if (ok) {
      _consecutiveRoundTripFailures = 0;
      return;
    }
    _consecutiveRoundTripFailures++;
    if (_consecutiveRoundTripFailures >= heartbeatFailureThreshold) {
      _consecutiveRoundTripFailures = 0;
      _beginHealing();
    }
  }

  /// Park recovery in the background; on return to the foreground, retry at
  /// once — a suspended app almost always wakes with a stale socket.
  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (foreground) retryNow();
  }

  /// Force an immediate attempt: reset the backoff and skip any pending wait.
  /// Safe to call repeatedly — a probe already in flight is left to finish.
  Future<void> retryNow() async {
    if (_disposed) return;
    _attempt = 0;
    if (_healing) {
      _wake();
      return;
    }
    // Reported healthy. Verify rather than trust — this is the path a manual
    // tap and a resume both take when the socket is frozen-but-"connected".
    if (_retrying) return;
    _setRetrying(true);
    final ok = await _backend.probeConnection(timeout: probeTimeout);
    _setRetrying(false);
    if (_disposed) return;
    if (!ok) {
      _beginHealing();
    } else if (_phase != ConnectionPhase.online) {
      _markOnline();
    }
  }

  // ───────── the recovery loop ─────────

  int _attempt = 0;

  void _beginHealing() {
    if (_disposed || _healing) return;
    _healing = true;
    _attempt = 0;

    // Hold off on any UI: most outages resolve inside the grace window.
    _graceTimer?.cancel();
    _graceTimer = Timer(graceDelay, () {
      if (_disposed || !_healing) return;
      _setPhase(ConnectionPhase.reconnecting);
    });
    _stalledTimer?.cancel();
    _stalledTimer = Timer(stalledAfter, () {
      if (_disposed || !_healing) return;
      _setPhase(ConnectionPhase.stalled);
    });

    _loop();
  }

  Future<void> _loop() async {
    while (_healing && !_disposed) {
      if (!_foreground || !_isActive()) {
        // Parked. setForeground(true) / retryNow() wakes us.
        await _sleep(null);
        continue;
      }

      _setRetrying(true);
      final quick = _attempt == 0 ? firstProbeTimeout : probeTimeout;
      var ok = await _backend.probeConnection(timeout: quick);
      if (!ok && _healing && !_disposed) {
        // Prod the client into tearing down and rebuilding the socket, then ask
        // again — reconnect() alone reports optimistically on some platforms.
        await _backend.reconnect();
        if (!_healing || _disposed) break;
        ok = await _backend.probeConnection(timeout: probeTimeout);
      }
      _setRetrying(false);

      if (_disposed) return;
      if (ok) {
        _markOnline();
        return;
      }

      _attempt++;
      await _sleep(_backoffFor(_attempt));
    }
  }

  Duration _backoffFor(int attempt) {
    if (backoff.isEmpty) return const Duration(seconds: 15);
    final i = attempt - 1;
    return i < backoff.length ? backoff[i] : backoff.last;
  }

  /// Interruptible wait. A null [d] waits indefinitely (parked), until [_wake].
  Future<void> _sleep(Duration? d) {
    final c = Completer<void>();
    _sleeper = c;
    Timer? t;
    if (d != null) {
      t = Timer(d, () {
        if (!c.isCompleted) c.complete();
      });
    }
    return c.future.whenComplete(() {
      t?.cancel();
      if (_sleeper == c) _sleeper = null;
    });
  }

  void _wake() {
    final s = _sleeper;
    _sleeper = null;
    if (s != null && !s.isCompleted) s.complete();
  }

  /// Verified online. Always re-registers subscriptions: we may have arrived
  /// here from a probe success that the socket stream never reported, and the
  /// web client does not replay subscriptions after a reconnect.
  void _markOnline() {
    _healing = false;
    _attempt = 0;
    _consecutiveRoundTripFailures = 0;
    _graceTimer?.cancel();
    _stalledTimer?.cancel();
    _wake();
    _setPhase(ConnectionPhase.online);
    // Fire-and-forget: a resubscribe failure must not stall the state machine,
    // and a socket that dies mid-resubscribe re-enters healing on its own.
    _onReconnected().catchError((Object e) {
      debugPrint('ConnectionHealth.onReconnected: $e');
    });
  }

  void _setPhase(ConnectionPhase p) {
    if (_phase == p) return;
    _phase = p;
    if (!_disposed) notifyListeners();
  }

  void _setRetrying(bool v) {
    if (_retrying == v) return;
    _retrying = v;
    if (!_disposed) notifyListeners();
  }
}
