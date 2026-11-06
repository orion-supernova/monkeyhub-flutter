/// The client's rules for vanish mode, as pure functions.
///
/// Nothing here touches a widget, a socket or a clock it was not handed, so
/// every rule is a table a test can walk. The server is the authority (see
/// `backend/convex/vanish.ts`); these only decide what to DRAW and what to
/// TELL it, and they are deliberately conservative: when in doubt a read does
/// not count and a message keeps its 24 hour clock.
library;

import '../models/chat_message.dart';
import '../models/chat_room.dart';

/// `vanish:stateForRoom`: whether vanish is on, the timer and the pending burn.
///
/// Messages with `createdAt <= burnUpTo` vanish at [burnAt]. The caller's OWN
/// messages with `createdAt <= mineUpTo` vanish then too (the slowest reader's
/// own messages: the server tells only that reader, so nobody can tell who is
/// holding the chat back).
class VanishState {
  const VanishState({
    required this.active,
    required this.afterSeen,
    this.burnAt,
    this.burnUpTo,
    this.mineUpTo,
  });

  final bool active;

  /// Seconds after everyone has seen a message that it vanishes (10, 60, 3600).
  final int afterSeen;

  final DateTime? burnAt;
  final DateTime? burnUpTo;
  final DateTime? mineUpTo;

  static DateTime? _ms(Object? v) => v is num
      ? DateTime.fromMillisecondsSinceEpoch(v.toInt())
      : null;

  static VanishState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return VanishState(
      active: raw['active'] == true,
      afterSeen: raw['afterSeen'] is num ? (raw['afterSeen'] as num).toInt() : 10,
      burnAt: _ms(raw['burnAt']),
      burnUpTo: _ms(raw['burnUpTo']),
      mineUpTo: _ms(raw['mineUpTo']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VanishState &&
      other.active == active &&
      other.afterSeen == afterSeen &&
      other.burnAt == burnAt &&
      other.burnUpTo == burnUpTo &&
      other.mineUpTo == mineUpTo;

  @override
  int get hashCode =>
      Object.hash(active, afterSeen, burnAt, burnUpTo, mineUpTo);
}

/// `vanish:myVanishPrefs`: the caller's own sharing choices.
class VanishPrefs {
  const VanishPrefs({
    this.perChat,
    this.global = false,
    this.seen = 'friends',
  });

  /// This room's explicit answer; null = never asked.
  final bool? perChat;

  /// "Share my reads in vanishing chats".
  final bool global;

  /// The raw `visibility.seen`: public | friends | nobody.
  final String seen;

  bool get seenHidden => seen == 'nobody';

  /// Whether a read here may count toward the 10 second clock.
  bool get counts => !seenHidden || global || perChat == true;

  static VanishPrefs? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return VanishPrefs(
      perChat: raw['perChat'] is bool ? raw['perChat'] as bool : null,
      global: raw['global'] == true,
      seen: raw['seen'] is String ? raw['seen'] as String : 'friends',
    );
  }

  VanishPrefs withPerChat(bool? v) =>
      VanishPrefs(perChat: v, global: global, seen: seen);

  @override
  bool operator ==(Object other) =>
      other is VanishPrefs &&
      other.perChat == perChat &&
      other.global == global &&
      other.seen == seen;

  @override
  int get hashCode => Object.hash(perChat, global, seen);
}

/// Whether reads in [room] are vanish reads: vanish mode is on, or this is a
/// secret room whose timer starts when a message is seen.
bool isVanishReadRoom(ChatRoom? room) {
  if (room == null) return false;
  if (room.vanishMode) return true;
  return room.isEphemeral && room.messageClock == 'seen';
}

/// The extra arguments of `markRoomRead` for a vanish room. Null for an
/// ordinary room, which sends nothing new.
///
/// [counts] is "this read may be shared": the reader hides nothing, or has
/// switched sharing on globally, or answered yes in this chat.
/// [platformProtects] false (web, Linux) means vanish messages are sealed
/// here, so a read can never count: it would start a clock on words nobody saw.
({bool vanish, bool vanishCounts})? vanishReadArgs({
  required ChatRoom? room,
  required VanishPrefs? prefs,
  required bool platformProtects,
}) {
  if (!isVanishReadRoom(room)) return null;
  final counts = platformProtects && (prefs?.counts ?? false);
  return (vanish: true, vanishCounts: counts);
}

/// The read cursor this device may claim. On a platform that cannot block
/// screenshots vanish messages from others are sealed, and a sealed message is
/// never seen: the cursor must not pass the oldest of them. Returns [upTo]
/// unchanged when nothing is sealed, or the instant before the oldest sealed
/// message (null when there is no cursor to claim at all).
DateTime? readCursorFor({
  required DateTime? upTo,
  required Iterable<ChatMessage> messages,
  required String? me,
  required bool platformProtects,
}) {
  if (platformProtects) return upTo;
  DateTime? oldest;
  for (final m in messages) {
    if (m.vanishUntil == null || m.senderId == me) continue;
    if (m.id.startsWith('tmp_')) continue;
    if (oldest == null || m.createdAt.isBefore(oldest)) oldest = m.createdAt;
  }
  if (oldest == null) return upTo;
  final before = oldest.subtract(const Duration(milliseconds: 1));
  if (upTo == null || upTo.isAfter(before)) return before;
  return upTo;
}

/// What a vanishing message shows beside its time.
enum VanishStampKind {
  /// Not a vanishing message.
  none,

