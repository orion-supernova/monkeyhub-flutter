// BRUNO (id 4): silverback gorilla brawler. Huge shoulders and forearms, silver
// saddle, a thick gold chain, taped wrists, loose cargo shorts. Chest-drum
// counter pose; hammer fists for his light and heavy normals.
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

class BrunoPal {
  final Color fur, furD, furL, skin, skinL, tape, shorts, shortsD, belt, gold, goldD, eye, teeth, mouth;
  const BrunoPal({
    required this.fur, required this.furD, required this.furL, required this.skin, required this.skinL,
    required this.tape, required this.shorts, required this.shortsD, required this.belt, required this.gold,
    required this.goldD, required this.eye, required this.teeth, required this.mouth,
  });
  static final BrunoPal base = BrunoPal(
      fur: hex(0xa3a9b6), furD: hex(0x676d7c), furL: hex(0xcdd2dc), skin: hex(0x34303c), skinL: hex(0x5a5465),
      tape: hex(0xf2eee4), shorts: hex(0x727a49), shortsD: hex(0x4a512c), belt: hex(0x2b221b), gold: hex(0xf5c231),
      goldD: hex(0xb98414), eye: hex(0xe9a23a), teeth: hex(0xfffaf0), mouth: hex(0x7a1e2c));
  /// Mirror match: a warm brown-backed cousin in rust shorts with silver chain and black tape.
  static final BrunoPal alt = BrunoPal(
      fur: hex(0x9a7660), furD: hex(0x5e4234), furL: hex(0xc79c80), skin: hex(0x3a2d2a), skinL: hex(0x5f4a42),
      tape: hex(0x2c2833), shorts: hex(0xc4572b), shortsD: hex(0x85330f), belt: hex(0x2b221b), gold: hex(0xe3e9f2),
      goldD: hex(0x8a93a6), eye: hex(0xe9a23a), teeth: hex(0xfffaf0), mouth: hex(0x7a1e2c));
}

final KPose brunoIdle =
    KPose.from(pIdle, lean: .34, head: -.1, fu: .6, ff: 2.4, bu: .35, bf: 2.65, ft: .62, fs: -.1, bt: -.38, bs: -.42);

final Path _bnTorso = pathOf((p) => p
  ..moveTo(-18, 0)
  ..cubicTo(-32, -12, -39, -34, -33, -52)
  ..cubicTo(-28, -66, -8, -73, 8, -71)
  ..cubicTo(26, -69, 38, -55, 37, -38)
  ..cubicTo(36, -22, 28, -8, 22, 0));
final Path _bnChest = pathOf((p) => p
  ..moveTo(12, -65)
  ..cubicTo(25, -62, 34, -52, 33, -38)
  ..cubicTo(32, -24, 26, -9, 20, 0)
  ..lineTo(-1, 0)
  ..cubicTo(-6, -22, -1, -52, 12, -65));
final Path _bnSaddle = pathOf((p) => p
  ..moveTo(-34, -50)
  ..cubicTo(-28, -66, -8, -73, 8, -71)
  ..cubicTo(18, -70, 25, -66, 29, -60)
  ..cubicTo(12, -56, 2, -48, -2, -30)
  ..cubicTo(-6, -16, -12, -6, -20, 0)
  ..cubicTo(-30, -12, -38, -34, -34, -50));
final Path _bnFoot = pathOf((p) => p
  ..moveTo(-10, -9)
  ..cubicTo(-4, -13, 6, -10, 10, -5)
  ..lineTo(23, -3.5)
  ..cubicTo(28, -2, 28, 5, 23, 6)
  ..lineTo(-10, 6)
  ..cubicTo(-14, 4, -14, -5, -10, -9));
final Path _bnHead = pathOf((p) => p
  ..moveTo(-16, 5)
  ..cubicTo(-20, -8, -13, -22, -3, -26)
  ..cubicTo(8, -28, 17, -19, 19, -9)
  ..cubicTo(21, -2, 20, 5, 18, 11)
  ..cubicTo(14, 18, 2, 20, -6, 17)
  ..cubicTo(-12, 14, -15, 10, -16, 5));
final Path _bnCrest = pathOf((p) => p
  ..moveTo(-15, -12)
  ..cubicTo(-16, -30, -5, -44, 6, -40)
  ..cubicTo(12, -37, 16, -28, 17, -17)
  ..cubicTo(9, -24, -4, -22, -15, -12));
