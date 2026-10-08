import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_message.dart';
import '../../models/enums.dart';
import 'json_file.dart';
import 'storage_kinds.dart';

/// What the ledger knows about one stored blob.
class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.kind,
    this.roomId,
    this.messageId,
    this.incoming = false,
    this.sentAt,
    this.fileName,
    this.url,
    this.file,
    int? lastSeen,
    this.local = false,
    this.saved = false,
  }) : lastSeen = lastSeen ?? DateTime.now().millisecondsSinceEpoch;

  /// The Convex storage id, or for a download nothing has tagged (an avatar,
  /// a link preview) the URL it came from.
  final String id;
  StorageKind kind;
  String? roomId;
  String? messageId;
  bool incoming;

  /// When the owning message was sent, epoch ms. Lists sort by it.
  int? sentAt;
  String? fileName;

  /// The URL the image cache keyed the file under, needed to delete it there.
  String? url;

  /// The image cache's file name for it, so the storage scan can size it with
  /// one `stat` instead of a database query per photo.
  String? file;

  /// The last time this was on screen, epoch ms. What auto-remove measures.
  int lastSeen;

  /// Whether a copy is believed to be on disk. Drives the photo download
  /// gate synchronously; the storage scan corrects it when the OS purged a
  /// file behind our back.
  bool local;

  /// Already copied to the photo library, so auto-save never does it twice.
  bool saved;

  Map<String, Object?> toJson() => {
        'k': kind.name,
        if (roomId != null) 'r': roomId,
        if (messageId != null) 'm': messageId,
        if (incoming) 'i': true,
        if (sentAt != null) 't': sentAt,
        if (fileName != null) 'f': fileName,
        if (url != null) 'u': url,
        if (file != null) 'p': file,
        's': lastSeen,
        if (local) 'l': true,
        if (saved) 'g': true,
      };

  static LedgerEntry? fromJson(String id, Object? j) {
    if (j is! Map) return null;
    final kind = StorageKind.parse(j['k'] as String?);
    if (kind == null) return null;
    return LedgerEntry(
      id: id,
      kind: kind,
      roomId: j['r'] as String?,
      messageId: j['m'] as String?,
      incoming: j['i'] == true,
      sentAt: j['t'] as int?,
      fileName: j['f'] as String?,
      url: j['u'] as String?,
      file: j['p'] as String?,
      lastSeen: j['s'] as int?,
      local: j['l'] == true,
      saved: j['g'] == true,
    );
  }
}

/// The index that ties every cached blob to the chat and message it came from.
///
/// None of the on-disk caches know that: a file in `mh_video_v1` is named by
/// its storage id and nothing else. Telegram's storage screen is built on
/// exactly this knowledge (storage by chat, auto-remove by kind of chat), so
/// the app records it at the one moment it is free: when a message carrying
/// media is drawn. [noteMessage] runs from the bubble's build; it is a map
/// lookup on the hot path and a write only when something is new.
///
/// "Last seen" is the clock auto-remove reads. It moves when the media is on
/// screen, throttled to once an hour per blob so scrolling a transcript does
/// not rewrite the file on every frame.
class MediaLedger extends ChangeNotifier {
  MediaLedger._();
  static final MediaLedger instance = MediaLedger._();

  static const _touchEvery = Duration(hours: 1);

  /// Ceiling on entries kept. Past it the longest-unseen entries that are not
  /// on disk are forgotten first; they describe nothing anyone can clear.
  static const _maxEntries = 20000;

  final JsonFile _file = JsonFile('mh_media_ledger_v1.json');
  final Map<String, LedgerEntry> _entries = {};
  bool _loaded = false;

  /// Resolves a room id to the kind of chat it is. Set by the app once the
  /// repository exists; null in tests and before sign-in, when every room
  /// reads as a group (the middle of the three rule sets).
  ChatClass? Function(String roomId)? roomClassifier;

  /// The rooms whose media auto-remove never touches. Saved Messages is the
  /// one the app puts here: it is where people keep things on purpose.
  bool Function(String roomId)? isKeptRoom;

  /// The signed-in user, so a surface that has a message but not the viewer
  /// (a shared media grid, a pager) can still say whether it is incoming.
  String? Function()? selfId;

  /// Every message the app currently holds in memory, for [adoptOrphans].
  Iterable<ChatMessage> Function()? loadedMessages;

  @visibleForTesting
  JsonFile get debugFile => _file;

