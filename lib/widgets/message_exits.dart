import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/chat_message.dart';
import '../theme/perf_tier.dart';
import 'dust_dissolve.dart';

/// Why a transcript row is leaving, which is all that picks its exit.
enum ExitReason {
  /// Somebody deleted it: the reader (one message, an album, a selection) or
  /// another member, seen through `ChatRepository.serverRemovals`. Exit:
  /// [DustDissolve], Telegram's dust.
  deleted,

  /// A vanish-mode message burned by the server. It arrives exactly like a
  /// remote removal; the only thing that tells it apart is that the message
  /// it removed carried `vanishUntil`. Exit: the same dust as [deleted].
  vanished,

  /// A Chamber of Secrets message ran out of time. Exit: `DepartingRow`, the
  /// hurricane, drawn from a capture of the bubble.
  expired,
}

/// One dust row's part in an exit: when its dust starts and how much of the
/// shared particle budget it may spend.
@immutable
class DustEntry {
  const DustEntry({
    required this.delay,
    required this.particles,
    required this.seed,
    this.reason = ExitReason.deleted,
  });

  /// After the batch starts. Rows go top to bottom a beat apart, so several
  /// deleted together read as one wave rather than a flash.
  final Duration delay;
  final int particles;
  final int seed;

  /// [ExitReason.deleted] or [ExitReason.vanished]; both look the same.
  final ExitReason reason;
}

/// Everything a departing row needs to blow itself apart after the message
/// it drew is gone: the message, its raster, and where the bubble sat in the
/// row.
class DepartureCapture {
  const DepartureCapture({
    required this.message,
    required this.rowKey,
    required this.isMine,
    required this.image,
    required this.pixelRatio,
    required this.bubbleSize,
    required this.bubbleInRow,
    required this.rowSize,
    required this.outline,
    this.tiles = MessageExits.maxTiles,
  });

  final ChatMessage message;
  final String rowKey;
  final bool isMine;

  /// The bubble's pixels, at [pixelRatio] device pixels per logical pixel.
  /// Null when nothing could be rastered — a bubble carrying a platform view,
  /// or one that had already left the tree — in which case the row leaves
  /// the quiet way.
  final ui.Image? image;
  final double pixelRatio;

  /// The bubble's box, in logical pixels, and its top-left inside the row.
  final Size bubbleSize;
  final Offset bubbleInRow;

  /// The row's own box, so the ghost that replaces it holds the same height
  /// until it collapses.
  final Size rowSize;

  /// The bubble's outline in its own coordinates — tail, corners and all —
  /// so only tiles that were actually bubble take flight.
  final Path outline;

  /// The most grains this one may cut the bubble into: its share of
  /// [MessageExits.tileBudget] with whatever else is leaving right now.
  final int tiles;
}

/// A row being held: the messages it draws and the exit it plays. Exactly one
/// of [dust] and [capture] is set, which is the whole of "the visual is chosen
/// by reason".
class _Exit {
  _Exit.dust(this.reason, this.messages, DustEntry this.dust) : capture = null;
  _Exit.expired(DepartureCapture this.capture)
      : reason = ExitReason.expired,
        messages = [capture.message],
        dust = null;

  final ExitReason reason;
  final List<ChatMessage> messages;
  final DustEntry? dust;
  final DepartureCapture? capture;
}

