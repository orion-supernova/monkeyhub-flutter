import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/family.dart';
import 'package:monkeyhub/screens/child_pair_screen.dart';
import 'package:monkeyhub/screens/pairing_code_screen.dart';

void main() {
  group('pairing code parsing', () {
    test('accepts the URI the parent app renders', () {
      expect(extractPairingCode('monkeyhub://pair?c=482917'), '482917');
    });

    test('accepts bare six digits, so a code read aloud still works', () {
      expect(extractPairingCode('482917'), '482917');
      expect(extractPairingCode('  482917  '), '482917');
    });

    test('round-trips what the parent screen generates', () {
      expect(extractPairingCode(pairingUri('100000')), '100000');
      expect(extractPairingCode(pairingUri('999999')), '999999');
    });

    test('rejects anything that is not exactly six digits', () {
      // A five- or seven-digit code can never be valid, and letting one
      // through would fire a doomed redeem call and show a confusing error.
      expect(extractPairingCode('48291'), isNull);
      expect(extractPairingCode('4829170'), isNull);
      expect(extractPairingCode('monkeyhub://pair?c=48291'), isNull);
      expect(extractPairingCode('abcdef'), isNull);
      expect(extractPairingCode(''), isNull);
    });

    test('rejects an unrelated QR the camera happens to see', () {
      expect(extractPairingCode('https://example.com'), isNull);
      expect(extractPairingCode('WIFI:S:home;T:WPA;P:hunter2;;'), isNull);
    });
  });

  group('request stage', () {
    test('maps the wire values from friendships.stage', () {
      expect(RequestStage.parse('awaitingSenderGuardian'),
          RequestStage.senderGuardian);
      expect(RequestStage.parse('awaitingRecipientGuardian'),
          RequestStage.recipientGuardian);
      expect(RequestStage.parse('awaitingRecipient'), RequestStage.recipient);
    });

    test('an absent stage means an unsupervised adult-to-adult request', () {
      expect(RequestStage.parse(null), isNull);
    });

    test('an unknown stage from a newer backend reads as unsupervised', () {
      // Failing closed here would hide legitimate requests; the server is
      // the authority on what a child may see either way.
      expect(RequestStage.parse('somethingNew'), isNull);
    });

    test('only the sender-guardian hop mentions a grown-up', () {
      // The other two must stay vague: telling a sender that the recipient's
      // guardian is deciding would disclose that the recipient is a child.
      expect(RequestStage.senderGuardian.senderLabel,
          'waiting for a grown-up');
      expect(RequestStage.recipientGuardian.senderLabel, 'waiting for them');
      expect(RequestStage.recipient.senderLabel, 'waiting for them');
    });
  });

  group('child policy', () {
    test('defaults lock down public rooms and room creation', () {
      const p = ChildPolicy();
      expect(p.publicRoomsEnabled, isFalse);
      expect(p.canCreateRooms, isFalse);
      expect(p.callsEnabled, isTrue);
      expect(p.mediaEnabled, isTrue);
      expect(p.canRequestContacts, isTrue);
    });

    test('a missing flag falls back to the locked-down default', () {
      // An older backend, or a partial write, must not silently unlock
      // public rooms.
      final p = ChildPolicy.fromJson(const {'callsEnabled': false});
      expect(p.publicRoomsEnabled, isFalse);
      expect(p.callsEnabled, isFalse);
    });

    test('copyWith leaves untouched flags alone', () {
      const p = ChildPolicy();
      final next = p.copyWith(publicRoomsEnabled: true);
      expect(next.publicRoomsEnabled, isTrue);
      expect(next.canCreateRooms, isFalse);
    });
  });

  group('family context', () {
    test('an account with no accountType is an unrestricted adult', () {
      // Every row that predates this feature has no accountType, so the
      // fallback has to be adult or the whole userbase gets supervised.
      final ctx = FamilyContext.fromJson(const {});
      expect(ctx.isChild, isFalse);
      expect(ctx.childPolicy, isNull);
      expect(ctx.pendingCount, 0);
    });

    test('a child carries its policy', () {
      final ctx = FamilyContext.fromJson(const {
        'accountType': 'child',
        'childPolicy': {
          'publicRoomsEnabled': true,
          'callsEnabled': false,
          'mediaEnabled': true,
          'canRequestContacts': true,
          'canCreateRooms': false,
        },
        'pendingCount': 2,
      });
      expect(ctx.isChild, isTrue);
      expect(ctx.policy.publicRoomsEnabled, isTrue);
      expect(ctx.policy.callsEnabled, isFalse);
      expect(ctx.pendingCount, 2);
    });

    test('the empty context reads as an unrestricted adult', () {
      // FamilyService starts here before the first fetch lands; treating it
      // as a locked child would break the app for every adult on launch.
      expect(FamilyContext.empty.isChild, isFalse);
    });
  });

  group('guard errors', () {
    test('recognises the codes childGuard.ts throws', () {
      expect(isChildGateError(Exception('CHILD_APPROVAL_REQUIRED')), isTrue);
      expect(isChildGateError(Exception('CHILD_NOT_ALLOWED')), isTrue);
    });

    test('an ordinary failure is not a gate', () {
      // Misreading a network blip as a gate would silently drop the message
      // instead of leaving it queued for retry.
      expect(isChildGateError(Exception('NETWORK_ERROR')), isFalse);
      expect(isChildGateError(Exception('NOT_A_MEMBER')), isFalse);
    });

    test('distinguishes "switched off" from "needs approval"', () {
      // Only the latter should offer an ASK button.
      expect(isChildBlockedOutright(Exception('CHILD_NOT_ALLOWED')), isTrue);
      expect(
          isChildBlockedOutright(Exception('CHILD_APPROVAL_REQUIRED')), isFalse);
    });
  });

  group('queue items', () {
    test('routes contact rows and room rows to different mutations', () {
      // isContact decides between advanceContactRequest (a friendships id)
      // and decideApproval (an approvalRequests id) — swapping them would
      // throw REQUEST_NOT_FOUND on every tap.
      final outgoing = QueueItem.fromJson(const {
        'type': 'contactOutgoing',
        '_id': 'f1',
        'createdAt': 0,
        'child': {'_id': 'c1', 'username': 'leo', 'name': 'Leo'},
        'other': {'_id': 'u1', 'username': 'zoe', 'name': 'Zoe'},
      });
      final room = QueueItem.fromJson(const {
        'type': 'joinRoom',
        '_id': 'a1',
        'createdAt': 0,
        'child': {'_id': 'c1', 'username': 'leo', 'name': 'Leo'},
        'room': {'_id': 'r1', 'name': 'minecraft', 'memberCount': 12},
      });
      expect(outgoing!.isContact, isTrue);
      expect(room!.isContact, isFalse);
      expect(room.room?.name, 'minecraft');
    });

    test('drops an unknown item type instead of crashing the queue', () {
      // A newer backend adding a kind must not blank the parent's whole
      // inbox — the rest of the rows still need deciding.
      expect(
        QueueItem.fromJson(const {
          'type': 'somethingNew',
          '_id': 'x',
          'createdAt': 0,
          'child': {'_id': 'c1', 'username': 'leo', 'name': 'Leo'},
        }),
        isNull,
      );
    });
  });
}
