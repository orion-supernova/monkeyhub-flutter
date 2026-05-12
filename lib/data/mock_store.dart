import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/room.dart';
import '../models/message.dart';
import '../models/requests.dart';

class MockStore extends ChangeNotifier {
  MockStore._() {
    _seed();
  }
  static final MockStore instance = MockStore._();

  late final User me;
  final List<User> users = [];
  final List<Room> rooms = [];
  final List<Message> messages = [];
  final List<FriendRequest> friendRequests = [];
  final List<RoomInvite> roomInvites = [];
  final Set<String> friendIds = {};

  void _seed() {
    me = User(
      id: 'u_me',
      name: 'Kio Ashford',
      handle: '@kio',
      avatarSeed: 17,
      isPublic: true,
      bio: 'late-night designer · collects fonts and stones',
    );

    users.addAll([
      me,
      User(id: 'u_iris', name: 'Iris Calder', handle: '@iris.calder', avatarSeed: 3, isPublic: true, bio: 'sound artist · berlin'),
      User(id: 'u_nael', name: 'Nael Hoffmann', handle: '@nael', avatarSeed: 9, isPublic: true, bio: 'reads too much · cooks slow'),
      User(id: 'u_mira', name: 'Mira Okonkwo', handle: '@mira_o', avatarSeed: 22, isPublic: false, bio: 'private studio · serif enthusiast'),
      User(id: 'u_dax',  name: 'Dax Ferreira', handle: '@dax.fr', avatarSeed: 41, isPublic: true, bio: 'climber, archivist, midnight typist'),
      User(id: 'u_yuki', name: 'Yuki Tanabe', handle: '@yuki', avatarSeed: 14, isPublic: false, bio: 'private — invite only'),
      User(id: 'u_rae',  name: 'Rae Linwood', handle: '@rae.lin', avatarSeed: 27, isPublic: true, bio: 'ceramics, opinions, plums'),
      User(id: 'u_omar', name: 'Omar Vance',  handle: '@ovance',  avatarSeed: 33, isPublic: true, bio: 'systems thinker, light sleeper'),
    ]);

    friendIds.addAll(['u_iris', 'u_nael', 'u_dax', 'u_rae']);

    rooms.addAll([
      Room(
        id: 'r_vanish',
        name: 'vanishing ink',
        description: 'whatever you say here, the server forgets.',
        topic: 'thoughts unfit for the archive',
        visibility: RoomVisibility.private,
        type: RoomType.ephemeral,
        ttl: const Duration(seconds: 30),
        memberIds: ['u_me', 'u_iris', 'u_nael', 'u_dax'],
      ),
      Room(
        id: 'r_studio',
        name: 'studio late-night',
        description: 'open studio — drop in, share what you\'re making',
        topic: 'design crit · type · color',
        visibility: RoomVisibility.public,
        type: RoomType.standard,
        memberIds: ['u_me', 'u_iris', 'u_nael', 'u_rae', 'u_omar', 'u_dax'],
      ),
      Room(
        id: 'r_sunday',
        name: 'sunday cooking',
        description: 'low and slow. share what\'s on the stove.',
        topic: 'kitchen things',
        visibility: RoomVisibility.public,
        type: RoomType.standard,
        memberIds: ['u_me', 'u_nael', 'u_rae'],
      ),
      Room(
        id: 'r_burnafter',
        name: 'burn after reading',
        description: 'one-minute messages. nothing stays.',
        topic: 'the dossier',
        visibility: RoomVisibility.private,
        type: RoomType.ephemeral,
        ttl: const Duration(seconds: 60),
        memberIds: ['u_me', 'u_dax', 'u_omar'],
      ),
      Room(
        id: 'r_archive',
        name: 'the archive',
        description: 'links, notes, anything worth keeping',
        topic: 'reading lists & references',
        visibility: RoomVisibility.private,
        type: RoomType.standard,
        memberIds: ['u_me', 'u_iris', 'u_mira'],
      ),
    ]);

    final now = DateTime.now();
    DateTime t(int sAgo) => now.subtract(Duration(seconds: sAgo));

    // Standard room messages
    messages.addAll([
      Message(id: 'm1', roomId: 'r_studio', authorId: 'u_iris', text: 'just laid out the new poster — the kerning is alive', createdAt: t(640)),
      Message(id: 'm2', roomId: 'r_studio', authorId: 'u_me',   text: 'send a peek?', createdAt: t(610)),
      Message(id: 'm3', roomId: 'r_studio', authorId: 'u_nael', text: 'I\'m biased but the italic is the right call', createdAt: t(540)),
      Message(id: 'm4', roomId: 'r_studio', authorId: 'u_rae',  text: 'serifs on a friday, simply pure', createdAt: t(420)),
      Message(id: 'm5', roomId: 'r_studio', authorId: 'u_me',   text: 'going to stay up and finish this one', createdAt: t(120)),
      Message(id: 'm6', roomId: 'r_studio', authorId: 'u_dax',  text: 'I owe you a cup of something', createdAt: t(45)),

      Message(id: 'm7', roomId: 'r_sunday', authorId: 'u_nael', text: 'lamb shoulder — eight hours. trust the process.', createdAt: t(7200)),
      Message(id: 'm8', roomId: 'r_sunday', authorId: 'u_rae',  text: 'making sourdough focaccia. olive oil situation is dramatic.', createdAt: t(5400)),
      Message(id: 'm9', roomId: 'r_sunday', authorId: 'u_me',   text: 'I have feelings about the focaccia', createdAt: t(3000)),
      Message(id: 'm10', roomId: 'r_sunday', authorId: 'u_nael', text: 'come over at 7', createdAt: t(1200)),

      Message(id: 'm11', roomId: 'r_archive', authorId: 'u_iris', text: 'this essay on attention by jenny odell — worth the slow read', createdAt: t(86400)),
      Message(id: 'm12', roomId: 'r_archive', authorId: 'u_mira', text: 'I keep coming back to it', createdAt: t(72000)),
      Message(id: 'm13', roomId: 'r_archive', authorId: 'u_me',  text: 'adding it to the shelf for the studio', createdAt: t(64800)),
    ]);

    // Ephemeral room — vanishing ink (30s TTL)
    messages.addAll([
      Message(id: 'e1', roomId: 'r_vanish', authorId: 'u_iris', text: 'I\'m about to send something I won\'t want kept', createdAt: t(28), ttl: const Duration(seconds: 30)),
      Message(id: 'e2', roomId: 'r_vanish', authorId: 'u_me',   text: 'go',  createdAt: t(22), ttl: const Duration(seconds: 30)),
      Message(id: 'e3', roomId: 'r_vanish', authorId: 'u_iris', text: 'I think I\'m leaving the agency next month. nobody else knows yet.', createdAt: t(18), ttl: const Duration(seconds: 30)),
      Message(id: 'e4', roomId: 'r_vanish', authorId: 'u_dax',  text: 'good. you\'ve outgrown that room.', createdAt: t(12), ttl: const Duration(seconds: 30)),
      Message(id: 'e5', roomId: 'r_vanish', authorId: 'u_nael', text: 'whatever you do, write the letter long.', createdAt: t(6), ttl: const Duration(seconds: 30)),
      Message(id: 'e6', roomId: 'r_vanish', authorId: 'u_me',   text: 'noted. burning this thread in three two', createdAt: t(2), ttl: const Duration(seconds: 30)),
    ]);

    // Ephemeral room — burn after reading (60s TTL)
    messages.addAll([
      Message(id: 'b1', roomId: 'r_burnafter', authorId: 'u_omar', text: 'the venue confirmed. friday. don\'t put it in any thread that lives.', createdAt: t(58), ttl: const Duration(seconds: 60)),
      Message(id: 'b2', roomId: 'r_burnafter', authorId: 'u_me',   text: 'understood. delete this too.', createdAt: t(40), ttl: const Duration(seconds: 60)),
      Message(id: 'b3', roomId: 'r_burnafter', authorId: 'u_dax',  text: 'I\'ll bring the rest in person.', createdAt: t(15), ttl: const Duration(seconds: 60)),
    ]);

    friendRequests.addAll([
      FriendRequest(id: 'fr1', fromUserId: 'u_omar', toUserId: 'u_me', sentAt: t(3600), note: 'met you at the typography meet — would be good to keep in touch'),
      FriendRequest(id: 'fr2', fromUserId: 'u_mira', toUserId: 'u_me', sentAt: t(86400 * 2)),
      FriendRequest(id: 'fr3', fromUserId: 'u_yuki', toUserId: 'u_me', sentAt: t(86400 * 4), note: 'private profile — let\'s start small'),
    ]);

    roomInvites.addAll([
      RoomInvite(id: 'ri1', roomId: 'r_archive', fromUserId: 'u_iris', toUserId: 'u_me', sentAt: t(7200)),
      RoomInvite(id: 'ri2', roomId: 'r_studio',  fromUserId: 'u_dax',  toUserId: 'u_me', sentAt: t(86400)),
    ]);
  }

