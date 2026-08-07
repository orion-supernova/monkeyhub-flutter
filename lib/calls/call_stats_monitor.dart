import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Coarse connection quality derived from WebRTC stats. `poor` drives the
/// warning chip in the call UI; `fair` shows a subtle indicator.
enum CallQuality { good, fair, poor }

/// One 2-second stats poll, condensed to what the UI and logs care about.
class CallQualitySnapshot {
  const CallQualitySnapshot({
    required this.quality,
    this.rttMs,
    this.lossPercent,
    this.outKbps,
    this.inKbps,
    this.jitterMs,
    this.frameWidth,
    this.frameHeight,
    this.fps,
    this.limitationReason,
    this.candidateType,
  });

  final CallQuality quality;
  final double? rttMs;
  final double? lossPercent;
  final double? outKbps;

  /// Inbound (received) bitrate — the counterpart to [outKbps]. Same delta
  /// math, off `inbound-rtp.bytesReceived`.
  final double? inKbps;

  /// Jitter buffer delay on the inbound stream, straight from
  /// `inbound-rtp.jitter` (WebRTC reports it in seconds; converted to ms).
  final double? jitterMs;
  final int? frameWidth;
  final int? frameHeight;
  final double? fps;

  /// libwebrtc's own diagnosis of why send quality is capped:
  /// none | bandwidth | cpu | other. The single most useful field when a
  /// user reports pixelation.
  final String? limitationReason;

  /// Local candidate type of the nominated pair — host/srflx/relay. Tells
  /// whether the TURN server is in the media path.
  final String? candidateType;
}

/// Polls [RTCPeerConnection.getStats] every 2s while a call is active and
/// publishes a [CallQualitySnapshot] into [target]. One platform-channel
/// call per poll plus delta math — cheap by construction.
class CallStatsMonitor {
  CallStatsMonitor({required this.pc, required this.target});

  final RTCPeerConnection pc;
  final ValueNotifier<CallQualitySnapshot?> target;

