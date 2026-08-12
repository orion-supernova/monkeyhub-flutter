import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'paragraph_geometry.dart';

/// The rounded chip behind an inline-code run, painted BENEATH the paragraph.
///
/// An underlay rather than a WidgetSpan pill because the message paragraph
/// carries exactly one placeholder — the stamp spacer, whose sizing decides
/// whether a full last line wraps — and a second one would start influencing
/// that. Nothing is added to the paragraph here at all; this is a
/// `Positioned.fill` sibling that reads where the glyphs landed and draws
/// under them.
///
/// It replaced a `TextStyle.background` paint, which honoured the same rule
/// but is a flush rectangle the full height of the line box: no side padding,
/// square corners, no edge. On a dark theme, where the whole range between a
/// bubble and pure black spans about 1.3:1, that left nothing for the eye to
/// catch. The edge this can draw and a paint cannot is most of the fix.
class InlineCodeUnderlay extends StatefulWidget {
  const InlineCodeUnderlay({
    super.key,
    required this.paragraphKey,
    required this.ranges,
    required this.fill,
    this.border,
  });

  /// Key on the paragraph this sits under — the same one the veil uses.
  final GlobalKey paragraphKey;

  /// Code stretches in DISPLAY coordinates (the fold's `codeRanges`), already
  /// merged so a run split by a bold boundary arrives as one entry.
  final List<({int start, int end})> ranges;

  final Color fill;
  final Color? border;

  @override
  State<InlineCodeUnderlay> createState() => _InlineCodeUnderlayState();
}

class _InlineCodeUnderlayState extends State<InlineCodeUnderlay>
    with ParagraphMeasured<InlineCodeUnderlay> {
  @override
  GlobalKey get paragraphKey => widget.paragraphKey;

  @override
  List<({int start, int end})> get measuredRanges => widget.ranges;

  /// Sideways outset is the padding a `TextStyle.background` could never have
  /// — without it the chip starts and ends flush against the neighbouring
  /// words. The 1px vertical INSET works the other way: `BoxHeightStyle.max`
  /// returns the full line box, so wrapped lines' chips would otherwise touch
  /// and fuse into a column.
  @override
  double get measureInsetX => -3.5;
  @override
  double get measureInsetY => 1.0;

  /// One path per code run, unioned from its line rects.
  ///
  /// Built at measure time, not per frame: `Path.combine` over a handful of
  /// rects is cheap once and wasteful sixty times a second. The union is what
  /// gives a wrapped run a single continuous outline — rounding each line rect
  /// separately would draw an internal edge everywhere the run wraps.
  List<Path> _paths = const [];

  @override
  void onMeasured(List<List<Rect>> value) {
    final paths = <Path>[];
    for (final run in value) {
      if (run.isEmpty) continue;
      Path? combined;
      for (final r in run) {
        final rrect = RRect.fromRectAndRadius(
          r,
          // Scales with the line box so the chip stays a chip at any text
          // size, capped so a large-text chip doesn't turn into a lozenge.
          Radius.circular(math.min(5, r.height / 3)),
        );
        final piece = Path()..addRRect(rrect);
        combined = combined == null
            ? piece
            : Path.combine(PathOperation.union, combined, piece);
      }
      if (combined != null) paths.add(combined);
    }
    setState(() => _paths = paths);
  }

  @override
  Widget build(BuildContext context) {
    // Armed even with nothing to paint, so a measurement that lands before the
    // paragraph is ready gets retried on the next layout.
    return watchLayout(
      child: CustomPaint(
        painter: _CodeChipPainter(
          paths: _paths,
          fill: widget.fill,
          border: widget.border,
        ),
        // No RepaintBoundary: this never animates, so a layer per bubble would
        // be cost with nothing to save.
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CodeChipPainter extends CustomPainter {
  _CodeChipPainter({required this.paths, required this.fill, this.border});

  final List<Path> paths;
  final Color fill;
  final Color? border;

  @override
  void paint(Canvas canvas, Size size) {
    if (paths.isEmpty) return;
    final fillPaint = Paint()..color = fill;
    final edge = border;
    final edgePaint = edge == null
        ? null
        : (Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    for (final p in paths) {
      canvas.drawPath(p, fillPaint);
      if (edgePaint != null) canvas.drawPath(p, edgePaint);
    }
  }

  @override
  bool shouldRepaint(_CodeChipPainter old) =>
      !identical(old.paths, paths) ||
      old.fill != fill ||
      old.border != border;

  /// Explicitly not hit-testable: the chip is decoration under the words, and
  /// the words' own recognizers live in the paragraph above it. (This is
  /// `RenderCustomPaint`'s default, spelled out because it is load-bearing —
  /// a hit-testing underlay would swallow taps on links.)
  @override
  bool hitTest(Offset position) => false;
}
