import 'dart:convert';
import '../format/duration_format.dart' as fmt;

/// 1:1 call or a ringing group call (a huddle never gets one: nobody was
/// called).
enum CallEventKind { direct, group }

enum CallEventType { audio, video }

/// The wire `s` of a call message. See docs/design/calls.md section 1.
enum CallEventStatus { ringing, active, ended, missed, declined, cancelled }

/// Worst connection either side reported after the call (`q`).
enum CallEventQuality { good, fair, poor }

/// What the viewer's bubble says, after the wire status is read from their
/// side. One entry per row of the perspective table in the design doc, so the
/// bubble, the chat list's preview line and the tests all agree.
enum CallPhase {
  /// I am calling and nobody has picked up yet.
  calling,

  /// Somebody is calling me (a group call: with a Join pill).
  incomingRinging,

  /// Connected right now: a live timer from `a`.
  live,

  /// I called and we talked.
  outgoingEnded,

  /// They called and we talked.
  incomingEnded,

  /// I called and nobody picked up.
  noAnswer,

  /// They called and I never picked up.
  missed,

  /// I called and hung up before anybody answered.
  cancelled,

  /// Declined, by them (my call) or by me (theirs).
  declined,
}

/// The `call:{json}` system message, parsed.
///
/// Pure Dart on purpose, like `HuddleHistory`: the transcript bubble, the chat
/// list's preview line, a notification and the Calls tab all read it, and
/// none of them should need a widget tree to do so.
class CallEvent {
  const CallEvent({
    required this.kind,
    required this.id,
    required this.type,
    required this.status,
    this.answeredAt,
    this.endedAt,
    this.duration,
    this.people,
    this.answeredOn,
    this.quality,
  });

  static const String prefix = 'call:';

  final CallEventKind kind;

  /// The `calls` / `groupCalls` id.
  final String id;
  final CallEventType type;
  final CallEventStatus status;

  /// When the call was answered. Null until then.
  final DateTime? answeredAt;

  /// When it ended. Null while live.
  final DateTime? endedAt;

  /// Time talked (`e - a`). Null when it was never answered.
  final Duration? duration;

  /// Group only: everyone who joined at some point, the starter included.
  final int? people;

  /// Direct only: platform tag of the callee device that answered.
  final String? answeredOn;
  final CallEventQuality? quality;

  bool get isVideo => type == CallEventType.video;
  bool get isGroup => kind == CallEventKind.group;

  /// Ringing or connected: the message is still moving.
  bool get isLive =>
      status == CallEventStatus.ringing || status == CallEventStatus.active;

  /// Whether [content] is a call message at all, even a malformed one. For the
  /// surfaces that cannot localize and must never show the raw code.
  static bool isCallContent(String content) => content.startsWith(prefix);

  /// [content] as a call, or null when it is any other message, or a call
  /// message this build cannot read (unknown shape, missing field).
  static CallEvent? parse(String content) {
    if (!content.startsWith(prefix)) return null;
    final Object? j;
    try {
      j = jsonDecode(content.substring(prefix.length));
    } catch (_) {
      return null;
    }
    if (j is! Map) return null;
    final v = j['v'];
    if (v is! int || v < 1) return null;
    final kind = switch (j['k']) {
      'd' => CallEventKind.direct,
      'g' => CallEventKind.group,
      _ => null,
    };
    final id = j['id'];
    final type = switch (j['t']) {
      'audio' => CallEventType.audio,
      'video' => CallEventType.video,
      _ => null,
    };
    final status = switch (j['s']) {
      'ringing' => CallEventStatus.ringing,
      'active' => CallEventStatus.active,
      'ended' => CallEventStatus.ended,
      'missed' => CallEventStatus.missed,
      'declined' => CallEventStatus.declined,
      'cancelled' => CallEventStatus.cancelled,
      _ => null,
    };
    if (kind == null ||
        id is! String ||
        id.isEmpty ||
        type == null ||
        status == null) {
      return null;
    }
    DateTime? at(Object? ms) => ms is num && ms >= 0
        ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
        : null;
    final d = j['d'];
    final n = j['n'];
    final o = j['o'];
    return CallEvent(
      kind: kind,
      id: id,
      type: type,
      status: status,
      answeredAt: at(j['a']),
      endedAt: at(j['e']),
      duration: d is num && d >= 0 ? Duration(milliseconds: d.toInt()) : null,
      // A count, or (be liberal) the list of who joined.
      people: n is int && n >= 1 ? n : (n is List && n.isNotEmpty ? n.length : null),
      answeredOn: o is String && o.isNotEmpty ? o : null,
      quality: switch (j['q']) {
        'good' => CallEventQuality.good,
        'fair' => CallEventQuality.fair,
        'poor' => CallEventQuality.poor,
        _ => null,
      },
    );
  }

  /// The wire form, for tests and for anything that has to write one.
  String get content {
    final m = <String, Object>{
      'v': 1,
      'k': isGroup ? 'g' : 'd',
      'id': id,
      't': isVideo ? 'video' : 'audio',
      's': status.name,
      if (answeredAt != null) 'a': answeredAt!.millisecondsSinceEpoch,
      if (endedAt != null) 'e': endedAt!.millisecondsSinceEpoch,
      if (duration != null) 'd': duration!.inMilliseconds,
      'n': ?people,
      'o': ?answeredOn,
      if (quality != null) 'q': quality!.name,
    };
    return '$prefix${jsonEncode(m)}';
  }

  /// Which row of the perspective table applies to a viewer. [isMine] is
  /// "the viewer started this call" (`message.userId`).
  CallPhase phaseFor({required bool isMine}) => switch (status) {
        CallEventStatus.ringing =>
          isMine ? CallPhase.calling : CallPhase.incomingRinging,
        CallEventStatus.active => CallPhase.live,
        CallEventStatus.ended =>
          isMine ? CallPhase.outgoingEnded : CallPhase.incomingEnded,
        CallEventStatus.missed => isMine ? CallPhase.noAnswer : CallPhase.missed,
        CallEventStatus.cancelled =>
          isMine ? CallPhase.cancelled : CallPhase.missed,
        CallEventStatus.declined => CallPhase.declined,
      };

  /// Whether the call was answered on a device other than the viewer's own
  /// (`ownPlatform` is a `DeviceIdentity.platformTag()`; the simulator counts
  /// as iOS). False when no device is recorded.
  bool answeredElsewhere(String ownPlatform) {
    final o = answeredOn;
    if (o == null) return false;
    String norm(String p) => p == 'ios-simulator' ? 'ios' : p;
    return norm(o) != norm(ownPlatform);
  }

  /// Two missed calls from the same caller that can share one ×N bubble.
  bool collapsesWith(CallEvent other) =>
      kind == CallEventKind.direct &&
      other.kind == CallEventKind.direct &&
      type == other.type &&
      _isUnanswered && other._isUnanswered;

  bool get _isUnanswered =>
      status == CallEventStatus.missed || status == CallEventStatus.cancelled;

  /// "12:41", or "1:02:03" past an hour.
  static String formatClock(Duration d) => fmt.formatClock(d);
}
