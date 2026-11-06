import 'package:flutter/widgets.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../models/chat_room.dart';
import '../../models/chat_user.dart';
import '../navigation/open_room.dart' as nav;

/// What the Calls tab needs to know about rooms and people, and the two things
/// it asks the app to do (open a chat, find or create a DM). The tab never
/// copies profile data: it resolves a row's room and peer here, at build time,
/// from what the app already holds. A seam so widget tests need no repository.
abstract class CallsDirectory implements Listenable {
  String? get myId;
  ChatRoom? room(String id);
  ChatUser? user(String id);

  /// Friends, for the new-call picker.
  List<ChatUser> get friends;

  /// Every room the user is in, for finding a DM.
  Iterable<ChatRoom> get rooms;

  /// The DM room with [friend], created when there is none yet.
  Future<String> dmRoomWith(ChatUser friend);

  void openChat(BuildContext context, String roomId);
}

/// [CallsDirectory] over the app's [ChatRepository].
class RepoCallsDirectory implements CallsDirectory {
  RepoCallsDirectory(this.repo, this.api);
  final ChatRepository repo;
  final ChatApi api;

  @override
  String? get myId => repo.userId;
  @override
  ChatRoom? room(String id) => repo.roomById(id);
  @override
  ChatUser? user(String id) => repo.userById(id);
  @override
  List<ChatUser> get friends => repo.friends;
  @override
  Iterable<ChatRoom> get rooms => repo.activeRooms;

  @override
  Future<String> dmRoomWith(ChatUser friend) async {
    for (final r in repo.activeRooms) {
      if (r.isDm && !r.isSavedMessages && r.participantIds.contains(friend.id)) {
        return r.id;
      }
    }
    return repo.openDmWith(friend);
  }

  @override
  void openChat(BuildContext context, String roomId) =>
      nav.openRoom(context, roomId: roomId, repo: repo, api: api);

  @override
  void addListener(VoidCallback listener) => repo.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => repo.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is RepoCallsDirectory && other.repo == repo && other.api == api;
  @override
  int get hashCode => Object.hash(repo, api);
}
