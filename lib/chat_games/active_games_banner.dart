import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/matches_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../party_games/party_art.dart';
import '../screens/games/match_screen.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/ios_kit.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/strip_pill.dart';
import 'match_copy.dart';

/// Height the strip takes when shown, for chrome that reserves its space
/// (the floating header style): the 44pt strip, plus the gap that keeps it
/// from touching the strip below.
const kGamesBannerHeight = kGamesStripHeight + kGamesStripGap;

/// The strip itself: the height the pinned message and the suggestions strip
/// already use, so the three stack as one family under the header.
const kGamesStripHeight = 44.0;
const kGamesStripGap = 6.0;
const _kThumb = 26.0;

/// The room's open games, under the header: one line, zero height when there
/// are none.
///
/// Drawn as the pinned message's sibling, not as a call banner: a game is part
/// of the conversation the way a pin is, and in the floating style a solid
/// card stacked on a frosted pill read as two unrelated pieces of chrome. One
/// game names itself and opens straight from here;
/// several say how many and open a sheet listing them.
/// The action pill fills with the accent only when it is your move.
class ActiveGamesBanner extends StatelessWidget {
  const ActiveGamesBanner({
    super.key,
    required this.roomId,
    required this.userId,
    this.glass = false,
  });

  final String roomId;
  final String userId;

  /// Frosted and gutter-inset, for the floating chat style. Same flag, same
  /// meaning as [PinnedMessageBanner.glass].
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return ListenableBuilder(
      listenable: MatchesStore.instance,
      builder: (context, _) {
        final games = MatchesStore.instance.openIn(roomId);
        return AnimatedSize(
          duration: theme.motionFast,
          curve: theme.motionEntrance,
          alignment: Alignment.topCenter,
          child: games.isEmpty
              ? const SizedBox(width: double.infinity, height: 0)
              : _Banner(games: games, userId: userId, glass: glass),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.games,
    required this.userId,
    required this.glass,
  });

  final List<ChatMatch> games;
  final String userId;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mine = games.where((g) => g.isTurnOf(userId)).length;
    final one = games.length == 1 ? games.first : null;
    final title = one != null
        ? sentenceCaseOf(context, chatGameName(l10n, one.game))
        : sentenceCaseOf(context, l10n.chatGameBannerCount(games.length));
    final meta = sentenceCaseOf(
      context,
      one != null
          ? matchStatusLine(l10n, one, userId)
          : mine > 0
          ? l10n.chatGameBannerYourMoves(mine)
          : l10n.chatGameStatusPlaying,
    );
    void open() => one != null
        ? openMatchScreen(context, match: one, userId: userId)
        : _showList(context, userId);

    final row = SizedBox(
      height: kGamesStripHeight,
      child: Row(
        children: [
          const SizedBox(width: 9),
          _Lead(yourMove: mine > 0),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: '  $meta',
                    style: TextStyle(color: theme.inkMuted),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(color: theme.ink, fontSize: 15),
            ),
          ),
          const SizedBox(width: 6),
          StripPill(
            label: mine > 0 ? l10n.chatGamePlay : l10n.chatGameOpen,
            prominent: mine > 0,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );

    // The whole strip is the target: it does one thing, and a 44pt row whose
    // left three quarters did nothing would be a trap for the thumb.
    final tappable = FocusableTap(
      onTap: open,
      semanticLabel: '$title, $meta',
      radius: glass ? kStripGlassRadius : 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: row,
      ),
    );

    if (glass) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          kStripGlassGutter,
          0,
          kStripGlassGutter,
          kGamesStripGap,
        ),
        child: LiquidGlass(
          shape: LiquidGlassShape.rounded,
          radius: kStripGlassRadius,
          child: tappable,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: tappable,
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

/// The controller on a soft tile: the strip's glyph, the way the pin is the
/// pinned strip's. Accent when a game here is waiting on you, quiet otherwise.
/// Not the board itself: at 26pt a board is a smudge, and the name beside it
/// already says which game.
class _Lead extends StatelessWidget {
  const _Lead({required this.yourMove});

  final bool yourMove;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final tint = yourMove ? theme.accent : theme.inkMuted;
    return Container(
      width: _kThumb,
      height: _kThumb,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(CupertinoIcons.gamecontroller_fill, size: 16, color: tint),
    );
  }
}
