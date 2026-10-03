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
  String get tagline => 'Calm under pressure.';
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
  // Labels use Inter (warm clean sans) instead of IBM Plex Mono so the
  // calm Spectral display family isn't undercut by a code-y caption face.
  TextStyle _mono(double s, [FontWeight w = FontWeight.w500]) =>
      GoogleFonts.inter(fontSize: s, fontWeight: w, height: 1.2, color: inkSoft);

  @override
  // Upright: no Spectral italic is bundled, and with runtime fetching off an
  // italic request fails and falls back to the platform face.
  TextStyle get displayHero => _disp(64, FontWeight.w300).copyWith(letterSpacing: -1.5);
  @override
  TextStyle get displayLarge => _disp(34, FontWeight.w400);
  @override
  TextStyle get displayMedium => _disp(24, FontWeight.w400);
  @override
  TextStyle get displaySmall => _disp(18, FontWeight.w500);
  @override
  // Reading text is Inter; Spectral stays on the titles. A serif body beside
  // Inter captions made every row two typefaces at the same size, and the
  // italic emphasis asked for a Spectral italic the bundle doesn't carry.
  TextStyle get body => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w400, height: 1.45, letterSpacing: -0.1, color: inkSoft);
  @override
  TextStyle get bodyEmph => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w600, height: 1.45, letterSpacing: -0.1, color: ink);
  @override
  TextStyle get bodySoft => GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: -0.05, color: inkMuted);
  @override
  TextStyle get caption =>
      _mono(12, FontWeight.w500).copyWith(letterSpacing: 0.4, color: inkMuted);
  @override
  TextStyle get mono => _mono(13, FontWeight.w500);
  @override
  TextStyle get monoLarge => _mono(17, FontWeight.w600).copyWith(color: accent);
  @override
  TextStyle get monoTiny =>
      _mono(10, FontWeight.w600).copyWith(letterSpacing: 0.8, color: inkMuted);
  @override
  TextStyle get label =>
      _mono(11, FontWeight.w600).copyWith(letterSpacing: 0.6, color: accent);

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
        // A soft dark drop, not an accent glow pushed 8pt down: the teal
        // band that leaked out under each card read as a second card's edge.
        boxShadow: [
          BoxShadow(
              color: ephemeral
                  ? accent.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 6)),
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
    return const _OceanStatic();
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
      Icon(isPublic ? Icons.public : Icons.public_off, size: size, color: inkSoft);

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

  // See AppTheme.iconMark — deep_ocean's brandMark fills opaquely (gradient
  // circle). BrandIconCanvas's surface backdrop covers the corners.
  @override
  Widget iconMark({double size = 28}) => brandMark(size: size);

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    // Mid-depth sea hues: the old teal and sky blues held white initials at
    // 1.7–2.1:1, and #1A2980 sank into the background.
    final palette = [
      const Color(0xFF107F86),
      const Color(0xFF2B44B8),
      const Color(0xFF1C72B4),
      const Color(0xFF3A63D6),
      const Color(0xFF0D7F74),
      const Color(0xFF5458E0),
    ];
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}

/// Static ocean backdrop. Previously this was a `_OceanBackground` animated
/// `CustomPaint` re-running every frame with three `MaskFilter.blur(radius: 80)`
/// patches — that's the most expensive blur radius in the codebase and pinned
/// the GPU. The look is preserved as a `LinearGradient` base plus three
/// fullscreen `RadialGradient`s, all wrapped in a `RepaintBoundary` so it
/// never reinvalidates the rest of the tree.
class _OceanStatic extends StatelessWidget {
  const _OceanStatic();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A192F),
                  Color(0xFF0E2143),
                  Color(0xFF050E1C),
                ],
              ),
            ),
          ),
          _OceanGlow(
            center: Alignment(-0.5, -0.4),
            radius: 0.95,
            color: Color(0xFF26D0CE), // cyan
            peakAlpha: 0.26,
          ),
          _OceanGlow(
            center: Alignment(0.55, 0.1),
            radius: 1.05,
            color: Color(0xFF1A2980), // navy
            peakAlpha: 0.30,
          ),
          _OceanGlow(
            center: Alignment(0.0, 0.7),
            radius: 0.85,
            color: Color(0xFF38BDF8), // sky blue
            peakAlpha: 0.22,
          ),
        ],
      ),
    );
  }
}

class _OceanGlow extends StatelessWidget {
  const _OceanGlow({
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
