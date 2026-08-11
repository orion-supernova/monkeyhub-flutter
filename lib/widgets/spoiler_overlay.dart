import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../data/spoiler_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import 'paragraph_geometry.dart';

/// The dust veil over a message's spoiler text, and everything that happens
/// when a finger touches it.
///
/// Sits as a `Positioned.fill` sibling ABOVE the paragraph (which renders the
/// hidden text normally — layout must be real so the bubble is the right size,
/// and so the reveal uncovers words that were always exactly there).
///
/// **The plate is the bubble.** Exactly [cover], which callers set to the
/// bubble's own painted fill, so there is no rectangle, no edge and no corner
/// to see — only a stretch of bubble where words should be, with dust moving
/// over it. It used to be the text INK, i.e. a glowing white slab on a dark
/// theme, and then briefly a measured step off the bubble, which still read as
/// a box. Opaque, and the opacity is the concealment: the dust is texture, not
/// privacy.
///
/// **The finger pushes the dust.** Motes inside [_repelRadius] of a moving
/// touch take an impulse away from it and carry it with momentum, so the dust
/// parts around a fingertip and drifts back after it leaves. This is separate
/// from the wipe: pushing dust aside does not reveal anything.
///
/// **Reveal is a wavefront.** A tap opens a disc of clear text from the touch
/// point outward, dust blowing ahead of its edge. A drag instead erases a
/// soft-brush stroke from a low-res alpha mask, so a partial swipe reveals
/// exactly what it touched and no more; a drag is never mistaken for a tap.
///
/// **Nothing stays open.** A full reveal holds for [_holdFor] and then runs
/// the wavefront backwards — the dust closes over the words again. A partial
/// wipe heals the same way. Leaving the room re-veils everything (see
/// [SpoilerStore]).
///
/// **Calm motion** builds a different thing entirely, per the MotionScope
/// contract: no ticker, no particle buffers allocated at all — a static plate
/// that a single tap fades away, and that heals on the same timer. Screen
/// readers get the same tap-reveal through [Semantics] in both modes, because
/// a wipe is not an accessible gesture.
class SpoilerOverlay extends StatefulWidget {
  const SpoilerOverlay({
    super.key,
    required this.paragraphKey,
    required this.ranges,
    required this.contextId,
    required this.cover,
    required this.dust,
  });

  /// Key on the paragraph this overlay covers — resolved to a
  /// [RenderParagraph] so the veil rects come from real glyph geometry
  /// (multi-line spoilers yield one box per line).
  final GlobalKey paragraphKey;

  /// The spoiler stretches, in the DISPLAY text's coordinates (the fold's
  /// `spoilerRanges`).
  final List<({int start, int end})> ranges;

  /// What keys the open state in the session store — the message id.
  final String contextId;

  /// The plate, painted opaque. The bubble's own fill (see
  /// `FormattingSurface.spoilerCover`), so the veiled stretch is invisible as
  /// a shape and legible only as an absence of words.
  final Color cover;

  /// Ink of the dust motes (see `FormattingSurface.spoilerDust`) — the text's
  /// own colour, so the field reads as the hidden words ground to powder.
  final Color dust;

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

  /// How long a reveal stands before the dust closes back over it. Scaled by
  /// how much there is to read — a two-word spoiler does not need the window a
  /// paragraph does — and floored at something you cannot miss.
  Duration get _holdFor {
    var chars = 0;
    for (final r in widget.ranges) {
      chars += r.end - r.start;
    }
    return Duration(
      milliseconds: (2500 + chars * 60).clamp(5000, 18000),
    );
  }

  /// How far a moving touch pushes dust around itself.
  static const double _repelRadius = 52;

  static const _revealIn = Duration(milliseconds: 420);
  static const _revealOut = Duration(milliseconds: 760);
  static const _healOut = Duration(milliseconds: 700);

  /// [rects] flattened — the veil doesn't care which range a line came from.
  List<Rect> _rects = const [];

  /// One particle field per line rect. Empty under calm motion, and cleared on
  /// re-measure so the next build reseeds against the new geometry.
  List<_DustField> _fields = const [];

  /// Drives the dust drift. Created only outside calm motion.
  AnimationController? _drift;

