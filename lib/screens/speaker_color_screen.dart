import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/speaker_colors.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// Picker for how far each person's own colour reaches inside a group room.
///
/// Every card previews the SAME three-person exchange, because the whole point
/// of the setting is comparative — you are not judging one colour, you are
/// judging whether three people beside each other are tellable apart. A
/// one-speaker preview would show the feature and hide the reason for it.
class SpeakerColorScreen extends StatefulWidget {
  const SpeakerColorScreen({super.key});

  @override
  State<SpeakerColorScreen> createState() => _SpeakerColorScreenState();
}

class _SpeakerColorScreenState extends State<SpeakerColorScreen> {
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

  void _set(SpeakerTint v) => SettingsStore.instance.setSpeakerTint(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = SettingsStore.instance.speakerTint;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  edgeToEdgeBottom(context, 40),
                ),
                children: [
                  Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back,
                          color: theme.inkSoft, size: 18),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(l10n.speakerColorScreenTitle,
                      style: theme.displayMedium),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(width: 18, height: 1, color: theme.accent),
                    const SizedBox(width: 8),
                    Text(l10n.speakerColorScreenSubtitle, style: theme.caption),
                  ]),
                  const SizedBox(height: 28),
                  _StyleCard(
                    label: l10n.speakerColorScreenOffLabel,
                    sub: l10n.speakerColorScreenOffDescription,
                    active: current == SpeakerTint.off,
                    preview: const _Preview(tint: SpeakerTint.off),
                    onTap: () => _set(SpeakerTint.off),
                  ),
                  const SizedBox(height: 14),
                  _StyleCard(
                    label: l10n.speakerColorScreenNameLabel,
                    sub: l10n.speakerColorScreenNameDescription,
                    active: current == SpeakerTint.name,
                    preview: const _Preview(tint: SpeakerTint.name),
                    onTap: () => _set(SpeakerTint.name),
                  ),
                  const SizedBox(height: 14),
                  _StyleCard(
                    label: l10n.speakerColorScreenBubbleLabel,
                    sub: l10n.speakerColorScreenBubbleDescription,
                    active: current == SpeakerTint.bubble,
                    preview: const _Preview(tint: SpeakerTint.bubble),
                    onTap: () => _set(SpeakerTint.bubble),
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final lines = [
      l10n.bubbleStyleScreenPreviewQuestion,
      l10n.bubbleStyleScreenPreviewReplyOne,
      l10n.bubbleStyleScreenPreviewReplyTwo,
    ];
    final slots =
        SpeakerSlots.forMembers([for (final id in _cast) (id: id, joinedAt: 0)]);
    // The card's own plate, not the room's — the preview sits on a sunken
    // surface here, and conditioning against the room background would hand
    // back colours that clear contrast somewhere this card isn't.
    final ground = theme.surfaceSunken;
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
          width: 20,
          height: 20,
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

/// Same card chrome as the bubble- and reply-style pickers, so the three
/// settings detail screens read as one family.
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
