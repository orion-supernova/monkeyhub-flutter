import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../games/how_to/chat_guides.dart';
import '../games/how_to/how_to_play.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../party_games/party_art.dart';
import '../party_games/race_table.dart' show racePuzzleName;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import 'game_art_state.dart';
import 'match_copy.dart';
import 'play_style.dart';

/// How a chat game should be played, as the start sheet chose it.
enum ChatGameMode { live, turns }

/// What the start sheet hands back. It sends nothing itself: which room, and
/// what a refusal looks like, are the room screen's business — the same split
/// `InteractionDraft` has.
class ChatGameDraft {
  const ChatGameDraft({
    required this.game,
    required this.mode,
    this.options = MatchOptions.none,
  });

  final String game;
  final ChatGameMode mode;

  /// A party game's variant: Imposter's voice clues, Puzzle Race's puzzle.
  final MatchOptions options;

  MatchMode get matchMode =>
      mode == ChatGameMode.turns ? MatchMode.async : MatchMode.live;
}

/// The party games a room lists, in the sheet's order. A room that can never
/// seat a game does not list it: a DM will always be two people, so Imposter,
/// which needs three, is simply not there. A group that is only too small
/// right now still lists it, greyed with what it needs ([isTooSmallFor]):
/// adding someone fixes that, and the shelf is where people learn the game
/// exists at all.
///
/// The board games all seat two, so every room gets all of them.
List<String> partyGamesFor({required bool isDm}) => [
  for (final g in kPartyGames)
    if (!isDm || minSeatsOf(g) <= 2) g,
];

/// The ways [game] can be played in this room. Take turns is a DM thing (the
/// server refuses it elsewhere, `ASYNC_DM_ONLY`) and party games are live
/// only, because a round of Liar's Dice spread over two days is not a round.
/// Whether a group of [memberCount] people is too small to start [game].
/// Null is a count we do not know, which never blocks.
bool isTooSmallFor(String game, int? memberCount) =>
    memberCount != null && memberCount < minSeatsOf(game);

List<PlayStyle> playStylesOf(String game, {required bool isDm}) => [
  if (isDm && !isPartyGame(game)) PlayStyle.turns,
  PlayStyle.live,
];

/// "Play a game": pick one, then how.
///
/// Two screens inside one sheet. The first is the shelf: board games, then
/// party games, each tile carrying coloured badges for how it can be played
/// here. Tapping one slides to its own page: the art large, what it is, the
/// ways to play it spelled out (live pauses when someone leaves; turns get
/// two days a move, with reminders and a nudge), its options, and Start.
///
/// Bots are not here. A game against the app is not a chat thing; it lives
/// on the Feed's games row ([BotHubScreen]).
///
/// [voiceAvailable] is whether group calls exist on this build; without them
/// Imposter's voice option is not offered. [memberCount] is the room's size,
/// for greying out a party game it cannot seat yet.
Future<ChatGameDraft?> showGameStartSheet(
  BuildContext context, {
  required bool isDm,
  bool voiceAvailable = true,
  int? memberCount,
}) {
  HapticFeedback.selectionClick();
  return showAdaptiveSheet<ChatGameDraft>(
    context,
    useSafeArea: true,
    builder: (_) => StartGameSheet(
      isDm: isDm,
      voiceAvailable: voiceAvailable,
      memberCount: memberCount,
    ),
  );
}

/// The sheet's body, public for tests and design previews.
class StartGameSheet extends StatefulWidget {
  const StartGameSheet({
    super.key,
    required this.isDm,
    this.voiceAvailable = true,
    this.memberCount,
    this.initialGame,
  });

  final bool isDm;
  final bool voiceAvailable;

  /// How many people are in the room, or null when not known.
  final int? memberCount;

  /// Opens straight onto this game's page. For previews.
  final String? initialGame;

