// PIP (id 7): a tiny golden lion tamarin. A fluffy golden mane, a long tail,
// an oversized teal scarf. Quick and acrobatic. Pose channel `sa` = 1 puts an
// acorn in her front hand (the nutToss wind-up).
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import 'cast_art.dart';
import 'monkey_kit.dart';

class PipPal {
  final Color fur, furD, furL, belly, face, faceL, scarf, scarfD, scarfL, eye, iris, acorn, acornD, cap;
  const PipPal({
    required this.fur, required this.furD, required this.furL, required this.belly, required this.face,
    required this.faceL, required this.scarf, required this.scarfD, required this.scarfL, required this.eye,
    required this.iris, required this.acorn, required this.acornD, required this.cap,
  });
  static final PipPal base = PipPal(
      fur: hex(0xf59a22), furD: hex(0xc2640f), furL: hex(0xffc84a), belly: hex(0xffd988), face: hex(0x5e4234),
      faceL: hex(0x8d6a52), scarf: hex(0x1fb5a8), scarfD: hex(0x0d7a72), scarfL: hex(0x7cebdf), eye: hex(0xfffaf0),
      iris: hex(0x24150d), acorn: hex(0xc98a3c), acornD: hex(0x8a5a22), cap: hex(0x6a4420));
  /// Mirror match: a ruddier coat with a hot-pink scarf.
  static final PipPal alt = PipPal(
      fur: hex(0xe6641c), furD: hex(0xa83f0c), furL: hex(0xffa648), belly: hex(0xffc98a), face: hex(0x4e362c),
      faceL: hex(0x7d5a48), scarf: hex(0xea3f8f), scarfD: hex(0xa8195c), scarfL: hex(0xff9ccb), eye: hex(0xfffaf0),
      iris: hex(0x24150d), acorn: hex(0xc98a3c), acornD: hex(0x8a5a22), cap: hex(0x6a4420));
}

final KPose pipIdle =
    KPose.from(pIdle, lean: .22, head: -.04, fu: .85, ff: 2.2, bu: .55, bf: 2.5, ft: .8, fs: -.2, bt: -.5, bs: -.62);

final Path _acornCap = pathOf((p) => p
  ..moveTo(-15, 1)
  ..cubicTo(-16, -10, -4, -14, 4, -13)
  ..cubicTo(13, -12, 18, -6, 17.5, 2)
  ..close());
final Path _capHatch = Path.combine(
    PathOperation.intersect,
    _acornCap,
    hatchPath([
      for (var i = -3; i < 5; i++) ...[
        (Offset(i * 5.0 - 6, -14), Offset(i * 5.0 + 6, 4)),
        (Offset(i * 5.0 + 6, -14), Offset(i * 5.0 - 6, 4)),
      ]
    ], 1));
final Path _ppTorso = pathOf((p) => p
  ..moveTo(-9, 0)
  ..cubicTo(-13, -10, -13, -28, -8, -37)
  ..cubicTo(-4, -43, 6, -43, 10, -37)
  ..cubicTo(14, -28, 12, -10, 9, 0));
final Path _ppBelly = pathOf((p) => p
  ..moveTo(4, -36)
  ..cubicTo(10, -30, 10, -12, 7, -1)
  ..cubicTo(1, -6, 0, -26, 4, -36));
final Path _ppFace = pathOf((p) => p
  ..moveTo(2, -9)
  ..cubicTo(9, -12, 17, -9, 19, -2)
  ..cubicTo(21, 5, 18, 12, 11, 14)
  ..cubicTo(4, 16, -1, 11, -2, 5)
  ..cubicTo(-3, -1, -1, -7, 2, -9));
final Path _ppFoot = pathOf((p) => p
  ..moveTo(-5, -6)
  ..cubicTo(-1, -9, 5, -7, 8, -3)
  ..lineTo(18, -1.5)
  ..cubicTo(21, 0, 21, 4, 18, 5)
  ..lineTo(-5, 5)
  ..cubicTo(-8, 3, -8, -3, -5, -6));