  Iterable<LedgerEntry> get entries => _entries.values;
  LedgerEntry? operator [](String id) => _entries[id];

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _file.read();
    if (raw is Map) {
      for (final e in raw.entries) {
        final entry = LedgerEntry.fromJson(e.key as String, e.value);
        if (entry != null) _entries.putIfAbsent(entry.id, () => entry);
      }
    }
    notifyListeners();
  }

  ChatClass classOf(LedgerEntry e) {
    final room = e.roomId;
    if (room == null) return ChatClass.groups;
    return roomClassifier?.call(room) ?? ChatClass.groups;
  }

  /// Records the media [m] carries. [incoming] is whether someone else sent
  /// it, which is all auto-download and auto-save care about.
  void noteMessage(ChatMessage m, {required bool incoming}) {
    // An optimistic bubble has no server id yet, and its bytes are local.
    if (m.id.startsWith('tmp_')) return;
    switch (m.type) {
      case MessageType.image:
        _note(m.mediaStorageId, StorageKind.photos, m, incoming);
      case MessageType.video:
        _note(m.mediaStorageId, StorageKind.videos, m, incoming);
        _note(m.posterStorageId, StorageKind.videos, m, incoming);
      case MessageType.videoNote:
        _note(m.mediaStorageId, StorageKind.videoMessages, m, incoming);
        _note(m.posterStorageId, StorageKind.videoMessages, m, incoming);
      case MessageType.audio:
        _note(m.mediaStorageId, StorageKind.voice, m, incoming);
      case MessageType.file:
        _note(m.mediaStorageId, StorageKind.files, m, incoming);
      case MessageType.sticker:
        _note(m.stickerStorageId, StorageKind.stickers, m, incoming);
      default:
        return;
    }
  }

  /// [noteMessage] for a surface that knows the message but not who is
  /// looking: the shared media grid, the media pager.
  void noteSeen(ChatMessage m) {
    final me = selfId?.call();
    noteMessage(m, incoming: me == null || m.senderId != me);
  }

  /// Files a chat onto every entry in [ids] that has none, by finding the
  /// message that carries it among those the app has loaded. The safety net
  /// under the surfaces that tag as they draw: whatever path fetched a file,
  /// the storage screen can still say which chat it belongs to.
  void adoptOrphans(Iterable<String> ids) {
    final wanted = {
      for (final id in ids)
        if (_entries[id]?.roomId == null) id,
    };
    final source = loadedMessages;
    if (wanted.isEmpty || source == null) return;
    for (final m in source()) {
      final hit = wanted.contains(m.mediaStorageId) ||
          wanted.contains(m.posterStorageId) ||
          wanted.contains(m.stickerStorageId);
      if (!hit) continue;
      noteSeen(m);
      wanted
        ..remove(m.mediaStorageId)
        ..remove(m.posterStorageId)
        ..remove(m.stickerStorageId);
      if (wanted.isEmpty) return;
    }
  }

  void _note(String? id, StorageKind kind, ChatMessage m, bool incoming) {
    if (id == null || id.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final known = _entries[id];
    if (known != null) {
      var dirty = false;
      // An untagged download (fetched before its bubble was ever drawn)
      // learns where it belongs.
      if (known.roomId == null) {
        known
          ..roomId = m.roomId
          ..messageId = m.id
          ..kind = kind
          ..incoming = incoming
          ..sentAt = m.createdAt.millisecondsSinceEpoch
          ..fileName = m.fileName;
        dirty = true;
      }
      if (now - known.lastSeen > _touchEvery.inMilliseconds) {
        known.lastSeen = now;
        dirty = true;
      }
      if (dirty) _changed();
      return;
    }
    _entries[id] = LedgerEntry(
      id: id,
      kind: kind,
      roomId: m.roomId,
      messageId: m.id,
      incoming: incoming,
      sentAt: m.createdAt.millisecondsSinceEpoch,
      fileName: m.fileName,
      lastSeen: now,
    );
    _changed();
  }

  /// A file just landed on disk. [url] is the image cache's key for it.
  /// Creates an untagged entry of [fallbackKind] when nothing noted it yet.
  LedgerEntry markLocal(
    String id, {
    String? url,
    String? file,
    StorageKind? fallbackKind,
  }) {
    final e = _entries.putIfAbsent(
      id,
      () => LedgerEntry(id: id, kind: fallbackKind ?? StorageKind.other),
    );
    e.local = true;
    if (url != null) e.url = url;
    if (file != null) e.file = file;
    e.lastSeen = DateTime.now().millisecondsSinceEpoch;
    _changed();
    return e;
  }

  /// Whether [id] is believed to be on disk.
  bool isLocal(String id) => _entries[id]?.local ?? false;

  void markSaved(String id) {
    final e = _entries[id];
    if (e == null || e.saved) return;
    e.saved = true;
    _changed();
  }

  /// The files behind [ids] are gone. Untagged entries are forgotten outright;
  /// tagged ones keep their chat so a re-download is filed correctly.
  void markRemoved(Iterable<String> ids) {
    var any = false;
    for (final id in ids) {
      final e = _entries[id];
      if (e == null) continue;
      any = true;
      if (e.roomId == null) {
        _entries.remove(id);
      } else {
        e
          ..local = false
          ..file = null;
      }
    }
    if (any) _changed();
  }

  /// Sign-out: nothing here may outlive the account it describes.
  Future<void> clear() async {
    _entries.clear();
    await _file.delete();
    notifyListeners();
  }

  void _changed() {
    if (_entries.length > _maxEntries) _trim();
    // Nothing is written until the stored ledger has been read, or a write
    // would replace it with this partial picture. Also what keeps widget
    // tests, which never load it, free of a pending write timer.
    if (_loaded) _file.schedule(_snapshot);
    // Listeners are screens showing a storage breakdown; they rescan rather
    // than read this per change, so one notification per burst is plenty.
    if (_notifyQueued) return;
    _notifyQueued = true;
    scheduleMicrotask(() {
      _notifyQueued = false;
      notifyListeners();
    });
  }

  bool _notifyQueued = false;

  void _trim() {
    final gone = _entries.values.where((e) => !e.local).toList()
      ..sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
    for (final e in gone.take(_entries.length - _maxEntries * 9 ~/ 10)) {
      _entries.remove(e.id);
    }
  }

  Map<String, Object?> _snapshot() =>
      {for (final e in _entries.values) e.id: e.toJson()};

  Future<void> flush() => _file.flush();

  @visibleForTesting
  void debugReset() {
    _entries.clear();
    _loaded = false;
    roomClassifier = null;
    isKeptRoom = null;
    selfId = null;
    loadedMessages = null;
  }
}
