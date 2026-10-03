import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_toast.dart';
import 'room_items.dart' show formatClockDuration;
import '../widgets/ios_kit.dart' show GlassIconButton, SpringPress;
import '../widgets/sheet_kit.dart' show sentenceCaseOf;
import 'package:flutter/cupertino.dart' show CupertinoIcons;

/// The MIME for what [VoiceRecorderScreen] produces: AAC-LC in an ISO-BMFF
/// (MP4) container.
///
/// `audio/mp4` (RFC 4337) and NOT `audio/m4a`, which is what this used to send
/// and which is registered nowhere. Convex serves storage from an
/// extension-less URL — `<site>/api/storage/<uuid>` — so on iOS the served
/// content type is the *only* signal AVFoundation gets about the container, and
/// its MIME→UTI table has no entry for `audio/m4a`. Every voice note ever sent
/// therefore rendered "audio failed" while the bytes themselves were perfectly
/// good. (`audio/x-m4a` also works on Apple platforms, but it is an
/// unregistered iTunes vendor type — no reason to prefer it to the standard.)
///
/// Convex fixes contentType at upload time and it cannot be patched afterwards,
/// so this only helps notes sent from this build onward. `AudioFileCache` is
/// the half that revives the ones already stored.
const voiceNoteContentType = 'audio/mp4';

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
      showAppToast(
        context,
        AppLocalizations.of(context)
            .voiceRecorderScreenMicPermissionDeniedSnackbar,
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final p =
        '${dir.path}/mh_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    // The file this writes is not "faststart": the index (`moov`) lands after
    // the payload (`mdat`), because both backends here — AVAudioRecorder and
    // MediaMuxer — stream samples out and only finalise the index on stop.
    // That is hostile to progressive HTTP, and there is no knob on `record` to
    // change it; getting faststart would mean remuxing afterwards. Don't.
    // Playback downloads the whole file before handing it to the player (see
    // AudioFileCache), so atom order has no observable effect.
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 96000,
      ),
      path: p,
    );
    _started = DateTime.now();
    _path = p;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _started == null) return;
      setState(() => _elapsed = DateTime.now().difference(_started!));
    });
    _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen(
      (a) {
        if (!mounted) return;
        // amplitude.current is in dB, typically -60..0
        final norm = ((a.current + 45) / 45).clamp(0.0, 1.0);
        setState(() => _level = norm);
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              maxWidth: ContentWidth.auth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GlassIconButton(
                          icon: CupertinoIcons.xmark,
                          semanticLabel: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onTap: _discardAndExit,
                        ),
                        const Spacer(),
                        Text(
                          sentenceCaseOf(context, _recording
                              ? AppLocalizations.of(
                                  context,
                                ).voiceRecorderScreenStatusRecording
                              : (_recorded
                                    ? AppLocalizations.of(
                                        context,
                                      ).voiceRecorderScreenStatusReady
                                    : AppLocalizations.of(
                                        context,
                                      ).voiceRecorderScreenStatusTapToStart)),
                          style: theme.bodySoft.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _recording ? theme.danger : theme.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Amplitude meter
                    _Meter(level: _level, recording: _recording),
                    const SizedBox(height: 28),
                    Text(
                      formatClockDuration(_elapsed),
                      // Voice Memos' clock: big, light, fixed-width digits so
                      // it ticks without the number shuffling sideways.
                      style: theme.displayLarge.copyWith(
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(flex: 2),
                    if (!_recorded)
                      // The Voice Memos button: a white ring around a red
                      // disc that morphs into a stop square while recording.
                      _RecordButton(
                        recording: _recording,
                        label: sentenceCaseOf(
                          context,
                          _recording
                              ? AppLocalizations.of(context).voiceRecorderScreenStopButton
                              : AppLocalizations.of(context).voiceRecorderScreenRecordButton,
                        ),
                        onTap: _recording ? _stop : _start,
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _Capsule(
                              label: sentenceCaseOf(
                                context,
                                AppLocalizations.of(context).voiceRecorderScreenReRecordButton,
                              ),
                              filled: false,
                              onTap: () {
                                setState(() {
                                  _recorded = false;
                                  _elapsed = Duration.zero;
                                  _path = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Capsule(
                              label: sentenceCaseOf(
                                context,
                                AppLocalizations.of(context).voiceRecorderScreenSendButton,
                              ),
                              filled: true,
                              onTap: _confirm,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
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
                  color: (recording ? theme.danger : theme.accent).withValues(
                    alpha: 0.6,
                  ),
                  blurRadius: 28,
                ),
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

/// Voice Memos' record control: white ring, red centre that morphs between
/// a disc (record) and a rounded square (stop) on a spring.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.label,
    required this.onTap,
  });

  final bool recording;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final calm = MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpringPress(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.ink.withValues(alpha: 0.9), width: 4),
            ),
            child: AnimatedContainer(
              duration: calm
                  ? Duration.zero
                  : const Duration(milliseconds: 340),
              curve: Curves.easeOutBack,
              width: recording ? 32 : 66,
              height: recording ? 32 : 66,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(recording ? 8 : 33),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: theme.bodySoft.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.inkSoft,
          ),
        ),
      ],
    );
  }
}

/// A full-width capsule action: filled for the primary (Send), tinted for the
/// secondary (Re-record).
class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? theme.accent : theme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.body.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: filled ? theme.accentInk : theme.accent,
          ),
        ),
      ),
    );
  }
}
