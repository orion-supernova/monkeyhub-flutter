// The roster painters: MOJO (capuchin trickster), TANK (rhino grappler) and
// NYX (shadow spirit), ported from docs/fighting-game/roster-lab.html. They
// share RigPainter's three looks (fill / detail / limb) and the KPose skeleton,
// with per-character bone lengths from RigDims.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'art_common.dart';
import 'glow.dart';
import 'kai_rig.dart';

// ------------------------------------------------------------------ palettes

class MojoPal {
  final Color fur, furD, face, cap, jacket, stripe, shorts, band, bamboo, node, tape, eye, iris, teeth, tapeW;
  const MojoPal({
    required this.fur, required this.furD, required this.face, required this.cap, required this.jacket,
    required this.stripe, required this.shorts, required this.band, required this.bamboo, required this.node,
    required this.tape, required this.eye, required this.iris, required this.teeth, required this.tapeW,
  });
  static final MojoPal base = MojoPal(
    fur: hex(0x5b3a27), furD: hex(0x3a2418), face: hex(0xf1d2ab), cap: hex(0x241610), jacket: hex(0xffc93a),
    stripe: hex(0x1d1726), shorts: hex(0x3c6e93), band: hex(0xe8423a), bamboo: hex(0xd8b45e), node: hex(0x9c7a32),
    tape: hex(0xff7a3a), eye: hex(0xfffaf0), iris: hex(0x2a1a10), teeth: hex(0xfffaf0), tapeW: hex(0xefe6d8));
  /// Player 2 / mirror match: teal jacket, plum shorts, white headband.
  static final MojoPal alt = MojoPal(
    fur: hex(0x5b3a27), furD: hex(0x3a2418), face: hex(0xf1d2ab), cap: hex(0x241610), jacket: hex(0x1fb5a8),
    stripe: hex(0x0c3d3a), shorts: hex(0x7a3c93), band: hex(0xf6f1e6), bamboo: hex(0xd8b45e), node: hex(0x9c7a32),
    tape: hex(0xff4f9a), eye: hex(0xfffaf0), iris: hex(0x2a1a10), teeth: hex(0xfffaf0), tapeW: hex(0xefe6d8));
}

class TankPal {
  final Color hide, hideD, hideL, horn, hornD, singlet, trim, belt, beltD, gem, boot, tape, eye, iris;
  const TankPal({
    required this.hide, required this.hideD, required this.hideL, required this.horn, required this.hornD,
    required this.singlet, required this.trim, required this.belt, required this.beltD, required this.gem,
    required this.boot, required this.tape, required this.eye, required this.iris,
  });
  static final TankPal base = TankPal(
    hide: hex(0x8a909b), hideD: hex(0x5c616c), hideL: hex(0xb6bbc4), horn: hex(0xefe3c8), hornD: hex(0xbfae88),
    singlet: hex(0x7d1f30), trim: hex(0xffc93a), belt: hex(0xf2c14e), beltD: hex(0xb8862c), gem: hex(0xe8423a),
    boot: hex(0x2b2633), tape: hex(0xf0ece4), eye: hex(0xfffaf0), iris: hex(0x1d1210));
  /// Player 2 / mirror match: navy singlet, silver trim and belt.
  static final TankPal alt = TankPal(
    hide: hex(0x8a909b), hideD: hex(0x5c616c), hideL: hex(0xb6bbc4), horn: hex(0xefe3c8), hornD: hex(0xbfae88),
    singlet: hex(0x1f2f6b), trim: hex(0xd5d9e2), belt: hex(0xcfd3dc), beltD: hex(0x7b8190), gem: hex(0x3fd2c7),
    boot: hex(0x2b2633), tape: hex(0xf0ece4), eye: hex(0xfffaf0), iris: hex(0x1d1210));
}

class NyxPal {
  final Color cloak, cloakD, cloakL, voidC, mask, maskD, glow, violet, hand, hair, hairHi, capeShade;
  const NyxPal({
    required this.cloak, required this.cloakD, required this.cloakL, required this.voidC, required this.mask,
    required this.maskD, required this.glow, required this.violet, required this.hand, required this.hair,
    required this.hairHi, required this.capeShade,
  });
  static final NyxPal base = NyxPal(
    cloak: hex(0x2b2056), cloakD: hex(0x160f33), cloakL: hex(0x4b3c8e), voidC: hex(0x0a0618), mask: hex(0xece8ff),
    maskD: hex(0xb8b0e6), glow: hex(0x9ff3ff), violet: hex(0xc48bff), hand: hex(0xd9d2ff), hair: hex(0x4a2f9a),
    hairHi: hex(0xa58cf5), capeShade: hex(0x0b0720));
  /// Player 2 / mirror match: crimson cloak with a gold glow.
  static final NyxPal alt = NyxPal(
    cloak: hex(0x5a1426), cloakD: hex(0x2e0a14), cloakL: hex(0x8a2a40), voidC: hex(0x1a0408), mask: hex(0xf3ece6),
    maskD: hex(0xcdb8aa), glow: hex(0xffd77a), violet: hex(0xffb347), hand: hex(0xf0dcd2), hair: hex(0x7a2030),
    hairHi: hex(0xff8a7a), capeShade: hex(0x1a0408));
}

// ------------------------------------------------------------------ helpers

Path pathOf(void Function(Path p) f) {
  final p = Path();
  f(p);
  p.close();
  return p;
}

