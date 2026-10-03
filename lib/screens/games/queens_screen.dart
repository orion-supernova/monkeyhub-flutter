import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/queens_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// QUEENS — one crown per row, per column and per colour region, and no two
/// crowns touching, not even at a corner.
///
/// A tap cycles a square through nothing → cross → crown, which is the order
/// that matches how the game is actually played: you rule squares out long
/// before you commit to one. The board rules squares out alongside you, faintly
/// — see [_autoCross] for why those crosses are drawn differently from the
/// player's own.
class QueensScreen extends StatefulWidget {
  const QueensScreen({super.key, required this.userId});

  final String userId;

  @override
  State<QueensScreen> createState() => _QueensScreenState();
}

class _QueensScreenState extends State<QueensScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.queens,
    userId: widget.userId,
  );

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final AnimationController _winSweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  List<QueensMark> _marks = const [];
  final List<(int, QueensMark)> _undo = [];
  int? _popCell;

  /// Whether the board crosses out the squares a placed crown rules out.
  ///
  /// On by default. Doing that bookkeeping by hand is sixty taps of arithmetic
  /// the game is not actually about, and every player who turns it off does so
  /// deliberately — which is why it is a toggle rather than a decision made for
  /// them.
  bool _autoCross = true;

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
  }

  /// Rebuilds the board from whatever was saved.
  ///
  /// The saved array is the player's own marks while a board is in progress and
  /// the submitted answer once it is finished — the two are told apart by
  /// length, since an answer is one column per row and a board is one mark per
  /// square. Without that, reopening a solved Queens would show an empty grid.
  void _restore() {
    final board = GamesStore.instance.boards.queens;
    final n = board.size;
    if (n == 0) return;
    _marks = List<QueensMark>.filled(n * n, QueensMark.none);
    final saved = _play.restored;
    if (saved.length == n * n) {
      for (var i = 0; i < saved.length; i++) {
        _marks[i] = QueensMark.values[saved[i].clamp(0, 2)];
      }
    } else if (saved.length == n) {
      for (var row = 0; row < n; row++) {
        if (saved[row] >= 0 && saved[row] < n) {
          _marks[row * n + saved[row]] = QueensMark.crown;
        }
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
      ..checkpoint([for (final m in _marks) m.index])
      ..removeListener(_onPlay)
      ..dispose();
    GamesStore.instance.removeListener(_onPlay);
    _pop.dispose();
    _winSweep.dispose();
    super.dispose();
  }

  void _tap(int index) {
    if (!_play.ready || _play.finished || _play.paused || _play.busy) return;
    final before = _marks[index];
    final next = switch (before) {
      QueensMark.none => QueensMark.blocked,
      QueensMark.blocked => QueensMark.crown,
      QueensMark.crown => QueensMark.none,
    };
    setState(() {
      _undo.add((index, before));
      _marks[index] = next;
      _popCell = index;
    });
    _pop.forward(from: 0);
    HapticFeedback.selectionClick();

    final board = GamesStore.instance.boards.queens;
    if (next == QueensMark.crown &&
        queensConflicts(board, _marks).contains(index)) {
      // Counted the moment a crown lands somewhere it cannot go, not at the
      // end. A mistake tallied at submit time is a number with no memory
      // attached to it.
      _play.noteMistake();
      HapticFeedback.heavyImpact();
      return;
    }
    _maybeFinish();
  }

  void _undoLast() {
    if (_undo.isEmpty || _play.finished) return;
    final (index, mark) = _undo.removeLast();
    setState(() {
      _marks[index] = mark;
      _popCell = null;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _hint() async {
    final board = GamesStore.instance.boards.queens;
    // Queens' hint speaks in rows: the answer is a column per row, so the reply
    // is "row N's crown belongs in column M". -1 marks a row the player has not
    // settled on one crown for.
    final current = queensSolution(board, _marks) ??
        List<int>.filled(board.size, -1);
    final hint = await _play.hint(current);
    if (hint == null || !mounted) return;
    setState(() {
      for (var c = 0; c < board.size; c++) {
        final cell = hint.index * board.size + c;
        _marks[cell] = c == hint.value ? QueensMark.crown : QueensMark.blocked;
      }
      _popCell = hint.index * board.size + hint.value;
      _undo.clear();
    });
    _pop.forward(from: 0);
    _maybeFinish();
  }

  Future<void> _giveUp() async {
    if (!await confirmGiveUp(context)) return;
    final answer = await _play.reveal();
    if (answer == null || !mounted) return;
    final board = GamesStore.instance.boards.queens;
    setState(() {
      _marks = List<QueensMark>.filled(board.size * board.size, QueensMark.none);
      for (var row = 0; row < answer.length; row++) {
        _marks[row * board.size + answer[row]] = QueensMark.crown;
      }
    });
  }

  /// Submits the moment the board is complete and legal.
  ///
  /// No "check" button. On a board whose rules are fully visible there is
  /// nothing left to check — a legal, complete grid IS the answer, and asking
  /// the player to confirm it costs them a second on a timed game for no
  /// information.
  Future<void> _maybeFinish() async {
    final board = GamesStore.instance.boards.queens;
    if (!queensSolved(board, _marks)) return;
    final solution = queensSolution(board, _marks);
    if (solution == null) return;
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(solution);
    if (ok && mounted) _winSweep.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = GamesStore.instance.boards.queens;
    final conflicts = queensConflicts(board, _marks);

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gameQueensName,
      rule: l10n.gameQueensRule,
      board: AnimatedBuilder(
        animation: Listenable.merge([_pop, _winSweep]),
        builder: (context, _) => GameBoardSurface(
          onTapCell: _tap,
          n: board.size,
          painter: QueensBoardPainter(
            board: board,
            theme: theme,
            palette: GamePalette(theme),
            marks: _play.paused ? const [] : _marks,
            conflicts: conflicts,
            autoBlocked: _autoCross && !_play.paused
                ? queensBlocked(board, _marks)
                : const {},
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
          icon: CupertinoIcons.xmark_square,
          label: l10n.gameAutoCross,
          selected: _autoCross,
          onTap: () => setState(() => _autoCross = !_autoCross),
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
      onShare: _play.finished
          ? () => copyGameResult(
              context,
              name: l10n.gameQueensName,
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
