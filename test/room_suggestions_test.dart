import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/room_suggestion_queue.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/room_suggestions_banner.dart';

/// A member's suggested group photo, as the ADMIN meets it.
///
/// The bug report was "only I can see what I suggested — the admin can't".
/// The suggestion was stored and the admin's query answered correctly; what
/// failed was the route to it, which ran through a push and a row deep in Room
/// Info. These pin the new route: the room itself tells an admin, and tells
/// nobody else.
ChatRoom _group({String name = 'Dürüst isim'}) => ChatRoom(
      id: 'r1',
      name: name,
      createdBy: 'owner',
      createdAt: DateTime(2026),
      isPrivate: false,
      memberCount: 2,
    );

RoomChangeRequest _photo(String id, {String who = 'Murat'}) => RoomChangeRequest(
      requestId: id,
      field: RoomChangeField.avatar,
      createdAt: DateTime(2026, 9, 17),
      storageId: 'kg2-$id',
      user: ChatUser(id: 'm1', username: who.toLowerCase(), name: who),
    );

class _Harness {
  _Harness({required String role, ChatRoom? room}) : _room = room ?? _group() {
    roster = [
      ChatUser(id: 'me', username: 'me', name: 'Me', role: role),
      ChatUser(id: 'm1', username: 'murat', name: 'Murat', role: 'member'),
    ];
    queue = RoomSuggestionQueue(
      me: () => 'me',
      room: () => _room,
      roster: () => roster,
      fetch: () {
        fetches++;
        return answer.future;
      },
    );
  }

  final ChatRoom _room;
  late List<ChatUser> roster;
  late final RoomSuggestionQueue queue;
  int fetches = 0;
  Completer<List<RoomChangeRequest>> answer = Completer();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoomSuggestionQueue', () {
    test('an owner is a reviewer, and asks once', () async {
      final h = _Harness(role: 'owner');
      h.queue.syncStanding();
      h.queue.syncStanding();

      expect(h.queue.isReviewer, isTrue);
      expect(h.fetches, 1, reason: 'standing did not move the second time');

      h.answer.complete([_photo('a')]);
      await pumpEventQueue();
      expect(h.queue.pending.single.requestId, 'a');
      h.queue.dispose();
    });

    test('a plain member costs nothing — no query is ever issued', () async {
      final h = _Harness(role: 'member');
      h.queue.syncStanding();
      await h.queue.refresh();

      expect(h.queue.isReviewer, isFalse);
      expect(h.fetches, 0);
      h.queue.dispose();
    });

    test('a DM never has a queue, whatever the roster says', () async {
      final h = _Harness(role: 'owner', room: _group(name: 'dm:regular:a:b'));
      h.queue.syncStanding();

      expect(h.queue.isReviewer, isFalse);
      expect(h.fetches, 0);
      h.queue.dispose();
    });

    test('refreshes coalesce into one follow-up read', () async {
      final h = _Harness(role: 'admin');
      h.queue.syncStanding();
      unawaited(h.queue.refresh());
      unawaited(h.queue.refresh());
      expect(h.fetches, 1, reason: 'the first read is still in flight');

      final first = h.answer;
      h.answer = Completer();
      first.complete([_photo('a')]);
      await pumpEventQueue();
      expect(h.fetches, 2, reason: 'exactly one more, not one per ask');

      h.answer.complete(const []);
      await pumpEventQueue();
      expect(h.queue.pending, isEmpty);
      h.queue.dispose();
    });

    test('losing admin clears the strip', () async {
      final h = _Harness(role: 'admin');
      h.queue.syncStanding();
      h.answer.complete([_photo('a')]);
      await pumpEventQueue();
      expect(h.queue.pending, hasLength(1));

      h.roster = [
        ChatUser(id: 'me', username: 'me', name: 'Me', role: 'member'),
      ];
      h.queue.syncStanding();
      expect(h.queue.pending, isEmpty);
      h.queue.dispose();
    });

    test('a failed read keeps what was already there', () async {
      final h = _Harness(role: 'admin');
      h.queue.syncStanding();
      h.answer.complete([_photo('a')]);
      await pumpEventQueue();

      h.answer = Completer()..completeError(StateError('offline'));
      await h.queue.refresh();
      expect(h.queue.pending.single.requestId, 'a');
      h.queue.dispose();
    });
  });

  group('RoomSuggestionsBanner', () {
    Future<void> pump(
      WidgetTester t,
      List<RoomChangeRequest> pending, {
      VoidCallback? onReview,
    }) async {
      await t.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Column(children: [
              RoomSuggestionsBanner(
                pending: pending,
                api: ChatApi(ConvexBackend.instance),
                onReview: onReview ?? () {},
              ),
            ]),
          ),
        ),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('nothing pending takes no height', (t) async {
      await pump(t, const []);
      expect(t.getSize(find.byType(RoomSuggestionsBanner)).height, 0);
    });

    testWidgets('one suggestion names who and what', (t) async {
      final text = RoomChangeRequest(
        requestId: 'n',
        field: RoomChangeField.name,
        createdAt: DateTime(2026),
        value: 'Trip 2026',
        user: ChatUser(id: 'm1', username: 'murat', name: 'Murat'),
      );
      await pump(t, [text]);
      expect(find.text('Murat suggested a new name'), findsOneWidget);
      expect(find.text('REVIEW'), findsOneWidget);
      expect(
        t.getSize(find.byType(RoomSuggestionsBanner)).height,
        kSuggestionsBannerHeight,
        reason: 'the liquid style reserves exactly this much for it',
      );
    });

    testWidgets('several collapse to a count, and the strip opens review',
        (t) async {
      var reviewed = 0;
      await pump(t, [_photo('a'), _photo('b')], onReview: () => reviewed++);
      expect(find.text('2 suggestions waiting for you'), findsOneWidget);

      await t.tap(find.byType(RoomSuggestionsBanner));
      expect(reviewed, 1);
    });
  });
}
