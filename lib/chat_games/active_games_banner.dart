import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../calls/widgets/call_chrome.dart';
import '../data/matches_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../party_games/party_art.dart';
import '../screens/games/match_screen.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import 'match_copy.dart';

/// Height the banner takes when shown, for chrome that reserves its space
/// (the floating header style). Padding plus the shared banner's one row.
const kGamesBannerHeight = 64.0;

/// The room's open games, under the header: one line, zero height when there
/// are none.
///
/// Built on the shared [CallStatusBanner], neutral like the "call in progress"
/// banner for a call you are not in — the room is not asking anything of you
/// unless it is your move, and then the action says so. One game is opened
/// straight from here; several open a sheet listing them.
class ActiveGamesBanner extends StatelessWidget {
  const ActiveGamesBanner({
    super.key,
    required this.roomId,
    required this.userId,
  });

  final String roomId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MatchesStore.instance,
      builder: (context, _) {
        final games = MatchesStore.instance.openIn(roomId);
        if (games.isEmpty) return const SizedBox.shrink();
        return _Banner(games: games, userId: userId);
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.games, required this.userId});

  final List<ChatMatch> games;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine = games.where((g) => g.isTurnOf(userId)).length;
    final one = games.length == 1 ? games.first : null;
    final title = one != null
        ? sentenceCaseOf(context, chatGameName(l10n, one.game))
        : sentenceCaseOf(context, l10n.chatGameBannerCount(games.length));
    final meta = one != null
        ? matchStatusLine(l10n, one, userId)
        : mine > 0
        ? l10n.chatGameBannerYourMoves(mine)
        : l10n.chatGameStatusPlaying;
    void open() => one != null
        ? openMatchScreen(context, match: one, userId: userId)
        : _showList(context, userId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: CallStatusBanner(
        tone: CallBannerTone.neutral,
        icon: CupertinoIcons.gamecontroller_fill,
        title: title,
        meta: Text(sentenceCaseOf(context, meta)),
        onTap: open,
        semanticLabel: '$title, $meta',
        actions: [
          CallBannerAction(
            icon: CupertinoIcons.play_fill,
            label: mine > 0 ? l10n.chatGamePlay : l10n.chatGameOpen,
            semanticLabel: mine > 0 ? l10n.chatGamePlay : l10n.chatGameOpen,
            prominent: mine > 0,
            onTap: open,
          ),
        ],
      ),
    );
  }

  void _showList(BuildContext context, String userId) {
    showAdaptiveSheet<void>(
      context,
      useSafeArea: true,
      builder: (sheet) {
        final theme = ThemeScope.of(sheet);
        final l10n = AppLocalizations.of(sheet);
        return SheetFrame(
          title: sentenceCaseOf(sheet, l10n.chatGameSheetTitle),
          showClose: true,
          padding: EdgeInsets.zero,
          scrollsUnderInset: true,
          child: ListView(
            shrinkWrap: true,
            padding: sheetListPadding(sheet),
            children: [
              SheetGroup(
                children: [
                  for (final g in games)
                    GroupedRow(
                      title: sentenceCaseOf(sheet, chatGameName(l10n, g.game)),
                      subtitle: sentenceCaseOf(
                        sheet,
                        matchStatusLine(l10n, g, userId),
                      ),
                      trailing: g.state == null && !g.party
                          ? null
                          : SizedBox(
                              width: 40,
                              height: 40,
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(theme.radiusSm),
                                // A party game's state is a public view,
                                // not a board: its picture stands in.
                                child: g.party
                                    ? PartyGameArt(game: g.game)
                                    : TurnBoard(
                                        gameId: g.game,
                                        state: g.state!,
                                        thumbnail: true,
                                      ),
                              ),
                            ),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        openMatchScreen(context, match: g, userId: userId);
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
