import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Gradient, PointMode;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
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

  /// Reach of the draught around a fingertip. Wider than the brush that
  /// actually clears, so dust is moving well outside the part being uncovered
  /// — the air arrives before the erasing does.
  static const double _repelRadius = 66;

  static const _revealIn = Duration(milliseconds: 420);

  /// Longer than the reveal, and deliberately so: the dust has to travel in
  /// from upwind and settle, and a drift that arrives in the time it took to
  /// blow away reads as a rewind.
  static const _revealOut = Duration(milliseconds: 1150);
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

  /// True while the veil is re-forming. The same controller runs both ways,
  /// but the two directions look nothing alike: opening is a wavefront cut
  /// out of the plate, closing is dust blowing back in over the words.
  bool _gathering = false;

  /// Which way the dust drifts back in, fixed per message so a spoiler always
  /// re-forms the same way. Mostly sideways, tilted a little, and pointing
  /// one way or the other depending on the id.
  late final Offset _wind = () {
    final r = math.Random(widget.contextId.hashCode ^ 0x51D3);
    final a = (r.nextBool() ? 0.0 : math.pi) + (r.nextDouble() - 0.5) * 0.7;
    return Offset(math.cos(a), math.sin(a) * 0.45);
  }();

  /// Real time between paints, for the integrated part of the field.
  final _FrameClock _clock = _FrameClock();

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
      // Drop the wipe. Every gesture that opens a spoiler leaves marks on the
      // mask — even a tap, whose pointer-down stamps one brush dot before
      // `onEnd` decides it was a tap — and the whole plate is transparent
      // right now, so clearing it is invisible. Leaving it would punch those
      // marks straight back through the dust when it closes over again: the
      // spot you tapped would come back permanently bare.
      _mask?.reset();
      _heal.value = 0;
      _maskRevision.value++;
      // Nothing to animate while the words are simply readable.
      _drift?.stop();
      _scheduleHeal();
    } else if (status == AnimationStatus.dismissed) {
      _gathering = false;
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
        // The drift has to be running again before the dust can blow in.
        if (!_calm) _drift?.repeat();
        _gathering = true;
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
    _gathering = false;
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
        // The period every mote's wander and twinkle divides into a whole
        // number of times, so the repeat lands exactly on itself. Nine
        // seconds puts the fastest wander harmonic around 1.5s and the
        // quickest twinkle around a quarter of that — shimmer rather than
        // flicker, and far too long to read as a loop.
        duration: const Duration(seconds: 9),
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
          gatheringOf: () => _gathering,
          healOf: () => _heal.value,
          touchOf: () => _touch.value,
          originOf: () => _waveOrigin,
          clock: _clock,
          wind: _wind,
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
        amp = Float32List(count * 4),
        freq = Float32List(count * 4),
        phase = Float32List(count * 4),
        shove = Float32List(count * 2),
        shoveVel = Float32List(count * 2),
        stagger = Float32List(count),
        gust = Float32List(count),
        blast = Float32List(count * 2);

  final int count;

  /// `strokeWidth`, which with a round cap is the mote's diameter.
  final double size;
  final double baseAlpha;

  /// Whole twinkle cycles per period — integral so the loop stays seamless,
  /// and mutually coprime across tiers so the field never pulses as one.
  final int cycles;
  final double offset;

  /// Live positions. The ONLY buffer handed to `drawRawPoints`.
  final Float32List xy;

  /// Where this mote hangs about, absolute.
  final Float32List home;

  /// Two wander amplitudes per axis: `[x1, x2, y1, y2]`.
  final Float32List amp;

  /// Their frequencies, in whole cycles per period: `[x1, x2, y1, y2]`.
  final Float32List freq;

  /// Their phase offsets, in turns: `[x1, x2, y1, y2]`.
  final Float32List phase;

  /// Displacement from being blown about, and its velocity.
  ///
  /// A spring–damper pair, integrated properly rather than a decayed offset.
  /// The distinction is the whole difference between air and a magnifier: an
  /// offset that relaxes back is a lens following your finger, whereas a mote
  /// with velocity is *thrown*, keeps going after the draught has passed, and
  /// swings back past its resting place before it settles.
  final Float32List shove;
  final Float32List shoveVel;

  /// When this mote arrives, as a fraction of the settle, so the dust blows
  /// back in as a drift rather than all at once.
  final Float32List stagger;

  /// How far upwind it starts, and how hard the draught catches it.
  final Float32List gust;

  /// Per-mote randomness in the reveal, so the wavefront isn't a clean ring.
  final Float32List blast;
}

