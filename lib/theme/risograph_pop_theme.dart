import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class RisographPopTheme implements AppTheme {
  @override
  String get id => 'risograph_pop';
  @override
  String get name => 'Risograph Pop';
  @override
  String get tagline => 'a screen-printed zine';
  @override
  ThemeMood get mood => ThemeMood.riso;

  @override
  List<Color> get swatch => const [Color(0xFFF3EAD3), Color(0xFF1E3A8A), Color(0xFFEA580C)];

  @override
  Color get background => const Color(0xFFF3EAD3);
  @override
  Color get surface => const Color(0xFFFAF3DE);
  @override
  Color get surfaceRaised => const Color(0xFFFFFAE9);
  @override
  Color get surfaceSunken => const Color(0xFFEADFC2);
  @override
  Color get divider => const Color(0xFF1A1A1A);

  @override
  Color get ink => const Color(0xFF1A1A1A);
  @override
  Color get inkSoft => const Color(0xFF2A2A2A);
  @override
  Color get inkMuted => const Color(0xFF5A554A);

  @override
  Color get accent => const Color(0xFFEA580C);
  @override
  Color get accentInk => const Color(0xFFFAF3DE);
  @override
  Color get accentSoft => const Color(0xFFEA580C).withValues(alpha: 0.18);
  @override
  Color get danger => const Color(0xFFC2410C);
  @override
  Color get success => const Color(0xFF1E3A8A);

  Color get blueInk => const Color(0xFF1E3A8A);

  @override
  TextStyle get displayHero => GoogleFonts.fraunces(
        fontSize: 72,
        fontWeight: FontWeight.w900,
        height: 0.92,
        letterSpacing: -3,
        color: ink,
      );
  @override
  TextStyle get displayLarge => GoogleFonts.fraunces(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 0.96,
        letterSpacing: -1.4,
        color: ink,
      );
  @override
  TextStyle get displayMedium => GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -0.6,
        color: ink,
      );
  @override
  TextStyle get displaySmall => GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: ink,
      );
  @override
  TextStyle get body => GoogleFonts.fraunces(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: ink,
      );
  @override
  TextStyle get bodyEmph => GoogleFonts.fraunces(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: ink,
      );
  @override
  TextStyle get bodySoft => GoogleFonts.fraunces(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: inkMuted,
      );
  @override
  TextStyle get caption => GoogleFonts.spaceMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get mono => GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: ink,
      );
  @override
  TextStyle get monoLarge => GoogleFonts.spaceMono(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: ink,
      );
  @override
  TextStyle get monoTiny => GoogleFonts.spaceMono(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get label => GoogleFonts.spaceMono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        height: 1.2,
        color: ink,
      );

  @override
  double get radiusSm => 2;
  @override
  double get radiusMd => 4;
  @override
  double get radiusLg => 6;
  @override
  double get radiusXl => 10;

  @override
  Duration get motionFast => const Duration(milliseconds: 180);
  @override
  Duration get motionMed => const Duration(milliseconds: 360);
  @override
  Duration get motionSlow => const Duration(milliseconds: 600);
  @override
  Curve get motionCurve => Curves.easeOutBack;
  @override
  Curve get motionEntrance => Curves.easeOutCubic;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) {
    return BoxDecoration(
      color: active ? surfaceRaised : surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(color: ink, width: 2),
      boxShadow: [
        BoxShadow(color: ink, blurRadius: 0, offset: const Offset(4, 4)),
      ],
    );
  }

  @override
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral}) {
    return BoxDecoration(
      color: isMine ? accent : surfaceRaised,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radiusLg),
        topRight: Radius.circular(radiusLg),
        bottomLeft: Radius.circular(isMine ? radiusLg : 1),
        bottomRight: Radius.circular(isMine ? 1 : radiusLg),
      ),
      border: Border.all(color: ink, width: 1.8),
      boxShadow: [
        BoxShadow(color: ink, blurRadius: 0, offset: const Offset(2.5, 2.5)),
      ],
    );
  }

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: ink, width: 2.5),
          left: BorderSide(color: ink, width: 2),
          right: BorderSide(color: ink, width: 2),
        ),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? blueInk : surface,
        border: Border.all(color: ink, width: 1.5),
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceRaised,
        border: Border.all(color: ink, width: 1.8),
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: background),
        IgnorePointer(child: CustomPaint(painter: _HalftoneBackgroundPainter(color: blueInk, seed: 11))),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.9),
              radius: 0.9,
              colors: [accent.withValues(alpha: 0.06), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget ephemeralSignature({required double progress}) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScatterDotsPainter(progress: progress, color: accent, seed: 23),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RisoVisibilityPainter(isPublic: isPublic, color: ink, fill: isPublic ? accent : blueInk),
    );
  }

  @override
  Widget hourglassIcon({double size = 16, Color? color}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RisoHourglassPainter(stroke: ink, fill: color ?? accent),
    );
  }

  @override
  Widget brandMark({double size = 28}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StarBurstPainter(stroke: ink, fill: accent, secondary: blueInk),
    );
  }

  @override
  List<Color> avatarGradient(int seed) {
    final palette = [
      const Color(0xFFEA580C),
      const Color(0xFF1E3A8A),
      const Color(0xFFFFC857),
      const Color(0xFFE63946),
      const Color(0xFF2A9D8F),
      const Color(0xFFA663CC),
    ];
    final rand = math.Random(seed);
    final a = palette[rand.nextInt(palette.length)];
    final b = palette[rand.nextInt(palette.length)];
    return [a, b];
  }
}

