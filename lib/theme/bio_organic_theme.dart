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
  @override
  Color get surface => const Color(0xFFFFFFFF).withValues(alpha: 0.06);
  @override
  Color get surfaceRaised => const Color(0xFFFFFFFF).withValues(alpha: 0.10);
  @override
  Color get surfaceSunken => const Color(0xFF000000).withValues(alpha: 0.30);
  @override
  Color get divider => const Color(0xFFFFFFFF).withValues(alpha: 0.10);

  @override
  Color get ink => const Color(0xFFF1F6FF);
  @override
  Color get inkSoft => const Color(0xFFD7E1F4);
  @override
  Color get inkMuted => const Color(0xFF7E8CB1);

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

  @override
  TextStyle get displayHero => GoogleFonts.instrumentSerif(
        fontSize: 70,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 0.95,
        letterSpacing: -2,
        color: ink,
      );
  @override
  TextStyle get displayLarge => GoogleFonts.instrumentSerif(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.0,
        letterSpacing: -0.6,
        color: ink,
      );
  @override
  TextStyle get displayMedium => GoogleFonts.instrumentSerif(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        height: 1.1,
        letterSpacing: -0.4,
        color: ink,
      );
  @override
  TextStyle get displaySmall => GoogleFonts.instrumentSerif(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.15,
        color: ink,
      );
  @override
  TextStyle get body => GoogleFonts.instrumentSerif(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: inkSoft,
      );
  @override
  TextStyle get bodyEmph => GoogleFonts.instrumentSerif(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.45,
        color: ink,
      );
  @override
  TextStyle get bodySoft => GoogleFonts.instrumentSerif(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: inkMuted,
      );
  @override
  TextStyle get caption => GoogleFonts.ibmPlexMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get mono => GoogleFonts.ibmPlexMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: inkSoft,
      );
  @override
  TextStyle get monoLarge => GoogleFonts.ibmPlexMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: ink,
      );
  @override
  TextStyle get monoTiny => GoogleFonts.ibmPlexMono(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get label => GoogleFonts.ibmPlexMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
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
    return const _AuroraMesh();
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

class _AuroraMesh extends StatefulWidget {
  const _AuroraMesh();
  @override
  State<_AuroraMesh> createState() => _AuroraMeshState();
}

class _AuroraMeshState extends State<_AuroraMesh> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        painter: _AuroraPainter(t: _ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF050714));
    final phase = t * math.pi * 2;
    final blobs = [
      _Blob(const Color(0xFF3B82F6), 0.8, 0.15, 0.35, 0.0),
      _Blob(const Color(0xFFD946EF), 0.9, 0.85, 0.65, 0.6),
      _Blob(const Color(0xFF22D3EE), 0.7, 0.5, 0.2, 1.4),
      _Blob(const Color(0xFF14B8A6), 0.6, 0.2, 0.85, 2.2),
      _Blob(const Color(0xFF8B5CF6), 0.55, 0.7, 0.92, 3.0),
    ];
    for (final b in blobs) {
      final cx = (b.cx + 0.08 * math.cos(phase + b.phase)) * size.width;
      final cy = (b.cy + 0.06 * math.sin(phase * 0.8 + b.phase)) * size.height;
      final r = (size.shortestSide * b.scale) * (0.9 + 0.1 * math.sin(phase * 1.3 + b.phase));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [b.color.withValues(alpha: 0.42), b.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
    // Faint star field
    final rand = math.Random(99);
    final p = Paint();
    for (var i = 0; i < 80; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final twinkle = 0.4 + 0.6 * math.sin(phase * 2 + i * 7);
      p.color = Colors.white.withValues(alpha: 0.10 + 0.10 * twinkle.abs());
      canvas.drawCircle(Offset(x, y), 0.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}

class _Blob {
  _Blob(this.color, this.scale, this.cx, this.cy, this.phase);
  final Color color;
  final double scale;
  final double cx;
  final double cy;
  final double phase;
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
