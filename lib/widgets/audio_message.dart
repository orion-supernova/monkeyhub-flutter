import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../backend/chat_api.dart';
import '../media/audio_file_cache.dart';
import '../media/file_url_cache.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

/// How the bubble is currently rendering.
///
/// Replaces an earlier `bool _ready` + `Object? _error` pair, which could only
/// say "something went wrong" — and so rendered the same dead-end "audio
/// failed" for a burned view-once file (nothing to retry) and for a dropped
/// packet (very much worth retrying).
enum _Phase { loading, ready, failed, unavailable }

/// What the player should DRAW, derived from what `just_audio` reports.
///
/// A free function rather than inline in `build` because the interesting part
/// is not the layout, it is this translation — and it had two bugs in it that
/// only showed up after a note finished playing. `audio_completion_test.dart`
/// pins both.
class AudioDisplay {
  const AudioDisplay({required this.playing, required this.progress, required this.elapsed});

  /// Whether to draw the PAUSE glyph, and whether a tap means "pause".
  final bool playing;

  /// 0..1 for the scrubber.
  final double progress;

  /// The left-hand half of `0:07 / 0:42`.
  final Duration elapsed;
}

/// Translates a raw player state into what the bubble shows.
///
/// Two things here are not obvious and were both wrong before:
///
///  * **`just_audio` does not clear `playing` when a track finishes.** It emits
///    `PlayerState(playing: true, processingState: completed)` and leaves it
///    there. Reading [rawPlaying] alone therefore claims a finished note is
///    still playing — which drew a pause button on a stopped voice note and,
///    worse, sent the tap handler down its `pause()` branch, so the first tap
///    after it ended did nothing and replaying took two taps.
///
///  * **The position stream stops a tick short of the duration.** Its last
///    emission is a frame or so under [total] and then it goes quiet, so a
///    finished note rested at about 97% — a bar that visibly never arrives,
///    beside a readout saying `0:41 / 0:42`.
///
/// Both are fixed by treating `completed` as the authority it is: the note is
/// not playing, and it is exactly at the end.
AudioDisplay audioDisplayFor({
  required bool rawPlaying,
  required bool completed,
  required Duration position,
  required Duration total,
}) {
  if (completed) {
    return AudioDisplay(playing: false, progress: 1, elapsed: total);
  }
  return AudioDisplay(
    playing: rawPlaying,
    progress: total.inMilliseconds == 0
        ? 0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
    elapsed: position,
  );
}

/// Inline audio bubble. Resolves [storageId] → a playable source, lazy-loads it
/// into a [just_audio] player, plays in place. Minimal UX: play/pause +
/// position scrubber.
///
/// Off-web the source is a *local file*, not the storage URL — see
/// [AudioFileCache] for why streaming an extension-less Convex URL is what made
/// every voice note unplayable.
class AudioMessage extends StatefulWidget {
  const AudioMessage({
    super.key,
    required this.api,
    required this.storageId,
    required this.isMine,
  });
  final ChatApi api;
  final String? storageId;
  final bool isMine;

  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage> {
  final _player = AudioPlayer();
  _Phase _phase = _Phase.loading;

  /// From `setFilePath`/`setUrl`, which know the duration before the position
  /// stream has ticked once.
  Duration? _duration;

  /// Web only. Revoked on dispose — an object URL left dangling pins its bytes
  /// for the life of the document.
  String? _blobUrl;

  /// Guards against a slow resolve landing after a newer one has started, which
  /// a recycled row makes entirely possible.
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AudioMessage old) {
    super.didUpdateWidget(old);
    // `message_bubble.dart` builds this with no key, so the ListView recycles
    // one State onto a different message as rows scroll. Without this the
    // bubble keeps playing — and showing the duration of — the previous note.
    if (old.storageId == widget.storageId) return;
    _revokeBlob();
    unawaited(_player.stop());
    setState(() {
      _phase = _Phase.loading;
      _duration = null;
    });
    _resolve();
  }

  @override
  void dispose() {
    _revokeBlob();
    _player.dispose();
    super.dispose();
  }

  void _revokeBlob() {
    final url = _blobUrl;
    if (url == null) return;
    _blobUrl = null;
    revokeWebPlayableUrl(url);
  }

