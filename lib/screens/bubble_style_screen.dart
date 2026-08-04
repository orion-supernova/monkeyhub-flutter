import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// Picker for the shape every message bubble is drawn with. Each card previews
/// a real three-message exchange — one incoming message, then a two-message
/// run going out — because the interesting part of a bubble shape is what it
/// does across a *run*, not on a single bubble.
class BubbleStyleScreen extends StatefulWidget {
  const BubbleStyleScreen({super.key});

  @override
  State<BubbleStyleScreen> createState() => _BubbleStyleScreenState();
}

class _BubbleStyleScreenState extends State<BubbleStyleScreen> {
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

  void _set(BubbleStyle v) => SettingsStore.instance.setBubbleStyle(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = SettingsStore.instance.bubbleStyle;
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
                      icon: Icon(Icons.arrow_back,
                          color: theme.inkSoft, size: 18),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(l10n.bubbleStyleScreenTitle, style: theme.displayMedium),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(width: 18, height: 1, color: theme.accent),
                    const SizedBox(width: 8),
                    Text(l10n.bubbleStyleScreenSubtitle, style: theme.caption),
                  ]),
                  const SizedBox(height: 28),
                  _StyleCard(
                    label: l10n.bubbleStyleScreenTailedLabel,
                    sub: l10n.bubbleStyleScreenTailedDescription,
                    active: current == BubbleStyle.tailed,
                    preview: const _Preview(style: BubbleStyle.tailed),
                    onTap: () => _set(BubbleStyle.tailed),
                  ),
                  const SizedBox(height: 14),
                  _StyleCard(
                    label: l10n.bubbleStyleScreenSoftLabel,
                    sub: l10n.bubbleStyleScreenSoftDescription,
                    active: current == BubbleStyle.soft,
                    preview: const _Preview(style: BubbleStyle.soft),
                    onTap: () => _set(BubbleStyle.soft),
                  ),
                  const SizedBox(height: 14),
                  _StyleCard(
                    label: l10n.bubbleStyleScreenPillLabel,
                    sub: l10n.bubbleStyleScreenPillDescription,
                    active: current == BubbleStyle.pill,
                    preview: const _Preview(style: BubbleStyle.pill),
                    onTap: () => _set(BubbleStyle.pill),
                  ),
                  const SizedBox(height: 14),
                  _StyleCard(
                    label: l10n.bubbleStyleScreenSlabLabel,
                    sub: l10n.bubbleStyleScreenSlabDescription,
                    active: current == BubbleStyle.slab,
                    preview: const _Preview(style: BubbleStyle.slab),
                    onTap: () => _set(BubbleStyle.slab),
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

/// One three-bubble exchange drawn with [style], through the very same
/// decoration the transcript uses — so what the card shows is what the room
/// will do.
class _Preview extends StatelessWidget {
  const _Preview({required this.style});
  final BubbleStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bubble(theme, l10n.bubbleStyleScreenPreviewQuestion, mine: false),
        const SizedBox(height: 6),
        _bubble(theme, l10n.bubbleStyleScreenPreviewReplyOne,
            mine: true, lastInRun: false),
        const SizedBox(height: 1),
        _bubble(theme, l10n.bubbleStyleScreenPreviewReplyTwo,
            mine: true, firstInRun: false),
      ],
    );
  }

  Widget _bubble(
    AppTheme theme,
    String text, {
    required bool mine,
    bool firstInRun = true,
    bool lastInRun = true,
  }) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: theme.bubbleDecoration(
          isMine: mine,
          ephemeral: false,
          style: style,
          firstInRun: firstInRun,
          lastInRun: lastInRun,
        ),
        child: Text(
          text,
          style: theme.body.copyWith(
            color: mine ? theme.accentInk : theme.ink,
          ),
        ),
      ),
    );
  }
}

/// Same card chrome as the reply-style picker, so the two settings detail
/// screens read as one family.
class _StyleCard extends StatelessWidget {
  const _StyleCard({
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
                  )
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
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: theme.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(l10n.bubbleStyleScreenActiveBadge,
                        style: theme.monoTiny.copyWith(color: theme.accent)),
                  ]),
              ],
            ),
            const SizedBox(height: 6),
            Text(sub, style: theme.monoTiny),
            const SizedBox(height: 14),
            Container(
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
