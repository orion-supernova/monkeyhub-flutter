// Web stub. A browser tab's banners belong to Web Push and `WebNotifier`;
// this only exists so the conditional export in `linux_notifier.dart`
// resolves.
import 'banner_composer.dart';

class LinuxNotifier implements DesktopBannerSink {
  LinuxNotifier._();
  static final LinuxNotifier instance = LinuxNotifier._();

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

  void setTrayLabels({required String open, required String quit}) {}
}
