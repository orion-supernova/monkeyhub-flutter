import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../models/chat_message.dart';
import '../theme/perf_tier.dart';

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
    this.tiles = MessageDepartures.maxTiles,
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
  /// [MessageDepartures.budget] with whatever else is leaving right now.
  final int tiles;
}

/// Which transcript rows are *leaving* — and are therefore worth animating
/// out. The departing twin of [MessageArrivals].
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
///    5Hz tick and asks for a departure; the raster is taken after that
///    frame, when the bubble has painted one last time at full strength.
///  * **The delivery.** [observeRemoval] runs synchronously inside the
///    repository callback, BEFORE the screen rebuilds without the row — the
///    one moment the vanished row's render tree is still the last painted
///    frame and can still be read.
///
/// The ghost is a real row: [withGhosts] splices the departed message back
/// into the timeline at its chronological place so the list keeps it in
/// `itemCount` while the exit runs, and [end] drops it again. Identity is the
/// arrivals ledger's `rowKey`, so a send that the server confirmed mid-exit is
/// one row, not two.
class MessageDepartures {
  MessageDepartures({required this.onChanged});

  /// Grains per bubble, at most (see `DepartingRow`).
  static const int maxTiles = 5000;

  /// Grains shared by every bubble leaving at once. A burst of messages sent
  /// together expires together; each takes what is left, never under
  /// [_minTiles], so ten at once cost about what two do.
  static const int budget = 12000;
  static const int _minTiles = 900;

  int get _tilesInFlight {
    var n = 0;
    for (final d in _active.values) {
      n += d.tiles;
    }
    return n;
  }

  /// Called when a departure begins or ends, so the owner can rebuild with
  /// or without the ghost. Never called synchronously from a request.
  final VoidCallback onChanged;

  final Map<String, DepartureCapture> _active = {};
  final Map<String, GlobalKey> _anchors = {};
  final Map<String, GlobalKey> _rowBoxes = {};

  /// Rows that asked to leave on their clock and are waiting for the end of
  /// the frame to be rastered.
  final Set<String> _pending = {};

  /// Bumped when the ghost set changes; [withGhosts] memoises on it.
  int _version = 0;
  List<ChatMessage>? _mergedSource;
  int _mergedVersion = -1;
  List<ChatMessage> _merged = const [];

  bool _disposed = false;

