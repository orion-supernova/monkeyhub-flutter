import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart' show FocusRingShape;
import 'capture_glyphs.dart' show TrashGlyph;
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
/// The tray adds a lift (the others sit back at 0.86 scale), again a paint
/// transform, never a size, and its ring slides between tiles.
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
    this.tileKey,
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
        trailing = null,
        tileKey = null;

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

  /// Who tile [i] is, so a tray that loses or gains a photo can move the
  /// tiles that stayed instead of repainting new ones in their places. Null
  /// identifies tiles by position.
  final Object Function(int i)? tileKey;

  /// The remove chip on the current tray tile.
  static const removeChipKey = ValueKey('mediaFilmstrip.remove');

  /// How long a removed tile takes to go into the bin before the tray hands
  /// it to [onRemove].
  static const removeDuration = Duration(milliseconds: 220);

  /// Up to this many, the tray is built whole and animates (see
  /// [_TrayStrip]); past it, lazily, as the gallery's rail is.
  static const _eagerMax = 24;

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
    // Tiles slid in BEFORE the current one (the gallery fetching older
    // pictures): the ring's tile moved right by exactly that many, so the
    // offset moves with it, unanimated, and the reader sees the same tiles.
    // Otherwise the reveal below would slide the rail across the whole batch.
    // Read by this frame's layout; a rail that fitted without scrolling has
    // no offset to keep.
    final grew = widget.count - old.count;
    if (grew > 0 &&
        widget.index - old.index == grew &&
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent > 0) {
      final p = _scroll.position;
      p.correctPixels(p.pixels + grew * widget._extent);
    }
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

          if (!widget.viewer && widget.count <= MediaFilmstrip._eagerMax) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: HorizontalWheelScroll(
                child: _TrayStrip(
                  strip: widget,
                  scroll: _scroll,
                  viewport: constraints.maxWidth,
                ),
              ),
            );
          }

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
                    calm: MediaQuery.disableAnimationsOf(context),
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

/// The overshoot every tray motion shares: the ring sliding to a tile, a tile
/// lifting as it becomes current. A spring's settle in a curve, so a quick
/// second tap retargets from wherever the first one had got to.
const Cubic _trayOvershoot = Cubic(0.28, 1.32, 0.42, 1);

/// How far an unselected tray tile sits back: smaller and dimmer, a paint-only
/// transform so the rail never reflows under a thumb (see [MediaFilmstrip]).
const double _trayRestScale = 0.86;
const double _trayRestOpacity = 0.55;

/// The white ring's gap outside a tray tile, and its radius.
const double _trayRingInset = 3;
const double _trayTileRadius = 10;

/// One tray tile: the picture, lifting into place as it becomes current and
/// sitting back, smaller and dimmer, when it is not.
///
/// [ring] draws the selection ring on the tile itself, for the lazy rail; the
/// animated tray draws one ring that SLIDES between tiles instead, the real
/// thing moving rather than one ring fading out while another fades in.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.child,
    required this.selected,
    required this.onTap,
    required this.onRemove,
    required this.removeSemanticLabel,
    required this.semanticLabel,
    this.ring = true,
    this.leaving = false,
    this.calm = false,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? removeSemanticLabel;
  final String? semanticLabel;
  final bool ring;

  /// Being swallowed by the bin: shrinks into its top-left corner, where the
  /// remove chip sits, and fades.
  final bool leaving;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    const size = MediaFilmstrip.tileSize;
    final face = TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: calm ? Duration.zero : const Duration(milliseconds: 340),
      curve: _trayOvershoot,
      // The picture rasterises once; the lift is a compositor matrix.
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_trayTileRadius),
          child: SizedBox.expand(child: child),
        ),
      ),
      builder: (context, t, picture) => Transform.scale(
        scale: _trayRestScale + (1 - _trayRestScale) * t,
        child: Opacity(
          opacity: (_trayRestOpacity + (1 - _trayRestOpacity) * t)
              .clamp(0.0, 1.0),
          child: picture,
        ),
      ),
    );

    Widget tile = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: face),
          if (ring && selected)
            const Positioned(
              left: -_trayRingInset,
              top: -_trayRingInset,
              right: -_trayRingInset,
              bottom: -_trayRingInset,
              child: _TrayRing(),
            ),
        ],
      ),
    );

    tile = SpringPress(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: PressSpec.scaleSmall,
      focusRadius: _trayTileRadius,
      haptic: false,
      child: tile,
    );

    final remove = onRemove;
    if (remove != null) {
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          // Top-left, the house corner for anything that takes a thing away,
          // and off the face in the middle of the thumbnail. Pops in on the
          // tile that just became current, so the eye follows it there.
          Positioned(
            left: -13,
            top: -13,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: calm ? 1 : 0.4, end: 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: _RemoveChip(
                key: MediaFilmstrip.removeChipKey,
                onTap: remove,
                gulping: leaving,
                calm: calm,
                semanticLabel: removeSemanticLabel ?? '',
              ),
            ),
          ),
        ],
      );
    }

    // The swallow: into the corner the bin sits in, quicker than it came.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: leaving ? 1 : 0),
      duration: calm ? Duration.zero : MediaFilmstrip.removeDuration,
      curve: Curves.easeInCubic,
      child: tile,
      builder: (context, g, child) => g == 0
          ? child!
          : Transform.scale(
              alignment: Alignment.topLeft,
              scale: 1 - 0.8 * g,
              child: Opacity(opacity: 1 - g, child: child),
            ),
    );
  }
}

