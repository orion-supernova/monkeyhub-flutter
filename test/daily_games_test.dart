import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/games/game_rules.dart';
import 'package:monkeyhub/models/daily_game.dart';

/// The daily games' rules, checked against the engines that actually decide.
///
/// Every rule in `lib/games/game_rules.dart` also exists in
/// `backend/convex/games/*.ts`, and the split is not optional: the client has
/// to know instantly which cell is contradicting itself, and the server has to
/// be the only thing that says a board is solved. Two implementations of one
/// rule set drift, and the drift is silent in the worst direction — a grid that
/// looks finished while `submit` rejects it, or a legal cell painted as a
/// mistake.
///
/// So the load-bearing test here is the fixture one: real generated boards and
/// the answers the SERVER computed for them, asserted against the DART mirror.
/// A unit test written on either side alone would only be checking that
/// implementation against its own idea of the rules.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final days = (fixtures['days'] as List).cast<Map<String, dynamic>>();

  List<int> ints(dynamic raw) => [
    for (final v in raw as List) (v as num).toInt(),
  ];

  group('the Dart rules agree with the server engines', () {
    test('fixtures cover every game on several days', () {
      // Guards the whole group: an empty or truncated fixture file would make
      // every assertion below vacuously pass.
      expect(days.length, greaterThanOrEqualTo(4));
      for (final day in days) {
        for (final game in ['queens', 'tango', 'zip', 'sudoku']) {
          expect(day[game], isNotNull, reason: '${day['dayKey']}/$game');
        }
      }
    });

    test('queens accepts the server answer and nothing beside it', () {
      for (final day in days) {
        final entry = day['queens'] as Map<String, dynamic>;
        final board = QueensBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);
        final n = board.size;

        final marks = List<QueensMark>.filled(n * n, QueensMark.none);
        for (var row = 0; row < n; row++) {
          marks[row * n + answer[row]] = QueensMark.crown;
        }
        expect(
          queensSolved(board, marks),
          isTrue,
          reason: '${day['dayKey']}: server answer rejected by the mirror',
        );
        expect(queensConflicts(board, marks), isEmpty);
        expect(queensSolution(board, marks), answer);

        // Slide one crown along its row. Because the generator proves the
        // board has exactly one solution, every such board is illegal — so
        // this is a real check on the mirror's rules and not just on counting.
        for (var row = 0; row < n; row++) {
          for (var col = 0; col < n; col++) {
            if (col == answer[row]) continue;
            final moved = List<QueensMark>.of(marks);
            moved[row * n + answer[row]] = QueensMark.none;
            moved[row * n + col] = QueensMark.crown;
            expect(
              queensSolved(board, moved),
              isFalse,
              reason: '${day['dayKey']}: row $row column $col was accepted',
            );
          }
        }
      }
    });

    test('tango accepts the server answer and rejects a flipped cell', () {
      for (final day in days) {
        final entry = day['tango'] as Map<String, dynamic>;
        final board = TangoBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);

        expect(
          tangoSolved(board, answer),
          isTrue,
          reason: '${day['dayKey']}: server answer rejected by the mirror',
        );
        expect(tangoTrouble(board, answer).isEmpty, isTrue);

        for (var i = 0; i < answer.length; i++) {
          final flipped = List<int>.of(answer);
          flipped[i] = answer[i] == tangoSun ? tangoMoon : tangoSun;
          expect(
            tangoSolved(board, flipped),
            isFalse,
            reason: '${day['dayKey']}: flipping cell $i was accepted',
          );
          // And it must be able to SAY where: a board that knows the grid is
          // wrong but highlights nothing is useless to the player.
          expect(tangoTrouble(board, flipped).cells, isNotEmpty);
        }
      }
    });

    test('sudoku accepts the server answer and rejects a changed digit', () {
      for (final day in days) {
        final entry = day['sudoku'] as Map<String, dynamic>;
        final board = SudokuBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);

        expect(
          sudokuSolved(board, answer),
          isTrue,
          reason: '${day['dayKey']}: server answer rejected by the mirror',
        );
        expect(sudokuConflicts(board, answer), isEmpty);

        for (var i = 0; i < answer.length; i += 5) {
          final wrong = List<int>.of(answer);
          wrong[i] = answer[i] == 1 ? 2 : 1;
          expect(sudokuSolved(board, wrong), isFalse);
          expect(sudokuConflicts(board, wrong), contains(i));
        }
      }
    });

    test('zip accepts the generated route and walks it a step at a time', () {
      for (final day in days) {
        final entry = day['zip'] as Map<String, dynamic>;
        final board = ZipBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);

        expect(
          zipSolved(board, answer),
          isTrue,
          reason: '${day['dayKey']}: server route rejected by the mirror',
        );

        // The move gate has to admit the whole route one cell at a time. If it
        // refuses a step the server would accept, that route is undrawable —
        // the player cannot reach a solution the board considers correct.
        final drawn = <int>[];
        for (final cell in answer) {
          expect(
            zipCanEnter(board, drawn, cell),
            isTrue,
            reason: '${day['dayKey']}: gate refused step ${drawn.length}',
          );
          drawn.add(cell);
        }
        expect(drawn, answer);

        // A route one cell short, and one that repeats a cell, are both wrong.
        expect(zipSolved(board, answer.sublist(0, answer.length - 1)), isFalse);
        expect(
          zipSolved(board, [...answer.sublist(0, answer.length - 1), answer[0]]),
          isFalse,
        );
      }
    });
  });

  group('queens', () {
    // A board whose regions are eight horizontal bands, so region and row are
    // the same constraint and the rules can be exercised one at a time.
    final board = QueensBoard(
      size: 4,
      regions: [
        for (var i = 0; i < 16; i++) i ~/ 4,
      ],
    );

    List<QueensMark> marksOf(List<int> cells) {
      final marks = List<QueensMark>.filled(16, QueensMark.none);
      for (final c in cells) {
        marks[c] = QueensMark.crown;
      }
      return marks;
    }

    test('two crowns in a column clash', () {
      expect(queensConflicts(board, marksOf([0, 8])), {0, 8});
    });

    test('crowns that touch diagonally clash', () {
      expect(queensConflicts(board, marksOf([0, 5])), {0, 5});
    });

    test('crowns two columns apart on adjacent rows do not', () {
      expect(queensConflicts(board, marksOf([0, 6])), isEmpty);
    });

    test('two crowns in one row leave the board without a solution', () {
      // Not a conflict *set* question — `queensSolution` refuses outright,
      // because "a column per row" has no answer for a row holding two.
      expect(queensSolution(board, marksOf([0, 2])), isNull);
    });

    test('auto-cross covers the row, column, colour and the ring around', () {
      final blocked = queensBlocked(board, marksOf([5]));
      expect(blocked, contains(4)); // same row
      expect(blocked, contains(1)); // same column
      expect(blocked, contains(0)); // diagonal touch
      expect(blocked, contains(10)); // diagonal the other way
      expect(blocked, isNot(contains(5))); // never the crown itself
      // Row 3, column 3: a different row, column and band, and two columns
      // clear of the crown — the only kind of cell that survives.
      expect(blocked, isNot(contains(15)));
    });

    test('a board that has not arrived is never solved', () {
      // The guard that matters: without it an empty grid reads as "zero rows,
      // all satisfied" and the screen auto-submits nothing at all.
      expect(queensSolved(QueensBoard.empty, const []), isFalse);
      expect(queensSolution(QueensBoard.empty, const []), isNull);
    });
  });

  group('tango', () {
    const board = TangoBoard(
      size: 4,
      givens: [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
      signs: [TangoSign(a: 0, b: 1, eq: true)],
    );

    test('three of one symbol in a row is flagged, two is not', () {
      final two = List<int>.filled(16, tangoEmpty);
      two[0] = tangoSun;
      two[1] = tangoSun;
      expect(tangoTrouble(board, two).cells, isEmpty);

      final three = List<int>.of(two)..[2] = tangoSun;
      expect(tangoTrouble(board, three).cells, containsAll([0, 1, 2]));
    });

    test('a broken operator names itself as well as its two cells', () {
      final cells = List<int>.filled(16, tangoEmpty);
      cells[0] = tangoSun;
      cells[1] = tangoMoon;
      final trouble = tangoTrouble(board, cells);
      expect(trouble.signs, {0});
      expect(trouble.cells, containsAll([0, 1]));
    });

    test('a half-filled line is not yet an over-count', () {
      // Reporting "too many suns" before there are too many would be telling
      // the player they are wrong for having started.
      final cells = List<int>.filled(16, tangoEmpty);
      cells[0] = tangoSun;
      cells[4] = tangoSun;
      expect(tangoTrouble(board, cells).cells, isEmpty);
    });

    test('more than half a line of one symbol is', () {
      final cells = List<int>.filled(16, tangoEmpty);
      cells[0] = tangoSun;
      cells[4] = tangoSun;
      cells[8] = tangoSun;
      expect(tangoTrouble(board, cells).cells, containsAll([0, 4, 8]));
    });

    test('an unarrived board is never solved', () {
      expect(tangoSolved(TangoBoard.empty, const []), isFalse);
    });
  });

  group('mini sudoku', () {
    const board = SudokuBoard(size: 6, givens: []);

    test('a repeat inside a 2x3 box is a conflict', () {
      final cells = List<int>.filled(36, sudokuEmpty);
      cells[0] = 4;
      cells[7] = 4; // row 1, column 1 — same box, different row and column
      expect(sudokuConflicts(board, cells), {0, 7});
    });

    test('the same digit in different boxes, rows and columns is not', () {
      final cells = List<int>.filled(36, sudokuEmpty);
      cells[0] = 4;
      cells[21] = 4; // row 3, column 3
      expect(sudokuConflicts(board, cells), isEmpty);
    });

    test('an unarrived board is never solved', () {
      expect(sudokuSolved(SudokuBoard.empty, const []), isFalse);
    });
  });

  group('zip', () {
    const board = ZipBoard(size: 3, checkpoints: [0, 4, 8]);

    test('the line must start on the first dot', () {
      expect(zipCanEnter(board, const [], 1), isFalse);
      expect(zipCanEnter(board, const [], 0), isTrue);
    });

    test('a step must be orthogonal and onto an unvisited cell', () {
      expect(zipCanEnter(board, const [0], 4), isFalse); // diagonal
      expect(zipCanEnter(board, const [0], 1), isTrue);
      expect(zipCanEnter(board, const [0, 1], 0), isFalse); // already visited
    });

    test('a numbered dot may not be entered before the one before it', () {
      // ⑧ sits at cell 8; reaching it before ⑤ at cell 4 is exactly the case
      // the gate exists for, and it refuses rather than reporting it after.
      expect(zipCanEnter(board, const [0, 1, 2, 5], 8), isFalse);
      expect(zipCanEnter(board, const [0, 1, 2, 5, 4], 7), isTrue);
    });

    test('a full legal route is solved', () {
      expect(zipSolved(board, const [0, 1, 2, 5, 4, 3, 6, 7, 8]), isTrue);
    });

    test('a route that misses a cell is not, even if it hits every dot', () {
      expect(zipSolved(board, const [0, 1, 4, 7, 8]), isFalse);
    });

    test('an unarrived board is never solved or enterable', () {
      expect(zipSolved(ZipBoard.empty, const []), isFalse);
      expect(zipCanEnter(ZipBoard.empty, const [], 0), isFalse);
    });
  });

  group('wire decoding', () {
    test('a whole day of boards round-trips', () {
      final day = days.first;
      final boards = DailyBoards.fromJson({
        'dayKey': day['dayKey'],
        'queens': (day['queens'] as Map)['board'],
        'tango': (day['tango'] as Map)['board'],
        'zip': (day['zip'] as Map)['board'],
        'sudoku': (day['sudoku'] as Map)['board'],
      });
      expect(boards.ready, isTrue);
      expect(boards.queens.size, 8);
      expect(boards.queens.regions, hasLength(64));
      expect(boards.tango.size, 6);
      expect(boards.tango.signs, isNotEmpty);
      expect(boards.zip.checkpoints, hasLength(8));
      expect(boards.sudoku.givens, hasLength(36));
    });

    test('a missing payload decodes to a board that is not ready', () {
      // The hub gates on `ready`, so a partial payload must not render as four
      // empty grids that look playable.
      expect(DailyBoards.fromJson(null).ready, isFalse);
      expect(DailyBoards.fromJson(const {'dayKey': 'x'}).ready, isFalse);
    });

    test('standings decode per game, and an unknown game is dropped', () {
      final standings = GameStandings.fromJson({
        'mine': {
          'queens': {'solved': true, 'durationMs': 61000, 'finishedAt': 1},
        },
        'progress': {
          'tango': [0, 1, 0],
        },
        'boards': {
          'queens': [
            {'userId': 'a', 'name': 'ada', 'solved': true, 'durationMs': 61000},
            {'userId': 'b', 'name': 'bo', 'solved': false, 'gaveUp': true},
          ],
          // A game a newer server has started shipping and this build has never
          // heard of. It must not take the rest of the payload down with it.
          'hexle': [
            {'userId': 'c', 'solved': true},
          ],
        },
      });

      expect(standings.mine[DailyGame.queens]?.solved, isTrue);
      expect(standings.mine[DailyGame.queens]?.finished, isTrue);
      expect(standings.progress[DailyGame.tango], [0, 1, 0]);
      expect(standings.boards[DailyGame.queens], hasLength(2));
      expect(standings.boards.keys, isNot(contains(null)));
      expect(standings.rankOf(DailyGame.queens, 'b'), 2);
      expect(standings.rankOf(DailyGame.queens, 'nobody'), isNull);
      expect(standings.rankOf(DailyGame.zip, 'a'), isNull);
    });

    test('an unfinished row reads as unfinished, not as a loss', () {
      final row = GameResult.fromJson(
        const {'game': 'zip', 'solved': false},
      );
      expect(row?.game, DailyGame.zip);
      expect(row?.finished, isFalse);
      expect(row?.gaveUp, isFalse);
    });
  });

  group('formatGameTime', () {
    test('reads as a stopwatch, with seconds always two digits', () {
      expect(formatGameTime(0), '0:00');
      expect(formatGameTime(9000), '0:09');
      expect(formatGameTime(61000), '1:01');
      expect(formatGameTime(599000), '9:59');
      expect(formatGameTime(3600000), '1:00:00');
      expect(formatGameTime(3661000), '1:01:01');
    });

    test('a board with no time shows a dash rather than zero', () {
      // 0:00 would read as an impossibly fast solve on a leaderboard row.
      expect(formatGameTime(null), '—');
    });
  });
}
