import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../data/spoiler_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import 'dust/dust_kit.dart';
import 'dust/rub_field.dart';
import 'dust/spoiler_dust.dart';
import 'paragraph_geometry.dart';

/// The dust veil over a message's spoiler text, and everything that happens
/// when a finger touches it.
///
/// **There is no plate.** The earlier veil painted an opaque rectangle in the
/// bubble's fill colour over the real text and drew dust on top of that. The
/// rectangle was only invisible when its colour matched the bubble *exactly*,
/// which it could not on a translucent fill, a speaker-tinted group bubble or
/// a photo caption — and so a spoiler read as a box drawn inside the message,
/// with the dust as a second layer over it. This widget instead WRAPS the
/// paragraph and hides the glyphs themselves (see [RenderVeiledText]): the
/// bubble's own ground shows through untouched, and the dust is drawn straight
/// onto it in the text's ink. Layout is still real — the paragraph is laid out
/// with the hidden words so the bubble is the right size and the reveal
/// uncovers text that was always exactly there.
///
/// **The dust is alive.** Each mote is born, drifts on a slow curling current,
/// fades and dies, and another takes its place somewhere else. The field never
/// loops, has no grain and no direction, and a fingertip's draught throws the
/// motes near it aside.
///
/// **A tap opens a wavefront** from the touch point: the words appear inside
/// an expanding disc while the dust ahead of its edge is blown clear. **A
/// horizontal rub wipes** — a soft-brush stroke reveals only what it touched.
///
/// **Nothing stays open.** After a short hold ([kSpoilerHoldMaxMs] at most)
/// the dust blows back in on a wind and the words dim beneath it as it
/// arrives. A partial wipe crumbles shut the same way. Leaving the room
/// re-veils everything (see [SpoilerStore]).
///
/// **Calm motion** builds no ticker and allocates no particle buffers, per the
/// MotionScope contract: a static stipple marks the veil, a tap reveals
/// instantly, and the same hold re-veils it. Screen readers get the tap-reveal
/// through [Semantics] in both modes.
class SpoilerVeil extends StatefulWidget {
  const SpoilerVeil({
    super.key,
    required this.paragraphKey,
    required this.ranges,
    required this.contextId,
    required this.ink,
    required this.child,
  });

  /// Key on the paragraph inside [child], resolved to its [RenderParagraph]
  /// so the veil rects come from real glyph geometry.
  final GlobalKey paragraphKey;

  /// The spoiler stretches, in the DISPLAY text's coordinates (the fold's
  /// `spoilerRanges`).
  final List<({int start, int end})> ranges;

  /// What keys the open state in the session store — the message id.
  final String contextId;

  /// Ink of the dust — the text's own colour, so the field reads as the
  /// hidden words ground to powder, and so it contrasts with the bubble for
  /// the same reason the words do.
  final Color ink;

  /// The paragraph (and, when the message has inline code, the chip underlay
  /// beneath it — a chip inside a spoiler is hidden along with its words).
  final Widget child;

  @override
  State<SpoilerVeil> createState() => _SpoilerVeilState();
}

/// How long the wavefront takes to open the spoiler.
const Duration kSpoilerRevealIn = Duration(milliseconds: 380);

/// How long the dust takes to blow back in over the words.
const Duration kSpoilerGather = Duration(milliseconds: 800);

/// How long a partial wipe takes to close over.
const Duration kSpoilerHeal = Duration(milliseconds: 700);

/// The hold between a reveal completing and the dust returning: a floor, a
/// little per character, and a ceiling. Short on purpose — a spoiler is a
/// glimpse, not a toggle — and every one of these is deliberately a single
/// number to change.
const int kSpoilerHoldBaseMs = 1400;
const int kSpoilerHoldPerCharMs = 15;
const int kSpoilerHoldMaxMs = 2000;

