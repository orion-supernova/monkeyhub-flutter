// HANA - fencer. A white jacket with a crimson sash, white breeches and socks,
// her hair in a high ponytail, a rapier held out in an en-garde with the back
// arm raised. The blade is the pose's weapon: `sa` is its angle, joints()
// gives the tip (smear and hit point). Thrusts leave thin glinting lines.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim, poseFor;
import '../roster_poses.dart' show rigScale;
import '../roster_rig.dart' show ellP, tubePath, bbOf, pathOf;
import 'cast_art.dart';
import 'human_kit.dart';

class _HanaCol {
  final Color jacket, jacketD, sash, sashD, hair, hairHi, shoe, steel;
  const _HanaCol(this.jacket, this.jacketD, this.sash, this.sashD, this.hair, this.hairHi, this.shoe, this.steel);
}

final _HanaCol _main = _HanaCol(hex(0xf6f6fa), hex(0xb4b9d0), hex(0xc41e3a), hex(0x7e1024), hex(0x241a33), hex(0x5a4a80),
    hex(0xe8e8ee), hex(0xe4ebf3));
final _HanaCol _alt = _HanaCol(hex(0xdde8f8), hex(0x95a8cc), hex(0xf2b21a), hex(0xa87608), hex(0xcf9a3c), hex(0xf6d98a),
    hex(0x2a3550), hex(0xf0f4fa));

const double _blade = 120;

class HanaArt extends CastArt {
  HanaArt();

  @override
  int get id => 14;
  @override
  RigDims get dims => const RigDims(14, 58, 32, 28, 43, 41, 1.17, 8, 5.5, 21, 3);

  static final KPose _idle = KPose.from(pIdle,
      lean: .1, head: -.05, fu: 1.3, ff: 1.5, bu: -2.0, bf: -3.0, ft: .75, fs: .08, bt: -.7, bs: -.35, sa: -.14);
  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal(_main);
  @override
  KPalette get altPalette => _pal(_alt);
  KPalette _pal(_HanaCol c) => KPalette(
      skin: hex(0xf1cfae), hair: c.hair, tip: c.hairHi, vest: c.sash, tank: c.jacket, pants: c.jacket, pad: c.jacket,
      wrap: c.jacket, shoe: c.shoe, sole: hex(0x2b2633), accent: c.sash, tankShade: c.jacketD);

  @override
  double get portraitWidth => 150;

  @override
  ({Offset sTip, Offset sEnd, Offset mid})? joints(Joints j, KPose p) {
    final d = Offset(math.cos(p.sa), math.sin(p.sa));
    return (sTip: j.fHa + d * (_blade + p.sx), sEnd: j.fHa - d * 10, mid: j.fHa);
  }

  /// The blade follows the forearm for poses borrowed from the generic set.
  @override
  KPose rebase(KPose k) => KPose.from(k, sa: math.pi / 2 - k.ff - .05);

  // ------------------------------------------------------------------ paint

  final Path _hairCap = pathOf((p) => p
    ..moveTo(14.5, -9)
    ..cubicTo(15.5, -19, 6, -28, -4, -26)
    ..cubicTo(-14, -24, -19, -14, -17, -2)
    ..cubicTo(-14, -8, -9, -12, -3, -13)
    ..cubicTo(3, -13.5, 8, -14, 10, -17)
    ..cubicTo(12, -15, 13.5, -12, 14.5, -9));
  final Path _sidelock = pathOf((p) => p
    ..moveTo(-3, -12)
    ..cubicTo(-6, -6, -6, 4, -3, 11)
    ..cubicTo(-1, 8, 0, 0, 1, -11));
  final Path _bell = pathOf((p) => p
    ..moveTo(-3, -9)
    ..quadraticBezierTo(11, -9, 11, 0)
    ..quadraticBezierTo(11, 9, -3, 9)
    ..quadraticBezierTo(2, 0, -3, -9));
  final Path _band = rrPath(-17, -9, 33, 9, 3);

