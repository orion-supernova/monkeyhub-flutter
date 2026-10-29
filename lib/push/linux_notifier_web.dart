/// Web stub. A browser tab's banners belong to Web Push and `WebNotifier`;
/// this only exists so the conditional export in `linux_notifier.dart`
/// resolves.
class LinuxNotifier {
  LinuxNotifier._();
  static final LinuxNotifier instance = LinuxNotifier._();

  static bool get supported => false;

  void setOnOpenRoom(void Function(String roomId) cb) {}

  Future<void> show({
    required String roomId,
    required String title,
    required String body,
    bool quiet = false,
  }) async {}

  Future<void> dismissRoom(String roomId) async {}

  void setTrayLabels({required String open, required String quit}) {}
}
