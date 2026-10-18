/// Web stub. A browser tab updates by reloading (`web_reload.dart`); this only
/// exists so the conditional export in `linux_self_update.dart` resolves.
class LinuxSelfUpdate {
  const LinuxSelfUpdate._();

  static bool get supported => false;

  static Future<bool> run({void Function(double progress)? onProgress}) async =>
      false;

  static void sweep() {}
}
