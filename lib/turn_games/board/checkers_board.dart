import 'dart:math' as math;
import '../../l10n/generated/app_localizations.dart';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../games/game_canvas.dart' show paintCrown;
import '../../theme/app_theme.dart';
import '../checkers.dart';
import '../turn_rules.dart';
import 'board_kit.dart';
import 'seat_palette.dart';

/// One hop of a move, slid; a jumped piece shrinks away while the jumper
/// passes over it.
const double _hopMs = 180;

/// PDN square (0-based) to its row and column on the 8x8 board, row 0 at
/// dark's back rank. Mirrors the private `_rowOf` / `_colOf` in the rules.
int _rowOf(int sq) => sq ~/ 4;
int _colOf(int sq) => _rowOf(sq).isEven ? 2 * (sq % 4) + 1 : 2 * (sq % 4);

/// Piece codes, as `CheckersState.board` holds them.
int _sideOf(int p) => p == 0 ? -1 : (p <= 2 ? 0 : 1);
bool _isKing(int p) => p == 2 || p == 4;

/// Where the board's squares are drawn.
///
/// [flipped] turns the board round so the viewer's own men start at the
/// bottom: dark (seat 0) starts on the top rows in PDN, so dark's player sees
/// it rotated. Light's player and spectators see it as printed.
class CheckersGeometry {
  CheckersGeometry(Size size, {required this.flipped})
    : side = math.min(size.width, size.height);

  final double side;
  final bool flipped;

  double get cell => side / 8;
  double get radius => cell * 0.38;

  Offset center(int sq) {
    var r = _rowOf(sq);
    var c = _colOf(sq);
    if (flipped) {
      r = 7 - r;
      c = 7 - c;
    }
    return Offset((c + 0.5) * cell, (r + 0.5) * cell);
  }

  Rect square(int sq) => Rect.fromCenter(center: center(sq), width: cell, height: cell);

  /// The playable square under [p], or null for a light square or off-board.
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
    if ((r + c).isEven) return null;
    return r * 4 + (c >> 1);
  }
}

/// Checkers: tap a piece, then tap where it lands, hop by hop.
class CheckersBoardView extends BoardView {
  const CheckersBoardView({super.key, required super.props});

  @override
  State<CheckersBoardView> createState() => _CheckersBoardState();
}

/// A move as the painter animates it: the piece, its path and what it took.
class CheckersAnimation {
  const CheckersAnimation({
    required this.piece,
    required this.path,
    required this.captured,
  });

  /// The piece code before the move (a man that crowns travels as a man).
  final int piece;
  final List<int> path;

  /// Jumped squares with the piece code that stood there, in jump order.
  final List<(int, int)> captured;
}

class _CheckersBoardState extends BoardViewState<CheckersBoardView> {
  CheckersState? _s;
  List<CheckersMove> _legal = const [];

  /// The move being assembled: the selected piece's square first, then each
  /// landing tapped so far.
  List<int> _path = const [];

  CheckersAnimation? _anim;

  @override
  void initState() {
    super.initState();
    _s = _decode(widget.props.state);
    _refreshLegal();
  }

  static CheckersState? _decode(String raw) {
    try {
      return checkersRules.decode(raw);
    } on FormatException {
      return null;
    }
  }

  void _refreshLegal() {
    final s = _s;
    _legal = s != null && widget.props.canMoveFor(s.turn)
        ? checkersRules.legalMoves(s)
        : const [];
  }

  @override
  void didUpdateWidget(CheckersBoardView old) {
    super.didUpdateWidget(old);
    if (old.props.state == widget.props.state) {
      if (old.props.enabled != widget.props.enabled ||
          old.props.mySeat != widget.props.mySeat) {
        _refreshLegal();
        _path = const [];
      }
      return;
    }
    final before = _s;
    final next = _decode(widget.props.state);
    if (next == null) return;
    _s = next;
    _path = const [];
    _anim = null;
    _refreshLegal();
    if (before == null) return;
    final move = _inferMove(before, next);
    if (move == null) {
      play(0);
      return;
    }
    _anim = move;
    play(_hopMs * (move.path.length - 1));
  }

