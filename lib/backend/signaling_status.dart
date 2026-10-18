import 'package:flutter/foundation.dart';

/// What the rest of the app may know about the Convex transport's health,
/// without depending on [ConnectionHealth] itself.
///
/// ───────── why this exists ─────────
///
/// Calls signal over Convex. When the phone moves from Wi-Fi to cellular, the
/// media path AND the signaling path break at the same instant, and the call's
/// ICE-restart offer has to ride a socket that is itself being rebuilt. The
/// call's recovery budget used to be a flat 30s from the first ICE
/// `disconnected`, with three restart attempts — while the signaling socket
/// took longer than that to come back on its own. So every attempt went into
/// a dead socket, timed out, and the call tore itself down as "Connection
/// lost" at the exact moment the network had recovered enough to carry it.
///
/// This ledger lets call recovery tell those apart:
///
///  * **[downtimeBetween]** — how much of an outage window the signaling
///    transport itself was down. That time is not the peer's fault and no
///    restart could have gone through, so it does not count against the
///    call's budget (see `shouldAbandonRestart`).
///  * **[upEdges]** — bumped each time the transport is verified back. A call
///    that is reconnecting restarts ICE at once instead of waiting out a
///    backoff timer that was armed while nothing could be sent.
///  * **[networkEpoch]** — bumped when the device's network actually changed
///    (Wi-Fi ↔ cellular, not a flicker). A call restarts ICE proactively on
///    it rather than waiting the ~5-30s libwebrtc needs to declare the old
///    candidate pair dead.
///
/// Written only by [ConnectionHealth]. A singleton for the same reason
/// `ConnectionHealth.maybeInstance` exists: the call services are built long
/// before, and far away from, the app state that owns the monitor.
class SignalingStatus extends ChangeNotifier {
  SignalingStatus({DateTime Function() now = DateTime.now}) : _now = now;

  static final SignalingStatus instance = SignalingStatus();

  final DateTime Function() _now;

  DateTime? _downSince;

  /// Closed outages, oldest first. Bounded: a call's outage window is at most
  /// a couple of minutes, and nothing older than that is ever asked about.
  final List<(DateTime, DateTime)> _closed = [];
  static const _keep = 32;

  int _upEdges = 0;
  int _networkEpoch = 0;

  /// The transport is believed down right now (a healing episode is running).
  bool get isDown => _downSince != null;

  /// Count of verified down → up transitions since launch.
  int get upEdges => _upEdges;

  /// Count of settled network changes since launch.
  int get networkEpoch => _networkEpoch;

  void markDown() {
    if (_downSince != null) return;
    _downSince = _now();
    notifyListeners();
  }

  void markUp() {
    final since = _downSince;
    if (since == null) return;
    _downSince = null;
    _closed.add((since, _now()));
    if (_closed.length > _keep) _closed.removeAt(0);
    _upEdges++;
    notifyListeners();
  }

  void noteNetworkChanged() {
    _networkEpoch++;
    notifyListeners();
  }

  /// How much of [from, to] the transport spent down, including an outage
  /// still in progress.
  Duration downtimeBetween(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return Duration.zero;
    var total = Duration.zero;
    void add(DateTime a, DateTime b) {
      final s = a.isAfter(from) ? a : from;
      final e = b.isBefore(to) ? b : to;
      if (e.isAfter(s)) total += e.difference(s);
    }

    for (final (a, b) in _closed) {
      add(a, b);
    }
    final open = _downSince;
    if (open != null) add(open, to);
    return total;
  }

  @visibleForTesting
  void resetForTest() {
    _downSince = null;
    _closed.clear();
    _upEdges = 0;
    _networkEpoch = 0;
  }
}
