import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../fight/core/bot.dart' as fb;
import '../data/settings_store.dart';
import '../fight/view/fight_character_grid.dart' show fightCharOf;
import '../fight/view/fight_lobby_screen.dart';
import '../fight/view/fighter_portrait.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../turn_games/bot.dart';
import '../widgets/ios_kit.dart';
import 'bot_match_screen.dart';
import 'game_start_sheet.dart' show ChatGameArt;
import 'match_copy.dart';
import 'monkey_avatar.dart';
import '../theme/layout.dart';

/// The board games you can play against the app's own bot.
///
/// Its own place, shown inline on the Games tab ([BotHubPanel]), rather than a mode
/// inside a chat's "Play a game" sheet: a game against the app posts nothing
/// and involves nobody, so offering it from a conversation put a solo thing
/// in a social place and made the sheet's first question ("how?") about the
/// wrong thing.
///
/// Pick how tough the bot plays, then a game. The level is remembered for the
/// session, so a rematch from here is one tap.
class BotHubScreen extends StatelessWidget {
  const BotHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        // Desktop and web: the content is a centred column, not edge to edge.
        final side = ((box.maxWidth - 960) / 2).clamp(16.0, double.infinity);
        return IosPage(
          title: sentenceCaseOf(context, l10n.botHubTitle),
          padding: EdgeInsets.fromLTRB(side, 0, side, 40),
          children: [
            _Intro(text: l10n.botHubSubtitle(l10n.chatGameBotName)),
            const SizedBox(height: 22),
            const BotHubPanel(),
          ],
        );
      },
    );
  }
}

/// The bot hub's working part: the level picker, the fighter banner, the
/// board-game grid and the "not ranked" footer. Shared by [BotHubScreen] and
/// the Games tab, which shows it inline rather than one more push away.
class BotHubPanel extends StatefulWidget {
  const BotHubPanel({super.key});

  @override
  State<BotHubPanel> createState() => _BotHubPanelState();
}

class _BotHubPanelState extends State<BotHubPanel> {
  static BotLevel _remembered = BotLevel.medium;

  BotLevel _level = _remembered;

  void _setLevel(BotLevel l) {
    if (l == _level) return;
    HapticFeedback.selectionClick();
    setState(() => _level = _remembered = l);
  }

  void _playFight() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FightLobbyScreen(
          level: switch (_level) {
            BotLevel.easy => fb.BotLevel.easy,
            BotLevel.medium => fb.BotLevel.normal,
            BotLevel.hard => fb.BotLevel.hard,
          },
        ),
      ),
    );
  }

  void _play(String game) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BotMatchScreen(game: game, level: _level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final hint = switch (_level) {
      BotLevel.easy => l10n.chatGameBotEasyHint,
      BotLevel.medium => l10n.chatGameBotMediumHint,
      BotLevel.hard => l10n.chatGameBotHardHint,
    };
    return LayoutBuilder(
      builder: (context, box) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedHeader(sentenceCaseOf(context, l10n.botHubLevelTitle)),
        Row(
          children: [
            for (final (i, l) in BotLevel.values.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _LevelCard(
                  key: ValueKey('bot_level_${l.name}'),
                  level: l,
                  selected: l == _level,
                  onTap: () => _setLevel(l),
                ),
              ),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: AnimatedSwitcher(
            duration: motion.d(theme.motionFast),
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.topStart,
              children: [...previous, ?current],
            ),
            child: Text(
              sentenceCaseOf(context, hint),
              key: ValueKey(_level),
              style: groupedFooterStyle(theme),
            ),
          ),
        ),
        const SizedBox(height: 26),
        _FightBanner(
          key: const ValueKey('bot_fight_banner'),
          title: l10n.fightTitle,
          subtitle: l10n.fightHubSubtitle,
          wide: box.maxWidth >= Breakpoints.botHubWide,
          onTap: _playFight,
        ),
        const SizedBox(height: 26),
        GroupedHeader(sentenceCaseOf(context, l10n.botHubPickGame)),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 12.0;
            final across = box.maxWidth >= Breakpoints.botHubThreeUp ? 3 : 2;
            final w = (box.maxWidth - gap * (across - 1)) / across;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final g in kChatGames)
                  SizedBox(
                    width: w,
                    child: _BotGameTile(
                      key: ValueKey('bot_game_$g'),
                      game: g,
                      onTap: () => _play(g),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.info_circle, size: 14, color: theme.inkMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                sentenceCaseOf(context, l10n.practiceNotRanked),
                style: groupedFooterStyle(theme),
              ),
            ),
          ],
        ),
      ],
    );
      },
    );
  }
}

