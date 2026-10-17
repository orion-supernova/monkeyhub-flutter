import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../widgets/capture_glyphs.dart';

// The call tray's drawn glyphs.
//
// Filled, the way FaceTime and the Phone app draw their controls (SF's
// `mic.fill`, `video.fill`, `speaker.wave.3.fill`, `airpods`): solid shapes
// with the details cut out of them, never even-weight outlines, which read
// as Material. Drawn on the capture glyphs' 24-unit grid at the shared
// stroke, inside one layer so a cut (the mute slash, the share arrow, the
// flip arrows) shows the button's own fill through it.
//
// Every state change is a phased transition, not a swap:
//
//  * Mute: the mic squashes, then the slash draws through it. Unmute: the
//    slash pulls back out, then the capsule hops and throws two voice ticks.
//  * Camera off: the lens pulls in, then the slash. On: the slash pulls
//    out, then the lens pushes forward and flares.
//  * Earpiece ↔ speaker: the outer waves draw out of the cone one after
//    the other, or fold back in, outermost first.
//  * Speaker ↔ AirPods ↔ headphones: the old shape tips and shrinks away,
//    then the new one springs in on an overshoot (AirPods land one bud
//    after the other).
//  * Share: the arrow launches out of the screen and a stop square pops
//    into the cut; stopping drops the square and the arrow rises back.
//  * Flip, More, Hide: a one-off move per tap (the arrows spin half a lap,
//    the dots hop in turn, the chevron dips).
//
// No idle loops: the tray is resting chrome. Reduce Motion snaps.

/// Which drawn glyph a tray control shows.
enum CallGlyphKind { mic, camera, audio, share, flip, more, hide }

/// Where the sound goes, as the audio control (and the mic's badge) draws
/// it.
enum CallAudioGlyphRoute { receiver, speaker, airpods, headphones }

/// A tray control's drawn glyph and the state it shows.
@immutable
class CallTrayGlyph {
  const CallTrayGlyph(
    this.kind, {
    this.on = false,
    this.route = CallAudioGlyphRoute.receiver,
  });

  /// [headset]: the voice is picked up by a headset's mic; [route] says
  /// which (AirPods or headphones) for the badge.
  const CallTrayGlyph.mic({
    required bool on,
    bool headset = false,
    CallAudioGlyphRoute route = CallAudioGlyphRoute.headphones,
  }) : this(
          CallGlyphKind.mic,
          on: on,
          route: headset ? route : CallAudioGlyphRoute.receiver,
        );

  const CallTrayGlyph.camera({required bool on})
      : this(CallGlyphKind.camera, on: on);

  const CallTrayGlyph.audio(CallAudioGlyphRoute route)
      : this(
          CallGlyphKind.audio,
          on: route != CallAudioGlyphRoute.receiver,
          route: route,
        );

  const CallTrayGlyph.share({required bool on})
      : this(CallGlyphKind.share, on: on);

  final CallGlyphKind kind;

  /// The mic is live, the camera is on, the sound is out of the earpiece,
  /// a share is going out.
  final bool on;

  /// The audio control's route; the mic's headset badge, or [receiver]
  /// for none.
  final CallAudioGlyphRoute route;

  bool get headset =>
      route == CallAudioGlyphRoute.airpods ||
      route == CallAudioGlyphRoute.headphones;

  /// Kinds that move on every tap rather than on a change of state.
  bool get kicksOnTap =>
      kind == CallGlyphKind.flip ||
      kind == CallGlyphKind.more ||
      kind == CallGlyphKind.hide;

  @override
  bool operator ==(Object other) =>
      other is CallTrayGlyph &&
      other.kind == kind &&
      other.on == on &&
      other.route == route;

  @override
  int get hashCode => Object.hash(kind, on, route);
}

/// [glyph] drawn at [size], its ink lerping from [ink] to [litInk] as
/// [lit] (the control's white "on" fill) comes on. [taps] counts the
/// control's taps: a change moves the kinds that move on a tap.
class AnimatedCallGlyph extends StatefulWidget {
  const AnimatedCallGlyph({
    super.key,
    required this.glyph,
    required this.size,
    required this.ink,
    required this.litInk,
    this.lit = false,
    this.taps = 0,
  });

  final CallTrayGlyph glyph;
  final double size;
  final Color ink;
  final Color litInk;
  final bool lit;
  final int taps;