/// Which transcript rows are LEAVING, and are therefore held on screen to
/// play an exit before the list closes over them. One ledger for every way a
/// row can go, keyed by [ExitReason]:
///
///  * [ExitReason.deleted] and [ExitReason.vanished] turn the row to dust
///    ([DissolvingRow] over [DustDissolve]). Only an explicit removal ever
///    does this:
///      - **Local** — the reader's own DELETE (one message, an album, or a
///        selection). The screen calls [begin] with the messages BEFORE it
///        asks the repository, so the rows are held from the first frame and
///        the optimistic local removal that follows cannot drop them.
///      - **Remote** — `ChatRepository.serverRemovals`, through
///        [observeServerRemovals]: rows the server stopped sending from the
///        INSIDE of its live window. That window is the newest rows of a
///        contiguous range, so a row can only fall off its oldest edge; one
///        missing from between rows that are still there was removed, not
///        paged out. See there. A vanish-mode burn is a server-side delete,
///        so it arrives here too; it is told apart by the removed message
///        having carried `vanishUntil`.
///  * [ExitReason.expired] is a Chamber of Secrets message running out of
///    time, with its own capture and its own exit (`DepartingRow`). Nothing
///    here ever dissolves an ephemeral row, and nothing ever blows an
///    ordinary one apart.
///
/// Only rows that are on screen dissolve. One that is scrolled away just goes,
/// as before. A held row stays in the list (spliced back by [withHeld]) until
/// its exit has finished and its height has closed; [end] then drops it, and
/// keeps it hidden for as long as the server is still listing it.
///
/// ## Dust rows
///
/// Rows are registered by the builder ([registerRow]) under the id of the
/// message that heads them, with every message the row draws — an album is
/// one row of several. A row is only taken when ALL of its messages are being
/// removed: deleting one photograph out of an album leaves the album standing
/// and that photograph simply goes.
///
/// ## Expiring rows
///
/// A Chamber of Secrets message dies twice. Its clock runs out on this
/// device, and, a network round trip apart, the server deletes it and the
/// subscription re-delivers the window without it. Either can come first —
/// a device a few seconds fast sees the row vanish from under a countdown
/// that still had time on it — and the exit has to play exactly once from
/// whichever arrives first. The bubble itself is gone by the time the second
/// one lands, so the thing that plays is a *capture*: the bubble's pixels,
/// taken while it was still on screen, handed to a ghost row that holds the
/// message's place in the transcript and blows the picture apart.
///
/// Two moments can take that capture:
///
///  * **The clock.** [EphemeralMessageBubble] notices its own expiry on the
///    5Hz tick and asks for an exit ([requestExpiry]); the raster is taken
///    after that frame, when the bubble has painted one last time at full
///    strength.
///  * **The delivery.** [observeExpiredRemoval] runs synchronously inside the
///    repository callback, BEFORE the screen rebuilds without the row — the
///    one moment the vanished row's render tree is still the last painted
///    frame and can still be read.
///
/// The ghost is a real row: [withHeld] splices the departed message back
/// into the timeline at its chronological place so the list keeps it in
/// `itemCount` while the exit runs, and [end] drops it again. Identity is the
/// arrivals ledger's `rowKey`, so a send that the server confirmed mid-exit is
/// one row, not two.
class MessageExits {
  MessageExits({required this.onChanged, this.budget = defaultBudget});

  /// Called when rows start or finish, so the owner can rebuild. Never called
  /// synchronously from a request.
  final VoidCallback onChanged;

  /// Particles shared by every row dissolving at once.
  final int budget;

  static const int defaultBudget = 12000;

  /// Between one row's dust and the next one down.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Most rows a remote removal may dissolve at once. A burst is not a
  /// deletion anybody watched happen (a block, a moderator clearing a room):
  /// those rows just go.
  static const int maxRemoteBurst = 12;

  /// Grains per expiring bubble, at most (see `DepartingRow`).
  static const int maxTiles = 5000;

  /// Grains shared by every bubble leaving at once. A burst of messages sent
  /// together expires together; each takes what is left, never under
  /// [_minTiles], so ten at once cost about what two do.
  static const int tileBudget = 12000;
  static const int _minTiles = 900;

  int get _tilesInFlight {
    var n = 0;
    for (final e in _active.values) {
      n += e.capture?.tiles ?? 0;
    }
    return n;
  }

  /// Dust rows: the row's box, the messages it draws and the head of each.
  final Map<String, GlobalKey> _rowBoxes = {};
  final Map<String, List<String>> _members = {};
  final Map<String, String> _headOf = {};