/// The tray's selection ring: white, outside the picture, so it costs the
/// thumbnail none of its pixels and competes with no colour in it.
class _TrayRing extends StatelessWidget {
  const _TrayRing();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(_trayTileRadius + _trayRingInset),
            border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
          ),
        ),
      );
}

/// The photo tray proper: every tile placed by hand, so the strip can MOVE.
///
/// Small by construction (a send carries a handful of photos), so it is built
/// eagerly and each tile keeps its State across a removal through its
/// [MediaFilmstrip.tileKey]. That buys the motion a lazy list cannot have:
///
///  * one ring slides from tile to tile with a spring's overshoot;
///  * a removed tile is swallowed by the bin chip in its corner, and the
///    tiles after it close the gap by sliding, not by jumping;
///  * a tile added from the camera or the library pops in.
class _TrayStrip extends StatefulWidget {
  const _TrayStrip({
    required this.strip,
    required this.scroll,
    required this.viewport,
  });

  final MediaFilmstrip strip;
  final ScrollController scroll;
  final double viewport;

  @override
  State<_TrayStrip> createState() => _TrayStripState();
}

class _TrayStripState extends State<_TrayStrip>
    with SingleTickerProviderStateMixin {
  /// Times the swallow; a ticker rather than a timer, so it stops with the
  /// screen and a test can pump through it.
  late final AnimationController _swallow = AnimationController(
    vsync: this,
    duration: MediaFilmstrip.removeDuration,
  );

  @override
  void dispose() {
    _swallow.dispose();
    super.dispose();
  }

  /// The tile on its way into the bin, by key, until [MediaFilmstrip.onRemove]
  /// has taken it out of the count.
  Object? _leaving;

  /// Keys present in the last build, so a key that was not is a new tile.
  Set<Object> _known = {};
  bool _built = false;

  Object _keyOf(int i) => widget.strip.tileKey?.call(i) ?? i;

  void _remove(int i) {
    if (_leaving != null) return;
    final calm = MediaQuery.disableAnimationsOf(context);
    if (calm) {
      widget.strip.onRemove?.call(i);
      return;
    }
    final key = _keyOf(i);
    setState(() => _leaving = key);
    _swallow.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      final strip = widget.strip;
      // Still where it was? Then it goes; a rail rebuilt under it in the
      // meantime (a send started) keeps it.
      final at = [for (var j = 0; j < strip.count; j++) _keyOf(j)].indexOf(key);
      setState(() => _leaving = null);
      if (at >= 0) strip.onRemove?.call(at);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strip = widget.strip;
    final calm = MediaQuery.disableAnimationsOf(context);
    const tile = MediaFilmstrip.tileSize;
    final extent = strip._extent;
    final slots = strip.count + (strip.trailing == null ? 0 : 1);
    final content = slots * extent - strip._gapNow;
    final centred = content <= widget.viewport;
    final pad = centred ? (widget.viewport - content) / 2 : 14.0;
    final width = centred ? widget.viewport : content + 28;
    const move = Duration(milliseconds: 300);
    final slide = calm ? Duration.zero : move;

    final keys = [for (var i = 0; i < strip.count; i++) _keyOf(i)];
    // New since the last build: these pop in, one after the other.
    final fresh = _built ? keys.where((k) => !_known.contains(k)).toList() : const [];
    _known = keys.toSet();
    _built = true;

    final index = strip.index;
    final hasRing = index >= 0 && index < strip.count;

    return SingleChildScrollView(
      controller: widget.scroll,
      scrollDirection: Axis.horizontal,
      physics: centred
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: SizedBox(
        width: width,
        height: tile,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < strip.count; i++)
              AnimatedPositioned(
                key: ValueKey<Object>(keys[i]),
                duration: slide,
                curve: Curves.easeOutCubic,
                left: pad + i * extent,
                top: 0,
                width: tile,
                height: tile,
                child: _PopIn(
                  delay: fresh.contains(keys[i])
                      ? Duration(milliseconds: 45 * fresh.indexOf(keys[i]))
                      : null,
                  calm: calm,
                  child: _Tile(
                    selected: i == index,
                    ring: false,
                    leaving: _leaving == keys[i],
                    calm: calm,
                    semanticLabel:
                        strip.tileSemanticLabel?.call(i + 1, strip.count),
                    onTap: () => strip.onTap(i),
                    onRemove: strip.onRemove == null || i != index
                        ? null
                        : () => _remove(i),
                    removeSemanticLabel: strip.removeSemanticLabel,
                    child: strip.thumbnailBuilder(context, i),
                  ),
                ),
              ),
            if (hasRing)
              // Over the tiles, but never in the way of a tap.
              AnimatedPositioned(
                key: const ValueKey('ring'),
                duration: calm ? Duration.zero : const Duration(milliseconds: 380),
                curve: _trayOvershoot,
                left: pad + index * extent - _trayRingInset,
                top: -_trayRingInset,
                width: tile + 2 * _trayRingInset,
                height: tile + 2 * _trayRingInset,
                child: AnimatedOpacity(
                  opacity: _leaving == null ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: const _TrayRing(),
                ),
              ),
            if (strip.trailing != null)
              AnimatedPositioned(
                key: const ValueKey('trailing'),
                duration: slide,
                curve: Curves.easeOutCubic,
                left: pad + strip.count * extent,
                top: 0,
                width: tile,
                height: tile,
                child: strip.trailing!,
              ),
          ],
        ),
      ),
    );
  }
}

