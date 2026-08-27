import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_content_item.dart';
import 'package:monkeyhub/screens/fullscreen_image_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/room_gallery_scope.dart';
import 'package:monkeyhub/widgets/steady_hero.dart';

/// A photo tapped in a transcript opens the room's gallery, not a dead end.
///
/// It used to open `FullscreenImageViewer`, which shows exactly one picture: to
/// see the next photo in the conversation you backed out, scrolled, and tapped
/// again. This pins the three things that make the swipeable version work, all
/// of which fail silently rather than loudly if they regress.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  ChatMessage photo(String id, {bool viewOnce = false, String? storageId}) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.image,
        mediaStorageId: storageId ?? 'blob_$id',
        mediaWidth: 800,
        mediaHeight: 600,
        viewOnce: viewOnce,
      );

  /// The scope sits ABOVE the app, exactly as `MonkeyHubApp` builds it. That
  /// is load-bearing here rather than incidental: the fullscreen viewer is
  /// pushed on the ROOT navigator, so a `ThemeScope` tucked inside `home` is
  /// not an ancestor of it and every `RemoteImage` on that route throws.
  Widget host(Widget child) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 500, child: child),
        ),
      ),
    ),
  );

  Widget bubble(ChatMessage m) => MessageBubble(
    message: m,
    now: DateTime(2026, 3, 1, 12),
    currentUserId: 'bob',
    api: api,
  );

  testWidgets('a photo in a room asks the room for the whole gallery', (
    tester,
  ) async {
    final m = photo('m1');
    ChatMessage? asked;

    await tester.pumpWidget(
      host(
        RoomGalleryScope(
          openGallery: (message, {required sourceDecodeWidth}) async =>
              asked = message,
          child: bubble(m),
        ),
      ),
    );

    await tester.tap(find.byType(SteadyHero));
    await tester.pump();

    expect(asked?.id, 'm1');
    // And emphatically NOT the single-picture route: opening both would put a
    // viewer under the gallery for the reader to back out of twice.
    expect(find.byType(FullscreenImageViewer), findsNothing);
  });

  testWidgets('a photo with no room behind it still opens on its own', (
    tester,
  ) async {
    // The thread sheet and the lifted message-actions preview both build
    // bubbles outside the room's scope. There is no conversation to swipe
    // through there, and one picture is the honest answer.
    await tester.pumpWidget(host(bubble(photo('m2'))));

    await tester.tap(find.byType(SteadyHero));
    // Bounded rather than pumpAndSettle: the unresolved image's shimmer
    // schedules frames forever, so a settle loop would hang instead of failing.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(FullscreenImageViewer), findsOneWidget);
  });

  testWidgets('the gallery and the bubble agree on the hero tag', (
    tester,
  ) async {
    // The gallery is handed messages, not widgets, so it rebuilds this string
    // from scratch. A tag it computed differently would match nothing and
    // degrade to a cross-fade — with no error anywhere to say so.
    final m = photo('m3');
    await tester.pumpWidget(host(bubble(m)));

    final hero = tester.widget<SteadyHero>(find.byType(SteadyHero));
    expect(hero.tag, bubbleMediaHeroTag(m));
  });

  test('the gallery set is the same set the MEDIA tab would show', () {
    // Shared predicate, on purpose. A hand-written filter here is how the
    // gallery ends up including an armed view-once photo that the shared-content
    // grid correctly refuses to list.
    expect(messageBelongsIn(photo('a'), RoomContentTab.media), isTrue);
    expect(
      messageBelongsIn(photo('b', viewOnce: true), RoomContentTab.media),
      isFalse,
      reason: 'a burn-on-open picture is not something you swipe past',
    );
    expect(
      messageBelongsIn(
        ChatMessage(
          id: 'c',
          roomId: 'r',
          senderId: 'alice',
          senderName: 'alice',
          content: '',
          createdAt: DateTime(2026, 3, 1, 12),
          type: MessageType.image,
        ),
        RoomContentTab.media,
      ),
      isFalse,
      reason: 'no storage id is a failed or still-running upload',
    );
  });
}
