import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/tic_tac_toe.dart';
import 'package:monkeyhub/turn_games/turn_rules.dart';

import 'fixture_replay.dart';

/// Tic-tac-toe's Dart mirror. The fixture replay is the load-bearing part;
/// the cases below pin the edges random play reaches only by luck.
void main() {
  const rules = ticTacToeRules;

  TicTacToeState play(List<int> moves) {
    var s = rules.initial(2);
    for (final m in moves) {
      s = rules.apply(s, m);
    }
    return s;
  }

  replayTurnFixtures(rules);

  test('opens empty with X to move', () {
    expect(rules.encode(rules.initial(2)), '........./0');
    expect(rules.legalMoves(rules.initial(2)), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('lines and a full board end the game the same way the server does', () {
    final row = play([0, 3, 1, 4, 2]);
    expect(rules.outcome(row)?.winner, 0);
    expect(rules.outcome(row)?.reason, 'line');
    expect(rules.winningLine(row), [0, 1, 2]);
    final draw = play([0, 1, 2, 4, 3, 5, 7, 6, 8]);
    expect(rules.outcome(draw)?.isDraw, isTrue);
    expect(rules.outcome(draw)?.reason, 'full');
  });

  test('illegal moves throw IllegalMove', () {
    final s = play([4]);
    for (final m in [4, 9, -1]) {
      expect(() => rules.apply(s, m), throwsA(isA<IllegalMove>()));
    }
    for (final raw in ['04', '', 'x', '4.0']) {
      expect(() => rules.decodeMove(raw), throwsA(isA<IllegalMove>()));
    }
    final won = play([0, 3, 1, 4, 2]);
    expect(() => rules.apply(won, 8), throwsA(isA<IllegalMove>()));
  });

  test('decode refuses what the server would', () {
    // The same list as ticTacToe.test.ts.
    for (final raw in [
      '',
      '........./',
      '........./2',
      '........../0',
      'X......../0',
      'O......../1',
      'XX......./1',
      'XXXOO..../0',
      'XXXOOO.../1',
      'XX.OOOX../1',
      'x......../1',
    ]) {
      expect(() => rules.decode(raw), throwsFormatException, reason: raw);
    }
  });
}