/// A tile arriving: from small and clear to full size, overshooting once.
class _PopIn extends StatefulWidget {
  const _PopIn({required this.child, required this.delay, required this.calm});

  final Widget child;

  /// Null: already here when the rail was first built, no entrance.
  final Duration? delay;
  final bool calm;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  AnimationController? _in;

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null || widget.calm) return;
    const travel = 420;
    final wait = delay.inMilliseconds;
    _start = wait / (wait + travel);
    _in = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: wait + travel),
    )..forward();
  }

  /// Where in [_in] the tile starts moving: the stagger, without a timer.
  double _start = 0;

  @override
  void dispose() {
    _in?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _in;
    if (c == null) return widget.child;
    return AnimatedBuilder(
      animation: c,
      child: widget.child,
      builder: (context, child) {
        final t = ((c.value - _start) / (1 - _start)).clamp(0.0, 1.0);
        if (c.value >= 1) return child!;
        final s = 0.35 + 0.65 * Curves.easeOutBack.transform(t);
        return Transform.scale(
          scale: s,
          child: Opacity(
            opacity: Curves.easeOut.transform((t * 2).clamp(0.0, 1.0)),
            child: child,
          ),
        );
      },
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

/// The remove mark on the current tile: a small white disc with a drawn bin,
/// over the tile's top-left corner.
///
/// White on purpose. The dark × it once was vanished into the black round
/// the rail, and the red disc after it shouted louder than the photo; white
/// is the one ink that holds over both a photo and the black. The bin's lid
/// lifts while a finger is on it and slams as the tile goes in.
///
/// 22pt drawn inside a 36pt tap target, so it is easy to hit on purpose
/// without growing over the tiles beside it.
class _RemoveChip extends StatefulWidget {
  const _RemoveChip({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    required this.gulping,
    required this.calm,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final bool gulping;
  final bool calm;

  @override
  State<_RemoveChip> createState() => _RemoveChipState();
}

class _RemoveChipState extends State<_RemoveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gulp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(_RemoveChip old) {
    super.didUpdateWidget(old);
    if (widget.gulping && !old.gulping && !widget.calm) _gulp.forward(from: 0);
  }

  @override
  void dispose() {
    _gulp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: () {
        // The removal is a decision, not a selection: its own firmer tick.
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      semanticLabel: widget.semanticLabel,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.circle,
      focusRadius: 11,
      haptic: false,
      builder: (context, pressed) => Padding(
        // The extra slop is the tap target, not paint.
        padding: const EdgeInsets.all(7),
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 6)],
          ),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: pressed || widget.gulping ? 1 : 0),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            builder: (context, open, _) => AnimatedBuilder(
              animation: _gulp,
              builder: (context, _) => TrashGlyph(
                color: const Color(0xFF1C1C1E),
                open: open,
                gulp: _gulp.value,
                size: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
