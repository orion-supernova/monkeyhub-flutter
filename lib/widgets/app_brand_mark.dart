import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'monkey_collection.dart';

/// Sentinel id used in [SettingsStore.manualLogoThemeId] to mean "the canonical
/// MonkeyHub logo asset, not a theme-flavored brandMark." Picked to never
/// collide with a real `AppTheme.id`.
const String canonicalLogoId = '__monkeyhub__';

/// Renders the app's brand mark. Resolves which mark to draw from the user's
/// [SettingsStore.logoMode]:
///  - [LogoMode.auto] follows the active theme (legacy behavior).
///  - [LogoMode.alwaysDefault] renders the canonical MonkeyHub asset.
///  - [LogoMode.manual] uses [SettingsStore.manualLogoThemeId] — either a theme
///    id (renders that theme's brandMark) or [canonicalLogoId] (renders the
///    canonical asset).
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    final active = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (_, _) => _resolve(active, size),
    );
  }

  Widget _resolve(AppTheme active, double size) {
    final s = SettingsStore.instance;
    switch (s.logoMode) {
      case LogoMode.auto:
        return active.brandMark(size: size);
      case LogoMode.alwaysDefault:
        return CanonicalLogo(size: size);
      case LogoMode.manual:
        final id = s.manualLogoThemeId;
        if (id == null) return active.brandMark(size: size);
        if (id == canonicalLogoId) return CanonicalLogo(size: size);
        final variant = monkeyVariantById(id);
        if (variant != null) {
          return MonkeyIconCanvas(variant: variant, size: size);
        }
        return ThemeController.byId(id).brandMark(size: size);
    }
  }
}

/// The canonical MonkeyHub brand mark — the actual launcher icon, independent
/// of any theme.
class CanonicalLogo extends StatelessWidget {
  const CanonicalLogo({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'branding/logo.webp',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}
