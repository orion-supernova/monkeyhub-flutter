/// The chess board: tap a piece and tap its square, or drag it there.
///
/// Squares use the same themed neutrals as checkers (never wood). The last
/// move's two squares are tinted, a king in check sits in a soft danger glow,
/// and a selected piece's legal squares show as dots, or as rings where the
/// move takes something. A pawn reaching the last rank opens a small picker
/// over the board itself, never a route, with the four pieces it can become.
///
/// Rules come from [chessRules], the rules of record, so the board only ever
/// emits a token the server's chess.js would list for the same position.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../chess.dart';
import 'board_kit.dart';
import 'chess_pieces.dart';

/// How long a moved piece takes to slide; a captured one fades over the same.
const double _slideMs = 220;

/// Where the 64 squares are drawn. `sq64` is row-major from a8 (see
/// `chess.dart`); [flipped] puts black at the bottom, for seat 1.
class ChessGeometry {
  ChessGeometry(Size size, {required this.flipped})
    : side = math.min(size.width, size.height);

  final double side;
  final bool flipped;

  double get cell => side / 8;

  /// Screen row and column of [sq64].
  (int, int) cellOf(int sq64) {
    final row = sq64 >> 3;
    final col = sq64 & 7;
    return flipped ? (7 - row, 7 - col) : (row, col);
  }

  Rect square(int sq64) {
    final (r, c) = cellOf(sq64);
    return Rect.fromLTWH(c * cell, r * cell, cell, cell);
  }

  Offset center(int sq64) => square(sq64).center;

  /// The square under [p], or null off the board.
  int? squareAt(Offset p) {
    if (cell <= 0 || p.dx < 0 || p.dy < 0 || p.dx >= side || p.dy >= side) {
      return null;
    }
    var r = (p.dy / cell).floor();
    var c = (p.dx / cell).floor();
    if (flipped) {
      r = 7 - r;
      c = 7 - c;
    }
    return r * 8 + c;
  }
}

/// One piece sliding, for the move animation: a castling move has two.
typedef ChessSlide = ({int piece, int from, int to});

/// A move as the painter animates it.
class ChessAnimation {
  const ChessAnimation({required this.slides, required this.captured});

  final List<ChessSlide> slides;

  /// The taken piece and the square it stood on (not the landing square, for
  /// en passant), fading while the mover arrives.
  final (int, int)? captured;
}

class ChessBoardView extends BoardView {
  const ChessBoardView({super.key, required super.props});

  @override
  State<ChessBoardView> createState() => _ChessBoardState();
}

class _ChessBoardState extends BoardViewState<ChessBoardView> {
  ChessState? _s;
  List<int> _legal = const [];

  /// The selected piece's square, `sq64`.
  int? _selected;

  /// A promotion waiting for its piece: from and to, `sq64`.
  (int, int)? _promotion;

  /// The finger, while a piece is being dragged; board-local.
  Offset? _drag;

  ChessAnimation? _anim;

  @override
  void initState() {
    super.initState();
    _s = _decode(widget.props.state);
    _refreshLegal();
  }

  static ChessState? _decode(String raw) {
    try {
      return chessRules.decode(raw);
    } on FormatException {
      return null;
    }
  }

  void _refreshLegal() {
    final s = _s;
    _legal = s != null && widget.props.canMoveFor(s.turn)
        ? chessRules.legalMoves(s)
        : const [];
  }

  void _clearInput() {
    _selected = null;
    _promotion = null;
    _drag = null;
  }

  @override
  void didUpdateWidget(ChessBoardView old) {
    super.didUpdateWidget(old);
    if (old.props.state == widget.props.state) {
      if (old.props.enabled != widget.props.enabled ||
          old.props.mySeat != widget.props.mySeat) {
        _refreshLegal();
        _clearInput();
      }
      return;
    }
    final before = _s;
    final next = _decode(widget.props.state);
    if (next == null) return;
    _s = next;
    _clearInput();
    _anim = null;
    _refreshLegal();
    if (before == null) return;
    final move = _inferMove(before, next);
    if (move == null) {
      play(0);
      return;
    }
    _anim = move;
    play(_slideMs);
  }

