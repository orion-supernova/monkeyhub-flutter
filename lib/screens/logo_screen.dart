import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_brand_mark.dart';
import '../widgets/brand_icon_canvas.dart';
import '../widgets/monkey_collection.dart';

class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key});

  @override
  State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
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

  void _setMode(LogoMode m) => SettingsStore.instance.setLogoMode(m);
  void _pickManual(String id) {
    SettingsStore.instance.setLogoMode(LogoMode.manual);
    SettingsStore.instance.setManualLogoThemeId(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = SettingsStore.instance;
    final mode = store.logoMode;
    final manualId = store.manualLogoThemeId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
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
                Text('app logo.', style: theme.displayMedium),
                const SizedBox(height: 10),
                Row(children: [
                  Container(width: 18, height: 1, color: theme.accent),
                  const SizedBox(width: 8),
                  Text('the mark in your header, your call.', style: theme.caption),
                ]),
                const SizedBox(height: 28),
                _ModeCard(
                  label: 'AUTO',
                  sub: 'follows your theme. mark changes with the palette.',
                  active: mode == LogoMode.auto,
                  onTap: () => _setMode(LogoMode.auto),
                  preview: const _AutoPreview(),
                ),
                const SizedBox(height: 14),
                _ModeCard(
                  label: 'MANUAL',
                  sub: 'pick any mark, keep your theme.',
                  active: mode == LogoMode.manual,
                  onTap: () => _setMode(LogoMode.manual),
                  preview: mode == LogoMode.manual
                      ? _ManualGrid(selectedId: manualId, onPick: _pickManual)
                      : const _ManualPreviewStrip(),
                ),
                const SizedBox(height: 14),
                _ModeCard(
                  label: 'ALWAYS DEFAULT',
                  sub: 'the MonkeyHub mark, regardless of theme.',
                  active: mode == LogoMode.alwaysDefault,
                  onTap: () => _setMode(LogoMode.alwaysDefault),
                  preview: const _DefaultPreview(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
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
            preview,
          ],
        ),
      ),
    );
  }
}

class _AutoPreview extends StatelessWidget {
  const _AutoPreview();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final picks = _pickShowcase(3);
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        children: [
          // Canonical first — the fallback identity.
          Expanded(
            child: Center(
              child: Opacity(opacity: 0.55, child: CanonicalLogo(size: 30)),
            ),
          ),
          for (var i = 0; i < picks.length; i++)
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: i == 1 ? 1 : 0.55,
                  child: picks[i].brandMark(size: i == 1 ? 40 : 30),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualPreviewStrip extends StatelessWidget {
  const _ManualPreviewStrip();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final picks = _pickShowcase(4);
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: CanonicalLogo(size: 32))),
          for (final t in picks)
            Expanded(child: Center(child: t.brandMark(size: 30))),
        ],
      ),
    );
  }
}

class _ManualGrid extends StatelessWidget {
  const _ManualGrid({required this.selectedId, required this.onPick});
  final String? selectedId;
  final void Function(String id) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final themes = ThemeController.all;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GridSectionHeader(label: 'MONKEY COLLECTION'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              // Canonical MonkeyHub is the "default" of the collection — picks
              // here clear any alternate icon, returning iOS to the primary
              // AppIcon (which is the same monkey on the same dark backdrop).
              _LogoTile(
                label: 'MonkeyHub',
                background: const Color(0xFF0E0E10),
                borderColor: theme.divider,
                selected: selectedId == canonicalLogoId,
                onTap: () => onPick(canonicalLogoId),
                child: const CanonicalIconCanvas(
                  backdrop: Color(0xFF0E0E10),
                  size: 72,
                ),
              ),
              for (final v in monkeyCollection)
                _LogoTile(
                  label: v.displayName,
                  // The illustration is full-bleed and opaque so the tile
                  // background is invisible behind it — keep it neutral.
                  background: theme.surface,
                  borderColor: theme.divider,
                  selected: v.id == selectedId,
                  onTap: () => onPick(v.id),
                  child: MonkeyIconCanvas(variant: v, size: 72),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _GridSectionHeader(label: 'THEMES'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final t in themes)
                _LogoTile(
                  label: t.name,
                  background: t.surface,
                  borderColor: t.divider,
                  selected: t.id == selectedId,
                  onTap: () => onPick(t.id),
                  child: BrandIconCanvas(theme: t, size: 72),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridSectionHeader extends StatelessWidget {
  const _GridSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.label.copyWith(letterSpacing: 2.4, color: theme.accent),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ],
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.label,
    required this.background,
    required this.borderColor,
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final String label;
  final Color background;
  final Color borderColor;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: theme.motionFast,
              width: 72,
              height: 72,
              // Clip the edge-to-edge BrandIconCanvas child to the tile's
              // rounded corners — otherwise the square canvas overdraws them.
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(theme.radiusMd),
                border: Border.all(
                  color: selected ? theme.accent : borderColor,
                  width: selected ? 1.6 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: theme.accent.withValues(alpha: 0.30), blurRadius: 14)]
                    : null,
              ),
              alignment: Alignment.center,
              child: child,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.monoTiny.copyWith(
                color: selected ? theme.accent : theme.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultPreview extends StatelessWidget {
  const _DefaultPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: theme.divider),
      ),
      alignment: Alignment.center,
      child: CanonicalLogo(size: 64),
    );
  }
}

/// Picks a small set of themes whose marks vary visually, so previews don't all
/// look like the same letter.
List<AppTheme> _pickShowcase(int n) {
  final all = ThemeController.all;
  if (all.length <= n) return all;
  final indices = <int>[];
  final step = (all.length - 1) / (n - 1);
  for (var i = 0; i < n; i++) {
    indices.add((i * step).round().clamp(0, all.length - 1));
  }
  return [for (final i in indices) all[i]];
}
