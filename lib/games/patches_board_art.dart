import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';
import 'game_rules.dart';

/// Paints a Patches board — the grid, a badge per clue, the patches the player
/// has cut, and the rectangle under their finger.
///
/// **The badge is the clue.** Its outline is the shape it asks for — a square,
/// an upright bar, a lying bar, or a circle for "any rectangle" — and the
/// number inside is the area, when the board prints one. A shape drawn as
/// itself needs no legend and no translation, and it stays readable on the hub
/// tile where a word or an icon font would be a smudge.
///
/// Each clue carries its colour from the start (clue k is palette entry k),
/// and its patch is laid down in the same colour, so "which clue is this patch
/// for" is answered before anyone asks. Colour is never the only signal: the
/// badge shape and the number carry every rule on their own.
///
/// Pass no [patches] and it draws today's clues alone, inert: the hub tile.
class PatchesBoardPainter extends CustomPainter {
  PatchesBoardPainter({
    required this.board,
    required this.theme,
    required this.palette,
    this.patches = const [],
    this.preview,
    this.previewClue = -1,
    this.previewOk = false,
    this.lifting = const {},
    this.popClue,
    this.pop = 1,
    this.win = 0,
  });

  final PatchesBoard board;
  final AppTheme theme;
  final GamePalette palette;

  /// One per clue, null where that clue has no patch yet.
  final List<PatchRect?> patches;

  /// The rectangle being dragged out, if any.
  final PatchRect? preview;

  /// The clue [preview] holds, or -1 for none or several.
  final int previewClue;

  /// Whether [preview] would be a legal patch if the finger lifted now.
  final bool previewOk;

  /// Patches the preview would lift off the board if it landed. Drawn faint,
  /// so the cost of the stroke is visible before it is paid.
  final Set<int> lifting;

  /// The patch that just landed, and how far through its settle it is.
  final int? popClue;
  final double pop;

  final double win;

  static final _backdrop = PathCache();
  static final _labels = GlyphTextCache();

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;

    // The empty grid, one path for all forty-nine squares.
    final backdrop = _backdrop.at((n, (cell * 4).round()), () {
      final path = Path();
      for (var i = 0; i < n * n; i++) {
        path.addRRect(
          RRect.fromRectAndRadius(
            grid.rect(i).deflate(cell * 0.05),
            Radius.circular(cell * 0.2),
          ),
        );
      }
      return path;
    });
    canvas.drawPath(backdrop, Paint()..color = theme.surfaceSunken);