class _SpoilerVeilState extends State<SpoilerVeil>
    with TickerProviderStateMixin {
  late final VeilModel _model = VeilModel(seed: widget.contextId.hashCode);

  /// Drives the dust. Created only outside calm motion, and only started
  /// while there is dust to move: never while the words are simply readable.
  Ticker? _ticker;
  Duration? _lastTick;

  /// Bumped per tick; the dust painter repaints on it.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  /// The reveal wavefront. 0 = veiled, 1 = fully open. Runs forward on a tap
  /// and backwards — as the gather — when the hold expires.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: kSpoilerRevealIn,
    reverseDuration: kSpoilerGather,
  )
    ..addListener(() => _model.reveal = _reveal.value)
    ..addStatusListener(_onRevealStatus);

  /// Crumbles a partial wipe shut. 0 = holes intact.
  late final AnimationController _heal = AnimationController(
    vsync: this,
    duration: kSpoilerHeal,
  )
    ..addListener(() => _model.heal = _heal.value)
    ..addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      _model._mask?.reset();
      _model.endHeal();
      _heal.value = 0;
      _maskRevision.value++;
    });

  /// Bumped whenever the wipe mask changes, so both painters repaint without
  /// the State rebuilding sixty times a second during a drag.
  final ValueNotifier<int> _maskRevision = ValueNotifier<int>(0);

  Offset? _lastWipePoint;
  Timer? _healTimer;
  int _gathers = 0;

  /// Last resolved motion budget, cached from build so gesture callbacks can
  /// read it without registering an inherited-widget dependency mid-event.
  bool _calm = false;

  bool get _open => _reveal.value >= 1 && !_model.gathering;

  Duration get _holdFor {
    var chars = 0;
    for (final r in widget.ranges) {
      chars += r.end - r.start;
    }
    return Duration(
      milliseconds: (kSpoilerHoldBaseMs + chars * kSpoilerHoldPerCharMs)
          .clamp(kSpoilerHoldBaseMs, kSpoilerHoldMaxMs),
    );
  }

  @override
  void initState() {
    super.initState();
    // Mounting onto an already-open message (a rebuild in place, or a row
    // recycled while the text was showing) picks the state up and restarts
    // the hold, so an entry in the store can never strand a spoiler readable.
    if (SpoilerStore.instance.isRevealed(widget.contextId)) {
      _reveal.value = 1;
      _scheduleHeal();
    }
  }

  @override
  void dispose() {
    _healTimer?.cancel();
    _ticker?.dispose();
    _reveal.dispose();
    _heal.dispose();
    _frame.dispose();
    _maskRevision.dispose();
    _model.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- ticker

  void _ensureTicker() {
    if (_calm) return;
    final t = _ticker ??= createTicker(_onTick);
    if (!t.isActive) {
      _lastTick = null;
      t.start();
    }
  }

  void _stopTicker() {
    _ticker?.stop();
    _lastTick = null;
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    final dt = dustFrameDt(last, elapsed);
    _model.time += dt;
    _model._field?.step(_model, dt);
    _stepBoil(dt);
    _frame.value++;
    // Open again: the words are readable and the ticker only stayed up for
    // the last of the boiled dust to blow away.
    if (_open && _model.boil == null) _stopTicker();
  }

  /// The dust boiling off the wipe under a held finger (see [RubField]):
  /// made by the first wipe, stepped while it has anything to move, and
  /// dropped the moment it has nothing.
  void _stepBoil(double dt) {
    final boil = _model.boil;
    if (boil == null) return;
    final mask = _model._mask;
    final hole = mask != null && !mask.clean ? _model.hole : null;
    // Only while the finger is on dust that is still being wiped, not once
    // the whole veil has gone up on the wavefront.
    final emitting = hole != null && _reveal.value <= 0 ? _model.touch : null;
    boil
      ..inkRgb = _model.inkRgb
      ..step(
        dt,
        time: _model.time,
        touch: _model.touch,
        emitFrom: emitting,
        rub: hole,
        heal: _model.heal,
      );
    if (emitting == null && !boil.busy && !_model.healing) _model.boil = null;
  }

  /// A field for the boil, over the veil and a margin round it, inside the
  /// paragraph's own box.
  void _ensureBoil() {
    if (_calm || _model.boil != null || _model.rects.isEmpty) return;
    final area = _model.bounds
        .inflate(_boilReach)
        .intersect(_model.box.inflate(_boilOverhang));
    if (area.isEmpty) return;
    // The picture's rate (the text's dust is denser than a picture's, so the
    // boil needs all of it to read over it), less for a spoiler too short to
    // carry a picture's cloud: a word still boils plainly, it is just not
    // buried.
    var area2 = 0.0;
    for (final r in _model.rects) {
      area2 += r.width * r.height;
    }
    final scale = math.sqrt(area2 / _boilFullArea).clamp(0.4, 1.0);
    _model.boil = RubField(
      area,
      _model.dpr,
      emitRate: RubField.defaultEmitRate * scale,
      inkRgb: _model.inkRgb,
      edgeFade: 10,
    );
  }

  /// How far round the veiled words the boiled dust may travel, and how far
  /// past the paragraph's box (into the bubble's padding).
  static const double _boilReach = 34;
  static const double _boilOverhang = 10;

  /// Veil area, in px², from which a spoiler boils at the full rate.
  static const double _boilFullArea = 4000;

  // ----------------------------------------------------------- transitions

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _model.endReveal();
      SpoilerStore.instance.reveal(widget.contextId);
      // Drop the wipe. The whole veil is open, so clearing it is invisible;
      // leaving it would punch its holes straight back through the dust when
      // it closes over again.
      _model._mask?.reset();
      _heal.value = 0;
      _maskRevision.value++;
      // Nothing to animate while the words are simply readable, once the
      // last of the boiled dust has blown away.
      if (_model.boil == null) _stopTicker();
      _scheduleHeal();
    } else if (status == AnimationStatus.dismissed) {
      _model.endGather();
      SpoilerStore.instance.conceal(widget.contextId);
    }
  }

  /// Arms the re-veil. Any new interaction cancels and re-arms it.
  void _scheduleHeal() {
    _healTimer?.cancel();
    _healTimer = Timer(_holdFor, () {
      if (!mounted) return;
      if (_open) {
        _model.beginGather(math.Random(_model.seed ^ (_gathers++ * 0x9E37)));
        _ensureTicker();
        _reveal.reverse();
      } else if (_model._mask case final mask? when !mask.clean) {
        _model.beginHeal(math.Random(_model.seed ^ (_gathers++ * 0x9E37)));
        _ensureTicker();
        _heal.forward(from: 0);
      }
    });
  }

  void _revealWhole({Offset? origin}) {
    if (_reveal.value > 0 || _reveal.isAnimating) return;
    // A soft tick as the dust blows off, the Telegram reveal.
    HapticFeedback.lightImpact();
    _healTimer?.cancel();
    _model.beginReveal(origin ?? _model.bounds.center);
    _ensureTicker();
    _reveal.forward();
  }

  void _wipeAt(Offset point) {
    final mask = _model._mask;
    if (mask == null || _reveal.value > 0) return;
    // A stroke onto healing holes takes them over rather than fighting the
    // fade.
    if (_heal.isAnimating) {
      _heal
        ..stop()
        ..value = 0;
      _model.endHeal();
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

  // -------------------------------------------------------------- hit test

  bool _hitsVeil(Offset local) {
    if (_reveal.value > 0 || _model.gathering) return false;
    final mask = _model._mask;
    for (final r in _model.rects) {
      if (r.inflate(4).contains(local)) {
        // A cell the wipe already cleared is open window, not veil — a
        // pointer landing there belongs to the transcript again.
        if (mask == null || !mask.isCleared(local)) return true;
      }
    }
    return false;
  }

  /// Whether a pointer at this GLOBAL position lands on unrevealed veil.
  bool _hitTestGlobal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    return _hitsVeil(box.globalToLocal(global));
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    _calm = motion.calm;
    _reveal
      ..duration = motion.d(kSpoilerRevealIn)
      ..reverseDuration = motion.d(kSpoilerGather);
    _heal.duration = motion.d(kSpoilerHeal);

    _model
      ..inkRgb = widget.ink.toARGB32() & 0xFFFFFF
      ..dpr = MediaQuery.devicePixelRatioOf(context)
      ..setCalm(_calm);

    // Calm is a code path: the ticker and the field are simply never made.
    if (_calm) {
      _ticker?.dispose();
      _ticker = null;
      _lastTick = null;
    } else if (!_open) {
      _ensureTicker();
    }

    final maskRepaint = Listenable.merge([_reveal, _heal, _maskRevision]);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The paragraph, with its spoiler glyphs masked out. The only
        // non-positioned child, so the Stack hugs the text exactly as the
        // bare paragraph would.
        VeiledText(
          model: _model,
          paragraphKey: widget.paragraphKey,
          ranges: widget.ranges,
          repaint: maskRepaint,
          child: widget.child,
        ),
        // The dust, in its own layer so the drift never repaints the text.
        // Under IgnorePointer: it is decoration, and a CustomPaint that took
        // hits would swallow taps on every link in the paragraph beneath.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DustPainter(
                  repaint: Listenable.merge([
                    _frame,
                    maskRepaint,
                    _model.geometry,
                  ]),
                  model: _model,
                  ink: widget.ink,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        // The gestures, as the TOP sibling: hit-tested before the paragraph,
        // so on a veiled link the veil's recognizers enter the arena first
        // and a tap reveals rather than opens. Translucent, and with a child
        // that takes no hits, so everywhere else the hit test carries on
        // down to the paragraph and its links still work.
        Positioned.fill(
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              _VeilTapRecognizer:
                  GestureRecognizerFactoryWithHandlers<_VeilTapRecognizer>(
                () => _VeilTapRecognizer(hitTest: _hitTestGlobal),
                (r) => r.onTapUp = (d) => _revealWhole(origin: d.localPosition),
              ),
              if (!_calm)
                _WipeRecognizer:
                    GestureRecognizerFactoryWithHandlers<_WipeRecognizer>(
                  () => _WipeRecognizer(hitTest: _hitTestGlobal),
                  (r) {
                    r.dragStartBehavior = DragStartBehavior.down;
                    r.onStart = (d) {
                      _lastWipePoint = null;
                      _healTimer?.cancel();
                      _model._mask?.lift();
                      _model.touch = d.localPosition;
                      _ensureBoil();
                      _ensureTicker();
                      _wipeAt(d.localPosition);
                    };
                    r.onUpdate = (d) {
                      _model.touch = d.localPosition;
                      _wipeAt(d.localPosition);
                    };
                    r.onEnd = (_) {
                      _lastWipePoint = null;
                      _model.touch = null;
                      _scheduleHeal();
                    };
                    r.onCancel = () {
                      _lastWipePoint = null;
                      _model.touch = null;
                      _scheduleHeal();
                    };
                  },
                ),
            },
            child: Semantics(
              button: true,
              label: AppLocalizations.of(context).spoilerRevealHint,
              onTap: _revealWhole,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gestures
// ---------------------------------------------------------------------------

/// A tap that exists only on unrevealed dust.
///
/// A tight pre-accept slop, so a short rub is handed to [_WipeRecognizer]
/// rather than being mistaken for a tap that opens the whole spoiler — the
/// opposite of what a swipe over two words asked for.
class _VeilTapRecognizer extends TapGestureRecognizer {
  _VeilTapRecognizer({required this.hitTest})
      : super(preAcceptSlopTolerance: _WipeRecognizer.slop);

  final bool Function(Offset globalPosition) hitTest;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      hitTest(event.position) && super.isPointerAllowed(event);
}

/// The wipe: a horizontal drag that exists only on unrevealed dust.
///
/// Horizontal, not a pan, and accepted normally rather than claimed on
/// pointer-down — the trade its predecessor made the other way. Claiming on
/// down made the wipe deterministic at the cost of every other gesture that
/// could start on the dust, and a transcript scroll that happened to begin on
/// a veil went to the veil instead. Now a vertical drag is the list's (it
/// accepts at its own slop while this one sits out), a long-press is the
/// action menu's, and only motion that is unmistakably sideways is a wipe.
///
/// It accepts early, at [slop] rather than the platform's touch slop, because
/// the row's swipe-to-reply is the same kind of recognizer one level up: both
/// cross the slop on the same event, and this one — deeper in the tree, so
/// handed the event first — wins the tie. Once it has the pointer, the rub
/// is free in two dimensions; only the acceptance is horizontal.
class _WipeRecognizer extends HorizontalDragGestureRecognizer {
  _WipeRecognizer({required this.hitTest});

  final bool Function(Offset globalPosition) hitTest;

  /// Sideways travel that makes a rub a rub. Well under `kTouchSlop`, so a
  /// deliberate short swipe over two words stays a partial reveal.
  static const double slop = 6;

  double _dx = 0;
  double _dy = 0;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      hitTest(event.position) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _dx = 0;
    _dy = 0;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _dx += event.delta.dx;
      _dy += event.delta.dy;
    }
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      _dx.abs() > slop && _dx.abs() > 1.2 * _dy.abs();
}

// ---------------------------------------------------------------------------
// The veiled paragraph
// ---------------------------------------------------------------------------

/// The paragraph with its spoiler glyphs masked out of its own pixels.
///
/// Public only so tests can reach [RenderVeiledText]; not for use outside
/// [SpoilerVeil].
class VeiledText extends SingleChildRenderObjectWidget {
  const VeiledText({
    super.key,
    required this.model,
    required this.paragraphKey,
    required this.ranges,
    required this.repaint,
    required Widget super.child,
  });

  final VeilModel model;
  final GlobalKey paragraphKey;
  final List<({int start, int end})> ranges;
  final Listenable repaint;

  @override
  RenderVeiledText createRenderObject(BuildContext context) => RenderVeiledText(
        model: model,
        paragraphKey: paragraphKey,
        ranges: ranges,
        repaint: repaint,
      );

  @override
  void updateRenderObject(BuildContext context, RenderVeiledText renderObject) {
    renderObject
      ..model = model
      ..paragraphKey = paragraphKey
      ..ranges = ranges
      ..repaint = repaint;
  }
}

/// Paints its child with the spoiler stretches cut out of it.
///
/// The concealment is the paragraph's own alpha, not something drawn over
/// it, which is what lets the bubble's ground — gradient, translucency,
/// speaker tint, photograph — show through exactly as it is.
///
/// Three paths, cheapest first:
///
///  * **Open** — just the child.
///  * **Concealed and still** (almost every frame): the child painted under
///    an even-odd clip with the veil rects cut out. No layers.
///  * **A reveal, gather, wipe or heal in flight**: the child into a layer,
///    then a visibility mask composited onto it with `dstIn` — opaque where
///    the words show, a soft-rimmed disc for the wavefront, a blurred brush
///    path for the wipe, a moving gradient front for the gather. Two
///    offscreens, for a few hundred milliseconds at a time.
///
/// Geometry is measured in [performLayout], right after the child lays out,
/// so the very first paint is already cut to the glyphs: no post-frame
/// measurement, no frame of bare text, no opaque placeholder standing in.
class RenderVeiledText extends RenderProxyBox {
  RenderVeiledText({
    required VeilModel model,
    required GlobalKey paragraphKey,
    required List<({int start, int end})> ranges,
    required Listenable repaint,
  })  : _model = model,
        _paragraphKey = paragraphKey,
        _ranges = ranges,
        _repaint = repaint;

  VeilModel _model;
  VeilModel get model => _model;
  set model(VeilModel value) {
    if (identical(value, _model)) return;
    _model = value;
    markNeedsLayout();
  }

  GlobalKey _paragraphKey;
  set paragraphKey(GlobalKey value) {
    if (value == _paragraphKey) return;
    _paragraphKey = value;
    markNeedsLayout();
  }

  List<({int start, int end})> _ranges;
  set ranges(List<({int start, int end})> value) {
    if (listEquals(value, _ranges)) return;
    _ranges = value;
    markNeedsLayout();
  }

  Listenable _repaint;
  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
  }

  /// Room around the box for glyph overhang and the wipe's blur. Both layers
  /// take exactly this rect: a layer composites back over its own bounds and
  /// nothing else, so a mask layer smaller than the text layer would hand
  /// back an unmasked ring of text around the edge.
  static const double _slack = 28;

  /// What the last measurement was taken against, so a relayout the
  /// paragraph does without us — it is its own relayout boundary under tight
  /// constraints — is caught at paint time.
  RenderParagraph? _measuredParagraph;
  Size _measuredSize = Size.zero;
  InlineSpan? _measuredText;
  bool _remeasureQueued = false;

  ClipPathLayer? _clipLayer;

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _measure();
  }

  void _measure() {
    final p = paragraphUnder(_paragraphKey);
    if (p == null || !p.attached || !p.hasSize) {
      _measuredParagraph = null;
      _model.adopt(const []);
      return;
    }
    // A transform rather than the global round trip: this box's own offset
    // in its parent is not set yet mid-layout, and the two halves of a
    // global→local trip would only cancel out once it is.
    final m = p.getTransformTo(this);
    final groups = paragraphRectsIn(
      paragraph: p,
      ranges: _ranges,
      toLocal: (o) => MatrixUtils.transformPoint(m, o),
      // Grown so the cut covers the glyphs' own antialiasing rather than
      // stopping exactly at it.
      insetX: -1.5,
      insetY: -1.5,
    );
    _measuredParagraph = p;
    _measuredSize = p.textSize;
    _measuredText = p.text;
    _model.box = Offset.zero & size;
    _model.adopt([for (final g in groups) ...g]);
  }

  /// The veil rects, in this box's coordinates. For tests.
  @visibleForTesting
  List<Rect> get debugVeilRects => _model.rects;

  /// Whether the next paint cuts the spoiler out of the text. For tests.
  @visibleForTesting
  bool get debugConcealing => _model.rects.isNotEmpty && !_model.open;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    final p = _measuredParagraph;
    if (p != null &&
        (p.textSize != _measuredSize || !identical(p.text, _measuredText)) &&
        !_remeasureQueued) {
      // Stale by one frame, then exact — a layout cannot be requested from
      // inside paint.
      _remeasureQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _remeasureQueued = false;
        if (attached) markNeedsLayout();
      });
    }

    final m = _model;
    if (m.rects.isEmpty || m.open) {
      context.paintChild(child, offset);
      return;
    }

    if (child.needsCompositing) {
      _paintComposited(context, offset, child);
      return;
    }

    final canvas = context.canvas;
    final bounds = (offset & size).inflate(_slack);

    if (m.still) {
      final clip = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds);
      for (final r in m.rects) {
        clip.addRect(r.shift(offset));
      }
      canvas
        ..save()
        ..clipPath(clip);
      context.paintChild(child, offset);
      canvas.restore();
      return;
    }

    canvas.saveLayer(bounds, Paint());
    context.paintChild(child, offset);
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
    _paintVisibility(canvas, offset, bounds);
    canvas
      ..restore()
      ..restore();
  }

  /// The mask: opaque where the words may show, transparent where they may
  /// not. Composited onto the text with `dstIn`, so this IS the text's alpha.
  void _paintVisibility(Canvas canvas, Offset offset, Rect bounds) {
    final m = _model;
    const opaque = Color(0xFFFFFFFF);
    canvas.drawRect(bounds, Paint()..color = opaque);

    if (m.gathering) {
      // The wind front. Concealed upwind of it, clear downwind, a soft band
      // between — and a different band per line, so nothing about the edge
      // is ruler-straight. The dust arrives on the same front (see
      // [_DustField.prepareGather]); the words dim under it as it lands.
      final w = m.wind;
      final front = m.frontAt(m.gather);
      for (var i = 0; i < m.rects.length; i++) {
        final f = front + m.lineJitter[i];
        canvas.drawRect(
          m.rects[i].shift(offset),
          Paint()
            ..blendMode = BlendMode.dstOut
            ..shader = ui.Gradient.linear(
              offset + w * (f - VeilModel.frontBand),
              offset + w * f,
              const [Color(0xFF000000), Color(0x00000000)],
            ),
        );
      }
      return;
    }

    final conceal = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0xFF000000);
    for (final r in m.rects) {
      canvas.drawRect(r.shift(offset), conceal);
    }

    // The wavefront: one expanding disc from wherever the finger was, with a
    // soft rim so the words arrive at its edge rather than snapping in.
    final wave = m.waveRadius;
    if (wave > 0) {
      final c = m.origin + offset;
      canvas.drawCircle(
        c,
        wave,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            wave,
            const [opaque, opaque, Color(0x00FFFFFF)],
            const [0, VeilModel.waveRim, 1],
          ),
      );
    }

    // The wipe: a heap of blurred discs along the finger's path.
    //
    // Healing closes the hole on a wind of its own, exactly as the whole
    // veil closes after a tap: covered upwind of a soft front, still open
    // downwind, the dust arriving on the same front (see
    // [_DustField.prepareHeal]). It used to drop the discs one by one, which
    // at the size of a thumb-stroke read as patches of text blinking out —
    // the same "paint coming back" the plate was retired for, in miniature.
    final mask = m._mask;
    if (mask != null && !mask.clean && m.heal < 1) {
      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          _WipeMask.stampBlur,
        );
      if (m.healing) {
        // In the translated (local) space the path is drawn in.
        final w = m.healWind;
        final f = m.healFrontAt(m.heal);
        paint.shader = ui.Gradient.linear(
          w * (f - VeilModel.healBand),
          w * f,
          const [Color(0x00FFFFFF), opaque],
        );
      } else {
        paint.color = opaque;
      }
      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..drawPath(mask.path, paint)
        ..restore();
    }
  }

  /// The fallback for a child that composites — only a `SelectionArea`
  /// above a message could make one, and nothing does today. A hard-edged
  /// clip instead of the soft mask: correct, never pretty, and free of the
  /// per-frame image the soft version would need through a layer.
  void _paintComposited(PaintingContext context, Offset offset, RenderBox child) {
    final m = _model;
    var concealed = Path();
    for (final r in m.rects) {
      concealed.addRect(r);
    }
    final holes = Path();
    final wave = m.waveRadius;
    if (wave > 0) {
      holes.addOval(Rect.fromCircle(center: m.origin, radius: wave * VeilModel.waveRim));
    }
    final mask = m._mask;
    if (mask != null && !mask.clean && m.heal < 1) {
      holes.addPath(mask.path, Offset.zero);
    }
    concealed = Path.combine(PathOperation.difference, concealed, holes);
    final clip = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(_slack)),
      concealed,
    );
    _clipLayer = context.pushClipPath(
      true,
      offset,
      Offset.zero & size,
      clip,
      (ctx, off) => ctx.paintChild(child, off),
      oldLayer: _clipLayer,
    );
  }

  @override
  void dispose() {
    _clipLayer = null;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Shared state
// ---------------------------------------------------------------------------

/// Everything the veiled text, the dust painter and the gestures read: the
/// measured geometry, the wipe mask, the particle field, and where the
/// reveal and gather currently are.
///
/// A plain object rather than a notifier — the animation controllers already
/// drive repaints; this just holds what they are driving. Public only
/// because [VeiledText] takes one; not for use outside this library.
class VeilModel {
  VeilModel({required this.seed});

  final int seed;

  /// One rect per visual line of veiled text, in the veiled text's box.
  List<Rect> rects = const [];
  Rect bounds = Rect.zero;

  /// Bumped when [rects] change, so the dust layer repaints for a geometry
  /// change even under calm motion, where nothing else drives it.
  final ValueNotifier<int> geometry = ValueNotifier<int>(0);

  _WipeMask? _mask;
  _DustField? _field;
  Float32List? _stipple;

  /// The dust boiling off a wipe, while there is any (see [RubField]).
  RubField? boil;

  /// The veiled text's own box, which the boil stays inside (give or take
  /// the bubble's padding).
  Rect box = Rect.zero;

  /// The wipe, as the boil reads it.
  late final RubHole hole = _VeilHole(this);

  bool calm = false;
  double dpr = 3;
  int inkRgb = 0xFFFFFF;

  /// Seconds of dust time; only advances while the ticker runs.
  double time = 0;

  double reveal = 0;
  double heal = 0;
  bool gathering = false;
  bool revealing = false;
  Offset origin = Offset.zero;
  Offset? touch;

  /// Farthest corner from [origin], fixed at the start of a reveal.
  double _far = 0;

  /// Wind for the current gather, a unit vector, and the projection range
  /// the front sweeps across.
  Offset wind = const Offset(1, 0);
  double _pMin = 0;
  double _pMax = 0;
  List<double> lineJitter = const [];

  /// A partial wipe healing: its own wind and the projection range its front
  /// sweeps — the wiped hole's, not the whole veil's, so the sweep is scaled
  /// to what it has to close.
  bool healing = false;
  Offset healWind = const Offset(1, 0);
  double _healPMin = 0;
  double _healPMax = 0;

  /// Width of the soft band on a healing hole's front. Narrower than
  /// [frontBand]: a thumb-stroke is only so wide.
  static const double healBand = 50;
  static const double healPad = healBand + 6;
  double get _healSpan => _healPMax - _healPMin + 2 * healPad;

  /// Width of the soft band between concealed and clear on the wind front.
  static const double frontBand = 80;

  /// Per-line scatter of the front, in px. The sweep is widened by this on
  /// both ends so every line still starts fully clear and ends fully covered.
  static const double frontJitter = 20;

  /// Where along the wavefront's radius the words are fully clear.
  static const double waveRim = 0.72;

  /// How far past the farthest corner the wavefront travels, so the last
  /// mote is well clear before the animation ends.
  static const double waveOvershoot = 46;

  bool get open => reveal >= 1 && !gathering;

  /// The healing front's position along [healWind] at [t] ∈ 0..1.
  double healFrontAt(double t) => (_healPMin - healPad) + t * _healSpan;

  /// Concealed with nothing in flight — the state that needs no layers.
  bool get still =>
      reveal <= 0 && !gathering && (_mask == null || _mask!.clean) && heal <= 0;

  /// 0 at the start of a gather, 1 when the dust has fully returned.
  double get gather => gathering ? 1 - reveal : 0;

  double get waveRadius {
    if (reveal <= 0 || gathering) return 0;
    return Curves.easeOutCubic.transform(reveal) * (_far + waveOvershoot);
  }

  /// The wind front's position along [wind] at [t] ∈ 0..1.
  double frontAt(double t) {
    const pad = frontBand + frontJitter;
    return (_pMin - pad) + t * (_pMax - _pMin + 2 * pad);
  }

  void adopt(List<Rect> flat) {
    if (listEquals(flat, rects)) return;
    rects = flat;
    var b = flat.isEmpty ? Rect.zero : flat.first;
    for (final r in flat.skip(1)) {
      b = b.expandToInclude(r);
    }
    bounds = b;
    _mask = flat.isEmpty ? null : _WipeMask.covering(flat);
    _stipple = null;
    boil = null;
    lineJitter = List<double>.filled(flat.length, 0);
    _rebuildField();
    geometry.value++;
  }

  void setCalm(bool value) {
    if (value == calm) return;
    calm = value;
    boil = null;
    _rebuildField();
    geometry.value++;
  }

  /// A fresh field for the current geometry — or none, under calm. Stepped
  /// once at zero so its buffers are full before the first paint.
  void _rebuildField() {
    if (calm || rects.isEmpty) {
      _field = null;
      return;
    }
    _field = _DustField(rects, seed, dpr)..step(this, 0);
  }

  void beginReveal(Offset at) {
    gathering = false;
    revealing = true;
    origin = at;
    var far = 0.0;
    for (final r in rects) {
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        far = math.max(far, (c - at).distance);
      }
    }
    _far = far;
    _field?.beginReveal();
  }

  void endReveal() {
    revealing = false;
  }

  void beginGather(math.Random rand) {
    // Mostly sideways — reading direction or against it — with a tilt, so
    // the dust crosses the words rather than falling on them.
    final tilt = (rand.nextDouble() - 0.5) * (math.pi / 3);
    final sign = rand.nextBool() ? 1.0 : -1.0;
    wind = Offset(math.cos(tilt) * sign, math.sin(tilt));
    var pMin = double.infinity;
    var pMax = double.negativeInfinity;
    for (final r in rects) {
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final p = c.dx * wind.dx + c.dy * wind.dy;
        pMin = math.min(pMin, p);
        pMax = math.max(pMax, p);
      }
    }
    _pMin = pMin.isFinite ? pMin : 0;
    _pMax = pMax.isFinite ? pMax : 0;
    lineJitter = [
      for (var i = 0; i < rects.length; i++)
        (rand.nextDouble() * 2 - 1) * frontJitter,
    ];
    gathering = true;
    revealing = false;
    _field?.prepareGather(this, rand);
  }

  void endGather() {
    gathering = false;
    _field?.endGather();
  }

  void beginHeal(math.Random rand) {
    final mask = _mask;
    if (mask == null || mask.clean) return;
    final tilt = (rand.nextDouble() - 0.5) * (math.pi / 3);
    final sign = rand.nextBool() ? 1.0 : -1.0;
    healWind = Offset(math.cos(tilt) * sign, math.sin(tilt));
    final b = mask.holeBounds;
    var pMin = double.infinity;
    var pMax = double.negativeInfinity;
    for (final c in [b.topLeft, b.topRight, b.bottomLeft, b.bottomRight]) {
      final p = c.dx * healWind.dx + c.dy * healWind.dy;
      pMin = math.min(pMin, p);
      pMax = math.max(pMax, p);
    }
    _healPMin = pMin.isFinite ? pMin : 0;
    _healPMax = pMax.isFinite ? pMax : 0;
    healing = true;
    _field?.prepareHeal(this);
  }

  void endHeal() {
    if (!healing) return;
    healing = false;
    _field?.endHeal(healWind);
  }

  /// A static stipple standing in for the field under calm motion —
  /// deterministic, allocated once, never stepped.
  Float32List stipple() {
    final have = _stipple;
    if (have != null) return have;
    final rand = math.Random(seed ^ 0x57A7);
    var n = 0;
    for (final r in rects) {
      n += (r.width * r.height / 14).round().clamp(12, 600);
    }
    final pts = Float32List(n * 2);
    var k = 0;
    for (final r in rects) {
      final count = (r.width * r.height / 14).round().clamp(12, 600);
      for (var i = 0; i < count && k < n; i++, k++) {
        pts[2 * k] = r.left + rand.nextDouble() * r.width;
        pts[2 * k + 1] = r.top + rand.nextDouble() * r.height;
      }
    }
    return _stipple = pts;
  }

  void dispose() {
    geometry.dispose();
  }
}

