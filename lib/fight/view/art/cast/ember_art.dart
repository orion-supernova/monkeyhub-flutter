// EMBER (she): a small, bouncy dragon kid. Red-orange scales on arms, legs and
// a long tail, little horns, small wings, an oversized yellow hoodie with the
// hood up between the horns, sneakers. Channels: `sx` = ignition (hand fire,
// wing fire, tail-tip flame, wings spread), `sa` = tail swing (radians about
// its root; negative sweeps low and forward), `open` = claws spread + mouth open.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim;
import 'cast_art.dart';
import 'legends_kit.dart';

class _EM {
  final Color scale, scaleD, belly, hood, hoodD, hoodIn, horn, shoe, shoeD, accent, fire1, fire2, fire3, wing;
  const _EM(this.scale, this.scaleD, this.belly, this.hood, this.hoodD, this.hoodIn, this.horn, this.shoe, this.shoeD, this.accent,
      this.fire1, this.fire2, this.fire3, this.wing);
  static final base = _EM(hex(0xf0502a), hex(0xa82a1a), hex(0xffd9a0), hex(0xffd23a), hex(0xd8981a), hex(0x9a5a08), hex(0xf6ecd0),
      hex(0xf6f2e8), hex(0xb8b2a6), hex(0xe8402a), hex(0xff4b1f), hex(0xffa81f), hex(0xfff1a8), hex(0xffa23a));
  /// Mirror match: a teal dragon in a violet hoodie with blue fire.
  static final alt = _EM(hex(0x2fb8b0), hex(0x167a78), hex(0xd8f6ee), hex(0x8a4fd6), hex(0x5a2fa0), hex(0x3a1c70), hex(0xfff0c8),
      hex(0x2a2236), hex(0x14101e), hex(0xff6ab0), hex(0x3a6bff), hex(0x38d6ff), hex(0xe8ffff), hex(0xff8ac8));
}

final KPose _idle = KPose.from(pIdle,
    lean: .12, head: -.05, fu: .8, ff: 2.1, bu: .5, bf: 2.4, ft: .5, fs: -.1, bt: -.2, bs: -.45);

final Path _hoodieP = roundPoly(const [
  Offset(-18, 5), Offset(-21, -18), Offset(-17, -36), Offset(-6, -46), Offset(10, -46), Offset(18, -36), Offset(22, -16), Offset(23, 6),
], 8);
final Path _pocket = roundPoly(const [Offset(-3, -22), Offset(15, -21), Offset(17, -9), Offset(-5, -9)], 3.5);
final Path _hem = rrPath(-19, -1, 42, 7, 3);
final Path _sneaker = roundPoly(const [Offset(-9, -10), Offset(5, -11), Offset(10, -4), Offset(21, -1), Offset(23, 6), Offset(-10, 6)], 3.5);
final Path _toeCap = roundPoly(const [Offset(11, -4), Offset(21, -1), Offset(23, 6), Offset(11, 6)], 2.5);
final Path _hoodRing = Path()
  ..fillType = PathFillType.evenOdd
  ..addOval(Rect.fromCenter(center: const Offset(0, -2), width: 46, height: 46))
  ..addOval(Rect.fromCenter(center: const Offset(5, 0), width: 29, height: 33));
final Path _hoodPeak = Path()
  ..moveTo(-8, -20)
  ..quadraticBezierTo(-10, -37, -27, -36)
  ..quadraticBezierTo(-19, -29, -17, -17)
  ..close();
final Path _hornN = Path()
  ..moveTo(-12, -14)
  ..quadraticBezierTo(-20, -30, -9, -38)
  ..quadraticBezierTo(-10, -26, -2, -17)
  ..close();
final Path _hornF = Path()
  ..moveTo(9, -17)
  ..quadraticBezierTo(14, -32, 24, -34)
  ..quadraticBezierTo(18, -26, 17, -15)
  ..close();
final Path _snout = ovalP(15, 6, 7.5, 5.5, .15);

class EmberArt extends CastArt {
  const EmberArt();

  @override
  int get id => 18;

