import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../backend/chat_api.dart';

/// Uploads a single binary blob to Convex's file storage.
///
/// Flow (mirrors v02 ConvexChatAPI.uploadFile):
///   1. Ask backend for a short-lived upload URL.
///   2. POST the bytes there. Response body is JSON: `{ "storageId": "..." }`.
class UploadService {
  UploadService(this._api);
  final ChatApi _api;

  Future<String> uploadFile({
    required Uint8List bytes,
    required String contentType,
    String? filename,
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

  Future<String> uploadXFile({required File file, required String contentType}) async {
    final bytes = await file.readAsBytes();
    return uploadFile(bytes: bytes, contentType: contentType, filename: file.path.split('/').last);
  }
}
