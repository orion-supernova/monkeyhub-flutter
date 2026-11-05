// The KAI skeleton, forward kinematics, palettes and the shaped body parts.
// Ported from docs/fighting-game/style-lab.html (fk, place, fillPart, parts).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'art_common.dart';
import 'roster_rig.dart';
import 'cast/registry.dart';
import 'quality.dart';

// ------------------------------------------------------------------ pose

/// 22 numbers describing one frame of the rig (see the lab's NUM list).
/// Angles: 0 = hanging straight down, +pi/2 = pointing forward.
/// The last three are roster channels: `sa` staff angle (radians, unrotated
/// pelvis frame, MOJO only), `al` alpha (1 = solid), `sx` extra staff length.
class KPose {
  final Float64List v;
  KPose._(this.v);

  factory KPose({
    double rx = 0, double ry = 0, double lean = .14, double head = -.06,
    double fu = .45, double ff = 2.65, double bu = .3, double bf = 2.8,
    double ft = .5, double fs = .02, double bt = -.18, double bs = -.5,
    double ffa = 0, double bfa = 0, double spin = 0, double tuck = 0,
    double baf = 0, double blf = 0, double open = 0, double sa = 0, double al = 1, double sx = 0,
  }) =>
      KPose._(Float64List.fromList([rx, ry, lean, head, fu, ff, bu, bf, ft, fs, bt, bs, ffa, bfa, spin, tuck, baf, blf, open, sa, al, sx]));

  /// Copy of [b] with some fields replaced.
  factory KPose.from(KPose b, {
    double? rx, double? ry, double? lean, double? head, double? fu, double? ff, double? bu, double? bf,
    double? ft, double? fs, double? bt, double? bs, double? ffa, double? bfa, double? spin, double? tuck,
    double? baf, double? blf, double? open, double? sa, double? al, double? sx,
  }) {
    final n = Float64List.fromList(b.v);
    final l = [rx, ry, lean, head, fu, ff, bu, bf, ft, fs, bt, bs, ffa, bfa, spin, tuck, baf, blf, open, sa, al, sx];
    for (var i = 0; i < l.length; i++) {
      final x = l[i];
      if (x != null) n[i] = x;
    }
    return KPose._(n);
  }

  double get rx => v[0];
  double get ry => v[1];
  double get lean => v[2];
  double get head => v[3];
  double get fu => v[4];
  double get ff => v[5];
  double get bu => v[6];
  double get bf => v[7];
  double get ft => v[8];
  double get fs => v[9];
  double get bt => v[10];
  double get bs => v[11];
  double get ffa => v[12];
  double get bfa => v[13];
  double get spin => v[14];
  double get tuck => v[15];
  double get baf => v[16];
  double get blf => v[17];
  double get open => v[18];
  double get sa => v[19];
  double get al => v[20];
  double get sx => v[21];

  static KPose lerp(KPose a, KPose b, double t) {
    final n = Float64List(22);
    for (var i = 0; i < 22; i++) {
      n[i] = a.v[i] + (b.v[i] - a.v[i]) * t;
    }
    // Discrete switches (layering / open hand) flip at the midpoint.
    for (final i in const [16, 17, 18]) {
      n[i] = t < .5 ? a.v[i] : b.v[i];
    }
    return KPose._(n);
  }
}

// ------------------------------------------------------------------ skeleton

const double spLen = 60, uaLen = 33, faLen = 29, thLen = 43, shLen = 41;
/// The lab draws the rig at 1.18x; kept as the rig's own scale.
const double csScale = 1.18;

/// One character's skeleton: bone lengths, shoulder / hip half-widths, head
/// offsets and the lab scale. KAI's are the constants above; the roster's come
/// from the roster lab's `dims`.
class RigDims {
  final double sp, ua, fa, th, sh, cs, shw, hw, headd, hx;
  /// 0 KAI, 1 MOJO, 2 TANK, 3 NYX: which extra joints fk() derives.
  final int kind;
  const RigDims(this.kind, this.sp, this.ua, this.fa, this.th, this.sh, this.cs, this.shw, this.hw, this.headd, this.hx);
}

const RigDims kaiDims = RigDims(0, spLen, uaLen, faLen, thLen, shLen, csScale, 9, 6, 21, 3);
const RigDims mojoDims = RigDims(1, 44, 31, 30, 28, 28, 1.08, 7, 5, 19, 5);
const RigDims tankDims = RigDims(2, 64, 33, 30, 32, 30, 1.3, 14, 9, 22, 12);
const RigDims nyxDims = RigDims(3, 62, 33, 32, 42, 40, 1.18, 8, 5, 22, 3);

RigDims dimsFor(int charId) {
  switch (charId) {
    case 1: return mojoDims;
    case 2: return tankDims;
    case 3: return nyxDims;
    default: return castArt[charId]?.dims ?? kaiDims;
  }
}

enum Jt { pel, neck, fSh, bSh, fEl, fWr, fHa, bEl, bWr, bHa, fHip, bHip, fKn, fAn, bKn, bAn, head, c, sTip, sEnd, horn, mid }

