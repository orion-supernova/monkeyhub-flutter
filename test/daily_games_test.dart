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
        for (final game in [
          'queens',
          'tango',
          'zip',
          'sudoku',
          'flow',
          'futoshiki',
          'nonogram',
          'minesweeper',
          'starbattle',
          'patches',
        ]) {
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

  group('the new five agree with the server engines', () {
    test('flow accepts the server pipes and nothing one step short', () {
      for (final day in days) {
        final entry = day['flow'] as Map<String, dynamic>;
        final board = FlowBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);
        final pipes = flowPipesOf(board, answer);

        expect(pipes, hasLength(board.endpoints.length));
        expect(
          flowSolved(board, pipes),
          isTrue,
          reason: '${day['dayKey']}: server pipes rejected by the mirror',
        );
        expect(flowSolution(board, pipes), answer);

        // A pipe drawn from its other dot is the same pipe: the player drags
        // from whichever end is nearer, and the submission is turned round.
        final flipped = [
          for (var k = 0; k < pipes.length; k++)
            k == 0 ? pipes[k].reversed.toList() : pipes[k],
        ];
        expect(flowSolution(board, flipped), answer);

        // Every pipe cut one square short leaves the board unsolved.
        for (var k = 0; k < pipes.length; k++) {
          final short = [
            for (var j = 0; j < pipes.length; j++)
              j == k ? pipes[j].sublist(0, pipes[j].length - 1) : pipes[j],
          ];
          expect(flowSolved(board, short), isFalse, reason: 'pipe $k');
        }
      }
    });

    test('futoshiki accepts the server answer and rejects a changed digit', () {
      for (final day in days) {
        final entry = day['futoshiki'] as Map<String, dynamic>;
        final board = FutoshikiBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);

        expect(
          futoshikiSolved(board, answer),
          isTrue,
          reason: '${day['dayKey']}: server answer rejected by the mirror',
        );
        expect(futoshikiTrouble(board, answer).isEmpty, isTrue);
        for (var i = 0; i < answer.length; i++) {
          final wrong = List<int>.of(answer);
          wrong[i] = answer[i] % board.size + 1;
          expect(futoshikiSolved(board, wrong), isFalse);
          // A changed digit always repeats one in its row, so the board can
          // say where.
          expect(futoshikiTrouble(board, wrong).cells, contains(i));
        }
      }
    });

    test('nonogram accepts the server picture and rejects a flipped square', () {
      for (final day in days) {
        final entry = day['nonogram'] as Map<String, dynamic>;
        final board = NonogramBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);
        final cells = [
          for (final v in answer) v == 1 ? nonogramFilled : nonogramCrossed,
        ];

        expect(
          nonogramSolved(board, cells),
          isTrue,
          reason: '${day['dayKey']}: server picture rejected by the mirror',
        );
        expect(nonogramSolution(cells), answer);
        expect(nonogramTrouble(board, cells).isEmpty, isTrue);
        // Crossed and untouched blanks mean the same thing to a clue.
        final bare = [
          for (final v in answer) v == 1 ? nonogramFilled : nonogramUnknown,
        ];
        expect(nonogramSolved(board, bare), isTrue);
        // An empty grid contradicts nothing yet.
        expect(
          nonogramTrouble(
            board,
            List<int>.filled(answer.length, nonogramUnknown),
          ).isEmpty,
          isTrue,
        );

        for (var i = 0; i < cells.length; i++) {
          final flipped = List<int>.of(cells);
          flipped[i] = cells[i] == nonogramFilled
              ? nonogramCrossed
              : nonogramFilled;
          expect(nonogramSolved(board, flipped), isFalse);
          // A fully decided line that no longer reads back its clue has no
          // arrangement left, so the mistake is visible on its row.
          expect(
            nonogramTrouble(board, flipped).rows,
            contains(i ~/ board.size),
          );
        }
      }
    });

    test('minesweeper decodes the same mines the server placed', () {
      for (final day in days) {
        final dayKey = day['dayKey'] as String;
        final entry = day['minesweeper'] as Map<String, dynamic>;
        final board = MinesweeperBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);
        final mines = minesweeperMines(board, dayKey);

        expect(mines, answer, reason: '$dayKey: Dart decode drifted from TS');
        expect(mines.fold(0, (a, b) => a + b), board.mineCount);
        // The opening square is a promised 0 with no mine around it.
        final numbers = minesweeperNumbers(mines, board.size);
        expect(mines[board.start], 0);
        expect(numbers[board.start], 0);
        // A wrong day key decodes to a different layout: the mask is real.
        expect(minesweeperMines(board, '1999-01-01'), isNot(answer));
      }
    });

    test('the mask decodes like TypeScript on sixty day keys', () {
      // The mask is mulberry32 over FNV-1a, ported with 32-bit wrapping, and
      // a port like that goes wrong on a handful of seeds rather than all of
      // them — so many keys, not one.
      final masks =
          (fixtures['minesweeperMasks'] as List).cast<Map<String, dynamic>>();
      expect(masks.length, greaterThanOrEqualTo(60));
      for (final m in masks) {
        final board = MinesweeperBoard(
          size: 9,
          start: 0,
          mineCount: 0,
          mines: m['mines'] as String,
        );
        expect(
          minesweeperMines(board, m['dayKey'] as String),
          ints(m['map']),
          reason: '${m['dayKey']}',
        );
      }
    });

    test('a cleared field is every safe square open', () {
      final day = days.first;
      final board = MinesweeperBoard.fromJson(
        ((day['minesweeper'] as Map)['board'] as Map).cast<String, dynamic>(),
      );
      final mines = minesweeperMines(board, day['dayKey'] as String);
      final numbers = minesweeperNumbers(mines, board.size);
      final cells = List<int>.filled(mines.length, minesweeperHidden);
      for (final i in minesweeperFlood(
        cells,
        mines,
        numbers,
        board.size,
        board.start,
      )) {
        cells[i] = numbers[i];
      }
      // The opening opens more than itself: it is a 0.
      expect(cells.where((v) => v >= 0).length, greaterThan(1));
      expect(minesweeperCleared(cells, mines), isFalse);
      for (var i = 0; i < cells.length; i++) {
        if (mines[i] == 0) cells[i] = numbers[i];
      }
      expect(minesweeperCleared(cells, mines), isTrue);
    });

    test('star battle accepts the server answer and nothing beside it', () {
      for (final day in days) {
        final entry = day['starbattle'] as Map<String, dynamic>;
        final board = StarBattleBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);
        final marks = [
          for (final v in answer) v == 1 ? StarMark.star : StarMark.none,
        ];

        expect(
          starBattleSolved(board, marks),
          isTrue,
          reason: '${day['dayKey']}: server answer rejected by the mirror',
        );
        expect(starBattleConflicts(board, marks), isEmpty);
        expect(starBattleSolution(marks), answer);

        // Slide each star one square sideways: the board has one answer, so
        // every such board is wrong.
        for (var i = 0; i < answer.length; i++) {
          if (answer[i] != 1) continue;
          final to = i % board.size == 0 ? i + 1 : i - 1;
          if (answer[to] == 1) continue;
          final moved = List<StarMark>.of(marks)
            ..[i] = StarMark.none
            ..[to] = StarMark.star;
          expect(starBattleSolved(board, moved), isFalse);
        }
      }
    });

    test('patches accepts the server answer and nothing beside it', () {
      for (final day in days) {
        final entry = day['patches'] as Map<String, dynamic>;
        final board = PatchesBoard.fromJson(
          (entry['board'] as Map).cast<String, dynamic>(),
        );
        final answer = ints(entry['answer']);
        final patches = patchesFromLabels(board, answer);

        expect(
          patches.every((p) => p != null),
          isTrue,
          reason: '${day['dayKey']}: a server patch the mirror cannot read',
        );
        expect(
          patchesSolved(board, patches),
          isTrue,
          reason: '${day['dayKey']}: server answer rejected by the mirror',
        );
        expect(patchesSolution(board, patches), answer);
        expect(patchesLabels(board, patches), answer);
        for (var k = 0; k < patches.length; k++) {
          expect(patchJudge(board, patches[k]!), (clue: k, trouble: null));
        }

        // Every patch one row or column short: legal or not on its own, the
        // board is no longer covered.
        for (var k = 0; k < patches.length; k++) {
          final p = patches[k]!;
          if (p.area == 1) continue;
          final shrunk = p.rows > 1
              ? PatchRect(p.top, p.left, p.bottom - 1, p.right)
              : PatchRect(p.top, p.left, p.bottom, p.right - 1);
          final cut = List<PatchRect?>.of(patches)..[k] = shrunk;
          expect(patchesSolved(board, cut), isFalse);
        }

        // The whole board as one rectangle holds every clue.
        final n = board.size;
        expect(
          patchJudge(board, PatchRect(0, 0, n - 1, n - 1)).trouble,
          PatchTrouble.twoClues,
        );
      }
    });

    test('a patch has to match its clue', () {
      const board = PatchesBoard(
        size: 4,
        clues: [
          PatchClue(cell: 0, shape: PatchShape.square, area: 4),
          PatchClue(cell: 3, shape: PatchShape.tall),
          PatchClue(cell: 12, shape: PatchShape.wide, area: 3),
          PatchClue(cell: 15, shape: PatchShape.any, area: 2),
        ],
      );
      expect(patchJudge(board, PatchRect.span(0, 5, 4)), (clue: 0, trouble: null));
      // The top row holds two clues; the 1×3 holds one, at the wrong size.
      expect(patchJudge(board, PatchRect.span(0, 3, 4)).trouble, PatchTrouble.twoClues);
      expect(patchJudge(board, PatchRect.span(0, 12, 4)).trouble, PatchTrouble.twoClues);
      expect(patchJudge(board, PatchRect.span(0, 2, 4)).trouble, PatchTrouble.area);
      expect(patchJudge(board, PatchRect.span(1, 9, 4)).trouble, PatchTrouble.noClue);
      // Tall with no number: any upright bar, never a lying one or a square.
      expect(patchJudge(board, PatchRect.span(3, 11, 4)), (clue: 1, trouble: null));
      expect(patchJudge(board, PatchRect.span(2, 3, 4)).trouble, PatchTrouble.shape);
      expect(patchJudge(board, PatchRect.span(3, 3, 4)).trouble, PatchTrouble.shape);
      expect(patchJudge(board, PatchRect.span(12, 14, 4)), (clue: 2, trouble: null));
      expect(patchJudge(board, PatchRect.span(14, 15, 4)), (clue: 3, trouble: null));
      expect(patchJudge(board, PatchRect.span(11, 15, 4)), (clue: 3, trouble: null));
      // The drag can run either way round.
      expect(PatchRect.span(15, 10, 4), PatchRect.span(10, 15, 4));
    });
  });

  group('nonogram lines', () {
    const u = nonogramUnknown;
    const f = nonogramFilled;
    const x = nonogramCrossed;

    test('an undecided line fits any clue that is short enough', () {
      expect(nonogramLineFits(const [3, 1], const [u, u, u, u, u]), isTrue);
      expect(nonogramLineFits(const [3, 2], const [u, u, u, u, u]), isFalse);
    });

    test('a cross inside the only place a run fits breaks the line', () {
      expect(nonogramLineFits(const [4], const [u, u, x, u, u]), isFalse);
      expect(nonogramLineFits(const [2], const [u, u, x, u, u]), isTrue);
    });

    test('shading more than the clue allows breaks the line', () {
      expect(nonogramLineFits(const [1, 1], const [f, f, u, u, u]), isFalse);
      expect(nonogramLineFits(const [2], const [f, u, u, f, u]), isFalse);
      expect(nonogramLineFits(const [1, 1], const [f, u, u, f, u]), isTrue);
    });

    test('an empty clue allows no shading at all', () {
      expect(nonogramLineFits(const [], const [u, x, u]), isTrue);
      expect(nonogramLineFits(const [], const [u, f, u]), isFalse);
    });

    test('runs read back in order, an empty line as no runs', () {
      expect(nonogramRuns(const [f, f, x, f, u, f, f, f]), [2, 1, 3]);
      expect(nonogramRuns(const [x, u, x]), isEmpty);
    });
  });

  group('star battle', () {
    final board = StarBattleBoard(
      size: 4,
      regions: [for (var i = 0; i < 16; i++) i ~/ 4],
    );

    List<StarMark> marksOf(List<int> cells) => [
      for (var i = 0; i < 16; i++)
        cells.contains(i) ? StarMark.star : StarMark.none,
    ];

    test('stars touching at a corner clash', () {
      expect(starBattleConflicts(board, marksOf([0, 5])), {0, 5});
    });

    test('a third star in a row clashes with the other two', () {
      final wide = StarBattleBoard(
        size: 6,
        regions: [for (var i = 0; i < 36; i++) i % 6],
      );
      final marks = [
        for (var i = 0; i < 36; i++)
          i == 0 || i == 2 || i == 4 ? StarMark.star : StarMark.none,
      ];
      expect(starBattleConflicts(wide, marks), {0, 2, 4});
    });

    test('two stars apart in a row are fine, and dot out the rest of it', () {
      expect(starBattleConflicts(board, marksOf([0, 2])), isEmpty);
      final blocked = starBattleBlocked(board, marksOf([0, 2]));
      expect(blocked, containsAll([1, 3, 4, 5, 6, 7]));
      expect(blocked, isNot(contains(8)));
    });
  });

  group('flow', () {
    const board = FlowBoard(size: 3, endpoints: [(0, 2), (3, 8)]);

    test('a pipe through another colour\'s dot is not a pipe', () {
      expect(flowPipeComplete(board, 0, const [0, 3, 4, 1, 2]), isFalse);
      expect(flowPipeComplete(board, 0, const [0, 1, 2]), isTrue);
    });

    test('a full legal filling is solved, in either direction', () {
      final pipes = [
        const [2, 1, 0],
        const [3, 6, 7, 4, 5, 8],
      ];
      expect(flowSolution(board, pipes), [0, 1, 2, 3, 6, 7, 4, 5, 8]);
    });

    test('a filling that leaves a square empty is not', () {
      final pipes = [
        const [0, 1, 2],
        const [3, 4, 5, 8],
      ];
      expect(flowSolved(board, pipes), isFalse);
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
        'flow': (day['flow'] as Map)['board'],
        'futoshiki': (day['futoshiki'] as Map)['board'],
        'nonogram': (day['nonogram'] as Map)['board'],
        'minesweeper': (day['minesweeper'] as Map)['board'],
        'starbattle': (day['starbattle'] as Map)['board'],
        'patches': (day['patches'] as Map)['board'],
      });
      expect(boards.ready, isTrue);
      expect(boards.patches.size, 7);
      expect(boards.patches.clues.length, inInclusiveRange(8, 10));
      expect(boards.flow.size, 7);
      expect(boards.flow.endpoints.length, greaterThanOrEqualTo(6));
      expect(boards.futoshiki.givens, hasLength(25));
      expect(boards.nonogram.rows, hasLength(10));
      expect(boards.nonogram.cols, hasLength(10));
      expect(boards.minesweeper.mines, hasLength(22));
      expect(boards.starbattle.regions, hasLength(100));
      for (final game in DailyGame.values) {
        expect(boards.sizeOf(game), greaterThan(0), reason: game.wire);
      }
      expect(boards.queens.size, 8);
      expect(boards.queens.regions, hasLength(64));
      expect(boards.tango.size, 6);
      expect(boards.tango.signs, isNotEmpty);
      expect(boards.zip.checkpoints, hasLength(8));
      expect(boards.sudoku.givens, hasLength(36));
    });

    test('a payload from before the new five is not ready', () {
      // A board cached on disk by an older build has only the first four;
      // reading it as ready would draw five empty tiles that look playable.
      final day = days.first;
      final old = DailyBoards.fromJson({
        'dayKey': day['dayKey'],
        for (final g in ['queens', 'tango', 'zip', 'sudoku'])
          g: (day[g] as Map)['board'],
      });
      expect(old.ready, isFalse);
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
      expect(formatGameTime(null), '–');
    });
  });
}