  @override
  RigDims get dims => const RigDims(18, 44, 26, 24, 28, 26, 1.34, 8, 6, 20, 5);

  @override
  KPose get idle => _idle;

  @override
  double get portraitWidth => 120;

  @override
  KPalette get palette => KPalette(
      skin: hex(0xf0502a), hair: hex(0xd8981a), tip: hex(0xffd23a), vest: hex(0xffd23a), tank: hex(0xd8981a),
      pants: hex(0xf0502a), pad: hex(0xa82a1a), wrap: hex(0xffd9a0), shoe: hex(0xf6f2e8), sole: hex(0xb8b2a6), accent: hex(0xffa81f));

  @override
  KPalette get altPalette => KPalette(
      skin: hex(0x2fb8b0), hair: hex(0x5a2fa0), tip: hex(0xff6ab0), vest: hex(0x8a4fd6), tank: hex(0x5a2fa0),
      pants: hex(0x2fb8b0), pad: hex(0x167a78), wrap: hex(0xd8f6ee), shoe: hex(0x2a2236), sole: hex(0x14101e), accent: hex(0x38d6ff));

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final q = Pq(_idle);
    return (
      q(fu: 2.6, ff: 3.0, bu: 2.4, bf: 2.9, lean: -.1, rx: -3, sx: .5),
      q(fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.5, lean: .5, rx: 12, sx: 1, open: 1),
      q(fu: 1.2, ff: 2.6, bu: 1.0, bf: 2.7, baf: 1, lean: .15, sx: .3),
    );
  }

  // ================================================================ paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final e = alt ? _EM.alt : _EM.base;
    final sil = rp.sil != null;
    final ig = p.sx.clamp(0.0, 1.0);
    final bounce = math.sin(frame * .14);
    _tail(rp, p, e, frame, ig);
    if (!sil) _wings(rp, p, e, frame, ig);
    if (p.baf < .5) _arm(rp, j, true, p, e, ig);
    _leg(rp, j, true, p, e);
    _torso(rp, p, e, frame);
    _leg(rp, j, false, p, e);
    if (p.blf >= .5) _leg(rp, j, true, p, e);
    _head(rp, j, p, e, frame, bounce);
    if (p.baf >= .5) _arm(rp, j, true, p, e, ig);
    _arm(rp, j, false, p, e, ig);
  }

  List<Offset> tailPts(KPose p, double f) {
    final sw = math.sin(f * .09) * 4;
    final k = 1 - math.min(1.0, p.sa.abs() * .8) * .75; // straightens when swung
    final raw = cubic(const Offset(-8, -3), Offset(-30, 4 + sw * .3), Offset(-50, -14 + sw * k), Offset(-48 * (1 - (1 - k) * .3) - 6, -38 * k + 4 + sw * k), 14);
    final cs = math.cos(p.sa), sn = math.sin(p.sa);
    const o = Offset(-8, -3);
    return [
      for (final q in raw)
        Offset(o.dx + (q.dx - o.dx) * cs - (q.dy - o.dy) * sn, o.dy + (q.dx - o.dx) * sn + (q.dy - o.dy) * cs)
    ];
  }

  void _tail(RigPainter rp, KPose p, _EM e, double f, double ig) {
    final c = rp.c;
    c.save();
    c.rotate(p.lean * .5);
    final pts = tailPts(p, f);
    rp.fill(tube(pts, 6.4, 1.6), e.scale, boundsOf(pts, 8), shade: e.scaleD, lw: 2);
    if (rp.sil == null) {
      // Back spikes and a lighter underside.
      for (var i = 3; i < 13; i += 3) {
        final a = pts[i], b = pts[i + 1];
        final d = b - a, n = Offset(d.dy, -d.dx) / d.distance;
        final tip = a + n * (4.5 - i * .25) + d * .5;
        fillC(c, Path()..moveTo(a.dx, a.dy)..lineTo(tip.dx, tip.dy)..lineTo(b.dx, b.dy)..close(), e.scaleD);
        if (rp.cel) strokeC(c, Path()..moveTo(a.dx, a.dy)..lineTo(tip.dx, tip.dy)..lineTo(b.dx, b.dy), 1.2, kInk);
      }
      // The tail always burns a little at the tip.
      final tip = pts.last, pre = pts[pts.length - 3];
      final ang = math.atan2(tip.dy - pre.dy, tip.dx - pre.dx);
      c.save();
      c.translate(tip.dx, tip.dy);
      c.rotate(ang * .4 - math.pi / 2 * .6);
      drawFlame(c, rp.look, 9 + 5 * math.sin(f * .6) + ig * 12, 4 + ig * 3, f.toInt(), 5, outer: e.fire1, mid: e.fire2, core: e.fire3, ink: 1.4);
      c.restore();
    }
    c.restore();
  }

  void _wings(RigPainter rp, KPose p, _EM e, double f, double ig) {
    final c = rp.c;
    c.save();
    c.rotate(p.lean);
    final flap = math.sin(f * .16) * .12 + ig * .35;
    for (var w = 0; w < 2; w++) {
      c.save();
      c.translate(-12 + w * 5, -34);
      c.rotate(-.35 - flap * (w == 0 ? 1 : .6) - ig * .5);
      final s = 1.6 + ig * .6;
      c.scale(s, s);
      final mem = Path()
        ..moveTo(0, 0)
        ..lineTo(-20, -22)
        ..quadraticBezierTo(-17, -10, -10, -9)
        ..quadraticBezierTo(-12, -2, -4, -1)
        ..quadraticBezierTo(-4, 5, 4, 4)
        ..close();
      final col = w == 0 ? dk(e.wing, .25) : e.wing;
      rp.fill(mem, col, const Rect.fromLTRB(-22, -24, 6, 6), shade: e.scaleD, lw: 1.8, noHT: true);
      lineC(c, const Offset(0, 0), const Offset(-20, -22), 2, e.scaleD);
      lineC(c, const Offset(-2, 0), const Offset(-10, -9), 1.2, e.scaleD);
      if (ig > .25 && w == 1) {
        c.save();
        c.translate(-20, -22);
        c.rotate(-math.pi * .75);
        drawFlame(c, rp.look, 10 + 12 * ig, 3.4, f.toInt(), 8 + w, outer: e.fire1, mid: e.fire2, core: e.fire3, ink: 1.2);
        c.restore();
      }
      c.restore();
    }
    c.restore();
  }

  void _torso(RigPainter rp, KPose p, _EM e, double f) {
    final c = rp.c;
    final sil = rp.sil != null;
    c.save();
    c.rotate(p.lean);
    rp.fill(_hoodieP, e.hood, const Rect.fromLTRB(-22, -47, 24, 6), shade: e.hoodD, lw: 2.3);
    rp.fill(_pocket, lt(e.hood, .06), const Rect.fromLTRB(-5, -22, 17, -9), shade: e.hoodD, lw: 1.6, noHT: true);
    rp.fill(_hem, dk(e.hood, .12), const Rect.fromLTRB(-19, -1, 23, 6), shade: e.hoodD, lw: 1.8, noHT: true);
    if (!sil) {
      rp.detail((pa) => pa
        ..moveTo(4, -22)
        ..lineTo(0, -9)
        ..moveTo(10, -22)
        ..lineTo(13, -9)
        ..moveTo(-12, -30)
        ..quadraticBezierTo(-14, -18, -13, -4)
        ..moveTo(-12, 0)
        ..lineTo(-12, 5)
        ..moveTo(-4, 0)
        ..lineTo(-4, 5)
        ..moveTo(4, 0)
        ..lineTo(4, 5)
        ..moveTo(12, 0)
        ..lineTo(12, 5)
        ..moveTo(19, 0)
        ..lineTo(19, 5), w: 1.2, col: rp.paint ? withA(e.hoodD, .8) : e.hoodD);
      // Drawstrings with little beads.
      for (final x in const [3.0, 9.0]) {
        lineC(c, Offset(x, -42), Offset(x - 1, -29), 1.5, e.belly);
        dotC(c, Offset(x - 1, -28), 1.7, e.belly);
      }
    }
    c.restore();
  }

  void _leg(RigPainter rp, Joints j, bool back, KPose p, _EM e) {
    final c = rp.c;
    final sil = rp.sil != null;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    Color cc(Color col) => back ? dk(col, .3) : col;
    rp.limb(hip, kn, 7.4, 6.2, cc(e.scale), bulge: 1.8, shade: e.scaleD);
    rp.limb(kn, an, 6.2, 5, cc(e.scale), bulge: 1.2, shade: e.scaleD);
    if (!sil) {
      // Scale chevrons on the thigh and shin.
      rp.detail((pa) {
        for (final t in const [.3, .6]) {
          final q = Offset.lerp(hip, kn, t)!;
          pa.moveTo(q.dx - 3, q.dy - 1);
          pa.lineTo(q.dx + 1, q.dy + 2);
          pa.lineTo(q.dx + 4, q.dy - 1);
        }
      }, w: 1, col: back ? e.scaleD : withA(e.scaleD, .8));
      // Slouchy white socks.
      rp.limb(Offset.lerp(kn, an, .62)!, an, 6.2, 6, cc(e.shoe), noHT: true, lw: 1.6, shade: e.shoeD);
    }
    c.save();
    c.translate(an.dx, an.dy + 2);
    c.rotate(footAngle(j, p, back));
    c.scale(1.12, 1.12);
    rp.fill(_sneaker, cc(e.shoe), const Rect.fromLTRB(-10, -11, 24, 7), shade: e.shoeD, lw: 2.1);
    rp.fill(_toeCap, cc(e.accent), const Rect.fromLTRB(10, -5, 24, 7), noHT: true, lw: 1.6);
    rp.fill(rrPath(-10, 4, 34, 4, 1.5), back ? dk(e.shoeD, .1) : e.shoeD, const Rect.fromLTRB(-10, 4, 24, 8), noHT: true, lw: 1.4);
    if (!sil) {
      rp.detail((pa) => pa
        ..moveTo(0, -9)
        ..lineTo(3, -5)
        ..moveTo(-3, -8)
        ..lineTo(1, -4), w: 1);
    }
    c.restore();
  }

  void _arm(RigPainter rp, Joints j, bool back, KPose p, _EM e, double ig) {
    final c = rp.c;
    final sil = rp.sil != null;
    final sh = back ? j.bSh : j.fSh, el = back ? j.bEl : j.fEl, wr = back ? j.bWr : j.fWr;
    Color cc(Color col) => back ? dk(col, .3) : col;
    // Oversized sleeve to the elbow, scaly forearm below it.
    rp.limb(sh, el, 8.8, 8, cc(e.hood), bulge: 2.4, shade: e.hoodD, lw: 2.1);
    rp.limb(el, wr, 5.4, 4.4, cc(e.scale), bulge: 1.2, shade: e.scaleD);
    rp.limb(Offset.lerp(sh, el, .86)!, Offset.lerp(sh, el, 1.06)!, 8.6, 8.2, cc(e.hoodD), noHT: true, lw: 1.6);
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    final fist = ovalP(3, 0, 6.2, 5.6);
    rp.fill(fist, cc(e.scale), const Rect.fromLTRB(-3, -6, 9, 6), shade: e.scaleD, lw: 1.8, noHT: true);
    if (!sil) {
      final open = p.open > .5;
      for (var i = 0; i < 3; i++) {
        final a = open ? (-.7 + i * .7) : (-.25 + i * .25);
        final o = Offset(7, -3.5 + i * 3.5);
        final tip = o + polar(a, open ? 6.5 : 4.2);
        final claw = Path()..moveTo(o.dx, o.dy - 1.3)..lineTo(tip.dx, tip.dy)..lineTo(o.dx, o.dy + 1.3)..close();
        fillC(c, claw, e.horn);
        if (rp.cel) strokeC(c, claw, 1, kInk);
      }
      if (ig > .15 && !back) {
        c.save();
        c.translate(5, 0);
        c.rotate(-ang - math.pi / 2);
        drawFlame(c, rp.look, 8 + 16 * ig + math.sin(ig * 30) * 2, 4 + 3 * ig, 3 + (ig * 40).toInt(), 2, outer: e.fire1, mid: e.fire2, core: e.fire3, ink: 1.4);
        c.restore();
      }
    }
    c.restore();
  }

  void _head(RigPainter rp, Joints j, KPose p, _EM e, double f, double bounce) {
    final c = rp.c;
    final sil = rp.sil != null;
    rp.limb(j.neck, Offset(j.head.dx - 6, j.head.dy + 12), 7, 6, e.hoodD, noHT: true, lw: 1.8);
    c.save();
    c.translate(j.head.dx, j.head.dy + bounce * .8);
    c.rotate(j.headA);
    c.scale(1.38, 1.38);
    rp.fill(_hornN, e.horn, const Rect.fromLTRB(-20, -38, -2, -13), shade: dk(e.horn, .25), lw: 1.6, noHT: true);
    rp.fill(_hornF, e.horn, const Rect.fromLTRB(9, -35, 25, -14), shade: dk(e.horn, .25), lw: 1.6, noHT: true);
    // The dark inside of the hood, then the face, then the hood's rim over it.
    rp.fill(ovalP(0, -2, 21, 21), e.hoodIn, const Rect.fromLTRB(-21, -23, 21, 19), noHT: true, lw: 2);
    rp.fill(ovalP(5, 0, 14.5, 16.5), e.scale, const Rect.fromLTRB(-10, -17, 20, 17), shade: e.scaleD, lw: 1.8);
    if (!sil) {
      rp.fill(_snout, lt(e.scale, .18), const Rect.fromLTRB(8, 1, 23, 12), noHT: true, lw: 1.4);
      dotC(c, const Offset(19, 4.5), .9, e.scaleD);
      dotC(c, const Offset(21, 5), .8, e.scaleD);
      fillC(c, ovalP(6.5, 8, 3.2, 2, 0), withA(const Color(0xFFFF7A9A), .55));
      // Big eyes: a near one and a smaller far one.
      rp.fill(ovalP(7, -4, 5.2, 6.4), const Color(0xFFFFFAF0), const Rect.fromLTRB(2, -11, 12, 3), noHT: true, lw: 1.3);
      rp.fill(ovalP(14.8, -4.4, 3, 4.4), const Color(0xFFFFFAF0), const Rect.fromLTRB(12, -9, 18, 1), noHT: true, lw: 1.1);
      fillC(c, ovalP(8.2, -3.6, 3.3, 4.4), e.fire2);
      fillC(c, ovalP(15.4, -4, 1.9, 3), e.fire2);
      fillC(c, ovalP(8.6, -3.6, 1.5, 3.2), const Color(0xFF2A120A));
      fillC(c, ovalP(15.6, -4, .9, 2), const Color(0xFF2A120A));
      dotC(c, const Offset(9.4, -5.6), 1.2, const Color(0xFFFFFFFF));
      rp.detail((pa) => pa
        ..moveTo(3, -11)
        ..quadraticBezierTo(7, -13, 12, -11), w: 1.8, col: e.scaleD);
      // Forehead scale marks.
      rp.detail((pa) => pa
        ..moveTo(0, -12)
        ..lineTo(3, -15)
        ..lineTo(6, -12), w: 1, col: e.scaleD);
      if (p.open > .5) {
        rp.fill(ovalP(15, 9.5, 5.2, 3.8), const Color(0xFF4A0E10), const Rect.fromLTRB(10, 6, 21, 14), noHT: true, lw: 1.3);
        fillC(c, ovalP(15, 11.4, 3.2, 1.7), const Color(0xFFFF7A9A));
      } else {
        rp.detail((pa) => pa
          ..moveTo(10, 9)
          ..quadraticBezierTo(15, 12, 20, 8.5), w: 1.4);
        fillC(c, Path()..moveTo(11.6, 10)..lineTo(12.8, 12.6)..lineTo(14, 10.8)..close(), const Color(0xFFFFFAF0));
      }
    }
    rp.fill(_hoodRing, e.hood, const Rect.fromLTRB(-23, -25, 23, 21), shade: e.hoodD, lw: 2.1);
    rp.fill(_hoodPeak, e.hood, const Rect.fromLTRB(-18, -35, 9, -17), shade: e.hoodD, lw: 1.8, noHT: true);
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
        final x = lunge(id, m, q(fu: 1.5, ff: 1.55, lean: .26, rx: 8, open: 1, bu: .6, bf: 2.2), Jt.fHa);
        return MoveAnim(strike(m, I, q(fu: .2, ff: 2.4, lean: .05), x), smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(id, m, q(bu: 1.5, bf: 1.55, baf: 1, lean: .3, rx: 8, open: 1, fu: .5, ff: 2.2), Jt.bHa);
        return MoveAnim(strike(m, I, q(bu: .1, bf: 2.6, baf: 1, lean: .05), x), smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // A big spinning haymaker, tail whipping round.
        final x = lunge(id, m, q(bu: 1.55, bf: 1.6, baf: 1, lean: .55, rx: 12, fu: .3, ff: 2.9, sa: -1.6, open: 1), Jt.bHa);
        return MoveAnim(
            strike(m, I, q(bu: .05, bf: 2.95, baf: 1, lean: -.05, rx: -4, fu: .6, ff: 2.4, sa: 1.0), x, hold: KPose.from(x, sa: -2.2), windAt: .6),
            smear: Jt.bHa, smearA: s - 3, smearB: s + a + 2);
      case 'fireball':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final cup = q(fu: .7, ff: 1.9, bu: .6, bf: 2.0, baf: 1, lean: .1, sx: .5, open: 1, ft: .62, fs: -.1);
        final thr = q(fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.5, baf: 1, lean: .32, sx: 1, open: 1, rx: 4, ft: .7, fs: .05, bt: -.4);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rd(sp * .55)), cup),
          Key(sp, thr, 1),
          Key(sp + 2, KPose.from(thr, sx: 0)),
          Key(sp + rd((t - sp) * .45), KPose.from(thr, sx: 0, lean: .28)),
          Key(mx(t, sp + 4), I),
        ]));
      case 'fireBreath':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final inhale = q(lean: -.26, head: -.3, fu: .3, ff: 1.0, bu: .2, bf: 1.0, baf: 1, ft: .6, fs: -.1, bt: -.4, bs: -.3, sx: .4);
        final blow = q(lean: .45, head: .15, fu: .5, ff: 1.2, bu: .35, bf: 1.0, baf: 1, ft: .8, fs: .05, bt: -.5, bs: -.3, open: 1, sx: .5, rx: 6);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, sp - 5), inhale),
          Key(mx(2, sp - 1), KPose.from(inhale, lean: -.32)),
          Key(sp, blow, 1),
          Key(sp + 15, KPose.from(blow, lean: .5)),
          Key(mx(t, sp + 16), I),
        ]));
      case 'tailSweep':
        final cr = q(lean: .5, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .8, ff: 1.6, bu: .5, bf: 1.9);
        final sweep = KPose.from(cr, sa: -3.0, lean: .6, sx: .8, rx: 4);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 4), KPose.from(cr, sa: .7, lean: .35, sx: .3)),
              Key(s, KPose.from(cr, sa: -.7, sx: .7), 1),
              Key(s + a, sweep, 1),
              Key(s + a + rd(r * .4), KPose.from(cr, sa: -3.0, sx: .2)),
              Key(mx(t, s + a + rd(r * .4) + 1), I),
            ]));
      case 'flameWingHop':
        final cr = q(lean: .45, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .9, ff: 1.7, bu: .6, bf: 1.9, sx: .4);
        final up = q(lean: -.05, head: -.2, fu: 2.9, ff: 3.0, bu: 1.0, bf: 2.0, ft: 1.6, fs: .2, bt: 1.0, bs: -.2, sx: 1, open: 1, rx: 4);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), cr),
              Key(s, up, 1),
              Key(s + a, KPose.from(up, lean: .15, ft: .9, fs: .1, bt: .2, sx: .8)),
              Key(s + a + rd(r * .5), q(lean: .3, ft: .8, fs: -.2, sx: .2)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a);
      case 'dragonInferno':
        final inhale = q(lean: -.3, head: -.32, fu: .2, ff: .9, bu: .1, bf: .9, baf: 1, ft: .75, fs: -.05, bt: -.55, bs: -.3, sx: .6);
        final blow = q(lean: .5, head: .18, fu: .5, ff: 1.2, bu: .3, bf: 1.0, baf: 1, ft: .9, fs: .05, bt: -.6, bs: -.3, open: 1, sx: 1, rx: 6);
        final end = s + a;
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, s - 8), inhale),
          Key(mx(2, s - 1), KPose.from(inhale, lean: -.38, sx: 1)),
          Key(s, blow, 1),
          Key(end, KPose.from(blow, lean: .55)),
          Key(end + rd(r * .5), q(lean: .3, sx: .2)),
          Key(mx(t, end + rd(r * .5) + 1), I),
        ]));
    }
    return null;
  }

  // ================================================================ projectiles

  @override
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) {
    final e = _EM.base;
    if (def.name.startsWith('Fireball')) {
      final big = def.name.contains('EX');
      // Trailing tongue of fire behind a round head.
      c.save();
      c.translate(-5, 0);
      c.rotate(math.pi);
      drawFlame(c, look, 20 + math.sin(age * 1.1) * 3, 6.4, age, 4, outer: e.fire1, mid: e.fire2, core: e.fire3, ink: .8);
      c.restore();
      final r = big ? 8.6 : 7.4;
      if (look == FightLook.painted) {
        drawGlow(c, Offset.zero, r * 2.6, withA(e.fire2, .7));
        dotC(c, Offset.zero, r, withA(e.fire1, .9));
        plusDot(c, Offset.zero, r * .75, withA(e.fire2, .9));
        plusDot(c, Offset.zero, r * .4, withA(e.fire3, 1));
      } else {
        dotC(c, Offset.zero, r, e.fire1);
        dotC(c, Offset.zero, r * .72, e.fire2);
        dotC(c, Offset.zero, r * .38, e.fire3);
        if (look == FightLook.cartoon) ringC(c, Offset.zero, r, .9, kInk);
      }
      final rnd = SRand(age * 3 + 1);
      for (var i = 0; i < 4; i++) {
        dotC(c, Offset(-8 - rnd.next() * 14, (rnd.next() - .5) * 12), .5 + rnd.next() * .9, withA(e.fire3, .9));
      }
      return true;
    }
    if (def.name.startsWith('Fire Breath')) {
      final ex = def.name.contains('EX');
      final grow = math.min(1.0, (age + 2) / 6);
      final fade = age > def.life - 4 ? (def.life - age) / 4 : 1.0;
      for (var i = 0; i < 3; i++) {
        c.save();
        c.translate(-15.5 + i * 1.2, (i - 1) * 2.2 * grow);
        c.rotate((i - 1) * .1 + math.sin(age + i) * .04);
        drawFlame(c, look, (22 + i * 4 + (ex ? 6 : 0)) * grow, (8.2 - i * 1.2 + (ex ? 1.6 : 0)) * grow, age + i * 3, i + 7,
            outer: e.fire1, mid: e.fire2, core: e.fire3, alpha: fade, ink: .8);
        c.restore();
      }
      return true;
    }
    return false;
  }

  // ================================================================ move fx

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final x = FxCtx(cam, s, player);
    final m = x.move;
    if (m == null) return;
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final e = alt ? _EM.alt : _EM.base;
    final sf = x.sf, st = m.startup;
    final hd = fk(x.pose, x.dims);
    Offset mouth() => x.off(x.joint(Jt.head), rotO(const Offset(18, 9) * 1.38, hd.headA));

    switch (m.name) {
      case 'fireball':
        {
          final age = sf - (m.projectiles.isNotEmpty ? m.projectiles.first.frame : st);
          if (age >= 0 && age < 6) {
            x.at(c, x.joint(Jt.fHa), x.u, () => flash(c, look, 16 * (1 - age / 6) + 4, e.fire2, 1 - age / 7, pts: 8));
          }
        }
        break;
      case 'fireBreath':
        {
          final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : st;
          final age = sf - sp + 3;
          if (age >= 0 && age < 18) {
            x.at(c, mouth(), x.k, () {
              c.rotate(.12);
              final k = math.min(1.0, (age + 1) / 4);
              final fade = age > 13 ? (18 - age) / 5 : 1.0;
              for (var i = 0; i < 2; i++) {
                c.save();
                c.rotate((i - .5) * .12);
                drawFlame(c, look, 62 * k, 17 * k, s.frame + i * 2, i + 3, outer: e.fire1, mid: e.fire2, core: e.fire3, alpha: fade, ink: 2.2);
                c.restore();
              }
            });
          }
        }
        break;
      case 'tailSweep':
        {
          final age = sf - st;
          if (age >= -2 && age < m.active + 8) {
            x.at(c, x.world(0, 0), x.k, () {
              final k = math.min(1.0, (age + 2) / math.max(1, m.active));
              final fade = age > m.active ? math.max(0.0, 1 - (age - m.active) / 8) : 1.0;
              for (var i = 0; i < 6; i++) {
                final px = 18 + i * 20.0;
                if (px > 18 + k * 120) continue;
                c.save();
                c.translate(px, -2);
                c.rotate(-math.pi / 2 + math.sin(s.frame * .5 + i) * .15);
                drawFlame(c, look, (13 + (i % 3) * 5) * fade, 4.2, s.frame + i * 2, i, outer: e.fire1, mid: e.fire2, core: e.fire3, alpha: fade, ink: 1.6);
                c.restore();
              }
            });
          }
        }
        break;
      case 'flameWingHop':
        {
          if (sf < st + m.active + 6) {
            final k = sf < st ? .4 : math.max(0.0, 1 - (sf - st - m.active) / 6);
            for (final jt in const [Jt.fAn, Jt.bAn]) {
              x.at(c, x.joint(jt), x.u, () {
                c.rotate(math.pi / 2);
                drawFlame(c, look, 24 * k, 6, s.frame, jt.index, outer: e.fire1, mid: e.fire2, core: e.fire3, ink: 1.6);
              });
            }
            if (sf < 12) x.at(c, x.world(0, 0), x.k, () => puffs(c, look, sf, 12, 8, 36, 14, e.fire2, r0: 2.5, grow: 5));
          }
        }
        break;
      case 'dragonInferno':
        {
          final end = st + m.active;
          if (sf < st) {
            // Sparks drawn into her mouth while she inhales.
            final k = sf / st;
            x.at(c, mouth(), x.k, () {
              final r = SRand(sf * 3 + 5);
              for (var i = 0; i < 9; i++) {
                final a = -.6 + r.next() * 1.4, d = (1 - ((sf * .09 + i / 9) % 1)) * 50 * (.4 + k);
                dotC(c, polar(a, d), 1.6, i.isEven ? e.fire3 : e.fire2);
              }
            });
          } else if (sf < end + 8) {
            final k = math.min(1.0, (sf - st + 3) / 8);
            final fade = sf > end ? (end + 8 - sf) / 8 : 1.0;
            x.at(c, mouth(), x.k, () {
              c.rotate(.06);
              final len = 300 * k;
              for (var i = 0; i < 4; i++) {
                c.save();
                c.translate(0, (i - 1.5) * 3);
                c.rotate((i - 1.5) * .045);
                drawFlame(c, look, len * (1 - i * .06), (30 - i * 3) * k, s.frame + i * 3, i + 2, outer: e.fire1, mid: e.fire2, core: e.fire3, alpha: fade, ink: 2.6);
                c.restore();
              }
              final r = SRand(s.frame ~/ 2 + 3);
              for (var i = 0; i < 10; i++) {
                final px = r.next() * len, py = (r.next() - .5) * 46 * k;
                dotC(c, Offset(px, py), 1.2 + r.next() * 2, withA(e.fire3, fade * .9));
              }
            });
          }
        }
        break;
    }
  }
}
