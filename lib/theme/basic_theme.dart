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
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active}) =>
      BoxDecoration(
        color: active ? surfaceRaised : surface,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(
          color: ephemeral ? accent.withValues(alpha: 0.5) : divider,
          width: ephemeral ? 1 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );

  @override
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral}) =>
      BoxDecoration(
        color: isMine ? accent : surfaceRaised,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMine ? 20 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 20),
        ),
        border: ephemeral ? Border.all(color: accent.withValues(alpha: 0.4)) : null,
        boxShadow: isMine
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
  List<Color> avatarGradient(int seed) {
    final r = math.Random(seed);
    final palette = _p.avatarPalette;
    return [palette[r.nextInt(palette.length)], palette[r.nextInt(palette.length)]];
  }
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
}

// ─── Palettes ────────────────────────────────────────────────────────────

const _midnight = _BasicPalette(
  id: 'basic',
  name: 'Midnight',
  tagline: 'clean. quiet. blue.',
  background: Color(0xFF0B1118),
  surface: Color(0xFF131A24),
  surfaceRaised: Color(0xFF1A2230),
  surfaceSunken: Color(0xFF070B11),
  divider: Color(0x14FFFFFF), // white @ ~8%
  ink: Color(0xFFFFFFFF),
  inkSoft: Color(0xFFE2E7EE),
  inkMuted: Color(0xFF8693A4),
  accent: Color(0xFF007AFF),
  accentInk: Color(0xFFFFFFFF),
  danger: Color(0xFFFF3B30),
  success: Color(0xFF34C759),
  avatarPalette: [
    Color(0xFF007AFF),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFAF52DE),
    Color(0xFF5856D6),
    Color(0xFFFF2D55),
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
  inkMuted: Color(0xFF8E8E93),
  accent: Color(0xFF007AFF),
  accentInk: Color(0xFFFFFFFF),
  danger: Color(0xFFFF3B30),
  success: Color(0xFF34C759),
  avatarPalette: [
    Color(0xFF007AFF),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFAF52DE),
    Color(0xFF5856D6),
    Color(0xFFFF2D55),
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
  avatarPalette: [
    Color(0xFF8E8E93),
    Color(0xFFAEAEB2),
    Color(0xFFC7C7CC),
    Color(0xFF636366),
    Color(0xFF48484A),
    Color(0xFFE5E5E5),
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
  accent: Color(0xFFE85A8C),
  accentInk: Color(0xFFFFFFFF),
  danger: Color(0xFFCC2D44),
  success: Color(0xFF389C5C),
  avatarPalette: [
    Color(0xFFE85A8C),
    Color(0xFFFFB2A8),
    Color(0xFFF99488),
    Color(0xFFC56C9E),
    Color(0xFFFFC1D0),
    Color(0xFFB85970),
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
  avatarPalette: [
    Color(0xFF9BBF7C),
    Color(0xFF6E8B5C),
    Color(0xFFB7CC9C),
    Color(0xFF4F6A45),
    Color(0xFFD2A878),
    Color(0xFF8FA890),
  ],
);