// ---------------------------------------------------------------------------
// The dust
// ---------------------------------------------------------------------------

/// The particle field over one veil: every mote of every line, in one set of
/// buffers, drawn with one call.
///
/// An emitter, not a shimmer. Each mote is born somewhere in its line, drifts
/// off on its own heading, is bent by a slow current, fades in and out over a
/// life of a second or two, and is reborn elsewhere when it dies or wanders
/// out. Nothing repeats and nothing has a direction in common — which is the
/// whole difference between dust and machinery. The old field's motes were
/// each tethered to a home and wandered a Lissajous figure around it forever;
/// that is a static that twinkles, not a thing that travels.
///
/// Buffers are allocated once per geometry and mutated in place; [step]
/// allocates nothing.
class _DustField {
  _DustField(this.rects, int seed, double dpr)
      : _rand = math.Random(seed) {
    var wanted = 0;
    for (final r in rects) {
      wanted += _wantedFor(r);
    }
    // A whole long message set to spoiler is the pathological case; scale
    // the field down proportionally rather than letting it grow unbounded.
    final scale = wanted > _globalCap ? _globalCap / wanted : 1.0;
    var total = 0;
    final perRect = <int>[];
    for (final r in rects) {
      final n = (_wantedFor(r) * scale).round().clamp(8, 2200);
      perRect.add(n);
      total += n;
    }
    count = total;
    x = Float32List(total);
    y = Float32List(total);
    vx = Float32List(total);
    vy = Float32List(total);
    kx = Float32List(total);
    ky = Float32List(total);
    age = Float32List(total);
    life = Float32List(total);
    size = Float32List(total);
    peak = Float32List(total);
    rnd = Float32List(total);
    homeX = Float32List(total);
    homeY = Float32List(total);
    upwind = Float32List(total);
    stagger = Float32List(total);
    rectOf = Uint16List(total);
    live = Uint8List(total);
    sparkle = Uint8List(total);
    arrived = Uint8List(total);
    gated = Uint8List(total);
    transforms = Float32List(total * 4);
    spriteRects = Float32List(total * 4);
    colors = Int32List(total);
    points = Float32List(total * 2);

    // The smallest grain that still registers.
    final floor = SpoilerGrain.floorFor(dpr);
    var i = 0;
    for (var ri = 0; ri < rects.length; ri++) {
      for (var j = 0; j < perRect[ri]; j++, i++) {
        rectOf[i] = ri;
        rnd[i] = _rand.nextDouble();
        // The spoiler grain, shared with the dust over hidden media (see
        // [SpoilerGrain]): one recipe, so a spoiler is the same stuff
        // wherever it is.
        if (SpoilerGrain.pick(_rand, floor, size, peak, i)) sparkle[i] = 1;
        _spawn(i, fresh: false);
      }
    }
  }

