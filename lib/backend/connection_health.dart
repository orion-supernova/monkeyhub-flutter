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
///  * **A successful probe is the ONLY reconnect edge**, and it always fires
///    [onReconnected]. Previously the banner's own watchdog hid itself on a
///    successful probe without telling anyone, so subscriptions stayed dead
///    behind a healthy-looking UI. Conversely, a `connected` event on the
///    stream used to mark us online on its own — see [_onSocketState] for why
///    that produced a flapping banner and a resubscribe storm.
///  * **[onReconnected] only runs after a probe returned true.** That matters
///    because every `subscribe()` first waits (up to 10s) for the socket to
///    come up; re-subscribing while down would burn that timeout once per
///    subscription. Confirming first keeps resubscribe fast.
class ConnectionHealth extends ChangeNotifier {
  ConnectionHealth({
    required ConnectionProbe backend,
    required Future<void> Function() onReconnected,
    required bool Function() isActive,
    this.graceDelay = const Duration(milliseconds: 1200),
    this.stalledAfter = const Duration(seconds: 12),
    this.firstProbeTimeout = const Duration(seconds: 7),
    this.probeTimeout = const Duration(seconds: 10),
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
  ///
  /// Generous on purpose: "can't reach server" is an alarming thing to show for
  /// what is often just a slow round-trip. This deployment is small enough that
  /// a single-document mutation has been observed exceeding Convex's 1s
  /// function limit under load, so a few seconds of silence is normal, not a
  /// failure.
  final Duration stalledAfter;

  /// The first probe of an outage is sized for a server under load rather than an
  /// idle one — too tight (e.g. 4s) and the app reports itself offline whenever
  /// the Wi-Fi/cellular radio is merely re-associating after screen unlock.
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

  /// Tracks whether the current retry is user/resume initiated or an automatic
  /// background attempt during [ConnectionPhase.stalled].
  bool _isManualOrResumeRetry = false;

  /// When the in-flight probe started, used to debounce rapid cancellation attempts.
  DateTime? _lastProbeStartedAt;

  StreamSubscription<bool>? _socketSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Timer? _graceTimer;
  Timer? _stalledTimer;

  /// Whether the banner's clocks are currently running. Tracked separately from
  /// the [Timer] handles because a fired timer stays non-null, so the handles
  /// alone can't answer "are we armed?".
  bool _uiTimersArmed = false;

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
        if (usable) retryNow(manual: true);
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
    _disarmUiTimers();
    _interruptAttempt(force: true);
    _wake();
    super.dispose();
  }

  // ───────── inputs ─────────

  /// The socket stream is a hint, never a verdict — in both directions.
  ///
  /// The native client's state enum has exactly two values, `connected` and
  /// `connecting`, and it toggles between them every time the Rust client runs
  /// a lap of its own internal reconnect backoff. Marking ourselves online on
  /// the rising edge (as this used to) meant every one of those laps produced:
  /// banner hides → grace → "reconnecting…" → "can't reach server · tap to
  /// retry" → hides → repeat, with a full [_onReconnected] — 8 subscriptions
  /// and a signaling restart — fired on each pass. That flap is what a stuck
  /// reconnect looked like from the outside, and it hammered the server that
  /// was already too slow to answer.
  ///
  /// So a `connected` edge now only means "worth checking again right now":
  /// reset the backoff and wake the loop. [_markOnline] is reachable solely
  /// from a probe that actually round-tripped.
  void _onSocketState(bool connected) {
    final wasUp = _socketUp;
    _socketUp = connected;
    if (!connected) {
      _beginHealing();
      return;
    }
    if (wasUp) return;
    if (_healing) {
      _attempt = 0;
      _interruptAttempt(force: true);
      _wake();
    } else if (_phase != ConnectionPhase.online) {
      // Not healing yet somehow reporting an outage — verify and reconcile.
      unawaited(retryNow(manual: true));
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
      // A round-trip that actually completed is the same class of evidence a
      // probe gives us — stronger, even, since it rode the live socket rather
      // than opening a query to test it. Reconcile on it. Without this the
      // heartbeat could succeed every 30s while the banner sat on
      // "reconnecting…", because clearing the phase was reachable ONLY from a
      // probe, and the probe only runs when the loop is unparked.
      if (_phase != ConnectionPhase.online) _markOnline();
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
    if (foreground) retryNow(manual: true);
  }

  /// Force an immediate attempt: reset the backoff and skip any pending wait.
  ///
  /// Pass [manual] = true when invoked by user tap or explicit resume event.
  Future<void> retryNow({bool manual = true}) async {
    if (_disposed) return;
    _attempt = 0;
    if (_healing) {
      if (manual) {
        _isManualOrResumeRetry = true;
        _setRetrying(true);
      }
      _interruptAttempt(force: manual);
      _wake();
      return;
    }
    // Reported healthy. Verify rather than trust — this is the path a manual
    // tap and a resume both take when the socket is frozen-but-"connected".
    if (_retrying) return;
    if (manual) _isManualOrResumeRetry = true;
    _setRetrying(true);
    _lastProbeStartedAt = DateTime.now();
    final ok = await _backend.probeConnection(timeout: probeTimeout);
    _setRetrying(false);
    _isManualOrResumeRetry = false;
    if (_disposed) return;
    if (!ok) {
      _beginHealing();
    } else if (_phase != ConnectionPhase.online) {
      _markOnline();
    }
  }

  // ───────── the recovery loop ─────────

  int _attempt = 0;

  /// Non-null only while an attempt is in flight. Completing it makes [_loop]
  /// stop waiting on that attempt and start a fresh one immediately.
  Completer<void>? _interrupt;

  void _interruptAttempt({bool force = false}) {
    if (!force && _lastProbeStartedAt != null) {
      final elapsed = DateTime.now().difference(_lastProbeStartedAt!);
      // Debounce: do not cancel a probe that started less than 1.5s ago
      // unless force is true (manual tap/socket state event).
      if (elapsed < const Duration(milliseconds: 1500)) return;
    }
    final c = _interrupt;
    _interrupt = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Sentinel distinguishing "interrupted" from a real `false` result.
  static final Object _interrupted = Object();

  /// Await [work] unless [gate] fires first, in which case return null.
  Future<bool?> _raceInterrupt(Future<bool> work, Completer<void> gate) async {
    final r = await Future.any<Object?>([
      work.then<Object?>((v) => v).catchError((Object _) => false),
      gate.future.then<Object?>((_) => _interrupted),
    ]);
    return identical(r, _interrupted) ? null : r as bool;
  }

  void _beginHealing() {
    if (_disposed || _healing) return;
    _healing = true;
    _attempt = 0;
    // Note the loop itself arms the UI clocks, and only once it is genuinely
    // probing — see [_armUiTimers].
    _loop();
  }

  /// Start the two clocks that escalate the banner: [graceDelay] → reconnecting,
  /// [stalledAfter] → stalled. Holding off for the grace window keeps short
  /// blips from flashing UI.
  ///
  /// These are armed by [_loop] when it starts an attempt, NOT by
  /// [_beginHealing], because a healing episode does not imply an observation.
  /// The loop parks whenever the app is backgrounded or signed out and issues no
  /// probes at all; arming on `_beginHealing` meant the clocks ran straight
  /// through that park, so the banner escalated to "reconnecting…" and then
  /// "can't reach server" on nothing but elapsed time. That is exactly what put
  /// a permanent, untappable "reconnecting…" over the login screen of an app
  /// whose connection was fine — the loop parked before the first probe (no
  /// session yet), and nothing could clear a phase that no probe had set.
  void _armUiTimers() {
    if (_uiTimersArmed) return;
    _uiTimersArmed = true;
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
  }

  void _disarmUiTimers() {
    _uiTimersArmed = false;
    _graceTimer?.cancel();
    _graceTimer = null;
    _stalledTimer?.cancel();
    _stalledTimer = null;
  }

  Future<void> _loop() async {
    while (_healing && !_disposed) {
      if (!_foreground || !_isActive()) {
        _setRetrying(false);
        _isManualOrResumeRetry = false;
        _disarmUiTimers();
        _setPhase(ConnectionPhase.online);
        await _sleep(null);
        continue;
      }
      _armUiTimers();

      final gate = _interrupt = Completer<void>();
      // When stalled, only reflect retrying spinner if this is an explicit
      // manual tap/resume attempt or attempt 0. Automatic background retries
      // keep the stalled banner UI steady ("can't reach server · tap to retry").
      final showRetrying = _phase != ConnectionPhase.stalled || _isManualOrResumeRetry || _attempt == 0;
      if (showRetrying) _setRetrying(true);

      _lastProbeStartedAt = DateTime.now();
      final quick = _attempt == 0 ? firstProbeTimeout : probeTimeout;
      var ok = await _raceInterrupt(
        _backend.probeConnection(timeout: quick),
        gate,
      );

      // Web only, and deliberately so. There, `reconnect()` is a genuine
      // teardown and rebuild, which the platform needs: a backgrounded tab's
      // socket can freeze WITHOUT the browser firing `onclose`, so the client
      // never heals it on its own.
      //
      // On native it is not a reconnect at all. convex_flutter implements it as
      // `checkConnection()` — the very same health-check query the probe above
      // just ran, with the client's own 30s operation timeout. It cannot touch
      // the socket even in principle: the Rust client holds its connection in a
      // OnceCell and exposes no close, reconnect or dispose. Calling it here
      // bought nothing, blocked this loop for up to 30s per attempt (which is
      // what made "tap to retry" feel dead), and tripled the query load on a
      // server we already suspect of being overloaded. The Rust client runs its
      // own reconnect loop; the probe above is how we learn whether it worked.
      if (ok == false && kIsWeb && _healing && !_disposed) {
        final healed = await _raceInterrupt(
          _backend.reconnect().timeout(probeTimeout, onTimeout: () => false),
          gate,
        );
        ok = healed == null || healed
            ? healed
            : await _raceInterrupt(
                _backend.probeConnection(timeout: probeTimeout),
                gate,
              );
      }
      if (_interrupt == gate) _interrupt = null;
      if (_disposed) return;
      if (ok == null) {
        continue;
      }
      _setRetrying(false);
      _isManualOrResumeRetry = false;

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
  ///
  /// Deliberately unthrottled. The repeated resubscribes that used to hammer
  /// the server came from [_onSocketState] marking us online on an unverified
  /// stream edge, and they are fixed there, at the source: reaching this method
  /// now costs a full healing episode plus a probe that actually round-tripped,
  /// which can happen at most once per outage. Rate-limiting the one call that
  /// keeps subscriptions alive would only reintroduce this file's oldest bug —
  /// a healthy-looking UI over dead subscriptions.
  void _markOnline() {
    // Idempotent. [noteRoundTrip] can reconcile while a probe is still in
    // flight, and that probe then lands on this method too — one reconnect
    // edge, so one [_onReconnected].
    if (!_healing && _phase == ConnectionPhase.online) return;
    _healing = false;
    _attempt = 0;
    _consecutiveRoundTripFailures = 0;
    _disarmUiTimers();
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
