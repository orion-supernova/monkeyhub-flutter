import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_games/match_copy.dart';
import '../chat_games/match_face.dart';
import '../data/matches_store.dart';
import '../games/game_canvas.dart';
import '../games/game_rules.dart';
import '../games/queens_board_art.dart';
import '../games/sudoku_board_art.dart';
import '../games/tango_board_art.dart';
import '../games/zip_board_art.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../models/daily_game.dart';
import '../screens/games/game_keypad.dart';
import '../screens/games/game_scaffold.dart' show GameTool;
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/seat_palette.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart' show SheetRise;
import 'party_kit.dart';
import 'party_views.dart';

/// PUZZLE RACE at the table: everyone's bar along the top, the board in the
/// middle, and the standings once it is over.
///
/// The board is played with the daily games' own painters and rule mirrors
/// (`lib/games/`), but NOT with their [GamePlayController]: that controller
/// is the daily clock, autosave, hints and standings, none of which a race
/// has. The race's clock is the server's, its standings are the match row,
/// and there are no hints in a race. So each kind keeps a lean board state
/// here ([_RaceBoard]) and the server is told two things only: how far along
/// this player is ([MatchController.reportProgress], throttled), and the
/// finished board (`finish:[…]`), which it checks with the very `isSolved`
/// the daily game uses.
///
/// Contradictions are drawn the way Tango draws them: a square the player is
/// still cycling is not judged until they move on from it (or after a beat),
/// so a moon on its way through a sun never flashes a row red. The race keeps
/// no mistake count, so this is only about what the board shows.
class RaceTable extends StatefulWidget {
  const RaceTable({
    super.key,
    required this.match,
    required this.controller,
    required this.viewerId,
    this.enabled = true,
  });

  final ChatMatch match;
  final MatchController controller;
  final String viewerId;
  final bool enabled;

  @override
  State<RaceTable> createState() => _RaceTableState();
}

class _RaceTableState extends State<RaceTable> with TickerProviderStateMixin {
  _RaceBoard? _board;
  String? _boardFor;

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final AnimationController _win = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// The finish in flight or accepted; reset by a refusal so the player can
  /// keep going.
  bool _finishSent = false;
  Timer? _trailingProgress;
  Timer? _settle;
  static const _settleAfter = Duration(milliseconds: 900);

  RaceView? get _view {
    final v = partyViewOf(widget.match);
    return v is RaceView ? v : null;
  }

  int get _mySeat => widget.match.seatOf(widget.viewerId);

  bool get _finished {
    final v = _view;
    final seat = _mySeat;
    if (v == null || seat < 0 || seat >= v.players.length) return false;
    return v.players[seat].rank != null;
  }

  bool get _playable {
    final m = widget.match;
    final v = _view;
    return widget.enabled &&
        v != null &&
        !v.over &&
        m.status == MatchStatus.active &&
        _mySeat >= 0 &&
        !_finished &&
        !_finishSent;
  }

  @override
  void dispose() {
    _trailingProgress?.cancel();
    _settle?.cancel();
    _pop.dispose();
    _win.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// The board for [v]'s puzzle, built once per puzzle.
  _RaceBoard? _boardOf(RaceView v) {
    final key = '${widget.match.id}:${v.kind}:${v.startedAt}';
    if (_boardFor != key) {
      _boardFor = key;
      _board = _RaceBoard.of(v.kind, v.puzzle);
      if (v.kind == 'zip' && !_pulse.isAnimating) _pulse.repeat();
    }
    return _board;
  }

  /// After every change: the bar, the settle timer, and the finish.
  void _changed(_RaceBoard b, int? cell) {
    _pop.forward(from: 0);
    _settle?.cancel();
    if (cell != null && b.pending == cell) {
      _settle = Timer(_settleAfter, () {
        if (!mounted) return;
        setState(() => b.settle(cell));
      });
    }
    _report(b);
    final solution = b.solution();
    if (solution != null && !_finishSent) _finish(solution);
  }

  void _report(_RaceBoard b) {
    final pct = (b.progress * 100).floor();
    widget.controller.reportProgress(pct);
    // The throttle drops a tick sent too soon after the last; the trailing
    // one makes sure the bar the others see ends up where the board is.
    _trailingProgress?.cancel();
    _trailingProgress = Timer(MatchController.progressEvery, () {
      if (mounted) widget.controller.reportProgress(pct);
    });
  }

  Future<void> _finish(List<int> solution) async {
    _finishSent = true;
    _trailingProgress?.cancel();
    HapticFeedback.mediumImpact();
    final calm = MotionScope.of(context).calm;
    calm ? _win.value = 1 : _win.forward(from: 0);
    setState(() {});
    final ok = await widget.controller.act('finish:${jsonEncode(solution)}');
    if (!mounted) return;
    if (!ok) {
      _win.value = 0;
      setState(() => _finishSent = false);
    }
  }

  void _tap(int cell) {
    final b = _board;
    if (b == null || !_playable) return;
    final changed = b.tap(cell);
    if (changed == null) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {});
    _changed(b, changed);
  }

