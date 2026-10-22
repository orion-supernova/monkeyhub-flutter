import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_games/match_copy.dart';
import '../chat_games/move_notation.dart';
import '../data/matches_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../models/chat_message.dart';
import '../models/game_move.dart';
import '../screens/games/match_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import 'action_buttons.dart';
import 'attachment_bubble_frame.dart';
import 'message_stamp.dart';

/// One move of a turn by turn game, as it lands in the chat: who moved, what
/// they played, and the board it left.
///
/// The board is drawn from the row (`ChatMessage.gameMove`), never from the
/// game, so a transcript of forty moves is forty pictures and no
/// subscriptions. Only the footer ("Your move", "Waiting for Bob", who won)
/// reads [MatchesStore], which the room already watches, and only the
/// footer rebuilds when a game changes.
///
/// A tap opens the game. The newest move whose turn is the viewer's wears the
/// filled Play button; an older move says so and stays quiet.
class GameMoveBubble extends StatelessWidget {
  const GameMoveBubble({
    super.key,
    required this.theme,
    required this.message,
    required this.isMine,
    required this.width,
    required this.radius,
    required this.currentUserId,
    this.stamp,
  });

  final AppTheme theme;
  final ChatMessage message;
  final bool isMine;
  final double width;
  final BorderRadius radius;
  final String currentUserId;
  final MessageStamp? stamp;

  void _open(BuildContext context, GameMoveSnapshot snap) {
    HapticFeedback.selectionClick();
    final known = MatchesStore.instance.forMatch(snap.matchId);
    if (known != null) {
      openMatchScreen(context, match: known, userId: currentUserId);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchScreen(matchId: snap.matchId, userId: currentUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snap = message.gameMove;
    final name = snap == null ? '' : chatGameName(l10n, snap.game);
    final who = isMine
        ? l10n.chatGameMvYouPlayed
        : l10n.chatGameMvTheyPlayed(message.resolvedSenderName(context));
    final notation = snap == null
        ? null
        : moveNotation(l10n, snap.game, snap.move);
    final palette = snap == null
        ? null
        : SeatPalette(theme, gameId: snap.game);
    final seatColor = palette?.fill(snap!.seat) ?? theme.accent;
    // Chess and checkers turn the board round for the viewer's own side.
    final viewerSeat = snap == null
        ? null
        : isMine
        ? snap.seat
        : 1 - snap.seat;

    return FocusableTap(
      onTap: snap == null ? null : () => _open(context, snap),
      enabled: snap != null,
      semanticLabel: [
        name,
        who,
        ?notation,
        if (snap != null) l10n.chatGameMvNumber(snap.seq),
      ].join(', '),
      radius: radius.topLeft.x,
      child: AttachmentBubbleFrame(
        theme: theme,
        radius: radius,
        width: width,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AttachmentKindLabel(
                      theme: theme,
                      icon: CupertinoIcons.gamecontroller_fill,
                      label: snap == null
                          ? message.content
                          : '${sentenceCaseOf(context, name)} · '
                                '${l10n.chatGameMvNumber(snap.seq)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _SeatDot(color: seatColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyEmph.copyWith(
                        color: theme.ink,
                        fontSize: 17,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (notation != null) ...[
                    const SizedBox(width: 8),
                    _NotationChip(
                      text: notation,
                      wash: palette!.wash(snap!.seat),
                    ),
                  ],
                ],
              ),
              if (snap != null) ...[
                const SizedBox(height: 10),
                // Its own layer: a footer change (the other player moved)
                // never repaints the board.
                RepaintBoundary(
                  child: _Board(snap: snap, viewerSeat: viewerSeat),
                ),
              ],
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: MatchesStore.instance,
                builder: (context, _) => _Footer(
                  theme: theme,
                  snap: snap,
                  match: snap == null
                      ? null
                      : MatchesStore.instance.forMatch(snap.matchId),
                  viewerId: currentUserId,
                  stamp: stamp,
                  onOpen: snap == null ? null : () => _open(context, snap),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatDot extends StatelessWidget {
  const _SeatDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      // A hairline, so Reversi's black seat still shows on a dark bubble.
      border: Border.all(
        color: ThemeScope.of(context).ink.withValues(alpha: 0.22),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
      ],
    ),
  );
}

class _NotationChip extends StatelessWidget {
  const _NotationChip({required this.text, required this.wash});

  final String text;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Over a faint ink base: a black seat's wash alone is invisible on
        // a dark bubble.
        color: Color.alphaBlend(wash, theme.ink.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: attachmentMetaStyle(theme).copyWith(
          color: theme.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The board the move made, as large as the bubble allows, with the move
/// itself highlighted.
class _Board extends StatelessWidget {
  const _Board({required this.snap, required this.viewerSeat});

  final GameMoveSnapshot snap;
  final int? viewerSeat;

  /// Tall enough to read a chess position, short enough that a run of moves
  /// stays a conversation rather than a gallery.
  static const _maxSide = 196.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final aspect = TurnBoard.aspectRatioOf(snap.game, snap.state, thumbnail: true);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxSide, maxHeight: _maxSide),
        child: AspectRatio(
          aspectRatio: aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusMd),
            child: TurnBoard(
              gameId: snap.game,
              state: snap.state,
              mySeat: viewerSeat,
              lastMove: snap.move,
              thumbnail: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.theme,
    required this.snap,
    required this.match,
    required this.viewerId,
    required this.onOpen,
    this.stamp,
  });

  final AppTheme theme;
  final GameMoveSnapshot? snap;
  final ChatMatch? match;
  final String viewerId;
  final VoidCallback? onOpen;
  final MessageStamp? stamp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = match;
    final s = snap;
    // The game as it stands, read only while this is its newest move.
    final latest = m != null && s != null && m.seq == s.seq;
    String? line;
    var accent = false;
    Widget? action;
    if (latest) {
      if (!m.status.isOpen) {
        line = matchResultLine(l10n, m, viewerId);
        accent = m.winner != null && m.seats[m.winner!].userId == viewerId;
      } else if (m.isTurnOf(viewerId)) {
        line = l10n.chatGameYourMove;
        accent = true;
        action = RowPillButton(
          label: l10n.chatGamePlay,
          onTap: onOpen,
          filled: true,
        );
      } else if (m.turnSeat != null && m.isSeated(viewerId)) {
        line = l10n.chatGameWaitingFor(m.seats[m.turnSeat!].name);
      }
    } else if (m != null && s != null && m.seq > s.seq) {
      line = l10n.chatGameMvEarlier;
    }
    return Row(
      children: [
        ?action,
        if (action != null) const SizedBox(width: 10),
        if (line != null)
          Flexible(
            child: Text(
              sentenceCaseOf(context, line),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: attachmentMetaStyle(theme).copyWith(
                color: accent ? theme.accent : attachmentSecondaryInk(theme),
                fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        const Spacer(),
        if (stamp != null) KeyedSubtree(key: kVisibleStampKey, child: stamp!),
      ],
    );
  }
}
