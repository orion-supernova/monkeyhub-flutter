import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The platform's "lift subject from background" — Apple's Vision foreground
/// mask on iOS 17+ and macOS 14+ (see `SubjectCutout.swift`). Everywhere else
/// [isSupported] is false and the sticker maker offers a shaped crop instead.
class SubjectCutout {
  SubjectCutout._();

  static const _channel = MethodChannel('monkeyhub/cutout');

  static bool get _applePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool? _supported;

  static Future<bool> isSupported() async {
    if (!_applePlatform) return false;
    final known = _supported;
    if (known != null) return known;
    try {
      return _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return _supported = false;
    }
  }

  /// A PNG of [image]'s subject on transparency, cropped to it — or null when
  /// there is no subject to find, or no cut-out on this system.
  static Future<Uint8List?> cutout(Uint8List image) async {
    if (!await isSupported()) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('cutout', {'bytes': image});
    } catch (e) {
      debugPrint('[cutout] $e');
      return null;
    }
  }
}
