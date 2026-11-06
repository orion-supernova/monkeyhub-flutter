import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

// Telegram's profile header (PeerInfoHeaderNode), the way the React Native
// port does it in HeroHeader.tsx: as the page scrolls up, the hero's avatar
// shrinks and slides to the left of the title while the name scales down to a
// 17pt title beside it, both landing in the bar. Pulling past the top grows
// the avatar. Driven straight off the scroll offset, so it tracks the finger
// and reverses exactly.
//
// The avatar and name stay where the screen builds them, with their own taps,
// badges and Hero flights. [HeroDockAvatar] and [HeroDockTitle] leave a
// same-size gap in the scrolled content and paint the real widget in
// [HeroPage]'s own overlay, which sits above the bar's veil. That way the
// docked pair is never covered by the fade that hides scrolled rows.

/// The avatar's diameter once docked in the bar.
const double kDockedAvatar = 44;

/// Space between the docked avatar and the title.
const double _dockGap = 8;

/// The docked title's font size: the iOS bar title.
const double _dockTitleSize = 17;

/// The bar keeps this much clear on each side for the back button and actions.
const double _barSideInset = 64;

/// Pulling down this far grows the avatar by [_stretchMax].
const double _stretchSpan = 320;
const double _stretchMax = 0.55;

/// Where a docking piece sits with the page scrolled to the top, in the page's
/// coordinates.
@immutable
class _DockGeometry {
  const _DockGeometry(this.centre, this.size);
  final Offset centre;
  final Size size;

  @override
  bool operator ==(Object other) =>
      other is _DockGeometry &&
      (other.centre - centre).distance < 0.5 &&
      (other.size.width - size.width).abs() < 0.5 &&
      (other.size.height - size.height).abs() < 0.5;

  @override
  int get hashCode => Object.hash(centre.dx.round(), centre.dy.round(), size.width.round(), size.height.round());
}

/// What [HeroPage] shares with the pieces that dock into its bar.
class HeroDockController {
  HeroDockController(this.scroll);

  final ScrollController scroll;

  /// The page's root box: every geometry is measured against it.
  final GlobalKey pageKey = GlobalKey();

  final ValueNotifier<_DockGeometry?> _avatar = ValueNotifier(null);
  final ValueNotifier<_DockGeometry?> _title = ValueNotifier(null);

  /// Fires when either piece is measured or moves.
  Listenable get geometry => Listenable.merge([_avatar, _title]);

  /// Whether a [HeroDockTitle] has been laid out on this page.
  bool get hasTitle => _title.value != null;

  /// The bar's vertical centre in page coordinates. Set by [HeroPage].
  double barCentre = 0;

  /// The one-line title the bar shows when the name is too long to dock as
  /// itself. See [titleFits]. Set by [HeroPage].
  Widget barTitle = const SizedBox.shrink();

  double _avatarDiameter = 0;
  double _titleFontSize = 28;
  double _pageWidth = 0;

  void dispose() {
    _avatar.dispose();
    _title.dispose();
  }

  double get pixels =>
      scroll.hasClients && scroll.positions.length == 1 ? scroll.position.pixels : 0;

  /// The scroll offset at which the head has finished docking: the name's
  /// centre reaches the bar's, or for a name too long to dock, its top does.
  /// Null until measured.
  double? get dockedAt {
    final t = _title.value;
    if (t != null) {
      final y = titleFits ? t.centre.dy : t.centre.dy - t.size.height / 2;
      return math.max(y - barCentre, 1);
    }
    final a = _avatar.value;
    if (a != null) return math.max(a.centre.dy - barCentre, 1);
    return null;
  }

  double get _titleScale => _dockTitleSize / _titleFontSize;

  double get _available => math.max(0, _pageWidth - 2 * _barSideInset);

  /// Whether the name docks as itself. A name that wraps, or that would not
  /// fit beside the avatar at bar size, scrolls away instead, and a one-line
  /// ellipsised title takes its place in the bar.
  bool get titleFits {
    final t = _title.value;
    if (t == null) return true;
    final oneLine = t.size.height < _titleFontSize * 1.9;
    return oneLine &&
        t.size.width * _titleScale + kDockedAvatar + _dockGap <= _available;
  }

  double get _dockedTitleWidth {
    final t = _title.value;
    if (t == null) return 0;
    return titleFits
        ? t.size.width * _titleScale
        : _available - kDockedAvatar - _dockGap;
  }

  /// The docked avatar's left edge: the avatar and title together are centred.
  double get _groupLeft {
    final group = kDockedAvatar + (hasTitle ? _dockGap + _dockedTitleWidth : 0);
    return (_pageWidth - group) / 2;
  }

  /// How much bigger the avatar is drawn while the page is pulled past the top.
  double _grow(double stretch) =>
      1 + math.min(stretch / _stretchSpan, _stretchMax);

