import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_preference.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/medal_disc.dart';
import '../../widgets/score_row.dart' show PlayerFace;
import '../../widgets/streak_badge.dart';

/// One of the three on a [LeaderPodium].
class PodiumEntry {
  const PodiumEntry({
    required this.userId,
    required this.name,
    required this.isViewer,
    required this.metric,
    required this.semantics,
    this.streak = 0,
    this.onTap,
    this.place,
  });

  final String userId;

  /// Empty for the viewer, who is "You".
  final String name;
  final bool isViewer;

  /// What the board ranks by, drawn under the name: the solved dots on
  /// "Today", a time or "4/6" on one game's board.
  final Widget metric;

  /// The metric read aloud, after the place and the name.
  final String semantics;
  final int streak;

  /// The same as tapping the row would be: the whole result.
  final VoidCallback? onTap;

  /// The place this person holds, shared on a tie: two people tied for first
  /// both stand raised with gold, and the next one takes bronze. Null reads
  /// as their seat ("1, 2, 3" left to right of the order given).
  final int? place;
}

/// The top three PLACES, drawn as a podium: first in the middle and raised,
/// the next two either side, each a face with its medal set into the bottom
/// edge. On the page, not in a card: the winners are the one thing on this
/// screen that should not look like a settings row.
///
/// A seat is a place, not a person. People tied on a place share its seat
/// and are swiped through there, the face turning away a little in 3D as the
/// next turns in, A to Z, starting on you when you are among them. So two
/// tied for first are one gold seat holding two, the next place (third,
/// under "1, 1, 3") takes the side seat, and a third seat with no place left
/// to give is empty with a dash. No medal ever spills into the list.
///
/// No pedestal blocks. Steps under the faces read as clip art; the height
/// difference alone says who won.
///
/// The seats rise in once per change of WHO is on them (keyed on their ids),
/// so a refresh that changes nothing does not replay it, and Reduce Motion
/// skips it entirely.
class LeaderPodium extends StatelessWidget {
  const LeaderPodium({super.key, required this.entries});

  /// Best first: everyone holding a place of 1 to 3, ties together. A place
  /// nobody has taken is drawn as an empty seat, so the podium keeps its
  /// shape whether three have played or none.
  final List<PodiumEntry> entries;

  /// [entries] as seats: runs of one shared place, best first, three at most.
  List<List<PodiumEntry>> get _seats {
    final seats = <List<PodiumEntry>>[];
    for (var i = 0; i < entries.length; i++) {
      final place = entries[i].place ?? i + 1;
      if (seats.isNotEmpty && (seats.last.first.place ?? -1) == place) {
        seats.last.add(entries[i]);
      } else if (seats.length < 3) {
        seats.add([entries[i]]);
      }
    }
    return seats;
  }

  @override
  Widget build(BuildContext context) {
    final seats = _seats;
    // The place an empty seat stands for: the one the next person would
    // take, while it is still a podium place; past third, a dash.
    final places = <int>[];
    var next = 1;
    for (var i = 0; i < 3; i++) {
      if (i < seats.length) {
        final place = seats[i].first.place ?? next;
        places.add(place);
        next = place + seats[i].length;
      } else {
        places.add(next <= 3 ? next : 0);
        next++;
      }
    }
    // Second, first, third, left to right.
    const order = [1, 0, 2];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final i in order)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: places[i] == 1 ? 0 : 22),
                child: i < seats.length
                    ? _Rise(
                        key: ValueKey(
                          'podium_${i}_${seats[i].map((e) => e.userId).join('_')}',
                        ),
                        // First place lands first.
                        index: i,
                        child: seats[i].length == 1
                            ? _Slot(place: places[i], entry: seats[i].single)
                            : _SharedSeat(place: places[i], entries: seats[i]),
                      )
                    : _EmptySeat(place: places[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/// A podium face: the picture, the viewer's accent ring, the medal set into
/// the bottom edge like a coin.
///
/// The picture sits on a disc of the page's own colour, 4.5 wider all round:
/// where faces overlap in a shared seat, the one in front is cut out of the
/// one behind by a clean page-coloured edge (the stacked-avatar idiom), so
/// the pile reads as layers rather than one blob.
class _PodiumFace extends StatelessWidget {
  const _PodiumFace({
    required this.entry,
    required this.place,
    this.medal = true,
    this.depth = 0,
  });

  final PodiumEntry entry;
  final int place;

  /// Off in a shared seat, which pins one medal under the whole stack.
  final bool medal;

  /// 0 in front, 1 a step behind: drains some colour from the picture (never
  /// its light, so a face behind is greyer, not darker) and fades the shadow.
  final double depth;

  static double sizeFor(int place) => place == 1 ? 72.0 : 56.0;

  /// Face plus ring: 2.5 + 2 each side.
  static double boxFor(int place) => sizeFor(place) + 9;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    Widget picture = PlayerFace(
      userId: entry.userId,
      label: _labelOf(context, l10n, entry),
      size: sizeFor(place),
    );
    if (depth > 0.01) {
      picture = ColorFiltered(
        colorFilter: ColorFilter.matrix(_saturation(1 - 0.45 * depth)),
        child: picture,
      );
    }
    // A soft lift on light pages; on dark ones a shadow is invisible and
    // only muddies the ring, so the cut-out edge does the work alone.
    final shadow = theme.isLight && depth < 0.99
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12 * (1 - depth)),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
        : null;
    final face = Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.background,
        boxShadow: shadow,
        border: Border.all(
          color: entry.isViewer ? theme.accent : theme.background,
          width: 2,
        ),
      ),
      child: picture,
    );
    if (!medal) return face;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        face,
        Positioned(
          bottom: -10,
          child: MedalDisc(
            rank: place,
            medal: true,
            size: 26,
            border: theme.background,
          ),
        ),
      ],
    );
  }

  /// A luminance-keeping saturation matrix: [s] 1 is untouched, 0 is grey.
  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      i * r + s, i * g, i * b, 0, 0,
      i * r, i * g + s, i * b, 0, 0,
      i * r, i * g, i * b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

