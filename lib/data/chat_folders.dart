import 'dart:ui' show Color;

import '../models/chat_room.dart';

/// Folders per account. Mirrors `MAX_FOLDERS` in backend/convex/chatFolders.ts.
const int kMaxChatFolders = 10;

/// Rooms added by hand to one folder, and kept out by hand, each. Mirrors
/// `MAX_FOLDER_ROOMS`.
const int kMaxFolderRooms = 100;

/// Folder name length. Mirrors `MAX_FOLDER_NAME`.
const int kMaxFolderName = 24;

/// The folder-tag palette, Telegram's seven. A folder stores an index into
/// it (`chatFolders.color`), so the order here is part of the data: append,
/// never reorder. Each entry is (light, dark).
const List<(Color, Color)> kFolderTagColors = [
  (Color(0xFFE5484D), Color(0xFFFF6369)), // red
  (Color(0xFFF76808), Color(0xFFFF8B3E)), // orange
  (Color(0xFF8E4EC6), Color(0xFFB57FE8)), // violet
  (Color(0xFF30A46C), Color(0xFF4CC38A)), // green
  (Color(0xFF05A2C2), Color(0xFF3DC8E5)), // cyan
  (Color(0xFF0090FF), Color(0xFF52A9FF)), // blue
  (Color(0xFFD6409F), Color(0xFFF26BB8)), // pink
];

Color folderTagColor(int index, {required bool dark}) {
  final c = kFolderTagColors[index.clamp(0, kFolderTagColors.length - 1)];
  return dark ? c.$2 : c.$1;
}

/// One chat folder: a named rule over the chat list, not a copy of it.
///
/// A room is in the folder when it was added by hand ([include]), or when
/// its kind is taken in ([dms], [groups]) and none of the "leave out"
/// switches drop it. A room kept out by hand ([exclude]) never is. Same
/// precedence as Telegram's `include_peers` / `exclude_peers`.
class ChatFolder {
  const ChatFolder({
    required this.id,
    required this.name,
    this.emoji,
    this.color,
    this.dms = false,
    this.groups = false,
    this.excludeMuted = false,
    this.excludeRead = false,
    this.excludeArchived = true,
    this.include = const [],
    this.exclude = const [],
  });

  /// Empty for a folder being drawn up that the server has not saved yet.
  final String id;
  final String name;
  final String? emoji;

  /// Index into [kFolderTagColors]; null draws no tag.
  final int? color;
  final bool dms;
  final bool groups;
  final bool excludeMuted;
  final bool excludeRead;
  final bool excludeArchived;
  final List<String> include;
  final List<String> exclude;

  /// Whether the folder takes in anything at all. The server refuses one
  /// that does not (`FOLDER_EMPTY`).
  bool get takesAnything => dms || groups || include.isNotEmpty;

  bool matches(ChatRoom r) {
    if (exclude.contains(r.id)) return false;
    if (include.contains(r.id)) return true;
    final kind = r.isDm ? dms : groups;
    if (!kind) return false;
    if (excludeArchived && r.isArchived) return false;
    if (excludeMuted && r.isMuted) return false;
    if (excludeRead && !r.hasUnread) return false;
    return true;
  }

  /// Keeps [rooms]' order: the server's recency sort, as [RoomFilter.apply].
  List<ChatRoom> apply(Iterable<ChatRoom> rooms) =>
      rooms.where(matches).toList(growable: false);

  /// Rooms in the folder with something unread: the number on its tab.
  int unreadCount(Iterable<ChatRoom> rooms) {
    var n = 0;
    for (final r in rooms) {
      if (r.hasUnread && matches(r)) n++;
    }
    return n;
  }

  ChatFolder copyWith({
    String? id,
    String? name,
    String? Function()? emoji,
    int? Function()? color,
    bool? dms,
    bool? groups,
    bool? excludeMuted,
    bool? excludeRead,
    bool? excludeArchived,
    List<String>? include,
    List<String>? exclude,
  }) => ChatFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji != null ? emoji() : this.emoji,
    color: color != null ? color() : this.color,
    dms: dms ?? this.dms,
    groups: groups ?? this.groups,
    excludeMuted: excludeMuted ?? this.excludeMuted,
    excludeRead: excludeRead ?? this.excludeRead,
    excludeArchived: excludeArchived ?? this.excludeArchived,
    include: include ?? this.include,
    exclude: exclude ?? this.exclude,
  );

  /// The fields `chatFolders:save` takes, without the id.
  Map<String, Object?> toArgs() => {
    'name': name,
    'emoji': ?emoji,
    'color': ?color,
    'dms': dms,
    'groups': groups,
    'excludeMuted': excludeMuted,
    'excludeRead': excludeRead,
    'excludeArchived': excludeArchived,
    'include': include,
    'exclude': exclude,
  };

  Map<String, Object?> toJson() => {'id': id, ...toArgs()};

  static ChatFolder fromJson(Map<String, dynamic> m) => ChatFolder(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    emoji: m['emoji'] as String?,
    color: (m['color'] as num?)?.toInt(),
    dms: m['dms'] == true,
    groups: m['groups'] == true,
    excludeMuted: m['excludeMuted'] == true,
    excludeRead: m['excludeRead'] == true,
    excludeArchived: m['excludeArchived'] != false,
    include: [for (final e in (m['include'] as List? ?? const [])) '$e'],
    exclude: [for (final e in (m['exclude'] as List? ?? const [])) '$e'],
  );

  static List<ChatFolder> parseList(Object? raw) => [
    if (raw is List)
      for (final e in raw)
        if (e is Map) ChatFolder.fromJson(e.cast<String, dynamic>()),
  ];

  @override
  bool operator ==(Object other) =>
      other is ChatFolder &&
      other.id == id &&
      other.name == name &&
      other.emoji == emoji &&
      other.color == color &&
      other.dms == dms &&
      other.groups == groups &&
      other.excludeMuted == excludeMuted &&
      other.excludeRead == excludeRead &&
      other.excludeArchived == excludeArchived &&
      _sameList(other.include, include) &&
      _sameList(other.exclude, exclude);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    emoji,
    color,
    dms,
    groups,
    excludeMuted,
    excludeRead,
    excludeArchived,
    Object.hashAll(include),
    Object.hashAll(exclude),
  );

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Telegram's suggested folders, adapted to what a room here can be. The
/// folders screen offers each one the account does not already have
/// something equivalent to.
enum SuggestedFolder { unread, personal, groups }
