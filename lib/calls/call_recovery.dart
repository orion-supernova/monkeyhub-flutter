/// Pure recovery/glare policy for [CallService], split out so it's
/// unit-testable without a real PeerConnection.
library;

/// Hard ceiling on how long a call may sit in the reconnecting state before
/// it's torn down as failed.
const Duration kMaxCallOutage = Duration(seconds: 30);

/// Delay before the NEXT restart attempt, given how many have already run.
/// Returns null when the schedule is exhausted (the caller runs one final
/// pass that trips [shouldAbandonRestart]).
Duration? nextRestartDelay(int attemptsSoFar) {
  switch (attemptsSoFar) {
    case 0:
      return Duration.zero;
    case 1:
      return const Duration(seconds: 4);
    case 2:
      return const Duration(seconds: 10);
    default:
      return null;
  }
}

/// True when recovery should stop and the call be torn down as failed.
bool shouldAbandonRestart({
  required DateTime? outageStart,
  required DateTime now,
  required int attemptsSoFar,
}) {
  if (attemptsSoFar >= 3) return true;
  if (outageStart != null && now.difference(outageStart) > kMaxCallOutage) {
    return true;
  }
  return false;
}

/// Mutual-call glare tiebreak — both users dialed each other simultaneously.
/// Deterministic and asymmetric by construction: exactly one side "wins" and
/// keeps its outgoing call ringing; the loser cancels its own outgoing and
/// rings for the winner's invite instead.
bool winsGlare({required String myUserId, required String peerUserId}) =>
    myUserId.compareTo(peerUserId) > 0;
