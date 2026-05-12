import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Palette-parameterized Vault theme — serif "private dossier" mood.
/// Variants:
///   - VaultNoirTheme.noir()  → dark, original (id 'vault_noir')
///   - VaultNoirTheme.ivory() → light parchment       (id 'vault_ivory')
class VaultNoirTheme implements AppTheme {
  VaultNoirTheme._(this._p);

  factory VaultNoirTheme() => VaultNoirTheme._(_noir);
  factory VaultNoirTheme.noir() => VaultNoirTheme._(_noir);
  factory VaultNoirTheme.ivory() => VaultNoirTheme._(_ivory);

  final _VaultPalette _p;

  @override
  String get id => _p.id;
  @override
  String get name => _p.name;
  @override
  String get tagline => _p.tagline;
  @override
  ThemeMood get mood => ThemeMood.vault;

  @override
  List<Color> get swatch => [_p.background, _p.ink, _p.accent];

  @override
  Color get background => _p.background;
  @override
  Color get surface => _p.surface;
  @override
  Color get surfaceRaised => _p.surfaceRaised;
  @override
  Color get surfaceSunken => _p.surfaceSunken;
  @override
  Color get divider => _p.divider;

  @override
  Color get ink => _p.ink;
  @override
  Color get inkSoft => _p.inkSoft;
  @override
  Color get inkMuted => _p.inkMuted;

  @override
  Color get accent => _p.accent;
  @override
  Color get accentInk => _p.accentInk;
  @override
  Color get accentSoft => _p.accent.withValues(alpha: 0.12);
  @override
  Color get danger => _p.danger;
  @override
  Color get success => _p.success;

  @override
  TextStyle get displayHero => GoogleFonts.cormorant(
        fontSize: 64,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.0,
        letterSpacing: -1.5,
        color: ink,
      );
  @override
  TextStyle get displayLarge => GoogleFonts.cormorant(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 1.05,
        letterSpacing: -0.5,
        color: ink,
      );
  @override
  TextStyle get displayMedium => GoogleFonts.cormorant(
        fontSize: 26,
        fontWeight: FontWeight.w500,
        height: 1.1,
        letterSpacing: -0.3,
        color: ink,
      );
  @override
  TextStyle get displaySmall => GoogleFonts.cormorant(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.15,
        color: ink,
      );
  @override
  TextStyle get body => GoogleFonts.cormorantInfant(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: inkSoft,
      );
  @override
  TextStyle get bodyEmph => GoogleFonts.cormorant(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        height: 1.4,
        color: ink,
      );
  @override
  TextStyle get bodySoft => GoogleFonts.cormorantInfant(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: inkMuted,
      );
  @override
  TextStyle get caption => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: inkSoft,
      );
  @override
  TextStyle get monoLarge => GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: ink,
      );
  @override
  TextStyle get monoTiny => GoogleFonts.jetBrainsMono(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        height: 1.2,
        color: inkMuted,
      );
  @override
  TextStyle get label => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.8,
        height: 1.2,
        color: inkSoft,
      );

  @override
  double get radiusSm => 4;
  @override
  double get radiusMd => 8;
  @override
  double get radiusLg => 12;
  @override
  double get radiusXl => 16;

  @override
  Duration get motionFast => const Duration(milliseconds: 240);
  @override
  Duration get motionMed => const Duration(milliseconds: 520);
  @override
  Duration get motionSlow => const Duration(milliseconds: 820);
  @override
  Curve get motionCurve => Curves.easeOutExpo;
  @override
  Curve get motionEntrance => Curves.easeOutQuart;

  @override
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) {
    return BoxDecoration(
      color: active ? surfaceRaised : surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: ephemeral
          ? Border.all(color: accent.withValues(alpha: 0.45), width: 1, strokeAlign: BorderSide.strokeAlignInside)
          : Border.all(color: divider, width: 1),
      boxShadow: [
        BoxShadow(
          color: _p.shadowColor,
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
      ],
    );
  }

  @override
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral}) {
    return BoxDecoration(
      color: isMine ? accent.withValues(alpha: 0.92) : surfaceRaised,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radiusLg),
        topRight: Radius.circular(radiusLg),
        bottomLeft: Radius.circular(isMine ? radiusLg : radiusSm),
        bottomRight: Radius.circular(isMine ? radiusSm : radiusLg),
      ),
      border: ephemeral
          ? Border.all(color: (isMine ? ink : accent).withValues(alpha: 0.5), width: 0.8)
          : Border.all(color: divider, width: 0.6),
    );
  }

  @override
  BoxDecoration sheetDecoration() => BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.35), width: 2)),
        boxShadow: [
          BoxShadow(color: _p.shadowColor, blurRadius: 48, offset: const Offset(0, -16)),
        ],
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
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: background),
        // Soft vertical vignette
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.6),
              radius: 1.2,
              colors: [
                accent.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Procedural grain
        IgnorePointer(
          child: CustomPaint(
            painter: _GrainPainter(seed: 7, color: _p.grainColor),
          ),
        ),
      ],
    );
  }

  @override
  Widget ephemeralSignature({required double progress}) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SmokeStreakPainter(progress: progress, color: ink.withValues(alpha: 0.55)),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget visibilityIcon({required bool isPublic, double size = 14}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _VaultVisibilityPainter(isPublic: isPublic, color: inkSoft),
    );
  }

  @override
  Widget hourglassIcon({double size = 16, Color? color}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _HourglassPainter(color: color ?? accent),
    );
  }

  @override
  Widget brandMark({double size = 28}) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WaxSealPainter(color: accent, ink: ink),
    );
  }

  @override
  List<Color> avatarGradient(int seed) {
    final rand = math.Random(seed);
    final tones = _p.avatarPalette;
    final a = tones[rand.nextInt(tones.length)];
    final b = tones[rand.nextInt(tones.length)];
    return [a, b];
  }
}

