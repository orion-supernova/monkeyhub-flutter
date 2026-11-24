import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/view/art/stages/stages.dart';
import 'package:monkeyhub/fight/view/fight_stage_picker.dart';

void main() {
  test('Random picks only among the stages owned', () {
    bool owns(int id) => id == 0 || id == 3;
    final seen = <int>{};
    for (var i = 0; i < 200; i++) {
      seen.add(fightStageResolveOwned(kFightStageRandom, owns, math.Random(i)));
    }
    expect(seen, {0, 3});
  });

  test('A named stage plays when owned, Rooftop when locked', () {
    bool owns(int id) => id == 0 || id == 2;
    expect(fightStageResolveOwned(2, owns), 2);
    expect(fightStageResolveOwned(4, owns), 0);
  });

  test('Nothing owned still plays the free Rooftop', () {
    expect(fightStageResolveOwned(kFightStageRandom, (_) => false), 0);
  });
}
