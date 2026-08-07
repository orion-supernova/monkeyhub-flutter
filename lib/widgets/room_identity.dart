import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';

/// What a room card can say about itself when the conversation hasn't started.
///
/// A card is a fixed box whether or not there's anything in it, and a room that
/// nobody has spoken in yet used to leave most of that box blank: a name, a
/// ghost line, a count. So the card asks in order for the most useful thing it
/// can say, and only falls back once each rung runs out.
enum RoomSubtitleKind {
  /// The last thing someone said. Always wins.
  message,

  /// The room's own description — real content the cards never showed, though
  /// it has been in the model all along and Discover has been printing it.
  description,

  /// Nothing has been said and nobody wrote a description. This is the rung
  /// [RoomMonogram] and the bigger name exist for.
  empty,
}

typedef RoomSubtitle = ({String text, RoomSubtitleKind kind});

RoomSubtitle roomSubtitle(BuildContext context, ChatRoom room) {
  final last = room.lastMessage?.trim();
  if (last != null && last.isNotEmpty) {
    return (text: last, kind: RoomSubtitleKind.message);
  }
  final description = room.description?.trim();
  if (description != null && description.isNotEmpty) {
    return (text: description, kind: RoomSubtitleKind.description);
  }
  return (
    text: AppLocalizations.of(context).roomGridTileEmptyLastMessage,
    kind: RoomSubtitleKind.empty,
  );
}

/// How long ago, in the coarse words the room list uses.
String roomTimeAgo(BuildContext context, DateTime then) {
  final l10n = AppLocalizations.of(context);
  final d = DateTime.now().difference(then);
  if (d.inSeconds < 30) return l10n.roomCardTimeAgoJustNow;
  if (d.inSeconds < 60) return l10n.roomCardTimeAgoSeconds(d.inSeconds);
  if (d.inMinutes < 60) return l10n.roomCardTimeAgoMinutes(d.inMinutes);
  if (d.inHours < 24) return l10n.roomCardTimeAgoHours(d.inHours);
  if (d.inDays < 7) return l10n.roomCardTimeAgoDays(d.inDays);
  return l10n.roomCardTimeAgoWeeks((d.inDays / 7).floor());
}

/// The room's initial, huge and nearly invisible, bled off the bottom corner
/// of its card.
///
/// The answer to "what fills the card when there is nothing to fill it with":
/// a name and an id, which every room has from the second it exists. The
/// letter gives the card a subject and the seeded tint gives it a colour of
/// its own, so a wall of quiet rooms reads as a set of distinct things rather
/// than a row of blanks — and neither costs a query.
///
/// Only for rooms wearing the fallback avatar. A room with a picture already
/// has a face, and a DM borrows the other person's.
class RoomMonogram extends StatelessWidget {
  const RoomMonogram({
    super.key,
    required this.name,
    required this.seed,
    required this.size,
  });

  final String name;

  /// Stable per room — the room id — so the tint never changes under someone.
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final trimmed = name.trim();
    final letter =
        trimmed.isEmpty ? '#' : trimmed.characters.first.toUpperCase();
    return IgnorePointer(
      child: Text(
        letter,
        textAlign: TextAlign.center,
        style: theme.displayHero.copyWith(
          fontSize: size,
          height: 1,
          color: theme.avatarGradient(seed.hashCode).first.withValues(
                alpha: 0.16,
              ),
        ),
      ),
    );
  }
}
