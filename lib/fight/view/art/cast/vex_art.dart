// VEX (10) - red fox, illusions and fakes. Slim, a big bushy tail with a glowing
// white tip, a long purple scarf that streams, amber eyes. Her decoy is a
// translucent copy of her, the snare a faint glowing paw-mark circle, and she
// teleports with a flicker.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim, poseFor;
import '../roster_poses.dart' show rigScale, rosterIdle;
import 'animal_kit.dart';
import 'cast_art.dart';

class VexPal {
  final Color fur, furD, white, blk, scarf, scarfD, scarfL, vest, trim, eye, iris, glow, ear;
  const VexPal({
    required this.fur, required this.furD, required this.white, required this.blk, required this.scarf,
    required this.scarfD, required this.scarfL, required this.vest, required this.trim, required this.eye,
    required this.iris, required this.glow, required this.ear,
  });
  static final VexPal base = VexPal(
    fur: hex(0xea6128), furD: hex(0xa63a18), white: hex(0xfff6ea), blk: hex(0x2a1e26), scarf: hex(0x8a4fd6),
    scarfD: hex(0x5a2f9e), scarfL: hex(0xc7a2ff), vest: hex(0x2c2438), trim: hex(0xc7a2ff), eye: hex(0xfff3c8),
    iris: hex(0xffb31a), glow: hex(0xcdb4ff), ear: hex(0x5a2a36));
  /// Mirror match: a frost-blue fox with a magenta scarf and a cyan tail tip.
  static final VexPal alt = VexPal(
    fur: hex(0x6f93bf), furD: hex(0x3f5c86), white: hex(0xf0f8ff), blk: hex(0x1d2333), scarf: hex(0xf0508a),
    scarfD: hex(0xa22860), scarfL: hex(0xff9fc4), vest: hex(0x1a2a3c), trim: hex(0xff9fc4), eye: hex(0xf2fff0),
    iris: hex(0x8cf06a), glow: hex(0x9ff3ff), ear: hex(0x2d3550));
}

final Path _torso = pathOf((p) => p
  ..moveTo(-9, 0)
  ..cubicTo(-12, -10, -13, -26, -11, -40)
  ..cubicTo(-9, -48, -3, -52, 3, -51)
  ..cubicTo(9, -50, 12, -44, 12, -36)
  ..cubicTo(12, -26, 10, -12, 8, 0));
final Path _bib = pathOf((p) => p
  ..moveTo(3, -50)
  ..cubicTo(10, -48, 12, -40, 12, -34)
  ..cubicTo(11, -22, 9, -10, 7, -1)
  ..cubicTo(2, -12, 1, -30, 2, -44));
final Path _wrap = pathOf((p) => p
  ..moveTo(-10, -3)
  ..cubicTo(-13, -12, -13, -26, -11, -40)
  ..cubicTo(-9, -47, -4, -49, 0, -49)
  ..lineTo(5, -28)
  ..lineTo(9, -47)
  ..cubicTo(11, -44, 12, -40, 12, -36)
  ..cubicTo(12, -26, 10, -12, 8, -3));
final Path _head = pathOf((p) => p
  ..moveTo(-3, -14)
  ..cubicTo(-12, -14, -16, -7, -15, 1)
  ..cubicTo(-14, 8, -9, 13, -1, 14.5)
  ..cubicTo(5, 15, 10, 12, 14, 10)
  ..lineTo(24.5, 5.8)
  ..cubicTo(27, 4, 27, 1, 24.6, -.4)
  ..lineTo(14, -4)
  ..cubicTo(11, -9, 6, -14, -3, -14));
final Path _muzzle = pathOf((p) => p
  ..moveTo(1, 15)
  ..cubicTo(3, 6, 12, 1, 25, 1.4)
  ..lineTo(25, 5.8)
  ..cubicTo(20, 8, 14, 10, 10, 12.5)
  ..cubicTo(7, 14, 4, 15, 1, 15));
final Path _ruff = pathOf((p) => p
  ..moveTo(-8, 6)
  ..lineTo(-19, 9)
  ..lineTo(-13, 12)
  ..lineTo(-18, 16)
  ..lineTo(-7, 16)
  ..lineTo(-1, 13));
final Path _ear = pathOf((p) => p
  ..moveTo(-13, -8)
  ..quadraticBezierTo(-15, -25, -6, -37)
  ..quadraticBezierTo(-2, -24, 1, -11));
final Path _earIn = pathOf((p) => p
  ..moveTo(-10, -11)
  ..quadraticBezierTo(-11, -23, -6, -31)
  ..quadraticBezierTo(-4, -22, -2, -13));
