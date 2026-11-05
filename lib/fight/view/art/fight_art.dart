// Art for the fighting game: stage, fighters (KAI rig), effects and HUD.
// Public API: FightLook, FightCamera, FightArt, FightHudText.
import 'dart:math' as math;
import 'dart:ui';

import '../../core/core.dart';
import 'art_common.dart';
import 'camera.dart';
import 'fx_art.dart';
import 'glow.dart';
import 'hud_art.dart';
import 'hud_text.dart';
import 'kai_poses.dart';
import 'kai_rig.dart';
import 'poser.dart';
import 'stage_art.dart';

export 'art_common.dart' show FightLook;
export 'camera.dart' show FightCamera;
export 'hud_text.dart' show FightHudText;

class FightArt {
  FightArt();

  final StageArt _stage = StageArt();
  final HudPainter _hud = HudPainter();
  final RigPainter _rig = RigPainter();
  final FxPainter _fx = FxPainter();
  final Paint _p = Paint()..isAntiAlias = true;
  Shader? _vig;
  Size _vigSize = Size.zero;

  /// Stage background. Static layers are cached Pictures (per look / size); the
  /// neon flicker, string lights and reflections are drawn per call. Parallax:
  /// far layers move less with the camera than near ones.
  void paintStage(Canvas c, Size size, FightCamera cam, FightLook look, int frame) {
    _stage.paint(c, size, cam, look, frame);
  }

  /// Shadows, traps, both fighters (facing from Fighter.face), projectiles, and
  /// the effects derived from FightState.events and fighter state. Hit-stop
  /// shake is derived from the fighters' `stop`. The super-flash darkening is
  /// drawn here (between the stage and the fighters).
  void paintActors(Canvas c, Size size, FightCamera cam, FightState s, FightLook look) {
    c.save();
    if (s.phase == Phase.fight && s.superFlash <= 0) {
      final stop = math.max(s.p[0].stop, s.p[1].stop);
      if (stop > 0) {
        final amp = math.min(stop, 12) * .5 * cam.scale;
        c.translate((hash01(s.frame, 1) * 2 - 1) * amp, (hash01(s.frame, 2) * 2 - 1) * amp * .7);
      }
    }
    for (final t in s.traps) {
      _trap(c, cam, s, t, look);
    }
    for (var i = 0; i < 2; i++) {
      _shadow(c, cam, s.p[i], look);
    }
    if (s.superFlash > 0 && s.superBy >= 0) _superDarken(c, size, cam, s, look);
    for (var i = 0; i < 2; i++) {
      _ghosts(c, cam, s, i, look);
    }
    // Fighter that is attacking draws in front.
    int rank(int i) => s.p[i].state == St.move ? 2 : (s.p[i].state == St.grabbed ? 0 : 1);
    final order = rank(0) > rank(1) ? [1, 0] : [0, 1];
    for (final i in order) {
      _fighter(c, cam, s, i, look);
    }
    for (var i = 0; i < 2; i++) {
      _smear(c, cam, s, i, look);
    }
    for (var i = 0; i < 2; i++) {
      _charge(c, cam, s, i, look);
    }
    for (final p in s.projectiles) {
      _projectile(c, cam, s, p, look);
    }
    for (final e in s.events) {
      _event(c, cam, s, e, look);
    }
    c.restore();
    if (look == FightLook.painted) _vignette(c, size);
  }

  /// HUD in screen space. [names] are display names; every word comes from [text].
  void paintHud(Canvas c, Size size, FightState s, FightLook look, List<String> names, {FightHudText? text}) {
    _hud.paint(c, size, s, look, names, text ?? FightHudText.english);
  }

  // ------------------------------------------------------------------ pieces

  KPalette _palette(FightState s, int i) {
    final id = s.chars[i].id;
    final alt = i == 1 && (id == 0 || s.chars[0].id == s.chars[1].id);
    return KPalette.forChar(id, alt);
  }

  void _enter(Canvas c, FightCamera cam, double wx, double wy, int face) {
    final o = cam.toScreen(wx, wy);
    c.translate(o.dx, o.dy);
    c.scale(cam.scale * kRig * face, cam.scale * kRig);
  }

  void _fighter(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    final pose = poseFor(s, i);
    c.save();
    _enter(c, cam, f.x / unitsPerPx, f.y / unitsPerPx, f.face);
    _rig.fighter(c, pose, _palette(s, i), look);
    c.restore();
  }

