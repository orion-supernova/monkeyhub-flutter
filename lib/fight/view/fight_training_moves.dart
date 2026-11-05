// The training room's brain, with no Flutter in it: the move list of a
// fighter, the inputs that perform each move on the engine, the frame data
// shown for it, and the keep-alive rules of the room. Pure so a test can run
// every move of every fighter through the real engine.

import 'dart:math' as math;

import '../core/core.dart';

/// Where a move sits in the list.
enum TrainGroup { normals, specials, superMove, counters }

/// One performable move.
class TrainMove {
  const TrainMove({
    required this.group,
    required this.moveId,
    required this.move,
    required this.glyph,
    required this.name,
    this.normal,
    this.ex = false,
    this.parent = -1,
  });

  final TrainGroup group;

  /// Index into `CharacterDef.moves` that must start when this is performed.
  final int moveId;
  final MoveDef move;

  /// The input in arcade notation, facing right: `→ S`, `↓ S+H`, `L L H`.
  final String glyph;

  /// Display name from the engine's move name ("Surge Palm"). Empty for a
  /// normal, whose name is a translated label picked by [normal].
  final String name;

  /// `N.*` index of a normal (the screen translates its label).
  final int? normal;
  final bool ex;

  /// For a counter follow-up: the stance move that has to be performed first.
  final int parent;
}

/// "surgePalm" -> "Surge Palm".
String trainingMoveName(String raw) {
  final b = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    final upper = ch.toUpperCase() == ch && ch.toLowerCase() != ch;
    if (i == 0) {
      b.write(ch.toUpperCase());
    } else {
      if (upper) b.write(' ');
      b.write(ch);
    }
  }
  return b.toString();
}

const List<String> _slotGlyph = ['', '→ ', '↓ ', '↑ '];

/// Every move of [c] a player can perform, in list order.
List<TrainMove> trainingMoves(CharacterDef c) {
  final out = <TrainMove>[];
  const normalGlyph = {
    N.standLight: 'L',
    N.standLight2: 'L L',
    N.standFinisher: 'L L H',
    N.standHeavy: 'H',
    N.crouchLight: '↓ L',
    N.crouchHeavy: '↓ H',
    N.jumpLight: '↑ then L',
    N.jumpHeavy: '↑ then H',
    N.fwdHeavy: '→ H',
    N.throwMove: 'L+H',
  };
  for (var n = 0; n < N.count; n++) {
    out.add(TrainMove(group: TrainGroup.normals, moveId: n, move: c.moves[n], glyph: normalGlyph[n]!, name: '', normal: n));
  }
  for (var slot = 0; slot < c.specials.length; slot++) {
    final id = c.specials[slot];
    out.add(TrainMove(
      group: TrainGroup.specials,
      moveId: id,
      move: c.moves[id],
      glyph: '${_slotGlyph[slot]}S',
      name: trainingMoveName(c.moves[id].name),
    ));
  }
  for (var slot = 0; slot < c.exSpecials.length; slot++) {
    final id = c.exSpecials[slot];
    if (id < 0) continue;
    out.add(TrainMove(
      group: TrainGroup.specials,
      moveId: id,
      move: c.moves[id],
      glyph: '${_slotGlyph[slot]}S+H',
      name: trainingMoveName(c.moves[id].name),
      ex: true,
    ));
  }
  out.add(TrainMove(
    group: TrainGroup.superMove,
    moveId: c.superMove,
    move: c.moves[c.superMove],
    glyph: 'SUPER',
    name: trainingMoveName(c.moves[c.superMove].name),
  ));
  // Everything else is reached from another move: a counter stance's answer.
  final listed = {for (final m in out) m.moveId};
  for (var i = N.count; i < c.moves.length; i++) {
    if (listed.contains(i)) continue;
    var parent = -1;
    for (var j = 0; j < c.moves.length && parent < 0; j++) {
      if (c.moves[j].counterMove == i) parent = j;
    }
    if (parent < 0) {
      for (var j = 0; j < c.moves.length && parent < 0; j++) {
        if (c.moves[j].chainInto == i) parent = j;
      }
    }
    final from = out.where((m) => m.moveId == parent).firstOrNull;
    out.add(TrainMove(
      group: TrainGroup.counters,
      moveId: i,
      move: c.moves[i],
      glyph: from?.glyph ?? '',
      name: trainingMoveName(c.moves[i].name),
      ex: from?.ex ?? false,
      parent: parent,
    ));
  }
  return out;
}

