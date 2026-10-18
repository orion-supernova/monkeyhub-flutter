import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_games/match_copy.dart';
import '../chat_games/match_face.dart';
import '../chat_games/watcher_faces.dart';
import '../data/matches_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../models/chat_message.dart';
import '../party_games/party_art.dart';
import '../screens/games/match_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import 'action_buttons.dart';
import 'attachment_bubble_frame.dart';
import 'game_tile.dart' show StatusChip;
import 'message_stamp.dart';
import 'skeleton_rows.dart';

/// An in-chat game's card in the transcript.
///
/// Two sources, the way a poll card has two: the game's NAME comes from the
/// message (`content`), so the card says what it is on the first frame, and
/// the live body — seats, board, result — from [MatchesStore], which may land
/// a beat later. Until it does, a skeleton of the same height holds the
/// place, so nothing below jumps when it arrives.
///
/// The card never posts anything itself and never changes the message: a
/// move updates the game row, the store hears it, and this redraws. A whole
/// game of Connect Four is one card that changes, not forty messages.
///
/// Every tap opens the game ([MatchScreen]). "Join" on a lobby with an open
/// seat sits down first, so the button means what it says.
///
/// A party game has no board worth a thumbnail (its table is mostly secrets),
/// so while it is played the card shows who is at the table and the phase
/// line instead: "Round 2 · 14 dice", "Voting", "3 of 5 finished".
class GameBubble extends StatelessWidget {
  const GameBubble({
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

  @override
  Widget build(BuildContext context) {
    final store = MatchesStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final match = store.forMessage(message.id);
        if (match == null && currentUserId.isNotEmpty) {
          // Scrolled back past the room's live window: hydrate once.
          store.ensureFor(currentUserId, [message.id]);
        }
        return _Card(
          theme: theme,
          message: message,
          match: match,
          width: width,
          radius: radius,
          viewerId: currentUserId,
          stamp: stamp,
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.theme,
    required this.message,
    required this.match,
    required this.width,
    required this.radius,
    required this.viewerId,
    this.stamp,
  });

  final AppTheme theme;
  final ChatMessage message;
  final ChatMatch? match;
  final double width;
  final BorderRadius radius;
  final String viewerId;
  final MessageStamp? stamp;

  void _open(BuildContext context) {
    final m = match;
    if (m == null) return;
    HapticFeedback.selectionClick();
    openMatchScreen(context, match: m, userId: viewerId);
  }

  Future<void> _join(BuildContext context) async {
    final m = match;
    if (m == null) return;
    HapticFeedback.selectionClick();
    try {
      await MatchesStore.instance.api.join(viewerId, m.id);
    } catch (_) {
      // Lost the race for the seat: open it anyway, where the lobby shows
      // what happened.
    }
    if (context.mounted) openMatchScreen(context, match: m, userId: viewerId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = match;
    final name = m == null
        ? message.content
        : chatGameName(l10n, m.game);
    final semantics = m == null
        ? name
        : '$name, ${matchStatusLine(l10n, m, viewerId)}';

    return FocusableTap(
      onTap: m == null ? null : () => _open(context),
      enabled: m != null,
      semanticLabel: semantics,
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
                      label: sentenceCaseOf(
                        context,
                        m?.mode == MatchMode.async
                            ? l10n.chatGameKindTurns
                            : l10n.chatGameKindLive,
                      ),
                    ),
                  ),
                  if (m != null) _StatusChip(match: m),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyEmph.copyWith(
                  color: theme.ink,
                  fontSize: 17,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              if (m == null)
                const _BodySkeleton()
              else if (m.status == MatchStatus.lobby)
                _LobbyBody(match: m, viewerId: viewerId)
              else if (m.party)
                _PartyBody(match: m, viewerId: viewerId)
              else
                _BoardBody(match: m, viewerId: viewerId),
              const SizedBox(height: 10),
              _Footer(
                theme: theme,
                match: m,
                viewerId: viewerId,
                stamp: stamp,
                onOpen: () => _open(context),
                onJoin: () => _join(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.match});

  final ChatMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final (label, tone, icon) = switch (match.status) {
      MatchStatus.lobby => (
        l10n.chatGameStatusWaiting,
        theme.inkMuted,
        CupertinoIcons.hourglass,
      ),
      MatchStatus.active => (
        l10n.chatGameStatusPlaying,
        theme.success,
        CupertinoIcons.circle_fill,
      ),
      MatchStatus.paused => (
        l10n.chatGameStatusPaused,
        theme.inkSoft,
        CupertinoIcons.pause_fill,
      ),
      MatchStatus.finished => (
        l10n.chatGameStatusFinished,
        theme.inkSoft,
        CupertinoIcons.flag_fill,
      ),
      MatchStatus.abandoned => (
        l10n.chatGameStatusEnded,
        theme.inkMuted,
        CupertinoIcons.xmark,
      ),
    };
    return StatusChip(
      label: sentenceCaseOf(context, label),
      tone: tone,
      icon: icon,
    );
  }
}

/// The lobby: who has sat down, ready or not, and the seats still open.
class _LobbyBody extends StatelessWidget {
  const _LobbyBody({required this.match, required this.viewerId});

  final ChatMatch match;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = SeatPalette(theme, gameId: match.game);
    final capacity = maxSeatsOf(match.game);
    // Two open seats in a four-seat game are one placeholder: the card is a
    // summary, and four empty circles read as four people missing.
    final open = (capacity - match.seats.length).clamp(0, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            for (var i = 0; i < match.seats.length; i++)
              _SeatChip(
                roomId: match.roomId,
                userId: match.seats[i].userId,
                name: seatName(l10n, match, i, viewerId),
                ring: palette.fill(i),
                ready: match.seats[i].ready,
              ),
            if (open > 0) const _OpenSeat(),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          sentenceCaseOf(context, matchStatusLine(l10n, match, viewerId)),
          style: attachmentMetaStyle(theme),
        ),
      ],
    );
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({
    required this.roomId,
    required this.userId,
    required this.name,
    required this.ring,
    required this.ready,
  });

  final String roomId;
  final String userId;
  final String name;
  final Color ring;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 2.5),
            ),
            child: MatchFace(
              roomId: roomId,
              userId: userId,
              name: name,
              size: 38,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: attachmentMetaStyle(theme).copyWith(
              color: theme.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            sentenceCaseOf(
              context,
              ready ? l10n.chatGameReady : l10n.chatGameNotReady,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: attachmentMetaStyle(theme).copyWith(
              fontSize: 12,
              color: ready ? theme.success : attachmentSecondaryInk(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSeat extends StatelessWidget {
  const _OpenSeat();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.ink.withValues(alpha: 0.06),
            ),
            child: Icon(
              CupertinoIcons.plus,
              size: 20,
              color: attachmentActionInk(theme),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sentenceCaseOf(context, l10n.chatGameOpenSeat),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: attachmentMetaStyle(theme),
          ),
        ],
      ),
    );
  }
}