  void _enter(int digit) {
    final b = _board;
    if (b is! _SudokuRace || !_playable) return;
    final changed = b.enter(digit);
    if (changed == null) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {});
    _changed(b, changed);
  }

  bool _refused = false;

  void _dragTo(int cell) {
    final b = _board;
    if (b is! _ZipRace || !_playable) return;
    final r = b.dragTo(cell);
    if (r == _ZipStep.refused) {
      if (!_refused) {
        _refused = true;
        HapticFeedback.lightImpact();
      }
      return;
    }
    _refused = false;
    if (r == _ZipStep.none) return;
    HapticFeedback.selectionClick();
    setState(() {});
    _changed(b, null);
  }

  void _undo() {
    final b = _board;
    if (b == null || !_playable || !b.canUndo) return;
    HapticFeedback.selectionClick();
    _settle?.cancel();
    setState(b.undo);
    _report(b);
  }

  void _clear() {
    final b = _board;
    if (b == null || !_playable || !b.canUndo) return;
    HapticFeedback.mediumImpact();
    _settle?.cancel();
    setState(b.clear);
    _report(b);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final v = _view;
    if (v == null) return const SizedBox.shrink();
    final m = widget.match;
    final b = _boardOf(v);
    final mySeat = _mySeat;
    final me = mySeat >= 0 && mySeat < v.players.length ? v.players[mySeat] : null;
    final done = me?.rank != null || _finishSent;
    final children = <Widget>[
      _RaceBars(match: m, view: v, viewerId: widget.viewerId),
      const SizedBox(height: 12),
    ];
    if (v.over) {
      children.add(_RaceResults(match: m, view: v, viewerId: widget.viewerId));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    children.add(Row(
      children: [
        Expanded(
          child: Text(
            sentenceCaseOf(context, _kindName(l10n, v.kind)),
            style: groupedTitleStyle(theme).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        PhaseClockPill(clock: widget.controller, deadline: v.deadline),
      ],
    ));
    children.add(const SizedBox(height: 10));
    if (b != null) {
      children.add(Stack(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_pop, _win, _pulse]),
            builder: (context, _) => b.surface(
              theme: theme,
              pop: _pop.value,
              win: _win.value,
              pulse: _pulse.value,
              live: _playable,
              onTap: _tap,
              onDragStart: () {
                _refused = false;
                if (b is _ZipRace) b.markStroke();
              },
              onDragTo: _dragTo,
            ),
          ),
          if (done)
            Positioned.fill(
              child: _SolvedCover(
                rank: me?.rank,
                durationMs: me?.durationMs,
              ),
            ),
        ],
      ));
      if (!done && mySeat >= 0) {
        children.add(const SizedBox(height: 12));
        if (b is _SudokuRace) {
          children.add(GameKeypad(
            size: b.board.size,
            remaining: b.remaining,
            enabled: _playable && b.selected != null,
            onEnter: _enter,
            keyPrefix: 'race',
          ));
          children.add(const SizedBox(height: 10));
        }
        children.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameTool(
              icon: CupertinoIcons.arrow_uturn_left,
              label: l10n.gameUndo,
              onTap: _playable && b.canUndo ? _undo : null,
            ),
            const SizedBox(width: 12),
            GameTool(
              icon: CupertinoIcons.trash,
              label: l10n.gameClear,
              onTap: _playable && b.canUndo ? _clear : null,
            ),
          ],
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

String _kindName(AppLocalizations l10n, String kind) => switch (kind) {
  'queens' => l10n.gameQueensName,
  'tango' => l10n.gameTangoName,
  'sudoku' => l10n.gameSudokuName,
  'zip' => l10n.gameZipName,
  _ => kind,
};

/// The name of a Puzzle Race board, for the start sheet's picker.
String racePuzzleName(AppLocalizations l10n, String kind) => _kindName(l10n, kind);

// ── Bars ────────────────────────────────────────────────────────────────────

/// Everyone's progress, face first: a bar in the seat's colour that fills as
/// they go, and their place and time once they are done.
class _RaceBars extends StatelessWidget {
  const _RaceBars({
    required this.match,
    required this.view,
    required this.viewerId,
  });

  final ChatMatch match;
  final RaceView view;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = SeatPalette(theme, gameId: match.game);
    final motion = MotionScope.of(context);
    return PartyPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Column(
        children: [
          for (var i = 0; i < view.players.length && i < match.seats.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Opacity(
                    opacity: view.players[i].left ? 0.4 : 1,
                    child: MatchFace(
                      roomId: match.roomId,
                      userId: match.seats[i].userId,
                      name: match.seats[i].name,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: Text(
                      seatName(l10n, match, i, viewerId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: groupedMetaStyle(theme).copyWith(
                        color: theme.ink,
                        fontWeight: match.seats[i].userId == viewerId
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 8,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: palette.wash(i)),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                end: view.players[i].progress / 100,
                              ),
                              duration: motion.d(theme.motionSlow),
                              curve: theme.motionCurve,
                              builder: (context, f, _) => FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: f.clamp(0.0, 1.0),
                                child: ColoredBox(color: palette.fill(i)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _trailing(l10n, view.players[i]),
                      textAlign: TextAlign.end,
                      style: groupedMetaStyle(theme).copyWith(
                        fontWeight: FontWeight.w700,
                        color: view.players[i].rank == 1
                            ? theme.success
                            : theme.inkSoft,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _trailing(AppLocalizations l10n, RacePlayer p) {
    if (p.rank != null) return '#${p.rank} ${formatGameTime(p.durationMs)}';
    if (p.left) return l10n.chatGameRaceLeft;
    return '${p.progress}%';
  }
}

class _SolvedCover extends StatelessWidget {
  const _SolvedCover({this.rank, this.durationMs});

  final int? rank;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SheetRise(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            decoration: BoxDecoration(
              color: groupedFill(theme).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(groupedRadius(theme)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.checkmark_seal_fill, size: 40, color: theme.success),
                const SizedBox(height: 8),
                Text(
                  sentenceCaseOf(
                    context,
                    rank == null ? l10n.chatGameRaceSolved : l10n.chatGameRaceYouPlaced(rank!),
                  ),
                  style: theme.displaySmall.copyWith(fontWeight: FontWeight.w800),
                ),
                if (durationMs != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatGameTime(durationMs),
                    style: groupedTitleStyle(theme).copyWith(
                      color: theme.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                PartyCaption(l10n.chatGameRaceWaiting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The final standings: place, face, name, time.
class _RaceResults extends StatelessWidget {
  const _RaceResults({
    required this.match,
    required this.view,
    required this.viewerId,
  });

  final ChatMatch match;
  final RaceView view;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final order = [
      for (var i = 0; i < view.players.length && i < match.seats.length; i++) i,
    ]..sort((a, b) {
        final ra = view.players[a].rank;
        final rb = view.players[b].rank;
        if (ra != null && rb != null) return ra.compareTo(rb);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return view.players[b].progress.compareTo(view.players[a].progress);
      });
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedHeader(l10n.chatGameRaceResults),
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          child: ColoredBox(
            color: groupedFill(theme),
            child: Column(
              children: [
                for (var k = 0; k < order.length; k++) ...[
                  if (k > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 96),
                      child: SizedBox(
                        height: hairline,
                        child: ColoredBox(color: theme.divider),
                      ),
                    ),
                  _ResultRow(
                    match: match,
                    seat: order[k],
                    player: view.players[order[k]],
                    viewerId: viewerId,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.match,
    required this.seat,
    required this.player,
    required this.viewerId,
  });

  final ChatMatch match;
  final int seat;
  final RacePlayer player;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = match.seats[seat];
    final rank = player.rank;
    final medal = switch (rank) {
      1 => const Color(0xFFE8B730),
      2 => const Color(0xFFA7B0BA),
      3 => const Color(0xFFC98A5A),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal == null
                ? Text(
                    rank == null ? '–' : '$rank',
                    textAlign: TextAlign.center,
                    style: groupedTitleStyle(theme).copyWith(
                      color: theme.inkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: medal, shape: BoxShape.circle),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          MatchFace(roomId: match.roomId, userId: s.userId, name: s.name, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              seatName(l10n, match, seat, viewerId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: groupedTitleStyle(theme).copyWith(
                fontWeight: rank == 1 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            rank != null
                ? formatGameTime(player.durationMs)
                : player.left
                ? l10n.chatGameRaceLeft
                : l10n.chatGameRaceDnf,
            style: groupedTitleStyle(theme).copyWith(
              color: rank != null ? theme.ink : theme.inkMuted,
              fontWeight: rank != null ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Boards ──────────────────────────────────────────────────────────────────

/// One kind's lean board state: what the player has put down, the undo
/// trail, the square still being settled, and the two things the race needs
/// from it ([progress] and [solution]).
sealed class _RaceBoard {
  static _RaceBoard? of(String kind, Map<String, dynamic> puzzle) {
    switch (kind) {
      case 'queens':
        final b = QueensBoard.fromJson(puzzle);
        return b.isEmpty ? null : _QueensRace(b);
      case 'tango':
        final b = TangoBoard.fromJson(puzzle);
        return b.isEmpty ? null : _TangoRace(b);
      case 'sudoku':
        final b = SudokuBoard.fromJson(puzzle);
        return b.isEmpty ? null : _SudokuRace(b);
      case 'zip':
        final b = ZipBoard.fromJson(puzzle);
        return b.isEmpty ? null : _ZipRace(b);
    }
    return null;
  }

  int get n;

  /// The square the player is still cycling, not yet judged.
  int? pending;

  /// The square that last changed, for its pop.
  int? popCell;

  /// Bumped by every change. The painter's inputs (a copy of the marks, the
  /// contradictions) are rebuilt once per version, not once per frame of the
  /// pop or the Zip pulse that redraw the board in between.
  int version = 0;
  int _snapFor = -1;

  /// Rebuilds the cached painter inputs if anything changed since.
  void snapshot() {
    if (_snapFor == version) return;
    _snapFor = version;
    rebuild();
  }

  /// Fills the kind's cached painter inputs from its live state.
  void rebuild();

  /// Judges [cell] if it is still the pending one.
  void settle(int cell) {
    if (pending == cell) {
      pending = null;
      version++;
    }
  }

  /// A tap on [cell]: the cell that changed, or null for a refusal.
  int? tap(int cell);

  /// 0 → 1: how much of the board is filled in.
  double get progress;

  /// The board in `finish:`'s encoding once it is solved; null until then.
  List<int>? solution();

  bool get canUndo;
  void undo();
  void clear();

  Widget surface({
    required AppTheme theme,
    required double pop,
    required double win,
    required double pulse,
    required bool live,
    required void Function(int) onTap,
    required VoidCallback onDragStart,
    required void Function(int) onDragTo,
  });
}

class _QueensRace extends _RaceBoard {
  _QueensRace(this.board)
    : marks = List.filled(board.size * board.size, QueensMark.none);

  final QueensBoard board;
  final List<QueensMark> marks;
  final List<(int, QueensMark)> _undo = [];

  @override
  int get n => board.size;

  @override
  int? tap(int cell) {
    final before = marks[cell];
    final next = switch (before) {
      QueensMark.none => QueensMark.blocked,
      QueensMark.blocked => QueensMark.crown,
      QueensMark.crown => QueensMark.none,
    };
    _undo.add((cell, before));
    marks[cell] = next;
    popCell = cell;
    pending = next == QueensMark.crown ? cell : null;
    version++;
    return cell;
  }

  List<QueensMark> _marks = const [];
  Set<int> _conflicts = const {};
  Set<int> _blocked = const {};

  @override
  void rebuild() {
    _marks = List.of(marks);
    _conflicts = conflicts;
    _blocked = queensBlocked(board, marks);
  }

  /// Contradictions, leaving out a crown still being settled.
  Set<int> get conflicts {
    final p = pending;
    if (p == null || marks[p] != QueensMark.crown) {
      return queensConflicts(board, marks);
    }
    final settled = List.of(marks)..[p] = QueensMark.none;
    return queensConflicts(board, settled);
  }

  @override
  double get progress =>
      n == 0 ? 0 : marks.where((m) => m == QueensMark.crown).length / n;

  @override
  List<int>? solution() =>
      queensSolved(board, marks) ? queensSolution(board, marks) : null;

  @override
  bool get canUndo => _undo.isNotEmpty;

  @override
  void undo() {
    final (cell, mark) = _undo.removeLast();
    marks[cell] = mark;
    pending = null;
    popCell = null;
    version++;
  }

  @override
  void clear() {
    marks.fillRange(0, marks.length, QueensMark.none);
    _undo.clear();
    pending = null;
    version++;
  }

  @override
  Widget surface({
    required AppTheme theme,
    required double pop,
    required double win,
    required double pulse,
    required bool live,
    required void Function(int) onTap,
    required VoidCallback onDragStart,
    required void Function(int) onDragTo,
  }) {
    snapshot();
    return GameBoardSurface(
      n: n,
      onTapCell: live ? onTap : null,
      painter: QueensBoardPainter(
        board: board,
        theme: theme,
        palette: GamePalette(theme),
        marks: _marks,
        conflicts: _conflicts,
        autoBlocked: _blocked,
        popCell: popCell,
        pop: pop,
        win: win,
      ),
    );
  }
}

class _TangoRace extends _RaceBoard {
  _TangoRace(this.board)
    : cells = List.filled(board.size * board.size, tangoEmpty),
      _empties = board.givens.where((g) => g == tangoEmpty).length;

  final TangoBoard board;
  final List<int> cells;
  final int _empties;
  final List<(int, int)> _undo = [];

  @override
  int get n => board.size;

  @override
  int? tap(int cell) {
    if (board.givens[cell] != tangoEmpty) return null;
    final before = cells[cell];
    final next = switch (before) {
      tangoEmpty => tangoSun,
      tangoSun => tangoMoon,
      _ => tangoEmpty,
    };
    _undo.add((cell, before));
    cells[cell] = next;
    popCell = cell;
    pending = next == tangoEmpty ? null : cell;
    version++;
    return cell;
  }

  List<int> _cells = const [];
  TangoTrouble _trouble = const TangoTrouble(cells: {}, signs: {});

  @override
  void rebuild() {
    _cells = List.of(cells);
    _trouble = trouble;
  }

  TangoTrouble get trouble {
    final p = pending;
    if (p == null) return tangoTrouble(board, _full);
    final settled = _full..[p] = tangoEmpty;
    return tangoTrouble(board, settled);
  }

  List<int> get _full => [
    for (var i = 0; i < cells.length; i++)
      board.givens[i] != tangoEmpty ? board.givens[i] : cells[i],
  ];

  @override
  double get progress => _empties == 0
      ? 0
      : cells.where((c) => c != tangoEmpty).length / _empties;

  @override
  List<int>? solution() {
    final full = _full;
    return tangoSolved(board, full) ? full : null;
  }

  @override
  bool get canUndo => _undo.isNotEmpty;

  @override
  void undo() {
    final (cell, value) = _undo.removeLast();
    cells[cell] = value;
    pending = null;
    popCell = null;
    version++;
  }

  @override
  void clear() {
    cells.fillRange(0, cells.length, tangoEmpty);
    _undo.clear();
    pending = null;
    version++;
  }

  @override
  Widget surface({
    required AppTheme theme,
    required double pop,
    required double win,
    required double pulse,
    required bool live,
    required void Function(int) onTap,
    required VoidCallback onDragStart,
    required void Function(int) onDragTo,
  }) {
    snapshot();
    return GameBoardSurface(
      n: n,
      onTapCell: live ? onTap : null,
      painter: TangoBoardPainter(
        board: board,
        theme: theme,
        cells: _cells,
        trouble: _trouble,
        popCell: popCell,
        pop: pop,
        win: win,
      ),
    );
  }
}

class _SudokuRace extends _RaceBoard {
  _SudokuRace(this.board)
    : cells = List.filled(board.size * board.size, sudokuEmpty),
      _empties = board.givens.where((g) => g == sudokuEmpty).length;

  final SudokuBoard board;
  final List<int> cells;
  final int _empties;
  final List<(int, int)> _undo = [];
  int? selected;

  @override
  int get n => board.size;

  /// A tap selects; the keypad writes.
  @override
  int? tap(int cell) {
    if (selected != cell && pending != null) pending = null;
    selected = cell;
    version++;
    return cell;
  }

  int? enter(int digit) {
    final cell = selected;
    if (cell == null || board.givens[cell] != sudokuEmpty) return null;
    final before = cells[cell];
    _undo.add((cell, before));
    // The digit already there clears it: the keypad is its own eraser.
    cells[cell] = before == digit ? sudokuEmpty : digit;
    popCell = cell;
    pending = cells[cell] == sudokuEmpty ? null : cell;
    version++;
    return cell;
  }

  List<int> _cells = const [];
  Set<int> _conflicts = const {};

  @override
  void rebuild() {
    _cells = List.of(cells);
    _conflicts = conflicts;
  }

  Set<int> get conflicts {
    final p = pending;
    if (p == null) return sudokuConflicts(board, cells);
    final settled = List.of(cells)..[p] = sudokuEmpty;
    return sudokuConflicts(board, settled);
  }

  Map<int, int> get remaining {
    final left = {for (var v = 1; v <= board.size; v++) v: board.size};
    for (var i = 0; i < cells.length; i++) {
      final v = board.givens[i] != sudokuEmpty ? board.givens[i] : cells[i];
      if (v != sudokuEmpty && left.containsKey(v)) left[v] = left[v]! - 1;
    }
    return left;
  }

  @override
  double get progress => _empties == 0
      ? 0
      : cells.where((c) => c != sudokuEmpty).length / _empties;

  @override
  List<int>? solution() {
    final full = [
      for (var i = 0; i < cells.length; i++)
        board.givens[i] != sudokuEmpty ? board.givens[i] : cells[i],
    ];
    return sudokuSolved(board, full) ? full : null;
  }

  @override
  bool get canUndo => _undo.isNotEmpty;

  @override
  void undo() {
    final (cell, value) = _undo.removeLast();
    cells[cell] = value;
    selected = cell;
    pending = null;
    popCell = null;
    version++;
  }

  @override
  void clear() {
    cells.fillRange(0, cells.length, sudokuEmpty);
    _undo.clear();
    pending = null;
    version++;
  }

  @override
  Widget surface({
    required AppTheme theme,
    required double pop,
    required double win,
    required double pulse,
    required bool live,
    required void Function(int) onTap,
    required VoidCallback onDragStart,
    required void Function(int) onDragTo,
  }) {
    snapshot();
    return GameBoardSurface(
      n: n,
      onTapCell: live ? onTap : null,
      painter: SudokuBoardPainter(
        board: board,
        theme: theme,
        cells: _cells,
        conflicts: _conflicts,
        selected: live ? selected : null,
        popCell: popCell,
        pop: pop,
        win: win,
      ),
    );
  }
}

enum _ZipStep { none, moved, refused }

class _ZipRace extends _RaceBoard {
  _ZipRace(this.board);

  final ZipBoard board;
  List<int> path = [];
  int _strokeMark = 0;

  @override
  int get n => board.size;

  /// [path] is replaced, never edited, so the painter's identity check is
  /// already exact and there is nothing to cache.
  @override
  void rebuild() {}

  void markStroke() => _strokeMark = path.length;

  _ZipStep dragTo(int cell) {
    if (path.length >= 2 && cell == path[path.length - 2]) {
      path = path.sublist(0, path.length - 1);
      return _ZipStep.moved;
    }
    if (path.isNotEmpty && cell == path.last) return _ZipStep.none;
    if (!zipCanEnter(board, path, cell)) return _ZipStep.refused;
    path = [...path, cell];
    return _ZipStep.moved;
  }

  @override
  int? tap(int cell) {
    markStroke();
    return dragTo(cell) == _ZipStep.moved ? cell : null;
  }

  @override
  double get progress {
    final total = n * n;
    return total == 0 ? 0 : path.length / total;
  }

  @override
  List<int>? solution() => zipSolved(board, path) ? List.of(path) : null;

  @override
  bool get canUndo => path.isNotEmpty;

  /// One stroke back, the way the daily Zip undoes.
  @override
  void undo() {
    final to = _strokeMark < path.length ? _strokeMark : path.length - 1;
    path = path.sublist(0, to < 0 ? 0 : to);
    _strokeMark = path.length;
  }

  @override
  void clear() {
    path = [];
    _strokeMark = 0;
  }

  @override
  Widget surface({
    required AppTheme theme,
    required double pop,
    required double win,
    required double pulse,
    required bool live,
    required void Function(int) onTap,
    required VoidCallback onDragStart,
    required void Function(int) onDragTo,
  }) => GameBoardSurface(
    n: n,
    claimsDrag: live,
    onDragStart: live ? onDragStart : null,
    onDragTo: live ? onDragTo : null,
    onTapCell: live
        ? (cell) {
            onDragStart();
            onDragTo(cell);
          }
        : null,
    painter: ZipBoardPainter(
      board: board,
      theme: theme,
      path: path,
      win: win,
      headPulse: pulse,
    ),
  );
}
