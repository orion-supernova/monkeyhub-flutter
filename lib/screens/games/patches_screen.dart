import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/games_api.dart';
import '../../data/games_store.dart';
import '../../games/game_canvas.dart';
import '../../games/game_play_controller.dart';
import '../../games/game_rules.dart';
import '../../games/hint_spotlight.dart';
import '../../games/patches_board_art.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import 'game_scaffold.dart';

/// PATCHES — cut the board into rectangles, one clue in each, every patch the
/// shape its clue shows and, where the clue prints a number, that many squares.
///
/// Drawn with a finger, on the same gesture surface as Zip and Flow: press on
/// one corner, drag to the opposite one. The rectangle follows the finger,
/// filled in its clue's colour while it is a legal patch and outlined red when
/// it is not, with its size in a pill on its top edge — so the player sees
/// whether it fits before letting go, not after.
///
/// Letting go of a legal rectangle lays it down, lifting whatever it lands on
/// (and the clue's previous patch, if it had one); the patches it would lift
/// fade while the finger is still down. Letting go of an illegal one lays
/// nothing. A tap on a patch lifts it; a tap on a one-square clue is that
/// patch.
///
/// A patch already down is reshaped by grabbing it, the way LinkedIn's board
/// works, rather than by lifting it and drawing it again: see [PatchGrip] for
/// which part of a patch a press takes hold of. A reshape previews exactly
/// like a fresh stroke; letting go of a legal one replaces the patch (one undo
/// step), and letting go of an illegal one leaves the patch as it was.
///
/// No mistakes are counted, for the reason Flow and Zip count none: the board
/// refuses an illegal patch as it is drawn, so there is no wrong state to
/// settle on. A legal patch in the wrong place is not a slip the board can
/// see — only the answer knows — and that is what the hint's first tier is
/// for.
class PatchesScreen extends StatefulWidget {
  const PatchesScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PatchesScreen> createState() => _PatchesScreenState();
}

