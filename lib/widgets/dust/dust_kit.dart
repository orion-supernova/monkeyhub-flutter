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
