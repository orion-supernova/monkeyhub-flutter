import 'dart:async';
import 'dart:ui' show Color, Offset, Path;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSLColor;

import '../../theme/app_theme.dart';
import 'draw_wire.dart';

/// One stroke on the shared screen, from whoever drew it.
///
/// Points are kept in a buffer that doubles as it grows, so a long stroke
/// appended to sixty times a second never copies more than it must. The
/// [path] fields are a render cache the canvas owns; they live here because
/// the stroke is the natural key and a map from strokes to paths would have
/// to be pruned by hand.
class DrawStroke {
  DrawStroke({
    required this.author,
    required this.id,
    required this.color,
    required this.width,
    required this.startedAt,
  });

  final String author;
  final int id;
  final Color color;

  /// Width as a fraction of the frame width.
  final double width;
  final DateTime startedAt;

  /// Null while the finger is still down.
  DateTime? endedAt;

  Float32List _buf = Float32List(64);

  /// Number of points.
  int length = 0;

  /// The x/y pairs so far — a view over the buffer, not a copy.
  Float32List get points => Float32List.view(_buf.buffer, 0, length * 2);

  double x(int i) => _buf[2 * i];
  double y(int i) => _buf[2 * i + 1];

  void addAll(Float32List xy) {
    final n = xy.length ~/ 2;
    if (n == 0) return;
    final need = (length + n) * 2;
    if (need > _buf.length) {
      var cap = _buf.length;
      while (cap < need) {
        cap *= 2;
      }
      final grown = Float32List(cap);
      grown.setRange(0, length * 2, _buf);
      _buf = grown;
    }
    _buf.setRange(length * 2, need, xy);
    length += n;
  }

  /// The render cache: the path last built, the point count and the frame
  /// size it was built for. See `DrawCanvas`.
  Path? path;
  int pathLength = -1;
  double pathWidth = 0;
  double pathHeight = 0;

  String get key => keyFor(author, id);
  static String keyFor(String author, int id) => '$author/$id';
}

/// Every live stroke on the shared screen, from everyone, and where each is
/// in its short life.
///
/// A stroke lives [lifetime] after the finger lifts, then takes [dissolve]
/// to blow away. Both ends of that are moments the canvas must repaint at —
/// and nothing else is happening at either, so the model keeps ONE timer
/// aimed at the earliest of them rather than asking the canvas to poll.
///
/// Local drawing goes through [beginLocal]/[appendLocal]/[endLocal], which
/// apply immediately (the drawer's own line must not lag the finger) and
/// queue the same ops for the channel. The queue is flushed at most once
/// per [flushInterval], with consecutive appends to one stroke folded into
/// one op, so a 120 Hz stylus does not become 120 packets a second.
class DrawModel extends ChangeNotifier {
  DrawModel({this.onOutbound});

  /// How long a finished stroke stays sharp.
  static const Duration lifetime = Duration(milliseconds: 2500);

  /// How long it takes to go once its time is up.
  static const Duration dissolve = Duration(milliseconds: 650);

  /// Where the drawer's own ops go — the channel fan-out. Null when there is
  /// nobody to send to (a preview, a test).
  void Function(List<DrawOp> ops)? onOutbound;

  /// The clock every lifetime is measured on. Injectable, so a test can
  /// walk a stroke through its life without waiting three seconds for it.
  DateTime Function() clock = DateTime.now;

  /// Floor between two outbound flushes. Pointer events already arrive one
  /// batch per frame; this keeps a 120 Hz display from doubling the rate.
  @visibleForTesting
  Duration flushInterval = const Duration(milliseconds: 33);

  final Map<String, DrawStroke> _strokes = {};
  List<DrawStroke>? _live;
  Timer? _deadline;
  bool _disposed = false;

  int _nextLocalId = 1;

  /// The drawer's own author key — only used to route local ops through
  /// [apply], where remote ops go too, so both paths are one path.
  static const String localAuthor = '';

  /// Strokes not yet gone, oldest first.
  List<DrawStroke> get strokes =>
      _live ??= List.unmodifiable(_strokes.values);

  bool get isEmpty => _strokes.isEmpty;

  /// 0 while the stroke is sharp, 1 once it has fully blown away.
  double dissolveT(DrawStroke s, DateTime now) {
    final ended = s.endedAt;
    if (ended == null) return 0;
    final start = ended.add(lifetime);
    if (!now.isAfter(start)) return 0;
    final t = now.difference(start).inMicroseconds / dissolve.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }

  /// Whether any stroke is mid-dissolve right now.
  bool get anyDissolving {
    final now = clock();
    for (final s in _strokes.values) {
      final t = dissolveT(s, now);
      if (t > 0 && t < 1) return true;
    }
    return false;
  }

  /// The next instant something visibly changes: a stroke starting to
  /// dissolve, or finishing. Null when nothing is on a clock.
  DateTime? get nextDeadline {
    DateTime? best;
    for (final s in _strokes.values) {
      final ended = s.endedAt;
      if (ended == null) continue;
      final start = ended.add(lifetime);
      final gone = start.add(dissolve);
      final now = clock();
      final next = now.isBefore(start) ? start : gone;
      if (best == null || next.isBefore(best)) best = next;
    }
    return best;
  }

