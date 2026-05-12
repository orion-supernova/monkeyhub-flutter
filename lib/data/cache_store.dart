import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../models/chat_room.dart';

/// On-disk snapshot of the data the user already saw — used to render
/// instantly on cold boot, even when the network is down. The Convex
/// subscriptions overwrite this with live data as soon as they connect.
///
/// Files live under `<app-documents>/cache/<userId>/`:
///   - `rooms.json` — list of rooms (capped at all known)
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

  // ─────────────────────────────── messages ───────────────────────────────

  Future<List<ChatMessage>> loadMessages(String userId, String roomId) async {
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

  // ─────────────────────────────── cleanup ───────────────────────────────

  /// Drop all cached data for the given user. Called on signOut + deleteAccount.
  Future<void> clearFor(String userId) async {
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
