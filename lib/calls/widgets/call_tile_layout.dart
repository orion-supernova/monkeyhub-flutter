import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';

/// Where [count] video tiles go in [area]: every tile filled, no empty
/// slots, the way FaceTime and WhatsApp tile a group.
///
/// The old grid was a `GridView` of fixed 3:4 cards, so two people were two
/// small boxes at the top of an otherwise black screen. This one picks the
/// column count whose tiles hold the biggest picture of a camera's shape (a
/// portrait 3:4 on a portrait screen, landscape 4:3 on a wide one), then
/// stretches every tile to fill its row. Rows are balanced and the longer
/// ones come first: seven on three rows is 3, 2, 2, never 3, 3, 1, and a
/// shorter row's tiles widen to fill it rather than leave a hole.
///
/// Rects are in [area]'s coordinates, [gap] apart. Pure, so a test can pin
/// the shapes without a widget tree.
List<Rect> callTileRects(int count, Size area, {double gap = 8}) {
  if (count <= 0 || area.isEmpty) return const [];
  final aspect = area.width < area.height ? 3 / 4 : 4 / 3;
  var bestCols = 1;
  var bestScore = -1.0;
  for (var cols = 1; cols <= count; cols++) {
    final rows = (count / cols).ceil();
    final w = (area.width - gap * (cols - 1)) / cols;
    final h = (area.height - gap * (rows - 1)) / rows;
    if (w <= 0 || h <= 0) continue;
    // The biggest camera-shaped picture that fits the tile: what a viewer
    // actually gets to see once the cover fit has cropped the rest.
    final fw = math.min(w, h * aspect);
    final score = fw * (fw / aspect);
    if (score > bestScore + 0.5) {
      bestScore = score;
      bestCols = cols;
    }
  }
  final rows = (count / bestCols).ceil();
  final base = count ~/ rows;
  final extra = count % rows;
  final h = (area.height - gap * (rows - 1)) / rows;
  final out = <Rect>[];
  for (var r = 0; r < rows; r++) {
    final inRow = base + (r < extra ? 1 : 0);
    final w = (area.width - gap * (inRow - 1)) / inRow;
    for (var c = 0; c < inRow; c++) {
      out.add(Rect.fromLTWH(c * (w + gap), r * (h + gap), w, h));
    }
  }
  return out;
}

/// Lays [children] out at [callTileRects] for their count. Keyed children
/// keep their state (and their video view) as the count changes, and glide
/// to their new slots rather than jumping: someone joining makes room, the
/// others sliding and resizing around the newcomer, who pops in. Each tile
/// starts its glide from wherever it is, so a second change mid-glide never
/// jumps either. Calm motion snaps.
class CallTileLayout extends StatelessWidget {
  const CallTileLayout({super.key, required this.children, this.gap = 8});

  final List<Widget> children;
  final double gap;

  static const Duration glide = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    final duration = MotionScope.of(context).d(glide);
    return LayoutBuilder(
      builder: (context, box) {
        final rects = callTileRects(children.length, box.biggest, gap: gap);
        return Stack(
          children: [
            for (var i = 0; i < rects.length; i++)
              AnimatedPositioned.fromRect(
                key: children[i].key,
                rect: rects[i],
                duration: duration,
                curve: Curves.easeOutCubic,
                child: _Arrival(
                  animate: duration > Duration.zero,
                  child: children[i],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A tile's entrance: in from a little smaller, fading up. Plays once, when
/// the tile is first laid out; never again as it moves.
class _Arrival extends StatelessWidget {
  const _Arrival({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: child,
      // One shape at every t, so the tile (and its video view) is never
      // re-parented when the entrance ends.
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        );
      },
    );
  }
}
