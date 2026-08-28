import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/chat_message.dart';

/// Which transcript rows are *news* — and are therefore worth animating in.
///
/// A chat list is rebuilt from scratch on every delivery: Convex re-sends the
/// whole live window on any change, a page of history is spliced in at the far
/// end, a jump into old history swaps the list wholesale, and `ListView.builder`
/// re-runs the builder for a row every time it scrolls back into view. None of
/// those are arrivals, and animating any of them makes the transcript shimmer.
///
/// The first attempt at telling them apart compared `createdAt` against the
/// newest row already drawn. That reads as obviously correct and is not: the
/// clock it compares is two clocks. An optimistic bubble is stamped from the
/// device, its echo from the server, and a device running a few seconds fast
/// silently suppressed the entrance of every message that arrived next. Worse,
/// the echo of your OWN send looks exactly like news under that rule — new id,
/// newer stamp — so a send played its entrance twice: once when the bubble
/// appeared and again, from zero height, when the server confirmed it.
///
/// So this ledger uses no clock at all. It asks two questions:
///
///  * **Is this row the same row?** A send is one row with two ids — the local
///    `tmp_…` and the server's — and the echo names the bubble it replaces in
///    its `clientId`. [keyFor] folds the pair onto one identity, so the swap is
///    a row being updated rather than one row leaving and another arriving.
///  * **Is this row at the tail?** Everything after the last row already drawn
///    is news; everything before it is backfilled history. That is true by
///    construction whatever the clocks say.
///
/// On top of that, three things deliberately do not animate:
///
///  * **Your own sends.** Tapping send is direct manipulation, and the reply to
///    direct manipulation is *now* — the bubble belongs under the composer the
///    instant the composer clears. It is also the one case where the transcript
///    is already moving, because a send scrolls to the bottom.
///  * **A burst bigger than [maxBurst].** Opening a room, widening the window,
///    replaying the query set after a reconnect: these arrive as news at the
///    tail and are not news at all. One or two bubbles land; twelve is a load.
///  * **Anything arriving while the reader is scrolled away.** They cannot see
///    it, and growing a row below them drags the paragraph they are reading.
///
/// The ledger holds ids and one timer. It draws nothing; [ArrivingRow] does.
class MessageArrivals {
  MessageArrivals({required this.onSettled});

  /// Called when the entrance window closes, so the owner can rebuild without
  /// the arrival wrappers. Never called synchronously from [observe].
  final VoidCallback onSettled;

  /// More rows than this landing at once is a load, not news. Two people
  /// answering at the same moment is the honest ceiling for "arrived while I
  /// was looking".
  static const int maxBurst = 3;

  /// How long an id stays eligible to play its entrance.
  ///
  /// Bounds the case the ledger cannot otherwise see: a row that arrives below
  /// the fold and is only built minutes later, when the reader scrolls down to
  /// it — by then it is not an arrival, it is history. Comfortably longer than
  /// the slowest theme's entrance (bio-organic's `motionMed`, 600ms) so a row
  /// built a frame or two late still plays; being a little too generous costs
  /// nothing, since the set is only ever a hint to the builder.
  static const Duration hold = Duration(milliseconds: 700);

  /// Ids drawn at least once, in canonical form. The answer to "is this an
  /// arrival or is it just scrolling into view?".
  final Set<String> _drawn = {};

  /// Server id → the local `tmp_…` id it replaced, for rows this ledger watched
  /// land. Keeps a confirmed send on the identity its bubble was born with, so
  /// the row is never rebuilt from scratch under a new key.
  final Map<String, String> _folded = {};

  /// Ids currently playing their entrance. Small and short-lived: an id enters
  /// on the delivery that carried it and leaves one [hold] later.
  final Set<String> _arriving = {};

  Timer? _timer;

  /// Above this the ledger is remembering rows the transcript can no longer
  /// reach. Pruned to whatever is still in the list; anything dropped can only
  /// come back as backfill, which never animates.
  static const int _maxRemembered = 4000;

  /// The identity of the row that draws [m], stable across the moment the
  /// server's copy replaces the optimistic one.
  ///
  /// `clientId` is only trusted on our own rows. On someone else's it is *their*
  /// device's key — a string this transcript has no claim on, and one two
  /// devices could in principle mint in the same microsecond.
  String keyFor(ChatMessage m) => _folded[m.id] ?? m.id;

  /// Whether the row keyed [rowKey] should play an entrance.
  bool isArriving(String rowKey) => _arriving.contains(rowKey);

