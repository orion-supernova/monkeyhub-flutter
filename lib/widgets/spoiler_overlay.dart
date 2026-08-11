import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../data/spoiler_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import 'paragraph_geometry.dart';

/// The dust veil over a message's spoiler text, and the two ways to clear it.
///
/// Sits as a `Positioned.fill` sibling ABOVE the paragraph (which renders the
/// hidden text normally — layout must be real so the bubble is the right size,
/// and so the reveal uncovers words that were always exactly there).
///
/// **What it looks like, and why.** An opaque plate roughly the bubble's own
/// colour, under a dense field of sub-pixel motes in the text's ink. The plate
/// is the concealment; the dust is what says there is something under here.
/// This is the inverse of what it was: the plate used to be the text INK, so
/// on a dark theme a spoiler was a glowing white slab — the brightest thing on
/// screen, pointing straight at the one thing the sender asked to hide — with
/// a few dozen fat dots on it. Telegram and iMessage both go the other way,
/// and the reason is legible once you see the two side by side.
///
/// **Reveal.** A tap dissolves the whole thing, dust scattering away from the
/// finger. A drag erases a soft-brush stroke from a low-res alpha mask instead,
/// so a half-hearted smudge reveals a half-readable secret — which is the
/// point; once ~85% of the veiled area is clear the remainder goes on its own.
/// Both record the reveal (session-only) in [SpoilerStore]. Tap is detected
/// inside the pan rather than by a second recognizer: [_WipeGestureRecognizer]
/// claims the pointer on down, so a sibling tap recognizer could never win the
/// arena.
///
/// **Calm motion** builds a different thing entirely, per the MotionScope
/// contract: no ticker, no particle buffers allocated at all — a static plate
/// that a single tap fades away. Screen readers get the same tap-reveal
/// through [Semantics] in both modes, because a wipe is not an accessible
/// gesture.
///
/// **Partial state is disposable.** The mask lives in this State and dies with
/// it; scrolling a half-wiped spoiler away re-veils it. Only the full reveal
/// outlives the widget, via the store.
class SpoilerOverlay extends StatefulWidget {
  const SpoilerOverlay({
    super.key,
    required this.paragraphKey,
    required this.ranges,
    required this.contextId,
    required this.cover,
    required this.dust,
    required this.onRevealed,
  });

  /// Key on the paragraph this overlay covers — resolved to a
  /// [RenderParagraph] so the veil rects come from real glyph geometry
  /// (multi-line spoilers yield one box per line).
  final GlobalKey paragraphKey;

  /// The spoiler stretches, in the DISPLAY text's coordinates (the fold's
  /// `spoilerRanges`).
  final List<({int start, int end})> ranges;

  /// What keys the session reveal — the message id.
  final String contextId;

  /// The opaque plate under the dust (see `FormattingSurface.spoilerCover`) —
  /// near enough the bubble's own colour to read as a blank patch of it.
  final Color cover;

  /// Ink of the dust motes (see `FormattingSurface.spoilerDust`) — the text's
  /// own colour, so the field reads as the hidden words ground to powder.
  /// Cannot be derived from [cover] any more: the plate IS the bubble now, so
  /// a cover-derived mote would be invisible against it.
  final Color dust;

  /// Fired once, after the veil has fully dissolved — the host rebuilds and
  /// stops mounting this overlay.
  final VoidCallback onRevealed;

  @override
  State<SpoilerOverlay> createState() => _SpoilerOverlayState();
}

