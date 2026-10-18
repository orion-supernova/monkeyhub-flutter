import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/games_api.dart';
import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/hint_spotlight.dart';
import '../../games/sudoku_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_keypad.dart';
import 'game_scaffold.dart';

/// MINI SUDOKU — the digits 1 to 6, once in every row, column and 2×3 box.
///
/// Select a square, then a digit — rather than a digit and then squares. Both
/// work; this order is the one that lets the board highlight everything the
/// selected square is constrained by *before* you commit to anything, which on
/// a 6×6 is most of the deduction.
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key, required this.userId});

  final String userId;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.sudoku,
    userId: widget.userId,
  );

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final AnimationController _winSweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  List<int> _cells = const [];
  final Map<int, Set<int>> _notes = {};
  final List<(int, int, Set<int>)> _undo = [];
  final Set<int> _counted = {};
  int? _selected;
  int? _popCell;

  /// The hint on show, until the player's next move or a tap on its banner.
  BoardHint? _spot;
  int _hintSerial = 0;

  /// Whether the keypad writes pencil marks instead of answers.
  bool _noting = false;

  @override
  void initState() {
    super.initState();
    _play.addListener(_onPlay);
    _play.snapshot = () => List<int>.of(_cells);
    GamesStore.instance.addListener(_onPlay);
    _boot();
  }

  Future<void> _boot() async {
    await GamesStore.instance.load(widget.userId);
    if (!mounted) return;
    await _play.begin();
    if (!mounted) return;
    setState(_restore);
    // A board left solved but never submitted — the connection was down when
    // it was finished and the player walked away — goes in now. Waiting for a
    // tap would be waiting for the one move that unsolves it.
    if (!_play.finished) _maybeFinish();
  }

  void _restore() {
    final board = GamesStore.instance.boards.sudoku;
    final total = board.size * board.size;
    if (total == 0) return;
    _cells = List<int>.filled(total, sudokuEmpty);
    final saved = _play.restored;
    if (saved.length == total) {
      for (var i = 0; i < total; i++) {
        // Printed digits are never taken from the save — if the board ever
        // changed under a stale autosave, the printed grid is the truth.
        _cells[i] = board.givens[i] != sudokuEmpty ? sudokuEmpty : saved[i];
      }
    }
    if (_play.finished && _play.solved) _winSweep.value = 1;
  }

  void _onPlay() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _play
      ..checkpoint(_cells)
      ..removeListener(_onPlay)
      ..dispose();
    GamesStore.instance.removeListener(_onPlay);
    _pop.dispose();
    _winSweep.dispose();
    super.dispose();
  }

  bool get _playable =>
      _play.ready && !_play.finished && !_play.paused && !_play.busy;

  void _select(int index) {
    if (!_playable) return;
    setState(() {
      _selected = index;
      // Selecting the hinted square is looking at it; anywhere else is a
      // move on, and the hint has done its job.
      if (!(_spot?.target.contains(index) ?? true)) _spot = null;
    });
    HapticFeedback.selectionClick();
  }

  void _enter(int value) {
    final index = _selected;
    final board = GamesStore.instance.boards.sudoku;
    if (!_playable || index == null) return;
    if (board.givens[index] != sudokuEmpty) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _undo.add((index, _cells[index], {...?_notes[index]}));
      if (_noting && value != sudokuEmpty) {
        // A pencil mark on a square that already holds an answer would be
        // invisible, so writing one clears the answer first.
        _cells[index] = sudokuEmpty;
        final marks = _notes.putIfAbsent(index, () => <int>{});
        if (!marks.remove(value)) marks.add(value);
      } else {
        // Tapping the digit already in a square clears it, so the keypad is
        // its own eraser and nobody has to find the separate one.
        _cells[index] = _cells[index] == value ? sudokuEmpty : value;
        _notes.remove(index);
      }
      _popCell = index;
      _counted.remove(index);
      _spot = null;
    });
    _pop.forward(from: 0);
    HapticFeedback.selectionClick();

    if (sudokuConflicts(board, _withGivens(board)).contains(index) &&
        _counted.add(index)) {
      _play.noteMistake();
      HapticFeedback.heavyImpact();
      return;
    }
    _maybeFinish();
  }

  /// The grid as the rules see it: the player's digits with the printed ones
  /// folded in. The conflict check has to see the printed digits too — a 4
  /// typed into a row that already prints a 4 is exactly the mistake a player
  /// most needs flagged, and checking the player's cells alone never saw it.
  List<int> _withGivens(SudokuBoard board) => [
    for (var i = 0; i < _cells.length; i++)
      board.givens[i] != sudokuEmpty ? board.givens[i] : _cells[i],
  ];

  /// A key on the board: a digit types into the selected square, Backspace
  /// clears it, N turns pencil marks on and off.
  bool _key(int cell, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyN) {
      setState(() => _noting = !_noting);
      return true;
    }
    final v = digitOfKey(key);
    final board = GamesStore.instance.boards.sudoku;
    if (v == null || v > board.size) return false;
    if (_selected != cell) _select(cell);
    _enter(v);
    return true;
  }

  void _undoLast() {
    if (_undo.isEmpty || _play.finished) return;
    final (index, value, marks) = _undo.removeLast();
    setState(() {
      _cells[index] = value;
      if (marks.isEmpty) {
        _notes.remove(index);
      } else {
        _notes[index] = marks;
      }
      _selected = index;
      _popCell = null;
      _counted.remove(index);
      _spot = null;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _hint() async {
    final hint = await _play.hint(_cells);
    if (hint == null || !mounted) return;
    final cell = hint.cell ?? hint.index;
    if (cell < 0 || cell >= _cells.length) return;
    setState(() {
      _notes.remove(cell);
      _selected = cell;
      _counted.remove(cell);
      if (hint.kind == GameHintKind.wrong) {
        // The digit comes out; the ring and the banner say why.
        _cells[cell] = sudokuEmpty;
        _popCell = null;
      } else {
        _cells[cell] = hint.answer ?? hint.value;
        _popCell = cell;
      }
      _spot = BoardHint.of(hint, serial: ++_hintSerial, target: {cell});
    });
    _pop.forward(from: 0);
    _maybeFinish();
  }

  Future<void> _giveUp() async {
    if (!await confirmGiveUp(context)) return;
    final answer = await _play.reveal();
    if (answer == null || !mounted) return;
    setState(() {
      _cells = answer;
      _notes.clear();
      _selected = null;
      _spot = null;
    });
  }

  Future<void> _maybeFinish() async {
    final board = GamesStore.instance.boards.sudoku;
    final full = [
      for (var i = 0; i < _cells.length; i++)
        board.givens[i] != sudokuEmpty ? board.givens[i] : _cells[i],
    ];
    if (!sudokuSolved(board, full)) return;
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(full);
    if (ok && mounted) _winSweep.forward(from: 0);
  }

  /// How many of each digit are still unplaced, so a keypad key can retire
  /// itself once its digit is all used up.
  Map<int, int> get _remaining {
    final board = GamesStore.instance.boards.sudoku;
    final left = {for (var v = 1; v <= board.size; v++) v: board.size};
    for (var i = 0; i < _cells.length; i++) {
      final v = board.givens[i] != sudokuEmpty ? board.givens[i] : _cells[i];
      if (v != sudokuEmpty && left.containsKey(v)) left[v] = left[v]! - 1;
    }
    return left;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = GamesStore.instance.boards.sudoku;

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      onUndo: _undo.isEmpty ? null : _undoLast,
      title: l10n.gameSudokuName,
      rule: l10n.gameSudokuRule,
      hintBanner: HintBanner(
        hint: _play.paused ? null : _spot,
        onDismiss: () => setState(() => _spot = null),
      ),
      board: HintSpotlight(
        hint: _play.paused || _play.finished ? null : _spot,
        n: board.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pop, _winSweep]),
          builder: (context, _) => GameBoardSurface(
            onTapCell: _select,
            keyboardSelects: true,
            onCellKey: _key,
            n: board.size,
            painter: SudokuBoardPainter(
              board: board,
              theme: theme,
              cells: _play.paused ? const [] : _cells,
              notes: _play.paused ? const {} : _notes,
              conflicts: _play.paused
                  ? const {}
                  : sudokuConflicts(board, _withGivens(board)),
              selected: _play.paused ? null : _selected,
              popCell: _popCell,
              pop: _pop.value,
              win: _winSweep.value,
            ),
          ),
        ),
      ),
      tools: [
        GameTool(
          icon: CupertinoIcons.arrow_uturn_left,
          label: l10n.gameUndo,
          onTap: _undo.isEmpty ? null : _undoLast,
        ),
        GameTool(
          icon: CupertinoIcons.pencil,
          label: l10n.gameNotes,
          selected: _noting,
          onTap: () => setState(() => _noting = !_noting),
        ),
        GameTool(
          icon: CupertinoIcons.lightbulb,
          label: l10n.gameHint,
          onTap: _play.busy ? null : _hint,
        ),
        GameTool(
          icon: CupertinoIcons.flag,
          label: l10n.gameGiveUp,
          danger: true,
          onTap: _play.busy ? null : _giveUp,
        ),
      ],
      footer: board.isEmpty
          ? null
          : GameKeypad(
              size: board.size,
              remaining: _remaining,
              enabled: _playable && _selected != null,
              onEnter: _enter,
              keyPrefix: 'sudoku',
            ),
      onShare: _play.finished
          ? () => copyGameResult(
              context,
              name: l10n.gameSudokuName,
              solved: _play.solved,
              durationMs: _play.durationMs,
            )
          : null,
      onTellFriends: _play.finished
          ? () => tellFriendsAboutGame(context, controller: _play)
          : null,
    );
  }
}
