import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../theme/perf_tier.dart';
import 'dust_kit.dart';

/// Telegram's spoiler grain: what one mote of a spoiler is.
///
/// Shared by both spoiler fields, the interactive one over hidden words
/// (`SpoilerVeil`) and the ambient one over hidden media ([SpoilerDust]), so a
/// spoiler looks like the same stuff wherever it is.
///
/// Three grains: fine dust carries the mass (many, small and dim, so that
/// together they read as haze), a few larger motes carry the depth, and a
/// handful of sparkles carry the light. Each drifts in a straight line of its
/// own at a walking pace, fades in over the first quarter of its life and out
/// over the last third, and is reborn somewhere else.
abstract final class SpoilerGrain {
  /// Draws one grain's size (logical px) and peak alpha into [size] and
  /// [peak] at [i]; returns whether it is a sparkle. [floor] is the smallest
  /// size that still registers on this screen ([floorFor]).
  static bool pick(
    math.Random r,
    double floor,
    Float32List size,
    Float32List peak,
    int i,
  ) {
    final t = r.nextDouble();
    var sparkle = false;
    if (t < 0.74) {
      size[i] = 0.7 + r.nextDouble() * 0.45;
      peak[i] = 0.22 + r.nextDouble() * 0.3;
    } else if (t < 0.96) {
      size[i] = 1.1 + r.nextDouble() * 0.5;
      peak[i] = 0.45 + r.nextDouble() * 0.3;
    } else {
      size[i] = 1.7 + r.nextDouble() * 0.6;
      peak[i] = 0.85 + r.nextDouble() * 0.15;
      sparkle = true;
    }
    if (size[i] < floor) size[i] = floor;
    return sparkle;
  }

  /// On a 1x or 2x screen a sub-1.2px dot bilinear-filters into nothing.
  static double floorFor(double dpr) => dpr <= 2 ? 1.1 : 0.75;

  /// A grain's own drift, px/s.
  static double speed(math.Random r) => 3 + r.nextDouble() * 9;

  /// A grain's life, seconds.
  static double life(math.Random r) => 0.9 + r.nextDouble() * 1.5;

  /// Alpha over a life [u] (0..1), as a share of the grain's peak: in over
  /// the first quarter, out over the last third.
  static double envelope(double u) {
    var a = 1.0;
    if (u < 0.25) a *= dustSmooth(u / 0.25);
    if (u > 0.7) a *= 1 - dustSmooth((u - 0.7) / 0.3);
    return a;
  }

  /// The current every grain rides, px/s, at ([px], [py]) and [time]
  /// seconds: the curl of a slowly turning scalar field, so it is
  /// divergence-free (motes are bent, never herded) and zero-mean, so there
  /// is no direction to the field for the eye to catch.
  static double flowX(double px, double py, double time) =>
      -3.0 * DustTrig.sin(px / 90 + time / 16) * DustTrig.sin(py / 40 - time / 21);

  static double flowY(double px, double py, double time) =>
      -1.3 *
      DustTrig.sin(px / 90 + time / 16 + 0.25) *
      DustTrig.sin(py / 40 - time / 21 + 0.25);

  /// A sparkle's twinkle at [time] seconds, given its own random [rnd].
  static double twinkle(double time, double rnd) =>
      0.55 + 0.45 * DustTrig.sin(time * 1.4 + rnd * 7);
}

/// The spoiler over hidden media: the message-bubble spoiler's dust (same
/// [SpoilerGrain]s, same current) as a living field filling
/// its box (or the oval inscribed in it), the media's own blur showing
/// through — Telegram's "hidden, but there".
///
/// **Closed form.** A grain's whole life is a function of the time: its
/// table entry fixes its heading, pace, life and grain; which life it is on
/// (`time / life`) seeds where that life starts, through a hash. Nothing is
/// stepped, nothing is stored per instance but the render buffers, and every
/// instance reads one shared static table — a chat with five sealed notes
/// holds one table, not five fields.
///
/// **Cost.** One `drawRawAtlas` per frame off the shared soft-dot sprite;
/// no allocation per frame (the buffers are sized to the box and kept). The
/// work happens in `paint`, so a box the list has scrolled out of view but
/// kept alive does no particle math at all: only its ticker fires. The ticker
/// is a [TickerMode]-aware one (a covering route or an inactive tab stops it)
/// and repaints at most 60 times a second, whatever the display's rate.
///
/// **One clock.** Every field reads the frame clock, not a clock of its own,
/// so two fields with the same [seed] show the same grains at the same
/// instant. A widget that is swapped for another mid-flight (an upload's
/// circle handing over to the sent one) therefore carries on grain for grain,
/// and one that comes up where a field with its seed was showing a moment ago
/// skips its fade-in ([wasShowing]).
///
/// **In and out.** A field fades in over [fade] when it first appears (or
/// when [active] turns on) and out when [active] turns off; once out, its
/// ticker stops and it paints nothing.
///
/// **Reduced motion** ([MediaQuery.disableAnimationsOf]): no ticker, one
/// still speckle, no fades.
class SpoilerDust extends StatefulWidget {
  const SpoilerDust({
    super.key,
    this.color = const Color(0xFFFFFFFF),
    this.oval = false,
    this.seed = 0,
    this.density = defaultDensity,
    this.maxGrains = defaultMaxGrains,
    this.brightness = 1,
    this.active = true,
    this.fade = defaultFade,
    this.draught,
  });

