import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/room_filter.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/theme_preference.dart' show AppThemeBrightness;
import '../theme/theme_scope.dart';
import '../l10n/text_case.dart';
import 'filter_capsule.dart';
import 'desktop_scroll.dart';

/// The always-visible control for [FilterStyle.chips].
///
/// Eight facets don't fit a phone row — let alone the 360pt column the chat
/// list occupies in the desktop two-pane — so the row scrolls. Dimension
/// separators are drawn between groups because the combination rule is
/// OR-within / AND-across, and a flat undifferentiated row would imply the
/// wrong thing.
class RoomFilterBar extends StatelessWidget {
  const RoomFilterBar({
    super.key,
    required this.filter,
    required this.counts,
    required this.onChanged,
    this.gutter = 20,
  });

  final RoomFilter filter;
  final RoomFacetCounts counts;
  final ValueChanged<RoomFilter> onChanged;

  /// The page margin the row lines up with at rest.
  ///
  /// The bar itself must be laid out full-bleed and apply this itself, rather
  /// than being handed an already-inset box: as leading and trailing scroll
  /// padding the first and last chip still start and end on the page margin,
  /// but the ones in between run to the screen edge and slide off it instead of
  /// vanishing at an invisible wall 20pt in.
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // A horizontal ListView hands its children a TIGHT cross-axis constraint,
    // so this height is imposed on every chip rather than being a floor. Left
    // at a flat 34 it clipped the label at accessibility text sizes — nothing
    // in the app clamps `textScaler`. Scaling the box keeps the chips whole;
    // the cap stops a 3x setting from eating the room list.
    final scaled = MediaQuery.textScalerOf(context).scale(32).clamp(32.0, 56.0);
    return SizedBox(
      height: scaled,
      child: HorizontalWheelScroll(
        child: ListView(
          // The row lives inside the chat list's scroll view, so scrolling far
          // enough down unmounts it. A scroll position only survives that if it
          // has somewhere to persist to, and one without a PageStorageKey of its
          // own persists nowhere: scroll the row to a later facet, scroll the
          // chats past it, come back, and the row had silently rewound to the
          // start.
          key: const PageStorageKey('room_filter_bar'),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: gutter),
          physics: const BouncingScrollPhysics(),
          children: [
            // 'all' is a reset, not a facet — it reads active precisely when
            // nothing else is, so the row always has exactly one obvious
            // way back to the unfiltered list.
            _Chip(
              label: l10n.roomFilterBarAllChipLabel,
              active: filter.isEmpty,
              onTap: filter.isEmpty
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onChanged(RoomFilter.empty);
                    },
            ),
            for (final dimension in facetDimensionOrder) ...[
              _Separator(color: theme.divider),
              for (final facet in RoomFacet.values.where(
                (f) => f.dimension == dimension,
              ))
                _Chip(
                  label: facet.label(l10n),
                  count: counts[facet],
                  active: filter.has(facet),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(filter.toggle(facet));
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 0.5,
    height: 16,
    color: color,
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// Null on the 'all' chip, which counts nothing.
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterCapsule(
          label: sentenceCaseOf(context, label),
          active: active,
          onTap: onTap,
          count: count,
          semanticLabel: count == null
              ? label
              : AppLocalizations.of(
                  context,
                ).roomFilterBarChipCountSemanticLabel(count!, label),
        ),
      );
}

/// The chat list's filters as a desktop draws them: every facet on screen at
/// once, as segmented button groups, one group per dimension, so the
/// OR-within / AND-across rule is the layout itself rather than a separator
/// you have to know to read.
///
/// A scrolling chip row is a phone's answer to a 360pt width and a thumb; a
/// pointer can reach everything and the pane has the height to wrap, so here
/// nothing hides off the edge and the active filters are never scrolled
/// away. 'All' leads the first group as the reset, exactly as it leads the
/// chip row.
///
/// Within a group more than one can be on, and the selection shows it: two
/// neighbours that are both on fuse into one band (the shared corners square
/// off and the fill grows across the seam), and an on facet draws a small
/// check into itself, which a single-choice segmented control never does.
class RoomFilterSegments extends StatelessWidget {
  const RoomFilterSegments({
    super.key,
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  final RoomFilter filter;
  final RoomFacetCounts counts;
  final ValueChanged<RoomFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = <List<FilterSegment>>[];
    for (final dimension in facetDimensionOrder) {
      groups.add([
        if (groups.isEmpty)
          FilterSegment(
            label: sentenceCaseOf(context, l10n.roomFilterBarAllChipLabel),
            selected: filter.isEmpty,
            check: false,
            onTap: filter.isEmpty ? null : () => onChanged(RoomFilter.empty),
          ),
        for (final facet in RoomFacet.values.where(
          (f) => f.dimension == dimension,
        ))
          FilterSegment(
            label: sentenceCaseOf(context, facet.label(l10n)),
            count: counts[facet],
            selected: filter.has(facet),
            onTap: () => onChanged(filter.toggle(facet)),
          ),
      ]);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final g in groups) SegmentGroup(segments: g)],
    );
  }
}

/// One button in a [SegmentGroup].
@immutable
class FilterSegment {
  const FilterSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.check = true,
  });

