import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Port of v02's "Retro Wave" theme — pink + cyan over deep purple.
class RetroWaveTheme implements AppTheme {
  @override
  String get id => 'retro_wave';
  @override
  String get name => 'Retro Wave';
  @override
  String get tagline => 'sunset on the grid';
  @override
  ThemeMood get mood => ThemeMood.vault;

  @override
  List<Color> get swatch => const [Color(0xFF120458), Color(0xFFFF2E6C), Color(0xFF00F9FF)];

  @override
  Color get background => const Color(0xFF120458);
  @override
  Color get surface => const Color(0xFF1B0B40);
  @override
  Color get surfaceRaised => const Color(0xFF26124F);
  @override
  Color get surfaceSunken => const Color(0xFF0A0230);
  @override
  Color get divider => const Color(0xFF00F9FF).withValues(alpha: 0.16);

  @override
  Color get ink => Colors.white;
  @override
  Color get inkSoft => const Color(0xFFE5DFFE);
  @override
  Color get inkMuted => const Color(0xFFB4A5FF);

  @override
  Color get accent => const Color(0xFF00F9FF);
  @override
  Color get accentInk => const Color(0xFF120458);
  @override
  Color get accentSoft => accent.withValues(alpha: 0.18);
  @override
  Color get danger => const Color(0xFFFF3D71);
  @override
  Color get success => const Color(0xFF00F9FF);

  Color get magenta => const Color(0xFFFF2E6C);
  Color get violet => const Color(0xFFFB00FF);

  TextStyle _disp(double s, FontWeight w) => GoogleFonts.audiowide(
        fontSize: s,
        fontWeight: w,
        height: 1.05,
        letterSpacing: 1.2,
        color: ink,
      );
  TextStyle _mono(double s, [FontWeight w = FontWeight.w500]) =>
      GoogleFonts.spaceMono(fontSize: s, fontWeight: w, height: 1.2, color: inkSoft);

  @override
  TextStyle get displayHero => _disp(56, FontWeight.w400).copyWith(letterSpacing: 2);
  @override
  TextStyle get displayLarge => _disp(30, FontWeight.w400).copyWith(letterSpacing: 1.4);
  @override
  TextStyle get displayMedium => _disp(22, FontWeight.w400).copyWith(letterSpacing: 1);
  @override
  TextStyle get displaySmall => GoogleFonts.audiowide(
      fontSize: 17, fontWeight: FontWeight.w400, height: 1.2, color: ink);
  @override
  TextStyle get body => GoogleFonts.spaceMono(
      fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: inkSoft);
  @override
  TextStyle get bodyEmph => GoogleFonts.spaceMono(
      fontSize: 14, fontWeight: FontWeight.w700, height: 1.45, color: ink);
  @override
  TextStyle get bodySoft => GoogleFonts.spaceMono(
      fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, color: inkMuted);
  @override
  TextStyle get caption =>
      _mono(11, FontWeight.w700).copyWith(letterSpacing: 1.6, color: accent);
  @override
  TextStyle get mono => _mono(12, FontWeight.w400);
  @override
  TextStyle get monoLarge => _mono(16, FontWeight.w700).copyWith(color: accent);
  @override
  TextStyle get monoTiny =>
      _mono(9, FontWeight.w700).copyWith(letterSpacing: 1.8, color: inkMuted);
  @override
  TextStyle get label =>
      _mono(10, FontWeight.w700).copyWith(letterSpacing: 2.0, color: accent);

  @override
  double get radiusSm => 0;
  @override
  double get radiusMd => 2;
  @override
  double get radiusLg => 4;
  @override
  double get radiusXl => 8;

