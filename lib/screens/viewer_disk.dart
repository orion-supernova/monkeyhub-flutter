/// Save and Copy for the media viewers on a desk.
///
/// A phone saves a photograph into its photo library and copies nothing; a
/// desk saves to Downloads and copies the picture itself, so it can be pasted
/// into a document, a mail or another chat. Both start from the bytes this
/// device already has: the full-resolution file the image cache keeps on disk
/// (see `RemoteImage`), or the video the player already downloaded. The
/// network is the last resort, not the first move, which is what the
/// share/save helpers in `room_content_actions.dart` do.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../backend/chat_api.dart';
import '../media/file_meta.dart';
import '../media/file_url_cache.dart';
import '../media/image_raster.dart' show imageBytesSize;
import '../models/chat_message.dart';
import '../models/enums.dart';
import 'viewer_disk_io.dart' if (dart.library.html) 'viewer_disk_web.dart'
    as platform;

/// Where a save landed. [path] is null on the web, where the browser owns
/// the download and says so itself.
class ViewerSaved {
  const ViewerSaved({this.path});
  final String? path;
}

abstract final class ViewerDisk {
  /// Copy puts an IMAGE on the clipboard, and Flutter's clipboard carries
  /// text only. A browser has the async Clipboard API; macOS and Windows
  /// would need a native pasteboard write this app does not have yet, and a
  /// Copy that silently copies nothing is worse than no Copy.
  static bool get canCopyImage => kIsWeb;

  /// Whether this platform can say where a save went and open it there.
  static bool get canReveal => platform.canReveal;

  /// Writes [m]'s file into Downloads (a browser download on the web), named
  /// as it was sent, never over an existing file. Null when it did not save.
  static Future<ViewerSaved?> save({
    required ChatApi api,
    required ChatMessage m,
  }) async {
    try {
      final bytes = await _bytes(api, m);
      if (bytes == null) return null;
      final name = m.fileName ?? _fallbackName(m);
      final path = await platform.writeToDownloads(
        bytes,
        name,
        m.mimeType ?? mimeTypeForFileName(name),
      );
      if (path == null) return null;
      return ViewerSaved(path: path.isEmpty ? null : path);
    } catch (e) {
      debugPrint('ViewerDisk.save ${m.id} failed: $e');
      return null;
    }
  }

  /// Puts [m]'s picture on the clipboard as a PNG, the one image type every
  /// browser's clipboard must take. False when it could not.
  static Future<bool> copyImage({
    required ChatApi api,
    required ChatMessage m,
  }) async {
    if (!canCopyImage || m.type != MessageType.image) return false;
    try {
      // The PNG is a promise handed to the clipboard straight away: Safari
      // only accepts a write started inside the key press or click, and the
      // fetch and re-encode below take longer than that window.
      return await platform.copyPng(() async {
        final bytes = await _bytes(api, m);
        if (bytes == null) return null;
        return _png(bytes);
      });
    } catch (e) {
      debugPrint('ViewerDisk.copyImage ${m.id} failed: $e');
      return false;
    }
  }

  /// [m]'s picture in image pixels, for a double-click's "100%": the size
  /// the sender reported, else the header of the file already on disk
  /// ([imageBytesSize] reads only that, it decodes nothing). Null on the
  /// web without a reported size, and for anything not yet downloaded.
  static Future<Size?> pixelSize(ChatMessage m) async {
    final w = m.mediaWidth, h = m.mediaHeight;
    if (w != null && h != null && w > 0 && h > 0) {
      return Size(w.toDouble(), h.toDouble());
    }
    try {
      final bytes = await platform.localBytes(m);
      if (bytes == null) return null;
      // Header only, nothing decoded; through the one web-safe door.
      return await imageBytesSize(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Shows a saved file in Finder / Explorer / the file manager.
  static Future<void> reveal(String path) => platform.reveal(path);

  static Future<Uint8List?> _png(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded);
    try {
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } finally {
      codec.dispose();
    }
  }

  static Future<Uint8List?> _bytes(ChatApi api, ChatMessage m) async {
    final id = m.mediaStorageId;
    if (id == null) return null;
    final local = await platform.localBytes(m);
    if (local != null) return local;
    final url =
        await FileUrlCache.instance.resolve(id, () => api.getFileUrl(id));
    if (url == null) return null;
    // On the web this is normally answered from the browser's HTTP cache,
    // which already holds the file the viewer is showing.
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  }

  static String _fallbackName(ChatMessage m) => switch (m.type) {
        MessageType.image => 'photo-${m.id}.jpg',
        MessageType.video => 'video-${m.id}.mp4',
        MessageType.videoNote => 'video-note-${m.id}.mp4',
        _ => 'file-${m.id}',
      };
}