  /// The move that took [a] to [b], from [TurnBoard.lastMove] when it agrees
  /// with the boards, else read off the difference: the mover's piece left
  /// one square and arrived on another, and whatever of the other side's
  /// vanished was jumped. A multi-jump read off a diff has no landings, so it
  /// slides straight; the token, when given, gives the true route.
  CheckersAnimation? _inferMove(CheckersState a, CheckersState b) {
    final mover = a.turn;
    final raw = widget.props.lastMove;
    if (raw != null) {
      try {
        final m = checkersRules.decodeMove(raw);
        final piece = a.board[m.from];
        if (_sideOf(piece) == mover &&
            _sideOf(b.board[m.to]) == mover &&
            (m.from == m.to || b.board[m.from] == 0)) {
          return CheckersAnimation(
            piece: piece,
            path: m.squares,
            captured: [for (final c in m.captures) if (c >= 0) (c, a.board[c])],
          );
        }
      } on FormatException {
        // Fall through to the diff.
      } on IllegalMove {
        // Fall through to the diff.
      }
    }
    int? from;
    int? to;
    final captured = <(int, int)>[];
    for (var i = 0; i < 32; i++) {
      final x = a.board[i];
      final y = b.board[i];
      if (x == y) continue;
      if (_sideOf(x) == mover && y == 0) {
        if (from != null) return null;
        from = i;
      } else if (_sideOf(y) == mover && x == 0) {
        if (to != null) return null;
        to = i;
      } else if (_sideOf(x) == 1 - mover && y == 0) {
        captured.add((i, x));
      } else if (!(_sideOf(x) == mover && _sideOf(y) == mover)) {
        return null;
      }
    }
    if (from == null || to == null) return null;
    return CheckersAnimation(piece: a.board[from], path: [from, to], captured: captured);
  }

  bool get _flipped => widget.props.mySeat == 0;

  CheckersGeometry _geometry() {
    final box = context.findRenderObject() as RenderBox?;
    return CheckersGeometry(box?.size ?? Size.zero, flipped: _flipped);
  }

  /// Legal moves that begin with [_path].
  Iterable<CheckersMove> get _candidates sync* {
    for (final m in _legal) {
      if (m.squares.length < _path.length) continue;
      var ok = true;
      for (var i = 0; i < _path.length; i++) {
        if (m.squares[i] != _path[i]) {
          ok = false;
          break;
        }
      }
      if (ok) yield m;
    }
  }

  /// Squares a tap may take [_path] to next.
  Set<int> get _targets {
    if (_path.isEmpty) return const {};
    return {
      for (final m in _candidates)
        if (m.squares.length > _path.length) m.squares[_path.length],
    };
  }

  bool _hasMoveFrom(int sq) => _legal.any((m) => m.from == sq);

  void _tap(int? sq) {
    if (_legal.isEmpty) return;
    if (sq == null) {
      if (_path.isNotEmpty) setState(() => _path = const []);
      return;
    }
    if (_path.isNotEmpty) {
      if (_targets.contains(sq)) {
        _extend([..._path, sq]);
        return;
      }
      // A tap on a later landing of exactly one route is that route: there
      // is no reading of it but one, and tapping every hop of a long jump is
      // bookkeeping, not play.
      final routes = [
        for (final m in _candidates)
          if (m.squares.indexOf(sq) > _path.length - 1) m,
      ];
      if (routes.length == 1) {
        final m = routes.first;
        _extend(m.squares.sublist(0, m.squares.indexOf(sq) + 1));
        return;
      }
      if (_path.length == 1 && sq == _path.first) {
        setState(() => _path = const []);
        return;
      }
    }
    if ((_path.length <= 1) && _hasMoveFrom(sq)) {
      BoardHaptics.tick();
      setState(() => _path = [sq]);
      return;
    }
    if (_path.isNotEmpty) setState(() => _path = const []);
  }

