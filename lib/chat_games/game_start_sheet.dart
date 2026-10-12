import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../party_games/party_art.dart';
import '../party_games/race_table.dart' show racePuzzleName;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import '../turn_games/bot.dart';
import '../turn_games/registry.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import 'match_copy.dart';

/// How a chat game should be played, as the start sheet chose it.
enum ChatGameMode { live, turns, bot }

/// What the start sheet hands back. It sends nothing itself: which room, and
/// what a refusal looks like, are the room screen's business — the same split
/// `InteractionDraft` has.
class ChatGameDraft {
  const ChatGameDraft({
    required this.game,
    required this.mode,
    this.level,
    this.options = MatchOptions.none,
  });

  final String game;
  final ChatGameMode mode;

  /// The bot's strength, for [ChatGameMode.bot].
  final BotLevel? level;

  /// A party game's variant: Imposter's voice clues, Puzzle Race's puzzle.
  final MatchOptions options;

  MatchMode get matchMode =>
      mode == ChatGameMode.turns ? MatchMode.async : MatchMode.live;
}

/// "Play a game": pick how (live, take turns, against the bot), then which.
///
/// "Take turns" is offered in a DM only — the server refuses it anywhere else
/// (`ASYNC_DM_ONLY`), and offering a choice whose only outcome is a refusal
/// is worse than not offering it. It is the default in a DM because that is
/// how a game between two people who are not both looking at their phones
/// gets played at all; a group defaults to live.
///
/// [soloOnly] is Saved Messages, where there is nobody to play: only the bot
/// is offered.
///
/// The party games (Liar's Dice, Imposter, Puzzle Race) sit in their own
/// section under the two-player ones. They are live only, so with Take turns
/// or Vs bot chosen they stay in view but greyed, with the reason under the
/// header: hiding them would make the section jump in and out as the
/// segment moves. Imposter also needs three, which a DM can never seat. A
/// party game with options (Imposter's voice clues, the race's puzzle) opens
/// them in place under its tile, with the Start button there; one without
/// starts on the tap.
///
/// [voiceAvailable] is whether group calls exist on this build; without them
/// Imposter's voice option is not offered.
Future<ChatGameDraft?> showGameStartSheet(
  BuildContext context, {
  required bool isDm,
  bool soloOnly = false,
  bool voiceAvailable = true,
}) {
  HapticFeedback.selectionClick();
  return showAdaptiveSheet<ChatGameDraft>(
    context,
    useSafeArea: true,
    builder: (_) => StartGameSheet(
      isDm: isDm,
      soloOnly: soloOnly,
      voiceAvailable: voiceAvailable,
    ),
  );
}

/// The sheet's body, public for tests and design previews.
class StartGameSheet extends StatefulWidget {
  const StartGameSheet({
    super.key,
    required this.isDm,
    this.soloOnly = false,
    this.voiceAvailable = true,
  });

  final bool isDm;
  final bool soloOnly;
  final bool voiceAvailable;

