import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/message_interaction.dart';
import '../models/pending_upload.dart';

/// On-disk snapshot of the data the user already saw — used to render
/// instantly on cold boot, even when the network is down. The Convex
/// subscriptions overwrite this with live data as soon as they connect.
///
/// Files live under `<app-documents>/cache/<userId>/`:
///   - `rooms.json` — list of rooms (capped at all known)
///   - `friends.json` — the friends list, which is also what resolves a DM
///     room's real name and avatar (see [ChatUser.toJson])
///   - `messages_<roomId>.json` — last ~120 messages per room
///   - `members_<roomId>.json` — that room's roster, which is what resolves
///     every sender's name, avatar and speaker colour
///   - `speaker_colors.json` — this reader's manual speaker-colour pins
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

  // ───────────────────── interactive message bodies ─────────────────────
  //
  // Polls, checklists and events, beside the messages they belong to.
  //
  // A SECOND file rather than fields folded into `messages_<room>.json`,
  // mirroring the split the backend and the repository both make — and for a
  // reason of its own here: the message file is rewritten whenever the
  // transcript changes, and an interaction's tally changes far more often than
  // its transcript does. Two files means a vote rewrites a few hundred bytes
  // instead of the whole room.
  //
  // What this buys is the cold-boot frame. Without it, opening a room offline —
  // or in the moment before the socket connects — draws every poll as its
  // question with no options under it, which reads as a broken card rather than
  // as a loading one. The tallies restored here may be stale; that is fine and
  // is the same promise the cached transcript makes.

  Future<Map<String, MessageInteraction>> loadInteractions(
    String userId,
    String roomId,
  ) async {
    if (kIsWeb) return const {}; // no path_provider on web — live data only
    try {
      final dir = await _ensureDir(userId);
      final f = File('${dir.path}/interactions_$roomId.json');
      if (!await f.exists()) return const {};
      final list = (jsonDecode(await f.readAsString()) as List?) ?? const [];
      final out = <String, MessageInteraction>{};
      for (final e in list) {
        if (e is! Map) continue;
        final it = MessageInteraction.fromJson(e.cast<String, dynamic>());
        out[it.messageId] = it;
      }
      return out;
    } catch (e) {
      debugPrint('cache loadInteractions failed: $e');
      return const {};
    }
  }

  void scheduleSaveInteractions(
    String userId,
    String roomId,
    Iterable<MessageInteraction> interactions,
  ) {
    if (kIsWeb) return; // no disk cache on web
    // Uncapped, unlike the transcript above, because the set is already bounded
    // by the server: `interactions:listForRoom` returns at most one live
    // window's worth, and a room's whole history of polls is a handful of small
    // rows next to a hundred messages. A cap here would silently drop the
    // scrolled-back ones a page hydrate had just fetched.
    final rows = interactions.toList(growable: false);
    _debounce('int:$roomId', () async {
      try {
        final dir = await _ensureDir(userId);
        final f = File('${dir.path}/interactions_$roomId.json');
        await f.writeAsString(
          jsonEncode(rows.map((i) => i.toJson()).toList()),
        );
      } catch (e) {
        debugPrint('cache saveInteractions failed: $e');
      }
    });
  }

  // ────────────────────────────── room rosters ──────────────────────────────
  //
  // Who is in the room, beside the messages they sent.
  //
  // This is the file that makes a re-opened room paint ONCE. The transcript
  // above restores what was said; this restores who said it — and until it
  // lands there is no sender name, no avatar and, above all, no speaker
  // colour, because `SpeakerSlots.forMembers` is a function of the roster.
  // Without it, opening a room you have read a hundred times draws the whole
  // transcript in theme ink and then repaints every bubble the moment
  // `rooms:getMembers` answers. That repaint is the "colours arrive late"
  // everybody notices, and it is not the transcript's fault.
  //
  // Uncapped, like the interactions above and unlike the transcript, and here
  // the reason is correctness rather than size. Slot assignment resolves
  // collisions by probing FORWARD through the palette in join order, so
  // dropping any member frees a slot that somebody later in the order would
  // otherwise have been pushed off. A truncated roster is therefore not a
  // smaller answer, it is a DIFFERENT one — and a seed that settles the room
  // to different colours than the live roster will is worse than no seed at
  // all. A roster row is a few hundred bytes; even a large room is smaller
  // than the transcript sitting next to it.

  Future<List<ChatUser>> loadMembers(String userId, String roomId) async {
    if (kIsWeb) return const []; // no path_provider on web — live data only
    try {
      final dir = await _ensureDir(userId);
      final f = File('${dir.path}/members_$roomId.json');
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      final list = (jsonDecode(raw) as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => ChatUser.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('cache loadMembers failed: $e');
      return const [];
    }
  }

  void scheduleSaveMembers(
    String userId,
    String roomId,
    List<ChatUser> members,
  ) {
    if (kIsWeb) return; // no disk cache on web
    // Presence is stripped rather than persisted, which is two wins at once.
    //
    // The honest one: `status` and `lastSeen` describe where somebody was when
    // this file was written, and a cold start hours later that painted them
    // from disk would light a green dot beside a person who is not there. No
    // presence reads correctly as "not known yet"; stale presence reads as a
    // lie, and it is a lie the live subscription then visibly corrects.
    //
    // The cheap one: presence is also the ONLY field on a roster row that
    // changes minute to minute. Dropping it means this file is rewritten when
    // somebody joins, leaves, is promoted or changes their name or avatar —
    // rare — instead of every time a member's dot goes amber.
    final rows = [
      for (final u in members)
        u.toJson()
          ..remove('status')
          ..remove('lastSeen'),
    ];
    _debounce('mem:$roomId', () async {
      try {
        final dir = await _ensureDir(userId);
        final f = File('${dir.path}/members_$roomId.json');
        await f.writeAsString(jsonEncode(rows));
      } catch (e) {
        debugPrint('cache saveMembers failed: $e');
      }
    });
  }

  // ─────────────────────── speaker colour overrides ───────────────────────
  //
  // This reader's manual pins, roomId → subjectId → palette slot.
  //
  // Cached for one reason, and it is not the round trip: pins are applied
  // FIRST and absolutely by `SpeakerSlots.forMembers`, and the slots they
  // occupy are then off-limits to everyone the room places automatically. So a
  // roster restored from disk without them does not settle to a nearly-right
  // palette that the pins later refine — it settles to a DIFFERENT one, and
  // the reader watches the room rearrange itself when `speakerColors:mine`
  // lands. For anybody who has ever opened the picker, caching the roster
  // without also caching this would trade a fade-in for a reshuffle.
  //
  // One file for every room rather than one per room: the whole map is bounded
  // at twelve entries per room by the server and is empty for almost every
  // reader, and it arrives as a single app-wide subscription (see
  // `ChatRepository._speakerColors`) that has no per-room delivery to hang a
  // per-room write off.

  Future<Map<String, Map<String, int>>> loadSpeakerColors(String userId) async {
    if (kIsWeb) return const {}; // no path_provider on web — live data only
    try {
      final dir = await _ensureDir(userId);
      final f = File('${dir.path}/speaker_colors.json');
      if (!await f.exists()) return const {};
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return const {};
      final out = <String, Map<String, int>>{};
      decoded.forEach((roomId, byUser) {
        if (byUser is! Map) return;
        final inner = <String, int>{};
        byUser.forEach((subjectId, slot) {
          if (slot is num) inner[subjectId.toString()] = slot.toInt();
        });
        if (inner.isNotEmpty) out[roomId.toString()] = inner;
      });
      return out;
    } catch (e) {
      debugPrint('cache loadSpeakerColors failed: $e');
      return const {};
    }
  }

  void scheduleSaveSpeakerColors(
    String userId,
    Map<String, Map<String, int>> colors,
  ) {
    if (kIsWeb) return; // no disk cache on web
    // Deep-copied at schedule time, not read at fire time: the repository
    // replaces this map wholesale on every optimistic pin and every
    // subscription echo, and the debounce means the write lands ~600ms after
    // the call that asked for it.
    final snapshot = {
      for (final e in colors.entries) e.key: Map<String, int>.from(e.value),
    };
    _debounce('speakerColors', () async {
      try {
        final dir = await _ensureDir(userId);
        final f = File('${dir.path}/speaker_colors.json');
        await f.writeAsString(jsonEncode(snapshot));
      } catch (e) {
        debugPrint('cache saveSpeakerColors failed: $e');
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

  // ─────────────────────────────── outbox ───────────────────────────────

  /// How soon an outbox change reaches the disk. Much shorter than
  /// [_writeDebounce]: everything else here is a copy of something the server
  /// still has, while the outbox is the only copy there is. A send typed in a
  /// tunnel and followed by a swipe-away of the app must not depend on the
  /// phone staying up for another half second.
  static const Duration _outboxDebounce = Duration(milliseconds: 150);

  /// Messages this account sent that the server has not confirmed, as they
  /// were left — read back so a restart does not throw them away.
  ///
  /// Under `<userId>/outbox/`: `outbox.json` holds each message's wire map,
  /// and an attachment whose bytes never finished going up keeps them beside
  /// it as `<id>.bin` (and `<id>.poster.bin` for a video's still), so the
  /// bubble can still paint its picture and a retry has something to upload.
  /// [clearFor] takes the whole directory with it on sign-out — these are one
  /// person's unsent words and photos.
  ///
  /// Everything comes back as [MessageStatus.error]. Whether a send from a
  /// previous run should still go out is the sender's call, not this
  /// device's: the bubble offers retry and discard.
  Future<List<ChatMessage>> loadOutbox(String userId) async {
    if (kIsWeb) return const []; // no path_provider on web — memory only
    try {
      final dir = Directory('${(await _ensureDir(userId)).path}/outbox');
      final f = File('${dir.path}/outbox.json');
      if (!await f.exists()) return const [];
      final list = (jsonDecode(await f.readAsString()) as List?) ?? const [];
      final out = <ChatMessage>[];
      for (final raw in list) {
        try {
          final j = (raw as Map).cast<String, dynamic>();
          final m = ChatMessage.fromJson(
            (j['message'] as Map).cast<String, dynamic>(),
          );
          PendingUpload? upload;
          final up = (j['upload'] as Map?)?.cast<String, dynamic>();
          if (up != null) {
            final bytes = File('${dir.path}/${m.id}.bin');
            // Bytes gone means nothing to retry with; the message still comes
            // back, failed, so the sender sees what did not go and can discard
            // it — rather than having it vanish without a word.
            if (await bytes.exists()) {
              final poster = File('${dir.path}/${m.id}.poster.bin');
              upload = PendingUpload(
                bytes: await bytes.readAsBytes(),
                contentType: up['contentType'] as String,
                posterBytes:
                    await poster.exists() ? await poster.readAsBytes() : null,
              );
            }
          }
          out.add(m.copyWith(status: MessageStatus.error, upload: upload));
        } catch (e) {
          debugPrint('cache loadOutbox skipped an entry: $e');
        }
      }
      return out;
    } catch (e) {
      debugPrint('cache loadOutbox failed: $e');
      return const [];
    }
  }

  /// Replaces the stored outbox with [messages].
  ///
  /// Through the same debounce as every other write, so [clearFor]'s
  /// [discardPendingWrites] covers it: a sign-out must not be followed by the
  /// departing account's unsent messages being written back to disk.
  void scheduleSaveOutbox(String userId, List<ChatMessage> messages) {
    if (kIsWeb) return; // no disk cache on web
    final snapshot = List<ChatMessage>.of(messages);
    _debounce('outbox', delay: _outboxDebounce, () {
      // Chained: a write of several megabytes of photo can outlast the next
      // debounce, and two writes interleaving their renames and deletes would
      // leave neither outbox on disk.
      return _outboxWrites = _outboxWrites.then(
        (_) => _writeOutbox(userId, snapshot),
      );
    });
  }

  Future<void> _outboxWrites = Future.value();

  Future<void> _writeOutbox(String userId, List<ChatMessage> snapshot) async {
    try {
      final dir = Directory('${(await _ensureDir(userId)).path}/outbox');
      if (!await dir.exists()) await dir.create(recursive: true);
      final keep = <String>{'outbox.json'};
      final entries = <Map<String, dynamic>>[];
      for (final m in snapshot) {
        final up = m.upload;
        final holdsBytes = up != null && !up.disposed;
        if (holdsBytes) {
          // Written once per message: the bytes of a send never change.
          final bytes = File('${dir.path}/${m.id}.bin');
          if (!await bytes.exists()) await bytes.writeAsBytes(up.bytes);
          keep.add('${m.id}.bin');
          final poster = up.posterBytes;
          if (poster != null) {
            final pf = File('${dir.path}/${m.id}.poster.bin');
            if (!await pf.exists()) await pf.writeAsBytes(poster);
            keep.add('${m.id}.poster.bin');
          }
        }
        entries.add({
          'message': m.toJson(),
          if (holdsBytes) 'upload': {'contentType': up.contentType},
        });
      }
      // Through a temp file and a rename, so a kill mid-write leaves the
      // previous outbox rather than half of a new one.
      final tmp = File('${dir.path}/outbox.json.tmp');
      await tmp.writeAsString(jsonEncode(entries), flush: true);
      await tmp.rename('${dir.path}/outbox.json');
      // Bytes of anything sent or discarded since the last write.
      await for (final f in dir.list()) {
        final name = f.uri.pathSegments.last;
        if (f is File && !keep.contains(name)) await f.delete();
      }
    } catch (e) {
      debugPrint('cache saveOutbox failed: $e');
    }
  }

  // ─────────────────────────────── cleanup ───────────────────────────────

  /// Drop all cached data for the given user. Called on signOut + deleteAccount.
  ///
  /// Pending writes are dropped BEFORE the directory goes, and that ordering is
  /// load-bearing rather than tidy. Every save on this class is debounced by
  /// [_writeDebounce], so at the moment somebody signs out there is very likely
  /// a timer holding the last roster, transcript or pin map the departing
  /// account produced. Deleting the directory without cancelling it leaves the
  /// timer to fire ~600ms later, and `_ensureDir` will happily RECREATE the
  /// directory it just deleted and write that account's data back into it —
  /// which on a shared handset is the previous person's transcript reappearing
  /// under the next person's login.
  Future<void> clearFor(String userId) async {
    if (kIsWeb) return; // nothing cached on disk on web
    discardPendingWrites();
    try {
      final dir = await _ensureDir(userId);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('cache clearFor failed: $e');
    }
  }

  // ─────────────────────────────── debounce ───────────────────────────────

  void _debounce(
    String key,
    FutureOr<void> Function() job, {
    Duration delay = _writeDebounce,
  }) {
    _pendingWrites[key]?.cancel();
    _pendingWrites[key] = Timer(delay, () async {
      _pendingWrites.remove(key);
      await job();
    });
  }

  /// Abandon every debounced write that has not fired yet.
  ///
  /// Dropped, not flushed — the name says which, because the doc that used to
  /// sit here said "flush" while the body did exactly this, and the difference
  /// matters. The only caller is [clearFor], and on that path a write that
  /// lands is a write that resurrects the cache the caller is deleting; see
  /// the note there.
  @visibleForTesting
  void discardPendingWrites() {
    final timers = _pendingWrites.values.toList();
    _pendingWrites.clear();
    for (final t in timers) {
      t.cancel();
    }
  }
}
