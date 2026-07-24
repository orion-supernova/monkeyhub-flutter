import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

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
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('navigation.', style: theme.displayMedium),
                const SizedBox(height: 10),
                Row(children: [
                  Container(width: 18, height: 1, color: theme.accent),
                  const SizedBox(width: 8),
                  Text('how you move between chat, feed, settings', style: theme.caption),
                ]),
                const SizedBox(height: 28),
                _NavCard(
                  label: 'RADIAL ORB',
                  sub: 'hold + drag from the corner. a quiet idle, a gesture you grow into.',
                  active: current == NavStyle.radial,
                  preview: const _RadialPreview(),
                  onTap: () => _set(NavStyle.radial),
                ),
                const SizedBox(height: 14),
                _NavCard(
                  label: 'BOTTOM PILL',
                  sub: 'classic tap. always visible, no learning curve.',
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
              ? [BoxShadow(color: theme.accent.withValues(alpha: 0.25), blurRadius: 18)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.label)),
                if (active)
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('ACTIVE', style: theme.monoTiny.copyWith(color: theme.accent)),
                  ]),
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
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Stack(
      children: [
        // Ghost slices fanned above orb
        Positioned(
          left: 30,
          bottom: 50,
          child: _ghostDot(theme),
        ),
        Positioned(
          left: 56,
          bottom: 70,
          child: _ghostDot(theme),
        ),
        Positioned(
          left: 86,
          bottom: 62,
          child: _ghostDot(theme),
        ),
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
      width: 18,
      height: 18,
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
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: i == 0 ? theme.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}
