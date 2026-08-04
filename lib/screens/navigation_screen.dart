import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import 'navigation/destinations.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _set(NavStyle v) => SettingsStore.instance.setNavStyle(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = SettingsStore.instance.navStyle;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.inkSoft,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.messageStampNavigationTitle,
                      style: theme.displayMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 18, height: 1, color: theme.accent),
                      const SizedBox(width: 8),
                      Text(
                        l10n.messageStampNavigationSubtitle,
                        style: theme.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _NavCard(
                    label: l10n.messageStampRadialOrbLabel,
                    sub: l10n.messageStampRadialOrbDescription,
                    active: current == NavStyle.radial,
                    preview: const _RadialPreview(),
                    onTap: () => _set(NavStyle.radial),
                  ),
                  const SizedBox(height: 14),
                  _NavCard(
                    label: l10n.messageStampBottomPillLabel,
                    sub: l10n.messageStampBottomPillDescription,
                    active: current == NavStyle.pill,
                    preview: const _PillPreview(),
                    onTap: () => _set(NavStyle.pill),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.label,
    required this.sub,
    required this.active,
    required this.preview,
    required this.onTap,
  });
  final String label;
  final String sub;
  final bool active;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(
            color: active ? theme.accent : theme.divider,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.25),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.label)),
                if (active)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.messageStampActiveLabel,
                        style: theme.monoTiny.copyWith(color: theme.accent),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(sub, style: theme.monoTiny),
            const SizedBox(height: 14),
            Container(
              height: 140,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(theme.radiusMd),
                border: Border.all(color: theme.divider),
              ),
              child: preview,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialPreview extends StatelessWidget {
  const _RadialPreview();

  /// Mirrors [RadialFloatingMenu]'s real geometry at preview scale, so the card
  /// can't drift out of sync with the menu it's advertising. The dots used to
  /// be three hand-placed [Positioned]s.
  static const double _spanStart = -math.pi / 2.2;
  static const double _spanSweep = math.pi / 2.25;
  static const double _previewRadius = 56;
  static const double _orbCentre = 19; // 8pt inset + half of a 22pt orb
  static const double _dot = 18;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final n = navDestinations(AppLocalizations.of(context)).length;
    return Stack(
      children: [
        // Ghost slices fanned above the orb, evenly spaced across the quadrant.
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
        // Resting orb
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ],
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
        color: theme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: theme.accent.withValues(alpha: 0.45)),
      ),
    );
  }
}

class _PillPreview extends StatelessWidget {
  const _PillPreview();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.divider),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < navDestinations(AppLocalizations.of(context)).length; i++) ...[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: i == 0 ? theme.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (i < navDestinations(AppLocalizations.of(context)).length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}
