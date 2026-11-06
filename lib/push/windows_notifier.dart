// Windows toast indirection.
//
// The Windows build raises toasts through an FFI plugin, which needs dart:io
// and dart:ffi; web gets a no-op stub. Same conditional-export pattern as
// linux_notifier.dart.
export 'windows_notifier_io.dart' if (dart.library.html) 'windows_notifier_web.dart';
