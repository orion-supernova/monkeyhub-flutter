import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/theme_scope.dart';

/// Records an AAC voice note and pops its bytes.
///
/// Mobile and desktop only — the attachment menu does not offer the voice tile
/// in a browser. `getTemporaryDirectory` below has no web implementation, and
/// `record_web` would hand back opus/webm rather than the AAC that the send
/// path labels it as and the players downstream expect.
class VoiceRecorderScreen extends StatefulWidget {
  const VoiceRecorderScreen({super.key});
  @override
  State<VoiceRecorderScreen> createState() => _VoiceRecorderScreenState();
}

class _VoiceRecorderScreenState extends State<VoiceRecorderScreen> {
  final _rec = AudioRecorder();
  String? _path;
  bool _recording = false;
  bool _recorded = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  DateTime? _started;
  double _level = 0;
  StreamSubscription<Amplitude>? _ampSub;

  @override
  void dispose() {
    _ticker?.cancel();
    _ampSub?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('microphone permission denied')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final p = '${dir.path}/mh_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 96000),
      path: p,
    );
    _started = DateTime.now();
    _path = p;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _started == null) return;
      setState(() => _elapsed = DateTime.now().difference(_started!));
    });
    _ampSub = _rec
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((a) {
      if (!mounted) return;
      // amplitude.current is in dB, typically -60..0
      final norm = ((a.current + 45) / 45).clamp(0.0, 1.0);
      setState(() => _level = norm);
    });
    setState(() {
      _recording = true;
      _recorded = false;
    });
  }

  Future<void> _stop() async {
    final p = await _rec.stop();
    _ticker?.cancel();
    _ampSub?.cancel();
    setState(() {
      _recording = false;
      _recorded = p != null;
      _path = p ?? _path;
    });
  }

  Future<void> _discardAndExit() async {
    if (_recording) await _rec.stop();
    final p = _path;
    if (p != null) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop<Uint8List?>(null);
  }

  /// Reads the recording off disk and hands back the bytes, so the caller never
  /// has to know a temp file was involved — the upload path is bytes-only.
  Future<void> _confirm() async {
    final p = _path;
    if (p == null) return;
    Uint8List bytes;
    try {
      bytes = await File(p).readAsBytes();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop<Uint8List?>(bytes);
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                children: [
                  Row(children: [
                    IconButton(
                      onPressed: _discardAndExit,
                      icon: Icon(Icons.close, color: theme.inkSoft),
                    ),
                    const Spacer(),
                    Text(_recording ? 'RECORDING' : (_recorded ? 'READY' : 'TAP TO START'),
                        style: theme.label.copyWith(
                            color: _recording ? theme.danger : theme.accent, letterSpacing: 2.4)),
                  ]),
                  const Spacer(),
                  // Amplitude meter
                  _Meter(level: _level, recording: _recording),
                  const SizedBox(height: 28),
                  Text(_fmt(_elapsed), style: theme.displayLarge.copyWith(fontSize: 44)),
                  const Spacer(flex: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_recorded)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _recorded = false;
                                _elapsed = Duration.zero;
                                _path = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.divider),
                                borderRadius: BorderRadius.circular(theme.radiusMd),
                              ),
                              child: Text('RE-RECORD', style: theme.label),
                            ),
                          ),
                        ),
                      if (_recorded) const SizedBox(width: 10),
                      Expanded(
                        flex: _recorded ? 1 : 2,
                        child: GestureDetector(
                          onTap: () {
                            if (_recording) {
                              _stop();
                            } else if (_recorded) {
                              _confirm();
                            } else {
                              _start();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _recording ? theme.danger : theme.accent,
                              borderRadius: BorderRadius.circular(theme.radiusMd),
                            ),
                            child: Text(
                              _recording
                                  ? 'STOP'
                                  : (_recorded ? 'SEND' : 'RECORD'),
                              style: theme.label.copyWith(
                                  color: theme.accentInk, letterSpacing: 2.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.level, required this.recording});
  final double level;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final radius = 60.0 + level * 80;
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.accent.withValues(alpha: recording ? 0.15 : 0.06),
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording ? theme.danger : theme.accent,
              boxShadow: [
                BoxShadow(
                    color: (recording ? theme.danger : theme.accent).withValues(alpha: 0.6),
                    blurRadius: 28),
              ],
            ),
            child: Icon(
              recording ? Icons.stop : Icons.mic,
              size: 38,
              color: theme.accentInk,
            ),
          ),
        ],
      ),
    );
  }
}