  /// The reveal wavefront. 0 = veiled, 1 = fully open. Runs forward on a tap
  /// and backwards when the hold expires.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _revealIn,
    reverseDuration: _revealOut,
  )..addStatusListener(_onRevealStatus);

  /// Fades a partial wipe's holes back to nothing. 0 = holes intact.
  late final AnimationController _heal = AnimationController(
    vsync: this,
    duration: _healOut,
  )..addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      _mask?.reset();
      _heal.value = 0;
      _maskRevision.value++;
    });

  /// Bumped whenever the mask or the touch moves. The painter listens to this
  /// instead of the State calling setState sixty times a second during a drag.
  final ValueNotifier<int> _maskRevision = ValueNotifier<int>(0);

  /// Where the finger is, in local coordinates, or null when it is not down.
  final ValueNotifier<Offset?> _touch = ValueNotifier<Offset?>(null);

  _WipeMask? _mask;
  Offset? _lastWipePoint;

  /// Pending re-veil, for a full reveal or a partial wipe.
  Timer? _healTimer;

  /// Centre of the reveal wavefront.
  Offset _waveOrigin = Offset.zero;

  /// Tap-vs-drag bookkeeping for the single pan recognizer.
  double _panDistance = 0;

  /// A pointer that moves more than this is a wipe, full stop. Well under
  /// `kTouchSlop`, because a deliberate short swipe over two words must stay a
  /// partial reveal — treating it as a tap would blow the whole spoiler open,
  /// which is the opposite of what the gesture asked for.
  static const double _tapSlop = 6;

  /// Last resolved motion budget. Cached from build so gesture callbacks can
  /// read it without registering an inherited-widget dependency mid-event.
  bool _calm = false;

  bool get _open => _reveal.value >= 1;

  @override
  void initState() {
    super.initState();
    // Mounting onto an already-open message (a rebuild in place, or a row
    // recycled while the text was showing) picks the state up and restarts the
    // hold, so an entry in the store can never strand a spoiler readable.
    if (SpoilerStore.instance.isRevealed(widget.contextId)) {
      _reveal.value = 1;
      _scheduleHeal();
    }
  }

  @override
  void didUpdateWidget(SpoilerOverlay old) {
    super.didUpdateWidget(old);
    if (old.ranges != widget.ranges) scheduleMeasure();
  }

  @override
  void dispose() {
    _healTimer?.cancel();
    _drift?.dispose();
    _reveal.dispose();
    _heal.dispose();
    _maskRevision.dispose();
    _touch.dispose();
    super.dispose();
  }

  /// A fresh mask and a fresh particle field per measurement. Re-measuring
  /// mid-wipe therefore re-veils what had been wiped — consistent with partial
  /// state being disposable, and a rotation is not a subtle event to lose it
  /// to.
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

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      SpoilerStore.instance.reveal(widget.contextId);
      // Nothing to animate while the words are simply readable.
      _drift?.stop();
      _scheduleHeal();
    } else if (status == AnimationStatus.dismissed) {
      SpoilerStore.instance.conceal(widget.contextId);
      if (!_calm) _drift?.repeat();
    }
  }

  /// Arms the re-veil. Any new interaction cancels and re-arms it.
  void _scheduleHeal() {
    _healTimer?.cancel();
    _healTimer = Timer(_holdFor, () {
      if (!mounted) return;
      if (_open) {
        if (!_calm) _drift?.repeat();
        _reveal.reverse();
      } else if (_mask != null && !_mask!.clean) {
        _heal.forward(from: 0);
      }
    });
  }

  void _wipeAt(Offset point) {
    final mask = _mask;
    if (mask == null || _reveal.value > 0) return;
    // A stroke onto healing holes takes them over rather than fighting the
    // fade.
    if (_heal.isAnimating) {
      _heal
        ..stop()
        ..value = 0;
    }
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
    if (_reveal.value > 0 || _reveal.isAnimating) return;
    _waveOrigin = origin ?? _veilCentre();
    _reveal.forward();
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
    if (_reveal.value > 0) return false;
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
    final motion = MotionScope.of(context);
    // Cached before the early return: a spoiler that mounts already open
    // heals without ever having had geometry, and the heal reads this.
    _calm = motion.calm;

    // Still armed with nothing to paint: the notifier has to be mounted even
    // in the empty state, or a first measurement that lands before the
    // paragraph is ready has nothing to retry it.
    if (_rects.isEmpty) {
      return watchLayout(child: const SizedBox.expand());
    }

    // Calm is a code path: no ticker, no particles, no buffers. The
    // controller and the fields for the full effect are simply never created.
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
      );
      if (_fields.isEmpty) _fields = _buildFields();
      // Not while the words are simply readable.
      if (!_open && !_drift!.isAnimating) _drift!.repeat();
    }

    final painter = RepaintBoundary(
      child: CustomPaint(
        // Every per-frame input arrives through this Listenable, so neither
        // this widget nor its subtree rebuilds for drift, wipe, touch or
        // reveal.
        painter: _SpoilerDustPainter(
          repaint: Listenable.merge([
            _drift,
            _reveal,
            _heal,
            _maskRevision,
            _touch,
            rects,
          ]),
          rectsOf: () => _rects,
          fieldsOf: () => _fields,
          maskOf: () => _mask,
          phaseOf: () => _drift?.value ?? 0,
          revealOf: () => _reveal.value,
          healOf: () => _heal.value,
          touchOf: () => _touch.value,
          originOf: () => _waveOrigin,
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
              _panDistance = 0;
              _healTimer?.cancel();
              _mask?.lift();
              _touch.value = d.localPosition;
              _wipeAt(d.localPosition);
            };
            r.onUpdate = (d) {
              final last = _lastWipePoint;
              if (last != null) {
                _panDistance += (d.localPosition - last).distance;
              }
              _touch.value = d.localPosition;
              _wipeAt(d.localPosition);
            };
            r.onEnd = (_) {
              final moved = _panDistance;
              final liftedAt = _touch.value ?? _lastWipePoint;
              _lastWipePoint = null;
              _touch.value = null;
              // A pointer that went down on dust and came up without
              // travelling is a tap, and a tap opens the lot. Anything that
              // MOVED is a wipe, however short — a swipe over two words is a
              // request to see those two words, so it keeps exactly the
              // partial reveal it earned and then heals.
              if (moved <= _tapSlop) {
                _revealWhole(origin: liftedAt);
              } else {
                _scheduleHeal();
              }
            };
            r.onCancel = () {
              _lastWipePoint = null;
              _touch.value = null;
              _scheduleHeal();
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
        // Motes roam a little outside the plate, so the field's edge is a
        // fuzz of grain rather than a ruled line. The plate stays exact.
        _DustField.forRect(
          _rects[i].inflate(2.5),
          seed ^ (i * 0x9E3779B1),
          scale,
        ),
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
        shove = Float32List(count * 2),
        blast = Float32List(count * 2);

  final int count;

  /// `strokeWidth`, which with a round cap is the mote's diameter.
  final double size;
  final double baseAlpha;

  /// Whole twinkle cycles per drift period — integral so the loop stays
  /// seamless, and mutually near-coprime across tiers so the field never
  /// pulses as one.
  final int cycles;
  final double offset;

  /// Live positions. The ONLY buffer handed to `drawRawPoints`.
  final Float32List xy;

  /// Resting position relative to the rect's origin, so wrapping is a compare
  /// against the rect's own width with no subtraction.
  final Float32List home;

  /// Travel per full period, always an integer number of rect widths/heights.
  final Float32List vel;

  /// Live displacement from being pushed by a finger. Integrated across
  /// frames and decayed, which is what gives the dust momentum instead of
  /// snapping to an offset.
  final Float32List shove;

  /// Per-mote randomness in the reveal, so the wavefront isn't a clean ring.
  final Float32List blast;
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
        tier.blast[2 * i] = (rand.nextDouble() - 0.5) * 26;
        tier.blast[2 * i + 1] = (rand.nextDouble() - 0.5) * 20 - 8;
      }
      tiers.add(tier);
    }
    return _DustField._(rect, tiers);
  }

  /// Writes this frame's positions into every tier's [_DustTier.xy].
  ///
  /// [touch] pushes motes away from a fingertip with momentum. [wave] is the
  /// reveal's radius, and motes within reach of its edge are thrown outward
  /// ahead of it.
  void update({
    required double phase,
    required Offset? touch,
    required Offset waveOrigin,
    required double wave,
    required double repelRadius,
  }) {
    final w = rect.width;
    final h = rect.height;
    final tx = touch?.dx ?? 0;
    final ty = touch?.dy ?? 0;
    final r2 = repelRadius * repelRadius;

    for (final tier in tiers) {
      final xy = tier.xy;
      final home = tier.home;
      final vel = tier.vel;
      final shove = tier.shove;
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
        var px = rect.left + ux;
        var py = rect.top + uy;

        // The finger. An impulse each frame it is near, then a decay, so the
        // dust keeps moving after the touch passes and eases back rather than
        // snapping home.
        if (touch != null) {
          final dx = px + shove[ix] - tx;
          final dy = py + shove[iy] - ty;
          final d2 = dx * dx + dy * dy;
          if (d2 < r2) {
            final d = math.sqrt(d2);
            final falloff = 1 - d / repelRadius;
            final k = falloff * falloff * 5.5;
            if (d > 0.001) {
              shove[ix] += dx / d * k;
              shove[iy] += dy / d * k;
            } else {
              shove[iy] -= k;
            }
          }
        }
        shove[ix] *= 0.87;
        shove[iy] *= 0.87;
        px += shove[ix];
        py += shove[iy];

        // The reveal. Motes ahead of the wavefront are thrown outward so the
        // dust looks blown aside by the clearing, not simply erased by it.
        if (wave > 0) {
          final dx = px - waveOrigin.dx;
          final dy = py - waveOrigin.dy;
          final dist = math.sqrt(dx * dx + dy * dy);
          final lead = (1 - ((dist - wave) / 34)).clamp(0.0, 1.0);
          if (lead > 0) {
            final nx = dist > 0.001 ? dx / dist : 0.0;
            final ny = dist > 0.001 ? dy / dist : -1.0;
            final throwBy = lead * lead * 30;
            px += nx * throwBy + tier.blast[ix] * lead;
            py += ny * throwBy + tier.blast[iy] * lead;
          }
        }

        xy[ix] = px;
        xy[iy] = py;
      }
    }
  }
}

