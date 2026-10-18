import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../games/flow_board_art.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/hint_spotlight.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// FLOW — join every pair of matching dots with a pipe, so the pipes never
/// cross and every square ends up in one.
///
/// Drawn with a finger, like Zip, and built on the same gesture surface (see
/// zip_screen.dart for why a drag that starts on the board belongs to it). A
/// drag that starts on a dot lays that colour's pipe from scratch; one that
/// starts partway along a pipe carries on from there. Coming back over the
/// pipe rubs it out to the finger.
///
/// Drawing across another colour's pipe cuts it, the way every Flow game
/// does — and only for as long as the finger is in the way. The other pipes
/// are re-cut from where they were when the stroke began on every step, so
/// backing off a pipe you crossed by accident puts it straight back.
///
/// A dot of another colour is a wall, refused rather than cut: there is no
/// version of the board where a pipe runs through a different colour's dot,
/// and letting the line in only to throw it out reads as the drag breaking.
///
/// No mistakes are counted, for the same reason Zip counts none: the board
/// refuses an illegal step as it happens, so there is no wrong state to settle
/// on.
class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key, required this.userId});

  final String userId;

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.flow,
    userId: widget.userId,
  );

  late final AnimationController _winSweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// One pipe per colour, in the order it was drawn (from whichever of its
  /// dots the player started at).
  List<List<int>> _pipes = const [];

  /// The colour being drawn, and every pipe as it was when the stroke began.
  int? _active;
  List<List<int>>? _before;
  bool _refused = false;

  /// One entry per stroke: the whole board before it.
  final List<List<List<int>>> _undo = [];

  /// The hint on show, until the player's next move or a tap on its banner.
  BoardHint? _spot;
  int _hintSerial = 0;

  FlowBoard get _board => GamesStore.instance.boards.flow;

  @override
  void initState() {
    super.initState();
    _play.addListener(_onPlay);
    _play.snapshot = () => _encode(_board, _pipes);
    GamesStore.instance.addListener(_onPlay);
    _boot();
  }

  Future<void> _boot() async {
    await GamesStore.instance.load(widget.userId);
    if (!mounted) return;
    await _play.begin();
    if (!mounted) return;
    setState(_restore);
    if (!_play.finished) _maybeFinish();
  }

  /// Rebuilds the pipes from the save. A solved board's save is its
  /// submission — the pipes end to end — and an unfinished one is
  /// [_encode]'s per-square form. Both are one entry per square, so they are
  /// told apart by the result.
  void _restore() {
    final board = _board;
    final n = board.size;
    if (n == 0) return;
    _pipes = [for (final _ in board.endpoints) <int>[]];
    final saved = _play.restored;
    if (saved.length != n * n) return;
    if (_play.finished && _play.solved) {
      _pipes = flowPipesOf(board, saved);
      _winSweep.value = 1;
      return;
    }
    _pipes = _decode(board, saved);
  }

  /// The autosave. One entry per square: `colour * 64 + place along its pipe`,
  /// or -1. Not the submission's shape, because a half-drawn board is not a
  /// list of finished pipes, and not a pipe-by-pipe list with lengths either,
  /// because that runs longer than the board and the server caps a save at
  /// one entry per square. Position and colour together are enough to put
  /// every pipe back exactly as drawn, start and all.
  static List<int> _encode(FlowBoard board, List<List<int>> pipes) {
    final out = List<int>.filled(board.size * board.size, -1);
    for (var k = 0; k < pipes.length; k++) {
      for (var p = 0; p < pipes[k].length; p++) {
        out[pipes[k][p]] = k * 64 + p;
      }
    }
    return out;
  }

  /// The inverse of [_encode]. Each pipe is re-walked through the same rules
  /// a finger is held to, and stops at the first step that breaks one — a
  /// stale save on a changed board then comes back short, never illegal.
  static List<List<int>> _decode(FlowBoard board, List<int> saved) {
    final colours = board.endpoints.length;
    final byColour = [for (var k = 0; k < colours; k++) <(int, int)>[]];
    for (var cell = 0; cell < saved.length; cell++) {
      final v = saved[cell];
      if (v < 0) continue;
      final k = v ~/ 64;
      if (k < colours) byColour[k].add((v % 64, cell));
    }
    final out = <List<int>>[];
    for (var k = 0; k < colours; k++) {
      final steps = byColour[k]..sort((a, b) => a.$1.compareTo(b.$1));
      final pipe = <int>[];
      for (final (_, cell) in steps) {
        final ok = pipe.isEmpty
            ? board.dotAt(cell) == k
            : gridAdjacent(pipe.last, cell, board.size) &&
                  !pipe.contains(cell) &&
                  (board.dotAt(cell) < 0 || board.dotAt(cell) == k) &&
                  !_complete(board, k, pipe);
        if (!ok) break;
        pipe.add(cell);
      }
      out.add(pipe);
    }
    return out;
  }

  static bool _complete(FlowBoard board, int k, List<int> pipe) =>
      pipe.length > 1 && board.dotAt(pipe.last) == k;

  void _onPlay() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _play
      ..checkpoint(_encode(_board, _pipes))
      ..removeListener(_onPlay)
      ..dispose();
    GamesStore.instance.removeListener(_onPlay);
    _winSweep.dispose();
    super.dispose();
  }

  bool get _playable =>
      _play.ready && !_play.finished && !_play.paused && !_play.busy;

  List<List<int>> _copy(List<List<int>> pipes) => [
    for (final p in pipes) List<int>.of(p),
  ];

  void _dragStart() {
    if (_spot != null) setState(() => _spot = null);
    _active = null;
    _before = null;
    _refused = false;
  }

  void _dragTo(int cell) {
    if (!_playable) return;
    final board = _board;
    final active = _active;

    if (active == null) {
      // The first square of the stroke decides which pipe it is.
      final dot = board.dotAt(cell);
      var k = dot;
      if (k < 0) {
        for (var j = 0; j < _pipes.length; j++) {
          if (_pipes[j].contains(cell)) k = j;
        }
      }
      if (k < 0) return;
      _before = _copy(_pipes);
      _active = k;
      setState(() {
        if (dot >= 0) {
          // From a dot: this colour starts again from here.
          _pipes[k] = [cell];
        } else {
          // From partway along: everything past this square goes.
          _pipes[k] = _pipes[k].sublist(0, _pipes[k].indexOf(cell) + 1);
        }
      });
      HapticFeedback.selectionClick();
      return;
    }

    final pipe = _pipes[active];
    if (pipe.isEmpty || cell == pipe.last) return;

    // Retracting over its own trail.
    final back = pipe.indexOf(cell);
    if (back >= 0) {
      setState(() {
        _pipes[active] = pipe.sublist(0, back + 1);
        _recut();
      });
      HapticFeedback.selectionClick();
      return;
    }

    final dot = board.dotAt(cell);
    final blocked =
        !gridAdjacent(pipe.last, cell, board.size) ||
        _complete(board, active, pipe) ||
        (dot >= 0 && dot != active);
    if (blocked) {
      if (!_refused) {
        _refused = true;
        HapticFeedback.lightImpact();
      }
      return;
    }
    _refused = false;
    setState(() {
      _pipes[active] = [...pipe, cell];
      _recut();
    });
    if (dot == active) {
      // A pipe just closed: a firmer tick than a step, so a player who drew it
      // without looking still feels it land.
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// Every other pipe as it was when the stroke began, cut back to just short
  /// of the first square the active pipe now covers.
  void _recut() {
    final before = _before;
    final active = _active;
    if (before == null || active == null) return;
    final taken = _pipes[active].toSet();
    for (var k = 0; k < before.length; k++) {
      if (k == active) continue;
      final was = before[k];
      var keep = was.length;
      for (var i = 0; i < was.length; i++) {
        if (taken.contains(was[i])) {
          keep = i;
          break;
        }
      }
      _pipes[k] = was.sublist(0, keep);
    }
  }

  void _dragEnd() {
    final before = _before;
    _active = null;
    _before = null;
    _refused = false;
    if (before == null) return;
    _undo.add(before);
    setState(() {});
    _maybeFinish();
  }

  /// A tap on a dot clears that colour's pipe; a tap anywhere else is a
  /// one-square stroke, which does nothing a player would notice.
  void _tap(int cell) {
    if (!_playable) return;
    final k = _board.dotAt(cell);
    if (k < 0 || _pipes[k].length < 2) return;
    setState(() {
      _undo.add(_copy(_pipes));
      _pipes[k] = [];
      _spot = null;
    });
    HapticFeedback.selectionClick();
  }

  void _undoLast() {
    if (_undo.isEmpty || _play.finished) return;
    setState(() {
      _pipes = _undo.removeLast();
      _spot = null;
    });
    HapticFeedback.selectionClick();
  }

  void _clear() {
    if (_play.finished) return;
    setState(() {
      _undo.add(_copy(_pipes));
      _pipes = [for (final _ in _board.endpoints) <int>[]];
      _spot = null;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _hint() async {
    final board = _board;
    // The pipes laid end to end, each turned to run from its first dot, which
    // is the order the server reads "already right" in.
    final current = <int>[
      for (var k = 0; k < _pipes.length; k++)
        ...(_pipes[k].isNotEmpty && _pipes[k].first == board.endpoints[k].$2
            ? _pipes[k].reversed
            : _pipes[k]),
    ];
    final hint = await _play.hint(current);
    if (hint == null || !mounted || hint.cells.isEmpty) return;
    final k = hint.index;
    if (k < 0 || k >= _pipes.length) return;
    setState(() {
      _undo.clear();
      final taken = hint.cells.toSet();
      for (var j = 0; j < _pipes.length; j++) {
        if (j == k) continue;
        final cut = _pipes[j].indexWhere(taken.contains);
        if (cut >= 0) _pipes[j] = _pipes[j].sublist(0, cut);
      }
      _pipes[k] = List<int>.of(hint.cells);
      // The pipe itself is lit; no square in it needs a ring.
      _spot = BoardHint(
        hint: hint,
        serial: ++_hintSerial,
        target: const {},
        area: hint.cells.toSet(),
      );
    });
    HapticFeedback.mediumImpact();
    _maybeFinish();
  }

  Future<void> _giveUp() async {
    if (!await confirmGiveUp(context)) return;
    final answer = await _play.reveal();
    if (answer == null || !mounted) return;
    setState(() {
      _pipes = flowPipesOf(_board, answer);
      _spot = null;
    });
  }

  Future<void> _maybeFinish() async {
    final solution = flowSolution(_board, _pipes);
    if (solution == null) return;
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(solution);
    if (ok && mounted) _winSweep.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = _board;
    final drawn = _pipes.any((p) => p.length > 1);

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      onUndo: _undo.isEmpty ? null : _undoLast,
      title: l10n.gameFlowName,
      rule: l10n.gameFlowRule,
      hintBanner: HintBanner(
        hint: _play.paused ? null : _spot,
        onDismiss: () => setState(() => _spot = null),
      ),
      board: HintSpotlight(
        hint: _play.paused || _play.finished ? null : _spot,
        n: board.size,
        child: AnimatedBuilder(
          animation: _winSweep,
          builder: (context, _) => GameBoardSurface(
            n: board.size,
            onDragStart: _dragStart,
            onDragTo: _dragTo,
            onDragEnd: _dragEnd,
            claimsDrag: _play.ready && !_play.finished && !_play.paused,
            onTapCell: _tap,
            painter: FlowBoardPainter(
              board: board,
              theme: theme,
              palette: GamePalette(theme),
              // A fresh outer list per build: the pipes are edited in place, and
              // the painter decides whether to repaint by identity.
              pipes: _play.paused ? const [] : [..._pipes],
              active: _active,
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
          icon: CupertinoIcons.trash,
          label: l10n.gameClear,
          onTap: drawn ? _clear : null,
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
              name: l10n.gameFlowName,
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