/// The page's opening: the monkey on a soft disc of the accent, and who you
/// are playing.
class _Intro extends StatelessWidget {
  const _Intro({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme) + 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.accent.withValues(alpha: 0.35),
            ),
            child: const MonkeyAvatar(size: 56),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.body.copyWith(color: theme.inkSoft, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// How hard each level plays, as a colour: calm green to angry red.
TileTone _toneOf(BotLevel l) => switch (l) {
  BotLevel.easy => TileTone.green,
  BotLevel.medium => TileTone.orange,
  BotLevel.hard => TileTone.red,
};

/// One level: a three-bar strength meter, filled as far as the level goes,
/// and its name. The meter says "harder" without a word, in every language.
class _LevelCard extends StatelessWidget {
  const _LevelCard({
    super.key,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final BotLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final c = tileColor(theme, _toneOf(level));
    final name = sentenceCaseOf(
      context,
      switch (level) {
        BotLevel.easy => l10n.gameTierEasy,
        BotLevel.medium => l10n.gameTierMedium,
        BotLevel.hard => l10n.gameTierHard,
      },
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SpringPress(
        onTap: onTap,
        haptic: false,
        scale: 0.94,
        semanticLabel: name,
        child: AnimatedContainer(
          duration: motion.d(theme.motionFast),
          curve: theme.motionCurve,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              c.withValues(alpha: selected ? 0.14 : 0),
              groupedFill(theme),
            ),
            borderRadius: BorderRadius.circular(groupedRadius(theme) + 2),
            border: Border.all(
              color: selected ? c : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              _Meter(
                filled: level.index + 1,
                color: c,
                idle: theme.ink.withValues(alpha: 0.12),
                lit: selected,
              ),
              const SizedBox(height: 10),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyEmph.copyWith(
                  fontSize: 15,
                  color: selected ? theme.ink : theme.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three rising bars. The filled ones grow up into place when the card is
/// picked, one after another, so choosing "hard" visibly charges the meter.
class _Meter extends StatelessWidget {
  const _Meter({
    required this.filled,
    required this.color,
    required this.idle,
    required this.lit,
  });

  final int filled;
  final Color color;
  final Color idle;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    const heights = [12.0, 19.0, 26.0];
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 8,
              height: heights[i],
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: idle,
                borderRadius: BorderRadius.circular(3),
              ),
              child: i < filled
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey(lit),
                      tween: Tween(begin: lit ? 0.35 : 1, end: 1),
                      duration: motion.d(theme.motionMed) + Duration(milliseconds: 60 * i),
                      curve: Curves.easeOutBack,
                      builder: (context, t, _) => FractionallySizedBox(
                        heightFactor: t.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: lit ? color : color.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const SizedBox(width: 8),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _BotGameTile extends StatelessWidget {
  const _BotGameTile({super.key, required this.game, required this.onTap});

  final String game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final name = sentenceCaseOf(context, chatGameName(l10n, game));
    return SpringPress(
      onTap: onTap,
      scale: 0.95,
      semanticLabel: '$name, ${chatGameDescription(l10n, game)}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: groupedFill(theme),
          borderRadius: BorderRadius.circular(groupedRadius(theme) + 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(groupedRadius(theme) - 6),
              child: AspectRatio(aspectRatio: 1, child: ChatGameArt(game: game)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyEmph.copyWith(
                      fontSize: 16,
                      color: theme.ink,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.play_circle_fill,
                  size: 22,
                  color: theme.accent,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              chatGameDescription(l10n, game),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jungle Fist's door in Play the bot. It is not a turn game, so it is not a
/// tile in the grid but a banner above it: the real-time game gets its own
/// entrance and its own setup page.
class _FightBanner extends StatelessWidget {
  const _FightBanner({super.key, required this.title, required this.subtitle, required this.onTap, this.wide = false});

  final String title, subtitle;
  final VoidCallback onTap;

  /// Desktop: taller, with your fighter standing on the right.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final r = BorderRadius.circular(groupedRadius(theme) + 4);
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: wide ? 30 : 24, fontWeight: FontWeight.w900, color: const Color(0xffffcf6e), letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.body.copyWith(color: const Color(0xe6ffffff), height: 1.3)),
      ],
    );
    return SpringPress(
      onTap: onTap,
      scale: 0.97,
      semanticLabel: title,
      child: Container(
        height: wide ? 168 : null,
        padding: EdgeInsets.fromLTRB(wide ? 28 : 18, wide ? 0 : 16, wide ? 0 : 14, wide ? 0 : 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff2a1240), Color(0xff6a1d3a), Color(0xffa8452c)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: r,
        ),
        child: wide
            ? Row(
                children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: texts)),
                  // A still pose (no ticker): the banner costs nothing live.
                  SizedBox(
                    width: 190,
                    child: FighterPortrait(charId: fightCharOf(SettingsStore.instance.fightChar), animate: false, glow: const Color(0xffffb86b)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.chevron_right, color: Color(0xccffffff), size: 22),
                  const SizedBox(width: 20),
                ],
              )
            : Row(
                children: [
                  Expanded(child: texts),
                  const SizedBox(width: 10),
                  const Icon(CupertinoIcons.chevron_right, color: Color(0xccffffff), size: 20),
                ],
              ),
      ),
    );
  }
}
