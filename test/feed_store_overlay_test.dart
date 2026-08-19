import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';

/// The Feed board is ONE live query, so everything on it — the puzzle grid, the
/// games band, the nav badge — shares a single point of failure. When that
/// subscription goes quiet (a socket the OS suspended is the usual way), a
/// player's own confirmed write used to leave no trace on screen: the puzzle
/// screen cleared its draft and the grid still showed the state from before the
/// guess, so an accepted guess simply vanished and only a restart brought it
/// back.
///
/// These pin the overlay that fixes it, and — just as importantly — the two
/// ways it must NOT misbehave: it may never roll a row backwards, and it must
/// not survive into another day or another account.
void main() {
  final store = FeedStore.instance;

  PuzzleAttempt attempt(int rows, {bool solved = false, bool done = false}) =>
      PuzzleAttempt(
        guesses: [for (var i = 0; i < rows; i++) List.filled(kPuzzleSlots, 0)],
        feedback: [
          for (var i = 0; i < rows; i++) const PuzzlePegs(exact: 0, present: 0),
        ],
        solved: solved,
        done: done,
      );

  /// Delivers a payload exactly as the board subscription would.
  void board({PuzzleState puzzle = const PuzzleState()}) => store.applyBoard(
    FeedBoard(
      moments: const [],
      serverNow: DateTime.fromMillisecondsSinceEpoch(0),
      puzzle: puzzle,
    ),
  );

  /// Moves the store onto another day, the way midnight does.
  void rollTo(DateTime when) {
    store.clock = () => when;
    // stop/start is the public route back through _syncDay; the rollover timer
    // takes the same one when it fires.
    store.stop();
    store.start();
  }

  GameResult finished(DailyGame g) =>
      GameResult(game: g, solved: true, gaveUp: false, finished: true);

  setUp(() async {
    store.clock = DateTime.now;
    await store.detach();
    store.start();
  });

  tearDown(() async {
    store.clock = DateTime.now;
    await store.detach();
  });

  group('puzzle overlay', () {
    test('a guess shows up with no board payload at all', () {
      // The whole bug: this is the state of a client whose board subscription
      // never delivered. Before the overlay, `puzzle.mine` stayed null here and
      // the player watched their accepted guess disappear.
      expect(store.puzzle.mine, isNull);
      store.applyPuzzleAttempt(attempt(1));
      expect(store.puzzle.mine?.guesses.length, 1);
    });

    test('notifies, so a screen listening to the store repaints', () {
      // The row landing in the store is only half of it — nothing redraws
      // without this, which from the player's seat is the same bug.
      var notified = 0;
      void listener() => notified++;
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      store.applyPuzzleAttempt(attempt(1));
      expect(notified, 1);
    });

    test('a stale board payload cannot roll the row back', () {
      // A payload computed BEFORE the guess can land after it. Ordering the two
      // by guess count rather than by arrival is what makes that harmless —
      // guesses only ever grow within a day.
      store.applyPuzzleAttempt(attempt(3));
      board(puzzle: PuzzleState(mine: attempt(2)));
      expect(store.puzzle.mine?.guesses.length, 3);
    });

    test('the real payload takes over as soon as it catches up', () {
      // The overlay is a stopgap, not a second source of truth: the board
      // carries the revealed answer and the scoreboard, which a mutation reply
      // never does. On a tie the board must win.
      store.applyPuzzleAttempt(attempt(2));
      board(puzzle: PuzzleState(mine: attempt(2, done: true, solved: true)));
      expect(store.puzzle.mine?.done, isTrue);
      expect(store.puzzle.mine?.solved, isTrue);
    });

    test('the board keeps its scoreboard while the overlay is showing', () {
      // The overlay replaces the viewer's own row only. Blanking everyone
      // else's would trade one missing thing for another.
      final scores = [
        PuzzleScore(
          userId: 'u2',
          name: 'ada',
          solved: true,
          guessCount: 3,
          finishedAt: DateTime.fromMillisecondsSinceEpoch(0),
          feedback: const [],
        ),
      ];
      board(puzzle: PuzzleState(scores: scores));
      store.applyPuzzleAttempt(attempt(1));
      expect(store.puzzle.mine?.guesses.length, 1);
      expect(store.puzzle.scores.single.userId, 'u2');
    });

    test('does not leak across the midnight rollover', () {
      // Day-stamped rather than cleared on a timer. Without this the first
      // thing a player saw on a new day was yesterday's finished grid, on a
      // puzzle they had not started.
      store.applyPuzzleAttempt(attempt(4));
      expect(store.puzzle.mine, isNotNull);

      rollTo(DateTime.now().add(const Duration(days: 1)));
      expect(store.puzzle.mine, isNull);
    });

    test('does not survive sign-out', () async {
      // Another account's data on a shared handset.
      store.applyPuzzleAttempt(attempt(2));
      await store.detach();
      store.start();
      expect(store.puzzle.mine, isNull);
    });
  });

  group('games overlay', () {
    test('a finished game stops being counted as left to play', () {
      final before = store.gamesLeft;
      expect(before, DailyGame.values.length);

      store.noteGameFinished(DailyGame.values.first, finished(DailyGame.values.first));
      expect(store.gamesLeft, before - 1);
      expect(store.games[DailyGame.values.first]?.finished, isTrue);
    });

    test('finishing a second game does not forget the first', () {
      // The overlay accumulates. A naive replace would have made the band count
      // down and then back up again.
      if (DailyGame.values.length < 2) return;
      final a = DailyGame.values[0];
      final b = DailyGame.values[1];
      store.noteGameFinished(a, finished(a));
      store.noteGameFinished(b, finished(b));
      expect(store.games[a]?.finished, isTrue);
      expect(store.games[b]?.finished, isTrue);
      expect(store.gamesLeft, DailyGame.values.length - 2);
    });

    test('does not leak across the midnight rollover', () {
      store.noteGameFinished(DailyGame.values.first, finished(DailyGame.values.first));
      rollTo(DateTime.now().add(const Duration(days: 1)));
      expect(store.gamesLeft, DailyGame.values.length);
    });
  });
}