class _PatchesScreenState extends State<PatchesScreen>
    with TickerProviderStateMixin {
  late final GamePlayController _play = GamePlayController(
    game: DailyGame.patches,
    userId: widget.userId,
  );

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final AnimationController _winSweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// One per clue, null where it has no patch yet.
  List<PatchRect?> _patches = const [];

  /// One entry per change: every patch as it was before it.
  final List<List<PatchRect?>> _undo = [];

  /// The stroke in progress: the square it started on and the one under the
  /// finger now.
  int? _anchor;
  int? _reach;

  /// The patch being reshaped, while a stroke that started on one is down.
  PatchGrip? _grip;

  /// Whether the finger has left the square it pressed: a reshape that never
  /// moved is a tap.
  bool _moved = false;

  /// The pointer's cursor over the board: a resize arrow over a patch's edge
  /// or corner, so a mouse shows what a press there would take hold of.
  MouseCursor _cursor = MouseCursor.defer;

  int? _popClue;

  /// The hint on show, until the player's next move or a tap on its banner.
  BoardHint? _spot;
  int _hintSerial = 0;

  PatchesBoard get _board => GamesStore.instance.boards.patches;

  @override
  void initState() {
    super.initState();
    _play.addListener(_onPlay);
    _play.snapshot = () => patchesLabels(_board, _patches);
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

  /// Rebuilds the patches from the save. The autosave and the submission are
  /// the same shape — the clue covering each square, -1 for none in the
  /// autosave — so one decoder reads both.
  void _restore() {
    final board = _board;
    if (board.isEmpty) return;
    _patches = patchesFromLabels(board, _play.restored);
    if (_play.finished && _play.solved) _winSweep.value = 1;
  }

  void _onPlay() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _play
      ..checkpoint(patchesLabels(_board, _patches))
      ..removeListener(_onPlay)
      ..dispose();
    GamesStore.instance.removeListener(_onPlay);
    _pop.dispose();
    _winSweep.dispose();
    super.dispose();
  }

  bool get _playable =>
      _play.ready && !_play.finished && !_play.paused && !_play.busy;

  /// The rectangle under the finger, if a stroke is in progress.
  PatchRect? get _preview {
    final a = _anchor;
    final b = _reach;
    if (a == null || b == null) return null;
    final grip = _grip;
    if (grip != null) return grip.reshape(b, _board.size);
    return PatchRect.span(a, b, _board.size);
  }

  /// The grip a press on [cell] takes, or null where it starts a fresh
  /// stroke: a bare square, or the inside of a patch.
  PatchGrip? _gripAt(int cell) {
    final n = _board.size;
    for (var k = 0; k < _patches.length; k++) {
      final p = _patches[k];
      if (p == null || !p.contains(cell, n)) continue;
      return PatchGrip.at(k, p, cell, n);
    }
    return null;
  }

  void _hover(Offset at, double side) {
    final n = _board.size;
    MouseCursor next = MouseCursor.defer;
    if (n > 0 && _playable) {
      final cell = GameGrid(side: side, n: n).hit(at);
      final grip = cell == null ? null : _gripAt(cell);
      if (grip != null) next = grip.cursor;
    }
    if (next != _cursor) setState(() => _cursor = next);
  }

  /// The clues whose patches [rect] would lift if it landed for [clue]: its
  /// own previous patch and anything it overlaps.
  Set<int> _lifts(PatchRect rect, int clue) => {
    for (var k = 0; k < _patches.length; k++)
      if (_patches[k] case final p? when k == clue || p.overlaps(rect)) k,
  };

  void _dragStart() {
    if (_spot != null) setState(() => _spot = null);
    _anchor = null;
    _reach = null;
    _grip = null;
    _moved = false;
  }

  void _dragTo(int cell) {
    if (!_playable) return;
    if (_anchor == null) {
      setState(() {
        _anchor = cell;
        _reach = cell;
        _grip = _gripAt(cell);
      });
      HapticFeedback.selectionClick();
      return;
    }
    if (cell == _reach) return;
    _moved = true;
    final before = _preview;
    setState(() => _reach = cell);
    // A tick per change of size, not per square crossed: dragging along an
    // edge of the rectangle does not change it.
    if (_preview != before) HapticFeedback.selectionClick();
  }

  void _dragEnd() {
    final anchor = _anchor;
    final rect = _preview;
    final grip = _grip;
    final moved = _moved;
    setState(() {
      _anchor = null;
      _reach = null;
      _grip = null;
      _moved = false;
    });
    if (anchor == null || rect == null || !_playable) return;
    if (grip != null) {
      // Pressed on a patch and let go without leaving the square: a tap,
      // which lifts it, however much the thumb wobbled.
      if (!moved) {
        _tap(anchor);
        return;
      }
      if (rect == grip.from) return;
      final judged = patchJudge(_board, rect);
      if (judged.trouble != null || judged.clue < 0) {
        // Back to the shape it had. Nothing changed, so nothing to undo;
        // the settle says the patch is still there.
        setState(() => _popClue = grip.clue);
        _pop.forward(from: 0);
        HapticFeedback.lightImpact();
        return;
      }
      _land(rect);
      return;
    }
    // The board claims a drag on its first pixel of movement, so a tap with
    // a little wobble in it arrives here as a one-square stroke. It is a tap,
    // and lifting a patch has to work however steady the thumb was.
    if (rect.area == 1) {
      _tap(anchor);
      return;
    }
    _land(rect);
  }

  /// Lays [rect] down if it is a legal patch; refuses it otherwise.
  void _land(PatchRect rect) {
    final judged = patchJudge(_board, rect);
    final k = judged.clue;
    if (judged.trouble != null || k < 0) {
      HapticFeedback.lightImpact();
      return;
    }
    if (_patches[k] == rect) return;
    setState(() {
      _undo.add(List.of(_patches));
      for (final j in _lifts(rect, k)) {
        _patches[j] = null;
      }
      _patches[k] = rect;
      _popClue = k;
      _spot = null;
    });
    _pop.forward(from: 0);
    HapticFeedback.mediumImpact();
    _maybeFinish();
  }

  /// A tap on a patch lifts it. A tap on a bare square is a one-square
  /// stroke, which lands only on a clue whose patch is that one square.
  void _tap(int cell) {
    if (!_playable) return;
    final n = _board.size;
    for (var k = 0; k < _patches.length; k++) {
      final p = _patches[k];
      if (p == null || !p.contains(cell, n)) continue;
      setState(() {
        _undo.add(List.of(_patches));
        _patches[k] = null;
        _popClue = null;
        _spot = null;
      });
      HapticFeedback.selectionClick();
      return;
    }
    _land(PatchRect.span(cell, cell, n));
  }

  void _undoLast() {
    if (_undo.isEmpty || _play.finished) return;
    setState(() {
      _patches = _undo.removeLast();
      _popClue = null;
      _spot = null;
    });
    HapticFeedback.selectionClick();
  }

  void _clear() {
    if (_play.finished) return;
    setState(() {
      _undo.add(List.of(_patches));
      _patches = List<PatchRect?>.filled(_board.clues.length, null);
      _popClue = null;
      _spot = null;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _hint() async {
    final board = _board;
    final hint = await _play.hint(patchesLabels(board, _patches));
    if (hint == null || !mounted || hint.cells.isEmpty) return;
    final k = hint.answer ?? hint.value;
    if (k < 0 || k >= _patches.length) return;
    final cells = hint.cells.toSet();
    setState(() {
      _undo.clear();
      if (hint.kind == GameHintKind.wrong) {
        // Lifted; the red ring on its clue and the banner say why.
        _patches[k] = null;
        _popClue = null;
        _spot = BoardHint(
          hint: hint,
          serial: ++_hintSerial,
          target: {board.clues[k].cell},
          area: cells,
        );
      } else {
        final rect = _rectOf(hint.cells, board.size);
        for (final j in _lifts(rect, k)) {
          _patches[j] = null;
        }
        _patches[k] = rect;
        _popClue = k;
        // The patch itself is lit; no square in it needs a ring.
        _spot = BoardHint(
          hint: hint,
          serial: ++_hintSerial,
          target: const {},
          area: cells,
        );
      }
    });
    _pop.forward(from: 0);
    HapticFeedback.mediumImpact();
    _maybeFinish();
  }

  /// The rectangle spanning [cells] — a hint's patch, which the server sends
  /// square by square.
  static PatchRect _rectOf(List<int> cells, int n) {
    var rect = PatchRect.span(cells.first, cells.first, n);
    for (final c in cells) {
      final r = c ~/ n;
      final col = c % n;
      rect = PatchRect(
        r < rect.top ? r : rect.top,
        col < rect.left ? col : rect.left,
        r > rect.bottom ? r : rect.bottom,
        col > rect.right ? col : rect.right,
      );
    }
    return rect;
  }

  Future<void> _giveUp() async {
    if (!await confirmGiveUp(context)) return;
    final answer = await _play.reveal();
    if (answer == null || !mounted) return;
    setState(() {
      _patches = patchesFromLabels(_board, answer);
      _popClue = null;
      _spot = null;
    });
  }

  /// Submits the moment the board is cut completely and legally: every patch
  /// is checked as it lands, so a covered board is a solved one.
  Future<void> _maybeFinish() async {
    final solution = patchesSolution(_board, _patches);
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
    final preview = _play.paused ? null : _preview;
    final judged = preview == null ? null : patchJudge(board, preview);
    final previewOk = judged != null && judged.trouble == null;
    final grip = preview == null ? null : _grip;
    final lifting = <int>{
      if (preview != null && previewOk) ..._lifts(preview, judged.clue),
      // The patch in hand fades under its new shape, legal or not: letting
      // go of an illegal one brings it back.
      ?grip?.clue,
    };

    return GameScaffold(
      onUndo: _undo.isEmpty ? null : _undoLast,
      controller: _play,
      viewerId: widget.userId,
      title: l10n.gamePatchesName,
      rule: l10n.gamePatchesRule,
      hintBanner: HintBanner(
        hint: _play.paused ? null : _spot,
        onDismiss: () => setState(() => _spot = null),
      ),
      board: HintSpotlight(
        hint: _play.paused || _play.finished ? null : _spot,
        n: board.size,
        child: LayoutBuilder(
          builder: (context, box) => MouseRegion(
            cursor: _cursor,
            onHover: (e) => _hover(e.localPosition, box.biggest.shortestSide),
            onExit: (_) {
              if (_cursor != MouseCursor.defer) {
                setState(() => _cursor = MouseCursor.defer);
              }
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_pop, _winSweep]),
              builder: (context, _) => GameBoardSurface(
                n: board.size,
                onDragStart: _dragStart,
                onDragTo: _dragTo,
                onDragEnd: _dragEnd,
                claimsDrag: _play.ready && !_play.finished && !_play.paused,
                onTapCell: _tap,
                painter: PatchesBoardPainter(
                  board: board,
                  theme: theme,
                  palette: GamePalette(theme),
                  // A fresh list per build: the patches are edited in place,
                  // and the painter decides whether to repaint by identity.
                  patches: _play.paused ? const [] : [..._patches],
                  preview: preview,
                  previewClue: judged?.clue ?? -1,
                  previewOk: previewOk,
                  lifting: lifting,
                  popClue: _popClue,
                  pop: _pop.value,
                  win: _winSweep.value,
                ),
              ),
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
          onTap: _patches.any((p) => p != null) ? _clear : null,
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
              name: l10n.gamePatchesName,
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

/// What a press on a patch already down takes hold of, and the shape a drag
/// from there gives it.
///
/// Read per axis, rows and columns separately, from the square pressed:
///
///  * on the patch's first or last row (column), that edge follows the
///    finger and the opposite edge stays put;
///  * a patch one square high (wide) has both edges there, so the finger
///    pulls it out either way from that row (column);
///  * strictly between the two edges, the axis is held: the patch keeps its
///    rows (columns) whatever the finger does.
///
/// So a corner square moves the corner, the far corner pinned (LinkedIn's
/// "drag the patch out from the other end"); a square along a side moves that
/// side only; and the inside of a large patch, held on both axes, grips
/// nothing: a press there starts a fresh stroke as it always did. Every grip
/// is a whole square, so a finger never has to find a pixel-wide edge.
class PatchGrip {
  const PatchGrip._(this.clue, this.from, this.rowFixed, this.colFixed);

  /// The grip a press on [cell] (inside [rect], [clue]'s patch) takes, or
  /// null for the inside of the patch.
  static PatchGrip? at(int clue, PatchRect rect, int cell, int n) {
    final rowFixed = _fixed(cell ~/ n, rect.top, rect.bottom);
    final colFixed = _fixed(cell % n, rect.left, rect.right);
    if (rowFixed == null && colFixed == null) return null;
    return PatchGrip._(clue, rect, rowFixed, colFixed);
  }

  /// The edge that stays put on an axis, or null when the axis is held.
  static int? _fixed(int at, int lo, int hi) {
    if (lo == hi) return lo;
    if (at == lo) return hi;
    if (at == hi) return lo;
    return null;
  }

  final int clue;

  /// The patch as it was when pressed.
  final PatchRect from;

  /// Per axis, the edge that stays put; null where the axis is held.
  final int? rowFixed;
  final int? colFixed;

  /// The patch with the finger on [cell].
  PatchRect reshape(int cell, int n) {
    final r = cell ~/ n;
    final c = cell % n;
    final rf = rowFixed;
    final cf = colFixed;
    return PatchRect(
      rf == null ? from.top : (r < rf ? r : rf),
      cf == null ? from.left : (c < cf ? c : cf),
      rf == null ? from.bottom : (r > rf ? r : rf),
      cf == null ? from.right : (c > cf ? c : cf),
    );
  }

  /// The resize arrow a mouse shows over this grip.
  MouseCursor get cursor {
    final rf = rowFixed;
    final cf = colFixed;
    if (rf == null) return SystemMouseCursors.resizeLeftRight;
    if (cf == null) return SystemMouseCursors.resizeUpDown;
    // A strip pulls out either way along its short side: no single diagonal.
    if (from.rows == 1 || from.cols == 1) return SystemMouseCursors.move;
    // The far corner is pinned; the arrow points along the diagonal to it.
    final topLeftOrBottomRight = (rf == from.bottom) == (cf == from.right);
    return topLeftOrBottomRight
        ? SystemMouseCursors.resizeUpLeftDownRight
        : SystemMouseCursors.resizeUpRightDownLeft;
  }
}