Path ellP(double x, double y, double rx, double ry, [double rot = 0]) {
  final p = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2));
  final cs = math.cos(rot), sn = math.sin(rot);
  return p.transform(Float64List.fromList([cs, sn, 0, 0, -sn, cs, 0, 0, 0, 0, 1, 0, x, y, 0, 1]));
}

/// A tapered tube along a polyline: width w0 at the start, w1 at the end.
Path tubePath(List<Offset> pts, double w0, double w1) {
  final l = <Offset>[], rr = <Offset>[];
  final n = pts.length;
  for (var i = 0; i < n; i++) {
    final a = pts[math.max(0, i - 1)], b = pts[math.min(n - 1, i + 1)];
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    var ln = math.sqrt(dx * dx + dy * dy);
    if (ln == 0) ln = 1;
    final w = lerpD(w0, w1, i / (n - 1));
    l.add(Offset(pts[i].dx - dy / ln * w, pts[i].dy + dx / ln * w));
    rr.add(Offset(pts[i].dx + dy / ln * w, pts[i].dy - dx / ln * w));
  }
  final p = Path()..moveTo(l[0].dx, l[0].dy);
  for (var i = 1; i < n; i++) {
    p.lineTo(l[i].dx, l[i].dy);
  }
  for (var i = n - 1; i >= 0; i--) {
    p.lineTo(rr[i].dx, rr[i].dy);
  }
  p.close();
  return p;
}

List<Offset> bez(Offset p0, Offset p1, Offset p2, Offset p3, int n) {
  final o = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n, u = 1 - t;
    o.add(Offset(u * u * u * p0.dx + 3 * u * u * t * p1.dx + 3 * u * t * t * p2.dx + t * t * t * p3.dx,
        u * u * u * p0.dy + 3 * u * u * t * p1.dy + 3 * u * t * t * p2.dy + t * t * t * p3.dy));
  }
  return o;
}

Rect bbOf(List<Offset> pts, [double pad = 4]) {
  var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (final p in pts) {
    x0 = math.min(x0, p.dx);
    y0 = math.min(y0, p.dy);
    x1 = math.max(x1, p.dx);
    y1 = math.max(y1, p.dy);
  }
  return Rect.fromLTRB(x0 - pad, y0 - pad, x1 + pad, y1 + pad);
}

Offset _o(double x, double y) => Offset(x, y);

// ------------------------------------------------------------------ static paths

final Path _mjHead = pathOf((p) => p
  ..moveTo(-2, -17)
  ..cubicTo(-13, -17, -18, -8, -17, 2)
  ..cubicTo(-16, 10, -9, 16, -1, 17)
  ..cubicTo(6, 18, 12, 15, 14, 10)
  ..cubicTo(17, 6, 17.5, 0, 16, -4)
  ..cubicTo(15, -11, 10, -17, -2, -17));
final Path _mjFace = pathOf((p) => p
  ..moveTo(1, -10)
  ..cubicTo(8, -13, 14, -11, 15.5, -6)
  ..cubicTo(18.5, -1, 18.5, 6, 15, 10.5)
  ..cubicTo(12, 15, 5, 17, -1, 15)
  ..cubicTo(-4, 12, -5, 4, -4, -2)
  ..cubicTo(-3, -6, -2, -8.5, 1, -10));
final Path _mjCap = pathOf((p) => p
  ..moveTo(-22, -30)
  ..lineTo(22, -30)
  ..lineTo(22, -10)
  ..quadraticBezierTo(6, -14, -6, -7)
  ..quadraticBezierTo(-14, -3, -22, -2));
final Path _mjTuft = pathOf((p) => p
  ..moveTo(-6, -15)
  ..cubicTo(-10, -24, -8, -33, -1, -36)
  ..cubicTo(-3, -30, 2, -28, 6, -31)
  ..cubicTo(5, -25, 3, -19, 2, -15));
final Path _mjTorso = pathOf((p) => p
  ..moveTo(-11, 0)
  ..cubicTo(-16, -12, -17, -28, -14, -38)
  ..cubicTo(-11, -46, -3, -48, 3, -47)
  ..cubicTo(10, -46, 15, -40, 15, -31)
  ..cubicTo(15, -20, 13, -9, 10, 0));
final Path _mjBelly = pathOf((p) => p
  ..moveTo(1, -34)
  ..cubicTo(9, -34, 13, -24, 12, -14)
  ..cubicTo(11, -6, 8, -1, 3, 0)
  ..cubicTo(-2, -6, -3, -24, 1, -34));
final Path _mjJacket = pathOf((p) => p
  ..moveTo(-15, -24)
  ..cubicTo(-17, -32, -15, -42, -9, -46)
  ..cubicTo(-3, -49, 6, -49, 12, -45)
  ..cubicTo(15, -42, 16, -37, 15, -33)
  ..cubicTo(10, -34, 6, -30, 4, -24));
final Path _mjFoot = pathOf((p) => p
  ..moveTo(-6, -6)
  ..cubicTo(-2, -9, 6, -7, 10, -3)
  ..lineTo(20, -1)
  ..cubicTo(23, 0, 23, 4, 20, 5)
  ..lineTo(-6, 5)
  ..cubicTo(-9, 4, -9, -3, -6, -6));
final Path mojoPeelPath = pathOf((p) => p
  ..moveTo(0, -9)
  ..cubicTo(4, -8, 5, -3, 3, 0)
  ..cubicTo(9, -2, 13, 1, 13, 4)
  ..cubicTo(8, 4, 4, 4, 2, 3)
  ..lineTo(-2, 3)
  ..cubicTo(-4, 4, -8, 4, -13, 4)
  ..cubicTo(-13, 1, -9, -2, -3, 0)
  ..cubicTo(-5, -3, -4, -8, 0, -9));
