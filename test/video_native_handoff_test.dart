@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/file_url_cache.dart';
import 'package:monkeyhub/media/native_video_player.dart';
import 'package:monkeyhub/media/video_file_cache.dart';
import 'package:monkeyhub/privacy/capture_protection.dart';
import 'package:monkeyhub/screens/fullscreen_video_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// What this pins: **capture protection does not cost the user the OS player.**
///
/// It used to. iOS has no FLAG_SECURE, and the Dart `CaptureShield` cannot cover
/// a UIKit controller presented above the engine, so the viewer declined the
/// handoff outright whenever protection was on. Two things followed, both
/// silent. A user who leaves the toggle enabled never reached the native player
/// at all — the whole point of the route. And the disk cache never filled,
/// because the download lives in `_source`, behind the handoff that was being
/// skipped, so every open re-streamed the video from scratch.
///
/// Neither symptom names its cause from the outside: "a custom player opened
/// and it buffers every time" looks like a missing feature, not a privacy
/// setting doing its job too well. So the decision is pinned here rather than
/// left to be re-derived from a device.
class _UrlApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async =>
      'https://example.test/$storageId';
}

void main() {
  const channel = MethodChannel('monkeyhub/video');
  const viewport = Size(400, 800);

  late Directory cacheDir;
  late List<MethodCall> presented;

  setUp(() {
    presented = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      presented.add(call);
      return true;
    });
    // The test VM is neither iOS nor Android, so without this every case here
    // would take the unsupported branch and pin nothing.
    NativeVideoPlayer.debugSupportedOverride = true;

    FileUrlCache.instance
      ..debugReset()
      ..debugPersist = false;
    cacheDir = Directory.systemTemp.createTempSync('mh_video_handoff_test');
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = cacheDir;
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    NativeVideoPlayer.debugSupportedOverride = null;
    await CaptureProtection.instance.setUserEnabled(false);
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = null;
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  /// Seeds a local copy so `_source` answers off the disk cache and the test
  /// never touches the network. Also the state a warm cache is actually in.
  void seedCached(String storageId) {
    File('${cacheDir.path}/$storageId.mp4').writeAsBytesSync(
      List<int>.filled(64, 0),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> openViewer(
    WidgetTester tester, {
    required String storageId,
  }) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        // AppLocalizations is what supplies the native shield's copy, so the
        // delegates are load-bearing here rather than boilerplate.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Above the navigator, not inside `home`: the viewer pushes onto the
        // ROOT navigator, so a scope nested under a route is not an ancestor of
        // the route it opens.
        builder: (_, child) => ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: child!,
        ),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    unawaited(
      FullscreenVideoViewer.open(ctx, storageId: storageId, api: _UrlApi()),
    );
    await settle(tester);
  }

  testWidgets('capture protection still gets the OS player, shielded', (
    tester,
  ) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await CaptureProtection.instance.setUserEnabled(true);
    seedCached('guarded_1');
    await openViewer(tester, storageId: 'guarded_1');

    expect(
      presented,
      hasLength(1),
      reason: 'protection must not send the video back to the Flutter player',
    );
    final args = presented.single.arguments as Map;
    expect(args['secure'], isTrue);
    expect(
      args['url'],
      startsWith('file://'),
      reason: 'the cached copy plays, so the OS player never re-downloads',
    );
    // The copy is passed down because Swift cannot reach the app's twelve
    // localizations. Empty strings would render a shield with no explanation.
    expect(args['shieldTitle'], isNotEmpty);
    expect(args['shieldBody'], isNotEmpty);
  });

  testWidgets('an unprotected video hands off without asking for a shield', (
    tester,
  ) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    seedCached('plain_1');
    await openViewer(tester, storageId: 'plain_1');

    expect(presented, hasLength(1));
    expect((presented.single.arguments as Map)['secure'], isFalse);
  });
}