  /// Roughly one mote per 5px². Dense enough to read as a haze with
  /// sparkles in it rather than as dots — at one per 8px² the field, seen at
  /// full size, was a scatter of specks with bubble showing between them.
  static int _wantedFor(Rect r) =>
      (r.width * r.height / 5).round().clamp(32, 2200);

  static const int _globalCap = 6000;

  /// How quickly an impulse — a fingertip's draught, the wavefront, the wind
  /// — dies away, per second. A kick of v px/s therefore carries a mote about
  /// v / [_kickDecay] px before the drift has it back.
  static const double _kickDecay = 3.5;

  /// Nominal reach of the draught around a fingertip. Scaled per mote so the
  /// disturbed patch has a ragged edge; a shared radius draws a clean circle,
  /// which is what a magnifier looks like.
  static const double _draughtRadius = 34;

  /// Acceleration at the centre of the draught, px/s².
  static const double _draughtAccel = 2600;

  /// How far ahead of the wavefront motes are caught and thrown.
  static const double _waveLead = 34;

  final List<Rect> rects;
  final math.Random _rand;
  late final int count;

  late final Float32List x, y, vx, vy, kx, ky, age, life, size, peak, rnd;
  late final Float32List homeX, homeY, upwind, stagger;
  late final Uint16List rectOf;
  late final Uint8List live, sparkle, arrived, gated;

