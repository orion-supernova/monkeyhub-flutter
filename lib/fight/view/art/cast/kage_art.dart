// KAGE (he): a ghost samurai. A pale spectral body (low-alpha fills + glow),
// legs that fade into wisps like NYX's, dark lacquered armour floating on him
// (do, sode, kote, kabuto with a crescent crest), glowing white eyes and a
// katana. Channels: `sx` >= .5 = the blade is drawn (else sheathed at the
// hip), `sa` = blade angle (radians, unrotated pelvis frame), `al` = fade.
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

class _KG {
  final Color ghost, ghostD, hakama, hakamaD, armor, armorL, trim, glow, wisp;
  const _KG(this.ghost, this.ghostD, this.hakama, this.hakamaD, this.armor, this.armorL, this.trim, this.glow, this.wisp);
  static final base = _KG(hex(0xc4e4ff), hex(0x6f9fd8), hex(0x3a5aa8), hex(0x24397a), hex(0x1a1d34), hex(0x3c4378), hex(0xe4f0ff),
      hex(0xffffff), hex(0x9fd0ff));
  /// Mirror match: a rose-lilac ghost in blood-red lacquer with amber light.
  static final alt = _KG(hex(0xf2cdf0), hex(0xa874c0), hex(0x7a2a5a), hex(0x4a1438), hex(0x3a0f1a), hex(0x7a2a3a), hex(0xffd9a0),
      hex(0xffe8a8), hex(0xf0a0d8));
}

const double _bodyA = .66;
const double kBlade = 94;

final KPose _idle = KPose.from(pIdle,
    lean: .1, head: -.04, fu: .05, ff: .75, bu: .12, bf: .5, ft: .34, fs: .04, bt: -.24, bs: -.1);

final Path _kimono = roundPoly(const [
  Offset(-11, 3), Offset(-15, -20), Offset(-16, -46), Offset(-8, -61), Offset(8, -61), Offset(15, -46), Offset(13, -20), Offset(11, 3),
], 6);
final Path _do = roundPoly(const [
  Offset(-14, -18), Offset(-18, -48), Offset(-9, -59), Offset(9, -59), Offset(18, -48), Offset(14, -18), Offset(8, -12), Offset(-8, -12),
], 4);
final Path _kabuto = roundPoly(const [
  Offset(-17, 1), Offset(-16, -15), Offset(-7, -26), Offset(8, -26), Offset(16, -17), Offset(18, -8), Offset(3, -9), Offset(-3, 1),
], 6);
final Path _brim = roundPoly(const [Offset(7, -13), Offset(21, -10), Offset(20, -5), Offset(5, -8)], 1.5);
final Path _mask = roundPoly(const [Offset(3, 9), Offset(15, 6.5), Offset(15.5, 11), Offset(9, 17), Offset(2, 15)], 2.5);
final Path _face = ovalP(3, 1, 12.5, 15);

class KageArt extends CastArt {
  const KageArt();

  @override
  int get id => 17;

  @override
  RigDims get dims => const RigDims(17, 62, 32, 30, 36, 30, 1.18, 9, 6, 21, 3);

  @override
  KPose get idle => _idle;

  @override
  bool get floats => true;

  @override
  double get floatHeight => 12;

  @override
  double get portraitWidth => 130;

  @override
  KPalette get palette => KPalette(
      skin: hex(0xc4e4ff), hair: hex(0x1a1d34), tip: hex(0xe4f0ff), vest: hex(0x3a5aa8), tank: hex(0x1a1d34),
      pants: hex(0x3a5aa8), pad: hex(0x3c4378), wrap: hex(0xe4f0ff), shoe: hex(0x9fd0ff), sole: hex(0x6f9fd8), accent: hex(0xffffff));

  @override
  KPalette get altPalette => KPalette(
      skin: hex(0xf2cdf0), hair: hex(0x3a0f1a), tip: hex(0xffd9a0), vest: hex(0x7a2a5a), tank: hex(0x3a0f1a),
      pants: hex(0x7a2a5a), pad: hex(0x7a2a3a), wrap: hex(0xffd9a0), shoe: hex(0xf0a0d8), sole: hex(0xa874c0), accent: hex(0xffe8a8));