  @override
  Duration get motionFast => const Duration(milliseconds: 200);
  @override
  Duration get motionMed => const Duration(milliseconds: 420);
  @override
  Duration get motionSlow => const Duration(milliseconds: 700);
  @override
  Curve get motionCurve => Curves.easeOutExpo;
  @override
  Curve get motionEntrance => Curves.easeOutCubic;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: ephemeral ? magenta : accent.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
              color: (ephemeral ? magenta : accent).withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 4)),
        ],
      );

  @override
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral}) =>
      BoxDecoration(
        color: isMine ? accent : surfaceRaised,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusLg),
          topRight: Radius.circular(radiusLg),
          bottomLeft: Radius.circular(isMine ? radiusLg : radiusSm),
          bottomRight: Radius.circular(isMine ? radiusSm : radiusLg),
        ),
        border: Border.all(
            color: ephemeral
                ? magenta.withValues(alpha: 0.7)
                : (isMine ? accent : accent.withValues(alpha: 0.35)),
            width: 0.8),
        boxShadow: [
          BoxShadow(
              color: (isMine ? accent : magenta).withValues(alpha: 0.20),
              blurRadius: 14),
        ],
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [magenta.withValues(alpha: 0.18), surface],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(top: BorderSide(color: accent, width: 2)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent : Colors.transparent,
        border: Border.all(color: filled ? accent : accent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(0),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceSunken,
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Sky gradient
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1B0B40),
              magenta.withValues(alpha: 0.30),
              background,
            ],
            stops: const [0.0, 0.35, 0.7],
          ),
        ),
      ),
      // Sun
      Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFD400),
                  magenta,
                ],
              ),
              boxShadow: [
                BoxShadow(color: magenta.withValues(alpha: 0.6), blurRadius: 60, spreadRadius: 20),
              ],
            ),
          ),
        ),
      ),
      // Grid horizon
      IgnorePointer(child: CustomPaint(painter: _GridHorizonPainter(color: accent))),
    ]);
  }

  @override
  Widget ephemeralSignature({required double progress}) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              magenta.withValues(alpha: 0.5 * (1 - progress)),
              violet.withValues(alpha: 0.4 * (1 - progress)),
              accent.withValues(alpha: 0.4 * (1 - progress)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) =>
      Icon(isPublic ? Icons.public : Icons.public_off, size: size, color: accent);

  @override
  Widget hourglassIcon({double size = 16, Color? color}) =>
      Icon(Icons.hourglass_bottom, size: size, color: color ?? magenta);

  @override
  Widget brandMark({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [magenta, violet, accent],
        ),
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [BoxShadow(color: magenta.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      alignment: Alignment.center,
      child: Text('M',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w400,
            fontFamily: GoogleFonts.audiowide().fontFamily,
          )),
    );
  }

  // See AppTheme.iconMark — retro_wave's brandMark fills with a 3-color gradient.
  @override
  Widget iconMark({double size = 28}) => brandMark(size: size);

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    final palette = [
      const Color(0xFFFF2E6C),
      const Color(0xFFFB00FF),
      const Color(0xFF00F9FF),
      const Color(0xFFFFD400),
      const Color(0xFFA855F7),
    ];
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}

class _GridHorizonPainter extends CustomPainter {
  _GridHorizonPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.55;
    final p = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Horizon line glow
    final glow = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), glow);
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), p);

    // Perspective vertical lines
    final cx = size.width / 2;
    const numLines = 14;
    for (var i = -numLines; i <= numLines; i++) {
      final dx = i * size.width / 8;
      final start = Offset(cx, horizon);
      final end = Offset(cx + dx * 6, size.height + 10);
      canvas.drawLine(start, end, p);
    }
    // Horizontal grid lines below horizon, foreshortened
    for (var i = 1; i < 12; i++) {
      final t = i / 12.0;
      final y = horizon + math.pow(t, 1.8).toDouble() * (size.height - horizon);
      final a = (0.4 - i * 0.025).clamp(0.0, 1.0);
      final line = Paint()
        ..color = color.withValues(alpha: a)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridHorizonPainter oldDelegate) => false;
}
