// RAZZ (id 6): mandrill showman. The red-and-blue face, a sequined purple
// showman jacket with gold trim open over the chest, white gloves, a flashy
// rushdown stance with flair.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import 'cast_art.dart';
import 'monkey_kit.dart';

class RazzPal {
  final Color fur, furD, furL, chest, skin, red, redD, blue, blueD, blueL, beard, beardD, jacket, jacketD, jacketL,
      gold, goldD, pants, pantsD, glove, shoe, eye, teeth;
  const RazzPal({
    required this.fur, required this.furD, required this.furL, required this.chest, required this.skin,
    required this.red, required this.redD, required this.blue, required this.blueD, required this.blueL,
    required this.beard, required this.beardD, required this.jacket, required this.jacketD, required this.jacketL,
    required this.gold, required this.goldD, required this.pants, required this.pantsD, required this.glove,
    required this.shoe, required this.eye, required this.teeth,
  });
  static final RazzPal base = RazzPal(
      fur: hex(0x7a6840), furD: hex(0x4a3d22), furL: hex(0x9c8858), chest: hex(0xc2b184), skin: hex(0x3a2a3c),
      red: hex(0xea3a3c), redD: hex(0xa8202a), blue: hex(0x3f72e6), blueD: hex(0x233f9c), blueL: hex(0x86a8ff),
      beard: hex(0xffb42e), beardD: hex(0xd97a1a), jacket: hex(0x8f33d6), jacketD: hex(0x4d1a86),
      jacketL: hex(0xc984ff), gold: hex(0xf5c231), goldD: hex(0xb98414), pants: hex(0x241a38), pantsD: hex(0x120c20),
      glove: hex(0xfaf7ee), shoe: hex(0xf6f1e6), eye: hex(0xffb23a), teeth: hex(0xfffaf0));
  /// Mirror match: emerald jacket with silver trim, navy pants.
  static final RazzPal alt = RazzPal(
      fur: hex(0x7a6840), furD: hex(0x4a3d22), furL: hex(0x9c8858), chest: hex(0xc2b184), skin: hex(0x3a2a3c),
      red: hex(0xea3a3c), redD: hex(0xa8202a), blue: hex(0x3f72e6), blueD: hex(0x233f9c), blueL: hex(0x86a8ff),
      beard: hex(0xffb42e), beardD: hex(0xd97a1a), jacket: hex(0x16b57e), jacketD: hex(0x0a6a4a),
      jacketL: hex(0x6df0bd), gold: hex(0xe3e9f2), goldD: hex(0x8a93a6), pants: hex(0x1a2748), pantsD: hex(0x0c1428),
      glove: hex(0xfaf7ee), shoe: hex(0x2a2630), eye: hex(0xffb23a), teeth: hex(0xfffaf0));
}

final KPose razzIdle =
    KPose.from(pIdle, lean: .14, head: -.14, fu: .55, ff: 2.55, bu: .6, bf: 2.0, ft: .5, fs: -.06, bt: -.3, bs: -.5);

final Path _rzTorso = pathOf((p) => p
  ..moveTo(-14, 0)
  ..cubicTo(-21, -10, -23, -27, -19, -38)
  ..cubicTo(-15, -48, -3, -52, 6, -50)
  ..cubicTo(16, -48, 22, -40, 21, -30)
  ..cubicTo(20, -19, 16, -8, 13, 0));
final Path _rzJacket = pathOf((p) => p
  ..moveTo(-20, -38)
  ..cubicTo(-16, -48, -5, -53, 5, -51)
  ..lineTo(7, -44)
  ..cubicTo(4, -34, 6, -16, 9, -2)
  ..lineTo(11, 12)
  ..cubicTo(2, 15, -14, 15, -26, 11)
  ..cubicTo(-22, -4, -25, -26, -20, -38));
final Path _rzLapel = pathOf((p) => p
  ..moveTo(5, -51)
  ..lineTo(10, -46)
  ..cubicTo(8, -34, 10, -16, 13, -2)
  ..lineTo(8, -1)
  ..cubicTo(4, -16, 3, -34, 5, -51));
