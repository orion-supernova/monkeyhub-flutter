// GALE (11) - bald eagle, air fighter. White head, yellow hooked beak, brown
// body, WINGS instead of arms (the arm joints are the wing roots, primary
// feathers fan from the forearm), aviator goggles pushed up, a flight-jacket
// collar. Jumps and air dashes are wing driven; his gust is a curved wind.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim, poseFor;
import 'animal_kit.dart';
import 'cast_art.dart';

class GalePal {
  final Color head, headD, body, bodyD, bodyL, feather, featherD, featherL, tail, tailD, beak, beakD, leg, jacket,
      jacketD, collar, strap, lens, rim, eye, wind;
  const GalePal({
    required this.head, required this.headD, required this.body, required this.bodyD, required this.bodyL,
    required this.feather, required this.featherD, required this.featherL, required this.tail, required this.tailD,
    required this.beak, required this.beakD, required this.leg, required this.jacket, required this.jacketD,
    required this.collar, required this.strap, required this.lens, required this.rim, required this.eye,
    required this.wind,
  });
  static final GalePal base = GalePal(
    head: hex(0xf6f3ee), headD: hex(0xbfc0c6), body: hex(0x6a4528), bodyD: hex(0x3e2616), bodyL: hex(0xa27348),
    feather: hex(0x5d3b21), featherD: hex(0x351f10), featherL: hex(0xb58654), tail: hex(0xf6f3ee), tailD: hex(0xc3c4cc),
    beak: hex(0xf6bb2a), beakD: hex(0xc58a12), leg: hex(0xf2bb2c), jacket: hex(0x7d4c27), jacketD: hex(0x4a2c16),
    collar: hex(0xf3e7c9), strap: hex(0x3a2616), lens: hex(0x59c8ff), rim: hex(0xbcc1cc), eye: hex(0xffd23a),
    wind: hex(0xd8f6ff));
  /// Mirror match: a golden eagle in a slate-blue jacket with amber lenses.
  static final GalePal alt = GalePal(
    head: hex(0xdba85c), headD: hex(0xa8742e), body: hex(0x4b301c), bodyD: hex(0x2a1a0e), bodyL: hex(0x8a6238),
    feather: hex(0x3d2515), featherD: hex(0x20120a), featherL: hex(0x9a7040), tail: hex(0xe8d8b4), tailD: hex(0xb09a6e),
    beak: hex(0x9aa1ae), beakD: hex(0x6a707c), leg: hex(0xe6c240), jacket: hex(0x3f5c8c), jacketD: hex(0x263a5e),
    collar: hex(0xf6f6f6), strap: hex(0x1f2a3e), lens: hex(0xff9a3a), rim: hex(0xd8c8a0), eye: hex(0xffe38a),
    wind: hex(0xffe9c4));
}

final Path _breastMarks = pathOf((q) => q
  ..moveTo(4, -50)
  ..cubicTo(14, -46, 15, -30, 11, -4)
  ..lineTo(2, -4)
  ..cubicTo(6, -22, 5, -38, 4, -50));
final Path _torso = pathOf((p) => p
  ..moveTo(-9, 0)
  ..cubicTo(-14, -12, -15, -28, -12, -42)
  ..cubicTo(-9, -50, -2, -54, 4, -52)
  ..cubicTo(11, -50, 15, -42, 15, -32)
  ..cubicTo(15, -22, 12, -10, 9, 0));
final Path _jacket = pathOf((p) => p
  ..moveTo(-11, 0)
  ..cubicTo(-16, -12, -16, -28, -13, -42)
  ..lineTo(-7, -49)
  ..lineTo(7, -49)
  ..cubicTo(13, -45, 16, -38, 16, -30)
  ..cubicTo(16, -20, 13, -9, 10, 0));
final Path _hem = rrPath(-11, -6, 22, 7, 2.5);
final Path _head = pathOf((p) => p
  ..moveTo(-3, -15)
  ..cubicTo(-12, -15, -17, -8, -16, 0)
  ..cubicTo(-15, 8, -9, 13, -1, 14)
  ..cubicTo(5, 14.5, 10, 11, 12, 6)
  ..lineTo(11, -6)
  ..cubicTo(9, -12, 4, -15, -3, -15));
