import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/daily_game.dart';
import '../../widgets/puzzle_symbol.dart';
import '../flow_board_art.dart';
import '../futoshiki_board_art.dart';
import '../game_rules.dart';
import '../minesweeper_board_art.dart';
import '../nonogram_board_art.dart';
import '../patches_board_art.dart';
import '../queens_board_art.dart';
import '../starbattle_board_art.dart';
import '../sudoku_board_art.dart';
import '../tango_board_art.dart';
import '../zip_board_art.dart';
import 'demo_kit.dart';

// The daily puzzles' demos. Each one is a tiny hand-made board (smaller than
// the real one, so it reads at a glance) with a short script of moves. Times
// are loop fractions; the loop fades out after ~0.94.

List<FingerKey> _taps(DemoBoard b, List<(double, int)> taps) => [
  for (final (t, cell) in taps) FingerKey(t, b.center(cell), tap: true),
];

/// Finger keys gliding cell to cell along [cells], from [from] to [to].
List<FingerKey> _drag(DemoBoard b, List<int> cells, double from, double to) {
  if (cells.isEmpty) return const [];
  final step = cells.length < 2 ? 0.0 : (to - from) / (cells.length - 1);
  return [
    for (var i = 0; i < cells.length; i++)
      FingerKey(from + step * i, b.center(cells[i])),
  ];
}

/// How much of [cells] a drag running from [from] to [to] has covered.
int _dragCount(DemoFrame f, int length, double from, double to) {
  if (f.t < from) return 0;
  if (f.t >= to) return length;
  final step = (to - from) / math.max(1, length - 1);
  return 1 + ((f.t - from) / step).floor();
}

/// The most recent of [times] the loop has passed, or null.
int? _lastIndex(DemoFrame f, List<double> times) {
  int? last;
  for (var i = 0; i < times.length; i++) {
    if (f.t >= times[i]) last = i;
  }
  return last;
}

// ── Queens ──────────────────────────────────────────────────────────────────

const _queens = QueensBoard(
  size: 4,
  regions: [0, 0, 1, 1, 0, 2, 2, 1, 3, 3, 2, 1, 3, 3, 2, 2],
);
const _queensSolution = [1, 7, 8, 14];

List<QueensMark> _crowns(Iterable<int> at) => [
  for (var i = 0; i < 16; i++)
    at.contains(i) ? QueensMark.crown : QueensMark.none,
];

/// Crowns land one by one, one per row, column and colour; the board lights.
class QueensRulesDemo extends HowToDemo {
  const QueensRulesDemo();

  static const _at = [0.14, 0.28, 0.42, 0.56];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final placed = f.count(_at);
    final last = _lastIndex(f, _at);
    b.draw(
      canvas,
      QueensBoardPainter(
        board: _queens,
        theme: f.theme,
        palette: f.palette,
        marks: _crowns(_queensSolution.take(placed)),
        popCell: last == null ? null : _queensSolution[last],
        pop: last == null ? 1 : f.pop(_at[last]),
        win: f.seg(0.64, 0.86, Curves.linear),
      ),
    );
    paintFinger(canvas, f, _taps(b, [
      for (var i = 0; i < 4; i++) (_at[i], _queensSolution[i]),
    ]));
    paintSparkles(
      canvas,
      b.origin + Offset(b.side / 2, b.side / 2),
      b.side * 0.42,
      f.seg(0.64, 0.9, Curves.linear),
      f.theme.accent,
    );
  }
}

/// A crown goes diagonal to another: both turn red, it's taken back, and a
/// crown goes somewhere legal instead.
class QueensTouchDemo extends HowToDemo {
  const QueensTouchDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final crowns = <int>{
      if (f.at(0.14)) 5,
      if (f.at(0.36) && !f.at(0.66)) 10,
      if (f.at(0.78)) 11,
    };
    final marks = _crowns(crowns);
    final pops = [(0.14, 5), (0.36, 10), (0.78, 11)];
    final current = pops.lastWhere((p) => f.at(p.$1), orElse: () => pops[0]);
    b.draw(
      canvas,
      QueensBoardPainter(
        board: _queens,
        theme: f.theme,
        palette: f.palette,
        marks: marks,
        conflicts: queensConflicts(_queens, marks),
        popCell: f.at(current.$1) ? current.$2 : null,
        pop: f.pop(current.$1),
      ),
    );
    // A little shake on the clash, so the red reads as "no", not decoration.
    if (f.at(0.36) && !f.at(0.66)) {
      final p = f.seg(0.38, 0.52, Curves.linear);
      paintSpotlight(
        canvas,
        b.rect(5).expandToInclude(b.rect(10)).deflate(2)
            .shift(Offset(math.sin(p * math.pi * 6) * 3 * (1 - p), 0)),
        f.theme.danger,
        1 - f.seg(0.56, 0.66),
      );
    }
    paintFinger(canvas, f, [
      FingerKey(0.14, b.center(5), tap: true),
      // A crown takes two taps: × first, then the crown.
      FingerKey(0.3, b.center(10), tap: true),
      FingerKey(0.36, b.center(10), tap: true),
      FingerKey(0.66, b.center(10), tap: true),
      FingerKey(0.78, b.center(11), tap: true),
    ]);
    paintSparkles(canvas, b.center(11), b.side * 0.22, f.seg(0.8, 0.95), f.theme.accent);
  }
}

/// One square, three taps: ×, crown, clear.
class QueensControlsDemo extends HowToDemo {
  const QueensControlsDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    const taps = [0.18, 0.42, 0.66];
    final n = f.count(taps);
    final marks = [
      for (var i = 0; i < 16; i++)
        i != 6
            ? QueensMark.none
            : switch (n) {
                1 => QueensMark.blocked,
                2 => QueensMark.crown,
                _ => QueensMark.none,
              },
    ];
    b.draw(
      canvas,
      QueensBoardPainter(
        board: _queens,
        theme: f.theme,
        palette: f.palette,
        marks: marks,
        popCell: 6,
        pop: n == 0 ? 1 : f.pop(taps[n - 1]),
      ),
    );
    paintFinger(canvas, f, _taps(b, [for (final t in taps) (t, 6)]));
  }

  @override
  double get still => 0.5;
}

/// Tip: a crown, then the squares it rules out fill with faint ×s.
class QueensTipDemo extends HowToDemo {
  const QueensTipDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final marks = _crowns([if (f.at(0.14)) 5]);
    final blocked = f.at(0.14) ? queensBlocked(_queens, marks).toList() : <int>[];
    // Sweep outward from the crown, so it reads as the crown "claiming" them.
    blocked.sort((a, c) => _dist(a, 5, 4).compareTo(_dist(c, 5, 4)));
    final shown = (blocked.length * f.seg(0.3, 0.7, Curves.linear)).round();
    b.draw(
      canvas,
      QueensBoardPainter(
        board: _queens,
        theme: f.theme,
        palette: f.palette,
        marks: marks,
        autoBlocked: blocked.take(shown).toSet(),
        popCell: 5,
        pop: f.pop(0.14),
      ),
    );
    paintFinger(canvas, f, _taps(b, [(0.14, 5)]));
    final pulse = f.seg(0.3, 0.5) * (1 - f.seg(0.75, 0.9));
    paintSpotlight(canvas, b.rect(5).deflate(2), f.theme.accent, pulse);
  }
}

double _dist(int a, int b, int n) =>
    math.sqrt(math.pow(a ~/ n - b ~/ n, 2) + math.pow(a % n - b % n, 2));

// ── Tango ───────────────────────────────────────────────────────────────────

const _sun = tangoSun;
const _moon = tangoMoon;
const _empty = tangoEmpty;
const _tangoSolution = [_sun, _sun, _moon, _moon, _moon, _moon, _sun, _sun, _sun, _moon, _moon, _sun, _moon, _sun, _sun, _moon];

/// The value a Tango cell has after [taps] taps: empty → sun → moon → empty.
int _tangoCycle(int taps) => switch (taps % 3) {
  1 => _sun,
  2 => _moon,
  _ => _empty,
};

/// Plays Tango [taps] on top of [givens] and paints the result.
void _tango(
  Canvas canvas,
  DemoFrame f,
  DemoBoard b,
  TangoBoard board,
  List<(double, int)> taps, {
  List<int>? start,
  Set<int>? only,
}) {
  final cells = [...(start ?? board.givens)];
  final counts = <int, int>{};
  int? popCell;
  double pop = 1;
  // Like the real board, a mistake only shows once the player has settled on
  // it: the sun a moon passes through on its way is not an error.
  var settled = true;
  for (final (t, cell) in taps) {
    if (!f.at(t)) continue;
    settled = f.t - t > 0.1;
    counts[cell] = (counts[cell] ?? 0) + 1;
    cells[cell] = _tangoCycle(counts[cell]!);
    popCell = cell;
    pop = f.pop(t);
  }
  b.draw(
    canvas,
    TangoBoardPainter(
      board: board,
      theme: f.theme,
      cells: cells,
      trouble: !settled
          ? const TangoTrouble(cells: {}, signs: {})
          : only == null
          ? tangoTrouble(board, cells)
          : TangoTrouble(
              cells: tangoTrouble(board, cells).cells.intersection(only),
              signs: const {},
            ),
      popCell: popCell,
      pop: pop,
      win: tangoSolved(board, cells) ? f.seg(0.7, 0.9, Curves.linear) : 0,
    ),
  );
  paintFinger(canvas, f, _taps(b, taps));
}

/// Tap once for a sun, twice for a moon: the last row gets filled.
class TangoFillDemo extends HowToDemo {
  const TangoFillDemo();

  static final _board = TangoBoard(
    size: 4,
    givens: [
      for (var i = 0; i < 16; i++) i >= 12 ? _empty : _tangoSolution[i],
    ],
    signs: const [],
  );

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    // The moons first (each passes through a sun), then the suns, so no
    // in-between state ever breaks a rule.
    _tango(canvas, f, b, _board, const [
      (0.12, 12),
      (0.2, 12),
      (0.32, 15),
      (0.4, 15),
      (0.52, 13),
      (0.62, 14),
    ]);
    paintSparkles(
      canvas,
      b.origin + Offset(b.side / 2, b.side / 2),
      b.side * 0.42,
      f.seg(0.7, 0.92, Curves.linear),
      f.theme.accent,
    );
  }
}