  /// What moved between [a] and [b], read off the boards: the mover's pieces
  /// that left a square and those that arrived on one (one of each, or two
  /// of each for castling), and the other side's piece that vanished. A pair
  /// that cannot be read that way (a jump of several plies) just snaps.
  ChessAnimation? _inferMove(ChessState a, ChessState b) {
    final mover = a.turn;
    final left = <int>[];
    final arrived = <int>[];
    (int, int)? captured;
    for (var sq = 0; sq < 64; sq++) {
      final x = a.pieceAt(sq);
      final y = b.pieceAt(sq);
      if (x == y) continue;
      if (x != 0 && x >> 3 == mover) left.add(sq);
      if (y != 0 && y >> 3 == mover) arrived.add(sq);
      if (x != 0 && x >> 3 != mover) {
        if (captured != null) return null;
        captured = (sq, x);
      }
    }
    if (left.length != arrived.length || left.isEmpty || left.length > 2) {
      return null;
    }
    final slides = <ChessSlide>[];
    if (left.length == 1) {
      slides.add((piece: a.pieceAt(left.first), from: left.first, to: arrived.first));
    } else {
      // Castling: the king goes to the square its own type arrived on.
      for (final from in left) {
        final p = a.pieceAt(from);
        final to = arrived.firstWhere((t) => b.pieceAt(t) == p, orElse: () => -1);
        if (to < 0) return null;
        slides.add((piece: p, from: from, to: to));
      }
    }
    return ChessAnimation(slides: slides, captured: captured);
  }

  bool get _flipped => widget.props.mySeat == 1;

  ChessGeometry _geometry() {
    final box = context.findRenderObject() as RenderBox?;
    return ChessGeometry(box?.size ?? Size.zero, flipped: _flipped);
  }

  Iterable<int> _movesFrom(int sq) =>
      _legal.where((m) => chessMoveFrom(m) == sq);

  /// Landing squares for the selected piece.
  Set<int> get _targets {
    final sel = _selected;
    if (sel == null) return const {};
    return {for (final m in _movesFrom(sel)) chessMoveTo(m)};
  }

  /// Tries to move the selected piece to [to]. True if that was a move (or
  /// opened the promotion picker).
  bool _tryMove(int to) {
    final from = _selected;
    if (from == null) return false;
    final moves = _movesFrom(from).where((m) => chessMoveTo(m) == to).toList();
    if (moves.isEmpty) return false;
    if (moves.length > 1) {
      // Only a promotion offers several moves between the same two squares.
      BoardHaptics.tick();
      setState(() {
        _promotion = (from, to);
        _drag = null;
      });
      return true;
    }
    _emit(moves.first);
    return true;
  }

  void _tap(int? sq) {
    if (_legal.isEmpty) return;
    if (_promotion != null) {
      setState(_clearInput);
      return;
    }
    if (sq == null) {
      if (_selected != null) setState(_clearInput);
      return;
    }
    if (_tryMove(sq)) return;
    if (sq == _selected) {
      setState(_clearInput);
      return;
    }
    if (_movesFrom(sq).isNotEmpty) {
      BoardHaptics.tick();
      setState(() => _selected = sq);
      return;
    }
    if (_selected != null) setState(_clearInput);
  }

