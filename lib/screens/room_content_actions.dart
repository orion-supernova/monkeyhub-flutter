/// The bulk actions the shared-content browser offers, as plain functions.
///
/// Kept out of the screen because each one is a multi-step network operation
/// with its own partial-failure story, and because "what happened" has to be
/// reportable as a sentence — a bulk action that half worked and said nothing
/// is worse than one that failed outright.
library;

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../media/file_meta.dart';
import '../media/file_url_cache.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';

/// What a bulk action did, and the one line to show for it.
class BulkResult {
  const BulkResult({required this.summary, required this.ok, required this.failed});

  final String summary;
  final int ok;
  final int failed;
}

/// Forwards [messages] into each of [targets], one mutation per room.
///
/// One call per room because a Convex mutation is one transaction — see
/// `messages:forwardToRoom`. That is also what makes a partial result possible
/// and worth reporting: a DM the sender has been blocked in fails on its own
/// without taking the other four rooms down with it.
Future<BulkResult> forwardMessages({
  required ChatApi api,
  required ChatRepository repo,
  required String sourceRoomId,
  required List<String> targets,
  required List<ChatMessage> messages,
}) async {
  final me = repo.userId;
  if (me == null) {
    return const BulkResult(summary: 'not signed in', ok: 0, failed: 0);
  }

  final ids = [for (final m in messages) m.id];
  // Idempotency keys, stable per (message, room) pair. A retry after a dropped
  // ack collapses onto the rows the first attempt wrote rather than doubling
  // them — the same mechanism an optimistic bubble's id provides for a send.
  final stamp = DateTime.now().microsecondsSinceEpoch;

  var ok = 0;
  var failed = 0;
  String? firstError;

  for (final roomId in targets) {
    try {
      final res = await api.forwardToRoom(
        sourceRoomId: sourceRoomId,
        targetRoomId: roomId,
        userId: me,
        messageIds: ids,
        clientIds: [for (final id in ids) 'fwd_${stamp}_${roomId}_$id'],
      );
      if (res.forwarded > 0) {
        ok++;
      } else {
        failed++;
      }
    } catch (e) {
      failed++;
      firstError ??= e.toString();
      debugPrint('forward to $roomId failed: $e');
    }
  }

  return BulkResult(
    summary: _forwardSummary(ok: ok, failed: failed, error: firstError),
    ok: ok,
    failed: failed,
  );
}

String _forwardSummary({required int ok, required int failed, String? error}) {
  if (ok == 0) {
    // The refusals worth naming, because each has something the user can do
    // about it. Everything else is a generic failure.
    if (error != null && error.contains('SOURCE_IS_EPHEMERAL')) {
      return "messages that fade can't be forwarded";
    }
    if (error != null && error.contains('UNBLOCK_FIRST')) {
      return 'unblock them first';
    }
    if (error != null && error.contains('NOT_A_MEMBER')) {
      return "you're not in that chat anymore";
    }
    return "couldn't forward that";
  }
  if (failed == 0) return ok == 1 ? 'forwarded' : 'forwarded to $ok chats';
  return 'forwarded to $ok, $failed failed';
}