String _labelOf(BuildContext context, AppLocalizations l10n, PodiumEntry e) =>
    e.isViewer ? sentenceCaseOf(context, l10n.momentRailYouLabel) : e.name;

/// Under a face: the name (the accent for you), the metric, the streak.
class _SeatLabel extends StatelessWidget {
  const _SeatLabel({required this.entry, required this.place});

  final PodiumEntry entry;
  final int place;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final nameStyle = (place == 1
            ? groupedHeaderStyle(theme)
            : groupedTitleStyle(theme).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ))
        .copyWith(color: entry.isViewer ? theme.accent : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _labelOf(context, l10n, entry),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: nameStyle,
        ),
        const SizedBox(height: 4),
        entry.metric,
        if (entry.streak >= 2) ...[
          const SizedBox(height: 5),
          StreakBadge(entry.streak),
        ],
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.place, required this.entry});

  final int place;
  final PodiumEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final slot = Semantics(
      container: true,
      button: entry.onTap != null,
      label: [
        '$place. ${_labelOf(context, l10n, entry)}',
        entry.semantics,
        if (entry.streak >= 2) l10n.streakDays(entry.streak),
      ].join(', '),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PodiumFace(entry: entry, place: place),
            const SizedBox(height: 16),
            _SeatLabel(entry: entry, place: place),
          ],
        ),
      ),
    );
    final onTap = entry.onTap;
    if (onTap == null) return slot;
    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      focusRadius: theme.radiusMd,
      child: slot,
    );
  }
}

/// One place shared by several: their faces in a small stack, swiped
/// sideways like cover flow. The centred one stands in front at full size;
/// one neighbour each side tucks in behind it, smaller, turned a little
/// toward the middle and greyer (never darker), cut out of the front face by
/// a page-coloured ring. Everything stays inside the seat's own width, so
/// nothing is clipped and nothing strays into the next seat. One medal under
/// the stack: the place belongs to the seat, not to whoever is in front.
///
/// Under it, the front one's name and metric, and how many share the place
/// ("×10"), which reads "3/10" while you swipe.
///
/// Never moves on its own: a seat that rotated by itself would fight the
/// calm motion setting and make taps miss. A tap on a neighbour brings it to
/// the front; a tap on the front one opens their result.
class _SharedSeat extends StatefulWidget {
  const _SharedSeat({required this.place, required this.entries});

  final int place;

  /// A to Z, two or more.
  final List<PodiumEntry> entries;

  @override
  State<_SharedSeat> createState() => _SharedSeatState();
}