// ---------------------------------------------------------------- the room

/// Training rules, applied after every step: nobody dies, P1 never runs out
/// of meter, the round clock is frozen and the match never leaves the fight.
void trainingKeepAlive(FightState s) {
  s.p[0].health = s.chars[0].maxHealth;
  s.p[1].health = s.chars[1].maxHealth;
  s.p[0].meter = meterMax;
  s.timer = roundFrames;
  s.timeOver = false;
  s.phase = Phase.fight;
  s.phaseTimer = 0;
}

/// A fresh room: the same fighter on both sides (the dummy wears the mirror
/// outfit), no intro. [dist] is the gap between their origins in engine units
/// (null = the normal round-start gap). [frame] keeps the render clock running
/// across resets.
FightState trainingState(CharacterDef c, {int? dist, int frame = 0}) {
  final s = FightState.initial(seed: 7, p1: c, p2: c);
  s.frame = frame;
  if (dist != null) {
    s.p[0].x = stageCenter - dist ~/ 2;
    s.p[1].x = stageCenter - dist ~/ 2 + dist;
  }
  trainingKeepAlive(s);
  return s;
}

int _travel(MoveDef m) {
  final steps = [...m.steps]..sort((a, b) => a.frame.compareTo(b.frame));
  var vx = 0, sum = 0, k = 0;
  for (var f = 0; f < m.total; f++) {
    while (k < steps.length && steps[k].frame <= f) {
      if (steps[k].vx != null) vx = steps[k].vx!;
      k++;
    }
    sum += vx;
  }
  return sum;
}

/// Gap between the fighters' origins that lets [m] connect: projectiles from
/// range, traps under the dummy, grabs and normals close, rushes from a step
/// back.
int trainingDistance(CharacterDef c, MoveDef m) {
  final push = c.pushHalf * 2;
  if (m.windows.isEmpty) {
    if (m.projectiles.isNotEmpty) return 36000;
    if (m.traps.isNotEmpty) return math.max(push + 800, m.traps.first.x);
    return push + 3000;
  }
  if (m.grab) return m.cls == MoveClass.system ? math.min(push + 800, throwRange) : push + 800;
  var reach = 0;
  for (final w in m.windows) {
    reach = math.max(reach, w.box.x + w.box.w);
  }
  if (m.airborne && m.cls == MoveClass.normal) return push + 4000;
  if (_travel(m).abs() > 3000) return (reach + 2500).clamp(push + 1200, 16000).toInt();
  return (push + 1500).clamp(0, reach + 2500).toInt();
}

// ---------------------------------------------------------------- scripts

enum _When { now, contact, falling }

class _Beat {
  const _Beat(this.bits, [this.when = _When.now, this.after = -1]);
  final int bits;
  final _When when;
  final int after; // the move id that has to be playing for [_When.contact]
}

/// The inputs that perform one [TrainMove], frame by frame. Buttons are
/// single-frame pulses (the engine reads edges), and a chain or a jump button
/// waits for the right moment instead of guessing a frame count, so it works
/// at any speed and for every fighter.
class TrainingScript {
  TrainingScript._(this.dist, this._beats, this._poke);

  final int dist;
  final List<_Beat> _beats;
  final int _poke; // frame the dummy throws a light (counter stances), -1 = never
  int _i = 0, _waited = 0;
  bool _released = true;
  int _frame = 0;

