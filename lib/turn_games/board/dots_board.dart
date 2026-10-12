import 'dart:math' as math;

import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../dots.dart';
import 'board_kit.dart';
import 'seat_palette.dart';

/// A new line grows out from its middle; a box it closes washes in after.
const double _lineMs = 190;
const double _boxDelayMs = 120;
const double _boxMs = 240;

/// How far from an edge a touch still picks it, in cells.
const double _reach = 0.35;

/// Padding round the outer dots, in cells: room for the dot itself and for a
/// thumb aimed at the border edges.
const double _pad = 0.32;

/// Where a Dots board's dots and edges are.
class DotsLayout {
  DotsLayout(Size size, this.rows, this.cols)
    : cell = math.min(size.width / (cols + 2 * _pad), size.height / (rows + 2 * _pad)) {
    origin = Offset(
      (size.width - cell * cols) / 2,
      (size.height - cell * rows) / 2,
    );
  }

  final int rows;
  final int cols;
  final double cell;
  late final Offset origin;

  Offset dot(int r, int c) => origin + Offset(c * cell, r * cell);

  int get horizontals => (rows + 1) * cols;

  /// The two dots line [i] joins.
  (Offset, Offset) line(int i) {
    if (i < horizontals) {
      final r = i ~/ cols;
      final c = i % cols;
      return (dot(r, c), dot(r, c + 1));
    }
    final v = i - horizontals;
    final r = v ~/ (cols + 1);
    final c = v % (cols + 1);
    return (dot(r, c), dot(r + 1, c));
  }

  Rect box(int b) => Rect.fromLTWH(
    origin.dx + (b % cols) * cell,
    origin.dy + (b ~/ cols) * cell,
    cell,
    cell,
  );

