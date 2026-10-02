import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Port of v02's "Cyberpunk" theme — hot pink + acid green on near-black.
class CyberpunkTheme implements AppTheme {
  @override
  String get id => 'cyberpunk';
  @override
  String get name => 'Cyberpunk';
  @override
  String get tagline => 'neon bleeding through';
  @override
  ThemeMood get mood => ThemeMood.vault;

  @override
  List<Color> get swatch => const [Color(0xFF0A0A0F), Color(0xFFFF0055), Color(0xFF00FF66)];

  @override
  Color get background => const Color(0xFF0A0A0F);
  @override
  Color get surface => const Color(0xFF14141C);
  @override
  Color get surfaceRaised => const Color(0xFF1A1A25);
  @override
  Color get surfaceSunken => const Color(0xFF05050A);
  @override
  Color get divider => const Color(0xFF00FF66).withValues(alpha: 0.12);

  @override
  Color get ink => Colors.white;
  @override
  Color get inkSoft => const Color(0xFFE4F7EB);
  @override
  Color get inkMuted => const Color(0xFF8F8F9E);

  @override
  Color get accent => const Color(0xFF00FF66);
  @override
  Color get accentInk => const Color(0xFF0A0A0F);
  @override
  Color get accentSoft => accent.withValues(alpha: 0.18);
  @override
  Color get danger => const Color(0xFFFF0055);
  @override
  Color get success => accent;

  Color get magenta => const Color(0xFF9D00FF);

  // Syne's wide caps already sit close; -1.0 ran letters into each other
  // ("Weekend Crew"). A light negative keeps the display shape without the
  // collisions.
  TextStyle _disp(double s, FontWeight w) => GoogleFonts.syne(
        fontSize: s,
        fontWeight: w,
        height: 1.05,
        letterSpacing: -0.3,
        color: ink,
      );
  TextStyle _mono(double s, [FontWeight w = FontWeight.w500]) =>
      GoogleFonts.jetBrainsMono(fontSize: s, fontWeight: w, height: 1.2, color: inkSoft);

  @override
  TextStyle get displayHero => _disp(68, FontWeight.w800).copyWith(letterSpacing: -1);
  @override
  TextStyle get displayLarge => _disp(36, FontWeight.w800);
  @override
  TextStyle get displayMedium => _disp(26, FontWeight.w700);
  @override
  TextStyle get displaySmall => _disp(20, FontWeight.w600);
  @override
  TextStyle get body => GoogleFonts.syne(
      fontSize: 15, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.15, color: inkSoft);
  @override
  TextStyle get bodyEmph => GoogleFonts.syne(
      fontSize: 16, fontWeight: FontWeight.w700, height: 1.35, letterSpacing: 0.2, color: ink);
  @override
  TextStyle get bodySoft => GoogleFonts.syne(
      fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.1, color: inkMuted);
  @override
  TextStyle get caption =>
      _mono(11).copyWith(letterSpacing: 0.6, color: inkMuted, fontWeight: FontWeight.w600);
  @override
  TextStyle get mono => _mono(12, FontWeight.w400);
  @override
  TextStyle get monoLarge => _mono(16, FontWeight.w600).copyWith(color: accent);
  @override
  TextStyle get monoTiny =>
      _mono(9, FontWeight.w700).copyWith(letterSpacing: 1.6, color: inkMuted);
  @override
  TextStyle get label =>
      _mono(10, FontWeight.w700).copyWith(letterSpacing: 2.0, color: accent);

  @override
  double get radiusSm => 2;
  @override
  double get radiusMd => 4;
  @override
  double get radiusLg => 6;
  @override
  double get radiusXl => 10;

  @override
  Duration get motionFast => const Duration(milliseconds: 160);
  @override
  Duration get motionMed => const Duration(milliseconds: 320);
  @override
  Duration get motionSlow => const Duration(milliseconds: 560);
  @override
  Curve get motionCurve => Curves.easeOutBack;
  @override
  Curve get motionEntrance => Curves.easeOutCubic;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusLg),
        // A whisper of an edge. Full-strength green at 1.2pt on every card
        // stacked into cage bars down the list; the neon is kept for the
        // things that should glow — the accent, the ephemeral room.
        border: Border.all(
          color: ephemeral ? danger.withValues(alpha: 0.6) : accent.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: ephemeral
            ? [
                BoxShadow(
                  color: danger.withValues(alpha: 0.20),
                  blurRadius: 16,
                ),
              ]
            : null,
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
                ? danger.withValues(alpha: 0.6)
                : (isMine ? accent : accent.withValues(alpha: 0.14)),
            width: 0.8),
        boxShadow: isMine
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 12,
                ),
              ]
            : null,
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.5), width: 2)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent : Colors.transparent,
        border: Border.all(color: filled ? accent : accent.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceSunken,
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: background),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.8, -0.8),
            radius: 1.2,
            colors: [danger.withValues(alpha: 0.18), Colors.transparent],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, 0.8),
            radius: 1.2,
            colors: [magenta.withValues(alpha: 0.16), Colors.transparent],
          ),
        ),
      ),
      // Scanline overlay
      IgnorePointer(child: CustomPaint(painter: _ScanlinePainter(color: accent))),
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
              danger.withValues(alpha: 0.5 * (1 - progress)),
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
      Icon(Icons.hourglass_bottom, size: size, color: color ?? danger);

  @override
  Widget brandMark({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: accent, width: 1.5),
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      alignment: Alignment.center,
      child: Text('M',
          style: TextStyle(
            color: accent,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
          )),
    );
  }

  // Default delegate — see AppTheme.iconMark. Cyberpunk's brandMark already
  // fills its size box opaquely (background + accent border).
  @override
  Widget iconMark({double size = 28}) => brandMark(size: size);

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    // Deepened so a monogram's lit top still holds white at 3:1 — the
    // signal green and cyan were 1.3–1.5:1.
    final palette = [
      const Color(0xFFE0004C),
      const Color(0xFF008A3C),
      const Color(0xFF8A00E6),
      const Color(0xFFE0008F),
      const Color(0xFF007F9E),
    ];
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: 0.025);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }
  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => false;
}
