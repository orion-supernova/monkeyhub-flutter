import 'dart:math' as math;
import 'dart:ui';

import '../../core/core.dart';
import 'art_common.dart';

/// World -> screen. World x is engine px (engine units / 100, stage 0..1200),
/// world y is px above ground.
class FightCamera {
  final double scale; // screen px per world px
  final double originX; // screen x of world x = 0
  final double groundY; // screen y of world y = 0
  const FightCamera(this.scale, this.originX, this.groundY);

  Offset toScreen(double wx, double wy) => Offset(originX + wx * scale, groundY - wy * scale);

  /// Smoothly follows both fighters: centred on their midpoint, zoom from their
  /// separation (closer = tighter, never past the stage edges 0..1200), ground at
  /// ~85% of the height. Pass the previous camera to ease; null = snap.
  static FightCamera follow(FightState s, Size size, FightCamera? prev) {
    final a = s.p[0].x / unitsPerPx, b = s.p[1].x / unitsPerPx;
    final sep = (a - b).abs();
    final mid = (a + b) / 2;
    final minScale = size.width / stageWidthPx;
    // Visible world width: separation plus breathing room, never the whole stage unless needed.
    // On a tall (portrait) view, frame tighter: the width is what's scarce,
    // so show just the fighters plus a margin, or they end up tiny.
    final tall = size.height > size.width * .8;
    final vw = tall ? (sep + 190).clamp(440.0, stageWidthPx.toDouble()) : (sep + 560).clamp(640.0, stageWidthPx.toDouble());
    var scale = size.width / vw;
    // Keep headroom for the highest jump (about 190 px) plus a body height.
    final maxByHeight = size.height * .85 / 440;
    scale = math.min(scale, maxByHeight);
    scale = math.max(scale, minScale);
    var cx = mid;
    final gy = size.height * .85;
    if (prev != null && prev.scale > 0) {
      final pcx = (size.width / 2 - prev.originX) / prev.scale;
      scale = lerpD(prev.scale, scale, .12);
      cx = lerpD(pcx, cx, .12);
    }
    final half = size.width / 2 / scale;
    cx = cx.clamp(half, stageWidthPx - half).toDouble();
    if (half * 2 >= stageWidthPx) cx = stageWidthPx / 2;
    return FightCamera(scale, size.width / 2 - cx * scale, gy);
  }
}
