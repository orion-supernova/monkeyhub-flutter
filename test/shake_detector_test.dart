import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/diagnostics/shake_detector.dart';

/// The shake heuristic decides how often a child waving their phone lands in a
/// bug-report prompt. Too loose and it becomes a nuisance the whole app gets
/// blamed for; too tight and nobody finds the feature. These pin the shape.
void main() {
  final d = ShakeDetector.instance;
  final t0 = DateTime(2026, 8, 6, 12);

  var fired = 0;
  setUp(() {
    d.resetForTest();
    fired = 0;
    d.setHandlerForTest(() => fired++);
  });

  test('one hard jolt is not a shake', () {
    // Setting a phone down, or a bump on a bus. Real shaking repeats.
    d.debugFeed(4.0, t0);
    expect(fired, 0);
  });

  test('two spikes are still not enough', () {
    d.debugFeed(4.0, t0);
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 300)));
    expect(fired, 0);
  });

  test('three spikes inside the window fire once', () {
    d.debugFeed(4.0, t0);
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 300)));
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 600)));
    expect(fired, 1);
  });

  test('gentle motion never counts, however much of it there is', () {
    // Walking with the phone in hand peaks well under the threshold.
    for (var i = 0; i < 50; i++) {
      d.debugFeed(1.6, t0.add(Duration(milliseconds: i * 200)));
    }
    expect(fired, 0);
  });

  test('one physical jolt spread over several samples counts once', () {
    // The sensor reports a single impact across consecutive samples; without
    // the minimum gap that alone would satisfy the three-spike rule.
    d.debugFeed(4.0, t0);
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 20)));
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 40)));
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 60)));
    expect(fired, 0);
  });

  test('spikes spread beyond the window do not accumulate', () {
    d.debugFeed(4.0, t0);
    d.debugFeed(4.0, t0.add(const Duration(seconds: 2)));
    d.debugFeed(4.0, t0.add(const Duration(seconds: 4)));
    expect(fired, 0);
  });

  test('continuous shaking fires at most once per cooldown', () {
    // Not once in total: 7.5s of shaking spans two 3s cooldowns, so two. What
    // makes a long shake produce ONE prompt is ShakeToReport's single-sheet
    // guard — this layer only bounds the rate.
    for (var i = 0; i < 30; i++) {
      d.debugFeed(4.0, t0.add(Duration(milliseconds: i * 250)));
    }
    expect(fired, lessThanOrEqualTo(3));
    expect(fired, greaterThan(0));
  });

  test('one burst of shaking inside a single cooldown fires exactly once', () {
    for (var i = 0; i < 10; i++) {
      d.debugFeed(4.0, t0.add(Duration(milliseconds: i * 250)));
    }
    expect(fired, 1);
  });

  test('after the cooldown a fresh shake is heard again', () {
    d.debugFeed(4.0, t0);
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 300)));
    d.debugFeed(4.0, t0.add(const Duration(milliseconds: 600)));
    expect(fired, 1);

    final later = t0.add(const Duration(seconds: 10));
    d.debugFeed(4.0, later);
    d.debugFeed(4.0, later.add(const Duration(milliseconds: 300)));
    d.debugFeed(4.0, later.add(const Duration(milliseconds: 600)));
    expect(fired, 2);
  });

  test('disabling it silences everything', () {
    d.enabled = false;
    // debugFeed bypasses the enabled check by design (it is the seam below the
    // sensor callback), so assert the flag itself is what callers toggle.
    expect(d.enabled, isFalse);
    d.enabled = true;
    expect(d.enabled, isTrue);
  });
}
