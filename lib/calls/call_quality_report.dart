import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/call_log_api.dart';
import 'call_stats_monitor.dart';

/// 0 good, 1 fair, 2 poor: the wire value of a [CallQuality] in a quality
/// report (`callLog.quality.samples`).
int qualityBucketValue(CallQuality q) => switch (q) {
      CallQuality.good => 0,
      CallQuality.fair => 1,
      CallQuality.poor => 2,
    };

/// Folds the 2-second [CallQualitySnapshot] stream of a call into one bucket
/// per 10 seconds connected (the worst snapshot in the bucket wins), at most
/// [cap] buckets.
///
/// Nothing leaves the device while the call runs: the samples are held here
/// and handed over once, by [take], when the call ends. A stretch with no
/// snapshots (stats briefly stalled) repeats the last bucket so the strip's
/// length still tracks the time connected.
class CallQualityRecorder {
  CallQualityRecorder({
    this.bucket = const Duration(seconds: 10),
    this.cap = 360,
  });

  final Duration bucket;
  final int cap;

  final List<int> _done = [];
  DateTime? _start;
  int _open = -1;
  int _worst = 0;

  /// True once at least one snapshot has been recorded.
  bool get hasData => _start != null;

  void add(CallQuality q, DateTime now) {
    final start = _start ??= now;
    final index = now.difference(start).inMilliseconds ~/ bucket.inMilliseconds;
    if (_open < 0) _open = index;
    if (index > _open) {
      // Close the bucket that was open, then carry its value across any gap.
      _done.add(_worst);
      for (var i = _open + 1; i < index; i++) {
        _done.add(_worst);
      }
      _open = index;
      _worst = 0;
    }
    final v = qualityBucketValue(q);
    if (v > _worst) _worst = v;
  }

  /// The buckets so far, the open one included, and starts over. Empty when
  /// nothing was recorded.
  List<int> take() {
    if (_start == null) return const [];
    final out = [..._done, _worst];
    _done.clear();
    _start = null;
    _open = -1;
    _worst = 0;
    return out.length > cap ? out.sublist(0, cap) : out;
  }

  void reset() {
    _done.clear();
    _start = null;
    _open = -1;
    _worst = 0;
  }
}

/// How a finished call's samples reach the server. Swappable for tests.
typedef QualityReporter = Future<void> Function({
  String? callId,
  String? groupCallId,
  required List<int> samples,
});

Future<void> _defaultReporter({
  String? callId,
  String? groupCallId,
  required List<int> samples,
}) =>
    CallLogApi.shared.reportQuality(
      callId: callId,
      groupCallId: groupCallId,
      samples: samples,
    );

QualityReporter qualityReporter = _defaultReporter;

/// Fire and forget: sent after the call is over, never awaited by hang-up, and
/// every failure swallowed (a missing report just hides the strip).
void sendQualityReport({
  String? callId,
  String? groupCallId,
  required List<int> samples,
}) {
  if (samples.isEmpty || (callId == null && groupCallId == null)) return;
  unawaited(
    qualityReporter(callId: callId, groupCallId: groupCallId, samples: samples)
        .catchError((Object e) {
      debugPrint('callLog:reportQuality failed: $e');
    }),
  );
}