class _SpoilerOverlayState extends State<SpoilerOverlay>
    with TickerProviderStateMixin, ParagraphMeasured<SpoilerOverlay> {
  @override
  GlobalKey get paragraphKey => widget.paragraphKey;

  @override
  List<({int start, int end})> get measuredRanges => widget.ranges;

  /// Grown by 1.5px on both axes so the plate covers the glyphs' own
  /// antialiasing rather than stopping exactly at it.
  @override
  double get measureInsetX => -1.5;
  @override
  double get measureInsetY => -1.5;

  /// [rects] flattened — the veil doesn't care which range a line came from.
  List<Rect> _rects = const [];

  /// One particle field per line rect. Empty under calm motion, and cleared on
  /// re-measure so the next build reseeds against the new geometry.
  List<_DustField> _fields = const [];

  /// Drives the dust drift. Created only outside calm motion.
  AnimationController? _drift;

  /// Drives the reveal — the scatter and the plate's fade. 0 = veil fully
  /// present, 1 = gone. Duration is set per build because calm has no
  /// particles to give travel time to.
  late final AnimationController _dissolve = AnimationController(
    vsync: this,
    duration: _dissolveFull,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SpoilerStore.instance.reveal(widget.contextId);
        widget.onRevealed();
      }
    });

  static const _dissolveFull = Duration(milliseconds: 380);
  static const _dissolveCalm = Duration(milliseconds: 220);

  /// Bumped on every wipe stamp. The painter listens to this instead of the
  /// State calling setState sixty times a second during a drag.
  final ValueNotifier<int> _maskRevision = ValueNotifier<int>(0);

  _WipeMask? _mask;
  bool _dissolving = false;
  Offset? _lastWipePoint;

  /// Where the scatter blows away from — the finger, or the veil's centre for
  /// a reveal that had no touch behind it (the semantics action, or crossing
  /// the wipe threshold).
  Offset _scatterOrigin = Offset.zero;

  /// Tap-vs-drag bookkeeping for the single pan recognizer.
  Offset? _panStart;
  double _panDistance = 0;

  /// Last resolved motion budget. Cached from build so gesture callbacks can
  /// read it without registering an inherited-widget dependency mid-event.
  bool _calm = false;

  @override
  void didUpdateWidget(SpoilerOverlay old) {
    super.didUpdateWidget(old);
    if (old.ranges != widget.ranges) scheduleMeasure();
  }

  @override
  void dispose() {
    _drift?.dispose();
    _dissolve.dispose();
    _maskRevision.dispose();
    super.dispose();
  }

  /// A fresh mask and a fresh particle field per measurement. Re-measuring
  /// mid-wipe therefore re-veils what had been wiped — consistent with partial
  /// state being disposable (see the class doc), and a rotation is not a
  /// subtle event to lose it to.
  @override
  void onMeasured(List<List<Rect>> value) {
    final flat = [for (final group in value) ...group];
    if (flat.isEmpty) return;
    setState(() {
      _rects = flat;
      _mask = _WipeMask.covering(flat);
      _fields = const [];
    });
  }

  void _wipeAt(Offset point) {
    final mask = _mask;
    if (mask == null || _dissolving) return;
    final last = _lastWipePoint;
    // Interpolate between move events so a fast swipe leaves a stroke, not a
    // dotted line of brush stamps.
    if (last != null && (point - last).distance > _WipeMask.cell) {
      final steps = ((point - last).distance / _WipeMask.cell).ceil();
      for (var i = 1; i <= steps; i++) {
        mask.stamp(Offset.lerp(last, point, i / steps)!);
      }
    } else {
      mask.stamp(point);
    }
    _lastWipePoint = point;
    _maskRevision.value++;
    if (mask.clearedFraction >= 0.85) _revealWhole(origin: point);
  }

  void _revealWhole({Offset? origin}) {
    if (_dissolving) return;
    _dissolving = true;
    _scatterOrigin = origin ?? _veilCentre();
    // Calm has no particles to give travel time to, so it keeps the shorter
    // fade the veil always had.
    _dissolve.duration = _calm ? _dissolveCalm : _dissolveFull;
    _dissolve.forward();
  }

  Offset _veilCentre() {
    if (_rects.isEmpty) return Offset.zero;
    var bounds = _rects.first;
    for (final r in _rects.skip(1)) {
      bounds = bounds.expandToInclude(r);
    }
    return bounds.center;
  }

  bool _hitsVeil(Offset localPoint) {
    if (_dissolving) return false;
    final mask = _mask;
    for (final r in _rects) {
      if (r.inflate(4).contains(localPoint)) {
        // A cell the wipe already cleared is open window, not veil — a drag
        // starting there belongs to the transcript again.
        if (mask == null || !mask.isCleared(localPoint)) return true;
      }
    }
    return false;
  }

  /// Whether a pointer-down at this GLOBAL position lands on unrevealed veil.
  bool _hitTestGlobal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    return _hitsVeil(box.globalToLocal(global));
  }

  @override
  Widget build(BuildContext context) {
    // Still armed with nothing to paint: the notifier has to be mounted even
    // in the empty state, or a first measurement that lands before the
    // paragraph is ready has nothing to retry it.
    if (_rects.isEmpty) {
      return watchLayout(child: const SizedBox.expand());
    }
    final motion = MotionScope.of(context);
    _calm = motion.calm;

    // Calm is a code path: no ticker, no particles, no buffers. The
    // controller and the fields for the full effect are simply never created.
    // (Assigning in build mirrors how the drift controller was already
    // managed; build runs on measurement and dependency changes, not per
    // frame — the painter drives itself from `repaint:`.)
    if (motion.calm) {
      _drift?.dispose();
      _drift = null;
      _fields = const [];
    } else {
      _drift ??= AnimationController(
        vsync: this,
        // Long, because every mote's velocity is an integer number of rect
        // widths per period — see [_DustField]. A short loop would make that
        // return-to-start visible as a pulse.
        duration: const Duration(seconds: 20),
      )..repeat();
      if (_fields.isEmpty) _fields = _buildFields();
    }

    final painter = RepaintBoundary(
      child: CustomPaint(
        // Every per-frame input arrives through this Listenable, so neither
        // this widget nor its subtree rebuilds for drift, wipe or dissolve.
        painter: _SpoilerDustPainter(
          repaint: Listenable.merge([
            _drift,
            _dissolve,
            _maskRevision,
            rects,
          ]),
          rectsOf: () => _rects,
          fieldsOf: () => _fields,
          maskOf: () => _mask,
          phaseOf: () => _drift?.value ?? 0,
          dissolveOf: () => _dissolve.value,
          originOf: () => _scatterOrigin,
          cover: widget.cover,
          dust: widget.dust,
          calm: motion.calm,
        ),
        child: const SizedBox.expand(),
      ),
    );

    final semantics = watchLayout(
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context).spoilerRevealHint,
        onTap: _revealWhole,
        child: painter,
      ),
    );

    if (motion.calm) {
      // A tap target scoped to the veil itself, the same way the wipe is:
      // the recognizer only joins the arena when the down lands on dust, so
      // taps on the rest of the paragraph (links included) pass straight
      // through. Being the Stack's top child, it enters the arena before any
      // span recognizer underneath and wins the sweep — a VEILED link must
      // reveal, not open.
      return RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          _VeilTapRecognizer:
              GestureRecognizerFactoryWithHandlers<_VeilTapRecognizer>(
            () => _VeilTapRecognizer(hitTest: _hitTestGlobal),
            (r) => r.onTap = _revealWhole,
          ),
        },
        child: semantics,
      );
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _WipeGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_WipeGestureRecognizer>(
          () => _WipeGestureRecognizer(hitTest: _hitTestGlobal),
          (r) {
            r.onStart = (d) {
              _lastWipePoint = null;
              _panStart = d.localPosition;
              _panDistance = 0;
              _wipeAt(d.localPosition);
            };
            r.onUpdate = (d) {
              final last = _lastWipePoint;
              if (last != null) {
                _panDistance += (d.localPosition - last).distance;
              }
              _wipeAt(d.localPosition);
            };
            r.onEnd = (_) {
              final start = _panStart;
              _panStart = null;
              _lastWipePoint = null;
              // A pointer that went down on dust and came up without
              // travelling is a tap, and a tap reveals the lot. Detected here
              // rather than by a second recognizer because the pan claims the
              // pointer on down and would starve one.
              if (start != null && _panDistance <= kTouchSlop) {
                _revealWhole(origin: start);
              }
            };
            r.onCancel = () {
              _panStart = null;
              _lastWipePoint = null;
            };
          },
        ),
      },
      child: semantics,
    );
  }

  /// Seeds one particle field per line rect, sharing a global mote budget.
  List<_DustField> _buildFields() {
    if (_rects.isEmpty) return const [];
    var wanted = 0;
    for (final r in _rects) {
      wanted += _DustField.wantedFor(r);
    }
    // A whole long message set to spoiler is the pathological case; scale the
    // field down proportionally rather than letting it grow without bound.
    final scale =
        wanted > _DustField.globalCap ? _DustField.globalCap / wanted : 1.0;
    final seed = widget.contextId.hashCode;
    return [
      for (var i = 0; i < _rects.length; i++)
        _DustField.forRect(_rects[i], seed ^ (i * 0x9E3779B1), scale),
    ];
  }
}