final Path _bnFace = pathOf((p) => p
  ..moveTo(3, -11)
  ..cubicTo(10, -14, 18, -12, 22, -7)
  ..cubicTo(26, -2, 27, 6, 24, 12)
  ..cubicTo(21, 17, 12, 19, 6, 17)
  ..cubicTo(1, 14, 0, 6, 1, -2)
  ..cubicTo(1, -7, 2, -10, 3, -11));
final Path _bnBrow = pathOf((p) => p
  ..moveTo(2, -9)
  ..cubicTo(8, -17, 20, -15, 25, -7)
  ..cubicTo(20, -5, 11, -3, 3, 1));
final Path _bnMuzzle = ellP(18.5, 7.5, 8, 7);

class BrunoArt extends CastArt {
  const BrunoArt();

  @override
  int get id => 4;
  @override
  RigDims get dims => const RigDims(4, 60, 35, 33, 30, 30, 1.66, 16, 9, 15, 9);
  @override
  KPose get idle => brunoIdle;
  @override
  KPalette get palette => _pal(false);
  @override
  KPalette get altPalette => _pal(true);
  @override
  double get portraitWidth => 175;

  static KPalette _pal(bool alt) {
    final m = alt ? BrunoPal.alt : BrunoPal.base;
    return KPalette(
        skin: m.fur, hair: m.furD, tip: m.furL, vest: m.shorts, tank: m.skin, pants: m.shorts, pad: m.gold,
        wrap: m.tape, shoe: m.skin, sole: m.belt, accent: m.gold);
  }

