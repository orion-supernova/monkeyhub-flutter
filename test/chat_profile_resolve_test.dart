import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/profile_cache.dart';
import 'package:monkeyhub/data/profile_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/reply_indicator.dart';

/// What this pins: chat surfaces show the sender's CURRENT name from the
/// profile cache, the copy stamped on the message as the fallback, and
/// "Deleted account" for a tombstone.
Map<String, dynamic> _row(String id, String name, {bool deleted = false}) => {
  'id': id,
  'name': name,
  'username': 'un_$id',
  if (deleted) 'deleted': true,
  'updatedAt': 1,
};

Future<ProfileCache> _cache(
  Map<String, Map<String, dynamic>?> server, {
  Object? error,
}) async {
  final c = ProfileCache.forTest(
    fetch: (ids) async {
      if (error != null) throw error;
      return [for (final id in ids) server[id]];
    },
    subscribe: (ids, onData, onError) async => () {},
  );
  await c.attach('me');
  return c;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final api = ChatApi(ConvexBackend.instance);

  ChatMessage msg() => ChatMessage(
    id: 'm1',
    roomId: 'r',
    senderId: 'alice',
    senderName: 'Old Alice',
    content: 'hello',
    createdAt: DateTime(2026, 3, 1, 12),
    type: MessageType.text,
    status: MessageStatus.sent,
  );

  Widget host(ProfileCache? cache, Widget child) {
    final app = MaterialApp(
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
    return cache == null ? app : ProfileScope(cache: cache, child: app);
  }

  Widget bubble() => MessageBubble(
    message: msg(),
    now: DateTime(2026, 3, 1, 12),
    currentUserId: 'bob',
    api: api,
    author: ChatUser(id: 'alice', username: 'alice', name: 'Old Alice'),
    showAvatarSlot: true,
    showAvatar: true,
    grouped: false,
    lastInRun: true,
    senderName: 'Old Alice',
  );

  testWidgets('a bubble shows the name after a rename', (tester) async {
    final cache = await _cache({'alice': _row('alice', 'New Alice')});
    await tester.pumpWidget(host(cache, bubble()));
    expect(find.text('Old Alice'), findsOneWidget);
    await _settle(tester);
    expect(find.text('New Alice'), findsOneWidget);
    expect(find.text('Old Alice'), findsNothing);
    cache.clear(); // cancels the pending subscribe/prune timers
  });

  testWidgets('the copy is the fallback when the cache is empty', (
    tester,
  ) async {
    final cache = await _cache({'alice': null});
    await tester.pumpWidget(host(cache, bubble()));
    await _settle(tester);
    expect(find.text('Old Alice'), findsOneWidget);
    cache.clear(); // cancels the pending subscribe/prune timers
  });

  testWidgets('the copy is the fallback with no scope', (tester) async {
    await tester.pumpWidget(host(null, bubble()));
    await _settle(tester);
    expect(find.text('Old Alice'), findsOneWidget);
  });

  testWidgets('the copy is the fallback in legacy mode', (tester) async {
    final cache = await _cache(
      {},
      error: Exception('Could not find public function for profiles:get'),
    );
    await tester.pumpWidget(host(cache, bubble()));
    await _settle(tester);
    expect(cache.legacy, isTrue);
    expect(find.text('Old Alice'), findsOneWidget);
    cache.clear(); // cancels the pending subscribe/prune timers
  });

  testWidgets('a tombstone shows Deleted account', (tester) async {
    final cache = await _cache({
      'alice': _row('alice', 'New Alice', deleted: true),
    });
    await tester.pumpWidget(host(cache, bubble()));
    await _settle(tester);
    expect(find.text('Deleted account'), findsOneWidget);
    expect(find.text('Old Alice'), findsNothing);
    cache.clear(); // cancels the pending subscribe/prune timers
  });

  testWidgets('a reply preview resolves the quoted sender', (tester) async {
    final cache = await _cache({'alice': _row('alice', 'New Alice')});
    const preview = ReplyPreview(
      senderId: 'alice',
      senderName: 'Old Alice',
      contentPreview: 'quoted words',
      type: MessageType.text,
    );
    await tester.pumpWidget(
      host(
        cache,
        ReplyIndicator(
          preview: preview,
          isMine: false,
          parentIsMine: false,
          api: api,
          parentAuthor: null,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Old Alice'), findsOneWidget);
    await _settle(tester);
    expect(find.text('New Alice'), findsOneWidget);
    expect(find.text('Old Alice'), findsNothing);
    cache.clear(); // cancels the pending subscribe/prune timers
  });

  testWidgets('a sender with no roster entry and no copy shows the cached name', (
    tester,
  ) async {
    final cache = await _cache({'alice': _row('alice', 'New Alice')});
    final m = ChatMessage(
      id: 'm2',
      roomId: 'r',
      senderId: 'alice',
      senderName: '',
      content: 'hello',
      createdAt: DateTime(2026, 3, 1, 12),
      type: MessageType.text,
      status: MessageStatus.sent,
    );
    await tester.pumpWidget(
      host(
        cache,
        MessageBubble(
          message: m,
          now: DateTime(2026, 3, 1, 12),
          currentUserId: 'bob',
          api: api,
          author: null,
          showAvatarSlot: true,
          showAvatar: true,
          grouped: false,
          lastInRun: true,
          // What room_screen now passes: non-null, empty.
          senderName: '',
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('New Alice'), findsOneWidget);
    cache.clear();
  });
}
