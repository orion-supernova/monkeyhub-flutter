import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/challenges_store.dart';
import '../data/feed_store.dart';
import '../games/game_names.dart';
import '../games/ranking.dart' show rankByPlace;
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_message.dart';
import '../models/daily_game.dart';
import '../screens/games/daily_game_screens.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'attachment_bubble_frame.dart';
import 'message_stamp.dart';
import 'score_row.dart';
import 'settings_pickers.dart' show GroupedFooter;
import 'sheet_kit.dart';
import 'skeleton_rows.dart';
import 'spring_press.dart';

/// A "Beat my time" card: a friend's finished daily result, sent as a dare.
///
/// The headline and the time come from the challenge itself (fetched once —
/// it never changes); the verdict comes from the viewer's OWN result for the
/// same board, read off the Feed's board, so it updates the moment they
/// finish without the card subscribing to anything. A challenge from an
/// earlier day still shows its time, but the board it named has closed, so
/// there is nothing to play.
///
/// Under it, "who played": the room's finished results for the same board
/// (`challenges:roomResults`), one-shot and shared by every card of that
/// board in the room — see [ChallengesStore.ensureRoomResults].
class ChallengeBubble extends StatelessWidget {
  const ChallengeBubble({
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
    final store = ChallengesStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, FeedStore.instance]),
      builder: (context, _) {
        final c = store.forMessage(message.id);
        if (c == null && currentUserId.isNotEmpty) {
          store.ensureFor(currentUserId, [message.id]);
        }
        if (c != null) {
          final feed = FeedStore.instance;
          final own = feed.games[c.game];
          store.ensureRoomResults(
            userId: currentUserId,
            roomId: message.roomId,
            game: c.game,
            dayKey: c.dayKey,
            // Refetched the moment the viewer's own row would appear.
            viewerFinished:
                c.dayKey == feed.dayKey && own != null && own.finished,
          );
        }
        return _Card(
          theme: theme,
          message: message,
          challenge: c,
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
    required this.challenge,
    required this.width,
    required this.radius,
    required this.viewerId,
    this.stamp,
  });

  final AppTheme theme;
  final ChatMessage message;
  final GameChallenge? challenge;
  final double width;
  final BorderRadius radius;
  final String viewerId;
  final MessageStamp? stamp;

