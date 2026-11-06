import 'package:flutter/foundation.dart';

/// How a call went for me (`callLog.outcome`).
enum CallOutcome {
  answered,
  missed,
  unanswered,
  declined,
  cancelled;

  static CallOutcome parse(Object? s) => switch (s) {
        'answered' => answered,
        'missed' => missed,
        'declined' => declined,
        'cancelled' => cancelled,
        _ => unanswered,
      };
}

enum CallLogKind {
  direct,
  group,
  huddle;

  static CallLogKind parse(Object? s) => switch (s) {
        'group' => group,
        'huddle' => huddle,
        _ => direct,
      };
}

/// One move of a call between my devices.
@immutable
class CallHandoff {
  const CallHandoff({required this.at, required this.platform});
  final int at;
  final String platform;
}

/// One `callLog` row: one person's side of one call.
@immutable
class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.roomId,
    required this.kind,
    required this.video,
    required this.incoming,
    required this.outcome,
    required this.startedAt,
    required this.endedAt,
    this.durationMs = 0,
    this.peerId,
    this.people,
    this.ringingAt,
    this.answeredAt,
    this.answeredOn,
    this.handoffs = const [],
    this.qualityWorst,
    this.qualitySamples = const [],
  });

  final String id;
  final String roomId;
  final CallLogKind kind;
  final bool video;
  final bool incoming;
  final CallOutcome outcome;
  final String? peerId;
  final int? people;
  final int startedAt;
  final int? ringingAt;
  final int? answeredAt;
  final int endedAt;
  final int durationMs;
  final String? answeredOn;
  final List<CallHandoff> handoffs;
  final String? qualityWorst;

  /// One bucket per 10 s connected: 0 good, 1 fair, 2 poor.
  final List<int> qualitySamples;

  bool get isMissed => outcome == CallOutcome.missed;
  bool get wasAnswered => outcome == CallOutcome.answered;

  factory CallLogEntry.fromJson(Map<String, dynamic> j) {
    int? n(String k) => (j[k] as num?)?.toInt();
    final q = j['quality'];
    return CallLogEntry(
      id: j['_id'].toString(),
      roomId: j['roomId'].toString(),
      kind: CallLogKind.parse(j['kind']),
      video: j['type'] == 'video',
      incoming: j['direction'] == 'in',
      outcome: CallOutcome.parse(j['outcome']),
      peerId: j['peerId']?.toString(),
      people: n('people'),
      startedAt: n('startedAt') ?? 0,
      ringingAt: n('ringingAt'),
      answeredAt: n('answeredAt'),
      endedAt: n('endedAt') ?? n('startedAt') ?? 0,
      durationMs: n('durationMs') ?? 0,
      answeredOn: j['answeredOn']?.toString(),
      handoffs: [
        for (final h in (j['handoffs'] as List?) ?? const [])
          if (h is Map)
            CallHandoff(
              at: (h['at'] as num?)?.toInt() ?? 0,
              platform: h['platform']?.toString() ?? '',
            ),
      ],
      qualityWorst: q is Map ? q['worst']?.toString() : null,
      qualitySamples: q is Map
          ? [
              for (final s in (q['samples'] as List?) ?? const [])
                if (s is num) s.toInt().clamp(0, 2),
            ]
          : const [],
    );
  }
}

/// A page of `callLog:list` (Convex pagination result).
@immutable
class CallLogPage {
  const CallLogPage({
    required this.rows,
    required this.isDone,
    this.continueCursor,
  });
  final List<CallLogEntry> rows;
  final bool isDone;
  final String? continueCursor;

  factory CallLogPage.fromJson(Map<String, dynamic> j) => CallLogPage(
        rows: [
          for (final r in (j['page'] as List?) ?? const [])
            if (r is Map) CallLogEntry.fromJson(r.cast<String, dynamic>()),
        ],
        isDone: j['isDone'] != false,
        continueCursor: j['continueCursor']?.toString(),
      );
}

@immutable
class CallTopPeer {
  const CallTopPeer({required this.peerId, required this.ms, required this.calls});
  final String peerId;
  final int ms;
  final int calls;
}

/// One pinned person from `callFavorites:list`.
@immutable
class CallFavourite {
  const CallFavourite({required this.peerId, required this.addedAt});
  final String peerId;
  final int addedAt;

  /// `[{peerId, addedAt}]`, kept in the order given (oldest first).
  static List<CallFavourite> parseList(dynamic raw) => [
        if (raw is List)
          for (final r in raw)
            if (r is Map && r['peerId'] != null)
              CallFavourite(
                peerId: r['peerId'].toString(),
                addedAt: (r['addedAt'] as num?)?.toInt() ?? 0,
              ),
      ];
}

/// `callLog:summary`: connected time and the people talked to most.
@immutable
class CallLogSummary {
  const CallLogSummary({
    required this.totalMs,
    required this.calls,
    required this.top,
  });
  final int totalMs;
  final int calls;
  final List<CallTopPeer> top;

  static const empty = CallLogSummary(totalMs: 0, calls: 0, top: []);

  factory CallLogSummary.fromJson(Map<String, dynamic> j) => CallLogSummary(
        totalMs: (j['totalMs'] as num?)?.toInt() ?? 0,
        calls: (j['calls'] as num?)?.toInt() ?? 0,
        top: [
          for (final t in (j['top'] as List?) ?? const [])
            if (t is Map && t['peerId'] != null)
              CallTopPeer(
                peerId: t['peerId'].toString(),
                ms: (t['ms'] as num?)?.toInt() ?? 0,
                calls: (t['calls'] as num?)?.toInt() ?? 0,
              ),
        ],
      );
}

/// A line of the grouped list: a day header or a (possibly merged) call row.
sealed class CallListItem {
  const CallListItem();
}

class CallDayHeader extends CallListItem {
  const CallDayHeader(this.day);

  /// Local midnight of the day.
  final DateTime day;
}

/// One or more consecutive entries that read as the same call: same room,
/// kind, type, direction and outcome, on the same local day.
class CallRow extends CallListItem {
  const CallRow(this.entries);

  /// Newest first.
  final List<CallLogEntry> entries;
  CallLogEntry get first => entries.first;
  int get count => entries.length;
}

DateTime _dayOf(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime(d.year, d.month, d.day);
}

bool _sameCall(CallLogEntry a, CallLogEntry b) =>
    a.roomId == b.roomId &&
    a.kind == b.kind &&
    a.video == b.video &&
    a.incoming == b.incoming &&
    a.outcome == b.outcome &&
    a.peerId == b.peerId;

/// Turns newest-first [entries] into day headers and merged rows.
List<CallListItem> groupCallLog(List<CallLogEntry> entries) {
  final out = <CallListItem>[];
  DateTime? day;
  List<CallLogEntry>? run;
  void flush() {
    if (run != null) out.add(CallRow(run!));
    run = null;
  }

  for (final e in entries) {
    final d = _dayOf(e.startedAt);
    if (day != d) {
      flush();
      day = d;
      out.add(CallDayHeader(d));
    }
    if (run != null && _sameCall(run!.last, e)) {
      run!.add(e);
    } else {
      flush();
      run = [e];
    }
  }
  flush();
  return out;
}

/// Missed calls newer than [seenAt]: the Calls tab badge.
int missedSince(Iterable<CallLogEntry> missed, int seenAt) {
  var n = 0;
  for (final e in missed) {
    if (e.isMissed && e.startedAt > seenAt) n++;
  }
  return n;
}
