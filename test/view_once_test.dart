import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';
import 'package:monkeyhub/widgets/remote_image.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// View-once photos: the sealed bubble, and the model rules underneath it.
///
/// The property that matters most here is a negative one — a view-once bubble
/// must never construct a [RemoteImage], because that path caches to disk and
/// would leave a readable copy of a photo the server has deleted. The rest pins
/// the three visual states onto one silhouette, so the transcript doesn't jump
/// as a bubble goes sealed → opened → ghost.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  ChatMessage photo({
    bool viewOnce = true,
    bool opened = false,
    DateTime? burnedAt,
    String? storageId,
    String senderId = 'alice',
  }) => ChatMessage(
    id: 'm1',
    roomId: 'r',
    senderId: senderId,
    senderName: 'alice',
    content: '',
    createdAt: DateTime(2026, 3, 1, 12),
    type: MessageType.image,
    mediaStorageId: storageId,
    status: MessageStatus.sent,
    viewOnce: viewOnce,
    viewOnceOpened: opened,
    viewOnceBurnedAt: burnedAt,
  );

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 500, child: child),
        ),
      ),
    ),
  );

  Widget bubble(
    ChatMessage m, {
    String currentUserId = 'bob',
    Future<void> Function()? onOpen,
  }) => MessageBubble(
    message: m,
    now: DateTime(2026, 3, 1, 12),
    currentUserId: currentUserId,
    api: api,
    onOpenViewOnce: onOpen,
  );

  group('sealed bubble', () {
    testWidgets('never builds a RemoteImage', (tester) async {
      await tester.pumpWidget(host(bubble(photo())));
      await tester.pump();
      // The disk-caching image path must not be anywhere near this bubble.
      expect(find.byType(RemoteImage), findsNothing);
      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets('unopened reads "tap to view"', (tester) async {
      await tester.pumpWidget(host(bubble(photo())));
      expect(find.text('Tap to view'), findsOneWidget);
    });

    testWidgets('spent reads "opened"', (tester) async {
      await tester.pumpWidget(host(bubble(photo(opened: true))));
      expect(find.text('Opened'), findsOneWidget);
      expect(find.text('Tap to view'), findsNothing);
    });

    testWidgets('burned without ever being opened reads "expired"', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(bubble(photo(burnedAt: DateTime(2026, 3, 15)))),
      );
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('the sender sees the same tile, not their own photo', (
      tester,
    ) async {
      // Same silhouette and the same wording as a recipient's — the sender has
      // no reopen path, so nothing here should suggest one.
      await tester.pumpWidget(host(bubble(photo(), currentUserId: 'alice')));
      expect(find.byType(RemoteImage), findsNothing);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('View once'), findsOneWidget);
      expect(find.text('Tap to view'), findsNothing);
    });
  });

  group('taps', () {
    testWidgets('an unopened photo can be opened once', (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        host(bubble(photo(), onOpen: () async => opens++)),
      );
      await tester.tap(find.text('Photo'));
      await tester.pumpAndSettle();
      expect(opens, 1);
    });

    testWidgets('a spent photo ignores taps', (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        host(bubble(photo(opened: true), onOpen: () async => opens++)),
      );
      await tester.tap(find.text('Photo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(opens, 0);
    });

    testWidgets('a burned photo ignores taps', (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        host(
          bubble(
            photo(burnedAt: DateTime(2026, 3, 15)),
            onOpen: () async => opens++,
          ),
        ),
      );
      await tester.tap(find.text('Photo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(opens, 0);
    });

    testWidgets('the sender cannot reopen their own', (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        host(
          bubble(photo(), currentUserId: 'alice', onOpen: () async => opens++),
        ),
      );
      await tester.tap(find.text('Photo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(opens, 0);
    });
  });

  testWidgets('all three states share one silhouette', (tester) async {
    Future<Size> sizeOf(ChatMessage m) async {
      await tester.pumpWidget(host(bubble(m)));
      await tester.pump();
      return tester.getSize(
        find
            .ancestor(of: find.text('Photo'), matching: find.byType(Container))
            .last,
      );
    }

    // If these diverged, the transcript would reflow underneath the reader at
    // the exact moment a photo burned.
    final sealed = await sizeOf(photo());
    final spent = await sizeOf(photo(opened: true));
    final ghost = await sizeOf(photo(burnedAt: DateTime(2026, 3, 15)));
    expect(spent, sealed);
    expect(ghost, sealed);
    // Square, and pinned: a sealed photo is a picture-shaped placeholder, not
    // the attachment bar it used to be.
    expect(sealed, const Size(152, 152));
  });

  testWidgets('the tile carries its own timestamp', (tester) async {
    // Before, a caption-less view-once photo failed `messageStampsInline` — it
    // has no storage id by design — and paid for a whole external row to show
    // four characters. The stamp now lives in the tile's own bottom corner.
    await tester.pumpWidget(host(bubble(photo())));
    await tester.pump();
    expect(find.text('12:00'), findsOneWidget);

    final tile = find
        .ancestor(of: find.text('Photo'), matching: find.byType(Container))
        .last;
    expect(
      find.descendant(of: tile, matching: find.byKey(kVisibleStampKey)),
      findsOneWidget,
    );

    // And it sits in the tile's bottom-trailing corner, not floating in the
    // middle of it. A Stack lays its non-positioned children out loose, so an
    // un-filled content layer would shrink the box these are measured against
    // and drag the stamp inwards with it.
    final box = tester.getRect(tile);
    final stamp = tester.getRect(find.byKey(kVisibleStampKey));
    expect(stamp.right, greaterThan(box.center.dx));
    expect(stamp.bottom, greaterThan(box.center.dy));
    expect(box.right - stamp.right, lessThan(20));
    expect(box.bottom - stamp.bottom, lessThan(20));

    // The seal and its labels stay centred on the tile's own axis.
    expect(
      tester.getRect(find.text('Photo')).center.dx,
      moreOrLessEquals(box.center.dx, epsilon: 0.5),
    );
  });

  group('model rules', () {
    test('openable only for an unspent recipient', () {
      expect(photo().viewOnceOpenable(isMine: false), isTrue);
      expect(photo().viewOnceOpenable(isMine: true), isFalse);
      expect(photo(opened: true).viewOnceOpenable(isMine: false), isFalse);
      expect(
        photo(burnedAt: DateTime(2026, 3, 15)).viewOnceOpenable(isMine: false),
        isFalse,
      );
      expect(photo(viewOnce: false).viewOnceOpenable(isMine: false), isFalse);
    });

    test('survives the disk cache round trip', () {
      // CacheStore reuses this codec, so a cold boot must not redraw a spent
      // photo as an unopened one and invite a tap that can only be refused.
      final m = photo(opened: true, burnedAt: DateTime(2026, 3, 15, 9));
      final back = ChatMessage.fromJson(m.toJson());
      expect(back.viewOnce, isTrue);
      expect(back.viewOnceOpened, isTrue);
      expect(back.viewOnceBurnedAt, DateTime(2026, 3, 15, 9));
      expect(back.viewOnceBurned, isTrue);
    });

    test('an ordinary photo round-trips with the flags off', () {
      final m = photo(viewOnce: false, storageId: 'st_1');
      final back = ChatMessage.fromJson(m.toJson());
      expect(back.viewOnce, isFalse);
      expect(back.viewOnceOpened, isFalse);
      expect(back.viewOnceBurnedAt, isNull);
      expect(back.mediaStorageId, 'st_1');
    });

    test('copyWith carries the view-once state', () {
      final m = photo();
      expect(m.copyWith(viewOnceOpened: true).viewOnceOpened, isTrue);
      // Not passing it must not silently clear it.
      expect(photo(opened: true).copyWith().viewOnceOpened, isTrue);
      expect(photo().copyWith().viewOnce, isTrue);
    });

    test('a quoted view-once parent is labelled, not thumbnailed', () {
      final p = ReplyPreview.fromJson({
        'senderId': 'alice',
        'senderName': 'alice',
        'contentPreview': '__VIEW_ONCE__',
        'type': 'image',
      });
      expect(p.isViewOnce, isTrue);
      expect(p.isDeleted, isFalse);
      // The storage id is what a reply preview would otherwise make permanent.
      expect(p.mediaStorageId, isNull);
    });
  });
}