  void _extend(List<int> path) {
    for (final m in _legal) {
      if (_samePath(m.squares, path)) {
        setState(() => _path = const []);
        _emit(m);
        return;
      }
    }
    BoardHaptics.tick();
    setState(() => _path = path);
  }

  static bool _samePath(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _emit(CheckersMove m) {
    final s = _s;
    if (s == null || !widget.props.canMoveFor(s.turn)) return;
    final token = checkersRules.encodeMove(m);
    // Only a token the rules list leaves the board.
    if (!checkersRules.legalMoves(s).any((x) => x.token == token)) return;
    BoardHaptics.land();
    widget.props.onMove!(token);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final p = widget.props;
    final l10n = boardL10n(context);
    final canMove = _legal.isNotEmpty;
    final mustCapture = canMove && _legal.first.isCapture;
    List<int>? lastPath;
    // Thumbnails too: a move bubble's board is about the move it shows.
    if (p.lastMove != null) {
      try {
        lastPath = checkersRules.decodeMove(p.lastMove!).squares;
      } on FormatException {
        lastPath = null;
      }
    }
    final painter = CheckersPainter(
      board: s.board,
      seats: p.seats,
      theme: p.theme,
      flipped: _flipped,
      clock: clock,
      anim: _anim,
      path: _path,
      targets: _targets,
      capturers: mustCapture && _path.isEmpty
          ? {for (final m in _legal) m.from}
          : const {},
      moverSeat: s.turn,
      last: lastPath,
    );
    return boardSurface(
      props: p,
      painter: painter,
      semantics: BoardSemanticsPainter(
        version: '${p.state}|$canMove|${_path.join(',')}',
        nodes: (size) {
          final g = CheckersGeometry(size, flipped: _flipped);
          final targets = _targets;
          return [
            for (var sq = 0; sq < 32; sq++)
              boardNode(
                g.square(sq),
                '${l10n.boardSquareName(sq + 1)}, '
                '${_pieceName(l10n, s.board[sq])}'
                '${targets.contains(sq) ? ', ${l10n.boardMoveHere}' : ''}',
                selected: _path.isNotEmpty && _path.last == sq,
                onTap: canMove && (targets.contains(sq) || _hasMoveFrom(sq))
                    ? () => _tap(sq)
                    : null,
              ),
          ];
        },
      ),
      gestures: canMove
          ? (child) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tap(_geometry().squareAt(d.localPosition)),
              child: child,
            )
          : null,
    );
  }

  static String _pieceName(AppLocalizations l10n, int p) => switch (p) {
    1 => l10n.boardDarkMan,
    2 => l10n.boardDarkKing,
    3 => l10n.boardLightMan,
    4 => l10n.boardLightKing,
    _ => l10n.boardEmpty,
  };
}

/// Per-size art: the board's square paths and the two disc shaders.
class _CheckersArt {
  _CheckersArt(Size size) {
    final g = CheckersGeometry(size, flipped: false);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if ((r + c).isOdd) {
          darkSquares.addRect(Rect.fromLTWH(c * g.cell, r * g.cell, g.cell, g.cell));
        }
      }
    }
    shadow = discShadow(g.radius, alpha: 0.34);
    light = discLight(g.radius, highlight: 0.26, shade: 0.14);
  }

  /// Rotating the board 180 degrees maps dark squares onto dark squares, so
  /// one path serves both orientations.
  final Path darkSquares = Path();

  /// The soft shadow under every piece. The brief asked for a Picture with a
  /// blur baked in; a Picture replays its blur every time it is drawn, so
  /// this is the same falloff as a radial gradient, which costs nothing.
  late final ui.Shader shadow;
  late final ui.Shader light;
}

final _art = SizeCache<_CheckersArt>(_CheckersArt.new);