final Path _rzFurHead = () {
  final p = Path()..moveTo(-16, 6);
  p.cubicTo(-22, -6, -14, -20, -2, -22);
  p.cubicTo(8, -23, 17, -17, 19, -8);
  p.lineTo(17, 2);
  p.cubicTo(15, 12, 6, 17, -4, 16);
  // jagged fur along the nape
  p.lineTo(-9, 21);
  p.lineTo(-11, 14);
  p.lineTo(-16, 17);
  p.close();
  return p;
}();
final Path _rzCrest = pathOf((p) => p
  ..moveTo(-12, -16)
  ..lineTo(-14, -26)
  ..lineTo(-8, -24)
  ..lineTo(-7, -35)
  ..lineTo(-1, -29)
  ..lineTo(3, -37)
  ..lineTo(6, -29)
  ..lineTo(12, -31)
  ..lineTo(12, -22)
  ..lineTo(16, -17)
  ..cubicTo(8, -21, -2, -21, -12, -16));
final Path _rzMuzzle = pathOf((p) => p
  ..moveTo(3, -10)
  ..cubicTo(14, -15, 34, -12, 45, -6)
  ..cubicTo(51, -2, 51, 7, 45, 10)
  ..cubicTo(34, 14, 16, 15, 8, 12)
  ..cubicTo(2, 8, 1, -4, 3, -10));
final Path _rzRed = pathOf((p) => p
  ..moveTo(5, -11)
  ..cubicTo(18, -17, 38, -13, 48, -6)
  ..cubicTo(52, -2, 52, 6, 47, 8)
  ..cubicTo(43, 4, 32, -3, 8, -5));
final Path _rzCheek = pathOf((p) => p
  ..moveTo(10, -1)
  ..cubicTo(22, -7, 38, -2, 42, 5)
  ..cubicTo(38, 12, 24, 14, 13, 11)
  ..cubicTo(7, 8, 7, 2, 10, -1));
final Path _rzBeard = pathOf((p) => p
  ..moveTo(5, 11)
  ..lineTo(7, 20)
  ..lineTo(12, 15)
  ..lineTo(15, 26)
  ..lineTo(20, 17)
  ..lineTo(24, 27)
  ..lineTo(29, 17)
  ..lineTo(34, 23)
  ..lineTo(38, 11)
  ..cubicTo(26, 16, 14, 16, 5, 11));
final Path _rzShoe = pathOf((p) => p
  ..moveTo(-7, -9)
  ..cubicTo(-2, -12, 6, -9, 10, -4)
  ..lineTo(21, -2)
  ..cubicTo(25, 0, 25, 5, 21, 6)
  ..lineTo(-7, 6)
  ..cubicTo(-10, 4, -10, -5, -7, -9));

class RazzArt extends CastArt {
  const RazzArt();

  @override
  int get id => 6;
  @override
  RigDims get dims => const RigDims(6, 50, 31, 30, 32, 32, 1.3, 10, 6, 26, 8);
  @override
  KPose get idle => razzIdle;
  @override
  KPalette get palette => _pal(false);
  @override
  KPalette get altPalette => _pal(true);
  @override
  double get portraitWidth => 135;