  /// Render buffers, compacted each step: the first [alive] entries of each
  /// are the motes to draw.
  late final Float32List transforms, spriteRects, points;
  late final Int32List colors;
  int alive = 0;

  /// While revealing, a dead mote stays dead: the field empties as the front
  /// passes and never refills.
  bool revealing = false;
  bool gathering = false;

  /// While a wipe heals, the motes that belong to the hole are [gated]: held
  /// back until the front reaches their spot, then blown in on it.
  bool healing = false;

  void _spawn(int i, {required bool fresh}) {
    final r = rects[rectOf[i]];
    x[i] = r.left + _rand.nextDouble() * r.width;
    y[i] = r.top + _rand.nextDouble() * r.height;
    _relaunch(i, fresh: fresh);
  }

  /// New heading, speed and life for a mote already positioned.
  void _relaunch(int i, {required bool fresh}) {
    final heading = _rand.nextDouble();
    final speed = SpoilerGrain.speed(_rand);
    vx[i] = DustTrig.sin(heading + 0.25) * speed;
    vy[i] = DustTrig.sin(heading) * speed;
    life[i] = SpoilerGrain.life(_rand);
    // A field seeded mid-life is steady from its first frame, rather than
    // every mote being born together and dying together.
    age[i] = fresh ? 0 : _rand.nextDouble() * life[i];
    kx[i] = 0;
    ky[i] = 0;
    live[i] = 1;
  }

