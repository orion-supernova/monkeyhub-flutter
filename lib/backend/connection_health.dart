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
///   1. **It dies and reconnects.** Both clients replay their own query set
///      across this now (convex-rs `resend_ongoing_queries_mutations`; the
///      vendored web client's `_replaySubscriptions`), so data comes back on its
///      own — but the stream reports it as a `connecting`/`connected` pair, and
///      convex-rs emits that pair on every lap of its internal backoff whether
///      or not anything was wrong.
///   2. **It freezes with no `onclose`.** Nothing is emitted at all, so the
///      client reports `connected` forever and never reconnects. This is the
///      common case after a long background: the NAT binding expired or the
///      interface changed while the device slept, and nothing on either side
///      has any reason to notice. convex-rs's own detector for it is a 30s
///      inactivity check on a MONOTONIC clock — which does not advance during
///      sleep, so it has learned nothing by the time we resume.
///
/// So the stream is a hint, not truth. Ground truth is a real round-trip
/// ([ConnectionProbe.probeConnection]) — and when even that cannot get through,
/// [ConnectionProbe.reconnect] tears the transport down and builds a new one,
/// which is the only exit from case 2. This class treats the stream as one
/// input among several, and a successful probe as authoritative.
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
///  * **[onReconnected] only runs after a probe returned true.** It is cheap
///    now — subscriptions restore themselves (see above, and
///    `SubscriptionRegistry` for the forced-rebuild case), so all that is left
///    is flushing sends that failed while the socket was down. Confirming
///    first still matters: re-posting into a dead socket just re-fails them.
///  * **A successful rebuild is not a verdict either.** [ConnectionProbe.reconnect]
///    returns once a fresh transport exists, not once it has connected — see
///    `ConvexBackend.reconnect`. It buys a socket worth probing, nothing more.
class ConnectionHealth extends ChangeNotifier {
  ConnectionHealth({
    required ConnectionProbe backend,
    required Future<void> Function() onReconnected,
    required bool Function() isActive,
    this.graceDelay = const Duration(milliseconds: 1200),
    Duration? initialGraceDelay,
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
    this.backgroundRebuildThreshold = const Duration(seconds: 20),
    this.rebuildAfterAttempt = 2,
    this.rebuildTimeout = const Duration(seconds: 6),
    this.connectivityRetryThrottle = const Duration(seconds: 3),
    this.maxStalledRearms = 2,
    this.minLoopInterval = const Duration(milliseconds: 750),
    DateTime Function() now = DateTime.now,
    Stream<bool>? connectivity,
    bool watchConnectivity = true,
  }) : initialGraceDelay = initialGraceDelay ?? (graceDelay == const Duration(milliseconds: 1200) ? const Duration(milliseconds: 2500) : graceDelay),
       _backend = backend,
       _onReconnected = onReconnected,
       _isActive = isActive,
       _now = now,
       _connectivity = connectivity,
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
  final Duration initialGraceDelay;

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

  /// A background gap at least this long means the socket is presumed dead and
  /// gets rebuilt on sight, without spending a probe timeout confirming it.
  ///
  /// Measured on the WALL clock, deliberately. The failure this targets is a
  /// socket whose NAT binding expired or whose interface changed while the
  /// device slept, and convex-rs's own detector for that is monotonic — it does
  /// not advance during sleep, so it has learned nothing by the time we resume.
  final Duration backgroundRebuildThreshold;

  /// How many failed probes before the loop escalates to a rebuild. Above zero
  /// so a merely slow server does not get its socket torn down on one miss.
  final int rebuildAfterAttempt;

  /// Ceiling on a rebuild. A rebuild that is taking this long has stopped being
  /// the fast path it exists to be, so fall through and probe.
  final Duration rebuildTimeout;

  /// Minimum spacing between retries triggered by OS interface changes. Both
  /// platforms emit several of these per unlock.
  final Duration connectivityRetryThrottle;

  /// How many times one healing episode may push the "can't reach server"
  /// alarm back on evidence of progress. Capped because uncapped, a socket
  /// flapping every few seconds would defer the alarm forever — a permanently
  /// broken connection that never says so.
  final int maxStalledRearms;

  /// The part of a backoff wait that no wake may cut short. See [_sleepAtLeast].
  final Duration minLoopInterval;

  /// Injectable wall clock. Tests advance it instantly instead of waiting.
  final DateTime Function() _now;

