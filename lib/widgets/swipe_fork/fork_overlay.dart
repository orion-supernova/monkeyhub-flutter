import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAnimatedSize;

import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../theme/vanish_palette.dart';
import '../swipe_fork.dart';

/// The two colours a choice can take, derived from the theme.
///
/// Talk is the theme's own `success`. No theme has a violet, so vanish rotates
/// the accent's hue to violet and keeps its saturation and lightness (clamped
/// so it reads on any surface): it follows the theme without a hard-coded hex.
class ForkPalette {
  ForkPalette(AppTheme theme)
      : talk = theme.success,
        vanish = VanishPalette(theme).vanish;

  final Color talk;
  final Color vanish;

  Color of(ForkOption o) => o.isVanish ? vanish : talk;

  /// A readable glyph colour on top of [c].
  static Color onColor(Color c) => VanishPalette.onColor(c);
}

/// Every word the fork shows, from the app's localizations.
class ForkLabels {
  const ForkLabels(this.l);
  final AppLocalizations l;

  String title(ForkOption o) => switch (o.kind) {
        ForkKind.vanishOn => l.forkChipVanish,
        ForkKind.vanishOff => l.forkChipTurnOff,
        ForkKind.startHuddle => l.forkChipTalk,
        ForkKind.joinHuddle => l.forkChipJoin,
      };

  String sub(ForkOption o) => switch (o.kind) {
        ForkKind.vanishOn => l.forkChipVanishSub,
        ForkKind.vanishOff => l.forkChipTurnOffSub,
        ForkKind.startHuddle => l.forkChipTalkSub,
        ForkKind.joinHuddle => l.forkChipJoinSub(math.max(1, o.joinCount)),
      };

  String _single(ForkOption o) => switch (o.kind) {
        ForkKind.vanishOn => l.forkSubVanishOn,
        ForkKind.vanishOff => l.forkSubVanishOff,
        ForkKind.startHuddle => l.forkSubTalk,
        ForkKind.joinHuddle => l.forkSubJoin,
      };

  String _release(ForkOption o) => switch (o.kind) {
        ForkKind.vanishOn => l.forkReleaseVanishOn,
        ForkKind.vanishOff => l.forkReleaseVanishOff,
        ForkKind.startHuddle => l.forkReleaseTalk,
        ForkKind.joinHuddle => l.forkReleaseJoin,
      };

  /// The two hint lines for the controller's current view.
  (String, String) hint(SwipeForkController c) {
    final only = c.viewLeft ?? c.viewRight;
    if (!c.viewForked) {
      return (
        l.forkHintSwipeUp,
        c.viewSingle ? _single(only!) : l.forkSubChoose,
      );
    }
    if (c.viewSingle) return (_release(only!), l.forkDragDownCancel);
    final armed = c.viewArmed;
    if (armed == null) return (l.forkSlideToChoose, l.forkLetGoCancel);
    final o = armed == ForkSide.left ? c.viewLeft : c.viewRight;
    return (_release(o!), l.forkSlideBackCancel);
  }
}

/// Where everything sits, in the overlay's own coordinates. The gap is the
/// strip between the (lifted) newest message and the top of the dock; the
/// circle and the chips are centred in it.
class ForkGeometry {
  ForkGeometry(this.size, this.dockHeight, {this.topInset = 0});

  static const circle = 28.0;
  static const chipW = 124.0;
  static const chipH = 108.0;
  static const chipSpread = 118.0;

  /// Air kept between a chip and the header above it or the dock below it.
  static const chipMargin = 8.0;

  /// Circle plus its two caption lines.
  static const block = 64.0;

  final Size size;

  /// The measured dock (shelf, reply card, field), from the bottom edge.
  final double dockHeight;

  /// The bottom of whatever sits above the transcript (the header), from the
  /// top edge: the chips never ride up under it.
  final double topInset;

  double get dockTop => size.height - dockHeight;
  double get cx => size.width / 2;

  /// The gap's vertical centre for a list lifted by [lift].
  double blockCenterY(double lift) => dockTop - lift / 2;