/// Spotlight a row, then a column: two of each, every time.
class TangoBalanceDemo extends HowToDemo {
  const TangoBalanceDemo();

  static const _board = TangoBoard(size: 4, givens: _tangoSolution, signs: []);

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    b.draw(
      canvas,
      TangoBoardPainter(board: _board, theme: f.theme, cells: _tangoSolution),
    );
    final row = f.seg(0.08, 0.18) * (1 - f.seg(0.4, 0.48));
    paintSpotlight(canvas, b.rect(4).expandToInclude(b.rect(7)).deflate(1), f.theme.accent, row);
    final col = f.seg(0.48, 0.58) * (1 - f.seg(0.82, 0.9));
    paintSpotlight(canvas, b.rect(2).expandToInclude(b.rect(14)).deflate(1), f.theme.accent, col);
    for (final (i, at) in [(4, 0.2), (5, 0.24), (6, 0.28), (7, 0.32)]) {
      paintSparkles(canvas, b.center(i), b.grid.cell * 0.5, f.seg(at, at + 0.14), f.theme.accent, count: 5);
    }
    for (final (i, at) in [(2, 0.6), (6, 0.64), (10, 0.68), (14, 0.72)]) {
      paintSparkles(canvas, b.center(i), b.grid.cell * 0.5, f.seg(at, at + 0.14), f.theme.accent, count: 5);
    }
  }

  @override
  double get still => 0.3;
}

/// Three moons in a row light up red; the third is cycled round to a sun.
class TangoThreeDemo extends HowToDemo {
  const TangoThreeDemo();

  static final _board = TangoBoard(
    size: 4,
    givens: [
      for (var i = 0; i < 16; i++) i == 11 ? _empty : _tangoSolution[i],
    ],
    signs: const [],
  );

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    // Sun, moon (three moons: red), back to empty, sun.
    // Only the three in a row light up: the column breaking the balance
    // rule too is another step's lesson.
    _tango(canvas, f, b, _board, const [
      (0.16, 11),
      (0.26, 11),
      (0.6, 11),
      (0.7, 11),
    ], only: const {9, 10, 11});
    paintSparkles(canvas, b.center(11), b.side * 0.22, f.seg(0.72, 0.9), f.theme.accent);
  }

  @override
  double get still => 0.45;
}

/// = and × between squares: fill the partner to match, then to differ.
class TangoSignsDemo extends HowToDemo {
  const TangoSignsDemo();

  static const _board = TangoBoard(
    size: 4,
    givens: [_empty, _sun, _empty, _empty, _moon, _empty, _empty, _empty, _empty, _empty, _empty, _empty, _empty, _empty, _empty, _empty],
    signs: [TangoSign(a: 4, b: 5, eq: true), TangoSign(a: 1, b: 2, eq: false)],
  );

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    _tango(canvas, f, b, _board, const [
      (0.16, 5),
      (0.24, 5),
      (0.56, 2),
      (0.64, 2),
    ]);
    paintSpotlight(
      canvas,
      b.rect(4).expandToInclude(b.rect(5)).deflate(1),
      f.theme.accent,
      f.seg(0.04, 0.12) * (1 - f.seg(0.38, 0.44)),
    );
    paintSpotlight(
      canvas,
      b.rect(1).expandToInclude(b.rect(2)).deflate(1),
      f.theme.accent,
      f.seg(0.44, 0.52) * (1 - f.seg(0.82, 0.9)),
    );
    paintSparkles(canvas, b.center(5), b.side * 0.2, f.seg(0.26, 0.42), f.theme.accent);
    paintSparkles(canvas, b.center(2), b.side * 0.2, f.seg(0.66, 0.82), f.theme.accent);
  }

  @override
  double get still => 0.7;
}

/// Tip: two suns side by side. A third would make three in a row, so both
/// ends are moons.
class TangoTipDemo extends HowToDemo {
  const TangoTipDemo();

  static const _board = TangoBoard(
    size: 4,
    givens: [_empty, _empty, _empty, _empty, _empty, _sun, _sun, _empty, _empty, _empty, _empty, _empty, _empty, _empty, _empty, _empty],
    signs: [],
  );

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    // Each end is cycled sun → moon in one quick double tap; the sun it
    // passes through never settles, so it never reads as a mistake.
    _tango(canvas, f, b, _board, const [
      (0.4, 4),
      (0.46, 4),
      (0.62, 7),
      (0.68, 7),
    ]);
    paintSpotlight(
      canvas,
      b.rect(5).expandToInclude(b.rect(6)).deflate(1),
      f.theme.accent,
      f.seg(0.06, 0.14) * (1 - f.seg(0.84, 0.9)),
    );
    // Then the two squares the pair decides.
    final ends = f.seg(0.2, 0.28) * (1 - f.seg(0.36, 0.4));
    paintSpotlight(canvas, b.rect(4).deflate(3), f.theme.accent, ends);
    paintSpotlight(canvas, b.rect(7).deflate(3), f.theme.accent, ends);
    paintSparkles(canvas, b.center(4), b.side * 0.18, f.seg(0.48, 0.64), f.theme.accent, count: 6);
    paintSparkles(canvas, b.center(7), b.side * 0.18, f.seg(0.7, 0.86), f.theme.accent, count: 6, seed: 0.4);
  }

  @override
  double get still => 0.8;
}

// ── Zip ─────────────────────────────────────────────────────────────────────

const _zip = ZipBoard(size: 4, checkpoints: [0, 6, 9, 12]);
const _zipPath = [0, 1, 2, 3, 7, 6, 5, 4, 8, 9, 10, 11, 15, 14, 13, 12];

/// From 1, through 2, to 3, in order.
class ZipOrderDemo extends HowToDemo {
  const ZipOrderDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final cells = _zipPath.sublist(0, 10);
    final n = _dragCount(f, cells.length, 0.12, 0.72);
    b.draw(canvas, ZipBoardPainter(board: _zip, theme: f.theme, path: cells.sublist(0, n)));
    paintFinger(canvas, f, _drag(b, cells, 0.12, 0.72));
    // A little burst each time a number is reached.
    paintSparkles(canvas, b.center(6), b.side * 0.2, f.seg(0.12 + 5 * 0.0667, 0.5), f.theme.accent, count: 6);
    paintSparkles(canvas, b.center(9), b.side * 0.2, f.seg(0.72, 0.88), f.theme.accent, count: 6);
  }
}

/// The rest of the board, ending on the last number. Lights up.
class ZipFillDemo extends HowToDemo {
  const ZipFillDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final rest = _zipPath.sublist(9);
    final n = _dragCount(f, rest.length, 0.14, 0.56);
    b.draw(
      canvas,
      ZipBoardPainter(
        board: _zip,
        theme: f.theme,
        path: [..._zipPath.sublist(0, 9), ...rest.take(math.max(1, n))],
        win: f.seg(0.6, 0.86, Curves.linear),
      ),
    );
    paintFinger(canvas, f, _drag(b, rest, 0.14, 0.56));
    paintSparkles(
      canvas,
      b.origin + Offset(b.side / 2, b.side / 2),
      b.side * 0.42,
      f.seg(0.6, 0.88, Curves.linear),
      f.theme.accent,
    );
  }
}

/// Into a dead end, back out, and on the right way.
class ZipUndoDemo extends HowToDemo {
  const ZipUndoDemo();

  static const _wrong = [0, 1, 2, 3, 7, 11, 10];
  static const _keys = <(double, int)>[
    (0.06, 5), // 0..7 drawn
    (0.16, 6), // → 11
    (0.24, 7), // → 10 (wrong: 6 is still waiting)
    (0.42, 6), // back to 11
    (0.5, 5), // back to 7
    (0.62, -6), // on to 6, the right way
    (0.7, -7),
    (0.78, -8),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    var path = _wrong.sublist(0, 5);
    for (final (t, len) in _keys) {
      if (!f.at(t)) break;
      path = len > 0 ? _wrong.sublist(0, len) : _zipPath.sublist(0, -len);
    }
    b.draw(canvas, ZipBoardPainter(board: _zip, theme: f.theme, path: path));
    paintFinger(canvas, f, [
      FingerKey(0.08, b.center(7)),
      FingerKey(0.16, b.center(11)),
      FingerKey(0.24, b.center(10)),
      FingerKey(0.34, b.center(10)),
      FingerKey(0.42, b.center(11)),
      FingerKey(0.5, b.center(7)),
      FingerKey(0.62, b.center(6)),
      FingerKey(0.7, b.center(5)),
      FingerKey(0.78, b.center(4)),
    ]);
    // The dead end flashes before it's undone.
    paintSpotlight(
      canvas,
      b.rect(10).expandToInclude(b.rect(11)).deflate(2),
      f.theme.danger,
      f.seg(0.26, 0.3) * (1 - f.seg(0.38, 0.44)),
    );
    paintSparkles(canvas, b.center(6), b.side * 0.2, f.seg(0.62, 0.78), f.theme.accent, count: 6);
  }

  @override
  double get still => 0.3;
}

/// Tip: cutting from 3 down to 2 leaves the corner with one way in, so it can
/// never be reached. Back off, sweep the corner, then go on to 2.
class ZipTipDemo extends HowToDemo {
  const ZipTipDemo();

  static const _short = [0, 1, 2, 6];
  static const _sweep = [2, 3, 7, 6];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final List<int> path;
    if (!f.at(0.46)) {
      path = _short.sublist(0, math.max(1, _dragCount(f, 4, 0.08, 0.3)));
    } else if (!f.at(0.54)) {
      path = _short.sublist(0, 3);
    } else {
      path = [0, 1, ..._sweep.take(math.max(1, _dragCount(f, 4, 0.54, 0.76)))];
    }
    b.draw(canvas, ZipBoardPainter(board: _zip, theme: f.theme, path: path));
    paintFinger(canvas, f, [
      ..._drag(b, _short, 0.08, 0.3),
      FingerKey(0.46, b.center(6)),
      FingerKey(0.54, b.center(2)),
      ..._drag(b, _sweep, 0.54, 0.76),
    ]);
    // The stranded corner pulses red until the line comes back for it.
    final pulse = 0.8 + 0.2 * math.sin(f.t * math.pi * 12);
    paintSpotlight(
      canvas,
      b.rect(3).deflate(3),
      f.theme.danger,
      pulse * f.seg(0.3, 0.34) * (1 - f.seg(0.5, 0.56)),
    );
    paintSparkles(canvas, b.center(3), b.side * 0.18, f.seg(0.62, 0.78), f.theme.accent, count: 6);
    paintSparkles(canvas, b.center(6), b.side * 0.2, f.seg(0.76, 0.92), f.theme.accent, count: 6, seed: 0.4);
  }

  @override
  double get still => 0.4;
}

