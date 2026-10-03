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
  String get tagline => 'Sunset on the grid.';
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

  /// Reading text. Space Mono at body size spent ~40 characters on a line,
  /// so a two-line preview held one sentence; the theme's voice stays in the
  /// Audiowide titles and the mono meta, and prose gets a proportional face.
  TextStyle _text(double s, FontWeight w, Color c) => GoogleFonts.inter(
        fontSize: s,
        fontWeight: w,
        height: 1.4,
        letterSpacing: -0.1,
        color: c,
      );

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
  TextStyle get body => _text(16, FontWeight.w400, inkSoft);
  @override
  TextStyle get bodyEmph => _text(16, FontWeight.w600, ink);
  @override
  TextStyle get bodySoft => _text(14, FontWeight.w400, inkMuted);
  // Tracking held to 0.6: callers set timestamps from this at 14pt, where the
  // old 1.6 spread "12:29 AM" across a third of the row.
  @override
  TextStyle get caption =>
      _mono(11, FontWeight.w700).copyWith(letterSpacing: 0.6, color: accent);
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
          color: ephemeral
              ? magenta.withValues(alpha: 0.7)
              : accent.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
              color: (ephemeral ? magenta : accent).withValues(alpha: 0.12),
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
      // Grid horizon
      // The sun sets ON the horizon, low on the screen, and dimmed. It used to
      // hang at the top behind the title and the filter chips, where the
      // orange disc ate the chip labels outright. Down here, at 26% and cut
      // into bands, every ink colour still clears 4.3:1 over its brightest
      // (yellow) edge.
      IgnorePointer(
        child: CustomPaint(
          painter: _GridHorizonPainter(
            color: accent,
            sunTop: const Color(0xFFFFD400),
            sunBottom: magenta,
          ),
        ),
      ),
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
    // The neon hues themselves (cyan #00F9FF, yellow #FFD400) put white
    // initials at 1.3:1. Same hue families, deep enough that the lit top of
    // a monogram still holds white at 3:1 or better.
    final palette = [
      const Color(0xFFD9266A),
      const Color(0xFFB800C4),
      const Color(0xFF0080A8),
      const Color(0xFFB86206),
      const Color(0xFF8A3FE0),
    ];
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}

class _GridHorizonPainter extends CustomPainter {
  _GridHorizonPainter({
    required this.color,
    required this.sunTop,
    required this.sunBottom,
  });
  final Color color;
  final Color sunTop;
  final Color sunBottom;

  /// The sun's opacity. See the comment at the call site for the contrast
  /// budget this is held to.
  static const double _sunAlpha = 0.26;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.74;

    // Setting sun: a disc centred on the horizon, clipped to the sky, its
    // lower half cut into the classic thinning bands.
    final r = size.width * 0.32;
    final centre = Offset(size.width / 2, horizon);
    final sunRect = Rect.fromCircle(center: centre, radius: r);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, horizon));
    final bands = Path()..addRect(Rect.fromLTRB(0, 0, size.width, horizon));
    for (var i = 0; i < 5; i++) {
      final y = horizon - r * 0.12 - i * r * 0.11;
      final gap = r * (0.055 - i * 0.009);
      bands.addRect(Rect.fromLTRB(0, y - gap, size.width, y));
    }
    bands.fillType = PathFillType.evenOdd;
    canvas.clipPath(bands);
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sunTop.withValues(alpha: _sunAlpha),
            sunBottom.withValues(alpha: _sunAlpha),
          ],
        ).createShader(Rect.fromLTRB(
          sunRect.left,
          sunRect.top,
          sunRect.right,
          horizon,
        )),
    );
    canvas.restore();

    final p = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Horizon line glow
    final glow = Paint()
      ..color = color.withValues(alpha: 0.4)
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
      final a = (0.22 - i * 0.015).clamp(0.0, 1.0);
      final line = Paint()
        ..color = color.withValues(alpha: a)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridHorizonPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.sunTop != sunTop ||
      oldDelegate.sunBottom != sunBottom;
}
