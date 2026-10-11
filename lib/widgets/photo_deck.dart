import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../keyboard/focusable_tap.dart';
import 'message_stamp.dart';
import 'photo_mosaic.dart' show MosaicTile;

/// A run of photographs dealt as a hand of cards: one in front, the next ones
/// peeking out behind it, and a swipe that deals the next card or takes the
/// last one back. The iMessage album, and the alternative to [PhotoMosaic]
/// ([SettingsStore.albumCards] picks which).
///
/// ## Why cards
///
/// A grid shrinks every photograph to fit all of them; a hand keeps one at full
/// size and says "there are more" with the edges behind it. Ten photographs of
/// one evening read as one thing to flick through, not a contact sheet.
///
/// ## The swipe
///
/// A swipe scrolls a POSITION through the hand, the way a finger scrolls a
/// page, and every card's pose is a function of how far it is from that
/// position (see [_pose]). Nothing is sequenced: there is one number, and the
/// cards are where it says.
///
/// Between two neighbours the motion is one curve, and only the card being
/// swiped away rides it: out to the side and back onto its pile, shrinking
/// as it goes. The card behind it does not swing at all; it just comes
/// forward off its pile into the front. They trade places at the halfway
/// point, where the swiped card is furthest out, so neither is seen to pop
/// through the other. Going back, the front card swings out to the right and
/// the last card seen comes forward off the left pile.
/// A long swipe runs through several cards in order, each on its own arc.
/// Letting go glides the position to the nearest card on one critically
/// damped spring, carrying the finger's speed; a flick runs on further.
///
/// The hand has ends, as iMessage's does. Cards already seen stay in it,
/// behind the front like the ones still to come, and past either end the
/// whole hand gives a little under the finger and springs back. On the last
/// card the count label offers the way back to the first, which runs every
/// card back past on its own arc. (It used to wrap round forever; with no
/// last card a swipe never felt like it arrived anywhere.)
///
/// The iMessage stack, frame for frame. An earlier version moved the card
/// under the finger alone and swapped the stacking at a fixed distance, then
/// tucked the card away as a second animation; it read as two steps, and the
/// card visibly jumped from in front to behind partway through a swipe.

/// ## What stays the mosaic's
///
/// Each card is a [MosaicTile]: the same tap to fullscreen (and the same hero
/// tag, so the flight works unchanged), the same long-press menu anchored to
/// that photograph, its own reaction chips and upload arc. Only the front card
/// takes taps; behind cards are scenery.
///
/// ## Cost
///
/// Transforms and a shadow per card, at most four cards mounted. No blur, no
/// relayout while dragging: the stack's size is fixed by [width].
class PhotoDeck extends StatefulWidget {
  const PhotoDeck({
    super.key,
    required this.photos,
    required this.api,
    required this.width,
    required this.radius,
    required this.currentUserId,
    required this.onOpen,
    this.onTileLongPress,
    this.onTileContextMenu,
    this.onReactionTap,
    this.onReactionLongPress,
    this.highlightedPhotoId,
    this.highlightT = 0,
    this.stamp,
  });

  /// Oldest first; the first is the front card.
  final List<ChatMessage> photos;
  final ChatApi api;

  /// The deck's full width, peeking edges included.
  final double width;
  final BorderRadius radius;
  final String currentUserId;
  final void Function(ChatMessage m, {required int sourceDecodeWidth}) onOpen;
  final void Function(ChatMessage m, GlobalKey anchor)? onTileLongPress;
  final void Function(ChatMessage m, Offset globalPosition)? onTileContextMenu;
  final void Function(ChatMessage m, String emoji)? onReactionTap;
  final void Function(ChatMessage m, String emoji)? onReactionLongPress;

  /// A jump that lands on one of these photographs deals it to the front, so
  /// the pulse is on a card the reader can actually see.
  final String? highlightedPhotoId;
  final double highlightT;

  /// The album's one time and delivery stamp, laid on the front card's
  /// corner. Lifted off while a card is moving: it belongs to the hand, not
  /// to whichever card is passing through that corner.
  final MessageStamp? stamp;