// ── Mini Sudoku ─────────────────────────────────────────────────────────────

const _sudokuSolution = [
  1, 2, 3, 4, 5, 6, //
  4, 5, 6, 1, 2, 3, //
  2, 3, 1, 5, 6, 4, //
  5, 6, 4, 2, 3, 1, //
  3, 1, 2, 6, 4, 5, //
  6, 4, 5, 3, 1, 2, //
];
const _sudokuBlanks = {2, 7, 9, 14, 16, 19, 23, 26, 28, 31, 33, 35};

final _sudoku = SudokuBoard(
  size: 6,
  givens: [
    for (var i = 0; i < 36; i++)
      _sudokuBlanks.contains(i) ? sudokuEmpty : _sudokuSolution[i],
  ],
);

/// Row, column, box: each lights up holding 1 to 6.
class SudokuRulesDemo extends HowToDemo {
  const SudokuRulesDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 6);
    b.draw(
      canvas,
      SudokuBoardPainter(board: _sudoku, theme: f.theme, cells: _sudokuSolution),
    );
    final a = f.theme.accent;
    paintSpotlight(canvas, b.rect(0).expandToInclude(b.rect(5)).deflate(1), a,
        f.seg(0.06, 0.14) * (1 - f.seg(0.3, 0.36)));
    paintSpotlight(canvas, b.rect(2).expandToInclude(b.rect(32)).deflate(1), a,
        f.seg(0.36, 0.44) * (1 - f.seg(0.6, 0.66)));
    paintSpotlight(canvas, b.rect(15).expandToInclude(b.rect(23)).deflate(1), a,
        f.seg(0.66, 0.74) * (1 - f.seg(0.88, 0.93)));
  }

  @override
  double get still => 0.5;
}

/// The board, a little keypad under it, and the finger moving between them.
void _sudokuWithPad(
  Canvas canvas,
  DemoFrame f, {
  required List<(double, int, int)> moves, // (time, cell, digit)
  required List<double> selects, // when each move's cell is selected
}) {
  final b = DemoBoard(f, n: 6, fraction: 0.66, dy: -0.11);
  final cells = [..._sudoku.givens];
  int? selected;
  int? popCell;
  double pop = 1;
  for (var i = 0; i < moves.length; i++) {
    if (f.at(selects[i])) selected = moves[i].$2;
    final (t, cell, digit) = moves[i];
    if (!f.at(t)) continue;
    cells[cell] = digit;
    popCell = cell;
    pop = f.pop(t);
  }
  b.draw(
    canvas,
    SudokuBoardPainter(
      board: _sudoku,
      theme: f.theme,
      cells: cells,
      conflicts: sudokuConflicts(_sudoku, cells),
      selected: selected,
      popCell: popCell,
      pop: pop,
    ),
  );

  // The keypad: six capsules under the board.
  final padTop = b.origin.dy + b.side + f.side * 0.05;
  final gap = f.side * 0.018;
  final w = (b.side - gap * 5) / 6;
  final h = f.side * 0.1;
  Offset key(int digit) =>
      Offset(b.origin.dx + (digit - 1) * (w + gap) + w / 2, padTop + h / 2);
  final down = <int>{
    for (final (t, _, d) in moves)
      if ((f.t - t).abs() < 0.04) d,
  };
  for (var d = 1; d <= 6; d++) {
    final c = key(d);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h),
      Radius.circular(h * 0.3),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = down.contains(d)
            ? f.theme.accent.withValues(alpha: 0.3)
            : f.theme.ink.withValues(alpha: 0.07),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$d',
        style: f.theme.body.copyWith(
          fontSize: h * 0.5,
          fontWeight: FontWeight.w600,
          color: f.theme.ink,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  paintFinger(canvas, f, [
    for (var i = 0; i < moves.length; i++) ...[
      FingerKey(selects[i], b.center(moves[i].$2), tap: true),
      FingerKey(moves[i].$1, key(moves[i].$3), tap: true),
    ],
  ]);
}

/// Tap a square, then a number.
class SudokuTapDemo extends HowToDemo {
  const SudokuTapDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) => _sudokuWithPad(
    canvas,
    f,
    selects: const [0.12, 0.5],
    moves: const [(0.3, 2, 3), (0.68, 7, 5)],
  );
}

/// A 5 where a 5 already is: red. Swap it for the 3.
class SudokuClashDemo extends HowToDemo {
  const SudokuClashDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) => _sudokuWithPad(
    canvas,
    f,
    selects: const [0.12, 0.56],
    moves: const [(0.28, 2, 5), (0.66, 2, 3)],
  );

  @override
  double get still => 0.45;
}

/// Tip: the top row is only missing one number. Spot it, fill it.
class SudokuTipDemo extends HowToDemo {
  const SudokuTipDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 6);
    final cells = [..._sudoku.givens];
    if (f.at(0.52)) cells[2] = 3;
    b.draw(
      canvas,
      SudokuBoardPainter(
        board: _sudoku,
        theme: f.theme,
        cells: cells,
        popCell: 2,
        pop: f.pop(0.52),
      ),
    );
    paintSpotlight(
      canvas,
      b.rect(0).expandToInclude(b.rect(5)).deflate(1),
      f.theme.accent,
      f.seg(0.08, 0.18) * (1 - f.seg(0.8, 0.88)),
    );
    // The gap pulses until it's filled.
    final pulse = f.at(0.52) ? 0.0 : 0.5 + 0.5 * math.sin(f.t * math.pi * 10);
    paintSpotlight(canvas, b.rect(2).deflate(3), const Color(0xFFFFC53D), pulse * f.seg(0.18, 0.26));
    paintSparkles(canvas, b.center(2), b.side * 0.2, f.seg(0.54, 0.74), f.theme.accent);
  }
}

// ── Flow ────────────────────────────────────────────────────────────────────

const _flow = FlowBoard(size: 4, endpoints: [(0, 3), (4, 15), (5, 9)]);
const _flowPipes = [
  [0, 1, 2, 3],
  [4, 8, 12, 13, 14, 15],
  [5, 6, 7, 11, 10, 9],
];

/// Two pipes drawn dot to dot.
class FlowConnectDemo extends HowToDemo {
  const FlowConnectDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final a = _dragCount(f, 4, 0.1, 0.32);
    final c = _dragCount(f, 6, 0.48, 0.74);
    b.draw(
      canvas,
      FlowBoardPainter(
        board: _flow,
        theme: f.theme,
        palette: f.palette,
        pipes: [
          _flowPipes[0].sublist(0, a),
          _flowPipes[1].sublist(0, c),
          const [],
        ],
        active: f.at(0.48) && !f.at(0.74)
            ? 1
            : f.at(0.1) && !f.at(0.32)
            ? 0
            : null,
      ),
    );
    paintFinger(canvas, f, [
      ..._drag(b, _flowPipes[0], 0.1, 0.32),
      ..._drag(b, _flowPipes[1], 0.48, 0.74),
    ]);
    paintSparkles(canvas, b.center(3), b.side * 0.2, f.seg(0.32, 0.48), f.palette.regionInk(0), count: 6);
    paintSparkles(canvas, b.center(15), b.side * 0.2, f.seg(0.74, 0.9), f.palette.regionInk(1), count: 6);
  }
}

/// The short way leaves holes. Undo, take the long way, board lights up.
class FlowLongWayDemo extends HowToDemo {
  const FlowLongWayDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final List<int> third;
    if (!f.at(0.1)) {
      third = const [];
    } else if (!f.at(0.42)) {
      third = const [5, 9];
    } else {
      third = _flowPipes[2].sublist(0, _dragCount(f, 6, 0.48, 0.74));
    }
    b.draw(
      canvas,
      FlowBoardPainter(
        board: _flow,
        theme: f.theme,
        palette: f.palette,
        pipes: [_flowPipes[0], _flowPipes[1], third],
        active: f.at(0.1) && !f.at(0.74) ? 2 : null,
        win: f.seg(0.76, 0.92, Curves.linear),
      ),
    );
    // The holes the short way left.
    final holes = f.seg(0.18, 0.24) * (1 - f.seg(0.36, 0.42));
    for (final i in const [6, 7, 10, 11]) {
      paintSpotlight(canvas, b.rect(i).deflate(4), f.theme.danger, holes);
    }
    paintFinger(canvas, f, [
      FingerKey(0.06, b.center(5)),
      FingerKey(0.12, b.center(9)),
      FingerKey(0.38, b.center(9)),
      FingerKey(0.46, b.center(5)),
      ..._drag(b, _flowPipes[2], 0.48, 0.74),
    ]);
    paintSparkles(
      canvas,
      b.origin + Offset(b.side / 2, b.side / 2),
      b.side * 0.42,
      f.seg(0.76, 0.94, Curves.linear),
      f.theme.accent,
    );
  }

  @override
  double get still => 0.3;
}

/// Tip: the pipes that hug the edge go first. The one left over has exactly
/// the middle to fill.
class FlowTipDemo extends HowToDemo {
  const FlowTipDemo();

