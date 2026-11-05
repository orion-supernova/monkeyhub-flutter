// RYOKO (8) - tigress, claw rushdown. Orange with bold black stripes, white
// muzzle and chest, a sleeveless black gi top with a red belt, claw gauntlets.
// Low predatory stance; her claws leave three-line slashes (paintMoveFx).
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

class RyokoPal {
  final Color fur, furD, furL, stripe, gi, giD, belt, beltD, claw, eye, iris, nose, ear, glow;
  const RyokoPal({
    required this.fur, required this.furD, required this.furL, required this.stripe, required this.gi,
    required this.giD, required this.belt, required this.beltD, required this.claw, required this.eye,
    required this.iris, required this.nose, required this.ear, required this.glow,
  });
  static final RyokoPal base = RyokoPal(
    fur: hex(0xf08a24), furD: hex(0xb4561a), furL: hex(0xfff4e4), stripe: hex(0x1b1220), gi: hex(0x1f1c2a),
    giD: hex(0x0f0d16), belt: hex(0xd8362b), beltD: hex(0x8a1d1a), claw: hex(0xe9eef5), eye: hex(0xfff6d0),
    iris: hex(0xf2b01e), nose: hex(0xd9646c), ear: hex(0xf6c9c0), glow: hex(0xffb347));
  /// Mirror match: a snow tigress in teal with a gold belt and gold claws.
  static final RyokoPal alt = RyokoPal(
    fur: hex(0xe3ebf6), furD: hex(0xa4b2cc), furL: hex(0xffffff), stripe: hex(0x2a3454), gi: hex(0x0f5a66),
    giD: hex(0x08353d), belt: hex(0xf0b72e), beltD: hex(0xa97a12), claw: hex(0xf7d878), eye: hex(0xf0fbff),
    iris: hex(0x4fc3ee), nose: hex(0xe69aa8), ear: hex(0xf5d0dc), glow: hex(0x7fe0ff));
}

// ------------------------------------------------------------------ static paths

final Path _torso = pathOf((p) => p
  ..moveTo(-10, 0)
  ..cubicTo(-14, -12, -15, -30, -12, -44)
  ..cubicTo(-10, -53, -3, -57, 3, -57)
  ..cubicTo(10, -56, 14, -49, 14, -39)
  ..cubicTo(14, -27, 12, -12, 9, 0));
final Path _chest = pathOf((p) => p
  ..moveTo(4, -55)
  ..cubicTo(12, -53, 14, -44, 13, -36)
  ..cubicTo(12, -22, 10, -10, 7, -2)
  ..cubicTo(2, -12, 0, -30, 1, -46));
final Path _gi = pathOf((p) => p
  ..moveTo(-11, -2)
  ..cubicTo(-16, -14, -16, -34, -12, -46)
  ..cubicTo(-9, -54, -5, -57, -1, -57)
  ..lineTo(4, -31)
  ..lineTo(8, -55)
  ..cubicTo(11, -53, 13, -49, 14, -42)
  ..cubicTo(14, -28, 12, -12, 9, -2));
final Path _giTrim = pathOf((p) => p
  ..moveTo(-1, -57)
  ..lineTo(4, -31)
  ..lineTo(8, -55)
  ..lineTo(6.2, -55)
  ..lineTo(4, -37)
  ..lineTo(1.2, -55));
final Path _head = pathOf((p) => p
  ..moveTo(-3, -16)
  ..cubicTo(-13, -16, -18, -8, -17, 1)
  ..cubicTo(-16, 9, -10, 15, -1, 16)
  ..cubicTo(5, 17, 11, 15, 14, 11)
  ..cubicTo(18, 7, 18, 0, 16, -5)
  ..cubicTo(14, -12, 8, -16, -3, -16));
final Path _muzzle = pathOf((p) => p
  ..moveTo(5, 0)
  ..cubicTo(10, -4, 19, -3, 22, 2)
  ..cubicTo(24, 7, 20, 12, 13, 12.5)
  ..cubicTo(7, 12, 3, 7, 5, 0));