  /// P1's input for the next step.
  int p1(FightState s) {
    _frame++;
    if (_i >= _beats.length) return 0;
    if (!_released) {
      _released = true;
      return 0;
    }
    final b = _beats[_i];
    final p = s.p[0];
    var ready = switch (b.when) {
      _When.now => true,
      _When.contact => p.state == St.move && p.moveId == b.after && p.contact != 0,
      _When.falling => p.state == St.jump && p.vy < 0 && p.y <= 15500,
    };
    if (!ready && ++_waited > 60) ready = true; // never wedge on a whiff
    if (!ready) return 0;
    _i++;
    _waited = 0;
    _released = false;
    return b.bits;
  }

  /// The dummy's input: nothing, except to answer a counter stance.
  int p2(FightState s) => _poke >= 0 && _frame - 1 == _poke ? Inp.light : 0;

  /// All presses made.
  bool get done => _i >= _beats.length;
}

/// The script that performs [m] for fighter [c] (P1 faces right: `Inp.right`
/// is toward the dummy).
TrainingScript trainingScript(CharacterDef c, TrainMove m) {
  final key = c.id * 1000 + m.moveId + (m.group == TrainGroup.counters ? 500 : 0);
  var dist = _distCache[key];
  if (dist == null) {
    dist = _findDistance(c, m);
    _distCache[key] = dist;
  }
  return _build(c, m, dist);
}

final Map<int, int> _distCache = {};

bool _connects(FightState s) {
  final d = s.p[1];
  return d.comboHits > 0 ||
      d.slow > 0 ||
      d.state == St.hitstun ||
      d.state == St.airstun ||
      d.state == St.grabbed ||
      d.state == St.blockstun ||
      d.state == St.down;
}

/// Where this move connects: the rule-of-thumb gap first, then a sweep, each
/// tried on a scratch copy of the room. Counter follow-ups keep their fixed gap.
int _findDistance(CharacterDef c, TrainMove m) {
  final guess = trainingDistance(c, m.move);
  if (m.group == TrainGroup.counters) return guess;
  final push = c.pushHalf * 2;
  final tries = <int>[guess, for (var d = push + 800; d <= 26000; d += 1500) d];
  for (final d in tries) {
    final script = _build(c, m, d);
    final s = trainingState(c, dist: d);
    for (var f = 0; f < 110; f++) {
      step(s, script.p1(s), script.p2(s));
      trainingKeepAlive(s);
      if (_connects(s)) return d;
    }
  }
  return guess;
}

TrainingScript _build(CharacterDef c, TrainMove m, int dist) {
  const fwd = Inp.right;
  switch (m.group) {
    case TrainGroup.normals:
      switch (m.normal!) {
        case N.standLight:
          return TrainingScript._(dist, const [_Beat(Inp.light)], -1);
        case N.standLight2:
          return TrainingScript._(dist, const [_Beat(Inp.light), _Beat(Inp.light, _When.contact, N.standLight)], -1);
        case N.standFinisher:
          return TrainingScript._(
            dist,
            const [_Beat(Inp.light), _Beat(Inp.light, _When.contact, N.standLight), _Beat(Inp.heavy, _When.contact, N.standLight2)],
            -1,
          );
        case N.standHeavy:
          return TrainingScript._(dist, const [_Beat(Inp.heavy)], -1);
        case N.crouchLight:
          return TrainingScript._(dist, const [_Beat(Inp.down | Inp.light)], -1);
        case N.crouchHeavy:
          return TrainingScript._(dist, const [_Beat(Inp.down | Inp.heavy)], -1);
        case N.jumpLight:
          return TrainingScript._(dist, const [_Beat(Inp.up | fwd), _Beat(Inp.light, _When.falling)], -1);
        case N.jumpHeavy:
          return TrainingScript._(dist, const [_Beat(Inp.up | fwd), _Beat(Inp.heavy, _When.falling)], -1);
        case N.fwdHeavy:
          return TrainingScript._(dist, const [_Beat(fwd | Inp.heavy)], -1);
        default: // throw
          return TrainingScript._(dist, const [_Beat(Inp.light | Inp.heavy)], -1);
      }
    case TrainGroup.specials:
      return TrainingScript._(dist, [_Beat(_specialBits(c, m.moveId))], -1);
    case TrainGroup.superMove:
      return TrainingScript._(dist, const [_Beat(Inp.superBtn)], -1);
    case TrainGroup.counters:
      final stance = c.moves[m.parent];
      final pd = dist;
      // Take the stance, then have the dummy poke into it halfway through.
      final at = stance.counterStart >= 0 ? stance.counterStart : 4;
      return TrainingScript._(
        math.min(pd, c.pushHalf * 2 + 1500),
        [_Beat(_specialBits(c, m.parent))],
        math.max(0, at - 3),
      );
  }
}