  /// Expiring rows: the key on the bubble's own repaint boundary (what gets
  /// rastered) and on the row that draws it.
  final Map<String, GlobalKey> _anchors = {};
  final Map<String, GlobalKey> _expiringBoxes = {};

  /// Rows that asked to leave on their clock and are waiting for the end of
  /// the frame to be rastered.
  final Set<String> _pending = {};

  /// Every row held for an exit, under its head (dust) or its row key
  /// (expired).
  final Map<String, _Exit> _active = {};
  final Set<String> _heldIds = {};

  /// Ids whose rows have finished but which the server may still list (a
  /// selection delete is not removed locally first, and an expiry's delete is
  /// a round trip behind the local clock) — hidden until it stops. Without
  /// this the row would come back as a live bubble, expired, and blow up a
  /// second time.
  final Set<String> _gone = {};

  /// The last [ChatRepository.serverRemovals] serial acted on.
  int _seenRemovals = 0;

  /// Bumped when the held set changes; [withHeld] memoises on it.
  int _version = 0;
  List<ChatMessage>? _mergedSource;
  int _mergedVersion = -1;
  List<ChatMessage> _merged = const [];
  bool _disposed = false;

  /// The row headed by [head] draws [members] (just [head] for an ordinary
  /// row) and is measured by [box]. Cheap; call it on every build.
  void registerRow(String head, List<String> members, GlobalKey box) {
    _rowBoxes[head] = box;
    _members[head] = members;
    for (final id in members) {
      _headOf[id] = head;
    }
    _headOf[head] = head;
    _schedulePrune();
  }

  /// The key on the row that draws [rowKey], so a capture can measure how
  /// tall the row was and where the bubble sat in it.
  void registerExpiringRow(String rowKey, GlobalKey rowBox) {
    _expiringBoxes[rowKey] = rowBox;
  }

  /// The key on the bubble's own repaint boundary — what gets rastered.
  GlobalKey anchorKeyFor(String rowKey) {
    _schedulePrune();
    return _anchors.putIfAbsent(rowKey, () => GlobalKey(debugLabel: 'depart:$rowKey'));
  }

  int _pruneAt = 512;
  int _anchorPruneAt = 256;
  bool _pruneScheduled = false;

