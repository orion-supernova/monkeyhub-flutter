import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/device_login_link.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/device_login_scan_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/code_field.dart';
import 'package:monkeyhub/widgets/scan_frame_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends Fake implements ChatApi {
  final List<String> peeked = [];
  final List<bool> responses = [];
  bool failRespond = false;

  @override
  Future<String> peekDeviceLoginRequest({
    required String callerId,
    String? requestId,
    String? code,
  }) async {
    peeked.add(requestId ?? code ?? '');
    return 'Chrome on macOS';
  }

  @override
  Future<void> respondToDeviceLoginRequest({
    required String callerId,
    required bool approve,
    String? requestId,
    String? code,
  }) async {
    if (failRespond) throw StateError('boom');
    responses.add(approve);
  }
}

class _Auth extends AuthService {
  _Auth(this.fake) : super(ChatApi(ConvexBackend.instance));
  final _Api fake;

  @override
  ChatApi get api => fake;

  @override
  Session? get session => Session(userId: 'u1', username: 'm', name: 'M');

  @override
  bool get isChild => false;
}

class _Mem extends FlutterSecureStoragePlatform {
  final Map<String, String> items = {};
  @override
  Future<String?> read({required String key, required Map<String, String> options}) async => items[key];
  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async => items[key] = value;
  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async => items.containsKey(key);
  @override
  Future<void> delete({required String key, required Map<String, String> options}) async => items.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async => items.clear();
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => items;
}

/// The viewfinder breathes forever, so `pumpAndSettle` never returns on a
/// camera screen: advance a fixed span instead.
Future<void> settle(WidgetTester tester, [int steps = 20]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = _Mem();
  });

  void Function(BarcodeCapture)? detect;
  Widget camera(BuildContext c, void Function(BarcodeCapture) on) {
    detect = on;
    return const ColoredBox(color: Colors.black);
  }

  Widget host(_Api api, {bool? cameraSupported, bool withCamera = true}) =>
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DeviceLoginScanScreen(
                        auth: _Auth(api),
                        cameraSupported: cameraSupported,
                        cameraBuilder: withCamera ? camera : null,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<AppLocalizations> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await settle(tester);
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('no camera: the code field is the whole screen', (tester) async {
    await tester.pumpWidget(host(_Api(), cameraSupported: false, withCamera: false));
    final l10n = await open(tester);

    expect(find.byType(CodeField), findsOneWidget);
    expect(find.byType(ScanFrameOverlay), findsNothing);
    expect(find.text(l10n.deviceLinkEnterCodeInstead), findsNothing);
    expect(find.text(l10n.deviceLinkScanInstead), findsNothing);
  });

  testWidgets('camera: card explains, then expands into the code field', (tester) async {
    await tester.pumpWidget(host(_Api(), cameraSupported: true));
    final l10n = await open(tester);

    expect(find.byType(ScanFrameOverlay), findsOneWidget);
    expect(find.text(l10n.deviceLinkScanInstruction), findsOneWidget);
    expect(find.byType(CodeField), findsNothing);

    await tester.tap(find.text(l10n.deviceLinkEnterCodeInstead));
    await settle(tester, 20);
    expect(find.byType(CodeField), findsOneWidget);

    await tester.tap(find.text(l10n.deviceLinkScanInstead));
    await settle(tester, 20);
    expect(find.byType(CodeField), findsNothing);
    expect(find.text(l10n.deviceLinkScanInstruction), findsOneWidget);
  });

  testWidgets('a scanned code opens Finish linking; approve links and pops back', (tester) async {
    final api = _Api();
    await tester.pumpWidget(host(api, cameraSupported: true));
    final l10n = await open(tester);

    detect!(BarcodeCapture(barcodes: [
      Barcode(rawValue: deviceLoginUri('a' * 32)),
    ]));
    await tester.pump();
    // The viewfinder snaps shut on the hit.
    expect(
      tester.widget<ScanFrameOverlay>(find.byType(ScanFrameOverlay)).detected,
      isTrue,
    );
    await settle(tester);

    expect(api.peeked, ['a' * 32]);
    expect(find.text(l10n.deviceLinkFinishTitle), findsOneWidget);
    expect(find.text('Chrome on macOS'), findsWidgets);
    expect(api.responses, isEmpty); // never approves by itself

    await tester.tap(find.text(l10n.deviceLoginScanScreenApproveButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(api.responses, [true]);
    // The HUD plays first (1.2s), then the toast.
    var seen = false;
    for (var i = 0; i < 80 && !seen; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      seen = find.text(l10n.deviceLinkLinkedToast).evaluate().isNotEmpty;
    }
    await settle(tester, 12);
    expect(find.byType(DeviceLoginScanScreen), findsNothing);
    expect(seen, isTrue);
  });

  testWidgets('deny answers the request and leaves', (tester) async {
    final api = _Api();
    await tester.pumpWidget(host(api, cameraSupported: false, withCamera: false));
    final l10n = await open(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await settle(tester);
    expect(api.peeked, ['123456']);

    await tester.tap(find.text(l10n.deviceLoginScanScreenDenyButton));
    await settle(tester, 60);
    expect(api.responses, [false]);
    expect(find.byType(DeviceLoginScanScreen), findsNothing);
  });

  testWidgets('dismissing the sheet answers nothing and resumes scanning', (tester) async {
    final api = _Api();
    await tester.pumpWidget(host(api, cameraSupported: true));
    await open(tester);

    detect!(BarcodeCapture(barcodes: [
      Barcode(rawValue: deviceLoginUri('b' * 32)),
    ]));
    await settle(tester);
    await tester.tapAt(const Offset(200, 40)); // scrim
    await settle(tester);

    expect(api.responses, isEmpty);
    expect(find.byType(DeviceLoginScanScreen), findsOneWidget);
    expect(
      tester.widget<ScanFrameOverlay>(find.byType(ScanFrameOverlay)).detected,
      isFalse,
    );
  });

  testWidgets('a failed approval keeps the sheet and says so', (tester) async {
    final api = _Api()..failRespond = true;
    await tester.pumpWidget(host(api, cameraSupported: false, withCamera: false));
    final l10n = await open(tester);

    await tester.enterText(find.byType(TextField), '654321');
    await settle(tester);
    await tester.tap(find.text(l10n.deviceLoginScanScreenApproveButton));
    await settle(tester, 60);

    expect(find.text(l10n.deviceLinkFinishTitle), findsOneWidget);
    expect(find.text(l10n.deviceLoginScanScreenGenericError), findsWidgets);
  });
}
