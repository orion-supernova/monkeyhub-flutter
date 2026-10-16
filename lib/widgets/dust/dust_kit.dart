import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The dust, as a kit.
///
/// The spoiler veil grew the app's first particle system: motes born into
/// flat typed buffers, stepped in place, and drawn with a single
/// `drawRawAtlas` off one soft-dot sprite. Three other things now want the
/// same grain — a stroke on a shared screen blowing away, a whole message
/// bubble coming apart, and whatever comes next — so the pieces that are not
/// about *text* live here, and the veil imports them. Everything in this file
/// is a primitive: no ticker, no widget, no opinion about where motes come
/// from. Each caller owns its own life cycle and its own physics; what they
/// share is the sine table, the sprite, the frame clamp and the one draw
/// call.

/// A sine table, because a field costs several of them per mote per frame.
///
/// 2048 entries puts the worst quantisation error at about a hundredth of a
/// pixel at these amplitudes — invisible, and a fraction of the cost of
/// `math.sin` a few thousand motes at a time.
class DustTrig {
  DustTrig._();

  static const int _n = 2048;
  static final Float32List _table = () {
    final t = Float32List(_n);
    for (var i = 0; i < _n; i++) {
      t[i] = math.sin(2 * math.pi * i / _n);
    }
    return t;
  }();

  /// sin(2π · [turns]).
  static double sin(double turns) {
    var i = (turns * _n).toInt() & (_n - 1);
    if (i < 0) i += _n;
    return _table[i];
  }

  /// cos(2π · [turns]).
  static double cos(double turns) => sin(turns + 0.25);
}

/// A divergence-free wind, as a table: the curl of a smooth periodic stream
/// function, sampled once onto a [n]×[n] grid and read back bilinearly.
///
/// Curl noise is what makes smoke and dust move in streams that wrap around
/// each other instead of in parallel lines: being the curl of a field, it has
/// no sources or sinks, so motes neither clump into points nor tear apart —
/// they swirl. Building it costs a few hundred thousand sines, once per run of
/// the app; reading it costs four table loads and three lerps, with no
/// allocation, so a few thousand motes can read it every frame.
///
/// The domain is a unit torus: [sample] takes coordinates in periods, wraps
/// them, and leaves the answer in [x] and [y] (unit-ish: the table is scaled
/// so its strongest gust is 1).
class DustFlow {
  DustFlow._();

  static const int n = 64;
  static final Float32List _vx = Float32List(n * n);
  static final Float32List _vy = Float32List(n * n);
  static bool _built = false;

  /// The last [sample]'s answer. Statics, so a sample allocates nothing.
  static double x = 0, y = 0;

  static void _build() {
    _built = true;
    // ψ(u, v) = Σ A·sin(2π(kx·u + ky·v) + φ) with integer wave numbers, so it
    // tiles; amplitudes fall with frequency, so the big eddies lead and the
    // small ones roughen them.
    final rand = math.Random(0x5EED);
    const waves = 12;
    final kx = Float64List(waves), ky = Float64List(waves);
    final amp = Float64List(waves), ph = Float64List(waves);
    for (var w = 0; w < waves; w++) {
      int a, b;
      do {
        a = rand.nextInt(9) - 4;
        b = rand.nextInt(9) - 4;
      } while (a == 0 && b == 0);
      kx[w] = a.toDouble();
      ky[w] = b.toDouble();
      amp[w] = 1 / math.sqrt(a * a + b * b);
      ph[w] = rand.nextDouble() * 2 * math.pi;
    }
    var peak = 1e-9;
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final u = i / n, v = j / n;
        var du = 0.0, dv = 0.0;
        for (var w = 0; w < waves; w++) {
          final c = amp[w] * math.cos(2 * math.pi * (kx[w] * u + ky[w] * v) + ph[w]);
          du += c * kx[w];
          dv += c * ky[w];
        }
        // curl ψ = (∂ψ/∂v, −∂ψ/∂u).
        _vx[j * n + i] = dv;
        _vy[j * n + i] = -du;
        final m = math.sqrt(du * du + dv * dv);
        if (m > peak) peak = m;
      }
    }
    final s = 1 / peak;
    for (var k = 0; k < n * n; k++) {
      _vx[k] *= s;
      _vy[k] *= s;
    }
  }

  /// Builds the table now rather than on the first frame that needs it.
  static void warm() {
    if (!_built) _build();
  }

  /// The wind at ([u], [v]) periods, into [x] and [y].
  static void sample(double u, double v) {
    if (!_built) _build();
    final fu = u * n, fv = v * n;
    final iu = fu.floor(), iv = fv.floor();
    final tu = fu - iu, tv = fv - iv;
    final i0 = iu & (n - 1), i1 = (iu + 1) & (n - 1);
    final j0 = (iv & (n - 1)) * n, j1 = ((iv + 1) & (n - 1)) * n;
    final a = _vx[j0 + i0], b = _vx[j0 + i1];
    final c = _vx[j1 + i0], d = _vx[j1 + i1];
    final top = a + (b - a) * tu;
    x = top + (c + (d - c) * tu - top) * tv;
    final e = _vy[j0 + i0], f = _vy[j0 + i1];
    final g = _vy[j1 + i0], h = _vy[j1 + i1];
    final top2 = e + (f - e) * tu;
    y = top2 + (g + (h - g) * tu - top2) * tv;
  }
}

