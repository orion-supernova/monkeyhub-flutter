import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/characters/wave2b.dart';
import 'package:monkeyhub/fight/core/core.dart';

import 'determinism_test.dart' show randomLog, straightRun, twoPeers;
import 'fight_test_utils.dart';

// p0 stands left facing right: forward = right, away from p0 = right.
const int _fwd = Inp.right;
const int _away = Inp.right;

int _slotInput(int slot) => switch (slot) {
      Slot.forward => _fwd,
      Slot.down => Inp.down,
      Slot.up => Inp.up,
      _ => 0,
    };

/// Health lost by a standing dummy (Kai) after [c] performs special [slot].
({int dmg, FightState s, Watch w, Set<int> moves}) _fire(CharacterDef c, int slot,
    {bool ex = false, int dist = 9000, int frames = 100, InputFn? dummy, bool sup = false}) {
  final s = duel(c, kai, dist: dist);
  if (ex || sup) s.p[0].meter = meterMax;
  final input = sup ? Inp.superBtn : (_slotInput(slot) | Inp.special | (ex ? Inp.heavy : 0));
  final w = Watch()..observe(s);
  final moves = <int>{};
  for (var f = 0; f < frames; f++) {
    step(s, f == 0 ? input : 0, dummy == null ? 0 : dummy(f, s));
    w.observe(s);
    if (s.p[0].state == St.move) moves.add(s.p[0].moveId);
  }
  return (dmg: kai.maxHealth - s.p[1].health, s: s, w: w, moves: moves);
}

/// Most damage dealt to the dummy over a few spacings.
int _best(CharacterDef c, int slot, {bool ex = false, bool sup = false, List<int> dists = const [5500, 8000, 11000, 15000], InputFn? dummy}) {
  var best = 0;
  for (final d in dists) {
    final r = _fire(c, slot, ex: ex, sup: sup, dist: d, dummy: dummy);
    if (r.dmg > best) best = r.dmg;
  }
  return best;
}

int _match(CharacterDef a, CharacterDef b, int seed) {
  final s = FightState.initial(seed: seed, p1: a, p2: b);
  final b0 = FightBot(seed: seed * 2 + 1, level: BotLevel.hard);
  final b1 = FightBot(seed: seed * 2 + 2, level: BotLevel.normal);
  var frames = 0;
  while (s.phase != Phase.over && frames < 3 * (introFrames + roundFrames + koFrames) + 100) {
    step(s, b0.decide(s, 0), b1.decide(s, 1));
    frames++;
  }
  expect(s.phase, Phase.over, reason: '${a.name} vs ${b.name} must finish');
  return frames;
}

