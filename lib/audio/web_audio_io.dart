import 'dart:typed_data';

/// Non-web no-op. Native and desktop play alert sounds via just_audio; this
/// stub exists only so the conditional export in `web_audio.dart` resolves
/// off-web.
class WebAudio {
  const WebAudio._();

  static void configurePing(Uint8List bytes) {}
  static void configureRingtone(Uint8List bytes) {}
  static void unlock() {}
  static void playPing() {}
  static void startRingtone() {}
  static void stopRingtone() {}
}