class _SharedSeatState extends State<_SharedSeat>
    with SingleTickerProviderStateMixin {
  /// Which face is in front, in faces: fractional mid-swipe.
  late final AnimationController _page = AnimationController.unbounded(
    vsync: this,
    value: _start.toDouble(),
  )..addListener(_onPage);

  /// How far one face travels sideways per page; set each layout.
  double _step = 1;
  late int _shown = _start;
  bool _dragging = false;

  /// "3/10" instead of "×10" while swiping and a moment after.
  bool _counting = false;
  Timer? _countOff;

  int get _start {
    final you = widget.entries.indexWhere((e) => e.isViewer);
    return you < 0 ? 0 : you;
  }

  double get _last => (widget.entries.length - 1).toDouble();

  double get _inRange => _page.value.clamp(0.0, _last);

  void _onPage() {
    final now = _inRange.round();
    if (now == _shown) return;
    // A detent per face as it crosses the middle, under the finger or
    // gliding; not for a calm jump, which has no crossing to feel.
    if (_page.isAnimating || _dragging) HapticFeedback.selectionClick();
    setState(() => _shown = now);
  }

  @override
  void didUpdateWidget(_SharedSeat old) {
    super.didUpdateWidget(old);
    // The group changed under a refresh: stay on the same face, clamped.
    if (_page.value > _last) {
      _page.stop();
      _page.value = _last;
    }
  }

  @override
  void dispose() {
    _countOff?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _showCount() {
    _countOff?.cancel();
    if (!_counting) setState(() => _counting = true);
    _countOff = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_dragging) setState(() => _counting = false);
    });
  }

  // ── Gesture ──

  /// +1 when later names sit to the right.
  double get _dir => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _onStart(DragStartDetails _) {
    _page.stop();
    _dragging = true;
    _showCount();
  }

  void _onUpdate(DragUpdateDetails d) {
    // Past an end the finger pulls against resistance.
    final beyond = _page.value != _inRange;
    _page.value -= _dir * d.delta.dx / _step * (beyond ? 0.4 : 1);
  }

  void _onEnd(DragEndDetails d) {
    _dragging = false;
    final from = _page.value;
    final velocity = -_dir * d.velocity.pixelsPerSecond.dx / _step;
    // A flick carries on to the next face, a slow release lands on the
    // nearest; never more than one past where the finger let go.
    final near = from.clamp(0.0, _last).roundToDouble();
    final to = (from + velocity * 0.18)
        .roundToDouble()
        .clamp(near - 1, near + 1)
        .clamp(0.0, _last)
        .toDouble();
    _glide(to, velocity);
    _showCount();
  }

  void _onCancel() {
    // Lost to another gesture before it began, or torn down mid-drag.
    if (!_dragging || !mounted) return;
    _dragging = false;
    _glide(_inRange.roundToDouble(), 0);
  }

  void _goTo(int index) {
    _showCount();
    _glide(index.toDouble(), 0);
  }

  void _glide(double to, double velocity) {
    if (MotionScope.of(context).calm) {
      _page.value = to;
      return;
    }
    // Critically damped, so no face swings past the middle and back.
    _page
        .animateWith(SpringSimulation(
          SpringDescription.withDampingRatio(mass: 1, stiffness: 170),
          _page.value,
          to,
          velocity,
          tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
        ))
        .then((_) {
      if (mounted) _page.value = to;
    });
  }

  // ── Poses ──

  /// Face [i]'s pose at the current page: sideways offset (signed, before
  /// text direction), scale, turn and opacity. Null when not drawn.
  ({double x, double scale, double turn, double opacity, double depth})? _pose(
    int i,
    bool calm,
  ) {
    final d = i - _page.value;
    final a = d.abs();
    final side = d.sign;
    if (a <= 1) {
      return (
        x: side * _step * a,
        scale: 1 - 0.22 * a,
        turn: calm ? 0 : -side * 0.32 * a,
        opacity: 1,
        depth: a,
      );
    }
    // Past one step a face tucks back in behind its neighbour and fades
    // only once it is covered, so nothing ever rests see-through.
    if (calm || a >= 1.7) return null;
    final u = Curves.easeOut.transform((a - 1) / 0.7);
    return (
      x: side * _step * (1 - 0.45 * u),
      scale: 0.78 - 0.18 * u,
      turn: -side * (0.32 + 0.13 * u),
      opacity: a < 1.25 ? 1 : (1 - (a - 1.25) / 0.45).clamp(0.0, 1.0),
      depth: 1,
    );
  }

  Widget _strip(BuildContext context, double width) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final place = widget.place;
    final entries = widget.entries;
    final box = _PodiumFace.boxFor(place);
    // A neighbour's outer edge stays 4 inside the seat: step plus half its
    // scaled width. Too narrow for that (a small phone's side seat), it
    // shows no neighbours and the count chip alone says it is shared.
    final step = math.min(0.42 * box, width / 2 - 4 - 0.39 * box);
    final neighbours = step >= 0.18 * box;
    _step = neighbours ? step : box * 0.5;

    final posed = <(int, ({
      double x,
      double scale,
      double turn,
      double opacity,
      double depth,
    }))>[];
    for (var i = 0; i < entries.length; i++) {
      final pose = _pose(i, motion.calm);
      if (pose == null) continue;
      if (!neighbours && pose.depth > 0.5) continue;
      posed.add((i, pose));
    }
    // Furthest painted first, so the front face is painted (and hit) last.
    posed.sort((a, b) {
      final da = (a.$1 - _page.value).abs();
      final db = (b.$1 - _page.value).abs();
      if (da != db) return db.compareTo(da);
      return a.$1 == _inRange.round() ? 1 : -1;
    });
    final front = _inRange.round();
    return SizedBox(
      width: width,
      height: box + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, pose) in posed)
            Positioned(
              key: ValueKey(entries[i].userId),
              left: (width - box) / 2 + _dir * pose.x,
              top: 0,
              width: box,
              height: box,
              child: _faceAt(i, pose, front, theme),
            ),
          // One medal for the place, pinned under the stack and above every
          // face, hanging 10 below the front one like a coin.
          Positioned(
            left: (width - 26) / 2,
            top: box - 16,
            child: IgnorePointer(
              child: MedalDisc(
                rank: place,
                medal: true,
                size: 26,
                border: theme.background,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faceAt(
    int i,
    ({double x, double scale, double turn, double opacity, double depth}) pose,
    int front,
    AppTheme theme,
  ) {
    final entry = widget.entries[i];
    final a = (i - _page.value).abs();
    Widget face = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(_dir * pose.turn)
        ..scaleByDouble(pose.scale, pose.scale, 1, 1),
      child: _PodiumFace(
        entry: entry,
        place: widget.place,
        medal: false,
        depth: pose.depth,
      ),
    );
    if (pose.opacity < 1) face = Opacity(opacity: pose.opacity, child: face);
    if (a > 1.2) return IgnorePointer(child: face);
    if (i == front && a < 0.5) {
      final onTap = entry.onTap;
      if (onTap == null) return face;
      return SpringPress(
        onTap: onTap,
        scale: PressSpec.scaleSmall,
        haptic: false,
        hoverRadius: 0,
        child: face,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _goTo(i),
      child: face,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final entries = widget.entries;
    final place = widget.place;
    final current = entries[_shown.clamp(0, entries.length - 1)];
    final names = [for (final e in entries) _labelOf(context, l10n, e)];

    final count = Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: quietFill(theme),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          _counting ? '${_shown + 1}/${entries.length}' : '×${entries.length}',
          style: groupedMetaStyle(theme).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1,
            color: theme.inkSoft,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: [
        l10n.podiumSharedBy(entries.length, names.join(', '), place),
        '${_labelOf(context, l10n, current)}, ${current.semantics}',
      ].join('. '),
      onIncrease: _shown < entries.length - 1
          ? () => _goTo(_shown + 1)
          : null,
      onDecrease: _shown > 0 ? () => _goTo(_shown - 1) : null,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onStart,
                onHorizontalDragUpdate: _onUpdate,
                onHorizontalDragEnd: _onEnd,
                onHorizontalDragCancel: _onCancel,
                child: LayoutBuilder(
                  builder: (context, box) => AnimatedBuilder(
                    animation: _page,
                    builder: (context, _) => _strip(context, box.maxWidth),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: motion.calm
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: KeyedSubtree(
                key: ValueKey(current.userId),
                child: _SeatLabel(entry: current, place: place),
              ),
            ),
            const SizedBox(height: 6),
            count,
          ],
        ),
      ),
    );
  }
}

