// GOLEM (she): a stone giantess. Fitted grey-brown plates with moss and small
// flowers, two long braided vine "hair" braids, amber runes on the chest and
// forearms that brighten when armoured, a calm carved face with glowing eyes.
// Channels: `sx` = rune glow boost (armour), `sa` = a boulder held in both
// hands (0..1).
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim, evalKeys;
import 'cast_art.dart';
import 'legends_kit.dart';

class _GL {
  final Color stone, stoneD, stoneL, moss, mossL, rune, runeHot, vine, vineD, petal, petal2;
  const _GL(this.stone, this.stoneD, this.stoneL, this.moss, this.mossL, this.rune, this.runeHot, this.vine, this.vineD, this.petal, this.petal2);
  static final base = _GL(hex(0x8c7e6c), hex(0x584e41), hex(0xb0a28d), hex(0x5f8f3c), hex(0x8cbe52), hex(0xffb020), hex(0xfff0a0),
      hex(0x3e7a34), hex(0x244f26), hex(0xff8fb0), hex(0xfff6e8));
  /// Mirror match: dark basalt, violet lichen, cyan runes.
  static final alt = _GL(hex(0x4c4854), hex(0x26222e), hex(0x726c80), hex(0x7a5ac0), hex(0xa88ae8), hex(0x4ff3ff), hex(0xe0ffff),
      hex(0x6a3a96), hex(0x3a1c60), hex(0xffa040), hex(0xfff0d0));
}

final KPose _idle = KPose.from(pIdle,
    lean: .2, head: .04, fu: .9, ff: 1.9, bu: .7, bf: 2.05, ft: .5, fs: -.05, bt: -.28, bs: -.35);

final Path _pelvisP = roundPoly(const [Offset(-23, -12), Offset(-25, 7), Offset(25, 7), Offset(23, -12)], 6);
final Path _bellyP = roundPoly(const [Offset(-20, -32), Offset(-19, -10), Offset(19, -10), Offset(20, -32)], 5);
final Path _chestP = roundPoly(const [
  Offset(-25, -34), Offset(-28, -57), Offset(-17, -71), Offset(17, -71), Offset(29, -57), Offset(26, -34), Offset(14, -25), Offset(-14, -25),
], 8);
final Path _chestPlate = roundPoly(const [Offset(-12, -66), Offset(14, -66), Offset(17, -44), Offset(-1, -33), Offset(-15, -44)], 5);
final Path _footP = roundPoly(const [Offset(-14, -17), Offset(9, -17), Offset(16, -7), Offset(30, -4), Offset(33, 8), Offset(-15, 8)], 5);
final Path _headP = roundPoly(const [
  Offset(-14, -14), Offset(-4, -22), Offset(10, -20), Offset(17, -10), Offset(18, 5), Offset(12, 16), Offset(-2, 19), Offset(-13, 10),
], 6);
final Path _browP = roundPoly(const [Offset(1, -11), Offset(19, -10), Offset(19, -5.5), Offset(1, -7)], 2);

/// A lumpy boulder around the origin, radius [r].
Path boulderPath(double r) {
  const k = [1.0, .9, 1.06, .94, 1.04, .88, 1.02, .93, 1.07];
  final pts = [for (var i = 0; i < k.length; i++) polar(i / k.length * math.pi * 2 + .3, r * k[i])];
  return roundPoly(pts, r * .3);
}

void _drawBoulder(Canvas c, FightLook look, double r, _GL g, double rot, {double glow = 0}) {
  c.save();
  c.rotate(rot);
  final p = boulderPath(r);
  fillC(c, p, g.stoneD);
  fillIn(c, p, p.shift(Offset(-r * .13, -r * .15)), g.stone);
  fillIn(c, p, ovalP(-r * .35, -r * .5, r * .55, r * .3, -.4), g.moss);
  fillIn(c, p, ovalP(-r * .1, -r * .6, r * .25, r * .14, -.3), g.mossL);
  fillIn(c, p, ovalP(r * .35, r * .2, r * .3, r * .22, .4), g.stoneL);
  lineC(c, Offset(r * .1, -r * .1), Offset(r * .45, r * .3), r * .07, withA(g.stoneD, .8));
  lineC(c, Offset(-r * .4, r * .25), Offset(-r * .1, r * .45), r * .06, withA(g.stoneD, .8));
  dotC(c, Offset(-r * .45, -r * .6), r * .1, g.petal);
  dotC(c, Offset(-r * .45, -r * .6), r * .04, g.runeHot);
  if (look == FightLook.cartoon) strokeC(c, p, r * .11, kInk);
  if (glow > 0) {
    if (look == FightLook.painted) drawGlow(c, Offset.zero, r * 2, withA(g.rune, .5 * glow));
    ringC(c, Offset.zero, r * .55, r * .08, withA(g.rune, .9 * glow));
  }
  c.restore();
}

