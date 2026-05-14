import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_brand_mark.dart' show CanonicalLogo;

/// Single source of truth for "what a brand mark looks like as a launcher
/// icon."
///
/// Used in two places that MUST agree, or the in-app preview tile and the
/// shipped launcher PNG drift apart:
///   1. The MANUAL grid tile in [lib/screens/logo_screen.dart] (`_LogoTile`).
///   2. The PNG generator in [test/generate_launcher_icons.dart].
///
/// Composition rules:
/// - Opaque [AppTheme.surface] background. iOS rejects transparent alternate
///   icons, and [AppTheme.surface] is the colour the brand marks were
///   designed to read against (vs [AppTheme.background], which is the page
///   colour and often clashes).
/// - The brand mark fills the canvas edge-to-edge — no inner inset.
///   iOS already masks corners on alt icons and Android's adaptive-icon
///   safe-area is handled by the launcher.
class BrandIconCanvas extends StatelessWidget {
  const BrandIconCanvas({super.key, required this.theme, required this.size});
  final AppTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      // theme.surface is the visible fallback if the iconMark has transparent
      // edges (bio_organic, risograph_pop). For themes whose iconMark fills
      // edge-to-edge, this colour is fully covered.
      color: theme.surface,
      alignment: Alignment.center,
      child: theme.iconMark(size: size),
    );
  }
}

/// Same composition as [BrandIconCanvas] but renders the canonical MonkeyHub
/// asset instead of a theme-derived brand mark. The backdrop colour comes
/// from a theme so this canvas can live anywhere the theme is available;
/// when used as the manual-grid tile we pass the active theme.
class CanonicalIconCanvas extends StatelessWidget {
  const CanonicalIconCanvas({
    super.key,
    required this.backdrop,
    required this.size,
  });
  final Color backdrop;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: backdrop,
      alignment: Alignment.center,
      child: CanonicalLogo(size: size),
    );
  }
}