  /// Loads the audio. With [fresh], throws away any local copy first — the
  /// eviction is awaited here rather than fired off beside the reload, because
  /// a delete still in flight will happily remove the file the reload has just
  /// finished renaming into place.
  Future<void> _resolve({bool fresh = false}) async {
    final id = widget.storageId;
    if (id == null || id.isEmpty) return;
    final gen = ++_gen;
    try {
      if (fresh && !kIsWeb) await AudioFileCache.instance.evict(id);
      // The timeout covers the whole load, not just the download. What the
      // sender actually saw was the spinner and the literal "loading…" forever,
      // because an asset AVFoundation can't identify neither completes nor
      // throws — it just stops. An endless spinner is worse than a failure,
      // because a failure now has a retry on it.
      await _load(id, gen).timeout(const Duration(seconds: 45));
      if (!mounted || gen != _gen) return;
      setState(() => _phase = _Phase.ready);
    } on FileUnavailable {
      if (!mounted || gen != _gen) return;
      setState(() => _phase = _Phase.unavailable);
    } catch (e) {
      debugPrint('AudioMessage: $id failed to load: $e');
      if (!mounted || gen != _gen) return;
      setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _load(String id, int gen) async {
    Future<String?> url() =>
        FileUrlCache.instance.resolve(id, () => widget.api.getFileUrl(id));

    if (kIsWeb) {
      final remote = await url();
      if (remote == null) throw const FileUnavailable();
      final blob = await webPlayableUrl(remote);
      if (gen != _gen) {
        // A newer load overtook this one. Revoking the blob we just minted is
        // the only chance to release its bytes — nothing else holds a handle.
        if (blob != null) revokeWebPlayableUrl(blob);
        return;
      }
      _revokeBlob();
      _blobUrl = blob;
      // Falling back to the raw URL on a CORS refusal preserves exactly the
      // behaviour that shipped, which browsers other than Safari sniff fine.
      _duration = await _player.setUrl(blob ?? remote);
      return;
    }

    try {
      _duration = await _player
          .setFilePath(await AudioFileCache.instance.resolve(id, url));
    } on FileUnavailable {
      rethrow;
    } catch (_) {
      // One silent retry against a fresh copy. The file can be gone or
      // half-written underneath us in two ordinary ways: iOS purges
      // Library/Caches under disk pressure at any moment, and a download
      // interrupted by suspension leaves nothing usable. Both look identical
      // from here and both are fixed by downloading again, so doing it
      // silently beats making the user tap.
      await AudioFileCache.instance.evict(id);
      _duration = await _player
          .setFilePath(await AudioFileCache.instance.resolve(id, url));
    }
  }

  void _retry() {
    final id = widget.storageId;
    if (id == null) return;
    HapticFeedback.selectionClick();
    // The two things most likely to make this fail twice are a stale URL and a
    // bad local copy, and both are cached. `FileUrlCache.invalidate` has
    // existed since that cache was written and never had a caller — this is
    // the case it was written for.
    FileUrlCache.instance.invalidate(id);
    setState(() {
      _phase = _Phase.loading;
      _duration = null;
    });
    unawaited(_resolve(fresh: true));
  }

  /// The 34pt circle every state shares, so the bubble never resizes as it
  /// moves between them.
  Widget _disc(
    AppTheme theme,
    Color ink, {
    required Widget child,
    VoidCallback? onTap,
  }) {
    final disc = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: widget.isMine ? ink.withValues(alpha: 0.2) : theme.accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
    if (onTap == null) return disc;
    return GestureDetector(onTap: onTap, child: disc);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = widget.isMine ? theme.accentInk : theme.ink;
    final onDisc = widget.isMine ? ink : theme.accentInk;

    if (widget.storageId == null) {
      return Text('[audio missing]', style: theme.body.copyWith(color: ink));
    }

    if (_phase == _Phase.unavailable) {
      // The backend has no URL for this id — burned view-once, or a swept blob.
      // Retrying can only produce the same nothing, so there is no button.
      return Text('audio unavailable', style: theme.body.copyWith(color: ink));
    }

    if (_phase == _Phase.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _disc(theme, ink,
              onTap: _retry, child: Icon(Icons.refresh, color: onDisc, size: 18)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text('tap to retry',
                style: theme.monoTiny.copyWith(color: ink.withValues(alpha: 0.8))),
          ),
        ],
      );
    }

    final ready = _phase == _Phase.ready;
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final processing = snap.data?.processingState;
        final completed = processing == ProcessingState.completed;
        return StreamBuilder<Duration?>(
          stream: _player.positionStream,
          builder: (context, posSnap) {
            // `_duration` is the value setFilePath returned, available a beat
            // before the player's own stream reports one — which is why this
            // used to sit on "loading…" after the audio was already loaded.
            final total = _player.duration ?? _duration ?? Duration.zero;
            // Everything about how a finished note should look lives in here.
            final display = audioDisplayFor(
              rawPlaying: snap.data?.playing ?? false,
              completed: completed,
              position: posSnap.data ?? Duration.zero,
              total: total,
            );
            final playing = display.playing;
            final progress = display.progress;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _disc(
                  theme,
                  ink,
                  onTap: !ready
                      ? null
                      : () {
                          if (playing) {
                            _player.pause();
                          } else {
                            if (processing == ProcessingState.completed) {
                              _player.seek(Duration.zero);
                            }
                            _player.play();
                          }
                        },
                  child: !ready
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: onDisc,
                          ),
                        )
                      : Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          color: onDisc,
                          size: 18,
                        ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ink,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        total > Duration.zero
                            ? '${formatClockDuration(display.elapsed)}'
                                ' / ${formatClockDuration(total)}'
                            : 'loading…',
                        style: theme.monoTiny
                            .copyWith(color: ink.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
