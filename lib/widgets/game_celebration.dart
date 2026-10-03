import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// A one-shot confetti burst for a solved board — the Telegram/Game Center
/// "you did it" beat, over in under two seconds.
///
/// Paints over whatever it is stacked on and never takes a touch. Every
/// particle is generated once, up front, from a fixed seed, so a frame does
/// nothing but evaluate closed-form motion and draw: no allocation, no list
/// rebuilt, one reused [Paint]. Under reduced motion it draws nothing at all.
class GameCelebration extends StatefulWidget {
  const GameCelebration({super.key, this.play = true, this.origin});

  /// False renders nothing — lets a caller keep the widget mounted and decide
  /// later whether the moment deserves it (a give-up does not).
  final bool play;

  /// Where the burst comes from, in the widget's own 0..1 space. Defaults to
  /// a little above centre, roughly where a result title lands.
  final Alignment? origin;

  @override
  State<GameCelebration> createState() => _GameCelebrationState();
}

class _GameCelebrationState extends State<GameCelebration>
    with SingleTickerProviderStateMixin {
  static const _count = 70;

  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  List<_Particle> _particles = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(GameCelebration old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  void _maybeStart() {
    if (_started || !widget.play) return;
    if (MotionScope.of(context).calm) return;
    _started = true;
    _particles = _burst(ThemeScope.of(context));
    HapticFeedback.mediumImpact();
    _t.forward();
  }

  /// Theme colours first, so a burst on Risograph looks like Risograph; a
  /// couple of bright fixed ones keep it festive on a monochrome palette.
  static List<_Particle> _burst(AppTheme theme) {
    final r = math.Random(7);
    final colours = <Color>[
      theme.accent,
      ...{for (var i = 0; i < 6; i++) theme.avatarGradient(i * 97).first},
      const Color(0xFFFFD60A),
      const Color(0xFFFF375F),
    ];
    return [
      for (var i = 0; i < _count; i++)
        _Particle(
          // Mostly upward, fanned ±70°, with a spread of speeds so the burst
          // reads as depth rather than a ring.
          angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.78,
          speed: 0.55 + r.nextDouble() * 0.75,
          spin: (r.nextDouble() - 0.5) * 14,
          size: 5 + r.nextDouble() * 5,
          ratio: 0.4 + r.nextDouble() * 0.5,
          colour: colours[r.nextInt(colours.length)],
          delay: r.nextDouble() * 0.12,
        ),
    ];
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(
            progress: _t,
            particles: _particles,
            origin: widget.origin ?? const Alignment(0, -0.2),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.ratio,
    required this.colour,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final double ratio;
  final Color colour;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.particles,
    required this.origin,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<_Particle> particles;
  final Alignment origin;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final o = origin.alongSize(size);
    final reach = size.shortestSide * 0.95;
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      // Launch, then gravity: a parabola in closed form, with air drag
      // easing the horizontal drift.
      final drift = 1 - math.pow(1 - local, 2.2);
      final dx = math.cos(p.angle) * p.speed * reach * drift;
      final dy = math.sin(p.angle) * p.speed * reach * drift +
          local * local * reach * 1.15;
      final fade = local > 0.7 ? 1 - (local - 0.7) / 0.3 : 1.0;
      _paint.color = p.colour.withValues(alpha: p.colour.a * fade);
      canvas.save();
      canvas.translate(o.dx + dx, o.dy + dy);
      canvas.rotate(p.spin * local);
      // Flutter between face-on and edge-on, the paper tumbling.
      final flip = math.cos(p.spin * local * 1.7).abs() * 0.8 + 0.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * p.ratio * flip,
          ),
          const Radius.circular(1.5),
        ),
        _paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.particles != particles || old.origin != origin;
}
