// LUZ - luchadora. A magenta mask with gold flames (eyes and mouth free), a
// short cape, a turquoise one-piece, knee-high wrestling boots, taped wrists.
// Acrobatic: the dropkick, the sprinting splash, the hurricanrana and the
// top-rope swan all leave the ground and spin the body.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim;
import '../roster_rig.dart' show ellP, tubePath, bbOf, pathOf;
import 'cast_art.dart';
import 'human_kit.dart';

class _LuzCol {
  final Color mask, trim, suit, suitD, boot, cape, hair, tape, lace;
  const _LuzCol(this.mask, this.trim, this.suit, this.suitD, this.boot, this.cape, this.hair, this.tape, this.lace);
}

final _LuzCol _main = _LuzCol(hex(0xd4208f), hex(0xffc933), hex(0x12b5c6), hex(0x0b7f93), hex(0xc01a7e), hex(0xb81a78),
    hex(0x1b1018), hex(0xf4efe6), hex(0xffe9a8));
final _LuzCol _alt = _LuzCol(hex(0x6a3fe0), hex(0xe9f0ff), hex(0xff6a2b), hex(0xb83f14), hex(0x5a32c4), hex(0x5a32c4),
    hex(0x3a1a12), hex(0xf4efe6), hex(0xdfe6ff));

class LuzArt extends CastArt {
  LuzArt();

  @override
  int get id => 12;
  @override
  RigDims get dims => const RigDims(12, 56, 31, 27, 41, 40, 1.14, 8, 5.5, 21, 3);

  static final KPose _idle = KPose.from(pIdle,
      lean: .16, head: -.08, fu: 1.05, ff: 2.4, bu: .8, bf: 2.65, ft: .6, fs: .05, bt: -.4, bs: -.55);
  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal(_main);
  @override
  KPalette get altPalette => _pal(_alt);
  KPalette _pal(_LuzCol c) => KPalette(
      skin: hex(0xc9835a), hair: c.hair, tip: c.trim, vest: c.mask, tank: c.suit, pants: c.suit, pad: c.boot,
      wrap: c.tape, shoe: c.boot, sole: hex(0x2b2633), accent: c.trim);

  @override
  double get portraitWidth => 128;

  // ------------------------------------------------------------------ paint

  final Path _flames = pathOf((p) {
    for (final x in const [-7.0, 0.0, 7.0]) {
      p
        ..moveTo(x - 4, -16)
        ..quadraticBezierTo(x - 5, -24, x - 12, -30)
        ..quadraticBezierTo(x - 1, -27, x + 4, -17);
    }
  });
  final Path _eyePatch = ellP(8.2, -4.4, 7.4, 5.2, -.08);
  final Path _mouthPatch = ellP(10.4, 10.4, 4.6, 3.6, .1);
  late final Path _necklineIn = Path.combine(PathOperation.intersect, pTorso, _neckline);
  late final Path _eyePatchIn = Path.combine(PathOperation.intersect, pHead, _eyePatch);
  late final Path _mouthPatchIn = Path.combine(PathOperation.intersect, pHead, _mouthPatch);
  final Path _neckline = Path()
    ..moveTo(-24, -70)
    ..lineTo(24, -70)
    ..lineTo(24, -52)
    ..quadraticBezierTo(8, -40, -2, -49)
    ..quadraticBezierTo(-14, -57, -24, -52)
    ..close();
  final Path _stripe = Path()
    ..moveTo(-12, -1)
    ..cubicTo(-16, -20, -15, -38, -11, -56)
    ..lineTo(-5, -56)
    ..cubicTo(-9, -38, -10, -20, -6, -1)
    ..close();
  final Path _buckle = starPath(0, 0, 5.5, 2.4, 4, 0);

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final c = rp.c;
    final k = alt ? _alt : _main;
    final t = frame * .09;
    final arm = ArmStyle(skin: rp.pal.skin, tape: k.tape);
    // Short cape, behind everything.
    c.save();
    c.rotate(p.lean * .8);
    final w1 = math.sin(t) * 4, w2 = math.sin(t + 1.2) * 5;
    final cape = pathOf((q) => q
      ..moveTo(-6, -60)
      ..cubicTo(-24, -60, -37, -48, -43 + w1, -30 + w1)
      ..quadraticBezierTo(-47 + w1, -18 + w2, -38 + w2, -12 + w2)
      ..quadraticBezierTo(-33 + w1, -22, -25 + w2 * .5, -15)
      ..quadraticBezierTo(-14, -26, -9, -40));
    rp.fill(cape, k.cape, const Rect.fromLTRB(-48, -62, -6, -10), lw: 2.2, shade: dk(k.cape, .45));
    rp.detail((q) => q
      ..moveTo(-43 + w1, -30 + w1)
      ..quadraticBezierTo(-47 + w1, -18 + w2, -38 + w2, -12 + w2)
      ..quadraticBezierTo(-33 + w1, -22, -25 + w2 * .5, -15), w: 2.4, col: k.trim);
    c.restore();

