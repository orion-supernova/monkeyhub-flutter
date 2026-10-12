import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/feed_store.dart';
import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/minesweeper_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// MINESWEEPER — open every square that is not a mine, on a field where every
/// square can be worked out from the opening without a single guess.
///
/// The opening square is opened for the player before they touch anything.
/// The board is the same for everyone that day, so there is no free first
/// click to give (the desktop game places its mines after the click); the
/// server ships a square it promises is a 0 instead, and starting the player
/// on it is the same courtesy.
///
/// **A mine is a mistake, not a loss.** The square shows its mine, 30 seconds
/// go on the clock ([kMinePenalty]), and the board carries on. On a no-guess
/// field a mine is always a misread number, and ending a daily on one would
/// make a single slip worth more than ten minutes of clean deduction on a
/// leaderboard that is meant to rank the deduction.
///
/// A tap opens; a long press, or a tap with Flag switched on, plants or lifts a
/// flag. Tapping an opened number whose flags are all placed opens the rest of
/// its neighbours — the "chord" every fast player relies on.
class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key, required this.userId});

  final String userId;

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.minesweeper,
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

  /// Drives the "+0:30" that rises off the board when a mine is hit, so the
  /// cost is seen where it happened rather than discovered on the clock.
  late final AnimationController _penalty = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  List<int> _cells = const [];
  List<int> _mines = const [];
  List<int> _numbers = const [];
  int? _popCell;

  /// Whether a tap plants a flag instead of opening a square.
  bool _flagging = false;

  /// Whether to draw every mine — once the board is over, either way.
  bool _showMines = false;

  MinesweeperBoard get _board => GamesStore.instance.boards.minesweeper;

  /// The day the board belongs to, which seeds the mask its mines ship in.
  /// The payload's own, so a board fetched just before midnight still decodes
  /// with the key it was encoded with.
  String get _dayKey {
    final day = GamesStore.instance.boards.dayKey;
    return day.isNotEmpty ? day : FeedStore.instance.dayKey;
  }

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

  void _restore() {
    final board = _board;
    final n = board.size;
    if (n == 0) return;
    _mines = minesweeperMines(board, _dayKey);
    _numbers = minesweeperNumbers(_mines, n);
    _cells = List<int>.filled(n * n, minesweeperHidden);
    final saved = _play.restored;
    if (_play.finished && _play.solved) {
      // A solved board's save is the mine map it was submitted with: open
      // everything else and flag the mines.
      for (var i = 0; i < _cells.length; i++) {
        _cells[i] = _mines[i] == 1 ? minesweeperFlagged : _numbers[i];
      }
      _winSweep.value = 1;
      return;
    }
    if (saved.length == n * n) {
      for (var i = 0; i < saved.length; i++) {
        final v = saved[i];
        // Never trusted past the layout: a "revealed" square is re-read off
        // the real numbers, and one that is a mine was a hit.
        if (v >= 0 && v <= 8) {
          _cells[i] = _mines[i] == 1 ? minesweeperStruck : _numbers[i];
        } else if (v == minesweeperFlagged || v == minesweeperStruck) {
          _cells[i] = v;
        }
      }
    }
    if (_play.finished) {
      _showMines = true;
      return;
    }
    if (!_cells.any((v) => v >= 0 && v <= 8)) {
      for (final i in minesweeperFlood(_cells, _mines, _numbers, n, board.start)) {
        _cells[i] = _numbers[i];
      }
    }
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
    _penalty.dispose();
    super.dispose();
  }

  bool get _playable =>
      _play.ready && !_play.finished && !_play.paused && !_play.busy;

  void _tap(int index) {
    if (!_playable) return;
    if (_flagging) {
      _toggleFlag(index);
      return;
    }
    final v = _cells[index];
    if (v == minesweeperFlagged) {
      // A flag is the player's word; a tap does not overrule it.
      HapticFeedback.lightImpact();
      return;
    }
    if (v >= 1 && v <= 8) {
      _chord(index);
      return;
    }
    if (v != minesweeperHidden) return;
    _open([index]);
  }

  void _longPress(int index) {
    if (!_playable) return;
    _toggleFlag(index);
  }

  void _toggleFlag(int index) {
    final v = _cells[index];
    if (v != minesweeperHidden && v != minesweeperFlagged) return;
    setState(() {
      _cells[index] = v == minesweeperFlagged
          ? minesweeperHidden
          : minesweeperFlagged;
      _popCell = index;
    });
    _pop.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  /// Opens the hidden, unflagged neighbours of a number whose flags are all
  /// down. With a wrong flag among them this walks onto a mine, which is
  /// exactly the risk the player took by flagging it.
  void _chord(int index) {
    final n = _board.size;
    final around = minesweeperNeighbours(index, n);
    final flags = around
        .where(
          (j) =>
              _cells[j] == minesweeperFlagged || _cells[j] == minesweeperStruck,
        )
        .length;
    if (flags != _cells[index]) return;
    final targets = [
      for (final j in around)
        if (_cells[j] == minesweeperHidden) j,
    ];
    if (targets.isEmpty) return;
    _open(targets);
  }

  void _open(List<int> squares) {
    final n = _board.size;
    var struck = 0;
    setState(() {
      for (final i in squares) {
        if (_cells[i] != minesweeperHidden) continue;
        if (_mines[i] == 1) {
          _cells[i] = minesweeperStruck;
          struck++;
          continue;
        }
        for (final j in minesweeperFlood(_cells, _mines, _numbers, n, i)) {
          _cells[j] = _numbers[j];
        }
      }
      _popCell = squares.length == 1 ? squares.first : null;
    });
    _pop.forward(from: 0);
    if (struck > 0) {
      for (var k = 0; k < struck; k++) {
        _play
          ..noteMistake()
          ..addPenalty(kMinePenalty);
      }
      _penalty.forward(from: 0);
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    _maybeFinish();
  }

  Future<void> _hint() async {
    // A mine the player walked onto is, for the hint's purposes, a mine they
    // know about: sent as a flag, so the server does not spend a hint telling
    // them to flag it.
    final board = [
      for (final v in _cells) v == minesweeperStruck ? minesweeperFlagged : v,
    ];
    final hint = await _play.hint(board);
    if (hint == null || !mounted) return;
    if (hint.value == 1) {
      setState(() {
        _cells[hint.index] = minesweeperFlagged;
        _popCell = hint.index;
      });
      _pop.forward(from: 0);
      return;
    }
    if (_cells[hint.index] == minesweeperFlagged) {
      // A wrong flag, which the hint is pointing at precisely so it comes off.
      _cells[hint.index] = minesweeperHidden;
    }
    _open([hint.index]);
  }

  Future<void> _giveUp() async {
    if (!await confirmGiveUp(context)) return;
    final answer = await _play.reveal();
    if (answer == null || !mounted) return;
    setState(() {
      if (answer.length == _mines.length) _mines = answer;
      _showMines = true;
    });
  }

  Future<void> _maybeFinish() async {
    if (_mines.isEmpty || !minesweeperCleared(_cells, _mines)) return;
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(List<int>.of(_mines));
    if (!mounted) return;
    if (ok) {
      setState(() {
        // The last mines flag themselves: once every safe square is open there
        // is nothing left they could be.
        for (var i = 0; i < _cells.length; i++) {
          if (_mines[i] == 1 && _cells[i] == minesweeperHidden) {
            _cells[i] = minesweeperFlagged;
          }
        }
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
    final motion = MotionScope.of(context);

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gameMinesweeperName,
      rule: l10n.gameMinesweeperRule,
      board: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_pop, _winSweep]),
            builder: (context, _) => GameBoardSurface(
              n: board.size,
              onTapCell: _tap,
              onLongPressCell: _longPress,
              painter: MinesweeperBoardPainter(
                board: board,
                theme: theme,
                cells: paused
                    ? List<int>.filled(
                        board.size * board.size,
                        minesweeperHidden,
                      )
                    : _cells,
                mines: _mines,
                showMines: _showMines && !paused,
                popCell: _popCell,
                pop: _pop.value,
                win: _winSweep.value,
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _penalty,
              builder: (context, child) {
                final t = _penalty.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                // Calm motion keeps the chip in place and only fades it.
                final rise = motion.calm ? 0.0 : Curves.easeOutCubic.transform(t);
                final fade = t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85);
                return Align(
                  alignment: Alignment(0, -0.2 - 0.5 * rise),
                  child: Opacity(opacity: fade.clamp(0.0, 1.0), child: child),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: theme.danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${formatGameTime(kMinePenalty.inMilliseconds)}',
                  style: theme.body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.background,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      tools: [
        GameTool(
          icon: CupertinoIcons.flag_fill,
          label: l10n.gameFlag,
          selected: _flagging,
          onTap: () => setState(() => _flagging = !_flagging),
        ),
        GameTool(
          icon: CupertinoIcons.lightbulb,
          label: l10n.gameHint,
          onTap: _play.busy ? null : _hint,
        ),
        GameTool(
          icon: CupertinoIcons.xmark_circle,
          label: l10n.gameGiveUp,
          danger: true,
          onTap: _play.busy ? null : _giveUp,
        ),
      ],
      onShare: _play.finished
          ? () => copyGameResult(
              context,
              name: l10n.gameMinesweeperName,
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