  KPose _live(KPose p, double frame) {
    final ph = math.sin(frame * .13);
    return KPose.from(p, ft: p.ft + ph * .05, bt: p.bt - ph * .05, sa: p.sa + ph * .05, fu: p.fu + ph * .04, bf: p.bf + ph * .05);
  }

  @override
  void paint(RigPainter rp, Joints j0, KPose p0, bool alt, double frame) {
    final c = rp.c;
    final k = alt ? _alt : _main;
    final t = frame * .1;
    var j = j0;
    var p = p0;
    c.save();
    if (isIdleLike(p0, _idle)) {
      p = _live(p0, frame);
      j = fk(p, dims);
      c.translate(0, -(j.maxAn - j0.maxAn) - math.sin(frame * .13).abs() * 1.2);
    }
    final glove = k.jacket;
    final arm = ArmStyle(skin: rp.pal.skin, tape: k.jacket, sleeve: k.jacket, sleeveFrac: .96, glove: glove, girth: .88);
    final armF = ArmStyle(skin: rp.pal.skin, tape: k.jacket, sleeve: k.jacket, sleeveFrac: .96, glove: glove, girth: .88);
    if (p.baf < .5) kitArm(rp, j, p, true, arm, hand: (wr, el) => kitFist(rp, wr, el, rp.pal.skin, null, true));
    if (p.blf < .5) _leg(rp, j, p, true, k);
    _torso(rp, j, p, k, t);
    _leg(rp, j, p, false, k);
    if (p.blf >= .5) _leg(rp, j, p, true, k);
    _head(rp, j, p, k, t);
    if (p.baf >= .5) kitArm(rp, j, p, true, arm, hand: (wr, el) => kitFist(rp, wr, el, rp.pal.skin, null, true));
    final d = Offset(math.cos(p.sa), math.sin(p.sa));
    _blade_(rp, j.fHa, d, p.sx, k, frame);
    kitArm(rp, j, p, false, armF, hand: (wr, el) => kitFist(rp, wr, el, glove, null, false));
    // The bell guard sits in front of the fist.
    final g = j.fHa + d * 9;
    c.save();
    c.translate(g.dx, g.dy);
    c.rotate(p.sa);
    rp.fill(_bell, k.steel, const Rect.fromLTRB(-3, -9, 11, 9), shade: dk(k.steel, .4), noHT: true, lw: 1.8);
    rp.detail((q) => q
      ..moveTo(0, -5)
      ..quadraticBezierTo(6, -4, 7.5, 0)
      ..quadraticBezierTo(6, 4, 0, 5), w: 1, col: k.sash);
    c.restore();
    c.restore();
  }

  void _blade_(RigPainter rp, Offset hand, Offset d, double sx, _HanaCol k, double frame) {
    final c = rp.c;
    final a = hand + d * 12, b = hand + d * (_blade + sx);
    final pom = hand - d * 10;
    final pts = [a, lerpO(a, b, .5), b];
    final bb = bbOf([a, b, pom], 6);
    rp.fill(tubePath(pts, 2.6, 1.0), k.steel, bb, lw: 1.3, noHT: true, shade: dk(k.steel, .35));
    // Grip, pommel.
    rp.fill(limbPath(pom, hand + d * 4, 2.8, 3.2), dk(k.sash, .3), bb, lw: 1.5, noHT: true);
    c.drawCircle(pom - d * 1.5, 3.2, Paint()..color = k.steel);
    if (rp.sil == null) {
      // A glint that travels along the blade.
      final u = ((frame * .03) % 1.0);
      final q = lerpO(a, b, .25 + u * .7);
      final pt = Paint()..color = const Color(0xFFFFFFFF);
      final w = math.sin(u * math.pi);
      c.drawPath(starPath(q.dx, q.dy, 5 * w + .5, 1.2 * w + .2, 4, 0), pt);
    }
  }

