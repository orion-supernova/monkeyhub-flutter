import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/widgets/radial_floating_menu.dart';

/// Both nav chromes had the item count baked into their geometry. Neither
/// failure was catchable by the compiler or visible in a widget tree, so these
/// pin the arithmetic directly.
void main() {
  group('bottom pill indicator', () {
    test('segment centres span exactly -1..1 at the live count', () {
      final n = navDestinations.length;
      expect(segmentAlignmentX(0, n), -1);
      expect(segmentAlignmentX(n - 1, n), 1);
    });

    test('no segment ever lands outside the pill', () {
      // The regression: `-1 + i * 1.0` was this formula with count == 3 baked
      // in, so a fourth destination gave +2.0 and threw the indicator a half
      // segment past the right edge.
      for (var n = 2; n <= 8; n++) {
        for (var i = 0; i < n; i++) {
          final x = segmentAlignmentX(i, n);
          expect(x, inInclusiveRange(-1, 1), reason: 'segment $i of $n');
        }
      }
    });

    test('centres are evenly spaced and strictly increasing', () {
      final n = navDestinations.length;
      final xs = [for (var i = 0; i < n; i++) segmentAlignmentX(i, n)];
      for (var i = 1; i < n; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
        expect(xs[i] - xs[i - 1], closeTo(2 / (n - 1), 1e-9));
      }
    });

    test('three segments still behave exactly as before', () {
      expect(segmentAlignmentX(0, 3), -1);
      expect(segmentAlignmentX(1, 3), 0);
      expect(segmentAlignmentX(2, 3), 1);
    });

    test('an unknown segment centres rather than flying off', () {
      expect(segmentAlignmentX(-1, 4), 0);
      expect(segmentAlignmentX(0, 1), 0);
    });
  });

  group('radial fan', () {
    test('every slot stays above the horizontal at any count', () {
      // The regression: the old fixed 40° step put slot 3 at +38.2°, below the
      // horizontal, which rendered it 55pt underneath the gesture surface —
      // and `Clip.none` drew it there rather than clipping it away.
      for (var n = 1; n <= 8; n++) {
        for (var i = 0; i < n; i++) {
          expect(
            RadialGeometry.slotAngle(i, n),
            lessThanOrEqualTo(0),
            reason: 'slot $i of $n points downwards',
          );
        }
      }
    });

    test('no slot renders below the gesture surface', () {
      for (var n = 1; n <= 8; n++) {
        for (var i = 0; i < n; i++) {
          expect(
            RadialGeometry.bottom(i, n, 1),
            greaterThanOrEqualTo(0),
            reason: 'slot $i of $n sits below the widget',
          );
          expect(RadialGeometry.left(i, n, 1), greaterThanOrEqualTo(0));
        }
      }
    });

    test('the fan occupies the intended quadrant', () {
      final n = navDestinations.length;
      expect(RadialGeometry.slotAngle(0, n), RadialGeometry.spanStart);
      expect(
        RadialGeometry.slotAngle(n - 1, n),
        closeTo(RadialGeometry.spanStart + RadialGeometry.spanSweep, 1e-9),
      );
    });

    test('a single item sits mid-quadrant, not at its edge', () {
      expect(
        RadialGeometry.slotAngle(0, 1),
        closeTo(RadialGeometry.spanStart + RadialGeometry.spanSweep / 2, 1e-9),
      );
    });

    test('neighbouring orbs do not overlap at the live count', () {
      // Guards the radius against a future fifth destination: at 112pt a fifth
      // item would space neighbours ~39pt apart against a 44pt orb, so this
      // fails loudly rather than shipping overlapping glyphs.
      final n = navDestinations.length;
      for (var i = 1; i < n; i++) {
        final dx =
            RadialGeometry.left(i, n, 1) - RadialGeometry.left(i - 1, n, 1);
        final dy =
            RadialGeometry.bottom(i, n, 1) - RadialGeometry.bottom(i - 1, n, 1);
        expect(
          math.sqrt(dx * dx + dy * dy),
          greaterThanOrEqualTo(RadialGeometry.itemSize),
          reason: 'slots ${i - 1} and $i overlap — raise RadialGeometry.radius',
        );
      }
    });

    test('the last item still starts fanning out by the halfway mark', () {
      for (var n = 2; n <= 8; n++) {
        expect(RadialGeometry.stagger(n) * (n - 1), closeTo(0.5, 1e-9));
      }
    });

    group('hit testing', () {
      final n = navDestinations.length;

      test('pointing straight at a slot selects it', () {
        for (var i = 0; i < n; i++) {
          expect(
            RadialGeometry.indexForAngle(RadialGeometry.slotAngle(i, n), n),
            i,
          );
        }
      });

      test('between two slots the nearer wins — no dead zone', () {
        final step = RadialGeometry.spanSweep / (n - 1);
        // Just inside the boundary on either side of the 1↔2 midpoint.
        final mid = RadialGeometry.slotAngle(1, n) + step / 2;
        expect(RadialGeometry.indexForAngle(mid - 0.01, n), 1);
        expect(RadialGeometry.indexForAngle(mid + 0.01, n), 2);
      });

      test('overshooting past an end still commits to that end', () {
        // Dragging up-and-left plainly means "the top item". The old tolerance
        // shrank as items were added — three to four narrowed it 69° → 51.75°,
        // which turned this exact gesture from "select Chat" into "select
        // nothing".
        expect(RadialGeometry.indexForAngle(-3 * math.pi / 4, n), 0);
        // And down-and-right means the last one.
        expect(RadialGeometry.indexForAngle(math.pi / 4, n), n - 1);
      });

      test('a gesture that misses the fan entirely selects nothing', () {
        expect(
          RadialGeometry.indexForAngle(math.pi / 2, n),
          -1,
        ); // straight down
        expect(RadialGeometry.indexForAngle(math.pi, n), -1); // straight left
      });
    });
  });
}
