import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

// The second wave of Characters: themes with a point of view that still keep
// the app's structure untouched. Each one carries its personality in exactly
// the places a person reads character — the display face, a texture under
// everything, the bubble's material, one accent — and leaves the list, the
// rows and the controls exactly where every other theme puts them.
//
// Textures are painted once: static painters that never repaint, behind a
// RepaintBoundary, so a scroll never pays for them.

// ─── Shared pieces ──────────────────────────────────────────────────────────

/// A static, seeded speckle — paper grain or a dot field. [shouldRepaint] is
/// always false: the pattern depends on nothing but its constructor.
class _StaticDotsPainter extends CustomPainter {
  const _StaticDotsPainter({
    required this.color,
    required this.grid,
    required this.radius,
    this.jitter = false,
    this.seed = 7,
    this.density = 1,
  });

  final Color color;

  /// Spacing between dots. With [jitter] each dot lands somewhere in its cell
  /// (grain); without, they sit on the grid (a dot matrix).
  final double grid;
  final double radius;
  final bool jitter;
  final int seed;

  /// Fraction of cells that get a dot — a grain is sparse, a grid is full.
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final paint = Paint()..color = color;
    final pts = <Offset>[];
    for (var y = grid / 2; y < size.height; y += grid) {
      for (var x = grid / 2; x < size.width; x += grid) {
        if (density < 1 && r.nextDouble() > density) continue;
        pts.add(
          jitter
              ? Offset(
                  x + (r.nextDouble() - 0.5) * grid,
                  y + (r.nextDouble() - 0.5) * grid,
                )
              : Offset(x, y),
        );
      }
    }
    // One drawPoints call for the whole field rather than a circle per dot.
    paint
      ..strokeWidth = radius * 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, pts, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The stroked 'M' every launcher mark here is built on, drawn as a path so
/// it renders identically with or without fonts (the icon generator runs
/// where custom families fall back to boxes).
Path _monogramPath(Size size, {double inset = 0.28, double dip = 0.10}) {
  final s = size.shortestSide;
  final c = Offset(size.width / 2, size.height / 2);
  final h = s * inset;
  return Path()
    ..moveTo(c.dx - h, c.dy + h)
    ..lineTo(c.dx - h, c.dy - h)
    ..lineTo(c.dx, c.dy + s * dip)
    ..lineTo(c.dx + h, c.dy - h)
    ..lineTo(c.dx + h, c.dy + h);
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.ink,
    this.stroke = 0.14,
    this.ring,
  });

  final Color ink;
  final double stroke;

  /// A thin inner ring, the rubber-stamp edge Paper's mark wears.
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (ring != null) {
      canvas.drawCircle(
        size.center(Offset.zero),
        s * 0.40,
        Paint()
          ..color = ring!
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025,
      );
    }
    canvas.drawPath(
      _monogramPath(size, inset: ring != null ? 0.2 : 0.28),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * (ring != null ? stroke * 0.75 : stroke)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.ink != ink || old.ring != ring || old.stroke != stroke;
}

/// Dot's mark: the 'M' as a 5×5 dot matrix, with one red dot — Nothing's
/// signature move — in the corner.
class _DotMarkPainter extends CustomPainter {
  const _DotMarkPainter({required this.ink, required this.signal});
  final Color ink;
  final Color signal;

  static const _m = [
    '1...1',
    '11.11',
    '1.1.1',
    '1...1',
    '1...1',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cell = s * 0.12;
    final origin = Offset(
      size.width / 2 - cell * 2,
      size.height / 2 - cell * 2,
    );
    final on = Paint()..color = ink;
    final off = Paint()..color = ink.withValues(alpha: 0.12);
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        canvas.drawCircle(
          origin + Offset(x * cell, y * cell),
          cell * 0.36,
          _m[y][x] == '1' ? on : off,
        );
      }
    }
    canvas.drawCircle(
      Offset(size.width - s * 0.2, s * 0.2),
      s * 0.055,
      Paint()..color = signal,
    );
  }

  @override
  bool shouldRepaint(covariant _DotMarkPainter old) =>
      old.ink != ink || old.signal != signal;
}

Color _pick(List<Color> palette, math.Random r) =>
    palette[r.nextInt(palette.length)];

// ─── Paper ──────────────────────────────────────────────────────────────────

