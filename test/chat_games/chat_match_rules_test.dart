import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/matches_api.dart';
import 'package:monkeyhub/models/chat_match.dart';

/// The row-side mirror of the server's takeback and draw-offer rules
/// (`backend/convex/matches.ts`): what the board offers must be what the
/// server will take.
void main() {
  ChatMatch row(Map<String, dynamic> extra) => ChatMatch.fromJson({
    'id': 'm1',
    'roomId': 'r1',
    'game': 'chess',
    'mode': 'async',
    'status': 'active',
    'seats': [
      {'userId': 'a', 'name': 'Ada'},
      {'userId': 'b', 'name': 'Bob'},
    ],
    'state': 's',
    'seq': 3,
    'turnSeat': 1,
    'lastMove': 'e2e4',
    'createdBy': 'a',
    'createdAt': 0,
    ...extra,
  })!;

  test('parses the new fields, and an older server reads as none', () {
    final m = row({
      'takebackOffer': {'seat': 0, 'seq': 3},
      'takebackDeclined': {'seat': 1, 'seq': 2},
      'drawDeclined': {'seat': 0, 'seq': 1},
      'takebacks': [2, 0],
    });
    expect(m.takebackOfferSeat, 0);
    expect(m.takebackOfferSeq, 3);
    expect(m.takebackDeclinedSeat, 1);
    expect(m.drawDeclinedSeq, 1);
    expect(m.takebacksUsed(0), 2);
    expect(m.takebacksLeft(0), 1);
    final old = row({});
    expect(old.takebacks, isEmpty);
    expect(old.takebacksLeft(0), kMaxTakebacks);
  });

  test('only the last mover may ask, once per position, while some are left', () {
    expect(row({}).canAskTakeback('a'), isTrue);
    expect(row({}).canAskTakeback('b'), isFalse); // b is to move
    expect(row({}).canAskTakeback('z'), isFalse); // a spectator
    expect(row({'seq': 0, 'lastMove': null}).canAskTakeback('a'), isFalse);
    expect(
      row({'takebacks': [3, 0]}).canAskTakeback('a'),
      isFalse,
    );
    expect(
      row({'takebackDeclined': {'seat': 0, 'seq': 3}}).canAskTakeback('a'),
      isFalse,
    );
    expect(
      row({'takebackDeclined': {'seat': 0, 'seq': 2}}).canAskTakeback('a'),
      isTrue,
    );
    expect(row({'status': 'paused'}).canAskTakeback('a'), isFalse);
    expect(row({'game': 'liarsdice'}).canAskTakeback('a'), isFalse);
  });

  test('a standing request is for the other player to answer', () {
    final m = row({'takebackOffer': {'seat': 0, 'seq': 3}});
    expect(m.takebackOfferedTo('b'), isTrue);
    expect(m.takebackOfferedTo('a'), isFalse);
    expect(m.takebackAskedBy('a'), isTrue);
    expect(m.canAskTakeback('a'), isFalse);
    // A move since killed it.
    final moved = row({'takebackOffer': {'seat': 0, 'seq': 2}});
    expect(moved.takebackOfferedTo('b'), isFalse);
    expect(moved.takebackAskedBy('a'), isFalse);
  });

  test('a declined draw offer waits two moves', () {
    expect(row({}).canOfferDraw('a'), isTrue);
    expect(row({}).canOfferDraw('z'), isFalse);
    final declined = row({'drawDeclined': {'seat': 0, 'seq': 2}});
    expect(declined.canOfferDraw('a'), isFalse); // seq 3 < 2 + 2
    expect(declined.canOfferDraw('b'), isTrue);
    expect(
      row({'seq': 4, 'drawDeclined': {'seat': 0, 'seq': 2}}).canOfferDraw('a'),
      isTrue,
    );
    expect(
      row({'drawOffer': {'seat': 1, 'seq': 3}}).canOfferDraw('a'),
      isFalse,
    );
  });

  test('history parses, and the new error codes are recognised', () {
    final h = MatchHistory.fromJson({
      'seq': 5,
      'moves': [
        {'seat': 0, 'move': 'e2e4'},
        {'seat': 1, 'move': 'e7e5', 'auto': true},
      ],
    });
    expect(h.seq, 5);
    expect(h.moves.map((m) => m.move), ['e2e4', 'e7e5']);
    expect(h.moves.last.auto, isTrue);
    expect(matchErrorCode(Exception('Uncaught Error: NO_TAKEBACKS_LEFT')),
        'NO_TAKEBACKS_LEFT');
    expect(matchErrorCode(Exception('Uncaught Error: NO_TAKEBACKS')),
        'NO_TAKEBACKS');
    expect(matchErrorCode(Exception('Uncaught Error: NOTHING_TO_TAKE_BACK')),
        'NOTHING_TO_TAKE_BACK');
  });
}
