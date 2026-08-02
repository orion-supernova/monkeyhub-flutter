import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Wraps in-memory bytes in a Blob and hands back an object URL.
///
/// Same mechanism as [WebAudio] in `lib/audio/`, for a different reason: there
/// it sidesteps guessing Flutter-web's asset URL layout, here it puts a MIME
/// type the browser recognises onto bytes served from an extension-less Convex
/// storage URL under a content type that isn't registered anywhere.
///
/// `just_audio_web` assigns straight to `element.src`, so an object URL is all
/// it needs.
class BlobUrl {
  const BlobUrl._();

  /// An object URL for [bytes] typed [type], or null if the browser refuses.
  ///
  /// The caller owns the URL and must [revoke] it — an un-revoked object URL
  /// pins its bytes for the life of the document, which for a transcript full
  /// of voice notes is a real leak.
  static String? create(Uint8List bytes, String type) {
    try {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
      return web.URL.createObjectURL(blob);
    } catch (_) {
      return null;
    }
  }

  static void revoke(String url) {
    try {
      web.URL.revokeObjectURL(url);
    } catch (_) {/* already gone, or never ours */}
  }
}