class Joints {
  final Offset pel, neck, fSh, bSh, fEl, fWr, fHa, bEl, bWr, bHa, fHip, bHip, fKn, fAn, bKn, bAn, head, c;
  final double headA, maxAn;
  /// Roster extras: MOJO's staff tip / butt, TANK's horn tip, NYX's hands midpoint.
  final Offset sTip, sEnd, horn, mid;
  const Joints(this.pel, this.neck, this.fSh, this.bSh, this.fEl, this.fWr, this.fHa, this.bEl, this.bWr, this.bHa,
      this.fHip, this.bHip, this.fKn, this.fAn, this.bKn, this.bAn, this.head, this.c, this.headA, this.maxAn,
      {this.sTip = Offset.zero, this.sEnd = Offset.zero, this.horn = Offset.zero, this.mid = Offset.zero});

  Offset at(Jt j) {
    switch (j) {
      case Jt.pel: return pel;
      case Jt.neck: return neck;
      case Jt.fSh: return fSh;
      case Jt.bSh: return bSh;
      case Jt.fEl: return fEl;
      case Jt.fWr: return fWr;
      case Jt.fHa: return fHa;
      case Jt.bEl: return bEl;
      case Jt.bWr: return bWr;
      case Jt.bHa: return bHa;
      case Jt.fHip: return fHip;
      case Jt.bHip: return bHip;
      case Jt.fKn: return fKn;
      case Jt.fAn: return fAn;
      case Jt.bKn: return bKn;
      case Jt.bAn: return bAn;
      case Jt.head: return head;
      case Jt.c: return c;
      case Jt.sTip: return sTip;
      case Jt.sEnd: return sEnd;
      case Jt.horn: return horn;
      case Jt.mid: return mid;
    }
  }
}

Joints fk(KPose p, [RigDims d = kaiDims]) {
  final ux = math.sin(p.lean), uy = -math.cos(p.lean);
  final fx = math.cos(p.lean), fy = math.sin(p.lean);
  Offset at(Offset o, double u, double f) => Offset(o.dx + ux * u + fx * f, o.dy + uy * u + fy * f);
  Offset l(Offset o, double a, double len) => Offset(o.dx + math.sin(a) * len, o.dy + math.cos(a) * len);
  const pel = Offset.zero;
  final neck = at(pel, d.sp, 2), fSh = at(pel, d.sp - 8, d.shw), bSh = at(pel, d.sp - 8, -d.shw - 2);
  final fEl = l(fSh, p.fu, d.ua), fWr = l(fEl, p.ff, d.fa), fHa = l(fWr, p.ff, 6);
  final bEl = l(bSh, p.bu, d.ua), bWr = l(bEl, p.bf, d.fa), bHa = l(bWr, p.bf, 6);
  final fHip = Offset(d.hw, 6), bHip = Offset(-d.hw, 5);
  final fKn = l(fHip, p.ft, d.th), fAn = l(fKn, p.fs, d.sh), bKn = l(bHip, p.bt, d.th), bAn = l(bKn, p.bs, d.sh);
  final headA = p.lean * .55 + p.head;
  final head = Offset(neck.dx + math.sin(headA) * d.headd + d.hx, neck.dy - math.cos(headA) * d.headd);
  final c = at(pel, 24, 0);
  var sTip = Offset.zero, sEnd = Offset.zero, horn = Offset.zero, mid = Offset.zero;
  switch (d.kind) {
    case 1:
      final ca = math.cos(p.sa), sa = math.sin(p.sa), len = 86 + p.sx;
      sTip = Offset(fHa.dx + ca * len, fHa.dy + sa * len);
      sEnd = Offset(fHa.dx - ca * 44, fHa.dy - sa * 44);
      break;
    case 2:
      const s = 1.45;
      final ca = math.cos(headA), sa = math.sin(headA);
      const tx = 37 * s, ty = -31 * s;
      horn = Offset(head.dx + tx * ca - ty * sa, head.dy + tx * sa + ty * ca);
      break;
    case 3:
      mid = Offset((fHa.dx + bHa.dx) / 2, (fHa.dy + bHa.dy) / 2);
      break;
  }
  final j = Joints(pel, neck, fSh, bSh, fEl, fWr, fHa, bEl, bWr, bHa, fHip, bHip, fKn, fAn, bKn, bAn, head, c, headA,
      math.max(fAn.dy, bAn.dy), sTip: sTip, sEnd: sEnd, horn: horn, mid: mid);
  if (d.kind <= 3) return j;
  final x = castArt[d.kind]?.joints(j, p);
  if (x == null) return j;
  return Joints(pel, neck, fSh, bSh, fEl, fWr, fHa, bEl, bWr, bHa, fHip, bHip, fKn, fAn, bKn, bAn, head, c, headA,
      math.max(fAn.dy, bAn.dy), sTip: x.sTip, sEnd: x.sEnd, horn: horn, mid: x.mid);
}

/// Pelvis y in rig space relative to the ground contact (negative = above).
double pelvisY(KPose p, Joints j) {
  final gy = -(j.maxAn + 10);
  final sy = -42 - j.c.dy;
  return lerpD(gy, sy, p.tuck) - p.ry;
}

/// Rotates [o] about the body centre by the pose's spin (rig space).
Offset spinPoint(KPose p, Joints j, Offset o) {
  if (p.spin == 0) return o;
  final s = math.sin(p.spin), co = math.cos(p.spin);
  final dx = o.dx - j.c.dx, dy = o.dy - j.c.dy;
  return Offset(j.c.dx + dx * co - dy * s, j.c.dy + dx * s + dy * co);
}