final Path _beak = pathOf((p) => p
  ..moveTo(7, -7)
  ..cubicTo(14, -10, 23, -6, 26.5, 3)
  ..cubicTo(28, 8, 27, 12, 24.5, 13.5)
  ..cubicTo(24, 9, 20, 5.5, 14, 4.5)
  ..cubicTo(10, 4, 8, 0, 7, -7));
final Path _jaw = pathOf((p) => p
  ..moveTo(11, 5.4)
  ..cubicTo(16, 5.6, 20, 6.4, 23, 7.6)
  ..cubicTo(21, 10.4, 15, 10.4, 11, 8.6));
final Path _foot = pathOf((p) => p
  ..moveTo(-5, -5)
  ..cubicTo(0, -7, 6, -6, 9, -3)
  ..lineTo(9, 4)
  ..lineTo(-5, 4)
  ..cubicTo(-8, 2, -8, -3, -5, -5));

Path _feather(double len, double w) => Path()
  ..moveTo(0, -w)
  ..cubicTo(len * .4, -w * 1.2, len * .86, -w * .8, len, 0)
  ..cubicTo(len * .86, w * .7, len * .4, w * 1.05, 0, w)
  ..close();

class GaleArt extends CastArt {
  GaleArt();

  @override
  int get id => 11;

  @override
  RigDims get dims => const RigDims(11, 56, 30, 30, 41, 39, 1.2, 9, 6, 20, 5);

  static final KPose _idle = KPose.from(pIdle,
      lean: .2, head: -.05, fu: .75, ff: -.25, bu: .35, bf: -.6, ft: .65, fs: -.1, bt: -.3, bs: -.65);

  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal;
  @override
  KPalette get altPalette => _palAlt;

  static final KPalette _pal = KPalette(
      skin: hex(0x6a4528), hair: hex(0xf6f3ee), tip: hex(0xf6f3ee), vest: hex(0x7d4c27), tank: hex(0x4a2c16),
      pants: hex(0x6a4528), pad: hex(0xf2bb2c), wrap: hex(0xf3e7c9), shoe: hex(0xf2bb2c), sole: hex(0x3a2616),
      accent: hex(0x59c8ff));
  static final KPalette _palAlt = KPalette(
      skin: hex(0x4b301c), hair: hex(0xdba85c), tip: hex(0xdba85c), vest: hex(0x3f5c8c), tank: hex(0x263a5e),
      pants: hex(0x4b301c), pad: hex(0xe6c240), wrap: hex(0xf6f6f6), shoe: hex(0xe6c240), sole: hex(0x1f2a3e),
      accent: hex(0xff9a3a));

  @override
  double get portraitWidth => 150;

  /// In the air the generic jump poses become a wing beat: both wings thrown up
  /// and out, fanned (the painter adds the flap from the frame clock).
  @override
  KPose rebase(KPose k) {
    if (!jumpish(k)) return k;
    return KPose.from(k, fu: 2.0, ff: 2.45, bu: 1.7, bf: 2.15, open: 1, baf: 0);
  }

  Pen? _pen;

