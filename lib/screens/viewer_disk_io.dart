import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../media/file_url_cache.dart';
import '../media/storage/media_image_cache.dart';
import '../media/video_file_cache.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';

/// The device's own copy of [m]'s file, or null when there is none: the
/// image cache's full-resolution file for a photo, the downloaded file for a
/// video. Never touches the network.
Future<Uint8List?> localBytes(ChatMessage m) async {
  final id = m.mediaStorageId;
  if (id == null) return null;
  try {
    if (m.type == MessageType.video || m.type == MessageType.videoNote) {
      final path = await VideoFileCache.instance.lookup(id);
      return path == null ? null : await File(path).readAsBytes();
    }
    final url = FileUrlCache.instance.peek(id);
    if (url == null) return null;
    final hit = await MediaImageCache.manager.getFileFromCache(url);
    return hit == null ? null : await hit.file.readAsBytes();
  } catch (e) {
    debugPrint('viewer localBytes $id: $e');
    return null;
  }
}

/// Writes into the user's Downloads, as "name (2).jpg" when "name.jpg" is
/// already there. Null when Downloads is unknown or not writable (a sandboxed
/// Mac build without the Downloads entitlement lands here).
Future<String?> writeToDownloads(
  Uint8List bytes,
  String name,
  String mimeType,
) async {
  final dir = await getDownloadsDirectory();
  if (dir == null) return null;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  var file = File('${dir.path}${Platform.pathSeparator}$name');
  for (var n = 2; await file.exists(); n++) {
    file = File('${dir.path}${Platform.pathSeparator}$stem ($n)$ext');
  }
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

bool get canReveal => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Opens the folder a saved file is in. Not "select the file": that needs
/// `open -R` or `explorer /select`, a process launch a sandboxed Mac app is
/// not allowed; the folder opens through Launch Services like any link.
Future<void> reveal(String path) async {
  final dir = File(path).parent;
  try {
    await launchUrl(Uri.directory(dir.path));
  } catch (e) {
    debugPrint('viewer reveal $path: $e');
  }
}

Future<bool> copyPng(Future<Uint8List?> Function() png) async => false;