// ------------------------------------------------------------------ palette

class KPalette {
  final Color skin, hair, tip, vest, tank, pants, pad, wrap, shoe, sole, accent, eye, iris;
  final Color tankShade, hairShade, shoeShade;
  const KPalette({
    required this.skin, required this.hair, required this.tip, required this.vest, required this.tank,
    required this.pants, required this.pad, required this.wrap, required this.shoe, required this.sole,
    required this.accent, this.eye = const Color(0xFFFFF8EE), this.iris = const Color(0xFF3A2316),
    this.tankShade = const Color(0xFF141219), this.hairShade = const Color(0xFF0C0812),
    this.shoeShade = const Color(0xFFA9A2B8),
  });

  static final KPalette kai = KPalette(
    skin: hex(0xc98b62), hair: hex(0x1d1726), tip: hex(0xf3d27a), vest: hex(0x1fb5a8), tank: hex(0x25222e),
    pants: hex(0x3d4152), pad: hex(0xe8642c), wrap: hex(0xf39a4a), shoe: hex(0xf2efe8), sole: hex(0x2b2633),
    accent: hex(0xe8642c));

  /// Player 2 / mirror match: crimson vest, white tips, black shoes.
  static final KPalette kaiAlt = KPalette(
    skin: hex(0xc98b62), hair: hex(0x1d1726), tip: hex(0xf4f1ff), vest: hex(0xd6334f), tank: hex(0x25222e),
    pants: hex(0x34303f), pad: hex(0x3fd2c7), wrap: hex(0xe9e4f2), shoe: hex(0x2a2630), sole: hex(0xe8e4ee),
    accent: hex(0x3fd2c7), shoeShade: hex(0x15121a));

  static final KPalette mojo = KPalette(
    skin: hex(0x8d5a3a), hair: hex(0x2a1a10), tip: hex(0x7cd35a), vest: hex(0xe0a82e), tank: hex(0x1f3a2a),
    pants: hex(0x2f5a3c), pad: hex(0x7cd35a), wrap: hex(0xf3e2a0), shoe: hex(0x6d4a2a), sole: hex(0x1b1410),
    accent: hex(0x7cd35a), shoeShade: hex(0x3d2a18));
  static final KPalette mojoAlt = KPalette(
    skin: hex(0x8d5a3a), hair: hex(0x2a1a10), tip: hex(0xff7ab0), vest: hex(0x8a3fd6), tank: hex(0x2a1f3a),
    pants: hex(0x4a2f5a), pad: hex(0xff7ab0), wrap: hex(0xf3e2a0), shoe: hex(0x3a2a4a), sole: hex(0x1b1410),
    accent: hex(0xff7ab0), shoeShade: hex(0x20162b));

  static final KPalette tankP = KPalette(
    skin: hex(0xe3b496), hair: hex(0xb8362a), tip: hex(0xf0f0f0), vest: hex(0x4b63d6), tank: hex(0x1e2230),
    pants: hex(0x2a3550), pad: hex(0xc9c4d6), wrap: hex(0xc9c4d6), shoe: hex(0x9aa3b8), sole: hex(0x1f2430),
    accent: hex(0xffd23a), shoeShade: hex(0x626b80));
  static final KPalette tankAlt = KPalette(
    skin: hex(0xe3b496), hair: hex(0x2f3a2a), tip: hex(0xffd23a), vest: hex(0xe8642c), tank: hex(0x2a2018),
    pants: hex(0x4a3a2a), pad: hex(0x3a3a3a), wrap: hex(0xe8dcc0), shoe: hex(0x6a5a44), sole: hex(0x1f1810),
    accent: hex(0x3fd2c7), shoeShade: hex(0x3d3322));

  static final KPalette nyx = KPalette(
    skin: hex(0xb8a2d6), hair: hex(0x14101e), tip: hex(0xf4f1ff), vest: hex(0x8a3fd6), tank: hex(0x1a1426),
    pants: hex(0x241c34), pad: hex(0xff4f9a), wrap: hex(0xff4f9a), shoe: hex(0x2a2236), sole: hex(0xb8a2d6),
    accent: hex(0xff4f9a), shoeShade: hex(0x15101e));
  static final KPalette nyxAlt = KPalette(
    skin: hex(0xb8a2d6), hair: hex(0x14101e), tip: hex(0x4ff3ff), vest: hex(0x1f9ad6), tank: hex(0x101a26),
    pants: hex(0x1c2a3c), pad: hex(0x4ff3ff), wrap: hex(0x4ff3ff), shoe: hex(0x1f2a36), sole: hex(0xb8a2d6),
    accent: hex(0x4ff3ff), shoeShade: hex(0x101820));

  /// [charId] is CharacterDef.id; [alt] is true for player 2 (or a mirror match).
  static KPalette forChar(int charId, bool alt) {
    switch (charId) {
      case 1: return alt ? mojoAlt : mojo;
      case 2: return alt ? tankAlt : tankP;
      case 3: return alt ? nyxAlt : nyx;
      default:
        final cast = castArt[charId];
        if (cast != null) return alt ? cast.altPalette : cast.palette;
        return alt ? kaiAlt : kai;
    }
  }
}

