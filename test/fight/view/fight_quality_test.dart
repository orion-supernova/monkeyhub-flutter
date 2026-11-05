import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/view/fight_quality.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('two bad windows in a row step the quality down, one at a time', () {
    final g = FightQualityGovernor(window: 10, jankShare: .2)..start();
    void window(int janky) {
      for (var i = 0; i < 10; i++) {
        g.sample(i < janky);
      }
    }

    window(5);
    expect(fightQuality.value, FightQuality.full, reason: 'one bad window is a strike, not a verdict');
    window(5);
    expect(fightQuality.value, FightQuality.reduced);
    window(1); // a good window resets the strikes
    window(5);
    expect(fightQuality.value, FightQuality.reduced);
    window(5);
    expect(fightQuality.value, FightQuality.minimal);
    window(9);
    window(9);
    expect(fightQuality.value, FightQuality.minimal, reason: 'never below minimal');
    g.start();
    expect(fightQuality.value, FightQuality.full, reason: 'a new fight starts at full');
    g.stop();
  });

  test('a smooth device stays at full', () {
    final g = FightQualityGovernor(window: 10)..start();
    for (var i = 0; i < 500; i++) {
      g.sample(i % 20 == 0); // an occasional hitch
    }
    expect(fightQuality.value, FightQuality.full);
    g.stop();
  });
}
