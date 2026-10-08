// Renders the Data and Storage pages under Midnight and Daylight. Not a
// test, run by path:
//
//   flutter test test/design_preview/data_storage_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/media/storage/data_usage_store.dart';
import 'package:monkeyhub/media/storage/storage_kinds.dart';
import 'package:monkeyhub/media/storage/storage_service.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/data_storage/auto_download_screen.dart';
import 'package:monkeyhub/screens/data_storage/data_storage_screen.dart';
import 'package:monkeyhub/screens/data_storage/data_usage_screen.dart';
import 'package:monkeyhub/screens/data_storage/storage_category_screen.dart';
import 'package:monkeyhub/screens/data_storage/storage_usage_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';

import 'preview_kit.dart';

class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends ChangeNotifier implements ChatRepository {
  final _rooms = {
    for (final (id, name) in [
      ('r1', 'Weekend Crew'),
      ('r2', 'Design Club'),
      ('r3', 'Book Swap'),
      ('r4', 'Running Buddies'),
    ])
      id: ChatRoom(
        id: id,
        name: name,
        createdBy: 'me',
        createdAt: DateTime(2026),
        isPrivate: true,
        memberCount: 4,
      ),
  };

  @override
  String? get userId => 'me';

  @override
  ChatRoom? roomById(String id) => _rooms[id];

  @override
  ChatUser? userById(String id) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _mb = 1024 * 1024;

void _seed() {
  var n = 0;
  StoredItem item(StorageKind k, double mb, String room) => StoredItem.test(
        id: 'i${n++}',
        kind: k,
        bytes: (mb * _mb).round(),
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        roomId: room,
      );
  StorageService.instance.debugSetReport(StorageReport.debug(
    items: [
      item(StorageKind.videos, 18.4, 'r1'),
      item(StorageKind.videos, 12.2, 'r2'),
      item(StorageKind.photos, 1.9, 'r1'),
      item(StorageKind.photos, 0.8, 'r3'),
      item(StorageKind.files, 8.9, 'r3'),
      item(StorageKind.files, 7.3, 'r4'),
      item(StorageKind.voice, 0.6, 'r2'),
      item(StorageKind.videoMessages, 3.1, 'r4'),
    ],
    untracked: {
      StorageKind.stickers: (2.4 * _mb).round(),
      StorageKind.chatHistory: (4.2 * _mb).round(),
      StorageKind.other: (1.1 * _mb).round(),
      StorageKind.companions: 1640 * _mb,
    },
    disk: (free: 64 * 1024 * _mb, total: 256 * 1024 * _mb),
  ));
  final u = DataUsageStore.instance;
  u.record(UsageKind.videos, received: 20 * 1024 * _mb, sent: 50 * _mb, net: NetKind.wifi);
  u.record(UsageKind.photos, received: 5800 * _mb, sent: 300 * _mb, net: NetKind.wifi);
  u.record(UsageKind.photos, received: 900 * _mb, net: NetKind.cellular);
  u.record(UsageKind.files, received: 2100 * _mb, net: NetKind.wifi);
  u.record(UsageKind.voice, received: 80 * _mb, sent: 20 * _mb, net: NetKind.cellular);
  u.record(UsageKind.calls, received: 1400 * _mb, sent: 1200 * _mb, net: NetKind.cellular);
  u.record(UsageKind.stickers, received: 310 * _mb, net: NetKind.wifi);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await loadPreviewFonts();
    _seed();
  });

  final repo = _FakeRepo();
  final api = _FakeApi();
  final themes = {
    'midnight': BasicTheme.midnight(),
    'daylight': BasicTheme.daylight(),
  };

  for (final t in themes.entries) {
    testWidgets('hub ${t.key}', (tester) async {
      await snap(tester, previewApp(t.value, DataStorageScreen(repo: repo, api: api)),
          'data_storage_hub_${t.key}.png');
    });
    testWidgets('storage ${t.key}', (tester) async {
      await snap(
          tester,
          previewApp(t.value, StorageUsageScreen(repo: repo, api: api)),
          'data_storage_storage_${t.key}.png',
          size: const Size(393, 1900));
    });
    testWidgets('usage ${t.key}', (tester) async {
      await snap(tester, previewApp(t.value, const DataUsageScreen()),
          'data_storage_usage_${t.key}.png',
          size: const Size(393, 1400));
    });
    testWidgets('category ${t.key}', (tester) async {
      await snap(
          tester,
          previewApp(t.value,
              StorageCategoryScreen(kind: StorageKind.files, repo: repo, api: api)),
          'data_storage_category_${t.key}.png');
    });
    testWidgets('auto ${t.key}', (tester) async {
      await snap(tester,
          previewApp(t.value, const AutoDownloadScreen(net: NetKind.cellular)),
          'data_storage_auto_${t.key}.png');
    });
  }
}
