// Linux desktop-notification indirection.
//
// The Linux build talks to the notification daemon over D-Bus, which needs
// dart:io; web gets a no-op stub. Same conditional-export pattern as
// web_notifier.dart, in the other direction.
export 'linux_notifier_io.dart' if (dart.library.html) 'linux_notifier_web.dart';
