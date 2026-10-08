import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/file_url_cache.dart';
import 'package:monkeyhub/media/native_gallery.dart';
import 'package:monkeyhub/media/native_video_player.dart';
import 'package:monkeyhub/media/video_file_cache.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// What this pins: **closing the native gallery is ONE close.**
///
/// A video played from the Flutter media pager opens the OS gallery, which
/// swipes through the same set. If the pager stays underneath, closing the OS
/// player lands back on it and the user has to close a second time, which is
/// what shipped first. The pager has to be gone the moment the OS gallery is
/// up, whatever order the routes above it pop in.
class _UrlApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async =>
      'https://example.test/$storageId';
}

void main() {
  const channel = MethodChannel('monkeyhub/video');
  late Directory cacheDir;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    NativeVideoPlayer.debugSupportedOverride = true;
    nativeGalleryImageStat = (_) async => null;
    FileUrlCache.instance
      ..debugReset()
      ..debugPersist = false;
    cacheDir = Directory.systemTemp.createTempSync('mh_pager_native_test');
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = cacheDir;
    // The tapped video is already on disk, so the viewer resolves it with no
    // network and hands off at once.
    File('${cacheDir.path}/stor_v1.mp4').writeAsBytesSync(List.filled(64, 0));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    NativeVideoPlayer.debugSupportedOverride = null;
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = null;
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  ChatMessage msg(String id, MessageType type) => ChatMessage(
        id: id,
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12),
        type: type,
        mediaStorageId: 'stor_$id',
        mediaWidth: 900,
        mediaHeight: 1600,
      );

  testWidgets('playing a video from the pager leaves no pager behind',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.expand();
        }),
      ),
    ));

    MediaPagerScreen.open(
      ctx,
      // Two posterless videos: the pages draw a film glyph, not an image, so
      // nothing reaches the image cache (which needs path_provider).
      items: [msg('v0', MessageType.video), msg('v1', MessageType.video)],
      initialIndex: 1,
      api: _UrlApi(),
    );
    // Fixed pumps, not pumpAndSettle: the pager's image shimmer never settles.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(MediaPagerScreen), findsOneWidget);

    // Play: a tap on the video page.
    await tester.tapAt(const Offset(195, 422));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(calls.map((c) => c.method), ['presentGallery']);
    expect(find.byType(MediaPagerScreen), findsNothing,
        reason: 'the pager must step aside, or closing the OS player lands '
            'on it and needs a second close');
  });
}
