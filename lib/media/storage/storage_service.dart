import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../../companions/brain_manager.dart';
import '../../data/settings_store.dart';
import '../../transcripts/voice_transcriber.dart';
import '../../widgets/expressions/expression_media.dart' show KlipyCacheManager;
import '../audio_file_cache.dart';
import '../document_file_cache.dart';
import '../video_file_cache.dart';
import 'data_prefs.dart';
import 'media_image_cache.dart';
import 'media_ledger.dart';
import 'storage_kinds.dart';

/// Which store a file lives in, so it can be deleted from the right one.
/// `loose` is a file no store indexes by id (a GIF, a link preview, a chat
/// history snapshot): deleting the file is the whole of removing it.
enum _Store { image, video, audio, document, loose }

/// The folders a scan measures.
enum _Dir { image, video, audio, document, klipy, legacy, chats, transcripts }

/// One file, as the scan isolate reports it.
typedef _FileStat = ({String name, String path, int size, int modified});

/// Lists and stats every folder in [dirs]. Runs on a background isolate, so
/// it touches nothing but `dart:io`. The chat history folder is walked
/// recursively with outboxes left out: an outbox holds messages not yet sent,
/// which are not a cache.
Map<_Dir, List<_FileStat>> _measure(Map<_Dir, String> dirs) {
  final sep = Platform.pathSeparator;
  final out = <_Dir, List<_FileStat>>{};
  for (final e in dirs.entries) {
    final list = <_FileStat>[];
    out[e.key] = list;
    final dir = Directory(e.value);
    if (!dir.existsSync()) continue;
    final deep = e.key == _Dir.chats ||
        e.key == _Dir.klipy ||
        e.key == _Dir.legacy;
    try {
      for (final f in dir.listSync(recursive: deep)) {
        if (f is! File) continue;
        if (e.key == _Dir.chats && f.path.contains('${sep}outbox')) continue;
        try {
          final st = f.statSync();
          list.add((
            name: f.uri.pathSegments.last,
            path: f.path,
            size: st.size,
            modified: st.modified.millisecondsSinceEpoch,
          ));
        } catch (_) {/* vanished mid-scan */}
      }
    } catch (_) {/* unreadable folder: counts as empty */}
  }
  return out;
}

/// One cached file the user can see and clear on its own.
class StoredItem {
  StoredItem._({
    required this.id,
    required this.kind,
    required this.bytes,
    required this.lastSeen,
    required _Store store,
    this.roomId,
    this.messageId,
    this.sentAt,
    this.fileName,
    this.url,
    this.path,
  }) : _store = store;

  @visibleForTesting
  factory StoredItem.test({
    required String id,
    required StorageKind kind,
    required int bytes,
    required int lastSeen,
    String? roomId,
  }) =>
      StoredItem._(
        id: id,
        kind: kind,
        bytes: bytes,
        lastSeen: lastSeen,
        store: _Store.video,
        roomId: roomId,
      );

  final String id;
  final StorageKind kind;
  final int bytes;
  final int lastSeen;
  final String? roomId;
  final String? messageId;
  final int? sentAt;
  final String? fileName;
  final String? url;
  final String? path;
  final _Store _store;

  static const _imageExt = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.bmp'};

  /// Whether the file on disk is a picture that can be drawn straight from
  /// [path], with no network: every image store file, and loose files with
  /// an image extension.
  bool get isImageFile {
    if (_store == _Store.image) return true;
    final p = path;
    if (_store != _Store.loose || p == null) return false;
    final dot = p.lastIndexOf('.');
    return dot > 0 && _imageExt.contains(p.substring(dot).toLowerCase());
  }

  /// Whether [id] is a storage id a viewer can open. Loose files (GIFs,
  /// link previews) are keyed by their path, and an untagged download that
  /// never learned its id by its URL; neither names anything to open.
  bool get hasStorageId => _store != _Store.loose && !id.startsWith('http');

  /// Whether this file shows in the Media tab (a picture or a video) rather
  /// than the Files tab.
  bool get isVisual => switch (kind) {
        StorageKind.photos ||
        StorageKind.videos ||
        StorageKind.videoMessages =>
          true,
        _ => false,
      };
}

/// One chat's share of the cache.
class RoomUsage {
  RoomUsage(this.roomId);
  final String roomId;
  final Map<StorageKind, int> byKind = {};
  int get total => byKind.values.fold(0, (a, b) => a + b);
}

