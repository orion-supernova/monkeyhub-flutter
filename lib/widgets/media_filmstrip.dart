import 'package:flutter/cupertino.dart';

import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';
import 'spring_press.dart';
import 'desktop_scroll.dart';

/// The rail of thumbnails that sits under a full-bleed picture.
///
/// One widget for two screens that look the same and mean different things: in
/// the fullscreen viewer it is *where you are* in a set that already exists,
/// and in the photo tray it is *what you are about to send*. Both want the same
/// furniture — equal tiles, the current one ringed, tap to jump, the selection
/// dragged back into view when it moves — and the difference between them is
/// two optional parameters ([onRemove] and [trailing]) rather than two files.
///
/// **Every tile is the same width, including the selected one.** The obvious
/// design enlarges the current thumbnail, and it is the wrong one twice over:
/// a strip whose extents change under the scroll offset cannot be given an
/// `itemExtent`, so keeping the selection centred stops being arithmetic and
/// starts being a guess, and every swipe of the picture above makes the whole
/// rail reflow sideways under the reader's thumb. Selection is a ring and a
/// brightness instead — the same signal, spent on paint rather than layout.
///
/// Deliberately NOT built on media [LiquidGlass] like the rest of the photo
/// chrome. A glass pane is a `BackdropFilter`, this rail slides and fades with
/// the chrome, and animating a backdrop filter is the one thing this app has
/// agreed never to do. A flat gradient scrim buys the same legibility over an
/// arbitrary photograph for the cost of a shader.
class MediaFilmstrip extends StatefulWidget {
  const MediaFilmstrip({
    super.key,
    required this.count,
    required this.index,
    required this.thumbnailBuilder,
    required this.onTap,
    this.onRemove,
    this.removeSemanticLabel,
    this.tileSemanticLabel,
    this.trailing,
  }) : viewer = false;

  /// The gallery's rail: small square tiles packed 2pt apart, the others
  /// dimmed and the current one ringed in white — the Photos filmstrip. The
  /// plain constructor stays the photo tray's, which is an editor's rail of
  /// things you are about to send, with room for the remove chip on each.
  const MediaFilmstrip.viewer({
    super.key,
    required this.count,
    required this.index,
    required this.thumbnailBuilder,
    required this.onTap,
    this.tileSemanticLabel,
  })  : viewer = true,
        onRemove = null,
        removeSemanticLabel = null,
        trailing = null;

  /// The gallery's look — see [MediaFilmstrip.viewer].
  final bool viewer;

  final int count;

  /// The tile to ring. Out-of-range rings nothing, which is what an empty tray
  /// wants.
  final int index;

  /// Builds the picture inside tile [i]. Sized to fill a [tileSize] square and
  /// clipped by the rail, so a builder need not think about either.
  final Widget Function(BuildContext context, int i) thumbnailBuilder;

  final void Function(int i) onTap;

  /// Shows a dismiss badge on the CURRENT tile — never on the others, where it
  /// would sit under a thumb reaching to switch photos. Null — the viewer's
  /// case — leaves the tiles unadorned: you cannot take a photo out of a
  /// conversation that already happened.
  final void Function(int i)? onRemove;

  final String? removeSemanticLabel;

  /// Announced on tile [i] itself. `(i, count)` rather than a plain index
  /// because "3" alone tells a screen-reader user nothing about how far along
  /// the rail they are.
  final String Function(int i, int count)? tileSemanticLabel;

  /// Pinned after the last tile and scrolling with it — the tray's "add more".
  final Widget? trailing;

  /// Side of one tile. Big enough to recognise a face in, small enough that
  /// eight of them fit across a phone.
  static const tileSize = 54.0;
  static const _gap = 8.0;

  /// Height of the whole rail including its padding — callers reserve space
  /// with this rather than measuring it.
  static const height = tileSize + 22;

  /// The gallery rail's tile: small enough that the rail reads as an index
  /// under the photograph rather than a second row of photographs.
  static const viewerTileSize = 40.0;
  static const _viewerGap = 2.0;

  /// [height] for [MediaFilmstrip.viewer].
  static const viewerHeight = viewerTileSize + 12;

  double get _tile => viewer ? viewerTileSize : tileSize;
  double get _gapNow => viewer ? _viewerGap : _gap;
  double get _extent => _tile + _gapNow;

  @override
  State<MediaFilmstrip> createState() => _MediaFilmstripState();
}

class _MediaFilmstripState extends State<MediaFilmstrip> {
  final ScrollController _scroll = ScrollController();

