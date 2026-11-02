import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// The archive box on the Archived chats screen: a lid that swings up, and
/// three faces that hop out of it one after another.
///
/// It is a picture of the screen's state, not decoration. [open] is true while
/// there is something in the list to look at, so the lid lifts and the faces
/// rise; when a search or filter leaves nothing, the lid drops and the faces
/// sink back, and the box reads as shut. [unread] marks the front face as
/// something waiting (the app's badge red) and, for as long as it holds,
/// breathes a ring round it. That is the one idle loop: it runs only for a live
/// state, never for a box that has nothing to say.
///
/// Calm motion ([MotionScope]) skips all of it and draws the settled frame.
class ArchiveHero extends StatefulWidget {
  const ArchiveHero({
    super.key,
    required this.open,
    required this.unread,
    this.size = 92,
  });

  final bool open;
  final bool unread;
  final double size;

  @override
  State<ArchiveHero> createState() => _ArchiveHeroState();
}

class _ArchiveHeroState extends State<ArchiveHero>
    with TickerProviderStateMixin {
  // 0 shut, 1 fully open. One value drives the lid and every face, so they
  // can never disagree about whether the box is open.
  late final AnimationController _lid = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  bool _calm = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MotionScope.of(context).calm;
    final first = !_started;
    _started = true;
    if (first || calm != _calm) {
      _calm = calm;
      _sync(initial: first);
    }
  }

  @override
  void didUpdateWidget(ArchiveHero old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open || old.unread != widget.unread) {
      _sync(initial: false);
    }
  }

  void _sync({required bool initial}) {
    if (_calm) {
      _lid.value = widget.open ? 1 : 0;
      _pulse
        ..stop()
        ..value = 0;
      return;
    }
    if (widget.open) {
      // A beat after the route lands, so the lift is seen rather than
      // spent behind the page transition.
      if (initial) {
        Future<void>.delayed(const Duration(milliseconds: 220), () {
          if (mounted && widget.open && !_calm) _lid.forward();
        });
      } else {
        _lid.forward();
      }
    } else {
      _lid.reverse();
    }
    if (widget.unread && widget.open) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _lid.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ArchiveBoxPainter(
            lid: _lid,
            pulse: _pulse,
            unread: widget.unread,
            theme: theme,
          ),
        ),
      ),
    );
  }
}

class _ArchiveBoxPainter extends CustomPainter {
  _ArchiveBoxPainter({
    required this.lid,
    required this.pulse,
    required this.unread,
    required this.theme,
  }) : super(repaint: Listenable.merge([lid, pulse]));

  final Animation<double> lid;
  final Animation<double> pulse;
  final bool unread;
  final AppTheme theme;

  // Drawn on a 100 x 100 canvas and scaled, so every number below reads in
  // the same units whatever size the hero is given.
  static const double _unit = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / _unit;
    canvas.save();
    canvas.scale(s);

    final open = lid.value;
    final angle = Curves.easeOutBack.transform(open.clamp(0.0, 1.0)) *
        (24 * math.pi / 180);

    const bodyTop = 46.0;
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, bodyTop, 76, 44),
      const Radius.circular(11),
    );

    // Lid behind the faces while it is up, in front of everything once it is
    // down: a lid propped open is the back flap of the box, a shut one is its
    // top.
    final lidBehind = angle > 0.07;
    if (lidBehind) _paintLid(canvas, angle, bodyTop);

    _paintFaces(canvas, open, bodyTop);

    // The front of the box. Painted after the faces, so they rise out from
    // behind it.
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(theme.inkMuted, theme.surface, 0.18)!,
          Color.lerp(theme.inkMuted, theme.ink, 0.12)!,
        ],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, bodyPaint);
    // The handle slot.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 58, 24, 6),
        const Radius.circular(3),
      ),
      Paint()..color = theme.background.withValues(alpha: 0.5),
    );

    if (!lidBehind) _paintLid(canvas, angle, bodyTop);

    canvas.restore();
  }

  void _paintLid(Canvas canvas, double angle, double bodyTop) {
    canvas.save();
    // Hinged on the back-left edge, so it swings up and away like a chest.
    canvas.translate(8, bodyTop - 2);
    canvas.rotate(-angle);
    final lidRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, -14, 78, 14),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      lidRect,
      Paint()..color = Color.lerp(theme.inkMuted, theme.ink, 0.28)!,
    );
    canvas.restore();
  }

  void _paintFaces(Canvas canvas, double open, double bodyTop) {
    // Back to front, each one a beat later than the one before it.
    final colors = <Color>[
      theme.accent.withValues(alpha: 0.55),
      theme.accent,
      unread ? theme.badge : theme.inkMuted,
    ];
    const xs = [30.0, 50.0, 70.0];
    // Peeking out of the box, not floating above it.
    const rise = [9.0, 15.0, 11.0];
    for (var i = 0; i < 3; i++) {
      final start = 0.18 + i * 0.16;
      final t = Interval(start, math.min(1.0, start + 0.55))
          .transform(open.clamp(0.0, 1.0));
      final y = bodyTop + 4 - Curves.easeOutBack.transform(t) * rise[i];
      final c = Offset(xs[i], y);
      const r = 10.0;
      if (unread && i == 2 && t > 0.95) {
        // The ring leaves the face and fades as it goes.
        final p = pulse.value;
        canvas.drawCircle(
          c,
          r + 2 + p * 9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = theme.badge.withValues(alpha: (1 - p) * 0.55),
        );
      }
      canvas.drawCircle(c, r, Paint()..color = colors[i]);
      // A little shine so the faces read as faces and not dots.
      canvas.drawCircle(
        c.translate(-3, -3.5),
        2.6,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_ArchiveBoxPainter old) =>
      old.unread != unread || old.theme != theme;
}
