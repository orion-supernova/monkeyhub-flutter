// Linux in-place update indirection.
//
// The tarball build updates itself: download, verify, swap the install folder,
// relaunch. That needs dart:io, which web can't import, so this resolves to the
// real implementation off-web and a stub on web. Same conditional-export
// pattern as web_reload.dart.
export 'linux_self_update_io.dart'
    if (dart.library.html) 'linux_self_update_web.dart';