  /// How far each card behind sticks out past the one in front of it.
  static const double peek = 8;

  /// Cards drawn behind the front one at rest.
  static const int behindMax = 2;

  /// Card height over width: a portrait card, the shape most phone photos
  /// are, so the common photograph loses the least to the crop.
  static const double aspect = 1.22;

  /// The front card's width for a deck [width] wide holding [count]
  /// photographs: what is left once the peeking edges have their room, on
  /// both sides (cards still to come wait on the right, cards already seen on
  /// the left).
  static double cardWidth(double width, int count) =>
      width - 2 * inset(count);

  /// The room each side of the front card, for the cards piled there.
  static double inset(int count) => peek * math.min(count - 1, behindMax);

  @override
  State<PhotoDeck> createState() => _PhotoDeckState();
}

/// Where a card is drawn: offset, size, tilt, how far it is shaded into the
/// deck, and how much of it is there at all.
class _Pose {
  const _Pose(this.x, this.scale, this.turn, this.shade, this.opacity);
  final double x, scale, turn, shade, opacity;
}

class _PhotoDeckState extends State<PhotoDeck>
    with SingleTickerProviderStateMixin {
  /// Where the hand is scrolled to: the front card's index, fractional
  /// mid-swipe. It may run past either end while a finger pulls it there
  /// (see [_overscroll]); released, it springs to a whole number in range.
  late final AnimationController _position =
      AnimationController.unbounded(vsync: this)
        ..addListener(_repaint)
        // And on every status change. A glide that ends exactly on its card
        // changes no value on its last frame, so without this nothing
        // rebuilds once it stops: the deck went on thinking it was moving,
        // and left the front card ignoring pointers, so a long-press fell
        // through to the row (the album's LAST item) and the stamp stayed
        // hidden.
        ..addStatusListener((_) => _repaint());

  bool _dragging = false;

  /// The card the current swipe started on, for the tick when it lands on
  /// another, and to tell which way the hand is going: the card leaving the
  /// front in that direction is the one that swings (see [_pose]).
  double _startedAt = 0;

  final Map<String, GlobalKey> _anchors = {};
  GlobalKey _anchorFor(String id) =>
      _anchors.putIfAbsent(id, () => GlobalKey(debugLabel: 'deck-$id'));

  void _repaint() {
    if (mounted) setState(() {});
  }

  int get _n => widget.photos.length;
  double get _cardW => PhotoDeck.cardWidth(widget.width, _n);

  /// Finger travel that scrolls the hand by one card.
  double get _step => _cardW * 0.8;

  /// How far a card swings out at the top of its arc.
  double get _swing => _cardW * 0.46;

  double get _last => (_n - 1).toDouble();

  /// The position within the hand's ends.
  double get _inRange => _position.value.clamp(0.0, _last);

  /// How far, in pixels, the whole hand gives when pulled past an end.
  double get _overscroll => -(_position.value - _inRange) * _step * 0.35;

  /// The index of the card in front, once the hand is at rest.
  int get _front => _inRange.round();

  /// At rest as far as anyone can see: no finger down, and the hand within
  /// a sliver of a card of landing. NOT "the glide has finished": a
  /// critically damped spring creeps its last fraction of a point for most of
  /// a second, and a hand that counted that as moving ignored a long-press
  /// made right after a swipe (it fell through to the row, the album's last
  /// item) and kept its stamp hidden.
  bool get _resting =>
      !_dragging &&
      (_position.value - _position.value.roundToDouble()).abs() < 0.02;

  @override
  void initState() {
    super.initState();
    _dealHighlighted();
  }

  @override
  void didUpdateWidget(PhotoDeck old) {
    super.didUpdateWidget(old);
    _faces.clear();
    final live = {for (final m in widget.photos) m.id};
    _anchors.removeWhere((id, _) => !live.contains(id));
    if (widget.highlightedPhotoId != old.highlightedPhotoId) {
      _dealHighlighted();
    }
  }

  void _dealHighlighted() {
    final id = widget.highlightedPhotoId;
    if (id == null) return;
    final i = widget.photos.indexWhere((m) => m.id == id);
    if (i >= 0) _position.value = i.toDouble();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  // ── Gesture ──

  void _onStart(DragStartDetails _) {
    // A finger on a hand still gliding picks it up exactly where it is.
    _position.stop();
    _dragging = true;
    _startedAt = _position.value.roundToDouble();
  }

  void _onUpdate(DragUpdateDetails d) {
    // Leftward scrolls forward, through the next cards. Past an end the
    // finger pulls against resistance.
    final beyond = _position.value != _inRange;
    _position.value -= d.delta.dx / _step * (beyond ? 0.4 : 1);
  }

  void _onEnd(DragEndDetails d) {
    _dragging = false;
    final from = _position.value;
    final velocity = -d.velocity.pixelsPerSecond.dx / _step;
    // Where it would coast to, rounded to a card: a flick carries on to the
    // next one, a slow release lands on the nearest. Never more than one card
    // past where the finger let go, so a hard flick stays in hand.
    final near = from.clamp(0.0, _last).roundToDouble();
    final to = (from + velocity * 0.18)
        .roundToDouble()
        .clamp(near - 1, near + 1)
        .clamp(0.0, _last)
        .toDouble();
    if (to != _startedAt) HapticFeedback.selectionClick();
    _glide(to, velocity);
  }

  void _onCancel() {
    _dragging = false;
    _glide(_inRange.roundToDouble(), 0);
  }

  void _backToFirst() {
    HapticFeedback.selectionClick();
    _startedAt = _front.toDouble();
    _glide(0, 0);
  }

  void _glide(double to, double velocity) {
    if (MotionScope.of(context).calm) {
      _position.value = to;
      setState(() {});
      return;
    }
    // Critically damped: nothing swings past its card and back. A spring
    // stops within a tolerance of its target, not on it, and the hand is only
    // at rest (front card tappable, stamp back on) on a whole number.
    _position
        .animateWith(SpringSimulation(
          SpringDescription.withDampingRatio(mass: 1, stiffness: 170),
          _position.value,
          to,
          velocity,
          // In cards: a thousandth of one is a fraction of a point, and the
          // default's far tighter velocity floor kept the ticker (and every
          // card's repaint) running long after anything visibly moved.
          tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
        ))
        .then((_) {
      if (mounted) _position.value = to;
    });
  }

  // ── Poses ──

  /// How far card [i] sits from the position, in cards: 0 in front,
  /// positive for the ones still to come, negative for the ones already seen.
  double _offset(int i) => i - _inRange;

  /// A card [depth] places behind the front (fractional mid-move), on the
  /// [side] it is piled: +1 right (still to come, the side they arrive
  /// from), -1 left (already seen, the side they leave by).
  ///
  /// One pile used to hold both, on the left, so behind the front a card
  /// already seen and the next one sat in exactly the same place, and which
  /// of the two showed flipped partway through a swipe: the "second card"
  /// visibly jumped to the right one.
  _Pose _depth(double depth, double side) {
    final d = depth.clamp(0.0, PhotoDeck.behindMax + 1.0);
    final scale = 1 - 0.06 * d;
    return _Pose(
      // Centre-scaled, so push it out by what the scale took off its edge as
      // well as by its peek.
      side * (PhotoDeck.peek * d + _cardW * (1 - scale) / 2),
      scale,
      side * 0.03 * d,
      (0.16 * d).clamp(0.0, 0.48),
      d <= PhotoDeck.behindMax
          ? 1
          : (PhotoDeck.behindMax + 1 - d).clamp(0.0, 1.0),
    );
  }

  /// How deep a card at offset [r] sits: as many places behind the front as
  /// it is cards away, either side. A card leaving sinks exactly as fast as
  /// the next one rises, so they are level at the halfway swap, and it ends
  /// one place behind the new front: the card going "back inside the deck".
  double _depthAt(double r) => r.abs();

  /// Whether card [i] is the one being swiped away: of the two cards either
  /// side of the position, the one the hand is moving off. Forward (the
  /// position past where the swipe started) that is the lower of the two;
  /// back, the higher.
  bool _swiped(int i) {
    final p = _inRange;
    final k = p.floor();
    if (p == k) return false;
    return i == (k >= _startedAt ? k : k + 1);
  }

  /// Card [i]'s pose: its place on its pile, and, for the card being swiped
  /// away, an arc out to the side and back, tilting with it and shrinking a
  /// little more at the top of the swing.
  _Pose _pose(int i) {
    final r = _offset(i);
    final base = _depth(_depthAt(r), r.sign);
    final swung = r.abs() < 1 && _swiped(i);
    final out = swung ? math.sin(math.pi * r.abs()) : 0.0;
    final arc = r.sign * out * _swing;
    return _Pose(
      base.x + arc + _overscroll,
      base.scale * (1 - 0.06 * out),
      base.turn + arc / _cardW * 0.2,
      base.shade,
      base.opacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final cardW = _cardW;
    final cardH = cardW * PhotoDeck.aspect;

    // Drawn back to front, by depth; at the halfway swap the two cards are
    // equally deep and the one nearer the position wins. Cards past the
    // deepest painted place are skipped, except one place further, kept
    // mounted (unpainted) so its picture is decoded before it is needed.
    final drawn = <(int, double, double)>[];
    for (var i = 0; i < _n; i++) {
      final depth = _depthAt(_offset(i));
      if (depth > PhotoDeck.behindMax + 1.0) continue;
      drawn.add((i, depth, depth));
    }
    drawn.sort((a, b) {
      final byDepth = b.$2.compareTo(a.$2);
      return byDepth != 0 ? byDepth : b.$3.compareTo(a.$3);
    });

    final resting = _resting;
    final front = _front;
    final inset = PhotoDeck.inset(_n);
    final stamp = widget.stamp;
    // Its own stack rather than [StampedMedia]'s: that one clips to its box,
    // which cut a straight edge off every card swinging out past the deck.
    // The stamp sits on the front card's corner, not the deck's.
    final deck = SizedBox(
      width: widget.width,
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, _, _) in drawn)
            Positioned(
              key: ValueKey(widget.photos[i].id),
              left: inset,
              top: 0,
              width: cardW,
              height: cardH,
              // The card nearest the position takes touches whenever no finger
              // is dragging, settled or not: a press while the hand is still
              // gliding home is about that card, and leaving it inert let the
              // press fall through to the row (the album's LAST item).
              child: _card(theme, i, _pose(i), front: !_dragging && i == front),
            ),
          // Where in the hand you are, on the front card's corner and fixed
          // there while the cards move under it. See [_DeckPager].
          // 2, not 8: the pager pads its own tap target by 6.
          Positioned(
            top: 2,
            right: inset + 2,
            child: _DeckPager(
              count: _n,
              position: _inRange,
              atEnd: resting && front == _n - 1,
              semanticLabel: l10n.photoTrayCountLabel(_n),
              backLabel: l10n.photoDeckBackToFirst,
              onBack: _backToFirst,
            ),
          ),
          if (resting && stamp != null)
            Positioned(
              right: inset + 8,
              bottom: 8,
              child: KeyedSubtree(
                key: kVisibleStampKey,
                child: IgnorePointer(child: stamp),
              ),
            ),
        ],
      ),
    );

    // The swipe is heard over the label as well as the cards: a drag that
    // started an inch too high used to fall through to the row's reply
    // swipe.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _onCancel,
      child: deck,
    );
  }

  /// Each card's face, built once and handed back identical on every frame of
  /// a swipe, so a drag rebuilds and repaints nothing but the transforms. The
  /// [RepaintBoundary] keeps the picture, its rounded clip and its shadow as
  /// one cached layer that the transform only moves. Dropped whenever the
  /// album or the theme changes, which is never mid-swipe.
  final Map<String, Widget> _faces = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _faces.clear();
  }

  Widget _face(AppTheme theme, ChatMessage m) => _faces[m.id] ??=
      RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: widget.radius,
            child: MosaicTile(
              anchor: _anchorFor(m.id),
              message: m,
              api: widget.api,
              theme: theme,
              side: _cardW,
              radius: widget.radius,
              highlightT:
                  m.id == widget.highlightedPhotoId ? widget.highlightT : 0.0,
              currentUserId: widget.currentUserId,
              onOpen: (w) => widget.onOpen(m, sourceDecodeWidth: w),
              onLongPress: widget.onTileLongPress == null
                  ? null
                  : () => widget.onTileLongPress!(m, _anchorFor(m.id)),
              onContextMenu: widget.onTileContextMenu == null
                  ? null
                  : (at) => widget.onTileContextMenu!(m, at),
              onReactionTap: widget.onReactionTap == null
                  ? null
                  : (emoji) => widget.onReactionTap!(m, emoji),
              onReactionLongPress: widget.onReactionLongPress == null
                  ? null
                  : (emoji) => widget.onReactionLongPress!(m, emoji),
            ),
          ),
        ),
      );

  Widget _card(AppTheme theme, int index, _Pose pose, {required bool front}) {
    final m = widget.photos[index];
    // Every wrapper is always present, at a value that costs nothing when
    // idle (opacity 1, a clear shade): adding or dropping one mid-swipe would
    // change the tree's shape and remount the face under it.
    return IgnorePointer(
      ignoring: !front,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(pose.x, 0, 0, 1)
          ..rotateZ(pose.turn)
          ..scaleByDouble(pose.scale, pose.scale, 1, 1),
        child: Opacity(
          opacity: pose.opacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _face(theme, m),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: widget.radius,
                    color: Colors.black.withValues(alpha: pose.shade),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where in the hand you are: a dot per photograph on a small dark capsule,
/// the current one drawn out into a bar. It replaces a "▦ 4 photos" caption
/// over the bubble, which said how many but not where, and cost the bubble a
/// line.
///
/// The bar is a function of the same fractional position the cards are, so
/// it slides from dot to dot under the finger in step with them rather than
/// jumping when a card lands. On the last card a ↺ grows into the capsule and
/// the capsule takes a tap back to the first.
///
/// Past [_maxDots] the dots stop being countable at a glance, and a row of
/// them grows wider than a small card can spare, so the capsule says
/// "3 / 12" instead.
///
/// A plain translucent fill, not glass: it repaints every frame of a swipe,
/// and a blur under it would be re-sampled every frame too.
class _DeckPager extends StatelessWidget {
  const _DeckPager({
    required this.count,
    required this.position,
    required this.atEnd,
    required this.semanticLabel,
    required this.backLabel,
    required this.onBack,
  });

  final int count;
  final double position;
  final bool atEnd;
  final String semanticLabel;
  final String backLabel;
  final VoidCallback onBack;

  static const int _maxDots = 4;
  static const double _dot = 5;
  static const double _bar = 14;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final capsule = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: atEnd
                  ? const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(CupertinoIcons.arrow_counterclockwise,
                          size: 11, color: Colors.white),
                    )
                  : const SizedBox(height: 11),
            ),
            if (count > _maxDots)
              Text(
                '${position.round() + 1} / $count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  // Fixed-width digits, so the capsule does not twitch as
                  // the number changes under a swipe.
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )
            else
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                _pip(i),
              ],
          ],
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      child: IgnorePointer(
        ignoring: !atEnd,
        child: ExcludeFocus(
          excluding: !atEnd,
          child: FocusableTap(
            onTap: onBack,
            semanticLabel: backLabel,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              // A thumb-sized target round a capsule a few points tall.
              child: Padding(padding: const EdgeInsets.all(6), child: capsule),
            ),
          ),
        ),
      ),
    );
  }

  /// Dot [i]: drawn out toward a bar, and brightened, as the position nears
  /// it, so the bar is shared between two dots mid-swipe.
  Widget _pip(int i) {
    final near = (1 - (i - position).abs()).clamp(0.0, 1.0);
    return Container(
      width: _dot + (_bar - _dot) * near,
      height: _dot,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45 + 0.55 * near),
        borderRadius: BorderRadius.circular(_dot / 2),
      ),
    );
  }
}