/// A game under way or over: the board as it stands, and who is where.
class _BoardBody extends StatelessWidget {
  const _BoardBody({required this.match, required this.viewerId});

  final ChatMatch match;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = SeatPalette(theme, gameId: match.game);
    final state = match.state;
    final status = matchStatusLine(l10n, match, viewerId);
    final mine = match.isTurnOf(viewerId);
    final left = match.mode == MatchMode.async && match.isSeated(viewerId)
        ? matchTimeLeft(l10n, match, DateTime.now())
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          child: SizedBox(
            width: 96,
            height: 96,
            child: state == null
                ? ColoredBox(color: theme.ink.withValues(alpha: 0.05))
                : TurnBoard(
                    gameId: match.game,
                    state: state,
                    thumbnail: true,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < match.seats.length && i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.fill(i),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          seatName(l10n, match, i, viewerId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: attachmentMetaStyle(theme).copyWith(
                            color: match.seats[i].out
                                ? attachmentSecondaryInk(theme)
                                : theme.ink,
                            fontWeight: match.turnSeat == i &&
                                    match.status == MatchStatus.active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            decoration: match.seats[i].out
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                sentenceCaseOf(context, status),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: attachmentMetaStyle(theme).copyWith(
                  color: mine ? theme.accent : attachmentSecondaryInk(theme),
                  fontWeight: mine ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (left != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sentenceCaseOf(context, left),
                    style: attachmentMetaStyle(theme).copyWith(fontSize: 12),
                  ),
                ),
              if (!match.status.isOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sentenceCaseOf(context, l10n.chatGameNotRankedShort),
                    style: attachmentMetaStyle(theme).copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A party game under way or over: the table's faces, and where it stands.
class _PartyBody extends StatelessWidget {
  const _PartyBody({required this.match, required this.viewerId});

  final ChatMatch match;
  final String viewerId;

  /// Faces shown before the rest fold into a "+N".
  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = SeatPalette(theme, gameId: match.game);
    final status = matchStatusLine(l10n, match, viewerId);
    final mine = match.isTurnOf(viewerId);
    final seats = match.seats;
    final extra = seats.length - _shown;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          child: SizedBox(
            width: 64,
            height: 64,
            child: PartyGameArt(game: match.game),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 30,
                child: Row(
                  children: [
                    for (var i = 0; i < seats.length && i < _shown; i++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 4),
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: match.turnSeat == i &&
                                      match.status == MatchStatus.active
                                  ? palette.fill(i)
                                  : palette.fill(i).withValues(alpha: 0.45),
                              width: 2,
                            ),
                          ),
                          child: Opacity(
                            opacity: seats[i].out ? 0.4 : 1,
                            child: MatchFace(
                              roomId: match.roomId,
                              userId: seats[i].userId,
                              name: seats[i].name,
                              size: 23,
                            ),
                          ),
                        ),
                      ),
                    if (extra > 0)
                      Text(
                        '+$extra',
                        style: attachmentMetaStyle(theme).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sentenceCaseOf(context, status),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: attachmentMetaStyle(theme).copyWith(
                  color: mine ? theme.accent : theme.ink,
                  fontWeight: mine ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (!match.status.isOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sentenceCaseOf(context, l10n.chatGameNotRankedShort),
                    style: attachmentMetaStyle(theme).copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 96,
    child: Row(
      children: [
        SkeletonBox(width: 96, height: 96, radius: 10),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 90, height: 12, radius: 6),
              SizedBox(height: 8),
              SkeletonBox(width: 70, height: 12, radius: 6),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.theme,
    required this.match,
    required this.viewerId,
    required this.onOpen,
    required this.onJoin,
    this.stamp,
  });

  final AppTheme theme;
  final ChatMatch? match;
  final String viewerId;
  final VoidCallback onOpen;
  final VoidCallback onJoin;
  final MessageStamp? stamp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = match;
    Widget? action;
    if (m != null) {
      final seated = m.isSeated(viewerId);
      if (m.status == MatchStatus.lobby) {
        action = seated
            ? RowPillButton(label: l10n.chatGameOpen, onTap: onOpen)
            : m.seats.length < maxSeatsOf(m.game)
            ? RowPillButton(label: l10n.chatGameJoin, onTap: onJoin, filled: true)
            : RowPillButton(label: l10n.chatGameWatch, onTap: onOpen);
      } else if (m.status.isOpen) {
        action = m.isTurnOf(viewerId)
            ? RowPillButton(label: l10n.chatGamePlay, onTap: onOpen, filled: true)
            : RowPillButton(
                label: seated ? l10n.chatGameOpen : l10n.chatGameWatch,
                onTap: onOpen,
              );
      }
    }
    final watching = m != null && m.watching > 0 && m.status.isOpen
        ? l10n.chatGameWatchingCount(m.watching)
        : null;
    return Row(
      children: [
        ?action,
        if (action != null && watching != null) const SizedBox(width: 10),
        if (watching != null) ...[
          WatcherStack(match: m!, ring: attachmentBubbleFill(theme)),
          if (m.watcherIds.isNotEmpty) const SizedBox(width: 6),
        ],
        if (watching != null)
          Flexible(
            child: Text(
              watching,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: attachmentMetaStyle(theme),
            ),
          ),
        const Spacer(),
        if (stamp != null) KeyedSubtree(key: kVisibleStampKey, child: stamp!),
      ],
    );
  }
}