final Path _mjBandana = pathOf((q) => q
  ..moveTo(-9, -46)
  ..quadraticBezierTo(2, -41, 13, -46)
  ..lineTo(8, -37)
  ..lineTo(2, -33)
  ..lineTo(-4, -38));
final Path _mjGrin = pathOf((q) => q
  ..moveTo(7, 8.5)
  ..quadraticBezierTo(12, 13.5, 17, 7.5)
  ..quadraticBezierTo(12, 10, 7, 8.5));

final Path _tkTorso = pathOf((p) => p
  ..moveTo(-18, 0)
  ..cubicTo(-27, -16, -30, -40, -25, -56)
  ..cubicTo(-19, -69, 6, -72, 19, -63)
  ..cubicTo(29, -52, 29, -26, 21, -6)
  ..lineTo(19, 0));
final Path _tkSinglet = pathOf((p) => p
  ..moveTo(-21, -2)
  ..cubicTo(-26, -14, -27, -30, -24, -40)
  ..lineTo(-14, -40)
  ..lineTo(-10, -64)
  ..lineTo(-4, -64)
  ..lineTo(-2, -40)
  ..lineTo(8, -40)
  ..lineTo(12, -62)
  ..lineTo(18, -60)
  ..lineTo(18, -40)
  ..cubicTo(26, -32, 26, -18, 21, -4));
final Path _tkHead = pathOf((p) => p
  ..moveTo(-15, -11)
  ..cubicTo(-11, -20, 2, -22, 12, -16)
  ..cubicTo(20, -12, 26, -6, 30, 0)
  ..cubicTo(33, 4, 31, 10, 24, 11.5)
  ..cubicTo(14, 13.5, 0, 14.5, -8, 10.5)
  ..cubicTo(-15, 6, -18, -3, -15, -11));
final Path _tkHorn = pathOf((p) => p
  ..moveTo(20, -6)
  ..quadraticBezierTo(29, -22, 37, -31)
  ..quadraticBezierTo(33, -13, 30, -1));
final Path _tkHorn2 = pathOf((p) => p
  ..moveTo(10, -15)
  ..quadraticBezierTo(15, -24, 19, -28)
  ..quadraticBezierTo(18, -19, 17, -13));
final Path _tkEar = pathOf((p) => p
  ..moveTo(-10, -14)
  ..quadraticBezierTo(-17, -28, -9, -31)
  ..quadraticBezierTo(-4, -22, -5, -15));
final Path _tkBoot = pathOf((p) => p
  ..moveTo(-9, -15)
  ..lineTo(7, -15)
  ..cubicTo(9, -8, 14, -5, 20, -3)
  ..cubicTo(24, -1, 24, 6, 19, 7)
  ..lineTo(-10, 7)
  ..cubicTo(-12, 0, -11, -8, -9, -15));

final Path _nxHood = pathOf((p) => p
  ..moveTo(-4, -23)
  ..cubicTo(10, -25, 19, -15, 18, -2)
  ..cubicTo(18, 8, 13, 17, 4, 19)
  ..cubicTo(-6, 21, -14, 15, -16, 5)
  ..cubicTo(-19, -5, -25, -14, -36, -19)
  ..cubicTo(-25, -23, -14, -24, -4, -23));
final Path _nxOpen = pathOf((p) => p
  ..moveTo(4, -17)
  ..cubicTo(13, -17, 16, -6, 15, 3)
  ..cubicTo(14, 11, 9, 15, 3, 15)
  ..cubicTo(-1, 9, -1, -10, 4, -17));
final Path _nxMask = pathOf((p) => p
  ..moveTo(5, -15)
  ..cubicTo(14, -14, 17, -4, 15, 6)
  ..cubicTo(13, 12, 8, 15, 3, 13)
  ..cubicTo(9, 7, 10, -6, 5, -15));
final Path _nxTorso = pathOf((p) => p
  ..moveTo(-10, 0)
  ..cubicTo(-13, -10, -12, -24, -15, -38)
  ..cubicTo(-16, -50, -9, -60, -1, -60)
  ..cubicTo(8, -60, 14, -54, 15, -44)
  ..cubicTo(16, -34, 9, -24, 8, -14)
  ..cubicTo(8, -8, 10, -4, 11, 0));
final Path _nxPanel = pathOf((q) => q
  ..moveTo(-1, -56)
  ..lineTo(9, -56)
  ..cubicTo(8, -40, 4, -24, 6, -6)
  ..lineTo(2, -6)
  ..cubicTo(0, -24, 1, -40, -1, -56));
/// NYX's crescent (also her shard): r = outer radius.
Path nyxMoonPath(double r) {
  final p = Path();
  p.arcTo(Rect.fromCircle(center: Offset.zero, radius: r), -1.2, 1.2 + math.pi + 1.2, true);
  p.arcTo(Rect.fromCircle(center: Offset(r * .45, 0), radius: r * .78), 1.9 + math.pi, -2 * math.pi, false);
  p.close();
  return p;
}

/// The shard crescent used by the projectile.
Path shardPath(double r) {
  final p = Path();
  p.arcTo(Rect.fromCircle(center: Offset.zero, radius: r), -1.25, 1.25 + math.pi + 1.25, true);
  p.arcTo(Rect.fromCircle(center: Offset(r * .42, 0), radius: r * .8), 1.95 + math.pi, -2 * math.pi, false);
  p.close();
  return p;
}