final Path _earFar = pathOf((p) => p
  ..moveTo(0, -12)
  ..quadraticBezierTo(0, -26, 8, -34)
  ..quadraticBezierTo(10, -22, 9, -11));
final Path _eyeP = pathOf((p) => p
  ..moveTo(3, -1.2)
  ..quadraticBezierTo(8, -7.8, 13.4, -4.6)
  ..quadraticBezierTo(8, .2, 3, -1.2));
final Path _paw = rrPath(-2, -5, 12, 10, 4.5);
final Path _foot = pathOf((p) => p
  ..moveTo(-6, -6)
  ..cubicTo(-2, -9, 6, -7, 10, -3)
  ..lineTo(18, -1)
  ..cubicTo(22, 0, 22, 4, 19, 5)
  ..lineTo(-6, 5)
  ..cubicTo(-9, 4, -9, -3, -6, -6));

double _tailW(double t) => 2.4 + 12.5 * math.sin(math.pi * math.pow(t, .72).toDouble());

class VexArt extends CastArt {
  VexArt();

  @override
  int get id => 10;

  @override
  RigDims get dims => const RigDims(10, 54, 30, 27, 41, 39, 1.2, 7, 5, 19, 4);

  static final KPose _idle = KPose.from(pIdle,
      lean: .22, head: -.1, fu: .75, ff: 2.2, bu: .3, bf: 2.5, ft: .6, fs: -.12, bt: -.25, bs: -.7);

  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal;
  @override
  KPalette get altPalette => _palAlt;

  static final KPalette _pal = KPalette(
      skin: hex(0xea6128), hair: hex(0xfff6ea), tip: hex(0xfff6ea), vest: hex(0x8a4fd6), tank: hex(0x2c2438),
      pants: hex(0x2c2438), pad: hex(0x2a1e26), wrap: hex(0xc7a2ff), shoe: hex(0x2a1e26), sole: hex(0x2a1e26),
      accent: hex(0xc7a2ff));
  static final KPalette _palAlt = KPalette(
      skin: hex(0x6f93bf), hair: hex(0xf0f8ff), tip: hex(0xf0f8ff), vest: hex(0xf0508a), tank: hex(0x1a2a3c),
      pants: hex(0x1a2a3c), pad: hex(0x1d2333), wrap: hex(0xff9fc4), shoe: hex(0x1d2333), sole: hex(0x1d2333),
      accent: hex(0x9ff3ff));

  @override
  double get portraitWidth => 140;

  Pen? _pen;
  final RigPainter _ghost = RigPainter();