  /// Applies ops from [author] — a peer's id, or [localAuthor] for our own.
  void apply(String author, List<DrawOp> ops) {
    if (_disposed || ops.isEmpty) return;
    final now = clock();
    for (final op in ops) {
      switch (op) {
        case StrokeBegin(:final strokeId, :final argb, :final width, :final points):
          final s = DrawStroke(
            author: author,
            id: strokeId,
            color: Color(argb),
            width: width,
            startedAt: now,
          )..addAll(points);
          _strokes[s.key] = s;
        case StrokeAppend(:final strokeId, :final points):
          _strokes[DrawStroke.keyFor(author, strokeId)]?.addAll(points);
        case StrokeEnd(:final strokeId):
          final s = _strokes[DrawStroke.keyFor(author, strokeId)];
          if (s != null && s.endedAt == null) s.endedAt = now;
        case DrawClear():
          _strokes.clear();
      }
    }
    _changed();
  }

  // ------------------------------------------------------------ local input

  final List<DrawOp> _pending = [];
  int _pendingAppendId = -1;
  final List<double> _pendingAppend = [];
  Timer? _flush;
  DateTime? _lastFlush;

  /// Starts a stroke at [norm] (0..1 frame fractions). Returns its id.
  int beginLocal(Offset norm, {required Color color, required double width}) {
    final id = _nextLocalId++;
    final pts = Float32List(2)
      ..[0] = norm.dx
      ..[1] = norm.dy;
    final op = StrokeBegin(
        strokeId: id, argb: color.toARGB32(), width: width, points: pts);
    apply(localAuthor, [op]);
    _closePendingAppend();
    _pending.add(op);
    _scheduleFlush();
    return id;
  }

  void appendLocal(int strokeId, Offset norm) {
    final pts = Float32List(2)
      ..[0] = norm.dx
      ..[1] = norm.dy;
    apply(localAuthor, [StrokeAppend(strokeId: strokeId, points: pts)]);
    if (_pendingAppendId != strokeId) {
      _closePendingAppend();
      _pendingAppendId = strokeId;
    }
    _pendingAppend
      ..add(norm.dx)
      ..add(norm.dy);
    _scheduleFlush();
  }

  void endLocal(int strokeId) {
    apply(localAuthor, [StrokeEnd(strokeId: strokeId)]);
    _closePendingAppend();
    _pending.add(StrokeEnd(strokeId: strokeId));
    _scheduleFlush();
  }

  /// Drops every stroke, ours and theirs, and tells the peers to do the
  /// same. The presenter calls this when the share ends.
  void clearAll() {
    apply(localAuthor, const [DrawClear()]);
    _closePendingAppend();
    _pending.add(const DrawClear());
    _scheduleFlush();
  }

  void _closePendingAppend() {
    if (_pendingAppendId < 0) return;
    _pending.add(StrokeAppend(
      strokeId: _pendingAppendId,
      points: Float32List.fromList(_pendingAppend),
    ));
    _pendingAppendId = -1;
    _pendingAppend.clear();
  }

  void _scheduleFlush() {
    if (_flush != null) return;
    final last = _lastFlush;
    var wait = Duration.zero;
    if (last != null) {
      final since = clock().difference(last);
      if (since < flushInterval) wait = flushInterval - since;
    }
    _flush = Timer(wait, _flushNow);
  }

  void _flushNow() {
    _flush = null;
    if (_disposed) return;
    _closePendingAppend();
    if (_pending.isEmpty) return;
    final batch = List<DrawOp>.of(_pending);
    _pending.clear();
    _lastFlush = clock();
    onOutbound?.call(batch);
  }

  /// Sends whatever is queued right now. For a share ending, so the last
  /// ops are not left behind a timer that the dispose then cancels.
  void flush() {
    _flush?.cancel();
    _flushNow();
  }

  // ------------------------------------------------------------- lifetime

  /// Drops strokes that have fully dissolved as of [now].
  void prune(DateTime now) {
    var dropped = false;
    _strokes.removeWhere((_, s) {
      final gone = dissolveT(s, now) >= 1;
      dropped |= gone;
      return gone;
    });
    if (dropped) {
      _changed();
    } else {
      _arm();
    }
  }

  void _changed() {
    _live = null;
    _arm();
    notifyListeners();
  }

  void _arm() {
    _deadline?.cancel();
    _deadline = null;
    final next = nextDeadline;
    if (next == null) return;
    var wait = next.difference(clock());
    if (wait.isNegative) wait = Duration.zero;
    _deadline = Timer(wait, () {
      _deadline = null;
      if (_disposed) return;
      // Something crossed a threshold: either the first dust of a stroke
      // (a repaint) or the last of it (a prune). Prune re-arms either way.
      final now = clock();
      _live = null;
      prune(now);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _deadline?.cancel();
    _flush?.cancel();
    super.dispose();
  }
}

/// The colour a user draws in — their avatar's, so a stroke reads as theirs
/// without a legend. Pulled into a mid lightness so it holds up over a
/// bright document and a dark terminal alike.
Color drawColorFor(String userId, AppTheme theme) {
  // Same seed as `UserAvatar._seed`, so the stroke matches the face.
  var hash = 0;
  for (final c in userId.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  final gradient = theme.avatarGradient(hash);
  final base = gradient.isEmpty ? theme.accent : gradient.first;
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withLightness(hsl.lightness.clamp(0.48, 0.62))
      .withSaturation(hsl.saturation < 0.55 ? 0.55 : hsl.saturation)
      .toColor();
}
