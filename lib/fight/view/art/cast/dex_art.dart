// DEX - capoeirista. White abada pants with a coloured cord (corda), barefoot,
// a sleeveless tank, short locs. The idle is a ginga: the weight rocks side to
// side, the arms swing, the feet trade places. Kicks sweep wide arcs.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim;
import '../roster_poses.dart' show rigScale;
import '../roster_rig.dart' show ellP, tubePath, bbOf, pathOf;
import 'cast_art.dart';
import 'human_kit.dart';

class _DexCol {
  final Color tank, tankD, pants, pantsD, cord, locTip, skinD;
  const _DexCol(this.tank, this.tankD, this.pants, this.pantsD, this.cord, this.locTip, this.skinD);
}

final _DexCol _main = _DexCol(hex(0xf2c230), hex(0xb98a14), hex(0xf6f2e6), hex(0xb9b2a2), hex(0x2bb35a), hex(0xf2c230), hex(0x4f2c1a));
final _DexCol _alt = _DexCol(hex(0x2f9ae0), hex(0x1c6296), hex(0xeaf0f6), hex(0xa4aebb), hex(0xf0742a), hex(0xf0742a), hex(0x4f2c1a));

class DexArt extends CastArt {
  DexArt();

  @override
  int get id => 13;
  @override
  RigDims get dims => const RigDims(13, 60, 33, 29, 44, 42, 1.2, 9, 6.5, 21, 3);

  static final KPose _idle = KPose.from(pIdle,
      lean: .12, head: -.06, fu: .75, ff: 2.2, bu: .55, bf: .9, ft: .5, fs: -.02, bt: -.55, bs: -.25);
  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal(_main);
  @override
  KPalette get altPalette => _pal(_alt);
  KPalette _pal(_DexCol c) => KPalette(
      skin: hex(0x6b3f28), hair: hex(0x17100d), tip: c.locTip, vest: c.tank, tank: c.tank, pants: c.pants, pad: c.cord,
      wrap: c.cord, shoe: hex(0x6b3f28), sole: hex(0x4f2c1a), accent: c.cord);

  @override
  double get portraitWidth => 132;

  // ------------------------------------------------------------------ paint

  final Path _foot = footPath();
  final Path _cap = pathOf((p) => p
    ..moveTo(-17, -2)
    ..cubicTo(-18, -22, -2, -29, 10, -22)
    ..cubicTo(14, -19, 15, -14, 14, -11)
    ..cubicTo(8, -14, 0, -11, -6, -9)
    ..cubicTo(-12, -8, -16, -5, -17, -2));
  final Path _neckline = Path()
    ..moveTo(-26, -70)
    ..lineTo(26, -70)
    ..lineTo(26, -50)
    ..quadraticBezierTo(10, -34, 0, -46)
    ..quadraticBezierTo(-12, -58, -26, -48)
    ..close();
  final Path _band = rrPath(-16, -8, 31, 8, 2.5);

  /// The ginga: swings legs and arms from [frame]; returns the pose to draw.
  KPose _ginga(KPose p, double frame) {
    final ph = math.sin(frame * .075);
    return KPose.from(p,
        ft: _idle.ft - ph * .5, bt: _idle.bt - ph * .5, fs: _idle.fs - ph * .15, bs: _idle.bs - ph * .15,
        fu: p.fu + ph * .35, bu: p.bu - ph * .45, bf: p.bf + ph * .3, lean: p.lean + ph * .05);
  }