  void beginReveal() {
    revealing = true;
  }

  /// Sets every mote up to arrive on the wind: a home along its line, a
  /// moment to arrive keyed to when the front reaches that home, and how far
  /// upwind it starts.
  void prepareGather(VeilModel m, math.Random rand) {
    gathering = true;
    revealing = false;
    final w = m.wind;
    const pad = VeilModel.frontBand + VeilModel.frontJitter;
    final span = m._pMax - m._pMin + 2 * pad;
    for (var i = 0; i < count; i++) {
      final r = rects[rectOf[i]];
      homeX[i] = r.left + rand.nextDouble() * r.width;
      homeY[i] = r.top + rand.nextDouble() * r.height;
      final p = homeX[i] * w.dx + homeY[i] * w.dy;
      final whenFrontPasses = (p - (m._pMin - pad)) / span;
      // Slightly BEFORE the front passes its home: the dust is what dims the
      // words, so it has to be there first.
      stagger[i] =
          (whenFrontPasses - 0.06 - rand.nextDouble() * 0.12).clamp(0.0, 0.97);
      upwind[i] = 25 + rand.nextDouble() * 40;
      arrived[i] = 0;
      live[i] = 0;
    }
  }

  void endGather() {
    gathering = false;
    for (var i = 0; i < count; i++) {
      if (arrived[i] == 0) _arrive(i, const Offset(1, 0));
    }
  }

  /// Sets the motes over a wiped hole up to blow back in on the heal's wind,
  /// each when the front reaches where it sits. Everything outside the hole
  /// is left exactly as it is — the heal is local.
  void prepareHeal(VeilModel m) {
    healing = true;
    final mask = m._mask;
    if (mask == null) return;
    for (var i = 0; i < count; i++) {
      gated[i] = 0;
      if (live[i] == 1 && mask.clearedAt(x[i], y[i]) > 0.25) _gate(i, m);
    }
  }

