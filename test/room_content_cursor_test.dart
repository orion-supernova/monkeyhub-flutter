import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/room_content_controller.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_content_item.dart';

/// What this pins: the shared-content browser draws from two sources at once —
/// a page fetched out of the `by_room_bucket_time` index, and the room's
/// already-live transcript — and they OVERLAP at the newest end. Both hold the
/// most recent attachments.
///
/// Merging them without deduping by id renders whatever arrived between the
/// fetch starting and finishing twice, which is the case a user hits by
/// opening the browser right after sending a photo. Merging them with the wrong
/// cursor is worse: paging is driven off the FETCHED half only, because the
/// live half sits at the newest end and using it as "the oldest thing I hold"
/// would make page two jump backwards and re-fetch forever.
///
/// Also pinned: a page whose rows all render nothing must keep paging rather
/// than declare the tab empty. That is a real state on LINKS, where the server
/// selects rows with a coarse `hasLink` and the client decides what a URL is.
///
/// Siblings: `room_content_selection_test.dart` (what happens when the merged
/// list shrinks underneath a selection), `pin_subscription_lifecycle_test.dart`
/// (the fake-double style used here).
class _FakeApi extends Fake implements ChatApi {
  /// Pages handed out in order, one per call.
  final List<RoomContentPage> pages = [];
  final List<DateTime?> cursors = [];
  int calls = 0;

  @override
  Future<RoomContentPage> listRoomContent({
    required String roomId,
    required String userId,
    required String bucket,
    DateTime? before,
    int limit = 30,
  }) async {
    cursors.add(before);
    calls++;
    return pages.isEmpty ? RoomContentPage.empty : pages.removeAt(0);
  }

  @override
  Future<RoomContentPage> listRoomLinks({
    required String roomId,
    required String userId,
    DateTime? before,
    int limit = 30,
  }) async {
    cursors.add(before);
    calls++;
    return pages.isEmpty ? RoomContentPage.empty : pages.removeAt(0);
  }
}

/// A repository whose only job is to answer `messagesFor` and `userId` — the
/// two things the controller reads off it.
class _FakeRepo extends Fake implements ChatRepository {
  List<ChatMessage> live = const [];

  @override
  String? get userId => 'me';

  @override
  List<ChatMessage> messagesFor(String roomId) => live;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void dispose() {}
}

ChatMessage photo(String id, int minute) => ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: 'u1',
      senderName: 'ada',
      content: '',
      createdAt: DateTime.utc(2026, 1, 1, 12, minute),
      type: MessageType.image,
      mediaStorageId: 'stor_$id',
    );

ChatMessage textWith(String id, int minute, String content) => ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: 'u1',
      senderName: 'ada',
      content: content,
      createdAt: DateTime.utc(2026, 1, 1, 12, minute),
    );