  void _shadow(Canvas c, FightCamera cam, Fighter f, FightLook look) {
    final w = math.max(.4, 1 - f.y / unitsPerPx / 220) * 1.1;
    final o = cam.toScreen(f.x / unitsPerPx, 0);
    c.save();
    c.translate(o.dx, o.dy + 2 * cam.scale);
    c.scale(cam.scale * kFx * 1.25, cam.scale * kFx * 1.25 * .17);
    if (look == FightLook.painted) {
      drawGlow(c, Offset.zero, 46 * w, const Color(0x8C0A0414), additive: false);
    } else {
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 80 * w, height: 80 * w), _p..shader = null..color = const Color(0xFF1a0f26));
    }
    c.restore();
  }

  void _trap(Canvas c, FightCamera cam, FightState s, Trap t, FightLook look) {
    final def = s.chars[t.owner].traps[t.trap];
    final o = cam.toScreen(t.x / unitsPerPx, 0);
    final armed = t.arm <= 0;
    final w = def.w / unitsPerPx * cam.scale;
    c.save();
    c.translate(o.dx, o.dy);
    final col = armed ? const Color(0xFFffd23a) : const Color(0x99FFD23A);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: w * .22), _p..shader = null..color = col);
    if (look == FightLook.cartoon) {
      c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * .22),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kInk);
    }
    if (look == FightLook.painted && armed) drawGlow(c, Offset.zero, w * .7, const Color(0x66FFD23A));
    c.restore();
  }

  void _superDarken(Canvas c, Size size, FightCamera cam, FightState s, FightLook look) {
    final f = s.superFlash;
    final a = math.min(1.0, (superFlashFrames - f) / 5) * math.min(1.0, f / 8) * .72;
    c.drawRect(Offset.zero & size, _p..shader = null..color = Color.fromRGBO(8, 2, 20, a));
    final cas = s.p[s.superBy];
    final o = cam.toScreen(cas.x / unitsPerPx, cas.y / unitsPerPx + 90);
    drawGlow(c, o, 170 * cam.scale, Color.fromRGBO(120, 220, 255, .55 * a));
    final r = SRand(s.frame ~/ 2 + 3);
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Color.fromRGBO(210, 245, 255, .55 * a);
    final diag = size.longestSide;
    for (var i = 0; i < 26; i++) {
      final ang = r.next() * math.pi * 2, d0 = (140 + r.next() * 120) * cam.scale, d1 = diag * (.5 + r.next() * .5);
      _p.strokeWidth = 1 + r.next() * 3;
      c.drawLine(o + Offset(math.cos(ang), math.sin(ang)) * d0, o + Offset(math.cos(ang), math.sin(ang)) * d1, _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeWidth = 1;
  }

  void _ghosts(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    int lo, hi;
    switch (f.state) {
      case St.roll:
        lo = 4;
        hi = 24;
        break;
      case St.dash:
      case St.backdash:
        lo = 1;
        hi = 99;
        break;
      case St.move:
        if (f.moveId < 0) return;
        final n = s.chars[i].moves[f.moveId].name;
        if (n != 'cometKnee' && n != 'slideStep' && n != 'hundredStorm') return;
        lo = 3;
        hi = 99;
        break;
      default:
        return;
    }
    for (var k = 1; k <= 5; k++) {
      final sf2 = f.sf - 3 * k;
      if (sf2 < lo) break;
      if (sf2 > hi) continue;
      final a = 1 - 3 * k / 16;
      if (look != FightLook.painted && a < .5) continue;
      final col = look == FightLook.painted ? Color.fromRGBO(110, 220, 255, .35 * a) : const Color(0xFF53d6f0);
      final pose = poseAtSf(s, i, sf2);
      c.save();
      _enter(c, cam, f.x / unitsPerPx - f.vx / unitsPerPx * 3 * k, f.y / unitsPerPx - f.vy / unitsPerPx * 3 * k * .5, f.face);
      _rig.fighter(c, pose, _palette(s, i), look, silhouette: col);
      c.restore();
    }
  }

  void _smear(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    if (f.state != St.move || f.moveId < 0) return;
    final def = s.chars[i];
    final m = def.moves[f.moveId];
    final anim = animFor(m, def);
    final jt = anim.smear;
    if (jt == null || anim.storm) return;
    final sf = f.sf.toDouble();
    final lo = math.max(anim.smearA.toDouble(), sf - 3.5), hi = math.min(sf, anim.smearB.toDouble());
    if (hi - lo < .5) return;
    final fwdVx = f.vx / unitsPerPx * f.face / kRig;
    final pts = <Offset>[];
    for (var t = lo; t <= hi + .001; t += .25) {
      final o = jointRig(evalKeys(anim.keys, t), jt);
      pts.add(Offset(o.dx - fwdVx * (sf - t), o.dy));
    }
    c.save();
    _enter(c, cam, f.x / unitsPerPx, f.y / unitsPerPx, f.face);
    _fx.smear(c, look, pts, 1 / csScale);
    c.restore();
  }

  void _charge(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    if (f.state != St.move || f.moveId < 0) return;
    final m = s.chars[i].moves[f.moveId];
    if (m.name != 'surgePalm' || m.projectiles.isEmpty) return;
    final sp = m.projectiles.first.frame;
    final lo = (sp * .3).round();
    if (f.sf < lo || f.sf >= sp) return;
    final hand = jointRig(poseFor(s, i), Jt.fHa);
    final wx = f.x / unitsPerPx + f.face * hand.dx * kRig, wy = f.y / unitsPerPx - hand.dy * kRig;
    final o = cam.toScreen(wx, wy);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(cam.scale * kFx);
    _fx.charge(c, look, (f.sf - lo) / math.max(1, sp - lo), s.frame);
    c.restore();
  }

  void _projectile(Canvas c, FightCamera cam, FightState s, Projectile p, FightLook look) {
    final def = s.chars[p.owner].projectiles[p.proj];
    final o = cam.toScreen(p.x / unitsPerPx, p.y / unitsPerPx);
    final sc = cam.scale * (def.w / unitsPerPx) / 31.0;
    final dir = p.vx < 0 ? -1.0 : 1.0;
    c.save();
    c.translate(o.dx, o.dy);
    if (look == FightLook.painted) {
      // floor light under the projectile
      final g = cam.toScreen(p.x / unitsPerPx, 0);
      c.save();
      c.translate(g.dx - o.dx, g.dy - o.dy + 4);
      c.scale(1, .17);
      drawGlow(c, Offset.zero, 60 * cam.scale * kFx * 1.4, const Color(0x5950BEFF));
      c.restore();
    }
    c.scale(sc * dir, sc);
    _fx.projectile(c, look, def.life - p.life);
    c.restore();
  }

  void _event(Canvas c, FightCamera cam, FightState s, FightEvent e, FightLook look) {
    final age = s.frame - e.frame;
    if (age < 0 || age > 26) return;
    final o = cam.toScreen(e.x / unitsPerPx, e.y / unitsPerPx);
    final seed = e.frame * 31 + e.x ~/ 100 + e.kind * 7;
    final k = cam.scale * kFx * 1.15;
    void at(Offset pt, double scale, void Function() f) {
      c.save();
      c.translate(pt.dx, pt.dy);
      c.scale(scale);
      f();
      c.restore();
    }

    final ground = cam.toScreen(e.x / unitsPerPx, 0);
    switch (e.kind) {
      case Ev.hit:
        final big = e.value >= 60;
        at(o, k, () {
          _fx.spark(c, look, age, seed, big: big);
          if (big) _fx.ring(c, look, age);
        });
        break;
      case Ev.counterHit:
      case Ev.throwHit:
        at(o, k * 1.15, () {
          _fx.spark(c, look, age, seed, big: true);
          _fx.ring(c, look, age, size: 1.2);
        });
        break;
      case Ev.block:
        at(o, k, () => _fx.spark(c, look, age, seed, kind: 2));
        break;
      case Ev.perfectBlock:
        at(o, k * 1.2, () {
          _fx.spark(c, look, age, seed, big: true, kind: 2);
          _fx.ring(c, look, age, tint: const Color(0xFFffd23a));
        });
        break;
      case Ev.ko:
        at(o, k * 1.5, () {
          _fx.spark(c, look, age, seed, big: true);
          _fx.ring(c, look, age, size: 1.6);
        });
        break;
      case Ev.projectileSpawn:
        at(o, k * 1.2, () => _fx.flash(c, look, age, seed));
        break;
      case Ev.clash:
        at(o, k, () {
          _fx.spark(c, look, age, seed, big: true, kind: 3);
          _fx.ring(c, look, age);
        });
        break;
      case Ev.armor:
        at(o, k, () => _fx.spark(c, look, age, seed, kind: 3));
        break;
      case Ev.throwTech:
      case Ev.counterTrigger:
      case Ev.trap:
        at(o, k, () => _fx.ring(c, look, age, tint: const Color(0xFF8fd8ff)));
        break;
      case Ev.wallBounce:
        at(o, k, () {
          _fx.ring(c, look, age);
          _fx.dust(c, look, age, seed);
        });
        break;
      case Ev.land:
      case Ev.groundBounce:
      case Ev.roll:
      case Ev.dash:
        at(ground, k, () => _fx.dust(c, look, age, seed));
        break;
    }
    // Burst where a projectile died: the engine records it as a hit event at the contact point.
  }

  void _vignette(Canvas c, Size size) {
    if (_vig == null || _vigSize != size) {
      _vigSize = size;
      _vig = Gradient.radial(size.center(Offset.zero), size.longestSide * .62, const [Color(0x00000000), Color(0x8C0A0014)], const [.45, 1]);
    }
    c.drawRect(Offset.zero & size, _p..shader = _vig);
    _p.shader = null;
  }
}
