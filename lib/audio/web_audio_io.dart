import 'dart:typed_data';

import 'alert_sound.dart';

/// Non-web no-op. Native and desktop play alert sounds via just_audio; this
/// stub exists only so the conditional export in `web_audio.dart` resolves
/// off-web.
class WebAudio {
  const WebAudio._();

  static void configure(AlertSound sound, Uint8List bytes) {}
  static void unlock() {}
  static void play(AlertSound sound) {}
  static void stop(AlertSound sound) {}
}
