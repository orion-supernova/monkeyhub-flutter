import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/zip_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// ZIP — draw one line from ① to ⑧ that passes through every square exactly
/// once, taking the numbers in order.
///
/// Drawn with a finger, not tapped. The line extends when the drag reaches an
/// adjacent square and *retracts* when it comes back over the one before —
/// which is the whole interaction, because on a route this long the correction
/// you make most often is "back up two and go the other way".
///
/// The line simply refuses to enter a square the rules forbid rather than going
/// red there. That is a deliberate difference from the other three boards, and
/// it comes down to the gesture: Queens and Tango are about *seeing* a
/// contradiction, so showing one is the game. Zip is one continuous stroke, and
/// letting a finger slide through ⑤ before ④ only to paint the trail red behind
/// it makes the drag feel broken rather than the move feel wrong.
class ZipScreen extends StatefulWidget {
  const ZipScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ZipScreen> createState() => _ZipScreenState();
}

class _ZipScreenState extends State<ZipScreen> with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.zip,
    userId: widget.userId,
  );

  /// Breathes the head of an unfinished line, so a board glanced at after
  /// looking away still says "carry on from here".
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final AnimationController _winSweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  List<int> _path = [];

  /// How long the line was when the current drag began, so one gesture is one
  /// undo step rather than thirty.
  int _dragMark = 0;
  bool _refused = false;

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
    setState(() {
      final board = GamesStore.instance.boards.zip;
      final saved = _play.restored;
      // Any prefix of a legal route is a legal partial route, so a save is
      // replayed through the same gate a finger goes through rather than
      // trusted — a board that changed under a stale autosave then simply
      // stops accepting it at the first bad step instead of rendering a line
      // that breaks its own rules.
      _path = [];
      for (final cell in saved) {
        if (!zipCanEnter(board, _path, cell)) break;
        _path.add(cell);
      }
      if (_play.finished && _play.solved) _winSweep.value = 1;
    });
  }

  void _onPlay() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _play
      ..checkpoint(_path)
      ..removeListener(_onPlay)
      ..dispose();
    GamesStore.instance.removeListener(_onPlay);
    _pulse.dispose();
    _winSweep.dispose();
    super.dispose();
  }

  void _dragStart() {
    _dragMark = _path.length;
    _refused = false;
  }

  void _dragTo(int cell) {
    if (!_play.ready || _play.finished || _play.paused || _play.busy) return;
    final board = GamesStore.instance.boards.zip;

    // Retracting: the finger has come back over the square before the head, so
    // the line rubs itself out rather than trying to double back over its own
    // trail.
    if (_path.length >= 2 && cell == _path[_path.length - 2]) {
      setState(() => _path.removeLast());
      HapticFeedback.selectionClick();
      return;
    }
    if (_path.isNotEmpty && cell == _path.last) return;

    if (!zipCanEnter(board, _path, cell)) {
      // One buzz per refusal, not one per frame the finger rests on it — a
      // gesture held over a forbidden square would otherwise vibrate at the
      // pointer's report rate.
      if (!_refused) {
        _refused = true;
        HapticFeedback.lightImpact();
      }
      return;
    }
    _refused = false;
    setState(() => _path.add(cell));
    HapticFeedback.selectionClick();
    _maybeFinish();
  }

  void _dragEnd() {
    _refused = false;
  }

  /// Rolls the line back to where the last drag started.
  void _undoLast() {
    if (_play.finished || _path.isEmpty) return;
    setState(() {
      final to = _dragMark < _path.length ? _dragMark : _path.length - 1;
      _path = _path.sublist(0, to);
      _dragMark = _path.length;
    });
    HapticFeedback.selectionClick();
  }

  void _clear() {
    if (_play.finished) return;
    setState(() {
      _path = [];
      _dragMark = 0;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _giveUp() async {
    if (!await confirmGiveUp(context)) return;
    final answer = await _play.reveal();
    if (answer == null || !mounted) return;
    setState(() => _path = answer);
  }

  Future<void> _maybeFinish() async {
    final board = GamesStore.instance.boards.zip;
    if (!zipSolved(board, _path)) return;
    HapticFeedback.mediumImpact();
    final ok = await _play.submit(_path);
    if (ok && mounted) _winSweep.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final board = GamesStore.instance.boards.zip;

    return GameScaffold(
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gameZipName,
      rule: l10n.gameZipRule,
      board: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _winSweep]),
        builder: (context, _) => GameBoardSurface(
          n: board.size,
          onDragStart: _dragStart,
          onDragTo: _dragTo,
          onDragEnd: _dragEnd,
          // A tap is a one-square drag. Without it the very first square of a
          // board can only be claimed by a swipe, which is not how anyone
          // starts a puzzle.
          onTapCell: (cell) {
            _dragStart();
            _dragTo(cell);
          },
          painter: ZipBoardPainter(
            board: board,
            theme: theme,
            path: _play.paused ? const [] : _path,
            win: _winSweep.value,
            headPulse: _pulse.value,
          ),
        ),
      ),
      tools: [
        GameTool(
          icon: Icons.undo,
          label: l10n.gameUndo,
          onTap: _path.isEmpty ? null : _undoLast,
        ),
        GameTool(
          icon: Icons.clear_all,
          label: l10n.gameClear,
          onTap: _path.isEmpty ? null : _clear,
        ),
        GameTool(
          icon: Icons.flag_outlined,
          label: l10n.gameGiveUp,
          danger: true,
          onTap: _play.busy ? null : _giveUp,
        ),
      ],
      onShare: _play.finished
          ? () => copyGameResult(
              context,
              name: l10n.gameZipName,
              solved: _play.solved,
              durationMs: _play.durationMs,
            )
          : null,
    );
  }
}
