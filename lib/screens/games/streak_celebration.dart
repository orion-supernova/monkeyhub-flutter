import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../main.dart' show rootNavigatorKey;
import '../../widgets/capture_glyphs.dart';

/// How big a streak is, for how loud the celebration is. The tiers are the
/// design: each one adds something the one below does not have, so reaching the
/// next is something a player can SEE.
///
///  * [ember] 2 to 4: a flame lights and a few sparks float up.
///  * [blaze] 5 to 9: hotter, with a shockwave ring and more sparks.
///  * [inferno] 10 to 19: the screen glows, sparks fly in every direction and
///    confetti falls.
///  * [legend] 20 and up: white-gold flame, rotating rays and a full confetti
///    rain, held a little longer.
enum StreakTier {
  ember,
  blaze,
  inferno,
  legend;

  static StreakTier of(int days) => days >= 20
      ? legend
      : days >= 10
      ? inferno
      : days >= 5
      ? blaze
      : ember;

  String headline(AppLocalizations l10n) => switch (this) {
    ember => l10n.streakCelebrateTier1,
    blaze => l10n.streakCelebrateTier2,
    inferno => l10n.streakCelebrateTier3,
    legend => l10n.streakCelebrateTier4,
  };

  Duration get length => Duration(
    milliseconds: switch (this) {
      ember => 2800,
      blaze => 3300,
      inferno => 3900,
      legend => 4500,
    },
  );

  Color get flame => switch (this) {
    ember => const Color(0xFFFF8A3D),
    blaze => const Color(0xFFFF6A1F),
    inferno => const Color(0xFFFF3B1F),
    legend => const Color(0xFFFFD54A),
  };

  Color get core => switch (this) {
    ember => const Color(0xFFFFD27A),
    blaze => const Color(0xFFFFC83D),
    inferno => const Color(0xFFFFB020),
    legend => const Color(0xFFFFFFFF),
  };

  /// The colours sparks and confetti are drawn from.
  List<Color> get sparks => switch (this) {
    ember => const [Color(0xFFFFB45A), Color(0xFFFF8A3D), Color(0xFFFFD27A)],
    blaze => const [Color(0xFFFFC83D), Color(0xFFFF6A1F), Color(0xFFFFE7A3)],
    inferno => const [
      Color(0xFFFF3B1F),
      Color(0xFFFFB020),
      Color(0xFFFFE066),
      Color(0xFFFF7A59),
    ],
    legend => const [
      Color(0xFFFFD54A),
      Color(0xFFFFFFFF),
      Color(0xFFFFA726),
      Color(0xFF8AD8FF),
      Color(0xFFFF7AB6),
    ],
  };

  int get sparkCount => switch (this) {
    ember => 16,
    blaze => 30,
    inferno => 48,
    legend => 64,
  };

  int get confettiCount => switch (this) {
    ember || blaze => 0,
    inferno => 36,
    legend => 70,
  };

  bool get ring => index >= blaze.index;
  bool get glow => index >= inferno.index;
  bool get rays => this == legend;
}

/// The full-screen moment after a finished game extends a streak to 2 or more.
///
/// Shown over everything on the root navigator, so it does not belong to the
/// game's route: the game can already be on its way out and the flame still
/// lands. Tap anywhere to dismiss; otherwise it leaves on its own after the
/// tier's length. One at a time: a second request while one is up is dropped.
class StreakCelebration {
  StreakCelebration._();

  static OverlayEntry? _entry;