  /// The undrawn line nearest [p] within [_reach] of a cell, or null.
  int? nearest(Offset p, List<bool> drawn) {
    int? best;
    var bestD = _reach * cell;
    for (var i = 0; i < drawn.length; i++) {
      if (drawn[i]) continue;
      final (a, b) = line(i);
      final d = _distance(p, a, b);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  static double _distance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    final t = len2 == 0
        ? 0.0
        : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  static double aspect(int rows, int cols) => (cols + 2 * _pad) / (rows + 2 * _pad);
}

/// Dots and Boxes: draw an edge, close a box, go again.
class DotsBoardView extends BoardView {
  const DotsBoardView({super.key, required super.props});

  @override
  State<DotsBoardView> createState() => _DotsBoardState();
}

class _DotsBoardState extends BoardViewState<DotsBoardView> {
  DotsState? _s;

  /// The line that just went down and who drew it, for the colour.
  int? _fresh;
  int? _freshSeat;
  Set<int> _freshBoxes = const {};
  bool _animatingFresh = false;

  int? _ghost;

  /// Laid-out seat initials, one per seat, rebuilt only when the size or
  /// colour changes. Without it every claimed box would lay its letter out
  /// again every frame a line was growing.
  final _glyphs = DotsGlyphs();

  @override
  void initState() {
    super.initState();
    _s = _decode(widget.props.state);
    _resolveFresh(null);
  }

  @override
  void dispose() {
    _glyphs.dispose();
    super.dispose();
  }

  static DotsState? _decode(String raw) {
    try {
      return dotsRules.decode(raw);
    } on FormatException {
      return null;
    }
  }

  /// Works out which line is newest and whose it was, and returns whether
  /// it was a single step from [before] (and so should animate).
  ///
  /// The state keeps no author per line, so: the one new line since
  /// [before], else the [TurnBoard.lastMove] token. The drawer is the owner
  /// of any box the line borders that is now closed (a line that closes a
  /// box keeps the turn, and a box beside it that is closed now was closed
  /// by it, since the line was open until this move), otherwise the seat
  /// before the one now to move.
  bool _resolveFresh(DotsState? before) {
    final s = _s;
    _fresh = null;
    _freshSeat = null;
    _freshBoxes = const {};
    if (s == null) return false;
    int? line;
    var step = false;
    if (before != null && before.lines.length == s.lines.length) {
      int? added;
      var changes = 0;
      for (var i = 0; i < s.lines.length; i++) {
        if (before.lines[i] != s.lines[i]) {
          changes++;
          if (s.lines[i]) added = i;
        }
      }
      if (changes == 1 && added != null) {
        line = added;
        step = true;
      }
    }
    final raw = widget.props.lastMove;
    if (line == null && raw != null) {
      try {
        final v = dotsRules.decodeMove(raw);
        if (v < s.lines.length && s.lines[v]) line = v;
      } on FormatException {
        line = null;
      }
    }
    if (line == null) return false;
    int? seat;
    final closed = <int>{};
    for (final b in s.geometry.lineBoxes[line]) {
      if (s.owners[b] >= 0) {
        seat = s.owners[b];
        closed.add(b);
      }
    }
    _fresh = line;
    _freshSeat = seat ?? (s.toMove - 1 + s.seats) % s.seats;
    if (step) _freshBoxes = closed;
    return step;
  }

  @override
  void didUpdateWidget(DotsBoardView old) {
    super.didUpdateWidget(old);
    if (old.props.state == widget.props.state &&
        old.props.lastMove == widget.props.lastMove) {
      return;
    }
    final before = _s;
    final next = _decode(widget.props.state);
    if (next == null) return;
    _s = next;
    _ghost = null;
    final moved = old.props.state != widget.props.state;
    _animatingFresh = _resolveFresh(moved ? before : null);
    play(_animatingFresh
        ? (_freshBoxes.isEmpty ? _lineMs : _boxDelayMs + _boxMs)
        : 0);
  }

  bool _legal(int line) {
    final s = _s;
    if (s == null || !widget.props.canMoveFor(s.toMove)) return false;
    return line >= 0 && line < s.lines.length && !s.lines[line];
  }

  int? _lineAt(Offset p) {
    final s = _s;
    final box = context.findRenderObject() as RenderBox?;
    if (s == null || box == null) return null;
    return DotsLayout(box.size, s.rows, s.cols).nearest(p, s.lines);
  }

  void _hoverAt(Offset p) {
    final line = _lineAt(p);
    final next = line != null && _legal(line) ? line : null;
    if (next == _ghost) return;
    if (next != null && _ghost != null) BoardHaptics.tick();
    setState(() => _ghost = next);
  }

  void _commit() {
    final line = _ghost;
    setState(() => _ghost = null);
    if (line != null) _emit(line);
  }

  void _emit(int line) {
    if (!_legal(line)) return;
    BoardHaptics.land();
    widget.props.onMove!(dotsRules.encodeMove(line));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final p = widget.props;
    final l10n = boardL10n(context);
    final canMove = p.canMoveFor(s.toMove);
    final outcome = dotsRules.outcome(s);
    return boardSurface(
      props: p,
      painter: DotsPainter(
        state: s,
        seats: p.seats,
        theme: p.theme,
        labels: [for (var i = 0; i < s.seats; i++) p.seatLabel(i)],
        glyphs: _glyphs,
        fresh: _fresh,
        freshSeat: _freshSeat,
        freshBoxes: _freshBoxes,
        animateFresh: _animatingFresh,
        ghost: _ghost,
        ghostSeat: p.mySeat ?? s.toMove,
        winner: p.winLine ? outcome?.winner : null,
        clock: clock,
      ),
      semantics: BoardSemanticsPainter(
        version: '${p.state}|$canMove',
        nodes: (size) {
          final l = DotsLayout(size, s.rows, s.cols);
          return [
            for (var b = 0; b < s.owners.length; b++)
              boardNode(
                l.box(b).deflate(l.cell * 0.2),
                '${l10n.boardBoxName(cellName(l10n, b ~/ s.cols, b % s.cols))}, '
                '${s.owners[b] < 0 ? l10n.boardOpen : l10n.boardClaimedBy(p.seatLabel(s.owners[b]))}',
              ),
            for (var i = 0; i < s.lines.length; i++)
              boardNode(
                _lineRect(l, i),
                '${_lineName(l10n, l, i)}, '
                '${s.lines[i] ? l10n.boardDrawn : l10n.boardOpen}',
                onTap: _legal(i) ? () => _emit(i) : null,
              ),
          ];
        },
      ),
      gestures: canMove
          ? (child) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _hoverAt(d.localPosition),
              onTapUp: (d) {
                _hoverAt(d.localPosition);
                _commit();
              },
              onPanStart: (d) => _hoverAt(d.localPosition),
              onPanUpdate: (d) => _hoverAt(d.localPosition),
              onPanEnd: (_) => _commit(),
              onPanCancel: () {
                // A pan that never claimed the arena cancels here before the
                // tap resolves; the tap owns the ghost from then on.
              },
              child: child,
            )
          : null,
    );
  }

  static Rect _lineRect(DotsLayout l, int i) {
    final (a, b) = l.line(i);
    return Rect.fromPoints(a, b).inflate(l.cell * 0.18);
  }

  static String _lineName(AppLocalizations l10n, DotsLayout l, int i) {
    if (i < l.horizontals) {
      return l10n.boardHorizontalEdge(i ~/ l.cols + 1, i % l.cols + 1);
    }
    final v = i - l.horizontals;
    return l10n.boardVerticalEdge(v ~/ (l.cols + 1) + 1, v % (l.cols + 1) + 1);
  }
}

/// Seat initials, laid out once per (label, size, colour).
class DotsGlyphs {
  final _painters = <(String, int, Color), TextPainter>{};

