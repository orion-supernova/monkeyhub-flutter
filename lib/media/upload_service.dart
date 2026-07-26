import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../backend/chat_api.dart';

/// Uploads a single binary blob to Convex's file storage.
///
/// Flow (mirrors v02 ConvexChatAPI.uploadFile):
///   1. Ask backend for a short-lived upload URL.
///   2. POST the bytes there. Response body is JSON: `{ "storageId": "..." }`.
///
/// Bytes only, deliberately. There used to be a `uploadXFile(File)` wrapper
/// whose entire body was `readAsBytes()` — which throws `UnsupportedError` on
/// web, where a picked file is a `blob:` URL with no filesystem behind it.
/// Callers that start from an `XFile` read it themselves; everything the media
/// pipeline produces is already bytes.
class UploadService {
  UploadService(this._api);
  final ChatApi _api;

  Future<String> uploadFile({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final url = await _api.generateUploadUrl();
    final resp = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Upload failed (${resp.statusCode}): ${resp.body}');
    }
    // Convex returns { storageId: "kg2..." }.
    final match = RegExp(r'"storageId"\s*:\s*"([^"]+)"').firstMatch(resp.body);
    if (match == null) {
      throw Exception('Upload succeeded but storageId missing: ${resp.body}');
    }
    return match.group(1)!;
  }
}
