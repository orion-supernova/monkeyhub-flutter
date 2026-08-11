import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../data/spoiler_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import 'paragraph_geometry.dart';

/// The dust veil over a message's spoiler text, and the finger-wipe that
/// clears it.
///
/// Sits as a `Positioned.fill` sibling ABOVE the paragraph (which renders the
/// hidden text normally — layout must be real so the bubble is the right
/// size, and so the reveal uncovers words that were always exactly there).
/// The veil is a near-opaque fill in the text's own ink with a field of
/// drifting dust motes over it; the opacity is the concealment, the dust is
/// what says "there is something under here".
///
/// **The wipe.** A pan that STARTS on dust claims the gesture outright (see
/// [_WipeGestureRecognizer]) and erases a soft-brush stroke from a low-res
/// alpha mask; only the wiped cells go clear, so a half-hearted smudge
/// reveals a half-readable secret — which is the point. Once ~85% of the
/// veiled area is clear the remainder dissolves on its own and the reveal is
/// recorded (session-only) in [SpoilerStore].
///
/// **Calm motion** builds a different thing entirely, per the MotionScope
/// contract: no ticker, no particles — a static veil that a single tap fades
/// away. Screen readers get the same tap-reveal through [Semantics] in both
/// modes, because a wipe is not an accessible gesture.
///
/// **Partial state is disposable.** The mask lives in this State and dies
/// with it; scrolling a half-wiped spoiler away re-veils it. Only the full
/// reveal outlives the widget, via the store.
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

  /// Key on the paragraph this overlay covers — resolved post-frame to a
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

  /// Drives the dust drift. Created only outside calm motion.
  AnimationController? _drift;

  /// Drives the final dissolve once the wipe crosses the threshold, and the
  /// tap-reveal in calm mode. 0 = veil fully present, 1 = gone.
  late final AnimationController _dissolve = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SpoilerStore.instance.reveal(widget.contextId);
        widget.onRevealed();
      }
    });

  _WipeMask? _mask;
  bool _dissolving = false;
  Offset? _lastWipePoint;

  @override
  void didUpdateWidget(SpoilerOverlay old) {
    super.didUpdateWidget(old);
    if (old.ranges != widget.ranges) scheduleMeasure();
  }

  @override
  void dispose() {
    _drift?.dispose();
    _dissolve.dispose();
    super.dispose();
  }

  /// A fresh mask per measurement. Re-measuring mid-wipe therefore re-veils
  /// what had been wiped — consistent with partial state being disposable
  /// (see the class doc), and a rotation is not a subtle event to lose it to.
  @override
  void onMeasured(List<List<Rect>> value) {
    final flat = [for (final group in value) ...group];
    if (flat.isEmpty) return;
    setState(() {
      _rects = flat;
      _mask = _WipeMask.covering(flat);
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
    if (mask.clearedFraction >= 0.85) {
      _dissolving = true;
      _dissolve.forward();
    }
    setState(() {});
  }

  void _revealWhole() {
    if (_dissolving) return;
    _dissolving = true;
    _dissolve.forward();
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

  @override
  Widget build(BuildContext context) {
    // Still armed with nothing to paint: the notifier has to be mounted even
    // in the empty state, or a first measurement that lands before the
    // paragraph is ready has nothing to retry it.
    if (_rects.isEmpty) {
      return watchLayout(child: const SizedBox.expand());
    }
    final motion = MotionScope.of(context);

    // Calm is a code path: no ticker, no particles, no wipe tracking — a
    // static veil and a tap. The controllers for the full effect are simply
    // never created.
    if (motion.calm) {
      _drift?.dispose();
      _drift = null;
    } else {
      _drift ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    }

    final semantics = watchLayout(
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context).spoilerRevealHint,
        onTap: _revealWhole,
        child: AnimatedBuilder(
          animation: _dissolve,
          builder: (_, _) => AnimatedBuilder(
            // Merged rather than nested when the drift exists; under calm the
            // dissolve alone drives repaints.
            animation: _drift ?? _dissolve,
            builder: (_, _) => CustomPaint(
              painter: _SpoilerDustPainter(
                rects: _rects,
                cover: widget.cover,
                dust: widget.dust,
                mask: motion.calm ? null : _mask,
                phase: _drift?.value ?? 0,
                dissolve: Curves.easeOut.transform(_dissolve.value),
                seed: widget.contextId.hashCode,
                calm: motion.calm,
              ),
            ),
          ),
        ),
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
            () => _VeilTapRecognizer(hitTest: (global) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || !box.attached) return false;
              return _hitsVeil(box.globalToLocal(global));
            }),
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
          () => _WipeGestureRecognizer(hitTest: (global) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || !box.attached) return false;
            return _hitsVeil(box.globalToLocal(global));
          }),
          (r) {
            r.onStart = (d) {
              _lastWipePoint = null;
              _wipeAt(d.localPosition);
            };
            r.onUpdate = (d) => _wipeAt(d.localPosition);
            r.onEnd = (_) {
              _lastWipePoint = null;
            };
          },
        ),
      },
      child: semantics,
    );
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
/// `_hitsVeil`) — a trade QA can re-litigate with a tap-to-engage variant if
/// real thumbs disagree.
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

