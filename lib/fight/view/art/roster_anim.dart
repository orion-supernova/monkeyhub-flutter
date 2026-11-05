// Poses and move animations for MOJO, TANK and NYX. A part of poser.dart so it
// can reuse the key timeline machinery (Key, _strike, _lunge). Key poses are
// the roster lab's (mojoMoves / tankMoves / nyxMoves), timed from each MoveDef
// exactly like KAI's: wind-up through startup, full extension on the first
// active frame, hold through active, ease back through recovery.
part of 'poser.dart';

KPose _rosterPose(FightState s, int player, int sf) {
  final f = s.p[player];
  final def = s.chars[player];
  final id = def.id;
  final I = idleFor(id);
  switch (f.state) {
    case St.idle:
      return rosterIdle(id, s.frame.toDouble());
    case St.walk:
      final ph = (f.x / unitsPerPx) * f.face * .095;
      final w = math.sin(ph);
      final b = rosterIdle(id, s.frame.toDouble());
      return KPose.from(b,
          ft: I.ft + w * .32, bt: I.bt - w * .32, fs: I.fs + math.max(0, -w) * .3, bs: I.bs + math.max(0, w) * .3,
          fu: b.fu - w * .12, bu: b.bu + w * .12);
    case St.move:
      if (f.moveId < 0 || f.moveId >= def.moves.length) return I;
      final m = def.moves[f.moveId];
      return evalKeys(animFor(m, def).keys, sf.toDouble());
    default:
      return rebase(id, _kaiPose(s, player, sf, centre: standCentre(id)));
  }
}

MoveAnim _buildRoster(MoveDef m, CharacterDef def) {
  _curId = def.id;
  try {
    MoveAnim? a;
    switch (def.id) {
      case 1:
        a = _mojoAnim(m);
        break;
      case 2:
        a = _tankAnim(m);
        break;
      case 3:
        a = _nyxAnim(m);
        break;
      default:
        a = castArt[def.id]?.anim(m, def);
    }
    return a ?? _converted(m, def);
  } finally {
    _curId = 0;
  }
}

/// KAI's recipe for [m] re-based onto the character's idle (unknown names and
/// the normals the lab did not redraw).
MoveAnim _converted(MoveDef m, CharacterDef def) {
  final id = def.id, I = idleFor(id);
  final k = _build(m, def);
  return MoveAnim(
      [for (final key in k.keys) Key(key.f, identical(key.p, pIdle) ? I : rebase(id, key.p), key.ease)],
      smear: k.smear, smearA: k.smearA, smearB: k.smearB, storm: false);
}

/// Strictly increasing frames, so a short move never folds its key list back.
List<Key> _mono(List<Key> ks) {
  final out = <Key>[];
  for (final k in ks) {
    final f = out.isEmpty ? k.f : (k.f > out.last.f ? k.f : out.last.f + 1);
    out.add(Key(f, k.p, k.ease));
  }
  return out;
}

// ------------------------------------------------------------------ MOJO