  static const _strokes = [
    (1, 0.08, 0.3),
    (0, 0.36, 0.5),
    (2, 0.58, 0.8),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final pipes = <List<int>>[const [], const [], const []];
    int? active;
    for (final (k, from, to) in _strokes) {
      pipes[k] = _flowPipes[k].sublist(0, _dragCount(f, _flowPipes[k].length, from, to));
      if (f.at(from) && !f.at(to)) active = k;
    }
    b.draw(
      canvas,
      FlowBoardPainter(
        board: _flow,
        theme: f.theme,
        palette: f.palette,
        pipes: pipes,
        active: active,
        win: f.seg(0.82, 0.96, Curves.linear),
      ),
    );
    // The edges glow while the edge pipes go in; then the middle that is left.
    final edge = f.seg(0.02, 0.08) * (1 - f.seg(0.5, 0.56));
    paintSpotlight(canvas, b.rect(4).expandToInclude(b.rect(12)).deflate(1), f.theme.accent, edge);
    paintSpotlight(canvas, b.rect(13).expandToInclude(b.rect(15)).deflate(1), f.theme.accent, edge);
    paintSpotlight(canvas, b.rect(0).expandToInclude(b.rect(3)).deflate(1), f.theme.accent, edge);
    paintSpotlight(
      canvas,
      b.rect(5).expandToInclude(b.rect(11)).deflate(1),
      f.theme.accent,
      f.seg(0.52, 0.58) * (1 - f.seg(0.78, 0.84)),
    );
    paintFinger(canvas, f, [
      for (final (k, from, to) in _strokes) ..._drag(b, _flowPipes[k], from, to),
    ]);
    paintSparkles(
      canvas,
      b.origin + Offset(b.side / 2, b.side / 2),
      b.side * 0.42,
      f.seg(0.82, 0.98, Curves.linear),
      f.theme.accent,
    );
  }

  @override
  double get still => 0.5;
}

// ── Futoshiki ───────────────────────────────────────────────────────────────

const _futoSolution = [1, 2, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1];
const _futo = FutoshikiBoard(
  size: 4,
  givens: [0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 4, 0, 4, 0, 0, 0],
  signs: [
    FutoshikiSign(a: 0, b: 1, lt: true),
    FutoshikiSign(a: 6, b: 7, lt: true),
    FutoshikiSign(a: 4, b: 8, lt: false),
    FutoshikiSign(a: 10, b: 11, lt: false),
    FutoshikiSign(a: 13, b: 14, lt: false),
  ],
);

/// The grid fills square by square; it lights up when it's all true.
class FutoshikiRulesDemo extends HowToDemo {
  const FutoshikiRulesDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final open = [
      for (var i = 0; i < 16; i++)
        if (_futo.givens[i] == futoshikiEmpty) i,
    ];
    final times = [for (var k = 0; k < open.length; k++) 0.08 + k * 0.045];
    final cells = [..._futo.givens];
    int? popCell;
    var pop = 1.0;
    for (var k = 0; k < open.length; k++) {
      if (!f.at(times[k])) break;
      cells[open[k]] = _futoSolution[open[k]];
      popCell = open[k];
      pop = f.pop(times[k]);
    }
    b.draw(
      canvas,
      FutoshikiBoardPainter(
        board: _futo,
        theme: f.theme,
        cells: cells,
        popCell: popCell,
        pop: pop,
        win: f.seg(0.7, 0.9, Curves.linear),
      ),
    );
    paintSparkles(
      canvas,
      b.origin + Offset(b.side / 2, b.side / 2),
      b.side * 0.42,
      f.seg(0.7, 0.92, Curves.linear),
      f.theme.accent,
    );
  }
}

/// A sign lights up; the small number goes where it points.
class FutoshikiSignDemo extends HowToDemo {
  const FutoshikiSignDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final cells = [..._futo.givens];
    if (f.at(0.34)) cells[0] = 1;
    if (f.at(0.54)) cells[1] = 2;
    b.draw(
      canvas,
      FutoshikiBoardPainter(
        board: _futo,
        theme: f.theme,
        cells: cells,
        popCell: f.at(0.54) ? 1 : 0,
        pop: f.at(0.54) ? f.pop(0.54) : f.pop(0.34),
      ),
    );
    final pulse = f.seg(0.06, 0.14) * (1 - f.seg(0.82, 0.9));
    paintSpotlight(canvas, b.rect(0).expandToInclude(b.rect(1)).deflate(1), f.theme.accent, pulse);
    paintFinger(canvas, f, _taps(b, [(0.34, 0), (0.54, 1)]));
    paintSparkles(canvas, b.center(0), b.side * 0.2, f.seg(0.56, 0.76), f.theme.accent);
  }
}

/// 2 < 1 is a lie: the sign goes red. Swap them and it's happy.
class FutoshikiWrongDemo extends HowToDemo {
  const FutoshikiWrongDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final cells = [..._futo.givens];
    if (f.at(0.16)) cells[6] = 2;
    if (f.at(0.3)) cells[7] = 1;
    if (f.at(0.62)) cells[6] = 1;
    if (f.at(0.72)) cells[7] = 2;
    final last = _lastIndex(f, const [0.16, 0.3, 0.62, 0.72]);
    b.draw(
      canvas,
      FutoshikiBoardPainter(
        board: _futo,
        theme: f.theme,
        cells: cells,
        trouble: futoshikiTrouble(_futo, cells),
        popCell: last == null ? null : (last.isEven ? 6 : 7),
        pop: last == null ? 1 : f.pop(const [0.16, 0.3, 0.62, 0.72][last]),
      ),
    );
    paintFinger(canvas, f, _taps(b, [(0.16, 6), (0.3, 7), (0.62, 6), (0.72, 7)]));
    paintSparkles(canvas, b.rect(6).center + Offset(b.grid.cell / 2, 0), b.side * 0.22, f.seg(0.74, 0.92), f.theme.accent);
  }

  @override
  double get still => 0.45;
}

// Its own board: the second row holds a chain 1 < 2 < 3 and a printed 4.
const _futoChainSolution = [2, 3, 4, 1, 1, 2, 3, 4, 4, 1, 2, 3, 3, 4, 1, 2];
const _futoChain = FutoshikiBoard(
  size: 4,
  givens: [0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0],
  signs: [
    FutoshikiSign(a: 4, b: 5, lt: true),
    FutoshikiSign(a: 5, b: 6, lt: true),
  ],
);

/// Tip: a < b < c leaves c at least 3. With the 4 taken, c is the 3, and the
/// 1 and 2 fall in behind it.
class FutoshikiTipDemo extends HowToDemo {
  const FutoshikiTipDemo();

  static const _fills = [(0.5, 6), (0.62, 4), (0.7, 5)];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final cells = [..._futoChain.givens];
    int? popCell;
    var pop = 1.0;
    for (final (t, i) in _fills) {
      if (!f.at(t)) continue;
      cells[i] = _futoChainSolution[i];
      popCell = i;
      pop = f.pop(t);
    }
    b.draw(
      canvas,
      FutoshikiBoardPainter(
        board: _futoChain,
        theme: f.theme,
        cells: cells,
        popCell: popCell,
        pop: pop,
      ),
    );
    final fade = 1 - f.seg(0.84, 0.9);
    paintSpotlight(
      canvas,
      b.rect(4).expandToInclude(b.rect(6)).deflate(1),
      f.theme.accent,
      f.seg(0.06, 0.14) * fade,
    );
    // The printed 4 that leaves c exactly one choice.
    paintSpotlight(
      canvas,
      b.rect(7).deflate(3),
      f.theme.accent,
      f.seg(0.34, 0.4) * (1 - f.seg(0.5, 0.56)),
    );
    _paintBadge(canvas, f, b.rect(6).topCenter, '≥ 3', f.seg(0.2, 0.28) * (1 - f.seg(0.46, 0.5)));
    paintFinger(canvas, f, _taps(b, _fills));
    paintSparkles(canvas, b.center(6), b.side * 0.2, f.seg(0.52, 0.68), f.theme.accent);
  }

  @override
  double get still => 0.32;
}

/// A small accent pill reading [text], centred on [at]: a deduction written
/// onto the board, the way a player would pencil it in.
void _paintBadge(Canvas canvas, DemoFrame f, Offset at, String text, double strength) {
  if (strength <= 0) return;
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: f.theme.body.copyWith(
        fontSize: f.side * 0.06,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 0,
        color: f.theme.accentInk.withValues(alpha: strength),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final pill = Rect.fromCenter(
    center: at,
    width: tp.width + f.side * 0.05,
    height: tp.height + f.side * 0.03,
  );
  final rise = (1 - Curves.easeOutCubic.transform(strength.clamp(0.0, 1.0))) * f.side * 0.02;
  final shifted = pill.shift(Offset(0, rise));
  canvas.drawRRect(
    RRect.fromRectAndRadius(shifted, Radius.circular(shifted.height / 2)),
    Paint()..color = f.theme.accent.withValues(alpha: strength),
  );
  tp.paint(canvas, shifted.center - Offset(tp.width / 2, tp.height / 2));
}

// ── Nonogram ────────────────────────────────────────────────────────────────

const _nonogram = NonogramBoard(
  size: 5,
  rows: [
    [1, 1],
    [5],
    [5],
    [3],
    [1],
  ],
  cols: [
    [2],
    [4],
    [4],
    [4],
    [2],
  ],
);
const _heart = [
  0, 1, 0, 1, 0, //
  1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, //
  0, 1, 1, 1, 0, //
  0, 0, 1, 0, 0, //
];

DemoBoard _nonoBoard(DemoFrame f, [NonogramBoard board = _nonogram]) =>
    DemoBoard(f, n: 5, fraction: 0.9, lead: nonogramLeadFraction(board));

void _nonoPaint(Canvas canvas, DemoFrame f, DemoBoard b, List<int> cells,
    {int? popCell, double pop = 1, double win = 0, int? focus, NonogramBoard board = _nonogram}) {
  final rows = <int>{};
  final cols = <int>{};
  final n = board.size;
  for (var k = 0; k < n; k++) {
    final row = [for (var c = 0; c < n; c++) cells[k * n + c] == nonogramFilled ? 1 : 0];
    final col = [for (var r = 0; r < n; r++) cells[r * n + k] == nonogramFilled ? 1 : 0];
    if (_same(nonogramRuns(row), board.rows[k])) rows.add(k);
    if (_same(nonogramRuns(col), board.cols[k])) cols.add(k);
  }
  b.draw(
    canvas,
    NonogramBoardPainter(
      board: board,
      theme: f.theme,
      cells: cells,
      trouble: nonogramTrouble(board, cells),
      satisfiedRows: rows,
      satisfiedCols: cols,
      focus: focus,
      popCell: popCell,
      pop: pop,
      win: win,
    ),
  );
}

bool _same(List<int> a, List<int> b) {
  final aa = a.isEmpty ? const [0] : a;
  final bb = b.isEmpty ? const [0] : b;
  if (aa.length != bb.length) return false;
  for (var i = 0; i < aa.length; i++) {
    if (aa[i] != bb[i]) return false;
  }
  return true;
}

/// "5": drag across the whole row; its clue ticks off.
class NonogramClueDemo extends HowToDemo {
  const NonogramClueDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _nonoBoard(f);
    final cells = List<int>.filled(25, nonogramUnknown);
    const row = [5, 6, 7, 8, 9];
    final n = _dragCount(f, 5, 0.3, 0.56);
    for (final i in row.take(n)) {
      cells[i] = nonogramFilled;
    }
    _nonoPaint(canvas, f, b, cells, popCell: n > 0 ? row[n - 1] : null, pop: 1, focus: f.at(0.1) && !f.at(0.86) ? 7 : null);
    final clue = Rect.fromLTRB(
      b.origin.dx,
      b.rect(5).top,
      b.rect(9).right,
      b.rect(5).bottom,
    ).deflate(1);
    paintSpotlight(canvas, clue, f.theme.accent, f.seg(0.08, 0.18) * (1 - f.seg(0.84, 0.9)));
    paintFinger(canvas, f, _drag(b, row, 0.3, 0.56));
    paintSparkles(canvas, b.center(9), b.side * 0.2, f.seg(0.58, 0.78), f.theme.accent, count: 6);
  }
}