// ------------------------------------------------------------------ painter

class RosterPainter {
  RosterPainter(this.r);
  final RigPainter r;

  Canvas get c => r.c;
  bool get cel => r.cel;
  bool get paint => r.paint;
  bool get pix => r.pix;
  bool get sil => r.sil != null;

  final Paint _f = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _layer = Paint();

  late double _f60;

  void _fillC(Path p, Color col) => c.drawPath(p, _f..shader = null..color = col);
  void _circ(double x, double y, double rad, Color col) => c.drawCircle(Offset(x, y), rad, _f..shader = null..color = col);
  void _ink(Path p, double w, [Color col = kInk]) => c.drawPath(p, _s..shader = null..strokeWidth = w..color = col);

  void fighter(KPose p, int id, bool alt, int frame) {
    _f60 = frame.toDouble();
    final d = dimsFor(id);
    final j = fk(p, d);
    if (p.al <= .02) return;
    final layer = p.al < 1;
    if (layer) c.saveLayer(null, _layer..color = Color.fromRGBO(0, 0, 0, p.al.clamp(0.0, 1.0)));
    c.save();
    c.translate(p.rx, pelvisY(p, j));
    if (p.spin != 0) {
      c.translate(j.c.dx, j.c.dy);
      c.rotate(p.spin);
      c.translate(-j.c.dx, -j.c.dy);
    }
    switch (id) {
      case 1:
        _mojo(j, p, alt ? MojoPal.alt : MojoPal.base);
        break;
      case 2:
        _tank(j, p, alt ? TankPal.alt : TankPal.base);
        break;
      default:
        _nyx(j, p, alt ? NyxPal.alt : NyxPal.base);
    }
    c.restore();
    if (layer) c.restore();
  }

  // ================================================================ MOJO

  void _mojoStaff(Joints j, KPose p, MojoPal m) {
    final a = j.sEnd, b = j.sTip;
    r.fill(limbPath(a, b, 3.6, 3.6), m.bamboo,
        Rect.fromLTRB(math.min(a.dx, b.dx) - 4, math.min(a.dy, b.dy) - 4, math.max(a.dx, b.dx) + 4, math.max(a.dy, b.dy) + 4),
        shade: dk(m.bamboo, .35), lw: 2.2, noHT: true);
    if (sil) return;
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    for (final t in const [.18, .42, .66]) {
      final q = lerpO(a, b, t);
      r.fill(ellP(q.dx, q.dy, 1.6, 4.1, ang), m.node, Rect.fromLTRB(q.dx - 4, q.dy - 4, q.dx + 4, q.dy + 4), lw: 1, noHT: true);
    }
    for (final t in const [[0.0, .08], [.92, 1.0]]) {
      r.fill(limbPath(lerpO(a, b, t[0]), lerpO(a, b, t[1]), 4.1, 4.1), m.tape,
          Rect.fromLTRB(a.dx - 6, a.dy - 6, b.dx + 6, b.dy + 6), lw: 1.8, noHT: true);
    }
  }

  void _mojo(Joints j, KPose p, MojoPal m) {
    final f = _f60;
    // Tail: a long S that curls at the tip and sways while she waits.
    final sw = math.sin(f * .06) * 5;
    final tail = bez(_o(-9, -6), _o(-36, 2), _o(-50, -34 + sw), _o(-30, -56 + sw), 14) +
        bez(_o(-30, -56 + sw), _o(-20, -64 + sw), _o(-14, -52 + sw), _o(-20, -46 + sw), 5).sublist(1);
    r.fill(tubePath(tail, 4.4, 2.6), m.furD, bbOf(tail, 6), lw: 2.2);
    if (p.baf < .5) _mojoArm(j, true, p, m);
    if (p.blf < .5) _mojoLeg(j, true, p, m);
    r.fill(rrPath(-13, -6, 26, 19, 8), m.shorts, const Rect.fromLTRB(-13, -6, 13, 13));
    c.save();
    c.rotate(p.lean);
    r.fill(_mjTorso, m.fur, const Rect.fromLTRB(-17, -48, 15, 0), shade: m.furD);
    r.fill(_mjBelly, m.face, const Rect.fromLTRB(-3, -34, 13, 0), noHT: true, lw: 1.6);
    r.fill(_mjJacket, m.jacket, const Rect.fromLTRB(-17, -49, 16, -24), lw: 2.2);
    r.detail((pa) => pa
      ..moveTo(-12, -40)
      ..quadraticBezierTo(-9, -33, -11, -26), w: 2.2, col: paint ? withA(m.stripe, .7) : m.stripe);
    // Red bandana at the neck, knot and tails behind.
    r.fill(_mjBandana, m.band, const Rect.fromLTRB(-9, -46, 13, -33), lw: 1.8, noHT: true);
    final s1 = math.sin(f * .2) * 2, s2 = math.sin(f * .2 + 1) * 2;
    r.fill(
        pathOf((q) => q
          ..moveTo(-8, -45)
          ..lineTo(-18, -40 + s1)
          ..lineTo(-16, -36 + s2)
          ..lineTo(-7, -42)),
        m.band,
        const Rect.fromLTRB(-18, -46, -6, -36),
        lw: 1.6,
        noHT: true);
    r.fill(rrPath(-12, -4, 24, 5, 2), m.band, const Rect.fromLTRB(-12, -4, 12, 1), noHT: true, lw: 1.6);
    c.restore();
    _mojoLeg(j, false, p, m);
    if (p.blf >= .5) _mojoLeg(j, true, p, m);
    _mojoHead(j, p, m);
    if (p.baf >= .5) _mojoArm(j, true, p, m);
    _mojoStaff(j, p, m);
    _mojoArm(j, false, p, m);
  }