  @override
  State<StartGameSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<StartGameSheet> {
  late ChatGameMode _mode = widget.soloOnly
      ? ChatGameMode.bot
      : widget.isDm
      ? ChatGameMode.turns
      : ChatGameMode.live;
  BotLevel _level = BotLevel.medium;

  /// The party game whose options are open, if any.
  String? _party;
  bool _voice = false;
  String _puzzle = 'random';

  void _pick(String game) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      ChatGameDraft(
        game: game,
        mode: _mode,
        level: _mode == ChatGameMode.bot ? _level : null,
      ),
    );
  }

  /// Why [game] cannot be started from here, or null when it can.
  String? _partyBlock(AppLocalizations l10n, String game) {
    if (_mode != ChatGameMode.live) return l10n.chatGamePartyLiveOnly;
    if (widget.isDm && minSeatsOf(game) > 2) return l10n.chatGameNeedsThree;
    return null;
  }

  bool _hasOptions(String game) =>
      game == 'race' || (game == 'imposter' && widget.voiceAvailable);

  void _pickParty(String game) {
    if (!_hasOptions(game)) {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop(
        ChatGameDraft(game: game, mode: ChatGameMode.live),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _party = _party == game ? null : game);
  }

  void _setVoice(bool v) {
    HapticFeedback.selectionClick();
    setState(() => _voice = v);
  }

  /// The segmented control ticks on its own.
  void _setPuzzle(String p) => setState(() => _puzzle = p);

  void _startParty(String game) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      ChatGameDraft(
        game: game,
        mode: ChatGameMode.live,
        options: switch (game) {
          'imposter' => MatchOptions(voice: _voice),
          'race' => MatchOptions(puzzle: _puzzle == 'random' ? null : _puzzle),
          _ => MatchOptions.none,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final modeHint = switch (_mode) {
      ChatGameMode.live => l10n.chatGameModeLiveHint,
      ChatGameMode.turns => l10n.chatGameModeTurnsHint,
      ChatGameMode.bot => l10n.chatGameModeBotHint,
    };
    final levelHint = switch (_level) {
      BotLevel.easy => l10n.chatGameBotEasyHint,
      BotLevel.medium => l10n.chatGameBotMediumHint,
      BotLevel.hard => l10n.chatGameBotHardHint,
    };
    final motion = MotionScope.of(context);

    return SheetFrame(
      title: sentenceCaseOf(context, l10n.chatGameStartTitle),
      showClose: true,
      padding: EdgeInsets.zero,
      scrollsUnderInset: true,
      child: ListView(
        shrinkWrap: true,
        padding: sheetListPadding(context),
        children: [
          if (!widget.soloOnly)
          IosSegmentedControl<ChatGameMode>(
            value: _mode,
            onChanged: (m) {
              HapticFeedback.selectionClick();
              setState(() {
                _mode = m;
                if (m != ChatGameMode.live) _party = null;
              });
            },
            segments: [
              IosSegment(
                value: ChatGameMode.live,
                label: sentenceCaseOf(context, l10n.chatGameModeLive),
              ),
              if (widget.isDm)
                IosSegment(
                  value: ChatGameMode.turns,
                  label: sentenceCaseOf(context, l10n.chatGameModeTurns),
                ),
              IosSegment(
                value: ChatGameMode.bot,
                label: sentenceCaseOf(context, l10n.chatGameModeBot),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              sentenceCaseOf(context, modeHint),
              style: groupedFooterStyle(theme),
            ),
          ),
          AnimatedSize(
            duration: motion.d(theme.motionFast),
            curve: theme.motionCurve,
            alignment: Alignment.topCenter,
            child: _mode != ChatGameMode.bot
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IosSegmentedControl<BotLevel>(
                          value: _level,
                          onChanged: (l) {
                            HapticFeedback.selectionClick();
                            setState(() => _level = l);
                          },
                          segments: [
                            IosSegment(
                              value: BotLevel.easy,
                              label: sentenceCaseOf(context, l10n.gameTierEasy),
                            ),
                            IosSegment(
                              value: BotLevel.medium,
                              label: sentenceCaseOf(context, l10n.gameTierMedium),
                            ),
                            IosSegment(
                              value: BotLevel.hard,
                              label: sentenceCaseOf(context, l10n.gameTierHard),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Text(
                            sentenceCaseOf(context, levelHint),
                            style: groupedFooterStyle(theme),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              const gap = 10.0;
              final across = box.maxWidth >= 420 ? 3 : 2;
              final w = (box.maxWidth - gap * (across - 1)) / across;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final g in kChatGames)
                    SizedBox(
                      width: w,
                      child: _GameTile(game: g, onTap: () => _pick(g)),
                    ),
                ],
              );
            },
          ),
          if (!widget.soloOnly) ..._partySection(context),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.info_circle, size: 14, color: theme.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sentenceCaseOf(context, l10n.chatGameNotRanked),
                  style: groupedFooterStyle(theme),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on _StartSheetState {
  /// "Party": the three party games, their live-only note, and the options of
  /// whichever one is open.
  List<Widget> _partySection(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final note = _mode != ChatGameMode.live ? l10n.chatGamePartyLiveOnly : null;
    final open = _party;
    return [
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          sentenceCaseOf(context, l10n.chatGamePartySection),
          style: groupedHeaderStyle(theme),
        ),
      ),
      AnimatedSize(
        duration: motion.d(theme.motionFast),
        curve: theme.motionCurve,
        alignment: Alignment.topCenter,
        child: note == null
            ? const SizedBox(width: double.infinity, height: 8)
            : Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text(
                  sentenceCaseOf(context, note),
                  style: groupedFooterStyle(theme),
                ),
              ),
      ),
      LayoutBuilder(
        builder: (context, box) {
          const gap = 10.0;
          final across = box.maxWidth >= 420 ? 3 : 2;
          final w = (box.maxWidth - gap * (across - 1)) / across;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final g in kPartyGames)
                SizedBox(
                  width: w,
                  child: _GameTile(
                    key: ValueKey('party_$g'),
                    game: g,
                    selected: open == g,
                    blocked: _partyBlock(l10n, g),
                    onTap: () => _pickParty(g),
                  ),
                ),
            ],
          );
        },
      ),
      AnimatedSize(
        duration: motion.d(theme.motionMed),
        curve: theme.motionCurve,
        alignment: Alignment.topCenter,
        child: open == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _PartyOptions(
                  game: open,
                  voice: _voice,
                  puzzle: _puzzle,
                  onVoice: _setVoice,
                  onPuzzle: _setPuzzle,
                  onStart: () => _startParty(open),
                ),
              ),
      ),
    ];
  }
}