// ------------------------------------------------------------------ static paths

Path _torso() => Path()
  ..moveTo(-13, -1)
  ..cubicTo(-18, -14, -20, -31, -18, -46)
  ..cubicTo(-17, -56, -9, -63, -2, -63)
  ..cubicTo(7, -63, 16, -58, 19, -48)
  ..cubicTo(22, -36, 19, -21, 13, -10)
  ..lineTo(12, -1)
  ..close();
Path _vest() => Path()
  ..moveTo(-14, -2)
  ..cubicTo(-19, -14, -21, -31, -19, -46)
  ..cubicTo(-18, -57, -9, -64, -2, -64)
  ..cubicTo(5, -64, 12, -61, 15, -55)
  ..cubicTo(9, -46, 5, -28, 3, -3)
  ..close();
Path _headP() => Path()
  ..moveTo(-2, -19)
  ..cubicTo(-12, -19, -17, -11, -16, -1)
  ..cubicTo(-15, 6, -11, 11, -6, 13)
  ..cubicTo(-1, 17, 5, 18, 9, 16)
  ..cubicTo(11.5, 15, 12, 12, 12, 10)
  ..lineTo(11.5, 8.5)
  ..cubicTo(13, 7.5, 13, 5.5, 12.2, 4.5)
  ..lineTo(16, 1)
  ..lineTo(13.4, -3)
  ..cubicTo(14, -6, 13.5, -12, 11, -15)
  ..cubicTo(8, -18.5, 4, -19.5, -2, -19)
  ..close();
Path _hairP() => Path()
  ..moveTo(12.5, -11)
  ..lineTo(16, -18)
  ..lineTo(8, -17.5)
  ..lineTo(12, -26)
  ..lineTo(2, -21.5)
  ..lineTo(3, -31)
  ..lineTo(-5, -23)
  ..lineTo(-11, -30)
  ..lineTo(-12.5, -21)
  ..lineTo(-22, -23)
  ..lineTo(-16.5, -14)
  ..lineTo(-23, -10)
  ..lineTo(-15.5, -5)
  ..cubicTo(-12, -8, -6, -10.5, 0, -11.5)
  ..cubicTo(4, -12, 8, -12, 12.5, -11)
  ..close();
Path _shoeP() => Path()
  ..moveTo(-8, -10)
  ..cubicTo(-3, -14, 4, -13, 6, -8)
  ..cubicTo(12, -6, 19, -4, 22, 1)
  ..cubicTo(23, 5, 21, 8, 17, 8)
  ..lineTo(-8, 8)
  ..cubicTo(-11, 8, -11, 0, -8, -10)
  ..close();

final Path pTorso = _torso(), pVest = _vest(), pHead = _headP(), pHair = _hairP(), pShoe = _shoeP();
final Path pBolt = Path()
  ..moveTo(10, -44)
  ..lineTo(5, -35)
  ..lineTo(9, -35)
  ..lineTo(6, -27)
  ..lineTo(13, -37)
  ..lineTo(9, -37)
  ..close();
final Path pStripe = Path()
  ..moveTo(-3, -3)
  ..lineTo(10, -6)
  ..lineTo(8, -1.5)
  ..lineTo(17, -2)
  ..lineTo(4, 2.5)
  ..lineTo(6, -1.5)
  ..close();
final Path pEar = Path()..addOval(Rect.fromCenter(center: const Offset(-3, 1), width: 7.2, height: 10.8));
final Path pEye = Path()
  ..moveTo(4, -4.5)
  ..quadraticBezierTo(7.5, -7.5, 11.5, -4.2)
  ..quadraticBezierTo(7.5, -2.2, 4, -4.5)
  ..close();
final Path pHeadShade = Path()..addOval(Rect.fromCenter(center: const Offset(-7, -7), width: 20, height: 10));
final Path pPantsTop = rrPath(-16, -6, 31, 22, 9);
final Path pSoleBar = rrPath(-10, 5, 33, 5.5, 2.5);
final Path pBelt1 = rrPath(-15, -7, 18, 6, 2.5), pBelt2 = rrPath(-14, -3, 28, 7, 2.5), pBuckle = rrPath(5, -3, 7, 7, 1.5);
final Path pFist = rrPath(-2, -7, 15, 14, 5.5), pFistWrap = rrPath(-3, -7.5, 7, 15, 2.5);
final Path pPalm = rrPath(-1, -6, 12, 12, 4), pPalmWrap = rrPath(-2, -6.5, 5, 13, 2);

Path limbPath(Offset a, Offset b, double r1, double r2, [double bulge = 0, double bp = .42]) {
  final dx = b.dx - a.dx, dy = b.dy - a.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  final L = len == 0 ? 1.0 : len;
  final nx = -dy / L, ny = dx / L, an = math.atan2(ny, nx);
  final mx = a.dx + dx * bp, my = a.dy + dy * bp, rm = lerpD(r1, r2, bp);
  final p = Path()..moveTo(a.dx + nx * r1, a.dy + ny * r1);
  p.quadraticBezierTo(mx + nx * (rm + bulge) * 1.08, my + ny * (rm + bulge) * 1.08, b.dx + nx * r2, b.dy + ny * r2);
  p.arcTo(Rect.fromCircle(center: b, radius: r2), an, -math.pi, false);
  p.quadraticBezierTo(mx - nx * (rm + bulge * .45) * 1.06, my - ny * (rm + bulge * .45) * 1.06, a.dx - nx * r1, a.dy - ny * r1);
  p.arcTo(Rect.fromCircle(center: a, radius: r1), an + math.pi, -math.pi, false);
  p.close();
  return p;
}

