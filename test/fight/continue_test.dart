import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';

void main() {
  FightState lost() {
    final s = FightState.initial(seed: 3, p1: kai, p2: kai);
    s.p[0].wins = 0;
    s.p[1].wins = roundsToWin;
    s.p[0].health = 0;
    s.p[0].meter = 500;
    s.phase = Phase.over;
    s.matchWinner = 1;
    s.roundWinner = 1;
    return s;
  }

  test('continueAfterLoss takes back the deciding round and heals both', () {
    final s = lost();
    expect(s.continueAfterLoss(0), isTrue);
    expect(s.phase, Phase.intro);
    expect(s.matchWinner, -1);
    expect(s.p[1].wins, roundsToWin - 1);
    expect(s.p[0].wins, 0);
    expect(s.p[0].health, kai.maxHealth);
    expect(s.p[1].health, kai.maxHealth);
    expect(s.p[0].meter, 500);
    expect(s.timer, roundFrames);
    for (var i = 0; i < introFrames + 5; i++) {
      step(s, 0, 0);
    }
    expect(s.phase, Phase.fight);
  });

  test('continueAfterLoss refuses unless that fighter lost a finished match', () {
    final s = lost();
    expect(s.continueAfterLoss(1), isFalse);
    expect(s.phase, Phase.over);
    final fresh = FightState.initial(seed: 3, p1: kai, p2: kai);
    expect(fresh.continueAfterLoss(0), isFalse);
  });
}
