import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
import '../models/chat_room.dart';
import 'chat_folders.dart';
import 'settings_store.dart';

/// What [ChatFolderStore] needs from the backend. A seam so tests drive the
/// store and the screens with a fake instead of a socket.
abstract class ChatFolderSource {
  Future<void Function()> subscribe({
    required void Function(List<ChatFolder> folders) onData,
    void Function(Object error)? onError,
  });

  /// Creates (empty [ChatFolder.id]) or rewrites a folder; the folder's id.
  Future<String> save(ChatFolder folder);
  Future<void> remove(String id);
  Future<void> reorder(List<String> ids);
}

/// Client for `chatFolders:*` (backend/convex/chatFolders.ts). Authed through
/// the session token, so nothing here passes a user id.
class ChatFolderApi implements ChatFolderSource {
  ChatFolderApi(this._cv);
  final ConvexBackend _cv;

  static final ChatFolderApi shared = ChatFolderApi(ConvexBackend.instance);

  @override
  Future<void Function()> subscribe({
    required void Function(List<ChatFolder> folders) onData,
    void Function(Object error)? onError,
  }) async {
    final sub = await _cv.subscribe(
      'chatFolders:list',
      const {},
      onData: (raw) => onData(ChatFolder.parseList(raw)),
      onError: onError,
    );
    return sub.cancel;
  }

  @override
  Future<String> save(ChatFolder folder) async {
    final res = await _cv.mutation('chatFolders:save', {
      if (folder.id.isNotEmpty) 'id': folder.id,
      ...folder.toArgs(),
    });
    return '$res';
  }

  @override
  Future<void> remove(String id) =>
      _cv.mutation('chatFolders:remove', {'id': id});

  @override
  Future<void> reorder(List<String> ids) =>
      _cv.mutation('chatFolders:reorder', {'ids': ids});
}

/// The account's chat folders: one shared subscription, attached at sign-in
/// and dropped at sign-out, plus optimistic edits so a tab appears, moves or
/// goes the moment it is tapped and comes back if the server refuses.
///
/// The folder list is cached in [SettingsStore.chatFoldersCache] so the tabs
/// are on screen at a cold start, before the subscription answers.
class ChatFolderStore extends ChangeNotifier {
  ChatFolderStore._(this._source);

  static final ChatFolderStore instance = ChatFolderStore._(
    ChatFolderApi.shared,
  );

  @visibleForTesting
  factory ChatFolderStore.test(ChatFolderSource source) = ChatFolderStore._;

  final ChatFolderSource _source;

  List<ChatFolder> _server = const [];

  /// Local edits not yet echoed back: a whole list that wins over the
  /// server's until the next push arrives after the write settles.
  List<ChatFolder>? _pending;
  int _writes = 0;
  bool _loaded = false;
  void Function()? _cancel;
  int _gen = 0;

  /// Folders in tab order, with taps not yet confirmed.
  List<ChatFolder> get folders => _pending ?? _server;

  bool get loaded => _loaded;
  bool get atCap => folders.length >= kMaxChatFolders;