/// Free and total space on the device's volume, when the platform says.
typedef DiskSpace = ({int free, int total});

/// A snapshot of everything the app keeps on disk.
class StorageReport {
  StorageReport._({
    required this.byKind,
    required this.items,
    required this.byRoom,
    required this.disk,
  });

  /// A report built from [items] plus untracked totals, for previews and
  /// widget tests that have no disk to scan.
  @visibleForTesting
  factory StorageReport.debug({
    required List<StoredItem> items,
    Map<StorageKind, int> untracked = const {},
    DiskSpace? disk,
  }) {
    final byKind = <StorageKind, int>{...untracked};
    final byRoom = <String, RoomUsage>{};
    for (final i in items) {
      byKind[i.kind] = (byKind[i.kind] ?? 0) + i.bytes;
      final r = i.roomId;
      if (r == null) continue;
      final u = byRoom.putIfAbsent(r, () => RoomUsage(r));
      u.byKind[i.kind] = (u.byKind[i.kind] ?? 0) + i.bytes;
    }
    return StorageReport._(
        byKind: byKind, items: items, byRoom: byRoom, disk: disk);
  }

  static final empty = StorageReport._(
    byKind: const {},
    items: const [],
    byRoom: const {},
    disk: null,
  );

  final Map<StorageKind, int> byKind;
  final List<StoredItem> items;
  final Map<String, RoomUsage> byRoom;
  final DiskSpace? disk;

  int get total => byKind.values.fold(0, (a, b) => a + b);

  /// Rooms, biggest first.
  List<RoomUsage> get rooms =>
      byRoom.values.where((r) => r.total > 0).toList()
        ..sort((a, b) => b.total.compareTo(a.total));

  List<StoredItem> get media =>
      items.where((i) => i.isVisual && i.roomId != null).toList()
        ..sort((a, b) => b.bytes.compareTo(a.bytes));

  List<StoredItem> get files => items
      .where((i) =>
          i.roomId != null &&
          (i.kind == StorageKind.files || i.kind == StorageKind.voice))
      .toList()
    ..sort((a, b) => b.bytes.compareTo(a.bytes));

  /// Every file of [kind], biggest first: what a category's own page lists.
  List<StoredItem> itemsOf(StorageKind kind) =>
      items.where((i) => i.kind == kind).toList()
        ..sort((a, b) => b.bytes.compareTo(a.bytes));
}

/// Measures, clears and trims every cache the app keeps.
///
/// The caches themselves stay independent (images, videos, voice, documents,
/// GIFs, the chat history snapshot); this is the one place that sees them as a
/// whole, joins each file to the chat it came from through [MediaLedger], and
/// carries out the user's rules: auto-remove after a period untouched, per kind
/// of chat, and a ceiling on the total.
///
/// [report] is the latest scan. Screens listen and call [scan] when they
/// open; the scan is all `stat` calls on known paths, fast enough to run on
/// every visit.
class StorageService extends ChangeNotifier {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _device = MethodChannel('monkeyhub/device');

  StorageReport _report = StorageReport.empty;
  bool _scanning = false;
  bool _scannedOnce = false;
  Future<StorageReport>? _inFlight;

  StorageReport get report => _report;

  /// True until the first scan lands: the screens draw a calculating state
  /// rather than a misleading zero.
  bool get calculating => !_scannedOnce;
  bool get scanning => _scanning;

  /// Rescans every store. Concurrent calls share one scan.
  Future<StorageReport> scan() {
    if (_frozen) return Future.value(_report);
    return _inFlight ??= _scan().whenComplete(() {
      _inFlight = null;
    });
  }

  bool _frozen = false;

  /// Pins [report] and stops scanning, for previews and widget tests.
  @visibleForTesting
  void debugSetReport(StorageReport report) {
    _report = report;
    _scannedOnce = true;
    _frozen = true;
    notifyListeners();
  }