/// A cheap hash of two ints to 0..1, for per-mote per-frame coin flips
/// (flicker, sparkle) that must not allocate or touch a `Random`.
double dustHash(int a, int b) {
  var h = (a * 374761393 + b * 668265263) & 0x7fffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
  h ^= h >> 16;
  return (h & 0xFFFF) / 65536.0;
}

/// The one sprite every mote is drawn from: a soft dot, white, so a per-mote
/// colour can tint it through `BlendMode.modulate`.
///
/// Sized to the screen so the largest mote draws it about 1:1 — a 16px
/// sprite squeezed to two logical pixels through a bilinear filter flickers
/// with sub-pixel phase; one that is nearly the right size does not.
class DustSprite {
  DustSprite._();

  static final Map<int, ui.Image?> _cache = {};

  static int pxFor(double dpr) => (2.8 * dpr).round().clamp(6, 16);

  /// Null when the platform could not rasterise one, in which case a painter
  /// falls back to points.
  static ui.Image? forDpr(double dpr) {
    final px = pxFor(dpr);
    if (_cache.containsKey(px)) return _cache[px];
    ui.Image? image;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final c = Offset(px / 2, px / 2);
      canvas.drawCircle(
        c,
        px / 2,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            px / 2,
            const [Color(0xFFFFFFFF), Color(0xF2FFFFFF), Color(0x00FFFFFF)],
            const [0, 0.58, 1],
          ),
      );
      image = recorder.endRecording().toImageSync(px, px);
    } catch (_) {
      image = null;
    }
    _cache[px] = image;
    return image;
  }
}

/// One `drawRawAtlas` for the first [alive] entries of a set of render
/// buffers — or, when there is no sprite to draw with, one `drawRawPoints`.
class DustAtlas {
  DustAtlas._();

  static final Paint paint = Paint()..filterQuality = FilterQuality.low;

  /// [transforms] and [spriteRects] hold four floats per mote, [colors] one
  /// ARGB per mote; only the first [alive] motes are drawn. [points] is the
  /// x/y pair list the points fallback needs when [sprite] is null.
  static void draw(
    Canvas canvas, {
    required ui.Image? sprite,
    required Float32List transforms,
    required Float32List spriteRects,
    required Int32List colors,
    required int alive,
    Float32List? points,
    Color fallbackInk = const Color(0x99FFFFFF),
    ui.Image? atlas,
  }) {
    if (alive <= 0) return;
    final image = atlas ?? sprite;
    if (image == null) {
      if (points == null) return;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.view(points.buffer, points.offsetInBytes, alive * 2),
        Paint()
          ..color = fallbackInk
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.3,
      );
      return;
    }
    canvas.drawRawAtlas(
      image,
      Float32List.view(transforms.buffer, transforms.offsetInBytes, alive * 4),
      Float32List.view(spriteRects.buffer, spriteRects.offsetInBytes, alive * 4),
      Int32List.view(colors.buffer, colors.offsetInBytes, alive),
      BlendMode.modulate,
      null,
      paint,
    );
  }
}

/// Seconds to integrate for the frame at [now], given the previous tick.
///
/// Clamped hard: a dropped frame handed to an integrator is how particle
/// systems explode. The first frame after a start has no previous tick and
/// is taken as one sixtieth.
double dustFrameDt(Duration? last, Duration now) {
  if (last == null) return 1 / 60;
  return ((now - last).inMicroseconds / 1e6).clamp(1 / 240, 1 / 30);
}

