import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/characters/wave2a.dart';
import 'package:monkeyhub/fight/core/core.dart';

import 'determinism_test.dart' show randomLog, twoPeers;
import 'fight_test_utils.dart';

// What a special is expected to do against a standing Kai.
enum K { hit, proj, trap, counter, evade, feint, tele }

class Spec {
  final int slot;
  final K kind;
  final int dist;
  const Spec(this.slot, this.kind, this.dist);
}

const Map<String, List<Spec>> _specs = {
  'bruno': [Spec(0, K.counter, 9000), Spec(1, K.hit, 9000), Spec(2, K.hit, 9000), Spec(3, K.hit, 9000)],
  'sage': [Spec(0, K.proj, 25000), Spec(1, K.proj, 25000), Spec(2, K.evade, 9000), Spec(3, K.hit, 9000)],
  'razz': [Spec(0, K.hit, 9000), Spec(1, K.hit, 9000), Spec(2, K.hit, 9000), Spec(3, K.hit, 9000)],
  'pip': [Spec(0, K.proj, 25000), Spec(1, K.hit, 9000), Spec(2, K.hit, 9000), Spec(3, K.hit, 7000)],
  'ryoko': [Spec(0, K.hit, 9000), Spec(1, K.hit, 9000), Spec(2, K.hit, 9000), Spec(3, K.hit, 9000)],
  'bao': [Spec(0, K.counter, 9000), Spec(1, K.hit, 9000), Spec(2, K.hit, 9000), Spec(3, K.hit, 9000)],
  'vex': [Spec(0, K.proj, 15000), Spec(1, K.feint, 9000), Spec(2, K.trap, 11000), Spec(3, K.tele, 9000)],
  'gale': [Spec(0, K.proj, 25000), Spec(1, K.hit, 9000), Spec(2, K.hit, 9000), Spec(3, K.hit, 16000)],
};

const Map<String, int> _superDist = {'sage': 25000};

int _dirBits(int slot) => slot == Slot.forward ? Inp.right : (slot == Slot.down ? Inp.down : (slot == Slot.up ? Inp.up : 0));

class Probe {
  bool sawMove = false, sawProj = false, sawTrap = false, sawCounter = false, sawFollow = false;
  int damage = 0, startX = 0, minX = 1 << 30, endX = 0;
  int meter = 0;
}

/// Runs one move of [c] (by input [bits]) against a standing Kai and reports what happened.
Probe probe(CharacterDef c, int expectId, int bits, int dist,
    {int frames = 150, InputFn? in1, int followId = -1}) {
  final s = duel(c, kai, dist: dist);
  s.p[0].meter = meterMax;
  final pr = Probe()..startX = s.p[0].x;
  final input = tapAt(bits);
  final dummy = in1 ?? none;
  for (var f = 0; f < frames; f++) {
    step(s, input(f, s), dummy(f, s));
    final p = s.p[0];
    if (p.state == St.move && p.moveId == expectId) pr.sawMove = true;
    if (p.state == St.move && followId >= 0 && p.moveId == followId) pr.sawFollow = true;
    if (s.projectiles.any((e) => e.owner == 0)) pr.sawProj = true;
    for (final e in s.events) {
      if (e.kind == Ev.projectileSpawn && e.player == 0 && e.frame == s.frame) pr.sawProj = true;
    }
    if (s.traps.any((t) => t.owner == 0)) pr.sawTrap = true;
    for (final e in s.events) {
      if (e.kind == Ev.counterTrigger && e.frame == s.frame) pr.sawCounter = true;
    }
    if (p.x < pr.minX) pr.minX = p.x;
  }
  pr.damage = kai.maxHealth - s.p[1].health;
  pr.endX = s.p[0].x;
  pr.meter = s.p[0].meter;
  return pr;
}