class GolemArt extends CastArt {
  const GolemArt();

  @override
  int get id => 19;

  @override
  RigDims get dims => const RigDims(19, 66, 36, 34, 36, 34, 1.42, 17, 11, 22, 8);

  @override
  KPose get idle => _idle;

  @override
  double get portraitWidth => 170;

  @override
  KPalette get palette => KPalette(
      skin: hex(0x8c7e6c), hair: hex(0x3e7a34), tip: hex(0xffb020), vest: hex(0x584e41), tank: hex(0x584e41),
      pants: hex(0x584e41), pad: hex(0x5f8f3c), wrap: hex(0xffb020), shoe: hex(0x8c7e6c), sole: hex(0x584e41), accent: hex(0xffb020));

  @override
  KPalette get altPalette => KPalette(
      skin: hex(0x4c4854), hair: hex(0x6a3a96), tip: hex(0x4ff3ff), vest: hex(0x26222e), tank: hex(0x26222e),
      pants: hex(0x26222e), pad: hex(0x7a5ac0), wrap: hex(0x4ff3ff), shoe: hex(0x4c4854), sole: hex(0x26222e), accent: hex(0x4ff3ff));

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final q = Pq(_idle);
    return (
      q(fu: 2.8, ff: 3.0, bu: 2.7, bf: 3.0, lean: -.12, rx: -4, sx: .5),
      q(fu: 1.3, ff: 1.0, bu: 1.2, bf: .95, lean: .6, rx: 12, sx: 1),
      q(fu: 1.2, ff: 2.3, bu: 1.1, bf: 2.4, baf: 1, lean: .2, sx: .4),
    );
  }

  // ================================================================ paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final g = alt ? _GL.alt : _GL.base;
    final glow = (.5 + .12 * math.sin(frame * .05) + .5 * p.sx).clamp(0.0, 1.2);
    if (p.baf < .5) _arm(rp, j, true, p, g, glow);
    _leg(rp, j, true, p, g);
    _torso(rp, p, g, glow, frame);
    if (rp.sil == null) _braids(rp, j, p, g, frame);
    _leg(rp, j, false, p, g);
    if (p.blf >= .5) _leg(rp, j, true, p, g);
    _head(rp, j, p, g, glow, frame);
    if (p.baf >= .5) _arm(rp, j, true, p, g, glow);
    _arm(rp, j, false, p, g, glow);
    if (p.sa > .15 && rp.sil == null) {
      final mid = Offset((j.fHa.dx + j.bHa.dx) / 2 + 2, (j.fHa.dy + j.bHa.dy) / 2 - 20);
      rp.c.save();
      rp.c.translate(mid.dx, mid.dy);
      _drawBoulder(rp.c, rp.look, 24 * math.min(1.0, p.sa), g, frame * .01, glow: p.sx);
      rp.c.restore();
    }
  }

  void _braids(RigPainter rp, Joints j, KPose p, _GL g, double f) {
    final c = rp.c;
    for (var b = 0; b < 2; b++) {
      final sw = math.sin(f * .06 + b * 1.4) * 5, sw2 = math.sin(f * .06 + b * 1.4 - .8) * 7;
      final root = Offset(j.head.dx - 14 - b * 2, j.head.dy + 2 + b * 7);
      final pts = cubic(root, root + Offset(-20, 6), root + Offset(-26 + sw, 36), root + Offset(-34 + sw2, 82 + b * 6), 16);
      rp.fill(tube(pts, 5.6 - b * .4, 2.6), g.vine, boundsOf(pts, 8), shade: g.vineD, lw: 2, noHT: true);
      // The braid: overlapping leaf-shaped links, alternating.
      for (var i = 1; i < pts.length - 1; i++) {
        final a = pts[i], d = pts[i + 1] - pts[i - 1];
        final ang = math.atan2(d.dy, d.dx);
        final w = lerpD(5.2, 2.4, i / pts.length);
        c.save();
        c.translate(a.dx, a.dy);
        c.rotate(ang + (i.isEven ? .7 : -.7));
        fillC(c, ovalP(0, 0, w * 1.15, w * .55), i.isEven ? g.mossL : g.vine);
        if (rp.cel) strokeC(c, ovalP(0, 0, w * 1.15, w * .55), .8, kInk);
        c.restore();
      }
      // Tiny flowers tied in at the tip.
      final tip = pts.last;
      for (var i = 0; i < 3; i++) {
        final o = tip + Offset(-2 + i * 3.5, 1 + (i == 1 ? 3 : 0));
        for (var k = 0; k < 5; k++) {
          dotC(c, o + polar(k * 1.256, 2.2), 1.5, i.isEven ? g.petal : g.petal2);
        }
        dotC(c, o, 1.2, hex(0xffd84a));
      }
    }
  }

  static final Expando<(Path, Path)> _mossMarks = Expando('golemMoss');

  void _moss(Canvas c, Path clip, List<(double, double, double, double, double)> blobs, _GL g, {bool flowers = true}) {
    var m = _mossMarks[blobs];
    if (m == null) {
      final a = Path(), b = Path();
      for (final bl in blobs) {
        a.addPath(ovalP(bl.$1, bl.$2, bl.$3, bl.$4, bl.$5), Offset.zero);
        b.addPath(ovalP(bl.$1 + bl.$3 * .1, bl.$2 - bl.$4 * .3, bl.$3 * .6, bl.$4 * .45, bl.$5), Offset.zero);
      }
      _mossMarks[blobs] = m = (a, b);
    }
    fillIn(c, clip, m.$1, g.moss);
    fillIn(c, clip, m.$2, g.mossL);
    if (flowers) {
      for (final b in blobs.take(1)) {
        for (var i = 0; i < 3; i++) {
          final o = Offset(b.$1 - b.$3 * .4 + i * b.$3 * .45, b.$2 - b.$4 * .2 + (i == 1 ? -2.5 : 1));
          for (var k = 0; k < 5; k++) {
            dotC(c, o + polar(k * 1.256 + i, 2.3), 1.5, i == 1 ? g.petal2 : g.petal);
          }
          dotC(c, o, 1.2, hex(0xffd84a));
        }
      }
    }
  }

  void _rune(RigPainter rp, Offset o, double s, double a, _GL g, {double rot = 0}) {
    if (rp.sil != null) return;
    final c = rp.c;
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    c.scale(s);
    final glyph = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: 9))
      ..moveTo(-5, 0)
      ..lineTo(5, 0)
      ..moveTo(0, -6)
      ..lineTo(0, 6)
      ..moveTo(-4, -4)
      ..lineTo(4, 4)
      ..moveTo(-12, -10)
      ..lineTo(-12, 10)
      ..moveTo(12, -10)
      ..lineTo(12, 10);
    if (rp.paint) {
      drawGlow(c, Offset.zero, 18, withA(g.rune, .5 * a.clamp(0.0, 1.0)));
      plusStroke(c, glyph, 2.4 / s, withA(g.rune, .9 * a.clamp(0.0, 1.0)));
      plusStroke(c, glyph, 1 / s, withA(g.runeHot, .8 * a.clamp(0.0, 1.0)));
    } else {
      strokeC(c, glyph, 2.6 / s, withA(g.rune, a.clamp(0.0, 1.0)));
      if (a > .8) strokeC(c, glyph, 1 / s, withA(g.runeHot, 1));
    }
    c.restore();
  }

  void _torso(RigPainter rp, KPose p, _GL g, double glow, double f) {
    final c = rp.c;
    final sil = rp.sil != null;
    c.save();
    c.rotate(p.lean);
    rp.fill(_pelvisP, g.stoneD, const Rect.fromLTRB(-25, -12, 25, 7), shade: dk(g.stoneD, .3), lw: 2.6);
    // Skirt plates.
    for (var i = 0; i < 4; i++) {
      rp.fill(roundPoly([Offset(-24.0 + i * 12, -4), Offset(-14.0 + i * 12, -4), Offset(-15.5 + i * 12, 12), Offset(-24.0 + i * 12, 11)], 3), i.isEven ? g.stone : g.stoneL,
          Rect.fromLTWH(-24.0 + i * 12, -4, 11, 16), shade: g.stoneD, lw: 1.8, noHT: true);
    }
    rp.fill(_bellyP, g.stone, const Rect.fromLTRB(-20, -32, 20, -10), shade: g.stoneD, lw: 2.4);
    rp.fill(_chestP, g.stone, const Rect.fromLTRB(-29, -71, 29, -25), shade: g.stoneD);
    if (!sil) {
      rp.fill(_chestPlate, g.stoneL, const Rect.fromLTRB(-15, -66, 17, -33), shade: g.stone, lw: 1.8, noHT: true);
      rp.detail((pa) {
        for (final y in const [-28.0, -20.0, -13.0]) {
          pa.moveTo(-19, y);
          pa.lineTo(19, y);
        }
        pa.moveTo(0, -30);
        pa.lineTo(0, -10);
        pa.moveTo(-26, -50);
        pa.lineTo(-15, -46);
        pa.moveTo(28, -52);
        pa.lineTo(17, -47);
      }, w: 1.3, col: rp.paint ? withA(g.stoneD, .7) : g.stoneD);
      _moss(c, _chestP, const [(-22.0, -62.0, 11.0, 6.0, -.4), (18.0, -26.0, 8.0, 4.0, .3)], g, flowers: false);
      _moss(c, _pelvisP, const [(-18.0, 2.0, 9.0, 4.0, .1)], g, flowers: false);
      // The great rune on her chest.
      _rune(rp, const Offset(1, -50), 1.15, glow, g);
    }
    c.restore();
  }

  void _arm(RigPainter rp, Joints j, bool back, KPose p, _GL g, double glow) {
    final c = rp.c;
    final sil = rp.sil != null;
    final sh = back ? j.bSh : j.fSh, el = back ? j.bEl : j.fEl, wr = back ? j.bWr : j.fWr;
    Color cc(Color col) => back ? dk(col, .28) : col;
    // Upper arm: stacked plates; forearm: a heavy gauntlet with a rune.
    rp.fill(segBox(sh, el, 14, 11.5, 5), cc(g.stone), segRect(sh, el, 15), shade: g.stoneD, lw: 2.4);
    final a1 = Offset.lerp(sh, el, .42)!, a2 = Offset.lerp(sh, el, .62)!;
    rp.fill(segBox(a1, a2, 14.4, 13, 3), cc(g.stoneL), segRect(a1, a2, 15), shade: g.stone, lw: 1.8, noHT: true);
    rp.fill(ovalP(el.dx, el.dy, 11, 11), cc(g.stoneD), Rect.fromCenter(center: el, width: 23, height: 23), noHT: true, lw: 2);
    rp.fill(segBox(el, wr, 12, 13, 4.5), cc(g.stone), segRect(el, wr, 15), shade: g.stoneD, lw: 2.4);
    if (!sil && !back) {
      final m = Offset.lerp(el, wr, .5)!;
      _rune(rp, m, .65, glow, g, rot: math.atan2(wr.dy - el.dy, wr.dx - el.dx));
    }
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    if (p.open > .5) {
      rp.fill(rrPath(-3, -12, 18, 24, 7), cc(g.stone), const Rect.fromLTRB(-3, -12, 15, 12), shade: g.stoneD, lw: 2.2);
      for (var i = 0; i < 4; i++) {
        rp.fill(rrPath(13, -12.5 + i * 6.4, 17, 5.6, 2.5), cc(g.stoneL), Rect.fromLTWH(13, -12.5 + i * 6.4, 17, 5.6), noHT: true, lw: 1.6);
      }
    } else {
      rp.fill(rrPath(-3, -13.5, 28, 27, 9), cc(g.stone), const Rect.fromLTRB(-3, -14, 25, 14), shade: g.stoneD, lw: 2.6);
      if (!sil) {
        rp.detail((pa) => pa
          ..moveTo(13, -13)
          ..lineTo(13, 13)
          ..moveTo(13, -4.5)
          ..lineTo(24, -4.5)
          ..moveTo(13, 4.5)
          ..lineTo(24, 4.5), w: 1.4);
        if (!back) _moss(c, rrPath(-3, -13.5, 28, 27, 9), const [(2.0, -11.0, 8.0, 4.0, 0.0)], g, flowers: false);
      }
    }
    c.restore();
    // Pauldron.
    rp.fill(ovalP(sh.dx, sh.dy - 1, 17, 14, -.25), cc(g.stoneL), Rect.fromCenter(center: sh, width: 34, height: 28), shade: g.stoneD, lw: 2.6);
    if (!sil) {
      _moss(c, ovalP(sh.dx, sh.dy - 1, 17, 14, -.25), [(sh.dx - 4, sh.dy - 9, 11.0, 5.5, -.25)], g, flowers: !back);
      rp.detail((pa) => pa
        ..moveTo(sh.dx - 9, sh.dy + 4)
        ..quadraticBezierTo(sh.dx, sh.dy + 9, sh.dx + 10, sh.dy + 3), w: 1.3);
    }
  }

  void _leg(RigPainter rp, Joints j, bool back, KPose p, _GL g) {
    final c = rp.c;
    final sil = rp.sil != null;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    Color cc(Color col) => back ? dk(col, .28) : col;
    rp.fill(segBox(hip, kn, 16.5, 14, 5), cc(g.stone), segRect(hip, kn, 17), shade: g.stoneD, lw: 2.6);
    final t1 = Offset.lerp(hip, kn, .35)!, t2 = Offset.lerp(hip, kn, .55)!;
    rp.fill(segBox(t1, t2, 17, 16, 3), cc(g.stoneL), segRect(t1, t2, 18), shade: g.stone, lw: 1.8, noHT: true);
    rp.fill(ovalP(kn.dx + 2, kn.dy, 13.5, 12.5), cc(g.stoneL), Rect.fromCenter(center: kn, width: 28, height: 26), shade: g.stoneD, lw: 2.4);
    rp.fill(segBox(kn, an, 14, 12.5, 4.5), cc(g.stone), segRect(kn, an, 15), shade: g.stoneD, lw: 2.6);
    if (!sil && !back) {
      _moss(c, ovalP(kn.dx + 2, kn.dy, 13.5, 12.5), [(kn.dx - 2, kn.dy - 8, 8.0, 4.0, 0.0)], g, flowers: false);
    }
    c.save();
    c.translate(an.dx, an.dy + 2);
    c.rotate(footAngle(j, p, back));
    c.scale(1.2, 1.2);
    rp.fill(_footP, cc(g.stone), const Rect.fromLTRB(-15, -18, 34, 9), shade: g.stoneD, lw: 2.2);
    if (!sil) {
      rp.detail((pa) => pa
        ..moveTo(21, -4)
        ..lineTo(21, 7)
        ..moveTo(27, -3)
        ..lineTo(27, 7), w: 1.2);
    }
    c.restore();
  }

  void _head(RigPainter rp, Joints j, KPose p, _GL g, double glow, double f) {
    final c = rp.c;
    final sil = rp.sil != null;
    rp.limb(j.neck, Offset(j.head.dx - 6, j.head.dy + 14), 11, 10, g.stoneD, noHT: true, lw: 2);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.35, 1.35);
    // Moss crown with a few flowers, behind the carved face.
    rp.fill(_headP, g.stone, const Rect.fromLTRB(-15, -23, 19, 20), shade: g.stoneD, lw: 2);
    if (!sil) {
      _moss(c, _headP, const [(-6.0, -16.0, 14.0, 6.0, -.1), (-13.0, 2.0, 4.0, 8.0, 0.0)], g, flowers: true);
      rp.fill(_browP, g.stoneL, const Rect.fromLTRB(1, -12, 20, -5), shade: g.stoneD, lw: 1.4, noHT: true);
      // Calm eyes: amber slits glowing from under the brow.
      final ea = (.7 + .3 * glow).clamp(0.0, 1.0);
      if (rp.paint) {
        drawGlow(c, const Offset(9, -3), 8, withA(g.rune, .8 * ea));
        drawGlow(c, const Offset(15.5, -3.4), 5, withA(g.rune, .6 * ea));
      }
      fillC(c, ovalP(9.2, -3, 3.4, 1.7, .08), withA(g.runeHot, ea));
      fillC(c, ovalP(15.6, -3.4, 2, 1.3, .08), withA(g.runeHot, ea));
      if (rp.cel) strokeC(c, ovalP(9.2, -3, 3.4, 1.7, .08), .8, kInk);
      rp.detail((pa) => pa
        ..moveTo(10, 1)
        ..lineTo(12.5, 8)
        ..lineTo(9.5, 9)
        ..moveTo(7, 12.5)
        ..quadraticBezierTo(12, 14.5, 16, 11.5)
        ..moveTo(1, -1)
        ..quadraticBezierTo(2, 4, 0, 8), w: 1.3);
      // A small rune carved on the brow.
      fillC(c, Path()..moveTo(11, -17)..lineTo(13.5, -14.5)..lineTo(11, -12)..lineTo(8.5, -14.5)..close(), withA(g.rune, ea));
    }
    c.restore();
  }

  // ================================================================ moves

  /// [keys] with the rune glow (`sx`) lit exactly while the move's armour holds.
  List<Key> _armored(MoveDef m, List<Key> keys) {
    if (m.armorHits <= 0) return keys;
    final out = <Key>[];
    final as = m.armorStart, ae = m.armorEnd;
    KPose lit(KPose p, double v) => KPose.from(p, sx: v);
    final all = <(int, KPose, int)>[for (final k in keys) (k.f, k.p, k.ease)];
    final extra = <int>[as, ae];
    for (final f in extra) {
      if (!all.any((e) => e.$1 == f)) all.add((f, evalKeys(keys, f.toDouble()), 0));
    }
    all.sort((a, b) => a.$1.compareTo(b.$1));
    for (final e in all) {
      final inside = e.$1 >= as && e.$1 < ae;
      out.add(Key(e.$1, lit(e.$2, inside ? 1 : 0), e.$3));
    }
    return out;
  }

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = _idle;
    final q = Pq(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    MoveAnim armored(List<Key> k, {Jt? smear, int sA = 0, int sB = 0}) =>
        MoveAnim(_armored(m, k), smear: smear, smearA: sA, smearB: sB);
    switch (m.name) {
      case 'standLight':
        final x = lunge(id, m, q(fu: 1.5, ff: 1.55, lean: .3, rx: 8, bu: .8, bf: 2.0), Jt.fHa);
        return MoveAnim(strike(m, I, q(fu: .3, ff: 2.3, lean: .1), x), smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(id, m, q(bu: 1.5, bf: 1.55, baf: 1, lean: .34, rx: 8, fu: .7, ff: 2.0), Jt.bHa);
        return MoveAnim(strike(m, I, q(bu: .2, bf: 2.5, baf: 1, lean: .1), x), smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        final x = lunge(id, m, q(fu: 1.2, ff: .9, bu: 1.1, bf: .9, baf: 1, lean: .7, rx: 12, head: .2), Jt.fHa);
        return armored(
            strike(m, I, q(fu: 2.9, ff: 3.05, bu: 2.8, bf: 3.0, baf: 1, lean: -.2, rx: -5), x, hold: KPose.from(x, lean: .75), windAt: .6),
            smear: Jt.fHa, sA: s - 4, sB: s + a + 2);
      case 'standFinisher':
        final x = lunge(id, m, KPose.from(pKickX, ft: .2, fu: 1.0, ff: 1.5), Jt.bAn);
        return MoveAnim(strike(m, I, KPose.from(pKickC, fu: .9, ff: 2.0), x, windAt: .55), smear: Jt.bAn, smearA: s - 4, smearB: s + a + 2);
      case 'rockThrow':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final scoop = q(lean: .45, ft: .9, fs: -.3, bt: -.2, bs: -.6, fu: .6, ff: 1.2, bu: .55, bf: 1.15, baf: 1, sa: .5, open: 1);
        final over = q(fu: 2.9, ff: 3.0, bu: 2.8, bf: 2.95, baf: 1, lean: -.18, head: -.1, sa: 1, open: 1, rx: -3);
        final thr = q(fu: 1.55, ff: 1.5, bu: 1.45, bf: 1.45, baf: 1, lean: .5, rx: 10, sa: 0, open: 1);
        return armored(
            mono([
              Key(0, I),
              Key(mx(1, rd(sp * .3)), scoop),
              Key(mx(2, sp - 3), over),
              Key(sp, thr, 1),
              Key(sp + rd((t - sp) * .45), KPose.from(thr, lean: .45)),
              Key(mx(t, sp + 4), I),
            ]));
      case 'stoneShoulder':
        final wind = q(lean: .45, fu: 1.9, ff: 2.4, bu: 1.2, bf: 2.0, ft: .8, fs: -.1, bt: -.5, bs: -.5, rx: -4);
        final ram = q(lean: .9, head: .3, fu: 2.1, ff: 2.7, bu: -.5, bf: -.2, ft: 1.0, fs: .0, bt: -.9, bs: -.9, rx: 6);
        return armored(
            mono([
              Key(0, I),
              Key(mx(1, s - 6), wind),
              Key(s, ram, 1),
              Key(s + a, ram),
              Key(s + a + rd(r * .5), q(lean: .4, ft: .7, fs: -.1)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.fSh, sA: s - 1, sB: s + a + 1);
      case 'groundSlam':
        final over = q(fu: 3.05, ff: 3.1, bu: 2.95, bf: 3.05, baf: 1, lean: -.2, ft: .55, fs: -.05, bt: -.3, bs: -.3, rx: -4, head: -.1);
        final slam = q(fu: 1.05, ff: .5, bu: .95, bf: .45, baf: 1, lean: .85, head: .25, ft: .85, fs: -.1, bt: -.5, bs: -.4, rx: 10);
        return armored(
            mono([
              Key(0, I),
              Key(mx(1, s - 8), over),
              Key(mx(2, s - 2), KPose.from(over, lean: -.26)),
              Key(s + 1, slam, 1),
              Key(s + a, slam),
              Key(s + a + rd(r * .5), q(lean: .5, ft: .7, fs: -.1, fu: 1.1, ff: 1.3)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.fHa, sA: s - 3, sB: s + 6);
      case 'crushGrab':
        final reach = q(fu: 1.5, ff: 1.4, bu: 1.4, bf: 1.3, baf: 1, lean: .45, rx: 10, open: 1);
        final grip = KPose.from(reach, open: 0, lean: .5, rx: 12);
        final lift = q(fu: 2.9, ff: 3.0, bu: 2.8, bf: 2.9, baf: 1, lean: -.2, rx: 4, head: -.1, sx: 1);
        final slam = q(fu: 1.0, ff: .6, bu: .95, bf: .55, baf: 1, lean: .8, rx: 14, head: .25, sx: 1);
        final g0 = s + a;
        return armored(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), q(fu: 1.0, ff: 1.7, bu: .9, bf: 1.8, baf: 1, lean: .3, open: 1)),
              Key(s, reach, 1),
              Key(g0 + 2, grip),
              Key(g0 + 10, lift, 1),
              Key(g0 + 16, lift),
              Key(g0 + 22, slam, 1),
              Key(g0 + 30, slam),
              Key(mx(t, g0 + 31), I),
            ]),
            smear: Jt.fHa, sA: s - 1, sB: s + a);
      case 'cataclysm':
        final gather = q(lean: .3, ft: .95, fs: -.3, bt: -.2, bs: -.7, fu: 1.0, ff: 1.6, bu: .9, bf: 1.7, baf: 1, sx: 1);
        final up = q(fu: 3.05, ff: 3.1, bu: 2.95, bf: 3.05, baf: 1, lean: -.28, ry: 26, rx: -4, head: -.15, ft: .8, fs: .2, bt: .3, bs: -.1, sx: 1);
        final slam = q(fu: 1.0, ff: .45, bu: .95, bf: .4, baf: 1, lean: .9, head: .3, ft: .9, fs: -.1, bt: -.5, bs: -.4, rx: 10, sx: 1);
        return armored(
            mono([
              Key(0, I),
              Key(6, gather),
              Key(mx(7, s - 4), up, 1),
              Key(mx(8, s - 1), KPose.from(up, lean: -.32)),
              Key(s, slam, 1),
              Key(s + a, slam),
              Key(s + a + rd(r * .5), q(lean: .5, ft: .7, fs: -.1, sx: .0)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.fHa, sA: s - 3, sB: s + 6);
    }
    return null;
  }

  // ================================================================ projectiles

  @override
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) {
    if (!def.name.startsWith('Boulder')) return false;
    final ex = def.name.contains('EX');
    // Dust shed behind the rolling stone.
    for (var i = 0; i < 4; i++) {
      final k = i / 4;
      dotC(c, Offset(-13 - i * 5.0, 5 + math.sin(age * .4 + i) * 1.5), 2 + k * 4, withA(const Color(0xFFC9B99C), (1 - k) * (look == FightLook.painted ? .45 : .85)));
    }
    _drawBoulder(c, look, ex ? 14.5 : 13, _GL.base, age * .13, glow: ex ? 1 : 0);
    return true;
  }

  // ================================================================ move fx

  void _spikes(Canvas c, FightLook look, _GL g, double reach, double age, double life, int seed, {double hMax = 46, double step = 24, double speed = 4.5}) {
    final r = SRand(seed);
    // A glowing crack runs along the ground ahead of the spikes.
    final front = math.min(reach, age * speed * 4.2);
    final double fa = (1 - math.max(0.0, (age - life * .6) / (life * .4))).clamp(0.0, 1.0).toDouble();
    if (look == FightLook.painted) {
      plusLine(c, const Offset(0, -1.5), Offset(front, -1.5), 3, withA(g.rune, .8 * fa));
      drawGlow(c, Offset(front, -2), 16, withA(g.rune, .6 * fa));
    } else {
      lineC(c, const Offset(0, -1.5), Offset(front, -1.5), 3.4, withA(g.rune, fa));
      if (look == FightLook.cartoon) lineC(c, const Offset(0, -1.5), Offset(front, -1.5), 1, withA(g.runeHot, fa));
    }
    for (var x = 18.0, i = 0; x < reach; x += step, i++) {
      final h = hMax * (.55 + r.next() * .45), w = 10 + r.next() * 7;
      final t0 = x / (speed * 4.2);
      final ag = age - t0;
      if (ag < 0) continue;
      final up = math.min(1.0, ag / 3), down = ag > life * .5 ? math.max(0.0, 1 - (ag - life * .5) / (life * .5)) : 1.0;
      final hh = h * up * down;
      if (hh < 2) continue;
      final lean = (r.next() - .5) * .5;
      final spike = Path()
        ..moveTo(x - w, 0)
        ..lineTo(x - w * .3 + lean * hh * .5, -hh)
        ..lineTo(x + w * .2 + lean * hh * .5, -hh * .8)
        ..lineTo(x + w, 0)
        ..close();
      fillC(c, spike, g.stone);
      fillC(c, Path()..moveTo(x, 0)..lineTo(x + w * .2 + lean * hh * .5, -hh * .8)..lineTo(x + w, 0)..close(), g.stoneD);
      if (look == FightLook.cartoon) strokeC(c, spike, 2, kInk);
      if (look == FightLook.painted) plusStroke(c, Path()..moveTo(x - w * .6, -hh * .1)..lineTo(x - w * .3 + lean * hh * .4, -hh * .9), 1.2, withA(g.runeHot, .35 * fa));
    }
  }

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final x = FxCtx(cam, s, player);
    final m = x.move;
    if (m == null) return;
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final g = alt ? _GL.alt : _GL.base;
    final dust = alt ? const Color(0xFF9A94A6) : const Color(0xFFC9B99C);
    final sf = x.sf, st = m.startup;
    switch (m.name) {
      case 'stoneShoulder':
        if (sf >= st - 6 && sf < st + m.active + 6) {
          // Dust and chips kicked up behind her heels.
          x.at(c, x.world(-10, 0), x.k, () {
            puffs(c, look, (sf - st + 6) % 20, sf ~/ 3 + 3, 8, 30, 20, dust, r0: 4, grow: 9);
            final r = SRand(sf);
            for (var i = 0; i < 5; i++) {
              fillC(c, roundPoly([Offset(-4 - r.next() * 30, -2 - r.next() * 18), Offset(-1 - r.next() * 30, -4 - r.next() * 18), Offset(-3 - r.next() * 30, 0 - r.next() * 18)], .8), g.stoneL);
            }
          });
        }
        break;
      case 'groundSlam':
        {
          final w2 = m.windows.length > 1 ? m.windows[1] : m.windows.first;
          final age = sf - w2.start + 2.0;
          final reach = (w2.box.x + w2.box.w) / unitsPerPx;
          if (age >= 0 && age < 18) {
            x.at(c, x.world(0, 0), x.k, () => _spikes(c, look, g, reach, age, 18, 11));
            x.at(c, x.world(60, 0), x.k, () {
              puffs(c, look, age.toInt(), 3, 10, 40, 22, dust, r0: 4, grow: 10, life: 18);
              groundRing(c, look, 20 + age * 8, 3, g.rune, 1 - age / 18);
            });
          }
        }
        break;
      case 'crushGrab':
        {
          final slam = st + m.active + 22;
          final age = sf - slam;
          if (age >= -1 && age < 16) {
            x.at(c, x.world(70, 0), x.k, () {
              puffs(c, look, math.max(0, age), 5, 12, 46, 26, dust, r0: 4, grow: 10, life: 16);
              groundRing(c, look, 14 + age * 9, 3, g.rune, 1 - age / 16);
              final cr = Path()
                ..moveTo(-30, -1)
                ..lineTo(-8, 3)
                ..lineTo(0, -1)
                ..lineTo(20, 4)
                ..lineTo(44, 0);
              if (look == FightLook.painted) {
                plusStroke(c, cr, 2.6, withA(g.rune, 1 - age / 16));
              } else {
                strokeC(c, cr, 3, withA(g.rune, 1 - age / 16));
              }
            });
          }
        }
        break;
      case 'cataclysm':
        {
          final w2 = m.windows.length > 1 ? m.windows[1] : m.windows.first;
          if (sf < st) {
            // Stones lift from the ground around her as the runes flare.
            final k = sf / st;
            x.at(c, x.world(0, 0), x.k, () {
              final r = SRand(11);
              for (var i = 0; i < 9; i++) {
                final px = -70 + r.next() * 170, rise = (r.next() * .6 + .4) * 70 * k, ph = r.next() * 6;
                c.save();
                c.translate(px, -rise - 6 + math.sin(sf * .1 + ph) * 2);
                c.rotate(ph + sf * .05);
                final st0 = 5 + r.next() * 5;
                fillC(c, roundPoly([Offset(-st0, -st0 * .6), Offset(st0, -st0 * .8), Offset(st0 * .8, st0 * .7), Offset(-st0 * .9, st0)], 1.5), g.stoneL);
                if (look == FightLook.cartoon) strokeC(c, roundPoly([Offset(-st0, -st0 * .6), Offset(st0, -st0 * .8), Offset(st0 * .8, st0 * .7), Offset(-st0 * .9, st0)], 1.5), 1.6, kInk);
                c.restore();
              }
            });
          }
          final age = sf - w2.start + 2.0;
          if (age >= 0 && age < 26) {
            // The wave runs both ways across the whole arena.
            x.at(c, x.world(0, 0), x.k, () => _spikes(c, look, g, 430, age, 26, 5, hMax: 70, step: 28, speed: 7));
            x.at(c, x.world(0, 0), x.k, () {
              c.scale(-1, 1);
              _spikes(c, look, g, 430, age, 26, 8, hMax: 70, step: 28, speed: 7);
            });
            x.at(c, x.world(0, 0), x.k, () {
              puffs(c, look, age.toInt(), 9, 16, 90, 40, dust, r0: 6, grow: 14, life: 26);
              groundRing(c, look, 30 + age * 18, 4, g.rune, 1 - age / 26);
            });
          } else if (sf >= st && sf < w2.start) {
            x.at(c, x.world(40, 0), x.k, () {
              puffs(c, look, sf - st, 4, 10, 50, 26, dust, r0: 4, grow: 10, life: 16);
              groundRing(c, look, 16 + (sf - st) * 10, 4, g.rune, 1 - (sf - st) / 12);
            });
          }
        }
        break;
    }
  }
}
