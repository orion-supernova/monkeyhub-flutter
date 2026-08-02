import 'chat_message.dart';

/// One pinned message in a room, as `pins:listForRoom` returns it.
///
/// Composes a [ChatMessage] rather than adding `pinnedAt` / `pinnedBy` fields to
/// it. A pin is room state, not a property of the message: hanging it on
/// [ChatMessage] would drag it through `toJson` (the disk-cache format),
/// `copyWith`'s whitelist, and both bubble classes, for something none of them
/// need. It also flattens badly the other way — the banner and the sheet both
/// hand the whole message to the jump machinery, so an id-and-a-string record
/// would not be enough.
///
/// Deliberately has no `toJson`. Pins are never written to the disk cache: the
/// pinned message is usually outside the cached window anyway, so a cached pin
/// would point at something the cold-boot transcript doesn't contain. Offline
/// the banner is simply absent.
class RoomPin {
  const RoomPin({
    required this.message,
    required this.pinnedAt,
    required this.pinnedBy,
  });

  /// The pinned message itself, already view-once-sanitized by the server.
  final ChatMessage message;

  final DateTime pinnedAt;

  /// Who pinned it. May name somebody no longer in the room — a pin survives
  /// its author leaving, because it is room state like the room's name. Callers
  /// must tolerate this not resolving to a known member.
  final String pinnedBy;

  factory RoomPin.fromJson(Map<String, dynamic> json) => RoomPin(
        message: ChatMessage.fromJson(
          (json['message'] as Map).cast<String, dynamic>(),
        ),
        pinnedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['pinnedAt'] as num?)?.toInt() ?? 0,
        ),
        pinnedBy: json['pinnedBy']?.toString() ?? '',
      );
}
