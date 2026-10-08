import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'alert_sound.dart';

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

  static final Map<AlertSound, web.HTMLAudioElement> _elements = {};
  static bool _unlocked = false;

  static void configure(AlertSound sound, Uint8List bytes) {
    if (_elements.containsKey(sound)) return;
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: sound.mime),
    );
    final url = web.URL.createObjectURL(blob);
    _elements[sound] = web.HTMLAudioElement()
      ..src = url
      ..loop = sound.loop
      ..preload = 'auto';
  }

  static void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    for (final e in _elements.values) {
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

  /// From the top, so back-to-back one-shots each sound and a loop always
  /// opens on its first beat.
  static void play(AlertSound sound) {
    final e = _elements[sound];
    if (e == null) return;
    try {
      e.currentTime = 0;
      e.play();
    } catch (_) {}
  }

  static void stop(AlertSound sound) {
    final e = _elements[sound];
    if (e == null) return;
    try {
      e.pause();
      e.currentTime = 0;
    } catch (_) {}
  }
}
