// BOOM - sumo. Big, round and low: a navy mawashi with hanging cords, hair in a
// chonmage (topknot), huge open palms for the tsuppari. The idle is a wide low
// stance with a slow foot stomp (shiko) that shakes the dust.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, MoveAnim;
import '../roster_poses.dart' show rigScale;
import '../roster_rig.dart' show ellP, tubePath, bbOf, pathOf, bez;
import 'cast_art.dart';
import 'human_kit.dart';

class _BoomCol {
  final Color mawashi, mawashiD, trim, hair, tie, skinD;
  const _BoomCol(this.mawashi, this.mawashiD, this.trim, this.hair, this.tie, this.skinD);
}

final _BoomCol _main = _BoomCol(hex(0x1c2a66), hex(0x0e1638), hex(0xf2c14e), hex(0x15101a), hex(0xf4efe6), hex(0xb8764e));
final _BoomCol _alt = _BoomCol(hex(0x9c1c2c), hex(0x560c18), hex(0xe9eef6), hex(0x3a2a22), hex(0xf2c14e), hex(0xb8764e));

class BoomArt extends CastArt {
  BoomArt();

  @override
  int get id => 15;
  @override
  RigDims get dims => const RigDims(15, 54, 34, 30, 30, 28, 1.28, 17, 12, 24, 4);

  static final KPose _idle = KPose.from(pIdle,
      lean: .06, head: -.02, fu: 1.15, ff: 1.65, bu: .5, bf: 1.3, ft: .95, fs: -.3, bt: -.8, bs: -.1, open: 1);
  @override
  KPose get idle => _idle;

  @override
  KPalette get palette => _pal(_main);
  @override
  KPalette get altPalette => _pal(_alt);
  KPalette _pal(_BoomCol c) => KPalette(
      skin: hex(0xdfa57a), hair: c.hair, tip: c.tie, vest: c.mawashi, tank: c.mawashi, pants: c.mawashi, pad: c.mawashi,
      wrap: hex(0xdfa57a), shoe: hex(0xdfa57a), sole: c.skinD, accent: c.trim, tankShade: c.mawashiD);

  @override
  double get portraitWidth => 148;

  // ------------------------------------------------------------------ paint

  final Path _torso = pathOf((p) => p
    ..moveTo(-26, -2)
    ..cubicTo(-38, -22, -37, -52, -23, -64)
    ..cubicTo(-10, -75, 12, -75, 25, -63)
    ..cubicTo(36, -53, 40, -40, 41, -28)
    ..cubicTo(43, -12, 32, -1, 18, -2));
  final Path _belly = ellP(24, -22, 17, 20, -.1);
  final Path _foot = footPath();
  final Path _cap = pathOf((p) => p
    ..moveTo(14, -10)
    ..cubicTo(15, -20, 4, -25, -5, -23)
    ..cubicTo(-15, -21, -19, -10, -17, 0)
    ..cubicTo(-12, -6, -6, -10, 0, -11)
    ..cubicTo(6, -12, 11, -12, 14, -10));
  final Path _belt = rrPath(-28, -13, 66, 15, 6);

  KPose _stomp(KPose p, double frame) {
    final u = (frame % 110) / 110;
    var lift = 0.0;
    if (u < .26) {
      lift = smooth(u / .26);
    } else if (u < .31) {
      lift = 1 - (u - .26) / .05;
    }
    return KPose.from(p, ft: p.ft + lift * .85, fs: p.fs + lift * .7, lean: p.lean - lift * .05, bt: p.bt - lift * .1);
  }

