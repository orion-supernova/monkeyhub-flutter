import 'storage_kinds.dart';

const int _mb = 1024 * 1024;

/// One media type's auto-download rule on one network: which kinds of chat it
/// applies in, and (for videos and files) how big a file may be.
class MediaRule {
  const MediaRule({required this.chats, this.maxBytes = 0});

  final Set<ChatClass> chats;

  /// Ignored for photos, which are always small after the send-side cap.
  final int maxBytes;

  bool get isOff => chats.isEmpty;

  bool allows(ChatClass chat, {int? bytes}) {
    if (!chats.contains(chat)) return false;
    // An unknown size is allowed through; the download itself enforces
    // [maxBytes] from the response's length, so a big file is cut off there.
    return bytes == null || maxBytes <= 0 || bytes <= maxBytes;
  }

  MediaRule copyWith({Set<ChatClass>? chats, int? maxBytes}) => MediaRule(
        chats: chats ?? this.chats,
        maxBytes: maxBytes ?? this.maxBytes,
      );

  Map<String, Object?> toJson() => {
        'c': [for (final c in chats) c.name],
        'm': maxBytes,
      };

  static MediaRule fromJson(Object? j, MediaRule fallback) {
    if (j is! Map) return fallback;
    final raw = j['c'];
    final chats = raw is List
        ? {for (final s in raw) ?ChatClass.parse(s as String?)}
        : fallback.chats;
    final m = j['m'];
    return MediaRule(chats: chats, maxBytes: m is int ? m : fallback.maxBytes);
  }

  @override
  bool operator ==(Object other) =>
      other is MediaRule &&
      other.maxBytes == maxBytes &&
      other.chats.length == chats.length &&
      other.chats.containsAll(chats);

  @override
  int get hashCode => Object.hash(maxBytes, Object.hashAllUnordered(chats));
}

/// The three steps of the "Data usage" slider.
enum DownloadPreset { low, medium, high }

/// Every auto-download rule for one network.
class NetworkDownloadPrefs {
  const NetworkDownloadPrefs({
    required this.enabled,
    required this.photos,
    required this.videos,
    required this.files,
  });

  final bool enabled;
  final MediaRule photos;

  /// Videos and round video messages alike.
  final MediaRule videos;
  final MediaRule files;

  static const _all = {
    ChatClass.privateChats,
    ChatClass.groups,
    ChatClass.publicRooms,
  };

  /// The preset bundles. Medium differs by network the way Telegram's does:
  /// Wi-Fi is cheaper, so its middle step reaches further.
  static NetworkDownloadPrefs preset(DownloadPreset p, NetKind net) =>
      switch (p) {
        DownloadPreset.low => const NetworkDownloadPrefs(
            enabled: true,
            photos: MediaRule(chats: {ChatClass.privateChats}),
            videos: MediaRule(chats: {}, maxBytes: 5 * _mb),
            files: MediaRule(chats: {}, maxBytes: 1 * _mb),
          ),
        DownloadPreset.medium => NetworkDownloadPrefs(
            enabled: true,
            photos: const MediaRule(chats: _all),
            videos: MediaRule(
              chats: _all,
              maxBytes: (net == NetKind.wifi ? 15 : 10) * _mb,
            ),
            files: MediaRule(
              chats: _all,
              maxBytes: (net == NetKind.wifi ? 3 : 1) * _mb,
            ),
          ),
        DownloadPreset.high => const NetworkDownloadPrefs(
            enabled: true,
            photos: MediaRule(chats: _all),
            videos: MediaRule(chats: _all, maxBytes: 48 * _mb),
            files: MediaRule(chats: _all, maxBytes: 20 * _mb),
          ),
      };

  /// Which preset this is, or null once someone has customised a type.
  DownloadPreset? presetFor(NetKind net) {
    for (final p in DownloadPreset.values) {
      final ref = preset(p, net);
      if (ref.photos == photos && ref.videos == videos && ref.files == files) {
        return p;
      }
    }
    return null;
  }

  NetworkDownloadPrefs copyWith({
    bool? enabled,
    MediaRule? photos,
    MediaRule? videos,
    MediaRule? files,
  }) =>
      NetworkDownloadPrefs(
        enabled: enabled ?? this.enabled,
        photos: photos ?? this.photos,
        videos: videos ?? this.videos,
        files: files ?? this.files,
      );

  Map<String, Object?> toJson() => {
        'on': enabled,
        'p': photos.toJson(),
        'v': videos.toJson(),
        'f': files.toJson(),
      };

  static NetworkDownloadPrefs fromJson(Object? j, NetworkDownloadPrefs d) {
    if (j is! Map) return d;
    return NetworkDownloadPrefs(
      enabled: j['on'] is bool ? j['on'] as bool : d.enabled,
      photos: MediaRule.fromJson(j['p'], d.photos),
      videos: MediaRule.fromJson(j['v'], d.videos),
      files: MediaRule.fromJson(j['f'], d.files),
    );
  }
}

/// Save-to-Photos for one kind of chat.
class SaveToPhotos {
  const SaveToPhotos({
    this.photos = false,
    this.videos = false,
    this.maxVideoBytes = 48 * _mb,
  });

  final bool photos;
  final bool videos;
  final int maxVideoBytes;