/// Direction + Special (+ Heavy for an EX) that selects move [id].
int _specialBits(CharacterDef c, int id) {
  const dirs = [0, Inp.right, Inp.down, Inp.up];
  for (var slot = 0; slot < c.specials.length; slot++) {
    if (c.specials[slot] == id) return dirs[slot] | Inp.special;
    if (c.exSpecials[slot] == id) return dirs[slot] | Inp.special | Inp.heavy;
  }
  return Inp.special;
}

// ---------------------------------------------------------------- frame data

enum TrainFlagKind {
  knockdown,
  launch,
  wallBounce,
  groundBounce,
  projectile,
  grab,
  armor,
  invulnerable,
  invStrike,
  invThrow,
  invProjectile,
  counter,
  trap,
}

/// A property chip; [from]..[to] are the frames it covers (-1 = n/a).
class TrainFlag {
  const TrainFlag(this.kind, [this.from = -1, this.to = -1]);
  final TrainFlagKind kind;
  final int from, to;
}

class TrainFrameData {
  const TrainFrameData({
    required this.startup,
    required this.active,
    required this.recovery,
    required this.damage,
    required this.hits,
    required this.height,
    required this.flags,
  });
  final int startup, active, recovery, damage, hits;
  final BlockHeight height;
  final List<TrainFlag> flags;
  int get total => startup + active + recovery;
  bool get hitsAnything => damage > 0;
}

TrainFrameData trainingFrameData(CharacterDef c, MoveDef m) {
  var damage = 0, hits = m.windows.length;
  for (final w in m.windows) {
    damage += w.damage >= 0 ? w.damage : m.damage;
  }
  var height = m.height;
  var knockdown = m.knockdown;
  for (var i = 0; i < m.projectiles.length; i++) {
    final pd = c.projectiles[m.projectiles[i].proj];
    damage += pd.damage * pd.hits;
    hits += pd.hits;
    if (m.windows.isEmpty && i == 0) height = pd.height;
    knockdown = knockdown || pd.knockdown;
  }
  for (final t in m.traps) {
    final td = c.traps[t.trap];
    damage += td.damage;
    if (td.damage > 0) hits++;
  }
  if (m.windows.isEmpty && m.projectiles.isEmpty && m.traps.isEmpty) height = m.height;
  if (m.grab) damage = m.damage;
  final flags = <TrainFlag>[
    if (knockdown) const TrainFlag(TrainFlagKind.knockdown),
    if (m.launch > 0) const TrainFlag(TrainFlagKind.launch),
    if (m.wallBounce) const TrainFlag(TrainFlagKind.wallBounce),
    if (m.groundBounce) const TrainFlag(TrainFlagKind.groundBounce),
    if (m.projectiles.isNotEmpty) const TrainFlag(TrainFlagKind.projectile),
    if (m.grab) const TrainFlag(TrainFlagKind.grab),
    if (m.traps.isNotEmpty) const TrainFlag(TrainFlagKind.trap),
    if (m.counterMove >= 0) TrainFlag(TrainFlagKind.counter, m.counterStart, m.counterEnd - 1),
    if (m.armorHits > 0) TrainFlag(TrainFlagKind.armor, m.armorStart, m.armorEnd - 1),
    for (final v in m.invuln)
      TrainFlag(
        v.mask == Inv.all
            ? TrainFlagKind.invulnerable
            : (v.mask & Inv.strike) != 0
            ? TrainFlagKind.invStrike
            : (v.mask & Inv.throwing) != 0
            ? TrainFlagKind.invThrow
            : TrainFlagKind.invProjectile,
        v.start,
        v.end - 1,
      ),
  ];
  return TrainFrameData(
    startup: m.startup,
    active: m.active,
    recovery: m.recovery,
    damage: damage,
    hits: hits,
    height: height,
    flags: flags,
  );
}

