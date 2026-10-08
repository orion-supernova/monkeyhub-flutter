import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/storage/data_prefs.dart';
import 'package:monkeyhub/media/storage/data_usage_store.dart';
import 'package:monkeyhub/media/storage/media_ledger.dart';
import 'package:monkeyhub/media/storage/storage_kinds.dart';
import 'package:monkeyhub/media/storage/storage_service.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';

const _mb = 1024 * 1024;

ChatMessage _msg(
  String id,
  MessageType type, {
  String room = 'r1',
  String? media,
  String? poster,
  String? fileName,
}) =>
    ChatMessage(
      id: id,
      roomId: room,
      senderId: 'them',
      senderName: 'Them',
      content: '',
      createdAt: DateTime(2026, 10, 1),
      type: type,
      mediaStorageId: media,
      posterStorageId: poster,
      fileName: fileName,
    );

void main() {
  group('DataStoragePrefs', () {
    test('round-trips through JSON', () {
      final p = DataStoragePrefs.defaults.copyWith(
        cellular: NetworkDownloadPrefs.preset(DownloadPreset.low, NetKind.cellular)
            .copyWith(enabled: false),
        saveToPhotos: {
          ChatClass.privateChats:
              const SaveToPhotos(photos: true, maxVideoBytes: 10 * _mb),
        },
        keepMedia: {ChatClass.groups: KeepMedia.week},
        cacheLimit: CacheLimit.gb20,
        callDataSaver: CallDataSaver.cellular,
      );
      final back = DataStoragePrefs.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.cellular.enabled, isFalse);
      expect(back.cellular.presetFor(NetKind.cellular), DownloadPreset.low);
      expect(back.wifi.presetFor(NetKind.wifi), DownloadPreset.medium);
      expect(back.saveIn(ChatClass.privateChats).photos, isTrue);
      expect(back.saveIn(ChatClass.privateChats).maxVideoBytes, 10 * _mb);
      expect(back.saveIn(ChatClass.groups).isOff, isTrue);
      expect(back.keepIn(ChatClass.groups), KeepMedia.week);
      expect(back.keepIn(ChatClass.privateChats), KeepMedia.forever);
      expect(back.cacheLimit, CacheLimit.gb20);
      expect(back.callDataSaver, CallDataSaver.cellular);
    });

    test('garbage falls back to the defaults', () {
      final p = DataStoragePrefs.fromJson({'cell': 3, 'limit': 'nope', 'keep': []});
      expect(p.cacheLimit, DataStoragePrefs.defaults.cacheLimit);
      expect(p.cellular.presetFor(NetKind.cellular), DownloadPreset.medium);
    });

    test('every preset is recognised on both networks', () {
      for (final net in NetKind.values) {
        for (final preset in DownloadPreset.values) {
          expect(NetworkDownloadPrefs.preset(preset, net).presetFor(net), preset);
        }
      }
    });

    test('a customised type is no longer a preset', () {
      final p = NetworkDownloadPrefs.preset(DownloadPreset.medium, NetKind.wifi);
      final custom = p.copyWith(files: p.files.copyWith(maxBytes: 5 * _mb));
      expect(custom.presetFor(NetKind.wifi), isNull);
    });

    test('calls save data per the rule and the network', () {
      final cell = DataStoragePrefs.defaults
          .copyWith(callDataSaver: CallDataSaver.cellular);
      expect(cell.callsSaveData(NetKind.cellular), isTrue);
      expect(cell.callsSaveData(NetKind.wifi), isFalse);
      expect(DataStoragePrefs.defaults.callsSaveData(NetKind.cellular), isFalse);
    });
  });

  group('MediaRule', () {
    const rule = MediaRule(chats: {ChatClass.groups}, maxBytes: 10 * _mb);

    test('allows only its chats', () {
      expect(rule.allows(ChatClass.groups), isTrue);
      expect(rule.allows(ChatClass.privateChats), isFalse);
    });

    test('enforces the size cap when the size is known', () {
      expect(rule.allows(ChatClass.groups, bytes: 9 * _mb), isTrue);
      expect(rule.allows(ChatClass.groups, bytes: 11 * _mb), isFalse);
      // Unknown sizes pass; the download enforces the cap from the length.
      expect(rule.allows(ChatClass.groups), isTrue);
    });
  });

  group('MediaLedger', () {
    setUp(MediaLedger.instance.debugReset);

    test('files message media under its chat and kind', () {
      final ledger = MediaLedger.instance;
      ledger.noteMessage(
          _msg('m1', MessageType.video, media: 'vid1', poster: 'pos1'),
          incoming: true);
      ledger.noteMessage(_msg('m2', MessageType.file, media: 'doc1', fileName: 'a.pdf'),
          incoming: false);

      expect(ledger['vid1']!.kind, StorageKind.videos);
      expect(ledger['pos1']!.kind, StorageKind.videos);
      expect(ledger['vid1']!.roomId, 'r1');
      expect(ledger['vid1']!.incoming, isTrue);
      expect(ledger['doc1']!.fileName, 'a.pdf');
      expect(ledger['doc1']!.incoming, isFalse);
    });

    test('ignores optimistic messages and text', () {
      final ledger = MediaLedger.instance;
      ledger.noteMessage(_msg('tmp_1', MessageType.image, media: 'x'), incoming: true);
      ledger.noteMessage(_msg('m3', MessageType.text), incoming: true);
      expect(ledger.entries, isEmpty);
    });

    test('an untagged download learns its chat when the bubble draws', () {
      final ledger = MediaLedger.instance;
      ledger.markLocal('img1', url: 'https://x/1');
      expect(ledger['img1']!.roomId, isNull);
      expect(ledger['img1']!.kind, StorageKind.other);

      ledger.noteMessage(_msg('m4', MessageType.image, media: 'img1'), incoming: true);
      expect(ledger['img1']!.roomId, 'r1');
      expect(ledger['img1']!.kind, StorageKind.photos);
      expect(ledger.isLocal('img1'), isTrue);
    });

    test('removal forgets untagged files and unmarks tagged ones', () {
      final ledger = MediaLedger.instance;
      ledger.markLocal('avatar', url: 'https://x/a');
      ledger.noteMessage(_msg('m5', MessageType.image, media: 'p1'), incoming: true);
      ledger.markLocal('p1', url: 'https://x/p', file: 'p.jpg');

      ledger.markRemoved(['avatar', 'p1']);
      expect(ledger['avatar'], isNull);
      expect(ledger['p1'], isNotNull);
      expect(ledger.isLocal('p1'), isFalse);
      expect(ledger['p1']!.file, isNull);
    });

    test('entries survive a JSON round trip', () {
      final e = LedgerEntry(
        id: 'a',
        kind: StorageKind.voice,
        roomId: 'r',
        messageId: 'm',
        incoming: true,
        sentAt: 5,
        url: 'u',
        file: 'f',
        lastSeen: 7,
        local: true,
        saved: true,
      );
      final back = LedgerEntry.fromJson('a', jsonDecode(jsonEncode(e.toJson())))!;
      expect(back.kind, StorageKind.voice);
      expect(back.roomId, 'r');
      expect(back.incoming, isTrue);
      expect(back.file, 'f');
      expect(back.lastSeen, 7);
      expect(back.local, isTrue);
      expect(back.saved, isTrue);
    });
  });

  group('DataUsageStore', () {
    setUp(DataUsageStore.instance.debugReset);

    test('tallies per kind, direction and network', () {
      final s = DataUsageStore.instance;
      s.record(UsageKind.photos, received: 100, net: NetKind.wifi);
      s.record(UsageKind.photos, received: 50, net: NetKind.cellular);
      s.record(UsageKind.calls, sent: 30, received: 20, net: NetKind.cellular);

      expect(s.tally(UsageKind.photos).received, 150);
      expect(s.tally(UsageKind.photos, net: NetKind.wifi).received, 100);
      expect(s.total(net: NetKind.cellular).total, 100);
      expect(s.total().sent, 30);
    });

    test('maps upload content types to kinds', () {
      expect(UsageKind.forUpload('image/jpeg'), UsageKind.photos);
      expect(UsageKind.forUpload('video/mp4'), UsageKind.videos);
      expect(UsageKind.forUpload('audio/m4a'), UsageKind.voice);
      expect(UsageKind.forUpload('application/pdf'), UsageKind.files);
    });
  });

  group('StorageService.pickForRemoval', () {
    final now = DateTime(2026, 10, 8);
    int daysAgo(int d) => now.subtract(Duration(days: d)).millisecondsSinceEpoch;

    StoredItem item(String id, int mb, int ageDays, {String? room = 'g'}) =>
        StoredItem.test(
          id: id,
          kind: StorageKind.videos,
          bytes: mb * _mb,
          lastSeen: daysAgo(ageDays),
          roomId: room,
        );

    ChatClass classOf(String room) => switch (room) {
          'p' => ChatClass.privateChats,
          'pub' => ChatClass.publicRooms,
          _ => ChatClass.groups,
        };

    test('removes what is past its chat kind\'s keep period', () {
      final prefs = DataStoragePrefs.defaults.copyWith(
        keepMedia: {ChatClass.groups: KeepMedia.week},
        cacheLimit: CacheLimit.unlimited,
      );
      final picked = StorageService.pickForRemoval(
        [item('old', 1, 10), item('new', 1, 2), item('private', 1, 400, room: 'p')],
        prefs: prefs,
        now: now,
        classOf: classOf,
        isKept: (_) => false,
      );
      expect(picked.map((i) => i.id), ['old']);
    });

    test('never touches a kept room', () {
      final prefs = DataStoragePrefs.defaults.copyWith(
        keepMedia: {ChatClass.privateChats: KeepMedia.day},
        cacheLimit: CacheLimit.unlimited,
      );
      final picked = StorageService.pickForRemoval(
        [item('saved', 1, 90, room: 'p')],
        prefs: prefs,
        now: now,
        classOf: classOf,
        isKept: (r) => r == 'p',
      );
      expect(picked, isEmpty);
    });

    test('trims the least recently seen until under the ceiling', () {
      final prefs = DataStoragePrefs.defaults.copyWith(
        keepMedia: const {},
        cacheLimit: CacheLimit.gb1,
      );
      final picked = StorageService.pickForRemoval(
        [item('a', 400, 30), item('b', 400, 20), item('c', 400, 1)],
        prefs: prefs,
        now: now,
        classOf: classOf,
        isKept: (_) => false,
      );
      // 1200 MB against a 1024 MB ceiling: dropping the oldest is enough.
      expect(picked.map((i) => i.id), ['a']);
    });
  });

  group('StorageService.scan on a real disk', () {
    late Directory tmp;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tmp = await Directory.systemTemp.createTemp('mh_storage_scan');
      // Every path_provider directory is the temp folder.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => tmp.path,
      );
    });

    tearDownAll(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    void write(String rel, int bytes) {
      final f = File('${tmp.path}/$rel')..createSync(recursive: true);
      f.writeAsBytesSync(List.filled(bytes, 7));
    }

    test('measures every store off-thread and files media by chat', () async {
      MediaLedger.instance.debugReset();
      write('mh_video_v1/vid1.mp4', 1000);
      write('mh_files_v1/doc1.pdf', 500);
      write('cache/u1/messages_r1.json', 200);
      // An outbox holds unsent messages: never counted, never cleared.
      write('cache/u1/outbox/outbox.json', 999);
      MediaLedger.instance.noteMessage(
          _msg('m1', MessageType.video, media: 'vid1'),
          incoming: true);

      // The real scan, through Isolate.run: a closure that captured
      // anything unsendable fails right here.
      final r = await StorageService.instance.scan();

      expect(r.byKind[StorageKind.videos], 1000);
      expect(r.byKind[StorageKind.files], 500);
      expect(r.byKind[StorageKind.chatHistory], 200);
      // The video, and the chat's history snapshot filed under it too.
      expect(r.byRoom['r1']!.byKind[StorageKind.videos], 1000);
      expect(r.byRoom['r1']!.byKind[StorageKind.chatHistory], 200);

      final freed = await StorageService.instance.clear({StorageKind.videos});
      expect(freed, 1000);
      expect(File('${tmp.path}/mh_video_v1/vid1.mp4').existsSync(), isFalse);
      expect(File('${tmp.path}/cache/u1/outbox/outbox.json').existsSync(), isTrue);
      await MediaLedger.instance.flush();
    });
  });
}