  void _schedulePrune() {
    if (_pruneScheduled) return;
    if (_rowBoxes.length <= _pruneAt && _anchors.length <= _anchorPruneAt) {
      return;
    }
    // A long session scrolls past thousands of rows, and each one left an
    // entry here (and a row that expired off screen never departs, so nothing
    // ends it: its keys would stay for the session). Swept after the frame,
    // when every row being built has mounted: a box with no element by then
    // is off screen, and is put back by its own build the next time it is.
    _pruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prune());
  }

  void _prune() {
    _pruneScheduled = false;
    if (_disposed) return;
    final stale = [
      for (final e in _rowBoxes.entries)
        if (e.value.currentContext == null && !_active.containsKey(e.key)) e.key,
    ];
    for (final head in stale) {
      _rowBoxes.remove(head);
      for (final id in _members.remove(head) ?? const <String>[]) {
        if (_headOf[id] == head) _headOf.remove(id);
      }
      if (_headOf[head] == head) _headOf.remove(head);
    }
    _pruneAt = _rowBoxes.length * 2 < 512 ? 512 : _rowBoxes.length * 2;
    bool live(String k) => _active.containsKey(k) || _pending.contains(k);
    _anchors.removeWhere((k, key) => key.currentContext == null && !live(k));
    _expiringBoxes.removeWhere((k, key) => key.currentContext == null && !live(k));
    _anchorPruneAt = math.max(256, _anchors.length * 2);
  }

  /// The dust row headed by [head] is dissolving: when, and with how much.
  DustEntry? entryFor(String head) => _active[head]?.dust;

  /// The capture the expiring row keyed [rowKey] is blowing apart from.
  DepartureCapture? captureFor(String rowKey) => _active[rowKey]?.capture;

  /// Whether the row keyed [rowKey] is mid-way through an expiry exit.
  bool isExpiring(String rowKey) => _active[rowKey]?.capture != null;

  bool get isEmpty => _active.isEmpty && _gone.isEmpty;

  /// Whether [messageId] is held on screen by an exit in progress.
  bool isHeld(String messageId) => _heldIds.contains(messageId);

  /// Whether [messageId] has already left the screen for good.
  bool hasExited(String messageId) => _gone.contains(messageId);

  /// [messages] are being removed. Every on-screen row they make up whole
  /// starts to dissolve; returns how many did. Ephemeral messages are never
  /// taken: their exit is the expiry one. A row is [ExitReason.vanished] when
  /// any message it draws carried `vanishUntil`, [ExitReason.deleted]
  /// otherwise; the dust is the same.
  int begin(Iterable<ChatMessage> messages, {bool haptic = true}) {
    if (_disposed) return 0;
    final byId = <String, ChatMessage>{
      for (final m in messages)
        if (!m.isEphemeral && !m.id.startsWith('tmp_')) m.id: m,
    };
    if (byId.isEmpty) return 0;
    final rows = <({String head, double top, List<ChatMessage> members})>[];
    final seen = <String>{};
    for (final id in byId.keys) {
      final head = _headOf[id];
      if (head == null || !seen.add(head) || _active.containsKey(head)) {
        continue;
      }
      final ids = _members[head] ?? [head];
      if (!ids.every(byId.containsKey)) continue;
      final top = _visibleTop(_rowBoxes[head]);
      if (top == null) continue;
      rows.add((
        head: head,
        top: top,
        members: [for (final i in ids) byId[i]!],
      ));
    }
    if (rows.isEmpty) return 0;
    rows.sort((a, b) => a.top.compareTo(b.top));
    final share = (budget / rows.length)
        .round()
        .clamp(400, DustDissolve.maxParticles);
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final reason = r.members.any((m) => m.vanishUntil != null)
          ? ExitReason.vanished
          : ExitReason.deleted;
      _active[r.head] = _Exit.dust(
        reason,
        r.members,
        DustEntry(
          delay: stagger * i,
          particles: share,
          seed: r.head.hashCode,
          reason: reason,
        ),
      );
      for (final m in r.members) {
        _heldIds.add(m.id);
        _gone.remove(m.id);
      }
    }
    _version++;
    if (haptic) HapticFeedback.lightImpact();
    onChanged();
    return rows.length;
  }

  /// Take `ChatRepository.serverRemovals`: if it has moved since the last
  /// call, every message of [shown] (the list the screen drew last, held rows
  /// included) that the server removed starts its exit, before the rebuild
  /// that would have dropped it. No haptic: somebody else did this.
  int observeServerRemovals(
    ({int serial, Set<String> ids}) removals,
    List<ChatMessage> shown,
  ) {
    if (removals.serial == _seenRemovals) return 0;
    _seenRemovals = removals.serial;
    final gone = [
      for (final m in shown)
        if (removals.ids.contains(m.id)) m,
    ];
    if (gone.isEmpty || gone.length > maxRemoteBurst) return 0;
    return begin(gone, haptic: false);
  }

  /// The delete failed: whatever dust rows hold any of [ids] come back.
  void cancel(Iterable<String> ids) {
    if (_disposed) return;
    var changed = false;
    for (final id in ids) {
      changed = _gone.remove(id) || changed;
      final head = _headOf[id];
      if (head == null || _active[head]?.dust == null) continue;
      for (final m in _active.remove(head)!.messages) {
        _heldIds.remove(m.id);
      }
      changed = true;
    }
    if (!changed) return;
    _version++;
    onChanged();
  }

  /// The row keyed [rowKey] has reached its expiry on this device's clock.
  ///
  /// Safe to call from build, and on every tick after expiry: the first call
  /// schedules one capture for the end of the frame and the rest are no-ops.
  /// A row still on its optimistic `tmp_` id never departs — it has not been
  /// confirmed, so it cannot have expired.
  void requestExpiry(
    String rowKey,
    ChatMessage message, {
    required bool isMine,
    required ShapeBorder outline,
  }) {
    if (_disposed) return;
    if (message.id.startsWith('tmp_')) return;
    if (_active.containsKey(rowKey) || !_pending.add(rowKey)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_pending.remove(rowKey)) return;
      if (_active.containsKey(rowKey)) return;
      _beginExpired(rowKey, message, isMine: isMine, outline: outline);
      onChanged();
    });
  }

  /// Take a delivery: every ephemeral message in [previous] that is missing
  /// from [current] and not yet departing is captured NOW, while its row is
  /// still the last painted frame, and begins its exit.
  ///
  /// Synchronous on purpose; call it before the rebuild that drops the row.
  void observeExpiredRemoval(
    List<ChatMessage> previous,
    List<ChatMessage> current, {
    required String Function(ChatMessage) keyFor,
    required bool Function(ChatMessage) isMine,
    required ShapeBorder Function(ChatMessage) outlineFor,
  }) {
    if (_disposed || identical(previous, current) || previous.isEmpty) return;
    Set<String>? present;
    var began = false;
    for (final m in previous) {
      if (!m.isEphemeral || m.id.startsWith('tmp_')) continue;
      present ??= {for (final c in current) c.id};
      if (present.contains(m.id)) continue;
      final rowKey = keyFor(m);
      if (_active.containsKey(rowKey)) continue;
      // An exit the clock already asked for but has not rastered yet is
      // taken over here: the row is about to leave the tree, and the end of
      // the frame would be too late.
      _pending.remove(rowKey);
      if (_beginExpired(rowKey, m, isMine: isMine(m), outline: outlineFor(m))) {
        began = true;
      }
    }
    if (began) onChanged();
  }

  /// The row keyed [key] has finished its exit (dust gone and height closed,
  /// or the picture blown away). Drops it, frees any raster, and keeps its
  /// messages hidden while the server still lists them.
  void end(String key) {
    final exit = _active.remove(key);
    _anchors.remove(key);
    _expiringBoxes.remove(key);
    if (exit == null) return;
    for (final m in exit.messages) {
      _heldIds.remove(m.id);
      _gone.add(m.id);
    }
    _version++;
    exit.capture?.image?.dispose();
    if (!_disposed) onChanged();
  }

  /// [timeline] with every held message spliced back at its chronological
  /// place and every finished one left out. The same instance while nothing
  /// is in progress — so the screen's item cache keyed on list identity keeps
  /// working — and memoised otherwise.
  List<ChatMessage> withHeld(List<ChatMessage> timeline) {
    if (_active.isEmpty && _gone.isEmpty) return timeline;
    if (identical(timeline, _mergedSource) && _version == _mergedVersion) {
      return _merged;
    }
    final present = {for (final m in timeline) m.id};
    // A message that has left stays away. The server's delete can land a
    // beat after the exit has finished — the delivery round trip is not the
    // local clock — and until it does the row would otherwise come back.
    // Forgotten the moment the server no longer lists it.
    _gone.removeWhere((id) => !present.contains(id));
    final base = _gone.isEmpty
        ? timeline
        : [for (final m in timeline) if (!_gone.contains(m.id)) m];
    // A held row is only spliced back if the list has no copy of it under ANY
    // of its ids: mid-send the optimistic row and the server's echo are one
    // message with two ids, and both would claim the same row key.
    final known = {for (final m in timeline) ...m.identities};
    final missing = [
      for (final e in _active.values)
        for (final m in e.messages)
          if (!m.identities.any(known.contains)) m,
    ];
    List<ChatMessage> merged;
    if (missing.isEmpty) {
      merged = base;
    } else {
      missing.sort(_byTime);
      merged = <ChatMessage>[];
      var g = 0;
      for (final m in base) {
        while (g < missing.length && _byTime(missing[g], m) < 0) {
          merged.add(missing[g++]);
        }
        merged.add(m);
      }
      while (g < missing.length) {
        merged.add(missing[g++]);
      }
    }
    _mergedSource = timeline;
    _mergedVersion = _version;
    return _merged = merged;
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    for (final e in _active.values) {
      e.capture?.image?.dispose();
    }
    _active.clear();
    _heldIds.clear();
    _rowBoxes.clear();
    _anchors.clear();
    _expiringBoxes.clear();
  }

  static int _byTime(ChatMessage a, ChatMessage b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  /// The row's top in global coordinates, or null when it is not on screen:
  /// not built, or built only in the list's cache extent.
  static double? _visibleTop(GlobalKey? key) {
    final ctx = key?.currentContext;
    final box = ctx?.findRenderObject();
    if (ctx == null || box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    final Rect rect;
    try {
      rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
    } catch (_) {
      return null;
    }
    Rect? port;
    final scrollable = Scrollable.maybeOf(ctx);
    final portBox = scrollable?.context.findRenderObject();
    if (portBox is RenderBox && portBox.attached && portBox.hasSize) {
      port = MatrixUtils.transformRect(
        portBox.getTransformTo(null),
        Offset.zero & portBox.size,
      );
    } else {
      final view = View.maybeOf(ctx);
      if (view != null) {
        port = Offset.zero & (view.physicalSize / view.devicePixelRatio);
      }
    }
    if (port != null && !rect.overlaps(port)) return null;
    return rect.top;
  }

  /// Rasters the bubble under [rowKey] and records the departure. Returns
  /// false when there was nothing on screen to take — the row was never
  /// built, or is already gone — in which case there is nothing to animate
  /// and the row leaves the list the ordinary way.
  bool _beginExpired(
    String rowKey,
    ChatMessage message, {
    required bool isMine,
    required ShapeBorder outline,
  }) {
    final boundary = _anchors[rowKey]?.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.attached ||
        !boundary.hasSize) {
      return false;
    }
    final bubbleSize = boundary.size;
    if (bubbleSize.isEmpty) return false;

    final row = _expiringBoxes[rowKey]?.currentContext?.findRenderObject();
    var rowSize = bubbleSize;
    var bubbleInRow = Offset.zero;
    if (row is RenderBox && row.attached && row.hasSize) {
      rowSize = row.size;
      try {
        bubbleInRow = boundary.localToGlobal(Offset.zero, ancestor: row);
      } catch (_) {
        bubbleInRow = Offset.zero;
      }
    }

    final view = _anchors[rowKey]?.currentContext.let(View.maybeOf);
    final dpr = view?.devicePixelRatio ?? 2.0;
    final pixelRatio = Perf.captureRatio(dpr, max: 2);
    ui.Image? image;
    try {
      image = boundary.toImageSync(pixelRatio: pixelRatio);
    } catch (_) {
      image = null;
    }

    final capture = DepartureCapture(
      message: message,
      rowKey: rowKey,
      isMine: isMine,
      image: image,
      pixelRatio: pixelRatio,
      bubbleSize: bubbleSize,
      bubbleInRow: bubbleInRow,
      rowSize: rowSize,
      outline: outline.getOuterPath(Offset.zero & bubbleSize),
      tiles: (Perf.particles(tileBudget) - _tilesInFlight).clamp(
        Perf.particles(_minTiles),
        Perf.particles(maxTiles),
      ),
    );
    _active[rowKey] = _Exit.expired(capture);
    _heldIds.add(message.id);
    _version++;
    return true;
  }
}