// ---------------------------------------------------------------- boxes

/// A box in engine units: left, right, bottom, top.
class TrainRect {
  const TrainRect(this.l, this.r, this.b, this.t);
  final int l, r, b, t;
}

TrainRect _rectOf(Fighter f, Box bx) {
  int l, r;
  if (f.face == 1) {
    l = f.x + bx.x;
    r = l + bx.w;
  } else {
    r = f.x - bx.x;
    l = r - bx.w;
  }
  final b = f.y + bx.y;
  return TrainRect(l, r, b, b + bx.h);
}

/// The boxes the engine tests for fighter [i] right now (the same choice the
/// step makes: a move's own hurtboxes, else air / crouch / stand).
class TrainBoxes {
  TrainBoxes(this.hurt, this.pushbox, this.activeHit, this.pendingHit);
  final List<TrainRect> hurt;
  final TrainRect pushbox;
  final List<TrainRect> activeHit;

  /// Hit windows of the current move that are not live this frame.
  final List<TrainRect> pendingHit;
}

TrainBoxes trainingBoxes(FightState s, int i) {
  final f = s.p[i];
  final c = s.chars[i];
  List<Box> hurt;
  final m = f.state == St.move && f.moveId >= 0 ? c.moves[f.moveId] : null;
  if (m?.hurt != null) {
    hurt = m!.hurt!;
  } else if (!f.grounded) {
    hurt = c.airHurt;
  } else if (f.state == St.crouch || (f.state == St.blockstun && f.crouchBlock)) {
    hurt = c.crouchHurt;
  } else if (m != null && m.pose == Pose.crouch) {
    hurt = c.crouchHurt;
  } else {
    hurt = c.standHurt;
  }
  final active = <TrainRect>[], pending = <TrainRect>[];
  if (m != null) {
    for (final w in m.windows) {
      (f.sf >= w.start && f.sf < w.end ? active : pending).add(_rectOf(f, w.box));
    }
  }
  return TrainBoxes(
    [for (final b in hurt) _rectOf(f, b)],
    TrainRect(f.x - c.pushHalf, f.x + c.pushHalf, f.y, f.y + pushBoxHeight),
    active,
    pending,
  );
}

/// Projectile hit rectangles (engine units).
List<TrainRect> trainingProjectileRects(FightState s) => [
  for (final e in s.projectiles)
    TrainRect(
      e.x - s.chars[e.owner].projectiles[e.proj].w ~/ 2,
      e.x + s.chars[e.owner].projectiles[e.proj].w ~/ 2,
      e.y,
      e.y + s.chars[e.owner].projectiles[e.proj].h,
    ),
];

/// Trap rectangles (engine units).
List<TrainRect> trainingTrapRects(FightState s) => [
  for (final t in s.traps)
    TrainRect(
      t.x - s.chars[t.owner].traps[t.trap].w ~/ 2,
      t.x + s.chars[t.owner].traps[t.trap].w ~/ 2,
      0,
      s.chars[t.owner].traps[t.trap].h,
    ),
];