Offset lerpO(Offset a, Offset b, double t) => Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

// ------------------------------------------------------------------ painter

Image? _htTile;
Shader? _htShader;

Shader? halftoneShader() => _halftone();

Shader? _halftone() {
  if (_htShader != null) return _htShader;
  try {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    c.drawCircle(const Offset(3, 3), 1.25, Paint()..color = const Color(0xE60A0414)..isAntiAlias = true);
    final pic = rec.endRecording();
    _htTile = pic.toImageSync(6, 6);
    pic.dispose();
    _htShader = ImageShader(_htTile!, TileMode.repeated, TileMode.repeated, Float64List.fromList(const [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]),
        filterQuality: FilterQuality.low);
  } catch (_) {
    _htShader = null;
  }
  return _htShader;
}

/// Draws rig parts with one of the three looks. Reuse one instance per frame.
class RigPainter {
  late Canvas c;
  FightLook look = FightLook.cartoon;
  Color? sil;
  late KPalette pal;

  final Paint _fp = Paint()..isAntiAlias = true;
  final Paint _sp = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _ht = Paint()..isAntiAlias = true;

  bool get cel => look == FightLook.cartoon;
  bool get paint => look == FightLook.painted;
  bool get pix => look == FightLook.pixel;

  /// Per-part fill: the lab's `fillPart`, rebuilt to be cheap on every GPU.
  ///
  /// The lab shaded a part by clipping to it and drawing a shifted copy: a
  /// `clipPath` per part, ~90 per frame, the single most expensive thing a
  /// frame can ask of the web (CanvasKit) or a low-end Android GPU. Now the
  /// shading is a precomputed shape: for a path that is drawn again (every
  /// part path is cached, see [limb]), the crescent `path - path.shifted` is
  /// computed ONCE per light direction and kept with the path, as are the
  /// painted look's gradient (per colour), rim light and occlusion. A path
  /// seen only once (a per-frame shape) gets the flat look, which costs one
  /// draw. No clips, no layers, no per-frame shader allocations.
  ///
  /// [frameAngle] is how far the canvas is rotated from world space (limbs
  /// are drawn in their own frame), so the light stays where the world says.
  void fill(Path path, Color base, Rect bb,
      {Color? shade, bool noHT = false, double lw = 2.5, double frameAngle = 0}) {
    if (sil != null) {
      c.drawPath(path, _fp..shader = null..color = sil!);
      return;
    }
    final sh = shade ?? dk(base, .4);
    // Quality governor: reduced drops rim light, occlusion and halftone;
    // minimal drops the shading crescent too (flat fill + outline).
    final qual = fightQuality.value;
    final q = qual == FightQuality.minimal ? null : _part(path);
    final k = frameAngle == 0 ? 0 : ((frameAngle / (math.pi / 8)).round() % 16 + 16) % 16;
    if (paint) {
      if (q != null && qual == FightQuality.full && bb.width * bb.height >= 260) {
        final g = q.grad.putIfAbsent(base.toARGB32() * 31 + sh.toARGB32(),
            () => Gradient.linear(bb.topLeft, bb.bottomRight, [lt(base, .2), base, sh], const [0, .5, 1]));
        c.drawPath(path, _fp..color = const Color(0xFFFFFFFF)..shader = g);
        _fp.shader = null;
        c.drawPath(q.cut(1, k, const Offset(-2.6, 0)), _fp..color = const Color(0x99FFC496)); // rim light
        c.drawPath(q.cut(2, k, const Offset(0, -4)), _fp..color = const Color(0x30140828)); // occlusion
      } else {
        c.drawPath(path, _fp..shader = null..color = base);
        if (q != null) c.drawPath(q.cut(0, k, _light), _fp..color = Color.lerp(base, sh, .55)!);
      }
      _sp
        ..shader = null
        ..strokeWidth = 1.1
        ..color = const Color(0x8C0E0618);
      c.drawPath(path, _sp);
      return;
    }
    c.drawPath(path, _fp..shader = null..color = base);
    if (q != null) {
      final cres = q.cut(0, k, _light);
      c.drawPath(cres, _fp..color = sh);
      if (cel && !noHT && qual == FightQuality.full) {
        final s = _halftone();
        if (s != null) {
          _ht
            ..shader = s
            ..color = const Color(0x52000000);
          c.drawPath(cres, _ht);
        }
      }
    }
    if (cel) {
      _sp
        ..shader = null
        ..strokeWidth = lw
        ..color = kInk;
      c.drawPath(path, _sp);
    }
  }

  /// Paints [marks] (stripes, patches, shading) only where they overlap
  /// [clip], WITHOUT a GPU clip: the intersection is a path, computed once
  /// and kept when both paths are reused, or per call (on the CPU, cheap
  /// next to a clip on the GPU) when [marks] is built per frame.
  void inside(Path clip, Path marks, Color col, {Shader? shader}) {
    if (sil != null) return;
    final byMarks = _insides[clip] ??= Map.identity();
    final cut = byMarks[marks] ?? (() {
      final x = Path.combine(PathOperation.intersect, clip, marks);
      if (_seen[marks] == true) byMarks[marks] = x;
      _seen[marks] = true;
      return x;
    })();
    c.drawPath(cut, _fp..shader = shader..color = col);
    _fp.shader = null;
  }