  /// The fill's own fade, so the ink crosses over with it.
  static const fillDuration = Duration(milliseconds: 220);

  @override
  State<AnimatedCallGlyph> createState() => _AnimatedCallGlyphState();
}

class _AnimatedCallGlyphState extends State<AnimatedCallGlyph>
    with TickerProviderStateMixin {
  /// The state being left, and the one arrived at; [_morph] runs between.
  late CallTrayGlyph _from = widget.glyph;
  late CallTrayGlyph _to = widget.glyph;

  /// 0 → 1 across a transition's phases, linear: the painter shapes each
  /// phase itself.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );

  /// 1 on the lit fill: the ink.
  late final AnimationController _lit = AnimationController(
    vsync: this,
    duration: AnimatedCallGlyph.fillDuration,
    value: widget.lit ? 1 : 0,
  );

  /// The tap kinds' one-off move.
  late final AnimationController _kick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(AnimatedCallGlyph old) {
    super.didUpdateWidget(old);
    final g = widget.glyph;
    if (g != _to) {
      // A different control in this slot (the tray reshuffled) snaps; a
      // change of state plays its phases. Interrupted midway, it starts
      // over from the state it was heading for.
      _from = g.kind == _to.kind ? _to : g;
      _to = g;
      if (_calm || g.kind != _from.kind) {
        _morph.value = 1;
      } else {
        _morph.forward(from: 0);
      }
    }
    if (widget.lit != old.lit) {
      if (_calm) {
        _lit.value = widget.lit ? 1 : 0;
      } else {
        _lit.animateTo(widget.lit ? 1 : 0, curve: Curves.easeOut);
      }
    }
    if (widget.taps != old.taps && g.kicksOnTap && !_calm) {
      _kick.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _lit.dispose();
    _kick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _CallGlyphPainter(
            from: _from,
            to: _to,
            ink0: widget.ink,
            ink1: widget.litInk,
            morph: _morph,
            lit: _lit,
            kick: _kick,
          ),
        ),
      );
}

/// Forward and back once over [t], easing out of the push.
double _push(double t) =>
    t <= 0 || t >= 1 ? 0 : math.sin(math.pi * Curves.easeOut.transform(t));

/// Eased windows of a transition.
double _in(double t, double a, double b, [Curve c = Curves.easeOutBack]) =>
    c.transform(glyphSpan(t, a, b));
double _out(double t, double a, double b) =>
    1 - Curves.easeInCubic.transform(glyphSpan(t, a, b));

class _CallGlyphPainter extends GlyphGridPainter {
  _CallGlyphPainter({
    required this.from,
    required this.to,
    required this.ink0,
    required this.ink1,
    required this.morph,
    required this.lit,
    required this.kick,
  }) : super(ink0, repaint: Listenable.merge([morph, lit, kick]));

  final CallTrayGlyph from;
  final CallTrayGlyph to;
  final Color ink0;
  final Color ink1;
  final Animation<double> morph;
  final Animation<double> lit;
  final Animation<double> kick;

  @override
  Color get ink => Color.lerp(ink0, ink1, lit.value.clamp(0.0, 1.0))!;

