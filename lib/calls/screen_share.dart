import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../privacy/capture_protection.dart';

/// Which of this device's screen is on offer.
///
/// Mobile shares the whole display; the desktop share sheet lets the user
/// pick a display or a window from what [ScreenShare.sources] lists.
class ScreenShareSource {
  const ScreenShareSource({
    required this.id,
    required this.name,
    required this.isWindow,
    this.thumbnail,
  });

  final String id;
  final String name;
  final bool isWindow;

  /// PNG bytes from the platform's own thumbnailer, when it gave one.
  final Uint8List? thumbnail;
}

/// The platform side of sharing a screen, gathered in one place so the two
/// call services can say `prepare → capture → release` and nothing more.
///
/// Every platform captures differently and two of them need something set
/// up first:
///
///  * **iOS** captures through a Broadcast Upload Extension — the only way
///    to see past the app's own window. flutter_webrtc's capturer reads the
///    extension's id and the shared app group out of `Info.plist`
///    (`RTCScreenSharingExtension`, `RTCAppGroupIdentifier`) and presents
///    the system picker itself; the extension streams frames back over a
///    unix socket in the app-group container. If the extension is not in
///    the bundle the picker shows nothing, so [supported] asks the native
///    side whether the plist names one and the buttons simply do not appear
///    without it.
///  * **Android 14** refuses `createVirtualDisplay` unless a foreground
///    service typed `mediaProjection` is already running — and the consent
///    dialog must have been answered before that service starts, or the
///    service start itself is rejected as untyped. The plugin does neither:
///    its `getDisplayMedia` only raises the consent intent. So [prepare]
///    asks for consent first (the plugin caches the grant), then starts our
///    own [ScreenShareService], and only then does [capture] run.
///  * **Android, any version** blanks the outgoing picture while capture
///    protection (`FLAG_SECURE`) is on — the flag does exactly what it says,
///    to us as much as to anyone. Sharing a screen is a deliberate
///    broadcast of it, so protection is suspended for the share's duration
///    and restored the moment it ends. See [CaptureProtection.suspend].
///  * **macOS** enumerates displays and windows through ScreenCaptureKit;
///    the user picks one. Nothing to prepare beyond the usage string.
class ScreenShare {
  ScreenShare._();

  static const MethodChannel _channel = MethodChannel('monkeyhub/screen_share');

  /// Seam for tests: the capture behind [capture].
  @visibleForTesting
  static Future<MediaStream> Function(Map<String, dynamic> constraints)
      getDisplayMediaFn = (c) => navigator.mediaDevices.getDisplayMedia(c);

  /// Seam for tests: the native calls [prepare]/[release] make.
  @visibleForTesting
  static Future<dynamic> Function(String method, [Map<String, dynamic>? args])
      invokeFn = (m, [a]) => _channel.invokeMethod(m, a);

  /// Called when the platform ended the share from outside the app — the
  /// STOP action on Android's notification. The service that started the
  /// share sets this while it runs.
  static void Function()? onPlatformStop;

  static bool _handlerInstalled = false;
  static bool? _iosSupported;

  /// Whether this device can share at all. Cheap after the first call.
  static Future<bool> supported() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid || Platform.isMacOS || Platform.isWindows) {
      return true;
    }
    if (Platform.isIOS) {
      final known = _iosSupported;
      if (known != null) return known;
      try {
        final r = await invokeFn('isSupported');
        return _iosSupported = r == true;
      } catch (_) {
        return _iosSupported = false;
      }
    }
    return false;
  }

  /// Desktop only: what can be shared. Empty elsewhere.
  static Future<List<ScreenShareSource>> sources() async {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return const [];
    }
    try {
      final list = await desktopCapturer.getSources(
        types: [SourceType.Screen, SourceType.Window],
        thumbnailSize: ThumbnailSize(320, 200),
      );
      return [
        for (final s in list)
          ScreenShareSource(
            id: s.id,
            name: s.name,
            isWindow: s.type == SourceType.Window,
            thumbnail: s.thumbnail,
          ),
      ];
    } catch (e) {
      debugPrint('ScreenShare.sources failed: $e');
      return const [];
    }
  }

  /// Everything that has to happen before the capture may start. Idempotent
  /// enough to survive a failed capture followed by a retry.
  static Future<void> prepare({
    required String notificationTitle,
    required String notificationBody,
    required String notificationStop,
  }) async {
    _installHandler();
    if (!kIsWeb && Platform.isAndroid) {
      // Consent first — the plugin keeps the granted intent and reuses it
      // inside getDisplayMedia — then the typed service, in that order.
      final granted = await Helper.requestCapturePermission();
      if (!granted) throw const ScreenShareDeniedException();
      await invokeFn('start', {
        'title': notificationTitle,
        'body': notificationBody,
        'stop': notificationStop,
      });
    }
    CaptureProtection.instance.suspend();
  }

  /// The capture itself. [source] is the desktop pick; ignored on mobile.
  static Future<MediaStream> capture({ScreenShareSource? source}) async {
    final Map<String, dynamic> constraints;
    if (!kIsWeb && Platform.isIOS) {
      constraints = {
        'video': {'deviceId': 'broadcast'},
        'audio': false,
      };
    } else if (source != null) {
      constraints = {
        'video': {
          'deviceId': {'exact': source.id},
          'mandatory': {'frameRate': 15.0},
        },
        'audio': false,
      };
    } else {
      constraints = {'video': true, 'audio': false};
    }
    return getDisplayMediaFn(constraints);
  }

  /// Undo [prepare]. Safe to call more than once and without a prepare.
  static Future<void> release() async {
    CaptureProtection.instance.resume();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await invokeFn('stop');
      } catch (e) {
        debugPrint('ScreenShare.release: $e');
      }
    }
  }

  static void _installHandler() {
    if (_handlerInstalled || kIsWeb) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUserStop') onPlatformStop?.call();
      return null;
    });
  }
}

/// The user declined the system's capture consent.
class ScreenShareDeniedException implements Exception {
  const ScreenShareDeniedException();
  @override
  String toString() => 'ScreenShareDeniedException';
}
