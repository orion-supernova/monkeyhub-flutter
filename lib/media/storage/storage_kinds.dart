/// The vocabulary the Data and Storage area speaks: what kind of bytes a cached
/// file is, what kind of chat it came from, and which network moved it.
///
/// Its own file because everything in `lib/media/storage/` and every screen in
/// `lib/screens/data_storage/` names these, and none of them should have to
/// import the others to do it.
library;

/// What a cached file is, for the storage breakdown and the data usage
/// counters alike. Order is the order rows are listed in when two kinds are
/// the same size.
enum StorageKind {
  photos,
  videos,
  videoMessages,
  voice,
  files,
  stickers,

  /// The offline copy of chats: transcripts, member lists, room list. Shown
  /// so the total is honest; clearing it costs a re-sync, never a message.
  chatHistory,

  /// Sebastian's and Marlowe's on-device brains and the translation cache.
  /// Counted so the total is the truth, but never cleared from here: a brain
  /// is a deliberate multi-gigabyte download, not a cache. Its own pages
  /// manage it.
  companions,

  /// Avatars, link previews, room covers: anything the app fetched that no
  /// message owns.
  other;

  static final _byName = values.asNameMap();
  static StorageKind? parse(String? s) => _byName[s];

  /// Whether this kind belongs to a message and so to a chat. The per chat
  /// breakdown only counts these.
  bool get isMessageMedia => switch (this) {
        chatHistory || companions || other => false,
        _ => true,
      };

  /// Whether Clear Cache may delete it.
  bool get isClearable => this != companions;
}

/// The three shapes of conversation the rules are written against: Telegram's
/// private chats / groups / channels, in this app's terms. A public room is
/// the closest thing to a channel: strangers, volume, media you didn't ask for.
enum ChatClass {
  privateChats,
  groups,
  publicRooms;

  static final _byName = values.asNameMap();
  static ChatClass? parse(String? s) => _byName[s];
}

/// The network a transfer happened on. Ethernet and anything unidentified
/// count as Wi-Fi: the question every rule here answers is "is this costing
/// someone their data plan", and only a cellular radio does.
enum NetKind {
  cellular,
  wifi;

  static final _byName = values.asNameMap();
  static NetKind? parse(String? s) => _byName[s];
}

/// How long untouched media is kept before the sweeper reclaims it.
enum KeepMedia {
  forever(null),
  month(Duration(days: 30)),
  week(Duration(days: 7)),
  day(Duration(days: 1));

  const KeepMedia(this.duration);
  final Duration? duration;

  static final _byName = values.asNameMap();
  static KeepMedia? parse(String? s) => _byName[s];
}

/// The cache ceiling. Null bytes is no limit.
enum CacheLimit {
  gb1(1),
  gb5(5),
  gb20(20),
  unlimited(null);

  const CacheLimit(this.gigabytes);
  final int? gigabytes;

  int? get bytes {
    final g = gigabytes;
    return g == null ? null : g * 1024 * 1024 * 1024;
  }

  static final _byName = values.asNameMap();
  static CacheLimit? parse(String? s) => _byName[s];
}

/// When calls trade quality for data.
enum CallDataSaver {
  never,
  cellular,
  always;

  static final _byName = values.asNameMap();
  static CallDataSaver? parse(String? s) => _byName[s];
}
