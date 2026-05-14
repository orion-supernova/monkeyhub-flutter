import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class BioOrganicTheme implements AppTheme {
  @override
  String get id => 'bio_organic';
  @override
  String get name => 'Bio-Organic';
  @override
  String get tagline => 'deep-sea calm';
  @override
  ThemeMood get mood => ThemeMood.aurora;

  @override
  List<Color> get swatch => const [Color(0xFF050714), Color(0xFF22D3EE), Color(0xFFD946EF)];

  @override
  Color get background => const Color(0xFF050714);
  // Glass surfaces use a *dark* tint (not white) so the bottom pill nav and
  // cards read as dark glass on the aurora — light text stays legible.
  // Previously these were white-with-alpha, which created a near-white pill
  // that swallowed unselected nav labels.
  @override
  Color get surface => const Color(0xFF101A33).withValues(alpha: 0.70);
  @override
  Color get surfaceRaised => const Color(0xFF182446).withValues(alpha: 0.82);
  @override
  Color get surfaceSunken => const Color(0xFF050714).withValues(alpha: 0.55);
  @override
  Color get divider => const Color(0xFFFFFFFF).withValues(alpha: 0.14);

  @override
  Color get ink => const Color(0xFFF1F6FF);
  @override
  Color get inkSoft => const Color(0xFFE2EAFA);
  @override
  Color get inkMuted => const Color(0xFFA6B0CC);

  @override
  Color get accent => const Color(0xFF22D3EE);
  @override
  Color get accentInk => const Color(0xFF052028);
  @override
  Color get accentSoft => const Color(0xFF22D3EE).withValues(alpha: 0.18);
  @override
  Color get danger => const Color(0xFFFB7185);
  @override
  Color get success => const Color(0xFF34D399);

  Color get magenta => const Color(0xFFD946EF);

  // Instrument Serif's natural tracking is already tight — heavy negative
  // letterSpacing crushes characters into each other. Hero gets a touch of
  // negative for shape, everything else uses near-neutral tracking and a
  // tiny positive value on body sizes for readability.
  @override
  TextStyle get displayHero => GoogleFonts.instrumentSerif(
        fontSize: 64,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.0,
        letterSpacing: -0.4,
        color: ink,
      );
  @override
  TextStyle get displayLarge => GoogleFonts.instrumentSerif(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        height: 1.1,
        letterSpacing: 0,
        color: ink,
      );
  @override
  TextStyle get displayMedium => GoogleFonts.instrumentSerif(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        height: 1.15,
        letterSpacing: 0.1,
        color: ink,
      );
  @override
  TextStyle get displaySmall => GoogleFonts.instrumentSerif(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.2,
        letterSpacing: 0.15,
        color: ink,
      );
  @override
  TextStyle get body => GoogleFonts.instrumentSerif(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.25,
        color: inkSoft,
      );
  @override
  TextStyle get bodyEmph => GoogleFonts.instrumentSerif(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.5,
        letterSpacing: 0.25,
        color: ink,
      );
  @override
  TextStyle get bodySoft => GoogleFonts.instrumentSerif(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        letterSpacing: 0.2,
        color: inkMuted,
      );
  // Labels switch from IBM Plex Mono → Inter for a warmer, less code-y feel
  // that pairs with the Instrument Serif display + body.
  @override
  TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get mono => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: inkSoft,
      );
  @override
  TextStyle get monoLarge => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      );
  @override
  TextStyle get monoTiny => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get label => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.2,
        color: inkSoft,
      );

  @override
  double get radiusSm => 8;
  @override
  double get radiusMd => 14;
  @override
  double get radiusLg => 20;
  @override
  double get radiusXl => 28;

  @override
  Duration get motionFast => const Duration(milliseconds: 300);
  @override
  Duration get motionMed => const Duration(milliseconds: 600);
  @override
  Duration get motionSlow => const Duration(milliseconds: 1000);
  @override
  Curve get motionCurve => Curves.easeInOutCubicEmphasized;
  @override
  Curve get motionEntrance => Curves.easeOutCubic;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) {
    return BoxDecoration(
      color: active ? surfaceRaised : surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(
        color: ephemeral
            ? magenta.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.12),
        width: 1,
      ),
      gradient: ephemeral
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                magenta.withValues(alpha: 0.10),
                accent.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: ephemeral ? magenta.withValues(alpha: 0.30) : accent.withValues(alpha: 0.10),
          blurRadius: ephemeral ? 32 : 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  @override
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral}) {
    return BoxDecoration(
      color: isMine ? accent.withValues(alpha: 0.88) : surfaceRaised,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radiusLg),
        topRight: Radius.circular(radiusLg),
        bottomLeft: Radius.circular(isMine ? radiusLg : radiusSm),
        bottomRight: Radius.circular(isMine ? radiusSm : radiusLg),
      ),
      border: Border.all(
        color: ephemeral
            ? magenta.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.10),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: (isMine ? accent : magenta).withValues(alpha: ephemeral ? 0.25 : 0.10),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ],
    );
  }

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: const Color(0xFF0A0E20).withValues(alpha: 0.75),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: filled ? 0 : 0.18), width: 1),
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceSunken,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) {
    return const _AuroraStatic();
  }

  @override
  Widget ephemeralSignature({required double progress}) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BioShimmerPainter(progress: progress, accent: accent, magenta: magenta),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BioVisibilityPainter(isPublic: isPublic, color: inkSoft, glow: accent),
    );
  }

  @override
  Widget hourglassIcon({double size = 16, Color? color}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BioHourglassPainter(color: color ?? magenta),
    );
  }

  @override
  Widget brandMark({double size = 28}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BlobOrbPainter(accent: accent, magenta: magenta, ink: ink),
    );
  }

  // BrandIconCanvas's surface backdrop fills the corners where the blob has
  // transparent edges. See AppTheme.iconMark.
  @override
  Widget iconMark({double size = 28}) => brandMark(size: size);

  @override
  List<Color> avatarGradient(int seed) {
    final palette = [
      const Color(0xFF22D3EE),
      const Color(0xFFD946EF),
      const Color(0xFF38BDF8),
      const Color(0xFF34D399),
      const Color(0xFFA78BFA),
      const Color(0xFFF472B6),
    ];
    final rand = math.Random(seed);
    final a = palette[rand.nextInt(palette.length)];
    final b = palette[rand.nextInt(palette.length)];
    return [a, b];
  }
}