MoveAnim? _mojoAnim(MoveDef m) {
  final I = mojoIdle;
  KPose q(
          {double? lean, double? head, double? fu, double? ff, double? bu, double? bf, double? ft, double? fs,
          double? bt, double? bs, double? rx, double? ry, double? sa, double? sx, double? spin, double? baf, double? blf,
          double? ffa, double? bfa}) =>
      KPose.from(I,
          lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs, rx: rx, ry: ry,
          sa: sa, sx: sx, spin: spin, baf: baf, blf: blf, ffa: ffa, bfa: bfa);
  final s = m.startup, a = m.active, r = m.recovery, t = m.total;
  switch (m.name) {
    case 'standLight':
      final x = _lunge(m, q(fu: 1.45, ff: 1.55, lean: .45, rx: 12, sa: .04), Jt.sTip);
      return MoveAnim(
          _strike(m, q(fu: .35, ff: 2.0, lean: .25, sa: -.15), x,
              hold: KPose.from(x, fu: 1.4, ff: 1.58, lean: .42), idle: I),
          smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
    case 'standLight2':
      final x = _lunge(m, q(fu: 1.3, ff: 1.45, lean: .5, rx: 12, sa: .22, bu: .6, bf: 2.2), Jt.sTip);
      return MoveAnim(
          _strike(m, q(fu: .6, ff: 1.9, lean: .3, sa: .5), x, hold: KPose.from(x, ff: 1.5, lean: .47), idle: I),
          smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
    case 'standHeavy':
      final x = _lunge(m, q(fu: 1.0, ff: 1.3, bu: .9, bf: 1.4, lean: .55, sa: .75, rx: 14), Jt.sTip);
      return MoveAnim(
          _strike(m, q(fu: 2.6, ff: 3.0, bu: 2.4, bf: 2.9, lean: -.05, sa: -2.4, rx: -4), x,
              hold: KPose.from(x, sa: .8, lean: .5), windAt: .65, idle: I),
          smear: Jt.sTip, smearA: s - 4, smearB: s + a + 2);
    case 'crouchLight':
      final x = _lunge(m, rebase(1, pCrouchPunchX, sa: .08), Jt.sTip);
      return MoveAnim(_strike(m, rebase(1, pCrouchPunchW, sa: -.3), x, end: rebase(1, pCrouch, sa: -1.9), idle: I),
          smear: Jt.sTip, smearA: s - 2, smearB: s + a + 1);
    case 'fwdHeavy':
      final x = _lunge(m, q(fu: 1.2, ff: 1.0, bu: .8, bf: .9, lean: .52, sa: .7, rx: 8, baf: 1), Jt.sTip);
      return MoveAnim(
          _strike(m, q(fu: 3.0, ff: 3.1, bu: 2.5, bf: 2.9, lean: -.12, sa: -2.6), x, windAt: .8, idle: I,
              w2: q(fu: 3.1, ff: 3.2, bu: 2.6, bf: 3.0, lean: -.2, sa: -2.7)),
          smear: Jt.sTip, smearA: s - 3, smearB: s + a + 2);
    case 'staffVault':
      final plant = q(lean: .55, rx: 4, sa: .9, ft: 1.0, fs: -.3, bt: -.4, bs: -.6);
      final up = q(lean: .3, rx: 6, sa: 1.35, fu: 1.3, ff: 1.2);
      final tumble = q(lean: -.3, spin: -.5, sa: -1.3, ft: 1.9, fs: 1.6, bt: 1.5, bs: 1.2, fu: 2.2, ff: 2.4);
      final kick = q(lean: -.2, ft: 1.4, fs: 1.85, bt: 1.2, bs: .2, sa: -1.6, fu: 1.4, ff: 1.8);
      final land = q(lean: .4, ft: .95, fs: -.35, bt: .2, bs: -.95);
      return MoveAnim(
          _mono([
            Key(0, I),
            Key(4, plant),
            Key(9, up),
            Key(_mx(10, s - 6), tumble),
            Key(s, kick, 1),
            Key(s + a, kick),
            Key(s + a + _r(r * .4), land),
            Key(t, I),
          ]),
          smear: Jt.fAn, smearA: s - 3, smearB: s + a);
    case 'spinSweep':
      final low = q(lean: .55, ft: 1.1, fs: -.4, bt: .3, bs: -1.0, fu: 1.2, ff: 1.3, bu: 1.0, bf: 1.4, sa: 0, rx: 6);
      final end = m.windows.isEmpty ? s + a : m.windows.last.end;
      const spins = 4 * math.pi;
      return MoveAnim(
          _mono([
            Key(0, I),
            Key(_mx(1, s - 3), KPose.from(low, sa: -.8)),
            Key(s, low, 1),
            Key(end, KPose.from(low, sa: spins, rx: 14), 2),
            Key(end + _r(r * .3), q(lean: .4, rx: 10, sa: spins - 1.2)),
            Key(t, KPose.from(I, sa: spins - 1.8)),
          ]),
          smear: Jt.sTip, smearA: s - 1, smearB: end);
    case 'bananaPeel':
      final sp = m.traps.isNotEmpty ? m.traps.first.frame : s - 1;
      final toss = q(bu: 1.6, bf: 1.25, lean: .32, rx: 4, baf: 1);
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, _r(sp * .5)), q(bu: -.5, bf: .4, lean: .12, baf: 1)),
        Key(sp, toss, 1),
        Key(sp + _r((t - sp) * .45), KPose.from(toss, bu: 1.5, bf: 1.3, lean: .3)),
        Key(t, I),
      ]));
    case 'canopyDive':
      final crouch = q(lean: .35, ft: .95, fs: -.35, bt: .2, bs: -.95);
      final rise = q(lean: .05, fu: 2.6, ff: 2.9, sa: -2.0, ft: .4, fs: .1, bt: .1, bs: -.1);
      final tuck = q(lean: -.1, spin: -.4, ft: 1.8, fs: .3, bt: 1.3, bs: -.2, sa: -2.2, fu: 2.4, ff: 2.8);
      final aim = q(lean: .9, sa: .6, fu: 1.4, ff: 1.3, ft: .4, fs: .5, bt: -.3, bs: .2);
      final dive = q(lean: .8, sa: .55, fu: 1.4, ff: 1.3, ft: .4, fs: .5, bt: -.3, bs: .2);
      return MoveAnim(
          _mono([
            Key(0, I),
            Key(3, crouch),
            Key(8, rise, 1),
            Key(_mx(10, _r(s * .6)), tuck),
            Key(s - 3, aim),
            Key(s, dive, 1),
            Key(s + a, dive),
            Key(s + a + _r(r * .5), q(lean: .5, ft: 1.0, fs: -.35, bt: .25, bs: -.95)),
            Key(t, I),
          ]),
          smear: Jt.sTip, smearA: s - 3, smearB: s + a);
    case 'jungleFury':
      final ws = m.windows;
      final keys = <Key>[Key(0, I), Key(_mx(1, s ~/ 2), q(fu: 2.6, ff: 3.0, bu: 2.4, bf: 2.9, lean: -.05, sa: -2.4))];
      final gap = ws.length > 1 ? ws[1].start - ws[0].start : 4;
      for (var k = 0; k < ws.length; k++) {
        final last = k == ws.length - 1;
        final sw = (const [.14, -.1, .06, -.16, .1, -.04])[k % 6];
        // The staff stabs out (and lengthens) on each hit, then snaps back.
        final stab = last
            ? q(fu: 1.0, ff: 1.3, bu: .9, bf: 1.4, lean: .62, rx: 12, sa: .6, sx: 120)
            : q(fu: 1.5, ff: 1.57, lean: .45 + (k.isEven ? 0 : .05), rx: 10, sa: sw, sx: 62 + 10 * (k % 3));
        keys.add(Key(ws[k].start, stab, 1));
        if (!last) keys.add(Key(ws[k].start + _mx(1, gap ~/ 2), KPose.from(stab, fu: 1.15, ff: 1.45, lean: .38, sx: 14)));
      }
      final tail = ws.isEmpty ? s + a : ws.last.end;
      keys.add(Key(tail + _r(r * .3), q(fu: 1.0, ff: 1.3, bu: .9, bf: 1.4, lean: .5, sa: .7, sx: 40)));
      keys.add(Key(t, I));
      return MoveAnim(_mono(keys), smear: Jt.sTip, smearA: s - 1, smearB: tail);
  }
  return null;
}