void _checkSpec(CharacterDef c, Spec sp, bool ex) {
  final id = ex ? c.exSpecials[sp.slot] : c.specials[sp.slot];
  final bits = _dirBits(sp.slot) | Inp.special | (ex ? Inp.heavy : 0);
  final label = '${c.name} ${c.moves[id].name}${ex ? ' EX' : ''}';
  switch (sp.kind) {
    case K.hit:
    case K.tele:
      final pr = probe(c, id, bits, sp.dist);
      expect(pr.sawMove, isTrue, reason: '$label starts');
      expect(pr.damage, greaterThan(0), reason: '$label hits a standing dummy');
      break;
    case K.proj:
      final pr = probe(c, id, bits, sp.dist);
      expect(pr.sawMove, isTrue, reason: '$label starts');
      expect(pr.sawProj, isTrue, reason: '$label spawns a projectile');
      expect(pr.damage, greaterThan(0), reason: '$label projectile hits a standing dummy');
      break;
    case K.trap:
      final pr = probe(c, id, bits, sp.dist, frames: 160);
      expect(pr.sawTrap, isTrue, reason: '$label places a trap');
      expect(pr.damage, greaterThan(0), reason: '$label trap trips the dummy');
      break;
    case K.counter:
      // Dummy swings a stand light at many offsets; at least one lands inside the counter stance.
      final move = c.moves[id];
      var triggered = false;
      for (var off = 0; off < 30 && !triggered; off++) {
        final pr = probe(c, id, bits, sp.dist, frames: 90, in1: (f, s) => (f == off ? Inp.light : 0), followId: move.counterMove);
        if (pr.sawCounter) {
          triggered = true;
          expect(pr.sawFollow, isTrue, reason: '$label answers with its counter move');
          expect(pr.damage, greaterThan(0), reason: '$label counter hits');
        }
      }
      expect(triggered, isTrue, reason: '$label counter triggers');
      break;
    case K.evade:
      final pr = probe(c, id, bits, sp.dist);
      expect(pr.sawMove, isTrue, reason: '$label starts');
      expect(pr.minX, lessThan(pr.startX), reason: '$label hops back');
      break;
    case K.feint:
      final pr = probe(c, id, bits, sp.dist);
      expect(pr.sawMove, isTrue, reason: '$label starts');
      expect(pr.damage, 0, reason: '$label is a pure feint');
      break;
  }
}

