import 'package:flutter/foundation.dart';

import '../media/file_meta.dart' show kMaxFileUploadBytes;
import '../models/enums.dart';

/// One thing the OS handed us through the share sheet.
///
/// Always a **file on our own disk**, never the URI the sharing app named.
/// Android's `content://` grants are scoped to the activity that received the
/// intent and evaporate when it finishes; iOS hands an extension a URL inside a
/// container the app proper cannot read. Both platforms therefore copy the
/// bytes into our cache before Dart ever hears about the share, and this is the
/// path of that copy — see `ShareIntake.kt` and `ShareViewController.swift`.
///
/// [oversize] items are the exception: nothing was copied, because the file is
/// bigger than [kMaxFileUploadBytes] and copying it would be tens of megabytes
/// of disk churn for something the composer is about to refuse anyway. Their
/// [path] is empty.
@immutable
class SharedItem {
  const SharedItem({
    required this.path,
    required this.mimeType,
    required this.size,
    this.fileName,
    this.oversize = false,
  });

  final String path;
  final String mimeType;

  /// Bytes on disk. Reported by the platform even for [oversize] items, which
  /// is the whole point of reporting it — the refusal can name a real number.
  final int size;

  /// The name the sender's filesystem gave it, when the OS knew one. Rides
  /// onto the message for documents; ignored for photos and video.
  final String? fileName;

  final bool oversize;

  /// Which of the app's message types this becomes.
  ///
  /// Only the top-level MIME type is consulted. A share sheet is a place where
  /// unusual subtypes turn up constantly — `image/heic`, `image/avif`,
  /// `video/quicktime` — and treating an unfamiliar subtype as a document
  /// would send somebody's photo as a downloadable blob.
  MessageType get messageType {
    if (mimeType.startsWith('image/')) return MessageType.image;
    if (mimeType.startsWith('video/')) return MessageType.video;
    return MessageType.file;
  }

  bool get isImage => messageType == MessageType.image;

  @override
  String toString() =>
      'SharedItem($mimeType, $size bytes${oversize ? ', OVERSIZE' : ''})';
}

/// A complete arrival from the system share sheet.
///
/// [targetRoomId] is set when the user tapped one of the app's own suggestions
/// in the sheet's top row rather than the app icon — an Android sharing
/// shortcut or an iOS `INSendMessageIntent` donation, both keyed on the room
/// id. Null means "they picked the app", which is what raises the chat picker.
///
/// A payload with neither items nor text is not a share and is never built;
/// [ShareIntake] drops those at the boundary.
@immutable
class SharedPayload {
  const SharedPayload({
    this.items = const [],
    this.text,
    this.targetRoomId,
  });

  final List<SharedItem> items;

  /// Shared text, or the URL a browser's share button hands over. Becomes the
  /// composer's contents rather than a message: a share is a draft, and sending
  /// it is still the user's tap.
  final String? text;

  final String? targetRoomId;

  bool get isEmpty => items.isEmpty && (text == null || text!.trim().isEmpty);

  /// Items that actually have bytes behind them.
  List<SharedItem> get sendable =>
      [for (final i in items) if (!i.oversize) i];

  List<SharedItem> get oversized =>
      [for (final i in items) if (i.oversize) i];

  /// The single-photo case, which gets the editor rather than a straight send.
  ///
  /// One photo is the overwhelming majority of shares and the one where a
  /// preview is worth a whole screen: it is the only chance to crop, annotate
  /// or arm view-once before the picture is gone. Two photos would need a
  /// carousel the editor does not have, so they go straight up.
  SharedItem? get loneImage {
    final s = sendable;
    return s.length == 1 && s.first.isImage ? s.first : null;
  }

  SharedPayload withTarget(String? roomId) => SharedPayload(
        items: items,
        text: text,
        targetRoomId: roomId,
      );

  /// Rebuilds a payload from the platform channel's map.
  ///
  /// Returns null for anything that carries nothing — a share sheet can be
  /// dismissed mid-flight, and both platforms would rather hand over an empty
  /// envelope than nothing at all.
  static SharedPayload? fromChannel(Object? raw) {
    if (raw is! Map) return null;
    final items = <SharedItem>[];
    for (final entry in (raw['items'] as List?) ?? const []) {
      if (entry is! Map) continue;
      final mime = (entry['mimeType'] as String?) ?? 'application/octet-stream';
      final oversize = entry['oversize'] == true;
      final path = (entry['path'] as String?) ?? '';
      // A non-oversize item with no path is a platform bug, not a share.
      // Dropping it here keeps every downstream `File(path)` honest.
      if (path.isEmpty && !oversize) continue;
      items.add(SharedItem(
        path: path,
        mimeType: mime,
        size: (entry['size'] as num?)?.toInt() ?? 0,
        fileName: entry['fileName'] as String?,
        oversize: oversize,
      ));
    }
    final text = (raw['text'] as String?)?.trim();
    final payload = SharedPayload(
      items: items,
      text: (text == null || text.isEmpty) ? null : text,
      targetRoomId: (raw['targetId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (raw['targetId'] as String).trim(),
    );
    return payload.isEmpty ? null : payload;
  }

  @override
  String toString() => 'SharedPayload(${items.length} items, '
      'text=${text != null}, target=$targetRoomId)';
}
