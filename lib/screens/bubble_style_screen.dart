import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';

/// Picker for the shape every message bubble is drawn with: a live exchange
/// in the chosen shape on top — one incoming message, then a two-message run
/// going out, because what a shape does across a *run* is the interesting
/// part — and the four shapes as a checked list under it.
class BubbleStyleScreen extends StatelessWidget {
  const BubbleStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final current = SettingsStore.instance.bubbleStyle;
        GroupedRow option(BubbleStyle style, String title, String sub) =>
            GroupedRow.choice(
              title: title,
              subtitle: sub,
              selected: current == style,
              onTap: () {
                pickFeedback();
                SettingsStore.instance.setBubbleStyle(style);
              },
            );
        return SettingsPage(
          title: l10n.settingsHubBubbleStyle,
          children: [
            HeroPreview(
              valueKey: current,
              height: 176,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Center(child: _Preview(style: current)),
            ),
            GroupedSection(
              children: [
                option(
                  BubbleStyle.tailed,
                  l10n.settingsScreenValueBubbleTailed,
                  l10n.bubbleTailedSub,
                ),
                option(
                  BubbleStyle.soft,
                  l10n.settingsScreenValueBubbleSoft,
                  l10n.bubbleSoftSub,
                ),
                option(
                  BubbleStyle.pill,
                  l10n.settingsScreenValueBubblePill,
                  l10n.bubblePillSub,
                ),
                option(
                  BubbleStyle.slab,
                  l10n.settingsScreenValueBubbleSlab,
                  l10n.bubbleSlabSub,
                ),
              ],
            ),
          ],
        );
      },
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

