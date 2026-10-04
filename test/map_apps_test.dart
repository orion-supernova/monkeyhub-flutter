import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/map_apps_screen.dart';
import 'package:monkeyhub/services/maps_handoff.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/map_app_picker.dart';

class _Launcher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;
  Set<String> installed = {'maps', 'comgooglemaps', 'yandexmaps'};
  Set<String> failed = {};
  final launched = <Uri>[];
  final modes = <PreferredLaunchMode>[];
  @override
  Future<bool> canLaunch(String url) async =>
      installed.contains(Uri.parse(url).scheme);
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    final uri = Uri.parse(url);
    launched.add(uri);
    modes.add(options.mode);
    return !failed.contains(uri.scheme);
  }
}

Widget _host(Widget child) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: LayoutScope(
      windowClass: WindowClass.compact,
      width: 390,
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Launcher launcher;
  late UrlLauncherPlatform oldLauncher;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    oldLauncher = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    FlutterSecureStorage.setMockInitialValues({});
    await SettingsStore.instance.setMapApp(null, null);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    UrlLauncherPlatform.instance = oldLauncher;
  });

  test('iOS offers each installed maps app and a browser fallback', () async {
    expect((await MapsHandoff.availableApps()).map((app) => app.id), [
      'apple',
      'google',
      'yandex',
      'browser',
    ]);
    expect(launcher.launched, isEmpty);
  });

  test('app links preserve coordinates and Yandex longitude order', () {
    final yandex = MapsHandoff.appUri(
      'yandex',
      latitude: 41.0138,
      longitude: 28.9497,
    );
    expect(yandex.queryParameters['ll'], '28.949700,41.013800');
    expect(yandex.queryParameters['pt'], '28.949700,41.013800');
    final apple = MapsHandoff.appUri(
      'apple',
      latitude: 41.0138,
      longitude: 28.9497,
      label: 'A & B',
    );
    expect(apple.toString(), startsWith('maps://'));
    expect(apple.queryParameters['q'], 'A & B');
    expect(apple.queryParameters['ll'], '41.013800,28.949700');
  });

  test('invalid coordinates never launch an external app', () async {
    expect(
      await MapsHandoff.launch(
        MapsHandoff.browser,
        latitude: double.nan,
        longitude: 0,
      ),
      isFalse,
    );
    expect(
      await MapsHandoff.launch(MapsHandoff.browser, latitude: 91, longitude: 0),
      isFalse,
    );
    expect(launcher.launched, isEmpty);
  });

  test(
    'rapid default changes persist the last app and its name together',
    () async {
      final store = SettingsStore.instance;
      await Future.wait([
        store.setMapApp('apple', 'Apple Maps'),
        store.setMapApp('google', 'Google Maps'),
        store.setMapApp('yandex', 'Yandex Maps'),
      ]);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'mh.maps.app'), 'yandex');
      expect(await storage.read(key: 'mh.maps.name'), 'Yandex Maps');
    },
  );

  test('Android discovery and selection target the selected package', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('monkeyhub/maps');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'available') {
            return [
              {'id': 'com.google.android.apps.maps', 'name': 'Maps'},
              {'id': 'ru.yandex.yandexmaps', 'name': 'Yandex Maps'},
            ];
          }
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final apps = await MapsHandoff.availableApps();
    expect(apps.map((app) => app.id), [
      'android:com.google.android.apps.maps',
      'android:ru.yandex.yandexmaps',
      'browser',
    ]);
    expect(
      await MapsHandoff.launch(apps[1], latitude: 41, longitude: 29),
      isTrue,
    );
    expect(calls.last.arguments['id'], 'ru.yandex.yandexmaps');
    expect(calls.last.arguments['latitude'], 41);
  });

  Future<Future<MapOpenResult> Function()> mount(
    WidgetTester tester, {
    void Function(MapOpenResult)? result,
  }) async {
    late BuildContext context;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return () async {
      final opened = await openMapLocation(
        context,
        latitude: 41.0138,
        longitude: 28.9497,
        label: 'Shared pin',
      );
      result?.call(opened);
      return opened;
    };
  }

  testWidgets('first opening lets users choose without remembering', (
    tester,
  ) async {
    final open = await mount(tester);
    MapOpenResult? result;
    open().then((value) => result = value);
    await tester.pumpAndSettle();
    expect(find.text('Open location in'), findsOneWidget);
    expect(find.text('Apple Maps'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Yandex Maps'), findsOneWidget);
    await tester.tap(find.text('Yandex Maps'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(launcher.launched, isNotEmpty);
    expect(result, MapOpenResult.opened);
    expect(launcher.launched.single.scheme, 'yandexmaps');
    expect(launcher.modes.single, PreferredLaunchMode.externalApplication);
    expect(SettingsStore.instance.mapAppId, isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'remembered app opens directly and settings can restore ask every time',
    (tester) async {
      final open = await mount(tester);
      final completion = open();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google Maps'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(launcher.launched, isNotEmpty);
      expect(
        await tester.runAsync(
          () => completion.timeout(const Duration(seconds: 2)),
        ),
        MapOpenResult.opened,
      );
      expect(SettingsStore.instance.mapAppId, 'google');
      expect(
        (await const FlutterSecureStorage().read(key: 'mh.maps.app')),
        'google',
      );
      await open();
      await tester.pumpAndSettle();
      expect(launcher.launched.length, 2);
      await tester.pumpWidget(_host(const MapAppsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask every time'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => SettingsStore.instance.setMapApp(null, null));
      expect(SettingsStore.instance.mapAppId, isNull);
      expect(
        (await const FlutterSecureStorage().read(key: 'mh.maps.app')),
        isNull,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'removed default offers chooser and cancellation does not launch',
    (tester) async {
      await SettingsStore.instance.setMapApp('waze', 'Waze');
      final open = await mount(tester);
      MapOpenResult? result;
      open().then((value) => result = value);
      await tester.pumpAndSettle();
      expect(
        find.text('Your default maps app is unavailable. Choose another.'),
        findsOneWidget,
      );
      // Dismiss the route as a swipe-back/close would.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(result, MapOpenResult.cancelled);
      debugDefaultTargetPlatformOverride = null;
      expect(launcher.launched, isEmpty);
    },
  );

  testWidgets(
    'failed launch offers remaining apps and never remembers failure',
    (tester) async {
      launcher.failed.add('yandexmaps');
      final open = await mount(tester);
      MapOpenResult? result;
      open().then((value) => result = value);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.tap(find.text('Yandex Maps'));
      await tester.pumpAndSettle();
      expect(find.text('Yandex Maps'), findsNothing);
      expect(SettingsStore.instance.mapAppId, isNull);
      await tester.tap(find.text('Apple Maps'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(launcher.launched, isNotEmpty);
      expect(result, MapOpenResult.opened);
      expect(launcher.launched.map((uri) => uri.scheme), [
        'yandexmaps',
        'maps',
      ]);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
