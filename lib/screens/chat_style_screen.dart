import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/settings_pickers.dart';

/// How a room's chrome is drawn: a solid header over a flat composer, or
/// frosted controls floating over the conversation. Two pictures of a room,
/// side by side.
class ChatStyleScreen extends StatelessWidget {
  const ChatStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final current = SettingsStore.instance.chatStyle;
        return SettingsPage(
          title: l10n.settingsHubChatStyle,
          children: [
            PreviewChoiceTiles<ChatStyle>(
              selected: current,
              onChanged: (v) {
                pickFeedback();
                SettingsStore.instance.setChatStyle(v);
              },
              choices: [
                PreviewChoice(
                  value: ChatStyle.classic,
                  label: l10n.settingsScreenValueClassic,
                  preview: const Padding(
                    padding: EdgeInsets.all(9),
                    child: _ClassicPreview(),
                  ),
                ),
                PreviewChoice(
                  value: ChatStyle.compact,
                  label: l10n.settingsScreenValueCompact,
                  preview: const Padding(
                    padding: EdgeInsets.all(9),
                    child: _CompactPreview(),
                  ),
                ),
              ],
            ),
            // Two notes, not one run-on line: what the picked option does,
            // then — on its own line — what the page is for.
            GroupedFooter(
              '${current == ChatStyle.classic ? l10n.chatStyleClassicSub : l10n.chatStyleCompactSub}\n'
              '${l10n.chatStylePageFooter}',
            ),
          ],
        );
      },
    );
  }
}

class _ClassicPreview extends StatelessWidget {
  const _ClassicPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top header: flat row of back-glyph · title bars · info-glyph,
        // separated from the conversation by a hairline divider.
        Row(
          children: [
            _flatGlyph(theme),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 70, height: 6, color: theme.inkSoft),
                  const SizedBox(height: 4),
                  Container(width: 40, height: 4, color: theme.inkMuted),
                ],
              ),
            ),
            _flatGlyph(theme),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: theme.divider),
        const SizedBox(height: 10),
        // Two stacked message-bar mocks
        const Spacer(),
        _bubble(theme, mine: false),
        const SizedBox(height: 6),
        _bubble(theme, mine: true),
        const Spacer(),
        const SizedBox(height: 10),
        Container(height: 1, color: theme.divider),
        const SizedBox(height: 8),
        // Bottom composer: bordered rect + accent circle send
        Row(
          children: [
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: theme.divider),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
            ),
          ],
        ),
      ],
    );
  }

  Widget _flatGlyph(AppTheme theme) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: theme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider),
      ),
    );
  }

  Widget _bubble(AppTheme theme, {required bool mine}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.55,
        child: Container(
          height: 16,
          decoration: BoxDecoration(
            color: theme.bubbleFill(isMine: mine),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _CompactPreview extends StatelessWidget {
  const _CompactPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top header: glass back · glass pill · glass info
        Row(
          children: [
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22),
            const Spacer(),
            _miniPill(theme),
            const Spacer(),
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22),
          ],
        ),
        const SizedBox(height: 10),
        // Mid messages — overlap visually under the floating chrome
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.bubbleFill(isMine: false),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.bubbleFill(isMine: true),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Bottom composer: glass attach · glass field · glass tinted send
        Row(
          children: [
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22),
            const SizedBox(width: 6),
            Expanded(
              child: _miniGlass(theme, shape: BoxShape.rectangle, width: 0, height: 22, radius: 11),
            ),
            const SizedBox(width: 6),
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22, tinted: true),
          ],
        ),
      ],
    );
  }

  Widget _miniGlass(
    AppTheme theme, {
    required BoxShape shape,
    required double width,
    required double height,
    double radius = 0,
    bool tinted = false,
  }) {
    final base = tinted
        ? theme.accent.withValues(alpha: 0.50)
        : theme.surface.withValues(alpha: 0.55);
    return Container(
      width: width > 0 ? width : null,
      height: height,
      decoration: BoxDecoration(
        color: base,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null,
        border: Border.all(color: theme.accent.withValues(alpha: 0.30), width: 1),
        gradient: tinted
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
      ),
    );
  }

  Widget _miniPill(AppTheme theme) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(maxWidth: 90, minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: theme.accent.withValues(alpha: 0.30), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Container(width: 30, height: 4, color: theme.inkMuted),
        ],
      ),
    );
  }
}
