import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/request_outcome.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// The screen you're left on after sending a friend request used to be a dead
/// end: it polled the draft thread on a 3s timer *only* on the receiving side,
/// and nothing anywhere asked whether the request was still pending. So the
/// sender watched a "CANCEL REQUEST" bar forever — the other person could
/// accept, decline, or be declined by their own grown-up, and the screen said
/// the same thing it had said a second after they tapped send.
///
/// The fix reads the answer off the repository's live request lists. These pin
/// the rule that does it, and above all the guard that keeps it from firing on
/// a list that simply hasn't loaded yet.
void main() {
  ChatUser user(String id) => ChatUser(id: id, username: id, name: id);

  FriendRequest req(String id, String userId) => FriendRequest(
        id: id,
        user: user(userId),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        roomType: RoomType.regular,
        messageCount: 0,
      );

  RequestOutcome outcome({
    List<FriendRequest> live = const [],
    List<ChatUser> friends = const [],
    bool sawPending = true,
  }) =>
      requestOutcome(
        requestId: 'r1',
        otherUserId: 'them',
        live: live,
        friends: friends,
        sawPending: sawPending,
      );

  test('a request still in the live list is still pending', () {
    expect(outcome(live: [req('r1', 'them')]), RequestOutcome.pending);
  });

  test('the row leaving the list with a new friendship is an accept', () {
    expect(outcome(friends: [user('them')]), RequestOutcome.accepted);
  });

  test('the row leaving the list with no friendship ends it', () {
    // Declined by them, declined by their guardian, or withdrawn — the row's
    // absence cannot tell those apart, and the screen must not claim it can.
    expect(outcome(), RequestOutcome.ended);
  });

  test('an empty list before the subscription has delivered is not an answer', () {
    // The bug this guard exists for: a subscription that hasn't fired yet is
    // an empty list, which is indistinguishable from an answered request.
    // Without it the screen closes itself the instant it opens.
    expect(outcome(sawPending: false), RequestOutcome.pending);
  });

  test('an acceptance needs no such proof', () {
    // You cannot land in someone's friends list without the request that put
    // you there having been answered, so this is decisive even when the
    // pending row was never observed.
    expect(
      outcome(friends: [user('them')], sawPending: false),
      RequestOutcome.accepted,
    );
  });

  test('someone else\'s pending request is not this one', () {
    // Both lists carry every request in that direction. Matching on the wrong
    // one would leave this screen pending against a stranger's row.
    expect(outcome(live: [req('r2', 'other')]), RequestOutcome.ended);
  });

  test('an unrelated friendship is not this request being accepted', () {
    expect(outcome(friends: [user('other')]), RequestOutcome.ended);
  });
}
