// BAO (9) - panda, drunken-style dodger. Round and heavy, black and white, a
// loose green tunic with rolled sleeves, a red wine gourd on a cord that
// swings. A wobbly idle that sways, a sleepy grin.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim, poseFor;
import 'animal_kit.dart';
import 'cast_art.dart';

class BaoPal {
  final Color fur, furD, blk, blkL, tunic, tunicD, cuff, sash, gourd, gourdD, cord, cheek, eye;
  const BaoPal({
    required this.fur, required this.furD, required this.blk, required this.blkL, required this.tunic,
    required this.tunicD, required this.cuff, required this.sash, required this.gourd, required this.gourdD,
    required this.cord, required this.cheek, required this.eye,
  });
  static final BaoPal base = BaoPal(
    fur: hex(0xf6f2ea), furD: hex(0xc4beb4), blk: hex(0x24212c), blkL: hex(0x3d3947), tunic: hex(0x4ba35b),
    tunicD: hex(0x2a6a3a), cuff: hex(0x9bd985), sash: hex(0x8a5a2e), gourd: hex(0xd93a2e), gourdD: hex(0x8a1d1a),
    cord: hex(0xe9c45c), cheek: hex(0xff9aa8), eye: hex(0xfffaf0));
  /// Mirror match: a brown Qinling panda in an indigo tunic with an amber gourd.
  static final BaoPal alt = BaoPal(
    fur: hex(0xf2e3c2), furD: hex(0xc2ae88), blk: hex(0x6d4127), blkL: hex(0x8a5a3a), tunic: hex(0x3f50ae),
    tunicD: hex(0x232f7a), cuff: hex(0xaab6ff), sash: hex(0xd9a73a), gourd: hex(0xec9a1c), gourdD: hex(0x9a5a0a),
    cord: hex(0xf6f0e0), cheek: hex(0xff8a8a), eye: hex(0xfffaf0));
}

final Path _baoPupil = Path.combine(PathOperation.intersect, ellP(7.6, -3, 2.3, 2.1), Path()..addOval(Rect.fromCircle(center: const Offset(8.4, -2.7), radius: 1.3)));
final Path _torso = pathOf((p) => p
  ..moveTo(-17, 0)
  ..cubicTo(-25, -12, -26, -32, -20, -43)
  ..cubicTo(-14, -52, 0, -55, 8, -52)
  ..cubicTo(20, -48, 27, -34, 25, -20)
  ..cubicTo(24, -8, 18, -1, 12, 0));
final Path _tunic = pathOf((p) => p
  ..moveTo(-18, -3)
  ..cubicTo(-27, -14, -27, -32, -21, -44)
  ..cubicTo(-15, -53, -3, -56, 3, -54)
  ..lineTo(11, -37)
  ..lineTo(15, -51)
  ..cubicTo(21, -46, 28, -34, 26, -20)
  ..cubicTo(25, -9, 21, -3, 15, -1)
  ..lineTo(-4, 1));
final Path _head = pathOf((p) => p
  ..moveTo(-2, -16)
  ..cubicTo(-13, -16, -19, -8, -18, 1)
  ..cubicTo(-17, 10, -9, 16, 0, 16.5)
  ..cubicTo(9, 17, 17, 12, 18, 4)
  ..cubicTo(19, -6, 12, -16, -2, -16));
final Path _muzzle = pathOf((p) => p
  ..moveTo(7, 2)
  ..cubicTo(11, -2, 20, -1, 22, 4)
  ..cubicTo(23, 10, 17, 14, 12, 13.5)
  ..cubicTo(7, 13, 5, 7, 7, 2));
final Path _nose = pathOf((p) => p
  ..moveTo(17.5, 0)
  ..quadraticBezierTo(22, -.5, 21.5, 2.6)
  ..quadraticBezierTo(19.5, 4.6, 17.6, 2.8));
final Path _foot = pathOf((p) => p
  ..moveTo(-8, -7)
  ..cubicTo(-3, -11, 7, -9, 11, -4)
  ..cubicTo(17, -3, 22, -1, 22, 3)
  ..cubicTo(22, 6, 18, 7, 14, 7)
  ..lineTo(-7, 7)
  ..cubicTo(-11, 5, -11, -4, -8, -7));