  /// The grains' ink. Its alpha is ignored; each grain's own fade owns it.
  final Color color;

  /// Fill the oval inscribed in the box instead of the box, with no clip:
  /// grains outside it are simply not drawn.
  final bool oval;

  /// Picks where in the shared table this field reads, so two fields side
  /// by side do not move in step, and one field rebuilt as another (same
  /// seed) does not jump.
  final int seed;

  /// Grains per square logical pixel.
  final double density;

  /// Grains at most, however big the box.
  final int maxGrains;

  /// Scales every grain's peak alpha (clamped to 1): over a dark blur a
  /// field wants to be a little brighter than over a line of text.
  final double brightness;

  /// False fades the field out (and then stops it); true fades it in.
  final bool active;

  /// How long a fade in or out takes.
  final Duration fade;

  /// A fingertip on the field, in its own box, or null: the grains near it
  /// are thrown aside, as the text spoiler's are, and settle back where they
  /// were when it lifts. Null (every field that is only looked at) leaves the
  /// field exactly as it is without one.
  final ValueListenable<Offset?>? draught;

  /// How far a fingertip's draught reaches, logical px.
  static const double draughtRadius = 46;

  /// About one grain per 8pt²: a sealed 200pt circle carries ~3000, dense
  /// enough to read as a haze with sparkles in it, not a scatter of dots.
  static const double defaultDensity = 1 / 8;

  static const int defaultMaxGrains = 3200;

  static const Duration defaultFade = Duration(milliseconds: 280);

  /// Seed → the last frame time (seconds) a field with it was on screen.
  static final Map<int, double> _seen = {};

  /// A field with [seed] was on screen within the last half second: a new
  /// one with the same seed is that field carried on, not a new arrival.
  static bool wasShowing(int seed) {
    final last = _seen[seed];
    return last != null && _clock() - last < 0.5;
  }

  /// The frame clock, seconds. Shared by every field. Between frames (when
  /// the binding has no frame time to give) it is the last frame's.
  static double _clock() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.idle) {
      _lastFrame = binding.currentFrameTimeStamp.inMicroseconds / 1e6;
    }
    return _lastFrame;
  }

  static double _lastFrame = 0;

  @override
  State<SpoilerDust> createState() => _SpoilerDustState();
}

class _SpoilerDustState extends State<SpoilerDust>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  final _SpoilerBuffers _buffers = _SpoilerBuffers();
  double _lastPaint = -1;
  double _lastTick = -1;
  bool _calm = false;

  /// Where a still field (reduced motion) is frozen.
  static const double _stillAt = 1.7;

  @override
  void initState() {
    super.initState();
    // Carried on from a field with this seed that was just showing: from
    // where it was (then in or out as [active] says), not from nothing.
    _buffers.level = SpoilerDust.wasShowing(widget.seed) ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant SpoilerDust old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active || old.seed != widget.seed) _sync();
  }

  void _sync() {
    if (_calm) {
      _ticker?.stop();
      _buffers.level = widget.active ? 1 : 0;
      _time.value = _stillAt;
      return;
    }
    final wanted = widget.active || _buffers.level > 0;
    final t = _ticker ??= createTicker(_onTick);
    if (wanted && !t.isActive) {
      _lastTick = -1;
      t.start();
    } else if (!wanted && t.isActive) {
      t.stop();
    }
  }

  void _onTick(Duration _) {
    final now = SpoilerDust._clock();
    final dt = _lastTick < 0 ? 0.0 : (now - _lastTick).clamp(0.0, 0.1);
    _lastTick = now;
    final step = widget.fade.inMicroseconds <= 0
        ? 1.0
        : dt * 1e6 / widget.fade.inMicroseconds;
    var level = _buffers.level;
    level = widget.active
        ? math.min(1.0, level + step)
        : math.max(0.0, level - step);
    _buffers.level = level;
    if (level > 0) SpoilerDust._seen[widget.seed] = now;
    if (SpoilerDust._seen.length > 256) SpoilerDust._seen.clear();
    if (level <= 0 && !widget.active) {
      _ticker?.stop();
      _time.value = now;
      return;
    }
    // Sixty a second is all the drift needs; a 120Hz display would double
    // the particle math for nothing the eye can see at these speeds. On a
    // low-tier phone, thirty: the drift is slow enough that it still reads
    // as drift, at half the work of every sealed picture on screen.
    if (now - _lastPaint < (Perf.low ? 0.033 : 0.0155)) return;
    _lastPaint = now;
    _time.value = now;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _SpoilerPainter(
            time: _time,
            buffers: _buffers,
            rgb: widget.color.toARGB32() & 0xFFFFFF,
            oval: widget.oval,
            seed: widget.seed,
            density: widget.density,
            maxGrains: widget.maxGrains,
            brightness: widget.brightness,
            dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 2,
            draught: widget.draught,
          ),
          child: const SizedBox.expand(),
        ),
      );
}