/// A pan that exists only on unrevealed dust — and that CLAIMS the pointer
/// the moment it lands there.
///
/// Claiming on down rather than after slop is a deliberate trade. Waiting for
/// slop puts this recognizer in a race against the transcript's vertical
/// scroll and the row's swipe-to-reply, both of which resolve at the same
/// thresholds — a vertical wipe would scroll the list about half the time,
/// which reads as the effect being broken. Claiming immediately makes the
/// wipe deterministic at the cost of the gestures that could otherwise start
/// on the dust: a scroll or long-press begun EXACTLY on an unrevealed veil
/// goes to the veil. The veil is a few words tall, the rest of the bubble
/// still long-presses, and the wiped-open cells hand themselves back (see
/// `_hitsVeil`).
///
/// It also has to serve the tap, for the same reason: a `TapGestureRecognizer`
/// beside it would be resolved against before it ever fired. See the `onEnd`
/// handler.
class _WipeGestureRecognizer extends PanGestureRecognizer {
  _WipeGestureRecognizer({required this.hitTest});

  /// Whether a pointer-down at this GLOBAL position lands on unrevealed veil.
  final bool Function(Offset globalPosition) hitTest;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      hitTest(event.position) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Calm mode's tap-to-reveal, scoped to the veil the same way the wipe is.
class _VeilTapRecognizer extends TapGestureRecognizer {
  _VeilTapRecognizer({required this.hitTest});