// ------------------------------------------------------------------ TANK

MoveAnim? _tankAnim(MoveDef m) {
  final I = tankIdle;
  KPose q(
          {double? lean, double? head, double? fu, double? ff, double? bu, double? bf, double? ft, double? fs,
          double? bt, double? bs, double? rx, double? ry, double? open, double? baf}) =>
      KPose.from(I,
          lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs, rx: rx, ry: ry,
          open: open, baf: baf);
  final s = m.startup, a = m.active, r = m.recovery, t = m.total;
  switch (m.name) {
    case 'standLight':
      final x = _lunge(m, q(fu: 1.5, ff: 1.55, lean: .35, rx: 10, open: 1), Jt.fHa);
      return MoveAnim(
          _strike(m, q(fu: .6, ff: 2.2), x, hold: KPose.from(x, fu: 1.45, lean: .33), idle: I),
          smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
    case 'standLight2':
      final x = _lunge(m, q(bu: 1.5, bf: 1.55, lean: .35, rx: 10, open: 1, baf: 1), Jt.bHa);
      return MoveAnim(
          _strike(m, q(bu: .5, bf: 2.2, baf: 1), x, hold: KPose.from(x, bu: 1.45, lean: .33), idle: I),
          smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
    case 'standHeavy':
      final x = _lunge(m, q(fu: 1.3, ff: 1.0, bu: 1.2, bf: .95, lean: .6, rx: 12), Jt.fHa);
      return MoveAnim(
          _strike(m, q(fu: 2.8, ff: 3.0, bu: 2.7, bf: 3.0, lean: -.12, rx: -4), x,
              hold: KPose.from(x, lean: .55), windAt: .75, idle: I),
          smear: Jt.fHa, smearA: s - 4, smearB: s + a + 2);
    case 'stampede':
      KPose run(bool ph) => q(
          lean: .75, head: .55, fu: .5, ff: .4, bu: .2, bf: .3, ft: ph ? .95 : -.4, fs: ph ? .15 : -.8,
          bt: ph ? -.45 : .9, bs: ph ? -.75 : .1);
      final keys = <Key>[Key(0, I), Key(_mx(1, 3), q(lean: .5, head: .3, ft: .9, fs: -.3, bt: -.5, bs: -.6, fu: .6, ff: 1.2))];
      var ph = true;
      for (var f = 6; f < s + a; f += 5) {
        keys.add(Key(f, run(ph)));
        ph = !ph;
      }
      keys.add(Key(s + a, run(ph)));
      keys.add(Key(s + a + _r(r * .4), q(lean: .35, head: .2)));
      keys.add(Key(t, I));
      return MoveAnim(_mono(keys));
    case 'hornToss':
      final reach = q(fu: 1.5, ff: 1.4, bu: 1.4, bf: 1.3, lean: .4, rx: 10, open: 1);
      final grab = q(fu: 1.45, ff: 1.35, bu: 1.35, bf: 1.25, lean: .45, rx: 14, open: 1);
      final lift = q(fu: 2.7, ff: 2.9, bu: 2.6, bf: 2.8, lean: -.28, rx: 8, head: -.2);
      final toss = q(fu: 1.5, ff: 1.0, bu: 1.4, bf: 1.0, lean: .55, head: .35, rx: 14);
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, s - 3), reach),
        Key(s, grab, 1),
        Key(s + a + 3, grab),
        Key(s + a + 10, lift, 1),
        Key(s + a + 18, toss, 1),
        Key(s + a + 26, toss),
        Key(_mx(t, s + a + 27), I),
      ]));
    case 'earthquake':
      final knee = q(ft: 1.85, fs: .25, bt: -.12, bs: -.15, lean: -.06, fu: 1.7, ff: 1.8, bu: 1.4, bf: 1.5);
      final stomp = q(ft: .62, fs: -.02, lean: .45, fu: .75, ff: 1.05, bu: .6, bf: 1.0);
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, s - 7), knee),
        Key(_mx(2, s - 1), KPose.from(knee, ft: 1.9, lean: -.1)),
        Key(s, stomp, 1),
        Key(s + a, stomp),
        Key(t, I),
      ]));
    case 'rhinoUppercut':
      final crouch = q(lean: .5, ft: 1.0, fs: -.35, bt: .25, bs: -.95, bu: .2, bf: .5);
      final up = q(bu: 3.0, bf: 3.05, lean: -.15, head: -.2, ry: 24, rx: 10, baf: 1, fu: .6, ff: 1.4, ft: .3, fs: .2, bt: -.1, bs: -.2);
      return MoveAnim(
          _mono([
            Key(0, I),
            Key(_mx(1, s - 3), crouch),
            Key(s, up, 1),
            Key(s + a, KPose.from(up, lean: -.18, ry: 28)),
            Key(s + a + _r(r * .4), q(lean: .4, ft: 1.0, fs: -.35, bt: .25, bs: -.95, rx: 6)),
            Key(t, I),
          ]),
          smear: Jt.bHa, smearA: s - 3, smearB: s + a + 1);
    case 'avalancheSlam':
      final reach = q(fu: 1.5, ff: 1.4, bu: 1.4, bf: 1.3, lean: .4, rx: 10, open: 1);
      final grab = q(fu: 1.4, ff: 1.2, bu: 1.3, bf: 1.1, lean: .45, rx: 16, open: 1);
      final crouch = q(lean: .6, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: 1.3, ff: 1.3, bu: 1.2, bf: 1.2, rx: 8, open: 1);
      final leap = q(fu: 2.9, ff: 3.0, bu: 2.8, bf: 2.95, lean: -.2, rx: 6, ry: 36, head: -.25, ft: 1.8, fs: .3, bt: 1.4, bs: -.2);
      final slam = q(fu: 1.1, ff: 1.0, bu: 1.0, bf: .95, lean: .75, rx: 18, head: .3);
      final g = s + a;
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, s - 3), reach),
        Key(s, grab, 1),
        Key(g + 3, grab),
        Key(g + 8, crouch),
        Key(g + 16, leap, 1),
        Key(g + 22, KPose.from(leap, ry: 44)),
        Key(g + 28, slam, 1),
        Key(g + 38, slam),
        Key(_mx(t, g + 39), I),
      ]));
  }
  return null;
}