    final fill = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, cell * 0.05);

    for (var k = 0; k < patches.length && k < board.clues.length; k++) {
      final rect = patches[k];
      if (rect == null) continue;
      final faint = lifting.contains(k);
      // A landing patch starts a touch small and settles to its size.
      final settle = k == popClue
          ? 1 - 0.06 * math.sin(pop.clamp(0.0, 1.0) * math.pi)
          : 1.0;
      final box = _box(grid, rect, settle);
      fill.color = faint ? _wash(palette.region(k), 0.3) : palette.region(k);
      canvas.drawRRect(box, fill);
      // The win sweep, one patch at a time: each lights as the wave passes
      // its middle. Every board's sweep is the same diagonal wave, but here
      // it moves through whole pieces; lit square by square, a solved board
      // would look gridded at exactly the moment it should look finished.
      if (win > 0) {
        final a = _sweepAt(rect, n);
        if (a > 0) {
          canvas.drawRRect(
            box,
            Paint()..color = theme.success.withValues(alpha: 0.45 * a),
          );
        }
      }
      edge.color = palette.regionInk(k).withValues(alpha: faint ? 0.35 : 0.9);
      canvas.drawRRect(box, edge);
    }

    final p = preview;
    if (p != null) {
      final box = _box(grid, p, 1);
      if (previewOk) {
        fill.color = _wash(palette.region(previewClue), 0.7);
        edge.color = palette.regionInk(previewClue);
      } else {
        fill.color = _wash(theme.surfaceSunken, 0.92);
        edge.color = theme.danger.withValues(alpha: 0.9);
      }
      canvas.drawRRect(box, fill);
      // Hatched, not just red: clue 0's colour is a red too, and "this will
      // not land" must never be mistaken for a patch that did.
      if (!previewOk) _hatch(canvas, box, cell);
      canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = edge.color
          ..strokeWidth = math.max(2, cell * 0.075),
      );
    }

    for (var k = 0; k < board.clues.length; k++) {
      _paintClue(canvas, grid, k);
    }

    if (p != null) _paintCount(canvas, grid, p);
  }

  /// How lit [rect] is [win] of the way through the sweep: the wave's value
  /// at the patch's middle, read off the same diagonal every board uses.
  double _sweepAt(PatchRect rect, int n) {
    final d = (rect.top + rect.bottom + rect.left + rect.right) / 2 / (2 * (n - 1));
    final t = (win * 1.6 - d).clamp(0.0, 1.0);
    return t <= 0 ? 0 : math.sin(t * math.pi).abs();
  }

  /// Diagonal danger stripes inside [box].
  void _hatch(Canvas canvas, RRect box, double cell) {
    final r = box.outerRect;
    final gap = cell * 0.22;
    final stripe = Paint()
      ..color = theme.danger.withValues(alpha: 0.35)
      ..strokeWidth = math.max(1.2, cell * 0.045);
    canvas.save();
    canvas.clipRRect(box);
    for (var x = r.left - r.height; x < r.right; x += gap) {
      canvas.drawLine(
        Offset(x, r.bottom),
        Offset(x + r.height, r.top),
        stripe,
      );
    }
    canvas.restore();
  }

  /// [colour] at [alpha], flattened onto the page colour.
  ///
  /// Opaque on purpose. A see-through fill over the grid lets every square's
  /// rounded backdrop show through as a seam, and a patch that looks gridded
  /// reads as a selection of squares rather than one piece.
  Color _wash(Color colour, double alpha) =>
      Color.alphaBlend(colour.withValues(alpha: alpha), theme.background);

  /// [rect]'s outline on the board, inset so neighbouring patches keep a
  /// visible seam between them.
  RRect _box(GameGrid grid, PatchRect rect, double scale) {
    final cell = grid.cell;
    final topLeft = grid.origin(rect.top * grid.n + rect.left);
    final r = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      rect.cols * cell,
      rect.rows * cell,
    ).deflate(cell * 0.07);
    final scaled = scale == 1
        ? r
        : Rect.fromCenter(
            center: r.center,
            width: r.width * scale,
            height: r.height * scale,
          );
    return RRect.fromRectAndRadius(scaled, Radius.circular(cell * 0.22));
  }

  void _paintClue(Canvas canvas, GameGrid grid, int k) {
    final clue = board.clues[k];
    final cell = grid.cell;
    final center = grid.center(clue.cell);
    final ink = palette.regionInk(k);
    final (w, h) = switch (clue.shape) {
      PatchShape.square => (0.6, 0.6),
      PatchShape.tall => (0.44, 0.7),
      PatchShape.wide => (0.7, 0.44),
      PatchShape.any => (0.64, 0.64),
    };
    final badge = Rect.fromCenter(
      center: center,
      width: cell * w,
      height: cell * h,
    );
    final shape = clue.shape == PatchShape.any
        ? RRect.fromRectAndRadius(badge, Radius.circular(badge.width / 2))
        : RRect.fromRectAndRadius(badge, Radius.circular(cell * 0.1));
    canvas.drawRRect(shape, Paint()..color = ink);
    // A hairline in the background colour, so the badge keeps an edge on top
    // of its own patch, which is the same hue.
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, cell * 0.035)
        ..color = theme.background.withValues(alpha: 0.55),
    );
    if (clue.area > 0) {
      _labels.paint(
        canvas,
        center,
        '${clue.area}',
        theme.body.copyWith(
          letterSpacing: 0,
          color: _onInk(ink),
          fontSize: _half(cell * (clue.area >= 10 ? 0.3 : 0.36)),
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
    }
  }

  /// The dragged rectangle's size, in a pill on its top edge: the number the
  /// player is matching against the badge, readable without counting squares.
  void _paintCount(Canvas canvas, GameGrid grid, PatchRect p) {
    final cell = grid.cell;
    final box = _box(grid, p, 1).outerRect;
    final pill = Rect.fromCenter(
      center: Offset(
        box.center.dx,
        // On the top edge, or just inside it on the top row where above
        // would be off the board.
        p.top == 0 ? box.top + cell * 0.24 : box.top,
      ),
      width: cell * (p.area >= 10 ? 0.62 : 0.5),
      height: cell * 0.4,
    );
    final colour = previewOk ? palette.regionInk(previewClue) : theme.danger;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pill, Radius.circular(pill.height / 2)),
      Paint()..color = colour,
    );
    _labels.paint(
      canvas,
      pill.center,
      '${p.area}',
      theme.body.copyWith(
        letterSpacing: 0,
        color: _onInk(colour),
        fontSize: _half(cell * 0.27),
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }

  @override
  bool shouldRepaint(PatchesBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.patches != patches ||
      old.preview != preview ||
      old.previewClue != previewClue ||
      old.previewOk != previewOk ||
      old.lifting != lifting ||
      old.popClue != popClue ||
      old.pop != pop ||
      old.win != win;
}

/// Dark text on a light fill and light on a dark one, decided by the fill:
/// the same hue is pale on one theme and deep on another.
Color _onInk(Color ink) => ink.computeLuminance() > 0.35
    ? const Color(0xE6000000)
    : const Color(0xFFFFFFFF);

/// Rounds a font size to the half pixel, so cached labels are reused rather
/// than re-laid out per fractional pixel.
double _half(double size) => (size * 2).roundToDouble() / 2;
