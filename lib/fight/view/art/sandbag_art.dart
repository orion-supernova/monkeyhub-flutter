// The training room's heavy bag: a red bag on a chain that stands in for the
// dummy fighter. The engine still simulates the dummy (hit detection needs
// it); this only replaces how that fighter is drawn.
//
// The swing is view-only state, never part of the deterministic core. It is fed
// from the hit events the engine already records (swing is proportional to the
// damage), stepped by the number of sim frames that passed since the last
// paint, and frozen during hit-stop like the fight itself.
//
// Cost: no clips, no layers, no blur. Every shape is a cached Path built once
// in a local frame (pivot at the origin, y down, world px); a paint is a
// translate / scale / rotate and a handful of drawPath calls.
import 'dart:math' as math;
import 'dart:ui';

import '../../core/core.dart';
import 'art_common.dart';
import 'camera.dart';
import 'glow.dart';

class SandbagArt {
  // ---- geometry, world px. Local frame: pivot at (0,0), y grows downward.
  static const double _top = 162; // height of the bag's top above the ground
  static const double _chain = 300; // pivot to the top of the bag
  static const double _w = 56, _h = 150, _r = 22;
  static const double _ring = _chain - 30; // where the chain splits

  // ---- pendulum, the docs sandbox's numbers
  static const double _gravity = .0062, _damping = .985, _perDamage = .000168, _maxV = .042;

  double _anchor = 0; // world x of the pivot
  double _a = 0, _v = 0; // swing angle (rad) and its speed
  int _flash = 0;
  int _last = -1, _seen = 0;
  bool _snap = true;

  /// Hang still at the dummy's place on the next paint (new move, new room).
  void reset() => _snap = true;

  /// World x of the bag's body centre right now.
  double get bodyX => _anchor + math.sin(_a) * (_chain + _h / 2);

  /// Brings the swing up to [s]: new hits push it, elapsed sim frames step it.
  void update(FightState s, int dummy) {
    final f = s.frame;
    final d = s.p[dummy];
    // Hang the bag a little past the dummy's centre, away from the attacker:
    // a fighter leans into a punch, a bag cannot lean back, so without this
    // the attacker's torso sinks into it.
    final away = s.p[1 - dummy].x <= d.x ? 1.0 : -1.0;
    final dx = d.x / unitsPerPx + away * 22;
    if (_snap || _last < 0 || f < _last || f - _last > 90) {
      _snap = false;
      _anchor = dx;
      _a = _v = 0;
      _flash = 0;
      _seen = f - 1;
      _last = f;
    }
    var newest = _seen;
    for (final e in s.events) {
      if (e.frame <= _seen) continue;
      if (e.frame > newest) newest = e.frame;
      if (e.player != 1 - dummy) continue;
      if (e.kind != Ev.hit && e.kind != Ev.counterHit && e.kind != Ev.throwHit) continue;
      final dir = s.p[1 - dummy].x <= d.x ? 1.0 : -1.0;
      _v = (_v + dir * e.value * _perDamage).clamp(-_maxV, _maxV).toDouble();
      _flash = 6;
    }
    _seen = newest;
    final n = f - _last;
    _last = f;
    final frozen = math.max(s.p[0].stop, s.p[1].stop) > 0;
    // The pivot always tracks the dummy (the engine keeps the bodies apart),
    // a little looser while it reels so the swing reads, never so loose that
    // an advancing attacker walks into the bag.
    final settled = switch (d.state) {
      St.idle || St.walk || St.crouch || St.landing => true,
      _ => false,
    };
    final follow = settled ? .2 : .45;
    for (var i = 0; i < n; i++) {
      if (!frozen) {
        _v += -math.sin(_a) * _gravity;
        _v *= _damping;
        _a += _v;
        if (_flash > 0) _flash--;
      }
      _anchor += (dx - _anchor) * follow;
    }
  }

  // ---- shapes, built once

