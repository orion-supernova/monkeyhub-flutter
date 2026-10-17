import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'capture_glyphs.dart' show TrashGlyph, captureGlyphStroke;

// Drawn line glyphs for scheduling a message: the scheduler sheet's quick
// choices, its running sentence, and the queued list.
//
// The capture glyphs' grammar (see capture_glyphs.dart): a 24-unit grid with
// ~2 units of air, the shared stroke weight, and every animation is geometry,
// never a tint. Unlike those, these own their motion: each is told the state
// it shows and plays the one-off kick itself when that state changes, since a
// sheet row has nothing else to drive it. No idle loops: a sheet is resting
// chrome. Reduce Motion snaps.

/// A 0..1 window of [t]: 0 before [from], 1 after [to], linear between.
double _span(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// One forward-and-back of a one-off kick: 0 at rest, 1 at the peak.
double _bump(double t) =>
    t <= 0 || t >= 1 ? 0 : math.sin(math.pi * Curves.easeOut.transform(t));

/// Scales the canvas to the 24-unit grid, centered in a non-square box, and
/// hands [draw] a line and a fill paint in [color].
void _onGrid(
  Canvas canvas,
  Size size,
  Color color,
  void Function(Paint line, Paint fill) draw,
) {
  final side = size.shortestSide;
  if (side <= 0) return;
  final s = side / 24;
  canvas.save();
  canvas.translate((size.width - side) / 2, (size.height - side) / 2);
  canvas.scale(s);
  final line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = captureGlyphStroke(side) / s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  draw(line, Paint()..color = color);
  canvas.restore();
}

/// The painter and its own repaint boundary, so a kick repaints only the
/// glyph.
Widget _paint(double size, CustomPainter painter) => RepaintBoundary(
      child: CustomPaint(size: Size.square(size), painter: painter),
    );

/// The one-off kick every glyph here plays: a controller that runs once from
/// zero when [fire] is called, and never under Reduce Motion.
mixin _Kick<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  Duration get kickDuration => const Duration(milliseconds: 620);

  late final AnimationController kick = AnimationController(
    vsync: this,
    duration: kickDuration,
  );

  bool get calm => MediaQuery.disableAnimationsOf(context);

  void fire() {
    if (calm) return;
    kick.forward(from: 0);
  }

  @override
  void dispose() {
    kick.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Clock

/// A clock face showing [time]: when it changes, the hands SWEEP there, the
/// minute hand travelling the real distance (wrapped, plus one full turn for
/// anything a day or more away) instead of jumping. [alert] folds the hands
/// into a "!" (the hour hand straightens into the bar, the minute hand
/// shrinks into the dot under it), for a send that failed. [kickKey]
/// changing spins the minute hand once around and back to the same time: a
/// tap on something that does not move the time.
class ScheduleClockGlyph extends StatefulWidget {
  const ScheduleClockGlyph({
    super.key,
    required this.time,
    required this.color,
    this.alert = false,
    this.kickKey,
    this.size = 20,
  });

  final DateTime time;
  final Color color;
  final bool alert;
  final Object? kickKey;
  final double size;

  @override
  State<ScheduleClockGlyph> createState() => _ScheduleClockGlyphState();
}

class _ScheduleClockGlyphState extends State<ScheduleClockGlyph>
    with TickerProviderStateMixin, _Kick {
  /// Minutes on a 12-hour dial, unwrapped: where the sweep starts and ends.
  late double _from = _dial(widget.time);
  late double _to = _from;

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
    value: 1,
  );

  late final AnimationController _alert = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.alert ? 1 : 0,
  );

  static double _dial(DateTime t) =>
      (t.hour % 12) * 60 + t.minute + t.second / 60;

  double get _shown =>
      lerpDouble(_from, _to, Curves.easeOutBack.transform(_sweep.value))!;

  @override
  void didUpdateWidget(ScheduleClockGlyph old) {
    super.didUpdateWidget(old);
    if (old.time != widget.time) {
      final delta = widget.time.difference(old.time).inSeconds / 60;
      // The real distance, folded onto the dial, so a minute later is a
      // nudge and eight hours later is two thirds of a turn of the hour
      // hand; a day or a week later still visibly goes around once.
      var travel = delta.abs() % 720;
      if (delta.abs() >= 720) travel += 720;
      if (delta < 0) travel = -travel;
      final start = _shown;
      if (calm) {
        _from = _to = start + travel;
        _sweep.value = 1;
      } else {
        _from = start;
        _to = start + travel;
        _sweep.forward(from: 0);
      }
    }
    if (old.alert != widget.alert) {
      if (calm) {
        _alert.value = widget.alert ? 1 : 0;
      } else {
        _alert.animateTo(widget.alert ? 1 : 0, curve: Curves.easeOutBack);
      }
    }
    if (old.kickKey != widget.kickKey) fire();
  }

  @override
  void dispose() {
    _sweep.dispose();
    _alert.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _paint(
        widget.size,
        _ClockPainter(
          color: widget.color,
          minutes: () => _shown + 60 * Curves.easeInOutCubic.transform(kick.value),
          alert: _alert,
          repaint: Listenable.merge([_sweep, _alert, kick]),
        ),
      );
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({
    required this.color,
    required this.minutes,
    required this.alert,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Color color;
  final double Function() minutes;
  final Animation<double> alert;

  @override
  void paint(Canvas canvas, Size size) => _onGrid(canvas, size, color, (
        line,
        fill,
      ) {
        const c = Offset(12, 12);
        canvas.drawCircle(c, 9, line);
        final m = minutes();
        final a = alert.value;
        Offset tip(double turns, double length) => c +
            Offset(
              math.sin(2 * math.pi * turns) * length,
              -math.cos(2 * math.pi * turns) * length,
            );
        // The hour hand: from the hub out, folding into the "!" bar.
        final hourTip = tip(m / 720, 4.6);
        canvas.drawLine(
          Offset.lerp(c, const Offset(12, 13.2), a)!,
          Offset.lerp(hourTip, const Offset(12, 6.6), a)!,
          line,
        );
        // The minute hand: shrinks into the dot. A zero-length round-capped
        // line is a dot of the stroke's width.
        final minuteTip = tip(m / 60, 6.6);
        canvas.drawLine(
          Offset.lerp(c, const Offset(12, 17), a)!,
          Offset.lerp(minuteTip, const Offset(12, 17), a)!,
          line,
        );
      });

  @override
  bool shouldRepaint(_ClockPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Moon, sun, calendar: the quick choices

/// Which quick choice a [SchedulePresetGlyph] draws.
enum SchedulePresetMark {
  /// A clock: in an hour. Picked, the minute hand goes once around.
  clock,

  /// A crescent with a star: tonight, in eight hours. Picked, the crescent
  /// rocks and the star twinkles back in.
  moon,

  /// The sun on the horizon: tomorrow morning. Picked, it dips and rises
  /// again, its rays drawing back out.
  sunrise,

  /// A calendar page: in a week. Picked, the page flips over.
  calendar,

  /// A calendar with a plus: pick a date. Tapped, the plus turns.
  calendarPlus,
}

/// A quick choice's mark, kicked once each time [picked] turns on (or
/// [kickKey] changes, for a row that is tapped rather than chosen).
class SchedulePresetGlyph extends StatefulWidget {
  const SchedulePresetGlyph({
    super.key,
    required this.mark,
    required this.color,
    this.time,
    this.picked = false,
    this.kickKey,
    this.size = 20,
  });

  final SchedulePresetMark mark;
  final Color color;

  /// For [SchedulePresetMark.clock]: the time the hands show.
  final DateTime? time;
  final bool picked;
  final Object? kickKey;
  final double size;

  @override
  State<SchedulePresetGlyph> createState() => _SchedulePresetGlyphState();
}

class _SchedulePresetGlyphState extends State<SchedulePresetGlyph>
    with TickerProviderStateMixin, _Kick {
  @override
  Duration get kickDuration => const Duration(milliseconds: 720);

  /// How many kicks so far: what the clock's own spin is keyed on.
  int _kicks = 0;

  @override
  void didUpdateWidget(SchedulePresetGlyph old) {
    super.didUpdateWidget(old);
    if ((widget.picked && !old.picked) || old.kickKey != widget.kickKey) {
      _kicks++;
      fire();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mark == SchedulePresetMark.clock) {
      // The clock's spin is its own, so its sweep and its kick share hands.
      return ScheduleClockGlyph(
        time: widget.time ?? DateTime.now(),
        color: widget.color,
        size: widget.size,
        kickKey: _kicks,
      );
    }
    return _paint(
      widget.size,
      _PresetPainter(mark: widget.mark, color: widget.color, kick: kick),
    );
  }
}

class _PresetPainter extends CustomPainter {
  _PresetPainter({required this.mark, required this.color, required this.kick})
      : super(repaint: kick);

  final SchedulePresetMark mark;
  final Color color;
  final Animation<double> kick;

  @override
  void paint(Canvas canvas, Size size) => _onGrid(canvas, size, color, (
        line,
        fill,
      ) {
        final k = kick.value;
        switch (mark) {
          case SchedulePresetMark.moon:
            _moon(canvas, line, k);
          case SchedulePresetMark.sunrise:
            _sunrise(canvas, line, k);
          case SchedulePresetMark.calendar:
            _calendar(canvas, line, fill, k, plus: false);
          case SchedulePresetMark.calendarPlus:
            _calendar(canvas, line, fill, k, plus: true);
          case SchedulePresetMark.clock:
            break;
        }
      });

  void _moon(Canvas canvas, Paint line, double k) {
    // The crescent rocks back about its middle and settles, the way a
    // hanging thing does when it is touched.
    final rock = k == 0
        ? 0.0
        : -0.42 * math.sin(2.4 * math.pi * k) * math.pow(1 - k, 1.4);
    canvas.save();
    canvas.translate(11, 13);
    canvas.rotate(rock);
    canvas.translate(-11, -13);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: const Offset(11, 13), radius: 7.6)),
      Path()..addOval(Rect.fromCircle(center: const Offset(15.4, 9.6), radius: 6.4)),
    );
    canvas.drawPath(crescent, line);
    canvas.restore();
    // The star goes out and twinkles back in, a beat after the rock.
    final t = _span(k, 0.25, 1);
    final star = k == 0
        ? 1.0
        : t == 0
            ? 1 - _span(k, 0, 0.12)
            : Curves.elasticOut.transform(t);
    if (star <= 0.01) return;
    // A four-point sparkle, its sides bowed in to the middle: a plus at this
    // size reads as "add".
    const c = Offset(18.4, 5.6);
    final arm = 3.2 * star;
    final sparkle = Path()..moveTo(c.dx, c.dy - arm);
    for (final (dx, dy) in const [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)]) {
      sparkle.quadraticBezierTo(c.dx, c.dy, c.dx + dx * arm, c.dy + dy * arm);
    }
    canvas.drawPath(sparkle, line);
  }

  void _sunrise(Canvas canvas, Paint line, double k) {
    // Sets a little, then rises past where it was and settles.
    final dip = k == 0
        ? 0.0
        : k < 0.3
            ? 3.4 * Curves.easeIn.transform(k / 0.3)
            : 3.4 * (1 - Curves.easeOutBack.transform(_span(k, 0.3, 1)));
    const horizon = 17.0;
    final sun = Offset(12, horizon + dip);
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 24, horizon));
    canvas.drawArc(
      Rect.fromCircle(center: sun, radius: 5),
      math.pi,
      math.pi,
      false,
      line,
    );
    canvas.restore();
    // The rays draw back out from the sun once it is up again.
    final rays = k == 0 ? 1.0 : 1 - _bump(_span(k, 0, 0.9));
    for (final a in const [-0.5, -0.25, 0.0, 0.25, 0.5]) {
      final dir = Offset(math.sin(math.pi * a), -math.cos(math.pi * a));
      final from = sun + dir * 7.4;
      final to = sun + dir * (7.4 + 2.4 * rays);
      if (rays < 0.05 || to.dy > horizon - 0.6) continue;
      canvas.drawLine(from, to, line);
    }
    canvas.drawLine(const Offset(3, horizon), const Offset(21, horizon), line);
  }

  void _calendar(
    Canvas canvas,
    Paint line,
    Paint fill,
    double k, {
    required bool plus,
  }) {
    // The body and its rings.
    canvas.drawRRect(
      RRect.fromLTRBR(4, 5.6, 20, 20.4, const Radius.circular(3)),
      line,
    );
    canvas.drawLine(const Offset(8.4, 3.4), const Offset(8.4, 7), line);
    canvas.drawLine(const Offset(15.6, 3.4), const Offset(15.6, 7), line);
    canvas.drawLine(const Offset(4, 10), const Offset(20, 10), line);
    if (plus) {
      // The plus turns a quarter and pops, a tap that opens the calendar.
      canvas.save();
      canvas.translate(12, 15.2);
      canvas.rotate(math.pi / 2 * Curves.easeOutBack.transform(k));
      canvas.scale(1 + 0.25 * _bump(k));
      canvas.drawLine(const Offset(-2.8, 0), const Offset(2.8, 0), line);
      canvas.drawLine(const Offset(0, -2.8), const Offset(0, 2.8), line);
      canvas.restore();
      return;
    }
    // The page flips about the header line: it folds up edge-on, and the
    // next one comes down. The days are dots.
    final flip = k == 0 ? 1.0 : math.cos(math.pi * Curves.easeInOut.transform(k)).abs();
    canvas.save();
    canvas.translate(0, 10);
    canvas.scale(1, math.max(0.06, flip));
    canvas.translate(0, -10);
    final dot = line.strokeWidth * 0.62;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawCircle(Offset(8 + col * 4.0, 13.6 + row * 3.6), dot, fill);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PresetPainter old) =>
      old.mark != mark || old.color != color;
}