  static KPalette _pal(bool alt) {
    final m = alt ? RazzPal.alt : RazzPal.base;
    return KPalette(
        skin: m.fur, hair: m.furD, tip: m.furL, vest: m.jacket, tank: m.jacketD, pants: m.pants, pad: m.gold,
        wrap: m.glove, shoe: m.shoe, sole: m.pantsD, accent: m.gold);
  }

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final I = razzIdle;
    return (
      KPose.from(I, fu: -.4, ff: .2, bu: -.5, bf: .3, lean: .02, rx: -3, head: -.25),
      KPose.from(I, fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.5, lean: .4, rx: 12, baf: 1),
      KPose.from(I, fu: 2.2, ff: 2.9, bu: .5, bf: 1.9, lean: .1, head: -.2),
    );
  }

  // ---------------------------------------------------------------- paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final k = Ink.of(rp);
    final m = alt ? RazzPal.alt : RazzPal.base;
    final c = rp.c;
    // A short stubby tail.
    final tail = bez(pt(-10, -2), pt(-20, 2), pt(-24, -6 + math.sin(frame * .1) * 2), pt(-22, -12), 6);
    k.tube(tail, 4.2, 2.6, m.furD, lw: 1.8);
    if (p.baf < .5) _arm(k, j, true, p, m);
    if (p.blf < .5) _leg(k, j, true, p, m);
    rp.fill(rrPath(-15, -7, 30, 24, 9), m.pants, const Rect.fromLTRB(-15, -7, 15, 17), shade: m.pantsD);
    c.save();
    c.rotate(p.lean);
    rp.fill(_rzTorso, m.fur, const Rect.fromLTRB(-23, -52, 22, 0), shade: m.furD);
    rp.fill(ellP(12, -24, 8, 20), m.chest, const Rect.fromLTRB(4, -44, 20, -4), noHT: true, lw: 1.4);
    rp.detail((pa) {
      pa.moveTo(10, -40);
      pa.quadraticBezierTo(15, -36, 19, -39);
      pa.moveTo(10, -30);
      pa.quadraticBezierTo(15, -26, 19, -29);
    }, w: 1.1, col: rp.paint ? const Color(0x66281C28) : m.furL);
    // The jacket: open at the front, tails flaring behind, gold trim and sequins.
    rp.fill(_rzJacket, m.jacket, const Rect.fromLTRB(-26, -53, 11, 15), shade: m.jacketD, lw: 2.2);
    rp.fill(_rzLapel, m.jacketL, const Rect.fromLTRB(3, -52, 13, 0), noHT: true, lw: 1.6);
    rp.detail((pa) => pa
      ..moveTo(5, -51)
      ..cubicTo(3, -34, 4, -16, 8, -1), w: 2.2, col: m.gold);
    rp.detail((pa) => pa
      ..moveTo(-26, 11)
      ..cubicTo(-14, 15, 2, 15, 11, 12), w: 2.2, col: m.gold);
    if (!k.sil) {
      for (var i = 0; i < 12; i++) {
        final x = -21 + hash01(i, 3) * 25, y = -44 + hash01(i, 9) * 54;
        final tw = .5 + .5 * math.sin(frame * .22 + i * 1.7);
        if (i % 4 == 0) {
          rp.fill(sparkle(x, y, 2.6 + tw * 1.4), const Color(0xFFFFFFFF), Rect.fromLTRB(x - 4, y - 4, x + 4, y + 4), noHT: true, lw: .6);
        } else {
          k.dot(x, y, 1.1 + tw * .5, i.isEven ? m.gold : const Color(0xFFFFFFFF));
        }
      }
    }
    // Belt with a showy buckle.
    rp.fill(rrPath(-16, -8, 33, 6, 2), m.pantsD, const Rect.fromLTRB(-16, -8, 17, -2), noHT: true, lw: 1.6);
    rp.fill(rrPath(5, -9, 9, 8, 2), m.gold, const Rect.fromLTRB(5, -9, 14, -1), noHT: true, lw: 1.5, shade: m.goldD);
    // Bow tie.
    final tie = pathOf((q) => q
      ..moveTo(13, -47)
      ..lineTo(21, -52)
      ..lineTo(21, -42)
      ..close());
    rp.fill(tie, m.red, const Rect.fromLTRB(12, -53, 22, -41), noHT: true, lw: 1.5);
    c.restore();
    _leg(k, j, false, p, m);
    if (p.blf >= .5) _leg(k, j, true, p, m);
    _head(k, j, p, m);
    if (p.baf >= .5) _arm(k, j, true, p, m);
    _arm(k, j, false, p, m);
  }

  void _arm(Ink k, Joints j, bool b, KPose p, RazzPal m) {
    final rp = k.r;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final jc = b ? dk(m.jacket, .3) : m.jacket;
    rp.limb(sh, el, 9.2, 7.6, jc, bulge: 2, shade: m.jacketD);
    rp.fill(ellP(sh.dx, sh.dy - 1, 10.5, 8.6, -.2), b ? dk(m.gold, .3) : m.gold,
        Rect.fromLTRB(sh.dx - 11, sh.dy - 10, sh.dx + 11, sh.dy + 8), lw: 1.8, noHT: true, shade: m.goldD);
    rp.limb(el, wr, 7.6, 6.2, jc, bulge: 1.6, shade: m.jacketD);
    rp.limb(lerpO(el, wr, .66), wr, 7.4, 7, b ? dk(m.gold, .3) : m.gold, noHT: true, lw: 1.7, shade: m.goldD);
    if (p.open > .5) {
      k.openHand(wr, el, m.glove, s: 1.15, back: b);
    } else {
      k.fist(wr, el, m.glove, w: 15, h: 14, back: b);
    }
  }

  void _leg(Ink k, Joints j, bool b, KPose p, RazzPal m) {
    final rp = k.r;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    final pc = b ? dk(m.pants, .3) : m.pants;
    rp.limb(hip, kn, 10, 8.4, pc, bulge: 1.8, shade: m.pantsD);
    rp.limb(kn, an, 8.4, 7.8, pc, bulge: 1.2, shade: m.pantsD);
    // Gold side stripe down the leg.
    rp.detail((pa) {
      final a = lerpO(hip, kn, .1), z = lerpO(kn, an, .85);
      pa.moveTo(a.dx - 1, a.dy);
      pa.lineTo(kn.dx - 1, kn.dy);
      pa.lineTo(z.dx - 1, z.dy);
    }, w: 2.4, col: b ? dk(m.gold, .3) : m.gold);
    final shin = b ? p.bs : p.fs, off = b ? p.bfa : p.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
    final c = rp.c;
    c.save();
    c.translate(an.dx, an.dy + 4);
    c.rotate(planted ? 0 : -shin + off);
    rp.fill(_rzShoe, b ? dk(m.shoe, .3) : m.shoe, const Rect.fromLTRB(-10, -12, 26, 6), lw: 2, shade: dk(m.shoe, .35));
    rp.fill(rrPath(-8, 3, 32, 3.4, 1.5), m.gold, const Rect.fromLTRB(-8, 3, 24, 7), noHT: true, lw: 1.2);
    c.restore();
  }

  void _head(Ink k, Joints j, KPose p, RazzPal m) {
    final rp = k.r, c = rp.c;
    rp.limb(j.neck, Offset(j.head.dx - 5, j.head.dy + 11), 10, 8.6, m.furD, bulge: 1);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.1, 1.1);
    rp.fill(ellP(-6, 4, 3.6, 4.6), m.furD, const Rect.fromLTRB(-10, -2, -2, 10), lw: 1.6, noHT: true);
    // Furry cranium: a jagged ruff, a yellow-tan crest on top.
    rp.fill(_rzFurHead, m.fur, const Rect.fromLTRB(-22, -26, 20, 20), shade: m.furD);
    rp.fill(_rzCrest, m.furL, const Rect.fromLTRB(-14, -38, 16, -14), noHT: true, lw: 1.8, shade: m.fur);
    rp.detail((pa) {
      for (var i = 0; i < 7; i++) {
        pa.moveTo(-16 + i * 4.2, -14 + (i % 2) * 2);
        pa.lineTo(-18 + i * 4.2, -7 + (i % 2) * 2);
      }
      pa.moveTo(-8, -28);
      pa.lineTo(-6, -20);
      pa.moveTo(0, -31);
      pa.lineTo(1, -23);
    }, w: 1.1, col: rp.paint ? withA(m.furD, .7) : m.furD);
    if (!k.sil) {
      rp.fill(_rzBeard, m.beard, const Rect.fromLTRB(5, 10, 36, 28), noHT: true, lw: 1.6, shade: m.beardD);
      // The long muzzle is the dominant shape.
      rp.fill(_rzMuzzle, m.skin, const Rect.fromLTRB(1, -16, 50, 16), lw: 1.9);
      rp.fill(_rzCheek, m.blue, const Rect.fromLTRB(8, -9, 42, 15), noHT: true, lw: 1.5, shade: m.blueD);
      rp.detail((pa) {
        for (var i = 0; i < 5; i++) {
          pa.moveTo(13 + i * .6, -2 + i * 3.3);
          pa.quadraticBezierTo(26, -5 + i * 3.1, 40 - i * 1.2, 1 + i * 2.6);
        }
      }, w: 1.4, col: m.blueD);
      rp.detail((pa) => pa
        ..moveTo(16, -3.6)
        ..quadraticBezierTo(28, -7, 38, -1.4), w: 1.2, col: m.blueL);
      rp.fill(_rzRed, m.red, const Rect.fromLTRB(5, -18, 52, 9), noHT: true, lw: 1.5, shade: m.redD);
      k.dot(46.5, 2.2, 6.4, m.red);
      k.dot(44.5, .4, 1.6, const Color(0x66FFFFFF));
      k.dot(48.6, 3.4, 1.3, m.redD);
      k.dot(46, 5.2, 1.1, m.redD);
      // Small deep-set eye under a heavy brow.
      k.dot(9.5, -5.5, 3, const Color(0xFFFFF6E0));
      k.dot(10.2, -5.4, 2.1, m.eye);
      k.dot(10.5, -5.4, 1.1, const Color(0xFF1A0E08));
      rp.detail((pa) => pa
        ..moveTo(2, -8.5)
        ..quadraticBezierTo(9, -13, 17, -7.5), w: 3.6, col: m.furD);
      // A wide grin along the jaw.
      final grin = pathOf((q) => q
        ..moveTo(18, 9)
        ..quadraticBezierTo(32, 13.5, 43, 7)
        ..quadraticBezierTo(32, 10.2, 18, 9));
      rp.fill(grin, m.teeth, const Rect.fromLTRB(17, 6, 44, 14), noHT: true, lw: 1.2);
    }
    c.restore();
  }

  // ---------------------------------------------------------------- moves

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = razzIdle;
    final q = posing(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    switch (m.name) {
      case 'standLight':
        final x = lunge(6, m, q(fu: 1.5, ff: 1.57, lean: .28, rx: 9, head: -.1), Jt.fHa);
        return MoveAnim(strike(m, q(fu: .3, ff: 2.5), x, I, hold: KPose.from(x, fu: 1.42)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(6, m, q(bu: 1.5, bf: 1.57, baf: 1, lean: .3, rx: 9, head: -.1, fu: .3, ff: 2.6), Jt.bHa);
        return MoveAnim(strike(m, q(bu: .2, bf: 2.5, baf: 1), x, I, hold: KPose.from(x, bu: 1.42)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // A theatrical overhand with a flourish behind.
        final x = lunge(6, m, q(bu: 1.55, bf: 1.6, baf: 1, lean: .5, rx: 14, fu: -.4, ff: .3, head: -.1), Jt.bHa);
        return MoveAnim(
            strike(m, q(bu: .05, bf: 2.95, baf: 1, lean: -.05, rx: -4, fu: .6, ff: 2.4), x, I,
                hold: KPose.from(x, bu: 1.5), windAt: .55),
            smear: Jt.bHa, smearA: s - 3, smearB: s + a + 2);
      case 'showboat':
        // Arms flung wide, chest out, the crowd roars.
        final wind = q(fu: -.2, ff: .5, bu: -.3, bf: .6, lean: .02, rx: -4, head: -.1, ft: .4, bt: -.25, bs: -.4);
        final A = q(fu: 2.3, ff: 2.9, bu: 1.4, bf: 1.0, lean: -.08, head: -.3, open: 1, baf: 1, rx: 3);
        final B = q(fu: 1.4, ff: 1.0, bu: 2.3, bf: 2.9, lean: -.08, head: -.3, open: 1, baf: 1, rx: 3);
        final C = q(fu: 2.6, ff: 3.0, bu: 2.5, bf: 3.0, lean: -.12, head: -.35, open: 1, baf: 1, rx: 4);
        return MoveAnim(multiHit(m, I, wind, m.windows.length > 1 ? [A, B, C] : [A], KPose.from(A, lean: -.02), preAt: mx(1, s - 3)),
            smear: Jt.fHa, smearA: s - 1, smearB: s + a);
      case 'rumbaRush':
        final crouch = q(lean: .62, fu: .3, ff: 2.6, bu: .1, bf: 2.7, ft: .85, fs: -.2, bt: -.5, bs: -.7, rx: -3);
        final pf = q(fu: 1.5, ff: 1.57, bu: .2, bf: 2.8, lean: .75, rx: 12, ft: .9, fs: -.2, bt: -.6, bs: -.5);
        final pb = q(bu: 1.5, bf: 1.57, baf: 1, fu: .3, ff: 2.8, lean: .75, rx: 12, ft: .9, fs: -.2, bt: -.6, bs: -.5);
        final end = q(fu: 1.1, ff: 1.0, bu: 1.0, bf: .9, lean: .9, rx: 16, baf: 1, ft: .9, bt: -.6, bs: -.5);
        final ws = m.windows;
        final poses = <KPose>[for (var i = 0; i < ws.length; i++) i == ws.length - 1 ? end : (i.isEven ? pf : pb)];
        return MoveAnim(multiHit(m, I, crouch, poses, q(lean: .4, fu: .9, ff: 2.2), preAt: mx(1, s - 3)),
            smear: Jt.fHa, smearA: s - 1, smearB: s + a);
      case 'cartwheel':
        final spread = q(fu: 2.9, ff: 3.0, bu: 2.9, bf: 3.0, ft: 1.75, fs: 1.75, bt: -1.75, bs: -1.75, baf: 1, lean: .1, rx: 4);
        final end = m.windows.isEmpty ? s + a : m.windows.last.end;
        final turns = math.max(2.0, m.windows.length.toDouble());
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), q(lean: .8, fu: 1.4, ff: .4, bu: 1.3, bf: .3, ft: .9, bt: -.5, bs: -.5, baf: 1)),
              Key(s, KPose.from(spread, spin: 0), 1),
              Key(end, KPose.from(spread, spin: -math.pi * 2 * turns, rx: 10), 2),
              Key(end + rd(r * .4), q(lean: .5, ft: 1.0, fs: -.3, bt: .2, bs: -.9, fu: .8, ff: 2.0, spin: -math.pi * 2 * turns)),
              Key(mx(t, end + rd(r * .4) + 1), KPose.from(I, spin: -math.pi * 2 * turns)),
            ]),
            smear: Jt.fAn, smearA: s - 1, smearB: end);
      case 'risingFlip':
        final crouch = q(lean: .4, ft: .95, fs: -.35, bt: .2, bs: -.95, fu: .2, ff: 2.2, bu: .1, bf: 2.4);
        final kick = q(lean: -.3, ft: 1.7, fs: 1.6, bt: 1.0, bs: -.1, fu: 1.2, ff: 2.4, bu: 1.0, bf: 2.5, spin: -.35);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 2), crouch),
              Key(s, kick, 1),
              Key(s + rd(a * .5), KPose.from(kick, spin: -math.pi, tuck: .55, ft: 2.2, fs: .4, bt: 2.0, bs: -.3), 2),
              Key(s + a, KPose.from(kick, spin: -math.pi * 2 + .3, tuck: .2, ft: 1.4, fs: .6), 2),
              Key(mx(t, s + a + 1), KPose.from(q(lean: .15, ft: .6, fs: .1, bt: .1, bs: -.3), spin: -math.pi * 2)),
            ]),
            smear: Jt.fAn, smearA: s - 1, smearB: s + a);
      case 'grandFinale':
        final wind = q(fu: 2.9, ff: 3.1, bu: 2.8, bf: 3.0, lean: -.1, head: -.3, rx: -5, open: 1, baf: 1);
        final pf = q(fu: 1.5, ff: 1.57, bu: .3, bf: 2.7, lean: .55, rx: 12, baf: 1, ft: .8, fs: -.2, bt: -.55, bs: -.5);
        final pb = q(bu: 1.5, bf: 1.57, fu: .3, ff: 2.7, lean: .55, rx: 12, baf: 1, ft: .8, fs: -.2, bt: -.55, bs: -.5);
        final fin = q(fu: 2.5, ff: 3.0, bu: 2.4, bf: 2.9, lean: -.12, head: -.35, rx: 10, open: 1, baf: 1);
        final ws = m.windows;
        final poses = <KPose>[for (var i = 0; i < ws.length; i++) i == ws.length - 1 ? fin : (i.isEven ? pf : pb)];
        return MoveAnim(multiHit(m, I, wind, poses, q(lean: .1, fu: 2.2, ff: 2.9, bu: 2.0, bf: 2.8, open: 1, baf: 1), preAt: mx(1, s - 3)),
            smear: Jt.fHa, smearA: s - 1, smearB: s + a);
    }
    return null;
  }

  // ---------------------------------------------------------------- fx

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final f = s.p[player];
    if (f.state != St.move) return;
    final def = s.chars[player];
    if (f.moveId < 0 || f.moveId >= def.moves.length) return;
    final m = def.moves[f.moveId];
    final sf = f.sf;
    final foot = cam.toScreen(f.x / unitsPerPx, f.y / unitsPerPx);
    final u = cam.scale * 0.88 * dims.cs / csScale;
    final fill = Paint()..isAntiAlias = true;
    final ln = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void burst(Offset o, double k, int n, int seed, double rad) {
      for (var i = 0; i < n; i++) {
        final a = hash01(i, seed) * math.pi * 2;
        final d = (.4 + hash01(i, seed + 5) * .6) * rad * easeOut(k);
        final r0 = (3 + hash01(i, seed + 9) * 4) * (1 - k) * u;
        final gold = i.isEven ? const Color(0xFFFFD84A) : const Color(0xFFFFFFFF);
        final p = Offset(o.dx + math.cos(a) * d, o.dy + math.sin(a) * d * .8);
        c.save();
        c.translate(p.dx, p.dy);
        c.drawPath(sparkle(0, 0, math.max(.1, r0 * 2)), fill..color = gold.withValues(alpha: 1 - k));
        c.restore();
      }
    }

    switch (m.name) {
      case 'showboat':
        if (sf >= m.startup - 2 && sf < m.startup + 20) {
          final k = (sf - m.startup + 2) / 22;
          burst(Offset(foot.dx + f.face * 40 * u, foot.dy - 100 * u), k, 14, f.moveId, 90 * u);
        }
        break;
      case 'rumbaRush':
      case 'cartwheel':
        // Purple streaks trailing behind him.
        if (sf >= m.startup && sf < m.startup + m.active + 6) {
          final low = m.name == 'cartwheel';
          for (var i = 0; i < 4; i++) {
            final y = foot.dy - (low ? 18 + i * 14 : 60 + i * 16) * u;
            final len = (50 + hash01(i, sf ~/ 2) * 50) * u;
            c.drawLine(Offset(foot.dx - f.face * 30 * u, y), Offset(foot.dx - f.face * (30 * u + len), y),
                ln..strokeWidth = (4 - i * .6) * u..color = Color.fromRGBO(201, 132, 255, .7 - i * .12));
          }
        }
        break;
      case 'grandFinale':
        if (sf >= 1 && sf < m.startup + m.active + 10) {
          final k = clamp01(sf / (m.startup + m.active + 10));
          final o = Offset(foot.dx + f.face * 40 * u, foot.dy - 90 * u);
          if (look == FightLook.painted) {
            drawGlow(c, o, 150 * u, Color.fromRGBO(210, 140, 255, .26 * (1 - k * .5)));
          } else {
            c.save();
            c.translate(foot.dx, foot.dy);
            c.scale(1, .22);
            c.drawCircle(Offset.zero, (60 + 8 * math.sin(sf * .6)) * u, ln..strokeWidth = 3 * u..color = const Color(0xCCC984FF));
            c.restore();
          }
          if (sf % 3 == 0 || sf < 6) burst(o, (sf % 12) / 12.0, 10, sf ~/ 3, 110 * u);
        }
        break;
      case 'risingFlip':
        if (sf >= m.startup && sf < m.startup + m.active + 4) {
          final k = (sf - m.startup) / (m.active + 4);
          c.drawArc(Rect.fromCenter(center: Offset(foot.dx + f.face * 4 * u, foot.dy - 56 * u), width: 120 * u, height: 130 * u),
              f.face > 0 ? math.pi * .55 : -math.pi * .55 - math.pi * 1.1, math.pi * 1.1 * (1 - k * .3), false,
              ln..strokeWidth = (6 - 4 * k) * u..color = Color.fromRGBO(255, 230, 140, .9 - k * .6));
        }
        break;
    }
  }
}
