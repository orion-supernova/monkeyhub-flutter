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

/// Which of the three [live] and [friends] describe.
///
/// [sawPending] is the guard that makes this safe to act on. A subscription
/// that has not delivered yet is an empty list, and an empty list looks exactly
/// like an answered request — so an absence only counts once the row has been
/// seen present at least once. Acceptance needs no such proof: the other user
/// cannot appear in [friends] without the request that put them there having
/// been answered, and that holds even if the pending row was never observed.
RequestOutcome requestOutcome({
  required String requestId,
  required String otherUserId,
  required List<FriendRequest> live,
  required List<ChatUser> friends,
  required bool sawPending,
}) {
  if (friends.any((f) => f.id == otherUserId)) return RequestOutcome.accepted;
  if (live.any((r) => r.id == requestId)) return RequestOutcome.pending;
  return sawPending ? RequestOutcome.ended : RequestOutcome.pending;
}
