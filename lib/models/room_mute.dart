import 'package:flutter/foundation.dart';

/// "Always", as an instant rather than a null or a flag.
///
/// The Dart half of `backend/convex/mute.ts`'s `MUTE_ALWAYS`, and the same
/// number: 8_640_000_000_000_000 ms, which is simultaneously the largest value
/// [DateTime.fromMillisecondsSinceEpoch] accepts, the largest JavaScript's
/// `new Date()` accepts (so this survives the web build), and small enough to
/// be an exact float64 integer (so it survives the wire without rounding).
///
/// Read `mute.ts` for why the sentinel beat `null`-means-forever. The short
/// version is failure direction: a reader that forgets the sentinel and just
/// asks `now < untilMs` still says "muted", which is what the user asked for.
/// With null-as-forever the same forgetful reader unmutes them.
const int kMuteAlwaysMs = 8640000000000000;

/// The four lengths the mute sheet offers — the set every large messenger has
/// converged on, and deliberately not a free-form picker.
///
/// A duration picker turns "shut this up" into a small arithmetic problem, and
/// the answer people actually want is almost always one of these. [always] is
/// the important one and the reason the list isn't just three numbers: the
/// single most common reason to mute a chat is that you never want to hear
/// from it again, and an interface that can only mute for a week makes that
/// a recurring chore.
enum MuteDuration {
  hour(Duration(hours: 1)),
  eightHours(Duration(hours: 8)),
  week(Duration(days: 7)),

  /// No deadline. Sent to the server as an absent `durationMs`, stored as
  /// [kMuteAlwaysMs].
  always(null);

  const MuteDuration(this.span);

  /// How long from now, or null for [always].
  final Duration? span;

  /// What `rooms:muteRoom` wants: milliseconds, or null to mean "always".
  ///
  /// A LENGTH rather than a deadline, on purpose — the server turns it into an
  /// absolute instant with its own clock, so a phone running ten minutes fast
  /// doesn't mute for ten minutes less than the user asked for.
  int? get wireMs => span?.inMilliseconds;
}

/// What a room is silencing for this viewer, and until when.
///
/// Two independent switches on one clock. They never imply each other:
///
///  * [notifications] stops the push. Enforced server-side before the bytes
///    leave (`push.sendAlert`) — a notification suppressed on the device has
///    already buzzed the phone, which is not muting.
///  * [badges] stops the room appearing in any count: the unread pill on its
///    row, the dot, the bold name, the tab-bar number and the OS app-icon
///    badge. The stronger of the two, and the one that means "I don't want to
///    see this at all" rather than "don't interrupt me".
///
/// A room with [notifications] alone keeps climbing its unread count, which is
/// exactly what someone who picked only that switch asked for.
///
/// ── The clock ──────────────────────────────────────────────────────────────
///
/// [untilMs] is an absolute instant, computed and stored by the server, and it
/// is the only thing that decides whether either switch is in force. Expiry
/// happens by arithmetic, not by an event: nothing runs at the deadline, on
/// the server or here. That is why every question this class answers takes a
/// `now` — a mute lapses because time passed, and a caller that can name the
/// instant it cares about can be tested without waiting for one.
///
/// The client re-resolving what the server already knows is not duplication
/// for its own sake. `rooms:listUserRooms` is a reactive subscription, and a
/// deadline passing is not a database change, so nothing re-fires that query
/// when a mute lapses under an app someone left open. Sending a pre-resolved
/// boolean would therefore mean shipping a value with a shelf life. Sending
/// the deadline means the client can be right about it forever.
@immutable
class RoomMute {
  const RoomMute({
    this.notifications = false,
    this.badges = false,
    this.untilMs,
  });

  /// Nothing muted. What every room starts as, what an unmuted room returns
  /// to, and what a lapsed mute is indistinguishable from.
  static const RoomMute none = RoomMute();

  final bool notifications;
  final bool badges;

  /// When the mute lapses, in ms since epoch. Null when no mute was ever set;
  /// [kMuteAlwaysMs] when the user picked "always".
  final int? untilMs;

  /// True when this mute has no end.
  ///
  /// `>=` rather than `==` so a value that survived a lossy round-trip (or a
  /// future backend that picks a slightly different ceiling) still reads as
  /// forever rather than as a deadline in the year 275760, which would behave
  /// identically for every user alive but would make [until] try to render it.
  bool get isAlways => untilMs != null && untilMs! >= kMuteAlwaysMs;

  /// The deadline, for showing to a human — null when there isn't one to show.
  ///
  /// Null for [isAlways] as well as for an unset mute, because "always" has no
  /// clock face and every caller that renders this wants the word rather than
  /// a date eight thousand centuries out. Callers that need to compare rather
  /// than display use [untilMs].
  DateTime? get until => untilMs == null || isAlways
      ? null
      : DateTime.fromMillisecondsSinceEpoch(untilMs!);

  /// Whether anything at all is silenced at [now].
  ///
  /// Both halves matter. A deadline in the future with neither switch on is
  /// not a mute — the backend refuses to write that state, but a client
  /// holding a row from a build that could is better off agreeing with the
  /// server than showing a "Muted" pill on a room nothing is muting.
  bool isLiveAt(DateTime now) =>
      (notifications || badges) &&
      untilMs != null &&
      now.millisecondsSinceEpoch < untilMs!;

  /// Whether pushes from this room are silenced at [now].
  bool silencesNotificationsAt(DateTime now) => notifications && isLiveAt(now);

  /// Whether this room is kept out of every count at [now].
  bool silencesBadgesAt(DateTime now) => badges && isLiveAt(now);

  /// This mute with one switch flipped — for the sheet, which lets the user
  /// build a combination before committing it.
  RoomMute copyWith({bool? notifications, bool? badges, int? untilMs}) =>
      RoomMute(
        notifications: notifications ?? this.notifications,
        badges: badges ?? this.badges,
        untilMs: untilMs ?? this.untilMs,
      );

  /// Reads the three columns `rooms:listUserRooms` spreads onto every room.
  ///
  /// Every one of them is absent on a backend older than this feature and on
  /// any room cached before it, which all mean the same thing: not muted.
  factory RoomMute.fromJson(Map<String, dynamic> j) {
    final until = j['mutedUntil'];
    return RoomMute(
      notifications: (j['muteNotifications'] ?? false) as bool,
      badges: (j['muteBadges'] ?? false) as bool,
      untilMs: until is num ? until.toInt() : null,
    );
  }

  /// Only the set fields, so an unmuted room round-trips through the cache as
  /// the three keys simply being absent — the same shape the backend sends.
  Map<String, dynamic> toJson() => {
        if (notifications) 'muteNotifications': true,
        if (badges) 'muteBadges': true,
        if (untilMs != null) 'mutedUntil': untilMs,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomMute &&
          other.notifications == notifications &&
          other.badges == badges &&
          other.untilMs == untilMs;

  @override
  int get hashCode => Object.hash(notifications, badges, untilMs);

  @override
  String toString() => isLiveAt(DateTime.now())
      ? 'RoomMute(notifications: $notifications, badges: $badges, '
          'until: ${isAlways ? 'always' : until})'
      : 'RoomMute.none';
}