    if (p.baf < .5) kitArm(rp, j, p, true, arm);
    if (p.blf < .5) _leg(rp, j, p, true, k);
    _torso(rp, j, p, k);
    _leg(rp, j, p, false, k);
    if (p.blf >= .5) _leg(rp, j, p, true, k);
    _head(rp, j, p, k, t);
    if (p.baf >= .5) kitArm(rp, j, p, true, arm);
    kitArm(rp, j, p, false, arm);
  }

  void _torso(RigPainter rp, Joints j, KPose p, _LuzCol k) {
    final c = rp.c;
    final skin = rp.pal.skin;
    // Hips: the leotard's cut.
    rp.fill(pPantsTop, k.suit, const Rect.fromLTRB(-16, -6, 15, 16));
    c.save();
    c.rotate(p.lean);
    c.scale(1.04, .93);
    rp.fill(pTorso, k.suit, const Rect.fromLTRB(-20, -64, 20, 0), shade: k.suitD);
    rp.fill(_stripe, k.trim, const Rect.fromLTRB(-16, -56, -5, 0), lw: 1.5, noHT: true);
    // Scooped neckline over the shoulders.
    rp.fill(_necklineIn, skin, const Rect.fromLTRB(-24, -70, 24, -40), noHT: true, lw: 1.8);
    rp.detail((q) => q
      ..moveTo(-18, -52)
      ..quadraticBezierTo(-14, -57, -2, -49)
      ..quadraticBezierTo(8, -40, 19, -52), w: 2, col: k.trim);
    // Sash and star buckle.
    rp.fill(rrPath(-15, -9, 29, 7, 2.5), k.mask, const Rect.fromLTRB(-15, -9, 14, -2), noHT: true, lw: 1.8);
    c.save();
    c.translate(5, -5.5);
    rp.fill(_buckle, k.trim, const Rect.fromLTRB(-6, -6, 6, 6), noHT: true, lw: 1.4);
    c.restore();
    c.restore();
  }

  void _leg(RigPainter rp, Joints j, KPose p, bool back, _LuzCol k) {
    final c = rp.c;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    final skin = back ? dk(rp.pal.skin, .3) : rp.pal.skin;
    final boot = back ? dk(k.boot, .3) : k.boot;
    final trim = back ? dk(k.trim, .3) : k.trim;
    rp.limb(hip, kn, 11.6, 9.2, skin, bulge: 3);
    // The boot: knee-high, with a gold cuff and white laces.
    final top = lerpO(kn, an, -.08);
    rp.limb(top, an, 10, 7.2, boot, bulge: 2.4, noHT: true);
    rp.limb(lerpO(kn, an, -.14), lerpO(kn, an, .06), 10.6, 10.2, trim, noHT: true, lw: 2);
    rp.detail((q) {
      final a = lerpO(kn, an, .18), b = lerpO(kn, an, .78);
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final l = math.sqrt(dx * dx + dy * dy);
      if (l == 0) return;
      final nx = -dy / l, ny = dx / l;
      for (var i = 0; i < 4; i++) {
        final m = lerpO(a, b, i / 3);
        q.moveTo(m.dx + nx * 3.6 + dx / l * 3, m.dy + ny * 3.6 + dy / l * 3);
        q.lineTo(m.dx - nx * 3.6, m.dy - ny * 3.6);
      }
    }, w: 1.1, col: back ? dk(k.lace, .3) : k.lace);
    c.save();
    c.translate(an.dx, an.dy);
    c.rotate(footRot(j, p, back));
    rp.fill(pShoe, boot, const Rect.fromLTRB(-11, -14, 23, 9), shade: dk(k.boot, .45));
    rp.fill(pSoleBar, back ? dk(rp.pal.sole, .2) : rp.pal.sole, const Rect.fromLTRB(-10, 5, 23, 11), noHT: true);
    if (rp.sil == null) rp.fill(pStripe, trim, const Rect.fromLTRB(-3, -6, 17, 3), lw: 1.6, noHT: true);
    c.restore();
  }

  void _head(RigPainter rp, Joints j, KPose p, _LuzCol k, double t) {
    final c = rp.c;
    final skin = rp.pal.skin;
    kitNeck(rp, j, skin);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.18, 1.18);
    if (rp.sil == null) {
      // Braid out the back of the mask, and the lace tails.
      final sw = math.sin(t * 1.3) * 3;
      final braid = sway(const Offset(-11, -3), 34, -.8, .6, t * 1.3, 6 + sw.abs());
      rp.fill(tubePath(braid, 4.6, 1.8), k.hair, bbOf(braid, 6), noHT: true, lw: 1.6);
      final tie = sway(const Offset(-12, -8), 14, -.9, .1, t * 1.7 + 1, 3, n: 4);
      rp.fill(tubePath(tie, 2.6, 1), k.trim, bbOf(tie, 4), noHT: true, lw: 1.2);
    }
    rp.fill(_flames, k.trim, const Rect.fromLTRB(-20, -31, 12, -15), lw: 1.5, noHT: true);
    rp.fill(pHead, k.mask, const Rect.fromLTRB(-17, -20, 16, 18));
    if (rp.sil == null) {
      rp.fill(_eyePatchIn, skin, const Rect.fromLTRB(1, -10, 16, 2), noHT: true, lw: 1.7);
      rp.fill(_mouthPatchIn, dk(skin, .06), const Rect.fromLTRB(5, 6, 15, 14), noHT: true, lw: 1.5);
      // Gold trim around the eye and a flame streak sweeping back from it.
      rp.detail((q) => q.addPath(_eyePatch, Offset.zero), w: 1.5, col: k.trim);
      rp.detail((q) => q
        ..moveTo(1.5, -8)
        ..quadraticBezierTo(-6, -10, -12, -4)
        ..moveTo(1, -2)
        ..quadraticBezierTo(-6, 0, -11, 6), w: 2.2, col: k.trim);
      // Eye.
      c.drawPath(pEye, Paint()..color = rp.pal.eye);
      c.drawCircle(const Offset(9.3, -4.6), 1.8, Paint()..color = rp.pal.iris);
      c.drawCircle(const Offset(9.9, -5.2), .6, Paint()..color = const Color(0xFFFFFFFF));
      rp.detail((q) => q
        ..moveTo(3.4, -5.2)
        ..quadraticBezierTo(7.5, -8.6, 12.2, -5.4), w: 2.2, col: const Color(0xFF140C18));
      rp.detail((q) => q
        ..moveTo(11.6, -5.4)
        ..lineTo(13.4, -7.4), w: 1.2, col: const Color(0xFF140C18));
      // Smile.
      rp.detail((q) => q
        ..moveTo(7.2, 10.8)
        ..quadraticBezierTo(10.6, 12.6, 13.4, 9.8), w: 1.6, col: const Color(0xFF8A2440));
      rp.detail((q) => q
        ..moveTo(8.4, 9.2)
        ..quadraticBezierTo(10.8, 8.6, 13, 9.2), w: 1.1, col: const Color(0xFFB4506A));
    }
    c.restore();
  }

  // ------------------------------------------------------------------ poses

  @override
  KPose rebase(KPose k) => k;

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final q = poseOf(_idle);
    return (
      q(fu: 2.9, ff: 3.0, bu: 2.6, bf: 2.9, lean: -.12, rx: -4, baf: 1),
      q(fu: 1.55, ff: 1.5, bu: 1.2, bf: 1.0, lean: .5, rx: 14, ft: 1.0, fs: .1, bt: -.5, bs: -.6),
      q(fu: 1.2, ff: 2.8, bu: 1.0, bf: 2.9, baf: 1, lean: .1),
    );
  }

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = _idle;
    final q = poseOf(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    const tau = math.pi * 2;
    KPose crouch([double lean = .5]) => q(lean: lean, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .7, ff: 1.9, bu: .5, bf: 2.1);
    switch (m.name) {
      case 'standLight':
        final x = lunged(m, 12, q(fu: 1.55, ff: 1.62, lean: .3, rx: 8, open: 1, ft: .7, fs: .1, bt: -.45, bs: -.6), Jt.fHa);
        return MoveAnim(strike(m, I, q(fu: .45, ff: 2.6, lean: .1, open: 1), x, hold: KPose.from(x, fu: 1.45, ff: 1.7)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunged(m, 12, q(bu: 1.55, bf: 1.62, baf: 1, lean: .32, rx: 8, open: 1, fu: .3, ff: 2.6, ft: .7, fs: .1, bt: -.45, bs: -.6), Jt.bHa);
        return MoveAnim(strike(m, I, q(bu: .4, bf: 2.7, baf: 1, lean: .1, open: 1), x, hold: KPose.from(x, bu: 1.45, bf: 1.7)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // A lariat: one arm swung flat across, the body whipping after it.
        final x = lunged(m, 12, q(fu: 1.57, ff: 1.57, bu: -1.0, bf: -.5, lean: .5, rx: 14, ft: 1.0, fs: .12, bt: -.55, bs: -.65, head: -.12), Jt.fHa);
        return MoveAnim(
            strike(m, I, q(fu: -1.1, ff: -.7, bu: 1.5, bf: 1.7, baf: 1, lean: -.15, rx: -5, ft: .5, bt: -.7, bs: -.5), x,
                hold: KPose.from(x, lean: .56, rx: 17), windAt: .6),
            smear: Jt.fHa, smearA: s - 4, smearB: s + a + 2);
      case 'dropkick':
        final lift = m.steps.isEmpty ? 6 : m.steps.first.frame;
        final leap = q(tuck: 1, ry: 6, spin: -.35, lean: .1, ft: 1.8, fs: .5, bt: 1.5, bs: .2, fu: .3, ff: 1.2, bu: .2, bf: 1.0);
        final kick = q(tuck: 1, ry: 10, spin: -.98, lean: -.02, head: -.1, ft: 1.15, fs: 1.2, bt: 1.0, bs: 1.15, fu: -1.0, ff: -.6, bu: -1.3, bf: -.9, blf: 1);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, lift - 2), crouch()),
              Key(lift + 1, leap, 1),
              Key(s, kick, 1),
              Key(s + a, kick),
              Key(s + a + rnd(r * .4), q(spin: -.2, tuck: .6, ry: 4, ft: 1.0, fs: .0, bt: .5, bs: -.4, lean: .2)),
              Key(mx(t, s + a + rnd(r * .4) + 1), I),
            ]),
            smear: Jt.fAn, smearA: s - 3, smearB: s + a);
      case 'runningSplash':
        final keys = <Key>[Key(0, I), Key(2, crouch(.7))];
        var ph = true;
        for (var f = 5; f < s - 2; f += 4) {
          keys.add(Key(f, q(lean: .75, head: .1, fu: .6, ff: .9, bu: .2, bf: .5, ft: ph ? .95 : -.4, fs: ph ? .15 : -.8, bt: ph ? -.45 : .9, bs: ph ? -.75 : .1)));
          ph = !ph;
        }
        final dive = q(tuck: 1, ry: 20, spin: 1.28, lean: 0, head: -.2, fu: 2.95, ff: 3.05, bu: 2.75, bf: 2.95, ft: .25, fs: .1, bt: -.1, bs: .15, baf: 1);
        keys.add(Key(s - 1, q(lean: .8, ft: 1.1, fs: .3, bt: .6, bs: -.5, fu: 1.8, ff: 2.2, bu: 1.6, bf: 2.0), 1));
        keys.add(Key(s, dive, 1));
        keys.add(Key(s + a, KPose.from(dive, ry: 15, spin: 1.38)));
        keys.add(Key(s + a + rnd(r * .45), q(lean: .55, ft: 1.0, fs: -.3, bt: .2, bs: -.9, fu: 1.0, ff: 1.2)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fHa, smearA: s - 2, smearB: s + a);
      case 'slideKick':
        final slide = q(lean: -.75, head: .35, ft: 1.5, fs: 1.55, bt: 2.4, bs: 1.0, fu: -.9, ff: -.3, bu: -1.1, bf: -.6);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, rnd(s * .5)), crouch(.65)),
              Key(s, slide, 1),
              Key(s + a, slide),
              Key(s + a + rnd(r * .5), crouch(.55)),
              Key(mx(t, s + a + rnd(r * .5) + 1), I),
            ]),
            smear: Jt.fAn, smearA: s - 2, smearB: s + a);
      case 'hurricanrana':
        final lift = m.steps.isEmpty ? 4 : m.steps.first.frame;
        final leap = q(tuck: 1, ry: 12, spin: .15, lean: .25, ft: 2.1, fs: .3, bt: 1.9, bs: .1, fu: 2.2, ff: 2.4, bu: 2.0, bf: 2.3, baf: 1);
        final wrap = q(tuck: 1, ry: 18, spin: .95, lean: .3, ft: 1.7, fs: 1.3, bt: 1.0, bs: .5, fu: 1.7, ff: 1.8, bu: 1.5, bf: 1.7, baf: 1);
        final over = q(tuck: 1, ry: 20, spin: 3.4, lean: .2, ft: 1.2, fs: .8, bt: .9, bs: .5, fu: 1.4, ff: 1.5, bu: 1.2, bf: 1.4, baf: 1);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, lift - 1), crouch(.6)),
              Key(lift + 1, leap, 1),
              Key(s, wrap, 1),
              Key(s + rnd(a * .55), over),
              Key(s + a, q(tuck: .7, ry: 10, spin: tau, lean: .3, ft: 1.2, fs: .1, bt: .5, bs: -.4)),
              Key(s + a + rnd(r * .4), q(spin: tau, lean: .5, ft: 1.0, fs: -.35, bt: .25, bs: -.95)),
              Key(mx(t, s + a + rnd(r * .4) + 1), KPose.from(I, spin: tau)),
            ]),
            smear: Jt.bAn, smearA: s - 2, smearB: s + a);
      case 'topRopeSwan':
        final arch = q(tuck: 1, ry: 14, spin: .5, lean: -.3, head: -.5, fu: 2.4, ff: 2.5, bu: -2.4, bf: -2.5, ft: .4, fs: .1, bt: -.6, bs: .3);
        final swan = q(tuck: 1, ry: 16, spin: 1.8, lean: -.3, head: -.55, fu: 2.3, ff: 2.4, bu: -2.3, bf: -2.4, ft: .35, fs: .15, bt: -.7, bs: .4);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(2, crouch(.75)),
              Key(6, q(tuck: 1, ry: 12, spin: 0, lean: -.1, fu: 2.6, ff: 2.8, bu: -2.6, bf: -2.8, ft: 1.6, fs: .5, bt: 1.2, bs: 0), 1),
              Key(mx(8, rnd(s * .65)), arch),
              Key(s, swan, 1),
              Key(s + a, KPose.from(swan, spin: 2.15, ry: 12)),
              Key(s + a + rnd(r * .5), q(tuck: .5, ry: 6, spin: 4.7, lean: .3, ft: 1.0, fs: .1, bt: .4, bs: -.3)),
              Key(mx(t, s + a + rnd(r * .5) + 1), KPose.from(crouch(.5), spin: tau)),
            ]),
            smear: Jt.fHa, smearA: s - 4, smearB: s + a + 2);
    }
    return null;
  }

  // ------------------------------------------------------------------ fx

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final f = s.p[player];
    if (f.state != St.move || f.moveId < 0) return;
    final m = s.chars[player].moves[f.moveId];
    if (m.name != 'topRopeSwan' && m.name != 'runningSplash') return;
    if (f.sf < m.startup - 6 || f.sf > m.startup + m.active + 4) return;
    final alt = s.chars[0].id == s.chars[1].id && player == 1;
    final k = alt ? _alt : _main;
    final fx = Paint()..isAntiAlias = true;
    final swan = m.name == 'topRopeSwan';
    for (var i = 1; i <= 7; i++) {
      final back = i * (swan ? 2.6 : 2.0);
      final px = f.x / unitsPerPx - f.vx / unitsPerPx * back;
      final py = f.y / unitsPerPx - f.vy / unitsPerPx * back + 46 + i * .8;
      final o = cam.toScreen(px, py);
      final r = (swan ? 9.0 : 6.0) * cam.scale * (1 - i / 9);
      c.drawPath(starPath(o.dx, o.dy, r, r * .42, 4, i * .5 + s.frame * .08), fx..color = withA(i.isEven ? k.trim : k.mask, .85 - i * .1));
    }
  }
}
