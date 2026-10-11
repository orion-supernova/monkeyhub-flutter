import 'package:audio_session/audio_session.dart'
    show AndroidAudioAttributes, AndroidAudioContentType, AndroidAudioUsage;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';

import 'alert_sound.dart';
import 'web_audio.dart';

export 'alert_sound.dart';

/// Cross-platform alert sounds: the incoming-call ringtone, the new-message
/// ping, and the caller's two tones, the ringback and the "answered" chime.
///
/// Why this exists: on native mobile the OS rings incoming calls (CallKit /
/// ConnectionService) and plays the system notification sound for push banners.
/// Web and desktop have neither, so their in-app UI was completely silent. And
/// no platform gives the CALLER anything to hear while the other phone rings,
/// so the caller's tones play everywhere.
///
/// Native/desktop play via [just_audio]. WEB routes through [WebAudio] (a raw
/// <audio> element) instead — just_audio's Web Audio backend is SUSPENDED while
/// the tab is hidden, so a background ping/ringtone was silent; an <audio>
/// element keeps playing in a backgrounded tab.
///
/// Browser autoplay policy: audio can't start until the page has seen a user
/// gesture. An incoming call arrives with no gesture at that instant, so call
/// [unlock] once from the first pointer/key event after load (see the wiring in
/// `app.dart`) to prime the players while a gesture is in scope.
class AlertSounds {
  AlertSounds._();
  static final AlertSounds instance = AlertSounds._();

  /// One player per sound, made on first use: a voice-only user never pays
  /// for a ringback player, and a message ping never waits on the ringtone.
  final Map<AlertSound, AudioPlayer> _players = {};

  /// The load in flight or done, per sound, so two callers racing a first
  /// play share one `setAsset` instead of loading twice. Completes with
  /// whether the sound is playable.
  final Map<AlertSound, Future<bool>> _loads = {};
  /// Bumped by every [play] and [stop] of a sound. A play that had to wait
  /// for its load only starts if nothing came after it: a ringback stopped
  /// by an answer that beat the asset decode must stay stopped.
  final Map<AlertSound, int> _epoch = {};
  bool _unlocked = false;
  Future<void>? _webConfigured;

  /// Web only: load the asset bytes once and hand them to [WebAudio] as blobs.
  /// Loading (not playback) needs no user gesture, so this can run early.
  Future<void> _ensureWebConfigured() => _webConfigured ??= () async {
        for (final sound in AlertSound.values) {
          try {
            final bytes = await rootBundle.load(sound.asset);
            WebAudio.configure(sound, bytes.buffer.asUint8List());
          } catch (e) {
            debugPrint('AlertSounds: web ${sound.name} load failed: $e');
          }
        }
      }();

  Future<bool> _ensureLoaded(AlertSound sound) => _loads[sound] ??= () async {
        final player = _players[sound] ??= sound.inCall
            // The caller's tones sound while the call holds the audio
            // session. Left to just_audio, every play would activate the
            // session as MUSIC (iOS: `.playback`, configured on the spot when
            // nothing configured it yet, over the call's `.playAndRecord`;
            // Android: a media focus grab on the media stream). They play in
            // the call's session instead, and on Android as call signalling:
            // the voice-call stream, routed with the call to the earpiece or
            // the speaker, and not muted by the ringer's silent mode.
            // Interruptions too belong to the call, not to the player: the
            // CallKit plugin posts its own "interruption ended" on every
            // activation, and a real one pauses the call itself. The call
            // state starts and stops these tones.
            ? AudioPlayer(
                handleAudioSessionActivation: false,
                androidApplyAudioAttributes: false,
                handleInterruptions: false,
              )
            : AudioPlayer();
        try {
          if (sound.inCall) {
            await player.setAndroidAudioAttributes(const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.sonification,
              usage: AndroidAudioUsage.voiceCommunicationSignalling,
            ));
          }
          await player.setAsset(sound.asset);
          if (sound.loop) await player.setLoopMode(LoopMode.one);
          return true;
        } catch (e) {
          debugPrint('AlertSounds: ${sound.name} load failed: $e');
          // Let a later play try again rather than stay silent for good.
          _loads.remove(sound);
          return false;
        }
      }();

  /// Load [sounds] ahead of their first play, so that play starts on the
  /// beat instead of after an asset decode. Fire-and-forget safe.
  Future<void> prepare(Iterable<AlertSound> sounds) async {
    if (kIsWeb) return _ensureWebConfigured();
    await Future.wait(sounds.map(_ensureLoaded));
  }

  /// Prime the players against a user gesture so later autoplay (a ringtone
  /// for an incoming call) is permitted by the browser. Idempotent; a no-op on
  /// platforms without autoplay restrictions, but harmless there.
  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    if (kIsWeb) {
      await _ensureWebConfigured();
      WebAudio.unlock();
      return;
    }
    await _ensureLoaded(AlertSound.ringtone);
    if (!await _ensureLoaded(AlertSound.ping)) return;
    // A muted, immediately-paused touch is enough to satisfy the gesture
    // requirement without producing audible output.
    final ping = _players[AlertSound.ping]!;
    try {
      final wasVolume = ping.volume;
      await ping.setVolume(0);
      await ping.play();
      await ping.pause();
      await ping.seek(Duration.zero);
      await ping.setVolume(wasVolume);
    } catch (e) {
      debugPrint('AlertSounds.unlock: $e');
    }
  }

  /// Play [sound] from the top: a loop opens on its first beat, and
  /// back-to-back one-shots (two messages) each sound. Safe to call
  /// repeatedly.
  Future<void> play(AlertSound sound) async {
    final epoch = _epoch[sound] = (_epoch[sound] ?? 0) + 1;
    if (kIsWeb) {
      await _ensureWebConfigured();
      if (_epoch[sound] != epoch) return;
      WebAudio.play(sound);
      return;
    }
    if (!await _ensureLoaded(sound)) return;
    if (_epoch[sound] != epoch) return;
    final player = _players[sound]!;
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      debugPrint('AlertSounds.play(${sound.name}): $e');
    }
  }

  /// Stop [sound] and rewind. Safe to call when it is not playing, or was
  /// never loaded.
  Future<void> stop(AlertSound sound) async {
    _epoch[sound] = (_epoch[sound] ?? 0) + 1;
    if (kIsWeb) {
      WebAudio.stop(sound);
      return;
    }
    final player = _players[sound];
    if (player == null || _loads[sound] == null) return;
    try {
      await player.pause();
      await player.seek(Duration.zero);
    } catch (e) {
      debugPrint('AlertSounds.stop(${sound.name}): $e');
    }
  }

  Future<void> startRingtone() => play(AlertSound.ringtone);
  Future<void> stopRingtone() => stop(AlertSound.ringtone);
  Future<void> playPing() => play(AlertSound.ping);
}
