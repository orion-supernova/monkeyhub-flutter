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
import 'roster_fx.dart';
import 'roster_poses.dart';
import 'stage_art.dart';
import 'cast/registry.dart';

export 'art_common.dart' show FightLook;
export 'camera.dart' show FightCamera;
export 'hud_text.dart' show FightHudText;

class FightArt {
  FightArt();

  final StageArt _stage = StageArt();
  final HudPainter _hud = HudPainter();
  final RigPainter _rig = RigPainter();
  final FxPainter _fx = FxPainter();
  final RosterFx _rfx = RosterFx();
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
      _rosterBack(c, cam, s, i, look);
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
      _rosterFront(c, cam, s, i, look);
    }
    for (var i = 0; i < 2; i++) {
      castArt[s.chars[i].id]?.paintMoveFx(c, size, cam, s, i, look);
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

  bool _alt(FightState s, int i) {
    final id = s.chars[i].id;
    return i == 1 && (id == 0 || s.chars[0].id == s.chars[1].id);
  }

  void _enter(Canvas c, FightCamera cam, double wx, double wy, int face, [double rig = kRig]) {
    final o = cam.toScreen(wx, wy);
    c.translate(o.dx, o.dy);
    c.scale(cam.scale * rig * face, cam.scale * rig);
  }

  void _fighter(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    final pose = poseFor(s, i);
    c.save();
    final id = s.chars[i].id;
    _enter(c, cam, f.x / unitsPerPx, f.y / unitsPerPx, f.face, rigScale(id));
    _rig.fighter(c, pose, _palette(s, i), look, charId: id, alt: _alt(s, i), frame: s.frame);
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
    final ownerId = s.chars[t.owner].id;
    final cast = castArt[ownerId];
    if (cast != null) {
      c.save();
      c.translate(o.dx, o.dy);
      c.scale(cam.scale * (def.w / unitsPerPx) / 31.0);
      final drawn = cast.paintTrap(c, look, def, def.life - t.life, armed);
      c.restore();
      if (drawn) return;
    }
    if (ownerId == 1 || ownerId == 3) {
      final age = def.life - t.life;
      c.save();
      c.translate(o.dx, o.dy);
      if (ownerId == 1) {
        c.scale(cam.scale * kFx * 1.6);
        _rfx.peel(c, look, age, armed: armed);
      } else {
        c.scale(def.w / unitsPerPx / 2 / 72 * cam.scale);
        _rfx.pool(c, look, age, def.life, s.frame, t.x ~/ 100 + t.owner);
      }
      c.restore();
      return;
    }
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
        if (n != 'cometKnee' && n != 'slideStep' && n != 'hundredStorm' && n != 'stampede') return;
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
      final id = s.chars[i].id;
      _enter(c, cam, f.x / unitsPerPx - f.vx / unitsPerPx * 3 * k, f.y / unitsPerPx - f.vy / unitsPerPx * 3 * k * .5, f.face,
          rigScale(id));
      _rig.fighter(c, pose, _palette(s, i), look, silhouette: col, charId: id, alt: _alt(s, i), frame: s.frame);
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
    final dims = dimsFor(def.id);
    final fwdVx = f.vx / unitsPerPx * f.face / rigScale(def.id);
    final pts = <Offset>[];
    for (var t = lo; t <= hi + .001; t += .25) {
      final o = jointRig(evalKeys(anim.keys, t), jt, dims);
      pts.add(Offset(o.dx - fwdVx * (sf - t), o.dy));
    }
    c.save();
    _enter(c, cam, f.x / unitsPerPx, f.y / unitsPerPx, f.face, rigScale(def.id));
    _fx.smear(c, look, pts, 1 / dims.cs);
    c.restore();
  }

  void _charge(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    if (f.state != St.move || f.moveId < 0) return;
    final m = s.chars[i].moves[f.moveId];
    final id = s.chars[i].id;
    if ((m.name != 'surgePalm' && m.name != 'moonShard') || m.projectiles.isEmpty) return;
    final sp = m.projectiles.first.frame;
    final lo = (sp * (id == 3 ? .4 : .3)).round();
    if (f.sf < lo || f.sf >= sp) return;
    final j = jointRig(poseFor(s, i), id == 3 ? Jt.mid : Jt.fHa, dimsFor(id));
    final rs = rigScale(id);
    final wx = f.x / unitsPerPx + f.face * j.dx * rs, wy = f.y / unitsPerPx - j.dy * rs;
    final o = cam.toScreen(wx, wy);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(cam.scale * kFx);
    if (id == 3) {
      _rfx.moonCharge(c, look, (f.sf - lo) / math.max(1, sp - lo), s.frame);
    } else {
      _fx.charge(c, look, (f.sf - lo) / math.max(1, sp - lo), s.frame);
    }
    c.restore();
  }

  void _projectile(Canvas c, FightCamera cam, FightState s, Projectile p, FightLook look) {
    final def = s.chars[p.owner].projectiles[p.proj];
    final o = cam.toScreen(p.x / unitsPerPx, p.y / unitsPerPx);
    final cast = castArt[s.chars[p.owner].id];
    if (cast != null) {
      c.save();
      c.translate(o.dx, o.dy);
      final k = cam.scale * (def.w / unitsPerPx) / 31.0;
      c.scale(p.vx < 0 ? -k : k, k);
      final drawn = cast.paintProjectile(c, look, def, def.life - p.life);
      c.restore();
      if (drawn) return;
    }
    final nyx = s.chars[p.owner].id == 3;
    final sc = cam.scale * (def.w / unitsPerPx) / (nyx ? 42.0 : 31.0);
    final dir = p.vx < 0 ? -1.0 : 1.0;
    c.save();
    c.translate(o.dx, o.dy);
    if (look == FightLook.painted) {
      // floor light under the projectile
      final g = cam.toScreen(p.x / unitsPerPx, 0);
      c.save();
      c.translate(g.dx - o.dx, g.dy - o.dy + 4);
      c.scale(1, .17);
      drawGlow(c, Offset.zero, 60 * cam.scale * kFx * 1.4, nyx ? const Color(0x59B07CFF) : const Color(0x5950BEFF));
      c.restore();
    }
    c.scale(sc * dir, sc);
    if (nyx) {
      _rfx.moonShard(c, look, def.life - p.life);
    } else {
      _fx.projectile(c, look, def.life - p.life);
    }
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
        if (s.chars[e.player].id == 3) {
          at(o, k * .9, () => _rfx.moonBurst(c, look, age, seed, size: .7));
        } else {
          at(o, k * 1.2, () => _fx.flash(c, look, age, seed));
        }
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

  /// Roster effects that sit behind the fighters: NYX's dark sun.
  void _rosterBack(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    final def = s.chars[i];
    if (def.id != 3 || f.state != St.move || f.moveId < 0) return;
    final m = def.moves[f.moveId];
    if (m.name != 'totalEclipse') return;
    final sf = f.sf;
    final grow = clamp01(sf / math.max(1, m.startup + 4));
    final fade = sf > m.startup + m.active ? clamp01(1 - (sf - m.startup - m.active) / math.max(1, m.recovery * .6)) : 1.0;
    if (fade <= 0) return;
    final o = cam.toScreen(f.x / unitsPerPx + f.face * 40, f.y / unitsPerPx + 250);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(cam.scale * kFx * 1.5);
    _rfx.darkSun(c, look, grow * fade, math.sin(s.frame * .5) * .5 + .5, s.frame);
    c.restore();
    // One moon-blade per hit window, crossing the foe.
    final foe = s.p[1 - i];
    final ws = m.windows;
    for (var k = 0; k < ws.length; k++) {
      final age = sf - ws[k].start;
      if (age < 0 || age > 9) continue;
      final r = SRand(k * 7 + 5);
      final fo = cam.toScreen(foe.x / unitsPerPx + (r.next() - .5) * 40, foe.y / unitsPerPx + 70 + (r.next() - .5) * 50);
      c.save();
      c.translate(fo.dx, fo.dy);
      c.scale(cam.scale * kFx * 1.5);
      _rfx.slash(c, look, age, (k.isEven ? -.7 : .7) + (r.next() - .5) * .5, 62);
      c.restore();
    }
  }

  /// Roster effects in front of the fighters: TANK's quake, NYX's puff / halo.
  void _rosterFront(Canvas c, FightCamera cam, FightState s, int i, FightLook look) {
    final f = s.p[i];
    final def = s.chars[i];
    if (def.id < 2 || f.state != St.move || f.moveId < 0) return;
    final m = def.moves[f.moveId];
    final sf = f.sf;
    final seed = f.x ~/ 100 + s.frame ~/ 40;
    if (def.id == 2) {
      final qf = tankQuakeFrame(m);
      if (qf < 0 || sf < qf) return;
      final big = m.name == 'avalancheSlam';
      double reach = 0;
      for (final w in m.windows) {
        reach = math.max(reach, (w.box.x + w.box.w) / unitsPerPx);
      }
      if (reach <= 0) reach = 260;
      final o = cam.toScreen(f.x / unitsPerPx + f.face * (big ? 70 : 0), 0);
      c.save();
      c.translate(o.dx, o.dy);
      c.scale(cam.scale * f.face * 1.15, cam.scale * 1.15);
      _rfx.quake(c, look, sf - qf, seed, fwd: big ? 170 : math.max(120, reach / 1.15 - 20), back: big ? 150 : 60);
      c.restore();
      return;
    }
    if (def.id != 3) return;
    switch (m.name) {
      case 'phaseStep':
      case 'eclipseStrike':
        final tp = m.steps.where((e) => e.teleport != 0).map((e) => e.frame).fold<int>(m.name == 'phaseStep' ? m.startup : 0, (p, e) => e);
        // Smoke gathers as she fades, then bursts where she lands.
        final age = sf < tp ? sf - (tp - 6) : sf - tp + 6;
        if (age < 0 || age > 22) return;
        final o = cam.toScreen(f.x / unitsPerPx, f.y / unitsPerPx + 70);
        c.save();
        c.translate(o.dx, o.dy);
        c.scale(cam.scale * kFx * 1.3);
        _rfx.puff(c, look, age, seed + (sf < tp ? 0 : 5));
        c.restore();
        break;
      case 'eclipse':
        final lo = m.counterStart, hi = m.counterEnd;
        if (sf < lo || sf > hi + 4) return;
        final j = jointRig(poseFor(s, i), Jt.mid, nyxDims);
        final rs = rigScale(3);
        final o = cam.toScreen(f.x / unitsPerPx + f.face * (j.dx * rs + 20 * kFx), f.y / unitsPerPx - (j.dy * rs) + 4 * kFx * -1);
        final k = clamp01((sf - lo) / 5), out = sf > hi ? 1 - (sf - hi) / 4 : 1.0;
        c.save();
        c.translate(o.dx, o.dy);
        c.scale(cam.scale * kFx * 1.15);
        _rfx.eclipseHalo(c, look, k, out, s.frame);
        c.restore();
        break;
    }
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