/// The shared grains: [n] lives' worth of heading, pace, life, phase and
/// grain, drawn once per run of the app.
abstract final class _SpoilerTable {
  static const int n = 4096;
  static final Float32List dirX = Float32List(n), dirY = Float32List(n);
  static final Float32List life = Float32List(n), phase = Float32List(n);
  static final Float32List size = Float32List(n), peak = Float32List(n);
  static final Float32List rnd = Float32List(n);
  static final Uint8List sparkle = Uint8List(n);
  static double _floor = -1;

  /// Built for a screen's grain floor; rebuilt only if that changes.
  static void ensure(double floor) {
    if (_floor == floor) return;
    _floor = floor;
    final r = math.Random(0x5B01);
    for (var i = 0; i < n; i++) {
      final heading = r.nextDouble();
      final pace = SpoilerGrain.speed(r);
      dirX[i] = DustTrig.cos(heading) * pace;
      dirY[i] = DustTrig.sin(heading) * pace;
      life[i] = SpoilerGrain.life(r);
      phase[i] = r.nextDouble();
      rnd[i] = r.nextDouble();
      sparkle[i] = SpoilerGrain.pick(r, floor, size, peak, i) ? 1 : 0;
    }
  }
}

/// One field's render buffers, grown to its grain count and then kept.
class _SpoilerBuffers {
  Float32List transforms = Float32List(0);
  Float32List spriteRects = Float32List(0);
  Int32List colors = Int32List(0);
  int capacity = 0;
  double spritePx = 0;

  /// The field's fade, 0..1.
  double level = 0;

  void ensure(int count, double px) {
    if (count > capacity) {
      capacity = count;
      transforms = Float32List(count * 4);
      spriteRects = Float32List(count * 4);
      colors = Int32List(count);
      spritePx = 0;
    }
    if (spritePx != px) {
      // The sprite rect is the same for every grain: written once.
      spritePx = px;
      for (var k = 0; k < capacity; k++) {
        final o = k * 4;
        spriteRects[o] = 0;
        spriteRects[o + 1] = 0;
        spriteRects[o + 2] = px;
        spriteRects[o + 3] = px;
      }
    }
  }
}

class _SpoilerPainter extends CustomPainter {
  _SpoilerPainter({
    required this.time,
    required this.buffers,
    required this.rgb,
    required this.oval,
    required this.seed,
    required this.density,
    required this.maxGrains,
    required this.brightness,
    required this.dpr,
    this.draught,
  }) : super(
          repaint: draught == null ? time : Listenable.merge([time, draught]),
        );

