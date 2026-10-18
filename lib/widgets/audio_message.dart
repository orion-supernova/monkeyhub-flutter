import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../media/audio_file_cache.dart';
import '../media/file_url_cache.dart';
import '../media/view_once_fetch.dart' show ViewOnceOpener;
import '../media/view_once_media.dart';
import '../privacy/app_only.dart';
import '../privacy/capture_protection.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../screens/voice_recorder_screen.dart' show voiceNoteContentType;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../transcripts/language_hint.dart';
import '../transcripts/voice_transcriber.dart';
import 'dust_dissolve.dart';
import 'spring_press.dart';
import 'view_once_seal.dart';
import 'voice_transcript.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoIcons;

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
    this.seedKey,
    this.roomId,
    this.senderId,
  });
  final ChatApi api;
  final String? storageId;
  final bool isMine;

  /// Where the note was sent and by whom — only to guess its language from
  /// what the sender writes, for the built-in recognizer that must be told
  /// (see [VoiceLanguageHints]).
  final String? roomId;
  final String? senderId;

  /// What shapes the waveform: the same key the note's uploading row used
  /// (see `voiceBarsSeed`), so the bars do not change shape the moment the
  /// upload finishes. [storageId] when there is none.
  final String? seedKey;

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
    // A spring and a focus stop like every control (it was a bare
    // GestureDetector: no press, unreachable by keyboard).
    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.circle,
      focusRadius: 17,
      child: disc,
    );
  }

  /// The 13pt meta line under the waveform — the body face with tabular
  /// digits, not the caption slot (tracked mono at 12 on a character theme).
  TextStyle _metaStyle(AppTheme theme, Color ink) => theme.body.copyWith(
        fontSize: 13,
        height: 1.2,
        color: ink.withValues(alpha: 0.8),
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = widget.isMine ? theme.accentInk : theme.ink;
    final onDisc = widget.isMine ? ink : theme.accentInk;

    if (widget.storageId == null) {
      return Text(AppLocalizations.of(context).audioMessageMissingLabel,
          style: theme.body.copyWith(color: ink));
    }

    if (_phase == _Phase.unavailable) {
      // The backend has no URL for this id — burned view-once, or a swept blob.
      // Retrying can only produce the same nothing, so there is no button.
      return Text(AppLocalizations.of(context).audioMessageUnavailableLabel,
          style: theme.body.copyWith(color: ink));
    }

    if (_phase == _Phase.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _disc(theme, ink,
              onTap: _retry,
              child: Icon(CupertinoIcons.arrow_clockwise, color: onDisc, size: 17)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              sentenceCaseOf(
                context,
                AppLocalizations.of(context).audioMessageRetryHint,
              ),
              style: _metaStyle(theme, ink),
            ),
          ),
        ],
      );
    }

    final ready = _phase == _Phase.ready;
    // Null where the platform cannot transcribe (web). A map lookup otherwise.
    final transcript = VoiceTranscriber.instance.supported
        ? VoiceTranscriber.instance.handleFor(widget.storageId!)
        : null;
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
            final row = Row(
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
                      ? CupertinoActivityIndicator(radius: 7, color: onDisc)
                      // Play morphs into pause with a quick scale, the
                      // iMessage control.
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: Icon(
                            playing
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            key: ValueKey(playing),
                            color: onDisc,
                            size: 17,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // iMessage's waveform: bars seeded by the recording, so
                      // every note has its own shape and keeps it; played
                      // bars take the full ink.
                      SizedBox(
                        height: 20,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            seed: (widget.seedKey ?? widget.storageId ?? '').hashCode,
                            progress: progress,
                            played: ink,
                            unplayed: ink.withValues(alpha: 0.32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        total > Duration.zero
                            ? '${formatClockDuration(display.elapsed)}'
                                ' / ${formatClockDuration(total)}'
                            : AppLocalizations.of(context)
                                .audioMessageLoadingLabel,
                        style: _metaStyle(theme, ink),
                      ),
                    ],
                  ),
                ),
                if (transcript != null) ...[
                  const SizedBox(width: 2),
                  TranscriptButton(
                    handle: transcript,
                    isMine: widget.isMine,
                    onTap: _toggleTranscript,
                  ),
                ] else ...[
                  // The browser keeps the button: transcripts are made on the
                  // device, and the tap says that is why they are in the app.
                  const SizedBox(width: 2),
                  TranscriptButton.appOnly(
                    isMine: widget.isMine,
                    onTap: () => AppOnly.explainTranscripts(context),
                  ),
                ],
              ],
            );
            if (transcript == null) return row;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                row,
                TranscriptSlab(
                  handle: transcript,
                  isMine: widget.isMine,
                  position: display.elapsed,
                  // Mid-play: playing, or paused partway. Not at rest and not
                  // finished, where the whole transcript reads at full ink.
                  following: !completed &&
                      (playing || display.elapsed > Duration.zero),
                  onSeek: (at) {
                    if (!ready) return;
                    _player.seek(at);
                    if (!playing) _player.play();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Opens or folds the transcript. The first open is also what fetches the
  /// speech model and runs it — see [VoiceTranscriber.toggle].
  void _toggleTranscript() {
    final id = widget.storageId;
    if (id == null) return;
    final guess = VoiceLanguageHints.guess(
      roomId: widget.roomId,
      senderId: widget.senderId,
    );
    unawaited(VoiceTranscriber.instance.toggle(
      id,
      languages: [?guess, Localizations.localeOf(context).toLanguageTag()],
      // The same local copy playback uses, so a note already listened to is
      // transcribed without another download.
      () => AudioFileCache.instance.resolve(
        id,
        () => FileUrlCache.instance.resolve(id, () => widget.api.getFileUrl(id)),
      ),
    ));
  }
}

/// A play-once voice message: the same pill as [AudioMessage], with the
/// view-once "1" on its play button — Telegram's treatment.
///
/// Never touches [AudioFileCache] or [FileUrlCache] — the server sends no
/// storage id for an armed message, and a cached copy would outlive the burn.
/// The bytes arrive once, through [onOpen], and play in place from a
/// [ViewOnceMedia] that is released the moment playback ends, the pill goes
/// away, or the app leaves the foreground.
///
/// One look means one listen: there is no scrubber and no replay. A pause is
/// allowed — it is still the same listen — but the note never rewinds.
///
/// All three states (sealed, played, expired) and the playing one share the
/// pill's geometry, so the transcript does not move as one becomes another.
class ViewOnceAudioMessage extends StatefulWidget {
  const ViewOnceAudioMessage({
    super.key,
    required this.messageId,
    required this.isMine,
    required this.durationMs,
    required this.opened,
    required this.burned,
    this.selfChat = false,
    this.surface,
    this.onOpen,
  });

  /// Seeds the waveform's shape, and tells a recycled row it now shows a
  /// different note.
  final String messageId;
  final bool isMine;

  /// Recorded length. Kept on an armed send (unlike a photo's dimensions,
  /// it gives nothing away), so the sealed pill can say how long it is.
  final int? durationMs;

  /// This viewer has had their listen.
  final bool opened;

  /// The server has deleted the audio for everyone.
  final bool burned;

  /// Sent into the sender's own Saved Messages ([ChatMessage.viewOnceSelf]):
  /// the sender's copy is sealed there, and opens once, like a recipient's.
  final bool selfChat;

  /// The bubble's own fill, for the cut-out ring round the "1" badge.
  final Color? surface;

  /// Spends the listen and hands back the bytes. Null leaves the pill inert.
  final ViewOnceOpener? onOpen;

  @override
  State<ViewOnceAudioMessage> createState() => _ViewOnceAudioMessageState();
}

class _ViewOnceAudioMessageState extends State<ViewOnceAudioMessage>
    with WidgetsBindingObserver {
  AudioPlayer? _player;
  ViewOnceMedia? _media;
  StreamSubscription<PlayerState>? _sub;
  Duration? _total;

  /// Between the tap and the first sound: the fetch, the staging, the load.
  bool _busy = false;

  /// This pill played its note through (or was interrupted doing so). The
  /// message flag says the same once the repository has caught up; this covers
  /// the frames in between, and a load that failed after the look was spent.
  bool _done = false;

  /// Holding a [CaptureProtection] scope, exactly while there is something to
  /// hear.
  bool _scoped = false;

  /// Guards a slow fetch landing after a recycled row has moved on.
  int _gen = 0;

  /// The listen has just ended and the pill is turning to dust over its
  /// played self ([DustDissolve]).
  bool _burning = false;

  /// Where the playing pill was when the listen ended, so the picture that
  /// burns is the last one shown. Written by the playing builder, never read
  /// back into it.
  double _lastProgress = 1;
  String? _lastMeta;

  bool get _spent =>
      _done || widget.opened || widget.burned || _sendersCopy;

  /// The sender's own copy, spent from the start — except in Saved Messages.
  bool get _sendersCopy => widget.isMine && !widget.selfChat;

  bool get _openable =>
      widget.onOpen != null && !_busy && _player == null && !_spent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ViewOnceAudioMessage old) {
    super.didUpdateWidget(old);
    // Built with no key, like [AudioMessage], so the ListView can hand this
    // State a different message. The note that was playing is over.
    if (old.messageId == widget.messageId) return;
    _gen++;
    _finish(rebuild: false);
    _busy = false;
    _done = false;
    _burning = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gen++;
    _finish(rebuild: false);
    super.dispose();
  }

  /// The photo viewer's rule: leaving the app ends the look. On iOS both the
  /// screenshot gesture and Control Center (where recording starts) raise
  /// `inactive`, so a note cannot be left playing into a capture.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (_player != null) _finish();
  }

  Future<void> _open() async {
    if (!_openable) return;
    final gen = ++_gen;
    setState(() => _busy = true);
    Uint8List? bytes = await widget.onOpen!();
    if (!mounted || gen != _gen) return;
    if (bytes == null) {
      // The opener has said why. The message flags will redraw the pill.
      setState(() => _busy = false);
      return;
    }
    ViewOnceMedia? media;
    AudioPlayer? player;
    try {
      media = await ViewOnceMedia.stage(
        bytes,
        contentType: voiceNoteContentType,
        extension: 'm4a',
      );
      // Ours was the last reference; the staged copy is the only one now.
      bytes = null;
      player = AudioPlayer();
      final total = media.isFile
          ? await player.setFilePath(media.source)
          : await player.setUrl(media.source);
      if (!mounted ||
          gen != _gen ||
          _backgrounded()) {
        throw StateError('view-once voice: gone before it could play');
      }
      _player = player;
      _media = media;
      _total = total;
      _scoped = true;
      unawaited(CaptureProtection.instance.pushScope());
      unawaited(CaptureProtection.instance.ensureListening());
      _sub = player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) _finish();
      });
      setState(() => _busy = false);
      unawaited(player.play());
    } catch (e) {
      debugPrint('ViewOnceAudioMessage: ${widget.messageId}: $e');
      // Nothing below the hand-over to `_player` can throw, so whatever got
      // this far is still only ours to drop.
      unawaited(player?.dispose());
      unawaited(media?.release());
      // The listen was spent the moment the server handed out the ticket, so
      // there is nothing to retry: the pill goes straight to played.
      if (mounted && gen == _gen) {
        setState(() {
          _busy = false;
          _done = true;
        });
      }
    }
  }

  /// The app left the foreground while the bytes were on their way: the look
  /// ends there, as it would have had it been playing. Unknown (no lifecycle
  /// reported yet) counts as present.
  bool _backgrounded() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state != null && state != AppLifecycleState.resumed;
  }

  /// Ends the listen and lets go of everything it held.
  void _finish({bool rebuild = true}) {
    final hadSession = _player != null;
    final p = _player;
    _player = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (p != null) unawaited(p.dispose());
    final media = _media;
    _media = null;
    if (media != null) unawaited(media.release());
    if (_scoped) {
      _scoped = false;
      unawaited(CaptureProtection.instance.popScope());
    }
    if (!hadSession) return;
    _done = true;
    // Spent on screen: the pill burns. A recycled or disposed one just goes.
    if (rebuild && mounted) setState(() => _burning = true);
  }

  void _togglePause(bool playing) {
    final p = _player;
    if (p == null) return;
    if (playing) {
      unawaited(p.pause());
    } else {
      unawaited(p.play());
    }
  }

  /// The word after the duration. Played and expired are different facts —
  /// "you had it" against "nobody gets it" — the photo tile's distinction.
  String _caption(AppLocalizations l10n) {
    if (widget.burned) {
      return widget.opened || _done || _sendersCopy
          ? l10n.messageBubblePlayOncePlayed
          : l10n.messageBubbleViewOnceExpired;
    }
    if (widget.opened || _done) return l10n.messageBubblePlayOncePlayed;
    if (_sendersCopy) return l10n.messageBubblePlayOnceLabel;
    return l10n.messageBubblePlayOnceTapToPlay;
  }

  TextStyle _metaStyle(AppTheme theme, Color ink) => theme.body.copyWith(
        fontSize: 13,
        height: 1.2,
        color: ink.withValues(alpha: 0.8),
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ink = widget.isMine ? theme.accentInk : theme.ink;
    final onDisc = widget.isMine ? ink : theme.accentInk;
    final p = _player;
    if (p != null) return _playing(theme, ink, onDisc, p);
    if (_burning) {
      return DustDissolve(
        active: true,
        seed: widget.messageId.hashCode,
        sweep: Directionality.of(context) == TextDirection.rtl
            ? const Offset(-1, 0)
            : const Offset(1, 0),
        onDone: () {
          if (mounted) setState(() => _burning = false);
        },
        beneath: _sealedOrSpent(theme, l10n, ink, onDisc),
        child: _ended(theme, ink, onDisc),
      );
    }
    return _sealedOrSpent(theme, l10n, ink, onDisc);
  }

  /// The playing pill's last picture, held still for the burn.
  Widget _ended(AppTheme theme, Color ink, Color onDisc) {
    final total = _total;
    return _row(
      disc: _badged(
        theme,
        _disc(
          theme,
          ink,
          child: Icon(CupertinoIcons.play_fill, color: onDisc, size: 17),
        ),
      ),
      progress: _lastProgress,
      played: ink,
      unplayed: ink.withValues(alpha: 0.32),
      meta: Text(
        _lastMeta ??
            (total == null ? '' : '${formatClockDuration(total)}'
                ' / ${formatClockDuration(total)}'),
        maxLines: 1,
        softWrap: false,
        style: _metaStyle(theme, ink),
      ),
    );
  }

  Widget _sealedOrSpent(
    AppTheme theme,
    AppLocalizations l10n,
    Color ink,
    Color onDisc,
  ) {
    final spent = _spent && !_busy;
    final ms = widget.durationMs;
    final length = ms == null || ms <= 0
        ? null
        : formatClockDuration(Duration(milliseconds: ms));
    final caption = _caption(l10n);
    final Widget disc;
    if (_busy) {
      disc = _badged(
        theme,
        _disc(
          theme,
          ink,
          child: CupertinoActivityIndicator(radius: 7, color: onDisc),
        ),
      );
    } else if (spent) {
      // No fill: a spent pill is a hole where a note was, like the sunken
      // photo tile, and the struck seal says why.
      disc = SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: ViewOnceSeal(
            color: ink.withValues(alpha: 0.55),
            struck: true,
            size: 30,
          ),
        ),
      );
    } else {
      disc = _badged(
        theme,
        _disc(
          theme,
          ink,
          onTap: _openable ? _open : null,
          child: Icon(CupertinoIcons.play_fill, color: onDisc, size: 17),
        ),
      );
    }
    return Semantics(
      label: _openable
          ? l10n.messageBubblePlayOnceVoiceSemanticLabel
          : null,
      child: _row(
        disc: disc,
        progress: 0,
        played: spent ? ink.withValues(alpha: 0.14) : ink,
        unplayed: ink.withValues(alpha: spent ? 0.14 : 0.32),
        meta: Text(
          // Sealed and waiting, the pill reads like any other: just its
          // length, the badge says the rest. Once spent it says why.
          !spent && !_busy && length != null
              ? length
              : (length == null ? caption : '$length · $caption'),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: _metaStyle(theme, spent ? ink.withValues(alpha: 0.7) : ink),
        ),
      ),
    );
  }

  Widget _playing(AppTheme theme, Color ink, Color onDisc, AudioPlayer p) {
    return StreamBuilder<PlayerState>(
      stream: p.playerStateStream,
      builder: (context, snap) {
        return StreamBuilder<Duration?>(
          stream: p.positionStream,
          builder: (context, posSnap) {
            final total = p.duration ?? _total ?? Duration.zero;
            final display = audioDisplayFor(
              rawPlaying: snap.data?.playing ?? false,
              completed: snap.data?.processingState ==
                  ProcessingState.completed,
              position: posSnap.data ?? Duration.zero,
              total: total,
            );
            final meta = '${formatClockDuration(display.elapsed)}'
                ' / ${formatClockDuration(total)}';
            _lastProgress = display.progress;
            _lastMeta = meta;
            return _row(
              disc: _badged(
                theme,
                _disc(
                  theme,
                  ink,
                  onTap: () => _togglePause(display.playing),
                  child: Icon(
                    display.playing
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: onDisc,
                    size: 17,
                  ),
                ),
              ),
              progress: display.progress,
              played: ink,
              unplayed: ink.withValues(alpha: 0.32),
              meta: Text(
                meta,
                maxLines: 1,
                softWrap: false,
                style: _metaStyle(theme, ink),
              ),
            );
          },
        );
      },
    );
  }

  /// The play button with the view-once "1" over its bottom-trailing edge.
  /// Overhangs rather than resizes, so the pill keeps [AudioMessage]'s exact
  /// width.
  Widget _badged(AppTheme theme, Widget disc) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        disc,
        PositionedDirectional(
          end: -4,
          bottom: -4,
          child: ViewOnceCornerBadge(
            color: theme.accent,
            knockout: theme.accentInk,
            ring: widget.surface ?? theme.surface,
            size: 17,
          ),
        ),
      ],
    );
  }

  /// [AudioMessage]'s exact geometry: a 34pt disc, then a 120pt column of a
  /// 20pt waveform over one 13pt line.
  Widget _row({
    required Widget disc,
    required double progress,
    required Color played,
    required Color unplayed,
    required Widget meta,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        disc,
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    seed: widget.messageId.hashCode,
                    progress: progress,
                    played: played,
                    unplayed: unplayed,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              meta,
            ],
          ),
        ),
      ],
    );
  }

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
    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.circle,
      focusRadius: 17,
      child: disc,
    );
  }
}