/// "1 1": two singles with a gap; the rest of the row is crossed off.
class NonogramGapDemo extends HowToDemo {
  const NonogramGapDemo();

  static const _plan = <(double, int, int)>[
    (0.16, 1, nonogramFilled),
    (0.3, 3, nonogramFilled),
    (0.5, 0, nonogramCrossed),
    (0.58, 2, nonogramCrossed),
    (0.66, 4, nonogramCrossed),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _nonoBoard(f);
    final cells = List<int>.filled(25, nonogramUnknown);
    int? pop;
    var p = 1.0;
    for (final (t, i, v) in _plan) {
      if (!f.at(t)) continue;
      cells[i] = v;
      pop = i;
      p = f.pop(t);
    }
    _nonoPaint(canvas, f, b, cells, popCell: pop, pop: p);
    final clue = Rect.fromLTRB(b.origin.dx, b.rect(0).top, b.rect(4).right, b.rect(0).bottom).deflate(1);
    paintSpotlight(canvas, clue, f.theme.accent, f.seg(0.04, 0.12) * (1 - f.seg(0.84, 0.9)));
    paintFinger(canvas, f, _taps(b, [for (final (t, i, _) in _plan) (t, i)]));
  }
}

// A board whose top row reads `1 3` and whose left column reads `3 1`: the
// same two numbers, opposite orders, side by side.
const _nonogramOrder = NonogramBoard(
  size: 5,
  rows: [
    [1, 3],
    [1, 1],
    [3, 1],
    [1, 1],
    [5],
  ],
  cols: [
    [3, 1],
    [1, 1],
    [1, 3],
    [1, 1],
    [5],
  ],
);

/// Clue order: the top row's `1 3` fills left to right, then the left
/// column's `3 1` top to bottom. Each number lights up together with the run
/// it stands for, so first number ↔ first run is something you see.
class NonogramOrderDemo extends HowToDemo {
  const NonogramOrderDemo();

  @override
  Duration get period => const Duration(milliseconds: 6400);

  @override
  double get still => 0.88;

  // Each beat: the clue number lit (line, which number), the cells it owns,
  // and when it is lit. Rows are lines 0..4, columns 5..9.
  static const _beats = <(int, int, List<int>, double, double)>[
    (0, 0, [0], 0.06, 0.24),
    (0, 1, [2, 3, 4], 0.26, 0.46),
    (5, 0, [0, 5, 10], 0.52, 0.7),
    (5, 1, [20], 0.72, 0.88),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _nonoBoard(f, _nonogramOrder);
    final cells = List<int>.filled(25, nonogramUnknown);
    // (time, cell, mark): the row first, then the column.
    const plan = <(double, int, int)>[
      (0.12, 0, nonogramFilled),
      (0.2, 1, nonogramCrossed),
      (0.31, 2, nonogramFilled),
      (0.35, 3, nonogramFilled),
      (0.39, 4, nonogramFilled),
      (0.58, 5, nonogramFilled),
      (0.62, 10, nonogramFilled),
      (0.68, 15, nonogramCrossed),
      (0.78, 20, nonogramFilled),
    ];
    int? popCell;
    var p = 1.0;
    for (final (t, i, v) in plan) {
      if (!f.at(t)) continue;
      cells[i] = v;
      popCell = i;
      p = f.pop(t);
    }
    _nonoPaint(canvas, f, b, cells, popCell: popCell, pop: p, board: _nonogramOrder);

    final grid = b.grid;
    final cell = grid.cell;
    final step = cell * 0.6;
    for (final (line, k, run, on, off) in _beats) {
      final s = f.seg(on, on + 0.05) * (1 - f.seg(off, off + 0.05));
      if (s <= 0) continue;
      final column = line >= 5;
      final clue = column ? _nonogramOrder.cols[line - 5] : _nonogramOrder.rows[line];
      final back = grid.lead - cell * 0.42 - (clue.length - 1 - k) * step;
      final along = grid.lead + ((column ? line - 5 : line) + 0.5) * cell;
      final digit = b.origin + (column ? Offset(along, back) : Offset(back, along));
      paintSpotlight(
        canvas,
        Rect.fromCenter(center: digit, width: cell * 0.62, height: cell * 0.58),
        f.theme.accent,
        s,
        radius: 6,
      );
      final cover = run.map(b.rect).reduce((a, c) => a.expandToInclude(c));
      paintSpotlight(canvas, cover.deflate(1.5), f.theme.accent, s, radius: 6);
    }

    paintFinger(canvas, f, [
      ..._taps(b, [(0.12, 0), (0.2, 1)]),
      ..._drag(b, [2, 3, 4], 0.31, 0.39),
      ..._drag(b, [0, 5, 10], 0.54, 0.62),
      ..._taps(b, [(0.68, 15), (0.78, 20)]),
    ]);
    paintSparkles(canvas, b.center(4), b.side * 0.18, f.seg(0.42, 0.6), f.theme.accent, count: 6);
    paintSparkles(canvas, b.center(20), b.side * 0.18, f.seg(0.82, 0.98), f.theme.accent, count: 6, seed: 0.4);
  }
}

/// One square: shade, ×, clear. Then a drag shades a run in one go.
class NonogramControlsDemo extends HowToDemo {
  const NonogramControlsDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _nonoBoard(f);
    final cells = List<int>.filled(25, nonogramUnknown);
    const taps = [0.12, 0.28, 0.44];
    final n = f.count(taps);
    cells[0] = switch (n) {
      1 => nonogramFilled,
      2 => nonogramCrossed,
      _ => nonogramUnknown,
    };
    const run = [10, 11, 12, 13, 14];
    final d = _dragCount(f, 5, 0.58, 0.8);
    for (final i in run.take(d)) {
      cells[i] = nonogramFilled;
    }
    _nonoPaint(canvas, f, b, cells, popCell: n > 0 && d == 0 ? 0 : null, pop: n == 0 ? 1 : f.pop(taps[n - 1]));
    paintFinger(canvas, f, [
      ..._taps(b, [for (final t in taps) (t, 0)]),
      ..._drag(b, run, 0.58, 0.8),
    ]);
  }

  @override
  double get still => 0.3;
}

/// The whole heart fills in and glows.
class NonogramPictureDemo extends HowToDemo {
  const NonogramPictureDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _nonoBoard(f);
    final cells = List<int>.filled(25, nonogramUnknown);
    final p = f.seg(0.08, 0.6, Curves.linear);
    for (var i = 0; i < 25; i++) {
      if (i / 25 < p) cells[i] = _heart[i] == 1 ? nonogramFilled : nonogramCrossed;
    }
    _nonoPaint(canvas, f, b, cells, win: f.seg(0.64, 0.88, Curves.linear));
    paintSparkles(canvas, b.center(12), b.side * 0.42, f.seg(0.64, 0.9, Curves.linear), const Color(0xFFFF4D6D));
  }
}

// A full-size 10×10 for the tip, because the tip is about a row of 10: a
// sailboat, whose deck row reads 7.
const _boat = [
  0, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
  0, 0, 0, 0, 1, 1, 0, 0, 0, 0, //
  0, 0, 0, 1, 1, 1, 0, 0, 0, 0, //
  0, 0, 1, 1, 1, 1, 0, 0, 0, 0, //
  0, 1, 1, 1, 1, 1, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 0, //
  0, 1, 1, 1, 1, 1, 1, 1, 0, 0, //
  0, 0, 1, 1, 1, 1, 1, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
];
final _boatBoard = NonogramBoard(
  size: 10,
  rows: [
    for (var r = 0; r < 10; r++) nonogramRuns(_boat.sublist(r * 10, r * 10 + 10)),
  ],
  cols: [
    for (var c = 0; c < 10; c++) nonogramRuns([for (var r = 0; r < 10; r++) _boat[r * 10 + c]]),
  ],
);

/// Tip: the 7 pushed all the way left, then all the way right. The four
/// squares both cover are shaded before anything else is known.
class NonogramTipDemo extends HowToDemo {
  const NonogramTipDemo();