  void _dragStart(DragStartDetails d) {
    if (_legal.isEmpty || _promotion != null) return;
    final sq = _geometry().squareAt(d.localPosition);
    if (sq == null || _movesFrom(sq).isEmpty) return;
    if (_selected != sq) BoardHaptics.tick();
    setState(() {
      _selected = sq;
      _drag = d.localPosition;
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_drag == null) return;
    setState(() => _drag = d.localPosition);
  }

  void _dragEnd(DragEndDetails _) {
    final at = _drag;
    if (at == null) return;
    final sq = _geometry().squareAt(at);
    // A drop anywhere that is not a move puts the piece back and keeps it
    // selected, so a tap can still finish the move.
    setState(() => _drag = null);
    if (sq != null && sq != _selected) _tryMove(sq);
  }

  void _promote(int pieceType) {
    final p = _promotion;
    if (p == null) return;
    final (from, to) = p;
    final m = chessMove(from, to, pieceType);
    setState(_clearInput);
    if (_legal.contains(m)) _emit(m);
  }

  void _emit(int m) {
    final s = _s;
    if (s == null || !widget.props.canMoveFor(s.turn)) return;
    // Only a move the rules list leaves the board.
    if (!chessRules.legalMoves(s).contains(m)) return;
    setState(_clearInput);
    BoardHaptics.land();
    widget.props.onMove!(chessRules.encodeMove(m));
  }

  static String _pieceName(AppLocalizations l10n, int p) {
    if (p == 0) return l10n.boardEmpty;
    final piece = chessPieceWord(l10n, p & 7);
    return p >> 3 == 0
        ? l10n.chessPieceWhite(piece)
        : l10n.chessPieceBlack(piece);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final p = widget.props;
    final canMove = _legal.isNotEmpty;
    final targets = _targets;
    (int, int)? last;
    if (!p.thumbnail && p.lastMove != null) {
      try {
        final m = chessRules.decodeMove(p.lastMove!);
        last = (chessMoveFrom(m), chessMoveTo(m));
      } on FormatException {
        last = null;
      }
    }
    final painter = ChessPainter(
      state: s,
      theme: p.theme,
      dark: p.seats.dark,
      flipped: _flipped,
      thumbnail: p.thumbnail,
      clock: clock,
      anim: _anim,
      selected: _selected,
      targets: targets,
      drag: _drag,
      last: last,
    );
    final l10n = boardL10n(context);
    final surface = boardSurface(
      props: p,
      painter: painter,
      semantics: BoardSemanticsPainter(
        version: '${p.state}|$canMove|$_selected',
        nodes: (size) {
          final g = ChessGeometry(size, flipped: _flipped);
          return [
            for (var sq = 0; sq < 64; sq++)
              boardNode(
                g.square(sq),
                '${chessSquareName(sq)}, ${_pieceName(l10n, s.pieceAt(sq))}'
                '${targets.contains(sq) ? ', ${l10n.boardMoveHere}' : ''}',
                selected: _selected == sq,
                onTap: canMove && (targets.contains(sq) || _movesFrom(sq).isNotEmpty)
                    ? () => _tap(sq)
                    : null,
              ),
          ];
        },
      ),
      gestures: canMove
          ? (child) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: (d) => _tap(_geometry().squareAt(d.localPosition)),
              onPanStart: _dragStart,
              onPanUpdate: _dragUpdate,
              onPanEnd: _dragEnd,
              onPanCancel: () {
                if (_drag != null) setState(() => _drag = null);
              },
              child: child,
            )
          : null,
    );
    final promo = _promotion;
    if (promo == null || p.thumbnail) return surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        surface,
        LayoutBuilder(
          builder: (context, box) => _PromotionPicker(
            geometry: ChessGeometry(box.biggest, flipped: _flipped),
            to: promo.$2,
            side: s.turn,
            theme: p.theme,
            dark: p.seats.dark,
            calm: p.calm,
            onPick: _promote,
            onCancel: () => setState(_clearInput),
          ),
        ),
      ],
    );
  }
}

/// The four pieces a pawn can become, in a column over the board from the
/// promotion square towards the middle, queen nearest (the usual pick under
/// the finger that just moved). The rest of the board dims; a tap on it
/// cancels.
class _PromotionPicker extends StatelessWidget {
  const _PromotionPicker({
    required this.geometry,
    required this.to,
    required this.side,
    required this.theme,
    required this.dark,
    required this.calm,
    required this.onPick,
    required this.onCancel,
  });

  final ChessGeometry geometry;
  final int to;
  final int side;
  final AppTheme theme;
  final bool dark;
  final bool calm;
  final ValueChanged<int> onPick;
  final VoidCallback onCancel;

  static const _order = [chessQueen, chessKnight, chessRook, chessBishop];
  static const _letters = {chessQueen: 'q', chessKnight: 'n', chessRook: 'r', chessBishop: 'b'};

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    final cell = g.cell;
    final (row, col) = g.cellOf(to);
    // From the edge the pawn reached, downwards if that edge is the top.
    final down = row == 0;
    final style = ChessPieceStyle(darkTheme: dark);
    final tiles = <Widget>[
      for (var i = 0; i < 4; i++)
        Positioned(
          key: ValueKey('chess-promotion-${_letters[_order[i]]}'),
          left: col * cell,
          top: (down ? row + i : row - i) * cell,
          width: cell,
          height: cell,
          child: FocusableTap(
            onTap: () => onPick(_order[i]),
            semanticLabel: boardL10n(context)
                .chessPromoteTo(chessPieceWord(boardL10n(context), _order[i])),
            radius: cell * 0.2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(_order[i]),
              child: CustomPaint(
                painter: _PromotionTilePainter(
                  type: _order[i],
                  side: side,
                  style: style,
                  theme: theme,
                  dark: dark,
                  first: i == 0,
                ),
              ),
            ),
          ),
        ),
    ];
    final picker = Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: ColoredBox(color: theme.background.withValues(alpha: 0.42)),
          ),
        ),
        ...tiles,
      ],
    );
    if (calm) return picker;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: picker,
    );
  }
}

