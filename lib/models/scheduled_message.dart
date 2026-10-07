import 'package:flutter/foundation.dart';

import 'chat_message.dart' show MessageMention;
import 'message_formatting.dart';

/// Closest to now a message may be scheduled.
///
/// The Dart half of `MIN_LEAD_MS` in `backend/convex/scheduledMessages.ts`, and
/// the picker's floor rather than merely its validation: [ScheduleTimePicker]
/// refuses to select below this, so the server's copy is only ever reached by a
/// stale screen. Two minutes here against the server's one is deliberate slack —
/// a user who takes ninety seconds to finish choosing must not be refused for
/// having thought about it.
const Duration kScheduleMinLead = Duration(minutes: 2);

/// Furthest ahead a message may be scheduled: one year.
///
/// Mirrors `MAX_HORIZON_MS`. Keep the two in step — the client is what stops
/// anyone reaching the server's refusal, so a client that offered more would
/// offer a date the send would decline.
const Duration kScheduleMaxHorizon = Duration(days: 365);

/// The hour a "morning" preset means, in the user's own local time.
const int kScheduleMorningHour = 9;

/// The four one-tap delays the schedule sheet offers.
///
/// Modelled on [MuteDuration] in `room_mute.dart`, with one deliberate break
/// from its rule that the wire carries a LENGTH and never an instant.
///
/// [inAnHour], [inEightHours] and [inAWeek] are lengths, and go out as
/// `delayMs` so the server adds them to its own clock — a phone running ten
/// minutes fast must not schedule ten minutes short. That is exactly the
/// `rooms:muteRoom` argument.
///
/// [tomorrowMorning] cannot work that way. "Morning" is a wall-clock intent,
/// and it only means anything in the sender's timezone — which the server does
/// not know and should not start storing for this. So this one resolves here
/// and travels as an absolute `sendAt`, which the server range-checks against
/// [kScheduleMinLead]/[kScheduleMaxHorizon] rather than trusts. The custom
/// picker takes the same path for the same reason.
///
/// Every preset renders its RESOLVED clock time beneath its label, so none of
/// them can lie: [tomorrowMorning] means the next 9am, which at 2am is today,
/// and a chip that said "tomorrow" while meaning "in seven hours" is exactly
/// the sort of small dishonesty that makes a scheduler untrustworthy.
enum SchedulePreset {
  inAnHour(Duration(hours: 1)),
  inEightHours(Duration(hours: 8)),

  /// The next 09:00 local. Null span — see [resolve].
  tomorrowMorning(null),

  inAWeek(Duration(days: 7));

  const SchedulePreset(this.span);

  /// How long from now, or null for the wall-clock preset.
  final Duration? span;

  /// When this preset would send, measured from [now].
  ///
  /// Takes `now` rather than reading the clock so the resolution is testable
  /// without waiting for a particular hour — the [RoomMute] rule, and it earns
  /// its keep here: the interesting cases are 2am and 11pm.
  DateTime resolve(DateTime now) {
    final span = this.span;
    if (span != null) return now.add(span);
    // The next 09:00. `DateTime(y, m, d + 1, …)` normalises month and year
    // rollover on its own, so December 31st needs no special case.
    final todayAt = DateTime(
      now.year,
      now.month,
      now.day,
      kScheduleMorningHour,
    );
    return todayAt.isAfter(now)
        ? todayAt
        : DateTime(now.year, now.month, now.day + 1, kScheduleMorningHour);
  }

  /// What `scheduledMessages:schedule` wants as `delayMs`, or null when this
  /// preset travels as an absolute `sendAt` instead. Exactly one of this and
  /// [wireSendAt] is non-null for any preset.
  int? get wireDelayMs => span?.inMilliseconds;

  /// The absolute instant to send, for the presets that have one. See the
  /// class doc for why the two forms both exist.
  int? wireSendAt(DateTime now) =>
      span == null ? resolve(now).millisecondsSinceEpoch : null;
}