// ---------------------------------------------------------------------------
// Tray and sliders: the rows that open somewhere

/// A tray with a page standing in it: the queue of waiting messages.
class ScheduleTrayGlyph extends StatelessWidget {
  const ScheduleTrayGlyph({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _paint(size, _TrayPainter(color));
}

class _TrayPainter extends CustomPainter {
  _TrayPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => _onGrid(canvas, size, color, (
        line,
        fill,
      ) {
        // A page waiting in the tray, its top edge and two lines of text.
        canvas.drawPath(
          Path()
            ..moveTo(7, 12.2)
            ..lineTo(7, 5.6)
            ..arcToPoint(const Offset(8.6, 4), radius: const Radius.circular(1.6))
            ..lineTo(15.4, 4)
            ..arcToPoint(const Offset(17, 5.6), radius: const Radius.circular(1.6))
            ..lineTo(17, 12.2),
          line,
        );
        canvas.drawLine(const Offset(10, 7.6), const Offset(14, 7.6), line);
        // The tray: a dip in the middle where the page sits.
        canvas.drawPath(
          Path()
            ..moveTo(3.6, 13)
            ..lineTo(8.2, 13)
            ..lineTo(9.6, 15.6)
            ..lineTo(14.4, 15.6)
            ..lineTo(15.8, 13)
            ..lineTo(20.4, 13)
            ..lineTo(20.4, 18.4)
            ..arcToPoint(const Offset(18.4, 20.4), radius: const Radius.circular(2))
            ..lineTo(5.6, 20.4)
            ..arcToPoint(const Offset(3.6, 18.4), radius: const Radius.circular(2))
            ..close(),
          line,
        );
      });

  @override
  bool shouldRepaint(_TrayPainter old) => old.color != color;
}

/// Three sliders, their knobs at different stops: how these show up.
class ScheduleSlidersGlyph extends StatelessWidget {
  const ScheduleSlidersGlyph({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _paint(size, _SlidersPainter(color));
}

class _SlidersPainter extends CustomPainter {
  _SlidersPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => _onGrid(canvas, size, color, (
        line,
        fill,
      ) {
        const stops = [8.0, 15.0, 11.0];
        for (var i = 0; i < 3; i++) {
          final y = 6.0 + i * 6;
          final x = stops[i];
          // The track breaks around the knob, so the knob reads as a ring.
          canvas.drawLine(Offset(3.6, y), Offset(x - 2.6, y), line);
          canvas.drawLine(Offset(x + 2.6, y), Offset(20.4, y), line);
          canvas.drawCircle(Offset(x, y), 2.1, line);
        }
      });

  @override
  bool shouldRepaint(_SlidersPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// The check

/// The pick-one check that DRAWS itself onto the chosen row (the short arm,
/// then the long one, with a small overshoot) and undraws from its tip when
/// the choice moves on, so the check visibly travels between rows.
class ScheduleCheckGlyph extends StatefulWidget {
  const ScheduleCheckGlyph({
    super.key,
    required this.on,
    required this.color,
    this.size = 20,
  });

  final bool on;
  final Color color;
  final double size;

  @override
  State<ScheduleCheckGlyph> createState() => _ScheduleCheckGlyphState();
}

class _ScheduleCheckGlyphState extends State<ScheduleCheckGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 180),
    value: widget.on ? 1 : 0,
  );

  @override
  void didUpdateWidget(ScheduleCheckGlyph old) {
    super.didUpdateWidget(old);
    if (old.on == widget.on) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw.value = widget.on ? 1 : 0;
    } else if (widget.on) {
      _draw.forward();
    } else {
      _draw.reverse();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _paint(widget.size, _CheckPainter(widget.color, _draw));
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color, this.draw) : super(repaint: draw);
  final Color color;
  final Animation<double> draw;

  @override
  void paint(Canvas canvas, Size size) {
    final t = draw.value;
    if (t <= 0) return;
    _onGrid(canvas, size, color, (line, fill) {
      // A touch heavier than the outline glyphs: it is the row's answer.
      line.strokeWidth *= 1.15;
      final path = Path()
        ..moveTo(5, 12.6)
        ..lineTo(9.8, 17.4)
        ..lineTo(19.4, 7);
      final metric = path.computeMetrics().first;
      final drawn = metric.extractPath(
        0,
        metric.length * Curves.easeOutCubic.transform(t),
      );
      // The overshoot: the finished check swells and settles.
      final pop = draw.status == AnimationStatus.forward
          ? 0.16 * _bump(_span(t, 0.55, 1))
          : 0.0;
      canvas.save();
      canvas.translate(12, 12);
      canvas.scale(1 + pop);
      canvas.translate(-12, -12);
      canvas.drawPath(drawn, line);
      canvas.restore();
    });
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Row actions

/// What a queued row's action button draws.
enum ScheduleActionMark {
  /// Send it now: the arrow launches out of the top and a fresh one rises
  /// back into place from below.
  sendNow,

  /// Try a failed send again: the circling arrow goes once around.
  retry,

  /// Rewrite the words: the pen scribbles a quick line and lifts back.
  edit,

  /// Take it out of the queue: the lid flips open and slams shut.
  delete,
}

/// A row action's glyph. [kickKey] changing plays the mark's one-off kick;
/// the glyph is still otherwise. Change time has no mark here: it is the
/// [ScheduleClockGlyph], spun with its own kickKey.
class ScheduleActionGlyph extends StatefulWidget {
  const ScheduleActionGlyph({
    super.key,
    required this.mark,
    required this.color,
    this.kickKey,
    this.size = 20,
  });

  final ScheduleActionMark mark;
  final Color color;
  final Object? kickKey;
  final double size;

  @override
  State<ScheduleActionGlyph> createState() => _ScheduleActionGlyphState();
}

class _ScheduleActionGlyphState extends State<ScheduleActionGlyph>
    with TickerProviderStateMixin, _Kick {
  @override
  Duration get kickDuration => switch (widget.mark) {
        ScheduleActionMark.sendNow => const Duration(milliseconds: 560),
        ScheduleActionMark.retry => const Duration(milliseconds: 620),
        ScheduleActionMark.edit => const Duration(milliseconds: 600),
        ScheduleActionMark.delete => const Duration(milliseconds: 700),
      };

  @override
  void didUpdateWidget(ScheduleActionGlyph old) {
    super.didUpdateWidget(old);
    if (old.kickKey != widget.kickKey) fire();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mark == ScheduleActionMark.delete) {
      // The capture trash, driven here: open over the first stretch, then
      // the gulp slams it shut and wobbles the can.
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: kick,
          builder: (context, _) {
            final k = kick.value;
            final rest = k <= 0 || k >= 1;
            return TrashGlyph(
              color: widget.color,
              size: widget.size,
              open: rest ? 0 : Curves.easeOut.transform(_span(k, 0, 0.38)),
              gulp: rest ? 0 : _span(k, 0.38, 1),
            );
          },
        ),
      );
    }
    return _paint(
      widget.size,
      _ActionPainter(widget.mark, widget.color, kick),
    );
  }
}

class _ActionPainter extends CustomPainter {
  _ActionPainter(this.mark, this.color, this.kick) : super(repaint: kick);

  final ScheduleActionMark mark;
  final Color color;
  final Animation<double> kick;

  @override
  void paint(Canvas canvas, Size size) {
    final k = kick.value;
    final t = k >= 1 ? 0.0 : k;
    _onGrid(canvas, size, color, (line, fill) {
      switch (mark) {
        case ScheduleActionMark.sendNow:
          _sendNow(canvas, line, t);
        case ScheduleActionMark.retry:
          _retry(canvas, line, t);
        case ScheduleActionMark.edit:
          _edit(canvas, line, t);
        case ScheduleActionMark.delete:
          break;
      }
    });
  }

  /// An upright arrow. The kick throws it out of the top (accelerating,
  /// stretching a little) and a fresh one rises in from below and settles
  /// with an overshoot, so the button reads as "gone, and ready again".
  void _sendNow(Canvas canvas, Paint line, double t) {
    void arrow(double dy, double stretch, double alpha) {
      if (alpha <= 0) return;
      final p = Paint()
        ..color = line.color.withValues(alpha: line.color.a * alpha)
        ..style = line.style
        ..strokeWidth = line.strokeWidth
        ..strokeCap = line.strokeCap
        ..strokeJoin = line.strokeJoin;
      canvas.drawLine(Offset(12, 19.5 + dy), Offset(12, 5 + dy - stretch), p);
      canvas.drawPath(
        Path()
          ..moveTo(6.4, 10.6 + dy - stretch)
          ..lineTo(12, 5 + dy - stretch)
          ..lineTo(17.6, 10.6 + dy - stretch),
        p,
      );
    }

    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(-2, -1, 28, 25.5));
    if (t == 0) {
      arrow(0, 0, 1);
    } else {
      final out = Curves.easeIn.transform(_span(t, 0, 0.42));
      arrow(-22 * out, 2.2 * _bump(_span(t, 0, 0.42)), 1 - out);
      final back = _span(t, 0.36, 1);
      if (back > 0) {
        arrow(18 * (1 - Curves.easeOutBack.transform(back)), 0, 1);
      }
    }
    canvas.restore();
  }

  /// A circling arrow, open at the top right. The kick spins it once around,
  /// overshooting a touch and settling back.
  void _retry(Canvas canvas, Paint line, double t) {
    final turn = t == 0 ? 0.0 : Curves.easeOutBack.transform(t);
    canvas.save();
    canvas.translate(12, 12);
    canvas.rotate(2 * math.pi * turn);
    canvas.translate(-12, -12);
    const r = 7.2;
    const start = -math.pi / 2 + 0.55;
    const sweep = 2 * math.pi - 1.1;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(12, 12), radius: r),
      start,
      sweep,
      false,
      line,
    );
    // The head at the arc's end, pointing along it (clockwise).
    const end = start + sweep;
    final tip = Offset(12 + r * math.cos(end), 12 + r * math.sin(end));
    final along = Offset(-math.sin(end), math.cos(end));
    final out = Offset(math.cos(end), math.sin(end));
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - along.dx * 3.6 + out.dx * 3.2,
            tip.dy - along.dy * 3.6 + out.dy * 3.2)
        ..lineTo(tip.dx + along.dx * 0.6, tip.dy + along.dy * 0.6)
        ..lineTo(tip.dx - along.dx * 3.6 - out.dx * 3.2,
            tip.dy - along.dy * 3.6 - out.dy * 3.2),
      line,
    );
    canvas.restore();
  }

  /// A pen at a slant over a short ruled line. The kick dips the nib and
  /// scribbles a quick wave across the line, then lifts back to rest while
  /// the scribble fades.
  void _edit(Canvas canvas, Paint line, double t) {
    final run = Curves.easeInOut.transform(_span(t, 0.08, 0.72));
    final back = Curves.easeOutBack.transform(_span(t, 0.62, 1));
    final travel = t == 0 ? 0.0 : 9 * run * (1 - back);
    final dip = t == 0 ? 0.0 : 1.4 * _bump(_span(t, 0, 0.2));
    final wiggle =
        t == 0 ? 0.0 : 1.1 * math.sin(run * 6 * math.pi) * (1 - back);
    final tip = Offset(5.2 + travel, 18.2 + dip + wiggle);

    // The scribble: a sine run from the start to wherever the nib is,
    // fading once the pen lifts.
    final fade = 1 - _span(t, 0.7, 1);
    if (t > 0 && travel > 0.2 && fade > 0) {
      final p = Paint()
        ..color = line.color.withValues(alpha: line.color.a * 0.75 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.strokeWidth * 0.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(5.2, 20.4);
      for (var x = 5.2; x <= tip.dx; x += 0.5) {
        path.lineTo(x, 20.4 + 1.1 * math.sin((x - 5.2) * 1.4));
      }
      canvas.drawPath(path, p);
    }

    // The pen, its nib at [tip], leaning 45 degrees up to the right.
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(-math.pi / 4);
    // In pen space the nib is the origin and the barrel runs along +x.
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(3.4, -1.9)
        ..lineTo(15.2, -1.9)
        ..arcToPoint(const Offset(15.2, 1.9),
            radius: const Radius.circular(1.9))
        ..lineTo(3.4, 1.9)
        ..close(),
      line,
    );
    // The collar where the nib meets the barrel.
    canvas.drawLine(const Offset(3.4, -1.9), const Offset(3.4, 1.9), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ActionPainter old) =>
      old.color != color || old.mark != mark;
}