  final bool Function(Offset globalPosition) hitTest;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      hitTest(event.position) && super.isPointerAllowed(event);
}

/// One tier of motes over one line rect: same size, same paint, one draw call.
///
/// Tiers exist because `drawRawPoints` takes a single [Paint] for the whole
/// buffer. Four of them buy a field with depth — dim sub-pixel grain carrying
/// the mass, a bright handful carrying the sparkle — for four draw calls per
/// line instead of one `drawCircle` per mote, which is what capped the old
/// field at sixty.
class _DustTier {
  _DustTier(this.count, this.size, this.baseAlpha, this.cycles, this.offset)
      : xy = Float32List(count * 2),
        home = Float32List(count * 2),
        vel = Float32List(count * 2),
        jitter = Float32List(count * 2),
        push = Float32List(count);

  final int count;

  /// `strokeWidth`, which with a round cap is the mote's diameter.
  final double size;
  final double baseAlpha;

  /// Whole twinkle cycles per drift period — integral so the loop stays
  /// seamless, and mutually near-coprime across tiers so the field never
  /// pulses as one.
  final int cycles;
  final double offset;

  /// Live positions. The ONLY buffer written per frame, and the one handed
  /// straight to `drawRawPoints`.
  final Float32List xy;

  /// Resting position relative to the rect's origin, so wrapping is a compare
  /// against the rect's own width with no subtraction.
  final Float32List home;

  /// Travel per full period, always an integer number of rect widths/heights.
  final Float32List vel;

  /// Per-mote randomness in the scatter, so the blast isn't a clean radial.
  final Float32List jitter;

  /// How hard the scatter throws this mote away from the reveal's origin.
  final Float32List push;
}

/// The particle field over one line rect.
///
/// Buffers are allocated once, when the geometry is measured, and mutated in
/// place every frame — nothing here allocates inside `paint`.
class _DustField {
  _DustField._(this.rect, this.tiers);

  final Rect rect;
  final List<_DustTier> tiers;

  /// Roughly one mote per 7px². Dense enough to read as static rather than as
  /// dots, which is the entire difference between this and what it replaced.
  static int wantedFor(Rect r) =>
      (r.width * r.height / 7).round().clamp(32, 1600);

  static const int globalCap = 5000;

