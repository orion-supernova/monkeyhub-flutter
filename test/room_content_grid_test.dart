import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/media_grid_tile.dart';
import 'package:monkeyhub/widgets/video_message.dart';

/// What this pins: **a grid tile must never mount a video player.**
///
/// `VideoMessage` builds a `VideoPlayerController` per instance and calls
/// `initialize()` on it, so a screenful of forty videos is forty concurrent
/// media pipelines — forty `<video>` elements on web. The failure is not a
/// crash; it is a gallery that scrolls at three frames a second on a phone and
/// exhausts the browser's decoder limit on the web build, which is exactly the
/// kind of thing that ships because it looks fine with two test videos.
///
/// A video therefore renders its poster if it has one and a play glyph if it
/// does not. The glyph is the permanent state for every video sent from web or
/// desktop and for all history, because poster extraction is Android/iOS only —
/// so it is tested as a designed appearance, not as a loading state.
///
/// Sibling: `pinned_banner_tap_test.dart`, whose host harness this copies, and
/// whose lesson about `FocusableTap` registering no recognizer of its own
/// applies to every tappable here.
class _FakeApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

void main() {
  final api = _FakeApi();

  ChatMessage media(
    String id, {
    MessageType type = MessageType.image,
    String? poster,
    int? durationMs,
    String? storageId = 'stor',
  }) => ChatMessage(
    id: id,
    roomId: 'r1',
    senderId: 'u1',
    senderName: 'ada',
    content: '',
    createdAt: DateTime(2026, 3, 1, 12),
    type: type,
    mediaStorageId: storageId,
    posterStorageId: poster,
    mediaDurationMs: durationMs,
  );

  Widget host(Widget child) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 120, height: 120, child: child),
        ),
      ),
    ),
  );

  Widget tile(
    ChatMessage m, {
    bool selected = false,
    bool selecting = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) => MediaGridTile(
    message: m,
    api: api,
    selected: selected,
    selecting: selecting,
    onTap: onTap ?? () {},
    onLongPress: onLongPress ?? () {},
  );

  group('never a video player', () {
    testWidgets('a video with a poster mounts no VideoMessage', (tester) async {
      await tester.pumpWidget(
        host(tile(media('m1', type: MessageType.video, poster: 'poster_1'))),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(VideoMessage),
        findsNothing,
        reason: 'forty of these in a grid is forty media pipelines',
      );
    });

    testWidgets('a video with no poster mounts no VideoMessage either', (
      tester,
    ) async {
      await tester.pumpWidget(host(tile(media('m1', type: MessageType.video))));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VideoMessage), findsNothing);
    });

    testWidgets('the posterless case draws a deliberate glyph', (tester) async {
      await tester.pumpWidget(
        host(tile(media('m1', type: MessageType.video, durationMs: 42000))),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // The running time is the tell that this is a designed representation of
      // a video rather than an image that failed to load.
      expect(find.text('0:42'), findsOneWidget);
    });

    testWidgets('a duration it never measured is simply absent', (
      tester,
    ) async {
      await tester.pumpWidget(host(tile(media('m1', type: MessageType.video))));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('0:00'),
        findsNothing,
        reason: 'an unknown length must not render as a zero-length video',
      );
    });
  });

  group('selection', () {
    testWidgets('a tap fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(tile(media('m1'), onTap: () => taps++)));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(MediaGridTile));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a long press fires onLongPress, not onTap', (tester) async {
      var taps = 0;
      var longs = 0;
      await tester.pumpWidget(
        host(
          tile(media('m1'), onTap: () => taps++, onLongPress: () => longs++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.longPress(find.byType(MediaGridTile));
      await tester.pump();
      expect(longs, 1, reason: 'the phone shortcut into selection mode');
      expect(taps, 0);
    });

    testWidgets('every tile shows its checkbox once selecting, picked or not', (
      tester,
    ) async {
      // Otherwise the affordance is invisible on the tiles that have not been
      // picked yet, and the grid reads as though only one thing is selectable.
      await tester.pumpWidget(host(tile(media('m1'), selecting: true)));
      await tester.pump(const Duration(milliseconds: 400));
      final unpicked = tester.widgetList(find.byType(AnimatedContainer)).length;

      await tester.pumpWidget(host(tile(media('m1'))));
      await tester.pump(const Duration(milliseconds: 400));
      final idle = tester.widgetList(find.byType(AnimatedContainer)).length;

      expect(
        unpicked,
        greaterThan(idle),
        reason: 'selection mode adds the veil and its ring to every tile',
      );
    });
  });
}