  /// Injectable connectivity signal (true = a usable interface exists).
  final Stream<bool>? _connectivity;

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

  /// True while the non-healing "verify" probe in [retryNow] is in flight.
  /// Separate from [_retrying], which is a UI flag: using the UI flag as a
  /// mutex is what made tap-to-retry a no-op for up to a full probe timeout.
  bool _verifying = false;

  StreamSubscription<bool>? _socketSub;
  StreamSubscription<Object?>? _connectivitySub;

  /// When the app last went to the background, or null while foreground.
  DateTime? _backgroundedAt;

  /// Set when we already know the socket is probably dead — rebuild before
  /// wasting a probe timeout on it. Consumed by [_loop].
  bool _wantRebuild = false;

  DateTime? _lastConnectivityRetryAt;

  /// Consecutive interrupted attempts. Guards against a socket edge storm
  /// spinning [_loop] with neither backoff nor progress.
  int _interruptsInARow = 0;

  /// How many times [_noteProgress] has already pushed the stalled alarm back
  /// this episode.
  int _stalledRearms = 0;

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
  ///
  /// Re-entrant: `_bootstrap()` re-runs from the boot-error RETRY button, and
  /// leaving the old subscriptions attached doubled every socket edge and every
  /// interface change — including the retries they trigger.
  void start() {
    if (_disposed) return;
    _socketUp = _backend.isConnected;
    _socketSub?.cancel();
    _socketSub = _backend.connectionState.listen(_onSocketState);
    _connectivitySub?.cancel();
    _connectivitySub = null;
    if (_watchConnectivity) _startConnectivityWatch();
    if (!_socketUp) _beginHealing();
  }