  void _furFist(Offset wr, Offset el, Color col, Color fingers, bool back) {
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    r.fill(rrPath(-2, -6.5, 14, 13, 5.5), back ? dk(fingers, .3) : fingers, const Rect.fromLTRB(-2, -6, 12, 6), lw: 2);
    r.fill(rrPath(-3, -6.5, 6, 13, 2.5), back ? dk(col, .3) : col, const Rect.fromLTRB(-3, -6, 3, 6), lw: 1.8, noHT: true);
    r.detail((pa) => pa
      ..moveTo(7, -5)
      ..lineTo(7, 5), w: 1);
    c.restore();
  }

  void _mojoArm(Joints j, bool b, KPose p, MojoPal m) {
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final fur = b ? dk(m.fur, .3) : m.fur;
    r.limb(sh, el, 7.6, 5.6, b ? dk(m.jacket, .3) : m.jacket, bulge: 1.8);
    r.detail((pa) {
      final q = lerpO(sh, el, .15), rr2 = lerpO(sh, el, .9);
      pa.moveTo(q.dx, q.dy);
      pa.lineTo(rr2.dx, rr2.dy);
    }, w: 1.6, col: paint ? withA(m.stripe, .6) : m.stripe);
    r.limb(el, wr, 5.6, 4.6, fur, bulge: 1.4);
    r.limb(lerpO(el, wr, .7), wr, 5.2, 4.9, b ? dk(m.tapeW, .3) : m.tapeW, noHT: true, lw: 1.8);
    _furFist(wr, el, fur, b ? dk(m.face, .25) : m.face, b);
  }

  void _mojoLeg(Joints j, bool b, KPose p, MojoPal m) {
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    r.limb(hip, lerpO(hip, kn, .8), 9.5, 8.4, b ? dk(m.shorts, .3) : m.shorts, bulge: 2);
    r.limb(lerpO(hip, kn, .7), an, 6, 4.6, b ? dk(m.fur, .3) : m.fur, bulge: 1.2);
    r.limb(lerpO(kn, an, .75), an, 5, 4.8, b ? dk(m.tapeW, .3) : m.tapeW, noHT: true, lw: 1.8);
    final shin = b ? p.bs : p.fs, off = b ? p.bfa : p.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
    c.save();
    c.translate(an.dx, an.dy + 3);
    c.rotate(planted ? 0 : -shin + off);
    r.fill(_mjFoot, b ? dk(m.fur, .3) : m.furD, const Rect.fromLTRB(-9, -9, 23, 5), lw: 2);
    r.detail((pa) => pa
      ..moveTo(13, -1)
      ..lineTo(13, 4)
      ..moveTo(17, -.5)
      ..lineTo(17, 4.5), w: 1);
    c.restore();
  }

