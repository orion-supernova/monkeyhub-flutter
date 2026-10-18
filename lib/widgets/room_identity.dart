import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/room_capabilities.dart';
import '../privacy/app_only.dart';

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

  /// Nothing has been said and nobody wrote a description.
  empty,
}

typedef RoomSubtitle = ({String text, RoomSubtitleKind kind});

RoomSubtitle roomSubtitle(BuildContext context, ChatRoom room) {
  // A secret room does not open where capture can't be blocked, so its last
  // message is not shown there either.
  if (room.isEphemeral && AppOnly.gatesCapture) {
    return (
      text: AppLocalizations.of(context).appOnlySecretPreview,
      kind: RoomSubtitleKind.empty,
    );
  }
  final last = room.lastMessage?.trim();
  if (last != null && last.isNotEmpty) {
    return (text: last, kind: RoomSubtitleKind.message);
  }
  // Gated on the same capability the chat header and room info ask, so a room
  // whose description is hidden everywhere else cannot reappear here — which is
  // exactly what a DM would do, since a DM with no messages yet is the one
  // state this rung exists for. `peer` is not in hand on the room list and is
  // not needed: a DM is recognised by its name.
  final description =
      roomCapabilitiesFor(room).hasDescription ? room.description?.trim() : null;
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