final Path _nose = pathOf((p) => p
  ..moveTo(19.4, -1.8)
  ..lineTo(24, -.6)
  ..lineTo(21.6, 3.2));
final Path _ruff = pathOf((p) => p
  ..moveTo(-10, 5)
  ..lineTo(-20, 7)
  ..lineTo(-14, 10.5)
  ..lineTo(-19, 15)
  ..lineTo(-9, 15.5)
  ..lineTo(-2, 13));
final Path _irisCut = Path.combine(PathOperation.intersect, _eyeP, Path()..addOval(Rect.fromCircle(center: const Offset(9, -4.2), radius: 2.9)));
final Path _pupilCut = Path.combine(PathOperation.intersect, _eyeP, ellP(9.3, -4.2, .9, 2.8));
final Path _eyeP = pathOf((p) => p
  ..moveTo(3, -3)
  ..quadraticBezierTo(8, -8.2, 13.4, -4.2)
  ..quadraticBezierTo(8, -1.2, 3, -3));
final Path _headMarks = () {
  final p = Path();
  wedge(p, -6, -17, 1, 9, 4);
  wedge(p, 0, -17.5, 1.5, 9.5, 4);
  wedge(p, 6, -16.5, 1, 7.5, 3.4);
  wedge(p, -18, 0, 9, 2, 4);
  wedge(p, -17, 6, 8, 0, 3.6);
  return p;
}();
final Path _fist = rrPath(-1, -5.5, 12, 11, 5);
final Path _foot = pathOf((p) => p
  ..moveTo(-6, -6)
  ..cubicTo(-2, -9, 6, -7, 10, -3)
  ..lineTo(19, -1)
  ..cubicTo(23, 0, 23, 4, 20, 5)
  ..lineTo(-6, 5)
  ..cubicTo(-9, 4, -9, -3, -6, -6));
final Path _toes = pathOf((p) => p
  ..moveTo(12, -2)
  ..lineTo(19.5, -1)
  ..cubicTo(23, 0, 23, 4, 20, 5)
  ..lineTo(12, 5));

Path _claw(double y, double len, double bend) => Path()
  ..moveTo(9, y - 1.6)
  ..quadraticBezierTo(9 + len * .6, y - 1.2 + bend * .3, 9 + len, y + bend)
  ..quadraticBezierTo(9 + len * .55, y + 1.8 + bend * .3, 9, y + 1.8)
  ..close();

// ------------------------------------------------------------------ art

class RyokoArt extends CastArt {
  RyokoArt();

  @override
  int get id => 8;

  @override
  RigDims get dims => const RigDims(8, 56, 31, 27, 40, 38, 1.27, 8, 6, 20, 4);

  static final KPose _idle = KPose.from(pIdle,
      lean: .38, head: -.18, fu: .8, ff: 2.0, bu: .45, bf: 2.35, ft: .85, fs: -.25, bt: -.35, bs: -.85);

  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal;
  @override
  KPalette get altPalette => _palAlt;

  static final KPalette _pal = KPalette(
      skin: hex(0xf08a24), hair: hex(0x1b1220), tip: hex(0xfff4e4), vest: hex(0x1f1c2a), tank: hex(0x1b1220),
      pants: hex(0x1f1c2a), pad: hex(0xd8362b), wrap: hex(0xe9eef5), shoe: hex(0xf08a24), sole: hex(0x1b1220),
      accent: hex(0xd8362b));
  static final KPalette _palAlt = KPalette(
      skin: hex(0xe3ebf6), hair: hex(0x2a3454), tip: hex(0xffffff), vest: hex(0x0f5a66), tank: hex(0x2a3454),
      pants: hex(0x0f5a66), pad: hex(0xf0b72e), wrap: hex(0xf7d878), shoe: hex(0xe3ebf6), sole: hex(0x2a3454),
      accent: hex(0xf0b72e));

