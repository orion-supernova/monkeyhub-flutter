/// Packs pictures of mixed aspect ratios into full-width rows, the layout every
/// GIF picker uses (and the one KLIPY's own reference apps ship).
///
/// Each row is scaled so its pictures exactly fill [maxWidth] at a shared
/// height near [targetHeight]; no picture is cropped and none is letterboxed.
/// A grid of fixed cells would do one or the other to nearly every GIF.
///
/// Order is preserved exactly — KLIPY's terms require results to be shown in
/// the order it returned them — so this only ever decides where a row breaks,
/// never which item goes where.
library;

/// One item to place: its aspect ratio (width÷height), or a fixed-size block
/// that must not be scaled (an ad).
class RowInput {
  const RowInput.picture(this.aspectRatio)
      : fixedWidth = null,
        fixedHeight = null;
  const RowInput.fixed(double width, double height)
      : fixedWidth = width,
        fixedHeight = height,
        aspectRatio = width / height;

  final double aspectRatio;
  final double? fixedWidth;
  final double? fixedHeight;

  bool get isFixed => fixedWidth != null;
}

class JustifiedRow {
  const JustifiedRow({
    required this.start,
    required this.count,
    required this.height,
    required this.widths,
  });

  /// Index of the first input in this row.
  final int start;
  final int count;
  final double height;

  /// Laid-out width of each item, in order.
  final List<double> widths;
}

/// Lays [items] into rows.
///
/// A fixed item always gets a row of its own, centred by the caller, at its own
/// size (shrunk only if it is wider than [maxWidth]). The last row of pictures
/// is left at [targetHeight] rather than stretched to full width, so a lone
/// straggler does not blow up to fill the screen — unless [fillLastRow].
List<JustifiedRow> justifiedRows(
  List<RowInput> items, {
  required double maxWidth,
  double targetHeight = 110,
  double spacing = 4,
  bool fillLastRow = false,
  double minAspect = 0.5,
  double maxAspect = 3,
}) {
  if (maxWidth <= 0) return const [];
  final rows = <JustifiedRow>[];
  var start = 0;
  var ratios = <double>[];

  void flushPictures({required bool last}) {
    if (ratios.isEmpty) return;
    final gaps = spacing * (ratios.length - 1);
    final sum = ratios.fold<double>(0, (a, r) => a + r);
    var height = (maxWidth - gaps) / sum;
    if (last && !fillLastRow && height > targetHeight) height = targetHeight;
    rows.add(JustifiedRow(
      start: start,
      count: ratios.length,
      height: height,
      widths: [for (final r in ratios) r * height],
    ));
    start += ratios.length;
    ratios = [];
  }

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.isFixed) {
      flushPictures(last: true);
      final scale =
          item.fixedWidth! > maxWidth ? maxWidth / item.fixedWidth! : 1.0;
      rows.add(JustifiedRow(
        start: i,
        count: 1,
        height: item.fixedHeight! * scale,
        widths: [item.fixedWidth! * scale],
      ));
      start = i + 1;
      continue;
    }
    ratios.add(item.aspectRatio.clamp(minAspect, maxAspect));
    final sum = ratios.fold<double>(0, (a, r) => a + r);
    final width = sum * targetHeight + spacing * (ratios.length - 1);
    if (width >= maxWidth) flushPictures(last: false);
  }
  flushPictures(last: true);
  return rows;
}
