import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'hero_dock.dart';
import 'ios_kit.dart';
import 'sunlit_surface.dart' show SunlitBackdrop;
import 'teardown_safe.dart';
import 'notice.dart';
import '../ui/native/native_cut.dart';

// The account-area half of the iOS vocabulary in ios_kit.dart: the Contacts /
// Telegram profile shape (a big face, a name, a row of action tiles, then
// grouped sections) and the helpers the profile, room info and account pages
// share. Built on the kit's atoms, never instead of them.

/// Horizontal padding that keeps a page's grouped blocks at a readable width
/// on a wide window and at the iOS 16pt inset on a phone.
EdgeInsets readableInset(BuildContext context, {double top = 0, double bottom = 0}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = context.isCompact
      ? 16.0
      : ((width - ContentWidth.readable) / 2).clamp(16.0, double.infinity);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// [IosPage] slivers for a plain list of [children], centred at a readable
/// width on wide windows. Clears the home indicator itself.
List<Widget> readableSlivers(BuildContext context, List<Widget> children) => [
      SliverPadding(
        padding: readableInset(
          context,
          bottom: 40 + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: SliverList.list(children: children),
      ),
    ];

/// A page led by a person or a room rather than by a title: the hero (big
/// avatar, name, actions) scrolls away while the avatar and name dock into
/// the bar, the way Telegram profiles behave. The hero marks its avatar and
/// name with [HeroDockAvatar] and [HeroDockTitle]; without them the name
/// simply fades into the bar.
class HeroPage extends StatefulWidget {
  const HeroPage({
    super.key,
    required this.title,
    required this.hero,
    required this.children,
    this.actions = const [],
  });

  /// What the bar shows once the hero has scrolled away.
  final String title;
  final Widget hero;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  State<HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<HeroPage> {
  final _scroll = ScrollController();
  final _heroKey = GlobalKey();
  late final _dock = HeroDockController(_scroll);

  /// How far below the bar the docked veil fades out.
  static const double _veilFade = 30;

  /// The page lives in its own overlay so the docked avatar and name can
  /// paint above the bar's veil. See hero_dock.dart.
  late final _body = OverlayEntry(builder: _buildBody, opaque: true);

  /// The hero's laid-out height, measured after layout; it sets where the
  /// bar's small title starts to appear when nothing docks.
  double _heroHeight = 0;

  @override
  void dispose() {
    _dock.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _measureHero() {
    final box = _heroKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if ((box.size.height - _heroHeight).abs() < 0.5) return;
    setState(() => _heroHeight = box.size.height);
  }

  /// A release part way through the dock settles it open or shut, so the
  /// bar never rests on a half-shrunk avatar.
  bool _settle(ScrollEndNotification n) {
    if (n.depth != 0 || !_scroll.hasClients) return false;
    final docked = _dock.dockedAt;
    if (docked == null) return false;
    final position = _scroll.position;
    final s = position.pixels;
    if (s <= 0 || s >= docked) return false;
    final target = s < docked / 2 ? 0.0 : math.min(docked, position.maxScrollExtent);
    if ((target - s).abs() < 1) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // The entry builds from this state; rebuild it with the page.
    _body.markNeedsBuild();
    return Overlay(initialEntries: [_body]);
  }

  Widget _buildBody(BuildContext context) {
    final theme = ThemeScope.of(context);
    final canPop = Navigator.of(context).canPop();
    final top = MediaQuery.paddingOf(context).top;
    final bg = theme.background;
    final clearance = top + IosPage.barHeight;
    _dock.barCentre = top + IosPage.barHeight / 2;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureHero();
    });
    final barTitleStyle = theme.bodyEmph.copyWith(
      color: theme.ink,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    );
    _dock.barTitle = Text(
      widget.title,
      style: barTitleStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return HeroDockScope(
      dock: _dock,
      child: Scaffold(
        key: _dock.pageKey,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const SunlitBackdrop(),
            NativeCut(
              top: clearance,
              child: NotificationListener<ScrollEndNotification>(
              onNotification: _settle,
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  // Pinned and empty: holds the bar's place so the hero starts
                  // below it, as IosPage does.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HeroBarClearance(clearance),
                  ),
                  SliverToBoxAdapter(
                    child: KeyedSubtree(key: _heroKey, child: widget.hero),
                  ),
                  ...readableSlivers(context, widget.children),
                ],
              ),
            ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The soft edge, taller than the bar so rows dissolve as
                  // they scroll under it.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              bg,
                              bg.withValues(alpha: 0.92),
                              bg.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.62, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Solid through the whole bar once the head docks, then a
                  // short fade below it: the docked avatar and name and the
                  // glass back button sit on the page colour, with no rows
                  // ghosting through. Fades in over the last stretch of the
                  // dock, as the RN header's veil does. The fade below is long:
                  // a short one read as a black shadow cast on the first card.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: clearance + _veilFade,
                    child: IgnorePointer(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_scroll, _dock.geometry]),
                        builder: (context, child) {
                          final docked = _dock.dockedAt;
                          final s = _dock.pixels;
                          final o = docked == null
                              ? 0.0
                              : ((s - (docked - 56)) / 48).clamp(0.0, 1.0);
                          return o == 0
                              ? const SizedBox.shrink()
                              : Opacity(opacity: o, child: child);
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [bg, bg, bg.withValues(alpha: 0)],
                              stops: [0, clearance / (clearance + _veilFade), 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: top, bottom: 14),
                    child: SizedBox(
                      height: IosPage.barHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Only when the hero has no docking name; one that
                            // docks IS the bar title.
                            ListenableBuilder(
                              listenable: _dock.geometry,
                              builder: (context, _) => _dock.hasTitle
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 64),
                                      child: CollapsedTitleFade(
                                        scroll: _scroll,
                                        // The name sits a little above the hero's
                                        // bottom edge: show the small title as it
                                        // goes under the bar.
                                        start: (_heroHeight - 110).clamp(
                                          0.0,
                                          double.infinity,
                                        ),
                                        span: 24,
                                        child: Text(
                                          widget.title,
                                          style: barTitleStyle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                            ),
                            Row(
                              children: [
                                if (canPop) const GlassBackButton(),
                                const Spacer(),
                                for (var i = 0;
                                    i < widget.actions.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  widget.actions[i],
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The empty, pinned strip under [HeroPage]'s floating bar.
class _HeroBarClearance extends SliverPersistentHeaderDelegate {
  const _HeroBarClearance(this.extent);
  final double extent;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox(height: extent);

  @override
  bool shouldRebuild(_HeroBarClearance old) => old.extent != extent;
}

/// The hero's avatar: scales in on a soft spring the first time the page
/// shows, the Telegram profile "pop". Static under reduced motion.
class AvatarPop extends StatelessWidget {
  const AvatarPop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.72, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: child,
    );
  }
}

/// Fades and lifts its child in, [index] steps behind the first — the
/// stagger the hero's name, handle and action row arrive on.
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// One tile in a profile's action row — icon over a short label on a rounded
/// surface tile, equal widths, the Telegram / iOS Contacts arrangement.
///
/// Now drawn by [QuickActionTile]: one tint rule (accent, red for [danger]),
/// labels that wrap to two lines and shrink rather than ellipsize. New code
/// uses [SheetQuickActions] directly.
class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.busy = false,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;

  /// Null greys the tile out.
  final VoidCallback? onTap;
  final bool danger;
  final bool busy;

  /// Kept for callers; every tile is accent now (one tint rule per row —
  /// "Add" in accent beside "Mute" in ink read as two different controls).
  final bool emphasis;

  @override
  Widget build(BuildContext context) => QuickActionTile(
        icon: icon,
        label: label,
        onTap: onTap,
        destructive: danger,
        busy: busy,
      );
}

/// A row of [ProfileActionTile]s, equal widths with an 8pt gap, all as tall
/// as the tallest label needs.
class ProfileActionBar extends StatelessWidget {
  const ProfileActionBar({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => QuickTileRow(tiles: tiles);
}

/// A small status line under a hero name: a coloured dot and a word.
class StatusDotLine extends StatelessWidget {
  const StatusDotLine({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: groupedSubtitleStyle(theme),
        ),
      ],
    );
  }
}

/// A note under a hero or above a section: an icon and a sentence on a soft
/// fill, for things like "some fields are hidden".
///
/// A preset over [Notice] (quiet register).
class SoftNote extends StatelessWidget {
  const SoftNote({
    super.key,
    required this.icon,
    required this.text,
    this.tone,
    this.title,
  });

  final IconData icon;
  final String text;
  final Color? tone;

  /// A bold first line above [text] — a notice with a name ("Server
  /// unreachable"), replacing the server screen's private `_Notice`.
  final String? title;

  @override
  Widget build(BuildContext context) =>
      Notice(text, icon: icon, color: tone, title: title);
}

/// Section spacing helper for code that builds a hero by hand.
const SizedBox kHeroGap = SizedBox(height: 20);

/// A [GroupedSection] for rows that are not [GroupedRow]s — member lists,
/// inline editors — where the divider has to start at a caller-chosen inset
/// (the text column beside an avatar) rather than the kit's two defaults.
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.dividerInset = 16,
    this.margin = const EdgeInsets.only(bottom: 28),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final double dividerInset;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) GroupedHeader(header!),
          groupedBlock(
            theme,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Padding(
                      padding: EdgeInsets.only(left: dividerInset),
                      child: Container(
                        height: hairline,
                        color: theme.ink.withValues(alpha: 0.10),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(footer!, style: groupedFooterStyle(theme)),
            ),
        ],
      ),
    );
  }
}

/// A row with the grouped-row press highlight around arbitrary [child]
/// content — the member rows, the invite rows. Pass null [onTap] for a static
/// row.
class PressRow extends StatefulWidget {
  const PressRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.padding = const EdgeInsets.fromLTRB(16, 9, 14, 9),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final EdgeInsets padding;

  @override
  State<PressRow> createState() => _PressRowState();
}

class _PressRowState extends State<PressRow>
    with TeardownSafe<PressRow> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final body = Padding(padding: widget.padding, child: widget.child);
    if (widget.onTap == null) return body;
    // FocusableTap gives it the hand cursor, a Tab stop with Enter, the
    // focus ring and the square hover fill a grouped row has (the block's
    // clip rounds the ends). It carries the button semantics too.
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel,
      hover: HoverEffect.tint,
      hoverRadius: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        // A right-click is a mouse's long-press. Touch never produces one.
        onSecondaryTap: widget.onLongPress,
        child: AnimatedContainer(
          duration: _down ? Duration.zero : const Duration(milliseconds: 260),
          color: _down
              ? theme.ink.withValues(alpha: 0.08)
              : Colors.transparent,
          child: body,
        ),
      ),
    );
  }
}