  /// Where in the transition we are; 1 at rest.
  double get t => morph.value;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    // One layer for the whole glyph, so the cuts erase only the glyph.
    canvas.saveLayer(const Rect.fromLTWH(-6, -6, 36, 36), Paint());
    switch (to.kind) {
      case CallGlyphKind.mic:
        _mic(canvas, line, fill);
      case CallGlyphKind.camera:
        _camera(canvas, line, fill);
      case CallGlyphKind.audio:
        _audio(canvas, line, fill);
      case CallGlyphKind.share:
        _share(canvas, line, fill);
      case CallGlyphKind.flip:
        _flip(canvas, line, fill);
      case CallGlyphKind.more:
        _more(canvas, fill);
      case CallGlyphKind.hide:
        _hide(canvas, line);
    }
    canvas.restore();
  }

  // ── Shared pieces ────────────────────────────────────────────────────────

  static Paint _clearFill() => Paint()..blendMode = BlendMode.clear;

  static Paint _clearLine(double width) => Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// [p] filled with its corners rounded by a stroke of the same ink.
  static void _solid(Canvas canvas, Path p, Paint line, Paint fill) {
    canvas.drawPath(p, fill);
    canvas.drawPath(p, line);
  }

  /// The off slash, top-left to bottom-right, drawn to [d] of its length
  /// and cut out of whatever it crosses.
  static void _slash(Canvas canvas, Paint line, double d) {
    if (d <= 0.001) return;
    const a = Offset(3.6, 3.2);
    const b = Offset(20.4, 20.8);
    final end = Offset.lerp(a, b, d.clamp(0.0, 1.06))!;
    canvas.drawLine(a, end, _clearLine(line.strokeWidth * 2.9));
    canvas.drawLine(a, end, line);
  }

  /// How far the off slash is drawn: in on the way off (after the squash),
  /// out on the way on (before the hop).
  double _slashAmount() {
    if (from.on == to.on) return to.on ? 0 : 1;
    return to.on ? _out(t, 0, 0.4) : _in(t, 0.3, 0.9);
  }

  /// The squash that goes before a slash, and the push after one leaves.
  double get _squash =>
      from.on && !to.on ? math.sin(math.pi * glyphSpan(t, 0, 0.5)) : 0;
  double get _hop => !from.on && to.on ? _push(glyphSpan(t, 0.35, 1)) : 0;

  // ── Mic ──────────────────────────────────────────────────────────────────

  void _mic(Canvas canvas, Paint line, Paint fill) {
    // The badge: in after the mic has stepped aside, out before it returns.
    double badge;
    var badgeRoute = to.headset ? to.route : from.route;
    if (from.headset && to.headset && from.route != to.route) {
      // One headset for another: the old badge out, the new one in.
      final swap = t < 0.4;
      badgeRoute = swap ? from.route : to.route;
      badge = swap ? _out(t, 0, 0.4) : _in(t, 0.4, 1);
    } else if (from.headset == to.headset) {
      badge = to.headset ? 1 : 0;
    } else {
      badge = to.headset ? _in(t, 0.3, 1) : _out(t, 0, 0.45);
    }
    final aside = from.headset && to.headset ? 1.0 : badge.clamp(0.0, 1.0);
    final hop = _hop;
    final squash = _squash;

    canvas.save();
    canvas.translate(12 - 3.6 * aside, 12 - 2.2 * aside);
    canvas.scale(1 - 0.22 * aside);
    canvas.translate(-12, -12);

    // The capsule: squashed toward the yoke before the slash, hopping up
    // after it leaves. Yoke and stand stay planted.
    final top = 2.2 + 2.2 * squash - 2.4 * hop;
    final bottom = 14.4 - 2.4 * hop;
    canvas.drawRRect(
      RRect.fromLTRBR(8.3 - 0.5 * squash, top, 15.7 + 0.5 * squash, bottom,
          const Radius.circular(3.7)),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(5.4, 10.4)
        ..arcToPoint(
          const Offset(18.6, 10.4),
          radius: const Radius.circular(6.6),
          clockwise: false,
        ),
      line,
    );
    canvas.drawLine(const Offset(12, 17.2), const Offset(12, 20.8), line);
    canvas.drawLine(const Offset(8.8, 20.8), const Offset(15.2, 20.8), line);

    // Voice ticks thrown off the capsule's sides with the hop.
    if (hop > 0.02) {
      final tick = Paint()
        ..color = line.color.withValues(alpha: line.color.a * hop)
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.strokeWidth * 0.9
        ..strokeCap = StrokeCap.round;
      final o = 1.8 * hop;
      canvas.drawLine(Offset(5.4 - o, 4.4 - o * 0.5),
          Offset(3.8 - o, 3.0 - o * 0.5), tick);
      canvas.drawLine(Offset(18.6 + o, 4.4 - o * 0.5),
          Offset(20.2 + o, 3.0 - o * 0.5), tick);
    }
    _slash(canvas, line, _slashAmount());
    canvas.restore();

    if (badge > 0.01) {
      final route = badgeRoute;
      canvas.save();
      canvas.translate(17.4, 17.4);
      canvas.scale(math.max(0.0, badge));
      canvas.drawCircle(Offset.zero, 7.6, _clearFill());
      canvas.scale(0.6);
      canvas.translate(-12, -12);
      if (route == CallAudioGlyphRoute.airpods) {
        _airpods(canvas, line, fill, 1, 1);
      } else {
        _headphones(canvas, line, fill, 0);
      }
      canvas.restore();
    }
  }

  // ── Camera ───────────────────────────────────────────────────────────────

  void _camera(Canvas canvas, Paint line, Paint fill) {
    // Off: the lens pulls in first. On: it pushes out and flares once the
    // slash has gone.
    final pull = from.on && !to.on ? _push(glyphSpan(t, 0, 0.55)) : 0.0;
    final push = _hop;
    final x = 1.8 * push - 1.6 * pull;
    final flare = 1.6 * push;
    canvas.drawRRect(
      RRect.fromLTRBR(1.8 - 0.4 * push, 6.2, 15.6 - 0.4 * push, 17.8,
          const Radius.circular(3.4)),
      fill,
    );
    _solid(
      canvas,
      Path()
        ..moveTo(17.4 + x * 0.4, 10.3)
        ..lineTo(21.4 + x, 7.8 - flare)
        ..lineTo(21.4 + x, 16.2 + flare)
        ..lineTo(17.4 + x * 0.4, 13.7)
        ..close(),
      line,
      fill,
    );
    _slash(canvas, line, _slashAmount());
  }

  // ── Audio ────────────────────────────────────────────────────────────────

  static bool _speakerShape(CallAudioGlyphRoute r) =>
      r == CallAudioGlyphRoute.receiver || r == CallAudioGlyphRoute.speaker;

  void _audio(Canvas canvas, Paint line, Paint fill) {
    if (from.route == to.route ||
        (_speakerShape(from.route) && _speakerShape(to.route))) {
      // Same shape: the earpiece and the speaker are one cone with more
      // or fewer waves, and the waves do the moving.
      if (_speakerShape(to.route)) {
        _speaker(canvas, line, fill);
      } else {
        _routeShape(canvas, line, fill, to.route, settle: true);
      }
      return;
    }
    // Different shapes: the old one tips and shrinks away, then the new
    // one springs in past full size and settles.
    final out = _out(t, 0, 0.42);
    final inn = _in(t, 0.34, 1);
    if (out > 0.01) {
      canvas.save();
      canvas.translate(12, 12);
      canvas.rotate(-0.35 * (1 - out));
      canvas.scale(0.4 + 0.6 * out);
      canvas.translate(-12, -12);
      // Faded as one layer: fading the fill and its rounding stroke apart
      // draws a darker rim where they overlap.
      canvas.saveLayer(const Rect.fromLTWH(-6, -6, 36, 36), _alpha(out));
      _routeShape(canvas, line, fill, from.route, settle: true);
      canvas.restore();
      canvas.restore();
    }
    if (inn > 0.01) {
      canvas.save();
      canvas.translate(12, 12);
      canvas.rotate(0.3 * (1 - inn));
      canvas.scale(math.max(0.0, 0.4 + 0.6 * inn));
      canvas.translate(-12, -12);
      canvas.saveLayer(const Rect.fromLTWH(-6, -6, 36, 36), _alpha(inn));
      _routeShape(canvas, line, fill, to.route);
      canvas.restore();
      canvas.restore();
    }
  }

  static Paint _alpha(double a) => Paint()
    ..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0));

  void _routeShape(
    Canvas canvas,
    Paint line,
    Paint fill,
    CallAudioGlyphRoute r, {
    bool settle = false,
  }) {
    switch (r) {
      case CallAudioGlyphRoute.receiver:
      case CallAudioGlyphRoute.speaker:
        _speakerStatic(canvas, line, fill, r == CallAudioGlyphRoute.speaker);
      case CallAudioGlyphRoute.airpods:
        // One bud lands, then the other.
        _airpods(
          canvas,
          line,
          fill,
          settle ? 1 : _in(t, 0.34, 0.86),
          settle ? 1 : _in(t, 0.48, 1),
        );
      case CallAudioGlyphRoute.headphones:
        _headphones(canvas, line, fill, settle ? 0 : _push(glyphSpan(t, 0.5, 1)));
    }
  }

  static Path _cone() => Path()
    ..moveTo(2.8, 9.1)
    ..lineTo(6.4, 9.1)
    ..lineTo(10.8, 5.1)
    ..lineTo(10.8, 18.9)
    ..lineTo(6.4, 14.9)
    ..lineTo(2.8, 14.9)
    ..close();

  void _wave(Canvas canvas, Paint line, int i, double grow, double ripple) {
    if (grow <= 0.001) return;
    final r = 4.0 + i * 3.0 + 1.0 * ripple;
    final half = math.pi * 0.28 * grow.clamp(0.0, 1.15);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(10.8, 12), radius: r),
      -half,
      half * 2,
      false,
      line,
    );
  }

  void _speakerStatic(Canvas canvas, Paint line, Paint fill, bool loud) {
    _solid(canvas, _cone(), line, fill);
    for (var i = 0; i < 3; i++) {
      _wave(canvas, line, i, i == 0 || loud ? 1 : 0, 0);
    }
  }

  void _speaker(Canvas canvas, Paint line, Paint fill) {
    _solid(canvas, _cone(), line, fill);
    final toLoud = to.route == CallAudioGlyphRoute.speaker;
    final changed = from.route != to.route;
    for (var i = 0; i < 3; i++) {
      double grow;
      double ripple = 0;
      if (i == 0) {
        grow = 1;
        if (changed && toLoud) ripple = _push(glyphSpan(t, 0.0, 0.6));
      } else if (!changed) {
        grow = toLoud ? 1 : 0;
      } else if (toLoud) {
        // Out of the cone one after the other, each with a ripple.
        final a = 0.12 + (i - 1) * 0.22;
        grow = _in(t, a, a + 0.5);
        ripple = _push(glyphSpan(t, a + 0.2, a + 0.8));
      } else {
        // Folded back in, the outermost first.
        final a = (2 - i) * 0.2;
        grow = _out(t, a, a + 0.45);
      }
      _wave(canvas, line, i, grow, ripple);
    }
  }

  /// SF's `airpods`: two buds, head and stem, the stems on the inside.
  /// [left] and [right] scale each bud in from its head.
  void _airpods(
    Canvas canvas,
    Paint line,
    Paint fill,
    double left,
    double right,
  ) {
    void bud(double s, bool isLeft) {
      if (s <= 0.01) return;
      final head = Offset(isLeft ? 7.4 : 16.6, 8.0);
      canvas.save();
      canvas.translate(head.dx, head.dy);
      canvas.scale(math.max(0.0, s));
      canvas.translate(-head.dx, -head.dy);
      canvas.drawCircle(head, 4.0, fill);
      final stem = isLeft
          ? RRect.fromLTRBR(7.9, 8.4, 10.9, 20.6, const Radius.circular(1.5))
          : RRect.fromLTRBR(13.1, 8.4, 16.1, 20.6, const Radius.circular(1.5));
      canvas.drawRRect(stem, fill);
      // The speaker grille, cut out of the head.
      canvas.drawCircle(
        head + Offset(isLeft ? -1.3 : 1.3, -0.6),
        1.0,
        _clearFill(),
      );
      canvas.restore();
    }

    bud(left, true);
    bud(right, false);
  }

  /// SF's `headphones`, filled cups. [squeeze] pulls the cups in once.
  void _headphones(Canvas canvas, Paint line, Paint fill, double squeeze) {
    final q = 0.9 * squeeze;
    canvas.drawPath(
      Path()
        ..moveTo(4.4 + q, 15.4)
        ..lineTo(4.4 + q, 12.4)
        ..arcToPoint(
          Offset(19.6 - q, 12.4),
          radius: Radius.circular(7.6 - q),
        )
        ..lineTo(19.6 - q, 15.4),
      line,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(2.4 + q, 13.2, 8.0 + q, 21.2, const Radius.circular(2.4)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
          16.0 - q, 13.2, 21.6 - q, 21.2, const Radius.circular(2.4)),
      fill,
    );
  }

  // ── Share ────────────────────────────────────────────────────────────────

  void _share(Canvas canvas, Paint line, Paint fill) {
    canvas.drawRRect(
      RRect.fromLTRBR(2.2, 3.6, 21.8, 16.8, const Radius.circular(2.8)),
      fill,
    );
    canvas.drawLine(const Offset(12, 16.8), const Offset(12, 20.6), line);
    canvas.drawLine(const Offset(8.4, 20.6), const Offset(15.6, 20.6), line);

    double arrow;
    double rise;
    double square;
    if (from.on == to.on) {
      arrow = to.on ? 0 : 1;
      square = to.on ? 1 : 0;
      rise = 0;
    } else if (to.on) {
      // The arrow launches up and out of the screen, then the square pops
      // into the cut.
      final launch = Curves.easeInCubic.transform(glyphSpan(t, 0, 0.45));
      arrow = 1 - launch;
      rise = -5 * launch;
      square = _in(t, 0.4, 1);
    } else {
      square = _out(t, 0, 0.4);
      final back = _in(t, 0.35, 1);
      arrow = back.clamp(0.0, 1.0);
      rise = 4 * (1 - back);
    }
    final cut = _clearLine(line.strokeWidth * 1.05);
    if (arrow > 0.01) {
      canvas.save();
      canvas.clipRRect(
        RRect.fromLTRBR(2.2, 3.6, 21.8, 16.8, const Radius.circular(2.8)),
      );
      canvas.translate(12, 10.2 + rise);
      canvas.scale(0.6 + 0.4 * arrow);
      canvas.drawLine(const Offset(0, 3.4), const Offset(0, -3.0), cut);
      canvas.drawPath(
        Path()
          ..moveTo(-2.9, -0.4)
          ..lineTo(0, -3.3)
          ..lineTo(2.9, -0.4),
        cut,
      );
      canvas.restore();
    }
    if (square > 0.01) {
      canvas.save();
      canvas.translate(12, 10.2);
      canvas.scale(square);
      canvas.drawRRect(
        RRect.fromLTRBR(-2.8, -2.8, 2.8, 2.8, const Radius.circular(1.2)),
        _clearFill(),
      );
      canvas.restore();
    }
  }

  // ── Flip ─────────────────────────────────────────────────────────────────

  void _flip(Canvas canvas, Paint line, Paint fill) {
    // `arrow.triangle.2.circlepath.camera.fill`: the solid camera with the
    // arrows cut out of it; they turn half a lap on a tap, landing on the
    // same picture.
    const l = 2.4, r = 21.6, tp = 7.2, b = 20.0, k = 3.0;
    canvas.drawPath(
      Path()
        ..moveTo(l + k, tp)
        ..lineTo(8.0, tp)
        ..lineTo(9.3, 4.6)
        ..lineTo(14.7, 4.6)
        ..lineTo(16.0, tp)
        ..lineTo(r - k, tp)
        ..arcToPoint(const Offset(r, tp + k), radius: const Radius.circular(k))
        ..lineTo(r, b - k)
        ..arcToPoint(const Offset(r - k, b), radius: const Radius.circular(k))
        ..lineTo(l + k, b)
        ..arcToPoint(const Offset(l, b - k), radius: const Radius.circular(k))
        ..lineTo(l, tp + k)
        ..arcToPoint(const Offset(l + k, tp), radius: const Radius.circular(k))
        ..close(),
      fill,
    );
    final k0 = kick.value;
    final spin = k0 <= 0 || k0 >= 1 ? 0.0 : Curves.easeOutBack.transform(k0);
    const radius = 3.9;
    final cut = _clearLine(line.strokeWidth * 0.8);
    canvas.save();
    canvas.translate(12, 13.4);
    canvas.rotate(math.pi * spin);
    for (var i = 0; i < 2; i++) {
      final start = -math.pi * 0.95 + i * math.pi;
      const sweep = math.pi * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        start,
        sweep,
        false,
        cut,
      );
      final end = start + sweep;
      final at = Offset(math.cos(end), math.sin(end)) * radius;
      final along = Offset(-math.sin(end), math.cos(end));
      final out = Offset(math.cos(end), math.sin(end));
      const h = 2.4;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx + along.dx * h, at.dy + along.dy * h)
          ..lineTo(at.dx + out.dx * h * 0.85, at.dy + out.dy * h * 0.85)
          ..lineTo(at.dx - out.dx * h * 0.85, at.dy - out.dy * h * 0.85)
          ..close(),
        _clearFill(),
      );
    }
    canvas.restore();
  }

  // ── More, Hide ───────────────────────────────────────────────────────────

  void _more(Canvas canvas, Paint fill) {
    final k = kick.value;
    for (var i = 0; i < 3; i++) {
      final hop = _push(glyphSpan(k, i * 0.16, i * 0.16 + 0.6));
      canvas.drawCircle(Offset(5.2 + i * 6.8, 12 - 2.8 * hop), 2.2, fill);
    }
  }

  void _hide(Canvas canvas, Paint line) {
    final p = _push(kick.value);
    final dip = 2.4 * p;
    final heavy = Paint()
      ..color = line.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(5.2, 9 + dip)
        ..lineTo(12, 15.6 + dip - 1.0 * p)
        ..lineTo(18.8, 9 + dip),
      heavy,
    );
  }

  @override
  bool shouldRepaint(_CallGlyphPainter old) =>
      old.from != from ||
      old.to != to ||
      old.ink0 != ink0 ||
      old.ink1 != ink1;
}