/// Real elapsed time between paints.
///
/// The dust is integrated, not interpolated — motes carry velocity — so it
/// needs a timestep rather than an animation value. Clamped hard, because a
/// dropped frame handed to a spring integrator is how particle systems
/// explode.
class _FrameClock {
  Duration? _last;

  /// Seconds since the previous paint.
  double dt = 1 / 60;

  /// Monotonic seconds, for anything that wants a phase of its own.
  double seconds = 0;

  void tick() {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final last = _last;
    _last = now;
    dt = last == null
        ? 1 / 60
        : ((now - last).inMicroseconds / 1e6).clamp(1 / 240, 1 / 30);
    seconds += dt;
  }
}

/// A sine table, because the field costs four of them per mote per frame.
///
/// 2048 entries puts the worst quantisation error at about a hundredth of a
/// pixel at these amplitudes — invisible, and a fraction of the cost of
/// `math.sin` two thousand motes at a time.
class _Trig {
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

  /// share, strokeWidth, base alpha, twinkle cycles per period.
  ///
  /// Eight tiers rather than four, and the reason is brightness, not size:
  /// `drawRawPoints` takes one [Paint] for a whole buffer, so a tier is the
  /// finest grain at which a mote can twinkle. Four of them made the field
  /// pulse in four visible groups. Eight, on coprime cycle counts, never
  /// resolves into a beat.
  static const _spec = <(double, double, double, int)>[
    (0.22, 0.6, 0.20, 11),
    (0.18, 0.7, 0.27, 13),
    (0.15, 0.9, 0.34, 17),
    (0.13, 1.1, 0.42, 19),
    (0.11, 1.3, 0.50, 23),
    (0.09, 1.5, 0.60, 29),
    (0.07, 1.8, 0.71, 31),
    (0.05, 2.2, 0.86, 37),
  ];

  factory _DustField.forRect(Rect rect, int seed, double scale) {
    final rand = math.Random(seed);
    final total = (wantedFor(rect) * scale).round().clamp(8, 1600);

    final tiers = <_DustTier>[];
    var assigned = 0;
    for (var t = 0; t < _spec.length; t++) {
      final (share, size, alpha, cycles) = _spec[t];
      // The last tier takes the remainder so rounding can't lose motes — or
      // go negative on a field small enough for the roundings to overshoot.
      final count = t == _spec.length - 1
          ? math.max(0, total - assigned)
          : (total * share).round();
      assigned += count;
      if (count <= 0) continue;

      final tier = _DustTier(count, size, alpha, cycles, rand.nextDouble());
      for (var i = 0; i < count; i++) {
        final ix = 2 * i;
        final iy = ix + 1;
        tier.home[ix] = rect.left + rand.nextDouble() * rect.width;
        tier.home[iy] = rect.top + rand.nextDouble() * rect.height;

        // Two harmonics per axis, at their own whole-number rates. A mote
        // therefore traces a small Lissajous wander rather than a straight
        // line, and no two motes trace the same one.
        //
        // This is the fix for the field reading as machinery. It used to be
        // constant velocity with a wrap at the rect edge: every mote in a
        // tier moved at one of two speeds, in one of two directions, forever,
        // which is a conveyor belt — and a conveyor belt seen through a slot
        // is a turbine. Nothing here has a net direction, so there is no
        // current to see, and nothing wraps, so there are no motes streaming
        // off one edge and reappearing at the other.
        //
        // Whole-number rates keep the loop seamless: at phase 1 every
        // harmonic is exactly back where it started.
        for (var k = 0; k < 4; k++) {
          tier.freq[4 * i + k] = (1 + rand.nextInt(6)).toDouble();
          tier.phase[4 * i + k] = rand.nextDouble();
        }
        // Wider horizontally than vertically: a line rect is only so tall,
        // and dust that wanders more than a couple of pixels up and down
        // starts to look like it is falling.
        tier.amp[4 * i] = 1.6 + rand.nextDouble() * 3.6;
        tier.amp[4 * i + 1] = 0.5 + rand.nextDouble() * 1.6;
        tier.amp[4 * i + 2] = 0.7 + rand.nextDouble() * 1.9;
        tier.amp[4 * i + 3] = 0.3 + rand.nextDouble() * 0.9;

        tier.blast[ix] = (rand.nextDouble() - 0.5) * 26;
        tier.blast[iy] = (rand.nextDouble() - 0.5) * 20 - 8;
        // Cubed, so most motes are already home well before the last
        // stragglers land and the settle has a long, thinning tail instead of
        // a front that arrives like a curtain.
        final s = rand.nextDouble();
        tier.stagger[i] = s * s * s * 0.62;
        tier.gust[i] = 26 + rand.nextDouble() * 66;
      }
      tiers.add(tier);
    }
    return _DustField._(rect, tiers);
  }