  @override
  void paint(RigPainter rp, Joints j0, KPose p0, bool alt, double frame) {
    final c = rp.c;
    final k = alt ? _alt : _main;
    final t = frame * .09;
    var j = j0;
    var p = p0;
    c.save();
    var dust = 0.0;
    if (isIdleLike(p0, _idle)) {
      p = _stomp(p0, frame);
      j = fk(p, dims);
      final u = (frame % 110) / 110;
      // The body drops and shakes when the foot lands.
      if (u >= .3 && u < .5) {
        final d = (1 - (u - .3) / .2);
        c.translate(0, d * 3.2 * math.sin(u * 90).abs());
        dust = d;
      }
    }
    final arm = ArmStyle(skin: rp.pal.skin, tape: rp.pal.skin, taped: false, girth: 1.3, palm: 1.4);
    void palm(Offset wr, Offset el, bool back) {
      final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
      c.save();
      c.translate(wr.dx, wr.dy);
      c.rotate(ang);
      c.scale(1.5, 1.5);
      rp.openHand(Offset.zero, const Offset(-1, 0), back);
      c.restore();
    }

    if (p.baf < .5) kitArm(rp, j, p, true, arm, hand: (w, e) => palm(w, e, true));
    if (p.blf < .5) _leg(rp, j, p, true, k);
    _torsoP(rp, j, p, k, t);
    _leg(rp, j, p, false, k);
    if (p.blf >= .5) _leg(rp, j, p, true, k);
    _head(rp, j, p, k);
    if (p.baf >= .5) kitArm(rp, j, p, true, arm, hand: (w, e) => palm(w, e, true));
    kitArm(rp, j, p, false, arm, hand: (w, e) => palm(w, e, false));
    if (dust > 0 && rp.sil == null) {
      final g = j.fAn + const Offset(14, 10);
      final pt = Paint()..color = withA(const Color(0xFFE8DCCB), .55 * dust);
      for (var i = 0; i < 4; i++) {
        final r = (3 + i * 1.6) * (1.4 - dust * .5);
        c.drawCircle(Offset(g.dx + 8 + i * 9 * (1.2 - dust), g.dy - 3 - i * 2.2 * (1 - dust) - 2), r, pt);
      }
    }
    c.restore();
  }

  void _torsoP(RigPainter rp, Joints j, KPose p, _BoomCol k, double t) {
    final c = rp.c;
    final skin = rp.pal.skin;
    // Hips under the mawashi.
    rp.fill(rrPath(-24, -10, 46, 24, 11), k.mawashi, const Rect.fromLTRB(-24, -10, 22, 14), shade: k.mawashiD);
    c.save();
    c.rotate(p.lean);
    c.scale(1.06, 1.04);
    rp.fill(_torso, skin, const Rect.fromLTRB(-38, -75, 43, 0), shade: dk(skin, .3));
    if (rp.sil == null) {
      // Chest line, belly roundness, navel.
      rp.detail((q) => q
        ..moveTo(-18, -52)
        ..quadraticBezierTo(0, -44, 20, -50), w: 1.4);
      c.save();
      c.clipPath(_torso);
      c.drawPath(_belly, Paint()..color = rp.paint ? const Color(0x22FFFFFF) : lt(skin, .14));
      c.restore();
      rp.detail((q) => q.addPath(_belly, Offset.zero), w: 1.1, col: rp.paint ? const Color(0x44301810) : dk(skin, .35));
      rp.detail((q) => q
        ..moveTo(26, -26)
        ..lineTo(28.5, -23.5), w: 1.8);
    }
    // The mawashi: a thick belt around the middle and cords hanging in front.
    rp.fill(_belt, k.mawashi, const Rect.fromLTRB(-28, -13, 38, 2), shade: k.mawashiD, noHT: true, lw: 2.2);
    rp.detail((q) {
      for (var x = -22.0; x < 36; x += 8) {
        q.moveTo(x, -12);
        q.lineTo(x + 3, 1);
      }
    }, w: 1, col: k.mawashiD);
    for (var i = 0; i < 6; i++) {
      final root = Offset(14 + i * 4.4, 2);
      final l = sway(root, 27 - (i - 2.5).abs() * 2.2, .08, 1, t * 1.2 + i * .5, 2.2, n: 4);
      rp.fill(tubePath(l, 2.2, 1.7), i.isEven ? k.mawashi : dk(k.mawashi, .15), bbOf(l, 4), noHT: true, lw: 1.3);
      c.drawCircle(l.last, 2, Paint()..color = k.trim);
    }
    rp.fill(rrPath(11, -14, 10, 17, 3), k.trim, const Rect.fromLTRB(11, -14, 21, 3), noHT: true, lw: 1.6);
    c.restore();
  }