  static final Path _body = rrPath(-_w / 2, _chain, _w, _h, _r);
  static final Path _shadeCrescent = Path.combine(PathOperation.difference, _body, rrPath(-_w / 2 - 12, _chain - 2, _w, _h + 4, _r + 4));
  static final Path _shine = rrPath(-_w / 2 + 7, _chain + 24, 5, 84, 2.5);
  static final Path _bands = Path()
    ..addRRect(RRect.fromLTRBR(-_w / 2 - .5, _chain + 34, _w / 2 + .5, _chain + 46, const Radius.circular(3)))
    ..addRRect(RRect.fromLTRBR(-_w / 2 - .5, _chain + 104, _w / 2 + .5, _chain + 116, const Radius.circular(3)));
  static final Path _seam = Path()
    ..moveTo(-3, _chain + 54)
    ..lineTo(-3, _chain + 98);
  static final Path _cap = rrPath(-13, _chain - 5, 26, 11, 4);
  static final Path _links = () {
    final p = Path();
    var i = 0;
    for (var y = 6.0; y < _ring - 8; y += 12, i++) {
      p.addOval(Rect.fromCenter(center: Offset(0, y + 5), width: i.isEven ? 7 : 2.6, height: 13));
    }
    return p;
  }();
  static final Path _vee = Path()
    ..moveTo(0, _ring)
    ..lineTo(-17, _chain - 2)
    ..moveTo(0, _ring)
    ..lineTo(17, _chain - 2);
  static final Path _ringPath = Path()..addOval(Rect.fromCircle(center: const Offset(0, _ring), radius: 5.5));

  // ---- paints, shaders made on first use and kept
  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static Shader? _bodyShader, _tapeShader, _steelShader;

  static const Color _red = Color(0xFFD9364C), _redDark = Color(0xFF9B1F36), _tape = Color(0xFFF2E3C2), _tapeDark = Color(0xFFC9B58E);
  static const Color _steel = Color(0xFFCFC9DB), _steelDark = Color(0xFF8A8398), _white = Color(0xFFFFF6EE);

  static Shader _bodyGrad() => _bodyShader ??= Gradient.linear(const Offset(-_w / 2, 0), const Offset(_w / 2, 0), const [
    Color(0xFF6E1229),
    Color(0xFFD9475C),
    Color(0xFFC62C45),
    Color(0xFF8F1B36),
    Color(0xFF5A0E22),
  ], const [0, .22, .5, .82, 1]);
  static Shader _tapeGrad() => _tapeShader ??= Gradient.linear(const Offset(-_w / 2, 0), const Offset(_w / 2, 0), const [
    Color(0xFFB9A57F),
    Color(0xFFFFF1D2),
    Color(0xFFD9C7A0),
    Color(0xFF9E8B66),
  ], const [0, .3, .7, 1]);
  static Shader _steelGrad() => _steelShader ??= Gradient.linear(const Offset(-14, 0), const Offset(14, 0), const [
    Color(0xFF6C6580),
    Color(0xFFE4DEF0),
    Color(0xFF8A8398),
  ], const [0, .45, 1]);

