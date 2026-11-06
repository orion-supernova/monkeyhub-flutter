/// What a desktop banner says, decided once for every platform that draws one.
///
/// Linux (org.freedesktop.Notifications) and Windows (toasts) used to be going
/// to compose their own title and body, and two copies of "who is the title,
/// which lines, whose face" would drift the first time the phones changed.
/// This is the desktop half of what the phones already do
/// (android/.../ChatNotifications.kt MessagingStyle,
/// ios/NotificationService/NotificationService.swift `composed`): one entry per
/// room, the last few lines newest last, a DM titled by the person with bare
/// lines, a group titled by its name with "Sender: text" lines.
///
/// Pure Dart on purpose: no platform imports, so it is testable and safe to
/// compile into the web build that shares message_alerts.dart.
class BannerCard {
  const BannerCard({
    required this.roomId,
    required this.title,
    required this.lines,
    required this.avatarStorageId,
  });

  final String roomId;
  final String title;

  /// Oldest first, newest last, already attributed for a group.
  final List<String> lines;

  /// The storage id of the face to show, or null for the app icon.
  final String? avatarStorageId;

  String get body => lines.join('\n');
}

class BannerComposer {
  /// The phones show the last few lines of a conversation; five is what a
  /// toast or a daemon bubble can hold before it truncates the newest.
  static const maxLines = 5;

  final Map<String, BannerCard> _cards = {};

  /// Adds one inbound line to [roomId]'s card and returns the card to show.
  ///
  /// [sender] is only used in a group, where it prefixes the line. [replace]
  /// swaps the card's lines for this one instead of stacking: a secret room's
  /// preview is the same sentence every time, and five copies of it say less
  /// than one.
  BannerCard add({
    required String roomId,
    required bool isDm,
    required String title,
    required String text,
    String? sender,
    bool replace = false,
    String? peerAvatar,
    String? roomAvatar,
    String? senderAvatar,
  }) {
    final line = isDm || sender == null || sender.isEmpty
        ? text
        : '$sender: $text';
    final lines = replace
        ? <String>[line]
        : <String>[...?_cards[roomId]?.lines, line];
    if (lines.length > maxLines) {
      lines.removeRange(0, lines.length - maxLines);
    }
    final card = BannerCard(
      roomId: roomId,
      title: title,
      lines: List.unmodifiable(lines),
      avatarStorageId: pickAvatar(
        isDm: isDm,
        peer: peerAvatar,
        room: roomAvatar,
        sender: senderAvatar,
      ),
    );
    _cards[roomId] = card;
    return card;
  }

  /// The card as it stands now, or null once the room was read or dismissed.
  BannerCard? current(String roomId) => _cards[roomId];

  /// The room was read (or its banner swiped away): the next line starts a
  /// fresh card instead of dragging old lines back in.
  void reset(String roomId) => _cards.remove(roomId);

  void clear() => _cards.clear();

  /// A DM wears the other person's face, a group its own picture, and either
  /// falls back to whoever wrote the line (the iOS extension does the same).
  /// Only ids the chat list would also draw: an empty string is "no picture".
  static String? pickAvatar({
    required bool isDm,
    String? peer,
    String? room,
    String? sender,
  }) {
    String? ok(String? s) => s == null || s.isEmpty ? null : s;
    return isDm ? ok(peer) ?? ok(sender) : ok(room) ?? ok(sender);
  }
}

/// A platform's way of drawing a [BannerCard]. Implemented by the Linux and
/// Windows notifiers (and their web stubs), so message_alerts.dart treats them
/// the same.
abstract class DesktopBannerSink {
  bool get isSupported;

  /// Shows or replaces [roomId]'s banner. [avatarUrl] may be null (not
  /// resolved yet, or no picture); a sink fetches it with a short deadline and
  /// shows without it rather than hold the banner back. [quiet] is a later
  /// line of a burst: update the text, make no noise.
  Future<void> show({
    required String roomId,
    required String title,
    required String body,
    String? avatarUrl,
    bool quiet = false,
  });

  Future<void> dismissRoom(String roomId);

  void setOnOpenRoom(void Function(String roomId) cb);

  /// Told when the person closes a room's banner themselves, so the lines it
  /// held do not come back in the next one. Not every platform can say.
  void setOnDismissed(void Function(String roomId) cb);
}
