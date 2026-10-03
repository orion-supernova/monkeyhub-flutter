import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/speaker_colors.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';

/// Picker for how far each person's own colour reaches inside a group room.
///
/// The preview is a three-person exchange, because the whole point of the
/// setting is comparative — you are not judging one colour, you are judging
/// whether three people beside each other are tellable apart. It redraws live
/// as the choice under it changes.
class SpeakerColorScreen extends StatelessWidget {
  const SpeakerColorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final current = SettingsStore.instance.speakerTint;
        GroupedRow option(SpeakerTint tint, String title, String sub) =>
            GroupedRow.choice(
              title: title,
              subtitle: sub,
              selected: current == tint,
              onTap: () {
                pickFeedback();
                SettingsStore.instance.setSpeakerTint(tint);
              },
            );
        return SettingsPage(
          title: l10n.settingsHubSpeakerColors,
          children: [
            HeroPreview(
              valueKey: current,
              height: 236,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Preview(tint: current),
              ),
            ),
            GroupedSection(
              footer: l10n.speakerPageFooter,
              children: [
                option(
                  SpeakerTint.off,
                  l10n.settingsScreenValueSpeakerOff,
                  l10n.speakerOffSub,
                ),
                option(
                  SpeakerTint.name,
                  l10n.settingsScreenValueSpeakerName,
                  l10n.speakerNamesSub,
                ),
                option(
                  SpeakerTint.bubble,
                  l10n.settingsScreenValueSpeakerBubble,
                  l10n.speakerBubblesSub,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Three people talking, drawn at [tint].
///
/// Deliberately NOT a `MessageBubble`: that widget wants a repository, an api
/// handle and a live `SpeakerScope`, none of which a settings card has. What it
/// does share is the parts that decide what this looks like — the same
/// [SpeakerSlots] assignment a real room makes, the same
/// [SpeakerPalette] conditioning, and the same
/// [BubbleGeometry.bubbleDecoration] the transcript paints with — so the card
/// cannot drift from the room it is describing.
class _Preview extends StatelessWidget {
  const _Preview({required this.tint});

  final SpeakerTint tint;

  /// Stand-in ids. Fixed strings rather than anything generated, so the three
  /// colours on this card are the same three every time the screen opens.
  static const _cast = ['j57ada', 'j57jun', 'j57mira'];
  static const _names = ['ada', 'jun', 'mira'];

  // Listens to the settings it reads: this widget is built `const`, and a
  // const widget is never rebuilt by its parent, so a changed setting would
  // otherwise leave it showing the old value.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsStore.instance,
        builder: (context, _) => _buildListening(context),
      );

  Widget _buildListening(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final lines = [
      l10n.bubbleStyleScreenPreviewQuestion,
      l10n.bubbleStyleScreenPreviewReplyOne,
      l10n.bubbleStyleScreenPreviewReplyTwo,
    ];
    final slots =
        SpeakerSlots.forMembers([for (final id in _cast) (id: id, joinedAt: 0)]);
    // The preview sits on the page background, as a room does, so the colours
    // are conditioned against exactly what they will be read against.
    final ground = theme.background;
    final style = SettingsStore.instance.bubbleStyle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _cast.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _row(
            theme: theme,
            slot: tint == SpeakerTint.off ? null : slots.slotOf(_cast[i]),
            name: _names[i],
            text: lines[i],
            ground: ground,
            style: style,
          ),
        ],
      ],
    );
  }

  Widget _row({
    required AppTheme theme,
    required int? slot,
    required String name,
    required String text,
    required Color ground,
    required BubbleStyle style,
  }) {
    final ink = slot == null ? theme.accent : theme.speakerInk(slot, on: ground);
    final mark =
        slot == null ? theme.accent : theme.speakerMark(slot, on: ground);
    final authored =
        theme.messageBubbleDecoration(isMine: false, ephemeral: false);
    final fill = authored.color;
    final washed = (slot == null || tint != SpeakerTint.bubble || fill == null)
        ? null
        : theme.speakerWash(slot, surface: fill);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.surfaceRaised,
            border: slot == null
                ? Border.all(color: theme.divider)
                : Border.all(color: mark, width: 1.5),
          ),
          child: Text(
            name.characters.first.toUpperCase(),
            style: theme.monoTiny.copyWith(color: theme.inkSoft, height: 1.0),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.mono.copyWith(
                  color: slot == null
                      ? theme.accent.withValues(alpha: 0.95)
                      : ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: theme.bubbleDecoration(
                  isMine: false,
                  ephemeral: false,
                  style: style,
                  fill: washed,
                  edge: washed == null ? null : mark,
                ),
                child: Text(text, style: theme.body.copyWith(color: theme.ink)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

