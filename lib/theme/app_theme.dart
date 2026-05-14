import 'package:flutter/material.dart';

enum ThemeMood { vault, riso, aurora }

abstract class AppTheme {
  String get id;
  String get name;
  String get tagline;
  ThemeMood get mood;

  // Palette swatches (for the theme chip)
  List<Color> get swatch;

  // Surfaces
  Color get background;
  Color get surface;
  Color get surfaceRaised;
  Color get surfaceSunken;
  Color get divider;

  // Ink
  Color get ink;
  Color get inkSoft;
  Color get inkMuted;

  // Accents
  Color get accent;
  Color get accentInk;
  Color get accentSoft;
  Color get danger;
  Color get success;

  // Typography
  TextStyle get displayHero;
  TextStyle get displayLarge;
  TextStyle get displayMedium;
  TextStyle get displaySmall;
  TextStyle get body;
  TextStyle get bodyEmph;
  TextStyle get bodySoft;
  TextStyle get caption;
  TextStyle get mono;
  TextStyle get monoLarge;
  TextStyle get monoTiny;
  TextStyle get label;

  // Geometry
  double get radiusSm;
  double get radiusMd;
  double get radiusLg;
  double get radiusXl;

  // Motion
  Duration get motionFast;
  Duration get motionMed;
  Duration get motionSlow;
  Curve get motionCurve;
  Curve get motionEntrance;

  // Decorations
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active});
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral});
  BoxDecoration sheetDecoration();
  BoxDecoration chipDecoration({bool filled = false});
  BoxDecoration inputDecoration();

  // Composable widgets
  Widget backgroundLayer(BuildContext context);
  Widget ephemeralSignature({required double progress}); // 0 = fresh, 1 = expired
  Widget visibilityIcon({required bool isPublic, double size = 14});
  Widget hourglassIcon({double size = 16, Color? color});
  Widget brandMark({double size = 28});

  /// Same identity as [brandMark] but optimised for app-icon rendering: the
  /// drawing must fill the [size]×[size] square edge-to-edge with opaque
  /// pixels (no internal `borderRadius`, no shadow that depends on
  /// surrounding space). Used by `BrandIconCanvas` for the launcher PNG and
  /// the picker tile so both surfaces show identical content; the platform
  /// (iOS squircle mask, Android adaptive icon mask) applies the rounding.
  ///
  /// Default: forward to [brandMark]. Themes whose [brandMark] inset their
  /// content (e.g. a rounded button inside a square) should override this to
  /// return an edge-to-edge variant.
  Widget iconMark({double size = 28}) => brandMark(size: size);

  // Avatar gradient seeds (theme controls palette of generated avatars)
  List<Color> avatarGradient(int seed);
}