  /// Holds mote [i] where it is until the healing front passes it.
  void _gate(int i, VeilModel m) {
    gated[i] = 1;
    arrived[i] = 0;
    live[i] = 0;
    homeX[i] = x[i];
    homeY[i] = y[i];
    final w = m.healWind;
    final p = homeX[i] * w.dx + homeY[i] * w.dy;
    final whenFrontPasses =
        (p - (m._healPMin - VeilModel.healPad)) / m._healSpan;
    stagger[i] =
        (whenFrontPasses - 0.05 - _rand.nextDouble() * 0.1).clamp(0.0, 0.97);
    // A shorter run-up than the full gather: the hole is a thumb wide.
    upwind[i] = 10 + _rand.nextDouble() * 20;
  }

  void endHeal(Offset wind) {
    healing = false;
    for (var i = 0; i < count; i++) {
      if (gated[i] == 1 && arrived[i] == 0) _arrive(i, wind);
      gated[i] = 0;
    }
  }

  /// Blows mote [i] in from upwind: born at zero age, offset against the
  /// wind, carrying a kick that lands it on its home as the kick dies.
  void _arrive(int i, Offset w) {
    arrived[i] = 1;
    x[i] = homeX[i] - w.dx * upwind[i];
    y[i] = homeY[i] - w.dy * upwind[i];
    _relaunch(i, fresh: true);
    // Travel under exponential decay is v / decay, so this lands at home,
    // give or take the perpendicular scatter that keeps the arrival ragged.
    final v = upwind[i] * _kickDecay;
    final scatter = (rnd[i] - 0.5) * 40;
    kx[i] = w.dx * v - w.dy * scatter;
    ky[i] = w.dy * v + w.dx * scatter;
  }

  /// Advances every mote by [dt] and fills the render buffers.
  void step(VeilModel m, double dt) {
    final time = m.time;
    final decay = math.exp(-_kickDecay * dt);
    final touch = m.touch;
    final tx = touch?.dx ?? 0;
    final ty = touch?.dy ?? 0;
    final wave = m.waveRadius;
    final ox = m.origin.dx;
    final oy = m.origin.dy;
    final gatherT = m.gather;
    final wind = m.wind;
    final mask = m._mask;
    final wiped = mask != null && !mask.clean;
    final heal = m.heal;
    final healWind = m.healWind;
    final inkRgb = m.inkRgb;
    final spritePx = DustSprite.pxFor(m.dpr).toDouble();

    var k = 0;
    for (var i = 0; i < count; i++) {
      if (gathering && arrived[i] == 0) {
        if (gatherT < stagger[i]) continue;
        _arrive(i, wind);
      }
      if (healing && gated[i] == 1 && arrived[i] == 0) {
        if (heal < stagger[i]) continue;
        _arrive(i, healWind);
      }
      if (live[i] == 0) continue;

      var px = x[i];
      var py = y[i];

      // The current (see [SpoilerGrain.flowX]).
      final flowX = SpoilerGrain.flowX(px, py, time);
      final flowY = SpoilerGrain.flowY(px, py, time);

      var ax = 0.0;
      var ay = 0.0;

      // The draught. An acceleration, not a displacement: the mote is thrown
      // and then coasts, which is what makes this air rather than a lens
      // that follows the fingertip around.
      if (touch != null) {
        final reach = _draughtRadius * (0.6 + 0.8 * rnd[i]);
        final dx = px - tx;
        final dy = py - ty;
        final d2 = dx * dx + dy * dy;
        if (d2 < reach * reach) {
          final d = math.sqrt(d2);
          final falloff = 1 - d / reach;
          final f = falloff * falloff;
          // Outward, then knocked well off that line by a direction of the
          // mote's own — scattered, not radial, and with no tangential term:
          // a curl makes the field orbit the finger, which is a turbine.
          var ex = d > 0.001 ? dx / d : 0.0;
          var ey = d > 0.001 ? dy / d : -1.0;
          ex += DustTrig.sin(rnd[i] * 0.9 + 0.25) * 0.9;
          ey += DustTrig.sin(rnd[i] * 0.9) * 0.9;
          final el = math.sqrt(ex * ex + ey * ey);
          if (el > 0.001) {
            ex /= el;
            ey /= el;
          }
          ax += ex * _draughtAccel * f;
          ay += ey * _draughtAccel * f;
          // Turbulence on top, wandering in time, so the scatter keeps
          // changing for as long as the finger is down.
          ax += DustTrig.sin(time * 0.43 + rnd[i] * 13) * _draughtAccel * f * 0.5;
          ay += DustTrig.sin(time * 0.49 + rnd[i] * 17) * _draughtAccel * f * 0.5;
        }
      }

      // The wavefront. Motes inside the clear disc are gone; motes just
      // ahead of the rim are thrown outward and given a fraction of a second
      // to live, so they fade in flight rather than popping at the edge.
      if (revealing && wave > 0) {
        final dx = px - ox;
        final dy = py - oy;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < wave * VeilModel.waveRim - 3) {
          live[i] = 0;
          continue;
        }
        final lead = (1 - (dist - wave) / _waveLead).clamp(0.0, 1.0);
        if (lead > 0) {
          final nx = dist > 0.001 ? dx / dist : 0.0;
          final ny = dist > 0.001 ? dy / dist : -1.0;
          final f = lead * lead;
          ax += nx * 1400 * f + DustTrig.sin(rnd[i] * 0.7 + 0.25) * 600 * f;
          ay += ny * 1400 * f + DustTrig.sin(rnd[i] * 0.7) * 600 * f;
          final remaining = age[i] + 0.18;
          if (life[i] > remaining) life[i] = remaining;
        }
      }

      kx[i] = kx[i] * decay + ax * dt;
      ky[i] = ky[i] * decay + ay * dt;
      px += (vx[i] + flowX + kx[i]) * dt;
      py += (vy[i] + flowY + ky[i]) * dt;
      age[i] += dt;

      // Death: of old age, or of wandering out of the line. Reborn somewhere
      // else in the line — unless the reveal is on, in which case the field
      // is meant to be emptying.
      final r = rects[rectOf[i]];
      if (age[i] >= life[i] ||
          px < r.left - 2 ||
          px > r.right + 2 ||
          py < r.top - 2 ||
          py > r.bottom + 2) {
        if (revealing) {
          live[i] = 0;
          continue;
        }
        _spawn(i, fresh: true);
        px = x[i];
        py = y[i];
        // Born into a healing hole: wait for the front like the rest.
        if (healing && wiped && mask.clearedAt(px, py) > 0.25) {
          _gate(i, m);
          continue;
        }
      } else {
        x[i] = px;
        y[i] = py;
      }

      // Alpha: a fade in over the first quarter of a life, a fade out over
      // the last third, and a twinkle on the sparkles.
      var a = peak[i] * SpoilerGrain.envelope(age[i] / life[i]);
      if (sparkle[i] == 1) a *= SpoilerGrain.twinkle(time, rnd[i]);
      // A wiped cell is a window: no dust over words the reader has already
      // uncovered. A mote the heal has blown in is over covered words by
      // construction, so it is exempt; the rest keep their window.
      if (wiped && !(healing && gated[i] == 1)) {
        a *= 1 - mask.clearedAt(px, py) * (healing ? 1 - heal : 1);
      }
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
      colors[k] = ((a * 255).round() << 24) | inkRgb;
      points[2 * k] = px;
      points[2 * k + 1] = py;
      k++;
    }
    alive = k;
  }
}

