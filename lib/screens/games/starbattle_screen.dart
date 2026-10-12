import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/starbattle_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// STAR BATTLE — two stars in every row, column and colour region of a 10×10
/// board, and no two stars touching, not even at a corner.
///
/// Plays exactly like Queens: a tap cycles a square through nothing → dot →
/// star, and the board dots out what a placed star rules out, faintly. The
/// difference is the count, which is where the difficulty lives — "this region
/// is two rows tall, so those rows are spoken for" is a counting argument over
/// groups, and that is the deduction this board is for.
///
/// Because a star is reached *through* a dot, and is one tap from being taken
/// back, a square is only judged once the player has settled on it — the same
/// rule as Tango's (see [_pending]).
class StarBattleScreen extends StatefulWidget {
  const StarBattleScreen({super.key, required this.userId});

  final String userId;

  @override
  State<StarBattleScreen> createState() => _StarBattleScreenState();
}

class _StarBattleScreenState extends State<StarBattleScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.starbattle,
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

  List<StarMark> _marks = const [];
  final List<(int, StarMark)> _undo = [];
  int? _popCell;

  /// Whether the board dots out squares a placed star rules out. On by
  /// default, for the reason Queens' auto-cross is.
  bool _autoDot = true;

  /// Stars already counted as a mistake, so a clash that survives several
  /// rebuilds is one mistake rather than one per frame.
  final Set<int> _counted = {};

  /// The square the player is still cycling, if any.
  ///
  /// A star lands one tap after a dot and leaves one tap after that, so a
  /// player tapping through a square on the way to "empty" passes over a star
  /// they never meant to place. Judging it there would charge them a mistake
  /// for nothing and flash the board red under their finger. The square is
  /// judged when they tap a different one, or after [_settleAfter] with no
  /// further tap on it.
  int? _pending;
  Timer? _settle;

  static const _settleAfter = Duration(milliseconds: 900);

  StarBattleBoard get _board => GamesStore.instance.boards.starbattle;

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
    // A board left solved but never submitted goes in now; waiting for a tap
    // would be waiting for the one move that unsolves it.
    if (!_play.finished) _maybeFinish();
  }

  /// Rebuilds the board from whatever was saved. The save is the player's
  /// marks (0 none, 1 dot, 2 star) while in progress, and the 0/1 submission
  /// once solved — `submit` replaces the autosave with the finished grid. Both
  /// are one entry per square, so they are told apart by the result rather
  /// than by length; a surrender leaves the last autosave in place.
  void _restore() {
    final n = _board.size;
    if (n == 0) return;
    _marks = List<StarMark>.filled(n * n, StarMark.none);
    final saved = _play.restored;
    if (saved.length == n * n) {
      final submitted = _play.finished && _play.solved;
      for (var i = 0; i < saved.length; i++) {
        _marks[i] = submitted
            ? (saved[i] == 1 ? StarMark.star : StarMark.none)
            : StarMark.values[saved[i].clamp(0, 2)];
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
    // A square left mid-cycle was the player's last word on it.
    _judge(_pending, rebuild: false);
    _play
      ..checkpoint([for (final m in _marks) m.index])
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
      StarMark.none => StarMark.dot,
      StarMark.dot => StarMark.star,
      StarMark.star => StarMark.none,
    };
    if (_pending != index) _judge(_pending);
    setState(() {
      _undo.add((index, before));
      _marks[index] = next;
      _popCell = index;
      _counted.remove(index);
      _pending = next == StarMark.star ? index : null;
    });
    _pop.forward(from: 0);
    HapticFeedback.selectionClick();
    _settle?.cancel();
    if (_pending != null) _settle = Timer(_settleAfter, () => _judge(index));
    _maybeFinish();
  }

  /// Settles [index]: a star that breaks a rule is one mistake, counted once.
  void _judge(int? index, {bool rebuild = true}) {
    if (index == null || index != _pending) return;
    _settle?.cancel();
    _settle = null;
    _pending = null;
    if (_play.finished) return;
    if (_marks[index] == StarMark.star &&
        starBattleConflicts(_board, _marks).contains(index) &&
        _counted.add(index)) {
      _play.noteMistake();
      HapticFeedback.heavyImpact();
    }
    if (rebuild && mounted) setState(() {});
  }

  void _forgetPending() {
    _settle?.cancel();
    _settle = null;
    _pending = null;
  }

  /// The marks as the board judges them: a star still being cycled is left
  /// out of the conflict check, so it is drawn without flashing red.
  Set<int> _visibleConflicts() {
    final pending = _pending;
    if (pending == null) return starBattleConflicts(_board, _marks);
    final settled = List<StarMark>.of(_marks)..[pending] = StarMark.none;
    return starBattleConflicts(_board, settled);
  }

  void _undoLast() {
    if (_undo.isEmpty || _play.finished) return;
    final (index, mark) = _undo.removeLast();
    _forgetPending();
    setState(() {
      _marks[index] = mark;
      _popCell = null;
      _counted.remove(index);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _hint() async {
    _judge(_pending);
    final hint = await _play.hint(starBattleSolution(_marks));
    if (hint == null || !mounted) return;
    _forgetPending();
    setState(() {
      // Value 0 takes a wrong star away and leaves a dot in its place — the
      // player's own note that there is no star there; 1 puts a missing one
      // down.
      _marks[hint.index] = hint.value == 1 ? StarMark.star : StarMark.dot;
      _popCell = hint.index;
      _counted.remove(hint.index);
      _undo.clear();
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
      _marks = [
        for (final v in answer) v == 1 ? StarMark.star : StarMark.none,
      ];
    });
  }

  /// Submits the moment the board is complete and legal, like Queens: on a
  /// board whose rules are all visible a legal full grid IS the answer.
  Future<void> _maybeFinish() async {
    if (!starBattleSolved(_board, _marks)) return;
    _forgetPending();
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(starBattleSolution(_marks));
    if (ok && mounted) _winSweep.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = _board;

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gameStarbattleName,
      rule: l10n.gameStarbattleRule,
      board: AnimatedBuilder(
        animation: Listenable.merge([_pop, _winSweep]),
        builder: (context, _) => GameBoardSurface(
          onTapCell: _tap,
          n: board.size,
          painter: StarBattleBoardPainter(
            board: board,
            theme: theme,
            palette: GamePalette(theme),
            marks: _play.paused ? const [] : _marks,
            conflicts: _play.paused ? const {} : _visibleConflicts(),
            autoBlocked: _autoDot && !_play.paused
                ? starBattleBlocked(board, _marks)
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
          icon: CupertinoIcons.circle_grid_3x3,
          label: l10n.gameAutoDot,
          selected: _autoDot,
          onTap: () => setState(() => _autoDot = !_autoDot),
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
              name: l10n.gameStarbattleName,
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
