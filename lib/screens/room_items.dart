import '../models/chat_message.dart';
import '../models/enums.dart';

/// Flattening of a room's message list into renderable rows.
///
/// Lives outside `room_screen.dart` and depends on nothing but [ChatMessage]
/// so the whole thing is unit-testable without pumping widgets or standing up
/// a Convex client. [buildRoomItems] is pure.
///
/// Beyond date dividers it does two thread-aware things, both keyed on
/// [ChatMessage.threadKey] (`rootId ?? id` — two messages are in the same
/// thread iff their keys match):
///
///  * **Rails.** A thread whose members are separated by unrelated messages
///    gets a vertical connector spanning from its first visible member to its
///    last, drawn solid beside members and faded across everything in between.
///    Threads in this app interleave freely with the rest of the room, so this
///    is the only thing that makes one legible as a structure.
///  * **Folds.** A long thread's interior members collapse into a single
///    [ThreadFoldItem]. The root and the newest member always stay.
///
/// Nothing here keys off adjacency — a thread's messages are almost never
/// consecutive in the room timeline.

// ───────────────────────── list item model ─────────────────────────

abstract class RoomItem {
  /// Rail segments crossing this row, at most one per lane. Empty for rows
  /// no thread spans.
  List<RailSegment> get rails;
}

class IntroItem extends RoomItem {
  @override
  List<RailSegment> get rails => const [];
}

class DateDividerItem extends RoomItem {
  DateDividerItem(this.label, {this.rails = const []});
  final String label;
  @override
  final List<RailSegment> rails;
}