  void _leg(RigPainter rp, Joints j, KPose p, bool back, _BoomCol k) {
    final c = rp.c;
    final hip = back ? j.bHip : j.fHip, kn = back ? j.bKn : j.fKn, an = back ? j.bAn : j.fAn;
    final sk = back ? dk(rp.pal.skin, .3) : rp.pal.skin;
    rp.limb(hip, kn, 19, 14, sk, bulge: 5, shade: dk(rp.pal.skin, .3));
    rp.limb(kn, an, 14, 9.6, sk, bulge: 3.4);
    rp.limb(lerpO(hip, kn, -.1), lerpO(hip, kn, .28), 19.5, 18, back ? dk(k.mawashi, .3) : k.mawashi, noHT: true, lw: 2);
    c.save();
    c.translate(an.dx, an.dy + 1);
    c.rotate(footRot(j, p, back));
    c.scale(1.2, 1.15);
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

  void _head(RigPainter rp, Joints j, KPose p, _BoomCol k) {
    final c = rp.c;
    final skin = rp.pal.skin;
    rp.limb(j.neck, Offset(j.head.dx - 4, j.head.dy + 10), 14, 12.5, dk(skin, .1));
    c.save();
    c.translate(j.head.dx, j.head.dy);
    c.rotate(j.headA);
    c.scale(1.34, 1.3);
    rp.fill(pHead, skin, const Rect.fromLTRB(-17, -20, 16, 18));
    if (rp.sil == null) {
      c.save();
      c.clipPath(pHead);
      c.drawPath(pHeadShade, Paint()..color = rp.paint ? const Color(0x59281C28) : k.skinD);
      c.restore();
      rp.fill(pEar, dk(skin, .08), const Rect.fromLTRB(-7, -4, 1, 7), lw: 1.6, noHT: true);
      // Cheeks.
      c.drawPath(ellP(7, 6, 5, 3.4), Paint()..color = withA(const Color(0xFFE0605A), .28));
    }
    rp.fill(_cap, k.hair, const Rect.fromLTRB(-19, -25, 15, -2), shade: dk(k.hair, .2), noHT: true);
    // The chonmage: the queue folded forward over the crown, tied with a cord.
    final knot = bez(const Offset(-10, -21), const Offset(-14, -31), const Offset(-2, -41), const Offset(10, -32), 8);
    rp.fill(tubePath(knot, 4.6, 3.4), k.hair, bbOf(knot, 6), shade: dk(k.hair, .2), noHT: true, lw: 1.8);
    if (rp.sil == null) {
      c.drawCircle(const Offset(-9, -22.5), 3.2, Paint()..color = k.tie);
      c.drawCircle(const Offset(-9, -22.5), 3.2, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = kInk);
      rp.detail((q) => q
        ..moveTo(-3, -36.5)
        ..quadraticBezierTo(2, -35.5, 6, -32), w: 1, col: lt(k.hair, .3));
      // Small fierce eye, heavy brow, firm mouth.
      c.drawPath(ellP(8.4, -4.4, 3.5, 2.5, -.05), Paint()..color = rp.pal.eye);
      c.drawCircle(const Offset(9.2, -4.4), 1.6, Paint()..color = rp.pal.iris);
      c.drawCircle(const Offset(9.7, -5), .5, Paint()..color = const Color(0xFFFFFFFF));
      rp.detail((q) => q.addPath(ellP(8.4, -4.4, 3.5, 2.5, -.05), Offset.zero), w: 1, col: kInk);
      rp.detail((q) => q
        ..moveTo(2, -8.6)
        ..lineTo(13, -6.4), w: 3, col: const Color(0xFF140C18));
      rp.detail((q) => q
        ..moveTo(8, 9.6)
        ..quadraticBezierTo(10.4, 10.4, 12.6, 9), w: 1.5, col: const Color(0xFF6A2E24));
      rp.detail((q) => q
        ..moveTo(12.5, 1)
        ..lineTo(14.4, 2.6), w: 1, col: dk(skin, .4));
    }
    c.restore();
  }

  // ------------------------------------------------------------------ poses

  @override
  (KPose, KPose, KPose)? readyPoses() {
    final q = poseOf(_idle);
    return (
      q(fu: .2, ff: -.2, bu: .1, bf: -.3, lean: .2, rx: -4, baf: 1),
      q(fu: 1.5, ff: 1.57, bu: 1.4, bf: 1.5, baf: 1, lean: .42, rx: 12),
      q(fu: 1.2, ff: 1.9, bu: 1.1, bf: 1.9, baf: 1, lean: .1),
    );
  }

  @override
  MoveAnim? anim(MoveDef m, CharacterDef def) {
    final I = _idle;
    final q = poseOf(I);
    final s = m.startup, a = m.active, r = m.recovery, t = m.total;
    KPose crouch([double lean = .55]) => q(lean: lean, ft: 1.1, fs: -.55, bt: .5, bs: -.95, fu: .6, ff: .6, bu: .5, bf: .6);
    switch (m.name) {
      case 'standLight':
        final x = lunged(m, 15, q(fu: 1.55, ff: 1.6, lean: .22, rx: 8, ft: 1.0, bt: -.85), Jt.fHa, max: 30);
        return MoveAnim(strike(m, I, q(fu: .7, ff: 2.0, lean: .0, rx: -3), x, hold: KPose.from(x, fu: 1.45, ff: 1.7)),
            smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
      case 'standLight2':
        final x = lunged(m, 15, q(bu: 1.55, bf: 1.6, baf: 1, lean: .24, rx: 8, fu: .8, ff: 1.7, ft: 1.0, bt: -.85), Jt.bHa, max: 30);
        return MoveAnim(strike(m, I, q(bu: .7, bf: 2.0, baf: 1, lean: .0, rx: -3), x, hold: KPose.from(x, bu: 1.45, bf: 1.7)),
            smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
      case 'standHeavy':
        // Oshi: both palms drive into the chest, the whole mass behind them.
        final x = lunged(m, 15, q(fu: 1.5, ff: 1.52, bu: 1.4, bf: 1.5, baf: 1, lean: .42, rx: 14, ft: 1.15, fs: -.2, bt: -1.0, bs: -.25), Jt.fHa, max: 34);
        return MoveAnim(
            strike(m, I, q(fu: .1, ff: -.3, bu: 0, bf: -.3, baf: 1, lean: -.08, rx: -6), x, hold: KPose.from(x, lean: .5, rx: x.rx + 3), windAt: .7),
            smear: Jt.fHa, smearA: s - 3, smearB: s + a + 2);
      case 'tsuppari':
        final ws = m.windows;
        final gap = ws.length > 1 ? ws[1].start - ws[0].start : 4;
        final keys = <Key>[Key(0, I), Key(mx(1, s ~/ 2), q(fu: .8, ff: 1.9, bu: .7, bf: 1.9, lean: .15, ft: 1.1, fs: -.3))];
        for (var i = 0; i < ws.length; i++) {
          final last = i == ws.length - 1;
          final front = i.isEven;
          final thrust = last
              ? q(fu: 1.5, ff: 1.52, bu: 1.4, bf: 1.5, baf: 1, lean: .5, rx: 16, ft: 1.15, fs: -.2, bt: -1.0, bs: -.25)
              : q(
                  fu: front ? 1.52 : .7, ff: front ? 1.57 : 1.9, bu: front ? .6 : 1.5, bf: front ? 1.7 : 1.57, baf: front ? 0 : 1,
                  lean: .36 + (front ? 0 : .06), rx: 10 + i * 1.5, ft: 1.05, fs: -.2, bt: -.9, bs: -.2);
          keys.add(Key(ws[i].start, thrust, 1));
          if (!last) keys.add(Key(ws[i].start + mx(1, gap ~/ 2), KPose.from(thrust, lean: thrust.lean - .06)));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rnd(r * .35), q(lean: .25, fu: 1.1, ff: 1.7)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fHa, smearA: s - 1, smearB: tail);
      case 'dohyoCharge':
        // Tachiai: down low, fists to the ground, then the whole body drives forward.
        KPose run(bool ph) => q(
            lean: .85, head: .15, fu: 1.3, ff: 1.9, bu: 1.2, bf: 1.9, baf: 1, ft: ph ? 1.1 : -.1, fs: ph ? -.1 : -.7,
            bt: ph ? -.6 : .9, bs: ph ? -.6 : -.2);
        final keys = <Key>[Key(0, I), Key(mx(1, 4), q(lean: .8, ft: 1.25, fs: -.7, bt: .6, bs: -1.0, fu: .6, ff: .3, bu: .5, bf: .3, head: .2)), Key(mx(2, s - 2), q(lean: .9, ft: 1.3, fs: -.8, bt: .7, bs: -1.05, fu: .5, ff: .25, bu: .4, bf: .2, head: .25))];
        var ph = true;
        for (var f = s; f < s + a; f += 5) {
          keys.add(Key(f, run(ph), f == s ? 1 : 0));
          ph = !ph;
        }
        keys.add(Key(s + a, run(ph)));
        keys.add(Key(s + a + rnd(r * .45), q(lean: .35, fu: 1.1, ff: 1.7)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys));
      case 'uwatenage':
        final reach = q(fu: 1.5, ff: 1.5, bu: 1.4, bf: 1.45, baf: 1, lean: .38, rx: 8, ft: 1.05, fs: -.2, bt: -.9, bs: -.25);
        final lift = q(fu: 2.9, ff: 3.0, bu: 2.6, bf: 2.9, baf: 1, lean: -.22, rx: 4, ft: .85, fs: -.25, bt: -.7, bs: -.1, head: -.1);
        final slam = q(fu: 1.2, ff: .9, bu: 1.1, bf: .85, baf: 1, lean: .62, rx: 12, ft: 1.15, fs: -.4, bt: -.9, bs: -.2, head: .1);
        final g = s + a;
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 2), q(fu: 1.0, ff: 1.7, bu: .9, bf: 1.7, baf: 1, lean: .2)),
              Key(s, reach, 1),
              Key(g + 4, reach),
              Key(g + 11, lift, 1),
              Key(g + 18, slam, 1),
              Key(g + 24, slam),
              Key(mx(t, g + 25), I),
            ]));
      case 'bellyBounce':
        final hop = q(lean: -.3, head: -.12, ry: 14, fu: 2.3, ff: 2.5, bu: -2.2, bf: -2.4, ft: .6, fs: .2, bt: -.4, bs: .0, open: 1);
        return MoveAnim(
            mono([
              Key(0, I),
              Key(mx(1, s - 3), crouch(.5)),
              Key(s, hop, 1),
              Key(s + a, KPose.from(hop, ry: 18, lean: -.36)),
              Key(s + a + rnd(r * .4), q(lean: .1, ry: 3, ft: 1.0, fs: -.4)),
              Key(mx(t, s + a + rnd(r * .4) + 1), I),
            ]));
      case 'yokozunaThunder':
        final ws = m.windows;
        final gap = ws.length > 1 ? ws[1].start - ws[0].start : 4;
        final keys = <Key>[Key(0, I), Key(mx(1, 3), crouch(.7)), Key(mx(2, s - 1), q(lean: .85, ft: 1.3, fs: -.8, bt: .7, bs: -1.05, fu: .4, ff: .2, bu: .3, bf: .1, head: .25))];
        for (var i = 0; i < ws.length; i++) {
          final last = i == ws.length - 1;
          final front = i.isEven;
          final ph = front;
          final thrust = last
              ? q(fu: 1.5, ff: 1.52, bu: 1.4, bf: 1.5, baf: 1, lean: .62, rx: 18, ft: 1.2, fs: -.2, bt: -1.0, bs: -.25)
              : q(
                  fu: front ? 1.52 : .8, ff: front ? 1.57 : 1.9, bu: front ? .7 : 1.5, bf: front ? 1.8 : 1.57, baf: front ? 0 : 1,
                  lean: .6, rx: 10 + i * 2.0, ft: ph ? 1.1 : -.1, fs: ph ? -.1 : -.7, bt: ph ? -.6 : .9, bs: ph ? -.6 : -.2);
          keys.add(Key(ws[i].start, thrust, 1));
          if (!last) keys.add(Key(ws[i].start + mx(1, gap ~/ 2), KPose.from(thrust, lean: .52)));
        }
        final tail = ws.isEmpty ? s + a : ws.last.end;
        keys.add(Key(tail + rnd(r * .3), q(lean: .4, fu: 1.1, ff: 1.7)));
        keys.add(Key(t, I));
        return MoveAnim(mono(keys), smear: Jt.fHa, smearA: s, smearB: tail);
    }
    return null;
  }

  // ------------------------------------------------------------------ fx

  @override
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {
    final f = s.p[player];
    if (f.state != St.move || f.moveId < 0) return;
    final m = s.chars[player].moves[f.moveId];
    final rs = rigScale(15) * cam.scale;
    final pt = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (m.name == 'bellyBounce' && f.sf >= m.startup - 1 && f.sf <= m.startup + m.active + 4) {
      final o = jointScreen(cam, s, player, Jt.c) + Offset(f.face * 34 * rs, -4 * rs);
      final u = (f.sf - m.startup + 1) / (m.active + 5);
      final r = (24 + 46 * u) * rs;
      pt
        ..strokeWidth = (7 - 5 * u) * rs
        ..color = withA(const Color(0xFFFFE6A8), (1 - u).clamp(0.0, 1.0));
      c.drawArc(Rect.fromCenter(center: o, width: r * 1.1, height: r * 2), f.face > 0 ? -1.2 : math.pi - 1.2 + 0, 2.4, false, pt);
    }
    if (m.name == 'yokozunaThunder' && f.sf >= m.startup - 2 && f.sf <= m.startup + m.active + 8) {
      final o = jointScreen(cam, s, player, Jt.c);
      final top = (s.frame ~/ 3);
      for (var b = 0; b < 2; b++) {
        if ((s.frame + b * 3) % 6 > 3) continue;
        var x = o.dx + (b == 0 ? -1 : 1) * (60 + 40 * hash01(top, b)) * rs;
        var y = o.dy - 200 * rs;
        final path = Path()..moveTo(x, y);
        for (var i = 0; i < 6; i++) {
          x += (hash01(top, b * 9 + i) - .5) * 44 * rs + (o.dx - x) * .14;
          y += 36 * rs;
          path.lineTo(x, y);
        }
        pt
          ..strokeWidth = 5 * rs
          ..color = const Color(0x99FFE24A);
        c.drawPath(path, pt);
        pt
          ..strokeWidth = 2 * rs
          ..color = const Color(0xFFFFFFFF);
        c.drawPath(path, pt);
      }
    }
  }
}