void main() {
  late _FakeApi api;
  late _FakeRepo repo;

  RoomContentController make(RoomContentTab tab) => RoomContentController(
        repo: repo,
        api: api,
        roomId: 'r1',
        tab: tab,
      );

  setUp(() {
    api = _FakeApi();
    repo = _FakeRepo();
  });

  group('the seam between fetched and live', () {
    test('a message in both halves renders once', () async {
      final shared = photo('m2', 2);
      repo.live = [photo('m3', 3), shared];
      api.pages.add(RoomContentPage(items: [shared, photo('m1', 1)], hasMore: false));

      final c = make(RoomContentTab.media);
      await c.loadInitial();

      expect(c.items.map((m) => m.id), ['m3', 'm2', 'm1'],
          reason: 'the overlap at the newest end must collapse, not duplicate');
    });

    test('the live copy wins, because it is the one carrying reactions', () async {
      final stale = photo('m1', 1)..content = 'snapshot';
      final live = photo('m1', 1)..content = 'live';
      repo.live = [live];
      api.pages.add(RoomContentPage(items: [stale], hasMore: false));

      final c = make(RoomContentTab.media);
      await c.loadInitial();

      expect(c.items.single.content, 'live');
    });

    test('the merged list is newest-first regardless of which half it came from',
        () async {
      repo.live = [photo('m4', 4), photo('m1', 1)];
      api.pages.add(RoomContentPage(items: [photo('m3', 3), photo('m2', 2)], hasMore: false));

      final c = make(RoomContentTab.media);
      await c.loadInitial();

      expect(c.items.map((m) => m.id), ['m4', 'm3', 'm2', 'm1']);
    });

    test('only messages belonging in the tab are taken from the live half', () async {
      repo.live = [
        photo('m3', 3),
        textWith('m2', 2, 'just talking'),
        ChatMessage(
          id: 'm1',
          roomId: 'r1',
          senderId: 'u1',
          senderName: 'ada',
          content: '',
          createdAt: DateTime.utc(2026, 1, 1, 12, 1),
          type: MessageType.image,
          viewOnce: true,
        ),
      ];
      api.pages.add(RoomContentPage.empty);

      final c = make(RoomContentTab.media);
      await c.loadInitial();

      expect(c.items.map((m) => m.id), ['m3'],
          reason: 'text is not media, and a view-once photo is never shared '
              'content — the server keeps it out of the index, so the client '
              'must keep it out of the live half too');
    });
  });

  group('the paging cursor', () {
    test('is null on the first page', () async {
      api.pages.add(RoomContentPage(items: [photo('m1', 1)], hasMore: false));
      await make(RoomContentTab.media).loadInitial();
      expect(api.cursors, [null]);
    });

    test('comes from the fetched half, never from the live half', () async {
      // The live half is NEWER than everything fetched. If the cursor were
      // taken from `items`, page two would ask for "older than 12:09" and
      // re-read the page it already has.
      repo.live = [photo('m9', 9)];
      api.pages.add(RoomContentPage(items: [photo('m3', 3), photo('m2', 2)], hasMore: true));
      api.pages.add(RoomContentPage(items: [photo('m1', 1)], hasMore: false));

      final c = make(RoomContentTab.media);
      await c.loadInitial();
      await c.loadMore();

      expect(api.cursors[1], DateTime.utc(2026, 1, 1, 12, 2),
          reason: 'the oldest FETCHED row, not the oldest row on screen');
      expect(c.items.map((m) => m.id), ['m9', 'm3', 'm2', 'm1']);
    });

    test('a repeated row across a page boundary is dropped', () async {
      // Two messages can share a createdAt to the millisecond — a forward
      // writes its batch in one transaction — so a timestamp cursor cannot be
      // both non-skipping and non-repeating. Dedupe by id decides it.
      api.pages.add(RoomContentPage(items: [photo('m2', 2)], hasMore: true));
      api.pages.add(RoomContentPage(items: [photo('m2', 2), photo('m1', 1)], hasMore: false));

      final c = make(RoomContentTab.media);
      await c.loadInitial();
      await c.loadMore();

      expect(c.items.map((m) => m.id), ['m2', 'm1']);
    });

    test('stops asking once the server says there is no more', () async {
      api.pages.add(RoomContentPage(items: [photo('m1', 1)], hasMore: false));
      final c = make(RoomContentTab.media);
      await c.loadInitial();
      await c.loadMore();
      await c.loadMore();
      expect(api.calls, 1);
      expect(c.hasMore, isFalse);
    });
  });

  group('loading state', () {
    test('loadInitial fetches once however often it is called', () async {
      api.pages.add(RoomContentPage(items: [photo('m1', 1)], hasMore: true));
      final c = make(RoomContentTab.media);
      await c.loadInitial();
      await c.loadInitial();
      expect(api.calls, 1);
    });

    test('a failed page does not look like the end of the list', () async {
      final c = RoomContentController(
        repo: repo,
        api: _ThrowingApi(),
        roomId: 'r1',
        tab: RoomContentTab.media,
      );
      await c.loadInitial();

      expect(c.error, isNotNull);
      expect(c.hasMore, isTrue,
          reason: "a network error must not render as \"that's everything\"");
      expect(c.loadedOnce, isTrue);
    });

    test('refresh drops the fetched half and re-reads from the top', () async {
      api.pages.add(RoomContentPage(items: [photo('m2', 2)], hasMore: false));
      final c = make(RoomContentTab.media);
      await c.loadInitial();

      api.pages.add(RoomContentPage(items: [photo('m1', 1)], hasMore: false));
      await c.refresh();

      expect(c.items.map((m) => m.id), ['m1']);
      expect(api.cursors.last, isNull, reason: 'refresh starts at the top');
    });

    test('forget drops rows from the fetched half immediately', () async {
      api.pages.add(
          RoomContentPage(items: [photo('m2', 2), photo('m1', 1)], hasMore: false));
      final c = make(RoomContentTab.media);
      await c.loadInitial();

      c.forget({'m2'});
      expect(c.items.map((m) => m.id), ['m1']);
    });
  });

  group('links', () {
    test('one message with two URLs is two rows', () async {
      api.pages.add(RoomContentPage(
        items: [textWith('m1', 1, 'see https://a.dev and https://b.dev')],
        hasMore: false,
      ));

      final c = make(RoomContentTab.links);
      await c.loadInitial();

      expect(c.links.map((l) => l.url), ['https://a.dev', 'https://b.dev']);
      expect(c.links.every((l) => l.message.id == 'm1'), isTrue,
          reason: 'each row keeps its message, so "show in chat" works');
    });

    test('a page that renders nothing keeps paging instead of saying empty',
        () async {
      // The server selected these with its own coarser rule; the client finds
      // no URL in them. Stopping here would show "no links" over a room that
      // has some, one page further back.
      api.pages.add(RoomContentPage(
        items: [textWith('m3', 3, 'nothing here')],
        hasMore: true,
      ));
      api.pages.add(RoomContentPage(
        items: [textWith('m2', 2, 'still nothing')],
        hasMore: true,
      ));
      api.pages.add(RoomContentPage(
        items: [textWith('m1', 1, 'finally https://found.dev')],
        hasMore: false,
      ));

      final c = make(RoomContentTab.links);
      await c.loadInitial();

      expect(api.calls, 3);
      expect(c.links.single.url, 'https://found.dev');
      expect(c.isEmpty, isFalse);
    });

    test('the chase is bounded, so one tab cannot read a whole history',
        () async {
      for (var i = 0; i < 20; i++) {
        api.pages.add(RoomContentPage(
          items: [textWith('m$i', i, 'no url')],
          hasMore: true,
        ));
      }

      final c = make(RoomContentTab.links);
      await c.loadInitial();

      expect(api.calls, lessThanOrEqualTo(4),
          reason: 'a bound, not a while(isEmpty) loop');
      expect(c.hasMore, isTrue, reason: 'the screen can ask for more itself');
    });
  });
}

class _ThrowingApi extends Fake implements ChatApi {
  @override
  Future<RoomContentPage> listRoomContent({
    required String roomId,
    required String userId,
    required String bucket,
    DateTime? before,
    int limit = 30,
  }) async =>
      throw StateError('network');
}
