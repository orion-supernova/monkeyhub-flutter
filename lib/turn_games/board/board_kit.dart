/// What every turn-game board view shares: the props [TurnBoard] hands down,
/// the one animation clock a view may own, the semantics layer and a few
/// painting helpers.
///
/// Internal to `lib/turn_games/board/`. The public surface is `TurnBoard` and
/// `SeatPalette`; everything here exists so the five views do not each grow
/// their own copy of the same plumbing.
library;

import '../../l10n/generated/app_localizations.dart';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import 'seat_palette.dart';

/// Everything a board view needs from [TurnBoard] and its context, resolved
/// once per build so no view looks the theme or the motion budget up itself.
@immutable
class BoardProps {
  const BoardProps({
    required this.state,
    required this.mySeat,
    required this.enabled,
    required this.onMove,
    required this.lastMove,
    required this.thumbnail,
    required this.winLine,
    required this.seatLabels,
    required this.theme,
    required this.seats,
    required this.calm,
    required this.highContrast,
  });

  final String state;
  final int? mySeat;
  final bool enabled;
  final ValueChanged<String>? onMove;
  final String? lastMove;
  final bool thumbnail;
  final bool winLine;
  final List<String> seatLabels;
  final AppTheme theme;
  final SeatPalette seats;

  /// Snap instead of animate. Always true for a thumbnail.
  final bool calm;
  final bool highContrast;

  /// Whether this board may emit a move for a position where [toMove] is to
  /// play. [enabled] is the caller's word that it is the viewer's turn; the
  /// seat check is a second lock, because an optimistic state that has
  /// already moved on must never let a second tap through as the wrong side.
  bool canMoveFor(int toMove) =>
      enabled &&
      onMove != null &&
      !thumbnail &&
      (mySeat == null || mySeat == toMove);

  String seatLabel(int seat) => seat < seatLabels.length
      ? seatLabels[seat]
      : String.fromCharCode(0x41 + seat);
}

/// A board view: one per game, built by [TurnBoard].
abstract class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.props});

  final BoardProps props;
}

/// The one clock a board view owns.
///
/// A single controller per board rather than one per piece: every animation
/// here is one event (a mark drawing on, a disc dropping, a cascade of flips)
/// and the painter works out each piece's own progress from the shared
/// elapsed time. The controller is created lazily on the first animated
/// change, so a thumbnail, or a board under calm motion, never creates a
/// ticker at all.
abstract class BoardViewState<W extends BoardView> extends State<W>
    with SingleTickerProviderStateMixin {
  AnimationController? _anim;
  double _totalMs = 0;

  /// What the painter reads: elapsed milliseconds into the current run, or
  /// infinity when nothing is running (every phase finished).
  BoardClock get clock => BoardClock(_anim, _totalMs);

  bool get animating => _anim?.isAnimating ?? false;

  /// Starts a run of [totalMs]. Under calm motion (and on a thumbnail) the
  /// run is skipped and the board snaps to its end state.
  void play(double totalMs) {
    final p = widget.props;
    if (p.thumbnail || p.calm || totalMs <= 0) {
      _totalMs = 0;
      _anim?.value = 1;
      return;
    }
    final a = _anim ??= AnimationController(vsync: this);
    _totalMs = totalMs;
    a.duration = Duration(milliseconds: totalMs.ceil());
    a.forward(from: 0);
  }

  /// Fires [onDone] once, when the current run's elapsed time passes [atMs].
  /// For the haptic a dropped disc gives as it lands.
  void at(double atMs, VoidCallback onDone) {
    final a = _anim;
    if (a == null || !a.isAnimating) return;
    final run = a.duration;
    void listener() {
      if (a.duration != run) {
        a.removeListener(listener);
        return;
      }
      if (a.value * _totalMs >= atMs || a.isCompleted) {
        a.removeListener(listener);
        onDone();
      }
    }

    a.addListener(listener);
  }

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }
}

/// A snapshot of a view's clock for one painter: the animation to listen to
/// and the run length to scale it by. Cheap to build, built once per widget
/// build, never per frame.
@immutable
class BoardClock {
  const BoardClock(this.animation, this.totalMs);

  final Animation<double>? animation;
  final double totalMs;

  /// Elapsed milliseconds, or infinity once the run is over.
  double get ms {
    final a = animation;
    if (a == null || totalMs <= 0 || a.isCompleted) return double.infinity;
    return a.value * totalMs;
  }

  /// Progress of a phase that starts at [startMs] and lasts [lengthMs].
  double phase(double startMs, double lengthMs) {
    final t = ms;
    if (t == double.infinity) return 1;
    if (lengthMs <= 0) return t >= startMs ? 1 : 0;
    return ((t - startMs) / lengthMs).clamp(0.0, 1.0);
  }
}