/// Swappable colour tokens for a Vault variant. Typography, geometry,
/// motion, and decorative painters (wax seal, hourglass, grain) are
/// shared across all variants.
class _VaultPalette {
  const _VaultPalette({
    required this.id,
    required this.name,
    required this.tagline,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.divider,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.accent,
    required this.accentInk,
    required this.danger,
    required this.success,
    required this.shadowColor,
    required this.grainColor,
    required this.avatarPalette,
  });

  final String id;
  final String name;
  final String tagline;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color divider;
  final Color ink;
  final Color inkSoft;
  final Color inkMuted;
  final Color accent;
  final Color accentInk;
  final Color danger;
  final Color success;
  final Color shadowColor;
  final Color grainColor;
  final List<Color> avatarPalette;
}

const _noir = _VaultPalette(
  id: 'vault_noir',
  name: 'Vault Noir',
  tagline: 'a private dossier',
  background: Color(0xFF0A0A0B),
  surface: Color(0xFF131318),
  surfaceRaised: Color(0xFF1C1C22),
  surfaceSunken: Color(0xFF06060A),
  divider: Color(0x14F4F1EA), // ink @ 8%
  ink: Color(0xFFF4F1EA),
  inkSoft: Color(0xFFD9D4C5),
  inkMuted: Color(0xFF8A857A),
  accent: Color(0xFFD63B2A),
  accentInk: Color(0xFFF4F1EA),
  danger: Color(0xFFD63B2A),
  success: Color(0xFF7DA17A),
  shadowColor: Color(0x99000000),
  grainColor: Color(0x0FF4F1EA), // bone @ ~6% for visible texture on dark
  avatarPalette: [
    Color(0xFFD63B2A),
    Color(0xFFE9B872),
    Color(0xFF6B8E5A),
    Color(0xFFA88B6E),
    Color(0xFF8A857A),
    Color(0xFFB0492D),
  ],
);