  ChatFolder? byId(String? id) {
    if (id == null) return null;
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The folder the chat list is on, or null for All Chats. A remembered id
  /// whose folder was deleted (here or on another device) reads as All.
  ChatFolder? get active => byId(SettingsStore.instance.activeFolderId);

  @visibleForTesting
  void debugSeed(List<ChatFolder> folders) {
    _server = folders;
    _pending = null;
    _loaded = true;
    notifyListeners();
  }

  Future<void> attach() async {
    if (_cancel != null) return;
    final gen = ++_gen;
    final cached = SettingsStore.instance.chatFoldersCache;
    if (cached != null && _server.isEmpty) {
      try {
        _server = ChatFolder.parseList(jsonDecode(cached));
        notifyListeners();
      } catch (_) {}
    }
    try {
      final cancel = await _source.subscribe(
        onData: (list) {
          if (gen != _gen) return;
          _server = list;
          _loaded = true;
          if (_writes == 0) _pending = null;
          unawaited(
            SettingsStore.instance.setChatFoldersCache(
              jsonEncode([for (final f in list) f.toJson()]),
            ),
          );
          notifyListeners();
        },
        onError: (_) {
          if (gen != _gen) return;
          _loaded = true;
          notifyListeners();
        },
      );
      if (gen != _gen) {
        cancel();
      } else {
        _cancel = cancel;
      }
    } catch (_) {
      if (gen == _gen) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  /// Drops the subscription and this account's folders, cache included:
  /// they name the account's chats and must not show for the next sign-in.
  Future<void> detach() async {
    _gen++;
    _cancel?.call();
    _cancel = null;
    _server = const [];
    _pending = null;
    _writes = 0;
    _loaded = false;
    notifyListeners();
    await SettingsStore.instance.setChatFoldersCache(null);
    await SettingsStore.instance.setActiveFolder(null);
  }

  /// Runs [write] with [optimistic] on screen meanwhile; rolls back when it
  /// throws, and rethrows so the caller can say why.
  Future<T> _edit<T>(
    List<ChatFolder> optimistic,
    Future<T> Function() write,
  ) async {
    final before = _pending;
    _pending = optimistic;
    _writes++;
    notifyListeners();
    try {
      return await write();
    } catch (_) {
      _pending = before;
      rethrow;
    } finally {
      _writes--;
      // The server's echo of this write may already have landed while it
      // was in flight; once nothing is outstanding the server list is the
      // truth again.
      if (_writes == 0 && _loaded) _pending = null;
      notifyListeners();
    }
  }

  /// Creates [folder] (empty id) at the end of the tabs, or saves changes to
  /// an existing one. Returns the saved folder's id.
  Future<String> save(ChatFolder folder) {
    final list = [...folders];
    final at = folder.id.isEmpty
        ? -1
        : list.indexWhere((f) => f.id == folder.id);
    if (at >= 0) {
      list[at] = folder;
    } else {
      if (list.length >= kMaxChatFolders) {
        return Future.error(StateError('TOO_MANY_FOLDERS'));
      }
      list.add(folder);
    }
    return _edit(list, () => _source.save(folder));
  }

  Future<void> remove(String id) async {
    if (SettingsStore.instance.activeFolderId == id) {
      unawaited(SettingsStore.instance.setActiveFolder(null));
    }
    await _edit(
      [for (final f in folders) if (f.id != id) f],
      () => _source.remove(id),
    );
  }

  Future<void> reorder(List<String> ids) {
    final byId = {for (final f in folders) f.id: f};
    final list = [
      for (final id in ids) ?byId[id],
      for (final f in folders) if (!ids.contains(f.id)) f,
    ];
    return _edit(list, () => _source.reorder(ids));
  }

  /// Adds or removes one room by hand: the chat row's "Add to folder".
  /// Adding also lifts a hand-picked "keep out". Removing a room the folder
  /// would still take in by its kind keeps it out explicitly, as Telegram
  /// does; otherwise dropping it from the hand-picked list is enough.
  Future<void> toggleRoom(
    ChatFolder folder,
    ChatRoom room, {
    required bool add,
  }) {
    final include = [...folder.include]..remove(room.id);
    final exclude = [...folder.exclude]..remove(room.id);
    if (add) {
      if (include.length >= kMaxFolderRooms) {
        return Future.error(StateError('TOO_MANY_FOLDER_ROOMS'));
      }
      include.add(room.id);
    } else {
      final rest = folder.copyWith(include: include, exclude: exclude);
      if (rest.matches(room)) {
        if (exclude.length >= kMaxFolderRooms) {
          return Future.error(StateError('TOO_MANY_FOLDER_ROOMS'));
        }
        exclude.add(room.id);
      }
    }
    return save(folder.copyWith(include: include, exclude: exclude));
  }
}
