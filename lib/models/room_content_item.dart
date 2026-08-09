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
enum RoomContentTab { media, file, voice, links }

extension RoomContentTabWire on RoomContentTab {
  /// The `galleryBucket` value, or null for [RoomContentTab.links], which has
  /// no bucket and is fetched through `listLinks` instead.
  String? get bucket => switch (this) {
        RoomContentTab.media => 'media',
        RoomContentTab.file => 'file',
        RoomContentTab.voice => 'voice',
        RoomContentTab.links => null,
      };

  /// The key `roomContent:counts` returns this tab's total under.
  String get countKey => switch (this) {
        RoomContentTab.media => 'media',
        RoomContentTab.file => 'file',
        RoomContentTab.voice => 'voice',
        RoomContentTab.links => 'link',
      };

  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      RoomContentTab.media => l10n.roomContentTabLabelMedia,
      RoomContentTab.file => l10n.roomContentTabLabelFiles,
      RoomContentTab.voice => l10n.roomContentTabLabelVoice,
      RoomContentTab.links => l10n.roomContentTabLabelLinks,
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
bool messageBelongsIn(ChatMessage m, RoomContentTab tab) {
  if (m.viewOnce) return false;
  if (tab == RoomContentTab.links) {
    // Not gated on an attachment: a photo with a URL in its caption is a link.
    return m.content.isNotEmpty;
  }
  if (m.mediaStorageId == null) return false;
  return switch (tab) {
    RoomContentTab.media => m.type == MessageType.image ||
        m.type == MessageType.video ||
        m.type == MessageType.videoNote,
    RoomContentTab.voice => m.type == MessageType.audio,
    RoomContentTab.file => m.type == MessageType.file,
    RoomContentTab.links => false,
  };
}