  Future<StorageReport> _scan() async {
    if (kIsWeb) {
      _scannedOnce = true;
      notifyListeners();
      return _report;
    }
    // No notification here: scan() is called from initState, and telling
    // listeners mid-build is an error. The finally block reports the result.
    _scanning = true;
    try {
      final ledger = MediaLedger.instance;
      await ledger.load();
      final items = <StoredItem>[];
      final byKind = <StorageKind, int>{};
      void add(StorageKind k, int bytes) =>
          byKind[k] = (byKind[k] ?? 0) + bytes;

      final tmp = (await getTemporaryDirectory()).path;
      final cache = (await getApplicationCacheDirectory()).path;
      final docs = (await getApplicationDocumentsDirectory()).path;
      final support = (await getApplicationSupportDirectory()).path;
      final dirs = {
        _Dir.image: '$tmp/${MediaImageCache.storeKey}',
        _Dir.video: '$cache/${VideoFileCache.dirName}',
        _Dir.audio: '$cache/${AudioFileCache.dirName}',
        _Dir.document: '$cache/${DocumentFileCache.dirName}',
        _Dir.klipy: '$tmp/klipyMedia',
        _Dir.legacy: '$tmp/${DefaultCacheManager.key}',
        _Dir.chats: '$docs/cache',
        _Dir.transcripts: '$support/transcripts',
      };
      // Every list and stat on a background isolate: a cache of thousands of
      // files is thousands of syscalls, and the screen asking for them is
      // animating its ring while they run.
      final stats = await _measureOffThread(dirs);

      // Give a chat to anything fetched by a path that didn't tag it.
      ledger.adoptOrphans([
        for (final d in [_Dir.video, _Dir.audio, _Dir.document])
          for (final f in stats[d]!)
            f.name.contains('.') ? f.name.substring(0, f.name.indexOf('.')) : f.name,
        for (final e in ledger.entries)
          if (e.roomId == null) e.id,
      ]);

      // Images: every tracked file by name, the rest of the folder as
      // untracked "other" (files fetched before tracking existed).
      final images = {for (final f in stats[_Dir.image]!) f.name: f};
      final stale = <String>[];
      for (final e in ledger.entries) {
        final name = e.file;
        if (name == null || e.url == null) continue;
        final f = images.remove(name);
        if (f == null) {
          if (e.local) stale.add(e.id);
          continue;
        }
        items.add(_item(e, f.size, _Store.image, f.path));
        add(e.kind, f.size);
      }
      // Untracked images (avatars, covers, anything cached before tracking)
      // are still files someone can look at and clear one by one.
      StoredItem loose(_FileStat f, StorageKind kind, {String? roomId}) =>
          StoredItem._(
            id: f.path,
            kind: kind,
            bytes: f.size,
            lastSeen: f.modified,
            store: _Store.loose,
            path: f.path,
            roomId: roomId,
          );
      for (final f in images.values) {
        items.add(loose(f, StorageKind.other));
        add(StorageKind.other, f.size);
      }
      // The OS purged these from the temp directory behind our back.
      ledger.markRemoved(stale);

      void fromDir(_Dir dir, _Store store, StorageKind fallback) {
        for (final f in stats[dir]!) {
          if (f.name.endsWith('.part')) continue;
          final dot = f.name.indexOf('.');
          final id = dot > 0 ? f.name.substring(0, dot) : f.name;
          final e = ledger[id];
          final kind = e?.kind ?? fallback;
          items.add(e == null
              ? StoredItem._(
                  id: id,
                  kind: kind,
                  bytes: f.size,
                  lastSeen: f.modified,
                  store: store,
                  path: f.path,
                )
              : _item(e, f.size, store, f.path));
          add(kind, f.size);
        }
      }

      fromDir(_Dir.video, _Store.video, StorageKind.videos);
      fromDir(_Dir.audio, _Store.audio, StorageKind.voice);
      fromDir(_Dir.document, _Store.document, StorageKind.files);

      for (final f in stats[_Dir.klipy]!) {
        items.add(loose(f, StorageKind.stickers));
        add(StorageKind.stickers, f.size);
      }
      // flutter_cache_manager's default store: link previews, and everything
      // cached before this store existed.
      for (final f in stats[_Dir.legacy]!) {
        items.add(loose(f, StorageKind.other));
        add(StorageKind.other, f.size);
      }
      // Chat history, filed per chat from the snapshot's own file names. The
      // room list, friends and the like are what the app opens on: counted,
      // never offered for deletion.
      for (final f in stats[_Dir.chats]!) {
        final room = _historyRoom.firstMatch(f.name)?.group(1);
        if (room != null) items.add(loose(f, StorageKind.chatHistory, roomId: room));
        add(StorageKind.chatHistory, f.size);
      }
      add(StorageKind.companions, await _companionBytes());
      // The speech model, any partial of it, and the transcripts it made: one
      // row, each file listed so the category screen can show what is there.
      for (final f in stats[_Dir.transcripts]!) {
        items.add(loose(f, StorageKind.speechModel));
        add(StorageKind.speechModel, f.size);
      }

      final byRoom = <String, RoomUsage>{};
      for (final i in items) {
        final r = i.roomId;
        if (r == null) continue;
        final u = byRoom.putIfAbsent(r, () => RoomUsage(r));
        u.byKind[i.kind] = (u.byKind[i.kind] ?? 0) + i.bytes;
      }
      byKind.removeWhere((_, v) => v <= 0);

      _report = StorageReport._(
        byKind: byKind,
        items: items,
        byRoom: byRoom,
        disk: await _diskSpace(),
      );
      return _report;
    } catch (e) {
      debugPrint('StorageService.scan failed: $e');
      return _report;
    } finally {
      _scanning = false;
      _scannedOnce = true;
      notifyListeners();
    }
  }