  // -------------------------------------------------------------- paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final pen = (_pen ??= Pen(rp))..r = rp;
    final m = alt ? VexPal.alt : VexPal.base;
    final c = rp.c;
    _tail(pen, p, m, frame);
    if (p.baf < .5) _arm(pen, j, true, p, m);
    if (p.blf < .5) _leg(pen, j, true, p, m);
    rp.fill(rrPath(-11, -6, 22, 20, 8), m.vest, const Rect.fromLTRB(-11, -6, 11, 14), shade: dk(m.vest, .4));
    c.save();
    c.rotate(p.lean);
    rp.fill(_torso, m.fur, const Rect.fromLTRB(-13, -52, 12, 0), shade: m.furD);
    rp.fill(_bib, m.white, const Rect.fromLTRB(0, -50, 12, -2), noHT: true, lw: 1.4);
    rp.fill(_wrap, m.vest, const Rect.fromLTRB(-13, -50, 12, -3), shade: dk(m.vest, .4), lw: 2.1);
    if (!pen.sil) {
      rp.detail((pa) => pa
        ..moveTo(0, -49)
        ..lineTo(5, -28)
        ..lineTo(9, -47), w: 1.8, col: m.trim);
    }
    // Waist sash with two tails that flick.
    rp.fill(rrPath(-11, -9, 22, 6, 2.2), m.scarf, const Rect.fromLTRB(-11, -9, 11, -3), shade: m.scarfD, noHT: true, lw: 1.7);
    final f1 = math.sin(frame * .16) * 3, f2 = math.sin(frame * .16 + 1.4) * 3;
    rp.fill(
        pathOf((q) => q
          ..moveTo(-9, -7)
          ..lineTo(-21, -3 + f1)
          ..lineTo(-19, 1 + f1)
          ..lineTo(-8, -3)),
        m.scarf, const Rect.fromLTRB(-21, -9, -7, 2), lw: 1.4, noHT: true, shade: m.scarfD);
    rp.fill(
        pathOf((q) => q
          ..moveTo(-9, -5)
          ..lineTo(-18, 4 + f2)
          ..lineTo(-14, 7 + f2)
          ..lineTo(-6, -2)),
        m.scarf, const Rect.fromLTRB(-19, -5, -5, 8), lw: 1.4, noHT: true, shade: m.scarfD);
    c.restore();
    _leg(pen, j, false, p, m);
    if (p.blf >= .5) _leg(pen, j, true, p, m);
    // Scarf: ring at the neck, then two streamers behind the head.
    _scarf(pen, j, p, m, frame);
    _headP(pen, j, p, m);
    if (p.baf >= .5) _arm(pen, j, true, p, m);
    _arm(pen, j, false, p, m);
  }

  void _tail(Pen pen, KPose p, VexPal m, double frame) {
    final r = pen.r, c = pen.c;
    final sw = math.sin(frame * .05) * 6;
    final pts = bez(const Offset(-8, -6), Offset(-46, -2 + sw * .4), Offset(-74, -28 + sw), Offset(-52, -70 + sw * 1.4), 18);
    c.save();
    c.translate(-8, -6);
    c.rotate(p.sa);
    c.translate(8, 6);
    final body = tubeFn(pts, _tailW);
    r.fill(body, m.fur, bbOf(pts, 12), shade: m.furD, lw: 2.4);
    if (!pen.sil) {
      // A lighter inner flow line, then the white tip.
      r.detail((pa) {
        final q = pts.sublist(2, 13);
        pa.moveTo(q.first.dx, q.first.dy);
        for (var i = 1; i < q.length; i++) {
          pa.lineTo(q[i].dx + 2, q[i].dy - 1);
        }
      }, w: 1.4, col: pen.paint ? withA(m.furD, .35) : m.furD);
    }
    final tipPts = pts.sublist(13);
    final tip = tubeFn(tipPts, (t) => _tailW(.7 + .3 * t) * 1.05);
    r.fill(tip, m.white, bbOf(tipPts, 12), noHT: true, lw: 2.2);
    if (pen.paint && !pen.sil) {
      drawGlow(c, pts.last + const Offset(2, 4), 34, withA(m.glow, .55));
      drawGlow(c, pts.last + const Offset(2, 4), 16, withA(const Color(0xFFFFFFFF), .6));
    }
    c.restore();
  }

  void _scarf(Pen pen, Joints j, KPose p, VexPal m, double frame) {
    final r = pen.r, c = pen.c;
    final nk = j.neck;
    c.save();
    c.translate(nk.dx, nk.dy);
    c.rotate(p.lean * .6);
    r.fill(ellP(0, 1, 9.5, 5.6, -.3), m.scarf, const Rect.fromLTRB(-10, -6, 10, 8), shade: m.scarfD, lw: 2, noHT: true);
    // Two streamers that ripple; the longer one flows further and higher.
    for (var k = 0; k < 2; k++) {
      final long = k == 0;
      final n = long ? 16 : 11;
      final pts = <Offset>[];
      for (var i = 0; i <= n; i++) {
        final t = i / n;
        final wob = math.sin(frame * .16 - i * .6 + k * 1.7) * (1.5 + i * (long ? .55 : .4));
        pts.add(Offset(-6 - i * (long ? 5.6 : 4.4), 1 + k * 3 + wob + t * t * (long ? 9 : 6) - (long ? t * 6 : 0)));
      }
      final tube = tubeFn(pts, (t) => lerpD(long ? 5.2 : 4.6, 3.2, t));
      r.fill(tube, long ? m.scarf : m.scarfD, bbOf(pts, 7), shade: m.scarfD, lw: 1.9, noHT: true);
      if (!pen.sil && long) {
        r.detail((pa) {
          pa.moveTo(pts[1].dx, pts[1].dy);
          for (var i = 2; i < pts.length - 1; i++) {
            pa.lineTo(pts[i].dx, pts[i].dy);
          }
        }, w: 1.2, col: m.scarfL);
      }
    }
    c.restore();
  }

  void _arm(Pen pen, Joints j, bool b, KPose pose, VexPal m) {
    final r = pen.r, c = pen.c;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final fur = b ? dk(m.fur, .3) : m.fur;
    final blk = b ? dk(m.blk, .1) : m.blk;
    r.limb(sh, el, 5.6, 4.6, fur, bulge: 1.4, shade: m.furD);
    r.limb(el, wr, 4.8, 4.1, fur, bulge: 1, shade: m.furD);
    // Black stocking glove from mid-forearm, with a pale cuff.
    r.limb(lerpO(el, wr, .42), wr, 4.9, 4.7, blk, noHT: true, lw: 1.8);
    r.limb(lerpO(el, wr, .36), lerpO(el, wr, .46), 5.3, 5.2, b ? dk(m.white, .3) : m.white, noHT: true, lw: 1.5);
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    r.fill(_paw, blk, const Rect.fromLTRB(-2, -5, 10, 5), lw: 2, shade: dk(m.blk, .3));
    if (pose.open > .5 && !pen.sil) {
      for (var i = -1; i <= 1; i++) {
        r.limb(Offset(8, i * 3.2), Offset(14, i * 5.2), 1.7, 1.2, blk, noHT: true, lw: 1.3);
      }
    }
    c.restore();
  }

  void _leg(Pen pen, Joints j, bool b, KPose pose, VexPal m) {
    final r = pen.r, c = pen.c;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    final fur = b ? dk(m.fur, .3) : m.fur;
    final blk = b ? dk(m.blk, .1) : m.blk;
    r.limb(hip, kn, 7.6, 5.8, fur, bulge: 2, shade: m.furD);
    r.limb(hip, lerpO(hip, kn, .5), 8.6, 7.6, b ? dk(m.vest, .1) : m.vest, noHT: true, lw: 2, shade: dk(m.vest, .4));
    r.limb(lerpO(hip, kn, .88), an, 5.8, 4.7, blk, bulge: 1.2, noHT: true, lw: 2);
    final shin = b ? pose.bs : pose.fs, off = b ? pose.bfa : pose.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && pose.tuck < .3 && pose.ry < 1;
    c.save();
    c.translate(an.dx, an.dy + 3);
    c.rotate(planted ? 0 : -shin + off);
    r.fill(_foot, blk, const Rect.fromLTRB(-9, -9, 22, 5), lw: 2, shade: dk(m.blk, .3));
    c.restore();
  }

  void _headP(Pen pen, Joints j, KPose p, VexPal m) {
    final r = pen.r, c = pen.c;
    r.limb(j.neck, Offset(j.head.dx - 5, j.head.dy + 8), 6.6, 6.2, dk(m.fur, .05), bulge: .8, shade: m.furD);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.2, 1.2);
    r.fill(_earFar, dk(m.fur, .3), const Rect.fromLTRB(-1, -35, 11, -10), lw: 1.7, noHT: true);
    r.fill(_ruff, m.white, const Rect.fromLTRB(-19, 5, -1, 17), lw: 1.6, noHT: true);
    r.fill(_head, m.fur, const Rect.fromLTRB(-16, -15, 28, 16), shade: m.furD);
    r.fill(_muzzle, m.white, const Rect.fromLTRB(0, 0, 26, 16), lw: 1.6, noHT: true);
    r.fill(_ear, m.fur, const Rect.fromLTRB(-16, -38, 2, -8), lw: 1.9, shade: m.furD);
    if (!pen.sil) {
      // Black ear tips, pink-brown inner ear.
      c.save();
      c.clipPath(_ear);
      pen.flat(Path()..addRect(const Rect.fromLTRB(-20, -40, 5, -26)), m.blk);
      c.restore();
      pen.flat(_earIn, m.ear);
      pen.circ(24.8, .4, 2.3, m.blk);
      pen.circ(24, -.2, .7, const Color(0xCCFFFFFF));
      r.fill(_eyeP, m.eye, const Rect.fromLTRB(2, -9, 14, 1), noHT: true, lw: 1.1);
      c.save();
      c.clipPath(_eyeP);
      pen.circ(9, -3.4, 2.9, m.iris);
      pen.flat(ellP(9.4, -3.4, .9, 2.7), kInk);
      c.restore();
      pen.circ(10.4, -4.5, .7, const Color(0xFFFFFFFF));
      r.detail((pa) => pa
        ..moveTo(13.6, -4.8)
        ..quadraticBezierTo(8, -8.8, 2.4, -1.2)
        ..lineTo(-1, -4.4), w: 2.1, col: m.blk);
      r.fill(ellP(17.3, -4.2, 1.5, 2.1, .3), m.iris, const Rect.fromLTRB(15, -7, 19.5, -1.5), lw: .8, noHT: true);
      // Smirk with one raised corner.
      r.detail((pa) => pa
        ..moveTo(24, 5)
        ..quadraticBezierTo(16, 8.6, 9.5, 8)
        ..lineTo(8.4, 6.6), w: 1.3);
      pen.circ(17, 3.2, .6, m.blk);
      pen.circ(20, 3.6, .6, m.blk);
    }
    c.restore();
  }

  // -------------------------------------------------------------- poses

  KPose _q(
          {double? lean, double? head, double? fu, double? ff, double? bu, double? bf, double? ft, double? fs,
          double? bt, double? bs, double? rx, double? ry, double? baf, double? open, double? sa, double? al, double? spin}) =>
      KPose.from(_idle,
          lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs, rx: rx, ry: ry,
          baf: baf, open: open, sa: sa, al: al, spin: spin);

  @override
  (KPose, KPose, KPose)? readyPoses() => (
        _q(fu: .9, ff: 2.3, bu: .8, bf: 2.4, baf: 1, lean: .1, rx: -3),
        _q(fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.55, baf: 1, lean: .38, rx: 12, open: 1, ft: .75, bt: -.45),
        _q(fu: 1.2, ff: 2.7, bu: 1.0, bf: 2.8, baf: 1, lean: .12),
      );

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    final d = dims;
    final I = _idle;
    switch (m.name) {
      case 'standLight':
        final x = lunge(m, _q(fu: 1.5, ff: 1.55, lean: .32, rx: 10), Jt.fHa, d);
        return MoveAnim(strike(m, I, _q(fu: .4, ff: 2.4, lean: .15), x, hold: KPose.from(x, fu: 1.55)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(m, _q(bu: 1.5, bf: 1.55, baf: 1, lean: .34, rx: 10), Jt.bHa, d);
        return MoveAnim(strike(m, I, _q(bu: .3, bf: 2.5, baf: 1, lean: .15), x, hold: KPose.from(x, bu: 1.55)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        final x = lunge(m, _q(fu: .5, ff: 2.1, bu: 1.5, bf: 1.4, baf: 1, lean: .58, rx: 12, sa: 1.5, head: -.12), Jt.bHa, d);
        return MoveAnim(strike(m, I, _q(lean: -.12, bu: 2.6, bf: 2.9, baf: 1, rx: -4, sa: -.5), x,
            hold: KPose.from(x, sa: 1.9, lean: .62), windAt: .65),
            smear: Jt.bHa, smearA: s - 3, smearB: s + a + 2);
      case 'decoy':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final hands = _q(fu: .9, ff: 2.3, bu: .8, bf: 2.4, baf: 1, lean: .1, rx: -2);
        final cast = _q(fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.55, baf: 1, open: 1, lean: .32, rx: 6);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rnd(sp * .55)), hands),
          Key(mx(2, sp - 1), KPose.from(hands, al: .55)),
          Key(sp, cast, 1),
          Key(sp + 2, KPose.from(cast, al: .6)),
          Key(sp + 4, cast),
          Key(sp + rnd((t - sp) * .5), KPose.from(cast, lean: .28)),
          Key(t, I),
        ]));
      case 'fakeOut':
        final feint = _q(lean: .6, rx: 16, fu: .3, ff: 1.9, bu: -.5, bf: .7, ft: 1.0, fs: -.2, bt: -.5, bs: -.8, head: -.15);
        return MoveAnim(mono([
          Key(0, I),
          Key(2, _q(lean: .1, rx: -6, ft: .4, bt: -.1)),
          Key(mx(3, s - 1), KPose.from(feint, al: .55), 1),
          Key(s, feint, 1),
          Key(mx(t - 3, s + 1), KPose.from(feint, lean: .4, rx: 8)),
          Key(mx(t, s + 3), I),
        ]));
      case 'phantomSnare':
        final sp = m.traps.isNotEmpty ? m.traps.first.frame : s - 1;
        final crouch = _q(lean: .6, ft: 1.1, fs: -.4, bt: .3, bs: -1.0, fu: .8, ff: 1.5, bu: .4, bf: 1.3, rx: -2);
        final plant = _q(lean: .85, ft: 1.2, fs: -.45, bt: .35, bs: -1.05, fu: .2, ff: .1, bu: .3, bf: 1.5, rx: 8, open: 1);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rnd(sp * .5)), crouch),
          Key(sp, plant, 1),
          Key(sp + rnd((t - sp) * .5), plant),
          Key(t, I),
        ]));
      case 'mirageStep':
        final tp = m.steps.where((e) => e.teleport != 0).map((e) => e.frame).fold<int>(s - 2, (p, e) => e);
        final slash = lunge(m, _q(fu: 2.7, ff: 2.9, bu: 1.2, bf: 1.6, baf: 1, lean: -.15, rx: 8, ft: 1.3, fs: .4, bt: .2, bs: -.4, head: -.2), Jt.fHa, d, max: 12);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, tp - 5), _q(lean: .5, ft: 1.0, fs: -.3, bt: .2, bs: -.9)),
          Key(mx(2, tp - 3), _q(lean: .5, al: .45)),
          Key(mx(3, tp - 1), _q(lean: .5, al: .1)),
          Key(tp, _q(lean: .3, al: 0), 2),
          Key(tp + 1, _q(lean: .1, al: .5, fu: 1.5, ff: 2.0), 2),
          Key(s, slash, 1),
          Key(s + a, KPose.from(slash, lean: -.2, ft: 1.0)),
          Key(s + a + rnd(r * .45), _q(lean: .3)),
          Key(t, I),
        ]), smear: Jt.fHa, smearA: s - 2, smearB: s + a);
      case 'nineTails':
        final up = _q(lean: -.14, head: -.3, fu: 2.9, ff: 3.05, bu: 2.8, bf: 3.0, baf: 1, ft: .5, fs: -.1, bt: -.3, bs: -.6, rx: -2);
        final keys = <Key>[Key(0, I), Key(mx(1, 6), up)];
        var f = 12;
        var front = true;
        for (final pr in m.projectiles) {
          f = pr.frame;
          keys.add(Key(f, front ? KPose.from(up, fu: 1.7, ff: 1.6, lean: .1) : KPose.from(up, bu: 1.7, bf: 1.6, lean: .1), 1));
          keys.add(Key(f + 2, KPose.from(up, lean: -.1 + (front ? .02 : 0))));
          front = !front;
        }
        final slash = _q(fu: 1.1, ff: .9, bu: 1.0, bf: .85, baf: 1, lean: .7, rx: 12, ft: 1.0, bt: -.5, head: .1, open: 1);
        keys.add(Key(s, slash, 1));
        keys.add(Key(s + a, slash));
        keys.add(Key(s + a + rnd(r * .4), _q(lean: .3, fu: 1.2, ff: 1.9)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys));
    }
    return null;
  }

  // -------------------------------------------------------------- projectiles & traps

  static final Path _foxHead = pathOf((p) => p
    ..moveTo(-7, -7)
    ..quadraticBezierTo(-8, -17, -2, -22)
    ..quadraticBezierTo(0, -14, 2, -10)
    ..quadraticBezierTo(5, -13, 8, -12)
    ..lineTo(12, -5)
    ..cubicTo(16, -4, 18, -2, 18, 0)
    ..cubicTo(15, 3, 10, 6, 4, 6)
    ..cubicTo(-4, 6, -9, 2, -7, -7));

  @override
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) {
    if (def.name.startsWith('Decoy')) {
      final sc = rigScale(10) * 3100 / def.w;
      final flick = .5 + .1 * math.sin(age * .45) - (hash01(age ~/ 3, 9) > .86 ? .28 : 0);
      c.save();
      c.scale(sc, sc);
      final pose = rosterIdle(10, age.toDouble());
      if (look == FightLook.painted) {
        drawGlow(c, const Offset(0, -80), 90, withA(const Color(0xFFB79CFF), .3));
      }
      c.saveLayer(null, Paint()..colorFilter = ColorFilter.mode(Color.fromRGBO(205, 175, 255, flick.clamp(.15, .8)), BlendMode.modulate));
      _ghost.fighter(c, pose, _pal, look, charId: 10, alt: false, frame: age);
      c.restore();
      // Scan streaks crawling up the copy.
      final y = -((age * 2.4) % 170);
      c.drawRect(Rect.fromLTWH(-34, y, 68, 2.2), Paint()..color = const Color(0x66E6D8FF));
      c.restore();
      return true;
    }
    // Spirit fox: a comet in a fox's shape with three ghost tails.
    final cy = -(def.h / def.w * 31) / 2;
    final bob = math.sin(age * .4) * 1.8;
    c.save();
    c.translate(0, cy + bob);
    const white = Color(0xFFF4EEFF), vio = Color(0xFFB794FF);
    if (look == FightLook.painted) {
      drawGlow(c, Offset.zero, 30, withA(vio, .7));
      drawGlow(c, const Offset(4, 0), 15, const Color(0x99FFFFFF));
    }
    for (var i = 0; i < 3; i++) {
      final pts = <Offset>[];
      for (var k = 0; k <= 8; k++) {
        pts.add(Offset(-6 - k * 4.2, (i - 1) * (3 + k * .8) + math.sin(age * .4 - k * .7 + i) * (1 + k * .5)));
      }
      final tube = tubeFn(pts, (t) => lerpD(3.6, .3, t));
      c.drawPath(tube, Paint()
        ..color = look == FightLook.painted ? withA(vio, .55) : (i == 1 ? white : vio)
        ..blendMode = look == FightLook.painted ? BlendMode.plus : BlendMode.srcOver);
      if (look == FightLook.cartoon) {
        c.drawPath(tube, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = kInk);
      }
    }
    c.drawPath(_foxHead, Paint()..color = look == FightLook.painted ? const Color(0xFFFFFFFF) : white);
    if (look == FightLook.cartoon) {
      c.drawPath(_foxHead, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = kInk);
    }
    c.drawCircle(const Offset(6.5, -3.6), 1.4, Paint()..color = const Color(0xFF6A3FD0));
    c.restore();
    return true;
  }

  static final Path _pawPrint = () {
    final p = Path()..addOval(Rect.fromCenter(center: const Offset(0, 1.6), width: 8, height: 6.6));
    for (final o in const [Offset(-4.6, -2.6), Offset(-1.6, -4.6), Offset(1.8, -4.6), Offset(4.8, -2.6)]) {
      p.addOval(Rect.fromCenter(center: o, width: 2.8, height: 3.6));
    }
    return p;
  }();

  @override
  bool paintTrap(Canvas c, FightLook look, TrapDef def, int age, bool armed) {
    final pulse = armed ? .75 + .25 * math.sin(age * .2) : .35;
    final grow = clamp01(age / 8);
    final rx = 15.5 * grow, ry = 4.6 * grow;
    const vio = Color(0xFFB79CFF);
    c.save();
    c.translate(0, -2);
    if (look == FightLook.painted) {
      drawGlow(c, Offset.zero, 20 * grow, withA(vio, .45 * pulse));
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..blendMode = BlendMode.plus
        ..color = withA(const Color(0xFFE6D8FF), .9 * pulse));
    } else {
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), Paint()..color = withA(vio, .35 * pulse + .1));
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = withA(look == FightLook.cartoon ? kInk : vio, .9));
    }
    // The paw mark lying flat in the middle.
    c.save();
    c.scale(.9 * grow, .34 * grow);
    c.drawPath(_pawPrint, Paint()
      ..color = look == FightLook.painted ? withA(const Color(0xFFF2E9FF), .9 * pulse) : withA(const Color(0xFFE0D0FF), .5 + .4 * pulse)
      ..blendMode = look == FightLook.painted ? BlendMode.plus : BlendMode.srcOver);
    c.restore();
    if (armed && look != FightLook.pixel) {
      for (var i = 0; i < 3; i++) {
        final k = ((age * .02) + i / 3) % 1;
        c.drawCircle(Offset((i - 1) * 7.0, -k * 16), (1 - k) * 1.8 + .3, Paint()..color = withA(const Color(0xFFE6D8FF), (1 - k) * .9));
      }
    }
    c.restore();
    return true;
  }

  // -------------------------------------------------------------- effects

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final fr = FxFrame(cam, s, player);
    final m = fr.move;
    if (m == null) return;
    final sf = fr.f.sf;
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final pal = alt ? VexPal.alt : VexPal.base;
    final painted = look == FightLook.painted;
    final plus = Paint()
      ..isAntiAlias = true
      ..blendMode = painted ? BlendMode.plus : BlendMode.srcOver;
    c.save();
    fr.enter(c);
    final pose = poseFor(s, player);
    final pel = fr.joint(pose, Jt.pel);
    final mid = Offset(pel.dx, pel.dy - 34);
    void sparks(double k, bool inward, int n, double rad) {
      for (var i = 0; i < n; i++) {
        final a = hash01(i, 3) * math.pi * 2;
        final dist = rad * (inward ? (1 - k) : k) * (.55 + hash01(i, 5) * .6);
        final o = Offset(mid.dx + math.cos(a) * dist, mid.dy + math.sin(a) * dist * .9);
        final sz = (1 - k) * 3.4 + .8;
        final col = i % 3 == 0 ? const Color(0xFFFFFFFF) : pal.glow;
        if (painted) {
          c.drawCircle(o, sz, plus..color = withA(col, .9 * (1 - k * .6)));
        } else {
          final d = starPath(o.dx, o.dy, sz * 1.6, sz * .6, 4, a);
          c.drawPath(d, Paint()..color = col);
          if (look == FightLook.cartoon) {
            c.drawPath(d, Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = kInk);
          }
        }
      }
    }

    switch (m.name) {
      case 'mirageStep':
        final tp = m.steps.where((e) => e.teleport != 0).map((e) => e.frame).fold<int>(m.startup - 2, (p, e) => e);
        if (sf >= tp - 6 && sf < tp) sparks((sf - (tp - 6)) / 6, true, 12, 46);
        if (sf >= tp && sf < tp + 12) {
          sparks((sf - tp) / 12, false, 16, 64);
          c.save();
          c.translate(pel.dx, 0);
          groundRing(c, look, (sf - tp) / 12, 70, pal.glow, thick: 4);
          c.restore();
        }
        break;
      case 'fakeOut':
        if (sf <= m.startup + 2) {
          for (var i = -1; i <= 1; i++) {
            final y = mid.dy + i * 14 + 6;
            final len = 26.0 + (i == 0 ? 14 : 0);
            c.drawLine(Offset(pel.dx - 24 - len, y), Offset(pel.dx - 24, y), Paint()
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round
              ..color = withA(painted ? pal.glow : const Color(0xFFFFFFFF), .75));
          }
        }
        break;
      case 'decoy':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : 0;
        if (sf >= sp - 2 && sf < sp + 12) {
          c.save();
          c.translate(pel.dx + 140 / fr.rs, 0);
          groundRing(c, look, (sf - sp + 2) / 14, 44, pal.glow, thick: 4);
          c.restore();
          sparks((sf - sp + 2) / 14, false, 8, 40);
        }
        break;
      case 'phantomSnare':
        final tr = m.traps.isNotEmpty ? m.traps.first : null;
        if (tr != null && sf >= tr.frame - 1 && sf < tr.frame + 10) {
          c.save();
          c.translate(pel.dx + tr.x / unitsPerPx / fr.rs, 0);
          groundRing(c, look, (sf - tr.frame + 1) / 11, 52, pal.glow, thick: 4);
          c.restore();
        }
        break;
      case 'nineTails':
        _nineTails(c, look, pal, pel, sf, m);
        break;
    }
    c.restore();
  }

  void _nineTails(Canvas c, FightLook look, VexPal pal, Offset pel, int sf, MoveDef m) {
    final painted = look == FightLook.painted;
    final grow = clamp01((sf - 3) / 26);
    final fade = sf > m.startup + m.active ? clamp01(1 - (sf - m.startup - m.active) / 18) : 1.0;
    final burst = sf >= m.startup - 1 && sf < m.startup + 12 ? (sf - m.startup + 1) / 13.0 : -1.0;
    if (grow <= 0 || fade <= 0) return;
    final root = Offset(pel.dx - 8, pel.dy - 14);
    if (painted) drawGlow(c, Offset(root.dx - 10, root.dy - 30), 110 * grow, withA(pal.glow, .35 * fade));
    for (var i = 0; i < 9; i++) {
      final f = i / 8.0;
      final base = -math.pi * (.98 - f * .96) - .12; // fan from behind (left) over the head toward the front
      final len = (64 + 34 * math.sin(f * math.pi)) * grow;
      final wob = math.sin(sf * .12 + i * .9) * .09;
      final a0 = base + wob;
      final pts = <Offset>[];
      for (var k = 0; k <= 12; k++) {
        final t = k / 12;
        final a = a0 + math.sin(t * 2.2 + i) * .18 * grow;
        final d = len * t;
        pts.add(Offset(root.dx + math.cos(a) * d, root.dy + math.sin(a) * d * 1.05 - t * t * 8));
      }
      final tube = tubeFn(pts, (t) => (2 + 8 * math.sin(math.pi * math.pow(t, .7).toDouble())) * (.5 + .5 * grow));
      if (painted) {
        c.drawPath(tube, Paint()
          ..blendMode = BlendMode.plus
          ..color = withA(pal.glow, .32 * fade));
        c.drawCircle(pts.last, 5 * grow, Paint()
          ..blendMode = BlendMode.plus
          ..color = withA(const Color(0xFFFFFFFF), .8 * fade));
      } else {
        c.drawPath(tube, Paint()..color = withA(i.isEven ? pal.scarfL : pal.glow, fade));
        if (look == FightLook.cartoon) {
          c.drawPath(tube, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = withA(kInk, fade));
        }
        c.drawCircle(pts.last, 3.4 * grow, Paint()..color = withA(const Color(0xFFFFFFFF), fade));
      }
    }
    if (burst >= 0 && burst < 1) {
      c.save();
      c.translate(pel.dx + 40, 0);
      groundRing(c, look, burst, 150, const Color(0xFFFFFFFF), thick: 8);
      c.restore();
      if (painted) drawGlow(c, Offset(pel.dx + 60, pel.dy - 40), 120 * (1 - burst), withA(pal.glow, .6 * (1 - burst)));
    }
  }
}