/// A transcript row that can be deleted to dust.
///
/// Costs nothing while idle: with no [entry] it returns the row itself, no
/// wrapper, no controller, no repaint boundary. Every transcript row carries
/// one and rows mount and unmount all through a scroll, so anything more here
/// was paid on every frame of a fling (it cost 120 Hz scrolling its
/// smoothness). The wrapper and the controller appear only once a deletion
/// starts on this row; the row remounts inside it then, and the dust is taken
/// from the frame it paints there. Given one, it waits out [DustEntry.delay], burns the row
/// through [DustDissolve], and closes the row's height as the dust leaves —
/// starting once the wave has crossed, so the rows around it slide together
/// while the motes are still in the air — then calls [onGone].
class DissolvingRow extends StatefulWidget {
  const DissolvingRow({
    super.key,
    required this.entry,
    required this.onGone,
    required this.child,
  });

  final DustEntry? entry;
  final VoidCallback onGone;
  final Widget child;

  /// How long the row takes to close.
  static const Duration collapseDuration = Duration(milliseconds: 280);

  @override
  State<DissolvingRow> createState() => _DissolvingRowState();
}

class _DissolvingRowState extends State<DissolvingRow>
    with SingleTickerProviderStateMixin {
  /// Made on the first deletion, never for a row that is only scrolled past.
  AnimationController? _collapseOrNull;
  Animation<double>? _heightOrNull;

  AnimationController get _collapse => _collapseOrNull ??= AnimationController(
        vsync: this,
        duration: DissolvingRow.collapseDuration,
        value: 1,
      );

  Animation<double> get _height => _heightOrNull ??= CurvedAnimation(
        parent: _collapse,
        curve: Curves.easeInOut,
      );

  Timer? _startTimer;
  Timer? _closeTimer;
  bool _burning = false;
  bool _dustDone = false;
  bool _closing = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) _schedule(widget.entry!);
  }

  @override
  void didUpdateWidget(covariant DissolvingRow old) {
    super.didUpdateWidget(old);
    if (old.entry == null && widget.entry != null) {
      _schedule(widget.entry!);
    } else if (old.entry != null && widget.entry == null) {
      _reset();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _closeTimer?.cancel();
    _collapseOrNull?.dispose();
    super.dispose();
  }

  void _schedule(DustEntry e) {
    _startTimer?.cancel();
    void go() {
      if (!mounted || widget.entry == null) return;
      setState(() => _burning = true);
      // Close once the wave has crossed the row: everything left of it is in
      // the air, not in the box.
      const wave = DustDissolve.waveDuration;
      _closeTimer = Timer(wave, _close);
    }

    if (e.delay <= Duration.zero) {
      go();
    } else {
      _startTimer = Timer(e.delay, go);
    }
  }

  void _reset() {
    _startTimer?.cancel();
    _closeTimer?.cancel();
    _collapseOrNull?.stop();
    _collapseOrNull?.value = 1;
    _burning = false;
    _dustDone = false;
    _closing = false;
    _gone = false;
  }

  void _close() {
    if (!mounted || _closing || widget.entry == null) return;
    _closing = true;
    _collapse.reverse().whenCompleteOrCancel(_maybeGone);
  }

  void _onDust() {
    _dustDone = true;
    // Reduced motion finishes its fade before the wave timer would fire.
    if (!_closing) {
      _closeTimer?.cancel();
      _close();
    }
    _maybeGone();
  }

  void _maybeGone() {
    if (_gone || !mounted || widget.entry == null) return;
    if (!_dustDone || _collapse.value > 0) return;
    _gone = true;
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    // Idle: the row and nothing else.
    if (entry == null && !_burning && _collapseOrNull == null) return widget.child;
    return IgnorePointer(
      ignoring: entry != null,
      child: AnimatedBuilder(
        animation: _height,
        // Align loosens, so the row is given its full width back: a row
        // laid out narrower than the list would lose its alignment.
        builder: (context, child) => Align(
          alignment: Alignment.topCenter,
          heightFactor: _collapse.value >= 1 ? 1 : _height.value,
          child: SizedBox(width: double.infinity, child: child),
        ),
        child: DustDissolve(
          active: _burning,
          particles: entry?.particles ?? DustDissolve.maxParticles,
          seed: entry?.seed ?? 0,
          onDone: _onDust,
          child: widget.child,
        ),
      ),
    );
  }
}

extension<T extends Object> on T? {
  R? let<R>(R? Function(T) f) {
    final v = this;
    return v == null ? null : f(v);
  }
}