/// A scalloped fluffy mane around the face (built once).
final Path _ppMane = () {
  final p = Path();
  const n = 15;
  for (var i = 0; i <= n; i++) {
    final a = i / n * math.pi * 2;
    // Longer at the back and below (a lion's ruff), shorter over the face.
    final r = 21 + 6 * math.max(0, -math.cos(a)) + 4 * math.max(0, math.sin(a)) + (i.isEven ? 3.2 : 0);
    final x = -3 + math.cos(a) * r, y = 1 + math.sin(a) * r * .95;
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      final pa = (i - .5) / n * math.pi * 2;
      final rm = 21 + 6 * math.max(0, -math.cos(pa)) + 4 * math.max(0, math.sin(pa)) - 1.5;
      p.quadraticBezierTo(-3 + math.cos(pa) * rm, 1 + math.sin(pa) * rm * .95, x, y);
    }
  }
  p.close();
  return p;
}();

class PipArt extends CastArt {
  const PipArt();

  @override
  int get id => 7;
  @override
  RigDims get dims => const RigDims(7, 40, 25, 23, 25, 25, 1.04, 7, 4.5, 22, 5);
  @override
  KPose get idle => pipIdle;
  @override
  KPalette get palette => _pal(false);
  @override
  KPalette get altPalette => _pal(true);
  @override
  double get portraitWidth => 105;