  /// Viewport width from the last layout, so a selection change can compute a
  /// centring offset without waiting for another one. Zero until first build,
  /// where [_reveal] has nothing to do anyway.
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    // The gallery does NOT open on item zero — it opens on whatever was tapped,
    // forty photographs up the conversation. Without this the rail mounts at
    // offset zero showing the oldest six tiles, with the ring somewhere off the
    // right-hand edge, and only catches up on the reader's first swipe.
    //
    // After the first frame, because the offset is computed from a viewport
    // width that does not exist until layout has run. Jumped rather than
    // animated: nothing has moved yet, so there is nothing to follow.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(MediaFilmstrip old) {
    super.didUpdateWidget(old);
    // Also on a count change: removing the tile before the current one shifts
    // everything after it left, so the ring would otherwise sit under a
    // neighbour until the next tap.
    if (old.index != widget.index || old.count != widget.count) {
      // After the frame that lays the new count out — `maxScrollExtent` is
      // read below and a strip that just got shorter has not yet recomputed
      // it, so clamping now would clamp against the old one.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Slides tile [widget.index] to the middle, as far as the ends allow.
  void _reveal({bool animate = true}) {
    if (!mounted || !_scroll.hasClients || _viewport <= 0) return;
    final i = widget.index;
    if (i < 0 || i >= widget.count) return;
    final extent = widget._extent;
    final target = (i * extent +
            extent / 2 -
            _viewport / 2)
        .clamp(
      _scroll.position.minScrollExtent,
      _scroll.position.maxScrollExtent,
    );
    if ((target - _scroll.offset).abs() < 0.5) return;
    if (!animate) {
      _scroll.jumpTo(target);
      return;
    }
    _scroll.animateTo(
      target,
      // Short: this follows a swipe the user already made, so it should read
      // as the rail keeping up rather than as a second animation answering the
      // first.
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // One past the last tile when there is a trailing slot, so the arithmetic
    // below and the builder agree about how long the rail is.
    final slots = widget.count + (widget.trailing == null ? 0 : 1);
    final tile = widget._tile;
    final gap = widget._gapNow;
    return SizedBox(
      height: widget.viewer
          ? MediaFilmstrip.viewerHeight
          : MediaFilmstrip.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.maxWidth;
          final contentWidth = slots * widget._extent - gap;
          // A rail that fits sits centred and does not scroll. Left-aligning
          // three thumbnails under a centred photograph looks like the layout
          // ran out of things to do.
          final centred = contentWidth <= constraints.maxWidth;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: widget.viewer ? 6 : 11),
            // Lazily built, and it has to be: a long conversation's gallery is
            // hundreds of items, each tile owns a `RemoteImage` that resolves a
            // serving URL when it mounts, and a rail that inflated all of them
            // would spend a network round trip per photograph nobody has
            // scrolled to yet.
            child: HorizontalWheelScroll(
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: centred
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                padding: centred
                    ? EdgeInsets.symmetric(
                        horizontal: (constraints.maxWidth - contentWidth) / 2,
                      )
                    : const EdgeInsets.symmetric(horizontal: 14),
                itemCount: slots,
                // The ring around the current tile is painted past its edges,
                // into the gap; a clipping viewport would shave it off the
                // first and last tile.
                clipBehavior: Clip.none,
                separatorBuilder: (_, _) => SizedBox(width: gap),
                itemBuilder: (context, i) {
                  if (i >= widget.count) {
                    return SizedBox(
                      width: tile,
                      height: tile,
                      child: widget.trailing,
                    );
                  }
                  if (widget.viewer) {
                    return _ViewerTile(
                      selected: i == widget.index,
                      semanticLabel:
                          widget.tileSemanticLabel?.call(i + 1, widget.count),
                      onTap: () => widget.onTap(i),
                      child: widget.thumbnailBuilder(context, i),
                    );
                  }
                  return _Tile(
                    selected: i == widget.index,
                    accent: theme.accent,
                    semanticLabel:
                        widget.tileSemanticLabel?.call(i + 1, widget.count),
                    onTap: () => widget.onTap(i),
                    // Only on the photo being looked at. A badge on every tile
                    // sat exactly where a thumb lands reaching for another
                    // photo, so switching photos kept deleting them; now a
                    // tap on any other tile can only ever select it.
                    onRemove: widget.onRemove == null || i != widget.index
                        ? null
                        : () => widget.onRemove!(i),
                    removeSemanticLabel: widget.removeSemanticLabel,
                    child: widget.thumbnailBuilder(context, i),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.child,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.onRemove,
    required this.removeSemanticLabel,
    required this.semanticLabel,
  });

  final Widget child;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? removeSemanticLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The ring is drawn OUTSIDE the clip, so it never eats a row of the
    // thumbnail's own pixels — a 2pt border painted inside a 54pt tile is 4%
    // of the picture gone, and on a strip of faces that is the difference
    // between recognising someone and not.
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: MediaFilmstrip.tileSize,
      height: MediaFilmstrip.tileSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected ? accent : const Color(0x1FFFFFFF),
          width: selected ? 2 : 1,
        ),
      ),
      // A hair inside the ring so the two do not share pixels.
      padding: const EdgeInsets.all(1.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: AnimatedOpacity(
          // Unselected tiles are present, not shouting. Dimming rather than
          // greying keeps them recognisable as the photographs they are.
          opacity: selected ? 1 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: SizedBox.expand(child: child),
        ),
      ),
    );

    // The shared press: a small spring and a focus stop (it was a bare
    // FocusableTap + GestureDetector, which never moved under a finger).
    return SpringPress(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: PressSpec.scaleSmall,
      focusRadius: 9,
      haptic: false,
      child: onRemove == null
            ? tile
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  tile,
                  // Its own tap target rather than a long-press on the
                  // tile: removing a photo from a send is a one-tap decision
                  // everywhere else people have met it, and a gesture with
                  // no visible affordance is a feature only the person who
                  // wrote it knows about. The shared overlay chip, centred
                  // where the old private badge was, a few points over the
                  // corner so it stays off the face in the thumbnail.
                  Positioned(
                    top: -10,
                    right: -10,
                    // Pops in on the tile that just became current, so the
                    // eye follows it to the photo it belongs to.
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      builder: (_, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: _RemoveBadge(
                        onTap: onRemove!,
                        semanticLabel: removeSemanticLabel ?? '',
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

/// One square in the gallery's rail ([MediaFilmstrip.viewer]).
///
/// The ring is white and sits OUTSIDE the tile, in the 2pt gap — white because
/// the rail lives on a photograph, where an accent ring is one more colour
/// competing with the picture's own; outside so it costs the thumbnail none of
/// its 40 points.
///
/// Under a mouse a tile lifts most of the way out of its dimming and shows
/// a pointing hand, so the rail reads as a row of things to click rather
/// than a caption. Hover only: touch never sends it, so a phone's rail is
/// exactly as it was.
class _ViewerTile extends StatefulWidget {
  const _ViewerTile({
    required this.child,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  static const _size = MediaFilmstrip.viewerTileSize;

  @override
  State<_ViewerTile> createState() => _ViewerTileState();
}

class _ViewerTileState extends State<_ViewerTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    const size = _ViewerTile._size;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SpringPress(
        onTap: widget.onTap,
        semanticLabel: widget.semanticLabel,
        scale: PressSpec.scaleSmall,
        focusRadius: 8,
        haptic: false,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedOpacity(
                    // Dimmed, not greyed: the others stay recognisable as the
                    // photographs they are while the current one is plainly lit.
                    opacity: selected ? 1 : (_hover ? 0.85 : 0.55),
                    duration: const Duration(milliseconds: 150),
                    child: SizedBox.expand(child: widget.child),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: -2,
                  top: -2,
                  right: -2,
                  bottom: -2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                      ),
                    ),
                  ),
                ),
              if (!selected && _hover)
                // A hairline where the selected ring would be: "this one" under
                // the pointer, quieter than the ring that means "this one is up".
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0x80FFFFFF),
                          width: 1,
                        ),
                      ),
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

/// The scrim the rail and the chrome sit on.
///
/// A gradient rather than a bar: over a dark photograph a hard-edged panel is
/// a visible rectangle of slightly different black, and over a bright one a
/// rail with no scrim at all is unreadable. The gradient is invisible in both.
class MediaScrim extends StatelessWidget {
  const MediaScrim({super.key, required this.height, this.fromTop = false});

  final double height;
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: const [Color(0xB3000000), Color(0x00000000)],
          ),
        ),
      ),
    );
  }
}

/// The remove mark on the current tile: a red disc with a white trash glyph
/// and a white ring — iOS's delete red, so it reads as "take this out" at a
/// glance. The neutral dark × it replaced vanished into the black around
/// the rail.
///
/// 26pt drawn inside a 40pt tap target, so it is easy to hit on purpose
/// without growing over the tiles beside it.
class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final danger = ThemeScope.of(context).danger;
    return SpringPress(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.circle,
      focusRadius: 13,
      // The removal plays its own impact; the press must not add a tick.
      haptic: false,
      child: Padding(
        // The extra slop is the tap target, not paint.
        padding: const EdgeInsets.all(2),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: danger,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 6),
            ],
          ),
          child: const Icon(
            CupertinoIcons.trash_fill,
            size: 13,
            color: Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}
