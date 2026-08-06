import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/moment.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/remote_image.dart';

/// Reactions offered on a moment.
///
/// A fixed row rather than the full emoji picker used in chat. In a transcript
/// you are replying to a person; here you are reacting to a *thing that
/// happened*, and four one-tap options land the joke where a picker would
/// interrupt it. The set is tag-aware: piling onto a JINX is a different social
/// act from applauding a FATE.
List<String> quickReactionsFor(MomentTag? tag) => switch (tag) {
  MomentTag.jinx => const ['😂', '💀', '🫵', '😭'],
  MomentTag.fate => const ['🤯', '👏', '😮', '🔮'],
  MomentTag.luck => const ['🍀', '👏', '😤', '🤝'],
  MomentTag.calledIt => const ['🔮', '👏', '🙄', '😤'],
  MomentTag.npc => const ['😂', '🤖', '🫠', '💀'],
  null => const ['❤️', '😂', '🔥', '👏'],
};

/// Opens a moment full-screen.
Future<void> showMomentViewer(
  BuildContext context, {
  required Moment moment,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      // Translucent so the board stays visible behind the scrim — the moment
      // lifts off the rail rather than replacing the screen.
      opaque: false,
      barrierColor: null,
      transitionDuration: ThemeScope.of(context).motionMed,
      reverseTransitionDuration: ThemeScope.of(context).motionMed,
      pageBuilder: (_, _, _) => _MomentViewer(
        moment: moment,
        api: api,
        feedApi: feedApi,
        userId: userId,
      ),
      transitionsBuilder: (context, anim, _, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    ),
  );
}

class _MomentViewer extends StatefulWidget {
  const _MomentViewer({
    required this.moment,
    required this.api,
    required this.feedApi,
    required this.userId,
  });

  final Moment moment;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  @override
  State<_MomentViewer> createState() => _MomentViewerState();
}

class _MomentViewerState extends State<_MomentViewer> {
  /// Optimistic local overlay on top of the subscription's reaction state.
  ///
  /// The board is live, so the truth arrives on its own within a round trip —
  /// but a reaction that takes 200ms to appear feels broken, and this is the
  /// one interaction where latency is the whole experience.
  late final Set<String> _mine = {...widget.moment.myReactions};
  late final Map<String, int> _counts = {...widget.moment.reactionCounts};

  @override
  void initState() {
    super.initState();
    // Clearing the unseen ring is a side effect of looking, so it fires on
    // open rather than on any deliberate action. Failure is silent: the ring
    // simply stays, which is a far better outcome than an error over a photo.
    if (!widget.moment.mine && !widget.moment.seen) {
      widget.feedApi
          .markSeen(userId: widget.userId, momentIds: [widget.moment.id])
          .catchError((_) {});
    }
  }