/// Warm paper, a serif headline and a terracotta pencil — Things and a good
/// notebook. Calm enough to live in, with a grain you feel more than see.
class PaperTheme implements AppTheme {
  @override
  String get id => 'paper';
  @override
  String get name => 'Paper';
  @override
  String get tagline => 'Warm paper, a good pen.';
  @override
  ThemeMood get mood => ThemeMood.vault;
  @override
  List<Color> get swatch => [background, ink, accent];

  @override
  Color get background => const Color(0xFFF7F3EA);
  @override
  Color get surface => const Color(0xFFFFFDF8);
  @override
  Color get surfaceRaised => const Color(0xFFFFFDF8);
  @override
  Color get surfaceSunken => const Color(0xFFEDE6D8);
  @override
  Color get divider => const Color(0xFFE3DACA);
  @override
  Color get ink => const Color(0xFF2A2520);
  @override
  Color get inkSoft => const Color(0xFF6B6156);
  @override
  Color get inkMuted => const Color(0xFF8F8579);
  @override
  Color get accent => const Color(0xFFC2410C);
  @override
  Color get accentInk => const Color(0xFFFFFFFF);
  @override
  Color get accentSoft => accent.withValues(alpha: 0.12);
  @override
  Color get danger => const Color(0xFFB42318);
  @override
  Color get success => const Color(0xFF3F7D4E);

  TextStyle _serif(double size, {FontStyle? style, double? spacing}) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: style,
        letterSpacing: spacing ?? 0,
        height: 1.05,
        color: ink,
      );

  TextStyle _sans(double size, FontWeight w, Color c, {double? spacing}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing ?? -0.2,
        color: c,
      );

  @override
  TextStyle get displayHero => _serif(52, style: FontStyle.italic);
  @override
  TextStyle get displayLarge => _serif(40, spacing: -0.4);
  @override
  TextStyle get displayMedium => _serif(32, spacing: -0.2);
  @override
  TextStyle get displaySmall => _serif(24);
  @override
  TextStyle get body => _sans(16, FontWeight.w400, inkSoft);
  @override
  TextStyle get bodyEmph => _sans(16, FontWeight.w600, ink);
  @override
  TextStyle get bodySoft => _sans(15, FontWeight.w400, inkMuted);
  @override
  TextStyle get caption => _sans(13, FontWeight.w400, inkMuted);
  @override
  TextStyle get mono => _sans(13, FontWeight.w500, inkSoft)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  @override
  TextStyle get monoLarge => _serif(24)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  @override
  TextStyle get monoTiny => _sans(11, FontWeight.w600, inkMuted, spacing: 0.4);
  @override
  TextStyle get label => _sans(12, FontWeight.w600, inkSoft, spacing: 0.2);

  @override
  double get radiusSm => 6;
  @override
  double get radiusMd => 10;
  @override
  double get radiusLg => 14;
  @override
  double get radiusXl => 18;

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
  BoxDecoration roomCardDecoration({
    required bool ephemeral,
    required bool active,
  }) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(
          color: ephemeral ? accent.withValues(alpha: 0.45) : divider,
        ),
      );

  /// Theirs on white card stock with a pencil-thin edge; yours in the
  /// terracotta ink.
  @override
  BoxDecoration messageBubbleDecoration({
    required bool isMine,
    required bool ephemeral,
  }) =>
      BoxDecoration(
        color: isMine ? accent : surface,
        borderRadius: BorderRadius.circular(18),
        border: isMine
            ? null
            : Border.all(color: divider, width: 0.8),
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent : surfaceSunken,
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceSunken,
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) => SizedBox.expand(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _StaticDotsPainter(
              color: ink.withValues(alpha: 0.05),
              grid: 5,
              radius: 0.45,
              jitter: true,
              density: 0.35,
              seed: 31,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );

  @override
  Widget ephemeralSignature({required double progress}) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.18 * (1 - progress)),
                Colors.transparent,
              ],
            ),
          ),
        ),
      );

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) => Icon(
        isPublic ? CupertinoIcons.globe : CupertinoIcons.lock,
        size: size,
        color: inkSoft,
      );

  @override
  Widget hourglassIcon({double size = 16, Color? color}) => Icon(
        CupertinoIcons.hourglass,
        size: size,
        color: color ?? accent,
      );

  @override
  Widget brandMark({double size = 28}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(size * 0.225),
          border: Border.all(color: divider),
        ),
        child: CustomPaint(painter: _MarkPainter(ink: accent, ring: accent)),
      );

  @override
  Widget iconMark({double size = 28}) => Container(
        width: size,
        height: size,
        color: surface,
        child: CustomPaint(painter: _MarkPainter(ink: accent, ring: accent)),
      );

  static const _avatars = [
    Color(0xFF9C4A2F),
    Color(0xFF5E6B3A),
    Color(0xFF3F5E7A),
    Color(0xFF8A5A2B),
    Color(0xFF7A4E6E),
    Color(0xFF4F6F68),
  ];

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    return [_pick(_avatars, r), _pick(_avatars, r)];
  }
}

