import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/matches_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import 'match_face.dart';

/// A watcher's name as the room knows it; empty for someone not cached.
String _nameOf(String roomId, String userId) =>
    MatchesStore.instance.resolveUser?.call(roomId, userId)?.displayName ?? '';

/// The name under a watcher's face: "You" for the viewer, the first word of
/// their name otherwise (a row of faces has no room for surnames).
String _shortName(BuildContext context, String roomId, String userId,
    String viewerId) {
  if (userId == viewerId) {
    return sentenceCaseOf(
        context, AppLocalizations.of(context).momentRailYouLabel);
  }
  return _nameOf(roomId, userId).trim().split(RegExp(r'\s+')).first;
}

/// Who is watching, as a few overlapping faces, each ringed in [ring] so the
/// one in front cuts the one behind, and "+N" for the rest. The chat card's
/// footer: the count beside it is the caller's.
///
/// Nothing while the server has not named anyone (an older backend sends
/// only the count).
class WatcherStack extends StatelessWidget {
  const WatcherStack({
    super.key,
    required this.match,
    required this.ring,
    this.size = 20,
    this.max = 3,
  });

  final ChatMatch match;
  final Color ring;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ids = match.watcherIds;
    if (ids.isEmpty) return const SizedBox.shrink();
    final shown = ids.take(max).toList();
    final rest = match.watching - shown.length;
    final slots = shown.length + (rest > 0 ? 1 : 0);
    final step = size * 0.68;
    Widget ringed(Widget child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 1.5),
          ),
          child: child,
        );
    return SizedBox(
      width: size + step * (slots - 1),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (rest > 0)
            Positioned(
              left: step * shown.length,
              child: ringed(
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(quietFill(theme), ring),
                  ),
                  child: Text(
                    '+$rest',
                    maxLines: 1,
                    style: theme.body.copyWith(
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w700,
                      color: theme.inkSoft,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          // Back to front, so the first to arrive lands on top.
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              key: ValueKey(shown[i]),
              left: step * i,
              child: _PopIn(
                child: ringed(
                  MatchFace(
                    roomId: match.roomId,
                    userId: shown[i],
                    name: _nameOf(match.roomId, shown[i]),
                    size: size,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The audience, by name: an eye and "2 watching" over a row of their faces,
/// each with a first name under it. Beside or under the board, and in the
/// lobby under the seats. Falls back to the count alone for a server that
/// sends no names.
class WatcherRoster extends StatelessWidget {
  const WatcherRoster({
    super.key,
    required this.match,
    required this.viewerId,
    this.center = false,
  });

  final ChatMatch match;
  final String viewerId;

  /// The lobby centres everything under its seats; the sidebar reads from
  /// the start.
  final bool center;

  static const _face = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ids = match.watcherIds;
    final rest = match.watching - ids.length;
    final caption = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.eye_fill, size: 14, color: theme.inkMuted),
        const SizedBox(width: 6),
        Text(
          l10n.chatGameWatchingCount(match.watching),
          style: groupedMetaStyle(theme).copyWith(
            color: theme.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (ids.isEmpty) return caption;
    final alignment = center ? WrapAlignment.center : WrapAlignment.start;
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        caption,
        const SizedBox(height: 10),
        Wrap(
          alignment: alignment,
          spacing: 6,
          runSpacing: 10,
          children: [
            for (final id in ids)
              _PopIn(
                key: ValueKey(id),
                child: SizedBox(
                  width: _face + 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MatchFace(
                        roomId: match.roomId,
                        userId: id,
                        name: _nameOf(match.roomId, id),
                        size: _face,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shortName(context, match.roomId, id, viewerId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: groupedMetaStyle(theme).copyWith(
                          fontSize: 12,
                          color: id == viewerId ? theme.ink : theme.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (rest > 0)
              SizedBox(
                width: _face + 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _face,
                      height: _face,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: quietFill(theme),
                      ),
                      child: Text(
                        '+$rest',
                        style: theme.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A face arriving: a small springy pop from 60%, once, when it first
/// mounts. Someone sitting down to watch is an event; the same faces on a
/// rebuild are not.
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: MotionScope.of(context).d(theme.motionMed),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(
        opacity: ((t - 0.6) / 0.4).clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: c),
      ),
      child: child,
    );
  }
}
