import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/games_api.dart';
import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/hint_spotlight.dart';
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

  /// The hint on show, until the player's next move or a tap on its banner.
  BoardHint? _spot;
  int _hintSerial = 0;

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
    _play.snapshot = () => [for (final m in _marks) m.index];
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
      _spot = null;
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
      _spot = null;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _hint() async {
    final board = GamesStore.instance.boards.queens;
    final n = board.size;
    // Every mark, crosses included: a cross over the square a crown belongs
    // in is exactly the mistake a stuck player cannot see, and the hint has
    // to be able to point at it.
    final hint = await _play.hint([for (final m in _marks) m.index]);
    if (hint == null || !mounted) return;
    final total = n * n;
    setState(() {
      _undo.clear();
      final cell = hint.cell;
      if (hint.kind == null || cell == null || cell < 0 || cell >= total) {
        // A server from before explained hints: row [index]'s crown is at
        // column [value].
        final at = hint.index * n + hint.value;
        if (at < 0 || at >= total) return;
        _marks[at] = QueensMark.crown;
        _popCell = at;
        _spot = BoardHint(hint: hint, serial: ++_hintSerial, target: {at});
        return;
      }
      if (hint.kind == GameHintKind.wrong) {
        _marks[cell] = QueensMark.none;
        _popCell = null;
        _spot = BoardHint.of(hint, serial: ++_hintSerial);
        return;
      }
      if (hint.answer == 0 && hint.cells.isNotEmpty) {
        // A step that rules squares out: cross every one of them.
        final crossed = {
          for (final c in hint.cells)
            if (c >= 0 && c < total) c,
        };
        for (final c in crossed) {
          if (_marks[c] == QueensMark.none) _marks[c] = QueensMark.blocked;
        }
        _popCell = null;
        _spot = BoardHint.of(hint, serial: ++_hintSerial, target: crossed);
        return;
      }
      _marks[cell] = QueensMark.crown;
      _popCell = cell;
      _spot = BoardHint.of(hint, serial: ++_hintSerial);
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
      _spot = null;
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
      onUndo: _undo.isEmpty ? null : _undoLast,
      title: l10n.gameQueensName,
      rule: l10n.gameQueensRule,
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