// ─── Dot ────────────────────────────────────────────────────────────────────

/// True black, a dot-matrix headline and one red signal — the Nothing school.
/// Everything is monochrome until something needs you.
class DotTheme implements AppTheme {
  @override
  String get id => 'dot';
  @override
  String get name => 'Dot';
  @override
  String get tagline => 'Black, white and one red dot.';
  @override
  ThemeMood get mood => ThemeMood.aurora;
  @override
  List<Color> get swatch => [background, ink, accent];

  @override
  Color get background => const Color(0xFF000000);
  @override
  Color get surface => const Color(0xFF111111);
  @override
  Color get surfaceRaised => const Color(0xFF1C1C1C);
  @override
  Color get surfaceSunken => const Color(0xFF0A0A0A);
  @override
  Color get divider => const Color(0x1FFFFFFF);
  @override
  Color get ink => const Color(0xFFF2F2F2);
  @override
  Color get inkSoft => const Color(0xFFA6A6A6);
  @override
  Color get inkMuted => const Color(0xFF6E6E6E);
  @override
  Color get accent => const Color(0xFFFF2E2E);
  @override
  Color get accentInk => const Color(0xFF000000);
  @override
  Color get accentSoft => accent.withValues(alpha: 0.16);
  @override
  Color get danger => const Color(0xFFFF453A);
  @override
  Color get success => const Color(0xFF30D158);

  TextStyle _dots(double size, {FontWeight w = FontWeight.w900}) =>
      GoogleFonts.doto(
        fontSize: size,
        fontWeight: w,
        letterSpacing: 0.5,
        height: 1.0,
        color: ink,
      );

  TextStyle _grotesk(double size, FontWeight w, Color c, {double? spacing}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing ?? -0.1,
        color: c,
      );

  @override
  TextStyle get displayHero => _dots(56);
  @override
  TextStyle get displayLarge => _dots(38);
  @override
  TextStyle get displayMedium => _dots(30);
  @override
  TextStyle get displaySmall => _grotesk(20, FontWeight.w600, ink);
  @override
  TextStyle get body => _grotesk(16, FontWeight.w400, inkSoft);
  @override
  TextStyle get bodyEmph => _grotesk(16, FontWeight.w600, ink);
  @override
  TextStyle get bodySoft => _grotesk(15, FontWeight.w400, inkMuted);
  @override
  TextStyle get caption => _grotesk(13, FontWeight.w500, inkMuted);
  @override
  TextStyle get mono => _grotesk(13, FontWeight.w500, inkSoft)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  @override
  TextStyle get monoLarge => _dots(22, w: FontWeight.w700);
  @override
  TextStyle get monoTiny =>
      _grotesk(11, FontWeight.w600, inkMuted, spacing: 0.8);
  @override
  TextStyle get label => _grotesk(12, FontWeight.w600, inkSoft, spacing: 0.6);

  @override
  double get radiusSm => 4;
  @override
  double get radiusMd => 8;
  @override
  double get radiusLg => 12;
  @override
  double get radiusXl => 18;

  @override
  Duration get motionFast => const Duration(milliseconds: 180);
  @override
  Duration get motionMed => const Duration(milliseconds: 340);
  @override
  Duration get motionSlow => const Duration(milliseconds: 620);
  @override
  Curve get motionCurve => Curves.easeOutQuart;
  @override
  Curve get motionEntrance => Curves.easeOutExpo;

