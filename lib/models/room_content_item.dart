import 'package:flutter/widgets.dart' show BuildContext;

import '../l10n/generated/app_localizations.dart';
import 'chat_message.dart';
import 'enums.dart';

/// Which tab of the shared-content browser something belongs in.
///
/// The first three mirror `messages.galleryBucket` on the server verbatim —
/// [wire] is what `roomContent:listBucket` is called with, and a mismatch is
/// an `UNKNOWN_BUCKET` throw rather than an empty page, which is the failure
/// worth having.
///
/// [links] is the odd one out and deliberately not a bucket: a link lives on a
/// message that may also be a photo, so it is keyed by `hasLink` on its own
/// index and served by a different query. That is why this enum exists at all
/// rather than the screen passing bucket strings around.
///
/// [saved] is the same shape as [links] taken one step further, and it is worth
/// being precise about how far. Like links it has no bucket and its own query —
/// `bookmarks:listForRoom` rather than `roomContent:listBucket`. Unlike every
/// other tab it is not a property of the room at all: the same message is in
/// this tab for one member and absent for the next, because a bookmark is a row
/// keyed by `(room, reader, message)`. Two consequences follow it around this
/// file and the two screens that read it — [messageBelongsIn] cannot answer for
/// it (nothing about a [ChatMessage] says who kept it), and its count comes off
/// a live subscription the client already holds rather than out of
/// `roomContent:counts`. See [roomContentCountFor].
enum RoomContentTab { media, file, voice, links, saved }

extension RoomContentTabWire on RoomContentTab {
  /// The `galleryBucket` value, or null for the two tabs that have no bucket —
  /// [RoomContentTab.links] is fetched through `listLinks`, and
  /// [RoomContentTab.saved] is not fetched at all (see [RoomContentTab]).
  String? get bucket => switch (this) {
        RoomContentTab.media => 'media',
        RoomContentTab.file => 'file',
        RoomContentTab.voice => 'voice',
        RoomContentTab.links => null,
        RoomContentTab.saved => null,
      };

  /// The key `roomContent:counts` returns this tab's total under, or null for
  /// [RoomContentTab.saved], which that query knows nothing about.
  String? get countKey => switch (this) {
        RoomContentTab.media => 'media',
        RoomContentTab.file => 'file',
        RoomContentTab.voice => 'voice',
        RoomContentTab.links => 'link',
        RoomContentTab.saved => null,
      };

  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      RoomContentTab.media => l10n.roomContentTabLabelMedia,
      RoomContentTab.file => l10n.roomContentTabLabelFiles,
      RoomContentTab.voice => l10n.roomContentTabLabelVoice,
      RoomContentTab.links => l10n.roomContentTabLabelLinks,
      RoomContentTab.saved => l10n.roomContentTabLabelSaved,
    };
  }

  /// Lowercase form for the shared-content screen's header, which sets the
  /// tab name in the app's lowercase heading voice (e.g. 'settings.'). A
  /// pre-authored lowercase ARB value rather than `label(context).toLowerCase()`
  /// — Dart's `toLowerCase()` is not locale-aware and would turn the Turkish
  /// capital dotless I in 'BAĞLANTILAR' into a dotted 'i' instead of the
  /// correct dotless 'ı', misspelling 'bağlantılar'.
  String headerLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      RoomContentTab.media => l10n.roomContentTabHeaderMedia,
      RoomContentTab.file => l10n.roomContentTabHeaderFiles,
      RoomContentTab.voice => l10n.roomContentTabHeaderVoice,
      RoomContentTab.links => l10n.roomContentTabHeaderLinks,
      RoomContentTab.saved => l10n.roomContentTabHeaderSaved,
    };
  }
}

/// How many of something a tab holds, and whether that number is the truth.
///
/// The server stops counting at 99 (`COUNT_CAP` in roomContent.ts) because a
/// true count means reading every matching row on every room-info open, and
/// the badge only has to answer "is this tab worth opening".
class RoomContentCount {
  const RoomContentCount({required this.count, required this.capped});

  final int count;

  /// The real total is [count] or more. Render `99+`, never `99`.
  final bool capped;

  static const zero = RoomContentCount(count: 0, capped: false);

  /// `12`, `99+`, or null when there is nothing to badge — an empty tab reads
  /// better with no badge than with a `0`.
  String? get badge {
    if (count <= 0) return null;
    return capped ? '$count+' : '$count';
  }