  /// Plays the celebration for a streak that just grew from [from] to [days].
  /// Quiet when [days] is under 2 or one is already showing.
  static void play({required int from, required int days}) {
    if (days < 2 || _entry != null) return;
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => StreakCelebrationView(
        from: from,
        days: days,
        onDone: () {
          if (_entry == entry) _entry = null;
          entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class StreakCelebrationView extends StatefulWidget {
  const StreakCelebrationView({
    super.key,
    required this.from,
    required this.days,
    required this.onDone,
  });

  final int from;
  final int days;
  final VoidCallback onDone;

  @override
  State<StreakCelebrationView> createState() => _StreakCelebrationViewState();
}

class _StreakCelebrationViewState extends State<StreakCelebrationView>
    with SingleTickerProviderStateMixin {
  late final StreakTier _tier = StreakTier.of(widget.days);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _tier.length,
  );
  late final List<_Grain> _sparks;
  late final List<_Grain> _confetti;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.days * 7919);
    _sparks = [
      for (var i = 0; i < _tier.sparkCount; i++)
        _Grain.spark(rnd, _tier.sparks, burst: _tier.glow),
    ];
    _confetti = [
      for (var i = 0; i < _tier.confettiCount; i++)
        _Grain.confetti(rnd, _tier.sparks),
    ];
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
    unawaited(_haptics());
  }

  Future<void> _haptics() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    switch (_tier) {
      case StreakTier.ember:
        await HapticFeedback.lightImpact();
      case StreakTier.blaze:
        await HapticFeedback.mediumImpact();
      case StreakTier.inferno:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 140));
        await HapticFeedback.lightImpact();
      case StreakTier.legend:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.lightImpact();
    }
  }

  /// A tap lets it go early: it plays out its last tenth, never snaps off.
  void _dismiss() {
    if (_leaving || !mounted) return;
    _leaving = true;
    final from = _c.value;
    if (from >= 0.9) return;
    _c.animateTo(1.0, duration: const Duration(milliseconds: 260));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _span(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final calm = MediaQuery.disableAnimationsOf(context);
    final size = MediaQuery.sizeOf(context);
    final flameSize = math.min(size.width * 0.5, 210.0);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final fadeIn = _span(t, 0, 0.08);
              final fadeOut = 1 - _span(t, 0.88, 1);
              final fade = math.min(fadeIn, fadeOut);
              final ignite = calm ? 1.0 : _span(t, 0.06, 0.3);
              final numberIn = calm ? 1.0 : _span(t, 0.24, 0.4);
              // The old number holds, then the new one punches in.
              final shown = numberIn >= 0.5 ? widget.days : widget.from;
              final pop = calm
                  ? 1.0
                  : 1 + 0.35 * math.sin(math.pi * _span(t, 0.3, 0.46));
              final textIn = calm ? 1.0 : _span(t, 0.38, 0.52);
              return Opacity(
                opacity: fade,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: const Color(0xE6070509)),
                    if (_tier.glow)
                      _Glow(color: _tier.flame, t: calm ? 0.5 : t),
                    if (!calm)
                      CustomPaint(
                        painter: _FxPainter(
                          tier: _tier,
                          t: t,
                          sparks: _sparks,
                          confetti: _confetti,
                          flameSize: flameSize,
                        ),
                      ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: flameSize * 1.15,
                            child: Transform.translate(
                              offset: Offset(0, calm ? 0 : -4 * (1 - ignite)),
                              child: FlameGlyph(
                                color: _tier.flame,
                                core: _tier.core,
                                flicker: calm ? 0 : (t * _tier.length.inMilliseconds / 900) % 1,
                                ignite: ignite,
                                size: flameSize,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Opacity(
                            opacity: _span(numberIn, 0, 0.3),
                            child: Transform.scale(
                              scale: pop,
                              child: Text(
                                '$shown',
                                style: TextStyle(
                                  decoration: TextDecoration.none,
                                  fontSize: 96,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: _tier.flame.withValues(alpha: 0.8),
                                      blurRadius: 28,
                                    ),
                                  ],
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: textIn,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - textIn)),
                              child: Column(
                                children: [
                                  Text(
                                    sentenceCaseOf(
                                      context,
                                      l10n.streakCelebrateLabel,
                                    ),
                                    style: TextStyle(
                                      decoration: TextDecoration.none,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _tier.headline(l10n).toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      decoration: TextDecoration.none,
                                      fontSize: 24,
                                      letterSpacing: 2.4,
                                      fontWeight: FontWeight.w900,
                                      color: _tier.core,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The warm light behind an inferno or a legend: one radial gradient that
/// breathes. A gradient, not a blur: nothing here filters what is behind it.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  Widget build(BuildContext context) {
    final breathe = 0.85 + 0.15 * math.sin(t * math.pi * 6);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.9 * breathe,
          colors: [
            color.withValues(alpha: 0.38),
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
    );
  }
}

/// One spark or one piece of confetti, fully described by its seed so the
/// painter does no allocation per frame.
class _Grain {
  _Grain({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.delay,
    required this.spin,
    required this.drift,
    required this.confetti,
  });

  factory _Grain.spark(math.Random r, List<Color> palette, {required bool burst}) {
    // Sparks float UP out of the flame; an inferno also bursts sideways and down.
    final angle = burst
        ? r.nextDouble() * 2 * math.pi
        : -math.pi / 2 + (r.nextDouble() - 0.5) * 1.5;
    return _Grain(
      angle: angle,
      speed: 0.35 + r.nextDouble() * 0.75,
      size: 2 + r.nextDouble() * 4.5,
      color: palette[r.nextInt(palette.length)],
      delay: 0.08 + r.nextDouble() * 0.22,
      spin: 0,
      drift: (r.nextDouble() - 0.5) * 0.3,
      confetti: false,
    );
  }

  factory _Grain.confetti(math.Random r, List<Color> palette) => _Grain(
    angle: r.nextDouble(),
    speed: 0.5 + r.nextDouble() * 0.6,
    size: 6 + r.nextDouble() * 6,
    color: palette[r.nextInt(palette.length)],
    delay: 0.18 + r.nextDouble() * 0.3,
    spin: (r.nextDouble() - 0.5) * 14,
    drift: (r.nextDouble() - 0.5) * 0.25,
    confetti: true,
  );

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double delay;
  final double spin;
  final double drift;
  final bool confetti;
}

class _FxPainter extends CustomPainter {
  _FxPainter({
    required this.tier,
    required this.t,
    required this.sparks,
    required this.confetti,
    required this.flameSize,
  });

  final StreakTier tier;
  final double t;
  final List<_Grain> sparks;
  final List<_Grain> confetti;
  final double flameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2 - flameSize * 0.1);
    final paint = Paint();

    if (tier.rays) {
      final reach = size.longestSide;
      final a = ((t - 0.1) / 0.25).clamp(0.0, 1.0) * (1 - ((t - 0.8) / 0.2).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(t * 1.4);
      const rays = 14;
      for (var i = 0; i < rays; i++) {
        canvas.rotate(2 * math.pi / rays);
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(reach, -reach * 0.045)
          ..lineTo(reach, reach * 0.045)
          ..close();
        paint.shader = _rayShader(reach, tier.flame.withValues(alpha: 0.22 * a));
        canvas.drawPath(path, paint);
      }
      canvas.restore();
      paint.shader = null;
    }

    if (tier.ring) {
      final p = ((t - 0.1) / 0.32).clamp(0.0, 1.0);
      if (p > 0 && p < 1) {
        final eased = Curves.easeOutCubic.transform(p);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - p) + 1
          ..color = tier.core.withValues(alpha: 0.7 * (1 - p));
        canvas.drawCircle(origin, flameSize * (0.4 + 1.5 * eased), paint);
        paint.style = PaintingStyle.fill;
      }
    }

    for (final g in sparks) {
      final p = ((t - g.delay) / 0.55).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final dist = Curves.easeOutCubic.transform(p) * g.speed * size.shortestSide * 0.62;
      final lift = tier.glow ? 0.0 : p * p * flameSize * 0.25;
      final pos = origin.translate(
        math.cos(g.angle) * dist + g.drift * dist,
        math.sin(g.angle) * dist - lift,
      );
      paint.color = g.color.withValues(alpha: (1 - p) * 0.95);
      canvas.drawCircle(pos, g.size * (1 - p * 0.5), paint);
    }

    for (final g in confetti) {
      final p = ((t - g.delay) / 0.62).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final x = size.width * g.angle + math.sin(p * 6 + g.angle * 9) * 22 + g.drift * size.width * p;
      final y = -20 + (size.height + 40) * Curves.easeIn.transform(p) * g.speed;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(g.spin * p);
      paint.color = g.color.withValues(alpha: 1 - p * p);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: g.size, height: g.size * 0.55),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.t != t;
}

/// A ray's fade: strong at the flame, gone at the edge.
Shader _rayShader(double reach, Color c) => RadialGradient(
  colors: [c, c.withValues(alpha: 0)],
).createShader(Rect.fromCircle(center: Offset.zero, radius: reach));