  Future<void> _toggle(String emoji) async {
    final had = _mine.contains(emoji);
    setState(() {
      if (had) {
        _mine.remove(emoji);
        final n = (_counts[emoji] ?? 1) - 1;
        if (n <= 0) {
          _counts.remove(emoji);
        } else {
          _counts[emoji] = n;
        }
      } else {
        _mine.add(emoji);
        _counts[emoji] = (_counts[emoji] ?? 0) + 1;
      }
    });
    // Haptic on the commitment, not on the animation — the house rule.
    HapticFeedback.selectionClick();
    try {
      if (had) {
        await widget.feedApi.unreact(
          userId: widget.userId,
          momentId: widget.moment.id,
          emoji: emoji,
        );
      } else {
        await widget.feedApi.react(
          userId: widget.userId,
          momentId: widget.moment.id,
          emoji: emoji,
        );
      }
    } catch (_) {
      // Roll the optimistic edit back rather than leaving a reaction that does
      // not exist on the server — the next board payload would silently
      // contradict it and the count would appear to flicker on its own.
      if (!mounted) return;
      setState(() {
        if (had) {
          _mine.add(emoji);
          _counts[emoji] = (_counts[emoji] ?? 0) + 1;
        } else {
          _mine.remove(emoji);
          final n = (_counts[emoji] ?? 1) - 1;
          if (n <= 0) {
            _counts.remove(emoji);
          } else {
            _counts[emoji] = n;
          }
        }
      });
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    try {
      await widget.feedApi.remove(
        userId: widget.userId,
        momentId: widget.moment.id,
      );
    } catch (_) {
      /* the row is either gone or it isn't; the board will say which */
    }
    if (mounted) navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = widget.moment;
    final storageId = m.mediaKind == MomentMedia.video
        ? m.posterStorageId
        : m.mediaStorageId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // A tap anywhere off the card dismisses. Behind the card in the
          // stack so it never steals the reaction row's taps.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: theme.background.withValues(alpha: 0.92),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: motion.d(theme.motionMed),
                  curve: motion.c(theme.motionEntrance),
                  builder: (context, v, child) => Transform.scale(
                    scale: 0.96 + 0.04 * v,
                    child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.all(14),
                    decoration: theme.roomCardDecoration(
                      ephemeral: false,
                      active: false,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.mine ? l10n.momentRailYouLabel : m.authorName,
                                style: theme.displaySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (m.tag != null) MomentTagChip(tag: m.tag!),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (storageId != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                            child: RemoteImage(
                              storageId: storageId,
                              api: widget.api,
                              fit: BoxFit.contain,
                            ),
                          ),
                        if (m.caption?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(m.caption!, style: theme.body),
                        ],
                        const SizedBox(height: 14),
                        _ReactionRow(
                          emojis: quickReactionsFor(m.tag),
                          counts: _counts,
                          mine: _mine,
                          onTap: _toggle,
                        ),
                        if (m.mine) ...[
                          const SizedBox(height: 12),
                          FocusableTap(
                            onTap: _delete,
                            semanticLabel: l10n.momentViewerDelete,
                            radius: theme.radiusMd,
                            child: GestureDetector(
                              onTap: _delete,
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 14,
                                    color: theme.danger,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.momentViewerDelete,
                                    style: theme.monoTiny.copyWith(
                                      color: theme.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.emojis,
    required this.counts,
    required this.mine,
    required this.onTap,
  });

  final List<String> emojis;
  final Map<String, int> counts;
  final Set<String> mine;
  final void Function(String emoji) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        for (final e in emojis)
          Padding(
            key: ValueKey(e),
            padding: const EdgeInsets.only(right: 8),
            child: _ReactionPill(
              emoji: e,
              count: counts[e] ?? 0,
              active: mine.contains(e),
              onTap: () => onTap(e),
            ),
          ),
        // Reactions anyone added that are outside this moment's quick set —
        // possible when a newer client ships a different row, or when the tag
        // changed. Dropping them would make someone's reaction vanish.
        for (final e in counts.keys.where((k) => !emojis.contains(k)))
          Padding(
            key: ValueKey('extra_$e'),
            padding: const EdgeInsets.only(right: 8),
            child: _ReactionPill(
              emoji: e,
              count: counts[e] ?? 0,
              active: mine.contains(e),
              onTap: () => onTap(e),
            ),
          ),
        const Spacer(),
        Text('${counts.values.fold(0, (a, b) => a + b)}', style: theme.monoTiny),
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: emoji,
      selected: active,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? theme.accentSoft : theme.surfaceSunken,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? theme.accent : theme.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: theme.monoTiny.copyWith(fontSize: 13)),
              if (count > 0) ...[
                const SizedBox(width: 4),
                // AnimatedSwitcher keyed on the value so the number rolls
                // rather than swapping — the board's odometer idiom in
                // miniature.
                AnimatedSwitcher(
                  duration: theme.motionFast,
                  switchInCurve: theme.motionEntrance,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => ClipRect(
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$count',
                    key: ValueKey(count),
                    style: theme.monoTiny,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