  void _mojoHead(Joints j, KPose p, MojoPal m) {
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.28, 1.28);
    r.fill(ellP(-9, 1, 5.2, 6.2), m.fur, const Rect.fromLTRB(-15, -6, -3, 8), lw: 1.8);
    if (!sil) r.fill(ellP(-8.6, 1.4, 2.8, 3.6), m.face, const Rect.fromLTRB(-12, -3, -5, 5), noHT: true, lw: 1);
    r.fill(_mjTuft, m.cap, const Rect.fromLTRB(-10, -36, 7, -14), noHT: true, lw: 2);
    r.fill(_mjHead, m.fur, const Rect.fromLTRB(-18, -18, 17, 18), shade: m.furD);
    if (!sil) {
      r.inside(_mjHead, _mjCap, paint ? const Color(0xE11E120C) : m.cap);
      r.fill(_mjFace, m.face, const Rect.fromLTRB(-5, -13, 19, 17), lw: 1.8);
      r.fill(rrPath(-5, -20.5, 10, 4.5, 2), m.band, const Rect.fromLTRB(-5, -21, 5, -16), noHT: true, lw: 1.6);
      // Two eyes in 3/4 view: big near one, small far one. Lashes flick up.
      r.fill(ellP(7.5, -3.6, 4.2, 4.9), m.eye, const Rect.fromLTRB(3, -9, 12, 2), noHT: true, lw: 1.4);
      r.fill(ellP(15.2, -4.2, 2.2, 3.6), m.eye, const Rect.fromLTRB(13, -8, 18, 0), noHT: true, lw: 1.2);
      _circ(9.2, -3.2, 2.6, m.iris);
      _circ(15.8, -3.8, 1.5, m.iris);
      _circ(10, -4.4, .9, const Color(0xFFFFFFFF));
      r.detail((pa) => pa
        ..moveTo(3.4, -6.6)
        ..lineTo(1.6, -8.8)
        ..moveTo(4.6, -8)
        ..lineTo(3.4, -10.4), w: 1.2);
      r.detail((pa) => pa
        ..moveTo(3.8, -11.2)
        ..quadraticBezierTo(8, -13.6, 12.4, -10.8), w: 2.2, col: const Color(0xFF241610));
      _circ(16.6, 3.2, .9, m.cap);
      _circ(14.8, 3.6, .8, m.cap);
      r.fill(_mjGrin, m.teeth, const Rect.fromLTRB(7, 7, 17, 13), noHT: true, lw: 1.4);
    }
    c.restore();
  }

  // ================================================================ TANK

  void _tank(Joints j, KPose p, TankPal t) {
    if (p.baf < .5) _tankArm(j, true, p, t);
    if (p.blf < .5) _tankLeg(j, true, p, t);
    r.fill(rrPath(-21, -8, 42, 24, 10), t.singlet, const Rect.fromLTRB(-21, -8, 21, 16));
    c.save();
    c.rotate(p.lean);
    r.fill(_tkTorso, t.hide, const Rect.fromLTRB(-30, -72, 29, 0), shade: t.hideD);
    r.detail((pa) {
      for (final y in const [-30.0, -22.0, -14.0]) {
        pa.moveTo(4, y);
        pa.quadraticBezierTo(12, y + 2, 19, y - 1);
      }
    }, w: 1.3, col: paint ? const Color(0x59282832) : t.hideD);
    r.fill(_tkSinglet, t.singlet, const Rect.fromLTRB(-27, -64, 26, 0), lw: 2.3);
    r.detail((pa) => pa
      ..moveTo(-24, -39)
      ..lineTo(18, -39), w: 2.2, col: t.trim);
    // The championship belt.
    r.fill(rrPath(-24, -9, 49, 10, 3), const Color(0xFF3A2A1E), const Rect.fromLTRB(-24, -9, 25, 1), noHT: true, lw: 2);
    r.fill(ellP(8, -4, 11, 8.5), t.belt, const Rect.fromLTRB(-3, -13, 19, 5), noHT: true, lw: 2, shade: t.beltD);
    if (!sil) {
      r.fill(ellP(8, -4, 3.4, 3), t.gem, const Rect.fromLTRB(4, -7, 12, -1), noHT: true, lw: 1.2);
      r.detail((pa) => pa.addOval(Rect.fromCenter(center: const Offset(8, -4), width: 15, height: 11.2)), w: 1, col: const Color(0xFF8A5A14));
    }
    c.restore();
    _tankLeg(j, false, p, t);
    if (p.blf >= .5) _tankLeg(j, true, p, t);
    _tankHead(j, p, t);
    if (p.baf >= .5) _tankArm(j, true, p, t);
    _tankArm(j, false, p, t);
  }

  void _tankArm(Joints j, bool b, KPose p, TankPal t) {
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final h = b ? dk(t.hide, .3) : t.hide;
    r.limb(sh, el, 14, 11, h, bulge: 4);
    r.fill(ellP(sh.dx, sh.dy - 1, 12.5, 10.5, -.3), b ? dk(t.hideD, .2) : t.hideD,
        Rect.fromLTRB(sh.dx - 13, sh.dy - 12, sh.dx + 13, sh.dy + 10), lw: 2.2); // shoulder plate
    r.limb(el, wr, 11, 9.5, h, bulge: 3);
    r.limb(lerpO(el, wr, .62), wr, 10, 9.6, b ? dk(t.tape, .3) : t.tape, noHT: true, lw: 1.8);
    if (p.open > .5) {
      // The lab reuses KAI's open hand; here it takes the rhino's own hide and tape.
      final keep = r.pal;
      r.pal = _tankHandPal(t);
      r.openHand(wr, el, b);
      r.pal = keep;
      return;
    }
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    r.fill(rrPath(-3, -10, 20, 20, 8), h, const Rect.fromLTRB(-3, -10, 17, 10), lw: 2.4);
    r.detail((pa) => pa
      ..moveTo(11, -8)
      ..lineTo(11, 8)
      ..moveTo(5, -9)
      ..lineTo(5, -3), w: 1.2);
    c.restore();
  }

  KPalette? _handPalCache;
  TankPal? _handPalFor;
  KPalette _tankHandPal(TankPal t) {
    if (_handPalFor == t && _handPalCache != null) return _handPalCache!;
    _handPalFor = t;
    return _handPalCache = KPalette(
        skin: t.hide, hair: t.hideD, tip: t.hideD, vest: t.singlet, tank: t.hideD, pants: t.hideD, pad: t.hideD,
        wrap: t.tape, shoe: t.boot, sole: t.boot, accent: t.trim);
  }

  void _tankLeg(Joints j, bool b, KPose p, TankPal t) {
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    r.limb(hip, kn, 14.5, 12, b ? dk(t.hide, .3) : t.hide, bulge: 3);
    r.limb(hip, lerpO(hip, kn, .4), 14.8, 13.6, b ? dk(t.singlet, .3) : t.singlet, noHT: true, lw: 2);
    r.limb(kn, an, 12, 10, b ? dk(t.hide, .3) : t.hide, bulge: 2.6);
    r.limb(lerpO(kn, an, -.06), lerpO(kn, an, .22), 11.4, 10.8, b ? dk(t.boot, .2) : t.boot, noHT: true, lw: 2);
    final shin = b ? p.bs : p.fs, off = b ? p.bfa : p.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
    c.save();
    c.translate(an.dx, an.dy + 2);
    c.rotate(planted ? 0 : -shin + off);
    c.scale(1.15, 1.15);
    r.fill(_tkBoot, b ? dk(t.boot, .25) : t.boot, const Rect.fromLTRB(-12, -15, 24, 7), lw: 2.2, shade: const Color(0xFF151018));
    if (!sil) {
      r.detail((pa) => pa
        ..moveTo(-7, -11)
        ..lineTo(4, -11)
        ..moveTo(-7, -6)
        ..lineTo(6, -6), w: 1.2, col: const Color(0xFFCFC8D8));
      r.fill(rrPath(-10, 4, 32, 4, 2), const Color(0xFFCFC8D8), const Rect.fromLTRB(-10, 4, 22, 8), noHT: true, lw: 1.2);
    }
    c.restore();
  }

  void _tankHead(Joints j, KPose p, TankPal t) {
    final neckTop = Offset(j.head.dx - 8, j.head.dy + 10);
    r.limb(j.neck, neckTop, 14, 12, dk(t.hide, .1), bulge: 2);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.45, 1.45);
    r.fill(_tkEar, t.hideD, const Rect.fromLTRB(-17, -31, -4, -14), lw: 1.8);
    r.fill(_tkHead, t.hide, const Rect.fromLTRB(-18, -22, 33, 15), shade: t.hideD);
    r.fill(_tkHorn2, t.horn, const Rect.fromLTRB(10, -28, 19, -13), lw: 1.8, shade: t.hornD, noHT: true);
    r.fill(_tkHorn, t.horn, const Rect.fromLTRB(20, -31, 37, -1), lw: 2, shade: t.hornD, noHT: true);
    if (!sil) {
      r.detail((pa) => pa
        ..moveTo(14, -3)
        ..quadraticBezierTo(17, 1, 15, 5)
        ..moveTo(19, -2)
        ..quadraticBezierTo(22, 2, 20, 6)
        ..moveTo(-6, -4)
        ..quadraticBezierTo(-2, 2, -6, 8), w: 1.2, col: paint ? const Color(0x66282832) : t.hideD);
      r.fill(ellP(4.5, -7.5, 3, 2.4), t.eye, const Rect.fromLTRB(1, -10, 8, -5), noHT: true, lw: 1.1);
      _circ(5.3, -7.3, 1.5, t.iris);
      r.detail((pa) => pa
        ..moveTo(-1, -12)
        ..lineTo(10, -9.5), w: 3, col: const Color(0xFF3A3D46));
      _fillC(ellP(27.5, 4, 1.6, 1, .4), const Color(0xFF2A2830));
      r.detail((pa) => pa
        ..moveTo(10, 9.5)
        ..quadraticBezierTo(17, 10.5, 23, 8.5), w: 1.4);
    }
    c.restore();
  }

  // ================================================================ NYX

  void _nyxMoon(double x, double y, double rad, double rot, bool flat, NyxPal n) {
    c.save();
    c.translate(x, y);
    c.rotate(rot);
    final moon = nyxMoonPath(rad);
    if (paint && !flat) drawGlow(c, Offset.zero, rad * 3.2, withA(n.glow, .75));
    _fillC(moon, flat ? n.violet : n.glow);
    if (cel) _ink(moon, 1.3);
    c.restore();
  }

  void _nyx(Joints j, KPose p, NyxPal n) {
    final f = _f60;
    // The cloak's back: shoulders to a long trailing hem that ripples.
    c.save();
    c.rotate(p.lean * .6);
    final w1 = math.sin(f * .09) * 6, w2 = math.sin(f * .09 + 1.3) * 8, w3 = math.sin(f * .09 + 2.4) * 7;
    final cape = pathOf((q) => q
      ..moveTo(-6, -58)
      ..cubicTo(-26, -50, -34, -24, -44 + w1, -4)
      ..cubicTo(-52 + w2, 16, -40 + w3, 40, -58 + w2, 62)
      ..cubicTo(-38 + w3, 58, -24, 54, -14, 40)
      ..cubicTo(-8, 24, -6, 0, -4, -30));
    r.fill(cape, n.cloakD, const Rect.fromLTRB(-60, -58, -4, 62), lw: 2.2, shade: n.capeShade);
    if (!sil) {
      r.detail((pa) => pa
        ..moveTo(-50 + w2, 30)
        ..quadraticBezierTo(-40 + w3, 46, -50 + w2, 58), w: 1.6, col: n.violet);
    }
    c.restore();
    // The little moon that circles her.
    if (!sil) {
      final a = f * .045;
      _nyxMoon(j.neck.dx - 14 + math.cos(a) * 26, j.neck.dy - 30 + math.sin(a) * 9, 5.5, a * .6, false, n);
    }
    if (p.baf < .5) _nyxArm(j, true, p, n);
    _nyxLeg(j, true, p, n);
    _nyxLeg(j, false, p, n);
    c.save();
    c.rotate(p.lean);
    r.fill(_nxTorso, n.cloak, const Rect.fromLTRB(-16, -60, 16, 0), shade: n.cloakD);
    r.fill(_nxPanel, n.cloakL, const Rect.fromLTRB(-1, -56, 9, -6), noHT: true, lw: 1.4);
    r.fill(rrPath(-11, -24, 22, 5, 2.5), n.violet, const Rect.fromLTRB(-11, -24, 11, -19), noHT: true, lw: 1.6);
    if (!sil) _nyxMoon(3, -44, 4.2, -.5, true, n);
    c.restore();
    _nyxHead(j, p, n);
    if (p.baf >= .5) _nyxArm(j, true, p, n);
    _nyxArm(j, false, p, n);
  }

  void _nyxArm(Joints j, bool b, KPose p, NyxPal n) {
    final sh = b ? j.bSh : j.fSh, el = b ? j.bEl : j.fEl, wr = b ? j.bWr : j.fWr;
    final col = b ? dk(n.cloak, .3) : n.cloak;
    r.limb(sh, el, 7.4, 5.8, col, bulge: 1.6);
    r.limb(el, lerpO(el, wr, 1.05), 5.8, 9.4, b ? dk(n.cloakL, .35) : n.cloakL); // sleeve flares at the wrist
    r.detail((pa) {
      final q = lerpO(el, wr, 1.02);
      pa.addOval(Rect.fromCircle(center: q, radius: 6));
    }, w: 1.2, col: b ? dk(n.violet, .3) : n.violet);
    // Glowing hand.
    final ha = b ? j.bHa : j.fHa;
    if (!sil && !b && paint) drawGlow(c, ha, 18, const Color(0x8CA0F0FF));
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    final hc = b ? dk(n.hand, .3) : n.hand;
    if (p.open > .5) {
      for (var i = 0; i < 4; i++) {
        r.limb(Offset(3 + i * 2.2, -3.5), Offset(3.4 + i * 2.6, -12 + (i - 1.5).abs() * 1.4), 1.7, 1.3, hc, lw: 1.4, noHT: true);
      }
      r.fill(rrPath(0, -5, 10, 10, 4), hc, const Rect.fromLTRB(0, -5, 10, 5), lw: 1.6, noHT: true);
    } else {
      r.fill(rrPath(0, -5.5, 12, 11, 4.5), hc, const Rect.fromLTRB(0, -5, 12, 5), lw: 1.8, noHT: true);
    }
    c.restore();
  }

  void _nyxLeg(Joints j, bool b, KPose p, NyxPal n) {
    // No feet: each leg is robe to the knee, then a tail of smoke that thins
    // to nothing and curls.
    final hip = b ? j.bHip : j.fHip, kn = b ? j.bKn : j.fKn, an = b ? j.bAn : j.fAn;
    r.limb(hip, kn, 9.6, 7.4, b ? dk(n.cloak, .35) : n.cloak, bulge: 2);
    final f = _f60, curl = math.sin(f * .12 + (b ? 1 : 0)) * 4;
    final pts = bez(kn, lerpO(kn, an, .5), Offset(an.dx + 6, an.dy - 2), Offset(an.dx + 12 + curl, an.dy - 8), 10);
    final wisp = tubePath(pts, 7, .6);
    if (paint && !sil) {
      c.drawPath(
          wisp,
          _f
            ..color = const Color(0xFFFFFFFF)
            ..shader = Gradient.linear(kn, an, [b ? const Color(0xFF1C1440) : n.cloak, withA(n.cloak, 0)]));
      _f.shader = null;
    } else {
      r.fill(wisp, b ? dk(n.cloakD, .2) : n.cloakD, Rect.fromLTRB(kn.dx - 10, kn.dy - 10, an.dx + 20, an.dy + 6), noHT: true, lw: 1.8);
    }
    if (!sil) {
      for (var i = 0; i < 3; i++) {
        final t = (f * .02 + i / 3 + (b ? .15 : 0)) % 1.0;
        final x = an.dx + 6 + i * 3 - t * 10, y = an.dy - 2 + t * -18;
        final rad = (1 - t) * 2.6 + .4;
        _circ(x, y, rad, paint ? withA(n.violet, (1 - t) * .7) : n.violet);
      }
    }
  }

  void _nyxHead(Joints j, KPose p, NyxPal n) {
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.22, 1.22);
    final wv = math.sin(_f60 * .1) * 3;
    if (!sil) {
      // Long hair streaming back out of the hood, two locks, lit at the edge.
      final hair = bez(_o(-10, 2), _o(-26, 8), _o(-38, -2 + wv), _o(-54, 10 + wv), 12);
      r.fill(tubePath(hair, 6.4, 1.2), n.hair, bbOf(hair, 8), noHT: true, lw: 1.6);
      final hair2 = bez(_o(-8, 10), _o(-22, 22), _o(-34, 18 + wv), _o(-46, 30 + wv), 10);
      r.fill(tubePath(hair2, 5, 1), n.hair, bbOf(hair2, 8), noHT: true, lw: 1.4);
      r.detail((pa) => pa
        ..moveTo(-14, 4)
        ..quadraticBezierTo(-30, 6, -44, 2 + wv), w: 1.2, col: n.hairHi);
    }
    r.fill(_nxHood, n.cloak, const Rect.fromLTRB(-36, -25, 19, 21), shade: n.cloakD);
    if (!sil) {
      r.fill(_nxOpen, n.voidC, const Rect.fromLTRB(-1, -17, 16, 15), noHT: true, lw: 1.4);
      r.fill(_nxMask, n.mask, const Rect.fromLTRB(3, -15, 16, 14), lw: 1.6, shade: n.maskD, noHT: true);
      // A lock of hair falls in front, past the mask, down to the collar.
      final lw = wv * .4;
      r.fill(
          pathOf((q) => q
            ..moveTo(2, -16)
            ..cubicTo(-2, -6, -1, 8, 3, 22 + lw)
            ..cubicTo(5, 26, 8, 24, 7, 20)
            ..cubicTo(4, 10, 5, -4, 8, -15)),
          n.hair,
          const Rect.fromLTRB(-2, -16, 9, 26),
          noHT: true,
          lw: 1.4);
      r.detail((pa) => pa
        ..moveTo(4, -12)
        ..quadraticBezierTo(2, 4, 5, 18), w: 1.1, col: n.hairHi);
      // A glowing eye slit and a violet tear line: the mask's only features.
      if (paint) drawGlow(c, const Offset(11.5, -5), 9, withA(n.glow, .8));
      c.drawLine(const Offset(9, -4.5), const Offset(14, -5.4), _s..shader = null..strokeWidth = 2..color = n.glow);
      r.detail((pa) => pa
        ..moveTo(11.5, -2)
        ..lineTo(11, 4), w: 1.1, col: n.violet);
    }
    c.restore();
  }
}