  final ValueListenable<double> time;
  final _SpoilerBuffers buffers;
  final int rgb;
  final bool oval;
  final int seed;
  final double density;
  final int maxGrains;
  final double brightness;
  final double dpr;
  final ValueListenable<Offset?>? draught;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final touch = draught?.value;
    const reach = SpoilerDust.draughtRadius;
    final level = dustSmooth(buffers.level);
    if (level <= 0) return;
    final sprite = DustSprite.forDpr(dpr);
    if (sprite == null) return;
    _SpoilerTable.ensure(SpoilerGrain.floorFor(dpr));
    final w = size.width, h = size.height;
    final area = oval ? w * h * math.pi / 4 : w * h;
    // Fewer grains on a low-tier phone (see [Perf.particles]); the same
    // haze at arm's length.
    final count = Perf.particles(math.min(maxGrains, (area * density).round()));
    if (count <= 0) return;
    final spritePx = DustSprite.pxFor(dpr).toDouble();
    final b = buffers..ensure(count, spritePx);
    final tr = b.transforms;
    final colors = b.colors;
    const mask = _SpoilerTable.n - 1;
    final base = (seed * 2654435761) & mask;
    final now = time.value;
    final hw = w / 2, hh = h / 2;
    var k = 0;
    for (var i = 0; i < count; i++) {
      final j = (base + i) & mask;
      final life = _SpoilerTable.life[j];
      final t = now + _SpoilerTable.phase[j] * life;
      final cycle = (t / life).floor();
      final age = t - cycle * life;
      var a = _SpoilerTable.peak[j] * brightness;
      if (a > 1) a = 1;
      a *= level;
      a *= SpoilerGrain.envelope(age / life);
      if (_SpoilerTable.sparkle[j] == 1) {
        a *= SpoilerGrain.twinkle(now, _SpoilerTable.rnd[j]);
      }
      if (a < 0.02) continue;
      // Where this life began: a fresh spot per life, from the hash.
      final hu = dustHash(j + seed * 7919, cycle);
      final hv = dustHash(j * 31 + seed + 1, cycle);
      double x, y;
      if (oval) {
        // Uniform over the oval: the square root spreads the radius.
        final r = math.sqrt(hu);
        x = hw + r * DustTrig.cos(hv) * hw;
        y = hh + r * DustTrig.sin(hv) * hh;
      } else {
        x = hu * w;
        y = hv * h;
      }
      // Its own drift, bent by the shared current (read where the life
      // began: over a life of a second or two it barely changes).
      x += (_SpoilerTable.dirX[j] + SpoilerGrain.flowX(x, y, now)) * age;
      y += (_SpoilerTable.dirY[j] + SpoilerGrain.flowY(x, y, now)) * age;
      if (touch != null) {
        // Thrown away from the fingertip, each grain by its own reach, its
        // own strength and its own slant off the radius, all wandering in
        // time. A shared radius and a straight-out push cleared a clean disc
        // that followed the finger about: the fingertip's shape, drawn as a
        // void. This way the dust thins and swirls there, never empties.
        final rj = _SpoilerTable.rnd[j];
        final rr = reach * (0.55 + 0.8 * rj);
        final dx = x - touch.dx, dy = y - touch.dy;
        final d2 = dx * dx + dy * dy;
        if (d2 < rr * rr && d2 > 0.01) {
          final d = math.sqrt(d2);
          final f = 1 - d / rr;
          final strength = 0.3 + 0.7 * ((rj * 7.31) % 1.0);
          final push = f * f * rr * 0.6 * strength;
          var ex = dx / d + DustTrig.sin(rj * 0.9 + 0.25 + now * 0.11) * 0.8;
          var ey = dy / d + DustTrig.sin(rj * 0.9 + now * 0.13) * 0.8;
          final el = math.sqrt(ex * ex + ey * ey);
          if (el > 0.001) {
            ex /= el;
            ey /= el;
          }
          x += ex * push;
          y += ey * push;
        }
      }
      // Grains never leave the shape: past the edge they are not drawn.
      if (oval) {
        final dx = (x - hw) / hw, dy = (y - hh) / hh;
        if (dx * dx + dy * dy > 1) continue;
      } else if (x < 0 || y < 0 || x > w || y > h) {
        continue;
      }
      final s = _SpoilerTable.size[j];
      final sc = s / spritePx;
      final o = k * 4;
      tr[o] = sc;
      tr[o + 1] = 0;
      tr[o + 2] = x - s / 2;
      tr[o + 3] = y - s / 2;
      colors[k] = ((a * 255).round() << 24) | rgb;
      k++;
    }
    DustAtlas.draw(
      canvas,
      sprite: sprite,
      transforms: tr,
      spriteRects: b.spriteRects,
      colors: colors,
      alive: k,
    );
  }

  @override
  bool shouldRepaint(_SpoilerPainter old) =>
      old.rgb != rgb ||
      old.oval != oval ||
      old.seed != seed ||
      old.density != density ||
      old.maxGrains != maxGrains ||
      old.brightness != brightness ||
      old.dpr != dpr ||
      old.draught != draught ||
      !identical(old.buffers, buffers) ||
      old.time != time;

  @override
  bool hitTest(Offset position) => false;
}
