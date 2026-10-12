import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/reversi.dart';
import 'package:monkeyhub/turn_games/turn_rules.dart';

import 'fixture_replay.dart';

/// Reversi's Dart mirror. The fixtures include real forced passes; the cases
/// below pin the pass and game-over logic on positions built for it, the same
/// ones `reversi.test.ts` uses.
void main() {
  const rules = reversiRules;

  replayTurnFixtures(rules);

  test('standard opening, black to move', () {
    final s = rules.initial(2);
    expect(rules.legalMoves(s), [19, 26, 37, 44]);
    expect(rules.discCounts(s), [2, 2]);
  });

  test('the fixtures really do contain passes', () {
    // Otherwise the replay above would never exercise the pass branch.
    final raw = File('test/fixtures/turn_games/reversi.json').readAsStringSync();
    expect(RegExp(r'/[01]p"').hasMatch(raw), isTrue);
  });

  test('a pass position decodes with the skipped seat', () {
    final s = rules.decode('${'W' * 56}WWWWW.WB/0p');
    expect(s.passedSeat, 1);
    expect(rules.legalMoves(s), [61]);
  });

  test('a side with no move is skipped and flagged inside apply', () {
    // Built from cells directly: this position has an empty centre, which
    // decode (correctly) refuses, but apply does not care.
    final cells = rules.initial(2).cells..fillRange(0, 64, 0);
    cells[0] = 1;
    cells[1] = 2;
    cells[3] = 2;
    cells[8] = 1;
    cells[9] = 1;
    final before = ReversiState(cells, 0, false, reversiMovesFor(cells, 0));
    expect(before.moves, [2]);
    final after = rules.apply(before, 2);
    expect(after.toMove, 0);
    expect(after.passed, isTrue);
    expect(after.passedSeat, 1);
    expect(rules.encode(after).endsWith('/0p'), isTrue);
    expect(rules.legalMoves(after), [4]);
    final end = rules.apply(after, 4);
    expect(end.passed, isFalse);
    expect(rules.outcome(end)?.winner, 0);
    expect(rules.outcome(end)?.reason, 'discs');
    expect(() => rules.apply(end, 5), throwsA(isA<IllegalMove>()));
  });

  test('illegal moves throw', () {
    final s = rules.initial(2);
    for (final m in [0, 27, 64, -1]) {
      expect(() => rules.apply(s, m), throwsA(isA<IllegalMove>()));
    }
    expect(() => rules.decodeMove('019'), throwsA(isA<IllegalMove>()));
  });

  test('decode refuses impossible states', () {
    final open = rules.encode(rules.initial(2)).substring(0, 64);
    for (final raw in [
      '',
      '$open/2',
      '$open/0x',
      '${open.substring(1)}/0',
      '${'.' * 64}/0',
      '$open/0p',
      '${'W' * 56}WWWWW.WB/1',
    ]) {
      expect(() => rules.decode(raw), throwsFormatException, reason: raw);
    }
  });
}