  @override
  void paint(RigPainter rp, Joints j0, KPose p0, bool alt, double frame) {
    final c = rp.c;
    final k = alt ? _alt : _main;
    final t = frame * .09;
    var j = j0;
    var p = p0;
    c.save();
    if (isIdleLike(p0, _idle)) {
      p = _ginga(p0, frame);
      j = fk(p, dims);
      c.translate(math.sin(frame * .075) * 3.5, -(j.maxAn - j0.maxAn));
    }
    final arm = ArmStyle(skin: rp.pal.skin, tape: k.cord, taped: false, girth: .96);
    if (p.baf < .5) kitArm(rp, j, p, true, arm);
    if (p.blf < .5) _leg(rp, j, p, true, k);
    _torso(rp, j, p, k, t);
    _leg(rp, j, p, false, k);
    if (p.blf >= .5) _leg(rp, j, p, true, k);
    _head(rp, j, p, k, t);
    if (p.baf >= .5) kitArm(rp, j, p, true, arm);
    kitArm(rp, j, p, false, arm);
    c.restore();
  }

  void _torso(RigPainter rp, Joints j, KPose p, _DexCol k, double t) {
    final c = rp.c;
    final skin = rp.pal.skin;
    rp.fill(pPantsTop, k.pants, const Rect.fromLTRB(-16, -6, 15, 16), shade: k.pantsD);
    c.save();
    c.rotate(p.lean);
    c.scale(1.12, 1.0);
    rp.fill(pTorso, k.tank, const Rect.fromLTRB(-20, -64, 20, 0), shade: k.tankD);
    c.save();
    c.clipPath(pTorso);
    rp.fill(_neckline, skin, const Rect.fromLTRB(-26, -70, 26, -34), noHT: true, lw: 1.8);
    c.restore();
    rp.detail((q) => q
      ..moveTo(-19, -49)
      ..quadraticBezierTo(-12, -58, 0, -46)
      ..quadraticBezierTo(10, -34, 20, -50), w: 1.6);
    rp.detail((q) => q
      ..moveTo(-12, -30)
      ..quadraticBezierTo(-4, -26, 6, -29), w: 1.1);
    // The corda: a thick cord with a knot and two tails.
    rp.fill(_band, k.cord, const Rect.fromLTRB(-16, -8, 15, 0), noHT: true, lw: 1.8);
    rp.detail((q) {
      for (var x = -12.0; x < 14; x += 5) {
        q.moveTo(x, -8);
        q.lineTo(x + 3, 0);
      }
    }, w: 1, col: dk(k.cord, .45));
    final tails = [
      sway(const Offset(8, -3), 26, .25, .97, t * 1.2, 4, n: 5),
      sway(const Offset(5, -3), 20, .05, 1, t * 1.2 + 1.3, 4, n: 5),
    ];
    for (final tl in tails) {
      rp.fill(tubePath(tl, 2.6, 2.1), k.cord, bbOf(tl, 4), noHT: true, lw: 1.5);
    }
    c.save();
    c.translate(9, -4);
    rp.fill(ellP(0, 0, 4.4, 4.4), k.cord, const Rect.fromLTRB(-5, -5, 5, 5), noHT: true, lw: 1.6);
    c.restore();
    c.restore();
  }

  void _leg(RigPainter rp, Joints j, KPose p, bool back, _DexCol k) {
    final c = rp.c;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    final sk = back ? dk(rp.pal.skin, .3) : rp.pal.skin;
    final pc = back ? dk(k.pants, .3) : k.pants;
    // Bare shin and foot first, then the baggy abada over the thigh and knee.
    rp.limb(kn, an, 7.6, 5.6, sk, bulge: 1.6);
    final hem = lerpO(kn, an, .5);
    rp.limb(hip, kn, 13.5, 11, pc, bulge: 4.4, shade: k.pantsD);
    rp.limb(lerpO(kn, hem, -.1), hem, 11.6, 10, pc, bulge: 3.4, shade: k.pantsD);
    rp.limb(lerpO(kn, hem, .82), hem, 10.2, 9.8, back ? dk(k.pantsD, .2) : k.pantsD, noHT: true, lw: 2);
    rp.detail((q) {
      final m = lerpO(hip, kn, .5);
      q.moveTo(m.dx - 4, m.dy - 3);
      q.quadraticBezierTo(m.dx + 2, m.dy + 4, m.dx + 7, m.dy + 3);
    }, w: 1.1);
    c.save();
    c.translate(an.dx, an.dy + 1);
    c.rotate(footRot(j, p, back));
    rp.fill(_foot, sk, const Rect.fromLTRB(-10, -11, 23, 10), lw: 2.2);
    if (rp.sil == null) {
      rp.detail((q) => q
        ..moveTo(16, 3)
        ..lineTo(21, 4.5)
        ..moveTo(13, 5)
        ..lineTo(18, 7), w: 1);
    }
    c.restore();
  }

