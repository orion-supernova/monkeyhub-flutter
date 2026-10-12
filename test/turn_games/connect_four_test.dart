import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/connect_four.dart';
import 'package:monkeyhub/turn_games/turn_rules.dart';

import 'fixture_replay.dart';

/// Connect Four's Dart mirror: the server's playouts (one of them a full-board
/// draw), plus the edges a random game rarely visits.
void main() {
  const rules = connectFourRules;

  ConnectFourState play(List<int> moves) {
    var s = rules.initial(2);
    for (final m in moves) {
      s = rules.apply(s, m);
    }
    return s;
  }

  replayTurnFixtures(rules);

  test('there are 69 windows of four', () {
    expect(connectFourWindows.length, 69);
  });

  test('every direction wins, and the result survives a decode', () {
    for (final (moves, winner) in [
      ([0, 0, 1, 1, 2, 2, 3], 0),
      ([0, 1, 0, 1, 0, 1, 0], 0),
      ([0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3], 0),
      ([6, 5, 5, 4, 4, 3, 4, 3, 3, 0, 3], 0),
      ([0, 1, 0, 1, 0, 1, 2, 1], 1),
    ]) {
      final s = play(moves);
      expect(rules.outcome(s)?.winner, winner, reason: '$moves');
      final again = rules.decode(rules.encode(s));
      expect(rules.outcome(again)?.winner, winner, reason: '$moves');
    }
    expect(
      rules.winningCells(play([0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3])),
      [17, 23, 29, 35],
    );
  });

  test('a full column is not legal, nor is anything after a win', () {
    final s = play([0, 0, 0, 0, 0, 0]);
    expect(rules.legalMoves(s), [1, 2, 3, 4, 5, 6]);
    expect(() => rules.apply(s, 0), throwsA(isA<IllegalMove>()));
    expect(() => rules.apply(s, 7), throwsA(isA<IllegalMove>()));
    final won = play([0, 0, 1, 1, 2, 2, 3]);
    expect(() => rules.apply(won, 4), throwsA(isA<IllegalMove>()));
    expect(() => rules.decodeMove('03'), throwsA(isA<IllegalMove>()));
  });

  test('decode refuses impossible boards', () {
    final empty = '.' * 42;
    String bottom(String row) => empty.substring(0, 35) + row;
    for (final raw in [
      '',
      '$empty/2',
      '${empty}0',
      'X${empty.substring(1)}/1',
      '${bottom('X......')}/0',
      '${bottom('XXXXOOO')}/0',
      '${empty.substring(0, 28)}OOOO...XXXX.XX/0',
    ]) {
      expect(() => rules.decode(raw), throwsFormatException, reason: raw);
    }
  });
}