void main() {
  test('wave2b ids, keys and structure', () {
    expect(wave2b.map((c) => c.id), [12, 13, 14, 15, 16, 17, 18, 19]);
    for (final c in wave2b) {
      expect(c.moves.length, greaterThanOrEqualTo(N.count + 9), reason: c.name);
      expect(c.specials.length, 4);
      expect(c.exSpecials.length, 4);
      for (var k = 0; k < 4; k++) {
        expect(c.moves[c.specials[k]].cls, MoveClass.special, reason: '${c.name} slot $k');
        expect(c.moves[c.exSpecials[k]].name, c.moves[c.specials[k]].name, reason: '${c.name} EX keeps the base move name');
      }
      expect(c.moves[c.superMove].cls, MoveClass.superMove);
      expect(c.moves.take(N.count).map((m) => m.name).toList(),
          ['standLight', 'standLight2', 'standFinisher', 'standHeavy', 'crouchLight', 'crouchHeavy', 'jumpLight', 'jumpHeavy', 'fwdHeavy', 'throw']);
      // Every follow-up / projectile index a move refers to must exist.
      for (final m in c.moves) {
        for (final p in m.projectiles) {
          expect(p.proj, lessThan(c.projectiles.length), reason: '${c.name} ${m.name}');
        }
        for (final t in m.traps) {
          expect(t.trap, lessThan(c.traps.length));
        }
        if (m.counterMove >= 0) expect(m.counterMove, lessThan(c.moves.length));
      }
    }
  });

  for (final c in wave2b) {
    group(c.name, () {
      test('determinism: same inputs twice give the same checksum', () {
        final l0 = randomLog(21 + c.id, 600), l1 = randomLog(22 + c.id, 600);
        expect(straightRun(c, kai, 5, l0, l1, 0, 600), straightRun(c, kai, 5, l0, l1, 0, 600));
      });

      test('rollback equivalence vs KAI, TANK and its mirror', () {
        const frames = 300, delay = 2;
        var rollbacks = 0;
        for (final other in [kai, tank, c]) {
          final seed = 300 + c.id * 3 + other.id;
          final l0 = randomLog(seed * 2 + 1, frames + 8), l1 = randomLog(seed * 2 + 2, frames + 8);
          final expected = straightRun(c, other, seed, l0, l1, delay, frames);
          final r = twoPeers(c, other, seed, frames, delay: delay);
          expect(r.c0, expected, reason: '${c.name} vs ${other.name} peer 0');
          expect(r.c1, expected, reason: '${c.name} vs ${other.name} peer 1');
          expect(r.desyncs, 0);
          rollbacks += r.rollbacks;
        }
        expect(rollbacks, greaterThan(0));
      });

      test('bot vs bot: full matches finish (vs KAI and its mirror)', () {
        _match(c, kai, 60 + c.id);
        _match(c, c, 80 + c.id);
      });

      test('every special, EX and the super come out from their input and connect', () {
        for (var slot = 0; slot < 4; slot++) {
          for (final ex in [false, true]) {
            final id = ex ? c.exSpecials[slot] : c.specials[slot];
            final r = _fire(c, slot, ex: ex, dist: 9000, frames: 30);
            expect(r.moves, contains(id), reason: '${c.name} slot $slot ex=$ex must start move $id (${c.moves[id].name})');
            if (ex) expect(r.s.p[0].meter, lessThan(meterMax), reason: 'EX spends a bar');
          }
        }
        final sup = _fire(c, 0, sup: true, frames: 20);
        expect(sup.moves, contains(c.superMove));
        expect(sup.s.p[0].meter, meterMax - superCost);
      });
    });
  }

  group('hits on a standing dummy', () {
    // (character, slot, EX) for every special that is a plain strike / projectile / multi-hit.
    final strikes = <(CharacterDef, int)>[
      (luz, Slot.neutral), (luz, Slot.forward), (luz, Slot.down),
      (dex, Slot.neutral), (dex, Slot.forward), (dex, Slot.down), (dex, Slot.up),
      (hana, Slot.neutral), (hana, Slot.forward), (hana, Slot.up),
      (boom, Slot.neutral), (boom, Slot.forward), (boom, Slot.up),
      (unit7, Slot.neutral), (unit7, Slot.forward), (unit7, Slot.down), (unit7, Slot.up),
      (kage, Slot.forward), (kage, Slot.down), (kage, Slot.up),
      (ember, Slot.neutral), (ember, Slot.forward), (ember, Slot.down), (ember, Slot.up),
      (golem, Slot.neutral), (golem, Slot.forward), (golem, Slot.down),
    ];
    for (final (c, slot) in strikes) {
      test('${c.name} ${c.moves[c.specials[slot]].name} (and EX) hit', () {
        final dists = c.moves[c.specials[slot]].projectiles.isNotEmpty ? const [9000, 14000] : const [5500, 8000, 11000, 15000];
        expect(_best(c, slot, dists: dists), greaterThan(0), reason: 'base');
        expect(_best(c, slot, ex: true, dists: dists), greaterThan(0), reason: 'EX');
      });
    }

    for (final c in wave2b) {
      test('${c.name} ${c.moves[c.superMove].name} super connects', () {
        expect(_best(c, 0, sup: true), greaterThan(100));
      });
    }

    test('multi-hit specials land several hits', () {
      // Each of these is built from >= 3 hits; a 90 dmg floor means more than one connected.
      expect(_best(hana, Slot.neutral, dists: const [8000, 11000]), greaterThan(90));
      expect(_best(boom, Slot.neutral, dists: const [5500, 8000]), greaterThan(90));
      expect(_best(dex, Slot.forward), greaterThan(60));
    });
  });

  group('Luz / Boom / Golem grabs', () {
    final grabs = <(CharacterDef, int, int)>[(luz, Slot.up, 140), (boom, Slot.down, 140), (golem, Slot.up, 160)];
    for (final (c, slot, dmg) in grabs) {
      test('${c.name} ${c.moves[c.specials[slot]].name} ignores block and cannot be teched', () {
        for (final guard in c == luz ? [_away, _away | Inp.down] : [_away | Inp.down]) {
          final got = _best(c, slot, dists: const [6500, 7500, 8500, 9500], dummy: (f, s) => guard);
          expect(got, dmg, reason: 'guard $guard');
        }
        final teched = _best(c, slot, dists: const [6500, 7500, 8500, 9500], dummy: (f, s) => f == 4 ? (Inp.light | Inp.heavy) : 0);
        expect(teched, dmg);
      });
      test('${c.name} grab whiffs on a jumping opponent', () {
        final s = duel(c, kai, dist: 8000);
        s.p[1].y = 30000;
        s.p[1].state = St.jump;
        play(s, 40, in0: tapAt(_slotInput(slot) | Inp.special));
        expect(s.p[1].health, kai.maxHealth);
      });
    }

    test('LUZ hurricanrana leaves her in the air before the grab lands', () {
      final s = duel(luz, kai, dist: 8000);
      var maxY = 0;
      for (var f = 0; f < 30; f++) {
        step(s, f == 0 ? Inp.up | Inp.special : 0, 0);
        if (s.p[0].y > maxY) maxY = s.p[0].y;
      }
      expect(maxY, greaterThan(8000), reason: 'a jumping command grab');
    });

    test('LUZ topRopeSwan is an overhead: crouch-block fails, stand-block holds', () {
      final crouch = _best(luz, 0, sup: true, dummy: (f, s) => _away | Inp.down);
      final stand = _best(luz, 0, sup: true, dummy: (f, s) => _away);
      expect(crouch, greaterThan(150));
      expect(stand, lessThan(60), reason: 'chip only');
    });
  });

  group('counters', () {
    for (final (c, name) in [(hana, 'riposte'), (kage, 'iaido')]) {
      for (final ex in [false, true]) {
        test('${c.name} $name${ex ? ' EX' : ''}: a strike in the window triggers the counter', () {
          final s = duel(c, kai, dist: 9000);
          if (ex) s.p[0].meter = meterMax;
          final w = Watch();
          final input = (c == hana ? Inp.down : 0) | Inp.special | (ex ? Inp.heavy : 0);
          for (var f = 0; f < 70; f++) {
            step(s, f == 0 ? input : 0, f == 5 ? Inp.light : 0);
            w.observe(s);
          }
          expect(w.has(Ev.counterTrigger), isTrue);
          expect(s.p[1].health, lessThan(kai.maxHealth));
          expect(s.p[0].health, c.maxHealth, reason: 'the original strike was nullified');
        });
      }
      test('${c.name} $name without a strike just recovers', () {
        final s = duel(c, kai, dist: 30000);
        play(s, 60, in0: tapAt((c == hana ? Inp.down : 0) | Inp.special));
        expect(s.p[1].health, kai.maxHealth);
        expect(s.p[0].state, St.idle);
      });
    }
  });

  group('armor', () {
    // (character, input, frame the dummy jabs, label)
    final armored = <(CharacterDef, int, int, String)>[
      (boom, _fwd | Inp.special, 11, 'dohyoCharge'),
      (golem, _fwd | Inp.special, 8, 'stoneShoulder'),
      (golem, Inp.special, 12, 'rockThrow'),
      (golem, Inp.down | Inp.special, 10, 'groundSlam'),
      (golem, Inp.up | Inp.special, 3, 'crushGrab'),
      (golem, Inp.heavy, 3, 'standHeavy'),
    ];
    for (final (c, input, jab, label) in armored) {
      test('${c.name} $label absorbs a hit without flinching', () {
        final s = duel(c, kai, dist: 9000);
        final w = Watch();
        for (var f = 0; f < jab + 10; f++) {
          step(s, f == 0 ? input : 0, f == jab ? Inp.light : 0);
          w.observe(s);
        }
        expect(w.has(Ev.armor), isTrue, reason: label);
        expect(s.p[0].state, St.move, reason: 'armor means no hitstun');
        expect(s.p[0].health, c.maxHealth - 15, reason: 'half damage');
      });
    }

    test('golem armor absorbs exactly one hit (a second jab flinches it)', () {
      final s = duel(golem, kai, dist: 8000);
      for (var f = 0; f < 26; f++) {
        step(s, f == 0 ? Inp.special | _fwd : 0, (f == 6 || f == 14) ? Inp.light : 0);
      }
      expect(s.p[0].health, lessThan(golem.maxHealth - 15));
    });
  });

  group('projectiles', () {
    test('UNIT-7 rocket spawns, drifts down and hits from range', () {
      final r = _fire(unit7, Slot.neutral, dist: 30000, frames: 160);
      expect(r.w.has(Ev.projectileSpawn), isTrue);
      expect(r.dmg, greaterThan(0));
      final s = duel(unit7, kai, dist: 90000);
      play(s, 20, in0: tapAt(Inp.special));
      expect(s.projectiles, isNotEmpty);
      final y0 = s.projectiles.first.y;
      play(s, 10);
      expect(s.projectiles.first.y, lessThan(y0), reason: 'downward step');
    });

    test('UNIT-7 rocket EX fires a high and a low rocket', () {
      final s = duel(unit7, kai, dist: 90000);
      s.p[0].meter = meterMax;
      play(s, 22, in0: tapAt(Inp.special | Inp.heavy));
      expect(s.projectiles.length, 2);
    });

    test('UNIT-7 rocket outprioritises a fireball', () {
      final s = duel(unit7, kai, dist: 40000);
      final w = playWatch(s, 40, in0: tapAt(Inp.special), in1: tapAt(Inp.special));
      expect(w.has(Ev.clash), isTrue);
      expect(s.projectiles.where((p) => p.owner == 0), isNotEmpty, reason: 'rocket survives');
      expect(s.projectiles.where((p) => p.owner == 1), isEmpty);
    });

    test('UNIT-7 laser hits several times at chest height and misses a crouching dummy', () {
      final stand = _best(unit7, Slot.down, dists: const [9000, 14000]);
      expect(stand, greaterThan(60), reason: 'multi-hit beam');
      final crouch = _best(unit7, Slot.down, dists: const [9000, 14000], dummy: (f, s) => Inp.down);
      expect(crouch, 0);
      final ex = _best(unit7, Slot.down, ex: true, dists: const [9000]);
      expect(ex, greaterThan(stand - 1));
    });

    test('EMBER fireBreath is a short-range multi-hit', () {
      expect(_best(ember, Slot.forward, dists: const [8000, 11000]), greaterThan(40));
      final far = _fire(ember, Slot.forward, dist: 45000, frames: 80);
      expect(far.dmg, 0);
      expect(far.w.has(Ev.projectileSpawn), isTrue);
    });

    test('GOLEM boulder travels and hits; EX boulder has 2 hits', () {
      final r = _fire(golem, Slot.neutral, dist: 30000, frames: 140);
      expect(r.w.has(Ev.projectileSpawn), isTrue);
      expect(r.dmg, greaterThan(0));
      expect(golem.projectiles[1].hits, 2);
    });
  });

  group('movement and evasion', () {
    Projectile fireballAt(FightState s, int dx, int y) =>
        Projectile(1, 0, ++s.serial, s.p[0].x + dx, y, -600, 0, 100, 1);

    for (final (c, input, label) in [(dex, Inp.down | Inp.special, 'lowCartwheel'), (luz, Inp.down | Inp.special, 'slideKick'), (kage, Inp.down | Inp.special, 'shadowSlip')]) {
      test('${c.name} $label goes through a fireball', () {
        int hp(bool use) {
          final s = duel(c, kai, dist: 60000);
          s.projectiles.add(fireballAt(s, 12000, 2000));
          play(s, 30, in0: use ? tapAt(input) : none);
          return s.p[0].health;
        }

        expect(hp(false), lessThan(c.maxHealth), reason: 'control: standing eats it');
        expect(hp(true), c.maxHealth);
      });
    }

    test('KAGE dashSlash ends on the far side of the opponent', () {
      final s = duel(kage, kai, dist: 12000);
      play(s, 40, in0: tapAt(_fwd | Inp.special));
      expect(s.p[0].x, greaterThan(s.p[1].x));
      expect(s.p[1].health, lessThan(kai.maxHealth));
    });

    test('KAGE yuureiRyu vanishes and strikes from behind', () {
      final s = duel(kage, kai, dist: 14000);
      s.p[0].meter = meterMax;
      play(s, 90, in0: tapAt(Inp.superBtn));
      expect(s.p[0].x, greaterThan(s.p[1].x));
    });

    test('HANA lunge covers ground and hits from long range', () {
      expect(_best(hana, Slot.forward, dists: const [20000]), greaterThan(0));
    });

    test('BOOM tsuppari carries a cornered opponent into a wall bounce', () {
      final t = duel(boom, kai, dist: 9000, x: stageMaxX - 20000);
      t.p[0].x = stageMaxX - 9000;
      t.p[1].x = stageMaxX - 500;
      final w = playWatch(t, 70, in0: tapAt(Inp.special));
      expect(w.has(Ev.wallBounce), isTrue);
    });

    test('GOLEM groundSlam hits a low-blocker but not a jumper', () {
      var s = duel(golem, kai, dist: 14000);
      play(s, 60, in0: tapAt(Inp.down | Inp.special), in1: hold(_away | Inp.down));
      expect(s.p[1].health, lessThan(kai.maxHealth));
      s = duel(golem, kai, dist: 14000);
      s.p[1].y = 120000;
      s.p[1].state = St.jump;
      play(s, 40, in0: tapAt(Inp.down | Inp.special));
      expect(s.p[1].health, kai.maxHealth);
    });

    test('EMBER tailSweep is low: stand-block loses, crouch-block holds', () {
      final stand = _best(ember, Slot.down, dists: const [8000, 11000], dummy: (f, s) => _away);
      final crouch = _best(ember, Slot.down, dists: const [8000, 11000], dummy: (f, s) => _away | Inp.down);
      expect(stand, greaterThan(crouch));
    });

    test('UNIT-7 selfDestruct has a long recovery', () {
      expect(unit7.moves[unit7.superMove].recovery, greaterThanOrEqualTo(60));
    });
  });
}