  void _play(BuildContext context, GameChallenge c) {
    HapticFeedback.selectionClick();
    // The dare rides this route only, never a global: see [ChallengeScope].
    final target = ChallengeTarget.of(c, roomId: message.roomId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => dailyGameScreen(c.game, viewerId, challenge: target),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = challenge;
    final mine = c != null && c.userId == viewerId;
    final today = c != null && c.dayKey == FeedStore.instance.dayKey;
    final result = c == null ? null : FeedStore.instance.games[c.game];
    final played = today && result != null && result.finished;
    String? verdict;
    Color? verdictColor;
    if (c != null && !mine) {
      if (!today) {
        verdict = l10n.challengeClosed;
      } else if (played && result.solved && result.durationMs != null) {
        // Whole seconds, the clock's own precision: two times that read the
        // same are a tie, never a win on milliseconds nobody can see.
        final gap = (result.durationMs! ~/ 1000 - c.durationMs ~/ 1000) * 1000;
        if (gap == 0) {
          verdict = l10n.challengeTie;
        } else if (gap < 0) {
          verdict = l10n.challengeYouBeat(formatGameTime(-gap));
          verdictColor = theme.success;
        } else {
          verdict = l10n.challengeStillStanding(formatGameTime(gap));
        }
      }
    }
    final canPlay = c != null && !mine && today && !played;
    final name = c == null ? '' : sentenceCaseOf(context, dailyGameName(l10n, c.game));

    return FocusableTap(
      onTap: canPlay ? () => _play(context, c) : null,
      enabled: canPlay,
      semanticLabel: [
        l10n.challengeTitle,
        if (c != null) '$name, ${formatGameTime(c.durationMs)}',
        ?verdict,
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
              AttachmentKindLabel(
                theme: theme,
                icon: CupertinoIcons.flag_fill,
                label: sentenceCaseOf(context, l10n.challengeKind),
              ),
              const SizedBox(height: 8),
              Text(
                sentenceCaseOf(
                  context,
                  mine ? l10n.challengeYourTime : l10n.challengeTitle,
                ),
                style: theme.bodyEmph.copyWith(color: theme.ink, fontSize: 17),
              ),
              const SizedBox(height: 6),
              if (c == null)
                const SkeletonBox(width: 120, height: 30, radius: 8)
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatGameTime(c.durationMs),
                      style: theme.displaySmall.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: attachmentMetaStyle(theme),
                      ),
                    ),
                  ],
                ),
              if (verdict != null) ...[
                const SizedBox(height: 4),
                Text(
                  sentenceCaseOf(context, verdict),
                  style: attachmentMetaStyle(theme).copyWith(
                    color: verdictColor ?? attachmentSecondaryInk(theme),
                    fontWeight: verdictColor != null ? FontWeight.w600 : null,
                  ),
                ),
              ],
              if (c != null)
                if (ChallengesStore.instance.roomResults(
                      message.roomId,
                      c.game,
                      c.dayKey,
                    )
                    case final results?)
                  _WhoPlayed(
                    theme: theme,
                    challenge: c,
                    results: results,
                    viewerId: viewerId,
                  ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canPlay)
                    RowPillButton(
                      label: AppLocalizations.of(context).chatGamePlay,
                      onTap: () => _play(context, c),
                      filled: true,
                    ),
                  const Spacer(),
                  if (stamp != null)
                    KeyedSubtree(key: kVisibleStampKey, child: stamp!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The room's finished results for the card's board, ranked: the viewer's
/// name is "you", ties by name in the viewer's own locale.
List<({GameResult row, int place})> _ranked(
  BuildContext context,
  RoomResults results,
  String viewerId,
) {
  final you = sentenceCaseOf(
    context,
    AppLocalizations.of(context).momentRailYouLabel,
  );
  return rankByPlace(
    results.rows,
    sameScore: sameGameScore,
    nameOf: (r) => r.userId == viewerId ? you : r.name,
    placeOf: (r) => r.place,
  );
}

String _nameOf(BuildContext context, GameResult row, String viewerId) =>
    row.userId == viewerId
        ? sentenceCaseOf(context, AppLocalizations.of(context).momentRailYouLabel)
        : row.name;

/// "Who played" under the card's time.
///
/// A DM is two people, so it is one line: "Zeynep 0:17 · You 0:21", and only
/// once somebody besides the challenger has finished (the card's own time
/// already says the challenger's). A group gets faces, "5 of 12 played" and
/// the top three with the viewer pinned under them; a tap opens the whole
/// room's board.
class _WhoPlayed extends StatelessWidget {
  const _WhoPlayed({
    required this.theme,
    required this.challenge,
    required this.results,
    required this.viewerId,
  });

  final AppTheme theme;
  final GameChallenge challenge;
  final RoomResults results;
  final String viewerId;

  static const _top = 3;
  static const _faces = 4;

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked(context, results, viewerId);
    if (ranked.isEmpty) return const SizedBox.shrink();
    return results.isGroup
        ? _group(context, ranked)
        : _dm(context, ranked);
  }

  Widget _dm(BuildContext context, List<({GameResult row, int place})> ranked) {
    final others = ranked.where((r) => r.row.userId != challenge.userId);
    if (others.isEmpty) return const SizedBox.shrink();
    final meta = attachmentMetaStyle(theme);
    final soft = attachmentSecondaryInk(theme);
    final l10n = AppLocalizations.of(context);
    final spans = <InlineSpan>[];
    for (var i = 0; i < ranked.length; i++) {
      final row = ranked[i].row;
      if (i > 0) spans.add(TextSpan(text: '  ·  ', style: TextStyle(color: soft)));
      spans.add(
        TextSpan(
          text: '${_nameOf(context, row, viewerId)} ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
      spans.add(
        row.solved
            ? TextSpan(
                text: formatGameTime(row.durationMs),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )
            : TextSpan(
                text: sentenceCaseOf(context, l10n.gameStatusGaveUp),
                style: TextStyle(color: soft),
              ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(children: spans),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: meta.copyWith(color: theme.ink),
      ),
    );
  }

  Widget _group(
    BuildContext context,
    List<({GameResult row, int place})> ranked,
  ) {
    final l10n = AppLocalizations.of(context);
    final soft = attachmentSecondaryInk(theme);
    final summary = challengePlayedSummary(l10n, results, viewerId);
    final shown = [
      ...ranked.take(_top),
      // The viewer, pinned under the top three when they finished lower.
      ...ranked.skip(_top).where((r) => r.row.userId == viewerId),
    ];
    final faces = ranked.take(_faces).toList();
    final more = results.played - faces.length;
    return SpringPress(
      onTap: () => showRoomResultsSheet(
        context,
        challenge: challenge,
        results: results,
        viewerId: viewerId,
      ),
      scale: PressSpec.scale,
      semanticLabel: sentenceCaseOf(context, summary),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _FaceStack(
                  rows: [for (final r in faces) r.row],
                  results: results,
                  viewerId: viewerId,
                  ring: attachmentBubbleFill(theme),
                ),
                if (more > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '+$more',
                    style: attachmentMetaStyle(theme).copyWith(
                      color: soft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sentenceCaseOf(context, summary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: attachmentMetaStyle(theme).copyWith(color: soft),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 13, color: soft),
              ],
            ),
            const SizedBox(height: 6),
            for (final r in shown)
              _MiniRow(
                theme: theme,
                place: r.place,
                name: _nameOf(context, r.row, viewerId),
                row: r.row,
                isViewer: r.row.userId == viewerId,
              ),
          ],
        ),
      ),
    );
  }
}

/// One finisher inside the card: place, name, time. The bubble's own scale,
/// not a [ScoreRow] — the full rows are one tap away in the sheet.
class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.theme,
    required this.place,
    required this.name,
    required this.row,
    required this.isViewer,
  });

  final AppTheme theme;
  final int place;
  final String name;
  final GameResult row;
  final bool isViewer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final meta = attachmentMetaStyle(theme);
    final soft = attachmentSecondaryInk(theme);
    const tabular = [FontFeature.tabularFigures()];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$place',
              style: meta.copyWith(color: soft, fontFeatures: tabular),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: meta.copyWith(
                color: theme.ink,
                fontWeight: isViewer ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.solved
                ? formatGameTime(row.durationMs)
                : sentenceCaseOf(context, l10n.gameStatusGaveUp),
            style: meta.copyWith(
              color: row.solved ? theme.ink : soft,
              fontWeight: row.solved ? FontWeight.w600 : null,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Up to four faces, overlapping, the leader on top at the start.
class _FaceStack extends StatelessWidget {
  const _FaceStack({
    required this.rows,
    required this.results,
    required this.viewerId,
    required this.ring,
  });

  final List<GameResult> rows;
  final RoomResults results;
  final String viewerId;
  final Color ring;

  static const _face = 22.0;
  static const _step = _face - 7;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: _step * (rows.length - 1) + _face + 4,
      height: _face + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = rows.length - 1; i >= 0; i--)
            PositionedDirectional(
              start: _step * i,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
                child: PlayerFace(
                  userId: rows[i].userId,
                  label: _nameOf(context, rows[i], viewerId),
                  size: _face,
                  storageId: results.avatars[rows[i].userId],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The whole room's board for one challenge's game: the standings' own rows
/// ([ScoreRow] in a [SheetGroup]), over the room instead of friends.
Future<void> showRoomResultsSheet(
  BuildContext context, {
  required GameChallenge challenge,
  required RoomResults results,
  required String viewerId,
}) {
  HapticFeedback.selectionClick();
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (_) => _RoomResultsSheet(
      challenge: challenge,
      results: results,
      viewerId: viewerId,
    ),
  );
}

class _RoomResultsSheet extends StatelessWidget {
  const _RoomResultsSheet({
    required this.challenge,
    required this.results,
    required this.viewerId,
  });

  final GameChallenge challenge;
  final RoomResults results;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ranked = _ranked(context, results, viewerId);
    return SheetFrame(
      title: sentenceCaseOf(context, dailyGameName(l10n, challenge.game)),
      subtitle: sentenceCaseOf(
        context,
        challengePlayedSummary(l10n, results, viewerId),
      ),
      showClose: true,
      padding: EdgeInsets.zero,
      scrollsUnderInset: true,
      child: ListView(
        shrinkWrap: true,
        padding: sheetListPadding(context),
        children: [
          SheetRise(
            child: SheetGroup(
              header: l10n.gameStandingsLabel,
              children: [
                for (final r in ranked)
                  ScoreRow(
                    rank: r.place,
                    medal: r.row.solved,
                    userId: r.row.userId,
                    name: r.row.name,
                    isViewer: r.row.userId == viewerId,
                    avatarStorageId: results.avatars[r.row.userId],
                    semantics: r.row.solved
                        ? formatGameTime(r.row.durationMs)
                        : sentenceCaseOf(context, l10n.gameStatusGaveUp),
                    extra: r.row.hintsUsed > 0
                        ? Icon(
                            CupertinoIcons.lightbulb,
                            size: 15,
                            color: theme.inkMuted,
                          )
                        : null,
                    trailing: ScoreText(
                      r.row.solved
                          ? formatGameTime(r.row.durationMs)
                          : sentenceCaseOf(context, l10n.gameStatusGaveUp),
                      muted: !r.row.solved,
                    ),
                  ),
              ],
            ),
          ),
          // Members who are not the viewer's friends are left out, so say so:
          // a short list must never read as "nobody else played".
          GroupedFooter(l10n.challengeFriendsOnlyNote),
        ],
      ),
    );
  }
}

/// The "who played" line, counting the viewer's friends only (the server
/// lists nobody else) and saying so, with the viewer named apart: "You and 3
/// friends played", "3 friends played", "Only you have played so far".
String challengePlayedSummary(
  AppLocalizations l10n,
  RoomResults results,
  String viewerId,
) {
  final friends = results.rows.where((r) => r.userId != viewerId).length;
  final mine = results.rows.any((r) => r.userId == viewerId);
  return mine
      ? l10n.challengeYouAndFriendsPlayed(friends)
      : l10n.challengeFriendsPlayed(friends);
}