  void _torso(RigPainter rp, Joints j, KPose p, _HanaCol k, double t) {
    final c = rp.c;
    rp.fill(pPantsTop, k.jacket, const Rect.fromLTRB(-16, -6, 15, 16), shade: k.jacketD);
    c.save();
    c.rotate(p.lean);
    c.scale(1.06, .97);
    rp.fill(pTorso, k.jacket, const Rect.fromLTRB(-20, -64, 20, 0), shade: k.jacketD);
    // Jacket piping and the side seam.
    rp.detail((q) => q
      ..moveTo(7, -62)
      ..quadraticBezierTo(2, -34, 3, -4), w: 1.3, col: k.jacketD);
    rp.detail((q) => q
      ..moveTo(-14, -42)
      ..quadraticBezierTo(-10, -28, -11, -10), w: 1.1, col: k.jacketD);
    // A small crest on the chest.
    if (rp.sil == null) {
      c.drawCircle(const Offset(9, -43), 3.2, Paint()..color = k.sash);
      c.drawCircle(const Offset(9, -43), 3.2, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = kInk);
    }
    // The sash: a wide band at the waist, a knot at the hip and two tails.
    rp.fill(_band, k.sash, const Rect.fromLTRB(-17, -9, 16, 0), shade: k.sashD, noHT: true, lw: 2);
    final tails = [
      sway(const Offset(-14, -4), 30, -.55, .83, t * 1.1, 5, n: 6),
      sway(const Offset(-13, -3), 24, -.8, .6, t * 1.1 + 1.4, 5, n: 6),
    ];
    for (final tl in tails) {
      rp.fill(tubePath(tl, 3.8, 2.2), k.sash, bbOf(tl, 5), noHT: true, lw: 1.5, shade: k.sashD);
    }
    c.save();
    c.translate(-13, -4.5);
    rp.fill(ellP(0, 0, 5, 4.4), k.sash, const Rect.fromLTRB(-6, -5, 6, 5), noHT: true, lw: 1.6);
    c.restore();
    c.restore();
  }

  void _leg(RigPainter rp, Joints j, KPose p, bool back, _HanaCol k) {
    final c = rp.c;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    final w = back ? dk(k.jacket, .3) : k.jacket;
    // Breeches to just below the knee, then long white socks.
    rp.limb(hip, kn, 11.8, 9.6, w, bulge: 3, shade: k.jacketD);
    rp.limb(kn, an, 8.6, 6.2, w, bulge: 2, shade: k.jacketD);
    rp.limb(lerpO(kn, an, .08), lerpO(kn, an, .2), 9.0, 8.6, back ? dk(k.sash, .3) : k.sash, noHT: true, lw: 2);
    rp.limb(lerpO(kn, an, .8), an, 7, 6.8, back ? dk(k.jacketD, .15) : k.jacketD, noHT: true, lw: 1.8);
    c.save();
    c.translate(an.dx, an.dy);
    c.rotate(footRot(j, p, back));
    final sh = back ? dk(k.shoe, .3) : k.shoe;
    rp.fill(pShoe, sh, const Rect.fromLTRB(-11, -14, 23, 9), shade: dk(k.shoe, .4));
    rp.fill(pSoleBar, back ? dk(rp.pal.sole, .2) : rp.pal.sole, const Rect.fromLTRB(-10, 5, 23, 11), noHT: true);
    if (rp.sil == null) rp.fill(pStripe, back ? dk(k.sash, .3) : k.sash, const Rect.fromLTRB(-3, -6, 17, 3), lw: 1.6, noHT: true);
    c.restore();
  }