/// A message written now and queued for later.
///
/// The client half of the `scheduledMessages` table. Deliberately NOT a
/// [ChatMessage]: this has no sender identity to render, no reactions, no read
/// state and no place in a transcript, and giving it those fields would invite
/// somebody to put one in the message list — which is the single thing this
/// design exists to prevent (see the table's schema comment).
@immutable
class ScheduledMessage {
  const ScheduledMessage({
    required this.id,
    required this.roomId,
    required this.content,
    required this.sendAt,
    required this.createdAt,
    this.pending = true,
    this.replyToId,
    this.mentions = const [],
    this.mentionsEveryone = false,
    this.formatting = const [],
    this.failedReason,
    this.failedAt,
    this.mediaStorageId,
    this.mediaWidth,
    this.mediaHeight,
    this.viewOnce = false,
  });

  final String id;
  final String roomId;
  final String content;

  /// When this is due to go out.
  final DateTime sendAt;

  /// When the user queued it — not when it sends.
  final DateTime createdAt;

  /// Whether this is still waiting to be sent.
  ///
  /// False means the release ran and was refused; [failedReason] says why. A
  /// row that sent successfully is deleted server-side, so "pending false" and
  /// "failed" are the same state, and there is no third one to render.
  final bool pending;

  final String? replyToId;

  /// Who this names with an `@`. Ids and handles both, because the list sheet
  /// renders the queued text the same way a bubble would.
  final List<MessageMention> mentions;
  final bool mentionsEveryone;
  final List<FormattingEntity> formatting;

  /// One of `guardOutgoing`'s thrown strings, when the release was refused —
  /// a revoked child grant, a room the sender is no longer in, a block raised
  /// since. Null while [pending].
  final String? failedReason;
  final DateTime? failedAt;

  /// The photo, when this is a scheduled photo — already uploaded, so the
  /// list can show the very picture that will go out. [content] is then its
  /// caption, and may be empty.
  final String? mediaStorageId;
  final double? mediaWidth;
  final double? mediaHeight;

  /// Armed with the circled "1" when it was scheduled.
  final bool viewOnce;

  bool get isPhoto => mediaStorageId != null;

  /// Whether the release failed and the message is waiting on the sender.
  bool get hasFailed => !pending && failedReason != null;

  /// Whether the send time has passed while this is still queued.
  ///
  /// Not an error state: it is the few seconds between the deadline and the
  /// scheduler firing, and — if a job was lost — the up-to-five minutes before
  /// `scheduledMessages.gcOverdue` picks it up. Rendered as "sending…" rather
  /// than as a countdown that has gone negative.
  bool isOverdueAt(DateTime now) => pending && !sendAt.isAfter(now);