  @override
  State<StartGameSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<StartGameSheet> {
  /// The game whose page is showing, or null for the shelf.
  late String? _open = widget.initialGame;

  /// Whether the last move between shelf and page went forward, for the
  /// slide's direction.
  bool _forward = true;

  late PlayStyle _style = widget.isDm ? PlayStyle.turns : PlayStyle.live;
  bool _voice = false;
  String _puzzle = 'random';

  void _openGame(String game) {
    final styles = playStylesOf(game, isDm: widget.isDm);
    setState(() {
      _forward = true;
      _open = game;
      // A DM board game opens on Take turns, the way a game between two
      // people who are not both looking at their phones gets played at all.
      _style = styles.first;
    });
  }

  void _back() {
    HapticFeedback.selectionClick();
    setState(() {
      _forward = false;
      _open = null;
    });
  }

  void _setStyle(PlayStyle s) {
    if (s == _style) return;
    setState(() => _style = s);
  }

  void _setVoice(bool v) {
    HapticFeedback.selectionClick();
    setState(() => _voice = v);
  }

  /// The segmented control ticks on its own.
  void _setPuzzle(String p) => setState(() => _puzzle = p);

  void _start(String game) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      ChatGameDraft(
        game: game,
        mode: _style == PlayStyle.turns ? ChatGameMode.turns : ChatGameMode.live,
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
    final motion = MotionScope.of(context);
    final open = _open;
    final page = open == null
        ? _Shelf(
            key: const ValueKey('shelf'),
            isDm: widget.isDm,
            memberCount: widget.memberCount,
            onPick: _openGame,
          )
        : _GamePage(
            key: ValueKey('page_$open'),
            game: open,
            styles: playStylesOf(open, isDm: widget.isDm),
            style: _style,
            voiceAvailable: widget.voiceAvailable,
            voice: _voice,
            puzzle: _puzzle,
            onStyle: _setStyle,
            onVoice: _setVoice,
            onPuzzle: _setPuzzle,
            onStart: () => _start(open),
            group: !widget.isDm,
          );
    final forward = _forward;
    return PopScope(
      // Back (Esc, the system gesture) steps from a game's page to the shelf
      // before it closes the sheet.
      canPop: open == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open != null) _back();
      },
      child: SheetFrame(
        title: open == null
            ? sentenceCaseOf(context, l10n.chatGameStartTitle)
            : sentenceCaseOf(context, chatGameName(l10n, open)),
        showClose: true,
        closeIsBack: open != null,
        onClose: open == null ? null : _back,
        padding: EdgeInsets.zero,
        scrollsUnderInset: true,
        child: AnimatedSize(
          duration: motion.d(theme.motionMed),
          curve: theme.motionCurve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: motion.d(theme.motionMed),
            switchInCurve: theme.motionCurve,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, anim) {
              final incoming = child.key == page.key;
              // Pages slide in from the trailing edge going forward and from
              // the leading edge coming back, a fifth of a width: enough to
              // read as moving between two places, not so much that the
              // sheet looks like it is being swapped out.
              final dx = (incoming == forward ? 0.2 : -0.2);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(dx, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: page,
          ),
        ),
      ),
    );
  }
}

/// The shelf: board games, then party games, each section with the one line
/// that says how its games are played in this room.
class _Shelf extends StatelessWidget {
  const _Shelf({
    super.key,
    required this.isDm,
    required this.onPick,
    this.memberCount,
  });

  final bool isDm;
  final int? memberCount;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final party = partyGamesFor(isDm: isDm);
    var rise = 0;
    Widget section(String title, String hint, List<String> games) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            sentenceCaseOf(context, title),
            style: groupedHeaderStyle(theme),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text(hint, style: groupedFooterStyle(theme)),
        ),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 10.0;
            final across = box.maxWidth >= 560
                ? 4
                : box.maxWidth >= 420
                ? 3
                : 2;
            final w = (box.maxWidth - gap * (across - 1)) / across;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final g in games)
                  SizedBox(
                    width: w,
                    child: SheetRise(
                      index: rise++,
                      child: _GameTile(
                        key: ValueKey('game_$g'),
                        game: g,
                        styles: playStylesOf(g, isDm: isDm),
                        tooSmall: isTooSmallFor(g, memberCount),
                        onTap: () => onPick(g),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
    return ListView(
      shrinkWrap: true,
      padding: sheetListPadding(context),
      children: [
        section(
          l10n.chatGameSectionBoards,
          isDm ? l10n.chatGameBoardsHintDm : l10n.chatGameBoardsHintGroup,
          kChatGames,
        ),
        if (party.isNotEmpty) ...[
          const SizedBox(height: 22),
          section(l10n.chatGameSectionParty, l10n.chatGamePartyHint, party),
        ],
        const SizedBox(height: 16),
        _NotRanked(),
      ],
    );
  }
}

class _NotRanked extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
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
    );
  }
}

/// [game]'s picture: a party game's own art, or a board game's opening
/// position drawn by the real board.
class ChatGameArt extends StatelessWidget {
  const ChatGameArt({super.key, required this.game});