  factory RoomContentCount.fromJson(Map<String, dynamic> j) => RoomContentCount(
        count: (j['count'] as num?)?.toInt() ?? 0,
        capped: (j['capped'] ?? false) as bool,
      );
}

/// The number to badge [tab] with, from whichever of the two sources knows it.
///
/// Both surfaces that show these badges — the room-info rows and the browser's
/// pill strip — need the same answer, and the answer is not uniform, so it lives
/// here rather than being written out twice.
///
/// [serverCounts] is `roomContent:counts`, capped at 99 and fetched once per
/// screen. [savedCount] is `ChatRepository.savedFor(roomId).length`, which is a
/// live subscription the room already holds.
///
/// ── Why SAVED is counted on the client and the other four are not ──
///
/// A server count exists for the other four because a true one means reading
/// every matching row in the room, which is why it is capped and why it is a
/// separate one-shot query. None of that applies here: `bookmarks.ts` caps saves
/// at 50 per reader per room and `bookmarks:listForRoom` is ALREADY subscribed
/// for the open room, so the client is holding the entire list. Asking the
/// server would add a fifth index scan to every room-info open to re-derive a
/// number sitting in memory, and would arrive a round trip later than the list
/// it describes — a row reading `3` above a tab showing four.
///
/// It also lands in a strictly better state than the other four rather than a
/// different one: never `capped` (50 < 99, so `99+` is unreachable), and never
/// null-because-in-flight. The one state it can be wrong in is offline or before
/// the subscription's first frame, where it reads `none` — the same thing the
/// list itself says there, and the same bargain `MessageBookmark` documents.
RoomContentCount? roomContentCountFor(
  RoomContentTab tab, {
  required Map<String, RoomContentCount> serverCounts,
  required int savedCount,
}) {
  final key = tab.countKey;
  if (key == null) return RoomContentCount(count: savedCount, capped: false);
  return serverCounts[key];
}

/// One link, as the LINKS tab renders it.
///
/// A [message] can produce several of these: the server only records that a
/// message contains at least one URL, and the client re-derives the actual
/// URLs from `content` with `UrlDetector`. So this pairs the URL with the
/// message it came out of rather than being a row in its own right, which is
/// also what lets "show in chat" work from a link.
class RoomLink {
  const RoomLink({required this.url, required this.message});

  final String url;
  final ChatMessage message;

  DateTime get createdAt => message.createdAt;
}

/// A page of shared content, and whether there is more behind it.
///
/// The cursor is [oldest], not an opaque token: the server pages on
/// `createdAt` exactly like `messages:listBefore`, so the next page is
/// "everything before the oldest row I hold".
class RoomContentPage {
  const RoomContentPage({required this.items, required this.hasMore});

  final List<ChatMessage> items;
  final bool hasMore;

  static const empty = RoomContentPage(items: [], hasMore: false);

  /// Feed this back as `beforeTimestamp`. Null on an empty page, where there
  /// is nothing to page from.
  DateTime? get oldest => items.isEmpty ? null : items.last.createdAt;
}

/// Whether [m] would be rendered by [tab], for the client-side half of the
/// merge in `RoomContentController`.
///
/// Mirrors `galleryBucketFor` on the server, and has to: the controller splices
/// newly-arrived messages from the live transcript into a page fetched from the
/// index, so a message the two disagree about either appears twice or never.
/// The `mediaStorageId != null` and `!viewOnce` clauses are the same two guards
/// for the same two reasons — a failed upload is a tile that can never load,
/// and an armed photo is not shared content.
///
/// Always false for [RoomContentTab.saved], and that is the honest answer rather
/// than a gap: whether a message is saved is not a property of the message, it
/// is a row somebody else's reader holds. That tab has no fetched half to merge
/// against either, so the controller never asks — see `RoomContentController`.
bool messageBelongsIn(ChatMessage m, RoomContentTab tab) {
  if (tab == RoomContentTab.saved) return false;
  if (m.viewOnce) return false;
  if (tab == RoomContentTab.links) {
    // Not gated on an attachment: a photo with a URL in its caption is a link.
    return m.content.isNotEmpty;
  }
  if (m.mediaStorageId == null) return false;
  return switch (tab) {
    RoomContentTab.media =>
      m.type == MessageType.image || m.type == MessageType.video,
    RoomContentTab.voice => m.type == MessageType.audio,
    RoomContentTab.file => m.type == MessageType.file,
    RoomContentTab.links || RoomContentTab.saved => false,
  };
}
