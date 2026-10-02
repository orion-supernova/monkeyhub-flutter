import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Palette-parameterized "Basic" theme — iOS-native typography (SF Pro on
/// Apple platforms via Flutter's Cupertino system-font families, Roboto on
/// Android) with swappable color palettes (Midnight, Daylight, Graphite,
/// Rose, Forest). Each variant is its own entry in the theme picker; pick
/// via the named factory constructors.
class BasicTheme implements AppTheme {
  BasicTheme._(this._p);

  /// Backwards-compat default — the original dark navy + iOS-blue look.
  factory BasicTheme() => BasicTheme._(_midnight);
  factory BasicTheme.midnight() => BasicTheme._(_midnight);
  factory BasicTheme.daylight() => BasicTheme._(_daylight);
  factory BasicTheme.graphite() => BasicTheme._(_graphite);
  factory BasicTheme.rose() => BasicTheme._(_rose);
  factory BasicTheme.forest() => BasicTheme._(_forest);

  final _BasicPalette _p;

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
  Color get accentSoft => _p.accent.withValues(alpha: 0.16);
  @override
  Color get danger => _p.danger;
  @override
  Color get success => _p.success;

  // Values mirror Flutter's framework-blessed CupertinoTextThemeData
  // defaults — `CupertinoSystemText`/`CupertinoSystemDisplay` font
  // families, framework tracking conventions (-0.41 for text sizes,
  // +0.38 for display sizes). We construct fresh TextStyles instead of
  // delegating to CupertinoTextThemeData because its styles ship with
  // `inherit: false`, which Material widgets like TextField reject.
  static const String _kText = 'CupertinoSystemText';
  static const String _kDisplay = 'CupertinoSystemDisplay';

  @override
  TextStyle get displayHero => TextStyle(
        fontFamily: _kDisplay,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.38,
        color: ink,
      );
  @override
  TextStyle get displayLarge => TextStyle(
        fontFamily: _kDisplay,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.38,
        color: ink,
      );
  @override
  TextStyle get displayMedium => TextStyle(
        fontFamily: _kDisplay,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.38,
        color: ink,
      );
  @override
  TextStyle get displaySmall => TextStyle(
        fontFamily: _kDisplay,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.38,
        color: ink,
      );
  @override
  TextStyle get body => TextStyle(
        fontFamily: _kText,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        color: inkSoft,
      );
  @override
  TextStyle get bodyEmph => TextStyle(
        fontFamily: _kText,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: ink,
      );
  @override
  TextStyle get bodySoft => TextStyle(
        fontFamily: _kText,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        color: inkMuted,
      );
  @override
  TextStyle get caption => TextStyle(
        fontFamily: _kText,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        color: inkMuted,
      );
  // `label` and `monoTiny` are all-caps section headers ("BASIC",
  // "CONVERSATION", "ACTIVE") — wide positive tracking is a design
  // intent, kept on purpose.
  @override
  TextStyle get label => TextStyle(
        fontFamily: _kText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: inkSoft,
      );
  @override
  TextStyle get monoTiny => TextStyle(
        fontFamily: _kText,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: inkMuted,
      );
  // "mono" slots stay on the proportional system face with tabular figures
  // — iOS uses tabular SF for tickers/timers, not SF Mono.
  @override
  TextStyle get mono => TextStyle(
        fontFamily: _kText,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.41,
        color: inkSoft,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  @override
  TextStyle get monoLarge => TextStyle(
        fontFamily: _kDisplay,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.38,
        color: ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

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
  // Flat: a fill and a hairline, nothing under it. The soft offset shadow
  // this used to cast drew a grey lip along every card's bottom edge on the
  // light palettes — the Material elevated card, which is the look this
  // family exists to avoid.
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(
          color: ephemeral ? accent.withValues(alpha: 0.5) : divider,
          width: ephemeral ? 1 : 0.5,
        ),
      );

  @override
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral}) =>
      BoxDecoration(
        color: isMine ? (_p.bubble ?? accent) : surfaceRaised,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMine ? 20 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 20),
        ),
        border: ephemeral ? Border.all(color: accent.withValues(alpha: 0.4)) : null,
        // Flat, the way Messages draws them. A coloured glow under every
        // outgoing bubble is what made a busy transcript look like a stack
        // of buttons.
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
    // Flat. The accent wash this used to lay over the top third tinted every
    // header the theme's colour — on Midnight a blue haze behind the title,
    // which is the single most Android thing the screen did. iOS lets the
    // content and the glass carry colour, never the page.
    //
    // Expanded explicitly: callers drop this into an unpositioned Stack slot,
    // where a childless ColoredBox sizes itself to nothing.
    return SizedBox.expand(child: ColoredBox(color: background));
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
    return Icon(isPublic ? Icons.public : Icons.public_off, size: size, color: inkSoft);
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
        borderRadius: BorderRadius.circular(size * 0.225),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'M',
        style: TextStyle(
          fontFamily: _kDisplay,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.0,
          color: accentInk,
        ),
      ),
    );
  }

  @override
  Widget iconMark({double size = 28}) {
    // Edge-to-edge launcher-icon variant. Three things going on:
    //
    // 1. No internal `borderRadius`/`boxShadow` — the bg colour fills every
    //    pixel of the [size]×[size] square so iOS/Android can apply their
    //    own corner masks (squircle / adaptive icon) without revealing a
    //    surface-coloured "frame" inside the platform mask.
    //
    // 2. The 'M' glyph is drawn as a geometric path instead of `Text`.
    //    The brandMark uses `fontFamily: 'CupertinoSystemDisplay'`, which
    //    iOS maps to SF Pro Display at runtime but `flutter_test` (the
    //    launcher-PNG generator) doesn't know — it falls back to "Ahem",
    //    which renders every glyph as a solid square. Painting the M makes
    //    launcher PNG and in-app preview identical.
    //
    // 3. Light-surface palettes (Daylight, Rose) use `surface` as the icon
    //    bg and `accent` as the M colour; dark-surface palettes use
    //    `accent` as bg and `accentInk` as the M colour. Without this,
    //    midnight and daylight produce identical PNGs (same accent + same
    //    accentInk) — switching between them changes nothing visible on the
    //    home screen. The luminance branch keeps each variant distinct AND
    //    keeps each one high-contrast.
    final lightTheme = _p.surface.computeLuminance() > 0.5;
    final bg = lightTheme ? _p.surface : _p.accent;
    final fg = lightTheme ? _p.accent : _p.accentInk;
    return Container(
      width: size,
      height: size,
      color: bg,
      child: CustomPaint(painter: _BasicMonogramPainter(color: fg)),
    );
  }

  @override
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    final palette = _p.avatarPalette;
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
}