  /// How far the caption has made room for itself under the circle, 0..1: a
  /// barely opened gap holds just the circle, centred; a full one holds the
  /// circle and its two lines.
  double captionRoom(double lift) =>
      Curves.easeOut.transform(((lift - 44) / 36).clamp(0.0, 1.0));

  /// The circle's centre for a list lifted by [lift].
  ///
  /// Never lower than leaves room for the ring and, as it opens, its two
  /// caption lines above the dock: a barely lifted list has a gap too small to
  /// hold them, and the dock (with its shelf) is not theirs to draw on.
  Offset circleCenter(double lift) {
    final room = captionRoom(lift);
    final ideal = blockCenterY(lift) - (block - circle) / 2 * room;
    final lowest = dockTop - dockAir - circle / 2 - captionH * room;
    return Offset(cx, math.min(ideal, lowest));
  }

  /// Air kept above the dock, and the two caption lines' room.
  static const dockAir = 6.0;
  static const captionH = 36.0;

  /// The circle's centre for the peek, which has no caption.
  Offset peekCenter() => Offset(cx, dockTop - 28);

  /// The chips' vertical centre: the finger's height ([fingerY], in this
  /// box's coordinates), held between the header and the dock with a margin.
  /// Without a finger (a test, a peek) the gap's centre.
  double chipY(double? fingerY, double lift) {
    final lo = topInset + chipMargin + chipH / 2;
    final hi = dockTop - chipMargin - chipH / 2;
    if (hi < lo) return (topInset + dockTop) / 2;
    return (fingerY ?? blockCenterY(lift)).clamp(lo, hi).toDouble();
  }

  /// Chip centres: either side of the finger's column, at the finger's height.
  Offset chipCenter(ForkSide s, double lift, [double? fingerY]) => Offset(
        cx + (s == ForkSide.left ? -chipSpread : chipSpread),
        chipY(fingerY, lift),
      );
}

/// Pulls its child (the transcript) up by [SwipeForkController.lift]. One
/// transform: the rows are not rebuilt, only the layer moves. Clipped to the
/// list's own height (generously wide, so nothing that bleeds sideways is cut).
class ForkLift extends StatelessWidget {
  const ForkLift({super.key, required this.controller, required this.child});

  final SwipeForkController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: const _LiftClip(),
      child: AnimatedBuilder(
        animation: controller.repaint,
        child: child,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, -controller.lift), child: child),
      ),
    );
  }
}

class _LiftClip extends CustomClipper<Rect> {
  const _LiftClip();
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-4000, 0, size.width + 4000, size.height);
  @override
  bool shouldReclip(_LiftClip old) => false;
}

/// The fork's picture: the circle in the gap the lift opens, the option chips
/// beside it, and the caption. Mount it above the whole screen (it ignores
/// pointers). Everything is one painter driven by the controller, so a pull
/// never rebuilds the transcript or this widget; and nothing here is a blur.
class SwipeForkOverlay extends StatelessWidget {
  const SwipeForkOverlay({
    super.key,
    required this.controller,
    this.dockHeight,
    this.dockKey,
    this.topInset,
  });

  final SwipeForkController controller;

  /// The dock's measured height, or null before it is measured (a composer's
  /// height over the safe area is assumed).
  final double? Function()? dockHeight;

  /// The dock's own box (shelf, cards and field in one). When it is mounted
  /// its drawn top is measured here, so a shelf row of any height, an
  /// animating card, and the classic chat style (which publishes no inset) are
  /// all cleared; [dockHeight] is the fallback.
  final GlobalKey? dockKey;

  /// How far down the header reaches, or null for the status bar and a bar.
  final double? Function()? topInset;