  final String label;
  final bool selected;

  /// Null when tapping would change nothing (the reset, already reset).
  final VoidCallback? onTap;

  /// Shown after the label; a zero dims the label instead.
  final int? count;

  /// Whether this one draws a check while on. Off for a reset, which is a
  /// state rather than a choice among several.
  final bool check;
}

/// A row of joined buttons on one quiet track, with a selection that slides
/// and fuses rather than blinking on and off. Several can be on at once.
class SegmentGroup extends StatefulWidget {
  const SegmentGroup({super.key, required this.segments});

  final List<FilterSegment> segments;

  @override
  State<SegmentGroup> createState() => _SegmentGroupState();
}

class _SegmentGroupState extends State<SegmentGroup>
    with TickerProviderStateMixin {
  final List<AnimationController> _on = [];
  Listenable _all = Listenable.merge(const []);

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(SegmentGroup old) {
    super.didUpdateWidget(old);
    _syncControllers();
    final calm = MediaQuery.disableAnimationsOf(context);
    for (var i = 0; i < widget.segments.length; i++) {
      final target = widget.segments[i].selected ? 1.0 : 0.0;
      final c = _on[i];
      if (c.value == target && !c.isAnimating) continue;
      if (calm) {
        c.value = target;
      } else {
        c.animateTo(target, curve: Curves.linear);
      }
    }
  }

  void _syncControllers() {
    final n = widget.segments.length;
    if (_on.length == n) return;
    while (_on.length > n) {
      _on.removeLast().dispose();
    }
    while (_on.length < n) {
      _on.add(AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
        value: widget.segments[_on.length].selected ? 1 : 0,
      ));
    }
    _all = Listenable.merge(_on);
  }

  @override
  void dispose() {
    for (final c in _on) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final compact = Density.of(context).compact;
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    final fontSize = compact ? 13.0 : 14.0;
    final height = scaler.scale(fontSize) * 1.2 + (compact ? 12 : 16);
    const inset = 2.0;
    final padH = compact ? 10.0 : 12.0;
    final checkW = scaler.scale(fontSize) * 0.78 + 4;
    final labelStyle = theme.bodySoft.copyWith(
      fontSize: fontSize,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
    );
    final countStyle = labelStyle.copyWith(
      fontSize: fontSize - 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    double measure(String s, TextStyle st) => (TextPainter(
          text: TextSpan(text: s, style: st),
          textDirection: dir,
          textScaler: scaler,
          maxLines: 1,
        )..layout())
            .width;
    final segs = widget.segments;
    final labelW = [for (final s in segs) measure(s.label, labelStyle)];
    final countW = [
      for (final s in segs)
        (s.count ?? 0) > 0 ? measure('${s.count}', countStyle) + 5 : 0.0,
    ];
    final track = theme.ink.withValues(alpha: theme.isLight ? 0.06 : 0.10);
    final thumb = theme.accent;
    final onInk = theme.accentInk;

    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: _all,
        builder: (context, _) {
          final t = [
            for (final c in _on) Curves.easeOutCubic.transform(c.value),
          ];
          var widths = [
            for (var i = 0; i < segs.length; i++)
              padH * 2 +
                  labelW[i] +
                  countW[i] +
                  (segs[i].check ? checkW * t[i] : 0),
          ];
          final natural = widths.fold(0.0, (a, b) => a + b) + inset * 2;
          // Too wide for the pane (a long language, large type): every
          // segment gives up the same share and its label ellipsizes,
          // rather than the group running off the edge.
          if (box.maxWidth.isFinite && natural > box.maxWidth) {
            final k = (box.maxWidth - inset * 2) / (natural - inset * 2);
            widths = [for (final w in widths) w * k];
          }
          return CustomPaint(
            painter: _SegmentTrackPainter(
              widths: widths,
              on: t,
              inset: inset,
              track: track,
              thumb: thumb,
              rule: theme.ink.withValues(alpha: 0.14),
              radius: compact ? 8 : 10,
              rtl: dir == TextDirection.rtl,
            ),
            child: Padding(
              padding: const EdgeInsets.all(inset),
              child: SizedBox(
                height: height - inset * 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < segs.length; i++)
                      SizedBox(
                        width: widths[i],
                        child: _segment(
                          theme,
                          segs[i],
                          t[i],
                          _on[i].value,
                          labelStyle,
                          countStyle,
                          onInk,
                          padH,
                          checkW,
                          compact ? 6.0 : 8.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _segment(
    AppTheme theme,
    FilterSegment s,
    double t,
    double raw,
    TextStyle labelStyle,
    TextStyle countStyle,
    Color onInk,
    double padH,
    double checkW,
    double radius,
  ) {
    final empty = s.count == 0;
    final rest = empty ? theme.inkMuted : theme.inkSoft;
    final ink = Color.lerp(rest, onInk, t)!;
    final countInk =
        Color.lerp(theme.inkMuted, onInk.withValues(alpha: 0.78), t)!;
    void tap() {
      HapticFeedback.selectionClick();
      s.onTap?.call();
    }

    return FocusableTap(
      onTap: s.onTap == null ? null : tap,
      selected: s.selected,
      semanticLabel: s.count == null
          ? s.label
          : AppLocalizations.of(context)
              .roomFilterBarChipCountSemanticLabel(s.count!, s.label),
      radius: radius,
      inset: 1,
      hover: s.selected ? HoverEffect.none : HoverEffect.tint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: s.onTap == null ? null : tap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (s.check && t > 0)
                SizedBox(
                  width: checkW * t,
                  child: CustomPaint(
                    size: Size(checkW, labelStyle.fontSize!),
                    painter: _CheckPainter(
                      // Drawn in once the band has mostly arrived.
                      progress: Interval(0.35, 1).transform(raw),
                      color: ink,
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: labelStyle.copyWith(color: ink),
                ),
              ),
              if ((s.count ?? 0) > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '${s.count}',
                  maxLines: 1,
                  softWrap: false,
                  style: countStyle.copyWith(color: countInk),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The track, the separators and the selection band for a [SegmentGroup].
///
/// Each segment's band grows out from its middle as it turns on. Where a
/// neighbour is on too, that side reaches the seam instead and its corners
/// square off, so a run of selected segments reads as one band: the morph
/// is the two bands fusing, not a new rectangle appearing.
class _SegmentTrackPainter extends CustomPainter {
  _SegmentTrackPainter({
    required this.widths,
    required this.on,
    required this.inset,
    required this.track,
    required this.thumb,
    required this.rule,
    required this.radius,
    required this.rtl,
  });

  final List<double> widths;
  final List<double> on;
  final double inset;
  final Color track;
  final Color thumb;
  final Color rule;
  final double radius;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = track,
    );
    final n = widths.length;
    // Segment boxes, left to right on screen.
    final order = rtl ? [for (var i = n - 1; i >= 0; i--) i] : [for (var i = 0; i < n; i++) i];
    final lefts = List<double>.filled(n, 0);
    var x = inset;
    for (final i in order) {
      lefts[i] = x;
      x += widths[i];
    }
    final top = inset;
    final bottom = size.height - inset;
    final r = radius - inset;
    // Neighbour on screen to the left / right of segment i.
    int? leftOf(int i) {
      final k = order.indexOf(i);
      return k > 0 ? order[k - 1] : null;
    }

    int? rightOf(int i) {
      final k = order.indexOf(i);
      return k < n - 1 ? order[k + 1] : null;
    }

    // Separators first, under the band: faded out beside anything on.
    final rulePaint = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (var k = 0; k < n - 1; k++) {
      final a = order[k];
      final b = order[k + 1];
      final fade = 1 - math.max(on[a], on[b]);
      if (fade <= 0.01) continue;
      final sx = lefts[b];
      final h = (bottom - top) * 0.25;
      rulePaint.color = rule.withValues(alpha: rule.a * fade);
      canvas.drawLine(Offset(sx, top + h), Offset(sx, bottom - h), rulePaint);
    }

    final fill = Paint()..color = thumb;
    for (var i = 0; i < n; i++) {
      final g = on[i];
      if (g <= 0.001) continue;
      final l = leftOf(i);
      final rr = rightOf(i);
      final jl = l == null ? 0.0 : math.min(on[l], g);
      final jr = rr == null ? 0.0 : math.min(on[rr], g);
      final segL = lefts[i];
      final segR = lefts[i] + widths[i];
      final cx = (segL + segR) / 2;
      final half = widths[i] / 2 * (0.55 + 0.45 * g);
      final left = _lerp(cx - half, segL - (l == null ? 0 : 0.5), jl);
      final right = _lerp(cx + half, segR + (rr == null ? 0 : 0.5), jr);
      final squeeze = (1 - g) * (bottom - top) * 0.18;
      final rect = Rect.fromLTRB(left, top + squeeze, right, bottom - squeeze);
      final rl = Radius.circular(r * (1 - jl));
      final rrad = Radius.circular(r * (1 - jr));
      fill.color = thumb.withValues(alpha: thumb.a * math.min(1, g * 2.2));
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: rl,
          bottomLeft: rl,
          topRight: rrad,
          bottomRight: rrad,
        ),
        fill,
      );
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_SegmentTrackPainter old) =>
      !listEquals(old.widths, widths) ||
      !listEquals(old.on, on) ||
      old.track != track ||
      old.thumb != thumb ||
      old.rule != rule ||
      old.radius != radius ||
      old.rtl != rtl;
}

/// A line check that draws itself: the short stroke, then the long one.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final h = size.height;
    final w = size.width - 4;
    final y0 = (size.height - h * 0.7) / 2;
    final a = Offset(0, y0 + h * 0.38);
    final b = Offset(w * 0.36, y0 + h * 0.66);
    final c = Offset(w, y0 + h * 0.04);
    final first = (a - b).distance;
    final second = (c - b).distance;
    final drawn = (first + second) * progress;
    final path = Path()..moveTo(a.dx, a.dy);
    if (drawn <= first) {
      final p = Offset.lerp(a, b, drawn / first)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(b.dx, b.dy);
      final p = Offset.lerp(b, c, (drawn - first) / second)!;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
