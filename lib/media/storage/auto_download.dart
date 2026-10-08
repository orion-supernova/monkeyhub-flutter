import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../backend/chat_api.dart';
import '../../data/settings_store.dart';
import '../../models/chat_message.dart';
import '../../models/enums.dart';
import '../document_file_cache.dart';
import '../file_url_cache.dart';
import '../video_file_cache.dart';
import 'media_ledger.dart';
import 'network_kind.dart';
import 'storage_kinds.dart';

/// Decides what downloads without a tap, and fetches it.
///
/// The rules are the user's (Data and Storage → Automatic Media Download), per
/// network and per kind of chat. Voice messages and stickers are always
/// fetched: they are tiny, and a voice note that waits for a tap to download
/// before it can play is a worse product than the bytes it saves.
///
/// Photos are gated where they draw (`AutoDownloadGate`). Videos, round video
/// messages and files are fetched ahead here, from the same hook that files
/// them in the ledger, so the player and the document opener find a local
/// copy waiting. Ahead-fetches run two at a time, newest first, and a fast
/// scroll through history drops the oldest queued ones rather than spending
/// data on bubbles long gone from the screen.
class AutoDownload {
  AutoDownload._();
  static final AutoDownload instance = AutoDownload._();

  static const _maxQueued = 8;
  static const _maxActive = 2;

  /// Ids already considered this session, so a rebuild never re-queues.
  final Set<String> _seen = {};

  /// Photos the user tapped to load this session.
  final Set<String> _released = {};

  final List<_Job> _queue = [];
  int _active = 0;

  ChatClass _classOf(String roomId) =>
      MediaLedger.instance.roomClassifier?.call(roomId) ?? ChatClass.groups;

  /// Whether [kind] in [roomId] downloads on its own right now.
  bool allows(StorageKind kind, String roomId, {int? bytes}) {
    switch (kind) {
      case StorageKind.voice || StorageKind.stickers:
        return true;
      case StorageKind.chatHistory || StorageKind.other:
        return true;
      default:
        break;
    }
    if (NetworkKindMonitor.instance.offline) return false;
    final net = NetworkKindMonitor.instance.current;
    final rules = SettingsStore.instance.dataPrefs.downloadsOn(net);
    if (!rules.enabled) return false;
    final chat = _classOf(roomId);
    return switch (kind) {
      StorageKind.photos => rules.photos.allows(chat),
      StorageKind.videos ||
      StorageKind.videoMessages =>
        rules.videos.allows(chat, bytes: bytes),
      StorageKind.files => rules.files.allows(chat, bytes: bytes),
      _ => true,
    };
  }

  /// The size cap for an ahead-fetch of [kind] on the current network.
  int? capFor(StorageKind kind) {
    final rules = SettingsStore.instance.dataPrefs
        .downloadsOn(NetworkKindMonitor.instance.current);
    return switch (kind) {
      StorageKind.videos || StorageKind.videoMessages => rules.videos.maxBytes,
      StorageKind.files => rules.files.maxBytes,
      _ => null,
    };
  }

  /// Whether a photo should draw now, or wait behind a tap.
  bool photoReady(String storageId, String roomId, {required bool incoming}) =>
      !incoming ||
      _released.contains(storageId) ||
      MediaLedger.instance.isLocal(storageId) ||
      allows(StorageKind.photos, roomId);

  void releasePhoto(String storageId) => _released.add(storageId);

  /// Considers [m] for an ahead-fetch. Called as a message is drawn.
  void consider(ChatMessage m, ChatApi api, {required bool incoming}) {
    if (kIsWeb || !incoming || m.viewOnce) return;
    if (!NetworkKindMonitor.instance.started) return;
    final id = m.mediaStorageId;
    if (id == null || id.isEmpty || id.startsWith('tmp_')) return;
    final StorageKind kind;
    switch (m.type) {
      case MessageType.video:
        kind = StorageKind.videos;
      case MessageType.videoNote:
        kind = StorageKind.videoMessages;
      case MessageType.file:
        kind = StorageKind.files;
      default:
        return;
    }
    if (!_seen.add(id)) return;
    if (MediaLedger.instance.isLocal(id)) return;
    final bytes = kind == StorageKind.files ? m.fileSize : null;
    if (!allows(kind, m.roomId, bytes: bytes)) {
      // Not now. Forgotten, so the next sighting on a better network or
      // after a rule change gets a fresh look.
      _seen.remove(id);
      return;
    }
    _queue.add(_Job(id, kind, m.fileName, api));
    while (_queue.length > _maxQueued) {
      _seen.remove(_queue.removeAt(0).id);
    }
    _pump();
  }

  void _pump() {
    while (_active < _maxActive && _queue.isNotEmpty) {
      final job = _queue.removeLast();
      _active++;
      unawaited(_run(job).whenComplete(() {
        _active--;
        _pump();
      }));
    }
  }

  Future<void> _run(_Job j) async {
    // Rechecked at the moment of fetching: the network may have changed
    // while this waited in line.
    if (NetworkKindMonitor.instance.offline) {
      _seen.remove(j.id);
      return;
    }
    Future<String?> url() =>
        FileUrlCache.instance.resolve(j.id, () => j.api.getFileUrl(j.id));
    try {
      switch (j.kind) {
        case StorageKind.files:
          await DocumentFileCache.instance.resolve(j.id, url,
              fileName: j.fileName, maxBytes: capFor(j.kind));
        default:
          if (await VideoFileCache.instance.lookup(j.id) != null) return;
          await VideoFileCache.instance
              .resolve(j.id, url, maxBytes: capFor(j.kind));
      }
    } on MediaTooLarge {
      // Over the cap: left for a tap, which streams it as before.
    } on FileTooLarge {
      // Same, for a document.
    } catch (e) {
      debugPrint('auto-download ${j.id} failed: $e');
      _seen.remove(j.id);
    }
  }

  @visibleForTesting
  void debugReset() {
    _seen.clear();
    _released.clear();
    _queue.clear();
    _active = 0;
  }
}

class _Job {
  _Job(this.id, this.kind, this.fileName, this.api);
  final String id;
  final StorageKind kind;
  final String? fileName;
  final ChatApi api;
}