  /// Counted: a ring drains until [VanishState.burnAt].
  ring,

  /// Not counted yet: a quiet "24h" clock, never a Seen tick.
  clock,
}

VanishStampKind vanishStampKind({
  required ChatMessage message,
  required bool isMine,
  required VanishState? state,
}) {
  if (message.vanishUntil == null) return VanishStampKind.none;
  if (state == null || state.burnAt == null) return VanishStampKind.clock;
  final up = state.burnUpTo;
  if (up != null && !message.createdAt.isAfter(up)) return VanishStampKind.ring;
  final mine = state.mineUpTo;
  if (isMine && mine != null && !message.createdAt.isAfter(mine)) {
    return VanishStampKind.ring;
  }
  return VanishStampKind.clock;
}

/// How much of a ring is left: 1 when the burn was just scheduled, 0 at
/// [VanishState.burnAt].
double vanishRingRemaining(VanishState state, DateTime now) {
  final at = state.burnAt;
  if (at == null || state.afterSeen <= 0) return 0;
  final left = at.difference(now).inMilliseconds;
  return (left / (state.afterSeen * 1000)).clamp(0.0, 1.0);
}

/// The hidden-seen card of the design: vanish is on, the reader hides their
/// Seen, has not switched sharing on globally, and was never asked here.
bool showHiddenSeenCard({
  required bool vanishOn,
  required VanishPrefs? prefs,
  required bool answeredHere,
}) {
  if (!vanishOn || prefs == null || answeredHere) return false;
  return prefs.seenHidden && !prefs.global && prefs.perChat == null;
}

/// A parsed `vanish:` system line.
class VanishLine {
  const VanishLine(this.kind, [this.seconds]);

  final VanishLineKind kind;

  /// The timer, for [VanishLineKind.on] and [VanishLineKind.change].
  final int? seconds;

  static VanishLine? parse(String content) {
    if (!content.startsWith('vanish:')) return null;
    final parts = content.split(':');
    if (parts.length < 2) return null;
    switch (parts[1]) {
      case 'off':
        return const VanishLine(VanishLineKind.off);
      case 'on':
      case 'change':
        final s = parts.length > 2 ? int.tryParse(parts[2]) : null;
        if (s == null) return null;
        return VanishLine(
          parts[1] == 'on' ? VanishLineKind.on : VanishLineKind.change,
          s,
        );
    }
    return null;
  }
}

enum VanishLineKind { on, change, off }

/// The timers "Change" offers.
const List<int> kVanishAfterSeenOptions = [10, 60, 3600];

/// Whether a message may be copied, forwarded, saved or translated.
bool messageIsVanishing(ChatMessage m) => m.vanishUntil != null;