  static const _row = 7;
  static const _overlap = [73, 74, 75, 76];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 10, fraction: 0.92, lead: nonogramLeadFraction(_boatBoard));
    final cells = List<int>.filled(100, nonogramUnknown);
    final shaded = _dragCount(f, 4, 0.66, 0.78);
    for (final i in _overlap.take(shaded)) {
      cells[i] = nonogramFilled;
    }
    _nonoPaint(
      canvas,
      f,
      b,
      cells,
      board: _boatBoard,
      popCell: shaded > 0 ? _overlap[shaded - 1] : null,
    );
    Rect span(int from, int to) =>
        b.rect(_row * 10 + from).expandToInclude(b.rect(_row * 10 + to));
    final fade = 1 - f.seg(0.86, 0.92);
    // The clue and its row.
    paintSpotlight(
      canvas,
      Rect.fromLTRB(b.origin.dx, span(0, 9).top, span(0, 9).right, span(0, 9).bottom).deflate(1),
      f.theme.accent,
      f.seg(0.04, 0.12) * (1 - f.seg(0.2, 0.26)),
      radius: 6,
    );
    // As far left as it goes, then as far right: two placements, one row.
    final left = f.seg(0.24, 0.3) * (1 - f.seg(0.6, 0.66));
    final right = f.seg(0.4, 0.46) * (1 - f.seg(0.6, 0.66));
    paintSpotlight(canvas, span(0, 6).deflate(2), f.theme.accent, left, radius: 6);
    paintSpotlight(canvas, span(3, 9).deflate(2), const Color(0xFFFFC53D), right, radius: 6);
    // Where they agree.
    paintSpotlight(
      canvas,
      span(3, 6).deflate(1),
      f.theme.success,
      f.seg(0.54, 0.6) * fade,
      radius: 6,
    );
    paintFinger(canvas, f, _drag(b, _overlap, 0.66, 0.78));
    paintSparkles(canvas, span(3, 6).center, b.side * 0.2, f.seg(0.78, 0.94), f.theme.accent);
  }

  @override
  Duration get period => const Duration(milliseconds: 5200);

  @override
  double get still => 0.56;
}

// ── Minesweeper ─────────────────────────────────────────────────────────────

const _mineField = MinesweeperBoard(size: 5, start: 12, mineCount: 2, mines: '');
final _mines = List<int>.filled(25, 0)
  ..[4] = 1
  ..[20] = 1;
final _mineNumbers = minesweeperNumbers(_mines, 5);
final _opened = minesweeperFlood(
  List<int>.filled(25, minesweeperHidden),
  _mines,
  _mineNumbers,
  5,
  12,
);

List<int> _field({Set<int> open = const {}, Set<int> flags = const {}, int? struck}) => [
  for (var i = 0; i < 25; i++)
    i == struck
        ? minesweeperStruck
        : flags.contains(i)
        ? minesweeperFlagged
        : open.contains(i)
        ? _mineNumbers[i]
        : minesweeperHidden,
];

/// One tap in the middle; the empty area spills open.
class MinesOpenDemo extends HowToDemo {
  const MinesOpenDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 5);
    final open = <int>{
      for (final i in _opened)
        if (f.at(0.22 + _dist(i, 12, 5) * 0.06)) i,
    };
    b.draw(canvas, MinesweeperBoardPainter(board: _mineField, theme: f.theme, cells: _field(open: open)));
    paintFinger(canvas, f, _taps(b, [(0.2, 12)]));
  }
}

/// A 1 lights up, then its neighbours: only one is still closed.
class MinesNumberDemo extends HowToDemo {
  const MinesNumberDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 5);
    b.draw(canvas, MinesweeperBoardPainter(board: _mineField, theme: f.theme, cells: _field(open: _opened.toSet())));
    final a = f.theme.accent;
    paintSpotlight(canvas, b.rect(3).deflate(2), a, f.seg(0.08, 0.16) * (1 - f.seg(0.84, 0.9)));
    final ring = f.seg(0.26, 0.36) * (1 - f.seg(0.84, 0.9));
    paintSpotlight(canvas, b.rect(2).expandToInclude(b.rect(9)).deflate(1), a, ring * 0.6);
    final pulse = f.at(0.46) ? 0.55 + 0.45 * math.sin(f.t * math.pi * 12) : 0.0;
    paintSpotlight(canvas, b.rect(4).deflate(3), f.theme.danger, pulse * (1 - f.seg(0.84, 0.9)));
  }
}

/// Long-press to plant a flag on each mine. Field clears.
class MinesFlagDemo extends HowToDemo {
  const MinesFlagDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 5);
    final flags = {if (f.at(0.38)) 4, if (f.at(0.68)) 20};
    b.draw(
      canvas,
      MinesweeperBoardPainter(
        board: _mineField,
        theme: f.theme,
        cells: _field(open: _opened.toSet(), flags: flags),
        popCell: f.at(0.68) ? 20 : 4,
        pop: f.at(0.68) ? f.pop(0.68) : f.pop(0.38),
        win: f.seg(0.72, 0.9, Curves.linear),
      ),
    );
    paintFinger(canvas, f, [
      FingerKey(0.22, b.center(4), hold: 0.16),
      FingerKey(0.52, b.center(20), hold: 0.16),
    ]);
    paintSparkles(canvas, b.origin + Offset(b.side / 2, b.side / 2), b.side * 0.42,
        f.seg(0.72, 0.92, Curves.linear), f.theme.accent);
  }
}

/// Tap a mine: boom, +30s floats up.
class MinesPenaltyDemo extends HowToDemo {
  const MinesPenaltyDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 5);
    b.draw(
      canvas,
      MinesweeperBoardPainter(
        board: _mineField,
        theme: f.theme,
        cells: _field(open: _opened.toSet(), flags: {4}, struck: f.at(0.3) ? 20 : null),
        popCell: 20,
        pop: f.pop(0.3, 0.1),
      ),
    );
    paintFinger(canvas, f, _taps(b, [(0.3, 20)]));
    if (f.at(0.3)) {
      final shake = (1 - f.seg(0.3, 0.42, Curves.linear));
      paintSpotlight(canvas, b.rect(20).deflate(2).shift(Offset(math.sin(f.t * 120) * 3 * shake, 0)),
          f.theme.danger, 1 - f.seg(0.6, 0.7));
    }
    paintFloatLabel(canvas, f, b.center(20) + Offset(b.grid.cell * 0.9, 0), '+30s',
        f.seg(0.32, 0.8, Curves.linear), f.theme.danger);
  }

  @override
  double get still => 0.45;
}

/// Tip: a 1 lights up, then the one hidden square beside it, which is flagged.
class MinesTipDemo extends HowToDemo {
  const MinesTipDemo();

  /// The opened 1 nearest the bottom-left mine whose only hidden neighbour
  /// is that mine: found rather than hard-coded, so it stays true to the
  /// demo field.
  static final int _one = () {
    final open = _opened.toSet();
    for (final i in open) {
      if (_mineNumbers[i] != 1) continue;
      final hidden = minesweeperNeighbours(i, 5).where((x) => !open.contains(x));
      if (hidden.length == 1 && hidden.single == 20) return i;
    }
    return 15;
  }();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 5);
    final flagged = f.at(0.58);
    b.draw(
      canvas,
      MinesweeperBoardPainter(
        board: _mineField,
        theme: f.theme,
        cells: _field(open: _opened.toSet(), flags: {if (flagged) 20}),
        popCell: 20,
        pop: f.pop(0.58),
      ),
    );
    final fade = 1 - f.seg(0.84, 0.9);
    paintSpotlight(canvas, b.rect(_one).deflate(2), f.theme.accent, f.seg(0.06, 0.14) * fade);
    // Its neighbours, all open but one.
    final around = minesweeperNeighbours(_one, 5).map(b.rect).fold(b.rect(_one), (a, r) => a.expandToInclude(r));
    paintSpotlight(canvas, around.deflate(1), f.theme.accent, f.seg(0.2, 0.28) * (1 - f.seg(0.4, 0.46)) * 0.6);
    final pulse = flagged ? 0.0 : 0.55 + 0.45 * math.sin(f.t * math.pi * 12);
    paintSpotlight(canvas, b.rect(20).deflate(3), f.theme.danger, pulse * f.seg(0.3, 0.36));
    paintFinger(canvas, f, [FingerKey(0.42, b.center(20), hold: 0.16)]);
    paintSparkles(canvas, b.center(20), b.side * 0.2, f.seg(0.6, 0.78), f.theme.accent, count: 6);
  }

  @override
  double get still => 0.36;
}

// ── Star Battle ─────────────────────────────────────────────────────────────

const _stars = StarBattleBoard(
  size: 8,
  regions: [
    0, 0, 0, 1, 1, 2, 2, 2, //
    0, 0, 0, 1, 2, 2, 2, 2, //
    0, 0, 0, 1, 1, 2, 2, 2, //
    4, 0, 5, 1, 3, 3, 3, 3, //
    4, 4, 5, 5, 6, 3, 7, 3, //
    4, 4, 5, 6, 6, 6, 7, 7, //
    4, 4, 5, 5, 6, 6, 7, 7, //
    4, 4, 5, 6, 6, 6, 7, 7, //
  ],
);
const _starSolution = [1, 3, 13, 15, 17, 19, 29, 31, 32, 34, 44, 46, 48, 50, 60, 62];

List<StarMark> _starMarks(Iterable<int> stars, [Iterable<int> dots = const []]) => [
  for (var i = 0; i < 64; i++)
    stars.contains(i)
        ? StarMark.star
        : dots.contains(i)
        ? StarMark.dot
        : StarMark.none,
];

/// Two stars per row, column and colour, landing row by row.
class StarsRulesDemo extends HowToDemo {
  const StarsRulesDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 8);
    final times = [for (var k = 0; k < 16; k++) 0.08 + k * 0.036];
    final n = f.count(times);
    b.draw(
      canvas,
      StarBattleBoardPainter(
        board: _stars,
        theme: f.theme,
        palette: f.palette,
        marks: _starMarks(_starSolution.take(n)),
        popCell: n == 0 ? null : _starSolution[n - 1],
        pop: n == 0 ? 1 : f.pop(times[n - 1]),
        win: f.seg(0.7, 0.9, Curves.linear),
      ),
    );
    paintSparkles(canvas, b.origin + Offset(b.side / 2, b.side / 2), b.side * 0.42,
        f.seg(0.7, 0.92, Curves.linear), const Color(0xFFFFC53D));
  }
}

