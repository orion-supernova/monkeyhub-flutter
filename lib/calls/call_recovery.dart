/// Pure recovery/glare policy for [CallService], split out so it's
/// unit-testable without a real PeerConnection.
library;

/// How long a call may sit in the reconnecting state, counting only time
/// during which a restart could actually have been delivered — i.e. with the
/// signaling transport up. See [shouldAbandonRestart].
const Duration kMaxCallOutage = Duration(seconds: 30);

/// Absolute ceiling on one outage, whatever the signaling transport was
/// doing. A phone that has had no usable network for two minutes is not
/// coming back into this call.
const Duration kHardCallOutage = Duration(seconds: 120);

/// A signal from the peer this recently proves the peer is alive and
/// working on it (its `restart-request`, an `ice-batch`), so the call is
/// worth holding open even past [kMaxCallOutage].
const Duration kPeerAliveWindow = Duration(seconds: 15);

/// libwebrtc's `continualGatheringPolicy` for every call peer connection.
///
/// The default, gather once, stops looking for candidates after the first
/// gathering pass — so when the phone moves from Wi-Fi to cellular the new
/// interface is invisible to ICE until a full restart round-trips through
/// signaling. Gathering continually makes libwebrtc notice the new network on
/// its own, gather on it, and trickle the candidates; often the link moves to
/// the new path before anyone has to restart anything. Cost: one gathering
/// pass (and a TURN allocation) per network change — nothing while the network
/// holds still. Honoured natively by the vendored flutter_webrtc on Darwin and
/// Android.
const String kIceGatheringPolicy = 'gather_continually';

/// Delay before the NEXT restart attempt, given how many have already run.
///
/// Never exhausts: the outage budget in [shouldAbandonRestart] is what ends
/// recovery, not an attempt count. A count was the wrong limit — on a
/// Wi-Fi → cellular handover the first attempts are fired into a signaling
/// socket that is itself being rebuilt, so they cannot arrive, and three of
/// them used to be spent before anything could be delivered at all.
Duration nextRestartDelay(int attemptsSoFar) {
  switch (attemptsSoFar) {
    case 0:
      return Duration.zero;
    case 1:
      return const Duration(seconds: 4);
    case 2:
      return const Duration(seconds: 6);
    default:
      return const Duration(seconds: 8);
  }
}

/// How long a restart is left alone while its ICE checks are visibly running.
///
/// A restart mints new ICE credentials, so restarting again throws away every
/// check the previous one had in flight. Over TURN on a cellular link that
/// has just come up, a restart can take several seconds to connect — and a
/// schedule that fires on a fixed clock would keep killing the attempt that
/// was about to work.
const Duration kRestartSettle = Duration(seconds: 6);

/// Whether a scheduled restart attempt should stand down this time because
/// the previous one is still connecting.
bool restartStillSettling({
  required bool linkConnecting,
  required DateTime? lastRestartAt,
  required DateTime now,
}) =>
    linkConnecting &&
    lastRestartAt != null &&
    now.difference(lastRestartAt) < kRestartSettle;

/// True when recovery should stop and the call be torn down as failed.
///
/// [signalingDown] is how much of the outage the signaling transport itself
/// was down (`SignalingStatus.downtimeBetween`). That time does not count
/// against [kMaxCallOutage]: no restart offer could have reached the peer, so
/// it says nothing about whether the call is recoverable.
///
/// [lastPeerSignal] is when the peer last sent us anything for this call. A
/// peer heard from within [kPeerAliveWindow] is still trying, so the call is
/// held — up to [kHardCallOutage].
///
/// [attemptsSoFar] is kept for logging call sites; it no longer limits
/// anything (see [nextRestartDelay]).
bool shouldAbandonRestart({
  required DateTime? outageStart,
  required DateTime now,
  required int attemptsSoFar,
  Duration signalingDown = Duration.zero,
  DateTime? lastPeerSignal,
}) {
  if (outageStart == null) return false;
  final total = now.difference(outageStart);
  if (total > kHardCallOutage) return true;
  if (lastPeerSignal != null &&
      !lastPeerSignal.isBefore(outageStart) &&
      now.difference(lastPeerSignal) <= kPeerAliveWindow) {
    return false;
  }
  return total - signalingDown > kMaxCallOutage;
}

/// Mutual-call glare tiebreak — both users dialed each other simultaneously.
/// Deterministic and asymmetric by construction: exactly one side "wins" and
/// keeps its outgoing call ringing; the loser cancels its own outgoing and
/// rings for the winner's invite instead.
bool winsGlare({required String myUserId, required String peerUserId}) =>
    myUserId.compareTo(peerUserId) > 0;
