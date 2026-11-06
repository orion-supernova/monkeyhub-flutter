import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../theme/vanish_palette.dart';
import '../progress_ring.dart';
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

/// Where everything sits, in the overlay's own coordinates.
class ForkGeometry {
  ForkGeometry(this.size, double bottomPad)
      : baseY = size.height - bottomPad - 58;

  static const orbSize = 68.0;
  static const chipW = 132.0;
  static const chipH = 112.0;
  static const chipSpread = 92.0;

  final Size size;

  /// Where the orb rests: where the composer's centre line is.
  final double baseY;

  double get cx => size.width / 2;

  /// Chip centres: centred on screen, never clipped, 150pt above the fork line.
  Offset chipCenter(ForkSide s) => Offset(
        cx + (s == ForkSide.left ? -chipSpread : chipSpread),
        baseY - 96 - 150 + 6,
      );

  /// The orb's centre, scale and opacity for the controller's current frame.
  ({Offset pos, double scale, double opacity}) orb(SwipeForkController c) {
    final p = c.viewP;
    final base = Offset(cx + c.viewLean, baseY - c.viewTravel);
    var scale = 0.55 + 0.45 * p;
    var opacity = math.min(1.0, p * 2.2);
    var pos = base;
    final f = c.flight.value.clamp(0.0, 1.0);
    switch (c.exit) {
      case ForkExit.none:
        break;
      case ForkExit.cancel:
        pos = Offset.lerp(base, Offset(c.thumbX.clamp(0.0, size.width), baseY), f)!;
        scale = ui.lerpDouble(scale, 0.4, f)!;
      case ForkExit.commitTalk:
        pos = Offset.lerp(base, Offset(cx, size.height - 110), f)!;
        scale = ui.lerpDouble(scale, 0.6, f)!;
      case ForkExit.commitVanish:
        scale = ui.lerpDouble(scale, 1.5, f)!;
    }
    if (c.exit != ForkExit.none) {
      opacity = (c.exit == ForkExit.cancel ? opacity : 1.0) *
          (1 - c.orbFade.value.clamp(0.0, 1.0));
      final s = c.shake.value;
      if (s > 0 && s < 1) {
        pos += Offset(math.sin(s * math.pi * 4) * 10 * (1 - s), 0);
      }
    }
    return (pos: pos, scale: scale, opacity: opacity);
  }
}

/// The fork's picture: scrim, orb, chips, tether and hint. Mount it above the
/// whole screen (it ignores pointers). Everything animates through painters and
/// transforms driven by the controller, so a pull never rebuilds the transcript
/// or this widget; and nothing here is a blur.
class SwipeForkOverlay extends StatelessWidget {
  const SwipeForkOverlay({super.key, required this.controller});