  bool get isOff => !photos && !videos;

  SaveToPhotos copyWith({bool? photos, bool? videos, int? maxVideoBytes}) =>
      SaveToPhotos(
        photos: photos ?? this.photos,
        videos: videos ?? this.videos,
        maxVideoBytes: maxVideoBytes ?? this.maxVideoBytes,
      );

  Map<String, Object?> toJson() =>
      {'p': photos, 'v': videos, 'm': maxVideoBytes};

  static SaveToPhotos fromJson(Object? j) {
    if (j is! Map) return const SaveToPhotos();
    return SaveToPhotos(
      photos: j['p'] == true,
      videos: j['v'] == true,
      maxVideoBytes: j['m'] is int ? j['m'] as int : 48 * _mb,
    );
  }
}

/// Everything the Data and Storage screens configure, as one immutable value
/// persisted under one key. One key, not twenty, because the rules only make
/// sense together and are always written together.
class DataStoragePrefs {
  const DataStoragePrefs({
    required this.cellular,
    required this.wifi,
    required this.saveToPhotos,
    required this.keepMedia,
    required this.cacheLimit,
    required this.callDataSaver,
  });

  static final DataStoragePrefs defaults = DataStoragePrefs(
    cellular: NetworkDownloadPrefs.preset(DownloadPreset.medium, NetKind.cellular),
    wifi: NetworkDownloadPrefs.preset(DownloadPreset.medium, NetKind.wifi),
    saveToPhotos: const {},
    // A public room is a stream of strangers' media; a month untouched is a
    // sensible point to let it go. Conversations people chose are kept.
    keepMedia: const {ChatClass.publicRooms: KeepMedia.month},
    cacheLimit: CacheLimit.gb5,
    callDataSaver: CallDataSaver.never,
  );

  final NetworkDownloadPrefs cellular;
  final NetworkDownloadPrefs wifi;
  final Map<ChatClass, SaveToPhotos> saveToPhotos;
  final Map<ChatClass, KeepMedia> keepMedia;
  final CacheLimit cacheLimit;
  final CallDataSaver callDataSaver;

  NetworkDownloadPrefs downloadsOn(NetKind net) =>
      net == NetKind.cellular ? cellular : wifi;

  SaveToPhotos saveIn(ChatClass c) => saveToPhotos[c] ?? const SaveToPhotos();

  KeepMedia keepIn(ChatClass c) => keepMedia[c] ?? KeepMedia.forever;

  bool callsSaveData(NetKind net) => switch (callDataSaver) {
        CallDataSaver.never => false,
        CallDataSaver.cellular => net == NetKind.cellular,
        CallDataSaver.always => true,
      };

  DataStoragePrefs withDownloads(NetKind net, NetworkDownloadPrefs p) =>
      net == NetKind.cellular ? copyWith(cellular: p) : copyWith(wifi: p);

  DataStoragePrefs copyWith({
    NetworkDownloadPrefs? cellular,
    NetworkDownloadPrefs? wifi,
    Map<ChatClass, SaveToPhotos>? saveToPhotos,
    Map<ChatClass, KeepMedia>? keepMedia,
    CacheLimit? cacheLimit,
    CallDataSaver? callDataSaver,
  }) =>
      DataStoragePrefs(
        cellular: cellular ?? this.cellular,
        wifi: wifi ?? this.wifi,
        saveToPhotos: saveToPhotos ?? this.saveToPhotos,
        keepMedia: keepMedia ?? this.keepMedia,
        cacheLimit: cacheLimit ?? this.cacheLimit,
        callDataSaver: callDataSaver ?? this.callDataSaver,
      );

  Map<String, Object?> toJson() => {
        'cell': cellular.toJson(),
        'wifi': wifi.toJson(),
        'save': {
          for (final e in saveToPhotos.entries) e.key.name: e.value.toJson(),
        },
        'keep': {for (final e in keepMedia.entries) e.key.name: e.value.name},
        'limit': cacheLimit.name,
        'calls': callDataSaver.name,
      };

  static DataStoragePrefs fromJson(Object? j) {
    final d = defaults;
    if (j is! Map) return d;
    final save = <ChatClass, SaveToPhotos>{};
    final rawSave = j['save'];
    if (rawSave is Map) {
      for (final e in rawSave.entries) {
        final c = ChatClass.parse(e.key as String?);
        if (c != null) save[c] = SaveToPhotos.fromJson(e.value);
      }
    }
    Map<ChatClass, KeepMedia> keep = d.keepMedia;
    final rawKeep = j['keep'];
    if (rawKeep is Map) {
      keep = {
        for (final e in rawKeep.entries)
          ?ChatClass.parse(e.key as String?):
              ?KeepMedia.parse(e.value as String?),
      };
    }
    return DataStoragePrefs(
      cellular: NetworkDownloadPrefs.fromJson(j['cell'], d.cellular),
      wifi: NetworkDownloadPrefs.fromJson(j['wifi'], d.wifi),
      saveToPhotos: save,
      keepMedia: keep,
      cacheLimit: CacheLimit.parse(j['limit'] as String?) ?? d.cacheLimit,
      callDataSaver:
          CallDataSaver.parse(j['calls'] as String?) ?? d.callDataSaver,
    );
  }
}