  @override
  BoxDecoration roomCardDecoration({
    required bool ephemeral,
    required bool active,
  }) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusXl),
        border: ephemeral
            ? Border.all(color: accent.withValues(alpha: 0.5))
            : null,
      );

  /// Yours a white slab with black type — the brightest thing on a black
  /// screen, the way Nothing lets content be the only light.
  @override
  BoxDecoration messageBubbleDecoration({
    required bool isMine,
    required bool ephemeral,
  }) =>
      BoxDecoration(
        color: isMine ? ink : surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: ephemeral && !isMine
            ? Border.all(color: accent.withValues(alpha: 0.5))
            : null,
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? ink : surfaceRaised,
        borderRadius: BorderRadius.circular(999),
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surfaceRaised,
        borderRadius: BorderRadius.circular(radiusMd),
      );

  @override
  Widget backgroundLayer(BuildContext context) => SizedBox.expand(
        child: RepaintBoundary(
          child: ColoredBox(
            color: background,
            child: CustomPaint(
              painter: _StaticDotsPainter(
                color: ink.withValues(alpha: 0.07),
                grid: 16,
                radius: 0.9,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

  @override
  Widget ephemeralSignature({required double progress}) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.22 * (1 - progress)),
                Colors.transparent,
              ],
            ),
          ),
        ),
      );

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) => Icon(
        isPublic ? CupertinoIcons.circle_grid_3x3 : CupertinoIcons.lock_fill,
        size: size,
        color: inkSoft,
      );

  @override
  Widget hourglassIcon({double size = 16, Color? color}) => Icon(
        CupertinoIcons.timer,
        size: size,
        color: color ?? accent,
      );

  @override
  Widget brandMark({double size = 28}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.225),
          border: Border.all(color: divider),
        ),
        child: CustomPaint(painter: _DotMarkPainter(ink: ink, signal: accent)),
      );

  @override
  Widget iconMark({double size = 28}) => Container(
        width: size,
        height: size,
        color: background,
        child: CustomPaint(painter: _DotMarkPainter(ink: ink, signal: accent)),
      );

  // Greys, and one red in six: the signal colour stays rare enough to mean
  // something.
  static const _avatars = [
    Color(0xFF3D3D3D),
    Color(0xFF5A5A5A),
    Color(0xFF4A4A4A),
    Color(0xFF636363),
    Color(0xFF2E2E2E),
    Color(0xFFB3261E),
  ];

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    return [_pick(_avatars, r), _pick(_avatars, r)];
  }
}

// ─── Bloom ──────────────────────────────────────────────────────────────────

/// Blush, violet and a chunky, happy type — playful the way Duolingo is
/// playful: everything has a little weight under it and a little bounce in it.
class BloomTheme implements AppTheme {
  @override
  String get id => 'bloom';
  @override
  String get name => 'Bloom';
  @override
  String get tagline => 'Soft colours, a little bounce.';
  @override
  ThemeMood get mood => ThemeMood.riso;
  @override
  List<Color> get swatch => [background, accent, const Color(0xFFFF7AA8)];

  @override
  Color get background => const Color(0xFFFFF5F7);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceRaised => const Color(0xFFFFFFFF);
  @override
  Color get surfaceSunken => const Color(0xFFFFE4EC);
  @override
  Color get divider => const Color(0xFFF6D6E1);
  @override
  Color get ink => const Color(0xFF2B1430);
  @override
  Color get inkSoft => const Color(0xFF6E4A72);
  @override
  Color get inkMuted => const Color(0xFF8B6A8F);
  @override
  Color get accent => const Color(0xFF7C3AED);
  @override
  Color get accentInk => const Color(0xFFFFFFFF);
  @override
  Color get accentSoft => accent.withValues(alpha: 0.14);
  @override
  Color get danger => const Color(0xFFD12A5A);
  @override
  Color get success => const Color(0xFF15936A);

  /// The darker band a Bloom surface sits on — its "lip".
  Color get _accentLip => const Color(0xFF5B21B6);

  TextStyle _display(double size, {FontWeight w = FontWeight.w800}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: w,
        letterSpacing: -0.6,
        height: 1.05,
        color: ink,
      );

  TextStyle _round(double size, FontWeight w, Color c, {double? spacing}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing ?? 0,
        color: c,
      );

