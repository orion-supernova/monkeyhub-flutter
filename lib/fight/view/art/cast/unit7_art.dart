// UNIT-7 (it): a chunky retro-future robot. Cream and teal plating with panel
// lines and rivets, a dark visor with one scanning cyan eye, boxy fists,
// shoulder rocket pods and back thrusters. Channels: `sa` = charge (eye, chest
// core and seams glow; self-destruct heat), `sx` = back thruster power.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim;
import '../roster_rig.dart' show ellP;
import 'cast_art.dart';
import 'legends_kit.dart';

class _U7 {
  final Color cream, creamD, teal, tealD, dark, steel, glow, glowD, hot, rivet;
  const _U7(this.cream, this.creamD, this.teal, this.tealD, this.dark, this.steel, this.glow, this.glowD, this.hot, this.rivet);
  static final base = _U7(hex(0xf1e6cc), hex(0xbfa97c), hex(0x2fb3ad), hex(0x1a7580), hex(0x232d3a), hex(0x6b7a8a), hex(0x7ff7ff),
      hex(0x14b8d6), hex(0xff7a3a), hex(0x9a8a66));
  /// Mirror match: orange plating on charcoal, lime eye.
  static final alt = _U7(hex(0xf08a3c), hex(0xb25a22), hex(0x434e5e), hex(0x27303c), hex(0x12161d), hex(0x8a96a6), hex(0xb6ff6a),
      hex(0x5bc21f), hex(0xff3f6e), hex(0x7a4a22));
}

final KPose _idle = KPose.from(pIdle,
    lean: .1, head: -.02, fu: .65, ff: 2.1, bu: .45, bf: 2.35, ft: .42, fs: .0, bt: -.22, bs: -.3);

// ---- torso-local paths (origin pelvis, +x forward, up negative)
final Path _chest = roundPoly(const [
  Offset(-19, -26), Offset(-21, -46), Offset(-13, -55), Offset(13, -55), Offset(23, -47), Offset(21, -27), Offset(13, -20), Offset(-13, -20),
], 5);
final Path _chestLow = roundPoly(const [Offset(-15, -23), Offset(15, -23), Offset(13, -32), Offset(-13, -32)], 3);
final Path _pelvis = roundPoly(const [Offset(-17, -12), Offset(-18, 3), Offset(18, 3), Offset(17, -12)], 4);
final Path _abdomen = rrPath(-12, -25, 24, 12, 3);
final Path _belt = rrPath(-18, -9, 36, 4.5, 1.5);
final Path _pack = roundPoly(const [Offset(-34, -53), Offset(-17, -55), Offset(-16, -22), Offset(-34, -27)], 4);
final Path _nozA = roundPoly(const [Offset(-33, -49), Offset(-42, -53), Offset(-42, -41), Offset(-33, -42)], 1.5);
final Path _nozB = roundPoly(const [Offset(-33, -36), Offset(-42, -40), Offset(-42, -28), Offset(-33, -29)], 1.5);
const Offset _nozAp = Offset(-42, -47), _nozBp = Offset(-42, -34);
const Offset _core = Offset(9, -37);
final Path _seven = Path()
  ..moveTo(-14, -47)
  ..lineTo(-5, -47)
  ..lineTo(-9.5, -36);

// ---- head-local paths
final Path _helmet = roundPoly(const [
  Offset(-19, -6), Offset(-16, -19), Offset(-4, -24), Offset(12, -22), Offset(21, -12), Offset(22, 8), Offset(18, 15), Offset(-14, 15), Offset(-19, 8),
], 5);
final Path _crest = roundPoly(const [Offset(-17, -17), Offset(8, -24), Offset(12, -19), Offset(-17, -11)], 2);
final Path _visor = roundPoly(const [Offset(1, -9), Offset(22, -9), Offset(23, 2), Offset(1, 3)], 3);
final Path _brow = roundPoly(const [Offset(-1, -14), Offset(23, -14), Offset(23, -9), Offset(-1, -9)], 1.5);
final Path _jaw = roundPoly(const [Offset(3, 5), Offset(22, 4.5), Offset(20, 14), Offset(2, 14)], 3);
final Path _boot = roundPoly(const [Offset(-11, -13), Offset(7, -13), Offset(13, -5), Offset(26, -3), Offset(28, 6), Offset(-12, 6)], 3);
final Path _podP = roundPoly(const [Offset(-5, -17), Offset(20, -17), Offset(21, -3), Offset(-5, -3)], 3);

class Unit7Art extends CastArt {
  const Unit7Art();

  @override
  int get id => 16;

  @override
  RigDims get dims => const RigDims(16, 56, 30, 28, 34, 32, 1.32, 14, 9, 17, 3);

  @override
  KPose get idle => _idle;

  @override
  double get portraitWidth => 130;

  @override
  KPalette get palette => KPalette(
      skin: hex(0xf1e6cc), hair: hex(0x1a7580), tip: hex(0x7ff7ff), vest: hex(0x2fb3ad), tank: hex(0x232d3a),
      pants: hex(0xbfa97c), pad: hex(0x2fb3ad), wrap: hex(0xf1e6cc), shoe: hex(0xf1e6cc), sole: hex(0x232d3a), accent: hex(0x7ff7ff));

  @override
  KPalette get altPalette => KPalette(
      skin: hex(0xf08a3c), hair: hex(0x27303c), tip: hex(0xb6ff6a), vest: hex(0x434e5e), tank: hex(0x12161d),
      pants: hex(0xb25a22), pad: hex(0x434e5e), wrap: hex(0xf08a3c), shoe: hex(0xf08a3c), sole: hex(0x12161d), accent: hex(0xb6ff6a));