/// Saves the photos and videos in [messages] to the system photo library.
///
/// Skips anything that isn't a photo or a video rather than failing the batch:
/// a mixed selection is normal in a gallery, and "3 saved" is a better answer
/// than an error about the document that was also picked.
///
/// Never reached on web — `gal` has no web implementation (see the
/// `MissingPluginException` note in `profile_screen.dart`), so the SAVE action
/// is hidden there rather than offered and then failed.
Future<BulkResult> saveMessagesToDevice({
  required ChatApi api,
  required List<ChatMessage> messages,
}) async {
  if (kIsWeb) {
    return const BulkResult(summary: 'not available here', ok: 0, failed: 0);
  }

  final wanted = [
    for (final m in messages)
      if (m.type == MessageType.image || m.type == MessageType.video) m,
  ];
  if (wanted.isEmpty) {
    return const BulkResult(summary: 'nothing to save', ok: 0, failed: 0);
  }

  try {
    if (!await Gal.hasAccess(toAlbum: false)) {
      final granted = await Gal.requestAccess(toAlbum: false);
      if (!granted) {
        return const BulkResult(
            summary: 'photo access is off', ok: 0, failed: 0);
      }
    }
  } catch (e) {
    debugPrint('gal access check failed: $e');
    return const BulkResult(summary: "couldn't save those", ok: 0, failed: 0);
  }

  var ok = 0;
  var failed = 0;
  for (final m in wanted) {
    try {
      final bytes = await _fetchBytes(api, m.mediaStorageId);
      if (bytes == null) {
        failed++;
        continue;
      }
      if (m.type == MessageType.video) {
        // `Gal.putVideo` takes a path, not bytes, so the video has to touch
        // disk first. The temp file is named with the right extension because
        // the library reads the container from it, and is deleted immediately
        // afterwards — this is a handoff, not a cache. Safe without a `kIsWeb`
        // guard of its own: the whole function returned early on web, which is
        // also the only place `path_provider` has no implementation.
        final dir = await getTemporaryDirectory();
        final tmp = File('${dir.path}/monkeyhub-${m.id}.mp4');
        try {
          await tmp.writeAsBytes(bytes, flush: true);
          await Gal.putVideo(tmp.path);
          ok++;
        } finally {
          if (await tmp.exists()) await tmp.delete();
        }
        continue;
      }
      await Gal.putImageBytes(bytes, name: 'monkeyhub-${m.id}');
      ok++;
    } catch (e) {
      failed++;
      debugPrint('save ${m.id} failed: $e');
    }
  }

  return BulkResult(
    summary: ok == 0
        ? "couldn't save those"
        : failed == 0
            ? (ok == 1 ? 'saved to photos' : 'saved $ok to photos')
            : 'saved $ok, $failed failed',
    ok: ok,
    failed: failed,
  );
}

/// Hands [messages] to the system share sheet in one go.
///
/// Everything is fetched before the sheet opens, because `share_plus` takes
/// files rather than futures — and on web that fetch is also what lets the
/// download fall back to a correctly-named anchor instead of a Convex UUID.
Future<bool> shareMessages({
  required ChatApi api,
  required List<ChatMessage> messages,
}) async {
  final files = <XFile>[];
  final names = <String>[];

  for (final m in messages) {
    final bytes = await _fetchBytes(api, m.mediaStorageId);
    if (bytes == null) continue;
    final name = m.fileName ?? _fallbackName(m);
    files.add(XFile.fromData(
      bytes,
      name: name,
      mimeType: m.mimeType ?? mimeTypeForFileName(name),
    ));
    names.add(name);
  }

  if (files.isEmpty) return false;

  try {
    await SharePlus.instance.share(
      ShareParams(files: files, fileNameOverrides: names),
    );
    return true;
  } catch (e) {
    debugPrint('share failed: $e');
    return false;
  }
}

/// Deletes [messageIds] for everyone, reporting what the server refused.
///
/// Partial success is the normal outcome rather than an error: `deleteMany`
/// skips messages the caller doesn't own instead of throwing, so a selection
/// the UI mis-filtered removes what it legitimately can.
Future<BulkResult> deleteMessages({
  required ChatApi api,
  required ChatRepository repo,
  required List<String> messageIds,
}) async {
  final me = repo.userId;
  if (me == null) {
    return const BulkResult(summary: 'not signed in', ok: 0, failed: 0);
  }
  try {
    final res = await api.deleteMessages(userId: me, messageIds: messageIds);
    return BulkResult(
      summary: res.refused > 0
          ? 'deleted ${res.deleted}, ${res.refused} not yours'
          : (res.deleted == 1 ? 'deleted' : 'deleted ${res.deleted}'),
      ok: res.deleted,
      failed: res.refused,
    );
  } catch (e) {
    debugPrint('bulk delete failed: $e');
    return const BulkResult(summary: "couldn't delete those", ok: 0, failed: 1);
  }
}

String _fallbackName(ChatMessage m) => switch (m.type) {
      MessageType.image => 'photo-${m.id}.jpg',
      MessageType.video => 'video-${m.id}.mp4',
      MessageType.videoNote => 'video-note-${m.id}.mp4',
      MessageType.audio => 'voice-${m.id}.m4a',
      _ => 'file-${m.id}',
    };

Future<List<int>?> _fetchBytesRaw(ChatApi api, String storageId) async {
  final url = await FileUrlCache.instance.resolve(
    storageId,
    () => api.getFileUrl(storageId),
  );
  if (url == null) return null;
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode != 200) return null;
  return resp.bodyBytes;
}

Future<Uint8List?> _fetchBytes(ChatApi api, String? storageId) async {
  if (storageId == null) return null;
  try {
    final raw = await _fetchBytesRaw(api, storageId);
    return raw == null ? null : Uint8List.fromList(raw);
  } catch (e) {
    debugPrint('fetch $storageId failed: $e');
    return null;
  }
}