/// Move frame at which TANK's Earthquake / Avalanche Slam hits the ground, or
/// -1 for other moves. Drives the shockwave.
int tankQuakeFrame(MoveDef m) {
  switch (m.name) {
    case 'earthquake':
      return m.startup;
    case 'avalancheSlam':
      return m.startup + m.active + 28;
  }
  return -1;
}

// ------------------------------------------------------------------ NYX

MoveAnim? _nyxAnim(MoveDef m) {
  final I = nyxIdle;
  KPose q(
          {double? lean, double? head, double? fu, double? ff, double? bu, double? bf, double? rx, double? ry,
          double? open, double? baf, double? al}) =>
      KPose.from(I, lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, rx: rx, ry: ry, open: open, baf: baf, al: al);
  final s = m.startup, a = m.active, r = m.recovery, t = m.total;
  switch (m.name) {
    case 'standLight':
      final x = _lunge(m, q(fu: 1.55, ff: 1.55, lean: .22, rx: 10), Jt.fHa);
      return MoveAnim(_strike(m, q(fu: .4, ff: 2.3), x, hold: KPose.from(x, fu: 1.5, lean: .2), idle: I),
          smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
    case 'standLight2':
      final x = _lunge(m, q(bu: 1.55, bf: 1.55, lean: .22, rx: 10, baf: 1), Jt.bHa);
      return MoveAnim(_strike(m, q(bu: .3, bf: 2.4, baf: 1), x, hold: KPose.from(x, bu: 1.5, lean: .2), idle: I),
          smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
    case 'standHeavy':
      final x = _lunge(m, q(fu: 1.6, ff: 1.5, bu: 1.2, bf: 1.0, lean: .32, rx: 16), Jt.fHa);
      return MoveAnim(
          _strike(m, q(fu: -.2, ff: .6, lean: -.12, rx: -4, bu: 1.0, bf: 1.6), x,
              hold: KPose.from(x, fu: 1.55, lean: .3), windAt: .66, idle: I),
          smear: Jt.fHa, smearA: s - 4, smearB: s + a + 2);
    case 'standFinisher':
      final x = _lunge(m, q(fu: 1.55, ff: 1.55, bu: 1.45, bf: 1.5, baf: 1, lean: .3, rx: 12, open: 1), Jt.fHa);
      return MoveAnim(
          _strike(m, q(fu: .3, ff: 2.4, bu: .2, bf: 2.4, baf: 1, lean: .05, rx: -2, open: 1), x, idle: I),
          smear: Jt.fHa, smearA: s - 3, smearB: s + a + 2);
    case 'moonShard':
      final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
      final ext = q(fu: 1.5, ff: 1.5, bu: 1.3, bf: 1.45, lean: .28, ry: 20);
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, _r(sp * .4)), q(ry: 22)),
        Key(_mx(2, _r(sp * .72)), q(fu: 2.6, ff: 3.0, bu: 2.4, bf: 2.9, lean: -.12, ry: 24)),
        Key(sp, ext, 1),
        Key(sp + _r((t - sp) * .45), KPose.from(ext, fu: 1.45, lean: .25, ry: 18)),
        Key(t, I),
      ]));
    case 'phaseStep':
      // Fades out while the teleport winds up, vanishes on the step, and
      // reappears with a flourish.
      final tp = m.steps.where((e) => e.teleport != 0).map((e) => e.frame).fold<int>(s, (p, e) => e);
      final flourish = q(fu: 1.55, ff: 1.55, lean: .25, rx: 6);
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, tp - 5), q(lean: .2)),
        Key(_mx(2, tp - 1), q(lean: .2, al: 0), 2),
        Key(tp, q(lean: .2, al: 0), 2),
        Key(tp + 5, q(fu: .4, ff: 2.3, al: 1), 2),
        Key(tp + 8, flourish, 1),
        Key(tp + 14, KPose.from(flourish, fu: 1.5, lean: .22)),
        Key(_mx(t, tp + 15), I),
      ]));
    case 'shadowPool':
      final sp = m.traps.isNotEmpty ? m.traps.first.frame : s - 1;
      final dip = q(lean: .75, ry: 6, fu: 1.0, ff: .7, bu: .6, bf: 1.4, head: .2);
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, _r(sp * .65)), dip),
        Key(sp + 4, dip),
        Key(t, I),
      ]));
    case 'eclipse':
      final stance = q(fu: 1.2, ff: 2.95, bu: 1.1, bf: 2.55, baf: 1, lean: -.06, open: 0);
      final ce = m.counterEnd > 0 ? m.counterEnd : s + 16;
      return MoveAnim(_mono([
        Key(0, I),
        Key(_mx(1, s - 1), stance),
        Key(ce, KPose.from(stance, lean: -.08)),
        Key(ce + 3, KPose.from(stance, lean: -.04)),
        Key(_mx(t, ce + 4), I),
      ]));
    case 'eclipseStrike':
      final stance = q(fu: 1.2, ff: 2.95, bu: 1.1, bf: 2.55, baf: 1, lean: -.06, open: 0, al: .1);
      final x = _lunge(m, q(fu: 1.6, ff: 1.55, lean: .32, rx: 8), Jt.fHa);
      return MoveAnim(
          _mono([
            Key(0, stance),
            Key(2, q(fu: .4, ff: 2.3, al: 1), 2),
            Key(s, x, 1),
            Key(s + a, KPose.from(x, fu: 1.55, lean: .3)),
            Key(t, I),
          ]),
          smear: Jt.fHa, smearA: s - 3, smearB: s + a + 1);
    case 'totalEclipse':
      final ws = m.windows;
      final keys = <Key>[
        Key(0, I),
        Key(_mx(1, s ~/ 2), q(ry: 30, fu: 2.9, ff: 3.0, bu: 2.8, bf: 2.95, lean: -.1)),
      ];
      for (var k = 0; k < ws.length; k++) {
        final last = k == ws.length - 1;
        final front = k.isEven;
        keys.add(Key(
            ws[k].start,
            last
                ? q(ry: 26, fu: 1.6, ff: 1.4, bu: 1.5, bf: 1.35, baf: 1, lean: .4, rx: 8, open: 1)
                : (front
                    ? q(ry: 30, fu: 1.7, ff: 1.3, bu: 2.6, bf: 2.9, lean: .2, rx: 4, open: 1)
                    : q(ry: 32, fu: 2.6, ff: 2.9, bu: 1.7, bf: 1.3, baf: 1, lean: .18, rx: 4, open: 1)),
            1));
      }
      final tail = ws.isEmpty ? s + a : ws.last.end;
      keys.add(Key(tail + _r(r * .3), q(ry: 24, fu: 1.4, ff: 1.5, bu: 1.2, bf: 1.4, lean: .3)));
      keys.add(Key(t, I));
      return MoveAnim(_mono(keys), smear: Jt.fHa, smearA: s - 1, smearB: tail);
  }
  return null;
}