  /// The dock's drawn height from the bottom edge of [overlay], from the real
  /// render boxes: the box itself, and the [AnimatedSize] it grows in (which is
  /// the larger while a card is leaving).
  double? _dockHeightIn(BuildContext overlay, Size size) {
    final dock = dockKey?.currentContext?.findRenderObject();
    final me = overlay.findRenderObject();
    if (dock is! RenderBox || !dock.attached || !dock.hasSize) return null;
    if (me is! RenderBox || !me.attached || !me.hasSize) return null;
    var top = dock.localToGlobal(Offset.zero).dy;
    final parent = dock.parent;
    if (parent is RenderAnimatedSize && parent.hasSize) {
      top = math.min(top, parent.localToGlobal(Offset.zero).dy);
    }
    final height = size.height - (top - me.localToGlobal(Offset.zero).dy);
    return height.isFinite && height > 0 ? height : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    controller
      ..calm = MotionScope.of(context).calm
      ..rtl = Directionality.of(context) == TextDirection.rtl
      ..screenCenterX = MediaQuery.sizeOf(context).width / 2;
    final labels = ForkLabels(AppLocalizations.of(context));
    final palette = ForkPalette(theme);
    final fallback = MediaQuery.viewPaddingOf(context).bottom + 72;
    final defaultTop = MediaQuery.viewPaddingOf(context).top + 56;
    return ListenableBuilder(
      listenable: Listenable.merge([controller.visible, controller.peekOn]),
      builder: (context, _) {
        if (!controller.visible.value && !controller.peekOn.value) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: LayoutBuilder(
              builder: (context, box) {
                final here = context;
                ForkGeometry geoOf(Size size) => ForkGeometry(
                      size,
                      _dockHeightIn(here, size) ?? dockHeight?.call() ?? fallback,
                      topInset: topInset?.call() ?? defaultTop,
                    );
                return RepaintBoundary(
                  child: CustomPaint(
                    size: box.biggest,
                    painter: ForkScenePainter(
                      controller: controller,
                      theme: theme,
                      palette: palette,
                      labels: labels,
                      geoOf: geoOf,
                      originOf: () => _originOf(here),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// The overlay's top-left, in screen coordinates.
Offset _originOf(BuildContext overlay) {
  final me = overlay.findRenderObject();
  if (me is RenderBox && me.attached && me.hasSize) {
    return me.localToGlobal(Offset.zero);
  }
  return Offset.zero;
}

// ───────── circle, chips, caption ─────────

class ForkScenePainter extends CustomPainter {
  ForkScenePainter({
    required this.controller,
    required this.theme,
    required this.palette,
    required this.labels,
    required this.geoOf,
    this.originOf,
  }) : super(repaint: controller.repaint);

  final SwipeForkController controller;
  final AppTheme theme;
  final ForkPalette palette;
  final ForkLabels labels;
  final ForkGeometry Function(Size size) geoOf;

  /// The overlay's top-left on screen, to bring the finger's global position
  /// into the painter's own coordinates.
  final Offset Function()? originOf;

  /// Taken at the top of each paint, so the dock is measured as it is now.
  late ForkGeometry geo;

  final Map<String, TextPainter> _text = {};

  TextPainter _tp(String text, TextStyle style, double maxWidth, [int maxLines = 2]) {
    final key = '$text|${style.fontSize}|${style.color?.toARGB32()}|$maxWidth|$maxLines';
    return _text[key] ??= TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  @override
  void paint(Canvas canvas, Size size) {
    geo = geoOf(size);
    final c = controller;
    final out = 1 - c.chrome.value.clamp(0.0, 1.0);
    final gesture = c.visible.value;
    final lift = c.lift;

    if (gesture) {
      final a = ((lift - 18) / 22).clamp(0.0, 1.0) * out;
      if (a > 0) {
        if (!c.viewSingle) {
          if (c.viewHalves) {
            _halves(canvas, out);
          } else {
            for (final side in ForkSide.values) {
              _chip(canvas, side, out, lift);
            }
          }
        }
        _circle(canvas, geo.circleCenter(lift), a, c.viewP);
        _caption(canvas, geo.circleCenter(lift), a * geo.captionRoom(lift));
      }
      _failure(canvas);
    } else if (c.peekOn.value) {
      final a = ForkPeek.opacityAt(c.peekValue.value) * 0.7;
      if (a > 0) _circle(canvas, geo.peekCenter(), a, 0);
    }
  }

  /// The ring, the glyph in it. [alpha] fades the whole thing.
  void _circle(Canvas canvas, Offset center, double alpha, double progress) {
    final c = controller;
    final g = c.glyph.value.clamp(0.0, 1.0);
    final al = c.armLeft.value.clamp(0.0, 1.0);
    final ar = c.armRight.value.clamp(0.0, 1.0);
    var ready = Color.lerp(theme.ink.withValues(alpha: 0.85), theme.accent, g)!;
    final armedOpt = al >= ar ? c.viewLeft : c.viewRight;
    final armed = math.max(al, ar);
    if (armedOpt != null && armed > 0) {
      ready = Color.lerp(ready, palette.of(armedOpt), armed)!;
    }
    final pop = 1 + 0.15 * math.sin(math.pi * c.pulse.value.clamp(0.0, 1.0));
    const r = ForkGeometry.circle / 2 - 1;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pop);
    canvas.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: r + 14),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset.zero, r, ring..color = theme.ink.withValues(alpha: 0.16));
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        -math.pi / 2,
        sweep,
        false,
        ring..color = ready,
      );
    }

    // Chevron while pulling, then the option's glyph (one option) or a dot (two).
    final chevronA = 1 - g;
    if (chevronA > 0.01) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = theme.ink.withValues(alpha: 0.85 * chevronA);
      final dy = -3.0 * g;
      canvas.drawPath(
        Path()
          ..moveTo(-5, 2 + dy)
          ..lineTo(0, -3 + dy)
          ..lineTo(5, 2 + dy),
        p,
      );
    }
    if (g > 0.01) {
      final only = c.viewLeft ?? c.viewRight;
      if (c.viewSingle && only != null) {
        canvas.save();
        canvas.scale(0.5 + 0.1 * g);
        _icon(canvas, only, Offset.zero, ready.withValues(alpha: g));
        canvas.restore();
      } else {
        canvas.drawCircle(
          Offset.zero,
          3 * g,
          Paint()..color = ready,
        );
      }
    }
    canvas.restore();
    canvas.restore();
  }

  /// The full-screen style: the screen is two halves, a wash of each option's
  /// colour with its glyph and name, the half under the finger lit. One
  /// translucent rect per half and two small layers; nothing blurs.
  void _halves(Canvas canvas, double out) {
    final c = controller;
    final b = c.bloom.value.clamp(0.0, 1.0) * out;
    if (b <= 0.001) return;
    final size = geo.size;
    final midY = (geo.topInset + geo.dockTop) / 2 - 24;
    for (final side in ForkSide.values) {
      final o = side == ForkSide.left ? c.viewLeft : c.viewRight;
      if (o == null) continue;
      final arm =
          (side == ForkSide.left ? c.armLeft : c.armRight).value.clamp(0.0, 1.0);
      final col = palette.of(o);
      final rect = side == ForkSide.left
          ? Rect.fromLTRB(0, 0, geo.cx, size.height)
          : Rect.fromLTRB(geo.cx, 0, size.width, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Color.lerp(theme.surfaceRaised, col, 0.10 + 0.30 * arm)!
              .withValues(alpha: 0.80 * b),
      );
      final at = Offset(rect.center.dx, midY);
      canvas.saveLayer(
        Rect.fromCenter(center: at, width: rect.width, height: 190),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: b),
      );
      final pop = 1 + 0.14 * arm;
      canvas.save();
      canvas.translate(at.dx, at.dy - 34);
      canvas.scale(pop);
      canvas.drawCircle(
        Offset.zero,
        34,
        Paint()..color = Color.lerp(theme.surfaceSunken, col, arm)!,
      );
      canvas.scale(1.5);
      _icon(canvas, o, Offset.zero,
          Color.lerp(theme.ink, ForkPalette.onColor(col), arm)!);
      canvas.restore();
      final title = _tp(
        labels.title(o),
        theme.bodyEmph.copyWith(fontSize: 18, color: theme.ink, height: 1.15),
        rect.width - 24,
        1,
      );
      final sub = _tp(
        labels.sub(o),
        theme.caption.copyWith(fontSize: 13, color: theme.inkMuted, height: 1.2),
        rect.width - 24,
      );
      final ty = at.dy + 34 * pop + 14;
      title.paint(canvas, Offset(at.dx - title.width / 2, ty));
      sub.paint(canvas, Offset(at.dx - sub.width / 2, ty + title.height + 3));
      canvas.restore();
    }
    canvas.drawRect(
      Rect.fromLTWH(geo.cx - 0.5, 0, 1, size.height),
      Paint()..color = theme.divider.withValues(alpha: b),
    );
  }

  void _caption(Canvas canvas, Offset circle, double alpha) {
    final c = controller;
    var (top, sub) = labels.hint(c);
    // Two chips already say the rest; one line keeps clear of them.
    if (c.viewForked && !c.viewSingle) sub = '';
    final between = c.viewForked && !c.viewSingle;
    final w = between ? 108.0 : geo.size.width - 48;
    // Between the chips the line may wrap to two; it never runs under a chip.
    final a = _tp(top, theme.bodyEmph.copyWith(fontSize: 13, height: 1.1, color: theme.ink), w, between ? 2 : 1);
    final b = sub.isEmpty
        ? null
        : _tp(sub, theme.caption.copyWith(fontSize: 11.5, color: theme.inkMuted), w, 1);
    final y = circle.dy + ForkGeometry.circle / 2 + 6;
    canvas.saveLayer(
      Rect.fromLTWH(0, y - 4, geo.size.width, a.height + (b?.height ?? 0) + 8),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
    a.paint(canvas, Offset((geo.size.width - a.width) / 2, y));
    b?.paint(canvas, Offset((geo.size.width - b.width) / 2, y + a.height));
    canvas.restore();
  }

  /// A failed commit: one shake and the reason, on a small pill above the dock.
  void _failure(Canvas canvas) {
    final c = controller;
    final reason = c.failReason;
    if (reason == null || reason.isEmpty) return;
    final alpha = 1 - c.orbFade.value.clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final t = _tp(reason, theme.bodyEmph.copyWith(fontSize: 13, color: theme.ink), geo.size.width - 64, 2);
    final s = c.shake.value;
    final dx = s > 0 && s < 1 ? math.sin(s * math.pi * 4) * 10 * (1 - s) : 0.0;
    final rect = Rect.fromCenter(
      center: Offset(geo.cx + dx, geo.dockTop - 28),
      width: t.width + 28,
      height: t.height + 16,
    );
    canvas.saveLayer(
      rect.inflate(4),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    canvas.drawRRect(rr, Paint()..color = theme.surfaceRaised);
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.divider,
    );
    t.paint(canvas, rect.topLeft + const Offset(14, 8));
    canvas.restore();
  }

  void _chip(Canvas canvas, ForkSide side, double out, double lift) {
    final c = controller;
    final o = side == ForkSide.left ? c.viewLeft : c.viewRight;
    if (o == null) return;
    final b = c.bloom.value;
    if (b <= 0.001) return;
    final arm = (side == ForkSide.left ? c.armLeft : c.armRight).value.clamp(0.0, 1.0);
    final other = (side == ForkSide.left ? c.armRight : c.armLeft).value.clamp(0.0, 1.0);
    final col = palette.of(o);
    final from = geo.circleCenter(lift);
    final origin = originOf?.call() ?? Offset.zero;
    // The chips ride just above the thumb, straight off its position (no
    // spring in between), and lean along with its sideways travel.
    final fingerY = c.fingerY.value - origin.dy - 56;
    final slot = geo.chipCenter(side, lift, fingerY);
    final to = Offset(slot.dx + c.viewSlide * 40, slot.dy);
    // The spring may overshoot the scale, never the place: a chip stays
    // between the header and the dock all the way there.
    final center = Offset.lerp(from, to, b.clamp(0.0, 1.0))!;
    final scale = (0.3 + 0.7 * b) * (1 + 0.1 * arm - 0.06 * other);
    final alpha = (b * 3).clamp(0.0, 1.0) * out * (1 - 0.5 * other);

    const w = ForkGeometry.chipW, h = ForkGeometry.chipH;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final layer = alpha < 0.99;
    if (layer) {
      canvas.saveLayer(
        rect.inflate(6),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
    }
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(
      rr,
      Paint()..color = Color.lerp(theme.surfaceRaised, Color.lerp(theme.surfaceRaised, col, 0.22), arm)!,
    );
    canvas.drawRRect(
      rr.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.lerp(theme.divider, col, arm)!,
    );

    // The way to slide, on the side facing the finger: points outward, and
    // nudges once that way as the chips bloom.
    _chevron(canvas, side, rect, Color.lerp(theme.inkMuted, col, arm)!);

    // Icon disc.
    final disc = Offset(0, rect.top + 12 + 20);
    canvas.drawCircle(
      disc,
      20,
      Paint()..color = Color.lerp(theme.surfaceSunken, col, arm)!,
    );
    _icon(canvas, o, disc, Color.lerp(theme.ink, ForkPalette.onColor(col), arm)!);

    final title = _tp(
      labels.title(o),
      theme.bodyEmph.copyWith(fontSize: 13.5, color: theme.ink, height: 1.15),
      w - 16,
      1,
    );
    final ty = disc.dy + 20 + 6;
    title.paint(canvas, Offset(-title.width / 2, ty));
    final subY = ty + title.height + 2;
    if (o.kind == ForkKind.joinHuddle && o.joinUserIds.isNotEmpty) {
      _faces(canvas, o, Offset(0, subY + 7));
    } else {
      final sub = _tp(
        labels.sub(o),
        theme.caption.copyWith(fontSize: 11, color: theme.inkMuted, height: 1.2),
        w - 16,
      );
      sub.paint(canvas, Offset(-sub.width / 2, subY));
    }
    if (layer) canvas.restore();
    canvas.restore();
  }

  /// A small chevron on the chip's inner side, ‹ on the left chip and › on the
  /// right one. [SwipeForkController.kick] moves it a few points outward and
  /// back, once.
  void _chevron(Canvas canvas, ForkSide side, Rect chip, Color color) {
    final out = side == ForkSide.left ? -1.0 : 1.0;
    final nudge = 5 * math.sin(math.pi * controller.kick.value.clamp(0.0, 1.0));
    // The inner edge faces the finger: right edge of the left chip.
    final x = -out * (chip.width / 2 - 13) + out * nudge;
    final y = chip.top + 12 + 20;
    canvas.drawPath(
      Path()
        ..moveTo(x - out * 3, y - 5)
        ..lineTo(x + out * 3, y)
        ..lineTo(x - out * 3, y + 5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  void _icon(Canvas canvas, ForkOption o, Offset at, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = color;
    if (o.isTalk) {
      // A huddle is live audio: five bars.
      const hs = [6.0, 12.0, 18.0, 12.0, 6.0];
      for (var i = 0; i < hs.length; i++) {
        final x = at.dx + (i - 2) * 5.5;
        canvas.drawLine(Offset(x, at.dy - hs[i] / 2), Offset(x, at.dy + hs[i] / 2), p);
      }
      return;
    }
    // Vanish: a ring of dots fading out; "turn off" is the same ring, solid, struck through.
    if (o.kind == ForkKind.vanishOn) {
      for (var i = 0; i < 8; i++) {
        final a = -math.pi / 2 + i * math.pi / 4;
        canvas.drawCircle(
          at + Offset(math.cos(a), math.sin(a)) * 9,
          2,
          Paint()..color = color.withValues(alpha: 1 - i * 0.11),
        );
      }
    } else {
      canvas.drawCircle(at, 9, p..strokeWidth = 2.4);
      canvas.drawLine(at + const Offset(-7, 7), at + const Offset(7, -7), p);
    }
  }

  void _faces(Canvas canvas, ForkOption o, Offset center) {
    final ids = o.joinUserIds.take(3).toList();
    const r = 8.5, step = 12.0;
    final x0 = center.dx - (ids.length - 1) * step / 2;
    for (var i = 0; i < ids.length; i++) {
      final at = Offset(x0 + i * step, center.dy);
      final g = theme.avatarGradient(ids[i].hashCode.abs());
      canvas.drawCircle(
        at,
        r + 1.5,
        Paint()..color = theme.surfaceRaised,
      );
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            at - const Offset(r, r),
            at + const Offset(r, r),
            [g.first, g.last],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(ForkScenePainter old) =>
      old.theme != theme || old.labels.l != labels.l;
}