  void _report(
    ValueNotifier<_DockGeometry?> slot,
    GlobalKey key,
  ) {
    final box = key.currentContext?.findRenderObject();
    final page = pageKey.currentContext?.findRenderObject();
    if (box is! RenderBox || page is! RenderBox) return;
    if (!box.attached || !box.hasSize || !page.attached || !page.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: page);
    _pageWidth = page.size.width;
    // Content moves one for one with the scroll, overscroll included, so
    // adding the offset back gives the resting position.
    final g = _DockGeometry(
      topLeft + box.size.center(Offset.zero) + Offset(0, pixels),
      box.size,
    );
    if (slot.value != g) slot.value = g;
  }
}

class _HeroDockScope extends InheritedWidget {
  const _HeroDockScope({required this.dock, required super.child});
  final HeroDockController dock;

  @override
  bool updateShouldNotify(_HeroDockScope old) => old.dock != dock;
}

/// Provides [dock] to the pieces under [child]. Placed by [HeroPage].
class HeroDockScope extends StatelessWidget {
  const HeroDockScope({super.key, required this.dock, required this.child});
  final HeroDockController dock;
  final Widget child;

  static HeroDockController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HeroDockScope>()?.dock;

  @override
  Widget build(BuildContext context) => _HeroDockScope(dock: dock, child: child);
}

/// Shared plumbing: a placeholder in the content and the real child in the
/// page's overlay, placed from the placeholder's measured resting position
/// and the scroll offset.
///
/// Not a [LayerLink] to the placeholder: once the hero scrolls far enough
/// past the top, the viewport stops painting it, the link drops, and a
/// follower hidden when unlinked took the docked avatar and name with it.
abstract class _DockPieceState<T extends StatefulWidget> extends State<T> {
  final _portal = OverlayPortalController();
  final _key = GlobalKey();
  HeroDockController? _dock;

  ValueNotifier<_DockGeometry?> _slot(HeroDockController dock);
  Widget get pieceChild;
  Widget placeholder();
  Widget docked(BuildContext context, HeroDockController dock, Widget child);
  void configure(HeroDockController dock) {}

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) {
    final dock = _dock = HeroDockScope.maybeOf(context);
    if (dock == null) return pieceChild;
    configure(dock);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dock != null) _dock!._report(_slot(_dock!), _key);
    });
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => ListenableBuilder(
        listenable: Listenable.merge([dock.scroll, dock.geometry]),
        builder: (context, child) => docked(context, dock, child!),
        child: pieceChild,
      ),
      child: KeyedSubtree(key: _key, child: placeholder()),
    );
  }

  /// Draws [child] where the placeholder sits at the current scroll, moved
  /// by [offset]. Unseen for the one frame before the first measurement.
  /// One widget shape either way, so [child]'s state survives the switch.
  Widget follow(
    HeroDockController dock, {
    required Offset offset,
    required Widget child,
  }) {
    final g = _slot(dock).value;
    final at = g == null
        ? Offset.zero
        : g.centre - g.size.center(Offset.zero) - Offset(0, dock.pixels);
    return Align(
      alignment: Alignment.topLeft,
      child: Opacity(
        opacity: g == null ? 0 : 1,
        child: Transform.translate(offset: at + offset, child: child),
      ),
    );
  }
}

/// The hero's avatar. Shrinks to [kDockedAvatar] and lands left of the title
/// in the bar as the page scrolls.
class HeroDockAvatar extends StatefulWidget {
  const HeroDockAvatar({
    super.key,
    required this.diameter,
    this.extent,
    required this.child,
  });

  /// The avatar circle's diameter. The circle sits at the top left of [child].
  final double diameter;

  /// [child]'s size when it is bigger than the circle (a badge hanging past
  /// it). Defaults to [diameter].
  final double? extent;
  final Widget child;

  @override
  State<HeroDockAvatar> createState() => _HeroDockAvatarState();
}

class _HeroDockAvatarState extends _DockPieceState<HeroDockAvatar> {
  double get _extent => widget.extent ?? widget.diameter;

  @override
  ValueNotifier<_DockGeometry?> _slot(HeroDockController dock) => dock._avatar;

  @override
  Widget get pieceChild => widget.child;

  @override
  void configure(HeroDockController dock) => dock._avatarDiameter = widget.diameter;

  @override
  Widget placeholder() => SizedBox.square(dimension: _extent);