/// Draws a chunky uppercase 'M' as a stroked path so the icon doesn't depend
/// on a font being available at render time (the launcher-icon generator runs
/// under flutter_test where unknown font families fall back to Ahem — solid
/// squares). The geometry mirrors the proportions of the SF Pro Display 'M'
/// the in-app brandMark uses at small sizes.
class _BasicMonogramPainter extends CustomPainter {
  _BasicMonogramPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    // Place the M in the central 56% of the icon — leaves comfortable
    // breathing room inside the iOS squircle mask.
    final halfW = s * 0.28;
    final halfH = s * 0.28;
    final dip = s * 0.10;

    final path = Path()
      ..moveTo(c.dx - halfW, c.dy + halfH)
      ..lineTo(c.dx - halfW, c.dy - halfH)
      ..lineTo(c.dx, c.dy + dip)
      ..lineTo(c.dx + halfW, c.dy - halfH)
      ..lineTo(c.dx + halfW, c.dy + halfH);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BasicMonogramPainter old) => old.color != color;
}

/// All swappable colour tokens for a Basic variant. Typography, geometry,
/// motion, and shape are shared across every variant.
class _BasicPalette {
  const _BasicPalette({
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
    required this.avatarPalette,
    this.bubble,
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
  final List<Color> avatarPalette;

  /// Fill of the viewer's own bubbles, when it is not simply [accent]. A
  /// bright accent that reads well as text is usually too light to carry
  /// white text as a fill.
  final Color? bubble;
}

// ─── Palettes ────────────────────────────────────────────────────────────

// Near-black with a temperature, not navy. The old #0B1118 put its blue in
// the SURFACES, and saturated blue-grey elevation is the Material dark look;
// here the blue is a 3–5 unit lift in the B channel you sense rather than see,
// and the steps follow iOS's black → #1C1C1E → #2C2C2E rhythm a shade deeper
// so glass bars separate cleanly from what scrolls under them.
//
// The accent and the outgoing bubble are split on purpose. #3D80F2 is the
// balance point for a token that is both TEXT on the page (5.2:1) and a FILL
// under white (unread pips, 3.8:1) — on a near-black page no single blue
// reaches 4.5 on both, so the pip, bold 13pt, takes the large-text floor.
// The bubble is the deeper #2F6BE8 so white message text clears AA.
const _midnight = _BasicPalette(
  id: 'basic',
  name: 'Midnight',
  tagline: 'clean. quiet. blue.',
  background: Color(0xFF0A0B0F),
  surface: Color(0xFF15171D),
  surfaceRaised: Color(0xFF1F222A),
  surfaceSunken: Color(0xFF050608),
  divider: Color(0x12FFFFFF), // white @ 7%
  ink: Color(0xFFF3F5F9),
  inkSoft: Color(0xFFA3A9B6),
  inkMuted: Color(0xFF7C8089),
  accent: Color(0xFF3D80F2),
  accentInk: Color(0xFFFFFFFF),
  bubble: Color(0xFF2F6BE8),
  danger: Color(0xFFFF3B30),
  success: Color(0xFF34C759),
  // Deep enough that a white initial clears 3:1 even at the gradient's lit top.
  avatarPalette: [
    Color(0xFF0079FC),
    Color(0xFF248B3E),
    Color(0xFFB26800),
    Color(0xFFAD51DC),
    Color(0xFF5856D6),
    Color(0xFFFC2D54),
  ],
);

const _daylight = _BasicPalette(
  id: 'basic_daylight',
  name: 'Daylight',
  tagline: 'iOS, in the morning.',
  background: Color(0xFFF2F2F7),
  surface: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFE5E5EA),
  divider: Color(0x14000000), // black @ ~8%
  ink: Color(0xFF000000),
  inkSoft: Color(0xFF3C3C43),
  inkMuted: Color(0xFF737378),
  accent: Color(0xFF0064D2),
  accentInk: Color(0xFFFFFFFF),
  danger: Color(0xFFFF3B30),
  success: Color(0xFF34C759),
  // Deep enough that a white initial clears 3:1 even at the gradient's lit top.
  avatarPalette: [
    Color(0xFF0079FC),
    Color(0xFF248B3E),
    Color(0xFFB26800),
    Color(0xFFAD51DC),
    Color(0xFF5856D6),
    Color(0xFFFC2D54),
  ],
);

const _graphite = _BasicPalette(
  id: 'basic_graphite',
  name: 'Graphite',
  tagline: 'monochrome. minimal.',
  background: Color(0xFF111111),
  surface: Color(0xFF1A1A1A),
  surfaceRaised: Color(0xFF252525),
  surfaceSunken: Color(0xFF080808),
  divider: Color(0x1AFFFFFF), // white @ 10%
  ink: Color(0xFFFFFFFF),
  inkSoft: Color(0xFFD4D4D4),
  inkMuted: Color(0xFF8E8E93),
  accent: Color(0xFFE5E5E5),
  accentInk: Color(0xFF111111),
  danger: Color(0xFFFF453A),
  success: Color(0xFF30D158),
  bubble: Color(0xFFD1D1D6),
  // Mid-tone neutrals, two with a faint cool/warm cast so a column of them isn't one grey. Deep enough that a white initial clears 3:1 even at the gradient's lit top.
  avatarPalette: [
    Color(0xFF636366),
    Color(0xFF48484A),
    Color(0xFF76767A),
    Color(0xFF5A5F6B),
    Color(0xFF6B625A),
    Color(0xFF4A4F57),
  ],
);

const _rose = _BasicPalette(
  id: 'basic_rose',
  name: 'Rose',
  tagline: 'warm. soft. a flush.',
  background: Color(0xFFFFF5F2),
  surface: Color(0xFFFFFCFA),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFFFE9E0),
  divider: Color(0xFFE8D8D0),
  ink: Color(0xFF1F0F0F),
  inkSoft: Color(0xFF4A2929),
  inkMuted: Color(0xFF8B6C6C),
  accent: Color(0xFFC2386E),
  accentInk: Color(0xFFFFFFFF),
  danger: Color(0xFFCC2D44),
  success: Color(0xFF389C5C),
  // Deep enough that a white initial clears 3:1 even at the gradient's lit top.
  avatarPalette: [
    Color(0xFFC2386E),
    Color(0xFFC15862),
    Color(0xFFB3507E),
    Color(0xFFA8485A),
    Color(0xFFB56048),
    Color(0xFF8E4A6E),
  ],
);

const _forest = _BasicPalette(
  id: 'basic_forest',
  name: 'Forest',
  tagline: 'moss. quiet. trees.',
  background: Color(0xFF101A12),
  surface: Color(0xFF152419),
  surfaceRaised: Color(0xFF1E3022),
  surfaceSunken: Color(0xFF0A1109),
  divider: Color(0x1AFFFFFF), // white @ 10%
  ink: Color(0xFFE9F0E5),
  inkSoft: Color(0xFFB8C5B0),
  inkMuted: Color(0xFF7C8B75),
  accent: Color(0xFF9BBF7C),
  accentInk: Color(0xFF0A1109),
  danger: Color(0xFFC8615A),
  success: Color(0xFF9BBF7C),
  // Deep enough that a white initial clears 3:1 even at the gradient's lit top.
  avatarPalette: [
    Color(0xFF598342),
    Color(0xFF4F6A45),
    Color(0xFF6B7E41),
    Color(0xFF3F6A5A),
    Color(0xFF957145),
    Color(0xFF5F7A68),
  ],
);
