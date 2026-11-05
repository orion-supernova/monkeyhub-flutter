// SAGE (id 5): orangutan monk. Long arms, shaggy orange-auburn fur, saffron
// robes with a sash, prayer beads, a cloth sack of fruit at her hip, calm
// half-closed eyes. Projectiles: a MANGO (arc) and a rolling COCONUT (low).
//
// Pose channel `sa` is her held prop: 1 = a mango in the front hand, 2 = a
// coconut in the front hand (rounded; the rest of the generic poses leave it 0).
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

class SagePal {
  final Color fur, furD, furL, face, faceD, robe, robeD, robeL, sash, sashD, bead, bead2, sack, sackD, eye, lid;
  const SagePal({
    required this.fur, required this.furD, required this.furL, required this.face, required this.faceD,
    required this.robe, required this.robeD, required this.robeL, required this.sash, required this.sashD,
    required this.bead, required this.bead2, required this.sack, required this.sackD, required this.eye,
    required this.lid,
  });
  static final SagePal base = SagePal(
      fur: hex(0xd9722a), furD: hex(0x9b4418), furL: hex(0xf59a52), face: hex(0xe3a272), faceD: hex(0xb97848),
      robe: hex(0xf4a722), robeD: hex(0xb8731a), robeL: hex(0xffd067), sash: hex(0xa8322e), sashD: hex(0x6e1d1d),
      bead: hex(0x5a3320), bead2: hex(0xf5c231), sack: hex(0xeee3c2), sackD: hex(0xb8a77c), eye: hex(0x3a2216),
      lid: hex(0x8a4a22));
  /// Mirror match: deep teal robe, gold sash, jade beads.
  static final SagePal alt = SagePal(
      fur: hex(0xd9722a), furD: hex(0x9b4418), furL: hex(0xf59a52), face: hex(0xe3a272), faceD: hex(0xb97848),
      robe: hex(0x2c8aa0), robeD: hex(0x1a5468), robeL: hex(0x6fc7d6), sash: hex(0xe8b13a), sashD: hex(0xa27818),
      bead: hex(0x3fbf86), bead2: hex(0xf6f1e6), sack: hex(0xdfe9ee), sackD: hex(0x8fa2ad), eye: hex(0x3a2216),
      lid: hex(0x8a4a22));
}

final KPose sageIdle =
    KPose.from(pIdle, lean: .1, head: -.05, fu: .4, ff: .95, bu: .22, bf: .8, ft: .38, fs: -.06, bt: -.26, bs: -.4);

class SageArt extends CastArt {
  const SageArt();

  @override
  int get id => 5;
  @override
  RigDims get dims => const RigDims(5, 52, 38, 34, 33, 33, 1.32, 9, 5, 21, 4);
  @override
  KPose get idle => sageIdle;
  @override
  KPalette get palette => _pal(false);
  @override
  KPalette get altPalette => _pal(true);
  @override
  double get portraitWidth => 125;

