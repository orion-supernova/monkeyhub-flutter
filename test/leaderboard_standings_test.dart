import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/games/leaderboard_standings.dart';

/// The overall ("Today") leaderboard: one point per puzzle solved, then
/// whoever won more boards; equal on both is a shared place, listed A to Z.
void main() {
  GameResult row(
    DailyGame g,
    String id,
    String name, {
    bool solved = true,
    int ms = 60000,
  }) => GameResult(
    game: g,
    solved: solved,
    gaveUp: !solved,
    finished: true,
    durationMs: solved ? ms : null,
    userId: id,
    name: name,
  );

  List<LeaderRow> overall(
    GameStandings s, [
    PuzzleState p = const PuzzleState(),
    String viewer = 'me',
  ]) => overallStandings(s, p, viewer, you: 'You');

  PuzzleScore code(String id, String name, {bool solved = true}) =>
      PuzzleScore(
        userId: id,
        name: name,
        solved: solved,
        guessCount: 4,
        finishedAt: DateTime(2026),
        feedback: const [],
      );

  test('equal solved and equal wins share first, listed A to Z', () {
    final s = GameStandings(
      boards: {
        // c wins queens, b second; a wins tango, c second; b wins zip.
        DailyGame.queens: [row(DailyGame.queens, 'c', 'cem', ms: 50000), row(DailyGame.queens, 'b', 'Bo')],
        DailyGame.tango: [row(DailyGame.tango, 'a', 'Ada', ms: 50000), row(DailyGame.tango, 'c', 'cem')],
        DailyGame.zip: [row(DailyGame.zip, 'b', 'Bo', ms: 50000), row(DailyGame.zip, 'a', 'Ada')],
      },
    );
    final out = overall(s);
    // Everyone solved 2 and won 1: no rank sum, no hidden tiebreak.
    expect(out.map((r) => r.userId), ['a', 'b', 'c']);
    expect(out.map((r) => r.place), [1, 1, 1]);
    expect(out.every((r) => r.solved == 2 && r.wins == 1), isTrue);
  });

  test('a board tied for first is a win for everyone on it', () {
    final s = GameStandings(
      boards: {
        // Same whole second (61.0 vs 61.9): both first, both win.
        DailyGame.queens: [
          row(DailyGame.queens, 'x', 'Xan', ms: 61000),
          row(DailyGame.queens, 'y', 'Yas', ms: 61900),
          row(DailyGame.queens, 'z', 'Zia', ms: 62000),
        ],
      },
    );
    final out = overall(s);
    expect(out.map((r) => r.userId), ['x', 'y', 'z']);
    expect(out.map((r) => r.wins), [1, 1, 0]);
    expect(out.map((r) => r.place), [1, 1, 2]);
  });

  test('a tie sorts the viewer by "You", not first for an empty name', () {
    final s = GameStandings(
      boards: {
        DailyGame.sudoku: [
          row(DailyGame.sudoku, 'me', ''),
          row(DailyGame.sudoku, 'z', 'Zoe'),
          row(DailyGame.sudoku, 'i', 'ılgın'),
          row(DailyGame.sudoku, 'e', 'Émile'),
        ],
      },
    );
    final out = overall(s);
    expect(out.map((r) => r.userId), ['e', 'i', 'me', 'z']);
    expect(out.map((r) => r.place), [1, 1, 1, 1]);
    expect(out.firstWhere((r) => r.isViewer).name, '');
  });

  test('wins break a tie on solved', () {
    final s = GameStandings(
      boards: {
        DailyGame.queens: [row(DailyGame.queens, 'x', 'Xan', ms: 50000), row(DailyGame.queens, 'y', 'Yas')],
        DailyGame.tango: [row(DailyGame.tango, 'y', 'Yas', ms: 70000), row(DailyGame.tango, 'x', 'Xan', ms: 90000)],
        DailyGame.zip: [row(DailyGame.zip, 'x', 'Xan', ms: 50000), row(DailyGame.zip, 'y', 'Yas')],
      },
    );
    final out = overall(s);
    expect(out.map((r) => r.userId), ['x', 'y']);
    expect(out[0].wins, 2);
    expect(out[1].wins, 1);
    expect(out.map((r) => r.place), [1, 2]);
  });

  test('a gave-up row is ranked but neither solved nor a win', () {
    final s = GameStandings(
      boards: {
        DailyGame.zip: [
          row(DailyGame.zip, 'g', 'Gus', solved: false),
        ],
      },
    );
    final out = overall(s);
    expect(out, hasLength(1));
    expect(out.single.solved, 0);
    expect(out.single.wins, 0);
    expect(
      out.single.solvedByGame,
      List<bool>.filled(kLeaderboardGames.length, false),
    );
  });

  test('a code-only player counts, dot 1 is the code', () {
    final out = overall(
      const GameStandings(),
      PuzzleState(scores: [code('k', 'Kai')]),
    );
    expect(out.single.userId, 'k');
    expect(out.single.solved, 1);
    expect(out.single.wins, 1);
    expect(out.single.solvedByGame, [
      true,
      ...List<bool>.filled(kLeaderboardGames.length - 1, false),
    ]);
  });

  test('a viewer with no rows is absent; with rows, flagged and nameless', () {
    final s = GameStandings(
      boards: {
        DailyGame.sudoku: [row(DailyGame.sudoku, 'f', 'Fay')],
      },
    );
    final out = overall(s);
    expect(out.any((r) => r.isViewer), isFalse);

    final mine = overall(s, PuzzleState(scores: [code('me', '')]));
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
    expect(overall(s).single.name, 'Nia');
  });

  test('rankOf and ranked share a place on the same whole second', () {
    final s = GameStandings.fromJson({
      'boards': {
        'zip': [
          {'userId': 'me', 'name': '', 'solved': true, 'durationMs': 40100, 'finishedAt': 1},
          {'userId': 'b', 'name': 'Bo', 'solved': true, 'durationMs': 40800, 'finishedAt': 2},
          {'userId': 'a', 'name': 'Ada', 'solved': true, 'durationMs': 41000, 'finishedAt': 3},
          {'userId': 'g', 'name': 'Gus', 'solved': false, 'gaveUp': true, 'finishedAt': 4},
        ],
      },
    });
    expect(s.rankOf(DailyGame.zip, 'me'), 1);
    expect(s.rankOf(DailyGame.zip, 'b'), 1);
    expect(s.rankOf(DailyGame.zip, 'a'), 2);
    expect(s.rankOf(DailyGame.zip, 'g'), 3);
    final r = s.ranked(DailyGame.zip, viewerId: 'me', you: 'You');
    expect([for (final e in r) e.row.userId], ['b', 'me', 'a', 'g']);
    expect([for (final e in r) e.place], [1, 1, 2, 3]);
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
    final zip = s.streakRanking(DailyGame.zip, 'u1', you: 'You');
    // Bo and the viewer tie on 3: A to Z, the viewer read as "You".
    expect([for (final r in zip) r.userId], ['a', 'b', 'u1']);
    // The viewer is "You", never their own name back at them.
    expect(zip[2].name, '');
    expect(s.streakRanking(DailyGame.tango, 'u1', you: 'You'), isEmpty);
  });
}