  /// How long until this sends, floored at zero. See [isOverdueAt] for why the
  /// floor is not an error.
  Duration remainingAt(DateTime now) {
    final left = sendAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  ScheduledMessage copyWith({
    String? content,
    DateTime? sendAt,
    bool? pending,
    List<MessageMention>? mentions,
    bool? mentionsEveryone,
    List<FormattingEntity>? formatting,
  }) =>
      ScheduledMessage(
        id: id,
        roomId: roomId,
        content: content ?? this.content,
        sendAt: sendAt ?? this.sendAt,
        createdAt: createdAt,
        pending: pending ?? this.pending,
        replyToId: replyToId,
        mentions: mentions ?? this.mentions,
        mentionsEveryone: mentionsEveryone ?? this.mentionsEveryone,
        formatting: formatting ?? this.formatting,
        // Deliberately dropped when `pending` is being set back to true: a
        // retried row is not a failed one, and carrying the reason forward
        // would render a freshly-queued message as broken. Mirrors the same
        // clearing in `scheduledMessages:reschedule`.
        failedReason: (pending ?? this.pending) ? null : failedReason,
        failedAt: (pending ?? this.pending) ? null : failedAt,
        mediaStorageId: mediaStorageId,
        mediaWidth: mediaWidth,
        mediaHeight: mediaHeight,
        viewOnce: viewOnce,
      );

  /// Reads a row from `scheduledMessages:listForRoom`, or from the same shape
  /// on disk.
  ///
  /// Tolerant in the same places [ChatMessage.fromJson] is: an unknown
  /// formatting span drops rather than throwing, and a missing `pending` reads
  /// as true — a row written by a build that predates the failure path is one
  /// that has not failed.
  factory ScheduledMessage.fromJson(Map<String, dynamic> j) {
    final failedAt = (j['failedAt'] as num?)?.toInt();
    return ScheduledMessage(
      id: (j['_id'] ?? j['id']).toString(),
      roomId: (j['roomId']).toString(),
      content: (j['content'] ?? '') as String,
      sendAt: DateTime.fromMillisecondsSinceEpoch(
        (j['sendAt'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num?)?.toInt() ?? 0,
      ),
      pending: (j['pending'] ?? true) as bool,
      replyToId: j['replyToId']?.toString(),
      // Ids only on the wire, because the server has no handle to send until
      // the message is resolved at release. The list sheet renders "@" plus
      // whatever the composer stored, so a bare id never reaches a screen.
      mentions: [
        for (final m in (j['mentions'] as List?) ?? const [])
          if (m is Map) MessageMention.fromJson(m.cast<String, dynamic>()),
      ],
      mentionsEveryone: (j['mentionsEveryone'] ?? false) as bool,
      formatting: FormattingEntity.parseList(j['formatting']),
      failedReason: j['failedReason'] as String?,
      failedAt: failedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(failedAt),
      mediaStorageId: j['mediaStorageId']?.toString(),
      mediaWidth: (j['mediaWidth'] as num?)?.toDouble(),
      mediaHeight: (j['mediaHeight'] as num?)?.toDouble(),
      viewOnce: (j['viewOnce'] ?? false) as bool,
    );
  }

  /// Only the set fields, so an ordinary queued message round-trips as the
  /// shape the backend actually sends — the [RoomMute.toJson] rule.
  Map<String, dynamic> toJson() => {
        '_id': id,
        'roomId': roomId,
        'content': content,
        'sendAt': sendAt.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (pending) 'pending': true,
        if (replyToId != null) 'replyToId': replyToId,
        if (mentions.isNotEmpty)
          'mentions': [for (final m in mentions) m.toJson()],
        if (mentionsEveryone) 'mentionsEveryone': true,
        if (formatting.isNotEmpty)
          'formatting': [for (final f in formatting) f.toJson()],
        if (failedReason != null) 'failedReason': failedReason,
        if (failedAt != null) 'failedAt': failedAt!.millisecondsSinceEpoch,
        if (mediaStorageId != null) ...{
          'type': 'image',
          'mediaStorageId': mediaStorageId,
        },
        if (mediaWidth != null) 'mediaWidth': mediaWidth,
        if (mediaHeight != null) 'mediaHeight': mediaHeight,
        if (viewOnce) 'viewOnce': true,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledMessage &&
          other.id == id &&
          other.roomId == roomId &&
          other.content == content &&
          other.sendAt == sendAt &&
          other.createdAt == createdAt &&
          other.pending == pending &&
          other.replyToId == replyToId &&
          other.mentionsEveryone == mentionsEveryone &&
          other.failedReason == failedReason &&
          other.failedAt == failedAt &&
          other.mediaStorageId == mediaStorageId &&
          other.mediaWidth == mediaWidth &&
          other.mediaHeight == mediaHeight &&
          other.viewOnce == viewOnce &&
          listEquals(other.formatting, formatting) &&
          listEquals(
            [for (final m in other.mentions) m.userId],
            [for (final m in mentions) m.userId],
          );

  @override
  int get hashCode => Object.hash(
        id,
        roomId,
        content,
        sendAt,
        createdAt,
        pending,
        replyToId,
        mentionsEveryone,
        failedReason,
        failedAt,
        Object.hash(mediaStorageId, mediaWidth, mediaHeight, viewOnce),
        Object.hashAll(formatting),
        Object.hashAll([for (final m in mentions) m.userId]),
      );

  @override
  String toString() => hasFailed
      ? 'ScheduledMessage($id, FAILED $failedReason)'
      : 'ScheduledMessage($id, sends $sendAt)';
}