  static KPalette _pal(bool alt) {
    final m = alt ? SagePal.alt : SagePal.base;
    return KPalette(
        skin: m.fur, hair: m.furD, tip: m.furL, vest: m.robe, tank: m.robeD, pants: m.robe, pad: m.sash,
        wrap: m.bead2, shoe: m.fur, sole: m.furD, accent: m.sash);
  }

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final I = sageIdle;
    return (
      KPose.from(I, fu: .6, ff: 3.3, bu: .6, bf: 3.4, lean: -.04, rx: -3, open: 1),
      KPose.from(I, fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.45, lean: .3, rx: 12, open: 1, baf: 1),
      KPose.from(I, fu: .9, ff: 2.7, bu: .8, bf: 2.8, lean: .06, open: 1, baf: 1),
    );
  }

  // ---------------------------------------------------------------- paint

  static final Path _torso = pathOf((p) => p
    ..moveTo(-11, 0)
    ..cubicTo(-15, -12, -17, -28, -14, -40)
    ..cubicTo(-11, -48, -3, -52, 4, -51)
    ..cubicTo(12, -50, 17, -43, 16, -35)
    ..cubicTo(15, -22, 13, -9, 11, 0));
  static final Path _robeTop = pathOf((p) => p
    ..moveTo(-15, -40)
    ..cubicTo(-12, -48, -4, -52, 2, -52)
    ..lineTo(15, -28)
    ..cubicTo(14, -18, 13, -8, 12, 0)
    ..lineTo(-11, 0)
    ..cubicTo(-15, -12, -17, -28, -15, -40));
  static final Path _foot = pathOf((p) => p
    ..moveTo(-6, -8)
    ..cubicTo(-2, -11, 6, -9, 10, -4)
    ..lineTo(23, -2)
    ..cubicTo(27, 0, 26, 5, 22, 6)
    ..lineTo(-6, 6)
    ..cubicTo(-9, 4, -9, -4, -6, -8));

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final k = Ink.of(rp);
    final m = alt ? SagePal.alt : SagePal.base;
    final c = rp.c;
    final sway = math.sin(frame * .08);
    if (p.baf < .5) _arm(k, j, true, p, m, frame);
    _leg(k, j, true, p, m);
    _leg(k, j, false, p, m);
    // The robe skirt follows the knees.
    final fk = Offset(j.fKn.dx + 10, j.fKn.dy + 4 + sway), bk = Offset(j.bKn.dx - 10, j.bKn.dy + 4 - sway);
    final mid = Offset((fk.dx + bk.dx) / 2, math.max(fk.dy, bk.dy) + 8);
    final skirt = pathOf((q) => q
      ..moveTo(-15, -4)
      ..lineTo(16, -4)
      ..cubicTo(20, 8, fk.dx + 2, fk.dy - 12, fk.dx, fk.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, bk.dx, bk.dy)
      ..cubicTo(bk.dx - 2, bk.dy - 12, -19, 8, -15, -4));
    rp.fill(skirt, m.robe, Rect.fromLTRB(bk.dx - 4, -6, fk.dx + 4, mid.dy), shade: m.robeD, lw: 2.2);
    rp.detail((pa) {
      pa.moveTo(2, 4);
      pa.quadraticBezierTo(4, 16, mid.dx + 2, mid.dy - 6);
      pa.moveTo(-8, 4);
      pa.quadraticBezierTo(-9, 14, bk.dx + 8, bk.dy - 8);
    }, w: 1.2, col: rp.paint ? withA(m.robeD, .7) : m.robeD);
    c.save();
    c.rotate(p.lean);
    rp.fill(_torso, m.fur, const Rect.fromLTRB(-17, -52, 16, 0), shade: m.furD);
    rp.fill(_robeTop, m.robe, const Rect.fromLTRB(-17, -52, 16, 0), shade: m.robeD, lw: 2.2);
    rp.detail((pa) => pa
      ..moveTo(-8, -40)
      ..quadraticBezierTo(-4, -26, -7, -12)
      ..moveTo(2, -49)
      ..lineTo(15, -28), w: 1.3, col: rp.paint ? withA(m.robeD, .75) : m.robeD);
    // Sash, with a knot and two tails that sway.
    rp.fill(rrPath(-14, -15, 29, 10, 3.5), m.sash, const Rect.fromLTRB(-14, -15, 15, -5), shade: m.sashD, noHT: true, lw: 1.9);
    final tails = pathOf((q) => q
      ..moveTo(12, -11)
      ..quadraticBezierTo(18 + sway * 2, -2, 17 + sway * 3, 12)
      ..lineTo(12 + sway * 3, 13)
      ..quadraticBezierTo(11, 2, 9, -8));
    rp.fill(tails, m.sash, const Rect.fromLTRB(8, -12, 20, 14), shade: m.sashD, noHT: true, lw: 1.6);
    rp.fill(ellP(12, -10, 4.2, 4.6), m.sashD, const Rect.fromLTRB(8, -15, 17, -5), noHT: true, lw: 1.5);
    // Hair growing from the shoulders: a shaggy mantle down the back.
    final mantle = Path()..moveTo(-12, -48);
    for (var i = 0; i < 6; i++) {
      final x = -14 - (i % 2) * 3.0, y = -46 + i * 7.0;
      mantle.lineTo(x - 5, y + 3);
      mantle.lineTo(x + 1, y + 6);
    }
    mantle.lineTo(-6, -4);
    mantle.close();
    rp.fill(mantle, m.fur, const Rect.fromLTRB(-24, -50, -4, 0), noHT: true, lw: 1.5, shade: m.furD);
    // Prayer beads.
    if (!k.sil) {
      final bead = bez(pt(-2, -50), pt(10, -46), pt(16, -34), pt(12, -22), 8);
      for (var i = 0; i < bead.length; i++) {
        final big = i == bead.length - 1;
        rp.fill(ellP(bead[i].dx, bead[i].dy, big ? 3.8 : 2.7, big ? 3.8 : 2.7), big ? m.bead2 : m.bead,
            Rect.fromLTRB(bead[i].dx - 4, bead[i].dy - 4, bead[i].dx + 4, bead[i].dy + 4), noHT: true, lw: 1.1);
      }
    }
    c.restore();
    // The sack of fruit hanging at the hip.
    _sack(k, p, m, sway);
    _head(k, j, p, m, frame);
    if (p.baf >= .5) _arm(k, j, true, p, m, frame);
    _arm(k, j, false, p, m, frame);
    _prop(k, j, p, m);
  }

  void _sack(Ink k, KPose p, SagePal m, double sway) {
    final rp = k.r, c = rp.c;
    c.save();
    c.translate(-1, 9);
    c.rotate(sway * .05 - p.lean * .4);
    final bag = pathOf((q) => q
      ..moveTo(-3, 0)
      ..cubicTo(-12, 6, -13, 20, -5, 25)
      ..cubicTo(2, 28, 11, 24, 12, 15)
      ..cubicTo(12, 7, 6, 2, 3, 0));
    // fruit peeking out of the top
    rp.fill(ellP(-2, -2, 5.3, 5), hex(0xff8a2a), const Rect.fromLTRB(-8, -7, 4, 3), lw: 1.5, noHT: true);
    rp.fill(ellP(4.5, -3, 4.6, 4.4), hex(0xd8453a), const Rect.fromLTRB(0, -7, 9, 2), lw: 1.5, noHT: true);
    rp.fill(ellP(-5, -7, 2.4, 1.2, -.5), hex(0x3f9a4a), const Rect.fromLTRB(-8, -9, -2, -5), lw: 1, noHT: true);
    rp.fill(bag, m.sack, const Rect.fromLTRB(-13, 0, 12, 28), shade: m.sackD, lw: 2);
    rp.fill(rrPath(-5, 1, 11, 3.4, 1.7), m.sash, const Rect.fromLTRB(-5, 1, 6, 4), noHT: true, lw: 1.3);
    rp.detail((pa) => pa
      ..moveTo(-8, 10)
      ..quadraticBezierTo(0, 14, 7, 9), w: 1, col: rp.paint ? withA(m.sackD, .8) : m.sackD);
    c.restore();
  }

  void _arm(Ink k, Joints j, bool b, KPose p, SagePal m, double frame0) {
    final rp = k.r;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final fur = b ? dk(m.fur, .3) : m.fur;
    rp.limb(sh, el, 8.2, 6.2, fur, bulge: 1.6, shade: m.furD);
    // Long shaggy fur strands hanging off the arm.
    for (final seg in [(sh, el, 8), (el, wr, 6)]) {
      final tufts = Path();
      for (var i = 1; i < seg.$3; i++) {
        final q = lerpO(seg.$1, seg.$2, i / seg.$3);
        final len = 11 + (i % 3) * 4.0 + math.sin(frame0 * .1 + i) * 1.5;
        tufts.moveTo(q.dx - 3.5, q.dy + 1);
        tufts.quadraticBezierTo(q.dx - 5, q.dy + len * .6, q.dx - 2 + (i % 2) * 2, q.dy + len);
        tufts.quadraticBezierTo(q.dx + 1, q.dy + len * .5, q.dx + 3.5, q.dy + 1);
        tufts.close();
      }
      rp.fill(tufts, b ? dk(m.furD, .1) : m.fur, bbOf([seg.$1, seg.$2], 18), noHT: true, lw: 1.3, shade: m.furD);
    }
    if (b) {
      // Robe sleeve on the far arm.
      rp.limb(sh, lerpO(sh, el, .62), 9.4, 8.4, dk(m.robe, .3), bulge: 1.6, shade: m.robeD, noHT: true, lw: 2);
    }
    rp.limb(el, wr, 6.2, 4.9, fur, bulge: 1.2, shade: m.furD);
    // Wrist beads.
    if (!b) {
      for (var i = 0; i < 3; i++) {
        final q = lerpO(el, wr, .55 + i * .17);
        rp.fill(ellP(q.dx, q.dy, 3, 3), m.bead, Rect.fromLTRB(q.dx - 3, q.dy - 3, q.dx + 3, q.dy + 3), noHT: true, lw: 1);
      }
    }
    if (p.open > .5) {
      k.openHand(wr, el, m.fur, s: 1.1, back: b, spread: 1.0);
    } else {
      k.fist(wr, el, m.fur, w: 13, h: 11.5, knuckle: m.furL, back: b);
    }
  }

  void _leg(Ink k, Joints j, bool b, KPose p, SagePal m) {
    final rp = k.r;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    rp.limb(hip, kn, 8.4, 7.2, b ? dk(m.fur, .3) : m.fur, bulge: 1.4, shade: m.furD);
    rp.limb(kn, an, 7, 5, b ? dk(m.fur, .3) : m.fur, bulge: 1.4, shade: m.furD);
    // Robe trousers to the shin, with a cuff.
    rp.limb(lerpO(hip, kn, .45), lerpO(kn, an, .22), 9.4, 8.4, b ? dk(m.robe, .3) : m.robe, noHT: true, shade: m.robeD, lw: 2);
    rp.limb(lerpO(kn, an, .1), lerpO(kn, an, .3), 8.2, 8.2, b ? dk(m.sash, .3) : m.sash, noHT: true, lw: 1.6);
    final shin = b ? p.bs : p.fs, off = b ? p.bfa : p.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
    final c = rp.c;
    c.save();
    c.translate(an.dx, an.dy + 4);
    c.rotate(planted ? 0 : -shin + off);
    rp.fill(_foot, b ? dk(m.fur, .3) : m.furD, const Rect.fromLTRB(-9, -11, 27, 6), lw: 2);
    rp.detail((pa) => pa
      ..moveTo(14, -1)
      ..lineTo(14, 5)
      ..moveTo(19, -.5)
      ..lineTo(19, 5), w: 1);
    c.restore();
  }

  void _head(Ink k, Joints j, KPose p, SagePal m, double frame) {
    final rp = k.r, c = rp.c;
    rp.limb(j.neck, Offset(j.head.dx - 4, j.head.dy + 10), 9, 8, dk(m.fur, .12), bulge: 1);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.2, 1.2);
    final sw = math.sin(frame * .09) * 2.5;
    const skin = Color(0xFF6E5547), skinL = Color(0xFF8C7260), skinD = Color(0xFF45342B);
    if (!k.sil) {
      final h1 = bez(pt(-10, -4), pt(-22, 4), pt(-32, 12 + sw), pt(-40, 28 + sw), 9);
      rp.fill(tubePath(h1, 7, 1.4), m.fur, bbOf(h1, 8), noHT: true, lw: 1.6, shade: m.furD);
      final h2 = bez(pt(-8, 4), pt(-18, 14), pt(-24, 22 + sw), pt(-30, 38 + sw), 9);
      rp.fill(tubePath(h2, 6, 1.2), m.furD, bbOf(h2, 8), noHT: true, lw: 1.5);
    }
    // Shaggy hair mass growing from the head: a ruff behind the face and a swept crown.
    final ruff = pathOf((q) => q
      ..moveTo(-20, 4)
      ..cubicTo(-26, -12, -14, -27, 0, -27)
      ..cubicTo(9, -27, 14, -21, 12, -13)
      ..cubicTo(6, -12, 0, -8, -2, 0)
      ..cubicTo(-2, 10, 0, 20, -3, 26)
      ..cubicTo(-8, 28, -18, 18, -20, 4));
    rp.fill(ruff, m.fur, const Rect.fromLTRB(-27, -28, 21, 28), shade: m.furD, lw: 2.2);
    rp.detail((pa) {
      for (var i = 0; i < 6; i++) {
        pa.moveTo(-18 + i * 5.0, -22 + (i % 2) * 3);
        pa.lineTo(-20 + i * 5.0, -14 + (i % 2) * 3);
      }
    }, w: 1.1, col: rp.paint ? withA(m.furD, .7) : m.furD);
    if (!k.sil) {
      // Broad flat face, framed by big rounded cheek flanges.
      final face = pathOf((q) => q
        ..moveTo(1, -10)
        ..cubicTo(10, -13, 20, -8, 22, 0)
        ..cubicTo(25, 8, 20, 15, 12, 17)
        ..cubicTo(4, 18, -3, 12, -4, 4)
        ..cubicTo(-4, -3, -2, -8, 1, -10));
      rp.fill(ellP(1.5, 5, 10.5, 12.5), skinL, const Rect.fromLTRB(-9, -7, 12, 18), lw: 1.9, shade: skinD); // near flange
      rp.fill(face, skin, const Rect.fromLTRB(-4, -13, 25, 18), lw: 1.7, shade: skinD);
      rp.fill(ellP(10, 5.5, 8.5, 10.5), skinL, const Rect.fromLTRB(2, -5, 19, 16), noHT: true, lw: 1.1); // inner cheek pad
      rp.fill(ellP(18, 8.5, 7.2, 6.2), lt(skinL, .12), const Rect.fromLTRB(11, 2, 25, 15), noHT: true, lw: 1.2); // wide low muzzle
      // Beard fringe at the chin.
      rp.fill(fringe(pt(2, 16), pt(18, 17), 7, 6, frame * .1), m.furL, const Rect.fromLTRB(1, 15, 20, 25), noHT: true, lw: 1.3);
      // Small deep-set, calm half-closed eyes under a heavy brow.
      for (final e in const [(10.0, -2.4, 2.4), (17.2, -2.6, 1.8)]) {
        k.dot(e.$1, e.$2 + .5, e.$3, const Color(0xFFF2E4C8));
        k.dot(e.$1 + .4, e.$2 + .9, e.$3 * .62, const Color(0xFF1C120C));
        rp.fill(pathOf((q) => q
          ..moveTo(e.$1 - e.$3 - .8, e.$2 + .5)
          ..quadraticBezierTo(e.$1, e.$2 - e.$3 - 1.6, e.$1 + e.$3 + .8, e.$2 + .5)
          ..quadraticBezierTo(e.$1, e.$2 - e.$3 * .1, e.$1 - e.$3 - .8, e.$2 + .5)), skinD,
            Rect.fromLTRB(e.$1 - 5, e.$2 - 5, e.$1 + 5, e.$2 + 2), noHT: true, lw: 1);
        rp.detail((pa) => pa
          ..moveTo(e.$1 - e.$3 - 1, e.$2 + .5)
          ..quadraticBezierTo(e.$1, e.$2 + 1.4, e.$1 + e.$3 + 1, e.$2 + .3), w: 1.2, col: const Color(0xFF1C120C));
      }
      rp.detail((pa) => pa
        ..moveTo(5.5, -6.5)
        ..quadraticBezierTo(11, -9.5, 19.5, -6), w: 2.4, col: skinD);
      k.dot(21.5, 6.4, .9, const Color(0xFF1C120C));
      k.dot(19.2, 6.8, .8, const Color(0xFF1C120C));
      rp.detail((pa) => pa
        ..moveTo(12.5, 12.2)
        ..quadraticBezierTo(18, 14.2, 23.5, 11.4), w: 1.3, col: const Color(0xFF1C120C));
    }
    c.restore();
  }

  // ---------------------------------------------------------------- props

  static void paintMango(Canvas c, FightLook look, double spin, {double s = 1}) {
    final skin = Paint()..isAntiAlias = true;
    c.save();
    c.rotate(spin);
    c.scale(s, s);
    final body = pathOf((p) => p
      ..moveTo(-12, 1)
      ..cubicTo(-12, -9, -2, -13, 7, -9)
      ..cubicTo(14, -6, 15, 4, 8, 10)
      ..cubicTo(1, 15, -12, 11, -12, 1));
    if (look == FightLook.painted) {
      skin.shader = Gradient.linear(const Offset(-10, -10), const Offset(12, 12), [hex(0xffd23a), hex(0xff8a2a), hex(0xd8403a)], const [0, .55, 1]);
    } else {
      skin.color = look == FightLook.pixel ? hex(0xff9a2a) : hex(0xffa22e);
    }
    c.drawPath(body, skin);
    skin.shader = null;
    c.drawPath(Path()..addOval(Rect.fromLTWH(-3, 2, 15, 10)), skin..color = withA(hex(0xd8403a), .45));
    c.drawPath(Path()..addOval(Rect.fromLTWH(-8, -9, 7, 3.4)), skin..color = withA(const Color(0xFFFFFFFF), .5));
    if (look == FightLook.cartoon) {
      c.drawPath(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round
            ..color = kInk);
    }
    c.drawPath(ellP(-11, -9, 5, 2.2, -.7), skin..color = hex(0x3f9a4a));
    c.restore();
  }

  static void paintCoconut(Canvas c, FightLook look, double spin, {double s = 1}) {
    final f = Paint()..isAntiAlias = true;
    c.save();
    c.scale(s, s);
    c.rotate(spin);
    if (look == FightLook.painted) {
      f.shader = Gradient.radial(const Offset(-5, -6), 20, [hex(0xb98a5a), hex(0x7a4f2c), hex(0x4a2e18)], const [0, .55, 1]);
    } else {
      f.color = hex(0x7a4f2c);
    }
    c.drawCircle(Offset.zero, 13.5, f);
    f.shader = null;
    // Hairy husk strokes + the three dark "eyes".
    final h = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = hex(0x4a2e18);
    for (var i = 0; i < 9; i++) {
      final a = i * .7;
      c.drawLine(Offset(math.cos(a) * 6, math.sin(a) * 6), Offset(math.cos(a + .2) * 11.5, math.sin(a + .2) * 11.5), h);
    }
    f.color = hex(0x1f120a);
    c.drawCircle(const Offset(-3, -5), 2, f);
    c.drawCircle(const Offset(3, -5), 2, f);
    c.drawCircle(const Offset(0, -1), 1.7, f);
    if (look == FightLook.cartoon) c.drawCircle(Offset.zero, 13.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = kInk);
    c.restore();
  }

  void _prop(Ink k, Joints j, KPose p, SagePal m) {
    final prop = p.sa.round();
    if (prop < 1 || k.sil) return;
    final o = Offset(j.fHa.dx + 6, j.fHa.dy - 3);
    k.c.save();
    k.c.translate(o.dx, o.dy);
    if (prop == 1) {
      paintMango(k.c, k.r.look, -.5, s: .95);
    } else {
      paintCoconut(k.c, k.r.look, 0, s: .8);
    }
    k.c.restore();
  }

  @override
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) {
    final n = def.name;
    c.save();
    if (n.startsWith('Mango')) {
      final spin = age * .24;
      c.drawCircle(const Offset(-18, 3), 3, Paint()..color = const Color(0x44FFE9A0));
      c.drawCircle(const Offset(-26, 6), 2, Paint()..color = const Color(0x33FFE9A0));
      paintMango(c, look, spin, s: 1.1);
    } else if (n.startsWith('Coconut')) {
      // Rolls on the ground: the box is wider than tall; sits on the floor line.
      final h = def.h / def.w * 31.0;
      c.translate(0, h / 2 - 14.5);
      for (var i = 0; i < 3; i++) {
        c.drawCircle(Offset(-18.0 - i * 9, 9 - i * 2), 3.4 - i, Paint()..color = Color.fromRGBO(200, 180, 150, .45 - i * .12));
      }
      paintCoconut(c, look, age * .22, s: 1.0);
    } else if (n.contains('finale')) {
      _pineapple(c, look, age * .05);
    } else {
      _fruit(c, look, age * .08);
    }
    c.restore();
    return true;
  }

  static void _fruit(Canvas c, FightLook look, double spin) {
    final f = Paint()..isAntiAlias = true;
    c.save();
    c.rotate(spin);
    if (look == FightLook.painted) {
      f.shader = Gradient.radial(const Offset(-4, -5), 18, [hex(0xffd2a0), hex(0xff8a5a), hex(0xd8403a)], const [0, .5, 1]);
    } else {
      f.color = hex(0xff7a4e);
    }
    c.drawCircle(Offset.zero, 13, f);
    f.shader = null;
    c.drawPath(ellP(2, -12, 6, 2.6, -.6), f..color = hex(0x3f9a4a));
    if (look == FightLook.cartoon) c.drawCircle(Offset.zero, 13, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = kInk);
    c.drawPath(ellP(-5, -5, 3.4, 2, -.7), f..color = const Color(0x88FFFFFF));
    c.restore();
  }

  static void _pineapple(Canvas c, FightLook look, double spin) {
    final f = Paint()..isAntiAlias = true;
    c.save();
    c.rotate(spin);
    final body = ellP(0, 4, 12, 15);
    c.drawPath(body, f..color = hex(0xf2b92a));
    final g = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = hex(0xa8741a);
    c.save();
    c.clipPath(body);
    for (var i = -3; i <= 3; i++) {
      c.drawLine(Offset(i * 6.0 - 12, -12), Offset(i * 6.0 + 12, 20), g);
      c.drawLine(Offset(i * 6.0 + 12, -12), Offset(i * 6.0 - 12, 20), g);
    }
    c.restore();
    for (var i = -2; i <= 2; i++) {
      final leaf = Path()
        ..moveTo(i * 2.0, -9)
        ..quadraticBezierTo(i * 5.0, -20, i * 7.0, -25)
        ..quadraticBezierTo(i * 2.0, -18, i * 2.0 + 3, -9);
      c.drawPath(leaf, f..color = hex(0x3f9a4a));
    }
    if (look == FightLook.cartoon) c.drawPath(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = kInk);
    c.restore();
  }

  // ---------------------------------------------------------------- moves

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = sageIdle;
    final q = posing(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    switch (m.name) {
      case 'standLight':
        final x = lunge(5, m, q(fu: 1.5, ff: 1.55, lean: .22, rx: 9, open: 1), Jt.fHa);
        return MoveAnim(strike(m, q(fu: .5, ff: 2.6, open: 1), x, I, hold: KPose.from(x, fu: 1.42, lean: .2)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(5, m, q(bu: 1.5, bf: 1.55, lean: .22, rx: 9, open: 1, baf: 1), Jt.bHa);
        return MoveAnim(strike(m, q(bu: .5, bf: 2.6, open: 1, baf: 1), x, I, hold: KPose.from(x, bu: 1.42, lean: .2)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // Both palms drive forward, a monk's double thrust.
        final x = lunge(5, m, q(fu: 1.55, ff: 1.5, bu: 1.45, bf: 1.5, lean: .34, rx: 14, open: 1, baf: 1), Jt.fHa);
        return MoveAnim(
            strike(m, q(fu: .3, ff: 3.1, bu: .2, bf: 3.2, lean: -.06, rx: -4, open: 1, baf: 1), x, I,
                hold: KPose.from(x, lean: .36), windAt: .7),
            smear: Jt.fHa, smearA: s - 4, smearB: s + a + 2);
      case 'mangoLob':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final hold = q(fu: .9, ff: 2.3, sa: 1, lean: .08);
        final back = q(fu: 2.5, ff: 3.5, sa: 1, lean: -.08, rx: -3, ft: .45, bt: -.35);
        final out = q(fu: 2.0, ff: 1.75, sa: 0, lean: .22, rx: 6, open: 1);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rd(sp * .4)), hold),
          Key(mx(2, sp - 2), back),
          Key(sp, out, 1),
          Key(sp + rd((t - sp) * .45), KPose.from(out, fu: 1.7, ff: 1.6, lean: .2)),
          Key(mx(t, sp + 3), I),
        ]));
      case 'coconutRoll':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final crouch = q(lean: .5, ft: 1.0, fs: -.3, bt: .15, bs: -.9, fu: -.2, ff: .35, sa: 2);
        final back = q(lean: .55, ft: 1.0, fs: -.3, bt: .15, bs: -.9, fu: -.55, ff: .1, sa: 2, rx: -3);
        final roll = q(lean: .7, ft: 1.05, fs: -.3, bt: .15, bs: -.9, fu: 1.1, ff: 1.2, sa: 0, rx: 8, open: 1);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rd(sp * .4)), crouch),
          Key(mx(2, sp - 2), back),
          Key(sp, roll, 1),
          Key(sp + rd((t - sp) * .5), KPose.from(roll, lean: .6)),
          Key(mx(t, sp + 3), I),
        ]));
      case 'lotusSway':
        // Back-hop with palms together at the chest, swaying like a lotus.
        final pray = q(fu: .75, ff: 2.9, bu: .65, bf: 3.0, lean: -.1, rx: -6, open: 1, baf: 1, ft: .3, bt: -.15, bs: -.3);
        final sway = KPose.from(pray, lean: -.2, rx: -12, head: .08);
        return MoveAnim(mono([
          Key(0, I),
          Key(2, pray),
          Key(mx(4, s - 2), sway),
          Key(t - 4 > s ? t - 4 : s + 1, KPose.from(sway, lean: -.05, rx: -6)),
          Key(mx(t, s + 2), I),
        ]));
      case 'skyPalm':
        final crouch = q(lean: .32, ft: .95, fs: -.35, bt: .2, bs: -.95, fu: .2, ff: 1.0, bu: .1, bf: 1.0, open: 1);
        final up = q(lean: -.12, fu: 2.55, ff: 2.85, bu: .6, bf: 2.2, open: 1, ft: 1.3, fs: .2, bt: .2, bs: -.4, head: -.18);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), crouch),
              Key(s, up, 1),
              Key(s + a, KPose.from(up, fu: 2.65, lean: -.16)),
              Key(s + a + rd(r * .4), q(lean: .1, fu: 1.6, ff: 2.2, open: 1)),
              Key(mx(t, s + a + rd(r * .4) + 1), I),
            ]),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a);
      case 'fruitFeast':
        // Arms raised, the sack tipped: fruit rains over the screen.
        final raise = q(fu: 2.7, ff: 3.0, bu: 2.6, bf: 2.9, lean: -.12, open: 1, baf: 1, head: -.25, rx: -3);
        final cast = q(fu: 2.4, ff: 2.4, bu: 2.3, bf: 2.3, lean: .05, open: 1, baf: 1, head: -.2);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, s - 4), q(fu: .8, ff: 3.0, bu: .7, bf: 3.1, open: 1, baf: 1, lean: -.05)),
          Key(s, raise, 1),
          Key(s + 14, cast),
          Key(s + 30, raise),
          Key(mx(t, s + 31), I),
        ]));
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
    if (m.name == 'lotusSway' && sf < m.total) {
      // A lotus of petals opens under her feet and fades.
      final k = sf / m.total;
      final a = 1 - k;
      final o = Offset(foot.dx, foot.dy);
      for (var i = 0; i < 7; i++) {
        final ang = -math.pi + (i + .5) / 7 * math.pi;
        final len = (14 + 22 * math.min(1.0, sf / 6)) * u;
        c.save();
        c.translate(o.dx, o.dy);
        c.scale(1, .5);
        c.rotate(ang + math.pi / 2);
        final petal = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(len * .28, -len * .55, 0, -len)
          ..quadraticBezierTo(-len * .28, -len * .55, 0, 0);
        c.drawPath(petal, fill..color = Color.fromRGBO(255, 150, 190, .85 * a));
        if (look == FightLook.cartoon) c.drawPath(petal, ln..strokeWidth = 1.6 * u..color = Color.fromRGBO(21, 15, 30, a));
        c.restore();
      }
      if (look == FightLook.painted) drawGlow(c, o.translate(0, -8 * u), 56 * u, Color.fromRGBO(255, 170, 210, .3 * a));
    } else if (m.name == 'fruitFeast' && sf >= 2 && sf < m.startup + 34) {
      final pulse = .5 + .5 * math.sin(sf * .5);
      final o = Offset(foot.dx, foot.dy - 100 * u);
      if (look == FightLook.painted) {
        drawGlow(c, o, 120 * u, Color.fromRGBO(255, 210, 100, .22 + .12 * pulse));
      } else {
        c.save();
        c.translate(foot.dx, foot.dy);
        c.scale(1, .22);
        c.drawCircle(Offset.zero, (46 + 10 * pulse) * u, ln..strokeWidth = 3 * u..color = const Color(0xCCFFD25A));
        c.restore();
      }
    } else if (m.name == 'skyPalm' && sf >= m.startup && sf < m.startup + m.active + 4) {
      final k = (sf - m.startup) / (m.active + 4);
      final o = Offset(foot.dx + f.face * 30 * u, foot.dy - 120 * u);
      for (var i = 0; i < 3; i++) {
        final r0 = (14 + i * 10 + k * 18) * u;
        c.drawArc(Rect.fromCenter(center: o, width: r0 * 2, height: r0 * 1.2), -math.pi * .95, math.pi * .9, false,
            ln..strokeWidth = (3 - i * .7) * u..color = Color.fromRGBO(255, 235, 170, (1 - k) * (1 - i * .25)));
      }
    }
  }
}
