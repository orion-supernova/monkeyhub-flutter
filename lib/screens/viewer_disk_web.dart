import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../models/chat_message.dart';

/// No file of its own on the web: the browser's HTTP cache is the copy.
Future<Uint8List?> localBytes(ChatMessage m) async => null;

/// A browser download with the file's real name. Returns '' (saved, at a
/// place only the browser knows) or null when the browser refused.
Future<String?> writeToDownloads(
  Uint8List bytes,
  String name,
  String mimeType,
) async {
  final blob =
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  try {
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = name
      ..style.display = 'none';
    web.document.body?.append(a);
    a.click();
    a.remove();
    return '';
  } finally {
    // After the click has handed the blob to the download manager.
    Future<void>.delayed(const Duration(seconds: 30), () {
      web.URL.revokeObjectURL(url);
    });
  }
}

bool get canReveal => false;

Future<void> reveal(String path) async {}

/// `navigator.clipboard.write` with the PNG as a promise, so the write is
/// started inside the user's gesture and filled in when the bytes are ready.
Future<bool> copyPng(Future<Uint8List?> Function() png) async {
  final clipboard = web.window.navigator.clipboard;
  final blob = png().then((bytes) {
    if (bytes == null) throw StateError('no image');
    return web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  });
  final items = JSObject()..setProperty('image/png'.toJS, blob.toJS);
  await clipboard.write([web.ClipboardItem(items)].toJS).toDart;
  return true;
}
