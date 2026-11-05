// Shared small helpers for the fight art: colours, seeded randomness, looks.
import 'dart:math' as math;
import 'dart:ui';

enum FightLook { cartoon, painted, pixel }

const Color kInk = Color(0xFF150F1E);

Color hex(int rgb) => Color(0xFF000000 | rgb);
Color mixC(Color a, Color b, double t) => Color.lerp(a, b, t)!;
Color dk(Color c, [double t = .3]) => mixC(c, const Color(0xFF1A1030), t);
Color lt(Color c, [double t = .22]) => mixC(c, const Color(0xFFFFF2DF), t);
Color withA(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));
double lerpD(double a, double b, double t) => a + (b - a) * t;
double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double smooth(double t) {
  t = clamp01(t);
  return t * t * (3 - 2 * t);
}

double easeOut(double t) {
  t = clamp01(t);
  final u = 1 - t;
  return 1 - u * u * u;
}

/// Tiny deterministic LCG, same recipe as the style lab's `srand`.
class SRand {
  int _s;
  SRand(int seed) : _s = (seed & 0xFFFFFFFF) == 0 ? 1 : (seed & 0xFFFFFFFF);
  double next() {
    _s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _s / 4294967296;
  }
}

/// Cheap integer hash -> 0..1, for per-frame shake and sparkle.
double hash01(int a, [int b = 0]) {
  var h = (a * 374761393 + b * 668265263) & 0xFFFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
  h = h ^ (h >> 16);
  return (h & 0xFFFF) / 65536.0;
}

Path starPath(double x, double y, double r1, double r2, int n, double rot) {
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final r = i.isOdd ? r2 : r1;
    final a = rot + i * math.pi / n;
    final px = x + math.cos(a) * r, py = y + math.sin(a) * r;
    if (i == 0) {
      p.moveTo(px, py);
    } else {
      p.lineTo(px, py);
    }
  }
  p.close();
  return p;
}

Path rrPath(double x, double y, double w, double h, double r) =>
    Path()..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)));

/// Straight lines of width [w] as one filled path (butt caps), so they can be
/// intersected with a shape instead of drawn under a clip.
Path hatchPath(List<(Offset, Offset)> lines, double w) {
  final p = Path();
  for (final (a, b) in lines) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final l = math.sqrt(dx * dx + dy * dy);
    if (l == 0) continue;
    final nx = -dy / l * w / 2, ny = dx / l * w / 2;
    p
      ..moveTo(a.dx + nx, a.dy + ny)
      ..lineTo(b.dx + nx, b.dy + ny)
      ..lineTo(b.dx - nx, b.dy - ny)
      ..lineTo(a.dx - nx, a.dy - ny)
      ..close();
  }
  return p;
}
