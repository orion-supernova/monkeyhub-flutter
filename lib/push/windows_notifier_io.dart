import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications_windows/flutter_local_notifications_windows.dart';

import 'banner_avatar_files_io.dart';
import 'banner_composer.dart';

/// Toast banners for the Windows build.
///
/// Windows has no push service the app can use, so like Linux a message only
/// reaches this build over the Convex socket the running app holds, and the
/// banner is drawn here. One toast per room: a room's next message re-shows
/// under the same tag, which Windows treats as a replacement rather than a
/// second entry in the Action Center.
///
/// Only `flutter_local_notifications_windows` is used, never the umbrella
/// `flutter_local_notifications`: its iOS/Android/macOS halves would take over
/// the app's own native notification code (see the pubspec note about having
/// no notification SDK). This package is plain FFI into WinRT and does nothing
/// on the other platforms.
class WindowsNotifier implements DesktopBannerSink {
  WindowsNotifier._();
  static final WindowsNotifier instance = WindowsNotifier._();

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Same identity the Store package declares (`msix_config.identity_name` in
  /// pubspec.yaml), so a packaged build's toasts belong to the installed app
  /// and honour its Settings > Notifications entry. The GUID is the COM
  /// activator class the plugin registers so a click can start the app; it is
  /// ours alone and must not change between releases.
  static const _aumid = 'WalhallaApps.MonkeyHubYourInnerCircle';
  static const _guid = '7c1f4b52-3e0a-4d7e-9a1b-5d2f6c8e0b43';

  // Lazy: constructing it opens the native DLL, which only exists on Windows.
  late final FlutterLocalNotificationsWindows _plugin =
      FlutterLocalNotificationsWindows();

  Future<bool>? _ready;

  /// Windows tags are strings but the plugin takes an int per notification;
  /// a stable int per room keeps "same room" meaning "replace".
  final Map<String, int> _idByRoom = {};
  int _nextId = 1;

  /// Set once, by the first failure, like the Linux notifier: an unpackaged
  /// dev build or a Windows without toast support will not grow it mid-run.
  bool _broken = false;

  void Function(String roomId)? _onOpenRoom;

  @override
  bool get isSupported => supported;

  @override
  void setOnOpenRoom(void Function(String roomId) cb) => _onOpenRoom = cb;

  /// Windows reports clicks, not dismissals, to a running app.
  @override
  void setOnDismissed(void Function(String roomId) cb) {}

  Future<bool> _init() => _ready ??= _plugin.initialize(
        settings: const WindowsInitializationSettings(
          appName: 'MonkeyHub',
          appUserModelId: _aumid,
          guid: _guid,
        ),
        onDidReceiveNotificationResponse: (response) {
          final room = response.payload;
          if (room != null && room.isNotEmpty) _onOpenRoom?.call(room);
        },
      );

  /// Shows (or replaces) [roomId]'s toast. A quiet update is silent; the
  /// avatar is cropped to a circle in the app-logo slot, like a contact photo.
  @override
  Future<void> show({
    required String roomId,
    required String title,
    required String body,
    String? avatarUrl,
    bool quiet = false,
  }) async {
    if (!supported || _broken) return;
    try {
      if (!await _init()) throw StateError('toast init failed');
      final image = avatarUrl == null
          ? null
          : BannerAvatarFiles.instance.peek(avatarUrl) ??
              await BannerAvatarFiles.instance.fetch(avatarUrl);
      final id = _idByRoom.putIfAbsent(roomId, () => _nextId++);
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: roomId,
        notificationDetails: WindowsNotificationDetails(
          audio: quiet ? WindowsNotificationAudio.silent() : null,
          images: [
            if (image != null)
              WindowsImage(
                Uri.file(image, windows: true),
                altText: title,
                placement: WindowsImagePlacement.appLogoOverride,
                crop: WindowsImageCrop.circle,
              ),
          ],
        ),
      );
    } catch (e) {
      _broken = true;
      debugPrint('WindowsNotifier: toasts unavailable ($e)');
    }
  }

  /// Takes [roomId]'s toast down — the room was opened here. The plugin can
  /// only remove toasts for a packaged (MSIX) app; an unpackaged build leaves
  /// it in the Action Center, which is harmless.
  @override
  Future<void> dismissRoom(String roomId) async {
    final id = _idByRoom[roomId];
    if (id == null || _broken || _ready == null) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {/* already gone */}
  }
}
