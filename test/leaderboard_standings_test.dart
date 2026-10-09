import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/games/leaderboard_standings.dart';

/// The overall ("Today") leaderboard: one point per puzzle solved, ties to
/// whoever won more boards, then to the lower rank sum, then by name.
void main() {
  GameResult row(DailyGame g, String id, String name, {bool solved = true}) =>
      GameResult(
        game: g,
        solved: solved,
        gaveUp: !solved,
        finished: true,
        durationMs: solved ? 60000 : null,
        userId: id,
        name: name,
      );

  PuzzleScore code(String id, String name, {bool solved = true}) =>
      PuzzleScore(
        userId: id,
        name: name,
        solved: solved,
        guessCount: 4,
        finishedAt: DateTime(2026),
        feedback: const [],
      );

  test('more solved wins; equal solved goes to more wins, then rank sum', () {
    final s = GameStandings(
      boards: {
        // a wins queens, b second; c wins tango, a second; b wins zip.
        DailyGame.queens: [row(DailyGame.queens, 'a', 'Ada'), row(DailyGame.queens, 'b', 'Bo')],
        DailyGame.tango: [row(DailyGame.tango, 'c', 'Cem'), row(DailyGame.tango, 'a', 'Ada')],
        DailyGame.zip: [row(DailyGame.zip, 'b', 'Bo'), row(DailyGame.zip, 'c', 'Cem')],
      },
    );
    final out = overallStandings(s, const PuzzleState(), 'me');
    // Everyone solved 2, everyone won 1: rank sums decide.
    // a: q1 + t2 + z(2+1=3) + code(0+1=1) + sudoku(0+1=1) = 8
    // b: q2 + t(2+1=3) + z1 + 1 + 1 = 8
    // c: q(2+1=3) + t1 + z2 + 1 + 1 = 8 → name order.
    expect(out.map((r) => r.userId), ['a', 'b', 'c']);
    expect(out.every((r) => r.solved == 2 && r.wins == 1), isTrue);
    expect(out.first.rankSum, 8);
  });

  test('wins break a tie on solved before the rank sum does', () {
    final s = GameStandings(
      boards: {
        DailyGame.queens: [row(DailyGame.queens, 'x', 'Xan'), row(DailyGame.queens, 'y', 'Yas')],
        DailyGame.tango: [row(DailyGame.tango, 'x', 'Xan'), row(DailyGame.tango, 'y', 'Yas')],
      },
    );
    final out = overallStandings(s, const PuzzleState(), 'me');
    expect(out.map((r) => r.userId), ['x', 'y']);
    expect(out[0].wins, 2);
    expect(out[1].wins, 0);
  });

  test('a gave-up row is ranked but neither solved nor a win', () {
    final s = GameStandings(
      boards: {
        DailyGame.zip: [
          row(DailyGame.zip, 'g', 'Gus', solved: false),
        ],
      },
    );
    final out = overallStandings(s, const PuzzleState(), 'me');
    expect(out, hasLength(1));
    expect(out.single.solved, 0);
    expect(out.single.wins, 0);
    expect(out.single.rankSum, 1 + 1 + 1 + 1 + 1);
    expect(out.single.solvedByGame, [false, false, false, false, false]);
  });

  test('a code-only player counts, dot 1 is the code', () {
    final out = overallStandings(
      const GameStandings(),
      PuzzleState(scores: [code('k', 'Kai')]),
      'me',
    );
    expect(out.single.userId, 'k');
    expect(out.single.solved, 1);
    expect(out.single.wins, 1);
    expect(out.single.solvedByGame, [true, false, false, false, false]);
  });

  test('a viewer with no rows is absent; with rows, flagged and nameless', () {
    final s = GameStandings(
      boards: {
        DailyGame.sudoku: [row(DailyGame.sudoku, 'f', 'Fay')],
      },
    );
    final out = overallStandings(s, const PuzzleState(), 'me');
    expect(out.any((r) => r.isViewer), isFalse);

    final mine = overallStandings(
      s,
      PuzzleState(scores: [code('me', '')]),
      'me',
    );
    final me = mine.firstWhere((r) => r.isViewer);
    expect(me.name, '');
    expect(me.solved, 1);
  });

  test('the first non-empty name across rows is the one shown', () {
    final s = GameStandings(
      boards: {
        DailyGame.queens: [row(DailyGame.queens, 'n', '')],
        DailyGame.tango: [row(DailyGame.tango, 'n', 'Nia')],
      },
    );
    expect(overallStandings(s, const PuzzleState(), 'me').single.name, 'Nia');
  });

  test('a streak ranking is longest first, the viewer in it, lapsed absent', () {
    final s = GameStandings(
      streaks: {
        'u1': {DailyGame.zip: 3},
        'a': {DailyGame.zip: 7, DailyGame.queens: 2},
        'b': {DailyGame.zip: 3},
        'c': {DailyGame.queens: 9},
      },
      names: const {'a': 'Ada', 'b': 'Bo', 'c': 'Cem'},
      myStreaks: const {
        DailyGame.zip: GameStreak(current: 3, best: 5, today: true),
      },
    );
    final zip = s.streakRanking(DailyGame.zip, 'u1');
    expect([for (final r in zip) r.userId], ['a', 'u1', 'b']);
    // The viewer is "You", never their own name back at them.
    expect(zip[1].name, '');
    expect(s.streakRanking(DailyGame.tango, 'u1'), isEmpty);
  });
}