/// Smoothstep on 0..1.
double dustSmooth(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

/// A generic emitter: motes spawned anywhere, each with its own velocity,
/// life, size and colour; stepped in place; never reborn. When a mote's life
/// runs out its slot is free again.
///
/// Buffers are allocated once for [capacity] and mutated in place; [spawn]
/// and [step] allocate nothing. The render buffers are compacted on every
/// step so [DustAtlas.draw] can be handed them straight.
class DustMotes {
  DustMotes({required this.capacity, required double dpr, int seed = 0})
      : _rand = math.Random(seed),
        spritePx = DustSprite.pxFor(dpr).toDouble(),
        x = Float32List(capacity),
        y = Float32List(capacity),
        vx = Float32List(capacity),
        vy = Float32List(capacity),
        age = Float32List(capacity),
        life = Float32List(capacity),
        size = Float32List(capacity),
        peak = Float32List(capacity),
        rnd = Float32List(capacity),
        rgb = Int32List(capacity),
        live = Uint8List(capacity),
        transforms = Float32List(capacity * 4),
        spriteRects = Float32List(capacity * 4),
        colors = Int32List(capacity),
        points = Float32List(capacity * 2);

  final int capacity;
  final double spritePx;
  final math.Random _rand;

  final Float32List x, y, vx, vy, age, life, size, peak, rnd;
  final Int32List rgb;
  final Uint8List live;

  /// Render buffers, compacted each step: the first [alive] entries are the
  /// motes to draw.
  final Float32List transforms, spriteRects, points;
  final Int32List colors;
  int alive = 0;

  /// Next slot to try; wraps. Spawning is O(1) amortised while there is
  /// room and gives up (returns -1) when there is none.
  int _cursor = 0;

  /// How many motes are currently living.
  int _living = 0;
  int get living => _living;

  /// Adds a mote. [argb]'s RGB is the tint; its alpha is ignored — the
  /// mote's own fade owns alpha, scaled by [peak]. Returns the slot, or -1
  /// when the emitter is full.
  int spawn({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    required double size,
    required int argb,
    double peak = 1,
  }) {
    if (_living >= capacity) return -1;
    var i = _cursor;
    for (var tries = 0; tries < capacity; tries++) {
      if (live[i] == 0) break;
      i = (i + 1) % capacity;
    }
    if (live[i] != 0) return -1;
    _cursor = (i + 1) % capacity;
    this.x[i] = x;
    this.y[i] = y;
    this.vx[i] = vx;
    this.vy[i] = vy;
    this.life[i] = life <= 0 ? 0.001 : life;
    this.size[i] = size;
    this.peak[i] = peak;
    age[i] = 0;
    rnd[i] = _rand.nextDouble();
    rgb[i] = argb & 0xFFFFFF;
    live[i] = 1;
    _living++;
    return i;
  }

  /// Kills every mote.
  void clear() {
    live.fillRange(0, capacity, 0);
    _living = 0;
    alive = 0;
  }

  /// Advances every living mote by [dt] seconds and refills the render
  /// buffers. [drag] is a per-second velocity decay; [gravity] a downward
  /// acceleration in px/s².
  void step(double dt, {double drag = 0, double gravity = 0}) {
    final decay = drag <= 0 ? 1.0 : math.exp(-drag * dt);
    var k = 0;
    for (var i = 0; i < capacity; i++) {
      if (live[i] == 0) continue;
      age[i] += dt;
      if (age[i] >= life[i]) {
        live[i] = 0;
        _living--;
        continue;
      }
      vx[i] *= decay;
      vy[i] = vy[i] * decay + gravity * dt;
      final px = x[i] += vx[i] * dt;
      final py = y[i] += vy[i] * dt;

      // Alpha: a fade in over the first fifth of a life, a fade out over the
      // last half — a mote that leaves is what most of these are for.
      final u = age[i] / life[i];
      var a = peak[i];
      if (u < 0.2) a *= dustSmooth(u / 0.2);
      if (u > 0.5) a *= 1 - dustSmooth((u - 0.5) / 0.5);
      if (a < 0.02) continue;

      final s = size[i] / spritePx;
      final o = k * 4;
      transforms[o] = s;
      transforms[o + 1] = 0;
      transforms[o + 2] = px - spritePx * s / 2;
      transforms[o + 3] = py - spritePx * s / 2;
      spriteRects[o] = 0;
      spriteRects[o + 1] = 0;
      spriteRects[o + 2] = spritePx;
      spriteRects[o + 3] = spritePx;
      colors[k] = ((a * 255).round() << 24) | rgb[i];
      points[2 * k] = px;
      points[2 * k + 1] = py;
      k++;
    }
    alive = k;
  }
}