  /// Its own static method so the closure handed to [Isolate.run] captures
  /// only [dirs]. Created inside [_scan], it captured that whole scope (the
  /// ledger with its pending write Future included), and a Future cannot be
  /// sent to another isolate, so every scan failed.
  static Future<Map<_Dir, List<_FileStat>>> _measureOffThread(
          Map<_Dir, String> dirs) =>
      Isolate.run(() => _measure(dirs));

  /// `messages_<roomId>.json` and its siblings in the chat history snapshot.
  static final _historyRoom =
      RegExp(r'^(?:messages|interactions|members)_([A-Za-z0-9_-]+)\.json$');

  static StoredItem _item(LedgerEntry e, int size, _Store store, String path) =>
      StoredItem._(
        id: e.id,
        kind: e.kind,
        bytes: size,
        lastSeen: e.lastSeen,
        store: store,
        roomId: e.roomId,
        messageId: e.messageId,
        sentAt: e.sentAt,
        fileName: e.fileName,
        url: e.url,
        path: path,
      );

  static int _dirSize(Directory d) {
    if (!d.existsSync()) return 0;
    var total = 0;
    try {
      for (final e in d.listSync(recursive: true)) {
        if (e is File) total += e.statSync().size;
      }
    } catch (_) {}
    return total;
  }

  static Future<int> _companionBytes() async {
    var total = BrainManager.instance.installedBytes;
    try {
      final support = await getApplicationSupportDirectory();
      final f = File('${support.path}/companions/translations.json');
      if (f.existsSync()) total += f.lengthSync();
    } catch (_) {}
    return total;
  }

