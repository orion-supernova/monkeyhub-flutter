import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../game_canvas.dart';

/// A looping, hand-scripted mini game: the picture beside one step of a
/// how-to-play guide.
///
/// A demo is a pure function of time. [paint] gets the loop position `t`
/// (0..1) and draws the whole frame from scratch: the board as it stands at
/// that moment, then the ghost finger, ripples and sparkles on top. There is
/// no state between frames, which is what keeps a demo cheap (one
/// [CustomPainter] repaint per tick, no widget rebuilds) and what lets reduced
/// motion show a single still frame ([still]) with no special casing.
///
/// Boards are drawn by the real games' own painters, so a demo looks exactly
/// like the board the player is about to open.
abstract class HowToDemo {
  const HowToDemo();

  /// One full loop, including the beat it holds on the finished state.
  Duration get period => const Duration(milliseconds: 4200);

  /// The loop position drawn as a still picture under reduced motion: the
  /// moment that explains the step best, usually just after the point lands.
  double get still => 0.8;

  void paint(Canvas canvas, DemoFrame f);
}

/// Everything a demo needs to draw one frame.
class DemoFrame {
  DemoFrame({
    required this.theme,
    required this.size,
    required this.t,
    this.periodMs = 4200,
  }) : palette = GamePalette(theme);

  /// The loop's length, for driving a real board painter's own millisecond
  /// animations (a disc falling, a piece sliding) at their true speed.
  final double periodMs;

  final AppTheme theme;
  final GamePalette palette;
  final Size size;

  /// Loop position, 0..1.
  final double t;

  double get side => size.shortestSide;

  /// 0 before [a], 1 after [b], eased in between.
  double seg(double a, double b, [Curve curve = Curves.easeInOutCubic]) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    return curve.transform((t - a) / (b - a));
  }

  /// Whether the loop has reached [a].
  bool at(double a) => t >= a;

  /// A placement pop for something that lands at [a]: 0 → 1 over a short
  /// beat. Feed it to a board painter's `pop`.
  double pop(double a, [double len = 0.07]) => seg(a, a + len, Curves.linear);

  /// How many of [times] the loop has passed.
  int count(List<double> times) {
    var n = 0;
    for (final x in times) {
      if (t >= x) n++;
    }
    return n;
  }
}

/// A board's square, centred in the stage, and the grid inside it.
class DemoBoard {
  DemoBoard(
    DemoFrame f, {
    required this.n,
    this.fraction = 0.86,
    this.lead = 0,
    double dy = 0,
  }) : side = f.side * fraction,
       origin = Offset(
         (f.size.width - f.side * fraction) / 2,
         (f.size.height - f.side * fraction) / 2 + dy * f.side,
       );

  final int n;
  final double fraction;
  final double side;
  final Offset origin;

  /// Nonogram's clue gutter, as a fraction of [side].
  final double lead;

  GameGrid get grid => GameGrid(side: side, n: n, lead: side * lead);

  Size get size => Size.square(side);

  /// A cell's centre in stage coordinates.
  Offset center(int i) => origin + grid.center(i);

  Rect rect(int i) => grid.rect(i).shift(origin);

  /// Paints [painter] into the board square.
  void draw(Canvas canvas, CustomPainter painter) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    painter.paint(canvas, size);
    canvas.restore();
  }
}

/// One point the ghost finger passes through.
class FingerKey {
  const FingerKey(this.t, this.at, {this.tap = false, this.hold = 0});

  final double t;
  final Offset at;

  /// Presses here: a dip and a ripple.
  final bool tap;

  /// A long-press: the finger stays down this long (loop fraction) while a
  /// ring fills around it.
  final double hold;
}

