import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/chat_folder_store.dart';
import 'package:monkeyhub/data/chat_folders.dart';
import 'package:monkeyhub/models/chat_room.dart';

ChatRoom _room(
  String id, {
  bool dm = false,
  int unread = 0,
  bool archived = false,
}) => ChatRoom(
  id: id,
  name: dm ? 'dm:u0:$id' : 'group-$id',
  createdBy: 'u0',
  createdAt: DateTime(2026),
  isPrivate: true,
  memberCount: 2,
  unreadCount: unread,
  isArchived: archived,
);

class _FakeSource implements ChatFolderSource {
  void Function(List<ChatFolder>)? push;
  final saved = <ChatFolder>[];
  bool fail = false;
  int _next = 0;

  @override
  Future<void Function()> subscribe({
    required void Function(List<ChatFolder> folders) onData,
    void Function(Object error)? onError,
  }) async {
    push = onData;
    return () {};
  }

  @override
  Future<String> save(ChatFolder folder) async {
    if (fail) throw StateError('nope');
    saved.add(folder);
    return folder.id.isEmpty ? 'f${_next++}' : folder.id;
  }

  @override
  Future<void> remove(String id) async {
    if (fail) throw StateError('nope');
  }

  @override
  Future<void> reorder(List<String> ids) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatFolder.matches', () {
    final dm = _room('a', dm: true);
    final group = _room('b');
    final unreadGroup = _room('c', unread: 2);
    final archivedDm = _room('d', dm: true, archived: true);

    test('kinds take rooms in, archived stays out by default', () {
      const f = ChatFolder(id: '1', name: 'DMs', dms: true);
      expect(f.matches(dm), isTrue);
      expect(f.matches(group), isFalse);
      expect(f.matches(archivedDm), isFalse);
      expect(
        f.copyWith(excludeArchived: false).matches(archivedDm),
        isTrue,
      );
    });

    test('exclude by hand beats everything; include by hand beats flags', () {
      const f = ChatFolder(
        id: '1',
        name: 'x',
        groups: true,
        excludeRead: true,
        include: ['b'],
        exclude: ['c'],
      );
      // Read, but picked by hand.
      expect(f.matches(group), isTrue);
      // Unread group, but kept out by hand.
      expect(f.matches(unreadGroup), isFalse);
    });

    test('excludeRead keeps only rooms with something unread', () {
      const f = ChatFolder(id: '1', name: 'Unread', dms: true, groups: true,
          excludeRead: true);
      expect(f.apply([dm, group, unreadGroup]).map((r) => r.id), ['c']);
      expect(f.unreadCount([dm, group, unreadGroup]), 1);
    });

    test('json round-trips', () {
      const f = ChatFolder(
        id: '9',
        name: 'Work',
        emoji: '💼',
        color: 3,
        groups: true,
        include: ['a'],
      );
      expect(ChatFolder.fromJson(f.toJson().cast()), f);
    });
  });

  group('ChatFolderStore', () {
    test('save shows at once, rolls back when the server refuses', () async {
      final src = _FakeSource();
      final store = ChatFolderStore.test(src);
      await store.attach();
      src.push!([]);
      src.fail = true;
      final saving = store.save(const ChatFolder(id: '', name: 'A', dms: true));
      expect(store.folders.map((f) => f.name), ['A']);
      await expectLater(saving, throwsStateError);
      expect(store.folders, isEmpty);
    });

    test('refuses past the cap without asking the server', () async {
      final src = _FakeSource();
      final store = ChatFolderStore.test(src);
      await store.attach();
      src.push!([
        for (var i = 0; i < kMaxChatFolders; i++)
          ChatFolder(id: 'f$i', name: 'F$i', dms: true),
      ]);
      expect(store.atCap, isTrue);
      await expectLater(
        store.save(const ChatFolder(id: '', name: 'one more', dms: true)),
        throwsStateError,
      );
      expect(src.saved, isEmpty);
    });

    test('removing a room the folder takes by kind keeps it out by hand',
        () async {
      final src = _FakeSource();
      final store = ChatFolderStore.test(src);
      await store.attach();
      const f = ChatFolder(id: 'f', name: 'DMs', dms: true);
      src.push!([f]);
      final dm = _room('a', dm: true);
      unawaited(store.toggleRoom(f, dm, add: false));
      await Future<void>.delayed(Duration.zero);
      expect(src.saved.single.exclude, ['a']);
      expect(src.saved.single.include, isEmpty);

      // A hand-picked room just leaves the include list.
      const g = ChatFolder(id: 'g', name: 'Picked', include: ['b']);
      src.push!([g]);
      unawaited(store.toggleRoom(g, _room('b'), add: false));
      await Future<void>.delayed(Duration.zero);
      expect(src.saved.last.include, isEmpty);
      expect(src.saved.last.exclude, isEmpty);
    });
  });
}
