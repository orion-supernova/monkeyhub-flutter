import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Port of v02's "Neon Night" theme — acid green/cyan/yellow on near-black.
class NeonNightTheme implements AppTheme {
  @override
  String get id => 'neon_night';
  @override
  String get name => 'Neon Night';
  @override
  String get tagline => '4 a.m. arcade';
  @override
  ThemeMood get mood => ThemeMood.vault;

  @override
  List<Color> get swatch => const [Color(0xFF090415), Color(0xFFFFFF00), Color(0xFF00FFE0)];

  @override
  Color get background => const Color(0xFF090415);
  @override
  Color get surface => const Color(0xFF131025);
  @override
  Color get surfaceRaised => const Color(0xFF1A1632);
  @override
  Color get surfaceSunken => const Color(0xFF04020E);
  @override
  Color get divider => const Color(0xFFFFFF00).withValues(alpha: 0.14);

  @override
  Color get ink => Colors.white;
  @override
  Color get inkSoft => const Color(0xFFE0FFF7);
  @override
  Color get inkMuted => const Color(0xFF7E7E9A);

  @override
  Color get accent => const Color(0xFFFFFF00); // electric yellow
  @override
  Color get accentInk => const Color(0xFF090415);
  @override
  Color get accentSoft => accent.withValues(alpha: 0.18);
  @override
  Color get danger => const Color(0xFFFF0055);
  @override
  Color get success => const Color(0xFF00FF66);

  Color get cyan => const Color(0xFF00FFE0);
  Color get lime => const Color(0xFF00FF66);

  TextStyle _disp(double s, FontWeight w) => GoogleFonts.anta(
        fontSize: s,
        fontWeight: w,
        height: 1.05,
        letterSpacing: -0.5,
        color: ink,
      );
  TextStyle _mono(double s, [FontWeight w = FontWeight.w500]) =>
      GoogleFonts.jetBrainsMono(fontSize: s, fontWeight: w, height: 1.2, color: inkSoft);

  @override
  TextStyle get displayHero => _disp(64, FontWeight.w400).copyWith(letterSpacing: -2);
  @override
  TextStyle get displayLarge => _disp(34, FontWeight.w400).copyWith(letterSpacing: -1);
  @override
  TextStyle get displayMedium => _disp(24, FontWeight.w400);
  @override
  TextStyle get displaySmall => _disp(18, FontWeight.w400);
  @override
  TextStyle get body => GoogleFonts.anta(
      fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: inkSoft);
  @override
  TextStyle get bodyEmph =>
      GoogleFonts.anta(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: ink);
  @override
  TextStyle get bodySoft => GoogleFonts.anta(
      fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: inkMuted);
  @override
  TextStyle get caption =>
      _mono(11, FontWeight.w600).copyWith(letterSpacing: 1.4, color: cyan);
  @override
  TextStyle get mono => _mono(12, FontWeight.w400);
  @override
  TextStyle get monoLarge => _mono(16, FontWeight.w600).copyWith(color: accent);
  @override
  TextStyle get monoTiny =>
      _mono(9, FontWeight.w700).copyWith(letterSpacing: 1.6, color: inkMuted);
  @override
  TextStyle get label =>
      _mono(10, FontWeight.w700).copyWith(letterSpacing: 2.0, color: cyan);

  @override
  double get radiusSm => 3;
  @override
  double get radiusMd => 6;
  @override
  double get radiusLg => 10;
  @override
  double get radiusXl => 14;

  @override
  Duration get motionFast => const Duration(milliseconds: 180);
  @override
  Duration get motionMed => const Duration(milliseconds: 360);
  @override
  Duration get motionSlow => const Duration(milliseconds: 640);
  @override
  Curve get motionCurve => Curves.easeOutQuad;
  @override
  Curve get motionEntrance => Curves.easeOutQuart;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: ephemeral ? danger.withValues(alpha: 0.6) : cyan.withValues(alpha: 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
              color: (ephemeral ? danger : cyan).withValues(alpha: 0.25),
              blurRadius: 16),
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
              ? danger.withValues(alpha: 0.7)
              : (isMine ? accent : cyan.withValues(alpha: 0.35)),
          width: 0.8,
        ),
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(top: BorderSide(color: cyan, width: 2)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent : Colors.transparent,
        border: Border.all(color: filled ? accent : cyan.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceSunken,
        border: Border.all(color: cyan.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: background),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.7),
            radius: 1.0,
            colors: [lime.withValues(alpha: 0.10), Colors.transparent],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, 0.8),
            radius: 1.0,
            colors: [accent.withValues(alpha: 0.10), Colors.transparent],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, 0.5),
            radius: 1.0,
            colors: [cyan.withValues(alpha: 0.10), Colors.transparent],
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
              danger.withValues(alpha: 0.45 * (1 - progress)),
              accent.withValues(alpha: 0.35 * (1 - progress)),
              cyan.withValues(alpha: 0.30 * (1 - progress)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) =>
      Icon(isPublic ? Icons.public : Icons.lock_outline, size: size, color: cyan);

  @override
  Widget hourglassIcon({double size = 16, Color? color}) =>
      Icon(Icons.hourglass_bottom, size: size, color: color ?? danger);

  @override
  Widget brandMark({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, cyan],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 12)],
      ),
      alignment: Alignment.center,
      child: Text('M',
          style: TextStyle(
            color: background,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            fontFamily: GoogleFonts.anta().fontFamily,
          )),
    );
  }

  // See AppTheme.iconMark — neon_night's brandMark fills with a gradient.
  @override
  Widget iconMark({double size = 28}) => brandMark(size: size);

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    final palette = [
      const Color(0xFFFFFF00),
      const Color(0xFF00FFE0),
      const Color(0xFF00FF66),
      const Color(0xFFFF00A2),
      const Color(0xFFA855F7),
    ];
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}