/// Static "aurora" backdrop. Previously this was an animated CustomPaint with
/// five `MaskFilter.blur(radius: 60)` blobs + an 80-star twinkle loop, which
/// repainted every frame and pinned the GPU. The look is preserved here as
/// three overlaid fullscreen `RadialGradient`s (cheap, one-shot shader) plus
/// a tiny static star field — total cost is essentially zero after the first
/// frame, and the whole thing sits inside a `RepaintBoundary` so it never
/// invalidates the rest of the tree.
class _AuroraStatic extends StatelessWidget {
  const _AuroraStatic();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: const [
          ColoredBox(color: Color(0xFF050714)),
          _AuroraBlob(
            center: Alignment(-0.7, -0.8),
            radius: 0.95,
            color: Color(0xFF22D3EE), // cyan
            peakAlpha: 0.38,
          ),
          _AuroraBlob(
            center: Alignment(0.85, 0.75),
            radius: 1.05,
            color: Color(0xFFD946EF), // magenta
            peakAlpha: 0.32,
          ),
          _AuroraBlob(
            center: Alignment(-0.3, 0.6),
            radius: 0.85,
            color: Color(0xFF8B5CF6), // violet
            peakAlpha: 0.26,
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _StarFieldPainter(),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({
    required this.center,
    required this.radius,
    required this.color,
    required this.peakAlpha,
  });
  final Alignment center;
  final double radius;
  final Color color;
  final double peakAlpha;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [
              color.withValues(alpha: peakAlpha),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(99);
    final p = Paint();
    for (var i = 0; i < 32; i++) {
      p.color = Colors.white.withValues(alpha: 0.08 + rand.nextDouble() * 0.16);
      canvas.drawCircle(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
        0.6,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BioShimmerPainter extends CustomPainter {
  _BioShimmerPainter({required this.progress, required this.accent, required this.magenta});
  final double progress;
  final Color accent;
  final Color magenta;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(31);
    final particles = 30;
    for (var i = 0; i < particles; i++) {
      final ox = rand.nextDouble() * size.width;
      final oy = rand.nextDouble() * size.height;
      final angle = rand.nextDouble() * math.pi * 2;
      final dist = progress * (30 + rand.nextDouble() * 70);
      final cx = ox + math.cos(angle) * dist;
      final cy = oy + math.sin(angle) * dist - progress * 8;
      final color = i.isEven ? accent : magenta;
      final r = 1 + rand.nextDouble() * 2.5;
      final a = (1 - progress).clamp(0.0, 1.0) * 0.75;
      final paint = Paint()
        ..color = color.withValues(alpha: a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BioShimmerPainter oldDelegate) => oldDelegate.progress != progress;
}

class _BioVisibilityPainter extends CustomPainter {
  _BioVisibilityPainter({required this.isPublic, required this.color, required this.glow});
  final bool isPublic;
  final Color color;
  final Color glow;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final g = Paint()
      ..color = glow.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    if (isPublic) {
      // Concentric ripples
      for (var i = 0; i < 3; i++) {
        final r = size.width * (0.18 + i * 0.16);
        canvas.drawCircle(c, r, s);
      }
      canvas.drawCircle(c, size.width * 0.12, g);
    } else {
      // Closed orb
      canvas.drawCircle(c, size.width * 0.4, s);
      canvas.drawCircle(c, size.width * 0.4, g);
      // Small horizontal slit
      canvas.drawLine(Offset(c.dx - size.width * 0.18, c.dy), Offset(c.dx + size.width * 0.18, c.dy), s);
    }
  }
  @override
  bool shouldRepaint(covariant _BioVisibilityPainter oldDelegate) => oldDelegate.isPublic != isPublic;
}

class _BioHourglassPainter extends CustomPainter {
  _BioHourglassPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.2;
    final s = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final path = Path()
      ..moveTo(pad, pad)
      ..quadraticBezierTo(pad, size.height / 2, size.width / 2, size.height / 2)
      ..quadraticBezierTo(size.width - pad, size.height / 2, size.width - pad, size.height - pad)
      ..moveTo(pad, size.height - pad)
      ..quadraticBezierTo(pad, size.height / 2, size.width / 2, size.height / 2)
      ..quadraticBezierTo(size.width - pad, size.height / 2, size.width - pad, pad);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, s);
    canvas.drawLine(Offset(pad, pad), Offset(size.width - pad, pad), s);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(size.width - pad, size.height - pad), s);
  }
  @override
  bool shouldRepaint(covariant _BioHourglassPainter oldDelegate) => false;
}

class _BlobOrbPainter extends CustomPainter {
  _BlobOrbPainter({required this.accent, required this.magenta, required this.ink});
  final Color accent;
  final Color magenta;
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final g1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [accent, magenta.withValues(alpha: 0.7)],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(c, r, g1);
    canvas.drawCircle(c, r, Paint()
      ..color = ink.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);
    // Highlight
    canvas.drawCircle(
      Offset(c.dx - r * 0.35, c.dy - r * 0.4),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }
  @override
  bool shouldRepaint(covariant _BlobOrbPainter oldDelegate) => false;
}