/// Paints the squares, the pieces, selection, targets and the hop animation.
class CheckersPainter extends CustomPainter {
  CheckersPainter({
    required this.board,
    required this.seats,
    required this.theme,
    required this.flipped,
    required this.clock,
    this.anim,
    this.path = const [],
    this.targets = const {},
    this.capturers = const {},
    this.moverSeat = 0,
    this.last,
  }) : super(repaint: clock.animation);

  final List<int> board;
  final SeatPalette seats;
  final AppTheme theme;
  final bool flipped;
  final BoardClock clock;
  final CheckersAnimation? anim;

  /// The move being assembled by the viewer.
  final List<int> path;
  final Set<int> targets;

  /// Pieces that can capture while a capture is mandatory.
  final Set<int> capturers;
  final int moverSeat;

  /// The previous move's squares, tinted.
  final List<int>? last;

  @override
  void paint(Canvas canvas, Size size) {
    final g = CheckersGeometry(size, flipped: flipped);
    if (g.side <= 0) return;
    final art = _art.of(Size.square(g.side));
    final dark = seats.dark;
    final ink = theme.ink;

    // Squares: themed neutrals, never wood. The light squares are the card's
    // own surface lifted a touch; the dark ones are that surface with ink
    // worked in, so the board belongs to whatever theme it is on.
    final rect = Offset.zero & Size.square(g.side);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(g.side * 0.03)));
    canvas.drawRect(
      rect,
      Paint()..color = Color.alphaBlend(ink.withValues(alpha: dark ? 0.05 : 0.03), theme.surfaceRaised),
    );
    canvas.drawPath(
      art.darkSquares,
      Paint()..color = Color.alphaBlend(ink.withValues(alpha: dark ? 0.15 : 0.13), theme.surfaceRaised),
    );

    final lastPath = last;
    if (lastPath != null && lastPath.length >= 2) {
      final tint = Paint()..color = theme.accent.withValues(alpha: dark ? 0.22 : 0.18);
      canvas.drawRect(g.square(lastPath.first), tint);
      canvas.drawRect(g.square(lastPath.last), tint);
    }

    final a = anim;
    final ms = clock.ms;
    final moving = a != null && ms != double.infinity;

    // The assembled path: the selected piece is drawn at its latest landing,
    // and what it has jumped so far steps back.
    final selecting = path.isNotEmpty;
    final jumpedSoFar = <int>{};
    if (selecting && path.length > 1) {
      for (var i = 0; i + 1 < path.length; i++) {
        final x = path[i];
        final y = path[i + 1];
        final r = (_rowOf(x) + _rowOf(y)) ~/ 2;
        final c = (_colOf(x) + _colOf(y)) ~/ 2;
        if ((r + c).isOdd) jumpedSoFar.add(r * 4 + (c >> 1));
      }
    }

    final fill = Paint();
    final stroke = Paint()..style = PaintingStyle.stroke;
    final shadow = Paint()..shader = art.shadow;
    final light = Paint()..shader = art.light;

    for (var sq = 0; sq < 32; sq++) {
      final p = board[sq];
      if (p == 0) continue;
      if (moving && sq == a.path.last) continue;
      if (selecting && sq == path.first) continue;
      final alpha = jumpedSoFar.contains(sq) ? 0.35 : 1.0;
      _piece(canvas, g, g.center(sq), p, 1, alpha, fill, stroke, shadow, light);
      if (capturers.contains(sq)) {
        stroke
          ..color = theme.accent
          ..strokeWidth = math.max(1.5, g.radius * 0.13);
        canvas.drawCircle(g.center(sq), g.radius * 1.12, stroke);
      }
    }

    if (moving) {
      // Captured pieces shrink and fade as the jumper passes over them.
      for (var k = 0; k < a.captured.length; k++) {
        final (sq, piece) = a.captured[k];
        final t = easeOutCubic(clock.phase(_hopMs * k + _hopMs * 0.35, _hopMs * 0.8));
        if (t >= 1) continue;
        _piece(canvas, g, g.center(sq), piece, 1 - 0.5 * t, 1 - t, fill, stroke, shadow, light);
      }
      final hops = a.path.length - 1;
      final total = _hopMs * hops;
      final along = (ms / total).clamp(0.0, 1.0) * hops;
      final hop = math.min(along.floor(), hops - 1);
      final t = easeInOutCubic(along - hop);
      final at = Offset.lerp(g.center(a.path[hop]), g.center(a.path[hop + 1]), t)!;
      // A jump arcs a little: lifted at the top of each hop.
      final lift = a.captured.isEmpty ? 1.0 : 1 + 0.08 * math.sin(math.pi * t);
      _piece(canvas, g, at, a.piece, lift, 1, fill, stroke, shadow, light);
    }

    if (selecting) {
      final at = g.center(path.last);
      _piece(canvas, g, at, board[path.first], 1.07, 1, fill, stroke, shadow, light);
      stroke
        ..color = theme.accent
        ..strokeWidth = math.max(1.5, g.radius * 0.13);
      canvas.drawCircle(at, g.radius * 1.17, stroke);
      final dot = Paint()..color = seats.fill(moverSeat).withValues(alpha: 0.55);
      for (final t in targets) {
        canvas.drawCircle(g.center(t), g.cell * 0.13, dot);
      }
    }
    canvas.restore();
  }

  void _piece(
    Canvas canvas,
    CheckersGeometry g,
    Offset at,
    int piece,
    double scale,
    double alpha,
    Paint fill,
    Paint stroke,
    Paint shadow,
    Paint light,
  ) {
    if (alpha <= 0) return;
    final seat = _sideOf(piece);
    final r = g.radius;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (scale != 1) canvas.scale(scale);
    if (alpha >= 1) canvas.drawCircle(Offset.zero, r, shadow);
    fill.color = seats.fill(seat).withValues(alpha: alpha);
    canvas.drawCircle(Offset.zero, r, fill);
    if (alpha >= 1) canvas.drawCircle(Offset.zero, r, light);
    stroke
      ..color = seats.rim(seat).withValues(alpha: alpha)
      ..strokeWidth = r * 0.07;
    canvas.drawCircle(Offset.zero, r * 0.965, stroke);
    // The groove a turned draughtsman has, a ring inset from the edge.
    stroke
      ..color = seats.rim(seat).withValues(alpha: 0.75 * alpha)
      ..strokeWidth = r * 0.08;
    canvas.drawCircle(Offset.zero, r * 0.70, stroke);
    final glyph = seats.ink(seat).withValues(alpha: alpha * 0.92);
    if (_isKing(piece)) {
      if (seat == 0) {
        fill.color = glyph;
        paintCrown(canvas, Offset(0, r * 0.03), r * 1.45, fill);
      } else {
        // Light's crown is outlined: a second cue beside the colour.
        stroke
          ..color = glyph
          ..strokeWidth = r * 0.1
          ..strokeJoin = StrokeJoin.round;
        paintCrown(canvas, Offset(0, r * 0.03), r * 1.38, stroke);
        stroke.strokeJoin = StrokeJoin.miter;
      }
    } else if (seat == 1) {
      // Light's men carry a centre dot, so the two sides differ in shape too.
      fill.color = glyph;
      canvas.drawCircle(Offset.zero, r * 0.17, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CheckersPainter old) =>
      old.board != board ||
      old.seats != seats ||
      old.theme != theme ||
      old.flipped != flipped ||
      old.anim != anim ||
      old.path != path ||
      !_sameSet(old.targets, targets) ||
      !_sameSet(old.capturers, capturers) ||
      old.moverSeat != moverSeat ||
      old.last?.join() != last?.join() ||
      old.clock.animation != clock.animation ||
      old.clock.totalMs != clock.totalMs;

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