/// The wipe's memory, kept twice over: a [Path] of where the finger actually
/// went, which is what gets painted, and a low-res alpha grid, which is what
/// gets asked questions.
///
/// The two exist for different reasons. The grid answers "how much of this is
/// open" and "is this point already clear" in constant time, at ~7-logical-px
/// cells — far below glyph size, and a few kilobytes for a long spoiler. But
/// it must not be what you SEE: rasterising it as one rect per cell drew the
/// grid itself, a staircase of 7px squares along every feathered edge, which
/// is exactly the boxes-and-corners look the plate was flattened to avoid.
/// The path is stroked once with a round cap and a blur instead, so the hole
/// has a fingertip's soft edge for a single draw call.
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

  /// Where the finger went. Stroked, not filled — this is the hole.
  final Path path = Path();

  /// Whether the current subpath has been opened.
  bool _drawing = false;
  bool _any = false;

  /// Nothing has been wiped — the overwhelmingly common state, and the one
  /// where the painter can skip its offscreen layer entirely.
  bool get clean => !_any;

  /// The stroke width the [path] is meant to be drawn at: the brush's own
  /// diameter, less the blur that will soften it back out.
  static const double strokeWidth = brush * 1.7;
  static const double strokeBlur = 7;

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

  /// Begins a new stroke. Called on pointer-down so a second touch does not
  /// draw a line from wherever the last one ended.
  void lift() => _drawing = false;

  void stamp(Offset point) {
    if (_drawing) {
      path.lineTo(point.dx, point.dy);
    } else {
      path
        ..moveTo(point.dx, point.dy)
        // A zero-length subpath is not reliably capped, and a pointer that
        // goes down and stops still owes the finger a dot.
        ..lineTo(point.dx + 0.01, point.dy);
      _drawing = true;
    }
    _any = true;

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
      }
    }
  }

  /// Back to full dust, after a partial wipe has healed.
  void reset() {
    values.fillRange(0, values.length, 0);
    path.reset();
    _drawing = false;
    _any = false;
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

/// Paints the veil: the plate, the dust over it, and every hole punched
/// through both — the wipe's brush strokes and the reveal's wavefront.
///
/// Every per-frame value arrives through a getter closure and the whole thing
/// is scheduled by `repaint:`, so nothing above this rebuilds for an
/// animation frame, a pan event or a fingertip moving.
class _SpoilerDustPainter extends CustomPainter {
  _SpoilerDustPainter({
    required Listenable repaint,
    required this.rectsOf,
    required this.fieldsOf,
    required this.maskOf,
    required this.phaseOf,
    required this.revealOf,
    required this.healOf,
    required this.touchOf,
    required this.originOf,
    required this.cover,
    required this.dust,
    required this.calm,
  }) : super(repaint: repaint);

  final List<Rect> Function() rectsOf;
  final List<_DustField> Function() fieldsOf;
  final _WipeMask? Function() maskOf;
  final double Function() phaseOf;
  final double Function() revealOf;
  final double Function() healOf;
  final Offset? Function() touchOf;
  final Offset Function() originOf;
  final Color cover;
  final Color dust;
  final bool calm;

  /// How far past the furthest corner the wavefront travels, so the last mote
  /// is well clear before the animation ends.
  static const double _waveOvershoot = 46;

  /// Room around the overlay's own box for everything that paints outside it:
  /// the plate's outset, roaming motes, and the wipe stroke's blur.
  static const double _layerSlack = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = rectsOf();
    if (rects.isEmpty) return;
    final reveal = revealOf();
    if (reveal >= 1) return;

    final mask = maskOf();
    final heal = healOf();
    final wiped = mask != null && !mask.clean && heal < 1;
    final origin = originOf();

    // The wavefront's radius in pixels. Eased so it leaves fast and settles,
    // which is what makes the clearing feel like it was thrown outward rather
    // than inflated.
    var waveR = 0.0;
    if (reveal > 0) {
      var far = 0.0;
      for (final r in rects) {
        for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
          far = math.max(far, (c - origin).distance);
        }
      }
      waveR = Curves.easeOutCubic.transform(reveal) * (far + _waveOvershoot);
    }

    // The offscreen exists only so `dstOut` can erase this painter's own
    // pixels without touching the text underneath. An untouched, unrevealed
    // veil — almost all of them, almost all of the time — skips it entirely.
    //
    // The bounds are the overlay's box GROWN, and that is load-bearing rather
    // than defensive: saveLayer clips to them, the plate is outset past the
    // paragraph so it covers the glyphs' antialiasing, and clipping that
    // outset away leaves a hairline of legible text around the whole veil —
    // visible only while a wipe or reveal is in flight, which is exactly when
    // nobody is looking for a rendering bug. Motes roam outside too, and the
    // wipe's blur spreads further still.
    final holed = wiped || reveal > 0;
    if (holed) {
      canvas.saveLayer((Offset.zero & size).inflate(_layerSlack), Paint());
    }

    // 1. The plate. Opaque, and exactly the bubble's own colour, so there is
    //    no rectangle to see — only an absence of words. It is never faded:
    //    every pixel of it leaves through a hole, which is what keeps the
    //    reveal a wavefront instead of a dissolve.
    //
    //    Square, not rounded. A radius is invisible on a plate that matches
    //    its bubble, but it is NOT free: consecutive line rects stack, and
    //    rounding leaves an uncovered notch at each seam where the corners
    //    curve away from each other — a row of little nicks of text showing
    //    through, which is precisely the corner the flat plate exists to
    //    avoid. Square rects tile exactly.
    final fill = Paint()..color = cover;
    for (final r in rects) {
      canvas.drawRect(r, fill);
    }

    // 2. The dust. One draw call per tier per line — thousands of motes for
    //    the cost the old field paid for sixty. Skipped entirely under calm;
    //    the static plate is the whole effect there.
    if (!calm) {
      final phase = phaseOf();
      final touch = touchOf();
      final mote = Paint()..strokeCap = StrokeCap.round;
      for (final field in fieldsOf()) {
        field.update(
          phase: phase,
          touch: touch,
          waveOrigin: origin,
          wave: waveR,
          repelRadius: _SpoilerOverlayState._repelRadius,
        );
        for (final tier in field.tiers) {
          final twinkle = 0.78 +
              0.22 *
                  math.sin(
                      2 * math.pi * (phase * tier.cycles + tier.offset));
          final alpha = (tier.baseAlpha * twinkle).clamp(0.0, 1.0);
          mote
            ..color = dust.withValues(alpha: alpha)
            ..strokeWidth = tier.size;
          canvas.drawRawPoints(PointMode.points, tier.xy, mote);
        }
      }
    }

    if (!holed) return;

    // 3. The holes. `dstOut` removes what is already in the layer, so running
    //    it after the dust takes plate and motes together. Motes drawn after
    //    would float over text the reader has already uncovered.
    //
    //    The wipe's stroke first — one blurred path, so the hole has a
    //    fingertip's soft edge and no trace of the bookkeeping grid. Faded
    //    out as a whole while a partial reveal heals.
    if (wiped) {
      canvas.drawPath(
        mask.path,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..color = Color.fromRGBO(0, 0, 0, 1 - heal)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _WipeMask.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            _WipeMask.strokeBlur,
          ),
      );
    }

    // 4. The reveal, as one expanding disc from wherever the finger was, with
    //    a soft rim so the words fade in at its edge rather than snapping.
    //    Running it in reverse closes the dust back over them.
    if (waveR > 0) {
      const rim = 0.72;
      canvas.drawCircle(
        origin,
        waveR,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = RadialGradient(
            colors: const [
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: const [0, rim, 1],
          ).createShader(Rect.fromCircle(center: origin, radius: waveR)),
      );
    }

    canvas.restore();
  }

  /// Everything that changes per frame is scheduled by `repaint:`; this only
  /// has to answer for the values baked into the instance.
  @override
  bool shouldRepaint(_SpoilerDustPainter old) =>
      old.cover != cover || old.dust != dust || old.calm != calm;
}