  Timer? _timer;
  int _lastBytesSent = 0;
  int _lastBytesReceived = 0;
  int _lastPacketsLost = 0;
  int _lastPacketsReceived = 0;
  DateTime? _lastPollAt;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    target.value = null;
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _poll() async {
    List<StatsReport> reports;
    try {
      reports = await pc.getStats();
    } catch (_) {
      return;
    }
    final now = DateTime.now();
    final elapsed = _lastPollAt == null
        ? null
        : now.difference(_lastPollAt!).inMilliseconds / 1000.0;
    _lastPollAt = now;

    double? rttMs;
    String? candidateType;
    double? outKbps;
    double? inKbps;
    double? videoJitterMs;
    double? audioJitterMs;
    int? frameWidth;
    int? frameHeight;
    double? fps;
    String? limitationReason;
    double? lossPercent;
    double? inboundFps;

    // Nominated candidate pair → RTT + which path carries the media.
    for (final r in reports) {
      if (r.type != 'candidate-pair') continue;
      final v = r.values;
      final succeeded = v['state'] == 'succeeded';
      final nominated = v['nominated'] == true || v['nominated'] == 'true';
      if (!succeeded || !nominated) continue;
      final rtt = _num(v['currentRoundTripTime']);
      if (rtt != null) rttMs = rtt * 1000;
      final localId = v['localCandidateId']?.toString();
      if (localId != null) {
        for (final c in reports) {
          if (c.id == localId) {
            candidateType = c.values['candidateType']?.toString();
            break;
          }
        }
      }
      break;
    }

    int bytesSent = 0;
    for (final r in reports) {
      final v = r.values;
      final kind = (v['kind'] ?? v['mediaType'])?.toString();
      if (r.type == 'outbound-rtp' && kind == 'video') {
        bytesSent += _num(v['bytesSent'])?.toInt() ?? 0;
        fps = _num(v['framesPerSecond']) ?? fps;
        frameWidth = _num(v['frameWidth'])?.toInt() ?? frameWidth;
        frameHeight = _num(v['frameHeight'])?.toInt() ?? frameHeight;
        limitationReason =
            v['qualityLimitationReason']?.toString() ?? limitationReason;
      }
    }
    if (elapsed != null && elapsed > 0 && bytesSent >= _lastBytesSent) {
      outKbps = (bytesSent - _lastBytesSent) * 8 / 1000 / elapsed;
    }
    _lastBytesSent = bytesSent;

    int packetsLost = 0;
    int packetsReceived = 0;
    int bytesReceived = 0;
    for (final r in reports) {
      if (r.type != 'inbound-rtp') continue;
      final v = r.values;
      packetsLost += _num(v['packetsLost'])?.toInt() ?? 0;
      packetsReceived += _num(v['packetsReceived'])?.toInt() ?? 0;
      // Total download bitrate, audio + video — unlike [outKbps] this isn't
      // video-only, since jitter/bitrate on the audio leg matters just as
      // much for a voice-only call.
      bytesReceived += _num(v['bytesReceived'])?.toInt() ?? 0;
      final jitter = _num(v['jitter']);
      final kind = (v['kind'] ?? v['mediaType'])?.toString();
      if (kind == 'video') {
        inboundFps = _num(v['framesPerSecond']) ?? inboundFps;
        if (jitter != null) videoJitterMs = jitter * 1000;
      } else if (kind == 'audio') {
        if (jitter != null) audioJitterMs = jitter * 1000;
      }
    }
    // Video leg preferred when both exist, same convention as [videoFps]
    // below — otherwise whichever report happened to be visited last in
    // getStats()'s unordered result would silently win.
    final jitterMs = videoJitterMs ?? audioJitterMs;
    final dLost = packetsLost - _lastPacketsLost;
    final dRecv = packetsReceived - _lastPacketsReceived;
    if (dRecv + dLost > 0 && dLost >= 0 && dRecv >= 0) {
      lossPercent = dLost * 100 / (dRecv + dLost);
    }
    _lastPacketsLost = packetsLost;
    _lastPacketsReceived = packetsReceived;
    if (elapsed != null && elapsed > 0 && bytesReceived >= _lastBytesReceived) {
      inKbps = (bytesReceived - _lastBytesReceived) * 8 / 1000 / elapsed;
    }
    _lastBytesReceived = bytesReceived;

    final videoFps = fps ?? inboundFps;
    final quality = classifyQuality(
      rttMs: rttMs,
      lossPercent: lossPercent,
      videoFps: videoFps,
      limitationReason: limitationReason,
    );

    if (kDebugMode) {
      debugPrint(
        'stats: rtt=${rttMs?.toStringAsFixed(0) ?? '?'}ms '
        'loss=${lossPercent?.toStringAsFixed(1) ?? '?'}% '
        'out=${outKbps?.toStringAsFixed(0) ?? '?'}kbps '
        '${frameWidth ?? '?'}x${frameHeight ?? '?'}@'
        '${videoFps?.toStringAsFixed(0) ?? '?'} '
        'limit=${limitationReason ?? '?'} path=${candidateType ?? '?'}',
      );
    }

    target.value = CallQualitySnapshot(
      quality: quality,
      rttMs: rttMs,
      lossPercent: lossPercent,
      outKbps: outKbps,
      inKbps: inKbps,
      jitterMs: jitterMs,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      fps: videoFps,
      limitationReason: limitationReason,
      candidateType: candidateType,
    );
  }
}

/// Pure so it's unit-testable: thresholds per the field playbook — poor when
/// the call is visibly degraded, fair when the encoder is already fighting.
CallQuality classifyQuality({
  double? rttMs,
  double? lossPercent,
  double? videoFps,
  String? limitationReason,
}) {
  if ((rttMs ?? 0) > 400 ||
      (lossPercent ?? 0) > 8 ||
      (videoFps != null && videoFps < 10)) {
    return CallQuality.poor;
  }
  if ((rttMs ?? 0) > 250 ||
      (lossPercent ?? 0) > 3 ||
      (limitationReason != null &&
          limitationReason != 'none' &&
          limitationReason.isNotEmpty)) {
    return CallQuality.fair;
  }
  return CallQuality.good;
}
