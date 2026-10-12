import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/checkers.dart';
import 'package:monkeyhub/turn_games/turn_rules.dart';

/// The Dart checkers mirror, checked first against the server's own playouts
/// (`test/fixtures/turn_games/checkers.json`, written by
/// `backend/tools/turn-fixtures.ts` from the TS rules) and then rule by rule.
///
/// The fixture replay is the load-bearing part: a unit test here would only
/// check the mirror against its own idea of checkers.
void main() {
  const rules = checkersRules;

  /// A position from PDN squares, through the wire so it is one decode takes.
  CheckersState position(Map<int, String> pieces, {int turn = 0}) {
    final board = List.filled(32, '.');
    pieces.forEach((sq, p) => board[sq - 1] = p);
    const names = '0123456789abcdefghijklmnopqrstuv';
    final dark = [
      for (var i = 0; i < 32; i++)
        if (board[i] == 'B') names[i],
    ];
    final light = [
      for (var i = 0; i < 32; i++)
        if (board[i] == 'W') names[i],
    ];
    return rules.decode('${board.join()}|$turn|0|${dark.join()}${light.join()}');
  }

  List<String> legal(CheckersState s) =>
      rules.legalMoves(s).map(rules.encodeMove).toList();

  CheckersState play(CheckersState s, List<String> moves) {
    for (final m in moves) {
      s = rules.apply(s, rules.decodeMove(m));
    }
    return s;
  }

  group('fixture replay', () {
    final games =
        jsonDecode(
              File(
                'test/fixtures/turn_games/checkers.json',
              ).readAsStringSync(),
            )
            as List;

    test('matches every step the server played', () {
      expect(games, isNotEmpty);
      var steps = 0;
      for (final game in games) {
        for (final raw in game as List) {
          final step = raw as Map<String, dynamic>;
          final state = rules.decode(step['state'] as String);
          expect(rules.encode(state), step['state']);
          expect(rules.toMove(state), step['toMove']);
          expect(legal(state), step['legal']);
          expect(rules.outcome(state), isNull);
          final move = rules.decodeMove(step['move'] as String);
          // Both paths: a move fresh from legalMoves, and one off the wire.
          final fromList = rules
              .legalMoves(state)
              .firstWhere((m) => m == move);
          final next = rules.apply(state, fromList);
          expect(rules.encode(next), step['next']);
          expect(rules.encode(rules.apply(state, move)), step['next']);
          final want = step['outcome'] as Map<String, dynamic>?;
          final got = rules.outcome(next);
          if (want == null) {
            expect(got, isNull);
          } else {
            expect(got?.winner, want['winner']);
            expect(got?.reason, want['reason']);
          }
          steps++;
        }
      }
      expect(steps, greaterThan(100));
    });
  });

  group('rules', () {
    test('the opening has the seven book moves, dark first', () {
      final s = rules.initial(2);
      expect(rules.toMove(s), 0);
      expect(legal(s), [
        '9-13', '9-14', '10-14', '10-15', '11-15', '11-16', '12-16',
      ]);
      expect(rules.encode(s), 'bbbbbbbbbbbb........wwwwwwwwwwww|0|0|');
    });

    test('a capture is forced over any quiet move', () {
      final s = position({1: 'b', 15: 'b', 18: 'w'});
      expect(legal(s), ['15x22']);
      expect(
        () => rules.apply(s, rules.decodeMove('1-5')),
        throwsA(isA<IllegalMove>()),
      );
    });

    test('a multi-jump runs to the end, either branch allowed', () {
      final s = position({6: 'b', 10: 'w', 18: 'w', 19: 'w'});
      expect(legal(s), ['6x15x22', '6x15x24']);
      expect(
        () => rules.apply(s, rules.decodeMove('6x15')),
        throwsA(isA<IllegalMove>()),
      );
      final after = play(s, ['6x15x24']);
      expect(after.pieceAt(23), 'b');
      expect(after.pieceAt(9), '.');
      expect(after.pieceAt(18), '.');
    });

    test('crowning ends the move', () {
      final s = position({22: 'b', 26: 'w', 27: 'w', 1: 'W'});
      expect(legal(s), ['22x31']);
      final after = play(s, ['22x31']);
      expect(after.pieceAt(30), 'B');
      expect(after.pieceAt(26), 'w');
    });

    test('the side with no move loses', () {
      final blocked = position({5: 'b', 9: 'w', 14: 'w'});
      expect(rules.outcome(blocked)?.winner, 1);
      expect(rules.outcome(blocked)?.reason, 'no-moves');
      expect(rules.legalMoves(blocked), isEmpty);
    });

    test('threefold repetition is a draw', () {
      const shuffle = ['1-5', '32-28', '5-1', '28-32'];
      final twice = play(position({1: 'B', 32: 'W'}), shuffle);
      expect(rules.outcome(twice), isNull);
      final thrice = play(twice, shuffle);
      expect(rules.outcome(thrice)?.reason, 'repetition');
      expect(rules.outcome(thrice)?.isDraw, isTrue);
      expect(rules.legalMoves(thrice), isEmpty);
    });

    test('80 quiet plies is a draw', () {
      final past = StringBuffer();
      for (var i = 0; i < 78; i++) {
        past.write('abcdefghijklmnopqrstu'[i % 21]);
        past.write('123456789'[i ~/ 21]);
      }
      final s = rules.decode('B..............................W|0|78|${past}0v');
      final at79 = play(s, ['1-5']);
      expect(at79.quiet, 79);
      expect(rules.outcome(at79), isNull);
      final at80 = play(at79, ['32-28']);
      expect(rules.outcome(at80)?.reason, 'move-limit');
      expect(rules.decode(rules.encode(at80)).history, at80.history);
    });

    test('decode rejects what encode could not produce', () {
      for (final raw in [
        '',
        'bbbbbbbbbbbb........wwwwwwwwwwww|2|0|',
        'bbbbbbbbbbbb........wwwwwwwwwwww|0|1|',
        '...............................b|0|0|',
        'B..............................W|0|0|0',
        'B..............................W|0|0|v0',
      ]) {
        expect(() => rules.decode(raw), throwsFormatException, reason: raw);
      }
    });

    test('bad move tokens are refused', () {
      for (final raw in ['', '11', '11-15-19', '33-1', 'a-b', '0-4']) {
        expect(() => rules.decodeMove(raw), throwsFormatException, reason: raw);
      }
      expect(
        () => rules.apply(rules.initial(2), rules.decodeMove('22-18')),
        throwsA(isA<IllegalMove>()),
      );
    });
  });

  group('evaluator', () {
    const eval = checkersEvaluator;

    test('is symmetric at the opening and counts material', () {
      final s = rules.initial(2);
      expect(eval.evaluate(s, 0), -eval.evaluate(s, 1));
      final up = position({1: 'b', 2: 'b', 32: 'w'});
      expect(eval.evaluate(up, 0), greaterThan(90));
      final king = position({14: 'B', 32: 'w'});
      final man = position({14: 'b', 32: 'w'});
      expect(eval.evaluate(king, 0), greaterThan(eval.evaluate(man, 0)));
    });

    test('scores a finished game flat', () {
      final lost = position({5: 'b', 9: 'w', 14: 'w'});
      expect(eval.evaluate(lost, 1), TurnEvaluator.winScore);
      expect(eval.evaluate(lost, 0), -TurnEvaluator.winScore);
    });

    test('pulls a winning king toward the enemy', () {
      final far = position({1: 'B', 5: 'B', 32: 'W'});
      final near = position({23: 'B', 5: 'B', 32: 'W'});
      expect(eval.evaluate(near, 0), greaterThan(eval.evaluate(far, 0)));
    });

    test('orders longer jumps first', () {
      final s = position({6: 'b', 10: 'w', 19: 'w', 3: 'b', 8: 'w'});
      final moves = rules.legalMoves(s);
      expect(moves.map(rules.encodeMove), ['3x12', '6x15x24']);
      final ordered = eval.order(s, moves);
      expect(ordered.map(rules.encodeMove).first, '6x15x24');
    });
  });
}
