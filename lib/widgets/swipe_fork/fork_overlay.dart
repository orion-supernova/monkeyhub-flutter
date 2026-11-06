import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  ForkGeometry(this.size, this.dockHeight);

  static const circle = 28.0;
  static const chipW = 124.0;
  static const chipH = 108.0;
  static const chipSpread = 118.0;

  /// Circle plus its two caption lines.
  static const block = 64.0;

  final Size size;

  /// The measured dock (shelf, reply card, field), from the bottom edge.
  final double dockHeight;

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
  Offset circleCenter(double lift) => Offset(
        cx,
        blockCenterY(lift) - (block - circle) / 2 * captionRoom(lift),
      );

  /// The circle's centre for the peek, which has no caption.
  Offset peekCenter() => Offset(cx, dockTop - 28);

  /// Chip centres: either side of the circle, at the gap's height.
  Offset chipCenter(ForkSide s, double lift) => Offset(
        cx + (s == ForkSide.left ? -chipSpread : chipSpread),
        blockCenterY(lift),
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
  });

  final SwipeForkController controller;

  /// The dock's measured height, or null before it is measured (a composer's
  /// height over the safe area is assumed).
  final double? Function()? dockHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    controller
      ..calm = MotionScope.of(context).calm
      ..rtl = Directionality.of(context) == TextDirection.rtl;
    final labels = ForkLabels(AppLocalizations.of(context));
    final palette = ForkPalette(theme);
    final fallback = MediaQuery.viewPaddingOf(context).bottom + 72;
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
                final geo = ForkGeometry(box.biggest, dockHeight?.call() ?? fallback);
                return RepaintBoundary(
                  child: CustomPaint(
                    size: box.biggest,
                    painter: ForkScenePainter(
                      controller: controller,
                      theme: theme,
                      palette: palette,
                      labels: labels,
                      geo: geo,
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

// ───────── circle, chips, caption ─────────

class ForkScenePainter extends CustomPainter {
  ForkScenePainter({
    required this.controller,
    required this.theme,
    required this.palette,
    required this.labels,
    required this.geo,
  }) : super(repaint: controller.repaint);

  final SwipeForkController controller;
  final AppTheme theme;
  final ForkPalette palette;
  final ForkLabels labels;
  final ForkGeometry geo;

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
    final c = controller;
    final out = 1 - c.chrome.value.clamp(0.0, 1.0);
    final gesture = c.visible.value;
    final lift = c.lift;

    if (gesture) {
      final a = ((lift - 18) / 22).clamp(0.0, 1.0) * out;
      if (a > 0) {
        if (!c.viewSingle) {
          for (final side in ForkSide.values) {
            _chip(canvas, side, out, lift);
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
    // The end-side chip lags a beat behind, as in the prototype.
    var b = c.bloom.value;
    if (side == ForkSide.right) b = (b - 0.1) / 0.9;
    if (b <= 0.001) return;
    final arm = (side == ForkSide.left ? c.armLeft : c.armRight).value.clamp(0.0, 1.0);
    final other = (side == ForkSide.left ? c.armRight : c.armLeft).value.clamp(0.0, 1.0);
    final col = palette.of(o);
    final from = geo.circleCenter(lift);
    final to = geo.chipCenter(side, lift);
    final center = Offset.lerp(from, to, b)!;
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
      old.theme != theme ||
      old.geo.size != geo.size ||
      old.geo.dockHeight != geo.dockHeight ||
      old.labels.l != labels.l;
}
