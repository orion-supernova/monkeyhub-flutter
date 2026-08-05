import '../models/chat_user.dart';
import '../models/friend_request.dart';

/// Reading the fate of a friend request off the repository's live lists.
///
/// A pending request IS a row in `incomingRequests` / `outgoingRequests`, and
/// both of those are live Convex subscriptions. So the row *leaving* the list
/// is the accept/decline event itself — a screen sitting on a request needs no
/// poll and no push to learn it was answered, only this rule.
///
/// Pulled out as a free function so the one part that is easy to get wrong can
/// be pinned by a test with no socket: an absence has two causes, and only one
/// of them is an answer.

/// What has become of a request a screen is still showing.
enum RequestOutcome {
  /// Still waiting — or not yet proven otherwise, which must be treated the
  /// same way.
  pending,

  /// The other side said yes.
  accepted,

  /// The row is gone with no friendship behind it: declined, or withdrawn.
  ended,
}

/// How long an absent row with no friendship behind it has to stay that way
/// before the absence counts as an answer.
///
/// An accept patches the request row and writes the friendship in a single
/// backend transaction, but the two reach the app on two different live
/// queries, and each one notifies listeners the moment it lands. Between those
/// two notifications an accepted request is byte-for-byte identical to a
/// declined one: the pending row is gone and the friend isn't there yet. This
/// window is small — usually the very next turn of the event loop — but it is
/// the whole bug, because whoever reads the lists inside it concludes "they
/// said no" about a request that was accepted.
const requestAbsenceGrace = Duration(milliseconds: 1500);

/// Which of the three [live] and [friends] describe.
///
/// [sawPending] is the guard that makes this safe to act on. A subscription
/// that has not delivered yet is an empty list, and an empty list looks exactly
/// like an answered request — so an absence only counts once the row has been
/// seen present at least once. Acceptance needs no such proof: the other user
/// cannot appear in [friends] without the request that put them there having
/// been answered, and that holds even if the pending row was never observed.
///
/// [absenceSettled] is the second guard, and it covers the opposite mistake.
/// Even a *correctly* observed absence isn't an answer on its own, because the
/// friends list trails it by a notification — see [requestAbsenceGrace]. Only
/// the caller knows how long the absence has stood, so it passes that in;
/// until it does, an unexplained absence stays [pending]. Acceptance again
/// needs no proof, so a settled friendship short-circuits both guards.
RequestOutcome requestOutcome({
  required String requestId,
  required String otherUserId,
  required List<FriendRequest> live,
  required List<ChatUser> friends,
  required bool sawPending,
  required bool absenceSettled,
}) {
  if (friends.any((f) => f.id == otherUserId)) return RequestOutcome.accepted;
  if (live.any((r) => r.id == requestId)) return RequestOutcome.pending;
  if (!sawPending || !absenceSettled) return RequestOutcome.pending;
  return RequestOutcome.ended;
}
