// Settings search: the hub at rest (search field, Advanced) and mid-search.
//
//   flutter test test/design_preview/settings_search_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/screens/settings_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:monkeyhub/widgets/settings_search.dart';

import 'preview_kit.dart';

class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends Fake implements ChatRepository {}

class _FakeAuth extends ChangeNotifier implements AuthService {
  @override
  Session? get session =>
      Session(userId: 'me', username: 'murat', name: 'Murat Can');

  @override
  bool get isChild => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFamily extends ChangeNotifier implements FamilyService {
  @override
  int get pendingCount => 0;

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _hub() => Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => SettingsScreen(
          repo: _FakeRepo(),
          api: _FakeApi(),
          auth: _FakeAuth(),
          family: _FakeFamily(),
        ),
      ),
    );

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'MonkeyHub',
        packageName: 'x',
        version: '1.3.112',
        buildNumber: '1',
        buildSignature: '',
      ));

  for (final id in ['basic', 'basic_daylight']) {
    final theme = ThemeController.byId(id);
    for (final q in ['glass', 'debug', 'zzqx']) {
      testWidgets('settings search: $id $q', (tester) async {
        await snap(
          tester,
          previewApp(theme, _hub()),
          'search_${q}_$id.png',
          act: () async {
            await tester.enterText(
              find.descendant(
                of: find.byType(SettingsSearchField),
                matching: find.byType(TextField),
              ),
              q,
            );
          },
        );
      });
    }
    testWidgets('settings advanced: $id', (tester) async {
      await snap(
        tester,
        previewApp(theme, _hub()),
        'search_advanced_$id.png',
        size: const Size(393, 3400),
        dpr: 2,
      );
    });
  }
}