  /// share, strokeWidth, base alpha, |drift| in rect-widths, twinkle cycles.
  static const _spec = <(double, double, double, int, int)>[
    (0.46, 0.7, 0.30, 1, 17),
    (0.30, 1.0, 0.45, 2, 23),
    (0.18, 1.4, 0.62, 2, 29),
    (0.06, 2.0, 0.85, 3, 37),
  ];

  factory _DustField.forRect(Rect rect, int seed, double scale) {
    final rand = math.Random(seed);
    final total = (wantedFor(rect) * scale).round().clamp(8, 1600);
    final w = rect.width;
    final h = rect.height;

    final tiers = <_DustTier>[];
    var assigned = 0;
    for (var t = 0; t < _spec.length; t++) {
      final (share, size, alpha, drift, cycles) = _spec[t];
      // The last tier takes the remainder so rounding can't lose motes — or
      // go negative on a field small enough for three roundings to overshoot.
      final count = t == _spec.length - 1
          ? math.max(0, total - assigned)
          : (total * share).round();
      assigned += count;
      if (count <= 0) continue;

      final tier = _DustTier(count, size, alpha, cycles, 0.19 + t * 0.21);
      for (var i = 0; i < count; i++) {
        tier.home[2 * i] = rand.nextDouble() * w;
        tier.home[2 * i + 1] = rand.nextDouble() * h;
        // Integer multiples, so every mote is exactly home again at phase 1
        // and the repeat has no seam. Sign is random; magnitude grows with
        // the tier, so the brighter motes read as nearer.
        final dirX = rand.nextBool() ? 1 : -1;
        final dirY = rand.nextBool() ? 1 : -1;
        tier.vel[2 * i] = dirX * drift * w;
        // Vertical is always a single rect-height: dust drifts sideways, and
        // a line rect is short enough that more reads as jitter.
        tier.vel[2 * i + 1] = dirY * h;
        tier.jitter[2 * i] = (rand.nextDouble() - 0.5) * 16;
        tier.jitter[2 * i + 1] = (rand.nextDouble() - 0.5) * 16;
        tier.push[i] = 10 + rand.nextDouble() * 26;
      }
      tiers.add(tier);
    }
    return _DustField._(rect, tiers);
  }

  /// Writes this frame's positions into every tier's [_DustTier.xy].
  ///
  /// [scatter] is 0 for a veil at rest and rises to 1 through the reveal;
  /// above 0 the wrap is abandoned and motes fly away from [origin].
  void update(double phase, double scatter, Offset origin) {
    final w = rect.width;
    final h = rect.height;
    final s = scatter * scatter;
    for (final tier in tiers) {
      final xy = tier.xy;
      final home = tier.home;
      final vel = tier.vel;
      for (var i = 0; i < tier.count; i++) {
        final ix = 2 * i;
        final iy = ix + 1;
        // |vel| is at most 3 rect-widths, so these loops run at most 4 times
        // and beat a `%` on both clarity and the sign question.
        var ux = home[ix] + vel[ix] * phase;
        while (ux < 0) {
          ux += w;
        }
        while (ux >= w) {
          ux -= w;
        }
        var uy = home[iy] + vel[iy] * phase;
        while (uy < 0) {
          uy += h;
        }
        while (uy >= h) {
          uy -= h;
        }
        final px = rect.left + ux;
        final py = rect.top + uy;
        if (s <= 0) {
          xy[ix] = px;
          xy[iy] = py;
          continue;
        }
        var dx = px - origin.dx;
        var dy = py - origin.dy;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 0.001) {
          dx /= dist;
          dy /= dist;
        } else {
          dx = 0;
          dy = -1;
        }
        final shove = tier.push[i];
        xy[ix] = px + (dx * shove + tier.jitter[ix]) * s;
        // A touch of updraft, so the field lifts as it thins instead of
        // simply expanding.
        xy[iy] = py + (dy * shove + tier.jitter[iy]) * s - 14 * s;
      }
    }
  }
}

