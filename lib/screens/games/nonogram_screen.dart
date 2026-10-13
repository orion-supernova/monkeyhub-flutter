import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/games_api.dart';
import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/hint_spotlight.dart';
import '../../games/nonogram_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// NONOGRAM — shade the squares of a 10×10 grid so that every row and column
/// reads back the run lengths printed beside it, and a picture comes out.
///
/// A tap cycles a square through unknown → shaded → crossed → unknown. A drag
/// paints: the first square cycles as a tap would, and every square the finger
/// then crosses that was in the same state the first one started in takes the
/// same new state. That is how a run of seven gets shaded in one stroke rather
/// than seven taps, and it is the gesture every phone nonogram has taught
/// people to expect.
///
/// Because a cross is reached *through* a shade, the squares just changed are
/// not judged until the player has moved on from them — the settle rule Tango
/// uses (see [_pending]). And what is judged is a fact, not a guess: the board
/// never knows the picture, only whether a line can still be completed, so a
/// mistake is a move that leaves some row or column with no arrangement of its
/// clue that fits.
class NonogramScreen extends StatefulWidget {
  const NonogramScreen({super.key, required this.userId});

  final String userId;

  @override
  State<NonogramScreen> createState() => _NonogramScreenState();
}

class _NonogramScreenState extends State<NonogramScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.nonogram,
    userId: widget.userId,
  );

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final AnimationController _winSweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  List<int> _cells = const [];

  /// One entry per gesture — a tap, or a whole drag — so undo takes back what
  /// the player did in one motion rather than one square of a stroke.
  final List<List<(int, int)>> _undo = [];

  int? _popCell;

  /// The hint on show, until the player's next move or a tap on its banner.
  BoardHint? _spot;
  int _hintSerial = 0;
  int? _focus;

  /// The squares the player has just changed and not yet moved on from.
  ///
  /// Shading a square and then tapping it again to cross it passes through a
  /// shade the player never meant to keep; a row that shade briefly broke must
  /// not cost a mistake. So a gesture's squares are judged together, once: when
  /// the player touches a square outside them, or after [_settleAfter] with no
  /// further touch. Until then they are drawn but left out of the check.
  final Set<int> _pending = {};
  Timer? _settle;

  static const _settleAfter = Duration(milliseconds: 900);

  /// The drag in progress: the state its first square started in, and the
  /// state it is painting.
  int? _dragFrom;
  int? _dragPaint;
  List<(int, int)>? _stroke;

  NonogramBoard get _board => GamesStore.instance.boards.nonogram;

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
    if (!_play.finished) _maybeFinish();
  }

  /// Rebuilds the grid from the save: the working grid (1 / 0 / -1) while in
  /// progress, the 0/1 submission once solved. A solved board shows its
  /// picture alone, without a cross on every blank square.
  void _restore() {
    final n = _board.size;
    if (n == 0) return;
    _cells = List<int>.filled(n * n, nonogramUnknown);
    final saved = _play.restored;
    if (saved.length == n * n) {
      final submitted = _play.finished && _play.solved;
      for (var i = 0; i < saved.length; i++) {
        final v = saved[i];
        _cells[i] = submitted
            ? (v == 1 ? nonogramFilled : nonogramUnknown)
            : (v == nonogramFilled || v == nonogramCrossed
                  ? v
                  : nonogramUnknown);
      }
    }
    if (_play.finished && _play.solved) _winSweep.value = 1;
  }

  void _onPlay() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settle?.cancel();
    _play.removeListener(_onPlay);
    // The squares left pending on the way out were the player's last word.
    _judge(rebuild: false);
    _play
      ..checkpoint(_cells)
      ..dispose();
    GamesStore.instance.removeListener(_onPlay);
    _pop.dispose();
    _winSweep.dispose();
    super.dispose();
  }

  bool get _playable =>
      _play.ready && !_play.finished && !_play.paused && !_play.busy;

  static int _cycle(int v) => switch (v) {
    nonogramUnknown => nonogramFilled,
    nonogramFilled => nonogramCrossed,
    _ => nonogramUnknown,
  };

  void _dragStart() {
    _dragFrom = null;
    _dragPaint = null;
    _stroke = [];
  }

  void _dragTo(int index) {
    if (!_playable) return;
    final stroke = _stroke ??= [];
    if (_dragFrom == null) {
      // The first square of the gesture. Touching it again (a second tap on
      // the same square) keeps the pending group open; touching anything else
      // settles the one before.
      if (!_pending.contains(index)) _judge();
      final before = _cells[index];
      _dragFrom = before;
      _dragPaint = _cycle(before);
      _set(index, _dragPaint!, stroke);
      HapticFeedback.selectionClick();
      return;
    }
    if (stroke.any((e) => e.$1 == index)) return;
    if (_cells[index] != _dragFrom) return;
    _set(index, _dragPaint!, stroke);
    HapticFeedback.selectionClick();
  }

  void _set(int index, int value, List<(int, int)> stroke) {
    setState(() {
      stroke.add((index, _cells[index]));
      _cells[index] = value;
      _popCell = index;
      _focus = index;
      _pending.add(index);
      _spot = null;
    });
    _pop.forward(from: 0);
  }

  void _dragEnd() {
    final stroke = _stroke;
    _stroke = null;
    _dragFrom = null;
    _dragPaint = null;
    if (stroke == null || stroke.isEmpty) return;
    _undo.add(stroke);
    _settle?.cancel();
    _settle = Timer(_settleAfter, _judge);
    _maybeFinish();
  }

  void _tap(int index) {
    _dragStart();
    _dragTo(index);
    _dragEnd();
  }

  /// Settles the pending squares: if they leave a line with no arrangement of
  /// its clue that fits — one that DID fit without them — that is one
  /// mistake, however many squares the stroke covered.
  void _judge({bool rebuild = true}) {
    _settle?.cancel();
    _settle = null;
    if (_pending.isEmpty) return;
    final group = Set<int>.of(_pending);
    _pending.clear();
    if (_play.finished) return;
    final board = _board;
    final n = board.size;
    final without = List<int>.of(_cells);
    for (final i in group) {
      without[i] = nonogramUnknown;
    }
    final before = nonogramTrouble(board, without);
    final after = nonogramTrouble(board, _cells);
    final broke = group.any(
      (i) =>
          (after.rows.contains(i ~/ n) && !before.rows.contains(i ~/ n)) ||
          (after.cols.contains(i % n) && !before.cols.contains(i % n)),
    );
    if (broke) {
      _play.noteMistake();
      HapticFeedback.heavyImpact();
    }
    if (rebuild && mounted) setState(() {});
  }

  void _forgetPending() {
    _settle?.cancel();
    _settle = null;
    _pending.clear();
  }

  /// The grid as the board judges it: pending squares read as unknown, so a
  /// stroke still in hand is drawn without its line flashing red.
  List<int> get _settled {
    if (_pending.isEmpty) return _cells;
    final out = List<int>.of(_cells);
    for (final i in _pending) {
      out[i] = nonogramUnknown;
    }
    return out;
  }

  void _undoLast() {
    if (_undo.isEmpty || _play.finished) return;
    final stroke = _undo.removeLast();
    _forgetPending();
    setState(() {
      for (final (index, before) in stroke.reversed) {
        _cells[index] = before;
      }
      _popCell = null;
      _spot = null;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _hint() async {
    _judge();
    final hint = await _play.hint(_cells);
    if (hint == null || !mounted) return;
    _forgetPending();
    final cell = hint.cell ?? hint.index;
    if (cell < 0 || cell >= _cells.length) return;
    setState(() {
      _focus = cell;
      _undo.clear();
      if (hint.kind == GameHintKind.wrong) {
        // Back to undecided; the ring and the banner say why.
        _cells[cell] = nonogramUnknown;
        _popCell = null;
      } else {
        final value = hint.answer ?? hint.value;
        _cells[cell] = value == 1 ? nonogramFilled : nonogramCrossed;
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
    _forgetPending();
    setState(() {
      _cells = [
        for (final v in answer) v == 1 ? nonogramFilled : nonogramUnknown,
      ];
      _focus = null;
      _spot = null;
    });
  }

  /// Submits the moment every line reads back its clue. Crossed and untouched
  /// squares both count as blank, exactly as the server reads them.
  Future<void> _maybeFinish() async {
    if (!nonogramSolved(_board, _cells)) return;
    _forgetPending();
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(nonogramSolution(_cells));
    if (ok && mounted) {
      setState(() {
        _focus = null;
        // The finished picture, without the working.
        _cells = [
          for (final v in _cells)
            v == nonogramFilled ? nonogramFilled : nonogramUnknown,
        ];
      });
      _winSweep.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = _board;
    final paused = _play.paused;
    final settled = _settled;
    final done = paused
        ? (rows: <int>{}, cols: <int>{})
        : nonogramSatisfied(board, _cells);
    final lead = nonogramLeadFraction(board);

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gameNonogramName,
      rule: l10n.gameNonogramRule,
      hintBanner: HintBanner(
        hint: _play.paused ? null : _spot,
        onDismiss: () => setState(() => _spot = null),
      ),
      board: HintSpotlight(
        hint: _play.paused || _play.finished ? null : _spot,
        n: board.size,
        leadFraction: lead,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pop, _winSweep]),
          builder: (context, _) => GameBoardSurface(
            n: board.size,
            leadFraction: lead,
            onTapCell: _tap,
            onDragStart: _dragStart,
            onDragTo: _dragTo,
            onDragEnd: _dragEnd,
            // A stroke that starts on the grid is the grid's, or the page wins
            // every downward run before it has shaded a square.
            claimsDrag: _play.ready && !_play.finished && !paused,
            painter: NonogramBoardPainter(
              board: board,
              theme: theme,
              cells: paused ? const [] : _cells,
              trouble: paused
                  ? const NonogramTrouble(rows: {}, cols: {})
                  : nonogramTrouble(board, settled),
              satisfiedRows: done.rows,
              satisfiedCols: done.cols,
              focus: paused ? null : _focus,
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
              name: l10n.gameNonogramName,
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
