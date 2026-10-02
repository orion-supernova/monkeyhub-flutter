import '../models/chat_message.dart';
import '../models/enums.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Flattening of a room's message list into renderable rows.
///
/// Lives outside `room_screen.dart` and depends on nothing but [ChatMessage]
/// so the whole thing is unit-testable without pumping widgets or standing up
/// a Convex client. [buildRoomItems] is pure.
///
/// Beyond date dividers it does one thread-aware thing, keyed on
/// [ChatMessage.threadKey] (`rootId ?? id` — two messages are in the same
/// thread iff their keys match):
///
///  * **Folds.** A long thread's interior members collapse into a single
///    [ThreadFoldItem]. The root and the newest member always stay.
///
/// Nothing there keys off adjacency — a thread's messages are almost never
/// consecutive in the room timeline.
///
/// And one thing that is entirely about adjacency, in a pass of its own after
/// the rows are chosen:
///
///  * **Albums.** A run of adjacent photographs from one sender collapses into
///    a single row carrying all of them — see [collapseAlbums].

const List<String> _monthAbbrev = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// The label above a day's first row — `TODAY`, `YESTERDAY`, `MAR 14`, or
/// `MAR 14 · 2024` once the year stops being obvious.
///
/// [d] must already be date-only (`DateTime(y, m, d)`); the equality tests
/// against today and yesterday are exact, so a value carrying a time of day
/// silently never matches either.
///
/// Was a private method on `_RoomScreenState`, which meant the shared-content
/// browser — the second surface to group messages by day — could either reach
/// into a State or grow a second copy. `_fmt` had already been copied twice
/// elsewhere in this codebase, so the third copy is the one worth not writing.
String humanDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (d == today) return 'TODAY';
  if (d == yesterday) return 'YESTERDAY';
  final sameYear = d.year == now.year;
  return sameYear
      ? '${_monthAbbrev[d.month - 1]} ${d.day}'
      : '${_monthAbbrev[d.month - 1]} ${d.day} · ${d.year}';
}

/// The day a transcript row belongs to, the way Messages and Telegram write
/// it: "Today", "Yesterday", then the system's own short date — localized,
/// where the shared [humanDay] is fixed English capitals.
String transcriptDay(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final l10n = AppLocalizations.of(context);
  if (day == today) return l10n.transcriptDayToday;
  if (today.difference(day).inDays == 1) return l10n.chatListYesterday;
  final material = MaterialLocalizations.of(context);
  return day.year == now.year
      ? material.formatShortMonthDay(day)
      : material.formatMediumDate(day);
}