  final SwipeForkController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    controller
      ..calm = MotionScope.of(context).calm
      ..rtl = Directionality.of(context) == TextDirection.rtl;
    final labels = ForkLabels(AppLocalizations.of(context));
    final palette = ForkPalette(theme);
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visible,
      builder: (context, on, _) {
        if (!on) return const SizedBox.shrink();
        return IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: LayoutBuilder(
              builder: (context, box) {
                final geo = ForkGeometry(box.biggest, bottomPad);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: ForkScenePainter(
                          controller: controller,
                          theme: theme,
                          palette: palette,
                          labels: labels,
                          geo: geo,
                        ),
                      ),
                    ),
                    _ForkOrb(
                      controller: controller,
                      theme: theme,
                      palette: palette,
                      geo: geo,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ───────── the orb ─────────

class _ForkOrb extends StatelessWidget {
  const _ForkOrb({
    required this.controller,
    required this.theme,
    required this.palette,
    required this.geo,
  });

  final SwipeForkController controller;
  final AppTheme theme;
  final ForkPalette palette;
  final ForkGeometry geo;

  @override
  Widget build(BuildContext context) {
    // Built once; the transform around it is what moves.
    final orb = SizedBox(
      width: ForkGeometry.orbSize,
      height: ForkGeometry.orbSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: ForkOrbPainter(
              controller: controller,
              theme: theme,
              palette: palette,
            ),
          ),
          ProgressRing.animated(
            animation: controller.pullValue,
            color: theme.ink.withValues(alpha: 0.8),
            trackColor: theme.divider.withValues(alpha: 0.5),
            strokeWidth: 3,
            inset: 1.5,
          ),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: controller.repaint,
      child: RepaintBoundary(child: orb),
      builder: (context, child) {
        final o = geo.orb(controller);
        const h = ForkGeometry.orbSize / 2;
        return Align(
          alignment: Alignment.topLeft,
          child: Transform(
            transform: Matrix4.translationValues(o.pos.dx - h, o.pos.dy - h, 0),
            child: Transform.scale(
              scale: o.scale,
              child: Opacity(opacity: o.opacity.clamp(0.0, 1.0), child: child),
            ),
          ),
        );
      },
    );
  }
}

class ForkOrbPainter extends CustomPainter {
  ForkOrbPainter({
    required this.controller,
    required this.theme,
    required this.palette,
  }) : super(repaint: controller.repaint);

  final SwipeForkController controller;
  final AppTheme theme;
  final ForkPalette palette;

  // The three strokes of the glyph at each of its shapes, on a 24pt grid.
  static const _arrow = [
    [12.0, 19.0, 12.0, 5.0],
    [6.0, 11.0, 12.0, 5.0],
    [12.0, 5.0, 18.0, 11.0],
  ];
  static const _fork = [
    [12.0, 21.0, 12.0, 12.0],
    [5.0, 4.0, 12.0, 12.0],
    [19.0, 4.0, 12.0, 12.0],
  ];
  static const _check = [
    [12.0, 12.0, 12.0, 12.0],
    [5.0, 12.0, 10.0, 17.0],
    [10.0, 17.0, 19.0, 7.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 6;

    // Neutral until a side arms; then the side's colour.
    final al = c.armLeft.value.clamp(0.0, 1.0);
    final ar = c.armRight.value.clamp(0.0, 1.0);
    final raised = theme.surfaceRaised;
    var c0 = Color.lerp(raised, theme.ink, 0.12)!;
    var c1 = raised;
    var c2 = Color.lerp(raised, theme.background, 0.5)!;
    var glyphColor = theme.ink;
    void tint(ForkOption? o, double a) {
      if (o == null || a <= 0) return;
      final col = palette.of(o);
      c0 = Color.lerp(c0, Color.lerp(col, const Color(0xFFFFFFFF), 0.3), a)!;
      c1 = Color.lerp(c1, col, a)!;
      c2 = Color.lerp(c2, Color.lerp(col, const Color(0xFF000000), 0.25), a)!;
      glyphColor = Color.lerp(glyphColor, ForkPalette.onColor(col), a)!;
    }

    tint(c.viewLeft, al);
    tint(c.viewRight, ar);

    // A soft lift instead of a blur: the framework's own elevation shadow.
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
      theme.ink,
      8,
      false,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          center + Offset(-r * 0.3, -r * 0.44),
          r * 1.6,
          [c0, c1, c2],
          const [0, 0.55, 1],
        ),
    );

    final pulse = c.pulse.value;
    if (pulse > 0 && pulse < 1) {
      canvas.drawCircle(
        center,
        r * (1 + 1.1 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = glyphColor.withValues(alpha: 0.5 * (1 - pulse)),
      );
    }

    // Arrow -> fork -> check, endpoint by endpoint.
    final g = c.glyph.value;
    final k = c.check.value.clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = glyphColor;
    final s = 26 / 24;
    final origin = center - const Offset(13, 13);
    for (var i = 0; i < 3; i++) {
      double at(int j) {
        final a = ui.lerpDouble(_arrow[i][j], _fork[i][j], g)!;
        return ui.lerpDouble(a, _check[i][j], k)!;
      }

      canvas.drawLine(
        origin + Offset(at(0), at(1)) * s,
        origin + Offset(at(2), at(3)) * s,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ForkOrbPainter old) =>
      old.theme != theme || old.palette.talk != palette.talk;
}

// ───────── chips, tether, hint, scrim ─────────

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

    // Scrim: an opaque colour, only its opacity moves.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.background.withValues(alpha: 0.6 * c.viewP * out),
    );

    if (!c.viewSingle) {
      _tether(canvas, out);
      for (final side in ForkSide.values) {
        _chip(canvas, side, out);
      }
    }
    _hint(canvas, out);
  }

  void _tether(Canvas canvas, double out) {
    final c = controller;
    final side = c.viewArmed;
    if (c.calm || side == null || c.exit != ForkExit.none) return;
    final o = side == ForkSide.left ? c.viewLeft : c.viewRight;
    if (o == null) return;
    final arm = (side == ForkSide.left ? c.armLeft : c.armRight).value.clamp(0.0, 1.0);
    final orb = geo.orb(c).pos;
    final chip = geo.chipCenter(side);
    final end = Offset(chip.dx, chip.dy + ForkGeometry.chipH / 2 - 6);
    final start = Offset(orb.dx, orb.dy - 30);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2,
        math.min(start.dy, end.dy) - 30,
        end.dx,
        end.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = palette.of(o).withValues(alpha: 0.85 * arm * out),
    );
  }

  void _chip(Canvas canvas, ForkSide side, double out) {
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
    final from = geo.orb(c).pos;
    final to = geo.chipCenter(side);
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

  void _hint(Canvas canvas, double out) {
    final c = controller;
    final reason = c.failReason;
    String top, sub;
    double alpha;
    if (reason != null && reason.isNotEmpty) {
      top = reason;
      sub = '';
      alpha = 1 - c.orbFade.value.clamp(0.0, 1.0);
    } else {
      final (t, s) = labels.hint(c);
      top = t;
      sub = s;
      alpha = ((c.viewP - 0.05) * 10).clamp(0.0, 1.0) * out;
    }
    if (alpha <= 0) return;
    final w = geo.size.width - 48;
    final a = _tp(top, theme.bodyEmph.copyWith(fontSize: 13, color: theme.ink), w);
    final b = sub.isEmpty
        ? null
        : _tp(sub, theme.caption.copyWith(fontSize: 11.5, color: theme.inkMuted), w);
    final total = a.height + (b?.height ?? 0);
    final y = geo.baseY + 8 - total / 2;
    canvas.saveLayer(
      Rect.fromLTWH(0, y - 4, geo.size.width, total + 8),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
    a.paint(canvas, Offset((geo.size.width - a.width) / 2, y));
    b?.paint(canvas, Offset((geo.size.width - b.width) / 2, y + a.height));
    canvas.restore();
  }

  @override
  bool shouldRepaint(ForkScenePainter old) =>
      old.theme != theme || old.geo.size != geo.size || old.labels.l != labels.l;
}
