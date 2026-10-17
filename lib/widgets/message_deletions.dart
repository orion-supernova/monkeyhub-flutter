import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/chat_message.dart';
import 'dust_dissolve.dart';

/// One row's part in a deletion: when its dust starts and how much of the
/// shared particle budget it may spend.
@immutable
class DeletionEntry {
  const DeletionEntry({
    required this.delay,
    required this.particles,
    required this.seed,
  });

  /// After the batch starts. Rows go top to bottom a beat apart, so several
  /// deleted together read as one wave rather than a flash.
  final Duration delay;
  final int particles;
  final int seed;
}

/// Which transcript rows are being DELETED, and are therefore turning to
/// dust before they leave.
///
/// The sibling of `MessageDepartures`, and deliberately separate from it: a
/// departure is a Chamber of Secrets message running out of time, which has
/// its own capture and its own exit, and nothing here touches an ephemeral
/// row. This ledger only ever acts on an explicit deletion:
///
///  * **Local** — the reader's own DELETE (one message, an album, or a
///    selection). The screen calls [begin] with the messages BEFORE it asks
///    the repository, so the rows are held from the first frame and the
///    optimistic local removal that follows cannot drop them.
///  * **Remote** — `ChatRepository.serverRemovals`: rows the server stopped
///    sending from the INSIDE of its live window. That window is the newest
///    rows of a contiguous range, so a row can only fall off its oldest edge;
///    one missing from between rows that are still there was removed, not
///    paged out. See there.
///
/// Only rows that are on screen dissolve. One that is scrolled away just goes,
/// as before. A held row stays in the list (spliced back by [withHeld]) until
/// its dust has left and its height has closed; [end] then drops it, and keeps
/// it hidden for as long as the server is still listing it.
///
/// Rows are registered by the builder ([registerRow]) under the id of the
/// message that heads them, with every message the row draws — an album is
/// one row of several. A row is only taken when ALL of its messages are being
/// deleted: deleting one photograph out of an album leaves the album standing
/// and that photograph simply goes.
class MessageDeletions {
  MessageDeletions({required this.onChanged, this.budget = defaultBudget});

  /// Called when rows start or finish, so the owner can rebuild.
  final VoidCallback onChanged;

  /// Particles shared by every row dissolving at once.
  final int budget;

  static const int defaultBudget = 12000;

  /// Between one row's dust and the next one down.
  static const Duration stagger = Duration(milliseconds: 40);

  final Map<String, GlobalKey> _rowBoxes = {};
  final Map<String, List<String>> _members = {};
  final Map<String, String> _headOf = {};

  final Map<String, DeletionEntry> _active = {};
  final Map<String, List<ChatMessage>> _held = {};
  final Set<String> _heldIds = {};

  /// Ids whose rows have finished but which the server may still list (a
  /// selection delete is not removed locally first) — hidden until it stops.
  final Set<String> _gone = {};

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
    if (_rowBoxes.length > _pruneAt && !_pruneScheduled) {
      // A long session scrolls past thousands of rows, and each one left an
      // entry here. Swept after the frame, when every row being built has
      // mounted: a box with no element by then is off screen, and is put
      // back by its own build the next time it is.
      _pruneScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prune());
    }
  }

  int _pruneAt = 512;
  bool _pruneScheduled = false;

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
  }

  /// The row headed by [head] is dissolving: when, and with how much.
  DeletionEntry? entryFor(String head) => _active[head];

  bool get isEmpty => _active.isEmpty && _gone.isEmpty;

  /// Whether [messageId] is held on screen by a deletion in progress.
  bool isHeld(String messageId) => _heldIds.contains(messageId);

  /// [messages] are being deleted. Every on-screen row they make up whole
  /// starts to dissolve; returns how many did. Ephemeral messages are never
  /// taken: their exit is `MessageDepartures`'.
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
      _active[r.head] = DeletionEntry(
        delay: stagger * i,
        particles: share,
        seed: r.head.hashCode,
      );
      _held[r.head] = r.members;
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

  /// The delete failed: whatever rows hold any of [ids] come back.
  void cancel(Iterable<String> ids) {
    if (_disposed) return;
    var changed = false;
    for (final id in ids) {
      changed = _gone.remove(id) || changed;
      final head = _headOf[id];
      if (head == null || _active.remove(head) == null) continue;
      for (final m in _held.remove(head) ?? const <ChatMessage>[]) {
        _heldIds.remove(m.id);
      }
      changed = true;
    }
    if (!changed) return;
    _version++;
    onChanged();
  }

  /// The row headed by [head] has dissolved and closed.
  void end(String head) {
    if (_active.remove(head) == null) return;
    for (final m in _held.remove(head) ?? const <ChatMessage>[]) {
      _heldIds.remove(m.id);
      _gone.add(m.id);
    }
    _version++;
    if (!_disposed) onChanged();
  }

  /// [timeline] with every held message spliced back at its chronological
  /// place and every finished one left out. The same instance while nothing
  /// is in progress, and memoised otherwise.
  List<ChatMessage> withHeld(List<ChatMessage> timeline) {
    if (_active.isEmpty && _gone.isEmpty) return timeline;
    if (identical(timeline, _mergedSource) && _version == _mergedVersion) {
      return _merged;
    }
    final present = {for (final m in timeline) m.id};
    _gone.removeWhere((id) => !present.contains(id));
    final base = _gone.isEmpty
        ? timeline
        : [for (final m in timeline) if (!_gone.contains(m.id)) m];
    // A held row is only spliced back if the list has no copy of it under ANY
    // of its ids: mid-send the optimistic row and the server's echo are one
    // message with two ids, and both would claim the same row key.
    final known = {for (final m in timeline) ...m.identities};
    final missing = [
      for (final list in _held.values)
        for (final m in list)
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
    _active.clear();
    _held.clear();
    _heldIds.clear();
    _rowBoxes.clear();
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
}

/// A transcript row that can be deleted to dust.
///
/// Costs nothing while idle: with no [entry] it returns the row itself, no
/// wrapper, no controller, no repaint boundary. Every transcript row carries
/// one and rows mount and unmount all through a scroll, so anything more here
/// was paid on every frame of a fling (it cost 120 Hz scrolling its
/// smoothness). The wrapper and the controller appear only once a deletion
/// starts on this row; the row remounts inside it then, and the dust is taken
/// from the frame it paints there. Given one, it waits out [DeletionEntry.delay], burns the row
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

  final DeletionEntry? entry;
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

  void _schedule(DeletionEntry e) {
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