  /// The key on the bubble's own repaint boundary — what gets rastered.
  GlobalKey anchorKeyFor(String rowKey) {
    if (_anchors.length > _pruneAt && !_pruneScheduled) {
      // A row that expired off screen never departs, so nothing ends it: its
      // keys would stay for the session. Swept after the frame, when every
      // row being built has mounted; an off-screen row gets fresh ones when
      // it is next built.
      _pruneScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prune());
    }
    return _anchors.putIfAbsent(rowKey, () => GlobalKey(debugLabel: 'depart:$rowKey'));
  }

  int _pruneAt = 256;
  bool _pruneScheduled = false;

  void _prune() {
    _pruneScheduled = false;
    if (_disposed) return;
    bool live(String k) => _active.containsKey(k) || _pending.contains(k);
    _anchors.removeWhere((k, key) => key.currentContext == null && !live(k));
    _rowBoxes.removeWhere((k, key) => key.currentContext == null && !live(k));
    _pruneAt = math.max(256, _anchors.length * 2);
  }

  /// The key on the row that draws [rowKey], so a capture can measure how
  /// tall the row was and where the bubble sat in it.
  void registerRowBox(String rowKey, GlobalKey rowBox) {
    _rowBoxes[rowKey] = rowBox;
  }

  bool isDeparting(String rowKey) => _active.containsKey(rowKey);

  /// Ids whose exit has finished but which the server still lists — hidden
  /// until it stops. See [withGhosts].
  final Set<String> _gone = {};

  /// Whether [messageId] has already left the screen for good.
  bool hasDeparted(String messageId) => _gone.contains(messageId);

  DepartureCapture? captureFor(String rowKey) => _active[rowKey];

  /// The row keyed [rowKey] has reached its expiry on this device's clock.
  ///
  /// Safe to call from build, and on every tick after expiry: the first call
  /// schedules one capture for the end of the frame and the rest are no-ops.
  /// A row still on its optimistic `tmp_` id never departs — it has not been
  /// confirmed, so it cannot have expired.
  void requestLocalDeparture(
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
      _begin(rowKey, message, isMine: isMine, outline: outline);
      onChanged();
    });
  }

  /// Take a delivery: every ephemeral message in [previous] that is missing
  /// from [current] and not yet departing is captured NOW, while its row is
  /// still the last painted frame, and begins its exit.
  ///
  /// Synchronous on purpose; call it before the rebuild that drops the row.
  void observeRemoval(
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
      // A departure the clock already asked for but has not rastered yet is
      // taken over here: the row is about to leave the tree, and the end of
      // the frame would be too late.
      _pending.remove(rowKey);
      if (_begin(rowKey, m, isMine: isMine(m), outline: outlineFor(m))) {
        began = true;
      }
    }
    if (began) onChanged();
  }

  /// The timeline with every departed message spliced back in at its
  /// chronological place. Returns [timeline] itself — the same instance —
  /// while nothing is departing, and memoises the merge otherwise, so the
  /// screen's item cache keyed on list identity keeps working.
  List<ChatMessage> withGhosts(List<ChatMessage> timeline) {
    if (_active.isEmpty && _gone.isEmpty) return timeline;
    if (identical(timeline, _mergedSource) && _version == _mergedVersion) {
      return _merged;
    }
    final present = {for (final m in timeline) m.id};
    // A message that has blown away stays away. The server's delete can
    // land a beat after the exit has finished — the delivery round trip is
    // not the local clock — and until it does the row would otherwise come
    // back as a live bubble, expired, and blow up a second time. Forgotten
    // the moment the server no longer lists it.
    _gone.removeWhere((id) => !present.contains(id));
    final base = _gone.isEmpty
        ? timeline
        : [for (final m in timeline) if (!_gone.contains(m.id)) m];
    // Matched on every id the message has: a send confirmed mid-exit is in
    // the list under its server id, and splicing the ghost back as well would
    // put two rows on one key.
    final known = {for (final m in timeline) ...m.identities};
    final ghosts = [
      for (final d in _active.values)
        if (!d.message.identities.any(known.contains)) d.message,
    ];
    List<ChatMessage> merged;
    if (ghosts.isEmpty) {
      merged = base;
    } else {
      ghosts.sort(_byTime);
      merged = <ChatMessage>[];
      var g = 0;
      for (final m in base) {
        while (g < ghosts.length && _byTime(ghosts[g], m) < 0) {
          merged.add(ghosts[g++]);
        }
        merged.add(m);
      }
      while (g < ghosts.length) {
        merged.add(ghosts[g++]);
      }
    }
    _mergedSource = timeline;
    _mergedVersion = _version;
    return _merged = merged;
  }

  static int _byTime(ChatMessage a, ChatMessage b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  /// The exit has finished. Drops the ghost and frees its raster.
  void end(String rowKey) {
    final gone = _active.remove(rowKey);
    _anchors.remove(rowKey);
    _rowBoxes.remove(rowKey);
    if (gone == null) return;
    _gone.add(gone.message.id);
    _version++;
    gone.image?.dispose();
    if (!_disposed) onChanged();
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    for (final d in _active.values) {
      d.image?.dispose();
    }
    _active.clear();
    _anchors.clear();
    _rowBoxes.clear();
  }

  /// Rasters the bubble under [rowKey] and records the departure. Returns
  /// false when there was nothing on screen to take — the row was never
  /// built, or is already gone — in which case there is nothing to animate
  /// and the row leaves the list the ordinary way.
  bool _begin(
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

    final row = _rowBoxes[rowKey]?.currentContext?.findRenderObject();
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

    _active[rowKey] = DepartureCapture(
      message: message,
      rowKey: rowKey,
      isMine: isMine,
      image: image,
      pixelRatio: pixelRatio,
      bubbleSize: bubbleSize,
      bubbleInRow: bubbleInRow,
      rowSize: rowSize,
      outline: outline.getOuterPath(Offset.zero & bubbleSize),
      tiles: (Perf.particles(budget) - _tilesInFlight).clamp(
        Perf.particles(_minTiles),
        Perf.particles(maxTiles),
      ),
    );
    _version++;
    return true;
  }
}

extension<T extends Object> on T? {
  R? let<R>(R? Function(T) f) {
    final v = this;
    return v == null ? null : f(v);
  }
}
