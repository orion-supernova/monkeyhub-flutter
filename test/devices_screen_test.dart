import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/user_device.dart';
import 'package:monkeyhub/screens/devices_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins, above everything else: the screen never offers to remove
/// the device you are holding, and its copy matches what removal actually does.
///
/// The second one is not cosmetic, and it has now flipped once. While the
/// backend had no sessions, Remove stopped notifications and nothing else, and
/// the copy had to say so — a button reading "sign out" would have sent
/// somebody checking on a stolen phone away reassured about something that did
/// not happen. Sessions landed, `clearDeviceToken` revokes one, and the copy
/// now promises the sign-out because it can keep that promise. Whichever way
/// it points, the wording is a test rather than a preference: this screen is
/// read by people making a security decision.
class _MemStore extends FlutterSecureStoragePlatform {
  final Map<String, String> items = {};
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => items[key];
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => items[key] = value;
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => items.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => items.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      items.clear();
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => items;
}

class _FakeApi extends Fake implements ChatApi {
  _FakeApi(this.devices);

  List<UserDevice> devices;
  final List<String> removed = [];
  int removeOthersCalls = 0;

  @override
  Future<List<UserDevice>> listDevices({
    required String userId,
    required String deviceId,
  }) async => devices;

  @override
  Future<void> clearDeviceToken({
    required String userId,
    required String deviceId,
  }) async {
    removed.add(deviceId);
    devices = devices.where((d) => d.deviceId != deviceId).toList();
  }

  @override
  Future<int> removeOtherDevices({
    required String userId,
    required String deviceId,
  }) async {
    removeOthersCalls++;
    final gone = devices.where((d) => !d.isThis).length;
    devices = devices.where((d) => d.isThis).toList();
    return gone;
  }
}

class _StubAuth extends AuthService {
  _StubAuth() : super(ChatApi(ConvexBackend.instance));

  @override
  Session? get session =>
      Session(userId: 'u1', username: 'murat', name: 'Murat');

  @override
  bool get isChild => false;
}

UserDevice _device({
  required String id,
  required String platform,
  String? name,
  bool isThis = false,
  bool reachable = true,
  Duration seenAgo = Duration.zero,
}) => UserDevice(
  deviceId: id,
  platform: platform,
  deviceName: name,
  lastSeenAt: DateTime.now().subtract(seenAgo),
  createdAt: DateTime.now().subtract(const Duration(days: 30)),
  isThis: isThis,
  reachable: reachable,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = _MemStore();
  });

  Widget host(ChatApi api) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DevicesScreen(auth: _StubAuth(), api: api),
    ),
  );

  final fleet = [
    _device(
      id: 'a',
      platform: 'macos',
      name: "Murat's MacBook Air",
      isThis: true,
    ),
    _device(
      id: 'b',
      platform: 'ios',
      name: 'iPhone 15 Pro',
      seenAgo: const Duration(hours: 2),
    ),
    _device(
      id: 'c',
      platform: 'web',
      seenAgo: const Duration(days: 3),
      reachable: false,
    ),
  ];

  testWidgets('lists every device and names them', (tester) async {
    await tester.pumpWidget(host(_FakeApi([...fleet])));
    await tester.pumpAndSettle();

    expect(find.text("Murat's MacBook Air"), findsOneWidget);
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
    // No deviceName on the web row — the friendly platform label stands in
    // rather than a UUID, which would identify nothing to a reader.
    expect(find.text('Browser'), findsOneWidget);
  });

  testWidgets('marks this device and refuses to offer removing it', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeApi([...fleet])));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.textContaining(l10n.acctThisDevice), findsOneWidget);
    // Two others, so two Remove controls — never three.
    expect(find.text(l10n.acctRemove), findsNWidgets(2));
  });

  testWidgets('says so when a device cannot be reached', (tester) async {
    await tester.pumpWidget(host(_FakeApi([...fleet])));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.textContaining(l10n.acctNoNotifications), findsOneWidget);
  });

  testWidgets('the copy promises the sign-out that now actually happens', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeApi([...fleet])));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.devicesScreenFootnote), findsOneWidget);

    // `clearDeviceToken` revokes the device's session, so all three of these
    // have to say so. If someone weakens the backend back to a push-only
    // removal, this is the test that should stop them shipping copy that
    // overpromises to a person checking on a stolen phone.
    expect(l10n.devicesScreenFootnote.toLowerCase(), contains('signs it out'));
    expect(
      l10n.devicesScreenRemoveBody('iPhone').toLowerCase(),
      contains('signed out'),
    );
    expect(
      l10n.devicesScreenRemoveAllBody.toLowerCase(),
      contains('signed out'),
    );

    // And the old understatement is gone from every one of them.
    for (final copy in [
      l10n.devicesScreenFootnote,
      l10n.devicesScreenRemoveBody('iPhone'),
      l10n.devicesScreenRemoveAllBody,
    ]) {
      expect(copy.toLowerCase(), isNot(contains("won't be signed out")));
      expect(copy.toLowerCase(), isNot(contains('doesn\'t sign')));
    }
  });

  testWidgets('remove-all is hidden when this is the only device', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(_FakeApi([_device(id: 'a', platform: 'macos', isThis: true)])),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.devicesScreenRemoveAll), findsNothing);
    expect(find.text(l10n.acctRemove), findsNothing);
  });

  testWidgets('removing one device asks first, then drops just that row', (
    tester,
  ) async {
    final api = _FakeApi([...fleet]);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.acctRemove).first);
    await tester.pumpAndSettle();

    // The confirm sheet, not a silent deletion.
    expect(find.text(l10n.acctRemoveDeviceTitle), findsOneWidget);
    expect(api.removed, isEmpty);

    await tester.tap(find.text(l10n.acctRemove).last);
    await tester.pumpAndSettle();

    expect(api.removed, ['b']);
    expect(find.text('iPhone 15 Pro'), findsNothing);
    expect(find.text("Murat's MacBook Air"), findsOneWidget);
  });

  testWidgets('backing out of the confirm sheet removes nothing', (
    tester,
  ) async {
    final api = _FakeApi([...fleet]);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.acctRemove).first);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(DevicesScreen))).maybePop();
    await tester.pumpAndSettle();

    expect(api.removed, isEmpty);
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
  });

  testWidgets('remove-all sweeps the others and keeps this one', (
    tester,
  ) async {
    final api = _FakeApi([...fleet]);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.devicesScreenRemoveAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.acctRemoveAll).last);
    await tester.pumpAndSettle();

    expect(api.removeOthersCalls, 1);
    expect(find.text("Murat's MacBook Air"), findsOneWidget);
    expect(find.text('iPhone 15 Pro'), findsNothing);
    expect(find.text('Browser'), findsNothing);
  });
}