/// A star diagonal to another: red. Take it back, put it somewhere clear.
class StarsTouchDemo extends HowToDemo {
  const StarsTouchDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 8);
    final stars = {
      if (f.at(0.14)) 19,
      if (f.at(0.36) && !f.at(0.66)) 28,
      if (f.at(0.78)) 31,
    };
    final marks = _starMarks(stars);
    final pops = [(0.14, 19), (0.36, 28), (0.78, 31)];
    final current = pops.lastWhere((p) => f.at(p.$1), orElse: () => pops[0]);
    b.draw(
      canvas,
      StarBattleBoardPainter(
        board: _stars,
        theme: f.theme,
        palette: f.palette,
        marks: marks,
        conflicts: starBattleConflicts(_stars, marks),
        popCell: f.at(current.$1) ? current.$2 : null,
        pop: f.pop(current.$1),
      ),
    );
    paintFinger(canvas, f, [
      FingerKey(0.14, b.center(19), tap: true),
      FingerKey(0.3, b.center(28), tap: true),
      FingerKey(0.36, b.center(28), tap: true),
      FingerKey(0.66, b.center(28), tap: true),
      FingerKey(0.78, b.center(31), tap: true),
    ]);
    paintSparkles(canvas, b.center(31), b.side * 0.2, f.seg(0.8, 0.95), const Color(0xFFFFC53D));
  }

  @override
  double get still => 0.5;
}

/// One square, three taps: dot, star, clear.
class StarsControlsDemo extends HowToDemo {
  const StarsControlsDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 8);
    const taps = [0.18, 0.42, 0.66];
    final n = f.count(taps);
    final mark = switch (n) {
      1 => StarMark.dot,
      2 => StarMark.star,
      _ => StarMark.none,
    };
    b.draw(
      canvas,
      StarBattleBoardPainter(
        board: _stars,
        theme: f.theme,
        palette: f.palette,
        marks: [for (var i = 0; i < 64; i++) i == 27 ? mark : StarMark.none],
        popCell: 27,
        pop: n == 0 ? 1 : f.pop(taps[n - 1]),
      ),
    );
    // The finger steps aside after each tap, so the dot it left is seen.
    paintFinger(canvas, f, [
      for (final t in taps) ...[
        FingerKey(t, b.center(27), tap: true),
        FingerKey(t + 0.1, b.center(45)),
      ],
    ]);
  }

  @override
  double get still => 0.5;
}

/// Tip: a star dots out its ring; a second star in the row dots out the rest.
class StarsTipDemo extends HowToDemo {
  const StarsTipDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 8);
    final stars = [if (f.at(0.12)) 17, if (f.at(0.54)) 19];
    final marks = _starMarks(stars);
    final blocked = stars.isEmpty
        ? <int>[]
        : (starBattleBlocked(_stars, marks).toList()
            ..sort((a, c) => _dist(a, stars.last, 8).compareTo(_dist(c, stars.last, 8))));
    final since = f.at(0.54) ? 0.56 : 0.16;
    final before = f.at(0.54) ? starBattleBlocked(_stars, _starMarks([17])) : <int>{};
    final fresh = blocked.where((i) => !before.contains(i)).toList();
    final shown = (fresh.length * f.seg(since, since + 0.24, Curves.linear)).round();
    b.draw(
      canvas,
      StarBattleBoardPainter(
        board: _stars,
        theme: f.theme,
        palette: f.palette,
        marks: marks,
        autoBlocked: {...before, ...fresh.take(shown)},
        popCell: stars.isEmpty ? null : stars.last,
        pop: f.at(0.54) ? f.pop(0.54) : f.pop(0.12),
      ),
    );
    paintFinger(canvas, f, _taps(b, [(0.12, 17), (0.54, 19)]));
    paintSpotlight(
      canvas,
      b.rect(16).expandToInclude(b.rect(23)).deflate(1),
      f.theme.accent,
      f.seg(0.6, 0.68) * (1 - f.seg(0.84, 0.9)),
    );
  }
}

// ── Patches ─────────────────────────────────────────────────────────────────

// Five patches on a 4×4, and only one way to cut it: the wide 4 can only be
// the bottom row, which leaves the blank tall clue the whole of its column.
// Every kind of badge is on it, a blank one included, so the guide shows each
// before the player meets it on a real board.
const _patches = PatchesBoard(
  size: 4,
  clues: [
    PatchClue(cell: 2, shape: PatchShape.tall),
    PatchClue(cell: 5, shape: PatchShape.square, area: 4),
    PatchClue(cell: 8, shape: PatchShape.wide, area: 2),
    PatchClue(cell: 11, shape: PatchShape.any, area: 3),
    PatchClue(cell: 12, shape: PatchShape.wide, area: 4),
  ],
);
const _patchAnswer = [
  PatchRect(0, 2, 2, 2),
  PatchRect(0, 0, 1, 1),
  PatchRect(2, 0, 2, 1),
  PatchRect(0, 3, 2, 3),
  PatchRect(3, 0, 3, 3),
];

/// One drag on the Patches board: the finger lands on the first key's square
/// and glides through the rest, and the rectangle runs from where it landed
/// to whichever square is under the finger — the board's own reading of a
/// stroke, so the demo cannot draw a rectangle the real board would not.
class _PatchStroke {
  const _PatchStroke(this.keys);

  /// (loop time, square) — the first is the press, the last the release.
  final List<(double, int)> keys;

  double get start => keys.first.$1;
  double get end => keys.last.$1;

  List<FingerKey> finger(DemoBoard b) => [
    for (var i = 0; i < keys.length; i++)
      FingerKey(keys[i].$1, b.center(keys[i].$2), tap: i == 0),
  ];

  /// The rectangle under the finger, while the stroke is in progress.
  PatchRect? preview(DemoFrame f, DemoBoard b) {
    if (!f.at(start) || f.at(end)) return null;
    var pos = b.center(keys.first.$2);
    for (var i = 1; i < keys.length; i++) {
      final (t0, c0) = keys[i - 1];
      final (t1, c1) = keys[i];
      if (f.t >= t1) {
        pos = b.center(c1);
        continue;
      }
      // Eased exactly as the ghost finger is, so the rectangle and the
      // fingertip never disagree about where the finger is.
      final p = Curves.easeInOutCubic.transform(
        ((f.t - t0) / (t1 - t0)).clamp(0.0, 1.0),
      );
      pos = Offset.lerp(b.center(c0), b.center(c1), p)!;
      break;
    }
    final reach = b.grid.hit(pos - b.origin) ?? keys.first.$2;
    return PatchRect.span(keys.first.$2, reach, b.n);
  }

  /// Where the finger let go, as the patch it laid down.
  PatchRect get landed =>
      PatchRect.span(keys.first.$2, keys.last.$2, _patches.size);
}

/// Draws [patches] plus [stroke]'s rectangle, judged the way the board judges
/// it: in its clue's colour while it fits, red while it does not.
void _paintPatches(
  Canvas canvas,
  DemoFrame f,
  DemoBoard b,
  List<PatchRect?> patches, {
  PatchRect? preview,
  int? popClue,
  double pop = 1,
  double win = 0,
}) {
  final judged = preview == null ? null : patchJudge(_patches, preview);
  b.draw(
    canvas,
    PatchesBoardPainter(
      board: _patches,
      theme: f.theme,
      palette: f.palette,
      patches: patches,
      preview: preview,
      previewClue: judged?.clue ?? -1,
      previewOk: judged != null && judged.trouble == null,
      popClue: popClue,
      pop: pop,
      win: win,
    ),
  );
}

/// The whole board cut, patch by patch.
class PatchesRulesDemo extends HowToDemo {
  const PatchesRulesDemo();

  static const _order = [1, 0, 3, 2, 4];
  static const _strokes = [
    _PatchStroke([(0.06, 0), (0.14, 5)]),
    _PatchStroke([(0.2, 2), (0.28, 10)]),
    _PatchStroke([(0.34, 3), (0.42, 11)]),
    _PatchStroke([(0.48, 8), (0.54, 9)]),
    _PatchStroke([(0.6, 12), (0.68, 15)]),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final patches = List<PatchRect?>.filled(5, null);
    PatchRect? preview;
    int? last;
    for (var i = 0; i < _strokes.length; i++) {
      final s = _strokes[i];
      if (f.at(s.end)) {
        patches[_order[i]] = _patchAnswer[_order[i]];
        last = i;
      }
      preview ??= s.preview(f, b);
    }
    _paintPatches(
      canvas,
      f,
      b,
      patches,
      preview: preview,
      popClue: last == null ? null : _order[last],
      pop: last == null ? 1 : f.pop(_strokes[last].end),
      win: f.seg(0.72, 0.92, Curves.linear),
    );
    paintFinger(canvas, f, [for (final s in _strokes) ...s.finger(b)]);
    paintSparkles(
      canvas,
      b.origin + Offset(b.side / 2, b.side / 2),
      b.side * 0.42,
      f.seg(0.72, 0.94, Curves.linear),
      const Color(0xFFFFC53D),
    );
  }
}

/// The badge is the rule. A spotlight walks the four kinds in the order the
/// step names them (square, tall, wide, dashed), then a square 4 refuses a
/// bar of 3 (red) and takes a 2×2.
class PatchesShapeDemo extends HowToDemo {
  const PatchesShapeDemo();

  /// The square, tall, wide and "any" clues' squares.
  static const _tour = [5, 2, 8, 11];
  static const _stroke = _PatchStroke([(0.46, 4), (0.58, 6), (0.64, 6), (0.78, 1)]);

  @override
  Duration get period => const Duration(milliseconds: 5600);

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final done = f.at(_stroke.end);
    _paintPatches(
      canvas,
      f,
      b,
      [null, if (done) _stroke.landed else null, null, null, null],
      preview: _stroke.preview(f, b),
      popClue: done ? 1 : null,
      pop: f.pop(_stroke.end),
    );
    // One spotlight gliding badge to badge, rather than four blinking on and
    // off: the eye follows it instead of hunting for the next one.
    var spot = b.rect(_tour.first);
    for (var i = 1; i < _tour.length; i++) {
      final start = 0.1 * i;
      spot = Rect.lerp(spot, b.rect(_tour[i]), f.seg(start, start + 0.04))!;
    }
    paintSpotlight(
      canvas,
      spot.deflate(b.grid.cell * 0.12),
      f.theme.accent,
      f.seg(0.02, 0.06) * (1 - f.seg(0.4, 0.44)),
      radius: b.grid.cell * 0.2,
    );
    paintFinger(canvas, f, _stroke.finger(b));
    paintSparkles(canvas, b.center(5), b.side * 0.22, f.seg(0.8, 0.92),
        const Color(0xFFFFC53D));
  }

  @override
  double get still => 0.61;
}

