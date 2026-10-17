import 'dart:async';

import 'package:flutter/foundation.dart';

import 'json_file.dart';
import 'network_kind.dart';
import 'storage_kinds.dart';

/// What Data Usage tracks. Storage kinds plus calls, which move bytes but
/// never leave any on disk.
enum UsageKind {
  photos,
  videos,
  videoMessages,
  voice,
  files,
  stickers,
  calls,
  other;

  static final _byName = values.asNameMap();
  static UsageKind? parse(String? s) => _byName[s];

  static UsageKind of(StorageKind k) => switch (k) {
        StorageKind.photos => photos,
        StorageKind.videos => videos,
        StorageKind.videoMessages => videoMessages,
        StorageKind.voice => voice,
        StorageKind.files => files,
        StorageKind.stickers => stickers,
        StorageKind.chatHistory ||
        StorageKind.companions ||
        StorageKind.speechModel ||
        StorageKind.other =>
          other,
      };

  /// What an upload of [contentType] is, by its MIME family.
  static UsageKind forUpload(String contentType) {
    final t = contentType.toLowerCase();
    if (t.startsWith('image/')) return photos;
    if (t.startsWith('video/')) return videos;
    if (t.startsWith('audio/')) return voice;
    return files;
  }
}

/// Bytes in each direction.
class UsageTally {
  UsageTally([this.sent = 0, this.received = 0]);
  int sent;
  int received;
  int get total => sent + received;

  List<int> toJson() => [sent, received];
  static UsageTally fromJson(Object? j) => j is List && j.length == 2
      ? UsageTally((j[0] as num).toInt(), (j[1] as num).toInt())
      : UsageTally();
}

/// Counts every byte the app moves for media and calls, per network and per
/// kind, since [since].
///
/// Fed by the transfer points themselves (the image cache's file service, the
/// video, voice and document caches, the uploader, the call stats poll), each
/// one a single [record] call with the bytes it just moved. Chat sync over the
/// Convex socket is not counted: the socket lives in a native client that does
/// not report bytes, and a guessed number would be worse than an honest gap.
class DataUsageStore extends ChangeNotifier {
  DataUsageStore._();
  static final DataUsageStore instance = DataUsageStore._();

  final JsonFile _file = JsonFile('mh_data_usage_v1.json');
  final Map<NetKind, Map<UsageKind, UsageTally>> _tallies = {
    for (final n in NetKind.values) n: {},
  };
  DateTime _since = DateTime.now();
  bool _loaded = false;
  Timer? _notify;

  DateTime get since => _since;

  @visibleForTesting
  JsonFile get debugFile => _file;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _file.read();
    if (raw is Map) {
      final s = raw['since'];
      if (s is int) _since = DateTime.fromMillisecondsSinceEpoch(s);
      for (final n in NetKind.values) {
        final per = raw[n.name];
        if (per is! Map) continue;
        for (final e in per.entries) {
          final k = UsageKind.parse(e.key as String?);
          if (k != null) _tallies[n]![k] = UsageTally.fromJson(e.value);
        }
      }
    } else {
      _persist();
    }
    notifyListeners();
  }

  /// Adds [sent] and [received] bytes of [kind], on the network the device is
  /// on now unless [net] says otherwise.
  void record(UsageKind kind, {int sent = 0, int received = 0, NetKind? net}) {
    if (sent <= 0 && received <= 0) return;
    final n = net ?? NetworkKindMonitor.instance.current;
    final t = _tallies[n]!.putIfAbsent(kind, UsageTally.new);
    t.sent += _nonNeg(sent);
    t.received += _nonNeg(received);
    // Unloaded (a widget test, or before main's preload lands) the tally is
    // kept in memory only; persisting it would overwrite the stored counts.
    if (!_loaded) return;
    _persist();
    // A download reports every chunk; an open Data Usage screen redraws a few
    // times a second, not a few hundred.
    _notify ??= Timer(const Duration(milliseconds: 400), () {
      _notify = null;
      notifyListeners();
    });
  }

  static int _nonNeg(int v) => v < 0 ? 0 : v;

  /// One kind on one network, or across both when [net] is null.
  UsageTally tally(UsageKind kind, {NetKind? net}) {
    final out = UsageTally();
    for (final n in net == null ? NetKind.values : [net]) {
      final t = _tallies[n]![kind];
      if (t == null) continue;
      out
        ..sent += t.sent
        ..received += t.received;
    }
    return out;
  }

  UsageTally total({NetKind? net}) {
    final out = UsageTally();
    for (final k in UsageKind.values) {
      final t = tally(k, net: net);
      out
        ..sent += t.sent
        ..received += t.received;
    }
    return out;
  }

  Future<void> reset() async {
    for (final n in NetKind.values) {
      _tallies[n]!.clear();
    }
    _since = DateTime.now();
    _persist();
    await _file.flush();
    notifyListeners();
  }

  void _persist() => _file.schedule(() => {
        'since': _since.millisecondsSinceEpoch,
        for (final n in NetKind.values)
          n.name: {
            for (final e in _tallies[n]!.entries) e.key.name: e.value.toJson(),
          },
      });

  Future<void> flush() => _file.flush();

  @visibleForTesting
  void debugReset() {
    for (final n in NetKind.values) {
      _tallies[n]!.clear();
    }
    _since = DateTime.now();
    _loaded = false;
  }
}