/// Paints the veil: cover fills, drifting dust, and the wipe holes punched
/// through both.
///
/// One `saveLayer` per paint so `BlendMode.dstOut` erases only this painter's
/// own pixels — never the text (or bubble) underneath.
class _SpoilerDustPainter extends CustomPainter {
  _SpoilerDustPainter({
    required this.rects,
    required this.cover,
    required this.dust,
    required this.mask,
    required this.phase,
    required this.dissolve,
    required this.seed,
    required this.calm,
  });

  final List<Rect> rects;
  final Color cover;
  final Color dust;
  final _WipeMask? mask;
  final double phase;
  final double dissolve;
  final int seed;
  final bool calm;

  @override
  void paint(Canvas canvas, Size size) {
    if (dissolve >= 1) return;
    final layerAlpha = 1 - dissolve;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, layerAlpha),
    );

    // 1. The concealment. Near-opaque — this fill, not the dust, is what
    //    keeps the text unreadable.
    final fill = Paint()..color = cover.withValues(alpha: 0.96);
    for (final r in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        fill,
      );
    }

    // 2. The dust. Seeded by the message so the field is stable across
    //    rebuilds (the _GrainPainter precedent); each mote wanders a couple
    //    of pixels on its own phase and shimmers against the cover. Skipped
    //    entirely under calm — the static veil is the whole effect there.
    if (!calm) {
      final rand = math.Random(seed);
      final mote = Paint();
      for (final r in rects) {
        final count =
            math.min(60, math.max(8, (r.width * r.height / 110).round()));
        for (var i = 0; i < count; i++) {
          final baseX = r.left + rand.nextDouble() * r.width;
          final baseY = r.top + rand.nextDouble() * r.height;
          final own = rand.nextDouble();
          final t = 2 * math.pi * ((phase + own) % 1.0);
          final drift = Offset(math.cos(t + own * 9), math.sin(t)) *
              (1.2 + own * 1.4);
          final twinkle = 0.35 + 0.5 * (0.5 + 0.5 * math.sin(t * 2 + own * 7));
          mote.color = dust.withValues(alpha: twinkle);
          canvas.drawCircle(
            Offset(baseX, baseY) + drift,
            0.6 + own * 0.9,
            mote,
          );
        }
      }
    }

    // 3. The holes. Each cleared cell erases this layer's pixels by its own
    //    alpha, so the reveal has the brush's feathered edge.
    final m = mask;
    if (m != null) {
      final hole = Paint()..blendMode = BlendMode.dstOut;
      for (var y = 0; y < m.rows; y++) {
        for (var x = 0; x < m.cols; x++) {
          final v = m.values[y * m.cols + x];
          if (v <= 0.01) continue;
          hole.color = Color.fromRGBO(0, 0, 0, math.min(1, v));
          canvas.drawRect(
            Rect.fromLTWH(
              m.bounds.left + x * _WipeMask.cell,
              m.bounds.top + y * _WipeMask.cell,
              _WipeMask.cell + 0.5,
              _WipeMask.cell + 0.5,
            ),
            hole,
          );
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpoilerDustPainter old) =>
      old.phase != phase ||
      old.dissolve != dissolve ||
      old.rects != rects ||
      old.cover != cover ||
      old.dust != dust ||
      old.calm != calm;
}