/// A painter that paints nothing and supplies the board's semantics: one node
/// per cell, column or edge, each with its own label and, for a legal move,
/// an activation.
///
/// Separate from the board painter on purpose. That one is rebuilt for every
/// hover and selection and repaints every animation frame; this one only
/// rebuilds its nodes when [version] changes, which is once per position.
class BoardSemanticsPainter extends CustomPainter {
  BoardSemanticsPainter({required this.version, required this.nodes});

  /// Anything that changes exactly when the labels or the actions do.
  final Object version;

  final List<CustomPainterSemantics> Function(Size size) nodes;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(BoardSemanticsPainter oldDelegate) => false;

  @override
  SemanticsBuilderCallback get semanticsBuilder => nodes;

  @override
  bool shouldRebuildSemantics(BoardSemanticsPainter oldDelegate) =>
      oldDelegate.version != version;
}

/// One semantics node over [rect].
CustomPainterSemantics boardNode(
  Rect rect,
  String label, {
  VoidCallback? onTap,
  bool selected = false,
}) => CustomPainterSemantics(
  rect: rect,
  properties: SemanticsProperties(
    label: label,
    button: onTap != null,
    selected: selected,
    onTap: onTap,
    textDirection: TextDirection.ltr,
  ),
);

/// The board's own gesture surface plus its semantics, or the bare painting
/// for a thumbnail.
///
/// A thumbnail gets no detector, no semantics painter and no repaint
/// boundary: a chat card shows several of these and each must cost one
/// picture, nothing more.
Widget boardSurface({
  required BoardProps props,
  required CustomPainter painter,
  BoardSemanticsPainter? semantics,
  Widget Function(Widget child)? gestures,
}) {
  final paint = CustomPaint(
    painter: painter,
    foregroundPainter: props.thumbnail ? null : semantics,
    size: Size.infinite,
  );
  if (props.thumbnail) return ExcludeSemantics(child: paint);
  return RepaintBoundary(child: gestures == null ? paint : gestures(paint));
}

/// The haptics boards use, in one place so they are easy to audit.
abstract final class BoardHaptics {
  static void tick() => HapticFeedback.selectionClick();
  static void land() => HapticFeedback.lightImpact();
}

/// Ease curves as plain functions, so a painter can shape a phase without
/// holding a [Curve] object per piece.
double easeOutCubic(double t) {
  final u = 1 - t;
  return 1 - u * u * u;
}

double easeInQuad(double t) => t * t;

double easeInOutCubic(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2;

/// Size-keyed cache for the static geometry a painter would otherwise rebuild
/// every frame: a slab with 42 holes, a grid of lines, a radial shader.
///
/// Small and shared across instances, because a transcript draws the same
/// board at the same size many times over; eight entries covers a full-size
/// board, a thumbnail and a few layouts in between.
class SizeCache<T> {
  SizeCache(this._build, {this.capacity = 8});

  final T Function(Size size) _build;
  final int capacity;
  final _entries = <Size, T>{};

  T of(Size size) {
    final hit = _entries.remove(size);
    if (hit != null) {
      _entries[size] = hit;
      return hit;
    }
    final made = _build(size);
    _entries[size] = made;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
    return made;
  }
}

/// A dome of light over a disc of [radius] centred on the origin: bright at
/// the upper left, clear in the middle, a touch of shade at the lower edge.
/// Drawn with the canvas translated to each disc, so one shader serves every
/// disc of that size.
ui.Shader discLight(double radius, {double highlight = 0.30, double shade = 0.12}) =>
    ui.Gradient.radial(
      Offset(-radius * 0.34, -radius * 0.42),
      radius * 1.45,
      [
        const Color(0xFFFFFFFF).withValues(alpha: highlight),
        const Color(0x00FFFFFF),
        const Color(0xFF000000).withValues(alpha: shade),
      ],
      const [0.0, 0.55, 1.0],
    );

/// A soft contact shadow for a disc of [radius] centred on the origin, as a
/// radial gradient: the falloff a blurred circle gives, without a blur.
ui.Shader discShadow(double radius, {double alpha = 0.30}) => ui.Gradient.radial(
  Offset(0, radius * 0.14),
  radius * 1.22,
  [
    const Color(0xFF000000).withValues(alpha: alpha),
    const Color(0xFF000000).withValues(alpha: alpha * 0.6),
    const Color(0x00000000),
  ],
  const [0.0, 0.74, 1.0],
);

/// "Row 2, column 3", 1-based, for semantics labels.
/// The board's words in the reader's language, resolved once per build so the
/// semantics callback (which runs during painting, outside build) never looks
/// anything up. English when there are no localizations in scope — a board
/// mounted bare in a test or a preview still has labels.
AppLocalizations boardL10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

String cellName(AppLocalizations l10n, int row, int col) =>
    l10n.boardCellName(row + 1, col + 1);