  /// Spring pulling a blown mote back to where it lives, in px/s² per px.
  /// Slack, so a mote thrown by the draught takes most of a second to drift
  /// back rather than snapping to the finger like a lens.
  static const double _springK = 11;

  /// Damping. Under the critical value on purpose — a mote should overshoot
  /// its resting place and swing back once, the way something light does
  /// when the air stops moving.
  static const double _springC = 3.1;

  /// Acceleration at the centre of the draught, px/s². Enough that motes near
  /// the fingertip leave at a few hundred px/s: they are thrown clear, not
  /// pushed aside.
  static const double _blowAccel = 2700;

  /// Writes this frame's positions into every tier's [_DustTier.xy].
  ///
  /// [touch] is a source of moving air, not a repulsion field: it accelerates
  /// motes outward, curls them around itself, and lets them coast. [wave] is
  /// the reveal's radius, and motes within reach of its edge are thrown ahead
  /// of it. [gather] runs the whole thing backwards — 0 while a spoiler is
  /// veiled or opening, rising to 1 as the dust blows back in along [wind].
  void update({
    required double phase,
    required double dt,
    required double time,
    required Offset? touch,
    required Offset waveOrigin,
    required double wave,
    required double repelRadius,
    required double gather,
    required Offset wind,
  }) {
    final tx = touch?.dx ?? 0;
    final ty = touch?.dy ?? 0;
    final r2 = repelRadius * repelRadius;

    for (final tier in tiers) {
      final xy = tier.xy;
      final home = tier.home;
      final amp = tier.amp;
      final freq = tier.freq;
      final off = tier.phase;
      final shove = tier.shove;
      final shoveVel = tier.shoveVel;
      for (var i = 0; i < tier.count; i++) {
        final ix = 2 * i;
        final iy = ix + 1;
        final h4 = 4 * i;

        // Two harmonics per axis. Bounded, so the mote stays where it lives;
        // incommensurate between motes, so the field has no grain to it.
        var px = home[ix] +
            amp[h4] * _Trig.sin(freq[h4] * phase + off[h4]) +
            amp[h4 + 1] * _Trig.sin(freq[h4 + 1] * phase + off[h4 + 1]);
        var py = home[iy] +
            amp[h4 + 2] * _Trig.sin(freq[h4 + 2] * phase + off[h4 + 2]) +
            amp[h4 + 3] * _Trig.sin(freq[h4 + 3] * phase + off[h4 + 3]);

        // The draught. Everything below is an ACCELERATION — the mote is
        // thrown and then coasts, which is what makes this air rather than a
        // lens that follows the fingertip around.
        var ax = -_springK * shove[ix] - _springC * shoveVel[ix];
        var ay = -_springK * shove[iy] - _springC * shoveVel[iy];

        if (touch != null) {
          final dx = px + shove[ix] - tx;
          final dy = py + shove[iy] - ty;
          final d2 = dx * dx + dy * dy;
          if (d2 < r2) {
            final d = math.sqrt(d2);
            final falloff = 1 - d / repelRadius;
            final f = falloff * falloff;
            // Straight out from the fingertip. Motes at the very centre have
            // no direction to be pushed in, so they get shoved upward and
            // the field sorts itself out within a frame or two.
            final nx = d > 0.001 ? dx / d : 0.0;
            final ny = d > 0.001 ? dy / d : -1.0;
            ax += nx * _blowAccel * f;
            ay += ny * _blowAccel * f;
            // A curl around the finger, wandering in strength and direction.
            // Without it a held finger is a static bubble — the "magnifier"
            // read — and with it the dust keeps circulating for as long as
            // the finger is down, which is what a held draught looks like.
            final swirl = _Trig.sin(time * 0.42 + off[h4] * 3) * 0.55 +
                _Trig.sin(time * 1.13 + off[h4 + 1] * 5) * 0.25;
            ax += -ny * _blowAccel * f * swirl;
            ay += nx * _blowAccel * f * swirl;
            // Turbulence, so no two motes take the same line out.
            ax += _Trig.sin(time * 1.9 + off[h4 + 2] * 7) * _blowAccel * f * 0.3;
            ay += _Trig.sin(time * 2.3 + off[h4 + 3] * 11) * _blowAccel * f * 0.3;
          }
        }

        shoveVel[ix] += ax * dt;
        shoveVel[iy] += ay * dt;
        shove[ix] += shoveVel[ix] * dt;
        shove[iy] += shoveVel[iy] * dt;
        // A mote can be thrown a long way but not to the moon, and the cap
        // is also the integrator's safety rail.
        if (shove[ix] > 120) shove[ix] = 120;
        if (shove[ix] < -120) shove[ix] = -120;
        if (shove[iy] > 120) shove[iy] = 120;
        if (shove[iy] < -120) shove[iy] = -120;
        px += shove[ix];
        py += shove[iy];

        // Blowing back in. Each mote starts its own distance upwind and
        // arrives on its own beat, so the veil re-forms as a drift settling
        // over the words rather than an opacity ramp.
        if (gather > 0) {
          final st = tier.stagger[i];
          final t = ((gather - st) / (1 - st)).clamp(0.0, 1.0);
          final remaining = 1 - Curves.easeOutCubic.transform(t);
          if (remaining > 0) {
            final reach = tier.gust[i] * remaining;
            px += wind.dx * reach;
            // A little lift on the way in, so motes arc down into place
            // instead of sliding along a rail.
            py += wind.dy * reach - 7 * remaining * (1 - remaining) * 4;
          }
        }

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

  /// The hole, as a heap of overlapping discs along the finger's path.
  ///
  /// Filled, not stroked. A stroke is one constant width with one smooth
  /// gradient down both sides, which is a paint stroke — it looked like
  /// wiping a window with a squeegee, and no amount of blur fixes the shape.
  /// Discs of varying size, jittered off the path and flecked with smaller
  /// satellites, give a boundary that crumbles instead of ruling, which is
  /// what rubbing dust away actually looks like. Non-zero fill unions them
  /// for free, so it is still one draw call.
  final Path path = Path();

  /// Deterministic per mask, so a rebuild of the same wipe looks the same.
  final math.Random _rand = math.Random(0x5EED);

  Offset? _lastStamp;
  int _discs = 0;
  bool _any = false;

  /// Nothing has been wiped — the overwhelmingly common state, and the one
  /// where the painter can skip its offscreen layer entirely.
  bool get clean => !_any;

  /// Distance the finger must travel before another disc is laid down.
  static const double _stampSpacing = 3.5;

  /// Past this many discs the satellites stop, so a marathon scrub cannot
  /// grow a path that costs real time to rasterise and blur every frame. The
  /// core discs keep coming; by then the edge has all the variety it needs,
  /// and a wipe this long is about to cross the reveal threshold anyway.
  static const int _satelliteBudget = 220;

  /// Just enough to take the hard edge off the discs without returning the
  /// whole thing to a smooth gradient.
  static const double stampBlur = 3.2;

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

  /// Begins a new stroke, so the next disc is judged on its own rather than
  /// against wherever the last touch ended.
  void lift() => _lastStamp = null;

  void stamp(Offset point) {
    final last = _lastStamp;
    final travelled = last == null ? double.infinity : (point - last).distance;
    if (travelled >= _stampSpacing) {
      // A slow finger presses wider than a fast one — the same reason a
      // pencil eraser leaves a fat mark where you linger. Plus a little
      // per-disc variation, so no two are the same size.
      final speed = travelled.isFinite ? travelled : 0.0;
      final r = brush *
          (1.18 - speed / 70).clamp(0.78, 1.18) *
          (0.86 + _rand.nextDouble() * 0.3);
      path.addOval(Rect.fromCircle(center: point, radius: r));
      _discs++;

      // Flecks around the rim. These are what stop the boundary reading as a
      // shape at all.
      if (_discs < _satelliteBudget) {
        for (var s = 0; s < 2; s++) {
          final a = _rand.nextDouble() * 2 * math.pi;
          final d = r * (0.6 + _rand.nextDouble() * 0.45);
          path.addOval(Rect.fromCircle(
            center: point + Offset(math.cos(a) * d, math.sin(a) * d * 0.7),
            radius: r * (0.16 + _rand.nextDouble() * 0.2),
          ));
        }
      }
      _lastStamp = point;
      _any = true;
    }

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
    _lastStamp = null;
    _discs = 0;
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
    required this.gatheringOf,
    required this.healOf,
    required this.touchOf,
    required this.originOf,
    required this.clock,
    required this.wind,
    required this.cover,
    required this.dust,
    required this.calm,
  }) : super(repaint: repaint);

  final List<Rect> Function() rectsOf;
  final List<_DustField> Function() fieldsOf;
  final _WipeMask? Function() maskOf;
  final double Function() phaseOf;
  final double Function() revealOf;
  final bool Function() gatheringOf;
  final double Function() healOf;
  final Offset? Function() touchOf;
  final Offset Function() originOf;
  final _FrameClock clock;
  final Offset wind;
  final Color cover;
  final Color dust;
  final bool calm;

  /// How far past the furthest corner the wavefront travels, so the last mote
  /// is well clear before the animation ends.
  static const double _waveOvershoot = 46;

  /// Room around the overlay's own box for everything that paints outside it:
  /// the plate's outset, roaming motes, and the wipe stroke's blur.
  static const double _layerSlack = 28;

  /// Half-width of the settling front's soft edge, as a fraction of the
  /// veil's extent along the wind.
  static const double _frontBand = 0.16;

  /// A `dstOut` shader that erases only DOWNWIND of a front at [progress],
  /// which is how every re-veil in here is drawn: dust reclaims the words
  /// from one side instead of an opacity ramp taking them everywhere at once.
  ///
  /// [progress] 0 means the front has not arrived and everything is still
  /// erased; 1 means it has swept the whole span. Returns null at the extreme
  /// where a flat erase is equivalent, so the caller can skip the shader.
  ui.Gradient? _windFront(Rect bounds, double progress) {
    final front =
        (1 + _frontBand) - Curves.easeInOut.transform(progress) * (1 + 2 * _frontBand);
    if (front >= 1 + _frontBand) return null;
    final n = wind / wind.distance;
    final half = (bounds.width * n.dx.abs() + bounds.height * n.dy.abs()) / 2;
    return ui.Gradient.linear(
      bounds.center - n * half,
      bounds.center + n * half,
      const [
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0x00000000),
        Color(0x00000000),
      ],
      [
        0,
        (front - _frontBand).clamp(0.0, 1.0),
        (front + _frontBand).clamp(0.0, 1.0),
        1,
      ],
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rects = rectsOf();
    if (rects.isEmpty) return;
    clock.tick();
    final reveal = revealOf();
    final gathering = gatheringOf();
    // Fully open and staying that way: nothing to draw. While GATHERING the
    // same value means the dust is still upwind and about to arrive, so it
    // very much has something to draw.
    if (reveal >= 1 && !gathering) return;

    final mask = maskOf();
    final heal = healOf();
    final wiped = mask != null && !mask.clean && heal < 1;
    final origin = originOf();
    final gather = gathering ? 1 - reveal : 0.0;

    // The wavefront's radius in pixels. Eased so it leaves fast and settles,
    // which is what makes the clearing feel like it was thrown outward rather
    // than inflated. Only on the way OUT — the way back is a drift, not a
    // wavefront run in reverse, which is what made the re-veil read as a fade.
    var waveR = 0.0;
    if (reveal > 0 && !gathering) {
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
    // Where the veil's leading edge has got to, as a fraction along the wind
    // axis, running from just past the far end (nothing covered) to just past
    // the near end (all covered).
    final front = gathering
        ? (1 + _frontBand) -
            Curves.easeInOut.transform(gather) * (1 + 2 * _frontBand)
        : double.negativeInfinity;
    final plateHidden = front >= 1 + _frontBand;
    final fronted = gathering && !plateHidden && front > -_frontBand;

    var veilBounds = rects.first;
    for (final r in rects.skip(1)) {
      veilBounds = veilBounds.expandToInclude(r);
    }
    veilBounds = veilBounds.inflate(_layerSlack);

    final holed = wiped || waveR > 0 || fronted;
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
    //
    //    On the way back in it arrives as a FRONT, never as an alpha ramp.
    //    Fading it in was the whole reason the settle read as a dissolve: an
    //    even wash of opacity over the words is a dimmer, whatever is flying
    //    about on top of it. Instead the plate is drawn solid and then cut
    //    back to a line that sweeps downwind, so the words go out behind a
    //    drift that is visibly arriving from one side.
    if (!plateHidden) {
      final fill = Paint()..color = cover;
      for (final r in rects) {
        canvas.drawRect(r, fill);
      }
    }
    if (fronted) {
      final shader = _windFront(veilBounds, gather);
      if (shader != null) {
        canvas.drawRect(
          veilBounds,
          Paint()
            ..blendMode = BlendMode.dstOut
            ..shader = shader,
        );
      }
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
          dt: clock.dt,
          time: clock.seconds,
          touch: touch,
          waveOrigin: origin,
          wave: waveR,
          repelRadius: _SpoilerOverlayState._repelRadius,
          gather: gather,
          wind: wind,
        );
        for (final tier in field.tiers) {
          final twinkle =
              0.84 + 0.16 * _Trig.sin(phase * tier.cycles + tier.offset);
          final alpha = (tier.baseAlpha * twinkle).clamp(0.0, 1.0);
          mote
            ..color = dust.withValues(alpha: alpha)
            ..strokeWidth = tier.size;
          canvas.drawRawPoints(ui.PointMode.points, tier.xy, mote);
        }
      }
    }

    if (!holed) return;

    // 3. The holes that UNCOVER. `dstOut` removes what is already in the
    //    layer, so running these after the dust takes plate and motes
    //    together; motes drawn after would float over text the reader has
    //    already uncovered. (The settling front above is the one erase that
    //    runs BEFORE the dust, for the opposite reason: motes blowing in
    //    ahead of it have to survive it.)
    //
    //    The wipe's rub first — one filled heap of discs, so the hole has a
    //    crumbling edge and no trace of the bookkeeping grid. Healing sweeps
    //    the same wind across it rather than dimming it: a hole that fades
    //    out uniformly is the dissolve this whole effect exists not to be,
    //    just at a smaller scale.
    if (wiped) {
      final paint = Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          _WipeMask.stampBlur,
        );
      final shader = heal > 0 ? _windFront(veilBounds, heal) : null;
      if (shader != null) {
        paint.shader = shader;
      } else {
        paint.color = const Color(0xFF000000);
      }
      canvas.drawPath(mask.path, paint);
    }

    // 4. The reveal, as one expanding disc from wherever the finger was, with
    //    a soft rim so the words arrive at its edge rather than snapping in.
    //    Outward only — the way back is the settling front, not this run
    //    backwards, because a contracting disc is a wipe and reads as one.
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