  /// Take a delivery. [myUserId] is the signed-in user, [nearBottom] whether the
  /// transcript is parked at the newest message.
  void observe(
    List<ChatMessage> timeline, {
    required String? myUserId,
    required bool nearBottom,
  }) {
    if (timeline.isEmpty) return;

    final keys = <String>[];
    final taken = <String>{};
    for (final m in timeline) {
      var key = _fold(m, myUserId);
      if (!taken.add(key)) {
        // Both halves of one send in a single delivery — the echo arrived
        // before the optimistic bubble was reconciled away. Two rows cannot
        // share an identity, so the newcomer keeps its own and folds on the
        // next delivery, by which time the bubble is gone.
        _folded.remove(m.id);
        key = m.id;
        taken.add(key);
      }
      keys.add(key);
    }

    // First paint. Record the transcript; playing it in would be an entrance
    // per message for the whole screenful.
    if (_drawn.isEmpty) {
      _remember(keys);
      return;
    }

    // The last row we have already drawn. Everything past it is at the tail;
    // everything before it is history being spliced in behind the reader.
    var lastKnown = -1;
    var overlap = 0;
    for (var i = 0; i < keys.length; i++) {
      if (_drawn.contains(keys[i])) {
        lastKnown = i;
        overlap++;
      }
    }

    // Not one row in common: this is a different transcript, not a longer one —
    // a jump into old history, or the window collapsing back to the live tail.
    // There is no continuous motion between two disjoint lists to animate.
    if (overlap == 0) {
      _drawn.clear();
      _folded.clear();
      _remember(keys);
      return;
    }

    var tailNew = 0;
    final fresh = <String>[];
    for (var i = lastKnown + 1; i < keys.length; i++) {
      if (_drawn.contains(keys[i])) continue;
      tailNew++;
      // Ours already appeared the moment it was tapped.
      if (timeline[i].senderId == myUserId) continue;
      fresh.add(keys[i]);
    }
    _remember(keys);

    if (fresh.isEmpty) return;
    if (tailNew > maxBurst) return;
    if (!nearBottom) return;

    _arriving.addAll(fresh);
    // One timer for the whole burst rather than one per id: rows that land
    // together should finish together, and the caller is about to rebuild for
    // its own reasons anyway.
    _timer?.cancel();
    _timer = Timer(hold, () {
      if (_arriving.isEmpty) return;
      _arriving.clear();
      onSettled();
    });
  }

  /// Forget everything. For an owner that swaps to an unrelated transcript and
  /// knows it — [observe] detects the same thing on its own, one delivery later.
  void reset() {
    _drawn.clear();
    _folded.clear();
    _arriving.clear();
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// [keyFor], plus the one-time learning step: the first time the server's copy
  /// of one of our sends is seen, tie it to the bubble it replaced.
  String _fold(ChatMessage m, String? myUserId) {
    final known = _folded[m.id];
    if (known != null) return known;
    final client = m.clientId;
    if (client != null &&
        client != m.id &&
        m.senderId == myUserId &&
        _drawn.contains(client)) {
      _folded[m.id] = client;
      return client;
    }
    return m.id;
  }

  void _remember(List<String> keys) {
    _drawn.addAll(keys);
    if (_drawn.length <= _maxRemembered) return;
    _drawn
      ..clear()
      ..addAll(keys);
    _folded.removeWhere((_, folded) => !_drawn.contains(folded));
  }
}

/// Grows a newly-arrived transcript row into place instead of snapping it in.
///
/// Under the list's `reverse: true` an arrival is index 0 — the bottom — so
/// growing its height from zero reads as the bubble rising into place, and the
/// rows above it are pushed by exactly the amount they were going to move
/// anyway, over the entrance instead of over one frame.
///
/// [animate] is false for every row that is merely being built — scrolled back
/// into view, rebuilt after a reaction, part of a page of older history, or one
/// the reader sent themselves — and those return the child untouched,
/// allocating nothing. See [MessageArrivals] for which is which.
class ArrivingRow extends StatefulWidget {
  const ArrivingRow({
    super.key,
    required this.animate,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final bool animate;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  State<ArrivingRow> createState() => _ArrivingRowState();
}

class _ArrivingRowState extends State<ArrivingRow>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ctrl = AnimationController(vsync: this, duration: widget.duration)
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    // Nothing to play, or it has finished: hand back the child itself so a
    // settled transcript carries no extra layout or opacity layer per row.
    if (ctrl == null || ctrl.isCompleted) return widget.child;
    final t = CurvedAnimation(parent: ctrl, curve: widget.curve);
    return AnimatedBuilder(
      animation: t,
      // Built once and reused across every frame of the animation — the row
      // beneath is the expensive part and none of it depends on `t`.
      child: widget.child,
      builder: (context, child) => Align(
        alignment: Alignment.topCenter,
        heightFactor: t.value,
        child: Opacity(opacity: t.value, child: child),
      ),
    );
  }
}