/// A playing time as `m:ss` — `0:07`, `3:42`, `12:05`.
///
/// Minutes are not zero-padded and do not roll into hours: nothing this app
/// carries (a voice note, a video, a call timer) runs long enough for `1:02:03`
/// to be worth the width, and `62:03` stays readable if one ever does.
///
/// Not to be confused with `formatClockTime` in `message_stamp.dart`, which
/// formats a time of day.
String formatClockDuration(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// ───────────────────────── list item model ─────────────────────────

/// Marker for everything the transcript can render. Carries nothing itself —
/// it exists so the ListView has one type to switch on.
abstract class RoomItem {}

class IntroItem extends RoomItem {}

class DateDividerItem extends RoomItem {
  DateDividerItem(this.label);
  final String label;
}

/// Marks the first message newer than the reader's `lastReadAt` cursor at the
/// moment the room was opened — where [buildRoomItems] draws the "new
/// messages" line and where the room screen lands the initial scroll, so a
/// reader with a backlog opens onto what's new instead of the very bottom.
///
/// Emitted at most once per build, ahead of whatever else that message would
/// contribute (a date divider, a thread fold chip), so "everything from here
/// down is new" reads as literally true regardless of what follows it.
class UnreadDividerItem extends RoomItem {}

class MessageItem extends RoomItem {
  MessageItem(
    this.message, {
    this.grouped = false,
    this.newSender = true,
    this.lastInRun = true,
    this.replyMarker = ReplyMarker.full,
    this.album = const [],
  });

  final ChatMessage message;

  /// Every photograph this row draws when a run of them was collapsed into one
  /// album, oldest first. Empty on an ordinary row, and never of length one —
  /// a lone picture is a bubble, not an album.
  ///
  /// [message] is the LAST of them, deliberately. The row carries one
  /// timestamp, one delivery state and one place in the sender's run, and the
  /// honest value for all three is the newest photo's: the album finished
  /// arriving when its last picture did.
  final List<ChatMessage> album;

  /// Continues a run from the same sender: the vertical gap tightens and the
  /// bubble's corners tighten on the sender's side, so five replies in a row
  /// read as one block instead of five separate cards. A full-quote reply
  /// always breaks this — see [continuesRun] — even from the same sender,
  /// because the card needs a beat of its own.
  final bool grouped;

  /// Whether the sender differs from the previous *visible* message — same
  /// day, within the grouping window. This is what decides whether the
  /// sender's name needs to be shown again, and it is deliberately looser
  /// than [grouped]: a full-quote reply earns its own spacing beat even from
  /// the same sender, but that beat should not reprint a name the reader saw
  /// one bubble ago. [sameSenderAsPrev] is the same check [grouped] runs,
  /// minus the reply-marker veto.
  final bool newSender;

  /// Closes a run — nothing below it continues the same sender. This is the
  /// row that carries the avatar, so a run is bracketed by its name at the
  /// top and its face at the bottom. Not final: it can only be known once the
  /// *next* row is emitted, so pass 2 flips it back on the row above.
  ///
  /// Note `lastInRun && !grouped` means a run of exactly one — the avatar
  /// then stays top-aligned, since there is no run for it to close.
  bool lastInRun;

  /// How much of the quoted parent this row draws — see [replyMarkerFor] for
  /// the rule and [ReplyMarker] for why it is not a bool.
  final ReplyMarker replyMarker;
}

/// One or more of a thread's interior messages, folded away. Rendered as a
/// compact chip; tapping it opens the thread overlay.
class ThreadFoldItem extends RoomItem {
  ThreadFoldItem({
    required this.threadKey,
    required this.count,
    required this.oldestHiddenId,
    required this.senderIds,
  });

  final String threadKey;

  /// How many *loaded* messages are folded here. Deliberately not "replies":
  /// there is no server-side thread size, so this number cannot claim to be
  /// one — messages outside the loaded window aren't counted.
  final int count;

  /// Anchor for the thread overlay, so tapping lands on the folded content
  /// rather than the top of the thread.
  final String oldestHiddenId;

  /// Distinct senders among the folded messages, oldest first. The chip shows
  /// the first few as avatars.
  final List<String> senderIds;
}

// ───────────────────────── the build ─────────────────────────

/// Minimum number of messages that must be folded for a fold to be worth it.
/// Folding one is a net loss: the chip replaces the row it hides, so you
/// trade content for nothing.
const int kMinFoldedMessages = 2;

/// How much of [m]'s quoted parent to draw, given the content row directly
/// above it ([prev], null when nothing precedes it or a fold intervenes).
///
/// The parent being the row above is the one case where the full card repeats
/// a bubble already on screen; every other case has the parent somewhere off
/// in the scrollback, where repeating it is the entire point. A fold clearing
/// [prev] therefore restores the full card, which is right — the fold is what
/// took the parent away.
ReplyMarker replyMarkerFor(ChatMessage? prev, ChatMessage m) {
  if (!m.isReply) return ReplyMarker.none;
  if (prev != null && m.replyToId == prev.id) return ReplyMarker.compact;
  return ReplyMarker.full;
}

/// Whether [m] shares [prev]'s sender, same day, close in time — the same
/// check [continuesRun] runs, minus the reply-marker veto. This is what
/// decides whether a sender's name still needs saying, independent of
/// whether a full quote card forces this row to open its own spacing beat.
bool sameSenderAsPrev(
  ChatMessage? prev,
  ChatMessage m, {
  bool startsDay = false,
}) =>
    !startsDay &&
    prev != null &&
    prev.senderId == m.senderId &&
    m.createdAt.difference(prev.createdAt).inMinutes < 5;

/// Whether [m] continues [prev]'s run: [sameSenderAsPrev], and not
/// interrupted by a full quote card — that card is tall enough to need a beat
/// of its own, whereas the compact marker is one line and sits happily inside
/// a run. Shared with the thread overlay, which renders the same bubbles
/// against its own list and used to carry a hand-copied version of this rule.
///
/// The marker is derived here rather than passed in. It is a function of the
/// same [prev] and [m] the rest of the rule already has, and every caller that
/// had to supply it separately was one stale expression away from geometry
/// that disagreed with what got rendered.
bool continuesRun(
  ChatMessage? prev,
  ChatMessage m, {
  bool startsDay = false,
}) =>
    sameSenderAsPrev(prev, m, startsDay: startsDay) &&
    replyMarkerFor(prev, m) != ReplyMarker.full;

/// The most photographs one album may hold before the run starts a second
/// one. Matches the send cap, which is where these runs come from: one tap of
/// SEND is one album, and a sender who empties their camera roll in three
/// goes gets three blocks rather than one wall.
const int kMaxAlbumPhotos = 10;

/// Whether [m] may be drawn as a tile in an album rather than as its own
/// bubble.
///
/// The vetoes are all the same shape: a photograph that is carrying something
/// an 80-pixel square cannot carry. A caption is a paragraph, a quote card is
/// a second message, a sealed view-once photo is a whole affordance with its
/// own copy on it, an ephemeral one is a frame with a dissolve painted into it,
/// and a failed send needs its retry and discard controls at a size a thumb
/// can hit. Reactions are NOT a veto — the tile draws its own, because a
/// picture leaving the album the moment somebody reacts to it would make the
/// block jump under the reader's finger.
bool albumEligible(ChatMessage m) =>
    m.type == MessageType.image &&
    m.content.isEmpty &&
    !m.viewOnce &&
    !m.isEphemeral &&
    !m.isReply &&
    m.status != MessageStatus.error;

/// Collapses each run of adjacent album-eligible photo rows into one row that
/// draws them as a mosaic.
///
/// Runs after the emit loop rather than inside it, on the rows it produced.
/// Adjacency in the *output* is the property that matters — a date divider, a
/// fold chip or a sentence between two photographs all mean they are not one
/// album — and the output list is the only place that is already decided.
///
/// [MessageItem.grouped] is what ties the run together, so an album can only
/// ever form inside one sender's own uninterrupted block; the first photo may
/// itself continue a run of something else (a line of text, then four
/// pictures), which is why only the members after it are required to be
/// grouped.
List<RoomItem> collapseAlbums(List<RoomItem> rows) {
  final out = <RoomItem>[];
  for (var i = 0; i < rows.length;) {
    final head = rows[i];
    if (head is! MessageItem || !albumEligible(head.message)) {
      out.add(head);
      i++;
      continue;
    }
    var end = i + 1;
    while (end < rows.length && end - i < kMaxAlbumPhotos) {
      final next = rows[end];
      if (next is! MessageItem ||
          !next.grouped ||
          !albumEligible(next.message)) {
        break;
      }
      end++;
    }
    if (end - i < 2) {
      out.add(head);
      i++;
      continue;
    }
    final run = [for (var k = i; k < end; k++) rows[k] as MessageItem];
    out.add(MessageItem(
      run.last.message,
      grouped: run.first.grouped,
      newSender: run.first.newSender,
      // Safe to read now and not one row earlier: `lastInRun` is the one flag
      // the emit loop writes back onto a row it has already emitted, and every
      // one of those writes has happened by the time this pass runs.
      lastInRun: run.last.lastInRun,
      // Eligibility already refused a reply, so there is no marker to carry.
      replyMarker: ReplyMarker.none,
      album: [for (final r in run) r.message],
    ));
    i = end;
  }
  return out;
}

({List<RoomItem> items, Set<String> hidden}) buildRoomItems({
  required List<ChatMessage> messages,
  required bool roomIsEphemeral,
  required bool Function(ChatMessage m) mustKeepOwnRow,
  required String Function(DateTime day) dayLabel,
  int minFolded = kMinFoldedMessages,
  /// The message the UNREAD MESSAGES line sits above. Null draws no line — a
  /// room with no read cursor yet, one that was already fully read, or one
  /// whose first unread message is not in [messages].
  ///
  /// A message id and not the reader's `lastReadAt`, which is what this used
  /// to take. A timestamp is re-evaluated on every pass, so a message landing
  /// while the room is ON SCREEN is newer than the cursor too and gets a line
  /// of its own above it — an "unread" label over something the reader is
  /// watching arrive. The room screen picks the row once instead, and picks it
  /// with the same rule it aims the opening scroll with, which is also what
  /// keeps the line and the viewport pointed at the same message. See
  /// `_settleUnreadDivider`.
  String? unreadBeforeId,
}) {
  if (messages.isEmpty) {
    return (items: <RoomItem>[IntroItem()], hidden: const <String>{});
  }

  // ── Pass 0: bucket by thread ──────────────────────────────────────────
  // `messages` arrives chronological, so each bucket is chronological too.
  // Never assume the root is present: a hard-deleted root leaves a bucket
  // where no member has `id == threadKey`, and `members.first` is then the
  // oldest survivor — which is the right message to keep in place.
  final threads = <String, List<ChatMessage>>{};
  for (final m in messages) {
    threads.putIfAbsent(m.threadKey, () => <ChatMessage>[]).add(m);
  }

  // ── Pass 1: choose what to fold ───────────────────────────────────────
  final hidden = <String>{};
  final foldAt = <String, ThreadFoldItem>{};

  // Never fold in a Chamber-of-Secrets room: a folded message can expire
  // before the user ever sees it, which defeats the point of the room.
  // Rails still draw — they hide nothing.
  if (!roomIsEphemeral) {
    for (final entry in threads.entries) {
      final members = entry.value;
      if (members.length < minFolded + 2) continue;

      // Root and newest always stay put.
      final interior = members.sublist(1, members.length - 1);

      // Only a contiguous run may fold. A row that must keep its own place can
      // punch holes in the interior, and a chip spanning a hole would misstate
      // where the gap is.
      var bestStart = -1, bestLen = 0, runStart = -1, runLen = 0;
      for (var i = 0; i < interior.length; i++) {
        if (mustKeepOwnRow(interior[i])) {
          runStart = -1;
          runLen = 0;
          continue;
        }
        if (runStart < 0) runStart = i;
        runLen++;
        if (runLen > bestLen) {
          bestLen = runLen;
          bestStart = runStart;
        }
      }
      if (bestLen < minFolded) continue;

      final run = interior.sublist(bestStart, bestStart + bestLen);
      for (final m in run) {
        hidden.add(m.id);
      }
      final senders = <String>[];
      for (final m in run) {
        if (!senders.contains(m.senderId)) senders.add(m.senderId);
      }
      foldAt[run.first.id] = ThreadFoldItem(
        threadKey: entry.key,
        count: run.length,
        oldestHiddenId: run.first.id,
        senderIds: senders,
      );
    }
  }

  // ── Pass 2: emit rows ─────────────────────────────────────────────────
  final out = <RoomItem>[IntroItem()];

  DateTime? lastDay;
  ChatMessage? prevVisible;
  // The most recently emitted message row, so a grouped row can reach back and
  // clear its predecessor's `lastInRun`.
  MessageItem? prevRow;
  // Already true when there's no row to mark, so the loop below never has to
  // null-check `unreadBeforeId` itself.
  var unreadMarked = unreadBeforeId == null;

  for (final m in messages) {
    if (!unreadMarked && m.id == unreadBeforeId) {
      out.add(UnreadDividerItem());
      unreadMarked = true;
    }

    final fold = foldAt[m.id];
    final isHidden = hidden.contains(m.id);

    // The chip is keyed on the OLDEST folded message, which is itself hidden,
    // so it has to be emitted before the skip below — otherwise the fold is
    // computed and then silently never rendered.
    if (fold != null) {
      // The chip is visible content, so it opens a day like a message does.
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || d != lastDay) {
        out.add(DateDividerItem(dayLabel(d)));
        lastDay = d;
      }
      out.add(fold);
      // Barrier. Clearing prevVisible makes `grouped` false for the next row
      // with no extra branches — a fold is a new visual beat, so nothing may
      // group across it.
      prevVisible = null;
    }

    if (isHidden) continue;

    // Dividers otherwise walk the *visible* stream, so a day with nothing
    // left to show doesn't emit a divider over empty space.
    final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
    var startsDay = false;
    if (lastDay == null || d != lastDay) {
      out.add(DateDividerItem(dayLabel(d)));
      lastDay = d;
      startsDay = true;
    }

    final marker = replyMarkerFor(prevVisible, m);

    // Folds don't need a clause here: they always emit a chip, and the chip
    // clears prevVisible.
    final grouped = continuesRun(prevVisible, m, startsDay: startsDay);
    final newSender = !sameSenderAsPrev(prevVisible, m, startsDay: startsDay);

    // The row above only stays a run's last once nothing continues it.
    if (grouped) prevRow?.lastInRun = false;

    final row = MessageItem(
      m,
      grouped: grouped,
      newSender: newSender,
      replyMarker: marker,
    );
    out.add(row);
    prevRow = row;

    prevVisible = m;
  }

  return (items: collapseAlbums(out), hidden: hidden);
}