  /// OS interface changes are only ever a nudge to retry *now* instead of
  /// waiting out the backoff. Never a verdict — see the class doc.
  void _startConnectivityWatch() {
    try {
      final stream = _connectivity ??
          Connectivity().onConnectivityChanged.map(
                (results) => results.isNotEmpty &&
                    !results.contains(ConnectivityResult.none),
              );
      _connectivitySub = stream.listen((usable) {
        if (!usable) return;
        // Throttled, and non-manual. Both matter. iOS and Android each emit a
        // burst of interface transitions per unlock, and `manual: true` forces
        // an interrupt — so unthrottled manual retries killed the in-flight
        // probe over and over and the loop never got an answer out of any of
        // them.
        final n = _now();
        final last = _lastConnectivityRetryAt;
        if (last != null && n.difference(last) < connectivityRetryThrottle) {
          return;
        }
        _lastConnectivityRetryAt = n;
        _noteProgress();
        retryNow(manual: false);
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
      _noteProgress();
      _wake();
      // Deliberately NOT [_interruptAttempt]. An edge is a hint that whatever
      // is already in flight is now worth waiting for, and the probe in flight
      // is registered in the very query set convex-rs resends on reconnect —
      // so it is about to resolve. Killing it threw away exactly the evidence
      // the edge was telling us to gather, and since convex-rs emits an edge at
      // the top of every internal backoff lap, edges arriving faster than a
      // probe resolves spun [_loop] on `ok == null` forever: no backoff, no UI,
      // no answer.
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
  ///
  /// And past [backgroundRebuildThreshold], "stale" is the wrong word: the
  /// socket is very likely open and dead, with nothing on either side that will
  /// notice. Rebuild it on sight rather than spending a probe timeout learning
  /// what the length of the gap already told us.
  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _backgroundedAt = _now();
      return;
    }
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since != null &&
        _now().difference(since) >= backgroundRebuildThreshold) {
      _wantRebuild = true;
    }
    retryNow(manual: true);
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
    // A pending rebuild belongs to the loop, which is the only path that knows
    // how to rebuild and then probe. Without this the resume case fell straight
    // through to the verify below and spent a probe timeout on the very socket
    // the background gap already told us was dead — which is the whole bug.
    // Note the socket almost always still claims `connected` here: nothing on
    // either side of a NAT-expired connection has any reason to say otherwise.
    if (_wantRebuild) {
      _beginHealing();
      return;
    }

    // Reported healthy. Verify rather than trust — this is the path a manual
    // tap takes when the socket is frozen-but-"connected".
    //
    // The verify is interruptible and guarded by its own flag. It used to bail
    // on `_retrying`, which is the *banner's* spinner flag, so a user tapping
    // "tap to retry" during an in-flight verify did nothing at all for up to a
    // full probe timeout — on the one screen whose entire purpose is to make
    // something happen.
    if (_verifying) {
      if (!manual) return; // an automatic nudge defers to the one in flight
      _interruptAttempt(force: true);
    }
    _verifying = true;
    if (manual) _isManualOrResumeRetry = true;
    _setRetrying(true);
    final gate = _interrupt = Completer<void>();
    _lastProbeStartedAt = _now();
    final ok = await _raceInterrupt(
      _backend.probeConnection(timeout: firstProbeTimeout),
      gate,
    );
    if (_interrupt == gate) _interrupt = null;
    _verifying = false;
    if (_disposed) return;
    // Superseded: the successor owns the outcome, including the spinner.
    if (ok == null) return;
    _setRetrying(false);
    _isManualOrResumeRetry = false;
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
      final elapsed = _now().difference(_lastProbeStartedAt!);
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
  /// Armed by [_loop] only after a probe has actually FAILED — never by
  /// [_beginHealing], and never merely because an attempt is starting.
  ///
  /// Two separate bugs live at this line, and both were "the banner is on and
  /// the connection is fine":
  ///
  ///  * Arming in [_beginHealing] ran the clocks straight through the park the
  ///    loop takes while backgrounded or signed out, so the banner escalated on
  ///    nothing but elapsed time — a permanent, untappable "reconnecting…" over
  ///    the login screen of an app whose connection was fine.
  ///  * Arming when an attempt *starts* made every socket-state blip a banner,
  ///    because the loop begins an attempt on a bare `connecting` edge. That
  ///    edge is not evidence (see [_onSocketState]), and on native it is
  ///    routine: convex-rs toggles `connecting` on each lap of its own internal
  ///    reconnect, and it resends the whole query set when it comes back, so
  ///    those laps are invisible to everything except this banner. A server
  ///    hanging up periodically therefore produced a phone that showed
  ///    "reconnecting…" more or less permanently while messages flowed
  ///    normally. Four commits of grace-delay tuning were all attempts to hide
  ///    this by making the window wider than the flap.
  ///
  /// The cost is that a genuine outage takes one probe timeout longer to
  /// surface — which is the right trade. A banner that is wrong is worse than a
  /// banner that is late, and the message a user just sent already shows its own
  /// pending state meanwhile.
  void _armUiTimers() {
    if (_uiTimersArmed) return;
    _uiTimersArmed = true;
    _graceTimer?.cancel();
    //Slightly longer grace (3s) for the initial handshake (attempt 0) on launch/resume
    //so normal 1-2s WebSocket SSL handshakes never flash a false-alarm banner.
    final delay = _attempt == 0 ? initialGraceDelay : graceDelay;
    _graceTimer = Timer(delay, () {
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
    _stalledRearms = 0;
    _graceTimer?.cancel();
    _graceTimer = null;
    _stalledTimer?.cancel();
    _stalledTimer = null;
  }

  /// Something happened that is genuine evidence recovery is moving: a socket
  /// `connected` edge, or the OS reporting a usable interface. Notably NOT a
  /// successful rebuild — that only says a fresh transport exists, and it says
  /// it just as confidently on a phone in airplane mode.
  ///
  /// None of these are verdicts, so none of them clears the banner. But pushing
  /// the "can't reach server · tap to retry" alarm back is right, because that
  /// alarm is a claim that nothing is happening — and it used to be on a fixed
  /// clock from the first failed probe, so it fired on schedule no matter how
  /// much progress had been made since.
  ///
  /// Capped at [maxStalledRearms] per episode: uncapped, a socket flapping
  /// every few seconds would defer the alarm forever, which is the opposite
  /// failure — a connection that is genuinely broken and never says so.
  ///
  /// [_uiTimersArmed] stays latched. That latch correctly stops the *grace*
  /// clock re-running on every failure; only the stalled leg is resettable.
  void _noteProgress() {
    if (_disposed || !_uiTimersArmed) return;
    if (_stalledRearms >= maxStalledRearms) return;
    _stalledRearms++;
    _stalledTimer?.cancel();
    _stalledTimer = Timer(stalledAfter, () {
      if (_disposed || !_healing) return;
      _setPhase(ConnectionPhase.stalled);
    });
    if (_phase == ConnectionPhase.stalled) {
      _setPhase(ConnectionPhase.reconnecting);
    }
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

      final gate = _interrupt = Completer<void>();
      // When stalled, only reflect retrying spinner if this is an explicit
      // manual tap/resume attempt or attempt 0. Automatic background retries
      // keep the stalled banner UI steady ("can't reach server · tap to retry").
      final showRetrying = _phase != ConnectionPhase.stalled || _isManualOrResumeRetry || _attempt == 0;
      if (showRetrying) _setRetrying(true);

      // Rebuild BEFORE the first probe when the gap we just came back from
      // already tells us the socket is dead (see [setForeground]). Probing a
      // zombie costs a full [firstProbeTimeout] to learn something we can
      // predict, and that wasted 7s is most of what a user experiences as
      // "stuck on reconnecting".
      if (_wantRebuild && _healing && !_disposed) {
        _wantRebuild = false;
        await _raceInterrupt(
          _backend.reconnect().timeout(rebuildTimeout, onTimeout: () => false),
          gate,
        );
        // Deliberately not [_noteProgress] and deliberately not inspected. A
        // rebuild reports that a fresh transport EXISTS, not that it reached
        // anything — it does not await the handshake. On a phone with no
        // network at all it succeeds every time, so treating it as progress
        // would defer the "can't reach server" alarm for precisely the user who
        // most needs to see it. The handshake that follows announces itself on
        // the socket stream, and that edge is real evidence.
      }

      _lastProbeStartedAt = _now();
      final quick = _attempt == 0 ? firstProbeTimeout : probeTimeout;
      var ok = await _raceInterrupt(
        _backend.probeConnection(timeout: quick),
        gate,
      );

      // Escalation, on every platform. `reconnect()` is now a genuine teardown
      // and rebuild on native too (see `ConvexBackend.reconnect`), which is the
      // only way to recover a socket that went silent without closing — the
      // ordinary result of a long background, and one convex-rs itself notices
      // only after 30s on a clock that does not run while the device sleeps.
      //
      // Gated on the attempt count so a merely slow server does not get its
      // socket torn down on the first miss: a rebuild throws away a query set
      // that then has to be re-registered, which is not free.
      if (ok == false &&
          _attempt >= rebuildAfterAttempt &&
          _healing &&
          !_disposed) {
        final healed = await _raceInterrupt(
          _backend.reconnect().timeout(rebuildTimeout, onTimeout: () => false),
          gate,
        );
        if (healed == true) {
          // Re-probe at once — the point of the rebuild is that the next probe
          // rides a socket that can actually carry it. The backoff ladder is
          // NOT reset: it measures how long this outage has lasted, and a
          // rebuild does not shorten that. Resetting it left a phone with no
          // network oscillating on the first two rungs forever instead of
          // settling at one attempt per 15s.
          ok = await _raceInterrupt(
            _backend.probeConnection(timeout: probeTimeout),
            gate,
          );
        } else {
          // null → interrupted. false → rate-limited or failed, which is not a
          // second probe failure; carry the one we already have.
          ok = healed;
        }
      }
      if (_interrupt == gate) _interrupt = null;
      if (_disposed) return;
      if (ok == null) {
        // Insurance against any interrupt source arriving faster than a probe
        // can resolve. Without a floor this branch is an unbounded busy loop
        // that issues a fresh query per lap.
        if (++_interruptsInARow >= 3) {
          await _sleep(const Duration(milliseconds: 250));
        }
        continue;
      }
      _interruptsInARow = 0;
      _setRetrying(false);
      _isManualOrResumeRetry = false;

      if (ok) {
        _markOnline();
        return;
      }

      // Only now — with a probe that actually failed — is there anything worth
      // telling the user about. See [_armUiTimers].
      _armUiTimers();

      _attempt++;
      await _sleepAtLeast(_backoffFor(_attempt));
    }
  }

  /// Wait out [d], of which the first [minLoopInterval] cannot be cut short.
  ///
  /// A wake — a socket edge, an interface change, a tap — should shorten a long
  /// wait. It should never remove it. convex-rs emits a `connected` edge at the
  /// top of every lap of its own internal reconnect backoff, and each one both
  /// wakes this loop and resets its ladder, so a flapping socket could drive
  /// this into an unbounded source of server queries — against the server whose
  /// slowness started the flapping. The floor is what stops the feedback.
  Future<void> _sleepAtLeast(Duration d) async {
    final floor = d < minLoopInterval ? d : minLoopInterval;
    await Future<void>.delayed(floor);
    if (_disposed || !_healing) return;
    if (d > floor) await _sleep(d - floor);
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
    _interruptsInARow = 0;
    _wantRebuild = false;
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