/// Draws the field — one `drawRawAtlas` for every mote of every line — or,
/// under calm motion, the static stipple.
class _DustPainter extends CustomPainter {
  _DustPainter({
    required Listenable repaint,
    required this.model,
    required this.ink,
  }) : super(repaint: repaint);

  final VeilModel model;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final m = model;
    if (m.rects.isEmpty) return;
    if (m.open) {
      // Readable again; only the last of the boil is still in the air.
      m.boil?.paint(canvas);
      return;
    }

    if (m.calm) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        m.stipple(),
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.4,
      );
      return;
    }

    final field = m._field;
    if (field == null) return;
    final n = field.alive;
    if (n == 0) {
      m.boil?.paint(canvas);
      return;
    }

    DustAtlas.draw(
      canvas,
      sprite: DustSprite.forDpr(m.dpr),
      transforms: field.transforms,
      spriteRects: field.spriteRects,
      colors: field.colors,
      alive: n,
      points: field.points,
      fallbackInk: ink.withValues(alpha: 0.6),
    );
    // Over the field: the boil streams out across the wipe's rim, which is
    // what makes the rim.
    m.boil?.paint(canvas);
  }

  @override
  bool shouldRepaint(_DustPainter old) =>
      !identical(old.model, model) || old.ink != ink;

  /// Decoration only. Spelled out because it is load-bearing: a hit-testing
  /// painter here would swallow taps on every link in the paragraph.
  @override
  bool hitTest(Offset position) => false;
}

/// The wipe as [RubField] reads it: the mask's discs and clearance, and the
/// model's heal.
class _VeilHole implements RubHole {
  _VeilHole(this.m);

  final VeilModel m;

  @override
  int get discs => m._mask?._cx.length ?? 0;
  @override
  double discX(int j) => m._mask!._cx[j];
  @override
  double discY(int j) => m._mask!._cy[j];
  @override
  double discR(int j) => m._mask!._cr[j];
  @override
  double get rimRadius => _WipeMask.brush;
  @override
  double clearedAt(double x, double y) => m._mask?.clearedAt(x, y) ?? 0;
  @override
  bool get healing => m.healing;
  @override
  Offset get healWind => m.healWind;
  @override
  double get healPMin => m._healPMin;
  @override
  double get healPadding => VeilModel.healPad;
  @override
  double get healSpan => m._healSpan;
}

// ---------------------------------------------------------------------------
// The wipe
// ---------------------------------------------------------------------------

/// The wipe's memory, kept twice over: a [Path] of where the finger actually
/// went, which is what gets painted, and a low-res alpha grid, which is what
/// gets asked questions.
///
/// The grid answers "how much of this is open" and "is this point already
/// clear" in constant time, at ~7-logical-px cells — far below glyph size,
/// and a few kilobytes for a long spoiler. But it must not be what you SEE:
/// rasterising it as one rect per cell drew the grid itself, a staircase of
/// 7px squares along every feathered edge. The path is a heap of discs with
/// a blur instead, so the hole has a fingertip's soft edge for one draw call.
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
  /// gradient down both sides, which is a paint stroke. Discs of varying
  /// size, jittered off the path and flecked with smaller satellites, give a
  /// boundary that crumbles instead of ruling, which is what rubbing dust
  /// away actually looks like. Non-zero fill unions them for free.
  final Path path = Path();

  /// Deterministic per mask, so a rebuild of the same wipe looks the same.
  final math.Random _rand = math.Random(0x5EED);

  /// Every disc, kept alongside [path] so the heal can find the hole's
  /// extent.
  final List<double> _cx = [];
  final List<double> _cy = [];
  final List<double> _cr = [];

  Offset? _lastStamp;
  int _discs = 0;
  bool _any = false;

  /// Nothing has been wiped — the overwhelmingly common state, and the one
  /// where the veiled text can skip its layers entirely.
  bool get clean => !_any;

  /// Distance the finger must travel before another disc is laid down.
  static const double _stampSpacing = 3.5;

  /// Past this many discs the satellites stop, so a marathon scrub cannot
  /// grow a path that costs real time to rasterise and blur every frame.
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
      // pencil eraser leaves a fat mark where you linger.
      final speed = travelled.isFinite ? travelled : 0.0;
      final r = brush *
          (1.18 - speed / 70).clamp(0.78, 1.18) *
          (0.86 + _rand.nextDouble() * 0.3);
      _addDisc(point, r);
      _discs++;

      // Flecks around the rim. These are what stop the boundary reading as
      // a shape at all.
      if (_discs < _satelliteBudget) {
        for (var s = 0; s < 2; s++) {
          final a = _rand.nextDouble() * 2 * math.pi;
          final d = r * (0.6 + _rand.nextDouble() * 0.45);
          _addDisc(
            point + Offset(math.cos(a) * d, math.sin(a) * d * 0.7),
            r * (0.16 + _rand.nextDouble() * 0.2),
          );
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

  void _addDisc(Offset c, double r) {
    path.addOval(Rect.fromCircle(center: c, radius: r));
    _cx.add(c.dx);
    _cy.add(c.dy);
    _cr.add(r);
  }

  /// The box around every disc — what a heal has to sweep across.
  Rect get holeBounds {
    if (_cx.isEmpty) return bounds;
    var l = double.infinity;
    var t = double.infinity;
    var r = double.negativeInfinity;
    var b = double.negativeInfinity;
    for (var j = 0; j < _cx.length; j++) {
      l = math.min(l, _cx[j] - _cr[j]);
      t = math.min(t, _cy[j] - _cr[j]);
      r = math.max(r, _cx[j] + _cr[j]);
      b = math.max(b, _cy[j] + _cr[j]);
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  /// Back to full dust.
  void reset() {
    values.fillRange(0, values.length, 0);
    path.reset();
    _cx.clear();
    _cy.clear();
    _cr.clear();
    _lastStamp = null;
    _discs = 0;
    _any = false;
  }

  /// How clear the cell under [x],[y] is, 0..1.
  double clearedAt(double x, double y) {
    final cx = ((x - bounds.left) / cell).floor();
    final cy = ((y - bounds.top) / cell).floor();
    if (cx < 0 || cx >= cols || cy < 0 || cy >= rows) return 0;
    return values[cy * cols + cx].clamp(0.0, 1.0);
  }

  bool isCleared(Offset point) => clearedAt(point.dx, point.dy) >= 0.75;

  double get clearedFraction {
    if (_totalWeight == 0) return 0;
    var cleared = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (weights[i] > 0) cleared += math.min(1, values[i]);
    }
    return cleared / _totalWeight;
  }
}