  static final Map<int, Shader> _tipGrad = {};
  static final Path _tipRectP = Path()..addRect(const Rect.fromLTWH(-30, -40, 60, 22));
  static final Path _tipRectF = Path()..addRect(const Rect.fromLTWH(-30, -40, 60, 18.5));

  static final Expando<Map<Path, Path>> _insides = Expando('fightInside');

  /// The lab's inner-shadow offset (light from the upper left).
  static const Offset _light = Offset(-3.2, -3.6);

  static final Expando<_Part> _parts = Expando('fightPart');
  static final Expando<bool> _seen = Expando('fightPartSeen');

  /// The cache for a path drawn more than once; null the first time (a
  /// per-frame path is never seen twice, so it never costs a boolean op).
  static _Part? _part(Path p) {
    final have = _parts[p];
    if (have != null) return have;
    if (_seen[p] == true) return _parts[p] = _Part(p);
    _seen[p] = true;
    return null;
  }

  /// Limb shapes in their own frame (+x along the bone), by size: a limb's
  /// length is fixed per character, so there are a few dozen of these.
  static final Map<int, (Path, Rect)> _limbs = {};

  /// The lab's `detail`: a few ink lines (skipped in silhouettes).
  void detail(void Function(Path p) draw, {double w = 1.4, Color? col}) {
    if (sil != null) return;
    final p = Path();
    draw(p);
    _sp
      ..shader = null
      ..color = col ?? (paint ? const Color(0x730F061A) : kInk)
      ..strokeWidth = pix ? 1.6 : w;
    c.drawPath(p, _sp);
  }

  /// A tapered limb from [a] to [b]. Drawn from a cached shape in the
  /// limb's own frame (see [fill]), so moving it costs a transform, not a
  /// new path. Lengths snap to half a rig unit.
  void limb(Offset a, Offset b, double r1, double r2, Color col,
      {double bulge = 0, bool noHT = false, double lw = 2.5, Color? shade}) {
    final d = b - a;
    final len = (d.distance * 2).round() / 2;
    if (len < .5) return;
    final key = ((r1 * 8).round() & 0xff) |
        ((r2 * 8).round() & 0xff) << 8 |
        ((bulge * 8).round() & 0x7f) << 16 |
        ((len * 2).round() & 0x7ff) << 23;
    final (path, bb) = _limbs.putIfAbsent(key, () {
      final m = math.max(r1, r2) + bulge;
      return (limbPath(Offset.zero, Offset(len, 0), r1, r2, bulge), Rect.fromLTRB(-m, -m, len + m, m));
    });
    final ang = math.atan2(d.dy, d.dx);
    c.save();
    c.translate(a.dx, a.dy);
    c.rotate(ang);
    fill(path, col, bb, noHT: noHT, lw: lw, shade: shade, frameAngle: ang);
    c.restore();
  }

  final Paint _castLayer = Paint();

  /// A [CastArt] fighter: the same placement, spin and fade as the roster's.
  void _cast(CastArt cast, KPose p, bool alt, int frame) {
    if (p.al <= .02) return;
    final j = fk(p, cast.dims);
    final layer = p.al < 1;
    if (layer) c.saveLayer(null, _castLayer..color = Color.fromRGBO(0, 0, 0, p.al.clamp(0.0, 1.0)));
    c.save();
    c.translate(p.rx, pelvisY(p, j));
    if (p.spin != 0) {
      c.translate(j.c.dx, j.c.dy);
      c.rotate(p.spin);
      c.translate(-j.c.dx, -j.c.dy);
    }
    cast.paint(this, j, p, alt, frame.toDouble());
    c.restore();
    if (layer) c.restore();
  }

  /// The roster painters (MOJO / TANK / NYX), created on first use.
  RosterPainter? _roster;

  // -------- parts

  void _shoe(Offset an, double phi, bool back) {
    c.save();
    c.translate(an.dx, an.dy);
    c.rotate(phi);
    fill(pShoe, back ? dk(pal.shoe, .3) : pal.shoe, const Rect.fromLTRB(-11, -14, 23, 9),
        shade: back ? dk(pal.shoe, .5) : pal.shoeShade);
    fill(pSoleBar, back ? dk(pal.sole, .2) : pal.sole, const Rect.fromLTRB(-10, 5, 23, 11), noHT: true);
    if (sil == null) {
      fill(pStripe, back ? dk(pal.accent, .3) : pal.accent, const Rect.fromLTRB(-3, -6, 17, 3), lw: 1.6, noHT: true);
    }
    c.restore();
  }

