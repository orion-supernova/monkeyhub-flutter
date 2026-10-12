import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/dots.dart';
import 'package:monkeyhub/turn_games/turn_rules.dart';

/// The Dart Dots and Boxes mirror, checked first against the server's own
/// playouts (`test/fixtures/turn_games/dots.json`, written by
/// `backend/tools/turn-fixtures.ts` from the TS rules, 2–4 seats) and then
/// rule by rule.
///
/// On a 2 x 2 board the horizontals are 0–5 and the verticals 6–11; box 0 is
/// {0, 2, 6, 7} and box 1 is {1, 3, 7, 8}.
void main() {
  const rules = dotsRules;

  DotsState play(DotsState s, List<int> moves) {
    for (final m in moves) {
      s = rules.apply(s, m);
    }
    return s;
  }

  group('fixture replay', () {
    final games =
        jsonDecode(
              File('test/fixtures/turn_games/dots.json').readAsStringSync(),
            )
            as List;

    test('matches every step the server played', () {
      expect(games, isNotEmpty);
      final seatsSeen = <int>{};
      for (final game in games) {
        for (final raw in game as List) {
          final step = raw as Map<String, dynamic>;
          final state = rules.decode(step['state'] as String);
          seatsSeen.add(state.seats);
          expect(rules.encode(state), step['state']);
          expect(rules.toMove(state), step['toMove']);
          expect(
            rules.legalMoves(state).map(rules.encodeMove).toList(),
            step['legal'],
          );
          final next = rules.apply(
            state,
            rules.decodeMove(step['move'] as String),
          );
          expect(rules.encode(next), step['next']);
          final want = step['outcome'] as Map<String, dynamic>?;
          final got = rules.outcome(next);
          if (want == null) {
            expect(got, isNull);
          } else {
            expect(got?.winner, want['winner']);
            expect(got?.reason, want['reason']);
          }
        }
      }
      expect(seatsSeen, {2, 3, 4});
    });
  });

  group('rules', () {
    test('4 x 4 by default, lines numbered horizontals first', () {
      final s = rules.initial(2);
      expect(s.rows, 4);
      expect(s.cols, 4);
      expect(rules.legalMoves(s), List.generate(40, (i) => i));
      final g = DotsGeometry.of(2, 2);
      expect(g.boxSides[0], [0, 2, 6, 7]);
      expect(g.boxSides[3], [3, 5, 10, 11]);
      expect(g.lineBoxes[7], [0, 1]);
      expect(g.lineBoxes[4], [2]);
    });

    test('closing a box scores it and moves again', () {
      var s = play(rules.initialSized(2, 2, 2), [0, 2, 6]);
      expect(rules.toMove(s), 1);
      s = rules.apply(s, 7);
      expect(s.owners[0], 1);
      expect(s.scores, [0, 1]);
      expect(rules.toMove(s), 1);
      s = rules.apply(s, 11);
      expect(rules.toMove(s), 0);
    });

    test('one line can close two boxes', () {
      final s = play(rules.initialSized(2, 2, 2), [0, 2, 6, 1, 3, 8, 7]);
      expect(s.scores, [2, 0]);
      expect(rules.toMove(s), 0);
    });

    test('end, scoring and ties', () {
      final one = play(rules.initialSized(2, 1, 1), [0, 1, 2, 3]);
      expect(rules.outcome(one)?.winner, 1);
      expect(rules.outcome(one)?.reason, 'most-boxes');
      expect(() => rules.apply(one, 0), throwsA(isA<IllegalMove>()));
      final tie = rules.apply(rules.decode('1x2|1111110|0.|1|1,0'), 6);
      expect(rules.outcome(tie)?.isDraw, isTrue);
      final three = rules.apply(rules.decode('1x2|1111110|0.|2|1,0,0'), 6);
      expect(three.scores, [1, 0, 1]);
      expect(rules.outcome(three)?.reason, 'tie');
    });

    test('three and four seats rotate in order', () {
      for (final seats in [3, 4]) {
        var s = rules.initial(seats);
        final order = <int>[];
        for (var i = 0; i < 8; i++) {
          order.add(rules.toMove(s));
          s = rules.apply(s, i);
        }
        expect(order, [for (var i = 0; i < 8; i++) i % seats]);
      }
      expect(() => rules.initial(1), throwsA(isA<IllegalMove>()));
      expect(() => rules.initial(5), throwsA(isA<IllegalMove>()));
    });

    test('a 3 x 3 board plays to the end', () {
      final rand = Random(3);
      var s = rules.initialSized(2, 3, 3);
      expect(s.lines.length, 24);
      while (rules.outcome(s) == null) {
        final legal = rules.legalMoves(s);
        s = rules.apply(s, legal[rand.nextInt(legal.length)]);
        expect(rules.encode(rules.decode(rules.encode(s))), rules.encode(s));
      }
      expect(s.scores.reduce((a, b) => a + b), 9);
      expect(rules.encode(s), startsWith('3x3|'));
    });

    test('decode and move tokens refuse garbage', () {
      for (final raw in [
        '',
        '2x2|10100011000|2...|2|0,0,1',
        '2x2|101000110000|....|2|0,0,1',
        '2x2|101000110000|1...|2|1,0,0',
        '2x2|000000000000|....|0|0,0,0,0,0',
        '9x9|0|.|0|0,0',
      ]) {
        expect(() => rules.decode(raw), throwsFormatException, reason: raw);
      }
      for (final raw in ['', '-1', '01', 'x', '1.0']) {
        expect(() => rules.decodeMove(raw), throwsFormatException, reason: raw);
      }
      final s = play(rules.initial(2), [5]);
      expect(() => rules.apply(s, 5), throwsA(isA<IllegalMove>()));
      expect(() => rules.apply(s, 40), throwsA(isA<IllegalMove>()));
    });
  });

  group('evaluator', () {
    const eval = dotsEvaluator;

    test('values a forced chain sacrifice exactly', () {
      // 1 x 3, every horizontal drawn: one chain of three, nothing safe.
      final s = rules.decode('1x3|1111110000|...|0|0,0');
      expect(eval.evaluate(s, 0), -300);
      expect(eval.evaluate(s, 1), 300);
    });

    test('a long chain plus a short one: the controller gives two back', () {
      // 1 x 4: box 0 is a lone two-sided box walled off by line 9, boxes 1–3
      // a chain of three. The mover opens the single, the other side takes it
      // and must open the three: the mover nets 3 - 1 = +2.
      final s = rules.decode('1x4|1111001101000|....|0|0,0');
      expect(eval.evaluate(s, 0), 200);
    });

    test('handing over a third side costs the box', () {
      // Seat 0 to move with box 0 two-sided: line 6 hands it over, 11 is safe.
      final s = play(rules.initialSized(2, 2, 2), [0, 2]);
      expect(rules.toMove(s), 0);
      final given = rules.apply(s, 6);
      final kept = rules.apply(s, 11);
      expect(rules.toMove(given), 1);
      expect(rules.toMove(kept), 1);
      expect(
        eval.evaluate(given, 0),
        lessThan(eval.evaluate(kept, 0) - 50),
      );
    });

    test('scores a finished game flat', () {
      final done = play(rules.initialSized(2, 1, 1), [0, 1, 2, 3]);
      expect(eval.evaluate(done, 1), TurnEvaluator.winScore);
      expect(eval.evaluate(done, 0), -TurnEvaluator.winScore);
    });

    test('orders closing, then safe, then the smallest sacrifice', () {
      // 1 x 4: box 0 has three sides; boxes 1–3 a two-sided chain of three.
      final s = rules.decode('1x4|1111111110000|....|0|0,0');
      final ordered = eval.order(s, rules.legalMoves(s));
      expect(ordered.first, 9);
      final safe = rules.initial(2);
      final opened = play(safe, [0, 4]);
      final o = eval.order(opened, rules.legalMoves(opened));
      // Line 20 (left side of box 0) would make box 0 three-sided.
      expect(o.indexOf(20), greaterThan(o.indexOf(1)));
    });
  });
}