/// The wipe's memory: a low-res alpha grid over the veiled area.
///
/// ~7-logical-px cells are far below glyph size, so the wiped hole follows
/// the finger convincingly while the whole mask for a long spoiler stays a
/// few kilobytes. Values are 0 (veiled) to 1 (clear); the brush writes a
/// soft falloff so stroke edges feather instead of stair-stepping.
class _WipeMask {
  _WipeMask._(this.bounds, this.cols, this.rows, this.values, this.weights)
      : _totalWeight = weights.fold(0, (a, b) => a + b);

  static const double cell = 7;

  /// Brush radius. About a fingertip's core contact patch — big enough that
  /// wiping feels like wiping, small enough that partial reveals are real.
  static const double brush = 20;

  final Rect bounds;
  final int cols;
  final int rows;
  final Float32List values;

  /// 1 for cells whose centre sits inside a veil rect, else 0 — only those
  /// count toward [clearedFraction], so the bounding box's empty corners
  /// can't be "wiped" to cheat the threshold.
  final Float32List weights;
  final double _totalWeight;

  /// Cell-index bounds of everything ever stamped, so the painter iterates
  /// the wiped region rather than the whole grid every frame. Inverted while
  /// nothing has been touched, which is also how [clean] is answered.
  int dirtyMinX = 1 << 30;
  int dirtyMaxX = -1;
  int dirtyMinY = 1 << 30;
  int dirtyMaxY = -1;

  /// Nothing has been wiped — the overwhelmingly common state, and the one
  /// where the painter can skip its offscreen layer entirely.
  bool get clean => dirtyMaxX < dirtyMinX;

  factory _WipeMask.covering(List<Rect> rects) {
    var bounds = rects.first;
    for (final r in rects.skip(1)) {
      bounds = bounds.expandToInclude(r);
    }
    final cols = math.max(1, (bounds.width / cell).ceil());
    final rows = math.max(1, (bounds.height / cell).ceil());
    final values = Float32List(cols * rows);
    final weights = Float32List(cols * rows);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final centre = Offset(
          bounds.left + (x + 0.5) * cell,
          bounds.top + (y + 0.5) * cell,
        );
        if (rects.any((r) => r.contains(centre))) {
          weights[y * cols + x] = 1;
        }
      }
    }
    return _WipeMask._(bounds, cols, rows, values, weights);
  }

  void stamp(Offset point) {
    final minX = ((point.dx - brush - bounds.left) / cell).floor();
    final maxX = ((point.dx + brush - bounds.left) / cell).ceil();
    final minY = ((point.dy - brush - bounds.top) / cell).floor();
    final maxY = ((point.dy + brush - bounds.top) / cell).ceil();
    for (var y = math.max(0, minY); y <= math.min(rows - 1, maxY); y++) {
      for (var x = math.max(0, minX); x <= math.min(cols - 1, maxX); x++) {
        final centre = Offset(
          bounds.left + (x + 0.5) * cell,
          bounds.top + (y + 0.5) * cell,
        );
        final d = (centre - point).distance;
        if (d > brush) continue;
        final fall = 1 - (d / brush);
        final i = y * cols + x;
        values[i] = math.min(1, values[i] + fall * fall * 1.6);
        if (x < dirtyMinX) dirtyMinX = x;
        if (x > dirtyMaxX) dirtyMaxX = x;
        if (y < dirtyMinY) dirtyMinY = y;
        if (y > dirtyMaxY) dirtyMaxY = y;
      }
    }
  }

  bool isCleared(Offset point) {
    final x = ((point.dx - bounds.left) / cell).floor();
    final y = ((point.dy - bounds.top) / cell).floor();
    if (x < 0 || x >= cols || y < 0 || y >= rows) return false;
    return values[y * cols + x] >= 0.75;
  }

  double get clearedFraction {
    if (_totalWeight == 0) return 0;
    var cleared = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (weights[i] > 0) cleared += math.min(1, values[i]);
    }
    return cleared / _totalWeight;
  }
}

