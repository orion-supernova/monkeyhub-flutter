import 'package:flutter/widgets.dart';
import 'package:monkeyhub/backend/call_log_api.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/calls/call_log_models.dart';
import 'package:monkeyhub/screens/calls/calls_directory.dart';

/// A `callLog` source that answers from memory.
class FakeCallLogSource implements CallLogSource {
  FakeCallLogSource({
    this.byFilter = const {},
    this.week = CallLogSummary.empty,
    this.month = CallLogSummary.empty,
    List<String> favourites = const [],
  }) : _favs = [...favourites];

  /// The pinned peers, oldest first (what `callFavorites:list` returns).
  final List<String> _favs;

  /// When set, add / remove throw after this delay, like a refused mutation.
  bool failFavouriteWrites = false;
  final List<String> favouriteAdds = [];
  final List<String> favouriteRemoves = [];
  void Function(List<CallFavourite>)? _favSink;
  int favouriteSubscriptions = 0;

  List<String> get favourites => List.unmodifiable(_favs);

  void _pushFavs() => _favSink?.call([
        for (var i = 0; i < _favs.length; i++)
          CallFavourite(peerId: _favs[i], addedAt: i),
      ]);

  final Map<String, List<CallLogEntry>> byFilter;
  CallLogSummary week;
  CallLogSummary month;

  /// Every first-page subscription opened, by filter.
  final List<String> subscribed = [];
  final List<String> removed = [];
  final List<int> summaryCalls = [];
  final Map<String, void Function(CallLogPage)> _sinks = {};

  /// Pushes a new first page to a live subscription.
  void push(String filter, List<CallLogEntry> rows) =>
      _sinks[filter]?.call(CallLogPage(rows: rows, isDone: true));

  @override
  Future<void Function()> subscribeFirstPage({
    required String filter,
    required int numItems,
    required void Function(CallLogPage page) onPage,
    void Function(Object error)? onError,
  }) async {
    subscribed.add(filter);
    _sinks[filter] = onPage;
    onPage(CallLogPage(rows: byFilter[filter] ?? const [], isDone: true));
    return () => _sinks.remove(filter);
  }

  @override
  Future<CallLogPage> page({
    required String filter,
    required int numItems,
    required String cursor,
  }) async =>
      const CallLogPage(rows: [], isDone: true);

  @override
  Future<CallLogSummary> summary({required int since, int tzOffsetMin = 0}) async {
    summaryCalls.add(since);
    // The week is the shorter window: the caller asks for it first.
    return since > DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch
        ? week
        : month;
  }

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  Future<void Function()> subscribeFavourites({
    required void Function(List<CallFavourite> favourites) onData,
    void Function(Object error)? onError,
  }) async {
    favouriteSubscriptions++;
    _favSink = onData;
    _pushFavs();
    return () => _favSink = null;
  }

  @override
  Future<void> addFavourite(String peerId) async {
    favouriteAdds.add(peerId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (failFavouriteWrites) throw Exception('nope');
    if (!_favs.contains(peerId)) _favs.add(peerId);
    _pushFavs();
  }

  @override
  Future<void> removeFavourite(String peerId) async {
    favouriteRemoves.add(peerId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (failFavouriteWrites) throw Exception('nope');
    _favs.remove(peerId);
    _pushFavs();
  }
}

/// Rooms and people held in memory.
class FakeDirectory extends ChangeNotifier implements CallsDirectory {
  FakeDirectory({List<ChatUser> users = const [], List<ChatRoom> rooms = const []})
      : _users = {for (final u in users) u.id: u},
        _rooms = {for (final r in rooms) r.id: r};

  final Map<String, ChatUser> _users;
  final Map<String, ChatRoom> _rooms;
  final List<String> opened = [];

  @override
  String? get myId => 'me';
  @override
  ChatRoom? room(String id) => _rooms[id];
  @override
  ChatUser? user(String id) => _users[id];
  @override
  List<ChatUser> get friends => _users.values.toList();
  @override
  Iterable<ChatRoom> get rooms => _rooms.values;
  @override
  Future<String> dmRoomWith(ChatUser friend) async => 'dm-${friend.id}';
  @override
  void openChat(BuildContext context, String roomId) => opened.add(roomId);
}

ChatUser fakeUser(String id, String name) =>
    ChatUser(id: id, username: id, name: name);

ChatRoom fakeDm(String id, String peerId) => ChatRoom(
      id: id,
      name: 'dm:me:$peerId',
      createdBy: 'me',
      createdAt: DateTime(2026, 1, 1),
      isPrivate: true,
      memberCount: 2,
      participantIds: ['me', peerId],
    );

ChatRoom fakeGroup(String id, String name) => ChatRoom(
      id: id,
      name: name,
      createdBy: 'me',
      createdAt: DateTime(2026, 1, 1),
      isPrivate: true,
      memberCount: 4,
    );

/// A row for [roomId], [minutesAgo] minutes before [now].
CallLogEntry fakeEntry(
  String id, {
  String roomId = 'dm-a',
  String? peerId = 'a',
  required DateTime now,
  int minutesAgo = 5,
  CallOutcome outcome = CallOutcome.answered,
  bool video = false,
  bool incoming = true,
  CallLogKind kind = CallLogKind.direct,
  int durationMs = 0,
  int? people,
  int? ringingAt,
  int? answeredAt,
  String? answeredOn,
  List<CallHandoff> handoffs = const [],
  List<int> quality = const [],
}) {
  final start = now.subtract(Duration(minutes: minutesAgo)).millisecondsSinceEpoch;
  return CallLogEntry(
    id: id,
    roomId: roomId,
    kind: kind,
    video: video,
    incoming: incoming,
    outcome: outcome,
    peerId: peerId,
    people: people,
    startedAt: start,
    ringingAt: ringingAt,
    answeredAt: answeredAt,
    endedAt: start + durationMs + 4000,
    durationMs: durationMs,
    answeredOn: answeredOn,
    handoffs: handoffs,
    qualityWorst: quality.isEmpty ? null : 'good',
    qualitySamples: quality,
  );
}