  // -------------------------------------------------------------- paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final pen = (_pen ??= Pen(rp))..r = rp;
    final m = alt ? GalePal.alt : GalePal.base;
    final c = rp.c;
    final air = jumpish(p);
    _tailFan(pen, p, m, frame, air);
    if (p.baf < .5) _wing(pen, j, true, p, m, frame, air);
    if (p.blf < .5) _leg(pen, j, true, p, m);
    rp.fill(rrPath(-12, -6, 24, 21, 8), m.body, const Rect.fromLTRB(-12, -6, 12, 15), shade: m.bodyD);
    c.save();
    c.rotate(p.lean);
    rp.fill(_torso, m.body, const Rect.fromLTRB(-16, -54, 16, 0), shade: m.bodyD);
    // Pale breast feathers peeking through the open jacket.
    if (!pen.sil) {
      pen.clipped(_torso, _breastMarks, m.bodyL);
    }
    rp.fill(_jacket, m.jacket, const Rect.fromLTRB(-17, -50, 17, 0), shade: m.jacketD, lw: 2.3);
    if (!pen.sil) {
      rp.detail((pa) => pa
        ..moveTo(5, -48)
        ..lineTo(7, -8), w: 1.6, col: m.jacketD);
      rp.detail((pa) => pa
        ..moveTo(-12, -38)
        ..quadraticBezierTo(-8, -26, -10, -12), w: 1.3, col: pen.paint ? withA(m.jacketD, .6) : m.jacketD);
      // A little squadron patch on the chest.
      pen.flat(starPath(-2, -30, 4.2, 1.8, 5, -math.pi / 2), m.collar);
      if (pen.cel) pen.ink(starPath(-2, -30, 4.2, 1.8, 5, -math.pi / 2), 1);
    }
    rp.fill(_hem, m.jacketD, const Rect.fromLTRB(-11, -6, 11, 1), noHT: true, lw: 1.8);
    c.restore();
    _leg(pen, j, false, p, m);
    if (p.blf >= .5) _leg(pen, j, true, p, m);
    _headP(pen, j, p, m);
    if (p.baf >= .5) _wing(pen, j, true, p, m, frame, air);
    _wing(pen, j, false, p, m, frame, air);
  }

  void _tailFan(Pen pen, KPose p, GalePal m, double frame, bool air) {
    final r = pen.r;
    final sw = math.sin(frame * .07) * .06;
    final fan = air ? .55 : .3;
    for (var i = 0; i < 5; i++) {
      final a = math.pi - .05 + (i - 2) * fan * .5 + sw + (air ? .4 : .22);
      pen.c.save();
      pen.c.translate(-7, -3);
      pen.c.rotate(a);
      r.fill(_feather(i == 2 ? 40 : 35, 5.6), i.isEven ? m.tail : lt(m.tail, .0), const Rect.fromLTRB(0, -7, 42, 7),
          shade: m.tailD, lw: 1.8, noHT: i != 2);
      pen.c.restore();
    }
  }

  /// A wing: coverts along the arm, then primaries fanned from the forearm and
  /// wrist. [fan] widens it (open pose, jump); the flap swings it at the shoulder.
  void _wing(Pen pen, Joints j, bool b, KPose p, GalePal m, double frame, bool air) {
    final r = pen.r, c = pen.c;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final flap = air ? math.sin(frame * .42 + (b ? .7 : 0)) * .42 : (math.sin(frame * .05 + (b ? 1 : 0)) * .04);
    c.save();
    c.translate(sh.dx, sh.dy);
    c.rotate(flap);
    c.translate(-sh.dx, -sh.dy);
    final d = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    final px = -math.sin(d), py = math.cos(d);
    final sgn = (-px * 1.0 + py * .7) >= (px * 1.0 - py * .7) ? 1.0 : -1.0;
    final open = p.open > .5 || air;
    final fan = open ? 1.05 : .62;
    final base = b ? dk(m.feather, .28) : m.feather;
    const n = 7;
    for (var i = 0; i < n; i++) {
      final u = i / (n - 1);
      final root = lerpO(el, wr, .1 + .9 * u);
      final ang = d + sgn * (.12 + math.pow(1 - u, 1.1) * fan * 1.15) + (open ? -sgn * .08 * u : 0);
      final len = lerpD(open ? 26 : 26, open ? 50 : 46, math.pow(u, .8).toDouble());
      c.save();
      c.translate(root.dx + math.cos(d) * 6 * u, root.dy + math.sin(d) * 6 * u);
      c.rotate(ang);
      final col = i.isEven ? base : (b ? dk(m.featherL, .45) : lt(m.feather, .1));
      r.fill(_feather(len, 5.2), col, Rect.fromLTRB(0, -6, len, 6), shade: m.featherD, lw: 1.7, noHT: true);
      if (!pen.sil && u > .2) {
        r.detail((pa) => pa
          ..moveTo(len * .2, 0)
          ..lineTo(len * .85, 0), w: 1, col: pen.paint ? withA(m.featherD, .5) : m.featherD);
      }
      c.restore();
    }
    // Arm and the pale covert band over the feather roots.
    r.limb(sh, el, 7.4, 6.2, b ? dk(m.body, .28) : m.body, bulge: 2.2, shade: m.bodyD);
    r.limb(el, wr, 6.2, 5.2, b ? dk(m.body, .28) : m.body, bulge: 1.6, shade: m.bodyD);
    r.limb(lerpO(el, wr, .06), lerpO(el, wr, .8), 4.4, 4.0, b ? dk(m.bodyL, .3) : m.bodyL, noHT: true, lw: 1.6);
    if (!pen.sil) {
      r.detail((pa) {
        for (var i = 0; i < 3; i++) {
          final q = lerpO(sh, el, .25 + i * .26);
          pa.moveTo(q.dx - 3, q.dy - 1);
          pa.quadraticBezierTo(q.dx, q.dy + 3, q.dx + 3, q.dy - 1);
        }
      }, w: 1.1, col: pen.paint ? withA(m.bodyD, .6) : m.bodyD);
    }
    c.restore();
  }

  void _leg(Pen pen, Joints j, bool b, KPose pose, GalePal m) {
    final r = pen.r, c = pen.c;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    final yel = b ? dk(m.leg, .25) : m.leg;
    // Feathered thigh "trousers", then a scaly yellow shin and the talon foot.
    r.limb(hip, kn, 9.8, 7.8, b ? dk(m.body, .28) : m.body, bulge: 2.4, shade: m.bodyD);
    r.limb(lerpO(hip, kn, .3), lerpO(hip, kn, .98), 9.2, 7.6, b ? dk(m.bodyL, .3) : m.bodyL, noHT: true, lw: 1.8);
    r.limb(kn, an, 5.4, 4.6, yel, bulge: .8, shade: dk(m.leg, .45));
    final shin = b ? pose.bs : pose.fs, off = b ? pose.bfa : pose.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && pose.tuck < .3 && pose.ry < 1;
    c.save();
    c.translate(an.dx, an.dy + 3);
    c.rotate(planted ? 0 : -shin + off);
    c.scale(1.1, 1.1);
    r.fill(_foot, yel, const Rect.fromLTRB(-8, -7, 10, 4), lw: 1.9, shade: dk(m.leg, .45), noHT: true);
    for (final t in const [[-2.0, 3.0, 22.0, 5.0], [0.0, 0.5, 23.0, 0.2], [-1.0, -2.5, 20.0, -4.0]]) {
      final a = Offset(8, t[1]);
      final bb = Offset(t[2] - 3, t[3]);
      r.limb(a, bb, 2.4, 1.7, yel, noHT: true, lw: 1.5);
      r.fill(
          pathOf((q) => q
            ..moveTo(bb.dx - 1, bb.dy - 1.8)
            ..quadraticBezierTo(bb.dx + 5, bb.dy - 1, bb.dx + 6, bb.dy + 3.5)
            ..quadraticBezierTo(bb.dx + 2, bb.dy + 1.6, bb.dx - 1, bb.dy + 1.8)),
          b ? dk(m.strap, .1) : m.strap, Rect.fromLTRB(bb.dx - 1, bb.dy - 2, bb.dx + 7, bb.dy + 4), noHT: true, lw: 1.1);
    }
    r.limb(const Offset(-3, 0), const Offset(-10, 4), 2.2, 1.6, yel, noHT: true, lw: 1.5);
    c.restore();
  }

  void _headP(Pen pen, Joints j, KPose p, GalePal m) {
    final r = pen.r, c = pen.c;
    // Jacket collar: a ring of shearling around the neck, then the white neck.
    r.limb(j.neck, Offset(j.head.dx - 6, j.head.dy + 9), 8.6, 8, m.head, bulge: 1, shade: m.headD);
    final nk = j.neck;
    c.save();
    c.translate(nk.dx, nk.dy);
    c.rotate(p.lean * .6);
    r.fill(ellP(0, 1, 13, 7.5, -.15), m.jacket, const Rect.fromLTRB(-13, -7, 13, 9), shade: m.jacketD, lw: 2, noHT: true);
    for (var i = 0; i < 7; i++) {
      final a = math.pi * (.95 + i * .155);
      final x = math.cos(a) * 11.5, y = 1 + math.sin(a) * 6.2 + 3;
      r.fill(ellP(x, y, 4.6, 4.2), m.collar, Rect.fromLTRB(x - 5, y - 5, x + 5, y + 5), lw: 1.5, noHT: true, shade: dk(m.collar, .25));
    }
    c.restore();
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.2, 1.2);
    r.fill(_head, m.head, const Rect.fromLTRB(-17, -16, 13, 15), shade: m.headD);
    if (!pen.sil) {
      r.detail((pa) => pa
        ..moveTo(-13, -4)
        ..quadraticBezierTo(-9, -1, -10, 5)
        ..moveTo(-10, -9)
        ..quadraticBezierTo(-5, -6, -6, 1)
        ..moveTo(-12, 6)
        ..quadraticBezierTo(-7, 8, -4, 12), w: 1.1, col: pen.paint ? withA(m.headD, .6) : m.headD);
    }
    r.fill(_beak, m.beak, const Rect.fromLTRB(6, -11, 29, 15), shade: m.beakD, lw: 1.9, noHT: true);
    r.fill(_jaw, m.beakD, const Rect.fromLTRB(10, 4, 24, 11), lw: 1.4, noHT: true);
    if (!pen.sil) {
      r.detail((pa) => pa
        ..moveTo(23.5, 7.4)
        ..lineTo(11.5, 5.6), w: 1.2);
      pen.circ(12.5, -1.2, .8, kInk);
      // Fierce eye under a heavy brow.
      pen.flat(ellP(6.6, -4, 3.6, 3.3), const Color(0xFFFFFFFF));
      pen.circ(7.2, -3.8, 2.7, m.eye);
      pen.circ(7.8, -3.8, 1.3, kInk);
      pen.circ(8.4, -4.7, .55, const Color(0xFFFFFFFF));
      r.detail((pa) => pa
        ..moveTo(1, -8.4)
        ..lineTo(11.4, -3.8), w: 3, col: dk(m.headD, .45));
      // Goggles pushed up: strap band across the crown, two lenses on top.
      r.detail((pa) => pa
        ..moveTo(-16, -5)
        ..quadraticBezierTo(-6, -17, 10, -9), w: 4.2, col: m.strap);
      pen.circ(7.4, -12.4, 5.2, m.rim);
      pen.circ(7.4, -12.4, 3.8, withA(m.lens, .9));
      pen.circ(6.2, -13.6, 1.3, const Color(0xCCFFFFFF));
      pen.circ(-2.2, -14.2, 6.3, m.rim);
      pen.circ(-2.2, -14.2, 4.8, m.lens);
      pen.circ(-3.6, -15.8, 1.7, const Color(0xCCFFFFFF));
      if (pen.cel) {
        c.drawCircle(const Offset(-2.2, -14.2), 6.3, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = kInk);
        c.drawCircle(const Offset(7.4, -12.4), 5.2, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = kInk);
      }
    }
    c.restore();
  }

  // -------------------------------------------------------------- poses

  KPose _q(
          {double? lean, double? head, double? fu, double? ff, double? bu, double? bf, double? ft, double? fs,
          double? bt, double? bs, double? rx, double? ry, double? baf, double? open, double? spin, double? tuck, double? blf}) =>
      KPose.from(_idle,
          lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs, rx: rx, ry: ry,
          baf: baf, open: open, spin: spin, tuck: tuck, blf: blf);

  @override
  (KPose, KPose, KPose)? readyPoses() => (
        _q(fu: 3.3, ff: 3.8, bu: 3.0, bf: 3.5, baf: 1, lean: -.08, rx: -4, open: 1),
        _q(fu: 1.3, ff: 1.1, bu: 1.2, bf: 1.0, baf: 1, lean: .5, rx: 14, open: 1, ft: .8, bt: -.5),
        _q(fu: 1.2, ff: 2.9, bu: 1.0, bf: 3.0, baf: 1, lean: .12, open: 1),
      );

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    final d = dims;
    final I = _idle;
    // Wings swept straight back: the streamlined glide / dive carriage.
    KPose swept({double lean = 1.1}) => _q(
        lean: lean, head: -.35, fu: -1.35, ff: -1.6, bu: -1.2, bf: -1.5, open: 1, ft: 1.6, fs: 1.3, bt: 1.2, bs: .9, baf: 0);
    switch (m.name) {
      case 'standLight':
        final x = lunge(m, _q(fu: 1.45, ff: 1.55, lean: .3, rx: 10), Jt.fHa, d);
        return MoveAnim(strike(m, I, _q(fu: -.3, ff: -.9, lean: .1), x, hold: KPose.from(x, fu: 1.55)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(m, _q(bu: 1.5, bf: 1.55, baf: 1, lean: .32, rx: 10), Jt.bHa, d);
        return MoveAnim(strike(m, I, _q(bu: -.4, bf: -1.0, baf: 1, lean: .1), x, hold: KPose.from(x, bu: 1.55)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        final x = lunge(m, _q(fu: 1.2, ff: .9, bu: 1.1, bf: .8, baf: 1, lean: .6, rx: 12, open: 1, ft: .8, bt: -.5), Jt.fHa, d);
        return MoveAnim(strike(m, I, _q(fu: 3.3, ff: 3.8, bu: 3.0, bf: 3.5, baf: 1, lean: -.1, rx: -4, open: 1), x,
            hold: KPose.from(x, lean: .66), windAt: .65),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a + 2);
      case 'wingGust':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final back = _q(fu: -.9, ff: -1.4, bu: -.7, bf: -1.2, lean: -.18, open: 1, ft: .55, rx: -3);
        final push = _q(fu: 1.5, ff: 1.55, bu: 1.4, bf: 1.5, baf: 1, lean: .3, open: 1, rx: 6);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rnd(sp * .55)), back),
          Key(sp, push, 1),
          Key(sp + rnd((t - sp) * .4), KPose.from(push, fu: 1.1, ff: 1.3, bu: 1.0, bf: 1.2, lean: .25)),
          Key(t, I),
        ]));
      case 'talonGlide':
        final coil = _q(lean: .5, ft: 1.1, fs: -.4, bt: .3, bs: -1.0, fu: -.3, ff: -.9, bu: -.3, bf: -.8, open: 1);
        final lift = _q(lean: .3, fu: 3.1, ff: 3.6, bu: 2.8, bf: 3.3, baf: 1, open: 1, ft: .5, bt: -.2);
        final dive = KPose.from(swept(lean: .85), ft: 1.2, fs: .9);
        return MoveAnim(mono([
          Key(0, I),
          Key(1, coil),
          Key(3, lift, 1),
          Key(8, swept()),
          Key(s, swept(lean: 1.15), 1),
          Key(s + a - 2, KPose.from(swept(lean: 1.05), ft: 1.5)),
          Key(s + a, dive),
          Key(s + a + rnd(r * .5), _q(lean: .5, ft: 1.0, fs: -.3, bt: .3, bs: -.9)),
          Key(t, I),
        ]), smear: Jt.fAn, smearA: s, smearB: s + a);
      case 'wingSweep':
        final wind = _q(lean: .55, ft: 1.0, fs: -.35, bt: .3, bs: -.95, fu: -.5, ff: -.9, bu: -.9, bf: -1.2, open: 1, rx: -4);
        final x = lunge(m, _q(lean: .72, ft: 1.15, fs: -.4, bt: .4, bs: -1.0, fu: .95, ff: 1.05, bu: -.9, bf: -1.3, open: 1, rx: 6), Jt.fHa, d, max: 30);
        return MoveAnim(strike(m, I, wind, x, rec: _q(lean: .55, ft: 1.0, fs: -.3, bt: .3, bs: -.95), windAt: .6, recAt: .5),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a + 2);
      case 'skyDive':
        final coil = _q(lean: .5, ft: 1.1, fs: -.4, bt: .3, bs: -1.0, fu: -.4, ff: -.9, bu: -.4, bf: -.8, open: 1);
        final rise = _q(lean: -.08, fu: 3.1, ff: 3.3, bu: 3.0, bf: 3.2, baf: 1, ft: .3, fs: 0, bt: -.1, bs: -.1, open: 1);
        final flip = _q(lean: .15, fu: 3.4, ff: 3.9, bu: 3.2, bf: 3.7, baf: 1, ft: 1.0, fs: .6, bt: .6, bs: .2, open: 1, head: .1);
        final dive = _q(lean: .6, head: .25, fu: 3.6, ff: 4.0, bu: 3.4, bf: 3.8, baf: 1, ft: 1.05, fs: 1.0, bt: .85, bs: .75, open: 1);
        return MoveAnim(mono([
          Key(0, I),
          Key(2, coil),
          Key(5, rise, 1),
          Key(mx(8, s - 8), rise),
          Key(mx(9, s - 4), flip),
          Key(s, dive, 1),
          Key(s + a, dive),
          Key(s + a + rnd(r * .5), _q(lean: .4, ft: 1.0, fs: -.3, bt: .3, bs: -.9, open: 1)),
          Key(t, I),
        ]), smear: Jt.fAn, smearA: s, smearB: s + a);
      case 'stormTalon':
        final ws = m.windows;
        final up = _q(lean: -.1, fu: 3.2, ff: 3.5, bu: 3.0, bf: 3.4, baf: 1, open: 1, ft: .5, rx: -2);
        KPose whirl(double spin) => _q(
            tuck: 1, ry: 14, lean: .1, fu: 1.8, ff: 1.57, bu: 1.7, bf: 1.57, baf: 1, open: 1, ft: 2.0, fs: -.3, bt: 1.8, bs: -.4, spin: spin);
        final end = ws.isEmpty ? s + a : ws.last.end;
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, s ~/ 2), up),
          Key(mx(2, s - 1), KPose.from(up, lean: -.16, ry: 8)),
          Key(s, whirl(0), 1),
          Key(end, whirl(-8 * math.pi), 2),
          Key(end + rnd(r * .4), _q(lean: .3, open: 1, fu: 1.2, ff: 1.6)),
          Key(t, I),
        ]), smear: Jt.fHa, smearA: s, smearB: end);
    }
    return null;
  }

  // -------------------------------------------------------------- projectiles

  @override
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) {
    final h = def.h / def.w * 31;
    final painted = look == FightLook.painted;
    final wind = GalePal.base.wind;
    c.save();
    c.translate(0, -h / 2);
    if (painted) drawGlow(c, Offset.zero, h * .6, const Color(0x558CDCFF));
    final hh = h * .5;
    for (var i = 3; i >= 0; i--) {
      final x = -i * 8.5 + math.sin(age * .35 - i) * 1.2;
      final sc = 1 - i * .1;
      final w = (10 + (3 - i) * 2.2) * sc;
      final y = hh * sc;
      final p = Path()
        ..moveTo(x - 4, -y)
        ..quadraticBezierTo(x + w * 2, 0, x - 4, y)
        ..quadraticBezierTo(x + w * .65, 0, x - 4, -y)
        ..close();
      final a = i == 0 ? 1.0 : .8 - i * .17;
      if (painted) {
        c.drawPath(p, Paint()
          ..blendMode = BlendMode.plus
          ..color = withA(wind, .75 * a));
      } else {
        c.drawPath(p, Paint()..color = withA(i == 0 ? const Color(0xFFFFFFFF) : wind, a));
        if (look == FightLook.cartoon) {
          c.drawPath(p, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round
            ..color = withA(kInk, a));
        }
      }
    }
    // A curl of wind at the leading edge and a few loose feathers.
    final curl = Path()
      ..moveTo(10, -hh * .55)
      ..quadraticBezierTo(21, -hh * .5, 18, -hh * .15)
      ..quadraticBezierTo(15, 3, 21, 4);
    c.drawPath(curl, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = painted ? withA(const Color(0xFFFFFFFF), .9) : const Color(0xFFFFFFFF));
    for (var i = 0; i < 3; i++) {
      final t = ((age * .05) + i / 3) % 1;
      final fx = -10 - t * 24, fy = (hash01(i, 8) - .5) * hh * 1.6 + math.sin(t * 9 + i) * 3;
      c.save();
      c.translate(fx, fy);
      c.rotate(-.4 + t * 2);
      c.drawPath(_feather(7, 1.7), Paint()..color = withA(GalePal.base.featherL, 1 - t));
      c.restore();
    }
    c.restore();
    return true;
  }

  // -------------------------------------------------------------- effects

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final fr = FxFrame(cam, s, player);
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final pal = alt ? GalePal.alt : GalePal.base;
    final painted = look == FightLook.painted;
    final f = fr.f;
    final line = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..blendMode = painted ? BlendMode.plus : BlendMode.srcOver;
    void streaks(Offset at, int n, double len, double spread, double alpha, {bool vertical = false}) {
      for (var i = 0; i < n; i++) {
        final o = (hash01(i, 6) - .5) * spread;
        final l = len * (.6 + hash01(i, 7) * .6);
        final a = Offset(vertical ? at.dx + o : at.dx - hash01(i, 2) * 10, vertical ? at.dy - hash01(i, 2) * 10 : at.dy + o);
        final b = Offset(vertical ? a.dx : a.dx - l, vertical ? a.dy - l : a.dy);
        c.drawLine(a, b, line
          ..strokeWidth = 2 + hash01(i, 9) * 2
          ..color = withA(pal.wind, alpha * (.5 + hash01(i, 1) * .5)));
      }
    }

    c.save();
    fr.enter(c);
    final pose = poseFor(s, player);
    final pel = fr.joint(pose, Jt.pel);
    final mid = Offset(pel.dx, pel.dy - 30);
    final m = fr.move;
    if (m == null) {
      if (f.airDashT > 0) {
        streaks(Offset(mid.dx - 14, mid.dy), 7, 70, 70, .75);
        c.drawOval(Rect.fromCenter(center: Offset(mid.dx - 6, mid.dy), width: 34, height: 80), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = withA(pal.wind, .7));
      }
      c.restore();
      return;
    }
    final sf = f.sf;
    switch (m.name) {
      case 'talonGlide':
        if (sf >= 3 && sf < m.startup + m.active) streaks(Offset(mid.dx - 24, mid.dy), 6, 56, 54, .7);
        break;
      case 'skyDive':
        if (sf >= 4 && sf < m.startup - 4) streaks(Offset(mid.dx - 4, pel.dy + 40), 6, 60, 36, .65, vertical: true);
        if (sf >= m.startup - 4 && sf < m.startup + m.active) {
          streaks(Offset(mid.dx - 18, pel.dy - 70), 7, 56, 40, .8, vertical: true);
          c.save();
          c.translate(pel.dx + 20, 0);
          if (sf > m.startup + m.active - 3) groundRing(c, look, (sf - (m.startup + m.active - 3)) / 12, 80, pal.wind);
          c.restore();
        }
        break;
      case 'wingSweep':
        if (sf >= m.startup - 2 && sf < m.startup + m.active + 5) {
          final k = (sf - (m.startup - 2)) / (m.active + 7);
          c.save();
          c.translate(pel.dx + 40, -6);
          c.rotate(-.1);
          final arc = Path()
            ..moveTo(-40, 0)
            ..quadraticBezierTo(8, -22 * (1 - k * .5), 46, -4);
          c.drawPath(arc, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - k) + 1
            ..strokeCap = StrokeCap.round
            ..blendMode = painted ? BlendMode.plus : BlendMode.srcOver
            ..color = withA(pal.wind, 1 - k));
          c.restore();
        }
        break;
      case 'wingGust':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : 0;
        if (sf >= sp - 4 && sf < sp + 6) {
          final k = (sf - (sp - 4)) / 10;
          for (var i = 0; i < 2; i++) {
            c.drawArc(Rect.fromCenter(center: Offset(mid.dx + 10, mid.dy - 4), width: 70 + i * 22, height: 70 + i * 22), -.9, 1.8, false,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..strokeCap = StrokeCap.round
                  ..blendMode = painted ? BlendMode.plus : BlendMode.srcOver
                  ..color = withA(pal.wind, (1 - k) * .8));
          }
        }
        break;
      case 'stormTalon':
        if (sf >= m.startup - 2) {
          final fade = sf > m.startup + m.active ? clamp01(1 - (sf - m.startup - m.active) / 14) : 1.0;
          final cx = pel.dx + 4, cy = pel.dy - 34;
          for (var i = 0; i < 4; i++) {
            final rx = 46 + i * 11.0, ry = 74 + i * 10.0;
            final a0 = s.frame * (.32 + i * .05) + i * 1.7;
            c.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), a0, 1.5, false,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3.4 - i * .4
                  ..strokeCap = StrokeCap.round
                  ..blendMode = painted ? BlendMode.plus : BlendMode.srcOver
                  ..color = withA(i.isEven ? pal.wind : const Color(0xFFFFFFFF), .85 * fade));
            if (look == FightLook.cartoon) {
              c.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), a0, 1.5, false,
                  Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = .9
                    ..color = withA(kInk, .5 * fade));
            }
          }
          if (painted) drawGlow(c, Offset(cx, cy), 100, withA(pal.wind, .22 * fade));
        }
        break;
    }
    c.restore();
  }
}
