// Web stub: a browser tab's banners belong to Web Push and `WebNotifier`; this
// only exists so the conditional export in `windows_notifier.dart` resolves.
import 'banner_composer.dart';

class WindowsNotifier implements DesktopBannerSink {
  WindowsNotifier._();
  static final WindowsNotifier instance = WindowsNotifier._();

  static bool get supported => false;

  @override
  bool get isSupported => false;

  @override
  void setOnOpenRoom(void Function(String roomId) cb) {}

  @override
  void setOnDismissed(void Function(String roomId) cb) {}

  @override
  Future<void> show({
    required String roomId,
    required String title,
    required String body,
    String? avatarUrl,
    bool quiet = false,
  }) async {}

  @override
  Future<void> dismissRoom(String roomId) async {}
}
