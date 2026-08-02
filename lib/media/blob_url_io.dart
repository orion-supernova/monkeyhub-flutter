import 'dart:typed_data';

/// Non-web no-op. Native and desktop play audio from a real file on disk, so
/// there is nothing to wrap; this stub exists only so the conditional export in
/// `blob_url.dart` resolves off-web.
class BlobUrl {
  const BlobUrl._();

  /// Always null off-web — the caller treats that as "use the plain URL".
  static String? create(Uint8List bytes, String type) => null;

  static void revoke(String url) {}
}