  final String game;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (isPartyGame(game)) return PartyGameArt(game: game);
    final opening = chatGameArtState(game);
    if (opening == null) {
      return ColoredBox(color: theme.ink.withValues(alpha: 0.05));
    }
    return TurnBoard(gameId: game, state: opening, thumbnail: true);
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    super.key,
    required this.game,
    required this.styles,
    required this.onTap,
    this.tooSmall = false,
  });

  final String game;
  final List<PlayStyle> styles;
  final VoidCallback onTap;

  /// The room has fewer people than the game seats: the tile stays on the
  /// shelf, faded, saying what it needs, and does not open.
  final bool tooSmall;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final name = sentenceCaseOf(context, chatGameName(l10n, game));
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: sheetGroupFill(theme),
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
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodyEmph.copyWith(fontSize: 16, color: theme.ink),
          ),
          const SizedBox(height: 2),
          Text(
            tooSmall
                ? l10n.chatGameNeedsPeople(minSeatsOf(game))
                : chatGamePlayers(l10n, game),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedMetaStyle(theme).copyWith(
              color: tooSmall ? theme.ink : theme.inkMuted,
              fontSize: 12,
              fontWeight: tooSmall ? FontWeight.w600 : null,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [for (final s in styles) PlayStyleBadge(s)],
          ),
        ],
      ),
    );
    if (tooSmall) {
      return Semantics(
        button: true,
        enabled: false,
        label: '$name, ${l10n.chatGameNeedsPeople(minSeatsOf(game))}',
        excludeSemantics: true,
        child: Opacity(opacity: 0.45, child: tile),
      );
    }
    return SpringPress(
      onTap: onTap,
      semanticLabel: [
        name,
        chatGameDescription(l10n, game),
        for (final s in styles) s.badge(l10n),
      ].join(', '),
      scale: 0.95,
      child: tile,
    );
  }
}

/// One game's page: what it is, how it can be played here, its options, and
/// Start.
class _GamePage extends StatelessWidget {
  const _GamePage({
    super.key,
    required this.game,
    required this.styles,
    required this.style,
    required this.voiceAvailable,
    required this.voice,
    required this.puzzle,
    required this.onStyle,
    required this.onVoice,
    required this.onPuzzle,
    required this.onStart,
    this.group = false,
  });

  /// A group chat: the guide also covers watching and seat swaps.
  final bool group;

  final String game;
  final List<PlayStyle> styles;
  final PlayStyle style;
  final bool voiceAvailable;
  final bool voice;
  final String puzzle;
  final ValueChanged<PlayStyle> onStyle;
  final ValueChanged<bool> onVoice;
  final ValueChanged<String> onPuzzle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final name = sentenceCaseOf(context, chatGameName(l10n, game));
    final choice = styles.length > 1;
    return ListView(
      shrinkWrap: true,
      padding: sheetListPadding(context),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(groupedRadius(theme)),
                child: ChatGameArt(game: game),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatGameDescription(l10n, game),
                    style: theme.body.copyWith(
                      color: theme.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    chatGamePlayers(l10n, game),
                    style: groupedMetaStyle(theme).copyWith(
                      color: theme.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HowToPill(
                    onTap: () => showHowToPlay(
                      context,
                      chatGuide(
                        l10n,
                        game,
                        modes: styles,
                        group: group,
                        voice: game == 'imposter' && voice,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (choice)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              sentenceCaseOf(context, l10n.chatGameHowWillYouPlay),
              style: groupedHeaderStyle(theme),
            ),
          ),
        for (final (i, s) in styles.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          SheetRise(
            index: i,
            child: PlayStyleCard(
              key: ValueKey('mode_${s.name}'),
              style: s,
              selected: choice && s == style,
              onTap: choice ? () => onStyle(s) : null,
            ),
          ),
        ],
        if (game == 'imposter' && voiceAvailable) ...[
          const SizedBox(height: 14),
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
        ],
        if (game == 'race') ...[
          const SizedBox(height: 16),
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
        const SizedBox(height: 20),
        SheetActionButton(
          key: const ValueKey('game_start'),
          icon: style.icon,
          haptic: false,
          label: sentenceCaseOf(context, l10n.chatGameStartNamed(name)),
          onTap: onStart,
        ),
        const SizedBox(height: 14),
        _NotRanked(),
      ],
    );
  }
}

/// "How to play" on a game's page: the full guide, rules and both ways of
/// playing it here, with the little animated boards.
class _HowToPill extends StatelessWidget {
  const _HowToPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final label = sentenceCaseOf(context, l10n.gameInfoOpen);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SpringPress(
        key: const ValueKey('game_how_to'),
        onTap: onTap,
        semanticLabel: label,
        scale: PressSpec.scaleSmall,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.play_circle_fill, size: 15, color: theme.accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: groupedMetaStyle(theme).copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