Path _gourdBody() => pathOf((p) => p
  ..moveTo(-3, -14)
  ..cubicTo(-9, -13, -8, -7, -10, -3)
  ..cubicTo(-14, 3, -12, 11, -5, 13)
  ..cubicTo(2, 15, 10, 11, 9, 4)
  ..cubicTo(8, -2, 5, -6, 4, -9)
  ..cubicTo(5, -14, 2, -15, -3, -14));
final Path _gourd = _gourdBody();

class BaoArt extends CastArt {
  BaoArt();

  @override
  int get id => 9;

  @override
  RigDims get dims => const RigDims(9, 52, 34, 30, 34, 32, 1.3, 13, 9, 22, 4);

  static final KPose _idle = KPose.from(pIdle,
      lean: .1, head: .1, fu: .5, ff: 1.65, bu: .35, bf: 1.45, ft: .5, fs: -.1, bt: -.42, bs: -.45);

  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal;
  @override
  KPalette get altPalette => _palAlt;

  static final KPalette _pal = KPalette(
      skin: hex(0xf6f2ea), hair: hex(0x24212c), tip: hex(0xf6f2ea), vest: hex(0x4ba35b), tank: hex(0x2a6a3a),
      pants: hex(0x24212c), pad: hex(0x9bd985), wrap: hex(0x9bd985), shoe: hex(0x24212c), sole: hex(0x24212c),
      accent: hex(0xd93a2e));
  static final KPalette _palAlt = KPalette(
      skin: hex(0xf2e3c2), hair: hex(0x6d4127), tip: hex(0xf2e3c2), vest: hex(0x3f50ae), tank: hex(0x232f7a),
      pants: hex(0x6d4127), pad: hex(0xaab6ff), wrap: hex(0xaab6ff), shoe: hex(0x6d4127), sole: hex(0x6d4127),
      accent: hex(0xec9a1c));

  @override
  double get portraitWidth => 150;

  Pen? _pen;

  // -------------------------------------------------------------- paint

  /// How close the pose is to the resting stance (1 = at rest): the idle sway
  /// fades out the moment a move takes over.
  double _calm(KPose p) {
    final d = (p.fu - _idle.fu).abs() + (p.ff - _idle.ff).abs() + (p.bu - _idle.bu).abs() + (p.bf - _idle.bf).abs() +
        (p.lean - _idle.lean).abs() * 2 + (p.ft - _idle.ft).abs() + (p.bt - _idle.bt).abs() + p.ry.abs() * .05 + p.spin.abs();
    return clamp01(1 - d / 1.1);
  }

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final pen = (_pen ??= Pen(rp))..r = rp;
    final m = alt ? BaoPal.alt : BaoPal.base;
    final c = rp.c;
    final calm = _calm(p);
    // The whole upper body weaves around the hips while he waits.
    final sway = calm * (math.sin(frame * .055) * .05 + math.sin(frame * .13 + 1) * .018);
    void upper(void Function() draw) {
      c.save();
      c.rotate(sway);
      draw();
      c.restore();
    }