class MessageItem extends RoomItem {
  MessageItem(
    this.message, {
    this.grouped = false,
    this.lastInRun = true,
    this.replyMarker = ReplyMarker.full,
    this.rails = const [],
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

  @override
  final List<RailSegment> rails;
}

/// One or more of a thread's interior messages, folded away. Rendered as a
/// compact chip; tapping it opens the thread overlay.
class ThreadFoldItem extends RoomItem {
  ThreadFoldItem({
    required this.threadKey,
    required this.count,
    required this.oldestHiddenId,
    required this.senderIds,
    this.rails = const [],
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

  @override
  final List<RailSegment> rails;
}

// ───────────────────────── rails ─────────────────────────

enum RailKind {
  /// Topmost row of a thread's span — the rail starts here, rounded.
  capTop,

  /// Bottommost row of a thread's span — the rail ends here, rounded.
  capBottom,

  /// A thread member (or its fold chip) mid-span: solid, full height.
  through,

  /// A row that is *not* part of the thread but sits inside its span. Drawn
  /// faded, so the thread reads as continuing past unrelated messages.
  across,
}

class RailSegment {
  const RailSegment(this.kind, this.lane);

  final RailKind kind;

  /// Which parallel track to draw on, so overlapping threads don't collide.
  /// 0-based, innermost first.
  final int lane;

  /// True for rows belonging to the thread itself, as opposed to unrelated
  /// rows the rail merely passes on its way down.
  bool get isMember => kind != RailKind.across;

  @override
  String toString() => 'RailSegment($kind, lane $lane)';
}

extension RoomItemRails on RoomItem {
  /// The segment for this row belonging to a thread it is actually part of,
  /// if any. A row can carry several segments — one thread's member row is
  /// often another thread's [RailKind.across].
  RailSegment? get memberRail {
    for (final r in rails) {
      if (r.isMember) return r;
    }
    return null;
  }
}

// ───────────────────────── the build ─────────────────────────

/// Minimum number of messages that must be folded for a fold to be worth it.
/// Folding one is a net loss: the chip replaces the row it hides, so you
/// trade content for nothing.
const int kMinFoldedMessages = 2;

/// How many overlapping thread rails can be drawn side by side before extra
/// threads simply go without one, rather than crowding the gutter.
const int kMaxRailLanes = 2;

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
  required bool Function(ChatMessage m) isPinned,
  required String Function(DateTime day) dayLabel,
  int minFolded = kMinFoldedMessages,
  int maxRailLanes = kMaxRailLanes,
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

      // Only a contiguous run may fold. Pinning can punch holes in the
      // interior, and a chip spanning a hole would misstate where the gap is.
      var bestStart = -1, bestLen = 0, runStart = -1, runLen = 0;
      for (var i = 0; i < interior.length; i++) {
        if (isPinned(interior[i])) {
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
  // Row indices are recorded as we go so rail spans can be resolved after,
  // once we know which rows actually survived.
  final out = <RoomItem>[IntroItem()];
  final threadRows = <String, List<int>>{};

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
      threadRows.putIfAbsent(fold.threadKey, () => <int>[]).add(out.length - 1);
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
    if (threads[m.threadKey]!.length > 1) {
      threadRows.putIfAbsent(m.threadKey, () => <int>[]).add(out.length - 1);
    }

    prevVisible = m;
  }

  // ── Pass 3: rails ─────────────────────────────────────────────────────
  _applyRails(out, threadRows, maxRailLanes);

  return (items: out, hidden: hidden);
}

/// Resolves each thread's visible span into per-row [RailSegment]s, assigning
/// overlapping threads to parallel lanes.
///
/// A thread only earns a rail if it has at least two visible rows AND a gap
/// between them — two adjacent rows already read as connected, so a rail there
/// is noise. This is deliberately independent of folding: most threads are too
/// short to fold but still benefit from the connector.
void _applyRails(
  List<RoomItem> out,
  Map<String, List<int>> threadRows,
  int maxRailLanes,
) {
  // Indices address `out`, which interleaves date dividers among the content
  // rows, so raw index arithmetic overstates the gap: a parent and its reply
  // that sit next to each other but straddle midnight are two indices apart
  // and used to earn a rail connecting two rows already touching. Count
  // content rows only. Spans stay in raw indices — everything below addresses
  // `out` directly — so this is purely a measuring tape.
  final contentOrdinal = List<int>.filled(out.length, 0);
  var seen = 0;
  for (var i = 0; i < out.length; i++) {
    contentOrdinal[i] = seen;
    if (out[i] is! DateDividerItem) seen++;
  }

  final spans = <({int start, int end, Set<int> rows})>[];
  for (final rows in threadRows.values) {
    if (rows.length < 2) continue;
    final start = rows.first;
    final end = rows.last;
    // Adjacent rows need no connector.
    if (contentOrdinal[end] - contentOrdinal[start] < 2) continue;
    spans.add((start: start, end: end, rows: rows.toSet()));
  }
  if (spans.isEmpty) return;

  spans.sort((a, b) => a.start.compareTo(b.start));

  // Greedy lane assignment: a lane frees up once its last span has ended.
  final laneEnds = <int>[];
  final segments = <int, List<RailSegment>>{};
  for (final s in spans) {
    var lane = -1;
    for (var i = 0; i < laneEnds.length; i++) {
      if (laneEnds[i] < s.start) {
        lane = i;
        break;
      }
    }
    if (lane < 0) {
      if (laneEnds.length >= maxRailLanes) continue; // this one goes railless
      lane = laneEnds.length;
      laneEnds.add(s.end);
    } else {
      laneEnds[lane] = s.end;
    }

    for (var row = s.start; row <= s.end; row++) {
      final RailKind kind;
      if (row == s.start) {
        kind = RailKind.capTop;
      } else if (row == s.end) {
        kind = RailKind.capBottom;
      } else if (s.rows.contains(row)) {
        kind = RailKind.through;
      } else {
        // Not this thread's message — the rail only passes through. A row can
        // collect several of these while still being a member of its own
        // thread on another lane, which is why rails are a list.
        kind = RailKind.across;
      }
      segments.putIfAbsent(row, () => <RailSegment>[]).add(
            RailSegment(kind, lane),
          );
    }
  }

  for (final entry in segments.entries) {
    out[entry.key] = _withRails(out[entry.key], entry.value);
  }
}

/// Rebuilds a row carrying its rail segments. Items are immutable value-ish
/// objects, so this replaces rather than mutates.
RoomItem _withRails(RoomItem item, List<RailSegment> rails) {
  if (item is MessageItem) {
    return MessageItem(
      item.message,
      grouped: item.grouped,
      lastInRun: item.lastInRun,
      replyMarker: item.replyMarker,
      rails: rails,
    );
  }
  if (item is ThreadFoldItem) {
    return ThreadFoldItem(
      threadKey: item.threadKey,
      count: item.count,
      oldestHiddenId: item.oldestHiddenId,
      senderIds: item.senderIds,
      rails: rails,
    );
  }
  if (item is DateDividerItem) {
    return DateDividerItem(item.label, rails: rails);
  }
  return item;
}