  @override
  double get portraitWidth => 130;

  Pen? _pen;

  // -------------------------------------------------------------- paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final pen = (_pen ??= Pen(rp))..r = rp;
    final m = alt ? RyokoPal.alt : RyokoPal.base;
    final r = rp;
    final c = rp.c;
    // Tail: a long S ringed with black, tip black, flicking while she waits.
    final sw = math.sin(frame * .06) * 5;
    final tail = bez(const Offset(-8, -5), Offset(-34, 6 + sw * .3), Offset(-54, -14 + sw), Offset(-42, -46 + sw * 1.3), 14);
    final tailP = tubeFn(tail, (t) => lerpD(5.4, 3.6, t));
    r.fill(tailP, m.fur, bbOf(tail, 8), shade: m.furD, lw: 2.2);
    pen.clipped(
        tailP,
        crossBars(tail, const [.16, .3, .44, .58, .72], 7, 2.8)..addPath(crossBars(tail, const [.9], 7, 8), Offset.zero),
        m.stripe);

    if (p.baf < .5) _arm(pen, j, true, p, m);
    if (p.blf < .5) _leg(pen, j, true, p, m);
    // Gi shorts.
    r.fill(rrPath(-13, -6, 26, 22, 9), m.gi, const Rect.fromLTRB(-13, -6, 13, 16), shade: m.giD);
    c.save();
    c.rotate(p.lean);
    r.fill(_torso, m.fur, const Rect.fromLTRB(-16, -58, 15, 0), shade: m.furD);
    r.fill(_chest, m.furL, const Rect.fromLTRB(0, -55, 14, -2), noHT: true, lw: 1.4);
    pen.clipped(_torso, _bodyMarks, m.stripe);
    r.fill(_gi, m.gi, const Rect.fromLTRB(-17, -58, 15, -2), shade: m.giD, lw: 2.2);
    if (!pen.sil) {
      pen.flat(_giTrim, m.belt);
      if (pen.cel) pen.ink(_giTrim, 1);
      r.detail((pa) => pa
        ..moveTo(-11, -40)
        ..quadraticBezierTo(-8, -28, -10, -14), w: 1.4, col: pen.paint ? withA(m.furL, .22) : lt(m.gi, .25));
    }
    // Red belt, knot and two tails that flutter.
    r.fill(rrPath(-12, -10, 25, 8, 2.5), m.belt, const Rect.fromLTRB(-12, -10, 13, -2), shade: m.beltD, noHT: true, lw: 1.8);
    final f1 = math.sin(frame * .17) * 3, f2 = math.sin(frame * .17 + 1.2) * 3.5;
    r.fill(
        pathOf((q) => q
          ..moveTo(-11, -8)
          ..lineTo(-24, -4 + f1)
          ..lineTo(-22, 1 + f1)
          ..lineTo(-10, -4)),
        m.belt, const Rect.fromLTRB(-24, -10, -9, 2), lw: 1.5, noHT: true, shade: m.beltD);
    r.fill(
        pathOf((q) => q
          ..moveTo(-11, -6)
          ..lineTo(-21, 3 + f2)
          ..lineTo(-17, 7 + f2)
          ..lineTo(-9, -2)),
        m.belt, const Rect.fromLTRB(-22, -6, -8, 8), lw: 1.5, noHT: true, shade: m.beltD);
    r.fill(rrPath(-14, -9.5, 7, 7.5, 2.5), m.beltD, const Rect.fromLTRB(-14, -10, -7, -2), noHT: true, lw: 1.5);
    c.restore();
    _leg(pen, j, false, p, m);
    if (p.blf >= .5) _leg(pen, j, true, p, m);
    _headP(pen, j, p, m, frame);
    if (p.baf >= .5) _arm(pen, j, true, p, m);
    _arm(pen, j, false, p, m);
  }

  static final Path _bodyMarks = () {
    final p = Path();
    wedge(p, -15, -48, 11, 3, 4.5);
    wedge(p, -15, -39, 12, 2, 4.5);
    wedge(p, -15, -30, 12, 1, 4.5);
    wedge(p, -14, -21, 11, 0, 4.2);
    wedge(p, -13, -12, 10, -1, 4);
    return p;
  }();

  /// Stripes on a limb, cut to the limb once per (site, length) in the limb's
  /// own frame (like [RigPainter.limb]) and drawn with a transform: no clip,
  /// no per-frame boolean op.
  static final Map<(int, int), Path> _stripeCuts = {};

  void _stripes(Pen pen, int site, Offset a, Offset b, double r1, double r2, double bulge, double sr1, double sr2,
      List<double> ts, double len, double base, Color col) {
    if (pen.sil) return;
    final d = b - a;
    final l = (d.distance * 2).round() / 2;
    if (l < .5) return;
    final cut = _stripeCuts.putIfAbsent((site, (l * 2).round()), () {
      final end = Offset(l, 0);
      return Path.combine(PathOperation.intersect, limbPath(Offset.zero, end, r1, r2, bulge),
          limbStripes(Offset.zero, end, sr1, sr2, ts, len: len, base: base));
    });
    final c = pen.c;
    c.save();
    c.translate(a.dx, a.dy);
    c.rotate(math.atan2(d.dy, d.dx));
    pen.flat(cut, col);
    c.restore();
  }

  void _arm(Pen pen, Joints j, bool b, KPose pose, RyokoPal m) {
    final r = pen.r, c = pen.c;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final fur = b ? dk(m.fur, .3) : m.fur;
    final st = b ? dk(m.stripe, .1) : m.stripe;
    r.limb(sh, el, 6.6, 5.4, fur, bulge: 1.8, shade: m.furD);
    _stripes(pen, 0, sh, el, 6.6, 5.4, 1.8, 6, 5, const [.3, .62, .9], .7, 2.8, st);
    r.limb(el, wr, 5.6, 4.9, fur, bulge: 1.2, shade: m.furD);
    _stripes(pen, 1, el, wr, 5.6, 4.9, 1.2, 5.4, 4.8, const [.22, .5], .6, 2.6, st);
    // Gauntlet: a black bracer with a red band, then the claws.
    final g0 = lerpO(el, wr, .3);
    r.limb(g0, wr, 6.5, 6.1, b ? dk(m.gi, .1) : m.gi, noHT: true, lw: 2, shade: m.giD);
    r.limb(lerpO(el, wr, .3), lerpO(el, wr, .42), 6.7, 6.6, b ? dk(m.belt, .3) : m.belt, noHT: true, lw: 1.6);
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    final claw = b ? dk(m.claw, .3) : m.claw;
    final open = pose.open > .5;
    // Claws sit behind the knuckles so the fist overlaps their roots.
    for (var i = -1; i <= 1; i++) {
      final y = i * (open ? 4.6 : 3.4);
      r.fill(_claw(y, 15.5 - (i == 0 ? 0 : 1.5), i * (open ? 3.6 : 1.4)), claw,
          Rect.fromLTRB(8, y - 5, 26, y + 8), lw: 1.3, noHT: true, shade: dk(claw, .4));
    }
    r.fill(_fist, b ? dk(m.furL, .3) : m.furL, const Rect.fromLTRB(-1, -6, 11, 6), lw: 2, shade: m.furD);
    r.detail((pa) => pa
      ..moveTo(7, -4.5)
      ..lineTo(7, 4.5), w: 1);
    c.restore();
  }

  void _leg(Pen pen, Joints j, bool b, KPose pose, RyokoPal m) {
    final r = pen.r, c = pen.c;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    final fur = b ? dk(m.fur, .3) : m.fur;
    r.limb(hip, kn, 9.4, 7.4, fur, bulge: 2.4, shade: m.furD);
    _stripes(pen, 2, hip, kn, 9.4, 7.4, 2.4, 9, 7.4, const [.5, .78], .6, 3, b ? dk(m.stripe, .1) : m.stripe);
    r.limb(hip, lerpO(hip, kn, .52), 10.4, 9.2, b ? dk(m.gi, .1) : m.gi, noHT: true, lw: 2, shade: m.giD);
    r.limb(kn, an, 6.8, 5.3, fur, bulge: 1.6, shade: m.furD);
    _stripes(pen, 3, kn, an, 6.8, 5.3, 1.6, 6.4, 5.2, const [.25, .5], .6, 2.8, b ? dk(m.stripe, .1) : m.stripe);
    r.limb(lerpO(kn, an, .66), an, 5.9, 5.7, b ? dk(m.gi, .1) : m.gi, noHT: true, lw: 1.8, shade: m.giD);
    final shin = b ? pose.bs : pose.fs, off = b ? pose.bfa : pose.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && pose.tuck < .3 && pose.ry < 1;
    c.save();
    c.translate(an.dx, an.dy + 3);
    c.rotate(planted ? 0 : -shin + off);
    r.fill(_foot, fur, const Rect.fromLTRB(-9, -9, 23, 5), lw: 2, shade: m.furD);
    if (!pen.sil) {
      pen.flat(_toes, b ? dk(m.furL, .3) : m.furL);
      if (pen.cel) pen.ink(_toes, 1.2);
      r.detail((pa) => pa
        ..moveTo(15, 0)
        ..lineTo(15, 4.6)
        ..moveTo(18.5, 0)
        ..lineTo(18.5, 4.6), w: 1);
    }
    c.restore();
  }

  void _headP(Pen pen, Joints j, KPose p, RyokoPal m, double frame) {
    final r = pen.r, c = pen.c;
    final neckTop = Offset(j.head.dx - 6, j.head.dy + 9);
    r.limb(j.neck, neckTop, 8.8, 8.2, dk(m.fur, .05), bulge: 1, shade: m.furD);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.18, 1.18);
    // Far ear, then the head, near ear on top.
    r.fill(ellP(2, -15.5, 4.6, 5.8, .3), dk(m.fur, .3), const Rect.fromLTRB(-3, -22, 7, -10), lw: 1.6, noHT: true);
    r.fill(_ruff, m.furL, const Rect.fromLTRB(-20, 4, -1, 16), lw: 1.6, noHT: true);
    r.fill(_head, m.fur, const Rect.fromLTRB(-18, -17, 19, 17), shade: m.furD);
    pen.clipped(_head, _headMarks, m.stripe);
    r.fill(_muzzle, m.furL, const Rect.fromLTRB(3, -4, 24, 13), lw: 1.7, noHT: true);
    r.fill(ellP(-8.5, -15, 6, 7.4, -.35), m.fur, const Rect.fromLTRB(-15, -22, -2, -7), lw: 1.8, shade: m.furD);
    if (!pen.sil) {
      r.fill(ellP(-8, -14.5, 3.2, 4.4, -.35), m.ear, const Rect.fromLTRB(-12, -19, -4, -9), lw: 1, noHT: true);
      pen.flat(ellP(-9.5, -19.5, 4.2, 2.2, -.5), m.stripe);
      pen.flat(_nose, m.nose);
      pen.ink(_nose, 1.2);
      // Eye: amber with a slit pupil under a hard black brow.
      r.fill(_eyeP, m.eye, const Rect.fromLTRB(3, -9, 14, -1), noHT: true, lw: 1.2);
      pen.flat(_irisCut, m.iris);
      pen.flat(_pupilCut, kInk);
      pen.circ(10.4, -5.2, .7, const Color(0xFFFFFFFF));
      r.detail((pa) => pa
        ..moveTo(1.5, -9.6)
        ..quadraticBezierTo(8, -9, 14.4, -4.4), w: 2.6, col: m.stripe);
      // Far eye, smaller, on the bridge.
      r.fill(ellP(17, -4.5, 1.7, 2.4, .2), m.iris, const Rect.fromLTRB(15, -7, 19, -2), lw: .9, noHT: true);
      r.detail((pa) => pa
        ..moveTo(21.5, 3.2)
        ..lineTo(21, 7.2)
        ..moveTo(21, 7.2)
        ..quadraticBezierTo(15, 10.5, 8.5, 9.2), w: 1.3);
      // A small fang over the lip.
      pen.flat(pathOf((q) => q
        ..moveTo(13.6, 9.2)
        ..lineTo(15.4, 9.4)
        ..lineTo(14.6, 12.6)), const Color(0xFFFFFFFF));
      pen.circ(17.5, 5.2, .7, m.stripe);
      pen.circ(15.4, 5.7, .7, m.stripe);
      pen.circ(19.6, 6.2, .7, m.stripe);
    }
    c.restore();
  }

  // -------------------------------------------------------------- poses

  KPose _q(
          {double? lean, double? head, double? fu, double? ff, double? bu, double? bf, double? ft, double? fs,
          double? bt, double? bs, double? rx, double? ry, double? baf, double? open, double? spin}) =>
      KPose.from(_idle,
          lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs, rx: rx, ry: ry,
          baf: baf, open: open, spin: spin);

  @override
  KPose rebase(KPose k) => k;

  @override
  (KPose, KPose, KPose)? readyPoses() => (
        _q(fu: 2.7, ff: 3.0, bu: 2.4, bf: 2.8, lean: .15, rx: -4, baf: 1),
        _q(fu: 1.2, ff: .9, bu: 1.1, bf: .85, lean: .66, rx: 14, baf: 1, ft: 1.0, bt: -.5),
        _q(fu: 1.4, ff: 2.6, bu: 1.2, bf: 2.8, baf: 1, lean: .3),
      );

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    final d = dims;
    final I = _idle;
    switch (m.name) {
      case 'standLight':
        final x = lunge(m, _q(fu: 1.4, ff: 1.0, lean: .52, rx: 10), Jt.fHa, d);
        return MoveAnim(strike(m, I, _q(fu: 2.4, ff: 2.8, lean: .3, rx: -2), x, hold: KPose.from(x, fu: 1.5, ff: 1.15)));
      case 'standLight2':
        final x = lunge(m, _q(bu: 1.4, bf: 2.0, baf: 1, lean: .55, rx: 10), Jt.bHa, d);
        return MoveAnim(strike(m, I, _q(bu: 2.3, bf: 2.7, baf: 1, lean: .3), x, hold: KPose.from(x, bu: 1.5, bf: 2.1)));
      case 'standHeavy':
        final x = lunge(m, _q(fu: 1.2, ff: .85, bu: 1.1, bf: .8, lean: .74, rx: 12, head: .05, ft: 1.0, fs: -.2, bt: -.5, bs: -.9, baf: 1), Jt.fHa, d);
        return MoveAnim(strike(m, I, _q(fu: 2.9, ff: 3.0, bu: 2.8, bf: 2.95, lean: -.06, rx: -4, baf: 1), x,
            hold: KPose.from(x, lean: .8), windAt: .65));
      case 'clawFlurry':
        final ws = m.windows;
        final keys = <Key>[Key(0, I), Key(mx(1, s ~/ 2), _q(lean: .5, fu: 2.2, ff: 2.7, bu: 1.7, bf: 2.1, baf: 1, rx: -2))];
        final gap = ws.length > 1 ? ws[1].start - ws[0].start : 3;
        for (var k = 0; k < ws.length; k++) {
          final last = k == ws.length - 1;
          final front = k.isEven;
          final w = (const [0.0, .25, -.2, .15, -.1, .2, -.15])[k % 7];
          final strikeP = last
              ? _q(fu: 1.1, ff: .8, bu: 1.0, bf: .8, lean: .78, rx: 14, baf: 1, ft: 1.0, bt: -.5)
              : (front
                  ? _q(fu: 1.35, ff: 1.2 + w, bu: 1.6, bf: 2.2, baf: 1, lean: .55, rx: 8)
                  : _q(bu: 1.4, bf: 1.5 - w, fu: 1.6, ff: 2.2, baf: 1, lean: .58, rx: 8));
          keys.add(Key(ws[k].start, strikeP, 1));
          if (!last) keys.add(Key(ws[k].start + mx(1, gap ~/ 2), KPose.from(strikeP, lean: .48, rx: 4)));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rnd(r * .35), _q(lean: .55, fu: 1.1, ff: 1.5, rx: 6)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys));
      case 'pounce':
        final st = m.steps.isNotEmpty ? m.steps.first.frame : 6;
        final coil = _q(lean: .66, ft: 1.2, fs: -.45, bt: .3, bs: -1.05, fu: .5, ff: 1.7, bu: .2, bf: 1.5, rx: -6);
        final lift = _q(lean: .8, ft: .6, fs: .1, bt: -.7, bs: -.3, fu: 2.3, ff: 2.9, bu: 2.1, bf: 2.8, baf: 1);
        final claw = _q(lean: .9, head: -.15, fu: 1.5, ff: 1.45, bu: 1.45, bf: 1.5, baf: 1, ft: 1.3, fs: .7, bt: .6, bs: -.4);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, st - 3), coil),
          Key(st, lift, 1),
          Key(s, claw, 1),
          Key(s + a, KPose.from(claw, lean: 1.0, ft: 1.0, fs: .9)),
          Key(s + a + rnd(r * .45), _q(lean: .62, ft: 1.1, fs: -.4, bt: .3, bs: -.95)),
          Key(t, I),
        ]));
      case 'lowRake':
        final wind = _q(lean: .72, ft: 1.2, fs: -.45, bt: .3, bs: -1.05, fu: -.3, ff: .5, bu: .2, bf: 1.4, rx: -2);
        final x = lunge(m, _q(lean: .9, fu: .95, ff: .45, bu: .5, bf: 0, baf: 1, ft: 1.3, fs: -.5, bt: .35, bs: -1.0, rx: 6), Jt.fHa, d, max: 30);
        return MoveAnim(strike(m, I, wind, x, hold: KPose.from(x, fu: 1.05, ff: .5), rec: _q(lean: .66, ft: 1.1, fs: -.4, bt: .3, bs: -.95), windAt: .6, recAt: .5));
      case 'risingClaw':
        final crouch = _q(lean: .6, ft: 1.1, fs: -.4, bt: .3, bs: -.95, fu: .4, ff: 1.6, bu: .3, bf: 1.4, rx: -2);
        final up = _q(lean: -.12, head: -.25, fu: 2.95, ff: 3.05, bu: .8, bf: 1.5, baf: 1, ft: .4, fs: .15, bt: -.2, bs: -.35, rx: 6);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, s - 2), crouch),
          Key(s, up, 1),
          Key(s + a, KPose.from(up, lean: -.22, fu: 2.7, ff: 2.95, ft: .7, fs: .5)),
          Key(s + a + rnd(r * .45), _q(lean: .35, ft: .9, fs: -.3, bt: -.2, bs: -.7)),
          Key(t, I),
        ]));
      case 'tigerRage':
        final ws = m.windows;
        final roar = _q(lean: -.2, head: -.42, fu: 2.2, ff: 2.9, bu: 2.0, bf: 2.6, baf: 1, ft: .9, fs: -.2, bt: -.5, bs: -.9, rx: -4);
        final keys = <Key>[Key(0, I), Key(mx(1, s ~/ 2), roar), Key(mx(2, s - 1), KPose.from(roar, lean: -.28))];
        final gap = ws.length > 1 ? ws[1].start - ws[0].start : 3;
        for (var k = 0; k < ws.length; k++) {
          final last = k == ws.length - 1;
          final w = (const [0.0, .3, -.2, .15, -.25, .25, -.1, .2, -.15])[k % 9];
          final strikeP = last
              ? _q(fu: 1.05, ff: .8, bu: .95, bf: .78, lean: .8, rx: 16, baf: 1, ft: 1.05, fs: -.2, bt: -.55, head: .1)
              : (k.isEven
                  ? _q(fu: 1.4, ff: 1.2 + w, bu: 1.7, bf: 2.3, baf: 1, lean: .55 + w * .1, rx: 8.0 + k)
                  : _q(bu: 1.4, bf: 1.5 - w, fu: 1.7, ff: 2.3, baf: 1, lean: .58, rx: 8.0 + k));
          keys.add(Key(ws[k].start, strikeP, 1));
          if (!last) keys.add(Key(ws[k].start + mx(1, gap ~/ 2), KPose.from(strikeP, lean: .46)));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rnd(r * .3), _q(lean: .55, fu: 1.1, ff: 1.5, rx: 8)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys));
    }
    return null;
  }

  // -------------------------------------------------------------- effects

  static const Set<String> _clawMoves = {
    'standLight', 'standLight2', 'standHeavy', 'clawFlurry', 'pounce', 'lowRake', 'risingClaw', 'tigerRage',
  };

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final fr = FxFrame(cam, s, player);
    final m = fr.move;
    if (m == null || !_clawMoves.contains(m.name)) return;
    final alt = player == 1 && s.chars[0].id == s.chars[1].id;
    final pal = alt ? RyokoPal.alt : RyokoPal.base;
    final sf = fr.f.sf;
    c.save();
    fr.enter(c);
    final pel = fr.joint(poseFor(s, player), Jt.pel);
    if (m.name == 'tigerRage') {
      if (look == FightLook.painted) {
        final k = sf < m.startup ? sf / m.startup : 1.0;
        drawGlow(c, Offset(pel.dx, pel.dy - 40), 90, withA(pal.glow, .3 * k));
      }
      if (sf < m.startup + 8) {
        c.save();
        c.translate(pel.dx, 0);
        groundRing(c, look, sf / (m.startup + 8), 130, pal.glow);
        c.restore();
      }
    }
    final ws = m.windows;
    for (var k = 0; k < ws.length; k++) {
      final w = ws[k];
      final age = sf - w.start;
      if (age < 0 || age > 7) continue;
      final centre = fr.boxCentre(w);
      final len = math.max(w.box.h, w.box.w * .8) / unitsPerPx / fr.rs * (m.name == 'tigerRage' ? 1.05 : .95);
      double ang;
      switch (m.name) {
        case 'standLight':
          ang = .85;
          break;
        case 'standLight2':
          ang = -.8;
          break;
        case 'standHeavy':
          ang = 1.25;
          break;
        case 'pounce':
          ang = .5;
          break;
        case 'lowRake':
          ang = .12;
          break;
        case 'risingClaw':
          ang = -1.25;
          break;
        default:
          final sign = k.isEven ? 1.0 : -1.0;
          ang = sign * (.7 + hash01(k, 4) * .35);
      }
      final last = k == ws.length - 1 && ws.length > 2;
      c.save();
      c.translate(centre.dx, centre.dy);
      slash3(c, look, last ? 1.3 : ang, len * (last ? 1.25 : 1), age / 7, col: look == FightLook.painted ? pal.furL : const Color(0xFFFFF7E6), glow: pal.glow, gap: last ? 9 : 7);
      if (m.name == 'standHeavy' || last) {
        c.translate(7, 3);
        slash3(c, look, last ? 1.05 : 1.1, len * .85, age / 7, col: const Color(0xFFFFF7E6), glow: pal.glow);
      }
      c.restore();
    }
    c.restore();
  }
}
