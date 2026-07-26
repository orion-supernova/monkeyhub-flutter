import 'package:flutter/foundation.dart';

import '../media/upload_service.dart';

/// The bytes of an outgoing attachment, held only while it is on its way up.
///
/// Attached to the optimistic [ChatMessage] so the sender's own bubble can paint
/// the picture they just chose, immediately, from memory. Before this the bubble
/// was only built once the upload had finished and a storage id existed — so the
/// sender watched an unchanged transcript for the length of the upload and then
/// had their photo fetched back down from the server, over the network, having
/// just sent it up.
///
/// Deliberately not serialized. [ChatMessage.toJson] enumerates its keys, so this
/// field is invisible to it by construction; and the disk cache is only ever
/// handed server-parsed messages, never the pending list, so there is no path
/// from here to `SharedPreferences` even if someone adds the key by mistake.
class PendingUpload {
  PendingUpload({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  /// 0..1 where the transport can honestly measure it, null where it cannot —
  /// see [UploadService] for why the browser can only ever be indeterminate.
  ///
  /// A [ValueNotifier] rather than a field on the message: progress ticks about
  /// ten times a second, and routing that through the repository's
  /// `notifyListeners` would rebuild the entire transcript — every bubble, every
  /// avatar, every date divider — to move an arc three pixels. The tile listens
  /// to this directly and repaints alone.
  final ValueNotifier<double?> progress = ValueNotifier(null);

  /// Cancel handle for the request in flight, so leaving the upload behind can
  /// actually stop it rather than just stop caring about it.
  UploadTask? task;

  /// True once [dispose] has run. Guards the late arrival of a progress callback
  /// from a request that was cancelled — writing to a disposed notifier throws.
  bool get disposed => _disposed;
  bool _disposed = false;

  void report(double value) {
    if (_disposed) return;
    progress.value = value;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    task?.cancel();
    progress.dispose();
  }
}