/// The ghost finger: fades in at its first key, glides between keys, presses
/// on taps, fades out after its last.
///
/// Between two keys it moves on an ease curve, so a drag reads as a hand and
/// not a cursor. A key that is not a tap is a waypoint (a drag path).
void paintFinger(Canvas canvas, DemoFrame f, List<FingerKey> keys) {
  if (keys.isEmpty) return;
  final t = f.t;
  final first = keys.first.t;
  final last = keys.last.t + keys.last.hold;
  final fadeIn = ((t - (first - 0.06)) / 0.06).clamp(0.0, 1.0);
  final fadeOut = 1 - ((t - (last + 0.05)) / 0.06).clamp(0.0, 1.0);
  final opacity = math.min(fadeIn, fadeOut);
  if (opacity <= 0) return;

  // Where it is.
  Offset pos = keys.first.at;
  for (var i = 0; i < keys.length; i++) {
    final k = keys[i];
    if (t < k.t) {
      if (i == 0) break;
      final prev = keys[i - 1];
      final from = prev.t + prev.hold;
      final p = from >= k.t
          ? 1.0
          : Curves.easeInOutCubic.transform(
              ((t - from) / (k.t - from)).clamp(0.0, 1.0),
            );
      pos = Offset.lerp(prev.at, k.at, p)!;
      break;
    }
    pos = k.at;
  }

  // How pressed it is, and the ripple of the last tap.
  var press = 0.0;
  double? ripple;
  Offset? rippleAt;
  double? holdFill;
  for (final k in keys) {
    if (!k.tap && k.hold == 0) continue;
    final d = t - k.t;
    if (k.hold > 0) {
      if (d >= -0.03 && d <= k.hold + 0.03) {
        press = math.max(press, 1 - (d < 0 ? -d / 0.03 : 0));
        holdFill = (d / k.hold).clamp(0.0, 1.0);
      }
      if (d > k.hold && d < k.hold + 0.16) {
        ripple = (d - k.hold) / 0.16;
        rippleAt = k.at;
      }
      continue;
    }
    if (d.abs() < 0.035) press = math.max(press, 1 - d.abs() / 0.035);
    if (d >= 0 && d < 0.16) {
      ripple = d / 0.16;
      rippleAt = k.at;
    }
  }

  final theme = f.theme;
  final r = f.side * 0.058;
  if (ripple != null && rippleAt != null) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22 * (1 - ripple)
      ..color = theme.accent.withValues(alpha: 0.55 * (1 - ripple) * opacity);
    canvas.drawCircle(rippleAt, r * (0.9 + ripple * 1.5), ring);
  }

  // The fingertip rests just below and beside the point it touches, the way
  // a real thumb does, so the piece it places stays in view.
  final scale = 1 - press * 0.16;
  final tip = pos + Offset(r * 0.7, r * 0.95) * (1 - press * 0.5);
  final shadow = Paint()
    ..color = const Color(0xFF000000).withValues(alpha: 0.14 * opacity)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  canvas.drawCircle(tip + Offset(0, r * 0.35 * (1 - press)), r * scale, shadow);
  canvas.drawCircle(
    tip,
    r * scale,
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.62 * opacity),
  );
  canvas.drawCircle(
    tip,
    r * scale,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = theme.ink.withValues(alpha: 0.2 * opacity),
  );
  // Where it is touching: a small bright dot under the tip's edge.
  if (press > 0) {
    canvas.drawCircle(
      pos,
      r * 0.22 * press,
      Paint()..color = theme.accent.withValues(alpha: 0.8 * press * opacity),
    );
  }
  if (holdFill != null && holdFill > 0) {
    canvas.drawArc(
      Rect.fromCircle(center: tip, radius: r * 1.45),
      -math.pi / 2,
      math.pi * 2 * holdFill,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.28
        ..color = theme.accent.withValues(alpha: 0.9 * opacity),
    );
  }
}

/// A burst of little four-point sparkles flying out of [center], [p] of the
/// way through (0..1). The "you got it" beat.
void paintSparkles(
  Canvas canvas,
  Offset center,
  double radius,
  double p,
  Color color, {
  int count = 9,
  double seed = 0,
}) {
  if (p <= 0 || p >= 1) return;
  final paint = Paint()..style = PaintingStyle.fill;
  final fly = Curves.easeOutCubic.transform(p);
  for (var i = 0; i < count; i++) {
    final a = seed + i * math.pi * 2 / count + (i.isEven ? 0.18 : -0.12);
    final dist = radius * (0.35 + fly * (i.isEven ? 1.0 : 0.72));
    final at = center + Offset(math.cos(a), math.sin(a)) * dist;
    final s = radius * 0.13 * (1 - p) * (i.isEven ? 1 : 0.7);
    paint.color = (i % 3 == 0 ? const Color(0xFFFFC53D) : color)
        .withValues(alpha: (1 - p * p));
    canvas.drawPath(_sparkle(at, s), paint);
  }
}

Path _sparkle(Offset c, double s) {
  final w = s * 0.32;
  return Path()
    ..moveTo(c.dx, c.dy - s)
    ..quadraticBezierTo(c.dx + w * 0.3, c.dy - w * 0.3, c.dx + s, c.dy)
    ..quadraticBezierTo(c.dx + w * 0.3, c.dy + w * 0.3, c.dx, c.dy + s)
    ..quadraticBezierTo(c.dx - w * 0.3, c.dy + w * 0.3, c.dx - s, c.dy)
    ..quadraticBezierTo(c.dx - w * 0.3, c.dy - w * 0.3, c.dx, c.dy - s)
    ..close();
}

/// A soft rounded spotlight over [rect]: the "look here" of a demo.
void paintSpotlight(
  Canvas canvas,
  Rect rect,
  Color color,
  double strength, {
  double radius = 8,
}) {
  if (strength <= 0) return;
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  canvas.drawRRect(
    rr,
    Paint()..color = color.withValues(alpha: 0.16 * strength),
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = color.withValues(alpha: 0.85 * strength),
  );
}

/// A small label that floats up and fades out of [at]: "+30s", "✓".
void paintFloatLabel(
  Canvas canvas,
  DemoFrame f,
  Offset at,
  String text,
  double p,
  Color color,
) {
  if (p <= 0 || p >= 1) return;
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: f.theme.body.copyWith(
        fontSize: f.side * 0.075,
        fontWeight: FontWeight.w800,
        color: color.withValues(alpha: p < 0.75 ? 1 : (1 - p) / 0.25),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final rise = Curves.easeOutCubic.transform(p) * f.side * 0.1;
  tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2 + rise));
}