const _ivory = _VaultPalette(
  id: 'vault_ivory',
  name: 'Vault Ivory',
  tagline: 'an open dossier',
  background: Color(0xFFF7F1E6),
  surface: Color(0xFFFFFAEF),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFEDE5D2),
  divider: Color(0x1A000000), // black @ 10%
  ink: Color(0xFF1A1209),
  inkSoft: Color(0xFF3F3328),
  inkMuted: Color(0xFF7A6B5A),
  accent: Color(0xFFD63B2A),
  accentInk: Color(0xFFFFFAEF),
  danger: Color(0xFFA1281A),
  success: Color(0xFF5F8458),
  shadowColor: Color(0x141A1209), // ink @ ~8%, subtle on parchment
  grainColor: Color(0x0F1A1209), // dark coffee @ ~6% for texture on light
  avatarPalette: [
    Color(0xFFD63B2A),
    Color(0xFFB0492D),
    Color(0xFFA88B6E),
    Color(0xFF6B8E5A),
    Color(0xFF8A6E48),
    Color(0xFFC58B4A),
  ],
);

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.seed, required this.color});
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final paint = Paint();
    final count = (size.width * size.height / 220).clamp(200, 4000).toInt();
    for (var i = 0; i < count; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      paint.color = color.withValues(alpha: rand.nextDouble() * color.a);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

class _SmokeStreakPainter extends CustomPainter {
  _SmokeStreakPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final xJitter = (rand.nextDouble() - 0.5) * size.width * 0.6;
      final phase = (rand.nextDouble() + progress * 1.4) % 1.0;
      final yOff = -phase * size.height * 1.4;
      final cx = size.width / 2 + xJitter * progress;
      final cy = size.height + yOff;
      final r = (4 + rand.nextDouble() * 8) * (1 + progress * 1.2);
      final a = (1 - phase) * 0.18 * (1 - progress).clamp(0, 1);
      p.color = color.withValues(alpha: a);
      canvas.drawCircle(Offset(cx, cy), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokeStreakPainter oldDelegate) => oldDelegate.progress != progress;
}

class _VaultVisibilityPainter extends CustomPainter {
  _VaultVisibilityPainter({required this.isPublic, required this.color});
  final bool isPublic;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final c = Offset(size.width / 2, size.height / 2);
    if (isPublic) {
      // Eye
      final w = size.width * 0.84;
      final h = size.height * 0.5;
      final path = Path()
        ..moveTo(c.dx - w / 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy - h, c.dx + w / 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy + h, c.dx - w / 2, c.dy);
      canvas.drawPath(path, p);
      canvas.drawCircle(c, size.width * 0.14, p);
    } else {
      // Padlock
      final r = Rect.fromCenter(center: Offset(c.dx, c.dy + size.height * 0.15), width: size.width * 0.7, height: size.height * 0.55);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), p);
      // shackle
      final shackle = Path()
        ..moveTo(c.dx - size.width * 0.22, c.dy - size.height * 0.12)
        ..quadraticBezierTo(c.dx, c.dy - size.height * 0.65, c.dx + size.width * 0.22, c.dy - size.height * 0.12);
      canvas.drawPath(shackle, p);
    }
  }

  @override
  bool shouldRepaint(covariant _VaultVisibilityPainter oldDelegate) =>
      oldDelegate.isPublic != isPublic || oldDelegate.color != color;
}

class _HourglassPainter extends CustomPainter {
  _HourglassPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final pad = size.width * 0.18;
    final path = Path()
      ..moveTo(pad, pad)
      ..lineTo(size.width - pad, pad)
      ..lineTo(pad, size.height - pad)
      ..lineTo(size.width - pad, size.height - pad)
      ..close();
    canvas.drawPath(path, p);
    // Top caps
    canvas.drawLine(Offset(pad - 1, pad), Offset(size.width - pad + 1, pad), p);
    canvas.drawLine(Offset(pad - 1, size.height - pad), Offset(size.width - pad + 1, size.height - pad), p);
  }

  @override
  bool shouldRepaint(covariant _HourglassPainter oldDelegate) => oldDelegate.color != color;
}

class _WaxSealPainter extends CustomPainter {
  _WaxSealPainter({required this.color, required this.ink});
  final Color color;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    // Wax circle with notched edges
    final path = Path();
    const segs = 16;
    for (var i = 0; i < segs; i++) {
      final t = i / segs;
      final angle = t * math.pi * 2;
      final wave = (i.isEven ? 0.0 : -1.2);
      final radius = r + wave;
      final x = c.dx + math.cos(angle) * radius;
      final y = c.dy + math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()
      ..color = ink.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);
    // Letter M monogram (simple geometric)
    final mPaint = Paint()
      ..color = ink.withValues(alpha: 0.9)
      ..strokeWidth = size.width * 0.07
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final mPath = Path()
      ..moveTo(c.dx - r * 0.4, c.dy + r * 0.35)
      ..lineTo(c.dx - r * 0.4, c.dy - r * 0.35)
      ..lineTo(c.dx, c.dy + r * 0.1)
      ..lineTo(c.dx + r * 0.4, c.dy - r * 0.35)
      ..lineTo(c.dx + r * 0.4, c.dy + r * 0.35);
    canvas.drawPath(mPath, mPaint);
  }

  @override
  bool shouldRepaint(covariant _WaxSealPainter oldDelegate) => false;
}
