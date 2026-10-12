import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../games/futoshiki_board_art.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_keypad.dart';
import 'game_scaffold.dart';

/// FUTOSHIKI — the digits 1 to 5, once in every row and column, with every
/// `<` and `>` printed between two squares holding.
///
/// Played like Mini Sudoku, on purpose: select a square, then a digit, with
/// pencil notes for the working. Sudoku players arrive already knowing the
/// controls, and the whole of what is new about the board is the chevrons.
/// Digits go in directly rather than by cycling, so a digit is judged the
/// moment it lands — there is no passing-through state to forgive.
class FutoshikiScreen extends StatefulWidget {
  const FutoshikiScreen({super.key, required this.userId});

  final String userId;

  @override
  State<FutoshikiScreen> createState() => _FutoshikiScreenState();
}

class _FutoshikiScreenState extends State<FutoshikiScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.futoshiki,
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

  /// Whether the keypad writes pencil marks instead of answers.
  bool _noting = false;

  @override
  void initState() {
    super.initState();
    _play.addListener(_onPlay);
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
    final board = GamesStore.instance.boards.futoshiki;
    final total = board.size * board.size;
    if (total == 0) return;
    _cells = List<int>.filled(total, futoshikiEmpty);
    final saved = _play.restored;
    if (saved.length == total) {
      for (var i = 0; i < total; i++) {
        // Printed digits are never taken from the save — if the board ever
        // changed under a stale autosave, the printed grid is the truth.
        _cells[i] = board.givens[i] != futoshikiEmpty ? futoshikiEmpty : saved[i];
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
    setState(() => _selected = index);
    HapticFeedback.selectionClick();
  }

  void _enter(int value) {
    final index = _selected;
    final board = GamesStore.instance.boards.futoshiki;
    if (!_playable || index == null) return;
    if (board.givens[index] != futoshikiEmpty) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _undo.add((index, _cells[index], {...?_notes[index]}));
      if (_noting && value != futoshikiEmpty) {
        // A pencil mark on a square that already holds an answer would be
        // invisible, so writing one clears the answer first.
        _cells[index] = futoshikiEmpty;
        final marks = _notes.putIfAbsent(index, () => <int>{});
        if (!marks.remove(value)) marks.add(value);
      } else {
        // Tapping the digit already in a square clears it, so the keypad is
        // its own eraser and nobody has to find the separate one.
        _cells[index] = _cells[index] == value ? futoshikiEmpty : value;
        _notes.remove(index);
      }
      _popCell = index;
      _counted.remove(index);
    });
    _pop.forward(from: 0);
    HapticFeedback.selectionClick();

    if (futoshikiTrouble(board, _full).cells.contains(index) &&
        _counted.add(index)) {
      _play.noteMistake();
      HapticFeedback.heavyImpact();
      return;
    }
    _maybeFinish();
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
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _hint() async {
    final hint = await _play.hint(_cells);
    if (hint == null || !mounted) return;
    setState(() {
      _cells[hint.index] = hint.value;
      _notes.remove(hint.index);
      _selected = hint.index;
      _popCell = hint.index;
      _counted.remove(hint.index);
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
    });
  }

  Future<void> _maybeFinish() async {
    final board = GamesStore.instance.boards.futoshiki;
    final full = [
      for (var i = 0; i < _cells.length; i++)
        board.givens[i] != futoshikiEmpty ? board.givens[i] : _cells[i],
    ];
    if (!futoshikiSolved(board, full)) return;
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(full);
    if (ok && mounted) _winSweep.forward(from: 0);
  }

  /// The grid with the printed digits folded in — what the rules are checked
  /// against, since a digit the player enters can clash with a printed one.
  List<int> get _full {
    final board = GamesStore.instance.boards.futoshiki;
    return [
      for (var i = 0; i < _cells.length; i++)
        board.givens.length > i && board.givens[i] != futoshikiEmpty
            ? board.givens[i]
            : _cells[i],
    ];
  }

  /// How many of each digit are still unplaced, so a keypad key can retire
  /// itself once its digit is all used up.
  Map<int, int> get _remaining {
    final board = GamesStore.instance.boards.futoshiki;
    final left = {for (var v = 1; v <= board.size; v++) v: board.size};
    for (var i = 0; i < _cells.length; i++) {
      final v = board.givens[i] != futoshikiEmpty ? board.givens[i] : _cells[i];
      if (v != futoshikiEmpty && left.containsKey(v)) left[v] = left[v]! - 1;
    }
    return left;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = GamesStore.instance.boards.futoshiki;

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gameFutoshikiName,
      rule: l10n.gameFutoshikiRule,
      board: AnimatedBuilder(
        animation: Listenable.merge([_pop, _winSweep]),
        builder: (context, _) => GameBoardSurface(
          onTapCell: _select,
          n: board.size,
          painter: FutoshikiBoardPainter(
            board: board,
            theme: theme,
            cells: _play.paused ? const [] : _cells,
            notes: _play.paused ? const {} : _notes,
            trouble: _play.paused
                ? const FutoshikiTrouble(cells: <int>{}, signs: <int>{})
                : futoshikiTrouble(board, _full),
            selected: _play.paused ? null : _selected,
            popCell: _popCell,
            pop: _pop.value,
            win: _winSweep.value,
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
              keyPrefix: 'futoshiki',
            ),
      onShare: _play.finished
          ? () => copyGameResult(
              context,
              name: l10n.gameFutoshikiName,
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