  void _head(RigPainter rp, Joints j, KPose p, _HanaCol k, double t) {
    final c = rp.c;
    final skin = rp.pal.skin;
    kitNeck(rp, j, skin);
    // Jacket collar.
    rp.limb(Offset(j.neck.dx - 5, j.neck.dy + 2), Offset(j.neck.dx + 6, j.neck.dy + 1), 5.5, 5.5, k.jacket, noHT: true, lw: 1.8);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.17, 1.17);
    if (rp.sil == null) {
      // The high ponytail, swaying and streaming with the fight.
      final pony = sway(const Offset(-9, -22), 46, -.82, .45, t * 1.1, 8 + p.lean.abs() * 4, n: 9);
      rp.fill(tubePath(pony, 6.2, 1.4), k.hair, bbOf(pony, 8), shade: dk(k.hair, .3), noHT: true, lw: 1.8);
      rp.detail((q) {
        for (var i = 1; i < pony.length - 2; i += 3) {
          q.moveTo(pony[i].dx, pony[i].dy - 1);
          q.lineTo(pony[i + 1].dx, pony[i + 1].dy - 1);
        }
      }, w: 1, col: k.hairHi);
    }
    rp.fill(pHead, skin, const Rect.fromLTRB(-17, -20, 16, 18));
    if (rp.sil == null) {
      c.save();
      c.clipPath(pHead);
      c.drawPath(pHeadShade, Paint()..color = rp.paint ? const Color(0x59281C28) : mixC(skin, k.hair, .3));
      c.restore();
      rp.fill(pEar, dk(skin, .08), const Rect.fromLTRB(-7, -4, 1, 7), lw: 1.6, noHT: true);
    }
    rp.fill(_hairCap, k.hair, const Rect.fromLTRB(-19, -28, 16, -2), shade: dk(k.hair, .3), noHT: true);
    if (rp.sil == null) {
      rp.fill(_sidelock, k.hair, const Rect.fromLTRB(-7, -13, 2, 12), noHT: true, lw: 1.3);
      // The scrunchie.
      c.save();
      c.translate(-9, -22);
      rp.fill(ellP(0, 0, 4, 3.2, -.4), k.sash, const Rect.fromLTRB(-5, -4, 5, 4), noHT: true, lw: 1.4);
      c.restore();
      c.drawPath(pEye, Paint()..color = rp.pal.eye);
      c.drawCircle(const Offset(9.3, -4.6), 1.8, Paint()..color = rp.pal.iris);
      c.drawCircle(const Offset(9.8, -5.2), .6, Paint()..color = const Color(0xFFFFFFFF));
      rp.detail((q) => q
        ..moveTo(3.4, -5.2)
        ..quadraticBezierTo(7.5, -8.6, 12.2, -5.4), w: 2, col: const Color(0xFF140C18));
      rp.detail((q) => q
        ..moveTo(3, -10.6)
        ..quadraticBezierTo(8, -12.4, 12.4, -9.6), w: 1.5, col: k.hair);
      rp.detail((q) => q
        ..moveTo(8.5, 10.8)
        ..quadraticBezierTo(10.6, 11.6, 12.4, 10), w: 1.3, col: const Color(0xFF9A3A4A));
    }
    c.restore();
  }

  // ------------------------------------------------------------------ poses

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final q = poseOf(_idle);
    return (
      q(fu: 1.0, ff: 1.9, sa: -.4, lean: -.02, rx: -4, bu: -2.3, bf: -3.0),
      q(fu: 1.55, ff: 1.57, sa: 0, lean: .5, rx: 14, ft: 1.25, fs: -.05, bt: -1.0, bs: -1.0, bu: -2.2, bf: -2.2),
      q(fu: 1.2, ff: 1.2, sa: .3, lean: .1),
    );
  }

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = _idle;
    final q = poseOf(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    KPose thrust({double lean = .4, double rx = 8, double sa = 0, double ff = 1.57}) => q(
        fu: 1.5, ff: ff, sa: sa, lean: lean, rx: rx, ft: .9, fs: .05, bt: -.75, bs: -.45, bu: -1.5, bf: -2.4);
    KPose lungeP({double rx = 0}) => q(
        fu: 1.55, ff: 1.57, sa: 0, lean: .58, head: -.1, rx: rx, ft: 1.3, fs: -.02, bt: -1.0, bs: -1.0, bu: -2.2, bf: -2.2);
    KPose guard() => q(fu: 1.0, ff: 1.9, sa: -.45, lean: .02, bu: -2.3, bf: -3.0);
    switch (m.name) {
      case 'standLight':
        final x = lunged(m, 14, thrust(), Jt.sTip);
        return MoveAnim(strike(m, I, q(fu: 1.0, ff: 1.9, sa: -.4, lean: .1), x, hold: KPose.from(x, lean: .45)),
            smear: Jt.sTip, smearA: s - 1, smearB: s + a + 1);
      case 'standLight2':
        final x = lunged(m, 14, thrust(lean: .45, sa: -.16, ff: 1.45), Jt.sTip);
        return MoveAnim(strike(m, I, q(fu: .8, ff: 2.1, sa: -.5, lean: .08, bu: -1.6), x, hold: KPose.from(x, lean: .5)),
            smear: Jt.sTip, smearA: s - 1, smearB: s + a + 1);
      case 'standHeavy':
        // An overhead cut: the blade is whipped up behind her head, then down.
        final x = lunged(m, 14, q(fu: 1.35, ff: 1.0, sa: .62, lean: .55, rx: 12, ft: 1.0, fs: .05, bt: -.8, bs: -.5, bu: -1.8, bf: -2.0), Jt.sTip);
        return MoveAnim(
            strike(m, I, q(fu: 2.8, ff: 2.95, sa: -2.5, lean: -.1, rx: -4, bu: -2.4, bf: -3.0), x,
                hold: KPose.from(x, sa: .85, lean: .6), windAt: .65),
            smear: Jt.sTip, smearA: s - 1, smearB: s + a + 2);
      case 'thrustFlurry':
      case 'grandeFleche':
        final big = m.name == 'grandeFleche';
        final ws = m.windows;
        final gap = ws.length > 1 ? ws[1].start - ws[0].start : 3;
        final keys = <Key>[Key(0, I), Key(mx(1, s ~/ 2), big ? q(fu: 1.0, ff: 1.9, sa: -.4, lean: .45, ft: 1.0, fs: -.3, bt: -.5, bs: -.9, bu: -2.3, bf: -3.0) : guard())];
        for (var i = 0; i < ws.length; i++) {
          final last = i == ws.length - 1;
          final jit = const [-.06, .08, -.12, .1, -.02, .12, -.08, .04, -.1][i % 9];
          final stab = last
              ? lungeP(rx: big ? 18 : 12)
              : thrust(lean: .42 + (i.isEven ? 0 : .06), rx: 8 + i * (big ? 1.6 : 1.0), sa: jit, ff: 1.57 + jit * .5);
          keys.add(Key(ws[i].start, stab, 1));
          if (!last) keys.add(Key(ws[i].start + mx(1, gap ~/ 2), KPose.from(stab, fu: 1.25, ff: 1.8, sa: jit - .12, lean: .32)));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rnd(r * .35), q(fu: 1.2, ff: 1.7, sa: -.3, lean: .3, ft: 1.0, fs: -.1, bt: -.7, bs: -.5)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.sTip, smearA: s - 1, smearB: tail);
      case 'lunge':
        final x = lunged(m, 14, lungeP(), Jt.sTip, max: 20);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, rnd(s * .6)), q(fu: 1.0, ff: 1.9, sa: -.4, lean: .3, ft: 1.0, fs: -.25, bt: -.55, bs: -.8, bu: -2.4, bf: -3.0)),
              Key(s, x, 1),
              Key(s + a, x),
              Key(s + a + rnd(r * .35), KPose.from(x, lean: .45, rx: x.rx * .6)),
              Key(mx(t, s + a + rnd(r * .35) + 1), I),
            ]),
            smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
      case 'riposte':
        // The parry: the blade sweeps up and across, then holds.
        final par = q(fu: .9, ff: 1.95, sa: -.95, lean: -.04, ft: .8, fs: .1, bu: -2.3, bf: -3.0);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(2, q(fu: 1.2, ff: 1.7, sa: -.35)),
              Key(4, par, 1),
              Key(mx(5, t - 8), KPose.from(par, sa: -.8)),
              Key(mx(6, t), I),
            ]),
            smear: Jt.sTip, smearA: 0, smearB: 5);
      case 'riposteStrike':
        final x = lunged(m, 14, lungeP(rx: 4), Jt.sTip, max: 24);
        return MoveAnim(
            mono([
              Key(0, q(fu: .9, ff: 1.95, sa: -.95, lean: -.04, ft: .8, fs: .1, bu: -2.3, bf: -3.0)),
              Key(mx(1, s - 1), guard()),
              Key(s, x, 1),
              Key(s + a, x),
              Key(s + a + rnd(r * .4), KPose.from(x, lean: .4)),
              Key(mx(t, s + a + rnd(r * .4) + 1), I),
            ]),
            smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
      case 'risingPoint':
        final up = q(fu: 2.45, ff: 2.6, sa: -1.05, lean: -.08, rx: 5, ft: .9, fs: .08, bt: -.7, bs: -.3, bu: -1.0, bf: -.5, head: -.25);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), q(fu: 1.0, ff: 1.5, sa: .05, lean: .4, ft: 1.0, fs: -.3, bt: -.4, bs: -.8, bu: -2.0, bf: -2.8)),
              Key(s, up, 1),
              Key(s + a, KPose.from(up, lean: -.15, sa: -1.12)),
              Key(s + a + rnd(r * .4), q(fu: 1.6, ff: 2.0, sa: -.5, lean: .1)),
              Key(mx(t, s + a + rnd(r * .4) + 1), I),
            ]),
            smear: Jt.sTip, smearA: s - 1, smearB: s + a + 1);
    }
    return null;
  }

  // ------------------------------------------------------------------ fx

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final f = s.p[player];
    if (f.state != St.move || f.moveId < 0) return;
    final m = s.chars[player].moves[f.moveId];
    const names = {'thrustFlurry', 'lunge', 'grandeFleche', 'riposteStrike', 'risingPoint'};
    if (!names.contains(m.name)) return;
    final active = f.sf >= m.startup - 1 && f.sf <= m.startup + m.active + 2;
    if (!active) return;
    final pose = poseFor(s, player);
    final tip = jointScreen(cam, s, player, Jt.sTip);
    final rs = rigScale(14) * cam.scale;
    final dx = f.face * math.cos(pose.sa), dy = math.sin(pose.sa);
    final nx = -dy, ny = dx;
    final pt = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final alt = s.chars[0].id == s.chars[1].id && player == 1;
    final tint = alt ? const Color(0xFFFFE9A6) : const Color(0xFFBFEFFF);
    final n = m.name == 'grandeFleche' ? 5 : 3;
    for (var i = 0; i < n; i++) {
      final h = hash01(s.frame, i + player * 7);
      final off = (h - .5) * 26 * rs;
      final len = (50 + hash01(i, s.frame) * 70) * rs;
      final a = Offset(tip.dx + nx * off - dx * 8 * rs, tip.dy + ny * off - dy * 8 * rs);
      final b = Offset(a.dx - dx * len, a.dy - dy * len);
      pt
        ..strokeWidth = (1.1 + h * 1.3) * cam.scale
        ..color = withA(i.isEven ? const Color(0xFFFFFFFF) : tint, .85 - i * .1);
      c.drawLine(a, b, pt);
    }
    // The glint at the point.
    final w = (rs * 9) * (1 - (f.sf - m.startup).abs() / 12).clamp(.3, 1.0);
    c.drawPath(starPath(tip.dx, tip.dy, w, w * .28, 4, s.frame * .3), Paint()..color = const Color(0xFFFFFFFF));
  }
}
