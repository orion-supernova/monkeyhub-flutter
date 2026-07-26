import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/pending_upload.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/remote_image.dart';

/// The bubble for a photo that is still on its way up.
///
/// It used not to exist. The optimistic message was built only AFTER the upload
/// finished, so the sender tapped SEND, watched the editor pop, and got an
/// unchanged transcript for however many seconds the upload took — and then had
/// the picture they had just sent fetched back down over the network in order to
/// draw it.
///
/// The assertion that matters most is a negative one: an *armed* (view-once)
/// photo on its way up must still render the sealed tile, with no `Image` and no
/// [RemoteImage] anywhere beneath it. `RemoteImage` caches to disk, and a
/// burn-after-reading photo must leave nothing behind — so the branch order in
/// `buildMessageContent` has to keep checking `viewOnce` first, forever. That is
/// what this pins.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  /// A real PNG, encoded in pure Dart. A `PictureRecorder` round-trip would hang
  /// the suite under the fake-async binding — see camera_editor_chrome_test.
  Uint8List makePng() {
    final bitmap = img.Image(width: 8, height: 8);
    img.fill(bitmap, color: img.ColorRgb8(0x22, 0x88, 0x44));
    return img.encodePng(bitmap);
  }

  PendingUpload upload() =>
      PendingUpload(bytes: makePng(), contentType: 'image/png');

  ChatMessage outgoing({
    required PendingUpload up,
    MessageStatus status = MessageStatus.uploading,
    bool viewOnce = false,
    String? storageId,
  }) =>
      ChatMessage(
        // `tmp_` is what the room screen reads to know a message is optimistic.
        id: 'tmp_1',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.image,
        mediaStorageId: storageId,
        mediaWidth: viewOnce ? null : 800,
        mediaHeight: viewOnce ? null : 600,
        status: status,
        viewOnce: viewOnce,
        upload: up,
      );

  Widget host(Widget child) => MaterialApp(
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
    Future<void> Function()? onRetry,
    VoidCallback? onDiscard,
  }) =>
      MessageBubble(
        message: m,
        now: DateTime(2026, 3, 1, 12),
        // Its own sender: only the sender ever sees one of these.
        currentUserId: 'alice',
        api: api,
        onRetrySend: onRetry,
        onDiscardSend: onDiscard,
      );

  group('an ordinary photo on its way up', () {
    testWidgets('paints the local bytes, not a remote fetch', (tester) async {
      final up = upload();
      addTearDown(up.dispose);

      await tester.pumpWidget(host(bubble(outgoing(up: up))));

      expect(find.byType(Image), findsOneWidget);
      // The whole point: nothing resolves a URL for a picture already in memory.
      expect(find.byType(RemoteImage), findsNothing);
      // And it is emphatically not the "no bytes and no id" error plate.
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    });

    testWidgets('caps the decode so one big send cannot evict the image cache',
        (tester) async {
      final up = upload();
      addTearDown(up.dispose);

      await tester.pumpWidget(host(bubble(outgoing(up: up))));

      final image = tester.widget<Image>(find.byType(Image));
      // A cap exists at all — without one, `Image.memory` decodes the full
      // source, and a 12-megapixel photo is ~48 MB of RGBA.
      final resized = image.image as ResizeImage;
      // Exactly one axis. Both would reach ResizeImagePolicy.exact and squash the
      // bitmap before `fit` ever ran — the bug decodeSizeFor exists to prevent.
      expect(
        resized.width != null && resized.height != null,
        isFalse,
        reason: 'decode must constrain one axis, never both',
      );
      expect(resized.width ?? resized.height, isNotNull);
    });

    testWidgets('keeps painting the bytes after a storage id arrives',
        (tester) async {
      // For a moment after the upload lands the message has both. Resolving a URL
      // then would download back the picture we just finished sending.
      final up = upload();
      addTearDown(up.dispose);

      await tester.pumpWidget(host(
        bubble(outgoing(up: up, status: MessageStatus.pending, storageId: 'sA')),
      ));

      expect(find.byType(RemoteImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('offers no retry while it is still going up', (tester) async {
      final up = upload();
      addTearDown(up.dispose);

      await tester.pumpWidget(host(bubble(outgoing(up: up))));

      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  group('a photo whose send failed', () {
    testWidgets('offers retry and discard, and both fire', (tester) async {
      final up = upload();
      addTearDown(up.dispose);
      var retried = 0;
      var discarded = 0;

      await tester.pumpWidget(host(bubble(
        outgoing(up: up, status: MessageStatus.error),
        onRetry: () async => retried++,
        onDiscard: () => discarded++,
      )));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(retried, 1);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(discarded, 1);
    });

    testWidgets('still shows the picture behind the controls', (tester) async {
      // A failed send is recoverable, so the user has to be able to see WHICH
      // photo failed.
      final up = upload();
      addTearDown(up.dispose);

      await tester.pumpWidget(host(
        bubble(outgoing(up: up, status: MessageStatus.error)),
      ));

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('an armed photo on its way up', () {
    testWidgets('renders the sealed tile and never the bytes', (tester) async {
      final up = upload();
      addTearDown(up.dispose);

      await tester.pumpWidget(host(bubble(outgoing(up: up, viewOnce: true))));

      // The security-shaped assertion. If someone ever reorders the branches in
      // buildMessageContent so `upload` is checked before `viewOnce`, this fails.
      expect(find.byType(Image), findsNothing);
      expect(find.byType(RemoteImage), findsNothing);
      // And it is recognisably the sealed tile, mid-send.
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('sending…'), findsOneWidget);
    });

    testWidgets('a failed armed send offers retry, still without the picture',
        (tester) async {
      final up = upload();
      addTearDown(up.dispose);
      var retried = 0;

      await tester.pumpWidget(host(bubble(
        outgoing(up: up, viewOnce: true, status: MessageStatus.error),
        onRetry: () async => retried++,
      )));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(RemoteImage), findsNothing);
      expect(find.text('failed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(retried, 1);
    });
  });

  group('the other two attachment kinds', () {
    ChatMessage outgoingOf(MessageType type, PendingUpload up,
            {MessageStatus status = MessageStatus.uploading}) =>
        ChatMessage(
          id: 'tmp_1',
          roomId: 'r',
          senderId: 'alice',
          senderName: 'alice',
          content: '',
          createdAt: DateTime(2026, 3, 1, 12),
          type: type,
          status: status,
          upload: up,
        );

    testWidgets('a voice note in flight says so instead of "[audio missing]"',
        (tester) async {
      // AudioMessage renders a null storage id as that literal string, which is
      // true of a broken message and alarmingly false of one uploading fine.
      final up = upload();
      addTearDown(up.dispose);

      await tester.pumpWidget(host(bubble(
        outgoingOf(MessageType.audio, up),
      )));

      expect(find.text('[audio missing]'), findsNothing);
      expect(find.text('sending…'), findsOneWidget);
    });

    testWidgets('a failed voice note offers retry', (tester) async {
      final up = upload();
      addTearDown(up.dispose);
      var retried = 0;

      await tester.pumpWidget(host(bubble(
        outgoingOf(MessageType.audio, up, status: MessageStatus.error),
        onRetry: () async => retried++,
      )));

      expect(find.text('failed'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('a video in flight shows a ring, not an endless player',
        (tester) async {
      final up = upload();
      addTearDown(up.dispose);

      await tester
          .pumpWidget(host(bubble(outgoingOf(MessageType.video, up))));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('PendingUpload', () {
    test('a disposed upload refuses further progress instead of throwing', () {
      // A cancelled request's last callback can land after disposal; writing to a
      // disposed ValueNotifier throws.
      final up = upload();
      up.dispose();
      expect(up.disposed, isTrue);
      expect(() => up.report(0.5), returnsNormally);
    });

    test('disposing twice is a no-op', () {
      final up = upload();
      up.dispose();
      expect(up.dispose, returnsNormally);
    });
  });
}
