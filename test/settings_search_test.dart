import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/glass_screen.dart';
import 'package:monkeyhub/screens/settings_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/settings_search.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends Fake implements ChatRepository {}

class _FakeAuth extends ChangeNotifier implements AuthService {
  _FakeAuth({this.child = false});
  final bool child;

  @override
  Session? get session =>
      Session(userId: 'me', username: 'murat', name: 'Murat Can');

  @override
  bool get isChild => child;

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

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'MonkeyHub',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> pump(WidgetTester tester, {bool child = false, Locale? locale}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          repo: _FakeRepo(),
          api: _FakeApi(),
          auth: _FakeAuth(child: child),
          family: _FakeFamily(),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(SettingsSearchField),
        matching: find.byType(TextField),
      ),
      q,
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  Finder results() => find.byType(SettingsSearchResults);

  testWidgets('"glass" finds Glass, and tapping it opens the page',
      (tester) async {
    await pump(tester);
    await search(tester, 'glass');
    final hit = find.descendant(of: results(), matching: find.text(en.settingsHubGlass));
    expect(hit, findsOneWidget);
    expect(
      find.descendant(
        of: results(),
        matching: find.text('${en.settingsHubSectionAppearance} › ${en.settingsHubGlass}'),
      ),
      findsOneWidget,
      reason: 'the breadcrumb says where it lives',
    );
    await tester.tap(hit);
    await tester.pumpAndSettle();
    expect(find.byType(GlassScreen), findsOneWidget);
  });

  testWidgets('a keyword finds a setting its title never mentions',
      (tester) async {
    await pump(tester);
    await search(tester, 'debug');
    expect(
      find.descendant(of: results(), matching: find.text(en.settingsHubDiagnostics)),
      findsOneWidget,
    );
    await search(tester, 'dark');
    expect(
      find.descendant(of: results(), matching: find.text(en.settingsHubTheme)),
      findsOneWidget,
    );
  });

  testWidgets('English terms work in any language', (tester) async {
    final tr = lookupAppLocalizations(const Locale('tr'));
    await pump(tester, locale: const Locale('tr'));
    await search(tester, 'blur');
    expect(
      find.descendant(of: results(), matching: find.text(tr.settingsHubGlass)),
      findsOneWidget,
    );
  });

  testWidgets('a found switch works right in the results', (tester) async {
    await pump(tester);
    final before = SettingsStore.instance.showNetworkStats;
    await search(tester, 'ping');
    final row = find.descendant(
      of: results(),
      matching: find.text(en.settingsHubCallStats),
    );
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pump();
    expect(SettingsStore.instance.showNetworkStats, !before);
    SettingsStore.instance.setShowNetworkStats(before);
  });

  testWidgets('a child account finds nothing the hub hides from it',
      (tester) async {
    await pump(tester, child: true);
    await search(tester, 'server');
    expect(
      find.descendant(of: results(), matching: find.text(en.settingsHubServer)),
      findsNothing,
    );
    await search(tester, 'devices');
    expect(
      find.descendant(of: results(), matching: find.text(en.acctRowDevices)),
      findsNothing,
    );
  });

  testWidgets('nothing matches → a quiet empty state', (tester) async {
    await pump(tester);
    await search(tester, 'zzqx');
    expect(find.text(en.settingsSearchNoResults('zzqx')), findsOneWidget);
  });
}
