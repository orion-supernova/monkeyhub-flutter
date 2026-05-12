import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Port of v02's "Basic" theme — blue iOS-ish, dark variant.
class BasicTheme implements AppTheme {
  @override
  String get id => 'basic';
  @override
  String get name => 'Basic';
  @override
  String get tagline => 'clean. quiet. blue.';
  @override
  ThemeMood get mood => ThemeMood.vault; // dark mood family

  @override
  List<Color> get swatch => const [Color(0xFF0F1419), Color(0xFFFFFFFF), Color(0xFF007AFF)];

  @override
  Color get background => const Color(0xFF0B1118);
  @override
  Color get surface => const Color(0xFF131A24);
  @override
  Color get surfaceRaised => const Color(0xFF1A2230);
  @override
  Color get surfaceSunken => const Color(0xFF070B11);
  @override
  Color get divider => Colors.white.withValues(alpha: 0.08);

  @override
  Color get ink => Colors.white;
  @override
  Color get inkSoft => const Color(0xFFE2E7EE);
  @override
  Color get inkMuted => const Color(0xFF8693A4);

  @override
  Color get accent => const Color(0xFF007AFF);
  @override
  Color get accentInk => Colors.white;
  @override
  Color get accentSoft => const Color(0xFF007AFF).withValues(alpha: 0.16);
  @override
  Color get danger => const Color(0xFFFF3B30);
  @override
  Color get success => const Color(0xFF34C759);

  TextStyle _disp(double s, FontWeight w) => GoogleFonts.ibmPlexSans(
        fontSize: s,
        fontWeight: w,
        height: 1.1,
        letterSpacing: -0.5,
        color: ink,
      );
  TextStyle _mono(double s, [FontWeight w = FontWeight.w500]) =>
      GoogleFonts.ibmPlexMono(fontSize: s, fontWeight: w, height: 1.2, color: inkSoft);

  @override
  TextStyle get displayHero => _disp(64, FontWeight.w700).copyWith(letterSpacing: -1.5);
  @override
  TextStyle get displayLarge => _disp(34, FontWeight.w700);
  @override
  TextStyle get displayMedium => _disp(24, FontWeight.w600);
  @override
  TextStyle get displaySmall => _disp(18, FontWeight.w600);
  @override
  TextStyle get body => GoogleFonts.ibmPlexSans(
      fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, color: inkSoft);
  @override
  TextStyle get bodyEmph => GoogleFonts.ibmPlexSans(
      fontSize: 15, fontWeight: FontWeight.w600, height: 1.4, color: ink);
  @override
  TextStyle get bodySoft => GoogleFonts.ibmPlexSans(
      fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: inkMuted);
  @override
  TextStyle get caption => _mono(11).copyWith(letterSpacing: 1.2, color: inkMuted);
  @override
  TextStyle get mono => _mono(12, FontWeight.w400);
  @override
  TextStyle get monoLarge => _mono(16, FontWeight.w600).copyWith(color: ink);
  @override
  TextStyle get monoTiny => _mono(9, FontWeight.w600).copyWith(letterSpacing: 1.5, color: inkMuted);
  @override
  TextStyle get label => _mono(10, FontWeight.w600).copyWith(letterSpacing: 1.8, color: inkSoft);

  @override
  double get radiusSm => 6;
  @override
  double get radiusMd => 10;
  @override
  double get radiusLg => 14;
  @override
  double get radiusXl => 20;

  @override
  Duration get motionFast => const Duration(milliseconds: 220);
  @override
  Duration get motionMed => const Duration(milliseconds: 420);
  @override
  Duration get motionSlow => const Duration(milliseconds: 720);
  @override
  Curve get motionCurve => Curves.easeOutCubic;
  @override
  Curve get motionEntrance => Curves.easeOutQuart;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: ephemeral ? accent.withValues(alpha: 0.5) : divider, width: 1),
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
        border: ephemeral ? Border.all(color: accent.withValues(alpha: 0.4)) : null,
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: divider, width: 1)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent : Colors.transparent,
        border: Border.all(color: filled ? accent : divider, width: 1),
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceSunken,
        border: Border.all(color: divider),
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: background),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.10), Colors.transparent],
            stops: const [0.0, 0.35],
          ),
        ),
      ),
    ]);
  }

  @override
  Widget ephemeralSignature({required double progress}) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.4 * (1 - progress)),
                Colors.transparent,
              ],
            ),
          ),
        ),
      );

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) {
    return Icon(isPublic ? Icons.public : Icons.lock_outline, size: size, color: inkSoft);
  }

  @override
  Widget hourglassIcon({double size = 16, Color? color}) {
    return Icon(Icons.hourglass_bottom, size: size, color: color ?? accent);
  }

  @override
  Widget brandMark({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text('M',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w700,
            fontFamily: GoogleFonts.ibmPlexSans().fontFamily,
          )),
    );
  }

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    final palette = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFAF52DE),
      const Color(0xFF5856D6),
      const Color(0xFFFF2D55),
    ];
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}