  static Future<DiskSpace?> _diskSpace() async {
    try {
      final r = await _device.invokeMapMethod<String, Object?>('getDiskSpace');
      final free = (r?['free'] as num?)?.toInt() ?? 0;
      final total = (r?['total'] as num?)?.toInt() ?? 0;
      return free > 0 && total > 0 ? (free: free, total: total) : null;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────── clearing ───────────────────────────────

  /// Clears [kinds], everywhere or only in [roomId]. Returns bytes freed.
  Future<int> clear(Set<StorageKind> asked, {String? roomId}) async {
    final kinds = {for (final k in asked) if (k.isClearable) k};
    final picked = _report.items
        .where((i) =>
            kinds.contains(i.kind) && (roomId == null || i.roomId == roomId))
        .toList();
    var freed = await _delete(picked);
    if (roomId == null) {
      if (kinds.contains(StorageKind.stickers)) {
        freed += await _wipe(KlipyCacheManager.instance, 'klipyMedia');
      }
      if (kinds.contains(StorageKind.other)) {
        freed += await _wipeUntrackedImages();
        freed += await _wipe(DefaultCacheManager(), DefaultCacheManager.key);
      }
      if (kinds.contains(StorageKind.speechModel)) {
        // The files are gone already; this lets go of the loaded engine and
        // the in-memory transcripts, so nothing writes them back.
        await VoiceTranscriber.instance.forgetAll();
      }
    }
    await scan();
    return freed;
  }

  /// Deletes exactly [items]. Returns bytes freed.
  Future<int> deleteItems(Iterable<StoredItem> items) async {
    final freed = await _delete(items.toList());
    await scan();
    return freed;
  }

  Future<int> _delete(List<StoredItem> items) async {
    var freed = 0;
    for (final i in items) {
      try {
        switch (i._store) {
          case _Store.image:
            final url = i.url;
            if (url != null) await MediaImageCache.remove(url);
          case _Store.video:
            await VideoFileCache.instance.evict(i.id);
          case _Store.audio:
            await AudioFileCache.instance.evict(i.id);
          case _Store.document:
            await DocumentFileCache.instance.evict(i.id);
          case _Store.loose:
            break;
        }
        // Whatever the store did, the file must not survive a "clear".
        final p = i.path;
        if (p != null) {
          final f = File(p);
          if (f.existsSync()) f.deleteSync();
        }
        freed += i.bytes;
      } catch (e) {
        debugPrint('StorageService delete ${i.id} failed: $e');
      }
    }
    MediaLedger.instance.markRemoved(items.map((i) => i.id));
    return freed;
  }

  Future<int> _wipe(CacheManager m, String folder) async {
    final tmp = await getTemporaryDirectory();
    final size = _dirSize(Directory('${tmp.path}/$folder'));
    try {
      await m.emptyCache();
    } catch (_) {}
    return size;
  }

  /// Image files no ledger entry names: everything cached before tracking.
  Future<int> _wipeUntrackedImages() async {
    final dir = await MediaImageCache.directory();
    if (dir == null) return 0;
    final tracked = {
      for (final e in MediaLedger.instance.entries)
        if (e.file != null && e.roomId != null) e.file,
    };
    var freed = 0;
    for (final e in dir.listSync()) {
      if (e is! File || tracked.contains(e.uri.pathSegments.last)) continue;
      try {
        freed += e.lengthSync();
        e.deleteSync();
      } catch (_) {}
    }
    // Untagged entries point at files that are now gone.
    MediaLedger.instance.markRemoved([
      for (final e in MediaLedger.instance.entries)
        if (e.roomId == null) e.id,
    ]);
    return freed;
  }

  // ─────────────────────────────── policy ───────────────────────────────

  DateTime? _lastEnforced;

  /// Applies auto-remove and the cache ceiling. Cheap to call often: it runs
  /// at most every few hours unless [force]d (a rule just changed).
  Future<void> enforcePolicy({bool force = false}) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final last = _lastEnforced;
    if (!force && last != null && now.difference(last).inHours < 6) return;
    _lastEnforced = now;
    final report = await scan();
    final victims = pickForRemoval(
      report.items,
      prefs: SettingsStore.instance.dataPrefs,
      now: now,
      classOf: (roomId) =>
          MediaLedger.instance.roomClassifier?.call(roomId) ?? ChatClass.groups,
      isKept: (roomId) => MediaLedger.instance.isKeptRoom?.call(roomId) ?? false,
    );
    if (victims.isEmpty) return;
    await _delete(victims);
    await scan();
  }

  /// Which items the rules remove: first everything untouched for longer than
  /// its chat's keep period, then the least recently seen until the total
  /// fits the ceiling. Pure, for tests.
  @visibleForTesting
  static List<StoredItem> pickForRemoval(
    List<StoredItem> items, {
    required DataStoragePrefs prefs,
    required DateTime now,
    required ChatClass Function(String roomId) classOf,
    required bool Function(String roomId) isKept,
  }) {
    final out = <StoredItem>{};
    final nowMs = now.millisecondsSinceEpoch;
    for (final i in items) {
      final room = i.roomId;
      // Media only: a chat history snapshot's age says nothing about whether
      // anyone wants it, and losing it costs a slow first open.
      if (!i.kind.isMessageMedia) continue;
      if (room == null || isKept(room)) continue;
      final keep = prefs.keepIn(classOf(room)).duration;
      if (keep == null) continue;
      if (nowMs - i.lastSeen > keep.inMilliseconds) out.add(i);
    }
    final limit = prefs.cacheLimit.bytes;
    if (limit != null) {
      var total = items.fold<int>(0, (a, i) => a + i.bytes) -
          out.fold<int>(0, (a, i) => a + i.bytes);
      if (total > limit) {
        final byAge = items
            .where((i) =>
                !out.contains(i) &&
                i.kind != StorageKind.chatHistory &&
                !(i.roomId != null && isKept(i.roomId!)))
            .toList()
          ..sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
        for (final i in byAge) {
          if (total <= limit) break;
          out.add(i);
          total -= i.bytes;
        }
      }
    }
    return out.toList();
  }
}
