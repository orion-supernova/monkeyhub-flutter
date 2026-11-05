// The three HUD designs (cartoon / painted / pixel) from the style lab, plus
// round intro, K.O., match result and the combo counter.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextStyle, TextDirection, FontWeight, TextSpan, TextAlign;
import 'package:google_fonts/google_fonts.dart';

import '../../core/core.dart';
import 'art_common.dart';
import 'glow.dart';
import 'hud_text.dart';

class HudPainter {
  final Map<String, TextPainter> _tps = {};
  final Paint _f = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  double _tr0 = 1, _tr1 = 1;
  int _lastFrame = -1;

  // ---------------------------------------------------------------- text

  TextStyle _base(FightLook look) {
    switch (look) {
      case FightLook.cartoon:
        return GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800);
      case FightLook.painted:
        return GoogleFonts.anta();
      case FightLook.pixel:
        return GoogleFonts.doto(fontWeight: FontWeight.w900);
    }
  }

  TextPainter _tp(String text, double size, FightLook look, Color color, {Color? stroke, double strokeW = 0}) {
    final key = '${look.index}|$size|$text|${color.toARGB32()}|${stroke?.toARGB32()}|$strokeW';
    var tp = _tps[key];
    if (tp == null) {
      if (_tps.length > 300) _tps.clear();
      var st = _base(look).copyWith(fontSize: size, height: 1.0, letterSpacing: look == FightLook.pixel ? 1 : 0);
      st = stroke != null
          ? st.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeW
                ..strokeJoin = StrokeJoin.round
                ..color = stroke)
          : st.copyWith(color: color);
      tp = TextPainter(text: TextSpan(text: text, style: st), textDirection: TextDirection.ltr, textAlign: TextAlign.left)
        ..layout();
      _tps[key] = tp;
    }
    return tp;
  }

  /// [ax] -1 left / 0 centre / 1 right anchor on x; [ay] 0 top / .5 middle / 1 bottom.
  void _text(Canvas c, String text, Offset at, double size, FightLook look, Color fill,
      {Color? stroke, double strokeW = 0, double ax = 0, double ay = .5, double maxW = 1e9, Color? shadow, Offset shadowOff = const Offset(1.5, 2)}) {
    if (text.isEmpty) return;
    final base = _tp(text, size, look, fill);
    final k = base.width > maxW ? maxW / base.width : 1.0;
    final w = base.width, h = base.height;
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(k);
    final ox = -w * (ax + 1) / 2, oy = -h * ay;
    if (shadow != null) _tp(text, size, look, shadow).paint(c, Offset(ox + shadowOff.dx, oy + shadowOff.dy));
    if (stroke != null) _tp(text, size, look, fill, stroke: stroke, strokeW: strokeW).paint(c, Offset(ox, oy));
    base.paint(c, Offset(ox, oy));
    c.restore();
  }

  // ---------------------------------------------------------------- main

  void _advance(FightState s) {
    final h0 = s.p[0].health / s.chars[0].maxHealth, h1 = s.p[1].health / s.chars[1].maxHealth;
    final d = s.frame - _lastFrame;
    if (_lastFrame < 0 || d < 0 || d > 40) {
      _tr0 = h0;
      _tr1 = h1;
    } else {
      for (var i = 0; i < d; i++) {
        _tr0 += (h0 - _tr0) * .06;
        _tr1 += (h1 - _tr1) * .06;
      }
      if (_tr0 < h0) _tr0 = h0;
      if (_tr1 < h1) _tr1 = h1;
    }
    _lastFrame = s.frame;
  }

  void paint(Canvas c, Size size, FightState s, FightLook look, List<String> names, FightHudText t) {
    _advance(s);
    final su = math.min(size.width / 640, size.height / 400);
    final halfW = size.width / su / 2;
    final barW = (halfW - 70).clamp(250.0, 400.0).toDouble();
    const inner = 38.0;
    c.save();
    c.translate(size.width / 2, 0);
    c.scale(su);

    final hp = [for (var i = 0; i < 2; i++) clamp01(s.p[i].health / s.chars[i].maxHealth)];
    final tr = [_tr0.clamp(0.0, 1.0), _tr1.clamp(0.0, 1.0)];
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      _bar(c, look, side, barW, inner, hp[i], tr[i], s.p[i], i < names.length ? names[i] : 'P${i + 1}', s.frame);
    }
    _timer(c, look, s);
    _combo(c, look, s, halfW, t);
    _banners(c, look, s, names, t, halfW);
    c.restore();
  }

  // ---------------------------------------------------------------- bars

  void _bar(Canvas c, FightLook look, double side, double barW, double inner, double val, double tr, Fighter f, String name, int frame) {
    final outerX = side * (inner + barW);
    // Bar geometry in "bar space": x = 0 at the centre end, growing outward.
    c.save();
    c.translate(side * inner, 22);
    c.scale(side, 1);
    switch (look) {
      case FightLook.cartoon:
        final shape = Path()
          ..moveTo(0, 0)
          ..lineTo(barW, 0)
          ..lineTo(barW + 10, 22)
          ..lineTo(12, 22)
          ..close();
        c.drawPath(shape, _f..shader = null..color = const Color(0xFF2a1838));
        c.save();
        c.clipPath(shape);
        c.drawRect(Rect.fromLTWH(-2, 0, barW * tr + 12, 22), _f..color = const Color(0xFFff4f6e));
        c.drawRect(Rect.fromLTWH(-2, 0, barW * val + 12, 22), _f..color = val < .25 ? const Color(0xFFff7a3a) : const Color(0xFFffd23a));
        c.drawRect(const Rect.fromLTWH(-2, 3, 1000, 4), _f..color = const Color(0x80FFFFFF));
        c.restore();
        c.drawPath(shape, _s..strokeWidth = 3..color = kInk);
        break;
      case FightLook.painted:
        final rr = RRect.fromLTRBR(-4, -4, barW + 4, 18, const Radius.circular(7));
        c.drawRRect(rr, _f..shader = null..color = const Color(0xA60A0612));
        c.drawRRect(rr, _s..strokeWidth = 1.2..color = const Color(0xA6FFD696));
        final tw = barW * tr, vw = barW * val;
        if (tw > 1) {
          c.drawRRect(RRect.fromLTRBR(0, 0, tw, 14, const Radius.circular(5)),
              _f..shader = Gradient.linear(Offset.zero, const Offset(0, 14), const [Color(0xFFff8fa3), Color(0xFFc2183e)]));
        }
        if (vw > 1) {
          c.drawRRect(RRect.fromLTRBR(0, 0, vw, 14, const Radius.circular(5)),
              _f..shader = Gradient.linear(Offset.zero, const Offset(0, 14), const [Color(0xFFfff3b0), Color(0xFFffc44d), Color(0xFFe8761f)], const [0, .5, 1]));
          drawGlow(c, Offset(vw * .5, 7), math.max(20, vw * .55), const Color(0x59FFB347));
          c.drawRect(Rect.fromLTWH(3, 2, math.max(0, vw - 6), 3), _f..shader = null..color = const Color(0x59FFFFFF));
        }
        _f.shader = null;
        break;
      case FightLook.pixel:
        const segs = 20;
        final sw = barW / segs;
        for (var j = 0; j < segs; j++) {
          final on = (j + .5) / segs <= val;
          final low = j >= segs - 4;
          c.drawRect(Rect.fromLTWH(j * sw, 0, sw, 16), _f..shader = null..color = kInk);
          c.drawRect(Rect.fromLTWH(j * sw + 1, 1, sw - 2, 14),
              _f..color = on ? (low ? const Color(0xFFff4f6e) : const Color(0xFFffd23a)) : ((j + .5) / segs <= tr ? const Color(0xFF8a3048) : const Color(0xFF3a2648)));
        }
        break;
    }
    c.restore();

    // name, anchored to the bar's outer end
    final ax = side < 0 ? -1.0 : 1.0; // text starts at the outer end and runs inward
    final nameAt = Offset(outerX, 54);
    // meter segments (3), outer end, under the bar
    final segW = barW * .17;
    for (var k = 0; k < meterBars; k++) {
      final fr = clamp01((f.meter - k * meterBar) / meterBar);
      final x0 = side < 0 ? outerX + k * (segW + 3) : outerX - segW - k * (segW + 3);
      final r = Rect.fromLTWH(x0, 50, segW, 7);
      final ready = f.meter >= superCost;
      final pulse = ready ? .65 + .35 * math.sin(frame * .25) : 1.0;
      final back = look == FightLook.pixel ? const Color(0xFF3a2648) : const Color(0xFF241a30);
      c.drawRect(r, _f..shader = null..color = back);
      if (fr > 0) {
        final fillR = side < 0 ? Rect.fromLTWH(x0, 50, segW * fr, 7) : Rect.fromLTWH(x0 + segW * (1 - fr), 50, segW * fr, 7);
        final col = fr >= 1 ? (ready ? Color.lerp(const Color(0xFF3fd2c7), const Color(0xFFd6fffb), 1 - pulse)! : const Color(0xFF3fd2c7)) : const Color(0xFF2a9d94);
        c.drawRect(fillR, _f..color = col);
        if (look == FightLook.painted && fr >= 1) drawGlow(c, r.center, 14, withA(col, .35 * pulse));
      }
      if (look != FightLook.painted) {
        c.drawRect(r, _s..strokeWidth = look == FightLook.cartoon ? 1.6 : 1..color = kInk);
      } else {
        c.drawRect(r, _s..strokeWidth = .8..color = const Color(0x80FFD696));
      }
    }
    // win pips next to the timer
    for (var j = 0; j < roundsToWin; j++) {
      final cx = side * (inner + 10 + j * 14.0);
      final won = j < f.wins;
      c.drawCircle(Offset(cx, 56), 4.5, _f..shader = null..color = won ? const Color(0xFFffd23a) : const Color(0xFF241a30));
      c.drawCircle(Offset(cx, 56), 4.5, _s..strokeWidth = look == FightLook.cartoon ? 1.8 : 1..color = look == FightLook.painted ? const Color(0xA6FFD696) : kInk);
      if (won && look == FightLook.painted) drawGlow(c, Offset(cx, 56), 11, const Color(0x80FFC44D));
    }
    // name last so it sits on top
    _name(c, look, name, nameAt.translate(side < 0 ? 4 : -4, 8), ax, barW * .85);
  }

  void _name(Canvas c, FightLook look, String name, Offset at, double ax, double maxW) {
    switch (look) {
      case FightLook.cartoon:
        _text(c, name, at, 20, look, const Color(0xFFFFFFFF), stroke: kInk, strokeW: 5, ax: ax, ay: 0, maxW: maxW);
        break;
      case FightLook.painted:
        _text(c, name, at, 22, look, const Color(0xFFfff2dc), ax: ax, ay: 0, maxW: maxW, shadow: const Color(0x99000000), shadowOff: const Offset(0, 2));
        break;
      case FightLook.pixel:
        _text(c, name, at, 18, look, const Color(0xFFFFFFFF), ax: ax, ay: 0, maxW: maxW, shadow: kInk, shadowOff: const Offset(1.5, 1.5));
        break;
    }
  }

  // ---------------------------------------------------------------- timer

  void _timer(Canvas c, FightLook look, FightState s) {
    final secs = (s.timer.clamp(0, roundFrames) / fps).ceil();
    final low = secs <= 10 && s.phase == Phase.fight;
    final txt = '$secs';
    const at = Offset(0, 34);
    switch (look) {
      case FightLook.cartoon:
        c.drawPath(starPath(0, 34, 30, 22, 12, 0), _f..shader = null..color = low ? const Color(0xFFff4f6e) : const Color(0xFFff4f6e));
        c.drawPath(starPath(0, 34, 30, 22, 12, 0), _s..strokeWidth = 3..color = kInk);
        _text(c, txt, at, 26, look, const Color(0xFFFFFFFF), stroke: kInk, strokeW: 5, maxW: 36);
        break;
      case FightLook.painted:
        drawGlow(c, at, 40, Color.fromRGBO(255, 157, 92, low ? .6 : .35));
        _text(c, txt, at, 40, look, low ? const Color(0xFFffb0b8) : const Color(0xFFfff2dc), maxW: 52);
        break;
      case FightLook.pixel:
        _text(c, txt, at, 34, look, low ? const Color(0xFFff4f6e) : const Color(0xFFffd23a), maxW: 54, shadow: kInk, shadowOff: const Offset(2, 2));
        break;
    }
  }

  // ---------------------------------------------------------------- combo

  void _combo(Canvas c, FightLook look, FightState s, double halfW, FightHudText t) {
    int victim = -1, n = 1;
    for (var i = 0; i < 2; i++) {
      if (s.p[i].comboHits > n) {
        n = s.p[i].comboHits;
        victim = i;
      }
    }
    if (victim < 0) return;
    // Pop from the latest hit event on this victim.
    var age = 99;
    for (final e in s.events) {
      if ((e.kind == Ev.hit || e.kind == Ev.counterHit || e.kind == Ev.throwHit) && e.player == 1 - victim) {
        age = math.min(age, s.frame - e.frame);
      }
    }
    final pop = 1 + math.max(0, (8 - age) / 8) * .4;
    final x = (victim == 1 ? 1 : -1) * (halfW - 100);
    final maxW = 170.0;
    c.save();
    c.translate(x, 130);
    c.rotate(victim == 1 ? -.12 : .12);
    c.scale(pop);
    final txt = t.hits(n);
    switch (look) {
      case FightLook.cartoon:
        _text(c, txt, Offset.zero, 34, look, const Color(0xFFffd23a), stroke: kInk, strokeW: 8, maxW: maxW);
        break;
      case FightLook.painted:
        drawGlow(c, Offset.zero, 70, const Color(0x59FF7B3A));
        _text(c, txt, Offset.zero, 44, look, const Color(0xFFfff7d6), maxW: maxW, shadow: const Color(0x99FF7B3A), shadowOff: const Offset(0, 3));
        break;
      case FightLook.pixel:
        if (age > 20 || s.frame % 8 < 4 || true) {
          _text(c, txt, Offset.zero, 26, look, const Color(0xFFffd23a), maxW: maxW, shadow: kInk, shadowOff: const Offset(2, 2));
        }
        break;
    }
    c.restore();
  }

  // ---------------------------------------------------------------- banners

  void _banner(Canvas c, FightLook look, String text, double y, double size, double scale, double alpha, double maxW, {bool gold = true}) {
    if (alpha <= 0 || text.isEmpty) return;
    c.save();
    c.translate(0, y);
    c.scale(scale);
    if (alpha < 1) {
      c.saveLayer(Rect.fromCenter(center: Offset.zero, width: maxW * 1.4, height: size * 3), Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    }
    switch (look) {
      case FightLook.cartoon:
        c.rotate(-.05);
        _text(c, text, Offset.zero, size, look, gold ? const Color(0xFFffd23a) : const Color(0xFFFFFFFF), stroke: kInk, strokeW: size * .22, maxW: maxW);
        break;
      case FightLook.painted:
        drawGlow(c, Offset.zero, maxW * .5, const Color(0x59FF9D5C));
        _text(c, text, Offset.zero, size, look, const Color(0xFFfff2dc), maxW: maxW, shadow: const Color(0xB3FF7B3A), shadowOff: Offset(0, size * .05));
        break;
      case FightLook.pixel:
        _text(c, text, Offset.zero, size, look, gold ? const Color(0xFFffd23a) : const Color(0xFFFFFFFF), maxW: maxW, shadow: kInk, shadowOff: Offset(size * .06, size * .06));
        break;
    }
    if (alpha < 1) c.restore();
    c.restore();
  }

  void _banners(Canvas c, FightLook look, FightState s, List<String> names, FightHudText t, double halfW) {
    final maxW = math.min(halfW * 2 * .86, 560.0);
    double pop(int a, [double amt = .7]) => 1 + amt * (1 - easeOut(a / 9));
    String nm(int i) => i >= 0 && i < names.length ? names[i] : 'P${i + 1}';
    switch (s.phase) {
      case Phase.intro:
        final e = introFrames - s.phaseTimer;
        if (e < 56) {
          _banner(c, look, t.round(s.round), 150, 54, pop(e), e > 48 ? (56 - e) / 8 : 1, maxW, gold: false);
        } else {
          final k = e - 56;
          _banner(c, look, t.fight, 150, 74, pop(k, 1.0), k > 26 ? (34 - k) / 8 : 1, maxW);
        }
        break;
      case Phase.ko:
        final e = koFrames - s.phaseTimer;
        _banner(c, look, s.timeOver ? t.time : t.ko, 150, 84, pop(e, 1.2), 1, maxW);
        if (e >= 50) {
          final txt = s.roundWinner == 0 || s.roundWinner == 1 ? t.wins(nm(s.roundWinner)) : t.draw;
          _banner(c, look, txt, 215, 32, 1, clamp01((e - 50) / 8), maxW, gold: false);
        }
        break;
      case Phase.over:
        c.drawRect(Rect.fromLTWH(-halfW - 10, 0, halfW * 2 + 20, 600), _f..shader = null..color = const Color(0x4D000000));
        final txt = s.matchWinner == 0 || s.matchWinner == 1 ? t.wins(nm(s.matchWinner)) : t.draw;
        _banner(c, look, txt, 160, 62, 1, 1, maxW);
        break;
    }
  }
}
