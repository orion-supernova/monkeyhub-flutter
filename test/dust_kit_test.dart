import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/dust/dust_kit.dart';

/// The dust kit's primitives — the sine table, the frame clamp and the
/// generic emitter every dust effect is built on.
void main() {
  test('the sine table is a sine', () {
    // 2048 entries: one step is 2π/2048 ≈ 3.1e-3 of a radian, which is the
    // worst the truncation can do.
    const step = 2 * math.pi / 2048;
    for (var i = 0; i <= 400; i++) {
      final turns = i / 400 * 3 - 1; // -1..2 turns
      expect(
        DustTrig.sin(turns),
        closeTo(math.sin(2 * math.pi * turns), step),
        reason: 'sin at $turns turns',
      );
      expect(
        DustTrig.cos(turns),
        closeTo(math.cos(2 * math.pi * turns), step),
        reason: 'cos at $turns turns',
      );
    }
  });

  test('the frame clamp never hands an integrator a dropped frame', () {
    expect(dustFrameDt(null, const Duration(seconds: 5)), 1 / 60);
    expect(
      dustFrameDt(Duration.zero, const Duration(milliseconds: 16)),
      closeTo(0.016, 1e-6),
    );
    expect(
      dustFrameDt(Duration.zero, const Duration(seconds: 2)),
      1 / 30,
      reason: 'a two-second stall integrates as one long frame, not sixty',
    );
    expect(
      dustFrameDt(Duration.zero, const Duration(microseconds: 10)),
      1 / 240,
      reason: 'and a burst of ticks never integrates as zero',
    );
  });

  group('DustMotes', () {
    test('spawns into free slots and refuses past capacity', () {
      final motes = DustMotes(capacity: 3, dpr: 2, seed: 1);
      expect(motes.spawn(x: 0, y: 0, vx: 0, vy: 0, life: 1, size: 1, argb: 0),
          0);
      expect(motes.spawn(x: 0, y: 0, vx: 0, vy: 0, life: 1, size: 1, argb: 0),
          1);
      expect(motes.spawn(x: 0, y: 0, vx: 0, vy: 0, life: 1, size: 1, argb: 0),
          2);
      expect(motes.spawn(x: 0, y: 0, vx: 0, vy: 0, life: 1, size: 1, argb: 0),
          -1, reason: 'full');
      expect(motes.living, 3);
    });

    test('steps, compacts, and frees the dead', () {
      final motes = DustMotes(capacity: 4, dpr: 2, seed: 1);
      motes.spawn(x: 10, y: 10, vx: 100, vy: 0, life: 1, size: 1, argb: 0xFF0000);
      motes.spawn(x: 20, y: 20, vx: 0, vy: 0, life: 0.05, size: 1, argb: 0x00FF00);
      motes.step(0.1);
      // The short-lived mote died on this step; the other moved and is
      // drawn — first in the compacted buffers.
      expect(motes.living, 1);
      expect(motes.alive, 1);
      expect(motes.points[0], closeTo(20, 1e-3));
      expect(motes.points[1], closeTo(10, 1e-3));
      expect(motes.colors[0] & 0xFFFFFF, 0xFF0000, reason: 'tinted');
      expect((motes.colors[0] >> 24) & 0xFF, greaterThan(0), reason: 'fading in');
      // Its slot is free again.
      expect(motes.spawn(x: 0, y: 0, vx: 0, vy: 0, life: 1, size: 1, argb: 0),
          isNot(-1));
      expect(motes.living, 2);
      // And it dies of old age.
      motes.step(2);
      expect(motes.living, 0);
      expect(motes.alive, 0);
    });

    test('drag slows a mote and clear empties the field', () {
      final motes = DustMotes(capacity: 2, dpr: 2, seed: 1);
      final i = motes.spawn(x: 0, y: 0, vx: 100, vy: 0, life: 5, size: 1, argb: 0);
      motes.step(0.5, drag: 4);
      expect(motes.vx[i], lessThan(100));
      expect(motes.vx[i], greaterThan(0));
      motes.clear();
      expect(motes.living, 0);
      expect(motes.alive, 0);
    });
  });
}
