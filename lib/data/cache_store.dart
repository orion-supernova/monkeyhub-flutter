import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';

/// On-disk snapshot of the data the user already saw — used to render
/// instantly on cold boot, even when the network is down. The Convex
/// subscriptions overwrite this with live data as soon as they connect.
///
/// Files live under `<app-documents>/cache/<userId>/`:
///   - `rooms.json` — list of rooms (capped at all known)
///   - `friends.json` — the friends list, which is also what resolves a DM
///     room's real name and avatar (see [ChatUser.toJson])
///   - `messages_<roomId>.json` — last ~120 messages per room
///
/// Writes are debounced to avoid disk thrash; reads are best-effort and
/// swallow errors (a corrupted cache shouldn't break the app).
class CacheStore {
  CacheStore._();
  static final CacheStore instance = CacheStore._();

  static const int _maxMessagesPerRoom = 120;
  static const Duration _writeDebounce = Duration(milliseconds: 600);

  Directory? _baseDir;
  final Map<String, Timer> _pendingWrites = {};

  Future<Directory> _ensureDir(String userId) async {
    final docs = _baseDir ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/cache/$userId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ─────────────────────────────── rooms ───────────────────────────────

  Future<List<ChatRoom>> loadRooms(String userId) async {
    if (kIsWeb) return const []; // no path_provider on web — live data only
    try {
      final dir = await _ensureDir(userId);
      final f = File('${dir.path}/rooms.json');
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      final list = (jsonDecode(raw) as List?) ?? const [];
      return list
          .map((e) => ChatRoom.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('cache loadRooms failed: $e');
      return const [];
    }
  }

  void scheduleSaveRooms(String userId, List<ChatRoom> rooms) {
    if (kIsWeb) return; // no disk cache on web
    _debounce('rooms', () async {
      try {
        final dir = await _ensureDir(userId);
        final f = File('${dir.path}/rooms.json');
        await f.writeAsString(jsonEncode(rooms.map((r) => r.toJson()).toList()));
      } catch (e) {
        debugPrint('cache saveRooms failed: $e');
      }
    });
  }

  // ─────────────────────────────── friends ───────────────────────────────

  Future<List<ChatUser>> loadFriends(String userId) async {
    if (kIsWeb) return const []; // no path_provider on web — live data only
    try {
      final dir = await _ensureDir(userId);
      final f = File('${dir.path}/friends.json');
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      final list = (jsonDecode(raw) as List?) ?? const [];
      return list
          .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('cache loadFriends failed: $e');
      return const [];
    }
  }

  void scheduleSaveFriends(String userId, List<ChatUser> friends) {
    if (kIsWeb) return; // no disk cache on web
    _debounce('friends', () async {
      try {
        final dir = await _ensureDir(userId);
        final f = File('${dir.path}/friends.json');
        await f.writeAsString(jsonEncode(friends.map((u) => u.toJson()).toList()));
      } catch (e) {
        debugPrint('cache saveFriends failed: $e');
      }
    });
  }

  // ─────────────────────────────── messages ───────────────────────────────

  Future<List<ChatMessage>> loadMessages(String userId, String roomId) async {
    if (kIsWeb) return const []; // no path_provider on web — live data only
    try {
      final dir = await _ensureDir(userId);
      final f = File('${dir.path}/messages_$roomId.json');
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      final list = (jsonDecode(raw) as List?) ?? const [];
      return list
          .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('cache loadMessages failed: $e');
      return const [];
    }
  }

  void scheduleSaveMessages(
    String userId,
    String roomId,
    List<ChatMessage> messages,
  ) {
    // Cap at the last N to keep cache size bounded.
    if (kIsWeb) return; // no disk cache on web
    final clipped = messages.length > _maxMessagesPerRoom
        ? messages.sublist(messages.length - _maxMessagesPerRoom)
        : messages;
    _debounce('msg:$roomId', () async {
      try {
        final dir = await _ensureDir(userId);
        final f = File('${dir.path}/messages_$roomId.json');
        await f.writeAsString(
          jsonEncode(clipped.map((m) => m.toJson()).toList()),
        );
      } catch (e) {
        debugPrint('cache saveMessages failed: $e');
      }
    });
  }

  // ─────────────────────────── today's game boards ───────────────────────────

  /// Today's four puzzles, kept between launches.
  ///
  /// The boards are a pure function of the day key — there is no version of
  /// them that can go stale before midnight — so a launch on a day this device
  /// has already fetched has nothing to ask the server for. Without this the
  /// Feed's games band paints four placeholders on every cold start for as long
  /// as the round trip takes, which on a cold socket is the first thing anyone
  /// sees, every morning.
  ///
  /// Deliberately not under `<userId>/`, unlike everything else here: the
  /// payload is the same four puzzles for everybody and carries nobody's
  /// results, so scoping it per account would mean re-fetching the identical
  /// bytes for the second person on a shared handset. It is left alone by
  /// [clearFor] for the same reason — there is nothing in it to leak.
  ///
  /// The raw payload rather than the parsed model, so that adding a field to a
  /// board is a backend change and not also a serialiser this file has to know
  /// how to write.
  Future<Map<String, dynamic>?> loadDailyBoards(String dayKey) async {
    if (kIsWeb) return null; // no path_provider on web — live data only
    try {
      final docs = _baseDir ??= await getApplicationDocumentsDirectory();
      final f = File('${docs.path}/cache/games_daily.json');
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map?;
      // A payload for yesterday is not a stale board, it is the wrong game.
      if (j == null || j['dayKey'] != dayKey) return null;
      return (j['payload'] as Map?)?.cast<String, dynamic>();
    } catch (e) {
      debugPrint('cache loadDailyBoards failed: $e');
      return null;
    }
  }

  /// Undebounced: this is written once a day, right after the fetch that a
  /// relaunch a minute later would otherwise repeat.
  Future<void> saveDailyBoards(String dayKey, Map<String, dynamic> payload) async {
    if (kIsWeb) return; // no disk cache on web
    try {
      final docs = _baseDir ??= await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/cache');
      if (!await dir.exists()) await dir.create(recursive: true);
      await File('${dir.path}/games_daily.json').writeAsString(
        jsonEncode({'dayKey': dayKey, 'payload': payload}),
      );
    } catch (e) {
      debugPrint('cache saveDailyBoards failed: $e');
    }
  }

  // ─────────────────────────────── cleanup ───────────────────────────────

  /// Drop all cached data for the given user. Called on signOut + deleteAccount.
  Future<void> clearFor(String userId) async {
    if (kIsWeb) return; // nothing cached on disk on web
    try {
      final dir = await _ensureDir(userId);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('cache clearFor failed: $e');
    }
  }

  // ─────────────────────────────── debounce ───────────────────────────────

  void _debounce(String key, FutureOr<void> Function() job) {
    _pendingWrites[key]?.cancel();
    _pendingWrites[key] = Timer(_writeDebounce, () async {
      _pendingWrites.remove(key);
      await job();
    });
  }

  /// Flush all pending writes synchronously (used on signOut to make sure
  /// the last snapshot lands before the cache is cleared).
  Future<void> flush() async {
    final timers = _pendingWrites.values.toList();
    _pendingWrites.clear();
    for (final t in timers) {
      t.cancel();
    }
  }
}