  void _hand(Offset wr, Offset el, bool open, bool back) {
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    final sk = back ? dk(pal.skin, .3) : pal.skin;
    final wrp = back ? dk(pal.wrap, .3) : pal.wrap;
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    if (open) {
      for (var i = 0; i < 4; i++) {
        limb(Offset(2.5 + i * 2.6, -4), Offset(3 + i * 2.8, -15 + (i - 1.5).abs() * 1.6), 2.2, 1.9, sk, noHT: true, lw: 1.8);
      }
      fill(pPalm, sk, const Rect.fromLTRB(-1, -6, 11, 6), lw: 2);
      limb(const Offset(3, 4), const Offset(11, 6.5), 2.4, 2, sk, noHT: true, lw: 1.8);
      fill(pPalmWrap, wrp, const Rect.fromLTRB(-2, -6, 3, 6), noHT: true, lw: 1.8);
    } else {
      fill(pFist, sk, const Rect.fromLTRB(-2, -7, 13, 7), lw: 2.2);
      fill(pFistWrap, wrp, const Rect.fromLTRB(-3, -7, 4, 7), noHT: true, lw: 2);
      detail((p) => p..moveTo(9, -6)..lineTo(9, 6), w: 1.1);
    }
    c.restore();
  }

  /// An open hand at [wr] pointing along el->wr, in the current palette.
  void openHand(Offset wr, Offset el, bool back) => _hand(wr, el, true, back);

  void _arm(Joints j, bool back, KPose p) {
    final sh = back ? j.bSh : j.fSh, el = back ? j.bEl : j.fEl, wr = back ? j.bWr : j.fWr;
    final sk = back ? dk(pal.skin, .3) : pal.skin;
    final wrp = back ? dk(pal.wrap, .3) : pal.wrap;
    limb(sh, el, 10.5, 7, sk, bulge: 3.4);
    limb(el, wr, 7.6, 5.8, sk, bulge: 2.2);
    final w0 = lerpO(el, wr, .52);
    limb(w0, wr, 7.4, 6.4, wrp, noHT: true);
    detail((pa) {
      final dx = wr.dx - el.dx, dy = wr.dy - el.dy;
      final L = math.sqrt(dx * dx + dy * dy);
      if (L == 0) return;
      final nx = -dy / L * 5.8, ny = dx / L * 5.8;
      for (var i = 1; i < 3; i++) {
        final q = lerpO(w0, wr, i / 3);
        pa.moveTo(q.dx + nx, q.dy + ny);
        pa.lineTo(q.dx - nx + dx / L * 2, q.dy - ny + dy / L * 2);
      }
    }, w: 1);
    _hand(wr, el, p.open > .5, back);
  }

  void _leg(Joints j, bool back, KPose p) {
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    final pc = back ? dk(pal.pants, .3) : pal.pants;
    limb(hip, kn, 12, 9.4, pc, bulge: 3.4);
    limb(kn, an, 9.6, 7, pc, bulge: 2.6);
    detail((pa) {
      final m = lerpO(hip, kn, .5);
      pa.moveTo(m.dx - 3, m.dy - 2);
      pa.quadraticBezierTo(m.dx + 2, m.dy + 4, m.dx + 6, m.dy + 3);
    }, w: 1.1);
    {
      final dx = an.dx - kn.dx, dy = an.dy - kn.dy;
      final L = math.sqrt(dx * dx + dy * dy);
      final ll = L == 0 ? 1.0 : L;
      final fwd = (dy / ll) >= 0 ? 1.0 : -1.0;
      final k0 = Offset(kn.dx - dy / ll * 2.5 * fwd, kn.dy + dx / ll * 2.5 * fwd);
      final k1 = Offset(an.dx - dy / ll * 2.5 * fwd, an.dy + dx / ll * 2.5 * fwd);
      limb(lerpO(k0, k1, -.08), lerpO(k0, k1, .14), 8, 7.2, back ? dk(pal.pad, .3) : pal.pad, noHT: true);
    }
    limb(lerpO(kn, an, .82), an, 7.6, 7.4, back ? dk(pal.pants, .45) : dk(pal.pants, .18), noHT: true);
    final shin = back ? p.bs : p.fs, off = back ? p.bfa : p.ffa;
    final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
    _shoe(an, planted ? 0 : -shin + off, back);
  }

  void _torso(Joints j, KPose p) {
    fill(pPantsTop, pal.pants, const Rect.fromLTRB(-16, -6, 15, 16));
    c.save();
    c.rotate(p.lean);
    c.scale(1.22, 1.04);
    fill(pTorso, pal.tank, const Rect.fromLTRB(-20, -64, 20, 0), shade: pal.tankShade);
    if (sil == null) fill(pBolt, pal.accent, const Rect.fromLTRB(5, -44, 13, -27), lw: 1.5, noHT: true);
    detail((pa) => pa..moveTo(15, -24)..quadraticBezierTo(10, -21, 7, -14), w: 1.1);
    fill(pVest, pal.vest, const Rect.fromLTRB(-21, -64, 15, -2));
    detail((pa) => pa
      ..moveTo(-15, -40)
      ..quadraticBezierTo(-10, -30, -11, -12)
      ..moveTo(10, -52)
      ..quadraticBezierTo(7, -40, 6, -28), w: 1.1);
    fill(pBelt1, dk(pal.vest, .25), const Rect.fromLTRB(-15, -7, 3, -1), noHT: true, lw: 1.8);
    fill(pBelt2, const Color(0xFF2A2433), const Rect.fromLTRB(-14, -3, 14, 4), noHT: true, lw: 1.8);
    fill(pBuckle, pal.accent, const Rect.fromLTRB(5, -3, 12, 4), noHT: true, lw: 1.6);
    c.restore();
  }