class _PromotionTilePainter extends CustomPainter {
  _PromotionTilePainter({
    required this.type,
    required this.side,
    required this.style,
    required this.theme,
    required this.dark,
    required this.first,
  });

  final int type;
  final int side;
  final ChessPieceStyle style;
  final AppTheme theme;
  final bool dark;
  final bool first;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height).deflate(size.width * 0.04);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(size.width * 0.18));
    canvas.drawRRect(
      rr.shift(Offset(0, size.width * 0.03)),
      Paint()..color = const Color(0xFF000000).withValues(alpha: dark ? 0.35 : 0.14),
    );
    canvas.drawRRect(rr, Paint()..color = theme.surfaceRaised);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.ink.withValues(alpha: dark ? 0.14 : 0.08),
    );
    if (first) {
      canvas.drawRRect(
        rr,
        Paint()..color = theme.accent.withValues(alpha: dark ? 0.20 : 0.14),
      );
    }
    canvas.save();
    canvas.translate(r.left + r.width * 0.06, r.top + r.height * 0.04);
    canvas.scale(r.width * 0.88);
    style.paint(canvas, type, side);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PromotionTilePainter old) =>
      old.type != type || old.side != side || old.theme != theme || old.first != first;
}

/// Per-size art: the dark squares as one path, and the coordinate labels.
class _ChessArt {
  _ChessArt(this.side) {
    final cell = side / 8;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if ((r + c).isOdd) {
          darkSquares.addRect(Rect.fromLTWH(c * cell, r * cell, cell, cell));
        }
      }
    }
  }

  final double side;

  /// A 180 degree turn maps dark squares onto dark squares, so one path
  /// serves both orientations.
  final Path darkSquares = Path();

  final _labels = <(String, Color, TextStyle), TextPainter>{};

  /// A coordinate label, laid out once per size, colour and face. [base] is
  /// the theme's caption face, so the label is set in the app's type rather
  /// than in whatever the engine falls back to.
  TextPainter label(String text, Color color, TextStyle base) =>
      _labels[(text, color, base)] ??= TextPainter(
        text: TextSpan(
          text: text,
          style: base.copyWith(
            color: color,
            fontSize: side / 8 * 0.18,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
}

final _art = SizeCache<_ChessArt>((s) => _ChessArt(s.width));

/// Paints squares, highlights, coordinates, pieces and the move animation.
class ChessPainter extends CustomPainter {
  ChessPainter({
    required this.state,
    required this.theme,
    required this.dark,
    required this.flipped,
    required this.thumbnail,
    required this.clock,
    this.anim,
    this.selected,
    this.targets = const {},
    this.drag,
    this.last,
  }) : style = ChessPieceStyle(darkTheme: dark),
       super(repaint: clock.animation);

  final ChessState state;
  final AppTheme theme;
  final bool dark;
  final bool flipped;
  final bool thumbnail;
  final BoardClock clock;
  final ChessAnimation? anim;
  final int? selected;
  final Set<int> targets;
  final Offset? drag;

  /// The previous move's from and to squares, tinted.
  final (int, int)? last;

  final ChessPieceStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final g = ChessGeometry(size, flipped: flipped);
    if (g.side <= 0) return;
    final cell = g.cell;
    final art = _art.of(Size.square(g.side));
    final ink = theme.ink;
    final rect = Offset.zero & Size.square(g.side);

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(g.side * 0.03)));
    // The checkers neutrals: the card's raised surface, and that surface
    // with ink worked in, so the board belongs to whichever theme it is on.
    canvas.drawRect(
      rect,
      Paint()..color = Color.alphaBlend(ink.withValues(alpha: dark ? 0.05 : 0.03), theme.surfaceRaised),
    );
    canvas.drawPath(
      art.darkSquares,
      Paint()..color = Color.alphaBlend(ink.withValues(alpha: dark ? 0.15 : 0.13), theme.surfaceRaised),
    );

    final l = last;
    if (l != null) {
      final tint = Paint()..color = theme.accent.withValues(alpha: dark ? 0.24 : 0.20);
      canvas.drawRect(g.square(l.$1), tint);
      canvas.drawRect(g.square(l.$2), tint);
    }
    final sel = selected;
    if (sel != null) {
      canvas.drawRect(
        g.square(sel),
        Paint()..color = theme.accent.withValues(alpha: dark ? 0.38 : 0.32),
      );
    }

    // Check: a soft glow of the danger colour under the king, brightest at
    // its feet, gone before the square's edge.
    if (state.inCheck) {
      final k = g.square(state.kingSquare(state.turn));
      canvas.drawRect(
        k,
        Paint()
          ..shader = ui.Gradient.radial(k.center, cell * 0.62, [
            theme.danger.withValues(alpha: 0.85),
            theme.danger.withValues(alpha: 0.35),
            theme.danger.withValues(alpha: 0),
          ], const [0, 0.55, 1]),
      );
    }

    if (!thumbnail) _coordinates(canvas, g, art);

    // Legal squares for the selection: a dot on an empty one, a ring that
    // frames the piece on one that is taken.
    final mark = Paint()..color = ink.withValues(alpha: dark ? 0.30 : 0.22);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.075
      ..color = mark.color;
    for (final t in targets) {
      final c = g.center(t);
      // En passant lands on an empty square, so it gets a dot.
      if (state.pieceAt(t) != 0) {
        canvas.drawCircle(c, cell * 0.46, ring);
      } else {
        canvas.drawCircle(c, cell * 0.155, mark);
      }
    }

    final a = anim;
    final ms = clock.ms;
    final moving = a != null && ms != double.infinity;
    final hidden = <int>{
      if (moving) for (final s in a.slides) s.to,
      if (drag != null && sel != null) sel,
    };

    for (var sq = 0; sq < 64; sq++) {
      final p = state.pieceAt(sq);
      if (p == 0 || hidden.contains(sq)) continue;
      _piece(canvas, g.square(sq), p);
    }

    if (moving) {
      final t = easeOutCubic(clock.phase(0, _slideMs));
      final cap = a.captured;
      if (cap != null) {
        _piece(canvas, g.square(cap.$1), cap.$2, alpha: 1 - t);
      }
      for (final s in a.slides) {
        final at = Rect.lerp(g.square(s.from), g.square(s.to), t)!;
        _piece(canvas, at, s.piece);
      }
    }

    final d = drag;
    if (d != null && sel != null) {
      // Lifted: a little larger, and held above the finger so it stays in
      // sight while the finger covers the square it is aiming at.
      final size = cell * 1.25;
      final at = Rect.fromCenter(center: d - Offset(0, cell * 0.45), width: size, height: size);
      final hover = g.squareAt(d);
      if (hover != null && targets.contains(hover)) {
        canvas.drawRect(
          g.square(hover),
          Paint()..color = ink.withValues(alpha: dark ? 0.14 : 0.10),
        );
      }
      _piece(canvas, at, state.pieceAt(sel));
    }
    canvas.restore();
  }

  void _piece(Canvas canvas, Rect square, int piece, {double alpha = 1}) {
    canvas.save();
    // The art's own margins already keep it off the square's edges; the
    // nudge down sets the plinth near the bottom, where a piece stands.
    canvas.translate(square.left - square.width * 0.01, square.top + square.height * 0.035);
    canvas.scale(square.width * 1.02);
    style.paint(canvas, piece & 7, piece >> 3, alpha: alpha, shadow: !thumbnail);
    canvas.restore();
  }

  /// Files along the bottom edge (in each square's lower right), ranks down
  /// the left edge (upper left), whichever way round the board is.
  void _coordinates(Canvas canvas, ChessGeometry g, _ChessArt art) {
    final cell = g.cell;
    final color = theme.inkMuted;
    final base = theme.caption;
    final pad = cell * 0.06;
    for (var c = 0; c < 8; c++) {
      final file = flipped ? 7 - c : c;
      final t = art.label(String.fromCharCode(0x61 + file), color, base);
      t.paint(canvas, Offset((c + 1) * cell - pad - t.width, 8 * cell - pad - t.height));
    }
    for (var r = 0; r < 8; r++) {
      final rank = flipped ? r + 1 : 8 - r;
      art.label('$rank', color, base).paint(canvas, Offset(pad, r * cell + pad));
    }
  }

  @override
  bool shouldRepaint(ChessPainter old) =>
      old.state != state ||
      old.theme != theme ||
      old.dark != dark ||
      old.flipped != flipped ||
      old.anim != anim ||
      old.selected != selected ||
      old.drag != drag ||
      old.last != last ||
      !_sameSet(old.targets, targets) ||
      old.clock.animation != clock.animation ||
      old.clock.totalMs != clock.totalMs;

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// A piece type's name in the reader's language.
String chessPieceWord(AppLocalizations l10n, int type) => switch (type) {
  chessPawn => l10n.chessPawn,
  chessKnight => l10n.chessKnight,
  chessBishop => l10n.chessBishop,
  chessRook => l10n.chessRook,
  chessQueen => l10n.chessQueen,
  _ => l10n.chessKing,
};
