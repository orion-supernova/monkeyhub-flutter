import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';

import 'fight_test_utils.dart';

// p0 stands left facing right: forward = right, away from p0 = right.
const int _fwd = Inp.right;
const int _away = Inp.right;

void main() {
  group('block rules', () {
    test('overhead (fwd+heavy) beats crouch-block, loses to stand-block', () {
      var s = duel(kai, kai, dist: 10000);
      play(s, 40, in0: tapAt(_fwd | Inp.heavy), in1: hold(_away | Inp.down));
      expect(s.p[1].health, lessThan(kai.maxHealth), reason: 'crouch block must fail vs overhead');
      s = duel(kai, kai, dist: 10000);
      play(s, 40, in0: tapAt(_fwd | Inp.heavy), in1: hold(_away));
      expect(s.p[1].health, kai.maxHealth, reason: 'stand block holds vs overhead');
    });

    test('low (crouch light) beats stand-block, loses to crouch-block', () {
      var s = duel(kai, kai, dist: 8000);
      play(s, 30, in0: tapAt(Inp.down | Inp.light), in1: hold(_away));
      expect(s.p[1].health, lessThan(kai.maxHealth));
      s = duel(kai, kai, dist: 8000);
      play(s, 30, in0: tapAt(Inp.down | Inp.light), in1: hold(_away | Inp.down));
      expect(s.p[1].health, kai.maxHealth);
    });

    test('mid (stand light) is blocked either way', () {
      for (final extra in [0, Inp.down]) {
        final s = duel(kai, kai, dist: 8000);
        play(s, 30, in0: tapAt(Inp.light), in1: hold(_away | extra));
        expect(s.p[1].health, kai.maxHealth, reason: 'extra=$extra');
      }
    });

    test('jump heavy is an overhead', () {
      var s = duel(kai, kai, dist: 9000);
      // jump straight up then press heavy when airborne
      play(s, 50, in0: (f, st) => f == 0 ? Inp.up : (f == 30 ? Inp.heavy : 0), in1: hold(_away | Inp.down));
      expect(s.p[1].health, lessThan(kai.maxHealth));
    });

    test('chip damage comes from specials only', () {
      var s = duel(kai, kai, dist: 8000);
      play(s, 40, in0: tapAt(Inp.light), in1: hold(_away));
      expect(s.p[1].health, kai.maxHealth, reason: 'normal blocked: no chip');
      s = duel(kai, kai, dist: 25000);
      play(s, 100, in0: tapAt(Inp.special), in1: hold(_away));
      expect(s.p[1].health, kai.maxHealth - 12, reason: 'blocked Surge Palm chips 12');
    });
  });

  group('throws', () {
    test('throw connects, deals damage and knocks down', () {
      final s = duel(kai, kai, dist: 7000);
      play(s, 20, in0: tapAt(Inp.light | Inp.heavy));
      expect(s.p[1].health, kai.maxHealth - 110);
      expect(s.p[1].state == St.airstun || s.p[1].state == St.down, isTrue);
    });

    test('throw ignores blocking', () {
      final s = duel(kai, kai, dist: 7000);
      play(s, 20, in0: tapAt(Inp.light | Inp.heavy), in1: hold(_away | Inp.down));
      expect(s.p[1].health, kai.maxHealth - 110);
    });

    test('tech: light+heavy inside the 7 frame window cancels the throw', () {
      final s = duel(kai, kai, dist: 7000);
      var teched = false;
      for (var f = 0; f < 30; f++) {
        final grabbed = s.p[1].state == St.grabbed;
        step(s, f == 0 ? Inp.light | Inp.heavy : 0, grabbed && !teched ? Inp.light | Inp.heavy : 0);
        if (grabbed) teched = true;
      }
      expect(s.p[1].health, kai.maxHealth);
      expect(s.p[0].health, kai.maxHealth);
      expect((s.p[1].x - s.p[0].x).abs(), greaterThan(7000), reason: 'pushed apart');
    });

    test('throw whiffs on an airborne opponent', () {
      final s = duel(kai, kai, dist: 7000);
      s.p[1].y = 20000;
      s.p[1].vy = 100;
      s.p[1].state = St.jump;
      play(s, 12, in0: tapAt(Inp.light | Inp.heavy));
      expect(s.p[1].health, kai.maxHealth);
    });
  });

  group('timing events', () {
    test('perfect block: block begun right before the hit halves blockstun', () {
      final s = duel(kai, kai, dist: 8000);
      final m = kai.moves[N.standLight];
      final w = Watch();
      for (var f = 0; f < 40; f++) {
        // Start holding back only 2 frames before the first active frame.
        final holdNow = s.p[0].state == St.move && s.p[0].sf >= m.startup - 2;
        step(s, f == 0 ? Inp.light : 0, holdNow ? _away : 0);
        w.observe(s);
      }
      expect(w.has(Ev.perfectBlock), isTrue);
      expect(w.has(Ev.block), isFalse);
      expect(s.p[1].health, kai.maxHealth);
      expect(s.p[1].meter, greaterThan(0), reason: 'perfect block gains meter');
    });

    test('a block held long before the hit is a plain block', () {
      final s = duel(kai, kai, dist: 8000, x: stageMaxX - 8000);
      s.p[1].x = stageMaxX; // pinned in the corner so holding back does not walk away
      final w = playWatch(s, 30, in0: tapAt(Inp.light, 12), in1: hold(_away));
      expect(w.has(Ev.block), isTrue);
      expect(w.has(Ev.perfectBlock), isFalse);
    });

    test('counter hit: hitting a move in startup adds damage and fires the event', () {
      final s = duel(kai, kai, dist: 8000);
      final w = playWatch(s, 30, in0: tapAt(Inp.light, 2), in1: tapAt(Inp.heavy, 0));
      expect(w.has(Ev.counterHit), isTrue);
      expect(s.p[1].health, kai.maxHealth - (30 * 12 ~/ 10));
    });
  });

  group('combos', () {
    int autoChain(int f, FightState s) {
      final p = s.p[0];
      if (p.state == St.move && p.contact == 1) {
        if (p.moveId == N.standLight) return Inp.light;
        if (p.moveId == N.standLight2) return Inp.heavy;
        return 0;
      }
      return f == 0 ? Inp.light : 0;
    }

    test('light, light, heavy target combo scales 100/100/80', () {
      final s = duel(kai, kai, dist: 8000);
      play(s, 80, in0: autoChain);
      expect(s.p[1].health, kai.maxHealth - (30 + 30 + 60 * 80 ~/ 100));
    });

    test('scaling table has a 30% floor', () {
      expect([for (var i = 0; i < 12; i++) scalePercent(i, comboScaleFloor)],
          [100, 100, 80, 70, 60, 50, 40, 30, 30, 30, 30, 30]);
      expect(scalePercent(9, 40), 40, reason: 'supers use their own floor');
    });

    test('juggle budget: exhausted victims are untouchable until landing', () {
      int tryHit(bool locked) {
        final s = duel(kai, kai, dist: 8000);
        final v = s.p[1];
        v.state = St.airstun;
        v.y = 6000;
        v.vy = 300;
        v.juggleLeft = locked ? 0 : 5;
        v.juggleLocked = locked;
        play(s, 20, in0: tapAt(Inp.heavy));
        return kai.maxHealth - v.health;
      }

      expect(tryHit(false), greaterThan(0));
      expect(tryHit(true), 0);
    });

    test('hits spend juggle points until locked', () {
      final s = duel(kai, kai, dist: 8000);
      final v = s.p[1];
      v.state = St.airstun;
      v.y = 6000;
      v.vy = 300;
      v.juggleLeft = 1;
      play(s, 16, in0: tapAt(Inp.heavy)); // heavy costs 1 -> left 0 -> locked
      expect(v.juggleLocked, isTrue);
    });

    test('light cancels into a special on hit', () {
      final s = duel(kai, kai, dist: 8000);
      var cancelled = false;
      for (var f = 0; f < 40; f++) {
        final p = s.p[0];
        var i = 0;
        if (f == 0) i = Inp.light;
        if (p.state == St.move && p.moveId == N.standLight && p.contact == 1) i = Inp.special | Inp.down;
        step(s, i, 0);
        if (p.state == St.move && p.moveId == 12) cancelled = true; // Slide Step
      }
      expect(cancelled, isTrue);
    });
  });

  group('movement', () {
    test('double tap forward dashes faster than walking', () {
      final w = duel(kai, kai, dist: 60000);
      play(w, 16, in0: hold(_fwd));
      final walked = w.p[0].x - 50000;
      final d = duel(kai, kai, dist: 60000);
      play(d, 16, in0: (f, s) => (f == 0 || f == 3 || f == 4 || f > 4) ? _fwd : 0);
      expect(d.p[0].x - 50000, greaterThan(walked));
      expect(d.p[0].state == St.dash || d.p[0].x - 50000 > walked * 2, isTrue);
    });

    test('backdash on double tap back', () {
      final s = duel(kai, kai, dist: 20000);
      play(s, 12, in0: (f, st) => (f == 0 || f >= 3) ? Inp.left : 0);
      expect(s.p[0].x, lessThan(50000 - 4000));
    });

    test('roll passes through the opponent', () {
      final s = duel(kai, kai, dist: 12000);
      play(s, 50, in0: tapAt(Inp.roll));
      expect(s.p[0].x, greaterThan(s.p[1].x));
      expect(s.p[0].face, -1, reason: 'turns to face the opponent once the roll is done');
    });

    test('roll is strike-invulnerable on frames 2-14 and punishable after', () {
      int hurt(int rollFrame) {
        final s = duel(kai, kai, dist: 8000);
        s.p[1].state = St.roll;
        s.p[1].sf = rollFrame;
        s.p[1].jumpDir = -1; // back roll: stays solid and in reach
        s.p[1].vx = 0;
        play(s, 6, in0: tapAt(Inp.light));
        return kai.maxHealth - s.p[1].health;
      }

      // The jab lands ~5 frames after the press; roll frame advances meanwhile.
      expect(hurt(1), 0);
      expect(hurt(5), 0);
      expect(hurt(24), greaterThan(0), reason: 'recovery is punishable');
    });

    test('roll is throwable', () {
      final s = duel(kai, kai, dist: 7000);
      s.p[1].state = St.roll;
      s.p[1].sf = 6;
      s.p[1].jumpDir = -1;
      play(s, 20, in0: tapAt(Inp.light | Inp.heavy));
      expect(s.p[1].health, lessThan(kai.maxHealth));
    });

    test('hold roll on landing quick-rises', () {
      int rise(bool quick) {
        final s = duel(kai, kai, dist: 20000);
        s.p[0].state = St.airstun;
        s.p[0].y = 1;
        s.p[0].vy = -50;
        s.p[0].juggleLeft = 5;
        var n = 0;
        for (var f = 0; f < 80; f++) {
          step(s, quick ? Inp.roll : 0, 0);
          if (s.p[0].state == St.idle) {
            n = f;
            break;
          }
        }
        return n;
      }

      expect(rise(true), lessThan(rise(false) - 10));
    });
  });

  group('projectiles and entities', () {
    test('projectiles clash and cancel each other', () {
      final s = duel(kai, kai, dist: 60000);
      final w = playWatch(s, 90, in0: tapAt(Inp.special), in1: tapAt(Inp.special));
      expect(w.has(Ev.clash), isTrue);
      expect(s.projectiles, isEmpty);
      expect(s.p[0].health, kai.maxHealth);
      expect(s.p[1].health, kai.maxHealth);
    });

    test('Surge Palm travels and hits', () {
      final s = duel(kai, kai, dist: 40000);
      play(s, 80, in0: tapAt(Inp.special));
      expect(s.p[1].health, kai.maxHealth - 60);
    });

    test('Slide Step goes under a fireball', () {
      int hpAfter(bool slide) {
        final s = duel(kai, kai, dist: 40000);
        // p1 fires, p0 slides (down+special) timed to be mid-slide when it arrives.
        play(s, 60, in0: (f, st) {
          if (!slide) return 0;
          if (f == 14) return Inp.down | Inp.special;
          if (f > 14 && f < 19) return Inp.down;
          return 0;
        }, in1: tapAt(Inp.special));
        return s.p[0].health;
      }

      expect(hpAfter(false), lessThan(kai.maxHealth), reason: 'control: standing eats the fireball');
      expect(hpAfter(true), kai.maxHealth);
    });

    test('Banana Peel: one trap at a time, trips the opponent', () {
      final s = duel(mojo, kai, dist: 40000);
      play(s, 40, in0: tapAt(Inp.down | Inp.special));
      expect(s.traps.length, 1);
      final first = s.traps.first.x;
      s.p[0].x = 40000;
      play(s, 40, in0: tapAt(Inp.down | Inp.special));
      expect(s.traps.length, 1, reason: 'a new trap replaces the old one');
      expect(s.traps.first.x, isNot(first));
      // Walk the opponent onto it.
      s.p[1].x = s.traps.first.x + 4000;
      play(s, 30, in1: hold(Inp.left));
      expect(s.p[1].health, lessThan(kai.maxHealth));
      expect(s.traps, isEmpty);
    });

    test('Shadow Pool slows the opponent walk', () {
      final s = duel(nyx, kai, dist: 30000);
      play(s, 40, in0: tapAt(Inp.down | Inp.special));
      expect(s.traps.length, 1);
      s.p[1].x = s.traps.first.x;
      play(s, 4);
      expect(s.p[1].slow, greaterThan(100));
      final x0 = s.p[1].x;
      play(s, 10, in1: hold(Inp.left));
      final slowDist = x0 - s.p[1].x;
      expect(slowDist, lessThan(10 * kai.walkFwd * 7 ~/ 10), reason: 'slowed to ~60% of a normal walk');
    });
  });

  group('special mechanics', () {
    test('armor absorbs exactly one hit', () {
      final s = duel(tank, kai, dist: 9000);
      final w = Watch();
      // Tank charges; Kai jabs during the armor window.
      for (var f = 0; f < 12; f++) {
        step(s, f == 0 ? Inp.special : 0, f == 6 ? Inp.light : 0);
        w.observe(s);
      }
      expect(w.has(Ev.armor), isTrue);
      expect(s.p[0].armorLeft, 0);
      expect(s.p[0].health, tank.maxHealth - 15);
      expect(s.p[0].state, St.move, reason: 'armor means no hitstun');
      // Second hit while still inside the armor window now connects.
      s.p[0].sf = 8;
      s.p[0].stop = 0;
      s.p[1].stop = 0;
      s.p[1].state = St.idle;
      s.p[1].x = s.p[0].x + 8000;
      final before = s.p[0].health;
      play(s, 10, in1: tapAt(Inp.light));
      expect(s.p[0].health, lessThan(before));
      expect(s.p[0].state, isNot(St.move));
    });

    test('command grab ignores block', () {
      final s = duel(tank, kai, dist: 7500);
      play(s, 20, in0: tapAt(_fwd | Inp.special), in1: hold(_away | Inp.down));
      expect(s.p[1].health, kai.maxHealth - 150);
    });

    test('command grab cannot be teched', () {
      final s = duel(tank, kai, dist: 7500);
      play(s, 20, in0: tapAt(_fwd | Inp.special), in1: tapAt(Inp.light | Inp.heavy, 6));
      expect(s.p[1].health, kai.maxHealth - 150);
    });

    test('Earthquake hits a low-blocking opponent but not a jumping one', () {
      var s = duel(tank, kai, dist: 12000);
      play(s, 40, in0: tapAt(Inp.down | Inp.special), in1: hold(_away | Inp.down));
      expect(s.p[1].health, lessThan(kai.maxHealth));
      s = duel(tank, kai, dist: 12000);
      s.p[1].y = 40000;
      s.p[1].state = St.jump;
      play(s, 28, in0: tapAt(Inp.down | Inp.special));
      expect(s.p[1].health, kai.maxHealth);
    });

    test('Eclipse counter stance triggers and teleports behind', () {
      final s = duel(nyx, kai, dist: 9000);
      final w = Watch();
      for (var f = 0; f < 60; f++) {
        step(s, f == 0 ? Inp.up | Inp.special : 0, f == 3 ? Inp.light : 0);
        w.observe(s);
      }
      expect(w.has(Ev.counterTrigger), isTrue);
      expect(s.p[0].x, greaterThan(s.p[1].x), reason: 'Nyx ends up behind');
      expect(s.p[1].health, lessThan(kai.maxHealth));
      expect(s.p[0].health, nyx.maxHealth, reason: 'the original strike was nullified');
    });

    test('Eclipse without a strike just recovers', () {
      final s = duel(nyx, kai, dist: 20000);
      play(s, 60, in0: tapAt(Inp.up | Inp.special));
      expect(s.p[1].health, kai.maxHealth);
      expect(s.p[0].state, St.idle);
    });

    test('Phase Step lands on the far side', () {
      final s = duel(nyx, kai, dist: 20000);
      play(s, 40, in0: tapAt(_fwd | Inp.special));
      expect(s.p[0].x, greaterThan(s.p[1].x));
    });

    test('Comet Knee wall-bounces in the corner', () {
      final s = duel(kai, kai, dist: 9000, x: stageMinX + 20000);
      s.p[0].x = stageMinX + 9000;
      s.p[1].x = stageMinX + 1000;
      // Hit from the right pushes the victim into the left wall: swap roles.
      final t = duel(kai, kai, dist: 9000, x: stageMaxX - 20000);
      t.p[0].x = stageMaxX - 9000;
      t.p[1].x = stageMaxX - 500;
      final w = playWatch(t, 60, in0: tapAt(_fwd | Inp.special));
      expect(w.has(Ev.wallBounce), isTrue);
    });

    test('corner pushback transfers to the attacker', () {
      final s = duel(kai, kai, dist: 8000, x: stageMaxX - 8000);
      s.p[1].x = stageMaxX;
      final x0 = s.p[0].x;
      play(s, 30, in0: tapAt(Inp.heavy), in1: hold(_away));
      expect(s.p[0].x, lessThan(x0), reason: 'attacker slid back out of the corner pressure');
    });
  });

  group('super and meter', () {
    test('super costs 2 bars, freezes the opponent, then hits', () {
      final s = duel(kai, kai, dist: 8000);
      s.p[0].meter = meterMax;
      step(s, Inp.superBtn, 0);
      expect(s.p[0].meter, meterMax - superCost);
      expect(s.superFlash, superFlashFrames);
      final frozen = s.p[1].checksumLike();
      final px = s.p[0].x;
      for (var i = 0; i < superFlashFrames - 1; i++) {
        step(s, 0, Inp.left);
        expect(s.p[1].checksumLike(), frozen, reason: 'opponent frozen at flash frame $i');
        expect(s.p[0].x, px);
      }
      play(s, 120);
      expect(s.p[1].health, lessThan(kai.maxHealth - 200));
    });

    test('special+heavy+light together also fires the super', () {
      final s = duel(kai, kai, dist: 8000);
      s.p[0].meter = superCost;
      step(s, Inp.special | Inp.heavy | Inp.light, 0);
      expect(s.superFlash, superFlashFrames);
      expect(s.p[0].meter, 0);
    });

    test('super needs 2 bars', () {
      final s = duel(kai, kai, dist: 8000);
      s.p[0].meter = superCost - 1;
      step(s, Inp.superBtn, 0);
      expect(s.superFlash, 0);
    });

    test('EX special costs 1 bar', () {
      final s = duel(kai, kai, dist: 40000);
      s.p[0].meter = meterBar + 50;
      step(s, Inp.special | Inp.heavy, 0);
      expect(s.p[0].meter, 50);
      expect(s.p[0].moveId, 15);
    });

    test('meter is gained on landing hits and on taking damage', () {
      final s = duel(kai, kai, dist: 8000);
      play(s, 30, in0: tapAt(Inp.light));
      expect(s.p[0].meter, greaterThan(0));
      expect(s.p[1].meter, greaterThan(0));
    });
  });

  group('rounds', () {
    test('KO ends the round, next round resets, match ends at 2 wins', () {
      final s = duel(kai, kai, dist: 8000);
      s.p[1].health = 1;
      play(s, 20, in0: tapAt(Inp.light));
      expect(s.phase, Phase.ko);
      expect(s.p[0].wins, 1);
      expect(s.roundWinner, 0);
      play(s, koFrames + 2);
      expect(s.phase, Phase.intro);
      expect(s.round, 2);
      expect(s.p[1].health, kai.maxHealth);
      play(s, introFrames + 2);
      expect(s.phase, Phase.fight);
      s.p[0].x = 50000;
      s.p[1].x = 58000;
      s.p[1].health = 1;
      play(s, 20, in0: tapAt(Inp.light));
      expect(s.phase, Phase.ko);
      play(s, koFrames + 2);
      expect(s.phase, Phase.over);
      expect(s.matchWinner, 0);
    });

    test('time over: higher health wins, equal health draws', () {
      var s = duel(kai, kai);
      s.timer = 1;
      s.p[1].health = 400;
      play(s, 2);
      expect(s.phase, Phase.ko);
      expect(s.timeOver, isTrue);
      expect(s.roundWinner, 0);
      s = duel(kai, kai);
      s.timer = 1;
      play(s, 2);
      expect(s.roundWinner, 2);
      expect(s.p[0].wins, 1);
      expect(s.p[1].wins, 1);
    });

    test('double KO awards both a round', () {
      final s = duel(kai, kai);
      s.p[0].health = 0;
      s.p[1].health = 0;
      play(s, 2);
      expect(s.roundWinner, 2);
      expect(s.p[0].wins + s.p[1].wins, 2);
    });

    test('timer counts down 60 s', () {
      final s = duel(kai, kai);
      expect(s.timer, roundFrames);
      play(s, 60);
      expect(s.timer, roundFrames - 60);
    });
  });
}

extension on Fighter {
  /// Cheap fingerprint of the fields a freeze must not change.
  String checksumLike() => '$x,$y,$vx,$vy,$state,$sf,$health,$stun,$moveId';
}