  /// [base] is the theme's own emphasis face, so the initial is set in the
  /// app's type rather than whatever the engine falls back to.
  TextPainter of(String label, double size, Color color, TextStyle base) {
    final key = (label, (size * 2).round(), color);
    return _painters.putIfAbsent(key, () {
      if (_painters.length > 16) dispose();
      return TextPainter(
        text: TextSpan(
          text: label,
          style: base.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    });
  }

  void dispose() {
    for (final p in _painters.values) {
      p.dispose();
    }
    _painters.clear();
  }
}

/// Paints boxes, edges, the newest edge in its drawer's colour, and dots.
class DotsPainter extends CustomPainter {
  DotsPainter({
    required this.state,
    required this.seats,
    required this.theme,
    required this.labels,
    required this.glyphs,
    required this.clock,
    this.fresh,
    this.freshSeat,
    this.freshBoxes = const {},
    this.animateFresh = false,
    this.ghost,
    this.ghostSeat = 0,
    this.winner,
  }) : super(repaint: clock.animation);

  final DotsState state;
  final SeatPalette seats;
  final AppTheme theme;
  final List<String> labels;
  final DotsGlyphs glyphs;
  final BoardClock clock;
  final int? fresh;
  final int? freshSeat;
  final Set<int> freshBoxes;
  final bool animateFresh;
  final int? ghost;
  final int ghostSeat;

  /// The winning seat of a finished game; everyone else's boxes step back.
  final int? winner;

  @override
  void paint(Canvas canvas, Size size) {
    final s = state;
    final l = DotsLayout(size, s.rows, s.cols);
    if (l.cell <= 0) return;
    final ink = theme.ink;
    final lineW = math.max(2.0, l.cell * 0.075);

    final boxT = animateFresh ? easeOutCubic(clock.phase(_boxDelayMs, _boxMs)) : 1.0;
    final wash = Paint();
    final radius = Radius.circular(l.cell * 0.12);
    for (var b = 0; b < s.owners.length; b++) {
      final owner = s.owners[b];
      if (owner < 0) continue;
      final t = freshBoxes.contains(b) ? boxT : 1.0;
      if (t <= 0) continue;
      final dim = winner != null && owner != winner ? 0.5 : 1.0;
      final rect = l.box(b).deflate(lineW * 0.9);
      wash.color = seats.wash(owner).withValues(alpha: seats.wash(owner).a * t * dim);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), wash);
      // The dimmed colour is part of the glyph cache key (it is static once
      // the game is over); the fade-in alpha is not, or a growing box would
      // lay its letter out again every frame. That one goes through a layer,
      // for the two boxes a line can close at most.
      final glyph = glyphs.of(
        labels[owner],
        l.cell * 0.4,
        seats.fill(owner).withValues(alpha: dim),
        theme.bodyEmph,
      );
      final scale = 0.7 + 0.3 * t;
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      if (scale != 1) canvas.scale(scale);
      if (t < 1) {
        canvas.saveLayer(
          Rect.fromCenter(center: Offset.zero, width: glyph.width + 2, height: glyph.height + 2),
          Paint()..color = Color.fromRGBO(0, 0, 0, t),
        );
        glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
        canvas.restore();
      } else {
        glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      }
      canvas.restore();
    }

    // Open edges as the faintest guide, so the board shows where a line can
    // go before the first one is drawn.
    final guide = Paint()
      ..color = ink.withValues(alpha: 0.07)
      ..strokeWidth = lineW * 0.6
      ..strokeCap = StrokeCap.round;
    final drawn = Paint()
      ..color = ink.withValues(alpha: 0.55)
      ..strokeWidth = lineW
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < s.lines.length; i++) {
      if (i == fresh || i == ghost) continue;
      final (a, b) = l.line(i);
      canvas.drawLine(a, b, s.lines[i] ? drawn : guide);
    }

    final g = ghost;
    if (g != null) {
      final (a, b) = l.line(g);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = seats.ghost(ghostSeat)
          ..strokeWidth = lineW * 1.25
          ..strokeCap = StrokeCap.round,
      );
    }

    final f = fresh;
    if (f != null && s.lines[f]) {
      final (a, b) = l.line(f);
      final t = animateFresh ? easeOutCubic(clock.phase(0, _lineMs)) : 1.0;
      final mid = Offset.lerp(a, b, 0.5)!;
      canvas.drawLine(
        Offset.lerp(mid, a, t)!,
        Offset.lerp(mid, b, t)!,
        Paint()
          ..color = seats.fill(freshSeat ?? 0)
          ..strokeWidth = lineW
          ..strokeCap = StrokeCap.round,
      );
    }

    // Dots last, so every line ends under a round cap of its own.
    final dot = Paint()..color = ink;
    final r = math.max(2.2, l.cell * 0.075);
    for (var row = 0; row <= s.rows; row++) {
      for (var c = 0; c <= s.cols; c++) {
        canvas.drawCircle(l.dot(row, c), r, dot);
      }
    }
  }

  @override
  bool shouldRepaint(DotsPainter old) =>
      old.state != state ||
      old.seats != seats ||
      old.theme != theme ||
      old.fresh != fresh ||
      old.freshSeat != freshSeat ||
      old.freshBoxes != freshBoxes ||
      old.animateFresh != animateFresh ||
      old.ghost != ghost ||
      old.ghostSeat != ghostSeat ||
      old.winner != winner ||
      old.clock.animation != clock.animation ||
      old.clock.totalMs != clock.totalMs;
}