  @override
  Widget docked(BuildContext context, HeroDockController dock, Widget child) {
    final d = widget.diameter;
    final g = dock._avatar.value;
    final s = dock.pixels;
    final up = math.max(s, 0.0);
    final stretch = math.max(-s, 0.0);
    final grow = dock._grow(stretch);
    var scale = grow;
    var offset = Offset(0, d / 2 * (grow - 1));
    final range = dock.dockedAt;
    if (g != null && range != null) {
      // The circle has three times as far to shrink as the name, so a linear
      // shrink left a speck of a face over a still-big name: its size eases
      // in, half way to easeIn, on the name's clock. It slides on a slightly
      // faster one (as Telegram's does) so the still-large circle keeps clear
      // of the name rising under it.
      final p = (up / range).clamp(0.0, 1.0);
      final e = (up / (range * 0.8)).clamp(0.0, 1.0);
      final shrink = (p + Curves.easeIn.transform(p)) / 2;
      scale = (1 + (kDockedAvatar / d - 1) * shrink) * grow;
      // The circle's centre, not the box's: a badge can make the box bigger.
      final cx0 = g.centre.dx - _extent / 2 + d / 2;
      final cy0 = g.centre.dy - _extent / 2 + d / 2;
      final cx = lerpDouble(cx0, dock._groupLeft + kDockedAvatar / 2, e)!;
      final cy = lerpDouble(cy0, dock.barCentre, e)! +
          stretch +
          d / 2 * (grow - 1);
      offset = Offset(cx - cx0, cy - (cy0 - s));
    }
    return follow(
      dock,
      offset: offset,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        origin: Offset(d / 2, d / 2),
        child: SizedBox.square(dimension: _extent, child: child),
      ),
    );
  }
}

/// The hero's name. Scales down to a 17pt title and lands right of the
/// docked avatar. [fontSize] is the size [child] is drawn at.
class HeroDockTitle extends StatefulWidget {
  const HeroDockTitle({
    super.key,
    required this.fontSize,
    required this.child,
  });

  final double fontSize;
  final Widget child;

  @override
  State<HeroDockTitle> createState() => _HeroDockTitleState();
}

class _HeroDockTitleState extends _DockPieceState<HeroDockTitle> {
  @override
  ValueNotifier<_DockGeometry?> _slot(HeroDockController dock) => dock._title;

  @override
  Widget get pieceChild => widget.child;

  @override
  void configure(HeroDockController dock) => dock._titleFontSize = widget.fontSize;

  // Laid out but neither painted nor hit: it holds the name's exact space.
  @override
  Widget placeholder() => Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: widget.child,
      );

  @override
  Widget docked(BuildContext context, HeroDockController dock, Widget child) {
    final g = dock._title.value;
    final range = dock.dockedAt;
    final s = dock.pixels;
    final up = math.max(s, 0.0);
    final stretch = math.max(-s, 0.0);
    // The growing avatar above pushes the name down.
    final push = dock._avatarDiameter * (dock._grow(stretch) - 1);
    var offset = Offset(0, push);
    var scale = 1.0;
    var opacity = 1.0;
    var barFade = 0.0;
    if (g != null && range != null) {
      if (dock.titleFits) {
        final p = (up / range).clamp(0.0, 1.0);
        scale = 1 + (dock._titleScale - 1) * p;
        final cx1 = dock._groupLeft +
            kDockedAvatar +
            _dockGap +
            g.size.width * dock._titleScale / 2;
        final cy = lerpDouble(g.centre.dy, dock.barCentre, p)! + stretch + push;
        offset = Offset((cx1 - g.centre.dx) * p, cy - (g.centre.dy - s));
      } else {
        // Too long to dock: the name scrolls away under the bar and a
        // one-line title fades in beside the docked avatar, handing over as
        // the name's top line nears the bar.
        barFade = ((up - (range - 40)) / 24).clamp(0.0, 1.0);
        opacity = 1 - barFade;
      }
    }
    // One shape whatever the state, so the child's own entrance animation is
    // never torn down and restarted when the measurement lands.
    return Stack(
      children: [
        follow(
          dock,
          offset: offset,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              // Laid out at the placeholder's size, so a name wraps exactly
              // as it does in the content.
              child: SizedBox(
                width: g?.size.width,
                height: g?.size.height,
                child: child,
              ),
            ),
          ),
        ),
        if (barFade > 0)
          Positioned(
            left: dock._groupLeft + kDockedAvatar + _dockGap,
            width: dock._dockedTitleWidth,
            top: dock.barCentre - 14,
            height: 28,
            child: IgnorePointer(
              child: Opacity(
                opacity: barFade,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: dock.barTitle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fades part of the hero out as the page starts to scroll, and stops it
/// taking taps once mostly gone: the avatar's camera badge, which would
/// otherwise shrink to a speck, and the line under the name, which would sit
/// under the docked title like a second line.
class HeroDockFade extends StatelessWidget {
  const HeroDockFade({super.key, this.distance = 40, required this.child});

  /// Scroll distance over which it fades out.
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dock = HeroDockScope.maybeOf(context);
    if (dock == null) return child;
    return ListenableBuilder(
      listenable: dock.scroll,
      builder: (context, child) {
        final up = math.max(dock.pixels, 0.0);
        return IgnorePointer(
          ignoring: up > distance * 0.75,
          child: Opacity(
            opacity: (1 - up / distance).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
