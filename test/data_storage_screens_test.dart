import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/storage/storage_kinds.dart';
import 'package:monkeyhub/media/storage/storage_service.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/data_storage/auto_download_screen.dart';
import 'package:monkeyhub/screens/data_storage/data_storage_screen.dart';
import 'package:monkeyhub/screens/data_storage/data_usage_screen.dart';
import 'package:monkeyhub/screens/data_storage/save_to_photos_screen.dart';
import 'package:monkeyhub/screens/data_storage/storage_category_screen.dart';
import 'package:monkeyhub/screens/data_storage/storage_usage_screen.dart';
import 'package:monkeyhub/screens/data_storage/usage_widgets.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends ChangeNotifier implements ChatRepository {
  @override
  String? get userId => 'me';

  @override
  ChatRoom? roomById(String id) => ChatRoom(
        id: id,
        name: 'Room $id',
        createdBy: 'me',
        createdAt: DateTime(2026),
        isPrivate: true,
        memberCount: 2,
      );

  @override
  ChatUser? userById(String id) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _mb = 1024 * 1024;

/// A bare app: no wrapper supplying a text style, exactly like a route pushed
/// in the real app. Anything drawn outside the page's Scaffold shows up here
/// with Flutter's debug fallback style, yellow double underline included.
Widget _host(Widget child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

/// Every run of text on screen, with the style it actually paints in.
void _expectNoUnderlines(WidgetTester tester, String screen) {
  final bad = <String>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    void visit(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        final d = style?.decoration;
        if (d != null && d.contains(TextDecoration.underline)) {
          bad.add(span.text ?? '');
        }
        for (final c in span.children ?? const <InlineSpan>[]) {
          visit(c, style);
        }
      }
    }

    visit(rich.text, null);
  }
  expect(bad, isEmpty, reason: '$screen draws underlined text: $bad');
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    StorageService.instance.debugSetReport(StorageReport.debug(
      items: [
        StoredItem.test(
            id: 'v', kind: StorageKind.videos, bytes: 9 * _mb, lastSeen: 0, roomId: 'r'),
        StoredItem.test(
            id: 'f', kind: StorageKind.files, bytes: 2 * _mb, lastSeen: 0, roomId: 'r'),
      ],
      untracked: {StorageKind.other: _mb, StorageKind.companions: 300 * _mb},
    ));
  });

  final repo = _FakeRepo();
  final api = _FakeApi();
  final screens = <String, Widget>{
    'hub': DataStorageScreen(repo: repo, api: api),
    'storage': StorageUsageScreen(repo: repo, api: api),
    'usage': const DataUsageScreen(),
    'auto': const AutoDownloadScreen(net: NetKind.cellular),
    'rule': const MediaRuleScreen(net: NetKind.wifi, media: RuleMedia.videos),
    'save': const SaveToPhotosScreen(chat: ChatClass.groups),
    'category': StorageCategoryScreen(
        kind: StorageKind.videos, repo: repo, api: api),
  };

  for (final e in screens.entries) {
    testWidgets('${e.key} draws no underlined text', (tester) async {
      tester.view.physicalSize = const Size(393, 2400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(e.value));
      await tester.pump(const Duration(seconds: 1));
      _expectNoUnderlines(tester, e.key);
    });
  }

  testWidgets('an openable category row keeps the 52pt row height',
      (tester) async {
    await tester.pumpWidget(_host(Scaffold(
      body: Center(
        child: UsageCategoryRow(
          title: 'Videos',
          bytes: 9 * _mb,
          color: Colors.blue,
          checked: true,
          onToggle: () {},
          onOpen: () {},
        ),
      ),
    )));
    expect(tester.getSize(find.byType(UsageCategoryRow)).height, 52);
  });
}
