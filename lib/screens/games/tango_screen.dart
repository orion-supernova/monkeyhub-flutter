import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/tango_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// TANGO — three suns and three moons in every row and column, never three of
/// one in a row, and every `=` and `×` respected.
///
/// A tap cycles a square through empty → sun → moon. Printed squares do not
/// move; they are drawn on a raised surface rather than a sunken one so that is
/// visible before anyone taps one and finds out.
class TangoScreen extends StatefulWidget {
  const TangoScreen({super.key, required this.userId});

  final String userId;

  @override
  State<TangoScreen> createState() => _TangoScreenState();
}

class _TangoScreenState extends State<TangoScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.tango,
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
  final List<(int, int)> _undo = [];
  int? _popCell;

  /// Whether a contradiction has already been counted against this square.
  ///
  /// Without it a row that breaks the three-in-a-row rule tallies a fresh
  /// mistake on every rebuild it survives, and the result card ends up
  /// reporting forty mistakes for one bad guess.
  final Set<int> _counted = {};

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
    final board = GamesStore.instance.boards.tango;
    final total = board.size * board.size;
    if (total == 0) return;
    _cells = List<int>.filled(total, tangoEmpty);
    final saved = _play.restored;
    if (saved.length == total) {
      for (var i = 0; i < total; i++) {
        // A printed square is never taken from the save. If the board ever
        // changed under a stale autosave, the printed grid is the truth.
        _cells[i] = board.givens[i] != tangoEmpty ? tangoEmpty : saved[i];
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

  void _tap(int index) {
    if (!_play.ready || _play.finished || _play.paused || _play.busy) return;
    final board = GamesStore.instance.boards.tango;
    if (board.givens[index] != tangoEmpty) {
      HapticFeedback.lightImpact();
      return;
    }
    final before = _cells[index];
    final next = switch (before) {
      tangoEmpty => tangoSun,
      tangoSun => tangoMoon,
      _ => tangoEmpty,
    };
    setState(() {
      _undo.add((index, before));
      _cells[index] = next;
      _popCell = index;
      _counted.remove(index);
    });
    _pop.forward(from: 0);
    HapticFeedback.selectionClick();

    if (tangoTrouble(board, _cells).cells.contains(index) &&
        _counted.add(index)) {
      _play.noteMistake();
      HapticFeedback.heavyImpact();
      return;
    }
    _maybeFinish();
  }

  void _undoLast() {
    if (_undo.isEmpty || _play.finished) return;
    final (index, value) = _undo.removeLast();
    setState(() {
      _cells[index] = value;
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
    setState(() => _cells = answer);
  }

  Future<void> _maybeFinish() async {
    final board = GamesStore.instance.boards.tango;
    // The printed squares are folded in for the check: they are part of the
    // finished grid even though the player never touched them.
    final full = [
      for (var i = 0; i < _cells.length; i++)
        board.givens[i] != tangoEmpty ? board.givens[i] : _cells[i],
    ];
    if (!tangoSolved(board, full)) return;
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(full);
    if (ok && mounted) _winSweep.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = GamesStore.instance.boards.tango;

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gameTangoName,
      rule: l10n.gameTangoRule,
      board: AnimatedBuilder(
        animation: Listenable.merge([_pop, _winSweep]),
        builder: (context, _) => GameBoardSurface(
          onTapCell: _tap,
          n: board.size,
          painter: TangoBoardPainter(
            board: board,
            theme: theme,
            cells: _play.paused ? const [] : _cells,
            trouble: _play.paused
                ? const TangoTrouble(cells: <int>{}, signs: <int>{})
                : tangoTrouble(board, _cells),
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
              name: l10n.gameTangoName,
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