/// Paints the veil: the plate, the dust over it, and the wipe holes punched
/// through both.
///
/// Every per-frame value arrives through a getter closure and the whole thing
/// is scheduled by `repaint:`, so nothing above this rebuilds for an
/// animation frame or a pan event.
class _SpoilerDustPainter extends CustomPainter {
  _SpoilerDustPainter({
    required Listenable repaint,
    required this.rectsOf,
    required this.fieldsOf,
    required this.maskOf,
    required this.phaseOf,
    required this.dissolveOf,
    required this.originOf,
    required this.cover,
    required this.dust,
    required this.calm,
  }) : super(repaint: repaint);

  final List<Rect> Function() rectsOf;
  final List<_DustField> Function() fieldsOf;
  final _WipeMask? Function() maskOf;
  final double Function() phaseOf;
  final double Function() dissolveOf;
  final Offset Function() originOf;
  final Color cover;
  final Color dust;
  final bool calm;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = rectsOf();
    if (rects.isEmpty) return;
    final dissolve = dissolveOf();
    if (dissolve >= 1) return;

    final mask = maskOf();
    final holed = mask != null && !mask.clean;

    // The offscreen exists only so `dstOut` can erase this painter's own
    // pixels without touching the text underneath. Untouched veils — almost
    // all of them, almost all of the time — skip it entirely; the old painter
    // allocated one every frame forever.
    if (holed) canvas.saveLayer(Offset.zero & size, Paint());

    // 1. The plate. Fully opaque, and the opacity IS the concealment: with
    //    the plate now the bubble's own colour rather than a bar of ink,
    //    there is nothing to gain from the 4% that used to leak through.
    //    Fading it faster than the dust lets the words surface first.
    final plateAlpha =
        1 - Curves.easeIn.transform((dissolve / 0.55).clamp(0, 1));
    if (plateAlpha > 0.004) {
      final fill = Paint()..color = cover.withValues(alpha: plateAlpha);
      for (final r in rects) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          fill,
        );
      }
    }

    // 2. The dust. One draw call per tier per line — thousands of motes for
    //    the cost the old field paid for sixty. Skipped entirely under calm;
    //    the static plate is the whole effect there.
    if (!calm) {
      final phase = phaseOf();
      final origin = originOf();
      final fade = math.pow(1 - dissolve, 1.6).toDouble();
      final mote = Paint()..strokeCap = StrokeCap.round;
      for (final field in fieldsOf()) {
        field.update(phase, dissolve, origin);
        for (final tier in field.tiers) {
          final twinkle = 0.78 +
              0.22 *
                  math.sin(2 *
                      math.pi *
                      (phase * tier.cycles + tier.offset));
          final alpha = (tier.baseAlpha * twinkle * fade).clamp(0.0, 1.0);
          if (alpha <= 0.004) continue;
          mote
            ..color = dust.withValues(alpha: alpha)
            ..strokeWidth = tier.size * (1 + 0.5 * dissolve);
          canvas.drawRawPoints(PointMode.points, tier.xy, mote);
        }
      }
    }

    // 3. The holes. Each cleared cell erases this layer's pixels by its own
    //    alpha, so the reveal has the brush's feathered edge.
    //
    //    Order matters and is not cosmetic: `dstOut` removes what is already
    //    in the layer, so running it AFTER the dust deletes plate and motes
    //    together. Motes drawn after the holes would float over text the user
    //    has already uncovered.
    if (holed) {
      final hole = Paint()..blendMode = BlendMode.dstOut;
      for (var y = mask.dirtyMinY; y <= mask.dirtyMaxY; y++) {
        for (var x = mask.dirtyMinX; x <= mask.dirtyMaxX; x++) {
          final v = mask.values[y * mask.cols + x];
          if (v <= 0.01) continue;
          hole.color = Color.fromRGBO(0, 0, 0, math.min(1, v));
          canvas.drawRect(
            Rect.fromLTWH(
              mask.bounds.left + x * _WipeMask.cell,
              mask.bounds.top + y * _WipeMask.cell,
              _WipeMask.cell + 0.5,
              _WipeMask.cell + 0.5,
            ),
            hole,
          );
        }
      }
      canvas.restore();
    }
  }

  /// Everything that changes per frame is scheduled by `repaint:`; this only
  /// has to answer for the values baked into the instance.
  @override
  bool shouldRepaint(_SpoilerDustPainter old) =>
      old.cover != cover || old.dust != dust || old.calm != calm;
}
