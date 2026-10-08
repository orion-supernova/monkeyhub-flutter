import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/file_url_cache.dart';
import 'package:monkeyhub/media/native_video_player.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/video_message.dart' show VideoPlayerSurface;

/// What this pins: **a video in the gallery plays in the gallery.**
///
/// A video tapped in a grid used to skip the pager for the OS player, while
/// one swiped onto showed a poster in the pager's chrome: the same clip was
/// two different screens. Now the current page plays in place, inside the
/// pager, and only the current page ever holds a player.
class _GoneApi extends Fake implements ChatApi {
  // No URL: the surface settles on "unavailable" at once, with no player
  // plugin and no timer left behind.
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

void main() {
  const channel = MethodChannel('monkeyhub/video');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    NativeVideoPlayer.debugSupportedOverride = true;
    FileUrlCache.instance
      ..debugReset()
      ..debugPersist = false;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    NativeVideoPlayer.debugSupportedOverride = null;
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

  testWidgets('the current video plays in place; swiping away stops it',
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
      // Posterless videos: the pages draw a film glyph, not an image, so
      // nothing reaches the image cache (which needs path_provider).
      items: [msg('v0', MessageType.video), msg('v1', MessageType.video)],
      initialIndex: 1,
      api: _GoneApi(),
    );
    // Fixed pumps, not pumpAndSettle: the pager's image shimmer never settles.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(MediaPagerScreen), findsOneWidget);
    expect(find.byType(VideoPlayerSurface), findsOneWidget,
        reason: 'the page it opened on starts by itself, in the pager');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('v1')),
        matching: find.byType(VideoPlayerSurface),
      ),
      findsOneWidget,
    );
    expect(calls, isEmpty, reason: 'no hand-off to the OS player');

    // Swipe back to the first video: the player moves with the reader.
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(VideoPlayerSurface), findsOneWidget,
        reason: 'one player, on the page on screen');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('v0')),
        matching: find.byType(VideoPlayerSurface),
      ),
      findsOneWidget,
    );
    expect(find.byType(MediaPagerScreen), findsOneWidget);
    expect(calls, isEmpty);
  });
}
