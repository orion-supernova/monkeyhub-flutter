import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/puzzle.dart';

/// The puzzle's client-side model.
///
/// Scoring itself lives on the server (`backend/convex/puzzle.ts`) so the
/// answer never reaches the device while it can still be used. What is tested
/// here is everything the client derives from the feedback it is given — most
/// importantly the shareable grid, which is the one artifact that leaves the
/// app and lands in a group chat.
void main() {
  group('PuzzlePegs.shareRow', () {
    test('always spans exactly the number of slots', () {
      // A row that came out short or long would misalign the whole pasted grid
      // in someone else's chat, which is the only place it is ever seen.
      for (var exact = 0; exact <= kPuzzleSlots; exact++) {
        for (var present = 0; present + exact <= kPuzzleSlots; present++) {
          final row = PuzzlePegs(exact: exact, present: present).shareRow;
          expect(
            row.runes.length,
            kPuzzleSlots,
            reason: 'exact=$exact present=$present produced "$row"',
          );
        }
      }
    });

    test('orders green, then yellow, then blank', () {
      // Built from kPuzzleSlots rather than hardcoded, so changing the board
      // width fails the assertions that are genuinely about ORDER and not the
      // ones that are only about length — the previous version failed all of
      // them at once when the code went from five slots to four.
      String row(int green, int yellow) =>
          '🟩' * green + '🟨' * yellow + '⬜' * (kPuzzleSlots - green - yellow);

      expect(const PuzzlePegs(exact: 2, present: 1).shareRow, row(2, 1));
      expect(const PuzzlePegs(exact: 0, present: 0).shareRow, row(0, 0));
      expect(
        PuzzlePegs(exact: kPuzzleSlots, present: 0).shareRow,
        row(kPuzzleSlots, 0),
      );
      // The order itself: greens can never follow a yellow or a blank.
      final mixed = const PuzzlePegs(exact: 1, present: 1).shareRow;
      expect(mixed.startsWith('🟩'), isTrue);
      expect(mixed.runes.length, kPuzzleSlots);
    });

    test('a full board of exacts is all green', () {
      expect(
        PuzzlePegs(exact: kPuzzleSlots, present: 0).shareRow.contains('⬜'),
        isFalse,
      );
    });

    test('reveals no positional information', () {
      // The pegs are positionless by design. Two guesses with the same counts
      // must produce identical rows, or the grid would leak which slot was
      // right to anyone who has not played yet.
      const a = PuzzlePegs(exact: 1, present: 2);
      const b = PuzzlePegs(exact: 1, present: 2);
      expect(a.shareRow, b.shareRow);
    });
  });

  group('PuzzleAttempt', () {
    PuzzleAttempt attempt(int played, {bool solved = false}) => PuzzleAttempt(
      guesses: List.generate(played, (_) => List.filled(kPuzzleSlots, 0)),
      feedback: List.generate(
        played,
        (i) => PuzzlePegs(exact: i, present: 0),
      ),
      solved: solved,
      done: solved || played >= kPuzzleMaxGuesses,
    );

    test('remaining counts down from the maximum', () {
      expect(attempt(0).remaining, kPuzzleMaxGuesses);
      expect(attempt(1).remaining, kPuzzleMaxGuesses - 1);
      expect(attempt(kPuzzleMaxGuesses).remaining, 0);
    });

    test('started only once a guess exists', () {
      expect(attempt(0).started, isFalse);
      expect(attempt(1).started, isTrue);
    });

    test('shareGrid has one line per guess', () {
      expect(attempt(3).shareGrid.split('\n'), hasLength(3));
      expect(attempt(0).shareGrid, isEmpty);
    });
  });

  group('PuzzleAttempt.fromJson', () {
    test('withholds the answer while the game is live', () {
      // The server omits it until the player can no longer act; the client must
      // not invent one.
      final a = PuzzleAttempt.fromJson({
        'guesses': [
          [0, 1, 2, 3, 4],
        ],
        'feedback': [
          {'exact': 1, 'present': 1},
        ],
        'solved': false,
        'done': false,
      })!;
      expect(a.answer, isNull);
      expect(a.done, isFalse);
      expect(a.feedback.single.exact, 1);
    });

    test('accepts the answer once the attempt is finished', () {
      final a = PuzzleAttempt.fromJson({
        'guesses': const [],
        'feedback': const [],
        'solved': false,
        'done': true,
        'answer': [5, 4, 3, 2, 1],
      })!;
      expect(a.answer, [5, 4, 3, 2, 1]);
    });

    test('null attempt means the player has not started', () {
      expect(PuzzleAttempt.fromJson(null), isNull);
    });
  });

  group('PuzzleState', () {
    PuzzleScore score(
      String id, {
      int guesses = 3,
      bool solved = true,
      int? place,
    }) => PuzzleScore(
      userId: id,
      name: id,
      solved: solved,
      guessCount: guesses,
      finishedAt: DateTime(2026, 8, 7),
      feedback: const [],
      place: place,
    );

    test('rank is 1-based and null when absent', () {
      final s = PuzzleState(
        scores: [score('a', guesses: 2), score('b'), score('c', guesses: 4)],
      );
      expect(s.rankOf('a'), 1);
      expect(s.rankOf('c'), 3);
      expect(s.rankOf('nobody'), isNull);
    });

    test('equal guesses share a place; the finish time never decides', () {
      final s = PuzzleState(
        scores: [
          score('a'),
          score('b'),
          score('c', guesses: 5),
          score('x', solved: false, guesses: 6),
          score('y', solved: false, guesses: 6),
        ],
      );
      expect([for (final id in ['a', 'b', 'c', 'x', 'y']) s.rankOf(id)], [
        1, 1, 3, 4, 4,
      ]);
    });

    test("the server's place wins when it sends one", () {
      final s = PuzzleState(
        scores: [score('a', place: 1), score('b', guesses: 4, place: 1)],
      );
      expect(s.rankOf('b'), 1);
      expect(
        PuzzleScore.fromJson({'userId': 'q', 'place': 2}).place,
        2,
      );
      expect(PuzzleScore.fromJson({'userId': 'q'}).place, isNull);
    });

    test('ranked lists a tie A to Z, the viewer by "You"', () {
      final s = PuzzleState(
        scores: [
          PuzzleScore(
            userId: 'me',
            name: '',
            solved: true,
            guessCount: 3,
            finishedAt: DateTime(2026),
            feedback: const [],
          ),
          PuzzleScore(
            userId: 'w',
            name: 'Wim',
            solved: true,
            guessCount: 3,
            finishedAt: DateTime(2026),
            feedback: const [],
          ),
          PuzzleScore(
            userId: 'a',
            name: 'Ada',
            solved: true,
            guessCount: 3,
            finishedAt: DateTime(2026),
            feedback: const [],
          ),
        ],
      );
      final r = s.ranked(viewerId: 'me', you: 'You');
      expect([for (final e in r) e.row.userId], ['a', 'w', 'me']);
      expect([for (final e in r) e.place], [1, 1, 1]);
    });

    test('an absent payload is an empty state, not a crash', () {
      final s = PuzzleState.fromJson(null);
      expect(s.mine, isNull);
      expect(s.scores, isEmpty);
    });
  });
}