/// The open party game's options and its Start button.
class _PartyOptions extends StatelessWidget {
  const _PartyOptions({
    required this.game,
    required this.voice,
    required this.puzzle,
    required this.onVoice,
    required this.onPuzzle,
    required this.onStart,
  });

  final String game;
  final bool voice;
  final String puzzle;
  final ValueChanged<bool> onVoice;
  final ValueChanged<String> onPuzzle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (game == 'imposter')
          SheetGroup(
            children: [
              GroupedRow.toggle(
                key: const ValueKey('party_voice'),
                title: sentenceCaseOf(context, l10n.chatGameVoiceOption),
                subtitle: sentenceCaseOf(context, l10n.chatGameVoiceOptionHint),
                icon: CupertinoIcons.mic_fill,
                tone: TileTone.green,
                value: voice,
                onChanged: onVoice,
              ),
            ],
          ),
        if (game == 'race') ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              sentenceCaseOf(context, l10n.chatGamePuzzleOption),
              style: groupedHeaderStyle(theme),
            ),
          ),
          IosSegmentedControl<String>(
            value: puzzle,
            onChanged: onPuzzle,
            segments: [
              IosSegment(
                value: 'random',
                label: sentenceCaseOf(context, l10n.chatGamePuzzleRandom),
              ),
              for (final k in kRacePuzzles)
                IosSegment(value: k, label: racePuzzleName(l10n, k)),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SheetActionButton(
          key: const ValueKey('party_start'),
          label: sentenceCaseOf(
            context,
            l10n.chatGameStartNamed(chatGameName(l10n, game)),
          ),
          onTap: onStart,
        ),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    super.key,
    required this.game,
    required this.onTap,
    this.selected = false,
    this.blocked,
  });

  final String game;
  final VoidCallback onTap;

  /// Its options are open below.
  final bool selected;

  /// Why it cannot be started here; the tile is greyed and inert.
  final String? blocked;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final party = isPartyGame(game);
    final opening = party ? null : turnGameFor(game)?.initialEncoded(2);
    final name = sentenceCaseOf(context, chatGameName(l10n, game));
    final off = blocked != null;
    final tile = AnimatedContainer(
        duration: MotionScope.of(context).d(theme.motionFast),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: sheetGroupFill(theme),
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          border: Border.all(
            color: selected ? theme.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(groupedRadius(theme) - 6),
              child: AspectRatio(
                aspectRatio: 1,
                child: party
                    ? PartyGameArt(game: game)
                    : opening == null
                    ? ColoredBox(color: theme.ink.withValues(alpha: 0.05))
                    : TurnBoard(gameId: game, state: opening, thumbnail: true),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyEmph.copyWith(fontSize: 16, color: theme.ink),
            ),
            const SizedBox(height: 2),
            Text(
              chatGameDescription(l10n, game),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
            ),
            const SizedBox(height: 4),
            Text(
              chatGamePlayers(l10n, game),
              style: groupedMetaStyle(theme).copyWith(
                color: theme.inkMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    if (off) {
      return Semantics(
        enabled: false,
        label: '$name, $blocked',
        child: ExcludeSemantics(child: Opacity(opacity: 0.42, child: tile)),
      );
    }
    return SpringPress(
      onTap: onTap,
      semanticLabel: '$name, ${chatGameDescription(l10n, game)}',
      scale: 0.95,
      child: tile,
    );
  }
}
