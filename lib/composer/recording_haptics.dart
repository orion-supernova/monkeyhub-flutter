import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import '../ui/foundation/caps.dart';
import '../ui/foundation/channels.dart';

/// iOS mutes the Taptic Engine while the microphone is recording unless the
/// audio session opts in. Without this every haptic of a voice or video note
/// (lock, slide-to-cancel armed, send) is silent on an iPhone.
///
/// The app opts in at launch (`AppDelegate.swift`); call this again once a
/// recorder has started, because the record and camera plugins reconfigure
/// the shared session when they start. Fire-and-forget, a no-op elsewhere.
Future<void> allowHapticsWhileRecording() async {
  if (!Caps.iOS) return;
  try {
    await Channels.haptics.invokeMethod<void>('allowDuringRecording');
  } catch (e) {
    debugPrint('allowHapticsWhileRecording: $e');
  }
}

/// Holds the screen at full brightness while the front camera's white-screen
/// flash is on, and hands the user's brightness back when it goes off. Only
/// this app's window on Android; iOS restores the remembered level. A no-op
/// off mobile.
Future<void> setFlashBrightness(bool on) async {
  if (!Caps.nativeMobile) return;
  try {
    await const MethodChannel('monkeyhub/screen').invokeMethod<void>('setFlashBrightness', {'on': on});
  } catch (e) {
    debugPrint('setFlashBrightness: $e');
  }
}
