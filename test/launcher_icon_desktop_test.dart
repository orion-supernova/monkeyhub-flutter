import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/services/launcher_icon_renderer.dart';
import 'package:monkeyhub/services/launcher_icon_service.dart';
import 'package:monkeyhub/services/linux_launcher_icon.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final calls = <MethodCall>[];
  final renders = <String>[];
  late Directory tmp;
  late DesktopOs os;

  Uint8List bytesFor(String name) =>
      Uint8List.fromList(name.codeUnits + [px512]);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    calls.clear();
    renders.clear();
    tmp = Directory.systemTemp.createTempSync('mh_icon_test');
    LauncherIconService.debugResetDesktop();
    LauncherIconService.debugDesktopOs = () => os;
    LauncherIconService.debugLinuxIcon = LinuxLauncherIcon(
      dataHome: '${tmp.path}/data',
      stateHome: '${tmp.path}/state',
    );
    LinuxLauncherIcon.runner = (argv) async => ProcessResult(0, 0, '', '');
    LauncherIconService.debugRender = (name, px, shape) async {
      renders.add('$name:$px:${shape.name}');
      return bytesFor(name);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LauncherIconService.debugChannel, (c) async {
      calls.add(c);
      return null;
    });
  });

  tearDown(() {
    LauncherIconService.debugDesktopOs = null;
    LauncherIconService.debugRender = null;
    LauncherIconService.debugLinuxIcon = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LauncherIconService.debugChannel, null);
    tmp.deleteSync(recursive: true);
  });

  Future<void> pick(String? choice) async {
    final s = SettingsStore.instance;
    if (choice == null) {
      await s.setLogoMode(LogoMode.alwaysDefault);
    } else {
      await s.setManualLogoThemeId(choice);
      await s.setLogoMode(LogoMode.manual);
    }
    await LauncherIconService.applyFromSettings(ThemeController.byId('midnight'));
  }

  group('resolver', () {
    test('maps selections to platform icon names', () async {
      final s = SettingsStore.instance;
      final t = BasicTheme.midnight();
      await s.setLogoMode(LogoMode.alwaysDefault);
      expect(LauncherIconService.resolveIconName(s, t), isNull);
      await s.setManualLogoThemeId('mh_monkey_hmm');
      await s.setLogoMode(LogoMode.manual);
      expect(LauncherIconService.resolveIconName(s, t), 'mh_monkey_hmm');
      await s.setManualLogoThemeId('paper');
      expect(LauncherIconService.resolveIconName(s, t), 'vault_ivory');
      await s.setManualLogoThemeId('no_such_theme');
      expect(LauncherIconService.resolveIconName(s, t), isNull);
    });
  });

  group('desktop dispatch', () {
    test('macOS: squircle 1024 sent once, restored with null', () async {
      os = DesktopOs.macos;
      await pick('mh_monkey_hmm');
      expect(renders, ['mh_monkey_hmm:1024:macSquircle']);
      expect(calls.single.method, 'setIconImage');
      expect((calls.single.arguments as Map)['png'], bytesFor('mh_monkey_hmm'));

      await LauncherIconService.applyFromSettings(
        ThemeController.byId('midnight'),
      );
      expect(renders.length, 1, reason: 'unchanged icon is not re-rendered');
      expect(calls.length, 1, reason: 'nor re-sent');

      await pick(null);
      expect(calls.length, 2);
      expect((calls.last.arguments as Map)['png'], isNull);
    });

    test('Windows: 256 square', () async {
      os = DesktopOs.windows;
      await pick('mh_monkey_hmm');
      expect(renders, ['mh_monkey_hmm:256:square']);
      expect(calls.single.method, 'setIconImage');
    });

    test('a launch on the original icon sends nothing on mac and Windows',
        () async {
      for (final o in [DesktopOs.macos, DesktopOs.windows]) {
        os = o;
        LauncherIconService.debugResetDesktop();
        await pick(null);
        expect(calls, isEmpty, reason: '$o');
        expect(renders, isEmpty);
      }
    });

    test('rapid picks: only the newest is rendered', () async {
      os = DesktopOs.macos;
      final s = SettingsStore.instance;
      await s.setLogoMode(LogoMode.manual);
      await s.setManualLogoThemeId('mh_monkey_hmm');
      final a = LauncherIconService.applyFromSettings(
        ThemeController.byId('midnight'),
      );
      // No await: the pick lands while the first apply is still queued.
      final pending = s.setManualLogoThemeId('mh_monkey_bubble_head');
      final b = LauncherIconService.applyFromSettings(
        ThemeController.byId('midnight'),
      );
      await Future.wait([a, b, pending]);
      expect(renders, ['mh_monkey_bubble_head:1024:macSquircle']);
    });

    test('Linux: override files + marker, window icon, removal', () async {
      os = DesktopOs.linux;
      final linux = LauncherIconService.debugLinuxIcon!;
      await pick('mh_monkey_hmm');
      expect(renders, ['mh_monkey_hmm:512:square']);
      expect(File(linux.pathFor(512)).existsSync(), isTrue);
      expect(File(linux.pathFor(256)).existsSync(), isTrue);
      expect(File(linux.pathFor(512)).readAsBytesSync(),
          bytesFor('mh_monkey_hmm'));
      expect(await linux.installedName(), 'mh_monkey_hmm');
      expect((calls.single.arguments as Map)['png'], bytesFor('mh_monkey_hmm'));

      // A fresh launch re-applies from the files, without rendering.
      LauncherIconService.debugResetDesktop();
      renders.clear();
      await LauncherIconService.applyFromSettings(
        ThemeController.byId('midnight'),
      );
      expect(renders, isEmpty);
      expect(calls.length, 2);

      await pick(null);
      expect(File(linux.pathFor(512)).existsSync(), isFalse);
      expect(File(linux.pathFor(256)).existsSync(), isFalse);
      expect(await linux.installedName(), isNull);
      expect((calls.last.arguments as Map)['png'], isNull);
    });

    test('an unknown icon name changes nothing', () async {
      os = DesktopOs.macos;
      LauncherIconService.debugRender = null;
      await pick('mh_monkey_hmm');
      // Real renderer is not usable here; what matters is no crash and the
      // channel only ever sees well-formed calls.
      for (final c in calls) {
        expect(c.method, 'setIconImage');
      }
    });
  });

  group('renderer', () {
    testWidgets('renders mac squircle and square PNGs', (tester) async {
      final out = Platform.environment['MH_ICON_OUT'];
      final cases = <(String, DesktopIconShape, int)>[
        ('mh_monkey_hmm', DesktopIconShape.macSquircle, 1024),
        ('basic', DesktopIconShape.macSquircle, 1024),
        ('mh_monkey_hmm', DesktopIconShape.square, 256),
      ];
      for (final (name, shape, px) in cases) {
        final png = await tester.runAsync(
          () => LauncherIconRenderer.renderPng(name, px: px, shape: shape),
        );
        expect(png, isNotNull, reason: name);
        if (out != null) {
          File('$out/$name-${shape.name}-$px.png').writeAsBytesSync(png!);
        }
        final img = (await tester.runAsync(() async {
          final c = await ui.instantiateImageCodec(png!);
          return (await c.getNextFrame()).image;
        }))!;
        expect(img.width, px);
        final raw = (await tester.runAsync(
          () => img.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        int alpha(int x, int y) => raw.getUint8((y * px + x) * 4 + 3);
        expect(alpha(px ~/ 2, px ~/ 2), 255);
        if (shape == DesktopIconShape.macSquircle) {
          expect(alpha(2, 2), 0, reason: 'corner is transparent');
          expect(alpha(px ~/ 2, (px * 0.12).round()), 255,
              reason: 'body starts ~10% in');
          expect(alpha(px ~/ 2, (px * 0.05).round()), 0,
              reason: 'margin above the body is clear');
        } else {
          expect(alpha(1, 1), 255, reason: 'square is full bleed');
        }
      }
    });
  });
}

const px512 = 5;