/// How many bars every voice bubble's waveform has.
const int kVoiceWaveformBars = 30;

/// A voice bubble's bar heights for [seed], 0..1: what [VoiceWaveform] draws,
/// for a sent note's flight to land its bars on (see `send_flight.dart`).
List<double> voiceWaveformHeights(int seed) => _WaveformPainter.heightsFor(seed);

/// The waveform of a voice bubble, for one that is not an [AudioMessage]
/// yet (still uploading), so it already has the finished bubble's anatomy.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.seed,
    required this.played,
    required this.unplayed,
    this.progress = 0,
  });

  final int seed;
  final double progress;
  final Color played;
  final Color unplayed;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _WaveformPainter(seed: seed, progress: progress, played: played, unplayed: unplayed),
      );
}

/// The bars of a voice note. Heights come from a seeded generator — a real
/// amplitude envelope would need the audio decoded before it is played — so
/// the shape is stable per recording and reads as speech: mostly mid-height
/// with the occasional peak, tapering at both ends.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.played,
    required this.unplayed,
  });

  final int seed;
  final double progress;
  final Color played;
  final Color unplayed;

  static const _bars = kVoiceWaveformBars;
  static final _cache = <int, List<double>>{};

  List<double> _heights() => heightsFor(seed);

  static List<double> heightsFor(int seed) => _cache.putIfAbsent(seed, () {
        final r = math.Random(seed);
        return [
          for (var i = 0; i < _bars; i++)
            () {
              final edge = math.sin(math.pi * (i + 0.5) / _bars);
              final base = 0.25 + r.nextDouble() * 0.55;
              final peak = r.nextDouble() < 0.18 ? 0.25 : 0.0;
              return ((base + peak) * (0.55 + 0.45 * edge)).clamp(0.15, 1.0);
            }(),
        ];
      });

  @override
  void paint(Canvas canvas, Size size) {
    final h = _heights();
    final step = size.width / _bars;
    final barW = math.max(1.5, step * 0.55);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < _bars; i++) {
      final x = step * i + step / 2;
      final bh = math.max(barW, h[i] * size.height);
      paint
        ..color = (i + 0.5) / _bars <= progress ? played : unplayed
        ..strokeWidth = barW;
      canvas.drawLine(
        Offset(x, size.height / 2 - bh / 2 + barW / 2),
        Offset(x, size.height / 2 + bh / 2 - barW / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.played != played ||
      old.unplayed != unplayed;
}
