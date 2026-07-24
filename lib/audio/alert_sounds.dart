import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';

import 'web_audio.dart';

/// Cross-platform alert sounds: a looping incoming-call ringtone and a one-shot
/// new-message ping.
///
/// Why this exists: on native mobile the OS rings incoming calls (CallKit /
/// ConnectionService) and plays the system notification sound for push banners.
/// Web and desktop have neither, so their in-app UI was completely silent.
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

  static const _ringtoneAsset = 'assets/audio/ringtone.mp3';
  static const _pingAsset = 'assets/audio/ping.mp3';

  final AudioPlayer _ringtone = AudioPlayer();
  final AudioPlayer _ping = AudioPlayer();

  bool _ringtoneLoaded = false;
  bool _pingLoaded = false;
  bool _unlocked = false;
  bool _webConfigured = false;

  /// Web only: load the asset bytes once and hand them to [WebAudio] as blobs.
  /// Loading (not playback) needs no user gesture, so this can run early.
  Future<void> _ensureWebConfigured() async {
    if (_webConfigured) return;
    _webConfigured = true;
    try {
      final ping = await rootBundle.load(_pingAsset);
      WebAudio.configurePing(ping.buffer.asUint8List());
    } catch (e) {
      debugPrint('AlertSounds: web ping load failed: $e');
    }
    try {
      final ring = await rootBundle.load(_ringtoneAsset);
      WebAudio.configureRingtone(ring.buffer.asUint8List());
    } catch (e) {
      debugPrint('AlertSounds: web ringtone load failed: $e');
    }
  }

  /// Prime both players against a user gesture so later autoplay (a ringtone
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
    await _ensureRingtoneLoaded();
    await _ensurePingLoaded();
    // A muted, immediately-paused touch is enough to satisfy the gesture
    // requirement without producing audible output.
    try {
      final wasVolume = _ping.volume;
      await _ping.setVolume(0);
      await _ping.play();
      await _ping.pause();
      await _ping.seek(Duration.zero);
      await _ping.setVolume(wasVolume);
    } catch (e) {
      debugPrint('AlertSounds.unlock: $e');
    }
  }

  Future<void> _ensureRingtoneLoaded() async {
    if (_ringtoneLoaded) return;
    try {
      await _ringtone.setAsset(_ringtoneAsset);
      await _ringtone.setLoopMode(LoopMode.one);
      _ringtoneLoaded = true;
    } catch (e) {
      debugPrint('AlertSounds: ringtone load failed: $e');
    }
  }

  Future<void> _ensurePingLoaded() async {
    if (_pingLoaded) return;
    try {
      await _ping.setAsset(_pingAsset);
      _pingLoaded = true;
    } catch (e) {
      debugPrint('AlertSounds: ping load failed: $e');
    }
  }

  /// Start the looping ringtone. Safe to call repeatedly — restarts from the
  /// top if already playing.
  Future<void> startRingtone() async {
    if (kIsWeb) {
      await _ensureWebConfigured();
      WebAudio.startRingtone();
      return;
    }
    await _ensureRingtoneLoaded();
    if (!_ringtoneLoaded) return;
    try {
      await _ringtone.seek(Duration.zero);
      await _ringtone.play();
    } catch (e) {
      debugPrint('AlertSounds.startRingtone: $e');
    }
  }

  /// Stop the ringtone and rewind. Safe to call when not playing.
  Future<void> stopRingtone() async {
    if (kIsWeb) {
      WebAudio.stopRingtone();
      return;
    }
    if (!_ringtoneLoaded) return;
    try {
      await _ringtone.pause();
      await _ringtone.seek(Duration.zero);
    } catch (e) {
      debugPrint('AlertSounds.stopRingtone: $e');
    }
  }

  /// Play the new-message ping once. Restarts from the top so back-to-back
  /// messages each produce an audible tick.
  Future<void> playPing() async {
    if (kIsWeb) {
      await _ensureWebConfigured();
      WebAudio.playPing();
      return;
    }
    await _ensurePingLoaded();
    if (!_pingLoaded) return;
    try {
      await _ping.seek(Duration.zero);
      await _ping.play();
    } catch (e) {
      debugPrint('AlertSounds.playPing: $e');
    }
  }
}
