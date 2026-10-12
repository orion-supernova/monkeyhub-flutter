import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/challenges_store.dart';
import '../data/feed_store.dart';
import '../games/game_names.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_message.dart';
import '../models/daily_game.dart';
import '../screens/games/daily_game_screens.dart';
import '../theme/app_theme.dart';
import 'action_buttons.dart';
import 'attachment_bubble_frame.dart';
import 'message_stamp.dart';
import 'skeleton_rows.dart';

/// A "Beat my time" card: a friend's finished daily result, sent as a dare.
///
/// The headline and the time come from the challenge itself (fetched once —
/// it never changes); the verdict comes from the viewer's OWN result for the
/// same board, read off the Feed's board, so it updates the moment they
/// finish without the card subscribing to anything. A challenge from an
/// earlier day still shows its time, but the board it named has closed, so
/// there is nothing to play.
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
    ChallengesStore.instance.target = ChallengeTarget(
      game: c.game,
      dayKey: c.dayKey,
      name: c.name,
      durationMs: c.durationMs,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => dailyGameScreen(c.game, viewerId)),
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
        final gap = result.durationMs! - c.durationMs;
        if (gap.abs() < 1000) {
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
