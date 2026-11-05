import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';

/// Plays a whole match bot vs bot; returns the frames used.
int playMatch(CharacterDef a, CharacterDef b, int seed, BotLevel la, BotLevel lb) {
  final s = FightState.initial(seed: seed, p1: a, p2: b);
  final b0 = FightBot(seed: seed * 2 + 1, level: la);
  final b1 = FightBot(seed: seed * 2 + 2, level: lb);
  var frames = 0;
  while (s.phase != Phase.over && frames < 3 * (introFrames + roundFrames + koFrames) + 100) {
    step(s, b0.decide(s, 0), b1.decide(s, 1));
    frames++;
  }
  expect(s.phase, Phase.over, reason: '${a.name} vs ${b.name} seed $seed must finish');
  expect(s.matchWinner, inInclusiveRange(0, 2));
  return frames;
}

void main() {
  const levels = [
    [BotLevel.normal, BotLevel.normal],
    [BotLevel.hard, BotLevel.easy],
    [BotLevel.hard, BotLevel.hard],
  ];
  // All pairs of the starters; the rest of the cast has its own wave tests.
  for (final a in starters) {
    for (final b in starters) {
      test('${a.name} vs ${b.name}: 3 bot matches finish without exceptions', () {
        for (var k = 0; k < 3; k++) {
          playMatch(a, b, 40 + k + a.id * 7 + b.id * 3, levels[k][0], levels[k][1]);
        }
      });
    }
  }

  test('harder bots beat easier ones more often than not', () {
    var hardWins = 0, easyWins = 0;
    for (var k = 0; k < 8; k++) {
      final s = FightState.initial(seed: 900 + k, p1: kai, p2: kai);
      final h = FightBot(seed: 5 + k, level: BotLevel.hard);
      final e = FightBot(seed: 77 + k, level: BotLevel.easy);
      var f = 0;
      while (s.phase != Phase.over && f++ < 12000) {
        step(s, h.decide(s, 0), e.decide(s, 1));
      }
      if (s.matchWinner == 0) hardWins++;
      if (s.matchWinner == 1) easyWins++;
    }
    expect(hardWins, greaterThan(easyWins));
  });

  test('bots actually fight: damage is dealt, specials and supers get used', () {
    var specials = 0, supers = 0, damage = 0;
    for (final c in starters) {
      final s = FightState.initial(seed: 3, p1: c, p2: kai);
      final b0 = FightBot(seed: 1, level: BotLevel.hard);
      final b1 = FightBot(seed: 2, level: BotLevel.normal);
      var f = 0;
      var lastMove = -1, lastSerial = -1;
      while (s.phase != Phase.over && f++ < 12000) {
        step(s, b0.decide(s, 0), b1.decide(s, 1));
        final p = s.p[0];
        if (p.state == St.move && p.serial != lastSerial) {
          lastSerial = p.serial;
          lastMove = p.moveId;
          final m = c.moves[lastMove];
          if (m.cls == MoveClass.special) specials++;
          if (m.cls == MoveClass.superMove) supers++;
        }
      }
      damage += (kai.maxHealth - s.p[1].health).abs() + (c.maxHealth - s.p[0].health).abs();
    }
    expect(specials, greaterThan(10));
    expect(supers, greaterThan(0));
    expect(damage, greaterThan(0));
  });
}
