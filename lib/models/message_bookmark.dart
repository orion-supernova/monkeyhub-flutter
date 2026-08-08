import 'chat_message.dart';

/// One message this viewer saved in one room, as `bookmarks:listForRoom`
/// returns it.
///
/// ── Not the Saved Messages room ────────────────────────────────────────────
///
/// [ChatRoom.isSavedMessages] names something else entirely: the single-member
/// `dm:self:<userId>` room you forward COPIES into. This is a mark on a message
/// where it already lives, held by one reader, and it copies nothing. The two
/// share the word "saved" in the UI and share nothing at all in code — which is
/// why this type, its table and its backend module all say `bookmark` instead.
///
/// Composes a [ChatMessage] rather than adding a `saved` flag to it, for the
/// reason [RoomPin] gives and one more: a flag on the message would be wrong on
/// its face, because whether a message is saved depends on WHO is asking.
///
/// Deliberately has no `toJson`. Bookmarks are never written to the disk cache:
/// a saved message is usually outside the cached window, so a cached bookmark
/// would point at something a cold-boot transcript doesn't contain. Offline the
/// section is simply empty.
class MessageBookmark {
  const MessageBookmark({required this.message, required this.savedAt});

  /// The saved message itself, already view-once-sanitized by the server.
  final ChatMessage message;

  /// When this viewer saved it — not when it was sent. The section orders by
  /// this, newest first: a personal shelf reads best with the last thing you
  /// put on it at the top, which is the opposite of what a pin wants.
  final DateTime savedAt;

  factory MessageBookmark.fromJson(Map<String, dynamic> json) => MessageBookmark(
        message: ChatMessage.fromJson(
          (json['message'] as Map).cast<String, dynamic>(),
        ),
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['savedAt'] as num?)?.toInt() ?? 0,
        ),
      );
}