/// A podium place nobody has taken yet: a dashed outline where a face would
/// be, its place inside it, and nothing under it. No filled disc: on a dark
/// page a filled grey circle reads as a black hole, not as an open seat.
/// Past third (a seat with no podium place left to give) the outline is
/// empty. Quiet enough that a podium of one reads as one winner, not as two
/// people missing.
class _EmptySeat extends StatelessWidget {
  const _EmptySeat({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final box = place == 1 ? _PodiumFace.boxFor(1) : _PodiumFace.boxFor(2);
    return ExcludeSemantics(
      child: SizedBox(
        // The face box and the medal's 10 below it, like a taken seat.
        height: box + 10,
        child: Center(
          child: CustomPaint(
            size: Size.square(box),
            painter: _DashedRing(
              color: theme.inkMuted.withValues(alpha: 0.45),
            ),
            child: SizedBox.square(
              dimension: box,
              child: place == 0
                  ? null
                  : Center(
                      child: Text(
                        '$place',
                        style: groupedTitleStyle(theme).copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.inkMuted.withValues(alpha: 0.6),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed circle inset by half its stroke, the dashes spread evenly.
class _DashedRing extends CustomPainter {
  const _DashedRing({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.5;
    final r = size.shortestSide / 2 - stroke / 2;
    final around = 2 * math.pi * r;
    // About 4 on, 4 off, rounded so the last gap meets the first dash.
    final n = (around / 8).round();
    final sweep = 2 * math.pi / n;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, i * sweep - math.pi / 2, sweep / 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

/// Fades and lifts one slot in, staggered by [index].
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 60),
      // motionEntrance rather than motionCurve: some themes' motionCurve
      // overshoots past 1, which Opacity asserts on.
      curve: theme.motionEntrance,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}
