import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
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

// Opt in with [HeroPage.expandedPhoto]: pulling the page down past
// [_expandAt] latches the avatar open into a full-width photo that fills the
// head (Telegram's profile). It stays open on release and folds back into the
// circle as soon as the page scrolls up. The photo is painted by [HeroPage]
// beneath the bar; the name and the line under it ride over it.

/// The avatar's diameter once docked in the bar.
const double kDockedAvatar = 44;

/// Space between the docked avatar and the title.
const double _dockGap = 8;

/// The docked title's font size: the iOS bar title.
const double _dockTitleSize = 17;

/// The bar keeps this much clear on each side for the back button and actions.
const double _barSideInset = 64;

/// Pulling down this far latches the expanded photo open.
const double _expandAt = 72;

/// Scrolling up past this folds an expanded photo away.
const double _collapseAt = 8;

/// Left edge of the name over the expanded photo.
const double _photoInset = 20;

/// Room kept under the name inside the photo, for the line beneath it.
const double _photoPad = 30;

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
  HeroDockController(this.scroll, {required TickerProvider vsync})
      : _anim = AnimationController.unbounded(vsync: vsync) {
    scroll.addListener(_onScroll);
  }

  final ScrollController scroll;

  /// 0 collapsed, 1 expanded; a spring, so it may overshoot a little.
  final AnimationController _anim;
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 240,
    ratio: 0.8,
  );
  bool _expanded = false;

  /// Whether pulling down expands the avatar into a photo. See [configurePhoto].
  bool expandable = false;
  bool _calm = false;
  Widget Function(BuildContext context, Size size)? _photoBuilder;

  /// Fires as the expansion animates.
  Listenable get expandListenable => _anim;

  /// How far open the photo is, 0..1 (a touch over while the spring settles).
  double get expand => expandable ? _anim.value.clamp(0.0, 1.04) : 0.0;

  void configurePhoto({
    required bool enabled,
    Widget Function(BuildContext context, Size size)? builder,
    bool calm = false,
  }) {
    expandable = enabled && builder != null;
    _photoBuilder = builder;
    _calm = calm;
    if (!expandable && (_expanded || _anim.value != 0)) {
      _expanded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!expandable) _anim.value = 0;
      });
    }
  }

  void _onScroll() {
    if (!expandable || !scroll.hasClients || scroll.positions.length != 1) return;
    final s = scroll.position.pixels;
    if (!_expanded && s <= -_expandAt && hasTitle) {
      _setExpanded(true);
    } else if (_expanded && s > _collapseAt) {
      _setExpanded(false);
    }
  }

  void _setExpanded(bool on) {
    _expanded = on;
    if (on) HapticFeedback.lightImpact();
    if (_calm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_expanded == on) _anim.value = on ? 1 : 0;
      });
      return;
    }
    _anim.animateWith(
      SpringSimulation(_spring, _anim.value, on ? 1 : 0, _anim.velocity),
    );
  }

  /// The title's bottom edge at rest, without the expansion spacer.
  double get _nameBottomRest {
    final t = _title.value;
    return t == null ? 0 : t.centre.dy + t.size.height / 2;
  }

  /// The expanded photo's bottom edge at rest: a square, or lower if the name
  /// is already further down.
  double get _fullBottom => math.max(_pageWidth, _nameBottomRest + _photoPad);

  /// Height the expansion adds above the hero, at fully open.
  double get _photoExtra => math.max(0, _fullBottom - (_nameBottomRest + _photoPad));

  /// The live height of the spacer [HeroPage] holds above the hero.
  double get spacer => hasTitle ? _photoExtra * expand : 0;

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
    scroll.removeListener(_onScroll);
    _anim.dispose();
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
      1 + math.min(stretch / _stretchSpan, _stretchMax) * (1 - expand.clamp(0.0, 1.0));


  double _avatarExtent = 0;

  /// Where the avatar circle's centre is drawn now, and its scale: at rest,
  /// grown by a pull, or on its way into the bar. Null until measured.
  ///
  /// It slides on a clock a little faster than the name's (as Telegram's
  /// does) so the still-large circle keeps clear of the name rising under it.
  ({Offset centre, double scale})? avatarPose() {
    final g = _avatar.value;
    final range = dockedAt;
    if (g == null || range == null) return null;
    final d = _avatarDiameter;
    final s = pixels;
    final up = math.max(s, 0.0);
    final stretch = math.max(-s, 0.0);
    final grow = _grow(stretch);
    final p = (up / range).clamp(0.0, 1.0);
    final e = (up / (range * 0.8)).clamp(0.0, 1.0);
    // The circle has three times as far to shrink as the name, so a linear
    // shrink left a speck of a face over a still-big name: its size eases
    // in, half way to easeIn, on the name's clock.
    final shrink = (p + Curves.easeIn.transform(p)) / 2;
    final scale = (1 + (kDockedAvatar / d - 1) * shrink) * grow;
    // The circle's centre, not the box's: a badge can make the box bigger.
    final cx0 = g.centre.dx - _avatarExtent / 2 + d / 2;
    final cy0 = g.centre.dy - _avatarExtent / 2 + d / 2 + spacer;
    final cx = lerpDouble(cx0, _groupLeft + kDockedAvatar / 2, e)!;
    final cy = lerpDouble(cy0, barCentre, e)! + stretch + d / 2 * (grow - 1);
    return (centre: Offset(cx, cy), scale: scale);
  }

  /// The expanded photo: the avatar circle's rect grown into the head,
  /// corner radius easing to square. Null while closed. Painted by
  /// [HeroPage] under the bar. The picture itself is laid out once at a fixed
  /// size and only scaled and clipped, so no frame re-decodes it.
  Widget? buildPhoto(BuildContext context) {
    final builder = _photoBuilder;
    final t = expand;
    final pose = avatarPose();
    if (!expandable || builder == null || t <= 0.001 || pose == null) return null;
    final s = pixels;
    final up = math.max(s, 0.0);
    final stretch = math.max(-s, 0.0);
    final d = _avatarDiameter * pose.scale;
    final circle = Rect.fromCenter(center: pose.centre, width: d, height: d);
    final full = Rect.fromLTRB(0, -up, _pageWidth, _fullBottom - up + stretch);
    final rect = Rect.lerp(circle, full, t)!;
    final radius = d / 2 * (1 - t.clamp(0.0, 1.0));
    final side = _pageWidth;
    final shade = t.clamp(0.0, 1.0);
    final black = const Color(0xFF000000);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            // Nothing to tap: the open photo IS the full view. Drags reach
            // the scroll view underneath.
            child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: side,
                          height: side,
                          child: builder(context, Size(side, side)),
                        ),
                      ),
                      // Under the name, and under the back button.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              black.withValues(alpha: 0.62 * shade),
                              black.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.45],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              black.withValues(alpha: 0.38 * shade),
                              black.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.3],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }

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
    // adding the offset back gives the resting position. The expansion spacer
    // is taken out too: pieces add the live spacer themselves.
    final g = _DockGeometry(
      topLeft + box.size.center(Offset.zero) + Offset(0, pixels - spacer),
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
        listenable: Listenable.merge([dock.scroll, dock.geometry, dock.expandListenable]),
        builder: (context, child) => docked(context, dock, child!),
        child: pieceChild,
      ),
      child: KeyedSubtree(key: _key, child: placeholder()),
    );
  }

  /// Draws [child] with its top left at [topLeft] in the page's coordinates.
  /// Unseen for the one frame before the first measurement. One widget shape
  /// either way, so [child]'s state survives the switch.
  ///
  /// The translate is the OUTER layer on purpose. Inside an [Opacity] it moved
  /// the paint but not the hit box: RenderOpacity tests a tap against its own
  /// untranslated rect at the page's top left, so every docked piece drew in
  /// place and took no taps (the profile and room avatars, the editable name;
  /// 2026-11-18). RenderTransform skips that bounds check and maps the point.
  Widget place({required Offset? topLeft, required Widget child}) {
    return Align(
      alignment: Alignment.topLeft,
      child: Transform.translate(
        offset: topLeft ?? Offset.zero,
        child: Opacity(opacity: topLeft == null ? 0 : 1, child: child),
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
  void configure(HeroDockController dock) {
    dock._avatarDiameter = widget.diameter;
    dock._avatarExtent = _extent;
  }

  @override
  Widget placeholder() => SizedBox.square(dimension: _extent);

  @override
  Widget docked(BuildContext context, HeroDockController dock, Widget child) {
    final d = widget.diameter;
    final pose = dock.avatarPose();
    // The photo takes over from the circle as it opens: the circle is gone by
    // a quarter of the way, and can no longer be tapped or seen under it.
    final open = dock.expand;
    return place(
      topLeft: pose == null ? null : pose.centre - Offset(d / 2, d / 2),
      child: IgnorePointer(
        ignoring: open > 0.15,
        child: Opacity(
          opacity: (1 - open / 0.25).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: pose?.scale ?? 1,
            alignment: Alignment.topLeft,
            origin: Offset(d / 2, d / 2),
            child: SizedBox.square(dimension: _extent, child: child),
          ),
        ),
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
    final open = dock.expand;
    // The growing avatar above pushes the name down.
    final push = dock._avatarDiameter * (dock._grow(stretch) - 1);
    var scale = 1.0;
    var opacity = 1.0;
    var barFade = 0.0;
    Offset? topLeft;
    if (g != null) {
      final w = g.size.width;
      final h = g.size.height;
      // Where the name sits with the page at the top: under the avatar, or
      // when the photo is open, at its bottom left.
      final cyRest = g.centre.dy + dock.spacer;
      final baseLeft = lerpDouble(g.centre.dx - w / 2, _photoInset, open)!;
      var cx = baseLeft + w / 2;
      var cy = cyRest - s + push;
      if (range != null && dock.titleFits) {
        final p = (up / range).clamp(0.0, 1.0);
        scale = 1 + (dock._titleScale - 1) * p;
        final cx1 = dock._groupLeft +
            kDockedAvatar +
            _dockGap +
            w * dock._titleScale / 2;
        cx = lerpDouble(cx, cx1, p)!;
        cy = lerpDouble(cyRest, dock.barCentre, p)! + stretch + push;
      } else if (range != null) {
        // Too long to dock: the name scrolls away under the bar and a
        // one-line title fades in beside the docked avatar, handing over as
        // the name's top line nears the bar.
        barFade = ((up - (range - 40)) / 24).clamp(0.0, 1.0);
        opacity = 1 - barFade;
      }
      topLeft = Offset(cx - w / 2, cy - h / 2);
    }
    if (dock.expandable) {
      // White over the photo, the same glyphs: a filter, not a second style.
      child = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Color.fromRGBO(255, 255, 255, open.clamp(0.0, 1.0)),
          BlendMode.srcATop,
        ),
        child: child,
      );
    }
    // One shape whatever the state, so the child's own entrance animation is
    // never torn down and restarted when the measurement lands.
    return Stack(
      children: [
        place(
          topLeft: topLeft,
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
  const HeroDockFade({
    super.key,
    this.distance = 40,
    this.overPhoto = false,
    required this.child,
  });

  /// Scroll distance over which it fades out.
  final double distance;

  /// For the line under the name: when the page's photo opens it turns white
  /// and slides to the left edge with the name, over the photo.
  final bool overPhoto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dock = HeroDockScope.maybeOf(context);
    if (dock == null) return child;
    return ListenableBuilder(
      listenable: Listenable.merge([dock.scroll, dock.expandListenable]),
      builder: (context, child) {
        final up = math.max(dock.pixels, 0.0);
        Widget c = child!;
        if (overPhoto && dock.expandable) {
          final open = dock.expand.clamp(0.0, 1.0);
          c = Align(
            alignment: Alignment(-open, 0),
            child: Padding(
              padding: EdgeInsets.only(left: (_photoInset - 16) * open),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Color.fromRGBO(255, 255, 255, 0.86 * open),
                  BlendMode.srcATop,
                ),
                child: c,
              ),
            ),
          );
        }
        return IgnorePointer(
          ignoring: up > distance * 0.75,
          child: Opacity(
            opacity: (1 - up / distance).clamp(0.0, 1.0),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
