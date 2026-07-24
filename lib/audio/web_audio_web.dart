import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web alert sounds via `<audio>` elements fed from in-memory blobs.
///
/// Uses HTMLAudioElement instead of just_audio because an <audio> element keeps
/// playing when the tab is backgrounded, whereas just_audio's Web Audio backend
/// is suspended by the browser while hidden — which made the message ping and
/// the incoming-call ringtone silent in the background.
///
/// The audio bytes are loaded by [AlertSounds] via Flutter's asset bundle and
/// handed here as raw bytes, which we wrap in a Blob + object URL. That avoids
/// guessing Flutter-web's asset URL layout (which varies with base href), so
/// the source is always correct.
///
/// Browser autoplay: playback from a hidden tab is only allowed once the page
/// has been unlocked by a user gesture — [unlock] primes the elements muted
/// within the first gesture (wired from app.dart).
class WebAudio {
  const WebAudio._();

  static web.HTMLAudioElement? _ping;
  static web.HTMLAudioElement? _ring;
  static bool _unlocked = false;

  static web.HTMLAudioElement _element(Uint8List bytes, {bool loop = false}) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/mpeg'),
    );
    final url = web.URL.createObjectURL(blob);
    return web.HTMLAudioElement()
      ..src = url
      ..loop = loop
      ..preload = 'auto';
  }

  static void configurePing(Uint8List bytes) => _ping ??= _element(bytes);
  static void configureRingtone(Uint8List bytes) =>
      _ring ??= _element(bytes, loop: true);

  static void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    for (final e in [_ping, _ring]) {
      if (e == null) continue;
      try {
        // Pause only AFTER the muted play resolves — a synchronous pause aborts
        // the play promise ("AbortError") and can leave the element not fully
        // activated for later background playback.
        e.muted = true;
        e.play().toDart.then((_) {
          e.pause();
          e.currentTime = 0;
          e.muted = false;
        }).catchError((_) {
          e.muted = false;
        });
      } catch (_) {}
    }
  }

  static void playPing() {
    final e = _ping;
    if (e == null) return;
    try {
      e.currentTime = 0;
      e.play();
    } catch (_) {}
  }

  static void startRingtone() {
    final e = _ring;
    if (e == null) return;
    try {
      e.currentTime = 0;
      e.play();
    } catch (_) {}
  }

  static void stopRingtone() {
    final e = _ring;
    if (e == null) return;
    try {
      e.pause();
      e.currentTime = 0;
    } catch (_) {}
  }
}
