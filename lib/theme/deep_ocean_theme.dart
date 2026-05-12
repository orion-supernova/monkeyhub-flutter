import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Port of v02's "Deep Ocean" theme — navy + teal, water surface vibes.
/// This is also v02's login screen theme reference.
class DeepOceanTheme implements AppTheme {
  @override
  String get id => 'deep_ocean';
  @override
  String get name => 'Deep Ocean';
  @override
  String get tagline => 'calm under pressure';
  @override
  ThemeMood get mood => ThemeMood.aurora;

  @override
  List<Color> get swatch => const [Color(0xFF0A192F), Color(0xFF1A2980), Color(0xFF26D0CE)];

  @override
  Color get background => const Color(0xFF0A192F);
  @override
  Color get surface => const Color(0xFF112240);
  @override
  Color get surfaceRaised => const Color(0xFF172A4A);
  @override
  Color get surfaceSunken => const Color(0xFF050E1C);
  @override
  Color get divider => const Color(0xFF26D0CE).withValues(alpha: 0.16);

  @override
  Color get ink => Colors.white;
  @override
  Color get inkSoft => const Color(0xFFCCD6F6);
  @override
  Color get inkMuted => const Color(0xFF8892B0);

  @override
  Color get accent => const Color(0xFF26D0CE);
  @override
  Color get accentInk => const Color(0xFF0A192F);
  @override
  Color get accentSoft => accent.withValues(alpha: 0.18);
  @override
  Color get danger => const Color(0xFFFF647C);
  @override
  Color get success => accent;

  Color get deep => const Color(0xFF1A2980);

  TextStyle _disp(double s, FontWeight w) => GoogleFonts.spectral(
        fontSize: s,
        fontWeight: w,
        height: 1.05,
        letterSpacing: -0.5,
        color: ink,
      );
  TextStyle _mono(double s, [FontWeight w = FontWeight.w500]) =>
      GoogleFonts.ibmPlexMono(fontSize: s, fontWeight: w, height: 1.2, color: inkSoft);

  @override
  TextStyle get displayHero => _disp(64, FontWeight.w300).copyWith(letterSpacing: -1.5, fontStyle: FontStyle.italic);
  @override
  TextStyle get displayLarge => _disp(34, FontWeight.w400);
  @override
  TextStyle get displayMedium => _disp(24, FontWeight.w400);
  @override
  TextStyle get displaySmall => _disp(18, FontWeight.w500);
  @override
  TextStyle get body => GoogleFonts.spectral(
      fontSize: 15, fontWeight: FontWeight.w400, height: 1.5, color: inkSoft);
  @override
  TextStyle get bodyEmph => GoogleFonts.spectral(
      fontSize: 15, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, height: 1.5, color: ink);
  @override
  TextStyle get bodySoft => GoogleFonts.spectral(
      fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: inkMuted);
  @override
  TextStyle get caption =>
      _mono(11, FontWeight.w500).copyWith(letterSpacing: 1.2, color: inkMuted);
  @override
  TextStyle get mono => _mono(12, FontWeight.w400);
  @override
  TextStyle get monoLarge => _mono(16, FontWeight.w500).copyWith(color: accent);
  @override
  TextStyle get monoTiny =>
      _mono(9, FontWeight.w600).copyWith(letterSpacing: 1.6, color: inkMuted);
  @override
  TextStyle get label =>
      _mono(10, FontWeight.w600).copyWith(letterSpacing: 1.8, color: accent);

  @override
  double get radiusSm => 6;
  @override
  double get radiusMd => 12;
  @override
  double get radiusLg => 18;
  @override
  double get radiusXl => 24;

  @override
  Duration get motionFast => const Duration(milliseconds: 280);
  @override
  Duration get motionMed => const Duration(milliseconds: 560);
  @override
  Duration get motionSlow => const Duration(milliseconds: 900);
  @override
  Curve get motionCurve => Curves.easeInOutCubicEmphasized;
  @override
  Curve get motionEntrance => Curves.easeOutCubic;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: ephemeral ? accent : accent.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: ephemeral ? 0.25 : 0.10),
              blurRadius: 22,
              offset: const Offset(0, 8)),
        ],
      );

  @override
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral}) =>
      BoxDecoration(
        color: isMine ? accent.withValues(alpha: 0.88) : surfaceRaised,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusLg),
          topRight: Radius.circular(radiusLg),
          bottomLeft: Radius.circular(isMine ? radiusLg : radiusSm),
          bottomRight: Radius.circular(isMine ? radiusSm : radiusLg),
        ),
        border: ephemeral
            ? Border.all(color: accent.withValues(alpha: 0.6), width: 0.8)
            : null,
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [deep.withValues(alpha: 0.3), surface],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.35), width: 1)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent : Colors.transparent,
        border: Border.all(color: filled ? accent : accent.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceSunken,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) {
    return const _OceanBackground();
  }

  @override
  Widget ephemeralSignature({required double progress}) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              accent.withValues(alpha: 0.45 * (1 - progress)),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) =>
      Icon(isPublic ? Icons.public : Icons.lock_outline, size: size, color: inkSoft);

  @override
  Widget hourglassIcon({double size = 16, Color? color}) =>
      Icon(Icons.hourglass_bottom, size: size, color: color ?? accent);

  @override
  Widget brandMark({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deep, accent],
        ),
        borderRadius: BorderRadius.circular(size * 0.5),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 14)],
      ),
      alignment: Alignment.center,
      child: Text('M',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w400,
            fontFamily: GoogleFonts.spectral().fontFamily,
            fontStyle: FontStyle.italic,
          )),
    );
  }

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    final palette = [
      const Color(0xFF26D0CE),
      const Color(0xFF1A2980),
      const Color(0xFF38BDF8),
      const Color(0xFF60A5FA),
      const Color(0xFF14B8A6),
      const Color(0xFF6366F1),
    ];
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}

class _OceanBackground extends StatefulWidget {
  const _OceanBackground();
  @override
  State<_OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<_OceanBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(painter: _OceanPainter(t: _ctrl.value), size: Size.infinite),
    );
  }
}

class _OceanPainter extends CustomPainter {
  _OceanPainter({required this.t});
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    // Gradient base
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF0A192F), Color(0xFF0E2143), Color(0xFF050E1C)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    // Soft glow patches
    final phase = t * math.pi * 2;
    final patches = [
      _Patch(const Color(0xFF26D0CE), 0.8, 0.25, 0.30, 0.0),
      _Patch(const Color(0xFF1A2980), 0.9, 0.75, 0.55, 1.2),
      _Patch(const Color(0xFF38BDF8), 0.7, 0.5, 0.85, 2.0),
    ];
    for (final p in patches) {
      final cx = (p.cx + 0.06 * math.cos(phase + p.phase)) * size.width;
      final cy = (p.cy + 0.04 * math.sin(phase * 0.7 + p.phase)) * size.height;
      final r = size.shortestSide * p.scale;
      final paint = Paint()
        ..shader = RadialGradient(colors: [p.color.withValues(alpha: 0.30), p.color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OceanPainter oldDelegate) => true;
}

class _Patch {
  _Patch(this.color, this.scale, this.cx, this.cy, this.phase);
  final Color color;
  final double scale;
  final double cx;
  final double cy;
  final double phase;
}
