import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';
import 'package:monkeyhub/fight/view/art/quality.dart';

import 'paint_cost_test.dart' show CountingCanvas, PaintCounts;

/// The governor's levels must actually draw less: fighters at [reduced]
/// lose rim light, occlusion and halftone; at [minimal] the shading too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => fightQuality.value = FightQuality.full);

  PaintCounts cost(FightLook look, FightQuality q) {
    fightQuality.value = q;
    final art = FightArt();
    final n = PaintCounts();
    const size = Size(1280, 800);
    for (final c in roster) {
      final s = FightState.initial(seed: 3, p1: c, p2: roster[(c.id + 5) % roster.length]);
      for (var f = 0; f < 30; f++) {
        step(s, f.isEven ? Inp.light : 0, 0);
      }
      art.paintActors(CountingCanvas(n), size, FightCamera.follow(s, size, null), s, look);
    }
    return n;
  }

  for (final look in FightLook.values) {
    test('${look.name}: each lower quality level draws fewer paths', () {
      final full = cost(look, FightQuality.full), reduced = cost(look, FightQuality.reduced), minimal = cost(look, FightQuality.minimal);
      // ignore: avoid_print
      print('${look.name}: full ${full.path}/${full.shaded}  reduced ${reduced.path}/${reduced.shaded}  minimal ${minimal.path}/${minimal.shaded} (paths/shaded)');
      expect(minimal.path, lessThan(full.path));
      // Pixel has no halftone/rim to drop, so reduced equals full there.
      expect(reduced.path + reduced.shaded, look == FightLook.pixel ? lessThanOrEqualTo(full.path + full.shaded) : lessThan(full.path + full.shaded));
      expect(minimal.path, lessThanOrEqualTo(reduced.path));
    });
  }
}