  @override
  TextStyle get displayHero => _display(54);
  @override
  TextStyle get displayLarge => _display(36);
  @override
  TextStyle get displayMedium => _display(28);
  @override
  TextStyle get displaySmall => _display(20, w: FontWeight.w700);
  @override
  TextStyle get body => _round(16, FontWeight.w400, inkSoft);
  @override
  TextStyle get bodyEmph => _round(17, FontWeight.w800, ink);
  @override
  TextStyle get bodySoft => _round(15, FontWeight.w600, inkMuted);
  @override
  TextStyle get caption => _round(13, FontWeight.w600, inkMuted);
  @override
  TextStyle get mono => _round(13, FontWeight.w700, inkSoft)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  @override
  TextStyle get monoLarge => _display(22, w: FontWeight.w700)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  @override
  TextStyle get monoTiny => _round(11, FontWeight.w800, inkMuted, spacing: 0.3);
  @override
  TextStyle get label => _round(12, FontWeight.w800, inkSoft, spacing: 0.2);

  @override
  double get radiusSm => 10;
  @override
  double get radiusMd => 16;
  @override
  double get radiusLg => 22;
  @override
  double get radiusXl => 26;

  @override
  Duration get motionFast => const Duration(milliseconds: 240);
  @override
  Duration get motionMed => const Duration(milliseconds: 460);
  @override
  Duration get motionSlow => const Duration(milliseconds: 760);
  @override
  Curve get motionCurve => Curves.easeOutBack;
  @override
  Curve get motionEntrance => Curves.easeOutBack;

  @override
  BoxDecoration roomCardDecoration({
    required bool ephemeral,
    required bool active,
  }) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusXl),
        boxShadow: [
          BoxShadow(
            color: ephemeral ? accent.withValues(alpha: 0.35) : divider,
            offset: const Offset(0, 3),
          ),
        ],
      );

  /// Every bubble stands on a solid lip a few points tall — the chunky,
  /// pressable look that makes the whole theme feel like a toy you can tap.
  @override
  BoxDecoration messageBubbleDecoration({
    required bool isMine,
    required bool ephemeral,
  }) =>
      BoxDecoration(
        color: isMine ? accent : surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isMine ? _accentLip : divider,
            offset: const Offset(0, 3),
          ),
        ],
      );

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      );

  @override
  BoxDecoration chipDecoration({bool filled = false}) => BoxDecoration(
        color: filled ? accent : surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: filled ? _accentLip : divider,
            offset: const Offset(0, 2),
          ),
        ],
      );

  @override
  BoxDecoration inputDecoration() => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: divider, width: 1.5),
      );

  @override
  Widget backgroundLayer(BuildContext context) => SizedBox.expand(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: background),
              // Two soft blooms, blush and lilac, fixed in place.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.9, -0.85),
                    radius: 0.9,
                    colors: [Color(0x8CFFD9E6), Color(0x00FFD9E6)],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(1.0, 0.7),
                    radius: 0.9,
                    colors: [Color(0x66E9DDFF), Color(0x00E9DDFF)],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget ephemeralSignature({required double progress}) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.2 * (1 - progress)),
                Colors.transparent,
              ],
            ),
          ),
        ),
      );

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) => Icon(
        isPublic ? CupertinoIcons.globe : CupertinoIcons.lock_fill,
        size: size,
        color: inkSoft,
      );

  @override
  Widget hourglassIcon({double size = 16, Color? color}) => Icon(
        CupertinoIcons.hourglass_bottomhalf_fill,
        size: size,
        color: color ?? accent,
      );

  @override
  Widget brandMark({double size = 28}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(color: _accentLip, offset: Offset(0, size * 0.08)),
          ],
        ),
        child: CustomPaint(
          painter: _MarkPainter(ink: accentInk, stroke: 0.16),
        ),
      );

  @override
  Widget iconMark({double size = 28}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF8B4DF5), accent],
          ),
        ),
        child: CustomPaint(
          painter: _MarkPainter(ink: accentInk, stroke: 0.16),
        ),
      );

  static const _avatars = [
    Color(0xFF7C3AED),
    Color(0xFFC0267A),
    Color(0xFF0E7C86),
    Color(0xFFB4530F),
    Color(0xFF4F46E5),
    Color(0xFF9D2BB0),
  ];

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    return [_pick(_avatars, r), _pick(_avatars, r)];
  }
}