    final inHand = clamp01(p.sa);
    upper(() {
      if (p.baf < .5) _arm(pen, j, true, p, m);
    });
    if (p.blf < .5) _leg(pen, j, true, p, m);
    c.save();
    c.rotate(sway);
    // Gourd on its cord, slung at the back hip; swings with the lean.
    if (inHand < .95) _hangingGourd(pen, p, m, frame, 1 - inHand);
    // Trousers / sash base.
    rp.fill(rrPath(-17, -6, 34, 22, 10), m.blk, const Rect.fromLTRB(-17, -6, 17, 16));
    c.rotate(p.lean);
    rp.fill(_torso, m.fur, const Rect.fromLTRB(-27, -56, 27, 0), shade: m.furD);
    rp.fill(_tunic, m.tunic, const Rect.fromLTRB(-28, -56, 28, 2), shade: m.tunicD, lw: 2.4);
    if (!pen.sil) {
      rp.detail((pa) => pa
        ..moveTo(-17, -40)
        ..quadraticBezierTo(-12, -28, -14, -12)
        ..moveTo(18, -30)
        ..quadraticBezierTo(21, -20, 19, -10)
        ..moveTo(9, -35)
        ..quadraticBezierTo(8, -22, 11, -8), w: 1.5, col: pen.paint ? withA(m.tunicD, .6) : m.tunicD);
    }
    // Rope sash, knotted at the front with two ends.
    rp.fill(rrPath(-21, -13, 44, 8, 3.5), m.sash, const Rect.fromLTRB(-21, -13, 23, -5), shade: dk(m.sash, .4), noHT: true, lw: 1.9);
    rp.fill(
        pathOf((q) => q
          ..moveTo(10, -9)
          ..lineTo(14, 1)
          ..lineTo(18, 0)
          ..lineTo(16, -9)),
        m.sash, const Rect.fromLTRB(9, -10, 19, 2), noHT: true, lw: 1.5);
    c.restore();
    _leg(pen, j, false, p, m);
    if (p.blf >= .5) _leg(pen, j, true, p, m);
    upper(() {
      _headP(pen, j, p, m, frame);
      if (p.baf >= .5) _arm(pen, j, true, p, m);
      _arm(pen, j, false, p, m);
      if (inHand >= .05) _handGourd(pen, j, p, m, inHand);
    });
  }

  void _arm(Pen pen, Joints j, bool b, KPose pose, BaoPal m) {
    final r = pen.r, c = pen.c;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final blk = b ? dk(m.blk, .25) : m.blk;
    final tun = b ? dk(m.tunic, .3) : m.tunic;
    r.limb(sh, el, 12.5, 10, blk, bulge: 3.5, shade: dk(m.blk, .4));
    r.limb(sh, lerpO(sh, el, .62), 13.2, 11.6, tun, bulge: 2.5, shade: m.tunicD, lw: 2.2);
    // Rolled cuff.
    r.limb(lerpO(sh, el, .5), lerpO(sh, el, .7), 12.6, 12.4, b ? dk(m.cuff, .3) : m.cuff, noHT: true, lw: 2);
    r.limb(el, wr, 9.2, 7.8, blk, bulge: 2.2, shade: dk(m.blk, .4));
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    r.fill(rrPath(-3, -8.5, 17, 17, 8), blk, const Rect.fromLTRB(-3, -8, 14, 8), lw: 2.2, shade: dk(m.blk, .4));
    if (!pen.sil) {
      pen.flat(ellP(8, 0, 3.4, 4.4), b ? dk(m.blkL, .2) : m.blkL);
      for (final y in const [-5.0, -1.8, 1.8, 5.0]) {
        pen.circ(12, y * .8, 1.4, b ? dk(m.blkL, .2) : m.blkL);
      }
    }
    c.restore();
  }

  void _leg(Pen pen, Joints j, bool b, KPose pose, BaoPal m) {
    final r = pen.r, c = pen.c;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    final blk = b ? dk(m.blk, .25) : m.blk;
    r.limb(hip, kn, 14, 11, blk, bulge: 3.5, shade: dk(m.blk, .4));
    r.limb(kn, an, 11, 9, blk, bulge: 2.4, shade: dk(m.blk, .4));
    final shin = b ? pose.bs : pose.fs, off = b ? pose.bfa : pose.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && pose.tuck < .3 && pose.ry < 1;
    c.save();
    c.translate(an.dx, an.dy + 3);
    c.rotate(planted ? 0 : -shin + off);
    c.scale(1.12, 1.12);
    r.fill(_foot, blk, const Rect.fromLTRB(-11, -11, 23, 7), lw: 2.2, shade: dk(m.blk, .4));
    if (!pen.sil) {
      for (final x in const [13.0, 17.0]) {
        r.detail((pa) => pa
          ..moveTo(x, -1)
          ..lineTo(x, 4.5), w: 1, col: b ? dk(m.blkL, .2) : m.blkL);
      }
    }
    c.restore();
  }

  void _gourdShape(Pen pen, BaoPal m, double scale, {bool back = false}) {
    final r = pen.r;
    final c = pen.c;
    c.save();
    c.scale(scale, scale);
    r.fill(_gourd, back ? dk(m.gourd, .3) : m.gourd, const Rect.fromLTRB(-14, -15, 10, 15), shade: m.gourdD, lw: 2.2);
    if (!pen.sil) {
      r.fill(rrPath(-4.5, -20, 6.5, 7, 2), m.sash, const Rect.fromLTRB(-5, -20, 2, -13), noHT: true, lw: 1.6);
      r.detail((pa) => pa
        ..moveTo(-8, 4)
        ..quadraticBezierTo(-9, 9, -5, 11), w: 1.6, col: withA(const Color(0xFFFFFFFF), .75));
      r.detail((pa) => pa
        ..moveTo(-7, -8.5)
        ..lineTo(3, -8.5), w: 2, col: m.cord);
    }
    c.restore();
  }

  void _hangingGourd(Pen pen, KPose p, BaoPal m, double frame, double vis) {
    final c = pen.c;
    final a = math.sin(frame * .09) * .26 + math.sin(frame * .21) * .06 - (p.lean - _idle.lean) * 1.1 + p.spin * 0;
    const anchor = Offset(-15, -9);
    final len = 22.0;
    final cen = Offset(anchor.dx + math.sin(a) * len, anchor.dy + math.cos(a) * len);
    pen.r.detail((pa) => pa
      ..moveTo(anchor.dx, anchor.dy)
      ..lineTo(cen.dx, cen.dy - 4), w: 1.8, col: pen.sil ? null : dk(m.cord, .3));
    c.save();
    c.translate(cen.dx, cen.dy);
    c.rotate(a);
    _gourdShape(pen, m, .85 + .15 * vis);
    c.restore();
  }

  void _handGourd(Pen pen, Joints j, KPose p, BaoPal m, double k) {
    final c = pen.c;
    final ang = math.atan2(j.fWr.dy - j.fEl.dy, j.fWr.dx - j.fEl.dx);
    c.save();
    c.translate(j.fHa.dx, j.fHa.dy);
    c.rotate(ang + 1.2);
    c.scale(k, k);
    c.translate(-2, 10);
    _gourdShape(pen, m, 1.0);
    c.restore();
  }

  void _headP(Pen pen, Joints j, KPose p, BaoPal m, double frame) {
    final r = pen.r, c = pen.c;
    r.limb(j.neck, Offset(j.head.dx - 6, j.head.dy + 10), 13, 12, m.fur, bulge: 1, shade: m.furD);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.5, 1.5);
    r.fill(ellP(5, -15.5, 5.2, 5.2), dk(m.blk, .1), const Rect.fromLTRB(0, -21, 10, -10), lw: 1.8, noHT: true);
    r.fill(_head, m.fur, const Rect.fromLTRB(-19, -17, 20, 17), shade: m.furD);
    r.fill(ellP(-9.5, -14.5, 6.2, 6.2), m.blk, const Rect.fromLTRB(-16, -21, -3, -8), lw: 1.9, shade: dk(m.blk, .4));
    if (!pen.sil) {
      r.fill(_muzzle, m.fur, const Rect.fromLTRB(5, -2, 23, 15), noHT: true, lw: 1.5);
      // Eye patches slanting down, then a sleepy half-lidded eye in each.
      r.fill(ellP(7, -3, 5.4, 7, .55), m.blk, const Rect.fromLTRB(1, -11, 13, 5), noHT: true, lw: 1.6);
      r.fill(ellP(16.4, -4, 2.8, 4.4, .5), m.blk, const Rect.fromLTRB(13, -9, 20, 1), noHT: true, lw: 1.3);
      pen.flat(ellP(7.6, -3, 2.3, 2.1), m.eye);
      pen.flat(_baoPupil, kInk);
      pen.circ(16.6, -3.6, 1.1, m.eye);
      // Heavy lid across the top of the near eye.
      r.detail((pa) => pa
        ..moveTo(4.2, -4)
        ..quadraticBezierTo(7.6, -5.6, 11, -3.4), w: 2, col: m.eye);
      pen.flat(_nose, m.blk);
      r.detail((pa) => pa
        ..moveTo(19.4, 3)
        ..lineTo(19, 7)
        ..moveTo(19, 7)
        ..quadraticBezierTo(13, 11, 9, 8.2), w: 1.5);
      // Tipsy blush.
      pen.circ(8.8, 8.4, 3, withA(m.cheek, pen.paint ? .5 : .85));
    }
    c.restore();
  }

  // -------------------------------------------------------------- poses

  KPose _q(
          {double? lean, double? head, double? fu, double? ff, double? bu, double? bf, double? ft, double? fs,
          double? bt, double? bs, double? rx, double? ry, double? baf, double? open, double? sa, double? spin}) =>
      KPose.from(_idle,
          lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs, rx: rx, ry: ry,
          baf: baf, open: open, sa: sa, spin: spin);

  @override
  (KPose, KPose, KPose)? readyPoses() => (
        _q(lean: -.3, fu: 2.2, ff: 2.9, sa: 1, head: -.3, rx: -4),
        _q(lean: .55, fu: 1.4, ff: 1.5, bu: 1.3, bf: 1.4, baf: 1, rx: 12, open: 1, sa: 0),
        _q(lean: .1, fu: 1.1, ff: 2.4, bu: .9, bf: 2.5, baf: 1),
      );

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    final d = dims;
    final I = _idle;
    switch (m.name) {
      case 'standLight':
        final x = lunge(m, _q(fu: 1.45, ff: 1.5, lean: .35, rx: 10), Jt.fHa, d);
        return MoveAnim(strike(m, I, _q(fu: 1.9, ff: 2.6, lean: -.1, rx: -3), x, hold: KPose.from(x, fu: 1.5, ff: 1.55)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(m, _q(bu: 1.45, bf: 1.5, baf: 1, lean: .38, rx: 10), Jt.bHa, d);
        return MoveAnim(strike(m, I, _q(bu: 1.9, bf: 2.6, baf: 1, lean: -.1), x, hold: KPose.from(x, bu: 1.5, bf: 1.55)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        final x = lunge(m, _q(fu: .9, ff: 1.5, bu: 1.3, bf: 1.2, baf: 1, lean: .64, rx: 14, ft: .7, bt: -.5), Jt.bHa, d);
        return MoveAnim(strike(m, I, _q(lean: -.32, bu: 2.9, bf: 3.0, baf: 1, rx: -6, fu: 2.4, ff: 2.8), x,
            hold: KPose.from(x, lean: .7), windAt: .65),
            smear: Jt.bHa, smearA: s - 3, smearB: s + a + 2);
      case 'drunkenSway':
        final lo = _q(lean: -.55, head: .2, rx: -9, fu: -.4, ff: 1.0, bu: -.7, bf: .8, ft: .3, fs: 0, bt: -.7, bs: -.6);
        final hi = _q(lean: -.28, head: -.05, rx: -4, fu: -.1, ff: 1.3, bu: -.4, bf: 1.1, ft: .6, fs: -.1, bt: -.5, bs: -.5);
        final ks = <Key>[Key(0, I), Key(2, lo), Key(6, hi)];
        var f = 9;
        var down = true;
        final cEnd = m.counterEnd > 0 ? m.counterEnd : 24;
        while (f < cEnd) {
          ks.add(Key(f, down ? lo : hi));
          down = !down;
          f += 5;
        }
        ks.add(Key(mx(t, f + 1), I));
        return MoveAnim(mono(ks));
      case 'swayCounter':
        final lo = _q(lean: -.5, rx: -8, bu: 2.4, bf: 2.8, baf: 1, fu: 2.0, ff: 2.6);
        final x = lunge(m, _q(fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.5, baf: 1, lean: .52, rx: 14, open: 1, ft: .7, bt: -.5), Jt.fHa, d);
        return MoveAnim(strike(m, I, lo, x, hold: KPose.from(x, lean: .58), windAt: .5),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'bellyBounce':
        final st = m.steps.isNotEmpty ? m.steps.first.frame : 6;
        final coil = _q(lean: .3, ft: 1.1, fs: -.4, bt: .3, bs: -.9, fu: 1.4, ff: 1.9, bu: 1.2, bf: 1.7, rx: -4);
        final lift = _q(lean: .45, ft: 1.4, fs: .4, bt: 1.2, bs: .2, fu: 2.5, ff: 2.8, bu: 2.4, bf: 2.7, baf: 1);
        final flop = _q(lean: 1.15, head: -.55, fu: 2.3, ff: 2.4, bu: 1.9, bf: 2.1, baf: 1, ft: -.5, fs: -.4, bt: -.9, bs: -.3);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, st - 3), coil),
          Key(st, lift, 1),
          Key(s, flop, 1),
          Key(s + a, flop),
          Key(s + a + rnd(r * .5), KPose.from(flop, lean: 1.2, rx: 6)),
          Key(t, I),
        ]));
      case 'tipsySweep':
        final wind = _q(lean: .45, ft: 1.0, fs: -.35, bt: .8, bs: -1.1, fu: -.4, ff: .2, bu: -.8, bf: -.2, rx: -2);
        final x = _q(lean: .3, ft: 1.4, fs: 1.45, bt: .9, bs: -1.2, fu: -.6, ff: 0, bu: -.9, bf: -.3, rx: 8);
        return MoveAnim(strike(m, I, wind, x, rec: _q(lean: .35, ft: 1.0, fs: -.35, bt: .8, bs: -1.1), windAt: .6, recAt: .5),
            smear: Jt.fAn, smearA: s - 2, smearB: s + a + 1);
      case 'jugRise':
        final crouch = _q(lean: .5, ft: 1.0, fs: -.35, bt: .3, bs: -.95, fu: .8, ff: 1.5, bu: .5, bf: 1.3);
        final up = _q(lean: -.2, fu: 2.9, ff: 3.05, bu: .5, bf: 1.2, ft: .5, fs: .1, bt: -.1, bs: -.3, sa: 1);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, s - 3), crouch),
          Key(s, up, 1),
          Key(s + a, KPose.from(up, lean: -.3, ft: .8, fs: .6)),
          Key(s + a + rnd(r * .4), _q(lean: .3, ft: .9, fs: -.3, bt: -.2, bs: -.7, sa: .3)),
          Key(t, I),
        ]), smear: Jt.fHa, smearA: s - 2, smearB: s + a);
      case 'drunkenMaster':
        final ws = m.windows;
        final swigUp = _q(lean: -.2, head: -.4, fu: 2.2, ff: 2.95, sa: 1, rx: -2);
        final keys = <Key>[Key(0, I), Key(3, _q(fu: 1.8, ff: 2.5, sa: .8, lean: -.1)), Key(7, swigUp), Key(mx(8, s - 1), KPose.from(swigUp, lean: -.3, head: -.5))];
        final gap = ws.length > 1 ? ws[1].start - ws[0].start : 5;
        for (var k = 0; k < ws.length; k++) {
          final last = k == ws.length - 1;
          final p0 = last
              ? _q(fu: 1.0, ff: 1.0, bu: 1.0, bf: .9, baf: 1, lean: .72, rx: 16, sa: 1, ft: .8, bt: -.5)
              : (k.isEven
                  ? _q(fu: 1.5, ff: 1.5, bu: .6, bf: 2.2, lean: .5, rx: 10, open: 1, sa: 0, ft: .7)
                  : _q(bu: 1.5, bf: 1.5, baf: 1, fu: .6, ff: 2.2, lean: .12, rx: 8, open: 1, sa: 0, bt: -.2, head: .2));
          keys.add(Key(ws[k].start, p0, 1));
          if (!last) keys.add(Key(ws[k].start + mx(1, gap ~/ 2), KPose.from(p0, lean: k.isEven ? .05 : .45, rx: 4, sa: 0)));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rnd(r * .4), _q(lean: .4, fu: 1.0, ff: 1.6, rx: 6, sa: .4)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fHa, smearA: s - 1, smearB: tail);
    }
    return null;
  }

  // -------------------------------------------------------------- effects

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final fr = FxFrame(cam, s, player);
    final m = fr.move;
    if (m == null) return;
    final sf = fr.f.sf;
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final pal = alt ? BaoPal.alt : BaoPal.base;
    c.save();
    fr.enter(c);
    final pose = poseFor(s, player);
    final pel = fr.joint(pose, Jt.pel);
    if (m.name == 'bellyBounce') {
      final land = m.startup + m.active;
      if (sf >= land - 2 && sf < land + 16 && fr.f.y <= 200) {
        c.save();
        c.translate(pel.dx + 8, 0);
        groundRing(c, look, (sf - land + 2) / 18, 120, const Color(0xFFE8D9C0), thick: 7);
        c.restore();
      }
    }
    if (m.name == 'drunkenMaster' || m.name == 'drunkenSway') {
      // Dizzy sparks wheel around the head.
      final head = fr.joint(pose, Jt.head);
      final n = m.name == 'drunkenMaster' ? 5 : 3;
      for (var i = 0; i < n; i++) {
        final a = s.frame * .17 + i * math.pi * 2 / n;
        final o = Offset(head.dx + math.cos(a) * 30, head.dy - 34 + math.sin(a) * 9);
        final col = i.isEven ? pal.gourd : pal.cord;
        if (look == FightLook.painted) {
          c.drawCircle(o, 3.2, Paint()..color = withA(col, .85)..blendMode = BlendMode.plus);
        } else {
          final star = starPath(o.dx, o.dy, 4.6, 2, 4, a);
          c.drawPath(star, Paint()..color = col);
          if (look == FightLook.cartoon) {
            c.drawPath(star, Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = kInk);
          }
        }
      }
    }
    c.restore();
  }
}