  /// The soft ground shadow, under the bag's current place.
  void paintShadow(Canvas c, FightCamera cam, FightLook look) {
    final o = cam.toScreen(bodyX, 0);
    final double w = 1 - math.min(.35, _a.abs() * .5);
    c.save();
    c.translate(o.dx, o.dy + 2 * cam.scale);
    c.scale(cam.scale, cam.scale * .2);
    if (look == FightLook.painted) {
      drawGlow(c, Offset.zero, 48 * w, const Color(0x8C0A0414), additive: false);
    } else {
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 70 * w, height: 70 * w), _fill..shader = null..color = const Color(0xFF1A0F26));
    }
    c.restore();
  }

  /// The bag itself: chain, ring, body, tape, flash.
  void paint(Canvas c, FightCamera cam, FightLook look) {
    final o = cam.toScreen(_anchor, _top + _chain);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(cam.scale);
    c.rotate(_a);
    final flash = _flash > 0;
    switch (look) {
      case FightLook.cartoon:
        _toon(c, flash);
      case FightLook.painted:
        _paint(c, flash);
      case FightLook.pixel:
        _flat(c, flash);
    }
    c.restore();
  }

  void _toon(Canvas c, bool flash) {
    // Ink under the chain first, then the colour on top of it.
    _line
      ..shader = null
      ..color = kInk
      ..strokeWidth = 4.6;
    c.drawPath(_links, _line);
    c.drawPath(_vee, _line);
    _line.strokeWidth = 2.6;
    c.drawPath(_ringPath, _line);
    _line
      ..color = _steel
      ..strokeWidth = 1.7;
    c.drawPath(_links, _line);
    c.drawPath(_vee, _line);
    _line.strokeWidth = 2.6;
    c.drawPath(_ringPath, _line);
    _fill
      ..shader = null
      ..color = _steelDark;
    c.drawPath(_cap, _fill);
    _line
      ..color = kInk
      ..strokeWidth = 2.4;
    c.drawPath(_cap, _line);

    _fill.color = flash ? _white : _red;
    c.drawPath(_body, _fill);
    if (!flash) {
      _fill.color = _redDark;
      c.drawPath(_shadeCrescent, _fill);
      _fill.color = _tape;
      c.drawPath(_bands, _fill);
      _line
        ..color = kInk
        ..strokeWidth = 1.8;
      c.drawPath(_bands, _line);
      _line.strokeWidth = 1.3;
      c.drawPath(_seam, _line);
      _fill.color = const Color(0x66FFFFFF);
      c.drawPath(_shine, _fill);
    }
    _line
      ..color = kInk
      ..strokeWidth = 2.8;
    c.drawPath(_body, _line);
  }

  void _paint(Canvas c, bool flash) {
    _line
      ..shader = _steelGrad()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2;
    c.drawPath(_links, _line);
    c.drawPath(_vee, _line);
    c.drawPath(_ringPath, _line);
    _line.shader = null;
    _fill
      ..shader = _steelGrad()
      ..color = const Color(0xFFFFFFFF);
    c.drawPath(_cap, _fill);

    if (flash) {
      _fill
        ..shader = null
        ..color = _white;
      c.drawPath(_body, _fill);
    } else {
      _fill
        ..shader = _bodyGrad()
        ..color = const Color(0xFFFFFFFF);
      c.drawPath(_body, _fill);
      _fill.shader = _tapeGrad();
      c.drawPath(_bands, _fill);
      _fill
        ..shader = null
        ..color = const Color(0x2EFFFFFF);
      c.drawPath(_shine, _fill);
      _line
        ..color = const Color(0x4D1A0610)
        ..strokeWidth = 1;
      c.drawPath(_seam, _line);
    }
    _line
      ..color = const Color(0x661A0610)
      ..strokeWidth = 1.2;
    c.drawPath(_body, _line);
  }

  /// Pixel look: flat colour, drawn into the low-res pass; the shader adds the
  /// outline and snaps the palette.
  void _flat(Canvas c, bool flash) {
    _line
      ..shader = null
      ..color = _steel
      ..strokeWidth = 2.6;
    c.drawPath(_links, _line);
    c.drawPath(_vee, _line);
    c.drawPath(_ringPath, _line);
    _fill
      ..shader = null
      ..color = _steelDark;
    c.drawPath(_cap, _fill);
    _fill.color = flash ? _white : _red;
    c.drawPath(_body, _fill);
    if (!flash) {
      _fill.color = _redDark;
      c.drawPath(_shadeCrescent, _fill);
      _fill.color = _tape;
      c.drawPath(_bands, _fill);
      _fill.color = _tapeDark;
      c.drawRect(const Rect.fromLTWH(-_w / 2 + 1, _chain + 43, _w - 2, 3), _fill);
      c.drawRect(const Rect.fromLTWH(-_w / 2 + 1, _chain + 113, _w - 2, 3), _fill);
    }
  }
}