  @override
  ({Offset sTip, Offset sEnd, Offset mid})? joints(Joints j, KPose p) =>
      (sTip: j.fHa + polar(p.sa, kBlade), sEnd: j.fHa - polar(p.sa, 14), mid: j.fHa);

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final q = Pq(_idle);
    return (
      q(sx: 1, sa: -2.5, fu: 2.7, ff: 2.9, lean: -.1, rx: -3),
      q(sx: 1, sa: .7, fu: 1.4, ff: 1.5, lean: .5, rx: 14),
      q(sx: 1, sa: -.9, fu: 1.2, ff: 2.0, lean: .15),
    );
  }

  // ================================================================ paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final g = alt ? _KG.alt : _KG.base;
    final c = rp.c;
    final sil = rp.sil != null;
    final bob = math.sin(frame * .08) * 1.6;
    if (!sil) _souls(rp, j, g, frame);
    _sheath(rp, p, g, frame);
    if (p.baf < .5) _arm(rp, j, true, p, g, bob);
    _leg(rp, j, true, p, g, frame);
    _torso(rp, p, g, bob, frame);
    _leg(rp, j, false, p, g, frame);
    if (p.blf >= .5) _leg(rp, j, true, p, g, frame);
    _head(rp, j, p, g, frame, bob);
    if (p.baf >= .5) _arm(rp, j, true, p, g, bob);
    _arm(rp, j, false, p, g, bob);
    if (p.sx >= .5) _blade(rp, j, p, g, frame);
    if (!sil && rp.paint) {
      // A cold halo behind the whole spirit.
      drawGlow(c, Offset(j.c.dx - 2, j.c.dy), 70, withA(g.wisp, .16));
    }
  }

  void _souls(RigPainter rp, Joints j, _KG g, double f) {
    final c = rp.c;
    for (var i = 0; i < 2; i++) {
      final a = f * .035 + i * math.pi;
      final o = Offset(j.c.dx - 30 + math.cos(a) * 18, j.c.dy - 30 + math.sin(a) * 40 - 8 * i);
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(-math.pi / 2 + math.sin(f * .2 + i) * .3);
      drawFlame(c, rp.look, 9, 2.6, f.toInt(), i, outer: withA(g.ghostD, .7), mid: withA(g.wisp, .8), core: g.glow, alpha: .8, ink: 1);
      c.restore();
    }
  }

  void _sheath(RigPainter rp, KPose p, _KG g, double f) {
    final c = rp.c;
    final sil = rp.sil != null;
    c.save();
    c.rotate(p.lean);
    final saya = segBox(const Offset(30, -3), const Offset(-46, 15), 3.6, 2.8, 1.6);
    rp.fill(saya, g.armor, const Rect.fromLTRB(-48, -8, 32, 18), shade: g.armorL, lw: 1.8, noHT: true);
    if (!sil) {
      lineC(c, const Offset(-44, 14.6), const Offset(-36, 12.9), 3, g.trim);
      lineC(c, const Offset(24, -1.8), const Offset(20, -.9), 2, g.trim);
      if (p.sx < .5) {
        // The tsuka and guard, hand-wrapped, sticking forward of the belt.
        final tsuka = segBox(const Offset(30, -3), const Offset(46, -6.5), 2.6, 2.6, 1);
        rp.fill(tsuka, g.armorL, const Rect.fromLTRB(28, -10, 48, 2), noHT: true, lw: 1.4);
        for (var i = 0; i < 3; i++) {
          lineC(c, Offset(34 + i * 4.3, -5.4 - i * .7), Offset(35.6 + i * 4.3, -.9 - i * .7), 1, g.trim);
        }
        rp.fill(ovalP(30, -3, 1.9, 5.8, .22), g.trim, const Rect.fromLTRB(27, -9, 33, 3), noHT: true, lw: 1.2);
      }
    }
    c.restore();
  }

  void _torso(RigPainter rp, KPose p, _KG g, double bob, double f) {
    final c = rp.c;
    final sil = rp.sil != null;
    c.save();
    c.rotate(p.lean);
    rp.fill(rrPath(-13, -2, 26, 12, 4), withA(g.hakama, .9), const Rect.fromLTRB(-13, -2, 13, 10), shade: g.hakamaD, lw: 1.6, noHT: true);
    rp.fill(_kimono, withA(g.ghost, _bodyA), const Rect.fromLTRB(-16, -61, 15, 3), shade: withA(g.ghostD, _bodyA));
    rp.fill(rrPath(-14, -9, 28, 7.5, 2), withA(g.trim, .85), const Rect.fromLTRB(-14, -9, 14, -1), noHT: true, lw: 1.6, shade: g.ghostD);
    // Hip plates hang loose below the do.
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(0, bob * (.6 + i * .15));
      rp.fill(rrPath(-15 + i * 10, -3, 9, 15, 2), g.armor, Rect.fromLTWH(-15.0 + i * 10, -3, 9, 15), shade: g.armorL, lw: 1.6, noHT: true);
      c.restore();
    }
    c.save();
    c.translate(0, bob * .5);
    rp.fill(_do, g.armor, const Rect.fromLTRB(-18, -59, 18, -12), shade: g.armorL);
    if (!sil) {
      rp.detail((pa) {
        for (var y = -50.0; y < -14; y += 7.5) {
          pa.moveTo(-15, y);
          pa.quadraticBezierTo(0, y + 2, 15, y);
        }
      }, w: 1.1, col: rp.paint ? withA(g.trim, .45) : g.armorL);
      lineC(c, const Offset(0, -57), const Offset(0, -14), 1.3, withA(g.trim, .8));
      // A small glowing mon on the chest.
      if (rp.paint) drawGlow(c, const Offset(7, -42), 9, withA(g.glow, .55));
      dotC(c, const Offset(7, -42), 3, g.trim);
      ringC(c, const Offset(7, -42), 3, 1, g.armor);
    }
    c.restore();
    c.restore();
  }

  void _leg(RigPainter rp, Joints j, bool back, KPose p, _KG g, double f) {
    final c = rp.c;
    final sil = rp.sil != null;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    final col = back ? dk(g.hakama, .3) : g.hakama;
    rp.limb(hip, kn, 11.5, 9.5, withA(col, .92), bulge: 2.4, shade: g.hakamaD);
    // Below the knee the robe thins into a curling wisp.
    final curl = math.sin(f * .12 + (back ? 1 : 0)) * 4;
    final pts = cubic(kn, Offset.lerp(kn, an, .5)!, Offset(an.dx - 4, an.dy - 2), Offset(an.dx - 14 + curl, an.dy - 10), 10);
    final wisp = tube(pts, 9, .6);
    if (sil) {
      rp.fill(wisp, col, boundsOf(pts, 10));
    } else {
      gradFill(c, wisp, kn, an, [withA(col, .9), withA(g.ghostD, 0)]);
      if (rp.cel) {
        // A pale hem line where the cloth is still solid.
        final h = Path()
          ..moveTo(kn.dx - 8, kn.dy + 1)
          ..lineTo(kn.dx + 8, kn.dy + 1);
        strokeC(c, h, 1.6, withA(g.trim, .7));
      }
      for (var i = 0; i < 3; i++) {
        final t = (f * .02 + i / 3 + (back ? .15 : 0)) % 1.0;
        dotC(c, Offset(an.dx - 2 + i * 3 - t * 8, an.dy - 2 - t * 20), (1 - t) * 2.6 + .4, withA(g.wisp, (1 - t) * .8));
      }
    }
  }

  void _arm(RigPainter rp, Joints j, bool back, KPose p, _KG g, double bob) {
    final c = rp.c;
    final sil = rp.sil != null;
    final sh = back ? j.bSh : j.fSh, el = back ? j.bEl : j.fEl, wr = back ? j.bWr : j.fWr;
    final gc = back ? dk(g.ghost, .22) : g.ghost;
    rp.limb(sh, el, 8.4, 6.6, withA(gc, _bodyA), bulge: 2, shade: withA(g.ghostD, _bodyA));
    rp.limb(el, wr, 6.6, 4.8, withA(gc, _bodyA), bulge: 1.6, shade: withA(g.ghostD, _bodyA));
    // Kote: a floating armoured sleeve around the forearm.
    final k0 = Offset.lerp(el, wr, .12)!, k1 = Offset.lerp(el, wr, .86)!;
    rp.fill(segBox(k0, k1, 6.6, 6, 2.5), back ? dk(g.armor, .1) : g.armor, segRect(k0, k1, 8), shade: g.armorL, lw: 1.6, noHT: true);
    if (!sil) lineC(c, Offset.lerp(k0, k1, .5)!, Offset.lerp(k0, k1, .5)!, 0, g.trim);
    // The hand: a pale fist, wrapped.
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    if (p.open > .5) {
      rp.fill(rrPath(-1, -5, 11, 10, 3.5), withA(gc, .95), const Rect.fromLTRB(-1, -5, 10, 5), noHT: true, lw: 1.6);
      for (var i = 0; i < 4; i++) {
        rp.limb(Offset(8, -4 + i * 2.7), Offset(15, -5 + i * 3.1), 1.5, 1.2, withA(gc, .95), lw: 1.2, noHT: true);
      }
    } else {
      rp.fill(rrPath(-2, -5.8, 13, 11.6, 5), withA(gc, .95), const Rect.fromLTRB(-2, -6, 11, 6), noHT: true, lw: 1.8);
      if (!sil) rp.detail((pa) => pa..moveTo(7, -5)..lineTo(7, 5), w: 1);
    }
    c.restore();
    // Sode: three floating shoulder plates.
    c.save();
    c.translate(sh.dx - 2, sh.dy - 4 + bob * .8);
    c.rotate(back ? -.1 : .05);
    for (var i = 0; i < 3; i++) {
      final r = rrPath(-10 + i * .8, -3 + i * 6.2, 20 - i * 1.2, 7, 2);
      rp.fill(r, back ? dk(g.armor, .1) : g.armor, Rect.fromLTWH(-10, -3 + i * 6.2, 20, 7), shade: g.armorL, lw: 1.6, noHT: true);
      if (!sil) lineC(c, Offset(-8, 2.6 + i * 6.2), Offset(8, 2.6 + i * 6.2), 1.1, withA(g.trim, .8));
    }
    c.restore();
  }

  void _head(RigPainter rp, Joints j, KPose p, _KG g, double f, double bob) {
    final c = rp.c;
    final sil = rp.sil != null;
    rp.limb(j.neck, Offset(j.head.dx - 3, j.head.dy + 12), 6.5, 6, withA(g.ghost, _bodyA), noHT: true, lw: 1.6);
    c.save();
    c.translate(j.head.dx, j.head.dy + bob * .4);
    c.rotate(j.headA);
    c.scale(1.2, 1.2);
    final wv = math.sin(f * .1) * 3;
    if (!sil) {
      // A tail of spirit hair streaming back out of the helmet.
      final hair = cubic(const Offset(-12, -6), const Offset(-26, -4), Offset(-38, -12 + wv), Offset(-56, 0 + wv), 12);
      gradFill(c, tube(hair, 6, .8), const Offset(-12, 0), const Offset(-56, 0), [withA(g.ghost, .7), withA(g.ghostD, 0)]);
    }
    // Neck guard: stacked plates flaring back.
    for (var i = 0; i < 3; i++) {
      final y = -2 + i * 5.5;
      rp.fill(roundPoly([Offset(-12, y), Offset(-22 - i * 2, y + 7), Offset(-10, y + 9), Offset(-5, y + 3)], 1.5), g.armor,
          Rect.fromLTWH(-24, y, 20, 10), shade: g.armorL, lw: 1.5, noHT: true);
    }
    rp.fill(_face, withA(lt(g.ghost, .12), .96), const Rect.fromLTRB(-10, -14, 16, 16), shade: withA(g.ghostD, .96), lw: 1.8);
    if (!sil) {
      // Eyes: a bright near slit and a smaller far one.
      if (rp.paint) {
        drawGlow(c, const Offset(8, -3), 10, withA(g.glow, .9));
        drawGlow(c, const Offset(14.2, -3.2), 6, withA(g.glow, .7));
      }
      fillC(c, ovalP(8, -3, 3.8, 1.9, -.22), g.glow);
      fillC(c, ovalP(14.2, -3.3, 2.2, 1.4, -.22), g.glow);
      if (rp.cel) {
        strokeC(c, ovalP(8, -3, 3.8, 1.9, -.22), .9, kInk);
      }
      lineC(c, const Offset(2, -8), const Offset(15, -6.2), 2.6, g.armor);
    }
    rp.fill(_mask, g.armor, const Rect.fromLTRB(-1, 1, 17, 17), shade: g.armorL, lw: 1.6, noHT: true);
    if (!sil) {
      rp.detail((pa) => pa
        ..moveTo(5, 13)
        ..quadraticBezierTo(9, 15, 14, 11), w: 1.1, col: withA(g.trim, .85));
    }
    rp.fill(_kabuto, g.armor, const Rect.fromLTRB(-18, -27, 19, 2), shade: g.armorL);
    rp.fill(_brim, g.armorL, const Rect.fromLTRB(5, -14, 22, -4), shade: g.armor, lw: 1.5, noHT: true);
    if (!sil) {
      lineC(c, const Offset(-8, -22), const Offset(-12, -4), 1.2, withA(g.trim, .6));
      lineC(c, const Offset(0, -25), const Offset(-3, -8), 1.2, withA(g.trim, .6));
      // The crescent crest rising over the brow.
      c.save();
      c.translate(9, -24);
      c.rotate(-.55);
      if (rp.paint) drawGlow(c, const Offset(0, -9), 18, withA(g.glow, .5));
      final cr = _crescent(13, 6.5);
      rp.fill(cr, g.trim, const Rect.fromLTRB(-14, -22, 14, 4), shade: g.ghostD, lw: 1.6, noHT: true);
      c.restore();
    }
    c.restore();
  }

  Path _crescent(double r, double th) {
    // Flip so the cusps point up and the belly is below: draw as outer lower arc.
    final q = Path()..moveTo(-r, -r * .1);
    q.arcTo(Rect.fromCircle(center: Offset(0, -r * .1), radius: r), math.pi, -math.pi, false);
    q.arcTo(Rect.fromCenter(center: Offset(0, -r * .1 - th), width: 2 * r * .9, height: 2 * (r - th * .5)), 0, math.pi, false);
    q.close();
    return q;
  }

  void _blade(RigPainter rp, Joints j, KPose p, _KG g, double f) {
    final c = rp.c;
    if (rp.sil != null) return;
    c.save();
    c.translate(j.fHa.dx, j.fHa.dy);
    c.rotate(p.sa);
    final blade = Path()
      ..moveTo(3, -1.9)
      ..quadraticBezierTo(50, -4.8, kBlade, -.4)
      ..lineTo(kBlade - 5, 1.5)
      ..quadraticBezierTo(50, 1.2, 3, 2.1)
      ..close();
    if (rp.paint) {
      for (var i = 0; i < 5; i++) {
        drawGlow(c, Offset(14 + i * 19, -1.5), 12, withA(g.glow, .38));
      }
    }
    fillC(c, blade, const Color(0xFFF4FBFF));
    c.drawLine(const Offset(5, .3), const Offset(kBlade - 8, .1), Paint()..color = withA(g.ghostD, .7)..strokeWidth = .9);
    if (rp.cel) strokeC(c, blade, 1.5, kInk);
    rp.fill(rrPath(-15, -2.8, 16, 5.6, 2.2), g.armorL, const Rect.fromLTRB(-15, -3, 1, 3), noHT: true, lw: 1.4);
    for (var i = 0; i < 3; i++) {
      lineC(c, Offset(-12 + i * 4.3, -2.6), Offset(-10.5 + i * 4.3, 2.6), 1, g.trim);
    }
    rp.fill(ovalP(2, 0, 2, 6.2), g.trim, const Rect.fromLTRB(0, -6, 4, 6), noHT: true, lw: 1.3);
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
        final x = lunge(id, m, q(sx: 1, sa: .12, fu: 1.4, ff: 1.5, lean: .24, rx: 8, ft: .5, bt: -.4), Jt.sTip);
        return MoveAnim(strike(m, I, q(sx: 1, sa: -.5, fu: .7, ff: 1.8, lean: .1), x), smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(id, m, q(sx: 1, sa: -.25, fu: 1.2, ff: 1.4, lean: .3, rx: 10, bu: .5, bf: 2.0), Jt.sTip);
        return MoveAnim(strike(m, I, q(sx: 1, sa: .9, fu: 1.3, ff: 1.6, lean: .1), x), smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        final x = lunge(id, m, q(sx: 1, sa: .95, fu: 1.3, ff: 1.2, bu: 1.1, bf: 1.0, baf: 1, lean: .55, rx: 12, head: .1), Jt.sTip);
        return MoveAnim(
            strike(m, I, q(sx: 1, sa: -2.5, fu: 2.7, ff: 2.9, bu: 2.5, bf: 2.8, baf: 1, lean: -.14, rx: -4), x,
                hold: KPose.from(x, lean: .6, sa: 1.1), windAt: .6),
            smear: Jt.sTip, smearA: s - 4, smearB: s + a + 2);
      case 'standFinisher':
        final x = lunge(id, m, q(sx: 1, sa: .02, fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.5, baf: 1, lean: .5, rx: 14, ft: .9, bt: -.6), Jt.sTip);
        return MoveAnim(strike(m, I, q(sx: 1, sa: .05, fu: .6, ff: 1.9, bu: .5, bf: 1.9, baf: 1, lean: .0, rx: -4), x),
            smear: Jt.sTip, smearA: s - 3, smearB: s + a + 2);
      case 'crouchLight':
        final cr = q(lean: .5, ft: 1.0, fs: -.35, bt: .25, bs: -.95);
        final x = lunge(id, m, KPose.from(cr, sx: 1, sa: .35, fu: 1.4, ff: 1.5), Jt.sTip);
        return MoveAnim(strike(m, I, KPose.from(cr, sx: 1, sa: -.4, fu: .6, ff: 1.9), x, end: cr), smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
      case 'iaido':
        final stance = q(lean: .32, fu: .1, ff: .8, bu: .5, bf: 1.0, ft: .9, fs: -.2, bt: -.4, bs: -.6, head: -.12, rx: 2);
        final ce = m.counterEnd > 0 ? m.counterEnd : s + 20;
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, s - 1), stance),
          Key(ce, KPose.from(stance, lean: .3)),
          Key(mx(t, ce + 1), I),
        ]));
      case 'iaidoStrike':
        final draw = q(sx: 1, sa: .0, fu: 1.5, ff: 1.5, bu: .9, bf: 1.0, baf: 1, lean: .62, ft: .95, fs: .1, bt: -.9, bs: -.6, rx: 8, head: -.1);
        final stance = q(lean: .32, fu: .1, ff: .8, bu: .5, bf: 1.0, ft: .9, fs: -.2, bt: -.4, bs: -.6);
        return MoveAnim(
            mono([
              Key(0, stance),
              Key(s, draw, 1),
              Key(s + a, KPose.from(draw, sa: -.1)),
              Key(s + a + rd(r * .5), q(sx: 1, sa: .6, fu: .8, ff: 1.8, lean: .2)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.sTip, smearA: s - 3, smearB: s + a + 2);
      case 'dashSlash':
        final low = q(lean: .55, ft: 1.0, fs: -.3, bt: .1, bs: -.8, fu: .5, ff: 1.0, sx: 0);
        final cut = q(sx: 1, sa: .05, fu: 1.55, ff: 1.55, bu: 1.2, bf: 1.4, baf: 1, lean: .8, ft: 1.2, fs: .3, bt: -1.0, bs: -.9, head: -.2, rx: 10);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), low),
              Key(s, cut, 1),
              Key(s + a, cut),
              Key(s + a + rd(r * .4), q(sx: 1, sa: .6, lean: .3, fu: .9, ff: 1.7)),
              Key(mx(t, s + a + rd(r * .4) + 1), I),
            ]),
            smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
      case 'shadowSlip':
        final fade = q(lean: .6, ft: 1.2, fs: -.3, bt: .2, bs: -.9, fu: .3, ff: 1.0, al: .35);
        final cut = q(sx: 1, sa: .3, fu: 1.35, ff: 1.5, bu: 1.0, bf: 1.3, baf: 1, lean: .85, ft: 1.3, fs: -.2, bt: .0, bs: -.95, head: -.2, rx: 6);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(2, fade, 2),
              Key(mx(3, s - 2), fade),
              Key(s, cut, 1),
              Key(s + a, cut),
              Key(s + a + rd(r * .5), q(lean: .3, ft: .8, fs: -.2)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.sTip, smearA: s - 1, smearB: s + a + 1);
      case 'risingSlash':
        final low = q(sx: 1, sa: .8, fu: 1.2, ff: 1.3, lean: .5, ft: 1.0, fs: -.3, bt: .2, bs: -.9);
        final up = q(sx: 1, sa: -2.0, fu: 2.8, ff: 3.0, bu: .9, bf: 2.0, lean: -.2, head: -.25, ft: .2, fs: .1, bt: -.1, bs: -.2, rx: 4);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), low),
              Key(s, KPose.from(up, sa: -.6, lean: .1), 1),
              Key(s + rd(a * .5), up, 1),
              Key(s + a, KPose.from(up, sa: -2.3)),
              Key(s + a + rd(r * .5), q(sx: 1, sa: .3, lean: .2, ft: .8, fs: -.2)),
              Key(mx(t, s + a + rd(r * .5) + 1), I),
            ]),
            smear: Jt.sTip, smearA: s - 2, smearB: s + a + 2);
      case 'yuureiRyu':
        final ws = m.windows;
        final vanish = q(sx: 0.0, al: 0.0);
        final keys = <Key>[Key(0, I), Key(3, q(lean: .1, al: .5), 2), Key(5, vanish, 2), Key(mx(6, s - 1), vanish, 2)];
        final sp = ws.isEmpty ? s : ws.first.start;
        keys.add(Key(sp > keys.last.f ? sp : keys.last.f + 1, q(sx: 1, sa: .4, fu: 1.5, ff: 1.5, lean: .3, rx: 6), 2));
        const swings = [
          (.8, -.4), (-.9, .3), (.2, -1.0), (-.5, .7), (1.0, -.2), (-1.2, .5), (.0, -.8), (.9, .1),
        ];
        for (var k = 0; k < ws.length; k++) {
          final last = k == ws.length - 1;
          final sw = swings[k % swings.length];
          final f0 = ws[k].start;
          if (f0 <= keys.last.f) continue;
          keys.add(Key(f0, last
              ? q(sx: 1, sa: 1.0, fu: 1.1, ff: 1.2, bu: 1.0, bf: 1.2, baf: 1, lean: .7, rx: 12)
              : q(sx: 1, sa: sw.$1, fu: 1.4, ff: 1.5, lean: .28 + sw.$2 * .1, rx: 8.0 + k, bu: .5, bf: 2.0), 1));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rd(r * .35), q(sx: 1, sa: .6, lean: .25, fu: 1, ff: 1.7)));
        keys.add(Key(mx(t, tail + rd(r * .35) + 1), I));
        return MoveAnim(mono(keys), smear: Jt.sTip, smearA: s, smearB: tail);
    }
    return null;
  }

  // ================================================================ fx

  /// A crescent of cut light: outer radius [r], thickness [th], from angle
  /// [a0] sweeping [sw] radians (canvas coordinates, +y down).
  static void crescentFx(Canvas c, FightLook look, double r, double th, double a0, double sw, double a, Color col, Color edge) {
    if (a <= 0) return;
    const n = 18;
    final outer = <Offset>[], inner = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n, ang = a0 + sw * t, tk = math.sin(math.pi * t);
      outer.add(polar(ang, r));
      inner.add(polar(ang, r - th * .5 * (.04 + tk * .96)));
    }
    final p = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final o in outer.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    for (final o in inner.reversed) {
      p.lineTo(o.dx, o.dy);
    }
    p.close();
    if (look == FightLook.painted) {
      for (var i = 0; i < 4; i++) {
        final o = outer[3 + i * 4];
        drawGlow(c, o, th * 1.3, withA(edge, .35 * a));
      }
      plusFill(c, p, withA(col, .95 * a));
      plusStroke(c, p, 2, withA(edge, .6 * a));
    } else {
      fillC(c, p, withA(col, a));
      if (look == FightLook.cartoon) strokeC(c, p, 2.4, withA(kInk, a));
    }
  }

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final x = FxCtx(cam, s, player);
    final m = x.move;
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final g = alt ? _KG.alt : _KG.base;
    if (m == null) return;
    final sf = x.sf, st = m.startup;
    final age = sf - st;
    void arc(double cx, double cy, double r, double th, double a0, double sw, double life, {int shift = 0}) {
      final ag = sf - st - shift;
      if (ag < -0 || ag > life) return;
      final o = x.world(cx, cy);
      x.at(c, o, x.k, () {
        // The crescent grows along its sweep, then fades.
        final grow = math.min(1.0, (ag + 1) / 3);
        crescentFx(c, look, r, th, a0, sw * grow, 1 - ag / (life + 1), g.trim, g.wisp);
      });
    }

    switch (m.name) {
      case 'standLight':
        arc(30, 100, 110, 30, -.55, 1.1, 5);
        break;
      case 'standLight2':
        arc(30, 100, 115, 30, .55, -1.1, 5);
        break;
      case 'standHeavy':
        arc(20, 120, 130, 44, -1.9, 2.1, 6);
        break;
      case 'standFinisher':
        arc(-30, 95, 170, 34, -.4, .8, 6);
        break;
      case 'crouchLight':
        arc(30, 40, 100, 24, -.4, .8, 5);
        break;
      case 'iaido':
        if (sf >= m.counterStart && sf <= m.counterEnd) {
          // A cold focus at the hilt: the stance is a waiting snare.
          final o = x.joint(Jt.fHa);
          final pulse = .5 + .5 * math.sin(s.frame * .35);
          x.at(c, o, x.u, () {
            if (look == FightLook.painted) {
              drawGlow(c, Offset.zero, 16 + pulse * 8, withA(g.glow, .5 + pulse * .3));
              plusRing(c, Offset.zero, 12 + pulse * 6, 1.4, withA(g.wisp, .8));
            } else {
              ringC(c, Offset.zero, 9 + pulse * 6, 1.8, withA(g.glow, .9));
              dotC(c, Offset.zero, 2.4, g.glow);
            }
          });
        }
        break;
      case 'iaidoStrike':
        arc(-10, 85, 175, 38, -.5, 1.0, 8);
        if (age >= 0 && age < 7) {
          x.at(c, x.world(-60, 85), x.k, () {
            for (var i = 0; i < 4; i++) {
              final y = -22 + i * 14.0;
              lineC(c, Offset(-20 - i * 8, y), Offset(-110 - i * 12, y), 2, withA(g.glow, .8 * (1 - age / 7)));
            }
          });
        }
        break;
      case 'dashSlash':
        arc(-20, 80, 190, 40, -.5, 1.0, 7);
        if (age >= 0 && age < 8) {
          x.at(c, x.world(-30, 80), x.k, () {
            for (var i = 0; i < 4; i++) {
              final y = -20 + i * 13.0;
              lineC(c, Offset(-10 - i * 10, y), Offset(-90 - i * 14, y), 2, withA(g.wisp, .85 * (1 - age / 8)));
            }
          });
        }
        break;
      case 'shadowSlip':
        arc(-10, 30, 150, 28, -.45, .9, 6);
        break;
      case 'risingSlash':
        arc(0, 60, 105, 36, .9, -2.8, 8);
        arc(0, 60, 125, 30, .6, -2.4, 6, shift: 4);
        break;
      case 'yuureiRyu':
        if (sf < 16) {
          // He dissolves into rising spirit lights.
          final k = sf / 16;
          x.at(c, x.world(0, 70), x.k, () {
            final r = SRand(sf ~/ 2 + 5);
            for (var i = 0; i < 14; i++) {
              final xx = (r.next() - .5) * 60, y = -r.next() * 120 * k - 10;
              dotC(c, Offset(xx, y), 1.6 + r.next() * 2.4, withA(i.isEven ? g.glow : g.wisp, (1 - k * .6) * .9));
            }
          });
        }
        final foe = s.p[1 - player];
        for (var k = 0; k < m.windows.length; k++) {
          final ag = sf - m.windows[k].start;
          if (ag < 0 || ag > 6) continue;
          final r = SRand(k * 13 + 7);
          final o = cam.toScreen(foe.x / unitsPerPx + (r.next() - .5) * 60, foe.y / unitsPerPx + 70 + (r.next() - .5) * 60);
          final ang = (k.isEven ? -.8 : .8) + (r.next() - .5) * 1.2;
          c.save();
          c.translate(o.dx, o.dy);
          c.scale(cam.scale);
          c.rotate(ang);
          crescentFx(c, look, 70, 22, -.9, 1.8, 1 - ag / 7, g.trim, g.wisp);
          c.restore();
        }
        break;
    }
  }
}