/// Drag to cut a patch; tap it to lift it off; cut it again.
class PatchesControlsDemo extends HowToDemo {
  const PatchesControlsDemo();

  static const _first = _PatchStroke([(0.1, 8), (0.24, 9)]);
  static const _again = _PatchStroke([(0.66, 9), (0.8, 8)]);
  static const _lift = 0.48;

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final down =
        (f.at(_first.end) && !f.at(_lift)) || f.at(_again.end);
    final pop = f.at(_again.end) ? f.pop(_again.end) : f.pop(_first.end);
    _paintPatches(
      canvas,
      f,
      b,
      [null, null, if (down) _patchAnswer[2] else null, null, null],
      preview: _first.preview(f, b) ?? _again.preview(f, b),
      popClue: down ? 2 : null,
      pop: pop,
    );
    paintFinger(canvas, f, [
      ..._first.finger(b),
      // Steps aside so the landed patch is seen, then comes back to tap it.
      FingerKey(0.34, b.center(14)),
      FingerKey(_lift, b.center(9), tap: true),
      FingerKey(0.56, b.center(14)),
      ..._again.finger(b),
    ]);
  }

  @override
  double get still => 0.3;
}

/// Tip: the wide 4 on the bottom edge fits one way only. Start there.
class PatchesTipDemo extends HowToDemo {
  const PatchesTipDemo();

  static const _stroke = _PatchStroke([(0.4, 12), (0.6, 15)]);

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = DemoBoard(f, n: 4);
    final done = f.at(_stroke.end);
    _paintPatches(
      canvas,
      f,
      b,
      [null, null, null, null, if (done) _patchAnswer[4] else null],
      preview: _stroke.preview(f, b),
      popClue: done ? 4 : null,
      pop: f.pop(_stroke.end),
    );
    final glow = f.seg(0.06, 0.14) * (1 - f.seg(0.34, 0.4));
    paintSpotlight(
      canvas,
      b.rect(12).deflate(b.grid.cell * 0.12),
      f.theme.accent,
      glow,
      radius: b.grid.cell * 0.2,
    );
    // Then the one row it can be.
    paintSpotlight(
      canvas,
      b.rect(12).expandToInclude(b.rect(15)).deflate(1),
      f.theme.accent,
      f.seg(0.2, 0.28) * (1 - f.seg(0.36, 0.42)),
    );
    paintFinger(canvas, f, _stroke.finger(b));
    paintSparkles(canvas, b.center(13), b.side * 0.24, f.seg(0.62, 0.8),
        const Color(0xFFFFC53D));
  }

  @override
  double get still => 0.3;
}

// ── Code puzzle ─────────────────────────────────────────────────────────────

enum _Peg { exact, present, absent }

const _codeGuesses = [
  [0, 1, 2, 3],
  [2, 0, 5, 1],
  [2, 0, 4, 5],
];
const _codeVerdicts = [
  [_Peg.present, _Peg.absent, _Peg.present, _Peg.absent],
  [_Peg.exact, _Peg.exact, _Peg.present, _Peg.absent],
  [_Peg.exact, _Peg.exact, _Peg.exact, _Peg.exact],
];

/// Draws the code grid: [rows] rows, each with a guess typed up to [typed]
/// symbols and its verdict flipped [flip] of the way through (0..1 per cell
/// staggered).
void _codeGrid(
  Canvas canvas,
  DemoFrame f, {
  required int rows,
  required List<int> typed,
  required List<double> flips,
  bool secret = false,
  List<List<int>> guesses = _codeGuesses,
  List<List<_Peg>> verdicts = _codeVerdicts,
}) {
  final side = f.side * 0.82;
  final gap = side * 0.045;
  final cell = math.min((side - gap * 3) / 4, (f.size.height * 0.84 - gap * (rows - 1)) / rows);
  final width = cell * 4 + gap * 3;
  final height = cell * rows + gap * (rows - 1);
  final origin = Offset((f.size.width - width) / 2, (f.size.height - height) / 2);
  final accent = f.theme.accent;

  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < 4; c++) {
      final rect = Rect.fromLTWH(
        origin.dx + c * (cell + gap),
        origin.dy + r * (cell + gap),
        cell,
        cell,
      );
      final guess = r < guesses.length ? guesses[r] : null;
      final has = guess != null && r < typed.length && c < typed[r];
      // Cell by cell, left to right, the way the real board checks a row.
      final flip = r < flips.length
          ? (flips[r] * 4 - c).clamp(0.0, 1.0)
          : 0.0;
      final verdict = flip > 0.5 && guess != null ? verdicts[r][c] : null;
      final fill = switch (verdict) {
        _Peg.exact => f.theme.success.withValues(alpha: 0.32),
        _Peg.present => const Color(0xFFF5B400).withValues(alpha: 0.55),
        _Peg.absent => f.theme.ink.withValues(alpha: 0.16),
        null => f.theme.ink.withValues(alpha: has ? 0.1 : 0.05),
      };
      final squash = (math.cos(flip * math.pi)).abs();
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.scale(1, squash);
      final local = Rect.fromCenter(center: Offset.zero, width: cell, height: cell);
      canvas.drawRRect(
        RRect.fromRectAndRadius(local, Radius.circular(cell * 0.22)),
        Paint()..color = fill,
      );
      if (has) {
        PuzzleSymbol.paintSymbol(canvas, Offset.zero, cell * 0.5, guess[c], accent);
      } else if (secret && r == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '?',
            style: f.theme.body.copyWith(
              fontSize: cell * 0.45,
              fontWeight: FontWeight.w800,
              color: f.theme.inkMuted,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      }
      canvas.restore();
    }
  }
}

/// Where cell ([r], [c]) of a [rows]-row code grid sits: [_codeGrid]'s own
/// layout, for drawing on top of it.
Rect _codeCell(DemoFrame f, int rows, int r, int c) {
  final side = f.side * 0.82;
  final gap = side * 0.045;
  final cell = math.min((side - gap * 3) / 4, (f.size.height * 0.84 - gap * (rows - 1)) / rows);
  final width = cell * 4 + gap * 3;
  final height = cell * rows + gap * (rows - 1);
  final origin = Offset((f.size.width - width) / 2, (f.size.height - height) / 2);
  return Rect.fromLTWH(origin.dx + c * (cell + gap), origin.dy + r * (cell + gap), cell, cell);
}

/// A row of four ? marks; symbols get typed in.
class CodeGoalDemo extends HowToDemo {
  const CodeGoalDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final typed = f.count(const [0.2, 0.32, 0.44, 0.56]);
    _codeGrid(canvas, f, rows: 1, typed: [typed], flips: const [], secret: true);
  }
}

/// A guess flips: two greens light up.
class CodeGreenDemo extends HowToDemo {
  const CodeGreenDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    _codeGrid(canvas, f, rows: 2, typed: const [4, 4], flips: [1, f.seg(0.2, 0.5, Curves.linear)]);
  }

  @override
  double get still => 0.7;
}

/// The first guess flips: yellows and greys.
class CodeYellowDemo extends HowToDemo {
  const CodeYellowDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    _codeGrid(canvas, f, rows: 1, typed: const [4], flips: [f.seg(0.2, 0.5, Curves.linear)]);
  }

  @override
  double get still => 0.7;
}

/// Three rows down, all green, burst.
class CodeWinDemo extends HowToDemo {
  const CodeWinDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final typed = f.count(const [0.16, 0.24, 0.32, 0.4]);
    _codeGrid(
      canvas,
      f,
      rows: 6,
      typed: [4, 4, typed],
      flips: [1, 1, f.seg(0.46, 0.7, Curves.linear)],
    );
    paintSparkles(
      canvas,
      Offset(f.size.width / 2, f.size.height / 2),
      f.side * 0.42,
      f.seg(0.7, 0.92, Curves.linear),
      f.theme.success,
    );
  }
}

// The tip's game: the first guess finds 2 of the code's symbols, the second
// spends its two free slots on the two symbols never tried, and all four turn
// up. One reorder later, it's solved.
const _tipGuesses = [
  [0, 1, 2, 3],
  [4, 5, 0, 2],
  [2, 0, 4, 5],
];
const _tipVerdicts = [
  [_Peg.present, _Peg.absent, _Peg.present, _Peg.absent],
  [_Peg.present, _Peg.present, _Peg.present, _Peg.present],
  [_Peg.exact, _Peg.exact, _Peg.exact, _Peg.exact],
];

/// Tip: guess two brings in the two symbols nobody has tried yet. All four
/// light up, so the third guess only has to put them in order.
class CodeTipDemo extends HowToDemo {
  const CodeTipDemo();

  @override
  Duration get period => const Duration(milliseconds: 5200);

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final second = f.count(const [0.14, 0.2, 0.26, 0.32]);
    final third = f.count(const [0.6, 0.64, 0.68, 0.72]);
    _codeGrid(
      canvas,
      f,
      rows: 3,
      typed: [4, second, third],
      flips: [1, f.seg(0.36, 0.52, Curves.linear), f.seg(0.76, 0.88, Curves.linear)],
      guesses: _tipGuesses,
      verdicts: _tipVerdicts,
    );
    // The two new symbols, as they go in.
    final fresh = f.seg(0.14, 0.2) * (1 - f.seg(0.5, 0.56));
    paintSpotlight(
      canvas,
      _codeCell(f, 3, 1, 0).expandToInclude(_codeCell(f, 3, 1, 1)).inflate(3),
      f.theme.accent,
      fresh,
      radius: 10,
    );
    // Four yellows: every symbol found.
    paintSpotlight(
      canvas,
      _codeCell(f, 3, 1, 0).expandToInclude(_codeCell(f, 3, 1, 3)).inflate(3),
      const Color(0xFFF5B400),
      f.seg(0.52, 0.56) * (1 - f.seg(0.64, 0.7)),
      radius: 10,
    );
    paintSparkles(
      canvas,
      Offset(f.size.width / 2, f.size.height / 2),
      f.side * 0.42,
      f.seg(0.88, 0.99, Curves.linear),
      f.theme.success,
    );
  }

  @override
  double get still => 0.56;
}