  static KPalette _pal(bool alt) {
    final m = alt ? PipPal.alt : PipPal.base;
    return KPalette(
        skin: m.fur, hair: m.furD, tip: m.furL, vest: m.scarf, tank: m.fur, pants: m.fur, pad: m.scarf, wrap: m.scarf,
        shoe: m.furD, sole: m.furD, accent: m.scarf);
  }

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final I = pipIdle;
    return (
      KPose.from(I, fu: 2.8, ff: 3.1, bu: 2.7, bf: 3.1, lean: -.1, rx: -3),
      KPose.from(I, fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.5, lean: .5, rx: 12, baf: 1, ft: 1.2, fs: .3),
      KPose.from(I, fu: .9, ff: 2.3, bu: .8, bf: 2.5, lean: .3, baf: 1),
    );
  }

  // ---------------------------------------------------------------- paint

  @override
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame) {
    final k = Ink.of(rp);
    final m = alt ? PipPal.alt : PipPal.base;
    final c = rp.c;
    final sw = math.sin(frame * .09) * 5;
    // The long tail: a big S that curls over her back, tipped with a tuft.
    final tail = bez(pt(-8, -3), pt(-38, 6), pt(-52, -22 + sw), pt(-36, -52 + sw), 14) +
        bez(pt(-36, -52 + sw), pt(-28, -62 + sw), pt(-18, -56 + sw), pt(-22, -48 + sw), 5).sublist(1);
    k.tube(tail, 4.6, 3.6, m.fur, shade: m.furD, lw: 2);
    rp.fill(ellP(tail.last.dx, tail.last.dy, 4.6, 5.4), m.furL, Rect.fromLTRB(tail.last.dx - 6, tail.last.dy - 7, tail.last.dx + 6, tail.last.dy + 7),
        noHT: true, lw: 1.6);
    // The scarf's tails stream behind the neck.
    _scarfTails(k, j, p, m, frame);
    if (p.baf < .5) _arm(k, j, true, p, m);
    if (p.blf < .5) _leg(k, j, true, p, m);
    c.save();
    c.rotate(p.lean);
    rp.fill(_ppTorso, m.fur, const Rect.fromLTRB(-14, -44, 14, 0), shade: m.furD);
    rp.fill(_ppBelly, m.belly, const Rect.fromLTRB(0, -37, 11, 0), noHT: true, lw: 1.4);
    rp.detail((pa) {
      pa.moveTo(-9, -30);
      pa.lineTo(-6, -26);
      pa.moveTo(-10, -20);
      pa.lineTo(-7, -16);
      pa.moveTo(-8, -10);
      pa.lineTo(-5, -6);
    }, w: 1.1, col: rp.paint ? withA(m.furD, .6) : m.furD);
    c.restore();
    _leg(k, j, false, p, m);
    if (p.blf >= .5) _leg(k, j, true, p, m);
    _head(k, j, p, m, frame);
    if (p.baf >= .5) _arm(k, j, true, p, m);
    _arm(k, j, false, p, m);
    _prop(k, j, p, m);
  }

  void _scarfTails(Ink k, Joints j, KPose p, PipPal m, double frame) {
    final rp = k.r;
    final n = j.neck;
    for (var t = 0; t < 2; t++) {
      final len = t == 0 ? 64.0 : 46.0;
      final ph = frame * .17 + t * 1.9;
      final pts = <Offset>[];
      for (var i = 0; i <= 8; i++) {
        final u = i / 8;
        pts.add(Offset(n.dx - 4 - u * len, n.dy + 4 + t * 3 + u * (t == 0 ? 6 : 14) + math.sin(ph + u * 4.2) * (3 + u * 9)));
      }
      rp.fill(tubePath(pts, 5.2, 7.2), t == 0 ? m.scarf : m.scarfD, bbOf(pts, 9), noHT: true, lw: 1.9, shade: m.scarfD);
      // A pale band near the end.
      final a = pts[6], b = pts[7];
      rp.fill(tubePath([a, b], 6.2, 6.6), m.scarfL, bbOf([a, b], 8), noHT: true, lw: 1.2);
    }
  }

  void _arm(Ink k, Joints j, bool b, KPose p, PipPal m) {
    final rp = k.r;
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final fur = b ? dk(m.fur, .3) : m.fur;
    rp.limb(sh, el, 5.8, 4.6, fur, bulge: 1.2, shade: m.furD);
    rp.limb(el, wr, 4.6, 3.8, fur, bulge: .8, shade: m.furD);
    if (p.open > .5) {
      k.openHand(wr, el, m.fur, s: .75, back: b);
    } else {
      k.fist(wr, el, m.fur, w: 10, h: 8.6, knuckle: m.furL, back: b);
    }
  }

  void _leg(Ink k, Joints j, bool b, KPose p, PipPal m) {
    final rp = k.r;
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    final fur = b ? dk(m.fur, .3) : m.fur;
    rp.limb(hip, kn, 7.4, 5.4, fur, bulge: 1.6, shade: m.furD);
    rp.limb(kn, an, 5.4, 3.8, fur, bulge: .8, shade: m.furD);
    final shin = b ? p.bs : p.fs, off = b ? p.bfa : p.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
    final c = rp.c;
    c.save();
    c.translate(an.dx, an.dy + 4);
    c.rotate(planted ? 0 : -shin + off);
    rp.fill(_ppFoot, b ? dk(m.furD, .2) : m.furD, const Rect.fromLTRB(-8, -9, 22, 5), lw: 1.9);
    c.restore();
  }

  void _head(Ink k, Joints j, KPose p, PipPal m, double frame) {
    final rp = k.r, c = rp.c;
    rp.limb(j.neck, Offset(j.head.dx - 3, j.head.dy + 10), 6, 5.5, m.fur, bulge: .5);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.4, 1.4);
    if (!k.sil) {
      rp.fill(ellP(-8, -16, 4, 5.5, -.3), m.face, const Rect.fromLTRB(-13, -22, -3, -10), lw: 1.5, noHT: true); // ear
    }
    rp.fill(_ppMane, m.furL, const Rect.fromLTRB(-34, -27, 26, 32), shade: m.fur, lw: 2.1);
    if (!k.sil) {
      rp.fill(ellP(-3, 2, 15, 15), m.fur, const Rect.fromLTRB(-18, -13, 12, 17), noHT: true, lw: 1);
      rp.fill(_ppFace, m.face, const Rect.fromLTRB(-3, -12, 22, 16), lw: 1.6, shade: dk(m.face, .4));
      rp.fill(ellP(14, 6.5, 6.4, 5.6), m.faceL, const Rect.fromLTRB(8, 1, 21, 12), noHT: true, lw: 1);
      // Big bright eyes.
      k.dot(7, -1.2, 4.6, m.eye);
      k.dot(8.1, -.8, 3.1, m.iris);
      k.dot(9, -1.9, 1.1, const Color(0xFFFFFFFF));
      k.dot(15, -1.6, 2.9, m.eye);
      k.dot(15.7, -1.3, 2, m.iris);
      k.dot(16.2, -2.1, .75, const Color(0xFFFFFFFF));
      rp.detail((pa) => pa
        ..moveTo(3, -6.4)
        ..quadraticBezierTo(7, -8.6, 11, -6.4), w: 1.1, col: m.furD);
      k.dot(19.2, 4.4, 1.2, const Color(0xFF140C08));
      rp.detail((pa) => pa
        ..moveTo(10.5, 9.4)
        ..quadraticBezierTo(14.5, 12, 18.5, 8.8), w: 1.2, col: const Color(0xFF140C08));
    }
    c.restore();
    // The oversized scarf, wrapped round the neck and knotted at the front.
    final nb = Offset(j.neck.dx - 8, j.neck.dy + 2), nf = Offset(j.neck.dx + 9, j.neck.dy + 3);
    rp.limb(nb, nf, 8.4, 8.4, m.scarf, bulge: 3, shade: m.scarfD, lw: 2.2);
    rp.detail((pa) => pa
      ..moveTo(nb.dx + 3, nb.dy - 6)
      ..quadraticBezierTo((nb.dx + nf.dx) / 2, nb.dy - 1, nf.dx - 2, nf.dy - 7), w: 1.1, col: m.scarfL);
    rp.fill(ellP(nf.dx - 1, nf.dy + 5, 6.4, 5.6), m.scarfD, Rect.fromLTRB(nf.dx - 8, nf.dy, nf.dx + 7, nf.dy + 11), noHT: true, lw: 1.8);
  }

  void _prop(Ink k, Joints j, KPose p, PipPal m) {
    if (p.sa.round() < 1 || k.sil) return;
    k.c.save();
    k.c.translate(j.fHa.dx + 4, j.fHa.dy - 2);
    paintAcorn(k.c, k.r.look, -.4, s: .5, m: m);
    k.c.restore();
  }

  static void paintAcorn(Canvas c, FightLook look, double spin, {double s = 1, PipPal? m}) {
    final pal = m ?? PipPal.base;
    final f = Paint()..isAntiAlias = true;
    c.save();
    c.rotate(spin);
    c.scale(s, s);
    final body = pathOf((p) => p
      ..moveTo(-13, -1)
      ..cubicTo(-13, 9, -6, 14, 2, 14)
      ..cubicTo(10, 14, 16, 8, 16, 0)
      ..lineTo(-13, -1));
    if (look == FightLook.painted) {
      f.shader = Gradient.linear(const Offset(-10, -2), const Offset(14, 14), [hex(0xe8b05c), pal.acorn, pal.acornD], const [0, .5, 1]);
    } else {
      f.color = pal.acorn;
    }
    c.drawPath(body, f);
    f.shader = null;
    final cap = _acornCap;
    c.drawPath(cap, f..color = pal.cap);
    c.drawPath(_capHatch, f..color = withA(const Color(0xFF1F1008), .5));
    c.drawLine(const Offset(2, -13), const Offset(3, -18), Paint()..strokeWidth = 2.6..strokeCap = StrokeCap.round..color = pal.acornD);
    c.drawOval(const Rect.fromLTWH(-6, 3, 7, 4), f..color = const Color(0x55FFFFFF));
    if (look == FightLook.cartoon) {
      final ink = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = kInk;
      c.drawPath(body, ink);
      c.drawPath(cap, ink);
    }
    c.restore();
  }

  @override
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) {
    c.save();
    // Whoosh lines behind the nut.
    final w = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = const Color(0x66FFFFFF);
    if (look != FightLook.pixel) {
      c.drawLine(const Offset(-18, -4), const Offset(-34, -4), w);
      c.drawLine(const Offset(-16, 5), const Offset(-28, 5), w);
    }
    paintAcorn(c, look, age * .5, s: .95);
    c.restore();
    return true;
  }

  // ---------------------------------------------------------------- moves

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = pipIdle;
    final q = posing(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    switch (m.name) {
      case 'standLight':
        final x = lunge(7, m, q(fu: 1.5, ff: 1.57, lean: .4, rx: 8), Jt.fHa);
        return MoveAnim(strike(m, q(fu: .4, ff: 2.4), x, I, hold: KPose.from(x, fu: 1.42)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunge(7, m, q(bu: 1.5, bf: 1.57, baf: 1, lean: .42, rx: 8, fu: .5, ff: 2.4), Jt.bHa);
        return MoveAnim(strike(m, q(bu: .3, bf: 2.5, baf: 1), x, I, hold: KPose.from(x, bu: 1.42)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // A little forward flip with both feet: tail whips round.
        final x = lunge(7, m, q(ft: 1.5, fs: 1.45, bt: 1.2, bs: .8, lean: .5, rx: 10, fu: 1.2, ff: 1.8, bu: 1.0, bf: 2.0), Jt.fAn);
        return MoveAnim(
            strike(m, q(lean: .7, ft: 1.0, fs: -.3, bt: .25, bs: -.9, fu: .4, ff: 2.0, bu: .3, bf: 2.2), x, I, windAt: .6),
            smear: Jt.fAn, smearA: s - 3, smearB: s + a + 2);
      case 'nutToss':
        final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
        final hold = q(fu: .8, ff: 2.3, sa: 1);
        final back = q(fu: 2.4, ff: 3.4, sa: 1, lean: .05, rx: -3);
        final out = q(fu: 1.7, ff: 1.5, sa: 0, lean: .4, rx: 6, open: 1);
        return MoveAnim(mono([
          Key(0, I),
          Key(mx(1, rd(sp * .4)), hold),
          Key(mx(2, sp - 1), back),
          Key(sp, out, 1),
          Key(sp + rd((t - sp) * .45), KPose.from(out, fu: 1.5)),
          Key(mx(t, sp + 3), I),
        ]));
      case 'swingKick':
        // Swings in on a vine, hands up high, then snaps both feet forward.
        final grab = q(fu: 2.8, ff: 3.1, bu: 2.7, bf: 3.1, lean: .3, ft: 1.2, fs: .3, bt: 1.0, bs: -.2, baf: 1, rx: -4);
        final kick = q(fu: 2.9, ff: 3.1, bu: 2.8, bf: 3.1, lean: -.45, ft: 1.55, fs: 1.45, bt: 1.35, bs: 1.3, baf: 1, rx: 6);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), grab),
              Key(s, kick, 1),
              Key(s + a, KPose.from(kick, lean: -.3, ft: 1.2, fs: .9)),
              Key(mx(t, s + a + 1), KPose.from(pipIdle, ft: .6, fs: .1, bt: .1, bs: -.3, lean: .15)),
            ]),
            smear: Jt.fAn, smearA: s - 2, smearB: s + a);
      case 'scamper':
        // A low skitter: nearly horizontal, hands to the ground, legs a blur.
        KPose run(bool ph) => q(
            lean: 1.25, head: -.5, fu: .35, ff: ph ? .25 : .6, bu: .5, bf: ph ? .6 : .2, baf: 1,
            ft: ph ? 1.1 : -.3, fs: ph ? .3 : -.9, bt: ph ? -.4 : .9, bs: ph ? -.8 : .1, rx: 4);
        final keys = <Key>[Key(0, I), Key(mx(1, s - 2), q(lean: .9, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .5, ff: .8))];
        var ph = true;
        for (var f = s; f < s + a + 4; f += 3) {
          keys.add(Key(f, run(ph), 1));
          ph = !ph;
        }
        keys.add(Key(s + a + rd(r * .4), q(lean: .5, ft: .9, fs: -.3, bt: .2, bs: -.8)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fAn, smearA: s - 1, smearB: s + a);
      case 'tailSpin':
        // Rising spin, tail out like a propeller; each hit is one more turn.
        final n = math.max(3, m.windows.length);
        final spun = q(lean: .1, ft: 1.7, fs: 1.2, bt: 1.4, bs: .6, fu: 1.5, ff: 2.0, bu: 1.4, bf: 2.1, tuck: .4);
        final end = m.windows.isEmpty ? s + a : m.windows.last.end;
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 2), q(lean: .35, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .2, ff: 2.0)),
              Key(s, KPose.from(spun, spin: -.3), 1),
              Key(end, KPose.from(spun, spin: -math.pi * 2 * n), 2),
              Key(end + rd(r * .3), KPose.from(q(lean: .2, ft: .6, fs: .1, bt: .1, bs: -.3), spin: -math.pi * 2 * n)),
              Key(mx(t, end + rd(r * .3) + 1), KPose.from(I, spin: -math.pi * 2 * n)),
            ]),
            smear: Jt.fAn, smearA: s - 1, smearB: end);
      case 'blurFlurry':
        // Vanishes in a blur, reappears behind, and kicks off a flurry.
        final pf = q(fu: 1.5, ff: 1.57, lean: .55, rx: 8, ft: .9, bt: -.5, bs: -.5);
        final kb = q(bt: 1.55, bs: 1.5, blf: 1, lean: .1, rx: 6, fu: .8, ff: 2.0, bu: 1.2, bf: 1.9);
        final pb = q(bu: 1.5, bf: 1.57, baf: 1, lean: .55, rx: 8, ft: .9, bt: -.5, bs: -.5);
        final kf = q(ft: 1.55, fs: 1.5, lean: -.1, rx: 6, fu: 1.2, ff: 1.9, bu: .8, bf: 2.0, bt: -.2, bs: -.4);
        final fin = q(ft: 1.6, fs: 1.55, bt: 1.6, bs: 1.55, blf: 1, lean: -.3, rx: 10, fu: 2.5, ff: 2.9, bu: 2.4, bf: 2.9, baf: 1);
        final ws = m.windows;
        final cyc = [pf, kb, pb, kf];
        final keys = <Key>[
          Key(0, I),
          Key(mx(1, 2), q(lean: .3, al: .3, rx: 4), 2),
          Key(mx(2, 4), q(lean: .3, al: 0), 2),
          Key(mx(3, s - 1), q(lean: .4, al: 0), 2),
        ];
        for (var i = 0; i < ws.length; i++) {
          keys.add(Key(ws[i].start, i == ws.length - 1 ? fin : cyc[i % 4], 1));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rd(r * .35), q(lean: .2, ft: .6, fs: .1, bt: .1, bs: -.3, fu: 1.0, ff: 2.0)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fAn, smearA: s, smearB: tail);
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
    final ln = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (m.name) {
      case 'swingKick':
        // A vine drops from above to her hands.
        if (sf >= 1 && sf < m.startup + m.active) {
          final hands = Offset(foot.dx + f.face * 6 * u, foot.dy - 78 * u);
          final top = Offset(hands.dx - f.face * 10 * u, hands.dy - 330 * cam.scale);
          final vine = Path()
            ..moveTo(top.dx, top.dy)
            ..cubicTo(top.dx + f.face * 18 * u, top.dy + 120 * u, hands.dx - f.face * 14 * u, hands.dy - 120 * u, hands.dx, hands.dy);
          final a = sf < m.startup ? 1.0 : 1 - (sf - m.startup) / (m.active + 1) * .7;
          c.drawPath(vine, ln..strokeWidth = 4.5 * u..color = Color.fromRGBO(44, 110, 52, a));
          if (look == FightLook.cartoon) c.drawPath(vine, ln..strokeWidth = 1.5 * u..color = Color.fromRGBO(120, 200, 110, a));
        }
        break;
      case 'tailSpin':
        if (sf >= m.startup && sf < m.startup + m.active + 4) {
          final o = Offset(foot.dx, foot.dy - 66 * u);
          final k = (sf - m.startup) / (m.active + 4);
          for (var i = 0; i < 2; i++) {
            c.drawArc(Rect.fromCenter(center: o, width: (110 + i * 22) * u, height: (60 + i * 12) * u), sf * .5 + i * 2.2, 2.4, false,
                ln..strokeWidth = (4 - i) * u..color = Color.fromRGBO(255, 230, 150, .85 * (1 - k)));
          }
        }
        break;
      case 'scamper':
        if (sf >= m.startup && sf < m.startup + m.active + 6) {
          for (var i = 0; i < 3; i++) {
            final y = foot.dy - (8 + i * 9) * u;
            c.drawLine(Offset(foot.dx - f.face * 26 * u, y), Offset(foot.dx - f.face * (26 + 30 + hash01(i, sf ~/ 2) * 30) * u, y),
                ln..strokeWidth = 3 * u..color = Color.fromRGBO(255, 255, 255, .55 - i * .12));
          }
        }
        break;
      case 'blurFlurry':
        // Speed streaks while she is gone and during the flurry.
        if (sf < m.startup + m.active) {
          final vanished = sf < m.startup;
          for (var i = 0; i < 5; i++) {
            final y = foot.dy - (20 + hash01(i, sf ~/ 2) * 70) * u;
            final x = foot.dx + f.face * (vanished ? -30 : 10 + hash01(i, 4) * 40) * u;
            c.drawLine(Offset(x, y), Offset(x - f.face * (30 + hash01(i, 9) * 40) * u, y),
                ln..strokeWidth = (2.4 + hash01(i, 2) * 2) * u..color = Color.fromRGBO(124, 235, 223, vanished ? .8 : .55));
          }
        }
        break;
    }
  }
}
