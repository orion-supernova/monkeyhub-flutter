// WP5: Linked devices, Signal-style. Devices screen (0 and 2 devices), the
// scan screen (camera swapped for a dark stand-in: MobileScanner cannot run
// in tests), the expanded code entry, the "Finish linking" sheet, the success
// HUD, and the new-device QR panel. Dark and light.
//
//   flutter test test/design_preview/devices_flow_preview.dart
//
// PNGs: build/design_preview/wp5_<shot>_<theme>.png
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart' show Subscription;
import 'package:monkeyhub/models/user_device.dart';
import 'package:monkeyhub/screens/device_login_scan_screen.dart';
import 'package:monkeyhub/screens/devices_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/device_login_panel.dart';
import 'package:monkeyhub/widgets/glass_hud.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

final _now = DateTime.now();

class _Sub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _Api extends Fake implements ChatApi {
  _Api(this.devices);
  final List<UserDevice> devices;

  @override
  Future<List<UserDevice>> listDevices({
    required String userId,
    required String deviceId,
  }) async => devices;

  @override
  Future<String> peekDeviceLoginRequest({
    required String callerId,
    String? requestId,
    String? code,
  }) async => 'Chrome on macOS';

  @override
  Future<DeviceLoginRequest> createDeviceLoginRequest({
    required String deviceInfo,
  }) async => DeviceLoginRequest(
    requestId: 'a' * 32,
    code: '482913',
    expiresAt: DateTime.now().add(const Duration(minutes: 4, seconds: 32)),
  );

  @override
  Future<Subscription> subscribeDeviceLoginStatus({
    required String requestId,
    required void Function(String status) onStatus,
    void Function(Object error)? onError,
  }) async => _Sub();
}

class _Auth extends ChangeNotifier implements AuthService {
  _Auth(this._api);
  final ChatApi _api;
  @override
  ChatApi get api => _api;
  @override
  Session? get session => Session(userId: 'me', username: 'murat', name: 'Murat');
  @override
  bool get isChild => false;
  @override
  bool get isSignedIn => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _two = [
  UserDevice(
    deviceId: 'a',
    platform: 'ios',
    deviceName: "Murat's iPhone 16 Pro",
    lastSeenAt: _now,
    createdAt: _now.subtract(const Duration(days: 60)),
    isThis: true,
    reachable: true,
  ),
  UserDevice(
    deviceId: 'b',
    platform: 'macos',
    deviceName: 'MacBook Pro',
    lastSeenAt: _now.subtract(const Duration(hours: 3)),
    createdAt: _now.subtract(const Duration(days: 9)),
    isThis: false,
    reachable: true,
  ),
];

/// Stand-in for the camera: a dim scene with a faint code-like block.
Widget _fakeCamera(BuildContext context, void Function(dynamic) onDetect) =>
    DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1D24), Color(0xFF0B0C10)],
        ),
      ),
      child: Center(
        child: Container(
          width: 170,
          height: 170,
          margin: const EdgeInsets.only(bottom: 140),
          decoration: BoxDecoration(
            color: const Color(0xFFD9DCE3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: GridView.count(
            crossAxisCount: 13,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            children: [
              for (var i = 0; i < 169; i++)
                ColoredBox(
                  color: (i * 7 + i ~/ 13 * 3) % 5 < 2
                      ? Colors.black
                      : Colors.transparent,
                ),
            ],
          ),
        ),
      ),
    );

class _After extends StatefulWidget {
  const _After({required this.child, required this.onReady});
  final Widget child;
  final void Function(BuildContext) onReady;
  @override
  State<_After> createState() => _AfterState();
}

class _AfterState extends State<_After> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget scan(_Auth auth, {bool code = false, String? seeded}) =>
      DeviceLoginScanScreen(
        auth: auth,
        cameraSupported: true,
        startWithCode: code,
        initialRequestId: seeded,
        cameraBuilder: (c, on) => _fakeCamera(c, (_) {}),
      );

  for (final id in ['basic', 'basic_daylight']) {
    final theme = ThemeController.byId(id);
    Future<void> shot(
      WidgetTester tester,
      String name,
      Widget screen, {
      Duration settle = const Duration(milliseconds: 1500),
      bool frames = false,
    }) => snap(
      tester,
      previewApp(theme, screen),
      'wp5_${name}_$id.png',
      dpr: 2,
      settle: settle,
      // Frame by frame: a route pushed after the first frame needs them.
      act: frames ? () async {} : null,
    );

    testWidgets('devices 0 $id', (tester) async {
      final api = _Api(const []);
      await shot(tester, 'devices_0', DevicesScreen(auth: _Auth(api), api: api));
    });
    testWidgets('devices 2 $id', (tester) async {
      final api = _Api(_two);
      await shot(tester, 'devices_2', DevicesScreen(auth: _Auth(api), api: api));
    });
    testWidgets('scan $id', (tester) async {
      await shot(tester, 'scan', scan(_Auth(_Api(const []))));
    });
    testWidgets('code $id', (tester) async {
      await shot(tester, 'scan_code', scan(_Auth(_Api(const [])), code: true));
    });
    testWidgets('finish $id', (tester) async {
      await shot(
        tester,
        'finish',
        scan(_Auth(_Api(const [])), seeded: 'c' * 32),
        settle: const Duration(milliseconds: 2200),
        frames: true,
      );
    });
    testWidgets('hud $id', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          _After(
            onReady: (ctx) => showGlassHud(
              ctx,
              icon: CupertinoIcons.checkmark_alt,
              success: true,
              label: 'Linked',
              duration: const Duration(seconds: 30),
            ),
            child: scan(_Auth(_Api(const []))),
          ),
        ),
        'wp5_hud_$id.png',
        dpr: 2,
        settle: const Duration(milliseconds: 1000),
        act: () async {},
      );
      // Let the HUD's own timer run out before the test ends.
      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));
    });
    testWidgets('panel $id', (tester) async {
      final api = _Api(const []);
      await shot(
        tester,
        'panel',
        Scaffold(
          backgroundColor: theme.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
              child: DeviceLoginPanel(auth: _Auth(api), onCancel: () {}),
            ),
          ),
        ),
      );
    });
  }
}
