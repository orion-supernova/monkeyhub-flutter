import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/spring.dart';

/// Plain Dart, no widgets: the whole reason the spring is a separate class is
/// that "does this settle, and does it still settle when the frame is late" is
/// arithmetic, and arithmetic should not need a pumped widget tree to check.
void main() {
  /// Runs [s] at [fps] for at most [seconds] and returns the frames it took to
  /// come to rest. Fails rather than looping forever if it never does.
  int settle(Spring s, {double fps = 60, double seconds = 5}) {
    final dt = 1 / fps;
    final limit = (seconds * fps).round();
    for (var i = 1; i <= limit; i++) {
      s.tick(dt);
      if (s.atRest) return i;
    }
    fail('spring never came to rest: value=${s.value} velocity=${s.velocity}');
  }

  test('an overshooting spring arrives, overshoots once, and settles', () {
    final s = Spring(response: 0.42, ratio: 0.78);
    s.retarget(1);
    var peak = 0.0;
    for (var i = 0; i < 120; i++) {
      s.tick(1 / 60);
      if (s.value > peak) peak = s.value;
    }
    expect(peak, greaterThan(1.0), reason: 'ratio < 1 must overshoot');
    expect(
      peak,
      lessThan(1.10),
      reason: 'a 10% overshoot is a wobble, not a bounce',
    );
    expect(s.value, closeTo(1, 0.002));
  });

  test('a critically damped spring never passes its target', () {
    final s = Spring(response: 0.3, ratio: 1);
    s.retarget(1);
    for (var i = 0; i < 120; i++) {
      s.tick(1 / 60);
      expect(s.value, lessThanOrEqualTo(1.0001));
    }
  });

  test('retargeting mid-flight keeps the velocity it already had', () {
    final s = Spring(response: 0.4, ratio: 0.8);
    s.retarget(3);
    for (var i = 0; i < 8; i++) {
      s.tick(1 / 60);
    }
    final flying = s.velocity;
    expect(flying, greaterThan(0));

    final where = s.value;
    s.retarget(1);
    expect(s.velocity, flying, reason: 'a retarget must not brake the spring');
    expect(s.value, where, reason: 'a retarget must not teleport the spring');
    settle(s);
    expect(s.value, closeTo(1, 0.002));
  });

  test(
    'it settles from a 100ms frame, which is what pumpAndSettle gives it',
    () {
      // Semi-implicit Euler on a stiff spring diverges at this step size unless
      // tick() sub-steps. Left unguarded, every widget test of a spring-driven
      // widget would time out rather than fail, which is the worst way to find
      // out.
      final coarse = Spring(response: 0.16, ratio: 0.92)..retarget(3);
      final frames = settle(coarse, fps: 10);
      expect(frames, lessThan(50));
      expect(coarse.value, closeTo(3, 0.002));

      // And the coarse result is the same place the fine one reached.
      final fine = Spring(response: 0.16, ratio: 0.92)..retarget(3);
      settle(fine, fps: 120);
      expect(fine.value, closeTo(coarse.value, 0.002));
    },
  );

  test('a very late frame is capped rather than integrated in full', () {
    // The app was backgrounded for a minute. Arriving is right; simulating a
    // minute of oscillation to get there is not.
    final s = Spring(response: 0.4, ratio: 0.7)..retarget(1);
    s.tick(60);
    expect(s.value, closeTo(1, 0.05));
  });

  test('snap ends all motion at once', () {
    final s = Spring(response: 0.4, ratio: 0.6)..retarget(1);
    for (var i = 0; i < 6; i++) {
      s.tick(1 / 60);
    }
    expect(s.velocity, isNot(0));
    s.snap(2);
    expect(s.value, 2);
    expect(s.velocity, 0);
    expect(s.atRest, isTrue);
  });
}
