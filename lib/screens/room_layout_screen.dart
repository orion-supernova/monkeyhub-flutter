import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

class RoomLayoutScreen extends StatefulWidget {
  const RoomLayoutScreen({super.key});

  @override
  State<RoomLayoutScreen> createState() => _RoomLayoutScreenState();
}

class _RoomLayoutScreenState extends State<RoomLayoutScreen> {
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

  void _set(RoomLayout v) => SettingsStore.instance.setRoomLayout(v);
  void _setFilter(FilterStyle v) => SettingsStore.instance.setFilterStyle(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final current = SettingsStore.instance.roomLayout;
    final filter = SettingsStore.instance.filterStyle;
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
                  Text('chat list.', style: theme.displayMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 18, height: 1, color: theme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'how rooms stack, and how you filter them',
                        style: theme.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('LAYOUT', style: theme.label),
                  const SizedBox(height: 12),
                  _LayoutCard(
                    label: 'ROW LAYOUT',
                    sub: 'one column, full bleed. easy to read at a glance.',
                    active: current == RoomLayout.list,
                    preview: const _ListPreview(),
                    onTap: () => _set(RoomLayout.list),
                  ),
                  const SizedBox(height: 14),
                  _LayoutCard(
                    label: 'GRID LAYOUT',
                    sub: 'two columns, compact. more rooms in one look.',
                    active: current == RoomLayout.grid,
                    preview: const _GridPreview(),
                    onTap: () => _set(RoomLayout.grid),
                  ),
                  const SizedBox(height: 32),
                  Text('FILTER CONTROL', style: theme.label),
                  const SizedBox(height: 12),
                  _LayoutCard(
                    label: 'CHIP ROW',
                    sub:
                        'always on show. one tap to any filter, one row of space.',
                    active: filter == FilterStyle.chips,
                    preview: const _ChipsPreview(),
                    onTap: () => _setFilter(FilterStyle.chips),
                  ),
                  const SizedBox(height: 14),
                  _LayoutCard(
                    label: 'DRAWER BUTTON',
                    sub:
                        'one button that opens. nothing in the way until you ask.',
                    active: filter == FilterStyle.drawer,
                    preview: const _DrawerPreview(),
                    onTap: () => _setFilter(FilterStyle.drawer),
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

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
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
                        'ACTIVE',
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

class _ListPreview extends StatelessWidget {
  const _ListPreview();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          _bar(theme, accent: i == 0),
          if (i < 2) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _bar(AppTheme theme, {required bool accent}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: accent ? theme.accent.withValues(alpha: 0.18) : theme.surface,
          border: Border.all(
            color: accent
                ? theme.accent.withValues(alpha: 0.55)
                : theme.divider,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: accent ? theme.accent : theme.inkMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 6, color: theme.divider)),
          ],
        ),
      ),
    );
  }
}

/// A header row whose only filter affordance is one small button, over an
/// undisturbed list.
class _DrawerPreview extends StatelessWidget {
  const _DrawerPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.inkMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 6, color: theme.divider)),
            const SizedBox(width: 8),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border.all(color: theme.divider),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (i < 2) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// The same header, with a permanent row of capsules beneath it — and one
/// fewer room visible for it.
class _ChipsPreview extends StatelessWidget {
  const _ChipsPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.inkMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 6, color: theme.divider)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Container(
                width: i == 0 ? 22 : 28,
                height: 14,
                decoration: BoxDecoration(
                  color: i == 0 ? theme.accent : Colors.transparent,
                  border: Border.all(
                    color: i == 0 ? theme.accent : theme.divider,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (i < 3) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < 2; i++) ...[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border.all(color: theme.divider),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (i < 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _GridPreview extends StatelessWidget {
  const _GridPreview();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        for (var c = 0; c < 2; c++) ...[
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < 2; r++) ...[
                  _tile(theme, accent: c == 0 && r == 0),
                  if (r == 0) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (c == 0) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _tile(AppTheme theme, {required bool accent}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: accent ? theme.accent.withValues(alpha: 0.18) : theme.surface,
          border: Border.all(
            color: accent
                ? theme.accent.withValues(alpha: 0.55)
                : theme.divider,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