void main() {
  for (final c in wave2a) {
    group(c.name, () {
      test('data sanity: ids, slots, move tables', () {
        expect(wave2a.indexOf(c) + 4, c.id);
        expect(c.specials.length, 4);
        expect(c.exSpecials.length, 4);
        for (final id in [...c.specials, ...c.exSpecials, c.superMove]) {
          expect(id, inInclusiveRange(N.count, c.moves.length - 1));
        }
        for (final m in c.moves) {
          if (m.counterMove >= 0) expect(m.counterMove, lessThan(c.moves.length));
          for (final ps in m.projectiles) {
            expect(ps.proj, lessThan(c.projectiles.length));
            expect(ps.frame, lessThan(m.total), reason: '${m.name} projectile spawns inside the move');
          }
          for (final ts in m.traps) {
            expect(ts.trap, lessThan(c.traps.length));
          }
          for (final w in m.windows) {
            expect(w.end, lessThanOrEqualTo(m.total + 1), reason: '${m.name} window inside the move');
          }
        }
      });

      test('specials and EX variants come out and do their job', () {
        for (final sp in _specs[c.key]!) {
          _checkSpec(c, sp, false);
          _checkSpec(c, sp, true);
        }
      });

      test('super connects', () {
        final pr = probe(c, c.superMove, Inp.superBtn, _superDist[c.key] ?? 9000);
        expect(pr.sawMove, isTrue);
        expect(pr.damage, greaterThan(c.key == 'sage' ? 60 : 100));
      });

      test('determinism: same inputs give the same checksum twice', () {
        final l0 = randomLog(31 + c.id, 700), l1 = randomLog(57 + c.id, 700);
        int run() {
          final s = FightState.initial(seed: 5 + c.id, p1: c, p2: roster[c.id % 4]);
          s.p[0].meter = meterMax;
          for (var f = 0; f < 700; f++) {
            step(s, l0[f], l1[f]);
          }
          return s.checksum();
        }

        expect(run(), run());
      });

      test('rollback equals a straight run (two existing opponents and the mirror)', () {
        var k = 0;
        for (final o in [roster[c.id % 4], roster[(c.id + 1) % 4], c]) {
          const total = 360;
          const delay = 2;
          final seed = 300 + c.id * 5 + k++;
          final l0 = randomLog(seed * 2 + 1, total + 8), l1 = randomLog(seed * 2 + 2, total + 8);
          final s = FightState.initial(seed: seed, p1: c, p2: o);
          for (var f = 0; f < total; f++) {
            step(s, f < delay ? 0 : l0[f - delay], f < delay ? 0 : l1[f - delay]);
          }
          final r = twoPeers(c, o, seed, total, delay: delay);
          expect(r.c0, s.checksum(), reason: '${c.name} vs ${o.name} peer 0');
          expect(r.c1, s.checksum(), reason: '${c.name} vs ${o.name} peer 1');
          expect(r.desyncs, 0);
        }
      });

      test('bot vs bot matches finish', () {
        void match(CharacterDef a, CharacterDef b, int seed) {
          final s = FightState.initial(seed: seed, p1: a, p2: b);
          final b0 = FightBot(seed: seed + 3, level: BotLevel.hard);
          final b1 = FightBot(seed: seed + 9, level: BotLevel.normal);
          var f = 0;
          while (s.phase != Phase.over && f++ < 3 * (introFrames + roundFrames + koFrames) + 100) {
            step(s, b0.decide(s, 0), b1.decide(s, 1));
          }
          expect(s.phase, Phase.over, reason: '${a.name} vs ${b.name}');
        }

        match(c, tank, 11 + c.id);
        match(kai, c, 12 + c.id);
        match(c, c, 13 + c.id);
      });
    });
  }

  group('character-specific', () {
    test('RAZZ showboat builds meter on contact', () {
      final pr = probe(razz, razz.specials[0], Inp.special, 9000);
      // probe() starts with a full bar; only the +260 gain is visible if it was not capped.
      expect(pr.meter, meterMax);
      final s = duel(razz, kai, dist: 9000);
      play(s, 40, in0: tapAt(Inp.special));
      expect(s.p[0].meter, greaterThanOrEqualTo(260));
    });

    test('VEX fakeOut cancels early into another special', () {
      final s = duel(vex, kai, dist: 20000);
      var decoyFrame = -1;
      for (var f = 0; f < 60; f++) {
        step(s, f == 0 ? (Inp.right | Inp.special) : (f == 9 ? Inp.special : 0), 0);
        if (decoyFrame < 0 && s.p[0].state == St.move && s.p[0].moveId == vex.specials[0]) decoyFrame = f;
      }
      expect(vex.moves[vex.specials[1]].total, 14);
      expect(decoyFrame, inInclusiveRange(1, 11), reason: 'cancelled before the fake-out would have ended');
    });

    test('VEX mirageStep lands behind the opponent', () {
      final s = duel(vex, kai, dist: 9000);
      final ox = s.p[1].x;
      play(s, 20, in0: tapAt(Inp.up | Inp.special));
      expect(s.p[0].x, greaterThan(ox), reason: 'teleported to the far side');
      expect(s.p[0].face, -1);
    });

    test('BAO sway: a strike during the dodge frames whiffs', () {
      expect(bao.moves[bao.specials[0]].invAt(5) & Inv.strike, Inv.strike);
      var dodged = false;
      for (var off = 0; off < 14 && !dodged; off++) {
        final s = duel(bao, kai, dist: 9000);
        play(s, 40, in0: tapAt(Inp.special), in1: (f, st) => f == off ? Inp.light : 0);
        if (s.p[0].health == bao.maxHealth && !sawEvent(s, Ev.counterTrigger)) dodged = true;
      }
      expect(dodged, isTrue);
    });

    test('SAGE coconut is low, mango arcs down', () {
      expect(sage.projectiles[3].height, BlockHeight.low);
      expect(sage.projectiles[0].height, BlockHeight.mid);
      expect(sage.projectiles[0].vy, lessThan(0));
    });

    test('GALE glide stays level during the glide frames', () {
      final s = duel(gale, kai, dist: 40000);
      final ys = <int>[];
      for (var f = 0; f < 22; f++) {
        step(s, f == 0 ? (Inp.right | Inp.special) : 0, 0);
        ys.add(s.p[0].y);
      }
      expect(ys[9], greaterThan(0));
      expect(ys[12], ys[10], reason: 'level flight');
      expect(ys[16], ys[10], reason: 'level flight');
    });
  });

  group('air mobility', () {
    int apex(CharacterDef c, InputFn in0, {int frames = 90}) {
      final s = duel(c, kai, dist: 60000);
      var top = 0;
      for (var f = 0; f < frames; f++) {
        step(s, in0(f, s), 0);
        if (s.p[0].y > top) top = s.p[0].y;
      }
      return top;
    }

    // Up pressed at 0, released, pressed again at [second].
    InputFn upUp(int second) => (f, s) => (f == 0 || f == second) ? Inp.up : 0;

    test('PIP double jump: a second fresh up press adds height; holding up does not', () {
      final single = apex(pip, tapAt(Inp.up));
      final doubleJump = apex(pip, upUp(20));
      expect(doubleJump, greaterThan(single + 5000));
      final held = apex(pip, hold(Inp.up), frames: 40);
      final singleShort = apex(pip, tapAt(Inp.up), frames: 40);
      expect(held, singleShort);
    });

    test('PIP gets exactly one air jump per jump, and it resets on landing', () {
      final t = duel(pip, kai, dist: 60000);
      var boosts = 0;
      var lastVy = 0;
      for (var f = 0; f < 35; f++) {
        step(t, (f == 0 || f == 8 || f == 14 || f == 20) ? Inp.up : 0, 0);
        if (t.p[0].airJumpsUsed > lastVy) boosts++;
        lastVy = t.p[0].airJumpsUsed;
      }
      expect(boosts, 1);
      expect(t.p[0].airJumpsUsed, 1);
      play(t, 120);
      expect(t.p[0].y, 0);
      expect(t.p[0].airJumpsUsed, 0, reason: 'reset after landing');
      // A fresh jump gets its air jump again.
      final before = t.p[0].airJumpsUsed;
      for (var f = 0; f < 30; f++) {
        step(t, (f == 0 || f == 12) ? Inp.up : 0, 0);
      }
      expect(before, 0);
      expect(t.p[0].airJumpsUsed, 1);
    });

    test('GALE air dash: double-tap forward in the air dashes level, once per jump', () {
      final s = duel(gale, kai, dist: 60000);
      final xs = <int>[], ys = <int>[];
      for (var f = 0; f < 60; f++) {
        final inp = f == 0 ? Inp.up : (f == 14 || f == 16 ? Inp.right : 0);
        step(s, inp, 0);
        xs.add(s.p[0].x);
        ys.add(s.p[0].y);
      }
      expect(ys[20], ys[22], reason: 'level while dashing');
      expect(xs[22] - xs[20], gale.airDashSpeed * 2);
      final t = duel(gale, kai, dist: 60000);
      var dashes = 0;
      var prevT = 0;
      for (var f = 0; f < 70; f++) {
        final inp = f == 0 ? Inp.up : ((f == 14 || f == 16 || f == 34 || f == 36) ? Inp.right : 0);
        step(t, inp, 0);
        if (t.p[0].airDashT > prevT) dashes++;
        prevT = t.p[0].airDashT;
      }
      expect(dashes, 1);
    });

    test('GALE air dash backward moves away, and an air attack ends the dash', () {
      final s = duel(gale, kai, dist: 60000);
      final x0 = s.p[0].x;
      for (var f = 0; f < 40; f++) {
        step(s, f == 0 ? Inp.up : (f == 14 || f == 16 ? Inp.left : 0), 0);
      }
      expect(s.p[0].x, lessThan(x0));
      final t = duel(gale, kai, dist: 60000);
      for (var f = 0; f < 20; f++) {
        step(t, f == 0 ? Inp.up : (f == 12 || f == 14 ? Inp.right : (f == 17 ? Inp.light : 0)), 0);
      }
      expect(t.p[0].airDashT, 0);
      expect(t.p[0].state, St.move);
    });

    test('older characters are unaffected: no air jump, no air dash', () {
      for (final c in starters) {
        expect(c.airJumps, 0);
        expect(c.airDashFrames, 0);
      }
      final single = apex(kai, tapAt(Inp.up));
      expect(apex(kai, upUp(20)), single);
      final s = duel(kai, kai, dist: 60000);
      var maxVx = 0;
      for (var f = 0; f < 40; f++) {
        step(s, f == 0 ? Inp.up : (f == 14 || f == 16 ? Inp.right : 0), 0);
        if (s.p[0].vx.abs() > maxVx) maxVx = s.p[0].vx.abs();
      }
      expect(maxVx, lessThanOrEqualTo(kai.dashSpeed));
      expect(s.p[0].airDashT, 0);
    });

    test('air-mobility state is part of copy() and checksum()', () {
      final s = duel(gale, kai, dist: 60000);
      for (var f = 0; f < 18; f++) {
        step(s, f == 0 ? Inp.up : (f == 14 || f == 16 ? Inp.right : 0), 0);
      }
      expect(s.p[0].airDashT, greaterThan(0));
      final snap = s.copy();
      expect(snap.p[0].airDashT, s.p[0].airDashT);
      expect(snap.p[0].airDashUsed, s.p[0].airDashUsed);
      expect(snap.checksum(), s.checksum());
      final a = s.checksum();
      s.p[0].airJumpsUsed = 1;
      expect(s.checksum(), isNot(a));
    });
  });
}
