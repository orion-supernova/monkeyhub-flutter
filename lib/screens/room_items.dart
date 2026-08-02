import '../models/chat_message.dart';
import '../models/enums.dart';

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
/// Nothing here keys off adjacency — a thread's messages are almost never
/// consecutive in the room timeline.

// ───────────────────────── list item model ─────────────────────────

/// Marker for everything the transcript can render. Carries nothing itself —
/// it exists so the ListView has one type to switch on.
abstract class RoomItem {}

class IntroItem extends RoomItem {}

class DateDividerItem extends RoomItem {
  DateDividerItem(this.label);
  final String label;
}

class MessageItem extends RoomItem {
  MessageItem(
    this.message, {
    this.grouped = false,
    this.lastInRun = true,
    this.replyMarker = ReplyMarker.full,
  });

  final ChatMessage message;

  /// Continues a run from the same sender: the sender's name is not repeated
  /// and the vertical gap tightens, so five replies in a row read as one
  /// block instead of five separate cards.
  final bool grouped;

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

/// Whether [m] continues [prev]'s run: same sender, same day, close in time,
/// and not interrupted by a full quote card — that card is tall enough to
/// need a beat of its own, whereas the compact marker is one line and sits
/// happily inside a run. Shared with the thread overlay, which renders the
/// same bubbles against its own list and used to carry a hand-copied version
/// of this rule.
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
    !startsDay &&
    prev != null &&
    prev.senderId == m.senderId &&
    replyMarkerFor(prev, m) != ReplyMarker.full &&
    m.createdAt.difference(prev.createdAt).inMinutes < 5;

({List<RoomItem> items, Set<String> hidden}) buildRoomItems({
  required List<ChatMessage> messages,
  required bool roomIsEphemeral,
  required bool Function(ChatMessage m) mustKeepOwnRow,
  required String Function(DateTime day) dayLabel,
  int minFolded = kMinFoldedMessages,
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

  for (final m in messages) {
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

    // The row above only stays a run's last once nothing continues it.
    if (grouped) prevRow?.lastInRun = false;

    final row = MessageItem(m, grouped: grouped, replyMarker: marker);
    out.add(row);
    prevRow = row;

    prevVisible = m;
  }

  return (items: out, hidden: hidden);
}
