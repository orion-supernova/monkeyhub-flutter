// Linux secure-storage indirection.
//
// The Linux build keeps its secrets in a private file instead of the keyring
// (see linux_secure_storage_io.dart for why). That needs dart:io, which web
// can't import, so web gets a no-op stub. Same conditional-export pattern as
// update/linux_self_update.dart.
export 'linux_secure_storage_io.dart'
    if (dart.library.html) 'linux_secure_storage_web.dart';
