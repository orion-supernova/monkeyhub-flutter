/// Where a range of characters actually landed on screen, for anything that
/// has to paint over or under real text.
///
/// `text_runs.dart` reconciles *which* characters carry a decoration; this
/// answers *where those characters are*. Two widgets need it — the spoiler
/// veil above the paragraph and the inline-code chip below it — and they need
/// exactly the same three awkward parts: descending to the paragraph, mapping
/// glyph boxes into the overlay's coordinates, and re-measuring when the text
/// moves. Keeping one copy is the difference between fixing the staleness bug
/// once and fixing it twice.
library;

import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Glyph geometry for [ranges], in [host]'s coordinate space.
///
/// Returns **one inner list per range**, in the order given, so a caller that
/// cares which line-rects belong to the same run (the chip painter rounds only
/// a run's outer corners) can tell; a caller that doesn't just expands them.
/// A range that measures to nothing yields an empty inner list rather than
/// being dropped, so indices stay aligned with [ranges].
///
/// Returns `const []` — not a list of empties — when the paragraph isn't
/// measurable yet, which is the caller's signal to keep whatever it had.
///
/// [insetX]/[insetY] shrink each rect; pass negatives to grow it.
List<List<Rect>> paragraphRectsFor({
  required GlobalKey paragraphKey,
  required RenderBox host,
  required List<({int start, int end})> ranges,
  double insetX = 0,
  double insetY = 0,
}) {
  if (ranges.isEmpty) return const [];
  final p = _paragraphUnder(paragraphKey);
  if (p == null ||
      !p.attached ||
      !p.hasSize ||
      !host.attached ||
      !host.hasSize) {
    return const [];
  }

  Offset toLocal(Offset o) => host.globalToLocal(p.localToGlobal(o));

  // A selection box that ends at a soft wrap includes the space the line
  // broke on, and that space is laid out PAST the paragraph's own width — a
  // 392px paragraph hands back boxes ending at 408. Painted as-is, the veil
  // runs out through the bubble's padding to its edge, which reads as a bar
  // across the bubble rather than a patch over the words. Clamp before
  // coalescing, so the caller's outset still applies on top.
  final bounds = Rect.fromPoints(
    toLocal(Offset.zero),
    toLocal(Offset(p.size.width, p.size.height)),
  );

  final out = <List<Rect>>[];
  for (final range in ranges) {
    final raw = <Rect>[];
    for (final box in p.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
      // `max` so every box on a line is the full line height. Without it a
      // range that spans a size change (inline code is 0.92x the body) gets
      // boxes of two different heights on one line, and any fill drawn from
      // them has a step in it.
      boxHeightStyle: BoxHeightStyle.max,
    )) {
      final r = box.toRect();
      final mapped = Rect.fromPoints(toLocal(r.topLeft), toLocal(r.bottomRight))
          .intersect(bounds);
      if (mapped.width <= 0 || mapped.height <= 0) continue;
      raw.add(mapped);
    }
    out.add(_coalesce(raw, insetX, insetY));
  }
  return out;
}

/// The [RenderParagraph] under [key], found by descending rather than by a
/// single cast.
///
/// The cast this replaced returned null the moment anything wrapped the
/// `Text` — and `Text` wraps ITSELF in a `MouseRegion` whenever a
/// `SelectionRegistrar` is in scope, i.e. the first time anyone puts a
/// `SelectionArea` above a message. A null paragraph means no rects, which
/// means the spoiler veil silently stops mounting and the hidden text renders
/// as plain readable prose. Nothing in the app does that today; this is here
/// so that when someone does, it fails visibly or not at all.
RenderParagraph? _paragraphUnder(GlobalKey key) {
  RenderObject? ro = key.currentContext?.findRenderObject();
  // A handful of proxy boxes is normal; a deep walk means we're lost.
  for (var depth = 0; ro != null && ro is! RenderParagraph && depth < 8; depth++) {
    RenderObject? only;
    var seen = 0;
    ro.visitChildren((child) {
      only = child;
      seen++;
    });
    if (seen != 1) return null;
    ro = only;
  }
  return ro is RenderParagraph ? ro : null;
}