  // --- Helpers ----------------------------------------------------

  User userById(String id) => users.firstWhere((u) => u.id == id);
  Room? roomById(String id) => rooms.cast<Room?>().firstWhere((r) => r?.id == id, orElse: () => null);

  List<Room> roomsForMe() {
    return rooms.where((r) => r.memberIds.contains(me.id)).toList()
      ..sort((a, b) {
        // Pin ephemeral first then by last activity
        if (a.isEphemeral != b.isEphemeral) return a.isEphemeral ? -1 : 1;
        return lastActivityFor(b).compareTo(lastActivityFor(a));
      });
  }

  DateTime lastActivityFor(Room room) {
    final ms = messages.where((m) => m.roomId == room.id);
    if (ms.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return ms.map((m) => m.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Message? lastMessageFor(Room room) {
    final ms = messages.where((m) => m.roomId == room.id).toList();
    if (ms.isEmpty) return null;
    ms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ms.first;
  }

  List<Message> messagesFor(String roomId, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return messages
        .where((m) => m.roomId == roomId)
        .where((m) => m.expiresAt == null || m.expiresAt!.isAfter(n))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  // Mutations
  void setUserVisibility(User user, bool isPublic) {
    user.isPublic = isPublic;
    notifyListeners();
  }

  void purgeExpiredMessages([DateTime? now]) {
    final n = now ?? DateTime.now();
    final before = messages.length;
    messages.removeWhere((m) => m.expiresAt != null && m.expiresAt!.isBefore(n));
    if (messages.length != before) notifyListeners();
  }

  String sendMessage(String roomId, String text) {
    final room = roomById(roomId);
    if (room == null) return '';
    final id = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final msg = Message(
      id: id,
      roomId: roomId,
      authorId: me.id,
      text: text,
      createdAt: DateTime.now(),
      ttl: room.isEphemeral ? room.ttl : null,
    );
    messages.add(msg);
    notifyListeners();
    return id;
  }

  Room createRoom({
    required String name,
    required RoomVisibility visibility,
    required RoomType type,
    Duration? ttl,
    String? description,
  }) {
    final room = Room(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      visibility: visibility,
      type: type,
      ttl: type == RoomType.ephemeral ? ttl : null,
      memberIds: [me.id],
      description: description,
    );
    rooms.add(room);
    notifyListeners();
    return room;
  }

  void resolveFriendRequest(String requestId, {required bool accept}) {
    final i = friendRequests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    final req = friendRequests[i];
    req.status = accept ? RequestStatus.accepted : RequestStatus.declined;
    if (accept) friendIds.add(req.fromUserId);
    friendRequests.removeAt(i);
    notifyListeners();
  }

  void resolveRoomInvite(String inviteId, {required bool accept}) {
    final i = roomInvites.indexWhere((r) => r.id == inviteId);
    if (i < 0) return;
    final inv = roomInvites[i];
    if (accept) {
      final room = roomById(inv.roomId);
      if (room != null && !room.memberIds.contains(me.id)) {
        room.memberIds.add(me.id);
      }
    }
    roomInvites.removeAt(i);
    notifyListeners();
  }

  List<User> searchUsers(String q) {
    final n = q.trim().toLowerCase();
    if (n.isEmpty) return users.where((u) => u.id != me.id && u.isPublic).toList();
    return users.where((u) {
      if (u.id == me.id) return false;
      // private users are not discoverable unless already friends
      if (!u.isPublic && !friendIds.contains(u.id)) return false;
      return u.name.toLowerCase().contains(n) || u.handle.toLowerCase().contains(n);
    }).toList();
  }

  List<Room> searchRooms(String q) {
    final n = q.trim().toLowerCase();
    final discoverable = rooms.where((r) => r.isPublic).toList();
    if (n.isEmpty) return discoverable;
    return discoverable.where((r) =>
        r.name.toLowerCase().contains(n) ||
        (r.description ?? '').toLowerCase().contains(n)).toList();
  }
}