  void _head(RigPainter rp, Joints j, KPose p, _DexCol k, double t) {
    final c = rp.c;
    final skin = rp.pal.skin;
    kitNeck(rp, j, skin);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.2, 1.2);
    final hair = rp.pal.hair;
    if (rp.sil == null) {
      // Short locs, behind the head, bobbing with the ginga.
      for (var i = 0; i < 5; i++) {
        final root = Offset(-11.5 - (i == 2 ? 1.5 : 0), -17.0 + i * 3.6);
        final l = sway(root, 19.0 - i, -.78 - i * .04, .35 + i * .12, t * 1.4 + i * .8, 2.4, n: 5);
        rp.fill(tubePath(l, 3.4, 2.5), hair, bbOf(l, 4), noHT: true, lw: 1.3);
        c.drawCircle(l.last, 2.2, Paint()..color = i.isEven ? k.locTip : dk(k.locTip, .3));
      }
    }
    rp.fill(pHead, skin, const Rect.fromLTRB(-17, -20, 16, 18));
    if (rp.sil == null) {
      c.save();
      c.clipPath(pHead);
      c.drawPath(pHeadShade, Paint()..color = rp.paint ? const Color(0x59281C28) : k.skinD);
      c.restore();
      rp.fill(pEar, dk(skin, .08), const Rect.fromLTRB(-7, -4, 1, 7), lw: 1.6, noHT: true);
    }
    rp.fill(_cap, hair, const Rect.fromLTRB(-18, -29, 15, -5), shade: dk(hair, .3), noHT: true);
    if (rp.sil == null) {
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(-2.5 + i * 4.2, -21.5 + (i == 0 || i == 3 ? 2 : 0)), 2.4, Paint()..color = dk(hair, .35));
      }
      c.drawPath(pEye, Paint()..color = rp.pal.eye);
      c.drawCircle(const Offset(9.3, -4.6), 1.8, Paint()..color = rp.pal.iris);
      c.drawCircle(const Offset(9.8, -5.2), .6, Paint()..color = const Color(0xFFFFFFFF));
      rp.detail((q) => q
        ..moveTo(2.5, -9.4)
        ..lineTo(12.8, -7.4), w: 2.6, col: const Color(0xFF140C18));
      rp.detail((q) => q
        ..moveTo(7, 10.4)
        ..quadraticBezierTo(10.4, 12.4, 13, 9.4), w: 1.5, col: const Color(0xFF3A1A12));
      rp.detail((q) => q
        ..moveTo(10, 6.6)
        ..lineTo(13.2, 7.4), w: 1, col: const Color(0xFF3A1A12));
    }
    c.restore();
  }

  // ------------------------------------------------------------------ poses

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final q = poseOf(_idle);
    return (
      q(bt: 1.4, bs: 1.3, blf: 1, lean: -.2, fu: 1.2, ff: 1.0, bu: -.6, bf: -.3),
      q(bt: 2.2, bs: 2.0, blf: 1, lean: -.5, fu: 1.0, ff: .9, bu: -.5, bf: -.2, rx: 8),
      q(fu: 1.1, ff: 2.4, bu: .9, bf: 2.0, lean: .1, ft: .7, bt: -.6),
    );
  }

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = _idle;
    final q = poseOf(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    const tau = math.pi * 2;
    KPose crouch([double lean = .8]) =>
        q(lean: lean, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .5, ff: .35, bu: .35, bf: .2, head: -.2);
    switch (m.name) {
      case 'standLight':
        final x = lunged(m, 13, q(fu: 1.5, ff: 1.6, lean: .3, rx: 8, open: 1, ft: .7, fs: .05, bt: -.6, bs: -.35), Jt.fHa);
        return MoveAnim(strike(m, I, q(fu: .3, ff: .6, bu: 1.2, bf: 2.0, lean: .15), x, hold: KPose.from(x, fu: 1.4, ff: 1.7)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        // A low, quick front kick: the ponteira.
        final x = lunged(m, 13, q(ft: 1.45, fs: 1.5, lean: -.12, fu: .9, ff: 2.0, bu: .3, bf: 1.0, bt: -.35, bs: -.4, rx: 5), Jt.fAn, max: 30);
        return MoveAnim(strike(m, I, q(ft: 1.0, fs: -.3, lean: .05, fu: .9, ff: 2.0), x),
            smear: Jt.fAn, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // The queixada: a big swinging high kick with the back leg.
        final x = lunged(m, 13, q(bt: 2.15, bs: 1.95, blf: 1, lean: -.42, head: .1, ft: -.05, fs: 0, fu: 1.2, ff: .9, bu: -.5, bf: -.2, rx: 8), Jt.bAn, max: 30);
        return MoveAnim(
            strike(m, I, q(bt: 1.3, bs: -.2, blf: 1, lean: .3, ft: .45, fu: .5, ff: .6, bu: .1, bf: .5, rx: -3), x,
                hold: KPose.from(x, bt: 2.3, lean: -.5), windAt: .6),
            smear: Jt.bAn, smearA: s - 4, smearB: s + a + 2);
      case 'spinKick':
        final hit1 = q(bt: 1.75, bs: 1.6, blf: 1, lean: .55, ft: .9, fs: -.2, fu: .1, ff: .3, bu: -.3, bf: .0, head: -.1, rx: 6);
        final hit2 = q(bt: 2.55, bs: 2.3, blf: 1, lean: -.15, spin: -.35, ft: .5, fs: 0, fu: 1.0, ff: 1.2, bu: -.7, bf: -.4, rx: 8);
        final x = lunged(m, 13, hit1, Jt.bAn, max: 24);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, rnd(s * .5)), crouch(.9)),
              Key(s, x, 1),
              Key(s + rnd(a * .5), hit2),
              Key(s + a, KPose.from(hit2, spin: -.7, bt: 2.7)),
              Key(s + a + rnd(r * .45), crouch(.5)),
              Key(mx(t, s + a + rnd(r * .45) + 1), I),
            ]),
            smear: Jt.bAn, smearA: s - 4, smearB: s + a + 2);
      case 'flowCombo':
        final ws = m.windows;
        final keys = <Key>[Key(0, I), Key(mx(1, s ~/ 2), q(lean: .35, ft: .9, fs: -.2, bt: -.6, bs: -.4, fu: .9, ff: 1.4, bu: .6, bf: 1.0))];
        for (var i = 0; i < ws.length; i++) {
          final last = i == ws.length - 1;
          final lvl = last ? 2.1 : (i.isEven ? 1.5 : 1.75);
          final kick = q(
              ft: lvl, fs: lvl - .05, lean: last ? -.45 : -.1 + (i.isEven ? 0 : .1), head: .05, fu: .6 + (i.isEven ? 0 : .4), ff: 1.0,
              bu: -.4, bf: -.1, bt: -.55, bs: -.45, rx: 8 + i * 3.0, spin: last ? -.12 : 0);
          keys.add(Key(ws[i].start, kick, 1));
          if (!last) {
            keys.add(Key(ws[i].start + 3, q(ft: .9, fs: -.1, lean: .25, bt: -.5, bs: -.4, fu: .9, ff: 1.5, rx: 8 + i * 3.0)));
          }
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rnd(r * .4), crouch(.4)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fAn, smearA: s - 2, smearB: tail);
      case 'lowCartwheel':
        final star = q(tuck: 1, ry: 24, lean: 0, head: 0, fu: 2.9, ff: 3.0, bu: 3.0, bf: 3.1, ft: 1.15, fs: 1.2, bt: -1.15, bs: -1.2);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), crouch(.9)),
              Key(s, star, 1),
              Key(s + a, KPose.from(star, spin: tau), 2),
              Key(s + a + rnd(r * .4), KPose.from(crouch(.7), spin: tau)),
              Key(mx(t, s + a + rnd(r * .4) + 1), KPose.from(I, spin: tau)),
            ]),
            smear: Jt.fAn, smearA: s - 1, smearB: s + a);
      case 'invertida':
        // Hands down, body upside down, one leg scything out: the handstand kick.
        final up = q(tuck: 1, ry: 52, spin: -2.55, lean: 0, head: -.25, fu: -2.55, ff: -2.55, bu: -2.4, bf: -2.5, ft: -.3, fs: -.2, bt: 1.05, bs: .9, blf: 1);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 4), crouch(1.0)),
              Key(mx(2, s - 2), q(tuck: 1, ry: 34, spin: -1.3, lean: .3, fu: -1.3, ff: -1.3, bu: -1.2, bf: -1.2, ft: .4, bt: .8), 1),
              Key(s, up, 1),
              Key(s + a, KPose.from(up, ft: -.55, fs: -.45, bt: 1.4, bs: 1.3)),
              Key(s + a + rnd(r * .4), q(tuck: .7, ry: 20, spin: -tau + .5, lean: .5, ft: .8, fs: .1, bt: .2, bs: -.4)),
              Key(mx(t, s + a + rnd(r * .4) + 1), KPose.from(I, spin: -tau)),
            ]),
            smear: Jt.fAn, smearA: s - 3, smearB: s + a);
      case 'rodaDeFogo':
        final star = q(tuck: 1, ry: 26, lean: 0, fu: 2.9, ff: 3.0, bu: 3.0, bf: 3.1, ft: 1.2, fs: 1.25, bt: -1.2, bs: -1.25);
        final turns = (a / 9).ceil().clamp(2, 5);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s ~/ 2), crouch(.7)),
              Key(s, star, 1),
              Key(s + a, KPose.from(star, spin: tau * turns), 2),
              Key(s + a + rnd(r * .4), KPose.from(crouch(.6), spin: tau * turns)),
              Key(mx(t, s + a + rnd(r * .4) + 1), KPose.from(I, spin: tau * turns)),
            ]),
            smear: Jt.fAn, smearA: s - 1, smearB: s + a);
    }
    return null;
  }

  // ------------------------------------------------------------------ fx

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final f = s.p[player];
    if (f.state != St.move || f.moveId < 0) return;
    final m = s.chars[player].moves[f.moveId];
    if (m.name != 'rodaDeFogo' || f.sf < m.startup - 2 || f.sf > m.startup + m.active + 3) return;
    final o = jointScreen(cam, s, player, Jt.c);
    final rs = rigScale(13) * cam.scale;
    final fade = f.sf > m.startup + m.active ? .4 : 1.0;
    final pt = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final base = s.frame * .35;
    const cols = [Color(0xFFFF4A1C), Color(0xFFFF9A2A), Color(0xFFFFE066)];
    for (var i = 0; i < 3; i++) {
      final r = (74 - i * 12) * rs;
      pt
        ..strokeWidth = (11 - i * 3) * rs
        ..color = withA(cols[i], .8 * fade);
      for (var k = 0; k < 2; k++) {
        c.drawArc(Rect.fromCircle(center: o, radius: r), base * (i.isEven ? 1 : -1) + k * math.pi, 1.9, false, pt);
      }
    }
  }
}