  /// Hunched: every generic pose leans into the shoulders a little more.
  @override
  KPose rebase(KPose k) => k.tuck > .5 || k.spin != 0 ? k : KPose.from(k, lean: k.lean + .22);

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final I = brunoIdle;
    return (
      KPose.from(I, fu: 2.9, ff: 3.1, bu: 2.8, bf: 3.1, lean: -.05, rx: -4, sa: 1),
      KPose.from(I, fu: 1.1, ff: .9, bu: 1.0, bf: .85, lean: .8, rx: 14, baf: 1, sa: 1),
      KPose.from(I, fu: .9, ff: 2.2, bu: .8, bf: 2.35, baf: 1, lean: .5),
    );
  }

  // ---------------------------------------------------------------- paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final k = Ink.of(rp);
    final m = alt ? BrunoPal.alt : BrunoPal.base;
    final c = rp.c;
    if (p.baf < .5) _arm(k, j, true, p, m);
    if (p.blf < .5) _leg(k, j, true, p, m);
    // Shorts on the hips, belted.
    rp.fill(rrPath(-20, -10, 44, 30, 12), m.shorts, const Rect.fromLTRB(-20, -10, 24, 20), shade: m.shortsD);
    c.save();
    c.rotate(p.lean);
    rp.fill(_bnTorso, m.skin, const Rect.fromLTRB(-39, -73, 38, 0), shade: dk(m.skin, .4));
    rp.fill(_bnChest, m.skinL, const Rect.fromLTRB(-2, -65, 34, 0), noHT: true, lw: 1.6);
    rp.fill(_bnSaddle, m.fur, const Rect.fromLTRB(-39, -73, 30, 0), shade: m.furD, lw: 2.2);
    rp.detail((pa) {
      pa.moveTo(10, -50);
      pa.quadraticBezierTo(20, -44, 31, -50);
      pa.moveTo(8, -34);
      pa.quadraticBezierTo(20, -28, 30, -34);
      pa.moveTo(10, -18);
      pa.quadraticBezierTo(18, -14, 24, -18);
    }, w: 1.3, col: rp.paint ? const Color(0x66141018) : m.skin);
    rp.detail((pa) {
      for (final y in const [-60.0, -48.0, -36.0, -24.0]) {
        pa.moveTo(-24, y);
        pa.lineTo(-20, y + 5);
      }
    }, w: 1.2, col: rp.paint ? withA(m.furD, .6) : m.furD);
    // Belt with a gold buckle.
    rp.fill(rrPath(-21, -12, 46, 11, 3), m.belt, const Rect.fromLTRB(-21, -12, 25, -1), noHT: true, lw: 1.8);
    rp.fill(rrPath(10, -12, 11, 11, 2.5), m.gold, const Rect.fromLTRB(10, -12, 21, -1), noHT: true, lw: 1.6, shade: m.goldD);
    // The chain: a thick gold rope across the chest and a round medallion.
    final chain = bez(pt(-4, -70), pt(6, -50), pt(14, -38), pt(25, -33), 14);
    k.tube(chain, 3.4, 3.2, m.gold, shade: m.goldD, lw: 1.8);
    if (!k.sil) {
      rp.detail((pa) {
        for (var i = 1; i < chain.length - 1; i += 2) {
          final a = chain[i], b = chain[i + 1];
          pa.moveTo(a.dx - 1.6, a.dy - 2.6);
          pa.lineTo(b.dx + 1.6, b.dy + 2.6);
        }
      }, w: 1, col: m.goldD);
      rp.fill(ellP(27, -27, 8.2, 8.2), m.gold, const Rect.fromLTRB(19, -35, 35, -19), lw: 1.9, shade: m.goldD, noHT: true);
      rp.fill(starPath(27, -27, 5.2, 2.2, 5, -math.pi / 2), m.goldD, const Rect.fromLTRB(21, -33, 33, -21), noHT: true, lw: 1);
    }
    c.restore();
    _leg(k, j, false, p, m);
    if (p.blf >= .5) _leg(k, j, true, p, m);
    _head(k, j, p, m);
    if (p.baf >= .5) _arm(k, j, true, p, m);
    _arm(k, j, false, p, m);
  }

  void _arm(Ink k, Joints j, bool b, KPose p, BrunoPal m) {
    final rp = k.r;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final up = b ? dk(m.fur, .3) : m.fur;
    final fo = b ? dk(m.furD, .25) : m.furD;
    rp.limb(sh, el, 14, 11.5, up, bulge: 3, shade: b ? dk(m.furD, .3) : m.furD);
    rp.fill(ellP(sh.dx, sh.dy, 15.5, 14), up, Rect.fromLTRB(sh.dx - 16, sh.dy - 15, sh.dx + 16, sh.dy + 14),
        shade: m.furD, lw: 2.2);
    rp.limb(el, wr, 12.5, 10.4, fo, bulge: 3.4, shade: dk(m.skin, .2));
    rp.detail((pa) {
      for (var i = 1; i < 4; i++) {
        final q = lerpO(sh, el, i / 4);
        pa.moveTo(q.dx - 3, q.dy - 4);
        pa.lineTo(q.dx - 1, q.dy + 2);
      }
    }, w: 1.1, col: rp.paint ? withA(m.furD, .6) : dk(up, .35));
    // Taped wrist.
    final t0 = lerpO(el, wr, .5);
    rp.limb(t0, wr, 11.2, 10.6, b ? dk(m.tape, .3) : m.tape, noHT: true, lw: 1.9);
    rp.detail((pa) {
      final d = Offset(wr.dx - el.dx, wr.dy - el.dy);
      final L = d.distance == 0 ? 1.0 : d.distance;
      final nx = -d.dy / L * 10.8, ny = d.dx / L * 10.8;
      for (var i = 1; i < 4; i++) {
        final q = lerpO(t0, wr, i / 4);
        pa.moveTo(q.dx + nx, q.dy + ny);
        pa.lineTo(q.dx - nx + d.dx / L * 2, q.dy - ny + d.dy / L * 2);
      }
    }, w: 1.1, col: rp.paint ? const Color(0x66141018) : dk(m.tape, .45));
    if (p.open > .5) {
      k.openHand(wr, el, m.skinL, s: 1.7, back: b, spread: 1.15);
    } else {
      k.fist(wr, el, m.skin, w: 24, h: 21, knuckle: m.skinL, back: b);
    }
  }

  void _leg(Ink k, Joints j, bool b, KPose p, BrunoPal m) {
    final rp = k.r;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    rp.limb(hip, kn, 14.5, 12, b ? dk(m.furD, .3) : m.furD, bulge: 3);
    // Cargo shorts: baggy to just above the knee, with a pocket and a cuff.
    rp.limb(hip, lerpO(hip, kn, .8), 16.5, 15, b ? dk(m.shorts, .3) : m.shorts, bulge: 2.6, shade: m.shortsD, lw: 2.2);
    if (!k.sil) {
      final a = lerpO(hip, kn, .38);
      final ang = math.atan2(kn.dy - hip.dy, kn.dx - hip.dx);
      k.c.save();
      k.c.translate(a.dx, a.dy);
      k.c.rotate(ang);
      rp.fill(rrPath(-6, -16, 13, 11, 2), b ? dk(m.shorts, .4) : dk(m.shorts, .12), const Rect.fromLTRB(-6, -16, 7, -5),
          noHT: true, lw: 1.5);
      rp.detail((pa) => pa
        ..moveTo(-5, -13)
        ..lineTo(6, -13), w: 1, col: m.shortsD);
      k.c.restore();
      final cf = lerpO(hip, kn, .74);
      rp.limb(cf, lerpO(hip, kn, .84), 15.5, 15, b ? dk(m.shortsD, .2) : m.shortsD, noHT: true, lw: 1.6);
    }
    rp.limb(lerpO(hip, kn, .7), an, 11.5, 8.8, b ? dk(m.furD, .3) : m.furD, bulge: 1.8);
    final shin = b ? p.bs : p.fs, off = b ? p.bfa : p.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
    final c = rp.c;
    c.save();
    c.translate(an.dx, an.dy + 4);
    c.rotate(planted ? 0 : -shin + off);
    c.scale(1.12, 1.12);
    rp.fill(_bnFoot, b ? dk(m.skin, .25) : m.skin, const Rect.fromLTRB(-14, -13, 28, 6), lw: 2.1, shade: dk(m.skin, .5));
    rp.detail((pa) => pa
      ..moveTo(15, -2)
      ..lineTo(15, 5)
      ..moveTo(20, -2)
      ..lineTo(20, 5), w: 1.1);
    c.restore();
  }

  bool _roar(KPose p) =>
      p.sa > .5 || (p.fu > 1.3 && p.ff < 2.0) || (p.bu > 1.3 && p.bf < 2.0) || (p.fu > 2.2 && p.bu > 2.2);

  void _head(Ink k, Joints j, KPose p, BrunoPal m) {
    final rp = k.r, c = rp.c;
    // A thick neck from the shoulders up into the skull.
    final neckTop = Offset(j.head.dx - 6, j.head.dy + 12);
    rp.limb(j.neck, neckTop, 20, 15, m.furD, bulge: 2, shade: dk(m.furD, .3));
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.2, 1.2);
    final roar = _roar(p);
    rp.fill(ellP(-5, 3, 3.6, 5), m.skin, const Rect.fromLTRB(-9, -3, -1, 8), lw: 1.6, noHT: true); // ear
    rp.fill(_bnHead, m.furD, const Rect.fromLTRB(-20, -28, 21, 20), shade: dk(m.furD, .4));
    rp.fill(_bnCrest, m.fur, const Rect.fromLTRB(-16, -44, 17, -14), lw: 1.8, noHT: true, shade: m.furD);
    if (!k.sil) {
      rp.fill(_bnFace, m.skin, const Rect.fromLTRB(0, -14, 27, 19), lw: 1.8, shade: dk(m.skin, .4));
      rp.fill(_bnMuzzle, m.skinL, const Rect.fromLTRB(10, 0, 27, 15), noHT: true, lw: 1.2);
      rp.fill(_bnBrow, dk(m.skin, .35), const Rect.fromLTRB(1, -16, 24, -2), noHT: true, lw: 1.5);
      // Deep-set amber eye under the heavy brow.
      k.dot(12.4, -4.2, 3, const Color(0xFFFFF2DC));
      k.dot(13.3, -4, 1.9, m.eye);
      k.dot(13.6, -4, 1, const Color(0xFF1A0E08));
      rp.detail((pa) => pa
        ..moveTo(5, -8)
        ..quadraticBezierTo(13, -12.5, 22, -5.5), w: 4.6, col: const Color(0xFF14101A));
      rp.detail((pa) => pa
        ..moveTo(8, -12)
        ..quadraticBezierTo(5, -8, 6, -3), w: 1, col: dk(m.skin, .5));
      k.dot(22.5, 3.2, 1.2, const Color(0xFF0C0810));
      k.dot(19.4, 4.2, 1.1, const Color(0xFF0C0810));
      if (roar) {
        final mouth = pathOf((q) => q
          ..moveTo(10, 9)
          ..quadraticBezierTo(17, 8, 25, 8)
          ..quadraticBezierTo(24, 17, 16, 18)
          ..quadraticBezierTo(10, 16, 10, 9));
        rp.fill(mouth, m.mouth, const Rect.fromLTRB(10, 8, 25, 18), noHT: true, lw: 1.5);
        rp.fill(rrPath(12, 8.4, 11, 3.2, 1.2), m.teeth, const Rect.fromLTRB(12, 8, 23, 12), noHT: true, lw: 1);
        rp.fill(rrPath(13, 14.4, 8, 2.6, 1), m.teeth, const Rect.fromLTRB(13, 14, 21, 17), noHT: true, lw: 1);
      } else {
        rp.detail((pa) => pa
          ..moveTo(10, 11.5)
          ..quadraticBezierTo(17, 13.5, 24, 10.5), w: 1.6, col: const Color(0xFF14101A));
      }
    }
    c.restore();
  }

  // ---------------------------------------------------------------- moves

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = brunoIdle;
    final q = posing(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    switch (m.name) {
      case 'standLight':
        // A quick hammer fist: raised, then chopped down and forward.
        final x = lunge(4, m, q(fu: 1.35, ff: 1.1, bu: .5, bf: 2.5, lean: .62, rx: 8, head: -.2), Jt.fHa);
        return MoveAnim(
            strike(m, q(fu: 2.5, ff: 3.0, lean: .3, rx: -2), x, I, hold: KPose.from(x, fu: 1.25, lean: .6)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(4, m, q(bu: 1.35, bf: 1.1, fu: .6, ff: 2.4, lean: .62, rx: 8, baf: 1, head: -.2), Jt.bHa);
        return MoveAnim(
            strike(m, q(bu: 2.5, bf: 3.0, lean: .3, rx: -2, baf: 1), x, I, hold: KPose.from(x, bu: 1.25, lean: .6)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // Both fists overhead, a double-hammer smash.
        final x = lunge(4, m, q(fu: 1.1, ff: .95, bu: 1.0, bf: .85, lean: .82, rx: 14, baf: 1, head: -.22, sa: 1), Jt.fHa);
        return MoveAnim(
            strike(m, q(fu: 2.9, ff: 3.1, bu: 2.8, bf: 3.1, lean: -.08, rx: -5, baf: 1, sa: 1), x, I,
                hold: KPose.from(x, lean: .85), windAt: .7),
            smear: Jt.fHa, smearA: s - 4, smearB: s + a + 2);
      case 'fwdHeavy':
        final x = lunge(4, m, q(fu: 1.57, ff: 1.5, bu: 1.1, bf: 1.0, lean: .7, rx: 12, baf: 1), Jt.fHa);
        return MoveAnim(
            strike(m, q(fu: 2.8, ff: 3.1, bu: 2.5, bf: 3.0, lean: -.12, rx: -4, baf: 1), x, I, windAt: .8,
                w2: q(fu: 3.0, ff: 3.2, bu: 2.7, bf: 3.1, lean: -.2, baf: 1)),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a + 2);
      case 'standFinisher':
        final x = lunge(4, m, q(bt: 1.6, bs: 1.5, blf: 1, lean: .3, rx: 8, fu: .8, ff: 1.9, bu: 1.3, bf: 1.8), Jt.bAn);
        return MoveAnim(
            strike(m, q(bt: .2, bs: -1.0, blf: 1, lean: .55, fu: .5, ff: 2.4, bu: .4, bf: 2.6), x, I),
            smear: Jt.bAn, smearA: s - 3, smearB: s + a + 2);
      case 'chestDrum':
        // Both fists beat the chest; roar. The counter window is the drumming.
        final up = q(fu: 2.9, ff: 3.3, bu: 2.8, bf: 3.4, lean: -.04, sa: 1, head: -.25, baf: 1);
        final dA = q(fu: .55, ff: 3.75, bu: 2.3, bf: 3.2, lean: .2, sa: 1, head: -.18, baf: 1);
        final dB = q(fu: 2.3, ff: 3.2, bu: .55, bf: 3.75, lean: .2, sa: 1, head: -.18, baf: 1);
        final end = m.counterEnd > 0 ? m.counterEnd : s + 16;
        final keys = <Key>[Key(0, I), Key(mx(1, s - 2), up), Key(s, dA, 1)];
        var f = s + 3;
        var even = false;
        while (f < end) {
          keys.add(Key(f, even ? dA : dB, 1));
          even = !even;
          f += 3;
        }
        keys.add(Key(end + 2, KPose.from(up, lean: .1)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys));
      case 'drumSlam':
        final x = lunge(4, m, q(fu: 1.2, ff: .9, bu: 1.1, bf: .8, lean: .85, rx: 16, baf: 1, sa: 1, head: -.25), Jt.fHa);
        return MoveAnim(
            strike(m, q(fu: 2.9, ff: 3.2, bu: 2.8, bf: 3.2, lean: -.12, rx: -6, baf: 1, sa: 1), x, I,
                hold: KPose.from(x, lean: .9, rx: 18), windAt: .5),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 2);
      case 'gutPunch':
        // A lumbering haymaker: the back arm winds right back, then swings through.
        final x = lunge(4, m, q(bu: 1.5, bf: 1.57, baf: 1, lean: .72, rx: 12, fu: .5, ff: 2.6, head: -.25), Jt.bHa, max: 40);
        final wind = q(bu: -.9, bf: -.2, baf: 1, lean: -.14, rx: -8, fu: .9, ff: 2.3, ft: .55, bt: -.7, bs: -.5);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, rd(s * .55)), wind),
              Key(mx(2, s - 2), KPose.from(wind, lean: -.2, rx: -10)),
              Key(s, x, 1),
              Key(s + a, KPose.from(x, lean: .78)),
              Key(s + a + rd(r * .45), KPose.from(x, lean: .6, rx: 8)),
              Key(mx(t, s + a + rd(r * .45) + 1), I),
            ]),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 2);
      case 'groundPound':
        final wind = q(fu: 2.9, ff: 3.1, bu: 2.8, bf: 3.1, lean: .0, baf: 1, sa: 1, ft: .8, bt: -.6, rx: -4);
        final pound = q(fu: .75, ff: .3, bu: .65, bf: .2, lean: .98, rx: 14, baf: 1, ft: 1.0, fs: -.35, bt: .25, bs: -.95, head: -.3);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, rd(s * .55)), wind),
              Key(mx(2, s - 1), KPose.from(wind, lean: -.1)),
              Key(s, pound, 1),
              Key(s + a, pound),
              Key(s + a + rd(r * .45), KPose.from(pound, lean: .85)),
              Key(mx(t, s + a + rd(r * .45) + 1), I),
            ]),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a + 1);
      case 'hammerLeap':
        final crouch = q(lean: .75, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .8, ff: 1.0, bu: .7, bf: 1.0, baf: 1);
        final rise = q(lean: .3, fu: 2.9, ff: 3.1, bu: 2.8, bf: 3.1, baf: 1, ft: 1.6, fs: .2, bt: 1.2, bs: -.2, sa: 1);
        final smash = q(lean: .8, fu: 1.2, ff: .9, bu: 1.1, bf: .85, baf: 1, ft: .9, fs: .2, bt: .2, bs: -.4, sa: 1);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(3, crouch),
              Key(mx(5, s - 7), rise, 1),
              Key(mx(6, s - 2), KPose.from(rise, lean: .15)),
              Key(s, smash, 1),
              Key(s + a, smash),
              Key(s + a + rd(r * .5), q(lean: .65, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .9, ff: 1.2, bu: .8, bf: 1.2)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a);
      case 'jungleKing':
        final roar = q(fu: 2.9, ff: 3.2, bu: 2.9, bf: 3.3, lean: -.06, sa: 1, head: -.28, baf: 1, ft: .9, bt: -.7);
        final ws = m.windows;
        final slamA = q(fu: .85, ff: .35, bu: 2.8, bf: 3.2, lean: .8, rx: 10, sa: 1, baf: 1, ft: 1.0, fs: -.3, bt: .1, bs: -.9);
        final slamB = q(bu: .85, bf: .35, fu: 2.8, ff: 3.2, lean: .8, rx: 10, sa: 1, baf: 1, ft: 1.0, fs: -.3, bt: .1, bs: -.9);
        final fin = q(fu: 1.1, ff: .85, bu: 1.0, bf: .8, lean: .95, rx: 16, sa: 1, baf: 1, ft: 1.0, fs: -.3, bt: .25, bs: -.95);
        final keys = <Key>[Key(0, I), Key(mx(1, s ~/ 3), roar), Key(mx(2, s - 1), KPose.from(roar, lean: -.14, rx: -4))];
        for (var i = 0; i < ws.length; i++) {
          final last = i == ws.length - 1;
          keys.add(Key(ws[i].start, last ? fin : (i.isEven ? slamA : slamB), 1));
          if (!last && i + 1 < ws.length) {
            final gap = ws[i + 1].start - ws[i].start;
            keys.add(Key(ws[i].start + mx(1, gap ~/ 2), KPose.from(i.isEven ? slamA : slamB, fu: i.isEven ? 2.0 : 2.8, bu: i.isEven ? 2.8 : 2.0, lean: .5)));
          }
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rd(r * .3), q(lean: .6, fu: 1.0, ff: 1.5, bu: .9, bf: 1.6, baf: 1)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fHa, smearA: s - 1, smearB: tail);
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
    final paintLook = look == FightLook.painted;
    final fill = Paint()..isAntiAlias = true;
    final line = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void ring(Offset o, double r, double w, Color col, {double sq = .28}) {
      c.save();
      c.translate(o.dx, o.dy);
      c.scale(1, sq);
      c.drawCircle(Offset.zero, r, line..strokeWidth = w..color = col);
      c.restore();
    }

    switch (m.name) {
      case 'chestDrum':
      case 'drumSlam':
        if (m.name == 'chestDrum') {
          // Thump rings off the chest, one per beat, while the counter is up.
          final start = m.counterStart < 0 ? 4 : m.counterStart;
          if (sf < start) break;
          final chest = Offset(foot.dx + f.face * 14 * u, foot.dy - 82 * u);
          for (var i = 0; i < 3; i++) {
            final age = (sf - start - i * 3) % 9;
            final k = age / 9;
            final col = look == FightLook.painted ? Color.fromRGBO(255, 230, 160, .55 * (1 - k)) : Color.fromRGBO(255, 214, 90, 1 - k);
            c.drawCircle(chest.translate(f.face * 6 * u, 0), (14 + age * 5) * u, line..strokeWidth = (3 - 2 * k) * u..color = col);
          }
        } else if (sf >= m.startup && sf < m.startup + 16) {
          final k = (sf - m.startup) / 16;
          final o = Offset(foot.dx + f.face * 70 * u, foot.dy);
          ring(o, (20 + k * 80) * u, (5 - 4 * k) * u, Color.fromRGBO(255, 240, 200, 1 - k), sq: .22);
        }
        break;
      case 'groundPound':
      case 'hammerLeap':
        final hit = m.name == 'groundPound' ? m.startup : m.startup;
        if (sf >= hit && sf < hit + 20) {
          final k = (sf - hit) / 20;
          final o = Offset(foot.dx + f.face * 78 * u, cam.toScreen(f.x / unitsPerPx, 0).dy);
          ring(o, (14 + k * 74) * u, (6 - 5 * k) * u, Color.fromRGBO(255, 244, 214, 1 - k), sq: .2);
          ring(o, (8 + k * 46) * u, (4 - 3 * k) * u, Color.fromRGBO(255, 190, 80, 1 - k), sq: .2);
          if (look != FightLook.pixel) {
            for (var i = 0; i < 5; i++) {
              final r0 = hash01(i, f.moveId);
              final rx = o.dx + f.face * (i - 2) * 16 * u * (.4 + k);
              final ry = o.dy - (4 + math.sin(math.min(1.0, k * 2 + r0 * .3) * math.pi) * (10 + 22 * r0)) * u;
              c.drawRect(Rect.fromCenter(center: Offset(rx, ry), width: (3 + 3 * r0) * u, height: (3 + 3 * r0) * u),
                  fill..color = const Color(0xFF6B5A78).withValues(alpha: 1 - k));
            }
          }
        }
        break;
      case 'jungleKing':
        // A rampage aura: gold pulses around him while he pounds.
        if (sf >= 2 && sf < m.startup + m.active + 8) {
          final pulse = .5 + .5 * math.sin(sf * .7);
          final o = Offset(foot.dx + f.face * 10 * u, foot.dy - 80 * u);
          if (paintLook) {
            drawGlow(c, o, 130 * u, Color.fromRGBO(255, 200, 70, .22 + .2 * pulse));
          } else {
            ring(o.translate(0, 74 * u), (60 + 16 * pulse) * u, 3 * u, Color.fromRGBO(255, 214, 90, .8), sq: .22);
          }
          for (final w in m.windows) {
            final age = sf - w.start;
            if (age >= 0 && age < 12) {
              final k = age / 12;
              ring(Offset(foot.dx + f.face * 72 * u, cam.toScreen(f.x / unitsPerPx, 0).dy), (10 + k * 56) * u,
                  (4 - 3 * k) * u, Color.fromRGBO(255, 244, 214, 1 - k), sq: .2);
            }
          }
        }
        break;
    }
  }
}
