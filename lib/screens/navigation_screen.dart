import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/settings_pickers.dart';
import '../widgets/ios_kit.dart' show quietFill;
import 'navigation/destinations.dart';

/// How you move between the app's sections: an always-visible tab bar, or the
/// radial orb you hold and drag. Two tiles, each a tiny phone showing its own
/// navigation over the same list, the way iOS shows Light against Dark.
class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final current = SettingsStore.instance.navStyle;
        return SettingsPage(
          title: l10n.settingsHubNavigation,
          children: [
            PreviewChoiceTiles<NavStyle>(
              selected: current,
              onChanged: (v) {
                pickFeedback();
                SettingsStore.instance.setNavStyle(v);
              },
              choices: [
                PreviewChoice(
                  value: NavStyle.pill,
                  label: l10n.settingsHubNavTabBar,
                  preview: const MiniListBackdrop(child: _PillPreview()),
                ),
                PreviewChoice(
                  value: NavStyle.radial,
                  label: l10n.settingsScreenValueRadialOrb,
                  preview: const MiniListBackdrop(child: _RadialPreview()),
                ),
              ],
            ),
            // Two notes, not one run-on line: what the picked option does,
            // then — on its own line — what the page is for.
            GroupedFooter(
              '${current == NavStyle.pill ? l10n.navTabBarSub : l10n.navOrbSub}\n'
              '${l10n.navigationPageFooter}',
            ),
          ],
        );
      },
    );
  }
}

class _RadialPreview extends StatelessWidget {
  const _RadialPreview();

  /// Mirrors [RadialFloatingMenu]'s real geometry at preview scale, so the
  /// picture can't drift out of sync with the menu it's advertising.
  static const double _spanStart = -math.pi / 2.2;
  static const double _spanSweep = math.pi / 2.25;
  static const double _previewRadius = 46;
  static const double _orbCentre = 19; // 8pt inset + half of a 22pt orb
  static const double _dot = 14;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final n = navDestinations(AppLocalizations.of(context)).length;
    return Stack(
      children: [
        for (var i = 0; i < n; i++)
          () {
            final a = n <= 1
                ? _spanStart + _spanSweep / 2
                : _spanStart + (_spanSweep / (n - 1)) * i;
            return Positioned(
              left: _orbCentre + math.cos(a) * _previewRadius - _dot / 2,
              bottom: _orbCentre - math.sin(a) * _previewRadius - _dot / 2,
              child: _ghostDot(theme),
            );
          }(),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _ghostDot(AppTheme theme) {
    return Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: theme.ink.withValues(alpha: 0.15)),
      ),
    );
  }
}

/// The floating tab bar in miniature: a capsule of four glyph dots, the first
/// one lit.
class _PillPreview extends StatelessWidget {
  const _PillPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final n = navDestinations(AppLocalizations.of(context)).length;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 26,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            theme.ink.withValues(alpha: 0.10),
            theme.surface,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.ink.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: i == 0
                        ? quietFill(theme)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? theme.accent
                          : theme.ink.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
