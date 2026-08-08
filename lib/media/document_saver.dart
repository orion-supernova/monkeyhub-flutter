import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../backend/chat_api.dart';
import 'file_url_cache.dart';

/// Hands a received document to the platform, whatever "the platform" means
/// here.
///
/// One code path for every target, because `share_plus` already branches for
/// us: on web it tries the Web Share API and falls back to clicking an
/// `<a download="…">` anchor, and everywhere else it writes the bytes to a
/// temp file and opens the system share sheet. That fallback is the entire
/// reason this doesn't need a conditional import — an earlier sketch of this
/// grew its own web anchor and its own `path_provider` temp file before it
/// turned out both already existed a layer down.
///
/// The bytes are fetched rather than the URL being handed over directly, and
/// that is not incidental: Convex storage serves attachments from
/// `<site>/api/storage/<uuid>` with no `Content-Disposition` and no extension,
/// so a browser told to save that URL writes a file called `<uuid>` with no
/// type. [fileName] only survives if we own the download.
class DocumentSaver {
  const DocumentSaver._();

  /// Resolves [storageId] and downloads its bytes.
  ///
  /// Throws [FileUnavailable] when the storage id no longer resolves — a
  /// message whose room was wiped, or a blob reclaimed by `gcOrphanedFiles` —
  /// and rethrows transport failures, both of which the caller reports on the
  /// tile rather than swallowing. Shared by [save] and by the in-app text
  /// viewer, which wants the bytes to decode rather than to hand to the OS.
  static Future<Uint8List> fetchBytes({
    required ChatApi api,
    required String storageId,
  }) async {
    // Null rather than a throw on a miss — see `FileUrlCache.resolve`, which
    // deliberately doesn't cache the absence either.
    final url = await FileUrlCache.instance.resolve(
      storageId,
      () => api.getFileUrl(storageId),
    );
    if (url == null) throw const FileUnavailable();

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) throw const FileUnavailable();
    return resp.bodyBytes;
  }

  /// Fetches [storageId] and offers it to the OS as [fileName].
  ///
  /// [originRect] must be the tapped tile's rect in global coordinates. iPads
  /// and Macs anchor the share popover to it; passing null there leaves the
  /// sheet pinned to the middle of the screen with no arrow pointing anywhere.
  static Future<void> save({
    required ChatApi api,
    required String storageId,
    required String fileName,
    required String mimeType,
    Rect? originRect,
  }) async {
    final Uint8List bytes = await fetchBytes(api: api, storageId: storageId);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
        // `XFile.fromData` carries no filesystem name, so without this the
        // share sheet and the web download both fall back to a generated one.
        // The package's own docs name this exact case.
        fileNameOverrides: [fileName],
        sharePositionOrigin: originRect,
      ),
    );
  }
}