  void _head(Joints j, KPose p) {
    final neckTop = Offset(j.head.dx + math.sin(j.headA) * -12 - 2, j.head.dy + math.cos(j.headA) * 12);
    limb(j.neck, neckTop, 7.2, 6.6, dk(pal.skin, .12));
    fill(limbPath(Offset(j.neck.dx - 7, j.neck.dy + 2), Offset(j.neck.dx + 7, j.neck.dy + 1), 4.5, 4.5), dk(pal.vest, .2),
        Rect.fromLTRB(j.neck.dx - 12, j.neck.dy - 4, j.neck.dx + 12, j.neck.dy + 7), noHT: true, lw: 1.8);
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.2, 1.2);
    fill(pHead, pal.skin, const Rect.fromLTRB(-17, -20, 16, 18));
    if (sil == null) {
      inside(pHead, pHeadShade, paint ? const Color(0x59281C28) : mixC(pal.skin, pal.hair, .45));
      fill(pEar, dk(pal.skin, .08), const Rect.fromLTRB(-7, -4, 1, 7), lw: 1.6, noHT: true);
    }
    fill(pHair, pal.hair, const Rect.fromLTRB(-23, -31, 16, -5), shade: pal.hairShade, noHT: true);
    if (sil == null) {
      if (paint) {
        final g = _tipGrad.putIfAbsent(pal.tip.toARGB32(),
            () => Gradient.linear(const Offset(0, -31), const Offset(0, -18), [pal.tip, withA(pal.tip, 0)]));
        inside(pHair, _tipRectP, const Color(0xFFFFFFFF), shader: g);
      } else {
        inside(pHair, _tipRectF, pal.tip);
      }
      if (cel) {
        _sp
          ..shader = null
          ..strokeWidth = 2.4
          ..color = kInk;
        c.drawPath(pHair, _sp);
      }
      c.drawPath(pEye, _fp..shader = null..color = pal.eye);
      c.drawCircle(const Offset(9.3, -4.6), 1.7, _fp..color = pal.iris);
      if (!pix) {
        _sp
          ..strokeWidth = 1
          ..color = kInk;
        c.drawPath(pEye, _sp);
      }
      detail((pa) => pa..moveTo(2.5, -9)..lineTo(12.5, -6.8), w: pix ? 2.2 : 2.6, col: const Color(0xFF140C18));
      detail((pa) => pa..moveTo(8.5, 10.6)..lineTo(11.8, 9.6), w: 1.3);
      detail((pa) => pa..moveTo(4, 4.5)..lineTo(7, 6.5), w: 1,
          col: paint ? const Color(0xB3FFDCBE) : lt(pal.skin, .45));
    }
    c.restore();
  }

  /// Draws a whole fighter. The canvas origin must be the ground contact point,
  /// +x forward, unit = one rig unit (the caller applies the world scale).
  ///
  /// [charId] picks the character (0 KAI; 1 MOJO, 2 TANK, 3 NYX are drawn by
  /// [RosterPainter]); [alt] is the player-2 outfit of the roster characters
  /// (KAI's comes in [palette]); [frame] drives the idle loops (tails, capes,
  /// hair, the moon orbiting NYX).
  void fighter(Canvas canvas, KPose p, KPalette palette, FightLook lk,
      {Color? silhouette, int charId = 0, bool alt = false, int frame = 0}) {
    c = canvas;
    look = lk;
    pal = palette;
    sil = silhouette;
    if (charId >= 1 && charId <= 3) {
      (_roster ??= RosterPainter(this)).fighter(p, charId, alt, frame);
      return;
    }
    final cast = castArt[charId];
    if (cast != null) {
      _cast(cast, p, alt, frame);
      return;
    }
    final j = fk(p);
    c.save();
    c.translate(p.rx, pelvisY(p, j));
    if (p.spin != 0) {
      c.translate(j.c.dx, j.c.dy);
      c.rotate(p.spin);
      c.translate(-j.c.dx, -j.c.dy);
    }
    if (p.baf < .5) _arm(j, true, p);
    if (p.blf < .5) _leg(j, true, p);
    _torso(j, p);
    _leg(j, false, p);
    if (p.blf >= .5) _leg(j, true, p);
    _head(j, p);
    if (p.baf >= .5) _arm(j, true, p);
    _arm(j, false, p);
    c.restore();
  }
}

/// What [RigPainter.fill] keeps per reused path: shading crescents per kind
/// and light direction, and the painted gradient per colour.
class _Part {
  _Part(this.path);
  final Path path;
  final Map<int, Path> _cuts = {};
  final Map<int, Shader> grad = {};

  /// `path - path.shift(o)` with [o] turned into the path's own frame
  /// (rotated back by [k] sixteenths of a turn); [kind] keeps rim, shade
  /// and occlusion apart.
  Path cut(int kind, int k, Offset o) => _cuts.putIfAbsent(kind * 16 + k, () {
        final a = -k * math.pi / 8;
        final r = Offset(o.dx * math.cos(a) - o.dy * math.sin(a), o.dx * math.sin(a) + o.dy * math.cos(a));
        return Path.combine(PathOperation.difference, path, path.shift(r));
      });
}
