import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'demo_kit.dart';

// Jungle Fist's demos: two plain fighters on a floor, and the control or
// idea the step is about drawn over them. Painted from nothing but shapes, so
// they look the same whatever look the player chose for the fight itself.

enum FightDemoKind { controls, meter, block, grab, chain, rounds }

const _warm = Color(0xFFFF8A4C);
const _gold = Color(0xFFFFC53D);
const _cool = Color(0xFF5E7CE2);

class FightDemo extends HowToDemo {
  const FightDemo(this.kind);

  final FightDemoKind kind;

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final w = f.size.width;
    final h = f.size.height;
    final s = f.side;
    final floor = h * 0.74;
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.06, floor, w * 0.94, floor + s * 0.02, Radius.circular(s)),
      Paint()..color = f.theme.ink.withValues(alpha: 0.14),
    );
    switch (kind) {
      case FightDemoKind.controls:
        _fighter(canvas, f, Offset(w * 0.30, floor), _warm, lean: 0.4 * f.seg(0.1, 0.5));
        _fighter(canvas, f, Offset(w * 0.70, floor), _cool, facing: -1);
        // The stick on the left, four buttons on the right.
        final stick = Offset(w * 0.18, h * 0.40);
        final knob = stick + Offset(s * 0.07 * f.seg(0.1, 0.5), 0);
        _disc(canvas, stick, s * 0.11, f.theme.ink.withValues(alpha: 0.12));
        _disc(canvas, knob, s * 0.06, f.theme.ink.withValues(alpha: 0.45));
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 - math.pi / 2;
          final c = Offset(w * 0.82, h * 0.40) + Offset(math.cos(a), math.sin(a)) * s * 0.10;
          final lit = f.seg(0.55 + i * 0.1, 0.62 + i * 0.1) > 0 && f.t < 0.62 + i * 0.1 + 0.08;
          _disc(canvas, c, s * 0.055, (lit ? _gold : f.theme.ink.withValues(alpha: 0.18)));
        }
      case FightDemoKind.meter:
        final fill = f.seg(0.1, 0.8, Curves.linear) * 2;
        for (var i = 0; i < 2; i++) {
          final r = Rect.fromLTWH(w * 0.2, h * 0.30 + i * s * 0.16, w * 0.6, s * 0.10);
          final rr = RRect.fromRectAndRadius(r, Radius.circular(s));
          canvas.drawRRect(rr, Paint()..color = f.theme.ink.withValues(alpha: 0.12));
          final p = (fill - i).clamp(0.0, 1.0);
          if (p > 0) {
            canvas.drawRRect(
              RRect.fromLTRBR(r.left, r.top, r.left + r.width * p, r.bottom, Radius.circular(s)),
              Paint()..color = i == 1 && p >= 1 ? _gold : _warm,
            );
          }
        }
        if (fill >= 2) _burst(canvas, Offset(w * 0.5, h * 0.18), s * 0.12 * f.seg(0.8, 0.9), _gold);
      case FightDemoKind.block:
        final hit = f.seg(0.35, 0.5);
        _fighter(canvas, f, Offset(w * 0.30, floor), _warm, crouch: f.at(0.55) ? 0.35 : 0);
        _fighter(canvas, f, Offset(w * 0.70 - s * 0.1 * hit, floor), _cool, facing: -1, lean: 0.5 * hit);
        if (f.at(0.5) && f.t < 0.85) {
          _shield(canvas, Offset(w * 0.42, floor - s * 0.20), s * 0.12, f.seg(0.5, 0.6));
        }
      case FightDemoKind.grab:
        final close = f.seg(0.1, 0.4);
        final thrown = f.seg(0.5, 0.8);
        _fighter(canvas, f, Offset(w * 0.40 - s * 0.05 * (1 - close), floor), _warm, lean: 0.3 * close);
        final lift = math.sin(math.pi * thrown) * s * 0.30;
        _fighter(
          canvas,
          f,
          Offset(w * 0.52 + s * 0.30 * thrown, floor - lift),
          _cool,
          facing: -1,
          lean: -2.4 * thrown,
        );
      case FightDemoKind.chain:
        final hits = f.count(const [0.15, 0.35, 0.55, 0.78]);
        _fighter(canvas, f, Offset(w * 0.34, floor), _warm, lean: 0.3 * (hits > 0 ? 1 : 0));
        _fighter(canvas, f, Offset(w * 0.68, floor), _cool, facing: -1, lean: 0.15 * hits);
        for (var i = 0; i < hits; i++) {
          final c = Offset(w * 0.12 + i * w * 0.19, h * 0.16);
          _disc(canvas, c, s * 0.05, i == 3 ? _gold : _warm);
        }
        if (hits == 4) _burst(canvas, Offset(w * 0.56, floor - s * 0.2), s * 0.10, _gold);
      case FightDemoKind.rounds:
        final won = f.count(const [0.3, 0.65]);
        for (var i = 0; i < 3; i++) {
          final c = Offset(w * 0.5 + (i - 1) * s * 0.20, h * 0.34);
          _disc(canvas, c, s * 0.07, f.theme.ink.withValues(alpha: 0.12));
          if (i < won) _disc(canvas, c, s * 0.07, _gold);
        }
        // The clock sweeping round the middle.
        final arc = Rect.fromCircle(center: Offset(w * 0.5, h * 0.66), radius: s * 0.14);
        canvas.drawArc(
          arc,
          -math.pi / 2,
          2 * math.pi * (1 - f.seg(0.05, 0.95, Curves.linear)),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.035
            ..strokeCap = StrokeCap.round
            ..color = _warm,
        );
    }
  }
}

void _disc(Canvas canvas, Offset c, double r, Color color) =>
    canvas.drawCircle(c, r, Paint()..color = color);

/// A stick-figure-with-a-body fighter standing at [foot] (floor level).
void _fighter(
  Canvas canvas,
  DemoFrame f,
  Offset foot,
  Color color, {
  double facing = 1,
  double lean = 0,
  double crouch = 0,
}) {
  final s = f.side;
  final bodyH = s * 0.28 * (1 - crouch);
  canvas.save();
  canvas.translate(foot.dx, foot.dy);
  canvas.rotate(lean * 0.25 * facing);
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(-s * 0.05, -bodyH, s * 0.10, bodyH),
    Radius.circular(s * 0.05),
  );
  canvas.drawRRect(body, Paint()..color = color);
  canvas.drawCircle(Offset(0, -bodyH - s * 0.05), s * 0.06, Paint()..color = color);
  // A fist out front.
  canvas.drawCircle(
    Offset(facing * s * (0.09 + 0.06 * lean.abs().clamp(0.0, 1.0)), -bodyH * 0.7),
    s * 0.03,
    Paint()..color = color,
  );
  canvas.restore();
}

void _burst(Canvas canvas, Offset c, double r, Color color) {
  if (r <= 0) return;
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi / 8;
    final rr = i.isEven ? r : r * 0.55;
    final p = c + Offset(math.cos(a), math.sin(a)) * rr;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

void _shield(Canvas canvas, Offset c, double r, double a) {
  if (a <= 0) return;
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: r),
    -math.pi / 2.2,
    math.pi / 1.1,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round
      ..color = _gold.withValues(alpha: a),
  );
}