class _HalftoneBackgroundPainter extends CustomPainter {
  _HalftoneBackgroundPainter({required this.color, required this.seed});
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final paint = Paint();
    const cell = 18.0;
    for (var x = 0.0; x < size.width; x += cell) {
      for (var y = 0.0; y < size.height; y += cell) {
        final r = 0.4 + rand.nextDouble() * 1.1;
        final a = 0.04 + rand.nextDouble() * 0.06;
        paint.color = color.withValues(alpha: a);
        canvas.drawCircle(Offset(x + cell / 2, y + cell / 2), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftoneBackgroundPainter oldDelegate) => false;
}

class _ScatterDotsPainter extends CustomPainter {
  _ScatterDotsPainter({required this.progress, required this.color, required this.seed});
  final double progress;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final paint = Paint();
    final count = 40;
    for (var i = 0; i < count; i++) {
      final originX = rand.nextDouble() * size.width;
      final originY = rand.nextDouble() * size.height;
      final dirAngle = rand.nextDouble() * math.pi * 2;
      final dist = progress * (40 + rand.nextDouble() * 60);
      final cx = originX + math.cos(dirAngle) * dist;
      final cy = originY + math.sin(dirAngle) * dist;
      final r = (1.5 + rand.nextDouble() * 2.5) * (1 - progress * 0.3).clamp(0.0, 1.0);
      final a = (1 - progress).clamp(0.0, 1.0) * 0.85;
      paint.color = color.withValues(alpha: a);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterDotsPainter oldDelegate) => oldDelegate.progress != progress;
}

class _RisoVisibilityPainter extends CustomPainter {
  _RisoVisibilityPainter({required this.isPublic, required this.color, required this.fill});
  final bool isPublic;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final f = Paint()..color = fill;
    final c = Offset(size.width / 2, size.height / 2);
    if (isPublic) {
      // Megaphone shape
      final path = Path()
        ..moveTo(size.width * 0.15, size.height * 0.35)
        ..lineTo(size.width * 0.7, size.height * 0.15)
        ..lineTo(size.width * 0.7, size.height * 0.85)
        ..lineTo(size.width * 0.15, size.height * 0.65)
        ..close();
      canvas.drawPath(path, f);
      canvas.drawPath(path, s);
      // sound waves
      canvas.drawArc(Rect.fromCenter(center: Offset(size.width * 0.78, c.dy), width: size.width * 0.18, height: size.height * 0.45), -0.6, 1.2, false, s);
    } else {
      // Padlock filled
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + size.height * 0.18), width: size.width * 0.65, height: size.height * 0.5),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(body, f);
      canvas.drawRRect(body, s);
      final shackle = Path()
        ..moveTo(c.dx - size.width * 0.2, c.dy - size.height * 0.08)
        ..quadraticBezierTo(c.dx, c.dy - size.height * 0.6, c.dx + size.width * 0.2, c.dy - size.height * 0.08);
      canvas.drawPath(shackle, s);
    }
  }

  @override
  bool shouldRepaint(covariant _RisoVisibilityPainter oldDelegate) => oldDelegate.isPublic != isPublic;
}

class _RisoHourglassPainter extends CustomPainter {
  _RisoHourglassPainter({required this.stroke, required this.fill});
  final Color stroke;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.18;
    final top = Path()
      ..moveTo(pad, pad)
      ..lineTo(size.width - pad, pad)
      ..lineTo(size.width / 2, size.height / 2)
      ..close();
    final bottom = Path()
      ..moveTo(size.width / 2, size.height / 2)
      ..lineTo(pad, size.height - pad)
      ..lineTo(size.width - pad, size.height - pad)
      ..close();
    canvas.drawPath(top, Paint()..color = fill);
    canvas.drawPath(bottom, Paint()..color = fill.withValues(alpha: 0.5));
    final s = Paint()
      ..color = stroke
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(top, s);
    canvas.drawPath(bottom, s);
    canvas.drawLine(Offset(pad - 1, pad), Offset(size.width - pad + 1, pad), s);
    canvas.drawLine(Offset(pad - 1, size.height - pad), Offset(size.width - pad + 1, size.height - pad), s);
  }

  @override
  bool shouldRepaint(covariant _RisoHourglassPainter oldDelegate) => false;
}

class _StarBurstPainter extends CustomPainter {
  _StarBurstPainter({required this.stroke, required this.fill, required this.secondary});
  final Color stroke;
  final Color fill;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    // 8-point burst
    final path = Path();
    const points = 8;
    for (var i = 0; i < points * 2; i++) {
      final t = i / (points * 2);
      final angle = t * math.pi * 2 - math.pi / 2;
      final radius = i.isEven ? r : r * 0.55;
      final x = c.dx + math.cos(angle) * radius;
      final y = c.dy + math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    // Secondary offset for overprint
    canvas.save();
    canvas.translate(1.2, 1.2);
    canvas.drawPath(path, Paint()..color = secondary.withValues(alpha: 0.85));
    canvas.restore();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter oldDelegate) => false;
}
