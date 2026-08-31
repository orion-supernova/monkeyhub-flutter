import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Who is talking, for the rings around the faces.
///
/// WebRTC does not hand out audio levels as events; they sit in the stats
/// report, so somebody has to go and get them. This polls — but only while a
/// call screen is on and somebody is listening — and it polls the cheap way:
/// per unmuted peer, the stats scoped to that one remote audio track, which
/// is a handful of entries rather than the whole connection's report.
///
/// Levels come out smoothed and with hysteresis, because a raw level is a
/// flicker: it rises on the first syllable and drops in every gap between
/// words. A ring that blinked with every consonant would be worse than no
/// ring. So a speaker is "on" after two loud polls and "off" only after four
/// quiet ones, and the level that drives the ring's pulse decays rather than
/// dropping.
///
/// Each id gets its own [ValueNotifier], so only the ring that changed
/// repaints — never the screen, never the other rings. The local level comes
/// from the `media-source` entry of any one connection.
class AudioLevelMonitor {
  AudioLevelMonitor({this.interval = const Duration(milliseconds: 300)});

  /// How often to ask. Three times a second reads as live and costs a
  /// small platform call per peer.
  Duration interval;

  /// The id the local level is filed under.
  static const String me = 'me';

  /// Level at or above which two polls in a row make a speaker.
  static const double onThreshold = 0.08;

  /// Level below which four polls in a row unmake one.
  static const double offThreshold = 0.03;

  /// What to poll. Re-read on every tick so peers can come and go.
  Iterable<AudioLevelSource> Function() sources = () => const [];

  /// The connection to read our own level from, if any.
  RTCPeerConnection? Function() localPc = () => null;

  final Map<String, ValueNotifier<double>> _levels = {};
  final Map<String, int> _loud = {};
  final Map<String, int> _quiet = {};
  final Set<String> _speakingSet = {};

  /// Everyone currently speaking. Replaced (not mutated) on change.
  final ValueNotifier<Set<String>> speaking = ValueNotifier(const {});

  Timer? _timer;
  int _starts = 0;
  bool _polling = false;

  /// The smoothed level of [id], 0..1. Cached; a ring listens to one of
  /// these and nothing else.
  ValueNotifier<double> levelOf(String id) =>
      _levels.putIfAbsent(id, () => ValueNotifier<double>(0));

  /// Ref-counted: every screen that wants levels starts, and stops when it
  /// goes; the timer runs while anyone does.
  void start() {
    _starts++;
    _timer ??= Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    if (_starts > 0) _starts--;
    if (_starts > 0) return;
    _timer?.cancel();
    _timer = null;
    _settle();
  }

  bool get running => _timer != null;

  /// Everyone goes quiet — a call ended, a screen left.
  void _settle() {
    for (final n in _levels.values) {
      n.value = 0;
    }
    _loud.clear();
    _quiet.clear();
    if (_speakingSet.isNotEmpty) {
      _speakingSet.clear();
      speaking.value = const {};
    }
  }

  @visibleForTesting
  Future<void> pollNow() => _poll();

  Future<void> _poll() async {
    if (_polling) return; // a slow platform call must not pile up
    _polling = true;
    try {
      final seen = <String>{};
      for (final src in sources()) {
        seen.add(src.id);
        if (src.muted) {
          _apply(src.id, 0);
          continue;
        }
        _apply(src.id, await _remoteLevel(src));
      }
      final lpc = localPc();
      if (lpc != null) {
        seen.add(me);
        _apply(me, await _localLevel(lpc));
      }
      // Anyone gone from the sources goes quiet.
      for (final id in _levels.keys) {
        if (!seen.contains(id)) _apply(id, 0);
      }
    } finally {
      _polling = false;
    }
  }

  Future<double> _remoteLevel(AudioLevelSource src) async {
    try {
      final reports = await src.pc.getStats(src.track);
      double? level;
      for (final r in reports) {
        if (r.type != 'inbound-rtp') continue;
        final kind = r.values['kind'] ?? r.values['mediaType'];
        if (kind != null && kind != 'audio') continue;
        final v = r.values['audioLevel'];
        if (v is num) {
          level = v.toDouble();
          break;
        }
      }
      return (level ?? 0).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('AudioLevelMonitor: stats for ${src.id} failed: $e');
      return 0;
    }
  }

  Future<double> _localLevel(RTCPeerConnection pc) async {
    try {
      final reports = await pc.getStats();
      for (final r in reports) {
        if (r.type != 'media-source') continue;
        final kind = r.values['kind'] ?? r.values['mediaType'];
        if (kind != null && kind != 'audio') continue;
        final v = r.values['audioLevel'];
        if (v is num) return v.toDouble().clamp(0.0, 1.0);
      }
    } catch (e) {
      debugPrint('AudioLevelMonitor: local stats failed: $e');
    }
    return 0;
  }

  void _apply(String id, double raw) {
    final n = levelOf(id);
    // Decay rather than drop: the pulse eases out between words.
    final smoothed = raw > n.value * 0.6 ? raw : n.value * 0.6;
    if ((smoothed - n.value).abs() > 0.005) n.value = smoothed;

    if (raw >= onThreshold) {
      _loud[id] = (_loud[id] ?? 0) + 1;
      _quiet[id] = 0;
    } else if (raw < offThreshold) {
      _quiet[id] = (_quiet[id] ?? 0) + 1;
      _loud[id] = 0;
    }
    final isSpeaking = _speakingSet.contains(id);
    if (!isSpeaking && (_loud[id] ?? 0) >= 2) {
      _speakingSet.add(id);
      speaking.value = Set.unmodifiable(_speakingSet);
    } else if (isSpeaking && (_quiet[id] ?? 0) >= 4) {
      _speakingSet.remove(id);
      speaking.value = Set.unmodifiable(_speakingSet);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final n in _levels.values) {
      n.dispose();
    }
    _levels.clear();
    speaking.dispose();
  }
}

/// One remote participant to read a level for.
class AudioLevelSource {
  const AudioLevelSource({
    required this.id,
    required this.pc,
    required this.track,
    this.muted = false,
  });

  final String id;
  final RTCPeerConnection pc;

  /// The peer's audio track, so the stats can be scoped to it; null asks for
  /// the whole report and takes the first inbound audio entry.
  final MediaStreamTrack? track;
  final bool muted;
}