  @override
  (KPose, KPose, KPose)? readyPoses() {
    const q = Pq.new;
    final p = q(_idle);
    return (
      p(fu: 2.7, ff: 3.0, bu: 2.5, bf: 2.9, lean: -.1, rx: -4, sa: .5),
      p(fu: 1.4, ff: 1.0, bu: 1.3, bf: .95, lean: .55, rx: 12, sa: 1),
      p(fu: 1.1, ff: 2.6, bu: .95, bf: 2.8, baf: 1, lean: .1),
    );
  }

  // ================================================================ paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final u = alt ? _U7.alt : _U7.base;
    final c = rp.c;
    final sil = rp.sil != null;
    final heat = p.sa.clamp(0.0, 1.0);
    c.save();
    c.rotate(p.lean);
    _packAndThrust(rp, p, u, frame);
    c.restore();
    if (p.baf < .5) _arm(rp, j, true, p, u, heat);
    if (p.blf < .5) _leg(rp, j, true, p, u);
    _torso(rp, j, p, u, frame, heat);
    _pod(rp, j, true, u);
    _pod(rp, j, false, u);
    _leg(rp, j, false, p, u);
    if (p.blf >= .5) _leg(rp, j, true, p, u);
    _head(rp, j, p, u, frame, heat);
    if (p.baf >= .5) _arm(rp, j, true, p, u, heat);
    _arm(rp, j, false, p, u, heat);
    if (!sil && rp.paint && heat > .05) {
      drawGlow(c, Offset(j.c.dx + 6, j.c.dy - 8), 40 + 50 * heat, withA(u.hot, .5 * heat));
    }
  }

  void _packAndThrust(RigPainter rp, KPose p, _U7 u, double f) {
    final c = rp.c;
    final sil = rp.sil != null;
    // Pilot flames at the nozzles; `sx` is the thruster power.
    if (!sil) {
      final pw = p.sx.clamp(0.0, 1.0);
      for (final n in const [_nozAp, _nozBp]) {
        c.save();
        c.translate(n.dx, n.dy);
        c.rotate(math.pi);
        drawFlame(c, rp.look, 4 + math.sin(f * .8 + n.dy) * 1.2 + pw * 26, 2.6 + pw * 2.4, f.toInt(), n.dy.toInt(),
            outer: u.hot, mid: lt(u.hot, .35), core: u.glow, ink: 1.4);
        c.restore();
      }
    }
    rp.fill(_pack, u.steel, const Rect.fromLTRB(-35, -56, -15, -21), shade: u.dark, lw: 2.2);
    rp.fill(_nozA, u.dark, const Rect.fromLTRB(-43, -54, -32, -40), noHT: true, lw: 1.8);
    rp.fill(_nozB, u.dark, const Rect.fromLTRB(-43, -41, -32, -27), noHT: true, lw: 1.8);
    if (!sil) {
      rp.detail((pa) => pa
        ..moveTo(-27, -52)
        ..lineTo(-27, -26)
        ..moveTo(-34, -41)
        ..lineTo(-17, -41), w: 1.1);
    }
  }

  void _torso(RigPainter rp, Joints j, KPose p, _U7 u, double f, double heat) {
    final c = rp.c;
    final sil = rp.sil != null;
    c.save();
    c.rotate(p.lean);
    rp.fill(_pelvis, u.teal, const Rect.fromLTRB(-18, -12, 18, 3), shade: u.tealD, lw: 2.2);
    rp.fill(_abdomen, u.dark, const Rect.fromLTRB(-12, -25, 12, -13), noHT: true, lw: 2);
    rp.fill(_belt, u.cream, const Rect.fromLTRB(-18, -9, 18, -4), noHT: true, lw: 1.6, shade: u.creamD);
    rp.fill(_chest, u.cream, const Rect.fromLTRB(-21, -55, 23, -20), shade: u.creamD);
    rp.fill(_chestLow, u.teal, const Rect.fromLTRB(-15, -32, 15, -23), shade: u.tealD, lw: 1.8);
    if (!sil) {
      // Panel seams, a stencilled 7, a vent and rivets.
      rp.detail((pa) => pa
        ..moveTo(0, -55)
        ..lineTo(0, -33)
        ..moveTo(-20, -40)
        ..lineTo(-6, -40)
        ..moveTo(-12, -21)
        ..lineTo(-12, -14)
        ..moveTo(12, -21)
        ..lineTo(12, -14)
        ..moveTo(-5, -14)
        ..lineTo(5, -14), w: 1.2);
      rp.detail((pa) => pa.addPath(_seven, Offset.zero), w: 2.6, col: u.teal);
      rp.detail((pa) => pa
        ..moveTo(-16, -30)
        ..lineTo(-9, -30)
        ..moveTo(-16, -27)
        ..lineTo(-9, -27), w: 1.4, col: u.tealD);
      for (final r in const [Offset(-17, -50), Offset(17, -51), Offset(-17, -28), Offset(18, -28), Offset(-10, 0), Offset(10, 0)]) {
        dotC(c, r, 1.35, u.rivet);
      }
      // The chest core: a dark window with a cyan heart.
      final pulse = .5 + .5 * math.sin(f * .12);
      final cg = (.55 + .35 * pulse + heat).clamp(0.0, 1.4);
      rp.fill(rrPath(_core.dx - 7, _core.dy - 7, 14, 14, 3), u.dark, Rect.fromCenter(center: _core, width: 14, height: 14), noHT: true, lw: 1.8);
      if (rp.paint) drawGlow(c, _core, 16 + 12 * heat, withA(heat > .3 ? u.hot : u.glow, .75 * cg.clamp(0.0, 1.0)));
      dotC(c, _core, 4.2 + heat * 1.5, heat > .3 ? lt(u.hot, .2) : u.glow);
      dotC(c, _core, 2, const Color(0xFFFFFFFF));
      if (heat > .02) {
        // Seams overheating: hot lines through the plating.
        final hl = withA(u.hot, (heat * 1.2).clamp(0.0, 1.0));
        final hp = Path()
          ..moveTo(0, -55)
          ..lineTo(0, -33)
          ..moveTo(-20, -40)
          ..lineTo(-6, -40)
          ..moveTo(-18, -9)
          ..lineTo(18, -9)
          ..moveTo(-12, -21)
          ..lineTo(-12, -14)
          ..moveTo(12, -21)
          ..lineTo(12, -14);
        if (rp.paint) {
          plusStroke(c, hp, 2.6, hl);
        } else {
          strokeC(c, hp, 2.2, hl);
        }
        fillC(c, _chest, withA(u.hot, heat * .22));
      }
    }
    c.restore();
  }

  void _head(RigPainter rp, Joints j, KPose p, _U7 u, double f, double heat) {
    final c = rp.c;
    final sil = rp.sil != null;
    final neckTop = Offset(j.head.dx - 2, j.head.dy + 12);
    rp.limb(j.neck, neckTop, 8, 7.4, u.dark, noHT: true, lw: 2);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.3, 1.3);
    // Antenna with a blinking lamp.
    if (!sil) {
      lineC(c, const Offset(-9, -21), const Offset(-13, -35), 1.6, rp.cel ? kInk : u.steel);
      lineC(c, const Offset(-9, -21), const Offset(-13, -35), .8, u.steel);
      final on = (f ~/ 28).isEven;
      if (on && rp.paint) drawGlow(c, const Offset(-13, -36), 7, withA(u.hot, .8));
      dotC(c, const Offset(-13, -36), 2.6, on ? u.hot : u.creamD);
      if (rp.cel) ringC(c, const Offset(-13, -36), 2.6, 1, kInk);
    }
    rp.fill(_helmet, u.cream, const Rect.fromLTRB(-20, -25, 23, 16), shade: u.creamD);
    rp.fill(_crest, u.teal, const Rect.fromLTRB(-17, -24, 12, -11), shade: u.tealD, lw: 1.6, noHT: true);
    if (!sil) {
      rp.fill(ellP(-7, 2, 7, 7), u.teal, const Rect.fromLTRB(-14, -5, 0, 9), lw: 1.8, shade: u.tealD, noHT: true);
      dotC(c, const Offset(-7, 2), 3.2, u.dark);
      dotC(c, const Offset(-7, 2), 1.2, u.steel);
    }
    rp.fill(_jaw, u.teal, const Rect.fromLTRB(2, 4, 22, 14), shade: u.tealD, lw: 1.8, noHT: true);
    rp.fill(_visor, u.dark, const Rect.fromLTRB(1, -9, 23, 3), noHT: true, lw: 1.8);
    rp.fill(_brow, u.teal, const Rect.fromLTRB(-1, -14, 23, -9), shade: u.tealD, lw: 1.6, noHT: true);
    if (!sil) {
      rp.detail((pa) => pa
        ..moveTo(7, 7)
        ..lineTo(7, 13)
        ..moveTo(12, 7)
        ..lineTo(12, 13)
        ..moveTo(17, 7)
        ..lineTo(17, 13), w: 1.1);
      // The eye scans left-right along the visor; charging locks it forward.
      final scan = .5 + .5 * math.sin(f * .045);
      final ex = lerpD(lerpD(4.5, 18, scan), 17, heat.clamp(0.0, 1.0));
      final eg = (.8 + heat * .6);
      if (rp.paint) drawGlow(c, Offset(ex, -3), 14 + heat * 10, withA(heat > .5 ? u.hot : u.glow, .85 * eg.clamp(0.0, 1.0)));
      final eye = rrPath(ex - 2.6, -7.4, 5.2, 8.6, 2);
      fillC(c, eye, heat > .5 ? lt(u.hot, .3) : u.glow);
      fillC(c, rrPath(ex - 1, -5.8, 2, 5.2, 1), const Color(0xFFFFFFFF));
      // A faint trailing scan line on the visor.
      c.drawLine(Offset(3, -3), Offset(21, -3), Paint()..color = withA(u.glowD, .22)..strokeWidth = .8);
    }
    c.restore();
  }

  void _pod(RigPainter rp, Joints j, bool back, _U7 u) {
    final c = rp.c;
    final sil = rp.sil != null;
    final sh = back ? j.bSh : j.fSh;
    Color cc(Color col) => back ? dk(col, .3) : col;
    // Rocket pod on top of the shoulder, tilted forward.
    c.save();
    c.translate(sh.dx - 1, sh.dy - 2);
    c.rotate(-.4);
    rp.fill(_podP, cc(u.teal), const Rect.fromLTRB(-5, -17, 21, -3), shade: u.tealD, lw: 2);
    if (!sil) {
      rp.fill(rrPath(-5, -12, 25, 3, 1), cc(u.cream), const Rect.fromLTRB(-5, -12, 20, -9), noHT: true, lw: 1.1);
      dotC(c, const Offset(20, -12.5), 3.3, u.dark);
      dotC(c, const Offset(20, -7), 3.3, u.dark);
      dotC(c, const Offset(20.5, -12.5), 2.3, cc(u.hot));
      dotC(c, const Offset(20.5, -7), 2.3, cc(u.hot));
      dotC(c, const Offset(-2, -14), 1.1, u.rivet);
    }
    c.restore();
  }

  void _arm(RigPainter rp, Joints j, bool back, KPose p, _U7 u, double heat) {
    final c = rp.c;
    final sil = rp.sil != null;
    final sh = back ? j.bSh : j.fSh, el = back ? j.bEl : j.fEl, wr = back ? j.bWr : j.fWr;
    final dkc = back ? .3 : 0.0;
    Color cc(Color col) => back ? dk(col, dkc) : col;
    // Shoulder ball, upper arm, elbow, forearm, cuff.
    rp.fill(ellP(sh.dx, sh.dy + 1, 11, 10), cc(u.cream), Rect.fromCenter(center: sh, width: 22, height: 20), shade: u.creamD, lw: 2.2);
    final ua = segBox(sh, el, 9, 8, 3.5);
    rp.fill(ua, cc(u.cream), segRect(sh, el, 10), shade: u.creamD, lw: 2.2);
    rp.fill(ellP(el.dx, el.dy, 7.4, 7.4), cc(u.dark), Rect.fromCenter(center: el, width: 15, height: 15), noHT: true, lw: 1.8);
    rp.fill(segBox(el, wr, 8.6, 9.6, 3), cc(u.teal), segRect(el, wr, 10), shade: u.tealD, lw: 2.2);
    rp.fill(segBox(Offset.lerp(el, wr, .62)!, wr, 10.6, 10.6, 2.5), cc(u.cream), segRect(el, wr, 11), noHT: true, lw: 1.8, shade: u.creamD);
    if (!sil) {
      rp.detail((pa) {
        final q = Offset.lerp(sh, el, .5)!;
        pa.addOval(Rect.fromCenter(center: q, width: 5, height: 5));
      }, w: 1);
    }
    // Boxy fist (or a flat claw when open).
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    if (p.open > .5) {
      rp.fill(rrPath(-2, -8.5, 14, 17, 4), cc(u.cream), const Rect.fromLTRB(-2, -9, 12, 9), shade: u.creamD, lw: 2);
      for (var i = 0; i < 3; i++) {
        rp.fill(rrPath(11, -9.5 + i * 6.4, 12, 5.4, 2), cc(u.cream), Rect.fromLTWH(11, -9.5 + i * 6.4, 12, 5.4), noHT: true, lw: 1.5);
      }
    } else {
      rp.fill(rrPath(-3, -10, 21, 20, 5), cc(u.cream), const Rect.fromLTRB(-3, -10, 18, 10), shade: u.creamD, lw: 2.3);
      if (!sil) {
        rp.detail((pa) => pa
          ..moveTo(10, -10)
          ..lineTo(10, 10)
          ..moveTo(10, -3.5)
          ..lineTo(18, -3.5)
          ..moveTo(10, 3.5)
          ..lineTo(18, 3.5), w: 1.2);
        if (heat > .05) {
          c.drawRect(const Rect.fromLTRB(-3, -10, 18, 10), Paint()..color = withA(u.hot, heat * .3));
        }
      }
    }
    c.restore();
  }

  void _leg(RigPainter rp, Joints j, bool back, KPose p, _U7 u) {
    final c = rp.c;
    final sil = rp.sil != null;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    Color cc(Color col) => back ? dk(col, .3) : col;
    rp.fill(segBox(hip, kn, 12, 10.2, 4), cc(u.cream), segRect(hip, kn, 12), shade: u.creamD, lw: 2.3);
    rp.fill(ellP(kn.dx, kn.dy, 8.6, 8.6), cc(u.dark), Rect.fromCenter(center: kn, width: 17, height: 17), noHT: true, lw: 1.8);
    rp.fill(segBox(kn, an, 10.2, 9, 3), cc(u.teal), segRect(kn, an, 11), shade: u.tealD, lw: 2.3);
    final kp = Offset.lerp(hip, kn, .93)!;
    rp.fill(roundPoly([kp + const Offset(-3, -9), kp + const Offset(12, -7), kp + const Offset(12, 8), kp + const Offset(-3, 9)], 3), cc(u.cream),
        Rect.fromCenter(center: kp, width: 16, height: 18), noHT: true, lw: 1.8, shade: u.creamD);
    if (!sil) {
      rp.detail((pa) {
        final a = Offset.lerp(kn, an, .5)!;
        pa.moveTo(a.dx - 8, a.dy);
        pa.lineTo(a.dx + 8, a.dy);
      }, w: 1.1);
    }
    c.save();
    c.translate(an.dx, an.dy + 2);
    c.rotate(footAngle(j, p, back));
    c.scale(1.08, 1.08);
    rp.fill(_boot, cc(u.cream), const Rect.fromLTRB(-12, -14, 28, 7), shade: u.creamD, lw: 2.3);
    rp.fill(rrPath(-12, 3, 41, 4.5, 1.5), cc(u.dark), const Rect.fromLTRB(-12, 3, 29, 8), noHT: true, lw: 1.5);
    if (!sil) {
      rp.detail((pa) => pa
        ..moveTo(14, -4)
        ..lineTo(14, 3)
        ..moveTo(-6, -9)
        ..lineTo(3, -9), w: 1.1);
    }
    c.restore();
  }

  // ================================================================ moves

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = _idle;
    final q = Pq(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    switch (m.name) {
      case 'standLight':
        final x = lunge(id, m, q(fu: 1.5, ff: 1.56, lean: .2, rx: 8, bu: .6, bf: 2.2), Jt.fHa);
        return MoveAnim(strike(m, I, q(fu: .2, ff: 2.5, lean: .04), x, hold: KPose.from(x, rx: x.rx + 2)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(id, m, q(bu: 1.5, bf: 1.56, baf: 1, lean: .26, rx: 8, fu: .4, ff: 2.4), Jt.bHa);
        return MoveAnim(strike(m, I, q(bu: .1, bf: 2.6, baf: 1, lean: .04), x), smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // Both fists up, then a hammer blow.
        final x = lunge(id, m, q(fu: 1.35, ff: 1.0, bu: 1.25, bf: .95, lean: .55, rx: 12, head: .1), Jt.fHa);
        return MoveAnim(
            strike(m, I, q(fu: 2.7, ff: 3.0, bu: 2.5, bf: 2.9, lean: -.12, rx: -4, baf: 1), x, hold: KPose.from(x, lean: .6), windAt: .6),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a + 2);
      case 'standFinisher':
        final x = lunge(id, m, KPose.from(pKickX, ft: .0, fu: 1.1, ff: 1.5), Jt.bAn);
        return MoveAnim(strike(m, I, KPose.from(pKickC, fu: .8, ff: 1.9), x, hold: KPose.from(x, bt: 2.25, bs: 2.05), windAt: .55),
            smear: Jt.bAn, smearA: s - 4, smearB: s + a + 2);
      case 'rocket':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final brace = q(lean: .2, rx: 2, fu: 1.1, ff: 1.2, bu: .9, bf: 1.1, baf: 1, ft: .62, fs: .0, bt: -.4, bs: -.3, head: -.12);
        final aim = q(lean: -.08, fu: 1.3, ff: 1.4, bu: 1.1, bf: 1.3, baf: 1, ft: .5, bt: -.25, head: -.18, sa: .5);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rd(sp * .55)), aim),
          Key(sp, KPose.from(brace, rx: -4), 1),
          Key(sp + rd((t - sp) * .4), KPose.from(brace, lean: .12, rx: 0)),
          Key(mx(t, sp + 3), I),
        ]));
      case 'thrusterDash':
        final crouch = q(lean: .45, ft: .9, fs: -.25, bt: -.5, bs: -.7, fu: .9, ff: 1.5, bu: .6, bf: 1.9, sx: .5);
        final fly = q(lean: .95, head: -.25, fu: 1.5, ff: 1.5, bu: 1.2, bf: 1.7, baf: 1, ft: -.55, fs: -.7, bt: -.8, bs: -1.0, sx: 1, rx: 6);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 4), crouch),
              Key(s, fly, 1),
              Key(s + a, fly),
              Key(s + a + rd(r * .5), q(lean: .35, ft: .7, fs: -.2, sx: .2)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a);
      case 'laserBeam':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final stand = q(lean: -.05, head: -.12, fu: .25, ff: .5, bu: .2, bf: .45, ft: .62, fs: .04, bt: -.5, bs: -.2);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rd(sp * .35)), KPose.from(stand, sa: .35)),
          Key(mx(2, sp - 1), KPose.from(stand, sa: 1, lean: -.1)),
          Key(sp, KPose.from(stand, sa: 1, lean: -.08, rx: -3), 1),
          Key(sp + 6, KPose.from(stand, sa: .7, lean: -.06)),
          Key(mx(t - 6, sp + 7), KPose.from(stand, sa: .2)),
          Key(mx(t, sp + 8), I),
        ]));
      case 'jetRise':
        final crouch = q(lean: .45, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .9, ff: 1.6, bu: .5, bf: 1.9, sx: .6);
        final up = q(lean: -.04, head: -.2, fu: 3.0, ff: 3.1, bu: .35, bf: 2.0, ft: .12, fs: .06, bt: -.1, bs: -.05, sx: 1, rx: 6);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), crouch),
              Key(s, up, 1),
              Key(s + a, KPose.from(up, lean: -.1, sx: .7)),
              Key(s + a + rd(r * .45), q(lean: .3, ft: .9, fs: -.3, bt: .1, bs: -.6)),
              Key(mx(t, s + a + rd(r * .45) + 1), I),
            ]),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a + 1);
      case 'selfDestruct':
        final brace = q(fu: 1.15, ff: 2.95, bu: .95, bf: 3.05, baf: 1, lean: .08, ft: .55, fs: .05, bt: -.3, bs: -.4, head: .15);
        final keys = <Key>[Key(0, I), Key(4, KPose.from(brace, sa: .15))];
        var n = 0;
        for (var f = 6; f < s - 1; f += 2) {
          final k = (f - 4) / (s - 5);
          keys.add(Key(f, KPose.from(brace, rx: (n.isEven ? 1.8 : -1.8) * (.4 + k), sa: k, lean: .08 + (n.isEven ? .05 : -.02), head: .15 - k * .1)));
          n++;
        }
        final burst = q(fu: 1.9, ff: 1.65, bu: -1.3, bf: -1.2, baf: 1, lean: -.14, head: -.28, ft: .7, fs: .1, bt: -.6, bs: -.2, sa: 1, open: 1);
        keys.add(Key(s, burst, 1));
        keys.add(Key(s + a, burst));
        final slump = q(lean: .5, head: .4, fu: .1, ff: .25, bu: .05, bf: .2, ft: .5, fs: .05, bt: -.3, bs: -.2, sa: .5);
        keys.add(Key(s + a + 10, slump));
        keys.add(Key(s + a + rd(r * .65), KPose.from(slump, sa: 0, lean: .4)));
        keys.add(Key(mx(t, s + a + rd(r * .65) + 1), I));
        return MoveAnim(mono(keys));
    }
    return null;
  }

  // ================================================================ projectiles

  @override
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) {
    if (def.name.startsWith('Laser')) {
      _beam(c, look, def, age);
      return true;
    }
    if (def.name.startsWith('Rocket')) {
      _rocket(c, look, def, age);
      return true;
    }
    return false;
  }

  static final Path _rBody = roundPoly(const [Offset(-12, -4.6), Offset(5, -5), Offset(9, -3), Offset(9, 3), Offset(5, 5), Offset(-12, 4.6)], 1.6);
  static final Path _rShade = Path.combine(PathOperation.intersect, _rBody, rrPath(-12, 0, 24, 6, 0));
  static final Path _rBand1 = Path.combine(PathOperation.intersect, _rBody, rrPath(-7, -6, 3.4, 12, 0));
  static final Path _rBand2 = Path.combine(PathOperation.intersect, _rBody, rrPath(2, -6, 1.6, 12, 0));
  static final Path _rNose = Path()
    ..moveTo(8, -4.3)
    ..quadraticBezierTo(15, -3, 16, 0)
    ..quadraticBezierTo(15, 3, 8, 4.3)
    ..close();
  static final Path _rFinT = roundPoly(const [Offset(-12.5, -4.5), Offset(-5, -4.5), Offset(-11, -10)], .6);
  static final Path _rFinB = roundPoly(const [Offset(-12.5, 4.5), Offset(-5, 4.5), Offset(-11, 10)], .6);

  void _rocket(Canvas c, FightLook look, ProjectileDef def, int age) {
    final tilt = math.atan2(-def.vy.toDouble(), def.vx.toDouble());
    c.save();
    c.rotate(tilt);
    // Smoke trail behind the exhaust.
    for (var i = 0; i < 6; i++) {
      final k = i / 6.0, wob = math.sin(age * .5 + i * 1.7) * 1.1;
      final al = (1 - k) * (look == FightLook.painted ? .5 : .9);
      dotC(c, Offset(-14 - i * 5.0 - (age % 3), wob), 1.6 + k * 4.6, withA(const Color(0xFFE9E4DA), al));
      if (look == FightLook.cartoon) ringC(c, Offset(-14 - i * 5.0 - (age % 3), wob), 1.6 + k * 4.6, .5, withA(kInk, (1 - k) * .8));
    }
    c.save();
    c.translate(-12.5, 0);
    c.rotate(math.pi);
    drawFlame(c, look, 10 + math.sin(age * 1.3) * 2.4, 3.1, age, 3, outer: const Color(0xFFFF4B1F), mid: const Color(0xFFFFB02A), core: const Color(0xFFFFF4C2), ink: .7);
    c.restore();
    fillC(c, _rFinT, const Color(0xFF2FB3AD));
    fillC(c, _rFinB, const Color(0xFF1A7580));
    fillC(c, _rBody, const Color(0xFFF1E6CC));
    fillC(c, _rShade, const Color(0x22000000));
    fillC(c, _rBand1, const Color(0xFF2FB3AD));
    fillC(c, _rBand2, const Color(0xFFBFA97C));
    fillC(c, _rNose, const Color(0xFFFF5A3A));
    dotC(c, const Offset(-1.5, 0), 1.7, const Color(0xFF7FF7FF));
    dotC(c, const Offset(-12, 0), 1.5, const Color(0xFF232D3A));
    if (look == FightLook.cartoon) {
      for (final p in [_rBody, _rNose, _rFinT, _rFinB]) {
        strokeC(c, p, .8, kInk);
      }
    }
    if (look == FightLook.painted) drawGlow(c, const Offset(14, 0), 8, const Color(0x55FFB090));
    c.restore();
  }

  void _beam(Canvas c, FightLook look, ProjectileDef def, int age) {
    final fl = .88 + .12 * math.sin(age * 2.4) + .05 * math.sin(age * 5.1);
    final ex = def.name.contains('EX');
    final th = (ex ? 1.7 : 1.4) * fl;
    final fade = age > def.life - 3 ? (def.life - age) / 3.0 : 1.0;
    const x0 = -15.5, x1 = 15.5;
    Path lens(double h, double tail) => Path()
      ..moveTo(x0, 0)
      ..lineTo(x0 + tail, -h)
      ..lineTo(x1 - h, -h)
      ..quadraticBezierTo(x1 + h * .6, -h, x1 + h * .6, 0)
      ..quadraticBezierTo(x1 + h * .6, h, x1 - h, h)
      ..lineTo(x0 + tail, h)
      ..close();
    final outer = lens(th * 1.35, 9), mid = lens(th * .9, 8), core = lens(th * .42, 7);
    if (look == FightLook.painted) {
      for (var i = 0; i < 7; i++) {
        drawGlow(c, Offset(x0 + 2 + i * 4.9, 0), 4.6 * fl, withA(ex ? const Color(0xFFB6FF6A) : const Color(0xFF7FF7FF), .6 * fade));
      }
      c.drawPath(outer, Paint()..blendMode = BlendMode.plus..color = withA(const Color(0xFF14B8D6), .5 * fade));
      c.drawPath(mid, Paint()..blendMode = BlendMode.plus..color = withA(const Color(0xFF7FF7FF), .7 * fade));
      c.drawPath(core, Paint()..blendMode = BlendMode.plus..color = withA(const Color(0xFFFFFFFF), .95 * fade));
    } else {
      fillC(c, outer, withA(const Color(0xFF14B8D6), fade));
      fillC(c, mid, withA(const Color(0xFF7FF7FF), fade));
      fillC(c, core, withA(const Color(0xFFFFFFFF), fade));
      if (look == FightLook.cartoon) strokeC(c, outer, .45, withA(kInk, fade));
    }
    // Crackle: a few jagged filaments flick along the beam.
    final r = SRand(age * 7 + 3);
    final zz = Path()..moveTo(x0 + 6, 0);
    for (var x = x0 + 8; x < x1 - 1; x += 3.4) {
      zz.lineTo(x, (r.next() - .5) * th * 1.9);
    }
    if (look == FightLook.painted) {
      plusStroke(c, zz, .35, withA(const Color(0xFFFFFFFF), .8 * fade));
    } else {
      strokeC(c, zz, .35, withA(const Color(0xFFFFFFFF), .9 * fade));
    }
    // Bright head at the front.
    flash(c, look, 3.4 * fl, const Color(0xFF7FF7FF), fade, pts: 6, rot: age * .5);
  }

  // ================================================================ move fx

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final x = FxCtx(cam, s, player);
    final f = x.f;
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final hot = alt ? const Color(0xFFFF3F6E) : const Color(0xFFFF7A3A);
    final glow = alt ? const Color(0xFFB6FF6A) : const Color(0xFF7FF7FF);
    final m = x.move;
    final sf = x.sf;
    // Thrusters on dashes and hops.
    void thrust(Offset at, double len, double wid, {double rot = math.pi, int seed = 1}) {
      x.at(c, at, x.u, () {
        c.rotate(rot);
        drawFlame(c, look, len, wid, s.frame, seed, outer: hot, mid: lt(hot, .4), core: glow, ink: 1.6);
      });
    }

    if (f.state == St.dash && sf > 0) {
      final double len = 18.0 + 14.0 * math.min<double>(1.0, sf / 4);
      thrust(x.torso(const Offset(-43, -47)), len, 4.2, seed: 2);
      thrust(x.torso(const Offset(-43, -34)), len * .9, 3.8, seed: 3);
    } else if (f.state == St.jump && f.y > 3000) {
      thrust(x.torso(const Offset(-43, -47)), 10, 3, rot: math.pi * .85, seed: 4);
      thrust(x.torso(const Offset(-43, -34)), 9, 2.6, rot: math.pi * .85, seed: 5);
    }
    if (m == null) return;
    final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : m.startup;
    switch (m.name) {
      case 'thrusterDash':
        if (sf >= m.startup - 4 && sf <= m.startup + m.active + 6) {
          final k = math.min(1.0, (sf - m.startup + 4) / 3);
          thrust(x.torso(const Offset(-43, -47)), 46 * k, 5.2, rot: math.pi - .1, seed: 6);
          thrust(x.torso(const Offset(-43, -34)), 40 * k, 4.6, rot: math.pi - .1, seed: 7);
          // Speed streaks.
          if (sf >= m.startup) {
            final o = x.torso(const Offset(-30, -40));
            x.at(c, o, x.u, () {
              final r = SRand(s.frame ~/ 2);
              for (var i = 0; i < 4; i++) {
                final y = -22 + i * 15 + r.next() * 6, l = 30 + r.next() * 40;
                final a = Offset(-20 - r.next() * 20, y), b = Offset(-20 - l, y);
                if (look == FightLook.painted) {
                  plusLine(c, a, b, 1.6, withA(glow, .5));
                } else {
                  lineC(c, a, b, 1.6, withA(glow, .85));
                }
              }
            });
          }
        }
        break;
      case 'jetRise':
        if (sf <= m.startup + m.active + 6) {
          final k = sf < m.startup ? .35 : math.max(0.0, 1 - (sf - m.startup - m.active) / 7);
          for (final jt in const [Jt.fAn, Jt.bAn]) {
            final o = x.joint(jt);
            thrust(o + Offset(0, 4 * x.u), 34 * k, 6, rot: math.pi / 2, seed: jt.index);
          }
          if (sf < 12) {
            final g = x.world(0, 0);
            x.at(c, g, x.k, () => puffs(c, look, sf, 11, 9, 42, 12, const Color(0xFFE0D9CC), r0: 3, grow: 6));
          }
        }
        break;
      case 'rocket':
        {
          final age = sf - sp;
          if (age >= 0 && age < 9) {
            final mzd = rotO(const Offset(22, -11), -.4);
            final o = x.off(x.joint(Jt.fSh), mzd);
            x.at(c, o, x.u, () {
              flash(c, look, 14 * (1 - age / 9) + 3, glow, 1 - age / 11, pts: 7, rot: age * .3);
              puffs(c, look, age, 5, 6, 20, 8, const Color(0xFFEDE8DE), r0: 2, grow: 5, life: 14);
            });
            if (m.projectiles.length > 1) {
              final o2 = x.off(x.joint(Jt.bSh), mzd);
              x.at(c, o2, x.u, () => flash(c, look, 12 * (1 - age / 9) + 3, glow, 1 - age / 11, pts: 7, rot: age * .3));
            }
          }
        }
        break;
      case 'laserBeam':
        {
          final core = x.torso(_core);
          if (sf < sp) {
            // The core charges: light gathers inwards.
            final k = sf / math.max(1, sp);
            x.at(c, core, x.u, () {
              if (look == FightLook.painted) {
                drawGlow(c, Offset.zero, 12 + 26 * k, withA(glow, .5 + .4 * k));
              } else {
                fillC(c, Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 4 + 8 * k)), withA(glow, .7));
                if (look == FightLook.cartoon) ringC(c, Offset.zero, 4 + 8 * k, 1.4, kInk);
              }
              final r = SRand(sf * 3 + 1);
              for (var i = 0; i < 6; i++) {
                final a = r.next() * math.pi * 2, d = (1 - ((sf * .09 + i / 6) % 1)) * 34;
                dotC(c, polar(a, d), 1.6, withA(const Color(0xFFFFFFFF), .9));
              }
            });
          } else if (sf - sp < 9) {
            final age = sf - sp;
            x.at(c, core, x.u, () => flash(c, look, 22 * (1 - age / 9) + 4, glow, 1 - age / 10, pts: 10, rot: .3));
          }
        }
        break;
      case 'selfDestruct':
        _selfDestruct(c, x, m, look, hot, glow);
        break;
    }
  }

  void _selfDestruct(Canvas c, FxCtx x, MoveDef m, FightLook look, Color hot, Color glow) {
    final sf = x.sf, st = m.startup;
    final core = x.torso(_core);
    if (sf < st) {
      final k = sf / st;
      x.at(c, core, x.u, () {
        final rr = 48 - 30 * k;
        if (look == FightLook.painted) {
          drawGlow(c, Offset.zero, 16 + 40 * k, withA(hot, .35 + .5 * k));
        }
        // Contracting rings and sparks pulled in.
        for (var i = 0; i < 3; i++) {
          final t = ((sf * .08) + i / 3) % 1.0;
          final r = (1 - t) * (rr + 16) + 6;
          if (look == FightLook.painted) {
            plusRing(c, Offset.zero, r, 1.8, withA(hot, t * .8));
          } else {
            ringC(c, Offset.zero, r, 2.2, withA(i.isEven ? hot : glow, .4 + t * .5));
          }
        }
        final rnd = SRand(sf * 5 + 2);
        for (var i = 0; i < 8; i++) {
          final a = rnd.next() * math.pi * 2, d = (1 - ((sf * .1 + i / 8) % 1)) * (rr + 30);
          dotC(c, polar(a, d), 1.4 + k * 1.2, i.isEven ? const Color(0xFFFFFFFF) : hot);
        }
      });
      return;
    }
    final age = sf - st;
    final cen = x.world(0, 96);
    if (age <= 30) {
      x.at(c, cen, x.k, () {
        final grow = easeOut(math.min(1.0, age / 9));
        final fade = age < 12 ? 1.0 : math.max(0.0, 1 - (age - 12) / 18);
        final R = 150 * grow;
        if (look == FightLook.painted) {
          drawGlow(c, Offset.zero, R * 2.0, withA(hot, .55 * fade));
          drawGlow(c, Offset.zero, R * 1.35, withA(const Color(0xFFFFC85A), .8 * fade));
          drawGlow(c, Offset.zero, R * .85, withA(const Color(0xFFFFFFFF), .9 * fade));
          plusRing(c, Offset.zero, R * 1.15, 9 * (1 - grow) + 2, withA(const Color(0xFFFFE0A0), .9 * fade));
        } else {
          // A ragged fireball: outer starburst, orange body, yellow heart, white core.
          final st1 = starPath(0, 0, R * 1.18, R * .9, 16, age * .08);
          fillC(c, st1, withA(const Color(0xFFFF4B1F), fade));
          if (look == FightLook.cartoon) strokeC(c, st1, 3, withA(kInk, fade));
          fillC(c, starPath(0, 0, R * .88, R * .66, 14, -age * .1), withA(const Color(0xFFFFA81F), fade));
          fillC(c, Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: R * .55)), withA(const Color(0xFFFFE066), fade));
          fillC(c, Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: R * .28)), withA(const Color(0xFFFFFFFF), fade));
          ringC(c, Offset.zero, R * 1.3, 4 * (1 - grow) + 1.5, withA(const Color(0xFFFFF1C0), .8 * fade));
        }
        // Flying plates and bolts.
        final r = SRand(m.startup * 3 + 9);
        for (var i = 0; i < 14; i++) {
          final a = r.next() * math.pi * 2, sp = .6 + r.next() * .7;
          final d = R * 1.05 * sp * grow + 10;
          final o = Offset(math.cos(a) * d, math.sin(a) * d - age * .6 + age * age * .02);
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(a * 3 + age * .3 * (i.isEven ? 1 : -1));
          final shard = roundPoly(const [Offset(-5, -3), Offset(5, -2), Offset(4, 3), Offset(-4, 2)], 1);
          fillC(c, shard, withA(i % 3 == 0 ? const Color(0xFF2FB3AD) : const Color(0xFFF1E6CC), fade));
          if (look == FightLook.cartoon) strokeC(c, shard, 1.4, withA(kInk, fade));
          c.restore();
        }
      });
    }
    // Smoke rising from the blast, then from the scorched head.
    if (age > 4 && age < 56) {
      x.at(c, x.world(0, 70), x.k, () {
        puffs(c, look, age - 4, 21, 12, 110, 80, const Color(0xFF4A4452), r0: 6, grow: 16, life: 52);
      });
    }
    if (age > 14 && sf < m.total - 6) {
      x.at(c, x.joint(Jt.head), x.u, () => puffs(c, look, (age * 2) % 22, 8 + age ~/ 11, 4, 8, 34, const Color(0xFF5A5460), r0: 2, grow: 5));
    }
  }
}