/// Fuses [raw] into one rect per visual line, then applies the insets.
///
/// Two seam classes come out of `getBoxesForSelection`, and both show up as
/// hairlines in anything painted from it. A single line can yield several
/// boxes — bidi runs, and any style boundary inside the range, so `**bold**`
/// inside a spoiler splits it — and consecutive lines can disagree slightly on
/// their vertical extent. Snapping each line group to one top/bottom and
/// merging boxes that touch removes both.
///
/// Insets are applied LAST, on purpose: an outset applied per-box would make
/// neighbouring boxes overlap and defeat the gap test.
List<Rect> _coalesce(List<Rect> raw, double insetX, double insetY) {
  if (raw.isEmpty) return const [];
  final sorted = [...raw]..sort((a, b) {
      final byTop = a.top.compareTo(b.top);
      return byTop != 0 ? byTop : a.left.compareTo(b.left);
    });

  final lines = <List<Rect>>[];
  for (final r in sorted) {
    final line = lines.isEmpty ? null : lines.last;
    if (line != null && _sameLine(line.last, r)) {
      line.add(r);
    } else {
      lines.add([r]);
    }
  }

  final out = <Rect>[];
  for (final line in lines) {
    var top = line.first.top;
    var bottom = line.first.bottom;
    for (final r in line) {
      top = math.min(top, r.top);
      bottom = math.max(bottom, r.bottom);
    }
    // Already sorted by left within the line, so one pass merges.
    var left = line.first.left;
    var right = line.first.right;
    for (final r in line.skip(1)) {
      if (r.left - right <= 1.0) {
        right = math.max(right, r.right);
      } else {
        out.add(Rect.fromLTRB(left, top, right, bottom));
        left = r.left;
        right = r.right;
      }
    }
    out.add(Rect.fromLTRB(left, top, right, bottom));
  }

  if (insetX == 0 && insetY == 0) return out;
  final inset = <Rect>[];
  for (final r in out) {
    final next = Rect.fromLTRB(
      r.left + insetX,
      r.top + insetY,
      r.right - insetX,
      r.bottom - insetY,
    );
    if (next.width > 0 && next.height > 0) inset.add(next);
  }
  return inset;
}

/// Whether [b] sits on the same visual line as [a] — vertical spans overlap by
/// more than 60% of the shorter one. A ratio rather than a pixel tolerance so
/// it holds at any text scale.
bool _sameLine(Rect a, Rect b) {
  final overlap =
      math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
  if (overlap <= 0) return false;
  return overlap > 0.6 * math.min(a.height, b.height);
}

/// State that keeps [rects] in step with a paragraph it paints against.
///
/// Adopters supply [paragraphKey] and [measuredRanges] and paint from [rects].
/// Two things make this a mixin rather than copied code:
///
///  * **[rects] is a [ValueNotifier], not a `State` field.** Hand it straight
///    to `CustomPaint.repaint` and the widget tree never rebuilds for a
///    geometry change — the painter just repaints.
///  * **Re-measuring is not obvious.** Measuring once in a post-frame callback
///    (what the spoiler veil did) goes stale on rotation, on split view, on a
///    live drag of the accessibility text-size slider, and on the async font
///    load that resolves JetBrains Mono after first paint. For the veil that
///    is not cosmetic: the plate ends up over the wrong words while the real
///    text renders underneath it.
///
/// Wrap the painting subtree in [watchLayout] to arm the resize half.
mixin ParagraphMeasured<T extends StatefulWidget> on State<T> {
  /// Measured geometry, one inner list per entry in [measuredRanges].
  final ValueNotifier<List<List<Rect>>> rects =
      ValueNotifier<List<List<Rect>>>(const []);

  /// The paragraph to measure against — the same key the host put on its
  /// `Text.rich`.
  GlobalKey get paragraphKey;

  /// Character ranges to locate, in the DISPLAY text's coordinates.
  List<({int start, int end})> get measuredRanges;

  /// Per-rect shrink; negative grows. See [paragraphRectsFor].
  double get measureInsetX => 0;
  double get measureInsetY => 0;

  /// Called after [rects] has changed. Rebuild any derived geometry here.
  void onMeasured(List<List<Rect>> value) {}

  bool _scheduled = false;
  TextScaler? _lastScaler;

  @override
  void initState() {
    super.initState();
    scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Belt and braces for the rare relayout that changes glyph positions
    // without changing this overlay's own box.
    final scaler = MediaQuery.textScalerOf(context);
    if (_lastScaler != null && _lastScaler != scaler) scheduleMeasure();
    _lastScaler = scaler;
  }

  @override
  void dispose() {
    rects.dispose();
    super.dispose();
  }

  /// Measures after the current frame. Idempotent within a frame, so the
  /// notifier and the resize listener firing together cost one measure.
  void scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      measureNow();
    });
  }

  void measureNow() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final next = paragraphRectsFor(
      paragraphKey: paragraphKey,
      host: box,
      ranges: measuredRanges,
      insetX: measureInsetX,
      insetY: measureInsetY,
    );
    // Empty means "not measurable yet", never "the ranges moved off screen" —
    // keep the last good geometry rather than blinking the paint away.
    if (next.isEmpty) return;
    if (_sameGeometry(rects.value, next)) return;
    rects.value = next;
    onMeasured(next);
  }

  /// Re-measures whenever a relayout changes this widget's own size.
  ///
  /// Both adopters are `Positioned.fill` children of a Stack that the
  /// paragraph sizes, so any relayout that moves glyphs also resizes them.
  /// The notification fires DURING layout, so [scheduleMeasure]'s post-frame
  /// hop means one frame of stale-but-nearly-right rects on a resize. That is
  /// the accepted cost; measuring inside `paint` would be exact and would
  /// scatter this logic across two painters.
  Widget watchLayout({required Widget child}) =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          scheduleMeasure();
          return true;
        },
        child: SizeChangedLayoutNotifier(child: child),
      );
}

bool _sameGeometry(List<List<Rect>> a, List<List<Rect>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.length != y.length) return false;
    for (var j = 0; j < x.length; j++) {
      if (x[j] != y[j]) return false;
    }
  }
  return true;
}
